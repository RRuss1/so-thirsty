# SoThirsty — Design Spec & Build Brief

> **For Claude Code (VS Code):** This is the source of truth for the SoThirsty addon. Read all of it before you write any code. If something here is unclear, or a Forever API behaves differently than described, **ask Rich or add the question to Section 16. Don't guess.**
>
> **Design v3.** v1 read healers' mana and posted chat warnings; Forever always hides mana from addons, so it couldn't exist. v2 drew a glow on party frames; in game the edge styles hid under aggro borders and the options piled up. v3 keeps v2's engine (curves) and replaces the looks with **five indicators**, each with one switch and very few options.

---

## 1. What it is

**SoThirsty** is a lightweight in-game addon for **WoW: Forever**. It shows when a **healer's mana is low**, so the tank waits for the healer to drink before the next pull.

- **Five indicators**, each on or off (Section 8): the healer's **mana bar changes color**, **pips** on their frame, a **draining flask**, an **after-fight banner**, and a **screen-edge glow**.
- It's **silent and automatic**. Nothing is posted to chat or played as a sound on its own.
- It works **out of combat**. Everything hides during fights.
- A healer who is **drinking** shows dimmed, with a drink mark.
- A manual **drink button** posts one line to group chat when a person clicks it. That is the only way SoThirsty ever speaks.
- It watches every group member whose **assigned role is Healer**.
- **Each player who wants the indicators needs the addon.** Three of the five work even with party frames hidden.
- **In-game only.** No Discord, no network, no addon-to-addon messages.

**Name and branding:** display name **So Thirsty**; folder `SoThirsty`; slash commands `/thirsty` and `/sot`; chat prefix color water blue `|cff4fc3f7`; chat tag `[Thirsty]`.

### 1.1 The quiet contract: informative, never annoying

These rules beat every setting.

1. **Silent by default.** SoThirsty never posts to chat and never plays a sound on its own.
2. **Out of combat.** Every indicator hides in combat, and in battlegrounds and arenas.
3. **One after-fight moment.** `banner.delay` (default **5 s**) after the group leaves combat, the banner shows once. Cancelled if combat restarts. None after a wipe.
4. **Drinking means dim.** A drinking healer's indicators dim to 35% and they're left off the banner.
5. **Chat only when a person clicks.** The drink button posts **one line per click**, 15 s apart, at most **3 lines per 5 minutes**. Never in combat, never in battlegrounds or arenas, never to SAY, YELL or RAID_WARNING.
6. **No raid warnings.** Never `RaidWarningFrame` / `RaidNotice_AddMessage`.
7. **Never work around a secret.** The addon never tries to recover a hidden number (no reading text back, no measuring bars, no pixel tricks). It only hands secret values to the game functions built to take them.
8. **Few options.** Each indicator gets one switch and at most a handful of its own settings. A new option needs a reason.

---

## 2. Target client

- **WoW: Forever, Interface `16001`.** Ship **both** `SoThirsty_Forever.toc` and `SoThirsty.toc` with the same contents.
- **A modern Midnight-based client with restrictions:**
  - **Secret values.** Mana, health and range are **always secret**, in and out of combat, even for the player (Q17). Check with `issecretvalue` through `ns.IsSecret`. Never compare, test or do math on a secret.
  - **Curves are the sanctioned path.** Build a curve with `C_CurveUtil`, pass it to `UnitPowerPercent(unit, Enum.PowerType.Mana, false, curve)`, and give the secret result to `SetAlpha` / `SetVertexColor` / `StatusBar:SetValue` on our own art. The curve input is **0–1**. `curve:Evaluate(secret)` is blocked for addon code (Q18, Q19).
  - **No Alpha or Scale `AnimationGroup` over mana-driven textures.** An Alpha animation on a parent overrides its children's alpha instead of multiplying (Q22). A frame's own `SetAlpha` multiplies correctly: that's how known states are applied.
  - `COMBAT_LOG_EVENT_UNFILTERED` is forbidden. No realms: key players by **GUID**.
- Lua 5.1. CI tests on `lua5.1` and `luajit`.

---

## 3. Repo layout

