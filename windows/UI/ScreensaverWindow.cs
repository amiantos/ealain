using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Ealain.Services;

namespace Ealain.UI;

// Port of EalainView.swift: two stacked images crossfading every ~15 seconds,
// with a status label for AI Horde progress in the bottom-left corner.
public class ScreensaverWindow : Window
{
    readonly NativeMethods.RECT boundsPx;
    readonly bool windowed;
    readonly Guid windowId = Guid.NewGuid();
    readonly ScreenOrientation orientation;
    readonly GenerationService service;

    readonly Image bottomImage = new() { Stretch = Stretch.UniformToFill, Opacity = 0 };
    readonly Image topImage = new() { Stretch = Stretch.UniformToFill, Opacity = 0 };
    readonly TextBlock statusLabel;
    readonly TextBlock messageLabel;

    List<string> urls = new();
    readonly List<string> recentlyUsed = new();
    string? currentTopPath;
    string? currentBottomPath;

    bool currentlyAnimating;
    bool firstImageDisplayed;

    DispatcherTimer? swapTimer;
    DispatcherTimer? statusFadeTimer;
    DispatcherTimer? generateTimer;
    DispatcherTimer? messageCheckTimer;
    DispatcherTimer? messagePulseTimer;

    Point? lastMousePosition;

    public ScreensaverWindow(NativeMethods.RECT bounds, bool windowed)
    {
        boundsPx = bounds;
        this.windowed = windowed;
        orientation = bounds.Width < bounds.Height ? ScreenOrientation.Portrait : ScreenOrientation.Landscape;
        service = GenerationService.For(orientation);

        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        Background = Brushes.Black;
        ShowInTaskbar = windowed;
        WindowStartupLocation = windowed ? WindowStartupLocation.CenterScreen : WindowStartupLocation.Manual;
        if (windowed)
        {
            Title = "Ealain (windowed test — press Esc to close)";
            Width = 1280;
            Height = 720;
        }
        else
        {
            Topmost = true;
            Cursor = Cursors.None;
        }

        statusLabel = MakeLabel(bottomMargin: 10);
        messageLabel = MakeLabel(bottomMargin: 40);

        var grid = new Grid();
        grid.Children.Add(bottomImage);
        grid.Children.Add(topImage);
        grid.Children.Add(statusLabel);
        grid.Children.Add(messageLabel);
        Content = grid;

        SourceInitialized += OnSourceInitialized;
        Loaded += OnLoaded;
        Closed += OnClosed;

        if (windowed)
        {
            PreviewKeyDown += (_, e) =>
            {
                if (e.Key == Key.Escape) Close();
            };
        }
        else
        {
            PreviewKeyDown += (_, _) => ExitScreensaver();
            PreviewMouseDown += (_, _) => ExitScreensaver();
            MouseMove += OnMouseMove;
        }

        service.StatusChanged += OnServiceStatus;
        service.ImagesSaved += OnImagesSaved;
    }

    static TextBlock MakeLabel(double bottomMargin) => new()
    {
        Foreground = Brushes.White,
        FontSize = 16,
        FontWeight = FontWeights.Medium,
        HorizontalAlignment = HorizontalAlignment.Left,
        VerticalAlignment = VerticalAlignment.Bottom,
        Margin = new Thickness(10, 0, 10, bottomMargin),
        Opacity = 0,
        Effect = new DropShadowEffect
        {
            Color = Colors.Black,
            ShadowDepth = 2,
            BlurRadius = 3,
            Opacity = 0.9,
        },
    };

    void OnSourceInitialized(object? sender, EventArgs e)
    {
        if (windowed) return;
        var hwnd = new WindowInteropHelper(this).Handle;
        NativeMethods.SetWindowPos(
            hwnd, NativeMethods.HWND_TOPMOST,
            boundsPx.Left, boundsPx.Top, boundsPx.Width, boundsPx.Height,
            NativeMethods.SWP_SHOWWINDOW);
    }

    void OnLoaded(object? sender, RoutedEventArgs e)
    {
        Log.Debug($"Screensaver started! ({orientation}, {boundsPx.Width}x{boundsPx.Height})");

        UpdateUrls(firstLaunch: true);
        if (urls.Count == 0) UpdateStatusLabel("Ealain is starting...");

        generateTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(5) };
        generateTimer.Tick += (_, _) =>
        {
            if (urls.Count < GenerationService.MaxImages) service.Kick();
        };
        generateTimer.Start();
        if (urls.Count < GenerationService.MaxImages) service.Kick();

