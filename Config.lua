local ADDON_NAME, Addon = ...

-- Config frame
local ConfigFrame = nil

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
    -- Label
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 16, yOffset)
    labelText:SetText(label)
    
    -- Dropdown button
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", 16, yOffset - 18)
    dropdown:SetWidth(200)
    
    local function IsSelected(value)
        return Addon:GetSetting(settingKey) == value
    end
    
    local function SetSelected(value)
        Addon:SetSetting(settingKey, value)
        if onChange then
            onChange(value)
        end
        dropdown:GenerateMenu()
    end
    
    dropdown:SetupMenu(function(dropdown, rootDescription)
        for _, option in ipairs(options) do
            rootDescription:CreateRadio(option.label, IsSelected, SetSelected, option.value)
        end
    end)
    
    dropdown.settingKey = settingKey
    return dropdown
end

local function CreateSlider(parent, label, settingKey, minVal, maxVal, step, yOffset, onChange)
    -- Label
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 16, yOffset)
    labelText:SetText(label)
    
    -- Slider
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 16, yOffset - 28)
    slider:SetWidth(200)
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
        if onChange then
            onChange(value)
        end
    end)
    
    slider.settingKey = settingKey
    return slider
end

local function CreateColorPicker(parent, label, settingKey, yOffset, onChange)
    -- Label
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 16, yOffset)
    labelText:SetText(label)
    
    -- Color swatch button
    local colorButton = CreateFrame("Button", nil, parent)
    colorButton:SetPoint("TOPLEFT", 16, yOffset - 18)
    colorButton:SetSize(24, 24)
    
    -- Border
    local border = colorButton:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local innerBorder = colorButton:CreateTexture(nil, "OVERLAY", nil, 1)
    innerBorder:SetPoint("TOPLEFT", 1, -1)
    innerBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    innerBorder:SetColorTexture(0, 0, 0, 1)
    
    local innerSwatch = colorButton:CreateTexture(nil, "OVERLAY", nil, 2)
    innerSwatch:SetPoint("TOPLEFT", 2, -2)
    innerSwatch:SetPoint("BOTTOMRIGHT", -2, 2)
    colorButton.innerSwatch = innerSwatch
    
    -- Update the color display
    local function UpdateColorSwatch()
        local color = Addon:GetSetting(settingKey) or { r = 1, g = 0, b = 0, a = 1 }
        colorButton.innerSwatch:SetColorTexture(color.r, color.g, color.b, color.a)
    end
    
    UpdateColorSwatch()
    colorButton.UpdateColorSwatch = UpdateColorSwatch
    
    -- Color label showing hex value
    local hexLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hexLabel:SetPoint("LEFT", colorButton, "RIGHT", 8, 0)
    colorButton.hexLabel = hexLabel
    
    local function UpdateHexLabel()
        local color = Addon:GetSetting(settingKey) or { r = 1, g = 0, b = 0, a = 1 }
        local hex = string.format("#%02X%02X%02X", 
            math.floor(color.r * 255), 
            math.floor(color.g * 255), 
            math.floor(color.b * 255))
        hexLabel:SetText(hex)
    end
    
    UpdateHexLabel()
    colorButton.UpdateHexLabel = UpdateHexLabel
    
    -- Click handler to open color picker
    colorButton:SetScript("OnClick", function()
        local color = Addon:GetSetting(settingKey) or { r = 1, g = 0, b = 0, a = 1 }
        
        local info = {
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                Addon:SetSetting(settingKey, { r = r, g = g, b = b, a = a })
                UpdateColorSwatch()
                UpdateHexLabel()
                if onChange then
                    onChange()
                end
            end,
            hasOpacity = true,
            opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                Addon:SetSetting(settingKey, { r = r, g = g, b = b, a = a })
                UpdateColorSwatch()
                UpdateHexLabel()
                if onChange then
                    onChange()
                end
            end,
            cancelFunc = function(previousValues)
                Addon:SetSetting(settingKey, {
                    r = previousValues.r,
                    g = previousValues.g,
                    b = previousValues.b,
                    a = previousValues.a or 1
                })
                UpdateColorSwatch()
                UpdateHexLabel()
                if onChange then
                    onChange()
                end
            end,
            r = color.r,
            g = color.g,
            b = color.b,
            opacity = color.a,
        }
        
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    
    -- Highlight on hover
    colorButton:SetScript("OnEnter", function(self)
        self.innerSwatch:SetAlpha(0.8)
    end)
    
    colorButton:SetScript("OnLeave", function(self)
        self.innerSwatch:SetAlpha(1)
    end)
    
    colorButton.settingKey = settingKey
    return colorButton
end

local function CreateConfigFrame()
    local frame = CreateFrame("Frame", "BetterRaidFramesConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(320, 620)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    -- Title
    frame.TitleText:SetText("BetterRaidFrames")
    
    -- Description
    local desc = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 16, -32)
    desc:SetWidth(288)
    desc:SetJustifyH("LEFT")
    desc:SetText("Customize the appearance of the default raid frames.")
    
    -- =====================
    -- Role Icons Section
    -- =====================
    local roleHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    roleHeader:SetPoint("TOPLEFT", 16, -60)
    roleHeader:SetText("Role Icons")
    roleHeader:SetTextColor(1, 0.82, 0)
    
    local roleIconDropdown = CreateDropdown(
        frame,
        "Show role icons:",
        "showRoleIcons",
        Addon.RoleIconOptions,
        -80
    )
    frame.roleIconDropdown = roleIconDropdown
    
    -- =====================
    -- Name Section
    -- =====================
    local nameHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameHeader:SetPoint("TOPLEFT", 16, -150)
    nameHeader:SetText("Name")
    nameHeader:SetTextColor(1, 0.82, 0)
    
    local namePositionDropdown = CreateDropdown(
        frame,
        "Position:",
        "namePosition",
        Addon.NamePositionOptions,
        -170,
        function()
            Addon:RefreshNames()
        end
    )
    frame.namePositionDropdown = namePositionDropdown
    
    -- Truncate checkbox
    local truncateCheckbox = CreateCheckbox(
        frame,
        "Truncate long names",
        "nameTruncate",
        -230,
        function()
            Addon:RefreshNames()
        end
    )
    frame.truncateCheckbox = truncateCheckbox
    
    -- Truncate length slider
    local truncateSlider = CreateSlider(
        frame,
        "Max name length:",
        "nameTruncateLength",
        3, 12, 1,
        -260,
        function()
            Addon:RefreshNames()
        end
    )
    frame.truncateSlider = truncateSlider
    
    -- =====================
    -- Absorb Shield Section
    -- =====================
    local absorbHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    absorbHeader:SetPoint("TOPLEFT", 16, -320)
    absorbHeader:SetText("Absorb Shield")
    absorbHeader:SetTextColor(1, 0.82, 0)
    
    -- Enable checkbox
    local absorbCheckbox = CreateCheckbox(
        frame,
        "Show absorb shield overlay",
        "showAbsorbShield",
        -345,
        function()
            Addon:RefreshAbsorbShields()
        end
    )
    frame.absorbCheckbox = absorbCheckbox
    
    -- =====================
    -- Threat Display Section
    -- =====================
    local threatHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    threatHeader:SetPoint("TOPLEFT", 16, -380)
    threatHeader:SetText("Threat Display")
    threatHeader:SetTextColor(1, 0.82, 0)
    
    -- Enable checkbox
    local threatCheckbox = CreateCheckbox(
        frame,
        "Enable custom threat border",
        "customThreatBorder",
        -405
    )
    frame.threatCheckbox = threatCheckbox
    
    -- Border size slider
    local sizeSlider = CreateSlider(
        frame,
        "Border size:",
        "threatBorderSize",
        1, 5, 1,
        -440,
        function()
            Addon:RefreshThreatBorders()
        end
    )
    frame.sizeSlider = sizeSlider
    
    -- Color picker
    local colorPicker = CreateColorPicker(
        frame,
        "Border color:",
        "threatBorderColor",
        -500,
        function()
            Addon:RefreshThreatBorders()
        end
    )
    frame.colorPicker = colorPicker
    
    -- =====================
    -- Aura Display Section
    -- =====================
    local auraHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    auraHeader:SetPoint("TOPLEFT", 16, -550)
    auraHeader:SetText("Aura Display")
    auraHeader:SetTextColor(1, 0.82, 0)
    
    -- Hide aura borders checkbox
    local auraBordersCheckbox = CreateCheckbox(
        frame,
        "Hide borders on buff/debuff icons",
        "hideAuraBorders",
        -575,
        function()
            Addon:RefreshAuraBorders()
        end
    )
    frame.auraBordersCheckbox = auraBordersCheckbox
    
    return frame
end

function Addon:OpenConfig()
    if not ConfigFrame then
        ConfigFrame = CreateConfigFrame()
    end
    
    -- Refresh color picker displays when opening
    if ConfigFrame.colorPicker then
        ConfigFrame.colorPicker:UpdateColorSwatch()
        ConfigFrame.colorPicker:UpdateHexLabel()
    end
    
    if ConfigFrame:IsShown() then
        ConfigFrame:Hide()
    else
        ConfigFrame:Show()
    end
end
