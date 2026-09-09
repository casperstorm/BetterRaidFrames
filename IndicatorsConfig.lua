local _, Addon = ...

local TREE_WIDTH = 220

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
    local Refresh, refreshEditor, share, scroll
    local context = { profile = self:GetCurrentProfileName(), key = "default", token = 0, view = "empty",
        draft = {}, collapsed = {}, counts = {}, absent = {} }
    function context:GetSet() return Addon:GetIndicatorSet(self.key) end
    function context:GetItem()
        if self.profile == Addon:GetCurrentProfileName() then return Addon:FindDesignerIndicator(self.key, self.id) end
    end
    function context:CanEdit() return not InCombatLockdown() and self.profile == Addon:GetCurrentProfileName() end
    function context:Capture() return self.profile, self.key, self.token end
    function context:Matches(profile, key, token)
        return self:CanEdit() and self.profile == profile and self.key == key and self.token == token
    end
    function context:Refresh() Refresh() end
    function context:Reset()
        self.anchor, self.id, self.view = nil, nil, "empty"
        self.draft, self.collapsed, self.absent = {}, {}, {}
        self.token = self.token + 1
        self.reveal = true
        if share then share:Hide() end
        if scroll then scroll:SetVerticalScroll(0) end
    end
    function context:Select(anchor, id, view)
        self.anchor, self.id, self.view = anchor, id, view
        self.token = self.token + 1
        self.reveal = true
        if anchor then self.draft[anchor], self.collapsed[anchor] = true, false end
        Refresh()
    end
    function context:UnusedAnchors(includeCurrent)
        local result = {}
        for _, anchor in ipairs(Addon.IndicatorAnchors) do
            if (includeCurrent and anchor.value == self.anchor)
                or (not self.counts[anchor.value] and not self.draft[anchor.value]) then
                result[#result + 1] = anchor
            end
        end
        return result
    end
    function context:ChangeItem(changes)
        if not self:CanEdit() or not self:GetItem() or (self.view ~= "item" and self.view ~= "replace") then return end
        Addon:ChangeDesignerIndicator(self.key, self.id, changes)
        if changes.anchor and changes.anchor ~= self.anchor then self:Select(changes.anchor, self.id, "item")
        else Refresh() end
    end
    function context:ChangeGroup(changes)
        if self:CanEdit() and self.view == "group" and self.anchor then
            Addon:ChangeDesignerGroup(self.key, self.anchor, changes); Refresh()
        end
    end
    function context:MoveGroup(destination)
        if not self:CanEdit() or self.view ~= "group" or not self.anchor then return end
        local ok, err = Addon:MoveDesignerGroup(self.key, self.anchor, destination)
        if ok then
            self.draft[self.anchor], self.collapsed[self.anchor] = nil, nil
            self:Select(destination, nil, "group")
        else self:Message(err, true) end
    end
    function context:Reorder(step)
        if self:CanEdit() and self.view == "item" and self:GetItem() then
            Addon:MoveDesignerIndicator(self.key, self.id, step); Refresh()
        end
    end
    function context:CopyItem()
        if not self:CanEdit() or self.view ~= "item" or not self:GetItem() then return end
        local id, err = Addon:DuplicateDesignerIndicator(self.key, self.id)
        if id then self:Select(self.anchor, id, "item") else self:Message(err, true) end
    end
    function context:RemoveItem()
        if self:CanEdit() and self.view == "item" and self:GetItem() then
            Addon:RemoveDesignerIndicator(self.key, self.id)
            self:Select(self.anchor, nil, "group")
        end
    end

    local blizzardBuffs = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    blizzardBuffs:SetPoint("TOPLEFT", 8, y)
    blizzardBuffs.Text:SetText("Show Blizzard buff icons")
    blizzardBuffs.Text:SetFontObject("GameFontHighlightSmall")
    local function RefreshBlizzardBuffs() blizzardBuffs:SetChecked(C_CVar.GetCVarBool("raidFramesDisplayBuffs")) end
    blizzardBuffs:SetScript("OnClick", function(button)
        if not InCombatLockdown() then C_CVar.SetCVar("raidFramesDisplayBuffs", button:GetChecked() and "1" or "0") end
        RefreshBlizzardBuffs()
    end)
    blizzardBuffs:RegisterEvent("CVAR_UPDATE")
    blizzardBuffs:SetScript("OnEvent", RefreshBlizzardBuffs)
    local cvarNote = Label(content, "Raid and Raid-Style Party Frames; shared across profiles.", 280, y - 8, 390)
    cvarNote:SetTextColor(0.75, 0.75, 0.75)
    y = y - 36
    local profileLabel = Label(content, "", 12, y, 676)
    local preview = self:CreateDesignerPreview(content)
    preview:SetPoint("TOPLEFT", 12, y - 24)
    local previewGroup = Label(content, "", 206, y - 25, 470)
    local previewActive = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    previewActive:SetPoint("TOPLEFT", 198, y - 46)
    previewActive.Text:SetText("Selected buff active")
    previewActive.Text:SetFontObject("GameFontHighlightSmall")
    previewActive:SetScript("OnClick", function(button)
        if context.id then context.absent[context.id] = not button:GetChecked(); Refresh() end
    end)

    local status = Label(content, "", 12, 0, 676)
    status:ClearAllPoints(); status:SetPoint("BOTTOMLEFT", 12, 0)
    function context:Message(text, error)
        status:SetText(text or "")
        status:SetTextColor(error and 1 or 0.75, error and 0.35 or 0.75, error and 0.3 or 0.75)
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
    local sets = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    sets.label = Label(content, "Editing set", 12, y - 91)
    sets:SetPoint("TOPLEFT", 12, y - 107); sets:SetWidth(300)
    sets:SetupMenu(function(_, root)
        local profile, key, token = context:Capture()
        for _, option in ipairs(SetOptions()) do
            root:CreateRadio(option.label, function(value) return context.key == value end, function(value)
                if context:Matches(profile, key, token) then context.key = value; context:Reset(); Refresh() end
            end, option.value)
        end
    end)
    local useDefault = Button(content, "Use Default", 324, y - 107, 116, function()
        if context:CanEdit() then Addon:UseDefaultIndicators(context.key); context:Reset(); Refresh() end
    end)

    -- Review imports against the captured profile and set before replacing them.
    share = CreateFrame("Frame", nil, content, "BackdropTemplate")
    share:SetPoint("TOPLEFT", 4, y - 15); share:SetPoint("BOTTOMRIGHT", -4, 26)
    share:SetFrameLevel(content:GetFrameLevel() + 12); share:EnableMouse(true)
    share:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    share:SetBackdropColor(0.1, 0.1, 0.1, 1); share:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    local shareTitle = Label(share, "", 12, -12, 610)
    local shareInput = CreateFrame("EditBox", nil, share, "InputBoxTemplate")
    shareInput:SetPoint("TOPLEFT", 16, -40); shareInput:SetPoint("TOPRIGHT", -16, -40)
    shareInput:SetHeight(26); shareInput:SetAutoFocus(false); shareInput:SetMaxLetters(65536)
    local shareNote = Label(share, "", 12, -80, 602)
    local imported, destinationProfile, destinationKey, shareApply
    shareApply = Button(share, "Review Import", 12, -133, 130, function()
        if not context:CanEdit() or destinationProfile ~= context.profile or destinationKey ~= context.key then
            shareNote:SetText("The editing context changed. Close and reopen Import."); return
        end
        if imported then
            Addon:SaveIndicatorSet(destinationKey, imported); context:Reset(); Refresh()
        else
            local err
            imported, err = Addon:DecodeDesignerIndicators(shareInput:GetText())
            if imported then
                shareNote:SetText("Replace this set with " .. #imported.items .. " imported indicators? The current set will be replaced.")
                shareApply:SetText("Replace Set")
            else shareNote:SetText(err) end
        end
    end)
    shareInput:SetScript("OnTextChanged", function() imported = nil; shareApply:SetText("Review Import") end)
    shareInput:SetScript("OnEscapePressed", function() share:Hide() end)
    Button(share, "Close", 152, -133, 80, function() share:Hide() end)
    share:Hide()
    local function OpenShare(export)
        if not context:CanEdit() then return end
        destinationProfile, destinationKey = context.profile, context.key
        imported = nil
        shareTitle:SetText(export and "Export Indicators" or "Import Indicators")
        shareApply:SetShown(not export)
        shareInput:SetText(export and Addon:ExportDesignerIndicators(context.key) or "")
        shareNote:SetText(export and "Copy this text to share the selected set, including its groups."
            or "Paste a BetterRaidFrames indicator export, then review it before replacing this set.")
        share:Show(); shareInput:SetFocus(); shareInput:HighlightText()
    end
    Button(content, "Import", 452, y - 107, 92, function() OpenShare(false) end)
    Button(content, "Export", 556, y - 107, 88, function() OpenShare(true) end)

    local addGroup = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    addGroup.label = Label(content, "Groups", 12, y - 145)
    addGroup:SetPoint("TOPLEFT", 12, y - 165); addGroup:SetWidth(TREE_WIDTH)
    addGroup:SetDefaultText("+ Add group")
    addGroup:SetupMenu(function(_, root)
        local profile, key, token = context:Capture()
        for _, anchor in ipairs(context:UnusedAnchors()) do
            root:CreateRadio(anchor.label, function() return false end, function(value)
                if context:Matches(profile, key, token) then context:Select(value, nil, "group") end
            end, anchor.value)
        end
    end)
    scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, y - 200); scroll:SetPoint("BOTTOMLEFT", 12, 35); scroll:SetWidth(TREE_WIDTH)
    local tree = CreateFrame("Frame", nil, scroll)
    tree:SetSize(TREE_WIDTH, 1); scroll:SetScrollChild(tree)
    local separator = content:CreateTexture(nil, "BACKGROUND")
    separator:SetColorTexture(0.5, 0.5, 0.5, 0.25)
    separator:SetPoint("TOPLEFT", 254, y - 145); separator:SetPoint("BOTTOMLEFT", 254, 35); separator:SetWidth(1)
    local inspector = CreateFrame("Frame", nil, content)
    inspector:SetPoint("TOPLEFT", 270, y - 145); inspector:SetPoint("BOTTOMRIGHT", -4, 35)
    refreshEditor = self:BuildDesignerEditor(inspector, context)

    local groupRows, itemRows = {}, {}
    local function Entry(parent, x, width, callback)
        local entry = CreateFrame("Button", nil, parent)
        entry:SetPoint("TOPLEFT", x, 0); entry:SetSize(width, 28)
        entry.background = entry:CreateTexture(nil, "BACKGROUND")
        entry.background:SetAllPoints(); entry.background:SetColorTexture(0.45, 0.38, 0.12, 0.5)
        entry.label = Label(entry, "", 4, -8, width - 8); entry.label:SetWordWrap(false)
        entry:SetScript("OnClick", callback)
        entry:SetScript("OnEnter", function() entry.background:Show() end)
        entry:SetScript("OnLeave", function() entry.background:SetShown(entry.selected) end)
        function entry:Select(value)
            self.selected = value; self.background:SetShown(value)
            self.label:SetTextColor(1, value and 0.82 or 1, value and 0 or 1)
        end
        return entry
    end
    local function GroupRow(anchor)
        if groupRows[anchor] then return groupRows[anchor] end
        local row = CreateFrame("Frame", nil, tree); row:SetSize(TREE_WIDTH, 28)
        row.toggle = Button(row, "−", 0, -3, 22, function()
            context.collapsed[anchor] = not context.collapsed[anchor]
            if context.collapsed[anchor] and context.anchor == anchor then
                context.id, context.view = nil, "group"; context.token = context.token + 1
            end
            Refresh()
        end)
        row.select = Entry(row, 24, TREE_WIDTH - 24, function() context:Select(anchor, nil, "group") end)
        row.add = Button(tree, "+ Add indicator", 24, 0, TREE_WIDTH - 24, function() context:Select(anchor, nil, "add") end)
        row.anchor = anchor
        groupRows[anchor] = row
        return row
    end
    local function ItemRow(index)
        if itemRows[index] then return itemRows[index] end
        local row = CreateFrame("Frame", nil, tree); row:SetSize(TREE_WIDTH, 28)
        row.enabled = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        row.enabled:SetPoint("TOPLEFT", 16, 0)
        row.enabled:SetScript("OnClick", function(button)
            if context:CanEdit() and row.item then
                Addon:ChangeDesignerIndicator(context.key, row.item.id, { enabled = button:GetChecked() })
            end
            Refresh()
        end)
        row.select = Entry(row, 50, TREE_WIDTH - 50, function()
            if row.item then context:Select(row.item.anchor, row.item.id, "item") end
        end)
        row.icon = row.select:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("TOPLEFT", 2, -6); row.icon:SetSize(16, 16)
        row.select.label:ClearAllPoints(); row.select.label:SetPoint("TOPLEFT", 22, -8)
        row.select.label:SetWidth(TREE_WIDTH - 76)
        itemRows[index] = row
        return row
    end

    Refresh = function()
        if context.profile ~= Addon:GetCurrentProfileName() then
            context.profile = Addon:GetCurrentProfileName(); context:Reset()
        end
        local set = context:GetSet()
        local counts = {}
        for _, item in ipairs(set.items) do counts[item.anchor] = (counts[item.anchor] or 0) + 1 end
        context.counts = counts
        for id in pairs(context.absent) do
            if not Addon:FindDesignerIndicator(context.key, id) then context.absent[id] = nil end
        end
        local item = context:GetItem()
        if context.id and not item then context.id, context.view = nil, "group"; context.token = context.token + 1 end
        if item and item.anchor ~= context.anchor then context.anchor = item.anchor; context.token = context.token + 1 end
        if not context.anchor then
            for _, anchor in ipairs(Addon.IndicatorAnchors) do
                if counts[anchor.value] then context.anchor, context.view = anchor.value, "group"; break end
            end
        end
        if context.anchor then context.draft[context.anchor] = true end
        local ownSet = Addon:GetSetting("indicators").sets[context.key] ~= nil
        profileLabel:SetText("Profile: " .. context.profile .. (context.key ~= "default" and not ownSet
            and " — using Default; edits create an override" or ""))
        useDefault:SetEnabled(context.key ~= "default" and ownSet)
        RefreshBlizzardBuffs(); sets:GenerateMenu(); addGroup:GenerateMenu()
        addGroup:SetEnabled(#context:UnusedAnchors() > 0)
        local offset, rowIndex, selectedOffset = 0, 0, nil
        for _, anchor in ipairs(Addon.IndicatorAnchors) do
            local value = anchor.value
            local row = groupRows[value]
            if counts[value] or context.draft[value] then
                row = row or GroupRow(value)
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -offset); row:Show()
                row.select.label:SetText(anchor.label .. " · " .. (counts[value] or 0))
                row.select:Select(context.anchor == value and context.view ~= "item" and context.view ~= "replace")
                if row.select.selected then selectedOffset = offset end
                row.toggle:SetText(context.collapsed[value] and "+" or "−")
                offset = offset + 30
                if not context.collapsed[value] then
                    for _, entry in ipairs(set.items) do
                        if entry.anchor == value then
                            rowIndex = rowIndex + 1
                            local member = ItemRow(rowIndex)
                            member.item = entry
                            member:ClearAllPoints(); member:SetPoint("TOPLEFT", 0, -offset); member:Show()
                            member.enabled:SetChecked(entry.enabled)
                            local spell = C_Spell.GetSpellInfo(entry.spellID)
                            member.select.label:SetText(Addon:GetIndicatorSpellLabel(entry.spellID, spell))
                            member.select:Select(context.id == entry.id)
                            if member.select.selected then selectedOffset = offset end
                            member.icon:SetVertexColor(1, 1, 1, 1)
                            if entry.type == "ICON" then member.icon:SetTexture(spell and spell.iconID or 134400)
                            else local c = entry.color; member.icon:SetColorTexture(c.r, c.g, c.b, c.a) end
                            offset = offset + 28
                        end
                    end
                    row.add:ClearAllPoints(); row.add:SetPoint("TOPLEFT", 24, -offset - 2); row.add:Show()
                    row.add:SetEnabled(#set.items < Addon.MAX_DESIGNER_INDICATORS)
                    offset = offset + 34
                else row.add:Hide() end
                offset = offset + 6
            elseif row then row:Hide(); row.add:Hide() end
        end
        for index = rowIndex + 1, #itemRows do itemRows[index]:Hide(); itemRows[index].item = nil end
        tree:SetHeight(math.max(offset, 1))
        local position, height = scroll:GetVerticalScroll(), scroll:GetHeight()
        if context.reveal and selectedOffset then
            if selectedOffset < position then position = selectedOffset
            elseif selectedOffset + 28 > position + height then position = selectedOffset + 28 - height end
        end
        context.reveal = false
        scroll:SetVerticalScroll(math.max(0, math.min(position, offset - height)))
        previewActive:SetShown(item ~= nil)
        previewActive:SetChecked(item ~= nil and not context.absent[item.id])
        previewGroup:SetText(context.anchor and Addon:GetIndicatorAnchorName(context.anchor) .. " group" or "Live indicator preview")
        refreshEditor(set, item, counts)
        local overflow = preview:Refresh(set, context.id, context.absent)
        if Addon:HasPendingDesignerIndicators() then context:Message("Saved. Indicators will update when aura restrictions end.")
        elseif overflow then context:Message("A group exceeds the preview frame. Reduce its size or spacing.")
        elseif #set.items == 0 then context:Message("Add a group, then add its indicators. Up to 32 indicators per set.")
        else context:Message("Select a group for layout, or an indicator for its display settings.") end
    end
    content:HookScript("OnHide", function() share:Hide() end)
    Refresh()
    return Refresh
end
