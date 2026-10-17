// ArchangelOS: power button in the top-right cluster — a bare red icon, no fill.
// Opens the session menu (shutdown / reboot / log out / lock / suspend).
import QtQuick
import "../../"
import "../../services/"

Item {
    id: root
    property real localScale: 1.0
    implicitWidth:  Math.round(24 * localScale)
    implicitHeight: Math.round(24 * localScale)

    Text {
        anchors.centerIn: parent
        text: "⏻"
        color: hover.hovered ? Qt.lighter(Theme.active, 1.25) : Theme.active
        Behavior on color { ColorAnimation { duration: Anim.color } }
        font.pixelSize: Math.round(15 * root.localScale)
        scale: tap.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    MouseArea {
        id: tap
        anchors.fill: parent
        onClicked: {
            var next = !Popups.powerOpen
            Popups.closeAll()
            SurfaceState.toggle("right", "power")
            if (next) Popups.powerPinned = true
        }
    }
}
