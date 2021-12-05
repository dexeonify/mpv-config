-- mpv-osc-morden by maoiscat
-- email:valarmor@163.com
-- https://github.com/maoiscat/mpv-osc-morden

-- fork by cyl0
-- https://github.com/cyl0/mpv-osc-morden-x

-- forked again by dexeonify
--
-- Add support for deus0ww"s thumbnailer
-- https://github.com/deus0ww/mpv-conf/blob/master/scripts/Thumbnailer.lua
--
-- TODO: Rewrite to reach parity with mpv"s default osc
-- https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua

local ipairs,loadfile,pairs,pcall,tonumber,tostring = ipairs,loadfile,pairs,pcall,tonumber,tostring
local debug,io,math,os,string,table,utf8 = debug,io,math,os,string,table,utf8
local min,max,floor,ceil,huge = math.min,math.max,math.floor,math.ceil,math.huge
local mp      = require 'mp'
local assdraw = require 'mp.assdraw'
local msg     = require 'mp.msg'
local opt     = require 'mp.options'
local utils   = require 'mp.utils'

--
-- Parameters
--
-- default user option values
-- do not touch, change them in osc.conf
local user_opts = {
    showwindowed = true,        -- show OSC when windowed?
    showfullscreen = true,      -- show OSC when fullscreen?
    scalewindowed = 1,          -- scaling of the controller when windowed
    scalefullscreen = 1,        -- scaling of the controller when fullscreen
    scaleforcedwindow = 2,      -- scaling when rendered on a forced window
    vidscale = true,            -- scale the controller with the video?
    barmargin = 0,              -- vertical margin of top/bottombar
    boxalpha = 80,              -- alpha of the background box,
                                -- 0 (opaque) to 255 (fully transparent)
    hidetimeout = 500,          -- duration in ms until the OSC hides if no
                                -- mouse movement. enforced non-negative for the
                                -- user, but internally negative is "always-on".
    fadeduration = 200,         -- duration of fade out in ms, 0 = no fade
    deadzonesize = 0.5,         -- size of deadzone
    minmousemove = 0,           -- minimum amount of pixels the mouse has to
                                -- move between ticks to make the OSC show up
    iamaprogrammer = false,     -- use native mpv values and disable OSC
                                -- internal track list management (and some
                                -- functions that depend on it)
    layout = "bottombar",
    font = "mpv-osd-symbols",	-- default osc font
    seekbarhandlesize = 0.6,    -- size ratio of the diamond and knob handle
    seekrange = true,		-- show seekrange overlay
    seekrangealpha = 200,       -- transparency of seekranges
    seekbarkeyframes = true,    -- use keyframes when dragging the seekbar
    title = "${media-title}",   -- string compatible with property-expansion
                                -- to be shown as OSC title
    showtitle = true,		-- show title in OSC
    showonpause = true,         -- whether to disable the hide timeout on pause
    timetotal = false,          -- display total time instead of remaining time?
    timems = false,             -- display timecodes with milliseconds?
    visibility = "auto",        -- only used at init to set visibility_mode(...)
    windowcontrols = "auto",    -- whether to show window controls
    windowcontrols_alignment = "right", -- which side to show window controls on
    language = "eng",		-- eng=English, chs=Chinese


    font = "sans",
    font_mono = "monospace",
    font_bold = 600,
}

-- Localization
local language = {
	["eng"] = {
	    welcome = "{\\fs24\\1c&H0&\\1c&HFFFFFF&}Drop files or URLs to play here.",  -- this text appears when mpv starts
		off = "OFF",
		na = "n/a",
		none = "none",
		video = "Video",
		audio = "Audio",
		subtitle = "Subtitle",
		available = "Available ",
		track = " Tracks:",
		playlist = "Playlist",
		nolist = "Empty playlist.",
		chapter = "Chapter",
		nochapter = "No chapters.",
	},
	["chs"] = {
		welcome = "{\\1c&H00\\bord0\\fs30\\fn微软雅黑 light\\fscx125}MPV{\\fscx100} 播放器",  -- this text appears when mpv starts
		off = "关闭",
		na = "n/a",
		none = "无",
		video = "视频",
		audio = "音频",
		subtitle = "字幕",
		available = "可选",
		track = "：",
		playlist = "播放列表",
		nolist = "无列表信息",
		chapter = "章节",
		nochapter = "无章节信息",
	}
}
-- read options from config and command-line
opt.read_options(user_opts, "osc", function(list) update_options(list) end)
-- deus0ww - 2021-11-26

------------
-- tn_osc --
------------
local message = {
	osc = {
		registration  = "tn_osc_registration",
		reset         = "tn_osc_reset",
		update        = "tn_osc_update",
		finish        = "tn_osc_finish",
	},
	debug = "Thumbnailer-debug",

	queued     = 1,
	processing = 2,
	ready      = 3,
	failed     = 4,
}


-----------
-- Utils --
-----------
local OS_MAC, OS_WIN, OS_NIX = "MAC", "WIN", "NIX"
local function get_os()
	if jit and jit.os then
		if jit.os == "Windows" then return OS_WIN
		elseif jit.os == "OSX" then return OS_MAC
		else return OS_NIX end
	end
	if (package.config:sub(1,1) ~= "/") then return OS_WIN end
	local res = mp.command_native({ name = "subprocess", args = {"uname", "-s"}, playback_only = false, capture_stdout = true, capture_stderr = true, })
	return (res and res.stdout and res.stdout:lower():find("darwin") ~= nil) and OS_MAC or OS_NIX
end
local OPERATING_SYSTEM = get_os()

local function format_json(tab)
	local json, err = utils.format_json(tab)
	if err then msg.error("Formatting JSON failed:", err) end
	if json then return json else return "" end
end

local function parse_json(json)
	local tab, err = utils.parse_json(json, true)
	if err then msg.error("Parsing JSON failed:", err) end
	if tab then return tab else return {} end
end

local function join_paths(...)
	local sep = OPERATING_SYSTEM == OS_WIN and "\\" or "/"
	local result = ""
	for _, p in ipairs({...}) do
		result = (result == "") and p or result .. sep .. p
	end
	return result
end


--------------------
-- Data Structure --
--------------------
local tn_state, tn_osc, tn_osc_options, tn_osc_stats
local tn_thumbnails_indexed, tn_thumbnails_ready
local tn_gen_time_start, tn_gen_duration

local function reset_all()
	tn_state              = nil
	tn_osc = {
		cursor            = {},
		position          = {},
		scale             = {},
		osc_scale         = {},
		spacer            = {},
		osd               = {},
		background        = {text = "︎✇",},
		font_scale        = {},
		display_progress  = {},
		progress          = {},
		mini              = {text = "⚆",},
		thumbnail = {
			visible       = false,
			path_last     = nil,
			x_last        = nil,
			y_last        = nil,
		},
	}
	tn_osc_options        = nil
	tn_osc_stats = {
		queued            = 0,
		processing        = 0,
		ready             = 0,
		failed            = 0,
		total             = 0,
		total_expected    = 0,
		percent           = 0,
		timer             = 0,
	}
	tn_thumbnails_indexed = {}
	tn_thumbnails_ready   = {}
	tn_gen_time_start     = nil
	tn_gen_duration       = nil
end

------------
-- TN OSC --
------------
local osc_reg = {
	script_name = mp.get_script_name(),
	osc_opts = {
		scalewindowed   = user_opts.scalewindowed,
		scalefullscreen = user_opts.scalefullscreen,
	},
}
mp.command_native({"script-message", message.osc.registration, format_json(osc_reg)})

local tn_palette = {
	black        = "000000",
	white        = "FFFFFF",
	alpha_opaque = 0,
	alpha_clear  = 255,
	alpha_black  = min(255, user_opts.boxalpha),
	alpha_white  = min(255, user_opts.boxalpha + (255 - user_opts.boxalpha) * 0.8),
}

local tn_style_format = {
	background     = "{\\bord0\\1c&H%s&\\1a&H%X&}",
	subbackground  = "{\\bord0\\1c&H%s&\\1a&H%X&}",
	spinner        = "{\\bord0\\fs%d\\fscx%f\\fscy%f",
	spinner2       = "\\1c&%s&\\1a&H%X&\\frz%d}",
	closest_index  = "{\\1c&H%s&\\1a&H%X&\\3c&H%s&\\3a&H%X&\\xbord%d\\ybord%d}",
	progress_mini  = "{\\bord0\\1c&%s&\\1a&H%X&\\fs18\\fscx%f\\fscy%f",
	progress_mini2 = "\\frz%d}",
	progress_block = "{\\bord0\\1c&H%s&\\1a&H%X&}",
	progress_text  = "{\\1c&%s&\\3c&H%s&\\1a&H%X&\\3a&H%X&\\blur0.25\\fs18\\fscx%f\\fscy%f\\xbord%f\\ybord%f\\fn" .. user_opts.font_mono .. "}",
	text_timer     = "%.2ds",
	text_progress  = "%.3d/%.3d",
	text_progress2 = "[%d]",
	text_percent   = "%d%%",
}

local tn_style = {
	background     = (tn_style_format.background):format(tn_palette.black, tn_palette.alpha_black),
	subbackground  = (tn_style_format.subbackground):format(tn_palette.white, tn_palette.alpha_white),
	spinner        = (tn_style_format.spinner):format(0, 1, 1),
	closest_index  = (tn_style_format.closest_index):format(tn_palette.white, tn_palette.alpha_black, tn_palette.black, tn_palette.alpha_black, -1, -1),
	progress_mini  = (tn_style_format.progress_mini):format(tn_palette.white, tn_palette.alpha_opaque, 1, 1),
	progress_block = (tn_style_format.progress_block):format(tn_palette.white, tn_palette.alpha_white),
	progress_text  = (tn_style_format.progress_text):format(tn_palette.white, tn_palette.black, tn_palette.alpha_opaque, tn_palette.alpha_black, 1, 1, 2, 2),
}

local function set_thumbnail_above(offset)
	local tn_osc = tn_osc
	tn_osc.background.bottom   = tn_osc.position.y - offset - tn_osc.spacer.bottom
	tn_osc.background.top      = tn_osc.background.bottom - tn_osc.background.h
	tn_osc.thumbnail.top       = tn_osc.background.bottom - tn_osc.thumbnail.h
	tn_osc.progress.top        = tn_osc.background.bottom - tn_osc.background.h
	tn_osc.progress.mid        = tn_osc.progress.top + tn_osc.progress.h * 0.5
	tn_osc.background.rotation = -1
end

local function set_thumbnail_below(offset)
	local tn_osc = tn_osc
	tn_osc.background.top      = tn_osc.position.y + offset + tn_osc.spacer.top
	tn_osc.thumbnail.top       = tn_osc.background.top
	tn_osc.progress.top        = tn_osc.background.top + tn_osc.thumbnail.h + tn_osc.spacer.y
	tn_osc.progress.mid        = tn_osc.progress.top + tn_osc.progress.h * 0.5
	tn_osc.background.rotation = 1
end

local function set_mini_above() tn_osc.mini.y = (tn_osc.background.top    - 12 * tn_osc.osc_scale.y) end
local function set_mini_below() tn_osc.mini.y = (tn_osc.background.bottom + 12 * tn_osc.osc_scale.y) end

