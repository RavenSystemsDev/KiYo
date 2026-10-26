namespace KiYo.Core;

// Only the observed suffix and one preceding boundary character may be read.
public static class ObservedTail
{
    public static bool Matches(string visible, string expected, bool startsAtDocumentStart)
    {
        if (expected.Length is < 1 or > TypingState.MaxPendingCharacters) return false;
        // A provider can return fewer characters than requested. Matching text
        // alone is insufficient when the preceding boundary was not returned.
        if (visible == expected) return startsAtDocumentStart;
        return visible.Length == expected.Length + 1 && char.IsWhiteSpace(visible[0]) &&
            visible.AsSpan(1).SequenceEqual(expected.AsSpan());
    }
}
