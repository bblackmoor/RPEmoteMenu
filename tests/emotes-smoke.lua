-- Real DF/database/serialization and the native MainWindow emote editor.
-- Run from repository root: luatex --luaonly tests/emotes-smoke.lua
local native = dofile('tests/details-framework-ui-stubs.lua')
local methods = getmetatable(UIParent).__index
function methods:IsMouseOver() return self.mouseover == true end
function methods:SetEnabled(value) if value then self:Enable() else self:Disable() end end
function methods:GetID() return self.categoryID end
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
assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", addon)
assert(loadfile("RPEmoteMenu/Locales/enUS.lua"))("RPEmoteMenu", addon)
local function Load(name) assert(loadfile('RPEmoteMenu/'..name))('RPEmoteMenu', addon) end
for _, name in ipairs({'Scheduling.lua','Defaults.lua', 'StandardEmoteCatalog.lua','SettingDefinitions.lua','FontMedia.lua','BuiltInThemes.lua','JSON.lua','Database.lua','Serialization.lua','VisibleSlotOrder.lua','WindowGeometry.lua','WindowFade.lua','StandardEmotePicker.lua', 'EmoteEditor.lua','MainWindow.lua'}) do Load(name) end
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
addon.Settings.RegisterSettingsPanels()
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
    if not selector.widget.opened then selector.frame:GetScript('OnMouseDown')(selector.frame,'LeftButton') end
    local row=selector.widget.menus[i]; row:GetScript('OnMouseDown')(row,'LeftButton')
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
assert(dialog.NameBox.kind:lower()=='editbox' and dialog.SaveButton.kind:lower()=='button')
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
-- Confirmations retain their original category when settings selection changes.
Click(buttons['Restore Built-in Category']); local restore=popup; Select(3); Accept(restore)
assert(db.GetCategory(2).name==addon.DefaultSections[2].name and db.GetCategory(3).name=='Full')
Click(buttons['Restore All Built-in Categories']); Accept(popup)
assert(db.GetCategory(3).name==addon.DefaultSections[3].name and db.GetProfileSettings().selectedCategory==1)
Select(2); Click(buttons.Export)
local exchange=addon.SettingsUI.GetExchangeDialog()
assert(exchange.categoryIndex==2 and exchange.editBox.kind:lower()=='editbox')
Click(buttons.Import); assert(exchange.categoryIndex==2)
-- A Profile change rejects a pending restore instead of retargeting it.
Select(1); Click(buttons['Restore Built-in Category']); local acrossProfile=popup
assert(db.SetActiveProfile('Other')); db.GetCategory(1).name='Other changed'; Accept(acrossProfile)
assert(db.GetCategory(1).name=='Other changed')
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


