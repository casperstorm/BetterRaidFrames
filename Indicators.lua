local _, Addon = ...

-- Dynamic aura groups preallocate several buttons per indicator. Keep both
-- imported sets and interactive creation within a predictable resource budget.
Addon.MAX_DESIGNER_INDICATORS = 32
Addon.IndicatorAnchors = {
    { value = "TOPLEFT", label = "Top left" }, { value = "TOP", label = "Top" },
    { value = "TOPRIGHT", label = "Top right" }, { value = "LEFT", label = "Left" },
    { value = "CENTER", label = "Centre" }, { value = "RIGHT", label = "Right" },
    { value = "BOTTOMLEFT", label = "Bottom left" }, { value = "BOTTOM", label = "Bottom" },
    { value = "BOTTOMRIGHT", label = "Bottom right" },
}

Addon.IndicatorSpecializations = {
    { value = "1468", label = "Preservation Evoker", spells = { 364343, 366155, 367364, 355941, 376788, 357170, 363502, 373267 } },
    { value = "1473", label = "Augmentation Evoker", spells = { 410089, 413984, 360827, 410263, 410686, 395152 } },
    { value = "105", label = "Restoration Druid", spells = { 774, 8936, 33763, 155777, 48438, 102342 } },
    { value = "256", label = "Discipline Priest", spells = { 17, 194384, 33206, 1253593, 41635, 10060 } },
    { value = "257", label = "Holy Priest", spells = { 139, 77489, 47788, 41635, 10060 } },
    { value = "270", label = "Mistweaver Monk", spells = { 119611, 124682, 115175, 116849, 450769 } },
    { value = "264", label = "Restoration Shaman", spells = { 61295, 974, 383648, 382024 } },
    { value = "65", label = "Holy Paladin", spells = { 53563, 156910, 156322, 1244893, 1022, 6940 } },
}

local directions = {
    { value = "LEFT", label = "Left" }, { value = "RIGHT", label = "Right" },
    { value = "UP", label = "Up" }, { value = "DOWN", label = "Down" },
}
local anchorNames = {}
for _, anchor in ipairs(Addon.IndicatorAnchors) do anchorNames[anchor.value] = anchor.label end

local function Integer(value)
    return type(value) == "number" and value >= 1 and value <= 2147483647 and value == math.floor(value)
end

local function AvailableId(seen, preferred)
    local id = Integer(preferred) and preferred or 1
    while seen[id] do id = id == 2147483647 and 1 or id + 1 end
    return id
end

local function Number(value, low, high, fallback, step)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
    return math.max(low, math.min(high, math.floor(value / step + 0.5) * step))
end

local function Color(value, fallback)
    value = type(value) == "table" and value or {}
    local result = {}
    for i, key in ipairs({ "r", "g", "b", "a" }) do
        result[key] = Number(value[key], 0, 1, fallback[i], 0.001)
    end
    return result
end

function Addon:GetIndicatorAnchorName(anchor)
    return anchorNames[anchor] or "Bottom right"
end

