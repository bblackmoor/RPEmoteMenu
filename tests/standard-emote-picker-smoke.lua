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
local function Choose(alias)
    local choices = picker.Selector.widget.func()
    for _, option in ipairs(choices) do
        if option.value == 'enUS:'..alias then option.onclick(picker.Selector.widget,nil,option.value); return end
    end
    error('Choice missing: '..alias)
end
local function Use() popup=nil; picker.UseButton.scripts.OnClick(); return popup end
local function Accept(captured) StaticPopupDialogs[captured.name].OnAccept(nil,captured.data) end
assert(#picker.Selector.widget.func()==299)
local width,height=picker.Selector.widget:GetMenuSize(); assert(width==570 and height==240)
Choose('wave')
assert(picker.Preview:GetText():find('<target>',1,true))
assert(picker.Preview:GetText():find(addon.L.PICKER_UNVERIFIED,1,true))
assert(picker.UseButton:IsEnabled())
local unverifiedConfirmation=Use()
assert(unverifiedConfirmation and unverifiedConfirmation.text=='/wave')
assert(dialog.DefaultBox:GetText()==emote.defaultCommand)
-- Cancel preserves the saved commands; reopening and confirming inserts an unverified draft.
dialog:Hide(); Open(); Choose('wave'); Accept(Use())
assert(dialog.DefaultBox:GetText()=='/wave' and dialog.TargetedBox:GetText()=='')
assert(dialog.NameBox:GetText()==emote.label)
dialog:Hide(); Open()
assert(addon.Serialization.ExportEverything()==originalExport and executions==0)
-- Filtering invalidates callbacks from an open menu, and uses literal aliases.
local stale = picker.Selector.widget.func()[1]
picker.FilterBox:SetText(' /WaVe ')
assert(#picker.Selector.widget.func()==1 and picker.Selector:GetValue()==nil)
stale.onclick(picker.Selector.widget,nil,stale.value)
assert(picker.Selector:GetValue()==nil)
Choose('wave')
picker.FilterBox:SetText('[')
assert(#picker.Selector.widget.func()==0 and not picker.Selector.enabled)
assert(picker.Preview:GetText()==addon.L.PICKER_NO_RESULTS)
picker.FilterBox.scripts.OnEnterPressed(picker.FilterBox)
assert(updates==0 and dialog:IsShown())
picker.FilterBox:SetText('')
-- Verification fixtures check status and known-unsupported guards without claiming native acceptance.
local function Review(token,status)
    return {locale='enUS',clientBuild='70000',token=token,status=status or 'verified',targetingChecked=true,evidence='Automated fixture only'}
end
catalog.Verification.enUS = {wave=Review('WAVE'),lol=Review('LAUGH'),agree=Review('AGREE','unsupported')}
Open(); Choose('agree'); assert(not picker.UseButton:IsEnabled())
Choose('wave'); assert(picker.UseButton:IsEnabled())
local confirmation = Use()
assert(confirmation and confirmation.text=='/wave')
assert(dialog.DefaultBox:GetText()==emote.defaultCommand and addon.Serialization.ExportEverything()==originalExport)
-- Declining has no side effect; changing a draft retires that confirmation.
dialog.DefaultBox:SetText('New manual draft %s')
Accept(confirmation)
assert(dialog.DefaultBox:GetText()=='New manual draft %s' and dialog.Status:GetText()==addon.L.PICKER_DRAFT_CHANGED)
confirmation=Use(); Choose('lol'); Choose('wave'); Accept(confirmation)
assert(dialog.DefaultBox:GetText()=='New manual draft %s')
Choose('wave'); confirmation=Use(); Accept(confirmation)
assert(dialog.NameBox:GetText()=='User label %s' and dialog.DefaultBox:GetText()=='/wave' and dialog.TargetedBox:GetText()=='')
assert(addon.Serialization.ExportEverything()==originalExport)
dialog:Hide(); assert(emote.defaultCommand==' /e {player} %s ')
Open(); assert(picker.Selector:GetValue()==nil and picker.FilterBox:GetText()=='')
-- Empty drafts insert immediately and still require Save.
dialog.NameBox:SetText(''); dialog.DefaultBox:SetText(''); dialog.TargetedBox:SetText('')
Choose('wave'); assert(Use()==nil)
assert(dialog.NameBox:GetText()=='/wave' and dialog.DefaultBox:GetText()=='/wave')
assert(emote.defaultCommand==' /e {player} %s ')
dialog.SaveButton.scripts.OnClick()
assert(emote.label=='/wave' and emote.defaultCommand=='/wave' and emote.targetedCommand=='')
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
-- Hide/reopen, profile changes, replacement and revoked/build-stale reviews.
Open(); Choose('lol'); confirmation=Use(); dialog:Hide(); Open(); Accept(confirmation)
assert(dialog.DefaultBox:GetText()=='/wave')
Choose('wave'); confirmation=Use(); assert(db.CreateProfile('Other')); Accept(confirmation)
assert(dialog.DefaultBox:GetText()=='/wave' and not picker.UseButton:IsEnabled())
assert(db.SetActiveProfile('Default')); Open(); Choose('lol'); confirmation=Use()
local category=db.GetCategory(1); category.emotes[1]={label='Replacement',defaultCommand='/bow',targetedCommand=''}
Accept(confirmation); assert(category.emotes[1].defaultCommand=='/bow')
category.emotes[1]=emote
Open(); Choose('lol'); confirmation=Use(); catalog.Verification.enUS.lol.status='unsupported'; Accept(confirmation)
assert(dialog.DefaultBox:GetText()=='/wave')
catalog.Verification.enUS.lol.status='verified'
Open(); Choose('lol'); confirmation=Use()
local nativeBuild=GetBuildInfo; GetBuildInfo=function() return 'test','different-build' end
Accept(confirmation); assert(dialog.DefaultBox:GetText()=='/lol')
assert(picker.Preview:GetText():find(addon.L.PICKER_UNVERIFIED,1,true))
GetBuildInfo=nativeBuild
local editable=db.CanEditActiveProfile; db.CanEditActiveProfile=function() return false end
Open(); Choose('wave'); assert(picker.Selector.enabled and not picker.UseButton:IsEnabled()); Use()
assert(dialog.DefaultBox:GetText()=='/wave'); db.CanEditActiveProfile=editable
-- Long reference descriptions scroll inside the bounded preview viewport.
for _, row in ipairs(addon.Localization.StandardEmotes.enUS) do
    if row[1]=='wave' then row[2]=string.rep('長い説明 %s ',150); row[3]='<target> unchanged' end
end
Open(); Choose('wave')
assert(picker.PreviewScroll:GetHeight()==72 and picker.PreviewScroll:GetVerticalScrollRange()>0)
assert(dialog:GetHeight()<UIParent:GetHeight())
assert(picker.Preview:GetText():find('%s',1,true) and picker.Preview:GetText():find('<target>',1,true))
-- Missing/invalid/empty catalogs preserve manual editing.
addon.Localization.locale='deDE'; Open()
assert(not picker.Selector:GetFrame():IsShown() and not picker.UseButton:IsEnabled())
assert(picker.Preview:GetText()==addon.L.PICKER_UNAVAILABLE and dialog.DefaultBox:IsEnabled())
addon.Localization.StandardEmotes.deDE={{'/invalid','',''}}; Open(); assert(picker.Preview:GetText()==addon.L.PICKER_INVALID)
addon.Localization.StandardEmotes.deDE={}; Open(); assert(picker.Preview:GetText()==addon.L.PICKER_EMPTY)
assert(executions==0 and addon.Serialization.ExportProfile('Default')==savedExport)
print('PASS real picker filtering/previews, draft-only insertion, confirmation/session/review guards, Save/Cancel and bounded layouts')
