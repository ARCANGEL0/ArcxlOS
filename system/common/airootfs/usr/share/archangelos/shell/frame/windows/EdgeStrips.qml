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
import qs.arc.components as NSC
import "../" as Frame

PanelWindow {
    id: root

    required property bool rightEdge
    required property var modelData

    readonly property real uiScale: Math.max(0.75, Math.min(1.5, (screen ? screen.height : 1080) / 1080))
    readonly property int frameBorder: Math.round(Frame.Theme.borderWidth * root.uiScale)

    screen: modelData
    anchors { top: true; bottom: true; left: !rightEdge; right: rightEdge }
    implicitWidth: 28
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: rightEdge ? "arcshell-edge-right" : "arcshell-edge-left"
    mask: Region { Region { item: root.rightEdge ? tabHit : zone } }

    Item {
        id: zone
        visible: !root.rightEdge
        anchors.centerIn: parent
        width: parent.width
        height: Math.round(320 * root.uiScale)

        HoverHandler {
            onHoveredChanged: Frame.Popups.archMenuTriggerHovered = hovered
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
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

    Item {
        id: tabHit
        visible: root.rightEdge
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.round(64 * root.uiScale)

        Rectangle {
            id: tab
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.frameBorder + Math.round(13 * root.uiScale)
            height: Math.round(44 * root.uiScale)
            radius: Math.round(8 * root.uiScale)
            color: Frame.Theme.background
            opacity: Frame.Popups.audioOpen ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Frame.Anim.fast } }

            NSC.MatIcon {
                x: Math.round((tab.width - root.frameBorder - width) / 2)
                anchors.verticalCenter: parent.verticalCenter
                text: "chevron_left"
                font.pixelSize: Math.round(13 * root.uiScale)
                color: tabHover.hovered ? Frame.Theme.active : Frame.Theme.subtext
                Behavior on color { ColorAnimation { duration: Frame.Anim.fast } }
            }
        }

        HoverHandler {
            id: tabHover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                Frame.Popups.audioTriggerHovered = hovered
                if (hovered && !Frame.Popups.audioOpen) {
                    Frame.Popups.closeAll()
                    Frame.SurfaceState.open("rightCenter", "audio")
                }
            }
        }
        TapHandler {
            onTapped: {
                if (Frame.Popups.audioOpen) Frame.Popups.audioPinned = !Frame.Popups.audioPinned
                else {
                    Frame.Popups.closeAll()
                    Frame.SurfaceState.open("rightCenter", "audio")
                    Frame.Popups.audioPinned = true
                }
            }
        }
    }
}
