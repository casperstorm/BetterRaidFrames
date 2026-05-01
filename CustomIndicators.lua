local ADDON_NAME, Addon = ...

local SPELL_CATALOG = {
    { id = 355941, name = "Dream Breath" },
    { id = 363502, name = "Dream Flight" },
    { id = 364343, name = "Echo" },
    { id = 366155, name = "Reversion" },
    { id = 367364, name = "Echo Reversion" },
    { id = 373267, name = "Lifebind" },
    { id = 376788, name = "Echo Dream Breath" },
    { id = 360827, name = "Blistering Scales" },
    { id = 395152, name = "Ebon Might" },
    { id = 410089, name = "Prescience" },
    { id = 410263, name = "Inferno's Blessing" },
    { id = 410686, name = "Symbiotic Bloom" },
    { id = 413984, name = "Shifting Sands" },
    { id = 774, name = "Rejuvenation" },
    { id = 8936, name = "Regrowth" },
    { id = 33763, name = "Lifebloom" },
    { id = 48438, name = "Wild Growth" },
    { id = 155777, name = "Germination" },
    { id = 17, name = "Power Word: Shield" },
    { id = 194384, name = "Atonement" },
    { id = 1253593, name = "Void Shield" },
    { id = 139, name = "Renew" },
    { id = 41635, name = "Prayer of Mending" },
    { id = 77489, name = "Echo of Light" },
    { id = 115175, name = "Soothing Mist" },
    { id = 119611, name = "Renewing Mist" },
    { id = 124682, name = "Enveloping Mist" },
    { id = 450769, name = "Aspect of Harmony" },
    { id = 974, name = "Earth Shield" },
    { id = 383648, name = "Earth Shield" },
    { id = 61295, name = "Riptide" },
    { id = 53563, name = "Beacon of Light" },
    { id = 156322, name = "Eternal Flame" },
    { id = 156910, name = "Beacon of Faith" },
    { id = 1244893, name = "Beacon of the Savior" },
}

local VALID_TYPES = {
    ["bar"] = true,
    ["border"] = true,
    ["icon"] = true,
    ["spell-icon"] = true,
    ["square"] = true,
}

local BAR_TEXTURES = {
    BLIZZARD = {
        label = "Blizzard",
        path = "Interface\\TargetingFrame\\UI-StatusBar",
    },
    FLAT = {
        label = "Flat",
        path = "Interface\\Buttons\\WHITE8X8",
    },
    SHIELD = {
        label = "Shield",
        path = "Interface\\AddOns\\BetterRaidFrames\\Media\\shield",
    },
}

local BAR_TEXTURE_ORDER = { "BLIZZARD", "FLAT", "SHIELD" }

local BAR_BORDERS = {
    NONE = {
        label = "None",
        path = nil,
        edgeSize = 1,
    },
    SOLID = {
        label = "Solid",
        path = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    },
    TOOLTIP = {
        label = "Blizzard Tooltip",
        path = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    },
}

local BAR_BORDER_ORDER = { "NONE", "SOLID", "TOOLTIP" }

local VALID_DIRECTIONS = {
    LEFT_TO_RIGHT = true,
    RIGHT_TO_LEFT = true,
    TOP_TO_BOTTOM = true,
    BOTTOM_TO_TOP = true,
}

local VALID_ANCHORS = {
    CENTER = true,
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local DIRECTION_CONFIGS = {
    LEFT_TO_RIGHT = { orientation = "HORIZONTAL", reverseFill = false },
    RIGHT_TO_LEFT = { orientation = "HORIZONTAL", reverseFill = true },
    TOP_TO_BOTTOM = { orientation = "VERTICAL", reverseFill = true },
    BOTTOM_TO_TOP = { orientation = "VERTICAL", reverseFill = false },
}

local TICKER_INTERVAL = 0.10
local PREVIEW_PERIOD = 3.0
local DURATION_TEXT_INTERVAL = 0.25
local FULL_REFRESH_MIN_INTERVAL = 0.05
local runtime = {
    ticker = nil,
    previewId = nil,
    previewAll = false,
    rawConfig = nil,
    normalizedConfig = nil,
    activeTimedVisuals = {},
}

local function Clamp(v, minV, maxV)
    if type(v) ~= "number" then return minV end
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function ClampFrameLevel(level)
    local value = Round(level)
    if value < 0 then return 0 end
    if value > 65535 then return 65535 end
    return value
end

local function GetLSM()
    if not LibStub then return nil end
    return LibStub("LibSharedMedia-3.0", true)
end

local function BuildTextureOptionLabel(path, label)
    if not path or path == "" then
        return label
    end
    return "|T" .. tostring(path) .. ":16:10:0:0|t " .. label
end

local function BuildSpellOptionLabel(icon, label)
    if not icon or icon == 0 then
        return label
    end
    return "|T" .. tostring(icon) .. ":14:14:0:0|t " .. label
end

local function ResolveSpellInfo(spellId)
    local name
    local icon

    if C_Spell and C_Spell.RequestLoadSpellData then
        C_Spell.RequestLoadSpellData(spellId)
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellId)
        if type(info) == "table" then
            name = info.name or info.spellName
            icon = info.iconID or info.originalIconID
        end
    end

    if GetSpellInfo then
        local legacyName, _, legacyIcon = GetSpellInfo(spellId)
        if not name then
            name = legacyName
        end
        if not icon then
            icon = legacyIcon
        end
    end

    if not icon and C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(spellId)
    end

    if not icon and GetSpellTexture then
        icon = GetSpellTexture(spellId)
    end

    return name, icon
end

local function ParseMediaKey(key)
    if type(key) ~= "string" then return nil, nil end
    local prefix, value = key:match("^([A-Z_]+):(.*)$")
    return prefix, value
end

local function Round(v)
    if type(v) ~= "number" then return 0 end
    return math.floor(v + 0.5)
end

function Addon:GetDefaultCustomIndicators()
    return {
        enabled = true,
        previewEnabled = true,
        defaultZOffset = 0,
        nextId = 1,
        items = {},
    }
end

local function BuildDefaultItem(id, indicatorType)
    local normalizedType = indicatorType == "spell-icon" and "icon" or indicatorType
    local isBar = normalizedType == "bar"
    local isIcon = normalizedType == "icon"

    return {
        id = id,
        enabled = true,
        type = normalizedType,
        spellId = 0,
        anchor = isBar and "BOTTOM" or "CENTER",
        offsetX = 0,
        offsetY = 0,
        width = isBar and 60 or 18,
        height = isBar and 6 or 18,
        size = isBar and 18 or 18,
        scale = 1,
        alpha = 1,
        frameLevelOffset = 0,
        frameStrata = "INHERIT",
        orientation = "HORIZONTAL",
        direction = "RIGHT_TO_LEFT",
        barTexture = "BLIZZARD",
        barBackgroundColorR = 0,
        barBackgroundColorG = 0,
        barBackgroundColorB = 0,
        barBackgroundColorA = 0.5,
        barBorder = "NONE",
        showBorder = normalizedType ~= "icon",
        borderSize = isBar and 1 or 1,
        borderPadding = 0,
        borderInset = 0,
        borderColorR = 1,
        borderColorG = 1,
        borderColorB = 1,
        borderColorA = 1,
        showCooldownSwipe = isIcon,
        hideSwipe = false,
        invertCooldownSwipe = false,
        showCooldownText = false,
        showDuration = true,
        durationAnchor = "CENTER",
        durationX = 0,
        durationY = 0,
        durationColorByTime = true,
        durationColorR = 1,
        durationColorG = 1,
        durationColorB = 1,
        durationColorA = 1,
        showStacks = normalizedType ~= "bar",
        stackMinimum = 2,
        stackAnchor = "BOTTOMRIGHT",
        stackX = 0,
        stackY = 0,
        stackColorR = 1,
        stackColorG = 1,
        stackColorB = 1,
        stackColorA = 1,
        expiringEnabled = false,
        expiringThreshold = isBar and 5 or 30,
        expiringThresholdMode = isBar and "SECONDS" or "PERCENT",
        expiringColorR = 1,
        expiringColorG = 0.2,
        expiringColorB = 0.2,
        expiringColorA = 1,
        colorR = 0.2,
        colorG = 0.8,
        colorB = 0.2,
        colorA = 1,
    }
end

local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do
        out[k] = DeepCopy(v)
    end
    return out
end

