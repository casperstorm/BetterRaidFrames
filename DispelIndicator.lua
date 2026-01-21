local ADDON_NAME, Addon = ...

local function IsEditMode()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

local function IsRaidOrPartyFrame(frame)
    if not frame or not frame.unit then return false end
    local unit = frame.unit
    return unit == "player" or 
           string.match(unit, "^party%d") or 
           string.match(unit, "^raid%d")
end

local function UpdateDispelIndicator(frame)
    if not frame or not frame.dispelDebuffFrames then return end
    if not Addon:GetSetting("hideDispelIndicator") then return end

    for i = 1, #frame.dispelDebuffFrames do
        local dispelFrame = frame.dispelDebuffFrames[i]
        if dispelFrame then
            dispelFrame:Hide()
        end
    end
end

function Addon:HookDispelIndicator()
    hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
        if IsEditMode() then return end
        if not IsRaidOrPartyFrame(frame) then return end
        if not frame.dispelDebuffFrames then return end
        if Addon:GetSetting("hideDispelIndicator") then
            UpdateDispelIndicator(frame)
        end
    end)

    if CompactUnitFrame_UtilSetDispelDebuff then
        hooksecurefunc("CompactUnitFrame_UtilSetDispelDebuff", function(dispelFrame)
            if IsEditMode() then return end
            if Addon:GetSetting("hideDispelIndicator") and dispelFrame and dispelFrame.Hide then
                dispelFrame:Hide()
            end
        end)
    end
end

function Addon:RefreshDispelIndicator()
    if IsEditMode() then return end
    Addon:ForEachFrame(UpdateDispelIndicator)
end
