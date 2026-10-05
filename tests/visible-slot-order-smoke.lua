-- Direct component contract; no frames, saved data or private upvalues.
local addon = {}
assert(loadfile('RPEmoteMenu/VisibleSlotOrder.lua'))('RPEmoteMenu', addon)
local Move = addon.VisibleSlotOrder.Move
local function Fixture()
    local a, b, c = {name='A'}, {name='B'}, {name='C'}
    local hidden = {name='hidden'}
    return {[1]=hidden, [2]=a, [4]=b, [5]=hidden, [7]=c, [9]=hidden},
        {2,4,7}, {a,b,c}, hidden
end
-- Every original source/gap combination, including adjacent no-op gaps.
for source = 1, 3 do
    for gap = 1, 4 do
        local records, slots, original, hidden = Fixture()
        local expected = {original[1], original[2], original[3]}
        local destination = gap > source and gap - 1 or gap
        local changed = destination ~= source
        if changed then table.insert(expected, destination, table.remove(expected, source)) end
        assert(Move(records, slots, source, gap) == changed)
        for position, slot in ipairs(slots) do
            assert(records[slot] == expected[position], 'record identity/order changed')
            assert(slots[position] == ({2,4,7})[position], 'slot list changed')
        end
        assert(records[1] == hidden and records[5] == hidden and records[9] == hidden)
        assert(records[3] == nil and records[6] == nil and records[8] == nil)
    end
end
for _, invalid in ipairs({{0,1},{4,1},{1,0},{1,5},{1.5,1},{1,1.5},{1,math.huge}}) do
    local records, slots, original = Fixture()
    assert(not Move(records, slots, invalid[1], invalid[2]))
    for position, slot in ipairs(slots) do assert(records[slot] == original[position]) end
end
assert(not Move({}, {}, 1, 1))
local record = {}
local singleton = {[4]=record}
assert(not Move(singleton, {4}, 1, 1))
assert(not Move(singleton, {4}, 1, 2))
assert(singleton[4] == record)
print('PASS visible-slot order: all source/gap pairs, sparse hidden slots, identity and no-op/invalid moves')

-- Exercise actual window drag handlers with native frames stubbed.
local native = dofile('tests/details-framework-ui-stubs.lua')
local methods = getmetatable(UIParent).__index
function methods:SetResizeBounds(...) self.resizeBounds = {...} end
function methods:GetShadowOffset() return 0, 0 end
function methods:GetShadowColor() return 0, 0, 0, 1 end
function methods:SetRotation(value) self.rotation = value end
function methods:GetLeft() return self.left or 0 end
function methods:GetRight() return self:GetLeft() + self.width end
function methods:GetTop() return self.top or 600 end
function methods:GetBottom() return self:GetTop() - self.height end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetAlpha(value) self.alpha = value end
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
local runtime = {VERSION = 'test', Settings = {}, Commands = {ExecuteEmoteCommand = function() end}}
for _, file in ipairs({'Defaults.lua','SettingDefinitions.lua','Scheduling.lua','FontMedia.lua',
    'BuiltInThemes.lua','Database.lua','VisibleSlotOrder.lua','WindowGeometry.lua','WindowFade.lua',
    'EmoteEditor.lua','MainWindow.lua'}) do
    assert(loadfile('RPEmoteMenu/'..file))('RPEmoteMenu', runtime)
end
runtime.Database.InitializeDatabase()
runtime.MainWindow.CreateMainWindow()
local db, main = runtime.Database, runtime.MainWindow
local refreshes = 0
runtime.Settings.RefreshEditors = function() refreshes = refreshes + 1 end
local cursorX, cursorY = 0, 0
function GetCursorPosition() return cursorX, cursorY end
local function LayoutRows(categoryRows)
    local rows = {}
    for _, object in ipairs(native.objects) do
        local matches = categoryRows and object.categoryIndex
            or (not categoryRows and object.emoteIndex and not object.categoryIndex)
        if matches and object.visiblePosition and object:IsShown()
            and object:GetScript('OnDragStart') then
            rows[object.visiblePosition] = object
            object.left = categoryRows and 0 or 400
            object.top = 600 - object.visiblePosition * 50
            object.width, object.height = 100, 40
        end
    end
    assert(rows[1] and rows[2] and rows[3])
    return rows
end
local function Drop(rows, source, gap)
    local targetPosition = math.min(gap, 3)
    local target = rows[targetPosition]
    cursorX = target:GetLeft() + 10
    cursorY = gap == 4 and target:GetBottom() + 1 or target:GetTop() - 1
    rows[source]:GetScript('OnDragStart')(rows[source])
    rows[source]:GetScript('OnDragStop')(rows[source])
    assert(rows[source]:GetScript('OnUpdate') == nil and rows[source]:GetAlpha() == 1)
end
for source = 1, 3 do
    for gap = 1, 4 do
        local categories = db.GetCategories()
        for _, category in ipairs(categories) do category.name = '' end
        local a, b, c = categories[2], categories[4], categories[7]
        a.name, b.name, c.name = 'A', 'B', 'C'
        local hidden = categories[5]
        main.SetSelectedCategory(4)
        main.UpdateMenu()
        local expected = {a,b,c}
        local destination = gap > source and gap - 1 or gap
        if destination ~= source then
            table.insert(expected, destination, table.remove(expected, source))
        end
        local beforeRefresh = refreshes
        Drop(LayoutRows(true), source, gap)
        for position, slot in ipairs({2,4,7}) do
            assert(categories[slot] == expected[position])
            if expected[position] == b then
                assert(db.GetProfileSettings().selectedCategory == slot, 'selection lost category identity')
            end
        end
        assert(categories[5] == hidden)
        assert(refreshes == beforeRefresh + (destination ~= source and 1 or 0))
    end
end
-- Window emotes preserve incomplete/hidden records rather than compacting them.
for source = 1, 3 do
    for gap = 1, 4 do
        main.SetSelectedCategory(2)
        local category = db.GetCategory(2)
        local a = {label='A',defaultCommand='/e A',targetedCommand=''}
        local b = {label='B',defaultCommand='/e B',targetedCommand=''}
        local c = {label='C',defaultCommand='/e C',targetedCommand=''}
        local hidden = {label='incomplete',defaultCommand='',targetedCommand='/e hidden'}
        for index = 1, runtime.MAX_EMOTES do
            category.emotes[index] = {label='',defaultCommand='',targetedCommand=''}
        end
        category.emotes[2], category.emotes[4], category.emotes[7] = a,b,c
        category.emotes[5] = hidden
        main.UpdateMenu()
        local expected = {a,b,c}
        local destination = gap > source and gap - 1 or gap
        if destination ~= source then
            table.insert(expected, destination, table.remove(expected, source))
        end
        local beforeRefresh = refreshes
        Drop(LayoutRows(false), source, gap)
        for position, slot in ipairs({2,4,7}) do assert(category.emotes[slot] == expected[position]) end
        assert(category.emotes[5] == hidden)
        assert(db.GetProfileSettings().selectedCategory == 2)
        assert(refreshes == beforeRefresh + (destination ~= source and 1 or 0))
    end
end
print('PASS real window category/emote drags: all source/gap pairs, selected identity, hidden records and cleanup/refresh policy')
