local _, Addon = ...
local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitThreatSituation = UnitThreatSituation
local hooksecurefunc = hooksecurefunc

local BLINK_DURATION = 0.5
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

Addon.ThreatIndicatorShapeOptions = {
    { value = "SQUARE", label = "Square" },
    { value = "CIRCLE", label = "Circle" },
}

local validShapes = {}
for _, option in ipairs(Addon.ThreatIndicatorShapeOptions) do
    validShapes[option.value] = true
end

local function GetShape(settings)
    local shape = settings.threatIndicatorShape
    if validShapes[shape] then
        return shape
    end
    return "SQUARE"
end

local function SetIndicatorShape(indicator, shape)
    if indicator.BRFShape == shape then return end

    if shape == "CIRCLE" then
        if not indicator.BRFCircleMasks then
            local borderMask = indicator:CreateMaskTexture()
            borderMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            borderMask:SetAllPoints(indicator.border)

            local fillMask = indicator:CreateMaskTexture()
            fillMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            fillMask:SetAllPoints(indicator.texture)

            indicator.BRFCircleMasks = {
                border = borderMask,
                fill = fillMask,
            }
        end

        indicator.border:AddMaskTexture(indicator.BRFCircleMasks.border)
        indicator.texture:AddMaskTexture(indicator.BRFCircleMasks.fill)
    elseif indicator.BRFCircleMasks then
        indicator.border:RemoveMaskTexture(indicator.BRFCircleMasks.border)
        indicator.texture:RemoveMaskTexture(indicator.BRFCircleMasks.fill)
    end

    indicator.BRFShape = shape
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
    indicator.SetBRFShape = SetIndicatorShape
    frame.BRFThreatIndicator = indicator
    return indicator
end

local function ApplyIndicatorSettings(indicator, parentFrame, settings)
    local point = Addon:GetValidAnchor(settings.threatIndicatorPoint, "CENTER")
    local relativePoint = Addon:GetValidAnchor(settings.threatIndicatorRelativePoint, "CENTER")
    local offsetX = settings.threatIndicatorOffsetX or 0
    local offsetY = settings.threatIndicatorOffsetY or 0
    local size = settings.threatIndicatorSize or 8

    indicator:SetBRFShape(GetShape(settings))
    Addon:ApplyRegionLayout(indicator, parentFrame, point, relativePoint, offsetX, offsetY, size)
end

local function SetIndicatorVisible(indicator, visible, shouldBlink)
    if not visible then
        if indicator.animGroup:IsPlaying() then
            indicator.animGroup:Stop()
            indicator:SetAlpha(1)
        end
        if indicator:IsShown() then indicator:Hide() end
        return
    end

    if not indicator:IsShown() then indicator:Show() end
    if shouldBlink then
        if not indicator.animGroup:IsPlaying() then
            indicator:SetAlpha(1)
            indicator.animGroup:Play()
        end
    elseif indicator.animGroup:IsPlaying() then
        indicator.animGroup:Stop()
        indicator:SetAlpha(1)
    end
end

local function UpdateThreatIndicator(frame, settings, configOpen)
    if not frame then return end
    settings = settings or Addon:GetSettings()

    if not settings.showThreatIndicator then
        if frame.BRFThreatIndicator then
            SetIndicatorVisible(frame.BRFThreatIndicator, false, false)
        end
        return
    end

    local unit = frame.displayedUnit or frame.unit
    if not unit or not UnitExists(unit) then
        if frame.BRFThreatIndicator then SetIndicatorVisible(frame.BRFThreatIndicator, false, false) end
        return
    end

    local indicator = GetOrCreateThreatIndicator(frame)
    ApplyIndicatorSettings(indicator, frame, settings)

    local visible = configOpen
    if visible == nil then visible = Addon:IsConfigOpen() end
    if not visible then
        local status = UnitThreatSituation(unit)
        visible = status ~= nil and status >= 1
    end

    SetIndicatorVisible(indicator, visible, settings.threatIndicatorBlink)
end

function Addon:HookThreatIndicator()
    hooksecurefunc("CompactUnitFrame_UpdateAggroHighlight", function(frame)
        if Addon:IsEditModeActive() or not Addon:IsRaidOrPartyFrame(frame) then return end
        UpdateThreatIndicator(frame)
    end)
end

function Addon:UpdateThreatIndicator(frame, settings, configOpen)
    UpdateThreatIndicator(frame, settings, configOpen)
end
