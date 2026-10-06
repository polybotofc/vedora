namespace Roblox.ApiProxy.Configuration;

public sealed class AdminApiOptions
{
    public const string SectionName = "AdminApi";

    public string PublicBaseUrl { get; set; } = "https://admin.vedora.xyz/v1/";

    public string[] CorsAllowedOrigins { get; set; } =
    [
        "https://vedora.xyz",
        "http://localhost:3000",
        "http://localhost:5200",
    ];
}
