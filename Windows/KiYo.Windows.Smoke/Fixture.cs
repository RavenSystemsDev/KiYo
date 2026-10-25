using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using KiYo.Windows;
using KiYo.Core;
using Forms = System.Windows.Forms;
internal static class Fixture
{
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(nint window);
    private static string Body(string mode) => mode switch
    {
        "burst" => "ghbdtn hi rfr ltkf ", "partial" => "ghbdtn r", _ => "ghbdtn "
    };
    private static string Prefix(string mode) => mode == "prefixed" ? "😀 untouched " : "";
    internal static void Run(string mode, string file)
    {
        var thread = new Thread(() =>
        {
            Forms.Application.EnableVisualStyles();
            using var form = new Forms.Form { Text = "KiYo isolated input test", Width = 480, Height = 200 };
            Forms.TextBoxBase editor = mode == "password" ? new Forms.TextBox { UseSystemPasswordChar = true } : new Forms.RichTextBox();
            if (mode == "email") editor.AccessibleName = "Email address";
            editor.Dock = Forms.DockStyle.Fill; editor.Text = Prefix(mode) + Body(mode); editor.ReadOnly = mode == "readonly";
            form.Controls.Add(editor);
            using var timer = new Forms.Timer { Interval = 50 };
            timer.Tick += (_, _) =>
            {
                if (File.Exists(file + ".change"))
                {
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
                File.WriteAllText(file, form.Handle.ToInt64().ToString()); timer.Start();
            };
            Forms.Application.Run(form);
        });
        thread.SetApartmentState(ApartmentState.STA); thread.Start(); thread.Join();
    }
    internal static void Verify()
    {
        foreach (var mode in new[] { "editable", "selected", "password", "readonly", "email", "burst", "partial", "prefixed", "changed", "caret" })
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
                var snapshot = TextAccess.Read(window, mode == "selected" ? null : Body(mode));
                if (mode is "password" or "readonly" or "email")
                {
                    if (snapshot != null) throw new Exception("Protected fixture accepted: " + mode);
                    Console.WriteLine("PASS: " + mode + " field rejected");
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
                var pending = new TypingState(); pending.Context(window, 0x409);
                foreach (var c in Body(mode)) if (c == ' ') pending.Space(DateTimeOffset.UtcNow); else pending.Character(c);
                var plan = PhraseCorrection.Analyze(pending.Snapshot()!, (raw, candidate) => Layouts.CorrectBuffered(raw, candidate, true, []));
                var expectedText = Prefix(mode) + plan.Replacement;
                if (Native.GetForegroundWindow() != window) throw new Exception("Focus changed before test injection");
                if (!Native.Replace(mode == "selected" ? 0 : Body(mode).Length, mode == "selected" ? "привет" : plan.Replacement)) throw new Exception("SendInput test failed");
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
                Console.WriteLine("PASS: UIA " + mode + " text and SendInput replacement in isolated child process");
            }
            finally
            {
                if (!child.HasExited) { child.Kill(); child.WaitForExit(); }
                File.Delete(file); File.Delete(file + ".text"); File.Delete(file + ".change");
            }
        }
    }
}
