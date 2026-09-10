local env = assert(loadfile("tests/helpers/threat_env.lua"))()
local Addon = env.Addon
local methods = getmetatable(env.frame()).__index
function methods:SetAtlas(atlas) self.atlas = atlas end
assert(loadfile("RoleIcons.lua"))("BetterRaidFrames", Addon)
assert(loadfile("RoleIconsConfig.lua"))("BetterRaidFrames", Addon)
assert(loadfile("BetterRaidFrames.lua"))("BetterRaidFrames", Addon)
BetterRaidFramesDB = { currentProfile = "Default", profiles = { Default = env.settings }, globalSettings = {} }
function IsInRaid() return false end
function Addon:GetUseRaidStylePartyFrames() return true end
function Addon:RefreshFrameBorders() end
function Addon:BuildDesignerOptions() return function() end end
function Addon:BuildThreatOptions() return function() end end
function Addon:BuildAbsorbOptions() return function() end end
Addon:SwitchProfile("Default")
assert(loadfile("Config.lua"))("BetterRaidFrames", Addon)
Addon:OpenConfig()
local config = BetterRaidFramesConfigFrame
config.ShowTab("roleIcons")
local preset = env.find(function(w) return w.text == "Tiny tank & healer" end)
local content = preset.parent
local function inside(w)
    while w do if w == content then return true end; w = w.parent end
end
local function choose(label, value)
    local dropdown = env.find(function(w) return w.label and w.label.text == label and inside(w) end)
    for _, option in ipairs(dropdown.menu.items) do
        if option.value == value then option.callback(value); return end
    end
    error("missing role option " .. value)
end
local function slider(label)
    local text = env.find(function(w) return w.text == label and inside(w) end)
    return env.find(function(w) return w.template == "MinimalSliderWithSteppersTemplate" and w.parent == text.parent end)
end
local size, x, y = slider("Size (px):"), slider("X offset (px):"), slider("Y offset (px):")
assert(Addon:GetSetting("roleIconStyle") == "BLIZZARD" and not size.container:IsVisible(),
    "Blizzard stays the default and hides custom geometry controls")
preset.scripts.OnClick(preset)
assert(Addon:GetSetting("roleIconStyle") == "TINY" and Addon:GetSetting("showRoleIcons") == "TANK_HEALER")
assert(size.container:IsVisible() and size.value == 10 and x.value == -3 and y.value == -3)
local samples = {}
for _, w in ipairs(env.widgets) do
    if inside(w) and (w.text == "Tank" or w.text == "Healer" or w.text == "Damage") then samples[w.text] = w.parent end
end
assert(samples.Tank.BRFTinyRoleIcon:IsVisible() and samples.Healer.BRFTinyRoleIcon:IsVisible())
assert(not samples.Damage.BRFTinyRoleIcon, "the recommended preset leaves damage units unmarked")
choose("Show role icons:", "ALL")
assert(samples.Damage.BRFTinyRoleIcon:IsVisible(), "previews follow the current role filter")
choose("Show role icons:", "NONE")
for _, sample in pairs(samples) do assert(not sample.BRFTinyRoleIcon.shown) end
preset.scripts.OnClick(preset)
choose("Anchor:", "BOTTOMLEFT")
size:SetValue(7); x:SetValue(4); y:SetValue(5)
local icon = samples.Tank.BRFTinyRoleIcon
assert(icon.width == 7 and icon.point[1] == "BOTTOMLEFT" and icon.point[3] == "BOTTOMLEFT"
    and icon.point[4] == 4 and icon.point[5] == 5, "settings and preview share the same placement")
choose("Style:", "BLIZZARD")
assert(not size.container:IsVisible() and not icon:IsVisible())
preset.scripts.OnClick(preset)
assert(size.value == 7 and x.value == 4 and y.value == 5, "preset preserves the user's chosen size and position")

local allocated = #env.widgets
for _ = 1, 20 do
    choose("Style:", "BLIZZARD"); preset.scripts.OnClick(preset)
    config.ShowTab("names"); config.ShowTab("roleIcons")
end
assert(#env.widgets == allocated, "repeated style/tab changes reuse every preview object")
for _, w in ipairs(env.widgets) do
    if inside(w) then assert(not w.scripts.OnUpdate, "role previews need no timer") end
end
Addon:CreateProfile("Other"); Addon:SwitchProfile("Other"); Addon:RefreshConfig()
assert(Addon:GetSetting("roleIconStyle") == "BLIZZARD" and size.value == 10 and not size.container:IsVisible())
assert(BetterRaidFramesDB.profiles.Default.roleIconSize == 7 and BetterRaidFramesDB.profiles.Default.roleIconPoint == "BOTTOMLEFT")
env.combat = true
preset.scripts.OnClick(preset)
assert(Addon:GetSetting("roleIconStyle") == "BLIZZARD", "the preset respects the settings window's combat lock")
env.combat = false
Addon:SwitchProfile("Default"); Addon:RefreshConfig()
assert(size.container:IsVisible() and size.value == 7 and x.value == 4 and y.value == 5)
config:Hide()
assert(not icon:IsVisible())

print("PASS: role_icons_config_test (preset, preview, placement, profiles, reuse)")
