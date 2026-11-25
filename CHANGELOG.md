# Changelog

## v0.2.0 — Logic (unreleased)

- `Levels.lua`: the warning-level state machine (spec 6.2). Pure, with tests for every rule in spec 6.3.
- `Roster.lua`: finds healers by their Set Role role, reads their mana, keys them by GUID, coalesces mana updates to one every 0.5 s, and turns its events off when solo or when no one is a healer.
- `Drink.lua`: spots drink buffs on a healer; `/sot debug drink` shows buffs and the mana change over 10 seconds.
- `/sot status` and the addon compartment tooltip list each healer's mana, level and drinking state.
- `/sot levels 50 30 10` sets the three levels (rejects a bad order).
- Nothing is announced yet. Warnings come in Phase 3.
- `/sot debug mana`: first in-game test showed mana is a secret value even out of combat, so this probes every official way to read it (spec 16 Q17). Answer: none; mana is always secret on Forever.
- `/sot debug curve`: tests whether a curve can turn hidden mana into a color or a fade (spec 16 Q18). Answer: yes.
- `/sot debug swatch`: a live color and fade preview of your own mana, to settle the curve scale (spec 16 Q19). Answer: 0–1, updates live.

## v0.1.0 — Skeleton (unreleased)

- Repo, both TOCs, SavedVariables with every default from spec 12.1, slash commands (`/sot`, `/thirsty`), addon compartment entry.
- `/sot debug`: client info, group type, the chat channel that would be used, combat flags, and each member's role, mana and secret-value flags.
- `/sot debug events`: prints role and combat events live. `/sot debug window`: a sample window in the SoThirsty look.
- The SoThirsty icon (64 and 128 px) for the TOC, compartment and window title.
- Window helper adapted from Bounty Line, in the icon's palette (violet-lit stone, violet glow, candle gold, brass, leather), built from the game's own textures.
- A faint greyscale ghost of the icon behind every window's content; `/sot ghost 0-100` sets how strong (default 25).
- luacheck, CI on Lua 5.1 and LuaJIT, packager release workflow.