function Addon:NormalizeCustomIndicatorsConfig(cfg)
    local defaults = self:GetDefaultCustomIndicators()
    if type(cfg) ~= "table" then
        return DeepCopy(defaults)
    end

    local out = {
        enabled = cfg.enabled ~= false,
        previewEnabled = cfg.previewEnabled ~= false,
        nextId = math.max(1, Round(cfg.nextId ~= nil and cfg.nextId or defaults.nextId)),
        items = {},
    }

    if type(cfg.items) ~= "table" then
        return out
    end

    local seen = {}
    for _, item in ipairs(cfg.items) do
        if type(item) == "table" then
            local indicatorType = VALID_TYPES[item.type] and item.type or "bar"
            local id = item.id
            if type(id) ~= "string" or id == "" or seen[id] then
                id = "ci_" .. tostring(out.nextId)
                out.nextId = out.nextId + 1
            end
            seen[id] = true

            local normalized = BuildDefaultItem(id, indicatorType)
            normalized.enabled = item.enabled ~= false
            normalized.spellId = Round(item.spellId or 0)
            if normalized.spellId < 0 then normalized.spellId = 0 end
            normalized.anchor = VALID_ANCHORS[item.anchor] and item.anchor or normalized.anchor
            normalized.offsetX = Clamp(Round((item.offsetX ~= nil and item.offsetX) or item.x or normalized.offsetX), -250, 250)
            normalized.offsetY = Clamp(Round((item.offsetY ~= nil and item.offsetY) or item.y or normalized.offsetY), -250, 250)
            normalized.width = Clamp(Round(item.width or normalized.width), 4, 250)
            normalized.height = Clamp(Round(item.height or normalized.height), 2, 250)
            normalized.size = Clamp(Round(item.size or normalized.size), 4, 250)
            normalized.scale = Clamp(tonumber(item.scale) or normalized.scale, 0.2, 4)
            normalized.alpha = Clamp(tonumber(item.alpha) or item.colorA or normalized.alpha, 0, 1)
            normalized.frameLevelOffset = Clamp(Round((item.frameLevelOffset ~= nil and item.frameLevelOffset) or item.zOffset or normalized.frameLevelOffset), -30, 60)
            normalized.frameStrata = type(item.frameStrata) == "string" and item.frameStrata or normalized.frameStrata
            normalized.orientation = item.orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
            normalized.direction = VALID_DIRECTIONS[item.direction] and item.direction or normalized.direction
            normalized.barTexture = item.barTexture
            if not self:GetCustomIndicatorBarTexturePath(normalized.barTexture) then
                normalized.barTexture = normalized.barTexture
            end
            if not self:GetCustomIndicatorBarTexturePath(normalized.barTexture) then
                normalized.barTexture = "BLIZZARD"
            end
            normalized.barBorder = item.barBorder
            local borderSpec = self:GetCustomIndicatorBarBorderSpec(normalized.barBorder)
            if not borderSpec then
                normalized.barBorder = "NONE"
            end
            normalized.showBorder = item.showBorder ~= false
            normalized.borderSize = Clamp(Round(item.borderSize or normalized.borderSize), 1, 24)
            normalized.borderPadding = Clamp(Round(item.borderPadding or normalized.borderPadding), -20, 20)
            normalized.borderInset = Clamp(Round(item.borderInset or normalized.borderInset), -20, 20)
            normalized.borderColorR = Clamp(item.borderColorR or normalized.borderColorR, 0, 1)
            normalized.borderColorG = Clamp(item.borderColorG or normalized.borderColorG, 0, 1)
            normalized.borderColorB = Clamp(item.borderColorB or normalized.borderColorB, 0, 1)
            normalized.borderColorA = Clamp(item.borderColorA or normalized.borderColorA, 0, 1)
            normalized.barBackgroundColorR = Clamp(item.barBackgroundColorR or normalized.barBackgroundColorR, 0, 1)
            normalized.barBackgroundColorG = Clamp(item.barBackgroundColorG or normalized.barBackgroundColorG, 0, 1)
            normalized.barBackgroundColorB = Clamp(item.barBackgroundColorB or normalized.barBackgroundColorB, 0, 1)
            normalized.barBackgroundColorA = Clamp(item.barBackgroundColorA or normalized.barBackgroundColorA, 0, 1)
            normalized.showCooldownSwipe = item.hideSwipe == true and false or item.showCooldownSwipe ~= false
            normalized.hideSwipe = normalized.showCooldownSwipe == false
            normalized.invertCooldownSwipe = item.invertCooldownSwipe == true
            normalized.showCooldownText = item.showCooldownText == true
            normalized.showDuration = item.showDuration ~= false
            normalized.durationAnchor = VALID_ANCHORS[item.durationAnchor] and item.durationAnchor or normalized.durationAnchor
            normalized.durationX = Clamp(Round(item.durationX or normalized.durationX), -100, 100)
            normalized.durationY = Clamp(Round(item.durationY or normalized.durationY), -100, 100)
            normalized.durationColorByTime = item.durationColorByTime ~= false
            normalized.durationColorR = Clamp(item.durationColorR or normalized.durationColorR, 0, 1)
            normalized.durationColorG = Clamp(item.durationColorG or normalized.durationColorG, 0, 1)
            normalized.durationColorB = Clamp(item.durationColorB or normalized.durationColorB, 0, 1)
            normalized.durationColorA = Clamp(item.durationColorA or normalized.durationColorA, 0, 1)
            normalized.showStacks = item.showStacks ~= false
            normalized.stackMinimum = Clamp(Round(item.stackMinimum or normalized.stackMinimum), 1, 99)
            normalized.stackAnchor = VALID_ANCHORS[item.stackAnchor] and item.stackAnchor or normalized.stackAnchor
            normalized.stackX = Clamp(Round(item.stackX or normalized.stackX), -100, 100)
            normalized.stackY = Clamp(Round(item.stackY or normalized.stackY), -100, 100)
            normalized.stackColorR = Clamp(item.stackColorR or normalized.stackColorR, 0, 1)
            normalized.stackColorG = Clamp(item.stackColorG or normalized.stackColorG, 0, 1)
            normalized.stackColorB = Clamp(item.stackColorB or normalized.stackColorB, 0, 1)
            normalized.stackColorA = Clamp(item.stackColorA or normalized.stackColorA, 0, 1)
            normalized.expiringEnabled = item.expiringEnabled == true
            normalized.expiringThreshold = Clamp(Round(item.expiringThreshold or normalized.expiringThreshold), 1, 300)
            normalized.expiringThresholdMode = item.expiringThresholdMode == "SECONDS" and "SECONDS" or normalized.expiringThresholdMode
            if normalized.type ~= "bar" and item.expiringThresholdMode == "PERCENT" then
                normalized.expiringThresholdMode = "PERCENT"
            elseif normalized.type == "bar" and item.expiringThresholdMode == "PERCENT" then
                normalized.expiringThresholdMode = "PERCENT"
            end
            normalized.expiringColorR = Clamp(item.expiringColorR or normalized.expiringColorR, 0, 1)
            normalized.expiringColorG = Clamp(item.expiringColorG or normalized.expiringColorG, 0, 1)
            normalized.expiringColorB = Clamp(item.expiringColorB or normalized.expiringColorB, 0, 1)
            normalized.expiringColorA = Clamp(item.expiringColorA or normalized.expiringColorA, 0, 1)
            normalized.colorR = Clamp(item.colorR or normalized.colorR, 0, 1)
            normalized.colorG = Clamp(item.colorG or normalized.colorG, 0, 1)
            normalized.colorB = Clamp(item.colorB or normalized.colorB, 0, 1)
            normalized.colorA = Clamp(item.colorA or normalized.colorA, 0, 1)

            table.insert(out.items, normalized)
        end
    end

    return out
end

function Addon:GetCustomIndicatorsConfig()
    local cfg = self:GetSetting("customIndicators")
    if cfg == runtime.rawConfig and runtime.normalizedConfig then
        return runtime.normalizedConfig
    end

    local normalized = self:NormalizeCustomIndicatorsConfig(cfg)
    runtime.rawConfig = cfg
    runtime.normalizedConfig = normalized
    return normalized
end

function Addon:SetCustomIndicatorsConfig(cfg)
    local normalized = self:NormalizeCustomIndicatorsConfig(cfg)
    runtime.rawConfig = normalized
    runtime.normalizedConfig = normalized
    self:SetSetting("customIndicators", normalized)
end

