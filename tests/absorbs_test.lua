local env = assert(loadfile("tests/helpers/absorb_env.lua"))()
local Addon, settings = env.Addon, env.settings
local function near(a, b) assert(math.abs(a - b) < 1e-7, tostring(a) .. " ~= " .. tostring(b)) end
settings.showAbsorbs, settings.absorbOpacity = true, 100
settings.showOvershields, settings.overshieldTexture, settings.overshieldOpacity = false, "SHIELDS", 80
local frame = env.shieldFrame("party1")
local allocated, styles = #env.widgets, env.styleWrites
Addon:UpdateAbsorbs(frame)
assert(not frame.BRFOvershield and #env.widgets == allocated and env.styleWrites == styles and env.queries == 0,
    "default native shields allocate nothing, change no art, and make no health queries")
settings.showOvershields = true
Addon:UpdateAbsorbs(frame)
local bar = frame.BRFOvershield
assert(bar and #env.widgets == allocated + 3, "one status bar, fill, and mask per frame")
assert(bar:GetFrameLevel() == frame.healthBar:GetFrameLevel() and bar.alpha == .8)
assert(bar.BRFTexture.atlas == "RaidFrame-Shield-Overlay")
assert(bar.BRFTexture.horizTile and bar.BRFTexture.vertTile
    and bar.BRFTexture.atlasOptions[4] == "REPEAT" and bar.BRFTexture.atlasOptions[5] == "REPEAT",
    "the current shield artwork repeats at native detail instead of stretching the legacy texture")
near(env.overflowWidth(frame), .2)

for _, case in ipairs({ {40, 25, 0}, {80, 50, .3}, {100, 45, .45}, {100, 0, 0}, {100, 200, 1}, {20, 90, .1} }) do
    frame.healthBar:SetValue(case[1]); env.absorbs = case[2]
    Addon:UpdateAbsorbs(frame)
    near(env.overflowWidth(frame), case[3])
end
env.healthMax, env.absorbs = env.secret(200), env.secret(120)
frame.healthBar:SetMinMaxValues(0, env.healthMax)
frame.healthBar:SetValue(env.secret(150))
Addon:UpdateAbsorbs(frame)
assert(rawequal(bar.max, env.healthMax) and rawequal(bar.value, env.absorbs), "pass opaque health and absorbs unchanged")
near(env.overflowWidth(frame), .35)
frame.displayedUnit = "partypet1"
Addon:UpdateAbsorbs(frame)
assert(env.lastUnit == "partypet1", "shield data follows the displayed vehicle unit")

allocated, styles = #env.widgets, env.styleWrites
collectgarbage("collect"); collectgarbage("stop")
local memory = collectgarbage("count")
local dataWrites = env.valueWrites
for _ = 1, 1000 do Addon:UpdateAbsorbs(frame) end
local temporary = collectgarbage("count") - memory
collectgarbage("restart")
assert(temporary < 1 and #env.widgets == allocated and env.styleWrites == styles, "stable shield updates allocate nothing and do not restyle")
assert(env.valueWrites == dataWrites + 2000, "update only the two native bar values when the data refreshes")

settings.absorbOpacity = 40
Addon:UpdateAbsorbs(frame)
near(frame.totalAbsorb.alpha, .4); near(frame.totalAbsorbOverlay.alpha, .3)
assert(frame.myHealAbsorb:GetAlpha() == 1, "healing absorbs are unaffected")
settings.showAbsorbs = false
Addon:UpdateAbsorbs(frame)
assert(frame.totalAbsorb.alpha == 0 and frame.overAbsorbGlow.alpha == 0 and frame.TotalAbsorbLeftShadow.alpha == 0)
assert(bar.shown, "normal absorbs and overshields can be controlled independently")
settings.showAbsorbs, settings.absorbOpacity = true, 100
Addon:UpdateAbsorbs(frame)
near(frame.totalAbsorb.alpha, 1); near(frame.totalAbsorbOverlay.alpha, .75)

for _, option in ipairs(Addon.AbsorbTextureOptions) do
    settings.overshieldTexture = option.value
    Addon:UpdateAbsorbs(frame)
    assert(option.atlas and bar.BRFTexture.atlas == option.atlas or option.texture and bar.BRFTexture.texture == option.texture)
    assert(bar.BRFTexture.horizTile == (option.tiled == true) and bar.BRFTexture.vertTile == (option.tiled == true),
        "switching textures removes tiling from ordinary bar artwork")
end
settings.overshieldTexture, settings.overshieldOpacity = "FLAT", 35
Addon:UpdateAbsorbs(frame)
assert(bar.BRFTexture.texCoord[1] == 0 and bar.BRFTexture.texCoord[2] == 1 and bar.alpha == .35,
    "switching away from an atlas resets UV coordinates")
settings.overshieldTexture = "INVALID"
Addon:UpdateAbsorbs(frame)
assert(bar.BRFTexture.atlas == Addon.AbsorbTextureOptions[1].atlas)

settings.showOvershields = false
local queries = env.queries
Addon:UpdateAbsorbs(frame)
assert(not bar.shown and env.queries == queries, "disabled overshields stop querying health")
settings.showOvershields = true
Addon:UpdateAbsorbs(frame)
assert(frame.BRFOvershield == bar and #env.widgets == allocated and bar.shown)
frame:Hide(); Addon:UpdateAbsorbs(frame)
assert(not bar.shown)
frame:Show(); Addon:UpdateAbsorbs(frame)
assert(bar.shown)
frame.displayedUnit = "missing"; Addon:UpdateAbsorbs(frame)
assert(not bar.shown)
frame.displayedUnit = "secret"; Addon:UpdateAbsorbs(frame)
assert(not bar.shown)
frame.displayedUnit = "party2"; Addon:UpdateAbsorbs(frame)
assert(bar.shown)

frame.healthBar.accessDenied = true
Addon:UpdateAbsorbs(frame)
assert(not bar.shown, "inaccessible health geometry hides the extra display")
frame.healthBar.accessDenied = false
Addon:HookAbsorbs(); Addon:HookAbsorbs()
env.hooks.CompactUnitFrame_UpdateHealPrediction(frame)
assert(bar.shown, "native prediction refreshes reapply accessible shield displays")
local events = env.find(function(w) return w.events and w.events.ADDON_RESTRICTION_STATE_CHANGED end)
events.scripts.OnEvent()
assert(env.requested == "absorbs")
for _, object in ipairs(env.widgets) do assert(not object.scripts.OnUpdate, "shields add no polling") end

print("PASS: absorbs_test (overflow clipping, opaque values, native restoration, textures, reuse, restrictions)")
