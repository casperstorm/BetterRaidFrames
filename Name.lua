local _, Addon = ...
local C_ClassColor_GetClassColor = C_ClassColor.GetClassColor
local GetUnitName = GetUnitName
local UnitClass = UnitClass
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local hooksecurefunc = hooksecurefunc
local stringFind = string.find
local stringGmatch = string.gmatch
local stringSub = string.sub
local tableConcat = table.concat
local unpack = unpack or table.unpack

Addon.NameOutlineOptions = {
    { value = "NONE", label = "None" },
    { value = "OUTLINE", label = "Thin" },
    { value = "THICKOUTLINE", label = "Thick" },
}

local UTF8_CHARACTER = "([%z\1-\127\194-\244][\128-\191]*)"
local ELLIPSIS = "…"
local nameStates = setmetatable({}, { __mode = "k" })
local namesHooked = false

local cyrillicToLatin = {
    ["А"] = "A", ["Б"] = "B", ["В"] = "V", ["Г"] = "G", ["Д"] = "D",
    ["Е"] = "E", ["Ё"] = "Yo", ["Ж"] = "Zh", ["З"] = "Z", ["И"] = "I",
    ["Й"] = "Y", ["К"] = "K", ["Л"] = "L", ["М"] = "M", ["Н"] = "N",
    ["О"] = "O", ["П"] = "P", ["Р"] = "R", ["С"] = "S", ["Т"] = "T",
    ["У"] = "U", ["Ф"] = "F", ["Х"] = "Kh", ["Ц"] = "Ts", ["Ч"] = "Ch",
    ["Ш"] = "Sh", ["Щ"] = "Shch", ["Ъ"] = "", ["Ы"] = "Y", ["Ь"] = "",
    ["Э"] = "E", ["Ю"] = "Yu", ["Я"] = "Ya",
    ["а"] = "a", ["б"] = "b", ["в"] = "v", ["г"] = "g", ["д"] = "d",
    ["е"] = "e", ["ё"] = "yo", ["ж"] = "zh", ["з"] = "z", ["и"] = "i",
    ["й"] = "y", ["к"] = "k", ["л"] = "l", ["м"] = "m", ["н"] = "n",
    ["о"] = "o", ["п"] = "p", ["р"] = "r", ["с"] = "s", ["т"] = "t",
    ["у"] = "u", ["ф"] = "f", ["х"] = "kh", ["ц"] = "ts", ["ч"] = "ch",
    ["ш"] = "sh", ["щ"] = "shch", ["ъ"] = "", ["ы"] = "y", ["ь"] = "",
    ["э"] = "e", ["ю"] = "yu", ["я"] = "ya",
    ["Є"] = "Ye", ["І"] = "I", ["Ї"] = "Yi", ["Ґ"] = "G",
    ["є"] = "ye", ["і"] = "i", ["ї"] = "yi", ["ґ"] = "g",
}

local function StripServerName(name)
    if not name then return name end

    local separator = stringFind(name, "[- ]")
    return separator and stringSub(name, 1, separator - 1) or name
end

local function TruncateName(name, maxLength)
    if not name or maxLength <= 1 then return name end

    local characters = {}
    local count = 0
    for character in stringGmatch(name, UTF8_CHARACTER) do
        count = count + 1
        if count == maxLength then
            characters[count] = ELLIPSIS
        elseif count > maxLength then
            return tableConcat(characters)
        else
            characters[count] = character
        end
    end

    return name
end

local function TransliterateCyrillic(name)
    if not name then return name end

    local characters = {}
    local count = 0
    for character in stringGmatch(name, UTF8_CHARACTER) do
        count = count + 1
        characters[count] = cyrillicToLatin[character] or character
    end
    return tableConcat(characters)
end

local function TryTransformName(name, transform, ...)
    local ok, result = pcall(transform, name, ...)
    return ok and result or name
end

local function CapturePoints(fontString)
    local points = {}
    for index = 1, fontString:GetNumPoints() do
        points[index] = { fontString:GetPoint(index) }
    end
    return points
end

