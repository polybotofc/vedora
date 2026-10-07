namespace Vedora.RccServiceArbiter.Processes;

// Builds the RCCService command line. "{port}" is replaced with the allocated
// SOAP port; the template comes from Arbiter:Render:LaunchArguments so the
// exact flags can be tuned per RCCService build without a code change.
public static class RccLaunchArguments
{
    public const string DefaultTemplate = "-Console -Verbose -SettingsFile \"DevSettingsFile.json\" -port {port}";

    public static string Build(string? template, int port)
    {
        var value = string.IsNullOrWhiteSpace(template) ? DefaultTemplate : template;
        return value.Replace("{port}", port.ToString());
    }
}
