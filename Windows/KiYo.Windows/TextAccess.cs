using System.Windows.Automation;
using System.Windows.Automation.Text;
namespace KiYo.Windows;
internal sealed record TextSnapshot(nint Window, nint Focus, AutomationElement Element, TextPatternRange Range, string Text);
internal static class TextAccess
{
    private static AutomationElement? Editable(nint window)
    {
        if (Native.GetForegroundWindow() != window) return null;
        Native.GetWindowThreadProcessId(window, out var pid);
        if (pid == Environment.ProcessId) return null;
        var element = AutomationElement.FocusedElement;
        if (element == null || element.Current.ProcessId != pid || element.Current.IsPassword || !element.Current.IsEnabled) return null;
        var description = string.Join(" ", element.Current.Name, element.Current.HelpText, element.Current.AutomationId).ToLowerInvariant();
        if (new[] { "password", "passcode", "парол", "email", "e-mail", "электронн" }.Any(description.Contains)) return null;
        if (!element.TryGetCurrentPattern(TextPattern.Pattern, out var raw) || raw is not TextPattern pattern) return null;
        // Read-only web content and custom controls with unknown writability fail closed.
        var readOnly = pattern.DocumentRange.GetAttributeValue(TextPattern.IsReadOnlyAttribute);
        if (readOnly is not bool writable || writable) return null;
        return element;
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
            if (selection.CompareEndpoints(TextPatternRangeEndpoint.Start, selection, TextPatternRangeEndpoint.End) != 0) return null;
            var tail = selection.Clone();
            var moved = tail.MoveEndpointByUnit(TextPatternRangeEndpoint.Start, TextUnit.Character, -(expectedTail.Length + 1));
            var visible = tail.GetText(expectedTail.Length + 2);
            if (visible != expectedTail && !(visible.Length == expectedTail.Length + 1 && char.IsWhiteSpace(visible[0]) && visible[1..] == expectedTail)) return null;
            if (moved == 0) return null;
            return new(window, Native.Focus(window), element, selection.Clone(), expectedTail);
        }
        var text = selection.GetText(8193);
        return text.Length is > 0 and <= 8192 ? new(window, Native.Focus(window), element, selection.Clone(), text) : null;
    }
    internal static bool StillSelected(TextSnapshot snapshot)
    {
        var element = Editable(snapshot.Window);
        if (element == null || !Automation.Compare(element, snapshot.Element)) return false;
        var ranges = ((TextPattern)element.GetCurrentPattern(TextPattern.Pattern)).GetSelection();
        return ranges.Length == 1 && ranges[0].Compare(snapshot.Range);
    }
}
