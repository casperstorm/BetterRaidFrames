local ADDON_NAME, Addon = ...

local ConfigFrame = nil

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

local function CreateHorizontalSlider(parent, label, settingKey, minVal, maxVal, step, yOffset, onChange, isPercent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 32, yOffset)
    container:SetPoint("TOPRIGHT", -16, yOffset)
    container:SetHeight(32)

    local currentValue = Addon:GetSetting(settingKey) or minVal
    
    local function FormatValue(val)
        if isPercent then
            return string.format("%d%%", math.floor(val * 100 + 0.5))
        end
        return tostring(math.floor(val + 0.5))
    end

    -- Label on left
    local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetWidth(65)
    labelText:SetJustifyH("LEFT")
    labelText:SetText(label)

    -- Use Blizzard's MinimalSliderWithSteppersTemplate (same as Edit Mode uses)
    local sliderFrame = CreateFrame("Frame", nil, container, "MinimalSliderWithSteppersTemplate")
    sliderFrame:SetPoint("LEFT", labelText, "RIGHT", 8, 0)
    sliderFrame:SetPoint("RIGHT", -10, 0)
    sliderFrame:SetHeight(16)
    
    -- Calculate steps
    local steps = math.floor((maxVal - minVal) / step + 0.5)
    
    -- Create formatter for the right-side value display
    local formatters = {}
    formatters[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
        MinimalSliderWithSteppersMixin.Label.Right,
        function(val) return FormatValue(val) end
    )
    
    -- Track if init is in progress to avoid triggering callbacks
    sliderFrame.initInProgress = true
    
    -- Initialize the slider
    sliderFrame:Init(currentValue, minVal, maxVal, steps, formatters)
    
    -- Hide min/max text (we only want the value on the right)
    if sliderFrame.MinText then sliderFrame.MinText:Hide() end
    if sliderFrame.MaxText then sliderFrame.MaxText:Hide() end

    sliderFrame.initInProgress = false

    -- Hook the internal slider's OnValueChanged
    if sliderFrame.Slider then
        sliderFrame.Slider:HookScript("OnValueChanged", function(self, value)
            if not sliderFrame.initInProgress then
                value = math.floor(value / step + 0.5) * step
                Addon:SetSetting(settingKey, value)
                if onChange then onChange(value) end
            end
        end)
    end

    sliderFrame.settingKey = settingKey
    sliderFrame.label = labelText
    sliderFrame.container = container
    
    -- Helper to update slider value externally
    function sliderFrame:SetSliderValue(val)
        self.initInProgress = true
        self:SetValue(val)
        self.initInProgress = false
    end
    
    return sliderFrame
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
    container:SetSize(200, 26)

    local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetWidth(65)
    labelText:SetJustifyH("LEFT")
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
    frame:SetSize(380, 580)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    frame.TitleText:SetText("Better Raid Frames")

    local tip1 = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tip1:SetPoint("TOP", 0, -30)
    tip1:SetText("Tip: Join a Follower Dungeon to preview changes")
    tip1:SetTextColor(0.6, 0.6, 0.6)

    local combatWarning = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    combatWarning:SetPoint("TOP", tip1, "BOTTOM", 0, -2)
    combatWarning:SetText("Settings disabled during combat")
    combatWarning:SetTextColor(1, 0.3, 0.3)
    combatWarning:Hide()

    frame:SetScript("OnShow", function(self)
        Addon:UpdateAllFrames()
        if self.UpdateCombatLockdown then
            self.UpdateCombatLockdown(InCombatLockdown())
        else
            SetControlsEnabled(self.partyLeaderOptionsContainer or {}, Addon:GetSetting("showPartyLeader"))
            SetControlsEnabled(self.friendlyAbsorbOptionsContainer or {}, Addon:GetSetting("showFriendlyAbsorb"))
            SetControlsEnabled(self.hostileAbsorbOptionsContainer or {}, Addon:GetSetting("showHostileAbsorb"))
            SetControlsEnabled(self.raidMarkerOptionsContainer or {}, Addon:GetSetting("showRaidMarkers"))
            SetControlsEnabled(self.nameOptionsContainer or {}, Addon:GetSetting("customizeNames"))
            SetControlsEnabled(self.threatOptionsContainer or {}, Addon:GetSetting("showThreatIndicator"))
        end
    end)

    frame:SetScript("OnHide", function()
        Addon:UpdateAllFrames()
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -54)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(330)
    scrollFrame:SetScrollChild(content)
    
    frame.scrollFrame = scrollFrame
    frame.content = content

    local y = -8

    -- Profile Section (inline layout)
    local profileLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    profileLabel:SetPoint("TOPLEFT", 16, y)
    profileLabel:SetText("Profile:")

    local profileDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    profileDropdown:SetPoint("LEFT", profileLabel, "RIGHT", 6, 0)
    profileDropdown:SetWidth(100)

    local newBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    newBtn:SetSize(45, 20)
    newBtn:SetPoint("LEFT", profileDropdown, "RIGHT", 6, 0)
    newBtn:SetText("New")
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
    deleteBtn:SetSize(55, 20)
    deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 2, 0)
    deleteBtn:SetText("Remove")
    deleteBtn:SetScript("OnClick", function()
        local current = Addon:GetCurrentProfileName()
        StaticPopup_Show("BRF_DELETE_PROFILE", current)
    end)

    local function RefreshProfileDropdown()
        profileDropdown:SetupMenu(function(dropdown, rootDescription)
            local profiles = Addon:GetProfileList()
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

    local function UpdateProfileButtonsVisibility()
        local isDefault = Addon:GetCurrentProfileName() == "Default"
        renameBtn:SetEnabled(not isDefault)
        deleteBtn:SetEnabled(not isDefault)
    end

    frame.renameBtn = renameBtn
    frame.deleteBtn = deleteBtn
    frame.UpdateProfileButtonsVisibility = UpdateProfileButtonsVisibility
    UpdateProfileButtonsVisibility()

    local profileControls = {profileDropdown, profileLabel, newBtn, renameBtn, deleteBtn}

    y = y - 34

    -- Use Raid Style Party Frames checkbox
    local raidStyleCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    raidStyleCheckbox:SetPoint("TOPLEFT", 16, y)
    raidStyleCheckbox.Text:SetText("Use Raid-Style Party Frames")
    raidStyleCheckbox.Text:SetFontObject("GameFontHighlight")
    
    -- Warning text shown when disabled
    local raidStyleWarning = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    raidStyleWarning:SetPoint("LEFT", raidStyleCheckbox.Text, "RIGHT", 6, 0)
    raidStyleWarning:SetText("Required")
    raidStyleWarning:SetTextColor(1, 0.3, 0.3)
    y = y - 26
    
    -- Container for all controls that require raid-style frames
    local allRaidStyleControls = {}
    local UpdateAllRaidStyleControls
    
    local function UpdateRaidStyleCheckbox()
        local isRaidStyle = Addon:GetUseRaidStylePartyFrames()
        raidStyleCheckbox:SetChecked(isRaidStyle)
        raidStyleWarning:SetShown(not isRaidStyle)
        if UpdateAllRaidStyleControls then
            UpdateAllRaidStyleControls(isRaidStyle)
        end
    end
    
    raidStyleCheckbox:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        Addon:SetUseRaidStylePartyFrames(enabled)
        -- Re-check after a delay since it may take time to apply
        C_Timer.After(0.5, function()
            UpdateRaidStyleCheckbox()
        end)
    end)
    
    -- Update on show
    raidStyleCheckbox:SetScript("OnShow", UpdateRaidStyleCheckbox)
    y = y - 10

    local UpdateRaidMarkerOptionsEnabled
    local raidMarkersCheckbox = CreateCheckbox(content, "Show raid markers", "showRaidMarkers", y, function(checked)
        UpdateRaidMarkerOptionsEnabled(checked)
        Addon:RefreshRaidMarkers()
    end)
    table.insert(allRaidStyleControls, raidMarkersCheckbox)
    y = y - 28

    local raidMarkerOptionsContainer = {}
    local raidMarkerXSlider = CreateHorizontalSlider(content, "Marker X:", "raidMarkerX", -250, 250, 1, y, function()
        Addon:RefreshRaidMarkers()
    end)
    table.insert(raidMarkerOptionsContainer, raidMarkerXSlider.container)
    y = y - 26

    local raidMarkerYSlider = CreateHorizontalSlider(content, "Marker Y:", "raidMarkerY", -250, 250, 1, y, function()
        Addon:RefreshRaidMarkers()
    end)
    table.insert(raidMarkerOptionsContainer, raidMarkerYSlider.container)
    y = y - 26

    local raidMarkerSizeSlider = CreateHorizontalSlider(content, "Marker size:", "raidMarkerSize", 8, 32, 1, y, function()
        Addon:RefreshRaidMarkers()
    end)
    table.insert(raidMarkerOptionsContainer, raidMarkerSizeSlider.container)
    y = y - 34

    frame.raidMarkerOptionsContainer = raidMarkerOptionsContainer
    UpdateRaidMarkerOptionsEnabled = function(enabled)
        SetControlsEnabled(raidMarkerOptionsContainer, enabled)
    end
    UpdateRaidMarkerOptionsEnabled(Addon:GetSetting("showRaidMarkers"))

    local roleIconDropdown = CreateDropdown(
        content, "Show role icons:", "showRoleIcons", Addon.RoleIconOptions, y
    )
    table.insert(allRaidStyleControls, roleIconDropdown)
    table.insert(allRaidStyleControls, roleIconDropdown.label)
    y = y - 60

    local UpdatePartyLeaderOptionsEnabled

    local partyLeaderCheckbox = CreateCheckbox(content, "Show party leader icon", "showPartyLeader", y, function(checked)
        UpdatePartyLeaderOptionsEnabled(checked)
        Addon:RefreshPartyLeaders()
    end)
    table.insert(allRaidStyleControls, partyLeaderCheckbox)
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

    local friendlyAbsorbOpacitySlider = CreateHorizontalSlider(content, "Opacity:", "friendlyAbsorbOpacity", 0.1, 1.0, 0.1, y, function() Addon:RefreshFriendlyAbsorbs() end, true)
    y = y - 24

    local friendlyAbsorbColorPicker = CreateColorPicker(content, "Color:", "friendlyAbsorbColorR", "friendlyAbsorbColorG", "friendlyAbsorbColorB", y, function() Addon:RefreshFriendlyAbsorbs() end)
    y = y - 30

    local friendlyAbsorbOptionsContainer = {friendlyAbsorbOpacitySlider.container, friendlyAbsorbColorPicker}
    UpdateFriendlyAbsorbOptionsEnabled = function(enabled)
        SetControlsEnabled(friendlyAbsorbOptionsContainer, enabled)
    end
    frame.friendlyAbsorbOptionsContainer = friendlyAbsorbOptionsContainer
    UpdateFriendlyAbsorbOptionsEnabled(Addon:GetSetting("showFriendlyAbsorb"))

    local UpdateHostileAbsorbOptionsEnabled

    local hostileAbsorbCheckbox = CreateCheckbox(content, "Show hostile absorb (heal debuffs)", "showHostileAbsorb", y, function(checked)
        UpdateHostileAbsorbOptionsEnabled(checked)
        Addon:RefreshHostileAbsorbs()
    end)
    y = y - 26

    local hostileAbsorbOpacitySlider = CreateHorizontalSlider(content, "Opacity:", "hostileAbsorbOpacity", 0.1, 1.0, 0.1, y, function() Addon:RefreshHostileAbsorbs() end, true)
    y = y - 24

    local hostileAbsorbColorPicker = CreateColorPicker(content, "Color:", "hostileAbsorbColorR", "hostileAbsorbColorG", "hostileAbsorbColorB", y, function() Addon:RefreshHostileAbsorbs() end)
    y = y - 30

    local hostileAbsorbOptionsContainer = {hostileAbsorbOpacitySlider.container, hostileAbsorbColorPicker}
    UpdateHostileAbsorbOptionsEnabled = function(enabled)
        SetControlsEnabled(hostileAbsorbOptionsContainer, enabled)
    end
    frame.hostileAbsorbOptionsContainer = hostileAbsorbOptionsContainer
    UpdateHostileAbsorbOptionsEnabled(Addon:GetSetting("showHostileAbsorb"))

    local auraBordersCheckbox = CreateCheckbox(content, "Hide borders on buff/debuff icons", "hideAuraBorders", y, function() Addon:RefreshAuraBorders() end)
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

    local hideOnDeadCheckbox = CreateSubCheckbox(content, "Hide name when dead", "nameHideOnDead", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, hideOnDeadCheckbox)
    y = y - 25

    local hideOnOfflineCheckbox = CreateSubCheckbox(content, "Hide name when offline", "nameHideOnOffline", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, hideOnOfflineCheckbox)
    y = y - 25

    local shadowCheckbox = CreateSubCheckbox(content, "Text shadow", "nameTextShadow", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, shadowCheckbox)
    y = y - 15

    local shadowColorPicker = CreateColorPicker(content, "", "nameTextShadowColorR", "nameTextShadowColorG", "nameTextShadowColorB", y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, shadowColorPicker)
    y = y - 15

    local shadowOffsetSlider = CreateHorizontalSlider(content, "Offset:", "nameTextShadowOffset", 1, 3, 1, y, function() Addon:RefreshNames() end)
    table.insert(nameOptionsContainer, shadowOffsetSlider.container)
    y = y - 30

    local outlineContainer = CreateFrame("Frame", nil, content)
    outlineContainer:SetPoint("TOPLEFT", 32, y)
    outlineContainer:SetPoint("TOPRIGHT", -16, y)
    outlineContainer:SetHeight(32)

    local outlineLabel = outlineContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    outlineLabel:SetPoint("LEFT", 0, 0)
    outlineLabel:SetWidth(65)
    outlineLabel:SetJustifyH("LEFT")
    outlineLabel:SetText("Outline:")

    local outlineDropdown = CreateFrame("DropdownButton", nil, outlineContainer, "WowStyle1DropdownTemplate")
    outlineDropdown:SetPoint("LEFT", outlineLabel, "RIGHT", 8, 0)
    outlineDropdown:SetWidth(120)

    local function IsOutlineSelected(value)
        return Addon:GetSetting("nameTextOutline") == value
    end
    local function SetOutlineSelected(value)
        Addon:SetSetting("nameTextOutline", value)
        Addon:RefreshNames()
        outlineDropdown:GenerateMenu()
    end
    outlineDropdown:SetupMenu(function(_, rootDescription)
        rootDescription:CreateRadio("None", IsOutlineSelected, SetOutlineSelected, "NONE")
        rootDescription:CreateRadio("Thin", IsOutlineSelected, SetOutlineSelected, "OUTLINE")
        rootDescription:CreateRadio("Thick", IsOutlineSelected, SetOutlineSelected, "THICKOUTLINE")
    end)

    table.insert(nameOptionsContainer, outlineContainer)
    y = y - 30

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

    -- Add all remaining controls to the raid-style container
    for _, ctrl in ipairs(raidMarkerOptionsContainer) do table.insert(allRaidStyleControls, ctrl) end
    table.insert(allRaidStyleControls, partyLeaderHideInCombatCheckbox)
    for _, ctrl in ipairs(partyLeaderOptionsContainer) do table.insert(allRaidStyleControls, ctrl) end
    table.insert(allRaidStyleControls, friendlyAbsorbCheckbox)
    table.insert(allRaidStyleControls, friendlyAbsorbOpacitySlider.container)
    table.insert(allRaidStyleControls, friendlyAbsorbColorPicker)
    table.insert(allRaidStyleControls, hostileAbsorbCheckbox)
    table.insert(allRaidStyleControls, hostileAbsorbOpacitySlider.container)
    table.insert(allRaidStyleControls, hostileAbsorbColorPicker)
    table.insert(allRaidStyleControls, auraBordersCheckbox)
    table.insert(allRaidStyleControls, customizeNamesCheckbox)
    for _, ctrl in ipairs(nameOptionsContainer) do table.insert(allRaidStyleControls, ctrl) end
    table.insert(allRaidStyleControls, threatCheckbox)
    for _, ctrl in ipairs(threatOptionsContainer) do table.insert(allRaidStyleControls, ctrl) end

    -- Function to enable/disable all raid-style controls
    UpdateAllRaidStyleControls = function(enabled)
        SetControlsEnabled(allRaidStyleControls, enabled)
    end
    frame.allRaidStyleControls = allRaidStyleControls
    frame.UpdateAllRaidStyleControls = UpdateAllRaidStyleControls

    -- Initial update after a delay to ensure lib is ready
    C_Timer.After(0.5, UpdateRaidStyleCheckbox)

    -- Combat lockdown: disable all controls when in combat
    local function UpdateCombatLockdown(inCombat)
        combatWarning:SetShown(inCombat)
        SetControlsEnabled(profileControls, not inCombat)
        SetControlsEnabled({raidStyleCheckbox}, not inCombat)
        if inCombat then
            SetControlsEnabled(allRaidStyleControls, false)
        else
            local isRaidStyle = Addon:GetUseRaidStylePartyFrames()
            UpdateAllRaidStyleControls(isRaidStyle)
            raidStyleCheckbox:SetAlpha(1.0)
            raidStyleCheckbox:EnableMouse(true)
            -- Re-apply sub-section states
            SetControlsEnabled(frame.partyLeaderOptionsContainer or {}, Addon:GetSetting("showPartyLeader"))
            SetControlsEnabled(frame.friendlyAbsorbOptionsContainer or {}, Addon:GetSetting("showFriendlyAbsorb"))
            SetControlsEnabled(frame.hostileAbsorbOptionsContainer or {}, Addon:GetSetting("showHostileAbsorb"))
            SetControlsEnabled(frame.raidMarkerOptionsContainer or {}, Addon:GetSetting("showRaidMarkers"))
            SetControlsEnabled(frame.nameOptionsContainer or {}, Addon:GetSetting("customizeNames"))
            SetControlsEnabled(frame.threatOptionsContainer or {}, Addon:GetSetting("showThreatIndicator"))
        end
    end
    frame.UpdateCombatLockdown = UpdateCombatLockdown

    frame.combatEventFrame = CreateFrame("Frame")
    frame.combatEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame.combatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame.combatEventFrame:SetScript("OnEvent", function(self, event)
        UpdateCombatLockdown(event == "PLAYER_REGEN_DISABLED")
    end)

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
    if ConfigFrame.raidMarkerOptionsContainer then
        SetControlsEnabled(ConfigFrame.raidMarkerOptionsContainer, self:GetSetting("showRaidMarkers"))
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
