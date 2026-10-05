-- Run from the repository root: texlua --luaonly tests/settings-smoke.lua
-- A small WoW UI stub catches settings registration, module-order, and
-- cross-panel wiring regressions. Real WoW layout still requires an in-game check.
local addon = {VERSION = 'test'}
local function loadModule(path)
    local chunk = assert(loadfile(path))
    chunk('RPEmoteMenu', addon)
end
loadModule('RPEmoteMenu/Scheduling.lua')
loadModule('RPEmoteMenu/Defaults.lua')
loadModule('RPEmoteMenu/SettingDefinitions.lua')
loadModule('RPEmoteMenu/BuiltInThemes.lua')
-- All ordinary settings widgets use real DF; specialized native frames remain.
local native = dofile('tests/details-framework-ui-stubs.lua')
local widgets = native.objects
local Widget = getmetatable(UIParent).__index
function Widget:SetDefaultText(value) self:SetText(value) end
function Widget:OverrideText(value) self:SetText(value) end
function Widget:SetPoint(point, relative, relativePoint, x, y)
    self.point = {point, relative, relativePoint, x, y}
    self.anchor = {point=point,relative=relative,relativePoint=relativePoint,x=x,y=y}
end
function Widget:SetEnabled(value) if value then self:Enable() else self:Disable() end end
function Widget:SetupMenu(fn) self.menu = fn end
function Widget:SetChecked(value) self.checked = value end
function Widget:GetChecked() return self.checked end
function Widget:GetID() return 1 end
function Widget:GetFontString() return nil end
function Widget:IsMouseOver() return self.mouseover == true end
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
local activeProfile='Default'
local profiles={Default={theme='Default'}}
local tealSettings={}
for k,v in pairs(addon.DefaultThemeSettings) do tealSettings[k]=v end
local themes={Default={settings=addon.DefaultThemeSettings}, Teal={settings=tealSettings}}
local merged=setmetatable({}, {
  __index=function(_,k) return addon.DefaultSettings[k] end,
  __newindex=function(_,k,v) addon.DefaultSettings[k]=v end
})
local DB={}
function DB.GetSettings() return merged end
function DB.GetActiveProfileName() return activeProfile end
function DB.GetActiveThemeName() return profiles[activeProfile].theme end
function DB.GetTheme(name) return themes[name] end
function DB.GetThemeNames() return {'Default','Teal'} end
function DB.GetThemeSettings(name) return themes[name or DB.GetActiveThemeName()].settings end
function DB.GetThemeDescription(name) return name=='Default' and 'Fallback.' or 'Bundled preset.' end
function DB.IsBuiltInThemeName(name) return name=='Teal' end
function DB.GetProfileNames() return {'Default'} end
function DB.GetProfileDisplayName(name) return name end
function DB.GetProfileDescription() return 'Editable fallback.' end
function DB.CanEditActiveProfile() return true end
function DB.CanRenameOrDeleteActiveProfile() return false end
local categories={}
function DB.GetCategory(i)
  if categories[i] then return categories[i] end
  local c=addon.DefaultSections[i]
  local emotes={}
  for j=1,addon.MAX_EMOTES do emotes[j]={label='',defaultCommand='',targetedCommand=''} end
  categories[i]={name=c.name,emotes=emotes}
  return categories[i]
end
function DB.GetCategories()
  for i=1,addon.MAX_CATEGORIES do DB.GetCategory(i) end; return categories
end
function DB.SetProfileTheme(_,name) profiles[activeProfile].theme=name; addon.Settings.RefreshSettingsPanels(); return true end
function DB.GetProfilesUsingTheme(name) return name=='Teal' and {'Example'} or {} end
setmetatable(DB,{__index=function() return function() return true,'okay' end end})
addon.Database=DB
addon.MainWindow=setmetatable({}, {__index=function() return function() end end})
local themeRefreshes=0
addon.MainWindow.ApplyThemeSettings=function() themeRefreshes=themeRefreshes+1 end
function hooksecurefunc() end
addon.IsFontAvailable=function() return true end
addon.GetAvailableFonts=function() return {{name='Friz Quadrata'}} end
addon.Serialization={}
UIParent=CreateFrame('Frame')
CANCEL='Cancel'; DELETE='Delete'; OKAY='Okay'; CLOSE='Close'
StaticPopupDialogs={}; local lastPopup
function StaticPopup_Show(name, text, _, data) lastPopup={name=name,text=text,data=data} end
C_Timer={After=function() end}
UISpecialFrames={}
function strtrim(v) return (v:gsub('^%s+',''):gsub('%s+$','')) end
Settings={RegisterCanvasLayoutCategory=function(panel) return panel end,
 RegisterAddOnCategory=function() end,
 RegisterCanvasLayoutSubcategory=function(_,panel,caption) panel.categoryName=caption; return panel end,
 OpenToCategory=function(id) assert(id==1) end}
