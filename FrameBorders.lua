local _, Addon = ...
local unpack = unpack or table.unpack

local states = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local hooked = false

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function Number(value)
    return not Secret(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function Accessible(region)
    return region and not region:IsForbidden()
end

local function IsCompactFrame(frame)
    if not Accessible(frame) then return false end
    local name = frame:GetName()
    return not Secret(name) and type(name) == "string" and (name:match("^CompactPartyFrameMember%d+$")
        or name:match("^CompactRaidFrame%d+$") or name:match("^CompactRaidGroup%d+Member%d+$")) ~= nil
end

local function QueueUpdate()
    if not InCombatLockdown() and (Addon:GetSetting("crispFrameBorders") or next(states)) then
        Addon:RequestFeatureUpdate("frameBorders")
    end
end

local function ReadPoint(region, index)
    local point, relative, relativePoint, x, y = region:GetPoint(index)
    if Secret(point) or Secret(relative) or Secret(relativePoint) or not Number(x) or not Number(y) then return end
    return point, relative, relativePoint, x, y
end

local function Corners(region, topRelative, bottomRelative)
    if not Accessible(region) then return end
    local count = region:GetNumPoints()
    if Secret(count) or count ~= 2 then return end
    local top, bottom
    for index = 1, 2 do
        local point, relative, relativePoint, x, y = ReadPoint(region, index)
        if point == "TOPLEFT" and relative == topRelative then
            top = { point, relative, relativePoint, x, y }
        elseif point == "BOTTOMRIGHT" and relative == bottomRelative and relativePoint == "BOTTOMRIGHT" then
            bottom = { point, relative, relativePoint, x, y }
        else return end
    end
    if top and bottom then return { top = top, bottom = bottom } end
end

local function Capture(frame)
    local health = Corners(frame.healthBar, frame, frame)
    if not health or health.top[3] ~= "TOPLEFT" or health.top[4] ~= 1 or health.top[5] ~= -1 then return end
    local loss = frame.TempMaxHealthLoss
    if loss then
        if not Accessible(loss) or Secret(loss.ShouldAdjustHealthBarAnchor) or not loss.ShouldAdjustHealthBarAnchor
            or not Number(loss.xAnchorOffset) or not Number(loss.yAnchorOffset) then return end
        -- The current right anchor may include reduced max health. Save its
        -- normal base separately; never inspect or round a health percentage.
        health.bottom[4], health.bottom[5] = loss.xAnchorOffset, loss.yAnchorOffset
    end
    if health.bottom[4] ~= -1 or health.bottom[5] < 1 then return end
    local power
    if frame.powerBar then
        if not Accessible(frame.powerBar) then return end
        local shown = frame.powerBar:IsShown()
        if Secret(shown) then return end
        if shown then
            power = Corners(frame.powerBar, frame.healthBar, frame)
            if not power or power.top[3] ~= "BOTTOMLEFT" or power.top[4] ~= 0
                or power.bottom[4] ~= -1 or power.bottom[5] ~= 1 then return end
        end
    end
    return { health = health, power = power, loss = loss }
end

local function RightOffset(frame)
    local count = frame.healthBar:GetNumPoints()
    if Secret(count) or count ~= 2 then return end
    for index = 1, 2 do
        local point, relative, relativePoint, x = ReadPoint(frame.healthBar, index)
        if point == "BOTTOMRIGHT" and relative == frame and relativePoint == "BOTTOMRIGHT" then return x end
    end
end

local function SetCorners(region, corners)
    region:SetPoint(unpack(corners.top))
    region:SetPoint(unpack(corners.bottom))
end

local function Restore(frame, state)
    if not Accessible(frame) or not Accessible(frame.healthBar) or (state.loss and not Accessible(state.loss))
        or (state.power and not Accessible(frame.powerBar)) then return end
    local currentRight = RightOffset(frame)
    local original = state.health
    if state.loss then
        -- Anything but our own right anchor was written natively from the
        -- loss bar's untouched base offsets, and is already correct.
        if currentRight == state.right then SetCorners(frame.healthBar, original)
        else frame.healthBar:SetPoint(unpack(original.top)) end
    else
        if not currentRight then return end
        local adjustment = currentRight - state.right
        frame.healthBar:SetPoint(unpack(original.top))
        frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", original.bottom[4] + adjustment, original.bottom[5])
    end
    if state.power then SetCorners(frame.powerBar, state.power) end
    states[frame] = nil
end

local function Apply(frame)
    if not IsCompactFrame(frame) or not Accessible(frame.healthBar) then return end
    if not watched[frame] then
        frame:HookScript("OnSizeChanged", QueueUpdate)
        frame:HookScript("OnShow", QueueUpdate)
        watched[frame] = true
    end
    local visible = frame:IsVisible()
    if Secret(visible) or not visible then return end
    local left, bottom, width, height = frame:GetRect()
    local scale = frame:GetEffectiveScale()
    local factor = PixelUtil.GetPixelToUIUnitFactor()
    if not Number(left) or not Number(bottom) or not Number(width) or not Number(height)
        or not Number(scale) or not Number(factor) or scale <= 0 or factor <= 0 then return end
    local pixels = scale / factor
    if width * pixels <= 4 or height * pixels <= 4 then return end
    local state = states[frame]
    local currentRight = RightOffset(frame)
    if not currentRight then return end
    if state and state.left == left and state.bottom == bottom and state.width == width
        and state.height == height and state.pixels == pixels and currentRight == state.right then return end
    state = state or Capture(frame)
    if not state or (state.loss and not Accessible(state.loss)) or (state.power and not Accessible(frame.powerBar)) then return end
    local base = state.right or state.health.bottom[4]
    local adjustment = 0
    if state.loss then
        -- Blizzard re-anchors the right edge from the loss bar's offsets during
        -- max-health changes. Never write those offsets: addon values there
        -- taint its secret-value arithmetic. Only align while no reduction is
        -- applied; Blizzard's native reset is re-aligned on the next pass.
        if currentRight ~= base and currentRight ~= state.health.bottom[4] then return end
    else
        adjustment = currentRight - base
    end
    local function Round(value) return math.floor(value * pixels + 0.5) / pixels end
    local pixel = 1 / pixels
    -- Round the absolute screen edges, not just the relative offsets. Adjacent
    -- frames then share the same rounded boundary even at fractional heights.
    local x1 = Round(left) + pixel - left
    local y1 = Round(bottom + height) - pixel - (bottom + height)
    local x2 = Round(left + width) - pixel - (left + width)
    local y2 = Round(bottom + state.health.bottom[5] - 1) + pixel - bottom
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", x1, y1)
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", x2 + adjustment, y2)
    if state.power then
        local gap = PixelUtil.GetNearestPixelSize(state.power.top[5], scale)
        frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, gap)
        frame.powerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", x2, Round(bottom) + pixel - bottom)
    end
    state.left, state.bottom, state.width, state.height, state.pixels, state.right = left, bottom, width, height, pixels, x2
    states[frame] = state
