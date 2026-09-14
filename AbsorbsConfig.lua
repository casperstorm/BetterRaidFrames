local _, Addon = ...

local function Label(parent, text, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 24, y)
    label:SetWidth(620)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    label:SetTextColor(0.75, 0.75, 0.75)
    return label
end

function Addon:BuildAbsorbOptions(content, y, ui)
    local Refresh
    local function Changed() if Refresh then Refresh() end end
    local prediction = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    prediction:SetPoint("TOPLEFT", 8, y)
    prediction.Text:SetText("Show Blizzard absorbs and incoming heals")
    prediction.Text:SetFontObject("GameFontHighlightSmall")
    prediction:SetScript("OnClick", function(button)
        if not InCombatLockdown() then
            Addon:SetSetting("blizzardIncomingHeals", button:GetChecked() and true or false)
            Addon:ApplyBlizzardCVars()
        end
        Changed()
    end)
    Label(content, "Blizzard setting, saved per profile. Turning it off also hides\nincoming heals and healing-absorb effects. BRF overshields stay independent.", y - 32)
    y = y - 88

    ui.checkbox(content, "Show normal absorb shields", "showAbsorbs", y, Changed)
    ui.slider(content, "Opacity (%):", "absorbOpacity", 0, 100, 1, y - 40, Changed)
    Label(content, "Adjust only Blizzard's damage shields and their edge glow.\nRequires the Blizzard display above; incoming heals keep their usual display.", y - 80)

    ui.checkbox(content, "Show overshields", "showOvershields", y - 144, Changed)
    ui.dropdown(content, "Texture:", "overshieldTexture", self.AbsorbTextureOptions, y - 184, Changed)
    ui.slider(content, "Opacity (%):", "overshieldOpacity", 0, 100, 1, y - 224, Changed)
    Label(content, "Shows shield coverage beyond full health over the filled health bar.\nShields uses a tiled pattern; Blizzard Flat gives a plain overlay.", y - 264)

    local previewRow = self:CreateFramePreviewRow(content, 3, 120,
        { "Absorb fits", "Absorb overflows", "Shield at full health" })
    previewRow:SetPoint("TOPLEFT", 24, y - 334); previewRow:SetPoint("TOPRIGHT", -24, y - 334)
    local samples = previewRow.samples
    local health = { 40, 80, 100 }
    local shields = { 25, 50, 45 }
    for index, sample in ipairs(samples) do
        local background = sample:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.08, 0.1, 0.1, 1)
        local bar = CreateFrame("StatusBar", nil, sample)
        bar:SetPoint("TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", -1, 1)
        bar:SetMinMaxValues(0, 100)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetStatusBarColor(0.12, 0.4, 0.3)
        bar:SetValue(health[index])
        sample.healthBar = bar
        sample.totalAbsorb = bar:CreateTexture(nil, "OVERLAY")
        sample.totalAbsorb:SetAtlas("raidframe-shield-fill", false, nil, true, "REPEAT", "REPEAT")
        sample.totalAbsorb:SetHorizTile(true)
        sample.totalAbsorb:SetVertTile(true)
        sample.totalAbsorb:SetShown(health[index] < 100)
        sample.totalAbsorbOverlay = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        sample.totalAbsorbOverlay:SetAtlas("RaidFrame-Shield-Overlay", false, nil, true, "REPEAT", "REPEAT")
        sample.totalAbsorbOverlay:SetHorizTile(true)
        sample.totalAbsorbOverlay:SetVertTile(true)
        sample.totalAbsorbOverlay:SetAllPoints(sample.totalAbsorb)
        sample.totalAbsorbOverlay:SetShown(health[index] < 100)
    end
    Refresh = function()
        local nativeEnabled = Addon:GetSetting("blizzardIncomingHeals") ~= false
        prediction:SetChecked(nativeEnabled)
        if not content:IsVisible() then return end
        previewRow:RefreshSize()
        local settings = Addon:GetSettings()
        for index, sample in ipairs(samples) do
            local width, height = math.max(1, sample:GetWidth() - 2), math.max(1, sample:GetHeight() - 2)
            sample.totalAbsorb:SetPoint("TOPLEFT", sample.healthBar, "TOPLEFT", width * health[index] / 100, 0)
            sample.totalAbsorb:SetSize(width * math.min(shields[index], 100 - health[index]) / 100, height)
            sample.totalAbsorb:SetShown(nativeEnabled and health[index] < 100)
            sample.totalAbsorbOverlay:SetShown(nativeEnabled and health[index] < 100)
            Addon:UpdateAbsorbPreview(sample, settings, shields[index])
        end
    end
    previewRow.RefreshOptions = Refresh
    content:HookScript("OnShow", Refresh)
    Refresh()
    return Refresh
end
