// Appearance — accent, where colours come from, panel material and shape, and type.
// Every control writes the shell's own preferences, which save themselves and apply live.
import QtQuick
import qs.axs
import qs.axs.ui
import qs.ns as NSRoot
import "../../src" as Frame

PageScaffold {
    id: page
    property var meta
    group: "Personalize"
    title: "Appearance"
    desc: "How the shell looks: its accent, its panels and its type."

    readonly property bool fromWallpaper: !Frame.PrefsService.dynamicThemeOverride
    readonly property var accents: [
        { name: "Crimson", hex: "#C24A52" }, { name: "Ember", hex: "#C8643C" }, { name: "Brass", hex: "#B5945A" },
        { name: "Moss", hex: "#7E9C6A" },    { name: "Jade", hex: "#4F9A8A" },  { name: "Steel", hex: "#6F8EA8" },
        { name: "Iris", hex: "#8A7FC0" },    { name: "Rose", hex: "#C47A9A" },  { name: "Bone", hex: "#CFC7B8" }
    ]
    function same(a, b) { return String(a).toLowerCase() === String(b).toLowerCase(); }

    // ── preview strip ──────────────────────────────────────────────────────────
    Rectangle {
        width: parent.width; height: 120
        radius: Ax.radius + 2
        color: Ax.panel
        border.width: 1; border.color: Ax.border
        clip: true
        Row {
            anchors.left: parent.left; anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            // a miniature island + pane in the live style
            Rectangle {
                width: 220; height: 72; radius: Frame.PrefsService.cornerRadius * 0.6
                color: Ax.alpha(Ax.base, Frame.PrefsService.bgOpacity)
                border.width: Math.max(1, Frame.PrefsService.borderWidth / 4); border.color: Ax.border
                Column {
                    anchors.centerIn: parent; spacing: 8
                    Label { anchors.horizontalCenter: parent.horizontalCenter; mono: true; text: "09:41"; font.pixelSize: 20 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 3
                        Repeater { model: 22; Rectangle { required property int index; width: 3; radius: 1.5
                                   height: 4 + Math.abs(Math.sin(index * 0.7)) * 12; anchors.bottom: parent.bottom
                                   color: Ax.alpha(Ax.accent, 0.35 + Math.abs(Math.sin(index * 0.7)) * 0.65) } }
                    }
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Label { text: page.fromWallpaper ? "Colours from your wallpaper" : "ArchangelOS palette"; font.weight: Font.Medium }
                Label { text: page.fromWallpaper ? "The accent follows each wallpaper you set." : "Matte black with the accent you choose below."
                        color: Ax.faint; font.pixelSize: Ax.fsSmall }
                Row { spacing: 6; topPadding: 4
                      Repeater { model: [Ax.base, Ax.panel, Ax.raised, Ax.subtext, Ax.text, Ax.accent]
                                 Rectangle { required property var modelData; width: 22; height: 22; radius: 6; color: modelData; border.width: 1; border.color: Ax.border } } }
            }
        }
    }

    Section {
        title: "Colour"
        SRow {
            icon: "wallpaper"; title: "Colours from wallpaper"
            desc: "Derive the whole palette from the current wallpaper instead of the ArchangelOS palette"
            AxSwitch { checked: page.fromWallpaper; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Frame.PrefsService.dynamicThemeOverride = !on }
        }
        SRow {
            visible: page.fromWallpaper
            icon: "dark_mode"; title: "Dark mode"; desc: "Use the dark variant of the wallpaper palette"
            AxSwitch { checked: Frame.PrefsService.darkMode; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => Frame.PrefsService.darkMode = on }
        }
        // accent swatches
        Item {
            property bool topDivider: false
            width: parent.width
            height: accentCol.implicitHeight + 32
            opacity: page.fromWallpaper ? 0.4 : 1
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: accentCol
                x: Ax.pad; y: 16; width: parent.width - 2 * Ax.pad
                spacing: 12
                Row {
                    width: parent.width
                    Label { text: "Accent"; font.weight: Font.Medium; width: parent.width - hint.width }
                    Label { id: hint; text: page.fromWallpaper ? "Set by the wallpaper" : String(Frame.PrefsService.overrideActive).toUpperCase(); mono: true; font.pixelSize: Ax.fsSmall; color: Ax.faint }
                }
                Flow {
                    width: parent.width; spacing: 10
                    Repeater {
                        model: page.accents
                        delegate: Item {
                            id: sw
                            required property var modelData
                            readonly property bool on: page.same(Frame.PrefsService.overrideActive, modelData.hex)
                            width: 76; height: 64
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 34; height: 34; radius: 17
                                color: sw.modelData.hex
                                border.width: sw.on ? 2 : 0; border.color: Ax.base
                                Rectangle { anchors.centerIn: parent; width: 42; height: 42; radius: 21; color: "transparent"
                                            border.width: 2; border.color: sw.on ? sw.modelData.hex : (swMa.containsMouse ? Ax.alpha(Ax.text, 0.18) : "transparent") }
                                Icon { anchors.centerIn: parent; visible: sw.on; name: "check"; size: 18; color: "#fbf8f3" }
                            }
                            Label { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                    text: sw.modelData.name; font.pixelSize: Ax.fsSmall - 1; color: sw.on ? Ax.text : Ax.faint }
                            MouseArea { id: swMa; anchors.fill: parent; hoverEnabled: true; enabled: !page.fromWallpaper
                                        cursorShape: Qt.PointingHandCursor; onClicked: Frame.PrefsService.overrideActive = sw.modelData.hex }
                        }
                    }
                }
            }
        }
    }

    Section {
        title: "Panels"
        SRow {
            icon: "opacity"; title: "Panel opacity"; desc: "How solid the shell's bar, island and panels are"
            AxSlider { width: 280; anchors.verticalCenter: parent.verticalCenter
                       value: Frame.PrefsService.bgOpacity; from: 0.5; to: 1.0; valueScale: 100; suffix: "%"
                       onMoved: (v) => Frame.PrefsService.bgOpacity = Math.round(v * 100) / 100 }
        }
        SRow {
            icon: "blur_on"; title: "Blur behind panels"; desc: "Frosts what's underneath when panels are see-through"
            AxSwitch { checked: Frame.PrefsService.bgBlur; anchors.verticalCenter: parent.verticalCenter
                       onToggled: (on) => { Frame.PrefsService.bgBlur = on; Frame.PrefsService.updateHyprlandBlur(); } }
        }
        SRow {
            icon: "rounded_corner"; title: "Corner radius"; desc: "Roundness of the island, panels and notches"
            AxSlider { width: 280; anchors.verticalCenter: parent.verticalCenter
                       value: Frame.PrefsService.cornerRadius; from: 0; to: 32; stepSize: 1; suffix: " px"
                       onMoved: (v) => Frame.PrefsService.cornerRadius = Math.round(v) }
        }
        SRow {
            icon: "border_outer"; title: "Frame thickness"; desc: "The thin border that runs around the screen"
            AxSlider { width: 280; anchors.verticalCenter: parent.verticalCenter
                       value: Frame.PrefsService.borderWidth; from: 0; to: 16; stepSize: 1; suffix: " px"
                       onMoved: (v) => Frame.PrefsService.borderWidth = Math.round(v) }
        }
    }

    Section {
        title: "Type"
        SRow {
            icon: "text_fields"; title: "Shell font"; desc: "The face used across the bar, island and panels"
            AxSelect {
                id: fontSel
                width: 260; anchors.verticalCenter: parent.verticalCenter
                readonly property var keys: NSRoot.Config.fontFiles.map(f => f.key)
                model: NSRoot.Config.fontFiles.map(f => NSRoot.Config.fontNames[f.key] || f.key)
                current: keys.indexOf(NSRoot.Config.fontKey)
                onPicked: (i) => NSRoot.Config.fontPreset = keys[i]
            }
        }
    }
}