-- Match the addon's real load order for the settings modules.
for line in io.lines('RPEmoteMenu/RPEmoteMenu.toc') do
  if line:match('^Settings[%w]*%.lua$') or line=='MinimizedIconColor.lua' then
    loadModule('RPEmoteMenu/'..line)
  end
end
local first=DB.GetCategory(1)
first.emotes[1].label='First'
first.emotes[2].label='Second'
addon.Settings.RegisterSettingsPanels()
addon.Settings.Open()
addon.Settings.OpenAbout()
addon.Settings.OpenEmotes(1)
assert(addon.Settings.RefreshSettingsPanels)
addon.Settings.RefreshSettingsPanels()
local themesPanel,profilesPanel
for _,w in ipairs(widgets) do
  if w.categoryName=='Themes' then themesPanel=w end
  if w.categoryName=='Profiles' then profilesPanel=w end
end
assert(themesPanel and profilesPanel,'Settings categories did not register')
local found={}
for _,w in ipairs(widgets) do if w.text then found[w.text]=true end end
assert(found['Import Theme'] and found['Export Theme'] and found['Restore Bundled Themes'])
assert(found['Theme assigned to this Profile'])
assert(found['Hide setting gear icons'])
assert(not found['Hide settings gear icon'] and not found['Hide emote edit gear icons'])
local gearSwitch
for _,w in ipairs(widgets) do
  if w.text=='Hide setting gear icons' then
    for _,candidate in ipairs(widgets) do
      if candidate.parent==w.parent and candidate.anchor
        and candidate.anchor.y==w.anchor.y+4 and candidate.scripts.OnClick then
        gearSwitch=candidate; break
      end
    end
    break
  end
end
assert(gearSwitch, 'Unified gear toggle missing')
local gearRefreshes,menuRefreshes=0,0
addon.MainWindow.ApplySettingsGearVisibility=function() gearRefreshes=gearRefreshes+1 end
addon.MainWindow.UpdateMenu=function() menuRefreshes=menuRefreshes+1 end
gearSwitch.scripts.OnClick(gearSwitch)
assert(merged.hideSettingsGear and gearRefreshes==1 and menuRefreshes==1)
gearSwitch.scripts.OnClick(gearSwitch)
assert(not merged.hideSettingsGear and gearRefreshes==2 and menuRefreshes==2)
local function assertControlPosition(key, x, y)
  for _,w in ipairs(widgets) do
    if w.settingKey==key then
      assert(w.anchor and w.anchor.x==x and w.anchor.y==y,
        key..' control moved from its intended row')
      return
    end
  end
  error(key..' control missing')
end
assertControlPosition('tooltipDelayMs',255,-151)
assertControlPosition('categoryFont',95,-81)
assertControlPosition('categoryFontSize',160,-121)
assert(not found['Borders'] and not found['Border color'] and not found['Border style'])
for _,w in ipairs(widgets) do
  assert(w.settingKey~='borderColor' and w.settingKey~='borderStyle')
end
for _,w in ipairs(widgets) do
  if w.settingKey=='categoryFont' and w.anchor.x==95 then
    assert(w.parent.anchor and w.parent.anchor.y==-285,
      'Theme editor is too far below its management controls')
  end
end
local function assertTextPosition(label, x, y, panel)
  for _,w in ipairs(widgets) do
    if w.text==label and (not panel or w.parent==panel) then
      assert(w.anchor and w.anchor.x==x and w.anchor.y==y,
        label..' moved from its intended row')
      return
    end
  end
  error(label..' missing')
end
assertTextPosition('Selected profile',20,-85,profilesPanel)
assertTextPosition('Theme assigned to this Profile',20,-149,profilesPanel)
assertTextPosition('Emotes in this category',20,-269)
local rows={}
for _,w in ipairs(widgets) do
  if w.visiblePosition then rows[w.visiblePosition]=w end
