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
    DispatcherTimer? statusCycleTimer;
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
            Title = $"Ealain (windowed test — {orientation}, press Esc to close)";
            Width = boundsPx.Width;
            Height = boundsPx.Height;
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

        // A running screensaver covers the screen and has no console, so record
        // where the window actually landed. If a monitor ever ends up only
        // partly covered — the classic symptom of a DPI scaling mismatch — this
        // line is the evidence, measured by the process that owns the window
        // rather than by an outside tool with its own DPI awareness.
        if (NativeMethods.GetWindowRect(hwnd, out var placed))
            Log.Debug(
                $"Placed window at ({placed.Left},{placed.Top}) {placed.Width}x{placed.Height}; "
                + $"requested ({boundsPx.Left},{boundsPx.Top}) {boundsPx.Width}x{boundsPx.Height}; "
                + $"DPI {NativeMethods.GetDpiForWindow(hwnd)}");
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
        statusCycleTimer?.Stop();
        generateTimer?.Stop();
        messageCheckTimer?.Stop();
        messagePulseTimer?.Stop();
        DisplayRegistry.Remove(windowId);
    }

    void OnServiceStatus(string text) => Dispatcher.InvokeAsync(() => UpdateStatusLabel(text));

    void OnImagesSaved() => Dispatcher.InvokeAsync(() =>
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

        if (Committed(bottomImage) == 0.0)
        {
            LoadImageInto(bottomImage, path);
            currentBottomPath = path;
            Log.Debug("Swapped Bottom Image: " + Path.GetFileName(path));
            ShowBottomImage();
        }
        else if (Committed(topImage) == 1.0)
        {
            LoadImageInto(bottomImage, path);
            currentBottomPath = path;
            Log.Debug("Swapped Bottom Image: " + Path.GetFileName(path));
        }
        else if (Committed(topImage) == 0.0)
        {
            LoadImageInto(topImage, path);
            currentTopPath = path;
            Log.Debug("Swapped Top Image: " + Path.GetFileName(path));
        }

        DisplayRegistry.Set(windowId, currentTopPath, currentBottomPath);
    }

    void SwapImageViews()
    {
        if (currentlyAnimating) return;
        currentlyAnimating = true;

        if (Committed(topImage) == 0.0)
        {
            Log.Debug("Displaying Top Image");
            Fade(topImage, 1, 5, OnFadeComplete);
        }
        else
        {
            Log.Debug("Hiding Top Image");
            Fade(topImage, 0, 5, OnFadeComplete);
        }
    }

    void ShowBottomImage()
    {
        Log.Debug("Displaying Bottom Image");
        currentlyAnimating = true;
        Fade(bottomImage, 1, 5, OnFadeComplete);
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
                Dispatcher.InvokeAsync(() => target.Source = bitmap);
            }
            catch (Exception ex)
            {
                Log.Error($"Failed to load image {path}: {ex.Message}");
            }
        });
    }

    // MARK: Status + message labels

    // The status line breathes: fade up, hold, fade down, pause, repeat — at a
    // steady rhythm whether or not the text changes. Incoming statuses queue
    // behind whatever is on screen and are only swapped in at zero opacity, so
    // a message is never replaced mid-fade and every change is separated by a
    // complete fade out. This is a deliberate departure from macOS, which
    // interrupts the current fade the instant a new status arrives.
    const double StatusFadeSeconds = 1.0;
    static readonly TimeSpan StatusHold = TimeSpan.FromSeconds(2.5);
    static readonly TimeSpan StatusPause = TimeSpan.FromSeconds(0.5);

    // The horde poll emits a status every ~5s while generating, so this only
    // elapses once generation has finished and the line has nothing left to say.
    static readonly TimeSpan StatusIdleTimeout = TimeSpan.FromSeconds(12);

    // A breath takes ~5s, about the poll interval, so the queue normally holds
    // one entry. The cap covers bursts: statuses that arrive faster than they
    // can be read are dropped oldest-first, because the newest one is the
    // truthful description of what the horde is doing right now.
    const int MaxQueuedStatuses = 3;

    readonly Queue<string> statusQueue = new();
    string? statusOnScreen;
    DateTime lastStatusReceived;
    bool statusBreathing;

    void UpdateStatusLabel(string text)
    {
        lastStatusReceived = DateTime.UtcNow;

        // Collapse consecutive repeats — the poll re-sends the same line every
        // cycle, and re-queuing it would just delay genuinely new statuses.
        var newest = statusQueue.Count > 0 ? statusQueue.Last() : statusOnScreen;
        if (text == newest) return;

        statusQueue.Enqueue(text);
        while (statusQueue.Count > MaxQueuedStatuses) statusQueue.Dequeue();

        if (!statusBreathing) BreatheStatusLabel();
    }

    // Entered only at zero opacity, where changing the text is invisible.
    void BreatheStatusLabel()
    {
        if (statusQueue.Count > 0)
        {
            statusOnScreen = statusQueue.Dequeue();
            Log.Debug("Status: " + statusOnScreen);
        }
        else if (statusOnScreen == null || DateTime.UtcNow - lastStatusReceived > StatusIdleTimeout)
        {
            // Nothing new and the horde has gone quiet: rest dark until it speaks again.
            statusBreathing = false;
            statusOnScreen = null;
            return;
        }

        statusBreathing = true;
        statusLabel.Text = statusOnScreen;
        Fade(statusLabel, 1.0, StatusFadeSeconds, () =>
            statusCycleTimer = OneShot(StatusHold, FadeStatusLabelOut));
    }

    void FadeStatusLabelOut() =>
        Fade(statusLabel, 0.0, StatusFadeSeconds, () =>
            statusCycleTimer = OneShot(StatusPause, BreatheStatusLabel));

    void ShowMessage(string text)
    {
        messageLabel.Text = text;
        messagePulseTimer?.Stop();
        var visible = true;
        Fade(messageLabel, 1.0, 1.0);
        // macOS chains fadeIn/fadeOutMessageLabel with a 5s delay measured from
        // the start of each fade, so the label toggles every 5 seconds.
        messagePulseTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(5) };
        messagePulseTimer.Tick += (_, _) =>
        {
            visible = !visible;
            Fade(messageLabel, visible ? 1.0 : 0.0, 1.0);
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
                    await Dispatcher.InvokeAsync(() => ShowMessage(message));
                }
            }
            catch (Exception ex)
            {
                Log.Debug("Message check failed: " + ex.Message);
            }
        });
    }

    // MARK: Helpers

    // Core Animation, which the macOS build is written against, keeps a "model"
    // opacity distinct from what is on screen: layer.opacity is committed to a
    // fade's destination the instant that fade starts, and both the opacity
    // tests and the next fade's starting point read that committed value rather
    // than the value being rendered (EalainView.swift:266-292, 382, 395, 408,
    // 420, 472). WPF's Opacity is the live animated value, so the committed
    // value is tracked here instead. Interrupting a fade therefore snaps to the
    // committed value first, exactly as removeAllAnimations() does on macOS.
    readonly Dictionary<UIElement, double> committedOpacity = new();

    double Committed(UIElement element) =>
        committedOpacity.TryGetValue(element, out var value) ? value : 0.0;

    // CAAnimationDelegate.animationDidStop only acts when finished is true
    // (EalainView.swift:200-205), ignoring animations that were replaced.
    // WPF raises Completed for superseded animations too, so this token is how
    // the two cases are told apart; without it a replaced fade would clear the
    // fade that replaced it and write back its own stale target.
    readonly Dictionary<UIElement, object> fadeOwners = new();

    void Fade(UIElement element, double to, double seconds, Action? completed = null)
    {
        var from = Committed(element);
        committedOpacity[element] = to;

        var owner = new object();
        fadeOwners[element] = owner;

        var animation = new DoubleAnimation(from, to, TimeSpan.FromSeconds(seconds))
        {
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut },
        };
        animation.Completed += (_, _) =>
        {
            if (!fadeOwners.TryGetValue(element, out var current) || !ReferenceEquals(current, owner))
                return;
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
