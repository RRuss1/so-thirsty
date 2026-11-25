# SoThirsty — Design Spec & Build Brief

> **For Claude Code (VS Code):** This is the source of truth for the SoThirsty addon. Read all of it before you write any code. Build in the phases in Section 15, and finish and test each phase before you start the next. If something in this spec is unclear, or a Forever API behaves differently than described here, **ask Rich or add the question to Section 16. Don't guess.**
>
> The house style comes from `C:\Users\goret\Desktop\DEV\bounty-line`. Read that repo's `CLAUDE.md`, `.luacheckrc`, `.pkgmeta`, `.github/workflows/`, `addon/BountyLine/Core.lua`, `Debug.lua`, `UI/Options.lua`, `UI/Window.lua`, `Locales/enUS.lua` and `addon/tests/logic.lua`, and mirror their patterns. Section 3 lists what to copy and what to leave out.

---

## 1. What it is

**SoThirsty** is a lightweight in-game addon for **WoW: Forever**. It tells the group when a **healer's mana is low**, so the tank waits for the healer to drink before the next pull.

- **Only one person in the group needs it.** Any player with the addon watches every healer in the party or raid, including healers who don't have it. If several people have it, they agree on a single poster, so the group sees each warning once (Section 11).
- It watches every group member whose **assigned role is Healer**, using the game's "Set Role" / role check.
- It has **three warning levels**: 50%, 30% and 10% by default. Each level can be changed or turned off.
- It speaks **once, 10 seconds after combat ends**, and only if the healer is below a level **and isn't already drinking**. Nothing fires mid-fight.
- It shows warnings three ways, each one customizable (Section 9):
  1. A **colored highlight** on the healer's party/raid frame.
  2. An **on-screen banner** (SoThirsty's own, never the raid-warning frame), seen only by the local player.
  3. An optional **group chat line** in party, raid and/or instance chat (chosen per level), so players without the addon see it too. Never raid warnings.
- It is **in-game only**. It has no Discord integration, no Worker, no relay and no network requests.

**Name and branding**

- Display name: **So Thirsty**
- Folder and internal name: `SoThirsty`
- Slash commands: `/thirsty` and `/sot`
- Chat prefix color: water blue `|cff4fc3f7`

### 1.1 The quiet contract: informative, never annoying

These rules beat every other setting. If a feature would break one of them, the rule wins.

1. **One alert window per fight.** Warnings are evaluated once, `settleSeconds` (default **10 s**) after the group leaves combat. If combat restarts inside the window, the window is cancelled and nothing is said.
2. **Drinking means quiet.** If the healer is already drinking at the end of the window, say nothing (Section 6.4).
3. **Escalation only.** A level is announced at most once per drain cycle. A later warning must be deeper than the last one. Same level twice = silence.
4. **One chat line per window, for the whole group.** If several healers are low, they're merged into one line.
5. **One poster per group.** Only the elected addon user posts to chat (Section 11). Everyone else stays local.
6. **Hard cap.** At most **3 SoThirsty chat lines per 5 minutes** from any one client. Past the cap, warnings go local only, and the player sees a one-time local notice.
7. **Ready is quiet by default.** "Good to go" clears the frame highlight and shows locally, but doesn't post to chat unless the player turns it on.
8. **Wipes are quiet.** After a group wipe, everyone is low and everyone knows it. Stay silent until the next combat ends.
9. **Snooze is one click.** `/sot snooze`, the compartment menu, or a right-click on the banner silences chat for 30 minutes (or the rest of the instance).

---

## 2. Target client

Same as Bounty Line:

- **WoW: Forever, Interface `16001`.** Ship **both** `SoThirsty_Forever.toc` and `SoThirsty.toc` with the same contents, the same way Bounty Line does.
- **The client is a modern Midnight-based client with restrictions:**
  - **Secret values:** unit data, including other players' power, health and auras, can be hidden as secret values, especially in combat. Always check with `issecretvalue` through an `ns.IsSecret` helper. Never do math on a secret value. Skip it and degrade gracefully.
  - `COMBAT_LOG_EVENT_UNFILTERED` is forbidden. SoThirsty doesn't need it.
  - Addon comms (`C_ChatInfo.SendAddonMessage`) are restricted during instance encounters. SoThirsty only sends when out of combat. Still queue sends, and drop them if combat starts.
  - No realms. Key players by **GUID**, not by name.
- It is Lua 5.1. CI tests on both `lua5.1` and `luajit`.

---

## 3. Repo layout (mirror bounty-line, addon-only)

Create a new repo at `C:\Users\goret\Desktop\DEV\so-thirsty`:

```
so-thirsty/
├── CLAUDE.md                     # project rules (Section 14)
├── README.md                     # player-facing: install, what it does, commands, settings
├── CHANGELOG.md                  # one entry per phase
├── CONTRIBUTING.md               # adapted from bounty-line (drop worker/codec lines)
├── PRIVACY.md                    # "SoThirsty sends nothing anywhere except your own group chat if enabled"
├── SECURITY.md
├── LICENSE                       # same license as bounty-line
├── .gitignore                    # copy from bounty-line, trim worker/node bits
├── .luacheckrc                   # same shape as bounty-line (Section 13)
├── .pkgmeta                      # package-as SoThirsty, move addon/SoThirsty, ignore docs/tests/*.md
├── .github/
│   ├── ISSUE_TEMPLATE/ (bug_report.md, feature_request.md)
│   └── workflows/
│       ├── ci.yml                # addon job ONLY: luacheck + lua5.1 + luajit tests
│       └── addon-release.yml     # BigWigsMods/packager@v2 on v* tags (copy as-is)
├── docs/
│   ├── SoThirsty-Design-Spec.md  # THIS FILE (move it here in Phase 1)
│   └── curseforge-description.md
└── addon/
    ├── SoThirsty/
    │   ├── SoThirsty_Forever.toc
    │   ├── SoThirsty.toc
    │   ├── Locales/enUS.lua      # ALL player-facing text, plus drink aura names
    │   ├── Core.lua              # SavedVariables, defaults, slash commands, startup
    │   ├── Levels.lua            # PURE logic: threshold state machine + drink decision (no WoW API calls)
    │   ├── Roster.lua            # who's in the group, who's a healer, mana reads
    │   ├── Drink.lua             # drink aura scan + mana-rise sampling
    │   ├── Combat.lua            # group combat state, alert window timer, wipe detection
    │   ├── Announce.lua          # chat line + on-screen + sound, merge, caps, snooze
    │   ├── Comms.lua             # HELLO, poster election, MANA reports, chat-listen dedupe
    │   ├── Theme.lua             # color presets, texture/style tables, sound list (data only)
    │   ├── Frames.lua            # party/raid frame highlights in the chosen style
    │   ├── Debug.lua             # /sot debug ...
    │   ├── UI/Window.lua         # copy bounty-line's window helper (ns.CreateWindow, ns.Text)
    │   ├── UI/Banner.lua         # optional movable on-screen banner (Section 9.3)
    │   ├── UI/Options.lua        # settings window + Esc > Options > AddOns entry
    │   └── Media/                # only what the game doesn't have (Section 9.7)
    │       ├── logo.tga          # the SoThirsty icon (art/SoThirstyIcon2.png), 64 px (TOC + compartment)
    │       ├── logo-128.tga      # the same, 128 px (window title, banner)
    │       ├── ghost.tga         # greyscale, faded icon behind window content (Section 9.7)
    │       ├── glow-*.tga        # soft glow pieces (reused from bounty-line)
    │       └── Custom/README.txt # "drop custom1.ogg..custom3.ogg here" (Section 9.4)
    └── tests/
        └── logic.lua             # stubbed-API tests for Levels, Announce (merge/caps), Comms (election)
```

**Copy from bounty-line:** the `local addonName, ns = ...` namespace pattern, `ns.L` locales, `ns.Print`, `applyDefaults`, the slash command table (`COMMANDS`), the `ADDON_LOADED` startup, the `pcall(ns.RegisterOptions)` Settings entry, the options window's `{ "check" / "cycle" / "head" }` row tables, the debug `line()`/`show()` helpers, the luacheck and CI setup, the packager workflow, and the addon compartment functions.

**Leave out:** worker/, relay/, shared/, the codec, LibDeflate, qrencode, QR codes, packs, the Discord, the minimap button (the addon compartment entry is enough for a lightweight addon), and any network behavior.

**Libraries:** none. No LibStub, Ace or LibSharedMedia. Plain Blizzard API only.

---

## 4. TOC

```
## Interface: 16001
## Title: So Thirsty
## Notes: Tells your group when the healer is low on mana, out of combat, so the tank waits before pulling.
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
Announce.lua
Comms.lua
Frames.lua
Debug.lua
UI\Window.lua
UI\Banner.lua
UI\Options.lua
```

Settings are account-wide (`SoThirstyDB`). There's no per-character DB in v1.

---

## 5. Healer detection: tie into "Set Role"

- A unit is tracked only when **`UnitGroupRolesAssigned(unit) == "HEALER"`**. This is the role set through the role check, the LFG tool, or right-click portrait > **Set Role**.
- The **local player doesn't have to be the healer.** Every addon user tracks every healer in the group. This is what lets one addon user cover a group of players who don't have it.
- Re-scan on `GROUP_ROSTER_UPDATE`, `PLAYER_ROLES_ASSIGNED`, `ROLE_CHANGED_INFORM`, `PLAYER_ENTERING_WORLD`, and on `ADDON_LOADED` if already grouped.
- Units to scan:
  - In a raid (`IsInRaid()`): `raid1`–`raid40`.
  - In a party: `player` plus `party1`–`party4`.
  - Solo: do nothing. Unregister the power events to stay lightweight.
- Store tracked healers by GUID: `{ unit, guid, name, class }`. Units can shift when the roster changes, so always map GUID → current unit on each rescan.
- Skip a healer who is **dead or a ghost** (`UnitIsDeadOrGhost`), **offline** (`not UnitIsConnected`), or whose role read is secret.
- **No role assigned anywhere in the group:** do nothing by default. Print a single, once-per-group hint ("No healer role set — right-click the healer's portrait > Set Role") **only to the group leader**, and only if `settings.roleHint` is true (default true).
- Use the healer's **mana**, not their primary power: `UnitPower(unit, Enum.PowerType.Mana)` and `UnitPowerMax(unit, Enum.PowerType.Mana)`. This keeps working for druids in shapeshift forms. If max is 0, secret, or nil, skip the unit.
- If a healer has the addon, their own client's `MANA` report (Section 11.3) is preferred over a remote read. A player's own mana and auras are never secret to themselves.

---

## 6. The three warning levels

### 6.1 Defaults (customizable)

| Level | Default | Color (Classic preset) | Frame | On-screen | Party chat | Raid chat | Instance chat | Sound | Default chat line |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **50%** | Yellow `#FFD100` | ✔ | ✔ small | ✘ | ✘ | ✘ | ✘ | `{name} is getting thirsty ({pct}% mana)` |
| 2 | **30%** | Orange `#FF8000` | ✔ | ✔ medium | ✔ | ✘ | ✔ | ✘ | `{name} is thirsty ({pct}% mana) - let them drink` |
| 3 | **10%** | Red `#FF2020` | ✔ | ✔ large | ✔ | ✔ | ✔ | ✔ | `{name} is SO thirsty ({pct}% mana) - DON'T PULL` |
| Ready | **90%** | Green `#40FF40` (clears highlight) | ✔ | ✔ small | ✘ | ✘ | ✘ | ✘ | `{name} is refreshed ({pct}% mana) - good to go` |

- The Frame / On-screen / Party / Raid / Instance / Sound columns are the **output matrix**. Each cell is a setting (Section 9.1). The defaults keep chat quiet: 50% is a local heads-up only, chat starts at 30% in parties, and raids (where 20+ people read the chat) only hear about 10%.
- **Chat channel per level:** each level has three separate checks: **Party**, **Raid** and **Instance**. The channel used is still decided by the group type (8.3); the check says whether that level may post in that kind of group. Example: L2 with Party ✔ and Raid ✘ posts in a 5-man but stays local in a raid.
- **Color per level:** every level color (and Ready) has its own swatch that opens the color picker (9.2).
- Each level has an **enable toggle** and a **threshold from 5 to 95**, in steps of 5. The UI also accepts typed values from 1 to 99.
- Validation: the enabled thresholds must be **strictly descending** (L1 > L2 > L3). If an edit breaks the order, reject it and show a message. Don't silently reorder.
- **Ready** (default **on**, chat **off**): when a healer who triggered any level recovers to `readyAt` (default 90%), clear their highlight and show one local "good to go". Players who want the tank's green light in chat can tick its Party / Raid / Instance cells.
- Message templates are editable. Tokens are `{name}`, `{pct}`, `{level}`, `{threshold}` and `{class}`. "Reset messages" restores the defaults.
- `pct` = `floor(mana / max * 100)`. A level is "current" when **pct < threshold** (strictly less than, so "less than 30%" means 29 and below).

### 6.2 State machine (`Levels.lua`, pure, fully unit-tested)

Keep this file free of WoW API calls. It takes numbers and booleans and returns decisions, so `tests/logic.lua` can cover it completely.

Per-healer state (keyed by GUID):

```lua
state = {
  announced = 0,     -- deepest level announced this drain cycle (0 = none)
  cycle     = false, -- any level announced since last "ready"
  lastPct   = nil,
}
```

**`ns.Levels.Current(pct, cfg)`** returns the deepest enabled level whose threshold is greater than `pct`, or 0.

**`ns.Levels.Update(state, pct, inCombat, cfg)`** runs on every (coalesced) mana update. It never announces a level. It returns `nil`, `{ kind="arm" }` or `{ kind="ready" }`.

1. If `pct` is secret, return nil and leave the state untouched.
2. Set `lastPct = pct`.
3. **Re-arm:** while `announced > 0` and `pct >= threshold[announced] + cfg.rearmMargin` (default **5**), step `announced` down to the next shallower enabled level (or 0). This prevents flapping at the boundary.
4. **Ready:** if `cycle` is true, `pct >= cfg.readyAt`, Ready is enabled, and not `inCombat`: set `cycle = false`, `announced = 0`, return `{ kind="ready" }`.
5. **Arm:** if not `inCombat` and `Current(pct) > announced`, return `{ kind="arm" }`. This tells `Combat.lua` to open an alert window if one isn't open already (for mana spent between pulls, like buffing or topping people off).

**`ns.Levels.Settle(state, pct, drinking, cfg)`** runs once per healer when an alert window closes (Section 7). It returns `nil` or `{ kind="level", level=n, pct=pct }`.

1. If `pct` is secret or nil, return nil.
2. `current = Current(pct)`. If `current <= announced`, return nil (escalation only). A drop from 60 to 8 announces **only level 3**, never 50, then 30, then 10.
3. If `drinking` is true, return nil and **don't** change `announced`. If they stop early and the next pull drains them further, the next window can still warn.
4. Otherwise set `announced = current`, `cycle = true`, and return the level decision.

**`ns.Levels.IsDrinking(auraMatch, startPct, endPct, cfg)`** is the pure half of drink detection (Section 6.4):

- `auraMatch == true` → true.
- Otherwise, if both pcts are real numbers and `endPct - startPct >= cfg.drinkRise` → true.
- Otherwise false. (A secret or unknown aura read is `nil`, not `false`; it falls through to the mana-rise check.)

### 6.3 Required tests (in `addon/tests/logic.lua`)

Levels:

- 100 → 49, settle: L1 once. 48, 47, settle again: nothing.
- 100 → 29, settle: only L2.
- 60 → 8 in combat, settle at 8: L3 once.
- 60 → 25 in combat, drinks to 40 by settle: L1 at most (not L2).
- 29 → 31 → 29 (inside the re-arm margin), settles each time: no second L2.
- 29 → 36 → 29 (past the margin), settle: L2 again.
- Settle while drinking: nil, `announced` unchanged. Next settle, not drinking, still at 25: L2 fires.
- Two settles in a row with no mana change: the second returns nil.
- 9 → 92 out of combat: Ready once, then nothing.
- Ready disabled: never fires.
- A disabled level is skipped (L1 off and a drop to 45 does nothing).
- Custom thresholds 60/40/20 behave the same way.
- Invalid order (30/50/10) is rejected by `ns.Levels.Validate`.
- Secret pct: `Update` and `Settle` return nil and the state is unchanged.
- `Update` out of combat returns `arm` once a new level is crossed, and never returns `arm` in combat.
- `IsDrinking`: aura true → true; aura nil + rise 12 → true; aura nil + rise 3 → false; aura false + secret pcts → false.

Announce and Comms:

- Two healers settle in the same window → **one** merged line: `Healers thirsty: Sherl 28%, Brann 9%`.
- A fourth chat line inside 5 minutes is refused (cap) and routed local.
- Snooze on: chat refused, on-screen and frames still work.
- Wipe flag on: the window produces nothing.
- Election (pure `ns.Comms.Elect(hellos, roster)`): the leader with the addon wins; no leader → tank with the addon → lowest GUID. Every client computes the same winner from the same input.
- Healer opted out (`announceMe = false`): never in a chat line, still on frames.

### 6.4 Drink detection (`Drink.lua`)

"Already drinking" is checked at the **end** of the alert window, per healer. A healer is drinking if **either** signal says so:

1. **Drink aura.** Scan the healer's helpful auras (`C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")`, or `AuraUtil.ForEachAura`). Match the aura name against `L.DRINK_AURAS` (enUS: `Drink`, `Food & Drink`, `Refreshment`), plus an optional spell ID set in `Theme.lua` for known drinks. If any field we need is secret, the result is `nil` (unknown), not `false`.
2. **Mana rising.** `Drink.lua` samples the healer's pct when the window opens and again when it closes. If it rose by at least `settings.drinkRise` (default **10** percentage points across the 10 s window), treat them as drinking. This works even when auras are secret, as long as mana isn't. Tune the default with `/sot debug drink` (Section 16, Q11–Q12).

Extras:

- The healer's own client (if they have the addon) sends its own drinking flag in its `MANA` report. It's never secret to them, so it wins over a remote read.
- Frames can show a small **drinking** indicator on the healer's frame (`frames.showDrinking`, default on), so the tank can see "they're on it" without anyone typing.
- If a healer stops drinking early, we **don't** nag. The next alert window re-checks.

---

## 7. Combat gate and the alert window (`Combat.lua`)

The goal: **warnings never fire while anyone is fighting**, and they fire **once**, after things have calmed down.

- **The group is "in combat"** if the player is (`InCombatLockdown()` / `UnitAffectingCombat("player")`) **or any group member is** (`UnitAffectingCombat(unit)`).
- Setting `combatScope`: `"group"` (default) or `"me"`.
- If a member's combat flag reads as secret, **treat them as in combat**. That's the safe choice.
- **Events:** `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, and `UNIT_FLAGS` for group units. If `UNIT_FLAGS` proves unreliable on Forever (see Section 16), fall back to a **0.5 s `C_Timer` ticker that runs only while the player is out of combat and some member was last seen in combat**. Never run an always-on OnUpdate.

**The alert window:**

- **Opens** when the group leaves combat, or when `Levels.Update` returns `arm` out of combat and no window is open.
- On open: record each healer's pct (the drink-rise baseline) and start a `C_Timer.NewTimer(settings.settleSeconds)` (default **10 s**, choices 5 / 8 / 10 / 15 / 20).
- **Cancelled** if combat restarts before it closes. Nothing is said, and the next combat end opens a fresh window. Chain pulls stay silent.
- **Closes** after the timer: for each tracked healer, read fresh pct, decide drinking (6.4), call `Levels.Settle`, collect the decisions, and hand the list to `Announce.lua` **once**.
- Only one window is open at a time. A second `arm` while a window is open does nothing.

**Wipe detection:** if, when combat ends, at least half the group (minimum 2) is dead or a ghost, set a `wiped` flag. The window still updates state silently but produces no output. The flag clears at the next combat start. (`settings.quietAfterWipe`, default on.)

**When combat starts:**

- Cancel the open window, drop queued chat and comms sends.
- Frame highlights follow `settings.highlightInCombat`:
  - `"hide"` (default): stale data is worse than none, and mana may be secret in combat.
  - `"freeze"`: keep the last out-of-combat state.

---

## 8. Warning outputs (`Announce.lua`)

`Announce.lua` receives one list of decisions per alert window and routes each decision through the output matrix (9.1). Frames, on-screen and sound are **local** to each addon user. Chat is **shared** and goes through every rule in 1.1.

### 8.1 Frame highlight (`Frames.lua`): always local, no spam risk

- Show a highlight in the level's color on the healer's unit frame, in the chosen style (9.2). Optionally show a **badge** (`frames.badge`, default on). The badge helps color-blind players.
- **Blizzard frames to support (v1):**
  - Compact party frames (`CompactPartyFrame` members)
  - Compact raid frames (`CompactRaidFrameContainer` children)
  - The classic party frames (`PartyFrame.MemberFrame1..4` or the Forever equivalent; confirm in `/sot debug frames`)
- **Finding frames:** walk the known containers and match `frame.unit` / `frame.displayedUnit` against the healer's unit with `UnitIsUnit`. Re-map on roster updates, and with `hooksecurefunc` on the compact-frame setup function only if the plain re-scan isn't enough. Never replace Blizzard functions.
- **Taint safety:**
  - Our overlay is a plain, non-secure `Frame` that we create and `SetAllPoints()` on the target frame.
  - Create and anchor it **only out of combat**.
  - In combat, only `Show`/`Hide` our own frame. Never touch the Blizzard frame's own properties.
  - Pulse uses an `AnimationGroup` on our own overlay (not OnUpdate).
- The highlight is **continuous**: it always shows the current level while out of combat and clears at or above the L1 threshold. It isn't a one-shot, and it doesn't wait for the alert window. It's silent, so it can't be annoying.
- **Fallback:** if no frame is found for a healer (custom frames, hidden frames), show nothing on frames. Chat and on-screen warnings still work. `/sot debug frames` reports which frames were found.
- **Third-party frames** (ElvUI, Cell, Grid2): out of scope for v1. Add them to the README "Planned" list.

### 8.2 On-screen warning: local, every player with the addon

- **No raid warnings.** SoThirsty never uses `RaidWarningFrame` / `RaidNotice_AddMessage`, and never posts to the `RAID_WARNING` channel. The on-screen warning is always SoThirsty's own movable banner (9.3), in the level's color.
- `settings.onScreen`:
  - `"all"` (default): show it on every addon user's screen.
  - `"tank"`: show it only if *my* role is TANK (`UnitGroupRolesAssigned("player")`).
  - `"off"`.
- The healer's own screen: `settings.onScreenSelf` (default **off**). The healer already knows they're dry.
- A merged window with several healers shows **one** on-screen message, colored by the deepest level in it.

### 8.3 Group chat line: visible to players without the addon

- **Channel:**
  - `INSTANCE_CHAT` if `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)`
  - else `RAID` if `IsInRaid()`
  - else `PARTY`
  - Never `SAY`, `YELL` or `RAID_WARNING`.
  - Then the level's per-channel check (6.1) must allow that channel (`out.party`, `out.raid`, `out.instance`). If it doesn't, the line stays local. A merged line posts if **any** level in it allows the channel.
- **Who sends** (`settings.announceMode`):
  - `"group"` (**default**): the one **elected** addon user posts for **every** healer, with or without the addon (Section 11). This is what makes "only one person needs it" work.
  - `"self"`: only post about my own mana, when I'm the healer. Ignores election.
  - `"local"`: never post to chat. Frames, on-screen and sound only.
- **Rate limits** (hard, not configurable):
  - At most **one chat line per alert window**. Several healers are merged into one line (`Healers thirsty: Sherl 28%, Brann 9%`). With a single healer, use that level's template.
  - At most **3 chat lines per 5 minutes** per client. Past that, route to local and print one local notice ("SoThirsty is staying quiet for a few minutes").
  - **Never** send while in combat, and never send in battlegrounds or arenas.
  - Snooze (`/sot snooze [minutes]`, default 30, or `instance`) blocks chat only.
- Prefix every chat line with `[SoThirsty]` so people know it's an addon message (`settings.chatPrefix`, default on). The prefix is also how other addon users spot the line for the chat-listen safety net (11.4). If a player turns it off, the Options window notes that the safety net is weaker.
- Optional raid marker in the line (`chat.marker`, default none; choices `{rt1}`–`{rt8}`). Group chat strips color codes, so **colors are local only**.
- There's no global channel override. Channel choice lives per level (6.1).

---

## 9. Customization: colors, textures, sound and feel

Everything here is cosmetic or local. None of it can make chat louder than the quiet contract (1.1) allows. All lists of textures, colors and sounds live in `Theme.lua` as plain data tables, so adding a style is a one-line change.

### 9.1 Output matrix and presets

- A grid in Options: rows **L1 / L2 / L3 / Ready**, columns **Color / Frame / On-screen / Party / Raid / Instance / Sound**. Defaults are in the table in 6.1.
- **Quick presets** set the output columns in one click (colors are left alone):
  - **Quiet**: Party + Instance on L3 only, Raid never; sound on L3.
  - **Normal** (default): Party + Instance on L2 and L3, Raid on L3; sound on L3.
  - **Chatty**: Party, Raid and Instance on L1, L2, L3 and Ready; sound on L2 and L3.
  - **Local only**: all chat checks off (same effect as `announceMode = "local"`).
- Tank extra: `sound.tankAll` (default on). If my role is TANK, I hear a sound on every level I'd see on-screen. The tank is the one who has to stop.

### 9.2 Colors and frame look

**Color picker everywhere.** Every color in SoThirsty is a swatch that opens the game's color picker (`ColorPickerFrame`, with opacity, and Cancel restores the old color). That covers:

- L1, L2, L3 and Ready colors (frame highlight, badge and banner text).
- The badge text color (default: same as the level).
- The drinking indicator color (default `#4FC3F7`).
- The banner background and border tint.
- The chat prefix color in your own chat frame (`|cff4fc3f7` by default; local only).

