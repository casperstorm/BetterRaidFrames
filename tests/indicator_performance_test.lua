-- Resource counts and Lua allocations in a public-API fake, not measurements
-- of WoW's native renderer, GPU memory, or in-game CPU time.
local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
local methods = getmetatable(env.frame()).__index
local nativeCalls = 0
for _, name in ipairs({ "SetEnabled", "SetShown", "SetFrameLevel", "SetAuraGroupCandidateFilters", "SetAuraGroupLayout", "Play", "Stop" }) do
    local original = methods[name]
    methods[name] = function(self, ...)
        nativeCalls = nativeCalls + 1
        return original(self, ...)
    end
end
local function Count(kind)
    local total = 0
    for _, w in ipairs(env.widgets) do if w.kind == kind then total = total + 1 end end
    return total
end
local function Playing()
    local total = 0
    for _, w in ipairs(env.widgets) do if w.kind == "AnimationGroup" and w.playing then total = total + 1 end end
    return total
end
local function Heap()
    collectgarbage("collect")
    return collectgarbage("count")
end
local set = { items = {} }
for i = 1, 8 do set.items[i] = { id = i, spellID = 774 + i, type = "ICON" } end
Addon:SaveIndicatorSet("default", set)
local frames = {}
for i = 1, 40 do frames[i] = env.frame("raid" .. i); Addon:UpdateDesignerIndicators(frames[i]) end
assert(Count("Button") == 3200, "native automatic layout reserves ten buttons per indicator")
assert(Count("Texture") == 3200 and Count("Cooldown") == 0 and Count("FontString") == 0 and Count("AnimationGroup") == 0,
    "plain indicators allocate only their native buttons and icon textures")
