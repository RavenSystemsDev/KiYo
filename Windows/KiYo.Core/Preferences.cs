using System.Text.Json;
namespace KiYo.Core;
public sealed record Shortcut(uint Modifiers, uint Key)
{
    public bool Valid => (Modifiers & ~15u) == 0 && (Modifiers & 11) != 0 && Key is >= 0x30 and <= 0x87 && Key is not (>= 0x5B and <= 0x5F);
    public override string ToString() => ((Modifiers & 2) != 0 ? "Ctrl + " : "") + ((Modifiers & 1) != 0 ? "Alt + " : "") +
        ((Modifiers & 4) != 0 ? "Shift + " : "") + ((Modifiers & 8) != 0 ? "Win + " : "") +
        (Key is >= 0x70 and <= 0x87 ? $"F{Key - 0x6F}" : ((char)Key).ToString());
}
public sealed record Preferences
{
    public bool Enabled { get; init; } = true;
    public bool ShortWords { get; init; } = true;
    public bool UseSystemDictionary { get; init; } = true;
    public bool WelcomeShown { get; init; }
    public string Language { get; init; } = "system";
    public string[] Exclusions { get; init; } = [];
    public Shortcut ConvertShortcut { get; init; } = new(3, 'R');
    public Shortcut ExcludeShortcut { get; init; } = new(3, 'K');
    public Preferences Normalize()
    {
        var convert = ConvertShortcut is { Valid: true } ? ConvertShortcut : new Shortcut(3, 'R');
        var exclude = ExcludeShortcut is { Valid: true } ? ExcludeShortcut : new Shortcut(3, 'K');
        if (exclude == convert) exclude = new Shortcut(3, convert.Key == 'K' ? 'R' : 'K');
        return this with
        {
            Language = Language is "ru" or "en" ? Language : "system",
            Exclusions = (Exclusions ?? []).Where(w => w != null && w.Length is > 0 and <= 64 && !w.Any(char.IsControl))
                .Select(w => w.Trim().ToLowerInvariant()).Where(w => w.Length > 0).Distinct().Take(2000).ToArray(),
            ConvertShortcut = convert, ExcludeShortcut = exclude
        };
    }
    public static Preferences Read(string file)
    {
        try
        {
            if (!File.Exists(file) || new FileInfo(file).Length > 256 * 1024) return new();
            return (JsonSerializer.Deserialize<Preferences>(File.ReadAllText(file)) ?? new()).Normalize();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException) { return new(); }
    }
    public void Save(string file)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        var temp = file + ".tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(Normalize(), new JsonSerializerOptions { WriteIndented = true }));
        File.Move(temp, file, true);
    }
}
