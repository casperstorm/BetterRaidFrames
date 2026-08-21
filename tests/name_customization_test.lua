local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertEqual failed") .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local unpack = unpack or table.unpack

local settings = {
    customizeNames = true,
    nameOffsetX = 8,
    nameOffsetY = -4,
    nameSize = 14,
    nameHideServer = true,
    nameTruncate = true,
    nameTruncateLength = 6,
    nameClassColor = true,
    nameCyrillicToLatin = true,
    nameHideOnDead = false,
    nameHideOnOffline = false,
    nameTextShadow = true,
    nameTextShadowColorR = 0.1,
    nameTextShadowColorG = 0.2,
    nameTextShadowColorB = 0.3,
    nameTextShadowOffset = 2,
    nameTextOutline = "THICKOUTLINE",
}

local defaultFontObject = {
    GetFont = function() return "Fonts\\Default.ttf", 11, "OUTLINE" end,
}

local fontString = {
    points = { { "LEFT", nil, "LEFT", 3, 4 } },
    fontObject = defaultFontObject,
    fontPath = "Fonts\\Default.ttf",
    fontSize = 11,
    fontFlags = "OUTLINE",
    justify = "LEFT",
    textColor = { 0.8, 0.8, 0.8, 1 },
    shadowColor = { 0, 0, 0, 0.5 },
    shadowOffset = { 1, -1 },
    shown = true,
    clearCount = 0,
}

function fontString:GetNumPoints() return #self.points end
function fontString:GetPoint(index)
    local point = self.points[index]
    return point[1], point[2], point[3], point[4], point[5]
end
function fontString:ClearAllPoints() self.points = {}; self.clearCount = self.clearCount + 1 end
function fontString:SetPoint(...) self.points[#self.points + 1] = { ... } end
function fontString:GetFont() return self.fontPath, self.fontSize, self.fontFlags end
function fontString:SetFont(path, size, flags)
    self.fontPath, self.fontSize, self.fontFlags = path, size, flags
end
function fontString:GetFontObject() return self.fontObject end
function fontString:SetFontObject(fontObject)
    self.fontObject = fontObject
    self.fontPath, self.fontSize, self.fontFlags = fontObject:GetFont()
end
function fontString:GetJustifyH() return self.justify end
function fontString:SetJustifyH(justify) self.justify = justify end
function fontString:GetTextColor() return unpack(self.textColor) end
function fontString:SetTextColor(...) self.textColor = { ... } end
function fontString:GetShadowColor() return unpack(self.shadowColor) end
function fontString:SetShadowColor(...) self.shadowColor = { ... } end
function fontString:GetShadowOffset() return unpack(self.shadowOffset) end
function fontString:SetShadowOffset(...) self.shadowOffset = { ... } end
function fontString:IsShown() return self.shown end
function fontString:SetShown(shown) self.shown = shown end
function fontString:Show() self.shown = true end
function fontString:Hide() self.shown = false end
function fontString:SetText(text) self.text = text end

local frame = { unit = "party1", name = fontString }
local hooks = {}
local blizzardNameUpdates = 0
local blizzardStatusUpdates = 0

C_ClassColor = {
    GetClassColor = function(className)
        if className == "MAGE" then return { r = 0.2, g = 0.4, b = 0.8 } end
    end,
}
function GetUnitName() return "Александр-Realm" end
function UnitClass() return "Mage", "MAGE" end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return false end
function CompactUnitFrame_UpdateName(target)
    blizzardNameUpdates = blizzardNameUpdates + 1
    target.name:SetText("Blizzard Name")
end
function CompactUnitFrame_UpdateStatusText(target)
    blizzardStatusUpdates = blizzardStatusUpdates + 1
    target.name:Show()
end
function hooksecurefunc(name, callback) hooks[name] = callback end

local requestedFeature
local Addon = {}
function Addon:GetSettings() return settings end
function Addon:IsEditModeActive() return false end
function Addon:IsRaidOrPartyFrame() return true end
function Addon:RequestFeatureUpdate(feature) requestedFeature = feature end

assert(loadfile("Name.lua"))("BetterRaidFrames", Addon)

Addon:HookName()
Addon:UpdateName(frame)

assertEqual(fontString.points[1][1], "CENTER", "custom names should use the configured anchor")
assertEqual(fontString.points[1][4], 8, "custom names should apply the X offset")
assertEqual(fontString.points[1][5], -4, "custom names should apply the Y offset")
assertEqual(fontString.fontSize, 14, "custom names should apply the font size")
assertEqual(fontString.fontFlags, "THICKOUTLINE", "custom names should apply the outline")
assertEqual(fontString.text, "Aleks…", "name transforms should be Unicode safe and hide the realm")
assertEqual(fontString.textColor[1], 0.2, "class color should be applied")
assertEqual(fontString.shadowOffset[1], 2, "shadow offset should be applied")

local clearCount = fontString.clearCount
Addon:UpdateName(frame)
assertEqual(fontString.clearCount, clearCount, "unchanged layout settings should not re-anchor the name")

settings.nameTextShadow = false
Addon:UpdateName(frame)
assertEqual(fontString.shadowOffset[1], 0, "turning off the custom shadow should remove it")

settings.customizeNames = false
Addon:UpdateName(frame)

assertEqual(fontString.points[1][1], "LEFT", "disable should restore the original anchor")
assertEqual(fontString.points[1][4], 3, "disable should restore the original X offset")
assertEqual(fontString.points[1][5], 4, "disable should restore the original Y offset")
assertEqual(fontString.fontSize, 11, "disable should restore the original font size")
assertEqual(fontString.fontFlags, "OUTLINE", "disable should restore the original outline")
assertEqual(fontString.justify, "LEFT", "disable should restore text justification")
assertEqual(fontString.textColor[1], 0.8, "disable should restore the original text color")
assertEqual(fontString.shadowOffset[1], 1, "disable should restore the original shadow")
assertEqual(fontString.text, "Blizzard Name", "disable should ask Blizzard to restore the displayed text")
assertEqual(blizzardNameUpdates, 1, "disable should refresh Blizzard's name once")
assertEqual(blizzardStatusUpdates, 1, "disable should refresh Blizzard's status visibility once")

Addon:UpdateName(frame)
assertEqual(blizzardNameUpdates, 1, "disabled updates should become no-ops after restoration")

Addon:RefreshNames()
assertEqual(requestedFeature, "name", "manual refreshes should use the throttled name feature path")

assertEqual(type(hooks.CompactUnitFrame_UpdateName), "function", "the Blizzard name update should be hooked")
assertEqual(type(hooks.CompactUnitFrame_UpdateStatusText), "function", "status updates should be hooked")

print("PASS: name_customization_test")
