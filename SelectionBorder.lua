local ADDON_NAME, Addon = ...

local function IsRaidOrPartyFrame(frame)
    if not frame or not frame.unit then return false end
    local unit = frame.unit
    return unit == "player" or 
           string.match(unit, "^party%d") or 
           string.match(unit, "^raid%d")
end

local function HideSelectionHighlight(frame)
    if not frame then return end

    if frame.selectionHighlight and frame.selectionHighlight.Hide then
        frame.selectionHighlight:Hide()
    end

    if frame.SelectionHighlight and frame.SelectionHighlight.Hide then
        frame.SelectionHighlight:Hide()
    end
end

local function ShowSelectionHighlight(frame)
    if not frame then return end

    if frame.selectionHighlight and frame.selectionHighlight.Show then
        if frame.unit and UnitIsUnit(frame.unit, "target") then
            frame.selectionHighlight:Show()
        end
    end

    if frame.SelectionHighlight and frame.SelectionHighlight.Show then
        if frame.unit and UnitIsUnit(frame.unit, "target") then
            frame.SelectionHighlight:Show()
        end
    end
end

function Addon:HookSelectionBorder()
    hooksecurefunc("CompactUnitFrame_UpdateSelectionHighlight", function(frame)
        if not IsRaidOrPartyFrame(frame) then return end
        if Addon:GetSetting("hideSelectionBorder") then
            HideSelectionHighlight(frame)
        end
    end)
end

function Addon:UpdateSelectionBorder(frame)
    if Addon:GetSetting("hideSelectionBorder") then
        HideSelectionHighlight(frame)
    else
        ShowSelectionHighlight(frame)
    end
end

function Addon:RefreshSelectionBorders()
    Addon:ForEachFrame(function(frame)
        Addon:UpdateSelectionBorder(frame)
    end)
end
