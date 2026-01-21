local ADDON_NAME, Addon = ...

local function IsRaidOrPartyFrame(frame)
    if not frame or not frame.unit then return false end
    local unit = frame.unit
    return unit == "player" or 
           string.match(unit, "^party%d") or 
           string.match(unit, "^raid%d")
end

Addon.RoleIconOptions = {
    { value = "ALL", label = "All" },
    { value = "TANK", label = "Tank" },
    { value = "HEALER", label = "Healer" },
    { value = "TANK_HEALER", label = "Tank & Healer" },
    { value = "NONE", label = "None" },
}

local function UpdateRoleIcon(frame)
    if not frame or not frame.roleIcon then return end
    
    local unit = frame.unit
    if not unit then return end
    
    local role = UnitGroupRolesAssigned(unit)
    local setting = Addon:GetSetting("showRoleIcons")
    local shouldShow = false
    
    if setting == "ALL" then
        shouldShow = true
    elseif setting == "TANK" then
        shouldShow = (role == "TANK")
    elseif setting == "HEALER" then
        shouldShow = (role == "HEALER")
    elseif setting == "TANK_HEALER" then
        shouldShow = (role == "TANK" or role == "HEALER")
    end
    
    if shouldShow and role and role ~= "NONE" then
        frame.roleIcon:Show()
    else
        frame.roleIcon:Hide()
    end
end

function Addon:HookRoleIcons()
    hooksecurefunc("CompactUnitFrame_UpdateRoleIcon", function(frame)
        if not IsRaidOrPartyFrame(frame) then return end
        UpdateRoleIcon(frame)
    end)
end

function Addon:UpdateRoleIcon(frame)
    UpdateRoleIcon(frame)
end
