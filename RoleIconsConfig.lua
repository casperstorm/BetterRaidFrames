local _, Addon = ...

function Addon:BuildRoleIconOptions(content, y, ui)
    local Refresh
    local function Changed() if Refresh then Refresh() end end
    ui.dropdown(content, "Show role icons:", "showRoleIcons", self.RoleIconOptions, y, Changed)
    ui.dropdown(content, "Style:", "roleIconStyle", self.RoleIconStyleOptions, y - 40, Changed)

    local preset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    preset:SetPoint("TOPLEFT", 446, y - 40)
    preset:SetSize(176, 24)
    preset:SetText("Tiny tank & healer")
    preset:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        Addon:SetSetting("roleIconStyle", "TINY")
        Addon:SetSetting("showRoleIcons", "TANK_HEALER")
        Addon:RefreshConfig()
    end)

    local tiny = CreateFrame("Frame", nil, content)
    tiny:SetPoint("TOPLEFT", 0, y - 90)
    tiny:SetSize(650, 400)
    local samples = {}
    local roles = { "TANK", "HEALER", "DAMAGER" }
    for index, label in ipairs({ "Tank", "Healer", "Damage" }) do
        local sample = CreateFrame("Frame", nil, tiny)
        sample:SetPoint("TOPLEFT", 24 + (index - 1) * 208, 0)
        sample:SetSize(180, 54)
        local background = sample:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.12, 0.3, 0.25, 1)
        local name = sample:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", 4, -4)
        name:SetText(label)
        samples[index] = sample
    end

    ui.slider(tiny, "Size (px):", "roleIconSize", 6, 20, 1, -80, Changed)
    ui.dropdown(tiny, "Anchor:", "roleIconPoint", self.AnchorOptions, -120, Changed)
    ui.slider(tiny, "X offset (px):", "roleIconOffsetX", -250, 250, 1, -160, Changed)
    ui.slider(tiny, "Y offset (px):", "roleIconOffsetY", -250, 250, 1, -200, Changed)

    local note = tiny:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", 24, -250)
    note:SetWidth(600)
    note:SetJustifyH("LEFT")
    note:SetText("Small, borderless role symbols. Tank & Healer leaves damage roles unmarked.\nOffsets start at the selected anchor: +X moves right; +Y moves up.")
    note:SetTextColor(0.75, 0.75, 0.75)

    local nativeNote = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    nativeNote:SetPoint("TOPLEFT", 24, y - 98)
    nativeNote:SetWidth(600)
    nativeNote:SetJustifyH("LEFT")
    nativeNote:SetText("Blizzard controls icon size and placement. Choose Tiny for a smaller, movable symbol,\nor use Tiny tank & healer to show just those two roles.")
    nativeNote:SetTextColor(0.75, 0.75, 0.75)

    Refresh = function()
        local settings = Addon:GetSettings()
        local enabled = settings.roleIconStyle == "TINY"
        tiny:SetShown(enabled)
        nativeNote:SetShown(not enabled)
        if enabled then
            for index, sample in ipairs(samples) do Addon:UpdateRoleIconPreview(sample, settings, roles[index]) end
        end
    end
    content:HookScript("OnShow", Refresh)
    Refresh()
    return Refresh
end
