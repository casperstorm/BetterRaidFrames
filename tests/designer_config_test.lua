local env = assert(loadfile("tests/helpers/designer_env.lua"))()
local Addon = env.Addon
local cvarApplies = 0
function Addon:ApplyBlizzardCVars() cvarApplies = cvarApplies + 1 end
assert(loadfile("IndicatorEditor.lua"))("BetterRaidFrames", Addon)
assert(loadfile("IndicatorsConfig.lua"))("BetterRaidFrames", Addon)
local content = env.frame()
content:SetSize(676, 620)
local refresh = Addon:BuildDesignerOptions(content, -38)
local sizedPreview = env.find(function(w) return w.GetAvailableSize ~= nil end)
local nativeFrame = env.frame("player")
nativeFrame:SetSize(100, 90)
env.partyFrames = { nativeFrame }
refresh()
assert(sizedPreview:GetWidth() == 100 and sizedPreview:GetHeight() == 90 and sizedPreview.scale == 1)
assert(sizedPreview.parent:GetHeight() == 90, "the preview row reserves the displayed height")
nativeFrame:SetSize(100, 56)
refresh()
assert(sizedPreview.parent:GetHeight() == 56, "smaller frames give the editor its space back")
local function visible(w) return w.shown and (not w.parent or visible(w.parent)) end
local function click(w) assert(w, "missing widget"); w.scripts.OnClick(w) end
local function button(text)
    return env.find(function(w) return w.kind == "Button" and w.text == text and visible(w) end)
end
local function checkbox(text)
    return env.find(function(w) return w.Text and w.Text.text == text end)
end
local function dropdown(label)
    return env.find(function(w) return w.label and w.label.text == label and w.kind == "DropdownButton" and visible(w) end)
end
local function choose(label, value)
    for _, option in ipairs(dropdown(label).menu.items) do
        if option.value == value then option.callback(value); return end
    end
    error("choice not found: " .. label .. "/" .. value)
end
local function slider(label)
    return env.find(function(w) return w.label and w.label.text == label and w.template == "MinimalSliderWithSteppersTemplate" end)
end
local function group(anchor)
    return env.find(function(w) return w.anchor == anchor and w.toggle and visible(w) end)
end
local function member(id)
    return env.find(function(w) return w.item and w.item.id == id and visible(w) end)