local function CaptureDefault(fontString)
    local fontPath, fontSize, fontFlags = fontString:GetFont()
    local fontObject = fontString:GetFontObject()
    local customFontPath = fontPath
    if fontObject then
        customFontPath = fontObject:GetFont() or customFontPath
    end
    local textR, textG, textB, textA = fontString:GetTextColor()
    local shadowR, shadowG, shadowB, shadowA = fontString:GetShadowColor()
    local shadowX, shadowY = fontString:GetShadowOffset()

    local state = {
        points = CapturePoints(fontString),
        fontObject = fontObject,
        fontPath = fontPath,
        customFontPath = customFontPath,
        fontSize = fontSize,
        fontFlags = fontFlags,
        justifyH = fontString:GetJustifyH(),
        textColor = { textR, textG, textB, textA },
        shadowColor = { shadowR, shadowG, shadowB, shadowA },
        shadowOffset = { shadowX, shadowY },
        shown = fontString:IsShown(),
    }
    nameStates[fontString] = state
    return state
end

local function RefreshBlizzardName(frame)
    if CompactUnitFrame_UpdateName then
        CompactUnitFrame_UpdateName(frame)
    end
    if CompactUnitFrame_UpdateStatusText then
        CompactUnitFrame_UpdateStatusText(frame)
    end
end

local function RestoreNameStyle(fontString)
    local state = fontString and nameStates[fontString]
    if not state then return end

    nameStates[fontString] = nil

    fontString:ClearAllPoints()
    for index = 1, #state.points do
        local point = state.points[index]
        fontString:SetPoint(point[1], point[2], point[3], point[4], point[5])
    end

    if state.fontObject then
        fontString:SetFontObject(state.fontObject)
    elseif state.fontPath then
        fontString:SetFont(state.fontPath, state.fontSize, state.fontFlags)
    end
    fontString:SetJustifyH(state.justifyH)
    fontString:SetTextColor(unpack(state.textColor))
    fontString:SetShadowColor(unpack(state.shadowColor))
    fontString:SetShadowOffset(unpack(state.shadowOffset))
    fontString:SetShown(state.shown)

    return true
end

local function ApplyNameLayout(fontString, frame, settings, state)
    local anchor = Addon:GetValidAnchor(settings.nameAnchor, "CENTER")
    local offsetX = settings.nameOffsetX or 0
    local offsetY = settings.nameOffsetY or 0
    if state.anchor ~= anchor or state.offsetX ~= offsetX or state.offsetY ~= offsetY then
        fontString:ClearAllPoints()
        fontString:SetPoint(anchor, frame, anchor, offsetX, offsetY)
        state.anchor = anchor
        state.offsetX = offsetX
        state.offsetY = offsetY
    end

    local justify = stringFind(anchor, "LEFT", 1, true) and "LEFT"
        or stringFind(anchor, "RIGHT", 1, true) and "RIGHT" or "CENTER"
    if state.appliedJustify ~= justify then
        fontString:SetJustifyH(justify)
        state.appliedJustify = justify
    end

    local fontSize = settings.nameSize or 11
    local outline = settings.nameTextOutline
    local fontFlags = outline and outline ~= "NONE" and outline or ""
    if state.appliedFontSize ~= fontSize or state.appliedFontFlags ~= fontFlags then
        fontString:SetFont(state.customFontPath, fontSize, fontFlags)
        state.appliedFontSize = fontSize
        state.appliedFontFlags = fontFlags
    end
end

local function ApplyNameShadow(fontString, settings, state)
    local enabled = settings.nameTextShadow
    if enabled then
        local r = settings.nameTextShadowColorR or 0
        local g = settings.nameTextShadowColorG or 0
        local b = settings.nameTextShadowColorB or 0
        if state.appliedShadowR ~= r or state.appliedShadowG ~= g or state.appliedShadowB ~= b then
            fontString:SetShadowColor(r, g, b, 1)
            state.appliedShadowR = r
            state.appliedShadowG = g
            state.appliedShadowB = b
        end
    end

    local x = enabled and (settings.nameTextShadowOffset or 1) or 0
    local y = enabled and -x or 0
    if state.appliedShadowX ~= x or state.appliedShadowY ~= y then
        fontString:SetShadowOffset(x, y)
        state.appliedShadowX = x
        state.appliedShadowY = y
    end
end

