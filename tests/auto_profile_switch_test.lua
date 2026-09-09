local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertEqual failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual), 2)
    end
end

SlashCmdList = {}

Settings = {
    RegisterCanvasLayoutCategory = function(panel)
        return panel
    end,
    RegisterAddOnCategory = function() end,
}

local framePrototype = {}
local eventHandler
local onUpdateHandler
local framePasses = 0
local featureUpdates = {
    frameBorders = 0,
    raidMarker = 0,
    roleIcon = 0,
    threatIndicator = 0,
    partyLeader = 0,
    name = 0,
    indicators = 0,
}

function framePrototype:RegisterEvent() end
function framePrototype:SetScript(scriptName, callback)
    if scriptName == "OnEvent" then
        eventHandler = callback
    elseif scriptName == "OnUpdate" then
        onUpdateHandler = callback
    end
end
function framePrototype:CreateFontString()
    return {
        SetPoint = function() end,
        SetText = function() end,
    }
end
function framePrototype:SetSize() end
function framePrototype:SetPoint() end
function framePrototype:SetText() end
function framePrototype:Hide() self.shown = false end
function framePrototype:Show() self.shown = true end

function CreateFrame()
    return setmetatable({}, { __index = framePrototype })
end

local Addon = {
    RefreshFrameBorders = function() featureUpdates.frameBorders = featureUpdates.frameBorders + 1 end,
    HookFrameBorders = function() end,
    ForEachFrame = function(_, callback)
        framePasses = framePasses + 1
        callback({})
    end,
    UpdateRaidMarker = function() featureUpdates.raidMarker = featureUpdates.raidMarker + 1 end,
    UpdateRoleIcon = function() featureUpdates.roleIcon = featureUpdates.roleIcon + 1 end,
    UpdateThreatIndicator = function() featureUpdates.threatIndicator = featureUpdates.threatIndicator + 1 end,
    UpdatePartyLeader = function() featureUpdates.partyLeader = featureUpdates.partyLeader + 1 end,
    UpdateName = function() featureUpdates.name = featureUpdates.name + 1 end,
    UpdateDesignerIndicators = function() featureUpdates.indicators = featureUpdates.indicators + 1 end,
    HookRaidMarkers = function() end,
    HookRoleIcons = function() end,
    HookThreatIndicator = function() end,
    HookPartyLeader = function() end,
    HookName = function() end,
    HookDesignerIndicators = function() end,
    HookEditMode = function() end,
}

assert(loadfile("Indicators.lua"))("BetterRaidFrames", Addon)
assert(loadfile("BetterRaidFrames.lua"))("BetterRaidFrames", Addon)

BetterRaidFramesDB = {
    currentProfile = "Default",
    profiles = {
        Default = {
            buffIndicators = {
                { spellID = 364343, r = 1, g = 0.8, b = 0.4, obsolete = true },
                { spellID = 364343 },
                { spellID = "invalid" },
            },
            indicators = { sets = {
                default = { items = {
                    { id = 1, spellID = 364343, anchor = "TOP", color = { r = 1, g = 0.8, b = 0.4, a = 1 }, obsolete = true },
                    { spellID = "invalid" },
                }, groups = { TOP = { grow = "LEFT", spacing = 4 } } },
                ["1468"] = { items = { { id = 1, spellID = 366155, type = "ICON", size = 26 } } },
            } },
            raidMarkerX = 1,
            raidMarkerY = 2,
            threatIndicatorX = 7,
            threatIndicatorY = -3,
            partyLeaderX = 4,
            partyLeaderY = -5,
            nameX = 6,
            nameY = -7,
            raidFrameGrowth = "HORIZONTAL",
            removedSetting = true,
        },
        ["Legacy Buffs"] = {
            buffIndicatorHeight = 4,
            buffIndicatorDirection = "REMAINING",
            buffIndicatorPosition = "RIGHT",
            buffIndicatorFrameLevel = 112,
            buffIndicators = {
                { spellID = 364343 },
                { spellID = 774, thickness = 8, direction = "ELAPSED", position = "LEFT", frameLevel = 0 },
            },
        },
        Party = {},
        Raid = {},
    },
    globalSettings = {
        removedSetting = true,
    },
}

