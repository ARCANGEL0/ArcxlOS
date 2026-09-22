import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    height: 52
    property alias text: input.text
    property alias echoMode: input.echoMode
    property string label: ""
    property color textColor: "#ECEBE8"
    property color dim: "#9A9895"
    property color faint: "#5E5D5A"
    property color line: "#E9E7E3"
    property color accent: "#C24A52"
    property string fontFamily: "Quantico"
    signal accepted()

    function forceActive() { input.forceActiveFocus() }

    Text {
        id: cap
        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        color: input.activeFocus ? root.textColor : root.dim
        font.family: root.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 3
        opacity: 0.85
        Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.InOutQuad } }
    }

    TextField {
        id: input
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 26
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: 17
        font.letterSpacing: echoMode === TextInput.Password ? 4 : 0.5
        selectionColor: "#4A4A47"
        selectedTextColor: root.textColor
        background: Item {}
        onAccepted: root.accepted()

        cursorDelegate: Rectangle {
            width: 1
            color: root.accent
            visible: input.cursorVisible
            SequentialAnimation on opacity {
                running: input.activeFocus
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.15; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.15; to: 1; duration: 700; easing.type: Easing.InOutQuad }
            }
        }
    }

    Rectangle {
        id: baseLine
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.faint
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: 1
        color: root.line
        width: input.activeFocus ? parent.width : 0
        opacity: input.activeFocus ? 1 : 0
        Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 360 } }
    }
}
