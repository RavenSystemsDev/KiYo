namespace KiYo.Core;

public sealed record WordAttempt(long Revision, nint Window, nint Layout, string Word);

// No system input is suppressed. Revision invalidates a pending replacement as soon
// as another key, mouse action, focus, layout or setting change is observed.
public sealed class TypingState
{
    public long Revision { get; private set; }
    public string Buffer { get; private set; } = "";
    private nint window;
    private nint layout;
    private bool overflow;
    private string? rejected;
    private DateTimeOffset rejectionExpiry;
    private int eraseRemaining;
    private string? correctedOriginal;
    private DateTimeOffset correctionExpiry;
    public void Invalidate() { Revision++; Buffer = ""; overflow = false; eraseRemaining = 0; }
    public void Context(nint hwnd, nint hkl)
    {
        if (window != hwnd || layout != hkl) { Invalidate(); window = hwnd; layout = hkl; rejected = null; }
    }
    public void Character(char value)
    {
        Revision++; eraseRemaining = 0;
        if (overflow) return;
        if (Buffer.Length >= 64) { Buffer = ""; overflow = true; return; }
        Buffer += value;
    }
    public void Backspace(DateTimeOffset now)
    {
        Revision++;
        if (eraseRemaining > 0 && now <= correctionExpiry && --eraseRemaining == 0)
        { rejected = correctedOriginal; rejectionExpiry = now.AddSeconds(15); }
        if (Buffer.Length > 0) Buffer = Buffer[..^1];
    }
    public WordAttempt? Space(DateTimeOffset now)
    {
        Revision++;
        var word = Buffer; Buffer = "";
        if (overflow) { overflow = false; return null; }
        var preserve = rejected != null && now <= rejectionExpiry && string.Equals(rejected, word, StringComparison.OrdinalIgnoreCase);
        rejected = null;
        return word.Length >= 2 && !preserve ? new(Revision, window, layout, word) : null;
    }
    public bool Current(WordAttempt attempt) => Revision == attempt.Revision && window == attempt.Window && layout == attempt.Layout;
    public void Corrected(WordAttempt attempt, int outputLength, DateTimeOffset now)
    {
        if (!Current(attempt)) return;
        correctedOriginal = attempt.Word; eraseRemaining = outputLength + 1; correctionExpiry = now.AddSeconds(15);
    }
}
