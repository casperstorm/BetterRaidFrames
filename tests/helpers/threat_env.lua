local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
local methods = getmetatable(env.frame()).__index

function methods:IsVisible()
    return self.shown and (not self.parent or self.parent:IsVisible())
end
function methods:SetShown(value)
    if self.shown == value then return end
    local before = {}
    for _, w in ipairs(env.widgets) do before[w] = w:IsVisible() end
    self.shown = value
    for _, w in ipairs(env.widgets) do
        local visible = w:IsVisible()
        if visible ~= before[w] then
            local callback = w.scripts[visible and "OnShow" or "OnHide"]
            if callback then callback(w) end
        end
    end
end
function methods:HookScript(name, callback)
    local previous = self.scripts[name]
    self.scripts[name] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
local setPoint = methods.SetPoint
function methods:SetPoint(point, ...)
    setPoint(self, point, ...)
    self.points = self.points or {}
    self.points[point] = self.point
end
function methods:ClearAllPoints() self.point, self.allPoints, self.points = nil, nil, nil end
function methods:SetAllPoints(target) self.allPoints = target or self.parent end
function methods:GetWidth() return self.allPoints and self.allPoints:GetWidth() or self.width or 180 end
function methods:GetHeight() return self.allPoints and self.allPoints:GetHeight() or self.height or 56 end
function methods:SetBackdrop(info) self.backdrop = info end
function methods:SetBackdropBorderColor(...) self.borderColor = { ... } end
function methods:SetBorderBlendMode(mode) self.borderBlendMode = mode end
function methods:AddMaskTexture(mask) self.mask = mask end
function methods:RemoveMaskTexture(mask) if self.mask == mask then self.mask = nil end end
function methods:CreateMaskTexture() return self:CreateTexture() end
function methods:CreateAnimationGroup() return CreateFrame("AnimationGroup", nil, self) end
function methods:CreateAnimation() return CreateFrame("Animation", nil, self) end
function methods:Play() self.playing = true end
function methods:Stop() self.playing = false end
function methods:IsPlaying() return self.playing == true end
for _, name in ipairs({ "SetLooping", "SetFromAlpha", "SetToAlpha", "SetDuration", "SetOrder", "SetSmoothing",
    "SetClipsChildren", "SetMovable", "RegisterForDrag", "SetFrameStrata", "StartMoving", "StopMovingOrSizing" }) do
    methods[name] = function() end
end

local create = CreateFrame
function CreateFrame(kind, name, parent, template)
    local frame = create(kind, name, parent, template)
    if name then _G[name] = frame end
    if template == "BasicFrameTemplateWithInset" then frame.TitleText = frame:CreateFontString() end
    return frame
end
UIParent = CreateFrame("Frame")
StaticPopupDialogs = {}
SlashCmdList = {}
Settings = { RegisterCanvasLayoutCategory = function(panel) return panel end, RegisterAddOnCategory = function() end }
C_ClassColor = { GetClassColor = function() return { r = 1, g = 1, b = 1 } end }
function UnitExists() return true end
function UnitThreatSituation() return env.status end
function UnitGroupRolesAssigned() return "HEALER" end

assert(loadfile("Utils.lua"))("BetterRaidFrames", Addon)
assert(loadfile("ThreatBorders.lua"))("BetterRaidFrames", Addon)
assert(loadfile("ThreatIndicator.lua"))("BetterRaidFrames", Addon)
env.previewOpen = false
function Addon:IsThreatPreviewOpen() return env.previewOpen end
function Addon:IsEditModeActive() return false end
function Addon:IsRaidOrPartyFrame(frame) return frame.valid ~= false end
function Addon:GetProfileList() return { env.profile } end
function Addon:GetAutoProfileOptions() return { { value = "", label = "Disabled" } } end
function Addon:GetGlobalSetting() return "" end
function Addon:GetUseRaidStylePartyFrames() return true end
Addon.RoleIconOptions = { { value = "ALL", label = "All" } }
Addon.NameOutlineOptions = { { value = "NONE", label = "None" } }
env.settings.showThreatIndicator = true
env.settings.threatIndicatorBlink = true
env.settings.threatIndicatorColorByThreat = true
env.settings.threatIndicatorShape = "SQUARE"
return env
