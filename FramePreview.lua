local _, Addon = ...

local sizes = {}
local activePreview, queued, hooked
local events = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function PositiveNumber(value)
    return not Secret(value) and type(value) == "number" and value > 0 and value < math.huge
end

local function Accessible(frame)
    if not frame then return false end
    local allowed = frame:CanBeAccessedInContext()
    return not Secret(allowed) and allowed
end

local function EffectiveScale(frame)
    if Accessible(frame) then
        local scale = frame:GetEffectiveScale()
        if PositiveNumber(scale) then return scale end
    end
end

local function ResolveSize()
    local kind = IsInRaid() and "Raid" or "Party"
    local width, height, scale
    Addon:ForEachFrame(function(frame)
        if width or not Accessible(frame) then return end
        local visible = frame:IsVisible()
        if Secret(visible) or not visible then return end
        local w, h = frame:GetSize()
        local s = EffectiveScale(frame)
        if PositiveNumber(w) and PositiveNumber(h) and s then width, height, scale = w, h, s end
    end)
    local source = "Actual size"
    if not width and not InCombatLockdown() and Accessible(EditModeManagerFrame) then
        -- These are the same dimensions used by CompactUnitFrameUtil.ApplyConfig.
        -- Party and raid layouts have independent settings, including while solo.
        local indices = Enum.EditModeUnitFrameSystemIndices
        if indices and EditModeManagerFrame:IsInitialized() then
            local native = CompactUnitFrameUtil
            local w = EditModeManagerFrame:GetRaidFrameWidth(indices[kind], native and native.NativeFrameWidth or 72)
            local h = EditModeManagerFrame:GetRaidFrameHeight(indices[kind], native and native.NativeFrameHeight or 36)
            if PositiveNumber(w) and PositiveNumber(h) then
                width, height = w, h
                scale = EffectiveScale(kind == "Raid" and CompactRaidFrameContainer or CompactPartyFrame)
                    or EffectiveScale(UIParent) or 1
                source = "Edit Mode size"
            end
        end
    end
    if width then
        local cached = sizes[kind] or {}
        cached.width, cached.height, cached.scale = width, height, scale
        sizes[kind] = cached
        return width, height, scale, kind, source
    end
    local cached = sizes[kind]
    if cached then return cached.width, cached.height, cached.scale, kind, "Last known size" end
    return 72, 36, EffectiveScale(UIParent) or 1, kind, "Default size"
end

local function QueueRefresh()
    if queued or not activePreview or not activePreview:IsVisible() then return end
    queued = true
    -- Native layout can finish later in the same event. Coalesce its callbacks
    -- and never sample frame geometry from the preview's animation timer.
    C_Timer.After(0, function()
        queued = false
        local preview = activePreview
        if preview and preview:IsVisible() then preview:RefreshOptions() end
    end)
end

function Addon:WatchFramePreviewSize(preview)
    if activePreview == preview then return end
    if activePreview then self:UnwatchFramePreviewSize(activePreview) end
    activePreview = preview
    for _, event in ipairs(events) do preview:RegisterEvent(event) end
    preview:SetScript("OnEvent", QueueRefresh)
    if not hooked and CompactUnitFrameUtil and CompactUnitFrameUtil.ApplyConfig then
        hooksecurefunc(CompactUnitFrameUtil, "ApplyConfig", QueueRefresh)
        hooked = true
    end
end

function Addon:UnwatchFramePreviewSize(preview)
    for _, event in ipairs(events) do preview:UnregisterEvent(event) end
    if activePreview == preview then activePreview = nil end
end

function Addon:GetFramePreviewSize(parent, maxWidth, maxHeight)
    local width, height, scale, kind, source = ResolveSize()
    -- Scaling the whole preview preserves the live relationship between frame
    -- dimensions, indicator sizes, group spacing and offsets.
    local parentScale = parent:GetEffectiveScale()
    local relativeScale = scale / parentScale
    local fit = 1
    if maxWidth and maxHeight then
        fit = math.min(1, maxWidth / (width * relativeScale), maxHeight / (height * relativeScale))
    end
    local displayScale = relativeScale * fit
    local label = kind .. " · " .. source
    if fit < 1 then label = kind .. " · Fit " .. math.floor(fit * 100 + 0.5) .. "%" end
    return width, height, displayScale, label
end

function Addon:SizeFramePreview(preview)
    local maxWidth, maxHeight
    if preview.GetAvailableSize then maxWidth, maxHeight = preview:GetAvailableSize() end
    local width, height, displayScale, label = self:GetFramePreviewSize(preview:GetParent(), maxWidth, maxHeight)
    preview:SetSize(width, height)
    preview:SetScale(displayScale)
    self:UpdateNamePreview(preview)
    if preview.OnSizeResolved then
        preview:OnSizeResolved(width * displayScale, height * displayScale, label)
    end
end

-- Keep captions and column spacing in settings coordinates. Only the sample
-- frames scale, so every visual inside them retains its live proportions.
function Addon:CreateFramePreviewRow(parent, count, maxHeight, captions)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(80)
    row.samples = {}
    local source = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    source:SetPoint("TOPLEFT", 0, 0)
    source:SetTextColor(0.75, 0.75, 0.75)
    local cells, labels = {}, {}
    for index = 1, count do
        local cell = CreateFrame("Frame", nil, row)
        local sample = CreateFrame("Frame", nil, cell)
        sample:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 0)
        sample:SetSize(72, 36)
        cells[index], row.samples[index] = cell, sample
        if captions then
            local label = cell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetJustifyH("LEFT")
            label:SetText(captions[index])
            labels[index] = label
        end
    end
    function row:RefreshSize()
        if not self:IsVisible() then return end
        Addon:WatchFramePreviewSize(self)
        local columnWidth = math.max(1, (parent:GetWidth() - 48 - (count - 1) * 24) / count)
        local width, height, scale, label = Addon:GetFramePreviewSize(self, columnWidth, maxHeight)
        local displayHeight = height * scale
        source:SetText(label)
        self:SetHeight(20 + displayHeight + (captions and 24 or 0))
        local settings = Addon:GetSettings()
        for index, sample in ipairs(self.samples) do
            local cell = cells[index]
            cell:SetPoint("TOPLEFT", (index - 1) * (columnWidth + 24), -20)
            cell:SetSize(columnWidth, displayHeight)
            sample:SetSize(width, height)
            sample:SetScale(scale)
            Addon:UpdateNamePreview(sample, settings)
            if labels[index] then
                labels[index]:SetPoint("TOPLEFT", 0, -displayHeight - 8)
                labels[index]:SetWidth(columnWidth)
            end
        end
    end
    row.RefreshOptions = row.RefreshSize
    row:SetScript("OnHide", function() Addon:UnwatchFramePreviewSize(row) end)
    return row
end
