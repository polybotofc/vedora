using Microsoft.AspNetCore.Http;
using Roblox.Website.Middleware;

namespace Roblox.Web.Infrastructure.Tests;

public class ThumbnailMiddlewareTests : IDisposable
{
    private readonly string _basePath;

    public ThumbnailMiddlewareTests()
    {
        _basePath = Path.Combine(Path.GetTempPath(), "vedora-thumbnails-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(_basePath, "3d"));
    }

    public void Dispose()
    {
        if (Directory.Exists(_basePath)) Directory.Delete(_basePath, recursive: true);
    }

    private async Task<(DefaultHttpContext Context, bool NextCalled)> InvokeAsync(string path)
    {
        var context = InfrastructureTestHelpers.Context();
        context.Request.Path = path;
        var nextCalled = false;
        var middleware = new ThumbnailMiddleware(_ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        }, _basePath);

        await middleware.InvokeAsync(context);
        return (context, nextCalled);
    }

    [Fact]
    public async Task ThreeDimensionalJson_IsServedAsJson()
    {
        var json = """{"obj":"images/thumbnails/3d/abc","textures":["images/thumbnails/3d/def_tex_Player1Tex"]}""";
        await File.WriteAllTextAsync(Path.Combine(_basePath, "3d", "abc_thumbnail3d.json"), json);

        var (context, nextCalled) = await InvokeAsync("/images/thumbnails/3d/abc_thumbnail3d.json");

        Assert.False(nextCalled);
        Assert.Equal("application/json", context.Response.ContentType);
        context.Response.Body.Position = 0;
        Assert.Equal(json, await new StreamReader(context.Response.Body).ReadToEndAsync());
    }

    [Fact]
    public async Task Png_IsServedAsImage()
    {
        await File.WriteAllBytesAsync(Path.Combine(_basePath, "abc_thumbnail.png"), [0x89, 0x50, 0x4E, 0x47]);

        var (context, nextCalled) = await InvokeAsync("/images/thumbnails/abc_thumbnail.png");

        Assert.False(nextCalled);
        Assert.Equal("image/png", context.Response.ContentType);
    }

    [Fact]
    public async Task MissingFile_FallsThrough()
    {
        var (_, nextCalled) = await InvokeAsync("/images/thumbnails/does-not-exist.png");

        Assert.True(nextCalled);
    }
}
