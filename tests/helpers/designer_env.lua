-- A small public-API fake. Aura visibility changes happen only in ShowAuras,
-- representing Blizzard's secure side; the addon never receives that state.
local env = { widgets = {}, containers = {}, hooks = {}, restricted = false, internal = false, combat = false, spec = 1468, now = 0 }
local methods = {}
local function guard(frame)
    if env.internal then return end
    local ancestor = frame
    while ancestor do
        if ancestor.aura then assert(not env.restricted or ancestor.initializing, "access to forbidden aura descendant"); return end
        ancestor = ancestor.parent
    end
end
local function widget(kind, parent, template)
    local w = setmetatable({ kind = kind, parent = parent, template = template, scripts = {}, shown = true, bindings = {} }, { __index = methods })
    env.widgets[#env.widgets + 1] = w
    return w
end
function methods:SetPoint(...) guard(self); self.point = { ... } end
function methods:ClearAllPoints() guard(self); self.point = nil end
function methods:SetSize(w, h) guard(self); self.width, self.height = w, h end
function methods:SetWidth(v) guard(self); self.width = v end
function methods:SetHeight(v) guard(self); self.height = v end
function methods:GetWidth() guard(self); assert(env.internal or self.kind ~= "AuraContainer", "reading secret container size"); return self.width or 180 end
function methods:GetHeight() guard(self); assert(env.internal or self.kind ~= "AuraContainer", "reading secret container size"); return self.height or 130 end
function methods:GetSize() return self:GetWidth(), self:GetHeight() end
function methods:SetParent(parent) guard(self); self.parent = parent end
function methods:GetFrameLevel() guard(self); return self.level or (self.parent and self.parent:GetFrameLevel() + 1) or 5 end
function methods:SetFrameLevel(v)
    guard(self)
    assert(env.internal or not (env.restricted and self.kind == "AuraContainer" and #self.groups > 0), "propagating levels to forbidden children")
    self.level = v
end
function methods:IsForbidden() return self.aura and env.restricted and not self.initializing end
function methods:EnableMouse(v) guard(self); self.mouse = v end
function methods:SetMouseMotionEnabled(v) guard(self); self.motion = v end
function methods:CreateTexture() guard(self); return widget("Texture", self) end
function methods:CreateFontString() guard(self); return widget("FontString", self) end
function methods:CreateAnimationGroup()
    guard(self)
    local group = widget("AnimationGroup", self)
    self.animationGroup = group
    group.animations = {}
    return group
end
function methods:CreateAnimation(kind)
    guard(self)
    local animation = widget(kind, self)
    self.animations[#self.animations + 1] = animation
    return animation
end
function methods:Play() guard(self); self.playing = true end
function methods:Stop() guard(self); self.playing = false end
for method, field in pairs({ SetLooping = "looping", SetFromAlpha = "fromAlpha", SetToAlpha = "toAlpha",
    SetDuration = "duration", SetOrder = "order", SetSmoothing = "smoothing" }) do
    methods[method] = function(self, value) guard(self); self[field] = value end
end
function methods:SetText(v) guard(self); self.text = v; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function methods:GetText() return self.text or "" end
function methods:SetTexture(v) guard(self); self.texture = v; self.color = nil end
function methods:SetTexCoord(...) guard(self); self.texCoord = { ... } end
function methods:SetBlendMode(v) guard(self); self.blendMode = v end
function methods:SetColorTexture(...) guard(self); self.color = { ... }; self.texture = nil end
function methods:SetVertexColor(...) guard(self); self.vertex = { ... } end
function methods:SetTextColor(...) guard(self); self.textColor = { ... } end
function methods:SetAlpha(v) guard(self); self.alpha = v end
function methods:SetScale(v) guard(self); self.scale = v end
function methods:SetCooldown(...) guard(self); self.duration = { ... } end
function methods:Clear() guard(self); self.duration = nil end
function methods:SetDrawSwipe(v) guard(self); self.swipe = v end
function methods:SetReverse(v) guard(self); self.reverse = v end
function methods:SetShown(v) guard(self); self.shown = v end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetEnabled(v) self.enabled = v end
function methods:SetChecked(v) self.checked = v end
function methods:GetChecked() return self.checked end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:HookScript(name, callback) self.scripts[name] = callback end
function methods:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function methods:SetScrollChild(v) self.child = v end
function methods:SetVerticalScroll(v) self.scroll = v end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:Init(v, min, max, steps) self.value, self.min, self.max, self.steps = v, min, max, steps end
function methods:SetValue(v)
    self.value = v
    if self.Slider and self.Slider.scripts.OnValueChanged then self.Slider.scripts.OnValueChanged(self.Slider, v) end
end
for _, name in ipairs({ "SetAllPoints", "SetHideCountdownNumbers", "SetDrawEdge", "SetDrawBling", "SetFont", "SetShadowColor", "SetShadowOffset",
    "SetJustifyH", "SetWordWrap", "SetFontObject", "SetAutoFocus", "SetMaxLetters", "ClearFocus", "SetFocus", "HighlightText",
    "SetDefaultText", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor" }) do
    methods[name] = function(self) guard(self) end
end
for _, name in ipairs({ "Icon", "DurationCooldown", "DurationText", "ApplicationCount" }) do
    methods["Set" .. name] = function(self, element, options) guard(self); self.bindings[name] = { element = element, options = options } end
    methods["Clear" .. name] = function(self) guard(self); self.bindings[name] = nil end
end
local function menu()
    local m = { items = {} }
    function m:SetScrollMode(height) self.scrollHeight = height end
    function m:CreateRadio(label, selected, callback, value) self.items[#self.items + 1] = { label = label, selected = selected, callback = callback, value = value } end
    function m:CreateButton(label, callback) local child = menu(); child.label, child.callback = label, callback; self.items[#self.items + 1] = child; return child end
    return m
end
function methods:SetupMenu(builder) self.builder = builder; self:GenerateMenu() end
function methods:GenerateMenu() self.menu = menu(); self.builder(self, self.menu) end

function CreateFromMixins(...)
    local result = {}; for _, mixin in ipairs({ ... }) do for k, v in pairs(mixin) do result[k] = v end end; return result
end
function CreateAndInitFromMixin(mixin, ...) local result = CreateFromMixins(mixin); result:Init(...); return result end
function GenerateClosure(fn, ...) local args = { ... }; return function() return fn(table.unpack(args)) end end
function GetValueOrCallFunction(object, key) local v = object[key]; return type(v) == "function" and v() or v end

local realLayout = os.getenv("BRF_ANCHOR_UTIL")
if realLayout then
    assert(loadfile(realLayout))()
else
    AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 }, FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
    local flow = {}
    AnchorUtil.FlowLayoutMixin = flow
    function flow:Init() self.axis, self.point, self.h, self.v = 0, "TOPLEFT", 1, -1 end
    function flow:SetLayoutAxis(v) self.axis = v end
    function flow:SetAnchorPoint(v) self.point = v end
    function flow:SetGrowthDirection(h, v) self.h, self.v = h, v end
    function flow:SetPadding() end
    function flow:SetMaximumLineSize() end
    function flow:Apply(parent, groups)
        local cursor, cross = 0, 0
        for _, group in ipairs(groups) do
            for _, element in ipairs(group.elements) do
                local size = element.width
                if cursor > 0 then cursor = cursor + group.groupSpacing end
                element:SetPoint(self.point, parent, self.point, self.axis == 0 and cursor * self.h or 0, self.axis == 1 and cursor * self.v or 0)
                cursor, cross = cursor + size, math.max(cross, size)
            end
        end
        parent:SetSize(self.axis == 0 and math.max(cursor, 1) or math.max(cross, 1), self.axis == 1 and math.max(cursor, 1) or math.max(cross, 1))
    end
end

function methods:SetUnit(unit) self.unit = unit end
function methods:SetFlowLayoutAxis(v) self.flow:SetLayoutAxis(v) end
function methods:SetFlowLayoutAnchorPoint(v) self.flow:SetAnchorPoint(v) end
function methods:SetFlowLayoutGrowthDirection(h, v) self.flow:SetGrowthDirection(h, v) end
function methods:SetFlowLayoutPadding(...) self.flow:SetPadding(...) end
function methods:SetFlowLayoutMaximumLineSize(v) self.flow:SetMaximumLineSize(v or math.huge) end
function methods:AddAuraGroup(key, filter, options)
    assert(not self.byKey[key], "allocated a group twice")
    local group = { key = key, filter = filter, filters = options.candidateFilters, frames = {}, max = options.maxFrameCount, layout = {} }
    self.groups[#self.groups + 1] = group; self.byKey[key] = group
    for i = 1, 10 do
        local button = widget("Button", self); button.aura, button.initializing = true, true
        options.initializeFrame(button); button.initializing = false; group.frames[i] = button
    end
end
function methods:SetAuraGroupLayout(key, layout) self.byKey[key].layout = layout end
function methods:SetAuraGroupCandidateFilters(key, filters) self.byKey[key].filters = filters end
function CreateFrame(kind, _, parent, template)
    local w = widget(kind, parent, template)
    if kind == "CheckButton" then w.Text = widget("FontString", w) end
    if template == "MinimalSliderWithSteppersTemplate" then w.Slider = widget("Slider", w) end
    if kind == "AuraContainer" then
        w.groups, w.byKey = {}, {}; w.flow = CreateAndInitFromMixin(AnchorUtil.FlowLayoutMixin)
        env.containers[#env.containers + 1] = w
    end
    return w
end
function env.ShowAuras(container, spells)
    local descriptions = {}
    env.internal = true
    for _, group in ipairs(container.groups) do
        local active = false
        for spell in pairs(group.filters.includeSpellIDs) do if spells[spell] then active = true end end
        group.frames[1]:SetShown(active)
        descriptions[#descriptions + 1] = { elements = active and { group.frames[1] } or {}, groupSpacing = group.layout.groupSpacing or 0 }
    end
    container.flow:Apply(container, descriptions)
    env.internal = false
end
function GetTime() return env.now end
function InCombatLockdown() return env.combat end
function issecretvalue(v) return v == "secret" end
function hooksecurefunc(name, callback) env.hooks[name] = callback end
C_Timer = { After = function(_, callback) callback() end }
C_SpecializationInfo = { GetSpecialization = function() return 1 end, GetSpecializationInfo = function() return env.spec, "Test spec" end }
C_Spell = { GetSpellInfo = function(value)
    local id = tonumber(value) or (value == "Echo" and 364343)
    if id and id > 0 then return { spellID = id, name = "Buff " .. id, iconID = id + 1 } end
end }
C_StringUtil = { CreateNumericRuleFormatter = function() return { SetBreakpoints = function() end } end }
Enum = { NumericRuleFormatRounding = { Down = 1 }, CompressionMethod = { Gzip = 1 } }
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
function CreateMinimalSliderFormatter(_, fn) return fn end
ColorPickerFrame = { SetupColorPickerAndShow = function(_, info) env.colorPicker = info end, GetColorRGB = function() return .1, .2, .3 end, GetColorAlpha = function() return .4 end }
env.Addon = {}
local Addon = env.Addon
env.profile = "Default"
env.settings = {}
function Addon:GetSetting(key) return env.settings[key] end
function Addon:GetSettings() return env.settings end
function Addon:SetSetting(key, value) env.settings[key] = value end
function Addon:GetCurrentProfileName() return env.profile end
function Addon:IsRaidOrPartyFrame(frame) return frame.valid ~= false end
function Addon:IsConfigOpen() return false end
function Addon:RequestFeatureUpdate(feature) env.requested = feature end
assert(loadfile("Indicators.lua"))("BetterRaidFrames", Addon)
assert(loadfile("IndicatorDisplay.lua"))("BetterRaidFrames", Addon)
env.settings.indicators = Addon:NormalizeIndicators(nil)
function env.frame(unit) local f = CreateFrame("Frame"); f.unit = unit; f:SetSize(180, 56); return f end
function env.find(predicate)
    for _, w in ipairs(env.widgets) do if predicate(w) then return w end end
    error("widget not found")
end
return env
