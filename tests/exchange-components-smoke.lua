-- Explicit transfer component contracts and native lifecycle events.
local native=dofile('tests/details-framework-ui-stubs.lua')
function strtrim(value) return (value:gsub('^%s+',''):gsub('%s+$','')) end
local target={}
local imports=0
local addon={MAX_EMOTES=10,Database={
    IsCurrentContentTarget=function(value) return value==target end,
    CaptureContentTarget=function() return target end,
    GetCategory=function() return {name='Existing',emotes={}} end,
},Serialization={ImportProfileAsNew=function(text)
    imports=imports+1
    if text=='bad' then return false,'Rejected input' end
    return true,'New Profile','Source','Missing Theme'
end}}
assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", addon)
assert(loadfile("RPEmoteMenu/Locales/enUS.lua"))("RPEmoteMenu", addon)
for _,name in ipairs({'SettingsExchangeText.lua','SettingsExchangeActions.lua','SettingsExchangeLifecycle.lua'}) do
    assert(loadfile('RPEmoteMenu/'..name))('RPEmoteMenu',addon)
end
local dialog=CreateFrame('Frame')
dialog.editBox=CreateFrame('EditBox',nil,dialog)
dialog.scrollFrame=CreateFrame('ScrollFrame',nil,dialog)
dialog.scrollContent=CreateFrame('Frame',nil,dialog.scrollFrame)
dialog.scrollFrame:SetScrollChild(dialog.scrollContent)
dialog.scrollFrame:SetSize(120,80)
function dialog.scrollFrame:RefreshViewport()
    self:UpdateScrollChildRect()
    self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScroll(),self:GetVerticalScrollRange())))
end
dialog.editBox:SetSize(120,80)
dialog.status=dialog:CreateFontString()
dialog.actionButton=CreateFrame('Button',nil,dialog)
function dialog.actionButton:SetEnabled(enabled) if enabled then self:Enable() else self:Disable() end end
local measurement=dialog:CreateFontString()
local measuredHeight=300
function measurement:GetStringHeight() return measuredHeight end
StaticPopupDialogs={}
local popup
function StaticPopup_Show(name,text,_,data) popup={name=name,text=text,data=data} end
addon.ExchangeActions.Install(dialog)
local layout=addon.ExchangeTextLayout.Create({editBox=dialog.editBox,
    scrollFrame=dialog.scrollFrame,scrollContent=dialog.scrollContent,measurement=measurement})
addon.ExchangeLifecycle.Install(dialog,layout)
dialog.mode='import'; dialog.dataType='profile'
dialog.editBox:SetText('  exact draft  ')
assert(dialog.editBox:GetText()=='  exact draft  ' and measurement:GetText()=='  exact draft   ')
assert(dialog.editBox:GetHeight()==308 and dialog.actionButton:IsEnabled())
local function Cursor(y,height) dialog.editBox:GetScript('OnCursorChanged')(dialog.editBox,0,y,1,height) end
Cursor(-260,18); assert(dialog.scrollFrame:GetVerticalScroll()==202)
dialog.scrollFrame:SetHeight(40)
dialog.scrollFrame:GetScript('OnSizeChanged')(dialog.scrollFrame)
assert(dialog.scrollFrame:GetVerticalScroll()==242)
-- Invalid input preserves the draft and reports its error.
dialog.editBox:SetText('bad'); dialog.actionButton:GetScript('OnClick')()
assert(imports==1 and dialog.editBox:GetText()=='bad' and dialog.status:GetText()=='Rejected input')
local imported=0; dialog.onProfileImported=function() imported=imported+1 end
dialog.editBox:SetText('good'); dialog.actionButton:GetScript('OnClick')()
assert(imports==2 and imported==1 and dialog.editBox:GetText()=='' and not dialog.actionButton:IsEnabled())
assert(dialog.status:GetText():find('assigned Default Theme',1,true))
-- Replacing an occupied category keeps a captured confirmation target.
dialog.dataType='category'; dialog.categoryIndex=2; dialog.categoryTarget=target
dialog.editBox:SetText('payload'); dialog.actionButton:GetScript('OnClick')()
assert(popup.name=='RPEMOTEMENU_IMPORT_OVER_CATEGORY' and popup.data.target==target)
assert(popup.data.importText=='payload' and popup.data.categoryIndex==2)
-- A hide/reopen retires both the category target and cached caret coordinates.
Cursor(-900,18); dialog:Show(); dialog:Hide()
assert(dialog.categoryTarget==nil)
measuredHeight=20; layout.Refresh(true)
assert(dialog.editBox:GetHeight()==40 and dialog.scrollFrame:GetVerticalScroll()==0)
local before=imports
StaticPopupDialogs[popup.name].OnAccept(nil,popup.data)
assert(imports==before and dialog.status:GetText():find('Reopen Import',1,true))
-- User edits clear old status first; target errors must then remain visible.
dialog.editBox:SetText('draft')
dialog.editBox:GetScript('OnTextChanged')(dialog.editBox,true)
assert(not dialog.actionButton:IsEnabled() and dialog.status:GetText():find('Reopen Import',1,true))
dialog.mode='export'; dialog:Show()
dialog.editBox:GetScript('OnEscapePressed')(dialog.editBox)
assert(not dialog:IsShown())
print('PASS explicit exchange component sizing, caret/resize, import errors/results, confirmation ownership and lifecycle cleanup')

