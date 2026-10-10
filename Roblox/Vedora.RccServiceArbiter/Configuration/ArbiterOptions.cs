using System.ComponentModel.DataAnnotations;

namespace Vedora.RccServiceArbiter.Configuration;

public sealed class ArbiterOptions
{
    [Required]
    public string PublicIp { get; set; } = "127.0.0.1";

    [Required]
    public string BaseUrl { get; set; } = "http://vedora.xyz";

    public string ServiceUrl { get; set; } = string.Empty;

    // RCCService dispatches SOAP methods in its WSDL namespace
    // (http://roblox.com/), so this must stay roblox.com. Anything else makes
    // RCC answer every SOAP call with HTTP 500.
    [Required]
    public string SoapServiceUrl { get; set; } = "roblox.com";

    [Required]
    public string RccServiceRoot { get; set; } = "RCCService";

    [Required]
    public string QuilkinPath { get; set; } = "quilkin.exe";

    public bool ForcedFilteringEnabled { get; set; }

    // Vedora is 2021-only, so game servers always use this year regardless of
    // what a place row requests.
    [Range(2000, 2100)]
    public int GameServerYear { get; set; } = 2021;

    // RCCService launch arguments for game servers. "{port}" is replaced with
    // the allocated SOAP port. Game servers use the RCCService2021 build, which
    // needs "-port"; renders use the RCCService2020 build (see Render.LaunchArguments).
    public string GameServerLaunchArguments { get; set; } = "-Console -Verbose -SettingsFile \"DevSettingsFile.json\" -port {port}";

    public string GlobalMessageTopic { get; set; } = "GlobalMessage_VEDORA";

    [Range(0, 300)]
    public int PostStartDelaySeconds { get; set; } = 15;

    public string GameServerApiKey { get; set; } = string.Empty;

    public string PlaceVisitAccessKey { get; set; } = string.Empty;

    [Required]
    public ArbiterPortOptions Ports { get; set; } = new();

    [Required]
    public ArbiterProcessOptions Processes { get; set; } = new();

    [Required]
    public ArbiterRenderOptions Render { get; set; } = new();
}

public sealed class ArbiterRenderOptions
{
    // Renders use the RCCService2020 build (the build Vedora renders with); only
    // 2020 ships the full modern thumbnail scripts (Image.lua, AnimationSilhouette.lua).
    // Game servers stay on RCCService2021 (see GameServerYear).
    [Range(2000, 2100)] public int DefaultYear { get; set; } = 2020;
    [Range(1, 256)] public int MaxWorkers { get; set; } = 8;
    [Range(0, 256)] public int MinimumWarmWorkers { get; set; } = 3;
    [Range(1, 256)] public int MaximumIdleWorkers { get; set; } = 8;
    [Range(1, 10000)] public int QueueCapacity { get; set; } = 128;
    [Range(1, 10000)] public int InteractiveQueueCapacity { get; set; } = 64;
    [Range(1, 10000)] public int BackgroundQueueCapacity { get; set; } = 128;
    [Range(1, 10000)] public int ConversionQueueCapacity { get; set; } = 8;
    [Range(1, 16)] public int ConversionConcurrency { get; set; } = 2;
    [Range(1, 1000)] public int MaxReuseCount { get; set; } = 50;
    [Range(1, 3600)] public int IdleTtlSeconds { get; set; } = 300;
    [Range(1, 300)] public int JobTimeoutSeconds { get; set; } = 60;
    [Range(1, 4096)] public int MaxDimension { get; set; } = 1920;
    [Range(1, 1024)] public int MaxInputMegabytes { get; set; } = 250;
    [Range(1, 1024)] public int MaxOutputMegabytes { get; set; } = 64;
    public string PlaceConverterPath { get; set; } = "RobloxPlaceConverter.exe";
    public string OriginBaseUrl { get; set; } = string.Empty;
    public bool UseBinaryTransport { get; set; } = true;

    // RCCService launch arguments for render workers. "{port}" is replaced with
    // the allocated SOAP port. Matches the flags the RCCService2020 render batch
    // files use ("-console -verbose -port"); the 2021 "-SettingsFile" flag is
    // not needed here because the 2020 install has no DevSettingsFile.json.
    public string LaunchArguments { get; set; } = "-console -verbose -port {port}";
}

public sealed class ArbiterPortOptions
{
    [Required]
    public PortRange Rcc { get; set; } = new() { Start = 45000, End = 47000 };

    [Required]
    public PortRange GameServer { get; set; } = new() { Start = 50000, End = 60000 };

    [Required]
    public PortRange Proxy { get; set; } = new() { Start = 30000, End = 40000 };

    [Range(0, 3600)]
    public int RecentlyUsedHoldSeconds { get; set; } = 30;
}

public sealed class PortRange
{
    [Range(1, 65535)]
    public int Start { get; set; }

    [Range(1, 65535)]
    public int End { get; set; }
}

public sealed class ArbiterProcessOptions
{
    [Range(1, 10000)]
    public int MaxActiveProcesses { get; set; } = 256;

    [Range(1, 10000)]
    public int MaxActivePerYear { get; set; } = 128;

    [Range(0, 100)]
    public int ReservePerYear { get; set; } = 2;

    [Range(1, 1000)]
    public int MaxReuseCount { get; set; } = 5;

    [Range(1, 86400)]
    public int IdleTtlSeconds { get; set; } = 300;

    [Range(1, 300)]
    public int StartupTimeoutSeconds { get; set; } = 15;

    [Range(1, 300)]
    public int ShutdownTimeoutSeconds { get; set; } = 5;

    [Range(1, int.MaxValue)]
    public int JobExpirationSeconds { get; set; } = 6000000;

    [Range(1, 300)]
    public int CleanupIntervalSeconds { get; set; } = 5;
}
