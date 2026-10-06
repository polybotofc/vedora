namespace Roblox.Web.Infrastructure.Http;

public static class RobloxWebContextConstants
{
    public const string SessionCookieName = ".PUPPYSECURITY";
    public const string AltSessionCookieName = ".VEDORASECURITY";
    public const string RobloxSessionCookieName = ".ROBLOSECURITY";
    public const string CsrfCookieName = "rbxcsrf4";
    public const string DiscordCookieName = "VEDORA-DISCORD";
    public const string RobloxCookieName = "VEDORA-ROBLOX";
    public const string ProxyAuthorizationHeaderName = "rblx-authorization";
    public const string RequestContextItemKey = "Roblox.Web.Infrastructure.RequestContext";
    public const string LegacySessionItemKey = SessionCookieName;

    public const string UserIdHeaderName = "X-Vedora-UserId";
    public const string UsernameHeaderName = "X-Vedora-Username";
    public const string SessionIdHeaderName = "X-Vedora-SessionId";
    public const string AccountStatusHeaderName = "X-Vedora-AccountStatus";
    public const string AuthTypeHeaderName = "X-Vedora-AuthType";
    public const string GameIdHeaderName = "X-Vedora-GameId";
    public const string PlaceIdHeaderName = "X-Vedora-PlaceId";
    public const string ClientIpHashHeaderName = "X-Vedora-ClientIpHash";
    public const string UserAgentHeaderName = "X-Vedora-UserAgent";
}
