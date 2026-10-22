// Lock Screen — when the screen locks by itself, locking before sleep, and locking now.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Lock Screen"
    desc: "Keep your session private when you step away."

    // Your login and lock screen: the SDDM theme itself, live.
    Rectangle {
        width: parent.width; height: Math.round(width * 9 / 16)
        radius: Ax.radius + 2
        color: "#0e0e0d"
        border.width: 1; border.color: Ax.border
        clip: true
        SddmPreview { anchors.fill: parent; anchors.margins: 1 }
        AxButton { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 16
                   icon: "lock"; text: "Lock now"; kind: "primary"; onClicked: Idle.lockNow() }
    }

    Section {
        title: "Automatic lock"
        SRow {
            icon: "lock_clock"; title: "Lock when idle"; desc: "Lock the screen after you've been away for a while"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: Store.data.autoLock; onToggled: (on) => Idle.set("autoLock", on) }
        }
        SRow {
            visible: Store.data.autoLock
            icon: "timer"; title: "Lock after"
            AxSelect { width: 200; anchors.verticalCenter: parent.verticalCenter
                       readonly property var opts: Idle.ladder.filter(s => s > 0)
                       model: opts.map(s => Idle.label(s)); current: Idle.nearest(opts, Store.data.lockAfter)
                       onPicked: (i) => Idle.pick("lockAfter", opts[i]) }
        }
        SRow {
            icon: "bedtime"; title: "Lock before sleep"; desc: "So waking the computer always asks for your password"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: Store.data.lockOnSleep; onToggled: (on) => Idle.set("lockOnSleep", on) }
        }
    }

    Section {
        title: "Shortcut"
        SRow {
            icon: "keyboard"; title: "Lock from the keyboard"; desc: "Works from anywhere on the desktop"
            Row { spacing: 6; anchors.verticalCenter: parent.verticalCenter
                  Repeater { model: ["Super", "L"]
                             Rectangle { required property string modelData; width: kl.implicitWidth + 16; height: 24; radius: 6; color: Ax.raised
                                         border.width: 1; border.color: Ax.border
                                         Label { id: kl; anchors.centerIn: parent; mono: true; font.pixelSize: Ax.fsSmall; text: parent.modelData } } } }
        }
    }
}
