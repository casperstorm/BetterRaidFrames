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
    if not unit then return end
    if unit ~= "player" and not unit:match("^party%d$") and not unit:match("^raid%d+$") then
        return
    end
    if not UnitExists(unit) then return end
    
    local maxHealth = UnitHealthMax(unit)
    local absorbs = UnitGetTotalAbsorbs(unit)
    
    if Addon:IsConfigOpen() then
        absorbs = maxHealth * 0.5
    end
    
    if frame.overAbsorbGlow then frame.overAbsorbGlow:Hide() end
    if frame.totalAbsorb then frame.totalAbsorb:Hide() end
    if frame.totalAbsorbOverlay then frame.totalAbsorbOverlay:Hide() end
    
    if not frame.BRFFriendlyAbsorbBar then
        frame.BRFFriendlyAbsorbBar = CreateFrame("StatusBar", nil, frame)
        frame.BRFFriendlyAbsorbBar:SetMinMaxValues(0, 1)
        frame.BRFFriendlyAbsorbBar:EnableMouse(false)
    end
    
    local bar = frame.BRFFriendlyAbsorbBar
    local healthLevel = frame.healthBar:GetFrameLevel()
    
    bar:SetParent(frame.healthBar)
    bar:SetFrameStrata(frame:GetFrameStrata())
    bar:SetFrameLevel(healthLevel + 2)
    
    if bar.currentTexture ~= OVERLAY_TEXTURE then
        bar.currentTexture = OVERLAY_TEXTURE
        bar:SetStatusBarTexture(OVERLAY_TEXTURE)
        local barTex = bar:GetStatusBarTexture()
        if barTex then
            barTex:SetHorizTile(false)
            barTex:SetVertTile(false)
            barTex:SetTexCoord(0, 1, 0, 1)
            barTex:SetDrawLayer("ARTWORK", 2)
        end
    end
    
    local opacity = Addon:GetSetting("friendlyAbsorbOpacity") or 0.8
    local r = Addon:GetSetting("friendlyAbsorbColorR") or 1
    local g = Addon:GetSetting("friendlyAbsorbColorG") or 1
    local b = Addon:GetSetting("friendlyAbsorbColorB") or 1
    bar:SetStatusBarColor(r, g, b, opacity)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, 0)
    bar:SetOrientation("HORIZONTAL")
    bar:SetReverseFill(true)
    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(absorbs)
    bar:Show()
end

function Addon:HookFriendlyAbsorb()
    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        UpdateFriendlyAbsorb(frame)
    end)
    
    if CompactUnitFrame_UpdateHealPrediction then
        hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", function(frame)
            UpdateFriendlyAbsorb(frame)
        end)
    end
    
    hooksecurefunc("CompactUnitFrame_UpdateHealth", function(frame)
        UpdateFriendlyAbsorb(frame)
    end)
end

function Addon:UpdateFriendlyAbsorb(frame)
    UpdateFriendlyAbsorb(frame)
end

function Addon:RefreshFriendlyAbsorbs()
    Addon:ForEachFrame(UpdateFriendlyAbsorb)
end
