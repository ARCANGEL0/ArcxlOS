pragma Singleton
import QtQuick

// ArchangelOS capture theme — charcoal field with an ember accent, keyed to
// the same sumi-e language as the launcher.
QtObject {
  readonly property color ink:   "#e7e5e0"   // hairlines / text
  readonly property color inkd:  Qt.rgba(231/255, 229/255, 224/255, 0.55)

  // ember ramps — smoke → cinder. shotEmber is cool ash, recEmber is hot red.
  readonly property color smoke:    "#0c0b0a"
  readonly property color shotEmber: "#c9c4bb"
  readonly property color recEmber:  "#e0362a"
  readonly property color recGlow:   "#ff6a4d"

  readonly property string mono:    "Quantico"
  readonly property string display: "Shippori Mincho"
}
