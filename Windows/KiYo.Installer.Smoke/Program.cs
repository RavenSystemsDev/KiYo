using System.IO;
using System.Text;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Reflection.PortableExecutable;
using System.Runtime.InteropServices;
using System.Windows.Automation;
using Microsoft.Win32;

// This test installs only on a fresh disposable GitHub runner, never on a user's PC.
if (!OperatingSystem.IsWindows() || Environment.GetEnvironmentVariable("GITHUB_ACTIONS") != "true")
    throw new InvalidOperationException("Installer tests require a disposable Windows GitHub Actions runner.");
if (args.Length != 2) throw new ArgumentException("Expected installer and evidence directory.");
var setup = Path.GetFullPath(args[0]);
var evidence = Path.GetFullPath(args[1]);
Directory.CreateDirectory(evidence);
var target = Path.Combine(Path.GetTempPath(), "KiYo-install-test-" + Guid.NewGuid(), "KiYo");
var executable = Path.Combine(target, "KiYo.exe");
var preferencesDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RavenSystems", "KiYo");
var preferences = Path.Combine(preferencesDirectory, "settings.json");
var shortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "KiYo.lnk");
var desktopShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "KiYo.lnk");
const string uninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\{E9DA26F5-7C42-4B65-9E38-6A75434CFC81}_is1";
const string runKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
using (var uninstall = Registry.CurrentUser.OpenSubKey(uninstallKey))
using (var startup = Registry.CurrentUser.OpenSubKey(runKey))
{
    Check(uninstall is null && startup?.GetValue("KiYo") is null && !Directory.Exists(preferencesDirectory)
        && !File.Exists(shortcut) && !File.Exists(desktopShortcut) && Process.GetProcessesByName("KiYo").Length == 0,
        "Runner must not contain an existing KiYo installation or preferences");
}
var children = new List<Process>();
try
{
    var installer = Start(setup, $"/LANG=russian /DIR=\"{target}\" /LOG=\"{evidence}/install-ru.log\" /SP-");
    Wait(() => InstallerWindow() is not null && Find(InstallerWindow()!, "Установить") is not null);
    var window = InstallerWindow()!;
    Click(window, "Параметры установки");
    Wait(() => Dialog("Параметры установки") is not null);
    var options = Dialog("Параметры установки")!;
    Toggle(options, "Ярлык на рабочем столе");
    Capture(options, "00-options-ru.png");
    Click(options, "Сохранить");
    Click(window, "Лицензия");
    Wait(() => Dialog("Лицензия KiYo") is not null);
    Capture(Dialog("Лицензия KiYo")!, "00-license.png");
    Click(Dialog("Лицензия KiYo")!, "Готово");
    Capture(window, "01-welcome-ru.png");
    var clickInstall = Task.Run(() => Click(window, "Установить"));
    Wait(() => Find(window, "Устанавливаем KiYo") is not null || Find(window, "KiYo готов к работе") is not null);
    Capture(window, "02-progress-ru.png");
    Wait(() => Find(window, "KiYo готов к работе") is not null, 120_000);
    clickInstall.GetAwaiter().GetResult();
    Check(File.Exists(executable) && File.Exists(Path.Combine(target, "unins000.exe")), "Installed app and uninstaller exist");
    Check(File.Exists(shortcut) && File.Exists(desktopShortcut), "Start Menu and selected desktop shortcuts exist");
    using (var stream = File.OpenRead(executable))
    using (var pe = new PEReader(stream))
        Check(pe.PEHeaders.CoffHeader.Machine == Machine.Amd64, "x64 runner received x64 payload");
    foreach (var file in new[] { "LICENSE.txt", "PRIVACY.txt", "THIRD-PARTY-NOTICES.txt", "KiYo.runtimeconfig.json" })
        Check(File.Exists(Path.Combine(target, file)), "Installed " + file);
    Check(Directory.EnumerateFiles(Path.Combine(target, "runtime-notices"), "*", SearchOption.AllDirectories).Count() >= 4, "Runtime notices installed");
    using (var key = Registry.CurrentUser.OpenSubKey(uninstallKey))
    {
        Check(key?.GetValue("DisplayName") is string name && name.Contains("KiYo"), "Registered in Windows Apps");
        Check(key?.GetValue("DisplayVersion") as string == "0.1.0-alpha.5", "Installed version is alpha.5");
    }
    Check(State(window, "Запускать при входе в Windows") == ToggleState.Off, "Autostart defaults off");
    Toggle(window, "Запускать при входе в Windows");
    Directory.CreateDirectory(preferencesDirectory);
    const string sample = "{\"WelcomeShown\":true,\"Enabled\":false,\"Language\":\"ru\",\"Exclusions\":[\"installertestword\"]}";
    File.WriteAllText(preferences, sample);
    Capture(window, "03-ready-ru.png");
    Click(window, "Запустить KiYo");
    Wait(() => Process.GetProcessesByName("KiYo").Any(p => p.MainModule?.FileName == executable));
    var app = Process.GetProcessesByName("KiYo").Single(p => p.MainModule?.FileName == executable);
    children.Add(app);
    Thread.Sleep(1500);
    Check(Mutex.TryOpenExisting(@"Local\RavenSystems.KiYo.Windows", out var appMutex) && !app.HasExited, "Installed app launches and owns its single-instance mutex");
    appMutex?.Dispose();
    WaitExit(installer, 0);
    using (var key = Registry.CurrentUser.OpenSubKey(runKey))
        Check(key?.GetValue("KiYo") as string == '"' + executable + '"', "Selected autostart uses the installed executable");
    // AppMutex must reject an unattended update while KiYo is still running.
    var blocked = SilentInstall("blocked-update");
    Wait(() => blocked.HasExited, 45_000);
    Check(blocked.ExitCode != 0 && !app.HasExited, "Running-app update rejected without terminating KiYo");
    app.Kill(); app.WaitForExit();
    var beforeUpdate = File.ReadAllText(preferences);
    WaitExit(SilentInstall("upgrade"), 0);
    Check(File.ReadAllText(preferences) == beforeUpdate, "Update preserves settings and exclusions");
    using (var key = Registry.CurrentUser.OpenSubKey(runKey))
        Check(key?.GetValue("KiYo") as string == '"' + executable + '"', "Unattended update preserves autostart");
    // Exercise the second locale and the explicit close-without-launch action on update.
    installer = Start(setup, $"/LANG=english /DIR=\"{target}\" /LOG=\"{evidence}/update-en.log\" /SP-");
    Wait(() => InstallerWindow() is not null && Find(InstallerWindow()!, "Install") is not null);
    window = InstallerWindow()!;
    Capture(window, "04-welcome-en.png");
    var clickUpdate = Task.Run(() => Click(window, "Install"));
    Wait(() => Find(window, "KiYo is ready") is not null, 120_000);
    clickUpdate.GetAwaiter().GetResult();
    Check(State(window, "Launch when I sign in to Windows") == ToggleState.On, "Interactive update remembers autostart");
    Capture(window, "05-ready-en.png");
    Click(window, "Close installer");
    WaitExit(installer, 0);
    Check(Process.GetProcessesByName("KiYo").Length == 0, "Close does not launch the app");
    Check(File.ReadAllText(preferences) == beforeUpdate, "Interactive update preserves preferences");
    Uninstall("uninstall");
    Check(!File.Exists(executable) && !File.Exists(shortcut) && !File.Exists(desktopShortcut), "Uninstall removes app and shortcuts");
    using (var key = Registry.CurrentUser.OpenSubKey(uninstallKey)) Check(key is null, "Uninstall removes Apps registration");
    using (var key = Registry.CurrentUser.OpenSubKey(runKey)) Check(key?.GetValue("KiYo") is null, "Uninstall removes matching autostart");
    Check(File.ReadAllText(preferences) == beforeUpdate, "Uninstall preserves user settings and exceptions");
    WaitExit(SilentInstall("reinstall"), 0);
    using (var key = Registry.CurrentUser.CreateSubKey(runKey)) key.SetValue("KiYo", @"""C:\PortableKiYo\KiYo.exe""");
    Uninstall("uninstall-foreign-startup");
    using (var key = Registry.CurrentUser.OpenSubKey(runKey))
        Check(key?.GetValue("KiYo") as string == @"""C:\PortableKiYo\KiYo.exe""", "Uninstall leaves another copy's autostart alone");
    Console.WriteLine("PASS: installer RU/EN UI, launch, architecture, shortcuts, notices, running-app protection, update, uninstall and retained preferences.");
}
catch
{
    foreach (AutomationElement candidate in AutomationElement.RootElement.FindAll(TreeScope.Children, Condition.TrueCondition))
    {
        try
        {
            var process = Process.GetProcessById(candidate.Current.ProcessId);
            if (!IsInstallerPath(process.MainModule?.FileName)) continue;
            Capture(candidate, "failure-" + process.Id + ".png");
            var lines = candidate.FindAll(TreeScope.Descendants, Condition.TrueCondition).Cast<AutomationElement>()
                .Take(250).Select(e => $"{e.Current.ControlType.ProgrammaticName}: {e.Current.Name} [offscreen={e.Current.IsOffscreen}]");
            File.WriteAllLines(Path.Combine(evidence, "failure-ui.txt"), lines);
        }
        catch (Exception diagnosticError) { Console.WriteLine("Diagnostic capture: " + diagnosticError.Message); }
    }
    throw;
}
finally
{
    foreach (var process in children)
        try { if (!process.HasExited) { process.Kill(true); process.WaitForExit(5000); } } catch (InvalidOperationException) { }
    // All of these paths/values were verified absent before the test.
    using (var key = Registry.CurrentUser.OpenSubKey(runKey, writable: true)) key?.DeleteValue("KiYo", throwOnMissingValue: false);
    Registry.CurrentUser.DeleteSubKeyTree(uninstallKey, throwOnMissingSubKey: false);
    foreach (var path in new[] { shortcut, desktopShortcut }) if (File.Exists(path)) File.Delete(path);
    if (Directory.Exists(preferencesDirectory)) Directory.Delete(preferencesDirectory, true);
    if (Directory.Exists(Path.GetDirectoryName(target)!)) Directory.Delete(Path.GetDirectoryName(target)!, true);
}

