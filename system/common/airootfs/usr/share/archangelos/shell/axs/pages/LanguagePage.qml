// Language & Region — the system language, your country (and with it how dates, numbers and money
// are written), the keyboard, and the time zone. The globe shows the country you've picked and a
// pin for your time zone's city. Language and formats are applied with localectl (the locale is
// generated first if needed) and reach apps at the next sign-in; keyboard and time zone apply now.
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
    desc: "Your language, your country, your keyboard and your time."

    property var supported: []         // ["en_US.UTF-8", ...]
    property string lang: ""
    property string formats: ""
    property string pendingLang: ""
    property string pendingFmt: ""
    property string busy: ""
    property string error: ""
    property bool changed: false
    property var layoutNames: ({})     // "us" → "English (US)"
    property var variants: ({})        // "us" → [{ code, name }]
    readonly property date sample: new Date(2026, 9, 22, 14, 30, 5)

    Cmd { id: cmd }
    FileView {
        path: "/usr/share/i18n/SUPPORTED"
        onLoaded: page.supported = text().split("\n").filter(l => / UTF-8$/.test(l)).map(l => l.split(" ")[0])
                    .sort((a, b) => page.nameOf(a).localeCompare(page.nameOf(b)))
    }
    FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        onLoaded: {
            const names = {}, vars = {};
            let sec = "";
            for (const l of text().split("\n")) {
                if (l.startsWith("! ")) { sec = l.slice(2).trim(); continue; }
                let m;
                if (sec === "layout" && (m = /^\s+(\S+)\s+(.+)$/.exec(l))) names[m[1]] = m[2].trim();
                else if (sec === "variant" && (m = /^\s+(\S+)\s+(\S+):\s+(.+)$/.exec(l))) (vars[m[2]] = vars[m[2]] || []).push({ code: m[1], name: m[3].trim() });
            }
            page.layoutNames = names; page.variants = vars;
        }
    }
    function read() {
        cmd.run(["localectl", "status"], (c, out) => {
            const m = /LANG=(\S+)/.exec(out), t = /LC_TIME=(\S+)/.exec(out);
            page.lang = m ? m[1] : "C.UTF-8";
            page.formats = t ? t[1] : page.lang;
            page.pendingLang = page.lang; page.pendingFmt = page.formats;
        });
    }
    Component.onCompleted: { read(); Geo.refresh(); NSS.Input.active = true; NSS.Input.refresh(); }
    Component.onDestruction: NSS.Input.active = false

    function base(code) { return String(code).replace(/\..*$/, ""); }
    function cc(code) { const m = /_([A-Z]{2})/.exec(code || ""); return m ? m[1] : ""; }
    function langOf(code) { return String(code).split("_")[0]; }
    function nameOf(code) {
        // C / POSIX is the built-in fallback: no language chosen yet
        if (/^(C|POSIX)(\.|$)/.test(String(code))) return "Not set (system default, English)";
        const l = Qt.locale(page.base(code));
        if (!l || l.name === "C") return code;
        const n = l.nativeLanguageName || code, t = l.nativeTerritoryName || "";
        return (n.charAt(0).toUpperCase() + n.slice(1)) + (t ? " (" + t + ")" : "");
    }
    function countryName(c) { return globe.world[c] ? globe.world[c].n : (c || "—"); }

    // countries that have at least one locale, by name
    readonly property var countries: {
        const seen = {};
        for (const l of page.supported) { const c = page.cc(l); if (c) seen[c] = true; }
        return Object.keys(seen).sort((a, b) => page.countryName(a).localeCompare(page.countryName(b)));
    }
    readonly property string country: page.cc(page.pendingFmt)
    // Picking a country picks its formats, in your language if the country has it.
    function pickCountry(c) {
        const inLang = page.supported.find(l => page.cc(l) === c && page.langOf(l) === page.langOf(page.pendingLang));
        page.pendingFmt = inLang || page.supported.find(l => page.cc(l) === c) || page.pendingFmt;
    }
    function apply() {
        page.busy = "apply"; page.error = "";
        cmd.run(["/usr/lib/archangelos/axs-admin", "locale-set", page.pendingLang, page.pendingFmt], (c, o, e) => {
            page.busy = "";
            if (c === 126 || c === 127) page.error = "Cancelled.";
            else if (c !== 0) page.error = (e || o).trim() || "Couldn't change the language.";
            else { page.changed = true; page.read(); }
        });
    }
    readonly property bool dirty: page.pendingLang !== page.lang || page.pendingFmt !== page.formats

    // ── globe ──────────────────────────────────────────────────────────────────
    Rectangle {
        id: hero
        readonly property var loc: Qt.locale(page.base(page.pendingFmt))
        width: parent.width; height: 280
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        clip: true
        CornerTicks { len: 10; anchors.margins: 12 }
        Globe {
            id: globe
            x: 24; anchors.verticalCenter: parent.verticalCenter
            width: 240; height: 240
            highlight: page.country
            pin: Geo.zone ? { lon: Geo.zone.lon, lat: Geo.zone.lat } : null
        }
        Column {
            anchors.left: globe.right; anchors.leftMargin: 32
            anchors.right: parent.right; anchors.rightMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Label { caption: true; text: "Region"; color: Ax.accent }
            Label { width: parent.width; text: page.country ? page.countryName(page.country) : "Not set"; font.pixelSize: 28; font.weight: Font.DemiBold; font.letterSpacing: -0.4 }
            Item { width: 1; height: 8 }
            Grid {
                columns: 2; columnSpacing: 18; rowSpacing: 9
                Repeater {
                    model: [
                        ["Language", page.nameOf(page.pendingLang)],
                        ["Keyboard", NSS.Input.layouts.length ? (page.layoutNames[NSS.Input.layouts[0]] || NSS.Input.layouts[0]) : "—"],
                        ["Time zone", Geo.timezone.replace(/_/g, " ")],
                        ["Date", hero.loc.toString(page.sample, hero.loc.dateFormat(Locale.ShortFormat))],
                        ["Time", hero.loc.toString(page.sample, hero.loc.timeFormat(Locale.LongFormat).replace(/\s*t+\s*$/, ""))],
                        ["Number", Number(1234567.89).toLocaleString(hero.loc, "f", 2)],
                        ["Currency", hero.loc.currencySymbol(Locale.CurrencyIsoCode) ? hero.loc.currencySymbol(Locale.CurrencyIsoCode) + " (" + hero.loc.currencySymbol(Locale.CurrencySymbol) + ")" : "—"]
                    ]
                    Row {
                        required property var modelData
                        spacing: 0
                        Label { width: 84; caption: true; text: modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                        Label { mono: true; font.pixelSize: Ax.fsSmall; text: modelData[1] }
                    }
                }
            }
        }
    }

    Row {
        visible: page.dirty || page.changed || page.error !== ""
        spacing: 10
        AxButton { visible: page.dirty; text: page.busy === "apply" ? "Applying…" : "Apply language and formats"; kind: "primary"
                   enabled_: page.busy === ""; onClicked: page.apply() }
        AxButton { visible: page.dirty; text: "Reset"; onClicked: { page.pendingLang = page.lang; page.pendingFmt = page.formats; } }
        Label { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Ax.fsSmall
                color: page.error !== "" ? Ax.danger : Ax.subtext
                text: page.error !== "" ? page.error : page.changed && !page.dirty ? "Saved. Sign out and back in for apps to switch over." : "" }
    }

    Section {
        title: "Language"
        SRow {
            icon: "translate"; title: "System language"; desc: "Menus, apps and messages"
            AxSelect { width: 300; anchors.verticalCenter: parent.verticalCenter; searchable: true
                       model: page.supported.map(c => page.nameOf(c) + "  —  " + page.base(c))
                       current: page.supported.indexOf(page.pendingLang)
                       placeholder: page.nameOf(page.pendingLang)
                       onPicked: (i) => page.pendingLang = page.supported[i] }
        }
        SRow {
            icon: "info"; dim: true
            title: "ArcShell speaks English for now"
            desc: "Apps follow the system language. The desktop's own panels and Settings will follow once they're translated."
        }
    }

    Section {
        title: "Region"
        SRow {
            icon: "flag"; title: "Country or region"; desc: "Sets how dates, times, numbers, money and units are written"
            AxSelect { width: 300; anchors.verticalCenter: parent.verticalCenter; searchable: true
                       model: page.countries.map(c => page.countryName(c))
                       current: page.countries.indexOf(page.country)
                       onPicked: (i) => page.pickCountry(page.countries[i]) }
        }
        SRow {
            icon: "calendar_month"; title: "Formats"; desc: "The exact locale used for them"
            AxSelect { width: 300; anchors.verticalCenter: parent.verticalCenter; searchable: true
                       readonly property var opts: page.supported.filter(l => page.cc(l) === page.country)
                       model: opts.map(c => page.nameOf(c) + "  —  " + page.base(c))
                       current: opts.indexOf(page.pendingFmt)
                       onPicked: (i) => page.pendingFmt = opts[i] }
        }
        SRow {
            readonly property var here: Geo.zonesFor(page.country)
            visible: !Geo.auto && here.length > 0 && !here.some(z => z.tz === Geo.timezone)
            icon: "schedule"; title: "Use " + (here.length ? here[0].tz.split("/").pop().replace(/_/g, " ") : "") + " time?"
            desc: "Your time zone is in a different country"
            AxButton { text: "Use it"; anchors.verticalCenter: parent.verticalCenter; onClicked: Geo.setZone(parent.parent.here[0].tz) }
        }
    }

    Section {
        title: "Keyboard"
        note: NSS.Input.activeKeymap
        EmptyState {
            visible: NSS.Input.layouts.length === 0
            icon: "keyboard"; title: "No keyboard reported"
            desc: "Layouts come from Hyprland and show up here once the desktop runs on it."
        }
        SRow {
            visible: NSS.Input.layouts.length > 0
            icon: "keyboard"; title: "Layout"; desc: "The main keyboard layout"
            AxSelect { width: 300; anchors.verticalCenter: parent.verticalCenter; searchable: true
                       readonly property var codes: Object.keys(page.layoutNames).sort((a, b) => page.layoutNames[a].localeCompare(page.layoutNames[b]))
                       model: codes.map(c => page.layoutNames[c])
                       current: codes.indexOf(NSS.Input.layouts[0])
                       onPicked: (i) => {
                           const l = NSS.Input.layouts.slice(), v = NSS.Input.variants.slice();
                           const at = l.indexOf(codes[i]);
                           if (at > 0) { l.splice(at, 1); v.splice(at, 1); }
                           if (at !== 0) { l.unshift(codes[i]); v.unshift(""); }
                           NSS.Input.applyLayouts(l, v);
                       } }
        }
        SRow {
            visible: NSS.Input.layouts.length > 0 && (page.variants[NSS.Input.layouts[0]] || []).length > 0
            icon: "language"; title: "Keyboard variant"; desc: "Regional or special versions of the layout, like dead keys or Dvorak"
            AxSelect { width: 300; anchors.verticalCenter: parent.verticalCenter; searchable: true
                       readonly property var opts: [{ code: "", name: "Standard" }].concat(page.variants[NSS.Input.layouts[0]] || [])
                       model: opts.map(o => o.name)
                       current: Math.max(0, opts.findIndex(o => o.code === (NSS.Input.variants[0] || "")))
                       onPicked: (i) => { const v = NSS.Input.variants.slice(); v[0] = opts[i].code; NSS.Input.applyLayouts(NSS.Input.layouts, v); } }
        }
        SRow {
            visible: NSS.Input.layouts.length > 0
            icon: "login"; title: "Login screen keyboard"; desc: "Use this layout when typing your password at sign-in too"
            AxButton { text: "Use there too"; anchors.verticalCenter: parent.verticalCenter
                       onClicked: cmd.run(["localectl", "set-x11-keymap", NSS.Input.layouts.join(","), "", NSS.Input.variants.join(",")],
                                          (c, o, e) => { if (c !== 0) page.error = (e || o).trim(); }) }
        }
        SRow {
            icon: "keyboard_alt"; title: "More layouts and typing options"; desc: "Extra layouts, switching shortcut, Caps Lock, repeat"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("input")
        }
    }

    TimeSection { country: page.country }
}
