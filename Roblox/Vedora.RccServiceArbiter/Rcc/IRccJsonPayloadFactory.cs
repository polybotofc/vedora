using Vedora.RccServiceArbiter.Models;

namespace Vedora.RccServiceArbiter.Rcc;

public interface IRccJsonPayloadFactory
{
    string CreateGameServerPayload(StartGameServerRequest request, int gameServerPort);
}
