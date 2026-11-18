-- Component contracts: no MainWindow, live frames or private upvalue access.
local addon = {}
local function Load(name) assert(loadfile('RPEmoteMenu/' .. name))('RPEmoteMenu', addon) end
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
STANDARD_TEXT_FONT = 'fallback'
Load('Localization.lua'); Load('Locales/enUS.lua'); Load('Defaults.lua')
addon.GetFontPath = function(name) return name end
local pending = {}
addon.Scheduling = {
    Cancel = function(key) pending[key] = nil end,
    Replace = function(key, delay, callback) pending[key] = {delay = delay, callback = callback} end,
}
Load('WindowTypography.lua')
local typography = addon.WindowTypography
local label = {font = 'custom', size = 12, flags = 'OUTLINE', text = 'Example'}
function label:GetFont() return self.font, self.size, self.flags end
function label:SetFont(font, size, flags)
    self.font, self.size, self.flags = font, size, flags
    return font ~= 'rejected'
end
function label:GetText() return self.text end
function label:SetText(text) self.text = text end
function label:GetStringWidth() return self.font == 'fallback' and #self.text * 7 or 0 end
function label:GetUnboundedStringWidth() return self:GetStringWidth() + 1 end
function label:SetTextColor(...) self.color = {...} end
-- Prefer unbounded metrics; if accepted fonts have no glyphs, use fallback.
assert(typography.MeasureText(label, 'hello', 'rejected', 16) == 36)
label.GetUnboundedStringWidth = nil
assert(typography.MeasureText(label, 'hello', 'custom', 16) == 35)
assert(label.font == 'fallback' and label.size == 16)
assert(typography.MeasureText(nil, 'hello', 'custom', 16) == 0)
assert(typography.MeasureText(label, '', 'custom', 16) == 0)
label.text, label.flags = 'Preserve text', 'OUTLINE'
assert(not typography.ApplyFont(label, 'custom', 16, {r=0.2, g=0.3, b=0.4}, true))
assert(label.text == 'Preserve text' and label.flags == 'OUTLINE' and label.font == 'fallback')
assert(label.color[1] == 0.2 and label.color[4] == 1)
typography.RefreshTemplateFont(label)
assert(label.font == 'fallback' and label.size == 16 and label.flags == 'OUTLINE')
local theme = addon.DefaultThemeSettings
local sidebar, emotes = typography.MeasureColumns(label, {
    {name = string.rep('C', 1000), emotes = {{label = string.rep('E', 1000)}}}
}, theme, 28)
assert(sidebar == addon.MAX_SIDEBAR_WIDTH and emotes == addon.MAX_EMOTE_COLUMN_WIDTH)
sidebar, emotes = typography.MeasureColumns(label, {}, theme, 28)
assert(sidebar >= addon.MIN_SIDEBAR_WIDTH and emotes >= addon.MIN_EMOTE_COLUMN_WIDTH)
assert(sidebar + emotes + 28 >= 220)
-- Separate owners must not cancel one another. Deliver canceled callbacks too
-- to check generation guards independently of the scheduler's cancellation.
local firstCalls, secondCalls = 0, 0
local first = typography.CreateRefreshQueue(function() firstCalls = firstCalls + 1; return false end)
local second = typography.CreateRefreshQueue(function() secondCalls = secondCalls + 1; return true end)
first.Schedule(true)
local firstKey, firstPending = next(pending)
second.Schedule(true)
first.Cancel()
firstPending.callback()
assert(firstCalls == 0 and pending[firstKey] == nil)
local secondKey, secondPending = next(pending)
assert(secondKey ~= firstKey and secondPending.delay == 0)
secondPending.callback()
assert(secondCalls == 1)
pending = {}
first.Schedule()
assert(firstCalls == 1)
local delays = {0.25, 0.75, 2, 5, 10, 12}
for _, delay in ipairs(delays) do
    local key, request = next(pending)
    assert(request.delay == delay)
    pending[key] = nil
    request.callback()
end
assert(firstCalls == 7 and next(pending) == nil)
print('PASS typography measurement/fallback, preserved text/flags, width bounds and isolated bounded retry queues')
