local _, Addon = ...

local function Label(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

function Addon:BuildBuffIndicatorsOptions(content, y)
    local Refresh
    local controlRefreshers = {}

    local function CreateSlider(label, key, minimum, maximum, normalize, x, offsetY, width, suffix, labelWidth)
        Label(content, label, x, offsetY)
        local slider = CreateFrame("Frame", nil, content, "MinimalSliderWithSteppersTemplate")
        slider:SetPoint("TOPLEFT", x + (labelWidth or 100), offsetY)
        slider:SetSize(width, 16)
        local refreshing = false
        local formatters = {
            [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                MinimalSliderWithSteppersMixin.Label.Right,
                function(value) return string.format("%d%s", math.floor(value + 0.5), suffix or "") end
            ),
        }
        slider:Init(normalize(Addon, Addon:GetSetting(key)), minimum, maximum, maximum - minimum, formatters)
        if slider.MinText then slider.MinText:Hide() end
        if slider.MaxText then slider.MaxText:Hide() end
        slider.Slider:HookScript("OnValueChanged", function(_, value)
            if refreshing or InCombatLockdown() then return end
            Addon:SetSetting(key, normalize(Addon, value))
            Refresh()
        end)
        controlRefreshers[#controlRefreshers + 1] = function()
            refreshing = true
            slider:SetValue(normalize(Addon, Addon:GetSetting(key)))
            refreshing = false
        end
        return slider
    end

    local function CreateChoice(label, key, options, normalize, x, offsetY, labelWidth, width)
        Label(content, label, x, offsetY - 5)
        local dropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("TOPLEFT", x + labelWidth, offsetY)
        dropdown:SetWidth(width)
        dropdown:SetupMenu(function(_, root)
            local choices = type(options) == "function" and options() or options
            for _, option in ipairs(choices) do
                root:CreateRadio(option.label,
                    function(value) return normalize(Addon, Addon:GetSetting(key)) == value end,
                    function(value)
                        if InCombatLockdown() then return end
                        Addon:SetSetting(key, value)
                        Refresh()
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
    local previewNote = Label(content, "Duration preview", 208, y - 26)
    previewNote:SetTextColor(0.65, 0.65, 0.65)
    local segments = {}
    local previewElapsed = 0
    local previewDirection = "ELAPSED"
    local function PreviewValue()
        local progress = previewElapsed / 4
        return previewDirection == "REMAINING" and (1 - progress) or progress
    end
    preview:SetScript("OnShow", function() previewElapsed = 0 end)
    preview:SetScript("OnUpdate", function(_, elapsed)
        -- A repeating sample timer, independent of any real aura information.
        previewElapsed = (previewElapsed + elapsed) % 4
        for _, segment in ipairs(segments) do segment:SetValue(PreviewValue()) end
    end)

    CreateSlider("Thickness:", "buffIndicatorHeight", 1, Addon.MAX_BUFF_INDICATOR_HEIGHT,
        Addon.NormalizeBuffIndicatorHeight, 208, y - 48, 132, " px", 60)

    CreateChoice("Progress:", "buffIndicatorDirection", function()
        local vertical = Addon:IsBuffIndicatorVertical(Addon:GetSetting("buffIndicatorPosition"))
        return {
            { value = "ELAPSED", label = vertical and "Fill (top to bottom)" or "Fill (left to right)" },
            { value = "REMAINING", label = vertical and "Drain (bottom to top)" or "Drain (right to left)" },
        }
    end, Addon.NormalizeBuffIndicatorDirection, 16, y - 82, 68, 184)
    CreateChoice("Position:", "buffIndicatorPosition", {
        { value = "TOP", label = "Top" },
        { value = "BOTTOM", label = "Bottom" },
        { value = "LEFT", label = "Left" },
        { value = "RIGHT", label = "Right" },
    }, Addon.NormalizeBuffIndicatorPosition, 284, y - 82, 62, 96)

    local levelSlider = CreateSlider("Frame level:", "buffIndicatorFrameLevel",
        Addon.MIN_BUFF_INDICATOR_FRAME_LEVEL, Addon.MAX_BUFF_INDICATOR_FRAME_LEVEL,
        Addon.NormalizeBuffIndicatorFrameLevel, 16, y - 119, 284)
    levelSlider:HookScript("OnEnter", function()
        GameTooltip:SetOwner(levelSlider, "ANCHOR_RIGHT")
        GameTooltip:SetText("Frame level")
        GameTooltip:AddLine("Relative to the raid frame. Higher values draw above other elements.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    levelSlider:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local inputLabel = Label(content, "Buff name or spell ID:", 16, y - 153)
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

    local status = Label(content, "", 16, y - 203)
    status:SetWidth(440)
    local rows = {}

    local function AddBuff()
        if InCombatLockdown() then return end
        local added, message = Addon:AddBuffIndicator(input:GetText())
        if added then
            input:SetText("")
            input:ClearFocus()
            status:SetText("")
            Refresh()
        else
            status:SetText(message)
            status:SetTextColor(1, 0.35, 0.3)
        end
    end
    add:SetScript("OnClick", AddBuff)
    input:SetScript("OnEnterPressed", AddBuff)

    local listScroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 12, y - 224)
    listScroll:SetPoint("BOTTOMRIGHT", -26, 48)
    local list = CreateFrame("Frame", nil, listScroll)
    list:SetSize(440, 1)
    listScroll:SetScrollChild(list)
    for index = 1, self.MAX_BUFF_INDICATORS do
        local row = CreateFrame("Frame", nil, list)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
        row:SetSize(440, 28)

        local enabled = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        enabled:SetPoint("LEFT", 0, 0)
        enabled:SetScript("OnClick", function(button)
            if InCombatLockdown() then return end
            Addon:ChangeBuffIndicator(index, { enabled = button:GetChecked() })
            Refresh()
        end)
        row.enabled = enabled

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", 30, 0)
        icon:SetSize(20, 20)
        row.icon = icon
        local name = Label(row, "", 56, -7)
        name:SetWidth(168)
        name:SetWordWrap(false)
        row.name = name

        local mine = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        mine:SetPoint("LEFT", 228, 0)
        mine.Text:SetText("Mine")
        mine.Text:SetFontObject("GameFontHighlightSmall")
        mine:SetScript("OnClick", function(button)
            if InCombatLockdown() then return end
            Addon:ChangeBuffIndicator(index, { mineOnly = button:GetChecked() })
            Refresh()
        end)
        row.mine = mine

        local swatch = CreateFrame("Button", nil, row)
        swatch:SetPoint("LEFT", 308, 0)
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

        local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        remove:SetPoint("LEFT", 344, 0)
        remove:SetSize(76, 22)
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
            GameTooltip:SetText("Spell ID: " .. entry.spellID)
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
        local thickness = Addon:NormalizeBuffIndicatorHeight(Addon:GetSetting("buffIndicatorHeight"))
        local position = Addon:NormalizeBuffIndicatorPosition(Addon:GetSetting("buffIndicatorPosition"))
        local previewLayout = { width = 180, height = 46, thickness = thickness, position = position }
        local frameLevel = Addon:NormalizeBuffIndicatorFrameLevel(Addon:GetSetting("buffIndicatorFrameLevel"))
        previewDirection = Addon:NormalizeBuffIndicatorDirection(Addon:GetSetting("buffIndicatorDirection"))
        for _, refresh in ipairs(controlRefreshers) do refresh() end
        list:SetHeight(math.max(1, #entries * 28))
        listScroll:SetVerticalScroll(math.min(listScroll:GetVerticalScroll(),
            math.max(0, list:GetHeight() - listScroll:GetHeight())))
        for index, row in ipairs(rows) do
            local entry = entries[index]
            row:SetShown(entry ~= nil)
            segments[index]:Hide()
            if entry then
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
                    Addon:LayoutBuffIndicator(segment, preview, previewLayout, #entries, index)
                    Addon:SetBuffIndicatorBarOrientation(segment, position)
                    segment:SetFrameLevel(math.max(0, preview:GetFrameLevel() + frameLevel) + 2)
                    Addon:SetBuffIndicatorBarColor(segment, entry)
                    segment:SetValue(PreviewValue())
                    segment:Show()
                end
            end
        end
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
