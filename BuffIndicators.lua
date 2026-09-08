local _, Addon = ...

Addon.MAX_BUFF_INDICATORS = 8
Addon.MAX_BUFF_INDICATOR_HEIGHT = 12
Addon.MIN_BUFF_INDICATOR_FRAME_LEVEL = -10
Addon.MAX_BUFF_INDICATOR_FRAME_LEVEL = 200

local DEFAULT_COLORS = {
    { 1, 0.82, 0.4 },
    { 0.4, 0.85, 1 },
    { 0.55, 1, 0.55 },
    { 0.85, 0.6, 1 },
}

local function IsSpellID(value)
    return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
end

local function ColorComponent(value, fallback)
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.max(0, math.min(1, value))
end

local function NormalizeInteger(value, minimum, maximum, fallback)
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
end

function Addon:NormalizeBuffIndicatorHeight(value)
    return NormalizeInteger(value, 1, self.MAX_BUFF_INDICATOR_HEIGHT, 2)
end

function Addon:NormalizeBuffIndicatorFrameLevel(value)
    return NormalizeInteger(value, self.MIN_BUFF_INDICATOR_FRAME_LEVEL, self.MAX_BUFF_INDICATOR_FRAME_LEVEL, 10)
end

function Addon:NormalizeBuffIndicatorDirection(value)
    return value == "REMAINING" and "REMAINING" or "ELAPSED"
end

function Addon:NormalizeBuffIndicatorPosition(value)
    if value == "BOTTOM" or value == "LEFT" or value == "RIGHT" then return value end
    return "TOP"
end

function Addon:IsBuffIndicatorVertical(position)
    return position == "LEFT" or position == "RIGHT"
end

function Addon:SetBuffIndicatorBarOrientation(bar, position)
    bar:SetOrientation(self:IsBuffIndicatorVertical(position) and "VERTICAL" or "HORIZONTAL")
end

function Addon:CreateBuffIndicatorBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetAllPoints()
    bar:EnableMouse(false)
    bar:SetOrientation("HORIZONTAL")
    bar:SetReverseFill(false)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.background = bar:CreateTexture(nil, "BACKGROUND")
    bar.background:SetAllPoints()
    return bar
end

function Addon:SetBuffIndicatorBarColor(bar, entry)
    bar:SetStatusBarColor(entry.r, entry.g, entry.b, 1)
    bar.background:SetColorTexture(entry.r, entry.g, entry.b, 0.25)
end

local function EntrySetting(entry, key, legacy, legacyKey)
    if entry[key] ~= nil then return entry[key] end
    return legacy and legacy[legacyKey]
end

