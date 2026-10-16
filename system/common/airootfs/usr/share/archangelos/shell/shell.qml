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

ShellRoot {
    // ArcShell: frame, notches and their panels.
    ShellHost {}

    // arcshell: the left bar (drawn by its frame surface) and the launcher.
    Variants { model: Quickshell.screens; NS.Frame {} }
    Variants { model: Quickshell.screens; NS.Bar {} }
    Variants { model: Quickshell.screens; NS.Launcher {} }

    // arcshell's entry points (from its shell.qml), for keybinds:
    //   qs -p /usr/share/archangelos/shell ipc call launcher toggle
    //   qs -p /usr/share/archangelos/shell ipc call bar popout network
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
