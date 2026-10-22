// Lock Screen — when the screen locks by itself, locking before sleep, and locking now.
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Privacy & Security"
    title: "Lock Screen"
    desc: "Keep your session private when you step away."

    // The lock screen in miniature: /etc/hypr/hyprlock.conf drawn at scale — same background
    // (blurred, dimmed to 70%), mark, Quantico clock, user name and crimson password pill, at the
    // same offsets from the centre of a 1080p screen.
    QtObject { id: clock; property date now: new Date() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
    Rectangle {
        id: shot
        width: parent.width; height: Math.round(width * 9 / 16)
        radius: Ax.radius + 2
        color: "#0e0e0d"
        border.width: 1; border.color: Ax.border
        clip: true
        readonly property real k: height / 1080              // screen px → preview px
        readonly property real pt: 96 / 72 * k                // hyprlock font_size is in points
        readonly property string dir: "file:///usr/share/sddm/themes/archangelos/assets/"
        // hyprlock y offsets count up from the centre
        function cy(off, h) { return height / 2 - off * k - h / 2; }

        Image {
            id: bg
            anchors.fill: parent
            source: shot.dir + "background.png"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bg
            blurEnabled: true; blur: 0.35; blurMax: 32
            brightness: -0.3
            visible: bg.status === Image.Ready
        }
        Image {
            source: shot.dir + "logo.png"
            width: 176 * shot.k; height: width
            fillMode: Image.PreserveAspectFit
            x: (shot.width - width) / 2; y: shot.cy(232, height)
            smooth: true; mipmap: true
        }
        Text {
            text: Qt.formatTime(clock.now, "HH:mm")
            color: "#ecebe8"
            font.family: "Quantico"; font.pixelSize: 64 * shot.pt
            x: (shot.width - width) / 2; y: shot.cy(96, height)
        }
        Text {
            text: Quickshell.env("USER") || "user"
            color: "#9a9895"
            font.family: "Quantico"; font.pixelSize: 15 * shot.pt
            x: (shot.width - width) / 2; y: shot.cy(22, height)
        }
        Rectangle {
            width: 320 * shot.k; height: 52 * shot.k; radius: height / 2
            x: (shot.width - width) / 2; y: shot.cy(-48, height)
            color: "#1a1a19"
            border.width: Math.max(1, 2 * shot.k); border.color: "#c24a52"
            Text { anchors.centerIn: parent; text: "Enter password"; color: "#9a9895"
                   font.family: "Quantico"; font.pixelSize: 11 * shot.pt }
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
