// Overlay shown while slurp is picking a capture region (the pick itself is slurp's).
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.arc
import qs.arc.services

PanelWindow {
    id: sel
    required property var modelData
    screen: modelData

    visible: Capture.picking
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Text {
        anchors.centerIn: parent
        text: "Drag to select a region · Esc to cancel"
        color: Config.fg
        font.family: Config.textFont
        font.pixelSize: 15
        font.bold: true
        style: Text.Raised
        styleColor: Config.bg
    }
}
