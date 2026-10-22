// Profile — the machine as a specimen: an identity plate with the ArchangelOS mark, live vitals,
// and what the hardware and this desktop are.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS
import "../../src" as Frame

PageScaffold {
    id: page
    property var meta
    group: ""
    title: "Profile"
    desc: "Your machine at a glance — what it is, how it's running, and how it's dressed."

    property var info: ({})
    property int uptimeS: 0
    Component.onCompleted: { NSS.Sys.active = true; probe.running = true; }

    Process {
        id: probe
        command: ["sh", "-c",
            "printf 'host=%s\\n' \"$(cat /etc/hostname 2>/dev/null || uname -n)\";" +
            "printf 'kernel=%s\\n' \"$(uname -r)\"; printf 'arch=%s\\n' \"$(uname -m)\";" +
            "printf 'cpu=%s\\n' \"$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//;s/([^)]*)//g')\";" +
            "printf 'threads=%s\\n' \"$(nproc)\";" +
            "printf 'gpu=%s\\n' \"$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -1 | sed 's/^[^:]*: //;s/ (rev.*//')\";" +
            "printf 'pkgs=%s\\n' \"$(pacman -Qq 2>/dev/null | wc -l)\"; printf 'aur=%s\\n' \"$(pacman -Qqm 2>/dev/null | wc -l)\";" +
            "printf 'up=%s\\n' \"$(cut -d. -f1 /proc/uptime)\";" +
            "printf 'shell=%s\\n' \"$(basename \"${SHELL:-sh}\")\";" +
            "printf 'hypr=%s\\n' \"$(hyprctl version 2>/dev/null | sed -n 's/^Hyprland \\([^ ]*\\).*/\\1/p' | head -1)\";" +
            "printf 'version=%s\\n' \"$(cat /etc/archangelos/version 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); }
                page.info = o;
                page.uptimeS = parseInt(o.up || "0");
            }
        }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: { page.uptimeS += 1; clock.now = new Date(); } }
    QtObject { id: clock; property date now: new Date() }

    function fmtUptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + "d " : "") + h + "h " + (m < 10 ? "0" : "") + m + "m";
    }
    readonly property var scr: Quickshell.screens.length ? Quickshell.screens[0] : null

    // ── hero: identity plate + time/vitals ─────────────────────────────────────
    Row {
        width: parent.width
        spacing: 20

        Rectangle {
            id: plate
            width: 330; height: Math.max(430, rightCol.implicitHeight)
            radius: Ax.radius + 2
            color: Ax.panel
            border.width: 1; border.color: Ax.border
            clip: true

            // field: fine grid with a crimson ember behind the mark
            Canvas {
                id: field
                x: 14; y: 14; width: parent.width - 28; height: 236
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const g = c.createRadialGradient(width / 2, height * 0.52, 4, width / 2, height * 0.52, width * 0.62);
                    g.addColorStop(0, Qt.rgba(Ax.accent.r, Ax.accent.g, Ax.accent.b, 0.30));
                    g.addColorStop(0.55, Qt.rgba(Ax.accent.r, Ax.accent.g, Ax.accent.b, 0.06));
                    g.addColorStop(1, "transparent");
                    c.fillStyle = Qt.rgba(0, 0, 0, 0.35); c.fillRect(0, 0, width, height);
                    c.fillStyle = g; c.fillRect(0, 0, width, height);
                    c.strokeStyle = Qt.rgba(1, 1, 1, 0.035); c.lineWidth = 1;
                    for (let x = 0.5; x < width; x += 18) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, height); c.stroke(); }
                    for (let y = 0.5; y < height; y += 18) { c.beginPath(); c.moveTo(0, y); c.lineTo(width, y); c.stroke(); }
                }
                Connections { target: Ax; function onAccentChanged() { field.requestPaint(); } }
                CornerTicks { len: 10 }
                Image {
                    anchors.centerIn: parent; anchors.verticalCenterOffset: 4
                    source: Qt.resolvedUrl("../assets/mark.svg")
                    sourceSize: Qt.size(400, 293)
                    width: 200; height: 146
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                }
                Label { caption: true; text: "ARCHANGELOS"; x: 12; y: 10; font.pixelSize: 9 }
                Label { caption: true; text: page.info.version ? "v" + page.info.version : ""; anchors.right: parent.right; anchors.rightMargin: 12; y: 10; font.pixelSize: 9 }
            }

            Item {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.leftMargin: 22; anchors.rightMargin: 22; anchors.bottomMargin: 18
                height: 20
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Ax.divider }
                Label { anchors.bottom: parent.bottom; caption: true; text: "ArchangelOS  ·  " + Registry.editionName; font.pixelSize: 9 }
                Row { anchors.bottom: parent.bottom; anchors.bottomMargin: 3; anchors.right: parent.right; spacing: 4
                      Repeater { model: 3; Rectangle { required property int index; width: 5; height: 5; radius: 2.5
                                 color: index === 0 ? Ax.accent : Ax.alpha(Ax.accent, 0.35) } } }
            }
            Column {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                anchors.top: field.bottom; anchors.topMargin: 18
                spacing: 4
                Label { width: parent.width; text: page.info.host || "—"; font.pixelSize: 22; font.weight: Font.DemiBold; font.letterSpacing: -0.2 }
                Row {
                    spacing: 8
                    Label { text: (Quickshell.env("USER") || "user"); color: Ax.subtext; font.pixelSize: Ax.fsSmall }
                    Rectangle { width: 3; height: 3; radius: 1.5; color: Ax.faint; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: Registry.editionName + " Edition"; color: Ax.accent; font.pixelSize: Ax.fsSmall; font.weight: Font.Medium }
                }
                Item { width: 1; height: 12 }
                Rectangle { width: parent.width; height: 1; color: Ax.divider }
                Item { width: 1; height: 8 }
                Repeater {
                    model: [
                        ["KERNEL", page.info.kernel || "—"],
                        ["ARCH", page.info.arch || "—"],
                        ["COMPOSITOR", page.info.hypr ? "Hyprland " + page.info.hypr : "Hyprland"],
                        ["SHELL", page.info.shell || "—"],
                        ["UPTIME", page.fmtUptime(page.uptimeS)],
                        ["PACKAGES", page.info.pkgs || "—"],
                    ]
                    delegate: Item {
                        required property var modelData
                        width: parent.width; height: 24
                        Label { caption: true; text: parent.modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                        Label { mono: true; text: parent.modelData[1]; font.pixelSize: Ax.fsSmall; color: Ax.text
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.62; horizontalAlignment: Text.AlignRight }
                    }
                }
            }
        }

        Column {
            id: rightCol
            width: parent.width - plate.width - 20
            spacing: 18

            // time
            Rectangle {
                width: parent.width; height: 132
                radius: Ax.radius + 2
                color: Ax.panel
                border.width: 1; border.color: Ax.border
                Column {
                    x: 24; anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Label { caption: true; text: "Local time" }
                    Row {
                        spacing: 8
                        Label { id: bigTime; mono: true; font.pixelSize: 46; color: Ax.text
                                text: Qt.formatTime(clock.now, Frame.PrefsService.use24HourTime ? "HH:mm" : "h:mm") }
                        Label { caption: true; visible: !Frame.PrefsService.use24HourTime; text: Qt.formatTime(clock.now, "AP")
                                anchors.baseline: bigTime.baseline; font.pixelSize: 12; color: Ax.subtext }
                    }
                }
                Column {
                    anchors.right: parent.right; anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Label { anchors.right: parent.right; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: Qt.formatDate(clock.now, "dddd, d MMMM yyyy") }
                    Label { anchors.right: parent.right; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.faint; text: "up " + page.fmtUptime(page.uptimeS) }
                }
            }

            // vitals
            Grid {
                width: parent.width
                columns: 4
                columnSpacing: 12
                readonly property real tw: (width - 3 * columnSpacing) / 4
                StatTile { width: parent.tw; caption: "Processor"; value: Math.round(NSS.Sys.cpu * 100); unit: "%"; meter: NSS.Sys.cpu }
                StatTile { width: parent.tw; caption: "Memory"; value: Math.round(NSS.Sys.mem * 100); unit: "%"; meter: NSS.Sys.mem }
                StatTile { width: parent.tw; caption: "Disk"; value: Math.round(NSS.Sys.disk * 100); unit: "%"; meter: NSS.Sys.disk }
                StatTile { width: parent.tw; caption: "Temperature"; value: NSS.Sys.temp > 0 ? NSS.Sys.temp : "—"; unit: NSS.Sys.temp > 0 ? "°C" : ""; meter: NSS.Sys.temp > 0 ? NSS.Sys.temp / 100 : 0 }
            }

            Section {
                title: "Machine"
                SRow { icon: "memory"; title: "Processor"; desc: (page.info.threads ? page.info.threads + " threads" : "") + (NSS.Sys.load ? "  ·  load " + NSS.Sys.load.toFixed(2) : "")
                       Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: page.info.cpu || "—"; width: 300; horizontalAlignment: Text.AlignRight } }
                SRow { icon: "developer_board"; title: "Graphics"
                       Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: page.info.gpu || "—"; width: 300; horizontalAlignment: Text.AlignRight } }
                SRow { icon: "memory_alt"; title: "Memory"
                       Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: NSS.Sys.memTotalGb ? NSS.Sys.memUsedGb.toFixed(1) + " / " + NSS.Sys.memTotalGb.toFixed(1) + " GiB" : "—" } }
                SRow { icon: "monitor"; title: "Display"
                       Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: page.scr ? page.scr.width + " × " + page.scr.height : "—" } }
                SRow { icon: "inventory_2"; title: "Packages"; desc: "Installed from the repositories and the AUR"
                       Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: page.info.pkgs ? page.info.pkgs + " total  ·  " + page.info.aur + " AUR" : "—" } }
            }
        }
    }

    Section {
        title: "This desktop"
        SRow {
            icon: "palette"; title: "Accent"; desc: "Used for state and selection across the shell"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("appearance")
            Rectangle { width: 18; height: 18; radius: 9; color: Ax.accent; anchors.verticalCenter: parent.verticalCenter }
            Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: String(Ax.accent).toUpperCase(); anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "wallpaper"; title: "Wallpaper"; desc: "Set from the wallpaper picker or Settings › Wallpaper"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("wallpaper")
        }
        SRow {
            icon: "dashboard_customize"; title: "Shell"; desc: "Bar, island and panels"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("desktop")
            Badge { text: Frame.PrefsService.barEnabled ? "bar on" : "bar off"; tone: Frame.PrefsService.barEnabled ? "accent" : "neutral"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
