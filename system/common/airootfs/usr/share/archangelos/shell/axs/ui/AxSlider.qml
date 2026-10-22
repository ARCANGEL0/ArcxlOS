// Horizontal slider. `value` is the bound state; dragging emits `moved` live, `released` at the end.
import QtQuick
import qs.axs

Item {
    id: sl
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property string suffix: ""
    property int decimals: 0
    property bool showValue: true
    property real valueScale: 1            // display multiplier (0..1 shown as 0..100 %)
    signal moved(real v)
    signal released(real v)
    implicitWidth: 240; implicitHeight: 24

    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    property real _drag: -1
    readonly property real shown: _drag >= 0 ? _drag : frac

    function _valueAt(x) {
        const f = Math.max(0, Math.min(1, x / track.width));
        let v = from + f * (to - from);
        if (stepSize > 0) v = Math.round(v / stepSize) * stepSize;
        return v;
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: valueLbl.visible ? valueLbl.left : parent.right
        anchors.rightMargin: valueLbl.visible ? 12 : 0
        height: 4; radius: 2
        color: Ax.raised
        Rectangle {
            width: Math.max(0, track.width * sl.shown); height: parent.height; radius: 2
            color: Ax.accent
        }
        Rectangle {
            x: track.width * sl.shown - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: area.pressed ? 16 : 14; height: width; radius: width / 2
            color: "#fbf8f3"
            border.width: 3; border.color: Ax.accent
            Behavior on width { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: area
            anchors.fill: parent; anchors.margins: -10
            cursorShape: Qt.PointingHandCursor
            function at(mx) { return Math.max(0, Math.min(1, (mx - 10) / track.width)); }
            onPressed: (m) => { sl._drag = at(m.x); sl.moved(sl._valueAt(m.x - 10)); }
            onPositionChanged: (m) => { if (pressed) { sl._drag = at(m.x); sl.moved(sl._valueAt(m.x - 10)); } }
            onReleased: (m) => { sl.released(sl._valueAt(m.x - 10)); sl._drag = -1; }
        }
    }
    Label {
        id: valueLbl
        visible: sl.showValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        horizontalAlignment: Text.AlignRight
        mono: true
        font.pixelSize: Ax.fsSmall
        color: Ax.subtext
        text: ((sl.from + sl.shown * (sl.to - sl.from)) * sl.valueScale).toFixed(sl.decimals) + sl.suffix
    }
}
