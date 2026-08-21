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