eventHandler(nil, "ADDON_LOADED", "BetterRaidFrames")

assertEqual(Addon:GetSetting("buffIndicators"), nil, "removed duration indicators should be discarded on load")
assertEqual(Addon:SetSetting("buffIndicators", {}), false, "removed duration settings should be rejected")
local savedIndicators = Addon:GetIndicatorSet("default")
assertEqual(#savedIndicators.items, 1, "new designer settings should be normalized and preserved")
assertEqual(savedIndicators.items[1].obsolete, nil)
assertEqual(savedIndicators.items[1].mineOnly, true)
assertEqual(savedIndicators.items[1].anchor, "TOP")
assertEqual(savedIndicators.groups.TOP.spacing, 4)
assertEqual(Addon:GetIndicatorSet("1468").items[1].spellID, 366155, "specialization sets should survive cleanup")
local legacy = BetterRaidFramesDB.profiles["Legacy Buffs"]
assertEqual(legacy.buffIndicators, nil, "inactive profiles should also discard removed duration indicators")
assertEqual(#legacy.indicators.sets.default.items, 0, "old duration segments should not create new indicators")
assertEqual(legacy.buffIndicatorHeight, nil, "obsolete shared settings should be removed")
assertEqual(legacy.buffIndicatorDirection, nil)
assertEqual(legacy.buffIndicatorPosition, nil)
assertEqual(legacy.buffIndicatorFrameLevel, nil)

assertEqual(BetterRaidFramesDB.profiles.Default.threatIndicatorOffsetX, 7,
    "legacy threat X should migrate to a relative offset")
assertEqual(BetterRaidFramesDB.profiles.Default.threatIndicatorOffsetY, -3,
    "legacy threat Y should migrate to a relative offset")
assertEqual(BetterRaidFramesDB.profiles.Default.threatIndicatorPoint, "CENTER",
    "legacy threat position should retain its center anchor")
assertEqual(BetterRaidFramesDB.profiles.Default.raidMarkerOffsetX, 1,
    "legacy raid marker X should migrate to a relative offset")
assertEqual(BetterRaidFramesDB.profiles.Default.raidMarkerOffsetY, 2,
    "legacy raid marker Y should migrate to a relative offset")
assertEqual(BetterRaidFramesDB.profiles.Default.raidMarkerPoint, "TOP",
    "legacy raid marker position should retain its top anchor")
assertEqual(BetterRaidFramesDB.profiles.Default.partyLeaderOffsetX, 4,
    "legacy party leader X should migrate to a relative offset")
assertEqual(BetterRaidFramesDB.profiles.Default.partyLeaderOffsetY, -5,
    "legacy party leader Y should migrate to a relative offset")
assertEqual(BetterRaidFramesDB.profiles.Default.partyLeaderPoint, "TOPLEFT",
    "legacy party leader position should retain its top-left anchor")
assertEqual(BetterRaidFramesDB.profiles.Default.nameOffsetX, 6,
    "legacy name X should migrate to a relative offset")
assertEqual(BetterRaidFramesDB.profiles.Default.nameOffsetY, -7,
    "legacy name Y should migrate to a relative offset")
assertEqual(BetterRaidFramesDB.profiles.Default.nameAnchor, "CENTER",
    "existing name offsets must retain their center anchor")
assertEqual(BetterRaidFramesDB.profiles.Default.raidFrameGrowth, nil,
    "removed raid growth settings should be pruned")
assertEqual(BetterRaidFramesDB.profiles.Default.removedSetting, nil,
    "removed profile settings should be pruned")
assertEqual(BetterRaidFramesDB.globalSettings.removedSetting, nil,
    "removed global settings should be pruned")
assertEqual(Addon:CreateProfile("   "), false, "blank profile names should be rejected")
assertEqual(Addon:SetSetting("removedSetting", true), false, "unknown settings should be rejected")

local passesBeforeSettings = framePasses
assertEqual(Addon:SetSetting("raidMarkerSize", 19), true, "known settings should update")
assertEqual(Addon:SetSetting("raidMarkerOffsetX", 8), true, "related settings should update")
assertEqual(framePasses, passesBeforeSettings, "setting changes should wait for the next rendered frame")
onUpdateHandler()
assertEqual(framePasses, passesBeforeSettings + 1, "related setting changes should coalesce into one frame pass")
assertEqual(featureUpdates.raidMarker, 1, "a raid marker setting should only update raid markers")
assertEqual(featureUpdates.roleIcon, 0, "a raid marker setting should not update role icons")
assertEqual(featureUpdates.threatIndicator, 0, "a raid marker setting should not update threat indicators")
assertEqual(featureUpdates.partyLeader, 0, "a raid marker setting should not update party leader indicators")
assertEqual(featureUpdates.name, 0, "a raid marker setting should not update names")

local passesBeforeName = framePasses
assertEqual(Addon:SetSetting("customizeNames", true), true, "name customization should be configurable")
assertEqual(Addon:SetSetting("nameSize", 14), true, "name styling should be configurable")
assertEqual(Addon:SetSetting("nameAnchor", "BOTTOMLEFT"), true, "name anchors should be configurable")
onUpdateHandler()
assertEqual(framePasses, passesBeforeName + 1, "name settings should coalesce into one frame pass")
assertEqual(featureUpdates.name, 1, "name settings should only update names")

assertEqual(Addon:GetSetting("crispFrameBorders"), false, "pixel alignment should be opt-in")
local passesBeforeBorders = framePasses
local namesBeforeBorders = featureUpdates.name
local bordersBefore = featureUpdates.frameBorders
Addon:SetSetting("crispFrameBorders", true)
Addon:RequestFeatureUpdate("frameBorders")
assertEqual(featureUpdates.frameBorders, bordersBefore, "border edits wait for the coalesced update")
onUpdateHandler()
assertEqual(featureUpdates.frameBorders, bordersBefore + 1, "border requests coalesce into one refresh")
assertEqual(framePasses, passesBeforeBorders, "border refresh owns its scan without an unrelated frame pass")
assertEqual(featureUpdates.name, namesBeforeBorders, "border settings do not refresh other artwork")

assertEqual(Addon:GetSetting("roleIconStyle"), "BLIZZARD", "existing role icons retain their native style")
assertEqual(Addon:GetSetting("roleIconSize"), 10)
local rolesBefore = featureUpdates.roleIcon
local passesBeforeRoles = framePasses
Addon:SetSetting("roleIconStyle", "TINY")
Addon:SetSetting("showRoleIcons", "TANK_HEALER")
Addon:SetSetting("roleIconSize", 8)
Addon:SetSetting("roleIconPoint", "LEFT")
Addon:SetSetting("roleIconOffsetX", 4)
Addon:SetSetting("roleIconOffsetY", -2)
onUpdateHandler()
assertEqual(featureUpdates.roleIcon, rolesBefore + 1, "role settings coalesce into one role update")
assertEqual(framePasses, passesBeforeRoles + 1)
assertEqual(featureUpdates.name, namesBeforeBorders, "role styling does not rewrite names")

local passesBeforeLayout = framePasses
assertEqual(Addon:SetSetting("raidFrameAnchor", "BOTTOMRIGHT"), false,
    "the removed manual raid anchor setting should be rejected")
assertEqual(Addon:SetSetting("raidFrameGrowth", "LEFT"), false,
    "removed raid growth settings should be rejected")
assertEqual(Addon:RequestFeatureUpdate("frameLayout"), false,
    "the removed layout feature should not schedule updates")
assertEqual(framePasses, passesBeforeLayout,
    "removed layout settings should not scan compact unit frames")

assertEqual(Addon:GetSetting("threatIndicatorHideForTanks"), false)
assertEqual(Addon:GetSetting("threatIndicatorColorByThreat"), false)
assertEqual(Addon:GetSetting("threatIndicatorHighColorG"), 1)
assertEqual(Addon:GetSetting("threatIndicatorInsecureColorG"), 0.6)
assertEqual(Addon:GetSetting("threatIndicatorSecureColorG"), 0)
assertEqual(Addon:GetSetting("threatIndicatorBorderOpacity"), 100)
assertEqual(Addon:GetSetting("threatIndicatorBorderInset"), 0)
assertEqual(Addon:SetSetting("threatIndicatorBorder", "CUSTOM"), false, "removed border styles should be rejected")
assertEqual(Addon:SetSetting("threatIndicatorBorderTexture", "custom.tga"), false)
local threatUpdatesBefore = featureUpdates.threatIndicator
local namesBeforeThreat = featureUpdates.name
Addon:SetSetting("threatIndicatorHideForTanks", true)
Addon:SetSetting("threatIndicatorColorByThreat", true)
Addon:SetSetting("threatIndicatorHighColorB", 0.25)
Addon:SetSetting("threatIndicatorBorderOpacity", 40)
Addon:SetSetting("threatIndicatorBorderInset", -3)
Addon:SetSetting("threatIndicatorBorderColorG", 0.5)
Addon:SetSetting("threatIndicatorBorderSize", 4)
Addon:SetSetting("threatIndicatorBorderStyle", "GLOW")
Addon:SetSetting("threatIndicatorGlowSize", 12)
onUpdateHandler()
assertEqual(featureUpdates.threatIndicator, threatUpdatesBefore + 1, "threat options should coalesce into one update")
assertEqual(featureUpdates.name, namesBeforeThreat, "threat options should not update unrelated features")

local context = "solo"

function IsInRaid()
    return context == "raid"
end

function IsInGroup()
    return context == "party" or context == "raid"
end

assertEqual(Addon:GetAssignedProfileForContext("party"), "", "party assignment should default empty")
assertEqual(Addon:GetAssignedProfileForContext("raid"), "", "raid assignment should default empty")

Addon:SetGlobalSetting("partyProfile", "Party")
Addon:SetGlobalSetting("raidProfile", "Raid")

assertEqual(Addon:GetAssignedProfileForContext("party"), "Party", "party assignment should persist")
assertEqual(Addon:GetAssignedProfileForContext("raid"), "Raid", "raid assignment should persist")

context = "party"
assertEqual(Addon:ApplyAutomaticProfile(false), true, "party context should switch profile")
assertEqual(Addon:GetCurrentProfileName(), "Party", "party context should activate party profile")
assertEqual(Addon:GetSetting("crispFrameBorders"), false, "pixel alignment belongs to each profile")
assertEqual(Addon:GetSetting("roleIconStyle"), "BLIZZARD", "tiny roles belong to each profile")
assertEqual(Addon:GetSetting("roleIconSize"), 10)
assertEqual(Addon:GetSetting("nameAnchor"), "CENTER", "name placement belongs to each profile")
assertEqual(Addon:GetSetting("threatIndicatorHideForTanks"), false, "tank filtering should belong to each profile")
assertEqual(Addon:GetSetting("threatIndicatorColorByThreat"), false, "threat colours should belong to each profile")
assertEqual(Addon:GetSetting("threatIndicatorHighColorB"), 0)
assertEqual(Addon:GetSetting("threatIndicatorBorderOpacity"), 100)
assertEqual(Addon:GetSetting("threatIndicatorBorderInset"), 0)

context = "raid"
assertEqual(Addon:ApplyAutomaticProfile(false), true, "raid context should switch profile")
assertEqual(Addon:GetCurrentProfileName(), "Raid", "raid context should activate raid profile")

assertEqual(Addon:RenameProfile("Party", "Dungeon"), true, "rename should succeed")
assertEqual(Addon:GetAssignedProfileForContext("party"), "Dungeon", "party assignment should follow rename")

assertEqual(Addon:DeleteProfile("Raid"), true, "delete should succeed")
assertEqual(Addon:GetAssignedProfileForContext("raid"), "", "raid assignment should clear on delete")

context = "raid"
assertEqual(Addon:ApplyAutomaticProfile(false), false, "raid context should not switch when assignment is cleared")

assertEqual(Addon:SwitchProfile("Default"), true)
assertEqual(Addon:GetSetting("crispFrameBorders"), true, "switching back restores pixel alignment")
assertEqual(Addon:GetSetting("roleIconStyle"), "TINY")
assertEqual(Addon:GetSetting("showRoleIcons"), "TANK_HEALER")
assertEqual(Addon:GetSetting("roleIconSize"), 8)
assertEqual(Addon:GetSetting("roleIconPoint"), "LEFT")
assertEqual(Addon:GetSetting("roleIconOffsetX"), 4)
assertEqual(Addon:GetSetting("roleIconOffsetY"), -2)
assertEqual(Addon:GetSetting("nameAnchor"), "BOTTOMLEFT", "switching back restores the chosen name anchor")
assertEqual(Addon:GetSetting("threatIndicatorHideForTanks"), true)
assertEqual(Addon:GetSetting("threatIndicatorColorByThreat"), true)
assertEqual(Addon:DuplicateProfile("Default", "Indicator Copy"), true)
assertEqual(Addon:SwitchProfile("Indicator Copy"), true)
assertEqual(Addon:GetSetting("threatIndicatorHighColorB"), 0.25)
assertEqual(Addon:GetSetting("threatIndicatorBorderOpacity"), 40)
assertEqual(Addon:GetSetting("threatIndicatorBorderInset"), -3)
assertEqual(Addon:GetSetting("threatIndicatorBorderColorG"), 0.5)
assertEqual(Addon:GetSetting("threatIndicatorBorderSize"), 4)
assertEqual(Addon:GetSetting("threatIndicatorBorderStyle"), "GLOW")
assertEqual(Addon:GetSetting("threatIndicatorGlowSize"), 12)
assertEqual(Addon:GetSetting("nameAnchor"), "BOTTOMLEFT", "profile copies retain name placement")
local beforeIndicatorUpdate = featureUpdates.indicators
local beforeNameUpdate = featureUpdates.name
Addon:ChangeDesignerIndicator("default", 1, { mineOnly = false, color = { r = 0.2, g = 0.4, b = 0.6, a = 0.8 } })
Addon:ChangeDesignerIndicator("default", 1, { size = 30, text = "DURATION", anchor = "BOTTOM" })
Addon:ChangeDesignerGroup("default", "TOP", { grow = "RIGHT", spacing = 7 })
Addon:ChangeDesignerIndicator("1468", 1, { size = 40 })
onUpdateHandler()
assertEqual(featureUpdates.indicators, beforeIndicatorUpdate + 1, "designer edits should coalesce into one indicator update")
assertEqual(featureUpdates.name, beforeNameUpdate, "indicator edits should not refresh unrelated features")
local copiedSet = Addon:GetIndicatorSet("default")
assertEqual(copiedSet.items[1].mineOnly, false)
assertEqual(copiedSet.items[1].size, 30)
assertEqual(copiedSet.items[1].text, "DURATION")
assertEqual(copiedSet.items[1].anchor, "BOTTOM")
assertEqual(copiedSet.groups.TOP.spacing, 7)
assertEqual(Addon:SwitchProfile("Default"), true)
local originalSet = Addon:GetIndicatorSet("default")
assertEqual(originalSet.items[1].mineOnly, true, "profile copies must not share indicator entries")
assertEqual(originalSet.items[1].color.r, 1, "profile copies must not share indicator colours")
assertEqual(originalSet.items[1].size, 20)
assertEqual(originalSet.items[1].text, "NONE")
assertEqual(originalSet.items[1].anchor, "TOP")
assertEqual(originalSet.groups.TOP.grow, "LEFT", "profile copies must not share group settings")
assertEqual(originalSet.groups.TOP.spacing, 4)
assertEqual(Addon:GetIndicatorSet("1468").items[1].size, 26, "profile copies must not share specialization sets")
assertEqual(Addon:CreateProfile("Empty Indicators"), true)
assertEqual(Addon:SwitchProfile("Empty Indicators"), true)
assertEqual(#Addon:GetIndicatorSet("default").items, 0, "new profiles should have no indicators enabled")

print("PASS: auto_profile_switch_test")
