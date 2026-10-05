-- Real DF, database, serialization and native dialogs; native UI APIs are stubbed.
-- Run from repository root: luatex --luaonly tests/profile-utility-smoke.lua
local native = dofile('tests/details-framework-ui-stubs.lua')
local methods = getmetatable(UIParent).__index
function methods:SetDefaultText(value) self:SetText(value) end
function methods:OverrideText(value) self:SetText(value) end
function methods:SetupMenu(fn) self.menu = fn end
function methods:SetEnabled(value) if value then self:Enable() else self:Disable() end end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:GetID() return self.categoryID end
function methods:GetFontString() return nil end
function methods:IsMouseOver() return false end
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
StaticPopupDialogs = {}
local popupRequest, popupCount = nil, 0
function StaticPopup_Show(name, text, _, data)
    popupRequest = {name = name, text = text, data = data}; popupCount = popupCount + 1
end
local categories, opened = {}, nil
local function Register(panel, label)
    panel.categoryID = #categories + 1
    categories[#categories + 1] = {panel = panel, label = label}
    return panel
end
Settings = {
    RegisterCanvasLayoutCategory = Register,
    RegisterAddOnCategory = function() end,
    RegisterCanvasLayoutSubcategory = function(_, panel, label) return Register(panel, label) end,
    OpenToCategory = function(id) opened = id end,
}
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml') -- Use actual startup order, before PLAYER_LOGIN.
local addon = {VERSION = 'test', MainWindow = {}}
local function Load(name) assert(loadfile('RPEmoteMenu/' .. name))('RPEmoteMenu', addon) end
for _, name in ipairs({'Defaults.lua', 'FontMedia.lua', 'BuiltInThemes.lua', 'JSON.lua', 'Database.lua', 'Serialization.lua'}) do Load(name) end
local db = addon.Database
db.InitializeDatabase()
local runtimeCalls = 0
for _, name in ipairs({'ApplyProfileSettings', 'ApplyThemeSettings', 'UpdateMenu', 'ScheduleFontRefreshes'}) do
    addon.MainWindow[name] = function() runtimeCalls = runtimeCalls + 1 end
end
local buttons, dropdowns, links, buttonCandidates = {}, {}, {}, {}
-- Follow the actual settings module order, including Settings.lua before Widgets.
for line in io.lines('RPEmoteMenu/RPEmoteMenu.toc') do
    if line:match('^Settings[%w]*%.lua$') or line == 'MinimizedIconColor.lua' then
        Load(line)
        if line == 'SettingsWidgets.lua' then
            local widgets = addon.SettingsWidgets
            local button, dropdown, link = widgets.CreateButton, widgets.CreateDropdown, widgets.CreateLink
            widgets.CreateButton = function(parent, text, ...)
                local control = button(parent, text, ...)
                buttonCandidates[#buttonCandidates + 1] = {text = text, control = control}; return control
            end
            widgets.CreateDropdown = function(...)
                local control = dropdown(...)
                dropdowns[#dropdowns + 1] = control; return control
            end
            widgets.CreateLink = function(parent, text, ...)
                local control = link(parent, text, ...)
                links[text] = control; return control
            end
        end
    end
end
addon.Settings.CreateSettingsPanel()
assert(#categories == 6 and categories[1].label == 'RP Emote Menu' and categories[3].label == 'Profiles')
local profiles, transfer = categories[3].panel, categories[6].panel
for _, entry in ipairs(buttonCandidates) do
    local parent = entry.control.frame:GetParent()
    if parent == profiles or parent == transfer then buttons[entry.text] = entry.control end
end
local selectors = {}
for _, control in ipairs(dropdowns) do
    if control.frame:GetParent() == profiles then selectors[#selectors + 1] = control end
end
local selector, themeSelector = selectors[1], selectors[2]
assert(#selectors == 2)
assert(selector.frame:GetWidth() == 250 and selector.frame.point[5] == -112)
assert(themeSelector.frame:GetWidth() == 250 and themeSelector.frame.point[5] == -171)
assert(buttons.Create.frame.point[5] == -337 and buttons['Export Profile'].frame.point[5] == -370)
assert(buttons.Copy.frame.point[2] == buttons.Create.frame and buttons.Copy.frame.point[4] == 8)
assert(buttons['Import Everything'].frame.point[2] == buttons['Export Everything'].frame)
assert(buttons['Export Everything'].frame:GetParent() == transfer)
assert(runtimeCalls == 0, 'page construction must not assign settings')
local function Click(control)
    control.frame:GetScript('OnMouseDown')(control.frame, 'LeftButton')
    control.frame:GetScript('OnMouseUp')(control.frame, 'LeftButton')
end
local function Option(control, value)
    for _, entry in ipairs(control.widget.func()) do if entry.value == value then return entry end end
end
local function Select(control, value)
    local entry = assert(Option(control, value), 'choice not present: ' .. value)
    entry.onclick(control.widget, nil, value)
end
local function Accept(request, name)
    local dialog = StaticPopupDialogs[request.name]
    local popup = CreateFrame('Frame')
    popup.data = request.data
    popup.editBox = CreateFrame('EditBox', nil, popup)
    popup.button1 = CreateFrame('Button', nil, popup)
    if dialog.OnShow then dialog.OnShow(popup, request.data) end
    if name then
        popup.editBox:SetText(name)
        if dialog.EditBoxOnTextChanged then dialog.EditBoxOnTextChanged(popup.editBox) end
        assert(popup.button1:IsEnabled(), 'valid native dialog name was rejected')
    end
    dialog.OnAccept(popup, request.data)
end
local count = popupCount
Click(buttons.Rename); Click(buttons.Delete)
assert(popupCount == count and not buttons.Rename.frame:IsEnabled() and not buttons.Delete.frame:IsEnabled())
assert(not db.RenameProfile('Default', 'Invalid') and not db.DeleteProfile('Default'))
assert(Option(selector, 'Default')) -- Prime cached lists before lifecycle changes.
Select(themeSelector, 'Teal')
assert(db.GetActiveThemeName() == 'Teal' and themeSelector:GetValue() == 'Teal')
-- The still-native Theme editor must track assignment from the converted page.
local themeSelected
for _, object in ipairs(native.objects) do
    local parent = object:GetParent()
    while parent and parent ~= categories[4].panel do parent = parent:GetParent() end
    if object.MyObject and parent == categories[4].panel and object.point and object.point[5] == -103 then
        themeSelected = object.MyObject.myvalue
    end
end
assert(themeSelected == 'Teal')
Click(buttons.Create); Accept(popupRequest, 'Fresh')
assert(db.GetActiveProfileName() == 'Fresh' and db.GetActiveThemeName() == 'Teal')
assert(Option(selector, 'Fresh') and buttons.Rename.frame:IsEnabled())
local fresh = db.GetActiveProfile()
fresh.categories[1].name = 'Exact source'; fresh.settings.x = -25
Click(buttons.Copy); local copy = popupRequest
assert(copy.data.source == 'Fresh' and copy.data.initial == 'Fresh Copy')
Select(selector, 'Default'); Accept(copy, 'Copied')
local copied = db.GetProfile('Copied')
assert(copied.categories[1].name == 'Exact source' and copied.settings.x == -25 and copied.theme == 'Teal')
assert(copied.categories ~= fresh.categories and copied.settings ~= fresh.settings)
assert(Option(selector, 'Copied') and selector:GetValue() == 'Copied')
Click(buttons.Rename); local rename = popupRequest
Select(selector, 'Fresh'); Accept(rename, 'Renamed')
assert(db.GetProfile('Renamed') and not db.GetProfile('Copied') and db.GetActiveProfileName() == 'Fresh')
assert(Option(selector, 'Renamed') and not Option(selector, 'Copied'))
Select(selector, 'Renamed'); Click(buttons.Delete); local delete = popupRequest
RPEmoteMenuDB.activeProfiles['OtherCharacter-Realm'] = 'Renamed'
Select(selector, 'Fresh'); Accept(delete)
assert(not db.GetProfile('Renamed') and db.GetActiveProfileName() == 'Fresh')
assert(RPEmoteMenuDB.activeProfiles['OtherCharacter-Realm'] == 'Default' and not Option(selector, 'Renamed'))
-- Factory restore always targets Default, preserving Theme appearance/custom data.
local default = db.GetProfile('Default')
default.categories[1].name = 'Changed'; default.settings.x = 777
local appearance = db.GetThemeSettings('Default'); appearance.categoryFontSize = 18
Click(buttons['Restore Default']); Accept(popupRequest)
assert(db.GetProfile('Default').categories[1].name ~= 'Changed' and db.GetProfile('Default').settings.x == 0)
assert(db.GetActiveProfileName() == 'Fresh' and fresh.categories[1].name == 'Exact source')
assert(db.GetThemeSettings('Default') == appearance and appearance.categoryFontSize == 18)
-- A deleted captured target is rejected without affecting a later selection.
Select(selector, 'Fresh'); Click(buttons.Copy); local missing = popupRequest
assert(db.DeleteProfile('Fresh')); Accept(missing, 'Should Not Exist')
assert(not db.GetProfile('Should Not Exist') and db.GetActiveProfileName() == 'Default')
-- Native information link remains yellow circled text and anchors to the frame.
local information
for _, object in ipairs(native.objects) do
    if object:GetParent() == profiles and object.kind == 'Button' and object:GetScript('OnClick') then
        object:GetScript('OnClick')(object)
        if popupRequest.name == 'RPEMOTEMENU_PROFILE_INFO' then information = object; break end
    end
end
assert(information and information.point[2] == selector.frame)
-- About retains native Ctrl+C popup; construction resolved Widgets lazily.
local source = 'https://github.com/bblackmoor/rpemotemenu'
Click(assert(links[source]))
assert(popupRequest.name == 'RPEMOTEMENU_COPY_SOURCE' and popupRequest.data == source)
local copyPopup = CreateFrame('Frame'); copyPopup.editBox = CreateFrame('EditBox', nil, copyPopup)
copyPopup.data = popupRequest.data
StaticPopupDialogs[popupRequest.name].OnShow(copyPopup, popupRequest.data)
assert(copyPopup.editBox:GetText() == source)
-- Converted buttons route into the unchanged native multiline JSON dialog.
Click(buttons['Export Profile'])
local exchange = addon.SettingsUI.GetExchangeDialog()
assert(exchange.mode == 'export' and exchange.dataType == 'profile' and exchange.editBox.kind == 'EditBox')
local exported = assert(addon.JSON.Decode(exchange.editBox:GetText()))
assert(exported.version == 2 and exported.type == 'profile')
local profileJSON = exchange.editBox:GetText()
local active, assignment = db.GetActiveProfileName(), RPEmoteMenuDB.activeProfiles[db.GetCharacterKey()]
assert(Option(selector, 'Default'))
Click(buttons['Import Profile']); exchange.editBox:SetText(profileJSON)
exchange.actionButton:GetScript('OnClick')(exchange.actionButton)
assert(db.GetActiveProfileName() == active and RPEmoteMenuDB.activeProfiles[db.GetCharacterKey()] == assignment)
assert(#db.GetProfileNames() == 2 and #selector.widget.func() == 2, 'import invalidates cached choices')
Click(buttons['Export Everything'])
assert(exchange.dataType == 'everything' and exchange.mode == 'export')
local everythingJSON = exchange.editBox:GetText()
local everything = assert(addon.JSON.Decode(everythingJSON))
assert(everything.version == 2 and everything.type == 'everything' and not everything.globalSettings and not everything.activeProfiles)
local profilesBefore = #db.GetProfileNames()
Click(buttons['Import Everything']); exchange.editBox:SetText(everythingJSON)
exchange.actionButton:GetScript('OnClick')(exchange.actionButton)
assert(#db.GetProfileNames() == profilesBefore * 2 and db.GetActiveProfileName() == active)
assert(#selector.widget.func() == #db.GetProfileNames())
local beforeInvalid = #db.GetProfileNames()
exchange.editBox:SetText('{"version":99}'); exchange.actionButton:GetScript('OnClick')(exchange.actionButton)
assert(#db.GetProfileNames() == beforeInvalid)
-- Theme additions/renames/deletions also invalidate the assignment choices.
assert(Option(themeSelector, 'Default'))
assert(db.CreateTheme('Custom')); assert(Option(themeSelector, 'Custom'))
assert(db.RenameTheme('Custom', 'Changed Theme')); assert(not Option(themeSelector, 'Custom') and Option(themeSelector, 'Changed Theme'))
assert(db.DeleteTheme('Changed Theme', true)); assert(not Option(themeSelector, 'Changed Theme'))
-- Actually open the real DF menu with a long list, rather than calling its provider only.
for i = 1, 24 do assert(db.CopyProfile('Default', 'P' .. i .. string.rep('x', 60))) end
profiles.Refresh()
selector.frame:GetScript('OnMouseDown')(selector.frame, 'LeftButton')
assert(selector.widget.opened and #selector.widget.menus == #db.GetProfileNames())
assert(selector.widget.scroll:IsShown() and selector.widget.scroll.maximum > 0)
assert(selector.widget.scroll.thumb.texture == 'Interface\\Buttons\\WHITE8X8')
local staleChoice = assert(Option(selector, 'P1' .. string.rep('x', 60)))
assert(db.DeleteProfile(staleChoice.value))
assert(not selector.widget.opened, 'CRUD refresh closes an open stale menu')
local selected = db.GetActiveProfileName()
staleChoice.onclick(selector.widget, nil, staleChoice.value)
assert(db.GetActiveProfileName() == selected and selector:GetValue() == selected,
    'invalidated menu callbacks cannot select retired entries')
local writes = runtimeCalls
profiles.Refresh(); addon.Settings.RefreshSettingsPanels()
assert(runtimeCalls == writes, 'refresh must not assign settings')
-- Native labels/info anchors must never receive framework wrappers.
for _, object in ipairs(native.objects) do
    if object.point and type(object.point[2]) == 'table' then
        assert(not object.point[2].frame and not object.point[2].widget)
    end
end
local function DescendsFrom(object, frame)
    while object do
        if object == frame then return true end
        object = object:GetParent()
    end
end
for _, control in ipairs({selector, themeSelector, buttons.Create, buttons.Copy,
    buttons.Rename, buttons.Delete, buttons['Restore Default'], buttons['Export Profile'],
    buttons['Import Profile'], buttons['Export Everything'], buttons['Import Everything'], links[source]}) do
    for _, object in ipairs(native.objects) do
        if DescendsFrom(object, control.frame) then
            for _, asset in ipairs({object.texture or '', object.backdrop and object.backdrop.bgFile or '',
                object.backdrop and object.backdrop.edgeFile or ''}) do
                assert(not tostring(asset):find('AddOns\\Details\\', 1, true), 'external asset: ' .. tostring(asset))
            end
        end
    end
end
addon.Settings.OpenAbout(); assert(opened == categories[1].panel.categoryID)
addon.Settings.Open(); assert(opened == categories[2].panel.categoryID)
print('PASS real Profile/utility widgets, captured dialogs, CRUD, menu freshness, transfer and long menus')