local set_thumbnail_layout = {
	topbar    = function()	tn_osc.spacer.top   = 0.25
							set_thumbnail_below(38.75)
							set_mini_above() end,
	bottombar = function()	tn_osc.spacer.bottom = 0.25
							set_thumbnail_above(38.75)
							set_mini_below() end,
	box       = function()	set_thumbnail_above(15)
							set_mini_above() end,
	slimbox   = function()	set_thumbnail_above(12)
							set_mini_above() end,
}

local function update_tn_osc_params(seek_y)
	local tn_state, tn_osc_stats, tn_osc, tn_style, tn_style_format = tn_state, tn_osc_stats, tn_osc, tn_style, tn_style_format
	tn_osc.scale.x, tn_osc.scale.y   = get_virt_scale_factor()
	tn_osc.osd.w, tn_osc.osd.h       = mp.get_osd_size()
	tn_osc.cursor.x, tn_osc.cursor.y = get_virt_mouse_pos()
	tn_osc.position.y                = seek_y

	local osc_changed = false
	if     tn_osc.scale.x_last ~= tn_osc.scale.x or tn_osc.scale.y_last ~= tn_osc.scale.y
		or tn_osc.w_last       ~= tn_state.width or tn_osc.h_last       ~= tn_state.height
		or tn_osc.osd.w_last   ~= tn_osc.osd.w   or tn_osc.osd.h_last   ~= tn_osc.osd.h
	then
		tn_osc.scale.x_last, tn_osc.scale.y_last = tn_osc.scale.x, tn_osc.scale.y
		tn_osc.w_last, tn_osc.h_last             = tn_state.width, tn_state.height
		tn_osc.osd.w_last, tn_osc.osd.h_last     = tn_osc.osd.w, tn_osc.osd.h
		osc_changed = true
	end

	if osc_changed then
		tn_osc.osc_scale.x, tn_osc.osc_scale.y   = 1, 1
		tn_osc.spacer.x, tn_osc.spacer.y         = tn_osc_options.spacer, tn_osc_options.spacer
		tn_osc.font_scale.x, tn_osc.font_scale.y = 100, 100
		tn_osc.progress.h                        = (16 + tn_osc_options.spacer)
		if not user_opts.vidscale then
			tn_osc.osc_scale.x  = tn_osc.scale.x     * tn_osc_options.scale
			tn_osc.osc_scale.y  = tn_osc.scale.y     * tn_osc_options.scale
			tn_osc.spacer.x     = tn_osc.osc_scale.x * tn_osc.spacer.x
			tn_osc.spacer.y     = tn_osc.osc_scale.y * tn_osc.spacer.y
			tn_osc.font_scale.x = tn_osc.osc_scale.x * tn_osc.font_scale.x
			tn_osc.font_scale.y = tn_osc.osc_scale.y * tn_osc.font_scale.y
			tn_osc.progress.h   = tn_osc.osc_scale.y * tn_osc.progress.h
		end
		tn_osc.spacer.top, tn_osc.spacer.bottom  = tn_osc.spacer.y, tn_osc.spacer.y
		tn_osc.thumbnail.w, tn_osc.thumbnail.h   = tn_state.width * tn_osc.scale.x, tn_state.height * tn_osc.scale.y
		tn_osc.osd.w_scaled, tn_osc.osd.h_scaled = tn_osc.osd.w * tn_osc.scale.x, tn_osc.osd.h * tn_osc.scale.y
		tn_style.spinner                         = (tn_style_format.spinner):format(min(tn_osc.thumbnail.w, tn_osc.thumbnail.h) * 0.6667, tn_osc.font_scale.x, tn_osc.font_scale.y)
		tn_style.closest_index                   = (tn_style_format.closest_index):format(tn_palette.white, tn_palette.alpha_black, tn_palette.black, tn_palette.alpha_black, -1 * tn_osc.scale.x, -1 * tn_osc.scale.y)
		if tn_osc_stats.percent < 1 then
			tn_style.progress_text = (tn_style_format.progress_text):format(tn_palette.white, tn_palette.black, tn_palette.alpha_opaque, tn_palette.alpha_black, tn_osc.font_scale.x, tn_osc.font_scale.y, 2 * tn_osc.scale.x, 2 * tn_osc.scale.y)
			tn_style.progress_mini = (tn_style_format.progress_mini):format(tn_palette.white, tn_palette.alpha_opaque, tn_osc.font_scale.x, tn_osc.font_scale.y)
		end
	end
	
	if not tn_osc.position.y then return end
	if (osc_changed or tn_osc.cursor.x_last ~= tn_osc.cursor.x) and tn_osc.osd.w_scaled >= (tn_osc.thumbnail.w + 2 * tn_osc.spacer.x) then
		tn_osc.cursor.x_last  = tn_osc.cursor.x
		if tn_osc_options.centered then
			tn_osc.position.x = tn_osc.osd.w_scaled * 0.5
		else
			local limit_left  = tn_osc.spacer.x + tn_osc.thumbnail.w * 0.5
			local limit_right = tn_osc.osd.w_scaled - limit_left
			tn_osc.position.x = min(max(tn_osc.cursor.x, limit_left), limit_right)
		end
		tn_osc.thumbnail.left, tn_osc.thumbnail.right = tn_osc.position.x - tn_osc.thumbnail.w * 0.5, tn_osc.position.x + tn_osc.thumbnail.w * 0.5
		tn_osc.mini.x = tn_osc.thumbnail.right - 6 * tn_osc.osc_scale.x
	end
	
	if (osc_changed or tn_osc.display_progress.last ~= tn_osc.display_progress.current) then
		tn_osc.display_progress.last = tn_osc.display_progress.current
		tn_osc.background.h          = tn_osc.thumbnail.h + (tn_osc.display_progress.current and (tn_osc.progress.h + tn_osc.spacer.y) or 0)
		set_thumbnail_layout[user_opts.layout]()
	end
end

local function find_closest(seek_index, round_up)
	local tn_state, tn_thumbnails_indexed, tn_thumbnails_ready = tn_state, tn_thumbnails_indexed, tn_thumbnails_ready
	if not (tn_thumbnails_indexed and tn_thumbnails_ready) then return nil, nil end
	local time_index = floor(seek_index * tn_state.delta)
	if tn_thumbnails_ready[time_index] then return seek_index + 1, tn_thumbnails_indexed[time_index] end
	local direction, index = round_up and 1 or -1
	for i = 1, tn_osc_stats.total_expected do
		index        = seek_index + (i * direction)
		time_index   = floor(index * tn_state.delta)
		if tn_thumbnails_ready[time_index] then return index + 1, tn_thumbnails_indexed[time_index] end
		index        = seek_index + (i * -direction)
		time_index   = floor(index * tn_state.delta)
		if tn_thumbnails_ready[time_index] then return index + 1, tn_thumbnails_indexed[time_index] end
	end
	return nil, nil
end

local draw_cmd = { name = "overlay-add",    id = 9, offset = 0, fmt = "bgra" }
local hide_cmd = { name = "overlay-remove", id = 9}

local function draw_thumbnail(x, y, path)
	draw_cmd.x = x
	draw_cmd.y = y
	draw_cmd.file = path
	mp.command_native(draw_cmd)
	tn_osc.thumbnail.visible = true
end

local function hide_thumbnail()
	if tn_osc and tn_osc.thumbnail and tn_osc.thumbnail.visible then
		mp.command_native(hide_cmd)
		tn_osc.thumbnail.visible = false
	end
end

local function show_thumbnail(seek_percent)
	if not seek_percent then return nil, nil end
	local scale, thumbnail, total_expected, ready = tn_osc.scale, tn_osc.thumbnail, tn_osc_stats.total_expected, tn_osc_stats.ready
	local seek = seek_percent * (total_expected - 1)
	local seek_index = floor(seek + 0.5)
	local closest_index, path = thumbnail.closest_index_last, thumbnail.path_last
	if     thumbnail.seek_index_last     ~= seek_index
		or thumbnail.ready_last          ~= ready
		or thumbnail.total_expected_last ~= tn_osc_stats.total_expected
	then
		closest_index, path = find_closest(seek_index, seek_index < seek)
		thumbnail.closest_index_last, thumbnail.total_expected_last, thumbnail.ready_last, thumbnail.seek_index_last = closest_index, total_expected, ready, seek_index
	end
	local x, y = floor((thumbnail.left or 0) / scale.x + 0.5), floor((thumbnail.top or 0) / scale.y + 0.5)
	if path and not (thumbnail.visible and thumbnail.x_last == x and thumbnail.y_last == y and thumbnail.path_last == path) then
		thumbnail.x_last, thumbnail.y_last, thumbnail.path_last  = x, y, path
		draw_thumbnail(x, y, path)
	end
	return closest_index, path
end

local function ass_new(ass, x, y, align, style, text)
	ass:new_event()
	ass:pos(x, y)
	if align then ass:an(align)     end
	if style then ass:append(style) end
	if text  then ass:append(text)  end
end

local function ass_rect(ass, x1, y1, x2, y2)
	ass:draw_start()
	ass:rect_cw(x1, y1, x2, y2)
	ass:draw_stop()
end

local draw_progress = {
	[message.queued]     = function(ass, index, block_w, block_h) ass:rect_cw((index - 1) * block_w,             0, index * block_w, block_h) end,
	[message.processing] = function(ass, index, block_w, block_h) ass:rect_cw((index - 1) * block_w, block_h * 0.2, index * block_w, block_h * 0.8) end,
	[message.failed]     = function(ass, index, block_w, block_h) ass:rect_cw((index - 1) * block_w, block_h * 0.4, index * block_w, block_h * 0.6) end,
}

