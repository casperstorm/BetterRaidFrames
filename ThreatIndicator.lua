local ADDON_NAME, Addon = ...

local BLINK_DURATION = 0.5

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
    local db = BetterRaidFramesDB
    local offsetX = db.threatIndicatorX or 0
    local offsetY = db.threatIndicatorY or 0
    local size = db.threatIndicatorSize or 8
    
    indicator:SetSize(size, size)
    indicator:ClearAllPoints()
    indicator:SetPoint("CENTER", parentFrame, "CENTER", offsetX, offsetY)
end

local function UpdateThreatIndicator(frame)
    if not frame or not frame.unit then return end
    
    local indicator = GetOrCreateThreatIndicator(frame)
    
    if not BetterRaidFramesDB.showThreatIndicator then
        indicator:Hide()
        indicator.animGroup:Stop()
        return
    end
    
    ApplyIndicatorSettings(indicator, frame)
    
    if Addon.testMode then
        indicator:Show()
        if not indicator.animGroup:IsPlaying() then
            indicator.animGroup:Play()
        end
        return
    end
    
    local status = UnitThreatSituation(frame.unit)
    if status and status >= 1 then
        indicator:Show()
        if not indicator.animGroup:IsPlaying() then
            indicator.animGroup:Play()
        end
    else
        indicator:Hide()
        indicator.animGroup:Stop()
    end
end

function Addon:HookThreatIndicator()
    hooksecurefunc("CompactUnitFrame_UpdateAggroHighlight", function(frame)
        if not frame or not frame.unit then return end
        
        if BetterRaidFramesDB.showThreatIndicator then
            if frame.aggroHighlight then
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
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then
            if frame.BRFThreatIndicator then
                ApplyIndicatorSettings(frame.BRFThreatIndicator, frame)
            end
            UpdateThreatIndicator(frame)
        end
    end
    
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then
            if frame.BRFThreatIndicator then
                ApplyIndicatorSettings(frame.BRFThreatIndicator, frame)
            end
            UpdateThreatIndicator(frame)
        end
    end
    
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then
                if frame.BRFThreatIndicator then
                    ApplyIndicatorSettings(frame.BRFThreatIndicator, frame)
                end
                UpdateThreatIndicator(frame)
            end
        end
    end
end
