# SoThirsty — Project Instructions

The full design lives in `docs/SoThirsty-Design-Spec.md`. Read it before any work. It is the source of truth; if code and spec disagree, ask before changing either.

`README.md` is player-facing. Keep it in sync when behavior or commands change.

## What this is
- `addon/SoThirsty/`: WoW: Forever addon (Lua). Interface 16001, `SoThirsty_Forever.toc` + `SoThirsty.toc` (same contents).
- In-game only. No Discord, no Worker, no network, no relay.
- Only one player in the group needs the addon; it watches every healer.

## Hard rules
- The quiet contract (spec 1.1) beats every other setting: one alert window per fight (10 s after combat), skip healers who are drinking, escalation only, one merged chat line per window, one elected poster per group, 3 lines / 5 min cap.
- Forever addon API = modern Midnight client with restrictions: secret values may hide unit data (power, auras, combat flags) — check with ns.IsSecret and degrade gracefully; no COMBAT_LOG_EVENT_UNFILTERED; addon comms restricted in encounters (queue + flush, out of combat only); no realms — key by GUID.
- Warnings fire OUT OF COMBAT ONLY. Never send chat in combat, in battlegrounds or arenas, or to SAY/YELL/RAID_WARNING. No raid warnings of any kind: never RaidWarningFrame / RaidNotice_AddMessage; on-screen = our own banner.
- Chat channels are chosen per level (Party / Raid / Instance checks, spec 6.1).
- Healers = UnitGroupRolesAssigned(unit) == "HEALER". Nothing else.
- Never taint Blizzard frames: our own non-secure overlays only, created/anchored out of combat.
- Blizzard assets first (spec 9.7): game templates, ColorPickerFrame, textures, icons, fonts, SOUNDKIT. Ship art only when the game has no equivalent. Every color option uses the color picker.
- Window palette comes from the icon (`art/SoThirstyIcon2.png`): violet-lit stone, violet glow, candle gold, brass, leather, a touch of fel green (spec 9.7).
- Keep it lightweight: no libraries, no OnUpdate, UNIT_POWER_UPDATE only, auras scanned only when a window closes.
- Keep the addon free, unobfuscated and ad-free (Blizzard UI Add-On Development Policy).

## How to work
- Build in the phases in spec Section 15. Finish and test one phase before starting the next.
- Small commits with short, clean messages. No `Co-Authored-By` or other AI attribution lines in commits or PR descriptions.
- Work on a branch, open a PR, wait for CI, rebase-merge.
- Track progress in CHANGELOG.md (one entry per phase). Tag each finished phase `v0.<phase>.0`; v1.0.0 at release.
- When a Forever API behavior is uncertain, add it to spec Section 16 and add a `/sot debug` subcommand to test it in game. Don't guess.
- `Levels.lua` stays pure (no WoW API) and every rule in spec 6.2 has a test in `addon/tests/logic.lua`. Write the tests first.
- Tests: `lua5.1 addon/tests/logic.lua` and `luajit addon/tests/logic.lua`; lint: `luacheck addon`. CI runs all three.
