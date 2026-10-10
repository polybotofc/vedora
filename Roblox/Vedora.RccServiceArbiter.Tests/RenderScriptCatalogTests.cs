using System.Text.Json;
using Vedora.RccServiceArbiter.Configuration;
using Vedora.RccServiceArbiter.Rcc;
using Vedora.RccServiceArbiter.Rendering;
using Microsoft.Extensions.Options;
using Roblox.Rendering;
using Xunit;

namespace Vedora.RccServiceArbiter.Tests;

public sealed class RenderScriptCatalogTests
{
    [Theory]
    [InlineData(RenderKind.Avatar, "Avatar_R15_Action", "PNG")]
    [InlineData(RenderKind.Avatar3D, "Avatar_R15_Action", "obj")]
    [InlineData(RenderKind.AvatarHeadshot, "Closeup", "PNG")]
    [InlineData(RenderKind.MeshPart, "MeshPart", "PNG")]
    [InlineData(RenderKind.Animation, "AvatarAnimation", "PNG")]
    public void ModernRcc_UsesJsonThumbnailPayload(RenderKind kind, string expectedType, string expectedFormat)
    {
        var catalog = CreateCatalog();
        var execution = catalog.Create(new RenderRequest
        {
            Kind = kind, AssetId = 123, UserId = 456, Width = 640, Height = 360,
            CharacterAppearanceUrl = "https://example.test/avatar", AnimationUrl = "https://example.test/animation",
        });
        using var document = JsonDocument.Parse(execution.Script);
        Assert.Equal("Thumbnail", document.RootElement.GetProperty("Mode").GetString());
        var settings = document.RootElement.GetProperty("Settings");
        Assert.Equal(expectedType, settings.GetProperty("Type").GetString());
        Assert.Contains(settings.GetProperty("Arguments").EnumerateArray(), value => value.ValueKind == JsonValueKind.String && value.GetString() == expectedFormat);
        Assert.Empty(execution.Arguments);
    }

    [Fact]
    public void R6BodyShot_UsesAvatarTypeAndR6ArgumentOrder()
    {
        var execution = CreateCatalog().Create(new RenderRequest
        {
            Kind = RenderKind.Avatar,
            UserId = 456,
            AvatarRigType = AvatarRigType.R6,
            CharacterAppearanceUrl = "https://example.test/avatar-r6",
            Width = 840,
            Height = 840,
        });
        using var document = JsonDocument.Parse(execution.Script);
        var settings = document.RootElement.GetProperty("Settings");
        Assert.Equal("Avatar", settings.GetProperty("Type").GetString());
        var arguments = settings.GetProperty("Arguments");
        Assert.Equal("https://example.test/avatar-r6", arguments[0].GetString());
        Assert.Equal("https://example.test/", arguments[1].GetString());
        Assert.Equal("PNG", arguments[2].GetString());
        Assert.Equal(840, arguments[3].GetInt32());
        Assert.Equal(840, arguments[4].GetInt32());
        Assert.Equal(5, arguments.GetArrayLength());
    }

    [Fact]
    public void R15BodyShot_UsesActionTypeAndR15ArgumentOrder()
    {
        var execution = CreateCatalog().Create(new RenderRequest
        {
            Kind = RenderKind.Avatar,
            UserId = 456,
            AvatarRigType = AvatarRigType.R15,
            CharacterAppearanceUrl = "https://example.test/avatar-r15",
            Width = 840,
            Height = 840,
        });
        using var document = JsonDocument.Parse(execution.Script);
        var settings = document.RootElement.GetProperty("Settings");
        Assert.Equal("Avatar_R15_Action", settings.GetProperty("Type").GetString());
        var arguments = settings.GetProperty("Arguments");
        Assert.Equal("https://example.test/", arguments[0].GetString());
        Assert.Equal("https://example.test/avatar-r15", arguments[1].GetString());
        Assert.Equal("PNG", arguments[2].GetString());
        Assert.Equal(10, arguments.GetArrayLength());
    }

    [Fact]
    public void PrivateOrigin_RewritesDependencyHostsAndAddsCorrelationId()
    {
        var catalog = new RenderScriptCatalog(Options.Create(new ArbiterOptions
        {
            BaseUrl = "https://public.example.test",
            Render = new ArbiterRenderOptions { DefaultYear = 2020, OriginBaseUrl = "http://10.0.0.20:8080" },
        }));
        var execution = catalog.Create(new RenderRequest
        {
            Kind = RenderKind.Avatar,
            UserId = 456,
            CharacterAppearanceUrl = "https://api.public.test/v1/avatar?userId=456",
            CorrelationId = "render-abc",
        });
        using var document = JsonDocument.Parse(execution.Script);
        var arguments = document.RootElement.GetProperty("Settings").GetProperty("Arguments");

        var appearance = new Uri(arguments[1].GetString()!);
        Assert.Equal("10.0.0.20", appearance.Host);
        Assert.Equal(8080, appearance.Port);
        Assert.Contains("renderCorrelationId=render-abc", appearance.Query);
    }

