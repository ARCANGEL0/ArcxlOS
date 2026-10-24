// Wi-Fi & Network — wireless on/off, nearby networks (connect, password, forget) and wired links.
// Everything goes through the shell's NetworkManager service, so the bar updates in step.
import QtQuick
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Connectivity"
    title: "Wi-Fi & Network"
    desc: "Wireless and wired connections. Changes apply immediately."

    readonly property bool nmUp: NSS.Net.links.length > 0 || NSS.Net.networks.length > 0
    readonly property bool hasWifi: NSS.Net.wifiLinks.length > 0
    property string expanded: ""          // SSID whose password field is open
    property string error: ""

    Component.onCompleted: { NSS.Net.scan(); NSS.Net.loadSavedConnections(null); }

    header: AxButton {
        icon: "refresh"; text: "Scan"
        visible: page.nmUp && page.hasWifi
        enabled_: NSS.Net.wifiOn
        onClicked: NSS.Net.rescanWifi()
    }

    Section {
        visible: !page.nmUp
        EmptyState {
            icon: "wifi_off"
            title: "Network service isn't running"
            desc: "ArchangelOS manages connections with NetworkManager. Start it with  sudo systemctl enable --now NetworkManager"
        }
    }

    Section {
        visible: page.nmUp
        title: "Wi-Fi"
        SRow {
            icon: NSS.Net.wifiOn ? "wifi" : "wifi_off"
            title: "Wi-Fi"
            desc: !page.hasWifi ? "No wireless adapter found"
                : !NSS.Net.wifiOn ? "Off"
                : NSS.Net.wifiSsid !== "" ? "Connected to " + NSS.Net.wifiSsid
                : NSS.Net.connectingSsid() !== "" ? "Connecting to " + NSS.Net.connectingSsid() + "…"
                : "On — not connected"
            AxSwitch { checked: page.hasWifi && NSS.Net.wifiOn; enabled_: page.hasWifi; onToggled: (on) => NSS.Net.enableWifi(on, null); anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Section {
        visible: page.nmUp && page.hasWifi && NSS.Net.wifiOn
        title: "Networks"
        note: NSS.Net.networks.length ? NSS.Net.networks.length + " nearby" : ""

        EmptyState {
            visible: NSS.Net.networks.length === 0
            icon: "wifi_find"
            title: "Looking for networks…"
        }
        Repeater {
            model: NSS.Net.networks.slice().sort((a, b) => (b.active - a.active) || (b.strength - a.strength))
            delegate: Column {
                id: net
                required property var modelData
                property bool topDivider: false
                readonly property bool saved: NSS.Net.hasSavedProfile(modelData.ssid)
                readonly property bool busy: NSS.Net.connectingSsid() === modelData.ssid
                readonly property bool open_: page.expanded === modelData.ssid
                width: parent.width

                SRow {
                    topDivider: net.topDivider
                    icon: NSS.Net.netIcon(net.modelData.strength)
                    title: net.modelData.ssid
                    desc: (net.modelData.isSecure ? "Secured" : "Open") + (net.saved ? "  ·  Saved" : "") + "  ·  " + net.modelData.strength + "%"
                    Badge { visible: net.modelData.active; text: "connected"; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
                    Badge { visible: net.busy; text: "connecting"; anchors.verticalCenter: parent.verticalCenter }
                    AxButton {
                        visible: net.saved && !net.modelData.active
                        icon: "delete"; kind: "ghost"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: NSS.Net.forgetNetwork(net.modelData.ssid, null)
                    }
                    AxButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: net.modelData.active ? "Disconnect" : "Connect"
                        kind: net.modelData.active ? "ghost" : "primary"
                        enabled_: !net.busy
                        onClicked: {
                            page.error = "";
                            if (net.modelData.active) NSS.Net.disconnectWifi(net.modelData.ssid);
                            else if (net.modelData.isSecure && !net.saved) page.expanded = net.open_ ? "" : net.modelData.ssid;
                            else NSS.Net.connectWifi(net.modelData.ssid);
                        }
                    }
                }
                // password drawer
                Item {
                    visible: net.open_
                    width: parent.width; height: 62
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: Ax.pad + 46
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        AxField {
                            id: pw
                            width: 280; password: true; icon: "key"
                            placeholder: "Password for " + net.modelData.ssid
                            Component.onCompleted: focusIn()
                            onAccepted: joinBtn.clicked()
                        }
                        AxButton {
                            id: joinBtn
                            text: "Join"; kind: "primary"
                            enabled_: pw.text.length >= 8
                            onClicked: {
                                NSS.Net.connectToNetwork(net.modelData.ssid, pw.text, net.modelData.bssid, (ok, msg) => {
                                    if (!ok) page.error = msg || "Couldn't connect — check the password.";
                                });
                                page.expanded = "";
                            }
                        }
                        AxButton { text: "Cancel"; onClicked: page.expanded = "" }
                    }
                }
            }
        }
        Label {
            visible: page.error !== ""
            x: Ax.pad; width: parent.width - 2 * Ax.pad; bottomPadding: 14
            text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall; wrapMode: Text.WordWrap
        }
    }

    Section {
        visible: page.nmUp && NSS.Net.ethernetLinks.length > 0
        title: "Wired"
        Repeater {
            model: NSS.Net.ethernetLinks
            delegate: SRow {
                required property var modelData
                icon: NSS.Net.linkIcon(modelData)
                title: modelData.connection || modelData.device
                desc: (modelData.connection && modelData.connection !== modelData.device ? modelData.device + "  ·  " : "") + NSS.Net.linkState(modelData) + (NSS.Net.defaultDevice === modelData.device ? "  ·  Default route" : "")
                AxButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.stateCode !== 20
                    text: modelData.stateCode >= 100 ? "Disconnect" : "Connect"
                    kind: modelData.stateCode >= 100 ? "ghost" : "primary"
                    onClicked: modelData.stateCode >= 100 ? NSS.Net.disconnectDevice(modelData.device) : NSS.Net.connectDevice(modelData.device)
                }
            }
        }
    }

    Section {
        visible: page.nmUp
        title: "Details"
        SRow {
            icon: "router"; title: "Gateway"
            Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: NSS.Net.defaultGateway || "—"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "lan"; title: "Default interface"
            Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; text: NSS.Net.defaultDevice || "—"; anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            icon: "vpn_lock"; title: "VPN"; desc: NSS.Net.vpnActive ? "Active on " + (NSS.Net.vpnDevice || "—") : "Not connected"
            clickable: true; chevron: true; onClicked: NSS.Shell.openSettings("vpn")
            Badge { visible: NSS.Net.vpnActive; text: NSS.Net.vpnActiveName; tone: "accent"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