local function ApplyNameText(fontString, unit, settings)
    if settings.nameHideOnDead and UnitIsDeadOrGhost(unit)
        or settings.nameHideOnOffline and not UnitIsConnected(unit)
    then
        if fontString:IsShown() then fontString:Hide() end
        return
    end

    if not fontString:IsShown() then fontString:Show() end

    local displayName = GetUnitName(unit, true) or ""
    if settings.nameHideServer then
        displayName = TryTransformName(displayName, StripServerName)
    end
    if settings.nameCyrillicToLatin then
        displayName = TryTransformName(displayName, TransliterateCyrillic)
    end
    if settings.nameTruncate then
        displayName = TryTransformName(displayName, TruncateName, settings.nameTruncateLength or 8)
    end

    pcall(fontString.SetText, fontString, displayName)

    if settings.nameClassColor then
        local _, className = UnitClass(unit)
        local color = className and C_ClassColor_GetClassColor(className)
        if color then
            fontString:SetTextColor(color.r, color.g, color.b)
            return
        end
    end
    fontString:SetTextColor(1, 1, 1)
end

local function ApplyCustomName(frame, unit, settings)
    local fontString = frame.name
    local state = nameStates[fontString] or CaptureDefault(fontString)
    if not state.customFontPath then return end

    ApplyNameLayout(fontString, frame, settings, state)
    ApplyNameShadow(fontString, settings, state)
    ApplyNameText(fontString, unit, settings)
end

local function UpdateName(frame, settings)
    local fontString = frame and frame.name
    if not fontString then return end

    settings = settings or Addon:GetSettings()
    if not settings or not settings.customizeNames then
        if RestoreNameStyle(fontString) then RefreshBlizzardName(frame) end
        return
    end

    local unit = frame.displayedUnit or frame.unit
    if unit then ApplyCustomName(frame, unit, settings) end
end

function Addon:UpdateNamePreview(frame, settings)
    if not frame:IsVisible() then return end
    if not frame.name then
        -- Absorb previews contain child status bars. Give the name its own
        -- foreground so shield artwork cannot paint over the text.
        local host = CreateFrame("Frame", nil, frame)
        host:SetAllPoints()
        host:EnableMouse(false)
        local name = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        frame.name = name
    end
    frame.name:GetParent():SetFrameLevel((frame.healthBar or frame):GetFrameLevel() + 1)
    settings = settings or self:GetSettings()
    if settings.customizeNames then
        ApplyCustomName(frame, "player", settings)
    else
        -- Restore only our sample's style; native name/status update functions
        -- expect real compact unit frames and must not run on these previews.
        RestoreNameStyle(frame.name)
        frame.name:SetText(GetUnitName("player", true) or "")
        frame.name:Show()
    end
end

function Addon:HookName()
    if namesHooked then return end
    namesHooked = true

    local function OnNameUpdated(frame)
        local settings = Addon:GetSettings()
        if not settings.customizeNames and not (frame and frame.name and nameStates[frame.name]) then
            return
        end
        if Addon:IsEditModeActive() or not Addon:IsRaidOrPartyFrame(frame) then return end
        UpdateName(frame, settings)
    end

    if CompactUnitFrame_UpdateName then
        hooksecurefunc("CompactUnitFrame_UpdateName", OnNameUpdated)
    end
    if CompactUnitFrame_UpdateStatusText then
        hooksecurefunc("CompactUnitFrame_UpdateStatusText", OnNameUpdated)
    end
    if CompactUnitFrameLayoutTemplates_LayoutFrameElement then
        hooksecurefunc("CompactUnitFrameLayoutTemplates_LayoutFrameElement", function(frame, element, _, key)
            if key ~= "Name" or element ~= frame.name then return end
            local state = nameStates[element]
            if not state then return end
            -- Blizzard rebuilds name anchors on frame setup. Remember the new
            -- default for restoration, then reapply the user's selected anchor.
            state.points = CapturePoints(element)
            state.justifyH = element:GetJustifyH()
            state.anchor, state.appliedJustify = nil, nil
            OnNameUpdated(frame)
        end)
    end
end

function Addon:UpdateName(frame, settings)
    UpdateName(frame, settings)
end

function Addon:RefreshNames()
    Addon:RequestFeatureUpdate("name")
end
