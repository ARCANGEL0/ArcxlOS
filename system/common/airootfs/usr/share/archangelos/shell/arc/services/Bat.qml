pragma Singleton

// Battery (laptop only), via UPower's display device.
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property bool has:      UPower.displayDevice?.isLaptopBattery ?? false
    readonly property real raw:      UPower.displayDevice?.percentage ?? 0
    readonly property int  percent:  Math.round(raw <= 1 ? raw * 100 : raw)
    readonly property bool charging: (UPower.displayDevice?.state ?? 0) === UPowerDeviceState.Charging
    // Not `!charging`: a full battery on the mains is neither charging nor discharging.
    readonly property bool onBattery: root.has && UPower.onBattery
}
