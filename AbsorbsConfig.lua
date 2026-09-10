local _, Addon = ...
local PREDICTION_CVAR = "raidFramesDisplayIncomingHeals"

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
            C_CVar.SetCVar(PREDICTION_CVAR, button:GetChecked() and "1" or "0")
        end
        Changed()
    end)
    prediction:RegisterEvent("CVAR_UPDATE")
    prediction:SetScript("OnEvent", function(_, _, name)
        if type(name) == "string" and name:lower() == PREDICTION_CVAR:lower() then Changed() end
    end)
    Label(content, "Blizzard setting, shared across profiles. Turning it off also hides\nincoming heals and healing-absorb effects. BRF overshields stay independent.", y - 32)
    y = y - 88

    ui.checkbox(content, "Show normal absorb shields", "showAbsorbs", y, Changed)
    ui.slider(content, "Opacity (%):", "absorbOpacity", 0, 100, 1, y - 40, Changed)
    Label(content, "Adjust only Blizzard's damage shields and their edge glow.\nRequires the Blizzard display above; incoming heals keep their usual display.", y - 80)

    ui.checkbox(content, "Show overshields", "showOvershields", y - 144, Changed)
    ui.dropdown(content, "Texture:", "overshieldTexture", self.AbsorbTextureOptions, y - 184, Changed)
    ui.slider(content, "Opacity (%):", "overshieldOpacity", 0, 100, 1, y - 224, Changed)
    Label(content, "Shows shield coverage beyond full health over the filled health bar.\nShields uses a tiled pattern; Blizzard Flat gives a plain overlay.", y - 264)

    local samples = {}
    local health = { 40, 80, 100 }
    local shields = { 25, 50, 45 }
    for index, text in ipairs({ "Absorb fits", "Absorb overflows", "Shield at full health" }) do
        local sample = CreateFrame("Frame", nil, content)
        sample:SetPoint("TOPLEFT", 24 + (index - 1) * 208, y - 334)
        sample:SetSize(180, 54)
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
        sample.totalAbsorb:SetPoint("TOPLEFT", bar, "TOPLEFT", 178 * health[index] / 100, 0)
        sample.totalAbsorb:SetSize(178 * math.min(shields[index], 100 - health[index]) / 100, 52)
        sample.totalAbsorb:SetShown(health[index] < 100)
        sample.totalAbsorbOverlay = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        sample.totalAbsorbOverlay:SetAtlas("RaidFrame-Shield-Overlay", false, nil, true, "REPEAT", "REPEAT")
        sample.totalAbsorbOverlay:SetHorizTile(true)
        sample.totalAbsorbOverlay:SetVertTile(true)
        sample.totalAbsorbOverlay:SetAllPoints(sample.totalAbsorb)
        sample.totalAbsorbOverlay:SetShown(health[index] < 100)
        local label = sample:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", sample, "BOTTOMLEFT", 0, -8)
        label:SetText(text)
        samples[index] = sample
    end
    Refresh = function()
        local nativeEnabled = C_CVar.GetCVarBool(PREDICTION_CVAR)
        prediction:SetChecked(nativeEnabled)
        if not content:IsVisible() then return end
        local settings = Addon:GetSettings()
        for index, sample in ipairs(samples) do
            sample.totalAbsorb:SetShown(nativeEnabled and health[index] < 100)
            sample.totalAbsorbOverlay:SetShown(nativeEnabled and health[index] < 100)
            Addon:UpdateAbsorbPreview(sample, settings, shields[index])
        end
    end
    content:HookScript("OnShow", Refresh)
    Refresh()
    return Refresh
end
