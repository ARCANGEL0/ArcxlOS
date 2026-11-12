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
                title: "Focus Mode"
                description: "Toggle with SUPER+SHIFT+H. Only the island clock stays on screen."

                ToggleButton {
                    localScale: root.localScale
                    text: "Boot into Focus Mode"
                    description: "Start the shell already in focus mode."
                    checked: PrefsService.bootFocusMode
                    onCheckedChanged: {
                        if (checked !== PrefsService.bootFocusMode) {
                            PrefsService.bootFocusMode = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
                SettingsDivider { localScale: root.localScale }
                ToggleButton {
                    localScale: root.localScale
                    text: "Silence Notification Toasts"
                    description: "Don't pop up notifications while in focus mode; they still collect in the notification list."
                    checked: PrefsService.focusSilenceToasts
                    onCheckedChanged: {
                        if (checked !== PrefsService.focusSilenceToasts) {
                            PrefsService.focusSilenceToasts = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
                SettingsDivider { localScale: root.localScale }
                ToggleButton {
                    localScale: root.localScale
                    text: "Auto Do Not Disturb"
                    description: "Turn on Do Not Disturb when focus mode starts and restore it when focus mode ends."
                    checked: PrefsService.focusAutoDnd
                    onCheckedChanged: {
                        if (checked !== PrefsService.focusAutoDnd) {
                            PrefsService.focusAutoDnd = checked
                            PrefsService.saveConfig()
                        }
                    }
                }
            }
        }
    }
}
