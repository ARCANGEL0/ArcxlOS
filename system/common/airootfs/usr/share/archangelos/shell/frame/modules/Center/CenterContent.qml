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
import QtQuick.Effects
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"
import "../Right/"
import "../../components"
import "../../components"
import "../../components"

// CenterContent — scrollable dynamic island carousel.
//
// Active item order:
//   "title"     — always present (default)
//   "music"     — MPRIS player present
//   "timer"     — ClockState.timerRunning
//   "stopwatch" — ClockState.swRunning
//
// CenterNotchMonitor (internal QtObject) watches ClockState and
// handles urgent transitions:
//   • timer <= 30s remaining → force-scroll to timer, text blinks red
//   • stopwatch active → appears in carousel, scrolls if on title
//
// Cava bars: single Rectangle per bar, anchors.centerIn — grows
// symmetrically. No center rounding artefact. 5px wide.

Item {
	id: root

	property real localScale: 1.0
	// ArchangelOS: the clock rides at the island's head, beside the carousel (moved here from
	// the top-right panel), so the island is that much wider.
	// ArchangelOS: when a track plays, the island carries the media controls under a small clock
	// only while a track is loaded (playing or paused); stopped / no player = plain clock
	readonly property bool mediaUp: MediaService.activePlayer !== null
		&& (MediaService.activePlayer.playbackState === MprisPlaybackState.Playing
		 || MediaService.activePlayer.playbackState === MprisPlaybackState.Paused)
	property bool notchHovered: false
	readonly property bool showMedia: mediaUp && notchHovered
	readonly property bool onClock: (root._items[root._carouselIndex] ?? "clock") === "clock"
	readonly property string mode: !onClock ? "carousel"
		: mediaUp ? (expand ? "mediaHover" : "media")
		: (expand ? "clockHover" : "clock")
	readonly property bool expand: notchHovered && PrefsService.islandHoverExpand
	readonly property int idleClockW: PrefsService.islandIdleClockSize === "small" ? 24 : PrefsService.islandIdleClockSize === "large" ? 40 : 30
	readonly property int idleWidth: PrefsService.islandIdleWidth === "small" ? 156 : PrefsService.islandIdleWidth === "large" ? 240 : 200
	readonly property int clockSize: PrefsService.islandClockSize === "small" ? 22 : PrefsService.islandClockSize === "large" ? 40 : 28
	readonly property int islandWidth: Math.round(({ clock: idleWidth, clockHover: 300, media: 240, mediaHover: 450, carousel: Theme.cNotchMinWidth })[mode] * localScale)
	readonly property int idleClockH: PrefsService.islandIdleClockSize === "small" ? 34 : PrefsService.islandIdleClockSize === "large" ? 52 : 44
	readonly property int islandHeight: Math.round(({ clock: idleClockH, clockHover: 96, media: Theme.notchHeight, mediaHover: 148, carousel: Theme.notchHeight })[mode] * localScale)
	width: islandWidth
	implicitWidth: islandWidth
	height: islandHeight
	Behavior on width { Liquid {} }
	Behavior on height { Liquid {} }

	property var now: new Date()
	Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
	readonly property string timeFormat: PrefsService.use24HourTime ? "hh:mm" : "h:mm"
	readonly property string timeText: Qt.formatDateTime(root.now, root.timeFormat)
	readonly property int weekNumber: {
		const d = new Date(Date.UTC(root.now.getFullYear(), root.now.getMonth(), root.now.getDate()))
		const day = d.getUTCDay() || 7
		d.setUTCDate(d.getUTCDate() + 4 - day)
		const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
		return Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
	}
	readonly property int dayOfYear: Math.floor((new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate()) - new Date(root.now.getFullYear(), 0, 0)) / 86400000)

	// feed the notch visualiser whenever media is on the island
	Binding {
		target: CavaService; property: "notchMusicVisible"
		value: root.mediaUp && PrefsService.enableVisualiser
	}

	// ── Required notch width for the current carousel item ────────────────────
	// TopBar.cWidth reads this so the notch always matches what is visible,
	// even if the user scrolls away from record_active while recording.
	readonly property int fw: Math.round(Theme.cornerRadius * localScale)
	// ── MPRIS (via MediaService) ─────────────────────────────────────────────
	readonly property var    player:    MediaService.activePlayer
	readonly property bool   isPlaying: MediaService.isPlaying
	readonly property string artUrl:    MediaService.artUrl

	property string activeTitle: "Desktop"

	// ── App name helper ───────────────────────────────────────────────────────    
	// 2. Process to fetch the initialTitle
	property var _titleProc: Process {
		command: ["hyprctl", "activewindow", "-j"]
		running: false

		stdout: StdioCollector {
			id: titleOut
		}

		onExited: function(exitCode, exitStatus) {

			var out = titleOut.text.trim()            
			// Check for empty, Invalid, or empty JSON object
			if (exitCode !== 0 || out === "" || out === "Invalid" || out === "{}") {
				root.activeTitle = "Desktop"
				return
			}

			try {
				// Parse the JSON natively in Quickshell
				var data = JSON.parse(out)
				var title = data.initialTitle || ""

				if (title !== "") {
					// Capitalize the first letter (e.g., "kitty" -> "Kitty")
					var finalTitle = title.charAt(0).toUpperCase() + title.slice(1)
					root.activeTitle = finalTitle
				} else {
					root.activeTitle = "Desktop"
				}
			} catch(e) {
				root.activeTitle = "Desktop"
			}
		}
	}

	Connections{
		target: Hyprland
		// 3. Your Raw Event Monitor
		function onRawEvent(event) {
			// 3. Trigger title fetch on any window/workspace focus change
			var titleTriggers = ["workspace", "activewindow", "activespecial", "destroyworkspace", "closewindow", "changefloatingmode"]

			if (titleTriggers.includes(event.name)) {
				_titleProc.running = false
				_titleProc.running = true
			}
		}
	}

	// ── Dynamic item list ─────────────────────────────────────────────────────
	property var  _items:         ["clock"]
	property int  _carouselIndex: 0
    on_CarouselIndexChanged: {
    }
	readonly property real _itemStride: Math.round(45 * localScale)  // 30px height + 15px spacing

	function _rebuildItems(autoScrollType) {
		var currentType = (_items.length > _carouselIndex)
		? _items[_carouselIndex] : "clock"

		var list = ["clock"]
		if (ClockState.timerStarted)                   list.push("timer")
		if (ClockState.swStarted)                      list.push("stopwatch")
		if (ShellState.screenRecord && !ScreenRecService.recording) list.push("record_setup")
		if (ScreenRecService.recording)           list.push("record_active")

		root._items = list

		var idx = list.indexOf(currentType)
		if (idx < 0) idx = 0

		if (autoScrollType) {
			var nIdx = list.indexOf(autoScrollType)
			if (nIdx >= 0) {
				// Screen rec always takes priority — scroll regardless of where we are.
				// Other items only auto-scroll when coming from "title".
				var isScreenRec = (autoScrollType === "record_setup" ||
				autoScrollType === "record_active")
				if (isScreenRec || currentType === "title")
				idx = nIdx
			}
		}

		root._carouselIndex = idx
		statusList.contentY = idx * root._itemStride

	}

	// Force-scroll to a specific type regardless of where the user is
	function _forceScrollTo(type) {
		var idx = root._items.indexOf(type)
		if (idx < 0) return
		root._carouselIndex = idx
		statusList.contentY = idx * root._itemStride
	}

	onPlayerChanged: _rebuildItems(player !== null ? "music" : null)

	Connections {
		target: CavaService
		function onAudioActiveChanged() {
			_rebuildItems(CavaService.audioActive ? "music" : null)
		}
	}

	Connections {
		target: PrefsService
		function onEnableVisualiserChanged() {
			_rebuildItems(null)
		}
	}

	// ── State monitor — timer urgency + carousel transitions ─────────────────
	readonly property bool timerUrgent:
	ClockState.timerRunning && ClockState.timerLeft <= 30 && ClockState.timerLeft > 0

	Connections {
		target: ClockState

		function onTimerRunningChanged() {
			root._rebuildItems(ClockState.timerRunning ? "timer" : null)
		}

		function onSwStartedChanged() {
			root._rebuildItems(ClockState.swStarted ? "stopwatch" : null)
			root._forceScrollTo("stopwatch")
		}

		function onTimerLeftChanged() {
			if (ClockState.timerRunning && ClockState.timerLeft === 30 || ClockState.timerRunning && ClockState.timerLeft === 10)
			root._forceScrollTo("timer")
		}
		
		function onTimerStartedChanged() {
			root._rebuildItems(ClockState.timerStarted ? "timer" : null)
			root._forceScrollTo("timer")
		}
	}

	Connections {
		target: ShellState
		function onScreenRecordChanged() {
			if (ShellState.screenRecord && !ScreenRecService.recording)
			root._rebuildItems("record_setup")
			else if (!ShellState.screenRecord)
			root._rebuildItems(null)
		}
	}

	Connections {
		target: ScreenRecService
		function onRecordingChanged() {
			if (ScreenRecService.recording)
			root._rebuildItems("record_active")
			else
			root._rebuildItems(null)
		}
	}

	// ── Scroll debounce ───────────────────────────────────────────────────────
	property bool _scrollBusy: false
	Timer {
		id: scrollCooldown
		interval: 250
		onTriggered: root._scrollBusy = false
	}

	// ── Cava — shared via CavaService singleton ─────────────────────────────
	readonly property int _cavaBars: CavaService.barCount
	readonly property var _bars:     CavaService.bars

	component Liquid: SpringAnimation {
		spring: PrefsService.islandMotion === "Snappy" ? 11 : PrefsService.islandMotion === "Calm" ? 3.5 : 7
		damping: PrefsService.islandMotion === "Snappy" ? 0.75 : PrefsService.islandMotion === "Calm" ? 0.55 : 0.42
		epsilon: 0.3
	}

	component Reveal: SequentialAnimation {
		property bool shown: false
		property int delay: 0
		PauseAnimation { duration: shown ? delay : 0 }
		NumberAnimation { duration: shown ? 200 : 90; easing.type: Easing.OutCubic }
	}

	component CavaStrip: Item {
		id: strip
		property int count: 32
		readonly property real barWidth: Math.max(2, Math.min(Math.round(3 * root.localScale), strip.width / strip.count * 0.6))
		Row {
			anchors.fill: parent
			spacing: Math.max(1, (strip.width - strip.count * strip.barWidth) / Math.max(1, strip.count - 1))
			Repeater {
				model: strip.count
				delegate: Item {
					required property int index
					readonly property int amp: MediaService.isPlaying
						? (root._bars[Math.floor(index * root._cavaBars / strip.count)] ?? 0)
						: 0
					width: strip.barWidth
					height: strip.height
					Rectangle {
						anchors.centerIn: parent
						width: strip.barWidth
						height: Math.max(2, (parent.amp / 100.0) * strip.height)
						radius: width / 2
						color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, MediaService.isPlaying ? 0.35 + (parent.amp / 100.0) * 0.65 : 0.4)
						Behavior on height { NumberAnimation { duration: 90 } }
					}
				}
			}
		}
	}

	// ── Carousel (clock by default; music / timer / recording scroll in) ───────
	Item {
		anchors.fill: parent

		opacity: Popups.dashboardOpen ? 0 : 1
		visible: opacity > 0
		Behavior on opacity { NumberAnimation { duration: Anim.mediumFast} }

		// ── Click to toggle dashboard (Bottom of Z-order to not block buttons) ─────
		MouseArea {
			anchors.top: parent.top
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.topMargin: Math.round(-1 * localScale)
			width: parent.width
			height: Math.round((Theme.notchHeight + 3) * localScale)
			
			onClicked: {
				if (ShellState.screenRecord && !ScreenRecService.recording) {
					var pos = root.mapToItem(null, 0, 0)
					ScreenRecService.popupTargetX = pos.x
					ScreenRecService.popupTargetWidth = root.width
					ScreenRecService.optionsExpanded = !ScreenRecService.optionsExpanded
					return
				}
				if (Popups.dashboardOpen && Popups.dashboardAllowHover) {
					Popups.dashboardPinned = !Popups.dashboardPinned
					return
				}
				var next = !Popups.dashboardOpen
				Popups.closeAll()
				SurfaceState.toggle("top", "dashboard")
				if (next) Popups.dashboardPinned = true
			}
		}

		WheelHandler {
			acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
			onWheel: function(event) {
				// Block scroll only during setup (not during active recording)
				if (ShellState.screenRecord && !ScreenRecService.recording) return
				if (root._scrollBusy) return
				root._scrollBusy = true
				scrollCooldown.restart()

				var maxIdx = root._items.length - 1
				if (event.angleDelta.y < 0)
				root._carouselIndex = Math.min(maxIdx, root._carouselIndex + 1)
				else
				root._carouselIndex = Math.max(0, root._carouselIndex - 1)

				statusList.contentY = root._carouselIndex * root._itemStride
			}
		}

		ListView {
			id: statusList
			anchors.fill: parent
			orientation:  ListView.Vertical
			spacing:      Math.round(15 * localScale)
			clip:         true
			snapMode:     ListView.SnapOneItem
			interactive:  false

			Behavior on contentY {
				NumberAnimation { duration: Anim.mediumSlow; easing.type: Anim.outCubic; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod}
			}

			model: root._items

			delegate: Item {
				required property string modelData
				required property int    index

				width:  statusList.width
				height: statusList.height

				Item {
					id: face
					anchors.fill: parent
					visible: modelData === "clock"

					readonly property real u: root.localScale
					readonly property real tw: root.islandWidth
					readonly property real th: root.islandHeight

					Item {
						id: plain
						anchors.fill: parent
						visible: !root.mediaUp
						readonly property bool open: root.mode === "clockHover"
						readonly property real idleScale: 0.7
						readonly property real stackH: pTime.implicitHeight + pDate.implicitHeight + 3 * face.u + (PrefsService.islandShowWeek ? pWeek.implicitHeight + 3 * face.u : 0)
						readonly property real topY: (face.th - stackH) / 2

						Text {
							id: pTime
							text: root.timeText
							color: Theme.text
							font.pixelSize: plain.open ? Math.round(root.clockSize * face.u) : Math.round(root.idleClockW * face.u)
							font.bold: true
							transformOrigin: Item.TopLeft
							scale: plain.open ? 1 : plain.idleScale
							x: plain.open ? (face.tw - pTime.implicitWidth - (PrefsService.islandShowSeconds ? pSec.implicitWidth + 3 * face.u : 0)) / 2
							              : (face.tw - pTime.implicitWidth * plain.idleScale) / 2
							y: plain.open ? plain.topY : (face.th - pTime.implicitHeight * plain.idleScale) / 2
							Behavior on x { Liquid {} }
							Behavior on y { Liquid {} }
							Behavior on scale { Liquid {} }
						}
						Text {
							id: pSec
							text: Qt.formatDateTime(root.now, ":ss") + (PrefsService.use24HourTime ? "" : Qt.formatDateTime(root.now, " AP"))
							color: Theme.active
							font.pixelSize: Math.round(14 * face.u)
							font.bold: true
							x: pTime.x + pTime.implicitWidth * pTime.scale + 3 * face.u
							y: pTime.y + pTime.baselineOffset * pTime.scale - pSec.baselineOffset
							opacity: plain.open && PrefsService.islandShowSeconds ? 1 : 0
							Behavior on opacity { Reveal { shown: plain.open; delay: 40 } }
						}
						Text {
							id: pDate
							text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
							color: Theme.subtext
							font.pixelSize: Math.round(13 * face.u)
							font.bold: true
							x: (face.tw - implicitWidth) / 2
							y: plain.topY + pTime.implicitHeight + 3 * face.u + (plain.open ? 0 : -10 * face.u)
							opacity: plain.open ? 1 : (PrefsService.islandIdleShowDate ? 1 : 0)
							Behavior on x { Liquid {} }
							Behavior on y { Liquid {} }
							Behavior on opacity { Reveal { shown: plain.open; delay: 60 } }
						}
						Text {
							id: pWeek
							text: "Week " + root.weekNumber + "  ·  Day " + root.dayOfYear
							color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.6)
							font.pixelSize: Math.round(11 * face.u)
							x: (face.tw - implicitWidth) / 2
							y: pDate.y + pDate.implicitHeight + 3 * face.u
							opacity: plain.open && PrefsService.islandShowWeek ? 1 : 0
							Behavior on x { Liquid {} }
							Behavior on opacity { Reveal { shown: plain.open; delay: 40 } }
						}
					}

					Item {
						id: media
						anchors.fill: parent
						visible: root.mediaUp
						readonly property bool open: root.mode === "mediaHover"
						readonly property real idleScale: 0.5
						readonly property real artSize: 116 * face.u
						readonly property real pad: 16 * face.u
						readonly property real colLeft: pad + artSize + 18 * face.u
						readonly property real colWidth: face.tw - colLeft - 20 * face.u
						readonly property real colCenter: colLeft + colWidth / 2
						readonly property real barsOpenH: 24 * face.u
						readonly property real ctrlH: 30 * face.u
						readonly property real gap: 10 * face.u
						readonly property real openTop: (face.th - (mTime.implicitHeight + barsOpenH + ctrlH + gap * 2)) / 2
						readonly property real idleBarsH: 6 * face.u
						readonly property real idleTop: (face.th - (mTime.implicitHeight * idleScale + 3 * face.u + idleBarsH)) / 2

						Item {
							id: art
							x: media.pad
							y: media.pad
							width: media.artSize
							height: media.artSize
							transformOrigin: Item.TopLeft
							scale: media.open ? 1 : 0.35
							opacity: media.open ? 1 : 0
							Behavior on scale { Liquid {} }
							Behavior on opacity { Reveal { shown: media.open; delay: 40 } }

							Rectangle {
								anchors.fill: parent
								radius: Math.round(16 * face.u)
								color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
								visible: root.artUrl === ""
								Text {
									anchors.centerIn: parent
									text: "♪"
									font.pixelSize: Math.round(34 * face.u)
									color: Theme.active
								}
							}
							Rectangle {
								id: artMaskBig
								anchors.fill: parent
								radius: Math.round(16 * face.u)
								visible: false
								layer.enabled: true
							}
							Image {
								anchors.fill: parent
								source: root.artUrl
								sourceSize.width: Math.round(media.artSize * 2)
								fillMode: Image.PreserveAspectCrop
								smooth: true
								cache: true
								asynchronous: true
								visible: root.artUrl !== ""
								layer.enabled: true
								layer.effect: MultiEffect {
									maskEnabled: true
									maskSource: artMaskBig
									maskThresholdMin: 0.5
									maskSpreadAtMin: 1.0
								}
							}
							Rectangle {
								anchors.fill: parent
								radius: Math.round(16 * face.u)
								color: "transparent"
								border.width: 1
								border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
							}
						}

						Text {
							id: mTime
							text: root.timeText
							color: Theme.text
							font.pixelSize: Math.round(24 * face.u)
							font.bold: true
							transformOrigin: Item.TopLeft
							scale: media.open ? 1 : media.idleScale
							x: media.open ? media.colCenter - (mTime.implicitWidth + 8 * face.u + mDate.implicitWidth) / 2
							              : (face.tw - mTime.implicitWidth * media.idleScale) / 2
							y: media.open ? media.openTop : media.idleTop
							Behavior on x { Liquid {} }
							Behavior on y { Liquid {} }
							Behavior on scale { Liquid {} }
						}
						Text {
							id: mDate
							text: Qt.formatDateTime(root.now, "ddd, d MMMM")
							color: Theme.subtext
							font.pixelSize: Math.round(13 * face.u)
							font.bold: true
							x: mTime.x + mTime.implicitWidth * mTime.scale + 8 * face.u
							y: mTime.y + mTime.baselineOffset * mTime.scale - mDate.baselineOffset
							opacity: media.open ? 1 : 0
							Behavior on opacity { Reveal { shown: media.open; delay: 50 } }
						}

						CavaStrip {
							count: 40
							x: media.open ? media.colLeft : (face.tw - 176 * face.u) / 2
							y: media.open ? media.openTop + mTime.implicitHeight + media.gap
							              : media.idleTop + mTime.implicitHeight * media.idleScale + 3 * face.u
							width: media.open ? media.colWidth : 176 * face.u
							height: media.open ? media.barsOpenH : media.idleBarsH
							Behavior on x { Liquid {} }
							Behavior on y { Liquid {} }
							Behavior on width { Liquid {} }
							Behavior on height { Liquid {} }
						}

						Row {
							id: controls
							x: media.colCenter - implicitWidth / 2
							y: media.openTop + mTime.implicitHeight + media.barsOpenH + media.gap * 2 + (media.open ? 0 : 16 * face.u)
							height: media.ctrlH
							spacing: Math.round(26 * face.u)
							opacity: media.open ? 1 : 0
							visible: opacity > 0
							Behavior on y { Liquid {} }
							Behavior on opacity { Reveal { shown: media.open; delay: 80 } }
							Repeater {
								model: [
									{ key: "prev", tip: "Previous track" },
									{ key: "play", tip: "Play / pause" },
									{ key: "next", tip: "Next track" }
								]
								delegate: Item {
									required property var modelData
									readonly property bool isPlay: modelData.key === "play"
									width: Math.round((isPlay ? 30 : 22) * face.u)
									height: Math.round(26 * face.u)
									anchors.verticalCenter: parent.verticalCenter
									Rectangle {
										anchors.centerIn: parent
										visible: parent.isPlay
										width: parent.width + Math.round(4 * face.u)
										height: width
										radius: width / 2
										color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, ctrlArea.containsMouse ? 0.32 : 0.18)
										Behavior on color { ColorAnimation { duration: Anim.mediumFast } }
									}
									Text {
										anchors.centerIn: parent
										text: parent.isPlay ? (MediaService.isPlaying ? "󰏤" : "󰐊")
										                    : (parent.modelData.key === "prev" ? "󰒮" : "󰒭")
										color: ctrlArea.containsMouse ? Theme.active : Theme.text
										font.pixelSize: Math.round((parent.isPlay ? 18 : 17) * face.u)
										scale: ctrlArea.pressed ? 0.85 : 1
										Behavior on scale { NumberAnimation { duration: 120 } }
									}
									MouseArea {
										id: ctrlArea
										anchors.fill: parent
										anchors.margins: -Math.round(4 * face.u)
										hoverEnabled: true
										cursorShape: Qt.PointingHandCursor
										onClicked: {
											if (parent.modelData.key === "play") MediaService.toggle()
											else if (parent.modelData.key === "prev") MediaService.prev()
											else MediaService.next()
										}
									}
									Tip {
										text: parent.isPlay ? (MediaService.isPlaying ? "Pause" : "Play") : parent.modelData.tip
										localScale: face.u
									}
									Tip {
										text: parent.isPlay ? (MediaService.isPlaying ? "Pause" : "Play") : parent.modelData.tip
										localScale: face.u
									}
									Tip {
										text: parent.isPlay ? (MediaService.isPlaying ? "Pause" : "Play") : parent.modelData.tip
										localScale: face.u
									}
								}
							}
						}
					}
				}

				// ── Music ──────────────────────────────────────────────────────
				Item {
					anchors.fill: parent
					anchors.leftMargin: root.fw/2
					anchors.rightMargin: root.fw/2
					visible:      modelData === "music"

					readonly property int artSize: Math.round(20 * localScale)
					readonly property int artPad:  Math.round(7 * localScale)

					Item {
						x:    parent.artPad
						anchors.verticalCenter: parent.verticalCenter
						width:  parent.artSize
						height: parent.artSize

						Rectangle {
							anchors.fill:  parent
							radius:        width / 2
							color:         Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
							border.color:  Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.38)
							border.width:  1
							visible:       root.artUrl === ""
							Text {
								anchors.centerIn: parent
								text:           "♪"
								font.pixelSize: Math.round(9 * localScale)
								color:          Theme.active
							}
						}

						Rectangle {
							id:            artMask
							anchors.fill:  parent
							radius:        width / 2
							visible:       false
							layer.enabled: true
						}

						Image {
							anchors.fill:  parent
							source:        root.artUrl
							fillMode:      Image.PreserveAspectCrop
							smooth:        true
							cache:         true
							visible:       root.artUrl !== ""
							layer.enabled: true
							layer.effect: MultiEffect {
								maskEnabled:      true
								maskSource:       artMask
								maskThresholdMin: 0.5
								maskSpreadAtMin:  1.0
							}
						}

						HoverHandler { id: _miniPlayerHov; cursorShape: Qt.PointingHandCursor }
						MouseArea {
							anchors.fill: parent
							onClicked: Popups.miniPlayerOpen = !Popups.miniPlayerOpen
						}
					}

					Item {
						id: barsArea
						visible: PrefsService.enableVisualiser
						anchors {
							left:        parent.left
							leftMargin:  parent.artPad + parent.artSize + Math.round(5 * localScale)
							right:       parent.right
							rightMargin: Math.round(5 * localScale)
							top:         parent.top
							bottom:      parent.bottom
						}

						readonly property real _barW:       Math.round(5 * localScale)
						readonly property real _barSpacing: Math.max(
							1,
							(width - _barW * root._cavaBars) / Math.max(1, root._cavaBars - 1))
						readonly property real _maxBarH:    height / 2

						Row {
							anchors.fill: parent
							spacing:      barsArea._barSpacing

							Repeater {
								model: root._bars
								delegate: Item {
									required property int modelData
									width:  barsArea._barW
									height: barsArea.height
									readonly property real _amp: modelData / 100.0
									Rectangle {
										anchors.centerIn: parent
										width:  barsArea._barW
										height: Math.max(2, _amp * barsArea._maxBarH * 2)
										radius: width / 2
										color:  Qt.rgba(
											Theme.active.r, Theme.active.g, Theme.active.b,
											0.28 + _amp * 0.72)
									}
								}
							}
						}
					}
				}

				// ── Timer ──────────────────────────────────────────────────────
				Item {
					anchors.fill: parent
					visible:      modelData === "timer"

					Text {
						anchors {
							left:           parent.left
							leftMargin:     root.fw
							verticalCenter: parent.verticalCenter
						}
						text:           "󰔟"
						font.pixelSize: Math.round(16 * localScale)
						color:          root.timerUrgent ? "#ff5555" : Theme.active
						Behavior on color { ColorAnimation { duration: Anim.normal} }
					}

					Text {
						id: timerText
						anchors {
							left:           parent.left
							leftMargin:     Math.round(8 * localScale)
							right:          parent.right
							rightMargin:    Math.round(8 * localScale)
							verticalCenter: parent.verticalCenter
						}
						text:           ClockState.timerDisplay
						font.pixelSize: Math.round(15 * localScale)
						font.weight:    Font.Bold
						font.family:    "JetFrames Mono"
						horizontalAlignment: Text.AlignHCenter
						color:          root.timerUrgent ? "#ff5555" : Theme.text
						Behavior on color { ColorAnimation { duration: Anim.normal} }

						SequentialAnimation on opacity {
							id: timerBlink
							running:  root.timerUrgent
							loops:    Animation.Infinite
							NumberAnimation { to: 0.25; duration: Anim.verySlow; easing.type: Anim.inOutSine}
							NumberAnimation { to: 1.0;  duration: Anim.verySlow; easing.type: Anim.inOutSine}
						}

						Connections {
							target: timerBlink
							function onRunningChanged() {
								if (!timerBlink.running) timerText.opacity = 1.0
							}
						}
					}

					Row{
						anchors {
							right:          parent.right
							rightMargin:    root.fw
							verticalCenter: parent.verticalCenter
						}
						spacing: root.fw

						Text {
							anchors.verticalCenter: parent.verticalCenter
							text:           ClockState.timerRunning ? "󱫟" : "󱫡"
							font.pixelSize: Math.round(16 * localScale)
							color:          _timerPauseHov.hovered ? Theme.active : Theme.text
							HoverHandler { id: _timerPauseHov }
							MouseArea { 
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								onClicked: ClockState.timerRunning = !ClockState.timerRunning
							}
						}
						Text {
							anchors.verticalCenter: parent.verticalCenter
							text:           "󱫥"
							font.pixelSize: Math.round(16 * localScale)
							color:          _timerResetHov.hovered ? Theme.active : Theme.text
							HoverHandler { id: _timerResetHov; cursorShape: Qt.PointingHandCursor }
							MouseArea { 
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								onClicked: ClockState.requestTimerReset()
							}
						}
					}
				}

				// ── Stopwatch ──────────────────────────────────────────────────
				Item {
					anchors.fill: parent
					visible:      modelData === "stopwatch"

					Text {
						anchors {
							left:           parent.left
							leftMargin:     root.fw
							verticalCenter: parent.verticalCenter
						}
						text:           ""
						font.pixelSize: Math.round(16 * localScale)
						color:          Theme.active
					}

					Text {
						anchors {
							left:           parent.left
							leftMargin:     Math.round(8 * localScale)
							right:          parent.right
							rightMargin:    Math.round(8 * localScale)
							verticalCenter: parent.verticalCenter
						}
						text:           ClockState.swDisplay
						font.pixelSize: Math.round(15 * localScale)
						font.weight:    Font.Bold
						font.family:    "JetFrames Mono"
						horizontalAlignment: Text.AlignHCenter
						color:          Theme.text
					}

					Row{
						anchors {
							right:          parent.right
							rightMargin:    root.fw
							verticalCenter: parent.verticalCenter
						}
						spacing: root.fw
						
						Text {
							anchors.verticalCenter: parent.verticalCenter
							text:           ClockState.swRunning ? "󱫟" : "󱫡"
							font.pixelSize: Math.round(16 * localScale)
							color:          _pauseHov.hovered ? Theme.active : Theme.text
							HoverHandler { id: _pauseHov }
							MouseArea { 
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								onClicked: ClockState.swRunning = !ClockState.swRunning
							}
						}
						Text {
							anchors.verticalCenter: parent.verticalCenter
							text:           "󱫥"
							font.pixelSize: Math.round(16 * localScale)
							color:          _notchResetHov.hovered ? Theme.active : Theme.text
							HoverHandler { id: _notchResetHov; cursorShape: Qt.PointingHandCursor }
							MouseArea { 
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								onClicked: ClockState.requestStopwatchReset()
							}
						}
					}
				}

				ScreenRecordSetupDelegate { anchors.fill: parent; localScale: root.localScale; fw: root.fw; itemType: modelData }
				ScreenRecordActiveDelegate { anchors.fill: parent; localScale: root.localScale; fw: root.fw; itemType: modelData }

			} // delegate
		}



		HoverHandler {
			onHoveredChanged: {
				Popups.dashboardTriggerHovered = hovered
				if (ShellState.screenRecord && !ScreenRecService.recording && PrefsService.globalHoverMode && PrefsService.hoverDashboard) {
					if (hovered) ScreenRecService.requestExpand()
					else ScreenRecService.scheduleClose()
				}
			}
		}
	}
}

