import QtQuick 2.15

Item {
    id: root
    width: 30
    height: 30
    property string glyph: "⏻"
    property color dim: "#9A9895"
    property color textColor: "#ECEBE8"
    property string fontFamily: "Quantico"
    property bool enabled: true
    signal triggered()

    opacity: enabled ? (ma.containsMouse ? 1.0 : 0.5) : 0.2
    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InOutQuad } }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: ma.containsMouse ? root.textColor : root.dim
        font.pixelSize: 17
        font.family: root.fontFamily
        Behavior on color { ColorAnimation { duration: 320 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
