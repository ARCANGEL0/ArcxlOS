// Accessibility — make the desktop easier to see and use: bigger text and pointer, less motion,
// colour filters for colour-blindness and contrast, a screen reader and an on-screen keyboard.
// Visual changes apply live; the colour filter and motion setting are saved to
// ~/.config/archangelos/hypr/a11y.lua, text and pointer to the session environment.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Accessibility"
    title: "Accessibility"
    desc: "Text size, pointer, motion, colour, reading and typing aids."

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string shaderDir: "/usr/share/archangelos/shell/src/config/shaders"
    readonly property var s: Store.data
    property var have: ({})
    property bool orcaOn: false

    Cmd { id: cmd }
    Component.onCompleted: {
        cmd.sh('for p in orca wvkbd-mobintl onboard wvkbd; do command -v "$p" >/dev/null 2>&1 && echo "$p=1"; done; '
             + 'pgrep -x orca >/dev/null && echo "orca_running=1"', [], (c, o) => {
            const m = {}; for (const l of o.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = true; }
            page.have = m; page.orcaOn = !!m.orca_running;
        });
    }

    readonly property var filters: [
        { k: "", t: "Off", file: "" },
        { k: "grayscale", t: "Greyscale", file: "Grayscale.glsl" },
        { k: "highcontrast", t: "High contrast", file: "HighContrast.glsl" },
        { k: "invert", t: "Invert colours", file: "invert-colors.glsl" }
    ]
    // ── the a11y Hyprland fragment (filter + motion) ──────────────────────────────
    function writeFragment() {
        const f = page.filters.find(x => x.k === page.s.colorFilter);
        const shader = f && f.file ? page.shaderDir + "/" + f.file : "";
        const L = ["-- Written by ArchangelOS Settings > Accessibility."];
        L.push("hl.config({ decoration = { screen_shader = " + (shader ? "'" + shader + "'" : "''") + " }"
             + (page.s.reduceMotion ? ", animations = { enabled = false }" : "") + " })");
        cmd.sh('mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', [Store.dir + "/hypr/a11y.lua", L.join("\n")]);
    }
    function applyFilter(k) {
        Store.data.colorFilter = k;
        const f = page.filters.find(x => x.k === k);
        const path = f && f.file ? page.shaderDir + "/" + f.file : "";
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { screen_shader = '" + path + "' } })"]);
        page.writeFragment();
    }
    function setMotion(on) {
        Store.data.reduceMotion = on;
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ animations = { enabled = " + (on ? "false" : "true") + " } })"]);
        Quickshell.execDetached(["sh", "-c", "gsettings set org.gnome.desktop.interface enable-animations " + (on ? "false" : "true") + " 2>/dev/null; true"]);
        page.writeFragment();
    }
    function setCursor(size) {
        Store.data.cursorSize = size;
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$HOME/.config/environment.d"; printf "XCURSOR_SIZE=%s\\n" "$1" > "$HOME/.config/environment.d/60-cursor.conf"; '
            // keep the login-time size (Appearance reads the same file for the cursor theme)
            + 'conf="${XDG_CONFIG_HOME:-$HOME/.config}/archangelos/appearance.conf"; mkdir -p "$(dirname "$conf")"; touch "$conf"; '
            + 't="$(mktemp)"; grep -v "^CURSOR_SIZE=" "$conf" > "$t" 2>/dev/null; printf "CURSOR_SIZE=\\"%s\\"\\n" "$1" >> "$t"; mv "$t" "$conf"; '
            + 'th="$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d \"\\x27\")"; [ -n "$th" ] || th=Future-dark-cursors; '
            + 'hyprctl setcursor "$th" "$1" >/dev/null 2>&1; hyprctl keyword env XCURSOR_SIZE,"$1" >/dev/null 2>&1; '
            + 'gsettings set org.gnome.desktop.interface cursor-size "$1" 2>/dev/null; true', "sh", String(size)]);
    }
    function setText(scale) {
        Store.data.textScale = scale;
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$HOME/.config/environment.d"; printf "QT_SCALE_FACTOR=%s\\n" "$1" > "$HOME/.config/environment.d/70-textscale.conf"; '
            + 'gsettings set org.gnome.desktop.interface text-scaling-factor "$1" 2>/dev/null; true', "sh", String(scale)]);
    }
    function toggleOrca(on) {
        page.orcaOn = on;
        if (on) Quickshell.execDetached(["sh", "-c", "orca >/dev/null 2>&1 &"]);
        else Quickshell.execDetached(["pkill", "-x", "orca"]);
        // autostart
        Quickshell.execDetached(["sh", "-c", on
            ? 'mkdir -p "$HOME/.config/autostart"; printf "[Desktop Entry]\\nType=Application\\nExec=orca\\nName=Screen Reader\\nX-GNOME-Autostart-enabled=true\\n" > "$HOME/.config/autostart/orca.desktop"'
            : 'rm -f "$HOME/.config/autostart/orca.desktop"'] )
    }

    // ── sight ────────────────────────────────────────────────────────────────────
    Section {
        title: "Seeing"
        SRow {
            icon: "format_size"; title: "Text size"; desc: "Scales text in apps — " + Math.round(page.s.textScale * 100) + "% (sign out and in to apply everywhere)"
            AxSlider { width: 220; from: 1; to: 2; stepSize: 0.25; valueScale: 100; suffix: "%"; value: page.s.textScale; anchors.verticalCenter: parent.verticalCenter
                       onReleased: (v) => page.setText(Math.round(v * 4) / 4) }
        }
        SRow {
            icon: "mouse"; title: "Pointer size"; desc: "A bigger mouse cursor, easier to find"
            AxSlider { width: 220; from: 16; to: 64; stepSize: 4; suffix: " px"; value: page.s.cursorSize; anchors.verticalCenter: parent.verticalCenter
                       onReleased: (v) => page.setCursor(Math.round(v / 4) * 4) }
        }
        SRow {
            icon: "contrast"; title: "Colour filter"; desc: "Greyscale, high contrast, or inverted colours across the whole screen"
            AxSelect { width: 180; anchors.verticalCenter: parent.verticalCenter; model: page.filters.map(f => f.t)
                       current: Math.max(0, page.filters.findIndex(f => f.k === page.s.colorFilter))
                       onPicked: (i) => page.applyFilter(page.filters[i].k) }
        }
    }

    // ── motion ───────────────────────────────────────────────────────────────────
    Section {
        title: "Motion"
        SRow {
            icon: "animation"; title: "Reduce motion"; desc: "Turns off window and desktop animations, for comfort or less distraction"
            AxSwitch { checked: page.s.reduceMotion; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.setMotion(on) }
        }
    }

    // ── reading & typing ─────────────────────────────────────────────────────────
    Section {
        title: "Reading & typing"
        SRow {
            icon: "record_voice_over"; title: "Screen reader"
            desc: page.have.orca ? "Orca reads the screen aloud and describes what you focus" : "Not installed — add  orca  to read the screen aloud"
            AxSwitch { visible: !!page.have.orca; checked: page.orcaOn; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.toggleOrca(on) }
            Badge { visible: !page.have.orca; text: "not installed"; tone: "neutral"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "keyboard"; title: "On-screen keyboard"
            desc: (page.have["wvkbd-mobintl"] || page.have.wvkbd || page.have.onboard) ? "Type with a pointer or touchscreen" : "Not installed — add  wvkbd  (or  onboard ) for a touch keyboard"
            AxButton { visible: !!(page.have["wvkbd-mobintl"] || page.have.wvkbd || page.have.onboard); text: "Show"; anchors.verticalCenter: parent.verticalCenter
                       onClicked: Quickshell.execDetached(["sh", "-c", (page.have["wvkbd-mobintl"] ? "wvkbd-mobintl" : page.have.wvkbd ? "wvkbd" : "onboard") + " >/dev/null 2>&1 &"]) }
            Badge { visible: !(page.have["wvkbd-mobintl"] || page.have.wvkbd || page.have.onboard); text: "not installed"; tone: "neutral"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "keyboard_option_key"; title: "Sticky & slow keys"; desc: "Modifier and repeat behaviour is set in Keyboard & Mouse"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("input")
        }
    }

    Label { width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: Ax.fsSmall; color: Ax.faint
            text: "Text and pointer sizes take full effect for apps started after you sign out and back in." }
}
