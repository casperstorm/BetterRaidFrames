local ADDON_NAME, Addon = ...

local defaults = {
    showRoleIcons = "ALL",
    showThreatIndicator = false,
    threatIndicatorBlink = true,
    threatIndicatorX = 0,
    threatIndicatorY = 0,
    threatIndicatorSize = 8,
    hideAuraBorders = false,
    hideDispelIndicator = false,
    hideIncomingHeals = true,
    customizeNames = false,
    nameX = 0,
    nameY = 0,
    nameSize = 11,
    nameHideServer = false,
    nameTruncate = false,
    nameTruncateLength = 8,
    nameClassColor = false,
    showFriendlyAbsorb = false,
    showHostileAbsorb = false,
    hideSelectionBorder = false,
    showPartyLeader = false,
    partyLeaderX = 2,
    partyLeaderY = -2,
    partyLeaderSize = 16,
    partyLeaderHideInCombat = false,
}

function Addon:IsConfigOpen()
    return _G["BetterRaidFramesConfigFrame"] and _G["BetterRaidFramesConfigFrame"]:IsShown()
end

local function CopyDefaults()
    local copy = {}
    for key, value in pairs(defaults) do
        copy[key] = value
    end
    return copy
end

local function GetCurrentProfile()
    return BetterRaidFramesDB.profiles[BetterRaidFramesDB.currentProfile]
end

local function InitializeDB()
    if not BetterRaidFramesDB then
        BetterRaidFramesDB = {}
    end

    -- Migrate from old flat structure to profiles
    if not BetterRaidFramesDB.profiles then
        local oldSettings = {}
        local hasOldSettings = false

        for key, value in pairs(defaults) do
            if BetterRaidFramesDB[key] ~= nil then
                oldSettings[key] = BetterRaidFramesDB[key]
                hasOldSettings = true
                BetterRaidFramesDB[key] = nil
            end
        end

        -- Clean up old migration keys
        BetterRaidFramesDB.showAbsorbShield = nil
        BetterRaidFramesDB.customThreatBorder = nil
        BetterRaidFramesDB.namePosition = nil
        BetterRaidFramesDB.threatIndicatorPosition = nil

        BetterRaidFramesDB.profiles = {}
        BetterRaidFramesDB.currentProfile = "Default"

        if hasOldSettings then
            BetterRaidFramesDB.profiles["Default"] = oldSettings
        else
            BetterRaidFramesDB.profiles["Default"] = CopyDefaults()
        end
    end

    -- Ensure current profile exists
    if not BetterRaidFramesDB.currentProfile then
        BetterRaidFramesDB.currentProfile = "Default"
    end
    if not BetterRaidFramesDB.profiles[BetterRaidFramesDB.currentProfile] then
        BetterRaidFramesDB.profiles["Default"] = CopyDefaults()
        BetterRaidFramesDB.currentProfile = "Default"
    end

    -- Fill in missing defaults for current profile
    local profile = GetCurrentProfile()
    for key, value in pairs(defaults) do
        if profile[key] == nil then
            profile[key] = value
        end
    end
end

local function HookRaidFrames()
    Addon:HookRoleIcons()
    Addon:HookThreatIndicator()
    Addon:HookAuraBorders()
    Addon:HookDispelIndicator()
    Addon:HookIncomingHeals()
    Addon:HookName()
    Addon:HookFriendlyAbsorb()
    Addon:HookHostileAbsorb()
    Addon:HookSelectionBorder()
    Addon:HookPartyLeader()
end

function Addon:UpdateAllFrames()
    Addon:ForEachFrame(function(frame)
        Addon:UpdateRoleIcon(frame)
        Addon:UpdateThreatIndicator(frame)
        Addon:UpdateAuraBorders(frame)
        Addon:UpdateIncomingHeals(frame)
        Addon:UpdateName(frame)
        Addon:UpdateFriendlyAbsorb(frame)
        Addon:UpdateHostileAbsorb(frame)
        Addon:UpdateSelectionBorder(frame)
        Addon:UpdatePartyLeader(frame)
    end)
end

function Addon:GetSetting(key)
    local profile = GetCurrentProfile()
    return profile and profile[key]
end

function Addon:SetSetting(key, value)
    local profile = GetCurrentProfile()
    if profile then
        profile[key] = value
    end
    self:UpdateAllFrames()
end

function Addon:GetCurrentProfileName()
    return BetterRaidFramesDB.currentProfile
end

function Addon:GetProfileList()
    local list = {}
    for name in pairs(BetterRaidFramesDB.profiles) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function Addon:SwitchProfile(name)
    if BetterRaidFramesDB.profiles[name] then
        BetterRaidFramesDB.currentProfile = name
        -- Fill in missing defaults
        local profile = GetCurrentProfile()
        for key, value in pairs(defaults) do
            if profile[key] == nil then
                profile[key] = value
            end
        end
        self:UpdateAllFrames()
        return true
    end
    return false
end

function Addon:CreateProfile(name)
    if not name or name == "" or BetterRaidFramesDB.profiles[name] then
        return false
    end
    BetterRaidFramesDB.profiles[name] = CopyDefaults()
    return true
end

function Addon:DeleteProfile(name)
    if name == "Default" or not BetterRaidFramesDB.profiles[name] then
        return false
    end
    BetterRaidFramesDB.profiles[name] = nil
    if BetterRaidFramesDB.currentProfile == name then
        BetterRaidFramesDB.currentProfile = "Default"
        self:UpdateAllFrames()
    end
    return true
end

function Addon:RenameProfile(oldName, newName)
    if oldName == "Default" or not newName or newName == "" then
        return false
    end
    if not BetterRaidFramesDB.profiles[oldName] or BetterRaidFramesDB.profiles[newName] then
        return false
    end
    BetterRaidFramesDB.profiles[newName] = BetterRaidFramesDB.profiles[oldName]
    BetterRaidFramesDB.profiles[oldName] = nil
    if BetterRaidFramesDB.currentProfile == oldName then
        BetterRaidFramesDB.currentProfile = newName
    end
    return true
end

function Addon:CopyToProfile(targetName)
    if not BetterRaidFramesDB.profiles[targetName] then
        return false
    end
    local currentProfile = GetCurrentProfile()
    for key, value in pairs(currentProfile) do
        BetterRaidFramesDB.profiles[targetName][key] = value
    end
    return true
end


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

SLASH_BETTERRAIDFRAMES1 = "/brf"
SLASH_BETTERRAIDFRAMES2 = "/betterraidframes"

SlashCmdList["BETTERRAIDFRAMES"] = function(msg)
    Addon:OpenConfig()
end

_G["BetterRaidFrames"] = Addon
