-- Real database/window integration; only native rendering and coordinates stubbed.
local native = dofile('tests/details-framework-ui-stubs.lua')
dofile('tests/main-window-native.lua')
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
local addon = {VERSION='test', Settings={}}
assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", addon)
assert(loadfile("RPEmoteMenu/Locales/enUS.lua"))("RPEmoteMenu", addon)
for _, name in ipairs({'Defaults.lua','SettingDefinitions.lua','BuiltInThemes.lua','DatabaseNormalization.lua','DatabasePresentation.lua','Database.lua',
    'Scheduling.lua','FontMedia.lua','VisibleSlotOrder.lua','WindowGeometry.lua','WindowFade.lua',
    'EmoteEditor.lua','WindowTypography.lua','MenuRenderer.lua','MenuDrag.lua','MainWindow.lua'}) do
    assert(loadfile('RPEmoteMenu/'..name))('RPEmoteMenu',addon)
end
local db, main = addon.Database, addon.MainWindow
db.InitializeDatabase()
UIParent:SetSize(1000, 800)
main.CreateMainWindow()
assert(db.CreateProfile('Rendering test'))
local function Emote(label, defaultSend, targetedSend)
    return {label=label, defaultCommand='/s '..label, targetedCommand='/e '..label,
        defaultSend=defaultSend, targetedSend=targetedSend}
end
for _, category in ipairs(db.GetCategories()) do category.name='' end
local first, second = db.GetCategory(1), db.GetCategory(3)
first.name, first.emotes = 'First', {[2]=Emote('Original', false, true), [5]=Emote('Retire', true, false)}
second.name, second.emotes = 'Second', {[7]=Emote('Other', true, false)}
main.SetSelectedCategory(1)
main.UpdateMenu()
local row, retired, category
for _, object in ipairs(native.objects) do
    if object.emoteIndex == 2 then row = object end
    if object.emoteIndex == 5 then retired = object end
    if object.categoryIndex == 3 then category = object end
end
assert(row and retired and category)
local click, edit = row:GetScript('OnClick'), row.EditButton:GetScript('OnClick')
local dragStart, dragStop = row:GetScript('OnDragStart'), row:GetScript('OnDragStop')
local enter = category:GetScript('OnEnter')
local commands, edits = {}, {}
addon.Commands = {ExecuteEmoteCommand=function(...) commands[#commands+1]={...} end}
addon.EmoteEditor.Open = function(...) edits[#edits+1]={...} end
local function CheckBinding(label, defaultSend, targetedSend, categoryIndex, emoteIndex)
    assert(row:GetScript('OnClick') == click and row.EditButton:GetScript('OnClick') == edit)
    assert(row:GetScript('OnDragStart') == dragStart and row:GetScript('OnDragStop') == dragStop)
    click(row, 'LeftButton')
    local command = commands[#commands]
    assert(command[1] == '/s '..label and command[2] == '/e '..label)
    assert(command[3] == defaultSend and command[4] == targetedSend)
    click(row, 'RightButton')
    edit(row.EditButton)
    for index = #edits-1, #edits do
        assert(edits[index][1] == categoryIndex and edits[index][2] == emoteIndex)
    end
end
CheckBinding('Original', false, true, 1, 2)
-- Replace the record rather than mutate it: handlers must use the new binding.
first.emotes[2] = Emote('Edited', true, false)
main.UpdateMenu()
CheckBinding('Edited', true, false, 1, 2)
enter(category)
assert(category:GetScript('OnEnter') == enter and db.GetProfileSettings().selectedCategory == 3)
CheckBinding('Other', true, false, 3, 7)
assert(not retired:IsShown() and retired.emoteIndex == nil and retired.defaultSend == nil)
local beforeCommands, beforeEdits = #commands, #edits
retired:GetScript('OnClick')(retired, 'LeftButton')
retired.EditButton:GetScript('OnClick')(retired.EditButton)
assert(#commands == beforeCommands and #edits == beforeEdits, 'retired row acted on stale data')
row.suppressClick = true
click(row, 'LeftButton')
assert(#commands == beforeCommands, 'drag suppression was lost')
row.suppressClick = false
local globals = db.GetGlobalSettings()
globals.hideSettingsGear = true
main.UpdateMenu()
assert(not row.EditButton:IsShown() and not row.EditHoverIcon:IsShown())
globals.hideSettingsGear = false
main.UpdateMenu()
assert(row.EditButton:IsShown() and row.EditHoverIcon:IsShown())
-- Profile changes rebind existing frames, including explicit false Send values.
assert(db.CopyProfile('Rendering test', 'Replacement'))
db.GetCategory(3).emotes[7] = Emote('New profile', false, true)
main.UpdateMenu()
CheckBinding('New profile', false, true, 3, 7)
assert(db.SetActiveProfile('Rendering test'))
CheckBinding('Other', true, false, 3, 7)
-- Empty categories retire all bindings, then the same frame can be reused.
first.name, second.name = '', ''
main.UpdateMenu()
assert(not row:IsShown() and row.emoteIndex == nil and row.targetedSend == nil)
second.name = 'Restored'
main.UpdateMenu()
CheckBinding('Other', true, false, 3, 7)
print('PASS stable menu handlers, record replacement, sparse category selection, Send flags, gear visibility, retired rows and Profile rebinding')
