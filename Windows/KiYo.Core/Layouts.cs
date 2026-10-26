using System.Reflection;
using System.Text;

namespace KiYo.Core;

public static class Layouts
{
    private const string English = "`qwertyuiop[]asdfghjkl;'zxcvbnm,.";
    private const string Russian = "ёйцукенгшщзхъфывапролджэячсмитьбю";
    private const string Ending = ".,!?;:";
    private static readonly HashSet<string> En = Load("en");
    private static readonly HashSet<string> Ru = Load("ru");
    private static HashSet<string> Load(string lang)
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream($"KiYo.Core.Words.{lang}.txt")!;
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd().Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToHashSet(StringComparer.OrdinalIgnoreCase);
    }
    internal static bool KnownWord(string word) => (IsRussian(word) ? Ru : En).Contains(word);
    public static bool IsRussian(string text) => text.Any(c => c is >= 'А' and <= 'я' or 'Ё' or 'ё');
    public static bool IsLetter(char c) => c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= 'А' and <= 'я' or 'Ё' or 'ё';
    public static string Convert(string text)
    {
        var result = new StringBuilder(text.Length);
        foreach (var c in text)
        {
            var lower = char.ToLowerInvariant(c);
            var index = English.IndexOf(lower);
            var mapped = index >= 0 ? Russian[index] : (index = Russian.IndexOf(lower)) >= 0 ? English[index] : c;
            result.Append(char.IsUpper(c) ? char.ToUpperInvariant(mapped) : mapped);
        }
        return result.ToString();
    }
    public static bool Protected(string token, IEnumerable<string> exclusions)
    {
        var word = token.Trim().TrimEnd(Ending.ToCharArray());
        return word.Length > 64 || word.Any(char.IsDigit) || word.Contains('@') || word.Contains('/') ||
               word.Contains('\\') || word.Contains('_') || word.StartsWith("www.", StringComparison.OrdinalIgnoreCase) ||
               exclusions.Any(x => x.Equals(word, StringComparison.OrdinalIgnoreCase) || x.Equals(Convert(word), StringComparison.OrdinalIgnoreCase));
    }
    public static string? Correct(string token, bool shortWords, IEnumerable<string> exclusions, Func<string, bool, bool?>? valid = null)
    {
        if (Protected(token, exclusions)) return null;
        var word = token.TrimEnd(Ending.ToCharArray());
        var suffix = token[word.Length..];
        if (word.Length < (shortWords ? 2 : 3) || word.Equals("ру", StringComparison.OrdinalIgnoreCase)) return null;
        if (word.Equals("kiyo", StringComparison.OrdinalIgnoreCase)) return word == "KiYo" ? null : "KiYo" + suffix;
        var russian = IsRussian(word);
        if ((russian ? Ru : En).Contains(word)) return null;
        var converted = Convert(word);
        if (converted.Equals("kiyo", StringComparison.OrdinalIgnoreCase)) return "KiYo" + suffix;
        if ((russian ? En : Ru).Contains(converted)) return converted + suffix;
        // An unsupported spelling language is unknown, never evidence of a misspelling.
        if (word.Length >= 3 && valid?.Invoke(word, russian) == false && valid(converted, !russian) == true)
            return converted + suffix;
        return null;
    }
    public static string? CorrectBuffered(string original, string candidate, bool shortWords,
        IEnumerable<string> exclusions, Func<string, bool, bool?>? valid = null, Func<string, string?>? spelling = null)
    {
        if (Protected(original, exclusions) || Protected(candidate, exclusions)) return null;
        var corrected = Correct(candidate, shortWords, exclusions, valid) ?? spelling?.Invoke(candidate);
        // Candidate differs only when our own asynchronous layout request landed
        // after a prefix was already typed. Preserve the same physical keys.
        var result = corrected ?? (candidate != original ? candidate : null);
        return result == original ? null : result;
    }
    public static string ConvertSelection(string text)
    {
        if (text.Length > 8192) throw new ArgumentOutOfRangeException(nameof(text));
        var result = new StringBuilder(text.Length);
        var word = new StringBuilder();
        void Flush()
        {
            var value = word.ToString();
            var body = value.TrimEnd(Ending.ToCharArray());
            result.Append(Convert(body)).Append(value[body.Length..]);
            word.Clear();
        }
        foreach (var rune in text.EnumerateRunes())
        {
            if (Rune.IsWhiteSpace(rune) || rune.Value > char.MaxValue) { Flush(); result.Append(rune); }
            else word.Append(rune);
        }
        Flush();
        return result.ToString();
    }
    public static string[] ExclusionsFromSelection(string text) => text.Length > 512 ? [] : text
        .Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)
        .Select(w => w.Trim(".,!?;:\"()[]{}".ToCharArray()).ToLowerInvariant())
        .Where(w => w.Length is > 0 and <= 64 && w.All(c => !char.IsControl(c))).Distinct().ToArray();
}
