-- ~/.config/hypr/hyprland.lua

---- HOST ----
local function get_hostname()
	local f = io.open("/etc/hostname", "r")
	if not f then
		return ""
	end
	local h = f:read("l")
	f:close()
	return h or ""
end
local host = get_hostname()

---- ENVIRONMENT ----
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "16")

if host == "rits" then
	hl.env("LIBVA_DRIVER_NAME", "nvidia")
	hl.env("GBM_BACKEND", "nvidia-drm")
	hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
	hl.env("NVD_BACKEND", "direct")
end

---- MONITOR ----
if host == "rits" then
	hl.monitor({ output = "DP-3", mode = "5120x1440@239.76", position = "0x0", scale = 1 })
elseif host == "mori" then
	-- Check the real output name with `hyprctl monitors` and adjust.
	hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })
else
	hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
end

---- AUTOSTART   ---
hl.on("hyprland.start", function()
	hl.exec_cmd("ags run ~/.config/ags")
	hl.exec_cmd("hypridle")
	local walFile = io.open(os.getenv("HOME") .. "/.cache/wal/wal", "r")
	if walFile then
		local wallpaper = walFile:read("*l")
		walFile:close()
		if wallpaper then
			hl.exec_cmd("swaybg -i " .. wallpaper .. " -m fill")
		end
	end
end)

---- PYWAL COLORS --
local colorFile = io.open(os.getenv("HOME") .. "/.cache/wal/colors", "r")
local colors = {}
if colorFile then
	local i = 0
	for line in colorFile:lines() do
		colors[i] = line
		i = i + 1
	end
	colorFile:close()
end
local color2 = colors[2] or "#3E4149"
local color6 = colors[6] or "#87735C"
local activeBorder = "rgb(" .. color6:gsub("#", "") .. ")"
local inactiveBorder = "rgb(" .. color2:gsub("#", "") .. ")"

---- LOOK & FEEL --
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,
		border_size = 2,
		col = {
			active_border = activeBorder,
			inactive_border = inactiveBorder,
		},
		layout = "dwindle",
		resize_on_border = false,
		allow_tearing = false,
	},

	decoration = {
		rounding = 4,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = false,
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},

	input = {
		kb_layout = "gb",
		kb_variant = "",
		follow_mouse = 1,
		sensitivity = 0,
	},

	dwindle = {
		preserve_split = true,
	},

	cursor = {
		no_hardware_cursors = true,
	},

	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
})

---- ANIMATIONS  ---
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "almostLinear" })

---- WINDOW RULES --
hl.window_rule({
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	match = { class = "kitty" },
	opacity = "0.85 0.85",
})

hl.window_rule({
	match = { class = "com.gabm.satty" },
	float = true,
	center = true,
})
---- KEYBINDS    ---
local mod = "SUPER"
local moon = "CTRL + SHIFT + ALT + SUPER"

-- Applications
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + Tab", hl.dsp.exec_cmd("kitty"))
hl.bind("CTRL + Tab", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + Space", hl.dsp.exec_cmd("~/.config/rofi/launch.sh"))

-- App shortcuts
hl.bind(mod .. " + 6", hl.dsp.exec_cmd("spotify"))
hl.bind(mod .. " + 7", hl.dsp.exec_cmd("floorp"))
hl.bind(mod .. " + 8", hl.dsp.exec_cmd("discord"))
hl.bind(mod .. " + 9", hl.dsp.exec_cmd("steam"))
hl.bind(mod .. " + 0", hl.dsp.exec_cmd("obsidian"))
hl.bind(mod .. " + minus", hl.dsp.exec_cmd("keepassxc"))

-- Moonlander app shortcuts
hl.bind(moon .. " + h", hl.dsp.exec_cmd("spotify"))
hl.bind(moon .. " + j", hl.dsp.exec_cmd("floorp"))
hl.bind(moon .. " + k", hl.dsp.exec_cmd("discord"))
hl.bind(moon .. " + l", hl.dsp.exec_cmd("steam"))
hl.bind(moon .. " + semicolon", hl.dsp.exec_cmd("obsidian"))
hl.bind(moon .. " + apostrophe", hl.dsp.exec_cmd("keepassxc"))

-- System
hl.bind(mod .. " + p", hl.dsp.exec_cmd("ags request powermenu"))
hl.bind(moon .. " + p", hl.dsp.exec_cmd("ags request powermenu"))
hl.bind(mod .. " + n", hl.dsp.exec_cmd("swaync-client -t"))

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd(' grim -g "$(slurp)" - | satty -f - --copy-command wl-copy'))

-- Window management
hl.bind(mod .. " + w", hl.dsp.window.close())
hl.bind(mod .. " + v", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + f", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Focus (hjkl + arrows)
hl.bind(mod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + j", hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move windows (hjkl + arrows)
hl.bind(mod .. " + SHIFT + h", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + j", hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + SHIFT + k", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + l", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Resize (hjkl + arrows)
hl.bind(mod .. " + ALT + h", hl.dsp.window.resize({ x = -50, y = 0 }))
hl.bind(mod .. " + ALT + j", hl.dsp.window.resize({ x = 0, y = 50 }))
hl.bind(mod .. " + ALT + k", hl.dsp.window.resize({ x = 0, y = -50 }))
hl.bind(mod .. " + ALT + l", hl.dsp.window.resize({ x = 50, y = 0 }))
hl.bind(mod .. " + ALT + left", hl.dsp.window.resize({ x = -50, y = 0 }))
hl.bind(mod .. " + ALT + right", hl.dsp.window.resize({ x = 50, y = 0 }))
hl.bind(mod .. " + ALT + up", hl.dsp.window.resize({ x = 0, y = -50 }))
hl.bind(mod .. " + ALT + down", hl.dsp.window.resize({ x = 0, y = 50 }))

-- Workspaces 1-5
for i = 1, 5 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Moonlander workspace focus/move
local moonWsKeys = { a = 1, s = 2, d = 3, f = 4, g = 5 }
for key, ws in pairs(moonWsKeys) do
	hl.bind(moon .. " + " .. key, hl.dsp.focus({ workspace = ws }))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws }))
end

-- Cycle workspaces
hl.bind(mod .. " + comma", hl.dsp.focus({ workspace = "e-1", type = "workspace" }))
hl.bind(mod .. " + period", hl.dsp.focus({ workspace = "e+1", type = "workspace" }))

-- Alt+Tab
hl.bind("ALT + Tab", hl.dsp.focus({ window = "next" }))
hl.bind("ALT + SHIFT + Tab", hl.dsp.focus({ window = "prev" }))

-- Mouse window management
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Audio
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind(mod .. " + SHIFT + equal", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0"))
hl.bind(mod .. " + SHIFT + minus", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind(mod .. " + SHIFT + m", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("SUPER + XF86AudioPlay", hl.dsp.exec_cmd("playerctl -a stop"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
