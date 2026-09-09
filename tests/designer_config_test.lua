local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
local cvarValue, cvarWrites = "1", 0
C_CVar = {
    GetCVarBool = function(name)
        assert(name == "raidFramesDisplayBuffs")
        return cvarValue == "1"
    end,
    SetCVar = function(name, value)
        assert(name == "raidFramesDisplayBuffs")
        cvarValue, cvarWrites = value, cvarWrites + 1
    end,
}
assert(loadfile("IndicatorsConfig.lua"))("BetterRaidFrames", Addon)
local refresh = Addon:BuildDesignerOptions(env.frame(), -38)
local function findText(text) return env.find(function(w) return w.text == text end) end
local function click(w) w.scripts.OnClick(w) end
local blizzardBuffs = env.find(function(w) return w.Text and w.Text.text == "Show Blizzard buff icons" end)
assert(blizzardBuffs:GetChecked() and cvarWrites == 0, "opening the designer must respect the existing CVar")
blizzardBuffs:SetChecked(false); click(blizzardBuffs)
assert(cvarValue == "0")
blizzardBuffs:SetChecked(true); click(blizzardBuffs)
assert(cvarValue == "1")
cvarValue = "0"
blizzardBuffs.scripts.OnEvent(blizzardBuffs, "CVAR_UPDATE", "raidFramesDisplayBuffs", "0")
assert(not blizzardBuffs:GetChecked() and cvarWrites == 2, "external CVar updates must refresh without writing back")
local function dropdown(label) return env.find(function(w) return w.label and w.label.text == label end) end
local function choose(label, value)
    local d = dropdown(label)
    for _, option in ipairs(d.menu.items) do if option.value == value then option.callback(value); return end end
    error("choice not found: " .. label .. "/" .. value)
