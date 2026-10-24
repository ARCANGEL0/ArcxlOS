//@ pragma UseQApplication

/*
 * ArcShell — the ArchangelOS desktop shell, run as one process:
 *
 *   frame/ — the morphing surface: top-centre island, top-right panel,
 *            side and bottom notches (wallpaper picker, clipboard).
 *   arc/   — the vertical left bar, its popouts and the launcher.
 *   axs/   — ArchangelOS settings pages.
 *
 * Copyright (C) 2026 arcxlo (ArchangelOS). Distributed under the GNU
 * Affero General Public License v3 or later; see LICENSE.
 */

import QtQuick
import Quickshell
import Quickshell.Io
import "frame/windows"
import qs.arc.modules as NS
import qs.arc.services as NSS
import qs.arc as NSRoot
import "frame" as Frame
import "axs" as AXS

ShellRoot {
    // arc/'s frame layer stacks first, underneath: the morphing surface (which
    // also covers the bar's column) draws the one silhouette — bar, workspace
    // tab, island, notches — over it, and only arc/'s bulges (launcher, bar
    // popouts) show through.
    Variants { model: Quickshell.screens; NS.Frame {} }

    // frame/: the morphing surface, notches and their panels.
    ShellHost {}

    // arc/: the left bar's widgets and the launcher, above the surface.
    Variants { model: Quickshell.screens; NS.Bar {} }
    Variants { model: Quickshell.screens; NS.Launcher {} }

    // ArchangelOS Settings — one window, opened by `archangelos-settings [page]` or the launcher.
    AXS.SettingsWindow {}

    // One accent for both shells: ArcShell's (set from the wallpaper picker's swatches).
    Binding { target: NSRoot.Config; property: "accentOverride"; value: Frame.PrefsService.overrideActive }

    // arcshell's entry points (from its shell.qml), for keybinds:
    //   qs -p /usr/share/archangelos/shell ipc call launcher toggle
    //   qs -p /usr/share/archangelos/shell ipc call bar popout network
    // ArchangelOS Settings: `qs -p /usr/share/archangelos/shell ipc call settings open <page>`
    IpcHandler {
        target: "settings"
        function open(page: string): void { NSS.Shell.openSettings(page) }
        function toggle(): void { NSS.Shell.settingsVisible = !NSS.Shell.settingsVisible }
        function close(): void { NSS.Shell.settingsVisible = false }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { NSS.Shell.launcherVisible = !NSS.Shell.launcherVisible }
        function open(query: string): void { NSS.Shell.openLauncher(query) }
    }
    IpcHandler {
        target: "bar"
        function popout(name: string): void { NSS.Shell.barPopout = name ?? "" }
        function close(): void { NSS.Shell.barPopout = "" }
    }
}
