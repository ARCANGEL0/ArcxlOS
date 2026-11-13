import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    readonly property string themeDir: {
        const d = Quickshell.env("ARCHANGELOS_LOCK_THEME");
        return (d && d.length > 0) ? d : "/usr/share/sddm/themes/archangelos";
    }
    readonly property string me: Quickshell.env("USER") || Quickshell.env("LOGNAME") || (Quickshell.env("HOME") || "").split("/").pop()
    property string pending: ""
    property bool unlocking: false

    readonly property var config: parseConf(themeConf.text())

    function parseConf(text) {
        const out = {
            background: "assets/background.mp4", backgroundFallback: "assets/background.png", logo: "assets/logo.png",
            colorText: "#ECEBE8", colorDim: "#9A9895", colorFaint: "#5E5D5A", colorLine: "#E9E7E3",
            colorAccent: "#C24A52", colorInk: "#0E0E0D", fontFamily: "Quantico",
            loopBackground: "true", muteBackground: "true", showSessionMenu: "false", showPowerButtons: "true", logoDust: "true"
        };
        for (const raw of (text || "").split("\n")) {
            const line = raw.trim();
            if (line.length === 0 || line.startsWith("#") || line.startsWith("[")) continue;
            const eq = line.indexOf("=");
            if (eq < 1) continue;
            const key = line.slice(0, eq).trim();
            if (key === "showSessionMenu") continue;
            out[key] = line.slice(eq + 1).trim();
        }
        return out;
    }

    FileView {
        id: themeConf
        path: root.themeDir + "/theme.conf"
        blockLoading: true
    }

    readonly property QtObject sddm: QtObject {
        property bool canPowerOff: true
        property bool canReboot: true
        property bool canSuspend: true
        property string hostName: ""
        signal loginFailed()
        signal loginSucceeded()
        function login(user, password, session) { root.tryUnlock(user, password); }
        function powerOff() { Quickshell.execDetached(["systemctl", "poweroff"]); }
        function reboot() { Quickshell.execDetached(["systemctl", "reboot"]); }
        function suspend() { Quickshell.execDetached(["systemctl", "suspend"]); }
    }
    readonly property ListModel sessionModel: ListModel {
        property int lastIndex: 0
        ListElement { name: "Hyprland"; file: "hyprland.desktop" }
    }
    readonly property QtObject userModel: QtObject {
        property string lastUser: root.me
        property int count: 1
    }
    readonly property QtObject keyboard: QtObject {
        property bool capsLock: false
        property bool numLock: false
    }

    function tryUnlock(user, password) {
        if (root.unlocking || pam.active) return;
        if (user && user.trim() !== root.me) {
            root.sddm.loginFailed();
            return;
        }
        root.pending = password || "";
        if (!pam.start()) {
            root.pending = "";
            root.sddm.loginFailed();
        }
    }

    PamContext {
        id: pam
        config: "archangelos-lock"
        user: root.me
        onResponseRequiredChanged: {
            if (responseRequired) pam.respond(root.pending);
        }
        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success) {
                root.unlocking = true;
                root.sddm.loginSucceeded();
                lock.locked = false;
                quitTimer.start();
            } else {
                root.sddm.loginFailed();
            }
        }
    }

    Timer {
        id: quitTimer
        interval: 250
        onTriggered: Qt.quit()
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surface
            color: root.config.colorInk || "#0E0E0D"

            Loader {
                id: theme
                anchors.fill: parent
                focus: true
                source: "file://" + root.themeDir + "/Main.qml"
                onLoaded: focusTimer.start()
            }

            function findPass(item) {
                if (!item) return null;
                for (let i = 0; i < item.children.length; i++) {
                    const found = findPass(item.children[i]);
                    if (found) return found;
                }
                return item.echoMode === TextInput.Password ? item : null;
            }

            Timer {
                id: focusTimer
                interval: 200
                onTriggered: {
                    const field = surface.findPass(theme.item);
                    if (field) field.forceActiveFocus();
                    else theme.forceActiveFocus();
                }
            }

            Connections {
                target: root.sddm
                function onLoginFailed() { focusTimer.restart(); }
            }
        }
    }
}