end
local input = env.find(function(w) return w.kind == "EditBox" and w.height == 24 end)
input:SetText("Echo"); click(findText("Add"))
local a = Addon:GetIndicatorSet().items[1].id
assert(#Addon:GetIndicatorSet().items == 1)
choose("Display", "ICON")
choose("Text", "STACKS")
assert(Addon:FindDesignerIndicator("default", a).type == "ICON")
local glow = env.find(function(w) return w.Text and w.Text.text == "Glow" end)
local pulse = env.find(function(w) return w.Text and w.Text.text == "Pulse glow" end)
assert(not glow:GetChecked())
assert(not pulse:GetChecked() and not pulse.enabled, "pulsing requires glow")
glow:SetChecked(true); click(glow)
assert(Addon:FindDesignerIndicator("default", a).glow)
assert(pulse.enabled)
pulse:SetChecked(true); click(pulse)
assert(Addon:FindDesignerIndicator("default", a).glowPulse)
local size = env.find(function(w) return w.template == "MinimalSliderWithSteppersTemplate" and w.max == 50 end)
size:SetValue(26)
assert(Addon:FindDesignerIndicator("default", a).size == 26)
local oldAnchorMenu = dropdown("Anchor").menu.items[1]
choose("Editing set", "1468")
assert(glow:GetChecked(), "specializations inherit the default glow setting")
assert(pulse:GetChecked(), "specializations inherit the pulse setting")
pulse:SetChecked(false); click(pulse)
assert(not Addon:FindDesignerIndicator("1468", a).glowPulse and Addon:FindDesignerIndicator("default", a).glowPulse,
    "changing a specialization's pulse must preserve Default")
glow:SetChecked(false); click(glow)
assert(not pulse.enabled)
assert(not Addon:FindDesignerIndicator("1468", a).glow and Addon:FindDesignerIndicator("default", a).glow,
    "changing a specialization's glow must preserve Default")
oldAnchorMenu.callback(oldAnchorMenu.value)
assert(Addon:GetIndicatorSet("1468").items[1].anchor == "BOTTOMRIGHT", "stale dropdowns cannot write to another set")
choose("Grow", "UP")
assert(Addon:GetIndicatorSet("1468").groups.BOTTOMRIGHT.grow == "UP")
assert(Addon:GetIndicatorSet("default").groups.BOTTOMRIGHT.grow == "LEFT")
click(findText("Placement"))
local offsetX = env.find(function(w) return w.min == -250 and w.point[2] == 4 end)
local offsetY = env.find(function(w) return w.min == -250 and w.point[2] == 328 end)
local offsetZ = env.find(function(w) return w.min == -100 and w.max == 500 end)
assert(offsetZ.value == 0)
offsetZ:SetValue(240)
assert(Addon:GetIndicatorSet("1468").groups.BOTTOMRIGHT.offsetZ == 240)
local aboveBlizzard = findText("Above Blizzard icons")
env.combat = true
click(aboveBlizzard)
assert(Addon:GetIndicatorSet("1468").groups.BOTTOMRIGHT.offsetZ == 240, "the preset respects combat restrictions")
env.combat = false
click(aboveBlizzard)
assert(offsetZ.value == 200 and Addon:GetIndicatorSet("1468").groups.BOTTOMRIGHT.offsetZ == 200)
assert(Addon:GetIndicatorSet("default").groups.BOTTOMRIGHT.offsetZ == 0, "group Z edits must preserve other sets")
offsetX:SetValue(-12); offsetY:SetValue(8)
assert(Addon:GetIndicatorSet("1468").groups.BOTTOMRIGHT.offsetX == -12)
assert(Addon:GetIndicatorSet("1468").groups.BOTTOMRIGHT.offsetY == 8)
assert(Addon:GetIndicatorSet("default").groups.BOTTOMRIGHT.offsetX == 0, "group sliders must edit the selected spec only")
input:SetText("366155"); click(findText("Add"))
assert(#Addon:GetIndicatorSet("1468").items == 2)
assert(offsetX.value == -12 and offsetY.value == 8, "indicators sharing an anchor must share offset controls")
assert(offsetZ.value == 200, "indicators sharing an anchor must share their layer control")
local b = Addon:GetIndicatorSet("1468").items[2].id
choose("Anchor", "TOPLEFT")
assert(Addon:FindDesignerIndicator("1468", b).anchor == "TOPLEFT")
assert(offsetX.value == 0 and offsetY.value == 0, "moving to another anchor must load that group's offsets")
assert(offsetZ.value == 0, "joining another anchor loads its Z offset")
click(findText("Appearance"))
choose("Display", "SQUARE")
assert(not glow:GetChecked(), "a newly added indicator starts without glow")
assert(not pulse:GetChecked() and not pulse.enabled, "new indicators start without pulsing")
glow:SetChecked(true); click(glow)
pulse:SetChecked(true); click(pulse)
glow:SetChecked(false); click(glow)
assert(not pulse.enabled and pulse:GetChecked(), "turning glow off preserves its pulse preference")
glow:SetChecked(true); click(glow)
assert(pulse.enabled and pulse:GetChecked())
assert(Addon:FindDesignerIndicator("1468", b).glow and not Addon:FindDesignerIndicator("1468", a).glow,
    "square glow is independent of other indicators")
local swatch = env.find(function(w) return w.kind == "Button" and w.width == 22 end)
click(swatch)
local original = Addon:FindDesignerIndicator("1468", b).color
env.colorPicker.swatchFunc()
assert(Addon:FindDesignerIndicator("1468", b).color.a == .4)
env.colorPicker.cancelFunc()
assert(Addon:FindDesignerIndicator("1468", b).color.r == original.r)
click(swatch)
local staleColor = env.colorPicker
choose("Editing set", "default")
staleColor.swatchFunc()
assert(Addon:GetIndicatorSet("default").items[1].color.r == .4, "old pickers cannot change another set")
env.combat = true
pulse:SetChecked(false); click(pulse)
assert(Addon:FindDesignerIndicator("default", a).glowPulse, "combat-blocked clicks cannot change pulsing")
blizzardBuffs:SetChecked(true); click(blizzardBuffs)
assert(not blizzardBuffs:GetChecked() and cvarWrites == 2, "combat-blocked clicks must restore the actual CVar state")
input:SetText("774"); click(findText("Add")); size:SetValue(40)
assert(#Addon:GetIndicatorSet("default").items == 1 and Addon:GetIndicatorSet("default").items[1].size == 26)
env.combat = false
env.profile = "Another"
local oldSettings = env.settings
env.settings = { indicators = Addon:NormalizeIndicators(nil) }
refresh()
assert(not blizzardBuffs:GetChecked() and cvarWrites == 2, "profile changes must not override the shared CVar")
assert(#Addon:GetIndicatorSet().items == 0)
staleColor.cancelFunc()
assert(#Addon:GetIndicatorSet().items == 0)
input:SetText("774"); click(findText("Add"))
assert(#Addon:GetIndicatorSet().items == 1 and #oldSettings.indicators.sets.default.items == 1)

local payload = { version = 1, set = Addon:NormalizeIndicatorSet({ items = { { id = 1, spellID = 17, type = "ICON" } } }) }
C_EncodingUtil = { DecodeBase64 = function(s) return s end, DecompressString = function(s) return s end, DeserializeJSON = function() return payload end }
click(findText("Import"))
local shareInput = env.find(function(w) return w.kind == "EditBox" and w.height == 26 end)
shareInput:SetText("BRFI1:json")
click(findText("Review Import"))
assert(Addon:GetIndicatorSet().items[1].spellID == 774, "review must not replace settings")
click(findText("Replace Set"))
assert(Addon:GetIndicatorSet().items[1].spellID == 17)
print("designer config tests passed")
