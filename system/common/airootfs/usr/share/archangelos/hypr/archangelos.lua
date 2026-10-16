-- ArchangelOS overlay for the ArcShell Hyprland (Lua) config.
-- Loaded via `require("config.archangelos")` appended to hyprland.lua AFTER
-- `require("arcshell")`, so these layer on top of ArcShell's defaults.

-- Category app launcher (start menu) — SUPER + TAB
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("/usr/bin/archangelos-launcher-toggle"),
    { description = "ArchangelOS app launcher" })

-- ArchangelOS lock screen — SUPER + L
hl.bind("SUPER + L", hl.dsp.exec_cmd("/usr/bin/archangelos-lock"),
    { description = "Lock screen (ArchangelOS)" })

-- NOTE: SUPER + T (Rio terminal), SUPER + F (float toggle) and SUPER + SHIFT + F
-- (fullscreen) are authored directly in ArcShell's keybinds.lua by the desktop bake
-- (archangelos-arcshell-bake), because Hyprland stacks duplicate binds rather than
-- overriding them — an overlay bind here would fire *in addition to* ArcShell's.

-- (Removed) CTRL+SHIFT+arrow window-resize binds. The hl.dsp.window.resize({x,y})
-- table form raised "Runtime error in lua: Invalid size ''" in the post-arcshell
-- overlay context. Dropped entirely — keyboard resize was never a requested
-- feature and the error was noise on every arrow press.

-- Region screenshot — SUPER + SHIFT + S (animated selector → grim → clipboard)
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("/usr/bin/archangelos-screenshot"),
    { description = "Screenshot a region (ArchangelOS)" })

-- Region screen-record — SUPER + SHIFT + R (same selector; press again to stop)
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("/usr/bin/archangelos-screenrecord"),
    { description = "Record a region (ArchangelOS)" })

-- Float + center our own tool windows
hl.window_rule({ match = { title = "^archangelos-launcher$" }, float = true, center = true, size = "1120 720" })
hl.window_rule({ match = { title = "^archangelos-welcome$" },  float = true, center = true })
hl.window_rule({ match = { class = "^archangelos-gui-installer$" }, float = true, center = true, size = "1040 700" })

-- Rio terminal always opens as a small, floating, centered window.
hl.window_rule({ match = { class = "^[Rr]io$" }, float = true, center = true, size = "1000 640" })

-- Startup: set the ArchangelOS wallpaper, apply the default cursor/icon theme,
-- and ensure the idle-lock daemon runs.
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/bin/archangelos-wallpaper boot")
    -- default cursor: Future-dark (compositor cursor + toolkit hints)
    hl.exec_cmd("hyprctl setcursor Future-dark-cursors 24")
    hl.exec_cmd("hyprctl keyword env XCURSOR_THEME,Future-dark-cursors")
    hl.exec_cmd("hyprctl keyword env XCURSOR_SIZE,24")
    hl.exec_cmd("bash -c 'command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface icon-theme Zafiro-Nord-Dark-Black; gsettings set org.gnome.desktop.interface cursor-theme Future-dark-cursors; true'")
    hl.exec_cmd("bash -c 'pgrep -x hypridle >/dev/null || hypridle'")
end)
