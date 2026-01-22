local ADDON_NAME, Addon = ...

function Addon:IsRaidOrPartyFrame(frame)
    if not frame or not frame.unit then return false end
    local unit = frame.unit
    -- Use string.sub for better performance (no temp string allocation like match)
    if unit == "player" then return true end
    local p4 = string.sub(unit, 1, 4)
    if p4 == "raid" then return true end
    local p5 = string.sub(unit, 1, 5)
    if p5 == "party" then return true end
    return false
end

function Addon:ForEachFrame(callback)
    if IsInRaid() then
        for i = 1, 40 do
            local frame = _G["CompactRaidFrame" .. i]
            if frame then callback(frame) end
        end
        for group = 1, 8 do
            for member = 1, 5 do
                local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
                if frame then callback(frame) end
            end
        end
    else
        for i = 1, 5 do
            local frame = _G["CompactPartyFrameMember" .. i]
            if frame then callback(frame) end
        end
    end
end
