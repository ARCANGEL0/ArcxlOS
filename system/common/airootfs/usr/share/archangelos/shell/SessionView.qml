import QtQuick
import Quickshell

// Session panel: four actions, each under its kanji.
//   Left/Right select   Enter confirm   Esc close
Item {
    id: view

    property int sel: 0

    readonly property var actions: [
        { glyph: "鎖", label: "LOCK", hint: "SUPER + L",
          cmd: ["sh", "-c", "command -v archangelos-lock >/dev/null 2>&1 && exec archangelos-lock || exec hyprlock"] },
        { glyph: "退", label: "LOG OUT", hint: "END SESSION", cmd: ["hyprctl", "dispatch", "exit"] },
        { glyph: "再", label: "RESTART", hint: "REBOOT", cmd: ["systemctl", "reboot"] },
        { glyph: "終", label: "SHUT DOWN", hint: "POWER OFF", cmd: ["systemctl", "poweroff"] }
    ]

    function run(i) {
        ShellState.close()
        Quickshell.execDetached(actions[i].cmd)
    }

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: event => {
        const k = event.key
        if (k === Qt.Key_Escape) ShellState.close()
        else if (k === Qt.Key_Left) sel = (sel + actions.length - 1) % actions.length
        else if (k === Qt.Key_Right || k === Qt.Key_Tab) sel = (sel + 1) % actions.length
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) run(sel)
        else return
        event.accepted = true
    }

    Row {
        id: heading
        anchors { top: parent.top; left: parent.left; topMargin: 26; leftMargin: 36 }
        spacing: 14
        Text {
            anchors.baseline: label.baseline
            text: "終幕"
            font.family: Theme.serif
            font.pixelSize: 22
            color: Theme.accent
        }
        Text {
            id: label
            text: "SESSION"
            font.family: Theme.sans
            font.pixelSize: 11
            font.letterSpacing: 5
            color: Theme.dim
        }
    }

    Row {
        id: choices
        anchors { horizontalCenter: parent.horizontalCenter; top: heading.bottom; topMargin: 30 }
        spacing: 0

        Repeater {
            model: view.actions

            Item {
                id: choice
                required property var modelData
                required property int index
                readonly property bool current: view.sel === index
                width: 148
                height: 150

                Text {
                    id: kanji
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                    text: choice.modelData.glyph
                    font.family: Theme.serif
                    font.pixelSize: 52
                    color: choice.current ? Theme.accent : Theme.faint
                    scale: choice.current ? 1.06 : 1
                    Behavior on color { ColorAnimation { duration: Theme.medium } }
                    Behavior on scale { NumberAnimation { duration: Theme.medium; easing.type: Theme.curve } }
                }
                Text {
                    id: name
                    anchors { horizontalCenter: parent.horizontalCenter; top: kanji.bottom; topMargin: 10 }
                    text: choice.modelData.label
                    font.family: Theme.sans
                    font.pixelSize: 11
                    font.letterSpacing: 3.5
                    color: choice.current ? Theme.fg : Theme.dim
                    Behavior on color { ColorAnimation { duration: Theme.medium } }
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; top: name.bottom; topMargin: 6 }
                    text: choice.modelData.hint
                    font.family: Theme.sans
                    font.pixelSize: 8
                    font.letterSpacing: 2.5
                    color: Theme.faint
                    opacity: choice.current ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.medium } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: view.sel = choice.index
                    onClicked: view.run(choice.index)
                }
            }
        }
    }

    // The selection blade glides between choices.
    Rectangle {
        y: choices.y + choices.height - 4
        x: choices.x + view.sel * 148 + (148 - width) / 2
        width: 28
        height: 2
        color: Theme.accent
        Behavior on x { NumberAnimation { duration: Theme.morph; easing.type: Theme.curve } }
    }
}
