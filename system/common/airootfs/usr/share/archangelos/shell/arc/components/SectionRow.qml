// Label / value row for the per-meter hover panes.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.arc

Item {
    id: row
    property string label: ""
    property string value: ""
    Layout.fillWidth: true
    implicitHeight: 20

    RowLayout {
        anchors.fill: parent
        spacing: 8
        Text { Layout.fillWidth: true; text: row.label; color: Config.dim; font.family: Config.textFont; font.pixelSize: 10 }
        Text { text: row.value; color: Config.fg; font.family: Config.textFont; font.pixelSize: 10; font.bold: true }
    }
}
