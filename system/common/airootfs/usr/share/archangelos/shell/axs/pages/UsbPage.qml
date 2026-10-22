// USB devices — USBGuard: when on, devices plugged in now stay allowed and anything new waits
// for your OK here (keyboards that type by themselves, rogue chargers, BadUSB sticks).
import QtQuick
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "USB devices"
    desc: "Decide which USB devices may talk to this computer."

    property bool installed: false
    property bool on: false
    property var devs: []              // { id, target, name, vidpid, port }
    property var plain: []             // lsusb when USBGuard is off
    property string busy: ""
    property string error: ""

    Cmd { id: cmd }
    function load() {
        cmd.sh('command -v usbguard >/dev/null && echo inst=1 || echo inst=0; echo "act=$(systemctl is-active usbguard 2>/dev/null)"; echo "--list"; '
             + 'systemctl is-active -q usbguard && usbguard list-devices 2>/dev/null || lsusb 2>/dev/null | sed "s/^/LSUSB /"', [], (c, o) => {
            const [a, b] = o.split("--list");
            page.installed = a.indexOf("inst=1") >= 0; page.on = a.indexOf("act=active") >= 0;
            const d = [], p = [];
            for (const l of (b || "").split("\n")) {
                let m;
                if ((m = /^(\d+): (allow|block|reject) id (\S+) .*?name "([^"]*)".*?via-port "([^"]*)"/.exec(l))) d.push({ id: m[1], target: m[2], vidpid: m[3], name: m[4] || m[3], port: m[5] });
                else if ((m = /^LSUSB Bus (\d+) Device (\d+): ID (\S+) (.*)$/.exec(l))) { if (!/root hub/i.test(m[4])) p.push({ vidpid: m[3], name: m[4], port: "bus " + m[1] }); }
            }
            page.devs = d.sort((x, y) => (x.target === "allow") - (y.target === "allow")); page.plain = p;
        });
    }
    Component.onCompleted: load()
    Timer { interval: 2500; running: true; repeat: true; onTriggered: page.load() }
    function act(what, argv) {
        page.busy = what; page.error = "";
        cmd.run(argv, (c, o, e) => { page.busy = ""; if (c !== 0 && c !== 126) page.error = (e || o).trim().split("\n").pop(); page.load(); });
    }
    readonly property var waiting: devs.filter(x => x.target !== "allow")

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }

    Section {
        title: "Protection"
        EmptyState { visible: !page.installed; icon: "usb"; title: "USBGuard isn't installed"; desc: "Install it with  sudo pacman -S usbguard." }
        SRow {
            visible: page.installed
            icon: page.on ? "usb" : "usb_off"; title: "Ask before new USB devices work"
            desc: page.on ? "Devices plugged in later are blocked until you allow them below"
                          : "Off — any device works the moment it's plugged in. Turning this on keeps everything connected now"
            AxSwitch { checked: page.on; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.act("svc", ["/usr/lib/archangelos/axs-sec", on ? "usbguard-on" : "usbguard-off"]) }
        }
    }

    Section {
        visible: page.on && page.waiting.length > 0
        title: "Waiting for you"
        Repeater {
            model: page.waiting
            SRow {
                required property var modelData
                icon: "gpp_maybe"; title: modelData.name; desc: modelData.vidpid + "  ·  port " + modelData.port + "  ·  blocked"
                AxButton { text: "Allow once"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.act("a", ["usbguard", "allow-device", modelData.id]) }
                AxButton { text: "Always allow"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.act("a", ["usbguard", "allow-device", "-p", modelData.id]) }
            }
        }
    }

    Section {
        title: "Connected"
        note: (page.on ? page.devs.filter(x => x.target === "allow") : page.plain).length + ""
        Repeater {
            model: page.on ? page.devs.filter(x => x.target === "allow") : page.plain
            SRow {
                required property var modelData
                icon: /keyboard/i.test(modelData.name) ? "keyboard" : /mouse|receiver/i.test(modelData.name) ? "mouse" : /hub/i.test(modelData.name) ? "hub" : /storage|disk|flash|card/i.test(modelData.name) ? "sd_card" : "usb"
                title: modelData.name; desc: modelData.vidpid + "  ·  " + modelData.port
                AxButton { visible: page.on; text: "Block"; kind: "danger"; anchors.verticalCenter: parent.verticalCenter; onClicked: page.act("b", ["usbguard", "block-device", "-p", modelData.id]) }
            }
        }
    }
}
