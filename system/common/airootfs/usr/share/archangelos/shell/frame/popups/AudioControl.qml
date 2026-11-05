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
import Quickshell.Services.Pipewire
import "../components"
import "../services"
import "../"

Item {
    id: root

    property real localScale: 1.0
    property bool fullyOpen: true

    readonly property var sink:   Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    // Three vertical bars shown directly — no tabs, no pages.
    Row {
        id: bars
        anchors.centerIn: parent
        spacing: Math.round(14 * localScale)

        VBar {
            localScale: root.localScale
            title: "VOLUME"
            value: root.sink?.ready ? root.sink.audio.volume : 0
            muted: root.sink?.audio.muted ?? false
            icon: {
                if (!root.sink?.ready)            return "󰕾"
                if (root.sink.audio.muted)        return "󰖁"
                if (root.sink.audio.volume > 0.6) return "󰕾"
                if (root.sink.audio.volume > 0.2) return "󰖀"
                return "󰕿"
            }
            muteable: true
            onMuteToggled: {
                if (root.sink?.ready) root.sink.audio.muted = !root.sink.audio.muted
            }
            onValueSet: function(v) {
                if (root.sink?.ready) root.sink.audio.volume = v
            }
        }

        VBar {
            localScale: root.localScale
            title: "MICROPHONE"
            value: root.source?.ready ? root.source.audio.volume : 0
            muted: root.source?.audio.muted ?? false
            icon: {
                if (!root.source?.ready)         return "󰍭"
                if (root.source.audio.muted)     return "󰍭"
                return "󰍬"
            }
            muteable: true
            onMuteToggled: {
                if (root.source?.ready) root.source.audio.muted = !root.source.audio.muted
            }
            onValueSet: function(v) {
                if (root.source?.ready) root.source.audio.volume = v
            }
        }

        VBar {
            localScale: root.localScale
            title: "BRIGHTNESS"
            value: BrightnessService.brightness / 100
            muted: false
            icon: "󰃠"
            muteable: false
            onMuteToggled: {}
            onValueSet: function(v) {
                BrightnessService.setBrightness(Math.round(v * 100))
            }
        }
    }

    component VBar: Item {
        property real localScale: 1.0
        property string title: ""
        property real value: 0
        property bool muted: false
        property string icon: ""
        property bool muteable: true
        signal muteToggled()
        signal valueSet(real v)

        implicitWidth: Math.round(56 * localScale)
        implicitHeight: Math.round(260 * localScale)

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(10 * localScale)

            Text {
                text: Math.round(root.value * 100) + "%"
                color: root.muted ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25) : Theme.text
                font.pixelSize: Math.round(13 * localScale)
                font.bold: true
            }

            Item {
                width: Math.round(30 * localScale)
                height: Math.round(160 * localScale)

                Rectangle {
                    id: track
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)

                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: Math.max(radius * 2, parent.height * root.value)
                        radius: parent.radius
                        color: root.muted ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.15) : Theme.active
                        Behavior on color { ColorAnimation { duration: Anim.mediumFast } }
                        Behavior on height { NumberAnimation { duration: Anim.superFast; easing.type: Anim.outCubic } }
                    }

                    MouseArea {
                        id: trackMouse
                        anchors.fill: parent
                        anchors.topMargin: -Math.round(8 * localScale)
                        anchors.bottomMargin: -Math.round(8 * localScale)
                        cursorShape: Qt.SizeVerCursor
                        function calc(my) {
                            return Math.max(0.0, Math.min(1.0, 1.0 - (my / track.height)))
                        }
                        onPressed: root.valueChanged(calc(mouseY))
                        onPositionChanged: if (pressed) root.valueChanged(calc(mouseY))
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            var step = 0.05
                            var delta = event.angleDelta.y > 0 ? step : -step
                            root.valueChanged(Math.max(0.0, Math.min(1.0, root.value + delta)))
                        }
                    }
                }
            }

            Rectangle {
                width: Math.round(30 * localScale) + Math.round(16 * localScale)
                height: Math.round(28 * localScale)
                radius: Math.round(Theme.cornerRadius * localScale)
                color: root.muted
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2)
                    : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
                Behavior on color { ColorAnimation { duration: Anim.mediumFast } }

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    font.pixelSize: Math.round(14 * localScale)
                    color: root.muted ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.55)
                }

                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color: muteHov.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: Anim.fast } }
                }

                HoverHandler { id: muteHov; enabled: root.muteable }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.muteable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.muteToggled()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.title
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.3)
                font.pixelSize: Math.round(10 * localScale)
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
            }
        }
    }
}
