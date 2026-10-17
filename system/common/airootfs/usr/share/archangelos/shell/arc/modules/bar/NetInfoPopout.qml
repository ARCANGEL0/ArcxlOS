// ArchangelOS: network pane — the current connection and its details, plus a
// jump to the top-right Wi-Fi scanner. Grows out of the left dock.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.ns
import qs.ns.components
import qs.ns.services

BarPopout {
    id: pop
    name: "netinfo"
    implicitWidth: 268
    bodyHeight: 288
    reportOnHover: true

    readonly property var link: Net.activeWifi ?? Net.activeEthernet ?? null
    readonly property var ap: {
        for (var i = 0; i < Net.networks.length; i++) if (Net.networks[i].active) return Net.networks[i];
        return null;
    }
    readonly property bool isWifi: Net.activeWifi !== null
    readonly property string connName: isWifi ? Net.wifiSsid
                                              : (Net.activeEthernet ? (Net.activeEthernet.connection || "Ethernet") : "")

    component Row2: RowLayout {
        property string k
        property string v
        Layout.fillWidth: true
        spacing: 8
        Text { text: parent.k; color: Config.dim; font.family: Config.textFont; font.pixelSize: 10 }
        Item { Layout.fillWidth: true }
        Text { text: parent.v || "—"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 10
               elide: Text.ElideLeft; Layout.maximumWidth: 150; horizontalAlignment: Text.AlignRight }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 14 + Config.popFillet * 2 - pop.botPad + pop.topPad
        anchors.bottomMargin: 14 + pop.botPad
        spacing: 9

        Text { text: "NETWORK"; color: Config.accent; font.family: Config.textFont; font.pixelSize: 11; font.bold: true }

        // --- current connection ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MatIcon {
                text: !Net.netUp ? "signal_wifi_off"
                      : (pop.isWifi ? Net.netIcon(Net.wifiSignal) : "lan")
                font.pixelSize: 26; color: Net.netUp ? Config.accent : Config.dim
            }
            ColumnLayout {
                spacing: 0
                Text {
                    text: Net.netUp ? pop.connName : "Not connected"
                    color: Config.fg; font.family: Config.textFont; font.pixelSize: 13; font.bold: true
                    elide: Text.ElideRight; Layout.maximumWidth: 180
                }
                Text {
                    text: !Net.netUp ? "offline"
                          : (pop.isWifi ? (Net.wifiSignal + "% · " + (pop.ap && pop.ap.isSecure ? "secured" : "open"))
                                        : "wired")
                    color: Config.dim; font.family: Config.textFont; font.pixelSize: 9
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Config.outline }

        // --- details ---
        Row2 { k: "IP";        v: pop.link ? pop.link.ip4 : "" }
        Row2 { k: "Gateway";   v: pop.link ? pop.link.gateway : "" }
        Row2 { k: "BSSID";     v: pop.ap ? pop.ap.bssid : ""; visible: pop.isWifi }
        Row2 { k: "Interface"; v: pop.link ? pop.link.device : "" }
        Row2 { k: "MAC";       v: pop.link ? pop.link.mac : "" }
        Row2 { k: "Link";      v: pop.link ? pop.link.speed : "" }

        Item { Layout.fillHeight: true }

        // --- jump to the top-right Wi-Fi scanner ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: 8
            color: findMa.containsMouse ? Config.container : Config.surface
            border.width: 1; border.color: Config.outline
            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                MatIcon { text: "wifi_find"; font.pixelSize: 15; color: Config.accent }
                Text { text: "Find other networks"; color: Config.fg; font.family: Config.textFont; font.pixelSize: 11 }
            }
            MouseArea {
                id: findMa
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    pop.bar.hidePopout();
                    // opens ArcShell's top-right network panel (same as the wifi keybind)
                    Quickshell.execDetached(["qs", "-p", "/usr/share/archangelos/shell",
                                             "ipc", "call", "wifi-toggle", "toggle"]);
                }
            }
        }
    }
}
