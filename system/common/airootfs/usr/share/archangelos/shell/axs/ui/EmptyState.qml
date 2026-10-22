// Calm empty / unavailable state inside a section.
import QtQuick
import qs.axs

Item {
    property string icon: "info"
    property string title: ""
    property string desc: ""
    property bool topDivider: false
    width: parent ? parent.width : 600
    implicitHeight: col.implicitHeight + 44
    height: implicitHeight
    Column {
        id: col
        anchors.centerIn: parent
        width: parent.width - 80
        spacing: 8
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: parent.parent.icon; size: 26; color: Ax.faint }
        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: parent.parent.title; font.weight: Font.Medium; color: Ax.subtext }
        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; visible: text !== ""; text: parent.parent.desc
                font.pixelSize: Ax.fsSmall; color: Ax.muted; wrapMode: Text.WordWrap }
    }
}
