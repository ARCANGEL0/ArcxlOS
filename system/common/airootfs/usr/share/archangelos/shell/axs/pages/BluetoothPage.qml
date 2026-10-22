// Bluetooth — adapter power and visibility, your devices, and nearby ones to pair.
import QtQuick
import Quickshell.Bluetooth
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Connectivity"
    title: "Bluetooth"
    desc: "Pair headphones, controllers and other devices."

    readonly property var adapter: NSS.Bt.adapter
    readonly property var mine: NSS.Bt.devices.filter(d => d.paired || d.connected)
    readonly property var nearby: NSS.Bt.devices.filter(d => !d.paired && !d.connected && (d.name || d.deviceName))

    function label(d) { return d.name || d.deviceName || d.address; }
    function glyph(d) { return NSS.Bt.icon(d.icon) || "bluetooth"; }

    header: AxButton {
        visible: page.adapter !== null && NSS.Bt.enabled
        icon: NSS.Bt.discovering ? "stop_circle" : "radar"
        text: NSS.Bt.discovering ? "Stop scanning" : "Scan"
        onClicked: NSS.Bt.toggleScan()
    }

    Section {
        visible: page.adapter === null
        EmptyState {
            icon: "bluetooth_disabled"
            title: "No Bluetooth adapter"
            desc: "No adapter was found, or the bluetooth service isn't running (sudo systemctl enable --now bluetooth)."
        }
    }

    Section {
        visible: page.adapter !== null
        title: "Adapter"
        SRow {
            icon: NSS.Bt.enabled ? "bluetooth" : "bluetooth_disabled"
            title: "Bluetooth"
            desc: NSS.Bt.enabled ? (NSS.Bt.connected ? "On — device connected" : "On") : "Off"
            AxSwitch { checked: NSS.Bt.enabled; onToggled: NSS.Bt.toggle(); anchors.verticalCenter: parent.verticalCenter }
        }
        SRow {
            visible: NSS.Bt.enabled
            icon: "visibility"
            title: "Visible to nearby devices"
            desc: page.adapter ? "Shown as “" + (page.adapter.name || "ArchangelOS") + "”" : ""
            AxSwitch { checked: page.adapter ? page.adapter.discoverable : false
                       onToggled: (on) => { if (page.adapter) page.adapter.discoverable = on; }
                       anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Section {
        visible: page.adapter !== null && NSS.Bt.enabled
        title: "My devices"
        EmptyState { visible: page.mine.length === 0; icon: "devices_other"; title: "No paired devices"; desc: "Scan, then pair a device from the list below." }
        Repeater {
            model: page.mine
            delegate: SRow {
                required property var modelData
                icon: page.glyph(modelData)
                title: page.label(modelData)
                desc: (modelData.connected ? "Connected" : "Not connected") +
                      (modelData.batteryAvailable ? "  ·  battery " + Math.round(modelData.battery * 100) + "%" : "") +
                      (modelData.trusted ? "  ·  Trusted" : "")
                AxButton { icon: "delete"; anchors.verticalCenter: parent.verticalCenter; onClicked: modelData.forget() }
                AxButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.connected ? "Disconnect" : "Connect"
                    kind: modelData.connected ? "ghost" : "primary"
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
            }
        }
    }

    Section {
        visible: page.adapter !== null && NSS.Bt.enabled
        title: "Nearby"
        note: NSS.Bt.discovering ? "scanning…" : ""
        EmptyState {
            visible: page.nearby.length === 0
            icon: NSS.Bt.discovering ? "radar" : "bluetooth_searching"
            title: NSS.Bt.discovering ? "Searching…" : "Not scanning"
            desc: NSS.Bt.discovering ? "Put your device in pairing mode." : "Press Scan to look for devices."
        }
        Repeater {
            model: page.nearby
            delegate: SRow {
                required property var modelData
                icon: page.glyph(modelData)
                title: page.label(modelData)
                desc: modelData.pairing ? "Pairing…" : modelData.address
                AxButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.pairing ? "Cancel" : "Pair"
                    kind: modelData.pairing ? "ghost" : "primary"
                    onClicked: modelData.pairing ? modelData.cancelPair() : modelData.pair()
                }
            }
        }
    }
}
