// App permissions — who is using the microphone, camera or screen right now and switches that cut
// them off for everyone; the wireless radios and location; and real per-app permissions for
// Flatpak apps (network, files, devices, sound…), which are the ones Linux can sandbox.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "App permissions"
    desc: "What apps can see, hear and reach — and switches to take it away."

    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    PwObjectTracker { objects: page.nodes }
    function cls(n) { return n && n.properties ? (n.properties["media.class"] || "") : ""; }
    function app(n) { const p = n.properties || {}; return p["application.name"] || p["application.process.binary"] || n.description || n.name || "An app"; }
    readonly property var recording: nodes.filter(n => cls(n) === "Stream/Input/Audio")
    readonly property var screens: nodes.filter(n => cls(n) === "Stream/Input/Video" || (cls(n) === "Video/Source" && /portal|xdph|screencast/i.test(n.name || "")))
    property var camUsers: []
    property bool camOff: false
    property bool hasCam: false
    property string error: ""

    property var radios: []            // { type, soft, hard }
    property bool geo: false           // geoclue installed
    property string geoState: ""
    property var flatpaks: []          // { id, name }
    property string fpOpen: ""
    property var fpPerms: ({})         // shared / sockets / devices / filesystems for the open app
    Cmd { id: cmd }
    Cmd { id: cmd2 }
    function loadOnce() {
        cmd2.sh('command -v geoclue >/dev/null || [ -x /usr/lib/geoclue ] && echo "geo=1"; echo "geostate=$(systemctl is-active geoclue 2>/dev/null)"; '
              + 'command -v flatpak >/dev/null && flatpak list --app --columns=application,name 2>/dev/null | sed "s/^/fp=/"', [], (c, o) => {
            page.geo = o.indexOf("geo=1") >= 0;
            page.geoState = ((/geostate=(\S*)/.exec(o) || ["", ""])[1]);
            page.flatpaks = o.split("\n").filter(l => l.startsWith("fp=")).map(l => { const f = l.slice(3).split("\t"); return { id: f[0], name: f[1] || f[0] }; })
                .sort((a, b) => a.name.localeCompare(b.name));
        });
    }
    function loadRadios() {
        cmd2.sh('rfkill -rn -o TYPE,SOFT,HARD 2>/dev/null', [], (c, o) => {
            const seen = {};
            for (const l of o.split("\n")) { const f = l.trim().split(/\s+/); if (f.length === 3) { const t = f[0]; seen[t] = seen[t] || { type: t, soft: false, hard: false }; seen[t].soft = seen[t].soft || f[1] === "blocked"; seen[t].hard = seen[t].hard || f[2] === "blocked"; } }
            page.radios = Object.values(seen);
        });
    }
    function openFp(id) {
        page.fpOpen = page.fpOpen === id ? "" : id;
        if (page.fpOpen !== "") page.readFp(id);
    }
    function readFp(id) {
        cmd2.run(["flatpak", "info", "--show-permissions", id], (c, o) => {
            const m = {}; let sec = "";
            for (const l of o.split("\n")) {
                const h = /^\[(.+)\]$/.exec(l.trim()); if (h) { sec = h[1]; continue; }
                const kv = /^(\w+)=(.*)$/.exec(l.trim()); if (kv && sec === "Context") m[kv[1]] = kv[2].split(";").filter(x => x);
                if (sec === "Session Bus Policy" && /org\.freedesktop\.Notifications=talk/.test(l)) m.notify = true;
            }
            page.fpPerms = m;
        });
    }
    function has(key, val) { return (page.fpPerms[key] || []).indexOf(val) >= 0 && (page.fpPerms[key] || []).indexOf("!" + val) < 0; }
    function override(args) { const id = page.fpOpen; cmd2.run(["flatpak", "override", "--user"].concat(args, [id]), () => page.readFp(id)); }
    Component.onCompleted: { load(); loadOnce(); loadRadios(); }
    function load() {
        cmd.sh('ls /dev/video* >/dev/null 2>&1 && echo cam=1 || echo cam=0; [ -f /etc/modprobe.d/90-archangelos-camera.conf ] && echo off=1 || echo off=0; '
             + 'for d in /dev/video*; do [ -e "$d" ] || continue; for p in $(fuser "$d" 2>/dev/null); do ps -o comm= -p "$p" 2>/dev/null; done; done | sort -u | sed "s/^/user=/"', [], (c, o) => {
            const lines = o.split("\n");
            page.hasCam = lines.indexOf("cam=1") >= 0 || lines.indexOf("off=1") >= 0;
            page.camOff = lines.indexOf("off=1") >= 0;
            page.camUsers = lines.filter(l => l.startsWith("user=")).map(l => l.slice(5));
        });
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: { page.load(); page.loadRadios(); } }

    // live strip
    Rectangle {
        width: parent.width; height: 120
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: (page.recording.length || page.camUsers.length || page.screens.length) ? Ax.alpha(Ax.danger, 0.45) : Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Row {
            anchors.centerIn: parent
            spacing: 56
            Repeater {
                model: [
                    { i: "mic", t: "Microphone", n: page.recording.length, off: NSS.Audio.sourceMuted },
                    { i: "videocam", t: "Camera", n: page.camUsers.length, off: page.camOff },
                    { i: "screen_share", t: "Screen", n: page.screens.length, off: false }
                ]
                Column {
                    required property var modelData
                    spacing: 6
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 46; height: 46; radius: 23
                        color: modelData.n > 0 ? Ax.alpha(Ax.danger, 0.18) : Ax.raised
                        border.width: 1; border.color: modelData.n > 0 ? Ax.danger : Ax.border
                        Icon { anchors.centerIn: parent; name: modelData.off ? modelData.i + "_off" : modelData.i; size: 22; color: modelData.n > 0 ? Ax.danger : Ax.subtext }
                        SequentialAnimation on opacity { running: modelData.n > 0; loops: Animation.Infinite
                            NumberAnimation { to: 0.55; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
                    }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; font.pixelSize: Ax.fsSmall }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; caption: true
                            text: modelData.off ? "blocked" : modelData.n > 0 ? "in use" : "idle"; color: modelData.n > 0 ? Ax.danger : Ax.faint }
                }
            }
        }
    }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    Section {
        title: "Microphone"
        SRow {
            icon: NSS.Audio.sourceMuted ? "mic_off" : "mic"; title: "Allow the microphone"
            desc: NSS.Audio.sourceMuted ? "Muted for every app" : "Apps can record when they ask"
            AxSwitch { checked: !NSS.Audio.sourceMuted; anchors.verticalCenter: parent.verticalCenter; onToggled: NSS.Audio.toggleMic() }
        }
        Repeater {
            model: page.recording
            SRow { required property var modelData; icon: "graphic_eq"; title: page.app(modelData); desc: "Recording now"
                   Badge { text: "live"; tone: "danger"; anchors.verticalCenter: parent.verticalCenter } }
        }
    }

    Section {
        title: "Camera"
        EmptyState { visible: !page.hasCam; icon: "videocam_off"; title: "No camera found" }
        SRow {
            visible: page.hasCam
            icon: page.camOff ? "videocam_off" : "videocam"; title: "Allow the camera"
            desc: page.camOff ? "Switched off at the driver: no app can use it, even after a restart" : "Apps can use it when they ask"
            AxSwitch { checked: !page.camOff; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => cmd.run(["/usr/lib/archangelos/axs-sec", "camera", on ? "1" : "0"], (c, o, e) => { if (c !== 0 && c !== 126) page.error = (e || o).trim(); page.load(); }) }
        }
        Repeater {
            model: page.camUsers
            SRow { required property string modelData; icon: "videocam"; title: modelData; desc: "Using the camera now"
                   Badge { text: "live"; tone: "danger"; anchors.verticalCenter: parent.verticalCenter } }
        }
    }

    Section {
        title: "Screen sharing"
        EmptyState { visible: page.screens.length === 0; icon: "screen_share"; title: "Nothing is capturing the screen"; desc: "Apps ask through the desktop portal each time they want to share it." }
        Repeater {
            model: page.screens
            SRow { required property var modelData; icon: "screen_share"; title: page.app(modelData); desc: "Capturing the screen"
                   Badge { text: "live"; tone: "danger"; anchors.verticalCenter: parent.verticalCenter } }
        }
    }

    Section {
        title: "Wireless radios"
        EmptyState { visible: page.radios.length === 0; icon: "settings_input_antenna"; title: "No radios reported" }
        Repeater {
            model: page.radios
            SRow {
                required property var modelData
                readonly property var names: ({ wlan: ["Wi-Fi", "wifi"], bluetooth: ["Bluetooth", "bluetooth"], wwan: ["Mobile broadband", "signal_cellular_alt"], gps: ["GPS", "location_on"], nfc: ["NFC", "nfc"], uwb: ["Ultra-wideband", "sensors"] })
                icon: (names[modelData.type] || [modelData.type, "settings_input_antenna"])[1]
                title: (names[modelData.type] || [modelData.type])[0]
                desc: modelData.hard ? "Switched off by a hardware switch or key" : modelData.soft ? "Off — the radio isn't transmitting" : "On"
                AxSwitch { checked: !modelData.soft && !modelData.hard; enabled_: !modelData.hard; anchors.verticalCenter: parent.verticalCenter
                           onToggled: (on) => cmd2.run(["rfkill", on ? "unblock" : "block", modelData.type], () => page.loadRadios()) }
            }
        }
    }

    Section {
        title: "Location"
        SRow {
            icon: page.geo ? "location_on" : "location_off"
            title: page.geo ? "Location service" : "No location service"
            desc: page.geo ? (page.geoState === "active" ? "Running — apps can ask where you are" : "Not running — apps can't find your location")
                           : "Nothing on this computer gives apps your location (the automatic time zone is separate, in Date & Time)"
            AxSwitch { visible: page.geo; checked: page.geoState === "active"; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => cmd2.run(["systemctl", on ? "unmask" : "mask", "--now", "geoclue"], () => page.loadOnce()) }
        }
    }

    Section {
        title: "Flatpak apps"
        note: page.flatpaks.length ? page.flatpaks.length + " sandboxed" : ""
        EmptyState { visible: page.flatpaks.length === 0; icon: "inventory_2"; title: "No Flatpak apps"
                     desc: "Apps from pacman run with your full permissions. Flatpak apps run in a sandbox, and their permissions show up here." }
        Repeater {
            model: page.flatpaks
            delegate: Column {
                id: fa
                required property var modelData
                property bool topDivider: false
                readonly property bool open: page.fpOpen === modelData.id
                readonly property var e: DesktopEntries.byId(modelData.id)
                width: parent.width
                SRow {
                    topDivider: fa.topDivider
                    title: fa.modelData.name; desc: fa.modelData.id
                    image: fa.e && fa.e.icon ? Quickshell.iconPath(fa.e.icon, true) : ""
                    icon: image === "" ? "apps" : ""
                    clickable: true; onClicked: page.openFp(fa.modelData.id)
                    Icon { name: fa.open ? "expand_less" : "expand_more"; size: 20; color: Ax.faint; anchors.verticalCenter: parent.verticalCenter }
                }
                Repeater {
                    model: fa.open ? [
                        { t: "Internet", i: "public", on: page.has("shared", "network"), set: ["--share=network"], unset: ["--unshare=network"] },
                        { t: "Sound and microphone", i: "mic", on: page.has("sockets", "pulseaudio"), set: ["--socket=pulseaudio"], unset: ["--nosocket=pulseaudio"] },
                        { t: "Camera, USB and other devices", i: "videocam", on: page.has("devices", "all"), set: ["--device=all"], unset: ["--nodevice=all"] },
                        { t: "Your home folder", i: "home", on: page.has("filesystems", "home") || page.has("filesystems", "home:rw"), set: ["--filesystem=home"], unset: ["--nofilesystem=home"] },
                        { t: "All files on the computer", i: "folder_open", on: page.has("filesystems", "host"), set: ["--filesystem=host"], unset: ["--nofilesystem=host"] },
                        { t: "Show windows on the desktop directly", i: "desktop_windows", on: page.has("sockets", "wayland") || page.has("sockets", "x11"), set: ["--socket=wayland"], unset: ["--nosocket=wayland", "--nosocket=x11", "--nosocket=fallback-x11"] },
                        { t: "Notifications", i: "notifications", on: !!page.fpPerms.notify, set: ["--talk-name=org.freedesktop.Notifications"], unset: ["--no-talk-name=org.freedesktop.Notifications"] }
                    ] : []
                    SRow {
                        required property var modelData
                        icon: modelData.i; title: modelData.t; dim: !modelData.on
                        AxSwitch { checked: modelData.on; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.override(on ? modelData.set : modelData.unset) }
                    }
                }
                SRow {
                    visible: fa.open
                    icon: "restart_alt"; title: "Reset to what the app asked for"; dim: true
                    AxButton { text: "Reset"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.override(["--reset"]) }
                }
            }
        }
    }
}