function Addon:GetIndicatorGrowthOptions(anchor)
    local result = {}
    for _, direction in ipairs(directions) do
        if not anchor:find(direction.value, 1, true)
            and not (direction.value == "UP" and anchor:find("TOP", 1, true))
            and not (direction.value == "DOWN" and anchor:find("BOTTOM", 1, true)) then
            result[#result + 1] = direction
        end
    end
    return result
end

function Addon:NormalizeIndicatorGroup(value, anchor)
    value = type(value) == "table" and value or {}
    local grow = anchor:find("RIGHT", 1, true) and "LEFT" or "RIGHT"
    if anchor == "LEFT" then grow = "DOWN" elseif anchor == "RIGHT" then grow = "DOWN" end
    for _, option in ipairs(self:GetIndicatorGrowthOptions(anchor)) do
        if value.grow == option.value then grow = value.grow end
    end
    return {
        grow = grow,
        spacing = Number(value.spacing, 0, 20, 3, 1),
        offsetX = Number(value.offsetX, -250, 250, 0, 1),
        offsetY = Number(value.offsetY, -250, 250, 0, 1),
        offsetZ = Number(value.offsetZ, -100, 500, 0, 1),
    }
end

function Addon:NormalizeIndicatorSet(value)
    value = type(value) == "table" and value or {}
    local result = { nextId = 1, groups = {}, items = {} }
    local groups = type(value.groups) == "table" and value.groups or {}
    for _, anchor in ipairs(self.IndicatorAnchors) do
        result.groups[anchor.value] = self:NormalizeIndicatorGroup(groups[anchor.value], anchor.value)
    end
    local seen = {}
    for _, item in ipairs(type(value.items) == "table" and value.items or {}) do
        if type(item) == "table" and Integer(item.spellID) then
            local id = AvailableId(seen, Integer(item.id) and item.id or result.nextId)
            seen[id] = true
            result.nextId = math.max(result.nextId, id + 1)
            result.items[#result.items + 1] = {
                id = id, spellID = item.spellID, enabled = item.enabled ~= false,
                type = item.type == "ICON" and "ICON" or "SQUARE",
                anchor = anchorNames[item.anchor] and item.anchor or "BOTTOMRIGHT",
                size = Number(item.size, 10, 50, 20, 1),
                mineOnly = item.mineOnly ~= false, showTexture = item.showTexture ~= false,
                tooltip = item.tooltip == true,
                cooldown = item.cooldown == true,
                glow = item.glow == true,
                glowPulse = item.glowPulse == true,
                color = Color(item.color, { 0.4, 0.8, 0.65, 1 }),
                text = (item.text == "DURATION" or item.text == "STACKS") and item.text or "NONE",
                textScale = Number(item.textScale, 0.5, 3, 1, 0.1),
                textColor = Color(item.textColor, { 1, 1, 1, 1 }),
            }
            if #result.items == self.MAX_DESIGNER_INDICATORS then break end
        end
    end
    if Integer(value.nextId) then result.nextId = math.max(result.nextId, value.nextId) end
    result.nextId = AvailableId(seen, result.nextId)
    return result
end

function Addon:NormalizeIndicators(value)
    value = type(value) == "table" and value or {}
    local sets = type(value.sets) == "table" and value.sets or {}
    local result = { version = 1, sets = { default = self:NormalizeIndicatorSet(sets.default) } }
    for key, set in pairs(sets) do
        if type(key) == "string" and key:match("^%d+$") and Integer(tonumber(key)) and type(set) == "table" then
            result.sets[key] = self:NormalizeIndicatorSet(set)
        end
    end
    return result
end

function Addon:GetIndicatorSpecKey()
    local index = C_SpecializationInfo.GetSpecialization()
    local id = index and C_SpecializationInfo.GetSpecializationInfo(index)
    return id and tostring(id) or "default"
end

function Addon:GetIndicatorSet(key, settings)
    local data = (settings or self:GetSettings()).indicators
    return data.sets[key or self:GetIndicatorSpecKey()] or data.sets.default
end

local function CopyIndicatorSets(data)
    local copy = { version = 1, sets = {} }
    -- Sets are normalized on load and replaced on edit. Share untouched sets
    -- instead of copying every specialization for each slider movement.
    for key, set in pairs(data.sets) do copy.sets[key] = set end
    return copy
end

function Addon:SaveIndicatorSet(key, set)
    local data = CopyIndicatorSets(self:GetSetting("indicators"))
    data.sets[key] = self:NormalizeIndicatorSet(set)
    self:SetSetting("indicators", data)
end

function Addon:UseDefaultIndicators(key)
    if key == "default" then return end
    local data = CopyIndicatorSets(self:GetSetting("indicators"))
    data.sets[key] = nil
    self:SetSetting("indicators", data)
end

function Addon:FindDesignerIndicator(key, id)
    for index, item in ipairs(self:GetIndicatorSet(key).items) do
        if item.id == id then return item, index end
    end
end

function Addon:ResolveIndicatorSpell(input)
    input = tostring(input or ""):match("^%s*(.-)%s*$")
    local info = input ~= "" and C_Spell.GetSpellInfo(tonumber(input) or input)
    if info and Integer(info.spellID) then return info end
end

function Addon:AddDesignerIndicator(key, input, displayType, anchor)
    local spell = self:ResolveIndicatorSpell(input)
    if not spell then return nil, "Buff not found. Try the buff's spell ID." end
    local set = self:NormalizeIndicatorSet(self:GetIndicatorSet(key))
    if #set.items >= self.MAX_DESIGNER_INDICATORS then return nil, "Up to 32 indicators per set." end
    local id = set.nextId
    set.items[#set.items + 1] = { id = id, spellID = spell.spellID, type = displayType,
        anchor = anchor, cooldown = displayType == "ICON" }
    self:SaveIndicatorSet(key, set)
    return id
end

function Addon:ChangeDesignerIndicator(key, id, changes)
    local set = self:NormalizeIndicatorSet(self:GetIndicatorSet(key))
    for index, item in ipairs(set.items) do
        if item.id == id then
            local moved = changes.anchor and changes.anchor ~= item.anchor
            for field, value in pairs(changes) do if field ~= "id" then item[field] = value end end
            if moved then table.remove(set.items, index); set.items[#set.items + 1] = item end
            self:SaveIndicatorSet(key, set)
            return
        end
    end
end

function Addon:RemoveDesignerIndicator(key, id)
    local set = self:NormalizeIndicatorSet(self:GetIndicatorSet(key))
    for index, item in ipairs(set.items) do
        if item.id == id then table.remove(set.items, index); self:SaveIndicatorSet(key, set); return end
    end
end

function Addon:MoveDesignerIndicator(key, id, step)
    if step ~= -1 and step ~= 1 then return end
    local set = self:NormalizeIndicatorSet(self:GetIndicatorSet(key))
    for index, item in ipairs(set.items) do
        if item.id == id then
            for other = index + step, step == 1 and #set.items or 1, step do
                if set.items[other].anchor == item.anchor then
                    set.items[index], set.items[other] = set.items[other], item
                    self:SaveIndicatorSet(key, set)
                    return
                end
            end
            return
        end
    end
end

function Addon:DuplicateDesignerIndicator(key, id)
    local set = self:NormalizeIndicatorSet(self:GetIndicatorSet(key))
    if #set.items >= self.MAX_DESIGNER_INDICATORS then return nil, "Up to 32 indicators per set." end
    for index, item in ipairs(set.items) do
        if item.id == id then
            local copy = self:NormalizeIndicatorSet({ items = { item } }).items[1]
            copy.id = set.nextId
            table.insert(set.items, index + 1, copy)
            self:SaveIndicatorSet(key, set)
            return copy.id
        end
    end
end

function Addon:ChangeDesignerGroup(key, anchor, changes)
    local set = self:NormalizeIndicatorSet(self:GetIndicatorSet(key))
    for field, value in pairs(changes) do set.groups[anchor][field] = value end
    self:SaveIndicatorSet(key, set)
end

function Addon:ExportDesignerIndicators(key)
    local payload = { version = 1, set = self:NormalizeIndicatorSet(self:GetIndicatorSet(key)) }
    local json = C_EncodingUtil.SerializeJSON(payload)
    return "BRFI1:" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(json, Enum.CompressionMethod.Gzip))
end

function Addon:DecodeDesignerIndicators(input)
    if type(input) ~= "string" then return nil, "Enter a BetterRaidFrames indicator export." end
    input = input:match("^%s*(.-)%s*$")
    if #input > 65536 or input:sub(1, 6) ~= "BRFI1:" then return nil, "Invalid indicator export or unsupported version." end
    local ok, payload = pcall(function()
        local compressed = C_EncodingUtil.DecodeBase64(input:sub(7))
        local json = C_EncodingUtil.DecompressString(compressed, Enum.CompressionMethod.Gzip)
        assert(type(json) == "string" and #json <= 262144)
        return C_EncodingUtil.DeserializeJSON(json)
    end)
    if not ok or type(payload) ~= "table" or payload.version ~= 1 or type(payload.set) ~= "table"
        or type(payload.set.items) ~= "table" or type(payload.set.groups) ~= "table" then
        return nil, "Invalid indicator export. Nothing was changed."
    end
    local count, seen = 0, {}
    for index, item in pairs(payload.set.items) do
        count = count + 1
        if not Integer(index) or index > self.MAX_DESIGNER_INDICATORS or type(item) ~= "table"
            or not Integer(item.spellID) or not Integer(item.id) or seen[item.id]
            or (item.type ~= "ICON" and item.type ~= "SQUARE") or not anchorNames[item.anchor] then
            return nil, "Invalid indicators in export. Nothing was changed."
        end
        seen[item.id] = true
    end
    if count ~= #payload.set.items then return nil, "Invalid indicator list." end
    return self:NormalizeIndicatorSet(payload.set)
end
