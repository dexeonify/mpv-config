local Element = require('elements/Element')

---@class BufferingIndicator : Element
local BufferingIndicator = class(Element)

function BufferingIndicator:new() return Class.new(self) --[[@as BufferingIndicator]] end
function BufferingIndicator:init()
	Element.init(self, 'buffer_indicator', {render_order = 2})
	self.ignores_menu = true
	self.enabled = false
	self:decide_enabled()
end

function BufferingIndicator:decide_enabled()
	local cache = state.cache_underrun or state.cache_buffering and state.cache_buffering < 100
	local player = state.core_idle and not state.eof_reached
	if self.enabled then
		if not player or (state.pause and not cache) then self.enabled = false end
	elseif player and cache and state.uncached_ranges then self.enabled = true end
end

function BufferingIndicator:on_prop_pause() self:decide_enabled() end
function BufferingIndicator:on_prop_core_idle() self:decide_enabled() end
function BufferingIndicator:on_prop_eof_reached() self:decide_enabled() end
function BufferingIndicator:on_prop_uncached_ranges() self:decide_enabled() end
function BufferingIndicator:on_prop_cache_buffering() self:decide_enabled() end
function BufferingIndicator:on_prop_cache_underrun() self:decide_enabled() end

function BufferingIndicator:render()
	local ass = assdraw.ass_new()
	ass:rect(0, 0, display.width, display.height, {color = bg, opacity = 0.3})
	local size = round(30 + math.min(display.width, display.height) / 10)
	local opacity = (Elements.menu and not Elements.menu.is_closing) and 0.3 or 0.8
	ass:spinner(display.width / 2, display.height / 2, size, {color = fg, opacity = opacity})
	return ass
end

return BufferingIndicator
