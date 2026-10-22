-- ArchangelOS overlay on top of ArcShell's compositor config (appearance, input, layouts).
-- Loaded via `require("config.archangelos")` appended to hyprland.lua AFTER
-- `require("arcshell")`. Every keybind lives in config/keybinds.lua (ours, which replaces
-- ArcShell's); this file holds window rules and session startup only.

-- Float + center our own tool windows
hl.window_rule({ match = { title = "^archangelos-launcher$" }, float = true, center = true, size = "1120 720" })
hl.window_rule({ match = { title = "^archangelos-welcome$" },  float = true, center = true })
hl.window_rule({ match = { class = "^archangelos-gui-installer$" }, float = true, center = true, size = "1040 700" })

-- Rio terminal always opens as a small, floating, centered window.
hl.window_rule({ match = { class = "^[Rr]io$" }, float = true, center = true, size = "1000 640" })

-- Startup: launch the desktop shell, set the ArchangelOS wallpaper, apply the default cursor/icon theme,
-- and ensure the idle-lock daemon runs.
hl.on("hyprland.start", function()
    -- the ArchangelOS desktop shell (bar, dock, island, panes)
    hl.exec_cmd("bash -c 'pgrep -f \"[q]s -p /usr/share/archangelos/shell\" >/dev/null || exec qs -p /usr/share/archangelos/shell'")
    hl.exec_cmd("/usr/bin/archangelos-wallpaper boot")
    -- default cursor: Future-dark (compositor cursor + toolkit hints)
    hl.exec_cmd("hyprctl setcursor Future-dark-cursors 24")
    hl.exec_cmd("hyprctl keyword env XCURSOR_THEME,Future-dark-cursors")
    hl.exec_cmd("hyprctl keyword env XCURSOR_SIZE,24")
    hl.exec_cmd("bash -c 'command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface icon-theme Zafiro-Nord-Dark-Black; gsettings set org.gnome.desktop.interface cursor-theme Future-dark-cursors; true'")
    hl.exec_cmd("bash -c 'pgrep -x hypridle >/dev/null || hypridle'")
    -- password prompts for Settings (users, packages, OnionLayer) and anything else using polkit
    hl.exec_cmd("bash -c 'pidof polkit-gnome-authentication-agent-1 polkit-mate-authentication-agent-1 hyprpolkitagent polkit-kde-authentication-agent-1 >/dev/null || for a in /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 /usr/lib/mate-polkit/polkit-mate-authentication-agent-1; do [ -x \"$a\" ] && exec \"$a\"; done'")
end)

-- What Settings saves (Displays, Keyboard & Mouse) is loaded last, so it wins over the defaults.
do
    local cfg = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    for _, f in ipairs({ "/arcshell/hypr/monitors.lua", "/arcshell/hypr/input.lua", "/archangelos/hypr/pointer.lua" }) do
        local path = cfg .. f
        local fh = io.open(path, "r")
        if fh then
            fh:close()
            local ok, err = pcall(dofile, path)
            if not ok then print("archangelos: skipped " .. path .. ": " .. tostring(err)) end
        end
    end
end

-- Fallen: the red-team wheel draws on a transparent full-monitor window.
hl.window_rule({ match = { class = "^archangelos-wheel$" }, float = true, center = true, size = "monitor_w monitor_h" })
