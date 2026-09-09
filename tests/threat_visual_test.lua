local env = assert(loadfile("tests/helpers/threat_env.lua"))()
local Addon, settings = env.Addon, env.settings
local frame = env.frame("party1")
Addon:UpdateThreatIndicator(frame)
assert(not frame.BRFThreatIndicator, "hidden threat allocates nothing")
env.status = 1
Addon:UpdateThreatIndicator(frame)
local indicator = frame.BRFThreatIndicator
assert(indicator.border.shown and indicator.texture.shown and not indicator.edge.shown)
assert(indicator.texture.color[1] == 1 and indicator.texture.color[2] == 1)
assert(indicator.animGroup.playing and indicator.border.color[4] == 1)

settings.threatIndicatorBorderColorR, settings.threatIndicatorBorderColorG, settings.threatIndicatorBorderColorB = .2, .3, .4
settings.threatIndicatorBorderSize = 3
settings.threatIndicatorBorderOpacity = 45
Addon:UpdateThreatIndicator(frame)
assert(indicator.border.color[1] == .2 and indicator.border.point[4] == 3)
assert(indicator.border.color[4] == .45 and indicator.texture.color[4] == 1, "outline opacity leaves the fill opaque")
settings.threatIndicatorShape = "CIRCLE"
Addon:UpdateThreatIndicator(frame)
assert(indicator.texture.mask and indicator.border.mask, "solid circles mask both the fill and outline")

settings.threatIndicatorShape = "BORDER"
Addon:UpdateThreatIndicator(frame)
assert(not indicator.texture.shown and not indicator.texture.mask and not indicator.border.shown)
assert(indicator.edge.shown and indicator.edge.backdrop.edgeFile == "Interface\\Buttons\\WHITE8X8")
assert(indicator.allPoints == frame and indicator.edge.borderColor[1] == 1 and indicator.edge.borderColor[2] == 1)
assert(indicator.edge.borderColor[4] == .45 and indicator.edge.backdrop.edgeSize == 3)
local function CheckInset(expected)
    local top, bottom = indicator.edge.points.TOPLEFT, indicator.edge.points.BOTTOMRIGHT
    assert(top[2] == indicator and top[3] == "TOPLEFT" and top[4] == expected and top[5] == -expected)
    assert(bottom[2] == indicator and bottom[3] == "BOTTOMRIGHT" and bottom[4] == -expected and bottom[5] == expected)
end
CheckInset(0)
settings.threatIndicatorBorderInset = 6
Addon:UpdateThreatIndicator(frame); CheckInset(6)
settings.threatIndicatorBorderInset = -4
Addon:UpdateThreatIndicator(frame); CheckInset(-4)
frame:SetSize(240, 80)
assert(indicator:GetWidth() == 240 and indicator:GetHeight() == 80, "the border must follow unit frame resizing")
CheckInset(-4)

settings.threatIndicatorBlink = false
Addon:UpdateThreatIndicator(frame)
assert(not indicator.animGroup.playing and indicator.alpha == 1 and indicator.edge.borderColor[4] == .45,
    "stopping blinking preserves the selected border opacity")
settings.threatIndicatorBorderOpacity = 0
Addon:UpdateThreatIndicator(frame)
assert(indicator.edge.borderColor[4] == 0, "zero opacity makes the border transparent")
settings.threatIndicatorBorderOpacity = 150
settings.threatIndicatorBorderInset = -100
Addon:UpdateThreatIndicator(frame); CheckInset(-16)
assert(indicator.edge.borderColor[4] == 1)
settings.threatIndicatorBorderOpacity = -10
settings.threatIndicatorBorderInset = 100
Addon:UpdateThreatIndicator(frame); CheckInset(16)
assert(indicator.edge.borderColor[4] == 0)
settings.threatIndicatorBorderOpacity = 0/0
settings.threatIndicatorBorderInset = math.huge
Addon:UpdateThreatIndicator(frame); CheckInset(0)
assert(indicator.edge.borderColor[4] == 1, "invalid saved values fall back to visible defaults")

settings.threatIndicatorBorderOpacity, settings.threatIndicatorBorderInset = 45, 6
settings.threatIndicatorShape = "SQUARE"
Addon:UpdateThreatIndicator(frame)
assert(indicator.texture.shown and not indicator.allPoints and indicator:GetWidth() == 8,
    "returning to a small indicator clears the full-frame anchors")
assert(indicator.border.shown and not indicator.edge.shown and indicator.border.point[4] == 3,
    "frame inset does not alter the small indicator outline")
assert(frame.BRFThreatIndicator == indicator and indicator.border.color[4] == .45,
    "visual changes reuse one indicator and preserve opacity")
