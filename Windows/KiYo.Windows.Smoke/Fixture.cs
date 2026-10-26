using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Automation;
using KiYo.Windows;
using KiYo.Core;
using Forms = System.Windows.Forms;
internal static class Fixture
{
    private sealed class PacketRejectingEditor : Forms.RichTextBox
    {
        protected override void WndProc(ref Forms.Message message)
        {
            // Synthetic editor compatibility failure; never used by KiYo itself.
            if (message.Msg == 0x102 && (int)message.WParam != ' ') return;
            base.WndProc(ref message);
        }
    }
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(nint window);
    private static string Body(string mode) => mode switch
    {
        "burst" => "ghbdtn hi rfr ltkf ", "partial" => "ghbdtn r",
        "spelling" => "helllo worlld ghbdtn ",
        "music-tail" => "usic ", "joined-ru" => "руддщ ", _ => "ghbdtn "
    };
    private static string Prefix(string mode) => mode switch
    {
        "prefixed" => "😀 untouched ", "joined" or "music-tail" => "m", "joined-ru" => "р", _ => ""
    };
    internal static void Run(string mode, string file)
    {
        var thread = new Thread(() =>
        {
            Forms.Application.EnableVisualStyles();
            using var form = new Forms.Form { Text = "KiYo isolated input test", Width = 480, Height = 200 };
            Forms.TextBoxBase editor = mode == "password" ? new Forms.TextBox { UseSystemPasswordChar = true } :
                mode == "packet-drop" ? new PacketRejectingEditor() : new Forms.RichTextBox();
            if (mode == "email") editor.AccessibleName = "Email address";
            editor.Dock = Forms.DockStyle.Fill; editor.Text = Prefix(mode) + Body(mode); editor.ReadOnly = mode == "readonly";
            form.Controls.Add(editor);
            using var timer = new Forms.Timer { Interval = 50 };
            timer.Tick += (_, _) =>
            {
                if (File.Exists(file + ".change"))
                {
                    if (mode == "packet-drop") { editor.Text = Body(mode); editor.Select(editor.Text.Length, 0); }
                    if (mode == "changed") { editor.Text = "broken "; editor.Select(editor.Text.Length, 0); }
                    if (mode == "caret") editor.Select(0, 0);
                    File.Delete(file + ".change");
                }
                try { File.WriteAllText(file + ".text", editor.Text); }
                catch (IOException) { /* Parent may be reading; report again next tick. */ }
            };
            form.Shown += (_, _) =>
            {
                editor.Focus();
                editor.Select(mode == "selected" ? 0 : editor.Text.Length, mode == "selected" ? 6 : 0);
                // Publish the handle only after its file is closed: the parent may
                // otherwise observe File.Exists while WriteAllText still owns the file.
                File.WriteAllText(file + ".ready", form.Handle.ToInt64().ToString());
                File.Move(file + ".ready", file); timer.Start();
            };
            Forms.Application.Run(form);
        });
        thread.SetApartmentState(ApartmentState.STA); thread.Start(); thread.Join();
    }
    internal static void Verify()
    {
        foreach (var mode in new[] { "editable", "selected", "password", "readonly", "email", "burst", "spelling", "partial", "prefixed", "joined", "joined-ru", "music-tail", "changed", "caret", "packet-drop", "cancelled" })
        {
            var file = Path.Combine(Path.GetTempPath(), "kiyo-uia-" + Guid.NewGuid());
            using var child = Process.Start(new ProcessStartInfo(Environment.ProcessPath!) { ArgumentList = { "--fixture", mode, file }, UseShellExecute = false })!;
            try
            {
                var until = DateTime.UtcNow.AddSeconds(10);
                nint window = 0;
                while (DateTime.UtcNow < until)
                {
                    if (child.HasExited) throw new Exception("Input fixture exited unexpectedly");
                    if (File.Exists(file) && long.TryParse(File.ReadAllText(file), out var handle)) { window = new nint(handle); break; }
                    Thread.Sleep(50);
                }
                if (window == 0) throw new Exception("Input fixture failed to start");
                SetForegroundWindow(window);
                Thread.Sleep(200);
                if (Native.GetForegroundWindow() != window) throw new Exception("Windows test runner has no foreground desktop for UI Automation acceptance");
                if (mode == "email")
                {
                    // Synthetic fixture metadata only; production never logs field contents.
                    var focused = AutomationElement.FocusedElement.Current;
                    Console.WriteLine($"Email fixture: UIA name='{focused.Name}', class='{focused.ClassName}', framework='{focused.FrameworkId}'");
                }
                var snapshot = TextAccess.Read(window, mode == "selected" ? null : Body(mode));
                if (mode is "password" or "readonly" or "email")
                {
                    if (snapshot != null) throw new Exception("Protected fixture accepted: " + mode);
                    Console.WriteLine("PASS: " + mode + " field rejected");
                    continue;
                }
                if (mode is "joined" or "joined-ru" or "music-tail")
                {
                    if (snapshot != null) throw new Exception("Partial word accepted: " + mode);
                    // Prove this is a boundary rejection in a supported editor,
                    // not a false pass because the entire field was unreadable.
                    var complete = TextAccess.Read(window, Prefix(mode) + Body(mode));
                    if (complete == null || !TextAccess.StillSelected(complete)) throw new Exception("Full fixture word not readable: " + mode);
                    Console.WriteLine("PASS: " + mode + " partial word rejected; complete word validated without injection");
                    continue;
                }
                if (snapshot == null || !TextAccess.StillSelected(snapshot)) throw new Exception("Editable fixture not supported: " + mode);
                if (TextAccess.Read(window, "wrong ") != null) throw new Exception("Mismatched tail accepted");
                if (mode is "changed" or "caret")
                {
                    File.WriteAllText(file + ".change", "change isolated fixture");
                    until = DateTime.UtcNow.AddSeconds(3);
                    while (File.Exists(file + ".change") && DateTime.UtcNow < until) Thread.Sleep(20);
                    if (File.Exists(file + ".change")) throw new Exception("Fixture did not acknowledge mutation");
                    if (TextAccess.StillSelected(snapshot)) throw new Exception("Stale text/caret accepted: " + mode);
                    Console.WriteLine("PASS: stale " + mode + " rejected without replacement");
                    continue;
                }
                if (snapshot.NativeEdit == null) throw new Exception("Native edit backend unavailable in fixture: " + mode);
                if (mode == "cancelled")
                {
                    if (NativeEdit.Replace(snapshot.NativeEdit, Body(mode).Length, "привет ", () => false) != ReplacementResult.Cancelled)
                        throw new Exception("Cancelled replacement was not rejected");
                    if (!TextAccess.StillSelected(snapshot)) throw new Exception("Cancelled native replacement changed text or selection");
                    Console.WriteLine("PASS: cancelled native edit leaves original text and caret intact");
                    continue;
                }
                if (mode == "packet-drop")
                {
                    // Reproduce the reported gap: an editor accepts Backspace
                    // and spaces but rejects injected letter messages. A queued
                    // SendInput batch still reports success.
                    if (!Native.Replace(Body(mode).Length, "привет ")) throw new Exception("Legacy packet test failed to queue");
                    until = DateTime.UtcNow.AddSeconds(3);
                    bool gap = false;
                    while (DateTime.UtcNow < until)
                    {
                        try { if (File.ReadAllText(file + ".text") == " ") { gap = true; break; } }
                        catch (IOException) { }
                        Thread.Sleep(30);
                    }
                    if (!gap || TextAccess.ReplacementVisible(snapshot, "привет ")) throw new Exception("Packet rejection regression was not reproduced");
                    File.WriteAllText(file + ".change", "reset synthetic editor only");
                    until = DateTime.UtcNow.AddSeconds(3);
                    while (File.Exists(file + ".change") && DateTime.UtcNow < until) Thread.Sleep(20);
                    snapshot = TextAccess.Read(window, Body(mode));
                    if (snapshot?.NativeEdit == null || !TextAccess.StillSelected(snapshot)) throw new Exception("Packet fixture reset failed");
                    Console.WriteLine("PASS: reproduced spaces-only result despite successful SendInput; readback rejects it");
                }
                var pending = new TypingState(); pending.Context(window, 0x409);
                foreach (var c in Body(mode)) if (c == ' ') pending.Space(DateTimeOffset.UtcNow); else pending.Character(c);
                using var dictionary = new SystemDictionary();
                var plan = PhraseCorrection.Analyze(pending.Snapshot()!, (raw, candidate) => Layouts.CorrectBuffered(raw, candidate, true, [], null,
                    mode == "spelling" ? text => Spelling.Correct(text, [], dictionary.Valid, dictionary.Suggest) : null));
                if (mode == "spelling" && plan.Replacement != "hello world привет ") throw new Exception("Spelling/layout phrase decision failed");
                var expectedText = Prefix(mode) + plan.Replacement;
                if (Native.GetForegroundWindow() != window) throw new Exception("Focus changed before test injection");
                var replacement = mode == "selected" ? "привет" : plan.Replacement;
                if (NativeEdit.Replace(snapshot.NativeEdit, mode == "selected" ? 0 : Body(mode).Length, replacement,
                    () => Native.GetForegroundWindow() == window && Native.Focus(window) == snapshot.Focus) != ReplacementResult.Sent)
                    throw new Exception("Native edit replacement failed");
                until = DateTime.UtcNow.AddSeconds(3);
                var changed = false;
                while (DateTime.UtcNow < until)
                {
                    try
                    {
                        if (File.Exists(file + ".text") && File.ReadAllText(file + ".text") == expectedText) { changed = true; break; }
                    }
                    catch (IOException) { /* Fixture is reporting; retry without inspecting other windows. */ }
                    Thread.Sleep(50);
                }
                if (!changed) throw new Exception("Text replacement failed in isolated fixture: " + mode);
                if (!TextAccess.ReplacementVisible(snapshot, replacement)) throw new Exception("Replacement readback failed: " + mode);
                Console.WriteLine("PASS: UIA " + mode + " text and native whole-string replacement with readback in isolated child process");
                if (mode == "editable")
                {
                    if (!Native.PostMessage(snapshot.Focus, 0xC7, 0, 0)) throw new Exception("Could not request fixture undo"); // EM_UNDO
                    until = DateTime.UtcNow.AddSeconds(3); bool undone = false;
                    while (DateTime.UtcNow < until)
                    {
                        try { if (File.ReadAllText(file + ".text") == Body(mode)) { undone = true; break; } }
                        catch (IOException) { }
                        Thread.Sleep(30);
                    }
                    if (!undone) throw new Exception("One undo did not restore the original word");
                    Console.WriteLine("PASS: native correction can be undone as one complete edit");
                }
            }
            finally
            {
                if (!child.HasExited) { child.Kill(); child.WaitForExit(); }
                File.Delete(file); File.Delete(file + ".ready"); File.Delete(file + ".text"); File.Delete(file + ".change");
            }
        }
    }
}
