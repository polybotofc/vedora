using Microsoft.AspNetCore.Http;
using Roblox.Web.Infrastructure.Http;

namespace Roblox.Web.Infrastructure.Auth;

public static class RobloxSessionCookieWriter
{
    public static string AppendSessionCookies(HttpContext httpContext, string sessionId, TimeSpan? lifetime = null)
    {
        var sessionCookie = RobloxSessionTokenCodec.CreateJwt(new SessionTokenPayload
        {
            sessionId = sessionId,
            createdAt = DateTimeOffset.Now.ToUnixTimeSeconds(),
        });

        AppendSessionCookiesForToken(httpContext, sessionCookie, lifetime);
        return sessionCookie;
    }

    public static void AppendSessionCookiesForToken(HttpContext httpContext, string sessionCookie, TimeSpan? lifetime = null)
    {
        var options = CreateSessionCookieOptions(httpContext, lifetime);
        httpContext.Response.Cookies.Append(RobloxWebContextConstants.RobloxSessionCookieName, sessionCookie, options);
        httpContext.Response.Cookies.Append(RobloxWebContextConstants.SessionCookieName, sessionCookie, CreateSessionCookieOptions(httpContext, lifetime));
    }

    public static void DeleteSessionCookies(HttpContext httpContext)
    {
        httpContext.Response.Cookies.Delete(
            RobloxWebContextConstants.RobloxSessionCookieName,
            CreateSessionCookieOptions(httpContext));
        httpContext.Response.Cookies.Delete(
            RobloxWebContextConstants.SessionCookieName,
            CreateSessionCookieOptions(httpContext));
        httpContext.Response.Cookies.Delete(
            RobloxWebContextConstants.AltSessionCookieName,
            CreateSessionCookieOptions(httpContext));
    }

    private static CookieOptions CreateSessionCookieOptions(HttpContext httpContext, TimeSpan? lifetime = null)
    {
        var options = new CookieOptions
        {
            Secure = false,
            Expires = DateTimeOffset.Now.Add(lifetime ?? TimeSpan.FromDays(14)),
            IsEssential = true,
            HttpOnly = true,
            Path = "/",
            SameSite = SameSiteMode.Lax,
        };

        var domain = ResolveCookieDomain(httpContext);
        if (!string.IsNullOrWhiteSpace(domain))
        {
            options.Domain = domain;
        }

        return options;
    }

    private static string? ResolveCookieDomain(HttpContext httpContext)
    {
        var configuredBaseUrl = Roblox.Configuration.ShortBaseUrl;
        if (!string.IsNullOrWhiteSpace(configuredBaseUrl))
        {
            return BuildDomainAttribute(configuredBaseUrl, deriveRootDomain: false);
        }

        // Fall back to the request host. A cookie Domain must be a bare host (no
        // port). For the request host we keep the root domain so the cookie is
        // shared between the website and api subdomains.
        return BuildDomainAttribute(httpContext.Request.Host.Host, deriveRootDomain: true);
    }

    // A cookie Domain attribute must be a bare host: no scheme, port, or path.
    // Localhost and IP addresses are host-only, so they must not set a Domain.
    private static string? BuildDomainAttribute(string? value, bool deriveRootDomain)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var host = value.Trim();

        if (Uri.TryCreate(host, UriKind.Absolute, out var absolute) && !string.IsNullOrWhiteSpace(absolute.Host))
        {
            host = absolute.Host;
        }
        else
        {
            if (Uri.TryCreate("http://" + host, UriKind.Absolute, out var fromHost) &&
                !string.IsNullOrWhiteSpace(fromHost.Host))
            {
                host = fromHost.Host;
            }

            var portSeparator = host.IndexOf(':');
            if (portSeparator >= 0)
            {
                host = host[..portSeparator];
            }
        }

        host = host.Trim().TrimStart('.').TrimEnd('.');
        if (host.Length == 0 ||
            string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase) ||
            System.Net.IPAddress.TryParse(host, out _))
        {
            return null;
        }

        if (deriveRootDomain)
        {
            var labels = host.Split('.', StringSplitOptions.RemoveEmptyEntries);
            if (labels.Length < 2)
            {
                return null;
            }

            host = string.Join('.', labels[^2], labels[^1]);
        }

        return "." + host;
    }
}
