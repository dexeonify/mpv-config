-- Original script from https://github.com/occivink/mpv-scripts/blob/master/scripts/seek-to.lua

local assdraw = require 'mp.assdraw'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local platform = mp.get_property_native("platform")
local active = false
local cursor_position = 1
local time_scale = {60*60*10, 60*60, 60*10, 60, 10, 1, 0.1, 0.01, 0.001}

local ass_begin = mp.get_property("osd-ass-cc/0")
local ass_end = mp.get_property("osd-ass-cc/1")

local history = { {} }
for i = 1, 9 do
    history[1][i] = 0
end
local history_position = 1

-- timer to redraw periodically the message
-- to avoid leaving bindings when the seeker disappears for whatever reason
-- pretty hacky tbh
local timer_duration = 3
local blink_timer = nil
local blink_rate = 2    -- (1 / blink_rate)

local selection_color = "{\\c&46CFFF&}"
local selection_border_color = ""   -- "{\\3c&H0000FF&}"

local underline_on = "{\\u1}"   -- Enable underline
local underline_off = "{\\u0}"  -- Disable underline
local underline_forced = true   -- Always start with underline on

local ss = "{\\fscx0}"          -- Scale 0 to limit additional width of the hairspace
local se = "{\\fscx100}"        -- Reset scale
-- Insert 'hair space' after first digit to avoid shifting
-- when two 1's are beside each other (11:11:11.111)
local hs = ss .. string.char(0xE2, 0x80, 0x8A) .. se

function show_seeker()
    local prepend_char = {'',''..hs,':',''..hs,':',''..hs,'.',''..hs,''..hs}
    local str = ''
    for i = 1, 9 do
        str = str .. prepend_char[i]
        if i == cursor_position then
            -- Force underline into _on state on start or after switching to another digit
            if underline_forced or digit_switched then
                underline = underline_on
                underline_forced = false
                digit_switched = false
            else
                underline = (mp.get_time() * blink_rate % 2 < 1) and underline_on or underline_off
            end
            str = str .. '{\\b1}' .. selection_color .. selection_border_color
                .. underline .. history[history_position][i] .. '{\\r}'
        else
            str = str .. history[history_position][i]
        end
    end
    mp.osd_message("Seek to: " .. ass_begin .. str .. ass_end, timer_duration)
end

