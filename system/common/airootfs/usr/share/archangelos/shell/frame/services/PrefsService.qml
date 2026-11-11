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
import Quickshell
import Quickshell.Io
import "../"

QtObject {
    id: root

    signal loaded()
    property bool _loaded: false

    property string customAvatarPath: ""
    property bool bootFocusMode: false
    property bool islandHoverExpand: true
    property bool islandShowSeconds: true
    property bool islandShowWeek: false
    property string islandMotion: "Liquid"
    property string islandIdleWidth: "small"
    property string islandIdleClockSize: "small"
    property bool islandIdleShowDate: false
    property string islandClockSize: "normal"
    property bool focusSilenceToasts: false
    property bool focusAutoDnd: false
    property bool focusModeHoverExpand: true
    property string defaultDashboardTab: "Home"
    property string defaultAudioTab: "Output"
    property bool use24HourTime: false
    property bool alwaysShowBatteryPercentage: false
    property bool alwaysShowVolumePercentage: false

    property string animStyle: "slide"
    property real animSpeed: 1.0
    property string animCurve: "smooth"

    property bool autoUpdate: true

    property string screenrecCaptureTarget: "region"
    property bool screenrecAudioMic: false
    property bool screenrecAudioSystem: false
    property int screenrecFramerate: 30
    property string screenrecBackend: "wf"
    property string screenrecSaveDir: Quickshell.env("HOME") + "/Videos/screen_recordings"

    property string hotspotSsid: "ArcShell"
    property string hotspotPassword: "changeme1"

    property bool barEnabled: true
    property int borderWidth: 8          // matches arcshell's frame (ns/modules/Frame.qml)
    property int cornerRadius: 20
    property int windowPadding: 16
    property int windowRounding: 12

    property bool globalHoverMode: true
    property bool hoverDashboard: false
    property bool hoverNetwork: false
    property bool hoverAudio: true
    property bool hoverQuick: false
    property bool hoverArchMenu: false
    property bool hoverNotifications: false
    property bool hoverClipboard: false
    property bool hoverWallpaper: false
    
    property int hoverOpenDelay: 150
    property int hoverCloseDelay: 300

    property bool enableOsd: true
    property real osdDuration: 2.5
    property bool enableVisualiser: true

    property bool dynamicThemeOverride: true
    property bool darkMode: true
    property var themePair: ({
        dark:  { bg: "#080808", active: "#C24A52", text: "#ECEAE4", subtext: "#8a8884", border: "#2e2d2b" },
        light: { bg: "#f3f1ec", active: "#b0343e", text: "#1c1b19", subtext: "#6b6964", border: "#d6d2ca" }
    })

    function applyThemeVariant(variant, dark) {
        root.overrideBg       = variant.bg
        root.overrideActive   = variant.active
        root.overrideText     = variant.text
        root.overrideSubtext  = variant.subtext
        root.overrideBorder   = variant.border
        root.overrideIcon     = variant.text
        root.overrideIconFont = variant.active
        root.darkMode         = dark
        root.saveConfig()
    }

    function setDarkMode(dark) {
        if (root.dynamicThemeOverride && root.themePair && root.themePair.dark && root.themePair.light) {
            root.applyThemeVariant(dark ? root.themePair.dark : root.themePair.light, dark)
            return
        }
        root.darkMode = dark
        root.saveConfig()
    }
    property real bgOpacity: 1.0
    property bool bgBlur: false
    onBgBlurChanged: updateHyprlandBlur()
    Component.onCompleted: {
        updateHyprlandBlur()
        var p = ShellState.userDataDir + "/shell_prefs.json"
        _initProcPrefs.command = ["bash", "-c", "mkdir -p \"$(dirname \"" + p + "\")\" && touch \"" + p + "\"" ]
        _initProcPrefs.running = true
    }

    property string overrideBg: "#080808"
    property string overrideBorder: "#2e2d2b"
    property string overrideActive: "#C24A52"
    property string overrideIconFont: "#B9B6AE"
    property string overrideText: "#ECEAE4"
    property string overrideSubtext: "#8a8884"
    property string overrideIcon: "#ECEAE4"

    property string _cfgBuf: ""
    
    property var _configFile: FileView {
        path: ""
        onLoaded: {
            root._parse(text())
        }
    }

    function _parse(raw) {
        if (!raw || raw.trim() === "") {
            root.updateHyprlandBlur()
            root._loaded = true
                root.loaded()
            return
        }
        try {
            var o = JSON.parse(raw)
            if (o.customAvatarPath !== undefined) root.customAvatarPath = o.customAvatarPath
            if (o.bootFocusMode !== undefined) root.bootFocusMode = o.bootFocusMode
            if (o.islandHoverExpand !== undefined) root.islandHoverExpand = o.islandHoverExpand
            if (o.islandShowSeconds !== undefined) root.islandShowSeconds = o.islandShowSeconds
            if (o.islandShowWeek !== undefined) root.islandShowWeek = o.islandShowWeek
            if (o.islandIdleWidth !== undefined) root.islandIdleWidth = o.islandIdleWidth
            if (o.islandIdleClockSize !== undefined) root.islandIdleClockSize = o.islandIdleClockSize
            if (o.islandIdleShowDate !== undefined) root.islandIdleShowDate = o.islandIdleShowDate
            if (o.islandClockSize !== undefined) root.islandClockSize = o.islandClockSize
            if (o.islandIdleWidth !== undefined) root.islandIdleWidth = o.islandIdleWidth
            if (o.islandIdleClockSize !== undefined) root.islandIdleClockSize = o.islandIdleClockSize
            if (o.islandIdleShowDate !== undefined) root.islandIdleShowDate = o.islandIdleShowDate
            if (o.islandClockSize !== undefined) root.islandClockSize = o.islandClockSize
            if (o.islandMotion !== undefined) root.islandMotion = o.islandMotion
            if (o.focusSilenceToasts !== undefined) root.focusSilenceToasts = o.focusSilenceToasts
            if (o.focusAutoDnd !== undefined) root.focusAutoDnd = o.focusAutoDnd
            if (o.focusModeHoverExpand !== undefined) root.focusModeHoverExpand = o.focusModeHoverExpand
            if (o.defaultDashboardTab !== undefined) root.defaultDashboardTab = o.defaultDashboardTab
            if (o.defaultAudioTab !== undefined) root.defaultAudioTab = o.defaultAudioTab
            if (o.use24HourTime !== undefined) root.use24HourTime = o.use24HourTime
            if (o.alwaysShowBatteryPercentage !== undefined) root.alwaysShowBatteryPercentage = o.alwaysShowBatteryPercentage
            if (o.alwaysShowVolumePercentage !== undefined) root.alwaysShowVolumePercentage = o.alwaysShowVolumePercentage

            if (o.animStyle !== undefined) root.animStyle = o.animStyle
            if (o.animSpeed !== undefined) root.animSpeed = o.animSpeed
            if (o.animCurve !== undefined) root.animCurve = o.animCurve
            if (o.autoUpdate !== undefined) root.autoUpdate = o.autoUpdate
            if (o.screenrecCaptureTarget !== undefined) root.screenrecCaptureTarget = o.screenrecCaptureTarget
            if (o.screenrecAudioMic !== undefined) root.screenrecAudioMic = o.screenrecAudioMic
            if (o.screenrecAudioSystem !== undefined) root.screenrecAudioSystem = o.screenrecAudioSystem
            if (o.screenrecFramerate !== undefined) root.screenrecFramerate = o.screenrecFramerate
            if (o.screenrecBackend !== undefined) root.screenrecBackend = o.screenrecBackend
            if (o.screenrecSaveDir !== undefined) root.screenrecSaveDir = o.screenrecSaveDir
            if (o.hotspotSsid !== undefined) root.hotspotSsid = o.hotspotSsid
            if (o.hotspotPassword !== undefined) root.hotspotPassword = o.hotspotPassword

            if (o.barEnabled !== undefined) root.barEnabled = o.barEnabled
            if (o.borderWidth !== undefined) root.borderWidth = o.borderWidth
            if (o.cornerRadius !== undefined) root.cornerRadius = o.cornerRadius
            if (o.windowPadding !== undefined) root.windowPadding = o.windowPadding
            if (o.windowRounding !== undefined) root.windowRounding = o.windowRounding

            if (o.globalHoverMode !== undefined) root.globalHoverMode = o.globalHoverMode
            if (o.hoverDashboard !== undefined) root.hoverDashboard = o.hoverDashboard
            if (o.hoverNetwork !== undefined) root.hoverNetwork = o.hoverNetwork
            if (o.hoverAudio !== undefined) root.hoverAudio = o.hoverAudio
            if (o.hoverQuick !== undefined) root.hoverQuick = o.hoverQuick
            if (o.hoverArchMenu !== undefined) root.hoverArchMenu = o.hoverArchMenu
            if (o.hoverNotifications !== undefined) root.hoverNotifications = o.hoverNotifications
            if (o.hoverClipboard !== undefined) root.hoverClipboard = o.hoverClipboard
            if (o.hoverWallpaper !== undefined) root.hoverWallpaper = o.hoverWallpaper

            if (o.hoverOpenDelay !== undefined) root.hoverOpenDelay = o.hoverOpenDelay
            if (o.hoverCloseDelay !== undefined) root.hoverCloseDelay = o.hoverCloseDelay

            if (o.enableOsd !== undefined) root.enableOsd = o.enableOsd
            if (o.osdDuration !== undefined) root.osdDuration = o.osdDuration
            if (o.enableVisualiser !== undefined) root.enableVisualiser = o.enableVisualiser

            if (o.dynamicThemeOverride !== undefined) root.dynamicThemeOverride = o.dynamicThemeOverride
            if (o.darkMode !== undefined) root.darkMode = o.darkMode
            if (o.themePair !== undefined) root.themePair = o.themePair
            if (o.bgOpacity !== undefined) root.bgOpacity = o.bgOpacity
            if (o.bgBlur !== undefined) root.bgBlur = o.bgBlur
            if (o.overrideBg !== undefined) root.overrideBg = o.overrideBg
            if (o.overrideBorder !== undefined) root.overrideBorder = o.overrideBorder
            if (o.overrideActive !== undefined) root.overrideActive = o.overrideActive
            if (o.overrideIconFont !== undefined) root.overrideIconFont = o.overrideIconFont
            if (o.overrideText !== undefined) root.overrideText = o.overrideText
            if (o.overrideSubtext !== undefined) root.overrideSubtext = o.overrideSubtext
            if (o.overrideIcon !== undefined) root.overrideIcon = o.overrideIcon
        } catch(e) {}
        root.updateHyprlandBlur()
        root._loaded = true
                root.loaded()
    }

        onCustomAvatarPathChanged: if (_loaded) saveConfig()
    onBootFocusModeChanged: if (_loaded) saveConfig()
    onFocusModeHoverExpandChanged: if (_loaded) saveConfig()
    onDefaultDashboardTabChanged: if (_loaded) saveConfig()
    onDefaultAudioTabChanged: if (_loaded) saveConfig()
    onUse24HourTimeChanged: if (_loaded) saveConfig()
    onAlwaysShowBatteryPercentageChanged: if (_loaded) saveConfig()
    onAlwaysShowVolumePercentageChanged: if (_loaded) saveConfig()
    onAnimStyleChanged: if (_loaded) saveConfig()
    onAnimSpeedChanged: if (_loaded) saveConfig()
    onAnimCurveChanged: if (_loaded) saveConfig()
    onAutoUpdateChanged: if (_loaded) saveConfig()
    onScreenrecCaptureTargetChanged: if (_loaded) saveConfig()
    onScreenrecAudioMicChanged: if (_loaded) saveConfig()
    onScreenrecAudioSystemChanged: if (_loaded) saveConfig()
    onScreenrecFramerateChanged: if (_loaded) saveConfig()
    onScreenrecBackendChanged: if (_loaded) saveConfig()
    onScreenrecSaveDirChanged: if (_loaded) saveConfig()
    onHotspotSsidChanged: if (_loaded) saveConfig()
    onHotspotPasswordChanged: if (_loaded) saveConfig()
    onBarEnabledChanged: if (_loaded) saveConfig()
    onBorderWidthChanged: if (_loaded) saveConfig()
    onCornerRadiusChanged: if (_loaded) saveConfig()
    onWindowPaddingChanged: { if (_loaded) saveConfig(); ShellState.applyWindowGaps() }
    onWindowRoundingChanged: { if (_loaded) saveConfig(); ShellState.applyWindowRounding() }
    onGlobalHoverModeChanged: if (_loaded) saveConfig()
    onHoverDashboardChanged: if (_loaded) saveConfig()
    onHoverNetworkChanged: if (_loaded) saveConfig()
    onHoverAudioChanged: if (_loaded) saveConfig()
    onHoverQuickChanged: if (_loaded) saveConfig()
    onHoverArchMenuChanged: if (_loaded) saveConfig()
    onHoverNotificationsChanged: if (_loaded) saveConfig()
    onHoverClipboardChanged: if (_loaded) saveConfig()
    onHoverWallpaperChanged: if (_loaded) saveConfig()
    onHoverOpenDelayChanged: if (_loaded) saveConfig()
    onHoverCloseDelayChanged: if (_loaded) saveConfig()
    onEnableOsdChanged: if (_loaded) saveConfig()
    onOsdDurationChanged: if (_loaded) saveConfig()
    onEnableVisualiserChanged: if (_loaded) saveConfig()
    onDynamicThemeOverrideChanged: if (_loaded) saveConfig()
    onDarkModeChanged: if (_loaded) saveConfig()
    onBgOpacityChanged: { if (bgOpacity >= 0.95 && bgBlur) { bgBlur = false } if (_loaded) saveConfig() }
    onOverrideBgChanged: if (_loaded) saveConfig()
    onOverrideBorderChanged: if (_loaded) saveConfig()
    onOverrideActiveChanged: if (_loaded) saveConfig()
    onOverrideIconFontChanged: if (_loaded) saveConfig()
    onOverrideTextChanged: if (_loaded) saveConfig()
    onOverrideSubtextChanged: if (_loaded) saveConfig()
    onOverrideIconChanged: if (_loaded) saveConfig()

    function saveConfig() {
        var path = ShellState.userDataDir + "/shell_prefs.json"
        var data = JSON.stringify({
            customAvatarPath: root.customAvatarPath,
            bootFocusMode: root.bootFocusMode,
            islandHoverExpand: root.islandHoverExpand,
            islandShowSeconds: root.islandShowSeconds,
            islandShowWeek: root.islandShowWeek,
            islandIdleWidth: root.islandIdleWidth,
            islandIdleClockSize: root.islandIdleClockSize,
            islandIdleShowDate: root.islandIdleShowDate,
            islandClockSize: root.islandClockSize,
            islandIdleWidth: root.islandIdleWidth,
            islandIdleClockSize: root.islandIdleClockSize,
            islandIdleShowDate: root.islandIdleShowDate,
            islandClockSize: root.islandClockSize,
            islandMotion: root.islandMotion,
            focusSilenceToasts: root.focusSilenceToasts,
            focusAutoDnd: root.focusAutoDnd,
            focusModeHoverExpand: root.focusModeHoverExpand,
            defaultDashboardTab: root.defaultDashboardTab,
            defaultAudioTab: root.defaultAudioTab,
            use24HourTime: root.use24HourTime,
            alwaysShowBatteryPercentage: root.alwaysShowBatteryPercentage,
            alwaysShowVolumePercentage: root.alwaysShowVolumePercentage,
            animStyle: root.animStyle,
            animSpeed: root.animSpeed,
            animCurve: root.animCurve,
            autoUpdate: root.autoUpdate,
            screenrecCaptureTarget: root.screenrecCaptureTarget,
            screenrecAudioMic: root.screenrecAudioMic,
            screenrecAudioSystem: root.screenrecAudioSystem,
            screenrecFramerate: root.screenrecFramerate,
            screenrecBackend: root.screenrecBackend,
            screenrecSaveDir: root.screenrecSaveDir,
            hotspotSsid: root.hotspotSsid,
            hotspotPassword: root.hotspotPassword,
            barEnabled: root.barEnabled,
            borderWidth: root.borderWidth,
            cornerRadius: root.cornerRadius,
            windowPadding: root.windowPadding,
            windowRounding: root.windowRounding,
            globalHoverMode: root.globalHoverMode,
            hoverDashboard: root.hoverDashboard,
            hoverNetwork: root.hoverNetwork,
            hoverAudio: root.hoverAudio,
            hoverQuick: root.hoverQuick,
            hoverArchMenu: root.hoverArchMenu,
            hoverNotifications: root.hoverNotifications,
            hoverClipboard: root.hoverClipboard,
            hoverWallpaper: root.hoverWallpaper,
            hoverOpenDelay: root.hoverOpenDelay,
            hoverCloseDelay: root.hoverCloseDelay,
            enableOsd: root.enableOsd,
            osdDuration: root.osdDuration,
            enableVisualiser: root.enableVisualiser,
            dynamicThemeOverride: root.dynamicThemeOverride,
            darkMode: root.darkMode,
            themePair: root.themePair,
            bgOpacity: root.bgOpacity,
            bgBlur: root.bgBlur,
            overrideBg: root.overrideBg,
            overrideBorder: root.overrideBorder,
            overrideActive: root.overrideActive,
            overrideIconFont: root.overrideIconFont,
            overrideText: root.overrideText,
            overrideSubtext: root.overrideSubtext,
            overrideIcon: root.overrideIcon
        })
        _saveProc.command = ["bash", "-c", "mkdir -p \"$(dirname '" + path + "')\" && printf '%s' '" + data.replace(/'/g, "'\\''") + "' > '" + path + "'"]
        _saveProc.running = false
        _saveProc.running = true
    }

    function updateHyprlandBlur() {
        var isLua = ShellState.configProvider === "lua"
        var cmd = root.bgBlur
            ? (isLua ? "hyprctl eval \"hl.layer_rule({ match = { namespace = 'arcshell-frame' }, blur = true, ignore_alpha = 0.1 })\""
                     : "hyprctl keyword layerrule 'unset, arcshell-frame' && hyprctl keyword layerrule 'blur, arcshell-frame' && hyprctl keyword layerrule 'ignorealpha 0.1, arcshell-frame'")
            : (isLua ? "hyprctl eval \"hl.layer_rule({ match = { namespace = 'arcshell-frame' }, blur = false })\""
                     : "hyprctl keyword layerrule 'unset, arcshell-frame'")
        _blurProc.command = ["bash", "-c", "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then " + cmd + "; fi"]
        _blurProc.running = false
        _blurProc.running = true
    }

    property Process _initProcPrefs: Process {

        command: []
        running: false
        onExited: (code) => {
            _configFile.path = ShellState.userDataDir + "/shell_prefs.json"
        }
    }
    property var _saveProc: Process { command: []; running: false }
    property var _blurProc: Process { command: []; running: false }
}
