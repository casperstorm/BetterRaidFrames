local ADDON_NAME, Addon = ...

local function UpdateDispelIndicator(frame)
    if not frame or not frame.dispelDebuffFrames then return end

    if not BetterRaidFramesDB.hideDispelIndicator then return end

    for _, dispelFrame in ipairs(frame.dispelDebuffFrames) do
        dispelFrame:Hide()
    end
end

function Addon:HookDispelIndicator()
    hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
        if BetterRaidFramesDB.hideDispelIndicator then
            UpdateDispelIndicator(frame)
        end
    end)

    if CompactUnitFrame_UtilSetDispelDebuff then
        hooksecurefunc("CompactUnitFrame_UtilSetDispelDebuff", function(dispelFrame)
            if BetterRaidFramesDB.hideDispelIndicator then
                dispelFrame:Hide()
            end
        end)
    end
end

function Addon:RefreshDispelIndicator()
    Addon:ForEachFrame(UpdateDispelIndicator)
end
