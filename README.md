# i3 Workspaces

An [Omarchy](https://omarchy.org) bar widget: i3bar-style workspace numbers,
one per monitor.

Each bar shows only the workspaces that live on its own monitor, labelled
with their real Hyprland workspace IDs, and marks the one active on that
monitor with a solid accent-filled pill. Combined with the bindings in
[i3-style global numbering](#i3-style-global-numbering-on-omarchy), no two
monitors ever show the same number and Super+N always matches the label.

Stock `omarchy.workspaces` instead numbers every monitor 1-10 on its own, so
two monitors can both show `1`.

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

Restart the shell to pick up the change:

```bash
omarchy restart shell
```

The shell logs "Local plugin changed, reloading" when a plugin file is saved,
but a running bar can keep the old code until a restart, so restart after
editing `Workspaces.qml` too.

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
| `maxWorkspaceId` | `0` (no limit) | Highest workspace ID shown. `0` or less shows every workspace with a positive ID. Labels are the real Hyprland workspace IDs. |

## i3-style global numbering on Omarchy

Recent Omarchy versions give every monitor its own block of ten workspace
IDs (1-10, 11-20, 21-30, ...), and Super+N goes to slot N on the focused
monitor. This widget shows real IDs, so with those blocks a second monitor
shows `11`, `21` and so on, which don't match the keys. With an upper limit of
`10` (the old default) the widget filtered every workspace out and rendered
nothing.

For i3 behaviour, where Super+N always means workspace N on whichever monitor
holds it, add this to `~/.config/hypr/bindings.lua`:

```lua
-- Stop Omarchy renumbering workspaces into per-monitor blocks on reload and
-- hotplug. This overrides an Omarchy internal; recheck after `omarchy update`.
o.workspaces.reconcile = function() end

for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  local ws = tostring(workspace)
  o.rebind("SUPER + " .. key, "Switch to workspace " .. ws, hl.dsp.focus({ workspace = ws }))
  o.rebind("SUPER + SHIFT + " .. key, "Move window to workspace " .. ws, hl.dsp.window.move({ workspace = ws }))
  o.rebind("SUPER + SHIFT + ALT + " .. key, "Move window silently to workspace " .. ws, hl.dsp.window.move({ workspace = ws, follow = false }))
end

-- Move a workspace to another monitor without renumbering it.
for _, dir in ipairs({ "l", "r", "u", "d" }) do
  local name = ({ l = "LEFT", r = "RIGHT", u = "UP", d = "DOWN" })[dir]
  o.rebind("SUPER + SHIFT + ALT + " .. name, "Move workspace to monitor " .. dir, hl.dsp.workspace.move({ monitor = dir }))
end
```

Then run `hyprctl reload` and check `hyprctl configerrors`. Workspaces that
are already open keep their block IDs until you renumber them, for example:

```bash
hyprctl dispatch 'hl.dsp.workspace.change_id({ workspace = "21", id = 1 })'
```

If you use a monitor plugin that pins workspaces to screens (such as Screens'
"Assign by monitor"), turn that off or it may renumber workspaces again.

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

## License

[MIT](LICENSE)
