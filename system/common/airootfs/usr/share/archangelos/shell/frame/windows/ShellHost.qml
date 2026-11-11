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
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../components"
import "../services"
import Quickshell.Services.Pipewire

Scope {
    id: screenRoot
    property bool splashVisible: true
    onSplashVisibleChanged: if (!splashVisible) {
        ShellState.booted = true
        Quickshell.execDetached(["qs", "-p", Paths.installDir + "/splash", "ipc", "call", "splash", "dismiss"])
    }

    property var _keybinds: KeybindService
    property var _updater:  UpdateService
    property var _ipc:      IpcManager
    property var _migrator: MigrationService
    

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                PrefsService.updateHyprlandBlur()
                WallpaperService.updateBorders()
                ShellState.applyWindowGaps()
                ShellState.applyWindowRounding()
            }
        }
    }

    property bool _isBooting: true
    property bool _bootComplete: false

    Connections {
        target: WallpaperService
        function onWallpaperApplied() {
            if (!_bootComplete) {
                _bootComplete = true
                _isBooting = false
                splashVisible = false
            }
        }
    }

    Timer {
        id: bootGuardTimer
        interval: 400
        running: true
        repeat: false
        onTriggered: {
            if (!_bootComplete) {
                _bootComplete = true
                _isBooting = false
                splashVisible = false
            }
        }
    }

    Timer {
        id: osdCloseTimer
        interval: Math.max(100, Math.min(5000, PrefsService.osdDuration * 1000))
        repeat: false
        onTriggered: {
            if (Popups.osdOpened && SurfaceState.activeContent === "audio"
                    && !Popups.audioPinned && !Popups.audioTriggerHovered && !Popups.rightCenterHovered) {
                SurfaceState.close()
            }
        }
    }

    Connections {
        target: SurfaceState
        function onActiveContentChanged() { if (SurfaceState.activeContent !== "audio") Popups.osdOpened = false }
    }

    function _triggerOsd(page) {
        if (_isBooting || !PrefsService.enableOsd) return;
        const c = SurfaceState.activeContent
        if (c === "audio") {
            if (page) Popups.audioPage = page
            if (Popups.osdOpened) osdCloseTimer.restart()
            return
        }
        if (c === "none" || c === "notifications" || c === "quick") {
            Popups.audioPage = page || "volume"
            Popups.osdOpened = true
            SurfaceState.open("rightCenter", "audio")
            osdCloseTimer.restart()
        }
    }

    Connections {
        target: BrightnessService
        function onExternalBrightnessChanged(val) { _triggerOsd("display") }
    }

    property var _sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    Connections {
        target: _sinkAudio
        ignoreUnknownSignals: true
        function onVolumeChanged() { _triggerOsd("volume") }
        function onMutedChanged() { _triggerOsd("volume") }
    }

    Variants {
        model: Quickshell.screens
        
        delegate: Component {
            Item {
                required property var modelData
                readonly property var screen: modelData
                readonly property real localScale: Math.max(0.75, Math.min(1.5, (screen ? screen.height : 1080.0) / 1080.0))
                visible: !_isBooting

                StrutWindow {
                    screen: modelData;
                    edge: "top";
                    reserveSpace: ShellState.focusMode ? Math.round(Theme.borderWidth * localScale) * 2 : Math.round(40 * localScale) + Math.round(Theme.borderWidth * localScale) * 2
                    Behavior on reserveSpace { NumberAnimation { duration: Anim.transition; easing.type: Anim.globalCurve; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod } }
                }
                StrutWindow { screen: modelData; edge: "bottom"; reserveSpace: Math.round(Theme.borderWidth * localScale) * 2 }
                StrutWindow { screen: modelData; edge: "right"; reserveSpace: Math.round(Theme.borderWidth * localScale) * 2 }

                DynamicSurface {
                    screen: modelData
                }

                ConfirmDialog { screen: modelData }
                UpdatePopup { screen: modelData }
                MigrationOverlay { screen: modelData }
            }
        }
    }
}
