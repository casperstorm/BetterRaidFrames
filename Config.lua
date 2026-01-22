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
    local divider = parent:CreateTexture(nil, "OVERLAY")
    divider:SetPoint("TOPLEFT", 12, yOffset)
    divider:SetPoint("TOPRIGHT", -12, yOffset)
    divider:SetHeight(2)
    divider:SetColorTexture(0.5, 0.5, 0.5, 1)
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

local function CreateHorizontalSlider(parent, label, settingKey, minVal, maxVal, step, yOffset, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 32, yOffset)
    container:SetPoint("TOPRIGHT", -12, yOffset)
    container:SetHeight(20)

    local currentValue = Addon:GetSetting(settingKey) or minVal

    -- Label on left
    local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetText(label)

    -- Left arrow button (decrement)
    local leftBtn = CreateFrame("Button", nil, container)
    leftBtn:SetSize(20, 20)
    leftBtn:SetPoint("LEFT", labelText, "RIGHT", 2, 0)
    leftBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    leftBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    leftBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    -- Value input on right (editable)
    local valueBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    valueBox:SetSize(40, 18)
    valueBox:SetPoint("RIGHT", 0, 0)
    valueBox:SetAutoFocus(false)
    valueBox:SetNumeric(false)
    valueBox:SetText(currentValue)
    valueBox:SetJustifyH("CENTER")
    valueBox:SetFontObject("GameFontHighlightSmall")

    -- Right arrow button (increment)
    local rightBtn = CreateFrame("Button", nil, container)
    rightBtn:SetSize(20, 20)
    rightBtn:SetPoint("RIGHT", valueBox, "LEFT", -8, 0)
    rightBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    rightBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    rightBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    -- Slider in middle
    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", leftBtn, "RIGHT", 4, 0)
    slider:SetPoint("RIGHT", rightBtn, "LEFT", -4, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    slider.Low:Hide()
    slider.High:Hide()
    slider.Text:Hide()

    slider:SetValue(currentValue)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valueBox:SetText(value)
        Addon:SetSetting(settingKey, value)
        if onChange then onChange(value) end
    end)

    valueBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(minVal, math.min(maxVal, val))
            val = math.floor(val / step + 0.5) * step
            slider:SetValue(val)
        else
            self:SetText(slider:GetValue())
        end
        self:ClearFocus()
    end)

    valueBox:SetScript("OnEscapePressed", function(self)
        self:SetText(slider:GetValue())
        self:ClearFocus()
    end)

    leftBtn:SetScript("OnClick", function()
        local val = slider:GetValue() - step
        if val >= minVal then
            slider:SetValue(val)
        end
    end)

    rightBtn:SetScript("OnClick", function()
        local val = slider:GetValue() + step
        if val <= maxVal then
            slider:SetValue(val)
        end
    end)

    slider.leftBtn = leftBtn
    slider.rightBtn = rightBtn
    slider.settingKey = settingKey
    slider.label = labelText
    slider.valueBox = valueBox
    slider.container = container
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