```
so-thirsty/
├── CLAUDE.md, README.md, CHANGELOG.md, CONTRIBUTING.md, PRIVACY.md, SECURITY.md, LICENSE
├── .gitignore, .luacheckrc, .pkgmeta, .github/ (issue templates, ci.yml, addon-release.yml)
├── art/                          # icon sources, fallback backgrounds (not packaged)
├── docs/SoThirsty-Design-Spec.md # THIS FILE
└── addon/
    ├── SoThirsty/
    │   ├── SoThirsty_Forever.toc, SoThirsty.toc, Bindings.xml
    │   ├── Locales/enUS.lua      # ALL player-facing text, plus drink aura names
    │   ├── Core.lua              # SavedVariables, defaults, slash commands, startup
    │   ├── Theme.lua             # palettes, icons, sizes (data only)
    │   ├── Levels.lua            # PURE logic: curve points, visibility, button caps
    │   ├── Roster.lua            # who's a healer, what the addon may know about them
    │   ├── Drink.lua             # drink buff check
    │   ├── Combat.lua            # group combat state, the after-fight timer, wipe check
    │   ├── Curves.lua            # builds C_CurveUtil curves; asks the game to apply them
    │   ├── Frames.lua            # on-frame indicators: mana bar color, pips
    │   ├── Button.lua            # the drink button, its chat line, macros
    │   ├── Debug.lua             # /sot debug ...
    │   ├── UI/Window.lua         # window helper (ns.CreateWindow, ns.Text)
    │   ├── UI/Flask.lua          # the draining flask
    │   ├── UI/Banner.lua         # the after-fight banner
    │   ├── UI/Vignette.lua       # the screen-edge glow
    │   ├── UI/Minimap.lua        # minimap button + right-click command menu
    │   ├── UI/Options.lua        # the options window
    │   └── Media/                # logo.tga, logo-128.tga, minimap.tga, ghost.tga, glow-*.tga
    └── tests/logic.lua           # stubbed-API tests: Levels, Roster, Combat, Button, commands
```

No libraries. Plain Blizzard API only. The TOC lists the Lua files in the order above (`UI\Window.lua` before the other UI files, `UI\Options.lua` last).

---

## 4. TOC

Interface 16001; Title "So Thirsty"; SavedVariables `SoThirstyDB` (account-wide); IconTexture `Media\logo`; the three AddonCompartment functions. `X-Curse-Project-ID` is added at release.

---

## 5. Healer detection

- A unit is tracked only when **`UnitGroupRolesAssigned(unit) == "HEALER"`** (works for a right-click Set Role in a normal party, Q1).
- Every addon user tracks every healer in the group; the local player doesn't have to be the healer.
- Re-scan on `GROUP_ROSTER_UPDATE`, `PLAYER_ROLES_ASSIGNED`, `ROLE_CHANGED_INFORM`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`.
- Units: `raid1`–`raid40`, or `player` + `party1`–`party4`. Solo does nothing and unregisters its unit events.
- Healers are stored by GUID: `{ guid, unit, name, class, drinking }`.
- **What the addon may know** (`Roster.Known`): enabled, zone allowed, group in combat, dead, offline, drinking. Never mana.
- **No role set anywhere:** one once-per-group hint, only to the leader, only inside an instance (`roleHint`).

---

## 6. Levels

### 6.1 Defaults

| Level | Default | Color (Classic preset) |
|---|---|---|
| 1 "getting thirsty" | **50%** | Yellow `#FFD100` |
| 2 "thirsty" | **30%** | Orange `#FF8000` |
| 3 "so thirsty" | **10%** | Red `#FF2020` |

