-- Headless tests. Run from the repo root:  lua5.1 tests/run.lua
package.path = "./tests/?.lua;" .. package.path
local M = require("wow_mock")
M.Install()
local S = M.state

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 io.stderr:write("FAIL " .. name .. ": " .. tostring(err) .. "\n") end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function near(a, b, msg) if math.abs(a - b) > 1e-6 then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or "expected truthy", 2) end end
local function textHas(pattern)
    for _, t in ipairs(M.texts) do if t:find(pattern, 1, true) then return true end end
    return false
end

local ns = M.LoadAddon("TristansAddon_Forever.toc", ".")

-- Mark a spell as known by name (by research ID when there is one, else by name).
local function know(name)
    local id = ns.Rotation.SpellId(name)
    if id then S.known[id] = true end
    S.knownNames[name] = true
end
local function forget()
    S.known, S.knownNames = {}, {}
end

local function renderAll(label)
    for _, key in ipairs(ns.PanelOrder) do
        M.texts = {}
        ns.UI.Open(key)
        for _, t in ipairs(M.texts) do
            if t:find("This panel hit an error", 1, true) then error(label .. "/" .. key .. ": " .. t) end
        end
    end
end

local SUBS = {
    leveling = { "Path", "Zones & dungeons", "Trainer", "Class quests", "Riding & gold" },
    gear = { "For my level", "Best overall", "By bracket", "Consumables", "Weights" },
    settings = { "General", "Paladin bar", "Tooltips & bags", "Reminders", "About the data", "About" },
    learn = { "Lessons", "Spells", "Talents", "How the class works", "In a group", "PvP basics", "Leveling", "Common mistakes" },
    rotation = { "Solo", "Dungeon", "Raid", "Seals & auras", "Mana" },
    battle = { "Honor & Rank", "Battlegrounds", "PvP bar", "Cooldowns", "Burst coach", "World PvP" },
}
local function renderSubs(label)
    for key, list in pairs(SUBS) do
        for _, sub in ipairs(list) do
            M.texts = {}
            ns.UI.Open(key, sub)
            for _, t in ipairs(M.texts) do
                if t:find("This panel hit an error", 1, true) then error(label .. "/" .. key .. "/" .. sub .. ": " .. t) end
            end
        end
    end
    ns.UI.Open("rotation", "Solo")
end


test("toc files match between plain and _Forever", function()
    local a, b = io.open("TristansAddon.toc"):read("*a"), io.open("TristansAddon_Forever.toc"):read("*a")
    eq(a, b)
    truthy(a:find("## Interface: 16001", 1, true), "interface")
    truthy(a:find("## X-Website: https://github.com/ninepointlabs/tristans-addon", 1, true), "website")
    truthy(a:find("## Title: Tristan's Addon", 1, true), "title")
    truthy(a:find("## SavedVariables: TristansAddonDB", 1, true), "saved variables")
    truthy(a:find("## SavedVariablesPerCharacter: TristansAddonCharDB", 1, true), "per-character saved variables")
    -- every listed file exists; no Bindings.xml
    for line in a:gmatch("[^\n]+") do
        if not line:match("^##") and line:match("%S") then truthy(io.open((line:gsub("\\", "/"))), "missing " .. line) end
    end
    eq(io.open("Bindings.xml"), nil, "no Bindings.xml")
end)

test("no leftover Andric/Parzelle/Mage globals or code", function()
    for _, f in ipairs({ "Core/Boot.lua", "Core/DB.lua", "Core/Init.lua", "UI/Main.lua", "UI/BlessingButton.lua", "UI/PaladinBar.lua", "UI/PvPBar.lua", "UI/Hints.lua" }) do
        local s = io.open(f):read("*a")
        truthy(not s:find("Parzelle", 1, true) and not s:find("Andric", 1, true) and not s:find("isMage", 1, true), f)
    end
end)