local function CreateColorPicker(parent, label, settingKeyR, settingKeyG, settingKeyB, yOffset, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 32, yOffset)
    container:SetSize(200, 20)

    local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetText(label)

    local colorSwatch = CreateFrame("Button", nil, container)
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetPoint("LEFT", labelText, "RIGHT", 8, 0)

    local swatchBg = colorSwatch:CreateTexture(nil, "BACKGROUND")
    swatchBg:SetAllPoints()
    swatchBg:SetColorTexture(0, 0, 0, 1)

    local swatchColor = colorSwatch:CreateTexture(nil, "ARTWORK")
    swatchColor:SetPoint("TOPLEFT", 1, -1)
    swatchColor:SetPoint("BOTTOMRIGHT", -1, 1)

    local r = Addon:GetSetting(settingKeyR) or 1
    local g = Addon:GetSetting(settingKeyG) or 1
    local b = Addon:GetSetting(settingKeyB) or 1
    swatchColor:SetColorTexture(r, g, b, 1)

    colorSwatch:SetScript("OnClick", function()
        local currentR = Addon:GetSetting(settingKeyR) or 1
        local currentG = Addon:GetSetting(settingKeyG) or 1
        local currentB = Addon:GetSetting(settingKeyB) or 1

        local info = {
            swatchFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                Addon:SetSetting(settingKeyR, newR)
                Addon:SetSetting(settingKeyG, newG)
                Addon:SetSetting(settingKeyB, newB)
                swatchColor:SetColorTexture(newR, newG, newB, 1)
                if onChange then onChange() end
            end,
            cancelFunc = function()
                Addon:SetSetting(settingKeyR, currentR)
                Addon:SetSetting(settingKeyG, currentG)
                Addon:SetSetting(settingKeyB, currentB)
                swatchColor:SetColorTexture(currentR, currentG, currentB, 1)
                if onChange then onChange() end
            end,
            r = currentR,
            g = currentG,
            b = currentB,
            hasOpacity = false,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    container.colorSwatch = colorSwatch
    container.swatchColor = swatchColor
    container.label = labelText
    return container
end

local function CreateConfigFrame()
    local frame = CreateFrame("Frame", "BetterRaidFramesConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(340, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    frame.TitleText:SetText("Better Raid Frames")

    local tip1 = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tip1:SetPoint("TOP", 0, -34)
    tip1:SetText("Join a Follower Dungeon to test and adjust")
    tip1:SetTextColor(0.7, 0.7, 0.7)

    local tip2 = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tip2:SetPoint("TOP", tip1, "BOTTOM", 0, -2)

    local function UpdateRaidStyleTip()
        local inGroup = IsInGroup()
        local isRaidStyle = false

        if inGroup then
            -- Check if compact party frame is visible
            local compactMember = _G["CompactPartyFrameMember1"]
            isRaidStyle = compactMember and compactMember:IsShown() and compactMember:IsVisible()
        else
            -- Not in group, check Edit Mode setting directly
            if EditModeManagerFrame and EditModeManagerFrame.UseRaidStylePartyFrames then
                isRaidStyle = EditModeManagerFrame:UseRaidStylePartyFrames()
            end
        end

        if isRaidStyle then
            tip2:SetText("Raid-style party frames enabled")
            tip2:SetTextColor(0.4, 0.8, 0.4)  -- green
        else
            tip2:SetText("Enable raid-style party frames in Edit Mode")
            tip2:SetTextColor(1, 0.5, 0.5)  -- red/warning
        end
    end
    UpdateRaidStyleTip()

    -- Register events for dynamic updates
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(self, event)
        UpdateRaidStyleTip()
    end)

    -- Periodic check for Edit Mode setting changes (event doesn't fire reliably)
    local timeSinceLastUpdate = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        timeSinceLastUpdate = timeSinceLastUpdate + elapsed
        if timeSinceLastUpdate >= 1 then
            timeSinceLastUpdate = 0
            UpdateRaidStyleTip()
        end
    end)

    frame:SetScript("OnShow", function()
        UpdateRaidStyleTip()
        Addon:UpdateAllFrames()
    end)

    frame:SetScript("OnHide", function()
        Addon:UpdateAllFrames()
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -66)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 8)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(288)
    scrollFrame:SetScrollChild(content)
    
    frame.scrollFrame = scrollFrame
    frame.content = content

    local y = -10

    -- Profile Section
    local profileDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    profileDropdown:SetPoint("TOP", content, "TOP", 0, y)
    profileDropdown:SetWidth(120)

    local profileLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    profileLabel:SetPoint("RIGHT", profileDropdown, "LEFT", -8, 0)
    profileLabel:SetText("Profile:")

    local function RefreshProfileDropdown()
        profileDropdown:SetupMenu(function(dropdown, rootDescription)
            local profiles = Addon:GetProfileList()
            local currentProfile = Addon:GetCurrentProfileName()
            for _, name in ipairs(profiles) do
                rootDescription:CreateRadio(name,
                    function() return Addon:GetCurrentProfileName() == name end,
                    function()
                        Addon:SwitchProfile(name)
                        Addon:RefreshConfig()
                    end,
                    name
                )
            end
        end)
    end
    RefreshProfileDropdown()
    frame.profileDropdown = profileDropdown
    frame.RefreshProfileDropdown = RefreshProfileDropdown

    local newBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    newBtn:SetSize(45, 20)
    newBtn:SetPoint("TOPLEFT", profileDropdown, "BOTTOMLEFT", 0, -8)
    newBtn:SetText("New")
    newBtn:GetFontString():SetFont(newBtn:GetFontString():GetFont(), 10)
    newBtn:SetScript("OnClick", function()
        StaticPopup_Show("BRF_NEW_PROFILE")
    end)

    local renameBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    renameBtn:SetSize(55, 20)
    renameBtn:SetPoint("LEFT", newBtn, "RIGHT", 2, 0)
    renameBtn:SetText("Rename")
    renameBtn:GetFontString():SetFont(renameBtn:GetFontString():GetFont(), 10)
    renameBtn:SetScript("OnClick", function()
        StaticPopup_Show("BRF_RENAME_PROFILE")
    end)

    local deleteBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    deleteBtn:SetSize(50, 20)
    deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 2, 0)
    deleteBtn:SetText("Delete")
    deleteBtn:GetFontString():SetFont(deleteBtn:GetFontString():GetFont(), 10)
    deleteBtn:SetScript("OnClick", function()
        local current = Addon:GetCurrentProfileName()
        StaticPopup_Show("BRF_DELETE_PROFILE", current)
    end)

    local function UpdateProfileButtonsVisibility()
        local isDefault = Addon:GetCurrentProfileName() == "Default"
        if renameBtn then
            renameBtn:SetEnabled(not isDefault)
        end
        if deleteBtn then
            deleteBtn:SetEnabled(not isDefault)
        end
    end

    frame.renameBtn = renameBtn
    frame.deleteBtn = deleteBtn
    frame.UpdateProfileButtonsVisibility = UpdateProfileButtonsVisibility
    UpdateProfileButtonsVisibility()

    -- Profile section uses relative positioning, so set y to where it ends
    -- Dropdown at -10, ~28px tall, buttons 8px below, buttons 20px tall = ends around -66
    y = -80

    -- Blizzard Raid Frame Settings Section
    CreateDivider(content, y)
    y = y - 16

    local blizzHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    blizzHeader:SetPoint("TOPLEFT", 16, y)
    blizzHeader:SetText("Shortcut to Blizzard Settings")
    y = y - 22

    local blizzSettingsBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    blizzSettingsBtn:SetSize(220, 22)
    blizzSettingsBtn:SetPoint("TOPLEFT", 16, y)
    blizzSettingsBtn:SetText("Interface Options")
    blizzSettingsBtn:SetScript("OnClick", function()
        Settings.OpenToCategory(Settings.INTERFACE_CATEGORY_ID)
    end)
    y = y - 26

    local editModeBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    editModeBtn:SetSize(220, 22)
    editModeBtn:SetPoint("TOPLEFT", 16, y)
    editModeBtn:SetText("Frames Options (Edit Mode)")
    editModeBtn:SetScript("OnClick", function()
        ShowUIPanel(EditModeManagerFrame)
    end)
    y = y - 38

    CreateDivider(content, y)
    y = y - 16

    local roleIconDropdown = CreateDropdown(
        content, "Show role icons:", "showRoleIcons", Addon.RoleIconOptions, y
    )
    y = y - 60

    local UpdatePartyLeaderOptionsEnabled

    local partyLeaderCheckbox = CreateCheckbox(content, "Show party leader icon", "showPartyLeader", y, function(checked)
        UpdatePartyLeaderOptionsEnabled(checked)
        Addon:RefreshPartyLeaders()
    end)
    frame.partyLeaderCheckbox = partyLeaderCheckbox
    y = y - 28

    local partyLeaderOptionsContainer = {}

    local partyLeaderHideInCombatCheckbox = CreateSubCheckbox(content, "Hide in combat", "partyLeaderHideInCombat", y, function() Addon:RefreshPartyLeaders() end)
    table.insert(partyLeaderOptionsContainer, partyLeaderHideInCombatCheckbox)
    y = y - 26

    local partyLeaderXSlider = CreateHorizontalSlider(content, "X:", "partyLeaderX", -250, 250, 1, y, function() Addon:RefreshPartyLeaders() end)
    table.insert(partyLeaderOptionsContainer, partyLeaderXSlider.container)
    y = y - 26

    local partyLeaderYSlider = CreateHorizontalSlider(content, "Y:", "partyLeaderY", -250, 250, 1, y, function() Addon:RefreshPartyLeaders() end)
    table.insert(partyLeaderOptionsContainer, partyLeaderYSlider.container)
    y = y - 26

    local partyLeaderSizeSlider = CreateHorizontalSlider(content, "Size:", "partyLeaderSize", 8, 32, 1, y, function() Addon:RefreshPartyLeaders() end)
    table.insert(partyLeaderOptionsContainer, partyLeaderSizeSlider.container)
    y = y - 26

    UpdatePartyLeaderOptionsEnabled = function(enabled)
        SetControlsEnabled(partyLeaderOptionsContainer, enabled)
    end
    frame.partyLeaderOptionsContainer = partyLeaderOptionsContainer
    UpdatePartyLeaderOptionsEnabled(Addon:GetSetting("showPartyLeader"))

    local UpdateFriendlyAbsorbOptionsEnabled

    local friendlyAbsorbCheckbox = CreateCheckbox(content, "Show friendly absorb (shields)", "showFriendlyAbsorb", y, function(checked)
        UpdateFriendlyAbsorbOptionsEnabled(checked)
        Addon:RefreshFriendlyAbsorbs()
    end)
    y = y - 26

    local friendlyAbsorbOpacitySlider = CreateHorizontalSlider(content, "Opacity:", "friendlyAbsorbOpacity", 0.1, 1.0, 0.1, y, function() Addon:RefreshFriendlyAbsorbs() end)
    y = y - 24

    local friendlyAbsorbColorPicker = CreateColorPicker(content, "Color:", "friendlyAbsorbColorR", "friendlyAbsorbColorG", "friendlyAbsorbColorB", y, function() Addon:RefreshFriendlyAbsorbs() end)
    y = y - 30

    UpdateFriendlyAbsorbOptionsEnabled = function(enabled)
        SetControlsEnabled({friendlyAbsorbOpacitySlider.container, friendlyAbsorbColorPicker}, enabled)
    end
    UpdateFriendlyAbsorbOptionsEnabled(Addon:GetSetting("showFriendlyAbsorb"))

    local UpdateHostileAbsorbOptionsEnabled

    local hostileAbsorbCheckbox = CreateCheckbox(content, "Show hostile absorb (heal debuffs)", "showHostileAbsorb", y, function(checked)
        UpdateHostileAbsorbOptionsEnabled(checked)
        Addon:RefreshHostileAbsorbs()
    end)
    y = y - 26

    local hostileAbsorbOpacitySlider = CreateHorizontalSlider(content, "Opacity:", "hostileAbsorbOpacity", 0.1, 1.0, 0.1, y, function() Addon:RefreshHostileAbsorbs() end)
    y = y - 24

    local hostileAbsorbColorPicker = CreateColorPicker(content, "Color:", "hostileAbsorbColorR", "hostileAbsorbColorG", "hostileAbsorbColorB", y, function() Addon:RefreshHostileAbsorbs() end)
    y = y - 30

    UpdateHostileAbsorbOptionsEnabled = function(enabled)
        SetControlsEnabled({hostileAbsorbOpacitySlider.container, hostileAbsorbColorPicker}, enabled)
    end
    UpdateHostileAbsorbOptionsEnabled(Addon:GetSetting("showHostileAbsorb"))

    local hideIncomingHealsCheckbox = CreateCheckbox(content, "Hide incoming heal indicator", "hideIncomingHeals", y, function() Addon:RefreshIncomingHeals() end)
    y = y - 25

    local auraBordersCheckbox = CreateCheckbox(content, "Hide borders on buff/debuff icons", "hideAuraBorders", y, function() Addon:RefreshAuraBorders() end)
    y = y - 25

    local dispelIndicatorCheckbox = CreateCheckbox(content, "Hide dispel indicator", "hideDispelIndicator", y, function() Addon:RefreshDispelIndicator() end)
    y = y - 25

    local selectionBorderCheckbox = CreateCheckbox(content, "Hide selection border", "hideSelectionBorder", y, function() Addon:RefreshSelectionBorders() end)
    y = y - 25
    
    -- Name
    local UpdateNameOptionsEnabled

    local customizeNamesCheckbox = CreateCheckbox(content, "Customize names", "customizeNames", y, function(checked)
        UpdateNameOptionsEnabled(checked)
        Addon:RefreshNames()
    end)
    frame.customizeNamesCheckbox = customizeNamesCheckbox
    y = y - 35

    local nameOptionsContainer = {}

    local nameXSlider = CreateHorizontalSlider(content, "X:", "nameX", -250, 250, 1, y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, nameXSlider.container)
    y = y - 26

    local nameYSlider = CreateHorizontalSlider(content, "Y:", "nameY", -250, 250, 1, y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, nameYSlider.container)
    y = y - 26

    local nameSizeSlider = CreateHorizontalSlider(content, "Size:", "nameSize", 6, 20, 1, y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, nameSizeSlider.container)
    y = y - 30

    local hideServerCheckbox = CreateSubCheckbox(content, "Hide server name", "nameHideServer", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, hideServerCheckbox)
    y = y - 25

    local truncateCheckbox = CreateSubCheckbox(content, "Truncate long names", "nameTruncate", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, truncateCheckbox)
    y = y - 30

    local truncateSlider = CreateHorizontalSlider(content, "Max length:", "nameTruncateLength", 3, 12, 1, y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, truncateSlider.container)
    y = y - 30

    local classColorCheckbox = CreateSubCheckbox(content, "Class color", "nameClassColor", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, classColorCheckbox)
    y = y - 25

    local cyrillicCheckbox = CreateSubCheckbox(content, "Convert Cyrillic to Latin", "nameCyrillicToLatin", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, cyrillicCheckbox)
    y = y - 25

    UpdateNameOptionsEnabled = function(enabled)
        SetControlsEnabled(nameOptionsContainer, enabled)
    end
    frame.nameOptionsContainer = nameOptionsContainer
    UpdateNameOptionsEnabled(Addon:GetSetting("customizeNames"))

    -- Threat Indicator
    local UpdateThreatOptionsEnabled

    local threatCheckbox = CreateCheckbox(content, "Show threat indicator", "showThreatIndicator", y, function(checked)
        UpdateThreatOptionsEnabled(checked)
        Addon:RefreshThreatIndicators()
    end)
    frame.threatCheckbox = threatCheckbox
    y = y - 28

    local threatOptionsContainer = {}

    local threatBlinkCheckbox = CreateSubCheckbox(content, "Blinking", "threatIndicatorBlink", y, function() Addon:RefreshThreatIndicators() end)
    table.insert(threatOptionsContainer, threatBlinkCheckbox)
    y = y - 25

    local threatXSlider = CreateHorizontalSlider(content, "X:", "threatIndicatorX", -250, 250, 1, y, function() Addon:RefreshThreatIndicators() end)
    table.insert(threatOptionsContainer, threatXSlider.container)
    y = y - 26

    local threatYSlider = CreateHorizontalSlider(content, "Y:", "threatIndicatorY", -250, 250, 1, y, function() Addon:RefreshThreatIndicators() end)
    table.insert(threatOptionsContainer, threatYSlider.container)
    y = y - 26

    local threatSizeSlider = CreateHorizontalSlider(content, "Size:", "threatIndicatorSize", 4, 20, 1, y, function() Addon:RefreshThreatIndicators() end)
    table.insert(threatOptionsContainer, threatSizeSlider.container)
    y = y - 26
    
    UpdateThreatOptionsEnabled = function(enabled)
        SetControlsEnabled(threatOptionsContainer, enabled)
    end
    frame.threatOptionsContainer = threatOptionsContainer
    UpdateThreatOptionsEnabled(Addon:GetSetting("showThreatIndicator"))


    content:SetHeight(math.abs(y) + 30)

    return frame
