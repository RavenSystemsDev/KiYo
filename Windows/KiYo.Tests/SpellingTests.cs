using KiYo.Core;

internal static class SpellingTests
{
    private static readonly HashSet<string> Dictionary = new(StringComparer.OrdinalIgnoreCase)
    { "hello", "world", "word", "receive", "правильно", "поставить", "игнорируешь", "нужно", "кот", "коты" };
    internal static bool? Valid(string word, bool russian) => Layouts.IsRussian(word) == russian && Dictionary.Contains(word);
    internal static IReadOnlyList<string> Suggestions(string word, bool russian) => word.ToLowerInvariant() switch
    {
        "helllo" => ["hello"], "worlld" => ["world", "word"],
        "праивльно" => ["правильно"], "поставвить" => ["поставить"],
        "игнорируешьшь" => ["игнорируешь"], "нунжно" => ["нужно"],
        _ => []
    };
    internal static string? CorrectBuffered(string original, string candidate) =>
        Layouts.CorrectBuffered(original, candidate, true, [], Valid,
            text => Spelling.Correct(text, [], Valid, Suggestions));
    internal static int Run()
    {
        var checks = 0;
        void Check(bool ok, string name) { checks++; if (!ok) throw new Exception("SPELLING: " + name); }
        void Equal(string? expected, string? actual, string name) => Check(expected == actual, name + $"; expected [{expected}], got [{actual}]");
        string? Correct(string word, string[]? proposals = null, string[]? exclusions = null) =>
            Spelling.Correct(word, exclusions ?? [], Valid, (w, ru) => proposals ?? Suggestions(w, ru));
        foreach (var (input, expected) in new[] {
            ("игнорируешьшь", "игнорируешь"), ("праивльно", "правильно"),
            ("поставвить", "поставить"), ("нунжно", "нужно"),
            ("helllo", "hello"), ("worlld", "world"), ("recieve", "receive") })
        {
            Equal(expected, Correct(input, [expected]), "single-word typo: " + input);
            Equal(char.ToUpperInvariant(expected[0]) + expected[1..] + "!?",
                Correct(char.ToUpperInvariant(input[0]) + input[1..] + "!?", [expected]), "title case and punctuation: " + input);
            Equal(null, Correct(input, [expected], [input]), "excluded input: " + input);
            Equal(null, Correct(input, [expected], [expected]), "excluded result: " + input);
            Equal(null, Correct(input, [expected], [Layouts.Convert(input)]), "excluded other layout: " + input);
        }
        Equal("world", Correct("worlld", ["word", "world"]), "closest word independent of provider order");
        Equal("hello", Correct("helllo", ["hello", "HELLO"]), "duplicate suggestions are not ambiguity");
        Equal(null, Correct("котт", ["кот", "коты"]), "equally close candidates untouched");
        Equal(null, Correct("worlld", ["world", "word"], ["world"]), "excluded best cannot promote a worse candidate");
        Equal(null, Correct("helllo", ["helllo", "hello"]), "provider disagreement is not an autocorrection");
        Equal(null, Correct("qwertyx", ["hello"]), "unrelated word is not a typo");
        Equal(null, Correct("котт", ["кот ты", "кот-ты", "кот\nты", "kitty"]), "no word splitting, controls or cross-language guesses");
        Equal(null, Correct("helllo", Enumerable.Repeat("hello", 33).ToArray()), "oversized provider results rejected");
        Equal(null, Correct("helllo", ["helloo"]), "unverified proposal rejected");
        var invoked = false;
        IReadOnlyList<string> Unexpected(string word, bool ru) { invoked = true; return ["hello"]; }
        foreach (var token in new[] { "hello", "postgres", "CRM", "HEL LLO", "HELLLO", "HelloWorld", "h", "he",
            "ру", "РУ", "helllo1", "user@helllo.com", "https://helllo.com", "helllo.txt", "helllo_world",
            "heлllo", "he\u0301llo", "abc-def", new string('a', 49) })
            Equal(null, Spelling.Correct(token, [], (_, _) => false, Unexpected), "protected/known token: " + token);
        Check(!invoked, "protected tokens never reach the spelling provider");
        Equal(null, Spelling.Correct("helllo", [], (_, _) => null, Unexpected), "missing dictionary is unknown");
        Check(!invoked, "missing dictionary never reaches suggestions");
        Equal(null, Spelling.Correct("helllo", [], (_, _) => true, Unexpected), "correct system word retained");
        Equal("привет", Layouts.CorrectBuffered("ghbdtn", "ghbdtn", true, [], null,
            _ => throw new Exception("Spelling must not override layout correction")), "layout has priority");
        Equal("KiYo", CorrectBuffered("KIYO", "KIYO"), "canonical brand keeps its spelling");
        Equal(null, Layouts.CorrectBuffered("helllo", "helllo", true, []), "disabled spelling keeps prior behavior");
        Equal("hello", Layouts.CorrectBuffered("helllo", "helllo", true, [], null,
            t => Spelling.Correct(t, [], Valid, Suggestions)), "spelling independent from layout dictionary switch");
        Equal(null, Layouts.CorrectBuffered("helllo", "helllo", true, ["helllo"], null,
            _ => throw new Exception("Excluded word must not reach spelling")), "combined pipeline respects exceptions");

        var state = new TypingState(); state.Context(1, 0x409, 10);
        void Type(string text) { foreach (var c in text) if (c == ' ') state.Space(DateTimeOffset.UnixEpoch); else state.Character(c); }
        Type("helllo "); var first = state.Snapshot()!;
        Type("worlld ghbdtn he");
        var old = PhraseCorrection.Analyze(first, CorrectBuffered); state.Remember(old);
        Check(!state.Applied(old, 0, DateTimeOffset.UnixEpoch), "late spelling cannot edit stale text");
        var analysis = PhraseCorrection.Analyze(state.Snapshot()!, CorrectBuffered);
        Equal("hello world привет he", analysis.Replacement, "fast mixed layout and spelling preserve unfinished tail");
        Equal(null, analysis.LayoutWord, "spelling never switches in the middle of a word");
        Check(state.Applied(analysis, 0, DateTimeOffset.UnixEpoch), "current spelling phrase applied");
        Equal("he", state.Buffer, "unfinished prefix kept after replay");
        Type("lllo "); analysis = PhraseCorrection.Analyze(state.Snapshot()!, CorrectBuffered);
        Equal("hello ", analysis.Replacement, "next complete spelling word preserved");
        state.Applied(analysis, 0, DateTimeOffset.UnixEpoch);
        for (int i = 0; i < 6; i++) state.Backspace(DateTimeOffset.UnixEpoch);
        Type("helllo "); Check(!state.HasPending, "manual rejection of spelling respected on retry");

        var file = Path.Combine(Path.GetTempPath(), "kiyo-spelling-" + Guid.NewGuid(), "settings.json");
        try
        {
            new Preferences { SpellingEnabled = true }.Save(file);
            Check(Preferences.Read(file).SpellingEnabled, "spelling preference persisted");
            File.WriteAllText(file, "{\"Enabled\":true,\"UseSystemDictionary\":true}");
            Check(!Preferences.Read(file).SpellingEnabled, "old settings leave spelling off");
            Check(!new Preferences().SpellingEnabled, "new settings require opt-in");
        }
        finally { Directory.Delete(Path.GetDirectoryName(file)!, true); }
        Console.WriteLine($"PASS: spelling safeguards ({checks} checks).");
        return checks;
    }
}
