# So Thirsty

A lightweight addon for **WoW: Forever** that shows when your **healer is low on mana**, so the tank waits for them to drink before the next pull.

- **A glow on the healer's frame.** Below 50% mana their party/raid frame glows yellow, turning orange and then red as mana falls, in 10% bands.
- **Silent.** It never posts to chat or plays a sound on its own.
- **Out of combat.** The glow hides during fights and gives one short nudge 5 seconds after a fight ends.
- **Drinking shows.** A healer who is drinking gets a dimmed glow and a drink icon.
- **One button for chat.** The healer can click "I need a drink" to post one line to the group.

> **Status: beta, not yet tested in a group.** Everything below is built, but only the mana-color part has been checked in game so far. See [CHANGELOG.md](CHANGELOG.md).

## Good to know

- **The game hides mana numbers from addons** on Forever. So Thirsty can show mana as a color, but it can't know the number. That's why there are no automatic chat warnings and no percentages in its text.
- **Each player who wants the glow needs the addon.** The glow is drawn on your own screen. Players without it only see the chat line, when the healer clicks the button.
- It works with the game's own party and raid frames. ElvUI, Cell, Grid2 and VuhDo are planned.

## How it decides who the healer is

It uses the game's **role**: right-click the healer's portrait > **Set Role** > Healer (or the role check). No role set, no glow.

## Levels

| Level | Default | Color |
|---|---|---|
| 1 "getting thirsty" | below 50% | yellow, faint |
| 2 "thirsty" | below 30% | orange |
| 3 "so thirsty" | below 10% | red, full strength, slow pulse |
| Ready | 90% and up | optional green tick after a fight |

**Minimap button:** left-click opens Options, right-click opens a menu of every command, drag to move it.

Levels move in steps of 10. Colors, glow style, strength, the pulse, the nudge and more are in the Options window (`/sot`). Changes show right away so you can judge them; press **Save** to keep them. Closing without Save undoes them.

## The drink button

A small button appears when your role is Healer and you're in a group.

- **Left-click:** posts `[Thirsty] <you> needs a drink - hold the pull`
- **Right-click:** posts `[Thirsty] <you> is good to go`

It posts to party, raid or instance chat, whichever your group uses. Limits: 15 seconds between lines, 3 lines per 5 minutes, never in combat, never in battlegrounds or arenas. You can edit both lines. Drag the button to move it.

**Want it on a key?** `/sot macro` makes two macros ("SoT Drink" and "SoT Ready") and puts the first on your cursor to drop on an action bar. Or bind keys directly under **Key Bindings > AddOns > So Thirsty**.

## Commands

`/sot` or `/thirsty`:

| Command | Does |
|---|---|
| `/sot` | Open the Options window |
| `/sot status` | Healers being watched |
| `/sot on` / `off` | Turn it on or off |
| `/sot levels 50 30 10` | Set the three levels |
| `/sot drink` / `ready` | Same as clicking the button |
| `/sot meter` | Show or hide the thirst meter (a small panel of healer mana bars) |
| `/sot move` / `lock` | Show the button and the meter so you can place them |
| `/sot macro` | Make action-bar macros for the two chat lines |
| `/sot test` | Play the preview (nothing is posted) |
| `/sot ghost 25` | How strongly the black-and-white logo shows behind windows (0 = off) |
| `/sot minimap` | Show or hide the minimap button |
| `/sot debug` | What the game tells the addon (paste this into bug reports) |
| `/sot debug party` | Checks that the glow works on group members |
| `/sot debug frames` | Which unit frame the glow sits on |
| `/sot debug drink` | Each healer's buffs and whether they count as drinking |
| `/sot debug icons` | The game icons the addon uses |
| `/sot help` | Command list |

## Planned

Third-party unit frames (ElvUI, Cell, Grid2, VuhDo), translations.

## Privacy

So Thirsty sends nothing anywhere except one line to your own group chat when you click the drink button. See [PRIVACY.md](PRIVACY.md).