function Addon:CreateCustomIndicatorItem(indicatorType)
    local cfg = self:GetCustomIndicatorsConfig()
    local typeName = VALID_TYPES[indicatorType] and indicatorType or "bar"
    local id = "ci_" .. tostring(cfg.nextId)
    cfg.nextId = cfg.nextId + 1
    local item = BuildDefaultItem(id, typeName)
    table.insert(cfg.items, item)
    self:SetCustomIndicatorsConfig(cfg)
    return id
end

function Addon:DeleteCustomIndicatorItem(id)
    if type(id) ~= "string" then return end
    local cfg = self:GetCustomIndicatorsConfig()
    for i, item in ipairs(cfg.items) do
        if item.id == id then
            table.remove(cfg.items, i)
            self:SetCustomIndicatorsConfig(cfg)
            return
        end
    end
end

function Addon:DuplicateCustomIndicatorItem(id)
    if type(id) ~= "string" then return nil end
    local cfg = self:GetCustomIndicatorsConfig()
    for _, item in ipairs(cfg.items) do
        if item.id == id then
            local copy = DeepCopy(item)
            copy.id = "ci_" .. tostring(cfg.nextId)
            cfg.nextId = cfg.nextId + 1

            local offsetX = copy.offsetX
            if type(offsetX) ~= "number" then
                offsetX = copy.x or 0
            end
            local offsetY = copy.offsetY
            if type(offsetY) ~= "number" then
                offsetY = copy.y or 0
            end

            copy.offsetX = Clamp(offsetX + 8, -250, 250)
            copy.offsetY = Clamp(offsetY - 8, -250, 250)
            copy.x = nil
            copy.y = nil

            table.insert(cfg.items, copy)
            self:SetCustomIndicatorsConfig(cfg)
            return copy.id
        end
    end
    return nil
end

function Addon:UpdateCustomIndicatorItem(id, updates)
    if type(id) ~= "string" or type(updates) ~= "table" then return end
    local cfg = self:GetCustomIndicatorsConfig()
    for _, item in ipairs(cfg.items) do
        if item.id == id then
            for k, v in pairs(updates) do
                item[k] = v
            end
            self:SetCustomIndicatorsConfig(cfg)
            return
        end
    end
end

function Addon:GetCustomIndicatorSpellCatalog()
    local ids = {}
    for _, spell in ipairs(SPELL_CATALOG) do
        table.insert(ids, spell.id)
    end
    return ids
end

function Addon:GetCustomIndicatorSpellOptions()
    local options = {
        { label = "None", value = 0 },
    }

    local sorted = {}
    for _, spell in ipairs(SPELL_CATALOG) do
        local spellId = spell.id
        local name, icon = ResolveSpellInfo(spellId)
        if not name then
            name = spell.name or ("Spell " .. tostring(spellId))
        end
        local label = name .. " (" .. tostring(spellId) .. ")"
        label = BuildSpellOptionLabel(icon, label)

        table.insert(sorted, {
            label = label,
            value = spellId,
            icon = icon,
            sortName = string.lower(name),
        })
    end

    table.sort(sorted, function(a, b)
        if a.sortName == b.sortName then
            return a.value < b.value
        end
        return a.sortName < b.sortName
    end)

    for _, option in ipairs(sorted) do
        option.sortName = nil
        table.insert(options, option)
    end

    return options
end

function Addon:GetCustomIndicatorSpellDisplay(spellId)
    local name, icon = ResolveSpellInfo(spellId)
    if not name then
        name = "Spell " .. tostring(spellId)
    end
    return name, icon
end

function Addon:CustomIndicatorTypeSupportsBorder(indicatorType)
    return indicatorType == "bar" or indicatorType == "square" or indicatorType == "border"
end

function Addon:GetCustomIndicatorAnchorOptions()
    return {
        { label = "Top Left", value = "TOPLEFT" },
        { label = "Top", value = "TOP" },
        { label = "Top Right", value = "TOPRIGHT" },
        { label = "Left", value = "LEFT" },
        { label = "Center", value = "CENTER" },
        { label = "Right", value = "RIGHT" },
        { label = "Bottom Left", value = "BOTTOMLEFT" },
        { label = "Bottom", value = "BOTTOM" },
        { label = "Bottom Right", value = "BOTTOMRIGHT" },
    }
end

local function GetExpiringState(item, aura, now)
    if item.expiringEnabled ~= true or not aura then
        return false
    end

    local effectiveDuration = Addon:CustomIndicatorGetEffectiveDuration(aura)
    local expirationTime = tonumber(aura.expirationTime)
    if not effectiveDuration or not expirationTime or expirationTime <= 0 then
        return false
    end

    local remaining = expirationTime - (now or 0)
    if remaining <= 0 then
        return true
    end

    local threshold = tonumber(item.expiringThreshold) or 0
    if item.expiringThresholdMode == "SECONDS" then
        return remaining <= threshold
    end

    if effectiveDuration <= 0 then
        return false
    end

    return (remaining / effectiveDuration) <= (threshold / 100)
end

local function FormatRemainingTime(aura, now)
    local expirationTime = tonumber(aura and aura.expirationTime)
    if not expirationTime or expirationTime <= 0 then
        return nil
    end

    local remaining = math.max(0, expirationTime - (now or 0))
    if remaining >= 60 then
        return string.format("%dm", math.ceil(remaining / 60))
    end
    if remaining >= 10 then
        return tostring(math.ceil(remaining))
    end
    return string.format("%.1f", remaining)
end

local function GetDurationTextColor(item, aura, now)
    if GetExpiringState(item, aura, now) then
        return item.expiringColorR, item.expiringColorG, item.expiringColorB, item.expiringColorA
    end

    if item.durationColorByTime ~= false and aura and Addon:CustomIndicatorHasReliableTiming(aura) then
        local effectiveDuration = Addon:CustomIndicatorGetEffectiveDuration(aura)
        local expirationTime = tonumber(aura.expirationTime)
        if effectiveDuration and expirationTime then
            local remaining = math.max(0, expirationTime - (now or 0))
            if remaining <= 5 then
                return 1, 0.2, 0.2, 1
            elseif remaining <= 10 then
                return 1, 0.82, 0.2, 1
            end
        end
    end

    return item.durationColorR, item.durationColorG, item.durationColorB, item.durationColorA
end

function Addon:CustomIndicatorComputeFill(now, expirationTime, duration)
    if type(duration) ~= "number" or duration <= 0 then
        return 1
    end
    local remaining = (expirationTime or 0) - (now or 0)
    if remaining <= 0 then return 0 end
    local fill = remaining / duration
    return Clamp(fill, 0, 1)
end

function Addon:CustomIndicatorGetEffectiveDuration(aura)
    if type(aura) ~= "table" then return nil end
    local duration = tonumber(aura.duration)
    if not duration or duration <= 0 then return nil end

    local modRate = tonumber(aura.timeMod or aura.modRate)
    if modRate and modRate > 0 and modRate ~= 1 then
        return duration / modRate
    end

    return duration
end

function Addon:GetCustomIndicatorBarDirectionConfig(direction)
    return DIRECTION_CONFIGS[direction] or DIRECTION_CONFIGS.RIGHT_TO_LEFT
end

function Addon:GetCustomIndicatorBarTextureOptions()
    local out = {}
    local seen = {}

    for _, key in ipairs(BAR_TEXTURE_ORDER) do
        local texture = BAR_TEXTURES[key]
        table.insert(out, {
            label = BuildTextureOptionLabel(texture.path, texture.label),
            value = key,
            path = texture.path,
        })
        seen[texture.path] = true
    end

    local lsm = GetLSM()
    if lsm and lsm.List and lsm.Fetch then
        local list = lsm:List("statusbar") or {}
        for _, name in ipairs(list) do
            local path = lsm:Fetch("statusbar", name, true)
            local key = "LSM_STATUSBAR:" .. tostring(name)
            if path and not seen[path] then
                table.insert(out, {
                    label = BuildTextureOptionLabel(path, tostring(name)),
                    value = key,
                    path = path,
                })
                seen[path] = true
            elseif path then
                table.insert(out, {
                    label = tostring(name),
                    value = key,
                    path = path,
                })
            end
        end
    end
    return out
end

function Addon:GetCustomIndicatorBarTexturePath(key)
    local prefix, value = ParseMediaKey(key)
    if prefix == "LSM_STATUSBAR" then
        local lsm = GetLSM()
        if lsm and lsm.Fetch then
            return lsm:Fetch("statusbar", value, true)
        end
        return nil
    end

    local texture = BAR_TEXTURES[key]
    if texture then
        return texture.path
    end
    return nil
