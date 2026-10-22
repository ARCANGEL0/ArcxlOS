// Button: "primary" (accent fill), "ghost" (quiet raised) or "danger".
import QtQuick
import qs.axs

Rectangle {
    id: btn
    property string text: ""
    property string icon: ""
    property string kind: "ghost"
    property bool enabled_: true
    signal clicked()
    implicitHeight: 32
    implicitWidth: content.implicitWidth + 28
    radius: Ax.radiusSm
    opacity: enabled_ ? 1 : 0.45
    readonly property bool hot: ma.containsMouse && enabled_
    color: kind === "primary" ? (hot ? Qt.lighter(Ax.accent, 1.1) : Ax.accent)
         : kind === "danger" ? (hot ? Ax.alpha(Ax.danger, 0.22) : Ax.alpha(Ax.danger, 0.12))
         : (hot ? Ax.mix(Ax.raised, Ax.text, 0.05) : Ax.raised)
    border.width: kind === "primary" ? 0 : 1
    border.color: kind === "danger" ? Ax.alpha(Ax.danger, 0.4) : Ax.border
    Behavior on color { ColorAnimation { duration: Ax.dur } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7
        Icon {
            visible: btn.icon !== ""
            name: btn.icon; size: 16
            anchors.verticalCenter: parent.verticalCenter
            color: btn.kind === "primary" ? "#fbf8f3" : btn.kind === "danger" ? Ax.danger : Ax.text
        }
        Label {
            visible: btn.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            font.pixelSize: Ax.fsSmall
            font.weight: Font.Medium
            color: btn.kind === "primary" ? "#fbf8f3" : btn.kind === "danger" ? Ax.danger : Ax.text
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled_
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
