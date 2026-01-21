local ADDON_NAME, Addon = ...

local ConfigFrame = nil

local SECTION_PADDING = 12
local HEADER_TO_CONTENT = 20

local function SetControlsEnabled(controls, enabled)
    local alpha = enabled and 1.0 or 0.5
    for _, control in ipairs(controls) do
        if control.SetEnabled then
            control:SetEnabled(enabled)
        end
        if control.SetAlpha then
            control:SetAlpha(alpha)
        end
        if control.EnableMouse then
            control:EnableMouse(enabled)
        end
    end
end

local function CreateDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 12, yOffset)
    divider:SetPoint("TOPRIGHT", -12, yOffset)
    divider:SetHeight(1)
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    return divider
end

local function CreateCheckbox(parent, label, settingKey, yOffset, onChange)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 16, yOffset)
    checkbox.Text:SetText(label)
    checkbox.Text:SetFontObject("GameFontHighlight")
    
    checkbox:SetChecked(Addon:GetSetting(settingKey))
    checkbox:SetScript("OnClick", function(self)
        Addon:SetSetting(settingKey, self:GetChecked())
        if onChange then
            onChange(self:GetChecked())
        end
    end)
    
    checkbox.settingKey = settingKey
    return checkbox
end

local function CreateDropdown(parent, label, settingKey, options, yOffset, onChange)
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 16, yOffset)
    labelText:SetText(label)
    
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", 16, yOffset - 18)
    dropdown:SetWidth(200)
    
    local function IsSelected(value)
        return Addon:GetSetting(settingKey) == value
    end
    
    local function SetSelected(value)
        Addon:SetSetting(settingKey, value)
        if onChange then onChange(value) end
        dropdown:GenerateMenu()
    end
    
    dropdown:SetupMenu(function(dropdown, rootDescription)
        for _, option in ipairs(options) do
            rootDescription:CreateRadio(option.label, IsSelected, SetSelected, option.value)
        end
    end)
    
    dropdown.settingKey = settingKey
    dropdown.label = labelText
    return dropdown
end

local function CreateSlider(parent, label, settingKey, minVal, maxVal, step, yOffset, onChange, showButtons)
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 32, yOffset)
    labelText:SetText(label)
    
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 32, yOffset - 28)
    slider:SetWidth(showButtons and 140 or 180)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    
    slider.Low:SetText(minVal)
    slider.High:SetText(maxVal)
    
    local currentValue = Addon:GetSetting(settingKey) or minVal
    slider:SetValue(currentValue)
    slider.Text:SetText(currentValue)
    
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        self.Text:SetText(value)
        Addon:SetSetting(settingKey, value)
        if onChange then onChange(value) end
    end)
    
    if showButtons then
        local minusBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        minusBtn:SetSize(22, 22)
        minusBtn:SetPoint("LEFT", slider, "RIGHT", 8, 0)
        minusBtn:SetText("-")
        minusBtn:SetScript("OnClick", function()
            local val = slider:GetValue() - step
            if val >= minVal then
                slider:SetValue(val)
            end
        end)
        slider.minusBtn = minusBtn
        
        local plusBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        plusBtn:SetSize(22, 22)
        plusBtn:SetPoint("LEFT", minusBtn, "RIGHT", 2, 0)
        plusBtn:SetText("+")
        plusBtn:SetScript("OnClick", function()
            local val = slider:GetValue() + step
            if val <= maxVal then
                slider:SetValue(val)
            end
        end)
        slider.plusBtn = plusBtn
    end
    
    slider.settingKey = settingKey
    slider.label = labelText
    return slider
end

local function CreateSubCheckbox(parent, label, settingKey, yOffset, onChange)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 32, yOffset)
    checkbox.Text:SetText(label)
    checkbox.Text:SetFontObject("GameFontHighlight")
    
    checkbox:SetChecked(Addon:GetSetting(settingKey))
    checkbox:SetScript("OnClick", function(self)
        Addon:SetSetting(settingKey, self:GetChecked())
        if onChange then onChange(self:GetChecked()) end
    end)
    
    checkbox.settingKey = settingKey
    return checkbox
end