local function display_tn_osc(seek_y, seek_percent, ass)
	if not (seek_y and seek_percent and ass and tn_state and tn_osc_stats and tn_osc_options and tn_state.width and tn_state.height and tn_state.duration and tn_state.cache_dir) or not tn_osc_options.visible then hide_thumbnail() return end

	update_tn_osc_params(seek_y)
	local tn_osc_stats, tn_osc, tn_style, tn_style_format, ass_new, ass_rect, seek_percent = tn_osc_stats, tn_osc, tn_style, tn_style_format, ass_new, ass_rect, seek_percent * 0.01
	local closest_index, path = show_thumbnail(seek_percent)

	-- Background
	ass_new(ass, tn_osc.thumbnail.left, tn_osc.background.top, 7, tn_style.background)
	ass_rect(ass, -tn_osc.spacer.x, -tn_osc.spacer.top, tn_osc.thumbnail.w + tn_osc.spacer.x, tn_osc.background.h + tn_osc.spacer.bottom)

	local spinner_color, spinner_alpha = tn_palette.white, tn_palette.alpha_white
	if not path then
		ass_new(ass, tn_osc.thumbnail.left, tn_osc.thumbnail.top, 7, tn_style.subbackground)
		ass_rect(ass, 0, 0, tn_osc.thumbnail.w, tn_osc.thumbnail.h)
		spinner_color, spinner_alpha = tn_palette.black, tn_palette.alpha_black
	end
	ass_new(ass, tn_osc.position.x, tn_osc.thumbnail.top + tn_osc.thumbnail.h * 0.5, 5, tn_style.spinner .. (tn_style_format.spinner2):format(spinner_color, spinner_alpha, tn_osc.background.rotation * seek_percent * 1080), tn_osc.background.text)

	-- Mini Progress Spinner
	if tn_osc.display_progress.current ~= nil and not tn_osc.display_progress.current and tn_osc_stats.percent < 1 then
		ass_new(ass, tn_osc.mini.x, tn_osc.mini.y, 5, tn_style.progress_mini .. (tn_style_format.progress_mini2):format(tn_osc_stats.percent * -360 + 90), tn_osc.mini.text)
	end

	-- Progress Bar
	if tn_osc.display_progress.current then
		local block_w, index = tn_osc_stats.total_expected > 0 and tn_state.width * tn_osc.scale.y / tn_osc_stats.total_expected or 0, 0
		if tn_thumbnails_indexed and block_w > 0 then
			-- Loading bar
			ass_new(ass, tn_osc.thumbnail.left, tn_osc.progress.top, 7, tn_style.progress_block)
			ass:draw_start()
			for time_index, status in pairs(tn_thumbnails_indexed) do
				index = floor(time_index / tn_state.delta) + 1
				if index ~= closest_index and not tn_thumbnails_ready[time_index] and index <= tn_osc_stats.total_expected and draw_progress[status] ~= nil then
					draw_progress[status](ass, index, block_w, tn_osc.progress.h)
				end
			end
			ass:draw_stop()

			if closest_index and closest_index <= tn_osc_stats.total_expected then
				ass_new(ass, tn_osc.thumbnail.left, tn_osc.progress.top, 7, tn_style.closest_index)
				ass_rect(ass, (closest_index - 1) * block_w, 0, closest_index * block_w, tn_osc.progress.h)
			end
		end

		-- Text: Timer
		ass_new(ass, tn_osc.thumbnail.left + 3 * tn_osc.osc_scale.y, tn_osc.progress.mid, 4, tn_style.progress_text, (tn_style_format.text_timer):format(tn_osc_stats.timer))

		-- Text: Number or Index of Thumbnail
		local temp = tn_osc_stats.percent < 1 and tn_osc_stats.ready or closest_index
		local processing = tn_osc_stats.processing > 0 and (tn_style_format.text_progress2):format(tn_osc_stats.processing) or ""
		ass_new(ass, tn_osc.position.x, tn_osc.progress.mid, 5, tn_style.progress_text, (tn_style_format.text_progress):format(temp and temp or 0, tn_osc_stats.total_expected) .. processing)

		-- Text: Percentage
		ass_new(ass, tn_osc.thumbnail.right - 3 * tn_osc.osc_scale.y, tn_osc.progress.mid, 6, tn_style.progress_text, (tn_style_format.text_percent):format(min(100, tn_osc_stats.percent * 100)))
	end
end


---------------
-- Listeners --
---------------
mp.register_script_message(message.osc.reset, function()
	hide_thumbnail()
	reset_all()	
end)

local text_progress_format = { two_digits = "%.2d/%.2d", three_digits = "%.3d/%.3d" }

mp.register_script_message(message.osc.update, function(json)
	local new_data = parse_json(json)
	if not new_data then return end
	if new_data.state then
		tn_state = new_data.state
		if tn_state.is_rotated then tn_state.width, tn_state.height = tn_state.height, tn_state.width end
		draw_cmd.w = tn_state.width
		draw_cmd.h = tn_state.height
		draw_cmd.stride = tn_state.width * 4
	end
	if new_data.osc_options then tn_osc_options = new_data.osc_options end
	if new_data.osc_stats then
		tn_osc_stats = new_data.osc_stats
		if tn_osc_options and tn_osc_options.show_progress then
			if     tn_osc_options.show_progress == 0 then tn_osc.display_progress.current = false
			elseif tn_osc_options.show_progress == 1 then tn_osc.display_progress.current = tn_osc_stats.percent < 1
			else                                          tn_osc.display_progress.current = true end
		end
		tn_style_format.text_progress = tn_osc_stats.total > 99 and text_progress_format.three_digits or text_progress_format.two_digits
		if tn_osc_stats.percent >= 1 then mp.command_native({"script-message", message.osc.finish}) end
	end
	if new_data.thumbnails and tn_state then
		local index, ready
		for time_string, status in pairs(new_data.thumbnails) do
			index, ready = tonumber(time_string), (status == message.ready)
			tn_thumbnails_indexed[index] = ready and join_paths(tn_state.cache_dir, time_string) .. tn_state.cache_extension or status
			tn_thumbnails_ready[index]   = ready
		end
	end
	request_tick()
end)

mp.register_script_message(message.debug, function()
	msg.info("Thumbnailer OSC Internal States:")
	msg.info("tn_state:", tn_state and utils.to_string(tn_state) or "nil")
	msg.info("tn_thumbnails_indexed:", tn_thumbnails_indexed and utils.to_string(tn_thumbnails_indexed) or "nil")
	msg.info("tn_thumbnails_ready:", tn_thumbnails_ready and utils.to_string(tn_thumbnails_ready) or "nil")
	msg.info("tn_osc_options:", tn_osc_options and utils.to_string(tn_osc_options) or "nil")
	msg.info("tn_osc_stats:", tn_osc_stats and utils.to_string(tn_osc_stats) or "nil")
	msg.info("tn_osc:", tn_osc and utils.to_string(tn_osc) or "nil")
end)




-----------------
-- mordenx.lua --
-----------------

-- apply lang opts
local texts = language[user_opts.language]
local osc_param = { -- calculated by osc_init()
    playresy = 0,                           -- canvas size Y
    playresx = 0,                           -- canvas size X
    display_aspect = 1,
    unscaled_y = 0,
    areas = {},
    video_margins = {
        l = 0, r = 0, t = 0, b = 0,         -- left/right/top/bottom
    },
}

local osc_styles = {
    TransBg = "{\\blur100\\bord150\\1c&H000000&\\3c&H000000&}",
    SeekbarBg = "{\\blur0\\bord0\\1c&HFFFFFF&}",
    SeekbarFg = "{\\blur1\\bord1\\1c&HE39C42&}",
    Ctrl1 = "{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs36\\fnmaterial-design-iconic-font}",
    Ctrl2 = "{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnmaterial-design-iconic-font}",
    Ctrl3 = "{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnmaterial-design-iconic-font}",
    Time = "{\\blur0\\bord0\\1c&HFFFFFF&\\3c&H000000&\\fs17\\fn" .. user_opts.font .. "}",
    Tooltip = "{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H000000&\\fs18\\fn" .. user_opts.font .. "}",
    Title = "{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H0\\fs38\\q2\\fn" .. user_opts.font .. "}",
    WinCtrl = "{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H0\\fs20\\fnmpv-osd-symbols}",
    elementDown = "{\\1c&H999999&}",
    wcButtons = "{\\1c&HFFFFFF\\fs24\\fnmpv-osd-symbols}",
    wcTitle = "{\\1c&HFFFFFF\\fs24\\q2}",
    wcBar = "{\\1c&H000000}",
}

-- internal states, do not touch
local state = {
    showtime,                               -- time of last invocation (last mouse move)
    osc_visible = false,
    anistart,                               -- time when the animation started
    anitype,                                -- current type of animation
    animation,                              -- current animation alpha
    mouse_down_counter = 0,                 -- used for softrepeat
    active_element = nil,                   -- nil = none, 0 = background, 1+ = see elements[]
    active_event_source = nil,              -- the "button" that issued the current event
    rightTC_trem = not user_opts.timetotal, -- if the right timecode should display total or remaining time
    mp_screen_sizeX, mp_screen_sizeY,       -- last screen-resolution, to detect resolution changes to issue reINITs
    initREQ = false,                        -- is a re-init request pending?
    last_mouseX, last_mouseY,               -- last mouse position, to detect significant mouse movement
    mouse_in_window = false,
    message_text,
    message_hide_timer,
    fullscreen = false,
    tick_timer = nil,
    tick_last_time = 0,                     -- when the last tick() was run
    hide_timer = nil,
    cache_state = nil,
    idle = false,
    enabled = true,
    input_enabled = true,
    showhide_enabled = false,
    dmx_cache = 0,
    border = true,
    maximized = false,
    osd = mp.create_osd_overlay("ass-events"),
    lastvisibility = user_opts.visibility,	-- save last visibility on pause if showonpause
    fulltime = user_opts.timems,
}

local window_control_box_width = 138
local tick_delay = 0.03

--- Automatically disable OSC
local builtin_osc_enabled = mp.get_property_native("osc")
if builtin_osc_enabled then
    mp.set_property_native("osc", false)
end

--
-- Helperfunctions
--

function set_osd(res_x, res_y, text)
    if state.osd.res_x == res_x and
       state.osd.res_y == res_y and
       state.osd.data == text then
        return
    end
    state.osd.res_x = res_x
    state.osd.res_y = res_y
    state.osd.data = text
    state.osd.z = 1000
    state.osd:update()
end

-- scale factor for translating between real and virtual ASS coordinates
function get_virt_scale_factor()
    local w, h = mp.get_osd_size()
    if w <= 0 or h <= 0 then
        return 0, 0
    end
    return osc_param.playresx / w, osc_param.playresy / h
end

-- return mouse position in virtual ASS coordinates (playresx/y)
function get_virt_mouse_pos()
    if state.mouse_in_window then
        local sx, sy = get_virt_scale_factor()
        local x, y = mp.get_mouse_pos()
        return x * sx, y * sy
    else
        return -1, -1
    end
end

function set_virt_mouse_area(x0, y0, x1, y1, name)
    local sx, sy = get_virt_scale_factor()
    mp.set_mouse_area(x0 / sx, y0 / sy, x1 / sx, y1 / sy, name)
end

function scale_value(x0, x1, y0, y1, val)
    local m = (y1 - y0) / (x1 - x0)
    local b = y0 - (m * x0)
    return (m * val) + b
end

-- returns hitbox spanning coordinates (top left, bottom right corner)
-- according to alignment
function get_hitbox_coords(x, y, an, w, h)

    local alignments = {
      [1] = function () return x, y-h, x+w, y end,
      [2] = function () return x-(w/2), y-h, x+(w/2), y end,
      [3] = function () return x-w, y-h, x, y end,

      [4] = function () return x, y-(h/2), x+w, y+(h/2) end,
      [5] = function () return x-(w/2), y-(h/2), x+(w/2), y+(h/2) end,
      [6] = function () return x-w, y-(h/2), x, y+(h/2) end,

      [7] = function () return x, y, x+w, y+h end,
      [8] = function () return x-(w/2), y, x+(w/2), y+h end,
      [9] = function () return x-w, y, x, y+h end,
    }

    return alignments[an]()
end

function get_hitbox_coords_geo(geometry)
    return get_hitbox_coords(geometry.x, geometry.y, geometry.an,
        geometry.w, geometry.h)
end

function get_element_hitbox(element)
    return element.hitbox.x1, element.hitbox.y1,
        element.hitbox.x2, element.hitbox.y2
end

function mouse_hit(element)
    return mouse_hit_coords(get_element_hitbox(element))
end

function mouse_hit_coords(bX1, bY1, bX2, bY2)
    local mX, mY = get_virt_mouse_pos()
    return (mX >= bX1 and mX <= bX2 and mY >= bY1 and mY <= bY2)
end

function limit_range(min, max, val)
    if val > max then
        val = max
    elseif val < min then
        val = min
    end
    return val
