local env = { widgets = {}, group = "solo", settings = { showSolo = false }, nativeAllowed = true,
    combat = false, secure = false, raidStyle = true, editing = false, preview = false,
    registrations = 0, removals = 0, layouts = 0, visibilityWrites = 0, hooks = 0 }
local methods = {}
local function writable(frame)
    assert(env.secure or not env.combat, "addon changed protected visibility during combat")
    assert(env.secure or frame:CanBeAccessedInContext() == true, "addon touched an inaccessible container")
end
function methods:CanBeAccessedInContext() return self.secretAccess and "secret" or not self.denied end
function methods:IsShown() return self.shown end
function methods:SetShown(value)
    writable(self)
    env.visibilityWrites = env.visibilityWrites + 1
    if self.shown == value then return end
    self.shown = value
    local callback = self.scripts[value and "OnShow" or "OnHide"]
    if callback then callback(self) end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:HookScript(name, callback)
    writable(self)
    assert(not self.scripts[name], "unexpected repeated hook")
    self.scripts[name] = callback
    env.hooks = env.hooks + 1
end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:GetAttribute(key) return self.attributes[key] end
function methods:SetAttribute(key, value)
    self.attributes[key] = value
    if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, key, value) end
end
function CreateFrame()
    local frame = setmetatable({ shown = true, scripts = {}, events = {}, attributes = {} }, { __index = methods })
    env.widgets[#env.widgets + 1] = frame
    return frame
end
function InCombatLockdown() return env.combat end
function IsInGroup() return env.group ~= "solo" end
function issecretvalue(value) return value == "secret" end
function hooksecurefunc(target, method, callback)
    if type(target) == "string" then target, method, callback = _G, target, method end
    local original = assert(target[method])
    target[method] = function(...)
        local result = original(...)
        callback(...)
        return result
    end
    env.hooks = env.hooks + 1
end
PartyFrame = CreateFrame()
function PartyFrame:UpdatePaddingAndLayout()
    writable(self)
    env.layouts = env.layouts + 1
    if CompactPartyFrame.shown then CompactPartyFrame.anchored = true end
end
EditModeManagerFrame = {}
function EditModeManagerFrame:UseRaidStylePartyFrames() return env.raidStyle end
function EditModeManagerFrame:EnterEditMode() env.editing, env.preview = true, true end
function EditModeManagerFrame:ExitEditMode() env.editing, env.preview = false, false end
function CompactPartyFrame_Generate()
    if not CompactPartyFrame then
        CompactPartyFrame = CreateFrame()
        CompactPartyFrame.shown = false
        -- Represents Blizzard's existing entry. BRF must not create or rebind it.
        CompactPartyFrame.player = { unit = "player", displayedUnit = "player", width = 100, height = 50 }
        function CompactPartyFrame:ShouldShow()
            return env.raidStyle and (env.editing and env.preview or env.nativeAllowed and env.group == "party")
        end
        function CompactPartyFrame:UpdateVisibility() self:SetShown(self:ShouldShow()) end
    end
    return CompactPartyFrame
end

local driver
local function NativeTick()
    if driver and not IsInGroup() then driver:Show() end
end
function RegisterStateDriver(frame, state, expression)
    writable(frame)
    assert(state == "visibility" and expression == "[group] ignore; show")
    assert(not driver, "duplicate visibility driver")
    driver = frame
    NativeTick()
end
function UnregisterStateDriver(frame, state)
    writable(frame)
    assert(state == "visibility" and driver == frame)
    driver = nil
end
-- Optional integration run with Blizzard's actual shared driver, without
-- making the normal test suite depend on a network download.
local realDriver = os.getenv("BRF_STATE_DRIVER")
if realDriver then
    strmatch = string.match
    function table.wipe(t) for key in pairs(t) do t[key] = nil end end
    function SecureCmdOptionParse(expression)
        assert(expression == "[group] ignore; show")
        return IsInGroup() and "ignore" or "show"
    end
    assert(loadfile(realDriver))()
    function NativeTick() SecureStateDriverManager.scripts.OnUpdate(SecureStateDriverManager, .3) end
end
local register, unregister = RegisterStateDriver, UnregisterStateDriver
function RegisterStateDriver(...)
    assert(not env.combat)
    env.registrations = env.registrations + 1
    register(...)
end
function UnregisterStateDriver(...)
    assert(not env.combat)
    env.removals = env.removals + 1
    unregister(...)
end
local Addon = {}
function Addon:GetSetting(key) return env.settings[key] end
function Addon:GetSettings() return env.settings end
function Addon:IsEditModeActive() return env.editing end
function Addon:RequestFeatureUpdate(feature) assert(feature == "soloFrame"); env.queued = true end
local function Flush()
    if not env.queued then return end
    env.queued = false
    Addon:RefreshSoloFrame()
    assert(not env.queued, "visibility updates must not schedule themselves forever")
end
local function Native(callback)
    env.secure = true
    callback()
    env.secure = false
end
local initialWrites = env.visibilityWrites
assert(loadfile("SoloFrame.lua"))("BetterRaidFrames", Addon)
Addon:HookSoloFrame()
local hooks = env.hooks
Addon:HookSoloFrame()
assert(env.hooks == hooks)
local events = env.widgets[#env.widgets]
local function Event(event)
    assert(events.events[event])
    events.scripts.OnEvent(events, event)
    Flush()
end
Addon:RefreshSoloFrame()
assert(env.registrations == 0 and env.visibilityWrites == initialWrites and not CompactPartyFrame)
env.settings.showSolo = true
Addon:RefreshSoloFrame()
assert(env.registrations == 0, "wait for Blizzard to create its container")
local frame = CompactPartyFrame_Generate()
Flush()
assert(frame.shown and frame.anchored and env.registrations == 1)
local player, widgets, layouts = frame.player, #env.widgets, env.layouts
local writes = env.visibilityWrites
collectgarbage("collect"); collectgarbage("stop")
local memory = collectgarbage("count")
for _ = 1, 1000 do Addon:RefreshSoloFrame() end
local allocated = collectgarbage("count") - memory
collectgarbage("restart")
assert(allocated < 1 and #env.widgets == widgets and env.visibilityWrites == writes and env.layouts == layouts,
    "stable updates allocate no widgets or temporary tables and do not rewrite visibility or layout")
frame:UpdateVisibility()
assert(not frame.shown)
Flush()
assert(frame.shown and env.registrations == 1, "reapply solo visibility after a native refresh")

env.combat = true
Native(function() frame:UpdateVisibility() end)
Flush()
assert(not frame.shown)
layouts = env.layouts
Native(NativeTick)
Flush()
assert(frame.shown and env.layouts == layouts, "the shared secure driver restores solo visibility during combat")
env.group = "party"
Native(function() frame:UpdateVisibility() end)
Native(NativeTick)
Flush()
assert(frame.shown)
env.nativeAllowed = false
Native(function() frame:UpdateVisibility() end)
Native(NativeTick)
Flush()
assert(not frame.shown, "grouped visibility remains under Blizzard's control, including special game modes")
env.nativeAllowed, env.group = true, "raid"
Native(function() frame:UpdateVisibility() end)
Native(NativeTick)
Flush()
assert(not frame.shown, "joining a raid never forces the party container to show")
env.group = "solo"
Native(function() frame:UpdateVisibility() end)
Native(NativeTick)
Flush()
assert(frame.shown, "leaving a raid in combat restores the solo frame")
env.settings.showSolo = false
Addon:RefreshSoloFrame()
assert(env.removals == 0 and frame.shown, "setting changes wait until combat ends")
env.combat = false
Event("PLAYER_REGEN_ENABLED")
assert(env.removals == 1 and not frame.shown)
env.settings.showSolo = true
Addon:RefreshSoloFrame()
env.raidStyle = false
Event("EDIT_MODE_LAYOUTS_UPDATED")
assert(not frame.shown and env.removals == 2)
env.raidStyle = true
Event("EDIT_MODE_LAYOUTS_UPDATED")
assert(frame.shown)
EditModeManagerFrame:EnterEditMode(); Flush()
local registrations = env.registrations
env.preview = false
frame:UpdateVisibility(); Flush(); Native(NativeTick)
assert(not frame.shown and env.registrations == registrations, "Edit Mode controls its own preview")
EditModeManagerFrame:ExitEditMode(); Flush()
assert(frame.shown)

env.settings.showSolo, frame.denied = false, true
Addon:RefreshSoloFrame()
local removals = env.removals
frame.denied, frame.secretAccess = false, true
Addon:RefreshSoloFrame()
assert(env.removals == removals, "defer cleanup for inaccessible or secret access results")
frame.secretAccess = false
Event("ADDON_RESTRICTION_STATE_CHANGED")
assert(not frame.shown and env.removals == removals + 1)
hooks = env.hooks
for _ = 1, 40 do
    env.settings.showSolo = true; Addon:RefreshSoloFrame()
    env.settings.showSolo = false; Addon:RefreshSoloFrame()
end
assert(#env.widgets == widgets and env.hooks == hooks and frame.player == player
    and player.unit == "player" and player.width == 100 and player.height == 50,
    "toggling reuses Blizzard's frame, unit binding, layout, and hooks")
for _, widget in ipairs(env.widgets) do
    assert(widget == SecureStateDriverManager or not widget.scripts.OnUpdate, "BRF adds no polling loop")
end

print("PASS: solo_frame_test (native player reuse, combat, party/raid, Edit Mode, restoration, allocation)")
