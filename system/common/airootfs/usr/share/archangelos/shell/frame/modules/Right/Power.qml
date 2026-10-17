// ArchangelOS: power button in the top-right cluster. Opens the session menu
// (shutdown / reboot / log out / lock / suspend) out of the right notch.
import QtQuick
import "../../components"
import "../../"
import "../../services/"

IconBtn {
    text: "⏻"
    textColor: Theme.active
    onClicked: {
        var next = !Popups.powerOpen
        Popups.closeAll()
        SurfaceState.toggle("right", "power")
        if (next) Popups.powerPinned = true
    }
}
