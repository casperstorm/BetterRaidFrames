local ADDON_NAME, Addon = ...

local HOSTILE_TEXTURE = "Interface\\AddOns\\BetterRaidFrames\\Media\\shield"

local function RestoreBlizzardHealAbsorb(frame)
    if not frame then return end
    if frame.myHealAbsorb then frame.myHealAbsorb:Show() end
    if frame.myHealAbsorbLeftShadow then frame.myHealAbsorbLeftShadow:Show() end
    if frame.myHealAbsorbRightShadow then frame.myHealAbsorbRightShadow:Show() end
    if frame.myHealAbsorbOverlay then frame.myHealAbsorbOverlay:Show() end
end

local function UpdateHostileAbsorb(frame)
    if not frame or not frame.healthBar then return end
    
    if not Addon:GetSetting("showHostileAbsorb") then
        if frame.BRFHostileAbsorbBar then
            frame.BRFHostileAbsorbBar:Hide()
        end
        RestoreBlizzardHealAbsorb(frame)
        return
    end
    
    local unit = frame.unit
    if not unit or not UnitExists(unit) then return end
    
    local maxHealth = UnitHealthMax(unit)
    local healAbsorb = UnitGetTotalHealAbsorbs(unit)
    
    if Addon:IsConfigOpen() then
        healAbsorb = maxHealth * 0.25
    end
    
    if frame.myHealAbsorb then frame.myHealAbsorb:Hide() end
    if frame.myHealAbsorbLeftShadow then frame.myHealAbsorbLeftShadow:Hide() end
    if frame.myHealAbsorbRightShadow then frame.myHealAbsorbRightShadow:Hide() end
    if frame.myHealAbsorbOverlay then frame.myHealAbsorbOverlay:Hide() end
    
    if not frame.BRFHostileAbsorbBar then
        local bar = CreateFrame("StatusBar", nil, frame.healthBar)
        bar:SetMinMaxValues(0, 1)
        bar:EnableMouse(false)
        bar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 3)
        bar:SetStatusBarTexture(HOSTILE_TEXTURE)
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(false)
            barTex:SetVertTile(false)
            barTex:SetTexCoord(0, 1, 0, 1)
            barTex:SetDrawLayer("ARTWORK", 3)
        end
        bar:SetAllPoints(frame.healthBar)
        bar:SetOrientation("HORIZONTAL")
        bar:SetReverseFill(false)
        frame.BRFHostileAbsorbBar = bar
    end
    
    local bar = frame.BRFHostileAbsorbBar
    local opacity = Addon:GetSetting("hostileAbsorbOpacity") or 0.7
    local r = Addon:GetSetting("hostileAbsorbColorR") or 0.4
    local g = Addon:GetSetting("hostileAbsorbColorG") or 0.1
    local b = Addon:GetSetting("hostileAbsorbColorB") or 0.1
    bar:SetStatusBarColor(r, g, b, opacity)
    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(healAbsorb)
    bar:Show()
end

function Addon:HookHostileAbsorb()
    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        UpdateHostileAbsorb(frame)
    end)

    if CompactUnitFrame_UpdateHealPrediction then
        hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
            if not Addon:IsRaidOrPartyFrame(frame) then return end
            UpdateHostileAbsorb(frame)
        end)
    end

    hooksecurefunc("CompactUnitFrame_UpdateHealth", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        UpdateHostileAbsorb(frame)
    end)

    -- Listen for heal absorb changes (e.g., when dispelled)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
    eventFrame:SetScript("OnEvent", function(self, event, unit)
        Addon:RefreshHostileAbsorbs()
    end)
end

function Addon:UpdateHostileAbsorb(frame)
    UpdateHostileAbsorb(frame)
end

function Addon:RefreshHostileAbsorbs()
    Addon:ForEachFrame(UpdateHostileAbsorb)
end
