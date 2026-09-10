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
    local previewRow = self:CreateFramePreviewRow(tiny, 3, 140, { "Tank", "Healer", "Damage" })
    previewRow:SetPoint("TOPLEFT", 24, 0); previewRow:SetPoint("TOPRIGHT", -24, 0)
    local samples = previewRow.samples
    local roles = { "TANK", "HEALER", "DAMAGER" }
    for _, sample in ipairs(samples) do
        local background = sample:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.12, 0.3, 0.25, 1)
    end

    local controls = CreateFrame("Frame", nil, tiny)
    controls:SetPoint("TOPLEFT", previewRow, "BOTTOMLEFT", -24, -26)
    controls:SetSize(650, 280)
    ui.slider(controls, "Size (px):", "roleIconSize", 6, 20, 1, 0, Changed)
    ui.dropdown(controls, "Position:", "roleIconPoint", self.AnchorOptions, -40, Changed)
    ui.slider(controls, "X offset (px):", "roleIconOffsetX", -250, 250, 1, -80, Changed)
    ui.slider(controls, "Y offset (px):", "roleIconOffsetY", -250, 250, 1, -120, Changed)

    local note = controls:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", 24, -170)
    note:SetWidth(600)
    note:SetJustifyH("LEFT")
    note:SetText("Small, borderless role symbols. Tank & Healer leaves damage roles unmarked.\nOffsets start at the selected position: +X moves right; +Y moves up.")
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
        if enabled and tiny:IsVisible() then
            previewRow:RefreshSize()
            for index, sample in ipairs(samples) do Addon:UpdateRoleIconPreview(sample, settings, roles[index]) end
        end
    end
    previewRow.RefreshOptions = Refresh
    content:HookScript("OnShow", Refresh)
    Refresh()
    return Refresh
end
