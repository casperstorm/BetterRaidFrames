local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
local function near(actual, expected, message)
    assert(math.abs(actual - expected) < 0.00001, message or (tostring(actual) .. " ~= " .. tostring(expected)))
end

UIParent = env.frame()
UIParent:SetScale(0.8)
local parent = env.frame()
parent:SetParent(UIParent); parent:SetScale(1.25)
CompactPartyFrame = env.frame()
CompactPartyFrame:SetParent(UIParent); CompactPartyFrame:SetScale(1.5)
CompactRaidFrameContainer = env.frame()
CompactRaidFrameContainer:SetParent(UIParent)
local party, raid = env.frame("player"), env.frame("raid1")
party:SetParent(CompactPartyFrame); party:SetSize(100, 56)
raid:SetParent(CompactRaidFrameContainer); raid:SetSize(80, 40)
env.partyFrames, env.raidFrames = { party }, { raid }

Enum.EditModeUnitFrameSystemIndices = { Party = 1, Raid = 2 }
CompactUnitFrameUtil = { NativeFrameWidth = 72, NativeFrameHeight = 36, ApplyConfig = function() end }
local configured = { [1] = { 110, 60 }, [2] = { 90, 45 } }
EditModeManagerFrame = env.frame()
function EditModeManagerFrame:IsInitialized() return true end
function EditModeManagerFrame:GetRaidFrameWidth(index) return configured[index][1] end
function EditModeManagerFrame:GetRaidFrameHeight(index) return configured[index][2] end

local preview = Addon:CreateDesignerPreview(parent)
local displayWidth, displayHeight, label
function preview:OnSizeResolved(w, h, text) displayWidth, displayHeight, label = w, h, text end
local set = Addon:NormalizeIndicatorSet({ items = {
    { id = 1, spellID = 774, type = "SQUARE", size = 48, anchor = "BOTTOMRIGHT" },
    { id = 2, spellID = 364343, type = "ICON", size = 48, anchor = "BOTTOMRIGHT" },
}, groups = { BOTTOMRIGHT = { grow = "LEFT", spacing = 2 } } })
local function refresh() return preview:Refresh(set, 1, {}) end

assert(refresh(), "98-wide group overflows a 100-wide frame with its insets")
assert(label == "Party · Actual size" and preview:GetWidth() == 100 and preview:GetHeight() == 56)
near(preview:GetEffectiveScale(), party:GetEffectiveScale(), "match physical scale despite a differently scaled settings parent")
near(displayWidth, 120); near(displayHeight, 67.2)
local icon = env.find(function(w) return w.kind == "Texture" and w.texture == 364344 end)
near(icon:GetEffectiveScale(), party:GetEffectiveScale(), "icons inherit the same effective scale as live indicators")
assert(icon.parent:GetWidth() == 48, "copying frame dimensions must not rewrite indicator sizes")

-- Never measure hidden retained frames or inaccessible objects.
local hidden = env.frame(); hidden:Hide()
local forbidden = env.frame(); forbidden.forbidden = true
env.partyFrames = { hidden, forbidden, party }
assert(refresh() and preview:GetWidth() == 100)
party:SetSize(150, 80)
assert(not refresh(), "overflow must follow the resized frame")
local health = env.find(function(w) return w.kind == "Texture" and w.parent == preview and w.color and w.color[1] == 0.24 end)
near(health.width, 148 * 0.83); near(health.height, 78)

env.raid = true
refresh()
assert(label == "Raid · Actual size" and preview:GetWidth() == 80 and preview:GetHeight() == 40)
near(preview:GetEffectiveScale(), raid:GetEffectiveScale())
raid:Hide()
refresh()
assert(label == "Raid · Edit Mode size" and preview:GetWidth() == 90)
env.raid = false
party:Hide()
refresh()
assert(label == "Party · Edit Mode size" and preview:GetWidth() == 110)
configured[1] = { 130, 75 }
refresh()
assert(preview:GetWidth() == 130, "saved layout changes supersede old cached dimensions while solo")

-- During restricted access retain public geometry from the same context.
party:Show(); party.accessDenied = true
env.combat = true
refresh()
assert(label == "Party · Last known size" and preview:GetWidth() == 130)
env.raid = true
refresh()
assert(preview:GetWidth() == 90, "raid and party caches must remain independent")
env.raid = false
party.accessDenied = false
party.GetSize = function() return "secret", "secret" end
party.GetEffectiveScale = function() return "secret" end
refresh()
assert(preview:GetWidth() == 130, "secret dimensions/scale must never reach comparisons or arithmetic")
party.GetSize, party.GetEffectiveScale = nil, nil
party.secretAccessResult = true
refresh()
assert(preview:GetWidth() == 130, "secret access results must be rejected before reading frame geometry")
party.secretAccessResult = nil
env.combat = false

