local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
assert(loadfile("Utils.lua"))("BetterRaidFrames", Addon)
local methods = getmetatable(env.frame()).__index
local writes, hookCount = 0, 0
function methods:SetAtlas(atlas) self.atlas = atlas end
for _, name in ipairs({ "SetSize", "SetWidth", "SetPoint", "ClearAllPoints", "SetAtlas", "Show", "Hide" }) do
    local original = methods[name]
    methods[name] = function(self, ...)
        assert(self:CanBeAccessedInContext() == true, "must not modify inaccessible role artwork")
        writes = writes + 1
        return original(self, ...)
    end
end
function hooksecurefunc(name, callback) hookCount = hookCount + 1; env.hooks[name] = callback end
local roles = { player = "TANK", party1 = "TANK", party2 = "HEALER", party3 = "DAMAGER", party4 = "NONE", partypet1 = "NONE" }
function UnitExists(unit) assert(unit ~= "secret"); return roles[unit] ~= nil end
function UnitGroupRolesAssigned(unit) assert(unit ~= "secret"); return roles[unit] end
assert(loadfile("RoleIcons.lua"))("BetterRaidFrames", Addon)
Addon:HookRoleIcons(); Addon:HookRoleIcons()
assert(hookCount == 1, "install one role hook, even if initialization repeats")

local settings = env.settings
settings.showRoleIcons = "ALL"
settings.roleIconStyle = "BLIZZARD"
settings.roleIconSize, settings.roleIconPoint = 10, "TOPRIGHT"
settings.roleIconOffsetX, settings.roleIconOffsetY = -3, -3
local function unitFrame(unit)
    local frame = env.frame(unit)
    frame.roleIcon = frame:CreateTexture()
    frame.roleIcon:SetSize(16, 16)
    frame.roleIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -2)
    frame.roleIcon:SetAtlas("native-" .. (roles[unit] or "NONE"))
    return frame
end
local tank, healer, damage = unitFrame("party1"), unitFrame("party2"), unitFrame("party3")
local allocated = #env.widgets
for _, frame in ipairs({ tank, healer, damage }) do
    Addon:UpdateRoleIcon(frame)
    assert(frame.roleIcon.shown and frame.roleIcon.width == 16 and not frame.BRFTinyRoleIcon)
