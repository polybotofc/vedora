namespace Vedora.RccServiceArbiter.Configuration;

// Resolves the RCCService root independently of the process working directory.
// `dotnet run` sets the CWD to the project directory, while the published binary
// and the test host use different working directories, so relative roots are
// anchored by walking up from the app base directory until the folder is found.
public static class RccPathResolver
{
    public static string ResolveRoot(string configuredRoot)
    {
        if (string.IsNullOrWhiteSpace(configuredRoot))
            return configuredRoot;
        if (Path.IsPathRooted(configuredRoot))
            return configuredRoot;

        foreach (var start in SearchStarts())
        {
            var directory = new DirectoryInfo(start);
            while (directory != null)
            {
                var candidate = Path.Combine(directory.FullName, configuredRoot);
                if (Directory.Exists(candidate))
                    return candidate;
                directory = directory.Parent;
            }
        }

        return configuredRoot;
    }

    public static string ResolveFile(string configuredPath)
    {
        if (string.IsNullOrWhiteSpace(configuredPath))
            return configuredPath;
        if (Path.IsPathRooted(configuredPath))
            return configuredPath;

        foreach (var start in SearchStarts())
        {
            var directory = new DirectoryInfo(start);
            while (directory != null)
            {
                var candidate = Path.Combine(directory.FullName, configuredPath);
                if (File.Exists(candidate))
                    return candidate;
                directory = directory.Parent;
            }
        }

        return Path.GetFullPath(configuredPath);
    }

    private static IEnumerable<string> SearchStarts()
    {
        yield return Directory.GetCurrentDirectory();
        yield return AppContext.BaseDirectory;
    }
}
