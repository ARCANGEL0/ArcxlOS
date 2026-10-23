// Windows & workspaces — how Hyprland frames and moves windows: gaps, borders, rounding, see-
// through inactive windows, blur, shadows, animations, screen tearing and adaptive sync, the
// tiling layout, and your own per-app rules. Changes apply live and are saved to
// ~/.config/archangelos/hypr/window.lua, which the compositor config loads last.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Personalize"
    title: "Windows & workspaces"
    desc: "Gaps, borders, animations, tearing and your own per-app rules."

    readonly property string fragment: Store.dir + "/hypr/window.lua"
    property var opt: ({})
    property bool loaded: false
    readonly property var rules: Store.data.wmRules

    Cmd { id: cmd }
    // every scalar we read and write, by hyprlang name
    readonly property var keys: ["general:gaps_in", "general:gaps_out", "general:border_size", "general:allow_tearing",
        "decoration:rounding", "decoration:active_opacity", "decoration:inactive_opacity",
        "decoration:blur:enabled", "decoration:blur:size", "decoration:shadow:enabled",
        "animations:enabled", "input:follow_mouse", "misc:vrr", "general:layout"]
    function load() {
        const names = page.keys.map(k => NSS.HyprCtl.optionName(k));
        cmd.sh('for k in "$@"; do printf "%s\\t" "$k"; hyprctl -j getoption "$k" 2>/dev/null | tr -d "\\n"; echo; done', names, (c, out) => {
            const o = {};
            for (const line of out.split("\n")) {
                const tab = line.indexOf("\t"); if (tab < 0) continue;
                const k = page.keys[names.indexOf(line.slice(0, tab))];
                try { const d = JSON.parse(line.slice(tab + 1)); o[k] = d.float ?? d.int ?? d.str ?? d.bool ?? d.value; } catch (e) {}
            }
            if (Object.keys(o).length) { page.opt = o; page.loaded = true; }
        });
    }
    Component.onCompleted: load()

    function num(k, d) { const v = page.opt[k]; return v === undefined || v === null ? d : Number(v); }
    function bool(k) { const v = page.opt[k]; return v === true || v === 1 || v === "1" || v === "true"; }
    function str(k, d) { const v = page.opt[k]; return v === undefined ? d : String(v); }

    function set(k, v) {
        const o = Object.assign({}, page.opt); o[k] = v; page.opt = o;
        const one = {}; one[k] = v; NSS.HyprCtl.setOptions(one);
        persist.restart();
    }
    Timer { id: persist; interval: 450; onTriggered: page.writeFragment() }

    function lstr(s) { return '"' + String(s).replace(/[\\"]/g, "\\$&") + '"'; }
    function writeFragment() {
        const b = k => page.bool(k) ? "true" : "false";
        const n = (k, d) => String(page.num(k, d));
        const L = [];
        L.push("-- Written by ArchangelOS Settings > Windows & workspaces. Edit it there.");
        L.push("hl.config({");
        L.push("    general = { gaps_in = " + n("general:gaps_in", 5) + ", gaps_out = " + n("general:gaps_out", 10)
             + ", border_size = " + n("general:border_size", 2) + ", allow_tearing = " + b("general:allow_tearing")
             + ", layout = " + page.lstr(page.str("general:layout", "master").replace(/[^a-z]/g, "")) + " },");
        L.push("    decoration = { rounding = " + n("decoration:rounding", 10)
             + ", active_opacity = " + page.num("decoration:active_opacity", 1).toFixed(2)
             + ", inactive_opacity = " + page.num("decoration:inactive_opacity", 1).toFixed(2)
             + ", blur = { enabled = " + b("decoration:blur:enabled") + ", size = " + n("decoration:blur:size", 6) + " },"
             + " shadow = { enabled = " + b("decoration:shadow:enabled") + " } },");
        L.push("    animations = { enabled = " + b("animations:enabled") + " },");
        L.push("    input = { follow_mouse = " + n("input:follow_mouse", 1) + " },");
        L.push("    misc = { vrr = " + n("misc:vrr", 0) + " },");
        L.push("})");
        for (const r of page.rules) {
            const parts = ["match = { " + (r.kind === "title" ? "title" : "class") + " = " + page.lstr(r.match) + " }"];
            if (r.float) parts.push("float = true"); else if (r.float === false) parts.push("tile = true");
            if (r.opacity !== undefined && r.opacity < 1) parts.push("opacity = " + r.opacity.toFixed(2));
            if (r.workspace) parts.push("workspace = " + page.lstr(String(r.workspace)));
            L.push("hl.window_rule({ " + parts.join(", ") + " })");
        }
        cmd.sh('mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', [page.fragment, L.join("\n")]);
    }
    function addRule(r) { Store.data.wmRules = page.rules.concat([r]); Store.data.wmRules = Store.data.wmRules; page.writeFragment(); applyRuleLive(r); }
    function removeRule(i) { Store.data.wmRules = page.rules.filter((x, j) => j !== i); page.writeFragment(); Quickshell.execDetached(["hyprctl", "reload"]); }
    function applyRuleLive(r) { Quickshell.execDetached(["hyprctl", "reload"]); }

    // ── spacing ──────────────────────────────────────────────────────────────────
    Section {
        title: "Spacing"
        SRow {
            icon: "space_bar"; title: "Gaps between windows"; desc: "The space tiled windows leave around each other"
            AxSlider { width: 220; from: 0; to: 40; stepSize: 1; suffix: " px"; value: page.num("general:gaps_in", 5); anchors.verticalCenter: parent.verticalCenter
                       onMoved: (v) => page.set("general:gaps_in", Math.round(v)) }
        }
        SRow {
            icon: "fit_screen"; title: "Gap to the screen edge"; desc: "The margin around the outside of the tiling"
            AxSlider { width: 220; from: 0; to: 60; stepSize: 1; suffix: " px"; value: page.num("general:gaps_out", 10); anchors.verticalCenter: parent.verticalCenter
                       onMoved: (v) => page.set("general:gaps_out", Math.round(v)) }
        }
        SRow {
            icon: "border_style"; title: "Border thickness"; desc: "The outline around the focused window"
            AxSlider { width: 220; from: 0; to: 8; stepSize: 1; suffix: " px"; value: page.num("general:border_size", 2); anchors.verticalCenter: parent.verticalCenter
                       onMoved: (v) => page.set("general:border_size", Math.round(v)) }
        }
        SRow {
            icon: "rounded_corner"; title: "Corner rounding"; desc: "How round the window corners are"
            AxSlider { width: 220; from: 0; to: 24; stepSize: 1; suffix: " px"; value: page.num("decoration:rounding", 10); anchors.verticalCenter: parent.verticalCenter
                       onMoved: (v) => page.set("decoration:rounding", Math.round(v)) }
        }
    }

    // ── look ─────────────────────────────────────────────────────────────────────
    Section {
        title: "Look"
        SRow {
            icon: "opacity"; title: "See-through inactive windows"
            desc: "Windows you're not using fade a little — " + Math.round(page.num("decoration:inactive_opacity", 1) * 100) + "% opaque"
            AxSlider { width: 220; from: 0.5; to: 1; valueScale: 100; suffix: "%"; value: page.num("decoration:inactive_opacity", 1); anchors.verticalCenter: parent.verticalCenter
                       onMoved: (v) => page.set("decoration:inactive_opacity", Math.round(v * 100) / 100) }
        }
        SRow {
            icon: "blur_on"; title: "Blur behind transparent windows"; desc: "Frosts what shows through a see-through window"
            AxSwitch { checked: page.bool("decoration:blur:enabled"); anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.set("decoration:blur:enabled", on) }
        }
        SRow {
            visible: page.bool("decoration:blur:enabled")
            icon: "lens_blur"; title: "Blur strength"
            AxSlider { width: 220; from: 1; to: 20; stepSize: 1; value: page.num("decoration:blur:size", 6); anchors.verticalCenter: parent.verticalCenter
                       onMoved: (v) => page.set("decoration:blur:size", Math.round(v)) }
        }
        SRow {
            icon: "contrast"; title: "Window shadows"; desc: "A soft drop shadow under each window"
            AxSwitch { checked: page.bool("decoration:shadow:enabled"); anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.set("decoration:shadow:enabled", on) }
        }
    }

    // ── behaviour ────────────────────────────────────────────────────────────────
    Section {
        title: "Behaviour"
        SRow {
            icon: "dashboard"; title: "Tiling layout"; desc: page.str("general:layout", "master") === "master" ? "Master: one main window, the rest beside it" : "Dwindle: windows split the space in half each time"
            AxSegment { options: ["Master", "Dwindle"]; current: page.str("general:layout", "master") === "dwindle" ? 1 : 0
                        onPicked: (i) => page.set("general:layout", i ? "dwindle" : "master"); anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "mouse"; title: "Focus follows the mouse"; desc: "Point at a window to focus it, without clicking"
            AxSwitch { checked: page.num("input:follow_mouse", 1) !== 0; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.set("input:follow_mouse", on ? 1 : 0) }
        }
        SRow {
            icon: "animation"; title: "Window animations"; desc: "Windows slide and fade as they open, move and close"
            AxSwitch { checked: page.bool("animations:enabled"); anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.set("animations:enabled", on) }
        }
        SRow {
            icon: "sync"; title: "Adaptive sync (VRR)"; desc: "Match the screen to the game's frame rate — fewer tears, smoother motion"
            AxSegment { options: ["Off", "On", "Fullscreen"]; current: page.num("misc:vrr", 0)
                        onPicked: (i) => page.set("misc:vrr", i); anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "tv_gen"; title: "Allow screen tearing"; desc: "Lets fullscreen games skip v-sync for the lowest latency (use with tearing-aware games)"
            AxSwitch { checked: page.bool("general:allow_tearing"); anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.set("general:allow_tearing", on) }
        }
    }

    // ── per-app rules ────────────────────────────────────────────────────────────
    Section {
        title: "Per-app rules"
        note: page.rules.length ? page.rules.length + " rules" : ""
        Repeater {
            model: page.rules
            SRow {
                required property var modelData
                required property int index
                icon: modelData.float ? "picture_in_picture" : "web_asset"
                title: modelData.match
                desc: [modelData.kind === "title" ? "by title" : "by app id",
                       modelData.float ? "floats" : modelData.float === false ? "tiles" : "",
                       modelData.opacity !== undefined && modelData.opacity < 1 ? Math.round(modelData.opacity * 100) + "% opaque" : "",
                       modelData.workspace ? "workspace " + modelData.workspace : ""].filter(x => x).join("  ·  ")
                ConfirmButton { icon: "delete"; confirmText: "Remove"; anchors.verticalCenter: parent.verticalCenter; onConfirmed: page.removeRule(index) }
            }
        }
        Item {
            property bool topDivider: page.rules.length > 0
            width: parent.width; height: addCol.implicitHeight + 28
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: addCol
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad; spacing: 10
                Label { text: "New rule"; font.weight: Font.Medium }
                Row {
                    spacing: 10
                    AxField { id: matchF; width: 220; placeholder: "App id, e.g. firefox"; anchors.verticalCenter: parent.verticalCenter }
                    AxSegment { id: byWhat; options: ["App id", "Title"]; current: 0; onPicked: (i) => current = i; anchors.verticalCenter: parent.verticalCenter }
                    Label { font.pixelSize: Ax.fsSmall; color: Ax.faint; text: "find the app id with  hyprctl activewindow"; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 10
                    AxSegment { id: howFloat; options: ["Leave as is", "Float", "Tile"]; current: 1; onPicked: (i) => current = i; anchors.verticalCenter: parent.verticalCenter }
                    Row { spacing: 6; anchors.verticalCenter: parent.verticalCenter
                          Label { text: "Opacity"; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter }
                          AxSlider { id: opF; width: 120; from: 0.4; to: 1; value: 1; anchors.verticalCenter: parent.verticalCenter }
                          Label { text: Math.round(opF.value * 100) + "%"; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; width: 36; anchors.verticalCenter: parent.verticalCenter } }
                    AxField { id: wsF; width: 100; placeholder: "Workspace"; anchors.verticalCenter: parent.verticalCenter }
                }
                AxButton {
                    text: "Add rule"; kind: "primary"; enabled_: matchF.text.trim() !== ""
                    onClicked: {
                        const r = { match: matchF.text.trim(), kind: byWhat.current === 1 ? "title" : "class" };
                        if (howFloat.current === 1) r.float = true; else if (howFloat.current === 2) r.float = false;
                        if (opF.value < 0.99) r.opacity = Math.round(opF.value * 100) / 100;
                        if (wsF.text.trim()) r.workspace = wsF.text.trim();
                        page.addRule(r); matchF.text = ""; wsF.text = "";
                    }
                }
            }
        }
    }

    Label { width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall; color: Ax.faint
            text: "Game mode temporarily overrides gaps, rounding, blur and shadows while it's on. These settings come back when you turn it off." }
}
