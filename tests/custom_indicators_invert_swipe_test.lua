local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertEqual failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual), 2)
    end
end

local Addon = {}
assert(loadfile("CustomIndicators.lua"))("BetterRaidFrames", Addon)

local settings = {
    customIndicators = {
        enabled = true,
        nextId = 3,
        items = {},
    },
}

function Addon:GetSetting(key)
    return settings[key]
end

function Addon:SetSetting(key, value)
    settings[key] = value
end

local normalized = Addon:NormalizeCustomIndicatorsConfig({
    enabled = true,
    nextId = 3,
    items = {
        { id = "ci_1", type = "spell-icon", spellId = 17, invertCooldownSwipe = true },
        { id = "ci_2", type = "square", spellId = 17 },
    },
})

assertEqual(normalized.items[1].invertCooldownSwipe, true, "invertCooldownSwipe should preserve true")
assertEqual(normalized.items[2].invertCooldownSwipe, false, "invertCooldownSwipe should default false")

assertEqual(type(Addon.CustomIndicatorShouldReverseCooldown), "function", "reverse helper should exist")
assertEqual(Addon:CustomIndicatorShouldReverseCooldown({ invertCooldownSwipe = true }), true,
    "reverse helper should return true")
assertEqual(Addon:CustomIndicatorShouldReverseCooldown({ invertCooldownSwipe = false }), false,
    "reverse helper should return false")

assertEqual(type(Addon.SetCustomIndicatorPreviewAll), "function", "preview-all setter should exist")
assertEqual(type(Addon.IsCustomIndicatorPreviewAll), "function", "preview-all getter should exist")
Addon:SetCustomIndicatorPreviewAll(true)
assertEqual(Addon:IsCustomIndicatorPreviewAll(), true, "preview-all should turn on")
Addon:SetCustomIndicatorPreviewAll(false)
assertEqual(Addon:IsCustomIndicatorPreviewAll(), false, "preview-all should turn off")

assertEqual(type(Addon.CustomIndicatorIsPlayerAura), "function", "player aura helper should exist")
assertEqual(Addon:CustomIndicatorIsPlayerAura("player"), true, "player auras should be accepted")
assertEqual(Addon:CustomIndicatorIsPlayerAura("party1"), false, "other units should be rejected")
assertEqual(Addon:CustomIndicatorIsPlayerAura(nil, { sourceUnit = "player" }), true,
    "sourceUnit player should be accepted")
assertEqual(Addon:CustomIndicatorIsPlayerAura(nil, { sourceUnit = "party1" }), false,
    "sourceUnit non-player should be rejected")
assertEqual(Addon:CustomIndicatorIsPlayerAura(nil, { isFromPlayerOrPlayerPet = true }), true,
    "player-owned aura flags should be accepted")
assertEqual(Addon:CustomIndicatorIsPlayerAura(nil, {}), false,
    "auras without ownership metadata should be rejected")

local cachedA = Addon:GetCustomIndicatorsConfig()
local cachedB = Addon:GetCustomIndicatorsConfig()
assertEqual(cachedA, cachedB, "config reads should reuse cached normalized table")

Addon:SetCustomIndicatorsConfig({
    enabled = true,
    nextId = 9,
    items = {},
})

local cachedC = Addon:GetCustomIndicatorsConfig()
local cachedD = Addon:GetCustomIndicatorsConfig()
assertEqual(cachedC, cachedD, "config cache should stay stable after writes")
assertEqual(cachedC.nextId, 9, "written config should remain normalized")

print("PASS: custom_indicators_invert_swipe_test")
