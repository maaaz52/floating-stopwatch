[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Import-Module (Join-Path $PSScriptRoot 'Stopwatch.Core.psm1') -Force

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class StopwatchNative {
    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint key);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong")]
    public static extern int GetWindowLong(IntPtr hWnd, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLong")]
    public static extern int SetWindowLong(IntPtr hWnd, int index, int newStyle);
}
'@

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Floating Stopwatch" Width="250" Height="64"
        WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowInTaskbar="True">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#EAF0F7"/>
      <Setter Property="Background" Value="#252F3A"/>
      <Setter Property="BorderBrush" Value="#3B4855"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="11,6"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="Medium"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="ButtonSurface" CornerRadius="7" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="ButtonSurface" Property="Background" Value="#334150"/>
                <Setter TargetName="ButtonSurface" Property="BorderBrush" Value="#5B6B7A"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonSurface" Property="Opacity" Value="0.72"/></Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="ButtonSurface" Property="BorderBrush" Value="#5FC7B7"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid x:Name="Shell" Background="Transparent" ClipToBounds="True">
    <Border x:Name="Chrome" Margin="3" CornerRadius="14" Background="#FA171E25" BorderBrush="#536373" BorderThickness="1" Opacity="0">
      <Border.Effect><DropShadowEffect BlurRadius="20" ShadowDepth="3" Color="#0A1017" Opacity="0.55"/></Border.Effect>
    </Border>

    <Grid x:Name="InteractiveChrome" Margin="13,8,13,11" Opacity="0" IsHitTestVisible="False">
      <Grid.RenderTransform><TranslateTransform x:Name="ControlsTransform" Y="8"/></Grid.RenderTransform>

      <Grid x:Name="TitleBar" Height="27" VerticalAlignment="Top" Background="Transparent">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="StateDot" Width="6" Height="6" Fill="#65717D" Margin="1,0,7,0"/>
          <TextBlock x:Name="ModeLabel" Text="STOPWATCH" Foreground="#91A0AE" FontSize="9" FontWeight="SemiBold"/>
        </StackPanel>
        <StackPanel HorizontalAlignment="Right" Orientation="Horizontal">
          <Button x:Name="PinButton" Content="TOP" Width="38" Height="23" Padding="4,2" Margin="0,0,5,0" FontSize="8" ToolTip="Toggle always on top"/>
          <Button x:Name="MinimizeButton" Width="27" Height="23" Padding="5" Margin="0,0,5,0" ToolTip="Minimize">
            <Path Data="M 2,7 L 12,7" Stroke="#EAF0F7" StrokeThickness="1.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
          </Button>
          <Button x:Name="CloseButton" Width="27" Height="23" Padding="5" ToolTip="Close">
            <Path Data="M 2,2 L 12,12 M 12,2 L 2,12" Stroke="#EAF0F7" StrokeThickness="1.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
          </Button>
        </StackPanel>
      </Grid>

      <TextBlock x:Name="StopwatchHint" Text="double-click the time to start or pause" Foreground="#71808E" FontSize="10"
                 HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,91,0,0"/>
      <StackPanel x:Name="DurationPanel" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,87,0,0" Visibility="Collapsed">
        <TextBlock Text="Duration" Foreground="#8E9BA8" FontSize="10" VerticalAlignment="Center" Margin="0,0,8,0"/>
        <TextBox x:Name="DurationInput" Text="05:00" Width="70" Height="24" Padding="5,2" Foreground="#ECF1F6"
                 Background="#202933" BorderBrush="#44515E" HorizontalContentAlignment="Center" FontFamily="Consolas"/>
        <Button x:Name="SetDurationButton" Content="SET" Height="24" Padding="8,2" Margin="6,0,0,0" FontSize="8"/>
      </StackPanel>

      <Grid Height="34" VerticalAlignment="Bottom">
        <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
        <Button x:Name="ModeButton" Grid.Column="0" Content="TIMER" Margin="0,0,4,0"/>
        <Button x:Name="StartButton" Grid.Column="1" Content="START" Margin="3,0" Background="#147D70" BorderBrush="#249C8C" FontWeight="SemiBold"/>
        <Button x:Name="ResetButton" Grid.Column="2" Content="RESET" Margin="4,0,0,0"/>
      </Grid>
    </Grid>

    <TextBlock x:Name="TimeDisplay" Text="00:00:00.00" Height="64" Foreground="#F7FAFC" FontFamily="Cascadia Mono,Consolas"
               FontWeight="SemiBold" FontSize="29" HorizontalAlignment="Center" VerticalAlignment="Top"
               Padding="0,10,0,0" TextOptions.TextFormattingMode="Display" ToolTip="Double-click to start or pause"
               RenderTransformOrigin="0.5,0.5">
      <TextBlock.Effect><DropShadowEffect BlurRadius="7" ShadowDepth="1" Color="#050A0F" Opacity="0.95"/></TextBlock.Effect>
      <TextBlock.RenderTransform>
        <TransformGroup>
          <ScaleTransform x:Name="TimeScale" ScaleX="1" ScaleY="1"/>
          <TranslateTransform x:Name="TimeTransform" Y="0"/>
        </TransformGroup>
      </TextBlock.RenderTransform>
    </TextBlock>
  </Grid>
</Window>
'@

$reader = [System.Xml.XmlNodeReader]::new([xml] $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @('Shell', 'Chrome', 'InteractiveChrome', 'ControlsTransform', 'TitleBar', 'StateDot', 'ModeLabel',
    'PinButton', 'MinimizeButton', 'CloseButton', 'TimeDisplay', 'TimeScale', 'TimeTransform', 'StopwatchHint',
    'DurationPanel', 'DurationInput', 'SetDurationButton', 'ModeButton', 'StartButton', 'ResetButton')
foreach ($name in $names) {
    Set-Variable -Name $name -Value $window.FindName($name) -Scope Script
}

$script:Mode = 'Stopwatch'
$script:IsRunning = $false
$script:Accumulated = [TimeSpan]::Zero
$script:RunClock = [System.Diagnostics.Stopwatch]::new()
$script:CountdownDuration = [TimeSpan]::FromMinutes(5)
$script:IsClickThrough = $false
$script:IsExpanded = $false
$script:Hwnd = [IntPtr]::Zero
$script:SettingsPath = Join-Path $env:LOCALAPPDATA 'FloatingStopwatch\settings.json'
$script:CollapsedWidth = 250.0
$script:CollapsedHeight = 64.0
$script:ExpandedWidth = 340.0
$script:ExpandedHeight = 174.0

function Start-NumberAnimation($Target, $Property, [double] $To, [int] $Milliseconds) {
    $animation = [System.Windows.Media.Animation.DoubleAnimation]::new()
    $animation.To = $To
    $animation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds($Milliseconds))
    $easing = [System.Windows.Media.Animation.CubicEase]::new()
    $easing.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    $animation.EasingFunction = $easing
    $Target.BeginAnimation($Property, $animation)
}

function Set-OverlayExpanded([bool] $Expanded) {
    if ($Expanded -eq $script:IsExpanded) { return }
    $script:IsExpanded = $Expanded

    if ($Expanded) {
        $rightEdge = $window.Left + $script:ExpandedWidth
        $screenRight = [System.Windows.SystemParameters]::VirtualScreenLeft + [System.Windows.SystemParameters]::VirtualScreenWidth
        if ($rightEdge -gt $screenRight) {
            $window.Left = [Math]::Max([System.Windows.SystemParameters]::VirtualScreenLeft, $screenRight - $script:ExpandedWidth)
        }
        # Transparent WPF windows stutter when their dimensions are animated.
        # Resize once, then animate only compositor-friendly opacity/transforms.
        $window.Width = $script:ExpandedWidth
        $window.Height = $script:ExpandedHeight
        $InteractiveChrome.IsHitTestVisible = $true

        Start-NumberAnimation $Chrome ([System.Windows.UIElement]::OpacityProperty) 1.0 110
        Start-NumberAnimation $InteractiveChrome ([System.Windows.UIElement]::OpacityProperty) 1.0 120
        Start-NumberAnimation $ControlsTransform ([System.Windows.Media.TranslateTransform]::YProperty) 0.0 130
        Start-NumberAnimation $TimeTransform ([System.Windows.Media.TranslateTransform]::YProperty) 23.0 130
        Start-NumberAnimation $TimeScale ([System.Windows.Media.ScaleTransform]::ScaleXProperty) 0.92 130
        Start-NumberAnimation $TimeScale ([System.Windows.Media.ScaleTransform]::ScaleYProperty) 0.92 130
        return
    }

    # Collapse immediately when the pointer leaves; cancel active animations so
    # no queued easing or focus state can hold the larger window open.
    $InteractiveChrome.IsHitTestVisible = $false
    $Chrome.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $InteractiveChrome.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $ControlsTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $null)
    $TimeTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $null)
    $TimeScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $null)
    $TimeScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $null)
    $Chrome.Opacity = 0
    $InteractiveChrome.Opacity = 0
    $ControlsTransform.Y = 8
    $TimeTransform.Y = 0
    $TimeScale.ScaleX = 1
    $TimeScale.ScaleY = 1
    $window.Width = $script:CollapsedWidth
    $window.Height = $script:CollapsedHeight
}

