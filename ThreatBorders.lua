local _, Addon = ...

Addon.ThreatBorderStyleOptions = {
    { value = "SOLID", label = "Solid" },
    { value = "GLOW", label = "Glow" },
}

local function Number(value, min, max, fallback)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return math.max(min, math.min(max, value))
end

function Addon:StyleThreatBorder(indicator, settings, fullFrame, r, g, b)
    local glow = fullFrame and settings.threatIndicatorBorderStyle == "GLOW" or false
    local size = glow and Number(settings.threatIndicatorGlowSize, 1, 32, 8)
        or Number(settings.threatIndicatorBorderSize, 1, 16, 1)
    local alpha = Number(settings.threatIndicatorBorderOpacity, 0, 100, 100) / 100
    local inset = fullFrame and Number(settings.threatIndicatorBorderInset, -16, 16, 0) or 0
    local edge = indicator.edge
    if indicator.BRFBorderSize ~= size or indicator.BRFBorderInset ~= inset
        or indicator.BRFBorderFull ~= fullFrame or indicator.BRFBorderGlow ~= glow then
        indicator.border:SetShown(not fullFrame)
        edge:SetShown(fullFrame)
        if fullFrame then
            edge:ClearAllPoints()
            edge:SetPoint("TOPLEFT", indicator, "TOPLEFT", inset, -inset)
            edge:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -inset, inset)
            -- Reuse the same backdrop pieces and the indicator's existing blink animation.
            edge:SetBackdrop({ edgeFile = glow and "Interface\\TutorialFrame\\UI-TutorialFrame-CalloutGlow"
                or "Interface\\Buttons\\WHITE8X8", edgeSize = size, tileEdge = true })
            edge:SetBorderBlendMode(glow and "ADD" or "BLEND")
        else
            indicator.border:ClearAllPoints()
            indicator.border:SetPoint("TOPLEFT", indicator, "TOPLEFT", -size, size)
            indicator.border:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", size, -size)
        end
        indicator.BRFBorderSize, indicator.BRFBorderInset, indicator.BRFBorderFull = size, inset, fullFrame
        indicator.BRFBorderGlow = glow
    end
    if fullFrame then
        edge:SetBackdropBorderColor(r, g, b, alpha)
    else
        indicator.border:SetColorTexture(settings.threatIndicatorBorderColorR or 0,
            settings.threatIndicatorBorderColorG or 0, settings.threatIndicatorBorderColorB or 0, alpha)
    end
end
