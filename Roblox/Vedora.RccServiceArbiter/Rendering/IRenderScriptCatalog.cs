using Vedora.RccServiceArbiter.Rcc;
using Roblox.Rendering;

namespace Vedora.RccServiceArbiter.Rendering;

public interface IRenderScriptCatalog
{
    ScriptExecution Create(RenderRequest request);

    // Returns the render kinds whose RCC thumbnail script (<Type>.lua) is absent
    // from the given set of available script names.
    IEnumerable<RenderKind> KindsWithMissingScripts(IReadOnlySet<string> availableScripts);
}

