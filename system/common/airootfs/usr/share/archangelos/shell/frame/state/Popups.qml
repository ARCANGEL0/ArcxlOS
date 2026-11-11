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

pragma Singleton
import QtQuick
import "../"

QtObject {
    property bool _ignoreDefaultTab: false
    property var activeExpandedButton: null

    readonly property bool audioOpen: SurfaceState.activeContent === "audio"
    onAudioOpenChanged: {
        if (!audioOpen) {
            _ignoreDefaultTab = false
            return
        }
        if (!osdOpened && !_ignoreDefaultTab) audioPage = "volume"
    }
    
    readonly property bool networkOpen: SurfaceState.activeContent === "network"
    readonly property bool batteryOpen: SurfaceState.activeContent === "battery"
    readonly property bool notificationsOpen: SurfaceState.activeContent === "notifications"
    readonly property bool archMenuOpen: SurfaceState.activeContent === "archMenu"
    readonly property bool powerOpen:    SurfaceState.activeContent === "power"
    readonly property bool dashboardOpen: SurfaceState.activeContent === "dashboard"
    onDashboardOpenChanged: {
        if (!dashboardOpen && activeExpandedButton) {
            activeExpandedButton.expanded = false
            activeExpandedButton = null
        }
        if (!dashboardOpen) {
            _ignoreDefaultTab = false
        }
        if (dashboardOpen && !_ignoreDefaultTab) {
            let opt = PrefsService.defaultDashboardTab
            if (opt === "System") dashboardPage = "stats"
            else if (opt === "Tasks") dashboardPage = "kanban"
            else if (opt === "Media") dashboardPage = "media"
            else if (opt === "Weather") dashboardPage = "weather"
            else if (opt === "Dev") dashboardPage = "dev"
            else if (opt === "Upkeep") dashboardPage = "maint"
            else if (opt === "Config") dashboardPage = "config"
            else dashboardPage = "home"
        }
    }
    
    readonly property bool wallpaperOpen: SurfaceState.activeContent === "wallpaper"
    property bool notificationToastOpen: false
    readonly property bool quickOpen: SurfaceState.activeContent === "quick"
    readonly property bool clipboardOpen: SurfaceState.activeContent === "clipboard"
    property bool colorPickerActive: false
    property bool miniPlayerOpen: false
    
    property bool audioPinned:         false
    property bool networkPinned:       false
    property bool notificationsPinned: false
    property bool archMenuPinned:      false
    property bool dashboardPinned:     false
    property bool wallpaperPinned:     false
    property bool quickPinned:         false
    property bool clipboardPinned:     false
    property bool powerPinned:          false

    property int    dashboardPageWidth: 900
    property string dashboardPage:      "home"
    property bool   tasksInteractionActive: false

    property bool   isInputFocused: false
    readonly property bool isInputActive: isInputFocused || tasksInteractionActive || colorPickerActive

    property string audioPage: "volume"

    property string networkPage: "wifi"

    property bool archMenuTriggerHovered:      false
    property bool audioTriggerHovered:         false
    property bool networkTriggerHovered:       false
    property bool notificationsTriggerHovered: false
    property bool wallpaperTriggerHovered:     false
    property bool quickTriggerHovered:         false
    property bool rightCenterHovered:          false
    property bool osdOpened:                   false
    property bool dashboardTriggerHovered:     false
    property bool clipboardTriggerHovered:     false
    property bool bottomDockHovered:           false

    property bool audioAllowHover:         PrefsService.globalHoverMode && PrefsService.hoverAudio
    property bool archMenuAllowHover:      PrefsService.globalHoverMode && PrefsService.hoverArchMenu
    property bool wallpaperAllowHover:     PrefsService.globalHoverMode && PrefsService.hoverWallpaper
    property bool clipboardAllowHover:     PrefsService.globalHoverMode && PrefsService.hoverClipboard
    property bool notificationsAllowHover: PrefsService.globalHoverMode && PrefsService.hoverNotifications
    property bool quickAllowHover:         PrefsService.globalHoverMode && PrefsService.hoverQuick
    property bool dashboardAllowHover:     PrefsService.globalHoverMode && PrefsService.hoverDashboard
    property bool networkAllowHover:     PrefsService.globalHoverMode && PrefsService.hoverNetwork

    property int  slideDuration:   Anim.transition
    property int  hoverCloseDelay: PrefsService.hoverCloseDelay
    property int  hoverOpenDelay:  PrefsService.hoverOpenDelay

    property bool   confirmOpen:    false
    property string confirmTitle:   ""
    property string confirmMessage: ""
    property string confirmLabel:   "Confirm"
    property string confirmAction:  ""
    property string confirmCancelLabel: "Cancel"
    property string confirmCancelAction: "close"
    property string confirmGfxMode: ""
    property bool   confirmRunning: false

    function showConfirm(title, message, label, action, gfxMode, cancelLabel, cancelAction) {
        confirmTitle   = title
        confirmMessage = message
        confirmLabel   = label
        confirmAction  = action
        confirmGfxMode = gfxMode ?? ""
        confirmCancelLabel = cancelLabel ?? "Cancel"
        confirmCancelAction = cancelAction ?? "close"
        closeAll()
        confirmOpen    = true
    }

    function cancelConfirm() {
        confirmOpen    = false
        confirmAction  = ""
        confirmGfxMode = ""
    }

    signal actionConfirmed(string action)

    readonly property bool anyOpen: audioOpen || networkOpen || batteryOpen
                                    || notificationsOpen || archMenuOpen
                                    || dashboardOpen || wallpaperOpen || quickOpen
                                    || clipboardOpen

    function closeAll() {
        SurfaceState.close()
        isInputFocused      = false
        miniPlayerOpen      = false
        bottomDockHovered   = false
        audioPinned         = false
        networkPinned       = false
        notificationsPinned = false
        archMenuPinned      = false
        dashboardPinned     = false
        wallpaperPinned     = false
        quickPinned         = false
        clipboardPinned     = false
        powerPinned         = false
    }
}
