// Sidebar entry. The active one gets a soft crimson plate and the blade marker on its left edge.
import QtQuick
import qs.axs

Item {
    id: nav
    property string icon: ""
    property string label: ""
    property bool active: false
    property string badge: ""
    signal clicked()
    width: parent ? parent.width : 220
    height: 36

    Rectangle {
        anchors.fill: parent
        radius: Ax.radiusSm
        color: nav.active ? Ax.alpha(Ax.accent, 0.11) : (ma.containsMouse ? Ax.hover : "transparent")
        Behavior on color { ColorAnimation { duration: Ax.dur } }
    }
    Rectangle {
        width: 3; height: nav.active ? 16 : 0; radius: 1.5
        anchors.left: parent.left; anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        color: Ax.accent
        Behavior on height { NumberAnimation { duration: Ax.dur; easing.type: Easing.OutCubic } }
    }
    Icon {
        id: ic
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        name: nav.icon; size: 18; filled: nav.active
        color: nav.active ? Ax.accent : (ma.containsMouse ? Ax.text : Ax.subtext)
    }
    Label {
        anchors.left: ic.right; anchors.leftMargin: 12
        anchors.right: badgeLbl.visible ? badgeLbl.left : parent.right; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: nav.label
        font.weight: nav.active ? Font.DemiBold : Font.Normal
        color: nav.active ? Ax.text : (ma.containsMouse ? Ax.text : Ax.subtext)
    }
    Label {
        id: badgeLbl
        visible: nav.badge !== ""
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        caption: true; text: nav.badge; color: Ax.faint
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nav.clicked() }
}
