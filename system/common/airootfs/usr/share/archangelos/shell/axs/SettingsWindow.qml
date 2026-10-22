// ArchangelOS Settings window — a regular toplevel the compositor tiles, floats and lists.
// Opened with `archangelos-settings [page]` (shell IPC: settings open <page>) or the launcher's
// Settings entry. Only the visible page is loaded, so closed settings cost nothing.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui
import qs.ns.services as NSS
import "../src" as Frame

FloatingWindow {
    id: win
    visible: NSS.Shell.settingsVisible
    onClosed: NSS.Shell.settingsVisible = false
    title: "Settings"
    color: Ax.base
    implicitWidth: 1220
    implicitHeight: 780
    minimumSize: Qt.size(960, 620)

    // created with the shell, so automatic time zone keeps working with Settings closed
    readonly property bool geoAuto: Geo.auto
    property string pageId: "profile"
    property string query: ""
    readonly property var current: Registry.find(win.pageId) ?? Registry.find("profile")
    readonly property var results: win.query.trim() === "" ? [] : Registry.search(win.query)

    function open(id) {
        if (Registry.find(id)) win.pageId = id;
        win.query = "";
        searchField.text = "";
    }
    onVisibleChanged: {
        if (!win.visible) return;
        if (NSS.Shell.settingsPage) win.open(NSS.Shell.settingsPage);
        NSS.Shell.settingsPage = "";
    }
    Connections {
        target: NSS.Shell
        function onSettingsPageChanged() {
            if (!win.visible || !NSS.Shell.settingsPage) return;
            win.open(NSS.Shell.settingsPage);
            NSS.Shell.settingsPage = "";
        }
    }

    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string avatar: Frame.PrefsService.customAvatarPath !== "" ? Frame.PrefsService.customAvatarPath
                                   : "file://" + (Quickshell.env("HOME") || "") + "/.face"

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_F) { searchField.focusIn(); e.accepted = true; }
            else if (e.key === Qt.Key_Escape) { if (win.query !== "") { searchField.text = ""; } else NSS.Shell.settingsVisible = false; e.accepted = true; }
        }

        // ── sidebar ──────────────────────────────────────────────────────────────
        Rectangle {
            id: side
            width: 272
            anchors.top: parent.top; anchors.bottom: parent.bottom
            color: Ax.sidebar

            // brand
            Item {
                id: brand
                x: 20; y: 22; width: parent.width - 40; height: 46
                Image {
                    id: mark
                    source: Qt.resolvedUrl("assets/mark.svg")
                    sourceSize: Qt.size(84, 62)
                    width: 42; height: 31
                    anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Column {
                    anchors.left: mark.right; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Label { text: "Settings"; font.pixelSize: Ax.fsHead + 1; font.weight: Font.DemiBold }
                    Label { caption: true; text: "ArchangelOS  ·  " + Registry.editionName }
                }
            }

            AxField {
                id: searchField
                x: 16; y: brand.y + brand.height + 18
                width: parent.width - 32
                icon: "search"
                placeholder: "Search settings   Ctrl F"
                onTextChanged: win.query = text
                onAccepted: if (win.results.length) win.open(win.results[0].id)
            }

            // nav (or search results)
            Flickable {
                id: navFlick
                anchors.top: searchField.bottom; anchors.topMargin: 14
                anchors.bottom: account.top; anchors.bottomMargin: 10
                x: 12; width: parent.width - 24
                contentHeight: navCol.implicitHeight + 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: navCol
                    width: parent.width
                    spacing: 2

                    // search results
                    Repeater {
                        model: win.results
                        delegate: NavItem {
                            required property var modelData
                            icon: modelData.icon; label: modelData.label
                            badge: modelData.group
                            active: modelData.id === win.pageId || modelData.id === win.current.parent
                            onClicked: win.open(modelData.id)
                        }
                    }
                    Label {
                        visible: win.query.trim() !== "" && win.results.length === 0
                        x: 12; topPadding: 10
                        text: "Nothing matches “" + win.query.trim() + "”"
                        color: Ax.faint; font.pixelSize: Ax.fsSmall
                    }

                    // grouped nav
                    Repeater {
                        model: win.query.trim() === "" ? Registry.groups : []
                        delegate: Column {
                            id: grp
                            required property var modelData
                            width: navCol.width
                            spacing: 2
                            Item {
                                visible: grp.modelData.name !== ""
                                width: parent.width; height: 32
                                Label { caption: true; text: grp.modelData.name; x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 8 }
                            }
                            Repeater {
                                model: grp.modelData.pages.filter(p => Registry.visible(p) && !p.hidden)
                                delegate: NavItem {
                                    required property var modelData
                                    icon: modelData.icon; label: modelData.label
                                    active: modelData.id === win.pageId || modelData.id === win.current.parent
                                    onClicked: win.open(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
            // fade the nav into the account strip
            Rectangle {
                anchors.bottom: navFlick.bottom; x: navFlick.x; width: navFlick.width; height: 24
                visible: navFlick.contentHeight > navFlick.height && !navFlick.atYEnd
                gradient: Gradient { GradientStop { position: 0; color: Ax.alpha(Ax.sidebar, 0) } GradientStop { position: 1; color: Ax.sidebar } }
            }

            // account chip
            Rectangle {
                id: account
                anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                x: 12; width: parent.width - 24; height: 52
                radius: Ax.radius - 2
                color: accMa.containsMouse ? Ax.hover : "transparent"
                border.width: 1; border.color: Ax.border
                Rectangle {
                    id: av
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 32; radius: 16
                    color: Ax.raised
                    border.width: 1; border.color: Ax.accentLine
                    clip: true
                    Label { anchors.centerIn: parent; visible: avImg.status !== Image.Ready; text: win.user.charAt(0).toUpperCase(); font.weight: Font.DemiBold; color: Ax.accent }
                    Image { id: avImg; anchors.fill: parent; anchors.margins: 1; source: win.avatar; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(64, 64); visible: status === Image.Ready }
                }
                Column {
                    anchors.left: av.right; anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Label { text: win.user; font.weight: Font.Medium }
                    Label { text: "Account settings"; font.pixelSize: Ax.fsSmall - 1; color: Ax.faint }
                }
                Icon { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; name: "chevron_right"; color: Ax.faint }
                MouseArea { id: accMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.open("users") }
            }
        }
        Rectangle { id: sideLine; anchors.left: side.right; width: 1; height: parent.height; color: Ax.border }

        // ── page ─────────────────────────────────────────────────────────────────
        Item {
            id: stage
            anchors.left: sideLine.right; anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: parent.bottom
            clip: true

            Loader {
                id: pageLoader
                anchors.fill: parent
                active: win.visible
                source: win.current ? Qt.resolvedUrl("pages/" + win.current.page + ".qml") : ""
                onLoaded: {
                    if (item && item.hasOwnProperty("meta")) item.meta = win.current;
                    enter.restart();
                }
                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: pageLoader.item; property: "opacity"; from: 0; to: 1; duration: Ax.durSlow; easing.type: Easing.OutCubic }
                    NumberAnimation { target: pageLoader.item; property: "y"; from: 10; to: 0; duration: Ax.durSlow; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
