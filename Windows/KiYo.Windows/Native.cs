using System.Runtime.InteropServices;
using System.Text;
namespace KiYo.Windows;
internal static class Native
{
    internal const nuint Tag = 0x4B49594F;
    internal const int WmHotkey = 0x0312;
    internal delegate nint Hook(int code, nint message, nint data);
    [StructLayout(LayoutKind.Sequential)] internal struct KeyboardEvent { public uint Key, Scan, Flags, Time; public nuint Extra; }
    [StructLayout(LayoutKind.Sequential)] internal struct GuiInfo { public uint Size, Flags; public nint Active, Focus, Capture, MenuOwner, MoveSize, Caret; public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] internal struct KeyboardInput { public ushort Key, Scan; public uint Flags, Time; public nuint Extra; }
    [StructLayout(LayoutKind.Sequential)] internal struct MouseInput { public int X, Y; public uint Data, Flags, Time; public nuint Extra; }
    [StructLayout(LayoutKind.Explicit)] internal struct InputUnion { [FieldOffset(0)] public KeyboardInput Keyboard; [FieldOffset(0)] public MouseInput Mouse; }
    [StructLayout(LayoutKind.Sequential)] internal struct Input { public uint Type; public InputUnion Data; }
    [DllImport("user32.dll", SetLastError = true)] internal static extern nint SetWindowsHookEx(int id, Hook callback, nint module, uint thread);
    [DllImport("user32.dll")] internal static extern nint CallNextHookEx(nint hook, int code, nint message, nint data);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UnhookWindowsHookEx(nint hook);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] internal static extern nint GetModuleHandle(string? name);
    [DllImport("user32.dll")] internal static extern nint GetForegroundWindow();
    [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(nint window, out uint pid);
    [DllImport("user32.dll")] internal static extern nint GetKeyboardLayout(uint thread);
    [DllImport("user32.dll")] internal static extern int GetKeyboardLayoutList(int size, [Out] nint[]? layouts);
    [DllImport("user32.dll")] internal static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] internal static extern short GetKeyState(int key);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool GetGUIThreadInfo(uint thread, ref GuiInfo info);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] internal static extern int ToUnicodeEx(uint key, uint scan, byte[] state, StringBuilder text, int size, uint flags, nint layout);
    [DllImport("user32.dll", SetLastError = true)] internal static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool PostMessage(nint window, uint message, nint wparam, nint lparam);
    [DllImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool RegisterHotKey(nint hwnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UnregisterHotKey(nint hwnd, int id);
    internal static bool Down(int key) => (GetAsyncKeyState(key) & 0x8000) != 0;
    internal static bool ModifiersDown() => new[] { 0x10, 0x11, 0x12, 0x5B, 0x5C }.Any(Down);
    internal static nint Focus(nint window)
    {
        var thread = GetWindowThreadProcessId(window, out _);
        var info = new GuiInfo { Size = (uint)Marshal.SizeOf<GuiInfo>() };
        return GetGUIThreadInfo(thread, ref info) ? info.Focus : 0;
    }
    internal static bool SupportedLayout(nint layout) => ((long)layout & 0xFFFF) is 0x0409 or 0x0419;
    internal static char? Translate(KeyboardEvent key, nint layout)
    {
        var state = new byte[256];
        // The current event has not updated async state yet. Apply it explicitly.
        for (int i = 0; i < 256; i++) if (Down(i)) state[i] = 0x80;
        state[key.Key] = 0x80;
        state[0x14] = (byte)(GetKeyState(0x14) & 1);
        var chars = new StringBuilder(8);
        var count = ToUnicodeEx(key.Key, key.Scan, state, chars, chars.Capacity, 4, layout);
        return count == 1 && !char.IsControl(chars[0]) && !char.IsSurrogate(chars[0]) ? chars[0] : null;
    }
    internal static Input Key(ushort key, bool up) => new() { Type = 1, Data = new() { Keyboard = new() { Key = key, Flags = up ? 2u : 0, Extra = Tag } } };
    internal static Input Unicode(char c, bool up) => new() { Type = 1, Data = new() { Keyboard = new() { Scan = c, Flags = 4u | (up ? 2u : 0), Extra = Tag } } };
    internal static bool Replace(int deleteCount, string replacement)
    {
        var inputs = new List<Input>();
        for (int i = 0; i < deleteCount; i++) { inputs.Add(Key(8, false)); inputs.Add(Key(8, true)); }
        foreach (var c in replacement) { inputs.Add(Unicode(c, false)); inputs.Add(Unicode(c, true)); }
        return inputs.Count > 0 && SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf<Input>()) == inputs.Count;
    }
    internal static nint RequestLayout(nint window, bool russian)
    {
        var layouts = new nint[GetKeyboardLayoutList(0, null)];
        GetKeyboardLayoutList(layouts.Length, layouts);
        var target = layouts.FirstOrDefault(h => ((long)h & 0xFFFF) == (russian ? 0x0419 : 0x0409));
        return target != 0 && PostMessage(window, 0x50, 0, target) ? target : 0;
    }
}
