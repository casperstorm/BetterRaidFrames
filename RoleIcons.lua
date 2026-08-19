local _, Addon = ...
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local hooksecurefunc = hooksecurefunc

Addon.RoleIconOptions = {
    { value = "ALL", label = "All" },
    { value = "TANK", label = "Tank" },
    { value = "HEALER", label = "Healer" },
    { value = "TANK_HEALER", label = "Tank & Healer" },
    { value = "NONE", label = "None" },
}

local function UpdateRoleIcon(frame, settings)
    if not frame or not frame.roleIcon then return end
    settings = settings or Addon:GetSettings()

    local setting = settings.showRoleIcons
    if setting == "NONE" then
        if frame.roleIcon:IsShown() then frame.roleIcon:Hide() end
        return
    end

    local unit = frame.displayedUnit or frame.unit
    if not unit or not UnitExists(unit) then
        if frame.roleIcon:IsShown() then frame.roleIcon:Hide() end
        return
    end

    local role = UnitGroupRolesAssigned(unit)
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
        if not frame.roleIcon:IsShown() then frame.roleIcon:Show() end
    elseif frame.roleIcon:IsShown() then
        frame.roleIcon:Hide()
    end
end

function Addon:HookRoleIcons()
    hooksecurefunc("CompactUnitFrame_UpdateRoleIcon", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        UpdateRoleIcon(frame)
    end)
end

function Addon:UpdateRoleIcon(frame, settings)
    UpdateRoleIcon(frame, settings)
end
