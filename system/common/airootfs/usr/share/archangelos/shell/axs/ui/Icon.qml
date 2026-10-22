// Material Symbols Rounded glyph by name (outlined; `filled` switches the FILL axis).
import QtQuick
import qs.axs

Text {
    property string name: ""
    property bool filled: false
    property int size: 18
    text: name
    font.family: Ax.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 400, "opsz": 24 })
    color: Ax.subtext
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Accessible.ignored: true
    Behavior on color { ColorAnimation { duration: Ax.dur } }
}
