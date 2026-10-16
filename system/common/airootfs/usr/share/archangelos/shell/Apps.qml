pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Data side of the ArchangelOS launcher, ported from /usr/bin/archangelos-launcher:
// the edition's menu.json, category + subcategory rows, search across every
// item, and launch-or-install for each app.
Singleton {
    id: apps

    readonly property string menuPath: "/usr/share/archangelos/launcher/menu.json"

    property string edition: "ArchangelOS"
    property var categories: []
    property var installed: ({})

    // One row per category, followed by its subcategories, as in the sidebar.
    readonly property var rows: {
        const out = []
        categories.forEach((cat, ci) => {
            out.push({ kind: "cat", ci: ci, si: -1, label: ((cat.icon || "") + "  " + cat.name).trim() })
            ;(cat.subcats || []).forEach((sub, si) =>
                out.push({ kind: "sub", ci: ci, si: si, label: sub.name }))
        })
        return out
    }

    function itemsFor(row) {
        if (!row) return []
        const cat = categories[row.ci]
        if (row.kind === "sub") return cat.subcats[row.si].items
        let items = (cat.items || []).slice()
        for (const s of (cat.subcats || [])) items = items.concat(s.items)
        return items
    }

    function titleFor(row) {
        if (!row) return ""
        const cat = categories[row.ci]
        return row.kind === "sub" ? cat.name + " · " + cat.subcats[row.si].name : cat.name
    }

    function search(text) {
        const q = text.trim().toLowerCase()
        const seen = {}, res = []
        for (const cat of categories) {
            let items = cat.items || []
            for (const s of (cat.subcats || [])) items = items.concat(s.items)
            for (const it of items)
                if (it.name.toLowerCase().includes(q) && !seen[it.name]) {
                    seen[it.name] = true
                    res.push(it)
                }
        }
        return res
    }

    function binOf(item) { return item.exec.split(" ")[0] }
    function isInstalled(item) { return installed[binOf(item)] === true }

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    // Same terminal preference as the Python launcher.
    function inTerminal(args) {
        return ["sh", "-c",
            'for t in rio konsole alacritty foot kitty wezterm xterm; do command -v "$t" >/dev/null 2>&1 && exec "$t" -e "$@"; done',
            "sh"].concat(args)
    }

    function launch(item) {
        const exe = item.exec
        const bin = binOf(item)
        if (!isInstalled(item)) {
            const after = item.terminal ? exe : "setsid " + exe + " >/dev/null 2>&1 &"
            const script = "archangelos-install-tool " + shq(item.pkg || bin)
                + "; if command -v " + shq(bin) + " >/dev/null 2>&1; then " + after
                + "; else echo; read -rp 'Install failed. Press Enter to close...'; fi"
            Quickshell.execDetached(inTerminal(["bash", "-lc", script]))
        } else if (item.terminal) {
            Quickshell.execDetached(inTerminal([exe]))
        } else {
            Quickshell.execDetached(["sh", "-c", exe])
        }
    }

    function refreshInstalled() { probe.running = true }

    FileView {
        path: apps.menuPath
        onLoaded: {
            try {
                const data = JSON.parse(text())
                apps.edition = data.edition || apps.edition
                apps.categories = data.categories || []
                apps.refreshInstalled()
            } catch (e) {
                console.warn("menu.json:", e)
            }
        }
    }

    Process {
        id: probe
        command: {
            const bins = []
            for (const cat of apps.categories) {
                let items = cat.items || []
                for (const s of (cat.subcats || [])) items = items.concat(s.items)
                for (const it of items) bins.push(apps.binOf(it))
            }
            return ["sh", "-c", 'for b in "$@"; do command -v "$b" >/dev/null 2>&1 && echo "$b"; done', "sh"].concat(bins)
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {}
                for (const b of text.split("\n")) if (b) found[b] = true
                apps.installed = found
            }
        }
    }
}
