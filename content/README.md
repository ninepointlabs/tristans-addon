# content/learn.json

Hand-written teaching and rotation content for **Learn the Paladin** and the **Rotation** tab (including its Seals & auras and Mana sub-tabs). `tools/build_data.py` turns it into `Data/Learn.lua`.

Rules (the weekly recheck must keep to them):

- Only facts from `research/data.json` or the archived pages behind it. Every entry lists `sources` (URLs).
- Anything not stated by a source, stated by only one third-party site, or conflicting between sources gets `"unconfirmed": true` and a short `"flag"`. The addon shows the flag in-game.
- Don't invent numbers (costs, coefficients, cooldowns, durations).
- Spell keys must match `data.json` names exactly (`spells_by_level[].name` without " (talent)"); talent keys match the talent names in `research/talents_paladin.json`.
- Never list removed-at-launch spells as current (Voice of Truth, Twist of Light, Blessing of Light, Blessing of Salvation, Blessing of Sanctuary, Sanctity Aura, Improved Retribution/Concentration Aura, Instrument of Law, Improved Seal of Fury, One-Handed Weapon Spec). Never mention "Hammer of the Righteous" as a spell.
- Alliance character: Horde-only content (Undead Paladin quests) belongs in data, not in lessons.

## Sections

`version`, `checked`, `spells`, `talents`, `mechanics`, `roles`, `leveling` (per spec), `mistakes`, `lessons` (unlock at `level`, optional `spec`, optional `"track": "pvp"`), `first_learn_hints`, `rotation`.

`mechanics[]` entries may carry `"topic": "mana"` (shown on Rotation › Mana) or `"topic": "seals"` (Rotation › Seals & auras).

Lessons with `"track": "pvp"` form the **PvP basics** track (Learn › PvP basics): Honor and Rank Points, world PvP on a PvP realm, battleground objectives, Forbearance timing, no interrupt or slow.

`rotation.<Holy|Protection|Retribution>.<solo|dungeon|raid>` = `{ summary, kind: "damage"|"healing", priority: [{spell, when, note}], tips, unconfirmed, flag, sources }`. Holy uses `kind: "healing"` (the on-screen helper shows a list).

`when` must be one the engine (`Modules/Rotation.lua`) understands:
`always`, `manual` (listed for reading, never suggested by the on-screen helper), `buff_missing`, `debuff_missing`, `ready`, `out_of_combat`, `in_combat`, `seal_missing`, `usable` (the game lights it up, e.g. Hammer of Wrath under 20%), `target_undead_or_demon`, `in_melee`, `mana_above:N`, `mana_below:N`, `target_hp_below:N`, `proc:<Buff name>`, `target_debuff_missing:<Debuff name>`, `stacks_below:<Aura>:N`, `stacks_at_least:<Aura>:N`. `tests/run.lua` fails if a step uses anything else or names a spell the research doesn't know.

After editing: `python3 tools/build_data.py && lua5.1 tests/run.lua`.
