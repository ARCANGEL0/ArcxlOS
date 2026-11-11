
hl.window_rule({ match = { title = "^archangelos-launcher$" }, float = true, center = true, size = "1120 720" })
hl.window_rule({ match = { title = "^archangelos-welcome$" },  float = true, center = true })
hl.window_rule({ match = { class = "^archangelos-gui-installer$" }, float = true, center = true, size = "1040 700" })

hl.window_rule({ match = { class = "^[Rr]io$" }, float = true, center = true, size = "1020 548" })
hl.config({ binds = { disable_keybind_grabbing = true } })
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

local themes_dir = (os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")) .. "/hypr/themes"
local active_theme = nil
do
    local f = io.open(themes_dir .. "/.active", "r")
    local name = f and f:read("*l") or nil
    if f then f:close() end
    if name and name ~= "" then
        local t = io.open(themes_dir .. "/" .. name .. "/theme.lua", "r")
        if t then t:close(); active_theme = name end
    end
end
if active_theme then
    local ok, err = pcall(dofile, themes_dir .. "/" .. active_theme .. "/theme.lua")
    if not ok then print("archangelos: theme " .. active_theme .. " failed: " .. tostring(err)) end
end
hl.bind("SUPER + CTRL + ALT + A", hl.dsp.exec_cmd("bash -c 'archangelos-shell use archangelos --now'"), { description = "Back to ArcShell" })

do
    local cfg = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    local ok, user = pcall(dofile, cfg .. "/archangelos/hypr/keys.lua")
    if ok and type(user) == "table" then
        for _, b in ipairs(user.custom or {}) do
            if type(b.keys) == "string" and type(b.cmd) == "string" then
                local fine, err = pcall(hl.bind, b.keys, hl.dsp.exec_cmd(b.cmd), { description = b.description or b.cmd })
                if not fine then print("archangelos: shortcut " .. b.keys .. " skipped: " .. tostring(err)) end
            end
        end
    end
end

hl.on("hyprland.start", function()
    if not active_theme then
        hl.exec_cmd("bash -c 'pgrep -f \"[q]s -p /usr/share/archangelos/shell\" >/dev/null || exec qs -p /usr/share/archangelos/shell'")
    end
    hl.exec_cmd("/usr/bin/archangelos-wallpaper boot")
    hl.exec_cmd("/usr/bin/archangelos-launcher")
    hl.exec_cmd([[bash -c '
        conf="${XDG_CONFIG_HOME:-$HOME/.config}/archangelos/appearance.conf"
        CURSOR_THEME=Crystal; ICON_THEME=Arcanum; CURSOR_SIZE=24
        [ -f "$conf" ] && . "$conf" 2>/dev/null
        hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE"
        hyprctl keyword env XCURSOR_THEME,"$CURSOR_THEME"
        hyprctl keyword env XCURSOR_SIZE,"$CURSOR_SIZE"
        if command -v gsettings >/dev/null; then
            gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"
            gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"
            gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE"
        fi
        true']])
    hl.exec_cmd("bash -c 'pgrep -x hypridle >/dev/null || hypridle'")
    hl.exec_cmd("bash -c 'pidof polkit-gnome-authentication-agent-1 polkit-mate-authentication-agent-1 hyprpolkitagent polkit-kde-authentication-agent-1 >/dev/null || for a in /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 /usr/lib/mate-polkit/polkit-mate-authentication-agent-1; do [ -x \"$a\" ] && exec \"$a\"; done'")
end)

do
    local cfg = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    for _, f in ipairs({ "/arcshell/hypr/monitors.lua", "/arcshell/hypr/input.lua", "/archangelos/hypr/pointer.lua", "/archangelos/hypr/window.lua", "/archangelos/hypr/a11y.lua" }) do
        local path = cfg .. f
        local fh = io.open(path, "r")
        if fh then
            fh:close()
            local ok, err = pcall(dofile, path)
            if not ok then print("archangelos: skipped " .. path .. ": " .. tostring(err)) end
        end
    end
end

hl.window_rule({ match = { class = "^archangelos-wheel$" }, float = true, center = true, size = "monitor_w monitor_h" })
