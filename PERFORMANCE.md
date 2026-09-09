**Performance audit — 9 September 2026**

The local stress tests found avoidable allocation and background animation work. The changes below reduce both. They do not establish the addon's total RAM or CPU cost inside WoW: the test harness models public APIs, without the native renderer, template internals, or actual aura traffic.

- Cooldown frames, text hosts, font strings, and glow textures now allocate only when enabled, then remain available for reuse.
- Pulsing uses one native bouncing alpha animation instead of two sequential animations. It adds no Lua callback to an aura button.
- Stable updates reuse the prepared indicator layout and make no native container/style writes. Editing one indicator restyles only that indicator's reserved buttons; unchanged filters and layout settings are retained.
- Moving a group can reuse an inactive anchor's container. Removing indicators clears their native bindings and stops their pulses. Hidden unit frames disable their containers; cleanup checks current-context access to every visual object and waits while any is restricted. Restriction-ending events also finish cleanup for hidden raid frames that are no longer in the current party/raid layout.
- Hidden previews allocate no indicator visuals and stop their pulse animations and timer. Static previews need no Lua update callback. Removed preview IDs are discarded.
- Editing one specialization replaces only that set. Untouched specialization sets stay shared and immutable, and the prepared-layout cache uses weak keys so obsolete settings snapshots can be collected.

The same mock scenario was run before and after the changes: 40 unit frames, eight indicators per frame, and one anchor group per frame. Counts below are explicit addon-created UI objects, including native aura buttons, textures, font strings, and animation objects. They exclude Blizzard template internals and are **not byte measurements**.

| Indicator configuration | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Plain icons | 19,240 | 6,440 | 66.5% |
| Icons with cooldown swipes | 19,240 | 9,640 | 49.9% |
| Icons with cooldowns, duration text, and pulsing glow | 28,840 | 25,640 | 11.1% |

Across 40,000 unchanged updates, temporary Lua allocation with garbage collection paused fell from 7,656 KiB to below 1 KiB in this harness. The optimized path allocated no additional UI objects and performed no native style/container writes. This describes allocation churn, not a claim that the old version leaked 7.5 MiB permanently.

The regression test also checks removing/re-enabling indicators, shrinking groups, repeated moves through all nine anchors, hidden frames, deferred cleanup, preview lifecycle, and 1,100 setting edits. After warm-up and garbage collection, the editing test did not show continuing retained growth. All ten test suites pass, including the runtime and performance tests with Blizzard's actual AnchorUtil layout implementation.

Run the local checks with:

```sh
for test in tests/*_test.lua; do lua "$test" || exit 1; done
```

There is still a resource floor: Blizzard's dynamic layout preallocates ten aura buttons per indicator. Its single-button slots do not participate in the automatic layout needed to close gaps. Allocated pools stay available for reuse, so visiting a larger configuration can increase memory until `/reload`; that alone is not evidence of a leak. The code retains the 32-indicator limit and does not modify Blizzard's allocation or security rules. [Blizzard aura-container defaults](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerShared.lua), [pool lifecycle](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua).

For an in-game check, `/reload` first so the previous version's allocated frames are gone. Warm up the intended party/raid configuration, then compare reported addon memory at equivalent idle points after repeated encounters and settings open/close cycles. This command refreshes and prints WoW's reported addon memory on demand:

```lua
/run UpdateAddOnMemoryUsage(); print("BetterRaidFrames:", GetAddOnMemoryUsage("BetterRaidFrames"), "KiB")
```

Transient increases before garbage collection are normal. A steady rise after repeating the same warmed configuration needs investigation. Compare CPU with pulse on/off using WoW's addon profiler during actual encounters; the local harness cannot measure native animation or aura-processing cost. No automatic memory polling, forced garbage collection, or profiling CVar changes were added. [Blizzard's performance display uses these memory APIs](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_PerformanceBar/PerformanceBar.lua).