- Thresholds move in **steps of 10** in Options (10–90); `/sot levels` accepts 1–99.
- They must be **strictly descending**. A bad edit is rejected with a message, never silently reordered.
- **Above level 1 nothing shows.** Below it, color blends smoothly from level 1's color to level 3's. Above level 1 the color is water blue `#4FC3F7` (seen only where an indicator is still visible, like the drink button's border).
- The addon can't "announce" a level: it never knows which one a healer is in. Only the screen shows it.

### 6.2 Pure logic (`Levels.lua`, fully unit-tested)

No WoW API. `Curves.lua` turns the point lists into real curves. Points are on the 0–1 scale.

- `Validate(levels)` → `true`, or `false` plus `"RANGE"` / `"ORDER"`.
- `ColorPoints(cfg, fine)` → linear color curve: level 3's color at 0 and at level 3, level 2's, level 1's, then `fine` just above level 1 (water blue unless a class color is passed).
- `AlphaPoints(cfg)` → the fade for the flask and screen glow: 1 at level 3 and below, down to `FAINT` (0.35) just under level 1, then 0 at level 1 and above.
- `LowPoints(cfg)` → step: 1 below level 1, 0 at and above (the bar color and banner text: solid on or off).
- `PipPoints(cfg, i)` → step: 1 below level `i`, 0 at and above.
- `ColorAt`, `AlphaAt`, `PipsLit`, and `Plain(pct, cfg)` → the same answers for a plain percent, for the previews. `Plain` returns `fraction, r, g, b, alpha, low, pip1, pip2, pip3`, the same order `Curves.All(unit)` returns the secret versions in.
- `Holder(known)` → known-state visibility: **0** when off, wrong zone, in combat, dead or offline; **0.35** and `drinking` when drinking; otherwise **1**.
- `CanNudge(known, wiped)` → may this healer be on the banner: not wiped, not drinking, not dead/offline, not in combat.
- `Wiped(dead, total)` → at least half the group and at least two players dead.
- `ButtonAllowed(now, log)` → `true`, or `false` plus `"COOLDOWN"` (15 s) / `"CAP"` (3 per 300 s).
- `Message(template, name, class)`; `Migrate(old)` (Section 12.1).

The final picture is always **known alpha (set by us on a frame) × secret alpha (set by the game on a texture)**. The two are never multiplied in Lua.

### 6.3 Required tests (`addon/tests/logic.lua`)

Every function above: validation cases; the color, fade, low and pip points at default and custom levels; `PipsLit` at the boundaries (at a level = not yet lit); `Plain` at 25% and 90%; each `Holder` rule and its priority; `CanNudge`; `Wiped`; the button cooldown and cap; `Migrate` (keeps and drops); the v4 defaults. Plus Roster (scan, roles, secret role, known states, coalescing, drink buff, solo, PvP zone, raid), Combat (timer delay, chain pull, drinking, wipe, dead, banner off, group scope), the drink button's hard rules, and every slash command.

### 6.4 Drink detection (`Drink.lua`)

- **Drinking** = a helpful aura matching `L.DRINK_AURAS` by name (`Drink`, `Food & Drink`, `Refreshment`) or a spell ID in `Drink.SPELL_IDS` (1135 so far). Readable out of combat for the player and party members (Q11).
- Unreadable aura data = unknown = treated as not drinking.
- Checked on `UNIT_AURA` for tracked healers, out of combat only, coalesced to once per healer per 0.5 s.

---

## 7. Combat and the after-fight moment (`Combat.lua`)

- **In combat** = the player is, or (`combatScope = "group"`, the default) any group member is. A secret read counts as in combat.
- Events: `PLAYER_REGEN_DISABLED` / `ENABLED`, and `UNIT_FLAGS` for group units (coalesced to 0.5 s). While the player is out of combat but someone else is still fighting, re-check every second. No always-on OnUpdate.
- **Combat starts:** cancel any pending banner; everything hides.
- **Combat ends:** indicators come back at once. Start `C_Timer.NewTimer(banner.delay)` if the banner is on.
- **The timer fires:** `Combat.Nudge` collects every healer passing `Levels.CanNudge` and hands the list to `Banner.Show`. A healer above level 1 is invisible on the banner (the game hides them), so the addon doesn't need to know who is low.
- **Wipe:** if at least half the group (minimum 2) is dead when combat ends, no banner this time.

---

## 8. The indicators

Each has `enabled` and lives in its own settings group. All follow `Levels.Holder` for known states.

### 8.1 Mana bar color (`Frames.lua`, `settings.bar`, on by default)

- Our own `StatusBar` (0–1) sits exactly over the healer's own power bar on their unit frame. Fill = `Curves.Fraction`, color = the color curve, fill alpha = `low`. So above level 1 it's invisible and the real bar shows; below, the bar reads yellow, orange, then red.
- The power bar is found by reading `target.powerBar` / `PowerBar` / `manabar` / `ManaBar` (Q25). Read-only: nothing is set on it. If none is showing, a 6 px strip along the frame's bottom is used.
- Option: opacity (40–100%).

### 8.2 Pips (`Frames.lua`, `settings.pips`, on by default)

- Three small squares in a corner of the healer's frame, each on a dark backing. Pip `i` has level `i`'s color and alpha from `pip<i>`: one lit below level 1, two below level 2, three below level 3. Countable, so it doesn't depend on judging a color.
- Options: size (small / medium / large), corner.

**Both on-frame indicators:**
- One **holder** per healer: our own plain frame, parented to `UIParent`, `SetAllPoints` on the unit frame, **created and anchored out of combat only**. In combat only alpha changes on our own frames.
- Frames supported: compact party (`CompactPartyFrameMember1..5`, confirmed Q8), compact raid, classic party, and the player frame as a last resort. Found by matching `frame.displayedUnit` / `frame.unit`.
- Post-hooks (`HookScript` OnShow/OnHide) on the unit frame keep the holder in step. Never replace or set anything on a Blizzard frame.
- No frame found → these two indicators don't show for that healer. The other three still do.
- A drinking healer also gets a small drink mark on the frame.

### 8.3 Draining flask (`UI/Flask.lua`, `settings.flask`, on by default)

- One flask per healer in a row, anywhere on screen. Works with party frames hidden. It is a stand-in for a mana bar: by default it **always shows** (out of combat), full or not.
- Built from a game potion icon: a dark, colorless copy behind (the empty flask); the same icon in color as a **vertical `StatusBar`** filled by `Curves.Fraction`, so the liquid drains (Q26); a 2 px edge that is the healer's **class color** while they are fine and the level colors below level 1 (`Curves.ClassColor`: the color curve with the class color as its "fine" end, one cached per class).
- The healer's name underneath, class-colored.
- With `flask.whenLow` on, it goes back to hiding while mana is fine: every texture's alpha comes from the fade curve and the name's from `low` (Q27; the name is dropped if the client refuses).
- **Several healers:** `flask.layout` lines them up in a **row** (default) or a **column**. `flask.together` (default on) places them as one stack; off, each flask is dragged to its own spot, saved per slot (first healer, second healer...) in `flask.points`. While placing, three stand-ins show so the layout can be seen.
- Options: only when low, opacity (20–100%), size, show names, row or column, stack or one by one. Placed in the on-screen preview (Section 9.2) or with `/sot move`.

### 8.4 After-fight banner (`UI/Banner.lua`, `settings.banner`, on by default)

- Once per fight (Section 7), near the top of the screen: one line per healer with the drink icon, their name and a colored underline. Color from the color curve; visibility from `low`. Hides after `banner.hold` seconds or when combat starts.
- **Wording:** `<First Surname>'s mana is at x%` (Q29). The number is never known to the addon: `Curves.Percent` gets the secret 0–100 value and hands it straight to `SetFormattedText`, so the game prints it (Q28). It is the number as of the moment the banner appears; it doesn't tick. If the client refuses, the line is just the name.
- If the client won't color or fade text from hidden values (Q27), the name is dropped and the icon and underline still show.
- Our own frame. Up to 8 lines.
- Options: delay (3 / 5 / 8 / 10 s), hold (3–8 s), size. Placed like the flask.
- **Placing** (`/sot move`, or the on-screen preview, Section 9.2) shows a sample with a purple plate to drag. It ends with `/sot lock`, or when the on-screen preview or the Options window closes. An indicator that is switched off shows nothing, placing or not.

### 8.5 Screen-edge glow (`UI/Vignette.lua`, `settings.vignette`, **off** by default)

- Four soft strips along the screen edges (the `glow-edge-*.tga` art, stretched), strata BACKGROUND. One layer per healer, up to 4; each colored by the color curve and faded by the fade curve, so the thirstiest shows through without any comparison.
- Layer alpha = known alpha × `vignette.strength`.
- `vignette.custom` swaps the level colors for one color of the player's own (`vignette.color`, from the color picker); the fade still comes from mana.
- Options: strength (10–100%), width (thin / medium / wide), use my own color + the color.

### 8.6 The drink button (`Button.lua`, `settings.button`)

The only thing that ever posts to chat, and only on a click.

- A small button with the drink icon; drag it any time. Shown when my role is Healer and I'm grouped (`show = "healer"`; also `"always"` / `"never"`). Its border takes my own mana color.
- **Left-click:** `{name} needs a drink - hold the pull`. **Right-click:** `{name} is good to go`. Both editable; tokens `{name}`, `{class}`. Tag `[Thirsty]` (`button.prefix`).
- **Channel** by group type: `INSTANCE_CHAT`, else `RAID`, else `PARTY`. Three checks (`party`, `raid`, `instance`) say where a click may post.
- **Hard rules:** `Levels.ButtonAllowed`; never in combat; never in battlegrounds or arenas. A refused click prints why, locally.
- **Keys:** `/sot macro` makes "SoT Drink" and "SoT Ready" macros (out of combat, if missing) and puts the first on the cursor. `Bindings.xml` adds both under Key Bindings > AddOns.

### 8.7 What's gone

v2's frame looks (tint, glow, border, corners, bar strip), the pulse, the nudge brighten, ready tick, range fade, grey edge, the thirst meter, the Ready level, color-band modes and feel presets. v1's automatic chat lines, sounds, banner-by-threshold, poster election and addon messages.

---

## 9. Look and assets

### 9.1 Colors

- Every color is a swatch that opens the game's `ColorPickerFrame`, with a **Reset** button beside it: the three level colors and the screen glow's own color.
- **Color presets** fill all three: Classic (yellow / orange / red), Water (light blue / blue / violet), Color-blind safe (yellow / orange / magenta). Picking a color by hand switches the preset to Custom.

### 9.2 Preview

Previews happen on the real indicators, not on a stand-in inside the window. Samples use plain numbers and rest at 25% mana, so everything shows.

- Opening the Flask, Banner or Screen glow tab shows that indicator's sample, so each can be tuned without a group.
- **Play** (`/sot test`) goes on screen (below) and runs all five from 100% down to 0%, through a drink, and back to the resting sample. Nothing is posted.
- **Preview on screen** (bottom right of the window, and "Preview and place on screen" on the Flask and Banner tabs) tucks the Options window away and shows every switched-on indicator where it really sits: three stand-in flasks, the banner, the screen glow, and the bar and pips on the real frames of the healers in the group, or on the player's own frame when there are none (`Frames.Demo`, plain numbers only). The flask, banner and drink button get their purple plates for dragging. A small draggable bar stays up with two buttons: **Play** and **Back to Options**. Unsaved changes ride along both ways. `/sot` also brings the window back. It won't start in combat, and a fight ends it like closing the window (nothing of ours shows in combat).

### 9.3 Blizzard assets first

Build from the game's own assets wherever one exists; ship art only when the game has none.

- **Templates:** `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `UIPanelCloseButton`, `InputBoxTemplate`, `BackdropTemplate`, `CooldownFrameTemplate`, `MenuUtil`, `GameTooltip`. Steppers ([-] value [+]) instead of sliders, so no slider template is needed.
- **Icons:** `INV_Drink_07` (drink button, drinking mark, banner), `INV_Potion_76` (flask). `Interface\TargetingFrame\UI-StatusBar` for bars.
- **Windows:** dialog border, tiling rock background tinted violet, the game's fonts.
- **What we ship:** `logo.tga` / `logo-128.tga`, `minimap.tga` (the first icon), `ghost.tga`, and the three `glow-*.tga` pieces.
- **Window art:** `ghost.tga` is the public icon (`art/SoThirstyIconPublic.jpeg`) in plain black and white, 512 px. It fills the whole content panel of every SoThirsty window, cropped not squashed. Strength is `settings.ghost` (default **35%**, 0 = off).
- **Palette** (from the icon): violet haze `#4F2365`, plum-slate stone `#2F1E22`, violet glow `#9E4DFF`, candle gold `#FACC5C` (titles), brass `#BF8C33` (edges), leather `#A5603A` (markers), warm white `#F2EBE0` (text), water blue `#4FC3F7` (chat prefix, "fine" mana).

---

## 10. Where it runs

`settings.zones`: dungeons **on**, raids **on**, open world and everything else **on**. Battlegrounds and arenas are **always off** and not a setting. Every indicator and the drink button follow this.

---

## 11. Who sees what

- **The five indicators:** only on the screen of a player who has the addon; each viewer's own settings decide their look.
- **The chat line:** everyone in the group, when someone with the addon clicks the drink button.
- A tank with party frames hidden still gets the flask, banner and screen glow.
- No addon messages, nothing agreed between clients.

---

## 12. Settings, options, commands

### 12.1 `SoThirstyDB` (version 4)

```lua
settings = {
  enabled = true,
  levels = {
    { pct = 50, color = { 1, 0.82, 0, 1 } },
    { pct = 30, color = { 1, 0.5, 0, 1 } },
    { pct = 10, color = { 1, 0.125, 0.125, 1 } },
  },
  palette = "classic",            -- "classic" | "water" | "colorblind" | "custom"
  bar = { enabled = true, alpha = 100 },
  pips = { enabled = true, size = "medium", corner = "TOPRIGHT" },
  flask = { enabled = true, scale = 100, names = true, alpha = 100, whenLow = false,
            layout = "row", together = true },                    -- + point / points once dragged
  banner = { enabled = true, delay = 5, hold = 5, scale = 100 },  -- + point once dragged
  vignette = { enabled = false, strength = 35, width = "medium", custom = false, color = { 0.31, 0.76, 0.97, 1 } },
  button = { show = "healer", party = true, raid = true, instance = true, prefix = true },
  zones = { dungeon = true, raid = true, world = true },
  combatScope = "group",          -- "group" | "me"
  roleHint = true,
  minimap = { hide = false, angle = 215 },
  ghost = 35,
  debugEvents = false,
}
```

Older databases (v1–v3) go through `Levels.Migrate`: it keeps on/off, the levels and colors, the palette, the drink button, zones, combat scope, role hint and the minimap button, and drops everything else.

### 12.2 Options window (`UI/Options.lua`)

**Big and sparse, so the art shows:** 900 × 660. A short list of tabs down the left; one short column of controls per tab; **Play** and **Preview on screen** in the bottom right (Section 9.2); the rest of the panel left open.

| Tab | Options |
|---|---|
| **General** (first) | On/off; the three zones; counts as "in combat"; role hint; minimap button; window art strength; Reset all; Debug info |
| **Levels** | The three levels (threshold + color each); color preset |
| **Mana bar** | Show this; opacity |
| **Pips** | Show this; size; corner |
| **Flask** | Show this; hide while mana is fine; opacity; size; show names; row or column; stack or one by one; preview and place on screen |
| **Banner** | Show this; how long after the fight; how long it stays; size; preview and place on screen |
| **Screen glow** | Show this; strength; width; use my own color; the color |
| **Drink button** | Show the button; party / raid / instance; `[Thirsty]` tag; the two lines; make macros |

- **Save / Undo changes.** A change shows at once, on the preview and for real, so it can be judged. It only sticks on **Save**. **Undo changes** returns to the last save. Closing with unsaved changes undoes them and says so in chat. Where things were dragged to always sticks. Slash commands apply at once.
- Also reachable from Esc > Options > AddOns.

### 12.3 Slash commands (`/thirsty`, `/sot`)

| Command | Does |
|---|---|
| `/sot` | Opens options |
| `/sot on` / `off` | Master toggle |
| `/sot levels 50 30 10` | Sets the three levels |
| `/sot bar` / `pips` / `flask` / `banner` / `glow` | Switches one indicator on or off |
| `/sot drink` / `ready` | Same as clicking the button |
| `/sot macro` | Makes the two macros |
| `/sot move` / `lock` | Shows the flask, banner and button for placing |
| `/sot test` | Plays the preview |
| `/sot ghost 35` | Window art strength |
| `/sot minimap` | Shows / hides the minimap button |
| `/sot status` | Tracked healers and their known states |
| `/sot debug` | Client, group, zone, combat, indicators on, per-unit role and state |
| `/sot debug looks` | Checks the indicators on every group member (Q25–Q27) |
| `/sot debug frames` / `drink` / `icons` / `events` | Unit frames found; drink buffs; game art; live event print |
| `/sot help` | Command list |

**Minimap button** (`UI/Minimap.lua`, no library): left-click opens Options, right-click opens a menu of every command, drag moves it. The addon compartment entry does the same.

---

## 13. Lightweight budget & code rules

- `UNIT_POWER_UPDATE` (mana only) and `UNIT_AURA`, for tracked healers only, coalesced to one refresh per healer per **0.5 s**. Unregistered when solo, in a disabled zone, or with no healer.
- Curves are rebuilt only when a level or color changes.
- No `OnUpdate`, with one exception: the minimap button while it is being dragged. Timers use `C_Timer`.
- No motion in v3: nothing pulses or animates. If motion returns, it must not use an Alpha/Scale `AnimationGroup` over mana-driven textures (Section 2).
- **Secrets:** never compare, branch on or do math with one. Test only the `ok` flag `Curves` returns. Pass secrets only to `SetAlpha`, `SetVertexColor`, `SetTextColor`, `SetValue`, and (the banner's percent) `SetFormattedText`.
- Every unproven setter is called through `pcall`, with a plain fallback, so a refusal degrades instead of erroring.
- All player-facing text in `Locales/enUS.lua`. `.luacheckrc` lists every WoW API used.
- Free, unobfuscated, ad-free (Blizzard UI Add-On Development Policy).

---

## 14. `CLAUDE.md`

The repo's `CLAUDE.md` carries the hard rules from this spec and the working rules (commits, PRs, tests). Keep it in step with this file.

---

## 15. Build status

| Step | Scope | State |
|---|---|---|
| 1. Skeleton | Repo, TOCs, Core, Locales, Debug, Window helper, CI | Done, checked in game |
| 2. Roster + probes | Healer tracking, drink buffs, the probes behind Q1–Q24 | Done, checked in game |
| 3. Drink button | Button, lines, caps, macros, key bindings | Built; button and caps checked in game; macros and bindings not yet |
| 4. Five indicators | Mana bar color, pips, flask, banner, screen glow; slim settings and options | Built; **not yet checked in game** (`/sot debug looks`, Q25–Q27) |
| 5. Release | README, CurseForge description and project ID, `v1.0.0` tag | To do |

---

## 16. Open questions: verify on Forever before relying on them

Answer each with a `/sot debug` subcommand in game. Record the answers here.

1. Does `UnitGroupRolesAssigned` return roles for **non-LFG** groups on Forever after a right-click **Set Role**? Does `PLAYER_ROLES_ASSIGNED` / `ROLE_CHANGED_INFORM` fire?
2. Is `UnitPower(partyN, Mana)` a **secret value** out of combat? In combat? (This decides whether `"freeze"` mode is even meaningful, and how much we lean on MANA reports.)
3. Does a party member's mana update when they're out of range or in another zone?
4. Does `UnitPower(unit, Enum.PowerType.Mana)` return real mana for a druid in a form?
5. Is `UnitAffectingCombat(partyN)` readable or secret? Does `UNIT_FLAGS` fire on combat changes for group units?
6. Can addon code call `SendChatMessage(msg, "PARTY" | "RAID" | "INSTANCE_CHAT")` without a hardware event on Forever, out of combat and inside instances?
7. Does Forever have LFG instance groups (`LE_PARTY_CATEGORY_INSTANCE` / `INSTANCE_CHAT`)?
8. What are the actual compact party/raid frame names and their `unit` fields on Forever's client? Do the classic `PartyFrame` member frames exist?
9. Does `C_ChatInfo.SendAddonMessage` to PARTY/RAID work out of combat inside a dungeon?
10. Which `SOUNDKIT` entries exist for the L3 / tank sound? Does `PlaySound(kit, channel)` honor the channel argument? (Reuse the `/bl debug sounds` approach.)
11. Are **other players' auras** readable out of combat (`C_UnitAuras.GetAuraDataByIndex`)? Are names, spell IDs or both secret? What are the drink aura names/IDs on Forever?
12. How fast does a healer's mana regen out of combat **without** drinking, over 10 s? This sets the `drinkRise` default so normal regen isn't mistaken for drinking.
13. Do `CHAT_MSG_PARTY` / `RAID` / `INSTANCE_CHAT` events give the sender GUID (arg 12) on Forever, so chat-listen can ignore our own lines?
14. Do `ColorPickerFrame:SetupColorPickerAndShow` and `AnimationGroup` alpha/scale animations work as on retail?
15. Does `PlaySoundFile` play `.ogg` files from `Interface\AddOns\SoThirsty\Media\Custom\` (after a client restart)?
16. Do the game textures in 9.7 exist on Forever (`UI-Background-Rock`, `UI-DialogBox-Background-Dark`, the drink icons, the slider templates)? A missing file shows as a blank or green square. If one is missing, swap in the `art/fallback/` version.
17. **Blocker.** With `UnitPower` secret, is there any official, readable mana source (`UnitPowerPercent`, a `C_Secrets` predicate, a different argument)? Can a `StatusBar` take a secret mana value? Test with `/sot debug mana`. If nothing is readable, mana thresholds and chat lines can't work as designed, and the design has to change. Don't work around a secret (e.g. measuring bar texture widths): that defeats a deliberate Blizzard restriction.

18. Can a `C_CurveUtil` curve turn the secret mana percent into an alpha or a color that our own textures accept (`UnitPowerPercent(unit, Mana, false, curve)`, `SetAlpha`, `SetVertexColor`)? Is the percent on a 0–1 or 0–100 scale? Test with `/sot debug curve`. This is the only way left to show mana levels (see Q17 answer).
19. What scale does `UnitPowerPercent` feed a curve (0–1 or 0–100)? Does a curve-driven color/fade update live on `UNIT_POWER_UPDATE`? Test with `/sot debug swatch` while spending mana.

Open for design v2 (all tested by `/sot debug party`):

20. Do curves work on a **party member's** mana, not just the player's? Does `UNIT_POWER_UPDATE` fire for them?
21. Does `SetAlphaFromBoolean(UnitInRange(unit), 1, 0.4)` take the secret range flag? Which event refreshes it?
22. Does a looping alpha `AnimationGroup` on a parent frame combine with a secret `SetAlpha` on a child texture (the pulse layer)?
23. Does `StatusBar:SetValue(UnitPowerPercent(unit, Mana))` fill correctly on a 0–1 range (the thirst meter)?
24. Does `StatusBar:SetStatusBarColor` or its texture's `SetVertexColor` take secret color parts?

Open for design v3 (tested by `/sot debug looks`):

25. Is the unit frame's own power bar reachable (`powerBar` / `PowerBar` / `manabar` / `ManaBar`), showing, and the size we expect? The mana bar color sits on it.
26. Does a **vertical** `StatusBar` using an icon as its fill texture take the secret mana fraction, and is the icon cropped (not squashed) as it drains? The flask depends on it.
27. Do `FontString:SetTextColor` and `FontString:SetAlpha` take secret values? The banner and the flask names depend on it.
28. Does `UnitPowerPercent(unit, Mana, false, CurveConstants.ScaleTo100)` return a (secret) 0–100 number, and does `FontString:SetFormattedText("%s's mana is at %.0f%%", name, secret)` print it? The banner's wording depends on it. `/sot debug looks` checks both. If not, the banner line is just the name.
29. **Surnames: yes** (verified for Bounty Line, 2026-11-21). `UnitName(unit)` returns the first name and the surname ("Slac", "Jaw"); the surname sits where retail has the realm. The banner shows "First Surname"; the flask keeps the first name, to fit.

Questions 3, 4, 6 and 16 still matter. Questions 9, 10, 12, 13 and 15 belonged to the v1 design (addon messages, sounds, mana-rise, chat-listen), and 21 to v2's range fade; they no longer apply.

### Answers so far

From `/sot debug`, client 1.60.1 build 71091 (16001), open world, out of combat, party of 2, no roles set:

- **Q2:** `UnitPower(unit, Mana)` is **secret out of combat**, for party members **and for the player**. `UnitPower(unit)` is secret too. `UnitPowerMax` was readable for the player and secret for the party member. `UnitPowerType` is readable. Leads to Q17.
- **Q5 (part):** `UnitAffectingCombat` is readable for party members out of combat.
- **Q7 (part):** `LE_PARTY_CATEGORY_INSTANCE` exists (= 2).
- `UnitGroupRolesAssigned`, `UnitGUID`, `UnitClass`, `UnitIsDeadOrGhost` and `UnitIsConnected` are readable. `UnitInRange` is secret.
- **Q1:** yes. Right-click **Set Role** to Healer in a normal open-world party, and `UnitGroupRolesAssigned` returns `HEALER` at once.
- Mana is also secret in combat (as expected).

From `/sot debug mana`, same client, open world, out of combat:

- **Q17: no readable mana source exists.** `UnitPower` (every argument form) and `UnitPowerPercent` are secret for the player and for party members. `C_Secrets.ShouldUnitPowerBeSecret` returns `true` for both, and `C_Secrets.GetPowerTypeSecrecy(Mana)` returns `2`. This is policy, not a bug: the addon can never know a healer's mana number. Comparisons against levels, chat lines, sounds and the state machine in 6.2 can't run on real mana.
- `UnitPowerMax` is readable for the player only (`ShouldUnitPowerMaxBeSecret` false); secret for party members. `UnitHealth` is secret too.
- A `StatusBar` accepts a secret mana value (`GetValue` stays secret). Present: `C_CurveUtil`, `CurveConstants`, `C_Secrets`, `C_RestrictedActions`, `canaccesssecrets`, `hasanysecretvalues`, `issecrettable`, `scrubsecretvalues`, `secretwrap`, `dropsecretaccess`. Leads to Q18.

From `/sot debug curve`, same client, out of combat:

- **Q18: yes, the visual path works.** `C_CurveUtil` has `CreateCurve`, `CreateColorCurve`, `EvaluateColorFromBoolean`, `EvaluateColorValueFromBoolean`, `EvaluateGameCurve`. `Enum.LuaCurveType`: Linear 0, Step 1, Cosine 2, Cubic 3. `CurveConstants`: ZeroToOne, ScaleTo100, Reverse, ReverseTo100.
  - `curve:Evaluate(secret)` is **blocked** for addon code ("only allowed during untainted execution"). Pass the curve to the API instead.
  - `UnitPowerPercent(unit, Mana, false, curve)` returns a secret number; `Texture:SetAlpha` accepts it.
  - `UnitPowerPercent(unit, Mana, false, colorCurve)` returns a color object whose `GetRGB()` is secret; `Texture:SetVertexColor` accepts it.
  - Textures also have `SetAlphaFromBoolean` and `SetVertexColorFromBoolean`.
  - Scale: see Q19.

From `/sot debug swatch` (player, spending mana from 100% to 4%):

- **Q19: the curve input is 0–1** (0.5 = half mana). The color square went green (100%), amber (42%), orange-red (14%), red (4%); the fade square, stepped at 0.9, appeared below 90%. Both update live on `UNIT_POWER_UPDATE` for the player. Party members still to confirm in a group.

From `/sot debug party`, `/sot debug frames` and `/sot debug drink` (design v2 build, party of 3, open world, out of combat, Blizzard raid-style party frames):

- **Q20: yes.** The color and strength curves work on party members' mana, and `SetVertexColor` / `SetAlpha` accept the results, for the player and both party members.
- **Q21: yes.** `UnitInRange` is secret, and both `Texture:SetAlphaFromBoolean` and `Frame:SetAlphaFromBoolean` accept it. The refresh event is still to confirm.
- **Q23: yes.** `UnitPowerPercent(unit, Mana, false, CurveConstants.ZeroToOne)` works and `StatusBar:SetValue` accepts it; the thirst meter fills correctly.
- **Q24: yes.** `StatusBar:SetStatusBarColor` and its texture's `SetVertexColor` both take secret color parts.
- **Q8:** with raid-style party frames on, the frames are `CompactPartyFrameMember1..N`, the player included. Classic party frames still to check.
- **Q11:** aura names and spell IDs are readable out of combat, for the player and for party members (their scans returned a clean `false`, not hidden). The drink buff is **"Drink", spell 1135** (Moonberry Juice).
- **Q6:** `SendChatMessage` to PARTY works from a button click, out of combat, in the open world. Instances still to check.
- **Q22: no.** An Alpha `AnimationGroup` on a parent frame overrides its child textures' alpha (the nudge lit the glow at full mana, and the pulse edge showed above level 3). Motion now uses a shared timer and plain `SetAlpha` on our own frames (8.1).
- Found in the same test: the glow art is drawn to grow inward, so an outward glow made its corner pieces cross. The glow now sits just inside the frame edge.

---

## 17. Out of scope (v1) and ideas parking lot

**Out of scope for v1:**

- Any Discord, web or network features.
- Tracking non-healer mana (DPS casters).
- Whisper alerts to the tank.
- Third-party unit frames (ElvUI, Cell, Grid2, VuhDo). List them as "Planned".
- Translations beyond enUS. The locale table is ready for them.

**Ideas for v1.1+ (not promises):**

- **Chat-line reaction:** when another player's `[Thirsty]` drink line appears in group chat, addon users get a small local banner or sound. This is the one automatic alert that's still possible, because it reacts to a person's click, not to mana.
- A percent badge on the frame, if the game allows formatting a secret number into our own text.
- Per-character profiles, and settings import/export strings.
- Third-party frame support (ElvUI, Cell, Grid2, VuhDo).
- Optional "tank whisper" mode for the drink button.
