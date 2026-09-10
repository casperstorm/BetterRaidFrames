local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
assert(loadfile("Utils.lua"))("BetterRaidFrames", Addon)

env.playerName = "Александр-Realm"
env.classColor = { r = 0.2, g = 0.4, b = 0.8 }
local settings = env.settings
settings.customizeNames = true
settings.nameAnchor, settings.nameOffsetX, settings.nameOffsetY = "BOTTOMRIGHT", -4, 5
settings.nameSize, settings.nameTextOutline = 14, "THICKOUTLINE"
settings.nameClassColor, settings.nameHideServer = true, true
settings.nameCyrillicToLatin, settings.nameTruncate, settings.nameTruncateLength = true, true, 6
settings.nameTextShadow, settings.nameTextShadowOffset = true, 2
settings.nameTextShadowColorR, settings.nameTextShadowColorG, settings.nameTextShadowColorB = .1, .2, .3

local parent = env.frame()
parent:SetSize(676, 634)
local preview = Addon:CreateDesignerPreview(parent)
local set = Addon:NormalizeIndicatorSet({})
preview:Refresh(set, nil, {})
assert(preview.name:GetText() == "Aleks…" and env.lastNameUnit == "player")
assert(preview.unit == nil, "preview naming must not require binding a unit frame")

local row = Addon:CreateFramePreviewRow(parent, 3, 120, { "Tank", "Healer", "Damage" })
for _, sample in ipairs(row.samples) do
    sample.healthBar = CreateFrame("StatusBar", nil, sample)
    sample.healthBar:SetFrameLevel(sample:GetFrameLevel() + 3)
end
row:RefreshSize()
local function CheckName(sample)
    local name = sample.name
    assert(name:GetText() == preview.name:GetText(), "all samples use the same player name formatting")
    assert(name.point[1] == "BOTTOMRIGHT" and name.point[2] == sample and name.point[3] == "BOTTOMRIGHT")
    assert(name.point[4] == -4 and name.point[5] == 5 and name.justifyH == "RIGHT")
    assert(name.fontSize == 14 and name.fontFlags == "THICKOUTLINE")
    assert(name.textColor[1] == .2 and name.textColor[2] == .4 and name.textColor[3] == .8)
    assert(name.shadowColor[1] == .1 and name.shadowOffset[1] == 2 and name.shadowOffset[2] == -2)
    assert(name:GetEffectiveScale() == sample:GetEffectiveScale())
    if sample.healthBar then
        assert(name:GetParent():GetFrameLevel() > sample.healthBar:GetFrameLevel(), "shield artwork stays below the name")
    end
end
CheckName(preview)
for _, sample in ipairs(row.samples) do CheckName(sample) end

-- The native path uses exactly the same formatter and style helpers.
local live = env.frame("party1")
live.name = live:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
Addon:UpdateName(live, settings)
assert(live.name:GetText() == preview.name:GetText() and live.name.fontFlags == preview.name.fontFlags)
assert(live.name.fontSize == preview.name.fontSize and live.name.justifyH == preview.name.justifyH)

settings.nameHideOnDead, env.dead = true, true
row:RefreshSize()
for _, sample in ipairs(row.samples) do assert(not sample.name:IsShown()) end
env.dead = false
settings.nameHideOnOffline, env.offline = true, true
row:RefreshSize()
for _, sample in ipairs(row.samples) do assert(not sample.name:IsShown()) end
env.offline = false
row:RefreshSize()
for _, sample in ipairs(row.samples) do assert(sample.name:IsShown()) end

function CompactUnitFrame_UpdateName() error("native name updater must never run on a preview") end
function CompactUnitFrame_UpdateStatusText() error("native status updater must never run on a preview") end
local allocated = #env.widgets
local original = row.samples[1].name
for _ = 1, 25 do
    settings.customizeNames = false
    row:RefreshSize()
    for _, sample in ipairs(row.samples) do
        local name = sample.name
        assert(name:GetText() == env.playerName and name:IsShown())
        assert(name.fontSize == 11 and name.fontFlags == "" and name.justifyH == "LEFT")
        assert(name.point[1] == "TOPLEFT" and name.point[4] == 3 and name.point[5] == -3)
        assert(name.textColor[1] == 1 and name.shadowOffset[1] == 1)
    end
    settings.customizeNames = true
    row:RefreshSize()
    for _, sample in ipairs(row.samples) do CheckName(sample) end
end
assert(#env.widgets == allocated and row.samples[1].name == original, "profile/style changes reuse the name and foreground")
row:Hide()
env.playerName = "Changed"
row:RefreshSize()
assert(row.samples[1].name:GetText() == "Aleks…" and not row.scripts.OnUpdate, "hidden previews do no name work")

print("PASS: frame_preview_name_test (player name, shared styling, foreground, defaults, visibility, reuse)")
