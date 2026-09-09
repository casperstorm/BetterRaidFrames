local _, Addon = ...

-- Anchor the entire group to the chosen point, but start flow at an edge on
-- its primary axis. A CENTER flow point would overlap differently sized icons.
function Addon:GetIndicatorFlowSettings(anchor, group)
    local vertical = group.grow == "UP" or group.grow == "DOWN"
    local top = anchor:find("TOP", 1, true)
    local bottom = anchor:find("BOTTOM", 1, true)
    local left = anchor:find("LEFT", 1, true)
    local right = anchor:find("RIGHT", 1, true)
    local x = vertical and (left and "LEFT" or right and "RIGHT" or "")
        or (group.grow == "LEFT" and "RIGHT" or "LEFT")
    local y = vertical and (group.grow == "UP" and "BOTTOM" or "TOP")
        or (top and "TOP" or bottom and "BOTTOM" or "")
    return {
        point = y .. x,
        axis = vertical and AnchorUtil.FlowLayoutAxis.Vertical or AnchorUtil.FlowLayoutAxis.Horizontal,
        horizontal = (group.grow == "LEFT" or (vertical and right)) and AnchorUtil.FlowDirection.Left
            or AnchorUtil.FlowDirection.Right,
        vertical = (group.grow == "UP" or (not vertical and bottom)) and AnchorUtil.FlowDirection.Up
            or AnchorUtil.FlowDirection.Down,
        offsetX = (left and 2 or right and -2 or 0) + (group.offsetX or 0),
        offsetY = (top and -2 or bottom and 2 or 0) + (group.offsetY or 0),
    }
end

local function GroupFrameLevel(parentLevel, group)
    return math.max(0, parentLevel + 10 + (group.offsetZ or 0))
end

local function StopPulse(visual)
    if visual.pulsing then
        visual.glowPulse:Stop()
        visual.glow:SetAlpha(1)
        visual.pulsing = false
    end
end

local function StyleGlow(visual, item)
    if not item.glow then
        StopPulse(visual)
        if visual.glow then visual.glow:Hide() end
        return
    end
    if not visual.glow then
        local glow = visual.overlay:CreateTexture(nil, "ARTWORK")
        glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
        glow:SetTexCoord(0.0078125, 0.5078125, 0.27734375, 0.52734375)
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", visual.button, "CENTER")
        visual.glow = glow
    end
    local glow = visual.glow
    glow:SetSize(item.size * 1.4, item.size * 1.4)
    glow:Show()
    if item.glowPulse then
        if not visual.glowPulse then
            local pulse = glow:CreateAnimationGroup()
            pulse:SetLooping("BOUNCE")
            local fade = pulse:CreateAnimation("Alpha")
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0.35)
            fade:SetDuration(0.6)
            fade:SetOrder(1)
            fade:SetSmoothing("IN_OUT")
            visual.glowPulse = pulse
        end
        if not visual.pulsing then visual.glowPulse:Play(); visual.pulsing = true end
    else
        StopPulse(visual)
        glow:SetAlpha(1)
    end
end

function Addon:CreateDesignerVisual(button)
    button:EnableMouse(false)
    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    return { button = button, texture = texture }
end

local durationFormatter
function Addon:StyleDesignerVisual(visual, item, preview)
    local button, texture = visual.button, visual.texture
    if not preview then
        button:ClearIcon()
        button:ClearDurationCooldown()
        button:ClearDurationText()
        button:ClearApplicationCount()
        button:SetMouseMotionEnabled(item.tooltip)
    end
    button:SetSize(item.size, item.size)
    texture:Hide()
    texture:SetVertexColor(1, 1, 1, 1)
    if item.type == "SQUARE" then
        local c = item.color
        texture:SetColorTexture(c.r, c.g, c.b, c.a)
        texture:Show()
    elseif item.showTexture then
        if preview then
            local spell = C_Spell.GetSpellInfo(item.spellID)
            texture:SetTexture(spell and spell.iconID or 134400)
        else
            button:SetIcon(texture)
        end
        texture:Show()
    end

    local swipe = item.cooldown and (item.type == "SQUARE" or item.showTexture)
    local cooldown = visual.cooldown
    if swipe and not cooldown then
        cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:EnableMouse(false)
        cooldown:SetReverse(true)
        cooldown:SetHideCountdownNumbers(true)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawSwipe(true)
        visual.cooldown = cooldown
    end
    if cooldown then
        cooldown:Clear()
        cooldown:SetShown(swipe)
        if swipe then
            if preview then cooldown:SetCooldown(GetTime(), 30)
            else button:SetDurationCooldown(cooldown) end
        end
    end

    local hasText = item.text ~= "NONE"
    if (item.glow or hasText) and not visual.overlay then
        local overlay = CreateFrame("Frame", nil, button)
        overlay:SetAllPoints()
        overlay:EnableMouse(false)
        visual.overlay = overlay
    end
    if visual.overlay then
        -- Permanent auras can hide their cooldown. Text and glow use an
        -- independent host above the swipe, following native aura visibility.
        visual.overlay:SetFrameLevel((cooldown or button):GetFrameLevel() + 1)
        visual.overlay:SetShown(item.glow or hasText)
    end
    StyleGlow(visual, item)
    if hasText and not visual.text then
        local text = visual.overlay:CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER")
        text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
        visual.text = text
    end
    local text = visual.text
    if text then
        text:SetText(preview and item.text == "STACKS" and "3" or "")
        text:SetShown(hasText)
        if hasText then
            text:SetScale(item.textScale)
            local c = item.textColor
            text:SetTextColor(c.r, c.g, c.b, c.a)
            text:SetAlpha(1)
        end
    end
    if preview then
        visual.previewItem = item
    elseif item.text == "STACKS" then
        button:SetApplicationCount(text)
    elseif item.text == "DURATION" then
        if not durationFormatter then
            durationFormatter = C_StringUtil.CreateNumericRuleFormatter()
            durationFormatter:SetBreakpoints({ { threshold = 0, rounding = Enum.NumericRuleFormatRounding.Down, format = "%d" } })
        end
        button:SetDurationText(text, { textFormatter = durationFormatter })
    end
