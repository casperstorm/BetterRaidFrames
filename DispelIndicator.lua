local ADDON_NAME, Addon = ...

local function UpdateDispelIndicator(frame)
    if not frame or not frame.dispelDebuffFrames then return end

    if not Addon:GetSetting("hideDispelIndicator") then return end

    for _, dispelFrame in ipairs(frame.dispelDebuffFrames) do
        dispelFrame:Hide()
    end
end

function Addon:HookDispelIndicator()
    hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
        if Addon:GetSetting("hideDispelIndicator") then
            UpdateDispelIndicator(frame)
        end
    end)

    if CompactUnitFrame_UtilSetDispelDebuff then
        hooksecurefunc("CompactUnitFrame_UtilSetDispelDebuff", function(dispelFrame)
            if Addon:GetSetting("hideDispelIndicator") then
                dispelFrame:Hide()
            end
        end)
    end
end

function Addon:RefreshDispelIndicator()
    Addon:ForEachFrame(UpdateDispelIndicator)
end
