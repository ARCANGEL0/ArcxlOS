//@ pragma UseQApplication

/*
 * ArchangelOS shell — a mesh of two shells, run as one process:
 *
 *   ArcShell   Copyright (C) 2026 arcxlo (ArchangelOS), AGPL-3.0
 *                 src/  — the morphing frame: top-centre island, top-right
 *                 panel, side and bottom notches (wallpaper picker, clipboard).
 *   arcshell  Copyright (c) 2026 arcxlo, MIT
 *                 ns/   — the vertical left bar, its popouts and the launcher.
 *
 * The combined work is distributed under the GNU Affero General Public
 * License v3 or later; see LICENSE (and ns/LICENSE for arcshell's terms).
 */

import QtQuick
import Quickshell
import Quickshell.Io
import "src/windows"
import qs.ns.modules as NS
import qs.ns.services as NSS
import qs.ns as NSRoot
import "src" as Frame
import "axs" as AXS

ShellRoot {
    // arcshell's frame goes first, so it stacks underneath: ArcShell's surface (which
    // also covers the bar's column) draws the one silhouette — bar, workspace tab, island,
    // notches — over it, and only arcshell's bulges (launcher, bar popouts) show through.
    Variants { model: Quickshell.screens; NS.Frame {} }

    // ArcShell: frame, notches and their panels.
    ShellHost {}

    // arcshell: the left bar's widgets and the launcher, above both frames.
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