end

function Addon:RefreshFrameBorders(settings)
    if InCombatLockdown() then return end
    settings = settings or self:GetSettings()
    if settings.crispFrameBorders then
        self:ForEachFrame(Apply)
    else
        -- Also restore retained frames from another party/raid layout or profile.
        for frame, state in pairs(states) do Restore(frame, state) end
    end
end

function Addon:HookFrameBorders()
    if hooked then return end
    hooked = true
    local function Setup(frame)
        if IsCompactFrame(frame) then
            -- Blizzard just restored native anchors, including the loss-bar
            -- offsets. Re-capture them after the complete layout pass finishes.
            states[frame] = nil
            QueueUpdate()
        end
    end
    if DefaultCompactUnitFrameSetup then hooksecurefunc("DefaultCompactUnitFrameSetup", Setup) end
    if DefaultCompactMiniFrameSetup then hooksecurefunc("DefaultCompactMiniFrameSetup", Setup) end
    if CompactUnitFrameUtil and CompactUnitFrameUtil.ApplyConfig then hooksecurefunc(CompactUnitFrameUtil, "ApplyConfig", Setup) end
    if CompactRaidGroup_UpdateLayout then hooksecurefunc("CompactRaidGroup_UpdateLayout", QueueUpdate) end
    if CompactRaidFrameContainer and CompactRaidFrameContainer.LayoutFrames then
        hooksecurefunc(CompactRaidFrameContainer, "LayoutFrames", QueueUpdate)
    end
    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", QueueUpdate)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", QueueUpdate)
    end
    local events = CreateFrame("Frame")
    events:RegisterEvent("UI_SCALE_CHANGED")
    events:RegisterEvent("DISPLAY_SIZE_CHANGED")
    events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", QueueUpdate)
end
