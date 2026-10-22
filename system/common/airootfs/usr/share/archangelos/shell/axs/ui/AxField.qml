// Single-line text field.
import QtQuick
import qs.axs

Rectangle {
    id: f
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property string icon: ""
    signal accepted()
    function focusIn() { input.forceActiveFocus(); }
    implicitWidth: 240; implicitHeight: 34
    radius: Ax.radiusSm
    color: Ax.raised
    border.width: 1
    border.color: input.activeFocus ? Ax.accentLine : Ax.border
    Behavior on border.color { ColorAnimation { duration: Ax.dur } }

    Icon {
        id: ic
        visible: f.icon !== ""
        name: f.icon; size: 16
        anchors.left: parent.left; anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        color: Ax.faint
    }
    TextInput {
        id: input
        anchors.left: ic.visible ? ic.right : parent.left
        anchors.leftMargin: ic.visible ? 8 : 12
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        font.family: Ax.sans; font.pixelSize: Ax.fsBody
        color: Ax.text
        selectionColor: Ax.accentSoft
        selectedTextColor: Ax.text
        echoMode: f.password ? TextInput.Password : TextInput.Normal
        clip: true
        onAccepted: f.accepted()
        Label {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text === "" && !input.activeFocus
            text: f.placeholder
            color: Ax.faint
        }
    }
}
