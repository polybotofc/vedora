namespace Vedora.RccServiceArbiter.Processes;

public interface IRccProcessLauncher
{
    IManagedProcess Start(string fileName, string arguments, string? workingDirectory = null);
}

public interface IManagedProcess : IDisposable
{
    int? Id { get; }
    bool HasExited { get; }
    void KillTree();

    // Captures the process stdout/stderr so a failed RCCService start can be
    // diagnosed. Returns false when the process produced no output.
    bool TryGetOutput(out string output);
}
