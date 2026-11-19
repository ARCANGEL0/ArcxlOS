-- ArchangelOS live-session welcome window (ArcShell engine Hyprland Lua overlay).
-- Installed only for the live `liveuser`, never into /etc/skel, so an
-- installed system does not show it. Loaded via
-- `require("config.archangelos-welcome")` appended to hyprland.lua.

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/bin/archangelos-welcome")
    hl.exec_cmd([[sh -c 'exec sudo env QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" /usr/bin/archangelos-gui-installer']])
end)
