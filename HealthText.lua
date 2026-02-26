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

local function ApplyBlizzardDefaultHealthText(frame)
    if not frame or not frame.statusText then return end

    local statusText = frame.statusText
    local fontPath, fontSize, fontFlags = GetFrameDefaultFont(statusText)

    statusText:Show()
    statusText:ClearAllPoints()
    if frame.healthBar then
        statusText:SetPoint("CENTER", frame.healthBar, "CENTER", 0, 0)
    else
        statusText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end
    statusText:SetJustifyH("CENTER")

    if fontPath then
        statusText:SetFont(fontPath, fontSize or 12, fontFlags or "")
    end

    statusText:SetTextColor(1, 1, 1, 1)
    statusText:SetShadowColor(0, 0, 0, 1)
    statusText:SetShadowOffset(0, 0)
end

local function ApplyCustomHealthText(frame)
    if not frame or not frame.statusText then return end

    local statusText = frame.statusText
    local offsetX = Addon:GetSetting("healthTextX") or 0
    local offsetY = Addon:GetSetting("healthTextY") or 0
    local fontSize = Addon:GetSetting("healthTextSize") or 11
    local outline = Addon:GetSetting("healthTextOutline") or "NONE"
    local flags = outline ~= "NONE" and outline or ""

    local fontPath = select(1, GetFrameDefaultFont(statusText))

    statusText:Show()
    statusText:ClearAllPoints()
    statusText:SetPoint("CENTER", frame, "CENTER", offsetX, offsetY)
    statusText:SetJustifyH("CENTER")

    if fontPath then
        statusText:SetFont(fontPath, fontSize, flags)
    end

    local textR = Addon:GetSetting("healthTextColorR") or 1
    local textG = Addon:GetSetting("healthTextColorG") or 1
    local textB = Addon:GetSetting("healthTextColorB") or 1
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

    if Addon:GetSetting("customizeHealthText") then
        ApplyCustomHealthText(frame)
    else
        ApplyBlizzardDefaultHealthText(frame)
    end
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
