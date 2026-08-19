local ADDON_NAME, Addon = ...

local defaults = {
    raidFrameGrowth = "RIGHT",
    showRaidMarkers = false,
    raidMarkerPoint = "TOP",
    raidMarkerRelativePoint = "TOP",
    raidMarkerOffsetX = 0,
    raidMarkerOffsetY = 2,
    raidMarkerSize = 16,
    showRoleIcons = "ALL",
    showThreatIndicator = false,
    threatIndicatorBlink = true,
    threatIndicatorShape = "SQUARE",
    threatIndicatorPoint = "CENTER",
    threatIndicatorRelativePoint = "CENTER",
    threatIndicatorOffsetX = 0,
    threatIndicatorOffsetY = 0,
    threatIndicatorSize = 8,
    showPartyLeader = false,
    partyLeaderPoint = "TOPLEFT",
    partyLeaderRelativePoint = "TOPLEFT",
    partyLeaderOffsetX = 2,
    partyLeaderOffsetY = -2,
    partyLeaderSize = 16,
    partyLeaderHideInCombat = false,
}

local POSITION_SETTING_MIGRATIONS = {
    raidMarkerX = "raidMarkerOffsetX",
    raidMarkerY = "raidMarkerOffsetY",
    threatIndicatorX = "threatIndicatorOffsetX",
    threatIndicatorY = "threatIndicatorOffsetY",
    partyLeaderX = "partyLeaderOffsetX",
    partyLeaderY = "partyLeaderOffsetY",
}

local RAID_GROWTH_MIGRATIONS = {
    DEFAULT = "RIGHT",
    HORIZONTAL = "RIGHT",
    VERTICAL = "RIGHT",
    DOWN = "RIGHT",
    UP = "LEFT",
}

local SETTING_FEATURES = {
    raidFrameGrowth = "frameLayout",
    showRaidMarkers = "raidMarker",
    raidMarkerPoint = "raidMarker",
    raidMarkerRelativePoint = "raidMarker",
    raidMarkerOffsetX = "raidMarker",
    raidMarkerOffsetY = "raidMarker",
    raidMarkerSize = "raidMarker",
    showRoleIcons = "roleIcon",
    showThreatIndicator = "threatIndicator",
    threatIndicatorBlink = "threatIndicator",
    threatIndicatorShape = "threatIndicator",
    threatIndicatorPoint = "threatIndicator",
    threatIndicatorRelativePoint = "threatIndicator",
    threatIndicatorOffsetX = "threatIndicator",
    threatIndicatorOffsetY = "threatIndicator",
    threatIndicatorSize = "threatIndicator",
    showPartyLeader = "partyLeader",
    partyLeaderPoint = "partyLeader",
    partyLeaderRelativePoint = "partyLeader",
    partyLeaderOffsetX = "partyLeader",
    partyLeaderOffsetY = "partyLeader",
    partyLeaderSize = "partyLeader",
    partyLeaderHideInCombat = "partyLeader",
}

local VALID_FEATURES = {
    frameLayout = true,
    raidMarker = true,
    roleIcon = true,
    threatIndicator = true,
    partyLeader = true,
}

