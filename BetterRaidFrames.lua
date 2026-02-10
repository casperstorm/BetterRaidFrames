local ADDON_NAME, Addon = ...

local defaults = {
    showRoleIcons = "ALL",
    showThreatIndicator = false,
    threatIndicatorBlink = true,
    threatIndicatorX = 0,
    threatIndicatorY = 0,
    threatIndicatorSize = 8,
    hideAuraBorders = false,
    customizeNames = false,
    nameX = 0,
    nameY = 0,
    nameSize = 11,
    nameHideServer = false,
    nameTruncate = false,
    nameTruncateLength = 8,
    nameClassColor = false,
    nameCyrillicToLatin = false,
    nameHideOnDead = false,
    showFriendlyAbsorb = false,
    friendlyAbsorbOpacity = 0.8,
    friendlyAbsorbColorR = 1,
    friendlyAbsorbColorG = 1,
    friendlyAbsorbColorB = 1,
    showHostileAbsorb = false,
    hostileAbsorbOpacity = 0.7,
    hostileAbsorbColorR = 0.4,
    hostileAbsorbColorG = 0.1,
    hostileAbsorbColorB = 0.1,
    showPartyLeader = false,
    partyLeaderX = 2,
    partyLeaderY = -2,
    partyLeaderSize = 16,
    partyLeaderHideInCombat = false,
}

function Addon:IsConfigOpen()
    return _G["BetterRaidFramesConfigFrame"] and _G["BetterRaidFramesConfigFrame"]:IsShown()
end

function Addon:IsEditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

-- Get the current Raid-Style Party Frames setting via LibEditModeOverride
function Addon:GetUseRaidStylePartyFrames()
    local LibEditModeOverride = LibStub and LibStub("LibEditModeOverride-1.0", true)
    if LibEditModeOverride and LibEditModeOverride:IsReady() then
        LibEditModeOverride:LoadLayouts()
        local success, result = pcall(function()
            return LibEditModeOverride:GetFrameSetting(PartyFrame, Enum.EditModeUnitFrameSetting.UseRaidStylePartyFrames)
        end)
        if success then
            return result == 1
        end
    end
    
    -- Fallback to checking EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame.UseRaidStylePartyFrames then
        return EditModeManagerFrame:UseRaidStylePartyFrames()
    end
    
    return false
end

-- Set the Raid-Style Party Frames setting via LibEditModeOverride
local RAID_STYLE_MAX_RETRIES, RAID_STYLE_RETRY_DELAY = 3, 2
function Addon:SetUseRaidStylePartyFrames(enabled, retryCount)
    local LibEditModeOverride = LibStub and LibStub("LibEditModeOverride-1.0", true)
    if not LibEditModeOverride then
        print("|cff00ff00BetterRaidFrames:|r LibEditModeOverride not available")
        return false
    end
    
    if not LibEditModeOverride:IsReady() then
        retryCount = retryCount or 0
        if retryCount > RAID_STYLE_MAX_RETRIES then
            print("|cff00ff00BetterRaidFrames:|r Edit Mode not ready, please try again later")
            return false
        end
        C_Timer.After(RAID_STYLE_RETRY_DELAY, function()
            Addon:SetUseRaidStylePartyFrames(enabled, retryCount + 1)
        end)
        return true
    end
    
    local value = enabled and 1 or 0
    
    LibEditModeOverride:LoadLayouts()
    
    if not LibEditModeOverride:CanEditActiveLayout() then
        print("|cff00ff00BetterRaidFrames:|r Cannot edit preset layouts. Create a custom layout in Edit Mode first.")
        return false
    end
    
    local success, err = pcall(function()
        LibEditModeOverride:SetFrameSetting(PartyFrame, Enum.EditModeUnitFrameSetting.UseRaidStylePartyFrames, value)
    end)
    
    if not success then
        print("|cff00ff00BetterRaidFrames:|r Failed to set Raid-Style Party Frames: " .. tostring(err))
        return false
    end
    
    if InCombatLockdown() then
        LibEditModeOverride:SaveOnly()
        print("|cff00ff00BetterRaidFrames:|r Setting saved. Will apply after combat.")
    else
        LibEditModeOverride:ApplyChanges()
    end
    
    return true
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
    Addon:HookName()
    Addon:HookFriendlyAbsorb()
    Addon:HookHostileAbsorb()
    Addon:HookPartyLeader()
end

function Addon:UpdateAllFrames()
    Addon:ForEachFrame(function(frame)
        Addon:UpdateRoleIcon(frame)
        Addon:UpdateThreatIndicator(frame)
        Addon:UpdateAuraBorders(frame)
        Addon:UpdateName(frame)
        Addon:UpdateFriendlyAbsorb(frame)
        Addon:UpdateHostileAbsorb(frame)
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

local function RegisterOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "BetterRaidFrames"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BetterRaidFrames")

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(150, 24)
    openBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    openBtn:SetText("Open Settings")
    openBtn:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel)
        Addon:OpenConfig()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    category.ID = panel.name
    Settings.RegisterAddOnCategory(category)
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitializeDB()
        HookRaidFrames()
        Addon:HookEditMode()
        RegisterOptionsPanel()
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
