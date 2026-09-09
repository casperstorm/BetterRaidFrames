local env = assert(loadfile("tests/helpers/threat_env.lua"))()
local Addon = env.Addon
function Addon:RefreshFrameBorders() end
env.settings.threatIndicatorBorder = "CUSTOM"
env.settings.threatIndicatorBorderTexture = "Interface\\AddOns\\MyMedia\\edge.tga"
assert(loadfile("BetterRaidFrames.lua"))("BetterRaidFrames", Addon)
BetterRaidFramesDB = { currentProfile = "Default", profiles = { Default = env.settings }, globalSettings = {} }
function Addon:GetUseRaidStylePartyFrames() return true end
function Addon:BuildDesignerOptions() return function() end end
function Addon:BuildRoleIconOptions() return function() end end
function IsInRaid() return false end
Addon:SwitchProfile("Default")
assert(Addon:GetSetting("threatIndicatorBorder") == nil and Addon:GetSetting("threatIndicatorBorderTexture") == nil,
    "old texture settings are removed when normalizing a profile")
assert(Addon:GetSetting("threatIndicatorBorderOpacity") == 100 and Addon:GetSetting("threatIndicatorBorderInset") == 0,
    "existing profiles keep full opacity and the original border position")
assert(Addon:GetSetting("threatIndicatorBorderStyle") == "SOLID" and Addon:GetSetting("threatIndicatorGlowSize") == 8,
    "existing profiles keep Solid and get a visible initial glow width")
local requested = 0
local Request = Addon.RequestFeatureUpdate
function Addon:RequestFeatureUpdate(feature)
    if feature == "threatIndicator" then requested = requested + 1 end
    return Request(self, feature)
