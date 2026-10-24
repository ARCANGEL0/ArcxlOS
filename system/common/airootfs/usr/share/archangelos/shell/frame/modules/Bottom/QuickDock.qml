/*
 * ArchangelOS shell — the bottom-centre resting notch: quick launches and small things.
 * Part of the ArcShell / arcshell mesh; AGPL-3.0 (see LICENSE).
 *
 * It rests in ArcShell's bottom-centre notch; the panels it calls rise out of the same edge
 * (the wallpaper picker morphs the notch itself, the launcher is arcshell's bulge) or out of
 * the bottom-right corner (clipboard); Apps opens the constellation launcher overlay.
 */

import QtQuick
import Quickshell
import qs.arc.components as NSC
import qs.arc.services as NSS
import "../../"

Row {
    id: dock
    property real localScale: 1.0
    readonly property int cell: Math.round(32 * localScale)
    spacing: Math.round(4 * localScale)

    // [glyph, tooltip, action]
    readonly property var launches: [
        // the constellation launcher (archangelos-launcher, SUPER+TAB) …
        ["apps",      "Apps",      () => Quickshell.execDetached(["archangelos-launcher-toggle"])],
        // … and arcshell's palette: apps, >commands, #clipboard, =calc, $run, :emoji
        ["search",    "Search",    () => NSS.Shell.launcherVisible = true],
        ["terminal",  "Terminal",  () => Quickshell.execDetached(["rio"])],
        ["folder",    "Files",     () => Quickshell.execDetached(["thunar"])],
        ["language",  "Browser",   () => Quickshell.execDetached(["librewolf"])]
    ]
    readonly property var tools: [
        ["wallpaper",     "Wallpapers", () => { Popups.closeAll(); SurfaceState.open("bottomCenter", "wallpaper"); Popups.wallpaperPinned = true }],
        ["content_paste", "Clipboard",  () => { Popups.closeAll(); SurfaceState.open("bottomRight", "clipboard"); Popups.clipboardPinned = true }],
        ["screenshot_region", "Screenshot", () => IpcManager.screenshotDelayed()]
    ]

    component Cell: Item {
        id: c
        required property var modelData
        width: dock.cell; height: dock.cell

        Rectangle {
            anchors.fill: parent
            radius: Math.round(9 * dock.localScale)
            color: hov.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.16) : "transparent"
            border.width: 1
            border.color: hov.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35) : "transparent"
            Behavior on color { ColorAnimation { duration: Anim.color } }
            Behavior on border.color { ColorAnimation { duration: Anim.color } }
        }
        NSC.MatIcon {
            anchors.centerIn: parent
            text: c.modelData[0]
            font.pixelSize: Math.round(18 * dock.localScale)
            color: hov.hovered ? Theme.active : Theme.subtext
            scale: tap.pressed ? 0.86 : (hov.hovered ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: Anim.mediumFast; easing.type: Easing.OutCubic } }
        }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        MouseArea { id: tap; anchors.fill: parent; onClicked: c.modelData[2]() }
    }

    Repeater { model: dock.launches; Cell {} }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1; height: Math.round(14 * dock.localScale)
        color: Theme.border
    }

    Repeater { model: dock.tools; Cell {} }
}
