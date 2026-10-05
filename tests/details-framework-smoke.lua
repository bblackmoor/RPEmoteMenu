-- Real DF sources and adapter, with explicit native UI stubs only.
-- Run from repository root: luatex --luaonly tests/details-framework-smoke.lua
local ui = dofile("tests/details-framework-ui-stubs.lua")
local root = "RPEmoteMenu/"
local LoadXML = dofile("tests/details-framework-loader.lua")
local scripts, manifests = LoadXML("Libs/DetailsFramework/load.xml")
assert(scripts == 52 and manifests == 9, "complete pinned load chain")
assert(not Details and not Plater, "standalone test has no addon hosts")
local df = LibStub:GetLibrary("DetailsFramework-1.0")
assert(df.dversion == 762)
for _, callback in ipairs(df.OnLoginSchedules) do callback() end
local ns = {SettingsUI = {}}
assert(loadfile(root .. "Scheduling.lua"))("RPEmoteMenu", ns)
local originalUI = ns.SettingsUI
assert(loadfile(root .. "SettingsWidgets.lua"))("RPEmoteMenu", ns)
local widgets = ns.SettingsWidgets
assert(ns.SettingsUI == originalUI and not ns.SettingsPanels, "adapter does not register or replace legacy pages")
assert(RPEmoteMenuDB == nil, "loading must not initialize saved settings")
assert(widgets.GetFramework() == df)

local changes, selected, rgb = 0
local function Changed() changes = changes + 1 end
local switch = widgets.CreateSwitch(UIParent, Changed)
assert(switch.widget.is_toggle and switch.frame:GetWidth() == 44)
assert(widgets.GetFrame(switch) == switch.frame)
assert(widgets.GetFrame(switch.widget) == switch.frame)
assert(widgets.GetFrame(UIParent) == UIParent)
switch:SetChecked(true)
switch:SetChecked(true)
assert(changes == 0 and switch:GetChecked(), "switch refresh is silent")
switch.frame:GetScript("OnClick")(switch.frame, "LeftButton")
assert(changes == 1 and not switch:GetChecked(), "user switch click notifies once")
switch:SetEnabled(false)
switch.frame:GetScript("OnClick")(switch.frame, "LeftButton")
assert(changes == 1 and not switch.frame:IsEnabled() and switch.frame.alpha == 0.5)
switch:SetEnabled(true)

local builds = 0
local dropdown = widgets.CreateDropdown(UIParent, function()
    builds = builds + 1
    return {{label = "One", value = "ONE"}, {label = "Two", value = "TWO"}}
end, function(value) Changed(); selected = value end)
dropdown:SetValue("ONE")
dropdown:SetValue("TWO")
dropdown:SetLabel("Current label")
assert(builds == 1 and changes == 1 and dropdown:GetValue() == "TWO")
assert(dropdown.widget.label:GetText() == "Current label")
dropdown:InvalidateOptions()
dropdown:SetValue("ONE")
assert(builds == 2 and changes == 1)
dropdown.widget.func()[2].onclick(dropdown.widget, nil, "TWO")
assert(changes == 2 and selected == "TWO" and dropdown:GetValue() == "TWO")
dropdown:SetEnabled(false)
dropdown.widget.func()[1].onclick(dropdown.widget, nil, "ONE")
assert(changes == 2 and dropdown:GetValue() == "TWO", "disabled callback is ignored")

local function Click(frame)
    frame:GetScript("OnMouseDown")(frame, "LeftButton")
    frame:GetScript("OnMouseUp")(frame, "LeftButton")
end
local button = widgets.CreateButton(UIParent, "Action", Changed)
Click(button.frame)
assert(changes == 3, "DF button callback adapts to simple action")
button:SetEnabled(false)
Click(button.frame)
assert(changes == 3)

-- Native text-entry events bypass DF's default trimming/empty-input handlers.
local saved, writes, owner = "Original", 0, {}
local text = widgets.CreateTextEntry(switch, function() return saved end,
    function(value) saved = value; writes = writes + 1 end,
    {width = 190, getOwner = function() return owner end})
assert(text.frame:GetParent() == switch.frame)
text:SetPoint("LEFT", switch, "RIGHT", 8, 0)
assert(text.frame.point[2] == switch.frame)
local function Event(control, event, ...) control.frame:GetScript(event)(control.frame, ...) end
local function Type(control, value)
    control.frame:SetFocus()
    control.frame:SetText(value)
    Event(control, "OnTextChanged", true)
