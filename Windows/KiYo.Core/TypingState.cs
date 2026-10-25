namespace KiYo.Core;

public sealed record WordAttempt(long Revision, nint Window, nint Layout, string Word);

// A bounded, in-memory suffix of observed input. New characters invalidate a
// snapshot, but keep completed words so a later snapshot can catch up safely.
public sealed class TypingState
{
    public const int MaxPendingCharacters = 1024;
    public long Revision { get; private set; }
    public long Generation { get; private set; }
    public string Buffer { get; private set; } = "";
    private string candidateBuffer = "";
    private readonly List<BufferedWord> words = new();
    private long nextWord;
    private nint window, focus, layout, requestedLayout;
    private bool overflow;
    private string? rejected, correctedOriginal;
    private DateTimeOffset rejectionExpiry, correctionExpiry;
    private int eraseRemaining;
    public bool HasObserved => words.Count > 0 || Buffer.Length > 0 || overflow || eraseRemaining > 0 || requestedLayout != 0 || rejected != null || correctedOriginal != null;
    public bool HasPending => words.Any(w => w.Eligible);
    public int PendingLength => words.Sum(w => w.Text.Length + 1) + Buffer.Length;

    public void Invalidate()
    {
        Generation++; Revision++; Buffer = candidateBuffer = ""; words.Clear(); overflow = false;
        eraseRemaining = 0; requestedLayout = 0; rejected = null; correctedOriginal = null;
    }
    public void Context(nint hwnd, nint hkl, nint nativeFocus = 0)
    {
        if (window == hwnd && focus == nativeFocus && layout == hkl) return;
        if (window == hwnd && focus == nativeFocus && requestedLayout != 0 && requestedLayout == hkl)
        {
            // A key can arrive before Windows handles our layout request. Keep
            // its visible text for validation, and normalize that prefix for the
            // eventual completed word so delayed switching cannot split scripts.
            if (layout != hkl && Buffer.Length > 0) candidateBuffer = Layouts.Convert(Buffer);
            Revision++; layout = hkl; requestedLayout = 0;
            return;
        }
        Invalidate(); window = hwnd; focus = nativeFocus; layout = hkl;
    }
    public void Character(char value)
    {
        // Automatic backspacing is limited to single-unit RU/EN/ASCII input.
        // Emoji, composition and combining characters break the observed suffix.
        if (!(value is >= ' ' and <= '~' || Layouts.IsLetter(value))) { Invalidate(); return; }
        Revision++; eraseRemaining = 0;
        if (overflow) return;
        if (Buffer.Length >= 64)
        {
            Buffer = candidateBuffer = ""; words.Clear(); overflow = true; return;
        }
        Buffer += value; candidateBuffer += value; Trim();
    }
    public void Backspace(DateTimeOffset now)
    {
        // Editing is a deliberate change, unlike appending ordinary characters.
        // Drop older candidates; only the still-observed current word is retained.
        Generation++; Revision++; words.Clear(); requestedLayout = 0;
        if (eraseRemaining > 0 && now <= correctionExpiry && --eraseRemaining == 0)
        { rejected = correctedOriginal; rejectionExpiry = now.AddSeconds(15); }
        if (Buffer.Length > 0) { Buffer = Buffer[..^1]; candidateBuffer = candidateBuffer[..^1]; }
    }
    public WordAttempt? Space(DateTimeOffset now)
    {
        Revision++;
        var word = Buffer; var candidate = candidateBuffer;
        Buffer = candidateBuffer = ""; eraseRemaining = 0;
        if (overflow) { overflow = false; return null; }
        var preserve = rejected != null && now <= rejectionExpiry && string.Equals(rejected, word, StringComparison.OrdinalIgnoreCase);
        rejected = null;
        var eligible = word.Length >= 2 && !preserve;
        words.Add(new(++nextWord, word, candidate, eligible, !eligible)); Trim();
        return eligible ? new(Revision, window, layout, word) : null;
    }
    private void Trim()
    {
        var length = PendingLength;
        while (length > MaxPendingCharacters && words.Count > 0)
        { length -= words[0].Text.Length + 1; words.RemoveAt(0); }
    }
    public PhraseAttempt? Snapshot() => HasPending
        ? new(Generation, Revision, window, focus, layout, words.ToArray(), Buffer) : null;
    public bool Current(PhraseAttempt attempt) => Generation == attempt.Generation && Revision == attempt.Revision &&
        window == attempt.Window && focus == attempt.Focus && layout == attempt.Layout;
    public bool Current(WordAttempt attempt) => Revision == attempt.Revision && window == attempt.Window && layout == attempt.Layout;
    public void Remember(PhraseAnalysis analysis)
    {
        if (Generation != analysis.Attempt.Generation) return;
        var resolved = analysis.Words.ToDictionary(w => w.Id);
        for (int i = 0; i < words.Count; i++)
            if (resolved.TryGetValue(words[i].Id, out var known) && known.Text == words[i].Text && known.Candidate == words[i].Candidate)
                words[i] = known;
        // Valid words before the first correction need never be read or rewritten.
        while (words.Count > 0 && words[0].Resolved && words[0].Correction == null) words.RemoveAt(0);
    }
    public bool Applied(PhraseAnalysis analysis, nint newLayout, DateTimeOffset now)
    {
        if (!Current(analysis.Attempt)) return false;
        words.Clear(); Revision++; requestedLayout = newLayout; eraseRemaining = 0;
        if (analysis.LayoutWord is { } corrected)
        {
            correctedOriginal = analysis.LastWord!.Text;
            var last = Array.FindLastIndex(analysis.Words, w => w.Text.Length > 0);
            eraseRemaining = corrected.Length + analysis.Words.Length - last; correctionExpiry = now.AddSeconds(15);
        }
        return true;
    }
    public void Corrected(WordAttempt attempt, int outputLength, DateTimeOffset now, nint requestedLayout = 0)
    {
        if (!Current(attempt)) return;
        words.Clear(); this.requestedLayout = requestedLayout;
        correctedOriginal = attempt.Word; eraseRemaining = outputLength + 1; correctionExpiry = now.AddSeconds(15);
    }
}
