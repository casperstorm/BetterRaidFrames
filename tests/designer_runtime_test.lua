local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
local function Glow(button)
    for _, w in ipairs(env.widgets) do
        if w.texture == "Interface\\SpellActivationOverlay\\IconAlert" and w.parent.parent == button then return w end
    end
end
-- Model rendered visibility from the fake's frame tree. This deliberately
-- stays on the test's secure side; the addon must not query forbidden frames.
local function Visible(region)
    return region.shown and (not region.parent or Visible(region.parent))
end
local frame = env.frame("party1")
Addon:UpdateDesignerIndicators(frame)
assert(#env.containers == 0, "empty sets allocate nothing")
local a = Addon:AddDesignerIndicator("default", 364343, "SQUARE", "BOTTOMRIGHT")
local b = Addon:AddDesignerIndicator("default", 366155, "ICON", "BOTTOMRIGHT")
local c = Addon:AddDesignerIndicator("default", 774, "SQUARE", "BOTTOMRIGHT")
Addon:ChangeDesignerIndicator("default", a, { size = 16, text = "STACKS", cooldown = true, glow = true, glowPulse = true })
Addon:ChangeDesignerIndicator("default", b, { size = 24, text = "DURATION", mineOnly = false, glow = true, glowPulse = true })
Addon:ChangeDesignerIndicator("default", c, { size = 12 })
Addon:UpdateDesignerIndicators(frame)
local container = env.containers[1]
assert(#env.containers == 1 and #container.groups == 3)
assert(container.point[1] == "BOTTOMRIGHT" and container.point[4] == -2 and container.point[5] == 2)
assert(container.unit == "party1" and container.enabled)
assert(container:GetFrameLevel() == frame:GetFrameLevel() + 10, "zero Z preserves the original layer")
local square, icon, third = container.groups[1], container.groups[2], container.groups[3]
assert(#square.frames == 10 and square.max == 1)
assert(square.filters.includeSpellIDs[364343] and square.filter == "PLAYER|HELPFUL",
    "Mine uses the native PLAYER aura filter")
assert(icon.filter == "HELPFUL")
env.ShowAuras(container, { [364343] = "other", [366155] = "other" })
assert(not square.frames[1].shown, "Mine hides the same buff cast by another player")
assert(icon.frames[1].shown, "Any caster shows another player's buff")
for _, button in ipairs(icon.frames) do
    assert(button.bindings.Icon and button.bindings.DurationCooldown and button.bindings.DurationText)
    assert(button.width == 24)
    assert(Glow(button).shown and Glow(button).width == 24 * 1.4, "every preallocated button needs the glow style")
    assert(Glow(button).animationGroup.playing, "every preallocated button needs the pulse style")
    assert(not button.animationGroup and not button.bindings.DurationText.element.animationGroup,
        "pulsing must not fade the icon or text")
end
assert(not Glow(third.frames[1]), "disabled glows allocate no textures or animations")
assert(square.frames[1].bindings.ApplicationCount)
assert(square.frames[1].bindings.ApplicationCount.element.parent.kind == "Frame",
    "permanent-aura text must not depend on a timed cooldown being shown")
env.ShowAuras(container, { [364343] = true, [366155] = true, [774] = true })
assert(Visible(Glow(square.frames[1])) and Visible(Glow(icon.frames[1])))
local cooldown = env.find(function(w) return w.kind == "Cooldown" and w.parent == square.frames[1] end)
cooldown:Hide()
assert(Visible(Glow(square.frames[1])), "a permanent buff keeps its glow when its cooldown is hidden")
assert(container.width == 58 and icon.frames[1].point[4] == -19)
assert(third.frames[1].point[4] == -46)
Addon:ChangeDesignerGroup("default", "BOTTOMRIGHT", { offsetX = 12, offsetY = -8 })
Addon:UpdateDesignerIndicators(frame)
env.ShowAuras(container, { [364343] = true, [366155] = true, [774] = true })
assert(container.point[4] == 10 and container.point[5] == -6, "offsets move the whole group relative to its inset")
assert(container.width == 58 and third.frames[1].point[4] == -46, "group movement must preserve internal spacing")

-- Blizzard moves only active frames, including during restrictions. The addon
-- makes no callbacks or visibility reads when the first/middle/last aura leaves.
env.restricted = true
env.ShowAuras(container, { [366155] = true, [774] = true })
assert(not Visible(Glow(square.frames[1])) and Visible(Glow(icon.frames[1])), "glow follows aura removal in combat")
assert(container.width == 39 and icon.frames[1].point[4] == 0)
env.ShowAuras(container, { [364343] = true, [774] = true })
assert(Visible(Glow(square.frames[1])) and not Visible(Glow(icon.frames[1])), "glow returns when the buff returns")
assert(container.width == 31 and third.frames[1].point[4] == -19)
assert(container.point[4] == 10 and container.point[5] == -6, "closing gaps must retain the group offset")
env.ShowAuras(container, {})
assert(not Visible(Glow(square.frames[1])) and not Visible(Glow(icon.frames[1])))
assert(container.width == 1 and container.height == 1)
frame.unit = "party2"
Addon:UpdateDesignerIndicators(frame)
assert(container.unit == "party2" and container.enabled)

Addon:ChangeDesignerIndicator("default", b, { type = "SQUARE", text = "STACKS", size = 18, glow = false })
Addon:ChangeDesignerGroup("default", "BOTTOMRIGHT", { offsetX = -4, offsetY = 6 })
Addon:UpdateDesignerIndicators(frame)
assert(not container.enabled and Addon:HasPendingDesignerIndicators(), "hide an obsolete style until it can be applied")
assert(icon.frames[1].width == 24)
env.restricted = false
Addon:UpdateDesignerIndicators(frame)
assert(container.enabled and not Addon:HasPendingDesignerIndicators())
assert(container.point[4] == -6 and container.point[5] == 8, "deferred settings must apply group offsets too")
for _, button in ipairs(icon.frames) do
    assert(button.width == 18 and not button.bindings.Icon and not button.bindings.DurationText and button.bindings.ApplicationCount)
    assert(not Glow(button).shown, "deferred changes clear glow from every pooled button")
    assert(not Glow(button).animationGroup.playing and Glow(button).alpha == 1,
        "disabling glow stops the pulse and restores opacity on every pooled button")
end
Addon:ChangeDesignerGroup("default", "BOTTOMRIGHT", { grow = "UP", spacing = 6 })
Addon:MoveDesignerIndicator("default", c, -1)
Addon:UpdateDesignerIndicators(frame)
env.ShowAuras(container, { [364343] = true, [366155] = true, [774] = true })
assert(container.height == 58 and container.width == 18)
assert(container.byKey["2:mine"].filters.includeSpellIDs[774])
assert(next(container.byKey["2"].filters.includeSpellIDs) == nil, "the old caster filter group is emptied")
assert(not (Glow(container.byKey["2:mine"].frames[1]) or {}).shown, "reordering cannot transfer glow to another spell")
assert(container.byKey["2:mine"].frames[1].point[5] == 22)

local allocationCount = #env.widgets
Addon:RemoveDesignerIndicator("default", c)
Addon:UpdateDesignerIndicators(frame)
assert(next(container.byKey["3"].filters.includeSpellIDs) == nil)
local d = Addon:AddDesignerIndicator("default", 774, "ICON", "BOTTOMRIGHT")
Addon:ChangeDesignerIndicator("default", d, { mineOnly = false })
Addon:UpdateDesignerIndicators(frame)
assert(#env.widgets == allocationCount, "removed filter groups and all their visuals are reused")
Addon:ChangeDesignerIndicator("default", d, { showTexture = false, text = "DURATION" })
Addon:UpdateDesignerIndicators(frame)
assert(not container.byKey["3"].frames[1].bindings.Icon and not container.byKey["3"].frames[1].bindings.DurationCooldown)
assert(container.byKey["3"].frames[1].bindings.DurationText)

env.restricted = true
local newFrame = env.frame("raid1")
Addon:UpdateDesignerIndicators(newFrame)
assert(#env.containers == 2 and env.containers[2].enabled, "new frames initialize while restricted")
assert(Glow(env.containers[2].groups[1].frames[1]).shown, "glow initializes on new frames during restrictions")
assert(Glow(env.containers[2].groups[1].frames[1]).animationGroup.playing,
    "pulses initialize during the native safe creation window")
newFrame.unit = "secret"
Addon:UpdateDesignerIndicators(newFrame)
assert(env.containers[2].unit == "none" and not env.containers[2].enabled)
env.spec = 105
Addon:SaveIndicatorSet("105", {})
Addon:UpdateDesignerIndicators(frame)
assert(not container.enabled, "an empty specialization override disables the old set during restrictions")
env.spec = 1468
Addon:UpdateDesignerIndicators(frame)
assert(container.enabled, "returning to identical settings can resume without restyling")
env.restricted = false
Addon:HookDesignerIndicators()
assert(env.hooks.CompactUnitFrame_SetUnit and env.hooks.CompactUnitFrame_UpdateInVehicle)
local eventFrame = env.find(function(w) return w.events and w.events.ADDON_RESTRICTION_STATE_CHANGED end)
eventFrame.scripts.OnEvent()
assert(env.requested == "indicators")

-- The same style is used in preview; removing the selected buff must remove
-- its glow too, and disabling glow must update an already allocated visual.
local sample = Addon:CreateDesignerPreview(env.frame())
local previewSet = Addon:NormalizeIndicatorSet({ items = { { id = 1, spellID = 774, type = "ICON", glow = true, glowPulse = true } } })
sample:Refresh(previewSet, 1, {})
local previewGlow = env.find(function(w)
    return w.texture == "Interface\\SpellActivationOverlay\\IconAlert" and w.parent.parent.parent.parent == sample
end)
assert(Visible(previewGlow))
local previewPulse = previewGlow.animationGroup
assert(previewPulse.playing and previewPulse.looping == "BOUNCE")
assert(previewPulse.animations[1].fromAlpha == 1 and previewPulse.animations[1].toAlpha == 0.35
    and #previewPulse.animations == 1, "one native bouncing animation fades out and returns to full brightness")
sample:Refresh(previewSet, 1, { [1] = true })
assert(not Visible(previewGlow) and not previewPulse.playing, "absent preview buffs must stop their glow")
previewSet.items[1].type, previewSet.items[1].size = "SQUARE", 30
sample:Refresh(previewSet, 1, {})
assert(Visible(previewGlow) and previewGlow.width == 42, "glow follows display and size changes")
assert(previewPulse.playing and previewGlow.animationGroup == previewPulse, "square previews reuse the pulse")
previewSet.items[1].glowPulse = false
sample:Refresh(previewSet, 1, {})
assert(Visible(previewGlow) and not previewPulse.playing and previewGlow.alpha == 1,
    "switching pulse off restores a steady glow")
previewSet.items[1].glowPulse = true
sample:Refresh(previewSet, 1, {})
assert(previewPulse.playing and previewGlow.animationGroup == previewPulse)
previewSet.items[1].glow = false
sample:Refresh(previewSet, 1, {})
assert(not Visible(previewGlow) and not previewPulse.playing)

-- Test every permitted anchor/direction with different element sizes through
-- the same flow configuration the real containers and preview receive.
local function Rectangle(button)
    local point, parent, _, x, y = table.unpack(button.point)
    local ax = point:find("LEFT") and 0 or point:find("RIGHT") and 1 or 0.5
    local ay = point:find("BOTTOM") and 0 or point:find("TOP") and 1 or 0.5
    local left = ax * parent.width + x - ax * button.width
    local bottom = ay * parent.height + y - ay * button.height
    return { left = left, right = left + button.width, bottom = bottom, top = bottom + button.height }
end
for _, anchor in ipairs(Addon.IndicatorAnchors) do
    for _, direction in ipairs(Addon:GetIndicatorGrowthOptions(anchor.value)) do
        local set = Addon:NormalizeIndicatorSet({ items = {
            { id = 1, spellID = 364343, anchor = anchor.value, size = 12 },
            { id = 2, spellID = 366155, anchor = anchor.value, size = 30 },
        }, groups = { [anchor.value] = { grow = direction.value, spacing = 5, offsetX = 7, offsetY = -9 } } })
        local sample = Addon:CreateDesignerPreview(env.frame())
        sample:Refresh(set, 1, {})
        local visible = {}
        for _, w in ipairs(env.widgets) do
            if w.kind == "Frame" and w.parent and w.parent.parent == sample and w.width and w.scripts and w.width == w.height then visible[#visible + 1] = w end
        end
        assert(#visible == 2)
        local bucket = visible[1].parent
        local insetX = anchor.value:find("LEFT") and 2 or anchor.value:find("RIGHT") and -2 or 0
        local insetY = anchor.value:find("TOP") and -2 or anchor.value:find("BOTTOM") and 2 or 0
        assert(bucket.point[4] == insetX + 7 and bucket.point[5] == insetY - 9, "preview offsets must match live anchors")
        if direction.value == "UP" or direction.value == "DOWN" then assert(bucket.height == 47 and bucket.width == 30)
        else assert(bucket.width == 47 and bucket.height == 30) end
        local first, second = Rectangle(visible[1]), Rectangle(visible[2])
        for _, bounds in ipairs({ first, second }) do
            assert(bounds.left >= 0 and bounds.bottom >= 0 and bounds.right <= bucket.width and bounds.top <= bucket.height,
                "mixed sizes must stay inside the anchored group")
        end
        local gap = direction.value == "LEFT" and first.left - second.right
            or direction.value == "RIGHT" and second.left - first.right
            or direction.value == "UP" and second.bottom - first.top
            or first.bottom - second.top
        assert(gap == 5, "mixed sizes must preserve the exact edge-to-edge gap")
        sample:Refresh(set, 1, { [1] = true })
        assert(bucket.width == 30 and bucket.height == 30)
        assert(visible[2].point[4] == 0 and visible[2].point[5] == 0)
    end
end

-- Groups have independent Z offsets and follow their parent frame's level.
Addon:SaveIndicatorSet("default", { items = {
    { id = 1, spellID = 774, anchor = "TOPLEFT" },
    { id = 2, spellID = 366155, anchor = "BOTTOMRIGHT" },
}, groups = { TOPLEFT = { offsetZ = 20 }, BOTTOMRIGHT = { offsetZ = -5 } } })
local layerFrame = env.frame("party4")
layerFrame:SetFrameLevel(50)
local beforeLayers = #env.containers
Addon:UpdateDesignerIndicators(layerFrame)
local front, back = env.containers[beforeLayers + 1], env.containers[beforeLayers + 2]
assert(front:GetFrameLevel() == 80 and back:GetFrameLevel() == 55)
local layerPreview = Addon:CreateDesignerPreview(env.frame())
layerPreview:Refresh(Addon:GetIndicatorSet(), 1, {})
local previewGroups = {}
for _, w in ipairs(env.widgets) do
    if w.kind == "Frame" and w.parent == layerPreview and w.point then previewGroups[w.point[1]] = w end
end
assert(previewGroups.TOPLEFT:GetFrameLevel() == layerPreview:GetFrameLevel() + 30)
assert(previewGroups.BOTTOMRIGHT:GetFrameLevel() == layerPreview:GetFrameLevel() + 5,
    "preview and live groups use the same relative layers")
layerFrame:SetFrameLevel(75)
Addon:UpdateDesignerIndicators(layerFrame)
assert(front:GetFrameLevel() == 105 and back:GetFrameLevel() == 80, "parent level changes retain each group offset")

env.restricted = true
Addon:ChangeDesignerGroup("default", "TOPLEFT", { offsetZ = -100 })
Addon:UpdateDesignerIndicators(layerFrame)
assert(not front.enabled and Addon:HasPendingDesignerIndicators(), "Z-only changes defer while aura buttons are forbidden")
assert(front.level == 105, "deferring a change must not propagate levels to forbidden children")
env.restricted = false
Addon:UpdateDesignerIndicators(layerFrame)
assert(front:GetFrameLevel() == 0 and front.enabled and not Addon:HasPendingDesignerIndicators(),
    "deferred Z changes apply safely and clamp at the lowest frame level")
assert(back:GetFrameLevel() == 80, "changing one group's layer leaves the other group in place")

-- Blizzard_PrivateAurasUI reserves defensive icons at level 150 and its
-- dispel overlay at 200. The old +100 cap cannot reach these on a low frame.
layerFrame:SetFrameLevel(5)
layerFrame.BigDefensiveBuff = { GetFrameLevel = function() error("must not inspect Blizzard's forbidden aura frames") end }
Addon:ChangeDesignerGroup("default", "TOPLEFT", { offsetZ = 100 })
Addon:UpdateDesignerIndicators(layerFrame)
assert(front.groups[1].frames[1]:GetFrameLevel() < 150, "reproduce the old layer limit")
Addon:ChangeDesignerGroup("default", "TOPLEFT", { offsetZ = 200 })
env.restricted = true
Addon:UpdateDesignerIndicators(layerFrame)
assert(not front.enabled and front.level == 115, "higher layers also defer until it is safe to restyle")
env.restricted = false
Addon:UpdateDesignerIndicators(layerFrame)
for _, button in ipairs(front.groups[1].frames) do
    assert(button:GetFrameLevel() > 200, "the front preset must raise every pooled aura above Blizzard's layers")
end
assert(back:GetFrameLevel() == 10, "raising one anchor group must leave the other group's layer unchanged")
layerPreview:Refresh(Addon:GetIndicatorSet(), 1, {})
assert(previewGroups.TOPLEFT:GetFrameLevel() == layerPreview:GetFrameLevel() + 210,
    "preview accepts the same higher layer as the live group")
Addon:ChangeDesignerGroup("default", "TOPLEFT", { offsetZ = 500 })
Addon:UpdateDesignerIndicators(layerFrame)
assert(front:GetFrameLevel() == 515, "the extended maximum must reach the runtime without being clamped to 100")

-- Exercise a full raid with a typical eight-indicator set. The public API
-- preallocates ten buttons per group; repeated updates must allocate none.
local raidSet = { items = {} }
for index = 1, 8 do raidSet.items[index] = { id = index, spellID = 774 + index } end
Addon:SaveIndicatorSet("default", raidSet)
local raidFrames, before = {}, #env.containers
for index = 1, 40 do
    raidFrames[index] = env.frame("raid" .. index)
    Addon:UpdateDesignerIndicators(raidFrames[index])
end
assert(#env.containers == before + 40)
for index = before + 1, #env.containers do assert(#env.containers[index].groups == 8) end
local allocated = #env.widgets
for _, raidFrame in ipairs(raidFrames) do Addon:UpdateDesignerIndicators(raidFrame) end
assert(#env.widgets == allocated, "stable raid updates must reuse existing containers and visuals")
print("designer runtime and layout tests passed" .. (os.getenv("BRF_ANCHOR_UTIL") and " (Blizzard AnchorUtil)" or ""))
