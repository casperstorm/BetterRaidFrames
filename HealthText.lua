local ADDON_NAME, Addon = ...

local function GetFrameDefaultFont(statusText)
    if not statusText then return nil, nil, nil end

    local fontObject = statusText:GetFontObject()
    if fontObject then
        local fontPath, fontSize, fontFlags = fontObject:GetFont()
        if fontPath then
            return fontPath, fontSize, fontFlags
        end
    end

    return statusText:GetFont()
end

local function GetClassColor(unit)
    if not unit then return nil end
    local _, className = UnitClass(unit)
    if className then
        local color = C_ClassColor.GetClassColor(className)
        if color then
            return color.r, color.g, color.b
        end
    end
    return nil
end

local function ApplyHealthText(frame)
    if not frame or not frame.statusText then return end

    local statusText = frame.statusText
    local offsetX = Addon:GetSetting("healthTextX") or 0
    local offsetY = Addon:GetSetting("healthTextY") or 0
    local fontSize = Addon:GetSetting("healthTextSize") or 11
    local outline = Addon:GetSetting("healthTextOutline") or "NONE"
    local flags = outline ~= "NONE" and outline or ""

    local fontPath = select(1, GetFrameDefaultFont(statusText))

    statusText:ClearAllPoints()
    statusText:SetPoint("CENTER", frame, "CENTER", offsetX, offsetY)
    statusText:SetJustifyH("CENTER")

    if fontPath then
        statusText:SetFont(fontPath, fontSize, flags)
    end

    local textR = Addon:GetSetting("healthTextColorR") or 1
    local textG = Addon:GetSetting("healthTextColorG") or 1
    local textB = Addon:GetSetting("healthTextColorB") or 1
    if Addon:GetSetting("healthTextClassColor") then
        local cr, cg, cb = GetClassColor(frame.unit)
        if cr and cg and cb then
            textR, textG, textB = cr, cg, cb
        end
    end
    statusText:SetTextColor(textR, textG, textB, 1)

    if Addon:GetSetting("healthTextShadow") then
        local sr = Addon:GetSetting("healthTextShadowColorR") or 0
        local sg = Addon:GetSetting("healthTextShadowColorG") or 0
        local sb = Addon:GetSetting("healthTextShadowColorB") or 0
        local shadowOffset = Addon:GetSetting("healthTextShadowOffset") or 1
        statusText:SetShadowColor(sr, sg, sb, 1)
        statusText:SetShadowOffset(shadowOffset, -shadowOffset)
    else
        statusText:SetShadowOffset(0, 0)
    end
end

local function UpdateHealthText(frame)
    if not frame or not frame.statusText then return end
    ApplyHealthText(frame)
end

function Addon:HookHealthText()
    hooksecurefunc("CompactUnitFrame_UpdateStatusText", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        if Addon:IsEditModeActive() then return end
        UpdateHealthText(frame)
    end)

    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        if Addon:IsEditModeActive() then return end
        UpdateHealthText(frame)
    end)
end

function Addon:UpdateHealthText(frame)
    UpdateHealthText(frame)
end

function Addon:RefreshHealthTexts()
    Addon:ForEachFrame(UpdateHealthText)
end
