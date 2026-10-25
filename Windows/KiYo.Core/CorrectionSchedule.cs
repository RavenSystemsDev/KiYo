namespace KiYo.Core;

// Monotonic millisecond clock supplied by the host (and virtual-clock tests).
public sealed class CorrectionSchedule
{
    public const int QuietMilliseconds = 25;
    public const int RetentionMilliseconds = 2000;
    private long lastActivity, notBefore, failedRevision = -1;
    private int failures;
    public void Activity(long now) { lastActivity = now; notBefore = 0; failedRevision = -1; failures = 0; }
    public bool Expired(long now) => now - lastActivity >= RetentionMilliseconds;
    public bool Ready(long now) => !Expired(now) && now - lastActivity >= QuietMilliseconds && now >= notBefore;
    public bool Retry(long revision, long now)
    {
        if (failedRevision != revision) { failedRevision = revision; failures = 0; }
        if (++failures >= 5) return false;
        notBefore = now + Math.Min(25 << failures, 200);
        return true;
    }
}
