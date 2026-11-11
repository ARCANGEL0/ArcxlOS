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
import "../components"
import "../services"
import "../"

Item {
    id: root

    property real localScale: 1.0

    readonly property int popupHeight: Popups.audioPage === "devices"
        ? Math.round(Math.max(130 * root.localScale, Math.min(360 * root.localScale, audioControl.devicesHeight + 20 * root.localScale)))
        : Math.round(252 * root.localScale)
    readonly property int maxWidth: Math.round(280 * root.localScale)

    property real targetWidth: Math.round(({ volume: 184, display: 236, devices: 280 })[Popups.audioPage] * root.localScale) || maxWidth

    readonly property int popupWidth: targetWidth

    onOpacityChanged: if (opacity === 1) forceActiveFocus()
    Keys.onEscapePressed: SurfaceState.close()

    MouseArea {
        anchors.fill: parent
        onClicked: Popups.audioPinned = true
    }

    Item {
        id: slide
        anchors.fill: parent
        clip: true

        AudioControl {
            id: audioControl
            localScale: root.localScale
            fullyOpen: (SurfaceState.activeContent === "audio") && root.opacity === 1

            anchors.fill: parent
        }
    }
}
