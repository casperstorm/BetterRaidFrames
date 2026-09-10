local _, Addon = ...

local managedFrame, watchedFrame
local hooked, updating = false, false
-- "ignore" leaves Blizzard in charge whenever there is a group. The shared
-- secure driver can show the existing player entry while solo, even in combat.
local SOLO_VISIBILITY = "[group] ignore; show"

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function Accessible(frame)
    if not frame then return false end
    local allowed = frame:CanBeAccessedInContext()
    return not Secret(allowed) and allowed
end

local function QueueUpdate()
    if not updating and (managedFrame or Addon:GetSetting("showSolo")) then
        Addon:RequestFeatureUpdate("soloFrame")
    end
end

local function SetShown(frame, shown)
    local current = frame:IsShown()
    if Secret(current) or current == shown then return end
    frame:SetShown(shown)
    -- Keep Blizzard's party anchor/padding, including the first solo login
    -- before this container has ever participated in the visible layout.
    PartyFrame:UpdatePaddingAndLayout()
end

function Addon:RefreshSoloFrame(settings)
    if InCombatLockdown() then return end
    settings = settings or self:GetSettings()
    if not settings.showSolo and not managedFrame then return end
    if not Accessible(PartyFrame) then return end

    local manager = EditModeManagerFrame
    local enabled = settings.showSolo and manager and manager:UseRaidStylePartyFrames()
        and not self:IsEditModeActive()
    local frame = CompactPartyFrame

    if managedFrame and (not enabled or managedFrame ~= frame) then
        if not Accessible(managedFrame) then return end
        local nativeShown = managedFrame:ShouldShow()
        if Secret(nativeShown) then return end
        updating = true
        UnregisterStateDriver(managedFrame, "visibility")
        SetShown(managedFrame, nativeShown)
        managedFrame = nil
        updating = false
    end
    if not enabled or not Accessible(frame) then return end

    updating = true
    if watchedFrame ~= frame then
        hooksecurefunc(frame, "UpdateVisibility", QueueUpdate)
        frame:HookScript("OnShow", QueueUpdate)
        watchedFrame = frame
    end
    if not managedFrame then
        -- Registering may show the frame immediately; update the parent layout
        -- once afterwards rather than doing layout work in a combat callback.
        RegisterStateDriver(frame, "visibility", SOLO_VISIBILITY)
        managedFrame = frame
        PartyFrame:UpdatePaddingAndLayout()
    end
    if not IsInGroup() then SetShown(frame, true) end
    updating = false
end

function Addon:HookSoloFrame()
    if hooked then return end
    hooked = true
    hooksecurefunc("CompactPartyFrame_Generate", QueueUpdate)
    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", QueueUpdate)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", QueueUpdate)
    end
    local events = CreateFrame("Frame")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    events:SetScript("OnEvent", QueueUpdate)
end
