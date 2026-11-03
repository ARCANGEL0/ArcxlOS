import QtQuick
import Quickshell
import "../"

Item {
    id: tip

    property string text: ""
    property real localScale: 1.0
    property int delay: 450
    property bool above: false
    property bool armed: false
    property bool suppressed: false

    anchors.fill: parent

    HoverHandler {
        id: hover
        parent: tip.parent
        onHoveredChanged: {
            if (hovered) showTimer.restart()
            else { showTimer.stop(); tip.armed = false }
        }
    }

    Timer {
        id: showTimer
        interval: tip.delay
        onTriggered: tip.armed = tip.text !== "" && tip.visible && !tip.suppressed
    }

    Loader {
        active: tip.armed && !tip.suppressed

        sourceComponent: PopupWindow {
            anchor.item: tip
            anchor.rect.x: 0
            anchor.rect.y: tip.above ? -Math.round(6 * tip.localScale) : tip.height + Math.round(6 * tip.localScale)
            anchor.rect.width: tip.width
            anchor.rect.height: 1
            anchor.edges: tip.above ? Edges.Top : Edges.Bottom
            anchor.gravity: tip.above ? Edges.Top : Edges.Bottom
            implicitWidth: bubble.width
            implicitHeight: bubble.height
            color: "transparent"
            mask: Region {}
            visible: true

            Rectangle {
                id: bubble
                width: label.implicitWidth + Math.round(18 * tip.localScale)
                height: label.implicitHeight + Math.round(10 * tip.localScale)
                radius: Math.round(7 * tip.localScale)
                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.96)
                border.width: 1
                border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                opacity: 0
                scale: 0.92
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: tip.text
                    color: Theme.text
                    font.pixelSize: Math.round(11 * tip.localScale)
                    font.bold: true
                }
            }
        }
    }
}
