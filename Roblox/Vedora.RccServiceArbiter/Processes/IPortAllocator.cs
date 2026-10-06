using Vedora.RccServiceArbiter.Configuration;

namespace Vedora.RccServiceArbiter.Processes;

public interface IPortAllocator
{
    int Allocate(PortRange range);
    void Release(int port);
}
