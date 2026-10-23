// Developer tools — the bits a developer sets once: the login shell, the default editor, your git
// identity, which toolchains are installed, and session environment variables. Git and the editor
// are your own files; changing the login shell asks for your password.
import QtQuick
import Quickshell
import qs.axs
import qs.axs.ui

PageScaffold {
    id: page
    property var meta
    group: "Developer"
    title: "Developer tools"
    desc: "Shell, editor, git identity, toolchains and environment."

    readonly property string admin: "/usr/lib/archangelos/axs-admin"
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string me: Quickshell.env("USER") || ""
    property var shells: []
    property string shell: ""
    property string editor: ""
    property string gitName: ""
    property string gitEmail: ""
    property string gitBranch: ""
    property var tools: []             // { k, name, version }
    property var envVars: []           // { key, value }
    property bool loaded: false
    property string busy: ""
    property string error: ""
    property string notice: ""

    Cmd { id: cmd }
    Cmd { id: act }

    readonly property var toolProbe: [
        { k: "git", name: "Git", cmd: "git --version" }, { k: "gcc", name: "GCC", cmd: "gcc -dumpversion" },
        { k: "clang", name: "Clang", cmd: "clang --version" }, { k: "python", name: "Python", cmd: "python --version" },
        { k: "node", name: "Node.js", cmd: "node --version" }, { k: "rustc", name: "Rust", cmd: "rustc --version" },
        { k: "go", name: "Go", cmd: "go version" }, { k: "docker", name: "Docker", cmd: "docker --version" },
        { k: "cargo", name: "Cargo", cmd: "cargo --version" }, { k: "make", name: "Make", cmd: "make --version" }
    ]
    function load() {
        cmd.sh('echo "--shells"; grep -vE "^#|nologin|false" /etc/shells 2>/dev/null | sort -u; '
             + 'echo "cur=$(getent passwd "$USER" | cut -d: -f7)"; '
             + 'echo "editor=$(cat "$HOME/.config/environment.d/90-editor.conf" 2>/dev/null | sed -n "s/^EDITOR=//p" | head -n1)"; '
             + 'echo "gitName=$(git config --global user.name 2>/dev/null)"; echo "gitEmail=$(git config --global user.email 2>/dev/null)"; '
             + 'echo "gitBranch=$(git config --global init.defaultBranch 2>/dev/null)"; '
             + 'echo "--tools"; for t in "$@"; do c="${t%% *}"; if command -v "$c" >/dev/null 2>&1; then printf "%s\\t" "$c"; $t 2>&1 | head -n1; else echo "$c\\t"; fi; done; '
             + 'echo "--env"; cat "$HOME/.config/environment.d/50-archangelos.conf" 2>/dev/null',
             page.toolProbe.map(t => t.cmd), (c, o) => {
            const sec = (a, b) => { const i = o.indexOf(a), j = b ? o.indexOf(b) : o.length; return i < 0 ? "" : o.slice(i + a.length, j < 0 ? o.length : j); };
            page.shells = sec("--shells", "--tools").split("\n").filter(l => l.startsWith("/"));
            for (const l of sec("--shells", "--tools").split("\n")) { const i = l.indexOf("="); if (i > 0) { const k = l.slice(0, i), v = l.slice(i + 1); if (k === "cur") page.shell = v; if (k === "editor") page.editor = v; if (k === "gitName") page.gitName = v; if (k === "gitEmail") page.gitEmail = v; if (k === "gitBranch") page.gitBranch = v; } }
            page.tools = sec("--tools", "--env").split("\n").filter(l => l.includes("\t")).map(l => { const f = l.split("\t"); const t = page.toolProbe.find(x => x.k === f[0] || x.cmd.startsWith(f[0])); return { k: f[0], name: t ? t.name : f[0], version: (f[1] || "").trim() }; });
            page.envVars = sec("--env").split("\n").filter(l => /^[A-Za-z_][A-Za-z0-9_]*=/.test(l)).map(l => { const i = l.indexOf("="); return { key: l.slice(0, i), value: l.slice(i + 1) }; });
            page.loaded = true;
        });
    }
    Component.onCompleted: load()

    function note(t) { page.notice = t; noticeT.restart(); }
    Timer { id: noticeT; interval: 4000; onTriggered: page.notice = "" }

    function setEditor(e) {
        page.editor = e;
        cmd.sh('mkdir -p "$HOME/.config/environment.d" && printf "EDITOR=%s\\nVISUAL=%s\\n" "$1" "$1" > "$HOME/.config/environment.d/90-editor.conf"', [e], () => page.note("Default editor set — new terminals will use it."));
    }
    function setGit(key, val) {
        cmd.sh('git config --global "$1" "$2"', [key, val], (c) => { if (c === 0) page.note("Saved."); });
    }
    function writeEnv(list) {
        page.envVars = list;
        const body = "# Written by ArchangelOS Settings > Developer tools. Session-wide variables.\n"
                   + list.map(v => v.key + "=" + v.value).join("\n") + (list.length ? "\n" : "");
        cmd.sh('mkdir -p "$HOME/.config/environment.d" && printf "%s" "$2" > "$HOME/.config/environment.d/50-archangelos.conf"', ["", body], () => page.note("Saved — applies to apps started after your next sign-in."));
    }
    function setShell(s) {
        page.busy = "shell"; page.error = "";
        act.run([page.admin, "shell-set", page.me, s], (c, o, e) => {
            page.busy = "";
            if (c === 126) page.error = "Cancelled.";
            else if (c !== 0) page.error = (e || o).trim() || "Couldn't change the shell.";
            else { page.shell = s; page.note("Login shell changed — opens next time you sign in."); }
        });
    }
    function shellName(p) { return (p || "").split("/").pop(); }

    Label { visible: page.error !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.error; color: Ax.danger; font.pixelSize: Ax.fsSmall }
    Label { visible: page.notice !== ""; width: parent.width; wrapMode: Text.WordWrap; text: page.notice; color: Ax.accent; font.pixelSize: Ax.fsSmall }

    Section {
        title: "Shell & editor"
        SRow {
            icon: "terminal"; title: "Login shell"; desc: "The shell your terminals open with — now " + (page.shellName(page.shell) || "…")
            AxSelect { width: 180; anchors.verticalCenter: parent.verticalCenter; model: page.shells.map(s => page.shellName(s))
                       current: Math.max(0, page.shells.indexOf(page.shell)); enabled: page.busy === ""
                       onPicked: (i) => { if (page.shells[i] !== page.shell) page.setShell(page.shells[i]); } }
        }
        SRow {
            icon: "edit_note"; title: "Default editor"; desc: "What $EDITOR points to, for git and command-line tools"
            AxField { width: 180; text: page.editor; placeholder: "nvim, nano, code…"; anchors.verticalCenter: parent.verticalCenter
                      onAccepted: if (text.trim()) page.setEditor(text.trim()) }
        }
    }

    Section {
        title: "Git identity"
        note: page.tools.find(t => t.k === "git") && page.tools.find(t => t.k === "git").version ? "" : "git not installed"
        SRow {
            icon: "badge"; title: "Name"; desc: "Stamped on every commit you make"
            AxField { width: 240; text: page.gitName; placeholder: "Your name"; anchors.verticalCenter: parent.verticalCenter; onAccepted: page.setGit("user.name", text.trim()) }
        }
        SRow {
            icon: "alternate_email"; title: "Email"
            AxField { width: 240; text: page.gitEmail; placeholder: "you@example.com"; anchors.verticalCenter: parent.verticalCenter; onAccepted: page.setGit("user.email", text.trim()) }
        }
        SRow {
            icon: "account_tree"; title: "Default branch name"; desc: "Used by  git init  for new repositories"
            AxField { width: 160; text: page.gitBranch; placeholder: "main"; anchors.verticalCenter: parent.verticalCenter; onAccepted: page.setGit("init.defaultBranch", text.trim()) }
        }
        SRow { icon: "info"; title: "Press Enter to save each field"; dim: true }
    }

    Section {
        title: "Toolchains"
        Repeater {
            model: page.tools
            SRow {
                id: toolRow
                required property var modelData
                readonly property bool got: !!modelData.version && modelData.version !== ""
                icon: "code"; title: modelData.name; desc: toolRow.got ? modelData.version : "Not installed"; dim: !toolRow.got
                Badge { visible: toolRow.got; text: "installed"; tone: "ok"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Section {
        title: "Environment variables"
        note: "session-wide"
        Repeater {
            model: page.envVars
            SRow {
                required property var modelData
                required property int index
                icon: "data_object"; title: modelData.key
                Label { text: modelData.value; mono: true; font.pixelSize: Ax.fsSmall; color: Ax.subtext; width: Math.min(implicitWidth, 300); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                ConfirmButton { icon: "delete"; confirmText: "Remove"; anchors.verticalCenter: parent.verticalCenter; onConfirmed: page.writeEnv(page.envVars.filter((x, j) => j !== index)) }
            }
        }
        SRow {
            icon: "add"; title: "Add a variable"
            AxField { id: envK; width: 150; placeholder: "NAME"; anchors.verticalCenter: parent.verticalCenter }
            AxField { id: envV; width: 200; placeholder: "value"; anchors.verticalCenter: parent.verticalCenter }
            AxButton { text: "Add"; kind: "primary"; enabled_: /^[A-Za-z_][A-Za-z0-9_]*$/.test(envK.text.trim()); anchors.verticalCenter: parent.verticalCenter
                       onClicked: { page.writeEnv(page.envVars.filter(v => v.key !== envK.text.trim()).concat([{ key: envK.text.trim(), value: envV.text }])); envK.text = ""; envV.text = ""; } }
        }
        SRow { icon: "info"; title: "Variables apply to graphical apps after you sign in again"; dim: true }
    }
}
