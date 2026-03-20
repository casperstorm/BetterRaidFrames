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

function framePrototype:RegisterEvent() end
function framePrototype:SetScript() end
function framePrototype:CreateFontString()
    return {
        SetPoint = function() end,
        SetText = function() end,
    }
end
function framePrototype:SetSize() end
function framePrototype:SetPoint() end
function framePrototype:SetText() end

function CreateFrame()
    return setmetatable({}, { __index = framePrototype })
end

local Addon = {
    UpdateAllFrames = function() end,
}

assert(loadfile("BetterRaidFrames.lua"))("BetterRaidFrames", Addon)
Addon.UpdateAllFrames = function() end

BetterRaidFramesDB = {
    currentProfile = "Default",
    profiles = {
        Default = {},
        Party = {},
        Raid = {},
    },
    globalSettings = {},
}

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

print("PASS: auto_profile_switch_test")