end

function Addon:OpenConfig()
    if not ConfigFrame then
        ConfigFrame = CreateConfigFrame()
    end

    if ConfigFrame.UpdateProfileButtonsVisibility then
        ConfigFrame.UpdateProfileButtonsVisibility()
    end

    if ConfigFrame:IsShown() then
        ConfigFrame:Hide()
    else
        ConfigFrame:Show()
    end
end

function Addon:RefreshConfig()
    if not ConfigFrame then return end

    if ConfigFrame.RefreshProfileDropdown then
        ConfigFrame.RefreshProfileDropdown()
    end

    if ConfigFrame.UpdateProfileButtonsVisibility then
        ConfigFrame.UpdateProfileButtonsVisibility()
    end

    if ConfigFrame.nameOptionsContainer then
        SetControlsEnabled(ConfigFrame.nameOptionsContainer, self:GetSetting("customizeNames"))
    end
    if ConfigFrame.threatOptionsContainer then
        SetControlsEnabled(ConfigFrame.threatOptionsContainer, self:GetSetting("showThreatIndicator"))
    end
    if ConfigFrame.partyLeaderOptionsContainer then
        SetControlsEnabled(ConfigFrame.partyLeaderOptionsContainer, self:GetSetting("showPartyLeader"))
    end

    -- Recreate the config frame to reflect new profile settings
    if ConfigFrame:IsShown() then
        ConfigFrame:Hide()
        ConfigFrame = nil
        ConfigFrame = CreateConfigFrame()
        ConfigFrame:Show()
    else
        ConfigFrame = nil
    end
