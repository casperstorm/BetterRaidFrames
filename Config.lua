local _, Addon = ...

local ConfigFrame = nil
local settingRefreshers = {}
local CONTROL_WIDTH = 400
local CONTROL_LABEL_WIDTH = 100
local DROPDOWN_WIDTH = 180

local function RegisterSettingRefresher(refresh)
    table.insert(settingRefreshers, refresh)
end

local function RefreshConfigDeferred()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            Addon:RefreshConfig()
        end)
    else
        Addon:RefreshConfig()
    end
end

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

    RegisterSettingRefresher(function()
        checkbox:SetChecked(Addon:GetSetting(settingKey))
    end)
    return checkbox
end

local function CreateDropdown(parent, label, settingKey, options, yOffset, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 24, yOffset)
    container:SetSize(CONTROL_WIDTH, 30)

    local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetWidth(CONTROL_LABEL_WIDTH)
    labelText:SetJustifyH("LEFT")
    labelText:SetText(label)

    local dropdown = CreateFrame("DropdownButton", nil, container, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", labelText, "RIGHT", 8, 0)
    dropdown:SetWidth(DROPDOWN_WIDTH)

    local function IsSelected(value)
        return Addon:GetSetting(settingKey) == value
    end

    local function SetSelected(value)
        Addon:SetSetting(settingKey, value)
        dropdown:GenerateMenu()
        if onChange then onChange(value) end
    end

    dropdown:SetupMenu(function(_, rootDescription)
        local choices = type(options) == "function" and options() or options
        if #choices > 12 then rootDescription:SetScrollMode(320) end
        for _, option in ipairs(choices) do
            rootDescription:CreateRadio(option.label, IsSelected, SetSelected, option.value)
        end
    end)

    dropdown.label = labelText
    dropdown.container = container
    RegisterSettingRefresher(function()
        dropdown:GenerateMenu()
    end)
    return dropdown
end

local function CreateHorizontalSlider(parent, label, settingKey, minVal, maxVal, step, yOffset, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 24, yOffset)
    container:SetSize(CONTROL_WIDTH, 32)

    local currentValue = Addon:GetSetting(settingKey) or minVal

    local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetWidth(CONTROL_LABEL_WIDTH)
    labelText:SetJustifyH("LEFT")
    labelText:SetText(label)

    local sliderFrame = CreateFrame("Frame", nil, container, "MinimalSliderWithSteppersTemplate")
    sliderFrame:SetPoint("LEFT", labelText, "RIGHT", 8, 0)
    sliderFrame:SetPoint("RIGHT", 0, 0)
    sliderFrame:SetHeight(16)

    local steps = math.floor((maxVal - minVal) / step + 0.5)

    local formatters = {}
    formatters[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
        MinimalSliderWithSteppersMixin.Label.Right,
        function(value) return tostring(math.floor(value + 0.5)) end
    )

    sliderFrame.initInProgress = true
    sliderFrame:Init(currentValue, minVal, maxVal, steps, formatters)

    if sliderFrame.MinText then sliderFrame.MinText:Hide() end
    if sliderFrame.MaxText then sliderFrame.MaxText:Hide() end

    sliderFrame.initInProgress = false

    if sliderFrame.Slider then
        sliderFrame.Slider:HookScript("OnValueChanged", function(_, value)
            if not sliderFrame.initInProgress then
                value = math.floor(value / step + 0.5) * step
                Addon:SetSetting(settingKey, value)
                if onChange then onChange(value) end
            end
        end)
    end

    sliderFrame.container = container
    RegisterSettingRefresher(function()
        sliderFrame.initInProgress = true
        sliderFrame:SetValue(Addon:GetSetting(settingKey) or minVal)
        sliderFrame.initInProgress = false
    end)

    return sliderFrame
end

local function CreateSubCheckbox(parent, label, settingKey, yOffset, xOffset, onChange)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", xOffset or 24, yOffset)
    checkbox.Text:SetText(label)
    checkbox.Text:SetFontObject("GameFontHighlight")

    checkbox:SetChecked(Addon:GetSetting(settingKey))
    checkbox:SetScript("OnClick", function(self)
        Addon:SetSetting(settingKey, self:GetChecked())
        if onChange then onChange(self:GetChecked()) end
    end)

    RegisterSettingRefresher(function()
        checkbox:SetChecked(Addon:GetSetting(settingKey))
    end)
    return checkbox
end

local function CreateColorPicker(parent, label, settingKeyR, settingKeyG, settingKeyB, yOffset, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 24, yOffset)
    container:SetSize(CONTROL_WIDTH, 26)

    local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetWidth(CONTROL_LABEL_WIDTH)
    labelText:SetJustifyH("LEFT")
    labelText:SetText(label)

    local colorSwatch = CreateFrame("Button", nil, container)
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetPoint("LEFT", labelText, "RIGHT", 8, 0)

    local border = colorSwatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.6, 0.6, 0.6, 1)

    local color = colorSwatch:CreateTexture(nil, "ARTWORK")
    color:SetPoint("TOPLEFT", 1, -1)
    color:SetPoint("BOTTOMRIGHT", -1, 1)

    local function RefreshColor()
        color:SetColorTexture(
            Addon:GetSetting(settingKeyR) or 0,
            Addon:GetSetting(settingKeyG) or 0,
            Addon:GetSetting(settingKeyB) or 0,
            1
        )
    end

    colorSwatch:SetScript("OnClick", function()
        local profile = Addon:GetCurrentProfileName()
        local originalR = Addon:GetSetting(settingKeyR) or 0
        local originalG = Addon:GetSetting(settingKeyG) or 0
        local originalB = Addon:GetSetting(settingKeyB) or 0

        local function SetColor(r, g, b)
            if Addon:GetCurrentProfileName() ~= profile or InCombatLockdown() then return end
            Addon:SetSetting(settingKeyR, r)
            Addon:SetSetting(settingKeyG, g)
            Addon:SetSetting(settingKeyB, b)
            color:SetColorTexture(r, g, b, 1)
            if onChange then onChange() end
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            swatchFunc = function()
                SetColor(ColorPickerFrame:GetColorRGB())
            end,
            cancelFunc = function()
                SetColor(originalR, originalG, originalB)
            end,
            r = originalR,
            g = originalG,
            b = originalB,
            hasOpacity = false,
        })
    end)

    container.SetEnabled = function(_, enabled)
        colorSwatch:SetEnabled(enabled)
    end

    RegisterSettingRefresher(RefreshColor)
    RefreshColor()
    return container
