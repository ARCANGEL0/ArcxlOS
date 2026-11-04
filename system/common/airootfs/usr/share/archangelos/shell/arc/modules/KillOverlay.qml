// Kill mode (SUPER+SHIFT+K): darkens the screen with a plain crosshair cursor, and clicking
// a window force-kills every process of that app. ESC or a click on empty space cancels.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.arc
import qs.arc.components
import qs.arc.services

PanelWindow {
    id: ov
    required property var modelData
    screen: modelData
    // Always realized; entering kill mode only flips colour/mask, so it is instant.
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: Shell.killMode ? Qt.rgba(0.06, 0.0, 0.0, 0.5) : "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Shell.killMode ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Region { id: noInput }
    mask: Shell.killMode ? null : noInput

    Connections {
        target: Shell
        function onKillModeChanged() { if (Shell.killMode) ma.forceActiveFocus() }
    }
    property real mx: width / 2
    property real my: height / 2

    // Topmost (smallest-area) mapped Hyprland toplevel under the cursor.
    function windowAt(x, y) {
        const tls = Hyprland.toplevels?.values ?? [];
        let best = null, bestArea = Infinity;
        for (const t of tls) {
            const o = t.lastIpcObject;
            if (!o || o.mapped === false) continue;
            const ax = o.at?.[0] ?? 0, ay = o.at?.[1] ?? 0;
            const w = o.size?.[0] ?? 0, h = o.size?.[1] ?? 0;
            if (w <= 0 || h <= 0) continue;
            if (x < ax || y < ay || x >= ax + w || y >= ay + h) continue;
            const area = w * h;
            if (area < bestArea) { bestArea = area; best = o; }
        }
        return best;
    }

    function killAt(x, y) {
        const w = ov.windowAt(x, y);
        Shell.killMode = false;
        if (w && w.pid > 1) { killProc.targetPid = w.pid; killProc.running = true; }
    }

    Process {
        id: killProc
        property int targetPid: 0
        running: false
        command: ["sh", "-c",
            "APP=$(cat /proc/$1/comm 2>/dev/null | tr -d ' '); "
            + "case \"$APP\" in ''|Hyprland|hyprland|systemd|systemd-logind|login|Xwayland|wayfire|river|rio|ssh|sshd|sudo|su|dbus-daemon|dbus-broker|polkit*|qs|quickshell) exit 1;; esac; "
            + "pkill -9 -x \"$APP\" 2>/dev/null; true", "sh", String(killProc.targetPid)]
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: Shell.killMode
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        Keys.onEscapePressed: Shell.killMode = false
        onPositionChanged: (mouse) => { ov.mx = mouse.x; ov.my = mouse.y }
        onClicked: (mouse) => ov.killAt(mouse.x, mouse.y)
    }

    Text {
        visible: Shell.killMode
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: 24
        text: "KILL MODE — click a window to force-kill its app · ESC to cancel"
        color: "#e03030"; font.family: Config.textFont; font.pixelSize: 13; font.weight: Font.Bold
    }
}
