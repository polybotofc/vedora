namespace Vedora.RccServiceArbiter.Processes;

public interface IRccReadinessProbe
{
    Task WaitUntilAvailableAsync(int port, TimeSpan timeout, CancellationToken cancellationToken);
}