function Get-CurrentElapsed {
    if ($script:IsRunning) {
        return $script:Accumulated + $script:RunClock.Elapsed
    }
    return $script:Accumulated
}

function Update-Display {
    $elapsed = Get-CurrentElapsed
    if ($script:Mode -eq 'Timer') {
        $remaining = $script:CountdownDuration - $elapsed
        $TimeDisplay.Text = Format-StopwatchTime -Time $remaining -AllowNegative
        if ($remaining.Ticks -le 0) {
            $TimeDisplay.Foreground = '#FFFF7A7A'
        } else {
            $TimeDisplay.Foreground = '#FFF7FAFC'
        }
    } else {
        $TimeDisplay.Text = Format-StopwatchTime -Time $elapsed
        $TimeDisplay.Foreground = '#FFF7FAFC'
    }
}

function Set-Running([bool] $Running) {
    if ($Running -eq $script:IsRunning) { return }
    if ($Running) {
        $script:RunClock.Restart()
        $script:IsRunning = $true
        $StartButton.Content = 'PAUSE'
        $StartButton.Background = '#FFB36B32'
        $StartButton.BorderBrush = '#FFD18A48'
        $StateDot.Fill = '#FF45D7B6'
    } else {
        $script:Accumulated = Get-CurrentElapsed
        $script:RunClock.Reset()
        $script:IsRunning = $false
        $StartButton.Content = 'START'
        $StartButton.Background = '#FF147D70'
        $StartButton.BorderBrush = '#FF249C8C'
        $StateDot.Fill = '#FF65717D'
    }
    Update-Display
}