end
assert(#env.widgets == allocated, "Blizzard style allocates no new visuals")

settings.roleIconStyle, settings.showRoleIcons = "TINY", "TANK_HEALER"
local nativePoint = tank.roleIcon.point
for _, frame in ipairs({ tank, healer, damage }) do Addon:UpdateRoleIcon(frame) end
local icon = tank.BRFTinyRoleIcon
assert(icon.atlas == "groupfinder-icon-role-micro-tank" and icon.width == 10 and icon.height == 10)
assert(healer.BRFTinyRoleIcon.atlas == "groupfinder-icon-role-micro-heal")
assert(not damage.BRFTinyRoleIcon and not damage.roleIcon.shown, "filtered damage roles allocate nothing")
assert(not tank.roleIcon.shown and tank.roleIcon.width == 1 and tank.roleIcon.height == 16)
assert(tank.roleIcon.point == nativePoint, "retain the native name anchor while reclaiming its icon width")
assert(icon.point[1] == "TOPRIGHT" and icon.point[2] == tank and icon.point[3] == "TOPRIGHT"
    and icon.point[4] == -3 and icon.point[5] == -3)

settings.roleIconPoint, settings.roleIconOffsetX, settings.roleIconOffsetY, settings.roleIconSize = "LEFT", 4, -7, 8
Addon:UpdateRoleIcon(tank)
assert(icon.point[1] == "LEFT" and icon.point[3] == "LEFT" and icon.point[4] == 4 and icon.point[5] == -7 and icon.width == 8)
assert(tank.roleIcon.point == nativePoint and tank.roleIcon.height == 16, "moving tiny artwork must not move names")

-- Blizzard uses the native icon's height to restore a square and can replace
-- its atlas for a newly assigned role or a vehicle before our post-hook runs.
local function nativeUpdate(frame, height, atlas)
    frame.roleIcon:SetSize(height, height)
    frame.roleIcon:SetAtlas(atlas)
    frame.roleIcon:Show()
    env.hooks.CompactUnitFrame_UpdateRoleIcon(frame)
end
tank.displayedUnit = "partypet1"
nativeUpdate(tank, 18, "RaidFrame-Icon-Vehicle")
assert(icon.shown and icon.atlas == "groupfinder-icon-role-micro-tank", "vehicles retain their assigned player's role")
assert(not tank.roleIcon.shown and tank.roleIcon.height == 18 and tank.roleIcon.width == 1)
tank.displayedUnit = nil
roles.party1 = "HEALER"
nativeUpdate(tank, 18, "native-HEALER")
assert(icon.atlas == "groupfinder-icon-role-micro-heal", "role reassignment updates the reusable texture")
settings.roleIconStyle = "BLIZZARD"
Addon:UpdateRoleIcon(tank)
assert(not icon.shown and tank.roleIcon.shown and tank.roleIcon.width == 18 and tank.roleIcon.atlas == "native-HEALER",
    "restore the latest native width and artwork after a role/layout change")
assert(tank.roleIcon.point == nativePoint)
settings.roleIconStyle = "TINY"
Addon:UpdateRoleIcon(tank)
assert(tank.BRFTinyRoleIcon == icon and icon.shown)

settings.showRoleIcons = "ALL"
Addon:UpdateRoleIcon(damage)
assert(damage.BRFTinyRoleIcon.atlas == "groupfinder-icon-role-micro-dps", "All still allows an optional damage marker")
settings.showRoleIcons = "TANK"
Addon:UpdateRoleIcon(tank); Addon:UpdateRoleIcon(damage)
assert(not icon.shown and not damage.BRFTinyRoleIcon.shown)
roles.party1 = "TANK"
Addon:UpdateRoleIcon(tank)
assert(icon.shown)
settings.showRoleIcons = "NONE"
Addon:UpdateRoleIcon(tank)
assert(not icon.shown and not tank.roleIcon.shown)
settings.showRoleIcons = "TANK_HEALER"

for _, role in ipairs({ "NONE", "secret" }) do
    roles.party1 = role
    Addon:UpdateRoleIcon(tank)
    assert(not icon.shown, "unassigned or secret roles have no marker")
end
roles.party1 = nil
Addon:UpdateRoleIcon(tank)
assert(not icon.shown, "missing units have no marker")
roles.party1, tank.unit = "TANK", "secret"
Addon:UpdateRoleIcon(tank)
env.hooks.CompactUnitFrame_UpdateRoleIcon(tank)
assert(not icon.shown, "secret unit tokens are never queried or compared")
tank.unit = "party1"

for _, object in ipairs({ tank, tank.roleIcon, icon }) do
    object.accessDenied = true
    local before = writes
    Addon:UpdateRoleIcon(tank)
    assert(writes == before, "temporarily inaccessible objects must be left untouched")
    object.accessDenied = false
end
Addon:UpdateRoleIcon(tank)
settings.roleIconSize, settings.roleIconPoint = 0 / 0, "INVALID"
settings.roleIconOffsetX, settings.roleIconOffsetY = 1000, -1000
Addon:UpdateRoleIcon(tank)
assert(icon.width == 10 and icon.point[1] == "TOPRIGHT" and icon.point[4] == 250 and icon.point[5] == -250)

-- Raid-sized, stable updates create no tables or UI objects and do no writes.
local raid = {}
for index = 1, 40 do
    local unit = "raid" .. index
    roles[unit] = index % 2 == 0 and "TANK" or "HEALER"
    raid[index] = unitFrame(unit)
    Addon:UpdateRoleIcon(raid[index])
end
allocated = #env.widgets
local before = writes
collectgarbage("collect"); collectgarbage("stop")
local memory = collectgarbage("count")
for _ = 1, 1000 do for _, frame in ipairs(raid) do Addon:UpdateRoleIcon(frame) end end
local temporary = collectgarbage("count") - memory
collectgarbage("restart")
assert(temporary < 1 and #env.widgets == allocated and writes == before,
    "40,000 stable role updates must not allocate objects/tables or rewrite artwork")
for _, widget in ipairs(env.widgets) do assert(not widget.scripts.OnUpdate, "roles must not add polling") end

print("PASS: role_icons_test (filters, anchors, vehicle roles, restoration, access, 40,000 stable updates)")
