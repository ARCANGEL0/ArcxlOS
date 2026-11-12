import QtQuick
import "../../components"
import "../../"
Item {
    id: root
    property real localScale: 1.0

    function resetScroll() { flick.contentY = 0; flick.returnToBounds() }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.height + Math.round(40 * localScale)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentCol
            width: parent.width
            spacing: Math.round(32 * localScale)

            SettingsGroup {
                localScale: root.localScale
                title: "Behavior"
                description: "How the top island reacts to the pointer."

                ToggleButton {
                    localScale: root.localScale
                    text: "Expand on Hover"
                    description: "Grow the island into the full clock or media player while hovered."
                    checked: PrefsService.islandHoverExpand
                    onCheckedChanged: {
                        if (checked !== PrefsService.islandHoverExpand) {
                            PrefsService.islandHoverExpand = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
                SettingsDivider { localScale: root.localScale }
                SettingsButton {
                    localScale: root.localScale
                    text: "Motion Style"
                    description: "Feel of the island's size morph: Liquid wobbles and settles, Snappy is quick and firm, Calm is slow and soft."
                    inputType: "options"
                    options: ["Liquid", "Snappy", "Calm"]
                    selectedOption: PrefsService.islandMotion
                    buttonText: selectedOption
                    onOptionSelected: function(opt) {
                        PrefsService.islandMotion = opt
                        PrefsService.saveConfig()
                    }
                }
            }

            SettingsGroup {
                localScale: root.localScale
                title: "Idle Width"
                description: "Island width when nothing is playing."

                SettingsButton {
                    localScale: root.localScale
                    text: "Small · Normal · Large"
                    description: "Idle island width."
                    inputType: "options"
                    options: ["Small", "Normal", "Large"]
                    selectedOption: {
                        var w = PrefsService.islandIdleWidth
                        if (w === "small") return "Small"
                        if (w === "large") return "Large"
                        return "Normal"
                    }
                    buttonText: selectedOption
                    onOptionSelected: function(opt) {
                        PrefsService.islandIdleWidth = { "Small": "small", "Normal": "normal", "Large": "large" }[opt]
                        PrefsService.saveConfig()
                    }
                }
                SettingsDivider { localScale: root.localScale }
                SettingsButton {
                    localScale: root.localScale
                    text: "Small · Normal · Large"
                    description: "Idle clock size."
                    inputType: "options"
                    options: ["Small", "Normal", "Large"]
                    selectedOption: {
                        var s = PrefsService.islandIdleClockSize
                        if (s === "small") return "Small"
                        if (s === "large") return "Large"
                        return "Normal"
                    }
                    buttonText: selectedOption
                    onOptionSelected: function(opt) {
                        PrefsService.islandIdleClockSize = { "Small": "small", "Normal": "normal", "Large": "large" }[opt]
                        PrefsService.saveConfig()
                    }
                }
                SettingsDivider { localScale: root.localScale }
                ToggleButton {
                    localScale: root.localScale
                    text: "Show Date on Idle"
                    description: "Show the date line under the clock when idle."
                    checked: PrefsService.islandIdleShowDate
                    onCheckedChanged: {
                        if (checked !== PrefsService.islandIdleShowDate) {
                            PrefsService.islandIdleShowDate = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
            }

            SettingsGroup {
                localScale: root.localScale
                title: "Expanded Clock"
                description: "Clock size when the island expands."

                SettingsButton {
                    localScale: root.localScale
                    text: "Small · Normal · Large"
                    description: "Expanded island clock size."
                    inputType: "options"
                    options: ["Small", "Normal", "Large"]
                    selectedOption: {
                        var s = PrefsService.islandClockSize
                        if (s === "small") return "Small"
                        if (s === "large") return "Large"
                        return "Normal"
                    }
                    buttonText: selectedOption
                    onOptionSelected: function(opt) {
                        PrefsService.islandClockSize = { "Small": "small", "Normal": "normal", "Large": "large" }[opt]
                        PrefsService.saveConfig()
                    }
                }
            }

            SettingsGroup {
                localScale: root.localScale
                title: "Clock"
                description: "What the expanded clock shows."

                ToggleButton {
                    localScale: root.localScale
                    text: "Use 24-Hour Time"
                    description: "Switch clock displays from 12h (AM/PM) to 24h format."
                    checked: PrefsService.use24HourTime
                    onCheckedChanged: {
                        if (checked !== PrefsService.use24HourTime) {
                            PrefsService.use24HourTime = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
                SettingsDivider { localScale: root.localScale }
                ToggleButton {
                    localScale: root.localScale
                    text: "Show Seconds"
                    description: "Show live seconds next to the time when the island is expanded."
                    checked: PrefsService.islandShowSeconds
                    onCheckedChanged: {
                        if (checked !== PrefsService.islandShowSeconds) {
                            PrefsService.islandShowSeconds = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
                SettingsDivider { localScale: root.localScale }
                ToggleButton {
                    localScale: root.localScale
                    text: "Show Week & Day Number"
                    description: "Show the ISO week and day of the year under the date."
                    checked: PrefsService.islandShowWeek
                    onCheckedChanged: {
                        if (checked !== PrefsService.islandShowWeek) {
                            PrefsService.islandShowWeek = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
            }

            SettingsGroup {
                localScale: root.localScale
                title: "Media"
                description: "Island behavior while audio is loaded."

                ToggleButton {
                    localScale: root.localScale
                    text: "Audio Visualizer"
                    description: "Show cava bars under the clock while a track is playing or paused."
                    checked: PrefsService.enableVisualiser
                    onCheckedChanged: {
                        if (checked !== PrefsService.enableVisualiser) {
                            PrefsService.enableVisualiser = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
            }
        }
    }
}
