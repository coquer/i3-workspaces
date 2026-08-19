import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// i3bar-style workspace indicators: plain numbered boxes, sharp corners,
// filtered to the monitor this bar instance lives on.
BarWidget {
  id: root
  moduleName: "i3-workspaces"

  readonly property int maxWorkspaceId: root.setting("maxWorkspaceId", 10)

  readonly property color activeColor: Color.accent
  readonly property color inactiveColor: Color.muted
  readonly property color urgentColor: Color.urgent
  readonly property color bgColor: Color.background
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  // --- which monitor is this bar on -----------------------------------------
  // One bar surface exists per monitor, so read the screen off the window this
  // widget was instantiated into rather than off global focus state. QsWindow
  // carries no change notification, so a cached readonly property can freeze
  // at "" if evaluated before the widget is parented into its window -- read
  // it fresh on every call instead.
  function screenName() {
    var win = root.QsWindow ? root.QsWindow.window : null
    return win && win.screen ? String(win.screen.name || "") : ""
  }

  readonly property var hyprMonitor: {
    var _ = root.revision
    var mine = root.screenName()
    if (mine === "") return null
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      if (String(monitors[i].name) === mine) return monitors[i]
    }
    return null
  }

  // Workspace active *on this monitor* -- not the same as the globally
  // focused workspace once a second monitor exists. hyprMonitor's own
  // change-notify only fires when the monitor object reference itself
  // changes, not when its activeWorkspace sub-property is updated in place
  // -- depend on revision explicitly so a workspace switch on another
  // monitor's bar surface still forces a fresh read here.
  readonly property int activeId: {
    var _ = root.revision
    if (root.hyprMonitor && root.hyprMonitor.activeWorkspace) return root.hyprMonitor.activeWorkspace.id
    return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  }

  // --- keeping Hyprland's view fresh -----------------------------------------
  property int revision: 0

  readonly property var workspaceEvents: ["workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "moveworkspace", "moveworkspacev2", "focusedmon", "urgent"]

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (root.workspaceEvents.indexOf(event.name) !== -1) {
        Hyprland.refreshWorkspaces()
        root.revision++
      }
    }
  }

  // The window this widget lives in may not be attached yet on first paint;
  // force one re-check once the event loop settles so screenName() resolves
  // even if no Hyprland event fires early on.
  Timer {
    interval: 50
    running: true
    repeat: false
    onTriggered: root.revision++
  }

  function monitorNameOf(workspace) {
    if (!workspace) return ""
    if (workspace.monitor && workspace.monitor.name) return String(workspace.monitor.name)
    var ipc = workspace.lastIpcObject
    if (ipc && ipc.monitor) return String(ipc.monitor)
    return ""
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  // Workspace ids belonging to this monitor, always including the active id
  // so the bar never renders empty.
  readonly property var workspaceIds: {
    var _ = root.revision
    var mine = root.screenName()
    var ids = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var id = workspace.id
      if (id <= 0 || id > root.maxWorkspaceId) continue

      if (mine !== "") {
        var owner = root.monitorNameOf(workspace)
        // An unknown owner is kept rather than dropped: better a stray box
        // than a workspace that silently vanishes from every bar.
        if (owner !== "" && owner !== mine) continue
      }

      if (ids.indexOf(id) === -1) ids.push(id)
    }

    if (root.activeId > 0 && root.activeId <= root.maxWorkspaceId && ids.indexOf(root.activeId) === -1) ids.push(root.activeId)

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds.length
    columnSpacing: 0
    rowSpacing: 0

    Repeater {
      model: root.workspaceIds

      Item {
        id: box
        required property int modelData

        readonly property var workspace: root.workspaceById(box.modelData)
        readonly property bool active: box.modelData === root.activeId
        readonly property bool urgent: box.workspace !== null && box.workspace.urgent === true

        Layout.alignment: Qt.AlignVCenter
        Layout.fillHeight: true
        Layout.fillWidth: root.vertical
        implicitWidth: root.vertical ? root.barSize : Style.space(20)
        implicitHeight: root.barSize

        // Text-color-only contrast is too weak when a theme's accent and
        // muted tones sit close in hue/lightness -- a solid fill makes the
        // active workspace unmistakable regardless of theme.
        Rectangle {
          anchors.centerIn: parent
          anchors.margins: 2
          width: Math.max(label.implicitWidth + Style.space(4), height)
          height: root.barSize - Style.space(6)
          radius: 3
          visible: box.active || box.urgent
          color: box.urgent ? root.urgentColor : root.activeColor
        }

        Text {
          id: label
          anchors.centerIn: parent
          text: box.modelData === 10 ? "0" : String(box.modelData)
          color: (box.active || box.urgent) ? root.bgColor : root.inactiveColor
          font.bold: box.active || box.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.vertical ? Style.font.icon : Style.font.body
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusWorkspace(box.modelData)
        }
      }
    }
  }
}