settings.threatIndicatorShape = "BORDER"
Addon:UpdateThreatIndicator(frame); CheckInset(6)

-- Glow replaces the existing edge, preserving geometry, colour, and blink state.
local edge, animation = indicator.edge, indicator.animGroup
settings.threatIndicatorBorderStyle = "GLOW"
Addon:UpdateThreatIndicator(frame); CheckInset(6)
assert(edge.backdrop.edgeFile == "Interface\\TutorialFrame\\UI-TutorialFrame-CalloutGlow"
    and edge.backdrop.edgeSize == 8 and edge.borderBlendMode == "ADD")
assert(edge.borderColor[1] == 1 and edge.borderColor[2] == 1 and edge.borderColor[4] == .45)
assert(not animation.playing and not indicator.scripts.OnUpdate and not edge.scripts.OnUpdate,
    "steady glow needs neither another animation nor a Lua update loop")
settings.threatIndicatorGlowSize = 3
Addon:UpdateThreatIndicator(frame)
local backdrop, count = edge.backdrop, #env.widgets
for _ = 1, 1000 do Addon:UpdateThreatIndicator(frame) end
assert(edge.backdrop == backdrop and #env.widgets == count, "stable glow updates reuse the backdrop and UI objects")
for _ = 1, 50 do
    settings.threatIndicatorBorderStyle = "SOLID"
    Addon:UpdateThreatIndicator(frame)
    assert(edge.backdrop.edgeFile == "Interface\\Buttons\\WHITE8X8" and edge.borderBlendMode == "BLEND")
    settings.threatIndicatorBorderStyle = "GLOW"
    Addon:UpdateThreatIndicator(frame)
end
assert(indicator.edge == edge and indicator.animGroup == animation and #env.widgets == count,
    "style changes reuse the edge and existing blink animation, even at equal widths")
settings.threatIndicatorShape = "CIRCLE"
Addon:UpdateThreatIndicator(frame)
assert(not edge.shown and indicator.border.shown and indicator.border.mask,
    "a saved frame glow must not replace the small circle's outline")
settings.threatIndicatorShape = "BORDER"
Addon:UpdateThreatIndicator(frame); CheckInset(6)
assert(edge.shown and edge.borderBlendMode == "ADD" and not indicator.border.shown)
settings.threatIndicatorGlowSize = math.huge
Addon:UpdateThreatIndicator(frame)
assert(edge.backdrop.edgeSize == 8, "invalid glow width falls back to a visible default")
settings.threatIndicatorGlowSize = 100
Addon:UpdateThreatIndicator(frame)
assert(edge.backdrop.edgeSize == 32)
settings.threatIndicatorGlowSize = -1
Addon:UpdateThreatIndicator(frame)
assert(edge.backdrop.edgeSize == 1)
settings.threatIndicatorBorderStyle = "UNKNOWN"
Addon:UpdateThreatIndicator(frame)
assert(edge.backdrop.edgeFile == "Interface\\Buttons\\WHITE8X8" and edge.borderBlendMode == "BLEND")
settings.threatIndicatorBorderStyle, settings.threatIndicatorGlowSize = "GLOW", 8

settings.threatIndicatorBlink = true
local sample = env.frame()
Addon:UpdateThreatPreview(sample, settings, 2, true)
assert(sample.BRFThreatIndicator.edge.borderColor[2] == .6 and sample.BRFThreatIndicator.animGroup.playing)
assert(sample.BRFThreatIndicator.edge.borderColor[4] == .45 and sample.BRFThreatIndicator.edge.points.TOPLEFT[4] == 6,
    "previews use the same opacity and inset as live borders")
assert(sample.BRFThreatIndicator.edge.backdrop.edgeFile == "Interface\\TutorialFrame\\UI-TutorialFrame-CalloutGlow"
    and sample.BRFThreatIndicator.edge.borderBlendMode == "ADD", "previews use the same glow as live borders")
Addon:UpdateThreatPreview(sample, settings, 2, false)
assert(not sample.BRFThreatIndicator.shown and not sample.BRFThreatIndicator.animGroup.playing)
env.previewOpen, env.status = true, nil
Addon:UpdateThreatIndicator(frame)
assert(indicator.shown)
env.previewOpen = false
Addon:UpdateThreatIndicator(frame)
assert(not indicator.shown and not indicator.animGroup.playing)
env.status = 3
Addon:UpdateThreatIndicator(frame)
assert(indicator.shown and indicator.animGroup.playing, "real threat continues outside the settings preview")
assert(indicator.edge.borderColor[4] == .45, "hide/show and blinking must preserve border opacity")
print("PASS: threat_visual_test")