end
assert(rows[1] and rows[2], 'Emote list did not populate')
rows[1].scripts.OnDragStart(rows[1])
rows[2].mouseover=true
rows[1].scripts.OnDragStop(rows[1])
assert(first.emotes[1].label=='Second' and first.emotes[2].label=='First',
  'Dragging an emote did not reorder the category')

local function isChildOf(w, ancestor)
  while w do if w==ancestor then return true end; w=w.parent end
  return false
end
local selectedTheme=false
for _,w in ipairs(widgets) do
  if w.MyObject and isChildOf(w,themesPanel) and w.anchor and w.anchor.y==-103 then
    for _,option in ipairs(w.MyObject.func()) do
      if option.value=='Teal' then option.onclick(w.MyObject,nil,option.value); selectedTheme=true; break end
    end
    if selectedTheme then break end
  end
end
assert(selectedTheme,'Bundled Theme missing from menu')
assert(DB.GetActiveThemeName()=='Teal','Editor selection did not change character assignment')
local foundDelete=false
for _,w in ipairs(widgets) do
  if w.text=='Delete' and isChildOf(w,themesPanel) then
    local frame = w.kind=='FontString' and w.parent or w
    if frame.scripts.OnMouseDown then
      frame.scripts.OnMouseDown(frame,'LeftButton'); frame.scripts.OnMouseUp(frame,'LeftButton')
    else frame.scripts.OnClick() end
    foundDelete=true
    break
  end
end
assert(foundDelete and lastPopup.name=='RPEMOTEMENU_DELETE_THEME')
assert(lastPopup.text:find('Example',1,true), 'In-use Theme prompt omitted Profiles')
assert(DB.GetTheme('Teal'), 'Opening deletion prompt changed the Theme')

local function SelectThemeFont()
  for _,w in ipairs(widgets) do
    if w.settingKey=='categoryFont' and isChildOf(w,themesPanel) then
      local chosen=false
      local option=w.MyObject.func()[1]; option.onclick(w.MyObject,nil,option.value); chosen=true
      assert(chosen,'Theme font menu had no options')
      return
    end
  end
  error('Theme font selector missing')
end
SelectThemeFont()
assert(themeRefreshes==1,'Editing the selected Theme did not refresh its appearance')

local edited=false
for _,w in ipairs(widgets) do
  if w.settingKey=='categoryFontSize' and isChildOf(w,themesPanel) then
    w.scripts.OnMouseWheel(w,1); edited=true; break
  end
end
assert(edited and tealSettings.categoryFontSize==13)
assert(addon.DefaultThemeSettings.categoryFontSize==12)
local resetIcon=false
for _,w in ipairs(widgets) do
  if w.text=='Restore Yellow' and isChildOf(w,themesPanel) then
    tealSettings.minimizedIconColor={r=0,g=0,b=1}
    local frame = w.kind=='FontString' and w.parent or w
    frame.scripts.OnMouseDown(frame,'LeftButton'); frame.scripts.OnMouseUp(frame,'LeftButton')
    resetIcon=true
    assert(tealSettings.minimizedIconColor.r==1 and tealSettings.minimizedIconColor.b==0)
    break
  end
end
assert(resetIcon,'Theme icon color reset missing')
local assigned=false
for _,w in ipairs(widgets) do
  if w.MyObject and isChildOf(w,profilesPanel)
    and type(w.anchor)=='table' and w.anchor.y==-171 then
    for _,option in ipairs(w.MyObject.func()) do
      if option.value=='Default' then
        option.onclick(w.MyObject,nil,option.value); assigned=true; break
      end
    end
    if assigned then break end
  end
end
assert(assigned and DB.GetActiveThemeName()=='Default')
local editorSelection
for _,w in ipairs(widgets) do
  if w.MyObject and isChildOf(w,themesPanel) and w.anchor and w.anchor.y==-103 then
    editorSelection=w.MyObject.myvalue
    assert(w.MyObject.label:GetText()=='Default', 'Theme editor dropdown did not refresh its text')
    break
  end
end
assert(editorSelection=='Default','Theme editor did not follow Profile assignment')
local editedDefault=false
for _,w in ipairs(widgets) do
  if w.settingKey=='categoryFontSize' and isChildOf(w,themesPanel) then
    w.scripts.OnMouseWheel(w,1); editedDefault=true; break
  end