end

local states = {}
local hooked, refreshQueued = false, false
local entriesBySet = setmetatable({}, { __mode = "k" })

local function GetEntries(set)
    local entries = entriesBySet[set]
    if not entries then
        entries = {}
        for _, item in ipairs(set.items) do
            if item.enabled then
                entries[item.anchor] = entries[item.anchor] or {}
                table.insert(entries[item.anchor], item)
            end
        end
        entriesBySet[set] = entries
    end
    return entries
end

local function Equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

local function SetPending(state, pending)
    if state.pending == pending then return end
    state.pending = pending
    if not refreshQueued and Addon.RefreshConfig and Addon:IsConfigOpen() then
        refreshQueued = true
        C_Timer.After(0, function() refreshQueued = false; Addon:RefreshConfig() end)
    end
end

local function BindUnit(state, unit)
    if state.unit == unit then return end
    for _, bucket in pairs(state.buckets) do bucket.container:SetUnit(unit) end
    state.unit = unit
end

local function CanRestyle(state)
    for _, bucket in pairs(state.buckets) do
        for _, pool in ipairs(bucket.pools) do
            for _, visual in ipairs(pool.visuals) do
                if visual.button:IsForbidden() then return false end
            end
        end
    end
    return true
end

local function SetBucketEnabled(bucket, enabled)
    if bucket.enabled == enabled then return end
    bucket.container:SetEnabled(enabled)
    bucket.container:SetShown(enabled)
    bucket.enabled = enabled
end

local function DeactivatePool(bucket, index)
    local pool = bucket.pools[index]
    if not pool.active then return end
    bucket.container:SetAuraGroupCandidateFilters(tostring(index), { includeSpellIDs = {} })
    for _, visual in ipairs(pool.visuals) do
        StopPulse(visual)
        if visual.cooldown then visual.cooldown:Clear() end
        visual.button:ClearIcon()
        visual.button:ClearDurationCooldown()
        visual.button:ClearDurationText()
        visual.button:ClearApplicationCount()
    end
    pool.active = false
end

local function Disable(state)
    if state.disabled and not state.needsCleanup then return end
    for _, bucket in pairs(state.buckets) do SetBucketEnabled(bucket, false) end
    state.disabled = true
    state.needsCleanup = not CanRestyle(state)
    if not state.needsCleanup then
        for _, bucket in pairs(state.buckets) do
            for index in ipairs(bucket.pools) do DeactivatePool(bucket, index) end
        end
        state.applied = nil
    end
end


local function ConfigureBucket(bucket, frame, anchor, group, level)
    if bucket.anchor == anchor and bucket.level == level and Equal(bucket.group, group) then return end
    local container = bucket.container
    local layout = Addon:GetIndicatorFlowSettings(anchor, group)
    container:ClearAllPoints()
    container:SetPoint(anchor, frame, anchor, layout.offsetX, layout.offsetY)
    container:SetFrameLevel(GroupFrameLevel(level, group))
    container:SetFlowLayoutAxis(layout.axis)
    container:SetFlowLayoutAnchorPoint(layout.point)
    container:SetFlowLayoutGrowthDirection(layout.horizontal, layout.vertical)
    container:SetFlowLayoutPadding(0, 0, 0, 0)
    container:SetFlowLayoutMaximumLineSize(nil)
    bucket.anchor, bucket.group, bucket.level = anchor, group, level
end

