import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    property string menuPath: {
        var p = Quickshell.env("ARCHANGELOS_MENU")
        return (p && p.length > 0) ? p : "/usr/share/archangelos/launcher/menu.json"
    }

    property string logoPath: {
        var p = Quickshell.env("ARCHANGELOS_LOGO")
        return (p && p.length > 0) ? p : "/usr/share/archangelos/logo-mark.svg"
    }

    property int startFocus: {
        var v = Quickshell.env("ARCHANGELOS_FOCUS")
        return (v && v.length > 0) ? parseInt(v) : -1
    }

    property string startQuery: {
        var q = Quickshell.env("ARCHANGELOS_QUERY")
        return (q && q.length > 0) ? q : ""
    }

    property bool open: Quickshell.env("ARCHANGELOS_SHOW") === "1"

    IpcHandler {
        target: "launcher"
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
            WlrLayershell.namespace: "archangelos-launcher"

            Launcher {
                anchors.fill: parent
                active: root.open
                menuPath: root.menuPath
                logoPath: root.logoPath
                startFocus: root.startFocus
                startQuery: root.startQuery
                onDismiss: root.open = false
            }
        }
    }
}
