using System.Diagnostics;
using System.Globalization;
using System.Reflection;
using KiYo.Core;
using Microsoft.Win32;
namespace KiYo.Windows;
internal static class Program
{
    [STAThread]
    private static void Main()
    {
        using var mutex = new Mutex(true, @"Local\RavenSystems.KiYo.Windows", out var first);
        if (!first)
        {
            try { using var signal = EventWaitHandle.OpenExisting(@"Local\RavenSystems.KiYo.ShowSettings"); signal.Set(); }
            catch (WaitHandleCannotBeOpenedException) { }
            return;
        }
        System.Windows.Forms.Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        System.Windows.Forms.Application.SetColorMode(SystemColorMode.System);
        System.Windows.Forms.Application.EnableVisualStyles();
        System.Windows.Forms.Application.SetCompatibleTextRenderingDefault(false);
        using var app = new TrayApp();
        System.Windows.Forms.Application.Run(app);
        mutex.ReleaseMutex();
    }
}
internal sealed class HotkeyWindow : NativeWindow, IDisposable
{
    internal Action<int>? Pressed;
    internal HotkeyWindow() => CreateHandle(new CreateParams { Caption = "KiYo shortcuts", Parent = new nint(-3) });
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == Native.WmHotkey) Pressed?.Invoke((int)m.WParam);
        base.WndProc(ref m);
    }
    internal bool Register(int id, Shortcut shortcut) => Native.RegisterHotKey(Handle, id, shortcut.Modifiers | 0x4000, shortcut.Key);
    internal void Clear() { Native.UnregisterHotKey(Handle, 1); Native.UnregisterHotKey(Handle, 2); }
    public void Dispose() { Clear(); DestroyHandle(); }
}
internal sealed class TrayApp : ApplicationContext
{
    private readonly string settingsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RavenSystems", "KiYo", "settings.json");
    private Preferences preferences;
    private readonly Control dispatcher = new();
    private readonly NotifyIcon tray;
    private readonly Icon icon;
    private readonly HotkeyWindow hotkeys = new();
    private readonly EventWaitHandle reopen = new(false, EventResetMode.AutoReset, @"Local\RavenSystems.KiYo.ShowSettings");
    private readonly RegisteredWaitHandle reopenWait;
    private InputService? input;
    private SettingsForm? settings;
    private bool exiting;
    internal bool Russian => preferences.Language == "ru" || preferences.Language == "system" && CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "ru";
    internal string T(string ru, string en) => Russian ? ru : en;
    internal TrayApp()
    {
        preferences = Preferences.Read(settingsPath);
        _ = dispatcher.Handle;
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("KiYo.Windows.Assets.KiYo.ico")!;
        icon = new Icon(stream);
        tray = new NotifyIcon { Icon = icon, Visible = true, Text = "KiYo" };
        tray.DoubleClick += (_, _) => ShowSettings();
        hotkeys.Pressed = id => input?.Selection(id == 2, words => Save(preferences with { Exclusions = preferences.Exclusions.Concat(words).Distinct().ToArray() }));
        reopenWait = ThreadPool.RegisterWaitForSingleObject(reopen, (_, _) =>
        {
            if (!exiting) try { dispatcher.BeginInvoke(ShowSettings); } catch (InvalidOperationException) { }
        }, null, Timeout.Infinite, false);
        RefreshMenu();
        dispatcher.BeginInvoke(() =>
        {
            try { input = new InputService(dispatcher, () => preferences, Report); }
            catch (Exception ex) when (ex is not OutOfMemoryException) { Report("hookFailed"); }
            RegisterShortcuts();
            if (!preferences.WelcomeShown)
            {
                Save(preferences with { WelcomeShown = true });
                ShowSettings();
            }
            RefreshMenu();
        });
    }
    internal void ShowSettings()
    {
        if (exiting) return;
        if (settings is { IsDisposed: false }) { settings.Show(); settings.WindowState = FormWindowState.Normal; settings.Activate(); return; }
        input?.Reset();
        settings = new SettingsForm(this, preferences, icon, p =>
        {
            Save(p);
            RegisterShortcuts();
        });
        settings.Show(); settings.Activate();
    }
    private void Save(Preferences value)
    {
        var old = preferences;
        preferences = value.Normalize();
        try { preferences.Save(settingsPath); }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        { preferences = old; MessageBox.Show(T("Не удалось сохранить настройки.", "Could not save settings."), "KiYo"); }
        input?.Reset(); RefreshMenu();
    }
    private void RegisterShortcuts()
    {
        hotkeys.Clear();
        var convert = hotkeys.Register(1, preferences.ConvertShortcut);
        var exclude = hotkeys.Register(2, preferences.ExcludeShortcut);
        if (!convert || !exclude) Report("shortcutBusy");
    }
    private void RefreshMenu()
    {
        var old = tray.ContextMenuStrip;
        var menu = new ContextMenuStrip();
        menu.Items.Add(T("Настройки…", "Settings…"), null, (_, _) => ShowSettings());
        var pause = menu.Items.Add(preferences.Enabled ? T("Приостановить", "Pause") : T("Включить автосмену", "Enable auto correction"), null,
            (_, _) => Save(preferences with { Enabled = !preferences.Enabled }));
        pause.Enabled = input?.Available ?? false;
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(T("Ошибка или идея?", "Bug or idea?"), null, (_, _) => Feedback());
        menu.Items.Add(T("О KiYo", "About KiYo"), null, (_, _) => About());
        menu.Items.Add(T("Завершить", "Quit"), null, (_, _) => ExitThread());
        tray.ContextMenuStrip = menu; old?.Dispose();
        tray.Text = "KiYo — " + (input?.Available != true ? T("ввод недоступен", "input unavailable") : preferences.Enabled ? T("автосмена включена", "auto correction on") : T("пауза", "paused"));
    }
    internal void Report(string code)
    {
        var text = code switch
        {
            "added" => T("Выделенные слова добавлены в исключения.", "Selected words added to exceptions."),
            "converted" => T("Раскладка выделенного текста исправлена.", "Selected text converted."),
            "unchanged" => T("В выделении нет символов для смены раскладки.", "No layout characters to convert in the selection."),
            "shortcutBusy" => T("Сочетание занято другой программой. Выберите другое в настройках.", "A shortcut is in use by another app. Choose another in Settings."),
            "hookFailed" => T("Не удалось подключить обработку ввода. Перезапустите KiYo.", "Could not start keyboard observation. Restart KiYo."),
            "inputFailed" => T("Windows не разрешила заменить текст. Проверьте результат; автосмена приостановлена.", "Windows could not complete text replacement. Check the text; auto correction is paused."),
            "busy" => T("Редактор ещё отвечает. Попробуйте снова.", "The editor is still responding. Try again."),
            "selectionTooLong" => T("Выделите до 512 символов для добавления в исключения.", "Select up to 512 characters to add exceptions."),
            _ => T("Выделите текст в доступном для редактирования поле. Этот редактор может не поддерживаться.", "Select text in an editable field. This editor may be unsupported.")
        };
        if (code == "inputFailed") Save(preferences with { Enabled = false });
        tray.ShowBalloonTip(3500, "KiYo", text, ToolTipIcon.Info);
    }
    internal void About() => MessageBox.Show(T(
        "KiYo для Windows · 0.1.0-alpha.1\n\nАвтосмена русской и английской раскладки.\nТекст обрабатывается локально.\n\nRaven Systems — https://ravensystems.io/\n\nЛицензия и конфиденциальность находятся рядом с KiYo.exe.",
        "KiYo for Windows · 0.1.0-alpha.1\n\nAutomatic Russian/English layout correction.\nText is processed locally.\n\nRaven Systems — https://ravensystems.io/\n\nLicense and privacy information are included beside KiYo.exe."), "KiYo", MessageBoxButtons.OK, MessageBoxIcon.Information);
    internal void Feedback()
    {
        var choice = MessageBox.Show(T("Сообщить об ошибке?\nДа — ошибка, Нет — предложение.", "Report a bug?\nYes — bug report, No — feature request."), "KiYo", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
        if (choice == DialogResult.Cancel) return;
        Open("mailto:dev@ravensystems.io?subject=" + Uri.EscapeDataString(choice == DialogResult.Yes ? "KiYo Windows — Bug report" : "KiYo Windows — Feature request"));
    }
    internal static void Open(string url)
    {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
        catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or InvalidOperationException) { MessageBox.Show(url, "KiYo"); }
    }
    protected override void ExitThreadCore()
    {
        exiting = true; reopenWait.Unregister(null); input?.Dispose(); hotkeys.Dispose();
        tray.Visible = false; tray.Dispose(); icon.Dispose(); settings?.Dispose(); dispatcher.Dispose(); reopen.Dispose();
        base.ExitThreadCore();
    }
}
internal static class Startup
{
    private const string Key = @"Software\Microsoft\Windows\CurrentVersion\Run";
    internal static bool Enabled
    {
        get { using var key = Registry.CurrentUser.OpenSubKey(Key); return key?.GetValue("KiYo") is string value && value == Command; }
    }
    private static string Command => "\"" + Environment.ProcessPath + "\"";
    internal static void Set(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(Key);
        if (enabled) key.SetValue("KiYo", Command, RegistryValueKind.String);
        else key.DeleteValue("KiYo", false);
    }
}
