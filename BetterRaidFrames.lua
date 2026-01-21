local ADDON_NAME, Addon = ...

-- Role icon display options
Addon.RoleIconOptions = {
    { value = "ALL", label = "All" },
    { value = "TANK", label = "Tank" },
    { value = "HEALER", label = "Healer" },
    { value = "TANK_HEALER", label = "Tank & Healer" },
    { value = "NONE", label = "None" },
}

-- Default settings
local defaults = {
    showRoleIcons = "ALL",
}

-- Initialize saved variables
local function InitializeDB()
    if not BetterRaidFramesDB then
        BetterRaidFramesDB = {}
    end
    for key, value in pairs(defaults) do
        if BetterRaidFramesDB[key] == nil then
            BetterRaidFramesDB[key] = value
        end
    end
end

-- Hook into CompactUnitFrame to hide role icons based on setting
local function UpdateRoleIcon(frame)
    if not frame or not frame.roleIcon then return end
    
    local unit = frame.unit
    if not unit then return end
    
    local role = UnitGroupRolesAssigned(unit)
    local setting = BetterRaidFramesDB.showRoleIcons
    
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

-- Hook the default raid frame role icon update
local function HookRaidFrames()
    hooksecurefunc("CompactUnitFrame_UpdateRoleIcon", function(frame)
        UpdateRoleIcon(frame)
    end)
end

-- Update all existing raid frames
function Addon:UpdateAllFrames()
    -- Update party frames
    for i = 1, 4 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then
            UpdateRoleIcon(frame)
        end
    end
    
    -- Update raid frames
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then
            UpdateRoleIcon(frame)
        end
    end
    
    -- Update raid group frames
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then
                UpdateRoleIcon(frame)
            end
        end
    end
end

-- Getter/Setter for settings
function Addon:GetSetting(key)
    return BetterRaidFramesDB[key]
end

function Addon:SetSetting(key, value)
    BetterRaidFramesDB[key] = value
    self:UpdateAllFrames()
end

-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitializeDB()
        HookRaidFrames()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon:UpdateAllFrames()
    end
end)

-- Slash commands
SLASH_BETTERRAIDFRAMES1 = "/brf"
SLASH_BETTERRAIDFRAMES2 = "/betterraidframes"

SlashCmdList["BETTERRAIDFRAMES"] = function(msg)
    Addon:OpenConfig()
end

-- Export addon table
_G["BetterRaidFrames"] = Addon