end

-- translate value into element coordinates
function get_slider_ele_pos_for(element, val)

    local ele_pos = scale_value(
        element.slider.min.value, element.slider.max.value,
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        val)

    return limit_range(
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        ele_pos)
end

-- translates global (mouse) coordinates to value
function get_slider_value_at(element, glob_pos)

    local val = scale_value(
        element.slider.min.glob_pos, element.slider.max.glob_pos,
        element.slider.min.value, element.slider.max.value,
        glob_pos)

    return limit_range(
        element.slider.min.value, element.slider.max.value,
        val)
end

-- get value at current mouse position
function get_slider_value(element)
    return get_slider_value_at(element, get_virt_mouse_pos())
end

function countone(val)
    if not (user_opts.iamaprogrammer) then
        val = val + 1
    end
    return val
end

-- align:  -1 .. +1
-- frame:  size of the containing area
-- obj:    size of the object that should be positioned inside the area
-- margin: min. distance from object to frame (as long as -1 <= align <= +1)
function get_align(align, frame, obj, margin)
    return (frame / 2) + (((frame / 2) - margin - (obj / 2)) * align)
end

-- multiplies two alpha values, formular can probably be improved
function mult_alpha(alphaA, alphaB)
    return 255 - (((1-(alphaA/255)) * (1-(alphaB/255))) * 255)
end

function add_area(name, x1, y1, x2, y2)
    -- create area if needed
    if (osc_param.areas[name] == nil) then
        osc_param.areas[name] = {}
    end
    table.insert(osc_param.areas[name], {x1=x1, y1=y1, x2=x2, y2=y2})
end

function ass_append_alpha(ass, alpha, modifier)
    local ar = {}

    for ai, av in pairs(alpha) do
        av = mult_alpha(av, modifier)
        if state.animation then
            av = mult_alpha(av, state.animation)
        end
        ar[ai] = av
    end

    ass:append(string.format("{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}",
               ar[1], ar[2], ar[3], ar[4]))
end

function ass_draw_cir_cw(ass, x, y, r)
	ass:round_rect_cw(x-r, y-r, x+r, y+r, r)
end

function ass_draw_rr_h_cw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_cw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_cw(x0, y0, x1, y1, r1, r2)
    end
end

function ass_draw_rr_h_ccw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_ccw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_ccw(x0, y0, x1, y1, r1, r2)
    end
end


--
-- Tracklist Management
--

local nicetypes = {video = texts.video, audio = texts.audio, sub = texts.subtitle}

-- updates the OSC internal playlists, should be run each time the track-layout changes
function update_tracklist()
    local tracktable = mp.get_property_native("track-list", {})

    -- by osc_id
    tracks_osc = {}
    tracks_osc.video, tracks_osc.audio, tracks_osc.sub = {}, {}, {}
    -- by mpv_id
    tracks_mpv = {}
    tracks_mpv.video, tracks_mpv.audio, tracks_mpv.sub = {}, {}, {}
    for n = 1, #tracktable do
        if not (tracktable[n].type == "unknown") then
            local type = tracktable[n].type
            local mpv_id = tonumber(tracktable[n].id)

            -- by osc_id
            table.insert(tracks_osc[type], tracktable[n])

            -- by mpv_id
            tracks_mpv[type][mpv_id] = tracktable[n]
            tracks_mpv[type][mpv_id].osc_id = #tracks_osc[type]
        end
    end
end

-- return a nice list of tracks of the given type (video, audio, sub)
function get_tracklist(type)
    local msg = texts.available .. nicetypes[type] .. texts.track
    if #tracks_osc[type] == 0 then
        msg = msg .. texts.none
    else
        for n = 1, #tracks_osc[type] do
            local track = tracks_osc[type][n]
            local lang, title, selected = "unknown", "", "○"
            if not(track.lang == nil) then lang = track.lang end
            if not(track.title == nil) then title = track.title end
            if (track.id == tonumber(mp.get_property(type))) then
                selected = "●"
            end
            msg = msg.."\n"..selected.." "..n..": ["..lang.."] "..title
        end
    end
    return msg
end

-- relatively change the track of given <type> by <next> tracks
    --(+1 -> next, -1 -> previous)
