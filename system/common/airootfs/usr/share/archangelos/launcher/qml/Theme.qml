pragma Singleton
import QtQuick

// ArchangelOS launcher theme — monochrome sumi-e, keyed to the grayscale
// samurai wallpaper. API mirrors the unit3 Theme so ported components work.
QtObject {
  // base surfaces
  readonly property color bg:     "#0a0a09"
  readonly property color bg2:    "#101010"
  readonly property color bg3:    "#171614"

  // ink / foreground
  readonly property color fg:     "#e7e5e0"
  readonly property color fgd:    Qt.rgba(231/255, 229/255, 224/255, 0.52)
  readonly property color fgdd:   Qt.rgba(231/255, 229/255, 224/255, 0.20)

  // accents — a neutral silver ramp (no color; matches the B/W wallpaper)
  readonly property color a1:     "#e9e6df"   // primary / focus glow
  readonly property color a2:     "#b9b6ae"
  readonly property color a3:     "#8f8c85"
  readonly property color a4:     "#f4f1ea"

  // hairlines
  readonly property color ln:     Qt.rgba(231/255, 229/255, 224/255, 0.12)
  readonly property color lnm:    Qt.rgba(231/255, 229/255, 224/255, 0.26)

  // fonts (shipped with ArchangelOS)
  readonly property string mono:    "Quantico"
  readonly property string display: "Shippori Mincho"

  // animation timings — smooth flow
  readonly property int durationFast: 150
  readonly property int durationMid:  380
  readonly property int durationSlow: 640
}
