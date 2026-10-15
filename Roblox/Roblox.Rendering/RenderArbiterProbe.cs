namespace Roblox.Rendering;

/// <summary>
/// Thrown when the RCC arbiter (render server) is known to be unreachable. It is
/// transient by nature: the arbiter is a host process, not a container, so it can
/// still be starting while the website and admin services are already serving.
/// </summary>
public sealed class RenderUnavailableException : Exception
{
    public RenderUnavailableException(string message) : base(message) { }
    public RenderUnavailableException(string message, Exception innerException) : base(message, innerException) { }
}

/// <summary>
/// Remembers a recent connection failure so callers fail fast instead of opening
/// a fresh socket for every queued job while the render server is down. This is
/// what stops the asset render queue from logging an identical
/// <c>Connection refused (host.docker.internal:3521)</c> stack trace per job
/// during a cold start. The window is short, so the first call after the arbiter
/// comes back is a real request and the queue recovers on its own.
/// </summary>
public static class RenderArbiterProbe
{
    private static readonly object Gate = new();
    private static DateTime _unreachableUntil = DateTime.MinValue;
    private static string _reason = string.Empty;

    /// <summary>How long a failed connection suppresses further attempts.</summary>
    public static TimeSpan UnreachableTtl { get; set; } = TimeSpan.FromSeconds(5);

    /// <summary>True while the cached "unreachable" window is still open.</summary>
    public static bool IsUnreachable
    {
        get { lock (Gate) return DateTime.UtcNow < _unreachableUntil; }
    }

    /// <summary>
    /// Throws <see cref="RenderUnavailableException"/> while the arbiter is known
    /// to be down. Callers that only want to skip a doomed request can catch it;
    /// callers that treat it as transient let the queue retry with backoff.
    /// </summary>
    public static void EnsureReachable(Uri? baseAddress)
    {
        string? reason = null;
        lock (Gate)
        {
            if (DateTime.UtcNow < _unreachableUntil)
                reason = _reason;
        }
        if (reason != null)
            throw new RenderUnavailableException(reason);
    }

    /// <summary>Records a connection failure and starts the suppression window.</summary>
    public static void ReportUnreachable(Uri? baseAddress, Exception? cause = null)
    {
        lock (Gate)
        {
            _reason = Describe(baseAddress, cause);
            _unreachableUntil = DateTime.UtcNow.Add(UnreachableTtl);
        }
    }

    /// <summary>Clears the suppression window after a successful request.</summary>
    public static void ReportReachable()
    {
        lock (Gate)
        {
            _unreachableUntil = DateTime.MinValue;
            _reason = string.Empty;
        }
    }

    /// <summary>Test hook: forget any cached failure.</summary>
    public static void Reset() => ReportReachable();

    private static string Describe(Uri? baseAddress, Exception? cause)
    {
        var target = baseAddress == null ? "the render server" : $"{baseAddress.Host}:{baseAddress.Port}";
        var suffix = cause == null ? string.Empty : $" ({cause.GetType().Name})";
        return $"Render server is not reachable at {target}{suffix}";
    }
}