local GLOBAL_DEFAULTS = {
    partyProfile = "",
    raidProfile = "",
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

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function NormalizeProfile(profile)
    for oldKey, newKey in pairs(POSITION_SETTING_MIGRATIONS) do
        if profile[newKey] == nil and profile[oldKey] ~= nil then
            profile[newKey] = profile[oldKey]
        end
    end

    profile.raidFrameGrowth = RAID_GROWTH_MIGRATIONS[profile.raidFrameGrowth]
        or profile.raidFrameGrowth

    for key in pairs(profile) do
        if defaults[key] == nil then
            profile[key] = nil
        end
    end

    for key, value in pairs(defaults) do
        if type(profile[key]) ~= type(value) then
            profile[key] = DeepCopy(value)
        end
    end
end

local function GetCurrentProfile()
    return BetterRaidFramesDB.profiles[BetterRaidFramesDB.currentProfile]
end

local function GetGlobalSettings()
    if type(BetterRaidFramesDB.globalSettings) ~= "table" then
        BetterRaidFramesDB.globalSettings = {}
    end

    local settings = BetterRaidFramesDB.globalSettings
    for key in pairs(settings) do
        if GLOBAL_DEFAULTS[key] == nil then
            settings[key] = nil
        end
    end
    for key, value in pairs(GLOBAL_DEFAULTS) do
        if type(settings[key]) ~= "string" then
            settings[key] = value
        end
    end

    return settings
end

local function InitializeDB()
    if type(BetterRaidFramesDB) ~= "table" then
        BetterRaidFramesDB = {}
    end

    -- Migrate from old flat structure to profiles
    if type(BetterRaidFramesDB.profiles) ~= "table" then
        local oldSettings = {}
        local hasOldSettings = false

        for key, value in pairs(defaults) do
            if BetterRaidFramesDB[key] ~= nil then
                oldSettings[key] = BetterRaidFramesDB[key]
                hasOldSettings = true
                BetterRaidFramesDB[key] = nil
            end
        end

        for oldKey, newKey in pairs(POSITION_SETTING_MIGRATIONS) do
            if oldSettings[newKey] == nil and BetterRaidFramesDB[oldKey] ~= nil then
                oldSettings[newKey] = BetterRaidFramesDB[oldKey]
                hasOldSettings = true
            end
        end

        BetterRaidFramesDB.profiles = {}
        BetterRaidFramesDB.currentProfile = "Default"

        if hasOldSettings then
            BetterRaidFramesDB.profiles["Default"] = oldSettings
        else
            BetterRaidFramesDB.profiles["Default"] = DeepCopy(defaults)
        end
    end

    for name, profile in pairs(BetterRaidFramesDB.profiles) do
        if type(name) ~= "string" or type(profile) ~= "table" then
            BetterRaidFramesDB.profiles[name] = nil
        else
            NormalizeProfile(profile)
        end
    end

    if not BetterRaidFramesDB.profiles.Default then
        BetterRaidFramesDB.profiles.Default = DeepCopy(defaults)
    end
    if type(BetterRaidFramesDB.currentProfile) ~= "string"
        or not BetterRaidFramesDB.profiles[BetterRaidFramesDB.currentProfile]
    then
        BetterRaidFramesDB.currentProfile = "Default"
    end

    for key in pairs(BetterRaidFramesDB) do
        if key ~= "profiles" and key ~= "currentProfile" and key ~= "globalSettings" then
            BetterRaidFramesDB[key] = nil
        end
    end

    GetGlobalSettings()
end

local function HookRaidFrames()
    Addon:InitializeRaidFrameLayout()
    Addon:HookRaidMarkers()
    Addon:HookRoleIcons()
    Addon:HookThreatIndicator()
    Addon:HookPartyLeader()
end

local pendingFeatureUpdates = {}
local updateThrottleFrame
local activeFeatures
local activeSettings
local activeConfigOpen
local activeInCombat

local function UpdateFrame(frame)
    if not activeFeatures or activeFeatures.raidMarker then Addon:UpdateRaidMarker(frame, activeSettings) end
    if not activeFeatures or activeFeatures.roleIcon then Addon:UpdateRoleIcon(frame, activeSettings) end
    if not activeFeatures or activeFeatures.threatIndicator then
        Addon:UpdateThreatIndicator(frame, activeSettings, activeConfigOpen)
    end
    if not activeFeatures or activeFeatures.partyLeader then
        Addon:UpdatePartyLeader(frame, activeSettings, activeInCombat)
    end
end

local function UpdateFrames(features)
    local updateAll = features == nil
    local updateLayout = updateAll or features.frameLayout
    local updateUnitFrames = updateAll or features.raidMarker or features.roleIcon
        or features.threatIndicator or features.partyLeader
    local updateThreat = updateAll or features.threatIndicator
    local updatePartyLeader = updateAll or features.partyLeader

    activeFeatures = features
    activeSettings = GetCurrentProfile()
    if updateLayout and Addon.UpdateRaidFrameLayout then
        Addon:UpdateRaidFrameLayout(activeSettings)
    end
    activeConfigOpen = updateThreat and Addon:IsConfigOpen() or false
    activeInCombat = updatePartyLeader and UnitAffectingCombat and UnitAffectingCombat("player") or false
    if updateUnitFrames then
        Addon:ForEachFrame(UpdateFrame)
    end
    activeFeatures = nil
    activeSettings = nil
end

local function ClearPendingFeatureUpdates()
    for feature in pairs(pendingFeatureUpdates) do
        pendingFeatureUpdates[feature] = nil
    end
end

local function FlushPendingFeatureUpdates()
    if updateThrottleFrame then updateThrottleFrame:Hide() end
    UpdateFrames(pendingFeatureUpdates)
    ClearPendingFeatureUpdates()
end

local function RequestFeatureUpdate(feature)
    pendingFeatureUpdates[feature] = true
    if not updateThrottleFrame then
        updateThrottleFrame = CreateFrame("Frame")
        updateThrottleFrame:Hide()
        updateThrottleFrame:SetScript("OnUpdate", FlushPendingFeatureUpdates)
    end
    updateThrottleFrame:Show()
end

function Addon:RequestFeatureUpdate(feature)
    if not VALID_FEATURES[feature] then return false end
    RequestFeatureUpdate(feature)
    return true
end

function Addon:UpdateAllFrames()
    if updateThrottleFrame then updateThrottleFrame:Hide() end
    ClearPendingFeatureUpdates()
    UpdateFrames(nil)
end

function Addon:GetSetting(key)
    local profile = GetCurrentProfile()
    return profile and profile[key]
end

function Addon:GetSettings()
    return GetCurrentProfile()
end

function Addon:SetSetting(key, value)
    local profile = GetCurrentProfile()
    if not profile or defaults[key] == nil then return false end
    if profile[key] == value then return true end

    profile[key] = value
    local feature = SETTING_FEATURES[key]
    if feature then
        RequestFeatureUpdate(feature)
    else
        self:UpdateAllFrames()
    end
    return true
end

function Addon:GetCurrentProfileName()
    return BetterRaidFramesDB.currentProfile
end

function Addon:GetGlobalSetting(key)
    return GetGlobalSettings()[key]
end

function Addon:SetGlobalSetting(key, value)
    if GLOBAL_DEFAULTS[key] == nil or type(value) ~= "string" then return false end

    local settings = GetGlobalSettings()
    settings[key] = value
    return true
end

function Addon:GetProfileList()
    local list = {}
    for name in pairs(BetterRaidFramesDB.profiles) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function Addon:GetAutoProfileOptions()
    local options = {
        { value = "", label = "Disabled" },
    }

    for _, name in ipairs(self:GetProfileList()) do
        table.insert(options, {
            value = name,
            label = name,
        })
    end

    return options
end

function Addon:GetGroupProfileContext()
    if IsInRaid and IsInRaid() then
        return "raid"
    end

    if IsInGroup and IsInGroup() then
        return "party"
    end

    return "solo"
end

function Addon:GetAssignedProfileForContext(context)
    if context == "party" then
        return self:GetGlobalSetting("partyProfile") or ""
    end
    if context == "raid" then
        return self:GetGlobalSetting("raidProfile") or ""
    end
    return ""
end

function Addon:ApplyAutomaticProfile(forceRefreshConfig)
    local context = self:GetGroupProfileContext()
    local targetProfile = self:GetAssignedProfileForContext(context)

    if targetProfile == "" or targetProfile == self:GetCurrentProfileName() then
        return false
    end

    if not BetterRaidFramesDB.profiles[targetProfile] then
        return false
    end

    local switched = self:SwitchProfile(targetProfile)
    if switched and forceRefreshConfig and self.RefreshConfig and self:IsConfigOpen() then
        self:RefreshConfig()
    end
    return switched
end

function Addon:SwitchProfile(name)
    if BetterRaidFramesDB.profiles[name] then
        BetterRaidFramesDB.currentProfile = name
        NormalizeProfile(GetCurrentProfile())
        self:UpdateAllFrames()
        return true
    end
    return false
end

local function IsValidProfileName(name)
    return type(name) == "string" and name:find("%S") ~= nil
end

function Addon:CreateProfile(name)
    if not IsValidProfileName(name) or BetterRaidFramesDB.profiles[name] then
        return false
    end
    BetterRaidFramesDB.profiles[name] = DeepCopy(defaults)
    return true
end

function Addon:DuplicateProfile(sourceName, targetName)
    if not IsValidProfileName(sourceName) or not BetterRaidFramesDB.profiles[sourceName] then
        return false
    end
    if not IsValidProfileName(targetName) or BetterRaidFramesDB.profiles[targetName] then
        return false
    end

    BetterRaidFramesDB.profiles[targetName] = DeepCopy(BetterRaidFramesDB.profiles[sourceName])
    return true
end

function Addon:DeleteProfile(name)
    if name == "Default" or not BetterRaidFramesDB.profiles[name] then
        return false
    end

    local globals = GetGlobalSettings()
    if globals.partyProfile == name then
        globals.partyProfile = ""
    end
    if globals.raidProfile == name then
        globals.raidProfile = ""
    end

    BetterRaidFramesDB.profiles[name] = nil
    if BetterRaidFramesDB.currentProfile == name then
        BetterRaidFramesDB.currentProfile = "Default"
        self:UpdateAllFrames()
    end
    return true
end

function Addon:RenameProfile(oldName, newName)
    if oldName == "Default" or not IsValidProfileName(newName) then
        return false
    end
    if not BetterRaidFramesDB.profiles[oldName] or BetterRaidFramesDB.profiles[newName] then
        return false
    end
    BetterRaidFramesDB.profiles[newName] = BetterRaidFramesDB.profiles[oldName]
    BetterRaidFramesDB.profiles[oldName] = nil
    local globals = GetGlobalSettings()
    if globals.partyProfile == oldName then
        globals.partyProfile = newName
    end
    if globals.raidProfile == oldName then
        globals.raidProfile = newName
    end
    if BetterRaidFramesDB.currentProfile == oldName then
        BetterRaidFramesDB.currentProfile = newName
    end
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

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

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitializeDB()
        HookRaidFrames()
        Addon:HookEditMode()
        RegisterOptionsPanel()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon:InitializeRaidFrameLayout()
        if not Addon:ApplyAutomaticProfile(true) then
            Addon:UpdateAllFrames()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not Addon:ApplyAutomaticProfile(true) then
            Addon:RequestFeatureUpdate("partyLeader")
        end
    end
end)

SLASH_BETTERRAIDFRAMES1 = "/brf"
SLASH_BETTERRAIDFRAMES2 = "/betterraidframes"

SlashCmdList["BETTERRAIDFRAMES"] = function()
    Addon:OpenConfig()
end

_G["BetterRaidFrames"] = Addon
