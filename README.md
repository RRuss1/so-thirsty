# So Thirsty

A lightweight addon for **WoW: Forever** that shows when your **healer is low on mana**, so the tank waits for them to drink before the next pull.

It's silent: it never posts to chat or plays a sound on its own. It only shows things, and only out of combat.

> **Status: beta.** The five indicators below are built but have not been tested in a group yet. See [CHANGELOG.md](CHANGELOG.md).

## Five ways to see it

Each one is a single switch. Use any mix.

| Indicator | What you see | Default |
|---|---|---|
| **Mana bar** | The healer's own mana bar on their party/raid frame turns yellow, orange, then red | on |
| **Pips** | Dots on the healer's frame: one below 50%, two below 30%, three below 10% | on |
| **Flask** | A flask on your screen for each healer, like a mana bar: the liquid drains with their mana, and the edge goes from their class color to yellow, orange, red. Several healers line up in a row or a column, and you can place them as one stack or one by one. Can be set to hide while they're fine | on |
| **Banner** | Five seconds after a fight, a line like "Lira's mana is at 30%" appears for a low healer, in their level color, for a few seconds | on |
| **Screen glow** | A soft haze on the edges of your screen as a healer runs dry, in the level colors or one color you pick | off |

- A healer who is **drinking** shows dimmed, with a drink mark.
- Everything hides **in combat**, and in battlegrounds and arenas.
- The flask, banner and screen glow work even if you keep **party frames hidden**.

## Good to know

- **The game hides mana numbers from addons** on Forever. So Thirsty can show mana as color and fill, but it can't know the number. That's why there are no automatic chat warnings. The one percentage, on the banner, is printed by the game itself; the addon never sees it.
- **Each player who wants the indicators needs the addon.** They're drawn on your own screen.
- It works with the game's own party and raid frames. ElvUI, Cell, Grid2 and VuhDo are planned.

## How it decides who the healer is

It uses the game's **role**: right-click the healer's portrait > **Set Role** > Healer (or the role check). No role set, nothing shows.

## The drink button

The one thing that posts to chat, and only when you click it. A small button appears when your role is Healer and you're in a group.

- **Left-click:** `[Thirsty] <you> needs a drink - hold the pull`
- **Right-click:** `[Thirsty] <you> is good to go`

It posts to party, raid or instance chat, whichever your group uses. Limits: 15 seconds between lines, 3 lines per 5 minutes, never in combat, never in battlegrounds or arenas. You can edit both lines and drag the button anywhere.

**Want it on a key?** `/sot macro` makes two macros ("SoT Drink" and "SoT Ready") and puts the first on your cursor to drop on an action bar. Or bind keys directly under **Key Bindings > AddOns > So Thirsty**.

## Options

`/sot` opens the options window, or left-click the minimap button. There's one short tab per indicator, plus Levels, Drink button and General.

- Changes show right away so you can judge them. Press **Save** to keep them; closing without Save undoes them.
- The Flask, Banner and Screen glow tabs show a sample while they're open. **Play** runs all five through a full drain on screen, with nothing posted.
- **Preview on screen** hides the window and shows every indicator where it really sits, so you can judge and drag them into place. Click **Back to Options** on the small bar to return.
- **Levels:** where each of the three levels starts (steps of 10) and its color, with presets including a color-blind safe one.

## Commands

`/sot` or `/thirsty`. Right-click the minimap button for the same list as a menu.

| Command | Does |
|---|---|
| `/sot` | Open the options window |
| `/sot status` | Healers being watched |
| `/sot on` / `off` | Turn it on or off |
| `/sot levels 50 30 10` | Set the three levels |
| `/sot bar` / `pips` / `flask` / `banner` / `glow` | Switch one indicator on or off |
| `/sot drink` / `ready` | Same as clicking the drink button |
| `/sot macro` | Make action-bar macros for the two chat lines |
| `/sot move` / `lock` | Show the flask and banner so you can drag them into place |
| `/sot test` | Play the preview (nothing is posted) |
| `/sot ghost 35` | How strongly the art shows behind windows (0 = off) |
| `/sot minimap` | Show or hide the minimap button |
| `/sot debug` | What the game tells the addon (paste this into bug reports) |
| `/sot debug looks` | Checks the indicators on your group members |
| `/sot debug frames` / `drink` / `icons` | Unit frames found; drink buffs; game art used |
| `/sot help` | Command list |

## Planned

Third-party unit frames (ElvUI, Cell, Grid2, VuhDo), translations.

## Privacy

So Thirsty sends nothing anywhere except one line to your own group chat when you click the drink button. See [PRIVACY.md](PRIVACY.md).
