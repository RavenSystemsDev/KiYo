using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Input;
using KiYo.Core;
using WpfButton = System.Windows.Controls.Button;
using WpfText = System.Windows.Controls.TextBlock;
using WpfControl = System.Windows.Controls.Control;
namespace KiYo.Windows;

internal partial class SettingsView : System.Windows.Controls.UserControl
{
    private readonly TrayApp app;
    private readonly Preferences prefs;
    private readonly SettingsForm owner;
    private readonly Action<Preferences> save;
    private readonly ObservableCollection<ExceptionWord> words = new();
    private Shortcut convert, exclude;
    private bool dictionariesChecked;
    internal SettingsView(TrayApp app, Preferences prefs, SettingsForm owner, Action<Preferences> save)
    {
        this.app = app; this.prefs = prefs; this.owner = owner; this.save = save;
        convert = prefs.ConvertShortcut; exclude = prefs.ExcludeShortcut;
        InitializeComponent();
        GeneralTab.Content = app.T("Основные", "General");
        TypingTab.Content = app.T("Сочетания и исключения", "Shortcuts and exceptions");
        GeneralTab.IsChecked = true;
        void Label(WpfText label, WpfControl control, string ru, string en)
        {
            label.Text = app.T(ru, en); AutomationProperties.SetName(control, label.Text);
        }
        Label(LanguageLabel, LanguagePicker, "Язык приложения", "App language");
        LanguagePicker.Items.Add(app.T("Как в системе", "System language")); LanguagePicker.Items.Add("Русский"); LanguagePicker.Items.Add("English");
        LanguagePicker.SelectedIndex = prefs.Language == "ru" ? 1 : prefs.Language == "en" ? 2 : 0;
        Label(LaunchLabel, Launch, "Запуск при входе", "Launch at login"); Launch.IsChecked = Startup.Enabled;
        Label(EnabledLabel, Enabled, "Автоисправление", "Auto correction"); Enabled.IsChecked = prefs.Enabled;
        Label(SpellingLabel, Spelling, "Исправление орфографии", "Spelling correction"); Spelling.IsChecked = prefs.SpellingEnabled;
        Label(ShortsLabel, Shorts, "Короткие слова", "Short words"); Shorts.IsChecked = prefs.ShortWords;
        Label(DictionaryLabel, Dictionary, "Словарь для раскладки", "Layout dictionary"); Dictionary.IsChecked = prefs.UseSystemDictionary;
        DictionaryStatus.Text = app.T("Словари Windows: проверяем…", "Windows dictionaries: checking…");
        Label(ConvertLabel, ConvertButton, "Исправить выделение", "Convert selection"); ConvertButton.Content = convert.ToString();
        Label(ExcludeLabel, ExcludeButton, "Добавить в исключения", "Exclude selection"); ExcludeButton.Content = exclude.ToString();
        ShortcutHint.Text = app.T("Нажмите на сочетание, чтобы назначить своё.", "Click a shortcut to record your own.");
        ExceptionsLabel.Text = app.T("Исключения", "Exceptions");
        ExceptionsHint.Text = app.T("Эти слова KiYo не исправляет", "KiYo leaves these words unchanged");
        WordPlaceholder.Text = app.T("Введите слово", "Enter a word"); AutomationProperties.SetName(WordInput, WordPlaceholder.Text);
        AutomationProperties.SetAutomationId(WordInput, "ExceptionInput");
        AutomationProperties.SetAutomationId(ExceptionsScroll, "ExceptionsScroll");
        AddButton.Content = app.T("Добавить", "Add");
        EmptyWords.Text = app.T("Пока нет исключений", "No exceptions yet");
        Words.ItemsSource = words;
        foreach (var word in prefs.Exclusions) words.Add(new(word, app.T("Удалить ", "Remove ") + word));
        UpdateWords(); ResetWordHint();
        GuideButton.Content = app.T("Инструкция", "User guide"); AboutButton.Content = app.T("О KiYo", "About KiYo");
        PrivacyHint.Text = app.T("Текст остаётся на устройстве", "Text stays on this device");
        FeedbackButton.Content = app.T("Ошибка или идея?", "Bug or idea?"); SaveButton.Content = app.T("Сохранить", "Save");
        Loaded += CheckDictionaries;
    }
    private void PageChanged(object sender, RoutedEventArgs e)
    {
        if (GeneralPage is null || TypingPage is null) return;
        GeneralPage.Visibility = GeneralTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        TypingPage.Visibility = TypingTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }
    private async void CheckDictionaries(object sender, RoutedEventArgs e)
    {
        if (dictionariesChecked) return;
        dictionariesChecked = true;
        var available = await Task.Run(() =>
        {
            using var system = new SystemDictionary();
            return (Russian: system.Available(true), English: system.Available(false));
        });
        if (owner.IsDisposed) return;
        string Status(bool present) => present ? app.T("есть", "installed") : app.T("нет", "missing");
        DictionaryStatus.Text = app.T("Словари Windows: ", "Windows dictionaries: ") + $"RU — {Status(available.Russian)}, EN — {Status(available.English)}";
    }
    private Shortcut? Record(Shortcut current, Shortcut other)
    {
        using var dialog = new ShortcutForm(app, current, other);
        return dialog.ShowDialog(owner) == DialogResult.OK ? dialog.Result : null;
    }
    private void RecordConvert(object sender, RoutedEventArgs e) { var chosen = Record(convert, exclude); if (chosen is not null) { convert = chosen; ConvertButton.Content = chosen.ToString(); } }
    private void RecordExclude(object sender, RoutedEventArgs e) { var chosen = Record(exclude, convert); if (chosen is not null) { exclude = chosen; ExcludeButton.Content = chosen.ToString(); } }
    private void ResetWordHint() => WordHint.Text = app.T("Пароли в исключения добавлять не нужно.", "You do not need to add passwords to exceptions.");
    private void WordChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        if (WordPlaceholder is null) return;
        WordPlaceholder.Visibility = WordInput.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
        ResetWordHint();
    }
    private void WordKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
        e.Handled = true; AddWord(sender, e);
    }
    private void AddWord(object sender, RoutedEventArgs e)
    {
        string word = WordInput.Text.Trim().ToLowerInvariant();
        if (word.Length == 0) { WordInput.Focus(); return; }
        if (word.Length > 64 || word.Any(char.IsWhiteSpace) || word.Any(char.IsControl))
        { WordHint.Text = app.T("Введите одно слово длиной до 64 символов.", "Enter one word, up to 64 characters."); return; }
        if (words.Any(item => string.Equals(item.Word, word, StringComparison.OrdinalIgnoreCase)))
        { WordHint.Text = app.T("Это слово уже есть в исключениях.", "This word is already in exceptions."); return; }
        if (words.Count >= 2000) { WordHint.Text = app.T("Можно сохранить до 2000 исключений.", "You can save up to 2,000 exceptions."); return; }
        words.Insert(0, new(word, app.T("Удалить ", "Remove ") + word));
        WordInput.Clear(); UpdateWords(); ExceptionsScroll.ScrollToTop(); WordInput.Focus();
    }
    private void RemoveWord(object sender, RoutedEventArgs e)
    {
        if (((WpfButton)sender).DataContext is ExceptionWord word) words.Remove(word);
        UpdateWords(); ResetWordHint();
    }
    private void UpdateWords() => EmptyWords.Visibility = words.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
    private void Guide(object sender, RoutedEventArgs e) => app.Guide(owner);
    private void About(object sender, RoutedEventArgs e) => app.About(owner);
    private void Author(object sender, RoutedEventArgs e) => TrayApp.Open("https://ravensystems.io/");
    private void Feedback(object sender, RoutedEventArgs e) => app.Feedback();
    private void Save(object sender, RoutedEventArgs e)
    {
        // A typed but not yet added word must not silently disappear on Save.
        if (!string.IsNullOrWhiteSpace(WordInput.Text))
        {
            AddWord(sender, e);
            if (!string.IsNullOrWhiteSpace(WordInput.Text)) { TypingTab.IsChecked = true; WordInput.Focus(); return; }
        }
        try { Startup.Set(Launch.IsChecked == true); }
        catch (Exception ex) when (ex is UnauthorizedAccessException or System.Security.SecurityException or IOException)
        { System.Windows.Forms.MessageBox.Show(owner, app.T("Не удалось изменить автозапуск.", "Could not change launch at login."), "KiYo"); return; }
        save(prefs with { Enabled = Enabled.IsChecked == true, ShortWords = Shorts.IsChecked == true, UseSystemDictionary = Dictionary.IsChecked == true,
            SpellingEnabled = Spelling.IsChecked == true, Language = LanguagePicker.SelectedIndex == 1 ? "ru" : LanguagePicker.SelectedIndex == 2 ? "en" : "system",
            ConvertShortcut = convert, ExcludeShortcut = exclude, Exclusions = words.Select(item => item.Word).ToArray() });
        owner.Close();
    }
    private sealed record ExceptionWord(string Word, string RemoveLabel);
}
