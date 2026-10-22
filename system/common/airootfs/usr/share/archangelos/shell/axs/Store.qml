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
        }
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])
}
