using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
namespace KiYo.Windows;
// Only read-only prefix methods are declared, in their native vtable order.
// Check/Suggest never add words or autocorrect entries to personal dictionaries.
internal sealed class SystemDictionary : IDisposable
{
    [ComImport, Guid("8E018A9D-2415-4677-BF08-794EA61F94BB"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IFactory
    {
        void Supported(out nint languages);
        void IsSupported([MarshalAs(UnmanagedType.LPWStr)] string language, [MarshalAs(UnmanagedType.Bool)] out bool supported);
        void Create([MarshalAs(UnmanagedType.LPWStr)] string language, out IChecker checker);
    }
    [ComImport, Guid("B6FD0B71-E2BC-4653-8D05-F197E412770B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IChecker
    {
        void Language([MarshalAs(UnmanagedType.LPWStr)] out string language);
        void Check([MarshalAs(UnmanagedType.LPWStr)] string text, out IErrors errors);
        void Suggest([MarshalAs(UnmanagedType.LPWStr)] string word, out IEnumString suggestions);
    }
    [ComImport, Guid("803E3BD4-2828-4410-8290-418D1D73C762"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IErrors { [PreserveSig] int Next(out nint error); }
    private readonly Dictionary<bool, IChecker?> checkers = new();
    private IFactory? factory;
    private IChecker? Checker(bool russian)
    {
        if (!checkers.TryGetValue(russian, out var checker))
        {
            factory ??= (IFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("7AB36653-1796-484B-BDFA-E74F1DB7C1DC"), true)!)!;
            var lang = russian ? "ru-RU" : "en-US";
            factory.IsSupported(lang, out var supported);
            if (supported) factory.Create(lang, out checker);
            checkers[russian] = checker;
        }
        return checker;
    }
    internal bool? Valid(string word, bool russian)
    {
        try
        {
            var checker = Checker(russian);
            if (checker == null) return null;
            checker.Check(word, out var errors);
            try
            {
                var result = errors.Next(out var error);
                try { return result == 1 && error == 0 ? true : result == 0 && error != 0 ? false : null; }
                finally { if (error != 0) Marshal.Release(error); }
            }
            finally { Marshal.ReleaseComObject(errors); }
        }
        catch (Exception ex) when (ex is COMException or InvalidCastException or TypeLoadException) { return null; }
    }
    internal IReadOnlyList<string> Suggest(string word, bool russian)
    {
        if (word.Length is < 4 or > 48 || !word.All(KiYo.Core.Layouts.IsLetter)) return [];
        try
        {
            var checker = Checker(russian);
            if (checker == null) return [];
            checker.Suggest(word, out var suggestions);
            try
            {
                var result = new List<string>();
                var next = new string[1];
                for (int i = 0; i <= 32; i++)
                {
                    // IEnumString permits a null fetched pointer for one item.
                    var status = suggestions.Next(1, next, 0);
                    if (status == 1) return result;
                    if (status != 0 || string.IsNullOrEmpty(next[0])) return [];
                    result.Add(next[0]);
                }
                return []; // Incomplete suggestions cannot establish a unique best result.
            }
            finally { Marshal.ReleaseComObject(suggestions); }
        }
        catch (Exception ex) when (ex is COMException or InvalidCastException or TypeLoadException) { return []; }
    }
    public void Dispose()
    {
        foreach (var checker in checkers.Values) if (checker != null) Marshal.ReleaseComObject(checker);
        checkers.Clear();
        if (factory != null) Marshal.ReleaseComObject(factory);
        factory = null;
    }
}