function set_track(type, next)
    local current_track_mpv, current_track_osc
    if (mp.get_property(type) == "no") then
        current_track_osc = 0
    else
        current_track_mpv = tonumber(mp.get_property(type))
        current_track_osc = tracks_mpv[type][current_track_mpv].osc_id
    end
    local new_track_osc = (current_track_osc + next) % (#tracks_osc[type] + 1)
    local new_track_mpv
    if new_track_osc == 0 then
        new_track_mpv = "no"
    else
        new_track_mpv = tracks_osc[type][new_track_osc].id
    end

    mp.commandv("set", type, new_track_mpv)

--	if (new_track_osc == 0) then
--        show_message(nicetypes[type] .. " Track: none")
--    else
--        show_message(nicetypes[type]  .. " Track: "
--            .. new_track_osc .. "/" .. #tracks_osc[type]
--            .. " [".. (tracks_osc[type][new_track_osc].lang or "unknown") .."] "
--            .. (tracks_osc[type][new_track_osc].title or ""))
--    end
end

-- get the currently selected track of <type>, OSC-style counted
function get_track(type)
    local track = mp.get_property(type)
    if track ~= "no" and track ~= nil then
        local tr = tracks_mpv[type][tonumber(track)]
        if tr then
            return tr.osc_id
        end
    end
    return 0
end

-- WindowControl helpers
function window_controls_enabled()
    val = user_opts.windowcontrols
    if val == "auto" then
        return not state.border
    else
        return val ~= "no"
    end
end

function window_controls_alignment()
    return user_opts.windowcontrols_alignment
end

--
-- Element Management
--

local elements = {}

function prepare_elements()

    -- remove elements without layout or invisble
    local elements2 = {}
    for n, element in pairs(elements) do
        if not (element.layout == nil) and (element.visible) then
            table.insert(elements2, element)
        end
    end
    elements = elements2

    function elem_compare (a, b)
        return a.layout.layer < b.layout.layer
    end

    table.sort(elements, elem_compare)


    for _,element in pairs(elements) do

        local elem_geo = element.layout.geometry

        -- Calculate the hitbox
        local bX1, bY1, bX2, bY2 = get_hitbox_coords_geo(elem_geo)
        element.hitbox = {x1 = bX1, y1 = bY1, x2 = bX2, y2 = bY2}

        local style_ass = assdraw.ass_new()

        -- prepare static elements
        style_ass:append("{}") -- hack to troll new_event into inserting a \n
        style_ass:new_event()
        style_ass:pos(elem_geo.x, elem_geo.y)
        style_ass:an(elem_geo.an)
        style_ass:append(element.layout.style)

        element.style_ass = style_ass

        local static_ass = assdraw.ass_new()


        if (element.type == "box") then
            --draw box
            static_ass:draw_start()
            ass_draw_rr_h_cw(static_ass, 0, 0, elem_geo.w, elem_geo.h,
                             element.layout.box.radius, element.layout.box.hexagon)
            static_ass:draw_stop()

        elseif (element.type == "slider") then
            --draw static slider parts
            local slider_lo = element.layout.slider
            -- calculate positions of min and max points
			element.slider.min.ele_pos = user_opts.seekbarhandlesize * elem_geo.h / 2
			element.slider.max.ele_pos = elem_geo.w - element.slider.min.ele_pos
            element.slider.min.glob_pos = element.hitbox.x1 + element.slider.min.ele_pos
            element.slider.max.glob_pos = element.hitbox.x1 + element.slider.max.ele_pos

            static_ass:draw_start()
			-- a hack which prepares the whole slider area to allow center placements such like an=5
			static_ass:rect_cw(0, 0, elem_geo.w, elem_geo.h)
			static_ass:rect_ccw(0, 0, elem_geo.w, elem_geo.h)
            -- marker nibbles
            if not (element.slider.markerF == nil) and (slider_lo.gap > 0) then
                local markers = element.slider.markerF()
                for _,marker in pairs(markers) do
                    if (marker >= element.slider.min.value) and (marker <= element.slider.max.value) then
                        local s = get_slider_ele_pos_for(element, marker)
                        if (slider_lo.gap > 5) then -- draw triangles
                            --top
                            if (slider_lo.nibbles_top) then
                                static_ass:move_to(s - 3, slider_lo.gap - 5)
                                static_ass:line_to(s + 3, slider_lo.gap - 5)
                                static_ass:line_to(s, slider_lo.gap - 1)
                            end
                            --bottom
                            if (slider_lo.nibbles_bottom) then
                                static_ass:move_to(s - 3, elem_geo.h - slider_lo.gap + 5)
								static_ass:line_to(s, elem_geo.h - slider_lo.gap + 1)
                                static_ass:line_to(s + 3, elem_geo.h - slider_lo.gap + 5)
                            end
                        else -- draw 2x1px nibbles
                            --top
                            if (slider_lo.nibbles_top) then
                                static_ass:rect_cw(s - 1, 0, s + 1, slider_lo.gap);
                            end
                            --bottom
                            if (slider_lo.nibbles_bottom) then
                                static_ass:rect_cw(s - 1, elem_geo.h-slider_lo.gap, s + 1, elem_geo.h);
                            end
                        end
                    end
                end
            end
        end

        element.static_ass = static_ass

        -- if the element is supposed to be disabled,
        -- style it accordingly and kill the eventresponders
        if not (element.enabled) then
            element.layout.alpha[1] = 136
            element.eventresponder = nil
        end
    end
end

--
-- Element Rendering
--
function render_elements(master_ass)

    for n=1, #elements do
        local element = elements[n]
        local style_ass = assdraw.ass_new()
        style_ass:merge(element.style_ass)
        ass_append_alpha(style_ass, element.layout.alpha, 0)

        if element.eventresponder and (state.active_element == n) then
            -- run render event functions
            if not (element.eventresponder.render == nil) then
                element.eventresponder.render(element)
            end
            if mouse_hit(element) then
                -- mouse down styling
                if (element.styledown) then
                    style_ass:append(osc_styles.elementDown)
                end
                if (element.softrepeat) and (state.mouse_down_counter >= 15
                    and state.mouse_down_counter % 5 == 0) then

                    element.eventresponder[state.active_event_source.."_down"](element)
                end
                state.mouse_down_counter = state.mouse_down_counter + 1
            end
        end

        local elem_ass = assdraw.ass_new()
        elem_ass:merge(style_ass)
        
        if not (element.type == "button") then
            elem_ass:merge(element.static_ass)
        end

        if (element.type == "slider") then

            local slider_lo = element.layout.slider
            local elem_geo = element.layout.geometry
            local s_min = element.slider.min.value
            local s_max = element.slider.max.value
            -- draw pos marker
            local pos = element.slider.posF()
            local seekRanges = element.slider.seekRangesF()
			local rh = user_opts.seekbarhandlesize * elem_geo.h / 2 -- Handle radius
            local xp
            
            if pos then
                xp = get_slider_ele_pos_for(element, pos)
				ass_draw_cir_cw(elem_ass, xp, elem_geo.h/2, rh)
				elem_ass:rect_cw(0, slider_lo.gap, xp, elem_geo.h - slider_lo.gap)
            end

            if seekRanges then
				elem_ass:draw_stop()
				elem_ass:merge(element.style_ass)
				ass_append_alpha(elem_ass, element.layout.alpha, user_opts.seekrangealpha)
				elem_ass:merge(element.static_ass)

                for _,range in pairs(seekRanges) do
                    local pstart = get_slider_ele_pos_for(element, range["start"])
                    local pend = get_slider_ele_pos_for(element, range["end"])
					elem_ass:rect_cw(pstart - rh, slider_lo.gap, pend + rh, elem_geo.h - slider_lo.gap)
                end
            end

            elem_ass:draw_stop()
            
            -- add tooltip
            if not (element.slider.tooltipF == nil) then
                if mouse_hit(element) then
                    local sliderpos = get_slider_value(element)
                    local tooltiplabel = element.slider.tooltipF(sliderpos)
                    local an = slider_lo.tooltip_an
                    local ty
                    if (an == 2) then
                        ty = element.hitbox.y1
                    else
                        ty = element.hitbox.y1 + elem_geo.h/2
                    end

                    local tx = get_virt_mouse_pos()
                    if (slider_lo.adjust_tooltip) then
                        if (an == 2) then
                            if (sliderpos < (s_min + 3)) then
                                an = an - 1
                            elseif (sliderpos > (s_max - 3)) then
                                an = an + 1
                            end
                        elseif (sliderpos > (s_max-s_min)/2) then
                            an = an + 1
                            tx = tx - 5
                        else
                            an = an - 1
                            tx = tx + 10
                        end
                    end

                    -- tooltip label
                    elem_ass:new_event()
                    elem_ass:pos(tx, ty)
                    elem_ass:an(an)
                    elem_ass:append(slider_lo.tooltip_style)
                    ass_append_alpha(elem_ass, slider_lo.alpha, 0)
                    elem_ass:append(tooltiplabel)
                    display_tn_osc(ty, sliderpos, elem_ass)
				else
					hide_thumbnail()
                end
            end

        elseif (element.type == "button") then

            local buttontext
            if type(element.content) == "function" then
                buttontext = element.content() -- function objects
            elseif not (element.content == nil) then
                buttontext = element.content -- text objects
            end
			
			buttontext = buttontext:gsub(":%((.?.?.?)%) unknown ", ":%(%1%)")  --gsub("%) unknown %(\"", "")

            local maxchars = element.layout.button.maxchars
            -- 认为1个中文字符约等于1.5个英文字符
            -- local charcount = buttontext:len()-  (buttontext:len()-select(2, buttontext:gsub("[^\128-\193]", "")))/1.5
            local charcount = (buttontext:len() + select(2, buttontext:gsub("[^\128-\193]", ""))*2) / 3
            if not (maxchars == nil) and (charcount > maxchars) then
                local limit = math.max(0, maxchars - 3)
                if (charcount > limit) then
                    while (charcount > limit) do
                        buttontext = buttontext:gsub(".[\128-\191]*$", "")
						charcount = (buttontext:len() + select(2, buttontext:gsub("[^\128-\193]", ""))*2) / 3
                    end
                    buttontext = buttontext .. "..."
                end
            end

            elem_ass:append(buttontext)
            
            -- add tooltip
			if not (element.tooltipF == nil) and element.enabled then
                if mouse_hit(element) then
                    local tooltiplabel = element.tooltipF
                    local an = 1
                    local ty = element.hitbox.y1
                    local tx = get_virt_mouse_pos()
                    
                    if ty < osc_param.playresy / 2 then
						ty = element.hitbox.y2
						an = 7
					end

                    -- tooltip label
                    if type(element.tooltipF) == "function" then
						tooltiplabel = element.tooltipF()
					else
						tooltiplabel = element.tooltipF
					end
                    elem_ass:new_event()
                    elem_ass:pos(tx, ty)
                    elem_ass:an(an)
                    elem_ass:append(element.tooltip_style)
                    elem_ass:append(tooltiplabel)
                end
			end
        end

        master_ass:merge(elem_ass)
    end
end

--
-- Message display
--

-- pos is 1 based
function limited_list(prop, pos)
    local proplist = mp.get_property_native(prop, {})
    local count = #proplist
    if count == 0 then
        return count, proplist
    end

    local fs = tonumber(mp.get_property('options/osd-font-size'))
    local max = math.ceil(osc_param.unscaled_y*0.75 / fs)
    if max % 2 == 0 then
        max = max - 1
    end
    local delta = math.ceil(max / 2) - 1
    local begi = math.max(math.min(pos - delta, count - max + 1), 1)
    local endi = math.min(begi + max - 1, count)

    local reslist = {}
    for i=begi, endi do
        local item = proplist[i]
        item.current = (i == pos) and true or nil
        table.insert(reslist, item)
    end
    return count, reslist
end

function get_playlist()
    local pos = mp.get_property_number('playlist-pos', 0) + 1
    local count, limlist = limited_list('playlist', pos)
    if count == 0 then
        return 'Empty playlist.'
    end

    local message = string.format('Playlist [%d/%d]:\n', pos, count)
    for i, v in ipairs(limlist) do
        local title = v.title
        local _, filename = utils.split_path(v.filename)
        if title == nil then
            title = filename
        end
        message = string.format('%s %s %s\n', message,
            (v.current and '●' or '○'), title)
    end
    return message
end

function get_chapterlist()
    local pos = mp.get_property_number('chapter', 0) + 1
    local count, limlist = limited_list('chapter-list', pos)
    if count == 0 then
        return 'No chapters.'
    end

    local message = string.format('Chapters [%d/%d]:\n', pos, count)
    for i, v in ipairs(limlist) do
        local time = mp.format_time(v.time)
        local title = v.title
        if title == nil then
            title = string.format('Chapter %02d', i)
        end
        message = string.format('%s[%s] %s %s\n', message, time,
            (v.current and '●' or '○'), title)
    end
    return message
end

function show_message(text, duration)

    --print("text: "..text.."   duration: " .. duration)
    if duration == nil then
        duration = tonumber(mp.get_property("options/osd-duration")) / 1000
    elseif not type(duration) == "number" then
        print("duration: " .. duration)
    end

    -- cut the text short, otherwise the following functions
    -- may slow down massively on huge input
    text = string.sub(text, 0, 4000)

    -- replace actual linebreaks with ASS linebreaks
    text = string.gsub(text, "\n", "\\N")

    state.message_text = text

    if not state.message_hide_timer then
        state.message_hide_timer = mp.add_timeout(0, request_tick)
    end
    state.message_hide_timer:kill()
    state.message_hide_timer.timeout = duration
    state.message_hide_timer:resume()
    request_tick()
end

function render_message(ass)
    if state.message_hide_timer and state.message_hide_timer:is_enabled() and
       state.message_text
    then
        local _, lines = string.gsub(state.message_text, "\\N", "")

        local fontsize = tonumber(mp.get_property("options/osd-font-size"))
        local outline = tonumber(mp.get_property("options/osd-border-size"))
        local maxlines = math.ceil(osc_param.unscaled_y*0.75 / fontsize)
        local counterscale = osc_param.playresy / osc_param.unscaled_y

        fontsize = fontsize * counterscale / math.max(0.65 + math.min(lines/maxlines, 1), 1)
        outline = outline * counterscale / math.max(0.75 + math.min(lines/maxlines, 1)/2, 1)

        local style = "{\\bord" .. outline .. "\\fs" .. fontsize .. "}"


        ass:new_event()
        ass:append(style .. state.message_text)
    else
        state.message_text = nil
    end
end

--
-- Initialisation and Layout
--

function new_element(name, type)
    elements[name] = {}
    elements[name].type = type

    -- add default stuff
    elements[name].eventresponder = {}
    elements[name].visible = true
    elements[name].enabled = true
    elements[name].softrepeat = false
    elements[name].styledown = (type == "button")
    elements[name].state = {}

    if (type == "slider") then
        elements[name].slider = {min = {value = 0}, max = {value = 100}}
    end


    return elements[name]
end

function add_layout(name)
    if not (elements[name] == nil) then
        -- new layout
        elements[name].layout = {}

        -- set layout defaults
        elements[name].layout.layer = 50
        elements[name].layout.alpha = {[1] = 0, [2] = 255, [3] = 255, [4] = 255}

        if (elements[name].type == "button") then
            elements[name].layout.button = {
                maxchars = nil,
            }
        elseif (elements[name].type == "slider") then
            -- slider defaults
            elements[name].layout.slider = {
                border = 1,
                gap = 1,
                nibbles_top = true,
                nibbles_bottom = true,
                adjust_tooltip = true,
                tooltip_style = "",
                tooltip_an = 2,
                alpha = {[1] = 0, [2] = 255, [3] = 88, [4] = 255},
            }
        elseif (elements[name].type == "box") then
            elements[name].layout.box = {radius = 0, hexagon = false}
        end

        return elements[name].layout
    else
        msg.error("Can't add_layout to element \""..name.."\", doesn't exist.")
    end
end

-- Window Controls
function window_controls(topbar)
    local wc_geo = {
        x = 0,
        y = 30 + user_opts.barmargin,
        an = 1,
        w = osc_param.playresx,
        h = 30,
    }

    local alignment = window_controls_alignment()
    local controlbox_w = window_control_box_width
    local titlebox_w = wc_geo.w - controlbox_w

    -- Default alignment is "right"
    local controlbox_left = wc_geo.w - controlbox_w
    local titlebox_left = wc_geo.x
    local titlebox_right = wc_geo.w - controlbox_w

    if alignment == "left" then
        controlbox_left = wc_geo.x
        titlebox_left = wc_geo.x + controlbox_w
        titlebox_right = wc_geo.w
    end

    add_area("window-controls",
             get_hitbox_coords(controlbox_left, wc_geo.y, wc_geo.an,
                               controlbox_w, wc_geo.h))

    local lo

    -- Background Bar
    new_element("wcbar", "box")
    lo = add_layout("wcbar")
    lo.geometry = wc_geo
    lo.layer = 10
    lo.style = osc_styles.wcBar
    lo.alpha[1] = user_opts.boxalpha

    local button_y = wc_geo.y - (wc_geo.h / 2)
    local first_geo =
        {x = controlbox_left + 5, y = button_y, an = 4, w = 25, h = 25}
    local second_geo =
        {x = controlbox_left + 30, y = button_y, an = 4, w = 25, h = 25}
    local third_geo =
        {x = controlbox_left + 55, y = button_y, an = 4, w = 25, h = 25}

    -- Window control buttons use symbols in the custom mpv osd font
    -- because the official unicode codepoints are sufficiently
    -- exotic that a system might lack an installed font with them,
    -- and libass will complain that they are not present in the
    -- default font, even if another font with them is available.

    -- Close: 🗙
    ne = new_element("close", "button")
    ne.content = "\238\132\149"
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("quit") end
    lo = add_layout("close")
    lo.geometry = alignment == "left" and first_geo or third_geo
    lo.style = osc_styles.wcButtons

    -- Minimize: 🗕
    ne = new_element("minimize", "button")
    ne.content = "\238\132\146"
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "window-minimized") end
    lo = add_layout("minimize")
    lo.geometry = alignment == "left" and second_geo or first_geo
    lo.style = osc_styles.wcButtons

    -- Maximize: 🗖 /🗗
    ne = new_element("maximize", "button")
    if state.maximized or state.fullscreen then
        ne.content = "\238\132\148"
    else
        ne.content = "\238\132\147"
    end
    ne.eventresponder["mbtn_left_up"] =
        function ()
            if state.fullscreen then
                mp.commandv("cycle", "fullscreen")
            else
                mp.commandv("cycle", "window-maximized")
            end
        end
    lo = add_layout("maximize")
    lo.geometry = alignment == "left" and third_geo or second_geo
    lo.style = osc_styles.wcButtons

    -- deadzone below window controls
    local sh_area_y0, sh_area_y1
    sh_area_y0 = user_opts.barmargin
    sh_area_y1 = (wc_geo.y + (wc_geo.h / 2)) +
                 get_align(1 - (2 * user_opts.deadzonesize),
                 osc_param.playresy - (wc_geo.y + (wc_geo.h / 2)), 0, 0)
    add_area("showhide_wc", wc_geo.x, sh_area_y0, wc_geo.w, sh_area_y1)

    if topbar then
        -- The title is already there as part of the top bar
        return
    else
        -- Apply boxvideo margins to the control bar
        osc_param.video_margins.t = wc_geo.h / osc_param.playresy
    end

    -- Window Title
    ne = new_element("wctitle", "button")
    ne.content = function ()
        local title = mp.command_native({"expand-text", user_opts.title})
        -- escape ASS, and strip newlines and trailing slashes
        title = title:gsub("\\n", " "):gsub("\\$", ""):gsub("{","\\{")
        return not (title == "") and title or "mpv"
    end
    local left_pad = 5
    local right_pad = 10
    lo = add_layout("wctitle")
    lo.geometry =
        { x = titlebox_left + left_pad, y = wc_geo.y - 3, an = 1,
          w = titlebox_w, h = wc_geo.h }
    lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}",
        osc_styles.wcTitle,
        titlebox_left + left_pad, wc_geo.y - wc_geo.h,
        titlebox_right - right_pad , wc_geo.y + wc_geo.h)

    add_area("window-controls-title",
             titlebox_left, 0, titlebox_right, wc_geo.h)
