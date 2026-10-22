// Notifications — do not disturb, and what has arrived recently.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import "../../src" as Frame
import "../../src/services" as N

PageScaffold {
    id: page
    property var meta
    group: "Personalize"
    title: "Notifications"
    desc: "Banners from apps, and the quiet mode that holds them back."

    readonly property var list: N.NotificationService.list

    Section {
        title: "Quiet"
        SRow {
            icon: Frame.ShellState.dnd ? "notifications_off" : "notifications_active"
            title: "Do not disturb"
            desc: Frame.ShellState.dnd ? "Banners are hidden. Notifications still collect in the list" : "Show a banner when something arrives"
            AxSwitch { anchors.verticalCenter: parent.verticalCenter; checked: Frame.ShellState.dnd; onToggled: (on) => Frame.ShellState.dnd = on }
        }
    }

    Section {
        title: "Recent"
        note: page.list.length ? page.list.length + " waiting" : ""
        EmptyState { visible: page.list.length === 0; icon: "notifications_none"; title: "You're all caught up"; desc: "New notifications collect here until you clear them." }
        Repeater {
            model: page.list.slice(0, 30)
            SRow {
                required property var modelData
                icon: "chat_bubble"
                title: (modelData.appName ? modelData.appName + "  ·  " : "") + (modelData.summary || "")
                desc: String(modelData.body || "").replace(/<[^>]*>/g, "").slice(0, 160)
                AxButton { icon: "close"; anchors.verticalCenter: parent.verticalCenter; onClicked: modelData.dismiss() }
            }
        }
        SRow {
            visible: page.list.length > 0
            icon: "clear_all"; title: "Clear all"
            AxButton { text: "Clear"; anchors.verticalCenter: parent.verticalCenter; onClicked: N.NotificationService.dismissAll() }
        }
    }

    Section {
        title: "Test"
        SRow {
            icon: "send"; title: "Send a test notification"; desc: "See how banners look with your current settings"
            AxButton { text: "Send"; anchors.verticalCenter: parent.verticalCenter
                       onClicked: Quickshell.execDetached(["notify-send", "-a", "Settings", "ArchangelOS", "Notifications are working."]) }
        }
    }
}
