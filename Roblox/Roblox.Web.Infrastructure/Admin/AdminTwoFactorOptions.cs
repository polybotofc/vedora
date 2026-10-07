using Microsoft.Extensions.Configuration;

namespace Roblox.Web.Infrastructure.Admin;

public sealed class AdminTwoFactorOptions
{
    public const string SectionName = "AdminTwoFactor";

    /// <summary>
    /// When false, staff are not required to complete TOTP verification before
    /// reaching the admin panel or admin APIs. Enabled by default so production
    /// keeps the second factor.
    /// </summary>
    public bool Required { get; set; } = true;
}

public static class AdminTwoFactorPolicy
{
    public static bool IsRequired(IConfiguration configuration)
    {
        return configuration.GetValue($"{AdminTwoFactorOptions.SectionName}:Required", true);
    }
}
