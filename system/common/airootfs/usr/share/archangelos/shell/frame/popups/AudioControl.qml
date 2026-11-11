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
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.arc.services
import qs.arc.components as NSC
import "../components"
import "../services"
import "../"

Item {
    id: root

    property real localScale: 1.0
    property bool fullyOpen: true

    readonly property var sink:   Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks:   Pipewire.nodes.values.filter(n => ((n.properties?.["media.class"]) || "") === "Audio/Sink")
    readonly property var sources: Pipewire.nodes.values.filter(n => ((n.properties?.["media.class"]) || "") === "Audio/Source")
    readonly property var monitors: (Display.monitors || []).filter(m => !m.disabled)

    readonly property real devicesHeight: devCol.implicitHeight

    function s(v) { return Math.round(v * root.localScale) }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.s(10)
        spacing: root.s(8)

        Item {
            id: page
            Layout.fillWidth: true
            Layout.fillHeight: true

            Row {
                visible: Popups.audioPage === "volume"
                anchors.centerIn: parent
                spacing: root.s(14)

                VBar {
                    title: "OUTPUT"
                    value: (root.sink?.ready && root.sink.audio) ? root.sink.audio.volume : 0
                    muted: root.sink?.audio?.muted ?? false
                    icon: muted ? "volume_off" : (value > 0.5 ? "volume_up" : "volume_down")
                    onMuteToggled: if (root.sink?.ready) root.sink.audio.muted = !root.sink.audio.muted
                    onValueSet: v => { if (root.sink?.ready) root.sink.audio.volume = v }
                }
                VBar {
                    title: "INPUT"
                    value: (root.source?.ready && root.source.audio) ? root.source.audio.volume : 0
                    muted: root.source?.audio?.muted ?? false
                    icon: muted ? "mic_off" : "mic"
                    onMuteToggled: if (root.source?.ready) root.source.audio.muted = !root.source.audio.muted
                    onValueSet: v => { if (root.source?.ready) root.source.audio.volume = v }
                }
            }

            Flickable {
                visible: Popups.audioPage === "devices"
                anchors.fill: parent
                contentHeight: devCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: devCol
                    width: parent.width
                    spacing: root.s(2)

                    Heading { text: "INPUT" }
                    Repeater {
                        model: root.sources
                        DeviceRow {
                            required property var modelData
                            node: modelData
                            isDefault: root.source === modelData
                            onPicked: Audio.setAudioSource(node)
                        }
                    }
                    Item { width: 1; height: root.s(6) }
                    Heading { text: "OUTPUT" }
                    Repeater {
                        model: root.sinks
                        DeviceRow {
                            required property var modelData
                            node: modelData
                            isDefault: root.sink === modelData
                            onPicked: Audio.setAudioSink(node)
                        }
                    }
                }
            }

            ColumnLayout {
                visible: Popups.audioPage === "display"
                anchors.fill: parent
                spacing: root.s(6)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(6)

                    Column {
                        Layout.fillWidth: true
                        spacing: root.s(4)
                        Repeater {
                            model: root.monitors
                            Column {
                                required property var modelData
                                width: parent.width
                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.pixelSize: root.s(11)
                                    font.bold: true
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.width + "×" + modelData.height + " · " + Math.round(modelData.refreshRate) + "Hz · " + modelData.scale + "x"
                                    elide: Text.ElideRight
                                    color: Theme.subtext
                                    font.pixelSize: root.s(9)
                                }
                            }
                        }
                    }

                    RailIcon {
                        Layout.alignment: Qt.AlignTop
                        icon: "settings"
                        onTapped: { SurfaceState.close(); Shell.openSettings("displays") }
                    }
                }

                VBar {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: root.s(2)
                    title: "BRIGHTNESS"
                    value: BrightnessService.brightness / 100
                    icon: "brightness_6"
                    muteable: false
                    onValueSet: v => BrightnessService.setBrightness(Math.round(v * 100))
                }

                Item { Layout.fillHeight: true }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: root.s(10)
            Layout.bottomMargin: root.s(10)
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
        }

        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: root.s(6)

            RailIcon { icon: "volume_up";  selected: Popups.audioPage === "volume";  onTapped: Popups.audioPage = "volume" }
            RailIcon { icon: "headphones"; selected: Popups.audioPage === "devices"; onTapped: Popups.audioPage = "devices" }
            RailIcon { icon: "light_mode"; selected: Popups.audioPage === "display"; onTapped: Popups.audioPage = "display" }
        }
    }

    component RailIcon: Item {
        id: ri
        property string icon: ""
        property bool selected: false
        signal tapped()
        implicitWidth: root.s(26)
        implicitHeight: root.s(26)

        NSC.MatIcon {
            anchors.centerIn: parent
            text: ri.icon
            font.pixelSize: root.s(17)
            color: ri.selected ? Theme.active : (riHov.hovered ? Theme.text : Theme.subtext)
            scale: riTap.pressed ? 0.88 : 1
            Behavior on color { ColorAnimation { duration: Anim.fast } }
            Behavior on scale { NumberAnimation { duration: Anim.fast } }
        }
        HoverHandler { id: riHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: riTap; onTapped: ri.tapped() }
    }

    component Heading: Text {
        color: Theme.subtext
        font.pixelSize: root.s(9)
        font.bold: true
        font.letterSpacing: 0.6
        bottomPadding: root.s(2)
    }

    component DeviceRow: Item {
        id: dr
        property var node: null
        property bool isDefault: false
        signal picked()
        width: parent.width
        height: root.s(26)

        Rectangle {
            anchors.fill: parent
            radius: root.s(6)
            color: Theme.text
            opacity: drHov.hovered ? 0.06 : 0
            Behavior on opacity { NumberAnimation { duration: Anim.fast } }
        }
        Row {
            anchors.fill: parent
            anchors.leftMargin: root.s(6)
            anchors.rightMargin: root.s(6)
            spacing: root.s(6)
            NSC.MatIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: dr.isDefault ? "radio_button_checked" : "radio_button_unchecked"
                font.pixelSize: root.s(13)
                color: dr.isDefault ? Theme.active : Theme.subtext
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - root.s(19)
                text: dr.node?.description || dr.node?.nickname || dr.node?.name || "Unknown device"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: dr.isDefault ? Theme.active : Theme.text
                font.pixelSize: root.s(11)
            }
        }
        HoverHandler { id: drHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: dr.picked() }
    }

    component VBar: Column {
        id: vb
        property string title: ""
        property real value: 0
        property bool muted: false
        property string icon: ""
        property bool muteable: true
        signal muteToggled()
        signal valueSet(real v)
        readonly property real shown: Math.max(0, Math.min(1, Number.isFinite(vb.value) ? vb.value : 0))

        spacing: root.s(6)
        width: root.s(46)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: vb.title
            color: Theme.subtext
            font.pixelSize: root.s(9)
            font.bold: true
            font.letterSpacing: 0.6
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(vb.shown * 100) + "%"
            color: vb.muted ? Theme.subtext : Theme.text
            font.pixelSize: root.s(12)
            font.bold: true
        }
        Rectangle {
            id: track
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.s(28)
            height: root.s(120)
            radius: width / 2
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: Math.max(parent.width, parent.height * vb.shown)
                radius: parent.radius
                color: vb.muted ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.18) : Theme.active
                Behavior on color { ColorAnimation { duration: Anim.mediumFast } }
                Behavior on height { NumberAnimation { duration: Anim.superFast; easing.type: Anim.outCubic } }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -root.s(6)
                cursorShape: Qt.SizeVerCursor
                function at(y) { return Math.max(0, Math.min(1, 1 - (y - root.s(6)) / track.height)) }
                onPressed: e => vb.valueSet(at(e.y))
                onPositionChanged: e => { if (pressed) vb.valueSet(at(e.y)) }
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => vb.valueSet(Math.max(0, Math.min(1, vb.shown + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.s(26)
            height: root.s(22)
            NSC.MatIcon {
                anchors.centerIn: parent
                text: vb.icon
                font.pixelSize: root.s(16)
                color: vb.muted ? Theme.active : (muteHov.hovered && vb.muteable ? Theme.text : Theme.subtext)
                Behavior on color { ColorAnimation { duration: Anim.fast } }
            }
            HoverHandler { id: muteHov; enabled: vb.muteable; cursorShape: Qt.PointingHandCursor }
            TapHandler { enabled: vb.muteable; onTapped: vb.muteToggled() }
        }
    }
}