local allocated, calls = #env.widgets, nativeCalls
local retained = Heap()
collectgarbage("stop")
local transient = collectgarbage("count")
for _ = 1, 1000 do for _, frame in ipairs(frames) do Addon:UpdateDesignerIndicators(frame) end end
local temporary = collectgarbage("count") - transient
collectgarbage("restart")
assert(temporary < 1, "unchanged updates must not allocate per-frame Lua tables")
assert(#env.widgets == allocated and nativeCalls == calls, "unchanged updates must not restyle or wake native containers")
assert(Heap() - retained < 1, "unchanged updates must not retain memory")

-- Editing one spell must not restyle seven other spells on each unit frame.
local styled = 0
local Style = Addon.StyleDesignerVisual
function Addon:StyleDesignerVisual(...)
    styled = styled + 1
    return Style(self, ...)
end
Addon:ChangeDesignerIndicator("default", 1, { size = 21 })
for _, frame in ipairs(frames) do Addon:UpdateDesignerIndicators(frame) end
assert(styled == 400, "only the changed indicator's reserved buttons need restyling")

-- Warm optional features, then reuse their objects after disabling/re-enabling.
for _, item in ipairs(set.items) do item.cooldown, item.glow, item.glowPulse, item.text = true, true, true, "DURATION" end
Addon:SaveIndicatorSet("default", set)
for _, frame in ipairs(frames) do Addon:UpdateDesignerIndicators(frame) end
assert(Count("Cooldown") == 3200 and Count("FontString") == 3200 and Playing() == 3200)
assert(Count("Alpha") == 3200, "each pulse uses one bouncing alpha animation")
allocated = #env.widgets
local function ApplyAll()
    for _, frame in ipairs(frames) do Addon:UpdateDesignerIndicators(frame) end
end
Addon:SaveIndicatorSet("default", {})
ApplyAll()
assert(Playing() == 0, "removing all indicators must stop every pulse")
for _, container in ipairs(env.containers) do
    assert(not container.enabled)
    for _, group in ipairs(container.groups) do
        assert(next(group.filters.includeSpellIDs) == nil, "inactive pools must stop matching auras")
        for _, button in ipairs(group.frames) do assert(next(button.bindings) == nil, "inactive text and cooldown bindings must be cleared") end
    end
end
Addon:SaveIndicatorSet("default", set); ApplyAll()
assert(Playing() == 3200 and #env.widgets == allocated, "re-enabling reuses every visual and animation")

-- Shrinking an anchor must also stop pulses in its unused trailing pools.
local reduced = Addon:NormalizeIndicatorSet(set)
while #reduced.items > 2 do table.remove(reduced.items) end
Addon:SaveIndicatorSet("default", reduced); ApplyAll()
assert(Playing() == 800, "unused pools must not keep their old pulses running")
Addon:SaveIndicatorSet("default", set); ApplyAll()

-- Move a whole group repeatedly. Native containers cannot be destroyed, so
-- reusing an inactive anchor is essential to avoid a new pool at every corner.
for pass = 1, 3 do
    for _, anchor in ipairs(Addon.IndicatorAnchors) do
        for _, item in ipairs(set.items) do item.anchor = anchor.value end
        Addon:SaveIndicatorSet("default", set); ApplyAll()
    end
end
assert(#env.containers == 40 and #env.widgets == allocated, "anchor moves must reuse containers and their full pools")

-- Hide/show and restrictions must retain safe deferred behavior.
for _, frame in ipairs(frames) do frame:Hide(); frame.scripts.OnHide(frame) end
assert(Playing() == 0)
ApplyAll()
assert(Playing() == 0, "background updates must not wake hidden unit frames")
for _, frame in ipairs(frames) do frame:Show(); frame.scripts.OnShow(frame) end
assert(Playing() == 3200)
env.restricted = true
Addon:SaveIndicatorSet("default", {}); ApplyAll()
for _, container in ipairs(env.containers) do assert(not container.enabled) end
env.restricted = false
ApplyAll()
assert(Playing() == 0, "deferred animation cleanup must run when aura restrictions end")
Addon:SaveIndicatorSet("default", set); ApplyAll()

-- Each edit creates a new immutable settings snapshot. Old plan-cache keys
-- must be collectible rather than accumulating with every edited setting.
local function EditMany(count)
    for i = 1, count do
        Addon:ChangeDesignerIndicator("default", 1, { size = i % 2 == 0 and 21 or 22 })
        Addon:UpdateDesignerIndicators(frames[1])
    end
end
EditMany(100)
retained = Heap()
EditMany(1000)
assert(Heap() - retained < 32, "discarded settings snapshots must not accumulate in the plan cache")
assert(#env.widgets == allocated, "repeated setting edits must not allocate more UI objects")

-- Preview work stops while hidden and resumes from the latest settings.
local preview = Addon:CreateDesignerPreview(env.frame())
preview:Hide(); preview.scripts.OnHide()
allocated = #env.widgets
preview:Refresh(Addon:GetIndicatorSet(), 1, {})
assert(#env.widgets == allocated and not preview.scripts.OnUpdate, "hidden previews allocate no indicator visuals")
preview:Show(); preview.scripts.OnShow()
assert(preview.scripts.OnUpdate)
local pulsing = Playing()
preview:Hide(); preview.scripts.OnHide()
assert(Playing() == pulsing - 8 and not preview.scripts.OnUpdate, "closing the preview stops its timer and pulses")
preview:Show(); preview.scripts.OnShow()
assert(Playing() == pulsing and preview.scripts.OnUpdate)
local static = Addon:NormalizeIndicatorSet({ items = { { id = 1, spellID = 774, text = "STACKS" } } })
preview:Refresh(static, 1, {})
assert(not preview.scripts.OnUpdate and Playing() == pulsing - 8, "static previews need no Lua frame callback")
local stackText = env.find(function(w) return w.kind == "FontString" and w.text == "3" end)
assert(stackText.shown)
print("PASS: indicator_performance_test (40 units, 8 indicators, 40000 stable updates; no new UI objects or native writes)")