end
assert(loadfile("ThreatIndicatorConfig.lua"))("BetterRaidFrames", Addon)
assert(loadfile("Config.lua"))("BetterRaidFrames", Addon)
Addon:OpenConfig()
local config = BetterRaidFramesConfigFrame
local borders = env.find(function(w) return w.Text and w.Text.text == "Crisp frame borders" end)
assert(borders and not borders:GetChecked(), "General exposes the optional border correction, disabled by default")
borders:SetChecked(true)
borders.scripts.OnClick(borders)
assert(Addon:GetSetting("crispFrameBorders"), "the border checkbox saves its profile setting")
assert(not Addon:IsThreatPreviewOpen(), "opening settings on General must not preview threat")
local before = requested
config.ShowTab("threatIndicator")
assert(Addon:IsThreatPreviewOpen() and requested == before + 1)
local samples = {}
for _, w in ipairs(env.widgets) do if w.BRFThreatIndicator then samples[#samples + 1] = w end end
assert(#samples == 3, "all three threat states have a sample even without a group")
local function CheckSamples(visible)
    for _, sample in ipairs(samples) do
        assert(sample.BRFThreatIndicator.shown == visible and sample.BRFThreatIndicator.animGroup:IsPlaying() == visible)
    end
end
CheckSamples(true)
for index, sample in ipairs(samples) do
    for channel, value in ipairs(Addon.ThreatLevels[index].color) do assert(sample.BRFThreatIndicator.texture.color[channel] == value) end
end
config.ShowTab("names")
assert(not Addon:IsThreatPreviewOpen() and requested == before + 2, "leaving Threat schedules live-frame cleanup")
CheckSamples(false)
config.ShowTab("threatIndicator")
CheckSamples(true)

local function findText(text) return env.find(function(w) return w.text == text end) end
local function click(w) w.scripts.OnClick(w) end
local function choose(label, value)
    local dropdown = env.find(function(w) return w.label and w.label.text == label and w:IsVisible() end)
    for _, option in ipairs(dropdown.menu.items) do if option.value == value then option.callback(value); return end end
    error("missing choice: " .. value)
end
choose("Visual:", "BORDER")
for _, sample in ipairs(samples) do
    local indicator = sample.BRFThreatIndicator
    assert(indicator.BRFShape == "BORDER" and not indicator.texture.shown and indicator.edge.shown)
end
click(findText("Border"))
for _, w in ipairs(env.widgets) do
    assert(w.text ~= "Custom border texture path:")
end
local function slider(text)
    local label = findText(text)
    return env.find(function(w) return w.template == "MinimalSliderWithSteppersTemplate" and w.parent == label.parent end)
end
local opacity, inset, thickness = slider("Opacity (%):"), slider("Inset (px):"), slider("Thickness (px):")
assert(opacity.value == 100 and inset.value == 0 and inset.container:IsVisible())
opacity:SetValue(37); inset:SetValue(4); thickness:SetValue(3)
assert(Addon:GetSetting("threatIndicatorBorderOpacity") == 37 and Addon:GetSetting("threatIndicatorBorderInset") == 4)
for _, sample in ipairs(samples) do
    local edge = sample.BRFThreatIndicator.edge
    assert(edge.backdrop.edgeFile == "Interface\\Buttons\\WHITE8X8" and edge.backdrop.edgeSize == 3)
    assert(edge.borderColor[4] == .37 and edge.points.TOPLEFT[4] == 4, "all three samples refresh immediately")
end
local glowSize = slider("Glow width (px):")
local borderStyle = env.find(function(w) return w.label and w.label.text == "Style:" end)
assert(#borderStyle.menu.items == 2 and not glowSize.container:IsVisible(), "only Solid and Glow are offered")
choose("Style:", "GLOW")
assert(glowSize.container:IsVisible() and not thickness.container:IsVisible())
glowSize:SetValue(12)
for index, sample in ipairs(samples) do
    local edge = sample.BRFThreatIndicator.edge
    assert(edge.backdrop.edgeFile == "Interface\\TutorialFrame\\UI-TutorialFrame-CalloutGlow"
        and edge.backdrop.edgeSize == 12 and edge.borderBlendMode == "ADD")
    assert(edge.borderColor[4] == .37 and edge.points.TOPLEFT[4] == 4)
    for channel, value in ipairs(Addon.ThreatLevels[index].color) do assert(edge.borderColor[channel] == value) end
end
choose("Style:", "SOLID")
assert(thickness.container:IsVisible() and thickness.value == 3 and not glowSize.container:IsVisible(),
    "Solid retains its separate thickness")
choose("Style:", "GLOW")
choose("Visual:", "CIRCLE")
assert(not inset.container:IsVisible(), "inset is a full-frame border control")
assert(not borderStyle.container:IsVisible() and not glowSize.container:IsVisible() and thickness.container:IsVisible())
assert(samples[1].BRFThreatIndicator.border.color[4] == .37)
choose("Visual:", "BORDER")
assert(inset.container:IsVisible() and samples[1].BRFThreatIndicator.edge.points.TOPLEFT[4] == 4)
assert(glowSize.container:IsVisible() and samples[1].BRFThreatIndicator.edge.backdrop.edgeSize == 12)

click(findText("Colours"))
local label = findText("Insecure threat:")
local swatch = env.find(function(w) return w.kind == "Button" and w.parent == label.parent end)
click(swatch)
env.colorPicker.swatchFunc()
assert(Addon:GetSetting("threatIndicatorInsecureColorG") == .2)
assert(samples[2].BRFThreatIndicator.edge.borderColor[2] == .2, "colour edits refresh the sample immediately")
env.colorPicker.cancelFunc()
assert(samples[2].BRFThreatIndicator.edge.borderColor[2] == .6, "cancelling restores the preview and saved colour")
click(swatch)
local oldPicker = env.colorPicker
Addon:CreateProfile("Other")
Addon:SwitchProfile("Other")
Addon:RefreshConfig()
oldPicker.swatchFunc()
assert(Addon:GetSetting("threatIndicatorInsecureColorG") == .6, "an old picker cannot overwrite another profile")
assert(Addon:GetSetting("threatIndicatorBorderOpacity") == 100 and Addon:GetSetting("threatIndicatorBorderInset") == 0)
assert(opacity.value == 100 and inset.value == 0, "controls refresh when switching profiles")
assert(Addon:GetSetting("threatIndicatorBorderStyle") == "SOLID" and glowSize.value == 8,
    "the new profile starts with its own border style and glow width")
assert(BetterRaidFramesDB.profiles.Default.threatIndicatorBorderOpacity == 37
    and BetterRaidFramesDB.profiles.Default.threatIndicatorBorderInset == 4, "border adjustments stay in their profile")
assert(BetterRaidFramesDB.profiles.Default.threatIndicatorBorderStyle == "GLOW"
    and BetterRaidFramesDB.profiles.Default.threatIndicatorGlowSize == 12, "glow settings stay in their profile")
CheckSamples(true)
Addon:SetSetting("threatIndicatorHighColorG", .25)
click(findText("Reset colours"))
assert(Addon:GetSetting("threatIndicatorHighColorG") == 1)
config:Hide()
assert(not Addon:IsThreatPreviewOpen())
CheckSamples(false)
config:Show()
CheckSamples(true)
config.ShowTab("general")
CheckSamples(false)
print("PASS: threat_config_test")
