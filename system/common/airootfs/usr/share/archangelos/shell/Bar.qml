import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// One per screen. The window spans the whole screen so panels can grow out
// of the notch, but its input mask is only the top strip while at rest.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property int barHeight: 36
    readonly property bool focusedScreen: !Hyprland.focusedMonitor
        || Hyprland.focusedMonitor.name === modelData.name
    readonly property bool open: ShellState.panel !== "" && focusedScreen

    anchors { top: true; left: true; right: true }
    implicitHeight: modelData.height
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barHeight

    WlrLayershell.namespace: "archangelos-shell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: win.open ? backdrop : strip }

    // Veil behind an open panel; clicking it puts the panel away.
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "black"
        opacity: win.open ? 0.42 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } }
        MouseArea {
            anchors.fill: parent
            enabled: win.open
            onClicked: ShellState.close()
        }
    }

    Item {
        id: strip
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: win.barHeight

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.62) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
            }
        }

        Workspaces {
            anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
        }

        Status {
            anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
        }
    }

    Notch {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        panel: win.focusedScreen ? ShellState.panel : ""
    }
}
