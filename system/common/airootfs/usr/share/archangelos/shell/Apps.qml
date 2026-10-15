pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// App catalogue for the launcher.
//  - categories come from the edition's curated menu.json
//  - icons are borrowed from matching .desktop entries when installed
//  - items whose binary is missing install on launch via archangelos-install-tool
//  - launches are counted so the "Recent" rail ranks what you actually use
Singleton {
    id: apps

    readonly property string menuPath: "/usr/share/archangelos/launcher/menu.json"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/archangelos"

    property string edition: "ArchangelOS"
    property var categories: []
    property var installed: ({})
    property var usage: ({})

    readonly property var allItems: {
        const seen = {}, out = []
        for (const c of categories)
            for (const it of c.items)
                if (!seen[it.name]) { seen[it.name] = true; out.push(it) }
        return out
    }

    readonly property var recent: allItems
        .filter(it => usage[it.name])
        .sort((a, b) => score(b) - score(a))
        .slice(0, 12)

    // What the category rail shows: recent launches first, then the menu.
    readonly property var rail: recent.length
        ? [{ name: "Recent", items: recent }].concat(categories)
        : categories

    function binOf(item) { return item.exec.split(" ")[0] }
    function isInstalled(item) { return installed[binOf(item)] === true }

    function score(item) {
        const u = usage[item.name]
        if (!u) return 0
        const ageH = (Date.now() - u.last) / 3600000
        const recency = ageH < 4 ? 4 : ageH < 24 ? 3 : ageH < 168 ? 2 : 1
        return u.count * recency
    }

    function search(query) {
        const q = query.trim().toLowerCase()
        if (!q) return []
        return allItems
            .map(it => {
                const n = it.name.toLowerCase()
                const rank = n.startsWith(q) ? 3 : n.includes(" " + q) ? 2 : n.includes(q) ? 1
                    : binOf(it).toLowerCase().includes(q) ? 0.5 : 0
                return { it: it, rank: rank + score(it) / 100 }
            })
            .filter(r => r.rank > 0)
            .sort((a, b) => b.rank - a.rank)
            .map(r => r.it)
    }

    function iconFor(item) {
        const bin = binOf(item)
        const entry = DesktopEntries.applications.values.find(e => {
            const cmd = (e.command && e.command.length) ? e.command[0] : (e.execString || "").split(" ")[0]
            return cmd.split("/").pop() === bin
        })
        return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
    }

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    // Runs the command inside the first terminal found.
    function inTerminal(script) {
        return ["sh", "-c",
            'for t in rio kitty foot alacritty konsole xterm; do command -v "$t" >/dev/null 2>&1 && exec "$t" -e bash -lc "$1"; done',
            "sh", script]
    }

    function launch(item) {
        const bin = binOf(item)
        if (isInstalled(item)) {
            Quickshell.execDetached(item.terminal ? inTerminal(item.exec) : ["sh", "-c", item.exec])
        } else {
            const after = item.terminal ? item.exec : "setsid " + item.exec + " >/dev/null 2>&1 &"
            Quickshell.execDetached(inTerminal(
                "archangelos-install-tool " + shq(item.pkg || bin)
                + "; if command -v " + shq(bin) + " >/dev/null 2>&1; then " + after
                + "; else echo; read -rp 'Install failed. Press Enter to close...'; fi"))
        }
        const u = usage[item.name] || { count: 0, last: 0 }
        const next = Object.assign({}, usage)
        next[item.name] = { count: u.count + 1, last: Date.now() }
        usage = next
        usageFile.setText(JSON.stringify(usage))
    }

    function refreshInstalled() { probe.running = true }

    function _ingest(raw) {
        let data
        try { data = JSON.parse(raw) } catch (e) { console.warn("menu.json:", e); return }
        edition = data.edition || edition
        categories = (data.categories || []).map(c => {
            const items = (c.items || []).slice()
            for (const s of (c.subcats || [])) items.push(...s.items)
            const seen = {}
            return {
                // menu.json names carry emoji; the shell's type is clean caps
                name: c.name.replace(/^[^A-Za-z0-9]+/, "").trim(),
                items: items.filter(it => !seen[it.name] && (seen[it.name] = true))
            }
        })
        refreshInstalled()
    }

    FileView {
        path: apps.menuPath
        onLoaded: apps._ingest(text())
    }

    FileView {
        id: usageFile
        path: apps.stateDir + "/launcher-usage.json"
        printErrors: false
        onLoaded: {
            try { apps.usage = JSON.parse(text()) } catch (e) { apps.usage = ({}) }
        }
    }

    Process {
        id: probe
        command: ["sh", "-c",
            'for b in "$@"; do command -v "$b" >/dev/null 2>&1 && echo "$b"; done', "sh"]
            .concat(apps.allItems.map(it => apps.binOf(it)))
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {}
                for (const b of text.split("\n")) if (b) found[b] = true
                apps.installed = found
            }
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", stateDir])
}
