namespace Ealain;

public static class EalainInfo
{
    public const string Version = "1.0";
    public const string DefaultStyleId = "ec929308-bfcf-47b2-92c1-07abdfbc682f";
    public const string HordeApiKey = "0000000000";
    public const string GitHubUrl = "https://github.com/amiantos/ealain";
    public const string BradUrl = "https://bradroot.me";
    public const string HordeUrl = "https://aihorde.net";
    public const string StylesUrl = "https://github.com/amiantos/ealain/blob/main/STYLES.md";
    public const string MessagesUrl = "https://ealain.s3.amazonaws.com/messages.json";

    // Key used to look up this build in messages.json, so Windows users can be
    // messaged independently of macOS users (whose key is just the version).
    public const string MessagesKey = "windows-" + Version;

    public const string ClientAgent = "Ealain-Windows:" + Version + ":" + GitHubUrl;
}

public enum ScreenOrientation
{
    Landscape,
    Portrait,
}

public static class AppPaths
{
    public static string DataRoot => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Ealain");

    public static string SettingsFile => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Ealain", "settings.json");
}

public static class HttpShared
{
    public static readonly HttpClient Client = CreateClient();

    static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        client.DefaultRequestHeaders.Add("Client-Agent", EalainInfo.ClientAgent);
        return client;
    }
}