end

function Addon:GetCustomIndicatorBarBorderOptions()
    local out = {}
    local seen = {}

    for _, key in ipairs(BAR_BORDER_ORDER) do
        local border = BAR_BORDERS[key]
        table.insert(out, {
            label = BuildTextureOptionLabel(border.path, border.label),
            value = key,
            path = border.path,
            edgeSize = border.edgeSize,
        })
        seen[border.path or "NONE"] = true
    end

    local lsm = GetLSM()
    if lsm and lsm.List and lsm.Fetch then
        local list = lsm:List("border") or {}
        for _, name in ipairs(list) do
            local path = lsm:Fetch("border", name, true)
            local key = "LSM_BORDER:" .. tostring(name)
            if path and not seen[path] then
                table.insert(out, {
                    label = BuildTextureOptionLabel(path, tostring(name)),
                    value = key,
                    path = path,
                    edgeSize = 8,
                })
                seen[path] = true
            elseif path then
                table.insert(out, {
                    label = tostring(name),
                    value = key,
                    path = path,
                    edgeSize = 8,
                })
            end
        end
    end

    return out
end

function Addon:GetCustomIndicatorBarBorderSpec(key)
    local prefix, value = ParseMediaKey(key)
    if prefix == "LSM_BORDER" then
        local lsm = GetLSM()
        if lsm and lsm.Fetch then
            local path = lsm:Fetch("border", value, true)
            if path then
                return { path = path, edgeSize = 8 }
            end
        end
        return nil
    end

    local border = BAR_BORDERS[key]
    return border
end

function Addon:SetCustomIndicatorPreviewId(id)
    if type(id) == "string" and id ~= "" then
        runtime.previewId = id
    else
        runtime.previewId = nil
    end
end

function Addon:IsCustomIndicatorPreviewActive(id)
    return type(id) == "string" and runtime.previewId == id
end

function Addon:SetCustomIndicatorPreviewAll(enabled)
    runtime.previewAll = enabled == true
end

function Addon:IsCustomIndicatorPreviewAll()
    return runtime.previewAll == true
end

function Addon:CustomIndicatorPreviewFill(now)
    local t = tonumber(now) or 0
    local phase = t % PREVIEW_PERIOD
    local fill = 1 - (phase / PREVIEW_PERIOD)
    return Clamp(fill, 0, 1)
end

function Addon:CustomIndicatorShouldReverseCooldown(item)
    return type(item) == "table" and item.invertCooldownSwipe == true
end

local function ReadNonSecretAuraField(aura, key)
    if type(aura) ~= "table" then
        return nil
    end

    local ok, value = pcall(function()
        return aura[key]
    end)
    if not ok then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

function Addon:CustomIndicatorNormalizeAuraData(auraOrName, icon, count, duration, expirationTime, timeMod)
    if auraOrName == nil then
        return nil
    end

    if type(auraOrName) == "table" then
        local aura = auraOrName
        return {
            icon = ReadNonSecretAuraField(aura, "icon") or ReadNonSecretAuraField(aura, "iconTexture") or ReadNonSecretAuraField(aura, "iconFileID"),
            applications = ReadNonSecretAuraField(aura, "applications") or ReadNonSecretAuraField(aura, "count") or 0,
            duration = ReadNonSecretAuraField(aura, "duration"),
            expirationTime = ReadNonSecretAuraField(aura, "expirationTime"),
            timeMod = ReadNonSecretAuraField(aura, "timeMod") or ReadNonSecretAuraField(aura, "modRate"),
        }
    end

    return {
        icon = icon,
        applications = count or 0,
        duration = duration,
        expirationTime = expirationTime,
        timeMod = timeMod,
    }
end

function Addon:CustomIndicatorHasReliableTiming(aura)
    if type(aura) ~= "table" then return false end
    if not self:CustomIndicatorGetEffectiveDuration(aura) then return false end
    if type(aura.expirationTime) ~= "number" or aura.expirationTime <= 0 then return false end
    return true
end

function Addon:CustomIndicatorIsPlayerAura(unitCaster, aura)
    local sourceUnit = unitCaster
    if type(aura) == "table" then
        sourceUnit = ReadNonSecretAuraField(aura, "sourceUnit")
            or ReadNonSecretAuraField(aura, "unitCaster")
            or ReadNonSecretAuraField(aura, "casterUnit")
            or sourceUnit
    end

    if sourceUnit ~= nil then
        if UnitIsUnit then
            local ok, matches = pcall(UnitIsUnit, sourceUnit, "player")
            return ok and matches or false
        end
        local ok, matches = pcall(function()
            return sourceUnit == "player"
        end)
        if ok then
            return matches or false
        end
    end

    return false
end

function Addon:CustomIndicatorShouldUsePreviewTiming(previewActive, aura)
    if previewActive ~= true then
        return false
    end
    return aura == nil
end

local function ShouldReplaceCachedAura(existing, candidate)
    if not candidate then
        return false
    end
    if not existing then
        return true
    end

    local existingReliable = Addon:CustomIndicatorHasReliableTiming(existing)
    local candidateReliable = Addon:CustomIndicatorHasReliableTiming(candidate)
    if candidateReliable ~= existingReliable then
        return candidateReliable
    end

    local existingExpiration = tonumber(existing.expirationTime) or 0
    local candidateExpiration = tonumber(candidate.expirationTime) or 0
    return candidateExpiration > existingExpiration
end

local function StorePlayerAuraBySpellId(aurasBySpellId, spellId, normalized)
    if type(aurasBySpellId) ~= "table" or not spellId or spellId <= 0 or not normalized then
        return
    end

    local existing = aurasBySpellId[spellId]
    if ShouldReplaceCachedAura(existing, normalized) then
        aurasBySpellId[spellId] = normalized
    end
end

local function ScanPlayerHelpfulAuras(unit, existingCache)
    if not unit or not UnitExists or not UnitExists(unit) then
        return nil
    end

    local aurasBySpellId = existingCache
    if not aurasBySpellId then
        aurasBySpellId = {}
    else
        for spellId in pairs(aurasBySpellId) do
            aurasBySpellId[spellId] = nil
        end
    end

    if UnitAura then
        for i = 1, 255 do
            local name, icon, count, _, duration, expirationTime, unitCaster, _, _, auraSpellID, _, _, _, _, _, timeMod =
                UnitAura(unit, i, "HELPFUL")
            if not name then break end
            if Addon:CustomIndicatorIsPlayerAura(unitCaster) and type(auraSpellID) == "number" and auraSpellID > 0 then
                StorePlayerAuraBySpellId(aurasBySpellId, auraSpellID,
                    Addon:CustomIndicatorNormalizeAuraData(name, icon, count, duration, expirationTime, timeMod))
            end
        end
        return aurasBySpellId
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 255 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not aura then break end
            local spellId = ReadNonSecretAuraField(aura, "spellId")
            if Addon:CustomIndicatorIsPlayerAura(nil, aura) and type(spellId) == "number" and spellId > 0 then
                StorePlayerAuraBySpellId(aurasBySpellId, spellId, Addon:CustomIndicatorNormalizeAuraData(aura))
            end
        end
    end

    return aurasBySpellId
end

local function FindAuraBySpellID(unit, spellId, aurasBySpellId)
    if not unit or not UnitExists or not UnitExists(unit) or not spellId or spellId <= 0 then
        return nil
    end

    if type(aurasBySpellId) == "table" then
        return aurasBySpellId[spellId]
    end

    local directAura = nil
    if C_UnitAuras then
        if unit == "player" and C_UnitAuras.GetPlayerAuraBySpellID then
            directAura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
        elseif C_UnitAuras.GetUnitAuraBySpellID then
            directAura = C_UnitAuras.GetUnitAuraBySpellID(unit, spellId)
        end
    end

    if directAura and Addon:CustomIndicatorIsPlayerAura(nil, directAura) then
        return Addon:CustomIndicatorNormalizeAuraData(directAura)
    end

    local scanned = ScanPlayerHelpfulAuras(unit)
    return scanned and scanned[spellId] or nil
end

local function EnsureCooldown(parent)
    if not parent.BRFIndicatorCooldown and CreateFrame then
        local cd = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
        cd:SetAllPoints(parent)
        cd:SetDrawSwipe(true)
        cd:SetDrawEdge(false)
        cd:SetDrawBling(false)
        cd:SetReverse(false)
        parent.BRFIndicatorCooldown = cd
    end
    return parent.BRFIndicatorCooldown
end

