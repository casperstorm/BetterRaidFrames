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
    if not BetterRaidFramesDB.showHostileAbsorb then
        if frame.BRFHostileAbsorbBar then
            frame.BRFHostileAbsorbBar:Hide()
        end
        RestoreBlizzardHealAbsorb(frame)
        return
    end
    
    local unit = frame.unit
    if not unit then return end
    if unit ~= "player" and not unit:match("^party%d$") and not unit:match("^raid%d+$") then
        return
    end
    if not UnitExists(unit) then return end
    
    local maxHealth = UnitHealthMax(unit)
    local healAbsorb = UnitGetTotalHealAbsorbs(unit)
    
    if Addon.testMode then
        healAbsorb = maxHealth * 0.25
    end
    
    if frame.myHealAbsorb then frame.myHealAbsorb:Hide() end
    if frame.myHealAbsorbLeftShadow then frame.myHealAbsorbLeftShadow:Hide() end
    if frame.myHealAbsorbRightShadow then frame.myHealAbsorbRightShadow:Hide() end
    if frame.myHealAbsorbOverlay then frame.myHealAbsorbOverlay:Hide() end
    
    if not frame.BRFHostileAbsorbBar then
        frame.BRFHostileAbsorbBar = CreateFrame("StatusBar", nil, frame)
        frame.BRFHostileAbsorbBar:SetMinMaxValues(0, 1)
        frame.BRFHostileAbsorbBar:EnableMouse(false)
    end
    
    local bar = frame.BRFHostileAbsorbBar
    local healthLevel = frame.healthBar:GetFrameLevel()
    
    bar:SetParent(frame.healthBar)
    bar:SetFrameStrata(frame:GetFrameStrata())
    bar:SetFrameLevel(healthLevel + 3)
    
    if bar.currentTexture ~= HOSTILE_TEXTURE then
        bar.currentTexture = HOSTILE_TEXTURE
        bar:SetStatusBarTexture(HOSTILE_TEXTURE)
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(false)
            barTex:SetVertTile(false)
            barTex:SetTexCoord(0, 1, 0, 1)
            barTex:SetDrawLayer("ARTWORK", 3)
        end
    end
    
    bar:SetStatusBarColor(0.4, 0.1, 0.1, 0.7)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, 0)
    bar:SetOrientation("HORIZONTAL")
    bar:SetReverseFill(false)
    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(healAbsorb)
    bar:Show()
end

function Addon:HookHostileAbsorb()
    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        UpdateHostileAbsorb(frame)
    end)
    
    if CompactUnitFrame_UpdateHealPrediction then
        hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
            UpdateHostileAbsorb(frame)
        end)
    end
    
    hooksecurefunc("CompactUnitFrame_UpdateHealth", function(frame)
        UpdateHostileAbsorb(frame)
    end)
end

function Addon:UpdateHostileAbsorb(frame)
    UpdateHostileAbsorb(frame)
end

function Addon:RefreshHostileAbsorbs()
    Addon:ForEachFrame(UpdateHostileAbsorb)
end
