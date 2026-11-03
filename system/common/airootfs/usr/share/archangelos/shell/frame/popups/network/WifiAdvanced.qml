/*
 * ArcShell
 * Copyright (C) 2026 arcxlo (ArchangelOS)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>
 */

import QtQuick
import Quickshell.Io
import "../../"
import "../../components"

Item {
    id: root

    property real localScale: 1.0
    property string uuid: ""
    property string ssid: ""
    property string ip4: ""

    property string mac: ""
    property string ipv4Method: "auto"
    property string ipv4Addr: ""
    property string ipv4Prefix: "24"
    property string ipv4Gw: ""
    property string ipv4Dns: ""
    property string ipv6Method: "auto"
    property string ipv6Addr: ""
    property string ipv6Prefix: "64"
    property string ipv6Gw: ""
    property string ipv6Dns: ""

    property bool _loading: false
    property bool _applying: false
    property string _status: ""

    readonly property bool _ipv4Manual: ipv4Method === "manual"
    readonly property bool _ipv6Manual: ipv6Method === "manual"

    readonly property string _ipv4Label: ipv4Method === "manual" ? "Manual" : "DHCP"
    readonly property string _ipv6Label: {
        switch (ipv6Method) {
            case "dhcp": return "DHCP"
            case "manual": return "Manual"
            case "disabled": return "Disabled"
            case "link-local": return "Link-local"
        }
        return "SLAAC"
    }

    readonly property string _ipv4Full: ipv4Addr !== ""
        ? (ipv4Prefix !== "" ? ipv4Addr + "/" + ipv4Prefix : ipv4Addr)
        : ""
    readonly property string _ipv6Full: ipv6Addr !== ""
        ? (ipv6Prefix !== "" ? ipv6Addr + "/" + ipv6Prefix : ipv6Addr)
        : ""

    readonly property var _fields: [
        { prop: "mac" },
        { prop: "ipv4Method" },
        { prop: "ipv4Addr", prefixProp: "ipv4Prefix" },
        { prop: "ipv4Gw" },
        { prop: "ipv4Dns" },
        { prop: "ipv6Method" },
        { prop: "ipv6Addr", prefixProp: "ipv6Prefix" },
        { prop: "ipv6Gw" },
        { prop: "ipv6Dns" }
    ]

    Process {
        id: readProc
        command: []
        running: false
        property int _lineIdx: 0
        stdout: SplitParser {
            onRead: function(line) {
                var field = root._fields[readProc._lineIdx++]
                if (!field) return
                var v = line.trim()
                if (field.prefixProp) {
                    var slash = v.indexOf("/")
                    if (slash >= 0) {
                        root[field.prop] = v.substring(0, slash).split(",")[0]
                        root[field.prefixProp] = v.substring(slash + 1).split(",")[0]
                    } else {
                        root[field.prop] = v.split(",")[0]
                        root[field.prefixProp] = ""
                    }
                } else {
                    root[field.prop] = v
                }
            }
        }
        onExited: {
            if (root.ipv4Prefix === "") root.ipv4Prefix = "24"
            if (root.ipv6Prefix === "") root.ipv6Prefix = "64"
            root._loading = false
        }
    }

    Process {
        id: applyProc
        command: []
        running: false
        onRunningChanged: if (!running) {
            root._applying = false
            root._status = "Applied — reconnecting…"
            Qt.callLater(function() { root._reload() })
        }
    }

    function _reload() {
        if (root.uuid === "") return
        readProc._lineIdx = 0
        readProc.command = root.buildReadCommand()
        readProc.running = false
        readProc.running = true
        root._loading = true
    }

    function buildReadCommand() {
        return [
            "bash", "-c",
            "nmcli -g 802-11-wireless.cloned-mac-address,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv6.method,ipv6.addresses,ipv6.gateway,ipv6.dns con show \"" + root.uuid + "\""
        ]
    }

    function buildApplyCommand() {
        return [
            "bash", "-c",
            "uuid=\"$1\"; mac=\"$2\"; m4=\"$3\"; a4=\"$4\"; g4=\"$5\"; d4=\"$6\"; m6=\"$7\"; a6=\"$8\"; g6=\"$9\"; d6=\"${10}\"; " +
            "nmcli con mod \"$uuid\" 802-11-wireless.cloned-mac-address \"$mac\"; " +
            "nmcli con mod \"$uuid\" ipv4.method \"$m4\"; " +
            "nmcli con mod \"$uuid\" ipv4.addresses \"$a4\"; " +
            "nmcli con mod \"$uuid\" ipv4.gateway \"$g4\"; " +
            "nmcli con mod \"$uuid\" ipv4.dns \"$d4\"; " +
            "nmcli con mod \"$uuid\" ipv6.method \"$m6\"; " +
            "nmcli con mod \"$uuid\" ipv6.addresses \"$a6\"; " +
            "nmcli con mod \"$uuid\" ipv6.gateway \"$g6\"; " +
            "nmcli con mod \"$uuid\" ipv6.dns \"$d6\"; " +
            "nmcli con down uuid \"$uuid\" >/dev/null 2>&1; " +
            "nmcli con up uuid \"$uuid\"",
            "--", root.uuid, root.mac, root.ipv4Method, root._ipv4Full, root.ipv4Gw, root.ipv4Dns,
            root.ipv6Method, root._ipv6Full, root.ipv6Gw, root.ipv6Dns
        ]
    }

    function _apply() {
        root._applying = true
        root._status = "Applying…"
        applyProc.command = root.buildApplyCommand()
        applyProc.running = false
        applyProc.running = true
    }

    onVisibleChanged: {
        if (visible) {
            root._status = ""
            root._reload()
            macBtn.expanded = false
            addr4Btn.expanded = false
            prefix4Btn.expanded = false
            gw4Btn.expanded = false
            dns4Btn.expanded = false
            addr6Btn.expanded = false
            prefix6Btn.expanded = false
            gw6Btn.expanded = false
            dns6Btn.expanded = false
        }
    }

    onUuidChanged: if (visible) root._reload()

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.height + Math.round(20 * localScale)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentCol
            width: flick.width
            spacing: Math.round(16 * localScale)

            Text {
                x: Math.round(4 * localScale)
                text: root.ssid !== "" ? "Connected to " + root.ssid : "Advanced network settings"
                color: Theme.subtext
                font.pixelSize: Math.round(11 * localScale)
            }

            SettingsGroup {
                localScale: root.localScale
                cornerRadius: Theme.cardRadius
                title: "Hardware"
                description: "Network interface identity for this connection."

                SettingsButton {
                    id: macBtn
                    localScale: root.localScale
                    text: "Cloned MAC address"
                    description: "Spoofed hardware address. Leave empty to use the real adapter."
                    inputType: "text"
                    inputText: root.mac
                    placeholder: "00:00:00:00:00:00"
                    buttonText: root.mac !== "" ? root.mac : "Default"
                    onInputAccepted: function(txt) { root.mac = txt }
                }
            }

            SettingsGroup {
                localScale: root.localScale
                cornerRadius: Theme.cardRadius
                title: "IPv4"
                description: "Address assignment, routing and name resolution."

                SettingsButton {
                    localScale: root.localScale
                    text: "Method"
                    description: "Enable DHCP for automatic assignment, or set a static address."
                    inputType: "options"
                    options: ["DHCP", "Manual"]
                    selectedOption: root._ipv4Label
                    buttonText: root._ipv4Label
                    onOptionSelected: function(opt) { root.ipv4Method = (opt === "Manual") ? "manual" : "auto" }
                }

                SettingsDivider { localScale: root.localScale }

                SettingsButton {
                    id: addr4Btn
                    localScale: root.localScale
                    enabled: root._ipv4Manual
                    opacity: root._ipv4Manual ? 1 : 0.45
                    text: "IP address"
                    description: "Static IPv4 address of this interface."
                    inputType: "text"
                    inputText: root.ipv4Addr
                    placeholder: "192.168.1.50"
                    buttonText: root.ipv4Addr !== "" ? root.ipv4Addr : "Not set"
                    onInputAccepted: function(txt) { root.ipv4Addr = txt }
                }

                SettingsDivider { localScale: root.localScale }

                SettingsButton {
                    id: prefix4Btn
                    localScale: root.localScale
                    enabled: root._ipv4Manual
                    opacity: root._ipv4Manual ? 1 : 0.45
                    text: "Subnet mask"
                    description: "Prefix length of the subnet, e.g. 24 for 255.255.255.0."
                    inputType: "text"
                    inputText: root.ipv4Prefix
                    placeholder: "24"
                    buttonText: root.ipv4Prefix !== "" ? "/" + root.ipv4Prefix : "Not set"
                    onInputAccepted: function(txt) { root.ipv4Prefix = txt }
                }

                SettingsDivider { localScale: root.localScale }

                SettingsButton {
                    id: gw4Btn
                    localScale: root.localScale
                    enabled: root._ipv4Manual
                    opacity: root._ipv4Manual ? 1 : 0.45
                    text: "Gateway"
                    description: "Default route for the static address."
                    inputType: "text"
                    inputText: root.ipv4Gw
                    placeholder: "192.168.1.1"
                    buttonText: root.ipv4Gw !== "" ? root.ipv4Gw : "Not set"
                    onInputAccepted: function(txt) { root.ipv4Gw = txt }
                }

                SettingsDivider { localScale: root.localScale }

                SettingsButton {
                    id: dns4Btn
                    localScale: root.localScale
                    text: "DNS servers"
                    description: "Comma-separated resolvers, e.g. 1.1.1.1,9.9.9.9"
                    inputType: "text"
                    inputText: root.ipv4Dns
                    placeholder: "1.1.1.1,9.9.9.9"
                    buttonText: root.ipv4Dns !== "" ? root.ipv4Dns : "Default"
                    onInputAccepted: function(txt) { root.ipv4Dns = txt }
                }
            }

            SettingsGroup {
                localScale: root.localScale
                cornerRadius: Theme.cardRadius
                title: "IPv6"
                description: "IPv6 address assignment, routing and name resolution."

                SettingsButton {
                    localScale: root.localScale
                    text: "Method"
                    description: "DHCPv6, stateless autoconfiguration (SLAAC), manual or disabled."
                    inputType: "options"
                    options: ["SLAAC", "DHCP", "Manual", "Disabled"]
                    selectedOption: root._ipv6Label
                    buttonText: root._ipv6Label
                    onOptionSelected: function(opt) {
                        switch (opt) {
                            case "DHCP": root.ipv6Method = "dhcp"; break
                            case "Manual": root.ipv6Method = "manual"; break
                            case "Disabled": root.ipv6Method = "disabled"; break
                            default: root.ipv6Method = "auto"
                        }
                    }
                }

                SettingsDivider { localScale: root.localScale }

                SettingsButton {
                    id: addr6Btn
                    localScale: root.localScale
                    enabled: root._ipv6Manual
                    opacity: root._ipv6Manual ? 1 : 0.45
                    text: "IP address"
                    description: "Static IPv6 address of this interface."
                    inputType: "text"
                    inputText: root.ipv6Addr
                    placeholder: "2001:db8::10"
                    buttonText: root.ipv6Addr !== "" ? root.ipv6Addr : "Not set"
                    onInputAccepted: function(txt) { root.ipv6Addr = txt }
                }

                SettingsDivider { localScale: root.localScale }

                SettingsButton {
                    id: prefix6Btn
                    localScale: root.localScale
                    enabled: root._ipv6Manual
                    opacity: root._ipv6Manual ? 1 : 0.45
                    text: "Subnet mask"
                    description: "Prefix length of the IPv6 subnet, e.g. 64."
                    inputType: "text"
                    inputText: root.ipv6Prefix
                    placeholder: "64"
                    buttonText: root.ipv6Prefix !== "" ? "/" + root.ipv6Prefix : "Not set"
                    onInputAccepted: function(txt) { root.ipv6Prefix = txt }
                }

                SettingsDivider { localScale: root.localScale }

                SettingsButton {
                    id: gw6Btn
                    localScale: root.localScale
                    enabled: root._ipv6Manual
                    opacity: root._ipv6Manual ? 1 : 0.45
                    text: "Gateway"
                    description: "Default route for the static IPv6 address."
                    inputType: "text"
                    inputText: root.ipv6Gw
                    placeholder: "2001:db8::1"
                    buttonText: root.ipv6Gw !== "" ? root.ipv6Gw : "Not set"
                    onInputAccepted: function(txt) { root.ipv6Gw = txt }
                }

                SettingsDivider { localScale: root.localScale }

                SettingsButton {
                    id: dns6Btn
                    localScale: root.localScale
                    text: "DNS servers"
                    description: "Comma-separated IPv6 resolvers, e.g. 2606:4700:4700::1111"
                    inputType: "text"
                    inputText: root.ipv6Dns
                    placeholder: "2606:4700:4700::1111"
                    buttonText: root.ipv6Dns !== "" ? root.ipv6Dns : "Default"
                    onInputAccepted: function(txt) { root.ipv6Dns = txt }
                }
            }

            Item {
                width: flick.width
                height: Math.round(30 * root.localScale)

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: Math.round(14 * root.localScale)
                        verticalCenter: parent.verticalCenter
                    }
                    width: Math.min(implicitWidth, Math.round(240 * root.localScale))
                    elide: Text.ElideRight
                    text: root._status !== "" ? root._status : (root._loading ? "Loading…" : "")
                    color: Theme.subtext
                    font.pixelSize: Math.round(11 * root.localScale)
                }

                Rectangle {
                    id: applyBtn
                    anchors {
                        right: parent.right
                        rightMargin: Math.round(12 * root.localScale)
                        verticalCenter: parent.verticalCenter
                    }
                    width: applyLbl.implicitWidth + Math.round(26 * root.localScale)
                    height: Math.round(30 * root.localScale)
                    radius: Math.round(6 * root.localScale)
                    color: applyH.hovered
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.24)
                        : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
                    border.width: Math.max(1, Math.round(1 * root.localScale))
                    Behavior on color { ColorAnimation { duration: Anim.fast } }

                    Text {
                        id: applyLbl
                        anchors.centerIn: parent
                        text: root._applying ? "Applying…" : "Apply"
                        color: Theme.active
                        font.pixelSize: Math.round(11 * root.localScale)
                        font.weight: Font.Medium
                    }

                    HoverHandler { id: applyH; cursorShape: root._applying ? Qt.ForbiddenCursor : Qt.PointingHandCursor; enabled: !root._applying }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root._applying
                        onClicked: root._apply()
                    }
                }
            }
        }
    }
}
