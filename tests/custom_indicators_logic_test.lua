local addon = {}
GetSpellInfo = nil
GetSpellTexture = nil
C_Spell = {
    GetSpellInfo = function(id)
        if id == 53563 then return { name = "Beacon of Light", iconID = 53563 } end
        if id == 17 then return { name = "Power Word: Shield", iconID = 17 } end
        if id == 774 then return { name = "Rejuvenation", iconID = 774 } end
        return nil
    end,
    GetSpellTexture = function(id)
        return id
    end,
}
local chunk = assert(loadfile("CustomIndicators.lua"))
chunk("BetterRaidFrames", addon)

addon.GetSetting = function(_, key)
    return nil
end
addon.SetSetting = function(_, key, value)
end

local catalog = addon:GetCustomIndicatorSpellCatalog()
assert(type(catalog) == "table" and #catalog > 0, "spell catalog must be non-empty")

local options = addon:GetCustomIndicatorSpellOptions()
assert(type(options) == "table" and #options > 1, "spell options must include None + spells")
assert(options[1].value == 0, "first option must be None")
local iconResolved = false
for _, option in ipairs(options) do
    if option.value == 17 then
        assert(option.label:match("^|T17:14:14:0:0|t"), "spell option should use C_Spell icon for known spell")
        iconResolved = true
        break
    end
end
assert(iconResolved, "expected known spell option in list")

for i = 3, #options do
    local prev = options[i - 1].label:gsub("^|T.-|t%s*", "")
    local curr = options[i].label:gsub("^|T.-|t%s*", "")
    prev = prev:match("^(.*) %(%d+%)$") or prev
    curr = curr:match("^(.*) %(%d+%)$") or curr
    prev = string.lower(prev)
    curr = string.lower(curr)
    assert(prev <= curr, "spell options should be sorted by spell name")
end

local fill = addon:CustomIndicatorComputeFill(100, 110, 20)
assert(fill == 0.5, "expected fill to be 0.5")

local zeroDurationFill = addon:CustomIndicatorComputeFill(100, 110, 0)
assert(zeroDurationFill == 1, "zero duration should be full bar")

addon:SetCustomIndicatorPreviewId("ci_test")
assert(addon:IsCustomIndicatorPreviewActive("ci_test") == true, "selected preview id should be active")
assert(addon:IsCustomIndicatorPreviewActive("ci_other") == false, "other preview ids should not be active")

local previewFill = addon:CustomIndicatorPreviewFill(2.5)
assert(previewFill >= 0 and previewFill <= 1, "preview fill must be clamped")

local defaults = addon:GetDefaultCustomIndicators()
assert(defaults.previewEnabled == true, "preview should default to enabled")
assert(defaults.defaultZOffset == 0, "default z offset should be 0")

local normalized = addon:NormalizeCustomIndicatorsConfig({
    enabled = true,
    nextId = 1,
    items = {
        { id = "ci_a", type = "bar", spellId = 774, direction = "invalid", zOffset = 999 },
    },
})
assert(normalized.items[1].direction == "RIGHT_TO_LEFT", "bar direction should normalize to default")
assert(normalized.items[1].zOffset == 30, "z offset should clamp to max")

local dirCfg = addon:GetCustomIndicatorBarDirectionConfig("LEFT_TO_RIGHT")
assert(dirCfg.orientation == "HORIZONTAL" and dirCfg.reverseFill == false, "left-to-right should be horizontal and non-reverse")

local textureOptions = addon:GetCustomIndicatorBarTextureOptions()
assert(type(textureOptions) == "table" and #textureOptions >= 2, "bar texture options should exist")
assert(textureOptions[1].value ~= nil, "bar texture option needs value")

local borderOptions = addon:GetCustomIndicatorBarBorderOptions()
assert(type(borderOptions) == "table" and #borderOptions >= 1, "bar border options should exist")
assert(borderOptions[1].value ~= nil, "bar border option needs value")

assert(addon:CustomIndicatorTypeSupportsBorder("bar") == true, "bar should support border")
assert(addon:CustomIndicatorTypeSupportsBorder("square") == true, "square should support border")
assert(addon:CustomIndicatorTypeSupportsBorder("spell-icon") == false, "spell icon should not support border")

local normalizedTexture = addon:NormalizeCustomIndicatorsConfig({
    enabled = true,
    nextId = 1,
    items = {
        { id = "ci_tex", type = "bar", spellId = 774, showCooldownSwipe = false, showCooldownText = false, borderPadding = 99, borderSize = 99, barTexture = "INVALID_TEXTURE_KEY", barBorder = "INVALID_BORDER_KEY" },
        { id = "ci_tex2", type = "bar", spellId = 17, borderPadding = -99, borderSize = 1, barTexture = "BLIZZARD", barBorder = "NONE" },
    },
})
assert(normalizedTexture.items[1].barTexture == "BLIZZARD", "invalid texture key should normalize to default")
assert(normalizedTexture.items[1].barBorder == "NONE", "invalid border key should normalize to none")
assert(normalizedTexture.items[1].borderSize == 24, "border size should clamp to max")
assert(normalizedTexture.items[1].borderPadding == 20, "border padding should clamp to max")
assert(normalizedTexture.items[2].borderPadding == -20, "border padding should clamp to min")
assert(normalizedTexture.items[1].showCooldownSwipe == false, "showCooldownSwipe false should persist")
assert(normalizedTexture.items[1].showCooldownText == false, "showCooldownText false should persist")
