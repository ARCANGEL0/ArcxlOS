//  ArchangelOS — radial application launcher
//  Quickshell entry point. Spawned by /usr/bin/archangelos-launcher and
//  dismissed by quitting the process (SUPER+TAB toggle). Fullscreen,
//  transparent Wayland overlay across every screen.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    // Absolute path to the menu definition (overridable via QS_MENU env).
    property string menuPath: {
        var p = Quickshell.env("ARCHANGELOS_MENU")
        return (p && p.length > 0) ? p : "/usr/share/archangelos/launcher/menu.json"
    }

    // Absolute path to the ArchangelOS mark shown at the hub.
    property string logoPath: {
        var p = Quickshell.env("ARCHANGELOS_LOGO")
        return (p && p.length > 0) ? p : "/usr/share/archangelos/logo.png"
    }

    function dismiss() { Qt.quit() }

    // debug/screenshot aid: start with a category pre-focused (ARCHANGELOS_FOCUS)
    property int startFocus: {
        var v = Quickshell.env("ARCHANGELOS_FOCUS")
        return (v && v.length > 0) ? parseInt(v) : -1
    }

    // debug/screenshot aid: pre-fill the live search (ARCHANGELOS_QUERY)
    property string startQuery: {
        var q = Quickshell.env("ARCHANGELOS_QUERY")
        return (q && q.length > 0) ? q : ""
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: true
            anchors.top: true; anchors.bottom: true
            anchors.left: true; anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            implicitWidth: modelData.width
            implicitHeight: modelData.height
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "archangelos-launcher"

            Launcher {
                anchors.fill: parent
                menuPath: root.menuPath
                logoPath: root.logoPath
                startFocus: root.startFocus
                startQuery: root.startQuery
                onDismiss: root.dismiss()
            }
        }
    }
}
