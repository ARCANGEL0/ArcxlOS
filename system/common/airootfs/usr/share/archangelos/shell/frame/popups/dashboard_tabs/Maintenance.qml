import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "../../"
import "../../components"
import "../../services"

Item {
    id: root

    property real localScale: 1.0

    readonly property real gap: Math.round(8 * localScale)
    readonly property real colW: (width - gap * 2) / 3

    property var repoUpdates: []
    property var aurUpdates: []
    property bool updatesBusy: false
    property bool repoDone: false
    property bool aurDone: false
    property string lastChecked: ""

    property string pkgCacheSize: ""
    property string userCacheSize: ""
    property var orphans: []
    property bool cleanupBusy: false

    property var failedUnits: []
    property bool servicesBusy: false

    property var errorLines: []
    property bool errorsBusy: false

    property var disks: []
    property var bigFolders: []
    property bool bigBusy: false

    property double lastRefresh: 0

    property string osVersion: ""
    property string osRemote: ""
    readonly property bool osUpdate: osRemote !== "" && osRemote !== osVersion

    FileView {
        path: "/etc/archangelos/version"
        onLoaded: root.osVersion = text().trim()
    }

    Process {
        id: osProc
        command: ["sh", "-c", "archangelos-update check 2>/dev/null; echo \"EXIT:$?\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /remote:\s*(\S+)/.exec(text)
                const ex = /EXIT:(\d+)/.exec(text)
                root.osRemote = m && ex && ex[1] === "3" ? m[1] : ""
            }
        }
    }

    function inTerminal(script, args) {
        const tail = "; echo; read -r -n1 -p 'Done — press any key to close' _"
        Quickshell.execDetached(["rio", "-e", "bash", "-c", script + tail, "bash"].concat(args || []))
    }

    function refreshAll() {
        root.lastRefresh = Date.now()
        refreshUpdates()
        refreshCleanup()
        refreshServices()
        refreshErrors()
        refreshDisks()
    }

    function refreshUpdates() {
        if (root.updatesBusy) return
        root.updatesBusy = true
        root.repoDone = false
        root.aurDone = false
        repoProc.running = true
        aurProc.running = true
        osProc.running = true
    }
    function finishUpdates() {
        if (!root.repoDone || !root.aurDone) return
        root.updatesBusy = false
        root.lastChecked = Qt.formatDateTime(new Date(), "hh:mm")
    }
    function refreshCleanup() {
        if (root.cleanupBusy) return
        root.cleanupBusy = true
        cacheProc.running = true
        orphanProc.running = true
    }
    function refreshServices() {
        if (root.servicesBusy) return
        root.servicesBusy = true
        failedProc.running = true
    }
    function refreshErrors() {
        if (root.errorsBusy) return
        root.errorsBusy = true
        errorsProc.running = true
    }
    function refreshDisks() {
        dfProc.running = true
    }

    function parseUpdates(text, source) {
        const out = []
        for (const raw of text.split("\n")) {
            const line = raw.trim()
            if (line === "") continue
            const m = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
            if (m) out.push({ name: m[1], from: m[2], to: m[3], source: source })
        }
        return out
    }

    onVisibleChanged: {
        if (!visible) return
        if (root.lastRefresh === 0 || Date.now() - root.lastRefresh > 600000) refreshAll()
    }
    Component.onCompleted: if (visible) refreshAll()

    Process {
        id: repoProc
        command: ["sh", "-c", "checkupdates 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.repoUpdates = root.parseUpdates(text, "repo")
                root.repoDone = true
                root.finishUpdates()
            }
        }
    }
    Process {
        id: aurProc
        command: ["sh", "-c", "if command -v paru >/dev/null; then paru -Qua 2>/dev/null; elif command -v yay >/dev/null; then yay -Qua 2>/dev/null; fi; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.aurUpdates = root.parseUpdates(text, "aur")
                root.aurDone = true
                root.finishUpdates()
            }
        }
    }
    Process {
        id: cacheProc
        command: ["sh", "-c", "du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1; echo; du -sh \"$HOME/.cache\" 2>/dev/null | cut -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n")
                root.pkgCacheSize = (parts[0] || "").trim() || "—"
                root.userCacheSize = (parts[2] || parts[1] || "").trim() || "—"
                root.cleanupBusy = orphanProc.running
            }
        }
    }
    Process {
        id: orphanProc
        command: ["sh", "-c", "pacman -Qdtq 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.orphans = text.split("\n").map(l => l.trim()).filter(l => l !== "")
                root.cleanupBusy = cacheProc.running
            }
        }
    }
    Process {
        id: failedProc
        command: ["sh", "-c", "systemctl --failed --no-legend --plain 2>/dev/null | awk '{print \"system\\t\" $1 \"\\t\" $4}'; systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print \"user\\t\" $1 \"\\t\" $4}'; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const raw of text.split("\n")) {
                    const f = raw.split("\t")
                    if (f.length >= 2 && f[1] !== "") out.push({ scope: f[0], unit: f[1], sub: f[2] || "failed" })
                }
                root.failedUnits = out
                root.servicesBusy = false
            }
        }
    }
    Process {
        id: errorsProc
        command: ["sh", "-c", "journalctl -p 3 -b -n 40 --no-pager -o short-iso 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const raw of text.split("\n")) {
                    const line = raw.trim()
                    if (line === "" || line.startsWith("--")) continue
                    const m = line.match(/^(\S+)\s+(\S+)\s+([^:]+):\s?(.*)$/)
                    if (m) {
                        const t = m[1].match(/T(\d\d:\d\d:\d\d)/)
                        out.push({ time: t ? t[1] : m[1], source: m[3].replace(/\[\d+\]$/, ""), message: m[4], raw: line })
                    } else {
                        out.push({ time: "", source: "", message: line, raw: line })
                    }
                }
                root.errorLines = out.reverse()
                root.errorsBusy = false
            }
        }
    }
    Process {
        id: dfProc
        command: ["sh", "-c", "df -h --output=target,size,used,avail,pcent / \"$HOME\" 2>/dev/null | tail -n +2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                const out = []
                for (const raw of text.split("\n")) {
                    const f = raw.trim().split(/\s+/)
                    if (f.length < 5 || seen[f[0]]) continue
                    seen[f[0]] = true
                    out.push({ target: f[0], size: f[1], used: f[2], avail: f[3], pct: parseInt(f[4]) || 0 })
                }
                root.disks = out
            }
        }
    }
    Process {
        id: bigProc
        command: ["sh", "-c", "du -xh --max-depth=1 \"$HOME\" 2>/dev/null | sort -h | grep -v -x \"[^\t]*\t$HOME\" | tail -8 | sort -rh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const raw of text.split("\n")) {
                    const f = raw.split("\t")
                    if (f.length === 2 && f[1] !== "") out.push({ size: f[0], path: f[1], name: f[1].split("/").pop() })
                }
                root.bigFolders = out
                root.bigBusy = false
            }
        }
    }

    component Spinner: Text {
        property bool running: false
        visible: running
        text: "󰑐"
        color: Theme.active
        font.pixelSize: Math.round(13 * root.localScale)
        RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: parent.running }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon: ""
        property string tip: ""
        property bool enabledState: true
        property bool danger: false
        signal activated()
        width: Math.round(24 * root.localScale)
        height: width
        radius: Math.round(6 * root.localScale)
        color: ibHov.hovered && enabledState
            ? Qt.rgba(danger ? Theme.error.r : Theme.active.r, danger ? Theme.error.g : Theme.active.g, danger ? Theme.error.b : Theme.active.b, 0.16)
            : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)
        opacity: enabledState ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: Anim.color } }
        Text {
            anchors.centerIn: parent
            text: ib.icon
            font.pixelSize: Math.round(12 * root.localScale)
            color: ibHov.hovered && ib.enabledState ? (ib.danger ? Theme.error : Theme.active) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.6)
        }
        HoverHandler { id: ibHov; cursorShape: ib.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor }
        MouseArea { anchors.fill: parent; onClicked: if (ib.enabledState) ib.activated() }
        Tip { text: ib.tip; localScale: root.localScale }
    }

    component TextButton: Rectangle {
        id: tb
        property string label: ""
        property string icon: ""
        property bool enabledState: true
        property bool primary: false
        signal activated()
        height: Math.round(26 * root.localScale)
        width: tbRow.implicitWidth + Math.round(18 * root.localScale)
        radius: Math.round(7 * root.localScale)
        color: primary
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, tbHov.hovered && enabledState ? 0.30 : 0.18)
            : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, tbHov.hovered && enabledState ? 0.10 : 0.05)
        border.width: 1
        border.color: primary ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35) : Theme.border
        opacity: enabledState ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: Anim.color } }
        Row {
            id: tbRow
            anchors.centerIn: parent
            spacing: Math.round(5 * root.localScale)
            Text {
                visible: tb.icon !== ""
                text: tb.icon
                font.pixelSize: Math.round(12 * root.localScale)
                color: tb.primary ? Theme.active : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: tb.label
                font.pixelSize: Math.round(11 * root.localScale)
                font.weight: Font.Medium
                color: tb.primary ? Theme.active : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        HoverHandler { id: tbHov; cursorShape: tb.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor }
        MouseArea { anchors.fill: parent; onClicked: if (tb.enabledState) tb.activated() }
    }

    component Panel: StatCard {
        id: panel
        property string title: ""
        property string badge: ""
        property color badgeColor: Theme.active
        property bool busy: false
        default property alias body: bodyItem.data
        property alias actions: actionRow.data
        localScale: root.localScale
        padding: Math.round(10 * root.localScale)

        Item {
            id: head
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: Math.round(24 * root.localScale)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * root.localScale)
                Text {
                    text: panel.title
                    font.pixelSize: Math.round(11 * root.localScale)
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    visible: panel.badge !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.round(16 * root.localScale)
                    width: badgeText.implicitWidth + Math.round(10 * root.localScale)
                    radius: height / 2
                    color: Qt.rgba(panel.badgeColor.r, panel.badgeColor.g, panel.badgeColor.b, 0.18)
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: panel.badge
                        font.pixelSize: Math.round(10 * root.localScale)
                        font.bold: true
                        color: panel.badgeColor
                    }
                }
                Spinner { running: panel.busy; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                id: actionRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(4 * root.localScale)
            }
        }
        Item {
            id: bodyItem
            anchors { top: head.bottom; topMargin: Math.round(6 * root.localScale); left: parent.left; right: parent.right; bottom: parent.bottom }
        }
    }

    component EmptyState: Column {
        property string icon: ""
        property string label: ""
        property color tint: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)
        anchors.centerIn: parent
        spacing: Math.round(4 * root.localScale)
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.icon; font.pixelSize: Math.round(24 * root.localScale); color: parent.tint }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.label; font.pixelSize: Math.round(11 * root.localScale); color: parent.tint }
    }

    component ThinScroll: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: Math.round(3 * root.localScale)
            radius: width / 2
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
        }
        background: Item {}
    }

    Row {
        anchors {
            fill: parent
            topMargin: Math.round(8 * root.localScale)
            bottomMargin: Math.round(8 * root.localScale)
        }
        spacing: root.gap

        Panel {
            id: updatesPanel
            width: root.colW
            height: parent.height
            title: "UPDATES"
            busy: root.updatesBusy
            readonly property int total: root.repoUpdates.length + root.aurUpdates.length
            badge: root.updatesBusy && root.lastChecked === "" ? "" : String(total)
            badgeColor: total > 0 ? Theme.active : Theme.netUpload
            actions: [
                IconButton {
                    icon: "󰑐"
                    tip: root.updatesBusy ? "Checking…" : "Check for updates"
                    enabledState: !root.updatesBusy
                    onActivated: root.refreshUpdates()
                }
            ]

            Item {
                anchors.fill: parent

                Item {
                    id: osRow
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: Math.round(26 * root.localScale)

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ArchangelOS v" + (root.osVersion || "?") + (root.osUpdate ? "  →  v" + root.osRemote : "")
                        font.pixelSize: Math.round(12 * root.localScale)
                        font.bold: true
                        color: root.osUpdate ? Theme.active : Theme.text
                    }

                    Rectangle {
                        id: osBtn
                        visible: root.osUpdate
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: osBtnText.implicitWidth + Math.round(16 * root.localScale)
                        height: Math.round(22 * root.localScale)
                        radius: height / 2
                        color: osBtnMa.containsMouse ? Qt.lighter(Theme.active, 1.2) : Theme.active
                        Behavior on color { ColorAnimation { duration: Anim.color } }

                        Text {
                            id: osBtnText
                            anchors.centerIn: parent
                            text: "Update"
                            font.pixelSize: Math.round(11 * root.localScale)
                            font.bold: true
                            color: Theme.background
                        }

                        MouseArea {
                            id: osBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.inTerminal("pkexec archangelos-update update")
                        }
                    }
                }

                Row {
                    id: updSummary
                    anchors { top: osRow.bottom; left: parent.left; right: parent.right }
                    height: Math.round(20 * root.localScale)
                    spacing: Math.round(10 * root.localScale)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Repo " + root.repoUpdates.length
                        font.pixelSize: Math.round(11 * root.localScale)
                        color: Theme.subtext
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "AUR " + root.aurUpdates.length
                        font.pixelSize: Math.round(11 * root.localScale)
                        color: Theme.subtext
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.lastChecked !== "" ? "checked " + root.lastChecked : ""
                        font.pixelSize: Math.round(10 * root.localScale)
                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)
                    }
                }

                ListView {
                    id: updList
                    anchors { top: updSummary.bottom; topMargin: Math.round(4 * root.localScale); left: parent.left; right: parent.right; bottom: updFooter.top; bottomMargin: Math.round(6 * root.localScale) }
                    clip: true
                    spacing: Math.round(2 * root.localScale)
                    model: root.repoUpdates.concat(root.aurUpdates)
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ThinScroll {}
                    delegate: Item {
                        required property var modelData
                        width: updList.width - Math.round(6 * root.localScale)
                        height: Math.round(30 * root.localScale)
                        Rectangle {
                            id: srcBadge
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(30 * root.localScale)
                            height: Math.round(15 * root.localScale)
                            radius: height / 2
                            readonly property color tint: modelData.source === "aur" ? Theme.netDownload : Theme.active
                            color: Qt.rgba(tint.r, tint.g, tint.b, 0.16)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.source === "aur" ? "AUR" : "REPO"
                                font.pixelSize: Math.round(8 * root.localScale)
                                font.bold: true
                                color: srcBadge.tint
                            }
                        }
                        Column {
                            anchors { left: srcBadge.right; leftMargin: Math.round(7 * root.localScale); right: parent.right; verticalCenter: parent.verticalCenter }
                            Text {
                                width: parent.width
                                text: modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: Math.round(11 * root.localScale)
                                font.weight: Font.Medium
                                color: Theme.text
                            }
                            Text {
                                width: parent.width
                                text: modelData.from + "  →  " + modelData.to
                                elide: Text.ElideMiddle
                                font.pixelSize: Math.round(9 * root.localScale)
                                font.family: "JetBrains Mono"
                                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
                            }
                        }
                    }

                    EmptyState {
                        visible: !root.updatesBusy && updList.count === 0
                        icon: "󰄬"
                        label: root.lastChecked === "" ? "Not checked yet" : "System is up to date"
                        tint: root.lastChecked === "" ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35) : Theme.netUpload
                    }
                    EmptyState {
                        visible: root.updatesBusy && updList.count === 0
                        icon: "󰑐"
                        label: "Checking repositories…"
                    }
                }

                Row {
                    id: updFooter
                    anchors { bottom: parent.bottom; right: parent.right }
                    spacing: Math.round(6 * root.localScale)
                    TextButton {
                        icon: "󰚰"
                        label: "Update all"
                        primary: true
                        enabledState: !root.updatesBusy
                        onActivated: root.inTerminal("if command -v paru >/dev/null; then paru -Syu; elif command -v yay >/dev/null; then yay -Syu; else sudo pacman -Syu; fi")
                    }
                }
            }
        }

        Column {
            width: root.colW
            height: parent.height
            spacing: root.gap

            Panel {
                width: parent.width
                height: Math.round((parent.height - root.gap) * 0.52)
                title: "CLEANUP"
                busy: root.cleanupBusy
                actions: [
                    IconButton {
                        icon: "󰑐"
                        tip: "Recalculate sizes"
                        enabledState: !root.cleanupBusy
                        onActivated: root.refreshCleanup()
                    }
                ]

                Column {
                    anchors.fill: parent
                    spacing: Math.round(6 * root.localScale)

                    component CleanRow: Item {
                        id: cr
                        property string label: ""
                        property string value: ""
                        property string buttonLabel: ""
                        property string buttonIcon: ""
                        property bool buttonEnabled: true
                        signal clicked()
                        width: parent.width
                        height: Math.round(28 * root.localScale)
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: cr.label
                                font.pixelSize: Math.round(10 * root.localScale)
                                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.5)
                            }
                            Text {
                                text: cr.value
                                font.pixelSize: Math.round(13 * root.localScale)
                                font.bold: true
                                color: Theme.text
                            }
                        }
                        TextButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            icon: cr.buttonIcon
                            label: cr.buttonLabel
                            enabledState: cr.buttonEnabled
                            onActivated: cr.clicked()
                        }
                    }

                    CleanRow {
                        label: "Package cache"
                        value: root.pkgCacheSize || "…"
                        buttonIcon: "󰃢"
                        buttonLabel: "Trim cache"
                        onClicked: root.inTerminal("sudo paccache -rk2")
                    }
                    CleanRow {
                        label: "Orphaned packages"
                        value: root.cleanupBusy && root.orphans.length === 0 ? "…" : (root.orphans.length === 0 ? "None" : root.orphans.length + (root.orphans.length === 1 ? " package" : " packages"))
                        buttonIcon: "󰆴"
                        buttonLabel: "Remove"
                        buttonEnabled: root.orphans.length > 0
                        onClicked: root.inTerminal("sudo pacman -Rns $(pacman -Qdtq)")
                    }
                    CleanRow {
                        label: "User cache (~/.cache)"
                        value: root.userCacheSize || "…"
                        buttonIcon: "󰉋"
                        buttonLabel: "Open"
                        onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.cache"])
                    }
                }
            }

            Panel {
                width: parent.width
                height: parent.height - root.gap - Math.round((parent.height - root.gap) * 0.52)
                title: "DISK USAGE"
                busy: root.bigBusy
                actions: [
                    IconButton {
                        icon: "󰍉"
                        tip: root.bigBusy ? "Scanning…" : "Find big folders in home"
                        enabledState: !root.bigBusy
                        onActivated: { root.bigBusy = true; bigProc.running = true }
                    }
                ]

                Item {
                    anchors.fill: parent

                    Column {
                        id: diskCol
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        spacing: Math.round(6 * root.localScale)
                        Repeater {
                            model: root.disks
                            delegate: Column {
                                required property var modelData
                                width: diskCol.width
                                spacing: Math.round(3 * root.localScale)
                                Item {
                                    width: parent.width
                                    height: Math.round(14 * root.localScale)
                                    Text {
                                        anchors.left: parent.left
                                        text: modelData.target === "/" ? "Root  /" : modelData.target
                                        font.pixelSize: Math.round(11 * root.localScale)
                                        font.weight: Font.Medium
                                        color: Theme.text
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: modelData.used + " / " + modelData.size + "  ·  " + modelData.avail + " free"
                                        font.pixelSize: Math.round(10 * root.localScale)
                                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.5)
                                    }
                                }
                                Rectangle {
                                    width: parent.width
                                    height: Math.round(5 * root.localScale)
                                    radius: height / 2
                                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                                    Rectangle {
                                        width: parent.width * Math.min(1, modelData.pct / 100)
                                        height: parent.height
                                        radius: height / 2
                                        color: modelData.pct >= 90 ? Theme.error : Theme.active
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: bigList
                        anchors { top: diskCol.bottom; topMargin: Math.round(8 * root.localScale); left: parent.left; right: parent.right; bottom: parent.bottom }
                        clip: true
                        model: root.bigFolders
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ThinScroll {}
                        delegate: Item {
                            required property var modelData
                            width: bigList.width - Math.round(6 * root.localScale)
                            height: Math.round(24 * root.localScale)
                            Text {
                                id: bigSize
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(44 * root.localScale)
                                text: modelData.size
                                font.pixelSize: Math.round(10 * root.localScale)
                                font.family: "JetBrains Mono"
                                font.bold: true
                                color: Theme.active
                            }
                            Text {
                                anchors { left: bigSize.right; right: openBig.left; rightMargin: Math.round(4 * root.localScale); verticalCenter: parent.verticalCenter }
                                text: modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: Math.round(11 * root.localScale)
                                color: Theme.text
                            }
                            IconButton {
                                id: openBig
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "󰉋"
                                tip: "Open folder"
                                onActivated: Quickshell.execDetached(["xdg-open", modelData.path])
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: bigList.count === 0
                            text: root.bigBusy ? "Scanning home folder…" : "Use 󰍉 to find the biggest folders"
                            font.pixelSize: Math.round(10 * root.localScale)
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)
                        }
                    }
                }
            }
        }

        Column {
            width: root.colW
            height: parent.height
            spacing: root.gap

            Panel {
                width: parent.width
                height: Math.round((parent.height - root.gap) * 0.42)
                title: "SERVICES"
                busy: root.servicesBusy
                badge: root.failedUnits.length > 0 ? root.failedUnits.length + " failed" : ""
                badgeColor: Theme.error
                actions: [
                    IconButton {
                        icon: "󰑐"
                        tip: "Recheck services"
                        enabledState: !root.servicesBusy
                        onActivated: root.refreshServices()
                    }
                ]

                ListView {
                    id: unitList
                    anchors.fill: parent
                    clip: true
                    model: root.failedUnits
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ThinScroll {}
                    delegate: Item {
                        required property var modelData
                        width: unitList.width - Math.round(6 * root.localScale)
                        height: Math.round(30 * root.localScale)
                        Rectangle {
                            id: dot
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(7 * root.localScale)
                            height: width
                            radius: width / 2
                            color: Theme.error
                        }
                        Column {
                            anchors { left: dot.right; leftMargin: Math.round(7 * root.localScale); right: unitBtns.left; rightMargin: Math.round(4 * root.localScale); verticalCenter: parent.verticalCenter }
                            Text {
                                width: parent.width
                                text: modelData.unit
                                elide: Text.ElideRight
                                font.pixelSize: Math.round(11 * root.localScale)
                                font.weight: Font.Medium
                                color: Theme.text
                            }
                            Text {
                                text: modelData.scope + " · " + modelData.sub
                                font.pixelSize: Math.round(9 * root.localScale)
                                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
                            }
                        }
                        Row {
                            id: unitBtns
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.round(4 * root.localScale)
                            IconButton {
                                icon: "󰈙"
                                tip: "View log"
                                onActivated: root.inTerminal(
                                    modelData.scope === "user" ? "journalctl --user -u \"$1\" -b -n 100 --no-pager | less" : "journalctl -u \"$1\" -b -n 100 --no-pager | less",
                                    [modelData.unit])
                            }
                            IconButton {
                                icon: "󰜉"
                                tip: "Restart service"
                                danger: true
                                onActivated: root.inTerminal(
                                    modelData.scope === "user" ? "systemctl --user restart \"$1\" && systemctl --user status \"$1\" --no-pager" : "sudo systemctl restart \"$1\" && systemctl status \"$1\" --no-pager",
                                    [modelData.unit])
                            }
                        }
                    }

                    EmptyState {
                        visible: !root.servicesBusy && unitList.count === 0
                        icon: "󰗠"
                        label: "All services healthy"
                        tint: Theme.netUpload
                    }
                }
            }

            Panel {
                width: parent.width
                height: parent.height - root.gap - Math.round((parent.height - root.gap) * 0.42)
                title: "RECENT ERRORS"
                busy: root.errorsBusy
                badge: root.errorLines.length > 0 ? String(root.errorLines.length) : ""
                badgeColor: Theme.error
                actions: [
                    IconButton {
                        icon: "󰑐"
                        tip: "Reload errors"
                        enabledState: !root.errorsBusy
                        onActivated: root.refreshErrors()
                    }
                ]

                ListView {
                    id: errList
                    anchors.fill: parent
                    clip: true
                    model: root.errorLines
                    spacing: Math.round(2 * root.localScale)
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ThinScroll {}
                    delegate: Item {
                        id: errRow
                        required property var modelData
                        property bool copied: false
                        width: errList.width - Math.round(6 * root.localScale)
                        height: Math.round(32 * root.localScale)
                        Column {
                            anchors { left: parent.left; right: copyBtn.left; rightMargin: Math.round(4 * root.localScale); verticalCenter: parent.verticalCenter }
                            Row {
                                spacing: Math.round(6 * root.localScale)
                                Text {
                                    text: errRow.modelData.time
                                    font.pixelSize: Math.round(9 * root.localScale)
                                    font.family: "JetBrains Mono"
                                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
                                }
                                Text {
                                    text: errRow.modelData.source
                                    font.pixelSize: Math.round(9 * root.localScale)
                                    font.bold: true
                                    color: Theme.error
                                }
                            }
                            Text {
                                width: parent.width
                                text: errRow.modelData.message
                                elide: Text.ElideRight
                                font.pixelSize: Math.round(10 * root.localScale)
                                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.75)
                            }
                        }
                        IconButton {
                            id: copyBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            icon: errRow.copied ? "󰄬" : "󰆏"
                            tip: errRow.copied ? "Copied" : "Copy line"
                            onActivated: {
                                Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", errRow.modelData.raw])
                                errRow.copied = true
                                copiedReset.restart()
                            }
                        }
                        Timer { id: copiedReset; interval: 1500; onTriggered: errRow.copied = false }
                    }

                    EmptyState {
                        visible: !root.errorsBusy && errList.count === 0
                        icon: "󰗠"
                        label: "No errors this boot"
                        tint: Theme.netUpload
                    }
                }
            }
        }
    }
}
