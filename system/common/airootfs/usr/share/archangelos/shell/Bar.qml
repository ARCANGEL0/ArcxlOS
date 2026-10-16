import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// One per screen: the left sidebar plus the panels that pour out of it.
// The window spans the screen so panels have room, but at rest its input
// mask is only the sidebar.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property int sideWidth: 52
    readonly property bool focusedScreen: !Hyprland.focusedMonitor
        || Hyprland.focusedMonitor.name === modelData.name
    readonly property string panel: focusedScreen ? ShellState.panel : ""
    readonly property bool open: panel !== ""

    anchors { top: true; bottom: true; left: true }
    implicitWidth: modelData.width
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: sideWidth

    WlrLayershell.namespace: "archangelos-shell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: win.open ? backdrop : sidebar }

    // Dims the desktop behind an open panel; clicking it puts the panel away.
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "black"
        opacity: win.open ? 0.38 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
        MouseArea {
            anchors.fill: parent
            enabled: win.open
            onClicked: ShellState.close()
        }
    }

    FlowPanel {
        x: win.sideWidth
        shown: win.panel === "launcher"
        size: Qt.size(launcher.width, Math.min(launcher.height, win.height - 48))
        originY: sidebar.launcherOriginY
        targetY: (win.height - size.height) / 2
        LauncherView { id: launcher; active: win.panel === "launcher" }
    }

    FlowPanel {
        x: win.sideWidth
        shown: win.panel === "session"
        size: Qt.size(session.width, session.height)
        originY: sidebar.sessionOriginY
        targetY: Math.max(16, sidebar.sessionOriginY + 20 - session.height)
        SessionView { id: session; active: win.panel === "session" }
    }

    // Above the panels, so their flared necks tuck in under it.
    Sidebar {
        id: sidebar
        width: win.sideWidth
        height: parent.height
    }
}
