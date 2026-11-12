// Compact info popout for the bar's status pills: title, a few lines, a hint, and action buttons.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.arc
import qs.arc.components

BarPopout {
    id: pop
    implicitWidth: 264
    bodyHeight: col.implicitHeight + 24

    property string title: ""
    property color titleColor: Config.accent
    property var lines: []
    property string hint: ""
    property var actions: []

    ColumnLayout {
        id: col
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 14 + Config.popFillet * 2 - pop.botPad + pop.topPad; leftMargin: 16; rightMargin: 16 }
        spacing: 6

        Text {
            text: pop.title; color: pop.titleColor
            font.family: Config.textFont; font.pixelSize: 15; font.bold: true
            Layout.fillWidth: true; elide: Text.ElideRight
        }
        Repeater {
            model: pop.lines
            Text {
                required property var modelData
                text: modelData; color: Config.dim
                font.family: Config.textFont; font.pixelSize: 12
                Layout.fillWidth: true; wrapMode: Text.Wrap
            }
        }
        Text {
            visible: pop.hint !== ""
            text: pop.hint; color: Config.faint
            font.family: Config.textFont; font.pixelSize: 11
            Layout.fillWidth: true; wrapMode: Text.Wrap
        }
        RowLayout {
            visible: pop.actions.length > 0
            spacing: 8
            Layout.fillWidth: true
            Repeater {
                model: pop.actions
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: actRow.implicitWidth + 16
                    implicitHeight: 26
                    radius: 13
                    color: Config.accent
                    Row {
                        id: actRow
                        anchors.centerIn: parent
                        spacing: 5
                        MatIcon { text: modelData.icon || ""; font.pixelSize: 13; color: Config.bg; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.label || ""; color: Config.bg; font.family: Config.textFont; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { modelData.run && modelData.run(); pop.bar.hidePopout() }
                    }
                }
            }
            Item { Layout.fillWidth: true; implicitWidth: 1; implicitHeight: 1 }
        }
    }
}