local function CreateConfigFrame()
    local frame = CreateFrame("Frame", "BetterRaidFramesConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(320, 800)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    frame:SetScript("OnHide", function()
        if Addon.testMode then
            Addon:SetTestMode(false)
            print("|cff00ff00BetterRaidFrames:|r Test mode auto-disabled (config closed)")
        end
    end)
    
    frame.TitleText:SetText("BetterRaidFrames")
    
    local desc = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 16, -32)
    desc:SetWidth(288)
    desc:SetJustifyH("LEFT")
    desc:SetText("Customize default raid frames.")
    
    local y = -55
    
    -- Test Mode
    local testHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    testHeader:SetPoint("TOPLEFT", 16, y)
    testHeader:SetText("Test Mode")
    testHeader:SetTextColor(1, 0.82, 0)
    y = y - HEADER_TO_CONTENT
    
    local testCheckbox = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    testCheckbox:SetPoint("TOPLEFT", 16, y)
    testCheckbox.Text:SetText("Enable test mode")
    testCheckbox.Text:SetFontObject("GameFontHighlight")
    testCheckbox:SetChecked(Addon.testMode)
    testCheckbox:SetScript("OnClick", function(self)
        Addon:SetTestMode(self:GetChecked())
    end)
    frame.testCheckbox = testCheckbox
    y = y - 25 - SECTION_PADDING
    
    CreateDivider(frame, y)
    y = y - SECTION_PADDING
    
    -- Role Icons
    local roleHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    roleHeader:SetPoint("TOPLEFT", 16, y)
    roleHeader:SetText("Role Icons")
    roleHeader:SetTextColor(1, 0.82, 0)
    y = y - HEADER_TO_CONTENT
    
    local roleIconDropdown = CreateDropdown(
        frame, "Show role icons:", "showRoleIcons", Addon.RoleIconOptions, y
    )
    y = y - 55 - SECTION_PADDING
    
    CreateDivider(frame, y)
    y = y - SECTION_PADDING
    
    -- Name
    local nameHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameHeader:SetPoint("TOPLEFT", 16, y)
    nameHeader:SetText("Name")
    nameHeader:SetTextColor(1, 0.82, 0)
    y = y - HEADER_TO_CONTENT
    
    local customizeNamesCheckbox = CreateCheckbox(frame, "Customize names", "customizeNames", y, function(checked)
        UpdateNameOptionsEnabled(checked)
        Addon:RefreshNames()
    end)
    frame.customizeNamesCheckbox = customizeNamesCheckbox
    y = y - 25
    
    local nameOptionsContainer = {}
    
    local nameXSlider = CreateSlider(frame, "X Offset:", "nameX", -250, 250, 1, y, function() Addon:RefreshNames() end, true)
    table.insert(nameOptionsContainer, nameXSlider)
    table.insert(nameOptionsContainer, nameXSlider.label)
    if nameXSlider.minusBtn then table.insert(nameOptionsContainer, nameXSlider.minusBtn) end
    if nameXSlider.plusBtn then table.insert(nameOptionsContainer, nameXSlider.plusBtn) end
    y = y - 55
    
    local nameYSlider = CreateSlider(frame, "Y Offset:", "nameY", -250, 250, 1, y, function() Addon:RefreshNames() end, true)
    table.insert(nameOptionsContainer, nameYSlider)
    table.insert(nameOptionsContainer, nameYSlider.label)
    if nameYSlider.minusBtn then table.insert(nameOptionsContainer, nameYSlider.minusBtn) end
    if nameYSlider.plusBtn then table.insert(nameOptionsContainer, nameYSlider.plusBtn) end
    y = y - 55
    
    local hideServerCheckbox = CreateSubCheckbox(frame, "Hide server name", "nameHideServer", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, hideServerCheckbox)
    y = y - 25
    
    local truncateCheckbox = CreateSubCheckbox(frame, "Truncate long names", "nameTruncate", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, truncateCheckbox)
    y = y - 25
    
    local truncateSlider = CreateSlider(frame, "Max length:", "nameTruncateLength", 3, 12, 1, y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, truncateSlider)
    table.insert(nameOptionsContainer, truncateSlider.label)
    y = y - 55 - SECTION_PADDING
    
    local function UpdateNameOptionsEnabled(enabled)
        SetControlsEnabled(nameOptionsContainer, enabled)
    end
    frame.nameOptionsContainer = nameOptionsContainer
    UpdateNameOptionsEnabled(Addon:GetSetting("customizeNames"))
    
    CreateDivider(frame, y)
    y = y - SECTION_PADDING
    
    -- Absorbs
    local absorbHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    absorbHeader:SetPoint("TOPLEFT", 16, y)
    absorbHeader:SetText("Absorbs")
    absorbHeader:SetTextColor(1, 0.82, 0)
    y = y - HEADER_TO_CONTENT
    
    local friendlyAbsorbCheckbox = CreateCheckbox(frame, "Show friendly absorb (shields)", "showFriendlyAbsorb", y, function() Addon:RefreshFriendlyAbsorbs() end)
    y = y - 25
    
    local hostileAbsorbCheckbox = CreateCheckbox(frame, "Show hostile absorb (heal debuffs)", "showHostileAbsorb", y, function() Addon:RefreshHostileAbsorbs() end)
    y = y - 25
    
    local hideIncomingHealsCheckbox = CreateCheckbox(frame, "Hide incoming heal indicator", "hideIncomingHeals", y, function() Addon:RefreshIncomingHeals() end)
    y = y - 25 - SECTION_PADDING
    
    CreateDivider(frame, y)
    y = y - SECTION_PADDING
    
    -- Threat Indicator
    local threatHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    threatHeader:SetPoint("TOPLEFT", 16, y)
    threatHeader:SetText("Threat Indicator")
    threatHeader:SetTextColor(1, 0.82, 0)
    y = y - HEADER_TO_CONTENT
    
    local threatCheckbox = CreateCheckbox(frame, "Show blinking threat indicator", "showThreatIndicator", y, function(checked)
        UpdateThreatOptionsEnabled(checked)
        Addon:RefreshThreatIndicators()
    end)
    frame.threatCheckbox = threatCheckbox
    y = y - 25
    
    local threatOptionsContainer = {}
    
    local threatXSlider = CreateSlider(frame, "X Offset:", "threatIndicatorX", -250, 250, 1, y, function() Addon:RefreshThreatIndicators() end, true)
    table.insert(threatOptionsContainer, threatXSlider)
    table.insert(threatOptionsContainer, threatXSlider.label)
    if threatXSlider.minusBtn then table.insert(threatOptionsContainer, threatXSlider.minusBtn) end
    if threatXSlider.plusBtn then table.insert(threatOptionsContainer, threatXSlider.plusBtn) end
    y = y - 55
    
    local threatYSlider = CreateSlider(frame, "Y Offset:", "threatIndicatorY", -250, 250, 1, y, function() Addon:RefreshThreatIndicators() end, true)
    table.insert(threatOptionsContainer, threatYSlider)
    table.insert(threatOptionsContainer, threatYSlider.label)
    if threatYSlider.minusBtn then table.insert(threatOptionsContainer, threatYSlider.minusBtn) end
    if threatYSlider.plusBtn then table.insert(threatOptionsContainer, threatYSlider.plusBtn) end
    y = y - 55
    
    local threatSizeSlider = CreateSlider(frame, "Size:", "threatIndicatorSize", 4, 20, 1, y, function() Addon:RefreshThreatIndicators() end)
    table.insert(threatOptionsContainer, threatSizeSlider)
    table.insert(threatOptionsContainer, threatSizeSlider.label)
    y = y - 55 - SECTION_PADDING
    
    local function UpdateThreatOptionsEnabled(enabled)
        SetControlsEnabled(threatOptionsContainer, enabled)
    end
    frame.threatOptionsContainer = threatOptionsContainer
    UpdateThreatOptionsEnabled(Addon:GetSetting("showThreatIndicator"))
    
    CreateDivider(frame, y)
    y = y - SECTION_PADDING
    
    -- Auras
    local auraHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    auraHeader:SetPoint("TOPLEFT", 16, y)
    auraHeader:SetText("Auras")
    auraHeader:SetTextColor(1, 0.82, 0)
    y = y - HEADER_TO_CONTENT
    
    local auraBordersCheckbox = CreateCheckbox(frame, "Hide borders on buff/debuff icons", "hideAuraBorders", y, function() Addon:RefreshAuraBorders() end)
    y = y - 25 - SECTION_PADDING
    
    frame:SetSize(320, math.abs(y) + 30)
    
    return frame
end

function Addon:OpenConfig()
    if not ConfigFrame then
        ConfigFrame = CreateConfigFrame()
    end
    
    if ConfigFrame.testCheckbox then
        ConfigFrame.testCheckbox:SetChecked(self.testMode)
    end
    
    if ConfigFrame.nameOptionsContainer then
        SetControlsEnabled(ConfigFrame.nameOptionsContainer, self:GetSetting("customizeNames"))
    end
    if ConfigFrame.threatOptionsContainer then
        SetControlsEnabled(ConfigFrame.threatOptionsContainer, self:GetSetting("showThreatIndicator"))
    end
    
    if ConfigFrame:IsShown() then
        ConfigFrame:Hide()
    else
        ConfigFrame:Show()
    end
end
