using System.Runtime.InteropServices;
namespace KiYo.Windows;
// Only read-only prefix methods are declared. No personal dictionary is modified.
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
    }
    [ComImport, Guid("803E3BD4-2828-4410-8290-418D1D73C762"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IErrors { [PreserveSig] int Next(out nint error); }
    private readonly Dictionary<bool, IChecker?> checkers = new();
    private IFactory? factory;
    internal bool? Valid(string word, bool russian)
    {
        try
        {
            if (!checkers.TryGetValue(russian, out var checker))
            {
                factory ??= (IFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("7AB36653-1796-484B-BDFA-E74F1DB7C1DC"), true)!)!;
                var lang = russian ? "ru-RU" : "en-US";
                factory.IsSupported(lang, out var supported);
                if (supported) factory.Create(lang, out checker);
                checkers[russian] = checker;
            }
            if (checker == null) return null;
            checker.Check(word, out var errors);
            try
            {
                var result = errors.Next(out var error);
                if (result < 0) return null;
                if (error != 0) { Marshal.Release(error); return false; }
                return true;
            }
            finally { Marshal.ReleaseComObject(errors); }
        }
        catch (Exception ex) when (ex is COMException or InvalidCastException or TypeLoadException) { return null; }
    }
    public void Dispose()
    {
        foreach (var checker in checkers.Values) if (checker != null) Marshal.ReleaseComObject(checker);
        if (factory != null) Marshal.ReleaseComObject(factory);
    }
}
