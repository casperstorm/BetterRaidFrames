local _, Addon = ...

local WIDTH = 404

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

-- One inspector is reused for every group and spell. The context owns selection
-- and writes; controls never retain a mutable settings table between refreshes.
function Addon:BuildDesignerEditor(parent, context)
    local refreshers = {}
    local section, advanced, lastToken = "Display", false, nil
    local title = Label(parent, "", 0, 0, WIDTH)
    local subtitle = Label(parent, "", 0, -20, WIDTH)
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -46)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(WIDTH, 1)
    scroll:SetScrollChild(body)
    local function Panel()
        local panel = CreateFrame("Frame", nil, body)
        panel:SetPoint("TOPLEFT")
        panel:SetWidth(WIDTH)
        return panel
    end
    local groupPanel, itemPanel, addPanel, emptyPanel = Panel(), Panel(), Panel(), Panel()
    Label(emptyPanel, "Choose Add group on the left, then select a position.\nAdd your first buff inside that group.", 0, 4, WIDTH)

    local function Dropdown(panel, label, x, y, width, options, get, set)
        local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
        dropdown.label = Label(panel, label, x, y)
        dropdown:SetPoint("TOPLEFT", x, y - 18)
        dropdown:SetWidth(width)
        dropdown:SetupMenu(function(_, root)
            local profile, key, token = context:Capture()
            for _, option in ipairs(type(options) == "function" and options() or options) do
                root:CreateRadio(option.label, function(value) return get() == value end, function(value)
                    if context:Matches(profile, key, token) then set(value) end
                end, option.value)
            end
        end)
        refreshers[#refreshers + 1] = function() dropdown:GenerateMenu() end
        return dropdown
    end
    local function Slider(panel, label, x, y, width, min, max, step, get, set)
        local slider = CreateFrame("Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
        slider.label = Label(panel, label, x, y)
        slider:SetPoint("TOPLEFT", x, y - 23)
        slider:SetSize(width, 16)
        local loading = false
        local formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
            MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return step == 1 and string.format("%d", value) or string.format("%.1f", value)
            end) }
        slider:Init(min, min, max, math.floor((max - min) / step + 0.5), formatters)
        if slider.MinText then slider.MinText:Hide() end
        if slider.MaxText then slider.MaxText:Hide() end
        slider.Slider:HookScript("OnValueChanged", function(_, value)
            if not loading and context:CanEdit() then set(math.floor(value / step + 0.5) * step) end
        end)
        refreshers[#refreshers + 1] = function() loading = true; slider:SetValue(get() or min); loading = false end
        return slider
    end
    local function ItemValue(key)
        local item = context:GetItem()
        return item and item[key]
    end
    local function Checkbox(panel, label, key, x, y)
        local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", x, y)
        checkbox.Text:SetText(label)
        checkbox.Text:SetFontObject("GameFontHighlightSmall")
        checkbox:SetScript("OnClick", function(self) context:ChangeItem({ [key] = self:GetChecked() }) end)
        refreshers[#refreshers + 1] = function() checkbox:SetChecked(ItemValue(key) or false) end
        return checkbox
    end
    local function Swatch(panel, label, key, x, y)
        Label(panel, label, x + 28, y - 4)
        local swatch = CreateFrame("Button", nil, panel)
        swatch:SetPoint("TOPLEFT", x, y)
        swatch:SetSize(22, 22)
        local texture = swatch:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        refreshers[#refreshers + 1] = function()
            local color = ItemValue(key)
            if color then texture:SetColorTexture(color.r, color.g, color.b, color.a) end
        end
        swatch:SetScript("OnClick", function()
            local original = ItemValue(key)
            if not original or not context:CanEdit() then return end
            local profile, setKey, token = context:Capture()
            local function Apply(value)
                if context:Matches(profile, setKey, token) then context:ChangeItem({ [key] = value }) end
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
    local function GroupValue(key)
        local group = context.anchor and context:GetSet().groups[context.anchor]
        return group and group[key]
    end
    Dropdown(groupPanel, "Position", 0, 0, 392, function() return context:UnusedAnchors(true) end,
        function() return context.anchor end, function(value) context:MoveGroup(value) end)
    Dropdown(groupPanel, "Grow", 0, -58, 186,
        function() return Addon:GetIndicatorGrowthOptions(context.anchor or "BOTTOMRIGHT") end,
        function() return GroupValue("grow") end, function(value) context:ChangeGroup({ grow = value }) end)
    Slider(groupPanel, "Spacing (px)", 212, -58, 164, 0, 20, 1,
        function() return GroupValue("spacing") end, function(value) context:ChangeGroup({ spacing = value }) end)
    Slider(groupPanel, "X offset (px)", 0, -118, 164, -250, 250, 1,
        function() return GroupValue("offsetX") end, function(value) context:ChangeGroup({ offsetX = value }) end)
    Slider(groupPanel, "Y offset (px)", 212, -118, 164, -250, 250, 1,
        function() return GroupValue("offsetY") end, function(value) context:ChangeGroup({ offsetY = value }) end)
    Label(groupPanel, "These settings move and arrange every indicator in this group.\nMissing buffs close the gap automatically.", 0, -176, WIDTH)
    local advancedButton = Button(groupPanel, "+ Advanced", 0, -224, 124, function()
        advanced = not advanced; context:Refresh()
    end)
    local groupAdd = Button(groupPanel, "Add indicator", 260, -224, 132, function()
        context:Select(context.anchor, nil, "add")
    end)
    local advancedPanel = CreateFrame("Frame", nil, groupPanel)
    advancedPanel:SetPoint("TOPLEFT", 0, -262)
    advancedPanel:SetSize(WIDTH, 124)
    Slider(advancedPanel, "Layer / Z offset", 0, 0, 370, -100, 500, 1,
        function() return GroupValue("offsetZ") end, function(value) context:ChangeGroup({ offsetZ = value }) end)
    Button(advancedPanel, "Above Blizzard icons", 0, -54, 208, function() context:ChangeGroup({ offsetZ = 200 }) end)
    Label(advancedPanel, "Higher values draw in front. This affects the whole group.", 0, -88, WIDTH)

    local up = Button(itemPanel, "↑", 0, 0, 28, function() context:Reorder(-1) end)
    local down = Button(itemPanel, "↓", 34, 0, 28, function() context:Reorder(1) end)
    local copy = Button(itemPanel, "Copy", 222, 0, 72, function() context:CopyItem() end)
    Button(itemPanel, "Remove", 302, 0, 90, function() context:RemoveItem() end)
    local display = CreateFrame("Frame", nil, itemPanel)
    display:SetPoint("TOPLEFT", 0, -70); display:SetSize(WIDTH, 314)
    local text = CreateFrame("Frame", nil, itemPanel)
    text:SetPoint("TOPLEFT", 0, -70); text:SetSize(WIDTH, 142)
    local displayTab = Button(itemPanel, "Display", 0, -34, 96, function() section = "Display"; context:Refresh() end)
    local textTab = Button(itemPanel, "Text", 104, -34, 96, function() section = "Text"; context:Refresh() end)
    Dropdown(display, "Display", 0, 0, 186, { { value = "ICON", label = "Spell icon" }, { value = "SQUARE", label = "Square" } },
        function() return ItemValue("type") end, function(value) context:ChangeItem({ type = value }) end)
    Slider(display, "Size (px)", 212, 0, 164, 10, 50, 1,
        function() return ItemValue("size") end, function(value) context:ChangeItem({ size = value }) end)
    local squareColor = Swatch(display, "Square colour", "color", 4, -63)
    local texture = Checkbox(display, "Show icon texture", "showTexture", 204, -59)
    Checkbox(display, "Cooldown swipe", "cooldown", -4, -95)
    Checkbox(display, "Mine (including pets)", "mineOnly", 204, -95)
    Checkbox(display, "Glow", "glow", -4, -129)
    local pulse = Checkbox(display, "Pulse glow", "glowPulse", 204, -129)
    Checkbox(display, "Mouseover tooltip", "tooltip", -4, -163)
    Button(display, "Change buff", 270, -167, 122, function()
        context:Select(context.anchor, context.id, "replace")
    end)
    Dropdown(display, "Move to group", 0, -212, 392, Addon.IndicatorAnchors,
        function() return ItemValue("anchor") end, function(value) context:ChangeItem({ anchor = value }) end)
    Label(display, "Move this indicator without changing its display settings.", 0, -270, WIDTH)
    Dropdown(text, "Text", 0, 0, 186, {
        { value = "NONE", label = "None" }, { value = "DURATION", label = "Remaining duration" },
        { value = "STACKS", label = "Stack count" },
    }, function() return ItemValue("text") end, function(value) context:ChangeItem({ text = value }) end)
    Slider(text, "Text scale", 212, 0, 164, 0.5, 3, 0.1,
        function() return ItemValue("textScale") end, function(value) context:ChangeItem({ textScale = value }) end)
    Swatch(text, "Text colour", "textColor", 4, -64)

    Label(addPanel, "Buff name or spell ID", 0, 0)
    local input = CreateFrame("EditBox", nil, addPanel, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", 4, -22); input:SetSize(260, 24)
    input:SetAutoFocus(false); input:SetMaxLetters(100)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local presets = CreateFrame("DropdownButton", nil, addPanel, "WowStyle1DropdownTemplate")
    presets:SetPoint("TOPLEFT", 278, -22); presets:SetWidth(114); presets:SetDefaultText("Buffs")
    presets:SetupMenu(function(_, root)
        local profile, key, token = context:Capture()
        for _, spec in ipairs(Addon.IndicatorSpecializations) do
            -- Clients without a spec's spells (WoW Forever has no Evokers or
            -- Monks) omit its category instead of showing an empty submenu.
            local category
            for _, spellID in ipairs(spec.spells) do
                local spell = C_Spell.GetSpellInfo(spellID)
                if spell then
                    category = category or root:CreateButton(spec.label)
                    category:CreateButton(Addon:GetIndicatorSpellLabel(spellID, spell), function()
                        if context:Matches(profile, key, token) then input:SetText(tostring(spellID)) end
                    end)
                end
            end
        end
    end)
    local function ApplyBuff()
        if not context:CanEdit() then return end
        if context.view == "replace" then
            local spell = Addon:ResolveIndicatorSpell(input:GetText())
            if not spell then context:Message("Buff not found. Try the buff's spell ID.", true); return end
            context:ChangeItem({ spellID = spell.spellID })
            context:Select(context.anchor, context.id, "item")
        elseif context.view == "add" and context.anchor then
            local id, err = Addon:AddDesignerIndicator(context.key, input:GetText(), "ICON", context.anchor)
            if id then context:Select(context.anchor, id, "item") else context:Message(err, true) end
        end
    end
    local apply = Button(addPanel, "Add", 0, -66, 118, ApplyBuff)
    input:SetScript("OnEnterPressed", ApplyBuff)
    Button(addPanel, "Cancel", 128, -66, 88, function()
        context:Select(context.anchor, context.id, context.id and "item" or "group")
    end)
    local addNote = Label(addPanel, "", 0, -110, WIDTH)

    return function(set, item, counts)
        local mode = context.view
        local adding = mode == "add" or mode == "replace"
        if lastToken ~= context.token then
            lastToken = context.token; scroll:SetVerticalScroll(0)
            if adding then
                input:SetText(mode == "replace" and item and tostring(item.spellID) or "")
                if parent:IsVisible() then input:SetFocus() end
            else input:ClearFocus() end
        end
        local anchorName = context.anchor and Addon:GetIndicatorAnchorName(context.anchor)
        title:SetText(mode == "group" and anchorName or adding and (mode == "replace" and "Change buff" or "Add indicator")
            or item and Addon:GetIndicatorSpellLabel(item.spellID, C_Spell.GetSpellInfo(item.spellID)) or "Indicator groups")
        subtitle:SetText(mode == "group" and "Group · " .. (counts[context.anchor] or 0) .. " indicators"
            or anchorName and "Group: " .. anchorName or "Each position has its own group settings.")
        groupPanel:SetShown(mode == "group"); itemPanel:SetShown(mode == "item")
        addPanel:SetShown(adding); emptyPanel:SetShown(mode == "empty")
        local height = mode == "group" and (advanced and 390 or 256)
            or mode == "item" and (section == "Display" and 370 or 210) or 168
        body:SetHeight(height)
        groupPanel:SetHeight(height); itemPanel:SetHeight(height); addPanel:SetHeight(168); emptyPanel:SetHeight(100)
        advancedPanel:SetShown(advanced)
        advancedButton:SetText(advanced and "− Advanced" or "+ Advanced")
        display:SetShown(section == "Display"); text:SetShown(section == "Text")
        displayTab:SetEnabled(section ~= "Display"); textTab:SetEnabled(section ~= "Text")
        local order = 0
        for _, entry in ipairs(set.items) do
            if item and entry.anchor == item.anchor then order = order + 1 end
            if item and entry.id == item.id then break end
        end
        up:SetEnabled(item ~= nil and order > 1)
        down:SetEnabled(item ~= nil and order < (counts[item.anchor] or 0))
        copy:SetEnabled(item ~= nil and #set.items < Addon.MAX_DESIGNER_INDICATORS)
        groupAdd:SetEnabled(#set.items < Addon.MAX_DESIGNER_INDICATORS)
        texture:SetEnabled(item ~= nil and item.type == "ICON")
        squareColor:SetEnabled(item ~= nil and item.type == "SQUARE")
        pulse:SetEnabled(item ~= nil and item.glow)
        apply:SetText(mode == "replace" and "Save buff" or "Add")
        apply:SetEnabled(mode == "replace" or #set.items < Addon.MAX_DESIGNER_INDICATORS)
        addNote:SetText(mode == "replace" and "The indicator keeps its display settings and position in the group."
            or "New indicators start as spell icons. Change their appearance under Display after adding them.")
        for _, refresh in ipairs(refreshers) do refresh() end
        presets:GenerateMenu()
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, height - scroll:GetHeight())))
    end
end
