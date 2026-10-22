// Multi-line plain-text field (monospace), e.g. for bridge lines or config snippets.
import QtQuick
import qs.axs

Rectangle {
    id: f
    property alias text: edit.text
    property string placeholder: ""
    implicitWidth: 400; implicitHeight: 120
    radius: Ax.radiusSm
    color: Ax.raised
    border.width: 1
    border.color: edit.activeFocus ? Ax.accentLine : Ax.border
    Behavior on border.color { ColorAnimation { duration: Ax.dur } }
    Flickable {
        id: fl
        anchors.fill: parent; anchors.margins: 10
        contentWidth: width; contentHeight: edit.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        TextEdit {
            id: edit
            width: fl.width
            wrapMode: TextEdit.WrapAnywhere
            font.family: Ax.mono; font.pixelSize: Ax.fsSmall
            color: Ax.text
            selectionColor: Ax.accentSoft; selectedTextColor: Ax.text
            selectByMouse: true
            onCursorRectangleChanged: {
                if (cursorRectangle.y < fl.contentY) fl.contentY = cursorRectangle.y;
                else if (cursorRectangle.y + cursorRectangle.height > fl.contentY + fl.height)
                    fl.contentY = cursorRectangle.y + cursorRectangle.height - fl.height;
            }
            Label {
                visible: edit.text === "" && !edit.activeFocus
                width: parent.width; wrapMode: Text.WordWrap
                text: f.placeholder; color: Ax.faint; mono: true; font.pixelSize: Ax.fsSmall
            }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; acceptedButtons: Qt.NoButton }
}
