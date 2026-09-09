local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
local a = assert(Addon:AddDesignerIndicator("default", "Echo", "SQUARE", "BOTTOMRIGHT"))
local b = assert(Addon:AddDesignerIndicator("default", "Echo", "ICON", "BOTTOMRIGHT"))
assert(a ~= b and #Addon:GetIndicatorSet().items == 2, "the same spell can have distinct indicators")
assert(not Addon:AddDesignerIndicator("default", "invalid", "ICON"))
assert(not Addon:FindDesignerIndicator("default", a).glow, "new and existing indicators default to no glow")
assert(not Addon:FindDesignerIndicator("default", a).glowPulse, "existing glows remain steady")
Addon:ChangeDesignerIndicator("default", a, { size = 16, text = "STACKS", glow = true, glowPulse = true })
assert(not Addon:FindDesignerIndicator("default", b).glow, "glow belongs to an individual indicator")
assert(Addon:GetIndicatorSet().groups.BOTTOMRIGHT.offsetX == 0 and Addon:GetIndicatorSet().groups.BOTTOMRIGHT.offsetY == 0,
    "existing groups must keep their position")
assert(Addon:GetIndicatorSet().groups.BOTTOMRIGHT.offsetZ == 0, "existing groups keep their layer")
Addon:ChangeDesignerGroup("default", "BOTTOMRIGHT", { grow = "UP", spacing = 6, offsetX = 12, offsetY = -8, offsetZ = 240 })
assert(Addon:GetIndicatorSet().groups.BOTTOMRIGHT.grow == "UP")
assert(Addon:GetIndicatorSet().groups.TOPRIGHT.spacing == 3)
Addon:MoveDesignerIndicator("default", a, 1)
assert(Addon:GetIndicatorSet().items[2].id == a)
local copy = assert(Addon:DuplicateDesignerIndicator("default", a))
assert(copy ~= a)
assert(Addon:FindDesignerIndicator("default", copy).glow, "copies retain their glow setting")
assert(Addon:FindDesignerIndicator("default", copy).glowPulse, "copies retain the pulse option")
Addon:ChangeDesignerIndicator("default", copy, { color = { r = 1, g = 0, b = 0, a = .5 } })
assert(Addon:FindDesignerIndicator("default", a).color.r == .4, "copies must not share colours")
Addon:ChangeDesignerIndicator("default", b, { anchor = "TOPLEFT" })
Addon:ChangeDesignerIndicator("default", b, { anchor = "BOTTOMRIGHT" })
assert(Addon:GetIndicatorSet().items[3].id == b, "joining another anchor appends to its order")

local unchangedDefault = Addon:GetIndicatorSet("default")
Addon:ChangeDesignerIndicator("1468", a, { size = 28 })
assert(Addon:GetIndicatorSet("default") == unchangedDefault, "editing one specialization must not copy untouched sets")
Addon:ChangeDesignerGroup("1468", "BOTTOMRIGHT", { offsetX = -24, offsetY = 18, offsetZ = -6 })
assert(Addon:GetIndicatorSet().groups.BOTTOMRIGHT.offsetZ == -6)
assert(Addon:GetIndicatorSet("default").groups.BOTTOMRIGHT.offsetZ == 240, "specialization layers must be independent")
assert(Addon:GetIndicatorSet().items[1].size == 28, "active specialization uses its override")
assert(Addon:GetIndicatorSet("default").items[1].size == 16, "editing a specialization must preserve Default")
assert(Addon:GetIndicatorSet("default").groups.BOTTOMRIGHT.offsetX == 12
    and Addon:GetIndicatorSet("default").groups.BOTTOMRIGHT.offsetY == -8, "specialization offsets must be independent")
env.spec = 105
assert(Addon:GetIndicatorSet() == Addon:GetIndicatorSet("default"), "other specs fall back to Default")
env.spec = 1468
Addon:UseDefaultIndicators("1468")
assert(Addon:GetIndicatorSet() == Addon:GetIndicatorSet("default"))
assert(Addon:GetIndicatorSet("default") == unchangedDefault, "removing an override must not copy Default")
Addon:SaveIndicatorSet("1468", {})
assert(#Addon:GetIndicatorSet().items == 0, "an empty override must suppress the default set")

local malformed = Addon:NormalizeIndicatorSet({ items = {
    { id = 1, spellID = 364343, size = 0/0, textScale = math.huge, color = false, anchor = "oops" },
    { id = 1, spellID = 366155, size = 999, text = "invalid", glow = "true", glowPulse = "true" },
    { spellID = "bad" }, false,
}, groups = {
    BOTTOMRIGHT = { grow = "RIGHT", spacing = -100, offsetX = math.huge, offsetY = 0/0, offsetZ = math.huge },
    TOPLEFT = { offsetX = -999, offsetY = 999, offsetZ = -999 },
    TOPRIGHT = { offsetZ = 999 },
    CENTER = { offsetZ = 4.7 },
} })
assert(#malformed.items == 2 and malformed.items[1].id ~= malformed.items[2].id)
assert(malformed.items[1].size == 20 and malformed.items[2].size == 50)
assert(not malformed.items[1].glow and not malformed.items[2].glow, "only an explicit boolean enables glow")
assert(not malformed.items[1].glowPulse and not malformed.items[2].glowPulse, "only an explicit boolean enables pulsing")
assert(malformed.items[1].textScale == 1 and malformed.items[1].anchor == "BOTTOMRIGHT")
assert(malformed.groups.BOTTOMRIGHT.grow == "LEFT" and malformed.groups.BOTTOMRIGHT.spacing == 0)
assert(malformed.groups.BOTTOMRIGHT.offsetX == 0 and malformed.groups.BOTTOMRIGHT.offsetY == 0)
assert(malformed.groups.TOPLEFT.offsetX == -250 and malformed.groups.TOPLEFT.offsetY == 250)
assert(malformed.groups.BOTTOMRIGHT.offsetZ == 0 and malformed.groups.TOPLEFT.offsetZ == -100
    and malformed.groups.TOPRIGHT.offsetZ == 500 and malformed.groups.CENTER.offsetZ == 5)
for _, anchor in ipairs(Addon.IndicatorAnchors) do
    for _, growth in ipairs(Addon:GetIndicatorGrowthOptions(anchor.value)) do
        assert(not (growth.value == "LEFT" and anchor.value:find("LEFT")))
        assert(not (growth.value == "DOWN" and anchor.value:find("BOTTOM")))
    end
end

-- The codec fake retains the structured payload while exercising validation,
-- normalization and replacement. Encoding/decoding itself is a Blizzard API.
local encoded
C_EncodingUtil = {
    SerializeJSON = function(payload) encoded = payload; return "json" end,
    DeserializeJSON = function() return encoded end,
    CompressString = function(s) return s end, DecompressString = function(s) return s end,
    EncodeBase64 = function(s) return s end, DecodeBase64 = function(s) return s end,
}
local exported = Addon:ExportDesignerIndicators("default")
local imported = assert(Addon:DecodeDesignerIndicators(exported))
assert(#imported.items == 3 and imported.groups.BOTTOMRIGHT.spacing == 6)
assert(imported.items[1].glow and imported.items[2].glow and not imported.items[3].glow,
    "sharing a set preserves each indicator's glow setting")
assert(imported.items[1].glowPulse and imported.items[2].glowPulse and not imported.items[3].glowPulse,
    "sharing a set preserves each indicator's pulse setting")
assert(imported.groups.BOTTOMRIGHT.offsetX == 12 and imported.groups.BOTTOMRIGHT.offsetY == -8,
    "sharing a set must preserve both group offsets")
assert(imported.groups.BOTTOMRIGHT.offsetZ == 240, "sharing a set must preserve group layers above the old limit")
assert(imported ~= Addon:GetIndicatorSet("default"))
assert(not Addon:DecodeDesignerIndicators("HARF:something"))
encoded.version = 2
assert(not Addon:DecodeDesignerIndicators(exported))
encoded.version = 1
encoded.set.items[2].id = encoded.set.items[1].id
assert(not Addon:DecodeDesignerIndicators(exported), "reject duplicate imported identities")
assert(#Addon:GetIndicatorSet("default").items == 3, "decode must never mutate the profile")
Addon:RemoveDesignerIndicator("default", b)
assert(#Addon:GetIndicatorSet("default").items == 2)
for _ = 3, Addon.MAX_DESIGNER_INDICATORS do assert(Addon:AddDesignerIndicator("default", 774, "SQUARE")) end
assert(not Addon:AddDesignerIndicator("default", 774, "SQUARE"))
Addon:SaveIndicatorSet("default", { nextId = 2147483647, items = { { id = 1, spellID = 774 } } })
local lastId = assert(Addon:AddDesignerIndicator("default", 774, "SQUARE"))
local wrappedId = assert(Addon:AddDesignerIndicator("default", 774, "SQUARE"))
assert(lastId == 2147483647 and wrappedId ~= lastId and wrappedId ~= 1)
assert(Addon:FindDesignerIndicator("default", wrappedId), "allocated IDs must survive normalization")
print("designer settings tests passed")