end

--
-- Layouts
--

local layouts = {}

-- Default layout
layouts = function ()

    local osc_geo = {w, h}

	osc_geo.w = osc_param.playresx
	osc_geo.h = 180

    -- origin of the controllers, left/bottom corner
    local posX = 0
    local posY = osc_param.playresy

    osc_param.areas = {} -- delete areas

    -- area for active mouse input
    add_area("input", get_hitbox_coords(posX, posY, 1, osc_geo.w, 104))

    -- area for show/hide
    add_area("showhide", 0, 0, osc_param.playresx, osc_param.playresy)

    -- fetch values
    local osc_w, osc_h=
        osc_geo.w, osc_geo.h

	--
    -- Controller Background
    --
	local lo

	new_element("TransBg", "box")
	lo = add_layout("TransBg")
	lo.geometry = {x = posX, y = posY, an = 7, w = osc_w, h = 1}
	lo.style = osc_styles.TransBg
	lo.layer = 10
	lo.alpha[3] = 0
	
    --
    -- Alignment
    --
	local refX = osc_w / 2
	local refY = posY
	local geo
	
    --
    -- Seekbar
    --
    new_element("bgbar1", "box")
    lo = add_layout("bgbar1")
    lo.geometry = {x = refX , y = refY - 96 , an = 5, w = osc_geo.w - 50, h = 2}
    lo.layer = 13
    lo.style = osc_styles.SeekbarBg
    lo.alpha[1] = 128
    lo.alpha[3] = 128

    lo = add_layout("seekbar")
    lo.geometry = {x = refX, y = refY - 96 , an = 5, w = osc_geo.w - 50, h = 16}
	lo.style = osc_styles.SeekbarFg
    lo.slider.gap = 7
    lo.slider.tooltip_style = osc_styles.Tooltip
    lo.slider.tooltip_an = 2
    
	-- buttons
    lo = add_layout("pl_prev")
    lo.geometry = {x = refX - 120, y = refY - 40 , an = 5, w = 30, h = 24}
    lo.style = osc_styles.Ctrl2

	lo = add_layout("skipback")
    lo.geometry = {x = refX - 60, y = refY - 40 , an = 5, w = 30, h = 24}
    lo.style = osc_styles.Ctrl2

			
    lo = add_layout("playpause")
    lo.geometry = {x = refX, y = refY - 40 , an = 5, w = 45, h = 45}
    lo.style = osc_styles.Ctrl1	

    lo = add_layout("skipfrwd")
    lo.geometry = {x = refX + 60, y = refY - 40 , an = 5, w = 30, h = 24}
    lo.style = osc_styles.Ctrl2	

    lo = add_layout("pl_next")
    lo.geometry = {x = refX + 120, y = refY - 40 , an = 5, w = 30, h = 24}
    lo.style = osc_styles.Ctrl2


	-- Time
    lo = add_layout("tc_left")
    lo.geometry = {x = 25, y = refY - 84, an = 7, w = 64, h = 20}
    lo.style = osc_styles.Time	
	

    lo = add_layout("tc_right")
    lo.geometry = {x = osc_geo.w - 25 , y = refY -84, an = 9, w = 64, h = 20}
    lo.style = osc_styles.Time	

    lo = add_layout("cy_audio")
	lo.geometry = {x = 37, y = refY - 40, an = 5, w = 24, h = 24}
    lo.style = osc_styles.Ctrl3	
	
    lo = add_layout("cy_sub")
    lo.geometry = {x = 87, y = refY - 40, an = 5, w = 24, h = 24}
    lo.style = osc_styles.Ctrl3

	lo = add_layout("tog_fs")
    lo.geometry = {x = osc_geo.w - 37, y = refY - 40, an = 5, w = 24, h = 24}
    lo.style = osc_styles.Ctrl3    

	lo = add_layout("tog_info")
    lo.geometry = {x = osc_geo.w - 87, y = refY - 40, an = 5, w = 24, h = 24}
    lo.style = osc_styles.Ctrl3
    
    geo = { x = 25, y = refY - 132, an = 1, w = osc_geo.w - 50, h = 48 }
    lo = add_layout("title")
    lo.geometry = geo
    lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}", osc_styles.Title,
								geo.x, geo.y - geo.h, geo.x + geo.w , geo.y)
	lo.alpha[3] = 0
end

-- Validate string type user options
function validate_user_opts()
    if user_opts.windowcontrols ~= "auto" and
       user_opts.windowcontrols ~= "yes" and
       user_opts.windowcontrols ~= "no" then
        msg.warn("windowcontrols cannot be \"" ..
                user_opts.windowcontrols .. "\". Ignoring.")
        user_opts.windowcontrols = "auto"
    end
    if user_opts.windowcontrols_alignment ~= "right" and
       user_opts.windowcontrols_alignment ~= "left" then
        msg.warn("windowcontrols_alignment cannot be \"" ..
                user_opts.windowcontrols_alignment .. "\". Ignoring.")
        user_opts.windowcontrols_alignment = "right"
    end
end

function update_options(list)
    validate_user_opts()
    request_tick()
    visibility_mode(user_opts.visibility, true)
    request_init()
end