        messageCheckTimer = OneShot(TimeSpan.FromSeconds(60), CheckForMessages);
    }

    void OnClosed(object? sender, EventArgs e)
    {
        service.StatusChanged -= OnServiceStatus;
        service.ImagesSaved -= OnImagesSaved;
        swapTimer?.Stop();
        statusFadeTimer?.Stop();
        generateTimer?.Stop();
        messageCheckTimer?.Stop();
        messagePulseTimer?.Stop();
        DisplayRegistry.Remove(windowId);
    }

    void OnServiceStatus(string text) => Dispatcher.BeginInvoke(() => UpdateStatusLabel(text));

    void OnImagesSaved() => Dispatcher.BeginInvoke(() =>
    {
        if (!firstImageDisplayed) SwapHiddenImage();
    });

    void OnMouseMove(object sender, MouseEventArgs e)
    {
        var position = e.GetPosition(this);
        if (lastMousePosition is Point last)
        {
            if (Math.Abs(position.X - last.X) > 10 || Math.Abs(position.Y - last.Y) > 10)
                ExitScreensaver();
        }
        else
        {
            // Ignore the spurious mouse-move Windows delivers as the window opens.
            lastMousePosition = position;
        }
    }

    void ExitScreensaver() => Application.Current.Shutdown();

    // MARK: Image cycling

    void UpdateUrls(bool firstLaunch)
    {
        try
        {
            urls = ImageCache.GetImageFiles(service.ImagesFolder);
            if (firstLaunch) SwapHiddenImage();
        }
        catch (Exception ex)
        {
            Log.Error(ex.Message);
        }
    }

    string? GetImageUrl()
    {
        UpdateUrls(firstLaunch: false);

        if (urls.Count < 2) return null;

        if (recentlyUsed.Count >= urls.Count)
        {
            Log.Debug("Image list exhausted, pruning recent urls by half");
            recentlyUsed.RemoveRange(0, recentlyUsed.Count / 2);
        }

        var newUrl = urls[Random.Shared.Next(urls.Count)];
        var attempts = 0;
        while (recentlyUsed.Contains(newUrl) && attempts++ < 1000)
            newUrl = urls[Random.Shared.Next(urls.Count)];

        recentlyUsed.Add(newUrl);
        if (!firstImageDisplayed)
        {
            firstImageDisplayed = true;
            Log.Debug("First image displayed!");
        }
        return newUrl;
    }

    void SwapHiddenImage()
    {
        var path = GetImageUrl();
        if (path == null) return;

        if (bottomImage.Opacity == 0.0)
        {
            LoadImageInto(bottomImage, path);
            currentBottomPath = path;
            Log.Debug("Swapped Bottom Image");
            ShowBottomImage();
        }
        else if (topImage.Opacity == 1.0)
        {
            LoadImageInto(bottomImage, path);
            currentBottomPath = path;
            Log.Debug("Swapped Bottom Image");
        }
        else if (topImage.Opacity == 0.0)
        {
            LoadImageInto(topImage, path);
            currentTopPath = path;
            Log.Debug("Swapped Top Image");
        }

        DisplayRegistry.Set(windowId, currentTopPath, currentBottomPath);
    }

    void SwapImageViews()
    {
        if (currentlyAnimating) return;
        currentlyAnimating = true;

        if (topImage.Opacity == 0.0)
        {
            Log.Debug("Displaying Top Image");
            Fade(topImage, 0, 1, 5, OnFadeComplete);
        }
        else
        {
            Log.Debug("Hiding Top Image");
            Fade(topImage, 1, 0, 5, OnFadeComplete);
        }
    }

    void ShowBottomImage()
    {
        Log.Debug("Displaying Bottom Image");
        currentlyAnimating = true;
        Fade(bottomImage, 0, 1, 5, OnFadeComplete);
    }

    void OnFadeComplete()
    {
        currentlyAnimating = false;
        Log.Debug("Fade animation complete");
        SwapHiddenImage();

        swapTimer?.Stop();
        swapTimer = OneShot(TimeSpan.FromSeconds(15), SwapImageViews);
    }

    void LoadImageInto(Image target, string path)
    {
        _ = Task.Run(() =>
        {
            try
            {
                var bitmap = new BitmapImage();
                bitmap.BeginInit();
                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                bitmap.UriSource = new Uri(path);
                bitmap.EndInit();
                bitmap.Freeze();
                Dispatcher.BeginInvoke(() => target.Source = bitmap);
            }
            catch (Exception ex)
            {
                Log.Error($"Failed to load image {path}: {ex.Message}");
            }
        });
    }

    // MARK: Status + message labels

    void UpdateStatusLabel(string text)
    {
        statusFadeTimer?.Stop();
        var current = statusLabel.Opacity;
        statusLabel.BeginAnimation(OpacityProperty, null);
        statusLabel.Opacity = current;
        statusLabel.Text = text;
        Fade(statusLabel, current, 1.0, 1.0);
        statusFadeTimer = OneShot(TimeSpan.FromSeconds(5), () =>
            Fade(statusLabel, statusLabel.Opacity, 0.0, 1.0));
    }

    void ShowMessage(string text)
    {
        messageLabel.Text = text;
        messagePulseTimer?.Stop();
        var visible = true;
        Fade(messageLabel, messageLabel.Opacity, 1.0, 1.0);
        messagePulseTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(6) };
        messagePulseTimer.Tick += (_, _) =>
        {
            visible = !visible;
            Fade(messageLabel, messageLabel.Opacity, visible ? 1.0 : 0.0, 1.0);
        };
        messagePulseTimer.Start();
    }

    void CheckForMessages()
    {
        Log.Debug("Checking for messages for this version of Ealain...");
        _ = Task.Run(async () =>
        {
            try
            {
                var json = await HttpShared.Client.GetStringAsync(EalainInfo.MessagesUrl);
                var messages = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
                if (messages != null
                    && messages.TryGetValue(EalainInfo.MessagesKey, out var message)
                    && !string.IsNullOrEmpty(message))
                {
                    await Dispatcher.BeginInvoke(() => ShowMessage(message));
                }
            }
            catch (Exception ex)
            {
                Log.Debug("Message check failed: " + ex.Message);
            }
        });
    }

    // MARK: Helpers

    static void Fade(UIElement element, double from, double to, double seconds, Action? completed = null)
    {
        var animation = new DoubleAnimation(from, to, TimeSpan.FromSeconds(seconds))
        {
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut },
        };
        animation.Completed += (_, _) =>
        {
            element.BeginAnimation(OpacityProperty, null);
            element.Opacity = to;
            completed?.Invoke();
        };
        element.BeginAnimation(OpacityProperty, animation);
    }

    DispatcherTimer OneShot(TimeSpan interval, Action action)
    {
        var timer = new DispatcherTimer { Interval = interval };
        timer.Tick += (_, _) =>
        {
            timer.Stop();
            action();
        };
        timer.Start();
        return timer;
    }
}
