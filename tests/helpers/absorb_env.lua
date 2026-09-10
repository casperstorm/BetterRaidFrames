local env = assert(loadfile("tests/helpers/threat_env.lua"))()
local methods = getmetatable(env.frame()).__index
local secrets = {}
function env.secret(number)
    local value = setmetatable({}, {
        __add = function() error("secret health arithmetic") end,
        __sub = function() error("secret health arithmetic") end,
        __mul = function() error("secret health arithmetic") end,
        __div = function() error("secret health arithmetic") end,
        __lt = function() error("secret health comparison") end,
        __le = function() error("secret health comparison") end,
    })
    secrets[value] = number
    return value
end
function issecretvalue(value) return value == "secret" or secrets[value] ~= nil end
env.healthMax, env.absorbs = 100, 40
env.valueWrites, env.styleWrites, env.queries = 0, 0, 0
function UnitHealthMax(unit) env.queries = env.queries + 1; env.lastUnit = unit; return env.healthMax end
function UnitGetTotalAbsorbs(unit) env.queries = env.queries + 1; env.lastUnit = unit; return env.absorbs end
function UnitHealth() error("the addon must not inspect health to decide whether an overshield is visible") end
function UnitExists(unit) assert(not issecretvalue(unit)); return unit ~= "missing" end
function methods:GetAlpha() return self.alpha == nil and 1 or self.alpha end
function methods:SetMinMaxValues(min, max)
    env.valueWrites = env.valueWrites + 1
    self.min, self.max = min, max
end
local SetValue = methods.SetValue
function methods:SetValue(value)
    env.valueWrites = env.valueWrites + 1
    return SetValue(self, value)
end
function methods:SetReverseFill(value) self.reverse = value end
function methods:SetStatusBarTexture(texture)
    self.fill = self.fill or self:CreateTexture()
    self.fill:SetTexture(texture)
end
function methods:GetStatusBarTexture() return self.fill end
function methods:SetStatusBarColor(...) self.color = { ... } end
function methods:SetDrawLayer(...) self.drawLayer = { ... } end
function methods:SetAtlas(atlas, useAtlasSize, filter, resetTexCoords, wrapH, wrapV)
    self.atlas = atlas
    self.atlasOptions = { useAtlasSize, filter, resetTexCoords, wrapH, wrapV }
end
function methods:SetHorizTile(value) self.horizTile = value end
function methods:SetVertTile(value) self.vertTile = value end
for _, name in ipairs({ "SetAlpha", "SetAtlas", "SetTexture", "SetHorizTile", "SetVertTile", "SetPoint", "SetAllPoints", "SetFrameLevel", "Show", "Hide" }) do
    local original = methods[name]
    methods[name] = function(self, ...)
        assert(self:CanBeAccessedInContext() == true, "cannot style inaccessible shield artwork")
        env.styleWrites = env.styleWrites + 1
        return original(self, ...)
    end
end
function env.shieldFrame(unit)
    local frame = env.frame(unit)
    frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBar:SetAllPoints(frame)
    frame.healthBar:SetMinMaxValues(0, 100)
    frame.healthBar:SetValue(80)
    frame.healthBar:SetStatusBarTexture("native-health")
    for _, key in ipairs({ "totalAbsorb", "totalAbsorbOverlay", "overAbsorbGlow", "TotalAbsorbLeftShadow", "myHealAbsorb" }) do
        frame[key] = frame:CreateTexture()
    end
    frame.totalAbsorbOverlay:SetAlpha(.75)
    return frame
end
-- The test's renderer models status-bar clipping and mask intersection. Only
-- this simulated native side unwraps secret values; addon code never does.
function env.overflowWidth(frame)
    local bar = frame.BRFOvershield
    if not bar or not bar:IsVisible() then return 0 end
    assert(bar.reverse and bar.allPoints == frame.healthBar and bar.BRFMask.allPoints == frame.healthBar.fill)
    assert(bar.BRFTexture.mask == bar.BRFMask)
    local function native(value) return secrets[value] or value end
    local maximum, value = native(bar.max), native(bar.value)
    local health = native(frame.healthBar.value) / native(frame.healthBar.max)
    local fill = maximum > 0 and math.max(0, math.min(1, value / maximum)) or 0
    return math.max(0, math.min(1, health) - (1 - fill))
end
assert(loadfile("Absorbs.lua"))("BetterRaidFrames", env.Addon)
return env
