// Language & Region — the system language and the formats for dates, numbers and money.
// Applied with localectl (the locale is generated first if it isn't yet); takes effect at the
// next sign-in.
import QtQuick
import Quickshell.Io
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "System"
    title: "Language & Region"
    desc: "The language apps use and how dates, numbers and money are written."

    property var supported: []         // ["en_US.UTF-8", ...]
    property string lang: ""
    property string formats: ""
    property string pendingLang: ""
    property string pendingFmt: ""
    property string busy: ""
    property string error: ""
    property bool changed: false
    readonly property date sample: new Date(2026, 9, 22, 14, 30)

    Cmd { id: cmd }
    FileView {
        path: "/usr/share/i18n/SUPPORTED"
        onLoaded: page.supported = text().split("\n").filter(l => / UTF-8$/.test(l)).map(l => l.split(" ")[0])
                    .sort((a, b) => page.nameOf(a).localeCompare(page.nameOf(b)))
    }
    function read() {
        cmd.run(["localectl", "status"], (c, out) => {
            const m = /LANG=(\S+)/.exec(out), t = /LC_TIME=(\S+)/.exec(out);
            page.lang = m ? m[1] : "C.UTF-8";
            page.formats = t ? t[1] : page.lang;
            page.pendingLang = page.lang; page.pendingFmt = page.formats;
        });
    }
    Component.onCompleted: read()

    function base(code) { return String(code).replace(/\..*$/, ""); }
    function nameOf(code) {
        const l = Qt.locale(page.base(code));
        if (!l || l.name === "C") return code;
        const n = l.nativeLanguageName || code, t = l.nativeTerritoryName || "";
        return (n.charAt(0).toUpperCase() + n.slice(1)) + (t ? " (" + t + ")" : "");
    }
    function apply() {
        page.busy = "apply"; page.error = "";
        cmd.run(["/usr/lib/archangelos/axs-admin", "locale-set", page.pendingLang, page.pendingFmt], (c, o, e) => {
            page.busy = "";
            if (c !== 0) page.error = (e || o).trim() || "Couldn't change the language.";
            else { page.changed = true; page.read(); }
        });
    }

    Section {
        title: "Language"
        SRow {
            icon: "translate"; title: "System language"; desc: "Menus, apps and messages"
            AxSelect { width: 300; anchors.verticalCenter: parent.verticalCenter; searchable: true
                       model: page.supported.map(c => page.nameOf(c) + "  —  " + page.base(c))
                       current: page.supported.indexOf(page.pendingLang)
                       onPicked: (i) => { page.pendingLang = page.supported[i]; if (page.pendingFmt === page.lang) page.pendingFmt = page.pendingLang; } }
        }
        SRow {
            icon: "calendar_month"; title: "Formats"; desc: "Dates, times, numbers, currency and units"
            AxSelect { width: 300; anchors.verticalCenter: parent.verticalCenter; searchable: true
                       model: page.supported.map(c => page.nameOf(c) + "  —  " + page.base(c))
                       current: page.supported.indexOf(page.pendingFmt)
                       onPicked: (i) => page.pendingFmt = page.supported[i] }
        }
        SRow {
            icon: "keyboard"; title: "Keyboard layouts"; desc: "Set in Keyboard & Mouse"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("input")
        }
    }

    // a live sample in the chosen formats
    Rectangle {
        id: sampleCard
        readonly property var loc: Qt.locale(page.base(page.pendingFmt))
        width: parent.width; height: 132
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Grid {
            x: 28; anchors.verticalCenter: parent.verticalCenter
            columns: 2; columnSpacing: 36; rowSpacing: 10
            Repeater {
                model: [
                    ["Date", sampleCard.loc.toString(page.sample, Locale.LongFormat).replace(/ \d+:\d+.*$/, "")],
                    ["Short date", sampleCard.loc.toString(page.sample, sampleCard.loc.dateFormat(Locale.ShortFormat))],
                    ["Time", sampleCard.loc.toString(page.sample, sampleCard.loc.timeFormat(Locale.ShortFormat))],
                    ["Number", Number(1234567.89).toLocaleString(sampleCard.loc, "f", 2)],
                    ["Money", Number(1234.5).toLocaleCurrencyString(sampleCard.loc)],
                    ["Units", sampleCard.loc.measurementSystem === Locale.MetricSystem ? "Metric" : "Imperial"]
                ]
                Row {
                    required property var modelData
                    spacing: 14
                    Label { width: 90; caption: true; text: modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                    Label { mono: true; font.pixelSize: Ax.fsSmall; text: modelData[1] }
                }
            }
        }
    }

    Row {
        spacing: 10
        AxButton { text: page.busy === "apply" ? "Applying…" : "Apply"; kind: "primary"
                   enabled_: page.busy === "" && (page.pendingLang !== page.lang || page.pendingFmt !== page.formats)
                   onClicked: page.apply() }
        AxButton { text: "Reset"; visible: page.pendingLang !== page.lang || page.pendingFmt !== page.formats
                   onClicked: { page.pendingLang = page.lang; page.pendingFmt = page.formats; } }
        Label { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Ax.fsSmall
                color: page.error !== "" ? Ax.danger : Ax.subtext
                text: page.error !== "" ? page.error : page.changed ? "Saved. Sign out and back in to see it everywhere." : "" }
    }
}
