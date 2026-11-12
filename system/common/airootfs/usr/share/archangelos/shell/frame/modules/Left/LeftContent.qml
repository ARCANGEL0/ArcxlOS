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
import "../../components"
import "../../../arc/services"
import "../../"

Row {
	property real localScale: 1.0
	height:  parent.height
	spacing: Math.round(5 * localScale)
	// Note: Do NOT add anchors.centerIn: parent here. TopBar handles that.

	// 1. ArchangelOS mark — heads the tab, level with the workspaces, opens the launcher
	Item {
		id: markBtn
		width: Math.round(26 * parent.localScale)
		height: Math.round(20 * parent.localScale)
		anchors.verticalCenter: parent.verticalCenter
		Image {
			anchors.centerIn: parent
			source: "file:///usr/share/archangelos/logo-mark.svg"
			sourceSize: Qt.size(56, 41)
			width: 24; height: 18
			smooth: true
			opacity: markMa.containsMouse ? 1.0 : 0.82
			scale: markMa.pressed ? 0.9 : 1.0
			Behavior on opacity { NumberAnimation { duration: 140 } }
			Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
		}
		MouseArea {
			id: markMa
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: Quickshell.execDetached(["/usr/bin/archangelos-launcher-toggle"])
		}
		Tip { text: "App launcher"; localScale: parent.localScale }
		Tip { text: "App launcher"; localScale: parent.localScale }
	}

	// 2. Workspaces
	Workspaces {
		localScale: parent.localScale
		anchors.verticalCenter: parent.verticalCenter
	}

}


