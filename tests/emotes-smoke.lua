-- Real DF/database/serialization and the native MainWindow emote editor.
-- Run from repository root: luatex --luaonly tests/emotes-smoke.lua
local native = dofile('tests/details-framework-ui-stubs.lua')
local methods = getmetatable(UIParent).__index
function methods:IsMouseOver() return self.mouseover == true end
function methods:GetID() return self.categoryID end
function methods:GetFontString() return nil end
function strtrim(v) return (v:gsub('^%s+', ''):gsub('%s+$', '')) end
StaticPopupDialogs = {}; UISpecialFrames = {}
local popup
function StaticPopup_Show(name, text, _, data) popup = {name=name, text=text, data=data} end
local panels = {}
local function Register(panel, label)
    panel.categoryID = #panels + 1
    panels[#panels + 1] = {panel=panel, label=label}; return panel
end
Settings = {RegisterCanvasLayoutCategory=Register, RegisterAddOnCategory=function() end,
    RegisterCanvasLayoutSubcategory=function(_, panel, label) return Register(panel, label) end,
    OpenToCategory=function() end}
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
local addon = {VERSION='test'}
local function Load(name) assert(loadfile('RPEmoteMenu/'..name))('RPEmoteMenu', addon) end
for _, name in ipairs({'Defaults.lua','FontMedia.lua','BuiltInThemes.lua','JSON.lua','Database.lua','Serialization.lua','MainWindow.lua'}) do Load(name) end
local db=addon.Database; db.InitializeDatabase()
local updates, selections = 0, 0
addon.MainWindow.UpdateMenu=function() updates=updates+1 end
addon.MainWindow.SetSelectedCategory=function(i) selections=selections+1; db.GetProfileSettings().selectedCategory=i end
for _, name in ipairs({'ApplyProfileSettings','ApplyThemeSettings','ScheduleFontRefreshes'}) do addon.MainWindow[name]=function() end end
local entries, fields = {}, {}
for line in io.lines('RPEmoteMenu/RPEmoteMenu.toc') do
    if line:match('^Settings[%w]*%.lua$') or line=='MinimizedIconColor.lua' then
        Load(line)
        if line=='SettingsWidgets.lua' then
            local widgets=addon.SettingsWidgets
            local button, text=widgets.CreateButton, widgets.CreateTextEntry
            widgets.CreateButton=function(parent, label, ...)
                local control=button(parent,label,...); entries[#entries+1]={label=label,control=control}; return control
            end
            widgets.CreateTextEntry=function(...)
                local control=text(...); fields[#fields+1]=control; return control
            end
        end
    end
end
addon.Settings.CreateSettingsPanel()
assert(#panels==6 and panels[5].label=='Emotes')
local panel=panels[5].panel
local buttons, nameBox, rows = {}, nil, {}
for _, entry in ipairs(entries) do
    local parent=entry.control.frame:GetParent()
    if parent==panel or entry.label=='Add Emote' then buttons[entry.label]=entry.control end
end
for _, field in ipairs(fields) do if field.frame:GetParent()==panel then nameBox=field end end
for _, object in ipairs(native.objects) do
    if object.EditButton then rows[#rows+1]=object end
end
assert(nameBox and #rows==10 and nameBox.frame:GetWidth()==420)
assert(nameBox.frame.point[4]==208 and nameBox.frame.point[5]==-230)
local selector=panel.categorySelector
assert(selector.frame:GetWidth()==300 and selector.frame.point[5]==-48)
assert(buttons['Restore Built-in Category'].frame.point[2]==selector.frame)
local function Click(control)
    local f=control.frame; f.scripts.OnMouseDown(f,'LeftButton'); f.scripts.OnMouseUp(f,'LeftButton')
end
local function Select(i)
    local choice=selector.widget.func()[i]; choice.onclick(selector.widget,nil,choice.value)
end
local function Type(value)
    nameBox.frame:SetFocus(); nameBox.frame:SetText(value); nameBox.frame.scripts.OnTextChanged(nameBox.frame,true)
end
local function Event(event) nameBox.frame.scripts[event](nameBox.frame) end
local function Accept(request) StaticPopupDialogs[request.name].OnAccept(nil,request.data) end
local initial=db.GetCategory(1).name
local before=updates
nameBox:RefreshValue(); assert(updates==before)
Type('  exact category  '); Event('OnEnterPressed')
assert(db.GetCategory(1).name=='  exact category  ' and updates==before+1)
assert(selector.widget.label:GetText()=='Category 1: exact category')
Type(''); nameBox.frame:ClearFocus(); assert(db.GetCategory(1).name=='')
Type('discard'); Event('OnEscapePressed'); assert(nameBox:GetText()=='' and db.GetCategory(1).name=='')
Type('discard'); panel:Hide(); assert(nameBox:GetText()=='' and db.GetCategory(1).name=='')
Type('stale category'); Select(2); Event('OnEnterPressed'); assert(db.GetCategory(1).name=='')
assert(db.GetProfileSettings().selectedCategory==1 and selections==0, 'settings browsing changed runtime selection')
Select(1)
Type('stale profile'); assert(db.CreateProfile('Other')); Event('OnEditFocusLost')
assert(db.GetCategory(1).name==initial)
assert(db.SetActiveProfile('Default')); Select(1)
Type('stale replacement'); local old=db.GetCategory(1); assert(db.ResetCategoryToDefaults(1)); Event('OnEnterPressed')
assert(db.GetCategory(1)~=old and db.GetCategory(1).name==initial)
-- Also reject ownership changes even without the usual explicit database refresh.
Type('orphan'); db.GetCategories()[1]={name='Replacement',emotes=old.emotes}; Event('OnEnterPressed')
assert(db.GetCategory(1).name=='Replacement')
-- Deferred show repairs layout-cleared text, but cannot erase a newer user edit.
local timers={}; C_Timer.After=function(_,fn) timers[#timers+1]=fn end
local function Drain() while #timers>0 do table.remove(timers,1)() end end
Event('OnShow'); nameBox.frame:SetText(''); Drain(); assert(nameBox:GetText()=='Replacement')
Event('OnShow'); Type('newer'); Drain(); assert(nameBox:GetText()=='newer'); Event('OnEscapePressed')
Event('OnShow'); nameBox:RefreshValue(); nameBox.frame:SetText('new refresh'); Drain(); assert(nameBox:GetText()=='new refresh'); nameBox:RefreshValue()
local staleChoice=selector.widget.func()[2]
Type('renamed'); Event('OnEnterPressed'); staleChoice.onclick(selector.widget,nil,2)
assert(panel.GetSelectedCategory()==1, 'old menu callback remained live')
-- Empty/targeted-only slots, exact strings, independent duplicates and capacity.
local function EmptyCategory(i)
    local category=db.GetCategory(i); category.name=''
    for j=1,10 do category.emotes[j]={label='',defaultCommand='',targetedCommand=''} end
    return category
end
local category=EmptyCategory(1); panel.RefreshEditors()
assert(buttons['Add Emote'].frame:IsEnabled() and not rows[1]:IsShown())
Click(buttons['Add Emote'])
local dialog
for _, object in ipairs(native.objects) do if object.NameBox then dialog=object end end
assert(dialog and dialog.categoryIndex==1 and dialog.emoteIndex==1)
assert(dialog.NameBox.kind=='EditBox' and dialog.SaveButton.kind=='Button')
dialog.NameBox:SetText('  Name  '); dialog.DefaultBox:SetText('  /e {player}  '); dialog.TargetedBox:SetText(' /e {target} ')
dialog.SaveButton.scripts.OnClick()
assert(category.emotes[1].label=='  Name  ' and category.emotes[1].defaultCommand=='  /e {player}  ')
assert(category.emotes[1].targetedCommand==' /e {target} ' and not dialog:IsShown())
Click(rows[1].EditButton); dialog.NameBox:SetText('cancelled'); dialog:Hide(); assert(category.emotes[1].label=='  Name  ')
Click(rows[1].EditButton); dialog.NameBox:SetText(''); dialog.DefaultBox:SetText(''); dialog.TargetedBox:SetText('target only')
dialog.TargetedBox.scripts.OnEnterPressed(dialog.TargetedBox)
assert(rows[1]:IsShown() and rows[1].Label:GetText()=='Unnamed emote')
Click(rows[1].DuplicateButton); assert(category.emotes[2].targetedCommand=='target only' and category.emotes[1]~=category.emotes[2])
category.emotes[2].label='Second'; panel.RefreshEditors()
rows[1].scripts.OnDragStart(rows[1]); rows[2].mouseover=true; rows[1].scripts.OnDragStop(rows[1]); rows[2].mouseover=false
assert(category.emotes[1].label=='Second' and category.emotes[2].targetedCommand=='target only')
-- Refresh/selection/page hide retire drags before pooled rows are rebound.
rows[1].scripts.OnDragStart(rows[1]); Select(2); rows[2].mouseover=true
rows[1].scripts.OnDragStop(rows[1]); rows[2].mouseover=false; Select(1)
assert(category.emotes[1].label=='Second')
rows[1].scripts.OnDragStart(rows[1]); panel:Show(); panel:Hide(); rows[2].mouseover=true
rows[1].scripts.OnDragStop(rows[1]); rows[2].mouseover=false
assert(category.emotes[1].label=='Second')
assert(rows[1].EditButton.frame.point[4]==-154 and rows[1].DeleteButton.frame:GetWidth()==62)
Click(rows[1].DeleteButton); local deletion=popup; Select(2); Accept(deletion)
assert(not addon.SettingsUI.EmoteHasContent(category.emotes[1]))
Select(1)
for i=1,10 do category.emotes[i]={label='E'..i,defaultCommand=' /e '..i..' ',targetedCommand=''} end
panel.RefreshEditors(); assert(not buttons['Add Emote'].frame:IsEnabled() and not rows[1].DuplicateButton.frame:IsEnabled())
local previous=updates; Click(rows[1].DuplicateButton); assert(updates==previous)
assert(not db.DuplicateEmote(1,1))
EmptyCategory(2); panel.RefreshEditors(); Click(buttons['Duplicate Category'])
assert(panel.GetSelectedCategory()==2 and db.GetProfileSettings().selectedCategory==2)
assert(db.GetCategory(2).emotes[1].defaultCommand==' /e 1 ' and db.GetCategory(2)~=category)
for i=1,10 do db.GetCategory(i).name='Full' end
panel.RefreshEditors(); assert(not buttons['Duplicate Category'].frame:IsEnabled() and not db.DuplicateCategory(2))
-- Confirmations keep captured slot/current-Profile target wiring, as before conversion.
Click(buttons['Restore Built-in Category']); local restore=popup; Select(3); Accept(restore)
assert(db.GetCategory(2).name==addon.DefaultSections[2].name and db.GetCategory(3).name=='Full')
Click(buttons['Restore All Built-in Categories']); Accept(popup)
assert(db.GetCategory(3).name==addon.DefaultSections[3].name and db.GetProfileSettings().selectedCategory==1)
Select(2); Click(buttons.Export)
local exchange=addon.SettingsUI.GetExchangeDialog()
assert(exchange.categoryIndex==2 and exchange.editBox.kind=='EditBox')
Click(buttons.Import); assert(exchange.categoryIndex==2)
-- The native confirmations still resolve captured slots against the current Profile.
Select(1); Click(buttons['Restore Built-in Category']); local acrossProfile=popup
assert(db.SetActiveProfile('Other')); db.GetCategory(1).name='Other changed'; Accept(acrossProfile)
assert(db.GetCategory(1).name==initial)
assert(db.SetActiveProfile('Default')); Select(2)
-- Disabled actions and fields reject synthetic clicks/input as well as real UI input.
local canEdit=db.CanEditActiveProfile; db.CanEditActiveProfile=function() return false end
panel.RefreshEditors(); assert(not nameBox.frame:IsEnabled() and not rows[1].DeleteButton.frame:IsEnabled())
local previousPopup=popup; Click(rows[1].DeleteButton); Click(buttons['Restore Built-in Category']); assert(popup==previousPopup)
assert(rows[1].EditButton.widget.text=='View')
db.CanEditActiveProfile=canEdit; panel.RefreshEditors()
assert(rows[1].EditButton.widget.text=='Edit')
for _, helper in ipairs({'CreateSwitch','CreateLabeledEditBox','CreateIntegerEditBox','CreateNumberSetting','CreateColorSetting','CreateFontSetting'}) do assert(addon.SettingsUI[helper]==nil) end
assert(addon.SettingsUI.CreateRows and addon.SettingsUI.CreateInfoLink)
print('PASS real Emotes widgets, exact/empty text, ownership, deferred show, native editor, capacity, drag, actions and cleanup')
