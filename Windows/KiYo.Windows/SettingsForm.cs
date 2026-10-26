using System.Runtime.InteropServices;
using System.Windows.Forms.Integration;
using KiYo.Core;
namespace KiYo.Windows;
internal class DarkForm : Form
{
    protected DarkForm()
    {
        BackColor = Color.FromArgb(25, 25, 27); ForeColor = Color.FromArgb(244, 244, 245);
        Font = new Font("Segoe UI", 10);
    }
    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        int enabled = 1, caption = 0x001B1919, text = 0x00F5F4F4;
        _ = DwmSetWindowAttribute(Handle, 20, ref enabled, sizeof(int));
        _ = DwmSetWindowAttribute(Handle, 35, ref caption, sizeof(int));
        _ = DwmSetWindowAttribute(Handle, 36, ref text, sizeof(int));
    }
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(nint window, int attribute, ref int value, int size);
}
internal sealed class SettingsForm : DarkForm
{
    internal SettingsForm(TrayApp app, Preferences prefs, Icon icon, Action<Preferences> save)
    {
        Text = app.T("Настройки KiYo", "KiYo settings"); Icon = icon;
        AutoScaleDimensions = new SizeF(96, 96); AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(634, 484); MinimumSize = SizeFromClientSize(ClientSize);
        StartPosition = FormStartPosition.CenterScreen;
        Controls.Add(new ElementHost { Dock = DockStyle.Fill, Child = new SettingsView(app, prefs, this, save) });
    }
}
internal sealed class ShortcutForm : DarkForm
{
    private readonly TrayApp app;
    private readonly Shortcut other;
    private readonly Label prompt;
    internal Shortcut? Result { get; private set; }
    internal ShortcutForm(TrayApp app, Shortcut current, Shortcut other)
    {
        this.app = app; this.other = other;
        Text = app.T("Горячая клавиша", "Keyboard shortcut"); ClientSize = new Size(440, 170);
        AutoScaleDimensions = new SizeF(96, 96); AutoScaleMode = AutoScaleMode.Dpi;
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