function Reset-Time {
    Set-Running $false
    $script:Accumulated = [TimeSpan]::Zero
    Update-Display
}

function Switch-Mode {
    Set-Running $false
    $script:Accumulated = [TimeSpan]::Zero
    if ($script:Mode -eq 'Stopwatch') {
        $script:Mode = 'Timer'
        $ModeLabel.Text = 'COUNTDOWN TIMER'
        $ModeButton.Content = 'STOPWATCH'
        $DurationPanel.Visibility = 'Visible'
        $StopwatchHint.Visibility = 'Collapsed'
    } else {
        $script:Mode = 'Stopwatch'
        $ModeLabel.Text = 'STOPWATCH'
        $ModeButton.Content = 'TIMER'
        $DurationPanel.Visibility = 'Collapsed'
        $StopwatchHint.Visibility = 'Visible'
    }
    Update-Display
}

function Set-CountdownDuration {
    try {
        $script:CountdownDuration = ConvertFrom-DurationText $DurationInput.Text
        $DurationInput.Text = if ($script:CountdownDuration.TotalHours -ge 1) {
            '{0:00}:{1:00}:{2:00}' -f [Math]::Floor($script:CountdownDuration.TotalHours), $script:CountdownDuration.Minutes, $script:CountdownDuration.Seconds
        } else {
            '{0:00}:{1:00}' -f [Math]::Floor($script:CountdownDuration.TotalMinutes), $script:CountdownDuration.Seconds
        }
        Reset-Time
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Invalid duration', 'OK', 'Warning') | Out-Null
        $DurationInput.Focus()
        $DurationInput.SelectAll()
    }
}

