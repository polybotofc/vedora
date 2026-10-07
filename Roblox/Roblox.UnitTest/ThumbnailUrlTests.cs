using System.Reflection;
using Roblox.Services;

namespace Roblox.UnitTest;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class ThumbnailUrlConfigurationCollection
{
    public const string Name = "ThumbnailUrlConfiguration";
}

// GetThumbnailUrl reads the process-wide Roblox.Configuration statics, so these
// assertions must not race other tests that flip IsCdnEnabled/CdnBaseUrl.
[Collection(ThumbnailUrlConfigurationCollection.Name)]
public sealed class ThumbnailUrlTests
{
    private static readonly MethodInfo GetThumbnailUrl = typeof(ThumbnailsService).GetMethod(
        "GetThumbnailUrl", BindingFlags.NonPublic | BindingFlags.Static)!;

    private static string Invoke(string fileName, bool isThumbnails = true) =>
        (string)GetThumbnailUrl.Invoke(null, [fileName, isThumbnails])!;

    [Fact]
    public void WithoutCdn_ReturnsRootRelativePath()
    {
        var previousEnabled = Roblox.Configuration.IsCdnEnabled;
        var previousBaseUrl = Roblox.Configuration.CdnBaseUrl;
        try
        {
            Roblox.Configuration.IsCdnEnabled = false;
            Roblox.Configuration.CdnBaseUrl = "http://localhost:5200";

            Assert.Equal("/images/thumbnails/abc_thumbnail.png", Invoke("images/thumbnails/abc_thumbnail.png"));
            Assert.Equal("/images/thumbnails/abc_thumbnail3d.json", Invoke("images/thumbnails/abc_thumbnail3d.json"));
            Assert.Equal("/images/thumbnails/abc_thumbnail.png", Invoke("abc_thumbnail"));
            Assert.Equal("/images/groups/abc", Invoke("groups/abc", isThumbnails: false));
            Assert.Equal("/images/groups/abc.png", Invoke("abc", isThumbnails: false));
        }
        finally
        {
            Roblox.Configuration.IsCdnEnabled = previousEnabled;
            Roblox.Configuration.CdnBaseUrl = previousBaseUrl;
        }
    }

    [Fact]
    public void AbsoluteUrls_ArePassedThroughUnchanged()
    {
        var previousEnabled = Roblox.Configuration.IsCdnEnabled;
        try
        {
            Roblox.Configuration.IsCdnEnabled = false;

            Assert.Equal("https://cdn.vedora.xyz/images/thumbnails/abc.png",
                Invoke("https://cdn.vedora.xyz/images/thumbnails/abc.png"));
            Assert.Equal("/img/placeholder.png", Invoke("/img/placeholder.png"));
        }
        finally
        {
            Roblox.Configuration.IsCdnEnabled = previousEnabled;
        }
    }

    [Fact]
    public void WithCdn_ReturnsCdnUrl()
    {
        var previousEnabled = Roblox.Configuration.IsCdnEnabled;
        var previousBaseUrl = Roblox.Configuration.CdnBaseUrl;
        try
        {
            Roblox.Configuration.IsCdnEnabled = true;
            Roblox.Configuration.CdnBaseUrl = "https://cdn.example.com";

            Assert.Equal("https://cdn.example.com/images/thumbnails/abc_thumbnail.png",
                Invoke("images/thumbnails/abc_thumbnail.png"));
        }
        finally
        {
            Roblox.Configuration.IsCdnEnabled = previousEnabled;
            Roblox.Configuration.CdnBaseUrl = previousBaseUrl;
        }
    }
}
