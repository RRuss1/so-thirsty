# SoThirsty — Project Instructions

The full design lives in `docs/SoThirsty-Design-Spec.md`. Read it before any work. It is the source of truth; if code and spec disagree, ask before changing either.

`README.md` is player-facing. Keep it in sync when behavior or commands change.

## What this is
- `addon/SoThirsty/`: WoW: Forever addon (Lua). Interface 16001, `SoThirsty_Forever.toc` + `SoThirsty.toc` (same contents).
- In-game only. No Discord, no Worker, no network, no relay, no addon-to-addon messages.
- Design v3: it SHOWS healer mana through five indicators (mana bar color, pips, flask, after-fight banner, screen-edge glow). It can't know the number.

## Hard rules
- Mana, health and range are ALWAYS secret on Forever (spec 16 Q17). Never compare, test, store or do math on a secret value. Check with ns.IsSecret. Test only the `ok` flag the Curves functions return, never the values after it.
- Curves are the only path: Levels.lua makes plain point lists, Curves.lua builds `C_CurveUtil` curves and calls `UnitPowerPercent(unit, Mana, false, curve)`, and the secret result goes straight into SetVertexColor / SetAlpha / SetTextColor / SetValue on our own art. The curve input is 0–1.
- Known states (combat, drinking, dead, zone) are plain alpha set on our own FRAMES; mana-driven values go on TEXTURES. The two multiply on screen and are never multiplied in Lua.
- Never work around a secret: no reading text or bar values back, no measuring widths, no pixel tricks (spec 1.1).
- The quiet contract (spec 1.1) beats every other setting: silent by default, hidden in combat, one after-fight banner (5 s after combat), drinking means dim, chat only when a person clicks, few options.
- Few options: each indicator has one switch and a handful of its own settings, on its own tab. Don't add an option without a reason (spec 1.1 rule 8).
- Chat: only the drink button / `/sot drink` / `/sot ready` may post, one line per click, 15 s cooldown, 3 lines per 5 min. Never in combat, never in battlegrounds or arenas, never to SAY/YELL/RAID_WARNING. Channel per group type, gated by the Party / Raid / Instance checks.
- No raid warnings of any kind: never RaidWarningFrame / RaidNotice_AddMessage. No automatic sounds.
- Healers = UnitGroupRolesAssigned(unit) == "HEALER". Nothing else.
- Never taint Blizzard frames: our own non-secure frames, parented to UIParent, created and anchored out of combat. Post-hooks (HookScript) only; reading where a unit frame's power bar is is fine, setting anything on a Blizzard frame is not.
- Every setter that isn't proven on Forever goes through pcall with a plain fallback, so a refusal degrades instead of erroring.
- Blizzard assets first (spec 9.3): game templates, ColorPickerFrame, textures, icons, fonts. Ship art only when the game has no equivalent. Every color option uses the color picker.
- Window palette comes from the icon: violet-lit stone, violet glow, candle gold, brass, leather (spec 9.3).
- Keep it lightweight: no libraries, no OnUpdate (C_Timer only; the one exception is the minimap button while it is being dragged), no Alpha or Scale AnimationGroup over mana-driven textures (it overrides their alpha), unit events only for tracked healers, coalesced to one refresh per healer per 0.5 s.
- Keep the addon free, unobfuscated and ad-free (Blizzard UI Add-On Development Policy).

## How to work
- Nothing counts as done until Rich has checked it in game. Say plainly what has and hasn't been tested there.
- Small commits with short, clean messages. No `Co-Authored-By` or other AI attribution lines in commits or PR descriptions.
- Work on a branch, open a PR, wait for CI, rebase-merge.
- Track progress in CHANGELOG.md and spec Section 15.
- When a Forever API behavior is uncertain, add it to spec Section 16 and add a `/sot debug` subcommand to test it in game. Don't guess.
- `Levels.lua` stays pure (no WoW API) and every rule in spec 6.2 has a test in `addon/tests/logic.lua`. Write the tests first.
- Tests: `lua5.1 addon/tests/logic.lua` and `luajit addon/tests/logic.lua`; lint: `luacheck addon`. CI runs all three. There is no Lua on Rich's machine; CI is the test run.
