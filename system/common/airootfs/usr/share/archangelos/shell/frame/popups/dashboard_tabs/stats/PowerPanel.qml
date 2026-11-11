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
import qs.arc.modules.bar as ArcBar
import "../../"
import "../../../"
import "../../../components"

Item {
    id: root

    property real localScale: 1.0
    required property var envyService

    ArcBar.PowerProfile { id: pp }
    Component.onCompleted: pp.refresh()
    onVisibleChanged: if (visible) { pp.error = ""; pp.refresh(); }
    Timer { interval: 4000; repeat: true; running: root.visible; onTriggered: pp.refresh() }

    Column {
        anchors.centerIn: parent
        spacing:          Math.round(16 * localScale)

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(8 * localScale)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "Power Profile"
                font.pixelSize: Math.round(11 * localScale)
                font.weight:    Font.Medium
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(6 * localScale)

                Repeater {
                    model: [
                        { id: "performance", label: "Performance" },
                        { id: "balanced",    label: "Balanced" },
                        { id: "power-saver", label: "Power Saver" }
                    ]
                    ProfileButton {
                        required property var modelData
                        localScale: root.localScale
                        label:     modelData.label
                        active:    pp.profile === modelData.id
                        enabled:   pp.pending === "" && pp.profile !== ""
                        onClicked: pp.apply(modelData.id)
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width:               Math.min(implicitWidth, root.width - Math.round(16 * localScale))
                visible:             text !== ""
                text:                pp.pending !== "" ? "Switching power mode…" : pp.error
                textFormat:          Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                wrapMode:            Text.Wrap
                font.pixelSize:      Math.round(10 * localScale)
                color:               pp.pending !== ""
                                         ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)
                                         : Theme.error
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width:  Math.round(200 * localScale)
            height: 1
            color:  Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(8 * localScale)
            visible: envyService.available

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "GPU Mode"
                font.pixelSize: Math.round(11 * localScale)
                font.weight:    Font.Medium
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(6 * localScale)

                ProfileButton {
                    localScale: root.localScale
                    label:     "Integrated"
                    active:    root.envyService.currentMode === "integrated"
                    enabled:   !root.envyService.busy
                    onClicked: root.envyService.switchMode("integrated")
                }
                ProfileButton {
                    localScale: root.localScale
                    label:     "Hybrid"
                    active:    root.envyService.currentMode === "hybrid"
                    enabled:   !root.envyService.busy
                    onClicked: root.envyService.switchMode("hybrid")
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "GPU mode switch requires a reboot"
                font.pixelSize: Math.round(10 * localScale)
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(8 * localScale)
            visible: !envyService.available

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "GPU Mode"
                font.pixelSize: Math.round(11 * localScale)
                font.weight:    Font.Medium
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "EnvyControl not installed"
                font.pixelSize: Math.round(12 * localScale)
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.3)
            }
        }
    }
}
