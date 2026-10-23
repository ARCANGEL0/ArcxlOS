// Settings that belong to ArchangelOS itself (idle, lock), kept in ~/.config/archangelos/settings.json.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/archangelos"
    property alias data: adapter
    // No settings file yet: the idle config on disk isn't ours, so Idle rewrites it to match.
    property bool fresh: false

    FileView {
        id: file
        path: root.dir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: (err) => { if (err === FileViewError.FileNotFound) { root.fresh = true; writeAdapter(); } }
        JsonAdapter {
            id: adapter
            // seconds; 0 = never
            property int dimAfter: 180
            property bool autoLock: true
            property int lockAfter: 300
            property int screenOffAfter: 600
            property int suspendAfter: 1800
            property bool lockOnSleep: true
            property bool autoTimezone: false
            // Privacy & history: what to clear at every sign-in
            property bool clearRecent: false
            property bool clearClipboard: false
            property bool clearThumbs: false
            property bool clearShellHistory: false
            property int trashDays: 0
            // Encryption: defaults for new encrypted drives
            property string luksCipher: "aes-xts-plain64"
            property int luksKeyBits: 512
            property string luksHash: "sha512"
            property string luksPbkdf: "argon2id"
            // gocryptfs vaults: [{ name, cipher, mount }]
            property var vaults: []
            // Windows & workspaces: user window rules [{ match, kind(class|title), float, opacity, workspace }]
            property var wmRules: []
            // Accessibility
            property int cursorSize: 24
            property real textScale: 1.0
            property bool reduceMotion: false
            property string colorFilter: ""     // "" | grayscale | invert | highcontrast
        }
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])
}
