-- YoRHa — a NieR:Automata rice ported to ArchangelOS. This is the Lua port of the upstream
-- hyprland config (theme.conf + land/*.conf, originally hyprlang): it reproduces the look, the
-- window/animation rules and the keybinds, and launches the YoRHa bar (AGS v3 / Astal) on start.
-- ArchangelOS loads this when "yorha" is the active shell (Settings > Desktop & Shell); its own
-- bar is not started, so the two never overlap.
local home = os.getenv("HOME") or ""
local theme = home .. "/.config/hypr/themes/yorha"
local sock = (os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/astal/yorha.sock"

-- Tell the bar something over its control socket (ws switch, toggles, screenshot…).
local function ags(msg) return "bash -c 'echo \"" .. msg .. "\" | socat - UNIX-CONNECT:" .. sock .. "'" end
-- First installed of a list (the file manager differs per edition).
local function first_of(...)
    local cands = table.concat({ ... }, " ")
    return hl.dsp.exec_cmd("bash -c 'for c in " .. cands .. "; do command -v $c >/dev/null && exec $c; done'")
end
local kitty = "kitty --config " .. theme .. "/components/kitty/yorha_light.conf"

-- ── appearance ────────────────────────────────────────────────────────────────
hl.config({
    general = {
        border_size = 0,
        gaps_in = 20,
        gaps_out = 20,
        ["col.active_border"] = "rgba(00000000)",
        ["col.inactive_border"] = "rgba(00000000)",
    },
    decoration = {
        rounding = 0,
        blur = { enabled = true, size = 5, passes = 1, noise = 0.05 },
        shadow = { enabled = true, range = 1, render_power = 1, offset = "5 5", color = "rgba(48463d55)", color_inactive = "rgba(48463d11)" },
        screen_shader = theme .. "/components/gridlines.frag",
    },
    animations = {
        enabled = true,
        animation = {
            "windows, 1, 4, swiftOut, slide left",
            "windowsIn, 1, 4, swiftOut, slide left",
            "windowsOut, 1, 3, swiftOut, slide right",
            "windowsMove, 1, 4, swiftOut, slide",
            "border, 1, 10, default",
            "fade, 0",
            "layers, 0",
            "workspaces, 0",
        },
        bezier = {
            "inout, 0.65, 0.01, 0, 0.95",
            "woa, 0, 0, 0, 1",
            "niercurve, 0.4, 0, 0.2, 1",
            "swiftOut, 0.05, 0.7, 0.1, 1.0",
        },
    },
    input = { touchpad = { natural_scroll = true } },
    gestures = { workspace_swipe = true, workspace_swipe_fingers = 4 },
    xwayland = { force_zero_scaling = true },
    misc = { disable_hyprland_logo = true, animate_manual_resizes = true, animate_mouse_windowdragging = true },
})

-- The YoRHa panels want their alpha kept; blur the shell layers.
hl.layer_rule({ match = { namespace = "bg_settings" }, blur = true })
hl.layer_rule({ match = { namespace = "side" }, blur = true })
hl.layer_rule({ match = { namespace = "bar" }, blur = true })
hl.window_rule({ match = { title = "^(fly_is_foot)$" }, float = true, center = true })
hl.window_rule({ match = { title = "^(Spotify)$" }, float = true })

-- ── keybinds (SUPER = MOD1, ALT = MOD2) ───────────────────────────────────────
local mod, alt = "SUPER", "ALT"
-- workspaces: handed to the bar so its tile animation plays first (falls back internally)
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.exec_cmd(theme .. "/scripts/ws-go " .. i), { description = "Workspace " .. i })
    hl.bind(alt .. " + " .. i, hl.dsp.window.move({ workspace = i, silent = true }), { description = "Send window to workspace " .. i })
end
hl.bind(mod .. " + 0", hl.dsp.exec_cmd(theme .. "/scripts/ws-go 10"), { description = "Workspace 10" })
hl.bind(alt .. " + 0", hl.dsp.window.move({ workspace = 10, silent = true }), { description = "Send window to workspace 10" })
hl.bind(mod .. " + mouse_down", hl.dsp.exec_cmd(theme .. "/scripts/ws-go +1"), { description = "Next workspace" })
hl.bind(mod .. " + mouse_up", hl.dsp.exec_cmd(theme .. "/scripts/ws-go -1"), { description = "Previous workspace" })

-- windows
hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mod .. " + E", first_of("thunar", "nautilus", "dolphin"), { description = "File manager" })
hl.bind(mod .. " + S", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo(), { description = "Pseudo-tile" })
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })
hl.bind(mod .. " + g", hl.dsp.group.toggle(), { description = "Toggle group" })
hl.bind(mod .. " + tab", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive f"), { description = "Next in group" })
hl.bind(mod .. " + f", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Fullscreen" })
hl.bind(mod .. " + c", hl.dsp.exec_cmd("hyprctl dispatch centerwindow"), { description = "Center window" })
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag window" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

-- apps / util
hl.bind(mod .. " + space", hl.dsp.exec_cmd("/usr/bin/archangelos-launcher-toggle"), { description = "App launcher" })
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(kitty .. " --title fly_is_foot"), { description = "Floating terminal" })
hl.bind(alt .. " + Return", hl.dsp.exec_cmd(kitty), { description = "Terminal" })
hl.bind(mod .. " + L", hl.dsp.exec_cmd("/usr/bin/archangelos-lock"), { description = "Lock screen" })
hl.bind(mod .. " + SHIFT + s", hl.dsp.exec_cmd(ags("screenshot")), { description = "Screenshot" })

-- bar-routed toggles (YoRHa's own UI)
hl.bind(alt .. " + SUPER + i", hl.dsp.exec_cmd(ags("toggle-settings")), { description = "YoRHa settings" })
hl.bind("Print", hl.dsp.exec_cmd(ags("screenshot")), { description = "Screenshot" })
hl.bind(mod .. " + " .. alt .. " + o", hl.dsp.exec_cmd(ags("toggle-player")), { description = "Music player" })
hl.bind("CTRL + SHIFT + " .. alt .. " + t", hl.dsp.exec_cmd(ags("toggle-dark")), { description = "Toggle dark / light" })
hl.bind(alt .. " + F11", hl.dsp.exec_cmd(ags("dismiss-notifs")), { description = "Dismiss notifications" })
hl.bind("CTRL + SHIFT + " .. alt .. " + r", hl.dsp.exec_cmd(theme .. "/scripts/ags-restart.sh"), { description = "Restart the YoRHa bar" })
hl.bind("SUPER + SHIFT + minus", hl.dsp.exec_cmd(theme .. "/scripts/screenrecord"), { description = "Screen record (toggle)" })
hl.bind("CTRL + " .. alt .. " + w", hl.dsp.exec_cmd(theme .. "/scripts/overkill"), { description = "Kill-window mode" })

-- media / hardware keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, description = "Mute" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true, description = "Brightness down" })

-- ── startup ───────────────────────────────────────────────────────────────────
-- At login (when YoRHa is the active shell) bring the bar up. Live switching from Settings runs
-- the same script through theme.json's "start", so both paths share one launcher.
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("bash " .. theme .. "/scripts/launch")
    hl.exec_cmd("bash -c 'pgrep -x hypridle >/dev/null || hypridle'")
    hl.exec_cmd("bash -c 'pidof polkit-gnome-authentication-agent-1 hyprpolkitagent >/dev/null || for a in /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 /usr/lib/mate-polkit/polkit-mate-authentication-agent-1; do [ -x \"$a\" ] && exec \"$a\"; done'")
end)
