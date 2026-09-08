local function equal(actual, expected, message)
    assert(actual == expected, (message or "unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local Addon = {}
local settings = { buffIndicators = {} }
local hooks, events, containers = {}, {}, {}
local restricted = false
local buttonCount, textureWrites = 0, 0
local requested
Enum = {
    StatusBarTimerDirection = { ElapsedTime = "elapsed", RemainingTime = "remaining" },
    StatusBarInterpolation = { Immediate = "immediate" },
}

function Addon:GetSettings() return settings end
function Addon:GetSetting(key) return settings[key] end
function Addon:SetSetting(key, value) settings[key] = value end
function Addon:RequestFeatureUpdate(feature) requested = feature end
function Addon:IsConfigOpen() return false end
function hooksecurefunc(name, callback) hooks[name] = callback end
function issecretvalue(value) return type(value) == "table" and value.secret == true end

local spells = {
    [364343] = { spellID = 364343, name = "Echo" },
    [774] = { spellID = 774, name = "Rejuvenation" },
}
C_Spell = {
    GetSpellInfo = function(value)
        if value == "Echo" then value = 364343 end
        return spells[value]
    end,
}

local function NewButton()
    buttonCount = buttonCount + 1
    local button = { initializing = true }
    local function RequireAccess()
        assert(not restricted or button.initializing, "accessed an aura button or texture while forbidden")
    end
    function button:IsForbidden() return restricted end
    function button:EnableMouse(enabled) RequireAccess(); self.mouseEnabled = enabled end
    function button:ClearAllPoints() RequireAccess() end
    function button:SetPoint(point, parent, relativePoint, x, y)
        RequireAccess()
        self.point, self.relativePoint = point, relativePoint
        self.parent, self.x, self.y = parent, x, y
    end
    function button:SetSize(width, height) RequireAccess(); self.width, self.height = width, height end
    function button:SetFrameLevel(level) RequireAccess(); self.level = level end
    function button:SetDurationBar(bar, options)
        RequireAccess()
        assert(bar.parent == self, "duration bars must be children of their aura button")
        self.bar, self.durationOptions = bar, options
    end
    -- Addon code must never read presence or drive an aura button's visibility.
    function button:IsShown() error("read secret aura visibility") end
    function button:Show() error("addon showed an aura button") end
    function button:Hide() error("addon hid an aura button") end
    return button
end

function CreateFrame(kind, _, parent, template)
    if kind == "StatusBar" then
        local bar = { parent = parent }
        local function RequireAccess()
            assert(not restricted or parent.initializing, "accessed a forbidden duration bar")
        end
        function bar:SetAllPoints() RequireAccess() end
        function bar:SetFrameLevel(level) RequireAccess(); self.level = level end
        function bar:EnableMouse(value) RequireAccess(); self.mouseEnabled = value end
        function bar:SetOrientation(value) RequireAccess(); self.orientation = value end
        function bar:SetReverseFill(value) RequireAccess(); self.reverseFill = value end
        function bar:SetStatusBarTexture(value) RequireAccess(); self.asset = value end
        function bar:SetMinMaxValues() RequireAccess() end
        function bar:SetValue()
            RequireAccess()
            assert(parent.initializing, "addon code must not update a bound timer's value")
        end
        function bar:SetStatusBarColor(r, g, b, a)
            RequireAccess()
            textureWrites = textureWrites + 1
            self.r, self.g, self.b, self.a = r, g, b, a
        end
        function bar:CreateTexture()
            RequireAccess()
            local texture = {}
            function texture:SetAllPoints() RequireAccess() end
            function texture:SetColorTexture(r, g, b, a)
                RequireAccess()
                textureWrites = textureWrites + 1
                self.r, self.g, self.b, self.a = r, g, b, a
            end
            return texture
        end
        function bar:GetValue() error("read secret timer progress") end
        function bar:GetTimerDuration() error("read secret aura duration") end
        function bar:SetTimerDuration() error("addon must delegate aura timer binding to Blizzard") end
        return bar
    end
    if kind == "Frame" then
        return {
            RegisterEvent = function() end,
            SetScript = function(_, _, callback) events.callback = callback end,
        }
    end
    equal(kind, "AuraContainer")
    equal(template, "CustomAuraContainerTemplate")
    local container = { slots = {}, parent = parent, writes = 0 }
    function container:SetPoint() end
    function container:SetSize() end
    function container:SetFrameLevel(level)
        assert(not restricted or not next(self.slots), "changed levels of forbidden aura children")
        self.level = level
    end
    function container:EnableMouse() end
    function container:SetUnit(unit) self.unit = unit end
    function container:SetEnabled(enabled) self.enabled = enabled end
    function container:Show() self.shown = true end
    function container:Hide() self.shown = false end
    function container:AddAuraSlot(key, filter, options)
        assert(not self.slots[key], "slot allocated twice")
        local button = NewButton()
        options.initializeFrame(button)
        button.initializing = false
        self.slots[key] = { button = button, filter = filter, filters = options.candidateFilters }
        return button
    end
    function container:SetAuraSlotCandidateFilters(key, filters)
        self.writes = self.writes + 1
        self.slots[key].filters = filters
    end
    containers[#containers + 1] = container
    return container
end

local function UnitFrame(unit)
    local frame = { unit = unit, width = 100, height = 60, level = 5, scripts = {} }
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetFrameLevel() return self.level end
    function frame:GetName() return "CompactPartyFrameMember1" end
    function frame:IsVisible() return true end
    function frame:HookScript(event, callback) self.scripts[event] = callback end
    return frame
end

assert(loadfile("Utils.lua"))("BetterRaidFrames", Addon)
assert(loadfile("BuffIndicators.lua"))("BetterRaidFrames", Addon)
Addon:HookBuffIndicators()
local function ChangeAll(changes)
    for index in ipairs(settings.buffIndicators) do Addon:ChangeBuffIndicator(index, changes) end
end
local frame = UnitFrame("party1")
Addon:UpdateBuffIndicators(frame)
equal(#containers, 0, "empty profiles should allocate no aura displays")
assert(not Addon:AddBuffIndicator("not a spell"))
assert(Addon:AddBuffIndicator(" Echo "))
assert(not Addon:AddBuffIndicator("364343"), "duplicates must be rejected")
Addon:UpdateBuffIndicators(frame)
local container = containers[1]
local echo = container.slots["1"]
equal(container.unit, "party1")
equal(echo.filter, "HELPFUL")
equal(echo.filters.includeSpellIDs[364343], true)
equal(echo.filters.isFromPlayerOrPlayerPet, true, "mine should be the default")
equal(echo.button.width, 96, "one buff should span the top edge")
equal(echo.button.height, 2)
equal(echo.button.point, "TOPLEFT")
equal(echo.button.y, -2, "top indicators should sit inside the frame")
equal(container.level, 15, "default level should be relative to the raid frame")
equal(echo.button.level, 16)
equal(echo.button.bar.level, 17)
equal(echo.button.mouseEnabled, false, "indicators must not intercept raid-frame clicks")
equal(echo.button.bar.mouseEnabled, false)
equal(echo.button.bar.orientation, "HORIZONTAL")
equal(echo.button.bar.reverseFill, false, "progress should advance from the left edge")
equal(echo.button.durationOptions.direction, Enum.StatusBarTimerDirection.ElapsedTime,
    "Blizzard should fill the bar using elapsed aura time")
equal(echo.button.bar.background.a, 0.25, "a faint track should mark newly applied or permanent buffs")

assert(Addon:AddBuffIndicator("774"))
Addon:ChangeBuffIndicator(2, { mineOnly = false, r = 0.1, g = 0.2, b = 0.3 })
Addon:UpdateBuffIndicators(frame)
local rejuv = container.slots["2"]
equal(rejuv.filters.isFromPlayerOrPlayerPet, nil, "any-caster must omit the caster restriction")
equal(echo.button.width, 47)
equal(rejuv.button.x, 50, "each buff should get a stable segment")
equal(rejuv.button.bar.r, 0.1)

Addon:ChangeBuffIndicator(1, { enabled = false })
Addon:UpdateBuffIndicators(frame)
equal(next(echo.filters.includeSpellIDs), nil, "disabled slots should match nothing")
equal(rejuv.button.x, 50, "disabling a buff must reserve its segment")
local writes = container.writes
local painted = textureWrites
Addon:UpdateBuffIndicators(frame)
equal(container.writes, writes, "unchanged settings should not rescan auras")
equal(textureWrites, painted, "unchanged settings should not restyle buttons")

restricted = true
frame.unit = "party2"
hooks.CompactUnitFrame_SetUnit(frame)
equal(container.unit, "party2", "recycled frames must retarget during restrictions")
frame.displayedUnit = "partypet2"
hooks.CompactUnitFrame_UpdateInVehicle(frame)
equal(container.unit, "partypet2", "indicators should follow the displayed vehicle unit")
settings.buffIndicators = Addon:NormalizeBuffIndicators(settings.buffIndicators)
Addon:UpdateBuffIndicators(frame)
equal(container.shown, true, "equivalent profile settings must not hide indicators during restrictions")
equal(textureWrites, painted)

Addon:ChangeBuffIndicator(2, { r = 0.8 })
Addon:UpdateBuffIndicators(frame)
equal(container.shown, false, "deferred edits must not show the previous profile's colours")
assert(Addon:HasPendingBuffIndicators())
equal(rejuv.button.bar.r, 0.1, "forbidden duration bars must not be modified")
restricted = false
events.callback(nil, "ADDON_RESTRICTION_STATE_CHANGED")
equal(requested, "buffIndicators", "restriction changes must request a refresh")
Addon:UpdateBuffIndicators(frame)
equal(rejuv.button.bar.r, 0.8)
equal(container.shown, true)
assert(not Addon:HasPendingBuffIndicators())

frame.width = 120
frame.scripts.OnSizeChanged()
equal(rejuv.button.x, 60, "resizing should redistribute the segments")
ChangeAll({ thickness = 7 })
Addon:UpdateBuffIndicators(frame)
equal(echo.button.height, 7, "height changes should resize every segment")
equal(rejuv.button.height, 7)
restricted = true
ChangeAll({ thickness = 10 })
ChangeAll({ direction = "REMAINING" })
ChangeAll({ position = "BOTTOM" })
ChangeAll({ frameLevel = 40 })
Addon:UpdateBuffIndicators(frame)
equal(rejuv.button.height, 7, "height changes must wait while aura buttons are forbidden")
equal(rejuv.button.point, "TOPLEFT", "position changes must wait while forbidden")
equal(container.level, 15, "frame levels must not propagate into forbidden children")
equal(rejuv.button.durationOptions.direction, Enum.StatusBarTimerDirection.ElapsedTime)
equal(container.shown, false)
restricted = false
Addon:UpdateBuffIndicators(frame)
equal(rejuv.button.height, 10)
equal(rejuv.button.point, "BOTTOMLEFT")
equal(rejuv.button.relativePoint, "BOTTOMLEFT")
equal(rejuv.button.y, 2, "bottom indicators should sit inside the frame")
equal(rejuv.button.durationOptions.direction, Enum.StatusBarTimerDirection.RemainingTime,
    "drain mode should use remaining time, not reverse the fill texture")
equal(rejuv.button.bar.reverseFill, false)
equal(container.level, 45)
equal(rejuv.button.level, 46)
equal(rejuv.button.bar.level, 47)
equal(container.shown, true)

ChangeAll({ position = "LEFT" })
Addon:UpdateBuffIndicators(frame)
equal(echo.button.point, "TOPLEFT")
equal(echo.button.x, 2)
equal(echo.button.y, -2)
equal(echo.button.width, 10, "vertical indicators should use the configured thickness as width")
equal(echo.button.height, 27)
equal(rejuv.button.y, -30, "vertical segments should reserve positions from top to bottom")
equal(rejuv.button.height, 28)
equal(rejuv.button.bar.orientation, "VERTICAL")
equal(rejuv.button.bar.reverseFill, false)
equal(rejuv.button.durationOptions.direction, Enum.StatusBarTimerDirection.RemainingTime)
equal(next(echo.filters.includeSpellIDs), nil, "disabled buffs should keep their vertical segment")
ChangeAll({ position = "RIGHT" })
Addon:UpdateBuffIndicators(frame)
equal(rejuv.button.point, "TOPRIGHT")
equal(rejuv.button.relativePoint, "TOPRIGHT")
equal(rejuv.button.x, -2, "right indicators should remain inside the frame")
equal(rejuv.button.y, -30)
frame.height = 100
frame.scripts.OnSizeChanged()
equal(rejuv.button.height, 48, "vertical segments must follow frame height changes")
equal(rejuv.button.y, -50)
restricted = true
ChangeAll({ position = "LEFT" })
Addon:UpdateBuffIndicators(frame)
equal(rejuv.button.point, "TOPRIGHT", "edge changes must wait while buttons are forbidden")
equal(container.shown, false)
restricted = false
Addon:UpdateBuffIndicators(frame)
equal(rejuv.button.point, "TOPLEFT")
equal(container.shown, true)
ChangeAll({ position = "BOTTOM" })
Addon:UpdateBuffIndicators(frame)
equal(rejuv.button.bar.orientation, "HORIZONTAL", "returning to top/bottom must restore horizontal progress")
equal(rejuv.button.width, 58)
equal(rejuv.button.height, 10)
Addon:RemoveBuffIndicator(1)
Addon:UpdateBuffIndicators(frame)
equal(echo.filters.includeSpellIDs[774], true, "remaining entries should reuse existing slots")
equal(echo.button.width, 116)
equal(next(rejuv.filters.includeSpellIDs), nil, "removed slots must not retain their old buffs")
equal(buttonCount, 2, "editing or removing entries must not leak aura buttons")

ChangeAll({ direction = "ELAPSED" })
Addon:UpdateBuffIndicators(frame)
assert(Addon:AddBuffIndicator("Echo"))
Addon:UpdateBuffIndicators(frame)
equal(rejuv.button.durationOptions.direction, Enum.StatusBarTimerDirection.ElapsedTime,
    "reusing a previously removed slot must apply the current direction")
Addon:RemoveBuffIndicator(2)
ChangeAll({ direction = "REMAINING" })
frame.level = 8
Addon:UpdateBuffIndicators(frame)
equal(container.level, 48, "layering should follow changes to the parent frame level")
equal(echo.button.bar.level, 50)
ChangeAll({ position = "RIGHT" })
Addon:UpdateBuffIndicators(frame)
equal(echo.button.width, 10)
equal(echo.button.height, 96, "a single vertical indicator should span the selected edge")

restricted = true
local anotherFrame = UnitFrame("raid1")
Addon:UpdateBuffIndicators(anotherFrame)
equal(#containers, 2, "new frames should initialize safely during aura restrictions")
equal(containers[2].slots["1"].button.bar.r, 0.8)
equal(containers[2].slots["1"].button.width, 10, "new vertical frames should use the saved thickness")
equal(containers[2].slots["1"].button.height, 56)
equal(containers[2].slots["1"].button.point, "TOPRIGHT")
equal(containers[2].slots["1"].button.bar.orientation, "VERTICAL")
equal(containers[2].slots["1"].button.durationOptions.direction, Enum.StatusBarTimerDirection.RemainingTime)
equal(containers[2].level, 45)
local secretUnitFrame = UnitFrame({ secret = true })
Addon:UpdateBuffIndicators(secretUnitFrame)
equal(#containers, 2, "secret unit values must not be parsed")
anotherFrame.displayedUnit = { secret = true }
Addon:UpdateBuffIndicators(anotherFrame)
equal(containers[2].unit, "none", "a secret displayed unit must clear any previous binding")
equal(containers[2].enabled, false)
anotherFrame.displayedUnit = nil
Addon:UpdateBuffIndicators(anotherFrame)
equal(containers[2].unit, "raid1", "a readable unit should resume tracking during aura restrictions")
equal(containers[2].enabled, true)
frame.displayedUnit, frame.unit = nil, nil
Addon:UpdateBuffIndicators(frame)
equal(container.unit, "none", "cleared frames must lose their previous unit binding")
equal(container.enabled, false)
Addon:RemoveBuffIndicator(1)
Addon:UpdateBuffIndicators(anotherFrame)
equal(containers[2].enabled, false, "empty profiles should disable their containers even in combat")

restricted = false
settings.buffIndicators = Addon:NormalizeBuffIndicators({
    { spellID = 364343, position = "TOP", thickness = 3, frameLevel = 20 },
    { spellID = 774, position = "LEFT", thickness = 5, direction = "REMAINING", frameLevel = 7 },
    { spellID = 8936, position = "TOP", thickness = 7, direction = "REMAINING", frameLevel = 80 },
    { spellID = 355936, position = "RIGHT", thickness = 6, frameLevel = -10 },
})
local mixedFrame = UnitFrame("party3")
Addon:UpdateBuffIndicators(mixedFrame)
local mixed = containers[#containers]
local top = mixed.slots["1"].button
local left = mixed.slots["2"].button
local secondTop = mixed.slots["3"].button
local right = mixed.slots["4"].button
equal(top.width, 47, "only buffs on the same edge should share its length")
equal(top.height, 3)
equal(secondTop.x, 50, "interleaved edges must not leave gaps on the top edge")
equal(secondTop.height, 7, "thickness must belong to each buff")
equal(left.width, 5)
equal(left.height, 56, "a single left buff should span the full vertical edge")
equal(left.point, "TOPLEFT")
equal(right.point, "TOPRIGHT")
equal(right.width, 6)
equal(right.height, 56)
equal(top.durationOptions.direction, Enum.StatusBarTimerDirection.ElapsedTime)
equal(left.durationOptions.direction, Enum.StatusBarTimerDirection.RemainingTime)
equal(secondTop.durationOptions.direction, Enum.StatusBarTimerDirection.RemainingTime)
equal(right.durationOptions.direction, Enum.StatusBarTimerDirection.ElapsedTime)
equal(top.bar.orientation, "HORIZONTAL")
equal(left.bar.orientation, "VERTICAL")
equal(mixed.level, 0, "the shared parent must stay below every individual frame level")
equal(top.bar.level, 27)
equal(left.bar.level, 14)
equal(secondTop.bar.level, 87, "a high frame level must not raise other buffs")
equal(right.bar.level, 2, "negative offsets must clamp without affecting other buffs")

Addon:ChangeBuffIndicator(1, { enabled = false })
Addon:UpdateBuffIndicators(mixedFrame)
equal(secondTop.x, 50, "disabled buffs should reserve their space on their own edge")
equal(left.height, 56)
Addon:ChangeBuffIndicator(2, { position = "TOP" })
Addon:UpdateBuffIndicators(mixedFrame)
equal(left.x, 34, "moving a buff should redistribute only its old and new edges")
equal(left.width, 31)
equal(left.height, 5)
equal(left.bar.orientation, "HORIZONTAL")
equal(secondTop.x, 66)
equal(right.height, 56)
Addon:ChangeBuffIndicator(1, { position = "BOTTOM" })
Addon:UpdateBuffIndicators(mixedFrame)
equal(left.x, 2)
equal(left.width, 47)
equal(secondTop.x, 50)
restricted = true
Addon:ChangeBuffIndicator(2, { position = "RIGHT", frameLevel = 50 })
Addon:UpdateBuffIndicators(mixedFrame)
equal(mixed.shown, false)
equal(left.bar.level, 14, "per-buff edits must wait for forbidden children to become accessible")
restricted = false
Addon:UpdateBuffIndicators(mixedFrame)
equal(left.bar.level, 57)
equal(left.point, "TOPRIGHT")
equal(left.height, 27)
equal(right.y, -30)
equal(right.height, 28)
equal(secondTop.width, 96)
Addon:RemoveBuffIndicator(1)
Addon:UpdateBuffIndicators(mixedFrame)
equal(mixed.slots["1"].filters.includeSpellIDs[774], true)
equal(top.point, "TOPRIGHT", "removing another buff must preserve this buff's settings in a reused slot")
equal(top.width, 5)
equal(top.bar.level, 57)
equal(top.durationOptions.direction, Enum.StatusBarTimerDirection.RemainingTime)
equal(mixed.slots["2"].button.bar.level, 87)
restricted = true
local coldMixedFrame = UnitFrame("raid2")
Addon:UpdateBuffIndicators(coldMixedFrame)
local coldMixed = containers[#containers]
equal(coldMixed.slots["1"].button.point, "TOPRIGHT", "mixed layouts must initialize safely under restrictions")
equal(coldMixed.slots["2"].button.point, "TOPLEFT")
equal(coldMixed.slots["1"].button.bar.level, 57)
equal(coldMixed.slots["2"].button.bar.level, 87)
equal(coldMixed.slots["3"].button.bar.level, 2)

local normalized = Addon:NormalizeBuffIndicators({
    { spellID = 364343, r = -5, g = 2, b = 0 / 0 },
    { spellID = 364343 },
    { spellID = -1 },
    { spellID = math.huge },
    { spellID = "invalid" },
    false,
})
equal(#normalized, 1, "invalid or duplicate saved entries must be discarded")
equal(normalized[1].r, 0)
equal(normalized[1].g, 1)
equal(normalized[1].b, 0.4)
equal(normalized[1].thickness, 2)
equal(normalized[1].direction, "ELAPSED")
equal(normalized[1].position, "TOP")
equal(normalized[1].frameLevel, 10)
local malformed = Addon:NormalizeBuffIndicators({
    { spellID = 364343, thickness = 100, direction = "invalid", position = false, frameLevel = -500 },
})[1]
equal(malformed.thickness, 12)
equal(malformed.direction, "ELAPSED")
equal(malformed.position, "TOP")
equal(malformed.frameLevel, -10)
local many = {}
for index = 1, 20 do many[index] = { spellID = index } end
equal(#Addon:NormalizeBuffIndicators(many), Addon.MAX_BUFF_INDICATORS)
equal(Addon:NormalizeBuffIndicatorHeight(nil), 2)
equal(Addon:NormalizeBuffIndicatorHeight(0 / 0), 2)
equal(Addon:NormalizeBuffIndicatorHeight(-10), 1)
equal(Addon:NormalizeBuffIndicatorHeight(100), 12)
equal(Addon:NormalizeBuffIndicatorHeight(3.7), 4)
equal(Addon:NormalizeBuffIndicatorDirection("invalid"), "ELAPSED")
equal(Addon:NormalizeBuffIndicatorPosition("invalid"), "TOP")
equal(Addon:NormalizeBuffIndicatorPosition("LEFT"), "LEFT")
equal(Addon:NormalizeBuffIndicatorPosition("RIGHT"), "RIGHT")
equal(Addon:NormalizeBuffIndicatorFrameLevel(nil), 10)
equal(Addon:NormalizeBuffIndicatorFrameLevel(0 / 0), 10)
equal(Addon:NormalizeBuffIndicatorFrameLevel(-500), -10)
equal(Addon:NormalizeBuffIndicatorFrameLevel(500), 200)

print("PASS: buff_indicators_test")
