using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;

namespace Ealain.UI;

public class ConfigWindow : Window
{
    readonly TextBox styleBox = new() { MinWidth = 320, Margin = new Thickness(0, 4, 0, 4) };
    readonly TextBlock savedLabel = new()
    {
        Text = "Saved!",
        Opacity = 0,
        VerticalAlignment = VerticalAlignment.Center,
        Margin = new Thickness(10, 0, 0, 0),
        Foreground = Brushes.Green,
    };

    public ConfigWindow()
    {
        Title = "Ealain Settings";
        SizeToContent = SizeToContent.WidthAndHeight;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;

        var root = new StackPanel { Margin = new Thickness(24), MaxWidth = 460 };

        root.Children.Add(new TextBlock
        {
            Text = "Ealain",
            FontSize = 28,
            FontWeight = FontWeights.Bold,
        });
        root.Children.Add(new TextBlock
        {
            Text = $"Version {EalainInfo.Version} for Windows",
            Foreground = Brushes.Gray,
            Margin = new Thickness(0, 0, 0, 12),
        });
        root.Children.Add(new TextBlock
        {
            Text = "Ealain displays abstract art generated with Stable Diffusion using the AI Horde. "
                 + "Limitless generative art gracing your screen, forever.",
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 16),
        });

        root.Children.Add(new TextBlock
        {
            Text = "Style ID Override",
            FontWeight = FontWeights.SemiBold,
        });
        root.Children.Add(styleBox);
        root.Children.Add(new TextBlock
        {
            Text = "Leave blank to use the default style. Paste an AI Horde style ID to display different art — see the Custom Styles link below.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brushes.Gray,
            FontSize = 11,
            Margin = new Thickness(0, 0, 0, 8),
        });

        var saveRow = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Margin = new Thickness(0, 0, 0, 20),
        };
        var saveButton = new Button { Content = "Save", Padding = new Thickness(20, 4, 20, 4) };
        saveButton.Click += OnSave;
        saveRow.Children.Add(saveButton);
        saveRow.Children.Add(savedLabel);
        root.Children.Add(saveRow);

        root.Children.Add(BuildLinkRow());

        Content = root;
        styleBox.Text = Settings.Load().StyleIdOverride;
    }

    void OnSave(object sender, RoutedEventArgs e)
    {
        var settings = Settings.Load();
        settings.StyleIdOverride = styleBox.Text.Trim();
        settings.Save();

        var fadeIn = new DoubleAnimation(0, 1, TimeSpan.FromSeconds(0.2));
        fadeIn.Completed += (_, _) =>
        {
            var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.5) };
            timer.Tick += (_, _) =>
            {
                timer.Stop();
                savedLabel.BeginAnimation(OpacityProperty, new DoubleAnimation(1, 0, TimeSpan.FromSeconds(0.3)));
            };
            timer.Start();
        };
        savedLabel.BeginAnimation(OpacityProperty, fadeIn);
    }

    static TextBlock BuildLinkRow()
    {
        var block = new TextBlock { TextWrapping = TextWrapping.Wrap };

        void AddLink(string text, string url, bool last = false)
        {
            var link = new Hyperlink(new Run(text)) { NavigateUri = new Uri(url) };
            link.RequestNavigate += (_, e) =>
            {
                try
                {
                    Process.Start(new ProcessStartInfo(e.Uri.AbsoluteUri) { UseShellExecute = true });
                }
                catch
                {
                }
            };
            block.Inlines.Add(link);
            if (!last) block.Inlines.Add(new Run("    "));
        }

        AddLink("GitHub", EalainInfo.GitHubUrl);
        AddLink("AI Horde", EalainInfo.HordeUrl);
        AddLink("Custom Styles", EalainInfo.StylesUrl);
        AddLink("bradroot.me", EalainInfo.BradUrl, last: true);
        return block;
    }
}