Process Start(string file, string arguments)
{
    var process = Process.Start(new ProcessStartInfo(file, arguments) { UseShellExecute = false })!;
    children.Add(process);
    return process;
}
Process SilentInstall(string name) => Start(setup, $"/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=\"{target}\" /LOG=\"{evidence}/{name}.log\"");
void Uninstall(string name)
{
    var process = Start(Path.Combine(target, "unins000.exe"), $"/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=\"{evidence}/{name}.log\"");
    WaitExit(process, 0);
    Wait(() => !File.Exists(executable));
}
static void Check(bool condition, string message)
{
    if (!condition) throw new Exception(message);
    Console.WriteLine("PASS: " + message);
}
static void Wait(Func<bool> condition, int timeout = 30_000)
{
    var watch = Stopwatch.StartNew();
    do
    {
        try { if (condition()) return; } catch (ElementNotAvailableException) { }
        Thread.Sleep(100);
    } while (watch.ElapsedMilliseconds < timeout);
    throw new TimeoutException("Installer test condition timed out.");
}
static void WaitExit(Process process, int expected)
{
    if (!process.WaitForExit(120_000)) throw new TimeoutException("Installer process did not exit.");
    Check(process.ExitCode == expected, "Process exit code " + expected);
}
static AutomationElement? Dialog(string title)
{
    foreach (AutomationElement window in AutomationElement.RootElement.FindAll(TreeScope.Children, Condition.TrueCondition))
    {
        try
        {
            var process = Process.GetProcessById(window.Current.ProcessId);
            if (!IsInstallerPath(process.MainModule?.FileName)) continue;
            if (window.Current.Name == title) return window;
            // VCL owned modal windows are UIA descendants of the installer,
            // not necessarily immediate desktop children.
            var owned = window.FindFirst(TreeScope.Descendants, new AndCondition(
                new PropertyCondition(AutomationElement.NameProperty, title),
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Window)));
            if (owned is not null) return owned;
        }
        catch (ArgumentException) { }
    }
    return null;
}
static bool IsInstallerPath(string? path)
{
    if (path is null || !Path.GetFileName(path).StartsWith("KiYo-Setup", StringComparison.OrdinalIgnoreCase)) return false;
    // Inno uses an 8.3 temporary path (RUNNER~1); compare the expanded path.
    var expanded = new StringBuilder(32768);
    if (Native.GetLongPathName(path, expanded, expanded.Capacity) == 0) return false;
    return expanded.ToString().StartsWith(Path.GetTempPath(), StringComparison.OrdinalIgnoreCase);
}
static AutomationElement? InstallerWindow() => Dialog("KiYo");
static AutomationElement? Find(AutomationElement window, string name) => window.FindFirst(TreeScope.Descendants,
    new AndCondition(new PropertyCondition(AutomationElement.NameProperty, name), new PropertyCondition(AutomationElement.IsOffscreenProperty, false)));
