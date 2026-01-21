local ADDON_NAME, Addon = ...

local defaults = {
    showRoleIcons = "ALL",
    showThreatIndicator = false,
    threatIndicatorX = 0,
    threatIndicatorY = 0,
    threatIndicatorSize = 8,
    hideAuraBorders = false,
    hideIncomingHeals = true,
    customizeNames = false,
    nameX = 0,
    nameY = 0,
    nameHideServer = false,
    nameTruncate = false,
    nameTruncateLength = 8,
    showFriendlyAbsorb = false,
    showHostileAbsorb = false,
}

Addon.testMode = false

local function InitializeDB()
    if not BetterRaidFramesDB then
        BetterRaidFramesDB = {}
    end
    for key, value in pairs(defaults) do
        if BetterRaidFramesDB[key] == nil then
            if type(value) == "table" then
                BetterRaidFramesDB[key] = {}
                for k, v in pairs(value) do
                    BetterRaidFramesDB[key][k] = v
                end
            else
                BetterRaidFramesDB[key] = value
            end
        end
    end
    
    -- Migration
    if BetterRaidFramesDB.showAbsorbShield ~= nil then
        BetterRaidFramesDB.showFriendlyAbsorb = BetterRaidFramesDB.showAbsorbShield
        BetterRaidFramesDB.showAbsorbShield = nil
    end
    if BetterRaidFramesDB.customThreatBorder ~= nil then
        BetterRaidFramesDB.showThreatIndicator = BetterRaidFramesDB.customThreatBorder
        BetterRaidFramesDB.customThreatBorder = nil
    end
    if BetterRaidFramesDB.namePosition ~= nil then
        BetterRaidFramesDB.namePosition = nil
    end
    if BetterRaidFramesDB.threatIndicatorPosition ~= nil then
        BetterRaidFramesDB.threatIndicatorPosition = nil
    end
end

local function HookRaidFrames()
    Addon:HookRoleIcons()
    Addon:HookThreatIndicator()
    Addon:HookAuraBorders()
    Addon:HookIncomingHeals()
    Addon:HookName()
    Addon:HookFriendlyAbsorb()
    Addon:HookHostileAbsorb()
end

function Addon:UpdateAllFrames()
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then
            Addon:UpdateRoleIcon(frame)
            Addon:UpdateThreatIndicator(frame)
            Addon:UpdateAuraBorders(frame)
            Addon:UpdateIncomingHeals(frame)
            Addon:UpdateName(frame)
            Addon:UpdateFriendlyAbsorb(frame)
            Addon:UpdateHostileAbsorb(frame)
        end
    end
    
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then
            Addon:UpdateRoleIcon(frame)
            Addon:UpdateThreatIndicator(frame)
            Addon:UpdateAuraBorders(frame)
            Addon:UpdateIncomingHeals(frame)
            Addon:UpdateName(frame)
            Addon:UpdateFriendlyAbsorb(frame)
            Addon:UpdateHostileAbsorb(frame)
        end
    end
    
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then
                Addon:UpdateRoleIcon(frame)
                Addon:UpdateThreatIndicator(frame)
                Addon:UpdateAuraBorders(frame)
                Addon:UpdateIncomingHeals(frame)
                Addon:UpdateName(frame)
                Addon:UpdateFriendlyAbsorb(frame)
                Addon:UpdateHostileAbsorb(frame)
            end
        end
    end
end

function Addon:GetSetting(key)
    return BetterRaidFramesDB[key]
end

function Addon:SetSetting(key, value)
    BetterRaidFramesDB[key] = value
    self:UpdateAllFrames()
end

function Addon:SetTestMode(enabled)
    self.testMode = enabled
    if enabled then
        print("|cff00ff00BetterRaidFrames:|r Test mode |cff00ff00ENABLED|r")
    else
        print("|cff00ff00BetterRaidFrames:|r Test mode |cffff0000DISABLED|r")
    end
    self:UpdateAllFrames()
end

function Addon:ToggleTestMode()
    self:SetTestMode(not self.testMode)
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
    if msg == "test" then
        Addon:ToggleTestMode()
    else
        Addon:OpenConfig()
    end
end

_G["BetterRaidFrames"] = Addon
