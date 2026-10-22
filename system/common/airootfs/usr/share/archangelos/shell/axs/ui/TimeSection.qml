// Time zone and clock: automatic or by hand, shared by Date & Time and Language & Region.
// `country` puts that country's zones at the top of the list.
import QtQuick
import qs.axs

Section {
    id: ts
    property string country: ""
    title: "Time"
    note: Geo.timezone

    QtObject { id: clock; property date now: new Date() }
    Timer { interval: 1000; running: ts.visible; repeat: true; onTriggered: clock.now = new Date() }

    EmptyState {
        visible: !Geo.timedated
        icon: "schedule"; title: "Time settings are unavailable"
        desc: "systemd-timedated isn't reachable, so the clock and time zone can't be changed from here."
    }
    SRow {
        visible: Geo.timedated
        icon: "public"; title: "Set the time zone automatically"
        desc: Geo.auto ? (Geo.detected ? "Found " + Geo.detected + " from your connection" : "Looks up where your internet connection is")
                         + ". Paused while GhostWired is on"
                       : "Off — you choose the zone below"
        AxSwitch { checked: Geo.auto; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => Geo.setAuto(on) }
    }
    SRow {
        visible: Geo.timedated
        icon: "travel_explore"; title: "Time zone"
        desc: Geo.busy === "tz" ? "Applying…" : Geo.zone ? Geo.zone.label : ""
        dim: Geo.auto
        AxSelect {
            width: 300; anchors.verticalCenter: parent.verticalCenter
            searchable: true
            readonly property var opts: {
                const near = ts.country ? Geo.zonesFor(ts.country) : [];
                return near.concat(Geo.zones.filter(z => near.indexOf(z) < 0));
            }
            model: opts.map(z => z.tz.replace(/_/g, " "))
            current: opts.findIndex(z => z.tz === Geo.timezone)
            opacity: Geo.auto ? 0.5 : 1
            onPicked: (i) => { if (!Geo.auto) Geo.setZone(opts[i].tz); }
        }
    }
    SRow {
        visible: Geo.timedated
        icon: "sync"; title: "Set the time automatically"
        desc: Geo.ntp ? "Synced with internet time servers" : "Off — set the date and time below"
        AxSwitch { checked: Geo.ntp; enabled_: Geo.busy === ""; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => Geo.setNtp(on) }
    }
    // by hand: DD-MM-YYYY and HH:MM:SS
    Item {
        id: manual
        property bool topDivider: false
        visible: Geo.timedated && !Geo.ntp
        width: parent.width; height: 70
        onVisibleChanged: if (visible) fill()
        Component.onCompleted: fill()
        function pad(n) { return String(n).padStart(2, "0"); }
        function fill() {
            const d = new Date();
            dd.text = pad(d.getDate()); mo.text = pad(d.getMonth() + 1); yy.text = String(d.getFullYear());
            hh.text = pad(d.getHours()); mi.text = pad(d.getMinutes()); ss.text = pad(d.getSeconds());
        }
        readonly property bool ok: /^\d{1,2}$/.test(dd.text) && /^\d{1,2}$/.test(mo.text) && /^\d{4}$/.test(yy.text)
            && /^\d{1,2}$/.test(hh.text) && /^\d{1,2}$/.test(mi.text) && /^\d{1,2}$/.test(ss.text)
            && +dd.text >= 1 && +dd.text <= 31 && +mo.text >= 1 && +mo.text <= 12 && +hh.text < 24 && +mi.text < 60 && +ss.text < 60
        Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
        Row {
            x: Ax.pad; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            component Num: AxField { width: 44 }
            Icon { name: "edit_calendar"; size: 18; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 6; height: 1 }
            Num { id: dd; placeholder: "DD" }
            Label { text: "-"; color: Ax.faint; mono: true; anchors.verticalCenter: parent.verticalCenter }
            Num { id: mo; placeholder: "MM" }
            Label { text: "-"; color: Ax.faint; mono: true; anchors.verticalCenter: parent.verticalCenter }
            Num { id: yy; width: 64; placeholder: "YYYY" }
            Item { width: 18; height: 1 }
            Icon { name: "schedule"; size: 18; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 6; height: 1 }
            Num { id: hh; placeholder: "HH" }
            Label { text: ":"; color: Ax.faint; mono: true; anchors.verticalCenter: parent.verticalCenter }
            Num { id: mi; placeholder: "MM" }
            Label { text: ":"; color: Ax.faint; mono: true; anchors.verticalCenter: parent.verticalCenter }
            Num { id: ss; placeholder: "SS" }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: Ax.pad; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            AxButton { icon: "restart_alt"; onClicked: manual.fill() }
            AxButton {
                text: Geo.busy === "time" ? "Setting…" : "Set"; kind: "primary"; enabled_: manual.ok && Geo.busy === ""
                onClicked: Geo.setTime(yy.text + "-" + manual.pad(+mo.text) + "-" + manual.pad(+dd.text) + " "
                                       + manual.pad(+hh.text) + ":" + manual.pad(+mi.text) + ":" + manual.pad(+ss.text))
            }
        }
    }
    Label {
        visible: Geo.error !== ""
        x: Ax.pad; width: parent.width - 2 * Ax.pad; bottomPadding: 14
        text: Geo.error; color: Ax.danger; font.pixelSize: Ax.fsSmall; wrapMode: Text.WordWrap
    }
}
