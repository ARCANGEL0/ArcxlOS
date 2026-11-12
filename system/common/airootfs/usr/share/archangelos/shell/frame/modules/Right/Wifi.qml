// ArchangelOS: wifi toggle in the top-right cluster.
// Icon shows signal when on, off-glyph when off; click toggles via Net.toggleWifi().
import QtQuick
import "../../"
import "../../services/"
import "../../../arc/services"

Item {
    id: root
    property real localScale: 1.0
    implicitWidth:  Math.round(24 * localScale)
    implicitHeight: Math.round(24 * localScale)

    Text {
        anchors.centerIn: parent
        text: Net.wifiUp ? "wifi" : "wifi_off"
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
        onClicked: Net.toggleWifi()
    }
}