local function ConfigurePool(bucket, index, item, spacing)
    local pool = bucket.pools[index]
    local previous = pool and pool.entry
    local active = pool and pool.active
    if pool then pool.entry = item end
    if not pool then
        pool = { entry = item, visuals = {} }
        bucket.pools[index] = pool
        bucket.container:AddAuraGroup(tostring(index), "HELPFUL", {
            maxFrameCount = 1,
            candidateFilters = { includeSpellIDs = {} },
            initializeFrame = function(button)
                -- Blizzard invokes this for every preallocated button, including
                -- batches created while restricted. The current entry is immutable.
                local visual = Addon:CreateDesignerVisual(button)
                Addon:StyleDesignerVisual(visual, pool.entry)
                pool.visuals[#pool.visuals + 1] = visual
            end,
        })
    elseif not active or not Equal(previous, item) then
        for _, visual in ipairs(pool.visuals) do Addon:StyleDesignerVisual(visual, item) end
    end
    if pool.spacing ~= spacing then
        bucket.container:SetAuraGroupLayout(tostring(index), { layoutIndex = index, groupSpacing = spacing })
        pool.spacing = spacing
    end
    if not active or previous.spellID ~= item.spellID or previous.mineOnly ~= item.mineOnly then
        local filters = { includeSpellIDs = { [item.spellID] = true } }
        if item.mineOnly then filters.isFromPlayerOrPlayerPet = true end
        bucket.container:SetAuraGroupCandidateFilters(tostring(index), filters)
    end
    pool.entry, pool.active = item, true
end

local function UnitFrameShown(frame) Addon:UpdateDesignerIndicators(frame) end
local function UnitFrameHidden(frame)
    if states[frame] then Disable(states[frame]) end
end

function Addon:UpdateDesignerIndicators(frame, settings)
    if not frame then return end
    local state = states[frame]
    local unit, assigned = frame.displayedUnit, frame.unit
    local secret = issecretvalue and (issecretvalue(unit) or issecretvalue(assigned))
    if not secret then unit = unit or assigned end
    if secret or not unit or not self:IsRaidOrPartyFrame(frame) then
        if state then BindUnit(state, "none"); Disable(state); SetPending(state, false) end
        return
    end
    if not frame:IsVisible() then
        if state then Disable(state); SetPending(state, false) end
        return
    end
    local set = self:GetIndicatorSet(nil, settings)
    local entries = GetEntries(set)
    if not next(entries) then
        if state then BindUnit(state, unit); Disable(state); SetPending(state, false) end
        return
    end
    if not state then
        state = { buckets = {}, pending = false }
        states[frame] = state
        frame:HookScript("OnShow", UnitFrameShown)
        frame:HookScript("OnHide", UnitFrameHidden)
    end
    BindUnit(state, unit)
    local level = frame:GetFrameLevel()
    if state.level ~= level or not Equal(state.applied, set) then
        if not CanRestyle(state) then
            Disable(state)
            SetPending(state, true)
            return
        end
        for _, anchorOption in ipairs(self.IndicatorAnchors) do
            local anchor = anchorOption.value
            local items, bucket = entries[anchor], state.buckets[anchor]
            if items then
                if not bucket then
                    -- Reuse an inactive anchor's container when a group moves.
                    for oldAnchor, unused in pairs(state.buckets) do
                        if not entries[oldAnchor] then
                            bucket = unused
                            state.buckets[oldAnchor] = nil
                            state.buckets[anchor] = bucket
                            break
                        end
                    end
                end
                if not bucket then
                    local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
                    container:EnableMouse(false)
                    container:SetUnit(unit)
                    bucket = { container = container, pools = {} }
                    state.buckets[anchor] = bucket
                end
                local group = set.groups[anchor] or self:NormalizeIndicatorGroup(nil, anchor)
                ConfigureBucket(bucket, frame, anchor, group, level)
                for index, item in ipairs(items) do ConfigurePool(bucket, index, item, group.spacing) end
            end
            if bucket then
                -- Retain and reuse groups: the public API cannot remove them.
                for index = (items and #items or 0) + 1, #bucket.pools do
                    DeactivatePool(bucket, index)
                end
            end
        end
    end
    state.applied, state.level = set, level
    state.disabled, state.needsCleanup = false, false
    for anchor, bucket in pairs(state.buckets) do
        local enabled = entries[anchor] ~= nil
        SetBucketEnabled(bucket, enabled)
    end
    SetPending(state, false)
end

function Addon:HasPendingDesignerIndicators()
    for frame, state in pairs(states) do if state.pending and frame:IsVisible() then return true end end
    return false
end

function Addon:HookDesignerIndicators()
    if hooked then return end
    hooked = true
    local function Update(frame) Addon:UpdateDesignerIndicators(frame) end
    hooksecurefunc("CompactUnitFrame_SetUnit", Update)
    hooksecurefunc("CompactUnitFrame_UpdateInVehicle", Update)
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ADDON_RESTRICTION_STATE_CHANGED",
        "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" }) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function()
        Addon:RequestFeatureUpdate("indicators")
        if Addon.RefreshConfig and Addon:IsConfigOpen() then Addon:RefreshConfig() end
    end)
