local unpack = table.unpack or unpack
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 1e-7, (label or "coordinate") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local combat, physicalHeight = false, 1080
local settings = { crispFrameBorders = false }
local frames, events = {}, {}
local writes, creations, scans, requests, hookCount = 0, 0, 0, 0, 0
local pending = false
local secret = setmetatable({}, {
    __add = function() error("secret arithmetic") end,
    __sub = function() error("secret arithmetic") end,
    __mul = function() error("secret arithmetic") end,
    __lt = function() error("secret comparison") end,
})
function issecretvalue(value) return rawequal(value, secret) end
function InCombatLockdown() return combat end
PixelUtil = {
    GetPixelToUIUnitFactor = function() return 768 / physicalHeight end,
    GetNearestPixelSize = function(size, scale)
        local pixel = 768 / physicalHeight / scale
        return math.floor(size / pixel + 0.5) * pixel
    end,
}

local methods = {}
function methods:IsForbidden() return self.forbidden end
function methods:IsVisible() return self.visible end
function methods:IsShown() return self.visible end
function methods:GetName() return self.name end
function methods:GetRect() return self.left, self.bottom, self.width, self.height end
function methods:GetEffectiveScale() return self.scale end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(index) return unpack(self.points[index]) end
function methods:SetPoint(point, relative, relativePoint, x, y)
    writes = writes + 1
    for index, old in ipairs(self.points) do
        if old[1] == point then self.points[index] = { point, relative, relativePoint, x, y }; return end
    end
    self.points[#self.points + 1] = { point, relative, relativePoint, x, y }
end
function methods:HookScript(name, callback)
    assert(not self.scripts[name], "frame hooks must only be installed once")
    self.scripts[name] = callback
    hookCount = hookCount + 1
end
function methods:SetScript(name, callback)
    assert(name ~= "OnUpdate", "pixel correction must not install a polling loop")
    self.scripts[name] = callback
end
function methods:RegisterEvent(name) self.events[name] = true end
function methods:SetShouldAdjustHealthBarAnchor()
    error("addon writes to loss-bar offsets taint Blizzard's secret max-health arithmetic")
end
local function region()
    return setmetatable({ points = {}, scripts = {}, events = {}, visible = true }, { __index = methods })
end
function CreateFrame()
    creations = creations + 1
    local result = region()
    events[#events + 1] = result
    return result
end
function hooksecurefunc(target, name, callback)
    if type(target) == "string" then target, name, callback = _G, target, name end
    local original = assert(target[name])
    target[name] = function(...)
        original(...)
        callback(...)
    end
end

-- Stock health/power anchors from DefaultCompactUnitFrameSetup; the health
-- reduction write matches TempMaxHealthLossMixin:Update_MaxHealthLoss.
function DefaultCompactUnitFrameSetup(frame)
    local power = frame.powerBar.visible
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, power and 9 or 1)
    local loss = frame.TempMaxHealthLoss
    loss.ShouldAdjustHealthBarAnchor, loss.xAnchorOffset, loss.yAnchorOffset = true, -1, power and 9 or 1
    if power then
        frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, frame.powerGap or 0)
        frame.powerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
end
DefaultCompactMiniFrameSetup = DefaultCompactUnitFrameSetup
CompactUnitFrameUtil = { ApplyConfig = DefaultCompactUnitFrameSetup }
function CompactRaidGroup_UpdateLayout() end
CompactRaidFrameContainer = { LayoutFrames = function() end }
EditModeManagerFrame = { EnterEditMode = function() end, ExitEditMode = function() end }

local Addon = {}
function Addon:GetSetting(key) return settings[key] end
function Addon:GetSettings() return settings end
function Addon:ForEachFrame(callback)
    scans = scans + 1
    for _, frame in ipairs(frames) do callback(frame) end
end
function Addon:RequestFeatureUpdate(feature)
    assert(feature == "frameBorders")
    pending = true
    requests = requests + 1
end
local function flush()
    if pending then pending = false; Addon:RefreshFrameBorders() end
end
local function event(name)
    for _, frame in ipairs(events) do if frame.events[name] then frame.scripts.OnEvent(frame, name) end end
    flush()
end
local function compact(name, left, bottom, width, height, scale, power)
    local frame = region()
    frame.name, frame.left, frame.bottom, frame.width, frame.height, frame.scale = name, left, bottom, width, height, scale
    frame.healthBar, frame.powerBar, frame.TempMaxHealthLoss = region(), region(), region()
    frame.powerBar.visible = power or false
    DefaultCompactUnitFrameSetup(frame)
    return frame
