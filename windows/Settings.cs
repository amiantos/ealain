using System.Text.Json;

namespace Ealain;

public sealed class Settings
{
    public string StyleIdOverride { get; set; } = "";

    public string ResolvedStyleId =>
        string.IsNullOrWhiteSpace(StyleIdOverride) ? EalainInfo.DefaultStyleId : StyleIdOverride.Trim();

    public static Settings Load()
    {
        try
        {
            if (File.Exists(AppPaths.SettingsFile))
                return JsonSerializer.Deserialize<Settings>(File.ReadAllText(AppPaths.SettingsFile)) ?? new Settings();
        }
        catch (Exception ex)
        {
            Log.Error("Failed to load settings: " + ex.Message);
        }
        return new Settings();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(AppPaths.SettingsFile)!);
            File.WriteAllText(
                AppPaths.SettingsFile,
                JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception ex)
        {
            Log.Error("Failed to save settings: " + ex.Message);
        }
    }
}
