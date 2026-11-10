# WoW Forever Paladin – research notes for Tristan's Addon (checked 2026-11-10, America/Chicago)

Raw copies of every page are in `raw/` (HTML + extracted .md). These notes are a starting summary, NOT a finished data.json.
Claude should build `research/data.json` (same shape as the priest/mage research: meta, spells, quests, builds, gear brackets,
consumables, reagents, riding, pvp, gaps, change_sources), every fact with `source_url` + `checked`, from these raw pages.
Removed from raw/: Icy Veins `*-pvp-guide` and `holy-paladin-healing-pve-guide` URLs (they returned Icy Veins' generic page = not found).

> **Update 2026-11-10 12:59 PM CT (Tim, final decisions):** Tristan is on a **PvP ruleset** realm. The Normal-ruleset inference below is superseded.

## Who: Tristan Ludlowe (facts from TUF, 2026-11-10)
- WTF folder `_forever_/WTF/Account/980903219#1/91/Tristan-Ludlowe/` created **2026-11-10 12:45 PM CT**, only `AddOns.txt` so far
  (AndricsAddon, ParzellesAddon, StoryTracker, Pawn, AMR, APLForever, Spoken*, DialogueUI, Ember, Plumber enabled). No SavedVariables yet,
  so no StoryTracker entry: **level, race, realm not readable from files yet**. Race/class (male Human Paladin, Alliance) come from Tim/Admin.
- Realm: the other "Tristan" in StoryTracker (`Tristan-CAMWOWUS2Realm1PvE`) is **Tristan Shadomane, a level-4 Night Elf Druid** (Nov 5) – not him.
  Inference only: `character-list-order.txt` has 12 characters in group 137 (= 11 known Realm1PvE characters + 1 new) and 1 in group 136
  (= Ruminant, the only `CAMWOWUS2Realm8PvP` character, Horde). So Tristan Ludlowe is **most likely on CAMWOWUS2Realm1PvE (Normal ruleset)**,
  like Andric and Parzelle. Confirm after his first logout (StoryTracker will write him) or ask Tim.
  Note: on the PvP ruleset you can only make one faction (Blizzard ruleset post), and Tim's PvP-ruleset character Ruminant is Horde, so an
  Alliance Tristan could not be on that same PvP ruleset anyway.

## WoW Forever now (Nov 10, 2026)
- Launched **Nov 4, 2026**. Level cap 60 (permanent). Raids open Dec 9 (from mage research).
- Rulesets replace realms: Normal, PvP, Roleplay, Roleplay PvP; Hardcore later. Battlegrounds mix all non-Hardcore rulesets; no
  cross-ruleset or cross-faction grouping (Blizzard ruleset post, updated 10-22).
- **PvP is live since launch, not a later phase.** Season 1 started with launch; Blizzard roadmap puts the first PvP season refresh in
  spring 2027 (lfcarry, secondary). Honor (currency: kills, BGs, PvP quests; holiday "Call to Arms" weeks give more) + Rank Points
  (BGs, PvP quests; **weekly cap**; 14 ranks to Grand Marshal; no decay). Character pane (C) › Player vs. Player tab shows rank,
  Rank Points and buyable rewards (Blizzard PvP post).
- Rank rewards (Blizzard): R1 tabard, R2 PvP trinket, R3 cloaks, R4 necklace, R5 combat potions, R6 tabard, R7 battle standard,
  R8 epic bracers/belt token, R9 boots, R10 gloves, R11 mounts, R12 legs/shoulders, R13 chest/helm, R14 weapons.
  Blue set for Honor; epic = blue piece + **Emboldened Seal** (rank-gated). Seasonal journey weekly tasks give Honor + Rank Points;
  3 per season give a Legacy Point (Legacy perk "For Great Honor" boosts Honor).
- Battlegrounds at launch (launch client per foreverdb/loreforever, secondary): **Warsong Gulch 10v10 (10–60), Arathi Basin 15v15 (20–60),
  Darkspear Islands 15v15 (30–60, new, Blizzard), Alterac Valley 40v40 (51–60)**. No arenas or rated BGs at launch. Queue at a capital
  battlemaster (no remote queue); Darkspear also via Alliance Theramore Expeditionary Force portal at Northwatch (Barrens).
  Marks of Honor per BG for rep quests; Darkspear rep vendors (Theramore Expeditionary Force) sell trinkets/rings/cloaks/weapons/armor.
  Unverified: honor cap 25,000 (beta Oct 1), weekly-cap table datamined, season ≥10 weeks, Battle for Gilneas disabled in client.
- Hotfixes Nov 9: Paladin Consecration damage fix; **Cooldown Manager now shows Seals correctly**; Plainsrunning can't stack in BG prep.

## Client / addon API (hard limits – shape PvP module)
- `omaforge clients` on TUF 2026-11-10: **Forever 1.60.1.70888, Interface 16001** (mage brief had build 70862). WOW_PROJECT_ID 18 (CAMELOT).
- Forever runs Midnight's addon "disarmament" (Blizzard rep in WoW UI Discord, Sep 15, via wowforevertierlist; no Forever-specific API list exists):
  - **No `COMBAT_LOG_EVENT` for addons**; Combat Log chat text unparseable → no kill-blow credit, no enemy cooldown/trinket tracking
    (OmniBar/Gladius-style), no DR tracker, no Spy-style detection from the log.
  - **Secret values** for other units' health %/missing, power, casts; aura *contents* are secret in combat (lists + UNIT_AURA still fire).
    Player's own casts (UNIT_SPELLCAST_* for "player"), max health/power of player units and secondary resources are readable.
    Secrets can be passed to StatusBar:SetValue / Cooldown widgets but not compared → e.g. "target under 20% for Hammer of Wrath" cannot be
    computed by addon code in combat; degrade to showing the spell's own usable/glow state if readable, else hide.
  - **In instances (likely incl. battlegrounds – unconfirmed)**: chat arrives as secrets and **addons may not send any chat/addon messages**;
    creature names/GUIDs secret. → No BG auto-callouts, no kill announcer, no addon-to-addon sync in BGs.
  - Secure snippets run out of combat only; casts only via secure buttons pressed by the player (one press = one cast).
  - Built-ins to point players at: Cooldown Manager (`/cdm`, Options › Gameplay Enhancement, off by default), swing timer
    (`C_SwingTimer`, `PLAYER_SWING`, off by default), PvP tab on Character pane. Ruleset detection API exists (wowforevertierlist; name TBD).
  - Lessons from Andric/Parzelle: secure buttons use `type=macro` + `/cast` macrotext (type=spell failed on Forever); no `/click`, no
    Bindings.xml; `SetOverrideBindingClick` per character out of combat; re-aim out of combat; `/targetexact` for strangers.
- Existing PvP addons with Forever builds (foreverbase Nov 5, secondary): BetterBlizzPlates or Plater (nameplates), Capping (BG timers),
  BugSack. Missing: Spy, OmniBar-style trackers, ClassicCastbars. Classic paladin staple PallyPower (blessing assignment, `/pp`, `/pallypower`)
  – idea source only, don't copy.

## Paladin baseline in Forever (Blizzard deep dive Oct 15 + dev notes Nov 2 = launch; foreverguide/endgametools summaries)
- Races: Alliance Human, Dwarf; Horde Undead (new). Talents from 10; gold medals at 11/16/21/31 points; respec at class trainer in a
  major city; Dual Spec at 40. Training ~206–207g total for all ranks 1–60.
- **Holy Strike** (new, lvl 6): instant Holy dmg, % weapon dmg per rank 25/29/32/36/39/43/46/50%; cooldown 10 s (was 12; Improved Holy
  Strike made baseline).
- **Judgement no longer consumes the Seal**; Judgements of Light/Wisdom/Crusader last 40 s (endgametools); Improved Blessing of Wisdom,
  Lasting Judgement, Improved SotC bonus baseline. Judgement is off the GCD (Icy Veins).
- **Seal of Fury** (new tank seal, lvl 10): flat Holy dmg per swing, absorb = 50% of it, Judgement of Fury taunts (10 yd), taunt now 3 s.
- **Righteous Fury** trained at 10 (was 16); +33% all threat, Holy threat bonus (Nov 2 says +90%; an earlier note says 60% – CONFLICT, launch=90%).
- **Consecration baseline at 20** (first 4 targets moderate dmg, rest very low). **Blessing of Kings baseline at 20**
  (10% stats, 1 h per foreverguide – verify duration). Blessing durations "1 hour" (Wisdom, Greater Blessings) are secondary claims – VERIFY.
- Removed at launch: **Blessing of Salvation/Salvation/Mass Salvation/Revoke, Blessing of Light (+Greater), Blessing of Sanctuary,
  Sanctity Aura, Improved Retribution Aura, Improved Concentration Aura, Voice of Truth, Twist of Light, Instrument of Law,
  Improved Seal of Fury, One-Handed Weapon Spec.** Classic seal twisting gone baseline.
- Resistance auras (Fire/Frost/Shadow) affect raid within 30 yd. Retribution Aura scales with spell power. **Lay on Hands CD 20 min.**
- Aura flyout on the action bar for Paladins (dev notes) – our aura UI must not fight it.
- Blizzard: Paladins have **no interrupt, no slow, limited range**; strong vs Undead/Demons.
- Milestones (Icy Veins Ret leveling): 10 Lay on Hands + Blessing of Protection; 12 Redemption quest; 20 Verigan's Fist quest, Consecration,
  Blessing of Kings; 22 Pursuit of Justice (talent); 30 Repentance (talent); 34 Divine Shield; 40 mount quest (speculative); 44 Hammer of Wrath;
  50 Holy Wrath. Divine Shield in Forever lets you keep attacking at −50% damage (Icy Veins). Divine Protection stops your attacks.
  Greater Blessing of Might 52, Wisdom 54, Kings 60 (foreverbattlegrounds, secondary – VERIFY).
- Class quests (Alliance, Icy Veins): 12 **The Tome of Divinity** (Redemption – do before groups); 20 **The Test of Righteousness**
  (Jordan Stilwell outside Ironforge 52,36; Deadmines/SFK/BFD; Verigan's Fist; realistic 22+); 22 **A Strange Artifact** (Althalaxx Orb,
  Darkshore 56.2,26.4) → Cloak of the Divine Storm. Mount quests 40/60: Icy Veins only speculates – GAP.
- Early weapons (Icy Veins): Ironforge Greathammer (Hall of Thanes, ~9), Deadmines hammers, Verigan's Fist, Manual Crowd Pummeler.

## Talents (launch)
- Holy: Holy Shock = 21-pt gold medal, 10 s CD; Divine Favor 16-pt; Light's Vigil 31-pt (healing only at launch); Oath of Light
  (row 4, one sworn ally 5 min); Boundless Light; Reverence (row 2, 2 pts); Infusion of Light; Illumination 50% refund; Divine Precision
  (2 pts, 4/8% Holy hit + −10/20% Silence duration); Spiritual Focus 5 pts; Improved Seals 5 pts; Purifying Power (Cleanse/Purify cost,
  Exorcism/Holy Wrath CD); Holy Power raises crit healing.
- Protection: Swift Judgement 16-pt; Templar's Bulwark 21-pt (absorb 100% max HP 8 s, 5 min, Forbearance; row 3, dispellable);
  Holy Shield needs Bulwark; Shieldsworn (capstone per Icy Veins; Holy Strike with shield, −4 s CD); Stoicism; Iron Creed; Shield Spec
  mana on block; Reckoning from blocks; Improved Hammer of Justice moved up to 10 points (build 70755); a Divine Shield/Protection/Bulwark
  CD talent (−60 s, Forbearance −10 s) – name in raw endgametools.
- Retribution: Sacred Arbiter 16-pt (Holy Strike +dmg, refreshes all Judgements incl. other Paladins'); Repentance 21-pt;
  **Unsealed Wrath 31-pt (needs Repentance)**: swings store echo of active Seal 15 s, up to 3; hit with a different Seal consumes them for
  one proc chance each = Forever's seal twisting; Vengeance 5 stacks, needs Seal of Command; Conviction 2/4/6% crit all; Champion of the
  Light 12–60% Int as spell dmg + Hammer of Wrath −0.2–1.0 s; Turn Evil; Two-Handed Weapon Spec +Holy/Physical and −threat;
  Sanctified Judgement; Pursuit of Justice; Unyielding Faith (fear/disorient reduction, moved from Holy).
- Archetypes (Icy Veins): Ret seal-twist (Unsealed Wrath) vs **Shockadin** (21 Holy for Holy Shock). Talent calculator data: Icy Veins
  calculator page is JS-only in raw (831 chars) – get tree data the same way as Andric/Parzelle (`research/talents_paladin.json`);
  foreverguide calculator (raw) also "uses the game client's data". Validate 51-point builds.

## Leveling (Icy Veins)
- Ret: "very efficient" leveler; Prot strong (AoE with Consecration + Retribution Aura, self-heals, easy dungeon groups); Holy slower but OK.
- Ret rotation: keep Blessing (Might → Kings at 20) + Seal; Judge SotC debuff first, then SoR/SoC; Judgement + Holy Strike on CD; HoJ/Repentance
  before Judgement with SoC; Consecration only when mana allows (8 s); Exorcism on Undead/Demons (30 yd pull tool); Hammer of Wrath <20%;
  don't refresh seal early, skip Judgement if the next swing kills; convert spare mana to Holy Light instead of drinking.
- Seal choice: SoC for slow 2H / low SP; SoR for fast weapons / high SP (SoR 12% SP per hit with 2H; SoC ~7 PPM, 20.3% SP).
- Stats Ret (leveling): weapon DPS > Hit & Expertise > Spell Power > Int > Crit > Str/AP > Agi.
- Professions: Mining+Blacksmithing (gear) or Herb+Alchemy; **Engineering grenades flagged as a strong PvP tool** for Paladins (no slows/gap closers).

## PvP – Paladin (secondary fansites, LOW-MEDIUM confidence; several are AI-written, verify every number in-game)
- Core tools: Hammer of Justice (stun, 10 yd, ~45–60 s CD, 6 s), Repentance (6 s incapacitate, 20 yd, 1 min), Blessing of Freedom
  (roots/slows; on a target it *replaces* your other Blessing from you), Blessing of Protection (physical immunity, Forbearance),
  Divine Shield/Divine Protection (Forbearance), Lay on Hands, Cleanse (poison, disease, magic) / Purify, Holy Shock (instant, 20 yd),
  Hammer of Wrath (execute, 30 yd, instant with Champion of the Light 5/5), Templar's Bulwark (Prot), Pursuit of Justice speed.
- Ret burst window: HoJ → Judgement (SoC, roughly double on stunned/incapacitated) → Holy Strike → (Repentance second window) → HoW finisher.
  With Unsealed Wrath: build echoes with SoC, swap Seal right before the stun.
- Holy BG healer: Oath of Light + Light's Vigil on flag carrier, Holy Shock on the move, Cleanse magic CC, Freedom on carrier, buff before gates.
- Roles by BG: Ret = attacker/flag hunter/roamer; Holy = healer/defender (foreverbattlegrounds ratings).
- DATA WARNINGS: foreverbattlegrounds Holy page still lists **Voice of Truth (removed at launch)**; thetirisfalen mentions
  "Hammer of the Righteous" (not a Forever Paladin spell in any primary source) and cites build-70707 calculator. Don't import those.

## Gaps to flag in-game (don't guess)
- Tristan's level/realm/ruleset until his SavedVariables exist; Blessing/Greater Blessing durations and levels; HoJ CD/duration; PvP
  trinket name/effect; Honor currency ID and the Lua API for rank/Rank Points/weekly cap (`C_PvP.*`, `GetPVPRankInfo`, `UnitPVPRank` –
  test each on Forever); whether BGs count as "instance" for chat lockdown; whether own-aura and own spell-cooldown reads are secret in combat;
  `IsSpellUsable`/overlay glow for Hammer of Wrath; Paladin mount quests 40/60; BiS until raids (Dec 9).
