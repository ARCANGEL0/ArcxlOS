// GhostWired — the ghost wire tunnel: every packet this computer sends goes through Tor or is
// rejected, except for the apps you exclude. State and commands live in the Ghost singleton;
// Excluded apps and Tor configuration are sub-pages.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "GhostWired"
    desc: "Disappear behind Tor. Every packet goes through the tunnel or doesn't leave at all."

    property int excluded: 0
    Cmd { id: cmd }
    Component.onCompleted: {
        Ghost.refresh();
        cmd.sh('grep -lx "X-GhostWired-Exempt=true" "${XDG_DATA_HOME:-$HOME/.local/share}"/applications/*.desktop 2>/dev/null | wc -l', [],
               (c, o) => page.excluded = parseInt(o) || 0);
    }
    readonly property var modes: [
        { k: "off", t: "No bridge", d: "Connect to Tor directly" },
        { k: "obfs4", t: "obfs4  (built-in)", d: "Looks like random noise; works on most censored networks", tr: "obfs4" },
        { k: "snowflake", t: "Snowflake  (built-in)", d: "Hides inside WebRTC through volunteer proxies", tr: "snowflake" },
        { k: "meek", t: "meek  (built-in)", d: "Disguised as traffic to a big CDN; slow, but hard to block", tr: "meek" },
        { k: "custom", t: "Custom bridges", d: "Your own lines from bridges.torproject.org" }
    ]
    function hasTransport(tr) { return !tr || (" " + (Ghost.st.transports || "") + " ").indexOf(" " + tr + " ") >= 0; }
    readonly property var mode: page.modes.find(m => m.k === (Ghost.st.bridges || "off")) ?? page.modes[0]

    // ── hero ────────────────────────────────────────────────────────────────────
    Rectangle {
        width: parent.width
        height: 244
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1
        border.color: Ghost.blocked ? Ax.alpha(Ax.danger, 0.45) : Ghost.running ? Ax.alpha(Ax.accent, 0.35) : Ax.border
        Behavior on border.color { ColorAnimation { duration: Ax.durSlow } }
        clip: true
        CornerTicks { len: 10; anchors.margins: 12 }

        // faint grid behind the circuit
        Canvas {
            anchors.fill: parent
            opacity: 0.5
            onPaint: {
                const g = getContext("2d"); g.reset();
                g.strokeStyle = Qt.rgba(1, 1, 1, 0.025); g.lineWidth = 1;
                for (let x = 0; x < width; x += 22) { g.beginPath(); g.moveTo(x + .5, 0); g.lineTo(x + .5, height); g.stroke(); }
                for (let y = 0; y < height; y += 22) { g.beginPath(); g.moveTo(0, y + .5); g.lineTo(width, y + .5); g.stroke(); }
            }
        }

        Column {
            x: 28; y: 26
            width: parent.width - 56 - heroSwitch.width
            spacing: 6
            Label { caption: true; text: "Ghost wire tunnel  ·  Tor"; color: Ghost.running ? Ax.accent : Ax.faint }
            Label { text: Ghost.blocked ? "Held" : Ghost.ready ? "Invisible" : Ghost.running ? "Connecting" : "Visible"
                    font.pixelSize: 28; font.weight: Font.DemiBold; font.letterSpacing: -0.4 }
            Label { width: parent.width; text: Ghost.phase; color: Ghost.blocked ? Ax.danger : Ax.subtext; font.pixelSize: Ax.fsSmall }
        }
        AxSwitch {
            id: heroSwitch
            anchors.right: parent.right; anchors.rightMargin: 28; y: 32
            scale: 1.25
            enabled_: Ghost.installed && Ghost.busy === ""
            checked: Ghost.running || Ghost.blocked
            onToggled: (on) => Ghost.act(on ? "on" : "off", [on ? "on" : "off"])
        }

        // the circuit: you → guard → middle → exit → internet
        Item {
            id: circuit
            x: 28; width: parent.width - 56
            anchors.bottom: parent.bottom; anchors.bottomMargin: 26
            height: 64
            Label { y: -24; caption: true; text: "Tor circuit" + (Ghost.running ? "  ·  " + Ghost.boot + "%" : "  ·  idle") }
            readonly property var nodes: [
                { t: "This computer", at: 0 }, { t: "Guard", at: 10 }, { t: "Middle", at: 50 },
                { t: "Exit", at: 90 }, { t: Ghost.exit && Ghost.exit.IP ? Ghost.exit.IP : "Internet", at: 100 }
            ]
            function lit(i) { return i === 0 || (Ghost.running && Ghost.boot >= nodes[i].at); }
            readonly property color tone: Ghost.blocked ? Ax.danger : Ax.accent
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    readonly property real step: circuit.width / 4
                    x: index * step + 8; width: step - 16
                    y: 11; height: 2; radius: 1
                    color: circuit.lit(index + 1) ? circuit.tone : Ax.alpha(Ax.text, 0.08)
                    Behavior on color { ColorAnimation { duration: Ax.durSlow } }
                    // a pulse runs along the segment being built
                    Rectangle {
                        visible: Ghost.running && !circuit.lit(index + 1) && circuit.lit(index)
                        width: 26; height: 2; radius: 1; color: circuit.tone
                        NumberAnimation on x { from: 0; to: parent.width - 26; duration: 900; loops: Animation.Infinite; running: parent.visible }
                    }
                }
            }
            Repeater {
                model: circuit.nodes
                Item {
                    required property var modelData
                    required property int index
                    x: index === 0 ? 0 : index === 4 ? circuit.width - width : index * circuit.width / 4 - width / 2
                    width: 120; height: parent.height
                    readonly property bool on: circuit.lit(index)
                    Rectangle {
                        x: index === 0 ? 0 : index === 4 ? parent.width - 12 : parent.width / 2 - 6
                        width: 12; height: 12; radius: 6; y: 6
                        color: parent.on ? circuit.tone : Ax.panel
                        border.width: 2; border.color: parent.on ? circuit.tone : Ax.alpha(Ax.text, 0.16)
                        Behavior on color { ColorAnimation { duration: Ax.durSlow } }
                    }
                    Label {
                        y: 28; width: parent.width
                        horizontalAlignment: index === 0 ? Text.AlignLeft : index === 4 ? Text.AlignRight : Text.AlignHCenter
                        mono: true; font.pixelSize: Ax.fsCaption + 1
                        text: modelData.t
                        color: parent.on ? Ax.text : Ax.faint
                    }
                }
            }
        }
    }

    Label {
        visible: Ghost.error !== ""
        width: parent.width; wrapMode: Text.WordWrap
        text: Ghost.error; color: Ax.danger; font.pixelSize: Ax.fsSmall
    }

    Section {
        visible: Ghost.loaded && !Ghost.installed
        EmptyState {
            icon: "shield"
            title: Ghost.st.installed !== "1" ? "Tor isn't installed" : "nftables isn't installed"
            desc: "GhostWired needs both. Install them with  sudo pacman -S tor nftables  — until then the settings below can't take effect."
        }
    }

    Section {
        visible: Ghost.ready
        title: "Your exit"
        SRow {
            icon: "public"
            title: Ghost.exit && Ghost.exit.IP ? Ghost.exit.IP : (Ghost.busy === "exit" ? "Asking the Tor Project…" : "Unknown")
            desc: Ghost.exit ? (Ghost.exit.IsTor ? "Websites see this address, not yours" : "Warning: this address is not a Tor exit") : "Where your traffic leaves the Tor network"
            Badge { visible: !!Ghost.exit; text: Ghost.exit && Ghost.exit.IsTor ? "tor" : "not tor"; tone: Ghost.exit && Ghost.exit.IsTor ? "accent" : "danger"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { icon: "refresh"; enabled_: Ghost.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: Ghost.checkExit() }
            AxButton { text: "New identity"; icon: "autorenew"; kind: "primary"; enabled_: Ghost.busy === ""
                       anchors.verticalCenter: parent.verticalCenter; onClicked: Ghost.newIdentity() }
        }
    }

    Section {
        title: "Tunnel"
        SRow {
            icon: "apps_outage"; title: "Excluded apps"
            desc: page.excluded === 0 ? "None — nothing gets past the tunnel" : page.excluded + (page.excluded === 1 ? " app connects" : " apps connect") + " directly, outside Tor"
            clickable: true; chevron: true
            onClicked: NSS.Shell.openSettings("ghostwired-exclude")
        }
        SRow {
            icon: "alt_route"; title: "Bridge"; desc: page.mode.d
            AxSelect {
                width: 230; anchors.verticalCenter: parent.verticalCenter
                model: page.modes.map(m => m.t + (page.hasTransport(m.tr) ? "" : "  — not installed"))
                current: page.modes.indexOf(page.mode)
                onPicked: (i) => Ghost.setOpt(["bridges=" + page.modes[i].k])
            }
        }
        SRow {
            visible: !page.hasTransport(page.mode.tr)
            icon: "warning"; title: "No " + page.mode.tr + " client on this computer"
            desc: page.mode.tr === "snowflake" ? "Install lyrebird or snowflake-pt-client (AUR). Until then Tor can't start with this bridge."
                                               : "Install obfs4proxy or lyrebird. Until then Tor can't start with this bridge."
            dim: true
        }
        Item {
            visible: page.mode.k === "custom"
            property bool topDivider: false
            width: parent.width
            height: bcol.implicitHeight + 32
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: bcol
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad
                spacing: 10
                Label { width: parent.width; wrapMode: Text.WordWrap; color: Ax.muted; font.pixelSize: Ax.fsSmall
                        text: "One per line, as bridges.torproject.org gives them, e.g.  obfs4 192.0.2.4:443 FINGERPRINT cert=… iat-mode=0" }
                AxTextArea {
                    id: bridgeText
                    width: parent.width; height: 116
                    placeholder: "obfs4 …\nwebtunnel …\nsnowflake …"
                    property bool dirty: false
                    function load() { text = (Ghost.st.bridge_list || "").split("\t").filter(l => l).join("\n"); }
                    Component.onCompleted: load()
                    Connections { target: Ghost; function onStChanged() { if (!bridgeText.dirty) bridgeText.load(); } }
                    onTextChanged: if (text !== (Ghost.st.bridge_list || "").split("\t").filter(l => l).join("\n")) dirty = true
                }
                Row {
                    spacing: 8
                    AxButton { text: "Save bridges"; kind: "primary"; enabled_: Ghost.busy === "" && bridgeText.dirty
                               onClicked: { bridgeText.dirty = false; Ghost.act("bridges", ["bridges"], bridgeText.text.trim() + "\n"); } }
                    AxButton { text: "Get bridges"; icon: "open_in_new"; onClicked: Qt.openUrlExternally("https://bridges.torproject.org/options") }
                }
            }
        }
        SRow {
            icon: "tune"; title: "Tor configuration"
            desc: "Ports " + (Ghost.st.socks_port || "9050") + " / " + (Ghost.st.trans_port || "9040") + " / " + (Ghost.st.dns_port || "5353")
                  + ((Ghost.st.exit_nodes || "") !== "" ? "  ·  exits in " + Ghost.st.exit_nodes.toUpperCase().replace(/,/g, ", ") : "")
            clickable: true; chevron: true
            onClicked: NSS.Shell.openSettings("ghostwired-advanced")
        }
    }

    Section {
        title: "Protection"
        SRow {
            icon: "block"; title: "Kill switch"
            desc: "If Tor stops unexpectedly, hold every packet back instead of falling back to a direct connection"
            AxSwitch { checked: Ghost.st.kill_switch === "1"; enabled_: Ghost.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Ghost.setOpt(["kill_switch=" + (on ? 1 : 0)]) }
        }
        SRow {
            icon: "power_settings_new"; title: "Start the tunnel at boot"
            desc: "Bring GhostWired up before anything else connects"
            AxSwitch { checked: Ghost.st.autostart === "1"; enabled_: Ghost.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Ghost.setOpt(["autostart=" + (on ? 1 : 0)]) }
        }
        SRow {
            icon: "fingerprint"; title: "Random hardware address"
            desc: "Give Wi-Fi and Ethernet a new MAC address for every network, so they can't recognise this machine"
            AxSwitch { checked: Ghost.macRandom; enabled_: Ghost.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Ghost.setMac(on) }
        }
    }

    Label {
        visible: Ghost.installed && (Ghost.st.warn || "") !== ""
        width: parent.width; wrapMode: Text.WordWrap
        mono: true; font.pixelSize: Ax.fsCaption + 1; color: Ax.faint
        text: "tor: " + (Ghost.st.warn || "")
    }
}
