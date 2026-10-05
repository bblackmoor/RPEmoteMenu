-- Real Theme page/framework/database/media/serialization; native UI is stubbed.
-- Run from repository root: luatex --luaonly tests/theme-smoke.lua
local native = dofile('tests/details-framework-ui-stubs.lua')
local methods = getmetatable(UIParent).__index
function methods:SetEnabled(value) if value then self:Enable() else self:Disable() end end
function methods:SetFont(path, size, flags) self.font = {path, size, flags}; return true end
function methods:GetFont() return unpack(self.font or {STANDARD_TEXT_FONT, 12, ''}) end
function methods:SetOwner(owner, anchor) self.owner, self.tooltipAnchor = owner, anchor end
function methods:AddLine(text) self.lines = self.lines or {}; self.lines[#self.lines + 1] = text end
local setColorTexture = methods.SetColorTexture
function methods:SetColorTexture(...) self.baseColor = {...}; setColorTexture(self, ...) end
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
local timers = {}
C_Timer.After = function(delay, callback) timers[#timers + 1] = {delay, callback} end
local function Drain()
    local count = 0
    while #timers > 0 do
        count = count + 1; assert(count < 100, 'unbounded media timer')
        table.remove(timers, 1)[2]()
    end
end
StaticPopupDialogs = {}
local request, prompts
prompts = 0
function StaticPopup_Show(name, text, _, data) request = {name = name, text = text, data = data}; prompts = prompts + 1 end
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
local addon = {Settings = {}, SettingsUI = {FIELD_GAP = 12}, MainWindow = {}}
local function Load(name) assert(loadfile('RPEmoteMenu/' .. name))('RPEmoteMenu', addon) end
for _, name in ipairs({'Scheduling.lua','Defaults.lua','SettingDefinitions.lua', 'FontMedia.lua', 'BuiltInThemes.lua', 'JSON.lua', 'Database.lua', 'Serialization.lua'}) do Load(name) end
local db, media = addon.Database, LibStub('LibSharedMedia-3.0')
db.InitializeDatabase()
local applies, fontUpdates, iconUpdates = 0, 0, 0
addon.MainWindow.ApplyThemeSettings = function() applies = applies + 1 end
addon.MainWindow.ScheduleFontRefreshes = function() fontUpdates = fontUpdates + 1 end
addon.MainWindow.ApplyProfileSettings = function() end
addon.MinimizedIconColor = {Apply = function() iconUpdates = iconUpdates + 1 end}
for _, name in ipairs({'SettingsColorPicker.lua', 'SettingsWidgets.lua', 'SettingsControls.lua',
    'SettingsExchangeText.lua', 'SettingsExchangeActions.lua', 'SettingsExchangeLifecycle.lua', 'SettingsExchange.lua', 'SettingsThemeDialogs.lua', 'SettingsThemeIcon.lua'}) do Load(name) end
local widgets, buttons, swatches, dropdowns = addon.SettingsWidgets, {}, {}, {}
local buttonFactory, colorFactory, menuFactory = widgets.CreateButton, widgets.CreateColorPicker, widgets.CreateDropdown
widgets.CreateButton = function(parent, label, ...)
    local control = buttonFactory(parent, label, ...); buttons[label] = control; return control
end
widgets.CreateColorPicker = function(...)
    local control = colorFactory(...); swatches[#swatches + 1] = control; return control
end
widgets.CreateDropdown = function(...)
    local control = menuFactory(...); dropdowns[#dropdowns + 1] = control; return control
end
Load('SettingsThemes.lua')
local panel = addon.SettingsUI.CreateThemesSettingsPanel()
addon.Settings.RefreshSettingsPanels = panel.RefreshControls
addon.InitializeFontMedia()
local controls = panel.themeControls
local management = dropdowns[#dropdowns]
local icon = swatches[#swatches]
assert(#dropdowns == 5 and #swatches == 7 and applies == 0 and iconUpdates == 0)
local function Click(control)
    control.frame:GetScript('OnMouseDown')(control.frame, 'LeftButton')
    control.frame:GetScript('OnMouseUp')(control.frame, 'LeftButton')
end
local function Event(control, event, ...) control.frame:GetScript(event)(control.frame, ...) end
local function Type(control, text)
    control.frame:SetFocus(); control.frame:SetText(text); Event(control, 'OnTextChanged', true)
end
local function Enter(control, text) Type(control, text); Event(control, 'OnEnterPressed') end
local function Option(control, value)
    for _, entry in ipairs(control.widget.func()) do if entry.value == value then return entry end end
end
local function Select(control, value)
    assert(Option(control, value), 'choice not present: ' .. value)
    if not control.widget.opened then
        control.frame:GetScript('OnMouseDown')(control.frame, 'LeftButton')
    end
    for _, row in ipairs(control.widget.menus) do
        if row:IsShown() and row.table.value == value then
            row:GetScript('OnMouseDown')(row, 'LeftButton'); return
        end
    end
    error('native choice row not present: ' .. value)
end

local function Accept(data, name)
    local popup = CreateFrame('Frame'); popup.data = data.data
    popup.editBox = CreateFrame('EditBox', nil, popup); popup.button1 = CreateFrame('Button', nil, popup)
    local dialog = StaticPopupDialogs[data.name]
    if dialog.OnShow then dialog.OnShow(popup, data.data) end
    if name then popup.editBox:SetText(name) end
    dialog.OnAccept(popup, data.data)
end
local function Position(control, x, y, width)
    assert(control.frame.point[4] == x and control.frame.point[5] == y)
    assert(control.frame:GetWidth() == width)
end
Position(management, 20, -103, 250)
Position(controls.categoryFont, 95, -81, 190); Position(controls.emoteFont, 405, -81, 190)
Position(controls.categoryFontSize, 160, -121, 52); Position(controls.emoteFontSize, 470, -121, 52)
assert(controls.categoryFont.frame:GetParent().point[5] == -285)
local count = prompts; Click(buttons.Rename); Click(buttons.Delete)
assert(prompts == count and not buttons.Rename.frame:IsEnabled() and not buttons.Delete.frame:IsEnabled())
assert(buttons['Restore Theme'].frame:IsEnabled())
-- Font policy, missing-name preservation, inexpensive labels and late providers.
local default = db.GetThemeSettings()
default.categoryFont = 'Absent'; default.emoteFont = 'Other Absent'
panel.RefreshControls()
local exported = assert(addon.Serialization.ExportTheme())
local missing = assert(Option(controls.categoryFont, 'Absent'))
assert(missing.label == 'Absent (unavailable)' and missing.font == nil)
assert(controls.categoryFont:GetValue() == 'Absent' and controls.categoryFont.widget.label:GetText() == 'Absent (unavailable)')
assert(controls.categoryFont.widget.label.textColor[2] == 0.35)
assert(controls.categoryFont.widget.label:GetFont() == STANDARD_TEXT_FONT)
Event(controls.categoryFont, 'OnEnter')
assert(GameTooltip.owner == controls.categoryFont.frame and GameTooltip.lines[1]:find('Absent', 1, true))
Event(controls.categoryFont, 'OnLeave')
local before = applies
media:Register('font', 'Absent', 'Interface\\Fonts\\absent.ttf'); Drain()
assert(applies == before and fontUpdates == 1 and addon.Serialization.ExportTheme() == exported)
assert(controls.categoryFont.widget.label:GetText() == 'Absent' and not controls.categoryFont.MissingFontName)
assert(Option(controls.categoryFont, 'Absent').font == 'Interface\\Fonts\\absent.ttf')
assert(controls.emoteFont.MissingFontName == 'Other Absent', 'font selectors remain independent')
media:SetGlobal('font', 'Absent'); Drain()
assert(default.categoryFont == 'Absent' and addon.Serialization.ExportTheme() == exported)
Select(controls.emoteFont, 'Absent')
assert(default.emoteFont == 'Absent' and applies == before + 1)
media:HashTable('font').Absent = nil
panel.RefreshFontControls()
assert(controls.categoryFont.MissingFontName == 'Absent' and default.categoryFont == 'Absent')
media:SetGlobal('font', nil); Drain()
media:Register('font', 'Absent', 'Interface\\Fonts\\absent.ttf'); Drain()
for i = 1, 24 do media:Register('font', 'Shared ' .. i, 'Interface\\Fonts\\shared.ttf') end
Drain()
Event(controls.categoryFont, 'OnMouseDown', 'LeftButton')
assert(controls.categoryFont.widget.opened and controls.categoryFont.widget.scroll:IsShown())
local cache = controls.categoryFont.widget.func()
local menus = #controls.categoryFont.widget.menus
local builds = 0
local getFonts = addon.GetAvailableFonts
addon.GetAvailableFonts = function(...) builds = builds + 1; return getFonts(...) end
panel.RefreshFontControls()
assert(builds == 0 and #controls.categoryFont.widget.menus == menus and not controls.categoryFont.widget.opened,
    'label refresh does not build font choices or assign values')
addon.GetAvailableFonts = getFonts
assert(controls.categoryFont.widget.func() ~= cache, 'late-font refresh invalidates choices')
-- Shared Theme editing, compact bounds, hidden thickness and captured ownership.
Select(management, 'Teal')
local teal = db.GetThemeSettings()
assert(db.GetActiveThemeName() == 'Teal' and management:GetValue() == 'Teal')
assert(db.CreateProfile('Shared')); assert(db.GetActiveThemeName() == 'Teal')
Enter(controls.categoryFontSize, '99'); Enter(controls.emoteFontSize, '1')
assert(teal.categoryFontSize == 24 and teal.emoteFontSize == 8)
Select(controls.categoryHighlightEffect, 'outline')
assert(controls.categoryHighlightThickness.frame:IsShown() and controls.categoryHighlightThickness.Label:IsShown())
Enter(controls.categoryHighlightThickness, '99'); assert(teal.categoryHighlightThickness == 6)
Type(controls.categoryHighlightThickness, '2'); before = applies
Select(controls.categoryHighlightEffect, 'shadow')
assert(teal.categoryHighlightThickness == 6 and not controls.categoryHighlightThickness.frame:IsShown() and applies == before + 1)
Event(controls.categoryHighlightThickness, 'OnEnterPressed'); assert(teal.categoryHighlightThickness == 6)
for _, effect in ipairs({'underline', 'separator', 'background'}) do
    Select(controls.categoryHighlightEffect, effect)
    assert(controls.categoryHighlightThickness.frame:IsShown() == (effect ~= 'background'))
end
Enter(controls.windowOpacity, '1'); assert(teal.windowOpacity == 0.1)
Enter(controls.windowOpacity, '150'); assert(teal.windowOpacity == 1)
Event(controls.categoryFontSize, 'OnMouseWheel', -1); assert(teal.categoryFontSize == 23)
Type(controls.categoryFontSize, '12'); Event(controls.categoryFontSize, 'OnEscapePressed'); assert(teal.categoryFontSize == 23)
Enter(controls.categoryFontSize, 'invalid'); assert(teal.categoryFontSize == 23)
Type(controls.categoryFontSize, '14'); Select(management, 'Default'); Event(controls.categoryFontSize, 'OnEnterPressed')
assert(teal.categoryFontSize == 23 and db.GetThemeSettings().categoryFontSize == 12)
Select(management, 'Teal'); assert(teal.categoryFontSize == 23)
assert(db.SetActiveProfile('Default')); assert(db.GetActiveThemeName() == 'Teal' and db.GetThemeSettings() == teal)
-- Both ordinary and icon swatches use the existing native RGB session manager.
local function Preview(info, r, g, b)
    function ColorPickerFrame:GetColorRGB() return r, g, b end
    info.swatchFunc()
end
local color = controls.categoryTextColor
local initial = {r = teal.categoryTextColor.r, g = teal.categoryTextColor.g, b = teal.categoryTextColor.b}
before = applies; Click(color); local edit = ColorPickerFrame.info
assert(applies == before and not edit.hasOpacity)
Preview(edit, 0.1, 0.2, 0.3); assert(teal.categoryTextColor.r == 0.1)
edit.cancelFunc(); assert(teal.categoryTextColor.r == initial.r)
Click(color); edit = ColorPickerFrame.info; Preview(edit, 0.3, 0.4, 0.5); ColorPickerFrame:Hide()
edit.cancelFunc(); assert(teal.categoryTextColor.r == 0.3)
Click(color); local stale = ColorPickerFrame.info; Preview(stale, 0.7, 0.8, 0.9)
Select(management, 'Default'); Preview(stale, 1, 0, 0); stale.cancelFunc()
assert(teal.categoryTextColor.r == 0.3 and db.GetThemeSettings().categoryTextColor.r == default.categoryTextColor.r)
Select(management, 'Teal'); Click(icon); local tint = ColorPickerFrame.info
Preview(tint, 0.1, 0.2, 0.3); assert(teal.minimizedIconColor.r == 0.1 and iconUpdates > 0)
assert(icon.Swatch.baseColor[1] == 1 and icon.Swatch.baseColor[2] == 1 and icon.Swatch.color[1] == 0.1,
    'swatch base texture stays white; RGB is applied only through vertex color')
Click(buttons['Restore Yellow']); Preview(tint, 1, 0, 0); tint.cancelFunc()
assert(teal.minimizedIconColor.r == 1 and teal.minimizedIconColor.g == 0.82 and teal.minimizedIconColor.b == 0)
local preview
for _, object in ipairs(native.objects) do if object.Icon then preview = object.Icon end end
assert(preview and preview.color[1] == 1 and preview.color[2] == 0.82)
Type(controls.categoryFontSize, '18'); Click(color); edit = ColorPickerFrame.info
Preview(edit, 0.9, 0.1, 0.2); panel:Hide(); Preview(edit, 1, 0, 0)
assert(teal.categoryFontSize == 23 and teal.categoryTextColor.r == 0.3 and not ColorPickerFrame:IsShown())
-- Geometry mutations stay runtime-owned; this suite checks the callback boundary.
panel.RefreshControls(); before = applies
local profileSettings, x = db.GetProfileSettings(), db.GetProfileSettings().x
Select(controls.titleBarPosition, 'LEFT')
assert(teal.titleBarPosition == 'LEFT' and applies == before + 1 and profileSettings.x == x)
-- Captured name/deletion/restore targets and shared factory reset scope.
Click(buttons.Copy); local copy = request; Select(management, 'Default'); Accept(copy, 'Custom')
assert(db.GetActiveThemeName() == 'Custom' and db.GetThemeSettings().categoryFontSize == 23)
assert(not buttons['Restore Theme'].frame:IsEnabled())
Click(buttons.Rename); local rename = request; Select(management, 'Teal'); Accept(rename, 'Renamed')
assert(db.GetTheme('Renamed') and not db.GetTheme('Custom'))
Select(management, 'Teal'); Click(buttons['Restore Theme']); local restore = request
Select(management, 'Renamed'); Accept(restore)
local factorySize
for _, definition in ipairs(addon.BuiltInThemes) do
    if definition.name == 'Teal' then factorySize = definition.settings.categoryFontSize end
end
assert(db.GetThemeSettings('Teal').categoryFontSize == factorySize)
assert(db.GetActiveThemeName() == 'Renamed' and db.GetThemeSettings().categoryFontSize == 23)
Select(management, 'Renamed'); assert(db.SetProfileTheme('Shared', 'Renamed'))
Click(buttons.Delete); local deletion = request
assert(deletion.text:find('Shared', 1, true) and deletion.data.confirmed)
Select(management, 'Default'); before = applies; Accept(deletion)
assert(db.GetTheme('Renamed') and db.GetProfileThemeName('Shared') == 'Renamed' and applies == before)
addon.SettingsUI.ConfirmThemeDeletion('Renamed'); Accept(request)
assert(not db.GetTheme('Renamed') and db.GetProfileThemeName('Shared') == 'Default')
-- Missing bundled entries recreate through the same menu; bulk reset preserves custom Themes.
assert(db.DeleteTheme('Teal', true))
assert(Option(management, 'Teal').label == 'Recreate Teal')
Select(management, 'Teal'); assert(db.GetTheme('Teal') and db.GetActiveThemeName() == 'Teal')
assert(Option(management, 'Teal').label == 'Teal (Bundled)')
assert(db.CopyTheme('Teal', 'Keep')); db.GetThemeSettings('Keep').categoryFontSize = 19
Click(buttons['Restore Bundled Themes']); Accept(request)
assert(db.GetThemeSettings('Keep').categoryFontSize == 19 and db.GetProfileSettings() == profileSettings)
local replaced = db.GetThemeSettings()
Type(controls.categoryFontSize, '18'); assert(db.RestoreTheme('Teal'))
Event(controls.categoryFontSize, 'OnEnterPressed')
assert(db.GetThemeSettings() ~= replaced and db.GetThemeSettings().categoryFontSize == factorySize,
    'same-name factory replacement retires pending numeric edits')
-- Converted Theme transfer buttons retain existing native JSON modes and activation.
Click(buttons['Export Theme']); local exchange = addon.SettingsUI.GetExchangeDialog()
assert(exchange.dataType == 'theme' and exchange.mode == 'export')
local text = exchange.editBox:GetText()
Click(buttons['Import Theme']); exchange.editBox:SetText(text)
exchange.actionButton:GetScript('OnClick')(exchange.actionButton)
assert(db.GetActiveThemeName() ~= 'Teal' and db.GetThemeSettings().categoryFontSize == factorySize)
assert(management:GetValue() == db.GetActiveThemeName())
before = applies; panel.RefreshControls(); panel.RefreshFontControls(); assert(applies == before)
for _, object in ipairs(native.objects) do
    if object.point and type(object.point[2]) == 'table' then assert(not object.point[2].frame and not object.point[2].widget) end
end
for _, object in ipairs(native.objects) do
    local parent = object
    while parent and parent ~= panel do parent = parent:GetParent() end
    if parent == panel then
        for _, asset in ipairs({object.texture or '', object.backdrop and object.backdrop.bgFile or '',
            object.backdrop and object.backdrop.edgeFile or ''}) do
            assert(not tostring(asset):find('AddOns\\Details\\', 1, true), 'external Theme asset: ' .. tostring(asset))
        end
    end
end


-- A font arriving during hover retires our tooltip without touching another owner.
local settings = db.GetThemeSettings()
settings.categoryFont = 'Review Missing'
panel.RefreshControls(); Event(controls.categoryFont, 'OnEnter')
assert(GameTooltip:IsOwned(controls.categoryFont.frame) and GameTooltip:IsShown())
media:Register('font', 'Review Missing', 'Interface\\Fonts\\review.ttf'); Drain()
assert(controls.categoryFont.MissingFontName == nil and not GameTooltip:IsShown())
Event(controls.categoryFont, 'OnLeave'); assert(not GameTooltip:IsShown())
settings.categoryFont = 'Still Missing'; panel.RefreshFontControls()
Event(controls.categoryFont, 'OnEnter'); Event(controls.categoryFont, 'OnLeave')
assert(not GameTooltip:IsShown())
Event(controls.categoryFont, 'OnEnter'); Event(controls.categoryFont, 'OnHide')
assert(not GameTooltip:IsShown())
Event(controls.categoryFont, 'OnEnter')
local otherOwner = CreateFrame('Frame')
GameTooltip:SetOwner(otherOwner); GameTooltip:SetText('Other tooltip'); GameTooltip:Show()
panel.RefreshFontControls(); Event(controls.categoryFont, 'OnLeave'); Event(controls.categoryFont, 'OnHide')
assert(GameTooltip:IsOwned(otherOwner) and GameTooltip:IsShown() and GameTooltip:GetText() == 'Other tooltip')

-- Native prompts retain the source object, even when its old name is reused.
for _, action in ipairs({'Copy', 'Rename', 'Delete'}) do
    local name = 'Guard Theme ' .. action
    assert(db.CreateTheme(name)); assert(db.SetProfileTheme(db.GetActiveProfileName(), name))
    panel.RefreshControls()
    Click(buttons[action]); local pending = request
    local original = db.GetTheme(name)
    assert(db.RenameTheme(name, name .. ' Original')); assert(db.CreateTheme(name))
    local replacement = db.GetTheme(name)
    local calls = applies
    Accept(pending, action ~= 'Delete' and name .. ' Result' or nil)
    assert(db.GetTheme(name) == replacement and db.GetTheme(name .. ' Original') == original)
    assert(not db.GetTheme(name .. ' Result') and applies == calls)
    assert(db.SetProfileTheme(db.GetActiveProfileName(), name)); panel.RefreshControls()
    Click(buttons[action]); pending = request
    assert(db.DeleteTheme(name, true)); assert(db.CreateTheme(name))
    replacement = db.GetTheme(name); calls = applies
    Accept(pending, action ~= 'Delete' and name .. ' Result' or nil)
    assert(db.GetTheme(name) == replacement and not db.GetTheme(name .. ' Result'))
    assert(applies == calls)
end
assert(db.SetProfileTheme(db.GetActiveProfileName(), 'Default')); panel.RefreshControls()
Click(buttons['Restore Theme']); local staleRestore = request
assert(db.RestoreTheme('Default'))
local replacementDefault = db.GetTheme('Default')
replacementDefault.settings.categoryFontSize = 29
local callsBeforeRestore = applies
Accept(staleRestore)
assert(db.GetTheme('Default') == replacementDefault and replacementDefault.settings.categoryFontSize == 29)
assert(applies == callsBeforeRestore)

Click(buttons['Restore Bundled Themes']); local staleBulk = request
local preset = addon.BuiltInThemes[1].name
assert(db.RestoreTheme(preset))
local replacements = {}
for _, definition in ipairs(addon.BuiltInThemes) do
    replacements[definition.name] = db.GetTheme(definition.name)
end
callsBeforeRestore = applies
Accept(staleBulk)
for name, object in pairs(replacements) do assert(db.GetTheme(name) == object) end
assert(applies == callsBeforeRestore, 'bulk rejection must precede all mutations')

assert(db.DeleteTheme(preset, true))
Click(buttons['Restore Bundled Themes']); local missingBulk = request
assert(db.CreateTheme(preset))
local recreated = db.GetTheme(preset)
Accept(missingBulk)
assert(db.GetTheme(preset) == recreated, 'missing slot must not follow a new replacement')
assert(db.DeleteTheme(preset, true))
Click(buttons['Restore Bundled Themes']); Accept(request)
assert(db.GetTheme(preset), 'an unchanged missing bundled Theme should still be recreated')

-- Deletion warnings bind the complete affected Profile set and its identities.
local ui = addon.SettingsUI
assert(db.CreateTheme('Deletion Guard'))
assert(db.CreateProfile('Deletion A'))
assert(db.SetProfileTheme('Deletion A', 'Deletion Guard'))
local function PendingDeletion()
    ui.ConfirmThemeDeletion('Deletion Guard')
    return request
end
local function RejectDeletion(pending)
    local theme = db.GetTheme('Deletion Guard')
    local calls = applies
    Accept(pending)
    assert(db.GetTheme('Deletion Guard') == theme and applies == calls)
end
local pending = PendingDeletion()
assert(db.CreateProfile('Deletion B'))
assert(db.SetProfileTheme('Deletion B', 'Deletion Guard'))
RejectDeletion(pending)
assert(db.GetProfileThemeName('Deletion A') == 'Deletion Guard'
    and db.GetProfileThemeName('Deletion B') == 'Deletion Guard')

pending = PendingDeletion()
assert(db.SetProfileTheme('Deletion B', 'Default'))
RejectDeletion(pending)
assert(db.GetProfileThemeName('Deletion A') == 'Deletion Guard')
pending = PendingDeletion()
assert(db.RenameProfile('Deletion A', 'Deletion Renamed'))
RejectDeletion(pending)
assert(db.GetProfileThemeName('Deletion Renamed') == 'Deletion Guard')

pending = PendingDeletion()
assert(db.DeleteProfile('Deletion Renamed'))
assert(db.CreateProfile('Deletion Renamed'))
assert(db.SetProfileTheme('Deletion Renamed', 'Deletion Guard'))
RejectDeletion(pending)
assert(db.GetProfileThemeName('Deletion Renamed') == 'Deletion Guard')

assert(db.SetProfileTheme('Deletion Renamed', 'Default'))
pending = PendingDeletion()
assert(not pending.data.confirmed)
assert(db.SetProfileTheme('Deletion B', 'Deletion Guard'))
RejectDeletion(pending)
assert(db.GetProfileThemeName('Deletion B') == 'Deletion Guard')

-- Reopening shows the current list, and unchanged confirmation succeeds.
pending = PendingDeletion()
assert(pending.text:find('Deletion B', 1, true)
    and not pending.text:find('Deletion Renamed', 1, true))
assert(db.CreateProfile('Unrelated Profile'))
Accept(pending)
assert(not db.GetTheme('Deletion Guard') and db.GetProfileThemeName('Deletion B') == 'Default')
assert(db.GetProfileThemeName('Deletion Renamed') == 'Default')

-- Case-only renames cannot make recreation or bulk restore violate name uniqueness.
assert(db.RestoreTheme('Teal'))
assert(db.SetProfileTheme(db.GetActiveProfileName(), 'Teal')); panel.RefreshControls()
assert(db.RenameTheme('Teal', 'TEAL')); panel.RefreshControls()
local capitalized = db.GetTheme('TEAL')
capitalized.settings.categoryFontSize = 31
local savedThemes = {}
for _, name in ipairs(db.GetThemeNames()) do savedThemes[name] = db.GetTheme(name) end
local callsBeforeConflict = applies
assert(Option(management, 'Teal').label == 'Recreate Teal')
Select(management, 'Teal')
assert(not db.GetTheme('Teal') and db.GetTheme('TEAL') == capitalized)
assert(db.GetActiveThemeName() == 'TEAL' and management:GetValue() == 'TEAL')
assert(applies == callsBeforeConflict)
local success, conflict = db.RestoreTheme('Teal')
assert(not success and conflict:find('TEAL', 1, true))
local count, bulkError = db.RestoreBuiltInThemes()
assert(not count and bulkError:find('TEAL', 1, true))
Click(buttons['Restore Bundled Themes']); Accept(request)
for name, object in pairs(savedThemes) do assert(db.GetTheme(name) == object) end
assert(not db.GetTheme('Teal') and capitalized.settings.categoryFontSize == 31)
assert(applies == callsBeforeConflict, 'conflicting restores must not partially update Themes')
assert(addon.Serialization.Decode(assert(addon.Serialization.ExportEverything()), 'everything'))

-- Renaming the conflicting custom Theme allows safe factory recreation.
assert(db.RenameTheme('TEAL', 'Teal Custom')); panel.RefreshControls()
Select(management, 'Teal')
assert(db.GetTheme('Teal') and db.GetTheme('Teal Custom') == capitalized)
assert(capitalized.settings.categoryFontSize == 31)
Click(buttons['Restore Bundled Themes']); Accept(request)
assert(db.GetTheme('Teal Custom') == capitalized and capitalized.settings.categoryFontSize == 31)
assert(addon.Serialization.Decode(assert(addon.Serialization.ExportEverything()), 'everything'))

-- Import copy describes the actual active-Profile assignment.
Click(buttons['Export Theme'])
local importedText = addon.SettingsUI.GetExchangeDialog().editBox:GetText()
Click(buttons['Import Theme'])
local importDialog = addon.SettingsUI.GetExchangeDialog()
assert(importDialog.instructions:GetText():find('assigns it to the active Profile', 1, true))
local previousTheme = db.GetActiveThemeName()
importDialog.editBox:SetText(importedText)
importDialog.actionButton:GetScript('OnClick')(importDialog.actionButton)
assert(db.GetActiveThemeName() ~= previousTheme and management:GetValue() == db.GetActiveThemeName())

-- Bulk restoration includes Default appearance, shared users and runtime refresh.
assert(db.SetProfileTheme(db.GetActiveProfileName(), 'Default')); panel.RefreshControls()
assert(db.SetProfileTheme('Shared', 'Default'))
local originalDefault = db.GetTheme('Default')
originalDefault.settings.categoryFontSize = 21
Click(buttons['Restore Bundled Themes']); local restoreWithDefault = request
assert(restoreWithDefault.data[1].name == 'Default')
assert(StaticPopupDialogs[restoreWithDefault.name].text:find('Default Theme', 1, true))
local callsBeforeDefault = applies
Accept(restoreWithDefault)
assert(db.GetTheme('Default') ~= originalDefault)
assert(db.GetThemeSettings('Default').categoryFontSize == addon.DefaultThemeSettings.categoryFontSize)
assert(db.GetProfileThemeName('Shared') == 'Default' and db.GetActiveThemeName() == 'Default')
assert(applies == callsBeforeDefault + 1)
assert(db.GetTheme('Teal Custom') == capitalized, 'custom Themes must remain unchanged')

-- Replacing Default while confirmation is open invalidates the whole batch.
Click(buttons['Restore Bundled Themes']); local staleDefaultBulk = request
assert(db.RestoreDefaultTheme())
local currentDefaults = {}
for _, target in ipairs(staleDefaultBulk.data) do currentDefaults[target.name] = db.GetTheme(target.name) end
callsBeforeDefault = applies
Accept(staleDefaultBulk)
for name, object in pairs(currentDefaults) do assert(db.GetTheme(name) == object) end
assert(applies == callsBeforeDefault)

local restoredCount = assert(db.RestoreBuiltInThemes())
assert(restoredCount == #addon.BuiltInThemes + 1)
print('PASS real Theme widgets, native choices, font providers and tooltip ownership, shared edits, picker lifecycle and reset scope')
