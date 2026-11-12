// A small status pill in the bar: icon (+ optional count) that opens its named popout on hover
// and reports its info card to the shared dockdev popout.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.arc
import qs.arc.components

Item {
    id: pill

    required property var bar
    property string popout: ""
    property string icon: ""
    property string glyph: ""
    property color tint: Config.fg
    property bool pulse: false
    property string count: ""
    property var info: ({ title: "", color: Config.accent, lines: [], hint: "", actions: [] })
    signal clicked()

    implicitWidth: row.implicitWidth + 18
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: ma.hovered ? Config.panelHover : Config.panel
        border.width: 1; border.color: Config.border
        Behavior on color { ColorAnim { } }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 6; height: parent.height + 6
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2; border.color: pill.tint
            opacity: pill.pulse ? pulseAnim.opacity : 0
            SequentialAnimation on opacity {
                id: pulseAnim
                running: pill.pulse && pill.visible
                loops: Animation.Infinite
                NumberAnimation { from: 0.55; to: 0; duration: 1200 }
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        MatIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.icon !== "" ? pill.icon : pill.glyph
            font.pixelSize: 14
            color: pill.tint
        }
        Text {
            visible: pill.count !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pill.count
            color: pill.tint
            font.family: Config.textFont
            font.pixelSize: 11
            font.bold: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            pill.bar.hoverAnchor = pill
            pill.bar.hoverInfo = pill.info
            if (pill.popout !== "") pill.bar.showPopout(pill.popout)
        }
        onClicked: {
            pill.clicked()
            if (pill.popout !== "") pill.bar.showPopout(pill.popout)
        }
    }
}
