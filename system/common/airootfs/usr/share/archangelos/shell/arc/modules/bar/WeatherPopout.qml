// ArchangelOS: weather pane — current conditions, a 3-day outlook and a city field.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.arc
import qs.arc.components
import qs.arc.services

BarPopout {
    id: pop
    name: "weather"
    implicitWidth: 236
    bodyHeight: 326
    reportOnHover: true

    onOpened: Weather.refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 14 + Config.popFillet * 2 - pop.botPad + pop.topPad
        anchors.bottomMargin: 14 + pop.botPad
        spacing: 10

        // --- header: city + observed time ---
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: Weather.city
                color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; font.bold: true
                elide: Text.ElideRight
            }
            Text {
                text: Weather.ok ? Weather.observed : (Weather.loading ? "…" : "offline")
                color: Config.dim; font.family: Config.textFont; font.pixelSize: 9
            }
        }

        // --- current ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MatIcon { text: Weather.icon; font.pixelSize: 40; color: Config.accent }
            ColumnLayout {
                spacing: 0
                Text {
                    text: Weather.ok ? Weather.tempC + "°" : "--"
                    color: Config.fg; font.family: Config.textFont; font.pixelSize: 30; font.bold: true
                }
                Text {
                    Layout.maximumWidth: 120
                    text: Weather.condition || "no data"
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        // --- feels / humidity / wind ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [["device_thermostat", Weather.feelsC + "°", "feels"],
                        ["humidity_mid", Weather.humidity + "%", "humidity"],
                        ["air", Weather.windKph + "", "km/h"]]
                delegate: ColumnLayout {
                    id: stat
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 1
                    MatIcon { Layout.alignment: Qt.AlignHCenter; text: stat.modelData[0]; font.pixelSize: 15; color: Config.dim }
                    Text { Layout.alignment: Qt.AlignHCenter; text: stat.modelData[1]; color: Config.fg; font.family: Config.textFont; font.pixelSize: 12; font.bold: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: stat.modelData[2]; color: Config.dim; font.family: Config.textFont; font.pixelSize: 8 }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Config.outline }

        // --- forecast ---
        Repeater {
            model: Weather.forecast
            delegate: RowLayout {
                id: fc
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                Text { Layout.preferredWidth: 42; text: fc.modelData.label; color: Config.fg; font.family: Config.textFont; font.pixelSize: 11 }
                MatIcon { text: fc.modelData.icon; font.pixelSize: 16; color: Config.dim }
                Item { Layout.fillWidth: true }
                Text { text: fc.modelData.maxC + "°"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 11; font.bold: true }
                Text { text: fc.modelData.minC + "°"; color: Config.dim; font.family: Config.textFont; font.pixelSize: 11 }
            }
        }

        Item { Layout.fillHeight: true }

        // --- change city ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: 8
            color: Config.surface
            border.width: cityInput.activeFocus ? 1 : 0
            border.color: Config.accent
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 8
                spacing: 6
                MatIcon { text: "location_on"; font.pixelSize: 14; color: Config.dim }
                TextInput {
                    id: cityInput
                    Layout.fillWidth: true
                    color: Config.fg; font.family: Config.textFont; font.pixelSize: 11
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    onAccepted: { if (text.trim()) { Weather.setCity(text.trim()); text = ""; focus = false; } }
                    Text {
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        visible: !cityInput.text && !cityInput.activeFocus
                        text: "change city…"; color: Config.dim; font: cityInput.font
                    }
                }
            }
        }
    }
}
