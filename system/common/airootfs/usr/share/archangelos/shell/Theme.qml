pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Palette + type + motion tokens. Colours are written by
// archangelos-shell-theme (from the wallpaper) and hot-reload here.
Singleton {
    id: theme

    readonly property color brand: "#C24A52"

    property var pal: ({})
    readonly property bool mono: pal.mono !== false
    readonly property color accent: pal.accent || brand
    readonly property color ink: pal.ink || "#0E0E0D"
    readonly property color surface: pal.surface || "#161615"
    readonly property color fg: pal.fg || "#ECEBE8"
    readonly property color dim: pal.dim || "#9A9895"
    readonly property color faint: pal.faint || "#5E5D5A"
    readonly property color line: Qt.alpha(fg, 0.09)

    readonly property string sans: "Quantico"
    readonly property string serif: "Shippori Mincho"
    readonly property string glyphs: "Symbols Nerd Font"

    // Motion: one easing family everywhere so the shell moves as one body.
    readonly property int quick: 180
    readonly property int medium: 320
    readonly property int morph: 520
    readonly property int curve: Easing.OutExpo

    readonly property var numerals: ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    function kanji(n) { return n >= 0 && n < numerals.length ? numerals[n] : String(n) }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/archangelos/shell-palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { theme.pal = JSON.parse(text()) } catch (e) { console.warn("palette:", e) }
        }
    }
}