-- Pending native editor operations never write to a different saved record.
assert(db.SetActiveProfile('Default')); Select(1)
local a=EmptyCategory(1); a.name='A'; a.emotes[1]={label='A original',defaultCommand='A command',targetedCommand=''}
panel.RefreshEditors(); Click(rows[1].EditButton); dialog.NameBox:SetText('A edited')
assert(db.SetActiveProfile('Other')); Select(1)
local b=EmptyCategory(1); b.name='B'; b.emotes[1]={label='B original',defaultCommand='B command',targetedCommand=''}
local before=updates; dialog.SaveButton.scripts.OnClick()
assert(a.emotes[1].label=='A original' and b.emotes[1].label=='B original' and updates==before)
assert(not dialog.SaveButton:IsEnabled() and dialog.Status:GetText():find('Reopen',1,true))
assert(db.SetActiveProfile('Default')); Select(1)
a.emotes[1]={label='First',defaultCommand='First command',targetedCommand=''}
a.emotes[2]={label='Second',defaultCommand='Second command',targetedCommand=''}
panel.RefreshEditors(); Click(rows[1].EditButton); dialog.NameBox:SetText('wrong slot')
rows[1].scripts.OnDragStart(rows[1]); rows[2].mouseover=true; rows[1].scripts.OnDragStop(rows[1]); rows[2].mouseover=false
before=updates; dialog.NameBox.scripts.OnEnterPressed(dialog.NameBox)
assert(a.emotes[1].label=='Second' and a.emotes[2].label=='First' and updates==before)
Click(rows[1].EditButton); dialog.NameBox:SetText('stale replacement')
local index=dialog.emoteIndex; assert(db.ResetCategoryToDefaults(1))
local replacement=db.GetCategory(1).emotes[index]; local savedLabel=replacement.label
before=updates; dialog.SaveButton.scripts.OnClick()
assert(replacement.label==savedLabel and updates==before)
-- Hiding retires even callbacks invoked synthetically after the window closes.
panel.RefreshEditors(); Click(rows[1].EditButton); dialog.NameBox:SetText('hidden edit'); dialog:Hide()
before=updates; dialog.SaveButton.scripts.OnClick(); assert(replacement.label==savedLabel and updates==before)
Click(rows[1].EditButton); assert(dialog.SaveButton:IsEnabled())
dialog.NameBox:SetText('  fresh edit  '); dialog.SaveButton.scripts.OnClick()
assert(replacement.label=='  fresh edit  ')
-- Delete binds to the original record and slot; reorder/reset/Profile changes retire it.
a=EmptyCategory(1)
a.emotes[1]={label='First',defaultCommand='First command',targetedCommand=''}
a.emotes[2]={label='Second',defaultCommand='Second command',targetedCommand=''}
panel.RefreshEditors(); Click(rows[1].DeleteButton); local pendingDelete=popup
rows[1].scripts.OnDragStart(rows[1]); rows[2].mouseover=true; rows[1].scripts.OnDragStop(rows[1]); rows[2].mouseover=false
before=updates; Accept(pendingDelete)
assert(a.emotes[1].label=='Second' and a.emotes[2].label=='First' and updates==before)
Click(rows[1].DeleteButton); pendingDelete=popup; assert(db.ResetCategoryToDefaults(1))
replacement=db.GetCategory(1).emotes[1]; savedLabel=replacement.label; before=updates; Accept(pendingDelete)
assert(replacement.label==savedLabel and updates==before)
Click(rows[1].DeleteButton); pendingDelete=popup; assert(db.SetActiveProfile('Other'))
before=updates; Accept(pendingDelete); assert(b.emotes[1].label=='B original' and updates==before)
assert(db.SetActiveProfile('Default')); Select(1); Click(rows[1].DeleteButton); Accept(popup)
assert(not addon.SettingsUI.EmoteHasContent(db.GetCategory(1).emotes[1]))
-- Restore rejects same-slot replacement and whole-Profile/record changes.
Click(buttons['Restore Built-in Category']); local pendingRestore=popup
assert(db.ResetCategoryToDefaults(1)); local restored=db.GetCategory(1); restored.name='Keep replacement'
before=updates; Accept(pendingRestore); assert(db.GetCategory(1)==restored and restored.name=='Keep replacement' and updates==before)
Click(buttons['Restore All Built-in Categories']); local pendingAll=popup
assert(db.SetActiveProfile('Other')); before=updates; Accept(pendingAll)
assert(db.GetCategory(1)==b and b.name=='B' and updates==before)
assert(db.SetActiveProfile('Default')); Click(buttons['Restore All Built-in Categories']); pendingAll=popup
assert(db.ResetCategoryToDefaults(2)); db.GetCategory(2).name='Keep category 2'
before=updates; Accept(pendingAll); assert(db.GetCategory(2).name=='Keep category 2' and updates==before)
Click(buttons['Restore All Built-in Categories']); pendingAll=popup
local category2=db.GetCategory(2); category2.emotes[1]={label='New record',defaultCommand='',targetedCommand=''}
before=updates; Accept(pendingAll); assert(category2.emotes[1].label=='New record' and updates==before)
Click(buttons['Restore All Built-in Categories']); Accept(popup)
assert(db.GetCategory(2).name==addon.DefaultSections[2].name)
-- Import binds when the editor opens, including empty categories without a popup.
Select(1); local source=db.GetCategory(1); source.name='Imported source'; source.emotes[1].label='  Imported label  '
local exported=assert(addon.Serialization.ExportCategory(1))
exchange:OpenImport(1); exchange.editBox:SetText(exported); exchange.actionButton.scripts.OnClick()
local pendingImport=popup; assert(pendingImport.name=='RPEMOTEMENU_IMPORT_OVER_CATEGORY')
assert(db.SetActiveProfile('Other')); before=updates; Accept(pendingImport)
assert(db.GetCategory(1)==b and b.name=='B' and updates==before)
assert(not exchange.actionButton:IsEnabled() and exchange.editBox:GetText()==exported)
assert(db.SetActiveProfile('Default')); Select(1)
exchange:OpenImport(1); exchange.editBox:SetText(exported); exchange.actionButton.scripts.OnClick(); pendingImport=popup
assert(db.ResetCategoryToDefaults(1)); restored=db.GetCategory(1); before=updates; Accept(pendingImport)
assert(db.GetCategory(1)==restored and updates==before)
-- Reopening/hiding the shared dialog cannot authorize an earlier confirmation.
exchange:OpenImport(1); exchange.editBox:SetText(exported); exchange.actionButton.scripts.OnClick(); pendingImport=popup
exchange:OpenImport(2); exchange.editBox:SetText('new session'); before=updates; Accept(pendingImport)
assert(exchange.editBox:GetText()=='new session' and updates==before)
exchange:OpenImport(1); exchange.editBox:SetText(exported); exchange.actionButton.scripts.OnClick(); pendingImport=popup
exchange:Hide(); before=updates; Accept(pendingImport); assert(db.GetCategory(1)==restored and updates==before)
exchange:OpenImport(1); exchange.editBox:SetText(exported); exchange.actionButton.scripts.OnClick(); Accept(popup)
assert(db.GetCategory(1)~=restored and db.GetCategory(1).name=='Imported source')
assert(db.GetCategory(1).emotes[1].label=='  Imported label  ')
assert(exchange.categoryTarget and db.IsCurrentContentTarget(exchange.categoryTarget))
local empty=EmptyCategory(3); exchange:OpenImport(3); exchange.editBox:SetText(exported)
assert(db.SetActiveProfile('Other')); before=updates; exchange.actionButton.scripts.OnClick()
assert(db.GetProfile('Default').categories[3]==empty and updates==before)
assert(db.SetActiveProfile('Default')); exchange:OpenImport(3); exchange.editBox:SetText(exported)
exchange.actionButton.scripts.OnClick(); assert(db.GetCategory(3).name=='Imported source')
-- Owner identity distinguishes a deleted/recreated Profile with the same name.
assert(db.CreateProfile('Transient')); Select(1); panel.RefreshEditors(); Click(rows[1].EditButton)
dialog.NameBox:SetText('old Profile edit'); assert(db.DeleteProfile('Transient')); assert(db.CreateProfile('Transient'))
local current=db.GetCategory(1).emotes[1]; savedLabel=current.label; before=updates; dialog.SaveButton.scripts.OnClick()
assert(current.label==savedLabel and updates==before)

