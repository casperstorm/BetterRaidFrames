local _, Addon = ...
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local hooksecurefunc = hooksecurefunc
local hooked = false
local nativeWidths = setmetatable({}, { __mode = "k" })

-- Borderless artwork also used by Blizzard's group finder.
local tinyAtlases = {
    TANK = "groupfinder-icon-role-micro-tank",
    HEALER = "groupfinder-icon-role-micro-heal",
    DAMAGER = "groupfinder-icon-role-micro-dps",
}

Addon.RoleIconStyleOptions = {
    { value = "BLIZZARD", label = "Blizzard" },
    { value = "TINY", label = "Tiny" },
}

Addon.RoleIconOptions = {
    { value = "ALL", label = "All" },
    { value = "TANK", label = "Tank" },
    { value = "HEALER", label = "Healer" },
    { value = "TANK_HEALER", label = "Tank & Healer" },
    { value = "NONE", label = "None" },
}

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function Accessible(object)
    if not object then return false end
    local accessible = object:CanBeAccessedInContext()
    return not Secret(accessible) and accessible
end

local function Number(value, fallback, min, max)
    if Secret(value) or type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
    return math.max(min, math.min(max, value))
end

local function ShouldShow(role, filter)
    return role and tinyAtlases[role] and (filter == "ALL" or filter == role
        or (filter == "TANK_HEALER" and (role == "TANK" or role == "HEALER"))) or false
end

local function GetRole(unit)
    if Secret(unit) or not unit then return end
    local exists = UnitExists(unit)
    if Secret(exists) or not exists then return end
    local role = UnitGroupRolesAssigned(unit)
    if not Secret(role) and type(role) == "string" then return role end
end

local function Show(icon, shown)
    local current = icon:IsShown()
    if not Secret(current) and current == shown then return end
    if shown then icon:Show() else icon:Hide() end
end

local function UpdateTiny(frame, settings, role)
    local icon = frame.BRFTinyRoleIcon
    if icon and not Accessible(icon) then return end
    if not ShouldShow(role, settings.showRoleIcons) then
        if icon then Show(icon, false) end
        return
    end
    if not icon then
        icon = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        frame.BRFTinyRoleIcon = icon
    end
    local atlas = tinyAtlases[role]
    if icon.BRFRoleAtlas ~= atlas then
        icon:SetAtlas(atlas)
        icon.BRFRoleAtlas = atlas
    end
    local size = Number(settings.roleIconSize, 10, 6, 20)
    local point = Addon:GetValidAnchor(settings.roleIconPoint, "TOPRIGHT")
    local x = Number(settings.roleIconOffsetX, -3, -250, 250)
    local y = Number(settings.roleIconOffsetY, -3, -250, 250)
    Addon:ApplyRegionLayout(icon, frame, point, point, x, y, size)
    Show(icon, true)
end

local function UpdateRoleIcon(frame, settings)
    if not Accessible(frame) or not Accessible(frame.roleIcon) then return end
    settings = settings or Addon:GetSettings()
    local native = frame.roleIcon
    if settings.roleIconStyle == "TINY" then
        local width = native:GetWidth()
        if Secret(width) then return end
        if nativeWidths[frame] == nil then nativeWidths[frame] = width end
        -- Keep the native anchor and height: names can be anchored here, and
        -- Blizzard uses the height to restore the icon on its next role update.
        if width ~= 1 then native:SetWidth(1) end
        Show(native, false)
        -- Vehicle units can have no role; use the assigned player's role.
        local unit = frame.unit
        if not Secret(unit) and not unit then unit = frame.displayedUnit end
        UpdateTiny(frame, settings, GetRole(unit))
        return
    end
    if frame.BRFTinyRoleIcon and Accessible(frame.BRFTinyRoleIcon) then Show(frame.BRFTinyRoleIcon, false) end
    if nativeWidths[frame] ~= nil then
        native:SetWidth(nativeWidths[frame])
        nativeWidths[frame] = nil
    end
    local unit = frame.displayedUnit
    if not Secret(unit) and not unit then unit = frame.unit end
    Show(native, ShouldShow(GetRole(unit), settings.showRoleIcons))
end

function Addon:HookRoleIcons()
    if hooked then return end
    hooked = true
    hooksecurefunc("CompactUnitFrame_UpdateRoleIcon", function(frame)
        if not Accessible(frame) or not Accessible(frame.roleIcon) or Secret(frame.unit) then return end
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        if nativeWidths[frame] ~= nil then
            local width = frame.roleIcon:GetWidth()
            if Secret(width) then return end
            nativeWidths[frame] = width
        end
        UpdateRoleIcon(frame)
    end)
end

function Addon:UpdateRoleIcon(frame, settings)
    UpdateRoleIcon(frame, settings)
end

function Addon:UpdateRoleIconPreview(frame, settings, role)
    UpdateTiny(frame, settings, role)
end
