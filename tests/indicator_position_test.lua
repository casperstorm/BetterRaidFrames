local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertEqual failed") .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local settings = {
    showRaidMarkers = true,
    showRoleIcons = "ALL",
    raidMarkerPoint = "LEFT",
    raidMarkerRelativePoint = "RIGHT",
    raidMarkerOffsetX = 3,
    raidMarkerOffsetY = -2,
    raidMarkerSize = 18,
    showThreatIndicator = true,
    threatIndicatorBlink = false,
    threatIndicatorShape = "CIRCLE",
    threatIndicatorPoint = "BOTTOMRIGHT",
    threatIndicatorRelativePoint = "TOPLEFT",
    threatIndicatorOffsetX = 4,
    threatIndicatorOffsetY = -6,
    threatIndicatorSize = 10,
    showPartyLeader = true,
    partyLeaderPoint = "BOTTOM",
    partyLeaderRelativePoint = "TOP",
    partyLeaderOffsetX = -5,
    partyLeaderOffsetY = 7,
    partyLeaderSize = 20,
    partyLeaderHideInCombat = false,
}

local Addon = {}
function Addon:GetSetting(key) return settings[key] end
function Addon:GetSettings() return settings end
function Addon:IsConfigOpen() return true end
function Addon:IsEditModeActive() return false end

local function CreateRegion()
    return {
        SetSize = function(self, width, height)
            self.width = width
            self.height = height
        end,
        ClearAllPoints = function() end,
        SetPoint = function(self, point, relativeTo, relativePoint, x, y)
            self.position = { point, relativeTo, relativePoint, x, y }
        end,
        GetPoint = function(self)
            local position = self.position
            if not position then return nil end
            return position[1], position[2], position[3], position[4], position[5]
        end,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
        SetBRFShape = function(self, shape) self.shape = shape end,
        IsShown = function(self) return self.shown == true end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
end

local animation = {
    playing = false,
    Stop = function(self) self.playing = false end,
    Play = function(self) self.playing = true end,
    IsPlaying = function(self) return self.playing end,
}

local raidMarker = CreateRegion()
local roleIcon = CreateRegion()
roleIcon.position = { "TOPRIGHT", nil, "TOPRIGHT", -3, -2 }
local threatIndicator = CreateRegion()
threatIndicator.animGroup = animation
local leaderIndicator = CreateRegion()

local frame = {
    unit = "party1",
    BRFRaidMarker = raidMarker,
    roleIcon = roleIcon,
    BRFThreatIndicator = threatIndicator,
    BRFLeaderIndicator = leaderIndicator,
}

function UnitExists(unit) return unit == "party1" end
function GetRaidTargetIndex() return 1 end
function SetRaidTargetIconTexture() end
function UnitIsGroupLeader() return true end
function UnitGroupRolesAssigned() return "HEALER" end
function UnitAffectingCombat() return false end

assert(loadfile("Utils.lua"))("BetterRaidFrames", Addon)
assert(loadfile("RaidMarkers.lua"))("BetterRaidFrames", Addon)
assert(loadfile("RoleIcons.lua"))("BetterRaidFrames", Addon)
assert(loadfile("ThreatIndicator.lua"))("BetterRaidFrames", Addon)
assert(loadfile("PartyLeader.lua"))("BetterRaidFrames", Addon)

Addon:UpdateRaidMarker(frame)
assertEqual(raidMarker.position[1], "LEFT", "raid marker anchor should be configurable")
assertEqual(raidMarker.position[2], frame, "raid marker should remain relative to its unit frame")
assertEqual(raidMarker.position[3], "RIGHT", "raid marker frame anchor should be configurable")
assertEqual(raidMarker.position[4], 3, "raid marker relative X should be applied")
assertEqual(raidMarker.position[5], -2, "raid marker relative Y should be applied")
assertEqual(raidMarker.width, 18, "raid marker size should be applied")

Addon:UpdateRoleIcon(frame)
assertEqual(roleIcon.position[1], "TOPRIGHT", "role icon should keep Blizzard's selected layout")
assertEqual(roleIcon.position[3], "TOPRIGHT", "role icon anchor should not be overridden")
assertEqual(roleIcon.position[4], -3, "role icon offset should not be overridden")

Addon:UpdateThreatIndicator(frame)
assertEqual(threatIndicator.shape, "CIRCLE", "threat indicator should support a circle shape")
assertEqual(threatIndicator.position[1], "BOTTOMRIGHT", "threat anchor should be configurable")
assertEqual(threatIndicator.position[2], frame, "threat indicator should remain relative to its unit frame")
assertEqual(threatIndicator.position[3], "TOPLEFT", "threat frame anchor should be configurable")
assertEqual(threatIndicator.position[4], 4, "threat relative X should be applied")
assertEqual(threatIndicator.position[5], -6, "threat relative Y should be applied")
assertEqual(threatIndicator.width, 10, "threat indicator size should be applied")

Addon:UpdatePartyLeader(frame)
assertEqual(leaderIndicator.position[1], "BOTTOM", "leader icon anchor should be configurable")
assertEqual(leaderIndicator.position[2], frame, "leader icon should remain relative to its unit frame")
assertEqual(leaderIndicator.position[3], "TOP", "leader icon frame anchor should be configurable")
assertEqual(leaderIndicator.position[4], -5, "leader icon relative X should be applied")
assertEqual(leaderIndicator.position[5], 7, "leader icon relative Y should be applied")
assertEqual(leaderIndicator.width, 20, "leader icon size should be applied")

settings.threatIndicatorShape = "SQUARE"
settings.threatIndicatorPoint = "INVALID"
settings.threatIndicatorRelativePoint = nil
Addon:UpdateThreatIndicator(frame)
assertEqual(threatIndicator.shape, "SQUARE", "threat shape should switch back to square")
assertEqual(threatIndicator.position[1], "CENTER", "invalid anchors should fall back safely")
assertEqual(threatIndicator.position[3], "CENTER", "missing frame anchors should fall back safely")

settings.showThreatIndicator = false
Addon:UpdateThreatIndicator(frame)
assertEqual(threatIndicator.shown, false, "disabled threat indicators should be hidden")

print("PASS: indicator_position_test")
