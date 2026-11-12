import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../../components"
import "../../services"
import qs.arc.components as AC

Item {
    id: root

    property real localScale: 1.0

    readonly property string home: Quickshell.env("HOME")

    property bool dockerOk: true
    property bool dockerLoaded: false
    property var containers: []
    property var ports: []
    property bool reposLoaded: false
    property bool reposScanning: false
    property var repos: []
    property string status: ""

    function flash(msg) {
        root.status = msg
        statusClear.restart()
    }

    Timer { id: statusClear; interval: 5000; onTriggered: root.status = "" }

    function refreshFast() {
        if (!dockerProc.running) dockerProc.running = true
        if (!portsProc.running) portsProc.running = true
    }

    function rescanRepos() {
        if (repoProc.running) return
        root.reposScanning = true
        repoProc.running = true
    }

    onVisibleChanged: if (visible) { refreshFast(); rescanRepos() }

    Timer { interval: 4000; repeat: true; running: root.visible; onTriggered: root.refreshFast() }
    Timer { interval: 60000; repeat: true; running: root.visible; onTriggered: root.rescanRepos() }
    Timer { id: refreshSoon; interval: 900; onTriggered: root.refreshFast() }

    Process {
        id: dockerProc
        command: ["docker", "ps", "-a", "--format", "{{json .}}"]
        stdout: StdioCollector { id: dockerOut }
        onExited: function(code) {
            root.dockerLoaded = true
            root.dockerOk = code === 0
            if (code !== 0) { root.containers = []; return }
            var list = []
            var lines = dockerOut.text.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                if (l === "") continue
                try {
                    var o = JSON.parse(l)
                    list.push({
                        name: o.Names || o.ID,
                        image: o.Image || "",
                        running: (o.State || "") === "running",
                        status: o.Status || o.State || "",
                        ports: (o.Ports || "").replace(/0\.0\.0\.0:|\[::\]:|:::/g, "").split(", ").filter(function(p, idx, a) { return p !== "" && a.indexOf(p) === idx }).join(", ")
                    })
                } catch (e) {}
            }
            list.sort(function(a, b) { return (b.running - a.running) || (a.name < b.name ? -1 : 1) })
            root.containers = list
        }
    }

    Process {
        id: portsProc
        command: ["ss", "-ltnpH"]
        stdout: StdioCollector { id: portsOut }
        onExited: {
            var list = []
            var seen = {}
            var lines = portsOut.text.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var f = lines[i].trim().split(/\s+/)
                if (f.length < 4) continue
                var local = f[3]
                var cut = local.lastIndexOf(":")
                var addr = local.substring(0, cut).replace(/^\[|\]$/g, "")
                var port = parseInt(local.substring(cut + 1))
                var rest = f.slice(5).join(" ")
                var m = rest.match(/\(\("([^"]+)",pid=(\d+)/)
                var proc = m ? m[1] : ""
                var pid = m ? parseInt(m[2]) : 0
                var key = port + "|" + proc
                if (seen[key]) continue
                seen[key] = true
                list.push({ port: port, addr: addr, proc: proc, pid: pid,
                            local: addr === "127.0.0.1" || addr === "::1" || addr === "localhost" })
            }
            list.sort(function(a, b) { return ((b.pid > 0) - (a.pid > 0)) || (a.port - b.port) })
            root.ports = list
        }
    }

    Process {
        id: repoProc
        command: ["bash", "-c",
            "for d in \"$HOME/projects\" \"$HOME/Projects\" \"$HOME/dev\" \"$HOME/code\"; do " +
            "[ -d \"$d\" ] && find \"$d\" -maxdepth 3 -name .git -type d -prune 2>/dev/null; done | sort -u | " +
            "while read -r g; do r=\"${g%/.git}\"; " +
            "b=$(git -C \"$r\" rev-parse --abbrev-ref HEAD 2>/dev/null); " +
            "n=$(git -C \"$r\" status --porcelain 2>/dev/null | wc -l); " +
            "ab=$(git -C \"$r\" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null | tr '\\t' ' '); " +
            "t=$(git -C \"$r\" log -1 --format=%cr 2>/dev/null); " +
            "printf '%s|%s|%s|%s|%s\\n' \"$r\" \"$b\" \"$n\" \"$ab\" \"$t\"; done"]
        stdout: StdioCollector { id: repoOut }
        onExited: {
            var list = []
            var lines = repoOut.text.split("\n")
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].trim() === "") continue
                var f = lines[i].split("|")
                var ab = (f[3] || "").trim().split(" ")
                list.push({
                    path: f[0],
                    name: f[0].split("/").pop(),
                    branch: f[1] || "?",
                    dirty: parseInt(f[2]) || 0,
                    behind: ab.length === 2 ? parseInt(ab[0]) : -1,
                    ahead: ab.length === 2 ? parseInt(ab[1]) : -1,
                    when: f[4] || ""
                })
            }
            list.sort(function(a, b) { return (b.dirty > 0) - (a.dirty > 0) || (a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1) })
            root.repos = list
            root.reposLoaded = true
            root.reposScanning = false
        }
    }

    Process {
        id: actionProc
        property string label: ""
        stderr: StdioCollector { id: actionErr }
        onExited: function(code) {
            if (code !== 0) root.flash(actionProc.label + " failed: " + (actionErr.text.trim().split("\n").pop() || ("exit " + code)))
            else root.flash(actionProc.label + " done")
            refreshSoon.restart()
        }
    }

    function act(label, cmd) {
        if (actionProc.running) { root.flash("Busy, try again"); return }
        actionProc.label = label
        actionProc.command = cmd
        actionProc.running = true
    }

    Process {
        id: pullProc
        property string repo: ""
        stdout: StdioCollector { id: pullOut }
        stderr: StdioCollector { id: pullErr }
        onExited: function(code) {
            var msg = (code === 0 ? pullOut.text : pullErr.text).trim().split("\n").pop()
            root.flash(pullProc.repo + ": " + (code === 0 ? (msg || "Up to date") : ("pull failed: " + msg)))
            root.rescanRepos()
        }
    }

    function pull(repo) {
        if (pullProc.running) { root.flash("A pull is already running"); return }
        pullProc.repo = repo.name
        pullProc.command = ["git", "-C", repo.path, "pull", "--ff-only"]
        pullProc.running = true
        root.flash(repo.name + ": pulling…")
    }

    component Act: Item {
        id: act
        property string icon: ""
        property string tip: ""
        property bool danger: false
        property bool confirm: false
        property bool armed: false
        signal triggered()
        width: armed ? confirmLabel.implicitWidth + Math.round(14 * root.localScale) : Math.round(24 * root.localScale)
        height: Math.round(24 * root.localScale)
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: Math.round(6 * root.localScale)
            color: act.armed ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22)
                 : actHov.hovered ? (act.danger ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
                                               : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.16))
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        AC.MatIcon {
            anchors.centerIn: parent
            visible: !act.armed
            text: act.icon
            font.pixelSize: Math.round(15 * root.localScale)
            color: actHov.hovered ? (act.danger ? Theme.error : Theme.active) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.6)
        }
        Text {
            id: confirmLabel
            anchors.centerIn: parent
            visible: act.armed
            text: "Confirm?"
            color: Theme.error
            font.pixelSize: Math.round(10 * root.localScale)
            font.bold: true
        }
        Timer { id: disarm; interval: 3000; onTriggered: act.armed = false }
        HoverHandler { id: actHov; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (act.confirm && !act.armed) { act.armed = true; disarm.restart(); return }
                act.armed = false
                act.triggered()
            }
        }
        Tip { text: act.armed ? "" : act.tip; localScale: root.localScale }
    }

    component PanelHeader: Item {
        id: ph
        property string title: ""
        property string icon: ""
        property string count: ""
        default property alias actions: actRow.data
        width: parent.width
        height: Math.round(28 * root.localScale)
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(7 * root.localScale)
            AC.MatIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: ph.icon
                font.pixelSize: Math.round(16 * root.localScale)
                color: Theme.active
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ph.title
                color: Theme.text
                font.pixelSize: Math.round(13 * root.localScale)
                font.bold: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: ph.count !== ""
                text: ph.count
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
                font.pixelSize: Math.round(11 * root.localScale)
            }
        }
        Row {
            id: actRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * root.localScale)
        }
    }

    component Empty: Column {
        property string icon: ""
        property string title: ""
        property string sub: ""
        anchors.centerIn: parent
        spacing: Math.round(6 * root.localScale)
        AC.MatIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.icon
            font.pixelSize: Math.round(30 * root.localScale)
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.15)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.title
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
            font.pixelSize: Math.round(12 * root.localScale)
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            width: Math.min(implicitWidth, Math.round(220 * root.localScale))
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: parent.sub
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.28)
            font.pixelSize: Math.round(10 * root.localScale)
        }
    }

    component RowBg: Rectangle {
        property bool hot: false
        radius: Math.round(8 * root.localScale)
        color: hot ? Theme.cardHover : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.03)
        border.width: 1
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: columns
        anchors {
            fill: parent
            topMargin: Math.round(8 * root.localScale)
            bottomMargin: Math.round(8 * root.localScale)
        }
        spacing: Math.round(8 * root.localScale)

        StatCard {
            localScale: root.localScale
            width: (columns.width - columns.spacing * 2) * 0.35
            height: columns.height

            PanelHeader {
                id: dockerHead
                title: "Docker"
                icon: "deployed_code"
                count: root.dockerOk && root.dockerLoaded ? root.containers.filter(function(c) { return c.running }).length + "/" + root.containers.length + " running" : ""
                Act { icon: "refresh"; tip: "Refresh"; onTriggered: root.refreshFast() }
            }

            ListView {
                id: dockerList
                anchors { top: dockerHead.bottom; topMargin: Math.round(6 * root.localScale); left: parent.left; right: parent.right; bottom: parent.bottom }
                clip: true
                spacing: Math.round(5 * root.localScale)
                boundsBehavior: Flickable.StopAtBounds
                model: root.containers
                delegate: Item {
                    id: crow
                    required property var modelData
                    width: dockerList.width
                    height: Math.round(50 * root.localScale)
                    RowBg { anchors.fill: parent; hot: crowHov.hovered }
                    HoverHandler { id: crowHov }
                    Rectangle {
                        id: dot
                        x: Math.round(10 * root.localScale)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(7 * root.localScale); height: width; radius: width / 2
                        color: crow.modelData.running ? "#5fd38a" : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
                    }
                    Column {
                        anchors { left: dot.right; leftMargin: Math.round(9 * root.localScale); right: cacts.left; rightMargin: Math.round(6 * root.localScale); verticalCenter: parent.verticalCenter }
                        spacing: Math.round(2 * root.localScale)
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: crow.modelData.name
                            color: Theme.text; font.pixelSize: Math.round(12 * root.localScale); font.bold: true
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: crow.modelData.image + (crow.modelData.ports ? "  ·  " + crow.modelData.ports : "")
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45); font.pixelSize: Math.round(10 * root.localScale)
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: crow.modelData.status
                            color: crow.modelData.running ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.8) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.3)
                            font.pixelSize: Math.round(9 * root.localScale)
                        }
                    }
                    Row {
                        id: cacts
                        anchors { right: parent.right; rightMargin: Math.round(6 * root.localScale); verticalCenter: parent.verticalCenter }
                        spacing: Math.round(1 * root.localScale)
                        Act {
                            icon: crow.modelData.running ? "stop" : "play_arrow"
                            tip: crow.modelData.running ? "Stop container" : "Start container"
                            onTriggered: root.act((crow.modelData.running ? "Stop " : "Start ") + crow.modelData.name, ["docker", crow.modelData.running ? "stop" : "start", crow.modelData.name])
                        }
                        Act {
                            visible: crow.modelData.running
                            icon: "restart_alt"; tip: "Restart container"
                            onTriggered: root.act("Restart " + crow.modelData.name, ["docker", "restart", crow.modelData.name])
                        }
                        Act {
                            icon: "article"; tip: "Follow logs in terminal"
                            onTriggered: Quickshell.execDetached(["rio", "-e", "sh", "-c", "docker logs -f --tail 200 \"$0\"", crow.modelData.name])
                        }
                        Act {
                            visible: !crow.modelData.running
                            icon: "delete"; tip: "Remove container"; danger: true; confirm: true
                            onTriggered: root.act("Remove " + crow.modelData.name, ["docker", "rm", crow.modelData.name])
                        }
                    }
                }
                Empty {
                    visible: dockerList.count === 0 && root.dockerLoaded
                    icon: root.dockerOk ? "inventory_2" : "cloud_off"
                    title: root.dockerOk ? "No containers" : "Docker isn't reachable"
                    sub: root.dockerOk ? "Containers you create will show up here" : "Is the docker service running and are you in the docker group?"
                }
            }
        }

        StatCard {
            localScale: root.localScale
            width: (columns.width - columns.spacing * 2) * 0.28
            height: columns.height

            PanelHeader {
                id: portsHead
                title: "Ports"
                icon: "lan"
                count: root.ports.length > 0 ? root.ports.length + " listening" : ""
                Act { icon: "refresh"; tip: "Refresh"; onTriggered: root.refreshFast() }
            }

            ListView {
                id: portList
                anchors { top: portsHead.bottom; topMargin: Math.round(6 * root.localScale); left: parent.left; right: parent.right; bottom: parent.bottom }
                clip: true
                spacing: Math.round(4 * root.localScale)
                boundsBehavior: Flickable.StopAtBounds
                model: root.ports
                delegate: Item {
                    id: prow
                    required property var modelData
                    width: portList.width
                    height: Math.round(36 * root.localScale)
                    RowBg { anchors.fill: parent; hot: prowHov.hovered }
                    HoverHandler { id: prowHov }
                    Text {
                        id: portNum
                        x: Math.round(10 * root.localScale)
                        width: Math.round(46 * root.localScale)
                        anchors.verticalCenter: parent.verticalCenter
                        text: prow.modelData.port
                        color: Theme.active
                        font.pixelSize: Math.round(12 * root.localScale)
                        font.bold: true
                        font.family: "JetBrains Mono"
                    }
                    Column {
                        anchors { left: portNum.right; right: pacts.left; rightMargin: Math.round(4 * root.localScale); verticalCenter: parent.verticalCenter }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: prow.modelData.proc !== "" ? prow.modelData.proc : "system"
                            color: prow.modelData.proc !== "" ? Theme.text : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
                            font.pixelSize: Math.round(11 * root.localScale)
                            font.bold: prow.modelData.proc !== ""
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: (prow.modelData.local ? "local" : prow.modelData.addr) + (prow.modelData.pid > 0 ? "  ·  pid " + prow.modelData.pid : "")
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)
                            font.pixelSize: Math.round(9 * root.localScale)
                        }
                    }
                    Row {
                        id: pacts
                        anchors { right: parent.right; rightMargin: Math.round(5 * root.localScale); verticalCenter: parent.verticalCenter }
                        spacing: Math.round(1 * root.localScale)
                        Act {
                            visible: prow.modelData.pid > 0
                            icon: "open_in_new"; tip: "Open http://localhost:" + prow.modelData.port
                            onTriggered: Quickshell.execDetached(["xdg-open", "http://localhost:" + prow.modelData.port])
                        }
                        Act {
                            visible: prow.modelData.pid > 0
                            icon: "close"; tip: "Kill " + prow.modelData.proc + " (pid " + prow.modelData.pid + ")"; danger: true; confirm: true
                            onTriggered: root.act("Kill " + prow.modelData.proc, ["kill", String(prow.modelData.pid)])
                        }
                    }
                }
                Empty {
                    visible: portList.count === 0
                    icon: "lan"
                    title: "Nothing listening"
                    sub: "TCP servers you start will appear here"
                }
            }
        }

        StatCard {
            localScale: root.localScale
            width: (columns.width - columns.spacing * 2) * 0.37
            height: columns.height

            PanelHeader {
                id: gitHead
                title: "Repositories"
                icon: "commit"
                count: root.reposScanning ? "scanning…" : (root.repos.length > 0 ? root.repos.length + " repos" : "")
                Act { icon: "sync"; tip: "Rescan repositories"; onTriggered: root.rescanRepos() }
            }

            Text {
                id: statusLine
                anchors { top: gitHead.bottom; left: parent.left; right: parent.right }
                height: root.status !== "" ? implicitHeight + Math.round(4 * root.localScale) : 0
                visible: root.status !== ""
                elide: Text.ElideRight
                text: root.status
                color: Theme.active
                font.pixelSize: Math.round(10 * root.localScale)
                Behavior on height { NumberAnimation { duration: 140 } }
            }

            ListView {
                id: repoList
                anchors { top: statusLine.bottom; topMargin: Math.round(6 * root.localScale); left: parent.left; right: parent.right; bottom: parent.bottom }
                clip: true
                spacing: Math.round(5 * root.localScale)
                boundsBehavior: Flickable.StopAtBounds
                model: root.repos
                delegate: Item {
                    id: rrow
                    required property var modelData
                    width: repoList.width
                    height: Math.round(44 * root.localScale)
                    RowBg { anchors.fill: parent; hot: rrowHov.hovered }
                    HoverHandler { id: rrowHov }
                    Column {
                        anchors { left: parent.left; leftMargin: Math.round(10 * root.localScale); right: racts.left; rightMargin: Math.round(6 * root.localScale); verticalCenter: parent.verticalCenter }
                        spacing: Math.round(2 * root.localScale)
                        Row {
                            width: parent.width
                            spacing: Math.round(6 * root.localScale)
                            Text {
                                width: Math.min(implicitWidth, parent.width * 0.6); elide: Text.ElideRight
                                text: rrow.modelData.name
                                color: Theme.text; font.pixelSize: Math.round(12 * root.localScale); font.bold: true
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: Math.round(15 * root.localScale)
                                width: branchText.implicitWidth + Math.round(10 * root.localScale)
                                radius: height / 2
                                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                                Text {
                                    id: branchText
                                    anchors.centerIn: parent
                                    text: rrow.modelData.branch
                                    color: Theme.active
                                    font.pixelSize: Math.round(9 * root.localScale)
                                    font.bold: true
                                }
                            }
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: {
                                var r = rrow.modelData
                                var parts = []
                                parts.push(r.dirty > 0 ? r.dirty + " changed" : "clean")
                                if (r.ahead > 0) parts.push("↑" + r.ahead)
                                if (r.behind > 0) parts.push("↓" + r.behind)
                                if (r.ahead < 0) parts.push("no upstream")
                                if (r.when !== "") parts.push(r.when)
                                return parts.join("  ·  ")
                            }
                            color: rrow.modelData.dirty > 0 ? "#f5c47a" : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
                            font.pixelSize: Math.round(10 * root.localScale)
                        }
                    }
                    Row {
                        id: racts
                        anchors { right: parent.right; rightMargin: Math.round(5 * root.localScale); verticalCenter: parent.verticalCenter }
                        spacing: Math.round(1 * root.localScale)
                        Act {
                            icon: "code"; tip: "Open in VS Code"
                            onTriggered: Quickshell.execDetached(["code", rrow.modelData.path])
                        }
                        Act {
                            icon: "terminal"; tip: "Open terminal here"
                            onTriggered: Quickshell.execDetached(["rio", "--working-dir", rrow.modelData.path])
                        }
                        Act {
                            visible: rrow.modelData.ahead >= 0
                            icon: "download"; tip: rrow.modelData.behind > 0 ? "Pull " + rrow.modelData.behind + " commit(s)" : "Pull (fast-forward)"
                            onTriggered: root.pull(rrow.modelData)
                        }
                    }
                }
                Empty {
                    visible: repoList.count === 0 && root.reposLoaded
                    icon: "folder_off"
                    title: "No repositories found"
                    sub: "Looked in ~/projects, ~/Projects, ~/dev and ~/code"
                }
            }
        }
    }
}
