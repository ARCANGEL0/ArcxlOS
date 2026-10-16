import QtQuick
import Quickshell

// Session panel, pours out next to the power button.
//   Up/Down select   Enter confirm   Esc close
Item {
    id: view

    width: 300
    height: 296

    property bool active: false
    property int sel: 0

    readonly property var actions: [
        { glyph: "", label: "Lock", hint: "SUPER + L",
          cmd: ["sh", "-c", "command -v archangelos-lock >/dev/null 2>&1 && exec archangelos-lock || exec hyprlock"] },
        { glyph: "", label: "Log out", hint: "END SESSION", cmd: ["hyprctl", "dispatch", "exit"] },
        { glyph: "", label: "Restart", hint: "REBOOT", cmd: ["systemctl", "reboot"] },
        { glyph: "", label: "Shut down", hint: "POWER OFF", cmd: ["systemctl", "poweroff"] }
    ]

    function run(i) {
        ShellState.close()
        Quickshell.execDetached(actions[i].cmd)
    }

    onActiveChanged: if (active) { sel = 0; keys.forceActiveFocus() }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Escape) ShellState.close()
            else if (k === Qt.Key_Up) view.sel = (view.sel + view.actions.length - 1) % view.actions.length
            else if (k === Qt.Key_Down || k === Qt.Key_Tab) view.sel = (view.sel + 1) % view.actions.length
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) view.run(view.sel)
            else return
            event.accepted = true
        }
    }

    Text {
        id: heading
        x: 24; y: 22
        text: "Session"
        font.family: Theme.serif
        font.pixelSize: 22
        font.bold: true
        color: Theme.fg
    }

    Item {
        id: list
        anchors { top: heading.bottom; topMargin: 16; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 }
        height: view.actions.length * 52

        Liquid {
            width: parent.width
            targetY: view.sel * 52
            targetHeight: 46
            Rectangle { anchors.fill: parent; radius: 8; color: Theme.surfaceHot; border.width: 1; border.color: Qt.alpha(Theme.accent, 0.6) }
        }

        Repeater {
            model: view.actions

            Item {
                id: entry
                required property var modelData
                required property int index
                readonly property bool current: view.sel === index
                y: index * 52
                width: list.width
                height: 46

                Text {
                    id: glyph
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    width: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: entry.modelData.glyph
                    font.family: Theme.glyphs
                    font.pixelSize: 15
                    color: entry.current ? Theme.accent : Theme.dim
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }
                Text {
                    anchors { left: glyph.right; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: entry.modelData.label
                    font.family: Theme.sans
                    font.pixelSize: 14
                    color: entry.current ? Theme.fg : Theme.dim
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: entry.modelData.hint
                    font.family: Theme.sans
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: Theme.faint
                    opacity: entry.current ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.medium } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: view.sel = entry.index
                    onClicked: view.run(entry.index)
                }
            }
        }
    }
}
