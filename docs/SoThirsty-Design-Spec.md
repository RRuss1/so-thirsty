# SoThirsty — Design Spec & Build Brief

> **For Claude Code (VS Code):** This is the source of truth for the SoThirsty addon. Read all of it before you write any code. Build in the phases in Section 15, and finish and test each phase before you start the next. If something in this spec is unclear, or a Forever API behaves differently than described here, **ask Rich or add the question to Section 16. Don't guess.**
>
> The house style comes from `C:\Users\goret\Desktop\DEV\bounty-line`. Mirror its patterns (Section 3).
>
> **Design v2.** The first design read healers' mana and posted chat warnings. In-game tests (Section 16, Q17–Q19) showed that Forever **always hides mana from addons**, so that design can't exist. This version shows mana **visually**, through the game's own curve functions, and adds a manual "I need a drink" button for chat.

---

## 1. What it is

**SoThirsty** is a lightweight in-game addon for **WoW: Forever**. It shows when a **healer's mana is low**, so the tank waits for the healer to drink before the next pull.

- It puts a **colored glow on the healer's party/raid frame**. The glow appears when the healer's mana drops below a level you choose, and changes color and strength as mana falls, in **10% bands**.
- It's **silent and automatic**. Nothing is ever posted to chat or played as a sound on its own.
- It works **out of combat**. The glow is hidden during fights, and gives one short **nudge** 5 seconds after a fight ends.
- A healer who is **drinking** shows a dimmed glow and a water drop, so everyone can see it's handled.
- A manual **"I need a drink" button** posts one line to group chat when a person clicks it. That is the only way SoThirsty ever speaks.
- It watches every group member whose **assigned role is Healer** (the game's Set Role / role check).
- **Each player who wants the glow needs the addon.** The glow is drawn on your own screen. Players without the addon only see the chat line, if the healer clicks the button.
- It is **in-game only**. No Discord, no Worker, no relay, no network requests, no addon-to-addon messages.

**Name and branding**

- Display name: **So Thirsty**
- Folder and internal name: `SoThirsty`
- Slash commands: `/thirsty` and `/sot`
- Chat prefix color: water blue `|cff4fc3f7`

### 1.1 The quiet contract: informative, never annoying

These rules beat every other setting. If a feature would break one of them, the rule wins.

1. **Silent by default.** SoThirsty never posts to chat and never plays a sound on its own.
2. **Out of combat.** The glow is hidden in combat (or very faint, if the player chooses). Nothing new appears mid-fight.
3. **One nudge per fight.** `nudgeDelay` (default **5 s**) after the group leaves combat, the glow brightens for a few seconds, then settles. If combat restarts first, the nudge is cancelled. No nudge after a wipe.
4. **Drinking means dim.** A healer who is drinking gets a dimmed glow and no nudge.
5. **Chat only when a person clicks.** The drink button posts **one line per click**, with a 15 s cooldown and a hard cap of **3 lines per 5 minutes**. Never in combat, never in battlegrounds or arenas, never to SAY, YELL or RAID_WARNING.
6. **No raid warnings.** Never `RaidWarningFrame` / `RaidNotice_AddMessage`.
7. **Never work around a secret.** The addon never tries to recover a hidden number (no reading text back, no measuring bars, no pixel tricks). It only hands secret values to the game functions built to take them.

---

## 2. Target client

- **WoW: Forever, Interface `16001`.** Ship **both** `SoThirsty_Forever.toc` and `SoThirsty.toc` with the same contents.
- **The client is a modern Midnight-based client with restrictions:**
  - **Secret values.** Mana, health and range are **always secret** on Forever, in and out of combat, even for the player's own character (Section 16, Q17). Check with `issecretvalue` through `ns.IsSecret`. Never compare, test or do math on a secret value.
  - **Curves are the sanctioned path.** Build a curve with `C_CurveUtil`, pass it to `UnitPowerPercent(unit, Enum.PowerType.Mana, false, curve)`, and give the (secret) result to `SetAlpha` / `SetVertexColor` on our own textures. The curve input is **0–1**. `curve:Evaluate(secret)` is blocked for addon code; the game must do the evaluating (Q18, Q19).
  - `COMBAT_LOG_EVENT_UNFILTERED` is forbidden. SoThirsty doesn't need it.
  - No realms. Key players by **GUID**, not by name.
- It is Lua 5.1. CI tests on both `lua5.1` and `luajit`.

---

## 3. Repo layout (mirror bounty-line, addon-only)

```
so-thirsty/
├── CLAUDE.md, README.md, CHANGELOG.md, CONTRIBUTING.md, PRIVACY.md, SECURITY.md, LICENSE
├── .gitignore, .luacheckrc, .pkgmeta
├── .github/ (issue templates, workflows/ci.yml, workflows/addon-release.yml)
├── art/                          # icon sources, fallback backgrounds (not packaged)
├── docs/
│   ├── SoThirsty-Design-Spec.md  # THIS FILE
│   └── curseforge-description.md
└── addon/
    ├── SoThirsty/
    │   ├── SoThirsty_Forever.toc, SoThirsty.toc
    │   ├── Locales/enUS.lua      # ALL player-facing text, plus drink aura names
    │   ├── Core.lua              # SavedVariables, defaults, slash commands, startup
    │   ├── Levels.lua            # PURE logic: curve points, visibility decisions, button caps (no WoW API)
    │   ├── Roster.lua            # who's in the group, who's a healer, dead/offline
    │   ├── Drink.lua             # drink aura check
    │   ├── Combat.lua            # group combat state, the nudge timer, wipe detection
    │   ├── Curves.lua            # builds C_CurveUtil curves from Levels' points; applies them to textures
    │   ├── Theme.lua             # color presets, style tables, icon list (data only)
    │   ├── Frames.lua            # the glow on party/raid frames
    │   ├── Button.lua            # the "I need a drink" button and its chat line
    │   ├── Debug.lua             # /sot debug ...
    │   ├── UI/Window.lua         # window helper (ns.CreateWindow, ns.Text)
    │   ├── UI/Meter.lua          # optional thirst meter panel
    │   ├── UI/Options.lua        # settings window + Esc > Options > AddOns entry
    │   └── Media/                # only what the game doesn't have (Section 9.7)
    │       ├── logo.tga, logo-128.tga, ghost.tga, glow-*.tga
    └── tests/
        └── logic.lua             # stubbed-API tests for Levels, Roster, slash commands
```

**Copy from bounty-line:** the `local addonName, ns = ...` namespace pattern, `ns.L` locales, `ns.Print`, `applyDefaults`, the slash command table, the `ADDON_LOADED` startup, the Settings entry, the options row tables, the debug `line()`/`show()` helpers, luacheck and CI setup, the packager workflow, and the addon compartment functions.

**Libraries:** none. Plain Blizzard API only.

---

## 4. TOC

```
## Interface: 16001
## Title: So Thirsty
## Notes: Shows when your healer is low on mana, out of combat, so the tank waits before pulling.
## Author: Slac Jaw from RP-PVP
## Version: @project-version@
## X-Curse-Project-ID: TODO   (Rich creates the CurseForge project, then fills this in)
## SavedVariables: SoThirstyDB
## IconTexture: Interface\AddOns\SoThirsty\Media\logo
## AddonCompartmentFunc: SoThirsty_OnAddonCompartmentClick
## AddonCompartmentFuncOnEnter: SoThirsty_OnAddonCompartmentEnter
## AddonCompartmentFuncOnLeave: SoThirsty_OnAddonCompartmentLeave

Locales\enUS.lua
Core.lua
Theme.lua
Levels.lua
Roster.lua
Drink.lua
Combat.lua
Curves.lua
Frames.lua
Button.lua
Debug.lua
UI\Window.lua
UI\Meter.lua
UI\Options.lua
```

Files are added to the TOC in the phase that creates them. Settings are account-wide (`SoThirstyDB`).

---

## 5. Healer detection: tie into "Set Role"

- A unit is tracked only when **`UnitGroupRolesAssigned(unit) == "HEALER"`**. Confirmed working for a right-click Set Role in a normal party (Q1).
- The **local player doesn't have to be the healer.** Every addon user sees a glow for every healer in the group.
- Re-scan on `GROUP_ROSTER_UPDATE`, `PLAYER_ROLES_ASSIGNED`, `ROLE_CHANGED_INFORM`, `PLAYER_ENTERING_WORLD`, and on `ADDON_LOADED` if already grouped.
- Units: `raid1`–`raid40` in a raid; `player` plus `party1`–`party4` in a party; solo does nothing and unregisters its events.
- Store tracked healers by GUID: `{ unit, guid, name, class }`. Map GUID → current unit on each rescan.
- **Known states** the addon can read: role, dead or ghost (`UnitIsDeadOrGhost`), offline (`not UnitIsConnected`), group combat, drink buff (6.4, to confirm for other players).
- **Mana is never read as a number.** Mana is `Enum.PowerType.Mana`, always passed with that type so druids in forms still work.
- **No role assigned anywhere in the group:** print one once-per-group hint, only to the group leader, only inside an instance, if `settings.roleHint` is true.

---

## 6. Levels and bands

### 6.1 Defaults (customizable)

Three **levels** are color anchors. The glow starts at level 1 and gets redder and stronger toward level 3.

| Level | Default | Color (Classic preset) | Meaning |
|---|---|---|---|
| 1 "getting thirsty" | **50%** | Yellow `#FFD100` | Glow starts here, faint |
| 2 "thirsty" | **30%** | Orange `#FF8000` | |
| 3 "so thirsty" | **10%** | Red `#FF2020` | Full strength; the slow pulse shows below this |
| Ready | **90%** | Green `#40FF40` | The optional ready tick shows at or above this |

- **Thresholds move in steps of 10** (10–90). Typed values via `/sot levels` accept 1–99.
- **Bands:** the range from 0 to level 1 is cut into **10% bands**. Each band gets a color blended between the level colors on either side.
  - `look.bands = "smooth"` (default): the color slides continuously.
  - `look.bands = "steps"`: the color jumps at each 10% line, so each band is one flat color.
- Above level 1, nothing shows.
- Validation: thresholds must be **strictly descending** (L1 > L2 > L3) and Ready must be above L1. Reject a bad edit with a message; don't silently reorder.
- A level can't be "announced": the addon never knows which band a healer is in. Only the screen shows it.

### 6.2 Pure logic (`Levels.lua`, fully unit-tested)

No WoW API calls. Numbers, booleans and tables in; plain tables out. `Curves.lua` turns the point lists into real curves.

- **`Levels.Validate(levels, ready)`** → `true`, or `false` plus `"RANGE"` / `"ORDER"` / `"READY"`.
- **`Levels.ColorPoints(cfg)`** → `{ type = "linear" | "step", points = { { x, r, g, b }, ... } }` on the 0–1 scale.
  - Smooth: points at 0 (L3 color), L3, L2 and L1 thresholds with their colors.
  - Steps: one point per 10% band from 0 up to L1, each with the blended color for that band's middle.
- **`Levels.AlphaPoints(cfg)`** → the strength curve.
  - `look.strength = true` (default): linear from `look.alpha` at the L3 threshold and below, down to `look.faint` (default 35% of `look.alpha`) just under L1, then **0 at L1 and above** (a hard step off at L1).
  - `look.strength = false`: `look.alpha` below L1, 0 at and above.
- **`Levels.PulsePoints(cfg)`** → step curve: 1 below the L3 threshold, 0 at and above.
- **`Levels.ReadyPoints(cfg)`** → step curve: 0 below Ready, 1 at and above.
- **`Levels.Holder(known, cfg)`** → the known-state part of visibility for one healer. Returns three plain values: `alpha` (0–1), `grey`, `drinking`. `known = { enabled, zoneOk, inCombat, dead, offline, drinking }`.
  1. Addon off, or zone not allowed → alpha 0.
  2. Dead or offline → alpha 0, grey (a faint grey edge replaces the glow).
  3. In combat → alpha 0, or 0.15 when `look.combat = "faint"`.
  4. Drinking → alpha `look.drinkDim` (default 35%), drinking.
  5. Otherwise → alpha `look.rest` (default 70%): the resting brightness. The nudge lifts it to 100% for a moment.
- **`Levels.CanNudge(known, wiped)`** → true only when enabled, zone ok, out of combat, not dead/offline, not drinking and not wiped.
- **`Levels.ButtonAllowed(now, log, cfg)`** → `true`, or `false` plus `"COOLDOWN"` / `"CAP"`. `log` is the list of the player's recent send times. 15 s between lines; 3 lines per 300 s.

The final picture is **holder alpha (known) × texture alpha (secret, from the strength curve)**. The addon sets the first on a parent frame and the game applies the second on the texture, so the two never have to be multiplied in Lua.

### 6.3 Required tests (in `addon/tests/logic.lua`)

- `Validate`: 50/30/10 + 90 ok; 30/50/10 → ORDER; 0 or 100 → RANGE; Ready 40 with L1 50 → READY.
- `ColorPoints` smooth, defaults: x = 0, 0.1, 0.3, 0.5 with red, red, orange, yellow.
- `ColorPoints` steps, defaults: five points (0, 0.1, 0.2, 0.3, 0.4); the 0.2 band is a red/orange blend; every x is a multiple of 0.1.
- `ColorPoints` with L1 = 80: steps gives eight points.
- `AlphaPoints` with strength: full at and below L3, faint just under L1, 0 at L1; without strength: flat then 0.
- `PulsePoints` and `ReadyPoints` step at the right x for custom thresholds.
- `Holder`: each rule above, in priority order (dead beats drinking; combat beats drinking; off beats everything).
- `CanNudge`: false for drinking, wiped, combat, dead; true otherwise.
- `ButtonAllowed`: first click ok; second inside 15 s → COOLDOWN; fourth inside 5 min → CAP; allowed again once old entries age out.
- Roster and slash-command tests from Phase 2 stay.

### 6.4 Drink detection (`Drink.lua`)

- A healer is **drinking** when one of their helpful auras matches `L.DRINK_AURAS` by name (enUS: `Drink`, `Food & Drink`, `Refreshment`) or a spell ID in `Drink.SPELL_IDS`.
- If the aura data is secret or unreadable, the answer is **unknown**, treated as not drinking. The glow just stays at full.
- Checked on `UNIT_AURA` for tracked healer units, **out of combat only**, coalesced to one check per healer per 0.5 s.
- Mana-rise detection is gone: it needed the mana number.
- Whether another player's auras are readable out of combat is still open (Q11). If they aren't, the drinking dim only works for your own character, and the README says so.

---

## 7. Combat gate and the nudge (`Combat.lua`)

- **The group is "in combat"** if the player is (`InCombatLockdown()` / `UnitAffectingCombat("player")`) **or any group member is** (`UnitAffectingCombat(unit)`, readable out of combat per Q5). A secret read counts as in combat.
- Setting `combatScope`: `"group"` (default) or `"me"`.
- **Events:** `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, and `UNIT_FLAGS` for group units. If `UNIT_FLAGS` proves unreliable, fall back to a 0.5 s `C_Timer` ticker that runs only while the player is out of combat and some member was last seen in combat. Never an always-on OnUpdate.

**Combat starts:** cancel any pending nudge; holders go to their combat alpha (hidden, or faint).

**Combat ends:** holders return to normal at once (the glow is back, at its resting look). Then start `C_Timer.NewTimer(settings.nudgeDelay)` (default **5 s**; choices 3 / 5 / 8 / 10).

**The nudge** (when the timer fires, once per fight):

- For each healer where `Levels.CanNudge` is true, play the nudge animation on that healer's holder: brighten and swell slightly for `nudgeHold` (default 3 s), then ease back. `AnimationGroup` only.
- A healer above level 1 has a glow alpha of 0 from the curve, so their nudge is invisible. The addon doesn't need to know who is low.
- If `frames.readyTick` is on, the ready tick layer is shown for the same few seconds (visible only at or above Ready, by its curve).
- `settings.nudge = false` turns the nudge off; the steady glow stays.

**Wipe detection:** if, when combat ends, at least half the group (minimum 2) is dead or a ghost, set `wiped`. No nudge this time. The flag clears at the next combat start. (`settings.quietAfterWipe`, default on.)

---

## 8. Outputs

### 8.1 The frame glow (`Frames.lua`, `Curves.lua`)

For each tracked healer, one **holder**: our own plain, non-secure `Frame`, `SetAllPoints()` on the healer's unit frame. Layers inside it:

| Layer | Driven by | Shows |
|---|---|---|
| **Glow** | color curve + strength curve (secret) | the thirst color, stronger as mana falls |
| **Pulse** | pulse step curve (secret) + a looping alpha animation on its sub-frame | a slow pulse below level 3 only |
| **Ready tick** (option, off) | ready step curve (secret) | a small green mark at or above Ready, during the nudge |
| **Drop icon** | known: drinking | a water drop while drinking |
| **Grey edge** | known: dead / offline | a faint grey edge instead of the glow |
| **Range fade** (option, off) | `SetAlphaFromBoolean(UnitInRange(unit), 1, 0.4)` on the glow sub-frame | fades the glow when the healer is far away (Q21) |

- **Refresh:** on `UNIT_POWER_UPDATE` for a tracked healer (mana type only), re-apply the curves: `tex:SetVertexColor(color:GetRGB())`, `tex:SetAlpha(alpha)`. Coalesce to one refresh per healer per 0.5 s. Also refresh on roster changes and when combat ends.
- **Holder alpha** comes from `Levels.Holder` and is set on the holder frame. Never mix it with secret values in Lua.
- **Blizzard frames to support (v1):** compact party frames, compact raid frames, and the classic party frames (or Forever's equivalent; confirm with `/sot debug frames`, Q8).
- **Finding frames:** walk the known containers and match `frame.unit` / `frame.displayedUnit` against the healer's unit with `UnitIsUnit`. Re-map on roster updates. Never replace Blizzard functions.
- **Taint safety:**
  - Create and anchor holders **only out of combat**.
  - In combat, only change alpha or `Show`/`Hide` on our own frames.
  - Never touch a Blizzard frame's own properties.
- **Fallback:** no frame found for a healer → no glow for them. The thirst meter (8.3) still works. `/sot debug frames` reports what was found.
- **Third-party frames** (ElvUI, Cell, Grid2, VuhDo): out of scope for v1.

### 8.2 The drink button (`Button.lua`)

The only thing that ever posts to chat, and only on a click.

- A small button with the drink icon. Drag it any time to move it. Shown when **my role is Healer** and I'm in a group, out of combat (`button.show = "healer"`; also `"always"` / `"never"`). Also reachable with `/sot drink`, `/sot ready`, and the addon compartment menu.
- **Left-click:** posts the thirsty line. **Right-click:** posts the ready line.
- **Tint:** the button's border takes my own mana color from the same color curve, so it glows as I run dry.
- **Cooldown:** greyed for 15 s after a line, with the game's cooldown swipe. Greyed in combat.
- **Channel** by group type: `INSTANCE_CHAT` if `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)`, else `RAID` if `IsInRaid()`, else `PARTY`. Never `SAY`, `YELL` or `RAID_WARNING`. Three checks say where the button may post: **Party / Raid / Instance** (`button.party`, `button.raid`, `button.instance`, all on by default). If the current group type is unchecked, the click prints a local note and sends nothing.
- **Rules** (hard, from 1.1): `Levels.ButtonAllowed` (15 s, 3 per 5 min); never in combat; never in battlegrounds or arenas.
- **Lines** (editable; tokens `{name}`, `{class}`):
  - Thirsty: `{name} needs a drink - hold the pull`
  - Ready: `{name} is good to go`
- Prefix `[Thirsty]` (`button.prefix`, default on), so people know it came from an addon.
- No mana number in the line: the addon doesn't have one.
- **Keys:** `/sot macro` makes two ordinary macros (`/sot drink`, `/sot ready`) for action bar slots, out of combat, only if they do not exist yet. `Bindings.xml` also adds both lines under Key Bindings > AddOns. Either way the same rules and caps apply.

### 8.3 The thirst meter (`UI/Meter.lua`, option, off by default)

- A tiny panel you can drag any time: one row per healer, class-colored name and a mana bar.
- The bar is a `StatusBar` on a 0–1 range, fed `UnitPowerPercent(unit, Mana)` (secret; the bar accepts it). Its color comes from the color curve; above level 1 it's water blue.
- Tick marks every 10%, with the three level lines slightly brighter.
- Shown out of combat only, in the same zones as the glow. Drinking shows the drop icon next to the name.
- Drag it any time; the position is saved. `/sot move` shows the meter and the button even when they would be hidden, so they can be placed; `/sot lock` ends that.

### 8.4 What v2 doesn't have

Automatic chat lines, sounds, an on-screen banner, a poster election, and addon-to-addon messages are all gone. They needed the mana number. See Section 17 for what might come back.

---

## 9. Customization: colors, textures and feel

Everything here is local and silent. All lists of styles, palettes and icons live in `Theme.lua` as plain data tables.

### 9.1 Presets

One-click **feel presets** set the motion options (colors are left alone):

- **Calm**: glow only. No nudge, no pulse.
- **Normal** (default): glow, strength ramp, nudge, pulse below level 3, drinking dim.
- **Full**: Normal plus ready tick, range fade and the thirst meter.

### 9.2 Colors and frame look

**Color picker everywhere.** Every color is a swatch that opens the game's `ColorPickerFrame` (with opacity; Cancel restores the old color). Each swatch has a small **reset** arrow. That covers the three level colors, Ready and the grey edge.

**Color presets** (`look.palette`) fill the four level colors in one click. Picking a color by hand switches the palette to **Custom**.

| Preset | L1 | L2 | L3 | Ready |
|---|---|---|---|---|
| **Classic** (default) | `#FFD100` yellow | `#FF8000` orange | `#FF2020` red | `#40FF40` green |
| **Water** (on-brand) | `#9BE7FF` light blue | `#4FC3F7` blue | `#7B4FF7` violet | `#FFFFFF` white |
| **Color-blind safe** | `#F0E442` yellow | `#E69F00` orange | `#CC79A7` magenta | `#56B4E9` sky blue |
| **Custom** | whatever you picked | | | |

