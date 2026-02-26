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

local TICKER_INTERVAL = 0.08
local PREVIEW_PERIOD = 3.0
local runtime = {
    ticker = nil,
    previewId = nil,
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
    return {
        id = id,
        enabled = true,
        type = indicatorType,
        spellId = 0,
        x = 0,
        y = 0,
        width = indicatorType == "bar" and 40 or 14,
        height = indicatorType == "bar" and 4 or 14,
        zOffset = 0,
        direction = "RIGHT_TO_LEFT",
        barTexture = "BLIZZARD",
        barBorder = "NONE",
        borderSize = 8,
        borderPadding = 0,
        borderColorR = 1,
        borderColorG = 1,
        borderColorB = 1,
        borderColorA = 1,
        showCooldownSwipe = true,
        showCooldownText = true,
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
            normalized.x = Clamp(Round(item.x or normalized.x), -250, 250)
            normalized.y = Clamp(Round(item.y or normalized.y), -250, 250)
            normalized.width = Clamp(Round(item.width or normalized.width), 4, 250)
            normalized.height = Clamp(Round(item.height or normalized.height), 2, 250)
            normalized.zOffset = Clamp(Round(item.zOffset or normalized.zOffset), -30, 30)
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
            normalized.borderSize = Clamp(Round(item.borderSize or normalized.borderSize), 1, 24)
            normalized.borderPadding = Clamp(Round(item.borderPadding or normalized.borderPadding), -20, 20)
            normalized.borderColorR = Clamp(item.borderColorR or normalized.borderColorR, 0, 1)
            normalized.borderColorG = Clamp(item.borderColorG or normalized.borderColorG, 0, 1)
            normalized.borderColorB = Clamp(item.borderColorB or normalized.borderColorB, 0, 1)
            normalized.borderColorA = Clamp(item.borderColorA or normalized.borderColorA, 0, 1)
            normalized.showCooldownSwipe = item.showCooldownSwipe ~= false
            normalized.showCooldownText = item.showCooldownText ~= false
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
    return self:NormalizeCustomIndicatorsConfig(cfg)
end

function Addon:SetCustomIndicatorsConfig(cfg)
    self:SetSetting("customIndicators", self:NormalizeCustomIndicatorsConfig(cfg))
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
            copy.x = Clamp(copy.x + 8, -250, 250)
            copy.y = Clamp(copy.y - 8, -250, 250)
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
    return indicatorType == "bar" or indicatorType == "square"
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

function Addon:GetCustomIndicatorBarDirectionConfig(direction)
    if direction == "LEFT_TO_RIGHT" then
        return { orientation = "HORIZONTAL", reverseFill = false }
    elseif direction == "TOP_TO_BOTTOM" then
        return { orientation = "VERTICAL", reverseFill = true }
    elseif direction == "BOTTOM_TO_TOP" then
        return { orientation = "VERTICAL", reverseFill = false }
    end
    return { orientation = "HORIZONTAL", reverseFill = true }
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
    if border then
        return {
            path = border.path,
            edgeSize = border.edgeSize,
        }
    end
    return nil
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

function Addon:CustomIndicatorPreviewFill(now)
    local t = tonumber(now) or 0
    local phase = t % PREVIEW_PERIOD
    local fill = 1 - (phase / PREVIEW_PERIOD)
    return Clamp(fill, 0, 1)
end

local function FindAuraBySpellID(unit, spellId)
    if not unit or not UnitExists or not UnitExists(unit) or not spellId or spellId <= 0 then
        return nil
    end

    if AuraUtil and AuraUtil.FindAuraBySpellID then
        local name, icon, count, debuffType, duration, expirationTime = AuraUtil.FindAuraBySpellID(spellId, unit, "HELPFUL")
        if name then
            return {
                icon = icon,
                applications = count,
                duration = duration,
                expirationTime = expirationTime,
            }
        end
    end

    local function IsMatchingSpellId(auraSpellId, wantedSpellId)
        local ok, matched = pcall(function()
            return auraSpellId == wantedSpellId
        end)
        return ok and matched or false
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 255 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not aura then break end
            if IsMatchingSpellId(aura.spellId, spellId) then
                return aura
            end
        end
    end

    if UnitAura then
        for i = 1, 255 do
            local name, icon, count, _, duration, expirationTime, _, _, _, auraSpellID = UnitAura(unit, i, "HELPFUL")
            if not name then break end
            if IsMatchingSpellId(auraSpellID, spellId) then
                return {
                    icon = icon,
                    applications = count,
                    duration = duration,
                    expirationTime = expirationTime,
                }
            end
        end
    end

    return nil
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

    local parent = frame.healthBar or frame
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

        local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetFrameLevel(ClampFrameLevel(bar:GetFrameLevel() + 1))

        data.frame = bar
        data.bar = bar
        data.border = border
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
    end

    frame.BRFCustomIndicators[item.id] = data
    return data
end

local function ApplyCooldown(visual, item, aura)
    if not visual or not visual.cooldown then return end
    if visual.cooldown.SetDrawSwipe then
        visual.cooldown:SetDrawSwipe(item.showCooldownSwipe ~= false)
    end
    if visual.cooldown.SetHideCountdownNumbers then
        visual.cooldown:SetHideCountdownNumbers(item.showCooldownText == false)
    end
    if aura and aura.duration and aura.duration > 0 and aura.expirationTime then
        local startTime = aura.expirationTime - aura.duration
        visual.cooldown:SetCooldown(startTime, aura.duration)
        visual.cooldown:Show()
    else
        if visual.cooldown.Clear then
            visual.cooldown:Clear()
        elseif CooldownFrame_Clear then
            CooldownFrame_Clear(visual.cooldown)
        else
            visual.cooldown:SetCooldown(0, 0)
        end
        visual.cooldown:Hide()
    end
end

local function HideVisual(data)
    if not data or not data.frame then return end
    data.frame:Hide()
end

local function UpdateIndicatorVisual(frame, item)
    local previewActive = Addon:IsConfigOpen() and Addon:IsCustomIndicatorPreviewActive(item.id)

    if item.spellId <= 0 and not previewActive then
        return false, false
    end

    local now = GetTime and GetTime() or 0
    local aura = FindAuraBySpellID(frame.unit, item.spellId)
    if not aura and previewActive then
        aura = {
            icon = GetSpellTexture and GetSpellTexture(item.spellId > 0 and item.spellId or 136243),
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

    visual.frame:ClearAllPoints()
    visual.frame:SetPoint("CENTER", frame.healthBar or frame, "CENTER", item.x, item.y)
    visual.frame:SetSize(item.width, item.height)
    local parent = frame.healthBar or frame
    if parent and parent.GetFrameLevel and visual.frame.SetFrameLevel then
        local baseLevel = parent:GetFrameLevel()
        visual.frame:SetFrameLevel(ClampFrameLevel(baseLevel + (item.zOffset or 0)))
        if visual.border and visual.border.SetFrameLevel then
            visual.border:SetFrameLevel(ClampFrameLevel(visual.frame:GetFrameLevel() + 1))
        end
    end
    visual.frame:Show()

    if item.type == "bar" and visual.bar then
        visual.bar:SetStatusBarTexture(Addon:GetCustomIndicatorBarTexturePath(item.barTexture) or BAR_TEXTURES.BLIZZARD.path)
        local dirCfg = Addon:GetCustomIndicatorBarDirectionConfig(item.direction)
        visual.bar:SetOrientation(dirCfg.orientation)
        visual.bar:SetReverseFill(dirCfg.reverseFill)
        local fill
        if previewActive then
            fill = Addon:CustomIndicatorPreviewFill(now)
        else
            fill = Addon:CustomIndicatorComputeFill(now, aura.expirationTime, aura.duration)
        end
        visual.bar:SetStatusBarColor(item.colorR, item.colorG, item.colorB, item.colorA)
        visual.bar:SetValue(fill)

        if visual.border and visual.border.SetBackdrop then
            local borderSpec = Addon:GetCustomIndicatorBarBorderSpec(item.barBorder)
            if borderSpec and borderSpec.path and borderSpec.path ~= "" then
                local edgeSize = item.borderSize or borderSpec.edgeSize or 8
                local padding = item.borderPadding or 0
                local total = edgeSize + padding
                if total < 0 then total = 0 end
                visual.border:SetPoint("TOPLEFT", -total, total)
                visual.border:SetPoint("BOTTOMRIGHT", total, -total)
                visual.border:SetBackdrop({
                    edgeFile = borderSpec.path,
                    edgeSize = edgeSize,
                })
                visual.border:SetBackdropBorderColor(item.borderColorR, item.borderColorG, item.borderColorB, item.borderColorA)
                visual.border:Show()
            else
                visual.border:SetBackdrop(nil)
                visual.border:Hide()
            end
        end
    elseif item.type == "spell-icon" and visual.texture then
        local icon = aura.icon or (GetSpellTexture and GetSpellTexture(item.spellId))
        if icon then
            visual.texture:SetTexture(icon)
        end
        if visual.border then
            visual.border:SetBackdrop(nil)
            visual.border:Hide()
        end
        ApplyCooldown(visual, item, aura)
    elseif item.type == "square" and visual.texture then
        visual.texture:SetColorTexture(item.colorR, item.colorG, item.colorB, item.colorA)
        if visual.border and visual.border.SetBackdrop then
            local borderSpec = Addon:GetCustomIndicatorBarBorderSpec(item.barBorder)
            if borderSpec and borderSpec.path and borderSpec.path ~= "" then
                local edgeSize = item.borderSize or borderSpec.edgeSize or 8
                local padding = item.borderPadding or 0
                local total = edgeSize + padding
                if total < 0 then total = 0 end
                visual.border:SetPoint("TOPLEFT", -total, total)
                visual.border:SetPoint("BOTTOMRIGHT", total, -total)
                visual.border:SetBackdrop({
                    edgeFile = borderSpec.path,
                    edgeSize = edgeSize,
                })
                visual.border:SetBackdropBorderColor(item.borderColorR, item.borderColorG, item.borderColorB, item.borderColorA)
                visual.border:Show()
            else
                visual.border:SetBackdrop(nil)
                visual.border:Hide()
            end
        end
        ApplyCooldown(visual, item, aura)
    end

    local timed = (previewActive and true) or (aura.duration and aura.duration > 0 and aura.expirationTime and aura.expirationTime > 0)
    return true, timed and true or false
end

local function HideStaleVisuals(frame, activeIds)
    if not frame.BRFCustomIndicators then return end
    for id, data in pairs(frame.BRFCustomIndicators) do
        if not activeIds[id] then
            HideVisual(data)
        end
    end
end

function Addon:UpdateCustomIndicators(frame)
    if not self:IsRaidOrPartyFrame(frame) then return false end

    local cfg = self:GetCustomIndicatorsConfig()
    local allowPreview = self:IsConfigOpen() and runtime.previewId ~= nil
    if not cfg.enabled and not allowPreview then
        if frame.BRFCustomIndicators then
            for _, data in pairs(frame.BRFCustomIndicators) do
                HideVisual(data)
            end
        end
        return false
    end

    local hasTimed = false
    local activeIds = {}

    for _, item in ipairs(cfg.items) do
        activeIds[item.id] = true
        local visible, timed = UpdateIndicatorVisual(frame, item)
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
    Addon:ForEachFrame(function(frame)
        if Addon:UpdateCustomIndicators(frame) then
            needsTicker = true
        end
    end)

    if needsTicker and not runtime.ticker and C_Timer and C_Timer.NewTicker then
        runtime.ticker = C_Timer.NewTicker(TICKER_INTERVAL, function()
            RefreshTickerState()
        end)
    elseif not needsTicker and runtime.ticker then
        runtime.ticker:Cancel()
        runtime.ticker = nil
    end
end

function Addon:RefreshCustomIndicators()
    RefreshTickerState()
end

function Addon:HookCustomIndicators()
    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        Addon:UpdateCustomIndicators(frame)
    end)

    if CompactUnitFrame_UpdateAuras then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            if not Addon:IsRaidOrPartyFrame(frame) then return end
            Addon:UpdateCustomIndicators(frame)
        end)
    end

    hooksecurefunc("CompactUnitFrame_UpdateHealth", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        Addon:UpdateCustomIndicators(frame)
    end)
end
