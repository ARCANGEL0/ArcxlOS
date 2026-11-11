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
import "../../frame/state"
import "../../frame/components" as FC

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    property bool barHovered: false
    property bool barExpanded: !Frame.ShellState.focusMode

    Item {
        id: barEdgeTrigger
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.round(4 * bar.localScale)
        visible: false
        z: 1
        HoverHandler { id: barEdgeHover; onHoveredChanged: bar.barHovered = hovered }
    }

    property string popout: ""
    Timer { id: popHideTimer; interval: 180; onTriggered: bar.popout = "" }
    readonly property string bulgeOwner: "bar"
    function showPopout(name) { popHideTimer.stop(); if (bar.popout !== name) PopoutState.clear(bar.bulgeOwner); bar.popout = name; }
    function hidePopout() { popHideTimer.restart(); }

    Connections {
        target: Shell
        function onBarPopoutChanged() {
            if (Shell.barPopout !== "") bar.showPopout(Shell.barPopout);
            else if (bar.popout !== "") bar.popout = "";
        }
    }
    onPopoutChanged: if (bar.popout === "" && Shell.barPopout !== "") Shell.barPopout = ""

    readonly property real screenScale: Math.max(0.75, Math.min(1.5, (bar.screen ? bar.screen.height : 1080) / 1080))
    readonly property real screenTop: Frame.ShellState.focusMode
        ? Math.round(Frame.Theme.borderWidth * bar.screenScale) * 2
        : Math.round(40 * bar.screenScale) + Math.round(Frame.Theme.borderWidth * bar.screenScale) * 2
    function reportPopBox(widget, popup, anim, height) {
        const gcy = widget.mapToItem(null, 0, widget.height / 2).y + bar.screenTop;
        const tp0 = popup.topPad !== undefined ? popup.topPad : 0;
        const ph = height === undefined ? popup.implicitHeight - tp0 : height;
        const bh = ph - Config.popFillet * 2;
        const pf = Config.popFillet;
        const bp = gcy + bh / 2 + pf > bar.screenTop + bar.height ? 12 : pf;
        if (popup.botPad !== undefined) popup.botPad = bp;
        let top = gcy - bh / 2;
        const reserve = Frame.Theme.borderWidth + Frame.Theme.notchHeight + Frame.Theme.cornerRadius * 2 + 6;
        let tp = 0;
        if (top < reserve) {
            tp = 2 * (reserve - top);
            if (gcy - (bh + pf * 2 + tp) / 2 < 0) tp = reserve - pf;
            top = reserve;
        }
        if (popup.topPad !== undefined && Math.abs(popup.topPad - tp) > 0.5) popup.topPad = tp;
        top = Math.max(pf, Math.min(top, bar.screenTop + bar.height - bh - bp));
        const ay = bh > 0 ? Math.max(0, Math.min(1, (gcy - top) / bh)) : 0.5;
        PopoutState.setBox(bar.implicitWidth - 18, top, popup.implicitWidth + 12, bh,
                           bar.bulgeOwner, anim, 0, ay);
    }

    property var trayMenuHandle: null
    property var hoverInfo: ({ title: "", lines: [], hint: "" })
    property Item hoverAnchor: null
    property Item trayMenuAnchor: null

    readonly property var sessionActions: Session.pick(["lock", "logout", "reboot", "poweroff", "suspend"])
    readonly property var sessionTones: [Config.info, Config.warning, Config.success, Config.danger, Config.warning]

    IdleInhibitor { window: bar; enabled: Shell.keepAwake }

    readonly property bool fullscreenHere: Hypr.fullscreenOn(bar.modelData?.name ?? "")

    anchors { top: true; left: true; bottom: true }
    implicitWidth: 56
    color: "transparent"
    visible: !Frame.ShellState.focusMode
    exclusiveZone: bar.fullscreenHere ? 0 : (Frame.ShellState.focusMode ? 0 : implicitWidth)
    mask: bar.fullscreenHere ? passthrough : null
    Region { id: passthrough }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        visible: !bar.fullscreenHere

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 16
        spacing: 10

        ColumnLayout {
            id: statusTop
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            StatusPill {
                id: healthPill
                bar: bar
                popout: "health"
                icon: "add_to_queue"
                tint: DockStatus.healthLevel === "bad" ? Config.danger
                    : DockStatus.healthLevel === "warn" ? Config.warning : Config.success
                pulse: DockStatus.healthLevel === "bad"
                onClicked: Frame.IpcManager._openDashboard("maint")
            }
            StatusPill {
                id: privacyPill
                bar: bar
                popout: "privacy"
                icon: "visibility"
                tint: DockStatus.screenShared || DockStatus.camInUse ? Config.danger
                    : (DockStatus.micInUse && !DockStatus.micMuted) ? Config.warning : Config.dim
                pulse: DockStatus.privacyActive && !(DockStatus.micMuted && !DockStatus.camInUse && !DockStatus.screenShared)
                onClicked: Shell.openSettings("permissions")
            }
            StatusPill {
                id: updatesPill
                bar: bar
                popout: "updates"
                visible: DockStatus.totalUpdates > 0
                icon: "deployed_code_update"
                tint: Config.accent
                count: DockStatus.shortCount(DockStatus.totalUpdates)
                onClicked: Frame.IpcManager._openDashboard("maint")
            }
            StatusPill {
                id: dockerPill
                bar: bar
                popout: "docker"
                glyph: "\uf308"
                tint: DockStatus.dockerRunning > 0 ? Config.info : Config.dim
                count: DockStatus.dockerRunning > 0 ? String(DockStatus.dockerRunning) : ""
                onClicked: Frame.IpcManager._openDashboard("dev")
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Component.onCompleted: Sys.active = true

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
                FC.Tip { text: "Weather"; suppressed: bar.popout !== "" }
            }

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
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 2
                        text: DockStatus.pingMs < 0 ? "-- ms" : DockStatus.pingMs + " ms"
                        color: DockStatus.pingMs < 0 || DockStatus.pingMs > 150 ? Config.danger
                             : DockStatus.pingMs > 70 ? Config.warning : Config.dim
                        font.family: Config.textFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: bar.showPopout("netinfo"); onExited: bar.hidePopout()
                    onClicked: bar.showPopout("netinfo")
                }
                FC.Tip { text: "Network traffic"; suppressed: bar.popout !== "" }
            }

            Item {
                id: sysWidget
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: sysCol.implicitWidth
                implicitHeight: sysCol.implicitHeight
                ColumnLayout {
                    id: sysCol
                    anchors.fill: parent
                    spacing: 12
                    BarMeter { id: cpuMeter; icon: "speed";           value: Sys.cpu;  valueText: Math.round(Sys.cpu * 100);  tint: Config.severity(Sys.cpu, Config.series[0], 0.75, 0.85); hist: Sys.cpuHist;  popout: "cpu"
                               onEntered: bar.showPopout("cpu");  onExited: bar.hidePopout() }
                    BarMeter { icon: "developer_board"; value: Sys.gpu;  valueText: Math.round(Sys.gpu * 100);  tint: Config.severity(Sys.gpu, Config.series[2], 0.8, 0.9); hist: Sys.gpuHist; visible: Sys.hasGpu }
                    BarMeter { id: ramMeter; icon: "memory";          value: Sys.mem;  valueText: Math.round(Sys.mem * 100);  tint: Config.severity(Sys.mem, Config.series[1], 0.8, 0.9); hist: Sys.memHist;  popout: "ram"
                               onEntered: bar.showPopout("ram");  onExited: bar.hidePopout() }
                    BarMeter { id: diskMeter; icon: "hard_disk";       value: Sys.disk; valueText: Math.round(Sys.disk * 100); tint: Config.severity(Sys.disk, Config.series[3], 0.8, 0.9); hist: Sys.diskHist; popout: "disk"
                               onEntered: bar.showPopout("disk"); onExited: bar.hidePopout() }
                    BarMeter { icon: Sys.batteryCharging ? "battery_charging_full" : "battery_full"
                               value: Sys.batteryPct / 100; valueText: Sys.batteryPct
                               tint: Sys.batteryPct <= 20 ? Config.tertiary : Config.accent; visible: Sys.hasBattery }
                }
                FC.Tip { text: "System stats"; suppressed: bar.popout !== "" }
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barWorkspaces
            readonly property int slot: 28
            readonly property int gap: 6
            readonly property int pitch: slot + gap
            readonly property int pill: 42
            readonly property int padV: 7
            implicitWidth: Config.barWorkspaces ? pill : 0
            implicitHeight: Config.barWorkspaces ? Hypr.maxWs * slot + (Hypr.maxWs - 1) * gap + padV * 2 : 0

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => HyprCtl.workspace(e.angleDelta.y > 0 ? "e-1" : "e+1")
            }

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Config.containerSoft
            }

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
                        readonly property string roman: {
                            let n = ws, r = "";
                            const m = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
                            for (const p of m) while (n >= p[0]) { r += p[1]; n -= p[0]; }
                            return r;
                        }
                        width: 28; height: 28; radius: 14
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            visible: wsSlot.occupied
                            text: wsSlot.roman
                            font.family: Config.textFont; font.pixelSize: 13; font.bold: true
                            color: wsSlot.active ? Config.accentText : (wsSlot.urgent ? Config.error : Config.fg)
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

        Item { Layout.fillHeight: true }

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
                    textFormat: Text.PlainText
                    color: Config.dim
                    font.family: Config.textFont; font.pixelSize: 12
                }
            }
        }

        Item { Layout.fillHeight: true }

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
                        onEntered: trayItem.openMenu()
                        onExited: bar.hidePopout()
                        onClicked: e => {
                            if (e.button === Qt.MiddleButton) trayItem.modelData.secondaryActivate();
                            else if (e.button === Qt.RightButton) trayItem.openMenu();
                        }
                    }
                    FC.Tip { text: trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id || ""; suppressed: bar.popout !== "" }
                }
            }
        }

        Item {
            id: clockWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barClock
            Layout.topMargin: 4
            implicitWidth: Config.barClock ? clockCol.implicitWidth : 0
            implicitHeight: Config.barClock ? clockCol.implicitHeight : 0

            ColumnLayout {
                id: clockCol
                anchors.centerIn: parent
                spacing: 0
                property var now: new Date()
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

        Item {
            id: volWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barVolume
            implicitWidth: Config.barVolume ? 40 : 0
            implicitHeight: Config.barVolume ? volStat.implicitHeight : 0
            Stat {
                id: volStat
                label: "Volume"
                anchors.horizontalCenter: parent.horizontalCenter
                icon: Audio.muted ? "volume_off" : (Audio.volume > 0.5 ? "volume_up" : "volume_down")
                value: Audio.muted ? "—" : Math.round(Audio.volume * 100) + ""
                tint: Audio.muted ? Config.dim : (volMa.containsMouse ? Config.accent : Config.fg)
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
            FC.Tip { text: Audio.muted ? "Click to unmute · scroll to adjust" : "Click to mute · scroll to adjust"; suppressed: bar.popout !== "" }
        }

        Item {
            id: recWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Capture.active
            Layout.preferredHeight: Capture.active ? implicitHeight : 0
            implicitWidth: 40
            implicitHeight: recStat.implicitHeight
            Stat {
                id: recStat
                label: "Recording"
                anchors.horizontalCenter: parent.horizontalCenter
                icon: Capture.stopping ? "save" : (Capture.paused ? "pause_circle" : "fiber_manual_record")
                value: Capture.elapsedText
                tint: Capture.stopping ? Config.dim
                    : (recMa.containsMouse ? Config.accent : (Capture.paused ? Config.warning : Config.error))
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
            FC.Tip { text: Capture.paused ? "Resume recording" : "Pause recording"; suppressed: bar.popout !== "" }
        }

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
            FC.Tip { text: "Turn off game mode"; suppressed: bar.popout !== "" }
        }

        Item {
            id: kbWidget
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barKeyboard
            implicitWidth: Config.barKeyboard ? kbStat.implicitWidth : 0
            implicitHeight: Config.barKeyboard ? kbStat.implicitHeight : 0
            Rectangle {
                anchors.fill: parent; anchors.margins: -4; radius: 9
                color: "transparent"
            }
            Stat { id: kbStat; label: "Keyboard layout"; anchors.centerIn: parent; icon: "keyboard"; value: Hypr.kbLayout; tint: kbMa.containsMouse ? Config.accent : Config.fg }
            MouseArea {
                id: kbMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", Hypr.kbDevice || "all", "next"])
            }
            FC.Tip { text: "Switch keyboard layout"; suppressed: bar.popout !== "" }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.barControls
            implicitWidth: Config.barControls ? 42 : 0
            implicitHeight: Config.barControls ? ctrlCol.implicitHeight + 12 : 0
            radius: 16
            readonly property bool popActive: bar.popout === "network" || bar.popout === "bluetooth" || bar.popout === "vpn"
            color: popActive ? "transparent" : Config.containerSoft
            Behavior on color { ColorAnim {} }
            ColumnLayout {
                id: ctrlCol
                anchors.centerIn: parent
                spacing: 8

                IconBtn {
                    id: netWidget
                    label: Net.netUp ? "Network, connected" : "Network, offline"
                    icon: Net.ethernetUp && (Net.ethernetIsDefault || !Net.wifiUp) ? "settings_ethernet"
                        : (!Net.wifiOn ? "wifi_off" : (Net.wifiUp ? Net.netIcon(Net.wifiSignal) : "wifi_find"))
                    tint: Net.netUp ? Config.accent : Config.dim
                    tip: Net.wifiOn ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
                    onClicked: Net.toggleWifi()
                    onHoverIn: { bar.showPopout("network"); Net.scan(); }
                    onHoverOut: bar.hidePopout()
                }
                IconBtn {
                    id: btWidget
                    label: !Bt.enabled ? "Bluetooth, off" : (Bt.connected ? "Bluetooth, connected" : "Bluetooth, on")
                    icon: !Bt.enabled ? "bluetooth_disabled" : (Bt.connected ? "bluetooth_connected" : "bluetooth")
                    tint: Bt.connected ? Config.accent : (Bt.enabled ? Config.fg : Config.dim)
                    tip: Bt.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on"
                    onClicked: Bt.toggle()
                    onHoverIn: bar.showPopout("bluetooth")
                    onHoverOut: bar.hidePopout()
                }
                IconBtn {
                    id: vpnWidget
                    label: Net.vpnActive ? "VPN, connected" : "VPN"
                    visible: Net.hasVpn
                    Layout.preferredHeight: Net.hasVpn ? implicitHeight : 0
                    icon: Net.vpnActive ? "vpn_lock" : "vpn_key_off"
                    tint: Net.vpnActive ? Config.accent : Config.dim
                    tip: "VPN profiles"
                    onHoverIn: bar.showPopout("vpn")
                    onHoverOut: bar.hidePopout()
                }
            }
        }

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 12
        spacing: 10

        Repeater {
            model: DockStatus.btBattery
            StatusPill {
                required property var modelData
                bar: bar
                popout: "dockdev"
                icon: (modelData.icon ?? "").indexOf("gam") >= 0 ? "sports_esports" : "headphones"
                tint: modelData.battery <= 0.2 ? Config.danger : Config.fg
                count: Math.round(modelData.battery * 100) + "%"
                info: ({
                    title: modelData.name || "Bluetooth device",
                    color: modelData.battery <= 0.2 ? Config.danger : Config.accent,
                    lines: ["Battery: " + Math.round(modelData.battery * 100) + "%" + (modelData.battery <= 0.2 ? " (low)" : ""), "Connected over Bluetooth"],
                    hint: "Click to open Bluetooth"
                })
                onClicked: Frame.IpcManager._openNetwork("bluetooth")
            }
        }

        Repeater {
            model: DockStatus.drives
            StatusPill {
                required property var modelData
                bar: bar
                popout: "dockdev"
                icon: "usb"
                tint: Config.fg
                info: ({
                    title: modelData.label,
                    color: Config.accent,
                    lines: [DockStatus.fmtBytes(modelData.free) + " free of " + DockStatus.fmtBytes(modelData.size), "Mounted at " + modelData.mount],
                    hint: "",
                    actions: [
                        { label: "Open", icon: "folder_open", run: () => DockStatus.open(modelData) },
                        { label: "Eject", icon: "eject", run: () => DockStatus.eject(modelData) }
                    ]
                })
                onClicked: DockStatus.open(modelData)
            }
        }

        IconBtn {
            id: mopWidget
            icon: "cleaning_services"
            label: "Cleaning"
            tip: "Cleaning settings"
            tipAbove: true
            tint: Config.fg
            onClicked: Shell.openSettings("cleaning")
        }

        Item {
            id: batWidget
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 32
            implicitHeight: 40
            visible: Bat.has

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 1
                MatIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: Bat.charging ? "battery_android_bolt"
                        : Bat.percent >= 99 ? "battery_android_full"
                        : "battery_android_" + Math.min(6, Math.max(0, Math.floor(Bat.percent / 15)))
                    font.pixelSize: 20
                    color: {
                        if (batMa.containsMouse) return Config.accent
                        var p = Bat.percent
                        if (p <= 0)   return "#ff4444"
                        if (p >= 100) return "#00cc00"
                        if (p < 50) {
                            var t = p / 50
                            return Qt.rgba(1, 0.42 + 0.58 * t, 0.27 * (1 - t), 1)
                        }
                        var t = (p - 50) / 50
                        return Qt.rgba(1 - t, 1, 0, 1)
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Bat.percent + "%"
                    color: batMa.containsMouse ? Config.accent : Config.fg
                    font.family: Config.textFont
                    font.pixelSize: 9
                }
            }
            MouseArea {
                id: batMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.showPopout("battery")
                onEntered: bar.showPopout("battery")
                onExited: bar.hidePopout()
            }
            FC.Tip { text: "Battery & power"; above: true; suppressed: bar.popout !== "" }
        }

        IconBtn {
            id: gearWidget
            icon: "settings"
            label: "Settings"
            tipAbove: true
            tint: Config.fg
            onClicked: Shell.openSettings()
        }
    }

    }
    }

    StatusPopout {
        bar: bar; widget: bar.hoverAnchor; name: "dockdev"
        title: bar.hoverInfo.title ?? ""
        titleColor: bar.hoverInfo.color ?? Config.accent
        lines: bar.hoverInfo.lines ?? []
        hint: bar.hoverInfo.hint ?? ""
        actions: bar.hoverInfo.actions ?? []
    }
    StatusPopout {
        bar: bar; widget: healthPill; name: "health"
        title: "System health"
        titleColor: healthPill.tint
        lines: DockStatus.healthIssues.length > 0 ? ["Needs attention:"].concat(DockStatus.healthIssues)
             : ["All good", "No failed services", "Disk " + Math.round(Sys.disk * 100) + "% used", "CPU " + Sys.temp + "°C"]
        hint: "Click to open Upkeep"
    }
    StatusPopout {
        bar: bar; widget: privacyPill; name: "privacy"
        title: DockStatus.privacyActive ? "In use" : "Privacy"
        titleColor: privacyPill.tint
        lines: {
            const l = [];
            l.push("Microphone: " + (DockStatus.micInUse ? "in use" : "idle") + (DockStatus.micMuted ? " (muted)" : ""));
            l.push("Camera: " + (DockStatus.camInUse ? "in use" : "idle"));
            l.push("Screen sharing: " + (DockStatus.screenShared ? "active" : "off"));
            return l;
        }
        hint: "Click to open App permissions"
    }
    StatusPopout {
        bar: bar; widget: updatesPill; name: "updates"
        title: DockStatus.totalUpdates + " updates"
        lines: [DockStatus.repoUpdates + " from the repositories", DockStatus.aurUpdates + " from the AUR"]
        hint: "Click to open Upkeep"
    }
    StatusPopout {
        bar: bar; widget: dockerPill; name: "docker"
        title: "Docker"
        titleColor: dockerPill.tint
        lines: [DockStatus.dockerRunning > 0 ? DockStatus.dockerRunning + " container" + (DockStatus.dockerRunning > 1 ? "s" : "") + " running" : "No containers running"]
        hint: "Click to open Dev"
    }
    SysPopout        { bar: bar; widget: sysWidget }
    CpuPopout        { bar: bar; widget: cpuMeter }
    RamPopout        { bar: bar; widget: ramMeter }
    DiskPopout       { bar: bar; widget: diskMeter }
    NetInfoPopout    { bar: bar; widget: monNetWidget }
    WeatherPopout    { bar: bar; widget: weatherWidget }
    VolumePopout     { bar: bar; widget: volWidget }
    RecordingPopout  { bar: bar; widget: recWidget }
    NetworkPopout    { bar: bar; widget: netWidget }
    BluetoothPopout  { bar: bar; widget: btWidget }
    VpnPopout        { bar: bar; widget: vpnWidget }
    BatteryPopout    { bar: bar; widget: batWidget }
    TrayMenuPopout   { bar: bar; widget: bar.trayMenuAnchor }
}
