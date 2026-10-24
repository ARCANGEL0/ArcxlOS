// ArchangelOS Settings — design tokens.
//
// Everything derives from the live shell palette (ArcShell's Theme: the AMOLED overrides or the
// matugen palette), so the settings window always matches the desktop and follows the accent the
// user picks. Layers step up from the window background in small, warm increments; crimson is
// reserved for state (active, on, selected) and danger, never for plain labels.
pragma Singleton

import QtQuick
import Quickshell
import "../frame" as Frame

Singleton {
    id: root

    function solid(c) { return Qt.rgba(c.r, c.g, c.b, 1); }
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // --- palette ---
    readonly property color base:     solid(Frame.Theme.background)        // window
    readonly property color text:     solid(Frame.Theme.text)
    readonly property color subtext:  mix(solid(Frame.Theme.text), solid(Frame.Theme.background), 0.38)
    readonly property color accent:   solid(Frame.Theme.active)
    readonly property color border:   mix(base, solid(Frame.Theme.border), 0.16)

    readonly property color sidebar:  mix(base, text, 0.025)
    readonly property color panel:    mix(base, text, 0.045)                // section cards
    readonly property color raised:   mix(base, text, 0.075)                // fields, tracks
    readonly property color hover:    alpha(text, 0.045)
    readonly property color muted:    mix(text, base, 0.46)                 // descriptions
    readonly property color faint:    mix(text, base, 0.6)                  // captions, meta
    readonly property color divider:  alpha(text, 0.06)

    readonly property color accentSoft: alpha(accent, 0.16)
    readonly property color accentLine: alpha(accent, 0.55)
    readonly property color danger:     "#d96a6a"
    readonly property color ok:         mix(accent, Qt.rgba(0.498, 0.749, 0.604, 1), 0.72)

    // --- type ---
    FontLoader { id: interFont;  source: Qt.resolvedUrl("../arc/assets/fonts/InterVariable.ttf") }
    FontLoader { id: monoFont;   source: Qt.resolvedUrl("../arc/assets/fonts/DepartureMono-Regular.otf") }
    FontLoader { id: iconFont;   source: Qt.resolvedUrl("../arc/assets/fonts/MaterialSymbolsRounded.ttf") }
    readonly property string sans: interFont.name || "sans-serif"
    readonly property string mono: monoFont.name || "monospace"
    readonly property string icons: iconFont.name

    readonly property int fsTitle: 26
    readonly property int fsHead: 15
    readonly property int fsBody: 13
    readonly property int fsSmall: 12
    readonly property int fsCaption: 10      // mono, uppercase section/meta labels

    // --- shape & motion ---
    readonly property int radius: 14
    readonly property int radiusSm: 9
    readonly property int pad: 18
    readonly property int rowH: 58
    readonly property int dur: 180
    readonly property int durSlow: 320
}