local function EnsureText(parent, key, layer)
    if not parent[key] then
        local text = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontNormalSmall")
        parent[key] = text
    end
    return parent[key]
end

local function ApplyFontStringPosition(text, parent, anchor, x, y)
    if not text then return end

    anchor = anchor or "CENTER"
    x = x or 0
    y = y or 0

    if text.BRFAnchor == anchor and text.BRFParent == parent and text.BRFX == x and text.BRFY == y then
        return
    end

    text:ClearAllPoints()
    text:SetPoint(anchor, parent, anchor, x, y)
    text.BRFAnchor = anchor
    text.BRFParent = parent
    text.BRFX = x
    text.BRFY = y
end

local function ApplyTextState(text, shown, value, r, g, b, a)
    if not text then return end
    if shown and value and value ~= "" then
        if text.BRFText ~= value then
            text:SetText(value)
            text.BRFText = value
        end
        r, g, b, a = r or 1, g or 1, b or 1, a or 1
        if text.BRFColorR ~= r or text.BRFColorG ~= g or text.BRFColorB ~= b or text.BRFColorA ~= a then
            text:SetTextColor(r, g, b, a)
            text.BRFColorR = r
            text.BRFColorG = g
            text.BRFColorB = b
            text.BRFColorA = a
        end
        if not text.BRFShown then
            text:Show()
            text.BRFShown = true
        end
    else
        if text.BRFText ~= "" then
            text:SetText("")
            text.BRFText = ""
        end
        if text.BRFShown ~= false then
            text:Hide()
            text.BRFShown = false
        end
    end
end

local function GetIndicatorDisplaySize(item)
    local scale = tonumber(item.scale) or 1
    if item.type == "bar" then
        return math.max(4, (item.width or 60) * scale), math.max(2, (item.height or 6) * scale)
    end

    if item.type == "square" then
        local width = math.max(4, (item.width or item.size or 18) * scale)
        local height = math.max(4, (item.height or item.size or 18) * scale)
        return width, height
    end

    local size = math.max(4, (item.size or item.width or 18) * scale)
    return size, size
end

local function ApplyVisualFrameLevel(frame, visual, item)
    if not frame or not visual or not visual.frame or not visual.frame.SetFrameLevel then return end

    local baseLevel = frame.GetFrameLevel and frame:GetFrameLevel() or 0
    local desiredLevel = ClampFrameLevel(baseLevel + (item.frameLevelOffset or 0))
    if visual.BRFFrameLevel ~= desiredLevel then
        visual.frame:SetFrameLevel(desiredLevel)
        visual.BRFFrameLevel = desiredLevel
    end

    local desiredStrata
    if item.frameStrata and item.frameStrata ~= "INHERIT" and visual.frame.SetFrameStrata then
        desiredStrata = item.frameStrata
    elseif frame.GetFrameStrata and visual.frame.SetFrameStrata then
        desiredStrata = frame:GetFrameStrata()
    end
    if desiredStrata and visual.BRFFrameStrata ~= desiredStrata then
        visual.frame:SetFrameStrata(desiredStrata)
        visual.BRFFrameStrata = desiredStrata
    end

    if visual.border and visual.border.SetFrameLevel then
        local borderLevel = ClampFrameLevel(desiredLevel + 1)
        if visual.BRFBorderFrameLevel ~= borderLevel then
            visual.border:SetFrameLevel(borderLevel)
            visual.BRFBorderFrameLevel = borderLevel
        end
    end
end

local function EnsureVisual(frame, item)
    if not frame.BRFCustomIndicators then
        frame.BRFCustomIndicators = {}
    end

    local existing = frame.BRFCustomIndicators[item.id]
    if existing and existing.type == item.type then
        return existing
    end

    if existing and existing.frame then
        existing.frame:Hide()
    end

    local parent = frame
    if not parent or not CreateFrame then
        return nil
    end

    local data = { type = item.type }

    if item.type == "bar" then
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetStatusBarTexture(Addon:GetCustomIndicatorBarTexturePath(item.barTexture) or BAR_TEXTURES.BLIZZARD.path)
        local dirCfg = Addon:GetCustomIndicatorBarDirectionConfig(item.direction)
        bar:SetOrientation(dirCfg.orientation)
        bar:SetReverseFill(dirCfg.reverseFill)
        bar:SetMinMaxValues(0, 1)
        bar:EnableMouse(false)

        local background = bar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(bar)

        local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetFrameLevel(ClampFrameLevel(bar:GetFrameLevel() + 1))

        data.frame = bar
        data.bar = bar
        data.background = background
        data.border = border
        data.durationText = EnsureText(bar, "BRFIndicatorDurationText")
    elseif item.type == "border" then
        local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        holder:EnableMouse(false)
        data.frame = holder
        data.border = holder
        data.durationText = EnsureText(holder, "BRFIndicatorDurationText")
    else
        local holder = CreateFrame("Frame", nil, parent)
        holder:EnableMouse(false)
        holder.texture = holder:CreateTexture(nil, "ARTWORK")
        holder.texture:SetAllPoints(holder)
        local border = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetFrameLevel(ClampFrameLevel(holder:GetFrameLevel() + 1))
        data.frame = holder
        data.texture = holder.texture
        data.border = border
        data.cooldown = EnsureCooldown(holder)
        data.durationText = EnsureText(holder, "BRFIndicatorDurationText")
        data.stackText = EnsureText(holder, "BRFIndicatorStackText")
    end

    frame.BRFCustomIndicators[item.id] = data
    return data
end

local function ApplyCooldown(visual, item, aura)
    if not visual or not visual.cooldown then return end
    local shouldDrawSwipe = item.hideSwipe ~= true and item.showCooldownSwipe ~= false
    if visual.cooldown.SetDrawSwipe then
        if visual.BRFDrawSwipe ~= shouldDrawSwipe then
            visual.cooldown:SetDrawSwipe(shouldDrawSwipe)
            visual.BRFDrawSwipe = shouldDrawSwipe
        end
    end
    local shouldReverse = Addon:CustomIndicatorShouldReverseCooldown(item)
    if visual.cooldown.SetReverse then
        if visual.BRFReverse ~= shouldReverse then
            visual.cooldown:SetReverse(shouldReverse)
            visual.BRFReverse = shouldReverse
        end
    end
    local hideCountdownNumbers = item.showCooldownText == false
    if visual.cooldown.SetHideCountdownNumbers then
        if visual.BRFHideCountdownNumbers ~= hideCountdownNumbers then
            visual.cooldown:SetHideCountdownNumbers(hideCountdownNumbers)
            visual.BRFHideCountdownNumbers = hideCountdownNumbers
        end
    end
    if aura and Addon:CustomIndicatorHasReliableTiming(aura) then
        local effectiveDuration = Addon:CustomIndicatorGetEffectiveDuration(aura)
        local startTime = aura.expirationTime - effectiveDuration
        local modRate = tonumber(aura.timeMod or aura.modRate)
        local durationToSet = (modRate and modRate > 0) and aura.duration or effectiveDuration

        if visual.BRFCooldownStart ~= startTime or visual.BRFCooldownDuration ~= durationToSet or visual.BRFCooldownModRate ~= modRate then
            if modRate and modRate > 0 then
                local ok = pcall(visual.cooldown.SetCooldown, visual.cooldown, startTime, aura.duration, modRate)
                if not ok then
                    visual.cooldown:SetCooldown(startTime, effectiveDuration)
                end
            else
                visual.cooldown:SetCooldown(startTime, effectiveDuration)
            end
            visual.BRFCooldownStart = startTime
            visual.BRFCooldownDuration = durationToSet
            visual.BRFCooldownModRate = modRate
        end
        if not visual.BRFCooldownShown then
            visual.cooldown:Show()
            visual.BRFCooldownShown = true
        end
    else
        if visual.BRFCooldownShown ~= false then
            if visual.cooldown.Clear then
                visual.cooldown:Clear()
            elseif CooldownFrame_Clear then
                CooldownFrame_Clear(visual.cooldown)
            else
                visual.cooldown:SetCooldown(0, 0)
            end
            visual.cooldown:Hide()
            visual.BRFCooldownShown = false
            visual.BRFCooldownStart = nil
            visual.BRFCooldownDuration = nil
            visual.BRFCooldownModRate = nil
        end
    end
end

