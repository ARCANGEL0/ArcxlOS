import QtQuick
import Quickshell.Hyprland

// Vertical workspace column for the sidebar. The active marker is a liquid
// drop that stretches toward the next workspace before settling.
Item {
    id: ws

    readonly property int cell: 34
    readonly property var ids: Hyprland.workspaces.values.map(w => w.id).filter(i => i > 0)
    readonly property int count: Math.max(5, ...ids)
    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    implicitWidth: 52
    implicitHeight: count * cell

    Liquid {
        x: 8
        width: parent.width - 16
        targetY: (ws.activeId - 1) * ws.cell + 3
        targetHeight: ws.cell - 6
        Rectangle { anchors.fill: parent; radius: 9; color: Qt.alpha(Theme.accent, 0.16) }
    }

    Liquid {
        x: 0
        width: 3
        targetY: (ws.activeId - 1) * ws.cell + 9
        targetHeight: ws.cell - 18
        Rectangle { anchors.fill: parent; radius: 1.5; color: Theme.accent }
    }

    Repeater {
        model: ws.count

        Item {
            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: wsId === ws.activeId
            readonly property bool occupied: ws.ids.indexOf(wsId) !== -1

            y: index * ws.cell
            width: ws.width
            height: ws.cell

            Text {
                anchors.centerIn: parent
                text: String(parent.wsId).padStart(2, "0")
                font.family: Theme.sans
                font.pixelSize: 12
                font.bold: parent.active
                font.letterSpacing: 1
                color: parent.active ? Theme.fg : parent.occupied ? Theme.dim : Theme.faint
                Behavior on color { ColorAnimation { duration: Theme.medium } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + parent.wsId)
            }
        }
    }
}
