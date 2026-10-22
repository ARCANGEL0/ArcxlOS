// A settings row: optional icon tile, title + description on the left, the control on the right.
import QtQuick
import qs.axs

Item {
    id: row
    property string icon: ""
    property string image: ""                // app icon or picture in place of a glyph
    property string title: ""
    property string desc: ""
    property bool topDivider: false
    property bool clickable: false
    property bool chevron: false
    property bool dim: false
    signal clicked()
    default property alias trailing: trail.data
    width: parent ? parent.width : 600
    implicitHeight: Math.max(Ax.rowH, texts.implicitHeight + 26, trail.implicitHeight + 24)
    height: implicitHeight
    onVisibleChanged: if (parent && parent.parent && parent.parent.parent && parent.parent.parent._relink) parent.parent.parent._relink()

    Rectangle {
        anchors.fill: parent; anchors.margins: 4
        radius: Ax.radiusSm
        color: Ax.hover
        visible: row.clickable && ma.containsMouse
    }
    Rectangle {
        visible: row.topDivider
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: Ax.pad; anchors.rightMargin: Ax.pad
        height: 1; color: Ax.divider
    }
    Rectangle {
        id: tile
        visible: row.icon !== "" || row.image !== ""
        anchors.left: parent.left; anchors.leftMargin: Ax.pad
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32; radius: 9
        color: Ax.raised
        border.width: 1; border.color: Ax.border
        Icon { anchors.centerIn: parent; visible: row.image === ""; name: row.icon; size: 17; color: row.dim ? Ax.faint : Ax.text }
        Image { anchors.centerIn: parent; visible: row.image !== ""; source: row.image; width: 22; height: 22
                sourceSize.width: 44; sourceSize.height: 44; asynchronous: true; smooth: true }
    }
    Column {
        id: texts
        anchors.left: tile.visible ? tile.right : parent.left
        anchors.leftMargin: tile.visible ? 14 : Ax.pad
        anchors.right: trail.left; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Label { width: parent.width; text: row.title; font.weight: Font.Medium; color: row.dim ? Ax.subtext : Ax.text }
        Label {
            width: parent.width
            visible: row.desc !== ""
            text: row.desc
            font.pixelSize: Ax.fsSmall
            color: Ax.muted
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }
    }
    Row {
        id: trail
        anchors.right: chev.visible ? chev.left : parent.right
        anchors.rightMargin: chev.visible ? 8 : Ax.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
    }
    Icon {
        id: chev
        visible: row.chevron
        anchors.right: parent.right; anchors.rightMargin: Ax.pad - 4
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron_right"; size: 20; color: Ax.faint
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: row.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
        z: -1
    }
}
