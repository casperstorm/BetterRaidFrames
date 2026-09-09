local _, Addon = ...

local LIST_WIDTH = 640

local function SpellLabel(spellID, spell)
    local name = spell and spell.name or "Spell " .. spellID
    -- Blizzard gives these Echo auras the same names as the original buffs.
    if spellID == 376788 or spellID == 367364 then
        return "Echoed " .. name
    end
    return name
end

local function Label(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    if width then label:SetWidth(width) end
    return label
end

local function Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

function Addon:BuildDesignerOptions(content, y)
    local Refresh
    local profile, editing = self:GetCurrentProfileName(), "default"
    local selected, absent, rows = nil, {}, {}
    local refreshers = {}
    local section = "Appearance"
    local function Selection()
        if profile ~= Addon:GetCurrentProfileName() then return end
        return Addon:FindDesignerIndicator(editing, selected)
    end
    local function ContextMatches(savedProfile, savedKey, savedId)
        return not InCombatLockdown() and savedProfile == Addon:GetCurrentProfileName()
            and profile == savedProfile and editing == savedKey and selected == savedId
    end
    local function Change(changes)
        if not InCombatLockdown() and Selection() then
            Addon:ChangeDesignerIndicator(editing, selected, changes)
            Refresh()
        end
    end

    local blizzardBuffs = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    blizzardBuffs:SetPoint("TOPLEFT", 8, y)
    blizzardBuffs.Text:SetText("Show Blizzard buff icons")
    blizzardBuffs.Text:SetFontObject("GameFontHighlightSmall")
    local function RefreshBlizzardBuffs()
        blizzardBuffs:SetChecked(C_CVar.GetCVarBool("raidFramesDisplayBuffs"))
    end
    blizzardBuffs:SetScript("OnClick", function(button)
        if not InCombatLockdown() then
            C_CVar.SetCVar("raidFramesDisplayBuffs", button:GetChecked() and "1" or "0")
        end
        RefreshBlizzardBuffs()
    end)
    blizzardBuffs:RegisterEvent("CVAR_UPDATE")
    blizzardBuffs:SetScript("OnEvent", RefreshBlizzardBuffs)
    refreshers[#refreshers + 1] = RefreshBlizzardBuffs
    local blizzardBuffsNote = Label(content, "Raid and Raid-Style Party Frames; shared across profiles.", 280, y - 8, 370)
    blizzardBuffsNote:SetTextColor(0.75, 0.75, 0.75)
    y = y - 36

    local context = Label(content, "", 12, y, LIST_WIDTH)
    local preview = self:CreateDesignerPreview(content)
    preview:SetPoint("TOPLEFT", 12, y - 24)
    local previewGroup = Label(content, "", 206, y - 25, 435)
    local previewActive = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    previewActive:SetPoint("TOPLEFT", 198, y - 46)
    previewActive.Text:SetText("Selected buff active")
    previewActive.Text:SetFontObject("GameFontHighlightSmall")
    previewActive:SetScript("OnClick", function(button)
        if selected then absent[selected] = not button:GetChecked(); Refresh() end
    end)

    local function Dropdown(parent, label, x, top, width, options, get, set)
        local labelText = Label(parent, label, x, top)
        local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("TOPLEFT", x, top - 16)
        dropdown:SetWidth(width)
        dropdown:SetupMenu(function(_, root)
            local savedProfile, savedKey, savedId = profile, editing, selected
            for _, option in ipairs(type(options) == "function" and options() or options) do
                root:CreateRadio(option.label, function(value) return get() == value end,
                    function(value)
                        if ContextMatches(savedProfile, savedKey, savedId) then set(value); Refresh() end
                    end, option.value)
            end
        end)
        refreshers[#refreshers + 1] = function() dropdown:GenerateMenu() end
        dropdown.label = labelText
        return dropdown
    end

    local function SetOptions()
        local result = { { value = "default", label = "Default (all specializations)" } }
        local current = Addon:GetIndicatorSpecKey()
        local found = current == "default"
        for _, option in ipairs(Addon.IndicatorSpecializations) do
            result[#result + 1] = option
            if option.value == current then found = true end
        end
        if not found then
            local index = C_SpecializationInfo.GetSpecialization()
            local _, name = C_SpecializationInfo.GetSpecializationInfo(index)
            result[#result + 1] = { value = current, label = name or "Current specialization" }
        end
        return result
    end
    Dropdown(content, "Editing set", 12, y - 91, 300, SetOptions,
        function() return editing end, function(value) editing = value; selected = nil; absent = {} end)
    local useDefault = Button(content, "Use Default", 324, y - 107, 116, function()
        if not InCombatLockdown() and profile == Addon:GetCurrentProfileName() then
            Addon:UseDefaultIndicators(editing); selected = nil; absent = {}; Refresh()
        end
    end)

    local status = Label(content, "", 12, 0, LIST_WIDTH)
    status:ClearAllPoints()
    status:SetPoint("BOTTOMLEFT", 12, 0)
    local function Message(text, error)
        status:SetText(text or "")
        status:SetTextColor(error and 1 or 0.75, error and 0.35 or 0.75, error and 0.3 or 0.75)
    end

    -- A local modal captures the destination before opening. It validates an
    -- import before offering replacement and cannot write to a changed profile.
    local share = CreateFrame("Frame", nil, content, "BackdropTemplate")
    share:SetPoint("TOPLEFT", 4, y - 15)
    share:SetPoint("BOTTOMRIGHT", -4, 26)
    share:SetFrameLevel(content:GetFrameLevel() + 12)
    share:EnableMouse(true)
    share:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    share:SetBackdropColor(0.1, 0.1, 0.1, 1)
    share:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    local shareTitle = Label(share, "", 12, -12, 610)
    local shareInput = CreateFrame("EditBox", nil, share, "InputBoxTemplate")
    shareInput:SetPoint("TOPLEFT", 16, -40)
    shareInput:SetPoint("TOPRIGHT", -16, -40)
    shareInput:SetHeight(26)
    shareInput:SetAutoFocus(false)
    shareInput:SetMaxLetters(65536)
    local shareNote = Label(share, "", 12, -80, 602)
    local imported, destinationProfile, destinationKey
    local shareApply
    shareApply = Button(share, "Review Import", 12, -133, 130, function()
        if InCombatLockdown() or destinationProfile ~= Addon:GetCurrentProfileName() or editing ~= destinationKey then
            shareNote:SetText("The editing context changed. Close and reopen Import.")
            return
        end
        if imported then
            Addon:SaveIndicatorSet(destinationKey, imported)
            selected = nil; absent = {}; share:Hide(); Refresh()
        else
            local err
            imported, err = Addon:DecodeDesignerIndicators(shareInput:GetText())
            if imported then
                shareNote:SetText("Replace this set with " .. #imported.items .. " imported indicators? The current set will be replaced.")
                shareApply:SetText("Replace Set")
            else shareNote:SetText(err) end
        end
    end)
    local function ResetImport()
        imported = nil
        shareApply:SetText("Review Import")
    end
    shareInput:SetScript("OnTextChanged", function() ResetImport() end)
    shareInput:SetScript("OnEscapePressed", function() share:Hide() end)
    Button(share, "Close", 152, -133, 80, function() share:Hide() end)
    share:Hide()
    local function OpenShare(export)
        if InCombatLockdown() then return end
        destinationProfile, destinationKey = profile, editing
        imported = nil
        shareTitle:SetText(export and "Export Indicators" or "Import Indicators")
        shareApply:SetShown(not export)
        shareInput:SetText(export and Addon:ExportDesignerIndicators(editing) or "")
        shareNote:SetText(export and "Copy this text to share the selected set, including its anchor groups." or "Paste a BetterRaidFrames indicator export, then review it before replacing this set.")
        share:Show(); shareInput:SetFocus(); shareInput:HighlightText()
    end
    Button(content, "Import", 452, y - 107, 92, function() OpenShare(false) end)
    Button(content, "Export", 556, y - 107, 88, function() OpenShare(true) end)

    Label(content, "Buff name or spell ID", 12, y - 139)
    local input = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", 16, y - 159)
    input:SetSize(422, 24)
    input:SetAutoFocus(false)
    input:SetMaxLetters(100)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local typeOptions = { { value = "SQUARE", label = "Square" }, { value = "ICON", label = "Spell icon" } }
    local function Add()
        if InCombatLockdown() or profile ~= Addon:GetCurrentProfileName() then return end
        local item = Selection()
        local id, err = Addon:AddDesignerIndicator(editing, input:GetText(), "ICON", item and item.anchor)
        if id then selected = id; input:SetText(""); Refresh() else Message(err, true) end
    end
    local add = Button(content, "Add", 568, y - 158, 76, Add)
    input:SetScript("OnEnterPressed", Add)
    local presets = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    presets:SetPoint("TOPLEFT", 446, y - 158)
    presets:SetWidth(110)
    presets:SetDefaultText("Buffs")
    presets:SetupMenu(function(_, root)
        local savedProfile, savedKey = profile, editing
        for _, spec in ipairs(Addon.IndicatorSpecializations) do
            local category = root:CreateButton(spec.label)
            for _, spellID in ipairs(spec.spells) do
                local spell = C_Spell.GetSpellInfo(spellID)
                if spell then
                    category:CreateButton(SpellLabel(spellID, spell), function()
                        if not InCombatLockdown() and savedProfile == Addon:GetCurrentProfileName() and savedKey == editing then
                            input:SetText(tostring(spellID))
                        end
                    end)
                end
            end
        end
    end)

    local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, y - 193)
    scroll:SetPoint("BOTTOMRIGHT", -26, 35)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(LIST_WIDTH, 1)
    scroll:SetScrollChild(list)
    local editor = CreateFrame("Frame", nil, list)
    local editorHeights = { Appearance = 244, Placement = 270, Text = 210 }
    editor:SetSize(LIST_WIDTH - 4, editorHeights.Appearance)
    local panels, sectionButtons = {}, {}
    for index, title in ipairs({ "Appearance", "Placement", "Text" }) do
        local panel = CreateFrame("Frame", nil, editor)
        panel:SetPoint("TOPLEFT", 4, -31)
        panel:SetSize(LIST_WIDTH - 12, editorHeights[title] - 36)
        panels[title] = panel
        sectionButtons[title] = Button(editor, title, 4 + (index - 1) * 100, -3, 96, function() section = title; Refresh() end)
    end

    local function FieldChoice(panel, label, key, x, top, width, options)
        return Dropdown(panel, label, x, top, width, options,
            function() local item = Selection(); return item and item[key] end,
            function(value) Change({ [key] = value }) end)
    end
    local function Checkbox(panel, label, key, x, top)
        local box = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        box:SetPoint("TOPLEFT", x, top)
        box.Text:SetText(label)
        box.Text:SetFontObject("GameFontHighlightSmall")
        box:SetScript("OnClick", function(self) Change({ [key] = self:GetChecked() }) end)
        refreshers[#refreshers + 1] = function() local item = Selection(); box:SetChecked(item and item[key] or false) end
        return box
    end
    local function Slider(panel, label, x, top, width, min, max, step, get, set)
        Label(panel, label, x, top)
        local slider = CreateFrame("Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
        slider:SetPoint("TOPLEFT", x, top - 23)
        slider:SetSize(width, 16)
        local loading = false
        local formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
            MinimalSliderWithSteppersMixin.Label.Right, function(value) return step == 1 and string.format("%d", value) or string.format("%.1f", value) end) }
        slider:Init(min, min, max, math.floor((max - min) / step + 0.5), formatters)
        if slider.MinText then slider.MinText:Hide() end
        if slider.MaxText then slider.MaxText:Hide() end
        slider.Slider:HookScript("OnValueChanged", function(_, value)
            if not loading and not InCombatLockdown() and Selection() then
                set(math.floor(value / step + 0.5) * step); Refresh()
            end
        end)
        refreshers[#refreshers + 1] = function() loading = true; slider:SetValue(get() or min); loading = false end
        return slider
    end
    local function Swatch(panel, label, key, x, top)
        Label(panel, label, x + 28, top - 4)
        local swatch = CreateFrame("Button", nil, panel)
        swatch:SetPoint("TOPLEFT", x, top)
        swatch:SetSize(22, 22)
        local color = swatch:CreateTexture(nil, "ARTWORK")
        color:SetAllPoints()
        refreshers[#refreshers + 1] = function()
            local item = Selection()
            if item then local c = item[key]; color:SetColorTexture(c.r, c.g, c.b, c.a) end
        end
        swatch:SetScript("OnClick", function()
            local item = Selection()
            if not item or InCombatLockdown() then return end
            local savedProfile, savedKey, savedId = profile, editing, selected
            local original = item[key]
            local function Apply(value)
                if ContextMatches(savedProfile, savedKey, savedId) then Change({ [key] = value }) end
            end
            local function Changed()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                Apply({ r = r, g = g, b = b, a = ColorPickerFrame:GetColorAlpha() })
            end
            ColorPickerFrame:SetupColorPickerAndShow({ r = original.r, g = original.g, b = original.b,
                opacity = original.a, hasOpacity = true, swatchFunc = Changed, opacityFunc = Changed,
                cancelFunc = function() Apply(original) end })
        end)
        return swatch
    end

    local appearance = panels.Appearance
    FieldChoice(appearance, "Display", "type", 4, -2, 270, typeOptions)
    Slider(appearance, "Size (px)", 328, -2, 254, 10, 50, 1,
        function() local item = Selection(); return item and item.size end, function(v) Change({ size = v }) end)
    local texture = Checkbox(appearance, "Show icon texture", "showTexture", 320, -58)
    local squareColor = Swatch(appearance, "Square colour", "color", 8, -62)
    Checkbox(appearance, "Cooldown swipe", "cooldown", 0, -93)
    Checkbox(appearance, "Mine (including pets)", "mineOnly", 320, -93)
    Checkbox(appearance, "Mouseover tooltip", "tooltip", 0, -127)
    Checkbox(appearance, "Glow", "glow", 0, -161)
    local glowPulse = Checkbox(appearance, "Pulse glow", "glowPulse", 320, -161)
    Button(appearance, "Change buff", 476, -130, 112, function()
        if InCombatLockdown() then return end
        local spell = Addon:ResolveIndicatorSpell(input:GetText())
        if spell then Change({ spellID = spell.spellID }); input:SetText("")
        else Message("Enter the new buff's name or ID above, then click Change buff.", true) end
    end)

    local placement = panels.Placement
    FieldChoice(placement, "Anchor", "anchor", 4, -2, 270, Addon.IndicatorAnchors)
    Slider(placement, "Group Z offset (layer)", 328, -2, 254, -100, 500, 1, function()
        local item = Selection()
        return item and Addon:GetIndicatorSet(editing).groups[item.anchor].offsetZ
    end, function(value)
        local item = Selection()
        if item then Addon:ChangeDesignerGroup(editing, item.anchor, { offsetZ = value }) end
    end)
    local groupLabel = Label(placement, "", 4, -58, 310)
    Button(placement, "Above Blizzard icons", 328, -54, 254, function()
        if InCombatLockdown() then return end
        local item = Selection()
        if item then
            -- Blizzard uses absolute levels 125/150/175/200 for its aura
            -- layers. Our group adds the unit frame's level plus 10 to this.
            Addon:ChangeDesignerGroup(editing, item.anchor, { offsetZ = 200 })
            Refresh()
        end
    end)
    Dropdown(placement, "Grow", 4, -82, 270, function()
        local item = Selection()
        return Addon:GetIndicatorGrowthOptions(item and item.anchor or "BOTTOMRIGHT")
    end, function()
        local item = Selection()
        return item and Addon:GetIndicatorSet(editing).groups[item.anchor].grow
    end, function(value)
        local item = Selection()
        if item then Addon:ChangeDesignerGroup(editing, item.anchor, { grow = value }) end
    end)
    Slider(placement, "Spacing (px)", 328, -82, 254, 0, 20, 1, function()
        local item = Selection()
        return item and Addon:GetIndicatorSet(editing).groups[item.anchor].spacing
    end, function(value)
        local item = Selection()
        if item then Addon:ChangeDesignerGroup(editing, item.anchor, { spacing = value }) end
    end)
    Slider(placement, "Group X offset (px)", 4, -139, 254, -250, 250, 1, function()
        local item = Selection()
        return item and Addon:GetIndicatorSet(editing).groups[item.anchor].offsetX
    end, function(value)
        local item = Selection()
        if item then Addon:ChangeDesignerGroup(editing, item.anchor, { offsetX = value }) end
    end)
    Slider(placement, "Group Y offset (px)", 328, -139, 254, -250, 250, 1, function()
        local item = Selection()
        return item and Addon:GetIndicatorSet(editing).groups[item.anchor].offsetY
    end, function(value)
        local item = Selection()
        if item then Addon:ChangeDesignerGroup(editing, item.anchor, { offsetY = value }) end
    end)
    Label(placement, "Shared by this anchor group. +X moves right; +Y moves up.\nHigher Z draws in front. Absent buffs close the gap.", 4, -198, 612)

    local textPanel = panels.Text
    FieldChoice(textPanel, "Text", "text", 4, -2, 270, {
        { value = "NONE", label = "None" }, { value = "DURATION", label = "Remaining duration" },
        { value = "STACKS", label = "Stack count" },
    })
    Slider(textPanel, "Text scale", 328, -2, 254, 0.5, 3, 0.1,
        function() local item = Selection(); return item and item.textScale end,
        function(value) Change({ textScale = value }) end)
    Swatch(textPanel, "Text colour", "textColor", 8, -66)

    local function CreateRow(index)
        local row = CreateFrame("Frame", nil, list)
        row:SetSize(LIST_WIDTH, 34)
        local enabled = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        enabled:SetPoint("TOPLEFT", 0, 0)
        enabled:SetScript("OnClick", function(button)
            if not InCombatLockdown() and row.item and profile == Addon:GetCurrentProfileName() then
                Addon:ChangeDesignerIndicator(editing, row.item.id, { enabled = button:GetChecked() }); Refresh()
            end
        end)
        row.enabled = enabled
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("TOPLEFT", 30, -5); row.icon:SetSize(20, 20)
        row.name = Label(row, "", 55, -7, 306)
        row.name:SetWordWrap(false)
        row.anchor = Label(row, "", 55, -20, 306)
        row.anchor:SetTextColor(0.65, 0.65, 0.65)
        row.edit = Button(row, "Edit", 368, -4, 64, function()
            selected = row.item.id; Refresh()
            scroll:SetVerticalScroll(math.min(row.offset, math.max(0, list:GetHeight() - scroll:GetHeight())))
        end)
        row.up = Button(row, "<", 436, -4, 24, function()
            if not InCombatLockdown() and profile == Addon:GetCurrentProfileName() then
                Addon:MoveDesignerIndicator(editing, row.item.id, -1); Refresh()
            end
        end)
        row.down = Button(row, ">", 462, -4, 24, function()
            if not InCombatLockdown() and profile == Addon:GetCurrentProfileName() then
                Addon:MoveDesignerIndicator(editing, row.item.id, 1); Refresh()
            end
        end)
        row.copy = Button(row, "Copy", 490, -4, 52, function()
            if not InCombatLockdown() and profile == Addon:GetCurrentProfileName() then
                local id, err = Addon:DuplicateDesignerIndicator(editing, row.item.id)
                if id then selected = id; Refresh() else Message(err, true) end
            end
        end)
        Button(row, "Remove", 546, -4, 82, function()
            if not InCombatLockdown() and profile == Addon:GetCurrentProfileName() then
                Addon:RemoveDesignerIndicator(editing, row.item.id); Refresh()
            end
        end)
        rows[index] = row
        return row
    end

    Refresh = function()
        if profile ~= Addon:GetCurrentProfileName() then
            profile = Addon:GetCurrentProfileName(); selected = nil; absent = {}; share:Hide(); scroll:SetVerticalScroll(0)
        end
        local set = Addon:GetIndicatorSet(editing)
        for id in pairs(absent) do
            if not Addon:FindDesignerIndicator(editing, id) then absent[id] = nil end
        end
        if not Selection() then selected = set.items[1] and set.items[1].id end
        local current = Selection()
        local ownSet = Addon:GetSetting("indicators").sets[editing] ~= nil
        context:SetText("Profile: " .. profile .. (editing ~= "default" and not ownSet and " — using Default; edits create an override" or ""))
        useDefault:SetEnabled(editing ~= "default" and ownSet)
        add:SetEnabled(#set.items < Addon.MAX_DESIGNER_INDICATORS)
        local counts, order = {}, {}
        for _, item in ipairs(set.items) do counts[item.anchor] = (counts[item.anchor] or 0) + 1 end
        local editorHeight = editorHeights[section]
        editor:SetHeight(editorHeight)
        local offset = 0
        for index, item in ipairs(set.items) do
            local row = rows[index] or CreateRow(index)
            row.item, row.offset = item, offset
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -offset)
            row:SetHeight(item.id == selected and editorHeight + 38 or 34); row:Show()
            offset = offset + row:GetHeight()
            order[item.anchor] = (order[item.anchor] or 0) + 1
            row.enabled:SetChecked(item.enabled)
            local spell = C_Spell.GetSpellInfo(item.spellID)
            row.name:SetText(SpellLabel(item.spellID, spell))
            row.anchor:SetText(Addon:GetIndicatorAnchorName(item.anchor) .. " · " .. order[item.anchor])
            row.icon:SetVertexColor(1, 1, 1, 1)
            if item.type == "ICON" then row.icon:SetTexture(spell and spell.iconID or 134400)
            else local c = item.color; row.icon:SetColorTexture(c.r, c.g, c.b, c.a) end
            row.edit:SetText(item.id == selected and "Editing" or "Edit")
            row.up:SetEnabled(order[item.anchor] > 1)
            row.down:SetEnabled(order[item.anchor] < counts[item.anchor])
            row.copy:SetEnabled(#set.items < Addon.MAX_DESIGNER_INDICATORS)
            if item.id == selected then
                editor:ClearAllPoints(); editor:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -35)
            end
        end
        for index = #set.items + 1, #rows do rows[index]:Hide(); rows[index].item = nil end
        editor:SetShown(current ~= nil)
        for title, panel in pairs(panels) do
            panel:SetShown(title == section)
            sectionButtons[title]:SetEnabled(title ~= section)
        end
        list:SetHeight(math.max(1, offset))
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, list:GetHeight() - scroll:GetHeight())))
        previewActive:SetEnabled(current ~= nil)
        previewActive:SetChecked(current and not absent[current.id] or false)
        previewGroup:SetText(current and Addon:GetIndicatorAnchorName(current.anchor) .. " group" or "Add an indicator to begin")
        groupLabel:SetText(current and Addon:GetIndicatorAnchorName(current.anchor) .. " group · " .. counts[current.anchor] .. " indicators" or "")
        texture:SetEnabled(current and current.type == "ICON" or false)
        squareColor:SetEnabled(current and current.type == "SQUARE" or false)
        glowPulse:SetEnabled(current and current.glow or false)
        for _, refresh in ipairs(refreshers) do refresh() end
        local overflow = preview:Refresh(set, selected, absent)
        if Addon:HasPendingDesignerIndicators() then Message("Saved. Indicators will update when aura restrictions end.")
        elseif overflow then Message("This group exceeds the preview frame. Reduce its size or spacing.")
        elseif #set.items == 0 then Message("Add a buff, then choose its display and anchor. Up to 32 per set.")
        else Message("Use < / > to reorder within an anchor group.") end
    end
    content:HookScript("OnHide", function() share:Hide() end)
    Refresh()
    return Refresh
end
