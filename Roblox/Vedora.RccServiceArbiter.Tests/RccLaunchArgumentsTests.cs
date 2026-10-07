using Vedora.RccServiceArbiter.Processes;
using Xunit;

namespace Vedora.RccServiceArbiter.Tests;

public class RccLaunchArgumentsTests
{
    [Fact]
    public void Build_SubstitutesPortIntoConfiguredTemplate()
    {
        Assert.Equal("-Console -port 45000", RccLaunchArguments.Build("-Console -port {port}", 45000));
    }

    [Fact]
    public void Build_FallsBackToDefaultTemplateWhenBlank()
    {
        Assert.Equal("-Console -port 1234", RccLaunchArguments.Build("", 1234));
        Assert.Equal("-Console -port 1234", RccLaunchArguments.Build(null, 1234));
        Assert.Equal("-Console -port 1234", RccLaunchArguments.Build("   ", 1234));
    }

    [Fact]
    public void Build_SupportsPositionalPortTemplate()
    {
        Assert.Equal("-console 50000", RccLaunchArguments.Build("-console {port}", 50000));
    }
}
