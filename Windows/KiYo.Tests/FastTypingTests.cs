using KiYo.Core;

internal static class FastTypingTests
{
    internal static int Run()
    {
        int checks = 0;
        void Check(bool condition, string name) { checks++; if (!condition) throw new Exception("FAST INPUT: " + name); }
        void Equal(string expected, string actual, string name) => Check(expected == actual, name + $"; expected [{expected}], got [{actual}]");
        static void Type(TypingState s, string text)
        { foreach (var c in text) if (c == ' ') s.Space(DateTimeOffset.UnixEpoch); else s.Character(c); }
        static PhraseAnalysis Analyze(PhraseAttempt p) => PhraseCorrection.Analyze(p, (raw, candidate) => Layouts.CorrectBuffered(raw, candidate, true, []));

        var s = new TypingState(); s.Context(1, 0x409, 10);
        Type(s, "ghbdtn "); var first = s.Snapshot()!;
        Type(s, "hi rfr lt");
        var stale = Analyze(first); s.Remember(stale);
        Check(!s.Current(first), "new typing rejects the stale caret");
        Check(!s.Applied(stale, 0, DateTimeOffset.UnixEpoch), "stale snapshot cannot commit");
        var calls = 0;
        var catchup = PhraseCorrection.Analyze(s.Snapshot()!, (raw, candidate) =>
        { calls++; return Layouts.CorrectBuffered(raw, candidate, true, []); });
        Equal("ghbdtn hi rfr lt", catchup.Attempt.Text, "all pending input retained while worker is busy");
        Equal("привет hi как lt", catchup.Replacement, "completed words fixed; unfinished suffix unchanged");
        Check(calls == 2, "resolved first word reused without repeating dictionary work");
        Check(catchup.LayoutWord == null, "do not switch layout mid-word");
        Check(s.Applied(catchup, 0, DateTimeOffset.UnixEpoch), "catch-up commit");
        Equal("lt", s.Buffer, "unfinished word remains tracked after replay");
        Type(s, "kf ");
        Equal("дела ", Analyze(s.Snapshot()!).Replacement, "next completion is not lost or doubled");

        foreach (var cancel in new Action<TypingState>[] {
            x => x.Invalidate(), x => x.Context(2, 0x409, 20),
            x => x.Context(1, 0x409, 11), x => x.Context(1, 0x419, 10),
            x => x.Backspace(DateTimeOffset.UnixEpoch) })
        {
            s = new(); s.Context(1, 0x409, 10); Type(s, "ghbdtn "); var pending = Analyze(s.Snapshot()!);
            cancel(s); s.Remember(pending);
            Check(!s.Current(pending.Attempt) && !s.HasPending, "context/edit cancellation cannot resurrect pending words");
            Check(!s.Applied(pending, 0, DateTimeOffset.UnixEpoch), "old context cannot commit");
        }

        s = new(); s.Context(1, 0x409, 10); Type(s, "ghbdtn ");
        var committed = Analyze(s.Snapshot()!); s.Applied(committed, 0x419, DateTimeOffset.UnixEpoch);
        Type(s, "r"); // Physical k-position arrived before WM_INPUTLANGCHANGEREQUEST.
        s.Context(1, 0x419, 10); Type(s, "ак ");
        var mixed = Analyze(s.Snapshot()!);
        Equal("rак ", mixed.Attempt.Text, "validate the actual mixed-layout text");
        Equal("как ", mixed.Replacement, "late OS layout acknowledgment preserves physical keys");
        var excluded = PhraseCorrection.Analyze(mixed.Attempt, (raw, candidate) => Layouts.CorrectBuffered(raw, candidate, true, ["как"]));
        Check(!excluded.Changed, "exceptions apply to normalized delayed-layout words");

        Check(Layouts.CorrectBuffered("hi", "рш", true, []) == null, "equivalent normalized result is not replayed repeatedly");

        s = new(); s.Context(1, 0x409, 10); Type(s, "ghbdtn  hi rfr, ltkf! ");
        Equal("привет  hi как, дела! ", Analyze(s.Snapshot()!).Replacement, "repeated spaces and punctuation preserved");
        s = new(); s.Context(1, 0x409, 10); Type(s, "ghbdtn   ");
        var spaces = Analyze(s.Snapshot()!);
        Equal("привет   ", spaces.Replacement, "trailing spaces kept");
        Equal("привет", spaces.LayoutWord!, "trailing spaces do not suppress layout switch");
        s.Applied(spaces, 0x419, DateTimeOffset.UnixEpoch); s.Context(1, 0x419, 10);
        for (int i = 0; i < 9; i++) s.Backspace(DateTimeOffset.UnixEpoch);
        Type(s, "ghbdtn "); Check(!s.HasPending, "manual retry after replay with extra spaces");
        s = new(); s.Context(1, 0x409, 10); Type(s, "ghbdtn user@example.com file_name https://test.io ");
        Equal("привет user@example.com file_name https://test.io ", Analyze(s.Snapshot()!).Replacement, "protected tokens preserved inside burst");
        s = new(); s.Context(1, 0x409, 10); Type(s, "hello "); s.Remember(Analyze(s.Snapshot()!));
        Check(!s.HasPending && s.PendingLength == 0, "valid prefix retired without editor replacement");
        Type(s, "ghbdtn "); Equal("привет ", Analyze(s.Snapshot()!).Replacement, "next word after retired prefix");

        s = new(); s.Context(1, 0x409, 10);
        for (int i = 0; i < 500; i++) { Type(s, "ghbdtn "); Check(s.PendingLength <= TypingState.MaxPendingCharacters, "bounded memory under continuous input"); }
        Check(s.Snapshot()!.Text.StartsWith("ghbdtn "), "capacity trimming never splits a word");
        Type(s, new string('q', 70)); Check(!s.HasPending, "oversized token cannot cause destructive partial replay");
        Type(s, " ghbdtn "); Equal("привет ", Analyze(s.Snapshot()!).Replacement, "recover at boundary after oversized token");
        s.Character('\u0301'); Check(!s.HasPending, "combining input cancels code-unit backspacing");

        var schedule = new CorrectionSchedule(); schedule.Activity(100);
        Check(!schedule.Ready(124) && schedule.Ready(125), "short quiet period before validating editor");
        Check(schedule.Retry(1, 125) && !schedule.Ready(130), "slow editor retry backs off");
        schedule.Activity(140); Check(schedule.Ready(165), "new typing does not inherit failed retry delay");
        for (int i = 0; i < 4; i++) Check(schedule.Retry(2, 200 + i * 200), "bounded validation retries");
        Check(!schedule.Retry(2, 1000), "unsupported editor cannot retry indefinitely");
        Check(schedule.Expired(2140), "idle pending text expires");

        // A partial observed word must never be rewritten leaving its prefix.
        foreach (var (visible, observed) in new[] {
            ("music ", "usic "), ("hello ", "ello "),
            ("mghbdtn ", "ghbdtn "), ("рруддщ ", "руддщ "),
            ("mghbdtn rfr ", "ghbdtn rfr ") })
        {
            Check(!ObservedTail.Matches(visible, observed, true), "unobserved first letter blocks partial replacement");
            Check(!ObservedTail.Matches(visible, observed, false), "mid-document prefix blocks partial replacement");
        }
        foreach (var observed in new[] { "music ", "ghbdtn ", "руддщ ", "ghbdtn rfr ", "ghbdtn r" })
        {
            Check(ObservedTail.Matches(observed, observed, true), "complete observed input at document start");
            Check(!ObservedTail.Matches(observed, observed, false), "provider omitted boundary away from document start");
            foreach (var boundary in new[] { " ", "\t", "\n", "\u00A0" })
                Check(ObservedTail.Matches(boundary + observed, observed, false), "known whitespace boundary permits complete word");
        }
        Check(!ObservedTail.Matches("", "", true), "empty observation is not a replacement target");
        Check(!ObservedTail.Matches("ghbdtn ", "ghbdtn  ", true), "missing observed input is rejected");
        Check(!ObservedTail.Matches(new string('a', 1025), new string('a', 1025), true), "oversized observation rejected");
        foreach (var prefix in new[] { "m", "mm", "р" })
        {
            var interrupted = new Editor(20, false);
            foreach (var c in prefix) interrupted.Key(c);
            interrupted.State.Invalidate(); // Monitoring resumes halfway through a word.
            foreach (var c in "ghbdtn ") { interrupted.Key(c); interrupted.Advance(5); }
            interrupted.Advance(1500);
            Equal(prefix + "ghbdtn ", interrupted.Text, "partial correction cannot leave an extra leading letter");
            Check(!interrupted.State.HasPending, "rejected partial observation is retired");
            foreach (var c in "ghbdtn ") { interrupted.Key(c); interrupted.Advance(5); }
            interrupted.Advance(1500);
            Equal(prefix + "ghbdtn привет ", interrupted.Text, "next complete word still corrects after prefix mismatch");
        }

        // Virtual-time editor models physical keys, layout changes, and variable
        // provider delays. Exact final strings detect missing/reordered letters.
        var scenarios = new[] {
            (Keys: "ghbdtn hi rfr ltkf ", Russian: false, Expected: "привет hi как дела "),
            (Keys: "hi how are you hello ", Russian: true, Expected: "hi how are you hello "),
            (Keys: "ghbdtn  hi  rfr ltkf ", Russian: false, Expected: "привет  hi  как дела ")
        };
        foreach (var scenario in scenarios)
        foreach (int interval in new[] { 1, 5, 10, 20, 40, 80 })
        foreach (int latency in new[] { 0, 5, 40, 120, 240 })
        {
            var editor = new Editor(latency, scenario.Russian);
            foreach (var c in scenario.Keys) { editor.Key(c); editor.Advance(interval); }
            editor.Advance(1500);
            Equal(scenario.Expected, editor.Text, $"physical phrase: keys {interval}ms/provider {latency}ms");
            Check(!editor.State.HasPending, "burst drained after provider catches up");
        }
        foreach (int interval in new[] { 1, 5, 20, 80 })
        foreach (int latency in new[] { 0, 40, 120, 240 })
        {
            var editor = new Editor(latency, false) { CorrectWord = SpellingTests.CorrectBuffered };
            foreach (var c in "helllo worlld ghbdtn hi ") { editor.Key(c); editor.Advance(interval); }
            editor.Advance(1500);
            Equal("hello world привет hi ", editor.Text, $"spelling and layouts at {interval}ms/{latency}ms");
            Check(!editor.State.HasPending, "spelling burst drained");
        }
        var cold = new Editor(20, false) { FirstLatency = 600 };
        foreach (var c in scenarios[0].Keys) { cold.Key(c); cold.Advance(40); }
        cold.Advance(1500);
        Equal(scenarios[0].Expected, cold.Text, "slow cold dictionary result is reused on next fresh validation");
        var lagging = new Editor(20, false) { ReadFailures = 2 };
        foreach (var c in scenarios[0].Keys) { lagging.Key(c); lagging.Advance(5); }
        lagging.Advance(1500);
        Equal(scenarios[0].Expected, lagging.Text, "temporary editor mismatch retries instead of losing phrase");
        var stalled = new Editor(2500, false);
        foreach (var c in scenarios[0].Keys) { stalled.Key(c); stalled.Advance(5); }
        stalled.Advance(3000);
        Equal(scenarios[0].Keys, stalled.Text, "expired slow-provider result does not edit old text");
        Check(!stalled.State.HasPending, "expired in-memory suffix released");
        stalled.Latency = 20;
        foreach (var c in " ghbdtn ") { stalled.Key(c); stalled.Advance(5); }
        stalled.Advance(1500);
        Equal(scenarios[0].Keys + " привет ", stalled.Text, "new input recovers after slow provider returns");
        for (int seed = 0; seed < 1000; seed++)
        {
            var random = new Random(seed);
            var editor = new Editor(random.Next(1, 240), false);
            for (int repetition = 0; repetition < 3; repetition++)
                foreach (var c in scenarios[0].Keys) { editor.Key(c); editor.Advance(random.Next(1, 95)); }
            editor.Advance(1500);
            Equal(string.Concat(Enumerable.Repeat(scenarios[0].Expected, 3)), editor.Text, "jittered typing and in-flight input, seed " + seed);
        }
        Console.WriteLine($"PASS: fast-input regressions ({checks} checks), 90 timing combinations and 1,000 jittered three-phrase sequences.");
        return checks;
    }

