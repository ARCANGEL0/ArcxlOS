import QtQuick 2.15
import QtMultimedia
import QtMultimedia 6.0 as QM6

Item {
    id: bg
    property url source
    property url fallbackSource
    property bool loopVideo: true
    property bool muted: true

    Image {
        id: poster
        anchors.fill: parent
        source: bg.fallbackSource
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
    }

    MediaPlayer {
        id: player
        source: bg.source
        audioOutput: QM6.AudioOutput { muted: bg.muted; volume: 0.0 }
        videoOutput: vout
        loops: bg.loopVideo ? MediaPlayer.Infinite : 1
        onErrorOccurred: function(err, str) {
            vout.opacity = 0
        }
    }

    VideoOutput {
        id: vout
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }

    Connections {
        target: player
        function onPlaybackStateChanged() {
            if (player.playbackState === MediaPlayer.PlayingState)
                vout.opacity = 1
        }
    }

    Component.onCompleted: player.play()
}
