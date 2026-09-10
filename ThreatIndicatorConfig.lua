local _, Addon = ...

local function Label(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    if width then label:SetWidth(width) end
    label:SetText(text)
    return label
end

local function Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 24)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

function Addon:BuildThreatOptions(content, y, ui)
    local Refresh
    local function Changed() if Refresh then Refresh() end end
    ui.checkbox(content, "Show threat indicator", "showThreatIndicator", y, Changed)
    ui.subCheckbox(content, "Blinking", "threatIndicatorBlink", y, 260, Changed)
    ui.subCheckbox(content, "Hide for tanks", "threatIndicatorHideForTanks", y, 390, Changed)

    local captions = {}
    for status, level in ipairs(self.ThreatLevels) do captions[status] = level.label end
    local previewRow = self:CreateFramePreviewRow(content, 3, 120, captions)
    previewRow:SetPoint("TOPLEFT", 24, y - 48); previewRow:SetPoint("TOPRIGHT", -24, y - 48)
    local samples = previewRow.samples
    for _, sample in ipairs(samples) do
        local health = sample:CreateTexture(nil, "BACKGROUND")
        health:SetAllPoints()
        health:SetColorTexture(0.12, 0.3, 0.25, 1)
    end

    local controls = CreateFrame("Frame", nil, content)
    controls:SetPoint("TOPLEFT", previewRow, "BOTTOMLEFT", -24, -24)
    controls:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    ui.dropdown(controls, "Visual:", "threatIndicatorShape", self.ThreatIndicatorShapeOptions, 0, Changed)
    local panels, buttons = {}, {}
    local selected = "Colours"
    for index, section in ipairs({ "Colours", "Placement", "Border" }) do
        local panel = CreateFrame("Frame", nil, controls)
        panel:SetPoint("TOPLEFT", 0, -76)
        panel:SetSize(650, 380)
        panels[section] = panel
        buttons[section] = Button(controls, section, 24 + (index - 1) * 124, -44, 116,
            function() selected = section; Refresh() end)
    end

    local colours = panels.Colours
    ui.subCheckbox(colours, "Color by threat", "threatIndicatorColorByThreat", 0, 24, Changed)
    for status, level in ipairs(self.ThreatLevels) do
        ui.colorPicker(colours, level.label .. ":", level.key .. "R", level.key .. "G", level.key .. "B",
            -36 * status, Changed)
    end
    Button(colours, "Reset colours", 24, -152, 132, function()
        if InCombatLockdown() then return end
        for _, level in ipairs(Addon.ThreatLevels) do
            for index, channel in ipairs({ "R", "G", "B" }) do Addon:SetSetting(level.key .. channel, level.color[index]) end
        end
        Addon:RefreshConfig()
    end)
    Label(colours, "Samples always show all three threat levels.\nWith Color by threat off, live threat uses the Secure threat colour.", 24, -200, 600)
    Label(colours, "Blizzard's separate aggro highlight can be disabled in\nOptions > Interface > Raid Frames > Display Aggro Highlight.", 24, -252, 600)

    local placement = panels.Placement
    local placementControls = {}
    local function Place(control)
        placementControls[#placementControls + 1] = control.container or control
    end
    Place(ui.dropdown(placement, "Position:", "threatIndicatorPoint", self.AnchorOptions, 0, Changed))
    Place(ui.slider(placement, "X offset (px):", "threatIndicatorOffsetX", -250, 250, 1, -36, Changed))
    Place(ui.slider(placement, "Y offset (px):", "threatIndicatorOffsetY", -250, 250, 1, -72, Changed))
    Place(ui.slider(placement, "Size (px):", "threatIndicatorSize", 4, 20, 1, -108, Changed))
    local placementNote = Label(placement, "", 24, -170, 600)

    local border = panels.Border
    local borderStyle = ui.dropdown(border, "Style:", "threatIndicatorBorderStyle", self.ThreatBorderStyleOptions, 0, Changed)
    local thickness = ui.slider(border, "Thickness (px):", "threatIndicatorBorderSize", 1, 16, 1, -40, Changed)
    local glowSize = ui.slider(border, "Glow width (px):", "threatIndicatorGlowSize", 1, 32, 1, -40, Changed)
    ui.slider(border, "Opacity (%):", "threatIndicatorBorderOpacity", 0, 100, 1, -80, Changed)
    local inset = ui.slider(border, "Inset (px):", "threatIndicatorBorderInset", -16, 16, 1, -120, Changed)
    local borderColor = ui.colorPicker(border, "Outline colour:", "threatIndicatorBorderColorR",
        "threatIndicatorBorderColorG", "threatIndicatorBorderColorB", -120, Changed)
    local borderNote = Label(border, "", 24, -164, 610)

    Refresh = function()
        previewRow:RefreshSize()
        local settings = Addon:GetSettings()
        local fullFrame = settings.threatIndicatorShape == "BORDER"
        local glow = fullFrame and settings.threatIndicatorBorderStyle == "GLOW"
        for section, panel in pairs(panels) do
            panel:SetShown(selected == section)
            buttons[section]:SetEnabled(selected ~= section)
        end
        for _, control in ipairs(placementControls) do control:SetShown(not fullFrame) end
        placementNote:SetText(fullFrame and "Frame border follows the entire unit frame and resizes with it."
            or "Offsets start at the selected position. +X moves right; +Y moves up.")
        borderColor:SetShown(not fullFrame)
        borderStyle.container:SetShown(fullFrame)
        thickness.container:SetShown(not glow)
        glowSize.container:SetShown(glow)
        inset.container:SetShown(fullFrame)
        borderNote:SetText(fullFrame and "Border uses the three threat colours.\nPositive inset moves inward; negative inset moves outward.\nOpacity sets its maximum brightness when blinking."
            or "Solid outline follows the indicator's shape.\nOpacity affects the outline; the indicator fill stays opaque.")
        for status, sample in ipairs(samples) do
            Addon:UpdateThreatPreview(sample, settings, status, Addon:IsThreatPreviewOpen() and content:IsVisible())
        end
    end
    previewRow.RefreshOptions = Refresh
    content:HookScript("OnShow", Refresh)
    content:HookScript("OnHide", function()
        for status, sample in ipairs(samples) do Addon:UpdateThreatPreview(sample, Addon:GetSettings(), status, false) end
    end)
    Refresh()
    return Refresh
end
