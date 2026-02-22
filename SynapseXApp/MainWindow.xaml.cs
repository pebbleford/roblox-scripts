using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Microsoft.Win32;

namespace SynapseXApp;

public partial class MainWindow : Window
{
    private const string DefaultGitHubUrl = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/synapsex.lua";

    private readonly (string Name, string Description, string Script)[] _scriptHubPresets =
    [
        ("Infinite Yield", "Powerful admin command script with 400+ commands",
            "loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()"),
        ("Dark Dex", "Advanced explorer for viewing game hierarchy and properties",
            "loadstring(game:HttpGet('https://raw.githubusercontent.com/infyiff/backup/main/dex.lua'))()"),
        ("Simple Spy", "Remote spy to monitor RemoteEvents and RemoteFunctions",
            "loadstring(game:HttpGet('https://github.com/exxtremestuffs/SimpleSpySource/raw/master/SimpleSpy.lua'))()"),
        ("Anti AFK", "Prevents Roblox from kicking you for being idle",
            "local VirtualUser = game:GetService('VirtualUser')\ngame:GetService('Players').LocalPlayer.Idled:Connect(function()\n    VirtualUser:CaptureController()\n    VirtualUser:ClickButton2(Vector2.new())\nend)\nprint('[Anti-AFK] Active')"),
        ("Fullbright", "Removes all darkness/shadows for full visibility",
            "local Lighting = game:GetService('Lighting')\nLighting.Brightness = 2\nLighting.ClockTime = 14\nLighting.FogEnd = 100000\nLighting.GlobalShadows = false\nLighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)\nprint('[Fullbright] Active')"),
        ("ESP Loader", "Load ESP overlay showing players through walls",
            "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/esp.lua'))()"),
        ("Synapse X Revival", "The full Synapse X Revival executor + admin GUI",
            "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/synapsex.lua'))()"),
        ("Speed Hack", "Set custom walkspeed for your character",
            "game:GetService('Players').LocalPlayer.Character.Humanoid.WalkSpeed = 100\nprint('[Speed] WalkSpeed set to 100')"),
        ("Jump Power", "Set custom jump power for your character",
            "game:GetService('Players').LocalPlayer.Character.Humanoid.JumpPower = 150\nprint('[Jump] JumpPower set to 150')"),
        ("Rejoin Server", "Quickly rejoin the current server",
            "local TeleportService = game:GetService('TeleportService')\nlocal Players = game:GetService('Players')\nTeleportService:Teleport(game.PlaceId, Players.LocalPlayer)\nprint('[Rejoin] Teleporting...')"),
        ("Spin Fling", "Spin your character to fling nearby players (V to toggle)",
            "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/spinfling.lua'))()"),
        ("Steal a Brainrot Hub (Only for Steal a Brainrot)", "Auto steal, admin spammer, ESP, fly, noclip - ONLY works in Steal a Brainrot",
            "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/stealabrainrot.lua'))()"),
        ("SAB Admin Tool (Only for Steal a Brainrot)", "Standalone admin spammer + defense mechanism - ONLY works in Steal a Brainrot",
            "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/stealabrainrot-admin.lua'))()"),
        ("99 Nights Hub (Only for 99 Nights in the Forest)", "Auto farm, kill aura, bring items, ESP, fly, saplings - ONLY works in 99 Nights in the Forest",
            "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/99nights.lua'))()"),
        ("SX Revival NBTF Hub (Only for Nuclear Blast Testing Facility)", "Silent aim, wallbang, ESP, aimbot, anti-kick, player actions, 7 tabs - ONLY works in NBTF",
            "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/nbtf.lua'))()")
    ];

    public MainWindow()
    {
        InitializeComponent();
        PopulateScriptHub();
        UpdateLineNumbers();
        SetActiveTab("Execute");
    }

