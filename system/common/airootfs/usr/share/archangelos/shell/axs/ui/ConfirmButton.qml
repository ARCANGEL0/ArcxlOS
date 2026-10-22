// A destructive button that asks once more: the first click arms it for a few seconds.
import QtQuick
import qs.axs

AxButton {
    id: b
    property string confirmText: "Are you sure?"
    property bool armed: false
    signal confirmed()
    kind: "danger"
    text: armed ? confirmText : (b.label || "")
    property string label: ""
    onClicked: { if (armed) { armed = false; disarm.stop(); confirmed(); } else { armed = true; disarm.restart(); } }
    Timer { id: disarm; interval: 3500; onTriggered: b.armed = false }
}
