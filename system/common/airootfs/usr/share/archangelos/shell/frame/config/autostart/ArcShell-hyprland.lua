-- ArcShell — Hyprland integration (Lua format)
-- Require this file from your hyprland.lua:
--   require("path.to.ArcShell-hyprland")
--
-- On NixOS with the Home Manager module and systemd.enable = true, ArcShell
-- and its daemons are managed by systemd user services — omit the exec_cmd
-- calls in the hyprland.start block and keep only the layer_rule entries.

-- Daemon autostarts (omit this block on NixOS when using the HM module)
hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("command -v arcshell >/dev/null 2>&1 && arcshell || qs -p " .. os.getenv("HOME") .. "/.local/src/ArcShell")
    hl.exec_cmd("bash -c 'if systemctl --user list-unit-files hyprpolkitagent.service >/dev/null 2>&1; then systemctl --user start hyprpolkitagent; elif command -v hyprpolkitagent >/dev/null 2>&1; then hyprpolkitagent; fi'")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- Layer rules — always required regardless of install method
hl.layer_rule({
    match   = { namespace = "^arcshell.*" },
    no_anim = true,
})

hl.layer_rule({
    match        = { namespace = "selection" },
    no_anim      = true,
    ignore_alpha = 1,
})

-- Dynamic keybinds managed by ArcShell's visual keybind editor
local kb_path = os.getenv("HOME") .. "/.config/ArcShell/ArcShellKeybinds.lua"
local f = io.open(kb_path, "r")
if f then
    f:close()
    dofile(kb_path)
end