    // ========== TITLE BAR ==========

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
            ToggleMaximize();
        else
            DragMove();
    }

    private void MinimizeButton_Click(object sender, RoutedEventArgs e) =>
        WindowState = WindowState.Minimized;

    private void MaximizeButton_Click(object sender, RoutedEventArgs e) =>
        ToggleMaximize();

    private void CloseButton_Click(object sender, RoutedEventArgs e) =>
        Close();

    private void ToggleMaximize()
    {
        if (WindowState == WindowState.Maximized)
        {
            WindowState = WindowState.Normal;
            MaximizeBtn.Content = "\uE739";
        }
        else
        {
            WindowState = WindowState.Maximized;
            MaximizeBtn.Content = "\uE923";
        }
    }

    // ========== TAB NAVIGATION ==========

    private void TabExecute_Click(object sender, RoutedEventArgs e) => SetActiveTab("Execute");
    private void TabScriptHub_Click(object sender, RoutedEventArgs e) => SetActiveTab("ScriptHub");
    private void TabSettings_Click(object sender, RoutedEventArgs e) => SetActiveTab("Settings");

    private void SetActiveTab(string tab)
    {
        ExecutePanel.Visibility = tab == "Execute" ? Visibility.Visible : Visibility.Collapsed;
        ScriptHubPanel.Visibility = tab == "ScriptHub" ? Visibility.Visible : Visibility.Collapsed;
        SettingsPanel.Visibility = tab == "Settings" ? Visibility.Visible : Visibility.Collapsed;

        var activeBrush = (SolidColorBrush)FindResource("AccentBrush");
        var inactiveBrush = (SolidColorBrush)FindResource("TextSecondaryBrush");

        TabExecute.Foreground = tab == "Execute" ? activeBrush : inactiveBrush;
        TabScriptHub.Foreground = tab == "ScriptHub" ? activeBrush : inactiveBrush;
        TabSettings.Foreground = tab == "Settings" ? activeBrush : inactiveBrush;

        TabExecute.FontWeight = tab == "Execute" ? FontWeights.Bold : FontWeights.Medium;
        TabScriptHub.FontWeight = tab == "ScriptHub" ? FontWeights.Bold : FontWeights.Medium;
        TabSettings.FontWeight = tab == "Settings" ? FontWeights.Bold : FontWeights.Medium;
    }

    // ========== EXECUTE TAB ==========

    private void ExecuteButton_Click(object sender, RoutedEventArgs e)
    {
        var script = ScriptEditor.Text;
        if (string.IsNullOrWhiteSpace(script))
        {
            SetStatus("Nothing to copy - editor is empty");
            return;
        }

        Clipboard.SetText(script);
        SetStatus("Copied! Paste into your executor to run");
    }

    private void ClearButton_Click(object sender, RoutedEventArgs e)
    {
        ScriptEditor.Clear();
        SetStatus("Editor cleared");
    }

    private void OpenFileButton_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "Lua Scripts (*.lua)|*.lua|Text Files (*.txt)|*.txt|All Files (*.*)|*.*",
            Title = "Open Script"
        };

        if (dialog.ShowDialog() == true)
        {
            ScriptEditor.Text = File.ReadAllText(dialog.FileName);
            SetStatus($"Opened: {Path.GetFileName(dialog.FileName)}");
        }
    }

    private void SaveFileButton_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new SaveFileDialog
        {
            Filter = "Lua Scripts (*.lua)|*.lua|Text Files (*.txt)|*.txt|All Files (*.*)|*.*",
            Title = "Save Script",
            DefaultExt = ".lua"
        };

        if (dialog.ShowDialog() == true)
        {
            File.WriteAllText(dialog.FileName, ScriptEditor.Text);
            SetStatus($"Saved: {Path.GetFileName(dialog.FileName)}");
        }
    }

    private void QuickLaunchButton_Click(object sender, RoutedEventArgs e)
    {
        var url = GitHubUrlBox?.Text ?? DefaultGitHubUrl;
        var loadstring = $"loadstring(game:HttpGet(\"{url}\"))()";
        Clipboard.SetText(loadstring);
        SetStatus("Loadstring copied to clipboard! Paste into your executor");
    }

    // ========== LINE NUMBERS ==========

    private void ScriptEditor_TextChanged(object sender, TextChangedEventArgs e) =>
        UpdateLineNumbers();

    private void UpdateLineNumbers()
    {
        var lineCount = ScriptEditor.Text.Split('\n').Length;
        LineNumbers.Text = string.Join("\n", Enumerable.Range(1, Math.Max(lineCount, 1)));
    }

    // ========== SCRIPT HUB ==========

    private void PopulateScriptHub()
    {
        foreach (var (name, description, script) in _scriptHubPresets)
        {
            var item = new Button
            {
                Style = (Style)FindResource("ScriptHubItem"),
                Margin = new Thickness(0, 0, 0, 6),
                Tag = script
            };

            var panel = new Grid();
            panel.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            panel.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            panel.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var textStack = new StackPanel();
            var nameBlock = new TextBlock
            {
                Text = name,
                FontSize = 14,
                FontWeight = FontWeights.SemiBold,
                Foreground = (SolidColorBrush)FindResource("TextPrimaryBrush")
            };
            var descBlock = new TextBlock
            {
                Text = description,
                FontSize = 11,
                Foreground = (SolidColorBrush)FindResource("TextSecondaryBrush"),
                Margin = new Thickness(0, 2, 0, 0)
            };
            textStack.Children.Add(nameBlock);
            textStack.Children.Add(descBlock);
            Grid.SetColumn(textStack, 0);

            var loadBtn = new Button
            {
                Content = "Load",
                Style = (Style)FindResource("DarkButton"),
                Padding = new Thickness(12, 4, 12, 4),
                FontSize = 11,
                Margin = new Thickness(8, 0, 4, 0),
                VerticalAlignment = VerticalAlignment.Center,
                Tag = script
            };
            loadBtn.Click += ScriptHub_LoadClick;
            Grid.SetColumn(loadBtn, 1);

            var copyBtn = new Button
            {
                Content = "Copy",
                Style = (Style)FindResource("AccentButton"),
                Padding = new Thickness(12, 4, 12, 4),
                FontSize = 11,
                VerticalAlignment = VerticalAlignment.Center,
                Tag = script
            };
            copyBtn.Click += ScriptHub_CopyClick;
            Grid.SetColumn(copyBtn, 2);

            panel.Children.Add(textStack);
            panel.Children.Add(loadBtn);
            panel.Children.Add(copyBtn);

            item.Content = panel;
            item.Click += (s, _) =>
            {
                ScriptEditor.Text = (string)((Button)s).Tag;
                SetActiveTab("Execute");
                SetStatus($"Loaded: {name}");
            };

            ScriptHubList.Children.Add(item);
        }
    }

    private void ScriptHub_LoadClick(object sender, RoutedEventArgs e)
    {
        e.Handled = true;
        var script = (string)((Button)sender).Tag;
        ScriptEditor.Text = script;
        SetActiveTab("Execute");
        SetStatus("Script loaded into editor");
    }

    private void ScriptHub_CopyClick(object sender, RoutedEventArgs e)
    {
        e.Handled = true;
        var script = (string)((Button)sender).Tag;
        Clipboard.SetText(script);
        SetStatus("Script copied to clipboard!");
    }

    // ========== SETTINGS TAB ==========

    private void CopyLoadstringButton_Click(object sender, RoutedEventArgs e)
    {
        var url = GitHubUrlBox.Text;
        var loadstring = $"loadstring(game:HttpGet(\"{url}\"))()";
        Clipboard.SetText(loadstring);
        LoadstringPreview.Text = loadstring;
        SetStatus("Loadstring copied to clipboard!");
    }

    // ========== STATUS BAR ==========

    private void SetStatus(string message) =>
        StatusText.Text = message;
}
