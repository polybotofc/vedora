using Vedora.RccServiceArbiter.Configuration;
using Xunit;

namespace Vedora.RccServiceArbiter.Tests;

public class RccPathResolverTests
{
    [Fact]
    public void ResolveRoot_ReturnsAbsolutePathUnchanged()
    {
        var absolute = Path.Combine(Path.GetTempPath(), "vedora-rcc-root");

        Assert.Equal(absolute, RccPathResolver.ResolveRoot(absolute));
    }

    [Fact]
    public void ResolveRoot_ReturnsEmptyValueUnchanged()
    {
        Assert.Equal("", RccPathResolver.ResolveRoot(""));
        Assert.Null(RccPathResolver.ResolveRoot(null!));
    }

    [Fact]
    public void ResolveRoot_FindsRelativeDirectoryUnderAppBase()
    {
        var name = "vedora-rcc-resolver-" + Guid.NewGuid().ToString("N");
        var created = Path.Combine(AppContext.BaseDirectory, name);
        Directory.CreateDirectory(created);
        try
        {
            Assert.Equal(created, RccPathResolver.ResolveRoot(name));
        }
        finally
        {
            Directory.Delete(created);
        }
    }

    [Fact]
    public void ResolveRoot_ReturnsConfiguredValueWhenNothingMatches()
    {
        var name = "vedora-missing-" + Guid.NewGuid().ToString("N");

        Assert.Equal(name, RccPathResolver.ResolveRoot(name));
    }

    [Fact]
    public void ResolveFile_FindsRelativeFileUnderAppBase()
    {
        var name = "vedora-rcc-file-" + Guid.NewGuid().ToString("N") + ".exe";
        var created = Path.Combine(AppContext.BaseDirectory, name);
        File.WriteAllText(created, "");
        try
        {
            Assert.Equal(created, RccPathResolver.ResolveFile(name));
        }
        finally
        {
            File.Delete(created);
        }
    }

    [Fact]
    public void ResolveFile_FallsBackToFullPathWhenMissing()
    {
        var name = "vedora-missing-" + Guid.NewGuid().ToString("N") + ".exe";

        Assert.Equal(Path.GetFullPath(name), RccPathResolver.ResolveFile(name));
    }
}
