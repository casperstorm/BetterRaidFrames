local _, Addon = ...
local stringFind = string.find
local stringSub = string.sub

Addon.AnchorOptions = {
    { value = "TOPLEFT", label = "Top left" },
    { value = "TOP", label = "Top" },
    { value = "TOPRIGHT", label = "Top right" },
    { value = "LEFT", label = "Left" },
    { value = "CENTER", label = "Center" },
    { value = "RIGHT", label = "Right" },
    { value = "BOTTOMLEFT", label = "Bottom left" },
    { value = "BOTTOM", label = "Bottom" },
    { value = "BOTTOMRIGHT", label = "Bottom right" },
}

local validAnchors = {}
for _, option in ipairs(Addon.AnchorOptions) do
    validAnchors[option.value] = true
end

local raidFrameNames = {}
local groupedRaidFrameNames = {}
local partyFrameNames = {}
for index = 1, 40 do
    raidFrameNames[index] = "CompactRaidFrame" .. index
end
for group = 1, 8 do
    for member = 1, 5 do
        groupedRaidFrameNames[#groupedRaidFrameNames + 1] = "CompactRaidGroup" .. group .. "Member" .. member
    end
end
for index = 1, 5 do
    partyFrameNames[index] = "CompactPartyFrameMember" .. index
end

local visitedFrames = {}
local visitGeneration = 0

local function VisitFrame(frame, callback, generation)
    if frame and visitedFrames[frame] ~= generation then
        visitedFrames[frame] = generation
        callback(frame)
    end
end

function Addon:GetValidAnchor(anchor, fallback)
    if validAnchors[anchor] then return anchor end
    if validAnchors[fallback] then return fallback end
    return "CENTER"
end

function Addon:ApplyRegionLayout(region, parent, point, relativePoint, offsetX, offsetY, size)
    if region.BRFSize ~= size then
        region:SetSize(size, size)
        region.BRFSize = size
    end

    if region.BRFPoint ~= point or region.BRFRelativePoint ~= relativePoint
        or region.BRFOffsetX ~= offsetX or region.BRFOffsetY ~= offsetY
    then
        region:ClearAllPoints()
        region:SetPoint(point, parent, relativePoint, offsetX, offsetY)
        region.BRFPoint = point
        region.BRFRelativePoint = relativePoint
        region.BRFOffsetX = offsetX
        region.BRFOffsetY = offsetY
    end
end

function Addon:IsRaidOrPartyFrame(frame)
    if not frame or not frame.unit then return false end
    local unit = frame.unit
    -- Nameplates can expose unit="player" in some contexts.
    -- Only accept player when the frame is an actual Compact Party/Raid frame.
    if unit == "player" then
        local frameName = frame.GetName and frame:GetName()
        if not frameName then return false end
        if stringFind(frameName, "^CompactPartyFrame") then return true end
        if stringFind(frameName, "^CompactRaidFrame") then return true end
        if stringFind(frameName, "^CompactRaidGroup") then return true end
        return false
    end

    -- Use string.sub for lightweight prefix checks.
    local p4 = stringSub(unit, 1, 4)
    if p4 == "raid" then return true end
    local p5 = stringSub(unit, 1, 5)
    if p5 == "party" then return true end
    return false
end

function Addon:ForEachFrame(callback)
    visitGeneration = visitGeneration + 1
    local generation = visitGeneration

    if IsInRaid() then
        for index = 1, #raidFrameNames do
            VisitFrame(_G[raidFrameNames[index]], callback, generation)
        end
        for index = 1, #groupedRaidFrameNames do
            VisitFrame(_G[groupedRaidFrameNames[index]], callback, generation)
        end
    else
        for index = 1, #partyFrameNames do
            VisitFrame(_G[partyFrameNames[index]], callback, generation)
        end
    end
end
