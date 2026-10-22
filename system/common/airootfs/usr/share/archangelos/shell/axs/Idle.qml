// Idle behaviour — dim, lock, screen off, sleep — written out as hypridle's config.
// Locking always goes through archangelos-lock, the same command as Super+L.
pragma Singleton

import QtQuick
import Quickshell
import qs.ns.services as NSS

Singleton {
    id: root
    readonly property var s: Store.data
    readonly property string confPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hypridle.conf"
    readonly property string lockCmd: "/usr/bin/archangelos-lock"

    // The ladders the pages offer, in seconds (0 = never).
    readonly property var ladder: [60, 120, 180, 300, 600, 900, 1200, 1800, 3600, 0]
    function label(sec) {
        if (sec <= 0) return "Never";
        if (sec < 60) return sec + " seconds";
        if (sec < 3600) return (sec / 60) + (sec === 60 ? " minute" : " minutes");
        return (sec / 3600) + (sec === 3600 ? " hour" : " hours");
    }
    // Index of the ladder step closest to a stored value (a hand-edited 330 shows as 5 minutes).
    function nearest(list, sec) {
        if (sec <= 0) return list.indexOf(0);
        let best = -1, d = 1e9;
        for (let i = 0; i < list.length; i++) if (list[i] > 0 && Math.abs(list[i] - sec) < d) { d = Math.abs(list[i] - sec); best = i; }
        return best;
    }
    function pick(key, sec) { root.s[key] = sec; root.write(); }
    function set(key, v) { root.s[key] = v; root.write(); }

    // Under a Lua compositor config `hyprctl dispatch dpms` is refused; it takes an hl.dsp call.
    function dpms(on) {
        return NSS.HyprCtl.lua ? "hyprctl eval 'hl.dispatch(hl.dsp.dpms({ action = \"" + (on ? "on" : "off") + "\" }))'"
                               : "hyprctl dispatch dpms " + (on ? "on" : "off");
    }
    function write() {
        const L = [];
        L.push("# Written by ArchangelOS Settings (Power & Battery, Lock Screen).");
        L.push("# Rewritten whenever those change; edit them there.");
        L.push("general {");
        L.push("    lock_cmd = " + root.lockCmd);
        if (s.lockOnSleep) L.push("    before_sleep_cmd = loginctl lock-session");
        L.push("    after_sleep_cmd = " + root.dpms(true));
        L.push("}");
        const listener = (t, on, off) => {
            if (t <= 0) return;
            L.push("", "listener {", "    timeout = " + t, "    on-timeout = " + on);
            if (off) L.push("    on-resume = " + off);
            L.push("}");
        };
        listener(s.dimAfter, "brightnessctl -s set 10", "brightnessctl -r");
        if (s.autoLock) listener(s.lockAfter, "loginctl lock-session");
        listener(s.screenOffAfter, root.dpms(false), root.dpms(true) + " && brightnessctl -r");
        listener(s.suspendAfter, "systemctl suspend");
        const body = L.join("\n") + "\n";
        // Write, then restart hypridle so the new timers count from now.
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1" && { pkill -x hypridle; sleep 0.3; setsid -f hypridle >/dev/null 2>&1; }',
            "sh", root.confPath, body]);
    }
    Component.onCompleted: if (Store.fresh) root.write()
    Connections { target: Store; function onFreshChanged() { if (Store.fresh) root.write(); } }
    function lockNow() { Quickshell.execDetached([root.lockCmd]); }
}
