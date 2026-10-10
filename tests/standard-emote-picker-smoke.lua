-- Real catalog/editor/DF controls with native UI and verification fixtures.
local native = dofile('tests/details-framework-ui-stubs.lua')
local methods = getmetatable(UIParent).__index
function methods:SetEnabled(value) if value then self:Enable() else self:Disable() end end
function methods:GetStringWidth() return #(self:GetText() or '') * 6 end
function methods:GetStringHeight() return math.max(12, math.ceil(#(self:GetText() or '') * 6 / math.max(1,self:GetWidth())) * 12) end
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
GetLocale = function() return 'enUS' end
StaticPopupDialogs = {}
local popup
function StaticPopup_Show(name, text, _, data) popup = {name=name,text=text,data=data} end
local executions, updates = 0, 0
DoEmote = function() executions = executions + 1 end
ChatFrame_OpenChat = function() executions = executions + 1 end
C_ChatInfo = {SendChatMessage = function() executions = executions + 1 end}
local addon = {VERSION='test', SettingsUI={FIELD_GAP=12}, Settings={}, MainWindow={UpdateMenu=function() updates=updates+1 end}}
local function Load(name) assert(loadfile('RPEmoteMenu/'..name))('RPEmoteMenu',addon) end
for _, name in ipairs({'Localization.lua','Locales/enUS.lua','Defaults.lua','StandardEmoteCatalog.lua','SettingDefinitions.lua','BuiltInThemes.lua','Database.lua','JSON.lua','Serialization.lua','Scheduling.lua','SettingsWidgets.lua','SettingsControls.lua','StandardEmotePicker.lua','EmoteEditor.lua'}) do Load(name) end
addon.Database.InitializeDatabase()
UIParent:SetSize(1000,800)
local db, catalog = addon.Database, addon.StandardEmoteCatalog
local emote = db.GetCategory(1).emotes[1]
emote.label, emote.defaultCommand, emote.targetedCommand = 'User label %s',' /e {player} %s ',' /e {target} '
local originalExport = assert(addon.Serialization.ExportEverything())
local function Open() addon.EmoteEditor.Open(1,1,false) end
Open()
local dialog
for _, object in ipairs(native.objects) do if object.NameBox then dialog=object end end
local picker = dialog.StandardPicker
assert(dialog.mouseEnabled, "editor shell consumes background clicks")
assert(picker.Preview:GetText()=="" and not picker.PreviewScroll:IsShown(), "empty picker has no helper or reserved preview space")
local compactHeight = dialog:GetHeight()
local function Choose(alias)
    local choices = picker.Selector.widget.func()
    for _, option in ipairs(choices) do
        if option.value == 'enUS:'..alias then option.onclick(picker.Selector.widget,nil,option.value); return end
    end
    error('Choice missing: '..alias)
end
assert(picker.UseButton == nil and StaticPopupDialogs.RPEMOTEMENU_USE_STANDARD_EMOTE == nil)
assert(#picker.Selector.widget.func()==299)
local width,height=picker.Selector.widget:GetMenuSize(); assert(width==570 and height==240)
Choose('wave')
assert(picker.PreviewScroll:IsShown() and dialog:GetHeight()>compactHeight, "selection reserves only its reference preview")
assert(picker.Preview:GetText():find('<target>',1,true))
assert(picker.Preview:GetText():find(addon.L.PICKER_UNVERIFIED,1,true))
assert(dialog.NameBox:GetText()=='Wave' and dialog.DefaultBox:GetText()=='/wave' and dialog.TargetedBox:GetText()=='')
assert(picker.Selector:GetValue()=='enUS:wave' and popup==nil)
assert(addon.Serialization.ExportEverything()==originalExport and executions==0)
for alias, label in pairs({badfeeling='Bad feeling',coverears='Cover ears',crossarms='Cross arms',followme='Follow me',highfive='High five'}) do
    Choose(alias)
    assert(dialog.NameBox:GetText()==label and dialog.DefaultBox:GetText()=='/'..alias)
    assert(picker.Selector:GetValue()=='enUS:'..alias and dialog.TargetedBox:GetText()=='')
end
-- The formatter also handles this spelling if it is supplied in a future catalog.
local rows = addon.Localization.StandardEmotes.enUS
rows[#rows+1] = {'covereyes','Cover eyes preview','Cover eyes targeted preview'}
dialog:Hide(); Open(); Choose('covereyes')
assert(dialog.NameBox:GetText()=='Cover eyes' and dialog.DefaultBox:GetText()=='/covereyes')
rows[#rows] = nil
dialog:Hide(); Open()
-- Every manual field resets selection without changing the other draft fields.
for _, box in ipairs({dialog.NameBox,dialog.DefaultBox,dialog.TargetedBox}) do
    Choose('wave')
    box:SetText('Manual %s {target}')
    box.scripts.OnTextChanged(box,true)
    assert(picker.Selector:GetValue()==nil and box:GetText()=='Manual %s {target}')
    assert(picker.Preview:GetText()=="" and not picker.PreviewScroll:IsShown())
    assert(dialog.Status:GetText()==addon.L.EDITOR_CHANGES_APPLY)
end
Choose('lol')
assert(dialog.NameBox:GetText()=='Lol' and dialog.DefaultBox:GetText()=='/lol' and dialog.TargetedBox:GetText()=='')
assert(picker.Selector:GetValue()=='enUS:lol')
dialog:Hide(); Open()
assert(dialog.NameBox:GetText()==emote.label and dialog.DefaultBox:GetText()==emote.defaultCommand)
assert(picker.Selector:GetValue()==nil and addon.Serialization.ExportEverything()==originalExport)
local function Review(token,status)
    return {locale='enUS',clientBuild='70000',token=token,status=status or 'verified',targetingChecked=true,evidence='Automated fixture only'}
end
catalog.Verification.enUS = {wave=Review('WAVE'),lol=Review('LAUGH'),agree=Review('AGREE','unsupported')}
Open(); Choose('agree')
assert(dialog.DefaultBox:GetText()==emote.defaultCommand and dialog.Status:GetText()==addon.L.PICKER_CANNOT_INSERT)
Choose('wave'); dialog.SaveButton.scripts.OnClick()
assert(emote.label=='Wave' and emote.defaultCommand=='/wave' and emote.targetedCommand=='')
assert(updates==1 and executions==0)
local savedExport=assert(addon.Serialization.ExportProfile('Default'))
local function SerializedHasPickerState(value)
    if type(value)~='table' then return false end
    for key,child in pairs(value) do
        if key=='supportStatus' or key=='defaultPreview' or key=='selectable' then return true end
        if SerializedHasPickerState(child) then return true end
    end
end
assert(not SerializedHasPickerState(RPEmoteMenuDB))
-- Stale callbacks cannot populate hidden/read-only/replaced editor sessions.
Open(); local retired=picker.Selector.widget.func()[1]; dialog:Hide()
retired.onclick(picker.Selector.widget,nil,retired.value)
assert(dialog.DefaultBox:GetText()=='/wave')
Open(); retired=picker.Selector.widget.func()[1]; dialog:Hide(); Open()
retired.onclick(picker.Selector.widget,nil,retired.value)
assert(picker.Selector:GetValue()==nil and dialog.DefaultBox:GetText()=='/wave')
assert(db.CreateProfile('Other')); Choose('lol')
assert(dialog.DefaultBox:GetText()=='/wave' and dialog.Status:GetText()==addon.L.EDITOR_TARGET_CHANGED)
assert(db.SetActiveProfile('Default')); Open()
local category=db.GetCategory(1); category.emotes[1]={label='Replacement',defaultCommand='/bow',targetedCommand=''}
Choose('lol'); assert(dialog.DefaultBox:GetText()=='/wave' and category.emotes[1].defaultCommand=='/bow')
category.emotes[1]=emote
Open(); catalog.Verification.enUS.lol.status='unsupported'; Choose('lol')
assert(dialog.DefaultBox:GetText()=='/wave')
catalog.Verification.enUS.lol.status='verified'
local nativeBuild=GetBuildInfo; GetBuildInfo=function() return 'test','different-build' end
Open(); Choose('lol'); assert(dialog.DefaultBox:GetText()=='/lol')
assert(picker.Preview:GetText():find(addon.L.PICKER_UNVERIFIED,1,true))
GetBuildInfo=nativeBuild
local editable=db.CanEditActiveProfile; db.CanEditActiveProfile=function() return false end
Open(); Choose('lol'); assert(picker.Selector.enabled and dialog.DefaultBox:GetText()=='/wave')
db.CanEditActiveProfile=editable
-- Long reference descriptions scroll inside the bounded preview viewport.
for _, row in ipairs(addon.Localization.StandardEmotes.enUS) do
    if row[1]=='wave' then row[2]=string.rep('長い説明 %s ',150); row[3]='<target> unchanged' end
end
Open(); Choose('wave')
assert(picker.PreviewScroll:GetHeight()==72 and picker.PreviewScroll:GetVerticalScrollRange()>0)
assert(dialog:GetHeight()<UIParent:GetHeight())
assert(picker.Preview:GetText():find('%s',1,true) and picker.Preview:GetText():find('<target>',1,true))
-- Missing/invalid/empty catalogs preserve manual editing.
addon.Localization.locale='deDE'
addon.Localization.StandardEmotes.deDE={{'badfeeling','Synthetic locale preview','Synthetic targeted preview'}}
Open()
local localizedChoice=picker.Selector.widget.func()[1]
localizedChoice.onclick(picker.Selector.widget,nil,localizedChoice.value)
assert(dialog.NameBox:GetText()=='Badfeeling' and dialog.DefaultBox:GetText()=='/badfeeling', 'English word boundaries stay locale-specific')
addon.Localization.StandardEmotes.deDE=nil
addon.Localization.locale='deDE'; Open()
assert(not picker.Selector:GetFrame():IsShown())
assert(picker.Preview:GetText()==addon.L.PICKER_UNAVAILABLE and dialog.DefaultBox:IsEnabled())
addon.Localization.StandardEmotes.deDE={{'/invalid','',''}}; Open(); assert(picker.Preview:GetText()==addon.L.PICKER_INVALID)
addon.Localization.StandardEmotes.deDE={}; Open(); assert(picker.Preview:GetText()==addon.L.PICKER_EMPTY)
assert(executions==0 and addon.Serialization.ExportProfile('Default')==savedExport)
print('PASS real picker inline selector/previews, draft-only insertion, manual reset/session/review guards, Save/Cancel and bounded layouts')


