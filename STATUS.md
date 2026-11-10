# STATUS: Tristan's Addon (2026-11-10)

**What it is:** the WoW Forever-only, do-everything Paladin companion for Tristan Ludlowe (Human Paladin, Alliance, PvP-ruleset realm), with a Battle (PvP) section. It follows the structure, window design and website style of Andric's Addon and Parzelle's Addon (Parzelle's where they differ).

**Repo:** local `/home/tim/Projects/tristans-addon`, branch `main`. Commits use `Nine Point Labs <179739321+ninepointlabs@users.noreply.github.com>`.
- **Not on GitHub yet.** `gh repo create ninepointlabs/tristans-addon --public --source . --remote origin --push` was blocked by Claude Code's permission check (creating a public repo). Run it (or approve it) to create the repo, set `origin` and push `main`. CI (`.github/workflows/test.yml`) runs on every push to `main` once it's there.
- **No tag, no GitHub release, no release post, no topics, no Pages setting, no DNS.** Admin handles releases with Tim's explicit OK. `docs/CNAME` = `tristans-addon.myazerothlife.com` (file only).
- Target: loadable **v0.1.0** on `main` (the TOC says `@project-version@`; the packager fills it in on a tag).

## Tim's decisions (final, 2026-11-10 12:59 PM CT)

1. Level as Retribution; dual spec at 40 = Retribution (A) + Holy (B) for battlegrounds. The picker marks Ret "recommended for leveling" and explains the plan, including at level 1-9 with no talents.
2. PvP at v0.1: medium, all six Battle pieces. No manual enemy-trinket timer.
3. PvP-ruleset realm: world PvP has its own sub-tab, a contested/hostile-zone notice and survival tips. No ruleset API is in the research, so the ruleset is a setting (default PvP); on Normal the zone notices stay quiet.
4. Blessing button by class: Might for Warriors/Rogues/Hunters, Wisdom for casters/healers/hybrids, "Kings for everyone" toggle, per-class overrides.
5. Names: `/tristan` + `/paladin`, `TristansAddon` / `TristansAddonDB` / `TristansAddonCharDB`, repo `ninepointlabs/tristans-addon`, site `tristans-addon.myazerothlife.com`.

## What works (verified headlessly, 2026-11-10)

| Check | Result |
|---|---|
| `lua5.1 tests/run.lua` | **44/44 pass** |
| `python3 tools/paladin-changes-poller/tests/test_poller.py` | 4/4 pass |
| `python3 tools/build_data.py --check` | up to date |
| `python3 tools/ivcalc.py` | 9 build links decode; all 9 are exactly 51 points on Forever's trees |
| Lua syntax | every `.lua` loads |
| `tools/install-dev.sh <dir>` | copies only TOCs, Core, Data, Modules, UI, LICENSE |
| Website | `docs/index.html` parses; `node --check` passes for `docs/app.js` and `docs/demo.js`. **Not viewed in a browser.** |

The strict WoW mock (undefined globals are errors) loads every TOC file and renders every screen and sub-tab for Holy, Protection and Retribution at levels 1, 24, 30 and 60, plus:
- a **level-1 character with no talents and no spec** (picker, Home nudge, Talents "pick a spec");
- a **level-30 Retribution in a battleground with secret values mocked** (target health, target auras, cooldowns, `IsSpellUsable`, `UnitPVPRank`, then your own auras too). Everything renders, unreadable values show "hidden", the rotation flags "some info hidden", and Honor & Rank says where to look.

Tests also cover: A/B profiles and dual-spec auto-switch; Paladin stat parsing (melee, caster and tank lines), weapon rules (plate/maces/two-handers yes, daggers no), PvP weights; faction filtering (Undead quests hidden for Alliance); every rotation step's condition and spell; the level-1 "known spells only" rule ("Train it" at 4 for Judgement); Aura/Seal recommendations; Blessing class choice, Kings, overrides, Greater only in a raid with 3+; the Blessing button's secure macrotext, Freedom skip and re-offer, combat freeze, `/targetexact`, keys (none by default, Super/Meta refused, override click); the PvP bar macrotexts, picked ally, show modes, combat freeze, keys; cooldowns, Forbearance and the burst coach; PvP probes, zone notice, "buff before the gates open"; reminders; About (Tristan Ludlowe + sister-addon links); slash commands and events; no macros created; no leftover Mage/Priest text.

## Features (v0.1.0)

- **Window:** Home · *Play:* Rotation, Gear · ***Battle:* PvP** · *Progress:* Leveling, Talents · *Learn:* Learn the Paladin · What's new · Settings. Battle is one group in the same window.
  - Rotation sub-tabs: Solo · Dungeon · Raid · **Seals & auras** (with the Unsealed Wrath echo helper) · Mana.
  - Battle sub-tabs: Honor & Rank · Battlegrounds · PvP bar · Cooldowns · Burst coach · World PvP. Battle labels use a muted battle red.
  - Leveling: Path · Zones & dungeons · Trainer · Class quests · Riding & gold. Settings: General · **Paladin bar** · Tooltips & bags · Reminders · About the data · About.
  - Learn adds a **PvP basics** sub-tab (19 lessons on the `pvp` track).
- **Paladin bar** (`UI/PaladinBar.lua`): the Blessing button (secure, `type=macro` + `/cast [@unit,help,nodead] <Blessing>`), plus Aura and Seal **hint** cells (not secure, never cast; Blizzard's Aura flyout stays the way to switch).
- **PvP bar** (`UI/PvPBar.lua`): secure `/cast` macrotext buttons for Freedom, Cleanse/Purify, Blessing of Protection, Hammer of Justice and Repentance. Re-aimed out of combat only; shown "In PvP" (PvP realm, battleground or flagged), always or never. No right-click menus on secure buttons (a right-click would also cast); the ally picker is on Battle › PvP bar.
- **Keys:** all optional, unbound by default, set per character with `SetOverrideBindingClick` out of combat, Super/Meta refused. No `Bindings.xml`, no player macros, no `/click`.
- **Data:** 49 spells, 65 talent/other spell IDs, 9 builds, 8 quests (3 Alliance class quests, 3 Undead quests hidden for Alliance, 2 unconfirmed mount rows), 67 gear rows (39 items, 35 with Icy Veins DB sources), 4 battlegrounds, 14 rank rewards, 11 PvP cooldown rows, 30 conflicts, 34 gaps. Teaching content: 49 spells, 49 talents, 30 mechanics, 61 lessons.

## Install / test on TUF

```sh
cd ~/Projects/tristans-addon
tools/install-dev.sh            # copies to …/_forever_/Interface/AddOns/TristansAddon
python3 research/merge.py       # only after editing research/parts/*.json
python3 tools/build_data.py     # regenerate Data/*.lua (--check fails if stale)
lua5.1 tests/run.lua
```

In game: `/reload`, then `/tristan`. Check the client with `/run print(GetBuildInfo()) print(WOW_PROJECT_ID)`.

## Client check

| | Value |
|---|---|
| `omaforge clients` on TUF (2026-11-10) | Forever `1.60.1.70888`, Interface `16001` |
| `.toc` Interface used | `16001` (matches), in `TristansAddon_Forever.toc` and the identical `TristansAddon.toc` |
| Runtime guard | runs only when `WOW_PROJECT_ID == 18` (`WOW_PROJECT_CAMELOT`); prints a message otherwise |

Re-run `omaforge clients` before any tag and bump `## Interface` in both TOCs if it changed.

## PvP APIs: readable vs secret

Nothing below has been tested on Forever yet; no source documents Forever's PvP Lua API. The addon feature-detects each one and shows the result on **Battle › Honor & Rank** ("ok", "secret", "missing", "error"), so the first login tells us.

| API | Used for | Status |
|---|---|---|
| `UnitPVPRank`, `GetPVPRankInfo`, `GetPVPRankProgress` | rank, rank name, progress | unverified (Classic API) |
| `C_CurrencyInfo.GetCurrencyListSize/ListInfo` (found by name "Honor") | Honor amount | unverified; no Honor currency ID in the research, none hard-coded |
| `GetPVPSessionStats`, `GetPVPLifetimeStats` | session/lifetime HKs | unverified |
| `GetZonePVPInfo`, `UnitIsPVP`, `IsInInstance` | zone status, flag, battleground | unverified |
| `C_Spell.GetSpellCooldown` (own spells) | cooldowns, burst coach | readable out of combat per research; in combat unverified. Cooldown widgets accept secrets |
| `C_UnitAuras` on yourself | Blessing/Aura/Seal/Forbearance/Unsealed Wrath | own auras readable per research; aura contents in combat unverified |
| `C_UnitAuras`, `UnitHealth` on others; combat log; chat in instances | not used for decisions | secret / unavailable per research (wowforevertierlist, Blizzard rep) |
| Ruleset API | realm ruleset | exists per one source, name unknown: not used (setting instead) |

## Research gaps (shown in Settings › About the data; never guessed)

- Later rank levels for 36 spells come only from endgametools' game-data list (flagged unconfirmed); no per-rank spell IDs.
- Greater Blessings: no IDs; levels 52/54/60 secondary only. Blessing durations unverified.
- Base cooldowns of Divine Shield, Divine Protection and Blessing of Protection; Hammer of Justice, Blessing of Freedom and Forbearance numbers are fansite-only (flagged). PvP trinket name/effect unknown.
- Unsealed Wrath's echo aura name/ID (the helper reads an aura named "Unsealed Wrath" and shows "hidden" otherwise). Judgement debuff and Vengeance IDs.
- Holy and Protection level-60 stat priorities (their leveling orders are used). No Protection PvP source, so no Protection burst sequence.
- Paladin class mount quests at 40/60 (Tome of Nobility seen once on Wowhead; flagged).
- Class trainer names, battlemaster names and coordinates (so no battlemaster map pin; the brief's "Mark battlemaster on map" is not built).
- Honor currency ID, weekly-cap values, Honor amounts, season end; whether battlegrounds count as instances for the chat lockdown.
- No gear guides past level 30, no pre-raid BiS ("too early" per Icy Veins), no Paladin enchants.
- No "dungeon Protection" talent build was published (Prot has a leveling build only).
- The archived warcraft.wiki.gg Secret Values page is a Cloudflare block page; nothing was taken from it.

Main conflicts (30 total, listed in game): Righteous Fury Holy threat 60% vs 90% (90% used), Holy Strike 12 s vs 10 s (10 s), Judgement of Fury taunt 4 s vs 3 s (3 s), Lay on Hands 20 min vs 1 h (20 min), Divine Shield -50% damage vs none (-50%), several spell IDs (Seal of Fury, Holy Shock, Light's Vigil), Voice of Truth / Blessing of Light still on some guides (removed at launch, not imported), "Hammer of the Righteous" (not imported).

## Decisions and assumptions

- **Base:** Parzelle's code copied and renamed; Mage-only modules (Conjure, Hand out, Travel/portals, CC tracker) removed. No `Andric*`/`Parzelle*` globals, frames or SavedVariables remain; the only mentions are the sister-addon links in Settings › About, README and website.
- **Research:** two parts merged by `research/merge.py`. Agents fetched and archived extra pages in `research/raw/` (Wowhead Forever leveling/abilities pages, endgametools spell list). The Wowhead "overview" pages in the original box were retail content and weren't used. `research/raw/` (8.5 MB) stays gitignored, like the sister addons. NOTES.md's Normal-realm inference is marked superseded by Tim's decision.
- **Addon assumptions (shown in About the data):** gear weights from priority order; percent stats and weapon DPS × 10 per 1% / per 1 DPS; PvP weights put Stamina first; Seal hint uses a 3.4 s swing as the "slow two-hander" cut-off (sources say slow/fast without a number); hybrids default to Wisdom; your own Blessing follows your spec; Righteous Fury "off unless tanking" is inferred from its threat bonus (flagged).
- **Rotation engine:** new conditions `seal_missing`, `usable` (Hammer of Wrath), `target_undead_or_demon`, `in_melee`, `target_debuff_missing:<Debuff>`. A Seal step is never suggested while that Seal is already up.
- **CI:** `test.yml` runs on push to `main` and on PRs. `release.yml` (BigWigs packager) only runs on `v*` tags; none made.
- **autonomix-cli:** not listed, because the addon ships no Linux executables.

## Commits

- `e89c98d` Tristan's Addon v0.1.0: spec-aware Paladin companion for WoW Forever, with a Battle (PvP) section
- `b608af5` STATUS: v0.1.0 on main, checks, PvP API probes, gaps, in-game checklist

## Still to check in game

1. Slash commands: are `/tristan` and `/paladin` free (not Blizzard commands or emotes)? If one clashes, keep `/tristan` and drop the other.
2. **Blessing button:** casts on self, party and a stranger (`/targetexact`); Might/Wisdom by class; Freedom skip then re-offer; key binding.
3. **PvP bar:** each button casts; does Forever honour `[@mouseover]` and `[mod:shift,@focus]` in these `/cast` lines? Does the picked ally resolve?
4. **Battle › Honor & Rank probe table:** which PvP APIs say ok/secret/missing; does Honor show up in the currency list by that name?
5. `GetZonePVPInfo` values on the PvP realm (contested/hostile notices), and `IsInInstance` = "pvp" in battlegrounds ("buff before the gates open").
6. Own aura reads in combat (Seal, Aura, Blessing, Forbearance `expirationTime`), and the Unsealed Wrath echo aura's real name.
7. `C_Spell.IsSpellUsable` for Hammer of Wrath under 20%; own cooldowns in combat.
8. Stat parsing against real Forever tooltips (melee/tank lines), gear upgrade glow, map pins.
9. Dual spec at 40 (Ret A + Holy B auto-switch), window layout, both bars' positions, Lua errors (`/console scriptErrors 1`).
10. After Tristan's first logout: read StoryTracker for his realm name and level and update the brief/STATUS.
11. Website: open `docs/index.html` in a browser; add screenshots (other players' names pixelated) once Tim provides them.
