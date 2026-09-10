local env = assert(loadfile("tests/helpers/absorb_env.lua"))()
local Addon = env.Addon
local cvarValue, cvarWrites = "1", 0
C_CVar = {
    GetCVarBool = function(name) assert(name == "raidFramesDisplayIncomingHeals"); return cvarValue == "1" end,
    SetCVar = function(name, value)
        assert(name == "raidFramesDisplayIncomingHeals")
        cvarValue, cvarWrites = value, cvarWrites + 1
    end,
}
local previewUpdates = 0
local UpdateAbsorbPreview = Addon.UpdateAbsorbPreview
function Addon:UpdateAbsorbPreview(...)
    previewUpdates = previewUpdates + 1
    return UpdateAbsorbPreview(self, ...)
end
assert(loadfile("AbsorbsConfig.lua"))("BetterRaidFrames", Addon)
assert(loadfile("BetterRaidFrames.lua"))("BetterRaidFrames", Addon)
BetterRaidFramesDB = { currentProfile = "Default", profiles = { Default = env.settings }, globalSettings = {} }
function IsInRaid() return false end
function Addon:GetUseRaidStylePartyFrames() return true end
function Addon:RefreshFrameBorders() end
function Addon:RefreshSoloFrame() end
function Addon:BuildDesignerOptions() return function() end end
function Addon:BuildThreatOptions() return function() end end
function Addon:BuildRoleIconOptions() return function() end end
Addon:SwitchProfile("Default")
assert(loadfile("Config.lua"))("BetterRaidFrames", Addon)
Addon:OpenConfig()
local config = BetterRaidFramesConfigFrame
config.ShowTab("absorbs")
local normal = env.find(function(w) return w.Text and w.Text.text == "Show normal absorb shields" end)
local prediction = env.find(function(w) return w.Text and w.Text.text == "Show Blizzard absorbs and incoming heals" end)
local overflow = env.find(function(w) return w.Text and w.Text.text == "Show overshields" end)
local content = normal.parent
local function inside(w)
    while w do if w == content then return true end; w = w.parent end
end
local function toggle(checkbox, checked)
    checkbox:SetChecked(checked)
    checkbox.scripts.OnClick(checkbox)
end
local opacity = {}
for _, w in ipairs(env.widgets) do
    if inside(w) and w.template == "MinimalSliderWithSteppersTemplate" then opacity[#opacity + 1] = w end
end
assert(#opacity == 2 and opacity[1].value == 100 and opacity[2].value == 80)
local samples = {}
for _, w in ipairs(env.widgets) do
    if inside(w) and (w.text == "Absorb fits" or w.text == "Absorb overflows" or w.text == "Shield at full health") then
        samples[w.text] = w.parent
    end
end
assert(normal:GetChecked() and not overflow:GetChecked(), "existing profiles retain native shields without overshields")
assert(prediction:GetChecked() and cvarWrites == 0, "opening settings respects the actual Blizzard CVar")
for _, sample in pairs(samples) do assert(not sample.BRFOvershield) end
toggle(overflow, true)
assert(Addon:GetSetting("showOvershields"))
assert(env.overflowWidth(samples["Absorb fits"]) == 0)
assert(math.abs(env.overflowWidth(samples["Absorb overflows"]) - .3) < 1e-7)
assert(math.abs(env.overflowWidth(samples["Shield at full health"]) - .45) < 1e-7)
toggle(prediction, false)
assert(cvarValue == "0" and cvarWrites == 1 and not prediction:GetChecked())
for _, sample in pairs(samples) do
    assert(not sample.totalAbsorb:IsVisible() and not sample.totalAbsorbOverlay:IsVisible())
    assert(sample.BRFOvershield:IsVisible(), "the CVar hides native previews without hiding BRF overshields")
end
env.combat = true
toggle(prediction, true)
assert(cvarValue == "0" and cvarWrites == 1 and not prediction:GetChecked(), "CVar changes respect the combat lock")
env.combat = false
cvarValue = "1"
prediction.scripts.OnEvent(prediction, "CVAR_UPDATE", "RAIDFRAMESDISPLAYINCOMINGHEALS", "1")
assert(prediction:GetChecked() and samples["Absorb fits"].totalAbsorb:IsVisible(), "external CVar changes refresh previews")
assert(cvarWrites == 1, "external CVar changes are never overwritten")
opacity[1]:SetValue(45); opacity[2]:SetValue(30)
for _, sample in pairs(samples) do
    assert(sample.totalAbsorb.alpha == .45 and sample.BRFOvershield.alpha == .3)
end
toggle(normal, false)
for _, sample in pairs(samples) do
    assert(sample.totalAbsorb.alpha == 0 and sample.BRFOvershield:IsVisible(), "overshields have independent visibility")
end
local dropdown = env.find(function(w) return inside(w) and w.label and w.label.text == "Texture:" end)
assert(#dropdown.menu.items == 9, "offer the reference addon's nine textures")
for _, option in ipairs(dropdown.menu.items) do
    option.callback(option.value)
    assert(Addon:GetSetting("overshieldTexture") == option.value)
end
local allocated = #env.widgets
for _ = 1, 20 do
    toggle(overflow, false); toggle(overflow, true)
    config.ShowTab("names"); config.ShowTab("absorbs")
end
assert(#env.widgets == allocated, "tab and setting changes reuse preview objects")
config.ShowTab("names")
local updates = previewUpdates
cvarValue = "0"
prediction.scripts.OnEvent(prediction, "CVAR_UPDATE", "raidFramesDisplayIncomingHeals", "0")
Addon:RefreshConfig()
assert(previewUpdates == updates, "hidden previews perform no shield updates")
config.ShowTab("absorbs")
Addon:CreateProfile("Other"); Addon:SwitchProfile("Other"); Addon:RefreshConfig()
assert(normal:GetChecked() and not overflow:GetChecked() and opacity[1].value == 100 and opacity[2].value == 80)
for _, sample in pairs(samples) do
    assert(sample.totalAbsorb.alpha == 1 and not sample.BRFOvershield:IsVisible(), "profile changes restore native opacity")
end
Addon:SwitchProfile("Default"); Addon:RefreshConfig()
assert(not normal:GetChecked() and overflow:GetChecked() and opacity[1].value == 45 and opacity[2].value == 30)
assert(Addon:GetSetting("overshieldTexture") == "EMPOWER")
assert(not prediction:GetChecked() and cvarWrites == 1, "profile changes preserve the shared Blizzard setting")
config:Hide()
for _, sample in pairs(samples) do assert(not sample.BRFOvershield:IsVisible()) end
for _, w in ipairs(env.widgets) do
    if inside(w) then assert(not w.scripts.OnUpdate, "shield previews need no timers") end
end
assert(env.queries == 0, "settings previews never query game health or absorb values")

print("PASS: absorbs_config_test (controls, shield previews, profiles, textures, reuse)")