function Set-ClickThrough([bool] $Enabled) {
    if ($script:Hwnd -eq [IntPtr]::Zero) { return }
    $GWL_EXSTYLE = -20
    $WS_EX_TRANSPARENT = 0x20
    $style = [StopwatchNative]::GetWindowLong($script:Hwnd, $GWL_EXSTYLE)
    if ($Enabled) { $style = $style -bor $WS_EX_TRANSPARENT } else { $style = $style -band (-bnot $WS_EX_TRANSPARENT) }
    [StopwatchNative]::SetWindowLong($script:Hwnd, $GWL_EXSTYLE, $style) | Out-Null
    $script:IsClickThrough = $Enabled
}

function Save-Settings {
    try {
        $folder = Split-Path $script:SettingsPath
        [System.IO.Directory]::CreateDirectory($folder) | Out-Null
        @{
            Left = $window.Left
            Top = $window.Top
            Topmost = $window.Topmost
            Opacity = $window.Opacity
            Mode = $script:Mode
            DurationSeconds = [int] $script:CountdownDuration.TotalSeconds
        } | ConvertTo-Json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
    } catch { }
}

function Restore-Settings {
    if (-not (Test-Path -LiteralPath $script:SettingsPath)) { return }
    try {
        $settings = Get-Content -LiteralPath $script:SettingsPath -Raw | ConvertFrom-Json
        $virtualLeft = [System.Windows.SystemParameters]::VirtualScreenLeft
        $virtualTop = [System.Windows.SystemParameters]::VirtualScreenTop
        $virtualRight = $virtualLeft + [System.Windows.SystemParameters]::VirtualScreenWidth
        $virtualBottom = $virtualTop + [System.Windows.SystemParameters]::VirtualScreenHeight
        if ($settings.Left -ge ($virtualLeft - $window.Width + 60) -and $settings.Left -le ($virtualRight - 60)) { $window.Left = $settings.Left }
        if ($settings.Top -ge $virtualTop -and $settings.Top -le ($virtualBottom - 60)) { $window.Top = $settings.Top }
        $window.Topmost = [bool] $settings.Topmost
        if ($settings.Opacity -ge 0.45 -and $settings.Opacity -le 1) { $window.Opacity = $settings.Opacity }
        if ($settings.DurationSeconds -gt 0) {
            $script:CountdownDuration = [TimeSpan]::FromSeconds([double] $settings.DurationSeconds)
            $DurationInput.Text = if ($script:CountdownDuration.TotalHours -ge 1) {
                '{0:00}:{1:00}:{2:00}' -f [Math]::Floor($script:CountdownDuration.TotalHours), $script:CountdownDuration.Minutes, $script:CountdownDuration.Seconds
            } else {
                '{0:00}:{1:00}' -f [Math]::Floor($script:CountdownDuration.TotalMinutes), $script:CountdownDuration.Seconds
            }
        }
        if ($settings.Mode -eq 'Timer') { Switch-Mode }
    } catch { }
}

function New-ContextMenu {
    $menu = [System.Windows.Controls.ContextMenu]::new()

    $topItem = [System.Windows.Controls.MenuItem]::new()
    $topItem.Header = 'Always on top'
    $topItem.IsCheckable = $true
    $topItem.IsChecked = $window.Topmost
    $topItem.Add_Click({ $window.Topmost = $topItem.IsChecked; $PinButton.Opacity = if ($window.Topmost) { 1 } else { 0.55 } }.GetNewClosure())
    $menu.Items.Add($topItem) | Out-Null

    $clickItem = [System.Windows.Controls.MenuItem]::new()
    $clickItem.Header = 'Click-through mode  (Ctrl+Alt+X to exit)'
    $clickItem.IsCheckable = $true
    $clickItem.Add_Click({ Set-ClickThrough $clickItem.IsChecked }.GetNewClosure())
    $menu.Items.Add($clickItem) | Out-Null

    $opacityMenu = [System.Windows.Controls.MenuItem]::new()
    $opacityMenu.Header = 'Opacity'
    foreach ($percent in @(100, 90, 75, 60)) {
        $item = [System.Windows.Controls.MenuItem]::new()
        $item.Header = "$percent%"
        $value = $percent / 100.0
        $item.Add_Click({ $window.Opacity = $value }.GetNewClosure())
        $opacityMenu.Items.Add($item) | Out-Null
    }
    $menu.Items.Add($opacityMenu) | Out-Null
    return $menu
}

