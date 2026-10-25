using System.Runtime.InteropServices;
using KiYo.Windows;
if (args is ["--fixture", var mode, var file]) { Fixture.Run(mode, file); return; }
if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException("Run this smoke test on Windows.");
var expected = Environment.Is64BitProcess ? 40 : 28;
if (Marshal.SizeOf<Native.Input>() != expected) throw new Exception("INPUT ABI mismatch");
var count = Native.GetKeyboardLayoutList(0, null);
if (count < 1) throw new Exception("No keyboard layouts available");
var layouts = new nint[count]; Native.GetKeyboardLayoutList(count, layouts);
using (var dictionary = new SystemDictionary())
{
    if (dictionary.Valid("hello", false) != true) throw new Exception("en-US dictionary could not validate hello");
    if (dictionary.Valid("ghbdtn", false) != false) throw new Exception("Dictionary accepted wrong-layout input");
    Console.WriteLine("Russian dictionary: " + (dictionary.Valid("привет", true)?.ToString() ?? "not installed (supported fallback)"));
}
Native.Hook callback = (code, message, data) => Native.CallNextHookEx(0, code, message, data);
var hook = Native.SetWindowsHookEx(13, callback, Native.GetModuleHandle(null), 0);
if (hook == 0) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
Native.UnhookWindowsHookEx(hook);
GC.KeepAlive(callback);
Console.WriteLine("PASS: Windows input ABI, keyboard layouts, read-only spelling COM and hook installation.");

Fixture.Verify();
