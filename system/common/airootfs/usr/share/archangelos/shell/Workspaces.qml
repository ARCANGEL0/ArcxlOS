import QtQuick
import Quickshell.Hyprland

// Logo + workspaces as kanji numerals. A single blade underline glides to
// the active workspace instead of each numeral lighting up on its own.
Item {
    id: ws

    readonly property int cell: 26
    readonly property int gap: 2
    readonly property var ids: Hyprland.workspaces.values.map(w => w.id).filter(i => i > 0)
    readonly property int count: Math.max(5, ...ids)
    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    implicitWidth: row.width
    implicitHeight: 28

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Image {
            source: "file:///usr/share/archangelos/logo.png"
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        Item { width: 12; height: 1 }

        Rectangle {
            width: 1
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.line
        }

        Item { width: 8; height: 1 }

        Repeater {
            id: numerals
            model: ws.count

            Item {
                required property int index
                readonly property int wsId: index + 1
                readonly property bool active: wsId === ws.activeId
                readonly property bool occupied: ws.ids.indexOf(wsId) !== -1

                width: ws.cell + ws.gap
                height: ws.cell

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: Theme.kanji(parent.wsId)
                    font.family: Theme.serif
                    font.pixelSize: 15
                    color: parent.active ? Theme.fg : parent.occupied ? Theme.dim : Theme.faint
                    opacity: parent.active || parent.occupied ? 1 : 0.7
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

    Rectangle {
        id: blade
        readonly property int firstX: 18 + 12 + 1 + 8
        width: 12
        height: 2
        radius: 1
        color: Theme.accent
        y: parent.height / 2 + 10
        x: firstX + (ws.activeId - 1) * (ws.cell + ws.gap) + (ws.cell - width) / 2
        Behavior on x { NumberAnimation { duration: Theme.morph; easing.type: Theme.curve } }
    }
}
