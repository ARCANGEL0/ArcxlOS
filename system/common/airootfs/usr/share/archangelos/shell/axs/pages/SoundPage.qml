// Sound — output and input devices, their volumes, and per-app volume (PipeWire, live).
import QtQuick
import Quickshell.Services.Pipewire
import qs.axs
import qs.axs.ui
import qs.arc.services as NSS

PageScaffold {
    id: page
    property var meta
    group: "Devices"
    title: "Sound"
    desc: "Choose where sound plays and records, and how loud each app is."

    readonly property bool pwUp: NSS.Audio.sink !== null || NSS.Audio.sinks.length > 0
    function nodeName(n) { return n ? (n.description || n.nickname || n.name || "Unknown device") : "—"; }
    function streamName(s) {
        const p = s.properties || {};
        return p["application.name"] || s.description || s.name || "App";
    }
    PwObjectTracker { objects: NSS.Audio.playbackStreams }

    Section {
        visible: !page.pwUp
        EmptyState {
            icon: "volume_off"
            title: "Audio service isn't running"
            desc: "ArchangelOS uses PipeWire. It starts with your session; if it's missing, run  systemctl --user enable --now pipewire wireplumber"
        }
    }

    Section {
        visible: page.pwUp
        title: "Output"
        SRow {
            icon: "speaker"; title: "Output device"; desc: "Where sound plays"
            AxSelect {
                width: 280; anchors.verticalCenter: parent.verticalCenter
                model: NSS.Audio.sinks.map(n => page.nodeName(n))
                current: NSS.Audio.sinks.indexOf(NSS.Audio.sink)
                onPicked: (i) => NSS.Audio.setAudioSink(NSS.Audio.sinks[i])
            }
        }
        SRow {
            icon: NSS.Audio.muted ? "volume_off" : NSS.Audio.volume < 0.4 ? "volume_down" : "volume_up"
            title: "Volume"
            AxButton { icon: NSS.Audio.muted ? "volume_off" : "volume_up"; kind: NSS.Audio.muted ? "danger" : "ghost"
                       anchors.verticalCenter: parent.verticalCenter; onClicked: NSS.Audio.toggleMute() }
            AxSlider { width: 300; anchors.verticalCenter: parent.verticalCenter
                       value: NSS.Audio.volume; to: 1.0; valueScale: 100; suffix: "%"
                       onMoved: (v) => NSS.Audio.setVolume(v) }
        }
    }

    Section {
        visible: page.pwUp
        title: "Input"
        EmptyState { visible: NSS.Audio.sources.length === 0; icon: "mic_off"; title: "No microphone found"; desc: "Plug in a headset or microphone and it will show up here." }
        SRow {
            visible: NSS.Audio.sources.length > 0
            icon: "mic"; title: "Input device"; desc: "Your microphone"
            AxSelect {
                width: 280; anchors.verticalCenter: parent.verticalCenter
                model: NSS.Audio.sources.map(n => page.nodeName(n))
                current: NSS.Audio.sources.indexOf(NSS.Audio.source)
                onPicked: (i) => NSS.Audio.setAudioSource(NSS.Audio.sources[i])
            }
        }
        SRow {
            visible: NSS.Audio.sources.length > 0
            icon: NSS.Audio.sourceMuted ? "mic_off" : "mic"
            title: "Input volume"
            AxButton { icon: NSS.Audio.sourceMuted ? "mic_off" : "mic"; kind: NSS.Audio.sourceMuted ? "danger" : "ghost"
                       anchors.verticalCenter: parent.verticalCenter; onClicked: NSS.Audio.toggleMic() }
            AxSlider { width: 300; anchors.verticalCenter: parent.verticalCenter
                       value: NSS.Audio.sourceVolume; to: 1.0; valueScale: 100; suffix: "%"
                       onMoved: (v) => NSS.Audio.setSourceVolume(v) }
        }
    }

    Section {
        visible: page.pwUp
        title: "Apps"
        note: NSS.Audio.playbackStreams.length ? NSS.Audio.playbackStreams.length + " playing" : ""
        EmptyState { visible: NSS.Audio.playbackStreams.length === 0; icon: "graphic_eq"; title: "Nothing is playing"; desc: "Apps that play sound show up here with their own volume." }
        Repeater {
            model: NSS.Audio.playbackStreams
            delegate: SRow {
                required property var modelData
                icon: "graphic_eq"
                title: page.streamName(modelData)
                desc: modelData.properties ? (modelData.properties["media.name"] || "") : ""
                AxButton { icon: modelData.audio && modelData.audio.muted ? "volume_off" : "volume_up"
                           kind: modelData.audio && modelData.audio.muted ? "danger" : "ghost"
                           anchors.verticalCenter: parent.verticalCenter
                           onClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted }
                AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter
                           value: modelData.audio ? modelData.audio.volume : 0; to: 1.0; valueScale: 100; suffix: "%"
                           onMoved: (v) => { if (modelData.audio) modelData.audio.volume = v; } }
            }
        }
    }
}
