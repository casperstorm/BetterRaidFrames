# BetterRaidFrames for Midnight

BetterRaidFrames is a lightweight World of Warcraft addon that extends Blizzard's default Raid-Style Party and Raid Frames with focused customization options.

**Made for Midnight.**

![BetterRaidFrames](asset.png)

> Tip: Join a Follower Dungeon to preview and configure your frames, or use Blizzard Edit Mode.

Discord username: `async`

## Features

- Profiles with automatic Party and Raid switching
- Simple Grow Right or Grow Left Raid group layouts
- Raid target markers with configurable anchors, offsets, and sizing
- Role icon display options
- Party leader indicator with configurable anchor, offsets, sizing, and combat visibility
- Optional name styling with positioning, sizing, truncation, class colors, transliteration, and text effects
- Square or circular threat indicator with configurable anchor, offsets, sizing, and optional blinking
- Buff duration indicators with up to eight coloured segments, fill or drain progress, placement on any frame edge, adjustable thickness and frame level, and a colour and caster filter for each buff
- Compact, Blizzard-style configuration window
- Event-driven updates designed to avoid unnecessary frame processing

## Usage

Type `/brf` or `/betterraidframes` to open the configuration window.

## FAQ

**How do I use it?**

For Party frames, enable **Use Raid-Style Party Frames** in Blizzard Edit Mode. Raid frame layout options can be configured from the **Frame Layout** section in `/brf`.

**How do I preview my changes?**

Join a Follower Dungeon or open Blizzard Edit Mode, then type `/brf`.

**How does Raid group growth work?**

Choose **Grow Right** or **Grow Left** under **Frame Layout**. BetterRaidFrames handles the Raid frame anchor automatically. Grow Left reverses the visual order so Group 1 stays fixed on the right and later groups are added to its left. This applies to Edit Mode's **Separate Groups** layouts. Changes requested during combat are applied after combat.

**Where do I edit frame and aura sizes?**

Open Blizzard Edit Mode and select the Party or Raid Frames.

**How do I highlight a buff such as Echo?**

Open **Buff Indicators** in `/brf`, enter the buff's name or spell ID (Echo: `364343`), and select **Add Buff**. Each buff gets its own segment inside every Raid-Style Party or Raid Frame. Click its colour swatch to choose a colour. **Mine** tracks your casts (including your pet); uncheck it to include any caster. The buff list scrolls when needed, and the animated preview reflects the display settings.

- **Progress:** Fill shows elapsed time; Drain starts full and shrinks as time runs out. Top and Bottom fill left to right and drain right to left. Left and Right fill top to bottom and drain bottom to top. A faint coloured track marks the active buff even when its fill is near zero.
- **Position:** Top, Bottom, Left, or Right, inset two pixels from the frame edge. Left and Right use vertical bars.
- **Thickness:** 1–12 pixels (default: 2). This controls bar height on the top/bottom edges and bar width on the left/right edges. Existing Height settings are preserved.
- **Frame level:** Adjust the drawing order relative to the raid frame, from -10 to 200 (default: 10). Higher values draw above other elements; lower values can place indicators behind them. This changes the indicators' level within the raid frame's existing frame strata.

One buff uses the full line. Multiple buffs divide the line into fixed segments in list order: left to right for horizontal edges, top to bottom for vertical edges. Space is reserved for disabled or absent buffs. Removing a buff redistributes the segments. Settings belong to the current profile. Blizzard's normal buff and debuff icons remain in place.

These indicators use the Retail 12.1 aura container API; Blizzard handles aura matching, visibility, and duration progress. Buffs without a duration still have a visible track while present. If an existing display cannot be restyled during aura restrictions, changes are saved and applied when restrictions end. Indicators awaiting new settings are hidden. Use the buff's spell ID when it differs from the spell that applies it.

**Where are Blizzard's Raid Frame options?**

Go to **Options > Interface > Raid Frames**.

**How can I track targeted spells?**

Use [Targeted Spells](https://www.curseforge.com/wow/addons/targetedspells).

## Installation

1. Download the latest release.
2. Extract the `BetterRaidFrames` folder into your World of Warcraft `Interface/AddOns` directory.
3. Restart World of Warcraft or reload the UI.

## Links

- [CurseForge](https://www.curseforge.com/wow/addons/better-raid-frames)

## License

BetterRaidFrames is released under the GPL-3.0 License. See [LICENSE](LICENSE) for details.
