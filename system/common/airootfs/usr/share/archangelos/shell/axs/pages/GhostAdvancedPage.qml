// GhostWired › Tor configuration — ports, exit countries, how circuits are split, local network
// access, and your own torrc lines (checked by Tor before they're used).
import QtQuick
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "GhostWired"
    title: "Tor configuration"
    desc: "The finer controls. The defaults are the safe ones."

    header: AxButton { icon: "arrow_back"; text: "GhostWired"; onClicked: NSS.Shell.openSettings("ghostwired") }

    Label {
        visible: Ghost.error !== ""
        width: parent.width; wrapMode: Text.WordWrap
        text: Ghost.error; color: Ax.danger; font.pixelSize: Ax.fsSmall
    }

    Section {
        title: "Circuits"
        SRow {
            icon: "call_split"; title: "Separate circuits per site"
            desc: "A different path through Tor for each destination, so sites can't be linked through one exit"
            AxSwitch { checked: Ghost.st.isolate === "1"; enabled_: Ghost.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Ghost.setOpt(["isolate=" + (on ? 1 : 0)]) }
        }
        SRow {
            icon: "lan"; title: "Reach the local network directly"
            desc: Ghost.st.lan_bypass === "1" ? "Printers, NAS and devices at home bypass Tor. This is an exception to the tunnel"
                                              : "Off: no exceptions. Even local devices are only reached through Tor (so mostly not at all)"
            AxSwitch { checked: Ghost.st.lan_bypass === "1"; enabled_: Ghost.busy === ""; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Ghost.setOpt(["lan_bypass=" + (on ? 1 : 0)]) }
        }
    }

    // ── exit location ──────────────────────────────────────────────────────────
    Section {
        title: "Exit location"
        note: (Ghost.st.exit_nodes || "") === "" ? "anywhere" : Ghost.st.exit_nodes.toUpperCase().replace(/,/g, " · ")
        Item {
            id: exitBox
            property bool topDivider: false
            property var chosen: (Ghost.st.exit_nodes || "").split(",").filter(c => c)
            readonly property var countries: [
                ["us", "United States"], ["ca", "Canada"], ["de", "Germany"], ["nl", "Netherlands"], ["fr", "France"],
                ["gb", "United Kingdom"], ["ch", "Switzerland"], ["se", "Sweden"], ["no", "Norway"], ["fi", "Finland"],
                ["is", "Iceland"], ["at", "Austria"], ["ro", "Romania"], ["cz", "Czechia"], ["pl", "Poland"],
                ["es", "Spain"], ["it", "Italy"], ["jp", "Japan"], ["sg", "Singapore"], ["au", "Australia"], ["br", "Brazil"]
            ]
            Connections { target: Ghost; function onStChanged() { exitBox.chosen = (Ghost.st.exit_nodes || "").split(",").filter(c => c); } }
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
                          AxSwitch { id: strict; checked: Ghost.st.strict_nodes === "1"; onToggled: (on) => checked = on; anchors.verticalCenter: parent.verticalCenter }
                          Label { text: "Only these countries, even if that means no connection"; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter } }
                }
                Row {
                    spacing: 8
                    AxButton { text: "Apply"; kind: "primary"; enabled_: Ghost.busy === ""
                               onClicked: Ghost.setOpt(["exit_nodes=" + exitBox.chosen.join(","), "strict_nodes=" + (strict.checked ? 1 : 0)]) }
                    AxButton { text: "Any country"; enabled_: Ghost.busy === "" && exitBox.chosen.length > 0
                               onClicked: { exitBox.chosen = []; Ghost.setOpt(["exit_nodes=", "strict_nodes=0"]); } }
                }
            }
        }
    }

    // ── ports ──────────────────────────────────────────────────────────────────
    Section {
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
                    text: Ghost.st[prow.modelData.k] || ""
                    onAccepted: if (/^\d{4,5}$/.test(text) && text !== Ghost.st[prow.modelData.k]) Ghost.setOpt([prow.modelData.k + "=" + text])
                }
                AxButton {
                    visible: pf.text !== (Ghost.st[prow.modelData.k] || "")
                    text: "Set"; kind: "primary"; anchors.verticalCenter: parent.verticalCenter
                    enabled_: /^\d{4,5}$/.test(pf.text) && Ghost.busy === ""
                    onClicked: Ghost.setOpt([prow.modelData.k + "=" + pf.text])
                }
            }
        }
    }


    Section {
        title: "Your torrc lines"
        note: "advanced"
        Item {
            property bool topDivider: false
            width: parent.width
            height: tcol.implicitHeight + 32
            Column {
                id: tcol
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad
                spacing: 10
                Label { width: parent.width; wrapMode: Text.WordWrap; color: Ax.muted; font.pixelSize: Ax.fsSmall
                        text: "Extra options added to the end of Tor's configuration, one per line. Tor checks them before they're saved. "
                            + "Lines for ports, bridges, logging and anything else GhostWired manages are left out so the tunnel can't break." }
                AxTextArea {
                    id: torrc
                    width: parent.width; height: 150
                    placeholder: "# for example\nNumEntryGuards 2\nExcludeExitNodes {ru},{cn}\nCircuitBuildTimeout 30"
                    property bool dirty: false
                    readonly property string saved: (Ghost.st.torrc_extra || "").split("\t").join("\n").replace(/\n+$/, "")
                    Component.onCompleted: text = saved
                    Connections { target: Ghost; function onStChanged() { if (!torrc.dirty) torrc.text = torrc.saved; } }
                    onTextChanged: dirty = text !== saved
                }
                Row {
                    spacing: 8
                    AxButton { text: Ghost.busy === "torrc" ? "Checking…" : "Check and save"; kind: "primary"; enabled_: Ghost.busy === "" && torrc.dirty
                               onClicked: Ghost.act("torrc", ["torrc"], torrc.text.trim() + "\n", (ok) => { if (ok) torrc.dirty = false; }) }
                    AxButton { text: "Revert"; visible: torrc.dirty; onClicked: { torrc.text = torrc.saved; torrc.dirty = false; } }
                    AxButton { text: "torrc manual"; icon: "open_in_new"; onClicked: Qt.openUrlExternally("https://2019.www.torproject.org/docs/tor-manual.html.en") }
                }
            }
        }
    }
}
