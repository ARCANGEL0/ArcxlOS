// Date & Time — clock format, automatic time and the time zone (systemd-timedated, live).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS
import "../../src" as Frame

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Date & Time"
    desc: "Clock format, automatic time and your time zone."

    readonly property bool timedated: NSS.SysLocale.timezone !== ""
    property string busy: ""
    Component.onCompleted: { NSS.SysLocale.active = true; NSS.SysLocale.refresh(); }
    QtObject { id: clock; property date now: new Date() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }

    Process {
        id: setter
        onExited: { page.busy = ""; NSS.SysLocale.refresh(); }
    }
    function utcOffset(d) {
        const m = -d.getTimezoneOffset(), a = Math.abs(m);
        return "UTC" + (m >= 0 ? "+" : "−") + String(Math.floor(a / 60)).padStart(2, "0") + ":" + String(a % 60).padStart(2, "0");
    }
    function run(what, args) { page.busy = what; setter.command = ["timedatectl"].concat(args); setter.running = true; }

    // ── clock face ─────────────────────────────────────────────────────────────
    Rectangle {
        width: parent.width; height: 150
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Column {
            x: 28; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Label { caption: true; text: page.timedated ? NSS.SysLocale.timezone.replace("_", " ") : "Local time" }
            Row {
                spacing: 10
                Label { id: hm; mono: true; font.pixelSize: 54; text: Qt.formatTime(clock.now, Frame.PrefsService.use24HourTime ? "HH:mm" : "h:mm") }
                Label { mono: true; font.pixelSize: 22; color: Ax.subtext; anchors.baseline: hm.baseline; text: Qt.formatTime(clock.now, ":ss") }
                Label { caption: true; visible: !Frame.PrefsService.use24HourTime; anchors.baseline: hm.baseline; text: Qt.formatTime(clock.now, "AP") }
            }
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Label { anchors.right: parent.right; text: Qt.formatDate(clock.now, "dddd"); font.pixelSize: Ax.fsHead; font.weight: Font.Medium }
            Label { anchors.right: parent.right; mono: true; text: Qt.formatDate(clock.now, "d MMMM yyyy"); color: Ax.subtext; font.pixelSize: Ax.fsSmall }
            Label { anchors.right: parent.right; mono: true; text: page.utcOffset(clock.now); color: Ax.faint; font.pixelSize: Ax.fsSmall }
        }
    }

    Section {
        title: "Clock"
        SRow {
            icon: "schedule"; title: "24-hour clock"; desc: "Show 14:30 instead of 2:30 PM, here and on the island"
            AxSwitch { checked: Frame.PrefsService.use24HourTime; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Frame.PrefsService.use24HourTime = on }
        }
    }

    Section {
        title: "Time"
        EmptyState {
            visible: !page.timedated
            icon: "schedule"
            title: "Time settings are unavailable"
            desc: "systemd-timedated isn't reachable, so the time zone and automatic time can't be changed from here."
        }
        SRow {
            visible: page.timedated
            icon: "sync"; title: "Set time automatically"; desc: "Keep the clock in sync with internet time servers"
            AxSwitch { checked: NSS.SysLocale.ntp; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.run("ntp", ["set-ntp", on ? "true" : "false"]) }
        }
        SRow {
            visible: page.timedated
            icon: "public"; title: "Time zone"; desc: page.busy === "tz" ? "Applying…" : "Where you are, for the local time"
            AxSelect { width: 300; anchors.verticalCenter: parent.verticalCenter
                       model: NSS.SysLocale.timezones.map(t => t.replace(/_/g, " "))
                       current: NSS.SysLocale.timezones.indexOf(NSS.SysLocale.timezone)
                       searchable: true
                       onPicked: (i) => page.run("tz", ["set-timezone", NSS.SysLocale.timezones[i]]) }
        }
    }
}
