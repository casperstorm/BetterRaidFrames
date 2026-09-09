local settings = {
    showThreatIndicator = true,
    threatIndicatorBlink = true,
    threatIndicatorHideForTanks = false,
    threatIndicatorColorByThreat = true,
}
local status, role, exists, configOpen = nil, "DAMAGER", true, false
local hooks, roleUnits, threatUnits = {}, {}, {}
local secret = setmetatable({}, {
    __lt = function() error("compared restricted threat") end,
    __le = function() error("compared restricted threat") end,
})
local colours = { [1] = { 1, 1, 0 }, [2] = { 1, 0.6, 0 }, [3] = { 1, 0, 0 } }
function issecretvalue(value) return rawequal(value, secret) end
function UnitExists(unit) assert(not issecretvalue(unit)); return exists end
function UnitThreatSituation(unit)
    assert(not issecretvalue(unit))
    threatUnits[#threatUnits + 1] = unit
    return status
end
function UnitGroupRolesAssigned(unit)
    assert(not issecretvalue(unit))
    roleUnits[#roleUnits + 1] = unit
    return role
end
function GetThreatStatusColor(value)
    assert(not issecretvalue(value), "restricted threat must not be used for colour lookups")
    return table.unpack(assert(colours[value]))
end
function hooksecurefunc(name, callback) hooks[name] = callback end
function CreateFrame() error("hidden units must not allocate an indicator") end

local Addon = {}
function Addon:GetSettings() return settings end
function Addon:IsThreatPreviewOpen() return configOpen end
function Addon:IsEditModeActive() return false end
function Addon:IsRaidOrPartyFrame(frame) return frame.valid ~= false end
function Addon:GetValidAnchor(_, fallback) return fallback end
function Addon:ApplyRegionLayout() end -- Geometry is covered by indicator_position_test.
function Addon:StyleThreatBorder() end -- Border rendering is covered by threat_visual_test.
assert(loadfile("ThreatIndicator.lua"))("BetterRaidFrames", Addon)
Addon:HookThreatIndicator()

local indicator = { shown = false, alpha = 1 }
function indicator:SetBRFShape() end
function indicator:ClearAllPoints() end
function indicator:Show() self.shown = true end
function indicator:Hide() self.shown = false end
function indicator:IsShown() return self.shown end
function indicator:SetAlpha(value) self.alpha = value end
indicator.texture = { SetColorTexture = function(self, ...) self.colour = { ... } end, SetShown = function() end }
indicator.animGroup = {
    playing = false,
    IsPlaying = function(self) return self.playing end,
    Play = function(self) self.playing = true end,
    Stop = function(self) self.playing = false end,
}
local frame = { unit = "party1", BRFThreatIndicator = indicator }
local function Update() Addon:UpdateThreatIndicator(frame) end
local function Hidden()
    assert(not indicator.shown and not indicator.animGroup.playing and indicator.alpha == 1)
end
local function Colour(expected)
    for index, value in ipairs(expected) do assert(indicator.texture.colour[index] == value) end
end

Update(); Hidden()
status = 0
Update(); Hidden()
for level = 1, 3 do
    status = level
    hooks.CompactUnitFrame_UpdateAggroHighlight(frame)
    assert(indicator.shown and indicator.animGroup.playing)
    Colour(colours[level])
end
indicator.alpha = 0.2
status = nil
Update(); Hidden()

-- Toggling colour mode restores red; live colours still work during preview.
status = 2
settings.threatIndicatorColorByThreat = false
Update(); Colour({ 1, 0, 0, 1 })
settings.threatIndicatorColorByThreat = true
configOpen = true
Update(); Colour(colours[2])
status = nil
Update(); Colour(colours[2]); assert(indicator.shown)

-- All three configured colours work, and the single-colour mode uses Secure.
settings.threatIndicatorHighColorR, settings.threatIndicatorHighColorG, settings.threatIndicatorHighColorB = .1, .2, .3
settings.threatIndicatorInsecureColorR, settings.threatIndicatorInsecureColorG, settings.threatIndicatorInsecureColorB = .4, .5, .6
settings.threatIndicatorSecureColorR, settings.threatIndicatorSecureColorG, settings.threatIndicatorSecureColorB = .7, .8, .9
local custom = { { .1, .2, .3 }, { .4, .5, .6 }, { .7, .8, .9 } }
for level = 1, 3 do status = level; Update(); Colour(custom[level]) end
settings.threatIndicatorColorByThreat = false
status = 1
Update(); Colour(custom[3])
settings.threatIndicatorColorByThreat = true
for _, level in ipairs(Addon.ThreatLevels) do
    for _, channel in ipairs({ "R", "G", "B" }) do settings[level.key .. channel] = nil end
end
status = nil
for index = 1, 3 do frame.unit = "party" .. index; Update(); Colour(colours[index % 3 + 1]) end
frame.unit = "party1"
configOpen = false
Update(); Hidden()
configOpen = true
Update(); assert(indicator.shown)

-- Tank filtering applies to preview too and follows role updates immediately.
settings.threatIndicatorHideForTanks = true
role = "TANK"
hooks.CompactUnitFrame_UpdateRoleIcon(frame)
Hidden()
Addon:UpdateThreatIndicator({ unit = "party2" })
role = "HEALER"
hooks.CompactUnitFrame_UpdateRoleIcon(frame)
assert(indicator.shown)
role = "NONE"
Update(); assert(indicator.shown)
role = "TANK"
settings.threatIndicatorHideForTanks = false
Update(); assert(indicator.shown)

-- Vehicle threat comes from the displayed unit; role belongs to its owner.
settings.threatIndicatorHideForTanks = true
frame.displayedUnit = "partypet1"
role = "TANK"
Update(); Hidden()
assert(roleUnits[#roleUnits] == "party1")
role = "HEALER"
status = 1
Update(); Colour(colours[1])
assert(threatUnits[#threatUnits] == "partypet1")

-- Recycled/absent frames and restricted values must clear stale animations.
frame.displayedUnit = nil
frame.unit = "party3"
exists = false
hooks.CompactUnitFrame_SetUnit(frame)
Hidden()
exists = true
configOpen = false
Update(); assert(indicator.shown)
status = secret
Update(); Hidden()
status = 2
role = secret
Update(); Hidden()
role = "HEALER"
exists = secret
Update(); Hidden()
exists = true
frame.displayedUnit = secret
Update(); Hidden()
frame.displayedUnit = nil
frame.unit = secret
Update(); Hidden()
frame.unit = "party1"
Update(); assert(indicator.shown)
settings.threatIndicatorBlink = false
Update(); assert(indicator.shown and not indicator.animGroup.playing and indicator.alpha == 1)
settings.showThreatIndicator = false
Update(); Hidden()

print("PASS: threat_indicator_test")
