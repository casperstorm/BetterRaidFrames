local ADDON_NAME, Addon = ...

local BLINK_DURATION = 0.5

local function IsRaidOrPartyFrame(frame)
    if not frame or not frame.unit then return false end
    local unit = frame.unit
    return unit == "player" or 
           string.match(unit, "^party%d") or 
           string.match(unit, "^raid%d")
end

local function GetOrCreateThreatIndicator(frame)
    if frame.BRFThreatIndicator then
        return frame.BRFThreatIndicator
    end
    
    local indicator = CreateFrame("Frame", nil, frame)
    indicator:SetFrameLevel(frame:GetFrameLevel() + 10)
    
    local border = indicator:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    indicator.border = border
    
    local texture = indicator:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(1, 0, 0, 1)
    indicator.texture = texture
    
    local animGroup = indicator:CreateAnimationGroup()
    animGroup:SetLooping("REPEAT")
    
    local fadeOut = animGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.2)
    fadeOut:SetDuration(BLINK_DURATION)
    fadeOut:SetOrder(1)
    fadeOut:SetSmoothing("IN_OUT")
    
    local fadeIn = animGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.2)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(BLINK_DURATION)
    fadeIn:SetOrder(2)
    fadeIn:SetSmoothing("IN_OUT")
    
    indicator.animGroup = animGroup
    frame.BRFThreatIndicator = indicator
    return indicator
end

local function ApplyIndicatorSettings(indicator, parentFrame)
    local offsetX = Addon:GetSetting("threatIndicatorX") or 0
    local offsetY = Addon:GetSetting("threatIndicatorY") or 0
    local size = Addon:GetSetting("threatIndicatorSize") or 8

    indicator:SetSize(size, size)
    indicator:ClearAllPoints()
    indicator:SetPoint("CENTER", parentFrame, "CENTER", offsetX, offsetY)
end

local function UpdateThreatIndicator(frame)
    if not frame or not frame.unit then return end

    local indicator = GetOrCreateThreatIndicator(frame)

    if not Addon:GetSetting("showThreatIndicator") then
        indicator:Hide()
        indicator.animGroup:Stop()
        return
    end

    ApplyIndicatorSettings(indicator, frame)

    local shouldBlink = Addon:GetSetting("threatIndicatorBlink")

    if Addon:IsConfigOpen() then
        indicator:Show()
        if shouldBlink then
            if not indicator.animGroup:IsPlaying() then
                indicator.animGroup:Play()
            end
        else
            indicator.animGroup:Stop()
            indicator:SetAlpha(1)
        end
        return
    end

    local status = UnitThreatSituation(frame.unit)
    if status and status >= 1 then
        indicator:Show()
        if shouldBlink then
            if not indicator.animGroup:IsPlaying() then
                indicator.animGroup:Play()
            end
        else
            indicator.animGroup:Stop()
            indicator:SetAlpha(1)
        end
    else
        indicator:Hide()
        indicator.animGroup:Stop()
    end
end

function Addon:HookThreatIndicator()
    hooksecurefunc("CompactUnitFrame_UpdateAggroHighlight", function(frame)
        if not IsRaidOrPartyFrame(frame) then return end
        
        if Addon:GetSetting("showThreatIndicator") then
            if frame.aggroHighlight and frame.aggroHighlight.Hide then
                frame.aggroHighlight:Hide()
            end
            UpdateThreatIndicator(frame)
        else
            if frame.BRFThreatIndicator then
                frame.BRFThreatIndicator:Hide()
                frame.BRFThreatIndicator.animGroup:Stop()
            end
        end
    end)
end

function Addon:UpdateThreatIndicator(frame)
    UpdateThreatIndicator(frame)
end

function Addon:RefreshThreatIndicators()
    Addon:ForEachFrame(function(frame)
        if frame.BRFThreatIndicator then
            ApplyIndicatorSettings(frame.BRFThreatIndicator, frame)
        end
        UpdateThreatIndicator(frame)
    end)
end
