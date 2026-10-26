using System.Runtime.InteropServices;
using KiYo.Windows;
using KiYo.Core;
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
    var proposals = dictionary.Suggest("helllo", false);
    if (!proposals.Contains("hello", StringComparer.OrdinalIgnoreCase)) throw new Exception("English spelling suggestions unavailable");
    var spelled = Spelling.Correct("helllo!", [], dictionary.Valid, dictionary.Suggest);
    if (spelled != "hello!") throw new Exception("Native spelling correction failed");
    if (Spelling.Correct("helllo!", ["helllo"], dictionary.Valid, dictionary.Suggest) != null)
        throw new Exception("Spelling changed an exclusion");
    if (Spelling.Correct("hello", [], dictionary.Valid, dictionary.Suggest) != null)
        throw new Exception("Spelling changed a correct word");
    if (dictionary.Valid("привет", true) == true)
    {
        var russian = Spelling.Correct("праивльно", [], dictionary.Valid, dictionary.Suggest);
        if (russian != "правильно") throw new Exception("Russian spelling correction failed");
        var sample = Spelling.Correct("игнорируешьшь", [], dictionary.Valid, dictionary.Suggest);
        if (sample != null && sample != "игнорируешь") throw new Exception("Unexpected Russian spelling replacement");
        Console.WriteLine("Russian repeated ending: " + (sample == null ? "ambiguous or unavailable (safely skipped)" : "corrected"));
    }
    Console.WriteLine("Russian dictionary: " + (dictionary.Valid("привет", true)?.ToString() ?? "not installed (supported fallback)"));
}
Native.Hook callback = (code, message, data) => Native.CallNextHookEx(0, code, message, data);
var hook = Native.SetWindowsHookEx(13, callback, Native.GetModuleHandle(null), 0);
if (hook == 0) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
Native.UnhookWindowsHookEx(hook);
GC.KeepAlive(callback);
Console.WriteLine("PASS: Windows input ABI, keyboard layouts, read-only spelling COM and hook installation.");

Fixture.Verify();
