using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Roblox.Web.Infrastructure.Extensions;

public static class RobloxDataProtectionExtensions
{
    /// <summary>
    /// Configures ASP.NET DataProtection so the key ring survives restarts and is
    /// shared by every service. Without a persistent ring the runtime generates a
    /// fresh key per process, which orphans outstanding antiforgery tokens and logs
    /// "The key {..} was not found in the key ring".
    /// </summary>
    public static IServiceCollection AddVedoraDataProtection(this IServiceCollection services, IConfiguration configuration)
    {
        var dataProtection = services.AddDataProtection()
            .SetApplicationName(configuration["DataProtection:ApplicationName"] ?? "vedora");

        var keysDirectory = configuration["DataProtection:KeysDirectory"];
        if (!string.IsNullOrWhiteSpace(keysDirectory))
        {
            Directory.CreateDirectory(keysDirectory);
            dataProtection.PersistKeysToFileSystem(new DirectoryInfo(keysDirectory));
        }

        return services;
    }
}
