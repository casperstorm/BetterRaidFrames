local Addon = {}
local settings = { buffIndicators = {} }
local profile = 'Default'
local inCombat = false
local widgets = {}
local methods = {}
local function widget(kind, parent, template)
    local value = setmetatable({ kind = kind, parent = parent, template = template, scripts = {} }, { __index = methods })
    widgets[#widgets + 1] = value
    return value
end
function methods:SetPoint(...) self.point = {...} end
function methods:SetSize(w,h) self.width, self.height = w,h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetHeight() return self.height or 160 end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level or 5 end
function methods:SetScrollChild(child) self.child = child end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:SetupMenu(builder) self.builder = builder; self:GenerateMenu() end
function methods:GenerateMenu()
    self.items = {}
    local items = self.items
    local root = {}
    function root:CreateRadio(label, selected, callback, value)
        items[#items + 1] = { label = label, selected = selected, callback = callback, value = value }
    end
    self.builder(self, root)
end
function methods:SetText(t) self.text = t end
function methods:GetText() return self.text or '' end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:HookScript(name, callback) self.scripts[name] = callback end
function methods:SetOrientation(value) self.orientation = value end
function methods:SetReverseFill(value) self.reverse = value end
function methods:SetStatusBarTexture(value) self.asset = value end
function methods:SetStatusBarColor(...) self.fillColor = {...} end
function methods:SetMinMaxValues(min, max) self.min, self.max = min, max end
function methods:Init(value, min, max, steps) self.value, self.min, self.max, self.steps = value,min,max,steps end
function methods:SetValue(value)
    self.value = value
    if self.Slider and self.Slider.scripts.OnValueChanged then self.Slider.scripts.OnValueChanged(self.Slider, value) end
end
function methods:SetChecked(c) self.checked = c end
function methods:GetChecked() return self.checked end
function methods:SetShown(s) self.shown = s end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false; self.hideCount = (self.hideCount or 0) + 1 end
function methods:SetEnabled(v) self.enabled = v end
function methods:SetAlpha(v) self.alpha = v end
function methods:SetTexture(v) self.asset = v end
function methods:SetColorTexture(...) self.color = {...} end
function methods:CreateTexture() return widget('Texture', self) end
function methods:CreateFontString() return widget('FontString', self) end
for _, method in ipairs({'SetJustifyH', 'SetTextColor', 'SetAllPoints', 'SetAutoFocus', 'SetMaxLetters', 'ClearFocus', 'SetFontObject', 'SetWordWrap', 'EnableMouse', 'ClearAllPoints'}) do
    methods[method] = function() end
end
function CreateFrame(kind, _, parent, template)
    local result = widget(kind, parent, template)
    if kind == 'CheckButton' then result.Text = widget('FontString', result) end
    if template == 'MinimalSliderWithSteppersTemplate' then result.Slider = widget('Slider', result) end
    return result
end
function InCombatLockdown() return inCombat end
function Addon:GetSetting(key) return settings[key] end
function Addon:SetSetting(key, value) settings[key] = value end
function Addon:GetCurrentProfileName() return profile end
C_Spell = { GetSpellInfo = function(value)
    local id = tonumber(value) or (value == 'Echo' and 364343)
    if id and id > 0 then return { spellID = id, name = 'Buff ' .. id, iconID = 1 } end
end }
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
function CreateMinimalSliderFormatter(_, callback) return callback end
ColorPickerFrame = { SetupColorPickerAndShow = function(_, info) ColorPickerFrame.info = info end, GetColorRGB = function() return .3,.4,.5 end }
assert(loadfile('BuffIndicators.lua'))('BetterRaidFrames', Addon)
assert(loadfile('BuffIndicatorsConfig.lua'))('BetterRaidFrames', Addon)
local refresh = Addon:BuildBuffIndicatorsOptions(widget('Frame'), -38)
local function find(predicate)
    for _, value in ipairs(widgets) do if predicate(value) then return value end end
    error('widget not found')
end
local input = find(function(w) return w.kind == 'EditBox' end)
local add = find(function(w) return w.text == 'Add Buff' end)
local preview = find(function(w) return w.kind == 'Frame' and w.width == 180 end)
local scroll = find(function(w) return w.kind == 'ScrollFrame' end)
local thickness = find(function(w) return w.template == 'MinimalSliderWithSteppersTemplate' and w.max == 12 end)
local level = find(function(w) return w.template == 'MinimalSliderWithSteppersTemplate' and w.max == 200 end)
local function enter(text) input:SetText(text); add.scripts.OnClick() end
local function row(id)
    return find(function(w) return w.name and w.name.text == 'Buff ' .. id and w.shown end)
end
local function entry(id)
    for _, buff in ipairs(settings.buffIndicators) do
        if buff.spellID == id then return buff end
    end
end
local function selectBuff(id)
    local value = row(id)
    if value.edit.text == 'Settings' then value.edit.scripts.OnClick() end
    assert(value.edit.text == 'Close')
end
local function choice(value)
    for _, w in ipairs(widgets) do
        for _, item in ipairs(w.items or {}) do
            if item.value == value then return item, w end
        end
    end
    error('choice not found: ' .. value)
end
local function choose(value)
    local item = choice(value)
    item.callback(value)
end
local function removeBuff(id)
    local value = find(function(w) return w.parent == row(id) and w.text == 'Remove' end)
    value.scripts.OnClick()
end
local function bar(index)
    local bars = {}
    for _, w in ipairs(widgets) do
        if w.kind == 'StatusBar' and w.parent == preview then bars[#bars + 1] = w end
    end
    return bars[index]
end

enter('nonsense')
assert(#settings.buffIndicators == 0)
enter('Echo')
assert(entry(364343) and input:GetText() == '')
assert(row(364343).edit.text == 'Close', 'adding a buff should open its own settings')
local editorHides = thickness.parent.hideCount
thickness:SetValue(4)
level:SetValue(112)
assert(thickness.parent.hideCount == editorHides, 'slider updates must not hide the editor and interrupt dragging')
choose('LEFT')
choose('REMAINING')
assert(entry(364343).thickness == 4 and entry(364343).frameLevel == 112)
assert(choice('ELAPSED').label == 'Fill (top to bottom)')
assert(choice('REMAINING').label == 'Drain (bottom to top)')
enter('774')
assert(row(364343).edit.text == 'Settings' and row(774).edit.text == 'Close')
assert(thickness.value == 2 and level.value == 10, 'new buffs should start with their own defaults')
choose('RIGHT')
thickness:SetValue(7)
level:SetValue(22)
assert(entry(364343).position == 'LEFT' and entry(774).position == 'RIGHT')
assert(entry(364343).thickness == 4 and entry(774).thickness == 7)
assert(entry(364343).direction == 'REMAINING' and entry(774).direction == 'ELAPSED')
assert(entry(364343).frameLevel == 112 and entry(774).frameLevel == 22)
assert(bar(1).point[1] == 'TOPLEFT' and bar(2).point[1] == 'TOPRIGHT')
assert(bar(1).width == 4 and bar(1).height == 42)
assert(bar(2).width == 7 and bar(2).height == 42)
assert(bar(1).level == 119 and bar(2).level == 29)
preview.scripts.OnShow()
preview.scripts.OnUpdate(preview, 1)
assert(bar(1).value == .75 and bar(2).value == .25, 'preview buffs must animate in their own directions')

local staleChoice = choice('BOTTOM')
selectBuff(364343)
assert(thickness.value == 4 and level.value == 112, "switching the editor must load that buff's settings")
staleChoice.callback(staleChoice.value)
assert(entry(364343).position == 'LEFT' and entry(774).position == 'RIGHT', 'stale menus must not edit another buff')
choose('TOP')
assert(choice('ELAPSED').label == 'Fill (left to right)')
assert(choice('REMAINING').label == 'Drain (right to left)')
assert(bar(1).orientation == 'HORIZONTAL' and bar(1).width == 176 and bar(1).height == 4)
assert(bar(2).orientation == 'VERTICAL' and bar(2).height == 42)
selectBuff(774)
choose('TOP')
assert(bar(1).width == 87 and bar(2).point[4] == 90, 'preview should split only buffs sharing an edge')
row(364343).enabled:SetChecked(false)
row(364343).enabled.scripts.OnClick(row(364343).enabled)
assert(bar(1).shown == false and bar(2).point[4] == 90, 'disabled buffs should reserve their preview segment')
choose('RIGHT')

local mine = row(774).mine
mine:SetChecked(false)
mine.scripts.OnClick(mine)
assert(entry(774).mineOnly == false and entry(364343).mineOnly == true)
local swatch = find(function(w) return w.kind == 'Button' and w.width == 20 and w.parent == row(774) end)
swatch.scripts.OnClick()
local originalR = entry(774).r
ColorPickerFrame.info.swatchFunc()
assert(entry(774).r == .3 and entry(364343).r == 1)
ColorPickerFrame.info.cancelFunc()
assert(entry(774).r == originalR)
swatch.scripts.OnClick()
removeBuff(364343)
assert(row(774).edit.text == 'Close', 'removing an earlier row must keep the editor on the same spell')
thickness:SetValue(9)
assert(entry(774).thickness == 9 and bar(1).width == 9)
ColorPickerFrame.info.swatchFunc()
assert(entry(774).r == originalR, 'a stale colour picker must not edit a shifted row')

inCombat = true
choose('BOTTOM')
thickness:SetValue(12)
removeBuff(774)
assert(entry(774).position == 'RIGHT' and entry(774).thickness == 9)
inCombat = false
refresh()
assert(thickness.value == 9)

local originalSettings = settings
local oldChoice = choice('LEFT')
profile = 'Other'
settings = { buffIndicators = Addon:NormalizeBuffIndicators({ { spellID = 774, position = 'BOTTOM', thickness = 3 } }) }
refresh()
assert(row(774).edit.text == 'Settings', 'switching profiles must close the old editor')
oldChoice.callback(oldChoice.value)
thickness:SetValue(10)
assert(entry(774).position == 'BOTTOM' and entry(774).thickness == 3, 'hidden or stale controls must not edit the new profile')
selectBuff(774)
assert(thickness.value == 3 and choice('BOTTOM').selected('BOTTOM'))
choose('LEFT')
assert(originalSettings.buffIndicators[1].position == 'RIGHT', 'profile edits must stay isolated')

for id = 1, 7 do enter(tostring(id)) end
assert(#settings.buffIndicators == 8 and add.enabled == false)
assert(row(7).edit.text == 'Close')
assert(scroll:GetVerticalScroll() > 0, 'a newly added buff should scroll into view')
assert(scroll:GetVerticalScroll() + scroll:GetHeight() >= row(7).offset + row(7):GetHeight())
row(7).edit.scripts.OnClick()
assert(row(7).edit.text == 'Settings')
assert(scroll:GetVerticalScroll() <= math.max(0, scroll.child:GetHeight() - scroll:GetHeight()), 'collapsing should clamp scrolling')
removeBuff(7)
assert(#settings.buffIndicators == 7 and add.enabled == true)
selectBuff(6)
removeBuff(6)
assert(scroll.child:GetHeight() == 6 * 32, 'removing the selected buff should collapse the editor')

print('PASS: buff_indicators_config_test')