end
Type(text, "  exact spaces  "); Event(text, "OnEnterPressed")
assert(saved == "  exact spaces  " and writes == 1, "Enter preserves exact text and commits once")
Type(text, ""); text:ClearFocus()
assert(saved == "" and writes == 2, "focus loss commits empty text")
Type(text, "   "); Event(text, "OnEnterPressed")
assert(saved == "   " and writes == 3, "whitespace-only value is preserved")
Type(text, "cancel"); Event(text, "OnEscapePressed")
assert(saved == "   " and writes == 3 and text:GetText() == saved)
text:SetText("programmatic"); text:ClearFocus(); text:RefreshValue()
assert(writes == 3 and text:GetText() == saved, "refresh is silent")
Type(text, "disabled"); text:SetEnabled(false); Event(text, "OnEnterPressed")
assert(writes == 3 and text:GetText() == saved and not text.frame:IsEnabled())
text:SetEnabled(true)
Type(text, "hidden"); text.frame:Hide()
assert(writes == 3 and text:GetText() == saved, "hide cancels pending edits")
saved = "new page value"; Event(text, "OnShow")
assert(writes == 3 and text:GetText() == saved)
Type(text, "old owner's edit"); owner = {}; saved = "new owner"
Event(text, "OnEnterPressed")
assert(writes == 3 and text:GetText() == "new owner", "selection changes cannot redirect a pending commit")
Type(text, "next edit"); text:ClearFocus()
assert(writes == 4 and saved == "next edit")

local integer, numberWrites = 12, 0
local number = widgets.CreateIntegerEntry(UIParent, function() return integer end,
    function(value) integer = value; numberWrites = numberWrites + 1 end,
    {minimum = 0, maximum = 100})
Type(number, "999"); Event(number, "OnEnterPressed")
assert(integer == 100 and number:GetText() == "100" and numberWrites == 1)
Type(number, "invalid"); Event(number, "OnEnterPressed")
Type(number, ""); number:ClearFocus()
assert(integer == 100 and numberWrites == 1, "invalid/empty numeric edits restore saved value")
Type(number, "25"); Event(number, "OnEscapePressed")
assert(integer == 100 and numberWrites == 1)
Event(number, "OnMouseWheel", -1)
assert(integer == 99 and numberWrites == 2)
number:SetEnabled(false); Event(number, "OnMouseWheel", -1)
assert(integer == 99 and numberWrites == 2)
local coordinate = widgets.CreateIntegerEntry(UIParent, function() return integer end,
    function(value) integer = value; numberWrites = numberWrites + 1 end,
    {allowNegative = true, width = 80})
Type(coordinate, "-250"); Event(coordinate, "OnEnterPressed")
assert(integer == -250 and numberWrites == 3)
for _, invalid in ipairs({"-", "-1.5", "NaN", "1e4"}) do
    Type(coordinate, invalid); Event(coordinate, "OnEnterPressed")
    assert(integer == -250 and numberWrites == 3)
end
Event(coordinate, "OnMouseWheel", 1)
assert(integer == -249 and numberWrites == 4)

local setValue = switch.widget.SetValue
switch.widget.SetValue = function() error("intentional refresh failure") end
assert(not pcall(switch.SetChecked, switch, true) and switch.refreshDepth == 0)
switch.widget.SetValue = setValue

-- The real existing database and picker manager remain the swatch authority.
assert(RPEmoteMenuDB == nil, "adapter loading/editing does not initialize saved data")
function strtrim(value) return (value:gsub("^%s+", ""):gsub("%s+$", "")) end
for _, file in ipairs({"Defaults.lua", "SettingDefinitions.lua", "BuiltInThemes.lua", "Database.lua"}) do
    assert(loadfile(root .. file))("RPEmoteMenu", ns)
end
ns.Database.InitializeDatabase()
assert(loadfile(root .. "SettingsColorPicker.lua"))("RPEmoteMenu", ns)
local db, colorWrites = ns.Database, 0
local function Color() return db.GetThemeSettings().categoryTextColor end
local original = {r = Color().r, g = Color().g, b = Color().b}
local color = widgets.CreateColorPicker(UIParent, Color, function(value)
    colorWrites = colorWrites + 1; db.GetThemeSettings().categoryTextColor = value
end)
local function Preview(info)
    function ColorPickerFrame:GetColorRGB() return 0.8, 0.7, 0.6 end
    info.swatchFunc()
