-- ArchangelOS overlay for the ArcShell Hyprland (Lua) config.
-- Loaded via `require("config.archangelos")` appended to hyprland.lua AFTER
-- `require("arcshell")`, so these layer on top of ArcShell's defaults.

-- Category app launcher (start menu) — SUPER + TAB
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("/usr/bin/archangelos-launcher-toggle"),
    { description = "ArchangelOS app launcher" })

-- ArchangelOS lock screen — SUPER + L
hl.bind("SUPER + L", hl.dsp.exec_cmd("/usr/bin/archangelos-lock"),
    { description = "Lock screen (ArchangelOS)" })

-- Rio terminal — SUPER + T (in addition to ArcShell's SUPER+Return)
hl.bind("SUPER + T", hl.dsp.exec_cmd("rio"),
    { description = "Open terminal (Rio)" })

-- Float + center our own tool windows
hl.window_rule({ match = { title = "^archangelos-launcher$" }, float = true, center = true, size = "1120 720" })
hl.window_rule({ match = { title = "^archangelos-welcome$" },  float = true, center = true })
hl.window_rule({ match = { class = "^archangelos-gui-installer$" }, float = true, center = true, size = "1040 700" })

-- Startup: set the ArchangelOS wallpaper and ensure the idle-lock daemon runs.
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/bin/archangelos-wallpaper boot")
    hl.exec_cmd("bash -c 'pgrep -x hypridle >/dev/null || hypridle'")
end)