**Highlight style** (`look.style`):

- `"glow"` (default): a soft glow just inside the frame edge, using the `glow-*.tga` textures (they are drawn to grow inward).
- `"border"`: solid border, thickness 1–4 px (`look.thickness`, default 2).
- `"corners"`: four small corner brackets. The least intrusive option.
- `"tint"`: a translucent fill over the whole frame.
- `"bar"`: a colored strip over the frame's mana bar area only.

**Other look settings:**

- **Bands:** smooth (default) or steps (6.1).
- **Strength ramp** on/off (`look.strength`), top opacity 20–100% (`look.alpha`, default 80), faint end (`look.faint`), resting brightness (`look.rest`, default 70).
- **Drinking dim** 10–100% (`look.drinkDim`, default 35) and the drop icon on/off.
- **In combat:** hidden (default) or faint (`look.combat`).
- **Pulse:** off / below level 3 (default); speed slow / normal / fast.
- **Nudge:** on/off, delay 3 / 5 / 8 / 10 s, hold 2–5 s.
- **Ready tick**, **range fade**: on/off (both off by default).
- **Drop icon** (`look.icon`): a built-in game drink icon (default `INV_Drink_07`; list in `Theme.lua`, checked with `/sot debug icons`) or the SoThirsty logo.

### 9.3 Preview

