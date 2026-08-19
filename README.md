# i3 Workspaces

An [Omarchy](https://omarchy.org) bar widget: i3bar-style workspace numbers,
one per monitor.

Stock `omarchy.workspaces` shows the same global workspace list on every bar
surface, which falls apart once a second monitor is attached -- both bars end
up showing identical numbers regardless of which monitor a workspace actually
lives on. This widget filters to the monitor each bar instance is drawn on, so
each screen shows only its own workspaces, and marks the one that's actually
active on that monitor with a solid accent-filled pill.

![i3-workspaces on two monitors: eDP-1 showing 1 2 3 with 2 active, HDMI-A-2 showing 4 active](demo.png)

## Install

```bash
omarchy plugin add https://github.com/coquer/i3-workspaces.git --enable
```

Or install manually: clone or copy this repo directly into the plugins
directory as `i3-workspaces`:

```bash
cp -r i3-workspaces ~/.config/omarchy/plugins/
```

`~/.config/omarchy/plugins/` is scanned one level deep
(`<pluginsDir>/*/manifest.json`), so `manifest.json` and `Workspaces.qml` have
to sit directly inside `~/.config/omarchy/plugins/i3-workspaces/` -- not
nested inside a wrapper directory.

Then add it to the bar's left section in `~/.config/omarchy/shell.json`:

```json
{ "id": "i3-workspaces" }
```

If the stock `omarchy.workspaces` widget is still in that section too, take
it out -- otherwise both render side by side and you get every workspace
number twice.

Reload the shell to pick up the change:

```bash
pkill -f "quickshell -n -p /usr/share/omarchy/shell"
```

Quickshell relaunches on its own (this is normal on Omarchy).

## Remove

```bash
omarchy plugin remove i3-workspaces
```

Or, if installed manually, delete the folder and drop the `shell.json` entry:

```bash
rm -rf ~/.config/omarchy/plugins/i3-workspaces
```

## Use

Click a number to focus that workspace. Numbers belonging to other monitors
never show up on a bar that isn't theirs -- each monitor only lists the
workspaces Hyprland has assigned to it, plus whichever workspace is currently
active there (so the bar never renders empty).

The active workspace on each monitor gets a solid accent pill regardless of
which monitor currently holds keyboard focus -- i.e. jumping your focus to a
second monitor doesn't gray out the workspace you left behind on the first
one. Text-color-only highlighting was tried first and dropped: several themes
use an accent close enough to the muted gray that the "active" state was hard
to read at bar font size, so a background fill was used instead for a signal
that survives any theme.

## Settings

Set in the widget's entry in `shell.json`:

```json
{ "id": "i3-workspaces", "maxWorkspaceId": 10 }
```

| Key | Default | Meaning |
| --- | --- | --- |
| `maxWorkspaceId` | `10` | Highest workspace number shown. Workspace 10 always renders as `0`, matching Hyprland's default keybinds. |

## How the per-monitor filtering works

Each bar surface is a separate instance of this widget, one per monitor. It
reads its own output name off `QsWindow.window.screen.name` and filters
`Hyprland.workspaces` down to whatever Hyprland reports as that workspace's
owning monitor (`workspace.monitor.name`, falling back to the raw IPC
payload). The monitor's own active workspace comes from
`Hyprland.monitors` rather than the globally focused workspace, since those
diverge the moment a second monitor exists.

`QsWindow` carries no change-notification, so reading it into a cached
`readonly property` at binding time can freeze at an empty screen name if the
widget evaluates before it's fully parented into its window -- this widget
reads it fresh inside a function on every recompute instead of caching it.
