// Date & Time — clock format, the time zone (automatic or chosen) and the clock (synced or set
// by hand, DD-MM-YYYY HH:MM:SS), through systemd-timedated.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS
import "../../frame" as Frame

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Date & Time"
    desc: "Clock format, automatic time and your time zone."

    QtObject { id: clock; property date now: new Date() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
    function utcOffset(d) {
        const m = -d.getTimezoneOffset(), a = Math.abs(m);
        return "UTC" + (m >= 0 ? "+" : "−") + String(Math.floor(a / 60)).padStart(2, "0") + ":" + String(a % 60).padStart(2, "0");
    }
    Component.onCompleted: Geo.refresh()

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
            Label { caption: true; text: Geo.timezone ? Geo.timezone.replace(/_/g, " ") : "Local time" }
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

    TimeSection { country: (Geo.zone && Geo.zone.cc.length) ? Geo.zone.cc[0] : "" }
}
