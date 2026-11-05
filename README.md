# Floating Stopwatch

A small, dependency-free stopwatch and countdown timer for Windows. At rest, only the compact time display is visible. Hover over it to reveal the controls with a smooth expansion. It stays above other windows, remembers its position, and can become click-through when you need an unobstructed overlay.

## Run it

Double-click **`Launch Stopwatch.vbs`**. Windows PowerShell and WPF are built into Windows, so there is nothing to install.

You can also run it from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Stopwatch.ps1
```

## Controls

- **START / PAUSE** — start or pause the active stopwatch/timer
- **RESET** — return to zero or the configured countdown duration
- **TIMER / STOPWATCH** — switch modes
- **PIN** — toggle always-on-top
- Move the pointer away to collapse back to the time-only overlay
- Drag the header or time display to move the window
- Double-click the time display to start/pause
- Right-click for opacity and click-through options

### Global shortcuts

These work even while another program is focused:

| Shortcut | Action |
| --- | --- |
| `Ctrl+Alt+Space` | Start / pause |
| `Ctrl+Alt+R` | Reset |
| `Ctrl+Alt+M` | Switch mode |
| `Ctrl+Alt+X` | Toggle click-through mode |

Click-through mode lets mouse clicks pass to the app beneath the timer. Use `Ctrl+Alt+X` to make the stopwatch interactive again.

Preferences are stored in `%LOCALAPPDATA%\FloatingStopwatch\settings.json`.
