local ADDON_NAME, Addon = ...

-- Config frame
local ConfigFrame = nil

local function CreateDropdown(parent, label, settingKey, options, yOffset)
    -- Label
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 16, yOffset)
    labelText:SetText(label)
    
    -- Dropdown button
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", 16, yOffset - 18)
    dropdown:SetWidth(200)
    
    local function IsSelected(value)
        return Addon:GetSetting(settingKey) == value
    end
    
    local function SetSelected(value)
        Addon:SetSetting(settingKey, value)
        dropdown:GenerateMenu()
    end
    
    dropdown:SetupMenu(function(dropdown, rootDescription)
        for _, option in ipairs(options) do
            rootDescription:CreateRadio(option.label, IsSelected, SetSelected, option.value)
        end
    end)
    
    dropdown.settingKey = settingKey
    return dropdown
end

local function CreateConfigFrame()
    local frame = CreateFrame("Frame", "BetterRaidFramesConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(320, 200)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    -- Title
    frame.TitleText:SetText("BetterRaidFrames")
    
    -- Description
    local desc = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 16, -32)
    desc:SetWidth(288)
    desc:SetJustifyH("LEFT")
    desc:SetText("Customize the appearance of the default raid frames.")
    
    -- Section header
    local header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, -60)
    header:SetText("Role Icons")
    header:SetTextColor(1, 0.82, 0)
    
    -- Dropdown for role icon visibility
    local roleIconDropdown = CreateDropdown(
        frame,
        "Show role icons:",
        "showRoleIcons",
        Addon.RoleIconOptions,
        -80
    )
    frame.roleIconDropdown = roleIconDropdown
    
    return frame
end

function Addon:OpenConfig()
    if not ConfigFrame then
        ConfigFrame = CreateConfigFrame()
    end
    
    if ConfigFrame:IsShown() then
        ConfigFrame:Hide()
    else
        ConfigFrame:Show()
    end
end