Every swatch has a small **reset** arrow next to it that puts back its default.

**Color presets** (`look.palette`) fill the four level colors in one click. Picking any color by hand switches the palette to **Custom**.

| Preset | L1 | L2 | L3 | Ready |
|---|---|---|---|---|
| **Classic** (default) | `#FFD100` yellow | `#FF8000` orange | `#FF2020` red | `#40FF40` green |
| **Water** (on-brand) | `#9BE7FF` light blue | `#4FC3F7` blue | `#7B4FF7` violet | `#FFFFFF` white |
| **Color-blind safe** | `#F0E442` yellow | `#E69F00` orange | `#CC79A7` magenta | `#56B4E9` sky blue |
| **Custom** | whatever you picked | | | |

**Highlight style** (`look.style`):

- `"glow"` (default): soft outer glow using the `glow-*.tga` textures.
- `"border"`: solid border, thickness 1–4 px (`look.thickness`, default 2).
- `"corners"`: four small corner brackets. The least intrusive option.
- `"tint"`: a translucent fill over the whole frame.
- `"bar"`: a colored strip over the frame's mana/power bar area only (still our own overlay, anchored to the frame).

**Other look settings:**

- Opacity 20–100% (`look.alpha`, default 80).
- Pulse: `"off"` / `"L3"` (default) / `"all"`, speed slow / normal / fast. `AnimationGroup` only.
- **Badge:** content `"pct"` (default, `30%`), `"icon"` (water drop), or `"both"`; position top-left / top-right (default) / bottom-left / bottom-right; size small / medium (default) / large.
- **Drop icon choice** (`look.icon`): a built-in game drink icon (default `INV_Drink_07`; list in `Theme.lua`, verified with `/sot debug icons`) or the SoThirsty logo.
- **Drinking indicator:** the badge swaps to a blue drop with a small "drinking" tint when 6.4 says they're drinking.