function copy_history_to_last()
    if history_position ~= #history then
        for i = 1, 9 do
            history[#history][i] = history[history_position][i]
        end
        history_position = #history
    end
end

function change_number(i)
    -- can't set above 60 minutes or seconds
    if (cursor_position == 3 or cursor_position == 5) and i >= 6 then
        return
    end
    if history[history_position][cursor_position] ~= i then
        copy_history_to_last()
        history[#history][cursor_position] = i
    end
    shift_cursor(false)
end

function shift_cursor(left)
    if left then
        cursor_position = math.max(1, cursor_position - 1)
    else
        cursor_position = math.min(cursor_position + 1, 9)
    end
    digit_switched = true
end

function current_time_as_sec(time)
    local sec = 0
    for i = 1, 9 do
        sec = sec + time_scale[i] * time[i]
    end
    return sec
end

function time_equal(lhs, rhs)
    for i = 1, 9 do
        if lhs[i] ~= rhs[i] then
            return false
        end
    end
    return true
end

function seek_to()
    copy_history_to_last()
    mp.commandv("osd-bar", "seek", current_time_as_sec(history[history_position]), "absolute")
    --deduplicate consecutive timestamps
    if #history == 1 or not time_equal(history[history_position], history[#history - 1]) then
        history[#history + 1] = {}
        history_position = #history
    end
    for i = 1, 9 do
        history[#history][i] = 0
    end
end

function backspace()
    if history[history_position][cursor_position] ~= 0 then
        copy_history_to_last()
        history[#history][cursor_position] = 0
    end
    shift_cursor(true)
end

function history_move(up)
    if up then
        history_position = math.max(1, history_position - 1)
    else
        history_position = math.min(history_position + 1, #history)
    end
end

local key_mappings = {
    LEFT  = function() shift_cursor(true) show_seeker() end,
    RIGHT = function() shift_cursor(false) show_seeker() end,
    UP    = function() history_move(true) show_seeker() end,
    DOWN  = function() history_move(false) show_seeker() end,
    BS    = function() backspace() show_seeker() end,
    ESC   = function() set_inactive() end,
    ENTER = function() seek_to() set_inactive() end,
    KP_ENTER = function() seek_to() set_inactive() end,
    ["Ctrl+v"] = function() paste_timestamp() end
}
for i = 0, 9 do
    local func = function() change_number(i) show_seeker() end
    key_mappings[string.format("KP%d", i)] = func
    key_mappings[string.format("%d", i)] = func
end

function set_active()
    if not mp.get_property("seekable") then return end
    -- find duration of the video and set cursor position accordingly
    local duration = mp.get_property_number("duration")
    if duration ~= nil then
        for i = 1, 9 do
            if duration > time_scale[i] then
                cursor_position = i
                break
            end
        end
    end
    for key, func in pairs(key_mappings) do
        mp.add_forced_key_binding(key, "seek-to-"..key, func, {repeatable=true})
    end
    show_seeker()
    active = true
    blink_timer = mp.add_periodic_timer(1 / blink_rate, show_seeker)
end

function set_inactive()
    mp.osd_message("")
    for key, _ in pairs(key_mappings) do
        mp.remove_key_binding("seek-to-"..key)
    end
    -- Reset timestamp to 0 when closed after entering it manually
    for i = 1, 9 do
        history[#history][i] = 0
    end
    -- Reset timestamp to 0 when closed while history entry was selected
    history_position = #history
    underline_forced = true
    active = false
    blink_timer:kill()
end

function subprocess(args)
    local cmd = {
        name = "subprocess",
        args = args,
        playback_only = false,
        capture_stdout = true
    }
    local res = mp.command_native(cmd)
    if not res.error then
        return res.stdout
    else
        msg.error("Error getting data from clipboard")
        return
    end
end

function get_clipboard()
    local res
    if platform == "windows" then
        res = subprocess({ "powershell", "-Command", "Get-Clipboard", "-Raw" })
    elseif platform == "darwin" then
        res = subprocess({ "pbpaste" })
    elseif platform == "linux" then
        if os.getenv("WAYLAND_DISPLAY") then
            res = subprocess({ "wl-paste", "-n" })
        else
            res = subprocess({ "xclip", "-selection", "clipboard", "-out" })
        end
    end
    return res
end

function paste_timestamp()
    local clipboard = get_clipboard()
    if clipboard == nil then return end

    local hours, minutes, seconds, milliseconds = clipboard:match("(%d+):(%d+):(%d+)%.?(%d*)")
    if not hours then
        minutes, seconds, milliseconds = clipboard:match("(%d+):(%d+)%.?(%d*)")
        hours = 0
        if not minutes then
            seconds, milliseconds = clipboard:match("(%d+)%.?(%d*)")
            minutes = 0
        end
    end

    if seconds then
        local total_seconds = tonumber(seconds)
        -- Convert available seconds to minutes
        minutes = minutes + math.floor(total_seconds / 60)
        seconds = total_seconds % 60
    end
    if minutes then
        local total_minutes = tonumber(minutes)
        -- Convert available minutes to hours
        hours   = hours + math.floor(total_minutes / 60)
        minutes = total_minutes % 60
    end

    if hours and minutes and seconds then
        milliseconds = milliseconds and (milliseconds .. string.rep("0", 3 - #milliseconds)):sub(1, 3) or 0

        -- Format timestamp HH:MM:SS:sss
        local timestamp = string.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
        -- Total time in seconds
        local timestamp_time = hours * 3600 + minutes * 60 + seconds + milliseconds / 1000
        local duration = mp.get_property_number("duration")
        -- If the total time is greater than the duration, return without seeking
        if timestamp_time > duration then
            set_inactive()
            mp.osd_message("Timestamp pasted exceeds the video duration!")
            msg.warn(timestamp .. " exceeds the video duration!")
            return
        end

        -- Split the formatted timestamp into individual digits
        local timestamp_digits = {timestamp:match("(%d)(%d):(%d)(%d):(%d)(%d)%.(%d)(%d)(%d)")}
        -- Add the pasted timestamp to the history table
        for i = 1, 9 do
            history[#history][i] = tonumber(timestamp_digits[i])
        end
        -- Add a new entry if the current timestamp is different from the last one in the history
        if #history == 1 or not time_equal(history[history_position], history[#history - 1]) then
            history[#history + 1] = {}
            history_position = #history
        end

        set_inactive()
        mp.osd_message("Seeking to: " .. timestamp)
        mp.commandv("osd-bar", "seek", timestamp, "absolute")
    else
        set_inactive()
        mp.osd_message("No pastable timestamp found!")
        msg.warn("No pastable timestamp found!")
    end
end

mp.add_key_binding(nil, "toggle-seeker", function() if active then set_inactive() else set_active() end end)