end
local function reduction(frame, fraction)
    local loss = frame.TempMaxHealthLoss
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -frame.width * fraction + loss.xAnchorOffset, loss.yAnchorOffset)
end
local function point(region, name)
    for _, p in ipairs(region.points) do if p[1] == name then return p end end
    error("missing anchor " .. name)
end
local function edges(frame, power)
    local top, bottom = point(frame.healthBar, "TOPLEFT"), point(frame.healthBar, "BOTTOMRIGHT")
    local left, high = frame.left + top[4], frame.bottom + frame.height + top[5]
    if power then
        top, bottom = point(frame.powerBar, "TOPLEFT"), point(frame.powerBar, "BOTTOMRIGHT")
        high = frame.bottom + point(frame.healthBar, "BOTTOMRIGHT")[5] + top[5]
        left = left + top[4]
    end
    local pixels = physicalHeight / 768 * frame.scale
    return left * pixels, (frame.bottom + bottom[5]) * pixels, (frame.left + frame.width + bottom[4]) * pixels, high * pixels
end
local function pixelEdges(frame, power)
    local left, bottom, right, top = edges(frame, power)
    for _, value in ipairs({ left, bottom, right, top }) do near(value, math.floor(value + 0.5), "physical pixel edge") end
end
local function stock(frame)
    local top, bottom = point(frame.healthBar, "TOPLEFT"), point(frame.healthBar, "BOTTOMRIGHT")
    near(top[4], 1); near(top[5], -1); near(bottom[4], -1)
    near(bottom[5], frame.powerBar.visible and 9 or 1)
    near(frame.TempMaxHealthLoss.xAnchorOffset, -1)
end

assert(loadfile("FrameBorders.lua"))("BetterRaidFrames", Addon)
Addon:HookFrameBorders()
Addon:HookFrameBorders()
assert(creations == 1, "one shared event frame, even if hooks are requested twice")
Addon:RefreshFrameBorders()
event("UI_SCALE_CHANGED")
assert(scans == 0 and requests == 0, "disabled defaults must not scan frames or schedule work")

-- Rows/columns at fractional positions and sizes, across resolutions and scales.
settings.crispFrameBorders = true
for _, resolution in ipairs({ 1080, 1440, 2160 }) do
    physicalHeight = resolution
    for _, scale in ipairs({ .64, .83, 1, 1.17 }) do
        local width, height, left, top = 91.37, 47.83, 31.61, 706.29
        for _, horizontal in ipairs({ false, true }) do
            frames = {}
            for index = 1, 5 do
                frames[index] = compact("CompactPartyFrameMember" .. index,
                    left + (horizontal and (index - 1) * width or 0),
                    top - (horizontal and 1 or index) * height, width, height, scale)
            end
            Addon:RefreshFrameBorders()
            for index, frame in ipairs(frames) do
                pixelEdges(frame)
                assert(#frame.points == 0 and frame.width == width and frame.height == height,
                    "unit-frame placement and sizing stay under Blizzard's control")
                if index > 1 then
                    local aLeft, aBottom, aRight = edges(frames[index - 1])
                    local bLeft, _, _, bTop = edges(frame)
                    near(horizontal and bLeft - aRight or aBottom - bTop, 2, "adjacent separator")
                end
            end
            local beforeWrites, beforeHooks = writes, hookCount
            for _ = 1, 50 do Addon:RefreshFrameBorders() end
            assert(writes == beforeWrites and hookCount == beforeHooks and creations == 1,
                "stable geometry must not rewrite anchors, add objects, or duplicate hooks")
            settings.crispFrameBorders = false
            Addon:RefreshFrameBorders()
            for _, frame in ipairs(frames) do stock(frame) end
            settings.crispFrameBorders = true
        end
    end
end

physicalHeight = 1440
local frame = compact("CompactRaidGroup1Member1", 43.23, 128.17, 100.37, 49.71, .83, true)
frame.powerGap = -2
DefaultCompactUnitFrameSetup(frame)
frames = { frame }
reduction(frame, .25)
Addon:RefreshFrameBorders()
near(point(frame.healthBar, "BOTTOMRIGHT")[4], -1 - frame.width * .25, "existing max-health reduction retained")
reduction(frame, 0)
Addon:RefreshFrameBorders()
pixelEdges(frame); pixelEdges(frame, true)
local healthLeft, healthBottom = edges(frame)
local powerLeft, _, _, powerTop = edges(frame, true)
near(healthLeft, powerLeft, "health and power share their left edge")
near(healthBottom - powerTop, 3, "two UI units round to a whole-pixel power-bar gap")