end

StaticPopupDialogs["BRF_NEW_PROFILE"] = {
    text = "Enter new profile name:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        if BetterRaidFrames:CreateProfile(name) then
            BetterRaidFrames:SwitchProfile(name)
            BetterRaidFrames:RefreshConfig()
        else
            print("|cff00ff00BetterRaidFrames:|r Could not create profile (name empty or already exists)")
        end
    end,
    OnShow = function(self)
        self.EditBox:SetText("")
        self.EditBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = parent.EditBox:GetText()
        if BetterRaidFrames:CreateProfile(name) then
            BetterRaidFrames:SwitchProfile(name)
            BetterRaidFrames:RefreshConfig()
        end
        parent:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BRF_RENAME_PROFILE"] = {
    text = "Enter new name for profile:",
    button1 = "Rename",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self)
        local newName = self.EditBox:GetText()
        local oldName = BetterRaidFrames:GetCurrentProfileName()
        if BetterRaidFrames:RenameProfile(oldName, newName) then
            BetterRaidFrames:RefreshConfig()
        else
            print("|cff00ff00BetterRaidFrames:|r Could not rename profile")
        end
    end,
    OnShow = function(self)
        self.EditBox:SetText(BetterRaidFrames:GetCurrentProfileName())
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local newName = parent.EditBox:GetText()
        local oldName = BetterRaidFrames:GetCurrentProfileName()
        if BetterRaidFrames:RenameProfile(oldName, newName) then
            BetterRaidFrames:RefreshConfig()
        end
        parent:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BRF_DELETE_PROFILE"] = {
    text = "Delete profile '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self)
        if BetterRaidFrames:DeleteProfile(BetterRaidFrames:GetCurrentProfileName()) then
            BetterRaidFrames:RefreshConfig()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
