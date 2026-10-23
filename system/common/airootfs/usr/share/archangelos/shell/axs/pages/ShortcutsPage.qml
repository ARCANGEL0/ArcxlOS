// Keyboard shortcuts — every bind of the shell that is running. ArcShell's own map is read from
// keybinds.lua; changing keys, turning a bind off or adding a new one is saved to
// ~/.config/archangelos/hypr/keys.lua (keybinds.lua and archangelos.lua load it), then Hyprland
// reloads. A theme that brings its own keybinds is shown as it is, read from `hyprctl binds`.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Keyboard shortcuts"
    desc: "Every shortcut on this desktop — change the keys, turn one off, or add your own."

    readonly property string cfg: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string dir: cfg + "/archangelos/hypr"
    property var shell: null                   // { id, name, keys } from archangelos-shell list
    readonly property bool own: !shell || shell.id === "archangelos" || !shell.keys
    property var defaults: []                  // { keys, desc, action, cat, flags }
    property var foreign: []                   // a theme's binds, read-only
    property var remap: ({})                   // original keys → new keys | false
    property var custom: []                    // { keys, cmd, description }
    property bool loaded: false
    property string query: ""
    property string editing: ""                // keys of the bind being edited, "+new" for a new one
    property string notice: ""
    property string error: ""

    Cmd { id: cmd }

    // ---- reading ----------------------------------------------------------------------------
    function load() {
        cmd.sh('archangelos-shell list 2>/dev/null | grep "|1$" | head -n1; echo "--src"; '
             + 'f="$1/hypr/config/keybinds.lua"; [ -f "$f" ] || f=/usr/share/archangelos/hypr/keybinds.lua; cat "$f" 2>/dev/null; '
             + 'echo "--user"; cat "$2/keys.json" 2>/dev/null; echo "--live"; '
             + 'command -v hyprctl >/dev/null && hyprctl binds -j 2>/dev/null', [page.cfg, page.dir], (c, o) => {
            const at = (t) => o.indexOf(t);
            const head = o.slice(0, at("--src")).trim().split("|");
            page.shell = head.length >= 7 ? { id: head[0], name: head[1], keys: head[4] === "1" } : null;
            page.defaults = page.parseLua(o.slice(at("--src") + 5, at("--user")));
            try { const u = JSON.parse(o.slice(at("--user") + 6, at("--live")) || "{}"); page.remap = u.remap || {}; page.custom = u.custom || []; }
            catch (e) { page.remap = {}; page.custom = []; }
            let live = [];
            try { live = JSON.parse(o.slice(at("--live") + 6) || "[]"); } catch (e) {}
            const mine = page.custom.map(b => page.norm(b.keys));
            page.foreign = live.map(b => ({ keys: page.fromMask(b.modmask, b.key), desc: b.description || b.dispatcher,
                                            action: (b.dispatcher || "") + (b.arg ? " " + b.arg : ""), cat: "Shortcuts", flags: [] }))
                               .filter(b => mine.indexOf(page.norm(b.keys)) < 0);
            page.loaded = true;
        });
    }
    Component.onCompleted: load()

    // keybinds.lua → rows. Section comments ("-- Apps") become the categories; the workspace
    // for-loop is expanded so each of its binds can be changed on its own.
    function parseLua(src) {
        const out = [];
        let cat = "General", loop = null;
        const unq = s => s.replace(/\\"/g, '"').replace(/\\\\/g, "\\");
        for (const raw of src.split("\n")) {
            const l = raw.trim();
            let m;
            if ((m = /^-- ([A-Z][^.:;`]{1,32})$/.exec(l))) { cat = m[1].trim(); continue; }
            if ((m = /^for i = (\d+), (\d+) do/.exec(l))) { loop = [+m[1], +m[2]]; continue; }
            if (l === "end") { loop = null; continue; }
            if (!(m = /^hl\.bind\((mod \.\. )?"([^"]*)"( \.\. i)?\s*,\s*/.exec(l))) continue;
            const keys = (m[1] ? "SUPER" : "") + m[2], perI = !!m[3];
            const rest = l.slice(m[0].length);
            const oi = rest.lastIndexOf(", {");
            const action = oi > 0 ? rest.slice(0, oi) : rest;
            const opts = oi > 0 ? rest.slice(oi) : "";
            const d = /description = "([^"]*)"( \.\. i)?/.exec(opts);
            const flags = ["locked", "repeating", "mouse"].filter(f => new RegExp(f + " = true").test(opts));
            let act = action;
            const ex = /exec_cmd\("((?:[^"\\]|\\.)*)"\)/.exec(action);
            if (ex) { act = unq(ex[1]); if (act.length > 64) act = /^bash -c/.test(act) ? "Runs a small script" : act.slice(0, 62) + "…"; }
            else if ((m = /^first_of\((.*)\)$/.exec(action))) act = "First installed of " + m[1].replace(/"/g, "");
            else if ((m = /^hl\.dsp\.([a-z_.]+)/.exec(action))) act = m[1].replace(/\./g, " › ");
            const one = (k, n) => out.push({ keys: k, desc: d ? d[1] + (d[2] ? n : "") : act, action: act, cat: cat, flags: flags });
            if (loop && perI) for (let i = loop[0]; i <= loop[1]; i++) one(keys + i, i);
            else one(keys, "");
        }
        out.push({ keys: "SUPER + CTRL + ALT + A", desc: "Back to ArcShell", action: "archangelos-shell use archangelos", cat: "Desktop shell", flags: [], fixed: true });
        return out;
    }
    function fromMask(mask, key) {
        const names = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]];
        return names.filter(n => mask & n[0]).map(n => n[1]).concat([key]).join(" + ");
    }
    function norm(k) { return (k || "").toUpperCase().replace(/\s+/g, "").replace("CONTROL", "CTRL"); }

    // ---- the effective map ------------------------------------------------------------------
    function keysOf(b) { const r = page.remap[b.keys]; return r === false ? "" : (typeof r === "string" && r ? r : b.keys); }
    readonly property var rows: {
        const list = page.own ? page.defaults.map(b => Object.assign({ kind: "default", now: page.keysOf(b), off: page.remap[b.keys] === false,
                                                                         changed: typeof page.remap[b.keys] === "string" }, b))
                              : page.foreign.map(b => Object.assign({ kind: "foreign", now: b.keys, off: false, changed: false }, b));
        return list.concat(page.custom.map((b, i) => ({ kind: "custom", index: i, keys: b.keys, now: b.keys, desc: b.description || b.cmd,
                                                        action: b.cmd, cat: "Your shortcuts", flags: [], off: false, changed: false })));
    }
    // who else answers to these keys
    function clash(keys, except) {
        const k = page.norm(keys);
        return page.rows.filter(r => !r.off && r.keys + r.kind + (r.index ?? "") !== except && page.norm(r.now) === k);
    }
    readonly property var shown: {
        const q = page.query.trim().toLowerCase();
        return q ? page.rows.filter(r => (r.desc + " " + r.now + " " + r.action + " " + r.cat).toLowerCase().includes(q)) : page.rows;
    }
    readonly property var cats: { const c = []; for (const r of page.shown) if (c.indexOf(r.cat) < 0) c.push(r.cat); return c; }
    readonly property int changes: Object.keys(page.remap).length + page.custom.length

    // ---- saving -----------------------------------------------------------------------------
    function luaStr(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/[\x00-\x1f]/g, " ") + '"'; }
    function save(remap, custom) {
        page.remap = remap; page.custom = custom; page.editing = ""; page.error = "";
        const L = ["-- Written by ArchangelOS Settings > Keyboard shortcuts. Edit them there.", "return {", "    remap = {"];
        for (const k in remap) L.push("        [" + page.luaStr(k) + "] = " + (remap[k] === false ? "false" : page.luaStr(remap[k])) + ",");
        L.push("    },", "    custom = {");
        for (const b of custom) L.push("        { keys = " + page.luaStr(b.keys) + ", cmd = " + page.luaStr(b.cmd) + ", description = " + page.luaStr(b.description || b.cmd) + " },");
        L.push("    },", "}");
        cmd.sh('mkdir -p "$1" && printf "%s\\n" "$2" > "$1/keys.lua" && printf "%s\\n" "$3" > "$1/keys.json" && '
             + '{ command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1; true; }',
               [page.dir, L.join("\n"), JSON.stringify({ remap: remap, custom: custom }, null, 1)], (c, o, e) => {
            if (c !== 0) page.error = (e || o).trim() || "Couldn't save the shortcuts.";
            else { page.notice = "Saved — the new keys work now."; noticeT.restart(); }
        });
    }
    Timer { id: noticeT; interval: 3500; onTriggered: page.notice = "" }
    function setKeys(row, keys) {
        if (row.kind === "custom") { const c = page.custom.slice(); c[row.index] = Object.assign({}, c[row.index], { keys: keys }); page.save(page.remap, c); return; }
        const r = Object.assign({}, page.remap);
        if (page.norm(keys) === page.norm(row.keys)) delete r[row.keys]; else r[row.keys] = keys;
        page.save(r, page.custom);
    }
    function setOff(row, off) {
        const r = Object.assign({}, page.remap);
        if (off) r[row.keys] = false; else delete r[row.keys];
        page.save(r, page.custom);
    }
    function reset(row) { const r = Object.assign({}, page.remap); delete r[row.keys]; page.save(r, page.custom); }
    function removeCustom(row) { page.save(page.remap, page.custom.filter((b, i) => i !== row.index)); }

    // ---- key names --------------------------------------------------------------------------
    readonly property var keyNames: ({
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Space]: "SPACE", [Qt.Key_Tab]: "TAB", [Qt.Key_Backtab]: "TAB",
        [Qt.Key_Escape]: "Escape", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert",
        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next",
        [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Print]: "Print",
        [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period", [Qt.Key_Slash]: "slash", [Qt.Key_Backslash]: "backslash",
        [Qt.Key_Minus]: "minus", [Qt.Key_Equal]: "equal", [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Apostrophe]: "apostrophe",
        [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright", [Qt.Key_QuoteLeft]: "grave"
    })
    function comboOf(ev) {
        const k = ev.key;
        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr].indexOf(k) >= 0) return "";
        let name = page.keyNames[k] || "";
        if (!name && k >= Qt.Key_A && k <= Qt.Key_Z) name = String.fromCharCode(k);
        else if (!name && k >= Qt.Key_0 && k <= Qt.Key_9) name = String.fromCharCode(k);
        else if (!name && k >= Qt.Key_F1 && k <= Qt.Key_F24) name = "F" + (k - Qt.Key_F1 + 1);
        if (!name) return "";
        const m = ev.modifiers, mods = [];
        if (m & Qt.MetaModifier) mods.push("SUPER");
        if (m & Qt.ControlModifier) mods.push("CTRL");
        if (m & Qt.AltModifier) mods.push("ALT");
        if (m & Qt.ShiftModifier) mods.push("SHIFT");
        return mods.concat([name]).join(" + ");
    }
    function valid(k) { return /^((SUPER|SHIFT|CTRL|CONTROL|ALT|MOD[2-5])\s*\+\s*)*[A-Za-z0-9_:]+$/i.test((k || "").trim()); }
    readonly property var pretty: ({ "mouse:272": "Left drag", "mouse:273": "Right drag", "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑",
        "left": "←", "right": "→", "up": "↑", "down": "↓", "Return": "Enter", "SPACE": "Space", "TAB": "Tab",
        "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Mute", "XF86AudioMicMute": "Mic mute",
        "XF86AudioPlay": "Play", "XF86AudioNext": "Next", "XF86AudioPrev": "Prev", "XF86MonBrightnessUp": "Bright +", "XF86MonBrightnessDown": "Bright −" })
    function caps(k) { return (k || "").split("+").map(s => s.trim()).filter(s => s).map(s => page.pretty[s] || (s === "SUPER" ? "Super" : s === "CTRL" ? "Ctrl" : s === "ALT" ? "Alt" : s === "SHIFT" ? "Shift" : s)); }

    // ---- pieces -----------------------------------------------------------------------------
    component Keycaps: Row {
        property string keys: ""
        property bool off: false
        spacing: 4
        Repeater {
            model: page.caps(parent.keys)
            Rectangle {
                required property string modelData
                height: 26; width: Math.max(26, kl.implicitWidth + 16); radius: 6
                color: Ax.raised; border.width: 1; border.color: Ax.border
                opacity: parent.off ? 0.45 : 1
                Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width - 6; height: 2; radius: 1; color: Ax.alpha(Ax.text, 0.08) }
                Label { id: kl; anchors.centerIn: parent; mono: true; font.pixelSize: Ax.fsSmall; text: modelData; color: Ax.text }
            }
        }
    }

    // Press-the-keys box (with a typed fallback: Hyprland keeps combos it already uses for itself)
    component KeyEditor: Item {
        id: ed
        property var row: null
        property bool isNew: false
        property string keys: ""
        readonly property var others: ed.keys ? page.clash(ed.keys, ed.row ? ed.row.keys + ed.row.kind + (ed.row.index ?? "") : "") : []
        width: parent.width; height: ec.implicitHeight + 28
        Column {
            id: ec
            x: Ax.pad; y: 14; width: parent.width - 2 * Ax.pad; spacing: 10
            Row {
                spacing: 10
                Rectangle {
                    id: cap
                    width: 300; height: 44; radius: Ax.radiusSm
                    color: catcher.activeFocus ? Ax.accentSoft : Ax.raised
                    border.width: 1; border.color: catcher.activeFocus ? Ax.accentLine : Ax.border
                    Item {
                        id: catcher
                        anchors.fill: parent
                        focus: true
                        Keys.onPressed: (ev) => { const c = page.comboOf(ev); if (c) { ed.keys = c; typed.text = c; } ev.accepted = true; }
                    }
                    Keycaps { visible: ed.keys !== ""; keys: ed.keys; anchors.centerIn: parent }
                    Label { visible: ed.keys === ""; anchors.centerIn: parent; text: catcher.activeFocus ? "Press the new keys…" : "Click here, then press the keys"; color: Ax.muted; font.pixelSize: Ax.fsSmall }
                    MouseArea { anchors.fill: parent; onClicked: catcher.forceActiveFocus() }
                }
                AxField { id: typed; width: 220; anchors.verticalCenter: parent.verticalCenter; placeholder: "or type: SUPER + SHIFT + K"; text: ed.keys
                          onTextChanged: if (text !== ed.keys) ed.keys = text }
            }
            Row {
                visible: ed.isNew; spacing: 10
                AxField { id: nDesc; width: 220; placeholder: "Name — e.g. Open notes" }
                AxField { id: nCmd; width: 300; placeholder: "Command — e.g. obsidian"; icon: "terminal" }
            }
            Label {
                width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall
                visible: text !== ""
                color: ed.others.length ? Ax.danger : Ax.muted
                text: ed.keys !== "" && !page.valid(ed.keys) ? "That isn't a key combination Hyprland understands."
                    : ed.others.length ? "Already used by: " + ed.others.map(o => o.desc).join(", ") + ". Both would run — change or turn that one off."
                    : ed.row && ed.row.flags.indexOf("mouse") >= 0 ? "Mouse binds take a mouse button, like SUPER + mouse:272." : ""
            }
            Row {
                spacing: 8
                AxButton {
                    text: ed.isNew ? "Add shortcut" : "Save"; kind: "primary"
                    enabled_: page.valid(ed.keys) && (!ed.isNew || nCmd.text.trim() !== "")
                    onClicked: {
                        const k = ed.keys.trim().replace(/\s*\+\s*/g, " + ");
                        if (ed.isNew) page.save(page.remap, page.custom.concat([{ keys: k, cmd: nCmd.text.trim(), description: nDesc.text.trim() || nCmd.text.trim() }]));
                        else page.setKeys(ed.row, k);
                    }
                }
                AxButton { visible: !!ed.row && ed.row.changed; text: "Back to " + (ed.row ? page.caps(ed.row.keys).join(" + ") : ""); onClicked: page.reset(ed.row) }
                AxButton { text: "Cancel"; onClicked: page.editing = "" }
            }
        }
        Component.onCompleted: { ed.keys = ed.isNew ? "" : (ed.row ? ed.row.now : ""); catcher.forceActiveFocus(); }
    }

    // ---- layout -----------------------------------------------------------------------------
    header: Row {
        spacing: 8
        AxButton { icon: "add"; text: "Add shortcut"; kind: "primary"; onClicked: page.editing = "+new" }
    }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    Rectangle {
        width: parent.width; height: 76
        radius: Ax.radius; color: Ax.panel; border.width: 1; border.color: Ax.border
        CornerTicks { len: 8; anchors.margins: 10 }
        Row {
            x: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 14
            Icon { name: "keyboard_command_key"; size: 26; color: Ax.accent; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Label { text: page.own ? "ArcShell" : (page.shell ? page.shell.name : "Theme"); font.weight: Font.Medium }
                Label { font.pixelSize: Ax.fsSmall; color: Ax.muted
                        text: page.notice !== "" ? page.notice
                            : page.own ? page.rows.filter(r => !r.off).length + " shortcuts" + (page.changes ? "  ·  " + page.changes + " changed by you" : "")
                            : "This theme brings its own shortcuts — they're listed as it defines them. Shortcuts you add here work in every shell." }
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            AxField { width: 220; icon: "search"; placeholder: "Find a shortcut or key"; onTextChanged: page.query = text }
            ConfirmButton { visible: page.changes > 0; label: "Restore defaults"; confirmText: "Undo all changes?"; onConfirmed: page.save({}, []) }
        }
    }

    Section {
        visible: page.editing === "+new"
        title: "New shortcut"
        Loader { width: parent.width; active: page.editing === "+new"; property bool topDivider: false
                 sourceComponent: KeyEditor { isNew: true } }
    }

    Section {
        visible: page.loaded && page.rows.length === 0
        EmptyState { icon: "keyboard"; title: "No shortcuts found"; desc: "Hyprland isn't running, or this theme's keybinds couldn't be read." }
    }

    Repeater {
        model: page.cats
        Section {
            id: catSec
            required property string modelData
            title: modelData
            note: page.shown.filter(r => r.cat === modelData).length + ""
            Repeater {
                model: page.shown.filter(r => r.cat === catSec.modelData)
                Column {
                    id: cell
                    required property var modelData
                    readonly property var r: modelData
                    readonly property string tag: r.keys + r.kind + (r.index ?? "")
                    property bool topDivider: false
                    width: parent.width
                    Rectangle { visible: cell.topDivider; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
                    SRow {
                        dim: cell.r.off
                        title: cell.r.desc
                        desc: cell.r.off ? "Off — " + cell.r.action : cell.r.action
                        Badge { visible: cell.r.changed; text: "changed"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                        Badge { visible: cell.r.kind !== "custom" && !cell.r.off && page.clash(cell.r.now, cell.tag).length > 0; text: "conflict"; tone: "danger"; anchors.verticalCenter: parent.verticalCenter }
                        Keycaps { keys: cell.r.now || cell.r.keys; off: cell.r.off; anchors.verticalCenter: parent.verticalCenter }
                        AxButton { visible: cell.r.kind !== "foreign" && !cell.r.fixed && !cell.r.off; icon: "edit"; anchors.verticalCenter: parent.verticalCenter
                                   onClicked: page.editing = page.editing === cell.tag ? "" : cell.tag }
                        AxSwitch { visible: cell.r.kind === "default" && !cell.r.fixed; checked: !cell.r.off; anchors.verticalCenter: parent.verticalCenter
                                   onToggled: (on) => page.setOff(cell.r, !on) }
                        ConfirmButton { visible: cell.r.kind === "custom"; icon: "delete"; confirmText: "Remove"; anchors.verticalCenter: parent.verticalCenter
                                        onConfirmed: page.removeCustom(cell.r) }
                    }
                    Loader { width: parent.width; active: page.editing === cell.tag
                             sourceComponent: KeyEditor { row: cell.r } }
                }
            }
        }
    }

    Label {
        width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall; color: Ax.faint
        text: "Shortcuts the desktop already uses can't be pressed into the box — type them instead. Changes are saved to " + page.dir.replace(Quickshell.env("HOME"), "~") + "/keys.lua."
    }
}
