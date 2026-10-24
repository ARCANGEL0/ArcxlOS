// Appearance — accent, where colours come from, panel material and shape, type, and the system
// cursor and icon themes. The shell controls write its own preferences; the cursor/icon theme
// writes ~/.config/archangelos/appearance.conf (read at login) and applies live.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.arc as NSRoot
import qs.arc.services as NSS
import "../../frame" as Frame

PageScaffold {
    id: page
    property var meta
    group: "Personalize"
    title: "Appearance"
    desc: "How the shell looks: its accent, panels, type, cursor and icons."

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string conf: (Quickshell.env("XDG_CONFIG_HOME") || (page.home + "/.config")) + "/archangelos/appearance.conf"
    property var cursorThemes: []
    property var iconThemes: []
    property string curCursor: ""
    property string curIcon: ""
    property int cursorSize: 24
    property bool themesLoaded: false
    property string busy: ""
    property string notice: ""
    property string error: ""

    Cmd { id: tcmd }
    function loadThemes() {
        tcmd.sh('paths="/usr/share/icons $HOME/.local/share/icons $HOME/.icons"; '
              + 'echo "--cursors"; for d in $paths; do [ -d "$d" ] || continue; for t in "$d"/*/; do [ -d "${t}cursors" ] && basename "$t"; done; done | sort -u; '
              + 'echo "--icons"; for d in $paths; do [ -d "$d" ] || continue; for t in "$d"/*/; do n=$(basename "$t"); '
              + 'case "$n" in hicolor|default|locolor) continue;; esac; [ -f "${t}index.theme" ] || continue; '
              + 'grep -qiE "^Directories=.*(apps|actions|places|devices|mimetypes|status|[0-9]+x[0-9]+|scalable)" "${t}index.theme" && echo "$n"; done; done | sort -u; '
              + 'echo "--cur"; . "$1" 2>/dev/null; '
              + 'echo "cursor=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d \"\\x27\" || echo "$CURSOR_THEME")"; '
              + 'echo "icon=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d \"\\x27\" || echo "$ICON_THEME")"; '
              + 'echo "size=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null || echo "${CURSOR_SIZE:-24}")"', [page.conf], (c, o) => {
            const sec = (a, b) => { const i = o.indexOf(a), j = b ? o.indexOf(b) : o.length; return i < 0 ? "" : o.slice(i + a.length, j < 0 ? o.length : j); };
            page.cursorThemes = sec("--cursors", "--icons").split("\n").filter(l => l.trim());
            page.iconThemes = sec("--icons", "--cur").split("\n").filter(l => l.trim());
            for (const l of sec("--cur").split("\n")) { const i = l.indexOf("="); if (i < 0) continue; const k = l.slice(0, i), v = l.slice(i + 1).trim();
                if (k === "cursor" && v) page.curCursor = v; if (k === "icon" && v) page.curIcon = v; if (k === "size" && v) page.cursorSize = parseInt(v) || 24; }
            page.themesLoaded = true;
        });
    }
    Component.onCompleted: loadThemes()

    function setKV(key, val, after) {
        tcmd.sh('conf="$1"; mkdir -p "$(dirname "$conf")"; touch "$conf"; t="$(mktemp)"; grep -v "^$2=" "$conf" > "$t" 2>/dev/null; printf "%s=\\"%s\\"\\n" "$2" "$3" >> "$t"; mv "$t" "$conf"', [page.conf, key, val], after);
    }
    function gtkSet(key, val) {
        tcmd.sh('for v in 3.0 4.0; do f="$HOME/.config/gtk-$v/settings.ini"; mkdir -p "$(dirname "$f")"; '
              + '[ -f "$f" ] || printf "[Settings]\\n" > "$f"; grep -q "^\\[Settings\\]" "$f" || printf "[Settings]\\n" >> "$f"; '
              + 'if grep -q "^$1=" "$f"; then sed -i "s|^$1=.*|$1=$2|" "$f"; else sed -i "/^\\[Settings\\]/a $1=$2" "$f"; fi; done', [key, val]);
    }
    function applyCursor(theme) {
        page.curCursor = theme;
        page.setKV("CURSOR_THEME", theme);
        page.gtkSet("gtk-cursor-theme-name", theme);
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$HOME/.config/environment.d"; printf "XCURSOR_THEME=%s\\n" "$1" > "$HOME/.config/environment.d/61-cursor-theme.conf"; '
            + 'gsettings set org.gnome.desktop.interface cursor-theme "$1" 2>/dev/null; '
            + 'hyprctl setcursor "$1" "$2" >/dev/null 2>&1; hyprctl keyword env XCURSOR_THEME,"$1" >/dev/null 2>&1; true', "sh", theme, String(page.cursorSize)]);
        page.flash("Cursor theme changed.");
    }
    function applyIcon(theme) {
        page.curIcon = theme;
        page.setKV("ICON_THEME", theme);
        page.gtkSet("gtk-icon-theme-name", theme);
        Quickshell.execDetached(["sh", "-c", 'gsettings set org.gnome.desktop.interface icon-theme "$1" 2>/dev/null; true', "sh", theme]);
        page.flash("Icon theme changed.");
    }
    function flash(t) { page.notice = t; flashT.restart(); }
    Timer { id: flashT; interval: 4000; onTriggered: page.notice = "" }

    FilePick {
        id: themePick
        title: "Choose a theme archive"
        filters: ["Theme archives (*.tar.gz *.tgz *.tar.xz *.txz *.tar.bz2 *.tar *.zip)", "All files (*)"]
        folder: Quickshell.env("XDG_DOWNLOAD_DIR") || (page.home + "/Downloads")
        onPicked: (p) => page.install(p)
    }
    function install(archive) {
        page.busy = "install"; page.error = ""; page.notice = "";
        tcmd.sh('a="$1"; dest="$HOME/.local/share/icons"; mkdir -p "$dest"; tmp="$(mktemp -d)"; '
              + 'case "$a" in *.tar.gz|*.tgz) tar -xzf "$a" -C "$tmp" ;; *.tar.xz|*.txz) tar -xJf "$a" -C "$tmp" ;; '
              + '*.tar.bz2) tar -xjf "$a" -C "$tmp" ;; *.tar) tar -xf "$a" -C "$tmp" ;; '
              + '*.zip) command -v unzip >/dev/null && unzip -q "$a" -d "$tmp" || bsdtar -xf "$a" -C "$tmp" ;; '
              + '*) rm -rf "$tmp"; echo "ERR unsupported archive"; exit 2 ;; esac || { rm -rf "$tmp"; echo "ERR could not extract"; exit 1; }; '
              + 'n=0; move() { mv -f "$1" "$dest/" 2>/dev/null && n=$((n+1)); }; '
              + 'for d in "$tmp"/*/; do [ -d "$d" ] || continue; '
              + 'if [ -f "${d}index.theme" ] || [ -d "${d}cursors" ]; then move "$d"; '
              + 'else for e in "$d"*/; do [ -d "$e" ] && { [ -f "${e}index.theme" ] || [ -d "${e}cursors" ]; } && move "$e"; done; fi; done; '
              + 'rm -rf "$tmp"; [ "$n" -gt 0 ] && echo "OK $n" || echo "ERR no theme found in the archive"', [archive], (c, o) => {
            page.busy = "";
            const r = o.trim();
            if (r.startsWith("OK")) { page.flash("Installed " + r.split(" ")[1] + " theme(s) — pick it below."); page.loadThemes(); }
            else page.error = r.replace(/^ERR /, "") || "Couldn't install that theme.";
        });
    }

    readonly property bool fromWallpaper: !Frame.PrefsService.dynamicThemeOverride
    readonly property var accents: [
        { name: "Crimson", hex: "#C24A52" }, { name: "Ember", hex: "#C8643C" }, { name: "Brass", hex: "#B5945A" },
        { name: "Moss", hex: "#7E9C6A" },    { name: "Jade", hex: "#4F9A8A" },  { name: "Steel", hex: "#6F8EA8" },
        { name: "Iris", hex: "#8A7FC0" },    { name: "Rose", hex: "#C47A9A" },  { name: "Bone", hex: "#CFC7B8" }
    ]
    function same(a, b) { return String(a).toLowerCase() === String(b).toLowerCase(); }

    // ── preview strip ──────────────────────────────────────────────────────────
    Rectangle {
        width: parent.width; height: 120
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        clip: true
        Row {
            anchors.left: parent.left; anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            // a miniature island + pane in the live style
            Rectangle {
                width: 220; height: 72; radius: Frame.PrefsService.cornerRadius * 0.6
                color: Ax.alpha(Ax.base, Frame.PrefsService.bgOpacity)
                border.width: Math.max(1, Frame.PrefsService.borderWidth / 4); border.color: Ax.border
                Column {
                    anchors.centerIn: parent; spacing: 8
                    Label { anchors.horizontalCenter: parent.horizontalCenter; mono: true; text: "09:41"; font.pixelSize: 20 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 3
                        Repeater { model: 22; Rectangle { required property int index; width: 3; radius: 1.5
                                   height: 4 + Math.abs(Math.sin(index * 0.7)) * 12; anchors.bottom: parent.bottom
                                   color: Ax.alpha(Ax.accent, 0.35 + Math.abs(Math.sin(index * 0.7)) * 0.65) } }
                    }
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Label { text: page.fromWallpaper ? "Colours from your wallpaper" : "ArchangelOS palette"; font.weight: Font.Medium }
                Label { text: page.fromWallpaper ? "The accent follows each wallpaper you set." : "Matte black with the accent you choose below."
                        color: Ax.faint; font.pixelSize: Ax.fsSmall }
                Row { spacing: 6; topPadding: 4
                      Repeater { model: [Ax.base, Ax.panel, Ax.raised, Ax.subtext, Ax.text, Ax.accent]
                                 Rectangle { required property var modelData; width: 22; height: 22; radius: 6; color: modelData; border.width: 1; border.color: Ax.border } } }
            }
        }
    }

    Section {
        title: "Colour"
        SRow {
            icon: "wallpaper"; title: "Colours from wallpaper"
            desc: "Derive the whole palette from the current wallpaper instead of the ArchangelOS palette"
            AxSwitch { checked: page.fromWallpaper; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Frame.PrefsService.dynamicThemeOverride = !on }
        }
        SRow {
            visible: page.fromWallpaper
            icon: "dark_mode"; title: "Dark mode"; desc: "Use the dark variant of the wallpaper palette"
            AxSwitch { checked: Frame.PrefsService.darkMode; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Frame.PrefsService.darkMode = on }
        }
        // accent swatches
        Item {
            property bool topDivider: false
            width: parent.width
            height: accentCol.implicitHeight + 32
            opacity: page.fromWallpaper ? 0.4 : 1
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: accentCol
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad
                spacing: 12
                Row {
                    width: parent.width
                    Label { text: "Accent"; font.weight: Font.Medium; width: parent.width - hint.width }
                    Label { id: hint; text: page.fromWallpaper ? "Set by the wallpaper" : String(Frame.PrefsService.overrideActive).toUpperCase(); mono: true; font.pixelSize: Ax.fsSmall; color: Ax.faint }
                }
                Flow {
                    width: parent.width; spacing: 10
                    Repeater {
                        model: page.accents
                        delegate: Item {
                            id: sw
                            required property var modelData
                            readonly property bool on: page.same(Frame.PrefsService.overrideActive, modelData.hex)
                            width: 76; height: 64
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 34; height: 34; radius: 17
                                color: sw.modelData.hex
                                border.width: sw.on ? 2 : 0; border.color: Ax.base
                                Rectangle { anchors.centerIn: parent; width: 42; height: 42; radius: 21; color: "transparent"
                                            border.width: 2; border.color: sw.on ? sw.modelData.hex : (swMa.containsMouse ? Ax.alpha(Ax.text, 0.18) : "transparent") }
                                Icon { anchors.centerIn: parent; visible: sw.on; name: "check"; size: 18; color: "#fbf8f3" }
                            }
                            Label { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                    text: sw.modelData.name; font.pixelSize: Ax.fsSmall - 1; color: sw.on ? Ax.text : Ax.faint }
                            MouseArea { id: swMa; anchors.fill: parent; hoverEnabled: true; enabled: !page.fromWallpaper
                                        cursorShape: Qt.PointingHandCursor; onClicked: Frame.PrefsService.overrideActive = sw.modelData.hex }
                        }
                    }
                }
            }
        }
    }

    Section {
        title: "Panels"
        SRow {
            icon: "opacity"; title: "Panel opacity"; desc: "How solid the shell's bar, island and panels are"
            AxSlider { width: 280; anchors.verticalCenter: parent.verticalCenter
                       value: Frame.PrefsService.bgOpacity; from: 0.5; to: 1.0; valueScale: 100; suffix: "%"
                       onMoved: (v) => Frame.PrefsService.bgOpacity = Math.round(v * 100) / 100 }
        }
        SRow {
            icon: "blur_on"; title: "Blur behind panels"; desc: "Frosts what's underneath when panels are see-through"
            AxSwitch { checked: Frame.PrefsService.bgBlur; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => { Frame.PrefsService.bgBlur = on; Frame.PrefsService.updateHyprlandBlur(); } }
        }
        SRow {
            icon: "rounded_corner"; title: "Corner radius"; desc: "Roundness of the island, panels and notches"
            AxSlider { width: 280; anchors.verticalCenter: parent.verticalCenter
                       value: Frame.PrefsService.cornerRadius; from: 0; to: 32; stepSize: 1; suffix: " px"
                       onMoved: (v) => Frame.PrefsService.cornerRadius = Math.round(v) }
        }
        SRow {
            icon: "border_outer"; title: "Frame thickness"; desc: "The thin border that runs around the screen"
            AxSlider { width: 280; anchors.verticalCenter: parent.verticalCenter
                       value: Frame.PrefsService.borderWidth; from: 0; to: 16; stepSize: 1; suffix: " px"
                       onMoved: (v) => Frame.PrefsService.borderWidth = Math.round(v) }
        }
    }

    Section {
        title: "Type"
        SRow {
            icon: "text_fields"; title: "Shell font"; desc: "The face used across the bar, island and panels"
            AxSelect {
                id: fontSel
                width: 260; anchors.verticalCenter: parent.verticalCenter
                readonly property var keys: NSRoot.Config.fontFiles.map(f => f.key)
                model: NSRoot.Config.fontFiles.map(f => NSRoot.Config.fontNames[f.key] || f.key)
                current: keys.indexOf(NSRoot.Config.fontKey)
                onPicked: (i) => NSRoot.Config.fontPreset = keys[i]
            }
        }
    }

    Section {
        title: "Cursor & icons"
        note: page.notice
        Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall
                property bool topDivider: false; leftPadding: Ax.pad; topPadding: 10 }
        SRow {
            icon: "mouse"; title: "Cursor theme"; desc: "The mouse pointer used across the desktop and apps"
            AxSelect { width: 240; anchors.verticalCenter: parent.verticalCenter; model: page.cursorThemes
                       current: Math.max(0, page.cursorThemes.indexOf(page.curCursor))
                       onPicked: (i) => page.applyCursor(page.cursorThemes[i]) }
        }
        SRow {
            icon: "apps"; title: "Icon theme"; desc: "Icons for apps, files and folders (GTK applications)"
            AxSelect { width: 240; anchors.verticalCenter: parent.verticalCenter; model: page.iconThemes
                       current: Math.max(0, page.iconThemes.indexOf(page.curIcon))
                       onPicked: (i) => page.applyIcon(page.iconThemes[i]) }
        }
        SRow {
            icon: "download"; title: "Install a theme"
            desc: page.busy === "install" ? "Installing…" : "Add a cursor or icon theme from an archive you downloaded (.tar.gz, .tar.xz or .zip)"
            AxButton { text: "Choose file…"; kind: "primary"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: themePick.open() }
        }
        SRow {
            icon: "straighten"; title: "Pointer size"; desc: "Set a larger cursor in Accessibility"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("accessibility")
        }
    }
}
