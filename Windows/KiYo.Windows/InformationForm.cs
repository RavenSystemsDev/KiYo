using System.Reflection;
using System.Windows;
using System.Windows.Forms.Integration;
using System.Windows.Media;
using KiYo.Core;
using Wpf = System.Windows.Controls;
namespace KiYo.Windows;

internal sealed class InformationForm : DarkForm
{
    internal InformationForm(TrayApp app, Icon icon, Preferences prefs, bool guide)
    {
        Text = guide ? app.T("Инструкция KiYo", "KiYo user guide") : app.T("О KiYo", "About KiYo");
        Icon = icon; AutoScaleDimensions = new SizeF(96, 96); AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new System.Drawing.Size(550, guide ? 470 : 370); MinimumSize = SizeFromClientSize(ClientSize);
        StartPosition = FormStartPosition.CenterParent; MinimizeBox = false; MaximizeBox = false;
        var root = new Wpf.Grid { Margin = new Thickness(24, 16, 24, 16) };
        root.Resources.MergedDictionaries.Add(new ResourceDictionary { Source = new Uri("/KiYo;component/Theme.xaml", UriKind.Relative) });
        root.RowDefinitions.Add(new Wpf.RowDefinition()); root.RowDefinitions.Add(new Wpf.RowDefinition { Height = GridLength.Auto });
        var content = new Wpf.StackPanel();
        root.Children.Add(new Wpf.ScrollViewer { Content = content, VerticalScrollBarVisibility = Wpf.ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = Wpf.ScrollBarVisibility.Disabled });
        void TextLine(string text, bool heading = false)
        {
            content.Children.Add(new Wpf.TextBlock { Text = text, TextWrapping = TextWrapping.Wrap, FontSize = heading ? 16 : 14,
                FontWeight = heading ? FontWeights.SemiBold : FontWeights.Normal, Foreground = (System.Windows.Media.Brush)new BrushConverter().ConvertFrom(heading ? "#F4F4F5" : "#ACACB3")!,
                Margin = new Thickness(0, heading ? 12 : 6, 4, 0) });
        }
        if (guide)
        {
            TextLine(app.T("Начало работы", "Getting started"), true);
            TextLine(app.T("KiYo находится рядом с часами. Печатайте как обычно: раскладка исправляется после пробела. Приостановить автосмену можно в меню значка.", "Find KiYo beside the clock. Type normally: layout corrections happen after a space. Pause auto correction from the tray menu."));
            TextLine(app.T("Раскладка и орфография", "Layout and spelling"), true);
            TextLine(app.T("Автоисправление переключает РУ ↔ EN. Для опечаток включите «Исправление орфографии». Нужны словари Windows; их наличие видно в настройках. Неоднозначные варианты пропускаются.", "Auto correction switches RU ↔ EN. Enable Spelling correction for typos. It needs Windows dictionaries; Settings shows their availability. Ambiguous suggestions are skipped."));
            TextLine(app.T("Выделенный текст", "Selected text"), true);
            TextLine(app.T($"{prefs.ConvertShortcut} — исправить раскладку выделения.\n{prefs.ExcludeShortcut} — добавить выделенные слова в исключения.", $"{prefs.ConvertShortcut} — convert the selected text's layout.\n{prefs.ExcludeShortcut} — add selected words to exceptions."));
            TextLine(app.T("Ваши настройки", "Your preferences"), true);
            TextLine(app.T("В разделе «Сочетания и исключения» назначьте свои клавиши и добавьте слова, которые не нужно менять. Нажмите «Сохранить». Пароли добавлять не нужно: защищённые поля пропускаются.", "Record your own shortcuts and add words to leave unchanged under Shortcuts and exceptions, then click Save. You do not need to add passwords: protected fields are skipped."));
        }
        else
        {
            string version = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion.Split('+')[0] ?? "";
            var header = new Wpf.StackPanel { Orientation = Wpf.Orientation.Horizontal, Margin = new Thickness(0, 8, 0, 10) };
            var logo = System.Windows.Interop.Imaging.CreateBitmapSourceFromHIcon(icon.Handle, Int32Rect.Empty, System.Windows.Media.Imaging.BitmapSizeOptions.FromEmptyOptions());
            header.Children.Add(new Wpf.Image { Source = logo, Width = 48, Height = 48, Margin = new Thickness(0, 0, 14, 0) });
            header.Children.Add(new Wpf.TextBlock { Text = "KiYo  " + version, FontSize = 22, FontWeight = FontWeights.SemiBold }); content.Children.Add(header);
            TextLine(app.T("Автоматически исправляет слова, набранные в неверной русской или английской раскладке, и переключает язык ввода.", "Automatically corrects words typed in the wrong Russian or English keyboard layout and switches the input language."));
            TextLine(app.T("Текст обрабатывается локально на вашем компьютере.", "Text is processed locally on your computer."));
            var author = new Wpf.Button { Content = new Wpf.TextBlock { Text = "Raven Systems · ravensystems.io", TextDecorations = TextDecorations.Underline },
                Style = (Style)root.Resources["Quiet"], HorizontalAlignment = System.Windows.HorizontalAlignment.Left, Margin = new Thickness(-8, 12, 0, 0) };
            author.Click += (_, _) => TrayApp.Open("https://ravensystems.io/"); content.Children.Add(author);
            var links = new Wpf.WrapPanel { Margin = new Thickness(0, 16, 0, 0) };
            void Document(string title, string file)
            {
                var button = new Wpf.Button { Content = title, Margin = new Thickness(0, 0, 8, 8) };
                button.Click += (_, _) => TrayApp.Open(Path.Combine(AppContext.BaseDirectory, file)); links.Children.Add(button);
            }
            Document(app.T("Конфиденциальность", "Privacy"), "PRIVACY.txt");
            Document(app.T("Лицензия", "License"), "LICENSE.txt");
            Document(app.T("Компоненты", "Components"), "THIRD-PARTY-NOTICES.txt");
            content.Children.Add(links);
        }
        var done = new Wpf.Button { Content = app.T("Готово", "Done"), MinWidth = 100, Margin = new Thickness(0, 16, 0, 0),
            HorizontalAlignment = System.Windows.HorizontalAlignment.Right, Style = (Style)root.Resources["Primary"] };
        done.Click += (_, _) => Close(); Wpf.Grid.SetRow(done, 1); root.Children.Add(done);
        var view = new Wpf.UserControl { Content = root, Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(25, 25, 27)),
            FontFamily = new System.Windows.Media.FontFamily("Segoe UI"), FontSize = 14, UseLayoutRounding = true };
        Controls.Add(new ElementHost { Dock = DockStyle.Fill, Child = view });
    }
    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData == Keys.Escape) { Close(); return true; }
        return base.ProcessCmdKey(ref msg, keyData);
    }
}