end

local function CreateConfigFrame()
    settingRefreshers = {}

    local frame = CreateFrame("Frame", "BetterRaidFramesConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(900, 700)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.TitleText:SetText("Better Raid Frames")

    local tabsPane = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    tabsPane:SetPoint("TOPLEFT", 12, -34)
    tabsPane:SetPoint("BOTTOMLEFT", 12, 8)
    tabsPane:SetWidth(138)

    local contentPane = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    contentPane:SetPoint("TOPLEFT", tabsPane, "TOPRIGHT", 8, 0)
    contentPane:SetPoint("BOTTOMRIGHT", -12, 8)

    local tabButtons = {}
    local tabPages = {}
    local tabOrder = {
        { id = "general",          label = "General" },
        { id = "raidMarkers",      label = "Raid Markers" },
        { id = "roleIcons",        label = "Role Icons" },
        { id = "names",            label = "Name" },
        { id = "partyLeader",      label = "Party Leader" },
        { id = "threatIndicator",  label = "Threat Indicator" },
        { id = "indicators",       label = "Indicators" },
    }

    local function CreateTabPage(id)
        local content = CreateFrame("Frame", nil, contentPane)
        content:SetPoint("TOPLEFT", 12, -12)
        content:SetPoint("BOTTOMRIGHT", -12, 12)
        content:Hide()

        tabPages[id] = content
        return content
    end

    local RefreshProfileDropdown
    local UpdateProfileButtonsVisibility

    local activeTabId = nil
    local featureTabsEnabled = true
    local function ShowTab(id)
        local previousTabId = activeTabId
        if tabPages[activeTabId] then
            tabPages[activeTabId]:Hide()
        end

        activeTabId = id
        frame.activeTabId = id

        if tabPages[id] then
            tabPages[id]:Show()
        end

        for _, tab in ipairs(tabOrder) do
            local btn = tabButtons[tab.id]
            if btn then
                local available = tab.id == "general" or featureTabsEnabled
                btn:SetEnabled(available and tab.id ~= id)
                btn:SetAlpha(available and 1.0 or 0.5)
            end
        end
        if previousTabId == "threatIndicator" or id == "threatIndicator" then
            Addon:RequestFeatureUpdate("threatIndicator")
        end
    end

    local function AddDropdownControl(options, dropdown)
        table.insert(options, dropdown.label)
        table.insert(options, dropdown)
    end

    local function BeginPage(content, title)
        local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 4, -2)
        heading:SetText(title)

        local divider = content:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -7)
        divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -7)
        divider:SetHeight(1)
        divider:SetColorTexture(1, 0.82, 0, 0.35)

        return -38
    end

    local function BuildAnchorControls(content, options, y, settingPrefix, anchorLabel)
        local pointDropdown = CreateDropdown(content, anchorLabel, settingPrefix .. "Point", Addon.AnchorOptions, y)
        AddDropdownControl(options, pointDropdown)
        y = y - 36

        local relativePointDropdown = CreateDropdown(content, "Frame anchor:",
            settingPrefix .. "RelativePoint", Addon.AnchorOptions, y)
        AddDropdownControl(options, relativePointDropdown)
        y = y - 36

        local xSlider = CreateHorizontalSlider(content, "Relative X:",
            settingPrefix .. "OffsetX", -250, 250, 1, y)
        table.insert(options, xSlider.container)
        y = y - 34

        local ySlider = CreateHorizontalSlider(content, "Relative Y:",
            settingPrefix .. "OffsetY", -250, 250, 1, y)
        table.insert(options, ySlider.container)
        return y - 34
    end

    local function BuildGeneralTab(content)
        local y = BeginPage(content, "General")

        local tip = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        tip:SetPoint("TOPLEFT", 16, y)
        tip:SetText("Tip: Join a Follower Dungeon to preview changes")
        tip:SetTextColor(0.6, 0.6, 0.6)
        y = y - 24

        local profileLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        profileLabel:SetPoint("TOPLEFT", 16, y)
        profileLabel:SetText("Profile:")

        local profileDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        profileDropdown:SetPoint("LEFT", profileLabel, "RIGHT", 6, 0)
        profileDropdown:SetWidth(120)

        local newBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        newBtn:SetSize(45, 20)
        newBtn:SetPoint("LEFT", profileDropdown, "RIGHT", 6, 0)
        newBtn:SetText("New")
        newBtn:SetScript("OnClick", function() StaticPopup_Show("BRF_NEW_PROFILE") end)

        local renameBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        renameBtn:SetSize(60, 20)
        renameBtn:SetPoint("LEFT", newBtn, "RIGHT", 2, 0)
        renameBtn:SetText("Rename")
        renameBtn:SetScript("OnClick", function() StaticPopup_Show("BRF_RENAME_PROFILE") end)

        local duplicateBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        duplicateBtn:SetSize(70, 20)
        duplicateBtn:SetPoint("LEFT", renameBtn, "RIGHT", 2, 0)
        duplicateBtn:SetText("Duplicate")
        duplicateBtn:SetScript("OnClick", function()
            local current = Addon:GetCurrentProfileName()
            StaticPopup_Show("BRF_DUPLICATE_PROFILE", current)
        end)

        local deleteBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        deleteBtn:SetSize(60, 20)
        deleteBtn:SetPoint("LEFT", duplicateBtn, "RIGHT", 2, 0)
        deleteBtn:SetText("Delete")
        deleteBtn:SetScript("OnClick", function()
            local current = Addon:GetCurrentProfileName()
            StaticPopup_Show("BRF_DELETE_PROFILE", current)
        end)

        RefreshProfileDropdown = function()
            profileDropdown:SetupMenu(function(_, rootDescription)
                local profiles = Addon:GetProfileList()
                for _, name in ipairs(profiles) do
                    rootDescription:CreateRadio(name,
                        function() return Addon:GetCurrentProfileName() == name end,
                        function()
                            Addon:SwitchProfile(name)
                            RefreshConfigDeferred()
                        end,
                        name
                    )
                end
            end)
        end
        RefreshProfileDropdown()

        UpdateProfileButtonsVisibility = function()
            local isDefault = Addon:GetCurrentProfileName() == "Default"
            renameBtn:SetEnabled(not isDefault)
            deleteBtn:SetEnabled(not isDefault)
        end
        UpdateProfileButtonsVisibility()

        frame.RefreshProfileDropdown = RefreshProfileDropdown
        frame.UpdateProfileButtonsVisibility = UpdateProfileButtonsVisibility

        y = y - 40

        local autoProfilesLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        autoProfilesLabel:SetPoint("TOPLEFT", 16, y)
        autoProfilesLabel:SetText("Auto profile switching:")
        y = y - 24

        local partyProfileLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        partyProfileLabel:SetPoint("TOPLEFT", 32, y)
        partyProfileLabel:SetText("Party:")

        local partyProfileDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        partyProfileDropdown:SetPoint("LEFT", partyProfileLabel, "RIGHT", 6, 0)
        partyProfileDropdown:SetWidth(140)

        local raidProfileLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        raidProfileLabel:SetPoint("LEFT", partyProfileDropdown, "RIGHT", 20, 0)
        raidProfileLabel:SetText("Raid:")

        local raidProfileDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        raidProfileDropdown:SetPoint("LEFT", raidProfileLabel, "RIGHT", 6, 0)
        raidProfileDropdown:SetWidth(140)

        local function SetupAutoProfileDropdown(dropdown, context)
            dropdown:SetupMenu(function(_, rootDescription)
                for _, option in ipairs(Addon:GetAutoProfileOptions()) do
                    rootDescription:CreateRadio(option.label,
                        function(value) return Addon:GetAssignedProfileForContext(context) == value end,
                        function(value)
                            if context == "party" then
                                Addon:SetGlobalSetting("partyProfile", value)
                            else
                                Addon:SetGlobalSetting("raidProfile", value)
                            end

                            local switched = Addon:ApplyAutomaticProfile(false)

                            if switched then
                                if frame.RefreshProfileDropdown then
                                    frame.RefreshProfileDropdown()
                                end
                                if frame.UpdateProfileButtonsVisibility then
                                    frame.UpdateProfileButtonsVisibility()
                                end
                            end

                            dropdown:GenerateMenu()
                        end,
                        option.value
                    )
                end
            end)
        end

        SetupAutoProfileDropdown(partyProfileDropdown, "party")
        SetupAutoProfileDropdown(raidProfileDropdown, "raid")
        RegisterSettingRefresher(function()
            partyProfileDropdown:GenerateMenu()
            raidProfileDropdown:GenerateMenu()
        end)

        local autoProfileNote = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        autoProfileNote:SetPoint("TOPLEFT", 32, y - 26)
        autoProfileNote:SetText("When set, BetterRaidFrames switches to that profile on party or raid roster changes.")
        autoProfileNote:SetTextColor(0.75, 0.75, 0.75)

        y = y - 62

        local raidStyleCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        raidStyleCheckbox:SetPoint("TOPLEFT", 16, y)
        raidStyleCheckbox.Text:SetText("Use Raid-Style Party Frames")
        raidStyleCheckbox.Text:SetFontObject("GameFontHighlight")

        local raidStyleWarning = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        raidStyleWarning:SetPoint("LEFT", raidStyleCheckbox.Text, "RIGHT", 6, 0)
        raidStyleWarning:SetText("Required")
        raidStyleWarning:SetTextColor(1, 0.3, 0.3)

        local function UpdateFeatureTabsEnabled()
            local isRaidStyle = Addon:GetUseRaidStylePartyFrames()
            featureTabsEnabled = isRaidStyle
            raidStyleCheckbox:SetChecked(isRaidStyle)
            raidStyleWarning:SetShown(not isRaidStyle)

            for _, tab in ipairs(tabOrder) do
                if tab.id ~= "general" then
                    local btn = tabButtons[tab.id]
                    if btn then
                        btn:SetEnabled(isRaidStyle and activeTabId ~= tab.id)
                        btn:SetAlpha(isRaidStyle and 1.0 or 0.5)
                    end
                end
            end

            if not isRaidStyle and activeTabId ~= "general" then
                ShowTab("general")
            end
        end

        frame.UpdateFeatureTabsEnabled = UpdateFeatureTabsEnabled

        raidStyleCheckbox:SetScript("OnClick", function(self)
            local enabled = self:GetChecked()
            Addon:SetUseRaidStylePartyFrames(enabled)
            C_Timer.After(0.5, UpdateFeatureTabsEnabled)
        end)

        y = y - 36

        local note = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        note:SetPoint("TOPLEFT", 16, y)
        note:SetText("Enable Raid-Style Party Frames first to configure feature tabs.")
        note:SetTextColor(0.75, 0.75, 0.75)

        y = y - 44
        CreateCheckbox(content, "Crisp frame borders", "crispFrameBorders", y)
        local borderNote = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        borderNote:SetPoint("TOPLEFT", 32, y - 32)
        borderNote:SetWidth(620)
        borderNote:SetJustifyH("LEFT")
        borderNote:SetText("Aligns health and power bar edges to screen pixels for more even separators.\nApplies out of combat. Disable to restore the original insets.")
        borderNote:SetTextColor(0.75, 0.75, 0.75)

        y = y - 88
        CreateCheckbox(content, "Show my frame while solo", "showSolo", y)
        local soloNote = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        soloNote:SetPoint("TOPLEFT", 32, y - 32)
        soloNote:SetWidth(620)
        soloNote:SetJustifyH("LEFT")
        soloNote:SetText("Keeps your Raid-Style Party Frame visible without a group, using its usual layout.\nChanges apply out of combat. Party and raid visibility stay automatic.")
        soloNote:SetTextColor(0.75, 0.75, 0.75)

        C_Timer.After(0.5, UpdateFeatureTabsEnabled)
    end

    local function BuildRaidMarkersTab(content)
        local y = BeginPage(content, "Raid Markers")
        local options = {}
        local updateOptions

        CreateCheckbox(content, "Show raid markers", "showRaidMarkers", y, function(checked)
            updateOptions(checked)
        end)
        y = y - 32

        y = BuildAnchorControls(content, options, y, "raidMarker", "Marker anchor:")

        local sizeSlider = CreateHorizontalSlider(content, "Marker size:", "raidMarkerSize", 8, 32, 1, y)
        table.insert(options, sizeSlider.container)

        updateOptions = function(enabled) SetControlsEnabled(options, enabled) end
        updateOptions(Addon:GetSetting("showRaidMarkers"))

    end

    local function BuildRoleIconsTab(content)
        local y = BeginPage(content, "Role Icons")
        RegisterSettingRefresher(Addon:BuildRoleIconOptions(content, y, {
            dropdown = CreateDropdown,
            slider = CreateHorizontalSlider,
        }))
    end

    local function BuildNamesTab(content)
        local y = BeginPage(content, "Name")
        local options = {}
        local updateOptions

        CreateCheckbox(content, "Customize names", "customizeNames", y, function(checked)
            updateOptions(checked)
        end)

        local resetNote = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        resetNote:SetPoint("TOPLEFT", 214, y - 4)
        resetNote:SetText("Disable to restore Blizzard's default style.")
        resetNote:SetTextColor(0.75, 0.75, 0.75)
        y = y - 40

        local function Section(label)
            local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            heading:SetPoint("TOPLEFT", 24, y)
            heading:SetText(label)
            table.insert(options, heading)
            y = y - 22
        end

        Section("Placement")
        local anchorDropdown = CreateDropdown(content, "Anchor:", "nameAnchor", Addon.AnchorOptions, y)
        AddDropdownControl(options, anchorDropdown)
        y = y - 36

        local xSlider = CreateHorizontalSlider(content, "X offset (px):",
            "nameOffsetX", -250, 250, 1, y)
        table.insert(options, xSlider.container)
        y = y - 32

        local ySlider = CreateHorizontalSlider(content, "Y offset (px):",
            "nameOffsetY", -250, 250, 1, y)
        table.insert(options, ySlider.container)
        y = y - 38

        local placementNote = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        placementNote:SetPoint("TOPLEFT", 24, y)
        placementNote:SetText("Offsets start at the selected anchor. +X moves right; +Y moves up.")
        placementNote:SetTextColor(0.75, 0.75, 0.75)
        table.insert(options, placementNote)
        y = y - 32

        Section("Text")
        local sizeSlider = CreateHorizontalSlider(content, "Font size (px):", "nameSize", 6, 40, 1, y)
        table.insert(options, sizeSlider.container)
        y = y - 34

        table.insert(options, CreateSubCheckbox(content, "Use class color", "nameClassColor", y, 24))
        table.insert(options, CreateSubCheckbox(content, "Hide server name", "nameHideServer", y, 300))
        y = y - 28

        table.insert(options, CreateSubCheckbox(content, "Truncate long names", "nameTruncate", y, 24))
        table.insert(options, CreateSubCheckbox(content, "Cyrillic to Latin", "nameCyrillicToLatin", y, 300))
        y = y - 28

        local maxLengthSlider = CreateHorizontalSlider(content, "Max length:",
            "nameTruncateLength", 3, 20, 1, y)
        table.insert(options, maxLengthSlider.container)
        y = y - 34

        table.insert(options, CreateSubCheckbox(content, "Hide when dead", "nameHideOnDead", y, 24))
        table.insert(options, CreateSubCheckbox(content, "Hide when offline", "nameHideOnOffline", y, 300))
        y = y - 38

        Section("Appearance")
        local outlineDropdown = CreateDropdown(content, "Outline:", "nameTextOutline",
            Addon.NameOutlineOptions, y)
        AddDropdownControl(options, outlineDropdown)
        y = y - 36

        table.insert(options, CreateSubCheckbox(content, "Text shadow", "nameTextShadow", y))
        y = y - 30

        table.insert(options, CreateColorPicker(content, "Shadow color:",
            "nameTextShadowColorR", "nameTextShadowColorG", "nameTextShadowColorB", y))
        y = y - 30

        local shadowOffsetSlider = CreateHorizontalSlider(content, "Shadow offset:",
            "nameTextShadowOffset", 1, 3, 1, y)
        table.insert(options, shadowOffsetSlider.container)

        updateOptions = function(enabled) SetControlsEnabled(options, enabled) end
        RegisterSettingRefresher(function()
            updateOptions(Addon:GetSetting("customizeNames"))
        end)
        updateOptions(Addon:GetSetting("customizeNames"))
    end

    local function BuildPartyLeaderTab(content)
        local y = BeginPage(content, "Party Leader")
        local options = {}
        local updateOptions

        CreateCheckbox(content, "Show party leader icon", "showPartyLeader", y, function(checked)
            updateOptions(checked)
        end)
        y = y - 28

        local hideInCombat = CreateSubCheckbox(content, "Hide in combat", "partyLeaderHideInCombat", y)
        table.insert(options, hideInCombat)
        y = y - 32

        y = BuildAnchorControls(content, options, y, "partyLeader", "Icon anchor:")

        local sizeSlider = CreateHorizontalSlider(content, "Size:", "partyLeaderSize", 8, 32, 1, y)
        table.insert(options, sizeSlider.container)

        updateOptions = function(enabled) SetControlsEnabled(options, enabled) end
        updateOptions(Addon:GetSetting("showPartyLeader"))
    end

    local function BuildThreatTab(content)
        local y = BeginPage(content, "Threat Indicator")
        RegisterSettingRefresher(Addon:BuildThreatOptions(content, y, {
            checkbox = CreateCheckbox,
            subCheckbox = CreateSubCheckbox,
            dropdown = CreateDropdown,
            slider = CreateHorizontalSlider,
            colorPicker = CreateColorPicker,
        }))
    end

    local builders = {
        indicators = function(content)
            local y = BeginPage(content, "Indicators")
            RegisterSettingRefresher(Addon:BuildDesignerOptions(content, y))
        end,
        general = BuildGeneralTab,
        raidMarkers = BuildRaidMarkersTab,
        roleIcons = BuildRoleIconsTab,
        names = BuildNamesTab,
        partyLeader = BuildPartyLeaderTab,
        threatIndicator = BuildThreatTab,
    }

    local prevButton = nil
    for _, tab in ipairs(tabOrder) do
        local button = CreateFrame("Button", nil, tabsPane, "UIPanelButtonTemplate")
        button:SetSize(116, 22)
        button:SetText(tab.label)
        tabButtons[tab.id] = button

        if prevButton then
            button:SetPoint("TOP", prevButton, "BOTTOM", 0, -4)
        else
            button:SetPoint("TOP", tabsPane, "TOP", 0, -8)
        end
        prevButton = button

        local content = CreateTabPage(tab.id)
        local build = builders[tab.id]
        if build then
            build(content)
        end

        button:SetScript("OnClick", function()
            ShowTab(tab.id)
        end)
    end

    local combatBlocker = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    combatBlocker:SetPoint("TOPLEFT", tabsPane, "TOPLEFT")
    combatBlocker:SetPoint("BOTTOMRIGHT", contentPane, "BOTTOMRIGHT")
    combatBlocker:SetFrameLevel(frame:GetFrameLevel() + 25)
    combatBlocker:EnableMouse(true)

    local blockerBg = combatBlocker:CreateTexture(nil, "BACKGROUND")
    blockerBg:SetAllPoints()
    blockerBg:SetColorTexture(0, 0, 0, 0.2)

    local combatWarning = combatBlocker:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    combatWarning:SetPoint("CENTER", 0, 0)
    combatWarning:SetText("Settings disabled during combat")
    combatWarning:SetTextColor(1, 0.3, 0.3)

    combatBlocker:Hide()

    frame.UpdateCombatLockdown = function(inCombat)
        combatBlocker:SetShown(inCombat)
    end

    frame.combatEventFrame = CreateFrame("Frame")
    frame.combatEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame.combatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame.combatEventFrame:SetScript("OnEvent", function(_, event)
        frame.UpdateCombatLockdown(event == "PLAYER_REGEN_DISABLED")
    end)

    frame.RefreshSettings = function()
        for _, refresh in ipairs(settingRefreshers) do
            refresh()
        end
        if frame.RefreshProfileDropdown then frame.RefreshProfileDropdown() end
        if frame.UpdateProfileButtonsVisibility then frame.UpdateProfileButtonsVisibility() end
        if frame.UpdateFeatureTabsEnabled then frame.UpdateFeatureTabsEnabled() end
    end

    frame:SetScript("OnShow", function(self)
        self.RefreshSettings()
        Addon:RequestFeatureUpdate("threatIndicator")
        self.UpdateCombatLockdown(InCombatLockdown())
    end)

    frame:SetScript("OnHide", function()
        Addon:RequestFeatureUpdate("threatIndicator")
    end)

    frame.ShowTab = ShowTab
    ShowTab("general")
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

    ConfigFrame:RefreshSettings()
