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
    frame:SetSize(920, 700)
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
    tabsPane:SetWidth(150)

    local contentPane = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    contentPane:SetPoint("TOPLEFT", tabsPane, "TOPRIGHT", 8, 0)
    contentPane:SetPoint("BOTTOMRIGHT", -12, 8)

    local tabButtons = {}
    local tabPages = {}
    local tabOrder = {
        { id = "general",          label = "General" },
        { id = "raidMarkers",      label = "Raid Markers" },
        { id = "roleIcons",        label = "Role Icons" },
        { id = "partyLeader",      label = "Party Leader" },
        { id = "friendlyAbsorb",   label = "Friendly Absorb" },
        { id = "hostileAbsorb",    label = "Hostile Absorb" },
        { id = "spellBorders",     label = "Spell Borders" },
        { id = "names",            label = "Name" },
        { id = "healthText",       label = "Health" },
        { id = "customIndicators", label = "Custom Indicators" },
        { id = "threatIndicator",  label = "Threat Indicator" },
    }

    local function CreateTabPage(id)
        local scrollFrame = CreateFrame("ScrollFrame", nil, contentPane, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 8, -8)
        scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)
        scrollFrame:Hide()

        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetWidth(700)
        content:SetHeight(1)
        scrollFrame:SetScrollChild(content)

        tabPages[id] = { scroll = scrollFrame, content = content }
        return content
    end

    local function RefreshProfileDropdown() end
    local function UpdateProfileButtonsVisibility() end

    local activeTabId = nil
    local function ShowTab(id)
        if tabPages[activeTabId] then
            tabPages[activeTabId].scroll:Hide()
        end

        activeTabId = id
        frame.activeTabId = id

        if tabPages[id] then
            tabPages[id].scroll:Show()
        end

        for _, tab in ipairs(tabOrder) do
            local btn = tabButtons[tab.id]
            if btn then
                btn:SetEnabled(tab.id ~= id)
            end
        end
    end

    local function BuildGeneralTab(content)
        local y = -10

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
        renameBtn:SetSize(55, 20)
        renameBtn:SetPoint("LEFT", newBtn, "RIGHT", 2, 0)
        renameBtn:SetText("Rename")
        renameBtn:GetFontString():SetFont(renameBtn:GetFontString():GetFont(), 10)
        renameBtn:SetScript("OnClick", function() StaticPopup_Show("BRF_RENAME_PROFILE") end)

        local deleteBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        deleteBtn:SetSize(55, 20)
        deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 2, 0)
        deleteBtn:SetText("Remove")
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
                            Addon:RefreshConfig()
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

        content:SetHeight(math.abs(y) + 40)
        C_Timer.After(0.5, UpdateFeatureTabsEnabled)
    end

    local function BuildRaidMarkersTab(content)
        local y = -10
        local options = {}
        local updateOptions

        local checkbox = CreateCheckbox(content, "Show raid markers", "showRaidMarkers", y, function(checked)
            updateOptions(checked)
            Addon:RefreshRaidMarkers()
        end)
        y = y - 28

        local xSlider = CreateHorizontalSlider(content, "Marker X:", "raidMarkerX", -250, 250, 1, y,
            function() Addon:RefreshRaidMarkers() end)
        table.insert(options, xSlider.container)
        y = y - 61

        local ySlider = CreateHorizontalSlider(content, "Marker Y:", "raidMarkerY", -250, 250, 1, y,
            function() Addon:RefreshRaidMarkers() end)
        table.insert(options, ySlider.container)
        y = y - 46

        local sizeSlider = CreateHorizontalSlider(content, "Marker size:", "raidMarkerSize", 8, 32, 1, y,
            function() Addon:RefreshRaidMarkers() end)
        table.insert(options, sizeSlider.container)

        updateOptions = function(enabled) SetControlsEnabled(options, enabled) end
        updateOptions(Addon:GetSetting("showRaidMarkers"))

        content:SetHeight(math.abs(y) + 60)
    end

    local function BuildRoleIconsTab(content)
        local y = -10
        CreateDropdown(content, "Show role icons:", "showRoleIcons", Addon.RoleIconOptions, y)
        content:SetHeight(90)
    end

    local function BuildPartyLeaderTab(content)
        local y = -10
        local options = {}
        local updateOptions

        CreateCheckbox(content, "Show party leader icon", "showPartyLeader", y, function(checked)
            updateOptions(checked)
            Addon:RefreshPartyLeaders()
        end)
        y = y - 28

        local hideInCombat = CreateSubCheckbox(content, "Hide in combat", "partyLeaderHideInCombat", y,
            function() Addon:RefreshPartyLeaders() end)
        table.insert(options, hideInCombat)
        y = y - 61

        local xSlider = CreateHorizontalSlider(content, "X:", "partyLeaderX", -250, 250, 1, y,
            function() Addon:RefreshPartyLeaders() end)
        table.insert(options, xSlider.container)
        y = y - 26

        local ySlider = CreateHorizontalSlider(content, "Y:", "partyLeaderY", -250, 250, 1, y,
            function() Addon:RefreshPartyLeaders() end)
        table.insert(options, ySlider.container)
        y = y - 26

        local sizeSlider = CreateHorizontalSlider(content, "Size:", "partyLeaderSize", 8, 32, 1, y,
            function() Addon:RefreshPartyLeaders() end)
        table.insert(options, sizeSlider.container)

        updateOptions = function(enabled) SetControlsEnabled(options, enabled) end
        updateOptions(Addon:GetSetting("showPartyLeader"))
        content:SetHeight(math.abs(y) + 60)
    end

    local function BuildFriendlyAbsorbTab(content)
        local y = -10
        local options = {}
        local updateOptions

        CreateCheckbox(content, "Show friendly absorb (shields)", "showFriendlyAbsorb", y, function(checked)
            updateOptions(checked)
            Addon:RefreshFriendlyAbsorbs()
        end)
        y = y - 26

        local opacity = CreateHorizontalSlider(content, "Opacity:", "friendlyAbsorbOpacity", 0.1, 1.0, 0.1, y,
            function() Addon:RefreshFriendlyAbsorbs() end, true)
        table.insert(options, opacity.container)
        y = y - 24

        local color = CreateColorPicker(content, "Color:", "friendlyAbsorbColorR", "friendlyAbsorbColorG",
            "friendlyAbsorbColorB", y, function() Addon:RefreshFriendlyAbsorbs() end)
        table.insert(options, color)

        updateOptions = function(enabled) SetControlsEnabled(options, enabled) end
        updateOptions(Addon:GetSetting("showFriendlyAbsorb"))
        content:SetHeight(math.abs(y) + 60)
    end

    local function BuildHostileAbsorbTab(content)
        local y = -10
        local options = {}
        local updateOptions

        CreateCheckbox(content, "Show hostile absorb (heal debuffs)", "showHostileAbsorb", y, function(checked)
            updateOptions(checked)
            Addon:RefreshHostileAbsorbs()
        end)
        y = y - 26

        local opacity = CreateHorizontalSlider(content, "Opacity:", "hostileAbsorbOpacity", 0.1, 1.0, 0.1, y,
            function() Addon:RefreshHostileAbsorbs() end, true)
        table.insert(options, opacity.container)
        y = y - 24

        local color = CreateColorPicker(content, "Color:", "hostileAbsorbColorR", "hostileAbsorbColorG",
            "hostileAbsorbColorB", y, function() Addon:RefreshHostileAbsorbs() end)
        table.insert(options, color)

        updateOptions = function(enabled) SetControlsEnabled(options, enabled) end
        updateOptions(Addon:GetSetting("showHostileAbsorb"))
        content:SetHeight(math.abs(y) + 60)
    end

    local function BuildSpellBordersTab(content)
        local y = -10
        CreateCheckbox(content, "Hide borders on spell icons", "hideAuraBorders", y,
            function() Addon:RefreshAuraBorders() end)
        content:SetHeight(math.abs(y) + 50)
    end

    local function BuildNamesTab(content)
        local y = -10
        local options = {}

        local xSlider = CreateHorizontalSlider(content, "X:", "nameX", -250, 250, 1, y,
            function() Addon:RefreshNames() end)
        table.insert(options, xSlider.container)
        y = y - 26

        local ySlider = CreateHorizontalSlider(content, "Y:", "nameY", -250, 250, 1, y,
            function() Addon:RefreshNames() end)
        table.insert(options, ySlider.container)
        y = y - 26

        local sizeSlider = CreateHorizontalSlider(content, "Size:", "nameSize", 6, 20, 1, y,
            function() Addon:RefreshNames() end)
        table.insert(options, sizeSlider.container)
        y = y - 30

        local hideServer = CreateSubCheckbox(content, "Hide server name", "nameHideServer", y,
            function() Addon:RefreshNames() end)
        table.insert(options, hideServer)
        y = y - 25

        local truncate = CreateSubCheckbox(content, "Truncate long names", "nameTruncate", y,
            function() Addon:RefreshNames() end)
        table.insert(options, truncate)
        y = y - 30

        local truncSlider = CreateHorizontalSlider(content, "Max length:", "nameTruncateLength", 3, 12, 1, y,
            function() Addon:RefreshNames() end)
        table.insert(options, truncSlider.container)
        y = y - 30

        local classColor = CreateSubCheckbox(content, "Class color", "nameClassColor", y,
            function() Addon:RefreshNames() end)
        table.insert(options, classColor)
        y = y - 25

        local cyr = CreateSubCheckbox(content, "Convert Cyrillic to Latin", "nameCyrillicToLatin", y,
            function() Addon:RefreshNames() end)
        table.insert(options, cyr)
        y = y - 25

        local dead = CreateSubCheckbox(content, "Hide name when dead", "nameHideOnDead", y,
            function() Addon:RefreshNames() end)
        table.insert(options, dead)
        y = y - 25

        local offline = CreateSubCheckbox(content, "Hide name when offline", "nameHideOnOffline", y,
            function() Addon:RefreshNames() end)
        table.insert(options, offline)
        y = y - 25

        local shadow = CreateSubCheckbox(content, "Text shadow", "nameTextShadow", y, function() Addon:RefreshNames() end)
        table.insert(options, shadow)
        y = y - 15

        local shadowColor = CreateColorPicker(content, "", "nameTextShadowColorR", "nameTextShadowColorG",
            "nameTextShadowColorB", y, function() Addon:RefreshNames() end)
        table.insert(options, shadowColor)
        y = y - 15

        local shadowOffset = CreateHorizontalSlider(content, "Offset:", "nameTextShadowOffset", 1, 3, 1, y,
            function() Addon:RefreshNames() end)
        table.insert(options, shadowOffset.container)
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
        outlineDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("None", function(v) return Addon:GetSetting("nameTextOutline") == v end,
                function(v)
                    Addon:SetSetting("nameTextOutline", v)
                    Addon:RefreshNames()
                    outlineDropdown:GenerateMenu()
                end, "NONE")
            rootDescription:CreateRadio("Thin", function(v) return Addon:GetSetting("nameTextOutline") == v end,
                function(v)
                    Addon:SetSetting("nameTextOutline", v)
                    Addon:RefreshNames()
                    outlineDropdown:GenerateMenu()
                end, "OUTLINE")
            rootDescription:CreateRadio("Thick", function(v) return Addon:GetSetting("nameTextOutline") == v end,
                function(v)
                    Addon:SetSetting("nameTextOutline", v)
                    Addon:RefreshNames()
                    outlineDropdown:GenerateMenu()
                end, "THICKOUTLINE")
        end)

        table.insert(options, outlineContainer)

        content:SetHeight(math.abs(y) + 70)
    end

    local function BuildHealthTextTab(content)
        local y = -10
        local options = {}

        local note = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        note:SetPoint("TOPLEFT", 16, y)
        note:SetText("Tip: Enable Blizzard health text at\nOptions > Interface > Raid Frames > Display Health Text")
        note:SetTextColor(0.9, 0.75, 0.2)
        table.insert(options, note)

        y = y - 26

        local xSlider = CreateHorizontalSlider(content, "X:", "healthTextX", -250, 250, 1, y,
            function() Addon:RefreshHealthTexts() end)
        table.insert(options, xSlider.container)
        y = y - 26

        local ySlider = CreateHorizontalSlider(content, "Y:", "healthTextY", -250, 250, 1, y,
            function() Addon:RefreshHealthTexts() end)
        table.insert(options, ySlider.container)
        y = y - 26

        local sizeSlider = CreateHorizontalSlider(content, "Size:", "healthTextSize", 6, 20, 1, y,
            function() Addon:RefreshHealthTexts() end)
        table.insert(options, sizeSlider.container)
        y = y - 30

        local color = CreateColorPicker(content, "Color:", "healthTextColorR", "healthTextColorG", "healthTextColorB", y,
            function() Addon:RefreshHealthTexts() end)
        table.insert(options, color)
        y = y - 30

        local classColor = CreateSubCheckbox(content, "Class color", "healthTextClassColor", y,
            function() Addon:RefreshHealthTexts() end)
        table.insert(options, classColor)
        y = y - 25

        local shadow = CreateSubCheckbox(content, "Text shadow", "healthTextShadow", y,
            function() Addon:RefreshHealthTexts() end)
        table.insert(options, shadow)
        y = y - 15

        local shadowColor = CreateColorPicker(content, "", "healthTextShadowColorR", "healthTextShadowColorG",
            "healthTextShadowColorB", y, function() Addon:RefreshHealthTexts() end)
        table.insert(options, shadowColor)
        y = y - 15

        local shadowOffset = CreateHorizontalSlider(content, "Offset:", "healthTextShadowOffset", 1, 3, 1, y,
            function() Addon:RefreshHealthTexts() end)
        table.insert(options, shadowOffset.container)
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
        outlineDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("None", function(v) return Addon:GetSetting("healthTextOutline") == v end,
                function(v)
                    Addon:SetSetting("healthTextOutline", v)
                    Addon:RefreshHealthTexts()
                    outlineDropdown:GenerateMenu()
                end, "NONE")
            rootDescription:CreateRadio("Thin", function(v) return Addon:GetSetting("healthTextOutline") == v end,
                function(v)
                    Addon:SetSetting("healthTextOutline", v)
                    Addon:RefreshHealthTexts()
                    outlineDropdown:GenerateMenu()
                end, "OUTLINE")
            rootDescription:CreateRadio("Thick", function(v) return Addon:GetSetting("healthTextOutline") == v end,
                function(v)
                    Addon:SetSetting("healthTextOutline", v)
                    Addon:RefreshHealthTexts()
                    outlineDropdown:GenerateMenu()
                end, "THICKOUTLINE")
        end)

        table.insert(options, outlineContainer)

        content:SetHeight(math.abs(y) + 70)
    end

    local function BuildThreatTab(content)
        local y = -10
        local options = {}
        local updateOptions

        local note = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        note:SetPoint("TOPLEFT", 16, y)
        note:SetText(
            "Tip: You can disable Blizzard aggro highlight at\nOptions > Interface > Raid Frames > Display Aggro Highlight")
        note:SetTextColor(0.9, 0.75, 0.2)
        y = y - 26

        CreateCheckbox(content, "Show threat indicator", "showThreatIndicator", y, function(checked)
            updateOptions(checked)
            Addon:RefreshThreatIndicators()
        end)
        y = y - 28

        local blinking = CreateSubCheckbox(content, "Blinking", "threatIndicatorBlink", y,
            function() Addon:RefreshThreatIndicators() end)
        table.insert(options, blinking)
        y = y - 25

        local xSlider = CreateHorizontalSlider(content, "X:", "threatIndicatorX", -250, 250, 1, y,
            function() Addon:RefreshThreatIndicators() end)
        table.insert(options, xSlider.container)
        y = y - 26

        local ySlider = CreateHorizontalSlider(content, "Y:", "threatIndicatorY", -250, 250, 1, y,
            function() Addon:RefreshThreatIndicators() end)
        table.insert(options, ySlider.container)
        y = y - 26

        local sizeSlider = CreateHorizontalSlider(content, "Size:", "threatIndicatorSize", 4, 20, 1, y,
            function() Addon:RefreshThreatIndicators() end)
        table.insert(options, sizeSlider.container)

        updateOptions = function(enabled) SetControlsEnabled(options, enabled) end
        updateOptions(Addon:GetSetting("showThreatIndicator"))
        content:SetHeight(math.abs(y) + 60)
    end

    local function BuildCustomIndicatorsTab(content)
        local y = -10
        local options = {}
        local selectedId = nil
        local indicatorDropdown
        local typeDropdown
        local directionDropdown
        local barTextureDropdown
        local barBorderDropdown
        local spellDropdown
        local previewAllCheckbox
        local cooldownSwipeCheckbox
        local invertSwipeCheckbox
        local cooldownTextCheckbox
        local globalToggle
        local colorContainer
        local backgroundColorContainer
        local borderColorContainer
        local durationColorContainer
        local stackColorContainer
        local expiringColorContainer
        local widthSlider
        local heightSlider
        local sizeSlider
        local alphaSlider
        local scaleSlider
        local xSlider
        local ySlider
        local zSlider
        local borderSizeSlider
        local borderPaddingSlider
        local borderInsetSlider
        local stackMinimumSlider
        local durationXSlider
        local durationYSlider
        local stackXSlider
        local stackYSlider
        local expiringThresholdSlider
        local duplicateBtn
        local deleteBtn
        local anchorDropdown
        local orientationDropdown
        local durationAnchorDropdown
        local stackAnchorDropdown
        local expiringModeDropdown
        local showBorderCheckbox
        local showDurationCheckbox
        local durationColorByTimeCheckbox
        local showStacksCheckbox
        local expiringCheckbox
        local RefreshEditorState

        local function Clamp(v, minV, maxV)
            if type(v) ~= "number" then return minV end
            if v < minV then return minV end
            if v > maxV then return maxV end
            return v
        end

        local function GetItemById(cfg, id)
            if not cfg or type(cfg.items) ~= "table" then return nil end
            for _, item in ipairs(cfg.items) do
                if item.id == id then
                    return item
                end
            end
            return nil
        end

        local function GetSelectedItem()
            local cfg = Addon:GetCustomIndicatorsConfig()
            if not selectedId and cfg.items[1] then
                selectedId = cfg.items[1].id
            end
            local item = GetItemById(cfg, selectedId)
            if not item and cfg.items[1] then
                selectedId = cfg.items[1].id
                item = cfg.items[1]
            end
            return cfg, item
        end

        local function UpdatePreviewTarget()
            local _, item = GetSelectedItem()
            if item then
                Addon:SetCustomIndicatorPreviewId(item.id)
            else
                Addon:SetCustomIndicatorPreviewId(nil)
            end
            Addon:RefreshCustomIndicators()
        end

        local function CreateValueSlider(parent, label, minVal, maxVal, step, yOffset, onChange)
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 32, yOffset)
            container:SetPoint("TOPRIGHT", -16, yOffset)
            container:SetHeight(36)

            local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            labelText:SetPoint("LEFT", 0, 0)
            labelText:SetWidth(90)
            labelText:SetJustifyH("LEFT")
            labelText:SetText(label)

            local sliderFrame = CreateFrame("Frame", nil, container, "MinimalSliderWithSteppersTemplate")
            sliderFrame:SetPoint("LEFT", labelText, "RIGHT", 8, 0)
            sliderFrame:SetPoint("RIGHT", -10, 0)
            sliderFrame:SetHeight(16)

            local steps = math.floor((maxVal - minVal) / step + 0.5)
            local formatters = {}
            formatters[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                MinimalSliderWithSteppersMixin.Label.Right,
                function(val) return tostring(math.floor(val + 0.5)) end
            )

            sliderFrame.initInProgress = true
            sliderFrame:Init(minVal, minVal, maxVal, steps, formatters)
            if sliderFrame.MinText then sliderFrame.MinText:Hide() end
            if sliderFrame.MaxText then sliderFrame.MaxText:Hide() end
            sliderFrame.initInProgress = false

            if sliderFrame.Slider then
                sliderFrame.Slider:HookScript("OnValueChanged", function(_, value)
                    if sliderFrame.initInProgress then return end
                    local quantized = math.floor(value / step + 0.5) * step
                    onChange(quantized)
                end)
            end

            function sliderFrame:SetSliderValue(val)
                self.initInProgress = true
                self:SetValue(val)
                self.initInProgress = false
            end

            sliderFrame.container = container
            return sliderFrame
        end

        local function RefreshIndicatorDropdown()
            if not indicatorDropdown then return end
            indicatorDropdown:SetupMenu(function(_, rootDescription)
                local cfg = Addon:GetCustomIndicatorsConfig()
                if #cfg.items == 0 then
                    rootDescription:CreateButton("No indicators", function() end)
                    return
                end

                for _, item in ipairs(cfg.items) do
                    local spellName = "No spell"
                    if item.spellId > 0 then
                        local resolvedName = Addon:GetCustomIndicatorSpellDisplay(item.spellId)
                        spellName = resolvedName or ("Spell " .. tostring(item.spellId))
                    end
                    local typeLabel = (item.type == "icon" and "Icon") or
                        (item.type == "square" and "Square") or
                        (item.type == "border" and "Border") or "Bar"
                    local title
                    if item.spellId > 0 then
                        title = string.format("%d. %s - %s (%d)", _, typeLabel, spellName, item.spellId)
                    else
                        title = string.format("%d. %s - No spell selected", _, typeLabel)
                    end
                    rootDescription:CreateRadio(title,
                        function(v) return selectedId == v end,
                        function(v)
                            selectedId = v
                            UpdatePreviewTarget()
                            if RefreshEditorState then RefreshEditorState() end
                        end,
                        item.id
                    )
                end
            end)
        end

        local function UpdateSelectedItem(updates)
            local _, item = GetSelectedItem()
            if not item then return end
            Addon:UpdateCustomIndicatorItem(item.id, updates)
            Addon:RefreshCustomIndicators()
            RefreshIndicatorDropdown()
            if RefreshEditorState then RefreshEditorState() end
        end

        local function RefreshTypeDropdown(item)
            if not typeDropdown then return end
            typeDropdown:SetupMenu(function(_, rootDescription)
                local choices = {
                    { label = "Bar",        value = "bar" },
                    { label = "Icon",       value = "icon" },
                    { label = "Square",     value = "square" },
                    { label = "Border",     value = "border" },
                }
                for _, choice in ipairs(choices) do
                    rootDescription:CreateRadio(choice.label,
                        function(v) return item and item.type == v end,
                        function(v)
                            UpdateSelectedItem({ type = v })
                        end,
                        choice.value
                    )
                end
            end)
        end

        local function RefreshAnchorDropdown(dropdown, item, key)
            if not dropdown then return end
            local options = Addon:GetCustomIndicatorAnchorOptions()
            dropdown:SetupMenu(function(_, rootDescription)
                for _, option in ipairs(options) do
                    rootDescription:CreateRadio(option.label,
                        function(v) return item and item[key] == v end,
                        function(v)
                            local updates = {}
                            updates[key] = v
                            UpdateSelectedItem(updates)
                        end,
                        option.value
                    )
                end
            end)
        end

        local function RefreshOrientationDropdown(item)
            if not orientationDropdown then return end
            orientationDropdown:SetupMenu(function(_, rootDescription)
                local choices = {
                    { label = "Horizontal", value = "HORIZONTAL" },
                    { label = "Vertical", value = "VERTICAL" },
                }
                for _, choice in ipairs(choices) do
                    rootDescription:CreateRadio(choice.label,
                        function(v) return item and item.orientation == v end,
                        function(v)
                            local updates = { orientation = v }
                            if v == "VERTICAL" and item and item.direction == "LEFT_TO_RIGHT" then
                                updates.direction = "BOTTOM_TO_TOP"
                            elseif v == "VERTICAL" and item and item.direction == "RIGHT_TO_LEFT" then
                                updates.direction = "TOP_TO_BOTTOM"
                            elseif v == "HORIZONTAL" and item and item.direction == "TOP_TO_BOTTOM" then
                                updates.direction = "RIGHT_TO_LEFT"
                            elseif v == "HORIZONTAL" and item and item.direction == "BOTTOM_TO_TOP" then
                                updates.direction = "LEFT_TO_RIGHT"
                            end
                            UpdateSelectedItem(updates)
                        end,
                        choice.value
                    )
                end
            end)
        end

        local function RefreshExpiringModeDropdown(item)
            if not expiringModeDropdown then return end
            expiringModeDropdown:SetupMenu(function(_, rootDescription)
                local choices = {
                    { label = "Percent", value = "PERCENT" },
                    { label = "Seconds", value = "SECONDS" },
                }
                for _, choice in ipairs(choices) do
                    rootDescription:CreateRadio(choice.label,
                        function(v) return item and item.expiringThresholdMode == v end,
                        function(v)
                            UpdateSelectedItem({ expiringThresholdMode = v })
                        end,
                        choice.value
                    )
                end
            end)
        end

        local function RefreshDirectionDropdown(item)
            if not directionDropdown then return end
            directionDropdown:SetupMenu(function(_, rootDescription)
                local choices = {
                    { label = "Right to left", value = "RIGHT_TO_LEFT" },
                    { label = "Left to right", value = "LEFT_TO_RIGHT" },
                    { label = "Top to bottom", value = "TOP_TO_BOTTOM" },
                    { label = "Bottom to top", value = "BOTTOM_TO_TOP" },
                }
                for _, choice in ipairs(choices) do
                    rootDescription:CreateRadio(choice.label,
                        function(v) return item and item.direction == v end,
                        function(v)
                            UpdateSelectedItem({ direction = v })
                        end,
                        choice.value
                    )
                end
            end)
        end

        local function RefreshBarTextureDropdown(item)
            if not barTextureDropdown then return end
            local textureOptions = Addon:GetCustomIndicatorBarTextureOptions()
            barTextureDropdown:SetupMenu(function(_, rootDescription)
                for _, option in ipairs(textureOptions) do
                    rootDescription:CreateRadio(option.label,
                        function(v) return item and item.barTexture == v end,
                        function(v)
                            UpdateSelectedItem({ barTexture = v })
                        end,
                        option.value
                    )
                end
            end)
        end

        local function RefreshBarBorderDropdown(item)
            if not barBorderDropdown then return end
            local borderOptions = Addon:GetCustomIndicatorBarBorderOptions()
            barBorderDropdown:SetupMenu(function(_, rootDescription)
                for _, option in ipairs(borderOptions) do
                    rootDescription:CreateRadio(option.label,
                        function(v) return item and item.barBorder == v end,
                        function(v)
                            UpdateSelectedItem({ barBorder = v })
                        end,
                        option.value
                    )
                end
            end)
        end

        local function RefreshSpellDropdown(item)
            if not spellDropdown then return end
            local spellOptions = Addon:GetCustomIndicatorSpellOptions()
            spellDropdown:SetupMenu(function(_, rootDescription)
                for _, option in ipairs(spellOptions) do
                    rootDescription:CreateRadio(option.label,
                        function(v) return item and item.spellId == v end,
                        function(v)
                            UpdateSelectedItem({ spellId = v })
                        end,
                        option.value
                    )
                end
            end)
        end

        RefreshEditorState = function()
            local cfg, item = GetSelectedItem()
            local hasItem = item ~= nil
            local active = hasItem and cfg.enabled

            if globalToggle then globalToggle:SetChecked(cfg.enabled) end
            if previewAllCheckbox then previewAllCheckbox:SetChecked(Addon:IsCustomIndicatorPreviewAll()) end
            if duplicateBtn then duplicateBtn:SetEnabled(active) end
            if deleteBtn then deleteBtn:SetEnabled(active) end
            SetControlsEnabled(options, active)

            if not hasItem then
                if colorContainer then colorContainer:SetShown(true) end
                if borderColorContainer then borderColorContainer:SetShown(true) end
                if directionDropdown then directionDropdown:SetShown(true) end
                if barTextureDropdown then barTextureDropdown:SetShown(true) end
                if barBorderDropdown then barBorderDropdown:SetShown(true) end
                if borderSizeSlider then borderSizeSlider.container:SetShown(true) end
                if borderPaddingSlider then borderPaddingSlider.container:SetShown(true) end
                if cooldownSwipeCheckbox then cooldownSwipeCheckbox:SetShown(true) end
                if invertSwipeCheckbox then invertSwipeCheckbox:SetShown(true) end
                if cooldownTextCheckbox then cooldownTextCheckbox:SetShown(true) end
                return
            end

            if widthSlider then widthSlider:SetSliderValue(item.width) end
            if heightSlider then heightSlider:SetSliderValue(item.height) end
            if sizeSlider then sizeSlider:SetSliderValue(item.size or item.width or 18) end
            if alphaSlider then alphaSlider:SetSliderValue((item.alpha or 1) * 100) end
            if scaleSlider then scaleSlider:SetSliderValue((item.scale or 1) * 100) end
            if xSlider then xSlider:SetSliderValue(item.offsetX or 0) end
            if ySlider then ySlider:SetSliderValue(item.offsetY or 0) end
            if zSlider then zSlider:SetSliderValue(item.frameLevelOffset or 0) end
            if borderSizeSlider then borderSizeSlider:SetSliderValue(item.borderSize or 8) end
            if borderPaddingSlider then borderPaddingSlider:SetSliderValue(item.borderPadding or 0) end
            if borderInsetSlider then borderInsetSlider:SetSliderValue(item.borderInset or 0) end
            if stackMinimumSlider then stackMinimumSlider:SetSliderValue(item.stackMinimum or 2) end
            if durationXSlider then durationXSlider:SetSliderValue(item.durationX or 0) end
            if durationYSlider then durationYSlider:SetSliderValue(item.durationY or 0) end
            if stackXSlider then stackXSlider:SetSliderValue(item.stackX or 0) end
            if stackYSlider then stackYSlider:SetSliderValue(item.stackY or 0) end
            if expiringThresholdSlider then expiringThresholdSlider:SetSliderValue(item.expiringThreshold or 30) end

            RefreshTypeDropdown(item)
            RefreshAnchorDropdown(anchorDropdown, item, "anchor")
            RefreshDirectionDropdown(item)
            RefreshOrientationDropdown(item)
            RefreshBarTextureDropdown(item)
            RefreshBarBorderDropdown(item)
            RefreshSpellDropdown(item)
            RefreshAnchorDropdown(durationAnchorDropdown, item, "durationAnchor")
            RefreshAnchorDropdown(stackAnchorDropdown, item, "stackAnchor")
            RefreshExpiringModeDropdown(item)

            local supportsBarStyle = item.type == "bar"
            local supportsPlaced = item.type ~= "border"
            local supportsColor = item.type ~= "icon"
            local supportsTextureBorder = item.type == "bar" or item.type == "square"
            local supportsAnyBorder = Addon:CustomIndicatorTypeSupportsBorder(item.type)
            local supportsCooldown = item.type == "icon" or item.type == "square"
            local supportsStacks = item.type == "icon" or item.type == "square"
            local supportsDuration = item.type == "icon" or item.type == "square" or item.type == "bar" or item.type == "border"

            if colorContainer then
                colorContainer:SetShown(true)
                if colorContainer.swatchColor then
                    colorContainer.swatchColor:SetColorTexture(item.colorR, item.colorG, item.colorB, 1)
                    colorContainer.swatchColor:SetAlpha((supportsColor or item.type == "border") and 1 or 0.4)
                end
                if colorContainer.colorSwatch then
                    colorContainer.colorSwatch:SetEnabled(supportsColor or item.type == "border")
                    colorContainer.colorSwatch:SetAlpha((supportsColor or item.type == "border") and 1 or 0.4)
                end
            end

            if backgroundColorContainer then
                backgroundColorContainer:SetShown(supportsBarStyle)
                if backgroundColorContainer.swatchColor then
                    backgroundColorContainer.swatchColor:SetColorTexture(item.barBackgroundColorR or 0,
                        item.barBackgroundColorG or 0, item.barBackgroundColorB or 0, 1)
                end
            end

            if anchorDropdown then anchorDropdown:SetShown(supportsPlaced) end
            if directionDropdown then
                directionDropdown:SetShown(supportsBarStyle)
                directionDropdown:SetEnabled(supportsBarStyle)
            end
            if orientationDropdown then
                orientationDropdown:SetShown(supportsBarStyle)
                orientationDropdown:SetEnabled(supportsBarStyle)
            end

            if barTextureDropdown then
                barTextureDropdown:SetShown(supportsBarStyle)
                barTextureDropdown:SetEnabled(supportsBarStyle)
            end
            if barBorderDropdown then
                barBorderDropdown:SetShown(supportsTextureBorder)
                barBorderDropdown:SetEnabled(supportsTextureBorder)
            end
            if showBorderCheckbox then
                showBorderCheckbox:SetShown(supportsAnyBorder)
                showBorderCheckbox:SetChecked(item.showBorder ~= false)
                showBorderCheckbox:SetEnabled(supportsAnyBorder)
            end
            if borderSizeSlider then
                borderSizeSlider.container:SetShown(supportsAnyBorder)
                borderSizeSlider:SetEnabled(supportsAnyBorder)
            end
            if borderPaddingSlider then
                borderPaddingSlider.container:SetShown(supportsTextureBorder)
                borderPaddingSlider:SetEnabled(supportsTextureBorder)
            end
            if borderInsetSlider then
                borderInsetSlider.container:SetShown(supportsAnyBorder)
                borderInsetSlider:SetEnabled(supportsAnyBorder)
            end

            if borderColorContainer then
                borderColorContainer:SetShown(supportsAnyBorder)
                if borderColorContainer.swatchColor then
                    borderColorContainer.swatchColor:SetColorTexture(item.borderColorR or 1, item.borderColorG or 1,
                        item.borderColorB or 1, 1)
                    borderColorContainer.swatchColor:SetAlpha(supportsAnyBorder and 1 or 0.4)
                end
                if borderColorContainer.colorSwatch then
                    borderColorContainer.colorSwatch:SetEnabled(supportsAnyBorder)
                    borderColorContainer.colorSwatch:SetAlpha(supportsAnyBorder and 1 or 0.4)
                end
            end

            if cooldownSwipeCheckbox then
                cooldownSwipeCheckbox:SetShown(supportsCooldown)
                cooldownSwipeCheckbox:SetEnabled(supportsCooldown)
                cooldownSwipeCheckbox:SetChecked(item.showCooldownSwipe ~= false)
                cooldownSwipeCheckbox:SetAlpha(supportsCooldown and 1 or 0.4)
            end

            if invertSwipeCheckbox then
                invertSwipeCheckbox:SetShown(supportsCooldown)
                invertSwipeCheckbox:SetEnabled(supportsCooldown)
                invertSwipeCheckbox:SetChecked(item.invertCooldownSwipe == true)
                invertSwipeCheckbox:SetAlpha(supportsCooldown and 1 or 0.4)
            end

            if cooldownTextCheckbox then
                cooldownTextCheckbox:SetShown(supportsCooldown)
                cooldownTextCheckbox:SetEnabled(supportsCooldown)
                cooldownTextCheckbox:SetChecked(item.hideSwipe ~= true)
                cooldownTextCheckbox:SetAlpha(supportsCooldown and 1 or 0.4)
            end

            if widthSlider then widthSlider.container:SetShown(supportsBarStyle) end
            if heightSlider then heightSlider.container:SetShown(supportsBarStyle) end
            if sizeSlider then sizeSlider.container:SetShown(item.type == "icon" or item.type == "square") end
            if alphaSlider then alphaSlider.container:SetShown(true) end
            if scaleSlider then scaleSlider.container:SetShown(supportsPlaced) end
            if xSlider then xSlider.container:SetShown(supportsPlaced) end
            if ySlider then ySlider.container:SetShown(supportsPlaced) end

            if showDurationCheckbox then
                showDurationCheckbox:SetShown(supportsDuration)
                showDurationCheckbox:SetChecked(item.showDuration ~= false)
            end
            if durationAnchorDropdown then durationAnchorDropdown:SetShown(supportsDuration) end
            if durationXSlider then durationXSlider.container:SetShown(supportsDuration) end
            if durationYSlider then durationYSlider.container:SetShown(supportsDuration) end
            if durationColorByTimeCheckbox then
                durationColorByTimeCheckbox:SetShown(supportsDuration)
                durationColorByTimeCheckbox:SetChecked(item.durationColorByTime ~= false)
            end
            if durationColorContainer then
                durationColorContainer:SetShown(supportsDuration)
                if durationColorContainer.swatchColor then
                    durationColorContainer.swatchColor:SetColorTexture(item.durationColorR or 1, item.durationColorG or 1,
                        item.durationColorB or 1, 1)
                    durationColorContainer.swatchColor:SetAlpha((item.durationColorByTime ~= false) and 0.4 or 1)
                end
                if durationColorContainer.colorSwatch then
                    durationColorContainer.colorSwatch:SetEnabled(item.durationColorByTime == false)
                    durationColorContainer.colorSwatch:SetAlpha((item.durationColorByTime ~= false) and 0.4 or 1)
                end
            end

            if showStacksCheckbox then
                showStacksCheckbox:SetShown(supportsStacks)
                showStacksCheckbox:SetChecked(item.showStacks ~= false)
            end
            if stackMinimumSlider then stackMinimumSlider.container:SetShown(supportsStacks) end
            if stackAnchorDropdown then stackAnchorDropdown:SetShown(supportsStacks) end
            if stackXSlider then stackXSlider.container:SetShown(supportsStacks) end
            if stackYSlider then stackYSlider.container:SetShown(supportsStacks) end
            if stackColorContainer then
                stackColorContainer:SetShown(supportsStacks)
                if stackColorContainer.swatchColor then
                    stackColorContainer.swatchColor:SetColorTexture(item.stackColorR or 1, item.stackColorG or 1,
                        item.stackColorB or 1, 1)
                end
            end

            if expiringCheckbox then
                expiringCheckbox:SetShown(true)
                expiringCheckbox:SetChecked(item.expiringEnabled == true)
            end
            if expiringThresholdSlider then expiringThresholdSlider.container:SetShown(true) end
            if expiringModeDropdown then expiringModeDropdown:SetShown(true) end
            if expiringColorContainer then
                expiringColorContainer:SetShown(true)
                if expiringColorContainer.swatchColor then
                    expiringColorContainer.swatchColor:SetColorTexture(item.expiringColorR or 1, item.expiringColorG or 0.2,
                        item.expiringColorB or 0.2, 1)
                end
            end
        end

        globalToggle = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        globalToggle:SetPoint("TOPLEFT", 16, y)
        globalToggle.Text:SetText("Enable custom indicators")
        globalToggle.Text:SetFontObject("GameFontHighlight")
        globalToggle:SetScript("OnClick", function(self)
            local cfg = Addon:GetCustomIndicatorsConfig()
            cfg.enabled = self:GetChecked()
            Addon:SetCustomIndicatorsConfig(cfg)
            Addon:RefreshCustomIndicators()
            RefreshEditorState()
        end)
        y = y - 26

        local hideBlizzAurasToggle = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        hideBlizzAurasToggle:SetPoint("TOPLEFT", 16, y)
        hideBlizzAurasToggle.Text:SetText("Hide Blizzard buffs on raid frames")
        hideBlizzAurasToggle.Text:SetFontObject("GameFontHighlight")
        hideBlizzAurasToggle:SetChecked(Addon:GetSetting("hideBlizzardAuras") == true)
        hideBlizzAurasToggle:SetScript("OnClick", function(self)
            Addon:SetSetting("hideBlizzardAuras", self:GetChecked())
        end)
        y = y - 32

        previewAllCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        previewAllCheckbox:SetPoint("TOPLEFT", 16, y)
        previewAllCheckbox.Text:SetText("Preview all indicators in config")
        previewAllCheckbox.Text:SetFontObject("GameFontHighlight")
        previewAllCheckbox:SetChecked(Addon:IsCustomIndicatorPreviewAll())
        previewAllCheckbox:SetScript("OnClick", function(self)
            Addon:SetCustomIndicatorPreviewAll(self:GetChecked())
            if not self:GetChecked() then
                UpdatePreviewTarget()
            else
                Addon:RefreshCustomIndicators()
            end
            RefreshEditorState()
        end)
        y = y - 32

        local addBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        addBtn:SetSize(105, 22)
        addBtn:SetPoint("TOPLEFT", 16, y)
        addBtn:SetText("Add Indicator")
        addBtn:SetScript("OnClick", function()
            selectedId = Addon:CreateCustomIndicatorItem("bar")
            UpdatePreviewTarget()
            RefreshIndicatorDropdown()
            RefreshEditorState()
        end)

        duplicateBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        duplicateBtn:SetSize(78, 22)
        duplicateBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
        duplicateBtn:SetText("Duplicate")
        duplicateBtn:SetScript("OnClick", function()
            local cfg, item = GetSelectedItem()
            if not cfg.enabled or not item then return end
            selectedId = Addon:DuplicateCustomIndicatorItem(item.id)
            UpdatePreviewTarget()
            RefreshIndicatorDropdown()
            RefreshEditorState()
        end)

        deleteBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        deleteBtn:SetSize(70, 22)
        deleteBtn:SetPoint("LEFT", duplicateBtn, "RIGHT", 6, 0)
        deleteBtn:SetText("Delete")
        deleteBtn:SetScript("OnClick", function()
            local cfg, item = GetSelectedItem()
            if not cfg.enabled or not item then return end
            Addon:DeleteCustomIndicatorItem(item.id)
            local cfgAfter = Addon:GetCustomIndicatorsConfig()
            selectedId = cfgAfter.items[1] and cfgAfter.items[1].id or nil
            UpdatePreviewTarget()
            RefreshIndicatorDropdown()
            RefreshEditorState()
        end)
        y = y - 40

        local selectLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        selectLabel:SetPoint("TOPLEFT", 16, y)
        selectLabel:SetText("Indicator:")

        indicatorDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        indicatorDropdown:SetPoint("LEFT", selectLabel, "RIGHT", 8, 0)
        indicatorDropdown:SetWidth(300)
        RefreshIndicatorDropdown()
        y = y - 46

        local spellLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        spellLabel:SetPoint("TOPLEFT", 16, y)
        spellLabel:SetText("Spell:")

        spellDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        spellDropdown:SetPoint("LEFT", spellLabel, "RIGHT", 8, 0)
        spellDropdown:SetWidth(320)
        table.insert(options, spellDropdown)
        y = y - 34

        local typeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        typeLabel:SetPoint("TOPLEFT", 16, y)
        typeLabel:SetText("Type:")

        typeDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        typeDropdown:SetPoint("LEFT", typeLabel, "RIGHT", 34, 0)
        typeDropdown:SetWidth(180)
        table.insert(options, typeDropdown)
        y = y - 34

        local anchorLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        anchorLabel:SetPoint("TOPLEFT", 16, y)
        anchorLabel:SetText("Anchor:")

        anchorDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        anchorDropdown:SetPoint("LEFT", anchorLabel, "RIGHT", 20, 0)
        anchorDropdown:SetWidth(180)
        table.insert(options, anchorDropdown)
        y = y - 34

        local directionLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        directionLabel:SetPoint("TOPLEFT", 16, y)
        directionLabel:SetText("Direction:")

        directionDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        directionDropdown:SetPoint("LEFT", directionLabel, "RIGHT", 8, 0)
        directionDropdown:SetWidth(220)
        table.insert(options, directionDropdown)
        y = y - 34

        local orientationLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        orientationLabel:SetPoint("TOPLEFT", 16, y)
        orientationLabel:SetText("Orientation:")

        orientationDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        orientationDropdown:SetPoint("LEFT", orientationLabel, "RIGHT", 8, 0)
        orientationDropdown:SetWidth(220)
        table.insert(options, orientationDropdown)
        y = y - 34

        local textureLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        textureLabel:SetPoint("TOPLEFT", 16, y)
        textureLabel:SetText("Texture:")

        barTextureDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        barTextureDropdown:SetPoint("LEFT", textureLabel, "RIGHT", 15, 0)
        barTextureDropdown:SetWidth(220)
        table.insert(options, barTextureDropdown)
        y = y - 34

        local borderLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        borderLabel:SetPoint("TOPLEFT", 16, y)
        borderLabel:SetText("Border:")

        barBorderDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        barBorderDropdown:SetPoint("LEFT", borderLabel, "RIGHT", 20, 0)
        barBorderDropdown:SetWidth(220)
        table.insert(options, barBorderDropdown)
        y = y - 34

        borderSizeSlider = CreateValueSlider(content, "Border size:", 1, 24, 1, y, function(v)
            UpdateSelectedItem({ borderSize = Clamp(math.floor(v + 0.5), 1, 24) })
        end)
        table.insert(options, borderSizeSlider.container)
        y = y - 30

        borderPaddingSlider = CreateValueSlider(content, "Border pad:", -20, 20, 1, y, function(v)
            UpdateSelectedItem({ borderPadding = Clamp(math.floor(v + 0.5), -20, 20) })
        end)
        table.insert(options, borderPaddingSlider.container)
        y = y - 34

        borderInsetSlider = CreateValueSlider(content, "Border inset:", -20, 20, 1, y, function(v)
            UpdateSelectedItem({ borderInset = Clamp(math.floor(v + 0.5), -20, 20) })
        end)
        table.insert(options, borderInsetSlider.container)
        y = y - 34

        showBorderCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        showBorderCheckbox:SetPoint("TOPLEFT", 32, y)
        showBorderCheckbox.Text:SetText("Show border")
        showBorderCheckbox.Text:SetFontObject("GameFontHighlight")
        showBorderCheckbox:SetScript("OnClick", function(self)
            UpdateSelectedItem({ showBorder = self:GetChecked() })
        end)
        table.insert(options, showBorderCheckbox)
        y = y - 28

        colorContainer = CreateColorPicker(content, "Color:", "_dummy_unused_customIndicatorColorR",
            "_dummy_unused_customIndicatorColorG", "_dummy_unused_customIndicatorColorB", y, function() end)
        colorContainer.colorSwatch:SetScript("OnClick", function()
            local _, item = GetSelectedItem()
            if not item then return end

            local currentR = item.colorR or 1
            local currentG = item.colorG or 1
            local currentB = item.colorB or 1

            local info = {
                swatchFunc = function()
                    local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    UpdateSelectedItem({ colorR = newR, colorG = newG, colorB = newB })
                    RefreshEditorState()
                end,
                cancelFunc = function()
                    UpdateSelectedItem({ colorR = currentR, colorG = currentG, colorB = currentB })
                    RefreshEditorState()
                end,
                r = currentR,
                g = currentG,
                b = currentB,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)
        table.insert(options, colorContainer)
        y = y - 34

        backgroundColorContainer = CreateColorPicker(content, "Bar bg:", "_dummy_unused_customIndicatorBgR",
            "_dummy_unused_customIndicatorBgG", "_dummy_unused_customIndicatorBgB", y, function() end)
        backgroundColorContainer.colorSwatch:SetScript("OnClick", function()
            local _, item = GetSelectedItem()
            if not item then return end

            local currentR = item.barBackgroundColorR or 0
            local currentG = item.barBackgroundColorG or 0
            local currentB = item.barBackgroundColorB or 0

            local info = {
                swatchFunc = function()
                    local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    UpdateSelectedItem({ barBackgroundColorR = newR, barBackgroundColorG = newG, barBackgroundColorB = newB })
                    RefreshEditorState()
                end,
                cancelFunc = function()
                    UpdateSelectedItem({ barBackgroundColorR = currentR, barBackgroundColorG = currentG, barBackgroundColorB = currentB })
                    RefreshEditorState()
                end,
                r = currentR,
                g = currentG,
                b = currentB,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)
        table.insert(options, backgroundColorContainer)
        y = y - 34

        borderColorContainer = CreateColorPicker(content, "Border color:", "_dummy_unused_customIndicatorBorderColorR",
            "_dummy_unused_customIndicatorBorderColorG", "_dummy_unused_customIndicatorBorderColorB", y, function() end)
        borderColorContainer.colorSwatch:SetScript("OnClick", function()
            local _, item = GetSelectedItem()
            if not item then return end

            local currentR = item.borderColorR or 1
            local currentG = item.borderColorG or 1
            local currentB = item.borderColorB or 1

            local info = {
                swatchFunc = function()
                    local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    UpdateSelectedItem({ borderColorR = newR, borderColorG = newG, borderColorB = newB })
                    RefreshEditorState()
                end,
                cancelFunc = function()
                    UpdateSelectedItem({ borderColorR = currentR, borderColorG = currentG, borderColorB = currentB })
                    RefreshEditorState()
                end,
                r = currentR,
                g = currentG,
                b = currentB,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)
        table.insert(options, borderColorContainer)
        y = y - 42

        durationColorContainer = CreateColorPicker(content, "Duration color:", "_dummy_unused_customIndicatorDurationR",
            "_dummy_unused_customIndicatorDurationG", "_dummy_unused_customIndicatorDurationB", y, function() end)
        durationColorContainer.colorSwatch:SetScript("OnClick", function()
            local _, item = GetSelectedItem()
            if not item then return end

            local currentR = item.durationColorR or 1
            local currentG = item.durationColorG or 1
            local currentB = item.durationColorB or 1

            local info = {
                swatchFunc = function()
                    local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    UpdateSelectedItem({ durationColorR = newR, durationColorG = newG, durationColorB = newB })
                    RefreshEditorState()
                end,
                cancelFunc = function()
                    UpdateSelectedItem({ durationColorR = currentR, durationColorG = currentG, durationColorB = currentB })
                    RefreshEditorState()
                end,
                r = currentR,
                g = currentG,
                b = currentB,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)
        table.insert(options, durationColorContainer)
        y = y - 34

        stackColorContainer = CreateColorPicker(content, "Stack color:", "_dummy_unused_customIndicatorStackR",
            "_dummy_unused_customIndicatorStackG", "_dummy_unused_customIndicatorStackB", y, function() end)
        stackColorContainer.colorSwatch:SetScript("OnClick", function()
            local _, item = GetSelectedItem()
            if not item then return end

            local currentR = item.stackColorR or 1
            local currentG = item.stackColorG or 1
            local currentB = item.stackColorB or 1

            local info = {
                swatchFunc = function()
                    local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    UpdateSelectedItem({ stackColorR = newR, stackColorG = newG, stackColorB = newB })
                    RefreshEditorState()
                end,
                cancelFunc = function()
                    UpdateSelectedItem({ stackColorR = currentR, stackColorG = currentG, stackColorB = currentB })
                    RefreshEditorState()
                end,
                r = currentR,
                g = currentG,
                b = currentB,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)
        table.insert(options, stackColorContainer)
        y = y - 34

        expiringColorContainer = CreateColorPicker(content, "Expiring color:", "_dummy_unused_customIndicatorExpiringR",
            "_dummy_unused_customIndicatorExpiringG", "_dummy_unused_customIndicatorExpiringB", y, function() end)
        expiringColorContainer.colorSwatch:SetScript("OnClick", function()
            local _, item = GetSelectedItem()
            if not item then return end

            local currentR = item.expiringColorR or 1
            local currentG = item.expiringColorG or 0.2
            local currentB = item.expiringColorB or 0.2

            local info = {
                swatchFunc = function()
                    local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    UpdateSelectedItem({ expiringColorR = newR, expiringColorG = newG, expiringColorB = newB })
                    RefreshEditorState()
                end,
                cancelFunc = function()
                    UpdateSelectedItem({ expiringColorR = currentR, expiringColorG = currentG, expiringColorB = currentB })
                    RefreshEditorState()
                end,
                r = currentR,
                g = currentG,
                b = currentB,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)
        table.insert(options, expiringColorContainer)
        y = y - 42

        widthSlider = CreateValueSlider(content, "Width:", 4, 250, 1, y, function(v)
            UpdateSelectedItem({ width = Clamp(math.floor(v + 0.5), 4, 250) })
        end)
        table.insert(options, widthSlider.container)
        y = y - 26

        heightSlider = CreateValueSlider(content, "Height:", 2, 250, 1, y, function(v)
            UpdateSelectedItem({ height = Clamp(math.floor(v + 0.5), 2, 250) })
        end)
        table.insert(options, heightSlider.container)
        y = y - 26

        sizeSlider = CreateValueSlider(content, "Size:", 4, 250, 1, y, function(v)
            UpdateSelectedItem({ size = Clamp(math.floor(v + 0.5), 4, 250) })
        end)
        table.insert(options, sizeSlider.container)
        y = y - 26

        alphaSlider = CreateValueSlider(content, "Alpha %:", 0, 100, 1, y, function(v)
            UpdateSelectedItem({ alpha = Clamp(v / 100, 0, 1) })
        end)
        table.insert(options, alphaSlider.container)
        y = y - 26

        scaleSlider = CreateValueSlider(content, "Scale %:", 20, 400, 1, y, function(v)
            UpdateSelectedItem({ scale = Clamp(v / 100, 0.2, 4) })
        end)
        table.insert(options, scaleSlider.container)
        y = y - 26

        xSlider = CreateValueSlider(content, "X:", -250, 250, 1, y, function(v)
            UpdateSelectedItem({ offsetX = Clamp(math.floor(v + 0.5), -250, 250) })
        end)
        table.insert(options, xSlider.container)
        y = y - 26

        ySlider = CreateValueSlider(content, "Y:", -250, 250, 1, y, function(v)
            UpdateSelectedItem({ offsetY = Clamp(math.floor(v + 0.5), -250, 250) })
        end)
        table.insert(options, ySlider.container)
        y = y - 30

        zSlider = CreateValueSlider(content, "Z:", -30, 30, 1, y, function(v)
            UpdateSelectedItem({ frameLevelOffset = Clamp(math.floor(v + 0.5), -30, 30) })
        end)
        table.insert(options, zSlider.container)
        y = y - 30

        cooldownSwipeCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        cooldownSwipeCheckbox:SetPoint("TOPLEFT", 32, y)
        cooldownSwipeCheckbox.Text:SetText("Show swipe")
        cooldownSwipeCheckbox.Text:SetFontObject("GameFontHighlight")
        cooldownSwipeCheckbox:SetScript("OnClick", function(self)
            UpdateSelectedItem({ showCooldownSwipe = self:GetChecked() })
        end)
        table.insert(options, cooldownSwipeCheckbox)

        invertSwipeCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        invertSwipeCheckbox:SetPoint("LEFT", cooldownSwipeCheckbox, "RIGHT", 120, 0)
        invertSwipeCheckbox.Text:SetText("Inverse Swipe")
        invertSwipeCheckbox.Text:SetFontObject("GameFontHighlight")
        invertSwipeCheckbox:SetScript("OnClick", function(self)
            UpdateSelectedItem({ invertCooldownSwipe = self:GetChecked() })
        end)
        table.insert(options, invertSwipeCheckbox)

        y = y - 24

        cooldownTextCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        cooldownTextCheckbox:SetPoint("TOPLEFT", 32, y)
        cooldownTextCheckbox.Text:SetText("Hide swipe")
        cooldownTextCheckbox.Text:SetFontObject("GameFontHighlight")
        cooldownTextCheckbox:SetScript("OnClick", function(self)
            UpdateSelectedItem({ hideSwipe = self:GetChecked(), showCooldownSwipe = not self:GetChecked() })
        end)
        table.insert(options, cooldownTextCheckbox)
        y = y - 28

        showDurationCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        showDurationCheckbox:SetPoint("TOPLEFT", 32, y)
        showDurationCheckbox.Text:SetText("Show duration text")
        showDurationCheckbox.Text:SetFontObject("GameFontHighlight")
        showDurationCheckbox:SetScript("OnClick", function(self)
            UpdateSelectedItem({ showDuration = self:GetChecked() })
        end)
        table.insert(options, showDurationCheckbox)
        y = y - 24

        local durationAnchorLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        durationAnchorLabel:SetPoint("TOPLEFT", 16, y)
        durationAnchorLabel:SetText("Duration anchor:")
        durationAnchorDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        durationAnchorDropdown:SetPoint("LEFT", durationAnchorLabel, "RIGHT", 8, 0)
        durationAnchorDropdown:SetWidth(180)
        table.insert(options, durationAnchorDropdown)
        y = y - 34

        durationXSlider = CreateValueSlider(content, "Duration X:", -100, 100, 1, y, function(v)
            UpdateSelectedItem({ durationX = Clamp(math.floor(v + 0.5), -100, 100) })
        end)
        table.insert(options, durationXSlider.container)
        y = y - 26

        durationYSlider = CreateValueSlider(content, "Duration Y:", -100, 100, 1, y, function(v)
            UpdateSelectedItem({ durationY = Clamp(math.floor(v + 0.5), -100, 100) })
        end)
        table.insert(options, durationYSlider.container)
        y = y - 26

        durationColorByTimeCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        durationColorByTimeCheckbox:SetPoint("TOPLEFT", 32, y)
        durationColorByTimeCheckbox.Text:SetText("Duration color by time")
        durationColorByTimeCheckbox.Text:SetFontObject("GameFontHighlight")
        durationColorByTimeCheckbox:SetScript("OnClick", function(self)
            UpdateSelectedItem({ durationColorByTime = self:GetChecked() })
            RefreshEditorState()
        end)
        table.insert(options, durationColorByTimeCheckbox)
        y = y - 28

        showStacksCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        showStacksCheckbox:SetPoint("TOPLEFT", 32, y)
        showStacksCheckbox.Text:SetText("Show stack text")
        showStacksCheckbox.Text:SetFontObject("GameFontHighlight")
        showStacksCheckbox:SetScript("OnClick", function(self)
            UpdateSelectedItem({ showStacks = self:GetChecked() })
        end)
        table.insert(options, showStacksCheckbox)
        y = y - 24

        stackMinimumSlider = CreateValueSlider(content, "Min stacks:", 1, 99, 1, y, function(v)
            UpdateSelectedItem({ stackMinimum = Clamp(math.floor(v + 0.5), 1, 99) })
        end)
        table.insert(options, stackMinimumSlider.container)
        y = y - 26

        local stackAnchorLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        stackAnchorLabel:SetPoint("TOPLEFT", 16, y)
        stackAnchorLabel:SetText("Stack anchor:")
        stackAnchorDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        stackAnchorDropdown:SetPoint("LEFT", stackAnchorLabel, "RIGHT", 20, 0)
        stackAnchorDropdown:SetWidth(180)
        table.insert(options, stackAnchorDropdown)
        y = y - 34

        stackXSlider = CreateValueSlider(content, "Stack X:", -100, 100, 1, y, function(v)
            UpdateSelectedItem({ stackX = Clamp(math.floor(v + 0.5), -100, 100) })
        end)
        table.insert(options, stackXSlider.container)
        y = y - 26

        stackYSlider = CreateValueSlider(content, "Stack Y:", -100, 100, 1, y, function(v)
            UpdateSelectedItem({ stackY = Clamp(math.floor(v + 0.5), -100, 100) })
        end)
        table.insert(options, stackYSlider.container)
        y = y - 28

        expiringCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        expiringCheckbox:SetPoint("TOPLEFT", 32, y)
        expiringCheckbox.Text:SetText("Enable expiring color")
        expiringCheckbox.Text:SetFontObject("GameFontHighlight")
        expiringCheckbox:SetScript("OnClick", function(self)
            UpdateSelectedItem({ expiringEnabled = self:GetChecked() })
        end)
        table.insert(options, expiringCheckbox)
        y = y - 24

        local expiringModeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        expiringModeLabel:SetPoint("TOPLEFT", 16, y)
        expiringModeLabel:SetText("Expiring mode:")
        expiringModeDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        expiringModeDropdown:SetPoint("LEFT", expiringModeLabel, "RIGHT", 12, 0)
        expiringModeDropdown:SetWidth(180)
        table.insert(options, expiringModeDropdown)
        y = y - 34

        expiringThresholdSlider = CreateValueSlider(content, "Expire at:", 1, 300, 1, y, function(v)
            UpdateSelectedItem({ expiringThreshold = Clamp(math.floor(v + 0.5), 1, 300) })
        end)
        table.insert(options, expiringThresholdSlider.container)
        y = y - 30

        content:SetHeight(math.abs(y) + 160)
        RefreshIndicatorDropdown()
        UpdatePreviewTarget()
        RefreshEditorState()
    end

    local builders = {
        general = BuildGeneralTab,
        raidMarkers = BuildRaidMarkersTab,
        roleIcons = BuildRoleIconsTab,
        partyLeader = BuildPartyLeaderTab,
        friendlyAbsorb = BuildFriendlyAbsorbTab,
        hostileAbsorb = BuildHostileAbsorbTab,
        spellBorders = BuildSpellBordersTab,
        names = BuildNamesTab,
        healthText = BuildHealthTextTab,
        customIndicators = BuildCustomIndicatorsTab,
        threatIndicator = BuildThreatTab,
    }

    local prevButton = nil
    for _, tab in ipairs(tabOrder) do
        local button = CreateFrame("Button", nil, tabsPane, "UIPanelButtonTemplate")
        button:SetSize(128, 22)
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

    frame:SetScript("OnShow", function(self)
        Addon:UpdateAllFrames()
        if self.RefreshProfileDropdown then self.RefreshProfileDropdown() end
        if self.UpdateProfileButtonsVisibility then self.UpdateProfileButtonsVisibility() end
        if self.UpdateFeatureTabsEnabled then self.UpdateFeatureTabsEnabled() end
        self.UpdateCombatLockdown(InCombatLockdown())
    end)

    frame:SetScript("OnHide", function()
        Addon:UpdateAllFrames()
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

    -- Recreate the config frame to reflect new profile settings
    if ConfigFrame:IsShown() then
        local activeTabId = ConfigFrame.activeTabId
        ConfigFrame:Hide()
        ConfigFrame = nil
        ConfigFrame = CreateConfigFrame()
        ConfigFrame:Show()
        if activeTabId and ConfigFrame.ShowTab then
            ConfigFrame:ShowTab(activeTabId)
        end
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
