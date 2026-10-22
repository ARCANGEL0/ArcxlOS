// The real SDDM theme (sddm/ → /usr/share/sddm/themes/archangelos), running live at 1080p and
// scaled into a card. SDDM normally hands the theme `config`, `sddm`, `userModel`,
// `sessionModel` and `keyboard`; they're stood in for here, so it draws but can't log anyone in.
import QtQuick
import Quickshell
import qs.axs

Item {
    id: host
    property bool live: true
    clip: true

    // stand-ins for what sddm-greeter provides
    readonly property var config: ({
        background: "assets/background.mp4", backgroundFallback: "assets/background.png", logo: "assets/logo.png",
        colorText: "#ECEBE8", colorDim: "#9A9895", colorFaint: "#5E5D5A", colorLine: "#E9E7E3",
        colorAccent: "#C24A52", colorInk: "#0E0E0D", fontFamily: "Quantico",
        loopBackground: "true", muteBackground: "true", showSessionMenu: "true", showPowerButtons: "true", logoDust: "true"
    })
    readonly property QtObject sddm: QtObject {
        property bool canPowerOff: true; property bool canReboot: true; property bool canSuspend: true
        property string hostName: ""
        signal loginFailed(); signal loginSucceeded()
        function login(u, p, s) {} function powerOff() {} function reboot() {} function suspend() {}
    }
    readonly property ListModel sessionModel: ListModel {
        property int lastIndex: 0
        ListElement { name: "Hyprland"; file: "hyprland.desktop" }
    }
    readonly property QtObject userModel: QtObject {
        property string lastUser: Quickshell.env("USER") || "user"
        property int count: 1
    }
    readonly property QtObject keyboard: QtObject { property bool capsLock: false; property bool numLock: false }

    Loader {
        id: theme
        active: host.live && host.visible
        // synchronous: compiled asynchronously, the theme's own components race and come up "not a type"
        source: Qt.resolvedUrl("../sddm/Main.qml")
        width: 1920; height: 1080
        scale: host.width / 1920
        transformOrigin: Item.TopLeft
        onLoaded: { item.width = 1920; item.height = 1080; }
    }
    // a picture, not a login: swallow input
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = false }
}
