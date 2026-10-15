import QtQuick

// Right side of the bar: quiet HUD readouts and the session (power) glyph.
Row {
    id: status
    spacing: 18

    component Meter: Column {
        id: meter
        required property string label
        required property int value
        spacing: 3
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Row {
            spacing: 6
            Text {
                text: meter.label
                font.family: Theme.sans
                font.pixelSize: 9
                font.letterSpacing: 2.5
                color: Theme.faint
            }
            Text {
                text: String(meter.value).padStart(2, "0")
                font.family: Theme.sans
                font.pixelSize: 11
                font.letterSpacing: 1
                color: Theme.dim
            }
        }

        Rectangle {
            width: 40
            height: 1
            color: Theme.line
            Rectangle {
                height: 1
                width: parent.width * Math.min(1, meter.value / 100)
                color: meter.value > 85 ? Theme.accent : Theme.dim
                Behavior on width { NumberAnimation { duration: Theme.medium; easing.type: Theme.curve } }
            }
        }
    }

    Meter { label: "CPU"; value: SysStats.cpu }
    Meter { label: "MEM"; value: SysStats.mem }

    Rectangle {
        width: 1
        height: 12
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.line
    }

    Text {
        id: power
        anchors.verticalCenter: parent.verticalCenter
        text: "⏻"
        font.family: Theme.glyphs
        font.pixelSize: 13
        color: hover.containsMouse || ShellState.panel === "session" ? Theme.accent : Theme.dim
        Behavior on color { ColorAnimation { duration: Theme.quick } }

        MouseArea {
            id: hover
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellState.toggle("session")
        }
    }
}