- **`/sot test`** and the Options **Preview** button play a fake healer through the bands on a sample frame in the Options window: 100% → 0% → drinking → ready, about 8 seconds. It uses plain numbers, so it needs no group and posts nothing.
- A live **preview frame** on the Look tab shows the current look at a slider-chosen mana level.

### 9.4 Sound

None in v2. The addon can't know when a healer crosses a level, so there's no moment to play one.

### 9.5 Chat look

- Two editable lines (thirsty, ready) with token help and Reset.
- Prefix on/off; Party / Raid / Instance checks (8.2).
- A **preview line** in Options shows exactly what a click would send. Nothing is sent.

### 9.6 Feel and quality of life

- **Status tooltip:** hovering the compartment icon lists tracked healers and whether each is drinking, dead or offline. No mana numbers.
- **`/sot status`** prints the same.
- **Minimap button** (`UI/Minimap.lua`, adapted from Bounty Line, no library): left-click opens Options, right-click opens a menu of every `/sot` command (each entry shows its command in grey), drag moves it around the minimap. `/sot minimap` or the menu hides it. The addon compartment entry does the same clicks.

### 9.7 Blizzard assets first

Build the interface from the game's own assets wherever one exists. Ship art only when the game has no equivalent.

- **Templates:** `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `UIPanelCloseButton`, the game's slider template, `InputBoxTemplate`, `UIDropDownMenu` / `MenuUtil`, `BackdropTemplate`, `GameTooltip`, `CooldownFrameTemplate` for the button's cooldown.
- **Color picker:** the game's `ColorPickerFrame`, never a homemade one.
- **Borders and backgrounds:** the dialog border, the tiling rock (`Interface\FrameGeneral\UI-Background-Rock`) and dark dialog background, tinted to the icon's palette with `SetVertexColor`.
- **Icons:** game icons for the drop, the button and the ready tick (for example `Interface\Icons\INV_Drink_07`, `Interface\RaidFrame\ReadyCheck-Ready`).
- **Bars:** `Interface\TargetingFrame\UI-StatusBar` for the meter.
- **Fonts:** the game's font objects.
- **Window ghost:** `ghost.tga` is the public icon (`art/SoThirstyIconPublic.jpeg`, the waterskin with the cross patch) in plain black and white, 512 px. It fills the whole content panel of every SoThirsty window, cropped rather than squashed, faintly behind all text and controls. Strength is `look.ghost` (0–100 %, default **25**, 0 = off): a slider on the Look tab, and `/sot ghost <n>`.
- **What we ship:** `logo.tga` / `logo-128.tga`, `minimap.tga` (the first icon, `art/SoThirstyIcon.png`, 64 px: the waterskin alone reads better at minimap size), `ghost.tga` and the three `glow-*.tga` pieces. Nothing else unless a game asset is missing on Forever (then the replacement goes in `Media/` and the reason in Section 16). Fallback backgrounds sit in `art/fallback/`.
- **Palette** (from the icon, `art/SoThirstyIcon2.png`): violet haze `#4F2365` over plum-slate stone `#2F1E22` for backgrounds, violet glow `#9E4DFF`, candle gold `#FACC5C` for titles, brass `#BF8C33` for fine edges, leather `#A5603A` for section markers, fel green `#6BE04D` as a sparing accent, warm white `#F2EBE0` body text. Water blue `#4FC3F7` stays for the chat prefix and the drinking drop.
- **Icon sizes:** `logo.tga` 64 px, `logo-128.tga` 128 px, `art/logo-256.png` for CurseForge.

