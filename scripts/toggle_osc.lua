local OSC_PEEK_SEC = 0.5
local CLEAR_OSD_TIMEOUT = .01 -- Hack for clearing OSD message upon OSC toggle

-- Assume initial mode is 'auto', actual mode is in osc.lua and cannot be read
local osc_always_on = false

local function toggle_osc_auto_always()
    osc_always_on = not osc_always_on

    mp.commandv('script-message', 'osc-visibility',
        osc_always_on and 'always' or 'auto'
    )
    mp.add_timeout(CLEAR_OSD_TIMEOUT, function ()
        mp.osd_message('')
    end)
end

local function peek_osc()
    if not osc_always_on then
        toggle_osc_auto_always()
        mp.add_timeout(OSC_PEEK_SEC, toggle_osc_auto_always)
    end
end

mp.add_key_binding(nil, 'toggle-osc-auto-always', toggle_osc_auto_always)
mp.add_key_binding(nil, 'peek-osc', peek_osc)