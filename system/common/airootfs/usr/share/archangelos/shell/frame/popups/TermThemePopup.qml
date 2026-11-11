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
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.arc.components as NSC
import qs.arc.services as NSS
import "../"

Item {
    id: root

    property real localScale: 1.0
    readonly property real s: localScale
    property bool open: false
    property var model: []

    implicitWidth: Math.round(648 * s)
    implicitHeight: Math.round(300 * s)
    width: implicitWidth
    height: implicitHeight
    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: popScale.scale
    transformOrigin: Item.Bottom

    Behavior on opacity { NumberAnimation { duration: Anim.mediumFast } }
    readonly property real riseY: (1 - popScale.scale) * Math.round(16 * s)
    transform: Translate { y: root.riseY }

    QtObject {
        id: popScale
        property real scale: open ? 1 : 0.88
        Behavior on scale { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
    }

    function refresh() { listProc.running = true }
    onOpenChanged: if (open) refresh()

    Process {
        id: listProc
        command: ["sh", "-c", 'p=$(command -v archangelos-terminal-theme); [ -z "$p" ] && [ -x "$HOME/.local/bin/archangelos-terminal-theme" ] && p="$HOME/.local/bin/archangelos-terminal-theme"; [ -z "$p" ] && p=/usr/bin/archangelos-terminal-theme; exec "$p" list']
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                for (const line of text.split("\n")) {
                    const f = line.split("|")
                    if (f.length >= 7 && f[0]) rows.push({ id: f[0], name: f[1], desc: f[2], bg: f[3] || "#000000", fg: f[4] || "#ffffff", accent: f[5] || "#ffffff", on: f[6] === "1" })
                }
                root.model = rows
            }
        }
    }

    function pick(id) {
        Quickshell.execDetached(["sh", "-c", 'p=$(command -v archangelos-terminal-theme); [ -z "$p" ] && [ -x "$HOME/.local/bin/archangelos-terminal-theme" ] && p="$HOME/.local/bin/archangelos-terminal-theme"; [ -z "$p" ] && p=/usr/bin/archangelos-terminal-theme; exec "$p" use "$1"', "sh", id])
        // mark ACTIVE immediately; confirm from disk only after the use process has finished
        root.model = root.model.map(r => Object.assign({}, r, { on: r.id === id }))
        confirmTimer.restart()
    }

    Timer {
        id: confirmTimer; interval: 900; repeat: false
        onTriggered: refresh()
    }

    // swallow clicks inside the popup so the outside-click shield doesn't dismiss it
    MouseArea { anchors.fill: parent }

    Rectangle {
        anchors.fill: parent
        radius: Math.round(16 * s)
        color: Theme.background
        border.width: Math.max(1, Math.round(Theme.borderWidth * s))
        border.color: Theme.border
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 32; saturation: 1.2 }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Math.round(14 * s)
        spacing: Math.round(10 * s)

        Row {
            width: parent.width
            spacing: Math.round(8 * s)
            Text {
                text: "TERMINAL"
                color: Theme.subtext
                font.pixelSize: Math.round(11 * s)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.model.length + " THEMES"
                color: Theme.subtext
                font.pixelSize: Math.round(11 * s)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                width: parent.width - Math.round(150 * s) - gearBox.width
            }
            Item { width: 1; height: 1 }
            Item {
                id: gearBox
                width: Math.round(28 * s); height: Math.round(28 * s)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.active
                    opacity: gearHov.hovered ? 0.18 : 0
                    Behavior on opacity { NumberAnimation { duration: Anim.fast } }
                }
                NSC.MatIcon {
                    anchors.centerIn: parent
                    text: "settings"
                    font.pixelSize: Math.round(16 * s)
                    color: gearHov.hovered ? Theme.active : Theme.subtext
                    scale: gearHov.hovered ? 1.4 : 1.0
                    rotation: gearHov.hovered ? 90 : 0
                    Behavior on color { ColorAnimation { duration: Anim.fast } }
                    Behavior on scale { NumberAnimation { duration: Anim.fast; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
                    Behavior on rotation { NumberAnimation { duration: Anim.mediumFast; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
                }
                HoverHandler { id: gearHov }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NSS.Shell.openSettings("shell")
                }
            }
        }

        Grid {
            columns: 4
            spacing: Math.round(8 * s)
            Repeater {
                model: root.model
                delegate: Item {
                    id: cardItem
                    width: Math.round(146 * s)
                    height: Math.round(118 * s)
                    readonly property bool hov: cardMa.hovered
                    scale: hov ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: Anim.fast; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: Math.round(10 * s)
                        color: cardItem.hov ? Theme.cardHover : Theme.card
                        border.width: (modelData.on || cardItem.hov) ? Math.max(2, Math.round(2 * s)) : Math.max(1, Math.round(s))
                        border.color: modelData.on ? modelData.accent : (cardItem.hov ? Theme.active : Theme.border)
                        Behavior on color { ColorAnimation { duration: Anim.color } }
                        Behavior on border.color { ColorAnimation { duration: Anim.color } }
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: Math.round(6 * s)
                        height: Math.round(52 * s)
                        radius: Math.round(6 * s)
                        color: modelData.bg
                        Column {
                            anchors.fill: parent
                            anchors.margins: Math.round(6 * s)
                            spacing: Math.round(2 * s)
                            Text { text: "~ $ ls"; color: modelData.fg; font.pixelSize: Math.round(9 * s); font.family: "monospace" }
                            Text { text: "shaders  themes"; color: modelData.accent; font.pixelSize: Math.round(9 * s); font.family: "monospace" }
                            Text { text: "~ $ █"; color: modelData.fg; font.pixelSize: Math.round(9 * s); font.family: "monospace" }
                        }
                    }
                    Text {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: card.bottom; anchors.topMargin: Math.round(6 * s)
                        anchors.leftMargin: Math.round(4 * s); anchors.rightMargin: Math.round(4 * s)
                        text: modelData.name
                        color: Theme.text
                        font.pixelSize: Math.round(11 * s)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        anchors.leftMargin: Math.round(4 * s); anchors.rightMargin: Math.round(4 * s)
                        text: modelData.desc
                        color: Theme.subtext
                        font.pixelSize: Math.round(9 * s)
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        id: badge
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: Math.round(8 * s)
                        width: Math.round(44 * s); height: Math.round(14 * s)
                        radius: height / 2
                        color: modelData.accent
                        visible: modelData.on
                        opacity: modelData.on ? 1 : 0
                        scale: modelData.on ? 1 : 0.4
                        Behavior on opacity { NumberAnimation { duration: Anim.fast } }
                        Behavior on scale { NumberAnimation { duration: Anim.fast; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
                        Text {
                            anchors.centerIn: parent
                            text: "ACTIVE"
                            color: modelData.bg
                            font.pixelSize: Math.round(8 * s)
                            font.bold: true
                        }
                    }
                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(modelData.id)
                    }
                }
            }
        }
    }
}
