# So Thirsty

A lightweight addon for **WoW: Forever** that tells your group when the **healer is low on mana**, so the tank waits for them to drink before the next pull.

- **Only one person in the group needs it.** It watches every healer, including healers who don't have the addon.
- **Never mid-fight.** It speaks once, about 10 seconds after combat ends, and only if the healer is low **and not already drinking**.
- **Calm by design.** One chat line per fight at most, never the same warning twice, and never raid warnings.

> **Status: early development.** Phases 1–2 (skeleton, healer tracking, `/sot status`) are built. Warnings, frame highlights and the Options window come next. See [CHANGELOG.md](CHANGELOG.md).

## How it decides who the healer is

It uses the game's **role**: right-click the healer's portrait > **Set Role** > Healer (or the role check). No role set, no warnings.

## Warning levels

| Level | Default | Default outputs |
|---|---|---|
| 1 | below 50% | frame highlight + on-screen (no chat) |
| 2 | below 30% | + party and instance chat |
| 3 | below 10% | + raid chat and a sound |
| Ready | back to 90% | clears the highlight, on-screen only |

Every level, color, chat channel and sound will be adjustable in the Options window.

## Commands

`/sot` or `/thirsty`:

| Command | Does |
|---|---|
| `/sot status` | Healers being watched, their mana, and whether they're drinking |
| `/sot on` / `off` | Turn it on or off |
| `/sot levels 50 30 10` | Set the three warning levels |
| `/sot ghost 25` | How strongly the faint waterskin shows behind windows (0 = off) |
| `/sot debug` | What the game tells the addon (paste this into bug reports) |
| `/sot debug mana` | Every way the game offers to read mana, and which ones it hides |
| `/sot debug curve` | Whether hidden mana can still drive a color or a fade |
| `/sot debug drink` | Each healer's buffs and whether they count as drinking |
| `/sot debug events` | Print role and combat events live (toggle) |
| `/sot debug window` | Open a sample window |
| `/sot help` | Command list |

## Planned

Third-party unit frames (ElvUI, Cell, Grid2, VuhDo), a small "thirst meter" panel, translations.

## Privacy

So Thirsty sends nothing anywhere except your own group chat, when a warning is set to post there. See [PRIVACY.md](PRIVACY.md).