end
local function selectItem(id) click(member(id).select) end
local function selectGroup(anchor) click(group(anchor).select) end
local input = env.find(function(w) return w.kind == "EditBox" and w.height == 24 end)
local function addBuff(anchor, spell)
    click(group(anchor).add)
    assert(visible(input))
    input:SetText(tostring(spell)); click(button("Add"))
    local set = Addon:GetIndicatorSet()
    return set.items[#set.items].id
end
local function item(key, id) return Addon:FindDesignerIndicator(key, id) end
local blizzardBuffs = checkbox("Show Blizzard buff icons")
local blizzardDebuffs = checkbox("Show Blizzard debuff icons")
assert(blizzardBuffs:GetChecked() and blizzardDebuffs:GetChecked() and cvarApplies == 0,
    "unset profile values show Blizzard's default")
blizzardBuffs:SetChecked(false); click(blizzardBuffs)
assert(env.settings.blizzardBuffs == false and env.settings.blizzardDebuffs == nil and cvarApplies == 1)
blizzardDebuffs:SetChecked(false); click(blizzardDebuffs)
assert(env.settings.blizzardDebuffs == false and env.settings.blizzardBuffs == false and cvarApplies == 2)
blizzardDebuffs:SetChecked(true); click(blizzardDebuffs)
assert(env.settings.blizzardDebuffs == true and cvarApplies == 3)

assert(#dropdown("Groups").menu.items == 9)
local beforeGroup = env.settings.indicators
choose("Groups", "BOTTOMRIGHT")
assert(env.settings.indicators == beforeGroup, "choosing an empty group is navigation, not a profile override")
assert(#dropdown("Groups").menu.items == 8)
assert(visible(slider("X offset (px)")) and not visible(slider("Layer / Z offset")))
local inspector = slider("X offset (px)").parent.parent.parent.parent
local inspectorPoint = inspector.point
assert(inspectorPoint and inspectorPoint[1] == "BOTTOMRIGHT", "the inspector is anchored independently of the tree")
local a = addBuff("BOTTOMRIGHT", "Echo")
assert(item("default", a).type == "ICON" and item("default", a).anchor == "BOTTOMRIGHT")
assert(not visible(slider("X offset (px)")), "spell editors contain no group layout controls")
assert(visible(slider("Size (px)")))
choose("Display", "SQUARE")
choose("Display", "ICON")
click(button("Text")); choose("Text", "STACKS")
assert(item("default", a).text == "STACKS")
click(button("Display"))
local glow, pulse = checkbox("Glow"), checkbox("Pulse glow")
assert(not glow:GetChecked() and not pulse:GetChecked() and not pulse.enabled)
glow:SetChecked(true); click(glow)
pulse:SetChecked(true); click(pulse)
slider("Size (px)"):SetValue(26)
assert(item("default", a).glow and item("default", a).glowPulse and item("default", a).size == 26)
local staleItemMenu = dropdown("Move to group").menu.items[1]

choose("Editing set", "1468")
assert(visible(slider("X offset (px)")), "sets open on group settings")
selectItem(a)
assert(glow:GetChecked() and pulse:GetChecked(), "specializations inherit Default")
pulse:SetChecked(false); click(pulse)
glow:SetChecked(false); click(glow)
assert(not item("1468", a).glow and not item("1468", a).glowPulse)
assert(item("default", a).glow and item("default", a).glowPulse and not pulse.enabled)
staleItemMenu.callback(staleItemMenu.value)
assert(item("1468", a).anchor == "BOTTOMRIGHT", "stale item menus cannot write to another set")
selectGroup("BOTTOMRIGHT")
choose("Grow", "UP")
slider("X offset (px)"):SetValue(-12); slider("Y offset (px)"):SetValue(8)
click(button("+ Advanced"))
assert(visible(slider("Layer / Z offset")))
slider("Layer / Z offset"):SetValue(240)
env.combat = true
click(button("Above Blizzard icons"))
assert(Addon:GetIndicatorSet().groups.BOTTOMRIGHT.offsetZ == 240)
env.combat = false
click(button("Above Blizzard icons"))
assert(Addon:GetIndicatorSet().groups.BOTTOMRIGHT.offsetZ == 200)
assert(Addon:GetIndicatorSet("default").groups.BOTTOMRIGHT.offsetZ == 0)
assert(Addon:GetIndicatorSet("default").groups.BOTTOMRIGHT.offsetX == 0)
click(button("− Advanced"))
assert(not visible(slider("Layer / Z offset")))
local b = addBuff("BOTTOMRIGHT", 355941)
assert(inspector.point == inspectorPoint, "selecting another spell must not move the inspector")
assert(item("1468", b).anchor == "BOTTOMRIGHT")
assert(not item("1468", b).glow and not item("1468", b).glowPulse)
click(button("↑"))
assert(Addon:GetIndicatorSet().items[1].id == b and not button("↑").enabled)
click(button("↓"))
assert(Addon:GetIndicatorSet().items[2].id == b and not button("↓").enabled)
click(button("Copy"))
local copy = Addon:GetIndicatorSet().items[3].id
assert(copy ~= b and item("1468", copy).anchor == "BOTTOMRIGHT")
click(button("Remove"))
assert(not item("1468", copy) and visible(slider("Spacing (px)")), "removing a spell returns to its group")
local toggle = member(b).enabled
toggle:SetChecked(false); click(toggle)
assert(not item("1468", b).enabled)
toggle:SetChecked(true); click(toggle)

-- Moving a group keeps both spells, their order and shared offsets together.
choose("Position", "TOPLEFT")
assert(item("1468", a).anchor == "TOPLEFT" and item("1468", b).anchor == "TOPLEFT")
assert(Addon:GetIndicatorSet().items[1].id == a and Addon:GetIndicatorSet().items[2].id == b)
assert(slider("X offset (px)").value == -12 and slider("Y offset (px)").value == 8)
assert(slider("Layer / Z offset").value == 200)
assert(group("TOPLEFT").select.selected)
assert(Addon:GetIndicatorSet("default").items[1].anchor == "BOTTOMRIGHT")
local staleGroupMenu = dropdown("Grow").menu.items[1]
choose("Groups", "BOTTOMRIGHT")
staleGroupMenu.callback(staleGroupMenu.value)
assert(Addon:GetIndicatorSet().groups.BOTTOMRIGHT.grow == "LEFT", "group menus capture the selected group")
for _, option in ipairs(dropdown("Position").menu.items) do
    assert(option.value ~= "TOPLEFT", "group positions never offer an occupied anchor")
end
selectItem(b)
choose("Move to group", "BOTTOMRIGHT")
assert(item("1468", b).anchor == "BOTTOMRIGHT" and item("1468", a).anchor == "TOPLEFT")
selectGroup("BOTTOMRIGHT")
assert(slider("X offset (px)").value == 0 and slider("Layer / Z offset").value == 0)
selectItem(b)
choose("Display", "SQUARE")
glow:SetChecked(true); click(glow)
pulse:SetChecked(true); click(pulse)
glow:SetChecked(false); click(glow)
assert(pulse:GetChecked() and not pulse.enabled, "turning glow off retains the pulse preference")
glow:SetChecked(true); click(glow)
local swatch = env.find(function(w) return w.kind == "Button" and w.width == 22 and visible(w) end)
click(swatch)
local original = item("1468", b).color
env.colorPicker.swatchFunc()
assert(item("1468", b).color.a == .4)
env.colorPicker.cancelFunc()
assert(item("1468", b).color.r == original.r)
click(swatch)
local staleColor = env.colorPicker
selectGroup("BOTTOMRIGHT")
staleColor.swatchFunc()
assert(item("1468", b).color.r == original.r, "selecting a group invalidates the old spell colour picker")
selectItem(b)
click(button("Change buff"))
assert(input:GetText() == "355941")
input:SetText("376788"); click(button("Save buff"))
assert(item("1468", b).spellID == 376788 and item("1468", b).type == "SQUARE")
assert(member(b).select.label.text:match("^Echoed "), "Echoed aura names stay distinct")
click(group("BOTTOMRIGHT").toggle)
assert(group("BOTTOMRIGHT").toggle.text == "+" and visible(slider("Spacing (px)")))
for _, w in ipairs(env.widgets) do
    assert(not (w.item and w.item.id == b and visible(w)), "collapsed groups hide their children")
end
selectGroup("BOTTOMRIGHT")
assert(member(b))

-- Changing selection, profile or combat state cannot redirect pending edits.
choose("Editing set", "default")
selectItem(a)
env.combat = true
pulse:SetChecked(false); click(pulse)
blizzardBuffs:SetChecked(true); click(blizzardBuffs)
blizzardDebuffs:SetChecked(false); click(blizzardDebuffs)
slider("Size (px)"):SetValue(40)
choose("Move to group", "TOP")
assert(item("default", a).glowPulse and item("default", a).size == 26 and item("default", a).anchor == "BOTTOMRIGHT")
assert(not blizzardBuffs:GetChecked() and blizzardDebuffs:GetChecked() and cvarApplies == 3,
    "combat blocks Blizzard aura changes")
selectGroup("BOTTOMRIGHT")
choose("Position", "TOP")
assert(item("default", a).anchor == "BOTTOMRIGHT")
click(group("BOTTOMRIGHT").add)
input:SetText("774"); click(button("Add"))
assert(#Addon:GetIndicatorSet("default").items == 1)
env.combat = false
local oldSettings = env.settings
env.profile, env.settings = "Another", { indicators = Addon:NormalizeIndicators(nil) }
refresh()
assert(#dropdown("Groups").menu.items == 9, "empty draft groups do not leak into another profile")
assert(blizzardBuffs:GetChecked() and blizzardDebuffs:GetChecked(), "Blizzard aura checkboxes follow the active profile")
staleColor.cancelFunc()
choose("Groups", "BOTTOMRIGHT")
addBuff("BOTTOMRIGHT", 774)
assert(#Addon:GetIndicatorSet().items == 1 and #oldSettings.indicators.sets.default.items == 1)

local payload = { version = 1, set = Addon:NormalizeIndicatorSet({ items = { { id = 1, spellID = 17, type = "ICON" } } }) }
C_EncodingUtil = { DecodeBase64 = function(s) return s end, DecompressString = function(s) return s end, DeserializeJSON = function() return payload end }
click(button("Import"))
local shareInput = env.find(function(w) return w.kind == "EditBox" and w.height == 26 end)
shareInput:SetText("BRFI1:json"); click(button("Review Import"))
assert(Addon:GetIndicatorSet().items[1].spellID == 774, "review must not replace settings")
click(button("Replace Set"))
assert(Addon:GetIndicatorSet().items[1].spellID == 17 and visible(slider("Spacing (px)")))
-- Warm both editor views, then ensure navigating them keeps a bounded UI pool.
selectItem(1); selectGroup("BOTTOMRIGHT")
local count = #env.widgets
for _ = 1, 100 do selectItem(1); selectGroup("BOTTOMRIGHT") end
assert(#env.widgets == count, "group/item navigation reuses controls and preview visuals")
print("designer group editor tests passed")
