local _, Addon = ...
local CreateFrame = CreateFrame
local UnitAffectingCombat = UnitAffectingCombat
local UnitExists = UnitExists
local UnitIsGroupLeader = UnitIsGroupLeader

local partyLeaderHooked = false

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

local function ApplyLeaderIndicatorSettings(indicator, parentFrame, settings)
    local point = Addon:GetValidAnchor(settings.partyLeaderPoint, "TOPLEFT")
    local offsetX = settings.partyLeaderOffsetX or 2
    local offsetY = settings.partyLeaderOffsetY or -2
    local size = settings.partyLeaderSize or 16

    Addon:ApplyRegionLayout(indicator, parentFrame, point, point, offsetX, offsetY, size)
end

local function UpdatePartyLeader(frame, settings, inCombat)
    if not frame then return end
    settings = settings or Addon:GetSettings()

    if not settings.showPartyLeader then
        if frame.BRFLeaderIndicator and frame.BRFLeaderIndicator:IsShown() then
            frame.BRFLeaderIndicator:Hide()
        end
        return
    end

    local unit = frame.displayedUnit or frame.unit
    if not unit or not UnitExists(unit) then
        if frame.BRFLeaderIndicator and frame.BRFLeaderIndicator:IsShown() then
            frame.BRFLeaderIndicator:Hide()
        end
        return
    end

    local indicator = GetOrCreateLeaderIndicator(frame)
    ApplyLeaderIndicatorSettings(indicator, frame, settings)

    if inCombat == nil then inCombat = UnitAffectingCombat("player") end
    
    local isLeader = UnitIsGroupLeader(unit)

    if isLeader and not (settings.partyLeaderHideInCombat and inCombat) then
        if not indicator:IsShown() then indicator:Show() end
    elseif indicator:IsShown() then
        indicator:Hide()
    end
end

function Addon:HookPartyLeader()
    if partyLeaderHooked then return end
    partyLeaderHooked = true

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function()
        Addon:RequestFeatureUpdate("partyLeader")
    end)
end

function Addon:UpdatePartyLeader(frame, settings, inCombat)
    UpdatePartyLeader(frame, settings, inCombat)
end

function Addon:UpdatePartyLeaderPreview(frame, settings)
    if not frame:IsVisible() then return end
    if not settings.showPartyLeader or (settings.partyLeaderHideInCombat and UnitAffectingCombat("player")) then
        if frame.BRFLeaderIndicator then frame.BRFLeaderIndicator:Hide() end
        return
    end
    -- The example always represents a leader, including while playing solo.
    local indicator = GetOrCreateLeaderIndicator(frame)
    ApplyLeaderIndicatorSettings(indicator, frame, settings)
    indicator:Show()
end
