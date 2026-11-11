pragma Singleton
import QtQuick
QtObject {
  readonly property color bg:     "#0a0a09"
  readonly property color bg2:    "#101010"
  readonly property color bg3:    "#171614"
  readonly property color fg:     "#e7e5e0"
  readonly property color fgd:    Qt.rgba(231/255, 229/255, 224/255, 0.52)
  readonly property color fgdd:   Qt.rgba(231/255, 229/255, 224/255, 0.20)
  readonly property color a1:     "#e9e6df"
  readonly property color a2:     "#b9b6ae"
  readonly property color a3:     "#8f8c85"
  readonly property color a4:     "#f4f1ea"
  readonly property color accent: "#c24a52"
  readonly property color ln:     Qt.rgba(231/255, 229/255, 224/255, 0.12)
  readonly property color lnm:    Qt.rgba(231/255, 229/255, 224/255, 0.26)
  readonly property string mono:    "Quantico"
  readonly property string display: "Shippori Mincho"
  readonly property int durationFast: 150
  readonly property int durationMid:  380
  readonly property int durationSlow: 640
}
