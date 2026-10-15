import QtQuick
import QtQuick.Shapes
import Quickshell

// The notch: an ink blade hanging from the top edge. At rest it carries the
// clock; on demand it morphs into the launcher or the session panel. Panel
// content is laid out at its final size and revealed once the shape has
// mostly opened, so nothing reflows mid-animation.
Item {
    id: notch

    property string panel: ""
    readonly property bool expanded: panel !== ""

    readonly property size restSize: Qt.size(236, 34)
    readonly property var sizes: ({
        "launcher": Qt.size(880, 610),
        "session": Qt.size(660, 260)
    })
    readonly property size target: sizes[panel] || restSize

    width: target.width
    height: target.height
    Behavior on width { NumberAnimation { duration: Theme.morph; easing.type: Theme.curve } }
    Behavior on height { NumberAnimation { duration: Theme.morph; easing.type: Theme.curve } }

    // Size of the chamfered (blade-cut) lower corners.
    property real cut: expanded ? 22 : 11
    Behavior on cut { NumberAnimation { duration: Theme.morph; easing.type: Theme.curve } }

    clip: true

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: Qt.alpha(Theme.ink, notch.expanded ? 0.985 : 0.92)
            strokeColor: Theme.line
            strokeWidth: 1
            startX: 0; startY: -1
            PathLine { x: notch.width; y: -1 }
            PathLine { x: notch.width; y: notch.height - notch.cut }
            PathLine { x: notch.width - notch.cut; y: notch.height - 0.5 }
            PathLine { x: notch.cut; y: notch.height - 0.5 }
            PathLine { x: 0; y: notch.height - notch.cut }
            PathLine { x: 0; y: -1 }
        }
    }

    // Edge glint along the blade's lower edge.
    Rectangle {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        height: 1
        width: (notch.width - 2 * notch.cut) * (notch.expanded ? 0.5 : 0.32)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(Theme.accent, 0) }
            GradientStop { position: 0.5; color: Theme.accent }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.accent, 0) }
        }
    }

    // Resting face: the clock.
    Item {
        anchors.fill: parent
        opacity: notch.expanded ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Row {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.family: Theme.sans
                font.bold: true
                font.pixelSize: 14
                font.letterSpacing: 1.5
                color: Theme.fg
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 4; height: 4; radius: 2
                color: Theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
                font.family: Theme.sans
                font.pixelSize: 10
                font.letterSpacing: 2.5
                color: Theme.dim
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellState.open("launcher")
        }
    }

    component PanelSlot: Loader {
        id: slot
        required property string name
        readonly property size size: notch.sizes[name]
        // keep mounted while the notch folds closed, then release
        active: ShellState.lastPanel === name && (notch.panel === name || notch.height > notch.restSize.height + 8)
        width: size.width
        height: size.height
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        opacity: notch.panel === name ? 1 : 0
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: slot.opacity < 0.5 ? 120 : 0 }
                NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic }
            }
        }
    }

    PanelSlot { name: "launcher"; sourceComponent: Component { LauncherView {} } }
    PanelSlot { name: "session"; sourceComponent: Component { SessionView {} } }
}