static void Click(AutomationElement window, string name)
{
    AutomationElement? button = null;
    // Invocations are asynchronous; a preceding modal may still be closing.
    Wait(() => (button = Find(window, name)) is not null && button.Current.IsEnabled, 10_000);
    ((InvokePattern)button!.GetCurrentPattern(InvokePattern.Pattern)).Invoke();
}
static ToggleState State(AutomationElement window, string name) =>
    ((TogglePattern)(Find(window, name) ?? throw new Exception("Checkbox not found: " + name)).GetCurrentPattern(TogglePattern.Pattern)).Current.ToggleState;
static void Toggle(AutomationElement window, string name) =>
    ((TogglePattern)(Find(window, name) ?? throw new Exception("Checkbox not found: " + name)).GetCurrentPattern(TogglePattern.Pattern)).Toggle();
void Capture(AutomationElement window, string name)
{
    // Capture only the installer-owned window on the isolated runner for visual review.
    Native.SetForegroundWindow((nint)window.Current.NativeWindowHandle);
    Thread.Sleep(150);
    var bounds = window.Current.BoundingRectangle;
    // Exclude Windows' invisible resize border, which otherwise captures desktop pixels.
    if (Native.DwmGetWindowAttribute((nint)window.Current.NativeWindowHandle, 9, out var frame, Marshal.SizeOf<Native.Rect>()) == 0)
        bounds = new System.Windows.Rect(frame.Left, frame.Top, frame.Right - frame.Left, frame.Bottom - frame.Top);
    using var image = new Bitmap((int)bounds.Width, (int)bounds.Height);
    using var graphics = Graphics.FromImage(image);
    graphics.CopyFromScreen((int)bounds.X, (int)bounds.Y, 0, 0, image.Size);
    image.Save(Path.Combine(evidence, name), ImageFormat.Png);
}
static class Native
{
    [StructLayout(LayoutKind.Sequential)]
    internal struct Rect { internal int Left, Top, Right, Bottom; }
    [DllImport("dwmapi.dll")]
    internal static extern int DwmGetWindowAttribute(nint window, int attribute, out Rect value, int size);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    internal static extern uint GetLongPathName(string shortPath, StringBuilder longPath, int capacity);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetForegroundWindow(nint window);
}