local function ApplyDurationText(visual, item, aura, now)
    if not visual or not visual.durationText then return end

    ApplyFontStringPosition(visual.durationText, visual.frame, item.durationAnchor, item.durationX, item.durationY)

    if item.showDuration == false or not aura or not Addon:CustomIndicatorHasReliableTiming(aura) then
        visual.BRFLastDurationTextTick = nil
        ApplyTextState(visual.durationText, false)
        return
    end

    local coarseTick = math.floor((now or 0) / DURATION_TEXT_INTERVAL)
    if visual.BRFLastDurationTextTick == coarseTick and visual.durationText.BRFShown then
        return
    end
    visual.BRFLastDurationTextTick = coarseTick

    local text = FormatRemainingTime(aura, now)
    local r, g, b, a = GetDurationTextColor(item, aura, now)
    ApplyTextState(visual.durationText, text ~= nil, text, r, g, b, a)
end

local function ApplyStackText(visual, item, aura)
    if not visual or not visual.stackText then return end

    ApplyFontStringPosition(visual.stackText, visual.frame, item.stackAnchor, item.stackX, item.stackY)

    local stacks = aura and tonumber(aura.applications) or 0
    local minimum = tonumber(item.stackMinimum) or 2
    local show = item.showStacks ~= false and stacks and stacks >= minimum
    ApplyTextState(visual.stackText, show, show and tostring(stacks) or nil,
        item.stackColorR, item.stackColorG, item.stackColorB, item.stackColorA)
end

local ApplyBorderBackdrop
local ClearBackdrop

local function ApplyPlacedIndicatorBorder(visual, item, r, g, b, a)
    if not visual or not visual.border or not visual.border.SetBackdrop then return end

    if item.showBorder == false then
        if visual.BRFBorderActive ~= false then
            ClearBackdrop(visual.border)
            visual.border:Hide()
            visual.BRFBorderActive = false
            visual.BRFBorderPath = nil
        end
        return
    end

    local borderSpec = Addon:GetCustomIndicatorBarBorderSpec(item.barBorder)
    if borderSpec and borderSpec.path and borderSpec.path ~= "" then
        local edgeSize = item.borderSize or borderSpec.edgeSize or 1
        local padding = (item.borderPadding or 0) - (item.borderInset or 0)
        local total = edgeSize + padding
        if total < 0 then total = 0 end
        if visual.BRFBorderTotal ~= total then
            visual.border:SetPoint("TOPLEFT", -total, total)
            visual.border:SetPoint("BOTTOMRIGHT", total, -total)
            visual.BRFBorderTotal = total
        end
        local needsBackdrop = visual.BRFBorderPath ~= borderSpec.path or visual.BRFBorderEdgeSize ~= edgeSize
            or visual.BRFBorderColorR ~= r or visual.BRFBorderColorG ~= g or visual.BRFBorderColorB ~= b or visual.BRFBorderColorA ~= a
        if (needsBackdrop and ApplyBorderBackdrop(visual.border, borderSpec.path, edgeSize, r, g, b, a)) or (not needsBackdrop and visual.BRFBorderActive) then
            if not visual.BRFBorderActive then
                visual.border:Show()
            end
            visual.BRFBorderActive = true
            visual.BRFBorderPath = borderSpec.path
            visual.BRFBorderEdgeSize = edgeSize
            visual.BRFBorderColorR = r
            visual.BRFBorderColorG = g
            visual.BRFBorderColorB = b
            visual.BRFBorderColorA = a
        else
            visual.border:Hide()
            visual.BRFBorderActive = false
        end
    else
        if visual.BRFBorderActive ~= false or visual.BRFBorderPath ~= nil then
            ClearBackdrop(visual.border)
            visual.border:Hide()
            visual.BRFBorderActive = false
            visual.BRFBorderPath = nil
        end
    end
end

local function HideVisual(data)
    if not data or not data.frame then return end
    data.frame:Hide()
    data.BRFShown = false
    if runtime.activeTimedVisuals[data] then
        runtime.activeTimedVisuals[data] = nil
    end
    if data.durationText then
        data.durationText:Hide()
        data.durationText.BRFShown = false
    end
    if data.stackText then
        data.stackText:Hide()
        data.stackText.BRFShown = false
    end
    if data.cooldown then
        data.cooldown:Hide()
        data.BRFCooldownShown = false
    end
    data.BRFBorderBodyShown = false
end

local function RegisterTimedVisual(visual, frame, item)
    if not visual or not frame or not item then return end
    visual.BRFFrameRef = frame
    visual.BRFItemRef = item
    if not runtime.activeTimedVisuals[visual] then
        runtime.activeTimedVisuals[visual] = true
    end
end

local function UnregisterTimedVisual(visual)
    if runtime.activeTimedVisuals[visual] then
        runtime.activeTimedVisuals[visual] = nil
    end
end

local function UpdateTimedIndicatorVisual(visual, now)
    if not visual or not visual.frame then
        UnregisterTimedVisual(visual)
        return false
    end

    local frame = visual.BRFFrameRef
    local item = visual.BRFItemRef
    if not frame or not item or not frame.unit or not Addon:IsRaidOrPartyFrame(frame) then
        UnregisterTimedVisual(visual)
        return false
    end
    if visual.frame.IsShown and not visual.frame:IsShown() then
        UnregisterTimedVisual(visual)
        return false
    end

    local aura = nil
    local previewActive = Addon:IsConfigOpen() and
        (Addon:IsCustomIndicatorPreviewAll() or Addon:IsCustomIndicatorPreviewActive(item.id))
    local aurasBySpellId = frame.BRFCustomIndicatorAurasBySpellId
    if type(aurasBySpellId) == "table" then
        aura = aurasBySpellId[item.spellId]
    end
    if Addon:CustomIndicatorShouldUsePreviewTiming(previewActive, aura) then
        aura = {
            icon = GetSpellTexture and GetSpellTexture(item.spellId > 0 and item.spellId or 136243),
            applications = 3,
            duration = PREVIEW_PERIOD,
            expirationTime = now + (PREVIEW_PERIOD - (now % PREVIEW_PERIOD)),
        }
    end

    if not aura or not Addon:CustomIndicatorHasReliableTiming(aura) then
        UnregisterTimedVisual(visual)
        return false
    end

    local effectiveDuration = Addon:CustomIndicatorGetEffectiveDuration(aura)
    local fill = Addon:CustomIndicatorComputeFill(now, aura.expirationTime, effectiveDuration or aura.duration)
    local isExpiring = GetExpiringState(item, aura, now)

    if item.type == "bar" and visual.bar then
        local barR, barG, barB, barA = item.colorR, item.colorG, item.colorB, item.colorA
        if isExpiring then
            barR, barG, barB, barA = item.expiringColorR, item.expiringColorG, item.expiringColorB, item.expiringColorA
        end
        if visual.BRFBarColorR ~= barR or visual.BRFBarColorG ~= barG or visual.BRFBarColorB ~= barB or visual.BRFBarColorA ~= barA then
            visual.bar:SetStatusBarColor(barR, barG, barB, barA)
            visual.BRFBarColorR = barR
            visual.BRFBarColorG = barG
            visual.BRFBarColorB = barB
            visual.BRFBarColorA = barA
        end
        if visual.BRFBarValue ~= fill then
            visual.bar:SetValue(fill)
            visual.BRFBarValue = fill
        end
        ApplyDurationText(visual, item, aura, now)
    elseif item.type == "icon" or item.type == "square" then
        if item.type == "square" and visual.texture then
            local squareR, squareG, squareB, squareA = item.colorR, item.colorG, item.colorB, item.colorA
            if isExpiring then
                squareR, squareG, squareB, squareA = item.expiringColorR, item.expiringColorG, item.expiringColorB, item.expiringColorA
            end
            if visual.BRFSquareColorR ~= squareR or visual.BRFSquareColorG ~= squareG or visual.BRFSquareColorB ~= squareB or visual.BRFSquareColorA ~= squareA then
                visual.texture:SetColorTexture(squareR, squareG, squareB, squareA)
                visual.BRFSquareColorR = squareR
                visual.BRFSquareColorG = squareG
                visual.BRFSquareColorB = squareB
                visual.BRFSquareColorA = squareA
            end
        end
        ApplyDurationText(visual, item, aura, now)
    elseif item.type == "border" and visual.border then
        local borderR, borderG, borderB, borderA = item.colorR, item.colorG, item.colorB, item.alpha or 1
        if isExpiring then
            borderR, borderG, borderB, borderA = item.expiringColorR, item.expiringColorG, item.expiringColorB, item.expiringColorA
        end
        local edgeSize = item.borderSize or 1
        if (visual.BRFBorderBodyPath ~= "Interface\\Buttons\\WHITE8X8" or visual.BRFBorderBodyEdgeSize ~= edgeSize
            or visual.BRFBorderBodyColorR ~= borderR or visual.BRFBorderBodyColorG ~= borderG
            or visual.BRFBorderBodyColorB ~= borderB or visual.BRFBorderBodyColorA ~= borderA)
            and ApplyBorderBackdrop(visual.border, "Interface\\Buttons\\WHITE8X8", edgeSize, borderR, borderG, borderB, borderA) then
            visual.BRFBorderBodyPath = "Interface\\Buttons\\WHITE8X8"
            visual.BRFBorderBodyEdgeSize = edgeSize
            visual.BRFBorderBodyColorR = borderR
            visual.BRFBorderBodyColorG = borderG
            visual.BRFBorderBodyColorB = borderB
            visual.BRFBorderBodyColorA = borderA
        end
        ApplyDurationText(visual, item, aura, now)
    end

    return true
