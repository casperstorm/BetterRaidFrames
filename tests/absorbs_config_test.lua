local env = assert(loadfile("tests/helpers/absorb_env.lua"))()
local Addon = env.Addon
local cvarValue, cvarWrites = "1", 0
C_CVar = {
    GetCVarBool = function(name)
        if name == "raidFramesDisplayBuffs" or name == "raidFramesDisplayDebuffs" then return true end
        assert(name == "raidFramesDisplayIncomingHeals"); return cvarValue == "1"
    end,
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
local addonEvents = env.find(function(w) return w.events and w.events.CVAR_UPDATE end)
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
local previewRow = env.find(function(w) return w.samples and inside(w) end)
for index, label in ipairs({ "Absorb fits", "Absorb overflows", "Shield at full health" }) do
    samples[label] = previewRow.samples[index]
end
content:SetSize(676, 634)
local liveFrame = env.frame("player")
liveFrame:SetParent(UIParent); liveFrame:SetSize(100, 56); liveFrame:SetScale(1.25)
CompactPartyFrameMember1 = liveFrame
Addon:RefreshConfig()
for _, sample in pairs(samples) do
    assert(sample:GetWidth() == 100 and sample:GetHeight() == 56)
    assert(sample:GetEffectiveScale() == liveFrame:GetEffectiveScale(), "shield samples match the live dimensions and scale")
end
assert(samples["Absorb fits"].totalAbsorb.width == 24.5 and samples["Absorb fits"].totalAbsorb.height == 54)
assert(samples["Absorb fits"].totalAbsorb.point[4] == 39.2, "absorb artwork begins at the sample health fill's edge")
liveFrame:SetSize(128, 72)
previewRow.scripts.OnEvent(previewRow, "EDIT_MODE_LAYOUTS_UPDATED")
assert(samples["Absorb fits"].totalAbsorb.width == 31.5 and samples["Absorb fits"].totalAbsorb.height == 70,
    "shield texture geometry follows a layout resize")
CompactPartyFrameMember1 = nil
assert(normal:GetChecked() and not overflow:GetChecked(), "existing profiles retain native shields without overshields")
assert(prediction:GetChecked() and cvarWrites == 0, "existing profiles inherit the actual Blizzard CVar")
for _, sample in pairs(samples) do assert(not sample.BRFOvershield) end
toggle(overflow, true)
assert(Addon:GetSetting("showOvershields"))
assert(env.overflowWidth(samples["Absorb fits"]) == 0)
assert(math.abs(env.overflowWidth(samples["Absorb overflows"]) - .3) < 1e-7)
assert(math.abs(env.overflowWidth(samples["Shield at full health"]) - .45) < 1e-7)
toggle(prediction, false)
assert(cvarValue == "0" and cvarWrites == 1 and not prediction:GetChecked())
assert(Addon:GetSetting("blizzardIncomingHeals") == false, "the choice is saved in the profile")
for _, sample in pairs(samples) do
    assert(not sample.totalAbsorb:IsVisible() and not sample.totalAbsorbOverlay:IsVisible())
    assert(sample.BRFOvershield:IsVisible(), "the CVar hides native previews without hiding BRF overshields")
end
env.combat = true
toggle(prediction, true)
assert(cvarValue == "0" and cvarWrites == 1 and not prediction:GetChecked(), "CVar changes respect the combat lock")
env.combat = false
cvarValue = "1"
addonEvents.scripts.OnEvent(addonEvents, "CVAR_UPDATE", "RAIDFRAMESDISPLAYINCOMINGHEALS", "1")
assert(prediction:GetChecked() and samples["Absorb fits"].totalAbsorb:IsVisible(), "external CVar changes refresh previews")
assert(cvarWrites == 1 and Addon:GetSetting("blizzardIncomingHeals"), "external CVar changes are kept by the profile")
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
config.ShowTab("names"); config.ShowTab("absorbs")
local allocated = #env.widgets
for _ = 1, 20 do
    toggle(overflow, false); toggle(overflow, true)
    config.ShowTab("names"); config.ShowTab("absorbs")
end
assert(#env.widgets == allocated, "tab and setting changes reuse preview objects")
config.ShowTab("names")
assert(not next(previewRow.events), "leaving Absorbs unregisters the sizing events")
local updates = previewUpdates
cvarValue = "0"
addonEvents.scripts.OnEvent(addonEvents, "CVAR_UPDATE", "raidFramesDisplayIncomingHeals", "0")
Addon:RefreshConfig()
assert(previewUpdates == updates, "hidden previews perform no shield updates")
config.ShowTab("absorbs")
Addon:CreateProfile("Other"); Addon:SwitchProfile("Other"); Addon:RefreshConfig()
assert(normal:GetChecked() and not overflow:GetChecked() and opacity[1].value == 100 and opacity[2].value == 80)
assert(prediction:GetChecked() and cvarValue == "1" and cvarWrites == 2, "new profiles apply their own Blizzard setting")
for _, sample in pairs(samples) do
    assert(sample.totalAbsorb.alpha == 1 and not sample.BRFOvershield:IsVisible(), "profile changes restore native opacity")
end
Addon:SwitchProfile("Default"); Addon:RefreshConfig()
assert(not normal:GetChecked() and overflow:GetChecked() and opacity[1].value == 45 and opacity[2].value == 30)
assert(Addon:GetSetting("overshieldTexture") == "EMPOWER")
assert(not prediction:GetChecked() and cvarValue == "0" and cvarWrites == 3, "switching back restores that profile's Blizzard setting")
config:Hide()
for _, sample in pairs(samples) do assert(not sample.BRFOvershield:IsVisible()) end
for _, w in ipairs(env.widgets) do
    if inside(w) then assert(not w.scripts.OnUpdate, "shield previews need no timers") end
end
assert(env.queries == 0, "settings previews never query game health or absorb values")

print("PASS: absorbs_config_test (controls, shield previews, profiles, textures, reuse)")
