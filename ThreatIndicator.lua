local _, Addon = ...
local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitThreatSituation = UnitThreatSituation
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local hooksecurefunc = hooksecurefunc

local BLINK_DURATION = 0.5
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

Addon.ThreatIndicatorShapeOptions = {
    { value = "SQUARE", label = "Square" },
    { value = "CIRCLE", label = "Circle" },
    { value = "BORDER", label = "Frame border" },
}

Addon.ThreatLevels = {
    { label = "High threat", key = "threatIndicatorHighColor", color = { 1, 1, 0 } },
    { label = "Insecure threat", key = "threatIndicatorInsecureColor", color = { 1, 0.6, 0 } },
    { label = "Secure threat", key = "threatIndicatorSecureColor", color = { 1, 0, 0 } },
}

function Addon:GetThreatIndicatorColor(settings, status)
    local level = self.ThreatLevels[status] or self.ThreatLevels[3]
    return settings[level.key .. "R"] or level.color[1], settings[level.key .. "G"] or level.color[2],
        settings[level.key .. "B"] or level.color[3]
end

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
    indicator:EnableMouse(false)

    local border = indicator:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    indicator.border = border

    local texture = indicator:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(1, 0, 0, 1)
    indicator.texture = texture

    indicator.edge = CreateFrame("Frame", nil, indicator, "BackdropTemplate")
    indicator.edge:EnableMouse(false)

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
    local offsetX = settings.threatIndicatorOffsetX or 0
    local offsetY = settings.threatIndicatorOffsetY or 0
    local size = settings.threatIndicatorSize or 8

    local shape = GetShape(settings)
    if indicator.BRFShape ~= shape then
        indicator.BRFPoint, indicator.BRFSize = nil, nil
        indicator:ClearAllPoints()
        if shape == "BORDER" then indicator:SetAllPoints(parentFrame) end
    end
    indicator:SetBRFShape(shape)
    indicator.texture:SetShown(shape ~= "BORDER")
    if shape ~= "BORDER" then
        Addon:ApplyRegionLayout(indicator, parentFrame, point, point, offsetX, offsetY, size)
    end
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

local function HideThreatIndicator(frame)
    if frame.BRFThreatIndicator then
        SetIndicatorVisible(frame.BRFThreatIndicator, false, false)
    end
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function DisplayThreat(frame, settings, status, preview)
    local indicator = GetOrCreateThreatIndicator(frame)
    ApplyIndicatorSettings(indicator, frame, settings)
    local colorStatus = (preview or settings.threatIndicatorColorByThreat) and status or 3
    local r, g, b = Addon:GetThreatIndicatorColor(settings, colorStatus)
    indicator.texture:SetColorTexture(r, g, b, 1)
    Addon:StyleThreatBorder(indicator, settings, GetShape(settings) == "BORDER", r, g, b)
    SetIndicatorVisible(indicator, true, settings.threatIndicatorBlink)
end

-- The three configuration samples use the same visual as the live frames,
-- without querying a real unit or requiring a party to exist.
function Addon:UpdateThreatPreview(frame, settings, status, visible)
    if visible then DisplayThreat(frame, settings, status, true)
    else HideThreatIndicator(frame) end
end

local function UpdateThreatIndicator(frame, settings, previewOpen)
    if not frame then return end
    settings = settings or Addon:GetSettings()

    if not settings.showThreatIndicator then
        HideThreatIndicator(frame)
        return
    end

    local unit = frame.displayedUnit
    if IsSecret(unit) then HideThreatIndicator(frame); return end
    unit = unit or frame.unit
    if IsSecret(unit) or not unit then HideThreatIndicator(frame); return end
    local exists = UnitExists(unit)
    if IsSecret(exists) or not exists then HideThreatIndicator(frame); return end

    if settings.threatIndicatorHideForTanks then
        -- A vehicle uses its owner's assigned role, not the vehicle's role.
        local roleUnit = frame.unit
        if IsSecret(roleUnit) then HideThreatIndicator(frame); return end
        local role = UnitGroupRolesAssigned(roleUnit or unit)
        if IsSecret(role) or role == "TANK" then HideThreatIndicator(frame); return end
    end

    local status = UnitThreatSituation(unit)
    -- Restricted threat states cannot be compared or used as colour indices.
    if IsSecret(status) then HideThreatIndicator(frame); return end
    if previewOpen == nil then previewOpen = Addon:IsThreatPreviewOpen() end
    local preview = false
    if status == nil or status < 1 then
        if not previewOpen then HideThreatIndicator(frame); return end
        -- Spread samples across the group instead of making every frame red.
        status = ((tonumber(unit:match("(%d+)$")) or 0) % 3) + 1
        preview = true
    end

    DisplayThreat(frame, settings, status, preview)
end

function Addon:HookThreatIndicator()
    local function Update(frame)
        if not frame or Addon:IsEditModeActive() or not Addon:IsRaidOrPartyFrame(frame) then return end
        UpdateThreatIndicator(frame)
    end
    hooksecurefunc("CompactUnitFrame_UpdateAggroHighlight", Update)
    hooksecurefunc("CompactUnitFrame_UpdateRoleIcon", Update)
    hooksecurefunc("CompactUnitFrame_SetUnit", Update)
end

function Addon:UpdateThreatIndicator(frame, settings, previewOpen)
    UpdateThreatIndicator(frame, settings, previewOpen)
end
