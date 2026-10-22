// Body text in the UI face. `mono` switches to the technical face for values and meta.
import QtQuick
import qs.axs

Text {
    property bool mono: false
    property bool caption: false            // small, uppercase, letter-spaced mono meta label
    font.family: (mono || caption) ? Ax.mono : Ax.sans
    font.pixelSize: caption ? Ax.fsCaption : Ax.fsBody
    font.letterSpacing: caption ? 1.4 : 0
    font.capitalization: caption ? Font.AllUppercase : Font.MixedCase
    color: caption ? Ax.faint : Ax.text
    elide: Text.ElideRight
    renderType: Text.QtRendering
    Behavior on color { ColorAnimation { duration: Ax.dur } }
}
