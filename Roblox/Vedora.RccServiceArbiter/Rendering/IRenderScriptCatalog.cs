using Vedora.RccServiceArbiter.Rcc;
using Roblox.Rendering;

namespace Vedora.RccServiceArbiter.Rendering;

public interface IRenderScriptCatalog
{
    ScriptExecution Create(RenderRequest request);
}

