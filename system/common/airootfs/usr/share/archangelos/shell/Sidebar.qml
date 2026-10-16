import QtQuick
import Quickshell

// Left sidebar: launcher button (logo), workspaces, then readouts, clock
// and the session button at the foot. Panels pour out of its right edge.
Item {
    id: side

    // Where panels emerge from, in sidebar coordinates.
    readonly property real launcherOriginY: logo.y + logo.height / 2
    readonly property real sessionOriginY: power.y + power.height / 2

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.ink, 0.97)
    }

    // ── top ──────────────────────────────────────────────────────────────
    Item {
        id: logo
        x: 0; y: 14
        width: parent.width
        height: 44

        Rectangle {
            anchors.centerIn: parent
            width: 38; height: 38; radius: 10
            color: Qt.alpha(Theme.accent, ShellState.panel === "launcher" ? 0.18 : logoHover.containsMouse ? 0.10 : 0)
            Behavior on color { ColorAnimation { duration: Theme.medium } }
        }
        Image {
            anchors.centerIn: parent
            source: "file:///usr/share/archangelos/logo.png"
            width: 26; height: 26
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }
        MouseArea {
            id: logoHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellState.toggle("launcher")
        }
    }

    Rectangle {
        id: rule
        anchors { top: logo.bottom; topMargin: 12; horizontalCenter: parent.horizontalCenter }
        width: 18; height: 1
        color: Theme.line
    }

    Workspaces {
        anchors { top: rule.bottom; topMargin: 12; left: parent.left; right: parent.right }
    }

    // ── foot ─────────────────────────────────────────────────────────────
    component Meter: Column {
        id: meter
        required property string label
        required property int value
        spacing: 3
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: String(meter.value).padStart(2, "0")
            font.family: Theme.sans
            font.pixelSize: 11
            color: meter.value > 85 ? Theme.accent : Theme.dim
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22; height: 2; radius: 1
            color: Theme.line
            Rectangle {
                height: parent.height; radius: 1
                width: parent.width * Math.min(1, meter.value / 100)
                color: meter.value > 85 ? Theme.accent : Theme.dim
                Behavior on width { NumberAnimation { duration: Theme.slow; easing.type: Theme.curve } }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: meter.label
            font.family: Theme.sans
            font.pixelSize: 7
            font.letterSpacing: 1.5
            color: Theme.faint
        }
    }

    Column {
        id: foot
        anchors { bottom: power.top; bottomMargin: 18; horizontalCenter: parent.horizontalCenter }
        spacing: 14

        Meter { label: "CPU"; value: SysStats.cpu }
        Meter { label: "MEM"; value: SysStats.mem }

        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 18; height: 1; color: Theme.line }

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH")
                font.family: Theme.sans; font.bold: true; font.pixelSize: 16
                color: Theme.fg
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                font.family: Theme.sans; font.bold: true; font.pixelSize: 16
                color: Theme.dim
            }
            Item { width: 1; height: 6 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dd MMM").toUpperCase()
                font.family: Theme.sans; font.pixelSize: 8; font.letterSpacing: 1
                color: Theme.faint
            }
        }
    }

    Item {
        id: power
        anchors { bottom: parent.bottom; bottomMargin: 14 }
        width: parent.width
        height: 40

        Rectangle {
            anchors.centerIn: parent
            width: 34; height: 34; radius: 10
            color: Qt.alpha(Theme.accent, ShellState.panel === "session" ? 0.18 : powerHover.containsMouse ? 0.10 : 0)
            Behavior on color { ColorAnimation { duration: Theme.medium } }
        }
        Text {
            anchors.centerIn: parent
            text: ""
            font.family: Theme.glyphs
            font.pixelSize: 15
            color: powerHover.containsMouse || ShellState.panel === "session" ? Theme.accent : Theme.dim
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
        MouseArea {
            id: powerHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellState.toggle("session")
        }
    }
}
