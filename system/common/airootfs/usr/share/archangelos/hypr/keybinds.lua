
do
    local dir = (os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")) .. "/hypr/themes"
    local f = io.open(dir .. "/.active", "r")
    local name = f and f:read("*l") or nil
    if f then f:close() end
    local function exists(p) local h = io.open(p, "r"); if h then h:close(); return true end; return false end
    if name and name ~= "" and exists(dir .. "/" .. name .. "/theme.lua") then
        local own = exists(dir .. "/" .. name .. "/config/keybinds.lua") or exists(dir .. "/" .. name .. "/keybinds.lua")
        local j = io.open(dir .. "/" .. name .. "/theme.json", "r")
        if j then own = own or (j:read("*a"):find('"keybinds"%s*:%s*true') ~= nil); j:close() end
        if own then return end
    end
end

local hl = hl
do
    local cfg = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    local ok, user = pcall(dofile, cfg .. "/archangelos/hypr/keys.lua")
    local remap = {}
    local function norm(k) return (k:upper():gsub("%s+", "")) end
    if ok and type(user) == "table" then
        for k, v in pairs(user.remap or {}) do remap[norm(k)] = v end
    end
    local real = hl.bind
    hl = setmetatable({ bind = function(keys, action, opts)
        local r = remap[norm(keys)]
        if r == false then return end
        if type(r) == "string" and r ~= "" then keys = r end
        return real(keys, action, opts)
    end }, { __index = hl })
end

local mod = "SUPER"

local function first_of(...)
	local cands = table.concat({ ... }, " ")
	return hl.dsp.exec_cmd("bash -c 'for c in " .. cands .. "; do command -v $c >/dev/null && exec $c; done'")
end

hl.bind(mod .. " + TAB", hl.dsp.exec_cmd("/usr/bin/archangelos-launcher-toggle"), { description = "App launcher" })
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("bash -c 'command -v archangelos-wheel >/dev/null || exit 0; pkill -f \"/usr/bin/[a]rchangelos-wheel\" || exec archangelos-wheel'"), { description = "Red-team wheel (Fallen)" })
hl.bind(mod .. " + L", hl.dsp.exec_cmd("/usr/bin/archangelos-lock"), { description = "Lock screen" })
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("/usr/bin/archangelos-screenshot"), { description = "Screenshot a region" })
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("/usr/bin/archangelos-screenrecord"), { description = "Record a region (press again to stop)" })
hl.bind("Print", hl.dsp.exec_cmd("/usr/bin/archangelos-screenshot"), { description = "Screenshot a region" })

hl.bind(mod .. " + B", hl.dsp.exec_cmd("librewolf"), { description = "Browser (LibreWolf)" })
hl.bind(mod .. " + T", hl.dsp.exec_cmd("rio"), { description = "Terminal (Rio)" })
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("rio"), { description = "Terminal (Rio)" })
hl.bind(mod .. " + E", first_of("thunar", "nautilus", "dolphin"), { description = "File manager" })
hl.bind(mod .. " + D", hl.dsp.exec_cmd("discord"), { description = "Discord" })
hl.bind(mod .. " + V", hl.dsp.exec_cmd("code"), { description = "Visual Studio Code" })

hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mod .. " + F", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating / tiled" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 1 }), { description = "Maximize / unmaximize" })

hl.bind("CTRL + SHIFT + left", hl.dsp.window.resize({ x = -40, y = 0 }), { repeating = true, description = "Narrower" })
hl.bind("CTRL + SHIFT + right", hl.dsp.window.resize({ x = 40, y = 0 }), { repeating = true, description = "Wider" })
hl.bind("CTRL + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -40 }), { repeating = true, description = "Shorter" })
hl.bind("CTRL + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 40 }), { repeating = true, description = "Taller" })

hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }), { description = "Move window left" })
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }), { description = "Move window up" })
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }), { description = "Move window down" })

for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }), { description = "Workspace " .. i })
	hl.bind(mod .. " + ALT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }), { description = "Send window to workspace " .. i })
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. i })
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag window" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 3%+"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-"), { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, description = "Mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Mute microphone" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true, description = "Brightness down" })

local superTimer = nil
hl.bind(mod .. " + Super_L", function()
	if superTimer then
		superTimer = nil
		hl.exec_cmd("qs -p /usr/share/archangelos/shell ipc call launcher toggle")
	else
		superTimer = hl.timer(function() superTimer = nil end, { timeout = 250, type = "oneshot" })
	end
end, { description = "Search apps (double tap)" })
