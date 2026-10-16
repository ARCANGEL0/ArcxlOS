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
import "../../components"
import "../../"

// ArchangelOS: the distro glyph is replaced by the ArchangelOS mark
// (/usr/share/archangelos/logo-mark.svg); the click still opens the menu.
IconBtn {
    id: rootBtn
    text: ""

    Image {
        anchors.centerIn: parent
        source: "file:///usr/share/archangelos/logo-mark.svg"
        sourceSize: Qt.size(Math.round(44 * rootBtn.localScale), Math.round(32 * rootBtn.localScale))
        width: Math.round(20 * rootBtn.localScale)
        height: Math.round(15 * rootBtn.localScale)
        smooth: true
    }

    onClicked: {
        if (!Popups.archMenuOpen) {
            SurfaceState.open("leftCenter", "archMenu")
            Popups.archMenuPinned = true
        } else {
            SurfaceState.close()
        }
    }
}