function preview:GetAvailableSize() return 120, 48 end
refresh()
near(displayHeight, 48)
assert(displayWidth <= 120 and label == "Party · Fit 50%", "oversized previews must label their reduction")
near(preview:GetEffectiveScale() / party:GetEffectiveScale(), 0.5)
preview.GetAvailableSize = nil

-- Coalesce native layout callbacks; events must stop when the section closes.
local timers, refreshes = {}, 0
C_Timer.After = function(delay, callback) assert(delay == 0); timers[#timers + 1] = callback end
function preview:RefreshOptions() refreshes = refreshes + 1; refresh() end
assert(preview.events.UI_SCALE_CHANGED and env.hooks.ApplyConfig)
for _ = 1, 20 do env.hooks.ApplyConfig(); preview.scripts.OnEvent(preview, "EDIT_MODE_LAYOUTS_UPDATED") end
assert(#timers == 1 and refreshes == 0)
local widgets = #env.widgets
timers[1](); timers = {}
assert(refreshes == 1 and #env.widgets == widgets, "size refreshes reuse existing frames, icons and text")
assert(not preview.scripts.OnUpdate, "static indicators do not gain a size polling timer")
env.hooks.ApplyConfig()
preview:Hide(); preview.scripts.OnHide()
assert(not next(preview.events), "a hidden preview unregisters its geometry events")
timers[1](); timers = {}
env.hooks.ApplyConfig()
assert(#timers == 0 and refreshes == 1, "queued callbacks must not revive hidden previews")
party:SetSize(105, 58)
preview:Show(); preview.scripts.OnShow()
assert(preview:GetWidth() == 105 and preview.events.GROUP_ROSTER_UPDATE)

-- Multi-sample sections use one measurement and one listener for the whole
-- row, sharing the same scale/fallback behaviour with the indicator designer.
parent:SetSize(676, 634)
local reads = 0
local ForEachFrame = Addon.ForEachFrame
function Addon:ForEachFrame(callback) reads = reads + 1; ForEachFrame(self, callback) end
local row = Addon:CreateFramePreviewRow(parent, 3, 120, { "First", "Second", "Third" })
row:RefreshSize()
assert(reads == 1 and row.events.GROUP_ROSTER_UPDATE and not next(preview.events),
    "changing sections moves the single geometry listener to the sample row")
for _, sample in ipairs(row.samples) do
    assert(sample:GetWidth() == 105 and sample:GetHeight() == 58)
    near(sample:GetEffectiveScale(), party:GetEffectiveScale())
end
near(row:GetHeight(), 44 + 58 * 1.2)
local caption = env.find(function(w) return w.text == "First" end)
near(caption:GetEffectiveScale(), parent:GetEffectiveScale(), "captions stay at the settings UI scale")
near(caption.point[3], -58 * 1.2 - 8)

party:SetSize(400, 200)
local rowWidgets = #env.widgets
for _ = 1, 10 do row.scripts.OnEvent(row, "UI_SCALE_CHANGED") end
assert(#timers == 1)
timers[1](); timers = {}
assert(reads == 2 and #env.widgets == rowWidgets, "all row samples resize in one pass without allocations")
local columnWidth = (676 - 48 - 48) / 3
for _, sample in ipairs(row.samples) do
    near(sample:GetWidth() * sample.scale, columnWidth)
    assert(sample:GetWidth() == 400 and sample:GetHeight() == 200, "fit preserves the underlying dimensions")
end
assert(env.find(function(w) return w.parent == row and w.kind == "FontString" end).text:find("Fit", 1, true),
    "the row reports when three live-sized frames do not fit")
near(row:GetHeight(), 44 + columnWidth / 2)
row:Hide(); row.scripts.OnHide()
env.hooks.ApplyConfig()
assert(not next(row.events) and #timers == 0)
local beforeHidden = reads
row:RefreshSize()
assert(reads == beforeHidden, "refreshing a hidden section does not sample live geometry")
assert(not row.scripts.OnUpdate)
preview:RefreshOptions()
assert(preview.events.GROUP_ROSTER_UPDATE and not next(row.events), "the designer resumes its watcher when revisited")

print("frame preview sizing tests passed")