end

local function IsBackdropSafe(frame)
    if not frame or not frame.SetBackdrop then
        return false
    end
    if frame.IsForbidden and frame:IsForbidden() then
        return false
    end
    if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
        return false
    end
    return true
end

ClearBackdrop = function(frame)
    if not frame or not frame.SetBackdrop then return end
    pcall(frame.SetBackdrop, frame, nil)
    frame.BRFBackdropKey = nil
end

ApplyBorderBackdrop = function(frame, edgeFile, edgeSize, r, g, b, a)
    if not IsBackdropSafe(frame) then
        return false
    end

    local backdropKey = tostring(edgeFile) .. "|" .. tostring(edgeSize)
    if frame.BRFBackdropKey ~= backdropKey then
        local ok = pcall(frame.SetBackdrop, frame, {
            edgeFile = edgeFile,
            edgeSize = edgeSize,
        })
        if not ok then
            return false
        end
        frame.BRFBackdropKey = backdropKey
    end

    if frame.BRFBackdropColorR ~= r or frame.BRFBackdropColorG ~= g or frame.BRFBackdropColorB ~= b or frame.BRFBackdropColorA ~= a then
        pcall(frame.SetBackdropBorderColor, frame, r, g, b, a)
        frame.BRFBackdropColorR = r
        frame.BRFBackdropColorG = g
        frame.BRFBackdropColorB = b
        frame.BRFBackdropColorA = a
    end
    return true
end

local function UpdateIndicatorVisual(frame, item, aurasBySpellId)
    local previewActive = Addon:IsConfigOpen() and
        (Addon:IsCustomIndicatorPreviewAll() or Addon:IsCustomIndicatorPreviewActive(item.id))

    if item.spellId <= 0 and not previewActive then
        return false, false
    end

    local now = GetTime and GetTime() or 0
    local aura = FindAuraBySpellID(frame.unit, item.spellId, aurasBySpellId)
    local usePreviewTiming = Addon:CustomIndicatorShouldUsePreviewTiming(previewActive, aura)
    if usePreviewTiming then
        aura = {
            icon = GetSpellTexture and GetSpellTexture(item.spellId > 0 and item.spellId or 136243),
            applications = 3,
            duration = PREVIEW_PERIOD,
            expirationTime = now + (PREVIEW_PERIOD - (now % PREVIEW_PERIOD)),
        }
    end

    if not aura then
        return false, false
    end

    local visual = EnsureVisual(frame, item)
    if not visual or not visual.frame then
        return false, false
    end

    local width, height = GetIndicatorDisplaySize(item)
    if item.type == "border" then
        local inset = item.borderInset or 0
        if visual.BRFLayoutMode ~= "border" or visual.BRFInset ~= inset or visual.BRFLayoutParent ~= frame then
            visual.frame:ClearAllPoints()
            visual.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, inset)
            visual.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset, -inset)
            visual.BRFLayoutMode = "border"
            visual.BRFInset = inset
            visual.BRFLayoutParent = frame
        end
    else
        local point = item.anchor or "CENTER"
        local offsetX = item.offsetX or 0
        local offsetY = item.offsetY or 0
        if visual.BRFLayoutMode ~= "point" or visual.BRFAnchor ~= point or visual.BRFOffsetX ~= offsetX or visual.BRFOffsetY ~= offsetY or visual.BRFLayoutParent ~= frame then
            visual.frame:ClearAllPoints()
            visual.frame:SetPoint(point, frame, point, offsetX, offsetY)
            visual.BRFLayoutMode = "point"
            visual.BRFAnchor = point
            visual.BRFOffsetX = offsetX
            visual.BRFOffsetY = offsetY
            visual.BRFLayoutParent = frame
        end
        if visual.BRFWidth ~= width or visual.BRFHeight ~= height then
            visual.frame:SetSize(width, height)
            visual.BRFWidth = width
            visual.BRFHeight = height
        end
    end
    ApplyVisualFrameLevel(frame, visual, item)
    local frameAlpha = item.alpha or 1
    if visual.BRFAlpha ~= frameAlpha then
        visual.frame:SetAlpha(frameAlpha)
        visual.BRFAlpha = frameAlpha
    end
    if not visual.BRFShown then
        visual.frame:Show()
        visual.BRFShown = true
    end

    local fillForColor
    if usePreviewTiming then
        fillForColor = Addon:CustomIndicatorPreviewFill(now)
    else
        local effectiveDuration = Addon:CustomIndicatorGetEffectiveDuration(aura)
        fillForColor = Addon:CustomIndicatorComputeFill(now, aura.expirationTime, effectiveDuration or aura.duration)
    end

    local isExpiring = GetExpiringState(item, aura, now)

    if item.type == "bar" and visual.bar then
        local barTexture = Addon:GetCustomIndicatorBarTexturePath(item.barTexture) or BAR_TEXTURES.BLIZZARD.path
        if visual.BRFBarTexture ~= barTexture then
            visual.bar:SetStatusBarTexture(barTexture)
            visual.BRFBarTexture = barTexture
        end
        local direction = item.orientation == "VERTICAL"
            and ((item.direction == "TOP_TO_BOTTOM" or item.direction == "BOTTOM_TO_TOP") and item.direction or "BOTTOM_TO_TOP")
            or ((item.direction == "LEFT_TO_RIGHT" or item.direction == "RIGHT_TO_LEFT") and item.direction or "RIGHT_TO_LEFT")
        local dirCfg = Addon:GetCustomIndicatorBarDirectionConfig(direction)
        if visual.BRFBarOrientation ~= dirCfg.orientation then
            visual.bar:SetOrientation(dirCfg.orientation)
            visual.BRFBarOrientation = dirCfg.orientation
        end
        if visual.BRFBarReverseFill ~= dirCfg.reverseFill then
            visual.bar:SetReverseFill(dirCfg.reverseFill)
            visual.BRFBarReverseFill = dirCfg.reverseFill
        end
        local barR, barG, barB, barA = item.colorR, item.colorG, item.colorB, item.colorA
        if isExpiring then
            barR, barG, barB, barA = item.expiringColorR, item.expiringColorG, item.expiringColorB, item.expiringColorA
        end
        if visual.BRFBarColorR ~= barR or visual.BRFBarColorG ~= barG or visual.BRFBarColorB ~= barB or visual.BRFBarColorA ~= barA then
            visual.bar:SetStatusBarColor(barR, barG, barB, barA)
            visual.BRFBarColorR = barR
            visual.BRFBarColorG = barG
            visual.BRFBarColorB = barB
            visual.BRFBarColorA = barA
        end
        if visual.background then
            local bgR, bgG, bgB, bgA = item.barBackgroundColorR, item.barBackgroundColorG,
                item.barBackgroundColorB, item.barBackgroundColorA
            if visual.BRFBackgroundColorR ~= bgR or visual.BRFBackgroundColorG ~= bgG or visual.BRFBackgroundColorB ~= bgB or visual.BRFBackgroundColorA ~= bgA then
                visual.background:SetColorTexture(bgR, bgG, bgB, bgA)
                visual.BRFBackgroundColorR = bgR
                visual.BRFBackgroundColorG = bgG
                visual.BRFBackgroundColorB = bgB
                visual.BRFBackgroundColorA = bgA
            end
        end
        local fill = fillForColor
        if visual.BRFBarValue ~= fill then
            visual.bar:SetValue(fill)
            visual.BRFBarValue = fill
        end

        ApplyPlacedIndicatorBorder(visual, item, item.borderColorR, item.borderColorG, item.borderColorB, item.borderColorA)
        ApplyDurationText(visual, item, aura, now)
    elseif item.type == "icon" and visual.texture then
        local icon = aura.icon or (GetSpellTexture and GetSpellTexture(item.spellId))
        if icon and visual.BRFTexture ~= icon then
            visual.texture:SetTexture(icon)
            visual.BRFTexture = icon
        end
        ApplyPlacedIndicatorBorder(visual, item, item.borderColorR, item.borderColorG, item.borderColorB, item.borderColorA)
        ApplyCooldown(visual, item, aura)
        ApplyDurationText(visual, item, aura, now)
        ApplyStackText(visual, item, aura)
    elseif item.type == "square" and visual.texture then
        local squareR, squareG, squareB, squareA = item.colorR, item.colorG, item.colorB, item.colorA
        if isExpiring then
            squareR, squareG, squareB, squareA = item.expiringColorR, item.expiringColorG, item.expiringColorB, item.expiringColorA
        end
        if visual.BRFSquareColorR ~= squareR or visual.BRFSquareColorG ~= squareG or visual.BRFSquareColorB ~= squareB or visual.BRFSquareColorA ~= squareA then
            visual.texture:SetColorTexture(squareR, squareG, squareB, squareA)
            visual.BRFSquareColorR = squareR
            visual.BRFSquareColorG = squareG
            visual.BRFSquareColorB = squareB
            visual.BRFSquareColorA = squareA
        end
        ApplyPlacedIndicatorBorder(visual, item, item.borderColorR, item.borderColorG, item.borderColorB, item.borderColorA)
        ApplyCooldown(visual, item, aura)
        ApplyDurationText(visual, item, aura, now)
        ApplyStackText(visual, item, aura)
    elseif item.type == "border" and visual.border then
        local borderR, borderG, borderB, borderA = item.colorR, item.colorG, item.colorB, item.alpha or 1
        if isExpiring then
            borderR, borderG, borderB, borderA = item.expiringColorR, item.expiringColorG, item.expiringColorB,
                item.expiringColorA
        end
        local edgeSize = item.borderSize or 1
        if (visual.BRFBorderBodyPath ~= "Interface\\Buttons\\WHITE8X8" or visual.BRFBorderBodyEdgeSize ~= edgeSize
            or visual.BRFBorderBodyColorR ~= borderR or visual.BRFBorderBodyColorG ~= borderG
            or visual.BRFBorderBodyColorB ~= borderB or visual.BRFBorderBodyColorA ~= borderA)
            and ApplyBorderBackdrop(visual.border, "Interface\\Buttons\\WHITE8X8", edgeSize, borderR, borderG, borderB, borderA) then
            visual.BRFBorderBodyPath = "Interface\\Buttons\\WHITE8X8"
            visual.BRFBorderBodyEdgeSize = edgeSize
            visual.BRFBorderBodyColorR = borderR
            visual.BRFBorderBodyColorG = borderG
            visual.BRFBorderBodyColorB = borderB
            visual.BRFBorderBodyColorA = borderA
        end
        if not visual.BRFBorderBodyShown then
            visual.border:Show()
            visual.BRFBorderBodyShown = true
        end
        ApplyDurationText(visual, item, aura, now)
    end

    local isTimed = Addon:CustomIndicatorHasReliableTiming(aura) and true or false
    if isTimed then
        RegisterTimedVisual(visual, frame, item)
    else
        UnregisterTimedVisual(visual)
    end

    return true, isTimed
