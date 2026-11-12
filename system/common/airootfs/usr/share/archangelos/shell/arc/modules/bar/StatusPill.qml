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

    implicitWidth: 40
    implicitHeight: col.implicitHeight + 6

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 3
        spacing: 1

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22
            height: 22

            Rectangle {
                anchors.centerIn: parent
                width: 32
                height: 32
                radius: 10
                color: ma.containsMouse ? Config.containerSoft : "transparent"
                Behavior on color { ColorAnim { } }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 34
                height: 34
                radius: 12
                color: "transparent"
                border.width: 2
                border.color: pill.tint
                opacity: pill.pulse ? pulseAnim.opacity : 0
                SequentialAnimation on opacity {
                    id: pulseAnim
                    running: pill.pulse && pill.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.55; to: 0; duration: 1200 }
                }
            }

            MatIcon {
                id: icon
                anchors.centerIn: parent
                visible: pill.icon !== ""
                text: pill.icon
                font.pixelSize: 18
                color: pill.tint
            }

            Text {
                anchors.centerIn: parent
                visible: pill.icon === "" && pill.glyph !== ""
                text: pill.glyph
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 17
                color: pill.tint
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pill.count !== ""
            text: pill.count
            color: pill.tint
            font.family: Config.textFont
            font.pixelSize: 9
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
        onExited: if (pill.popout !== "") pill.bar.hidePopout()
        onClicked: pill.clicked()
    }
}
