local env = assert(loadfile("tests/helpers/threat_env.lua"))()
local Addon = env.Addon
assert(loadfile("BetterRaidFrames.lua"))("BetterRaidFrames", Addon)
BetterRaidFramesDB = { currentProfile = "Default", profiles = { Default = env.settings }, globalSettings = {} }
function Addon:RefreshFrameBorders() end
function Addon:RefreshSoloFrame() end
function Addon:GetUseRaidStylePartyFrames() return true end
function Addon:BuildDesignerOptions() return function() end end
function Addon:BuildRoleIconOptions() return function() end end
function Addon:BuildAbsorbOptions() return function() end end
function Addon:BuildThreatOptions() return function() end end
Addon:SwitchProfile("Default")
assert(loadfile("Config.lua"))("BetterRaidFrames", Addon)
Addon:OpenConfig()
local config = BetterRaidFramesConfigFrame
config.ShowTab("names")
local customize = env.find(function(w) return w.Text and w.Text.text == "Customize names" end)
local content = customize.parent
local function inside(w)
    while w do if w == content then return true end; w = w.parent end
end
local row = env.find(function(w) return w.samples and inside(w) end)
local sample = row.samples[1]
assert(#row.samples == 1 and sample.name:GetText() == "Tidslomme-Realm")
assert(not customize:GetChecked() and sample.name.fontSize == nil, "the preview initially uses its default font")
row.parent:SetWidth(228)
local live = env.frame("player")
live:SetParent(UIParent); live:SetSize(100, 56); live:SetScale(1.25)
CompactPartyFrameMember1 = live
row.scripts.OnEvent(row, "EDIT_MODE_LAYOUTS_UPDATED")
assert(sample:GetWidth() == 100 and sample:GetHeight() == 56 and sample:GetEffectiveScale() == live:GetEffectiveScale())

local function toggle(text, value)
    local checkbox = env.find(function(w) return inside(w) and w.Text and w.Text.text == text end)
    checkbox:SetChecked(value); checkbox.scripts.OnClick(checkbox)
end
local function slider(text)
    local label = env.find(function(w) return inside(w) and w.text == text end)
    return env.find(function(w) return w.parent == label.parent and w.template == "MinimalSliderWithSteppersTemplate" end)
end
local function choose(text, value)
    local dropdown = env.find(function(w) return inside(w) and w.label and w.label.text == text end)
    for _, option in ipairs(dropdown.menu.items) do if option.value == value then option.callback(value); return end end
    error("missing option " .. value)
end
toggle("Customize names", true)
choose("Position:", "BOTTOMRIGHT")
slider("X offset (px):"):SetValue(-5); slider("Y offset (px):"):SetValue(4)
slider("Font size (px):"):SetValue(16)
assert(sample.name.point[1] == "BOTTOMRIGHT" and sample.name.point[4] == -5 and sample.name.point[5] == 4)
assert(sample.name.fontSize == 16, "sliders refresh the sample immediately")
toggle("Hide server name", true)
assert(sample.name:GetText() == "Tidslomme")
toggle("Truncate long names", true); slider("Max length:"):SetValue(4)
assert(sample.name:GetText() == "Tid…")
choose("Outline:", "OUTLINE")
assert(sample.name.fontFlags == "OUTLINE")
env.classColor = { r = .1, g = .5, b = .7 }
toggle("Use class color", true)
assert(sample.name.textColor[2] == .5)
toggle("Text shadow", true); slider("Shadow offset:"):SetValue(3)
assert(sample.name.shadowOffset[1] == 3 and sample.name.shadowOffset[2] == -3)
local colorLabel = env.find(function(w) return inside(w) and w.text == "Shadow color:" end)
local swatch = env.find(function(w) return w.parent == colorLabel.parent and w.kind == "Button" end)
swatch.scripts.OnClick(swatch); env.colorPicker.swatchFunc()
assert(sample.name.shadowColor[2] == .2)
env.colorPicker.cancelFunc()
assert(sample.name.shadowColor[2] == 0, "cancelling the colour picker restores the preview")

CompactPartyFrameMember1 = nil
Addon:CreateProfile("Other"); Addon:SwitchProfile("Other"); Addon:RefreshConfig()
assert(not customize:GetChecked() and sample.name:GetText() == "Tidslomme-Realm" and sample.name.fontSize == 11)
Addon:SwitchProfile("Default"); Addon:RefreshConfig()
assert(customize:GetChecked() and sample.name:GetText() == "Tid…" and sample.name.fontSize == 16,
    "profile preview: " .. tostring(customize:GetChecked()) .. ", " .. sample.name:GetText() .. ", " .. tostring(sample.name.fontSize))
local allocated = #env.widgets
for _ = 1, 20 do config.ShowTab("general"); config.ShowTab("names") end
assert(#env.widgets == allocated, "reopening Names reuses its frame and text")
config.ShowTab("general")
env.playerName = "Changed"
Addon:RefreshConfig()
assert(not next(row.events) and sample.name:GetText() == "Tid…", "hidden Name previews stop sizing and text updates")
config.ShowTab("names")
assert(sample.name:GetText() == "Cha…" and row.events.GROUP_ROSTER_UPDATE)
for _, w in ipairs(env.widgets) do if inside(w) then assert(not w.scripts.OnUpdate) end end

print("PASS: name_config_test (live editing, sizing, colour cancellation, profiles, visibility, reuse)")
