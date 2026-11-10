# research/data.json schema (Tristan's Addon, Paladin)

Same shape as Andric's Addon (Priest, `/home/tim/Projects/wow-forever-priest-addon/research/data.json`) and Parzelle's Addon
(Mage, `/home/tim/Projects/parzelles-addon/research/data.json`), with Paladin and PvP additions. Read one of them for examples.
`research/NOTES.md` is the starting summary; `research/raw/` holds the archived pages (HTML + MD).

**Every record** (list item or dict) carries `source_url` (the page the fact came from) and `checked` (`"2026-11-10"`, or the date
of the source record you copy). Never invent spell IDs, item IDs, quest IDs, NPC IDs, currency IDs, coordinates, stats, costs,
cooldowns or durations: use only what a raw page (or a page you fetched and archived in `research/raw/`) states.
Unknown -> omit the field (or `null`) and add a `gaps[]` entry. Conflicts -> add a `conflicts[]` entry.
Facts from one secondary/low-confidence site only (foreverbattlegrounds, thetirisfalen, lfcarry, wowcarry, foreverdb,
loreforeverwow, endgametools, foreverguide) get `"unconfirmed": true` and a short `"flag"`.
DATA WARNINGS: Voice of Truth, Twist of Light, Blessing of Light (+Greater), Blessing of Salvation/Salvation/Mass Salvation,
Blessing of Sanctuary, Sanctity Aura, Improved Retribution/Concentration Aura, Instrument of Law, Improved Seal of Fury,
One-Handed Weapon Spec are **removed at launch**: never list them as current. "Hammer of the Righteous" is not a Forever spell:
never import it. Seal of Righteousness/Command etc. use their exact English names.

`tools/build_data.py` turns `data.json` into `Data/*.lua`. Spell names must be the exact English in-game names.

## Core part (`research/parts/core.json`)
- `meta`: copy Parzelle's `meta` and change: `class: "Paladin"`, `latest_build_seen: "1.60.1.70888 (omaforge clients on TUF, 2026-11-10)"`,
  `talent_calc_version: "70888-1d81729b"`, `talent_calc_note` (Icy Veins build links use 70755-d1899b7d; both trees are in research/),
  `checked: "2026-11-10"`. Keep `toc_interface: 16001`, `max_level: 60`.
- `sources`: `{ short_key: url }` for every page used.
- `spells_by_level`: `[{ name, wowhead_base_spell_id, rank_learn_levels: [..], rank_spell_ids?: [...] (only if sourced, same length),
  school: "Holy"|"Physical"|null, category: "damage"|"heal"|"seal"|"judgement"|"blessing"|"aura"|"cc"|"defense"|"buff"|"utility"|"tank"|"resurrect",
  talent_tree?: "Holy"|"Protection"|"Retribution" (talent-taught spells whose later ranks are trained: name them `"<Name> (talent)"`, e.g. `"Holy Shock (talent)"`),
  faction?: "Alliance"|"Horde" (only if faction-specific), notes?, id_source?, unconfirmed?, flag?, source_url, checked }]`.
  Every Paladin trainer spell 1-60 for Forever. Primary source for levels: the Icy Veins leveling pages' spell/trainer tables
  (retribution/holy/protection-paladin-leveling) + class overview; Wowhead overview pages for IDs. Include at least:
  Seal of Righteousness, Seal of the Crusader, Seal of Command (talent), Seal of Justice, Seal of Light, Seal of Wisdom, Seal of Fury (new, 10),
  Judgement, Holy Strike (new, 6), Holy Light, Flash of Light, Lay on Hands, Blessing of Might, Blessing of Wisdom, Blessing of Kings (baseline 20),
  Blessing of Protection, Blessing of Freedom, Greater Blessing of Might/Wisdom/Kings (levels unverified -> flag), Devotion Aura, Retribution Aura,
  Concentration Aura, Fire/Frost/Shadow Resistance Aura, Righteous Fury, Divine Protection, Divine Shield, Divine Intervention (if sourced),
  Hammer of Justice, Hammer of Wrath, Consecration (baseline 20), Exorcism, Holy Wrath, Turn Undead, Purify, Cleanse, Redemption (class quest at 12),
  Sense Undead, Summon Warhorse/Charger (if sourced), Holy Shock (talent), Repentance (talent), Templar's Bulwark (talent), Holy Shield (talent),
  Divine Favor (talent), Light's Vigil (talent), Oath of Light (talent), Swift Judgement (talent). Judgement of X debuff names go in
  `talent_and_other_spell_ids`.
