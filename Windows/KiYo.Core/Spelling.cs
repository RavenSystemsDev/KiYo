namespace KiYo.Core;

// Optional, conservative single-word spelling correction. System suggestions are
// evidence, not instructions: reject ambiguous, cross-language or distant edits.
public static class Spelling
{
    public static string? Correct(string token, IEnumerable<string> exclusions,
        Func<string, bool, bool?> valid, Func<string, bool, IReadOnlyList<string>> suggest)
    {
        if (Layouts.Protected(token, exclusions)) return null;
        var word = token.TrimEnd(".,!?;:".ToCharArray());
        if (word.Length is < 4 or > 48 || !word.All(Layouts.IsLetter) ||
            word.Skip(1).Any(char.IsUpper) || Layouts.KnownWord(word)) return null;
        var russian = Layouts.IsRussian(word);
        if (!SameScript(word, russian) || valid(word, russian) != false) return null;
        var candidates = suggest(word, russian);
        // Never rank a truncated list: a missing candidate could create a tie.
        if (candidates.Count is 0 or > 32) return null;
        var limit = word.Length >= 8 ? 2 : 1;
        var bestDistance = int.MaxValue;
        string? best = null;
        var ambiguous = false;
        foreach (var candidate in candidates.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            if (string.IsNullOrEmpty(candidate) || candidate.Length is < 2 or > 48 ||
                !candidate.All(Layouts.IsLetter) || !SameScript(candidate, russian)) continue;
            var lower = candidate.ToLowerInvariant();
            if (lower == word.ToLowerInvariant()) return null;
            var distance = Distance(word.ToLowerInvariant(), lower);
            if (distance > limit || valid(lower, russian) != true) continue;
            if (distance < bestDistance) { bestDistance = distance; best = lower; ambiguous = false; }
            else if (distance == bestDistance) ambiguous = true;
        }
        // An excluded best result must not make us choose a less likely word.
        if (ambiguous || best == null || Layouts.Protected(best, exclusions)) return null;
        if (char.IsUpper(word[0])) best = char.ToUpperInvariant(best[0]) + best[1..];
        return best + token[word.Length..];
    }
    private static bool SameScript(string word, bool russian) => word.All(c =>
        russian ? c is >= 'А' and <= 'я' or 'Ё' or 'ё' : c is >= 'A' and <= 'Z' or >= 'a' and <= 'z');

    private static int Distance(string left, string right)
    {
        var d = new int[left.Length + 1, right.Length + 1];
        for (int i = 0; i <= left.Length; i++) d[i, 0] = i;
        for (int j = 0; j <= right.Length; j++) d[0, j] = j;
        for (int i = 1; i <= left.Length; i++)
        for (int j = 1; j <= right.Length; j++)
        {
            d[i, j] = Math.Min(Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1),
                d[i - 1, j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1));
            if (i > 1 && j > 1 && left[i - 1] == right[j - 2] && left[i - 2] == right[j - 1])
                d[i, j] = Math.Min(d[i, j], d[i - 2, j - 2] + 1);
        }
        return d[left.Length, right.Length];
    }
}
