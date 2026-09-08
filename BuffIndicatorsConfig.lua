local _, Addon = ...

local function Label(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

function Addon:BuildBuffIndicatorsOptions(content, y)
    local Refresh, ScrollToRow
    local controlRefreshers = {}
    local selectedSpellID
    local selectedProfile = Addon:GetCurrentProfileName()

    local function GetSelection()
        if selectedProfile ~= Addon:GetCurrentProfileName() then return end
        for index, entry in ipairs(Addon:GetSetting("buffIndicators")) do
            if entry.spellID == selectedSpellID then return index, entry end
        end
    end

    local function ChangeSelected(changes)
        if InCombatLockdown() then return end
        local index = GetSelection()
        if not index then return end
        Addon:ChangeBuffIndicator(index, changes)
        Refresh()
    end

    local function CreateSlider(parent, label, key, minimum, maximum, normalize, x, offsetY, width, suffix, labelWidth)
        Label(parent, label, x, offsetY)
        local slider = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
        slider:SetPoint("TOPLEFT", x + (labelWidth or 100), offsetY)
        slider:SetSize(width, 16)
        local refreshing = false
        local formatters = {
            [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                MinimalSliderWithSteppersMixin.Label.Right,
                function(value) return string.format("%d%s", math.floor(value + 0.5), suffix or "") end
            ),
        }
        slider:Init(normalize(Addon, nil), minimum, maximum, maximum - minimum, formatters)
        if slider.MinText then slider.MinText:Hide() end
        if slider.MaxText then slider.MaxText:Hide() end
        slider.Slider:HookScript("OnValueChanged", function(_, value)
            if refreshing or InCombatLockdown() then return end
            ChangeSelected({ [key] = normalize(Addon, value) })
        end)
        controlRefreshers[#controlRefreshers + 1] = function()
            refreshing = true
            local _, entry = GetSelection()
            slider:SetValue(normalize(Addon, entry and entry[key]))
            refreshing = false
        end
        return slider
    end

    local function CreateChoice(parent, label, key, options, normalize, x, offsetY, labelWidth, width)
        Label(parent, label, x, offsetY - 5)
        local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("TOPLEFT", x + labelWidth, offsetY)
        dropdown:SetWidth(width)
        dropdown:SetupMenu(function(_, root)
            local _, entry = GetSelection()
            if not entry then return end
            local profile = selectedProfile
            local choices = type(options) == "function" and options(entry) or options
            for _, option in ipairs(choices) do
                root:CreateRadio(option.label,
                    function(value) return normalize(Addon, entry[key]) == value end,
                    function(value)
                        -- A menu may still be open when the selected buff changes.
                        if selectedProfile ~= profile or selectedSpellID ~= entry.spellID then return end
                        ChangeSelected({ [key] = value })
                    end,
                    option.value)
            end
        end)
        controlRefreshers[#controlRefreshers + 1] = function() dropdown:GenerateMenu() end
    end

    local description = Label(content,
        "Track buff duration with a coloured segment for each buff.", 16, y)
    description:SetWidth(440)

    local preview = CreateFrame("Frame", nil, content)
    preview:SetPoint("TOPLEFT", 16, y - 24)
    preview:SetSize(180, 46)
    local background = preview:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 1)
    local health = preview:CreateTexture(nil, "ARTWORK")
    health:SetPoint("TOPLEFT", 1, -1)
    health:SetPoint("BOTTOMRIGHT", -1, 1)
    health:SetColorTexture(0.22, 0.38, 0.29, 1)
    local previewLabel = Label(preview, "Preview", 6, -20)
    previewLabel:ClearAllPoints()
    previewLabel:SetPoint("CENTER")
    local previewNote = Label(content, "Duration preview\nUse Settings beside a buff to edit its display.", 208, y - 28)
    previewNote:SetWidth(228)
    previewNote:SetTextColor(0.65, 0.65, 0.65)
    local segments = {}
    local previewElapsed = 0
    local function PreviewValue(segment)
        local progress = previewElapsed / 4
        return segment.direction == "REMAINING" and (1 - progress) or progress
    end
    preview:SetScript("OnShow", function() previewElapsed = 0 end)
    preview:SetScript("OnUpdate", function(_, elapsed)
        -- A repeating sample timer, independent of any real aura information.
        previewElapsed = (previewElapsed + elapsed) % 4
        for _, segment in ipairs(segments) do segment:SetValue(PreviewValue(segment)) end
    end)

    local inputLabel = Label(content, "Buff name or spell ID:", 16, y - 86)
    local input = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", inputLabel, "BOTTOMLEFT", 5, -8)
    input:SetSize(295, 24)
    input:SetAutoFocus(false)
    input:SetMaxLetters(100)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local add = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    add:SetPoint("LEFT", input, "RIGHT", 10, 0)
    add:SetSize(110, 24)
    add:SetText("Add Buff")

    local status = Label(content, "", 16, y - 136)
    status:SetWidth(440)
    local rows = {}

    local function AddBuff()
        if InCombatLockdown() then return end
        local added, message = Addon:AddBuffIndicator(input:GetText())
        if added then
            local entries = Addon:GetSetting("buffIndicators")
            selectedSpellID = entries[#entries].spellID
            selectedProfile = Addon:GetCurrentProfileName()
            input:SetText("")
            input:ClearFocus()
            status:SetText("")
            Refresh()
            ScrollToRow(rows[#entries])
        else
            status:SetText(message)
            status:SetTextColor(1, 0.35, 0.3)
        end
    end
    add:SetScript("OnClick", AddBuff)
    input:SetScript("OnEnterPressed", AddBuff)

    local listScroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 12, y - 162)
    listScroll:SetPoint("BOTTOMRIGHT", -26, 48)
    local list = CreateFrame("Frame", nil, listScroll)
    list:SetSize(440, 1)
    listScroll:SetScrollChild(list)
    local editor = CreateFrame("Frame", nil, list)
    editor:SetSize(440, 110)
    editor:Hide()

    CreateSlider(editor, "Thickness:", "thickness", 1, Addon.MAX_BUFF_INDICATOR_HEIGHT,
        Addon.NormalizeBuffIndicatorHeight, 4, -4, 132, " px", 100)

    CreateChoice(editor, "Progress:", "direction", function(entry)
        local vertical = Addon:IsBuffIndicatorVertical(entry.position)
        return {
            { value = "ELAPSED", label = vertical and "Fill (top to bottom)" or "Fill (left to right)" },
            { value = "REMAINING", label = vertical and "Drain (bottom to top)" or "Drain (right to left)" },
        }
    end, Addon.NormalizeBuffIndicatorDirection, 4, -38, 68, 184)
    CreateChoice(editor, "Position:", "position", {
        { value = "TOP", label = "Top" },
        { value = "BOTTOM", label = "Bottom" },
        { value = "LEFT", label = "Left" },
        { value = "RIGHT", label = "Right" },
    }, Addon.NormalizeBuffIndicatorPosition, 272, -38, 62, 96)

    local levelSlider = CreateSlider(editor, "Frame level:", "frameLevel",
        Addon.MIN_BUFF_INDICATOR_FRAME_LEVEL, Addon.MAX_BUFF_INDICATOR_FRAME_LEVEL,
        Addon.NormalizeBuffIndicatorFrameLevel, 4, -76, 284)
    levelSlider:HookScript("OnEnter", function()
        GameTooltip:SetOwner(levelSlider, "ANCHOR_RIGHT")
        GameTooltip:SetText("Frame level")
        GameTooltip:AddLine("Relative to the raid frame. Higher values draw above other elements.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    levelSlider:HookScript("OnLeave", function() GameTooltip:Hide() end)

    ScrollToRow = function(row)
        local scroll = listScroll:GetVerticalScroll()
        local bottom = row.offset + row:GetHeight()
        if row.offset < scroll then
            listScroll:SetVerticalScroll(row.offset)
        elseif bottom > scroll + listScroll:GetHeight() then
            listScroll:SetVerticalScroll(math.max(0, bottom - listScroll:GetHeight()))
        end
    end

    for index = 1, self.MAX_BUFF_INDICATORS do
        local row = CreateFrame("Frame", nil, list)
        row:SetPoint("TOPLEFT", 0, 0)
        row:SetSize(440, 32)

        local enabled = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        enabled:SetPoint("TOPLEFT", 0, 0)
        enabled:SetScript("OnClick", function(button)
            if InCombatLockdown() then return end
            Addon:ChangeBuffIndicator(index, { enabled = button:GetChecked() })
            Refresh()
        end)
        row.enabled = enabled

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 30, -4)
        icon:SetSize(20, 20)
        row.icon = icon
        local name = Label(row, "", 56, -8)
        name:SetWidth(122)
        name:SetWordWrap(false)
        row.name = name

        local mine = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        mine:SetPoint("TOPLEFT", 180, 0)
        mine.Text:SetText("Mine")
        mine.Text:SetFontObject("GameFontHighlightSmall")
        mine:SetScript("OnClick", function(button)
            if InCombatLockdown() then return end
            Addon:ChangeBuffIndicator(index, { mineOnly = button:GetChecked() })
            Refresh()
        end)
        row.mine = mine

        local swatch = CreateFrame("Button", nil, row)
        swatch:SetPoint("TOPLEFT", 246, -4)
        swatch:SetSize(20, 20)
        local border = swatch:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0, 0, 0, 1)
        local color = swatch:CreateTexture(nil, "ARTWORK")
        color:SetPoint("TOPLEFT", 1, -1)
        color:SetPoint("BOTTOMRIGHT", -1, 1)
        row.color = color
        swatch:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            local entry = Addon:GetSetting("buffIndicators")[index]
            if not entry then return end
            local profile = Addon:GetCurrentProfileName()
            local function SetColor(r, g, b)
                -- The colour picker can outlive the row or the selected profile.
                local current = Addon:GetSetting("buffIndicators")[index]
                if InCombatLockdown() or Addon:GetCurrentProfileName() ~= profile
                    or not current or current.spellID ~= entry.spellID then return end
                Addon:ChangeBuffIndicator(index, { r = r, g = g, b = b })
                Refresh()
            end
            ColorPickerFrame:SetupColorPickerAndShow({
                r = entry.r, g = entry.g, b = entry.b,
                hasOpacity = false,
                swatchFunc = function() SetColor(ColorPickerFrame:GetColorRGB()) end,
                cancelFunc = function() SetColor(entry.r, entry.g, entry.b) end,
            })
        end)

        local edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        edit:SetPoint("TOPLEFT", 278, -3)
        edit:SetSize(72, 22)
        edit:SetText("Settings")
        edit:SetScript("OnClick", function()
            local entry = Addon:GetSetting("buffIndicators")[index]
            if not entry then return end
            selectedSpellID = selectedSpellID ~= entry.spellID and entry.spellID or nil
            selectedProfile = Addon:GetCurrentProfileName()
            Refresh()
            ScrollToRow(row)
        end)
        row.edit = edit

        local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        remove:SetPoint("TOPLEFT", 360, -3)
        remove:SetSize(68, 22)
        remove:SetText("Remove")
        remove:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            Addon:RemoveBuffIndicator(index)
            Refresh()
        end)

        row:SetScript("OnEnter", function()
            local entry = Addon:GetSetting("buffIndicators")[index]
            if not entry then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            local spell = C_Spell.GetSpellInfo(entry.spellID)
            GameTooltip:SetText(spell and spell.name or "Buff")
            GameTooltip:AddLine("Spell ID: " .. entry.spellID, 1, 1, 1)
            GameTooltip:AddLine("Mine: only buffs cast by you or your pet.", 1, 1, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:EnableMouse(true)
        rows[index] = row

        segments[index] = Addon:CreateBuffIndicatorBar(preview)
    end

    local note = Label(content,
        "Mine = your casts only. Uncheck to include anyone's buffs.\nUse the buff's spell ID if it differs from the cast spell.",
        16, 0)
    note:ClearAllPoints()
    note:SetPoint("BOTTOMLEFT", 16, 6)
    note:SetWidth(440)
    note:SetTextColor(0.65, 0.65, 0.65)

    Refresh = function()
        local entries = Addon:GetSetting("buffIndicators")
        local profile = Addon:GetCurrentProfileName()
        if selectedProfile ~= profile then
            selectedProfile, selectedSpellID = profile, nil
            listScroll:SetVerticalScroll(0)
        end
        local selectedIndex = GetSelection()
        if not selectedIndex then selectedSpellID = nil end
        local layouts = Addon:GetBuffIndicatorLayouts(entries, 180, 46, preview:GetFrameLevel())
        for _, refresh in ipairs(controlRefreshers) do refresh() end
        editor:SetShown(selectedIndex ~= nil)
        local offset = 0
        for index, row in ipairs(rows) do
            local entry = entries[index]
            row:SetShown(entry ~= nil)
            segments[index]:Hide()
            if entry then
                local expanded = index == selectedIndex
                row.offset = offset
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -offset)
                row:SetHeight(expanded and 146 or 32)
                offset = offset + row:GetHeight()
                row.edit:SetText(expanded and "Close" or "Settings")
                if expanded then
                    editor:ClearAllPoints()
                    editor:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -32)
                end
                local spell = C_Spell.GetSpellInfo(entry.spellID)
                row.name:SetText(spell and spell.name or ("Spell " .. entry.spellID))
                row.icon:SetTexture(spell and spell.iconID or 134400)
                row.enabled:SetChecked(entry.enabled)
                row.mine:SetChecked(entry.mineOnly)
                row.color:SetColorTexture(entry.r, entry.g, entry.b, 1)
                row.name:SetAlpha(entry.enabled and 1 or 0.5)
                row.icon:SetAlpha(entry.enabled and 1 or 0.5)
                if entry.enabled then
                    local segment = segments[index]
                    local layout = layouts[index]
                    Addon:LayoutBuffIndicator(segment, preview, layout)
                    Addon:SetBuffIndicatorBarOrientation(segment, layout.position)
                    segment:SetFrameLevel(layout.frameLevel + 2)
                    segment.direction = layout.direction
                    Addon:SetBuffIndicatorBarColor(segment, entry)
                    segment:SetValue(PreviewValue(segment))
                    segment:Show()
                end
            end
        end
        list:SetHeight(math.max(1, offset))
        listScroll:SetVerticalScroll(math.min(listScroll:GetVerticalScroll(),
            math.max(0, list:GetHeight() - listScroll:GetHeight())))
        add:SetEnabled(#entries < Addon.MAX_BUFF_INDICATORS)
        if Addon:HasPendingBuffIndicators() then
            status:SetText("Saved. Indicators will update when aura restrictions end.")
            status:SetTextColor(1, 0.82, 0.4)
        elseif #entries == 0 then
            status:SetText("Add a buff to create your first indicator. Up to 8 per profile.")
            status:SetTextColor(0.65, 0.65, 0.65)
        else
            status:SetText("")
        end
    end
    Refresh()
    return Refresh
end
