pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Palette + type + motion tokens. The base colours are those of
// archangelos-launcher / the SDDM theme; the accent (and, on colourful
// wallpapers, the ink tint) is written by archangelos-shell-theme and
// hot-reloads here.
Singleton {
    id: theme

    readonly property color brand: "#C24A52"

    property var pal: ({})
    readonly property bool mono: pal.mono !== false
    readonly property color accent: pal.accent || brand
    readonly property color ink: pal.ink || "#0C0C0B"
    readonly property color fg: pal.fg || "#ECEBE8"
    readonly property color dim: pal.dim || "#9A9895"
    readonly property color faint: pal.faint || "#5E5D5A"

    // Launcher surfaces (C_SIDEBAR / C_SURFACE / C_SURFACE2 / C_LINE).
    readonly property color sidebar: Qt.darker(ink, 1.18)
    readonly property color surface: Qt.tint(ink, "#0AFFFFFF")
    readonly property color surfaceHot: Qt.tint(ink, Qt.alpha(accent, 0.07))
    readonly property color line: "#22FFFFFF"

    readonly property string sans: "Quantico"
    readonly property string serif: "Shippori Mincho"
    readonly property string glyphs: "Symbols Nerd Font"

    readonly property int quick: 180
    readonly property int medium: 320
    readonly property int slow: 520
    readonly property int curve: Easing.OutExpo
    // Preview aid: ARCHANGELOS_SHELL_SLOWMO=8 plays panel flows 8x slower.
    readonly property real motion: Number(Quickshell.env("ARCHANGELOS_SHELL_SLOWMO")) || 1

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
