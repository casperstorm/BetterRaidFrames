local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertEqual failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual), 2)
    end
end

local Addon = {}
assert(loadfile("CustomIndicators.lua"))("BetterRaidFrames", Addon)

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

print("PASS: custom_indicators_invert_swipe_test")
