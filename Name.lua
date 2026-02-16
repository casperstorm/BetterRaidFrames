local ADDON_NAME, Addon = ...

local originalNames = {}

local function StripServerName(name)
    if not name then return name end
    local spacePos = string.find(name, " ")
    if spacePos then
        return string.sub(name, 1, spacePos - 1)
    end
    return name
end

local function TruncateName(name, maxLength)
    if not name or maxLength <= 0 then return name end
    
    local len = strlenutf8 and strlenutf8(name) or #name
    if len <= maxLength then
        return name
    end
    
    if strlenutf8 then
        local truncated = ""
        local count = 0
        for char in string.gmatch(name, "([%z\1-\127\194-\244][\128-\191]*)") do
            if count >= maxLength - 1 then
                break
            end
            truncated = truncated .. char
            count = count + 1
        end
        return truncated .. "…"
    else
        return string.sub(name, 1, maxLength - 1) .. "…"
    end
end

local cyrillicToLatin = {
    -- Russian uppercase
    ["А"] = "A", ["Б"] = "B", ["В"] = "V", ["Г"] = "G", ["Д"] = "D",
    ["Е"] = "E", ["Ё"] = "Yo", ["Ж"] = "Zh", ["З"] = "Z", ["И"] = "I",
    ["Й"] = "Y", ["К"] = "K", ["Л"] = "L", ["М"] = "M", ["Н"] = "N",
    ["О"] = "O", ["П"] = "P", ["Р"] = "R", ["С"] = "S", ["Т"] = "T",
    ["У"] = "U", ["Ф"] = "F", ["Х"] = "Kh", ["Ц"] = "Ts", ["Ч"] = "Ch",
    ["Ш"] = "Sh", ["Щ"] = "Shch", ["Ъ"] = "", ["Ы"] = "Y", ["Ь"] = "",
    ["Э"] = "E", ["Ю"] = "Yu", ["Я"] = "Ya",
    -- Russian lowercase
    ["а"] = "a", ["б"] = "b", ["в"] = "v", ["г"] = "g", ["д"] = "d",
    ["е"] = "e", ["ё"] = "yo", ["ж"] = "zh", ["з"] = "z", ["и"] = "i",
    ["й"] = "y", ["к"] = "k", ["л"] = "l", ["м"] = "m", ["н"] = "n",
    ["о"] = "o", ["п"] = "p", ["р"] = "r", ["с"] = "s", ["т"] = "t",
    ["у"] = "u", ["ф"] = "f", ["х"] = "kh", ["ц"] = "ts", ["ч"] = "ch",
    ["ш"] = "sh", ["щ"] = "shch", ["ъ"] = "", ["ы"] = "y", ["ь"] = "",
    ["э"] = "e", ["ю"] = "yu", ["я"] = "ya",
    -- Ukrainian specific
    ["Є"] = "Ye", ["І"] = "I", ["Ї"] = "Yi", ["Ґ"] = "G",
    ["є"] = "ye", ["і"] = "i", ["ї"] = "yi", ["ґ"] = "g",
}

local function TransliterateCyrillic(name)
    if not name then return name end
    local result = ""
    for char in string.gmatch(name, "([%z\1-\127\194-\244][\128-\191]*)") do
        result = result .. (cyrillicToLatin[char] or char)
    end
    return result
end

local function GetClassColor(unit)
    if not unit then return nil end
    local _, className = UnitClass(unit)
    if className then
        local color = C_ClassColor.GetClassColor(className)
        if color then
            return color
        end
    end
    return nil
end

local function RestoreDefaultName(frame)
    if not frame or not frame.name then return end
    if not frame.unit then return end
    
    -- Let Blizzard handle it by not modifying anything
    -- Just ensure we're not leaving customizations behind
    frame.name:SetTextColor(1, 1, 1)
    frame.name:SetShadowOffset(0, 0)
end

local function UpdateName(frame)
    if not frame or not frame.name then return end
    
    local unit = frame.unit
    if not unit then return end
    
    if not Addon:GetSetting("customizeNames") then
        RestoreDefaultName(frame)
        return
    end

    -- Hide name when unit is dead and setting is enabled
    if Addon:GetSetting("nameHideOnDead") and UnitIsDeadOrGhost(unit) then
        frame.name:Hide()
        return
    else
        frame.name:Show()
    end

    local offsetX = Addon:GetSetting("nameX") or 0
    local offsetY = Addon:GetSetting("nameY") or 0
    local fontSize = Addon:GetSetting("nameSize") or 11
    local hideServer = Addon:GetSetting("nameHideServer")
    local truncateEnabled = Addon:GetSetting("nameTruncate")
    local maxLength = Addon:GetSetting("nameTruncateLength") or 8

    frame.name:ClearAllPoints()
    frame.name:SetPoint("CENTER", frame, "CENTER", offsetX, offsetY)
    frame.name:SetJustifyH("CENTER")

    local fontPath, _, fontFlags
    local fontObject = frame.name:GetFontObject()
    if fontObject then
        fontPath, _, fontFlags = fontObject:GetFont()
    end
    if not fontPath then
        fontPath, _, fontFlags = frame.name:GetFont()
    end
    if fontPath then
        local outline = Addon:GetSetting("nameTextOutline") or "NONE"
        local flags = outline ~= "NONE" and outline or ""
        frame.name:SetFont(fontPath, fontSize, flags)
    end

    if Addon:GetSetting("nameTextShadow") then
        local sr = Addon:GetSetting("nameTextShadowColorR") or 0
        local sg = Addon:GetSetting("nameTextShadowColorG") or 0
        local sb = Addon:GetSetting("nameTextShadowColorB") or 0
        local offset = Addon:GetSetting("nameTextShadowOffset") or 1
        frame.name:SetShadowColor(sr, sg, sb, 1)
        frame.name:SetShadowOffset(offset, -offset)
    else
        frame.name:SetShadowOffset(0, 0)
    end
    
    if frame.unit then
        local displayName = UnitName(frame.unit) or ""

        if not originalNames[frame] then
            originalNames[frame] = displayName
        end

        if hideServer then
            displayName = StripServerName(displayName)
        end

        if Addon:GetSetting("nameCyrillicToLatin") then
            displayName = TransliterateCyrillic(displayName)
        end

        if truncateEnabled then
            displayName = TruncateName(displayName, maxLength)
        end

        frame.name:SetText(displayName)

        if Addon:GetSetting("nameClassColor") then
            local color = GetClassColor(frame.unit)
            if color then
                frame.name:SetTextColor(color.r, color.g, color.b)
            end
        else
            frame.name:SetTextColor(1, 1, 1)
        end
    end
end

function Addon:HookName()
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        if Addon:IsEditModeActive() then return end
        UpdateName(frame)
    end)
    hooksecurefunc("CompactUnitFrame_UpdateStatusText", function(frame)
        if not Addon:IsRaidOrPartyFrame(frame) then return end
        if Addon:IsEditModeActive() then return end
        UpdateName(frame)
    end)
end

function Addon:UpdateName(frame)
    UpdateName(frame)
end

function Addon:RefreshNames()
    wipe(originalNames)
    Addon:ForEachFrame(UpdateName)
end
