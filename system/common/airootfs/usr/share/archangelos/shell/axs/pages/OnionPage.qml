// OnionLayer — send every connection this machine makes through Tor, with a kill switch,
// bridges, exit locations and ports. The work is done by /usr/lib/archangelos/onionlayer
// (its own Tor plus an nftables redirect); this page reads its status and drives it.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "OnionLayer"
    desc: "Route all of this computer's traffic through Tor. Nothing goes out any other way."

    readonly property string tool: "/usr/lib/archangelos/onionlayer"
    property var st: ({})
    property bool loaded: false
    property string busy: ""          // which action is in flight
    property string error: ""
    property var exit: null           // { IP, IsTor }
    property bool macRandom: false

    readonly property bool installed: st.installed === "1" && st.nft === "1"
    readonly property bool running: st.active === "active" || st.active === "activating" || st.active === "reloading"
    readonly property int boot: parseInt(st.bootstrap || "0")
    readonly property bool ready: st.active === "active" && boot >= 100
    readonly property bool blocked: st.blocked === "1" && !running
    readonly property string phase: !page.loaded ? "Checking…"
        : page.blocked ? "Tor stopped — traffic is held back until you turn OnionLayer off"
        : !page.running ? (st.armed === "1" ? "Lifting the rules…" : "Off — connections go out directly")
        : page.ready ? "On — everything goes through Tor"
        : "Connecting " + page.boot + "%" + (st.phase ? " · " + st.phase : "")

    Cmd { id: cmd }
    Cmd { id: poller }
    function parse(text) {
        const o = {};
        for (const line of text.split("\n")) { const i = line.indexOf("="); if (i > 0) o[line.slice(0, i)] = line.slice(i + 1); }
        return o;
    }
    function refresh() {
        if (poller.busy) return;
        poller.run([page.tool, "status"], (code, out) => { page.st = page.parse(out); page.loaded = true; });
        poller.sh('[ -f /etc/NetworkManager/conf.d/90-archangelos-mac.conf ] && echo 1 || echo 0', [], (c, o) => page.macRandom = o.trim() === "1");
    }
    Timer { interval: page.running && !page.ready ? 1200 : 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: page.refresh() }
    onReadyChanged: { page.exit = null; if (ready) page.checkExit(); }

    function act(name, args, input) {
        page.busy = name; page.error = "";
        cmd.run([page.tool].concat(args), (code, out, err) => {
            page.busy = "";
            if (code !== 0) page.error = (err || out).trim().replace(/^onionlayer: /, "") || "That didn't work.";
            page.refresh();
        }, input);
    }
    function setOpt(kv) { page.act("set", ["set"].concat(kv)); }
    function checkExit() {
        page.busy = "exit";
        cmd.run([page.tool, "exitip"], (code, out) => {
            page.busy = "";
            try { page.exit = JSON.parse(out); } catch (e) { page.exit = null; }
        });
    }

    // ── hero ────────────────────────────────────────────────────────────────────
    Rectangle {
        width: parent.width
        height: 214
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1
        border.color: page.blocked ? Ax.alpha(Ax.danger, 0.45) : page.running ? Ax.alpha(Ax.accent, 0.35) : Ax.border
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
            Label { caption: true; text: "Tor  ·  machine-wide"; color: page.running ? Ax.accent : Ax.faint }
            Label { text: page.blocked ? "Held" : page.ready ? "Protected" : page.running ? "Connecting" : "Off"
                    font.pixelSize: 28; font.weight: Font.DemiBold; font.letterSpacing: -0.4 }
            Label { width: parent.width; text: page.phase; color: page.blocked ? Ax.danger : Ax.subtext; font.pixelSize: Ax.fsSmall }
        }
        AxSwitch {
            id: heroSwitch
            anchors.right: parent.right; anchors.rightMargin: 28; y: 32
            scale: 1.25
            enabled_: page.installed && page.busy === ""
            checked: page.running || page.blocked
            onToggled: (on) => page.act(on ? "on" : "off", [on ? "on" : "off"])
        }

        // the circuit: you → guard → middle → exit → internet
        Item {
            id: circuit
            x: 28; width: parent.width - 56
            anchors.bottom: parent.bottom; anchors.bottomMargin: 26
            height: 64
            readonly property var nodes: [
                { t: "This computer", at: 0 }, { t: "Guard", at: 10 }, { t: "Middle", at: 50 },
                { t: "Exit", at: 90 }, { t: page.exit && page.exit.IP ? page.exit.IP : "Internet", at: 100 }
            ]
            function lit(i) { return i === 0 || (page.running && page.boot >= nodes[i].at); }
            readonly property color tone: page.blocked ? Ax.danger : Ax.accent
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
                        visible: page.running && !circuit.lit(index + 1) && circuit.lit(index)
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
        visible: page.error !== ""
        width: parent.width; wrapMode: Text.WordWrap
        text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall
    }

    Section {
        visible: page.loaded && !page.installed
        EmptyState {
            icon: "shield"
            title: st.installed !== "1" ? "Tor isn't installed" : "nftables isn't installed"
            desc: "OnionLayer needs both. Install them with  sudo pacman -S tor nftables  and come back."
        }
    }

    Section {
        visible: page.ready
        title: "Your exit"
        SRow {
            icon: "public"
            title: page.exit && page.exit.IP ? page.exit.IP : (page.busy === "exit" ? "Asking the Tor Project…" : "Unknown")
            desc: page.exit ? (page.exit.IsTor ? "Websites see this address, not yours" : "Warning: this address is not a Tor exit") : "Where your traffic leaves the Tor network"
            Badge { visible: !!page.exit; text: page.exit && page.exit.IsTor ? "tor" : "not tor"; tone: page.exit && page.exit.IsTor ? "accent" : "danger"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { icon: "refresh"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter; onClicked: page.checkExit() }
            AxButton {
                text: "New identity"; icon: "autorenew"; kind: "primary"
                enabled_: page.busy === ""
                anchors.verticalCenter: parent.verticalCenter
                onClicked: { page.busy = "newnym"; cmd.run([page.tool, "newnym"], (c, o, e) => {
                    page.busy = ""; if (c !== 0) page.error = (e || o).trim().replace(/^onionlayer: /, "");
                    else { page.exit = null; exitLater.restart(); } }); }
            }
        }
    }
    Timer { id: exitLater; interval: 2500; onTriggered: page.checkExit() }

    Section {
        visible: page.installed
        title: "Protection"
        SRow {
            icon: "block"; title: "Kill switch"
            desc: "If Tor stops unexpectedly, hold all traffic back instead of falling back to a direct connection"
            AxSwitch { checked: st.kill_switch === "1"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.setOpt(["kill_switch=" + (on ? 1 : 0)]) }
        }
        SRow {
            icon: "lan"; title: "Reach the local network"
            desc: "Let printers, NAS and other devices at home be reached directly. Off sends everything through Tor"
            AxSwitch { checked: st.lan_bypass === "1"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.setOpt(["lan_bypass=" + (on ? 1 : 0)]) }
        }
        SRow {
            icon: "call_split"; title: "Separate circuits per site"
            desc: "Use a different Tor circuit for each destination, so sites can't be linked through one exit"
            AxSwitch { checked: st.isolate === "1"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.setOpt(["isolate=" + (on ? 1 : 0)]) }
        }
        SRow {
            icon: "power_settings_new"; title: "Turn on at startup"
            desc: "Bring OnionLayer up before anything else connects"
            AxSwitch { checked: st.autostart === "1"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.setOpt(["autostart=" + (on ? 1 : 0)]) }
        }
        SRow {
            icon: "fingerprint"; title: "Random hardware address"
            desc: "Give Wi-Fi and Ethernet a new MAC address for every network, so they can't recognise this machine"
            AxSwitch { checked: page.macRandom; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => { page.busy = "mac"; cmd.run(["/usr/lib/archangelos/axs-admin", "mac-random", on ? "1" : "0"], (c, o, e) => {
                           page.busy = ""; if (c !== 0) page.error = (e || o).trim(); page.refresh(); }); } }
        }
    }

    // ── bridges ────────────────────────────────────────────────────────────────
    Section {
        visible: page.installed
        title: "Bridges"
        note: st.bridge_count && st.bridge_count !== "0" ? st.bridge_count + " saved" : ""
        SRow {
            icon: "alt_route"; title: "Connect through bridges"
            desc: "Unlisted entry relays for networks that block or watch Tor"
            AxSwitch { checked: st.bridges === "1"; enabled_: page.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => page.setOpt(["bridges=" + (on ? 1 : 0)]) }
        }
        SRow {
            icon: "extension"; title: "Transports on this machine"
            desc: "obfs4 and webtunnel come from lyrebird or obfs4proxy; snowflake from snowflake-client"
            Repeater {
                model: ["obfs4", "webtunnel", "snowflake"]
                Badge { required property string modelData; text: modelData
                        tone: (" " + (st.transports || "") + " ").indexOf(" " + modelData + " ") >= 0 ? "accent" : "neutral"
                        opacity: tone === "accent" ? 1 : 0.5; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Item {
            property bool topDivider: false
            width: parent.width
            height: bcol.implicitHeight + 32
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: bcol
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad
                spacing: 10
                Label { text: "Bridge lines"; font.weight: Font.Medium }
                Label { width: parent.width; wrapMode: Text.WordWrap; color: Ax.muted; font.pixelSize: Ax.fsSmall
                        text: "One per line, as bridges.torproject.org gives them, e.g.  obfs4 192.0.2.4:443 FINGERPRINT cert=… iat-mode=0" }
                AxTextArea {
                    id: bridgeText
                    width: parent.width; height: 116
                    placeholder: "obfs4 …\nwebtunnel …\nsnowflake …"
                    Component.onCompleted: text = (st.bridge_list || "").split("\t").filter(l => l).join("\n")
                    Connections { target: page; function onStChanged() { if (!bridgeText.activeFocus && !bridgeText.dirty) bridgeText.text = (st.bridge_list || "").split("\t").filter(l => l).join("\n"); } }
                    property bool dirty: false
                    onTextChanged: if (activeFocus) dirty = true
                }
                Row {
                    spacing: 8
                    AxButton { text: "Save bridges"; kind: "primary"; enabled_: page.busy === "" && bridgeText.dirty
                               onClicked: { bridgeText.dirty = false; page.act("bridges", ["bridges"], bridgeText.text.trim() + "\n"); } }
                    AxButton { text: "Get bridges"; icon: "open_in_new"; onClicked: Qt.openUrlExternally("https://bridges.torproject.org/options") }
                }
            }
        }
    }

    // ── exit location ──────────────────────────────────────────────────────────
    Section {
        visible: page.installed
        title: "Exit location"
        note: (st.exit_nodes || "") === "" ? "anywhere" : st.exit_nodes.toUpperCase().replace(/,/g, " · ")
        Item {
            id: exitBox
            property bool topDivider: false
            property var chosen: (st.exit_nodes || "").split(",").filter(c => c)
            readonly property var countries: [
                ["us", "United States"], ["ca", "Canada"], ["de", "Germany"], ["nl", "Netherlands"], ["fr", "France"],
                ["gb", "United Kingdom"], ["ch", "Switzerland"], ["se", "Sweden"], ["no", "Norway"], ["fi", "Finland"],
                ["is", "Iceland"], ["at", "Austria"], ["ro", "Romania"], ["cz", "Czechia"], ["pl", "Poland"],
                ["es", "Spain"], ["it", "Italy"], ["jp", "Japan"], ["sg", "Singapore"], ["au", "Australia"], ["br", "Brazil"]
            ]
            Connections { target: page; function onStChanged() { exitBox.chosen = (st.exit_nodes || "").split(",").filter(c => c); } }
            width: parent.width
            height: ecol.implicitHeight + 32
            Column {
                id: ecol
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad
                spacing: 12
                Label { width: parent.width; wrapMode: Text.WordWrap; color: Ax.muted; font.pixelSize: Ax.fsSmall
                        text: "Leave all off to let Tor choose. Fewer countries means fewer exits to pick from, which is easier to spot." }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: exitBox.countries
                        ChipToggle {
                            required property var modelData
                            text: modelData[1]; icon: "flag"
                            checked: exitBox.chosen.indexOf(modelData[0]) >= 0
                            onToggled: (on) => exitBox.chosen = on ? exitBox.chosen.concat([modelData[0]]) : exitBox.chosen.filter(c => c !== modelData[0])
                        }
                    }
                }
                Row {
                    spacing: 14
                    Row { spacing: 10; anchors.verticalCenter: parent.verticalCenter
                          AxSwitch { id: strict; checked: st.strict_nodes === "1"; onToggled: (on) => checked = on; anchors.verticalCenter: parent.verticalCenter }
                          Label { text: "Only these countries, even if that means no connection"; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter } }
                }
                Row {
                    spacing: 8
                    AxButton { text: "Apply"; kind: "primary"; enabled_: page.busy === ""
                               onClicked: page.setOpt(["exit_nodes=" + exitBox.chosen.join(","), "strict_nodes=" + (strict.checked ? 1 : 0)]) }
                    AxButton { text: "Any country"; enabled_: page.busy === "" && exitBox.chosen.length > 0
                               onClicked: { exitBox.chosen = []; page.setOpt(["exit_nodes=", "strict_nodes=0"]); } }
                }
            }
        }
    }

    // ── ports ──────────────────────────────────────────────────────────────────
    Section {
        visible: page.installed
        title: "Ports"
        note: "127.0.0.1"
        Repeater {
            model: [
                { k: "socks_port", t: "SOCKS proxy", d: "For apps that take a proxy setting (Tor Browser, torsocks, proxychains)", i: "settings_ethernet" },
                { k: "trans_port", t: "Transparent port", d: "Where redirected connections enter Tor", i: "swap_horiz" },
                { k: "dns_port", t: "DNS port", d: "Where every DNS lookup is answered from", i: "dns" },
                { k: "control_port", t: "Control port", d: "Used for New identity; cookie-authenticated", i: "tune" }
            ]
            SRow {
                id: prow
                required property var modelData
                icon: modelData.i; title: modelData.t; desc: modelData.d
                AxField {
                    id: pf
                    width: 96; anchors.verticalCenter: parent.verticalCenter
                    text: st[prow.modelData.k] || ""
                    onAccepted: if (/^\d{4,5}$/.test(text) && text !== st[prow.modelData.k]) page.setOpt([prow.modelData.k + "=" + text])
                }
                AxButton {
                    visible: pf.text !== (st[prow.modelData.k] || "")
                    text: "Set"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                    enabled_: /^\d{4,5}$/.test(pf.text) && page.busy === ""
                    onClicked: page.setOpt([prow.modelData.k + "=" + pf.text])
                }
            }
        }
    }

    Label {
        visible: page.installed && (st.warn || "") !== ""
        width: parent.width; wrapMode: Text.WordWrap
        mono: true; font.pixelSize: Ax.fsCaption + 1; color: Ax.faint
        text: "tor: " + (st.warn || "")
    }
}
