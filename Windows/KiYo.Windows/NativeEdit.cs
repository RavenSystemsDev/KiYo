using System.Runtime.InteropServices;
using System.Text;
namespace KiYo.Windows;

internal sealed record NativeEditTarget(nint Handle, uint Start, uint End);
internal enum ReplacementResult { Cancelled, Sent, Failed }

// Standard Unicode edit controls can replace a selected range with one message.
// No clipboard, remote-process memory or document-wide SetValue is involved.
internal static class NativeEdit
{
    private const uint TimeoutFlags = 0x22; // ABORTIFHUNG | ERRORONEXIT
    private const uint TimeoutMilliseconds = 50;
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(nint window, StringBuilder name, int capacity);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)] private static extern bool IsWindowUnicode(nint window);
    [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW", SetLastError = true)]
    private static extern nint SelectionMessage(nint window, uint message, out uint start, out uint end,
        uint flags, uint timeout, out nuint result);
    [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW", SetLastError = true)]
    private static extern nint RangeMessage(nint window, uint message, nuint start, nint end,
        uint flags, uint timeout, out nuint result);
    [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern nint ReplaceMessage(nint window, uint message, nuint undo, string text,
        uint flags, uint timeout, out nuint result);

    private static bool Supported(nint handle)
    {
        if (handle == 0 || !IsWindowUnicode(handle)) return false;
        var buffer = new StringBuilder(128);
        if (GetClassName(handle, buffer, buffer.Capacity) == 0) return false;
        var name = buffer.ToString();
        foreach (var known in new[] { "Edit", "RichEdit20W", "RICHEDIT50W", "RichEditD2D", "RichEditD2DPT" })
            if (name.Equals(known, StringComparison.OrdinalIgnoreCase) ||
                name.StartsWith("WindowsForms10." + known + ".app.", StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }
    // false means a known editor did not respond; never fall back to deleting
    // text with keystrokes after an inconclusive native operation.
    internal static bool TryCapture(nint handle, out NativeEditTarget? target)
    {
        target = null;
        if (!Supported(handle)) return true;
        if (!ReadSelection(handle, out var start, out var end)) return false;
        target = new(handle, start, end); return true;
    }
    private static bool ReadSelection(nint handle, out uint start, out uint end) =>
        SelectionMessage(handle, 0xB0, out start, out end, TimeoutFlags, TimeoutMilliseconds, out _) != 0 && start <= end;
    internal static bool StillSelected(NativeEditTarget target) =>
        ReadSelection(target.Handle, out var start, out var end) && start == target.Start && end == target.End;
    private static bool Select(nint handle, uint start, uint end) =>
        RangeMessage(handle, 0xB1, start, (nint)end, TimeoutFlags, TimeoutMilliseconds, out _) != 0;

    internal static ReplacementResult Replace(NativeEditTarget target, int deleteCount, string text, Func<bool> current)
    {
        if (deleteCount < 0 || text.Length == 0 || text.IndexOf('\0') >= 0 || !current() || !StillSelected(target))
            return ReplacementResult.Cancelled;
        if (deleteCount > 0 && (target.Start != target.End || target.Start < deleteCount)) return ReplacementResult.Cancelled;
        uint start = target.Start - (uint)deleteCount;
        var selected = target with { Start = start };
        if (deleteCount > 0 && !Select(target.Handle, start, target.End)) return ReplacementResult.Failed;
        // A sent message may dispatch hooks. Recheck input/focus and the range
        // immediately before the only operation that changes text.
        if (!StillSelected(selected) || !current())
        {
            // If a new key was observed but has not reached the editor yet,
            // undo only our temporary selection before that key can replace it.
            if (Native.Focus(Native.GetForegroundWindow()) == target.Handle && StillSelected(selected))
                Select(target.Handle, target.Start, target.End);
            return ReplacementResult.Cancelled;
        }
        if (ReplaceMessage(target.Handle, 0xC2, 1, text, TimeoutFlags, TimeoutMilliseconds, out _) == 0)
            return ReplacementResult.Failed;
        return ReplacementResult.Sent; // The caller also verifies the editor's resulting text.
    }
}