end

local function HideStaleVisuals(frame, activeIds)
    if not frame.BRFCustomIndicators then return end
    for id, data in pairs(frame.BRFCustomIndicators) do
        if not activeIds[id] then
            HideVisual(data)
        end
    end
end

function Addon:UpdateCustomIndicators(frame, useCachedAurasOnly)
    if not self:IsRaidOrPartyFrame(frame) then return false end

    local cfg = self:GetCustomIndicatorsConfig()
    local allowPreview = self:IsConfigOpen() and (runtime.previewId ~= nil or runtime.previewAll == true)
    if not cfg.enabled and not allowPreview then
        if frame.BRFCustomIndicators then
            for _, data in pairs(frame.BRFCustomIndicators) do
                HideVisual(data)
            end
        end
        return false
    end

    local hasTimed = false
    local aurasBySpellId = frame.BRFCustomIndicatorAurasBySpellId
    if useCachedAurasOnly ~= true or not aurasBySpellId or frame.BRFCustomIndicatorAuraUnit ~= frame.unit then
        aurasBySpellId = ScanPlayerHelpfulAuras(frame.unit, aurasBySpellId)
        frame.BRFCustomIndicatorAurasBySpellId = aurasBySpellId
        frame.BRFCustomIndicatorAuraUnit = frame.unit
    end

    local activeIds = frame.BRFCustomIndicatorActiveIds
    if not activeIds then
        activeIds = {}
        frame.BRFCustomIndicatorActiveIds = activeIds
    else
        for id in pairs(activeIds) do
            activeIds[id] = nil
        end
    end

    for _, item in ipairs(cfg.items) do
        activeIds[item.id] = true
        local visible, timed = UpdateIndicatorVisual(frame, item, aurasBySpellId)
        if not visible then
            local existing = frame.BRFCustomIndicators and frame.BRFCustomIndicators[item.id]
            HideVisual(existing)
        end
        if timed then
            hasTimed = true
        end
    end

    HideStaleVisuals(frame, activeIds)
    return hasTimed
end

local function RefreshTickerState()
    local needsTicker = false
    local now = GetTime and GetTime() or 0
    for visual in pairs(runtime.activeTimedVisuals) do
        if UpdateTimedIndicatorVisual(visual, now) then
            needsTicker = true
        end
    end

    if needsTicker and not runtime.ticker and C_Timer and C_Timer.NewTicker then
        runtime.ticker = C_Timer.NewTicker(TICKER_INTERVAL, function()
            RefreshTickerState()
        end)
    elseif not needsTicker and runtime.ticker then
        runtime.ticker:Cancel()
        runtime.ticker = nil
    end
end

local eventFrame

local function FindFrameByUnit(unit)
    if not unit then return nil end

    local matched = nil
    Addon:ForEachFrame(function(frame)
        if frame and frame.unit == unit and not matched then
            matched = frame
        end
    end)
    return matched
end

local function UpdateFrameAndTicker(frame, forced)
    if not Addon:IsRaidOrPartyFrame(frame) then return end

    local now = GetTime and GetTime() or 0
    local lastRefresh = frame.BRFCustomIndicatorLastFullRefresh or 0
    if forced ~= true and (now - lastRefresh) < FULL_REFRESH_MIN_INTERVAL then
        if not frame.BRFCustomIndicatorRefreshPending and C_Timer and C_Timer.After then
            frame.BRFCustomIndicatorRefreshPending = true
            local delay = FULL_REFRESH_MIN_INTERVAL - (now - lastRefresh)
            if delay < 0 then delay = 0 end
            C_Timer.After(delay, function()
                frame.BRFCustomIndicatorRefreshPending = false
                UpdateFrameAndTicker(frame, true)
            end)
        end
        return
    end

    frame.BRFCustomIndicatorLastFullRefresh = now

    local hasTimed = Addon:UpdateCustomIndicators(frame)

    if hasTimed then
        if not runtime.ticker and C_Timer and C_Timer.NewTicker then
            runtime.ticker = C_Timer.NewTicker(TICKER_INTERVAL, function()
                RefreshTickerState()
            end)
        end
    elseif runtime.ticker then
        RefreshTickerState()
    end
end

function Addon:RefreshCustomIndicators()
    local needsTicker = false
    Addon:ForEachFrame(function(frame)
        if Addon:UpdateCustomIndicators(frame) then
            needsTicker = true
        end
    end)

    if needsTicker then
        if not runtime.ticker and C_Timer and C_Timer.NewTicker then
            runtime.ticker = C_Timer.NewTicker(TICKER_INTERVAL, function()
                RefreshTickerState()
            end)
        end
    elseif runtime.ticker then
        runtime.ticker:Cancel()
        runtime.ticker = nil
    end
end

function Addon:HookCustomIndicators()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("UNIT_AURA")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        eventFrame:SetScript("OnEvent", function(_, event, unit)
            if event == "UNIT_AURA" then
                local frame = FindFrameByUnit(unit)
                if frame then
                    UpdateFrameAndTicker(frame, true)
                end
            else
                Addon:RefreshCustomIndicators()
            end
        end)
    end
end