- `talent_and_other_spell_ids`: `[{ name, spell_id, tree?, source_url, checked }]` for talent spells, Judgement debuffs (Judgement of the Crusader,
  Judgement of Light, Judgement of Wisdom, Judgement of Righteousness, Judgement of Fury), procs/buffs/debuffs the addon reads (Forbearance,
  Vengeance, Unsealed Wrath echo buff name if sourced, Divine Favor, Light's Grace?...). IDs only if sourced; `spell_id: null` otherwise.
- `milestones`: `{ items: [{level, what}], talent_milestones: "...", trainer_costs: "...", source_url, checked }` (Icy Veins Ret leveling milestones).
- `talent_changes`: `[{ tree: "Holy"|"Protection"|"Retribution"|"Baseline", change, source_url, checked }]` (deep dive Oct 15 + Nov 2 launch values; say which).
- `builds`: `[{ spec: "Holy"|"Protection"|"Retribution", purpose: "Leveling"|"Dungeon"|"Raid"|"PvP"|..., talent_calc_url, notes?, unconfirmed?, flag?, source_url, checked }]`:
  every build link on the Icy Veins pages (`data-talentcalculator-pointsurl="#tc-...~70755-d1899b7d"`; full URL =
  `https://www.icy-veins.com/wow-forever/paladin-talent-calculator#tc-...~70755-d1899b7d`) and the Wowhead `/forever/talent-calc/paladin/vkndmh...`
  links on foreverbattlegrounds (PvP, secondary -> unconfirmed). Keep URLs exactly. Use the page's own label for purpose.
- `rotations`: `{ retribution, protection, holy, mana, seals: "<SoC vs SoR rule as sourced>", source_url, checked }` (short sourced summaries).
- `stat_priority`: `[{ spec: "Retribution"|"Protection"|"Holy"|"Leveling", priority: "A > B > C", source_url, checked }]`. Tokens must be from:
  `Weapon DPS`, `Hit`, `Expertise`, `Spell power`, `Healing`, `Intellect`, `Crit`, `Spell crit`, `Strength`, `Attack power`, `Agility`, `Stamina`,
  `Spirit`, `MP5`, `Defense`, `Armor`, `Block`, `Block value`, `Dodge`, `Parry` (parentheses allowed for notes). If a spec has no published
  priority, add a gap instead of inventing one.
- `quests`: `[{ type: "class"|"breadcrumb"|"mount", level, races: "Human/Dwarf"|"Undead"|"All", faction: "Alliance"|"Horde"|"Both", name, quest_id?, zone?,
  start_npc?, coords?, reward?, reward_spell?, reward_item_id?, notes?, unconfirmed?, flag?, source_url, checked }]`: 12 The Tome of Divinity (Redemption),
  20 The Test of Righteousness (Jordan Stilwell, Verigan's Fist), 22 A Strange Artifact (Cloak of the Divine Storm), the Undead Paladin quests as
  `faction: "Horde"`, mount quests 40/60 only as unconfirmed rows.
- `class_trainers`: `{ trainers: ["Name (City/Zone)", ...], source_url, checked }` (only sourced names; else gap).
- `racials`: Human and Dwarf (Alliance Paladin races) racials if sourced.
- `race_notes`: `{ text, source_url, checked }` (Paladin races in Forever: Human, Dwarf, Undead (new, Horde)).
- `changes_log`: `[{ date, change, source_url, checked }]` Paladin/PvP-relevant dated changes (deep dive, dev notes, Nov 2 launch, Nov 9/10 hotfixes).
- `conflicts`, `gaps`.

## Gear/world/PvP part (`research/parts/gear.json`)
- `gear_by_bracket`: `[{ bracket: "level 20"|...|"level 60 pre-raid", spec?: "Retribution"|"Protection"|"Holy"|null, name, item_id, slot?, source, level?, faction?,
  source_url, checked }]` from the Icy Veins leveling + BiS pages (Ret BiS page; leveling weapons: Ironforge Greathammer, Verigan's Fist, Manual Crowd Pummeler...).
  Item IDs only from links in the raw HTML (`item=NNN` / `/item/NNN`).
- `other_weapons`: `{ note, source_url, checked }`; `bis`: `{ status, flag, source_url, checked }`.
- `consumables_enchants`, `professions` (`{ leveling, raiding, alternatives: [...], pvp_note, source_url, checked }`; Engineering for PvP).
- `riding`, `mounts`, `zones_by_level`, `new_zones`, `dungeons`, `raids`, `raid_rules`, `roadmap`, `addons`, `addon_dev`: copy from the Priest/Mage data.json
  (race-independent facts keep the original source_url/checked). Human mount row from Andric's research.
- `change_sources`: copy the Priest list (feeds are game-wide) and add Paladin/PvP pages worth watching.
- `pvp`: object, see below.

### `pvp`
```
pvp: {
  summary: { text, source_url, checked },                       # PvP live since launch, season 1, rulesets, no arenas
  rulesets: [{ name, world_pvp, notes, source_url, checked }],   # Normal / PvP / RP / RP-PvP (+ Hardcore later)
  honor: { currency_name: "Honor", currency_id?: null, cap_note?, earn: [...], notes, source_url, checked },
  rank_points: { weekly_cap: true, decay: false, ranks: 14, notes, source_url, checked },
  ranks: [{ rank: 1..14, reward, source_url, checked }],          # Blizzard's reward table (R1 tabard ... R14 weapons)
  rank_titles?: [{ rank, alliance, horde, source_url, checked }], # only if a raw page lists them
  gear_path: { text, emboldened_seal: "...", source_url, checked },
  battlegrounds: [{ key: "wsg"|"ab"|"darkspear"|"av", name, size: "10v10", min_level, max_level, objective,
     alliance_queue: "...", portal?: "...", marks?: "...", rep_faction?: "...", vendor_note?, call_to_arms?: "...",
     roles: { Retribution: "...", Holy: "...", Protection: "..." },   # from the paladin PvP pages; unconfirmed if secondary
     unconfirmed?, flag?, source_url, checked }],
  queue: { text, remote_queue: false, source_url, checked },      # battlemasters: Stormwind Keep etc.
  call_to_arms: { text, source_url, checked },
  seasonal: { text, source_url, checked },                         # seasonal journey, Legacy Point, "For Great Honor"
  cooldowns: [{ spell, cooldown?: "45 s"|..., duration?: "6 s", forbearance?: true, spec?: "Retribution"|..., talent?: true,
     notes, unconfirmed?, flag?, source_url, checked }],          # HoJ, Repentance, Divine Shield, Divine Protection, BoP, BoF, Lay on Hands (20 min),
                                                                   # Templar's Bulwark (5 min), Holy Shock (10 s), PvP trinket (name/effect gap)
  forbearance: { text, duration?: null, source_url, checked },
  burst: { Retribution: [{ spell, note }], Holy: [{ spell, note }], Protection: [...], source_url, checked, unconfirmed?, flag? },
  roles: [{ spec, role, text, source_url, checked }],
  world_pvp_tips: [{ title, body, source_url, checked }],         # PvP ruleset: always flagged in contested zones, ganks while leveling
  limits: [{ what, why, source_url, checked }],                    # no combat log, secret values, chat lockdown in instances...
  not_in_addon: [{ feature, why }],                                # enemy trinket/DR tracking, kill announcer, BG callouts, Spy, auto-target healers
  pvp_addons: [{ name, purpose, forever_build: true|false, source_url, checked }],  # BetterBlizzPlates, Plater, Capping, BugSack; missing: Spy, OmniBar
  api_notes: [{ api, note, status: "documented"|"unverified", source_url, checked }]   # GetZonePVPInfo, C_PvP..., Cooldown Manager /cdm, ruleset API
}
```

## Merge
`python3 research/merge.py` (or by hand) merges `parts/core.json` + `parts/gear.json` into `data.json`
(keys from both; `gaps`/`conflicts`/`sources` concatenated/merged).
