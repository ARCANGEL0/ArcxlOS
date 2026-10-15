import QtQuick
import Quickshell

// Launcher panel. Category rail on the left (Recent + the edition's menu),
// app grid on the right; typing searches every category at once.
//   Up/Down/Left/Right  select     Tab / Shift+Tab  category
//   Enter               launch     Esc              close
Item {
    id: view

    property int cat: 0
    readonly property string query: search.text
    readonly property var rail: Apps.rail
    readonly property var items: query.length
        ? Apps.search(query)
        : (rail[cat] ? rail[cat].items : [])

    onQueryChanged: grid.currentIndex = 0
    onCatChanged: grid.currentIndex = 0

    Component.onCompleted: {
        Apps.refreshInstalled()
        search.forceActiveFocus()
    }

    function step(delta) {
        if (items.length === 0) return
        grid.currentIndex = Math.max(0, Math.min(items.length - 1, grid.currentIndex + delta))
    }

    function stepCategory(delta) {
        search.text = ""
        cat = (cat + delta + rail.length) % rail.length
    }

    function launchCurrent() {
        if (grid.currentIndex >= 0 && grid.currentIndex < items.length) {
            Apps.launch(items[grid.currentIndex])
            ShellState.close()
        }
    }

    // Faint brush-stroke watermark: 起動, "to launch".
    Text {
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: -10; bottomMargin: -70 }
        text: "起動"
        font.family: Theme.serif
        font.pixelSize: 260
        color: Theme.fg
        opacity: 0.03
    }

    // ── header ───────────────────────────────────────────────────────────
    Row {
        id: header
        anchors { top: parent.top; left: parent.left; topMargin: 26; leftMargin: 36 }
        spacing: 14

        Text {
            anchors.baseline: label.baseline
            text: "起動"
            font.family: Theme.serif
            font.pixelSize: 24
            color: Theme.accent
        }
        Text {
            id: label
            text: "LAUNCH"
            font.family: Theme.sans
            font.pixelSize: 11
            font.letterSpacing: 5
            color: Theme.dim
        }
    }

    Text {
        anchors { right: parent.right; rightMargin: 36; verticalCenter: header.verticalCenter }
        text: Apps.edition.toUpperCase()
        font.family: Theme.sans
        font.pixelSize: 10
        font.letterSpacing: 4
        color: Theme.faint
    }

    // ── search: SDDM-style line field ────────────────────────────────────
    Item {
        id: field
        anchors { top: header.bottom; left: parent.left; right: parent.right; topMargin: 22; leftMargin: 36; rightMargin: 36 }
        height: 52

        Text {
            text: "SEARCH"
            font.family: Theme.sans
            font.pixelSize: 10
            font.letterSpacing: 3
            color: view.query.length ? Theme.accent : Theme.faint
            Behavior on color { ColorAnimation { duration: Theme.medium } }
        }

        TextInput {
            id: search
            anchors { left: parent.left; right: count.left; bottom: parent.bottom; bottomMargin: 8 }
            font.family: Theme.sans
            font.pixelSize: 19
            font.letterSpacing: 0.5
            color: Theme.fg
            selectionColor: Qt.alpha(Theme.accent, 0.4)
            clip: true
            cursorDelegate: Rectangle {
                width: 1
                color: Theme.accent
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.15; duration: 700; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.15; to: 1; duration: 700; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                anchors.fill: parent
                visible: !search.text
                text: "Type to search every category"
                font: search.font
                color: Theme.faint
            }

            Keys.onPressed: event => {
                const k = event.key
                if (k === Qt.Key_Escape) ShellState.close()
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) view.launchCurrent()
                else if (k === Qt.Key_Down) view.step(2)
                else if (k === Qt.Key_Up) view.step(-2)
                else if (k === Qt.Key_Right && search.cursorPosition === search.text.length) view.step(1)
                else if (k === Qt.Key_Left && search.cursorPosition === 0) view.step(-1)
                else if (k === Qt.Key_Tab) view.stepCategory(1)
                else if (k === Qt.Key_Backtab) view.stepCategory(-1)
                else return
                event.accepted = true
            }
        }

        Text {
            id: count
            anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 10 }
            text: String(view.items.length).padStart(2, "0") + " ITEMS"
            font.family: Theme.sans
            font.pixelSize: 10
            font.letterSpacing: 3
            color: Theme.faint
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.line
        }
        // accent underline draws out from the left as you type
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom }
            height: 1
            width: view.query.length ? parent.width : 0
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: Theme.morph; easing.type: Theme.curve } }
        }
    }

    // ── category rail ────────────────────────────────────────────────────
    ListView {
        id: railList
        anchors { top: field.bottom; left: parent.left; bottom: footer.top; topMargin: 22; leftMargin: 28; bottomMargin: 14 }
        width: 196
        clip: true
        model: view.rail
        currentIndex: view.query.length ? -1 : view.cat
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: Theme.medium
        highlightFollowsCurrentItem: true

        highlight: Item {
            width: railList.width
            height: 30
            Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.fg, 0.04) }
            Rectangle { width: 2; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
        }

        delegate: Item {
            id: railItem
            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem
            width: railList.width
            height: 30

            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 10
                Text {
                    text: String(railItem.index + 1).padStart(2, "0")
                    font.family: Theme.sans
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: railItem.current ? Theme.accent : Theme.faint
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: railItem.modelData.name.toUpperCase()
                    font.family: Theme.sans
                    font.pixelSize: 11
                    font.letterSpacing: 2.5
                    color: railItem.current ? Theme.fg : Theme.dim
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { search.text = ""; view.cat = railItem.index; search.forceActiveFocus() }
            }
        }
    }

    Rectangle {
        id: rule
        anchors { top: railList.top; bottom: railList.bottom; left: railList.right; leftMargin: 14 }
        width: 1
        color: Theme.line
    }

    // ── app grid ─────────────────────────────────────────────────────────
    GridView {
        id: grid
        anchors { top: railList.top; bottom: railList.bottom; left: rule.right; right: parent.right; leftMargin: 14; rightMargin: 28 }
        clip: true
        model: view.items
        cellWidth: Math.floor(width / 2)
        cellHeight: 58
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: Theme.quick
        highlightFollowsCurrentItem: true
        keyNavigationEnabled: false

        highlight: Item {
            width: grid.cellWidth
            height: grid.cellHeight
            Rectangle { anchors.fill: parent; anchors.margins: 3; color: Qt.alpha(Theme.accent, 0.10) }
            Rectangle { x: 3; width: 2; height: parent.height - 6; y: 3; color: Theme.accent }
        }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool ready: Apps.isInstalled(modelData)
            readonly property string icon: ready ? Apps.iconFor(modelData) : ""
            width: grid.cellWidth
            height: grid.cellHeight

            // staggered entrance, capped so long lists don't drag
            opacity: 0
            transform: Translate { id: lift; y: 8 }
            Component.onCompleted: enter.start()
            ParallelAnimation {
                id: enter
                SequentialAnimation {
                    PauseAnimation { duration: Math.min(cell.index, 14) * 22 }
                    ParallelAnimation {
                        NumberAnimation { target: cell; property: "opacity"; to: 1; duration: Theme.medium; easing.type: Easing.OutCubic }
                        NumberAnimation { target: lift; property: "y"; to: 0; duration: Theme.medium; easing.type: Theme.curve }
                    }
                }
            }

            Item {
                id: glyph
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                width: 28
                height: 28

                Image {
                    anchors.fill: parent
                    source: cell.icon
                    visible: cell.icon !== ""
                    sourceSize: Qt.size(56, 56)
                    asynchronous: true
                }
                // monogram stand-in for apps with no icon (or not yet installed)
                Rectangle {
                    anchors.fill: parent
                    visible: cell.icon === ""
                    color: "transparent"
                    border.color: cell.ready ? Theme.dim : Theme.line
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.name.charAt(0).toUpperCase()
                        font.family: Theme.sans
                        font.pixelSize: 13
                        color: cell.ready ? Theme.fg : Theme.faint
                    }
                }
            }

            Column {
                anchors { left: glyph.right; leftMargin: 14; right: tag.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 3
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: cell.modelData.name
                    font.family: Theme.sans
                    font.pixelSize: 14
                    color: cell.ready ? Theme.fg : Theme.dim
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Apps.binOf(cell.modelData) + (cell.modelData.terminal ? "  ·  TERMINAL" : "")
                    font.family: Theme.sans
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    color: Theme.faint
                }
            }

            Text {
                id: tag
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                text: cell.ready ? "" : "INSTALL"
                font.family: Theme.sans
                font.pixelSize: 9
                font.letterSpacing: 2.5
                color: Qt.alpha(Theme.accent, 0.85)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: grid.currentIndex = cell.index
                onClicked: { grid.currentIndex = cell.index; view.launchCurrent() }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: grid.count === 0
            text: view.query.length ? "NOTHING MATCHES  “" + view.query + "”" : ""
            font.family: Theme.sans
            font.pixelSize: 11
            font.letterSpacing: 3
            color: Theme.faint
        }
    }

    // ── footer: key hints ────────────────────────────────────────────────
    Row {
        id: footer
        anchors { bottom: parent.bottom; left: parent.left; bottomMargin: 26; leftMargin: 36 }
        spacing: 26

        Repeater {
            model: [["↑↓←→", "SELECT"], ["TAB", "CATEGORY"], ["ENTER", "LAUNCH"], ["ESC", "CLOSE"]]
            Row {
                required property var modelData
                spacing: 8
                Text {
                    text: parent.modelData[0]
                    font.family: Theme.sans
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: Theme.dim
                }
                Text {
                    text: parent.modelData[1]
                    font.family: Theme.sans
                    font.pixelSize: 9
                    font.letterSpacing: 2.5
                    color: Theme.faint
                }
            }
        }
    }
}