-- Live max-health updates continue using the corrected base after alignment.
reduction(frame, .4)
near(point(frame.healthBar, "BOTTOMRIGHT")[4], -1 - frame.width * .4)
frame.scale = 1.03
event("UI_SCALE_CHANGED")
near(point(frame.healthBar, "BOTTOMRIGHT")[4], -1 - frame.width * .4, "active reductions stay under Blizzard's control")
reduction(frame, 0)
event("UI_SCALE_CHANGED")
pixelEdges(frame); pixelEdges(frame, true)
reduction(frame, .4)
frame.visible = false
frames = {} -- e.g. the party/raid context changes while disabling the setting.
settings.crispFrameBorders = false
Addon:RefreshFrameBorders()
near(point(frame.healthBar, "BOTTOMRIGHT")[4], -1 - frame.width * .4, "hidden frames restore without clearing max-health reduction")
near(frame.TempMaxHealthLoss.xAnchorOffset, -1)
near(frame.TempMaxHealthLoss.yAnchorOffset, 9)
near(point(frame.powerBar, "TOPLEFT")[5], -2)
near(point(frame.powerBar, "BOTTOMRIGHT")[4], -1)
near(point(frame.powerBar, "BOTTOMRIGHT")[5], 1)
reduction(frame, 0); stock(frame)

-- Native setup invalidates cached geometry even if the outer frame size is unchanged.
frame.visible, settings.crispFrameBorders = true, true
frames = { frame }
Addon:RefreshFrameBorders()
frame.powerBar.visible = false
CompactUnitFrameUtil.ApplyConfig(frame)
assert(pending, "native configuration schedules a pass after the layout finishes")
flush(); pixelEdges(frame)
near(frame.TempMaxHealthLoss.xAnchorOffset, -1, "loss-bar offsets stay native")
near(frame.TempMaxHealthLoss.yAnchorOffset, 1, "loss-bar offsets stay native")
local before = writes
frame.left = frame.left + .3
CompactRaidFrameContainer:LayoutFrames()
flush()
assert(writes > before, "raid layout hook catches position-only changes")
pixelEdges(frame)
frame.height = frame.height + .3
frame.scripts.OnSizeChanged(frame)
flush(); pixelEdges(frame)

-- Combat edits wait until regen, for both enabling and restoring.
combat = true
before = writes
settings.crispFrameBorders = false
Addon:RefreshFrameBorders()
event("DISPLAY_SIZE_CHANGED")
assert(writes == before, "no protected artwork edits in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
stock(frame)
combat, settings.crispFrameBorders = true, true
before = writes
Addon:RefreshFrameBorders()
assert(writes == before)
combat = false
event("PLAYER_REGEN_ENABLED")
pixelEdges(frame)

-- A native combat reset is allowed to stand until an out-of-combat refresh.
combat = true
DefaultCompactUnitFrameSetup(frame)
before = writes
Addon:RefreshFrameBorders()
assert(writes == before)
combat = false
event("PLAYER_REGEN_ENABLED")
pixelEdges(frame)
settings.crispFrameBorders = false
Addon:RefreshFrameBorders()
stock(frame)

-- Never manipulate unknown, custom, forbidden, or restricted geometry.
settings.crispFrameBorders = true
for _, mutate in ipairs({
    function(f) f.name = "NamePlate1" end,
    function(f) f.name = secret end,
    function(f) f.forbidden = true end,
    function(f) f.healthBar.forbidden = true end,
    function(f) f.left = secret end,
    function(f) f.scale = 0 end,
    function(f) f.width = 0 / 0 end,
    function(f) f.visible = secret end,
    function(f) f.TempMaxHealthLoss.xAnchorOffset = secret end,
    function(f) point(f.healthBar, "BOTTOMRIGHT")[4] = secret end,
    function(f) point(f.healthBar, "TOPLEFT")[4] = 5 end,
}) do
    local restricted = compact("CompactRaidFrame1", 18.31, 13.37, 100, 50, .83)
    mutate(restricted)
    frames = { restricted }
    before = writes
    Addon:RefreshFrameBorders()
    assert(writes == before, "unsafe or foreign geometry must be left untouched")
end

print("PASS: frame_borders_test (pixel geometry, power/max-health, restoration, hooks, combat, restrictions)")