end

function Addon:CreateDesignerPreview(parent)
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetSize(180, 56)
    local bg = preview:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.16, 0.13, 1)
    local health = preview:CreateTexture(nil, "ARTWORK")
    health:SetPoint("TOPLEFT", 1, -1)
    health:SetSize(148, 54)
    health:SetColorTexture(0.24, 0.42, 0.3, 1)
    local name = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("TOPLEFT", 5, -4)
    name:SetText("Preview")
    local buckets, visuals = {}, {}
    local start, lastSecond = GetTime(), nil
    local currentSet, currentSelected, currentAbsent
    local function UpdatePreview()
        local elapsed = GetTime() - start
        local restarted = elapsed >= 30
        if restarted then start = GetTime(); elapsed = 0 end
        local second = math.floor(30 - elapsed)
        if second == lastSecond then return end
        lastSecond = second
        for _, visual in ipairs(visuals) do
            local item = visual.previewItem
            if item then
                if restarted and item.cooldown and (item.type == "SQUARE" or item.showTexture) then
                    visual.cooldown:SetCooldown(start, 30)
                end
                if item.text == "DURATION" then visual.text:SetText(tostring(second)) end
            end
        end
    end
    function preview:Refresh(set, selected, absent)
        currentSet, currentSelected, currentAbsent = set, selected, absent
        if not self:IsVisible() then return false end
        local descriptions, timed = {}, false
        for index = #set.items + 1, #visuals do
            local visual = visuals[index]
            StopPulse(visual)
            if visual.cooldown then visual.cooldown:Clear() end
            visual.button:Hide()
            visual.previewItem = nil
        end
        for index, item in ipairs(set.items) do
            local visual = visuals[index]
            if not visual then
                visual = Addon:CreateDesignerVisual(CreateFrame("Frame", nil, self))
                visuals[index] = visual
            end
            Addon:StyleDesignerVisual(visual, item, true)
            local visible = item.enabled and not absent[item.id]
            visual.button:SetShown(visible)
            if not visible then
                StopPulse(visual)
                if visual.cooldown then visual.cooldown:Clear() end
                visual.previewItem = nil
            elseif item.text == "DURATION" or (item.cooldown and (item.type == "SQUARE" or item.showTexture)) then
                timed = true
            end
            local anchor = item.anchor
            if not buckets[anchor] then
                buckets[anchor] = { frame = CreateFrame("Frame", nil, self), flow = CreateFromMixins(AnchorUtil.FlowLayoutMixin) }
                buckets[anchor].flow:Init()
            end
            local bucket = buckets[anchor]
            visual.button:SetParent(bucket.frame)
            descriptions[anchor] = descriptions[anchor] or {}
            local group = set.groups[anchor] or Addon:NormalizeIndicatorGroup(nil, anchor)
            table.insert(descriptions[anchor], { elements = visible and { visual.button } or {}, groupSpacing = group.spacing })
            visual.button:SetAlpha(item.id == selected and 1 or 0.8)
        end
        local overflow = false
        for anchor, bucket in pairs(buckets) do
            local group = set.groups[anchor] or Addon:NormalizeIndicatorGroup(nil, anchor)
            local layout = Addon:GetIndicatorFlowSettings(anchor, group)
            bucket.frame:ClearAllPoints()
            bucket.frame:SetPoint(anchor, self, anchor, layout.offsetX, layout.offsetY)
            bucket.frame:SetFrameLevel(GroupFrameLevel(self:GetFrameLevel(), group))
            bucket.flow:SetLayoutAxis(layout.axis)
            bucket.flow:SetAnchorPoint(layout.point)
            bucket.flow:SetGrowthDirection(layout.horizontal, layout.vertical)
            bucket.flow:Apply(bucket.frame, descriptions[anchor] or {})
            if bucket.frame:GetWidth() > 176 or bucket.frame:GetHeight() > 52 then overflow = true end
        end
        start = GetTime()
        lastSecond = nil
        self:SetScript("OnUpdate", timed and UpdatePreview or nil)
        if timed then UpdatePreview() end
        return overflow
    end
    preview:SetScript("OnHide", function()
        preview:SetScript("OnUpdate", nil)
        for _, visual in ipairs(visuals) do
            StopPulse(visual)
            if visual.cooldown then visual.cooldown:Clear() end
        end
    end)
    preview:SetScript("OnShow", function()
        if currentSet then preview:Refresh(currentSet, currentSelected, currentAbsent) end
    end)
    return preview
end
