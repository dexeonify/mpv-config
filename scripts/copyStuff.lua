require 'mp'
require 'mp.msg'

-- Copy:
-- Filename or URL
-- Full Filename Path
-- Current Video Time
-- Current Video Duration
-- Current Displayed Subtitle
-- Video Metadata

WINDOWS = 2
UNIX = 3

local function platform_type()
    local utils = require 'mp.utils'
    local workdir = utils.to_string(mp.get_property_native("working-directory"))
    if string.find(workdir, "\\") then
        return WINDOWS
    else
        return UNIX
    end
end

local function command_exists(cmd)
    local pipe = io.popen("type " .. cmd .. " > /dev/null 2> /dev/null; printf \"$?\"", "r")
    exists = pipe:read() == "0"
    pipe:close()
    return exists
end

local function get_clipboard_cmd()
    if command_exists("xclip") then
        return "xclip -silent -in -selection clipboard"
    elseif command_exists("wl-copy") then
        return "wl-copy"
    elseif command_exists("pbcopy") then
        return "pbcopy"
    else
        mp.msg.error("No supported clipboard command found")
        return false
    end
end

local function divmod(a, b)
    return a / b, a % b
end

local function set_clipboard(text)
    if platform == WINDOWS then
        mp.commandv("run", "powershell", "set-clipboard", table.concat({'"', text, '"'}))
        return true
    elseif (platform == UNIX and clipboard_cmd) then
        local pipe = io.popen(clipboard_cmd, "w")
        pipe:write(text)
        pipe:close()
        return true
    else
        mp.msg.error("Set_clipboard error")
        return false
    end
end

-- Copy Time
local function copyTime()
    local time_pos = mp.get_property_number("time-pos")
    local minutes, remainder = divmod(time_pos, 60)
    local hours, minutes = divmod(minutes, 60)
    local seconds = math.floor(remainder)
    local milliseconds = math.floor((remainder - seconds) * 1000)
    local time = string.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    if set_clipboard(time) then
        mp.osd_message(string.format("Time Copied to Clipboard: %s", time))
    else
        mp.osd_message("Failed to copy time to clipboard")
    end
end

-- Copy Filename with Extension
local function copyFilename()
    local filename = string.format("%s", mp.get_property_osd("filename"))
    local extension = string.match(filename, "%.(%w+)$")

    local succ_message = "Filename Copied to Clipboard"
    local fail_message = "Failed to copy filename to clipboard"

    -- If filename doesn't have an extension then it is a URL.
    if not extension then
        filename = mp.get_property_osd("path")

        succ_message = "URL Copied to Clipboard"
        fail_message = "Failed to copy URL to clipboard"
    end

    if set_clipboard(filename) then
        mp.osd_message(string.format("%s: %s", succ_message, filename))
    else
        mp.osd_message(string.format("%s", fail_message))
    end
end

-- Copy Full Filename Path
local function copyFullPath()
    if platform == WINDOWS then
        full_path = string.format("%s\\%s", mp.get_property_osd("working-directory"), mp.get_property_osd("path"))
    else
        full_path = string.format("%s/%s", mp.get_property_osd("working-directory"), mp.get_property_osd("path"))
    end

    if set_clipboard(full_path) then
        mp.osd_message(string.format("Full Filename Path Copied to Clipboard: %s", full_path))
    else
        mp.osd_message("Failed to copy full filename path to clipboard")
    end
end

-- Copy Current Displayed Subtitle
local function copySubtitle()
    local subtitle = string.format("%s", mp.get_property_osd("sub-text"))

    if subtitle == "" then
        mp.osd_message("There are no displayed subtitles.")
        return
    end

    if set_clipboard(subtitle) then
        mp.osd_message(string.format("Displayed Subtitle Copied to Clipboard: %s", subtitle))
    else
        mp.osd_message("Failed to copy displayed subtitle to clipboard")
    end
end

-- Copy Current Video Duration
local function copyDuration()
    local duration = string.format("%s", mp.get_property_osd("duration"))

    if set_clipboard(duration) then
        mp.osd_message(string.format("Video Duration Copied to Clipboard: %s", duration))
    else
        mp.osd_message("Failed to copy video duration to clipboard")
    end
end

-- Copy Current Video Metadata
local function copyMetadata()
    local metadata = string.format("%s", mp.get_property_osd("metadata"))

    if set_clipboard(metadata) then
        mp.osd_message(string.format("Video Metadata Copied to Clipboard: %s", metadata))
    else
        mp.osd_message("Failed to copy metadata to clipboard")
    end
end

platform = platform_type()
if platform == UNIX then
    clipboard_cmd = get_clipboard_cmd()
end

-- Key-Bindings
mp.add_key_binding(nil, "copyTime", copyTime)
mp.add_key_binding(nil, "copyFilename", copyFilename)
mp.add_key_binding(nil, "copyFullPath", copyFullPath)
mp.add_key_binding(nil, "copySubtitle", copySubtitle)
mp.add_key_binding(nil, "copyDuration", copyDuration)
mp.add_key_binding(nil, "copyMetadata", copyMetadata)
