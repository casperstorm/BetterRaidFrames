local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertEqual failed") .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local settings = { raidFrameGrowth = "LEFT" }
local Addon = {}
function Addon:GetSettings() return settings end

local function CreateLayoutFrame(name, point, width, height, x, y)
    return {
        name = name,
        point = point,
        width = width,
        height = height,
        x = x,
        y = y,
        shown = true,
        OnDragStop = function() end,
        UpdateSystem = function() end,
        TryUpdate = function() end,
        GetPoint = function(self) return self.point, UIParent, "CENTER", self.x, self.y end,
        GetSize = function(self) return self.width, self.height end,
        IsShown = function(self) return self.shown end,
        ClearAllPoints = function() end,
        SetPoint = function(self, newPoint, relativeTo, relativePoint, newX, newY)
            self.point = newPoint
            self.relativeTo = relativeTo
            self.relativePoint = relativePoint
            self.x = newX
            self.y = newY
        end,
    }
end

UIParent = {}
CompactRaidFrameContainer = CreateLayoutFrame("container", "TOPLEFT", 200, 100, 100, 50)
CompactRaidFrameContainer.GetSettingValue = function() return 1 end

local group1 = CreateLayoutFrame("group1", "TOPLEFT", 50, 100, 0, 0)
local group2 = CreateLayoutFrame("group2", "TOPLEFT", 50, 100, 0, 0)
local group3 = CreateLayoutFrame("group3", "TOPLEFT", 50, 100, 0, 0)
_G.CompactRaidGroup1 = group1
_G.CompactRaidGroup2 = group2
_G.CompactRaidGroup3 = group3

Enum = {
    EditModeUnitFrameSetting = { RaidGroupDisplayType = 1 },
    RaidGroupDisplayType = {
        SeparateGroupsHorizontal = 1,
        SeparateGroupsVertical = 2,
    },
}

EditModeManagerFrame = { UpdateRaidContainerFlow = function() end }

local inCombat = false
function InCombatLockdown() return inCombat end

local eventHandler
local eventFrame = {
    RegisterEvent = function() end,
    SetScript = function(_, _, callback) eventHandler = callback end,
}
function CreateFrame() return eventFrame end
function hooksecurefunc() end

C_Timer = { After = function(_, callback) callback() end }

assert(loadfile("RaidFrameLayout.lua"))("BetterRaidFrames", Addon)
Addon:InitializeRaidFrameLayout()
Addon:UpdateRaidFrameLayout()

assertEqual(CompactRaidFrameContainer.point, "TOPRIGHT", "grow left should fix the right edge")
assertEqual(CompactRaidFrameContainer.x, 300, "anchor conversion should preserve screen position")
assertEqual(CompactRaidFrameContainer.y, 50, "anchor conversion should preserve vertical position")
assertEqual(group1.point, "TOPRIGHT", "grow left should start with group 1 on the right")
assertEqual(group1.relativeTo, CompactRaidFrameContainer, "group 1 should anchor to the container")
assertEqual(group2.point, "TOPRIGHT", "group 2 should grow left from the top edge")
assertEqual(group2.relativeTo, group1, "group 2 should follow group 1")
assertEqual(group2.relativePoint, "TOPLEFT", "group 2 should sit left of group 1")
assertEqual(group3.relativeTo, group2, "group 3 should continue growing left")

settings.raidFrameGrowth = "RIGHT"
Addon:UpdateRaidFrameLayout()
assertEqual(CompactRaidFrameContainer.point, "TOPLEFT", "grow right should fix the left edge")
assertEqual(group1.point, "TOPLEFT", "grow right should start with group 1 on the left")
assertEqual(group2.point, "TOPLEFT", "group 2 should grow right from the top edge")
assertEqual(group2.relativeTo, group1, "group 2 should follow group 1")
assertEqual(group2.relativePoint, "TOPRIGHT", "group 2 should sit right of group 1")

inCombat = true
settings.raidFrameGrowth = "LEFT"
Addon:UpdateRaidFrameLayout()
assertEqual(CompactRaidFrameContainer.point, "TOPLEFT", "combat should defer layout changes")

inCombat = false
eventHandler(nil, "PLAYER_REGEN_ENABLED")
assertEqual(CompactRaidFrameContainer.point, "TOPRIGHT", "queued anchor should apply after combat")
assertEqual(group2.relativePoint, "TOPLEFT", "queued growth should apply after combat")

print("PASS: raid_frame_layout_test")
