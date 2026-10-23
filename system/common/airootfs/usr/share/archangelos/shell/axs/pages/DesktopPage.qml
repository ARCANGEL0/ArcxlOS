// Desktop & Shell — which shell runs (ArcShell or any theme in ~/.config/hypr/themes, switched
// with archangelos-shell), then ArcShell's own bar, island, hover panels, OSD and motion.
import QtQuick
import qs.axs
import qs.axs.ui
import Quickshell
import qs.ns.services as NSS
import "../../src" as Frame

PageScaffold {
    id: page
    property var meta
    group: "Personalize"
    title: "Desktop & Shell"
    desc: "Pick your desktop shell, then tune it."

    readonly property var prefs: Frame.PrefsService
    readonly property var curves: ["smooth", "spring", "cinematic", "sharp", "linear", "jello"]
    readonly property var curveNames: ["Smooth", "Spring", "Cinematic", "Sharp", "Linear", "Jello"]

    component Toggle: SRow {
        id: tg
        property string key
        AxSwitch { checked: !!page.prefs[tg.key]; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.prefs[tg.key] = on }
    }

    // ── shell picker ───────────────────────────────────────────────────────────
    property var shells: []            // { id, name, desc, preview, keys, live, active }
    property string chosen: ""
    property string switched: ""       // picked, waiting for the next sign-in
    property string error: ""
    readonly property var current: shells.find(x => x.active) ?? null
    readonly property var sel: shells.find(x => x.id === page.chosen) ?? page.current
    readonly property bool arcActive: !page.current || page.current.id === "archangelos"
    readonly property string themesDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/themes"
    Cmd { id: cmd }
    function load() {
        cmd.run(["archangelos-shell", "list"], (c, o) => {
            page.shells = o.split("\n").filter(l => l).map(l => { const f = l.split("|");
                return { id: f[0], name: f[1], desc: f[2], preview: f[3], keys: f[4] === "1", live: f[5] === "1", active: f[6] === "1" }; });
            if (!page.shells.some(x => x.id === page.chosen)) page.chosen = page.current ? page.current.id : "";
        });
    }
    Component.onCompleted: load()
    function use(sh, now) {
        page.error = "";
        cmd.run(["archangelos-shell", "use", sh.id].concat(now ? ["--now"] : []), (c, o, e) => {
            if (c !== 0) page.error = (e || o).trim();
            else if (!now) page.switched = sh.id;
            page.load();
        });
    }
    // Open a terminal and run CyberArch's own installer (clone → chmod → ./install.sh). It is
    // interactive (asks before installing packages / changing the config), which is why it runs in
    // a terminal rather than silently in the background.
    function installCyberArch() {
        const script = 'set -e; d="$(mktemp -d)"; '
            + 'echo "Cloning CyberArch-Shell…"; git clone --depth 1 https://github.com/ARCANGEL0/CyberArch-Shell.git "$d/CyberArch-Shell"; '
            + 'cd "$d/CyberArch-Shell"; chmod +x install.sh; ./install.sh; '
            + 'echo; echo "— installer finished. Reopen Settings > Desktop & Shell and refresh —"; read -p "Press Enter to close… " _';
        Quickshell.execDetached(["sh", "-c",
            'for t in rio kitty foot alacritty konsole xterm; do command -v "$t" >/dev/null 2>&1 && exec "$t" -e bash -lc "$1"; done; '
            + 'notify-send "No terminal found" "Install a terminal to run the CyberArch installer." 2>/dev/null',
            "sh", script]);
    }

    header: Row {
        spacing: 8
        AxButton { icon: "folder_open"; text: "Themes folder"
                   onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", page.themesDir]) }
        AxButton { icon: "refresh"; onClicked: page.load() }
    }

    Section {
        title: "Shell"
        note: page.shells.length + (page.shells.length === 1 ? " installed" : " installed")
        Item {
            property bool topDivider: false
            width: parent.width
            height: shellGrid.height + 32
            Grid {
                id: shellGrid
                x: Ax.pad; y: 16
                width: parent.width - 2 * Ax.pad
                columns: Math.max(2, Math.floor((width + 12) / 230))
                spacing: 12
                readonly property real cell: (width - (columns - 1) * spacing) / columns
                Repeater {
                    model: page.shells
                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool picked: page.sel && page.sel.id === modelData.id
                        width: shellGrid.cell; height: shellGrid.cell * 0.56 + 58
                        radius: Ax.radiusSm
                        color: Ax.raised
                        border.width: picked ? 2 : 1
                        border.color: picked ? Ax.accent : (cma.containsMouse ? Ax.alpha(Ax.text, 0.2) : Ax.border)
                        clip: true
                        Rectangle {
                            id: shot
                            x: 1; y: 1; width: parent.width - 2; height: shellGrid.cell * 0.56
                            color: Ax.mix(Ax.raised, Ax.base, 0.5)
                            Image {
                                anchors.fill: parent
                                source: card.modelData.preview ? "file://" + card.modelData.preview : ""
                                fillMode: card.modelData.id === "archangelos" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                                anchors.margins: card.modelData.id === "archangelos" ? 22 : 0
                                asynchronous: true; sourceSize.width: 460
                            }
                            Icon { anchors.centerIn: parent; visible: !card.modelData.preview; name: "desktop_windows"; size: 34; color: Ax.faint }
                        }
                        Column {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: shot.bottom
                            anchors.margins: 12; anchors.topMargin: 10
                            spacing: 4
                            Row {
                                width: parent.width; spacing: 6
                                Label { text: card.modelData.name; font.weight: Font.Medium; width: Math.min(implicitWidth, parent.width - badge.width - 6) }
                                Badge { id: badge; visible: card.modelData.active || page.switched === card.modelData.id
                                        text: card.modelData.active ? "running" : "next sign-in"; tone: "accent" }
                            }
                            Label { width: parent.width; text: card.modelData.desc || card.modelData.id; color: Ax.muted; font.pixelSize: Ax.fsSmall }
                        }
                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: page.chosen = card.modelData.id }
                    }
                }
            }
        }
        SRow {
            visible: !!page.sel && !page.sel.active
            icon: "swap_horiz"
            title: page.sel ? "Switch to " + page.sel.name : ""
            desc: !page.sel ? "" : (page.sel.live ? "Can switch right away, or at your next sign-in" : "Takes over when you next sign in")
                  + (page.sel.keys ? ". Brings its own keybinds, so ArchangelOS's step aside" : "")
            AxButton { visible: !!page.sel && page.sel.live; text: "Switch now"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.use(page.sel, true) }
            AxButton { text: page.switched === (page.sel ? page.sel.id : "") ? "Chosen" : "Use at next sign-in"; kind: "primary"
                       enabled_: page.switched !== (page.sel ? page.sel.id : "")
                       anchors.verticalCenter: parent.verticalCenter; onClicked: page.use(page.sel, false) }
        }
        SRow {
            visible: page.switched !== ""
            icon: "logout"; title: "Sign out to switch"
            desc: "Save your work first — open apps close when you log out"
            AxButton { text: "Log out now"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter; onClicked: NSS.HyprCtl.exit() }
        }
        SRow {
            icon: "keyboard"; title: "Way back"; dim: true
            desc: "Super + Ctrl + Alt + A returns to ArcShell from any shell, even one without keybinds"
        }
        SRow {
            visible: page.shells.length <= 1
            icon: "add_circle"; title: "Add a shell"; dim: true
            desc: "Put a theme in ~/.config/hypr/themes/<name>/ with its theme.lua and it shows up here"
        }
    }
    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    // CyberArch is big (AGS rice + its own installer that pulls many packages), so it isn't baked
    // in — it's installed on demand by its upstream installer, running in a terminal because that
    // installer is interactive. Once installed it lands in ~/.config/hypr/themes/cyberpunk and
    // shows up in the picker above like any other shell.
    Section {
        visible: !page.shells.some(x => x.id === "cyberpunk")
        title: "Install more shells"
        SRow {
            icon: "download"; title: "CyberArch"
            desc: "A Cyberpunk 2077 netrunner rice (AGS / Astal). Its installer downloads the packages it needs and asks before changing anything — a few GB and some minutes."
            AxButton { text: "Install…"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.installCyberArch() }
        }
        SRow {
            icon: "info"; dim: true; title: "After it finishes"
            desc: "Come back here and press refresh (top-right) — CyberArch will appear as a shell you can switch to."
        }
    }

    Label {
        width: parent.width; topPadding: 6
        caption: true; color: Ax.accent
        text: page.arcActive ? "ArcShell settings" : "ArcShell settings  ·  apply when ArcShell is the running shell"
    }

    Section {
        title: "Bar & island"
        Toggle { icon: "view_sidebar"; title: "Show the bar"; desc: "The vertical bar along the left edge"; key: "barEnabled" }
        Toggle { icon: "graphic_eq"; title: "Music visualiser"; desc: "Live bars on the island while audio plays"; key: "enableVisualiser" }
        Toggle { icon: "battery_full"; title: "Battery percentage"; desc: "Always show the number next to the battery"; key: "alwaysShowBatteryPercentage" }
        Toggle { icon: "volume_up"; title: "Volume percentage"; desc: "Always show the number next to the volume"; key: "alwaysShowVolumePercentage" }
    }

    Section {
        title: "Open on hover"
        note: page.prefs.globalHoverMode ? "" : "click to open"
        Toggle { icon: "ads_click"; title: "Open panels by hovering"; desc: "Point at a panel's edge to open it, instead of clicking"; key: "globalHoverMode" }
        // which panels open on hover, as one row of chips
        Item {
            property bool topDivider: false
            visible: page.prefs.globalHoverMode
            width: parent.width
            height: chipCol.implicitHeight + 30
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: chipCol
                x: Ax.pad; y: 15; width: parent.width - 2 * Ax.pad
                spacing: 12
                Label { text: "Panels that open on hover"; font.weight: Font.Medium }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: [
                            { k: "hoverDashboard", t: "Dashboard", i: "space_dashboard" },
                            { k: "hoverQuick", t: "Quick settings", i: "toggle_on" },
                            { k: "hoverNetwork", t: "Network", i: "wifi" },
                            { k: "hoverAudio", t: "Audio", i: "volume_up" },
                            { k: "hoverNotifications", t: "Notifications", i: "notifications" },
                            { k: "hoverClipboard", t: "Clipboard", i: "content_paste" },
                            { k: "hoverWallpaper", t: "Wallpaper picker", i: "wallpaper" }
                        ]
                        delegate: ChipToggle {
                            required property var modelData
                            text: modelData.t; icon: modelData.i
                            checked: !!page.prefs[modelData.k]
                            onToggled: (on) => page.prefs[modelData.k] = on
                        }
                    }
                }
            }
        }
        SRow {
            visible: page.prefs.globalHoverMode
            icon: "timer"; title: "Open delay"; desc: "How long to hover before a panel opens"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.prefs.hoverOpenDelay; from: 0; to: 800; stepSize: 10; suffix: " ms"
                       onMoved: (v) => page.prefs.hoverOpenDelay = Math.round(v) }
        }
        SRow {
            visible: page.prefs.globalHoverMode
            icon: "timer_off"; title: "Close delay"; desc: "How long a panel stays after the pointer leaves"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.prefs.hoverCloseDelay; from: 0; to: 1200; stepSize: 10; suffix: " ms"
                       onMoved: (v) => page.prefs.hoverCloseDelay = Math.round(v) }
        }
    }

    Section {
        title: "On-screen display"
        Toggle { icon: "picture_in_picture"; title: "Volume & brightness OSD"; desc: "A small overlay when you change volume or brightness"; key: "enableOsd" }
        SRow {
            visible: page.prefs.enableOsd
            icon: "hourglass_bottom"; title: "Stays for"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.prefs.osdDuration; from: 0.5; to: 5; stepSize: 0.5; decimals: 1; suffix: " s"
                       onMoved: (v) => page.prefs.osdDuration = v }
        }
    }

    Section {
        title: "Motion"
        SRow {
            icon: "speed"; title: "Animation speed"; desc: "Faster or slower than the ArchangelOS default"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.prefs.animSpeed; from: 0.5; to: 2.0; stepSize: 0.1; decimals: 1; suffix: "×"
                       onMoved: (v) => page.prefs.animSpeed = Math.round(v * 10) / 10 }
        }
        SRow {
            icon: "animation"; title: "Animation feel"; desc: "The curve panels open and close on"
            AxSelect { width: 200; anchors.verticalCenter: parent.verticalCenter
                       model: page.curveNames; current: page.curves.indexOf(page.prefs.animCurve)
                       onPicked: (i) => page.prefs.animCurve = page.curves[i] }
        }
    }
}