    [Theory]
    [InlineData("http://vedora.xyz")]
    [InlineData("http://vedora.xyz/")]
    public void PackageRender_NormalizesBaseUrlBeforeRccConcatenation(string configuredBaseUrl)
    {
        var catalog = new RenderScriptCatalog(Options.Create(new ArbiterOptions
        {
            BaseUrl = configuredBaseUrl,
            Render = new ArbiterRenderOptions { DefaultYear = 2020 },
        }));

        var execution = catalog.Create(new RenderRequest
        {
            Kind = RenderKind.Package,
            AssetUrls = "http://vedora.xyz/asset/?id=1",
        });
        using var document = JsonDocument.Parse(execution.Script);
        var arguments = document.RootElement.GetProperty("Settings").GetProperty("Arguments");

        Assert.Equal("http://vedora.xyz/", arguments[1].GetString());
        Assert.Equal("http://vedora.xyz/asset/?id=1785197", arguments[5].GetString());
    }

    [Fact]
    public void ModernTeeShirt_UsesRegisteredImageOperationWithUnderlyingContentId()
    {
        var catalog = new RenderScriptCatalog(Options.Create(new ArbiterOptions
        {
            BaseUrl = "https://example.test",
            Render = new ArbiterRenderOptions { DefaultYear = 2021 },
        }));

        var execution = catalog.Create(new RenderRequest
        {
            Kind = RenderKind.TeeShirt,
            AssetId = 901455,
            ContentId = 135483,
            Width = 420,
            Height = 420,
        });
        using var document = JsonDocument.Parse(execution.Script);
        var settings = document.RootElement.GetProperty("Settings");
        var arguments = settings.GetProperty("Arguments");

        Assert.Equal("Image", settings.GetProperty("Type").GetString());
        Assert.Equal(135483, arguments[0].GetInt64());
        Assert.Equal("https://example.test/", arguments[1].GetString());
        Assert.Equal("PNG", arguments[2].GetString());
        Assert.Equal(420, arguments[3].GetInt32());
        Assert.Equal(420, arguments[4].GetInt32());
        Assert.Equal(10, arguments.GetArrayLength());
    }

    // The render build (RCCService2021) must ship a thumbnail script for every
    // render kind. RCCService loads <Type>.lua from RCCService<Year>/internalscripts/thumbnails.
    [Fact]
    public void EveryRenderKindHasThumbnailScript()
    {
        var repoRoot = FindRepositoryRoot();
        if (repoRoot == null) return; // Repository layout is not available (packaged test run).

        var thumbnails = Path.Combine(repoRoot, "RCCService", "RCCService2021", "internalscripts", "thumbnails");
        Assert.True(Directory.Exists(thumbnails), $"Missing RCC thumbnail scripts at {thumbnails}");

        var available = Directory.GetFiles(thumbnails, "*.lua")
            .Select(file => Path.GetFileNameWithoutExtension(file)!)
            .ToHashSet(StringComparer.Ordinal);

        var missing = CreateCatalog().KindsWithMissingScripts(available).ToList();

        Assert.True(missing.Count == 0, "RCC 2021 has no thumbnail script for: " + string.Join(", ", missing));
    }

    // The OBJ output token is case-sensitive per build: the 2021 build matches
    // lowercase "obj", older builds use "OBJ".
    [Fact]
    public void ObjFormatToken_MatchesRenderBuild()
    {
        var catalog2020 = new RenderScriptCatalog(Options.Create(new ArbiterOptions
        { BaseUrl = "https://example.test", Render = new ArbiterRenderOptions { DefaultYear = 2020 } }));
        var execution2020 = catalog2020.Create(new RenderRequest { Kind = RenderKind.Avatar3D, UserId = 1, Width = 352, Height = 352 });
        AssertAdaptedFormat(execution2020, "OBJ");

        var catalog2021 = new RenderScriptCatalog(Options.Create(new ArbiterOptions
        { BaseUrl = "https://example.test", Render = new ArbiterRenderOptions { DefaultYear = 2021 } }));
        var execution2021 = catalog2021.Create(new RenderRequest { Kind = RenderKind.Avatar3D, UserId = 1, Width = 352, Height = 352 });
        AssertAdaptedFormat(execution2021, "obj");
    }

    private static void AssertAdaptedFormat(ScriptExecution execution, string expectedFormat)
    {
        using var document = JsonDocument.Parse(execution.Script);
        var arguments = document.RootElement.GetProperty("Settings").GetProperty("Arguments");
        Assert.Contains(arguments.EnumerateArray(), value => value.ValueKind == JsonValueKind.String && value.GetString() == expectedFormat);
    }

    private static string? FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory != null)
        {
            if (Directory.Exists(Path.Combine(directory.FullName, "RCCService", "RCCService2021", "internalscripts")))
                return directory.FullName;
            directory = directory.Parent;
        }
        return null;
    }

    private static RenderScriptCatalog CreateCatalog() => new(Options.Create(new ArbiterOptions
    { BaseUrl = "https://example.test", Render = new ArbiterRenderOptions { DefaultYear = 2021 } }));
}
