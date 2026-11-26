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
import Quickshell.Io
import "../../"
import "../../components"

// ClockCard - Clock / Timer / Alarm / Stopwatch

StatCard {
    id: root
    padding: 0

    property real localScale: 1.0

    // ── Mode ──────────────────────────────────────────────────────────────────
    property string _mode: "clock"

    // ── Clock ─────────────────────────────────────────────────────────────────
    property string _hm:       "00:00"
    property string _hStr:     "00"
    property string _mStr:     "00"
    property string _sec:      "00"
    property int    _currentH: 0
    property int    _currentM: 0
    property string _amPm:     "AM"

    // ── Timer ─────────────────────────────────────────────────────────────────
    property int  _timerTotal:   10 * 60
    property int  _timerLeft:    10 * 60
    property bool _timerRunning: false
    property bool _timerStarted: false
    property bool _timerFired:   false
    property bool _addTimerOpen: false

    // ── Stopwatch ─────────────────────────────────────────────────────────────
    property int  _swMs:      0
    property bool _swRunning: false
    property bool _swStarted:   false

    // ── Alarms ────────────────────────────────────────────────────────────────
    property var  _alarms:     []
    property int  _alarmIdSeq: 0
    property bool _addOpen:    false
    property int  _addHour:    7
    property int  _addMinute:  0

    // ── Notification ─────────────────────────────────────────────────────────
    Process {
        id: notifyProc
        command: []
        running: false
    }

    function _notify(title, body) {
        notifyProc.command = ["notify-send", "-a", "ArcShell", "-i", "alarm", title, body]
        notifyProc.running = false
        notifyProc.running = true
    }

    // ── Master tick ───────────────────────────────────────────────────────────
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root._tick()
            if (root._swRunning) root._swMs += 1000
            if (root._timerRunning && root._timerLeft > 0) {
                root._timerLeft--
                if (root._timerLeft === 0) {
                    root._timerRunning = false
                    if (!root._timerFired) {
                        root._timerFired = true
                        root._notify("Timer finished",
                            "Your " + root._timerTotalLabel() + " timer is done.")
                    }
                }
            }
            if (root._sec === "00") root._checkAlarms()
            // Repaint ring only when on timer page and timer is running
            if (root._mode === "timer") pageTimer.requestPaint()
            root._syncState()
        }
    }

    Component.onCompleted: { _tick(); _syncState() }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _zp(n) { return n < 10 ? "0"+n : ""+n }

    function _tick() {
        var d = new Date()
        var h = d.getHours(), m = d.getMinutes(), s = d.getSeconds()
        _currentH = h; _currentM = m
        
        var displayH = PrefsService.use24HourTime ? h : (h % 12 || 12)
        
        _hm  = _zp(displayH) + ":" + _zp(m) + ":" + _zp(s)
        _hStr = _zp(displayH)
        _mStr = _zp(m)
        _sec = _zp(s)
        _amPm = h >= 12 ? "PM" : "AM"
    }

    function _timerDisplay() {
        var h = Math.floor(_timerLeft / 3600)
        var m = Math.floor((_timerLeft % 3600) / 60)
        var s = _timerLeft % 60
        return h > 0
            ? _zp(h) + ":" + _zp(m) + ":" + _zp(s)
            : _zp(m) + ":" + _zp(s)
    }

    function _timerTotalLabel() {
        var h = Math.floor(_timerTotal / 3600)
        var m = Math.floor((_timerTotal % 3600) / 60)
        return h > 0 ? h + "h " + _zp(m) + "m" : m + "m"
    }

    function _timerProgress() {
        return _timerTotal > 0 ? (_timerTotal - _timerLeft) / _timerTotal : 0
    }

    function _swDisplay() {
        var t = Math.floor(_swMs / 1000)
        return _zp(Math.floor(t / 60)) + ":" + _zp(t % 60)
    }

    function _checkAlarms() {
        var list = _alarms.slice(), changed = false
        for (var i = 0; i < list.length; i++) {
            var a = list[i]
            if (!a.enabled) continue
            if (a.hour === _currentH && a.minute === _currentM && !a.firedToday) {
                list[i] = Object.assign({}, a, { firedToday: true })
                changed = true
                _notify("Alarm", (a.label !== "" ? a.label : "Alarm") +
                        " - " + _zp(a.hour) + ":" + _zp(a.minute))
            }
            if (a.firedToday && !(a.hour === _currentH && a.minute === _currentM)) {
                list[i] = Object.assign({}, a, { firedToday: false })
                changed = true
            }
        }
        if (changed) _alarms = list
    }

    function _addAlarm(h, m) {
        var hour = (h !== undefined) ? h : _addHour
        var minute = (m !== undefined) ? m : _addMinute
        var list = _alarms.slice()
        list.push({
            id:         _alarmIdSeq++,
            hour:       hour,
            minute:     minute,
            label:      "",
            enabled:    true,
            firedToday: false
        })
        _alarms  = list
        _addOpen = false
        _syncState()
    }

    function _toggleAlarm(id) {
        var list = _alarms.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                list[i] = Object.assign({}, list[i], { enabled: !list[i].enabled })
                break
            }
        }
        _alarms = list
        _syncState()
    }

    function _deleteAlarm(id) {
        _alarms = _alarms.filter(function(a) { return a.id !== id })
        _syncState()
    }

    function _syncState() {
        ClockState.timerRunning = _timerRunning
        ClockState.timerLeft    = _timerLeft
        ClockState.timerTotal   = _timerTotal
        ClockState.timerDisplay = _timerDisplay()
        ClockState.swRunning    = _swRunning
        ClockState.swDisplay    = _swDisplay()
        ClockState.swStarted    = _swStarted
        ClockState.timerStarted = _timerStarted

        var now = _currentH * 60 + _currentM, best = null
        for (var i = 0; i < _alarms.length; i++) {
            var a = _alarms[i]
            if (!a.enabled) continue
            var t    = a.hour * 60 + a.minute
            var diff = t >= now ? t - now : t + 1440 - now
            if (best === null || diff < best.minsUntil)
                best = { hour: a.hour, minute: a.minute, label: a.label, minsUntil: diff }
        }
        ClockState.nextAlarm = best
    }
    
    Connections {
        target: ClockState
      
        function onSwRunningChanged() {
            // Sync internal state if the singleton is changed externally (e.g., from the notch)
            if (root._swRunning !== ClockState.swRunning) {
                root._swRunning = ClockState.swRunning
            }
        }
        
        function onRequestStopwatchReset() {
            root._swMs = 0
            root._swRunning = false
            root._swStarted = false
            root._syncState()
        }
        
        function onTimerRunningChanged() {
            if (root._timerRunning !== ClockState.timerRunning) {
                root._timerRunning = ClockState.timerRunning
            }
        }
        
        function onRequestTimerReset() {
            root._timerLeft    = root._timerTotal
            root._timerRunning = false
            root._timerStarted = false
            root._syncState()
            pageTimer.requestPaint()
        }
    }
    
    Connections {
        target: PrefsService
        function onUse24HourTimeChanged() { root._tick() }
    }

    function resetCard() {
        root._mode = "clock"
        root._addOpen = false
        root._addTimerOpen = false
        if (pageAlarm && pageAlarm.resetScroll) pageAlarm.resetScroll()
    }

    Connections {
        target: SurfaceState
        function onActiveContentChanged() {
            if (SurfaceState.activeContent !== "dashboard") root.resetCard()
        }
    }

    Connections {
        target: Popups
        function onDashboardPageChanged() {
            if (Popups.dashboardPage !== "home") root.resetCard()
        }
    }
    
    // ── UI ────────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        Item {
            id: pagesContainer
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: tabs.top }
            clip: true
            
            property int pageIdx: Math.max(0, ["clock", "timer", "alarm", "stopwatch"].indexOf(root._mode))

            // ── CLOCK ─────────────────────────────────────────────────────────────
            Item {
                id: pageClock
                readonly property int myIdx: 0
                property bool isCurrent: root._mode === "clock"
                property bool wasCurrent: false
                property real parallaxFactor: Anim.style === "parallax" ? 0.3 : 1.0
                onIsCurrentChanged: { 
                    if (isCurrent) wasCurrent = false;
                    else if (Anim.style === "none") wasCurrent = false;
                    else wasCurrent = true;
                }
                
                width: parent.width; height: parent.height
                
                property real targetX: {
                    if (Anim.style === "none" || Anim.style === "fade" || Anim.style === "scale" || Anim.style === "rise") return 0;
                    if (isCurrent) return 0;
                    if (myIdx < pagesContainer.pageIdx) return -width * parallaxFactor;
                    return width;
                }
                
                x: targetX
                Behavior on x {
                    enabled: Anim.style !== "none"
                    NumberAnimation { 
                        duration: Anim.slow; easing.type: Anim.outExpo
                        onRunningChanged: { if (!running && !pageClock.isCurrent) pageClock.wasCurrent = false; }
                    }
                }
                
                property real targetOpacity: {
                    if (Anim.style === "none" || Anim.style === "slide") return 1.0;
                    if (isCurrent) return 1.0;
                    return 0.0;
                }
                opacity: targetOpacity
                Behavior on opacity {
                    enabled: Anim.style !== "none" && Anim.style !== "slide"
                    NumberAnimation { duration: Anim.slow; easing.type: Anim.outExpo
                        onRunningChanged: { if (!running && !pageClock.isCurrent) pageClock.wasCurrent = false; } }
                }
                
                scale: targetScale
                property real targetScale: {
                    if (Anim.style === "scale" || Anim.style === "rise") return isCurrent ? 1.0 : 0.95;
                    return 1.0;
                }
                Behavior on scale {
                    enabled: Anim.style === "scale" || Anim.style === "rise"
                    NumberAnimation { duration: Anim.slow; easing.type: Anim.outExpo; easing.overshoot: Anim.globalOvershoot; easing.amplitude: Anim.globalAmplitude; easing.period: Anim.globalPeriod
                        onRunningChanged: { if (!running && !pageClock.isCurrent) pageClock.wasCurrent = false; } }
                }
                
                visible: isCurrent || wasCurrent

                Row {
                    id: lcd
                    anchors.centerIn: parent
                    spacing: Math.round(8 * localScale)
                    readonly property real u: localScale
                    readonly property bool tick: (parseInt(root._sec) || 0) % 2 === 0

                    component Seg: Item {
                        id: seg
                        property string value: "8"
                        property color lit: Theme.active
                        property real dw: 34
                        property real dh: 64
                        readonly property real t: Math.max(3, Math.round(dw * 0.18))
                        readonly property var masks: ({ "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd",
                                                        "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc",
                                                        "8": "abcdefg", "9": "abcdfg" })
                        readonly property string on: masks[value] || ""
                        width: dw
                        height: dh
                        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.1, 0, seg.dh * 0.05, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                        Repeater {
                            model: [
                                { k: "a", x: 1, y: 0, w: 2, h: 0 }, { k: "b", x: 3, y: 1, w: 0, h: 1 },
                                { k: "c", x: 3, y: 2, w: 0, h: 1 }, { k: "d", x: 1, y: 3, w: 2, h: 0 },
                                { k: "e", x: 0, y: 2, w: 0, h: 1 }, { k: "f", x: 0, y: 1, w: 0, h: 1 },
                                { k: "g", x: 1, y: 4, w: 2, h: 0 }
                            ]
                            Rectangle {
                                required property var modelData
                                readonly property bool active: seg.on.indexOf(modelData.k) >= 0
                                readonly property real half: (seg.dh - seg.t) / 2
                                x: modelData.x === 0 ? 0 : modelData.x === 3 ? seg.dw - seg.t : seg.t + 1
                                y: modelData.y === 0 ? 0 : modelData.y === 1 ? seg.t / 2 + 1 : modelData.y === 2 ? half + seg.t / 2 + 1
                                   : modelData.y === 3 ? seg.dh - seg.t : half
                                width: modelData.w === 2 ? seg.dw - 2 * seg.t - 2 : seg.t
                                height: modelData.h === 1 ? half - seg.t / 2 - 2 : seg.t
                                radius: seg.t / 2
                                color: active ? seg.lit : Qt.rgba(seg.lit.r, seg.lit.g, seg.lit.b, 0.07)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                    }

                    Repeater {
                        model: [root._hStr.charAt(0), root._hStr.charAt(1)]
                        Seg { required property var modelData; value: modelData; lit: Theme.text
                              dw: Math.round(38 * lcd.u); dh: Math.round(72 * lcd.u); anchors.verticalCenter: parent.verticalCenter }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(16 * lcd.u)
                        Repeater {
                            model: 2
                            Rectangle {
                                width: Math.round(8 * lcd.u); height: width; radius: 2
                                color: lcd.tick ? Theme.active : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                        }
                    }
                    Repeater {
                        model: [root._mStr.charAt(0), root._mStr.charAt(1)]
                        Seg { required property var modelData; value: modelData; lit: Theme.active
                              dw: Math.round(38 * lcd.u); dh: Math.round(72 * lcd.u); anchors.verticalCenter: parent.verticalCenter }
                    }
                    Column {
                        anchors.bottom: parent.bottom
                        spacing: Math.round(6 * lcd.u)
                        Text {
                            visible: !PrefsService.use24HourTime
                            text: root._amPm
                            font.pixelSize: Math.round(12 * lcd.u); font.weight: Font.Bold
                            font.family: "JetBrains Mono"; font.letterSpacing: 2
                            color: Theme.active
                        }
                        Row {
                            spacing: Math.round(4 * lcd.u)
                            Repeater {
                                model: [root._sec.charAt(0), root._sec.charAt(1)]
                                Seg { required property var modelData; value: modelData
                                      lit: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.6)
                                      dw: Math.round(14 * lcd.u); dh: Math.round(26 * lcd.u) }
                            }
                        }
                    }
                }
            }

            // ── TIMER ─────────────────────────────────────────────────────────────
            TimerView {
                id: pageTimer
                localScale: root.localScale
                pageIdx: pagesContainer.pageIdx
                isCurrent: root._mode === "timer"
                timerTotal: root._timerTotal
                timerLeft: root._timerLeft
                timerRunning: root._timerRunning
                timerDisplay: root._timerDisplay()
                timerProgress: root._timerProgress()
                addTimerOpen: root._addTimerOpen
                onAddTimerOpenChanged: root._addTimerOpen = addTimerOpen
                onSetTimer: function(total) {
                    root._timerTotal   = total
                    root._timerLeft    = total
                    root._timerRunning = false
                    root._timerFired   = false
                    root._syncState()
                    pageTimer.requestPaint()
                }
                onToggleRunning: {
                    root._timerRunning = !root._timerRunning
                    root._timerStarted = true
                    root._timerFired   = false
                    root._syncState()
                }
                onReset: {
                    root._timerLeft    = root._timerTotal
                    root._timerRunning = false
                    root._timerFired   = false
                    root._timerStarted = false
                    root._syncState()
                    pageTimer.requestPaint()
                }
            }

            // ── ALARM ─────────────────────────────────────────────────────────────
            AlarmView {
                id: pageAlarm
                localScale: root.localScale
                pageIdx: pagesContainer.pageIdx
                isCurrent: root._mode === "alarm"
                alarms: root._alarms
                addOpen: root._addOpen
                onAddOpenChanged: root._addOpen = addOpen
                onAddAlarm: function(h, m) {
                    root._addHour   = h
                    root._addMinute = m
                    root._addAlarm(h, m)
                }
                onToggleAlarm: function(id) {
                    root._toggleAlarm(id)
                }
                onDeleteAlarm: function(id) {
                    root._deleteAlarm(id)
                }
            }

            // ── STOPWATCH ─────────────────────────────────────────────────────────
            StopwatchView {
                id: pageStopwatch
                localScale: root.localScale
                pageIdx: pagesContainer.pageIdx
                isCurrent: root._mode === "stopwatch"
                swDisplay: root._swDisplay()
                swRunning: root._swRunning
                onToggleRunning: {
                    root._swRunning = !root._swRunning
                    root._swStarted = true
                    root._syncState()
                }
                onReset: {
                    root._swMs = 0
                    root._swRunning = false
                    root._swStarted = false
                    root._syncState()
                }
            }
        } // End of pagesContainer

        // ── Tab bar ───────────────────────────────────────────────────────────
        TabSwitcher {
            id: tabs
            localScale: root.localScale
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            orientation: "horizontal"; width: parent.width
            currentPage: root._mode
            model: [
                { key: "clock",     icon: "󰥔", label: "Clock"     },
                { key: "timer",     icon: "󱎫", label: "Timer"     },
                { key: "alarm",     icon: "󰀠", label: "Alarm"     },
                { key: "stopwatch", icon: "󰔚", label: "Stopwatch" }
            ]
            onPageChanged: function(key) { root._mode = key }
        }
    }
}
