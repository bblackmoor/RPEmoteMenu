-- Run from the repository root: texlua --luaonly tests/settings-smoke.lua
-- A small WoW UI stub catches settings registration, module-order, and
-- cross-panel wiring regressions. Real WoW layout still requires an in-game check.
local addon = {VERSION = 'test'}
local function loadModule(path)
    local chunk = assert(loadfile(path))
    chunk('RPEmoteMenu', addon)
end
loadModule('RPEmoteMenu/Defaults.lua')
loadModule('RPEmoteMenu/BuiltInThemes.lua')
local widgets = {}
local Widget = {}
Widget.__index = function(_, key)
    if key == "Text" or key == "InternalText" or key == "MissingFontName" or key == "emoteIndex" or key == "parent" then return nil end
    return Widget[key] or function() end
end
function Widget:CreateFontString() return CreateFrame('FontString', nil, self) end
function Widget:CreateTexture() return CreateFrame('Texture', nil, self) end
function Widget:SetText(v) self.text = v end
function Widget:GetText() return self.text or '' end
function Widget:SetSize(w,h) self.width=w; self.height=h end
function Widget:GetWidth() return self.width or 250 end
function Widget:GetHeight() return self.height or 24 end
function Widget:GetStringWidth() return 10 end
function Widget:GetStringHeight() return 16 end
function Widget:SetScript(event, callback) self.scripts[event]=callback end
function Widget:HookScript(event, callback) self.scripts[event]=callback end
function Widget:SetEnabled(v) self.enabled=v end
function Widget:IsEnabled() return self.enabled ~= false end
function Widget:SetupMenu(fn) self.menu=fn end
function Widget:SetChecked(v) self.checked=v end
function Widget:GetChecked() return self.checked end
function Widget:GetID() return 1 end
function Widget:IsShown() return true end
function Widget:IsMouseOver() return self.mouseover == true end
function Widget:GetFontString() return nil end
function Widget:SetFont() return true end
function Widget:SetVerticalScroll() end
function CreateFrame(kind, _, parent)
    local widget=setmetatable({kind=kind,parent=parent,scripts={}}, Widget)
    widgets[#widgets+1]=widget
    return widget
end
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
STANDARD_TEXT_FONT='font'; CANCEL='Cancel'; DELETE='Delete'; OKAY='Okay'; CLOSE='Close'
StaticPopupDialogs={}; local lastPopup
function StaticPopup_Show(name, text, _, data) lastPopup={name=name,text=text,data=data} end
C_Timer={After=function() end}
GameTooltip=setmetatable({}, Widget)
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
addon.Settings.CreateSettingsPanel()
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
  if w.menu and isChildOf(w,themesPanel) then
    local root={CreateRadio=function(_,label,_,action)
      if label=='Teal (Bundled)' then action(); selectedTheme=true end
    end, CreateButton=function() end}
    w.menu(w,root)
    if selectedTheme then break end
  end
end
assert(selectedTheme,'Bundled Theme missing from menu')
assert(DB.GetActiveThemeName()=='Default','Editor selection changed character assignment')
local foundDelete=false
for _,w in ipairs(widgets) do
  if w.text=='Delete' and isChildOf(w,themesPanel) then
    w.scripts.OnClick()
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
      w.menu(w,{CreateRadio=function(_,_,_,action) action(); chosen=true end})
      assert(chosen,'Theme font menu had no options')
      return
    end
  end
  error('Theme font selector missing')
end
SelectThemeFont()
assert(themeRefreshes==0,'Editing an inactive Theme refreshed the active Theme')

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
    w.scripts.OnClick(w)
    resetIcon=true
    assert(tealSettings.minimizedIconColor.r==1 and tealSettings.minimizedIconColor.b==0)
    break
  end
end
assert(resetIcon,'Theme icon color reset missing')
local assigned=false
for _,w in ipairs(widgets) do
  if w.menu and isChildOf(w,profilesPanel) then
    local root={CreateRadio=function(_,label,_,action)
      if label=='Teal' then action(); assigned=true end
    end}
    w.menu(w,root)
    if assigned then break end
  end
end
assert(assigned and DB.GetActiveThemeName()=='Teal')
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
print('PASS Phase 6 registration, selected Theme edit, assignment, dialogs, exchange')