$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(30)
$timer.Add_Tick({ if ($script:IsRunning) { Update-Display } })

$hoverMonitor = [System.Windows.Threading.DispatcherTimer]::new()
$hoverMonitor.Interval = [TimeSpan]::FromMilliseconds(35)
$hoverMonitor.Add_Tick({
    if (-not $script:IsExpanded) { return }

    $pointer = [System.Windows.Input.Mouse]::GetPosition($window)
    $insideWindow = $pointer.X -ge 0 -and $pointer.Y -ge 0 -and
        $pointer.X -lt $window.ActualWidth -and $pointer.Y -lt $window.ActualHeight

    if (-not $insideWindow) {
        Set-OverlayExpanded $false
    }
})

$StartButton.Add_Click({ Set-Running (-not $script:IsRunning) })
$ResetButton.Add_Click({ Reset-Time })
$ModeButton.Add_Click({ Switch-Mode })
$SetDurationButton.Add_Click({ Set-CountdownDuration })
$DurationInput.Add_KeyDown({ if ($_.Key -eq 'Enter') { Set-CountdownDuration } })
$TimeDisplay.Add_MouseLeftButtonDown({ if ($_.ClickCount -eq 2) { Set-Running (-not $script:IsRunning) } })
$TitleBar.Add_MouseLeftButtonDown({ if ($_.LeftButton -eq 'Pressed') { $window.DragMove() } })
$TimeDisplay.Add_MouseMove({ if ($_.LeftButton -eq 'Pressed') { $window.DragMove() } })
$PinButton.Add_Click({ $window.Topmost = -not $window.Topmost; $PinButton.Opacity = if ($window.Topmost) { 1 } else { 0.55 } })
$MinimizeButton.Add_Click({ $window.WindowState = 'Minimized' })
$CloseButton.Add_Click({ $window.Close() })
$Shell.ContextMenu = New-ContextMenu
$window.Add_MouseEnter({
    Set-OverlayExpanded $true
})

$window.Add_SourceInitialized({
    $helper = [System.Windows.Interop.WindowInteropHelper]::new($window)
    $script:Hwnd = $helper.Handle
    $source = [System.Windows.Interop.HwndSource]::FromHwnd($script:Hwnd)
    $hook = [System.Windows.Interop.HwndSourceHook] {
        param([IntPtr] $hwnd, [int] $msg, [IntPtr] $wParam, [IntPtr] $lParam, [ref] [bool] $handled)
        if ($msg -eq 0x0312) {
            switch ($wParam.ToInt32()) {
                9101 { Set-Running (-not $script:IsRunning) }
                9102 { Reset-Time }
                9103 { Switch-Mode }
                9104 { Set-ClickThrough (-not $script:IsClickThrough) }
            }
            $handled.Value = $true
        }
        return [IntPtr]::Zero
    }
    $source.AddHook($hook)
    $MOD_CONTROL = 0x0002
    $MOD_ALT = 0x0001
    [StopwatchNative]::RegisterHotKey($script:Hwnd, 9101, $MOD_CONTROL -bor $MOD_ALT, 0x20) | Out-Null # Space
    [StopwatchNative]::RegisterHotKey($script:Hwnd, 9102, $MOD_CONTROL -bor $MOD_ALT, 0x52) | Out-Null # R
    [StopwatchNative]::RegisterHotKey($script:Hwnd, 9103, $MOD_CONTROL -bor $MOD_ALT, 0x4D) | Out-Null # M
    [StopwatchNative]::RegisterHotKey($script:Hwnd, 9104, $MOD_CONTROL -bor $MOD_ALT, 0x58) | Out-Null # X
})

$window.Add_Closed({
    Save-Settings
    $timer.Stop()
    $hoverMonitor.Stop()
    if ($script:Hwnd -ne [IntPtr]::Zero) {
        9101..9104 | ForEach-Object { [StopwatchNative]::UnregisterHotKey($script:Hwnd, $_) | Out-Null }
    }
})

Restore-Settings
$window.Width = $script:CollapsedWidth
$window.Height = $script:CollapsedHeight
Update-Display
$timer.Start()
$hoverMonitor.Start()
$window.ShowDialog() | Out-Null
