// Vertical status bar (left edge): launcher, workspaces, active window, tray, clock, volume,
// recording, brightness, kb layout, battery, network/bt/vpn, power. Hover-popouts grow out of it
// with a concave "cove" join — every one, tray menu included, is a transparent PopupWindow whose
// background is the Frame's SDF bulge (reportPopBox → PopoutState → modules/Frame.qml).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.arc
import qs.arc.components
import qs.arc.services
import qs.arc.modules.bar
import "../../frame" as Frame

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // One popout at a time, with a small close delay so the cursor can travel into it.
    property string popout: ""
    Timer { id: popHideTimer; interval: 180; onTriggered: bar.popout = "" }
    // Clear the frame bulge only when SWITCHING popouts. Re-calling showPopout for the one
    // already open (the cursor entering its body fires the HoverHandler) must not clear it:
    // bar.popout wouldn't change, so nothing would re-report the box and the background would go.
    // All bar popouts claim the bulge under one owner id, so closing one drops only its own — a
    // tray menu fading out used to clear the box the Dashboard had just claimed.
    readonly property string bulgeOwner: "bar"
    function showPopout(name) { popHideTimer.stop(); if (bar.popout !== name) PopoutState.clear(bar.bulgeOwner); bar.popout = name; }
    function hidePopout() { popHideTimer.restart(); }

    // Keyboard route in: `ipc call bar popout network`, kept in step both ways.
    Connections {
        target: Shell
        function onBarPopoutChanged() {
            if (Shell.barPopout !== "") bar.showPopout(Shell.barPopout);
            else if (bar.popout !== "") bar.popout = "";
        }
    }
    onPopoutChanged: if (bar.popout === "" && Shell.barPopout !== "") Shell.barPopout = ""

    // Report an open popout's body rect (screen px) so the Frame bulges the bar into it. Quickshell
    // centres the popup on its widget then clamps it on-screen; that clamp is replicated here so
    // the bulge tracks tall popouts too. `anim` false lands the bulge in the same frame, for a
    // popout that merely resized. `height` overrides popup.implicitHeight where that binding may
    // still be stale at report time (the tray menu).
    function reportPopBox(widget, popup, anim, height) {
        const gcy = widget.mapToItem(null, 0, widget.height / 2).y;   // widget center, screen y
        const tp0 = popup.topPad !== undefined ? popup.topPad : 0;
        const ph = height === undefined ? popup.implicitHeight - tp0 : height;
        const bh = ph - Config.popFillet * 2;                         // body height (minus fillets)
        const pf = Config.popFillet;
        // Skirt under the body: normally a full fillet so the SDF cove has room to curve back
        // into the bar. Where the screen edge already crowds the body — the power menu — that
        // skirt is dead space between the menu and the edge, so trade it for the bar's own 12px
        // margin and let the body reach down. The window height is unchanged; the padding just
        // moves from under the body to above it, so the window still lands flush at the edge.
        const bp = gcy + bh / 2 + pf > bar.height ? 12 : pf;
        if (popup.botPad !== undefined) popup.botPad = bp;
        let top = gcy - bh / 2;
        // ArchangelOS: the pane grows out of the main shell surface, whose top-left notch owns the
        // corner above it — keep the body below that, padding the popup so its content follows.
        const reserve = Frame.Theme.borderWidth + Frame.Theme.notchHeight + Frame.Theme.cornerRadius * 2 + 6;
        let tp = 0;
        if (top < reserve) {
            tp = 2 * (reserve - top);                                 // popup still centred on the widget
            if (gcy - (bh + pf * 2 + tp) / 2 < 0) tp = reserve - pf;  // popup slid to the screen top
            top = reserve;
        }
        if (popup.topPad !== undefined && Math.abs(popup.topPad - tp) > 0.5) popup.topPad = tp;
        top = Math.max(pf, Math.min(top, bar.height - bh - bp));      // keep body on-screen
        // Where the bulge grows from and collapses back to, as a fraction of the box. Left edge
        // (0) is the bar; the vertical share is the WIDGET's centre, not the box's — once the
        // screen edge has clamped the body those differ, and the default (0,0) meant every popout
        // retracted towards the top of itself instead of into the icon it flowed out of.
        const ay = bh > 0 ? Math.max(0, Math.min(1, (gcy - top) / bh)) : 0.5;
        PopoutState.setBox(bar.implicitWidth - 18, top, popup.implicitWidth + 12, bh,
                           bar.bulgeOwner, anim, 0, ay);
    }

    // Which tray item's menu the shared tray-menu popout should show.
    property var trayMenuHandle: null
    property Item trayMenuAnchor: null

    // Session actions for the power popout; the verbs live in services/Session.qml.
    readonly property var sessionActions: Session.pick(["lock", "logout", "reboot", "poweroff"])
    // Out of `sessionActions` on purpose: that array is the Repeater's model, so a palette
    // dependency there would rebuild all four delegates per theme change. Indexed in parallel
    // instead, so a switch only repaints them.
    readonly property var sessionTones: [Config.info, Config.warning, Config.success, Config.danger]

    // Keep-awake: inhibits idle/sleep while Shell.keepAwake is on.
    IdleInhibitor { window: bar; enabled: Shell.keepAwake }

    // Fullscreen on THIS output's current workspace, not anywhere in the session: a video going
    // fullscreen on another workspace used to take this bar away and hand back its exclusive zone.
    readonly property bool fullscreenHere: Hypr.fullscreenOn(bar.modelData?.name ?? "")

    anchors { top: true; left: true; bottom: true }
    implicitWidth: 56
    color: "transparent"
    // Never toggle `visible` on fullscreen: remapping the layer surface races with the Frame's own
    // remap and the bar routinely fails to reappear (QML reports visible=true, surface unmapped).
    // Keep it mapped — drop the exclusive zone, hide the content, empty the input region.
    visible: true
    exclusiveZone: bar.fullscreenHere ? 0 : implicitWidth
    mask: bar.fullscreenHere ? passthrough : null
    Region { id: passthrough }   // empty region → input passes through under fullscreen

    // Background is drawn by the Frame (one continuous SDF surface); this stays transparent.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        visible: !bar.fullscreenHere   // hide widgets under a fullscreen window

    // --- ArchangelOS mark (top-left corner) — the head of the bar, level with ArcShell's
    // workspace tab beside it. Opens ArcShell's control menu out of the bar's edge. ---
    Item {
        id: markBtn
        x: 0; y: 8
        width: parent.width; height: 40
        Rectangle {
            anchors.centerIn: parent
            width: 40; height: 32; radius: 10
            color: markMa.containsMouse || Frame.Popups.archMenuOpen ? Config.container : "transparent"
            Behavior on color { ColorAnim {} }
        }
        Image {
            anchors.centerIn: parent
            source: "file:///usr/share/archangelos/logo-mark.svg"
            sourceSize: Qt.size(56, 41)
            width: 26; height: 19
            smooth: true
            scale: markMa.pressed ? 0.9 : 1.0
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: markMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!Frame.Popups.archMenuOpen) {
                    Frame.SurfaceState.open("leftCenter", "archMenu")
                    Frame.Popups.archMenuPinned = true
                } else {
                    Frame.SurfaceState.close()
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        // ArchangelOS: the bar grows down out of ArcShell's top-left notch (logo and
        // workspaces live there), so the column starts below it.
        anchors.topMargin: 64
        anchors.bottomMargin: 16
        spacing: 10

        // --- Monitors (ArchangelOS): live readings; each cluster opens a dock pane ---
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Component.onCompleted: Sys.active = true

            // CPU / RAM / GPU / Storage / Battery — hover opens the system pane
            Item {
                id: sysWidget
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: sysCol.implicitWidth
                implicitHeight: sysCol.implicitHeight
                ColumnLayout {
                    id: sysCol
                    anchors.fill: parent
                    spacing: 12
                    BarMeter { icon: "speed";           value: Sys.cpu;  valueText: Math.round(Sys.cpu * 100);  tint: Config.severity(Sys.cpu, Config.series[0], 0.75, 0.85) }
                    BarMeter { icon: "memory";          value: Sys.mem;  valueText: Math.round(Sys.mem * 100);  tint: Config.severity(Sys.mem, Config.series[1], 0.8, 0.9) }
                    BarMeter { icon: "developer_board"; value: Sys.gpu;  valueText: Math.round(Sys.gpu * 100);  tint: Config.severity(Sys.gpu, Config.series[2], 0.8, 0.9); visible: Sys.hasGpu }
                    BarMeter { icon: "storage";         value: Sys.disk; valueText: Math.round(Sys.disk * 100); tint: Config.severity(Sys.disk, Config.series[3], 0.8, 0.9) }
                    BarMeter { icon: Sys.batteryCharging ? "battery_charging_full" : "battery_full"
                               value: Sys.batteryPct / 100; valueText: Sys.batteryPct
                               tint: Sys.batteryPct <= 20 ? Config.tertiary : Config.accent; visible: Sys.hasBattery }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: bar.showPopout("sys"); onExited: bar.hidePopout()
                    onClicked: bar.showPopout("sys")
                }
            }

            // Weather — hover opens the weather pane
            Item {
                id: weatherWidget
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: wxCol.implicitWidth
                implicitHeight: wxCol.implicitHeight
                ColumnLayout {
                    id: wxCol
                    anchors.fill: parent
                    spacing: 0
                    MatIcon { Layout.alignment: Qt.AlignHCenter; text: Weather.icon; font.pixelSize: 18; color: Config.dim }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Weather.ok ? Weather.tempC + "°" : "--"
                        color: Config.fg; font.family: Config.textFont; font.pixelSize: 11; font.bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: bar.showPopout("weather"); onExited: bar.hidePopout()
                    onClicked: bar.showPopout("weather")
                }
            }

            // Network — wifi/eth status + rates; hover opens the network pane
            Item {
                id: monNetWidget
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: netCol.implicitWidth
                implicitHeight: netCol.implicitHeight
                ColumnLayout {
                    id: netCol
                    anchors.fill: parent
                    spacing: 1
                    MatIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: !Net.netUp ? "signal_wifi_off"
                              : (Net.activeWifi !== null ? Net.netIcon(Net.wifiSignal) : "lan")
                        font.pixelSize: 15; color: Net.netUp ? Config.dim : Config.tertiary
                    }
                    Repeater {
                    model: [["south", Sys.down, Config.accent], ["north", Sys.up, Config.tertiary]]
                    ColumnLayout {
                        id: rate
                        required property var modelData
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 0
                        MatIcon { Layout.alignment: Qt.AlignHCenter; text: rate.modelData[0]; font.pixelSize: 11; color: rate.modelData[2] }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Shell.fmtSpeed(rate.modelData[1])
                            color: Config.dim
                            font.family: Config.textFont
                            font.pixelSize: 8
                        }
                    }
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: bar.showPopout("netinfo"); onExited: bar.hidePopout()
                    onClicked: bar.showPopout("netinfo")
                }
            }
        }

        // --- Workspaces: fixed slots + sliding active indicator ---
        Item {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barWorkspaces
            readonly property int slot: 28
            readonly property int gap: 6
            readonly property int pitch: slot + gap
            readonly property int pill: 42          // match the network pill width
            readonly property int padV: 7           // vertical padding inside the pill
            implicitWidth: pill
            implicitHeight: Hypr.maxWs * slot + (Hypr.maxWs - 1) * gap + padV * 2

            // Scroll over the workspaces to switch (up = previous, down = next).
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => HyprCtl.workspace(e.angleDelta.y > 0 ? "e-1" : "e+1")
            }

            // Pill background grouping the whole workspace column (matches the network pill below).
            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Config.containerSoft
            }

            // Sliding coral indicator behind the active workspace.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.slot; height: parent.slot; radius: parent.slot / 2
                color: Config.accent
                y: parent.padV + (Hypr.activeWs - 1) * parent.pitch
                Behavior on y { SpatialFast {} }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.padV
                spacing: parent.gap
                Repeater {
                    model: Hypr.maxWs
                    Rectangle {
                        id: wsSlot
                        required property int index
                        readonly property int ws: index + 1
                        readonly property bool active: ws === Hypr.activeWs
                        readonly property var wins: Hypr.wsWindows(ws)
                        readonly property bool occupied: wins.length > 0 || Hypr.wsOccupied(ws)
                        readonly property bool urgent: !!Hypr.urgentWs[ws] && !active
                        // Workspace number as a Roman numeral (I, II, III … up to ~X).
                        readonly property string roman: {
                            let n = ws, r = "";
                            const m = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
                            for (const p of m) while (n >= p[0]) { r += p[1]; n -= p[0]; }
                            return r;
                        }
                        width: 28; height: 28; radius: 14
                        color: "transparent"

                        // Roman numeral of the workspace number when occupied; a small dot when empty.
                        Text {
                            anchors.centerIn: parent
                            visible: wsSlot.occupied
                            text: wsSlot.roman
                            font.family: Config.textFont; font.pixelSize: 13; font.bold: true
                            color: wsSlot.active ? Config.accentText : (wsSlot.urgent ? Config.error : Config.fg)
                            // Pulse while requesting attention.
                            SequentialAnimation on opacity {
                                running: wsSlot.urgent; loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            visible: !wsSlot.occupied
                            width: wsSlot.active ? 7 : 5; height: width; radius: width / 2
                            color: wsSlot.active ? Config.accentText : (wsSlot.urgent ? Config.error : Config.dim)
                            Behavior on width { SpatialFast {} }
                            Behavior on color { ColorAnim {} }
                        }
                        StateLayer { ovRadius: 14; onTapped: HyprCtl.workspace(parent.ws) }
                    }
                }
            }
        }


        Item { Layout.fillHeight: true }  // spacer

        // --- Active window (icon + vertical title) ---
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barWindow && Hypr.activeClass !== ""
            spacing: 10

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 26; implicitHeight: 26
                FadeImage {
                    id: activeIconImg
                    anchors.fill: parent
                    box: 26
                    fillMode: Image.PreserveAspectFit
                    source: Hypr.activeEntry?.icon ? Quickshell.iconPath(Hypr.activeEntry.icon, true) : ""
                }
                MatIcon {
                    anchors.centerIn: parent
                    visible: !activeIconImg.ready
                    text: "web_asset"
                    font.pixelSize: 20
                    color: Config.dim
                }
            }

            // Title written sideways (rotated 90°).
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: awTitle.contentHeight
                implicitHeight: Math.min(240, awTitle.contentWidth)
                clip: true
                Text {
                    id: awTitle
                    anchors.centerIn: parent
                    rotation: -90
                    text: Hypr.activeTitle || Hypr.activeClass
                    // A window title is set by the window — a web page picks its own through
                    // <title>. AutoText would hand that to the rich-text engine, which resolves
                    // remote <img> URLs; PlainText is the only safe reading of foreign text.
                    textFormat: Text.PlainText
                    color: Config.dim
                    font.family: Config.textFont; font.pixelSize: 12
                }
            }
        }

        Item { Layout.fillHeight: true }  // spacer

        // --- System tray ---
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barTray
            spacing: 10
            Repeater {
                model: SystemTray.items
                Item {
                    id: trayItem
                    required property var modelData
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -5; radius: 8
                        color: trayMa.containsMouse ? Config.container : "transparent"
                        Behavior on color { ColorAnim {} }
                    }
                    Image {
                        id: trayIcon
                        anchors.fill: parent
                        sourceSize: Qt.size(18, 18)
                        source: trayItem.modelData.icon
                    }
                    function openMenu() {
                        if (!trayItem.modelData.hasMenu) return;
                        // Idempotent: reassigning the handle reloads the D-Bus menu, which briefly
                        // empties it and thrashes the bulge.
                        if (bar.popout === "traymenu" && bar.trayMenuAnchor === trayIcon) {
                            bar.showPopout("traymenu");
                            return;
                        }
                        bar.trayMenuHandle = trayItem.modelData.menu;
                        bar.trayMenuAnchor = trayIcon;
                        bar.showPopout("traymenu");
                    }
                    MouseArea {
                        id: trayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.RightButton | Qt.MiddleButton
                        // Hover shows the app's menu; it closes on hover-out like every other popout.
                        onEntered: trayItem.openMenu()
                        onExited: bar.hidePopout()
                        onClicked: e => {
                            if (e.button === Qt.MiddleButton) trayItem.modelData.secondaryActivate();
                            else if (e.button === Qt.RightButton) trayItem.openMenu();
                        }
                    }
                }
            }
        }

        // --- Clock (vertical): day / date / time ---
        Item {
            id: clockWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barClock
            Layout.topMargin: 4
            implicitWidth: clockCol.implicitWidth
            implicitHeight: clockCol.implicitHeight

            ColumnLayout {
                id: clockCol
                anchors.centerIn: parent
                spacing: 0
                property var now: new Date()
                // Once a minute, aligned to :00 — the readout is day/date/hh/mm with no seconds
                // anywhere, so a 1s tick relaid out and repainted the bar sixty times per visible
                // change. See components/DesktopClock.qml for the same pattern.
                Timer {
                    id: barMinuteTick
                    interval: 60000 - (Date.now() % 60000)
                    running: true
                    onTriggered: {
                        clockCol.now = new Date();
                        barMinuteTick.interval = 60000 - (Date.now() % 60000);
                        barMinuteTick.restart();
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clockCol.now, "ddd")
                    font.family: Config.textFont; font.pixelSize: 10; color: Config.dim
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clockCol.now, "d")
                    font.family: Config.textFont; font.pixelSize: 13; font.bold: true; color: Config.tertiary
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4; Layout.bottomMargin: 4
                    implicitWidth: 18; implicitHeight: 1; color: Config.container
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    // Qt reads "hh" as 00–23 unless an AP field is present, so 12-hour mode asks
                    // for one and drops it into its own line below.
                    text: Config.barClock12h ? Qt.formatDateTime(clockCol.now, "hh AP").split(" ")[0]
                                             : Qt.formatDateTime(clockCol.now, "hh")
                    font.family: Config.textFont; font.pixelSize: 17; font.bold: true; color: Config.tertiary
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clockCol.now, "mm")
                    font.family: Config.textFont; font.pixelSize: 17; color: Config.tertiary
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: Config.barClock12h
                    text: Qt.formatDateTime(clockCol.now, "AP")
                    font.family: Config.textFont; font.pixelSize: 9; color: Config.dim
                }
            }
        }


        // --- Volume (standalone: scroll to change, click to mute, hover for slider) ---
        Item {
            id: volWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barVolume
            implicitWidth: 40
            implicitHeight: volStat.implicitHeight
            Rectangle {
                anchors.fill: parent; radius: 9
                color: volMa.containsMouse ? Config.container : "transparent"
                Behavior on color { ColorAnim {} }
            }
            Stat {
                id: volStat
                label: "Volume"
                anchors.horizontalCenter: parent.horizontalCenter
                icon: Audio.muted ? "volume_off" : (Audio.volume > 0.5 ? "volume_up" : "volume_down")
                value: Audio.muted ? "—" : Math.round(Audio.volume * 100) + ""
                tint: Audio.muted ? Config.dim : Config.fg
            }
            MouseArea {
                id: volMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: bar.showPopout("volume")
                onExited: bar.hidePopout()
                onClicked: Audio.toggleMute()
                onWheel: e => Audio.addVolume(e.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }

        // --- Recording indicator (only while recording: elapsed time, hover for pause/stop) ---
        Item {
            id: recWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Capture.active
            Layout.preferredHeight: Capture.active ? implicitHeight : 0
            implicitWidth: 40
            implicitHeight: recStat.implicitHeight
            Rectangle {
                anchors.fill: parent; radius: 9
                color: recMa.containsMouse ? Config.container : "transparent"
                Behavior on color { ColorAnim {} }
            }
            Stat {
                id: recStat
                label: "Recording"
                anchors.horizontalCenter: parent.horizontalCenter
                // Muxing after a stop is neither recording nor paused: a blinking red dot over a
                // still-ticking clock would claim the capture is going when it is being written out.
                icon: Capture.stopping ? "save" : (Capture.paused ? "pause_circle" : "fiber_manual_record")
                value: Capture.elapsedText
                tint: Capture.stopping ? Config.dim : (Capture.paused ? Config.warning : Config.error)
                // Pulse only while capturing, so a paused recording reads as held. The value source
                // keeps the opacity it stopped on, so pausing must reset it to 1.
                SequentialAnimation on opacity {
                    running: Capture.state === "recording" && !Capture.stopping; loops: Animation.Infinite
                    onRunningChanged: if (!running) recStat.opacity = 1
                    NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            MouseArea {
                id: recMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: bar.showPopout("rec")
                onExited: bar.hidePopout()
                onClicked: Capture.togglePause()
            }
        }

        // --- Game mode indicator (only shown while active; click to turn off) ---
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: GameMode.enabled
            Layout.preferredHeight: GameMode.enabled ? implicitHeight : 0
            implicitWidth: 30; implicitHeight: 30; radius: 9
            color: "transparent"
            MatIcon {
                anchors.centerIn: parent
                text: "sports_esports"
                font.pixelSize: 16
                color: Config.accent
            }
            StateLayer { ovRadius: 9; tint: Config.accent; onTapped: GameMode.toggle() }
        }

        // --- Brightness (standalone: scroll to change, hover for slider; DDC/CI monitor) ---
        Item {
            id: briWidget
            visible: Config.barBrightness && Brightness.available
            Layout.preferredHeight: briWidget.visible ? implicitHeight : 0
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 40
            implicitHeight: briStat.implicitHeight
            Rectangle {
                anchors.fill: parent; radius: 9
                color: briMa.containsMouse ? Config.container : "transparent"
                Behavior on color { ColorAnim {} }
            }
            Stat {
                id: briStat
                label: "Brightness"
                anchors.horizontalCenter: parent.horizontalCenter
                icon: "brightness_medium"
                value: Brightness.brightness + ""
                tint: Config.fg
            }
            MouseArea {
                id: briMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: bar.showPopout("brightness")
                onExited: bar.hidePopout()
                onWheel: e => Brightness.set(Brightness.brightness + (e.angleDelta.y > 0 ? 5 : -5))
            }
        }

        // --- Keyboard layout (standalone, click to switch) ---
        Item {
            id: kbWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barKeyboard
            implicitWidth: kbStat.implicitWidth
            implicitHeight: kbStat.implicitHeight
            Rectangle {
                anchors.fill: parent; anchors.margins: -4; radius: 9
                color: kbMa.containsMouse ? Config.container : "transparent"
                Behavior on color { ColorAnim {} }
            }
            Stat { id: kbStat; label: "Keyboard layout"; anchors.centerIn: parent; icon: "keyboard"; value: Hypr.kbLayout; tint: Config.fg }
            MouseArea {
                id: kbMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", Hypr.kbDevice || "all", "next"])
            }
        }

        // --- Battery (laptops only) ---
        Stat {
            id: batWidget
            label: Bat.charging ? "Battery, charging" : "Battery"
            visible: Config.barBattery && Bat.has
            Layout.preferredHeight: batWidget.visible ? implicitHeight : 0
            icon: Bat.charging ? "battery_charging_full" : "battery_full"
            value: Bat.percent + ""
            tint: Bat.percent <= 15 ? Config.error : (Bat.percent <= 30 ? Config.warning : Config.tertiary)
        }

        // --- Controls pill: network / bluetooth / VPN ---
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barControls
            implicitWidth: 42
            implicitHeight: ctrlCol.implicitHeight + 12
            radius: 16
            // Fade the group background while its popout is open, so the coves blend into the
            // plain bar instead of clipping the pill.
            readonly property bool popActive: bar.popout === "network" || bar.popout === "bluetooth" || bar.popout === "vpn"
            color: popActive ? "transparent" : Config.containerSoft
            Behavior on color { ColorAnim {} }
            ColumnLayout {
                id: ctrlCol
                anchors.centerIn: parent
                spacing: 8

                // Network: one icon for whichever link actually carries traffic — wired when it
                // owns the default route (or is the only one up), else the Wi-Fi signal. The
                // popout below lists both when they are up together.
                IconBtn {
                    id: netWidget
                    label: Net.netUp ? "Network, connected" : "Network, offline"
                    icon: Net.ethernetUp && (Net.ethernetIsDefault || !Net.wifiUp) ? "settings_ethernet"
                        : (!Net.wifiOn ? "wifi_off" : (Net.wifiUp ? Net.netIcon(Net.wifiSignal) : "wifi_find"))
                    tint: Net.netUp ? Config.accent : Config.dim
                    onClicked: Net.toggleWifi()
                    onHoverIn: { bar.showPopout("network"); Net.scan(); }
                    onHoverOut: bar.hidePopout()
                }
                // Bluetooth (click toggles power via bluetoothctl, hover for devices)
                IconBtn {
                    id: btWidget
                    label: !Bt.enabled ? "Bluetooth, off" : (Bt.connected ? "Bluetooth, connected" : "Bluetooth, on")
                    icon: !Bt.enabled ? "bluetooth_disabled" : (Bt.connected ? "bluetooth_connected" : "bluetooth")
                    tint: Bt.connected ? Config.accent : (Bt.enabled ? Config.fg : Config.dim)
                    onClicked: Bt.toggle()
                    onHoverIn: bar.showPopout("bluetooth")
                    onHoverOut: bar.hidePopout()
                }
                // VPN (hover for the profile list)
                IconBtn {
                    id: vpnWidget
                    label: Net.vpnActive ? "VPN, connected" : "VPN"
                    visible: Net.hasVpn
                    Layout.preferredHeight: Net.hasVpn ? implicitHeight : 0
                    icon: Net.vpnActive ? "vpn_lock" : "vpn_key_off"
                    tint: Net.vpnActive ? Config.accent : Config.dim
                    onHoverIn: bar.showPopout("vpn")
                    onHoverOut: bar.hidePopout()
                }
            }
        }

        // (ArchangelOS: power lives in the top-right panel.)
    }
    }

    // --- Popouts ---
    // Each anchors to its widget and shows while bar.popout names it (modules/bar/BarPopout.qml).
    // ArchangelOS: the monitor panes
    SysPopout        { bar: bar; widget: sysWidget }
    NetInfoPopout    { bar: bar; widget: monNetWidget }
    WeatherPopout    { bar: bar; widget: weatherWidget }
    VolumePopout     { bar: bar; widget: volWidget }
    RecordingPopout  { bar: bar; widget: recWidget }
    BrightnessPopout { bar: bar; widget: briWidget }
    NetworkPopout    { bar: bar; widget: netWidget }
    BluetoothPopout  { bar: bar; widget: btWidget }
    VpnPopout        { bar: bar; widget: vpnWidget }
    // The anchor moves: whichever tray icon the cursor is on.
    TrayMenuPopout   { bar: bar; widget: bar.trayMenuAnchor }
}
