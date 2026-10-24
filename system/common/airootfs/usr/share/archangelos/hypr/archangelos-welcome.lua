-- ArchangelOS live-session welcome window (ArcShell engine Hyprland Lua overlay).
-- Installed only for the live `liveuser`, never into /etc/skel, so an
-- installed system does not show it. Loaded via
-- `require("config.archangelos-welcome")` appended to hyprland.lua.

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/bin/archangelos-welcome")
end)