end
color:RefreshValue(); Click(color.frame)
local first = ColorPickerFrame.info
assert(colorWrites == 0 and not first.hasOpacity and not first.opacityFunc, "opening/refresh is silent RGB")
Preview(first)
assert(colorWrites == 1 and Color().r == 0.8)
first.cancelFunc()
assert(colorWrites == 2 and Color().r == original.r and color.Swatch.color[1] == original.r)
Click(color.frame); local disabled = ColorPickerFrame.info; Preview(disabled)
color:SetEnabled(false)
assert(Color().r == original.r and not ColorPickerFrame:IsShown())
local count = colorWrites; Preview(disabled); disabled.cancelFunc()
assert(colorWrites == count, "disabled session callbacks are retired")
color:SetEnabled(true); Click(color.frame)
local accepted = ColorPickerFrame.info; Preview(accepted); ColorPickerFrame:Hide()
count = colorWrites; ns.SettingsUI.CancelColorEdit(); accepted.cancelFunc()
assert(colorWrites == count and Color().r == 0.8, "Okay commits preview")
Click(color.frame); local hidden = ColorPickerFrame.info; Preview(hidden); color.frame:Hide()
count = colorWrites; Preview(hidden)
assert(colorWrites == count and not ColorPickerFrame:IsShown(), "owner hide retires callbacks")
Click(color.frame); local displaced = ColorPickerFrame.info
ColorPickerFrame:SetupColorPickerAndShow({extraInfo = {}, swatchFunc = function() end})
count = colorWrites; ns.SettingsUI.CancelColorEdit(); Preview(displaced); displaced.cancelFunc()
assert(colorWrites == count and ColorPickerFrame:IsShown(), "another addon's picker stays open")
ColorPickerFrame:Hide()
Click(color.frame); local stale = ColorPickerFrame.info; Preview(stale)
assert(db.SetProfileTheme('Default', 'Teal'))
local currentColor = Color()
count = colorWrites; Preview(stale); stale.cancelFunc()
assert(colorWrites == count and Color() == currentColor and not ColorPickerFrame:IsShown(),
    "Theme selection retires the adapter's native picker owner")

local link = widgets.CreateLink(UIParent, "Information", Changed)
local function DescendsFrom(object, ancestor)
    while object do
        if object == ancestor then return true end
        object = object:GetParent()
    end
end
for _, control in ipairs({switch, dropdown, button, color, text, number, coordinate, link}) do
    for _, object in ipairs(ui.objects) do
        if DescendsFrom(object, control.frame) then
            for _, asset in ipairs({object.texture or "", object.backdrop and object.backdrop.bgFile or "",
                object.backdrop and object.backdrop.edgeFile or ""}) do
                assert(not tostring(asset):find("AddOns\\Details\\", 1, true), "external widget asset: " .. tostring(asset))
            end
        end
    end
end

-- Emulate a newer compatible embedder winning LibStub arbitration. Reloading
-- our bundle must preserve its table and registered methods, not downgrade it.
df.externalMarker = true
LibStub.minors["DetailsFramework-1.0"] = 763
LoadXML("Libs/DetailsFramework/load.xml")
assert(LibStub:GetLibrary("DetailsFramework-1.0") == df and df.externalMarker)
assert(LibStub.minors["DetailsFramework-1.0"] == 763 and widgets.GetFramework() == df)
local createSwitch = df.CreateSwitch
df.CreateSwitch = nil
local available, reason = widgets.GetFramework()
assert(not available and reason:find("CreateSwitch"), "incompatible external methods detected")
df.CreateSwitch = createSwitch
local originalStub = LibStub
LibStub = nil
assert(widgets.GetFramework() == nil, "missing library fails only at adapter construction")
LibStub = originalStub
assert(widgets.GetFramework() == df)


-- Traverse the actual native option handler, which selects before its callback.
local nativeChanges = 0
local review = widgets.CreateDropdown(UIParent, function()
    return {{value='ONE',label='One'}, {value='TWO',label='Two'}}
end, function() nativeChanges = nativeChanges + 1 end)
local function OpenReview()
    review.frame:GetScript('OnMouseDown')(review.frame, 'LeftButton')
    assert(review.widget.opened)
end
local function AssertOne()
    assert(review:GetValue() == 'ONE' and review.widget.myvalue == 'ONE')
    assert(review.widget.label:GetText() == 'One' and review.widget.myvaluelabel == 'One')