    private sealed class Editor(int latency, bool russian)
    {
        internal TypingState State { get; } = new();
        internal string Text { get; private set; } = "";
        private readonly CorrectionSchedule schedule = new();
        private long clock, finish, started;
        internal int Latency { get; set; } = latency;
        internal int FirstLatency { get; set; }
        internal int ReadFailures { get; set; }
        internal Func<string, string, string?>? CorrectWord { get; init; }
        private bool layoutRussian = russian;
        private PhraseAnalysis? job;
        internal void Key(char physical)
        {
            State.Context(1, layoutRussian ? 0x419 : 0x409, 10);
            char visible = layoutRussian && physical != ' ' ? Layouts.Convert(physical.ToString())[0] : physical;
            Text += visible;
            if (visible == ' ') State.Space(DateTimeOffset.UnixEpoch); else State.Character(visible);
            schedule.Activity(clock);
        }
        internal void Advance(int milliseconds)
        {
            for (int i = 0; i < milliseconds; i++)
            {
                clock++;
                if (schedule.Expired(clock)) State.Invalidate();
                if (job != null && clock >= finish)
                {
                    var done = job; job = null;
                    var readStart = Math.Max(0, Text.Length - done.Attempt.Text.Length - 1);
                    var matching = ObservedTail.Matches(Text[readStart..], done.Attempt.Text, readStart == 0);
                    if (ReadFailures > 0) { ReadFailures--; matching = false; }
                    State.Remember(done);
                    if (State.Current(done.Attempt) && done.Changed)
                    {
                        if (!matching || clock - started > 250 || !schedule.Ready(clock))
                        {
                            if (!schedule.Retry(done.Attempt.Revision, clock)) State.Invalidate();
                            continue;
                        }
                        Text = Text[..^done.Attempt.Text.Length] + done.Replacement;
                        nint target = 0;
                        if (done.LayoutWord is { } last) { layoutRussian = Layouts.IsRussian(last); target = layoutRussian ? 0x419 : 0x409; }
                        if (!State.Applied(done, target, DateTimeOffset.UnixEpoch)) throw new Exception("Simulation stale commit");
                    }
                }
                if (job == null && schedule.Ready(clock) && State.Snapshot() is { } next)
                {
                    job = PhraseCorrection.Analyze(next, CorrectWord ?? ((raw, candidate) => Layouts.CorrectBuffered(raw, candidate, true, [])));
                    started = clock; finish = clock + (FirstLatency > 0 ? FirstLatency : Latency); FirstLatency = 0;
                }
            }
        }
    }
}
