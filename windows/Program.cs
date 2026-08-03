using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Ealain.Services;
using Ealain.UI;

namespace Ealain;

// A Windows screensaver (.scr) is just a renamed .exe that Windows launches
// with one of three flags:
//   /s          run the screensaver fullscreen
//   /c[:hwnd]   show the configuration dialog
//   /p <hwnd>   render a live preview inside the Screen Saver Settings thumbnail
// We add /w, a windowed test mode for development. No arguments shows the
// config dialog, matching the classic scrnsave.lib behavior for double-clicks.
public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        Log.Init();
        var (mode, handle) = ParseArgs(args);
        try
        {
            switch (mode)
            {
                case "/s":
                    RunScreensaver(windowed: false);
                    break;
                case "/w":
                    RunScreensaver(windowed: true);
                    break;
                case "/p":
                    if (handle != IntPtr.Zero) RunPreview(handle);
                    break;
                default:
                    RunConfig();
                    break;
            }
        }
        catch (Exception ex)
        {
            Log.Error("Fatal: " + ex);
        }
    }

    static (string mode, IntPtr handle) ParseArgs(string[] args)
    {
        if (args.Length == 0) return ("/c", IntPtr.Zero);

        var first = args[0].Trim().ToLowerInvariant();
        var mode = first.Length >= 2 ? first[..2] : first;

        var handle = IntPtr.Zero;
        if (first.Length > 3 && first[2] == ':' && long.TryParse(first[3..], out var inlineHandle))
            handle = (IntPtr)inlineHandle;
        if (args.Length > 1 && long.TryParse(args[1], out var argHandle))
            handle = (IntPtr)argHandle;

        return (mode, handle);
    }

    static void RunScreensaver(bool windowed)
    {
        // Windows can launch the saver more than once in quick succession.
        using var mutex = new Mutex(true, "Local\\EalainScreensaver", out var createdNew);
        if (!createdNew) return;

        var app = new Application { ShutdownMode = ShutdownMode.OnLastWindowClose };

        Microsoft.Win32.SystemEvents.PowerModeChanged += (_, e) =>
        {
            if (e.Mode == Microsoft.Win32.PowerModes.Suspend)
                app.Dispatcher.BeginInvoke(() => app.Shutdown());
        };

        if (windowed)
        {
            new ScreensaverWindow(
                new NativeMethods.RECT { Left = 0, Top = 0, Right = 1280, Bottom = 720 },
                windowed: true).Show();
        }
        else
        {
            var monitors = NativeMethods.GetMonitorRects();
            if (monitors.Count == 0)
                monitors.Add(new NativeMethods.RECT { Left = 0, Top = 0, Right = 1920, Bottom = 1080 });
            foreach (var monitor in monitors)
                new ScreensaverWindow(monitor, windowed: false).Show();
        }

        app.Run();
    }

    static void RunConfig()
    {
        var app = new Application { ShutdownMode = ShutdownMode.OnLastWindowClose };
        new ConfigWindow().Show();
        app.Run();
    }

    // Hosts a WPF visual as a child window inside the little monitor thumbnail
    // in the Screen Saver Settings dialog. Best-effort: shows a random cached
    // image, or just the app name if the cache is empty.
    static void RunPreview(IntPtr parentHandle)
    {
        try
        {
            NativeMethods.GetClientRect(parentHandle, out var rect);

            var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
            var parameters = new HwndSourceParameters("Ealain Preview")
            {
                ParentWindow = parentHandle,
                WindowStyle = NativeMethods.WS_CHILD | NativeMethods.WS_VISIBLE,
                PositionX = 0,
                PositionY = 0,
                Width = Math.Max(rect.Width, 1),
                Height = Math.Max(rect.Height, 1),
            };
            var source = new HwndSource(parameters) { RootVisual = BuildPreviewVisual() };
            source.AddHook((IntPtr _, int msg, IntPtr _, IntPtr _, ref bool _) =>
            {
                if (msg == NativeMethods.WM_DESTROY)
                    app.Dispatcher.BeginInvoke(() => app.Shutdown());
                return IntPtr.Zero;
            });

            app.Run();
            source.Dispose();
        }
        catch (Exception ex)
        {
            Log.Error("Preview failed: " + ex.Message);
        }
    }

    static FrameworkElement BuildPreviewVisual()
    {
        var grid = new Grid { Background = Brushes.Black };
        try
        {
            var styleId = Settings.Load().ResolvedStyleId;
            var files = ImageCache.GetImageFiles(
                ImageCache.GetImagesFolder(styleId, ScreenOrientation.Landscape));
            if (files.Count > 0)
            {
                grid.Children.Add(new Image
                {
                    Source = new BitmapImage(new Uri(files[Random.Shared.Next(files.Count)])),
                    Stretch = Stretch.UniformToFill,
                });
                return grid;
            }
        }
        catch
        {
        }

        grid.Children.Add(new TextBlock
        {
            Text = "Ealain",
            Foreground = Brushes.White,
            FontSize = 12,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        });
        return grid;
    }
}
