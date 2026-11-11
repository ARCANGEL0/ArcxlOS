pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.arc
import qs.arc.components
import "../settings/common"
import qs.arc.services

BarPopout {
    id: pop
    name: "battery"
    implicitWidth: 320
    bodyHeight: batCol.implicitHeight + 24

    onOpened: { PowerMode.error = ""; PowerMode.refresh(); }
    Timer { interval: 4000; repeat: true; running: pop.shown; onTriggered: PowerMode.refresh() }

    ColumnLayout {
        id: batCol
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: 18 + Config.popFillet * 2 - pop.botPad + pop.topPad; leftMargin: 24; rightMargin: 16 }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            MatIcon {
                text: Bat.charging ? "battery_charging_full" : "battery_full"
                font.pixelSize: 30
                color: batColor(Bat.percent)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: Bat.charging ? "Battery, charging" : "Battery"
                    color: Config.fg
                    font.family: Config.textFont
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text: Bat.percent + "%"
                        + (Bat.charging ? "  ·  Charging"
                            : Bat.onBattery ? "  ·  On battery"
                            : "  ·  On mains")
                    color: Config.dim
                    font.family: Config.textFont
                    font.pixelSize: 11
                }
            }
        }

        SectionHeader { first: true; text: "Power mode" }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { id: "performance", label: "PERFORMANCE", icon: "rocket_launch",
                      desc: "Best performance, uses more battery", tone: Config.warning },
                    { id: "balanced",    label: "NEUTRAL",     icon: "bolt",
                      desc: "Balances performance and battery life", tone: Config.success },
                    { id: "saver", label: "POWER SAVING", icon: "eco",
                      desc: "Saves battery, reduces performance", tone: Config.info }
                ]
                Item {
                    id: modeRow
                    Layout.fillWidth: true
                    implicitHeight: 52
                    required property var modelData
                    readonly property bool active: PowerMode.mode === modeRow.modelData.id

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: modeRow.active ? modeRow.modelData.tone : Config.container
                        Behavior on color { ColorAnim {} }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        spacing: 12

                        MatIcon {
                            text: modeRow.modelData.icon
                            font.pixelSize: 18
                            color: modeRow.active ? Config.accentText : Config.fg
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: modeRow.modelData.label
                                color: modeRow.active ? Config.accentText : Config.fg
                                font.family: Config.textFont
                                font.pixelSize: 13
                                font.bold: true
                            }

                            Text {
                                text: modeRow.modelData.desc
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                color: modeRow.active ? Config.accentText : Config.dim
                                font.family: Config.textFont
                                font.pixelSize: 10
                            }
                        }
                    }

                    StateLayer {
                        ovRadius: 10
                        tint: modeRow.active ? Config.accentText : Config.fg
                        onTapped: PowerMode.apply(modeRow.modelData.id)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: PowerMode.pending !== "" ? "Switching power mode…" : PowerMode.error
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: PowerMode.pending !== "" ? Config.dim : Config.error
            font.family: Config.textFont
            font.pixelSize: 10
        }

        ToggleRow {
            first: true; last: true
            text: "Battery saver"
            subtext: "Pause live wallpaper and window previews, flatten the frame, shorten animations and stop background polling while on battery"
            checked: Config.batterySaver
            onToggled: Config.batterySaver = !Config.batterySaver
        }

    }

    function batColor(p) {
        if (p <= 0)   return "#ff4444"
        if (p >= 100) return "#00cc00"
        if (p < 50) {
            var t = p / 50
            return Qt.rgba(1, 0.42 + 0.58 * t, 0.27 * (1 - t), 1)
        }
        var t = (p - 50) / 50
        return Qt.rgba(1 - t, 1, 0, 1)
    }
}
