// A titled card of rows. Rows are stacked with hairline dividers between them.
import QtQuick
import qs.axs

Column {
    id: sec
    property string title: ""
    property string note: ""                 // right-aligned caption next to the title
    default property alias rows: body.data
    width: parent ? parent.width : 600
    spacing: 10

    Item {
        visible: sec.title !== ""
        width: parent.width; height: 14
        Label { caption: true; text: sec.title; anchors.left: parent.left; anchors.leftMargin: 4 }
        Label { caption: true; text: sec.note; anchors.right: parent.right; anchors.rightMargin: 4 }
    }
    Rectangle {
        width: parent.width
        height: body.implicitHeight
        radius: Ax.radius
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        clip: true
        Column {
            id: body
            width: parent.width
            // hairlines between visible rows
            onChildrenChanged: Qt.callLater(sec._relink)
        }
    }
    function _relink() {
        let first = true;
        for (let i = 0; i < body.children.length; i++) {
            const c = body.children[i];
            if (c.hasOwnProperty("topDivider")) { c.topDivider = !first && c.visible; if (c.visible) first = false; }
        }
    }
}