function Addon:NormalizeBuffIndicators(entries, legacy)
    local result, seen = {}, {}
    if type(entries) ~= "table" then return result end
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and IsSpellID(entry.spellID) and not seen[entry.spellID] then
            local color = DEFAULT_COLORS[(#result % #DEFAULT_COLORS) + 1]
            result[#result + 1] = {
                spellID = entry.spellID,
                enabled = entry.enabled ~= false,
                mineOnly = entry.mineOnly ~= false,
                r = ColorComponent(entry.r, color[1]),
                g = ColorComponent(entry.g, color[2]),
                b = ColorComponent(entry.b, color[3]),
                thickness = self:NormalizeBuffIndicatorHeight(EntrySetting(entry, "thickness", legacy, "buffIndicatorHeight")),
                direction = self:NormalizeBuffIndicatorDirection(EntrySetting(entry, "direction", legacy, "buffIndicatorDirection")),
                position = self:NormalizeBuffIndicatorPosition(EntrySetting(entry, "position", legacy, "buffIndicatorPosition")),
                frameLevel = self:NormalizeBuffIndicatorFrameLevel(EntrySetting(entry, "frameLevel", legacy, "buffIndicatorFrameLevel")),
            }
            seen[entry.spellID] = true
            if #result == self.MAX_BUFF_INDICATORS then break end
        end
    end
    return result
end

function Addon:AddBuffIndicator(input)
    local entries = self:NormalizeBuffIndicators(self:GetSetting("buffIndicators"))
    if #entries >= self.MAX_BUFF_INDICATORS then
        return false, "You can track up to " .. self.MAX_BUFF_INDICATORS .. " buffs per profile."
    end
    input = tostring(input or ""):match("^%s*(.-)%s*$")
    local spell = input ~= "" and C_Spell.GetSpellInfo(tonumber(input) or input)
    if not spell or not IsSpellID(spell.spellID) then
        return false, "Buff not found. Try the buff's spell ID."
    end
    for _, entry in ipairs(entries) do
        if entry.spellID == spell.spellID then return false, "That buff is already in the list." end
    end
    entries[#entries + 1] = { spellID = spell.spellID }
    self:SetSetting("buffIndicators", self:NormalizeBuffIndicators(entries))
    return true
end

function Addon:ChangeBuffIndicator(index, changes)
    local entries = self:NormalizeBuffIndicators(self:GetSetting("buffIndicators"))
    if not entries[index] then return end
    for key, value in pairs(changes) do entries[index][key] = value end
    self:SetSetting("buffIndicators", self:NormalizeBuffIndicators(entries))
end

function Addon:RemoveBuffIndicator(index)
    local entries = self:NormalizeBuffIndicators(self:GetSetting("buffIndicators"))
    if not entries[index] then return end
    table.remove(entries, index)
    self:SetSetting("buffIndicators", entries)
end

-- Segment positions depend only on configuration, never on which auras exist.
-- Disabled entries keep their space so the other buffs do not move.
function Addon:GetBuffIndicatorSegment(length, count, index)
    local available = math.max(0, length - 4)
    local start = math.floor(available * (index - 1) / count)
    local finish = math.floor(available * index / count)
    return 2 + start, math.max(1, finish - start - (index < count and 1 or 0))
end

function Addon:GetBuffIndicatorLayouts(entries, width, height, frameLevel)
    local counts, indices, layouts = {}, {}, {}
    for _, entry in ipairs(entries) do
        counts[entry.position] = (counts[entry.position] or 0) + 1
    end
    for index, entry in ipairs(entries) do
        local position = entry.position
        indices[position] = (indices[position] or 0) + 1
        layouts[index] = {
            width = width, height = height, position = position,
            thickness = entry.thickness, direction = entry.direction,
            frameLevel = math.max(0, frameLevel + entry.frameLevel),
            count = counts[position], index = indices[position],
        }
    end
    return layouts
end

function Addon:LayoutBuffIndicator(region, frame, layout)
    local vertical = self:IsBuffIndicatorVertical(layout.position)
    local offset, length = self:GetBuffIndicatorSegment(vertical and layout.height or layout.width, layout.count, layout.index)
    region:ClearAllPoints()
    if vertical then
        local right = layout.position == "RIGHT"
        local point = right and "TOPRIGHT" or "TOPLEFT"
        region:SetPoint(point, frame, point, right and -2 or 2, -offset)
        region:SetSize(layout.thickness, length)
    else
        local bottom = layout.position == "BOTTOM"
        local point = bottom and "BOTTOMLEFT" or "TOPLEFT"
        region:SetPoint(point, frame, point, offset, bottom and 2 or -2)
        region:SetSize(length, layout.thickness)
    end
end

local states = {}
local hooked = false
local refreshQueued = false

local function SetPending(state, pending)
    if state.pending == pending then return end
    state.pending = pending
    if not refreshQueued and Addon.RefreshConfig and Addon:IsConfigOpen() then
        refreshQueued = true
        C_Timer.After(0, function()
            refreshQueued = false
            Addon:RefreshConfig()
        end)
    end
end

local function EntriesEqual(a, b)
    if a == b then return true end
    if not a or #a ~= #b then return false end
    for index, entry in ipairs(a) do
        local other = b[index]
        if entry.spellID ~= other.spellID or entry.enabled ~= other.enabled
            or entry.mineOnly ~= other.mineOnly or entry.r ~= other.r
            or entry.g ~= other.g or entry.b ~= other.b
            or entry.thickness ~= other.thickness or entry.direction ~= other.direction
            or entry.position ~= other.position or entry.frameLevel ~= other.frameLevel then return false end
    end
    return true
end

local function LayoutSlot(slot, frame, layout)
    Addon:LayoutBuffIndicator(slot.button, frame, layout)
    slot.button:SetFrameLevel(layout.frameLevel + 1)
end

local function BindDurationBar(slot, direction)
    -- RemainingTime reduces the fill from full to empty along either axis;
    -- reversing the texture instead would grow it from the opposite end.
    slot.button:SetDurationBar(slot.bar, {
        direction = direction == "REMAINING" and Enum.StatusBarTimerDirection.RemainingTime
            or Enum.StatusBarTimerDirection.ElapsedTime,
        interpolation = Enum.StatusBarInterpolation.Immediate,
    })
    slot.direction = direction
end

local function CreateSlot(state, frame, layout, index, entry)
    local slot = {}
    -- initializeFrame is Blizzard's configuration window before the button
    -- becomes inaccessible. This also works for frames created during combat.
    state.container:AddAuraSlot(tostring(index), "HELPFUL", {
        candidateFilters = { includeSpellIDs = {} },
        initializeFrame = function(button)
            slot.button = button
            button:EnableMouse(false)
            LayoutSlot(slot, frame, layout)
            slot.bar = Addon:CreateBuffIndicatorBar(button)
            Addon:SetBuffIndicatorBarOrientation(slot.bar, layout.position)
            slot.bar:SetFrameLevel(layout.frameLevel + 2)
            Addon:SetBuffIndicatorBarColor(slot.bar, entry)
            -- Blizzard owns the timer and fill value; addon code never reads
            -- aura durations or updates this bar in an OnUpdate handler.
            BindDurationBar(slot, layout.direction)
        end,
    })
    state.slots[index] = slot
end

local function HasEnabledEntry(entries)
    for _, entry in ipairs(entries) do
        if entry.enabled then return true end
    end
    return false
end

local function BindUnit(state, unit)
    if state.unit ~= unit then
        state.container:SetUnit(unit)
        state.unit = unit
    end
end

function Addon:UpdateBuffIndicators(frame, settings)
    if not frame then return end
    local state = states[frame]
    local unit, assignedUnit = frame.displayedUnit, frame.unit
    local secretUnit = issecretvalue and (issecretvalue(unit) or issecretvalue(assignedUnit))
    -- Test secrecy before using either token in a truth test or fallback.
    if not secretUnit then unit = unit or assignedUnit end
    if secretUnit or not unit or not self:IsRaidOrPartyFrame(frame) then
        if state then
            BindUnit(state, "none")
            state.container:SetEnabled(false)
            state.container:Hide()
            SetPending(state, false)
        end
        return
    end

    settings = settings or self:GetSettings()
    if not settings then return end
    local entries = settings.buffIndicators
    if not HasEnabledEntry(entries) then
        if state then
            BindUnit(state, unit)
            state.container:SetEnabled(false)
            state.container:Hide()
            SetPending(state, false)
        end
        return
    end

    if not state then
        local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
        container:SetPoint("TOPLEFT", frame, "TOPLEFT")
        container:SetSize(1, 1)
        container:EnableMouse(false)
        state = { container = container, slots = {}, pending = false }
        states[frame] = state
        frame:HookScript("OnSizeChanged", function() Addon:UpdateBuffIndicators(frame) end)
        frame:HookScript("OnShow", function() Addon:UpdateBuffIndicators(frame) end)
    end

    -- Retarget through the public container API even while buttons are forbidden.
    -- A recycled raid frame must never keep tracking its previous unit.
    BindUnit(state, unit)
    local width = frame:GetWidth()
    local height = frame:GetHeight()
    local frameLevel = frame:GetFrameLevel()
    if not EntriesEqual(state.entries, entries) or state.width ~= width or state.height ~= height
        or state.frameLevel ~= frameLevel then
        for _, slot in ipairs(state.slots) do
            if slot.button:IsForbidden() then
                -- Do not display the previous profile's colours under new settings.
                state.container:SetEnabled(false)
                state.container:Hide()
                SetPending(state, true)
                return
            end
        end

        local layouts = self:GetBuffIndicatorLayouts(entries, width, height, frameLevel)
        local containerLevel = math.huge
        for _, layout in ipairs(layouts) do
            containerLevel = math.min(containerLevel, layout.frameLevel)
        end
        -- Keep the shared parent below every buff, then set each child's own level.
        state.container:SetFrameLevel(containerLevel)
        for index, entry in ipairs(entries) do
            local slot = state.slots[index]
            local layout = layouts[index]
            if slot then
                LayoutSlot(slot, frame, layout)
                self:SetBuffIndicatorBarOrientation(slot.bar, layout.position)
                slot.bar:SetFrameLevel(layout.frameLevel + 2)
                self:SetBuffIndicatorBarColor(slot.bar, entry)
                if slot.direction ~= layout.direction then
                    BindDurationBar(slot, layout.direction)
                end
            else
                CreateSlot(state, frame, layout, index, entry)
            end
            local filters = { includeSpellIDs = {} }
            if entry.enabled then filters.includeSpellIDs[entry.spellID] = true end
            if entry.mineOnly then filters.isFromPlayerOrPlayerPet = true end
            state.container:SetAuraSlotCandidateFilters(tostring(index), filters)
        end
        -- Slots are retained and reused: the API does not expose slot removal.
        for index = #entries + 1, #state.slots do
            state.container:SetAuraSlotCandidateFilters(tostring(index), { includeSpellIDs = {} })
        end
        state.width, state.height, state.frameLevel = width, height, frameLevel
    end
    state.entries = entries
    SetPending(state, false)
    state.container:SetEnabled(true)
    state.container:Show()
end

function Addon:HasPendingBuffIndicators()
    for frame, state in pairs(states) do
        if state.pending and frame:IsVisible() then return true end
    end
    return false
end

function Addon:HookBuffIndicators()
    if hooked then return end
    hooked = true
    local function Update(frame)
        Addon:UpdateBuffIndicators(frame)
    end
    hooksecurefunc("CompactUnitFrame_SetUnit", Update)
    hooksecurefunc("CompactUnitFrame_UpdateInVehicle", Update)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    events:SetScript("OnEvent", function()
        -- Defer until after the restriction event's temporary access window.
        Addon:RequestFeatureUpdate("buffIndicators")
    end)
end