### 9.3 On-screen look

- The on-screen warning is always the **banner**. No raid-warning frame, ever.
- **Banner** (`UI/Banner.lua`): our own frame with the SoThirsty icon, the healer's class-colored name, and the pct in the level color. Background and border tint come from the color picker (9.2).
  - Movable: "Unlock banner" in Options or `/sot move` shows a drag handle; `/sot lock` hides it. Position saved in `onScreen.point`.
  - Scale 50–200% (`onScreen.scale`), hold time 2–8 s (`onScreen.hold`, default 4), fade out with an `AnimationGroup`.
  - Right-click the banner: snooze menu (30 min / rest of instance / cancel).
- Size per level (small / medium / large) follows 6.1, and can be flattened to one size (`onScreen.sameSize`).

### 9.4 Sound

- **Per-level sound** (`sound.levels[1..3]`, `sound.ready`): pick from a list of game sounds (`SOUNDKIT` entries verified on Forever with `/sot debug sounds`), or **None**. Each picker has a ▶ **Preview** button. Defaults: L1 none, L2 none, L3 an alert sound, Ready none.
- **Custom sounds, no library:** players can drop `custom1.ogg`, `custom2.ogg`, `custom3.ogg` into `Media\Custom\` and pick "Custom 1–3". Played with `PlaySoundFile`; a missing file fails silently. We ship no custom sounds.
- **Channel** (`sound.channel`): Master (default) / SFX / Dialog / Ambience, so players who mute SFX still hear it, or vice versa.
- Master toggle `sound.enabled`. A sound plays **at most once per alert window**, for the deepest level in it.

### 9.5 Chat look

- Editable templates per level and Ready, plus the **merged** template (`Healers thirsty: {list}`), with token help and Reset.
- Prefix on/off (8.3) and an optional raid marker. Party / Raid / Instance are chosen per level in the output grid (9.1).
- **Preview line** in Options shows exactly what would be sent, built from the current templates. Nothing is sent.

### 9.6 Feel and quality of life

- **Snooze:** `/sot snooze [30 | instance | off]`, compartment right-click menu, banner right-click. Chat only; frames stay.
- **Healer opt-out** (`announceMe`, default on): a healer with the addon can say "don't announce me". This goes out in HELLO (Section 11), so the elected poster leaves them out of chat. Frames still show for everyone.
- **`/sot test`** walks through L1 → L2 → L3 → drinking → Ready on **your own** frame, screen and sound only, 2 s apart, using the current look. Never posts to chat. An Options **Preview** button does the same for one level.
- **Status tooltip:** hovering the compartment icon lists tracked healers, their pct, drinking state, who the elected poster is, and whether snooze is on.

### 9.7 Blizzard assets first

Build the interface from the game's own assets wherever one exists. Ship art only when the game has no equivalent. That keeps the download tiny, matches the game's look, and stays inside the add-on policy (the client's own files only, nothing extracted or redistributed).

- **Templates:** `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `UIPanelCloseButton`, the game's slider template (`MinimalSliderWithSteppersTemplate`, or `OptionsSliderTemplate` on older clients), `InputBoxTemplate`, `UIDropDownMenu` / `MenuUtil` for pickers, `BackdropTemplate`, `GameTooltip`.
- **Color picker:** the game's `ColorPickerFrame`, never a homemade one.
- **Borders and backgrounds:** the dialog border (`Interface\DialogFrame\UI-DialogBox-Border`), the tiling rock (`Interface\FrameGeneral\UI-Background-Rock`) and dark dialog background, tinted to the icon's palette with `SetVertexColor`.
- **Icons:** game icons for the badge, drinking indicator and sound/preview buttons (for example `Interface\Icons\INV_Drink_07`, `INV_Drink_18`, `Spell_Holy_MagicalSentry`; the exact list lives in `Theme.lua`, verified with `/sot debug icons`).
- **Highlights:** game atlases and textures where they fit (action-button glow, `UI-Frame-*` borders); our `glow-*.tga` only for the soft window/frame glow.
- **Fonts:** the game's font objects (`GameFontNormal`, `GameFontHighlight`, `GameFontNormalHuge`, `NumberFontNormal`).
- **Sounds:** `SOUNDKIT` entries only (plus the player's own optional custom files, 9.4).
- **Window ghost:** `ghost.tga` is the icon, greyscaled, softened and faded to transparent well before its edges. It sits faintly in the middle of every SoThirsty window, over the inner panel and under all text and controls, tinted toward the violet. Strength is `look.ghost` (0–100 %, default **25**, 0 = off). It's a slider on the Look tab, and `/sot ghost <n>` until then.
- **What we ship:** `logo.tga` / `logo-128.tga` (the SoThirsty icon), `ghost.tga` (the window ghost) and the three `glow-*.tga` pieces. Nothing else unless a game asset is missing on Forever (then the replacement goes in `Media/` and the reason goes in Section 16). Addon-made violet-stone backgrounds sit in `art/fallback/` for exactly that case.
- **Palette** (from the icon, `art/SoThirstyIcon2.png`): violet haze `#4F2365` over plum-slate stone `#2F1E22` for backgrounds, violet glow `#9E4DFF`, candle gold `#FACC5C` for titles, brass `#BF8C33` for fine edges, leather `#A5603A` for section markers, fel green `#6BE04D` as a sparing accent (Ready / "good to go"), warm white `#F2EBE0` body text. Water blue `#4FC3F7` stays for the chat prefix and the drinking indicator, because it means water.
- **Icon sizes:** `logo.tga` 64 px (TOC, compartment), `logo-128.tga` 128 px (window title, banner), `art/logo-256.png` for CurseForge. The source art is center-cropped to square.

---

## 10. Where it runs

`settings.zones` (multi-toggle):

| Zone | Default |
|---|---|
| Dungeons (`IsInInstance()` → `party`) | **on** |
| Raids (`raid`) | **on** |
| Open world / delves / scenarios | **off** (prevents spam in casual groups) |
| Battlegrounds / arenas (`pvp` / `arena`) | **always off**, not a setting |

Frame highlights follow the same zone rules.

---

## 11. One addon user covers the group (`Comms.lua`)

This is a **core** feature, not optional. The default `announceMode = "group"` depends on it.

### 11.1 HELLO

- Addon prefix: `SoThirsty` (register with `C_ChatInfo.RegisterAddonMessagePrefix`).
- Messages are tiny pipe-delimited strings, versioned: `1|HELLO|<version>|<isHealer>|<announceMe>|<mode>`.
- Send on group join, roster change (debounced 2 s) and `/sot sync`, **out of combat only**. Queue anything that's blocked and flush it after combat.
- Keep a `hellos[guid]` table. Drop entries for GUIDs that leave the group.

### 11.2 Election: exactly one poster

Everyone computes the same answer from the same HELLO list, so there's no negotiation round-trip. Among addon users whose mode is `"group"`:

1. The **group leader**, if they have the addon.
2. Otherwise a player whose role is **TANK**, lowest GUID first.
3. Otherwise the **lowest GUID** (string compare).

Re-elect on every roster change or HELLO. The poster's own thresholds and templates decide the chat line. Everyone else's settings still decide their own local frames, on-screen and sound.

### 11.3 MANA reports (healers with the addon)

- When an alert window closes, a healer with the addon sends `1|MANA|<pct>|<drinking>` once. Out of combat only, so it's allowed.
- The poster waits up to **1 s** after its own window closes for these, then uses them instead of its remote reads. A player's own mana and auras are never secret to themselves, so this fixes any secret-value gaps.

### 11.4 Fallback and safety net: chat-listen dedupe

Used when comms are blocked or unreliable on Forever, **and** always as a second safety net:

- Before posting, a client waits a short **stagger**: 0 s if it's the elected poster, otherwise `0.5 + (hash(myGUID) % 10) * 0.25` s (up to about 3 s).
- During the window and the stagger, it listens to `CHAT_MSG_PARTY`, `CHAT_MSG_PARTY_LEADER`, `CHAT_MSG_RAID`, `CHAT_MSG_RAID_LEADER`, `CHAT_MSG_INSTANCE_CHAT` and `CHAT_MSG_INSTANCE_CHAT_LEADER`. If another group member (sender GUID ≠ mine) posted a line starting with `[SoThirsty]`, **stay quiet** for this window.
- If comms are confirmed unavailable, print a one-time local notice: "SoThirsty: addon messages are blocked here. Using chat-listen to avoid double posts."

---

## 12. Settings, slash commands, debug

### 12.1 `SoThirstyDB` defaults

```lua
local DB_DEFAULTS = {
  version = 1,
  settings = {
    enabled = true,
    -- color: {r, g, b, a} from the color picker; out: the output grid row (9.1).
    levels = {
      { enabled = true, pct = 50, msg = nil, color = { 1, 0.82, 0, 1 },
        out = { frame = true, screen = true, party = false, raid = false, instance = false, sound = false } },
      { enabled = true, pct = 30, msg = nil, color = { 1, 0.5, 0, 1 },
        out = { frame = true, screen = true, party = true,  raid = false, instance = true,  sound = false } },
      { enabled = true, pct = 10, msg = nil, color = { 1, 0.125, 0.125, 1 },
        out = { frame = true, screen = true, party = true,  raid = true,  instance = true,  sound = true  } },
    },
    ready = { enabled = true, pct = 90, msg = nil, color = { 0.25, 1, 0.25, 1 },
      out = { frame = true, screen = true, party = false, raid = false, instance = false, sound = false } },
    mergedMsg = nil,                -- nil = locale default "Healers thirsty: {list}"
    rearmMargin = 5,
    settleSeconds = 10,             -- 5 | 8 | 10 | 15 | 20
    drinkRise = 10,                 -- pct points across the window that count as "drinking"
    quietAfterWipe = true,
    combatScope = "group",          -- "group" | "me"
    announceMode = "group",         -- "group" | "self" | "local"
    announceMe = true,              -- healer opt-out, sent in HELLO
    chat = { prefix = true, marker = nil },   -- channels are per level (levels[n].out)
    onScreen = {
      mode = "all",                 -- "all" | "tank" | "off"  (always our banner; never raid warnings)
      self = false,
      scale = 100, hold = 4, sameSize = false, point = nil,
      bgColor = { 0.05, 0.08, 0.12, 0.85 }, borderColor = { 0.31, 0.76, 0.97, 1 },
    },
    frames = { enabled = true, badge = true, showDrinking = true },
    look = {
      palette = "classic",          -- "classic" | "water" | "colorblind" | "custom" (any hand-picked color)
      badgeColor = nil,             -- nil = same as the level
      drinkColor = { 0.31, 0.76, 0.97, 1 },
      prefixColor = { 0.31, 0.76, 0.97, 1 },
      style = "glow",               -- "glow" | "border" | "corners" | "tint" | "bar"
      thickness = 2, alpha = 80,
      pulse = "L3", pulseSpeed = "normal",
      badgeContent = "pct", badgePos = "TOPRIGHT", badgeSize = "medium",
      icon = "drop",
      ghost = 25,                   -- faint greyscale icon behind window content, 0-100 % (9.7)
    },
    highlightInCombat = "hide",     -- "hide" | "freeze"
    sound = {
      enabled = true, channel = "Master", tankAll = true,
      levels = { "none", "none", "alert" }, ready = "none",
    },
    zones = { dungeon = true, raid = true, world = false },
    roleHint = true,
    snoozeUntil = nil,              -- time() or "instance"
  },
}
```

### 12.2 Options window (`UI/Options.lua`)

Build it the same way as Bounty Line's options: the addon's own window via `ns.CreateWindow`, plus a small canvas entry under Esc > Options > AddOns that opens it. Split it into **tabs** (or stacked sections if Bounty Line's window helper doesn't do tabs):

- **Warnings:** three level rows (enable check, threshold **slider** 5–95 step 5 with a numeric edit box, color swatch → color picker), the Ready row, the output grid (9.1: Frame / On-screen / **Party / Raid / Instance** / Sound checks per level) with preset buttons, and alert-window delay (cycle 5/8/10/15/20 s), drink-rise threshold, quiet after wipe.
- **Look:** palette (cycle), color swatches for every color in 9.2 (each opens the color picker, each with a reset arrow), highlight style, thickness, opacity, pulse, badge content/position/size, icon, drinking indicator, highlight in combat (cycle hide/freeze), window ghost strength (slider 0–100 %). A live **preview frame** on the tab shows the current look.
- **On-screen & Sound:** on-screen mode (all/tank/off), show on healer's own screen, Unlock banner, scale, hold, same size, banner background/border swatches; sounds on/off, channel, per-level sound pickers with ▶ preview, tank hears all.
- **Chat:** announce mode (group/self/local), announce me (healer opt-out), prefix, raid marker, "Edit messages..." (five edit boxes, token help, Reset), and the preview line.
- **General:** enabled, zones (three checks), combat check (group/me), role hint, snooze status + button.
- **Bottom buttons:** **Test** (runs `/sot test`), **Debug info**, **Reset all**, **Close**.

### 12.3 Slash commands (`/thirsty`, `/sot`)

| Command | Does |
|---|---|
| `/sot` | Opens options |
| `/sot on` / `off` | Master toggle |
| `/sot levels 50 30 10` | Quick-set thresholds (validated) |
| `/sot preset quiet\|normal\|chatty\|local` | Sets the output matrix |
| `/sot snooze [30\|instance\|off]` | Silences chat (frames and on-screen stay) |
| `/sot test` | Simulates L1 → L2 → L3 → drinking → Ready on **your own** frame, screen and sound only, 2 s apart. **Never** posts to chat. |
| `/sot move` / `lock` | Unlock / lock the banner |
| `/sot status` | Lists tracked healers with their mana %, level, drinking state, plus the elected poster |
| `/sot sync` | Re-sends HELLO |
| `/sot debug` | Client build, Interface, `WOW_PROJECT_ID`, group type, chat channel picked, combat flags, and for each unit: role, mana raw/max, secret flags |
| `/sot debug frames` | Which frame was found for each group unit (or "none") |
| `/sot debug drink` | For each healer: auras seen (name, spell ID, secret flags), drink match, and mana pct now vs. 10 s ago |
| `/sot debug comms` | HELLO table, election result, last MANA reports, whether sends succeed |
| `/sot debug sounds` / `icons` | Plays / shows each candidate in `Theme.lua` and reports which exist |
| `/sot debug chat` | Sends one test line to the group channel (asks for confirmation in chat first) to verify `SendChatMessage` works on Forever |
| `/sot help` | Command list |

---

## 13. Lightweight budget & code rules

- **CPU:**
  - Listen to `UNIT_POWER_UPDATE` (not `_FREQUENT`), filtered to `powerType == "MANA"` and tracked healer units only.
  - Coalesce updates per healer to at most one evaluation every **0.5 s**.
  - Scan auras **only when an alert window closes** (and in `/sot debug drink`), never on `UNIT_AURA` spam.
  - Listen to group chat events only while an alert window or stagger is open.
  - Unregister power events when solo, in a disabled zone, or when no healer is assigned.
- **Memory:** no per-frame tables in hot paths. Reuse state tables.
- **Size target:** about 1,500 lines of Lua total, excluding locales, `Theme.lua` data and tests.
- **No** `OnUpdate` scripts. Timers use `C_Timer.After` / `NewTimer`; animations use `AnimationGroup`.
- All player-facing text goes in `Locales/enUS.lua`. Locale lines are allowed to be long (`max_line_length = 200` for Locales, as in bounty-line).
- `.luacheckrc`: copy bounty-line's shape. Set `globals` to `SoThirstyDB`, `SLASH_SOTHIRSTY1/2`, `SlashCmdList` and the three compartment functions. List every WoW API used in `read_globals`, and keep that list accurate.
- Keep the addon free, unobfuscated and ad-free (Blizzard UI Add-On Development Policy).

---

## 14. `CLAUDE.md` for the new repo (create in Phase 1)

```markdown
# SoThirsty — Project Instructions

The full design lives in `docs/SoThirsty-Design-Spec.md`. Read it before any work. It is the source of truth; if code and spec disagree, ask before changing either.

## What this is
- `addon/SoThirsty/`: WoW: Forever addon (Lua). Interface 16001, `SoThirsty_Forever.toc` + `SoThirsty.toc`.
- In-game only. No Discord, no Worker, no network, no relay.
- Only one player in the group needs the addon; it watches every healer.

## Hard rules
- The quiet contract (spec 1.1) beats every other setting: one alert window per fight (10 s after combat), skip healers who are drinking, escalation only, one merged chat line per window, one elected poster per group, 3 lines / 5 min cap.
- Forever addon API = modern Midnight client with restrictions: secret values may hide unit data (power, auras, combat flags) — check with ns.IsSecret and degrade gracefully; no COMBAT_LOG_EVENT_UNFILTERED; addon comms restricted in encounters (queue + flush, out of combat only); no realms — key by GUID.
- Warnings fire OUT OF COMBAT ONLY. Never send chat in combat, in battlegrounds or arenas, or to SAY/YELL/RAID_WARNING.
- Healers = UnitGroupRolesAssigned(unit) == "HEALER". Nothing else.
- Never taint Blizzard frames: our own non-secure overlays only, created/anchored out of combat.
- Keep it lightweight: no libraries, no OnUpdate, UNIT_POWER_UPDATE only, auras scanned only when a window closes.
- Keep the addon free, unobfuscated and ad-free (Blizzard UI Add-On Development Policy).

## How to work
- Build in the phases in spec Section 15. Finish and test one phase before starting the next.
- Small commits with short, clean messages. No `Co-Authored-By` or other AI attribution lines in commits or PR descriptions.
- Work on a branch, open a PR, wait for CI, rebase-merge.
- Track progress in CHANGELOG.md (one entry per phase). Tag each finished phase `v0.<phase>.0`; v1.0.0 at release.
- When a Forever API behavior is uncertain, add it to spec Section 16 and add a `/sot debug` subcommand to test it in game. Don't guess.
- `Levels.lua` stays pure (no WoW API) and every rule in spec 6.2 has a test in `addon/tests/logic.lua`. Write the tests first.
```

---

## 15. Build phases

Each phase ends with: luacheck clean, tests passing on lua5.1 and luajit, a CHANGELOG entry, and a tag.

| Phase | Scope | Acceptance (Rich checks in game) |
|---|---|---|
| **1. Skeleton** | Repo, CLAUDE.md, both TOCs, Core (DB defaults, slash table, startup), Locales, Debug (`/sot debug`), Window helper, luacheck, CI, packager workflow, compartment entry | Loads on Forever with no Lua errors. `/sot debug` prints the client info and each group member's role and mana, showing `<secret>` where it applies. |
| **2. Logic** | `Levels.lua` + full tests (6.3), `Roster.lua` (role scan, mana reads, GUID map), `Drink.lua` + `/sot debug drink`, `/sot status` | `/sot status` in a party lists the healer with the correct % and drinking state. Setting or clearing the role via Set Role updates it. `/sot debug drink` shows a drink aura while the healer drinks. |
| **3. Gate + announce** | `Combat.lua` (group combat, alert window, wipe flag), `Announce.lua` (output matrix, merged line, on-screen, sounds, caps, snooze, zone rules), `/sot test`, `/sot debug chat` | In a dungeon, **the healer doesn't have the addon** and you do: the healer drops below 30 during a pull, and **one** chat line appears about 10 s after combat ends. If the healer is drinking by then, nothing is posted. Chain pulls post nothing until the last one ends. Nothing in BGs. |
| **4. Group mode** | `Comms.lua` (HELLO, election, MANA reports, chat-listen fallback), `/sot sync`, `/sot debug comms` | Two or three addon users in one group: each warning appears in chat **exactly once**. Kill comms (or test where they're blocked): chat-listen still prevents doubles. |
| **5. Frames + look** | `Frames.lua` highlights in all five styles, badge, pulse, drinking indicator, `Theme.lua` palettes; `/sot debug frames`, `/sot debug icons` | The highlight tracks the level out of combat, hides in combat, every style and palette renders, and there are no taint errors (`/console taintLog 1` is clean). |
| **6. Options + sound + banner** | Full tabbed options window, sliders + validation, output matrix + presets, color picker, message editor + preview line, sound pickers + preview + custom files, banner + move/lock, Esc-menu entry, `/sot debug sounds` | Changing thresholds to 60/40/20 works immediately. An invalid order is rejected. Each preset changes what reaches chat. Custom messages appear in chat. The banner moves and remembers its spot. |
| **7. Release** | README (players), `docs/curseforge-description.md`, logo, drop icon, CurseForge project ID in the TOCs, `v1.0.0` tag | Packager builds a zip; installing it from CurseForge works on Forever. |

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

### Answers so far

From `/sot debug`, client 1.60.1 build 71091 (16001), open world, out of combat, party of 2, no roles set:

- **Q2:** `UnitPower(unit, Mana)` is **secret out of combat**, for party members **and for the player**. `UnitPower(unit)` is secret too. `UnitPowerMax` was readable for the player and secret for the party member. `UnitPowerType` is readable. Leads to Q17.
- **Q5 (part):** `UnitAffectingCombat` is readable for party members out of combat.
- **Q7 (part):** `LE_PARTY_CATEGORY_INSTANCE` exists (= 2).
- `UnitGroupRolesAssigned`, `UnitGUID`, `UnitClass`, `UnitIsDeadOrGhost` and `UnitIsConnected` are readable. `UnitInRange` is secret.
- Q1 still open: no role was set yet in that test.

---

## 17. Out of scope (v1) and ideas parking lot

**Out of scope for v1:**

- Any Discord, web or network features.
- Tracking non-healer mana (DPS casters).
- Whisper alerts to the tank.
- Third-party unit frames (ElvUI, Cell, Grid2, VuhDo). List them as "Planned".
- Translations beyond enUS. The locale table is ready for them.

**Ideas for v1.1+ (not promises):**

- **Thirst meter:** a tiny movable panel listing each healer's mana bar in level colors, shown only out of combat.
- **`{eta}` token:** "~12 s to 90%", estimated from the drink-rise rate.
- Per-character profiles, and settings import/export strings.
- Third-party frame support (ElvUI, Cell, Grid2, VuhDo).
- Optional "tank whisper" mode for groups that hate group chat.
