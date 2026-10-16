import QtQuick

// The ArchangelOS app launcher (port of /usr/bin/archangelos-launcher):
// edition title + category sidebar on the left, category title, close
// button, search and a three-column grid of app cards on the right.
// Missing apps are dimmed and install on click.
//   Esc close   Enter launch   arrows move   Tab / Shift+Tab category
Item {
    id: view

    width: 1120
    height: 720

    property bool active: false
    property int row: 0
    readonly property string query: search.text.trim()
    readonly property var current: Apps.rows[row]
    readonly property var items: query ? Apps.search(query) : Apps.itemsFor(current)
    readonly property string title: query ? "Search: " + query.toLowerCase() : Apps.titleFor(current)
    property int sel: 0

    onActiveChanged: if (active) {
        search.text = ""
        sel = 0
        Apps.refreshInstalled()
        search.forceActiveFocus()
    }
    onItemsChanged: sel = 0

    function selectRow(r) {
        if (r < 0 || r >= Apps.rows.length) return
        search.text = ""
        row = r
    }

    function launch(item) {
        Apps.launch(item)
        ShellState.close()
    }

    // ── sidebar ──────────────────────────────────────────────────────────
    Rectangle {
        id: side
        width: 300
        height: parent.height
        color: Theme.sidebar

        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

        Text {
            id: brand
            x: 22; y: 22
            text: Apps.edition
            font.family: Theme.serif
            font.pixelSize: 20
            font.bold: true
            color: Theme.fg
        }

        ListView {
            id: cats
            anchors { top: brand.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom
                      leftMargin: 22; rightMargin: 16; bottomMargin: 18 }
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Apps.rows
            currentIndex: view.query ? -1 : view.row

            // Liquid highlight: stretches between rows, then settles.
            Liquid {
                id: catGlow
                width: cats.width
                visible: cats.currentItem !== null
                targetY: cats.currentItem ? cats.currentItem.y : 0
                targetHeight: cats.currentItem ? cats.currentItem.height : 0
                z: -1
                Rectangle { anchors.fill: parent; radius: 6; color: Theme.surfaceHot }
                Rectangle { width: 3; height: parent.height; radius: 1.5; color: Theme.accent }
            }

            delegate: Item {
                id: catRow
                required property var modelData
                required property int index
                readonly property bool sub: modelData.kind === "sub"
                readonly property bool selected: index === cats.currentIndex
                width: cats.width
                height: 37

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.surface
                    opacity: hover.containsMouse && !catRow.selected ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                }

                Text {
                    anchors { left: parent.left; leftMargin: catRow.sub ? 34 : 10; verticalCenter: parent.verticalCenter }
                    text: catRow.modelData.label
                    font.family: Theme.sans
                    font.pixelSize: 13
                    font.bold: catRow.selected
                    color: catRow.selected || hover.containsMouse ? Theme.fg
                         : catRow.sub ? Theme.faint : Theme.dim
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { view.selectRow(catRow.index); search.forceActiveFocus() }
                }
            }
        }
    }

    // ── content ──────────────────────────────────────────────────────────
    Item {
        id: content
        anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom
                  leftMargin: 28; rightMargin: 28; topMargin: 24; bottomMargin: 24 }

        Text {
            id: head
            anchors { left: parent.left; verticalCenter: close.verticalCenter }
            text: view.title
            font.family: Theme.serif
            font.pixelSize: 29
            font.bold: true
            color: Theme.fg

            // Title glides in whenever the category changes.
            onTextChanged: headIn.restart()
            ParallelAnimation {
                id: headIn
                NumberAnimation { target: head; property: "opacity"; from: 0.2; to: 1; duration: Theme.medium; easing.type: Easing.OutCubic }
                NumberAnimation { target: head; property: "anchors.leftMargin"; from: 10; to: 0; duration: Theme.slow; easing.type: Theme.curve }
            }
        }

        Rectangle {
            id: close
            anchors { right: parent.right; top: parent.top }
            width: 34; height: 34; radius: 17
            color: "transparent"
            border.width: 1
            border.color: closeHover.containsMouse ? Theme.accent : Theme.line
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }
            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 14
                color: closeHover.containsMouse ? Theme.accent : Theme.dim
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }
            MouseArea {
                id: closeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.close()
            }
        }

        Rectangle {
            id: field
            anchors { left: parent.left; right: parent.right; top: close.bottom; topMargin: 16 }
            height: 44
            radius: 8
            color: Theme.surface
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : Theme.line
            Behavior on border.color { ColorAnimation { duration: Theme.medium } }

            TextInput {
                id: search
                anchors { fill: parent; leftMargin: 13; rightMargin: 13 }
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.sans
                font.pixelSize: 14
                color: Theme.fg
                selectionColor: Qt.alpha(Theme.accent, 0.4)
                clip: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !search.text
                    text: "Search applications..."
                    font: search.font
                    color: Theme.faint
                }

                Keys.onPressed: event => {
                    const k = event.key
                    const n = view.items.length
                    if (k === Qt.Key_Escape) ShellState.close()
                    else if ((k === Qt.Key_Return || k === Qt.Key_Enter) && n) view.launch(view.items[view.sel])
                    else if (k === Qt.Key_Down) view.sel = Math.min(n - 1, view.sel + 3)
                    else if (k === Qt.Key_Up) view.sel = Math.max(0, view.sel - 3)
                    else if (k === Qt.Key_Right && search.cursorPosition === search.text.length) view.sel = Math.min(n - 1, view.sel + 1)
                    else if (k === Qt.Key_Left && search.cursorPosition === 0) view.sel = Math.max(0, view.sel - 1)
                    else if (k === Qt.Key_Tab) view.selectRow((view.row + 1) % Apps.rows.length)
                    else if (k === Qt.Key_Backtab) view.selectRow((view.row - 1 + Apps.rows.length) % Apps.rows.length)
                    else return
                    event.accepted = true
                }
            }
        }

        GridView {
            id: grid
            anchors { left: parent.left; right: parent.right; top: field.bottom; bottom: parent.bottom; topMargin: 16 }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: (width + 10) / 3
            cellHeight: 56
            model: view.items
            currentIndex: view.sel
            highlightFollowsCurrentItem: false

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool installed: Apps.isInstalled(modelData)
                readonly property bool hot: hover.containsMouse || index === view.sel
                width: grid.cellWidth
                height: grid.cellHeight

                // cards pour in, one after another
                opacity: 0
                transform: Translate { id: drift; x: -10 }
                Component.onCompleted: enter.start()
                SequentialAnimation {
                    id: enter
                    PauseAnimation { duration: Math.min(cell.index, 18) * 16 }
                    ParallelAnimation {
                        NumberAnimation { target: cell; property: "opacity"; to: 1; duration: Theme.medium; easing.type: Easing.OutCubic }
                        NumberAnimation { target: drift; property: "x"; to: 0; duration: Theme.slow; easing.type: Theme.curve }
                    }
                }

                Rectangle {
                    id: card
                    width: parent.width - 10
                    height: 46
                    radius: 8
                    color: cell.hot ? Theme.surfaceHot : Theme.surface
                    border.width: 1
                    border.color: cell.hot ? Theme.accent : Theme.line
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                    Text {
                        anchors { left: parent.left; right: hint.left; leftMargin: 14; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: cell.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.sans
                        font.pixelSize: 13
                        color: cell.installed ? Theme.fg : Theme.faint
                    }

                    // the old tooltip's "(installs on click)", shown on hover
                    Text {
                        id: hint
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: cell.installed ? "" : "INSTALL"
                        font.family: Theme.sans
                        font.pixelSize: 9
                        font.letterSpacing: 2
                        color: Theme.accent
                        opacity: cell.hot ? 0.9 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: card
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: view.sel = cell.index
                    onClicked: view.launch(cell.modelData)
                }
            }
        }
    }
}
