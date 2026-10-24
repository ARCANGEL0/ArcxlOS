// Where this computer is: time zone (by hand, or found from the internet connection), whether the
// clock syncs itself, and setting the clock by hand. Zones come from tzdata's zone1970.tab, which
// also gives each zone's country and city coordinates (for the globe's pin).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.axs.ui
import qs.arc.services as NSS

Singleton {
    id: root
    property string timezone: ""
    property bool ntp: false
    property bool timedated: false        // timedatectl answers (systemd is running)
    property var zones: []                // { tz, cc: ["PT"], lon, lat, label }
    property string busy: ""
    property string error: ""
    property string detected: ""          // what the last automatic lookup found
    readonly property bool auto: Store.data.autoTimezone

    readonly property var zone: zones.find(z => z.tz === root.timezone) ?? null

    // "+384300-0090800" → { lat, lon }
    function coord(s) {
        const m = /^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/.exec(s);
        if (!m) return null;
        const lat = (+m[2] + m[3] / 60 + (m[4] ? m[4] / 3600 : 0)) * (m[1] === "-" ? -1 : 1);
        const lon = (+m[6] + m[7] / 60 + (m[8] ? m[8] / 3600 : 0)) * (m[5] === "-" ? -1 : 1);
        return { lat: lat, lon: lon };
    }
    FileView {
        path: "/usr/share/zoneinfo/zone1970.tab"
        onLoaded: {
            const out = [];
            for (const l of text().split("\n")) {
                if (!l || l[0] === "#") continue;
                const f = l.split("\t");
                const c = root.coord(f[1]);
                if (!c || !f[2]) continue;
                const city = f[2].split("/").pop().replace(/_/g, " ");
                out.push({ tz: f[2], cc: f[0].split(","), lon: c.lon, lat: c.lat, label: city + (f[3] ? " — " + f[3] : "") });
            }
            out.push({ tz: "UTC", cc: [], lon: 0, lat: 51.5, label: "Coordinated Universal Time" });
            root.zones = out.sort((a, b) => a.tz.localeCompare(b.tz));
        }
    }
    function zonesFor(cc) { return root.zones.filter(z => z.cc.indexOf(cc) >= 0); }

    Cmd { id: cmd }
    function refresh() {
        cmd.sh('timedatectl show -p Timezone -p NTP 2>/dev/null && echo ok=1; '
             + '[ -L /etc/localtime ] && echo "link=$(readlink /etc/localtime | sed "s|.*zoneinfo/||")"', [], (c, o) => {
            const kv = {}; for (const l of o.split("\n")) { const i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1); }
            root.timedated = kv.ok === "1";
            root.timezone = kv.Timezone || kv.link || "UTC";
            root.ntp = kv.NTP === "yes";
        });
    }
    Component.onCompleted: refresh()

    function done(what) {
        return (c, o, e) => { root.busy = ""; if (c !== 0) root.error = (e || o).trim().split("\n").pop() || "Couldn't change the " + what + "."; root.refresh(); };
    }
    function setZone(tz) { root.busy = "tz"; root.error = ""; cmd.run(["timedatectl", "set-timezone", tz], root.done("time zone")); }
    function setNtp(on) { root.busy = "ntp"; root.error = ""; cmd.run(["timedatectl", "set-ntp", on ? "true" : "false"], root.done("clock")); }
    // "2026-10-22 14:30:00", local time
    function setTime(stamp) { root.busy = "time"; root.error = ""; cmd.run(["timedatectl", "set-time", stamp], root.done("time")); }
    function setAuto(on) { Store.data.autoTimezone = on; if (on) root.detect(); }

    // Automatic time zone: ask a geolocation service which zone this connection is in. Skipped
    // while GhostWired is up — the answer would be the Tor exit's zone, and the lookup itself
    // would be a needless request.
    function detect() {
        if (!root.auto) return;
        cmd.sh('[ -f /run/archangelos-ghostwired/state ] && exit 3; '
             + 'curl -fsS --max-time 8 https://ipapi.co/timezone 2>/dev/null || curl -fsS --max-time 8 "http://ip-api.com/line/?fields=timezone" 2>/dev/null', [], (c, o) => {
            const tz = o.trim();
            if (c !== 0 || !/^[A-Za-z_]+(\/[A-Za-z0-9_+-]+)*$/.test(tz)) return;
            root.detected = tz;
            if (tz !== root.timezone && root.zones.some(z => z.tz === tz)) root.setZone(tz);
        });
    }
    Timer { interval: 2 * 3600 * 1000; running: root.auto; repeat: true; triggeredOnStart: true; onTriggered: root.detect() }
    // a new network may be somewhere else
    Connections { target: NSS.Net; function onDefaultDeviceChanged() { if (root.auto) netLater.restart(); } }
    Timer { id: netLater; interval: 5000; onTriggered: root.detect() }
}