end

local function SubmitNewProfile(dialog)
    local name = dialog.EditBox:GetText()
    if Addon:CreateProfile(name) then
        Addon:SwitchProfile(name)
        RefreshConfigDeferred()
        return true
    end

    print("|cff00ff00BetterRaidFrames:|r Could not create profile (name empty or already exists)")
    return false
end

local function SubmitRenameProfile(dialog)
    local newName = dialog.EditBox:GetText()
    local oldName = Addon:GetCurrentProfileName()
    if Addon:RenameProfile(oldName, newName) then
        RefreshConfigDeferred()
        return true
    end

    print("|cff00ff00BetterRaidFrames:|r Could not rename profile")
    return false
end

local function SubmitDuplicateProfile(dialog)
    local targetName = dialog.EditBox:GetText()
    local sourceName = Addon:GetCurrentProfileName()
    if Addon:DuplicateProfile(sourceName, targetName) then
        Addon:SwitchProfile(targetName)
        RefreshConfigDeferred()
        return true
    end

    print("|cff00ff00BetterRaidFrames:|r Could not duplicate profile (name empty or already exists)")
    return false
end

local function SubmitFromEditBox(editBox, submit)
    local dialog = editBox:GetParent()
    submit(dialog)
    dialog:Hide()
end

StaticPopupDialogs["BRF_NEW_PROFILE"] = {
    text = "Enter new profile name:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = SubmitNewProfile,
    OnShow = function(self)
        self.EditBox:SetText("")
        self.EditBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        SubmitFromEditBox(self, SubmitNewProfile)
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
    OnAccept = SubmitRenameProfile,
    OnShow = function(self)
        self.EditBox:SetText(Addon:GetCurrentProfileName())
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        SubmitFromEditBox(self, SubmitRenameProfile)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BRF_DUPLICATE_PROFILE"] = {
    text = "Duplicate profile '%s' to:",
    button1 = "Duplicate",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = SubmitDuplicateProfile,
    OnShow = function(self, data)
        local sourceName = data or Addon:GetCurrentProfileName()
        if self.Text and self.Text.SetFormattedText then
            self.Text:SetFormattedText("Duplicate profile '%s' to:", sourceName)
        end
        self.EditBox:SetText(sourceName .. " Copy")
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        SubmitFromEditBox(self, SubmitDuplicateProfile)
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
    OnAccept = function()
        if Addon:DeleteProfile(Addon:GetCurrentProfileName()) then
            RefreshConfigDeferred()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
