local _, Addon = ...
local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local UnitExists = UnitExists
local hooksecurefunc = hooksecurefunc

local raidMarkersHooked = false
local MARKER_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local function GetOrCreateRaidMarker(frame)
    if frame.BRFRaidMarker then
        return frame.BRFRaidMarker
    end

    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(MARKER_TEXTURE)
    icon:Hide()
    frame.BRFRaidMarker = icon
    return icon
end

local function ApplyRaidMarkerSettings(frame, icon, settings)
    local size = settings.raidMarkerSize or 16
    local point = Addon:GetValidAnchor(settings.raidMarkerPoint, "TOP")
    local relativePoint = Addon:GetValidAnchor(settings.raidMarkerRelativePoint, "TOP")
    local offsetX = settings.raidMarkerOffsetX or 0
    local offsetY = settings.raidMarkerOffsetY or 2

    Addon:ApplyRegionLayout(icon, frame, point, relativePoint, offsetX, offsetY, size)
end

local function UpdateRaidMarker(frame, settings)
    if not frame or (not settings and not Addon:IsRaidOrPartyFrame(frame)) then return end
    settings = settings or Addon:GetSettings()

    if not settings.showRaidMarkers then
        if frame.BRFRaidMarker and frame.BRFRaidMarker:IsShown() then frame.BRFRaidMarker:Hide() end
        return
    end

    local icon = GetOrCreateRaidMarker(frame)
    local unit = frame.displayedUnit or frame.unit
    if not unit or not UnitExists(unit) then
        if icon:IsShown() then icon:Hide() end
        return
    end

    local index = GetRaidTargetIndex(unit)
    if not index then
        if icon:IsShown() then icon:Hide() end
        return
    end

    SetRaidTargetIconTexture(icon, index)

    ApplyRaidMarkerSettings(frame, icon, settings)
    if not icon:IsShown() then
        icon:Show()
    end
end

function Addon:HookRaidMarkers()
    if raidMarkersHooked then return end
    raidMarkersHooked = true

    if CompactUnitFrame_UpdateRaidTargetIcon then
        hooksecurefunc("CompactUnitFrame_UpdateRaidTargetIcon", function(frame)
            UpdateRaidMarker(frame)
        end)
    end
end

function Addon:UpdateRaidMarker(frame, settings)
    UpdateRaidMarker(frame, settings)
end
