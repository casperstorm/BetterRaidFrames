local ADDON_NAME, Addon = ...

local raidMarkersHooked = false
local MARKER_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local markerSettings = {
    enabled = true,
    size = 16,
    x = 0,
    y = 2,
}
local refreshThrottleFrame = nil

local function LoadMarkerSettings()
    markerSettings.enabled = Addon:GetSetting("showRaidMarkers")
    markerSettings.size = Addon:GetSetting("raidMarkerSize") or 16
    markerSettings.x = Addon:GetSetting("raidMarkerX") or 0
    markerSettings.y = Addon:GetSetting("raidMarkerY") or 2
end

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

local function ApplyRaidMarkerSettings(frame, icon)
    if icon.BRFSize ~= markerSettings.size then
        icon:SetSize(markerSettings.size, markerSettings.size)
        icon.BRFSize = markerSettings.size
    end

    if icon.BRFOffsetX ~= markerSettings.x or icon.BRFOffsetY ~= markerSettings.y then
        icon:ClearAllPoints()
        icon:SetPoint("TOP", frame, "TOP", markerSettings.x, markerSettings.y)
        icon.BRFOffsetX = markerSettings.x
        icon.BRFOffsetY = markerSettings.y
    end
end

local function UpdateRaidMarker(frame)
    if not frame or not Addon:IsRaidOrPartyFrame(frame) then return end

    local icon = GetOrCreateRaidMarker(frame)

    if not markerSettings.enabled then
        if icon:IsShown() then
            icon:Hide()
        end
        return
    end

    local unit = frame.displayedUnit or frame.unit
    if not unit or not UnitExists(unit) then
        if icon:IsShown() then
            icon:Hide()
        end
        return
    end

    local index = nil
    local gotIndex = pcall(function()
        index = GetRaidTargetIndex(unit)
    end)

    if not gotIndex then
        if icon:IsShown() then
            icon:Hide()
        end
        return
    end

    if not index then
        if icon:IsShown() then
            icon:Hide()
        end
        return
    end

    local setTextureOk = pcall(function()
        SetRaidTargetIconTexture(icon, index)
    end)
    if not setTextureOk then
        if icon.SetSpriteSheetCell then
            local spriteOk = pcall(function()
                icon:SetTexture(MARKER_TEXTURE)
                icon:SetSpriteSheetCell(index, 4, 4, 64, 64)
            end)
            if not spriteOk then
                if icon:IsShown() then
                    icon:Hide()
                end
                return
            end
        else
            if icon:IsShown() then
                icon:Hide()
            end
            return
        end
    end

    ApplyRaidMarkerSettings(frame, icon)
    if not icon:IsShown() then
        icon:Show()
    end
end

local function QueueRefresh()
    if not refreshThrottleFrame then
        refreshThrottleFrame = CreateFrame("Frame")
        refreshThrottleFrame:Hide()
        refreshThrottleFrame:SetScript("OnUpdate", function(self)
            self:Hide()
            Addon:RefreshRaidMarkers()
        end)
    end
    refreshThrottleFrame:Show()
end

function Addon:HookRaidMarkers()
    if raidMarkersHooked then return end
    raidMarkersHooked = true
    LoadMarkerSettings()

    if CompactUnitFrame_UpdateRaidTargetIcon then
        hooksecurefunc("CompactUnitFrame_UpdateRaidTargetIcon", function(frame)
            UpdateRaidMarker(frame)
        end)
    end

    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        UpdateRaidMarker(frame)
    end)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        QueueRefresh()
    end)
end

function Addon:UpdateRaidMarker(frame)
    UpdateRaidMarker(frame)
end

function Addon:RefreshRaidMarkers()
    LoadMarkerSettings()
    Addon:ForEachFrame(function(frame)
        UpdateRaidMarker(frame)
    end)
end
