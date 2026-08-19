local _, Addon = ...

local MAX_RAID_GROUPS = 8

Addon.RaidFrameGrowthOptions = {
    { value = "RIGHT", label = "Grow right" },
    { value = "LEFT", label = "Grow left" },
}

local anchorCoordinates = {
    TOPLEFT = { 0, 1 },
    TOP = { 0.5, 1 },
    TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 },
    CENTER = { 0.5, 0.5 },
    RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 },
    BOTTOM = { 0.5, 0 },
    BOTTOMRIGHT = { 1, 0 },
}

local growthLayouts = {
    RIGHT = {
        containerAnchor = "TOPLEFT",
        firstPoint = "TOPLEFT",
        nextPoint = "TOPLEFT",
        previousPoint = "TOPRIGHT",
    },
    LEFT = {
        containerAnchor = "TOPRIGHT",
        firstPoint = "TOPRIGHT",
        nextPoint = "TOPRIGHT",
        previousPoint = "TOPLEFT",
    },
}

local initialized = false
local refreshQueued = false
local refreshScheduled = false

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function GetGrowthLayout(growth)
    return growthLayouts[growth] or growthLayouts.RIGHT
end

local function UsesSeparateRaidGroups(container)
    if not container or not container.GetSettingValue or not Enum
        or not Enum.EditModeUnitFrameSetting or not Enum.RaidGroupDisplayType
    then
        return false
    end

    local displayType = container:GetSettingValue(Enum.EditModeUnitFrameSetting.RaidGroupDisplayType)
    return displayType == Enum.RaidGroupDisplayType.SeparateGroupsHorizontal
        or displayType == Enum.RaidGroupDisplayType.SeparateGroupsVertical
end

local function ApplyContainerAnchor(frame, targetPoint)
    if not frame or not frame.GetPoint or not frame.SetPoint then return end

    local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(1)
    local source = anchorCoordinates[point]
    local target = anchorCoordinates[targetPoint]
    if not source or point == targetPoint then return end

    local width, height = frame:GetSize()
    width = width or 0
    height = height or 0
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    frame:ClearAllPoints()
    frame:SetPoint(
        targetPoint,
        relativeTo,
        relativePoint,
        offsetX + (target[1] - source[1]) * width,
        offsetY + (target[2] - source[2]) * height
    )
end

local function LayoutRaidGroups(container, layout)
    -- Do not mutate container.flowFrames/isFlowGroup or call container:TryUpdate().
    -- Those paths can taint protected CompactUnitFrame updates in Midnight.
    local previous
    for groupIndex = 1, MAX_RAID_GROUPS do
        local group = _G["CompactRaidGroup" .. groupIndex]
        if group and group.IsShown and group:IsShown() then
            group:ClearAllPoints()
            if previous then
                group:SetPoint(layout.nextPoint, previous, layout.previousPoint, 0, 0)
            else
                group:SetPoint(layout.firstPoint, container, layout.firstPoint, 0, 0)
            end
            previous = group
        end
    end
end

function Addon:UpdateRaidFrameLayout(settings)
    if InCombat() then
        refreshQueued = true
        return false
    end

    local container = CompactRaidFrameContainer
    settings = settings or self:GetSettings()
    if not container or not settings then return false end

    local separateGroups = UsesSeparateRaidGroups(container)
    local layout = separateGroups and GetGrowthLayout(settings.raidFrameGrowth) or growthLayouts.RIGHT
    ApplyContainerAnchor(container, layout.containerAnchor)
    if separateGroups then LayoutRaidGroups(container, layout) end

    refreshQueued = false
    return true
end


local function FlushScheduledRefresh()
    refreshScheduled = false
    Addon:UpdateRaidFrameLayout()
end

local function RequestRefresh()
    if InCombat() then
        refreshQueued = true
        return
    end
    if refreshScheduled then return end

    -- Run after Blizzard's secure Edit Mode/roster update stack has finished.
    refreshScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, FlushScheduledRefresh)
    else
        FlushScheduledRefresh()
    end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" and refreshQueued then
        RequestRefresh()
    end
end

function Addon:InitializeRaidFrameLayout()
    if initialized then return end
    if not CompactRaidFrameContainer or not EditModeManagerFrame then
        return false
    end
    initialized = true

    if CompactRaidFrameContainer.OnDragStop then
        hooksecurefunc(CompactRaidFrameContainer, "OnDragStop", RequestRefresh)
    end
    if CompactRaidFrameContainer.UpdateSystem then
        hooksecurefunc(CompactRaidFrameContainer, "UpdateSystem", RequestRefresh)
    end
    if CompactRaidFrameContainer.TryUpdate then
        hooksecurefunc(CompactRaidFrameContainer, "TryUpdate", RequestRefresh)
    end
    if EditModeManagerFrame.UpdateRaidContainerFlow then
        hooksecurefunc(EditModeManagerFrame, "UpdateRaidContainerFlow", RequestRefresh)
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", OnEvent)
    return true
end
