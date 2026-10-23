// Night light — warms the screen on a schedule. "on" keeps it warm all the time; "auto" turns it
// warm from sunset to sunrise, worked out from the region's coordinates (the same ones Date & Time
// uses), so it needs no location service. The warming itself is done by hyprsunset; this singleton
// just decides when it should run and at what temperature. Kept alive by SettingsWindow, so it
// works whether or not the settings window is open, and comes back after a sign-in.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var s: Store.data
    property bool running: false            // is hyprsunset currently meant to be on
    property bool haveTool: true

    // Sunrise/sunset for today at the region's lat/lon, in local minutes-after-midnight.
    // Standard low-precision sunrise equation (NOAA), good to a minute or two — plenty here.
    function sunTimes() {
        const z = Geo.zone;
        if (!z || z.lat === undefined || z.lon === undefined) return null;
        const now = new Date();
        const start = new Date(now.getFullYear(), 0, 0);
        const day = Math.floor((now - start) / 86400000);
        const rad = Math.PI / 180, deg = 180 / Math.PI;
        const lngHour = z.lon / 15;
        function calc(isRise) {
            const t = day + ((isRise ? 6 : 18) - lngHour) / 24;
            const M = (0.9856 * t) - 3.289;
            let L = M + (1.916 * Math.sin(M * rad)) + (0.020 * Math.sin(2 * M * rad)) + 282.634;
            L = (L + 360) % 360;
            let RA = deg * Math.atan(0.91764 * Math.tan(L * rad));
            RA = (RA + 360) % 360;
            RA += (Math.floor(L / 90) * 90) - (Math.floor(RA / 90) * 90);
            RA /= 15;
            const sinDec = 0.39782 * Math.sin(L * rad);
            const cosDec = Math.cos(Math.asin(sinDec));
            const zenith = 90.833;
            const cosH = (Math.cos(zenith * rad) - (sinDec * Math.sin(z.lat * rad))) / (cosDec * Math.cos(z.lat * rad));
            if (cosH > 1 || cosH < -1) return null;                 // sun never rises / never sets
            let H = isRise ? 360 - deg * Math.acos(cosH) : deg * Math.acos(cosH);
            H /= 15;
            const T = H + RA - (0.06571 * t) - 6.622;
            let UT = (T - lngHour) % 24; if (UT < 0) UT += 24;
            // UT (hours) → local minutes, via this machine's offset
            const offMin = -now.getTimezoneOffset();
            let local = Math.round(UT * 60) + offMin;
            local = ((local % 1440) + 1440) % 1440;
            return local;
        }
        const sr = calc(true), ss = calc(false);
        if (sr === null || ss === null) return null;
        return { rise: sr, set: ss };
    }
    function fmt(min) { const h = Math.floor(min / 60), m = min % 60; return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m; }
    readonly property var times: Geo.zones.length ? sunTimes() : null
    readonly property string sunsetText: times ? fmt(times.set) : ""
    readonly property string sunriseText: times ? fmt(times.rise) : ""

    // Should the screen be warm right now, for the current mode?
    function wanted() {
        if (s.nightMode === "on") return true;
        if (s.nightMode !== "auto") return false;
        const t = root.times;
        if (!t) return false;                                       // unknown location → leave it off
        const now = new Date();
        const mins = now.getHours() * 60 + now.getMinutes();
        // Warm between sunset and the next sunrise (wraps past midnight).
        return t.set < t.rise ? (mins >= t.set && mins < t.rise) : (mins >= t.set || mins < t.rise);
    }

    function enable(on) {
        if (on === root.running) return;
        root.running = on;
        if (on) Quickshell.execDetached(["sh", "-c",
            'command -v hyprsunset >/dev/null || exit 0; pkill -x hyprsunset 2>/dev/null; sleep 0.2; setsid -f hyprsunset -t "$1" >/dev/null 2>&1', "sh", String(s.nightTemp)]);
        else Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
    }
    function retemp() {   // change temperature while it's on
        if (!root.running) return;
        Quickshell.execDetached(["sh", "-c",
            'command -v hyprsunset >/dev/null || exit 0; pkill -x hyprsunset 2>/dev/null; sleep 0.2; setsid -f hyprsunset -t "$1" >/dev/null 2>&1', "sh", String(s.nightTemp)]);
    }
    function sync() { root.enable(root.wanted()); }

    // React to the user's choices and to the clock.
    Connections {
        target: Store.data
        function onNightModeChanged() { root.sync(); }
        function onNightTempChanged() { if (root.running) root.retemp(); }
    }
    Timer { interval: 60000; running: root.s.nightMode === "auto"; repeat: true; onTriggered: root.sync() }
    // Settle after start-up once the region data has loaded, then apply.
    Timer { interval: 1500; running: true; repeat: false; onTriggered: root.sync() }
    Component.onCompleted: root.sync()
}
