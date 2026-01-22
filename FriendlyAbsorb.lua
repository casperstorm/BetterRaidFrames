local ADDON_NAME, Addon = ...

local OVERLAY_TEXTURE = "Interface\\AddOns\\BetterRaidFrames\\Media\\shield"

local function RestoreBlizzardAbsorb(frame)
    if not frame then return end
    if frame.overAbsorbGlow then frame.overAbsorbGlow:Show() end
    if frame.totalAbsorb then frame.totalAbsorb:Show() end
    if frame.totalAbsorbOverlay then frame.totalAbsorbOverlay:Show() end
end

local function UpdateFriendlyAbsorb(frame)
    if not frame or not frame.healthBar then return end
    
    if not Addon:GetSetting("showFriendlyAbsorb") then
        if frame.BRFFriendlyAbsorbBar then
            frame.BRFFriendlyAbsorbBar:Hide()
        end
        RestoreBlizzardAbsorb(frame)
        return
    end
    
    local unit = frame.unit
    if not unit or not UnitExists(unit) then return end
    
    local maxHealth = UnitHealthMax(unit)
    local absorbs = UnitGetTotalAbsorbs(unit)
    
    if Addon:IsConfigOpen() then
        absorbs = maxHealth * 0.5
    end
    
    if frame.overAbsorbGlow then frame.overAbsorbGlow:Hide() end
    if frame.totalAbsorb then frame.totalAbsorb:Hide() end
    if frame.totalAbsorbOverlay then frame.totalAbsorbOverlay:Hide() end
    
    if not frame.BRFFriendlyAbsorbBar then
        local bar = CreateFrame("StatusBar", nil, frame.healthBar)
        bar:SetMinMaxValues(0, 1)
        bar:EnableMouse(false)
        bar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 2)
        bar:SetStatusBarTexture(OVERLAY_TEXTURE)
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(false)
            barTex:SetVertTile(false)
            barTex:SetTexCoord(0, 1, 0, 1)
            barTex:SetDrawLayer("ARTWORK", 2)
        end
        bar:SetAllPoints(frame.healthBar)
        bar:SetOrientation("HORIZONTAL")
        bar:SetReverseFill(true)
        frame.BRFFriendlyAbsorbBar = bar
    end
    
    local bar = frame.BRFFriendlyAbsorbBar
    local opacity = Addon:GetSetting("friendlyAbsorbOpacity") or 0.8
    local r = Addon:GetSetting("friendlyAbsorbColorR") or 1
    local g = Addon:GetSetting("friendlyAbsorbColorG") or 1
    local b = Addon:GetSetting("friendlyAbsorbColorB") or 1
    bar:SetStatusBarColor(r, g, b, opacity)
    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(absorbs)
    bar:Show()
end

function Addon:HookFriendlyAbsorb()
    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        UpdateFriendlyAbsorb(frame)
    end)
    
    if CompactUnitFrame_UpdateHealPrediction then
        hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
            if not Addon:IsRaidOrPartyFrame(frame) then return end
            UpdateFriendlyAbsorb(frame)
        end)
    end
    
    hooksecurefunc("CompactUnitFrame_UpdateHealth", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        UpdateFriendlyAbsorb(frame)
    end)
end

function Addon:UpdateFriendlyAbsorb(frame)
    UpdateFriendlyAbsorb(frame)
end

function Addon:RefreshFriendlyAbsorbs()
    Addon:ForEachFrame(UpdateFriendlyAbsorb)
end
