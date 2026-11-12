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
                title: "Screen Recording"
                description: "Defaults for the island's screen recorder."

                SettingsButton {
                    localScale: root.localScale
                    text: "Capture Target"
                    description: "What a new recording captures by default."
                    inputType: "options"
                    options: ["Screen", "Window", "Region"]
                    selectedOption: PrefsService.screenrecCaptureTarget.charAt(0).toUpperCase() + PrefsService.screenrecCaptureTarget.slice(1)
                    buttonText: selectedOption
                    onOptionSelected: function(opt) {
                        PrefsService.screenrecCaptureTarget = opt.toLowerCase()
                        PrefsService.saveConfig()
                    }
                }
                SettingsDivider { localScale: root.localScale }
                SettingsButton {
                    localScale: root.localScale
                    text: "Frame Rate"
                    description: "Recording frame rate."
                    inputType: "options"
                    options: ["30 FPS", "60 FPS"]
                    selectedOption: PrefsService.screenrecFramerate + " FPS"
                    buttonText: selectedOption
                    onOptionSelected: function(opt) {
                        PrefsService.screenrecFramerate = parseInt(opt)
                        PrefsService.saveConfig()
                    }
                }
                SettingsDivider { localScale: root.localScale }
                SettingsButton {
                    localScale: root.localScale
                    text: "Backend"
                    description: "Recorder used: wf-recorder, gpu-screen-recorder, or wl-screenrec."
                    inputType: "options"
                    options: ["wf-recorder", "gpu-screen-recorder", "wl-screenrec"]
                    selectedOption: ({ wf: "wf-recorder", gsr: "gpu-screen-recorder", wlsr: "wl-screenrec" })[PrefsService.screenrecBackend] ?? "wf-recorder"
                    buttonText: selectedOption
                    onOptionSelected: function(opt) {
                        PrefsService.screenrecBackend = ({ "wf-recorder": "wf", "gpu-screen-recorder": "gsr", "wl-screenrec": "wlsr" })[opt]
                        PrefsService.saveConfig()
                    }
                }
                SettingsDivider { localScale: root.localScale }
                ToggleButton {
                    localScale: root.localScale
                    text: "Record Microphone"
                    description: "Include microphone audio in recordings."
                    checked: PrefsService.screenrecAudioMic
                    onCheckedChanged: {
                        if (checked !== PrefsService.screenrecAudioMic) {
                            PrefsService.screenrecAudioMic = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
                SettingsDivider { localScale: root.localScale }
                ToggleButton {
                    localScale: root.localScale
                    text: "Record System Audio"
                    description: "Include desktop audio in recordings."
                    checked: PrefsService.screenrecAudioSystem
                    onCheckedChanged: {
                        if (checked !== PrefsService.screenrecAudioSystem) {
                            PrefsService.screenrecAudioSystem = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
                SettingsDivider { localScale: root.localScale }
                SettingsButton {
                    localScale: root.localScale
                    text: "Save Directory"
                    description: "Directory path (/home/arcxlo/.cache/axrecover/sb/home/arcxlo/ or absolute) for recordings and snapshots."
                    placeholder: "/home/arcxlo/.cache/axrecover/sb/home/arcxlo/Videos/screen_recordings"
                    inputType: "text"
                    buttonText: inputText !== "" ? inputText : "Browse..."
                    inputText: PrefsService.screenrecSaveDir
                    validateAs: "dir"
                    onInputAccepted: function(txt) {
                        if (txt === "") return
                        PrefsService.screenrecSaveDir = txt
                        PrefsService.saveConfig()
                    }
                }
            }
        }
    }
}
