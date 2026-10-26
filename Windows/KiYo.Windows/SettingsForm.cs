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
        Font = new Font("Segoe UI", 10);
        AutoScaleDimensions = new SizeF(96, 96); AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(580, 440);
        StartPosition = FormStartPosition.CenterScreen;
        var body = new TableLayoutPanel
        {
            Dock = DockStyle.Fill, Padding = new Padding(12), ColumnCount = 1, RowCount = 3
        };
        body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        body.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
        body.RowStyles.Add(new RowStyle(SizeType.Absolute, 24));
        Controls.Add(body);
        var tabs = new TabControl { Dock = DockStyle.Fill, Margin = Padding.Empty };
        body.Controls.Add(tabs, 0, 0);
        TableLayoutPanel Page(string title)
        {
            var page = new TabPage(title) { Padding = new Padding(10), UseVisualStyleBackColor = true };
            var table = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, Margin = Padding.Empty };
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 53));
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 47));
            page.Controls.Add(table); tabs.TabPages.Add(page);
            return table;
        }
        void Full(TableLayoutPanel table, Control control, int height, bool flexible = false)
        {
            control.Dock = DockStyle.Fill; control.Margin = new Padding(0, 0, 0, 4);
            int row = table.RowStyles.Count;
            table.RowStyles.Add(new RowStyle(flexible ? SizeType.Percent : SizeType.Absolute, flexible ? 100 : height));
            table.RowCount = row + 1;
            table.Controls.Add(control, 0, row); table.SetColumnSpan(control, 2);
        }
        void Row(TableLayoutPanel table, string label, Control control, int height = 32)
        {
            var caption = new Label { Text = label, Dock = DockStyle.Fill, Margin = new Padding(0, 0, 8, 0), TextAlign = ContentAlignment.MiddleLeft, AutoEllipsis = true };
            control.Dock = DockStyle.Fill; control.Margin = new Padding(0, 2, 0, 2);
            int row = table.RowStyles.Count;
            table.RowStyles.Add(new RowStyle(SizeType.Absolute, height)); table.RowCount = row + 1;
            table.Controls.Add(caption, 0, row); table.Controls.Add(control, 1, row);
        }
        var general = Page(app.T("Основные", "General"));
        var typing = Page(app.T("Сочетания и исключения", "Shortcuts and exceptions"));
        Full(general, new Label { Text = app.T("KiYo — рядом с часами. Исправления после пробела.", "Find KiYo beside the clock. Corrections after a space.") }, 26);
        var language = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList };
        language.Items.AddRange(new object[] { app.T("Как в системе", "System language"), "Русский", "English" });
        language.SelectedIndex = prefs.Language == "ru" ? 1 : prefs.Language == "en" ? 2 : 0;
        Row(general, app.T("Язык приложения", "App language"), language);
        var launch = new CheckBox { Checked = Startup.Enabled, Text = app.T("Включить", "Enable"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(general, app.T("Запуск при входе", "Launch at login"), launch);
        var enabled = new CheckBox { Checked = prefs.Enabled, Text = app.T("Включить", "Enable"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(general, app.T("Автоисправление", "Auto correction"), enabled);
        var spelling = new CheckBox { Checked = prefs.SpellingEnabled, Text = app.T("Включить", "Enable"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(general, app.T("Исправление орфографии", "Spelling correction"), spelling);
        var shorts = new CheckBox { Checked = prefs.ShortWords, Text = app.T("Включить", "Enable"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(general, app.T("Короткие слова", "Short words"), shorts);
        var dictionary = new CheckBox { Checked = prefs.UseSystemDictionary, Text = app.T("Использовать", "Use"), CheckAlign = ContentAlignment.MiddleRight, TextAlign = ContentAlignment.MiddleRight };
        Row(general, app.T("Словарь для раскладки", "Layout dictionary"), dictionary);
        var dictionaryStatus = new Label { Text = app.T("Словари Windows: проверяем…", "Windows dictionaries: checking…"), AutoSize = false };
        Full(general, dictionaryStatus, 24);
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
        Full(general, new Label { Text = app.T("Орфография использует словари Windows. Неоднозначные варианты и защищённые поля пропускаются.", "Spelling uses Windows dictionaries. Ambiguous suggestions and protected fields are skipped.") }, 44);
        general.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); general.RowCount++;
        var convertButton = new Button { Text = convert.ToString() };
        convertButton.Click += (_, _) => { var chosen = Record(convert, exclude); if (chosen != null) { convert = chosen; convertButton.Text = chosen.ToString(); } };
        Row(typing, app.T("Исправить выделение", "Convert selection"), convertButton, 38);
        var excludeButton = new Button { Text = exclude.ToString() };
        excludeButton.Click += (_, _) => { var chosen = Record(exclude, convert); if (chosen != null) { exclude = chosen; excludeButton.Text = chosen.ToString(); } };
        Row(typing, app.T("Добавить в исключения", "Exclude selection"), excludeButton, 38);
        Full(typing, new Label { Text = app.T("Нажмите кнопку справа, чтобы задать сочетание. Оно работает с выделенным текстом.", "Click a button on the right to record a shortcut. Use it with selected text.") }, 44);
        Full(typing, new Label { Text = app.T("Исключения — по одному слову в строке. Не добавляйте пароли.", "Exceptions — one word per line. Do not enter passwords."), AutoSize = false }, 28);
        var words = new TextBox { Multiline = true, AcceptsReturn = true, ScrollBars = ScrollBars.Vertical, Text = string.Join(Environment.NewLine, prefs.Exclusions), MaxLength = 128000 };
        Full(typing, words, 0, flexible: true);
        var footer = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.RightToLeft, WrapContents = false, Margin = new Padding(0, 6, 0, 0) };
        var apply = new Button { Text = app.T("Сохранить", "Save"), Size = new Size(110, 28), Margin = Padding.Empty };
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
        var feedback = new Button { Text = app.T("Ошибка или идея?", "Bug or idea?"), Size = new Size(165, 28), Margin = new Padding(0, 0, 8, 0) };
        feedback.Click += (_, _) => app.Feedback();
        footer.Controls.Add(apply); footer.Controls.Add(feedback); body.Controls.Add(footer, 0, 1);
        var author = new LinkLabel
        {
            Dock = DockStyle.Fill, Margin = Padding.Empty,
            Text = "Raven Systems · ravensystems.io", TextAlign = ContentAlignment.MiddleCenter,
            LinkColor = Color.White, ActiveLinkColor = Color.White, VisitedLinkColor = Color.White,
            LinkBehavior = LinkBehavior.AlwaysUnderline,
            // Keep the white link legible in both Windows color modes.
            BackColor = Color.FromArgb(25, 27, 29)
        };
        author.LinkClicked += (_, _) => TrayApp.Open("https://ravensystems.io/"); body.Controls.Add(author, 0, 2);
        AcceptButton = apply;
        MinimumSize = SizeFromClientSize(ClientSize);
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