-- Rejected category edits preserve entered text and saved content on Enter/focus loss.
assert(db.SetActiveProfile('Default')); Select(1); panel.RefreshEditors()
local originalCategoryName = db.GetCategory(1).name
local overlong = string.rep('A', addon.ContentTextLimits.categoryName + 1)
Type(overlong); before = updates; Event('OnEnterPressed')
assert(nameBox:GetText() == overlong and db.GetCategory(1).name == originalCategoryName and updates == before)
Event('OnEditFocusLost')
assert(nameBox:GetText() == overlong and db.GetCategory(1).name == originalCategoryName)
Type(string.rep('A', addon.ContentTextLimits.categoryName)); Event('OnEnterPressed')
assert(#db.GetCategory(1).name == addon.ContentTextLimits.categoryName)
assert(addon.Serialization.Decode(assert(addon.Serialization.ExportCategory(1)), 'category'))
-- Byte limits also handle multibyte text consistently with the importer.
Type(string.rep('é', 65)); Event('OnEnterPressed')
assert(nameBox:GetText() == string.rep('é', 65) and #db.GetCategory(1).name == 128)
Event('OnEscapePressed'); assert(nameBox:GetText() == db.GetCategory(1).name)

panel.RefreshEditors(); Click(rows[1].EditButton)
local saved = db.GetCategory(1).emotes[1]
local previousLabel, previousDefault, previousTargeted = saved.label, saved.defaultCommand, saved.targetedCommand
for _, field in ipairs({{dialog.NameBox, 128}, {dialog.DefaultBox, 4096}, {dialog.TargetedBox, 4096}}) do
    dialog.NameBox:SetText('Valid')
    dialog.DefaultBox:SetText('/e valid')
    dialog.TargetedBox:SetText('')
    local entered = string.rep('X', field[2] + 1)
    field[1]:SetText(entered); before = updates
    dialog.SaveButton.scripts.OnClick()
    assert(dialog:IsShown() and field[1]:GetText() == entered)
    assert(saved.label == previousLabel and saved.defaultCommand == previousDefault
        and saved.targetedCommand == previousTargeted and updates == before)
    assert(dialog.Status:GetText():find('bytes', 1, true))
end
dialog.NameBox:SetText(string.rep('L', 128))
dialog.DefaultBox:SetText(string.rep('D', 4096))
dialog.TargetedBox:SetText(string.rep('T', 4096))
dialog.SaveButton.scripts.OnClick()
assert(not dialog:IsShown() and #saved.label == 128 and #saved.defaultCommand == 4096 and #saved.targetedCommand == 4096)
assert(addon.Serialization.Decode(assert(addon.Serialization.ExportCategory(1)), 'category'))

-- Generated duplicate names also stay within the transfer limit.
EmptyCategory(2)
local ok, duplicateIndex = db.DuplicateCategory(1)
assert(ok and #db.GetCategory(duplicateIndex).name <= addon.ContentTextLimits.categoryName)
assert(addon.Serialization.Decode(assert(addon.Serialization.ExportCategory(duplicateIndex)), 'category'))

db.GetCategory(1).name = string.rep('é', 64)
EmptyCategory(3)
ok, duplicateIndex = db.DuplicateCategory(1)
assert(ok and db.GetCategory(duplicateIndex).name == string.rep('é', 61) .. ' Copy')
assert(addon.Serialization.Decode(assert(addon.Serialization.ExportCategory(duplicateIndex)), 'category'))

-- Emotes keeps the native scrollbar step and clamps after content shrinks.
local listContent = rows[1]:GetParent()
local listScroll = listContent:GetParent()
assert(listScroll:GetScrollChild() == listContent and listContent:GetWidth() == 590)
assert(listScroll.options.reskin_slider == false and not listScroll:GetUseDragScroll())
assert(not listScroll:GetSmoothScrolling() and not listScroll:GetUseMomentum())
local bar = CreateFrame('Slider', nil, listScroll); bar:SetHeight(80); listScroll.ScrollBar = bar
function listScroll:GetVerticalScrollRange() return math.max(0, listContent:GetHeight() - 100) end
Select(1)
for index = 1, 10 do db.GetCategory(1).emotes[index] = {label='Row '..index, defaultCommand='/wave', targetedCommand=''} end
panel.RefreshEditors()
listScroll:GetScript('OnMouseWheel')(listScroll, -1); assert(listScroll:GetVerticalScroll() == 40)
listScroll:GetScript('OnMouseWheel')(listScroll, -5); assert(listScroll:GetVerticalScroll() == 80)
listScroll:GetScript('OnMouseWheel')(listScroll, 0); assert(listScroll:GetVerticalScroll() == 80)
bar.scrollStep = 15
listScroll:GetScript('OnMouseWheel')(listScroll, -1); assert(listScroll:GetVerticalScroll() == 95)
listScroll:GetScript('OnMouseDown')(listScroll, 'LeftButton'); assert(not listScroll.isDragging)
rows[1].scripts.OnDragStart(rows[1]); rows[2].mouseover=true
rows[1].scripts.OnDragStop(rows[1]); rows[2].mouseover=false
assert(db.GetCategory(1).emotes[2].label == 'Row 1')
EmptyCategory(1); panel.RefreshEditors()
listContent:GetScript('OnSizeChanged')(listContent)
assert(listScroll:GetVerticalScroll() == 0 and listContent:GetHeight() == 68)

print('PASS real Emotes widgets and captured native editor/delete/restore/import targets across Profile changes, reorder, replacement and dialog retirement')

-- Long transfer drafts remain exact, scroll to their end and clamp on replacement.
exchange:OpenImport(1)
local longText = "  " .. string.rep("é", 65000) .. "\n" .. string.rep("x", 300000) .. "  "
exchange.editBox:SetText(longText)
assert(exchange.editBox:GetText() == longText)
assert(exchange.editBox.maxBytes == 0 and exchange.editBox.maxLetters == 0)
exchange.editBox:SetFocus(); exchange.editBox:ClearFocus()
assert(exchange.editBox:GetText() == longText)
assert(exchange.scrollContent:GetHeight() == exchange.editBox:GetHeight())
exchange.scrollFrame:SetVerticalScroll(1000)
exchange.editBox:SetText("")
assert(exchange.scrollFrame:GetVerticalScroll() == 0)
assert(not exchange.actionButton:IsEnabled())
exchange.editBox:GetScript("OnEscapePressed")(exchange.editBox)
assert(not exchange:IsShown())

-- Controlled renderer metrics verify layout uses wrapped glyph widths, not bytes.
local measurement=exchange.textMeasurement
local fonts=0
function measurement:SetFont(path,size,flags)
    assert(path==STANDARD_TEXT_FONT and size==12); fonts=fonts+1
end
function measurement:GetStringHeight()
    local lines, width = 1, 0
    for _, code in utf8.codes(self:GetText()) do
        if code==10 then
            lines=lines+1; width=0
        else
            local glyph = code==87 and 12 or code==105 and 3 or code==233 and 9 or 3
            if width+glyph > self:GetWidth() then lines=lines+1; width=0 end
            width=width+glyph
        end
    end
    return lines*18
end
-- Dispatch native size events, including changes made within the layout itself.
local function Size(frame,width,height)
    frame:SetSize(width,height)
    frame:GetScript('OnSizeChanged')(frame,width,height)
end
exchange:OpenImport(1)
Size(exchange.scrollFrame,120,80)
local edit=exchange.editBox
edit:SetText(string.rep('W',80))
local wideHeight=edit:GetHeight()
assert(wideHeight==170 and measurement:GetWidth()==112)
edit:SetText(string.rep('i',80)); assert(edit:GetHeight()==80)
local unicodeText=string.rep('é',80)
edit:SetText(unicodeText); assert(edit:GetHeight()==134 and edit:GetText()==unicodeText)
edit:SetText(string.rep('W',80))
Size(exchange.scrollFrame,240,80)
assert(edit:GetWidth()==240 and edit:GetHeight()==98, 'resize must remeasure wrapping')
Size(exchange.scrollFrame,120,80); assert(edit:GetHeight()==wideHeight)
assert(exchange.scrollContent:GetHeight()==edit:GetHeight() and fonts>0)
local cursor=edit:GetScript('OnCursorChanged')
cursor(edit,0,-200,1,18)
assert(exchange.scrollFrame:GetVerticalScroll()==142 and edit:GetHeight()==222,
    'lower caret must remain visible, including layout lag')
cursor(edit,0,-20,1,18); assert(exchange.scrollFrame:GetVerticalScroll()==16)
cursor(edit,0,-40,1,18); assert(exchange.scrollFrame:GetVerticalScroll()==16,
    'an already visible caret must not scroll')
cursor(edit,0,0,1,18); assert(exchange.scrollFrame:GetVerticalScroll()==0)
edit:SetText('line\n'); assert(edit:GetHeight()==80 and measurement:GetText()=='line\n ')
edit:SetText(''); assert(exchange.scrollFrame:GetVerticalScroll()==0 and not exchange.actionButton:IsEnabled())
Size(exchange.scrollFrame,120,400)
assert(edit:GetHeight()==400 and exchange.scrollContent:GetHeight()==400)
-- Reentrant native size callbacks cannot recurse indefinitely.
local originalSetHeight=edit.SetHeight
function edit:SetHeight(height)
    local changed=height~=self:GetHeight(); originalSetHeight(self,height)
    if changed then self:GetScript('OnSizeChanged')(self,self:GetWidth(),height) end
end
edit:SetText(string.rep('W',1000))
assert(edit:GetHeight()>400 and edit:GetText()==string.rep('W',1000))
-- Height-only viewport changes must recheck a stationary caret.
Size(exchange.scrollFrame,120,400)
cursor(edit,0,-1000,1,18)
assert(exchange.scrollFrame:GetVerticalScroll()==622)
Size(exchange.scrollFrame,120,80)
assert(exchange.scrollFrame:GetVerticalScroll()==942,
    'shrinking viewport must keep the stationary caret visible')
Size(exchange.scrollFrame,120,400)
assert(exchange.scrollFrame:GetVerticalScroll()==942,
    'growing viewport must preserve a still-visible caret')
-- Width changes invalidate coordinates from the old wrapping.
Size(exchange.scrollFrame,240,400)
assert(edit:GetHeight()==962, 'old caret bounds must not inflate rewrapped content')
-- New text/reopening must never reuse caret bounds from the prior draft.
edit:SetText(''); Size(exchange.scrollFrame,120,80)
assert(edit:GetHeight()==80 and exchange.scrollFrame:GetVerticalScroll()==0)
exchange:Hide()
print('PASS transfer wrapped-text measurement, Unicode, resize, caret visibility, clamping and reentrant layout')

-- Every transfer-mode transition replaces its complete session consistently.
assert(db.SetActiveProfile('Default'))
local profileCallback=function() end
local themeCallback=function() end
local profileName=db.GetActiveProfileName()
local themeName=db.GetActiveThemeName()
local cases={
    {method='OpenExport',argument=1,mode='export',kind='category',title='Export Category 1'},
    {method='OpenImport',argument=1,mode='import',kind='category',title='Import Category 1'},
    {method='OpenProfileExport',argument=profileName,mode='export',kind='profile',title='Export Profile: '..profileName},
    {method='OpenProfileImport',argument=profileCallback,mode='import',kind='profile',title='Import Profile'},
    {method='OpenThemeExport',argument=themeName,mode='export',kind='theme',title='Export Theme: '..themeName},
    {method='OpenThemeImport',argument=themeCallback,mode='import',kind='theme',title='Import Theme'},
    {method='OpenEverythingExport',mode='export',kind='everything',title='Export Everything'},
    {method='OpenEverythingImport',mode='import',kind='everything',title='Import Everything'},
}
local highlights,focuses=0,0
local originalHighlight,originalFocus=edit.HighlightText,edit.SetFocus
function edit:HighlightText(...) highlights=highlights+1; return originalHighlight(self,...) end
function edit:SetFocus(...) focuses=focuses+1; return originalFocus(self,...) end
for _, previous in ipairs(cases) do
    for _, current in ipairs(cases) do
        assert(exchange[previous.method](exchange,previous.argument))
        local oldTarget=exchange.categoryTarget
        exchange.profileName='stale'; exchange.SetStatus('old status')
        local beforeHighlight,beforeFocus=highlights,focuses
        assert(exchange[current.method](exchange,current.argument))
        assert(exchange.mode==current.mode and exchange.dataType==current.kind)
        assert(exchange.title:GetText()==current.title and exchange.status:GetText()=='')
        assert(exchange.profileName==nil)
        assert(exchange.onProfileImported==(current.method=='OpenProfileImport' and profileCallback or nil))
        assert(exchange.onThemeImported==(current.method=='OpenThemeImport' and themeCallback or nil))
        assert(exchange.categoryIndex==(current.kind=='category' and 1 or nil))
        if current.method=='OpenImport' then
            assert(exchange.categoryTarget~=oldTarget and db.IsCurrentContentTarget(exchange.categoryTarget))
        else assert(exchange.categoryTarget==nil) end
        assert(exchange.scrollFrame:GetVerticalScroll()==0 and focuses==beforeFocus+1)
        if current.mode=='export' then
            assert(edit:GetText()~='' and edit.cursor==0 and highlights==beforeHighlight+1)
            assert(exchange.actionButton:IsEnabled())
        else
            assert(edit:GetText()=='' and highlights==beforeHighlight and not exchange.actionButton:IsEnabled())
        end
    end
end
-- Failed payload preparation must preserve a current import session in full.
for _, item in ipairs({
    {'OpenExport','ExportCategory',1},
    {'OpenProfileExport','ExportProfile',profileName},
    {'OpenThemeExport','ExportTheme',themeName},
    {'OpenEverythingExport','ExportEverything'},
}) do
    exchange:OpenThemeImport(themeCallback); edit:SetText('  retained draft  ')
    exchange.SetStatus('retained status'); exchange.scrollFrame:SetVerticalScroll(7)
    local title,instructions=exchange.title:GetText(),exchange.instructions:GetText()
    local original=addon.Serialization[item[2]]
    addon.Serialization[item[2]]=function() return false,'Expected failure' end
    local beforeHighlight,beforeFocus=highlights,focuses
    local success,message=exchange[item[1]](exchange,item[3])
    addon.Serialization[item[2]]=original
    assert(success==false and message=='Expected failure')
    assert(exchange.mode=='import' and exchange.dataType=='theme' and exchange.onThemeImported==themeCallback)
    assert(edit:GetText()=='  retained draft  ' and exchange.status:GetText()=='retained status')
    assert(exchange.title:GetText()==title and exchange.instructions:GetText()==instructions)
    assert(exchange.scrollFrame:GetVerticalScroll()==7 and highlights==beforeHighlight and focuses==beforeFocus)
end
edit.HighlightText,edit.SetFocus=originalHighlight,originalFocus
exchange:Hide()
print('PASS all 64 transfer-mode transitions, callback/target cleanup, focus/selection and failed export session preservation')


