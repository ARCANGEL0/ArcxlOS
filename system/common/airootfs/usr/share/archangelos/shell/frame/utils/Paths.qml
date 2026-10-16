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

QtObject {
    id: root

    // Environment overrides (priority 1)
    readonly property string envInstallDir: Quickshell.env("ARCSHELL_INSTALL_DIR")
    readonly property string envConfigDir:  Quickshell.env("ARCSHELL_CONFIG_DIR")
    readonly property string envIsNix:      Quickshell.env("ARCSHELL_NIX")

    // Fallback detection (priority 2 & 3)
    readonly property string defaultInstallDir: Quickshell.env("HOME") + "/.local/src/ArcShell"
    readonly property string defaultConfigDir:  Quickshell.env("HOME") + "/.config/ArcShell"

    readonly property string installDir: (envInstallDir && envInstallDir !== "") ? envInstallDir : (Quickshell.shellDir !== "" ? Quickshell.shellDir : defaultInstallDir)
    readonly property string configDir:  (envConfigDir && envConfigDir !== "") ? envConfigDir : defaultConfigDir
    readonly property string userDataDir: configDir + "/src/user_data"

    readonly property bool isNix: envIsNix === "1" || installDir.indexOf("/nix/store") !== -1
}
