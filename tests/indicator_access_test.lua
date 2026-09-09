local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
local visuals = {}
local Style = Addon.StyleDesignerVisual
function Addon:StyleDesignerVisual(visual, ...)
    visuals[visual.button] = visual
    return Style(self, visual, ...)
end

local id = Addon:AddDesignerIndicator("default", 364343, "ICON", "BOTTOMRIGHT")
Addon:ChangeDesignerIndicator("default", id, { cooldown = true })
local frame = env.frame("raid1")
Addon:UpdateDesignerIndicators(frame)
Addon:HookDesignerIndicators()
local events = env.find(function(w) return w.events and w.events.ADDON_RESTRICTION_STATE_CHANGED end)
local container = env.containers[1]
local button = container.groups[1].frames[1]
local visual = visuals[button]

-- Raid layout releases a frame through unusedFunc -> Hide -> our OnHide.
-- IsForbidden reports false despite temporary restrictions on the cooldown.
env.restricted = true
assert(not button:IsForbidden() and not visual.cooldown:IsForbidden())
assert(not button:CanBeAccessedInContext() and not visual.cooldown:CanBeAccessedInContext())
frame:Hide()
frame.scripts.OnHide(frame)
assert(not container.enabled and button.bindings.DurationCooldown, "hide the container and defer restricted cleanup")
frame.scripts.OnHide(frame) -- repeated raid layout passes must also be harmless.

-- Even if this raid frame is no longer enumerated (e.g. leaving the raid),
-- the restriction-ending event must finish its retained cleanup while hidden.
env.restricted = false
events.scripts.OnEvent()
assert(not container.enabled and not next(button.bindings), "restriction-ending events clean up retained hidden raid frames")
frame:Show()
frame.scripts.OnShow(frame)
assert(container.enabled and button.bindings.DurationCooldown, "reused raid frames bind again after cleanup")

Addon:ChangeDesignerIndicator("default", id, { glow = true, glowPulse = true, text = "DURATION" })
Addon:UpdateDesignerIndicators(frame)
local allocated = #env.widgets
for _, field in ipairs({ "button", "texture", "cooldown", "overlay", "text", "glow", "glowPulse" }) do
    local object = visual[field]
    object.accessDenied = true
    assert(not object:IsForbidden() and not object:CanBeAccessedInContext())
    if field ~= "button" then assert(button:CanBeAccessedInContext(), "child access can differ from the aura button") end
    frame:Hide()
    frame.scripts.OnHide(frame)
    assert(not container.enabled and button.bindings.DurationCooldown, "an inaccessible visual defers the whole cleanup")
    object.accessDenied = false
    events.scripts.OnEvent()
    assert(not next(button.bindings) and not visual.glowPulse.playing, "deferred bindings and pulse are cleared together")
    frame:Show()
    frame.scripts.OnShow(frame)
    assert(container.enabled and visual.glowPulse.playing and button.bindings.DurationCooldown)
    assert(#env.widgets == allocated, "cleanup and reuse must not replace pooled objects")
end

-- Restyling shares the same access check, including child-only restrictions.
visual.cooldown.accessDenied = true
Addon:ChangeDesignerIndicator("default", id, { size = 19 })
Addon:UpdateDesignerIndicators(frame)
assert(not container.enabled and Addon:HasPendingDesignerIndicators() and button.width == 20)
visual.cooldown.accessDenied = false
events.scripts.OnEvent()
Addon:UpdateDesignerIndicators(frame)
assert(container.enabled and not Addon:HasPendingDesignerIndicators() and button.width == 19)

-- Unknown access results must not be branched on as ordinary booleans.
button.secretAccessResult = true
Addon:ChangeDesignerIndicator("default", id, { size = 18 })
Addon:UpdateDesignerIndicators(frame)
assert(not container.enabled and button.width == 19)
button.secretAccessResult = false
Addon:UpdateDesignerIndicators(frame)
assert(container.enabled and button.width == 18)

-- Known-good settings still bind a new unit without touching restricted
-- visuals, so normal role/vehicle/roster updates keep showing active buffs.
env.restricted = true
frame.displayedUnit = "raidpet1"
Addon:UpdateDesignerIndicators(frame)
assert(container.unit == "raidpet1" and container.enabled)

print("PASS: indicator_access_test (raid hide, conditional/child restrictions, deferred cleanup, reuse)")