end
review:SetValue('ONE', 'One'); OpenReview()
local row = review.widget.menus[2]
local disabledClick = row:GetScript('OnMouseDown')
review:SetEnabled(false); assert(not review.widget.opened)
disabledClick(row, 'LeftButton'); AssertOne(); assert(nativeChanges == 0)
review.frame:GetScript('OnMouseDown')(review.frame, 'LeftButton'); assert(not review.widget.opened)
review:SetEnabled(true); OpenReview()
local retiredClick = row:GetScript('OnMouseDown')
review:InvalidateOptions(); review:SetValue('ONE', 'One')
retiredClick(row, 'LeftButton'); AssertOne(); assert(nativeChanges == 0)
OpenReview(); assert(review.widget.menus[2] == row, 'pooled rows should be reused')
retiredClick(row, 'LeftButton'); AssertOne(); assert(nativeChanges == 0)
row:GetScript('OnMouseDown')(row, 'LeftButton')
assert(nativeChanges == 1 and review:GetValue() == 'TWO' and review.widget.myvalue == 'TWO')
assert(review.widget.label:GetText() == 'Two' and not review.widget.opened)
row:GetScript('OnMouseDown')(row, 'LeftButton'); assert(nativeChanges == 1, 'closed menus are inert')
-- An explicit rejection/refresh during the callback wins over DF's final write.
local rejected
rejected = widgets.CreateDropdown(UIParent, function()
    return {{value='ONE',label='One'}, {value='TWO',label='Two'}}
end, function()
    rejected:SetValue('ONE', 'Canonical One')
end)
rejected:SetValue('ONE', 'Canonical One')
rejected.frame:GetScript('OnMouseDown')(rejected.frame, 'LeftButton')
local rejectedRow = rejected.widget.menus[2]
rejectedRow:GetScript('OnMouseDown')(rejectedRow, 'LeftButton')
assert(rejected:GetValue() == 'ONE' and rejected.widget.myvalue == 'ONE')
assert(rejected.widget.label:GetText() == 'Canonical One' and rejected.widget.myvaluelabel == 'Canonical One')

-- Canvas construction and wheel movement use the actual bundled DF implementation.
local canvas, child = widgets.CreateCanvasScrollBox(UIParent, {step = 40})
assert(canvas:GetScrollChild() == child and child:GetParent() == canvas)
assert(canvas.options.reskin_slider == false and not canvas:GetSmoothScrolling())
assert(not canvas:GetUseMomentum() and not canvas:GetUseDragScroll())
assert(canvas:GetScript('OnUpdate') == nil)
local range = 300
function canvas:GetVerticalScrollRange() return range end
local rectUpdates = 0
function canvas:UpdateScrollChildRect() rectUpdates = rectUpdates + 1 end
canvas:GetScript('OnMouseWheel')(canvas, -2); assert(canvas:GetVerticalScroll() == 80)
canvas:GetScript('OnMouseWheel')(canvas, 0); assert(canvas:GetVerticalScroll() == 80)
range = 25; child:GetScript('OnSizeChanged')(child)
assert(canvas:GetVerticalScroll() == 25 and rectUpdates == 1)
range = 0; canvas:GetScript('OnSizeChanged')(canvas)
assert(canvas:GetVerticalScroll() == 0 and rectUpdates == 2)
canvas:GetScript('OnMouseDown')(canvas, 'LeftButton')
assert(not canvas.isDragging)
local currentMethod = df.CreateCanvasScrollBox
df.CreateCanvasScrollBox = nil
assert(not widgets.GetFramework())
df.CreateCanvasScrollBox = currentMethod

print('PASS Details Framework adapters and native dropdown clicks, disable, retirement, row reuse and callback rejection')

-- Dialog drafts use real DF controls without page-style focus commits.
local draft = widgets.CreateDialogTextEntry(UIParent, 390, 24)
assert(draft.MyObject.type == "textentry")
assert(draft.maxBytes == 0 and draft.maxLetters == 0)
assert(not draft:GetScript("OnEditFocusLost") and not draft:GetScript("OnEnterPressed"))
for _, value in ipairs({"", "   ", "  exact text  ", string.rep("é", 65000)}) do
    draft:SetText(value); draft:SetFocus(); draft:ClearFocus()
    assert(draft:GetText() == value)
end
local shell = widgets.CreateDialog("RPEmoteMenuTestDialog", 610, 330)
assert(shell:GetWidth() == 610 and shell:GetHeight() == 330)
assert(shell.TitleBar and not shell.TitleBar:IsShown())
assert(not shell:GetScript("OnMouseDown"), "DF click-to-move/right-click-close policy is disabled")
local registrations = 0
for _, name in ipairs(UISpecialFrames) do if name == "RPEmoteMenuTestDialog" then registrations = registrations + 1 end end
assert(registrations == 1, "Escape registration occurs once")
local action = widgets.CreateDialogButton(shell, "Save", 110, 24)
local clicks = 0
 action:SetScript("OnClick", function() clicks = clicks + 1 end)
Click(action); assert(clicks == 0, "DF mouse-up callback cannot also save")
action:GetScript("OnClick")(action); assert(clicks == 1)
