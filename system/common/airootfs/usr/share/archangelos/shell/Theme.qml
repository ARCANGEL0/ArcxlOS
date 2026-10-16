pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Palette + type + motion tokens. The base ink colours follow the SDDM
// theme; the accent (and, on colourful wallpapers, the ink tint) is written
// by archangelos-shell-theme and hot-reloads here.
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

    // Panel surfaces and hairline.
    readonly property color sidebar: Qt.darker(ink, 1.18)
    readonly property color surface: Qt.tint(ink, "#0AFFFFFF")
    readonly property color surfaceHot: Qt.tint(ink, Qt.alpha(accent, 0.07))
    readonly property color line: "#22FFFFFF"

    readonly property string sans: "Quantico"
    readonly property string serif: "Shippori Mincho"
    readonly property string glyphs: "Symbols Nerd Font"

    // Preview aid: ARCHANGELOS_SHELL_SLOWMO=4 plays every animation 4x slower.
    readonly property real motion: Number(Quickshell.env("ARCHANGELOS_SHELL_SLOWMO")) || 1
    readonly property int quick: 180 * motion
    readonly property int medium: 320 * motion
    readonly property int slow: 520 * motion
    readonly property int curve: Easing.OutExpo

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