-- OSC INIT
function osc_init()
    msg.debug("osc_init")

    -- set canvas resolution according to display aspect and scaling setting
    local baseResY = 720
    local display_w, display_h, display_aspect = mp.get_osd_size()
    local scale = 1

    if (mp.get_property("video") == "no") then -- dummy/forced window
        scale = user_opts.scaleforcedwindow
    elseif state.fullscreen then
        scale = user_opts.scalefullscreen
    else
        scale = user_opts.scalewindowed
    end

    if user_opts.vidscale then
        osc_param.unscaled_y = baseResY
    else
        osc_param.unscaled_y = display_h
    end
    osc_param.playresy = osc_param.unscaled_y / scale
    if (display_aspect > 0) then
        osc_param.display_aspect = display_aspect
    end
    osc_param.playresx = osc_param.playresy * osc_param.display_aspect

    -- stop seeking with the slider to prevent skipping files
    state.active_element = nil

    elements = {}

    -- some often needed stuff
    local pl_count = mp.get_property_number("playlist-count", 0)
    local have_pl = (pl_count > 1)
    local pl_pos = mp.get_property_number("playlist-pos", 0) + 1
    local have_ch = (mp.get_property_number("chapters", 0) > 0)
    local loop = mp.get_property("loop-playlist", "no")

    local ne

    -- playlist buttons
    -- prev
    ne = new_element("pl_prev", "button")

    ne.content = "\xEF\x8E\xB5"
    ne.enabled = (pl_pos > 1) or (loop ~= "no")
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("playlist-prev", "weak")
        end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_playlist()) end

    --next
    ne = new_element("pl_next", "button")

    ne.content = "\xEF\x8E\xB4"
    ne.enabled = (have_pl and (pl_pos < pl_count)) or (loop ~= "no")
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("playlist-next", "weak")
        end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_playlist()) end


    --play control buttons
    --playpause
    ne = new_element("playpause", "button")

    ne.content = function ()
        if mp.get_property("pause") == "yes" then
            return ("\xEF\x8E\xAA")
        else
            return ("\xEF\x8E\xA7")
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "pause") end
    --ne.eventresponder["mbtn_right_up"] =
    --    function () mp.commandv("script-binding", "open-file-dialog") end

    --skipback
    ne = new_element("skipback", "button")

    ne.softrepeat = true
    ne.content = "\xEF\x8E\xA0"
    ne.enabled = (have_ch) -- disables button when no chapters available.
    ne.eventresponder["mbtn_left_down"] =
        --function () mp.command("seek -5") end
        --function () mp.commandv("seek", -5, "relative", "keyframes") end
        function () mp.commandv("add", "chapter", -1) end
    --ne.eventresponder["shift+mbtn_left_down"] =
        --function () mp.commandv("frame-back-step") end
    ne.eventresponder["mbtn_right_down"] =
        function () show_message(get_chapterlist()) end
        --function () mp.command("seek -60") end
        --function () mp.commandv("seek", -60, "relative", "keyframes") end

    --skipfrwd
    ne = new_element("skipfrwd", "button")

    ne.softrepeat = true
    ne.content = "\xEF\x8E\x9F"
    ne.enabled = (have_ch) -- disables button when no chapters available.
    ne.eventresponder["mbtn_left_down"] =
        --function () mp.command("seek +5") end
        --function () mp.commandv("seek", 5, "relative", "keyframes") end
        function () mp.commandv("add", "chapter", 1) end
    --ne.eventresponder["shift+mbtn_left_down"] =
        --function () mp.commandv("frame-step") end
    ne.eventresponder["mbtn_right_down"] =
        function () show_message(get_chapterlist()) end
        --function () mp.command("seek +60") end
        --function () mp.commandv("seek", 60, "relative", "keyframes") end

    --
    update_tracklist()
    
    --cy_audio
    ne = new_element("cy_audio", "button")
    ne.enabled = (#tracks_osc.audio > 0)
    ne.visible = (osc_param.playresx >= 540)
    ne.content = "\xEF\x8E\xB7"
    ne.tooltip_style = osc_styles.Tooltip
    ne.tooltipF = function ()
		local msg = texts.off
        if not (get_track("audio") == 0) then
            msg = (texts.audio .. " [" .. get_track("audio") .. " ∕ " .. #tracks_osc.audio .. "] ")
            local prop = mp.get_property("current-tracks/audio/title") --("current-tracks/audio/lang")
            if not prop then
				prop = texts.na
			end
			msg = msg .. "[" .. prop .. "]"
			prop = mp.get_property("current-tracks/audio/lang") --("current-tracks/audio/title")
			if prop then
				msg = msg .. " " .. prop
			end
			return msg
        end
        return msg
    end
    ne.eventresponder["mbtn_left_up"] =
        function () set_track("audio", 1) end
    ne.eventresponder["mbtn_right_up"] =
        function () set_track("audio", -1) end
    ne.eventresponder["mbtn_mid_up"] =
        function () show_message(get_tracklist("audio")) end
                
    --cy_sub
    ne = new_element("cy_sub", "button")
    ne.enabled = (#tracks_osc.sub > 0)
    ne.visible = (osc_param.playresx >= 600)
    ne.content = "\xEF\x8F\x93"
    ne.tooltip_style = osc_styles.Tooltip
    ne.tooltipF = function ()
		local msg = texts.off
        if not (get_track("sub") == 0) then
            msg = (texts.subtitle .. " [" .. get_track("sub") .. " ∕ " .. #tracks_osc.sub .. "] ")
            local prop = mp.get_property("current-tracks/sub/lang")
            if not prop then
				prop = texts.na
			end
			msg = msg .. "[" .. prop .. "]"
			prop = mp.get_property("current-tracks/sub/title")
			if prop then
				msg = msg .. " " .. prop
			end
			return msg
        end
        return msg
    end
    ne.eventresponder["mbtn_left_up"] =
        function () set_track("sub", 1) end
    ne.eventresponder["mbtn_right_up"] =
        function () set_track("sub", -1) end
    ne.eventresponder["mbtn_mid_up"] =
        function () show_message(get_tracklist("sub")) end
        
    --tog_fs
    ne = new_element("tog_fs", "button")
    ne.content = function ()
        if (state.fullscreen) then
            return ("\xEF\x85\xAC")
        else
            return ("\xEF\x85\xAD")
        end
    end
    ne.visible = (osc_param.playresx >= 540)
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "fullscreen") end

    --tog_info
    ne = new_element("tog_info", "button")
    ne.content = ""
    ne.visible = (osc_param.playresx >= 600)
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("script-binding", "stats/display-stats-toggle") end

    -- title
    ne = new_element("title", "button")
    ne.content = function ()
		local title = mp.command_native({"expand-text", user_opts.title})
        if state.paused then
			title = title:gsub("\\n", " "):gsub("\\$", ""):gsub("{","\\{")
		else
			title = title:gsub("\\n", " "):gsub("\\$", ""):gsub("{","\\{") --title = " "
		end
        return not (title == "") and title or " "
    end
    ne.visible = osc_param.playresy >= 320 and user_opts.showtitle
    
    --seekbar
    ne = new_element("seekbar", "slider")

    ne.enabled = not (mp.get_property("percent-pos") == nil)
    ne.slider.markerF = function ()
        local duration = mp.get_property_number("duration", nil)
        if not (duration == nil) then
            local chapters = mp.get_property_native("chapter-list", {})
            local markers = {}
            for n = 1, #chapters do
                markers[n] = (chapters[n].time / duration * 100)
            end
            return markers
        else
            return {}
        end
    end
    ne.slider.posF =
        function () return mp.get_property_number("percent-pos", nil) end
    ne.slider.tooltipF = function (pos)
        local duration = mp.get_property_number("duration", nil)
        if not ((duration == nil) or (pos == nil)) then
            possec = duration * (pos / 100)
            return mp.format_time(possec)
        else
            return ""
        end
    end
    ne.slider.seekRangesF = function()
        if not user_opts.seekrange then
            return nil
        end
        local cache_state = state.cache_state
        if not cache_state then
            return nil
        end
        local duration = mp.get_property_number("duration", nil)
        if (duration == nil) or duration <= 0 then
            return nil
        end
        local ranges = cache_state["seekable-ranges"]
        if #ranges == 0 then
            return nil
        end
        local nranges = {}
        for _, range in pairs(ranges) do
            nranges[#nranges + 1] = {
                ["start"] = 100 * range["start"] / duration,
                ["end"] = 100 * range["end"] / duration,
            }
        end
        return nranges
    end
    ne.eventresponder["mouse_move"] = --keyframe seeking when mouse is dragged
        function (element)
			if not element.state.mbtnleft then return end -- allow drag for mbtnleft only!
            -- mouse move events may pile up during seeking and may still get
            -- sent when the user is done seeking, so we need to throw away
            -- identical seeks
            local seekto = get_slider_value(element)
            if (element.state.lastseek == nil) or
                (not (element.state.lastseek == seekto)) then
                    local flags = "absolute-percent"
                    if not user_opts.seekbarkeyframes then
                        flags = flags .. "+exact"
                    end
                    mp.commandv("seek", seekto, flags)
                    element.state.lastseek = seekto
            end

        end
    ne.eventresponder["mbtn_left_down"] = --exact seeks on single clicks
        function (element)
			mp.commandv("seek", get_slider_value(element), "absolute-percent", "exact")
			element.state.mbtnleft = true
		end
	ne.eventresponder["mbtn_left_up"] =
		function (element) element.state.mbtnleft = false end
    ne.eventresponder["mbtn_right_down"] = --seeks to chapter start
        function (element)
			local duration = mp.get_property_number("duration", nil)
			if not (duration == nil) then
				local chapters = mp.get_property_native("chapter-list", {})
				if #chapters > 0 then
					local pos = get_slider_value(element)
					local ch = #chapters
					for n = 1, ch do
						if chapters[n].time / duration * 100 >= pos then
							ch = n - 1
							break
						end
					end
					mp.commandv("set", "chapter", ch - 1)
					--if chapters[ch].title then show_message(chapters[ch].time) end
				end
			end
		end
    ne.eventresponder["reset"] =
        function (element) element.state.lastseek = nil end


    -- tc_left (current pos)
    ne = new_element("tc_left", "button")
    ne.content = function ()
	if (state.fulltime) then
		return (mp.get_property_osd("playback-time/full"))
	else
		return (mp.get_property_osd("playback-time"))
	end
    end
    ne.eventresponder["mbtn_left_up"] = function ()
        state.fulltime = not state.fulltime
        request_init()
    end
    -- tc_right (total/remaining time)
    ne = new_element("tc_right", "button")
    ne.content = function ()
        if (mp.get_property_number("duration", 0) <= 0) then return "--:--:--" end
        if (state.rightTC_trem) then
		if (state.fulltime) then
			return ("-"..mp.get_property_osd("playtime-remaining/full"))
		else
			return ("-"..mp.get_property_osd("playtime-remaining"))
		end
        else
		if (state.fulltime) then
			return (mp.get_property_osd("duration/full"))
		else
			return (mp.get_property_osd("duration"))
		end
			
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () state.rightTC_trem = not state.rightTC_trem end

    -- load layout
    layouts()

    -- load window controls
    if window_controls_enabled() then
        window_controls()
    end

    --do something with the elements
    prepare_elements()
end

function shutdown()
    
end

--
-- Other important stuff
--


function show_osc()
    -- show when disabled can happen (e.g. mouse_move) due to async/delayed unbinding
    if not state.enabled then return end

    msg.trace("show_osc")
    --remember last time of invocation (mouse move)
    state.showtime = mp.get_time()

    osc_visible(true)

    if (user_opts.fadeduration > 0) then
        state.anitype = nil
    end
end

function hide_osc()
    msg.trace("hide_osc")
    if not state.enabled then
        -- typically hide happens at render() from tick(), but now tick() is
        -- no-op and won't render again to remove the osc, so do that manually.
        state.osc_visible = false
        render_wipe()
    elseif (user_opts.fadeduration > 0) then
        if not(state.osc_visible == false) then
            state.anitype = "out"
            request_tick()
        end
    else
        osc_visible(false)
    end
end

function osc_visible(visible)
    if state.osc_visible ~= visible then
        state.osc_visible = visible
    end
    request_tick()
end

function pause_state(name, enabled)
    state.paused = enabled
    if user_opts.showonpause then
		if enabled then
			state.lastvisibility = user_opts.visibility
			visibility_mode("always", true)
			show_osc()
		else
			visibility_mode(state.lastvisibility, true)
		end
	end
    request_tick()
end

function cache_state(name, st)
    state.cache_state = st
    request_tick()
end

-- Request that tick() is called (which typically re-renders the OSC).
-- The tick is then either executed immediately, or rate-limited if it was
-- called a small time ago.
function request_tick()
    if state.tick_timer == nil then
        state.tick_timer = mp.add_timeout(0, tick)
    end

    if not state.tick_timer:is_enabled() then
        local now = mp.get_time()
        local timeout = tick_delay - (now - state.tick_last_time)
        if timeout < 0 then
            timeout = 0
        end
        state.tick_timer.timeout = timeout
        state.tick_timer:resume()
    end
end

function mouse_leave()
    if get_hidetimeout() >= 0 then
        hide_osc()
    end
    -- reset mouse position
    state.last_mouseX, state.last_mouseY = nil, nil
    state.mouse_in_window = false
end

function request_init()
    state.initREQ = true
    request_tick()
end

-- Like request_init(), but also request an immediate update
function request_init_resize()
    request_init()
    -- ensure immediate update
    state.tick_timer:kill()
    state.tick_timer.timeout = 0
    state.tick_timer:resume()
end

function render_wipe()
    msg.trace("render_wipe()")
    state.osd:remove()
end

function render()
    msg.trace("rendering")
    local current_screen_sizeX, current_screen_sizeY, aspect = mp.get_osd_size()
    local mouseX, mouseY = get_virt_mouse_pos()
    local now = mp.get_time()

    -- check if display changed, if so request reinit
    if not (state.mp_screen_sizeX == current_screen_sizeX
        and state.mp_screen_sizeY == current_screen_sizeY) then

        request_init_resize()

        state.mp_screen_sizeX = current_screen_sizeX
        state.mp_screen_sizeY = current_screen_sizeY
    end

    -- init management
    if state.initREQ then
        osc_init()
        state.initREQ = false

        -- store initial mouse position
        if (state.last_mouseX == nil or state.last_mouseY == nil)
            and not (mouseX == nil or mouseY == nil) then

            state.last_mouseX, state.last_mouseY = mouseX, mouseY
        end
    end


    -- fade animation
    if not(state.anitype == nil) then

        if (state.anistart == nil) then
            state.anistart = now
        end

        if (now < state.anistart + (user_opts.fadeduration/1000)) then

            if (state.anitype == "in") then --fade in
                osc_visible(true)
                state.animation = scale_value(state.anistart,
                    (state.anistart + (user_opts.fadeduration/1000)),
                    255, 0, now)
            elseif (state.anitype == "out") then --fade out
                state.animation = scale_value(state.anistart,
                    (state.anistart + (user_opts.fadeduration/1000)),
                    0, 255, now)
            end

        else
            if (state.anitype == "out") then
                osc_visible(false)
            end
            state.anistart = nil
            state.animation = nil
            state.anitype =  nil
        end
    else
        state.anistart = nil
        state.animation = nil
        state.anitype =  nil
    end

    --mouse show/hide area
    for k,cords in pairs(osc_param.areas["showhide"]) do
        set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide")
    end
    if osc_param.areas["showhide_wc"] then
        for k,cords in pairs(osc_param.areas["showhide_wc"]) do
            set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide_wc")
        end
    else
        set_virt_mouse_area(0, 0, 0, 0, "showhide_wc")
    end
    do_enable_keybindings()

    --mouse input area
    local mouse_over_osc = false

    for _,cords in ipairs(osc_param.areas["input"]) do
        if state.osc_visible then -- activate only when OSC is actually visible
            set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "input")
        end
        if state.osc_visible ~= state.input_enabled then
            if state.osc_visible then
                mp.enable_key_bindings("input")
            else
                mp.disable_key_bindings("input")
            end
            state.input_enabled = state.osc_visible
        end

        if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
            mouse_over_osc = true
        end
    end

    if osc_param.areas["window-controls"] then
        for _,cords in ipairs(osc_param.areas["window-controls"]) do
            if state.osc_visible then -- activate only when OSC is actually visible
                set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "window-controls")
                mp.enable_key_bindings("window-controls")
            else
                mp.disable_key_bindings("window-controls")
            end

            if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
                mouse_over_osc = true
            end
        end
    end

    if osc_param.areas["window-controls-title"] then
        for _,cords in ipairs(osc_param.areas["window-controls-title"]) do
            if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
                mouse_over_osc = true
            end
        end
    end

    -- autohide
    if not (state.showtime == nil) and (get_hidetimeout() >= 0) then
        local timeout = state.showtime + (get_hidetimeout()/1000) - now
        if timeout <= 0 then
            if (state.active_element == nil) and not (mouse_over_osc) then
                hide_osc()
            end
        else
            -- the timer is only used to recheck the state and to possibly run
            -- the code above again
            if not state.hide_timer then
                state.hide_timer = mp.add_timeout(0, tick)
            end
            state.hide_timer.timeout = timeout
            -- re-arm
            state.hide_timer:kill()
            state.hide_timer:resume()
        end
    end


    -- actual rendering
    local ass = assdraw.ass_new()

    -- Messages
    render_message(ass)

    -- actual OSC
    if state.osc_visible then
        render_elements(ass)
    else
    	hide_thumbnail()
    end

    -- submit
    set_osd(osc_param.playresy * osc_param.display_aspect,
            osc_param.playresy, ass.text)
end

--
-- Eventhandling
--

local function element_has_action(element, action)
    return element and element.eventresponder and
        element.eventresponder[action]
end

function process_event(source, what)
    local action = string.format("%s%s", source,
        what and ("_" .. what) or "")

    if what == "down" or what == "press" then

        for n = 1, #elements do

            if mouse_hit(elements[n]) and
                elements[n].eventresponder and
                (elements[n].eventresponder[source .. "_up"] or
                    elements[n].eventresponder[action]) then

                if what == "down" then
                    state.active_element = n
                    state.active_event_source = source
                end
                -- fire the down or press event if the element has one
                if element_has_action(elements[n], action) then
                    elements[n].eventresponder[action](elements[n])
                end

            end
        end

    elseif what == "up" then

        if elements[state.active_element] then
            local n = state.active_element

            if n == 0 then
                --click on background (does not work)
            elseif element_has_action(elements[n], action) and
                mouse_hit(elements[n]) then

                elements[n].eventresponder[action](elements[n])
            end

            --reset active element
            if element_has_action(elements[n], "reset") then
                elements[n].eventresponder["reset"](elements[n])
            end

        end
        state.active_element = nil
        state.mouse_down_counter = 0

    elseif source == "mouse_move" then

        state.mouse_in_window = true

        local mouseX, mouseY = get_virt_mouse_pos()
        if (user_opts.minmousemove == 0) or
            (not ((state.last_mouseX == nil) or (state.last_mouseY == nil)) and
                ((math.abs(mouseX - state.last_mouseX) >= user_opts.minmousemove)
                    or (math.abs(mouseY - state.last_mouseY) >= user_opts.minmousemove)
                )
            ) then
            show_osc()
        end
        state.last_mouseX, state.last_mouseY = mouseX, mouseY

        local n = state.active_element
        if element_has_action(elements[n], action) then
            elements[n].eventresponder[action](elements[n])
        end
        request_tick()
    end
end

function show_logo()
	local osd_w, osd_h = 640, 360
	local logo_x, logo_y = osd_w/2, osd_h/2-20
	local ass = assdraw.ass_new()
	ass:new_event()
	ass:pos(logo_x, logo_y)
	ass:append("{\\1c&H8E348D&\\3c&H0&\\3a&H60&\\blur1\\bord0.5}")
	ass:draw_start()
	ass_draw_cir_cw(ass, 0, 0, 100)
	ass:draw_stop()
	
	ass:new_event()
	ass:pos(logo_x, logo_y)
	ass:append("{\\1c&H632462&\\bord0}")
	ass:draw_start()
	ass_draw_cir_cw(ass, 6, -6, 75)
	ass:draw_stop()

	ass:new_event()
	ass:pos(logo_x, logo_y)
	ass:append("{\\1c&HFFFFFF&\\bord0}")
	ass:draw_start()
	ass_draw_cir_cw(ass, -4, 4, 50)
	ass:draw_stop()
		
	ass:new_event()
	ass:pos(logo_x, logo_y)
	ass:append("{\\1c&H632462&\\bord&}")
	ass:draw_start()
	ass:move_to(-20, -20)
	ass:line_to(23.3, 5)
	ass:line_to(-20, 30)
	ass:draw_stop()
	
	ass:new_event()
	ass:pos(logo_x, logo_y+110)
	ass:an(8)
	ass:append(texts.welcome)
	set_osd(osd_w, osd_h, ass.text)
end

-- called by mpv on every frame
function tick()
    if (not state.enabled) then return end

    if (state.idle) then
		show_logo()
        -- render idle message
        msg.trace("idle message")

        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
            state.showhide_enabled = false
        end


    elseif (state.fullscreen and user_opts.showfullscreen)
        or (not state.fullscreen and user_opts.showwindowed) then

        -- render the OSC
        render()
    else
        -- Flush OSD
        set_osd(osc_param.playresy, osc_param.playresy, "")
    end

    state.tick_last_time = mp.get_time()

    if state.anitype ~= nil then
        request_tick()
    end
end

function do_enable_keybindings()
    if state.enabled then
        if not state.showhide_enabled then
            mp.enable_key_bindings("showhide", "allow-vo-dragging+allow-hide-cursor")
            mp.enable_key_bindings("showhide_wc", "allow-vo-dragging+allow-hide-cursor")
        end
        state.showhide_enabled = true
    end
end

function enable_osc(enable)
    state.enabled = enable
    if enable then
        do_enable_keybindings()
    else
        hide_osc() -- acts immediately when state.enabled == false
        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
        end
        state.showhide_enabled = false
    end
end

validate_user_opts()

mp.register_event("shutdown", shutdown)
mp.register_event("start-file", request_init)
mp.observe_property("track-list", nil, request_init)
mp.observe_property("playlist", nil, request_init)

mp.register_script_message("osc-message", show_message)
mp.register_script_message("osc-chapterlist", function(dur)
    show_message(get_chapterlist(), dur)
end)
mp.register_script_message("osc-playlist", function(dur)
    show_message(get_playlist(), dur)
end)
mp.register_script_message("osc-tracklist", function(dur)
    local msg = {}
    for k,v in pairs(nicetypes) do
        table.insert(msg, get_tracklist(k))
    end
    show_message(table.concat(msg, '\n\n'), dur)
end)

mp.observe_property("fullscreen", "bool",
    function(name, val)
        state.fullscreen = val
        request_init_resize()
    end
)
mp.observe_property("border", "bool",
    function(name, val)
        state.border = val
        request_init_resize()
    end
)
mp.observe_property("window-maximized", "bool",
    function(name, val)
        state.maximized = val
        request_init_resize()
    end
)
mp.observe_property("idle-active", "bool",
    function(name, val)
        state.idle = val
        request_tick()
    end
)
mp.observe_property("pause", "bool", pause_state)
mp.observe_property("demuxer-cache-state", "native", cache_state)
mp.observe_property("vo-configured", "bool", function(name, val)
    request_tick()
end)
mp.observe_property("playback-time", "number", function(name, val)
    request_tick()
end)
mp.observe_property("osd-dimensions", "native", function(name, val)
    -- (we could use the value instead of re-querying it all the time, but then
    --  we might have to worry about property update ordering)
    request_init_resize()
end)

-- mouse show/hide bindings
mp.set_key_bindings({
    {"mouse_move",              function(e) process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide", "force")
mp.set_key_bindings({
    {"mouse_move",              function(e) process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide_wc", "force")
do_enable_keybindings()

--mouse input bindings
mp.set_key_bindings({
    {"mbtn_left",           function(e) process_event("mbtn_left", "up") end,
                            function(e) process_event("mbtn_left", "down")  end},
    {"mbtn_right",          function(e) process_event("mbtn_right", "up") end,
                            function(e) process_event("mbtn_right", "down")  end},
    {"mbtn_mid",            function(e) process_event("mbtn_mid", "up") end,
                            function(e) process_event("mbtn_mid", "down")  end},
    {"wheel_up",            function(e) process_event("wheel_up", "press") end},
    {"wheel_down",          function(e) process_event("wheel_down", "press") end},
    {"mbtn_left_dbl",       "ignore"},
    {"mbtn_right_dbl",      "ignore"},
}, "input", "force")
mp.enable_key_bindings("input")

mp.set_key_bindings({
    {"mbtn_left",           function(e) process_event("mbtn_left", "up") end,
                            function(e) process_event("mbtn_left", "down")  end},
}, "window-controls", "force")
mp.enable_key_bindings("window-controls")

function get_hidetimeout()
    if user_opts.visibility == "always" then
        return -1 -- disable autohide
    end
    return user_opts.hidetimeout
end

function always_on(val)
    if state.enabled then
        if val then
            show_osc()
        else
            hide_osc()
        end
    end
end

-- mode can be auto/always/never/cycle
-- the modes only affect internal variables and not stored on its own.
function visibility_mode(mode, no_osd)
    if mode == "auto" then
        always_on(false)
        enable_osc(true)
    elseif mode == "always" then
        enable_osc(true)
        always_on(true)
    elseif mode == "never" then
        enable_osc(false)
    else
        msg.warn("Ignoring unknown visibility mode '" .. mode .. "'")
        return
    end
    
	user_opts.visibility = mode
	
    if not no_osd and tonumber(mp.get_property("osd-level")) >= 1 then
        mp.osd_message("OSC visibility: " .. mode)
    end

    -- Reset the input state on a mode change. The input state will be
    -- recalcuated on the next render cycle, except in 'never' mode where it
    -- will just stay disabled.
    mp.disable_key_bindings("input")
    mp.disable_key_bindings("window-controls")
    state.input_enabled = false
    request_tick()
end

visibility_mode(user_opts.visibility, true)
mp.register_script_message("osc-visibility", visibility_mode)
mp.add_key_binding(nil, "visibility", function() visibility_mode("cycle") end)

set_virt_mouse_area(0, 0, 0, 0, "input")
set_virt_mouse_area(0, 0, 0, 0, "window-controls")