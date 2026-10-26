using System.Diagnostics;
using System.Runtime.InteropServices;
using KiYo.Core;
namespace KiYo.Windows;
internal sealed class InputService : IDisposable
{
    private readonly Control dispatcher;
    private readonly Func<Preferences> preferences;
    private readonly Action<string> report;
    private readonly TypingState state = new();
    private readonly CorrectionSchedule schedule = new();
    private readonly System.Windows.Forms.Timer timer = new() { Interval = 15 };
    private readonly Native.Hook keyboardCallback, mouseCallback;
    private nint keyboard, mouse;
    private bool busy, disposed;
    internal bool Available => keyboard != 0 && mouse != 0;
    internal InputService(Control dispatcher, Func<Preferences> preferences, Action<string> report)
    {
        this.dispatcher = dispatcher; this.preferences = preferences; this.report = report;
        keyboardCallback = Keyboard; mouseCallback = Mouse;
        keyboard = Native.SetWindowsHookEx(13, keyboardCallback, Native.GetModuleHandle(null), 0);
        mouse = Native.SetWindowsHookEx(14, mouseCallback, Native.GetModuleHandle(null), 0);
        if (!Available) { Dispose(); throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); }
        timer.Tick += (_, _) => Pump(); timer.Start();
    }
    internal void Reset() => state.Invalidate();
    private nint Mouse(int code, nint message, nint data)
    {
        if (code >= 0 && (long)message != 0x200) state.Invalidate(); // clicks, wheel, dragging invalidate pending work
        return Native.CallNextHookEx(mouse, code, message, data);
    }
    private nint Keyboard(int code, nint message, nint data)
    {
        try { return HandleKeyboard(code, message, data); }
        catch (Exception ex) when (ex is not OutOfMemoryException)
        {
            state.Invalidate();
            return Native.CallNextHookEx(keyboard, code, message, data);
        }
    }
    private nint HandleKeyboard(int code, nint message, nint data)
    {
        if (code < 0) return Native.CallNextHookEx(keyboard, code, message, data);
        var e = Marshal.PtrToStructure<Native.KeyboardEvent>(data);
        if (e.Extra == Native.Tag) return Native.CallNextHookEx(keyboard, code, message, data);
        if ((e.Flags & 0x10) != 0) { state.Invalidate(); return Native.CallNextHookEx(keyboard, code, message, data); }
        schedule.Activity(Environment.TickCount64);
        if ((long)message is not (0x100 or 0x104)) return Native.CallNextHookEx(keyboard, code, message, data);
        var window = Native.GetForegroundWindow();
        var thread = Native.GetWindowThreadProcessId(window, out var pid);
        var layout = Native.GetKeyboardLayout(thread);
        state.Context(window, layout, Native.Focus(window));
        if (!preferences().Enabled || pid == Environment.ProcessId || !Native.SupportedLayout(layout)) state.Invalidate();
        else if (Native.Down(0x11) || Native.Down(0x12) || Native.Down(0x5B) || Native.Down(0x5C) || e.Key is 0x11 or 0x12 or 0x5B or 0x5C) state.Invalidate();
        else if (e.Key == 8) state.Backspace(DateTimeOffset.UtcNow);
        else if (e.Key == 0x20) state.Space(DateTimeOffset.UtcNow);
        else if (e.Key is 0x10 or 0xA0 or 0xA1) { /* Shift alone does not split a word. */ }
        else if (Native.Translate(e, layout) is char c) state.Character(c);
        else state.Invalidate();
        // Always forward real keyboard events, including space/tab/enter and key-up.
        return Native.CallNextHookEx(keyboard, code, message, data);
    }
    private void Pump()
    {
        if (disposed) return;
        var now = Environment.TickCount64;
        if (schedule.Expired(now)) { if (state.HasObserved) state.Invalidate(); return; }
        var attempt = state.Snapshot();
        if (attempt == null) return;
        if (!preferences().Enabled || Native.GetForegroundWindow() != attempt.Window || Native.Focus(attempt.Window) != attempt.Focus)
        { state.Invalidate(); return; }
        if (!busy && schedule.Ready(now) && !Native.ModifiersDown())
        { busy = true; CorrectAsync(attempt); }
    }
    private async void CorrectAsync(PhraseAttempt attempt)
    {
        var started = Stopwatch.StartNew();
        var options = preferences();
        try
        {
            // Only one provider operation is outstanding. While it runs, the hook
            // keeps appending words; the timer retries the latest suffix afterwards.
            var (analysis, snapshot) = await Task.Run(() =>
            {
                SystemDictionary? dictionary = null;
                try
                {
                    var analysis = PhraseCorrection.Analyze(attempt, (original, candidate) =>
                        Layouts.CorrectBuffered(original, candidate, options.ShortWords, options.Exclusions,
                            options.UseSystemDictionary ? (text, ru) => (dictionary ??= new()).Valid(text, ru) : null,
                            options.SpellingEnabled ? text => Spelling.Correct(text, options.Exclusions,
                                (word, ru) => (dictionary ??= new()).Valid(word, ru),
                                (word, ru) => (dictionary ??= new()).Suggest(word, ru)) : null));
                    if (!analysis.Changed) return (analysis, (TextSnapshot?)null);
                    var snapshot = TextAccess.Read(attempt.Window, attempt.Text);
                    return (analysis, snapshot != null && TextAccess.StillSelected(snapshot) ? snapshot : null);
                }
                finally { dictionary?.Dispose(); }
            });
            if (disposed || !preferences().Enabled || schedule.Expired(Environment.TickCount64)) return;
            // Results for still-present words remain useful even when newer input
            // made the captured caret/text stale. Never apply a stale replacement.
            state.Remember(analysis);
            if (!state.Current(attempt) || !analysis.Changed) return;
            if (snapshot == null || started.ElapsedMilliseconds > 250 || Native.ModifiersDown() ||
                !schedule.Ready(Environment.TickCount64))
            {
                if (!schedule.Retry(attempt.Revision, Environment.TickCount64)) state.Invalidate();
                return;
            }
            if (Native.GetForegroundWindow() != attempt.Window || Native.Focus(attempt.Window) != snapshot.Focus)
            { state.Invalidate(); return; }
            bool Current() => !disposed && preferences().Enabled && state.Current(attempt) &&
                Native.GetForegroundWindow() == attempt.Window && Native.Focus(attempt.Window) == snapshot.Focus && !Native.ModifiersDown();
            var replaced = Replace(snapshot, attempt.Text.Length, analysis.Replacement, Current);
            if (replaced == ReplacementResult.Cancelled)
            {
                // New typing during selection keeps the latest pending suffix.
                // Only an unchanged, repeatedly rejected attempt is retired.
                if (state.Current(attempt) && !schedule.Retry(attempt.Revision, Environment.TickCount64)) state.Invalidate();
                return;
            }
            if (replaced == ReplacementResult.Failed)
            { state.Invalidate(); report("inputFailed"); return; }
            var requestedLayout = analysis.LayoutWord is { } last
                ? Native.RequestLayout(attempt.Window, Layouts.IsRussian(last)) : 0;
            if (!state.Applied(analysis, requestedLayout, DateTimeOffset.UtcNow)) { state.Invalidate(); return; }
            await VerifyReplacement(snapshot, analysis.Replacement, state.Revision);
        }
        catch (Exception ex) when (ex is not OutOfMemoryException)
        {
            if (state.Current(attempt) && !schedule.Retry(attempt.Revision, Environment.TickCount64)) state.Invalidate();
        }
        finally { busy = false; }
    }
    internal async void Selection(bool addExclusion, Action<string[]> add)
    {
        if (busy || disposed) { report("busy"); return; }
        busy = true; state.Invalidate(); var revision = state.Revision;
        var window = Native.GetForegroundWindow();
        Task<TextSnapshot?>? work = null;
        try
        {
            for (int i = 0; i < 40 && Native.ModifiersDown(); i++) await Task.Delay(10);
            if (Native.ModifiersDown() || revision != state.Revision) return;
            work = Task.Run(() =>
            {
                var snapshot = TextAccess.Read(window, null);
                return snapshot != null && TextAccess.StillSelected(snapshot) ? snapshot : null;
            });
            if (await Task.WhenAny(work, Task.Delay(300)) != work) { report("unsupported"); return; }
            var result = await work;
            if (disposed || result == null || revision != state.Revision || Native.GetForegroundWindow() != window || Native.Focus(window) != result.Focus || Native.ModifiersDown())
            { report("unsupported"); return; }
            if (addExclusion)
            {
                var words = Layouts.ExclusionsFromSelection(result.Text);
                if (words.Length == 0) { report("selectionTooLong"); return; }
                add(words); report("added");
            }
            else
            {
                var changed = Layouts.ConvertSelection(result.Text);
                if (changed == result.Text) { report("unchanged"); return; }
                bool Current() => !disposed && revision == state.Revision && Native.GetForegroundWindow() == window &&
                    Native.Focus(window) == result.Focus && !Native.ModifiersDown();
                var replaced = Replace(result, 0, changed, Current);
                if (replaced != ReplacementResult.Sent) { if (replaced == ReplacementResult.Failed) report("inputFailed"); return; }
                if (await VerifyReplacement(result, changed, revision)) report("converted");
            }
        }
        catch (Exception ex) when (ex is not OutOfMemoryException) { report("unsupported"); }
        finally
        {
            if (work is { IsCompleted: false }) _ = work.ContinueWith(t => { _ = t.Exception; Post(() => busy = false); }, TaskScheduler.Default);
            else busy = false;
        }
    }
    private static ReplacementResult Replace(TextSnapshot snapshot, int deleteCount, string replacement, Func<bool> current)
    {
        if (!current()) return ReplacementResult.Cancelled;
        if (snapshot.NativeEdit is { } editor) return NativeEdit.Replace(editor, deleteCount, replacement, current);
        return Native.Replace(deleteCount, replacement) ? ReplacementResult.Sent : ReplacementResult.Failed;
    }
    private async Task<bool> VerifyReplacement(TextSnapshot snapshot, string replacement, long revision)
    {
        // SendInput reports queued events, not text accepted by the editor.
        // Keep the single worker occupied until that result is checked. Never
        // retry a destructive replacement or restore over subsequent user input.
        for (int i = 0; i < 6; i++)
        {
            if (disposed || state.Revision != revision || Native.GetForegroundWindow() != snapshot.Window || Native.Focus(snapshot.Window) != snapshot.Focus) return false;
            bool visible;
            try { visible = await Task.Run(() => TextAccess.ReplacementVisible(snapshot, replacement)); }
            catch (Exception ex) when (ex is not OutOfMemoryException) { visible = false; }
            if (disposed || state.Revision != revision || Native.GetForegroundWindow() != snapshot.Window || Native.Focus(snapshot.Window) != snapshot.Focus) return false;
            if (visible) return true;
            await Task.Delay(20);
        }
        if (disposed || state.Revision != revision || Native.GetForegroundWindow() != snapshot.Window || Native.Focus(snapshot.Window) != snapshot.Focus) return false;
        state.Invalidate(); report("inputFailed"); return false;
    }
    private void Post(Action action) { if (!disposed && !dispatcher.IsDisposed) try { dispatcher.BeginInvoke(action); } catch (InvalidOperationException) { } }
    public void Dispose()
    {
        disposed = true; timer.Stop(); timer.Dispose(); state.Invalidate();
        if (keyboard != 0) Native.UnhookWindowsHookEx(keyboard);
        if (mouse != 0) Native.UnhookWindowsHookEx(mouse);
        keyboard = mouse = 0;
    }
}
