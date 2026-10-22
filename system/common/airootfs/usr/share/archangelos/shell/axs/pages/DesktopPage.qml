// Desktop & Shell — the bar and island, which panels open on hover, the OSD, and motion.
import QtQuick
import qs.axs
import qs.axs.ui
import "../../src" as Frame

PageScaffold {
    id: page
    property var meta
    group: "Personalize"
    title: "Desktop & Shell"
    desc: "Tune ArcShell: the bar, the island and the panels around your screen."

    readonly property var prefs: Frame.PrefsService
    readonly property var curves: ["smooth", "spring", "cinematic", "sharp", "linear", "jello"]
    readonly property var curveNames: ["Smooth", "Spring", "Cinematic", "Sharp", "Linear", "Jello"]

    component Toggle: SRow {
        id: tg
        property string key
        AxSwitch { checked: !!page.prefs[tg.key]; anchors.verticalCenter: parent.verticalCenter; onToggled: (on) => page.prefs[tg.key] = on }
    }

    Section {
        title: "Bar & island"
        Toggle { icon: "view_sidebar"; title: "Show the bar"; desc: "The vertical bar along the left edge"; key: "barEnabled" }
        Toggle { icon: "graphic_eq"; title: "Music visualiser"; desc: "Live bars on the island while audio plays"; key: "enableVisualiser" }
        Toggle { icon: "battery_full"; title: "Battery percentage"; desc: "Always show the number next to the battery"; key: "alwaysShowBatteryPercentage" }
        Toggle { icon: "volume_up"; title: "Volume percentage"; desc: "Always show the number next to the volume"; key: "alwaysShowVolumePercentage" }
    }

    Section {
        title: "Open on hover"
        note: page.prefs.globalHoverMode ? "" : "click to open"
        Toggle { icon: "ads_click"; title: "Open panels by hovering"; desc: "Point at a panel's edge to open it, instead of clicking"; key: "globalHoverMode" }
        // which panels open on hover, as one row of chips
        Item {
            property bool topDivider: false
            visible: page.prefs.globalHoverMode
            width: parent.width
            height: chipCol.implicitHeight + 30
            Rectangle { visible: parent.topDivider; anchors.top: parent.top; x: Ax.pad; width: parent.width - 2 * Ax.pad; height: 1; color: Ax.divider }
            Column {
                id: chipCol
                x: Ax.pad; y: 15; width: parent.width - 2 * Ax.pad
                spacing: 12
                Label { text: "Panels that open on hover"; font.weight: Font.Medium }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: [
                            { k: "hoverDashboard", t: "Dashboard", i: "space_dashboard" },
                            { k: "hoverQuick", t: "Quick settings", i: "toggle_on" },
                            { k: "hoverNetwork", t: "Network", i: "wifi" },
                            { k: "hoverAudio", t: "Audio", i: "volume_up" },
                            { k: "hoverNotifications", t: "Notifications", i: "notifications" },
                            { k: "hoverClipboard", t: "Clipboard", i: "content_paste" },
                            { k: "hoverWallpaper", t: "Wallpaper picker", i: "wallpaper" }
                        ]
                        delegate: ChipToggle {
                            required property var modelData
                            text: modelData.t; icon: modelData.i
                            checked: !!page.prefs[modelData.k]
                            onToggled: (on) => page.prefs[modelData.k] = on
                        }
                    }
                }
            }
        }
        SRow {
            visible: page.prefs.globalHoverMode
            icon: "timer"; title: "Open delay"; desc: "How long to hover before a panel opens"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.prefs.hoverOpenDelay; from: 0; to: 800; stepSize: 10; suffix: " ms"
                       onMoved: (v) => page.prefs.hoverOpenDelay = Math.round(v) }
        }
        SRow {
            visible: page.prefs.globalHoverMode
            icon: "timer_off"; title: "Close delay"; desc: "How long a panel stays after the pointer leaves"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.prefs.hoverCloseDelay; from: 0; to: 1200; stepSize: 10; suffix: " ms"
                       onMoved: (v) => page.prefs.hoverCloseDelay = Math.round(v) }
        }
    }

    Section {
        title: "On-screen display"
        Toggle { icon: "picture_in_picture"; title: "Volume & brightness OSD"; desc: "A small overlay when you change volume or brightness"; key: "enableOsd" }
        SRow {
            visible: page.prefs.enableOsd
            icon: "hourglass_bottom"; title: "Stays for"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.prefs.osdDuration; from: 0.5; to: 5; stepSize: 0.5; decimals: 1; suffix: " s"
                       onMoved: (v) => page.prefs.osdDuration = v }
        }
    }

    Section {
        title: "Motion"
        SRow {
            icon: "speed"; title: "Animation speed"; desc: "Faster or slower than the ArchangelOS default"
            AxSlider { width: 260; anchors.verticalCenter: parent.verticalCenter; value: page.prefs.animSpeed; from: 0.5; to: 2.0; stepSize: 0.1; decimals: 1; suffix: "×"
                       onMoved: (v) => page.prefs.animSpeed = Math.round(v * 10) / 10 }
        }
        SRow {
            icon: "animation"; title: "Animation feel"; desc: "The curve panels open and close on"
            AxSelect { width: 200; anchors.verticalCenter: parent.verticalCenter
                       model: page.curveNames; current: page.curves.indexOf(page.prefs.animCurve)
                       onPicked: (i) => page.prefs.animCurve = page.curves[i] }
        }
    }
}