---

## 10. Where it runs

`settings.zones` (multi-toggle):

| Zone | Default |
|---|---|
| Dungeons (`IsInInstance()` → `party`) | **on** |
| Raids (`raid`) | **on** |
| Open world / delves / scenarios | **on** (the glow is silent, so there's nothing to spam) |
| Battlegrounds / arenas (`pvp` / `arena`) | **always off**, not a setting |

The glow, the meter and the drink button all follow these rules.

---

## 11. Who sees what

- **Glow, pulse, nudge, meter:** only on the screen of a player who has the addon. Each viewer's own settings decide their own look.
- **The chat line:** everyone in the group, addon or not, when the healer (or anyone with the addon) clicks the button.
- There are **no addon messages** and no election in v2. Nothing needs to be agreed between clients, because nothing automatic is shared.

---

## 12. Settings, slash commands, debug

### 12.1 `SoThirstyDB` defaults

```lua
local DB_DEFAULTS = {
  version = 2,
  settings = {
    enabled = true,
    levels = {
      { pct = 50, color = { 1, 0.82, 0, 1 } },
      { pct = 30, color = { 1, 0.5, 0, 1 } },
      { pct = 10, color = { 1, 0.125, 0.125, 1 } },
    },
    ready = { pct = 90, color = { 0.25, 1, 0.25, 1 } },
    nudge = true, nudgeDelay = 5, nudgeHold = 3,   -- delay: 3 | 5 | 8 | 10
    quietAfterWipe = true,
    combatScope = "group",          -- "group" | "me"
    frames = { enabled = true, drop = true, readyTick = false, rangeFade = false },
    look = {
      palette = "classic",          -- "classic" | "water" | "colorblind" | "custom"
      bands = "smooth",             -- "smooth" | "steps"
      strength = true, alpha = 80, faint = 35,
      rest = 70,                    -- resting brightness; the nudge lifts it to 100
      drinkDim = 35,
      combat = "hide",              -- "hide" | "faint"
      pulse = true, pulseSpeed = "normal",
      style = "glow",               -- "glow" | "border" | "corners" | "tint" | "bar"
      thickness = 2,
      icon = "drop",
      greyColor = { 0.6, 0.6, 0.6, 0.6 },
      ghost = 25,
    },
    button = {
      show = "healer",              -- "healer" | "always" | "never"
      party = true, raid = true, instance = true,
      prefix = true, thirstyMsg = nil, readyMsg = nil, point = nil,
    },
    meter = { enabled = false, point = nil, scale = 100 },
    zones = { dungeon = true, raid = true, world = true },
    roleHint = true,
    minimap = { hide = false, angle = 215 },
    debugEvents = false,
  },
}
```

A v1 database (the old output grid, sound and on-screen tables) is migrated on load: keep `enabled`, the three level `pct` and `color` values, `ready`, `look.ghost`, `look.palette`, `roleHint`; drop the rest.

### 12.2 Options window (`UI/Options.lua`)

The addon's own window via `ns.CreateWindow`, plus an entry under Esc > Options > AddOns that opens it. Tabs (or stacked sections):

- **Levels:** three threshold sliders (10–90, step 10) with color swatches, the Ready row, bands (smooth/steps), feel presets.
- **Look:** palette, swatches with reset arrows, style, thickness, strength ramp, opacity, drinking dim, in combat (hide/faint), pulse, nudge (on/off, delay, hold), ready tick, range fade, drop icon, window ghost. A live **preview frame**.
- **Button & chat:** show (healer/always/never), Party / Raid / Instance checks, prefix, the two lines with token help and Reset, the preview line, unlock to move.
- **Meter:** on/off, scale, unlock to move.
- **General:** enabled, zones, combat check (group/me), role hint.
- **Save / Undo changes** (bottom left): a change shows at once, on the preview and on the real frames, so it can be judged. It only sticks when **Save** is pressed. **Undo changes** goes back to the last save. Closing the window with unsaved changes (the X, Escape) undoes them and says so in chat. Where the button, meter and minimap button were dragged to always sticks. Slash commands (`/sot levels`, `/sot meter`...) still apply at once when the window is closed.
- **Other buttons:** **Play** and **Show the nudge** (preview), **Debug info**, **Reset all**.

### 12.3 Slash commands (`/thirsty`, `/sot`)

| Command | Does |
|---|---|
| `/sot` | Opens options (prints status until the Options window exists) |
| `/sot on` / `off` | Master toggle |
| `/sot levels 50 30 10` | Quick-set thresholds (validated) |
| `/sot drink` / `ready` | Same as clicking the button (same rules and caps) |
| `/sot meter` | Show / hide the thirst meter |
| `/sot move` / `lock` | Show the button and the meter so they can be placed (they drag any time) |
| `/sot macro` | Makes the "SoT Drink" and "SoT Ready" macros and puts the first on the cursor |
| `/sot test` | Plays the preview. Never posts to chat. |
| `/sot ghost 25` | Window ghost strength |
| `/sot minimap` | Show / hide the minimap button |
| `/sot status` | Tracked healers and their known states |
| `/sot debug` | Client build, group type, chat channel, combat flags, per-unit role and secret flags |
| `/sot debug mana` / `curve` / `swatch` | The probes that answered Q17–Q19 |
| `/sot debug party` | Curves on a **party member's** mana, and the other open checks (Q20–Q24) |
| `/sot debug frames` | Which frame was found for each group unit (or "none") |
| `/sot debug drink` | Each healer's buffs and whether one counts as drinking |
| `/sot debug icons` | Shows each candidate icon in `Theme.lua` and reports which exist |
| `/sot debug events` / `window` | Live event print; sample window |
| `/sot help` | Command list |

---

## 13. Lightweight budget & code rules

- **CPU:**
  - `UNIT_POWER_UPDATE` (not `_FREQUENT`), mana type and tracked healer units only, coalesced to one refresh per healer per **0.5 s**.
  - `UNIT_AURA` for tracked healer units only, out of combat only, coalesced the same way.
  - Curves are built once and rebuilt only when a level, color or look setting changes.
  - Unregister unit events when solo, in a disabled zone, or when no healer is assigned.
- **Memory:** no per-refresh tables in hot paths. Reuse holders and curves.
- **No** `OnUpdate` scripts, with one exception: the minimap button sets one while it is being dragged and removes it on release. Timers use `C_Timer`; motion uses `AnimationGroup`.
- **Secrets:** never compare, branch on or do math with a secret. Guard every read with `ns.IsSecret`. Pass secrets only to `SetAlpha`, `SetVertexColor`, `SetValue`, `SetAlphaFromBoolean` and the curve-taking APIs.
- All player-facing text goes in `Locales/enUS.lua` (lines up to 200 characters).
- `.luacheckrc`: list every WoW API used in `read_globals`, and keep that list accurate.
- Keep the addon free, unobfuscated and ad-free (Blizzard UI Add-On Development Policy).

---

## 14. `CLAUDE.md`

The repo's `CLAUDE.md` carries the hard rules from this spec (1.1, 2, 8, 9.7, 13) and the working rules (phases, commits, PRs, tests). Keep it in step with this file.

---

## 15. Build phases

Each phase ends with: luacheck clean, tests passing on lua5.1 and luajit, a CHANGELOG entry, and a tag.

| Phase | Scope | Acceptance (Rich checks in game) |
|---|---|---|
| **1. Skeleton** ✔ | Repo, TOCs, Core, Locales, Debug, Window helper, CI, compartment entry | Loads on Forever with no Lua errors. |
| **2. Roster + probes** ✔ | `Roster.lua`, `Drink.lua`, `/sot status`, and the `/sot debug mana` / `curve` / `swatch` probes that led to design v2 | Roles tracked; Q1, Q2, Q17–Q19 answered. |
| **3. Glow** | Remove the v1 mana-reading code. `Levels.lua` v2 + tests (6.3), `Curves.lua`, `Frames.lua` (glow layer, holder alpha, drinking dim + drop, grey edge, hidden in combat), settings migration, `/sot debug party`, `/sot debug frames`, `/sot test` | First: `/sot debug party` confirms curves work on a party member (Q20). Then: in a party, the healer's frame glows below 50% and reddens as mana falls; it hides in combat, dims while they drink, and there are no taint errors. |
| **4. Motion** | `Combat.lua` (group combat, nudge timer, wipe flag), nudge animation, pulse layer, ready tick, range fade | One nudge 5 s after a fight; none on chain pulls or after a wipe; the pulse shows only below 10%. |
| **5. Drink button** | `Button.lua`: button, tint, cooldown, chat lines, caps, channel checks, `/sot drink` / `ready`, move/lock | A click posts one line to the right channel. A second click inside 15 s does nothing. Nothing in combat or in battlegrounds. |
| **6. Options + meter** | Full options window, palettes, styles, presets, live preview, `UI/Meter.lua`, `Theme.lua`, Esc-menu entry, `/sot debug icons` | Changing levels to 60/40/20 moves the glow at once. Steps vs smooth is visible. Every style and palette renders. The meter moves and remembers its spot. |
| **7. Release** | README (players), `docs/curseforge-description.md`, CurseForge project ID in the TOCs, `v1.0.0` tag | Packager builds a zip; installing it from CurseForge works on Forever. |

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

Questions 3, 4, 6, 8, 11 and 16 still matter for v2. Questions 9, 10, 12, 13 and 15 belonged to the v1 design (addon messages, sounds, mana-rise, chat-listen) and no longer apply.

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
- **Q22** (pulse animation over a secret alpha) is still open: nobody was below level 3 during the test.
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
