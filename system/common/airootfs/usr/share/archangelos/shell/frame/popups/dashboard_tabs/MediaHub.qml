import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.arc.services as NSS
import "../../"
import "../../components"
import "../../services"

Item {
    id: root
    property real localScale: 1.0

    readonly property real u: root.localScale
    readonly property real gap: Math.round(10 * u)
    readonly property var player: MediaService.activePlayer
    readonly property bool hasPlayer: player !== null
    readonly property bool hasTrack: hasPlayer
        && (player.trackTitle ?? "") !== ""
        && (player.playbackState === MprisPlaybackState.Playing || player.playbackState === MprisPlaybackState.Paused)
    readonly property string trackArt: hasTrack ? MediaService.artUrl : ""
    readonly property bool playing: MediaService.isPlaying
    readonly property string album: player?.trackAlbum ?? ""

    Binding {
        target: CavaService
        property: "dashboardVisible"
        value: true
        when: root.visible && Popups.dashboardOpen
    }

    PwObjectTracker {
        objects: NSS.Audio.playbackStreams
    }

    component Panel: Rectangle {
        radius: Math.round(14 * root.u)
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.03)
        border.width: 1
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
    }

    component SectionLabel: Text {
        color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.75)
        font.pixelSize: Math.round(10 * root.u)
        font.bold: true
        font.letterSpacing: 1.2
    }

    component IconButton: Item {
        id: ib
        property string icon: ""
        property string tip: ""
        property bool active: false
        property bool enabledState: true
        property real size: 28
        property real glyph: 15
        signal clicked()
        width: Math.round(size * root.u)
        height: width
        opacity: enabledState ? 1 : 0.35
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: ib.active
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, ibArea.containsMouse ? 0.32 : 0.2)
                : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, ibArea.containsMouse ? 0.08 : 0)
            Behavior on color { ColorAnimation { duration: Anim.color } }
        }
        Text {
            anchors.centerIn: parent
            text: ib.icon
            font.pixelSize: Math.round(ib.glyph * root.u)
            color: ib.active || ibArea.containsMouse ? Theme.active : Theme.text
            scale: ibArea.pressed ? 0.86 : 1
            Behavior on scale { NumberAnimation { duration: 110 } }
            Behavior on color { ColorAnimation { duration: Anim.color } }
        }
        MouseArea {
            id: ibArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: ib.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (ib.enabledState) ib.clicked()
        }
        Tip { text: ib.tip; localScale: root.u }
    }

    component LineSlider: Item {
        id: ls
        property real value: 0
        property bool muted: false
        signal moved(real v)
        height: Math.round(16 * root.u)
        readonly property real shown: dragArea.pressed ? dragArea.dragValue : value
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Math.round(4 * root.u)
            radius: height / 2
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.1)
            Rectangle {
                width: Math.max(height, parent.width * Math.max(0, Math.min(1, ls.shown)))
                height: parent.height
                radius: height / 2
                color: ls.muted ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.3) : Theme.active
            }
        }
        Rectangle {
            width: Math.round(12 * root.u)
            height: width
            radius: width / 2
            x: Math.max(0, Math.min(parent.width - width, parent.width * Math.max(0, Math.min(1, ls.shown)) - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            visible: dragArea.containsMouse || dragArea.pressed
        }
        MouseArea {
            id: dragArea
            property real dragValue: 0
            anchors.fill: parent
            anchors.topMargin: -Math.round(4 * root.u)
            anchors.bottomMargin: -Math.round(4 * root.u)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function valueAt(mx) { return Math.max(0, Math.min(1, mx / width)) }
            onPressed: (mouse) => { dragValue = valueAt(mouse.x); ls.moved(dragValue) }
            onPositionChanged: (mouse) => { if (pressed) { dragValue = valueAt(mouse.x); ls.moved(dragValue) } }
        }
    }

    Item {
        id: leftCol
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: root.gap
        width: parent.width * 0.62

        Row {
            id: chips
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.round(30 * root.u)
            spacing: Math.round(8 * root.u)
            clip: true

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "PLAYERS"
                visible: MediaService.filteredPlayers.length > 0
            }

            Repeater {
                model: MediaService.filteredPlayers
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool selected: modelData === root.player
                    readonly property bool isPlaying: modelData.playbackState === MprisPlaybackState.Playing
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.round(26 * root.u)
                    width: chipRow.implicitWidth + Math.round(20 * root.u)
                    radius: height / 2
                    color: selected
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2)
                        : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, chipArea.containsMouse ? 0.08 : 0.04)
                    border.width: 1
                    border.color: selected ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                    Behavior on color { ColorAnimation { duration: Anim.color } }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Math.round(6 * root.u)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(6 * root.u)
                            height: width
                            radius: width / 2
                            color: chip.isPlaying ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: MediaService.playerLabel(chip.modelData)
                            color: chip.selected ? Theme.text : Theme.subtext
                            font.pixelSize: Math.round(11 * root.u)
                            font.bold: chip.selected
                        }
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaService.selectPlayer(chip.index)
                    }
                }
            }
        }

        Panel {
            id: playerPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: chips.bottom
            anchors.topMargin: Math.round(8 * root.u)
            height: Math.round(236 * root.u)
            clip: true

            Image {
                id: backdrop
                anchors.fill: parent
                source: root.trackArt
                fillMode: Image.PreserveAspectCrop
                visible: false
                asynchronous: true
                sourceSize.width: 256
            }
            MultiEffect {
                anchors.fill: parent
                source: backdrop
                visible: backdrop.status === Image.Ready
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                brightness: -0.55
                saturation: 0.2
                opacity: 0.55
            }

            Item {
                id: art
                anchors.left: parent.left
                anchors.leftMargin: Math.round(18 * root.u)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(196 * root.u)
                height: width

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(16 * root.u)
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.25)
                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        font.pixelSize: Math.round(64 * root.u)
                        color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5)
                    }
                }
                Rectangle {
                    id: artMask
                    anchors.fill: parent
                    radius: Math.round(16 * root.u)
                    visible: false
                    layer.enabled: true
                }
                Image {
                    id: artImage
                    anchors.fill: parent
                    source: root.trackArt
                    sourceSize.width: Math.round(art.width * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: root.trackArt !== "" && status === Image.Ready
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: artMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }
            }

            Column {
                id: info
                anchors.left: art.right
                anchors.leftMargin: Math.round(22 * root.u)
                anchors.right: parent.right
                anchors.rightMargin: Math.round(20 * root.u)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * root.u)
                visible: root.hasPlayer

                Text {
                    width: parent.width
                    text: MediaService.title || "Unknown title"
                    color: Theme.text
                    font.pixelSize: Math.round(19 * root.u)
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: MediaService.artist
                    visible: text !== ""
                    color: Theme.active
                    font.pixelSize: Math.round(13 * root.u)
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.album
                    visible: text !== ""
                    color: Theme.subtext
                    font.pixelSize: Math.round(12 * root.u)
                    elide: Text.ElideRight
                }

                Item { width: 1; height: Math.round(8 * root.u) }

                LineSlider {
                    width: parent.width
                    value: MediaService.progress
                    opacity: MediaService.canSeek ? 1 : 0.5
                    enabled: MediaService.canSeek
                    onMoved: (v) => MediaService.seek(v)
                }
                Item {
                    width: parent.width
                    height: Math.round(14 * root.u)
                    Text {
                        anchors.left: parent.left
                        text: MediaService._fmt(MediaService._pos)
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.round(10 * root.u)
                    }
                    Text {
                        anchors.right: parent.right
                        text: MediaService.length > 0 ? MediaService._fmt(MediaService.length) : "--:--"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.round(10 * root.u)
                    }
                }

                Item {
                    width: parent.width
                    height: Math.round(46 * root.u)

                    IconButton {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.player?.shuffleSupported ?? false
                        icon: "󰒟"
                        tip: root.player?.shuffle ? "Shuffle off" : "Shuffle on"
                        active: root.player?.shuffle ?? false
                        onClicked: root.player.shuffle = !root.player.shuffle
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(16 * root.u)
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰒮"; tip: "Previous track"; size: 34; glyph: 18
                            enabledState: MediaService.canPrev
                            onClicked: MediaService.prev()
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: root.playing ? "󰏤" : "󰐊"
                            tip: root.playing ? "Pause" : "Play"
                            size: 44; glyph: 22; active: true
                            enabledState: MediaService.canToggle
                            onClicked: MediaService.toggle()
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰒭"; tip: "Next track"; size: 34; glyph: 18
                            enabledState: MediaService.canNext
                            onClicked: MediaService.next()
                        }
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.player?.loopSupported ?? false
                        readonly property int loopState: root.player?.loopState ?? MprisLoopState.None
                        icon: loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                        tip: loopState === MprisLoopState.None ? "Repeat all"
                           : loopState === MprisLoopState.Playlist ? "Repeat one" : "Repeat off"
                        active: loopState !== MprisLoopState.None
                        onClicked: root.player.loopState = loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                                         : loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                                                         : MprisLoopState.None
                    }
                }

                Row {
                    width: parent.width
                    spacing: Math.round(8 * root.u)
                    visible: root.player?.volumeSupported ?? false
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰕾"
                        color: Theme.subtext
                        font.pixelSize: Math.round(13 * root.u)
                    }
                    LineSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Math.round(60 * root.u)
                        value: root.player?.volume ?? 0
                        onMoved: (v) => { if (root.player) root.player.volume = v }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round((root.player?.volume ?? 0) * 100) + "%"
                        color: Theme.subtext
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.round(10 * root.u)
                    }
                }
            }

            Column {
                anchors.left: art.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * root.u)
                visible: !root.hasPlayer
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing playing"
                    color: Theme.text
                    font.pixelSize: Math.round(18 * root.u)
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Start music in any app and it shows up here"
                    color: Theme.subtext
                    font.pixelSize: Math.round(12 * root.u)
                }
            }
        }

        Panel {
            id: visPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: playerPanel.bottom
            anchors.topMargin: root.gap
            anchors.bottom: parent.bottom

            Row {
                id: vis
                anchors.fill: parent
                anchors.margins: Math.round(14 * root.u)
                readonly property int count: CavaService.barCount
                readonly property real barW: Math.max(2, (width - (count - 1) * spacing) / count)
                spacing: Math.round(4 * root.u)
                Repeater {
                    model: vis.count
                    delegate: Item {
                        required property int index
                        readonly property real amp: root.playing ? (CavaService.bars[index] ?? 0) / 100.0 : 0
                        width: vis.barW
                        height: vis.height
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(Math.round(3 * root.u), parent.amp * parent.height)
                            radius: Math.min(width / 2, Math.round(4 * root.u))
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.active }
                                GradientStop { position: 1.0; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.25) }
                            }
                            Behavior on height { NumberAnimation { duration: 90 } }
                        }
                    }
                }
            }
        }
    }

    Panel {
        id: routing
        anchors.left: leftCol.right
        anchors.leftMargin: root.gap
        anchors.right: parent.right
        anchors.rightMargin: root.gap
        anchors.top: parent.top
        anchors.topMargin: root.gap
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.gap

        Flickable {
            anchors.fill: parent
            anchors.margins: Math.round(14 * root.u)
            contentHeight: routeCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: routeCol
                width: parent.width
                spacing: Math.round(6 * root.u)

                SectionLabel { text: "OUTPUT" }
                Repeater {
                    model: NSS.Audio.sinks
                    delegate: DeviceRow { isOutput: true }
                }

                Item { width: 1; height: Math.round(6 * root.u) }
                SectionLabel { text: "INPUT" }
                Repeater {
                    model: NSS.Audio.sources
                    delegate: DeviceRow { isOutput: false }
                }

                Item { width: 1; height: Math.round(6 * root.u) }
                SectionLabel { text: "APP MIXER" }
                Text {
                    visible: NSS.Audio.playbackStreams.length === 0
                    text: "No apps are playing audio"
                    color: Theme.subtext
                    font.pixelSize: Math.round(11 * root.u)
                }
                Repeater {
                    model: NSS.Audio.playbackStreams
                    delegate: Column {
                        id: streamRow
                        required property var modelData
                        readonly property bool muted: modelData?.audio?.muted ?? false
                        width: routeCol.width
                        spacing: Math.round(2 * root.u)
                        Row {
                            width: parent.width
                            spacing: Math.round(6 * root.u)
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(16 * root.u)
                                height: width
                                sourceSize.width: width * 2
                                source: Quickshell.iconPath(streamRow.modelData?.properties["application.icon-name"] ?? "", "audio-x-generic")
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Math.round(66 * root.u)
                                text: NSS.Audio.getStreamName(streamRow.modelData)
                                color: Theme.text
                                font.pixelSize: Math.round(11 * root.u)
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(30 * root.u)
                                horizontalAlignment: Text.AlignRight
                                text: Math.round((streamRow.modelData?.audio?.volume ?? 0) * 100) + "%"
                                color: Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: Math.round(9 * root.u)
                            }
                        }
                        Row {
                            width: parent.width
                            spacing: Math.round(6 * root.u)
                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 22; glyph: 12
                                icon: streamRow.muted ? "󰖁" : "󰕾"
                                tip: streamRow.muted ? "Unmute" : "Mute"
                                active: streamRow.muted
                                onClicked: NSS.Audio.setStreamMuted(streamRow.modelData, !streamRow.muted)
                            }
                            LineSlider {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Math.round(28 * root.u)
                                muted: streamRow.muted
                                value: streamRow.modelData?.audio?.volume ?? 0
                                onMoved: (v) => NSS.Audio.setStreamVolume(streamRow.modelData, v)
                            }
                        }
                    }
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: dev
        required property var modelData
        property bool isOutput: true
        readonly property bool current: modelData === (isOutput ? NSS.Audio.sink : NSS.Audio.source)
        width: routeCol.width
        height: Math.round(30 * root.u)
        radius: Math.round(8 * root.u)
        color: current
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.16)
            : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, devArea.containsMouse ? 0.06 : 0)
        border.width: current ? 1 : 0
        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
        Behavior on color { ColorAnimation { duration: Anim.color } }
        Row {
            anchors.fill: parent
            anchors.leftMargin: Math.round(10 * root.u)
            anchors.rightMargin: Math.round(10 * root.u)
            spacing: Math.round(8 * root.u)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dev.isOutput ? "󰓃" : "󰍬"
                color: dev.current ? Theme.active : Theme.subtext
                font.pixelSize: Math.round(13 * root.u)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Math.round(26 * root.u)
                text: dev.modelData?.nickname || dev.modelData?.description || dev.modelData?.name || "Unknown"
                color: dev.current ? Theme.text : Theme.subtext
                font.pixelSize: Math.round(11 * root.u)
                font.bold: dev.current
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: devArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dev.isOutput ? NSS.Audio.setAudioSink(dev.modelData) : NSS.Audio.setAudioSource(dev.modelData)
        }
    }
}