end
assert(editedDefault and addon.DefaultThemeSettings.categoryFontSize==13,
  'Theme editor controls did not follow Profile assignment')
assert(tealSettings.categoryFontSize==13,'Editing Default changed Teal')
themeRefreshes=0
SelectThemeFont()
assert(themeRefreshes==1,'Editing the active Theme did not refresh its appearance')
assert(StaticPopupDialogs['RPEMOTEMENU_DELETE_THEME'])
assert(StaticPopupDialogs['RPEMOTEMENU_RESTORE_DEFAULT_PROFILE'])
addon.Serialization.ExportEverything=function() return '{"type":"everything"}' end
addon.Serialization.ImportThemeAsNew=function()
  themes.Imported={settings=tealSettings}
  return true, 'Imported', 'Source'
end
local exchange=addon.SettingsUI.GetExchangeDialog()
assert(exchange:OpenEverythingExport())
assert(exchange.dataType=='everything')
local imported
exchange:OpenThemeImport(function(name) imported=name end)
exchange.editBox:SetText('{"type":"theme"}')
exchange.actionButton.scripts.OnClick()
assert(imported=='Imported')
assert(addon.Settings.RefreshEditors and addon.Settings.RefreshCategorySelector)
assert(addon.Settings.RefreshGeneralWindowFields and addon.Settings.RefreshFontControls)
addon.Settings.RefreshEditors(1)
addon.Settings.RefreshGeneralWindowFields()
addon.Settings.RefreshFontControls()

-- Load Core last, as the .toc does, and exercise its ADDON_LOADED registration.
local toc={}
for line in io.lines('RPEmoteMenu/RPEmoteMenu.toc') do
  if line:match('%.lua$') then
    assert(io.open('RPEmoteMenu/'..line,'r')):close()
    toc[#toc+1]=line
  end
end
assert(toc[1]=='Libs/LibStub/LibStub.lua' and toc[2]=='Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua'
 and toc[3]=='Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua' and toc[4]=='Defaults.lua'
 and toc[5]=='SettingDefinitions.lua' and toc[6]=='Scheduling.lua' and toc[7]=='FontMedia.lua' and toc[#toc]=='Core.lua')
local openedSettings,openedAbout=0,0
local originalOpen,originalAbout=addon.Settings.Open,addon.Settings.OpenAbout
addon.Settings.Open=function() openedSettings=openedSettings+1; originalOpen() end
addon.Settings.OpenAbout=function() openedAbout=openedAbout+1; originalAbout() end
DB.InitializeDatabase=function() end
addon.MainWindow.CreateMainWindow=function() end
addon.Settings.RegisterSettingsPanels=function() end
local mainFrame=CreateFrame('Frame')
function mainFrame:IsShown() return self.shown==true end
function mainFrame:Show() self.shown=true end
function mainFrame:Hide() self.shown=false end
addon.MainWindow.GetFrame=function() return mainFrame end
local activationSettings = {active = false}
DB.GetGlobalSettings=function() return activationSettings end
DB.SetActive=function(active)
    activationSettings.active = active
    if active then mainFrame:Show() else mainFrame:Hide() end
end
addon.MainWindow.UpdateMenu=function() end
C_AddOns={GetAddOnMetadata=function() return '2.0.203' end}
SlashCmdList={}
local previousCount=#widgets
loadModule('RPEmoteMenu/Core.lua')
local eventFrame=widgets[previousCount+1]
assert(eventFrame and eventFrame.scripts.OnEvent)
eventFrame.scripts.OnEvent(eventFrame,'ADDON_LOADED','RPEmoteMenu')
assert(SLASH_ELLEMOTE1=='/rpem' and SlashCmdList.ELLEMOTE)
for _,command in ipairs({'config','options','settings'}) do SlashCmdList.ELLEMOTE(command) end
SlashCmdList.ELLEMOTE('about')
assert(openedSettings==3 and openedAbout==1,'Slash routes did not open Settings/About')
SlashCmdList.ELLEMOTE('')
assert(activationSettings.active and mainFrame:IsShown(),'Slash toggle did not show the menu')
SlashCmdList.ELLEMOTE('')
assert(not activationSettings.active and not mainFrame:IsShown(),'Slash toggle did not hide the menu')
print('PASS settings registration, row positions, refresh, Theme actions, Emote drag, exchange, slash commands')