test("generated data present", function()
    truthy(#ns.Data.Spells >= 40, "spells")
    for _, spec in ipairs(ns.SPEC_ORDER) do
        truthy(ns.Data.Learn and ns.Data.Learn.rotation and ns.Data.Learn.rotation[spec] and ns.Data.Learn.rotation[spec].solo, "learn rotation " .. spec)
        truthy(ns.Data.StatPriority[spec], "stat priority " .. spec)
    end
    eq(ns.Data.Meta.toc_interface, 16001)
    eq(ns.Data.Meta.class, "Paladin")
    truthy(ns.Rotation.SpellId("Holy Strike"), "Holy Strike id")
    truthy(ns.Rotation.SpellId("Blessing of Might"), "Blessing of Might id")
    eq(#ns.Data.PvP.battlegrounds, 4, "four launch battlegrounds")
    eq(#ns.Data.PvP.ranks, 14, "14 ranks")
    -- removed-at-launch spells never appear as spells
    for _, s in ipairs(ns.Data.Spells) do
        for _, bad in ipairs({ "Voice of Truth", "Twist of Light", "Blessing of Light", "Blessing of Salvation", "Blessing of Sanctuary", "Sanctity Aura", "Hammer of the Righteous" }) do
            truthy(not s.name:find(bad, 1, true), "removed spell imported: " .. s.name)
        end
    end
end)

-- Login: Tristan, level 1, no talents, no spec.
S.level = 1
M.Fire("ADDON_LOADED", "TristansAddon")
M.Fire("PLAYER_LOGIN")
M.RunTimers()

test("login creates profile A/B with no spec", function()
    truthy(ns.db and ns.db.char.profiles.A and ns.db.char.profiles.B)
    eq(ns.DB.ActiveSpec(), nil)
    truthy(SlashCmdList.TRISTANSADDON, "slash")
    eq(SLASH_TRISTANSADDON1, "/tristan")
    eq(SLASH_TRISTANSADDON2, "/paladin")
    eq(ns.isPaladin, true)
    eq(ns.Progress.PlayerRace(), "Human")
    eq(ns.RECOMMENDED_LEVELING_SPEC, "Retribution")
end)

test("level 1, no talents, no spec: every screen renders and the picker recommends Retribution", function()
    S.level = 1
    renderAll("no spec")
    renderSubs("no spec")
    M.texts = {}
    ns.UI.ShowPicker()
    truthy(textHas("talents start at 10"), "picker explains no talents yet")
    truthy(textHas("recommended for leveling"), "recommended badge")
    truthy(textHas("level as Retribution"), "Retribution for leveling")
    truthy(textHas("Retribution (A) + Holy (B)"), "dual spec plan")
    M.texts = {}
    ns.UI.Open("home")
    truthy(textHas("No talents yet"), "home nudge")
    M.texts = {}
    ns.UI.Open("talents")
    truthy(textHas("Pick a spec first"))
end)

test("DB.Init keeps saved values and fills defaults", function()
    local acc, ch = ns.DB.Init({ percentScale = 14 }, { active = "B", profiles = { B = { spec = "Holy" } } })
    eq(acc.percentScale, 14)
    eq(ch.active, "B")
    eq(ch.profiles.B.spec, "Holy")
    eq(ch.profiles.A.rotationContext, "solo")
    eq(ch.profiles.A.pvpWeights, false)
    eq(ch.blessing.key, nil, "no key bound by default")
    eq(next(ch.pvpBar.keys), nil, "no PvP bar keys by default")
    eq(ch.pvp.ruleset, "PvP", "Tristan's realm is a PvP ruleset")
    ns.DB.Init(TristansAddonDB, TristansAddonCharDB)
end)

test("stat parsing: melee, caster and tank lines", function()
    local raw = ns.Stats.ParseLines({
        "Hammer of Testing", "+12 Strength", "+5 Agility", "+7 Intellect", "+5 Spirit", "+9 Stamina", "512 Armor", "24 Block",
        "Equip: Improves your chance to hit by 1%.", "Equip: Improves your chance to get a critical strike by 2%.",
        "Equip: +28 Attack Power.", "Equip: Increased Defense +7.", "Equip: Increases your chance to dodge an attack by 1%.",
        "Equip: Increases your chance to block attacks with a shield by 2%.", "Equip: Increases the block value of your shield by 10.",
        "Equip: Increases damage and healing done by magical spells and effects by up to 12.",
        "Equip: Increases damage done by Holy spells and effects by up to 6.",
        "Equip: Increases healing done by magical spells and effects by up to 20.",
        "Equip: Improves your chance to get a critical strike with spells by 1%.",
        "Equip: Restores 3 mana per 5 sec.", "(42.5 damage per second)",
        "(2) Set: +10 Strength", "Use: Restores 375 mana.",
    })
    eq(raw.STR, 12); eq(raw.AGI, 5); eq(raw.INT, 7); eq(raw.STA, 9); eq(raw.ARMOR, 512); eq(raw.BLOCK_VALUE, 34)
    eq(raw.HIT, 1); eq(raw.CRIT, 2); eq(raw.AP, 28); eq(raw.DEFENSE, 7); eq(raw.DODGE, 1); eq(raw.BLOCK, 2)
    eq(raw.SPELL_POWER, 12); eq(raw.HOLY_DAMAGE, 6); eq(raw.HEALING, 20); eq(raw.SPELL_CRIT, 1); eq(raw.MP5, 3); eq(raw.WEAPON_DPS, 42.5)
    local d = ns.Stats.Derive(raw, "Retribution")
    eq(d.DAMAGE, 18, "spell power + Holy damage"); eq(d.HEALING, 32, "healing + damage-and-healing")
end)

-- Item fixtures
local NEW, OLD, RING1, RING2, DAGGER, MACE2H, PLATE = "item:1001", "item:1002", "item:1003", "item:1004", "item:1005", "item:1007", "item:1008"
S.itemInfo[1001] = { equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 3 }
S.itemInfo[1002] = { equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 3 }
S.itemInfo[1003] = { equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0 }
S.itemInfo[1004] = { equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0 }
S.itemInfo[1005] = { equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 15 }
S.itemInfo[1007] = { equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 5 }
S.itemInfo[1008] = { equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 4 }
S.itemLines[NEW] = { "New", "+10 Strength", "+6 Stamina" }
S.itemLines[OLD] = { "Old", "+4 Strength" }
S.itemLines[RING1] = { "R1", "+3 Strength" }
S.itemLines[RING2] = { "R2", "+8 Strength" }
S.itemLines[DAGGER] = { "Dagger", "+5 Strength" }
S.itemLines[MACE2H] = { "Mace", "+15 Strength", "(30.0 damage per second)" }
S.itemLines[PLATE] = { "Plate", "+20 Stamina" }
S.equipped[5] = OLD
S.equipped[11] = RING1
S.equipped[12] = RING2

test("compare: Paladins use plate, maces and two-handers, not daggers", function()
    ns.Stats.ClearCache()
    local ret = ns.Stats.Compare(NEW, "Retribution", 30, {}, 10)
    truthy(ret.delta > 0, "strength chest is a Ret upgrade")
    eq(ns.Stats.Compare(DAGGER, "Retribution", 30, {}, 10).unusable, true, "no daggers")
    truthy(not ns.Stats.Compare(MACE2H, "Retribution", 30, {}, 10).unusable, "two-handed maces")
    truthy(not ns.Stats.Compare(PLATE, "Protection", 40, {}, 10).unusable, "plate")
    local res = ns.Stats.Compare(MACE2H, "Retribution", 30, {}, 10)
    eq(res.isWeapon, true)
end)

test("PvP weight profile puts Stamina on top", function()
    local base = ns.Stats.Weights("Retribution", 10, nil, false)
    local pvp = ns.Stats.Weights("Retribution", 10, nil, true)
    eq(pvp.STA, 1)
    truthy((base.STA or 0) < 1, "not top without PvP")
    ns.Stats.ClearCache()
    local a = ns.Stats.Compare(PLATE, "Retribution", 40, { pvpWeights = false }, 10)
    ns.Stats.ClearCache()
    local b = ns.Stats.Compare(PLATE, "Retribution", 40, { pvpWeights = true }, 10)
    truthy(b.score > a.score, "stamina plate scores higher with PvP weights")
end)

test("tooltip lines", function()
    ns.Stats.ClearCache()
    local all = table.concat(ns.Tooltip.LinesFor(NEW, "Retribution", {}, 30, 10), "\n")
    truthy(all:find("Strength", 1, true), all)
    truthy(all:find("addon assumption", 1, true))
    truthy(M.tooltipHook, "tooltip hook installed via TooltipDataProcessor")
    all = table.concat(ns.Tooltip.LinesFor(DAGGER, "Retribution", {}, 30, 10), "\n")
    truthy(all:find("Paladins can't use this", 1, true))
    all = table.concat(ns.Tooltip.LinesFor(NEW, "Retribution", { pvpWeights = true }, 30, 10), "\n")
    truthy(all:find("PvP", 1, true), "PvP weights named")
end)

test("training: faction and talent filtering", function()
    for lvl = 1, 60 do
        for _, e in ipairs(ns.Training.At(lvl, "Retribution", "Alliance")) do
            truthy(e.spell.faction ~= "Horde", "no Horde spell for Alliance: " .. e.spell.name)
            if e.spell.talent then eq(e.spell.talent_tree, "Retribution", "only Ret talent spells for Ret: " .. e.spell.name) end
        end
    end
    truthy(ns.Training.NextLevel(1, "Retribution"), "a next trainer level after 1")
    eq(ns.Training.NextLevel(60, "Retribution"), nil)
end)

test("quests: Human Alliance paladin sees Tome of Divinity, never the Undead quests", function()
    local list = ns.Progress.ClassQuests("Human", "Alliance")
    local tome = false
    for _, q in ipairs(list) do
        if q.name == "The Tome of Divinity" then tome = true eq(q.level, 12) end
        truthy(q.faction ~= "Horde", "no Horde quest: " .. q.name)
    end
    truthy(tome, "The Tome of Divinity listed")
    truthy(ns.Progress.NextClassQuest("Human", "Alliance", 1), "next class quest at level 1")
    -- Horde quests exist in the data but stay hidden
    local horde = 0
    for _, q in ipairs(ns.Data.Quests) do if q.faction == "Horde" then horde = horde + 1 end end
    truthy(horde > 0, "research has Undead quests")
    M.texts = {}
    ns.UI.Open("leveling", "Class quests")
    truthy(not textHas("A Lesson in Divinity"), "Undead quest hidden")
end)

test("gold goals from research", function()
    local g = ns.Progress.GoldGoals()
    eq(g[1].level, 40)
    truthy(g[1].gold > 0)
end)

-- Rotation engine with a fake state
local function fakeState(o)
    return {
        inCombat = function() return o.combat or false end,
        hasTarget = function() return o.target ~= false end,
        spellName = function(n) return n end,
        playerBuff = function(n) return o.buffs and o.buffs[n] or false end,
        playerDebuff = function(n) return o.debuffs and o.debuffs[n] or false end,
        playerStacks = function(n) return o.stacks and o.stacks[n] or 0 end,
        targetDebuff = function(n) return o.tdebuffs and o.tdebuffs[n] or false end,
        cooldown = function(n) return o.cds and o.cds[n] or 0 end,
        manaPct = function() return o.mana or 100 end,
        targetHpPct = function() return o.hp or 100 end,
        known = function(n) return o.known == nil or o.known[n] == true end,
        anySeal = function() if o.seal == nil then return false end return o.seal end,
        usable = function(n) return o.usable and o.usable[n] or false end,
        creatureType = function() return o.ctype or "Humanoid" end,
        inMelee = function() return o.melee ~= false end,
    }
end

test("rotation: every step uses a supported condition and a researched spell", function()
    for spec, ctxs in pairs(ns.Data.Learn.rotation) do
        for ctxName, ctx in pairs(ctxs) do
            truthy(#ctx.priority > 0, spec .. "/" .. ctxName .. " empty")
            for _, step in ipairs(ctx.priority) do
                local r = ns.Rotation.Check(step, fakeState({}))
                truthy(r ~= nil, ("%s/%s: condition %s unsupported"):format(spec, ctxName, tostring(step.when)))
                truthy(ns.Rotation.IsKnownName(step.spell), ("%s/%s: unknown spell %s"):format(spec, ctxName, step.spell))
            end
        end
    end
end)

test("rotation: paladin conditions", function()
    local C = ns.Rotation.Check
    eq(C({ spell = "Seal of Righteousness", when = "seal_missing" }, fakeState({})), true)
    eq(C({ spell = "Seal of Righteousness", when = "seal_missing" }, fakeState({ seal = "Seal of Command" })), false)
    eq(C({ spell = "Exorcism", when = "target_undead_or_demon" }, fakeState({ ctype = "Undead" })), true)
    eq(C({ spell = "Exorcism", when = "target_undead_or_demon" }, fakeState({ ctype = "Beast" })), false)
    eq(C({ spell = "Hammer of Wrath", when = "usable" }, fakeState({ usable = { ["Hammer of Wrath"] = true } })), true)
    eq(C({ spell = "Hammer of Wrath", when = "usable" }, fakeState({})), false)
    eq(C({ spell = "Seal of the Crusader", when = "target_debuff_missing:Judgement of the Crusader" }, fakeState({})), true)
    eq(C({ spell = "Seal of the Crusader", when = "target_debuff_missing:Judgement of the Crusader" }, fakeState({ tdebuffs = { ["Judgement of the Crusader"] = true } })), false)
    eq(C({ spell = "Seal of Command", when = "stacks_at_least:Unsealed Wrath:3" }, fakeState({ stacks = { ["Unsealed Wrath"] = 3 } })), true)
    eq(C({ spell = "Consecration", when = "mana_above:40" }, fakeState({ mana = 30 })), false)
    eq(C({ spell = "Seal of the Crusader", when = "target_debuff_missing:Judgement of the Crusader" }, fakeState({ buffs = { ["Seal of the Crusader"] = true } })), false, "running Seal not re-suggested")
    eq(C({ spell = "Consecration", when = "manual" }, fakeState({})), false)
end)

test("rotation shows only spells usable at your level (level 1 Ret)", function()
    local savedLevel = S.level
    S.level = 1
    forget()
    know("Seal of Righteousness"); know("Holy Light"); know("Devotion Aura")
    eq(ns.Rotation.Availability("Seal of Righteousness", 1, "Human", "Alliance"), "known")
    eq(ns.Rotation.Availability("Judgement", 1, "Human", "Alliance"), nil, "Judgement not before its level")
    eq(ns.Rotation.Availability("Judgement", 4, "Human", "Alliance"), "trainable", "Train it at 4")
    eq(ns.Rotation.Availability("Repentance", 30, "Human", "Alliance"), nil, "talent not taken")
    for _, sp in ipairs(ns.Data.Spells) do
        if sp.faction == "Horde" then eq(ns.Rotation.Availability(sp.name, 60, "Human", "Alliance"), nil, sp.name) end
    end
    ns.DB.SetSpec("Retribution")
    ns.DB.Profile().rotationContext = "solo"
    M.texts = {}
    ns.UI.Open("rotation", "Solo")
    truthy(not textHas(". Hammer of Wrath"), "Hammer of Wrath hidden at 1")
    truthy(textHas("unlock with levels or talents"))
    forget()
    S.level = savedLevel
end)

test("paladin state: aura, seal and blessing recommendations", function()
    local P = ns.Paladin
    local all = function() return true end
    eq(P.RecommendedAura({ spec = "Retribution", inGroup = false }, all), "Devotion Aura")
    eq(P.RecommendedAura({ spec = "Retribution", inGroup = true }, all), "Retribution Aura")
    eq(P.RecommendedAura({ spec = "Holy", inPvP = true }, all), "Concentration Aura")
    eq(P.RecommendedAura({ spec = "Holy", inPvP = false }, all), "Devotion Aura")
    eq(P.RecommendedAura({ spec = "Holy", override = "Shadow Resistance Aura" }, all), "Shadow Resistance Aura")
    eq(P.RecommendedSeal({ spec = "Protection" }, all), "Seal of Fury")
    eq(P.RecommendedSeal({ spec = "Holy" }, all), "Seal of Wisdom")
    eq(P.RecommendedSeal({ spec = "Retribution", targetHasCrusader = false }, all), "Seal of the Crusader")
    eq(P.RecommendedSeal({ spec = "Retribution", targetHasCrusader = true, weaponSpeed = 3.6 }, all), "Seal of Command")
    eq(P.RecommendedSeal({ spec = "Retribution", targetHasCrusader = true, weaponSpeed = 2.6 }, all), "Seal of Righteousness")
    local onlySoR = function(n) return n == "Seal of Righteousness" end
    eq(P.RecommendedSeal({ spec = "Retribution", weaponSpeed = 3.6 }, onlySoR), "Seal of Righteousness", "level 1: SoR only")
    -- Blessing choice by class
    local B = ns.Blessing.ChoiceForClass
    local cfg = { byClass = {}, kingsForAll = false }
    eq(B("WARRIOR", all, cfg), "Blessing of Might")
    eq(B("HUNTER", all, cfg), "Blessing of Might")
    eq(B("MAGE", all, cfg), "Blessing of Wisdom")
    eq(B("PRIEST", all, cfg), "Blessing of Wisdom")
    eq(B("PALADIN", all, cfg, true, "Retribution"), "Blessing of Might", "self as Ret")
    eq(B("PALADIN", all, cfg, true, "Holy"), "Blessing of Wisdom", "self as Holy")
    cfg.kingsForAll = true
    eq(B("WARRIOR", all, cfg), "Blessing of Kings")
    eq(B("WARRIOR", function(n) return n ~= "Blessing of Kings" end, cfg), "Blessing of Might", "Kings not known yet")
    cfg.byClass.WARRIOR = "Wisdom"
    eq(B("WARRIOR", all, cfg), "Blessing of Wisdom", "per-class override wins")
    eq(B("ROGUE", function(n) return n == "Blessing of Might" end, { byClass = {} }), "Blessing of Might")
    eq(B("MAGE", function(n) return n == "Blessing of Might" end, { byClass = {} }), "Blessing of Might", "falls back to what you know")
end)

test("blessing button: next player missing YOUR blessing, class-smart, Freedom skip, combat freeze", function()
    forget()
    eq(ns.Blessing.ShouldShow(), false, "hidden until you know a Blessing")
    know("Blessing of Might"); know("Blessing of Wisdom")
    S.auras["Blessing of Might"] = true -- you're blessed
    S.target = false
    S.units = {
        party1 = { guid = "G1", name = "Brann", player = true, friend = true, range = true, class = "WARRIOR", buffs = {} },
        party2 = { guid = "G2", name = "Tilly", player = true, friend = true, range = true, class = "PRIEST", buffs = {} },
        party3 = { guid = "G3", name = "Far", player = true, friend = true, range = false, class = "MAGE", buffs = {} },
    }
    ns.Blessing.Refresh()
    local b = _G.TristansBlessingButton
    truthy(b, "button exists")
    eq(b:GetAttribute("type"), "macro")
    eq(b:GetAttribute("macrotext"), "/cast [@party1,help,nodead] Blessing of Might", "warrior gets Might")
    eq(b:GetAttribute("useOnKeyDown"), nil, "acts on release")
    truthy(ns.PaladinBar.Shown().blessing, "on the Paladin bar")
    S.units.party1.buffs["Blessing of Might"] = true
    ns.Blessing.Update()
    eq(b:GetAttribute("macrotext"), "/cast [@party2,help,nodead] Blessing of Wisdom", "priest gets Wisdom")
    -- Freedom on the priest: skip (casting Wisdom would replace it)
    S.units.party2.buffs["Blessing of Freedom"] = true
    ns.Blessing.Update()
    eq(b:GetAttribute("type"), nil, "nobody to bless -> disarmed")
    truthy(b.reason:find("Freedom", 1, true) or b.reason:find("out of range", 1, true), b.reason)
    S.units.party2.buffs = {}
    ns.Blessing.Update()
    eq(b:GetAttribute("macrotext"), "/cast [@party2,help,nodead] Blessing of Wisdom", "offered again after Freedom ends")
    -- combat: keeps its target
    S.combat = true
    S.units.party2.buffs["Blessing of Wisdom"] = true
    ns.Blessing.Update()
    truthy(b:GetAttribute("macrotext"):find("@party2", 1, true), "doesn't re-aim in combat")
    S.combat = false
    -- strangers by name
    eq(ns.Blessing.MacroText("nameplate3", "Zed", true, "Blessing of Might"), "/targetexact Zed\n/cast [@target,help,nodead] Blessing of Might\n/targetlasttarget")
    -- key: none by default, Super refused, override click
    eq(ns.db.char.blessing.key, nil)
    S.meta = true
    eq(ns.PaladinBar.KeyString("F"), nil, "Super/Meta combos refused (Omarchy)")
    S.meta = false
    ns.Blessing.SetKey("ALT-B")
    eq(M.overrides["ALT-B"], "TristansBlessingButton:LeftButton")
    ns.Blessing.SetKey(nil)
    S.combat = true
    ns.Blessing.SetKey("G")
    eq(ns.db.char.blessing.key, nil, "can't rebind in combat")
    S.combat = false
    ns.Blessing.StartKeyCapture()
    local cap = _G.TristansKeyCapture
    cap.__scripts.OnKeyDown(cap, "G")
    eq(ns.db.char.blessing.key, "G", "captured key saved")
    ns.Blessing.SetKey(nil)
    ns.Blessing.Debug()
    for _, m in ipairs(M.macros) do error("no macros may be created: " .. m.name) end
    S.units, S.auras, S.target = {}, {}, true
    forget()
end)

test("greater blessing only in a raid, known, 3+ of a class", function()
    local pick = { spell = "Blessing of Might", order = 1, classNeed = 3 }
    local all = function() return true end
    eq(ns.Blessing.SpellFor(pick, all), "Blessing of Might", "not in a raid")
    local realRaid = IsInRaid
    IsInRaid = function() return true end
    eq(ns.Blessing.SpellFor(pick, all), "Greater Blessing of Might")
    eq(ns.Blessing.SpellFor(pick, function(n) return not n:find("Greater") end), "Blessing of Might", "Greater not known")
    pick.classNeed = 2
    eq(ns.Blessing.SpellFor(pick, all), "Blessing of Might", "only 2 need it")
    IsInRaid = realRaid
end)

test("aura and seal hint cells: hints, not secure buttons", function()
    local st = { recAura = "Devotion Aura", aura = false, recSeal = "Seal of Command", seal = false, inMelee = true, spec = "Retribution" }
    local av = ns.Hints.AuraView(st)
    eq(av.active, true, "no aura -> glow")
    st.aura = "Devotion Aura"
    eq(ns.Hints.AuraView(st).ok, true)
    st.aura = nil
    truthy(ns.Hints.AuraView(st).status:find("hidden", 1, true), "hidden aura state")
    local sv = ns.Hints.SealView(st, 3, true)
    truthy(sv.sub:find("swap", 1, true), "Unsealed Wrath at 3 echoes: swap")
    truthy(ns.Hints.SealView(st, nil, true).sub:find("hidden", 1, true), "echo hidden")
    forget()
    know("Devotion Aura"); know("Seal of Righteousness"); know("Blessing of Might")
    ns.DB.SetSpec("Retribution")
    ns.Hints.Refresh()
    local shown = ns.PaladinBar.Shown()
    truthy(shown.aura and shown.seal, "aura and seal cells on the bar")
    forget()
end)

test("PvP bar: secure /cast macrotext buttons, picked ally, keys optional", function()
    local def = ns.PvPBar.BUTTONS
    local byKey = {}
    for _, d in ipairs(def) do byKey[d.key] = d end
    eq(ns.PvPBar.MacroText(byKey.freedom, "Blessing of Freedom", "party2"),
        "/cast [@mouseover,help,nodead][@focus,help,nodead][@party2,help,nodead][@player] Blessing of Freedom")
    eq(ns.PvPBar.MacroText(byKey.cleanse, "Cleanse"), "/cast [@mouseover,help,nodead][@focus,help,nodead][@player] Cleanse")
    eq(ns.PvPBar.MacroText(byKey.protection, "Blessing of Protection", nil), "/cast [@mouseover,help,nodead][@focus,help,nodead] Blessing of Protection")
    eq(ns.PvPBar.MacroText(byKey.stun, "Hammer of Justice"), "/cast [mod:shift,@focus,harm,nodead] Hammer of Justice; [@target,harm,nodead] Hammer of Justice")
    eq(ns.PvPBar.Spell(byKey.cleanse, function(n) return n == "Purify" end), "Purify", "Purify until Cleanse")
    forget()
    know("Blessing of Freedom"); know("Hammer of Justice"); know("Purify")
    S.units = { party1 = { guid = "G1", name = "Carrier", player = true, friend = true, class = "WARRIOR", buffs = {} } }
    ns.db.char.pvpBar.show = "always"
    ns.PvPBar.SetAlly("Carrier")
    ns.PvPBar.Refresh()
    local f = _G.TristansPvP_freedom
    eq(f:GetAttribute("type"), "macro")
    truthy(f:GetAttribute("macrotext"):find("[@party1,help,nodead]", 1, true), "picked ally resolved to a unit")
    eq(_G.TristansPvP_stun:GetAttribute("macrotext"), "/cast [mod:shift,@focus,harm,nodead] Hammer of Justice; [@target,harm,nodead] Hammer of Justice")
    truthy(ns.PvPBar.Shown().freedom and ns.PvPBar.Shown().stun and ns.PvPBar.Shown().cleanse, "known buttons shown")
    truthy(not ns.PvPBar.Shown().repentance, "Repentance hidden until talented")
    -- combat freeze
    S.combat = true
    S.units = {}
    ns.PvPBar.Refresh()
    truthy(f:GetAttribute("macrotext"):find("party1", 1, true), "doesn't change in combat")
    S.combat = false
    -- "In PvP" mode on a Normal realm, not flagged: hidden
    ns.db.char.pvpBar.show = "pvp"
    ns.db.char.pvp.ruleset = "Normal"
    eq(ns.PvPBar.Wanted(), false)
    S.flagged = true
    eq(ns.PvPBar.Wanted(), true, "flagged -> shown")
    S.flagged = false
    ns.db.char.pvp.ruleset = "PvP"
    eq(ns.PvPBar.Wanted(), true, "PvP realm -> shown")
    -- keys
    ns.PvPBar.SetKey("stun", "SHIFT-Q")
    eq(M.overrides["SHIFT-Q"], "TristansPvP_stun:LeftButton")
    ns.PvPBar.SetKey("stun", nil)
    ns.PvPBar.SetAlly(nil)
    for _, m in ipairs(M.macros) do error("no macros may be created: " .. m.name) end
    forget()
end)

test("cooldowns, Forbearance and the burst coach (own casts only)", function()
    forget()
    know("Hammer of Justice"); know("Divine Shield"); know("Judgement"); know("Holy Strike")
    S.cooldowns = { ["Divine Shield"] = 120 }
    local list = ns.Cooldowns.List()
    local byName = {}
    for _, e in ipairs(list) do byName[e.spell] = e end
    truthy(byName["Hammer of Justice"], "HoJ listed")
    truthy(not byName["Repentance"], "unknown talent not listed")
    S.auras = { Forbearance = { expirationTime = 1030 } }
    truthy(ns.Cooldowns.ForbearanceText():find("30s", 1, true), ns.Cooldowns.ForbearanceText())
    S.auras = {}
    eq(ns.Cooldowns.ForbearanceText(), nil)
    -- Coach
    ns.DB.SetSpec("Retribution")
    local steps = ns.Cooldowns.Steps("Retribution")
    truthy(#steps >= 3, "Ret burst steps from research")
    ns.Cooldowns.ResetCoach()
    local state = { known = function(n) return n ~= "Repentance" and n ~= "Hammer of Wrath" and n ~= "Blessing of Freedom" end, cooldown = function() return 0 end }
    local v = ns.Cooldowns.Coach("Retribution", state, 1000)
    truthy(v.next, "a next step")
    local first = v.steps[v.next].spell
    S.spellNames = { [4242] = first }
    ns.Cooldowns.OnCast(4242, 1000)
    local v2 = ns.Cooldowns.Coach("Retribution", state, 1001)
    truthy(v2.steps[v.next].done, "cast step marked done")
    truthy(v2.next ~= v.next, "coach moves on")
    local v3 = ns.Cooldowns.Coach("Retribution", state, 1000 + ns.Cooldowns.WINDOW + 1)
    truthy(not v3.steps[v.next].done, "window resets")
    S.spellNames, S.cooldowns = nil, {}
    forget()
end)

test("PvP data layer: rank, honor, zone, probes", function()
    S.pvpRankId = 7
    local r = ns.PvP.Rank()
    eq(r.rank, 3)
    eq(ns.PvP.NextReward(3).rank, 4)
    S.currencies = { { name = "Honor", quantity = 1234, maxQuantity = 0, iconFileID = 1 } }
    eq(ns.PvP.Honor().amount, 1234)
    S.currencies = nil
    eq(ns.PvP.Honor(), nil)
    S.zonePvP = "contested"
    eq(ns.PvP.Zone().kind, "contested")
    S.zonePvP = nil
    eq(ns.PvP.Zone().kind, "none")
    local probes = ns.PvP.RunProbes()
    eq(probes.UnitPVPRank.status, "ok")
    eq(probes.GetPVPRankProgress.status, "missing")
    eq(ns.PvP.BGOpen({ min_level = 10, max_level = 60 }, 9), false)
    eq(ns.PvP.BGOpen({ min_level = 10, max_level = 60 }, 10), true)
    S.pvpRankId = nil
end)

test("world PvP notice on a PvP realm, quiet on Normal", function()
    local toasts = {}
    ns.On("TOAST", function(t) table.insert(toasts, t) end)
    S.zonePvP = "friendly"
    ns.PvP.OnZoneChanged()
    S.zonePvP = "contested"
    ns.PvP.OnZoneChanged()
    eq(#toasts, 1, "contested zone toast")
    S.zonePvP = "friendly"
    ns.PvP.OnZoneChanged()
    ns.db.char.pvp.ruleset = "Normal"
    S.zonePvP = "hostile"
    ns.PvP.OnZoneChanged()
    eq(#toasts, 1, "quiet on Normal")
    ns.db.char.pvp.ruleset = "PvP"
    S.zonePvP = nil
end)

test("level 30 Retribution in a battleground with secret values: everything renders, hidden not guessed", function()
    S.level = 30
    forget()
    for _, n in ipairs({ "Seal of Righteousness", "Seal of the Crusader", "Judgement", "Holy Strike", "Hammer of Justice", "Blessing of Might",
        "Blessing of Freedom", "Blessing of Protection", "Devotion Aura", "Retribution Aura", "Consecration", "Exorcism", "Purify", "Lay on Hands" }) do know(n) end
    ns.DB.SetSpec("Retribution")
    S.instanceType = "pvp"
    S.combat = true
    M.InstallSecrets()
    S.secretMode, S.secretCooldowns = true, true
    eq(ns.PvP.InBattleground(), true)
    eq(ns.Auras.HealthPct("target"), nil, "target health secret -> unknown")
    eq(ns.Auras.CooldownLeft("Judgement"), nil, "cooldown secret -> unknown")
    eq(ns.Rotation.Check({ spell = "Hammer of Wrath", when = "usable" }, ns.Rotation.LiveState), nil, "usable secret -> unknown")
    eq(ns.PvP.Rank(), nil, "rank secret -> hidden")
    eq(ns.PvP.probes.UnitPVPRank.status, "secret")
    local s, blocked = ns.Rotation.Suggest("Retribution", "solo", nil, 3)
    truthy(blocked, "suggestion flags hidden info")
    renderAll("ret30-bg-secret")
    renderSubs("ret30-bg-secret")
    M.texts = {}
    ns.UI.Open("battle", "Cooldowns")
    truthy(textHas("hidden"), "cooldowns show hidden")
    M.texts = {}
    ns.UI.Open("battle", "Honor & Rank")
    truthy(textHas("Not readable by addons"), "rank: where to look")
    truthy(textHas("secret"), "probe table shows secret")
    ns.Hud.Refresh()
    ns.Hud.Update()
    -- own auras secret too
    S.secretOwnAuras = true
    ns.Hints.Update()
    renderAll("ret30-bg-secret-own")
    S.secretOwnAuras = false
    M.RemoveSecrets()
    S.secretCooldowns = false
    S.combat = false
    S.instanceType = nil
    forget()
    S.level = 24
end)

test("buff before the gates open", function()
    local toasts = {}
    ns.On("TOAST", function(t, text) table.insert(toasts, t .. ": " .. text) end)
    forget()
    know("Blessing of Might")
    S.auras = {}
    S.instanceType = "pvp"
    ns.PvP.OnEnterWorld()
    M.RunTimers()
    local found = false
    for _, t in ipairs(toasts) do if t:find("gates open", 1, true) then found = true end end
    truthy(found, table.concat(toasts, "\n"))
    S.instanceType = nil
    forget()
end)

test("summary tips", function()
    local knows = function() return true end
    local f = { duration = 20, manaStart = 90, manaEnd = 60, casts = { ["Seal of Command"] = 1 }, order = {}, hidden = 0 }
    local tips = table.concat(ns.Summary.Tips(f, "Retribution", "solo", knows), "\n")
    truthy(tips:find("Judgement", 1, true), tips)
    truthy(tips:find("Holy Strike", 1, true), tips)
    f = { duration = 20, manaStart = 90, manaEnd = 10, casts = { ["Holy Light"] = 5 }, order = {}, hidden = 2 }
    tips = table.concat(ns.Summary.Tips(f, "Holy", "dungeon", knows), "\n")
    truthy(tips:find("Flash of Light", 1, true)); truthy(tips:find("hidden", 1, true))
    ns.Summary.Start(0, 90)
    eq(ns.Summary.Finish(2, 90), nil, "too short")
end)

test("learn: lessons unlock by level, PvP track exists, hints after first scan", function()
    local unlocked, upcoming = ns.Learn.Lessons(24, "Retribution")
    truthy(#unlocked > 0 and #upcoming > 0)
    local pvp = 0
    for _, l in ipairs(ns.Data.Learn.lessons) do if l.track == "pvp" then pvp = pvp + 1 end end
    truthy(pvp >= 8, "PvP basics lessons: " .. pvp)
    forget()
    ns.db.char.learn.seenSpells = { ["Holy Light"] = true }
    know("Seal of Righteousness")
    ns.Learn.ScanSpells(false)
    truthy(ns.db.char.learn.seenSpells["Seal of Righteousness"], "marks new spell seen")
    forget()
end)

test("reminders: blessing, aura, seal in melee, righteous fury, redemption quest", function()
    forget()
    know("Blessing of Might"); know("Devotion Aura"); know("Seal of Righteousness"); know("Righteous Fury"); know("Holy Strike")
    ns.DB.SetSpec("Retribution")
    S.auras = { ["Righteous Fury"] = true }
    S.level = 14
    local miss = ns.Reminders.Missing()
    local ids = {}
    for _, r in ipairs(miss) do ids[r.id] = true end
    truthy(ids.blessing, "blessing missing")
    truthy(ids.aura, "aura missing")
    truthy(ids.righteousFury, "RF on while not tanking")
    truthy(ids.redemption, "Redemption quest open at 14")
    S.auras = { ["Blessing of Might"] = true, ["Devotion Aura"] = true }
    ns.DB.SetSpec("Protection")
    ids = {}
    for _, r in ipairs(ns.Reminders.Missing()) do ids[r.id] = true end
    truthy(ids.righteousFury, "Prot: RF missing")
    truthy(not ids.blessing and not ids.aura, "buffs up")
    S.auras = {}
    S.level = 24
    forget()
end)

test("every panel and sub-tab renders for every spec (levels 1, 24, 30, 60)", function()
    for _, lvl in ipairs({ 1, 24, 30, 60 }) do
        S.level = lvl
        for _, spec in ipairs(ns.SPEC_ORDER) do
            ns.DB.SetSpec(spec)
            renderAll(spec .. "@" .. lvl)
            renderSubs(spec .. "@" .. lvl)
        end
    end
    S.level = 24
    eq(#ns.PanelOrder, 9, "9 screens")
    for _, old in ipairs({ "overview", "training", "quests", "mounts", "reminders", "sources", "options", "changes", "mana", "seals", "pvp", "honor", "battlegrounds", "cooldowns", "burst", "worldpvp", "bless" }) do
        ns.UI.Open(old)
    end
    truthy(#ns.UI.Search("seal") > 0, "search finds Seals")
    truthy(#ns.UI.Search("warsong") > 0, "search finds battlegrounds")
    eq(#ns.UI.Search("s"), 0, "search needs 2+ characters")
end)

test("Battle is one group in the same window", function()
    local groups = {}
    for _, g in ipairs(ns.UI.NAV) do if g.title then groups[g.title] = g.keys end end
    truthy(groups.Battle and groups.Battle[1] == "battle", "Battle group")
    eq(#groups.Battle, 1)
    eq(ns.Panels.battle.label, "PvP")
end)

test("no Priest, Mage, Andric or Parzelle text in the window (except the About links)", function()
    local bad = {}
    for _, spec in ipairs(ns.SPEC_ORDER) do
        ns.DB.SetSpec(spec)
        for key, list in pairs(SUBS) do
            for _, sub in ipairs(list) do
                ns.UI.Open(key, sub)
                M.texts = {}
                ns.UI.Refresh()
                for _, t in ipairs(M.texts) do
                    local about = (key == "settings" and sub == "About")
                    if t:find("Andric", 1, true) and not about then bad[#bad + 1] = key .. "/" .. sub .. ": " .. t end
                    if t:find("Parzelle", 1, true) and not about then bad[#bad + 1] = key .. "/" .. sub .. ": " .. t end
                    if t:find("Conjure", 1, true) or t:find("Arcane Intellect", 1, true) then bad[#bad + 1] = key .. "/" .. sub .. ": " .. t end
                end
            end
        end
    end
    eq(#bad, 0, table.concat(bad, "\n"))
end)

test("Horde content hidden for Alliance (quests, gear)", function()
    eq(ns.GearOtherFaction({ faction = "Horde" }), true, "Alliance player, Horde-only item")
    eq(ns.GearOtherFaction({ faction = "Alliance" }), false)
    eq(ns.GearOtherFaction({}), false)
end)

test("bags: highlight + one-time announcement", function()
    ns.DB.SetSpec("Retribution")
    S.level = 30
    S.bagSlots = { [0] = { NEW, DAGGER } }
    S.bagStacks = {}
    ns.Bags.Reset()
    local printed = 0
    local realPrint = ns.Print
    ns.Print = function(m) if tostring(m):find("Upgrade in your bags", 1, true) then printed = printed + 1 end end
    local found = ns.Bags.Scan(false)
    eq(#found, 1, "chest is an upgrade, dagger is not")
    ns.Bags.Scan(false)
    eq(printed, 1, "announced once")
    ns.Print = realPrint
    ns.Bags.RefreshAll()
    S.bagSlots = {}
end)

test("About names Tristan Ludlowe and links the sister addons", function()
    M.texts = {}
    SlashCmdList.TRISTANSADDON("about")
    truthy(textHas("Tristan Ludlowe"), "About tab shows Tristan's full name")
    truthy(textHas("tristans-addon.myazerothlife.com"), "website link")
    truthy(textHas("Andric's Addon"), "sister addon")
    truthy(textHas("Parzelle's Addon"), "sister addon")
end)

test("slash commands", function()
    SlashCmdList.TRISTANSADDON("spec holy")
    eq(ns.DB.ActiveSpec(), "Holy")
    SlashCmdList.TRISTANSADDON("spec ret")
    eq(ns.DB.ActiveSpec(), "Retribution")
    SlashCmdList.TRISTANSADDON("profile")
    eq(ns.DB.ActiveId(), "B")
    SlashCmdList.TRISTANSADDON("profile A")
    for _, cmd in ipairs({ "gear", "battle", "honor", "bg", "cooldowns", "burst", "world", "seals", "mana", "bless debug", "pvpbar always", "pvpbar pvp", "bar", "remind", "bogus", "" }) do SlashCmdList.TRISTANSADDON(cmd) end
end)

test("events: level up, combat, casts, zones, BG entry", function()
    S.level = 26
    M.Fire("PLAYER_LEVEL_UP", 26)
    S.combat = true
    M.Fire("PLAYER_REGEN_DISABLED")
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", ns.Rotation.SpellId("Holy Strike"))
    S.time = 1030
    S.combat = false
    M.Fire("PLAYER_REGEN_ENABLED")
    M.Fire("SPELLS_CHANGED")
    M.Fire("UNIT_AURA", "player")
    M.Fire("UNIT_AURA", "target")
    M.Fire("PLAYER_TARGET_CHANGED")
    M.Fire("PLAYER_EQUIPMENT_CHANGED")
    M.Fire("BAG_UPDATE_DELAYED")
    M.Fire("GROUP_ROSTER_UPDATE")
    S.zonePvP = "contested"
    M.Fire("ZONE_CHANGED_NEW_AREA")
    S.instanceType = "pvp"
    M.Fire("PLAYER_ENTERING_WORLD")
    M.Fire("PLAYER_PVP_RANK_CHANGED")
    M.Fire("HONOR_CURRENCY_UPDATE")
    M.RunTimers()
    S.time, S.zonePvP, S.instanceType = nil, nil, nil
end)

test("dual-spec ready profiles", function()
    ns.DB.SwitchProfile("A")
    ns.db.char.profiles.A.spec, ns.db.char.profiles.B.spec = nil, nil
    local fired = 0
    ns.On("SPEC_CHANGED", function() fired = fired + 1 end)
    ns.DB.SetSpec("Retribution")
    ns.DB.SetSpec("Holy", "B")
    eq(ns.DB.ActiveSpec(), "Retribution")
    truthy(ns.DB.SwitchProfile("B"))
    eq(ns.DB.ActiveSpec(), "Holy")
    eq(ns.DB.SwitchProfile("B"), false)
    ns.DB.SwitchProfile("A")
    eq(fired, 3, "SPEC_CHANGED fires on active changes only")
    truthy(M.events.ACTIVE_TALENT_GROUP_CHANGED, "dual-spec event registered")
    eq(ns.db.char.autoSwitch, true)
    S.numSpecGroups, S.specGroup = 2, 2
    eq(ns.DualSpec.HasDualSpec(), true)
    M.Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
    eq(ns.DB.ActiveId(), "B")
    eq(ns.DB.ActiveSpec(), "Holy")
    S.specGroup = 1
    M.Fire("ACTIVE_TALENT_GROUP_CHANGED", 1, 2)
    eq(ns.DB.ActiveId(), "A")
    ns.db.char.autoSwitch = false
    M.Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
    eq(ns.DB.ActiveId(), "A", "no switch when disabled")
    ns.db.char.autoSwitch = true
    S.specGroup = 2
    truthy(ns.DualSpec.Sync(), "sync to active group")
    eq(ns.DB.ActiveId(), "B")
    S.specGroup = 1
    ns.DualSpec.Sync()
    S.numSpecGroups = 1
end)

test("weights derive from priority order", function()
    for _, spec in ipairs(ns.SPEC_ORDER) do
        local prio = ns.Data.StatPriority[spec]
        local w = ns.Stats.Weights(spec, 10)
        local n = #prio.keys
        for r, k in ipairs(prio.keys) do
            local expect = (n - r + 1) / n
            if ns.Stats.PERCENT_KEYS[k] then expect = expect * 10 end
            near(w[k], expect, spec .. " " .. k)
        end
        eq(ns.Stats.WeightSetName(spec, 30, {}), spec)
    end
end)

test("compare: rings replace the weaker ring", function()
    eq(ns.Stats.Compare(OLD, "Retribution", 30, {}, 10).isEquipped, true)
    S.itemInfo[1006] = { equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0 }
    S.itemLines["item:1006"] = { "R3", "+5 Strength" }
    local res = ns.Stats.Compare("item:1006", "Retribution", 30, {}, 10)
    eq(res.against.slot, 11, "compares to weaker ring")
    truthy(res.delta > 0)
end)

test("changes: research baseline unread, mark read", function()
    local n = ns.Changes.UnreadCount()
    truthy(n >= 3, "research changes")
    ns.Changes.MarkRead(ns.Changes.All()[1])
    eq(ns.Changes.UnreadCount(), n - 1)
    ns.Changes.MarkAllRead()
    eq(ns.Changes.UnreadCount(), 0)
end)

test("talent builds decode onto Forever's trees", function()
    eq(#ns.Data.TalentTrees, 3, "three trees")
    local valid, valid60 = 0, 0
    for _, b in ipairs(ns.Data.DecodedBuilds) do
        if b.valid then
            valid = valid + 1
            for ti, tree in ipairs(ns.Data.TalentTrees) do
                eq(#b.trees[ti].points, #tree.talents, "points per talent")
                for i, t in ipairs(tree.talents) do truthy(b.trees[ti].points[i] <= t.max_rank) end
            end
            if b.level == 60 then valid60 = valid60 + 1 eq(b.total, 51) end
            truthy(b.total <= 51)
        else
            truthy(b.reason and b.reason ~= "", "invalid builds say why")
        end
    end
    truthy(valid > 0, "at least one build draws")
    for _, spec in ipairs(ns.SPEC_ORDER) do
        ns.DB.SetSpec(spec)
        M.texts = {}
        ns.UI.Open("talents")
        truthy(textHas("points (level"), spec .. " build summary line")
    end
end)

test("gear: my-level view vs best overall", function()
    S.level = 24
    ns.Data.GearBrackets["level 20"] = ns.Data.GearBrackets["level 20"] or {}
    table.insert(ns.Data.GearBrackets["level 20"], { name = "Testing Robe Low", item_id = 8801, source = "Test Dungeon" })
    table.insert(ns.Data.GearBrackets["level 20"], { name = "Testing Robe High", item_id = 8802, source = "Test Dungeon" })
    S.itemInfo[8801] = { equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 3, minLevel = 18 }
    S.itemInfo[8802] = { equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 3, minLevel = 31 }
    S.itemLines["item:8801"] = { "Chest", "+6 Strength" }
    S.itemLines["item:8802"] = { "Chest", "+40 Strength" }
    ns.Stats.ClearCache()
    ns.DB.SetSpec("Retribution")
    ns.UI.SetGearView("mine")
    M.texts = {}
    ns.UI.Open("gear")
    truthy(not textHas("Testing Robe High"), "level-31 item hidden at 24")
    ns.UI.SetGearView("best")
    M.texts = {}
    ns.UI.Refresh()
    truthy(textHas("Testing Robe High"), "best overall includes higher-level items")
    ns.UI.SetGearView("mine")
end)

test("map pin helpers", function()
    local e = ns.Map.FindDungeonEntrance("Wailing Caverns")
    truthy(e, "entrance from client map data")
    M.waypoints = {}
    truthy(ns.Map.SetWaypoint(e.mapID, e.x, e.y, "WC"))
    eq(M.waypoints[1].mapID, 10); eq(M.superTracked, true)
end)


print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
