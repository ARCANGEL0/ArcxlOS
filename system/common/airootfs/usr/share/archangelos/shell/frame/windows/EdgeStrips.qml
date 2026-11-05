/*
 * ArcShell
 * Copyright (C) 2026 arcxlo (ArchangelOS)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../" as Frame

// Thin always-on-top strips at the left/right screen edges (middle band).
// The frame's own notch masks sit under other full-screen layer surfaces and
// never saw pointer input, so hover triggers live here where the window itself
// IS the hover zone (default mask = whole window = the strip).
PanelWindow {
    id: root

    required property bool rightEdge   // true: right edge (quick/audio), false: left edge (arch menu)
    required property var modelData

    screen: modelData
    anchors { top: true; bottom: true; left: !rightEdge; right: rightEdge }
    width: 28
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: rightEdge ? "arcshell-edge-right" : "arcshell-edge-left"
    // input only on the middle band, so window corner controls at the edges stay clickable
    mask: Region { Region { item: zone } }

    Item {
        id: zone
        anchors.centerIn: parent
        width: parent.width
        height: Math.round(320 * (screen ? screen.height / 1080 : 1))

        HoverHandler {
            onHoveredChanged: {
                if (root.rightEdge) {
                    Frame.Popups.quickTriggerHovered = Frame.Popups.audioOpen ? false : hovered
                    Frame.Popups.audioTriggerHovered = hovered
                } else {
                    Frame.Popups.archMenuTriggerHovered = hovered
                }
            }
        }

        MouseArea {
            anchors.fill: parent
        onClicked: {
            if (root.rightEdge) {
                if (Frame.Popups.audioOpen && Frame.Popups.audioAllowHover) {
                    Frame.Popups.audioPinned = !Frame.Popups.audioPinned
                    return
                }
                if (Frame.SurfaceState.activeContent === "quick" && Frame.Popups.quickAllowHover) {
                    Frame.Popups.quickPinned = !Frame.Popups.quickPinned
                    return
                }
                if (!Frame.Popups.audioAllowHover && !Frame.Popups.quickAllowHover) {
                    if (Frame.Popups.audioOpen) {
                        Frame.SurfaceState.toggle("rightCenter", "audio")
                    } else if (Frame.SurfaceState.activeContent === "quick") {
                        Frame.SurfaceState.toggle("rightCenter", "quick")
                    } else {
                        Frame.SurfaceState.toggle("rightCenter", "quick")
                        Frame.Popups.quickPinned = true
                    }
                }
            } else {
                if (Frame.SurfaceState.activeContent === "archMenu" && Frame.Popups.archMenuAllowHover) {
                    Frame.Popups.archMenuPinned = !Frame.Popups.archMenuPinned
                    return
                }
                if (!Frame.Popups.archMenuAllowHover) {
                    const next = Frame.SurfaceState.activeContent !== "archMenu"
                    Frame.SurfaceState.toggle("leftCenter", "archMenu")
                    if (next) Frame.Popups.archMenuPinned = true
                }
            }
        }
    }
    }
}
