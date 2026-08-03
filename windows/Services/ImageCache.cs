using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;

namespace Ealain.Services;

public static class ImageCache
{
    public static string GetImagesFolder(string styleId, ScreenOrientation orientation)
    {
        var folder = Path.Combine(
            AppPaths.DataRoot,
            styleId,
            orientation == ScreenOrientation.Portrait ? "portrait" : "landscape");
        Directory.CreateDirectory(folder);
        return folder;
    }

    public static List<string> GetImageFiles(string folder)
    {
        try
        {
            if (!Directory.Exists(folder)) return new List<string>();
            return Directory.EnumerateFiles(folder)
                .Where(f => !Path.GetFileName(f).StartsWith('.'))
                .OrderBy(f => f, StringComparer.Ordinal)
                .ToList();
        }
        catch (Exception ex)
        {
            Log.Error("Failed to list cached images: " + ex.Message);
            return new List<string>();
        }
    }

    // The horde serves WebP; decode with ImageSharp and store JPEG so WPF can
    // load cached files without relying on an optional OS WebP codec.
    public static async Task<bool> SaveImageFromUrlAsync(string urlString, string folder)
    {
        try
        {
            var data = await HttpShared.Client.GetByteArrayAsync(urlString);

            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var originalName = "image";
            try
            {
                originalName = Path.GetFileNameWithoutExtension(new Uri(urlString).AbsolutePath);
            }
            catch
            {
            }
            var destination = Path.Combine(folder, $"{timestamp}-{originalName}.jpg");

            using var image = Image.Load(data);
            await image.SaveAsJpegAsync(destination, new JpegEncoder { Quality = 95 });

            Log.Debug("Image saved to: " + destination);
            return true;
        }
        catch (Exception ex)
        {
            Log.Error("Error saving image: " + ex);
            return false;
        }
    }
}
