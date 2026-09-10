local env = assert(loadfile("tests/helpers/threat_env.lua"))()
local Addon = env.Addon
function GetRaidTargetIndex() error("sample markers must not query real targets") end
function UnitIsGroupLeader() error("the sample must not depend on real leadership") end
function UnitAffectingCombat(unit) assert(unit == "player"); return env.combat end
function SetRaidTarget() error("a preview must never mark a real unit") end
local textureUpdates = 0
function SetRaidTargetIconTexture(icon, index) icon.markerIndex = index; textureUpdates = textureUpdates + 1 end
assert(loadfile("RaidMarkers.lua"))("BetterRaidFrames", Addon)
assert(loadfile("PartyLeader.lua"))("BetterRaidFrames", Addon)
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
Addon:SetSetting("customizeNames", true); Addon:SetSetting("nameHideServer", true); Addon:SetSetting("nameSize", 13)
assert(loadfile("Config.lua"))("BetterRaidFrames", Addon)
Addon:OpenConfig()
local config = BetterRaidFramesConfigFrame
local function Open(tab, checkboxText)
    config.ShowTab(tab)
    local checkbox = env.find(function(w) return w.Text and w.Text.text == checkboxText end)
    local content = checkbox.parent
    local row = env.find(function(w) return w.samples and w.parent.parent == content end)
    row.parent:SetWidth(228)
    return content, row, row.samples[1], checkbox
end
local function inside(w, content)
    while w do if w == content then return true end; w = w.parent end
end
local function toggle(checkbox, value) checkbox:SetChecked(value); checkbox.scripts.OnClick(checkbox) end
local function slider(content, text)
    local label = env.find(function(w) return inside(w, content) and w.text == text end)
    return env.find(function(w) return w.parent == label.parent and w.template == "MinimalSliderWithSteppersTemplate" end)
end
local function choose(content, label, value)
    local dropdown = env.find(function(w) return inside(w, content) and w.label and w.label.text == label end)
    for _, option in ipairs(dropdown.menu.items) do if option.value == value then option.callback(value); return end end
    error("missing option " .. value)
end

local markerPage, markerRow, markerFrame, showMarker = Open("raidMarkers", "Show raid markers")
assert(not markerFrame.BRFRaidMarker, "disabled markers do not allocate a sample icon")
toggle(showMarker, true)
local marker = markerFrame.BRFRaidMarker
assert(marker:IsVisible() and marker.markerIndex == 8 and markerFrame.unit == nil)
assert(markerFrame.name:GetText() == "Tidslomme" and markerFrame.name.fontSize == 13)
choose(markerPage, "Marker anchor:", "BOTTOMRIGHT"); choose(markerPage, "Frame anchor:", "TOPLEFT")
slider(markerPage, "Relative X:"):SetValue(-4); slider(markerPage, "Relative Y:"):SetValue(6)
slider(markerPage, "Marker size:"):SetValue(24)
assert(marker.point[1] == "BOTTOMRIGHT" and marker.point[2] == markerFrame and marker.point[3] == "TOPLEFT")
assert(marker.point[4] == -4 and marker.point[5] == 6 and marker.width == 24)
toggle(showMarker, false); assert(not marker:IsShown())
toggle(showMarker, true); assert(markerFrame.BRFRaidMarker == marker and marker:IsShown())

local leaderPage, leaderRow, leaderFrame, showLeader = Open("partyLeader", "Show party leader icon")
assert(not next(markerRow.events) and not leaderFrame.BRFLeaderIndicator)
toggle(showLeader, true)
local leader = leaderFrame.BRFLeaderIndicator
assert(leader:IsVisible() and leader.texture == "Interface\\GroupFrame\\UI-Group-LeaderIcon")
assert(leaderFrame.unit == nil and leaderFrame.name:GetText() == "Tidslomme")
choose(leaderPage, "Icon anchor:", "LEFT"); choose(leaderPage, "Frame anchor:", "RIGHT")
slider(leaderPage, "Relative X:"):SetValue(3); slider(leaderPage, "Relative Y:"):SetValue(-7)
slider(leaderPage, "Size:"):SetValue(18)
assert(leader.point[1] == "LEFT" and leader.point[3] == "RIGHT" and leader.point[4] == 3 and leader.point[5] == -7)
assert(leader.width == 18)
local hideInCombat = env.find(function(w) return inside(w, leaderPage) and w.Text and w.Text.text == "Hide in combat" end)
toggle(hideInCombat, true)
env.combat = true; leaderRow.scripts.OnEvent(leaderRow, "PLAYER_REGEN_DISABLED")
assert(not leader:IsShown(), "the leader preview follows combat visibility")
env.combat = false; leaderRow.scripts.OnEvent(leaderRow, "PLAYER_REGEN_ENABLED")
assert(leader:IsShown() and leaderFrame.BRFLeaderIndicator == leader)

local live = env.frame("player")
live:SetParent(UIParent); live:SetSize(100, 60); live:SetScale(1.25)
CompactPartyFrameMember1 = live
leaderRow.scripts.OnEvent(leaderRow, "EDIT_MODE_LAYOUTS_UPDATED")
assert(leaderFrame:GetWidth() == 100 and leaderFrame:GetHeight() == 60)
assert(leaderFrame:GetEffectiveScale() == live:GetEffectiveScale() and leader:GetEffectiveScale() == live:GetEffectiveScale())
config.ShowTab("raidMarkers")
assert(markerFrame:GetWidth() == 100 and markerFrame:GetEffectiveScale() == live:GetEffectiveScale())
CompactPartyFrameMember1 = nil

Addon:CreateProfile("Other"); Addon:SwitchProfile("Other"); Addon:RefreshConfig()
assert(not showMarker:GetChecked() and not marker:IsShown() and not slider(markerPage, "Marker size:").container.enabled)
config.ShowTab("partyLeader")
assert(not showLeader:GetChecked() and not leader:IsShown() and not slider(leaderPage, "Size:").container.enabled)
Addon:SwitchProfile("Default"); Addon:RefreshConfig()
assert(showLeader:GetChecked() and leader:IsShown() and leader.width == 18)
config.ShowTab("raidMarkers")
assert(showMarker:GetChecked() and marker:IsShown() and marker.width == 24)
local allocated = #env.widgets
for _ = 1, 20 do config.ShowTab("partyLeader"); config.ShowTab("raidMarkers") end
assert(#env.widgets == allocated, "sample frames, icons and names are reused across tab switches")
config.ShowTab("general")
local updates = textureUpdates
Addon:RefreshConfig()
assert(textureUpdates == updates and not next(markerRow.events) and not next(leaderRow.events), "hidden previews stop updating")
for _, w in ipairs(env.widgets) do
    if inside(w, markerPage) or inside(w, leaderPage) then assert(not w.scripts.OnUpdate) end
end

print("PASS: marker_leader_config_test (examples, live editing, sizing, combat, profiles, visibility, reuse)")
