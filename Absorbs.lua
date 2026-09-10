local _, Addon = ...
local UnitHealthMax = UnitHealthMax
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local nativeAlpha = setmetatable({}, { __mode = "k" })
local hooked = false

Addon.AbsorbTextureOptions = {
    { value = "SHIELDS", label = "Shields", atlas = "RaidFrame-Shield-Overlay", tiled = true },
    { value = "FLAT", label = "Blizzard Flat", texture = "Interface\\Buttons\\WHITE8X8" },
    { value = "RAID", label = "Blizzard Raid", texture = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { value = "DEFAULT", label = "Default", texture = 7539072 },
    { value = "SMOOTH", label = "Smooth", texture = 137012 },
    { value = "LUNAR", label = "Lunar", atlas = "_Druid-LunarBar" },
    { value = "TORGHAST", label = "Torghast", atlas = "jailerstower-scorebar-fill-normal" },
    { value = "INSANITY", label = "Insanity", atlas = "_Priest-InsanityBar" },
    { value = "EMPOWER", label = "Empower", atlas = "ui-castingbar-disabled-tier4-empower" },
}
local textures = {}
for _, option in ipairs(Addon.AbsorbTextureOptions) do textures[option.value] = option end

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function Accessible(object)
    if not object then return false end
    local allowed = object:CanBeAccessedInContext()
    return not Secret(allowed) and allowed
end

local function Number(value)
    return not Secret(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function Opacity(value, fallback)
    return math.max(0, math.min(100, Number(value) and value or fallback)) / 100
end

local function StyleNativeRegion(region, opacity)
    if not region then return end
    local state = nativeAlpha[region]
    if opacity == 1 and not state then return end
    if not Accessible(region) then return end
    if not state then
        local alpha = region:GetAlpha()
        if not Number(alpha) then return end
        state = { original = alpha }
        nativeAlpha[region] = state
    end
    local alpha = state.original * opacity
    if state.applied ~= alpha then
        region:SetAlpha(alpha)
        state.applied = alpha
    end
    if opacity == 1 then nativeAlpha[region] = nil end
end

local function StyleNative(frame, settings)
    local opacity = settings.showAbsorbs ~= false and Opacity(settings.absorbOpacity, 100) or 0
    -- Leave native visibility, prediction math, textures, and heal absorbs alone.
    StyleNativeRegion(frame.totalAbsorb, opacity)
    StyleNativeRegion(frame.totalAbsorbOverlay, opacity)
    StyleNativeRegion(frame.overAbsorbGlow, opacity)
    StyleNativeRegion(frame.TotalAbsorbLeftShadow, opacity)
end

local function HideOvershield(frame)
    local bar = frame.BRFOvershield
    if bar and Accessible(bar) and bar.BRFEnabled then
        bar:Hide()
        bar.BRFEnabled = false
    end
end

local function GetOvershield(frame, settings)
    if not settings.showOvershields then HideOvershield(frame); return end
    local health = frame.healthBar
    if not Accessible(health) then HideOvershield(frame); return end
    local fill = health:GetStatusBarTexture()
    if not Accessible(fill) then HideOvershield(frame); return end
    local level = health:GetFrameLevel()
    if not Number(level) then HideOvershield(frame); return end

    local bar = frame.BRFOvershield
    if not bar then
        bar = CreateFrame("StatusBar", nil, frame)
        bar:EnableMouse(false)
        bar:SetReverseFill(true)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar.BRFTexture = bar:GetStatusBarTexture()
        bar.BRFTexture:SetDrawLayer("BORDER")
        bar.BRFMask = bar:CreateMaskTexture()
        bar.BRFMask:SetTexture("Interface\\TargetingFrame\\UI-StatusBar", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        bar.BRFTexture:AddMaskTexture(bar.BRFMask)
        frame.BRFOvershield = bar
    end
    if not Accessible(bar) or not Accessible(bar.BRFTexture) or not Accessible(bar.BRFMask) then
        HideOvershield(frame)
        return
    end
    if bar.BRFHealth ~= health then
        bar:SetAllPoints(health)
        bar.BRFHealth = health
    end
    if bar.BRFHealthFill ~= fill then
        -- Clipping the reverse fill to current health reveals just overflow.
        -- The renderer handles secret geometry; Lua never reads its dimensions.
        bar.BRFMask:SetAllPoints(fill)
        bar.BRFHealthFill = fill
    end
    if bar.BRFLevel ~= level then bar:SetFrameLevel(level); bar.BRFLevel = level end
    local choice = textures[settings.overshieldTexture] or textures.SHIELDS
    if bar.BRFChoice ~= choice then
        if choice.atlas then
            local wrap = choice.tiled and "REPEAT" or "CLAMP"
            bar.BRFTexture:SetAtlas(choice.atlas, false, nil, true, wrap, wrap)
        else
            bar:SetStatusBarTexture(choice.texture)
            bar.BRFTexture:SetTexCoord(0, 1, 0, 1)
        end
        -- Keep the shield pattern at its native detail instead of stretching
        -- the old low-resolution shield graphic over the entire health bar.
        bar.BRFTexture:SetHorizTile(choice.tiled == true)
        bar.BRFTexture:SetVertTile(choice.tiled == true)
        bar.BRFChoice = choice
    end
    local opacity = Opacity(settings.overshieldOpacity, 80)
    if bar.BRFOpacity ~= opacity then bar:SetAlpha(opacity); bar.BRFOpacity = opacity end
    if not bar.BRFEnabled then bar:Show(); bar.BRFEnabled = true end
    return bar
end

function Addon:UpdateAbsorbs(frame, settings)
    if not Accessible(frame) then return end
    settings = settings or self:GetSettings()
    StyleNative(frame, settings)
    if not settings.showOvershields then HideOvershield(frame); return end
    local visible = frame:IsVisible()
    if Secret(visible) or not visible then HideOvershield(frame); return end
    local unit = frame.displayedUnit
    if Secret(unit) then HideOvershield(frame); return end
    unit = unit or frame.unit
    if Secret(unit) or not unit then HideOvershield(frame); return end
    local exists = UnitExists(unit)
    if Secret(exists) or not exists then HideOvershield(frame); return end
    local bar = GetOvershield(frame, settings)
    if bar then
        -- Pass these directly to secret-capable native APIs, without branching
        -- on, comparing, or performing arithmetic on health/absorb amounts.
        bar:SetMinMaxValues(0, UnitHealthMax(unit))
        bar:SetValue(UnitGetTotalAbsorbs(unit))
    end
end

function Addon:UpdateAbsorbPreview(frame, settings, amount)
    StyleNative(frame, settings)
    local bar = GetOvershield(frame, settings)
    if bar then bar:SetMinMaxValues(0, 100); bar:SetValue(amount) end
end

function Addon:HookAbsorbs()
    if hooked then return end
    hooked = true
    hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
        if not Accessible(frame) or Secret(frame.unit) or not Addon:IsRaidOrPartyFrame(frame) then return end
        Addon:UpdateAbsorbs(frame)
    end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    events:SetScript("OnEvent", function() Addon:RequestFeatureUpdate("absorbs") end)
end
