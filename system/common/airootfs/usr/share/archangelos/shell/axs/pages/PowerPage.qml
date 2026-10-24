// Power & Battery — battery state and health, power profile, when the screen dims, turns off and
// the machine sleeps, and the session buttons.
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Devices"
    title: "Power & Battery"
    desc: "Battery, performance and when the screen and computer go to sleep."

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev && dev.isLaptopBattery
    readonly property int pct: Math.round(dev ? dev.percentage * (dev.percentage <= 1 ? 100 : 1) : 0)
    readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging
    readonly property bool full: dev && dev.state === UPowerDeviceState.FullyCharged
    readonly property var batteries: (UPower.devices && UPower.devices.values ? UPower.devices.values : []).filter(d => d.isLaptopBattery)
    readonly property var peripherals: (UPower.devices && UPower.devices.values ? UPower.devices.values : []).filter(d => !d.isLaptopBattery && d.isPresent && d.type !== UPowerDeviceType.LinePower && d.percentage > 0)
    function dur(s) {
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }

    // ── battery card ───────────────────────────────────────────────────────────
    Rectangle {
        visible: page.hasBattery
        width: parent.width; height: 150
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        CornerTicks { len: 10; anchors.margins: 12 }
        Column {
            x: 28; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Label { caption: true; text: page.charging ? "Charging" : page.full ? "Full" : UPower.onBattery ? "On battery" : "Plugged in" }
            Row {
                spacing: 6
                Label { id: big; mono: true; font.pixelSize: 54; text: page.pct }
                Label { mono: true; font.pixelSize: 20; color: Ax.subtext; anchors.baseline: big.baseline; text: "%" }
            }
            Label { color: Ax.subtext; font.pixelSize: Ax.fsSmall
                    text: page.charging && page.dev.timeToFull > 0 ? page.dur(page.dev.timeToFull) + " until full"
                        : !page.charging && page.dev && page.dev.timeToEmpty > 0 ? page.dur(page.dev.timeToEmpty) + " left"
                        : page.full ? "Ready to go" : "" }
        }
        // a cell gauge, ten notches
        Row {
            anchors.right: parent.right; anchors.rightMargin: 32; anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Repeater {
                model: 10
                Rectangle {
                    required property int index
                    width: 12; height: 54; radius: 3
                    readonly property bool lit: index < Math.ceil(page.pct / 10)
                    color: lit ? (page.pct <= 15 && !page.charging ? Ax.danger : Ax.accent) : Ax.alpha(Ax.text, 0.06)
                    opacity: lit ? 0.35 + 0.65 * (index + 1) / 10 : 1
                    Behavior on color { ColorAnimation { duration: Ax.durSlow } }
                }
            }
        }
    }

    Section {
        visible: page.batteries.length > 0
        title: "Battery health"
        Repeater {
            model: page.batteries
            SRow {
                required property var modelData
                icon: "battery_profile"
                title: modelData.model || modelData.nativePath || "Battery"
                desc: (modelData.energyCapacity > 0 ? "Holds " + Math.round(modelData.energyCapacity) + " Wh" : "")
                      + (modelData.changeRate > 0 ? "  ·  drawing " + modelData.changeRate.toFixed(1) + " W" : "")
                Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.healthSupported ? Math.round(modelData.healthPercentage) + "% of new" : "" }
            }
        }
    }

    // power-profiles-daemon where it can, the CPU governor where it can't (see power-mode)
    property var pm: ({ mode: "balanced", ppd: "0", native_perf: "0" })
    property string pmBusy: ""
    Cmd { id: pmCmd }
    function readMode() {
        pmCmd.run(["/usr/lib/archangelos/power-mode", "get"], (c, o) => {
            const m = {}; for (const l of o.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1); }
            if (m.mode) page.pm = m;
        });
    }
    Component.onCompleted: readMode()
    readonly property var modes: ["saver", "balanced", "performance"]
    Section {
        title: "Performance"
        SRow {
            icon: page.pm.mode === "performance" ? "rocket_launch" : page.pm.mode === "saver" ? "eco" : "bolt"
            title: "Power mode"
            desc: page.pmBusy !== "" ? "Switching…"
                : page.pm.mode === "performance" ? "Maximum speed: the CPU runs flat out, using more power and running warmer"
                : page.pm.mode === "saver" ? "Slower and quieter, stretches the battery"
                : "A balance of speed and battery"
            AxSegment {
                anchors.verticalCenter: parent.verticalCenter
                options: ["Saver", "Balanced", "Performance"]
                current: page.modes.indexOf(page.pm.mode)
                onPicked: (i) => {
                    page.pmBusy = page.modes[i];
                    page.pm = Object.assign({}, page.pm, { mode: page.modes[i] });
                    pmCmd.run(["/usr/lib/archangelos/power-mode", "set", page.modes[i]], () => { page.pmBusy = ""; page.readMode(); });
                }
            }
        }
        SRow {
            visible: page.pm.mode === "performance" && page.pm.native_perf !== "1"
            icon: "info"; dim: true
            title: "Performance through the CPU governor"
            desc: "This machine's firmware has no performance profile of its own, so ArchangelOS sets the processor to full speed directly."
        }
    }

    Section {
        title: "Screen & sleep"
        note: "while idle"
        Repeater {
            model: [
                { k: "dimAfter", i: "brightness_low", t: "Dim the screen after" },
                { k: "screenOffAfter", i: "desktop_access_disabled", t: "Turn the screen off after" },
                { k: "suspendAfter", i: "bedtime", t: "Sleep after" }
            ]
            SRow {
                required property var modelData
                icon: modelData.i; title: modelData.t
                AxSelect {
                    width: 200; anchors.verticalCenter: parent.verticalCenter
                    model: Idle.ladder.map(s => Idle.label(s))
                    current: Idle.nearest(Idle.ladder, Store.data[modelData.k])
                    onPicked: (i) => Idle.pick(modelData.k, Idle.ladder[i])
                }
            }
        }
        SRow {
            icon: "lock_clock"; title: "Locking"; desc: "Auto-lock and lock-on-sleep live in Lock Screen"
            clickable: true; chevron: true
            onClicked: NSS.Shell.openSettings("lock")
        }
    }
    Section {
        visible: page.peripherals.length > 0
        title: "Other devices"
        Repeater {
            model: page.peripherals
            SRow {
                required property var modelData
                icon: "battery_horiz_075"
                title: modelData.model || "Device"
                Label { mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(modelData.percentage * (modelData.percentage <= 1 ? 100 : 1)) + "%" }
            }
        }
    }

    Section {
        title: "Session"
        Item {
            property bool topDivider: false
            width: parent.width; height: 74
            Row {
                anchors.centerIn: parent
                spacing: 10
                AxButton { icon: "lock"; text: "Lock"; onClicked: Idle.lockNow() }
                AxButton { icon: "bedtime"; text: "Sleep"; onClicked: Quickshell.execDetached(["systemctl", "suspend"]) }
                AxButton { icon: "logout"; text: "Log out"; onClicked: NSS.HyprCtl.exit() }
                ConfirmButton { icon: "restart_alt"; label: "Restart"; confirmText: "Restart now"; onConfirmed: Quickshell.execDetached(["systemctl", "reboot"]) }
                ConfirmButton { icon: "power_settings_new"; label: "Shut down"; confirmText: "Shut down now"; onConfirmed: Quickshell.execDetached(["systemctl", "poweroff"]) }
            }
        }
    }
}
