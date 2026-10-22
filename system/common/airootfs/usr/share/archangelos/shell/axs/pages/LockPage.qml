// Lock Screen — when the screen locks by itself, locking before sleep, and locking now.
import QtQuick
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Lock Screen"
    desc: "Keep your session private when you step away."

    // preview of the lock screen: the same artwork the login screen uses
    Rectangle {
        width: parent.width; height: 190
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        clip: true
        Image {
            anchors.fill: parent
            source: "file:///usr/share/sddm/themes/archangelos/assets/background.png"
            fillMode: Image.PreserveAspectCrop
            opacity: status === Image.Ready ? 0.55 : 0
            asynchronous: true
        }
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: Ax.alpha(Ax.base, 0.2) } GradientStop { position: 1; color: Ax.alpha(Ax.base, 0.85) } } }
        CornerTicks { len: 10; anchors.margins: 12 }
        Column {
            anchors.centerIn: parent; spacing: 8
            Label { anchors.horizontalCenter: parent.horizontalCenter; mono: true; font.pixelSize: 44; text: Qt.formatTime(new Date(), "HH:mm") }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 200; height: 30; radius: 15
                        color: Ax.alpha(Ax.base, 0.6); border.width: 1; border.color: Ax.accentLine
                        Label { anchors.centerIn: parent; text: "Password"; color: Ax.faint; font.pixelSize: Ax.fsSmall } }
        }
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
                       model: opts.map(s => Idle.label(s)); current: opts.indexOf(Store.data.lockAfter)
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
