// Segmented choice: a short list of mutually exclusive options in one pill.
import QtQuick
import qs.axs

Rectangle {
    id: seg
    property var options: []          // strings
    property int current: 0
    signal picked(int index)
    implicitHeight: 30
    implicitWidth: row.implicitWidth + 6
    radius: Ax.radiusSm
    color: Ax.raised
    border.width: 1; border.color: Ax.border

    Rectangle {
        id: pill
        y: 3; height: parent.height - 6; radius: Ax.radiusSm - 3
        color: Ax.accentSoft
        border.width: 1; border.color: Ax.accentLine
        readonly property Item tgt: rep.itemAt(seg.current)
        x: tgt ? tgt.x + 3 : 3
        width: tgt ? tgt.width : 0
        Behavior on x { NumberAnimation { duration: Ax.dur; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Ax.dur; easing.type: Easing.OutCubic } }
    }
    Row {
        id: row
        x: 3; height: parent.height
        Repeater {
            id: rep
            model: seg.options
            delegate: Item {
                required property var modelData
                required property int index
                width: lbl.implicitWidth + 26; height: row.height
                Label {
                    id: lbl
                    anchors.centerIn: parent
                    text: parent.modelData
                    font.pixelSize: Ax.fsSmall
                    font.weight: parent.index === seg.current ? Font.DemiBold : Font.Normal
                    color: parent.index === seg.current ? Ax.text : Ax.subtext
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(parent.index) }
            }
        }
    }
}
