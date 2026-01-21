local ADDON_NAME, Addon = ...

local editModeButton = nil

local function CreateEditModeButton()
    if editModeButton then return editModeButton end
    
    local button = CreateFrame("Button", "BRFEditModeButton", UIParent, "UIPanelButtonTemplate")
    button:SetSize(140, 22)
    button:SetText("Better Raid Frames")
    button:SetFrameStrata("HIGH")
    button:Hide()
    
    button:SetScript("OnClick", function()
        Addon:OpenConfig()
    end)
    
    editModeButton = button
    return button
end

local function PositionButton()
    if not editModeButton then return end
    
    local parent = nil
    
    if CompactPartyFrame and CompactPartyFrame:IsShown() then
        parent = CompactPartyFrame
    elseif CompactRaidFrameContainer and CompactRaidFrameContainer:IsShown() then
        parent = CompactRaidFrameContainer
    elseif PartyFrame and PartyFrame:IsShown() then
        parent = PartyFrame
    end
    
    editModeButton:ClearAllPoints()
    
    if parent then
        editModeButton:SetPoint("TOP", parent, "BOTTOM", 0, -5)
    else
        editModeButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
end

local function OnEditModeEnter()
    local button = CreateEditModeButton()
    PositionButton()
    button:Show()
    Addon:UpdateAllFrames()
end

local function OnEditModeExit()
    if editModeButton then
        editModeButton:Hide()
    end
    Addon:UpdateAllFrames()
end

function Addon:HookEditMode()
    if not EditModeManagerFrame then return end
    
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", OnEditModeEnter)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", OnEditModeExit)
    
    if EditModeManagerFrame:IsShown() then
        OnEditModeEnter()
    end
end
