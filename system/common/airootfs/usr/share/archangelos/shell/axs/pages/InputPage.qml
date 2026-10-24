// Keyboard & Mouse — layouts and how to switch them, typing repeat, pointer and touchpad.
// Layouts go through ArcShell's input service; pointer options are applied live and saved to
// ~/.config/archangelos/hypr/pointer.lua, which the compositor config loads last.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Devices"
    title: "Keyboard & Mouse"
    desc: "Layouts, typing, pointer speed and touchpad gestures."

    readonly property string fragment: Store.dir + "/hypr/pointer.lua"
    property var opt: ({})             // current pointer options, by hyprlang name
    property bool haveOpts: false
    property bool touchpad: false
    property var names: ({})           // xkb layout code → "English (US)"

    Cmd { id: cmd }
    Component.onCompleted: {
        NSS.Input.active = true;
        NSS.Input.refresh();
        cmd.sh("sed -n '/^! layout/,/^ *$/p' /usr/share/X11/xkb/rules/evdev.lst 2>/dev/null | tail -n +2", [], (c, o) => {
            const m = {};
            for (const l of o.split("\n")) { const r = /^\s+(\S+)\s+(.+)$/.exec(l); if (r) m[r[1]] = r[2].trim(); }
            page.names = m;
        });
        page.readOpts();
    }
    Component.onDestruction: NSS.Input.active = false

    readonly property var keys: ["input:sensitivity", "input:accel_profile", "input:natural_scroll", "input:left_handed",
        "input:repeat_rate", "input:repeat_delay", "input:touchpad:natural_scroll", "input:touchpad:tap-to-click",
        "input:touchpad:disable_while_typing", "input:touchpad:scroll_factor"]
    function readOpts() {
        const names = page.keys.map(k => NSS.HyprCtl.optionName(k));
        cmd.sh('for k in "$@"; do printf "%s\\t" "$k"; hyprctl -j getoption "$k" 2>/dev/null | tr -d "\\n"; echo; done; '
             + 'echo "devices"; hyprctl -j devices 2>/dev/null | tr -d "\\n"', names, (c, out) => {
            const o = {};
            const parts = out.split("\ndevices");
            const lines = parts[0].split("\n");
            for (let i = 0; i < lines.length; i++) {
                const tab = lines[i].indexOf("\t");
                if (tab < 0) continue;
                const k = page.keys[names.indexOf(lines[i].slice(0, tab))];
                try {
                    const d = JSON.parse(lines[i].slice(tab + 1));
                    o[k] = d.float ?? d.int ?? d.str ?? d.bool ?? d.value;
                } catch (e) {}
            }
            try { page.touchpad = (JSON.parse(parts[1] || "{}").mice ?? []).some(m => /touchpad|trackpad/i.test(m.name)); } catch (e) {}
            if (Object.keys(o).length) { page.opt = o; page.haveOpts = true; }
        });
    }
    function val(k, d) {
        const v = page.opt[k];
        // a zero repeat rate or delay would make the keyboard unusable; treat it as unset
        if (v === undefined || ((k === "input:repeat_rate" || k === "input:repeat_delay") && !(v > 0))) return d;
        return v;
    }
    function bool(k) { const v = page.opt[k]; return v === true || v === 1 || v === "true"; }
    function setOpt(k, v) {
        const o = Object.assign({}, page.opt); o[k] = v; page.opt = o;
        const one = {}; one[k] = v;
        NSS.HyprCtl.setOptions(one);
        persist.restart();
    }
    Timer { id: persist; interval: 400; onTriggered: page.writeFragment() }
    function writeFragment() {
        const b = k => page.bool(k) ? "true" : "false";
        const n = (k, d) => String(Number(page.val(k, d)));
        const body = "-- Written by ArchangelOS Settings > Keyboard & Mouse. Edit it there.\n"
            + "hl.config({ input = {\n"
            + "    sensitivity = " + n("input:sensitivity", 0) + ",\n"
            + "    accel_profile = \"" + String(page.val("input:accel_profile", "")).replace(/[^a-z]/g, "") + "\",\n"
            + "    natural_scroll = " + b("input:natural_scroll") + ",\n"
            + "    left_handed = " + b("input:left_handed") + ",\n"
            + "    repeat_rate = " + n("input:repeat_rate", 25) + ",\n"
            + "    repeat_delay = " + n("input:repeat_delay", 600) + ",\n"
            + "    touchpad = {\n"
            + "        natural_scroll = " + b("input:touchpad:natural_scroll") + ",\n"
            + "        tap_to_click = " + b("input:touchpad:tap-to-click") + ",\n"
            + "        disable_while_typing = " + b("input:touchpad:disable_while_typing") + ",\n"
            + "        scroll_factor = " + n("input:touchpad:scroll_factor", 1) + ",\n"
            + "    },\n"
            + "} })\n";
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "sh", page.fragment, body]);
    }

    function layoutName(code) { return page.names[code] || code.toUpperCase(); }
    readonly property var optList: NSS.Input.options.split(",").filter(o => o)
    function withOpt(prefixes, value) {
        const rest = page.optList.filter(o => !prefixes.some(p => o.startsWith(p)));
        if (value) rest.push(value);
        NSS.Input.setOptions(rest.join(","));
    }
    readonly property var switchKeys: [["", "Only from the bar"], ["grp:win_space_toggle", "Super + Space"], ["grp:alt_shift_toggle", "Alt + Shift"],
                                       ["grp:ctrl_shift_toggle", "Ctrl + Shift"], ["grp:caps_toggle", "Caps Lock"], ["grp:alts_toggle", "Both Alt keys"]]
    readonly property var capsModes: [["", "Caps Lock"], ["caps:escape", "Escape"], ["ctrl:nocaps", "Ctrl"], ["caps:backspace", "Backspace"], ["caps:none", "Nothing"]]
    function currentOf(list, prefixes) {
        const hit = page.optList.find(o => prefixes.some(p => o.startsWith(p)));
        return Math.max(0, list.findIndex(e => e[0] === (hit || "")));
    }

    // ── layouts ────────────────────────────────────────────────────────────────
    Section {
        title: "Keyboard layouts"
        note: NSS.Input.activeKeymap
        EmptyState {
            visible: NSS.Input.layouts.length === 0
            icon: "keyboard"; title: "No keyboard reported"
            desc: "Layouts come from Hyprland and show up here once the desktop runs on it."
        }
        Repeater {
            model: NSS.Input.layouts
            SRow {
                required property string modelData
                required property int index
                icon: index === NSS.Input.activeIndex ? "keyboard" : "keyboard_alt"
                title: page.layoutName(modelData)
                desc: modelData + ((NSS.Input.variants[index] || "") !== "" ? " · " + NSS.Input.variants[index] : "") + (index === 0 ? "  ·  default" : "")
                Badge { visible: index === NSS.Input.activeIndex; text: "in use"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                AxButton { icon: "arrow_upward"; visible: index > 0; anchors.verticalCenter: parent.verticalCenter; onClicked: NSS.Input.moveLayout(index, -1) }
                AxButton { icon: "check"; visible: index !== NSS.Input.activeIndex; anchors.verticalCenter: parent.verticalCenter; onClicked: NSS.Input.setLayout(index) }
                AxButton { icon: "close"; visible: NSS.Input.layouts.length > 1; kind: "danger"; anchors.verticalCenter: parent.verticalCenter; onClicked: NSS.Input.removeLayout(index) }
            }
        }
        SRow {
            visible: NSS.Input.layouts.length > 0
            icon: "add"; title: "Add a layout"
            AxSelect {
                width: 280; anchors.verticalCenter: parent.verticalCenter
                searchable: true
                placeholder: "Choose a language…"
                readonly property var codes: NSS.Input.catalog.filter(c => NSS.Input.layouts.indexOf(c) < 0)
                                             .sort((a, b) => page.layoutName(a).localeCompare(page.layoutName(b)))
                model: codes.map(c => page.layoutName(c))
                current: -1
                onPicked: (i) => NSS.Input.addLayout(codes[i])
            }
        }
        SRow {
            visible: NSS.Input.layouts.length > 1
            icon: "swap_horiz"; title: "Switch layouts with"
            AxSelect { width: 220; anchors.verticalCenter: parent.verticalCenter
                       model: page.switchKeys.map(e => e[1]); current: page.currentOf(page.switchKeys, ["grp:"])
                       onPicked: (i) => page.withOpt(["grp:"], page.switchKeys[i][0]) }
        }
        SRow {
            visible: NSS.Input.layouts.length > 0
            icon: "keyboard_capslock"; title: "Caps Lock key acts as"
            AxSelect { width: 220; anchors.verticalCenter: parent.verticalCenter
                       model: page.capsModes.map(e => e[1]); current: page.currentOf(page.capsModes, ["caps:", "ctrl:nocaps"])
                       onPicked: (i) => page.withOpt(["caps:", "ctrl:nocaps"], page.capsModes[i][0]) }
        }
        SRow {
            visible: NSS.Input.layouts.length > 0
            icon: "dialpad"; title: "Num Lock on at start"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: NSS.Input.numlock; onToggled: (on) => NSS.Input.setNumlock(on) }
        }
    }

    // ── typing ─────────────────────────────────────────────────────────────────
    Section {
        visible: page.haveOpts
        title: "Typing"
        SRow {
            icon: "timer"; title: "Repeat delay"; desc: "How long to hold a key before it repeats"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.val("input:repeat_delay", 600)
                       from: 150; to: 1000; stepSize: 10; suffix: " ms"; onReleased: (v) => page.setOpt("input:repeat_delay", Math.round(v)) }
        }
        SRow {
            icon: "fast_forward"; title: "Repeat rate"; desc: "How fast a held key repeats"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.val("input:repeat_rate", 25)
                       from: 5; to: 80; stepSize: 1; suffix: " /s"; onReleased: (v) => page.setOpt("input:repeat_rate", Math.round(v)) }
        }
        Item {
            property bool topDivider: false
            width: parent.width; height: 62
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            AxField { x: Ax.pad; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 2 * Ax.pad; icon: "edit"; placeholder: "Type here to try it out" }
        }
    }

    // ── pointer ────────────────────────────────────────────────────────────────
    Section {
        visible: page.haveOpts
        title: "Mouse"
        SRow {
            icon: "mouse"; title: "Pointer speed"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.val("input:sensitivity", 0)
                       from: -1; to: 1; stepSize: 0.05; decimals: 2; onReleased: (v) => page.setOpt("input:sensitivity", Math.round(v * 100) / 100) }
        }
        SRow {
            icon: "trending_up"; title: "Acceleration"; desc: "Off moves the pointer exactly as far as you move the mouse"
            AxSegment { anchors.verticalCenter: parent.verticalCenter
                        options: ["Default", "Adaptive", "Off"]
                        current: ["", "adaptive", "flat"].indexOf(String(page.val("input:accel_profile", ""))) < 0 ? 0 : ["", "adaptive", "flat"].indexOf(String(page.val("input:accel_profile", "")))
                        onPicked: (i) => page.setOpt("input:accel_profile", ["", "adaptive", "flat"][i]) }
        }
        SRow {
            icon: "swap_vert"; title: "Natural scrolling"; desc: "Content follows your fingers, like on a phone"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: page.bool("input:natural_scroll"); onToggled: (on) => page.setOpt("input:natural_scroll", on) }
        }
        SRow {
            icon: "back_hand"; title: "Left-handed"; desc: "Swap the left and right buttons"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: page.bool("input:left_handed"); onToggled: (on) => page.setOpt("input:left_handed", on) }
        }
    }

    Section {
        visible: page.haveOpts && page.touchpad
        title: "Touchpad"
        SRow {
            icon: "touch_app"; title: "Tap to click"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: page.bool("input:touchpad:tap-to-click"); onToggled: (on) => page.setOpt("input:touchpad:tap-to-click", on) }
        }
        SRow {
            icon: "swap_vert"; title: "Natural scrolling"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: page.bool("input:touchpad:natural_scroll"); onToggled: (on) => page.setOpt("input:touchpad:natural_scroll", on) }
        }
        SRow {
            icon: "keyboard_hide"; title: "Ignore while typing"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: page.bool("input:touchpad:disable_while_typing"); onToggled: (on) => page.setOpt("input:touchpad:disable_while_typing", on) }
        }
        SRow {
            icon: "unfold_more"; title: "Scroll speed"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.val("input:touchpad:scroll_factor", 1)
                       from: 0.2; to: 3; stepSize: 0.1; decimals: 1; suffix: "×"; onReleased: (v) => page.setOpt("input:touchpad:scroll_factor", Math.round(v * 10) / 10) }
        }
    }
}
