// Wallpaper — pick from your wallpapers and the ArchangelOS set, stills or live video.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import "../../src/services" as FrameSvc
import "../../src" as Frame

PageScaffold {
    id: page
    property var meta
    group: "Personalize"
    title: "Wallpaper"
    desc: "Stills and live wallpapers. With colours from wallpaper on, the whole shell follows the one you pick."

    readonly property var ws: FrameSvc.WallpaperService
    readonly property var walls: page.ws.wallpapers
    Component.onCompleted: page.ws.refresh()

    header: Row {
        spacing: 8
        AxButton { icon: "folder_open"; text: "Open folder"
                   onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", page.ws.wallpaperDir.replace(/^~/, Quickshell.env("HOME"))]) }
        AxButton { icon: "refresh"; onClicked: page.ws.refresh() }
    }

    // current
    Rectangle {
        width: parent.width; height: 220
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        clip: true
        Image {
            id: cur
            anchors.fill: parent; anchors.margins: 1
            source: page.ws.currentWall ? "file://" + page.ws.posterFor(page.ws.currentWall) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 1200
        }
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0.55; color: "transparent" } GradientStop { position: 1; color: Ax.alpha(Ax.base, 0.9) } } }
        Column {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 20
            spacing: 4
            Label { caption: true; text: page.ws.isVideo(page.ws.currentWall) ? "Current  ·  live" : "Current" }
            Label { text: page.ws.currentWall ? page.ws.currentWall.split("/").pop() : "None set"; font.weight: Font.Medium }
        }
        Badge { visible: page.ws.applying; text: "applying"; tone: "accent"; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16 }
    }

    Section {
        title: "Colours"
        SRow {
            icon: "palette"; title: "Colours from wallpaper"; desc: "Let the accent and surfaces follow the wallpaper"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: !Frame.PrefsService.dynamicThemeOverride
                       onToggled: (on) => Frame.PrefsService.dynamicThemeOverride = !on }
        }
        SRow {
            visible: !Frame.PrefsService.dynamicThemeOverride
            icon: "tune"; title: "Colour style"; desc: "How boldly colours are drawn out of the image"
            AxSelect { width: 200; anchors.verticalCenter: parent.verticalCenter
                       model: page.ws.schemes.map(s => s.split("-").map(w => w[0].toUpperCase() + w.slice(1)).join(" "))
                       current: page.ws.schemes.indexOf(page.ws.scheme)
                       onPicked: (i) => { page.ws.scheme = page.ws.schemes[i]; if (page.ws.currentWall) page.ws.apply(page.ws.currentWall); } }
        }
    }

    Section {
        title: "Library"
        note: page.walls.length + " wallpapers"
        EmptyState {
            visible: page.walls.length === 0
            icon: "wallpaper"; title: "No wallpapers found"
            desc: "Put images or videos in " + page.ws.wallpaperDir + " and they'll show up here."
        }
        Item {
            property bool topDivider: false
            visible: page.walls.length > 0
            width: parent.width
            height: grid.height + 32
            Grid {
                id: grid
                x: Ax.pad; y: 16
                width: parent.width - 2 * Ax.pad
                columns: Math.max(2, Math.floor((width + 12) / 200))
                spacing: 12
                readonly property real cell: (width - (columns - 1) * spacing) / columns
                Repeater {
                    model: page.walls
                    Rectangle {
                        id: tile
                        required property string modelData
                        readonly property bool on: modelData === page.ws.currentWall
                        width: grid.cell; height: grid.cell * 0.6
                        radius: Ax.radiusSm
                        color: Ax.raised
                        border.width: on ? 2 : 1
                        border.color: on ? Ax.accent : (tma.containsMouse ? Ax.alpha(Ax.text, 0.2) : Ax.border)
                        clip: true
                        Image {
                            anchors.fill: parent; anchors.margins: tile.on ? 2 : 1
                            // stills straight from the file (scaled on load), videos from their poster frame
                            source: "file://" + page.ws.posterFor(tile.modelData)
                            sourceSize.width: 420
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                        Badge { visible: page.ws.isVideo(tile.modelData); text: "live"; anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 8 }
                        Rectangle { visible: tile.on; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                                    width: 22; height: 22; radius: 11; color: Ax.accent
                                    Icon { anchors.centerIn: parent; name: "check"; size: 15; color: "#fbf8f3" } }
                        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: page.ws.apply(tile.modelData) }
                    }
                }
            }
        }
    }
}
