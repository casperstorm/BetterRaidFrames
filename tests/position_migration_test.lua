local env = assert(loadfile("tests/helpers/threat_env.lua"))()
local Addon = env.Addon
assert(loadfile("BetterRaidFrames.lua"))("BetterRaidFrames", Addon)
function Addon:UpdateAllFrames() end
for _, name in ipairs({ "SoloFrame", "Absorbs", "FrameBorders", "RaidMarkers", "RoleIcons",
    "ThreatIndicator", "PartyLeader", "Name", "DesignerIndicators", "EditMode" }) do
    Addon["Hook" .. name] = function() end
end
local loader = env.find(function(w) return w.events and w.events.ADDON_LOADED end)
local function Initialize() loader.scripts.OnEvent(loader, "ADDON_LOADED", "BetterRaidFrames") end

local features = { "raidMarker", "threatIndicator", "partyLeader" }
local points = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local function Center(point, relativePoint, x, y, size, width, height)
    local function X(anchor) return anchor:find("LEFT") and 0 or anchor:find("RIGHT") and 1 or 0.5 end
    local function Y(anchor) return anchor:find("BOTTOM") and 0 or anchor:find("TOP") and 1 or 0.5 end
    return width * X(relativePoint) + x + size * (0.5 - X(point)),
        height * Y(relativePoint) + y + size * (0.5 - Y(point))
end

BetterRaidFramesDB = { currentProfile = "Default", profiles = { Default = {} } }
local profiles = BetterRaidFramesDB.profiles
for _, point in ipairs(points) do
    for _, relative in ipairs(points) do
        local profile = {}
        profiles[point .. ":" .. relative] = profile
        for index, prefix in ipairs(features) do
            profile[prefix .. "Point"] = point
            profile[prefix .. "RelativePoint"] = relative
            profile[prefix .. "Size"] = 10 + index -- Include odd sizes and half-pixel offsets.
            profile[prefix .. "X"] = 4
            profile[prefix .. "Y"] = -7 -- Exercise the older X/Y migration too.
        end
    end
end
profiles.Current = { raidMarkerPoint = "RIGHT", raidMarkerOffsetX = -8, raidMarkerOffsetY = 3 }
profiles.Malformed = {
    raidMarkerPoint = false, raidMarkerRelativePoint = "RIGHT", raidMarkerSize = "bad",
    raidMarkerOffsetX = "bad", raidMarkerOffsetY = {},
    partyLeaderPoint = "invalid", partyLeaderRelativePoint = {},
}
Initialize()
assert(profiles.Default.raidMarkerPoint == "TOP" and profiles.Default.raidMarkerOffsetY == 2)
assert(profiles.Current.raidMarkerPoint == "RIGHT" and profiles.Current.raidMarkerOffsetX == -8
    and profiles.Current.raidMarkerOffsetY == 3, "a profile using Position is left unchanged")
assert(profiles.Malformed.raidMarkerPoint == "RIGHT" and profiles.Malformed.raidMarkerOffsetX == 8
    and profiles.Malformed.raidMarkerOffsetY == -6, "invalid settings use their previous defaults before conversion")
assert(profiles.Malformed.partyLeaderPoint == "TOPLEFT" and profiles.Malformed.partyLeaderOffsetX == 2
    and profiles.Malformed.partyLeaderOffsetY == -2)

for _, point in ipairs(points) do
    for _, relative in ipairs(points) do
        local name = point .. ":" .. relative
        local profile = profiles[name]
        for index, prefix in ipairs(features) do
            local position, x, y = profile[prefix .. "Point"], profile[prefix .. "OffsetX"], profile[prefix .. "OffsetY"]
            assert(position == relative, "Position follows the old frame anchor even in inactive profiles")
            assert(profile[prefix .. "RelativePoint"] == nil and profile[prefix .. "X"] == nil and profile[prefix .. "Y"] == nil)
            for _, dimensions in ipairs({ { 72, 36 }, { 200, 80 } }) do
                local oldX, oldY = Center(point, relative, 4, -7, 10 + index, dimensions[1], dimensions[2])
                local newX, newY = Center(position, position, x, y, profile[prefix .. "Size"], dimensions[1], dimensions[2])
                assert(newX == oldX and newY == oldY, "migration preserves placement for " .. prefix .. " " .. name)
            end
            Addon:SwitchProfile(name)
            assert(profile[prefix .. "OffsetX"] == x and profile[prefix .. "OffsetY"] == y,
                "switching profiles does not repeat the conversion")
            assert(Addon:SetSetting(prefix .. "RelativePoint", "CENTER") == false, "retired anchors cannot be saved")
        end
    end
end
Addon:DuplicateProfile("LEFT:RIGHT", "Copy")
Addon:SwitchProfile("Copy")
assert(profiles.Copy.raidMarkerPoint == "RIGHT" and profiles.Copy.raidMarkerOffsetX == 15)
Addon:CreateProfile("New")
Addon:SwitchProfile("New")
assert(profiles.New.raidMarkerPoint == "TOP" and profiles.New.raidMarkerRelativePoint == nil)

BetterRaidFramesDB = {
    raidMarkerPoint = "LEFT", raidMarkerRelativePoint = "RIGHT", raidMarkerX = 3, raidMarkerY = -2, raidMarkerSize = 18,
    threatIndicatorPoint = "BOTTOMRIGHT", threatIndicatorRelativePoint = "TOPLEFT",
    threatIndicatorOffsetX = 4, threatIndicatorOffsetY = -6, threatIndicatorSize = 10,
    partyLeaderPoint = "BOTTOM", partyLeaderRelativePoint = "TOP", partyLeaderX = -5, partyLeaderY = 7, partyLeaderSize = 20,
}
Initialize()
local flat = BetterRaidFramesDB.profiles.Default
assert(flat.raidMarkerPoint == "RIGHT" and flat.raidMarkerOffsetX == 21 and flat.raidMarkerOffsetY == -2)
assert(flat.threatIndicatorPoint == "TOPLEFT" and flat.threatIndicatorOffsetX == -6 and flat.threatIndicatorOffsetY == 4)
assert(flat.partyLeaderPoint == "TOP" and flat.partyLeaderOffsetX == -5 and flat.partyLeaderOffsetY == 27)
Initialize()
assert(flat.raidMarkerOffsetX == 21 and flat.threatIndicatorOffsetY == 4 and flat.partyLeaderOffsetY == 27,
    "reloading does not repeat migration")
for _, prefix in ipairs(features) do
    assert(flat[prefix .. "RelativePoint"] == nil and BetterRaidFramesDB[prefix .. "RelativePoint"] == nil)
end

print("PASS: position_migration_test (all anchor pairs, geometry, profiles, flat saves, malformed data, idempotence)")
