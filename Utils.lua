local ADDON_NAME, Addon = ...

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
