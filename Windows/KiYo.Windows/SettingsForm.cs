using KiYo.Core;
namespace KiYo.Windows;
internal sealed class SettingsForm : Form
{
    private readonly TrayApp app;
    private Shortcut convert, exclude;
    internal SettingsForm(TrayApp app, Preferences prefs, Icon icon, Action<Preferences> save)
    {
        this.app = app; convert = prefs.ConvertShortcut; exclude = prefs.ExcludeShortcut;
        Text = app.T("Настройки KiYo", "KiYo settings"); Icon = icon;
        Font = new Font("Segoe UI", 10); AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(540, 700); MinimumSize = new Size(540, 600);
        StartPosition = FormStartPosition.CenterScreen;
        var body = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(22), ColumnCount = 2, AutoScroll = true };
        body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 53)); body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 47));
        Controls.Add(body);
        int row = 0;
        void Full(Control control, int height)
        {
            control.Dock = DockStyle.Fill; control.Margin = new Padding(0, 0, 0, 12);
            body.RowStyles.Add(new RowStyle(SizeType.Absolute, height)); body.Controls.Add(control, 0, row++); body.SetColumnSpan(control, 2);
        }
        void Row(string label, Control control, int height = 44)
        {
            var caption = new Label { Text = label, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, AutoEllipsis = true };
            control.Dock = DockStyle.Fill; control.Margin = new Padding(0, 5, 0, 5);
            body.RowStyles.Add(new RowStyle(SizeType.Absolute, height)); body.Controls.Add(caption, 0, row); body.Controls.Add(control, 1, row++);
        }
        Full(new Label { Text = app.T("KiYo живёт возле часов. Исправляет раскладку после пробела в поддерживаемых редакторах. Текст остаётся на компьютере.", "Find KiYo beside the clock. It corrects the layout after a space in supported editors. Text stays on your computer."), AutoSize = false }, 70);
        var language = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList };
        language.Items.AddRange(new object[] { app.T("Как в системе", "System language"), "Русский", "English" });
        language.SelectedIndex = prefs.Language == "ru" ? 1 : prefs.Language == "en" ? 2 : 0;
        Row(app.T("Язык приложения", "App language"), language);
        var launch = new CheckBox { Checked = Startup.Enabled, Text = app.T("Включить", "Enable"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(app.T("Запуск при входе", "Launch at login"), launch);
        var enabled = new CheckBox { Checked = prefs.Enabled, Text = app.T("Включить", "Enable"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(app.T("Автоисправление", "Auto correction"), enabled);
        var spelling = new CheckBox { Checked = prefs.SpellingEnabled, Text = app.T("Включить", "Enable"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(app.T("Исправление орфографии", "Spelling correction"), spelling);
        var shorts = new CheckBox { Checked = prefs.ShortWords, Text = app.T("Включить", "Enable"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(app.T("Короткие слова", "Short words"), shorts);
        var dictionary = new CheckBox { Checked = prefs.UseSystemDictionary, Text = app.T("Использовать", "Use"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(app.T("Словарь для раскладки", "Layout dictionary"), dictionary);
        var dictionaryStatus = new Label { Text = app.T("Словари Windows: проверяем…", "Windows dictionaries: checking…"), AutoSize = false };
        Full(dictionaryStatus, 34);
        Shown += async (_, _) =>
        {
            var available = await Task.Run(() =>
            {
                using var system = new SystemDictionary();
                return (Russian: system.Available(true), English: system.Available(false));
            });
            if (IsDisposed || dictionaryStatus.IsDisposed) return;
            string Status(bool present) => present ? app.T("есть", "installed") : app.T("нет", "missing");
            dictionaryStatus.Text = app.T("Словари Windows: ", "Windows dictionaries: ") +
                $"RU — {Status(available.Russian)}, EN — {Status(available.English)}";
        };
        var convertButton = new Button { Text = convert.ToString() };
        convertButton.Click += (_, _) => { var chosen = Record(convert, exclude); if (chosen != null) { convert = chosen; convertButton.Text = chosen.ToString(); } };
        Row(app.T("Исправить выделение", "Convert selection"), convertButton);
        var excludeButton = new Button { Text = exclude.ToString() };
        excludeButton.Click += (_, _) => { var chosen = Record(exclude, convert); if (chosen != null) { exclude = chosen; excludeButton.Text = chosen.ToString(); } };
        Row(app.T("Добавить в исключения", "Exclude selection"), excludeButton);
        Full(new Label { Text = app.T("Исключения — по одному слову в строке. Не добавляйте пароли.", "Exceptions — one word per line. Do not enter passwords."), AutoSize = false }, 34);
        var words = new TextBox { Multiline = true, ScrollBars = ScrollBars.Vertical, Text = string.Join(Environment.NewLine, prefs.Exclusions), MaxLength = 128000 };
        Full(words, 120);
        Full(new Label { Text = app.T("Орфография исправляется после пробела через словари Windows для русского и английского. Неоднозначные варианты и защищённые поля пропускаются. Нужен установленный словарь языка.", "Spelling is corrected after a space using Russian and English Windows dictionaries. Ambiguous suggestions and protected fields are skipped. The language dictionary must be installed."), AutoSize = false }, 84);
        var footer = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft };
        var apply = new Button { Text = app.T("Сохранить", "Save"), AutoSize = true };
        apply.Click += (_, _) =>
        {
            try { Startup.Set(launch.Checked); }
            catch (Exception ex) when (ex is UnauthorizedAccessException or System.Security.SecurityException or IOException)
            { MessageBox.Show(app.T("Не удалось изменить автозапуск.", "Could not change launch at login."), "KiYo"); return; }
            save(prefs with { Enabled = enabled.Checked, ShortWords = shorts.Checked, UseSystemDictionary = dictionary.Checked, SpellingEnabled = spelling.Checked,
                Language = language.SelectedIndex == 1 ? "ru" : language.SelectedIndex == 2 ? "en" : "system",
                ConvertShortcut = convert, ExcludeShortcut = exclude, Exclusions = words.Lines });
            Close();
        };
        var feedback = new Button { Text = app.T("Ошибка или идея?", "Bug or idea?"), AutoSize = true };
        feedback.Click += (_, _) => app.Feedback();
        footer.Controls.Add(apply); footer.Controls.Add(feedback); Full(footer, 48);
        var author = new LinkLabel { Text = "Raven Systems · ravensystems.io", TextAlign = ContentAlignment.MiddleCenter };
        author.LinkClicked += (_, _) => TrayApp.Open("https://ravensystems.io/"); Full(author, 30);
        AcceptButton = apply;
    }
    private Shortcut? Record(Shortcut current, Shortcut other)
    {
        using var dialog = new ShortcutForm(app, current, other);
        return dialog.ShowDialog(this) == DialogResult.OK ? dialog.Result : null;
    }
}
internal sealed class ShortcutForm : Form
{
    private readonly TrayApp app;
    private readonly Shortcut other;
    private readonly Label prompt;
    internal Shortcut? Result { get; private set; }
    internal ShortcutForm(TrayApp app, Shortcut current, Shortcut other)
    {
        this.app = app; this.other = other;
        Text = app.T("Горячая клавиша", "Keyboard shortcut"); ClientSize = new Size(410, 160);
        StartPosition = FormStartPosition.CenterParent; FormBorderStyle = FormBorderStyle.FixedDialog; MinimizeBox = MaximizeBox = false;
        prompt = new Label { Dock = DockStyle.Fill, Padding = new Padding(20), Font = new Font("Segoe UI", 11), Text =
            app.T("Нажмите Ctrl или Alt вместе с буквой, цифрой или F-клавишей. Можно добавить Shift.\nEsc — отмена.\nСейчас: ", "Press Ctrl or Alt with a letter, number or F-key. You can add Shift.\nEsc cancels.\nCurrent: ") + current };
        Controls.Add(prompt);
    }
    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData == Keys.Escape) { DialogResult = DialogResult.Cancel; Close(); return true; }
        uint modifiers = (keyData.HasFlag(Keys.Control) ? 2u : 0) | (keyData.HasFlag(Keys.Alt) ? 1u : 0) | (keyData.HasFlag(Keys.Shift) ? 4u : 0);
        var key = (uint)(keyData & Keys.KeyCode);
        var value = new Shortcut(modifiers, key);
        if (!value.Valid) return true;
        if (value == other) { prompt.Text = app.T("Это сочетание уже используется KiYo.", "KiYo already uses this shortcut."); return true; }
        Result = value; DialogResult = DialogResult.OK; Close(); return true;
    }
}
