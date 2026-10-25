namespace KiYo.Core;

public sealed record BufferedWord(long Id, string Text, string Candidate, bool Eligible, bool Resolved = false, string? Correction = null);
public sealed record PhraseAttempt(long Generation, long Revision, nint Window, nint Focus, nint Layout,
    BufferedWord[] Words, string Incomplete)
{
    public string Text => string.Concat(Words.Select(w => w.Text + " ")) + Incomplete;
}
public sealed record PhraseAnalysis(PhraseAttempt Attempt, BufferedWord[] Words)
{
    public string Replacement => string.Concat(Words.Select(w => (w.Correction ?? w.Text) + " ")) + Attempt.Incomplete;
    public bool Changed => Words.Any(w => w.Correction != null && w.Correction != w.Text);
    // Never change layout halfway through a word or infer it from an older word.
    public BufferedWord? LastWord => Words.LastOrDefault(w => w.Text.Length > 0);
    public string? LayoutWord => Attempt.Incomplete.Length == 0 ? LastWord?.Correction : null;
}
public static class PhraseCorrection
{
    public static PhraseAnalysis Analyze(PhraseAttempt attempt, Func<string, string, string?> correct) => new(attempt,
        attempt.Words.Select(w => w.Resolved ? w : w with
        {
            Resolved = true,
            Correction = w.Eligible ? correct(w.Text, w.Candidate) : null
        }).ToArray());
}
