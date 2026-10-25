using System.Runtime.InteropServices;
using System.Windows.Automation;
using System.Windows.Automation.Text;
namespace KiYo.Windows;
internal sealed record TextSnapshot(nint Window, nint Focus, AutomationElement Element, TextPatternRange Range, string Text, bool IsTail);
internal static class TextAccess
{
    private static AutomationElement? Editable(nint window)
    {
        if (Native.GetForegroundWindow() != window) return null;
        Native.GetWindowThreadProcessId(window, out var pid);
        if (pid == Environment.ProcessId) return null;
        var element = AutomationElement.FocusedElement;
        if (element == null || element.Current.ProcessId != pid || element.Current.IsPassword || !element.Current.IsEnabled) return null;
        if (Sensitive(element.Current.Name, element.Current.HelpText, element.Current.AutomationId,
            element.Current.LabeledBy?.Current.Name) || NativeSensitiveField(window, pid)) return null;
        if (!element.TryGetCurrentPattern(TextPattern.Pattern, out var raw) || raw is not TextPattern pattern) return null;
        // Read-only web content and custom controls with unknown writability fail closed.
        var readOnly = pattern.DocumentRange.GetAttributeValue(TextPattern.IsReadOnlyAttribute);
        if (readOnly is not bool writable || writable) return null;
        return element;
    }
    private static bool Sensitive(params string?[] descriptions) => descriptions.Any(text => text != null &&
        new[] { "password", "passcode", "парол", "email", "e-mail", "электронн" }
            .Any(marker => text.Contains(marker, StringComparison.OrdinalIgnoreCase)));

    [DllImport("oleacc.dll", ExactSpelling = true)]
    private static extern int AccessibleObjectFromWindow(nint window, uint objectId, ref Guid interfaceId,
        [MarshalAs(UnmanagedType.Interface)] out Accessibility.IAccessible? accessible);

    private static bool NativeSensitiveField(nint window, uint processId)
    {
        // RichEdit's native UIA provider can omit a WinForms AccessibleName.
        // Also inspect the focused HWND's MSAA metadata; never read accValue.
        var focus = Native.Focus(window);
        if (focus == 0) return false;
        Native.GetWindowThreadProcessId(focus, out var focusedProcess);
        if (focusedProcess != processId) return true;
        var iid = typeof(Accessibility.IAccessible).GUID;
        var result = AccessibleObjectFromWindow(focus, 0xFFFFFFFC, ref iid, out var accessible); // OBJID_CLIENT
        if (result < 0 || accessible == null) return false; // UIA-only control
        try
        {
            if (accessible.get_accState(0) is int state && (state & 0x20000000) != 0) return true; // STATE_SYSTEM_PROTECTED
            return Sensitive(accessible.get_accName(0));
        }
        finally { if (Marshal.IsComObject(accessible)) Marshal.ReleaseComObject(accessible); }
    }
    internal static TextSnapshot? Read(nint window, string? expectedTail)
    {
        var element = Editable(window);
        if (element == null) return null;
        var pattern = (TextPattern)element.GetCurrentPattern(TextPattern.Pattern);
        var selections = pattern.GetSelection();
        if (selections.Length != 1) return null;
        var selection = selections[0];
        if (expectedTail != null)
        {
            if (!TailMatches(selection, expectedTail)) return null;
            return new(window, Native.Focus(window), element, selection.Clone(), expectedTail, true);
        }
        var text = selection.GetText(8193);
        return text.Length is > 0 and <= 8192 ? new(window, Native.Focus(window), element, selection.Clone(), text, false) : null;
    }
    private static bool TailMatches(TextPatternRange selection, string expected)
    {
        if (selection.CompareEndpoints(TextPatternRangeEndpoint.Start, selection, TextPatternRangeEndpoint.End) != 0) return false;
        var tail = selection.Clone();
        if (tail.MoveEndpointByUnit(TextPatternRangeEndpoint.Start, TextUnit.Character, -(expected.Length + 1)) == 0) return false;
        var visible = tail.GetText(expected.Length + 2);
        return visible == expected || visible.Length == expected.Length + 1 && char.IsWhiteSpace(visible[0]) && visible[1..] == expected;
    }
    internal static bool StillSelected(TextSnapshot snapshot)
    {
        var element = Editable(snapshot.Window);
        if (element == null || !Automation.Compare(element, snapshot.Element)) return false;
        var ranges = ((TextPattern)element.GetCurrentPattern(TextPattern.Pattern)).GetSelection();
        if (ranges.Length != 1 || !ranges[0].Compare(snapshot.Range)) return false;
        // UIA ranges are live. Equal endpoints alone do not prove unchanged text.
        return snapshot.IsTail ? TailMatches(ranges[0], snapshot.Text) : ranges[0].GetText(8193) == snapshot.Text;
    }
}
