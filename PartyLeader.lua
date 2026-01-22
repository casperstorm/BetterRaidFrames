local ADDON_NAME, Addon = ...

local function GetOrCreateLeaderIndicator(frame)
    if frame.BRFLeaderIndicator then
        return frame.BRFLeaderIndicator
    end
    
    local indicator = frame:CreateTexture(nil, "OVERLAY")
    indicator:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    indicator:Hide()
    
    frame.BRFLeaderIndicator = indicator
    return indicator
end

local function ApplyLeaderIndicatorSettings(indicator, parentFrame)
    local offsetX = Addon:GetSetting("partyLeaderX") or 2
    local offsetY = Addon:GetSetting("partyLeaderY") or -2
    local size = Addon:GetSetting("partyLeaderSize") or 16
    
    indicator:SetSize(size, size)
    indicator:ClearAllPoints()
    indicator:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", offsetX, offsetY)
end

local function UpdatePartyLeader(frame)
    if not frame or not frame.unit then return end
    if not UnitExists(frame.unit) then return end
    
    if not Addon:GetSetting("showPartyLeader") then
        if frame.BRFLeaderIndicator then
            frame.BRFLeaderIndicator:Hide()
        end
        return
    end
    
    local unit = frame.unit
    local indicator = GetOrCreateLeaderIndicator(frame)
    ApplyLeaderIndicatorSettings(indicator, frame)
    
    local hideInCombat = Addon:GetSetting("partyLeaderHideInCombat")
    local inCombat = UnitAffectingCombat("player")
    
    -- Safely check if unit is group leader
    local isLeader = UnitExists(unit) and UnitIsGroupLeader(unit)
    
    if isLeader and not (hideInCombat and inCombat) then
        indicator:Show()
    else
        indicator:Hide()
    end
end

function Addon:HookPartyLeader()
    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        UpdatePartyLeader(frame)
    end)
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function()
        Addon:RefreshPartyLeaders()
    end)
end

function Addon:UpdatePartyLeader(frame)
    UpdatePartyLeader(frame)
end

function Addon:RefreshPartyLeaders()
    Addon:ForEachFrame(function(frame)
        if frame.BRFLeaderIndicator then
            ApplyLeaderIndicatorSettings(frame.BRFLeaderIndicator, frame)
        end
        UpdatePartyLeader(frame)
    end)
end
