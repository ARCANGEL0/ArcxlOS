import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    property bool open: Quickshell.env("ARCHANGELOS_WHEEL_SHOW") === "1"

    Component.onCompleted: {
        const run = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
        pidWriter.path = run + "/archangelos-wheel.pid";
    }

    FileView {
        id: pidWriter
        onPathChanged: if (path.length > 0) setText("" + Quickshell.processId)
    }

    IpcHandler {
        target: "wheel"
        function toggle(): void { root.open = !root.open }
        function show(): void { root.open = true }
        function hide(): void { root.open = false }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.open
            anchors.top: true; anchors.bottom: true
            anchors.left: true; anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            implicitWidth: modelData.width
            implicitHeight: modelData.height
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "archangelos-wheel"

            Wheel {
                anchors.fill: parent
                active: root.open
                onDismiss: root.open = false
            }
        }
    }
}
