# Changelog

## v0.4.0 — Five indicators (unreleased, not yet tested in a group)

The first group test showed the frame glow hiding under aggro borders, and the options had piled up. The frame looks are gone, replaced by five indicators with one switch each.

- **Mana bar color:** the healer's own mana bar on their frame turns yellow, orange, then red below level 1.
- **Pips:** dots on the healer's frame, one per level reached.
- **Flask:** a flask per healer anywhere on screen, always showing like a mana bar (or only when low, as an option). It drains with their mana; its edge goes from class color to the level colors. Has an opacity setting. Several healers line up in a row or a column, placed as one stack or one flask at a time.
- **After-fight banner:** 5 seconds after a fight, a low healer's name in their level color. Skipped on chain pulls, after a wipe and for a drinking healer.
- **Screen-edge glow:** a soft haze on the screen edges, in the level colors or one color of your own. Off by default.
- The flask, banner and screen glow work with party frames hidden.
- **Options window rebuilt:** bigger (900 × 660) and sparser so the art shows, tabs down the left (General first), one short tab per indicator. Opening the Flask, Banner or Screen glow tab shows a sample of it. Save / Undo changes kept.
- **Preview on screen:** tucks the Options window away and shows every indicator where it really sits, with the flask, banner and drink button ready to drag. The small preview box stays up; **Back to Options** reopens the window. Replaces the "Place it" buttons.
- **Removed:** tint, glow, border, corners and bar-strip looks; the pulse, nudge brighten, ready tick, range fade and grey edge; the thirst meter; the Ready level; color-band modes; feel presets; and all their settings. `/sot meter` is gone; `/sot bar`, `pips`, `flask`, `banner`, `glow` are new.
- Old settings are migrated: levels, colors, the drink button, zones and the minimap button carry over.
- `/sot debug looks` checks the three things not yet proven on this client (spec 16 Q25–Q27). The old probes (`debug mana`, `curve`, `swatch`, `window`, `party`) are removed; their answers are in the spec.

## v0.3.0 — Design v2: the glow (unreleased, superseded by v0.4.0)

In-game tests showed that Forever always hides mana from addons, so the first design (read mana, post chat warnings) can't exist. Design v2 showed mana as a glow on healer frames and added a manual chat button.

- **Kept in v0.4.0:** the curve engine (`Curves.lua`), healer tracking, drink detection, the combat gate, the **drink button** (one line per click, 15 s apart, 3 per 5 minutes, `[Thirsty]` tag, macros and key bindings), the **minimap button** with its right-click command menu, Save / Undo in Options, and the black-and-white art behind windows.
- **Found in game:** curves work on party members' mana; drink buffs are readable ("Drink", spell 1135); fade animations override a texture's own transparency, so they can't be used over mana-driven art.
- **Dropped in v0.4.0:** the glow and every other frame look, and the thirst meter.

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
