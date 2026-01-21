local ADDON_NAME, Addon = ...

local function UpdateIncomingHeals(frame)
    if not frame then return end
    
    local unit = frame.unit
    if not unit then return end
    if unit ~= "player" and not unit:match("^party%d$") and not unit:match("^raid%d+$") then
        return
    end
    
    if BetterRaidFramesDB.hideIncomingHeals then
        if frame.myHealPrediction then frame.myHealPrediction:Hide() end
        if frame.otherHealPrediction then frame.otherHealPrediction:Hide() end
        if frame.myHealAbsorb then frame.myHealAbsorb:Hide() end
        if frame.myHealAbsorbLeftShadow then frame.myHealAbsorbLeftShadow:Hide() end
        if frame.myHealAbsorbRightShadow then frame.myHealAbsorbRightShadow:Hide() end
    else
        if frame.myHealPrediction then frame.myHealPrediction:Show() end
        if frame.otherHealPrediction then frame.otherHealPrediction:Show() end
    end
end

function Addon:HookIncomingHeals()
    if CompactUnitFrame_UpdateHealPrediction then
        hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
            UpdateIncomingHeals(frame)
        end)
    end
    
    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        UpdateIncomingHeals(frame)
    end)
end

function Addon:UpdateIncomingHeals(frame)
    UpdateIncomingHeals(frame)
end

function Addon:RefreshIncomingHeals()
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then UpdateIncomingHeals(frame) end
    end
    
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then UpdateIncomingHeals(frame) end
    end
    
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then UpdateIncomingHeals(frame) end
        end
    end
end
