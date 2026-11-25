# SoThirsty — Project Instructions

The full design lives in `docs/SoThirsty-Design-Spec.md`. Read it before any work. It is the source of truth; if code and spec disagree, ask before changing either.

`README.md` is player-facing. Keep it in sync when behavior or commands change.

## What this is
- `addon/SoThirsty/`: WoW: Forever addon (Lua). Interface 16001, `SoThirsty_Forever.toc` + `SoThirsty.toc` (same contents).
- In-game only. No Discord, no Worker, no network, no relay, no addon-to-addon messages.
- Design v2: it SHOWS healer mana as a glow on party/raid frames. It can't know the number.

## Hard rules
- Mana, health and range are ALWAYS secret on Forever (spec 16 Q17). Never compare, test, store or do math on a secret value. Check with ns.IsSecret. Test only the `ok` flag the Curves functions return, never the values after it.
- Curves are the only path: Levels.lua makes plain point lists, Curves.lua builds `C_CurveUtil` curves and calls `UnitPowerPercent(unit, Mana, false, curve)`, and the secret result goes straight into SetVertexColor / SetAlpha / SetValue on our own textures. The curve input is 0–1.
- Never work around a secret: no reading text or bar values back, no measuring widths, no pixel tricks (spec 1.1).
- The quiet contract (spec 1.1) beats every other setting: silent by default, hidden in combat, one nudge per fight (5 s after combat), drinking means dim, chat only when a person clicks.
- Chat: only the drink button / `/sot drink` / `/sot ready` may post, one line per click, 30 s cooldown, 3 lines per 5 min. Never in combat, never in battlegrounds or arenas, never to SAY/YELL/RAID_WARNING. Channel per group type, gated by the Party / Raid / Instance checks.
- No raid warnings of any kind: never RaidWarningFrame / RaidNotice_AddMessage. No automatic sounds.
- Healers = UnitGroupRolesAssigned(unit) == "HEALER". Nothing else.
- Never taint Blizzard frames: our own non-secure holders, parented to UIParent, created and anchored out of combat. Post-hooks (HookScript) only; never replace or set anything on a Blizzard frame.
- Blizzard assets first (spec 9.7): game templates, ColorPickerFrame, textures, icons, fonts. Ship art only when the game has no equivalent. Every color option uses the color picker.
- Window palette comes from the icon (`art/SoThirstyIcon2.png`): violet-lit stone, violet glow, candle gold, brass, leather, a touch of fel green (spec 9.7).
- Keep it lightweight: no libraries, no OnUpdate (C_Timer and AnimationGroup only; the one exception is the minimap button while it is being dragged), unit events only for tracked healers, coalesced to one refresh per healer per 0.5 s.
- Keep the addon free, unobfuscated and ad-free (Blizzard UI Add-On Development Policy).

## How to work
- Build in the phases in spec Section 15. Each phase needs an in-game check by Rich before it counts as done.
- Small commits with short, clean messages. No `Co-Authored-By` or other AI attribution lines in commits or PR descriptions.
- Work on a branch, open a PR, wait for CI, rebase-merge.
- Track progress in CHANGELOG.md (one entry per phase). Tag each finished phase `v0.<phase>.0`; v1.0.0 at release.
- When a Forever API behavior is uncertain, add it to spec Section 16 and add a `/sot debug` subcommand to test it in game. Don't guess.
- `Levels.lua` stays pure (no WoW API) and every rule in spec 6.2 has a test in `addon/tests/logic.lua`. Write the tests first.
- Tests: `lua5.1 addon/tests/logic.lua` and `luajit addon/tests/logic.lua`; lint: `luacheck addon`. CI runs all three. There is no Lua on Rich's machine; CI is the test run.
