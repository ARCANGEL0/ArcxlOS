// Gaming — the things that matter when you play: game mode, your launchers, the performance
// overlay (MangoHud), Proton/Wine compatibility and controllers. Game mode goes through
// ArcShell's own service; the overlay is written to ~/.config/MangoHud/MangoHud.conf.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Gaming"
    title: "Gaming"
    desc: "Game mode, your launchers, the overlay and controllers."

    readonly property string home: Quickshell.env("HOME") || ""
    property var have: ({})                 // program → bool
    property var pads: []                   // connected gamepads
    property var hud: ({})                  // MangoHud options present in the config
    property bool hudLoaded: false
    property string notice: ""

    Cmd { id: cmd }
    Cmd { id: pad }

    readonly property var launchers: [
        { k: "steam", name: "Steam", icon: "sports_esports", run: "steam", desc: "Valve's store and library" },
        { k: "lutris", name: "Lutris", icon: "casino", run: "lutris", desc: "Installers for Windows and classic games" },
        { k: "heroic", name: "Heroic", icon: "shield", run: "heroic", desc: "Epic, GOG and Amazon games" },
        { k: "bottles", name: "Bottles", icon: "science", run: "bottles", desc: "Run Windows apps in tidy prefixes" },
        { k: "protonup-qt", name: "ProtonUp-Qt", icon: "upgrade", run: "protonup-qt", desc: "Install Proton-GE and Wine-GE" }
    ]
    readonly property var probe: ["steam", "lutris", "heroic", "bottles", "protonup-qt", "mangohud", "gamescope", "gamemoded", "wine", "vkbasalt", "goverlay"]

    function load() {
        cmd.sh('for p in "$@"; do command -v "$p" >/dev/null 2>&1 && echo "$p=1" || echo "$p=0"; done', page.probe, (c, o) => {
            const m = {}; for (const l of o.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1) === "1"; }
            page.have = m;
        });
        page.loadHud();
        page.loadPads();
    }
    function loadPads() {
        pad.sh('grep -lE "Handlers=.*js[0-9]" /sys/class/input/*/device/../uevent 2>/dev/null >/dev/null; '
             + 'for d in /sys/class/input/js*; do [ -e "$d" ] || continue; n="$d/device/name"; [ -f "$n" ] || n="$d/../name"; '
             + '[ -f "$n" ] && echo "$(basename "$d")|$(cat "$n")"; done', [], (c, o) => {
            page.pads = o.split("\n").filter(l => l.includes("|")).map(l => ({ dev: l.split("|")[0], name: l.split("|").slice(1).join("|") }));
        });
    }
    readonly property string hudPath: page.home + "/.config/MangoHud/MangoHud.conf"
    function loadHud() {
        cmd.sh('cat "$1" 2>/dev/null', [page.hudPath], (c, o) => {
            const m = {};
            for (let line of o.split("\n")) { line = line.trim(); if (!line || line.startsWith("#")) continue;
                const i = line.indexOf("="); const k = i < 0 ? line : line.slice(0, i); m[k.trim()] = i < 0 ? true : line.slice(i + 1).trim(); }
            page.hud = m; page.hudLoaded = true;
        });
    }
    Component.onCompleted: load()

    // the overlay rows people actually flip, each a MangoHud key
    readonly property var hudRows: [
        { k: "fps", t: "Frame rate", d: "Frames per second, the headline number" },
        { k: "frame_timing", t: "Frame-time graph", d: "A line that spikes on stutter" },
        { k: "gpu_stats", t: "GPU load & clock", d: "How hard the graphics card is working" },
        { k: "gpu_temp", t: "GPU temperature", d: "" },
        { k: "cpu_stats", t: "CPU load & clock", d: "" },
        { k: "cpu_temp", t: "CPU temperature", d: "" },
        { k: "ram", t: "Memory use", d: "" },
        { k: "vram", t: "Video memory", d: "" },
        { k: "gpu_power", t: "GPU power draw", d: "" }
    ]
    function hudOn(k) { return page.hud[k] !== undefined; }
    function setHud(k, on) {
        const h = Object.assign({}, page.hud);
        if (on) h[k] = true; else delete h[k];
        page.writeHud(h);
    }
    function writeHud(h) {
        page.hud = h;
        const order = page.hudRows.map(r => r.k);
        const keys = Object.keys(h).sort((a, b) => { const ia = order.indexOf(a), ib = order.indexOf(b); return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib); });
        const lines = ["# Written by ArchangelOS Settings > Gaming. Overlay options for MangoHud."];
        for (const k of keys) lines.push(h[k] === true ? k : k + "=" + h[k]);
        cmd.sh('mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', [page.hudPath, lines.join("\n")], (c) => {
            if (c === 0) { page.notice = "Overlay saved — add  mangohud  before a game, or turn it on per-launcher"; noticeT.restart(); }
        });
    }
    readonly property var presets: ({
        off: {},
        light: { fps: true, frame_timing: true },
        full: { fps: true, frame_timing: true, gpu_stats: true, gpu_temp: true, cpu_stats: true, cpu_temp: true, ram: true, vram: true }
    })
    function applyPreset(name) {
        const p = page.presets[name]; const h = {};
        for (const k in p) h[k] = true;
        // keep any extra keys the user added by hand that aren't in our row list
        for (const k in page.hud) if (!page.hudRows.some(r => r.k === k)) h[k] = page.hud[k];
        page.writeHud(h);
    }
    readonly property int hudCount: page.hudRows.filter(r => page.hudOn(r.k)).length

    Timer { id: noticeT; interval: 5000; onTriggered: page.notice = "" }
    Label { visible: page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.notice; color: Ax.accent; font.pixelSize: Ax.fsSmall }

    // ── game mode ────────────────────────────────────────────────────────────────
    Section {
        title: "Game mode"
        SRow {
            icon: NSS.GameMode.enabled ? "rocket_launch" : "videogame_asset"
            title: NSS.GameMode.enabled ? "On — nothing gets in the way" : "Off"
            desc: "Drops animations, blur, shadows, rounding and gaps, lets frames tear for lower latency, and holds back notifications and auto-lock while you play."
            AxSwitch { checked: NSS.GameMode.enabled; anchors.verticalCenter: parent.verticalCenter; onToggled: NSS.GameMode.toggle() }
        }
        SRow {
            icon: "memory"; title: "feral GameMode"
            desc: page.have.gamemoded ? "Installed — games that support it get the CPU governor on performance automatically" : "Not installed — add  gamemode  for automatic CPU boosting in supported games"
            Badge { text: page.have.gamemoded ? "installed" : "missing"; tone: page.have.gamemoded ? "ok" : "neutral"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "bolt"; title: "Power mode"; desc: "Set the whole machine to performance in Power & Battery"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("power")
        }
    }

    // ── launchers ────────────────────────────────────────────────────────────────
    Section {
        title: "Launchers"
        Repeater {
            model: page.launchers
            SRow {
                id: lrow
                required property var modelData
                readonly property bool got: page.have[modelData.k] === true
                icon: modelData.icon; title: modelData.name; desc: modelData.desc; dim: !lrow.got
                Badge { visible: !lrow.got; text: "not installed"; tone: "neutral"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { visible: lrow.got; text: "Open"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                           onClicked: Quickshell.execDetached(["sh", "-c", modelData.run + " &"]) }
            }
        }
    }

    // ── overlay ──────────────────────────────────────────────────────────────────
    Section {
        title: "Performance overlay"
        note: page.have.mangohud ? (page.hudCount ? page.hudCount + " shown" : "nothing shown") : "MangoHud missing"
        SRow {
            icon: "insights"; title: "MangoHud"
            desc: page.have.mangohud ? "An overlay of frame rate and load on top of any Vulkan or OpenGL game"
                                     : "Not installed — add  mangohud  (and  lib32-mangohud  for 32-bit games)"
            AxSegment { visible: !!page.have.mangohud; options: ["Off", "Light", "Full"]
                        current: page.hudCount === 0 ? 0 : page.hudCount <= 2 ? 1 : 2
                        onPicked: (i) => page.applyPreset(["off", "light", "full"][i]); anchors.verticalCenter: parent.verticalCenter }
            AxButton { visible: !!page.have.goverlay; text: "GOverlay"; anchors.verticalCenter: parent.verticalCenter; onClicked: Quickshell.execDetached(["sh", "-c", "goverlay &"]) }
        }
        Repeater {
            model: page.have.mangohud ? page.hudRows : []
            SRow {
                required property var modelData
                icon: "check_box"; title: modelData.t; desc: modelData.d
                AxSwitch { checked: page.hudOn(modelData.k); anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.setHud(modelData.k, on) }
            }
        }
        SRow {
            visible: !!page.have.mangohud
            icon: "terminal"; title: "How to show it"
            desc: "Run a game with  mangohud %command%  in Steam's launch options, or  mangohud <game>  from a terminal. Steam ▸ right-click a game ▸ Properties ▸ Launch Options."
        }
    }

    // ── compatibility ────────────────────────────────────────────────────────────
    Section {
        title: "Windows games (Proton / Wine)"
        SRow {
            icon: "cable"; title: "Wine"; desc: page.have.wine ? "Installed — runs Windows programs directly" : "Not installed — Steam's Proton works without it; add  wine  for Lutris and Bottles"
            Badge { text: page.have.wine ? "installed" : "optional"; tone: page.have.wine ? "ok" : "neutral"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "filter_vintage"; title: "VkBasalt"; desc: page.have.vkbasalt ? "Installed — post-processing (sharpening, FXAA) for Vulkan games" : "Not installed — add  vkbasalt  for sharpening and colour filters"
            Badge { text: page.have.vkbasalt ? "installed" : "optional"; tone: page.have.vkbasalt ? "ok" : "neutral"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "crop_free"; title: "Gamescope"; desc: page.have.gamescope ? "Installed — a micro-compositor for upscaling and frame limiting. Wrap a game with  gamescope -W 2560 -H 1440 -- <game>" : "Not installed — add  gamescope  for resolution upscaling and a clean fullscreen"
            Badge { text: page.have.gamescope ? "installed" : "optional"; tone: page.have.gamescope ? "ok" : "neutral"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "developer_board"; title: "Graphics driver"; desc: "Vulkan and GPU details are in Graphics"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("graphics")
        }
    }

    // ── controllers ──────────────────────────────────────────────────────────────
    Section {
        title: "Controllers"
        note: page.pads.length ? page.pads.length + " connected" : ""
        EmptyState { visible: page.pads.length === 0; icon: "sports_esports"; title: "No controllers connected"; desc: "Plug in a gamepad or pair one over Bluetooth — it'll show up here." }
        Repeater {
            model: page.pads
            SRow {
                required property var modelData
                icon: "stadia_controller"; title: modelData.name; desc: "/dev/input/" + modelData.dev
                Badge { text: "ready"; tone: "ok"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        SRow {
            icon: "bluetooth"; title: "Pair a wireless controller"; desc: "Xbox, DualSense and 8BitDo pads pair in Bluetooth"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("bluetooth")
        }
    }
}
