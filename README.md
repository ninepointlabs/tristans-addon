# Tristan's Addon

The do-everything Paladin companion for **World of Warcraft: Forever**, with a real **Battle (PvP)** section.
Spec-aware for Holy, Protection and Retribution, with dual spec from day one. Named for **Tristan Ludlowe**,
Human Paladin of the Alliance, who lives on a PvP realm and would like to stop getting ganked in Redridge, thanks.

It's the third sibling of [Andric's Addon](https://andricsaddon.myazerothlife.com) (Priest) and
[Parzelle's Addon](https://parzelles-addon.myazerothlife.com) (Mage), from the makers of [My Azeroth Life](https://myazerothlife.com).

> **Status:** [v0.1.0](https://github.com/ninepointlabs/tristans-addon/releases/tag/v0.1.0) is out. Screenshots come once Tristan has logged a few hours.

- Website: https://tristans-addon.myazerothlife.com (files in `docs/`; the domain isn't live yet)
- WoW Forever only (`WOW_PROJECT_ID 18`), Interface `16001`. No Ace3; Blizzard API only. MIT.

## Contents

- [Install](#install)
- [Getting started](#getting-started)
- [Features](#features)
- [Battle: the PvP section](#battle-the-pvp-section)
- [What it can't do (and why)](#what-it-cant-do-and-why)
- [Slash commands](#slash-commands)
- [Where the information comes from](#where-the-information-comes-from)
- [For developers](#for-developers)
- [License and credits](#license-and-credits)

## Install

### With OmaForge (Linux)

Search for "tristan" in OmaForge, or:

```sh
omaforge install -c forever github:ninepointlabs/tristans-addon
omaforge update -c forever          # later versions
```

### By hand (any OS)

Download the zip from [GitHub Releases](https://github.com/ninepointlabs/tristans-addon/releases) and unzip it so the folder is
`World of Warcraft/_forever_/Interface/AddOns/TristansAddon`. From a checkout, `tools/install-dev.sh` copies only the files WoW needs.

## Getting started

1. Log in and type `/tristan` (or `/paladin`).
2. Pick a spec. Under level 10 there are no talents yet, so pick what you plan to level as. The plan: **level as Retribution**, then at 40 make dual spec **Retribution (A) + Holy (B)** for battlegrounds. Each profile keeps its own spec and follows your talent spec automatically.
3. Drag the **Paladin bar** (Blessing button, Aura hint, Seal hint) somewhere handy. Keys are optional and unbound by default.

## Features

The window has grouped screens: **Home** · *Play:* Rotation, Gear · *Battle:* **PvP** · *Progress:* Leveling, Talents · *Learn:* Learn the Paladin · What's new · Settings. Sub-tabs, a search box, "Sources & notes" on every screen, and a spec pill with the A/B profile in the header.

- **Home:** trainer now/next, riding savings, next class quest; *Needs attention* (no Blessing on you, no Aura, no Seal in melee range, Righteous Fury on while not tanking, the Redemption quest, unread news, new lessons); your rotation at a glance; a PvP card (Honor & Rank, or "open Character › PvP" when the client won't say) and world-PvP status.
- **Paladin bar:**
  - **Blessing button:** one press blesses the next friendly player missing *your* Blessing: you first, then your group nearest-first, your target, then friendly nameplates. Class-smart: Might for Warriors, Rogues and Hunters; Wisdom for casters and healers; Kings for everyone if you pick that (from 20). Every class can be overridden. Greater Blessings only when known, in a raid, when 3+ of a class need it. Anyone with your Blessing of Freedom or Protection is skipped until it ends (one Blessing per target), then offered again. Strangers via `/targetexact`.
  - **Aura hint** (Devotion solo, Retribution in groups, Concentration for Holy in PvP, resistance auras when you pin one) and **Seal hint** (Crusader first, then Command for slow two-handers or Righteousness for fast weapons; Seal of Fury for Protection, Wisdom for Holy). Hints only: Blizzard's Aura flyout stays the way to switch.
- **Rotation:** Solo / Dungeon / Raid priority lists per spec, known spells only ("Train it" when trainable, talents once taken), a small next-spell helper, a post-fight summary with mana tips, a **Seals & auras** sub-tab with the **Unsealed Wrath** echo helper (0–3, "swap Seal now"), and a **Mana** sub-tab.
- **Gear:** *For my level*, *Best overall*, *By bracket*, "How to get it", Mark on map, tooltip upgrade lines with per-spec weights, bag upgrade glow, and a **PvP weights** toggle (Stamina first).
- **Leveling:** path, zones and dungeons, trainer, class quests (The Tome of Divinity at 12 for Redemption, The Test of Righteousness at 20, A Strange Artifact at 22; Undead quests stay hidden for Alliance), riding & gold.
- **Talents:** builds drawn on Forever's own Paladin trees, each decoded and validated (every level-60 build is exactly 51 points), including PvP builds (Ret burst, Holy battleground healer).
- **Learn the Paladin:** every spell and talent, how Seals and Judgement work in Forever, group etiquette, leveling tips, common mistakes, level-gated lessons and a **PvP basics** track.
- **Reminders, What's new** (from `tools/paladin-changes-poller`), **Settings** (with About, named for Tristan Ludlowe).

## Battle: the PvP section

One group in the same window, with six sub-tabs:

- **Honor & Rank:** your rank, progress and Honor when the client lets addons read them, the next rank reward from Blizzard's table (R2 PvP trinket … R11 mount, R14 weapons), the blue → Emboldened Seal → epic path, and a table of which PvP APIs this client answered (ok / secret / missing).
- **Battlegrounds:** Warsong Gulch (10v10, 10–60), Arathi Basin (15v15, 20–60), Darkspear Islands (15v15, 30–60; Alliance portal at Northwatch), Alterac Valley (40v40, 51–60): objective, your spec's role, where to queue, marks, rep. Only the brackets your level allows are lit.
- **PvP bar:** secure buttons, one press = one cast: **Freedom** (mouseover, focus, your picked ally, else you), **Cleanse/Purify** (mouseover, focus, else you), **Blessing of Protection** (mouseover, picked ally, focus; not the tank), **Hammer of Justice** and **Repentance** (target; Shift for focus). Shown in PvP, always, or never.
- **Cooldowns:** your own PvP cooldowns and a **Forbearance** timer. Blizzard's Cooldown Manager (`/cdm`) is the built-in alternative.
- **Burst coach:** the sourced sequence for your spec (Ret: Hammer of Justice → Judgement → Holy Strike → Repentance → Hammer of Wrath; Holy: flag-carrier support). It follows *your* casts and cooldowns and lights the next step. Advice only.
- **World PvP:** your zone's status (sanctuary / friendly / contested / hostile), flag state, a notice when you enter contested or enemy land, and survival tips for leveling on a PvP realm. The realm ruleset is a setting (default PvP); it still works on Normal.

## What it can't do (and why)

Forever runs Blizzard's newer addon restrictions: **no combat log for addons**, other units' health, casts and aura contents are **secret values** in combat, and inside instances (probably battlegrounds too) addons **can't send chat or addon messages**. So Tristan's Addon does **not** do enemy trinket or cooldown tracking, diminishing-returns tracking, kill announcing, automatic battleground callouts, Spy-style enemy detection or auto-targeting healers. Some of that is impossible, and some would be automation Blizzard forbids.

For those jobs, use addons with Forever builds: **BetterBlizzPlates** or **Plater** (nameplates) and **Capping** (battleground timers).

Everything here is **advice only**: one key press = one cast, and nothing casts by itself.

## Slash commands

| Command | What it does |
|---|---|
| `/tristan` (or `/paladin`) | Open or close the window |
| `/tristan spec holy\|prot\|ret` | Set the active profile's spec |
| `/tristan profile [A\|B]` | Switch profile |
| `/tristan battle` · `honor` · `bg` · `cooldowns` · `burst` · `world` | Open a Battle sub-tab |
| `/tristan rotation` · `seals` · `mana` · `gear` · `leveling` · `talents` · `learn` · `news` · `settings` · `about` | Open a screen |
| `/tristan bless [key\|debug]` | Toggle the Blessing button, set its key, or print diagnostics |
| `/tristan pvpbar [always\|pvp\|never]` | When to show the PvP bar |
| `/tristan bar` | Move both bars back to their default spots |
| `/tristan hud` · `reset-hud` · `remind` | Rotation helper on/off, reset its position, check reminders now |

Keys: Settings › Paladin bar and Battle › PvP bar. None are bound by default, Super/Meta combos are refused (they belong to the desktop on Omarchy), and bindings only change out of combat. No `Bindings.xml`, no macros, no `/click`.

## Where the information comes from

Every fact in `research/data.json` carries its `source_url` and the date it was checked; the addon cites them under "Sources & notes" and Settings › About the data. Primary sources are Blizzard's posts (class deep dive, development notes, hotfixes, PvP progression, Darkspear Islands, rulesets). Icy Veins and Wowhead Forever guides come next. PvP fan sites are used only where nothing better exists, and those facts are marked **unconfirmed** in game. Gaps are listed, not guessed.

## For developers

```
Core/        Init, Spec, DB (SavedVariables TristansAddonDB / TristansAddonCharDB), DualSpec, Boot (events, slash)
Data/        GENERATED by tools/build_data.py (Changes.lua by the poller)
Modules/     Auras, Stats, Training, Progress, Paladin, PvP, Cooldowns, Reminders, Rotation, Summary, Changes, Learn, Tooltip, Map
UI/          Widgets, Main, Panels/*, Hud, Bags, PaladinBar, BlessingButton, Hints, PvPBar, Minimap
research/    data.json (+ parts/), talents_paladin*.json, item_sources.json, NOTES.md, sources.md, SCHEMA.md (raw/ is local only)
content/     learn.json (teaching + rotation text)
tests/       run.lua + wow_mock.lua (strict headless WoW mock)
tools/       build_data.py, ivcalc.py, fetch_talents.py, fetch_item_sources.py, install-dev.sh, paladin-changes-poller/
docs/        the website (excluded from the zip)
```

```sh
python3 research/merge.py                       # parts/*.json -> research/data.json
python3 tools/build_data.py                     # regenerate Data/*.lua (--check fails if stale)
python3 tools/ivcalc.py                         # decode and validate every talent build link
lua5.1 tests/run.lua                            # headless tests
python3 tools/paladin-changes-poller/tests/test_poller.py
tools/install-dev.sh                            # copy into …/_forever_/Interface/AddOns/TristansAddon
```

Releases are built by `.github/workflows/release.yml` (BigWigs packager) on a `v*` tag. Tags and releases happen only with Tim's explicit OK; before any tag, re-run `omaforge clients` and update `## Interface` in both `.toc` files if it changed.

## License and credits

MIT © Nine Point Labs. Game information from Blizzard, Icy Veins and Wowhead, credited per fact.
Tristan's Addon is an unofficial fan project, not affiliated with or endorsed by Blizzard Entertainment.
World of Warcraft and Warcraft are trademarks of Blizzard Entertainment, Inc.
