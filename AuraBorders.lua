local ADDON_NAME, Addon = ...

local function HideAuraFrameBorder(auraFrame)
    if not auraFrame then return end
    
    local borderNames = { "Border", "border", "Overlay", "overlay", "IconBorder", "iconBorder" }
    for _, name in ipairs(borderNames) do
        local border = auraFrame[name]
        if border and border.Hide then
            border:Hide()
        end
    end
    
    if auraFrame.icon then
        auraFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    
    if auraFrame.Icon then
        auraFrame.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    
    for _, region in ipairs({ auraFrame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local name = region:GetName() or ""
            local texture = region:GetTexture() or ""
            local drawLayer = region:GetDrawLayer()
            local isBorder = false
            
            if name:lower():find("border") or name:lower():find("overlay") then
                isBorder = true
            end
            
            if type(texture) == "string" and (texture:lower():find("border") or texture:lower():find("overlay")) then
                isBorder = true
            end
            
            if drawLayer == "OVERLAY" and not name:lower():find("icon") then
                isBorder = true
            end
            
            if isBorder then
                region:Hide()
                region:SetAlpha(0)
            end
        end
    end
    
    local frameName = auraFrame:GetName()
    if frameName then
        local borderFrame = _G[frameName .. "Border"]
        if borderFrame and borderFrame.Hide then
            borderFrame:Hide()
        end
        local overlayFrame = _G[frameName .. "Overlay"]
        if overlayFrame and overlayFrame.Hide then
            overlayFrame:Hide()
        end
    end
end

local function ShowAuraFrameBorder(auraFrame)
    if not auraFrame then return end
    
    local borderNames = { "Border", "border", "Overlay", "overlay", "IconBorder", "iconBorder" }
    for _, name in ipairs(borderNames) do
        local border = auraFrame[name]
        if border and border.Show then
            border:Show()
        end
    end
    
    if auraFrame.icon then
        auraFrame.icon:SetTexCoord(0, 1, 0, 1)
    end
    if auraFrame.Icon then
        auraFrame.Icon:SetTexCoord(0, 1, 0, 1)
    end
    
    for _, region in ipairs({ auraFrame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local drawLayer = region:GetDrawLayer()
            if drawLayer == "OVERLAY" then
                region:Show()
                region:SetAlpha(1)
            end
        end
    end
    
    local frameName = auraFrame:GetName()
    if frameName then
        local borderFrame = _G[frameName .. "Border"]
        if borderFrame and borderFrame.Show then
            borderFrame:Show()
        end
    end
end

local function ProcessFrameAuras(frame)
    if not frame then return end
    
    local shouldHide = BetterRaidFramesDB.hideAuraBorders
    
    if frame.buffFrames then
        for _, buffFrame in ipairs(frame.buffFrames) do
            if shouldHide then
                HideAuraFrameBorder(buffFrame)
            else
                ShowAuraFrameBorder(buffFrame)
            end
        end
    end
    
    if frame.debuffFrames then
        for _, debuffFrame in ipairs(frame.debuffFrames) do
            if shouldHide then
                HideAuraFrameBorder(debuffFrame)
            else
                ShowAuraFrameBorder(debuffFrame)
            end
        end
    end
    
    if frame.dispelDebuffFrames then
        for _, dispelFrame in ipairs(frame.dispelDebuffFrames) do
            if shouldHide then
                HideAuraFrameBorder(dispelFrame)
            else
                ShowAuraFrameBorder(dispelFrame)
            end
        end
    end
    
    local frameName = frame:GetName()
    if frameName then
        for i = 1, 10 do
            local buffFrame = _G[frameName .. "Buff" .. i]
            if buffFrame then
                if shouldHide then
                    HideAuraFrameBorder(buffFrame)
                else
                    ShowAuraFrameBorder(buffFrame)
                end
            end
            
            local debuffFrame = _G[frameName .. "Debuff" .. i]
            if debuffFrame then
                if shouldHide then
                    HideAuraFrameBorder(debuffFrame)
                else
                    ShowAuraFrameBorder(debuffFrame)
                end
            end
        end
    end
end

function Addon:HookAuraBorders()
    hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
        if BetterRaidFramesDB.hideAuraBorders then
            ProcessFrameAuras(frame)
        end
    end)
    
    if CompactUnitFrame_UtilSetBuff then
        hooksecurefunc("CompactUnitFrame_UtilSetBuff", function(buffFrame)
            if BetterRaidFramesDB.hideAuraBorders then
                HideAuraFrameBorder(buffFrame)
            end
        end)
    end
    
    if CompactUnitFrame_UtilSetDebuff then
        hooksecurefunc("CompactUnitFrame_UtilSetDebuff", function(debuffFrame)
            if BetterRaidFramesDB.hideAuraBorders then
                HideAuraFrameBorder(debuffFrame)
            end
        end)
    end
    
    if CompactUnitFrame_UtilSetDispelDebuff then
        hooksecurefunc("CompactUnitFrame_UtilSetDispelDebuff", function(dispelFrame)
            if BetterRaidFramesDB.hideAuraBorders then
                HideAuraFrameBorder(dispelFrame)
            end
        end)
    end
end

function Addon:UpdateAuraBorders(frame)
    ProcessFrameAuras(frame)
end

function Addon:RefreshAuraBorders()
    Addon:ForEachFrame(ProcessFrameAuras)
end
