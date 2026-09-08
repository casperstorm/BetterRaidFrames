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
    frameLayout = 0,
    raidMarker = 0,
    roleIcon = 0,
    threatIndicator = 0,
    partyLeader = 0,
    name = 0,
    buffIndicators = 0,
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
    ForEachFrame = function(_, callback)
        framePasses = framePasses + 1
        callback({})
    end,
    UpdateRaidMarker = function() featureUpdates.raidMarker = featureUpdates.raidMarker + 1 end,
    UpdateRoleIcon = function() featureUpdates.roleIcon = featureUpdates.roleIcon + 1 end,
    UpdateThreatIndicator = function() featureUpdates.threatIndicator = featureUpdates.threatIndicator + 1 end,
    UpdatePartyLeader = function() featureUpdates.partyLeader = featureUpdates.partyLeader + 1 end,
    UpdateName = function() featureUpdates.name = featureUpdates.name + 1 end,
    UpdateBuffIndicators = function() featureUpdates.buffIndicators = featureUpdates.buffIndicators + 1 end,
    UpdateRaidFrameLayout = function() featureUpdates.frameLayout = featureUpdates.frameLayout + 1 end,
    InitializeRaidFrameLayout = function() end,
    HookRaidMarkers = function() end,
    HookRoleIcons = function() end,
    HookThreatIndicator = function() end,
    HookPartyLeader = function() end,
    HookName = function() end,
    HookBuffIndicators = function() end,
    HookEditMode = function() end,
}

local updateBuffIndicators, hookBuffIndicators = Addon.UpdateBuffIndicators, Addon.HookBuffIndicators
assert(loadfile("BuffIndicators.lua"))("BetterRaidFrames", Addon)
Addon.UpdateBuffIndicators, Addon.HookBuffIndicators = updateBuffIndicators, hookBuffIndicators
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

assertEqual(#Addon:GetSetting("buffIndicators"), 1, "saved buffs should be normalized on load")
assertEqual(Addon:GetSetting("buffIndicators")[1].obsolete, nil, "unknown buff fields should be removed")
assertEqual(Addon:GetSetting("buffIndicators")[1].mineOnly, true, "saved buffs should default to own casts")
assertEqual(Addon:GetSetting("buffIndicators")[1].thickness, 2, "existing profiles should keep the two-pixel height")
assertEqual(Addon:GetSetting("buffIndicators")[1].direction, "ELAPSED")
assertEqual(Addon:GetSetting("buffIndicators")[1].position, "TOP")
assertEqual(Addon:GetSetting("buffIndicators")[1].frameLevel, 10)
local legacy = BetterRaidFramesDB.profiles["Legacy Buffs"]
assertEqual(legacy.buffIndicators[1].thickness, 4, "shared thickness should migrate into existing buffs")
assertEqual(legacy.buffIndicators[1].direction, "REMAINING")
assertEqual(legacy.buffIndicators[1].position, "RIGHT")
assertEqual(legacy.buffIndicators[1].frameLevel, 112)
assertEqual(legacy.buffIndicators[2].thickness, 8, "per-buff choices must take precedence during migration")
assertEqual(legacy.buffIndicators[2].direction, "ELAPSED")
assertEqual(legacy.buffIndicators[2].position, "LEFT")
assertEqual(legacy.buffIndicators[2].frameLevel, 0)
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
assertEqual(BetterRaidFramesDB.profiles.Default.raidFrameGrowth, "RIGHT",
    "legacy horizontal growth should migrate to right")
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
onUpdateHandler()
assertEqual(framePasses, passesBeforeName + 1, "name settings should coalesce into one frame pass")
assertEqual(featureUpdates.name, 1, "name settings should only update names")

local passesBeforeLayout = framePasses
local layoutUpdatesBefore = featureUpdates.frameLayout
assertEqual(Addon:SetSetting("raidFrameAnchor", "BOTTOMRIGHT"), false,
    "the removed manual raid anchor setting should be rejected")
assertEqual(Addon:SetSetting("raidFrameGrowth", "LEFT"), true,
    "raid frame growth should be configurable")
onUpdateHandler()
assertEqual(framePasses, passesBeforeLayout,
    "layout-only settings should not scan compact unit frames")
assertEqual(featureUpdates.frameLayout, layoutUpdatesBefore + 1,
    "layout settings should coalesce into one layout update")

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
assertEqual(Addon:DuplicateProfile("Default", "Buff Copy"), true)
assertEqual(Addon:SwitchProfile("Buff Copy"), true)
local beforeBuffUpdate = featureUpdates.buffIndicators
local beforeNameUpdate = featureUpdates.name
Addon:ChangeBuffIndicator(1, { mineOnly = false, r = 0.2 })
Addon:ChangeBuffIndicator(1, { thickness = 6 })
Addon:ChangeBuffIndicator(1, { direction = "REMAINING" })
Addon:ChangeBuffIndicator(1, { position = "BOTTOM" })
Addon:ChangeBuffIndicator(1, { frameLevel = 50 })
onUpdateHandler()
assertEqual(featureUpdates.buffIndicators, beforeBuffUpdate + 1, "buff edits should refresh buff indicators")
assertEqual(featureUpdates.name, beforeNameUpdate, "buff edits should not refresh unrelated features")
assertEqual(Addon:GetSetting("buffIndicators")[1].mineOnly, false)
assertEqual(Addon:GetSetting("buffIndicators")[1].thickness, 6)
assertEqual(Addon:GetSetting("buffIndicators")[1].direction, "REMAINING")
assertEqual(Addon:GetSetting("buffIndicators")[1].position, "BOTTOM")
assertEqual(Addon:GetSetting("buffIndicators")[1].frameLevel, 50)
assertEqual(Addon:SwitchProfile("Default"), true)
assertEqual(Addon:GetSetting("buffIndicators")[1].mineOnly, true, "profile copies must not share buff entries")
assertEqual(Addon:GetSetting("buffIndicators")[1].r, 1, "profile copies must not share buff colours")
assertEqual(Addon:GetSetting("buffIndicators")[1].thickness, 2, "height settings should belong to each profile")
assertEqual(Addon:GetSetting("buffIndicators")[1].direction, "ELAPSED", "direction should belong to each profile")
assertEqual(Addon:GetSetting("buffIndicators")[1].position, "TOP", "position should belong to each profile")
assertEqual(Addon:GetSetting("buffIndicators")[1].frameLevel, 10, "layering should belong to each profile")
Addon:ChangeBuffIndicator(1, { position = "LEFT" })
assertEqual(Addon:DuplicateProfile("Default", "Vertical Buffs"), true)
assertEqual(Addon:SwitchProfile("Vertical Buffs"), true)
assertEqual(Addon:GetSetting("buffIndicators")[1].position, "LEFT", "left placement should survive profile normalization")
Addon:ChangeBuffIndicator(1, { position = "RIGHT" })
assertEqual(Addon:SwitchProfile("Default"), true)
assertEqual(Addon:GetSetting("buffIndicators")[1].position, "LEFT", "vertical placement should remain profile-specific")
assertEqual(Addon:SwitchProfile("Vertical Buffs"), true)
assertEqual(Addon:GetSetting("buffIndicators")[1].position, "RIGHT", "right placement should survive profile normalization")
assertEqual(Addon:CreateProfile("Empty Buffs"), true)
assertEqual(Addon:SwitchProfile("Empty Buffs"), true)
assertEqual(#Addon:GetSetting("buffIndicators"), 0, "new profiles should have no indicators enabled")

print("PASS: auto_profile_switch_test")
