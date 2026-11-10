-- Paladin state: which Blessing, Aura and Seal you have up, which ones the
-- research recommends right now, Righteous Fury, and the Unsealed Wrath echo.
-- Read-only advice. Every aura read can come back nil ("can't tell", e.g. a
-- secret value in combat); callers show "hidden" instead of guessing.
local _, ns = ...

local Paladin = {}
ns.Paladin = Paladin

-- Removed at launch (Blessing of Light, Salvation, Sanctuary, Sanctity Aura) are
-- deliberately absent.
Paladin.BLESSINGS = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings" }
Paladin.GREATER = {
    ["Blessing of Might"] = "Greater Blessing of Might",
    ["Blessing of Wisdom"] = "Greater Blessing of Wisdom",
    ["Blessing of Kings"] = "Greater Blessing of Kings",
}
-- Freedom and Protection are also Blessings: one Blessing from you per target,
-- so either one replaces your Might/Wisdom/Kings on that target.
Paladin.REPLACING = { "Blessing of Freedom", "Blessing of Protection" }
Paladin.AURAS = { "Devotion Aura", "Retribution Aura", "Concentration Aura",
    "Fire Resistance Aura", "Frost Resistance Aura", "Shadow Resistance Aura" }
Paladin.SEALS = { "Seal of Righteousness", "Seal of the Crusader", "Seal of Command", "Seal of Justice",
    "Seal of Light", "Seal of Wisdom", "Seal of Fury" }
Paladin.UNSEALED_WRATH = "Unsealed Wrath" -- talent and (assumed) echo aura name; see Learn > Talents
Paladin.FORBEARANCE = "Forbearance"

-- Class-smart Blessing (Tim's decision 2026-11-10): Might for melee, Wisdom for
-- casters and healers, Kings for everyone once known if the player picks it.
-- Hybrids default to Wisdom (they use mana); every class can be overridden.
Paladin.CLASS_DEFAULT = {
    WARRIOR = "Might", ROGUE = "Might", HUNTER = "Might",
    MAGE = "Wisdom", PRIEST = "Wisdom", WARLOCK = "Wisdom",
    DRUID = "Wisdom", SHAMAN = "Wisdom", PALADIN = "Wisdom",
}
Paladin.CLASS_ORDER = { "WARRIOR", "ROGUE", "HUNTER", "PALADIN", "SHAMAN", "DRUID", "PRIEST", "MAGE", "WARLOCK" }
Paladin.CLASS_LABEL = {
    WARRIOR = "Warrior", ROGUE = "Rogue", HUNTER = "Hunter", PALADIN = "Paladin", SHAMAN = "Shaman",
    DRUID = "Druid", PRIEST = "Priest", MAGE = "Mage", WARLOCK = "Warlock",
}

local function knows(name) return ns.Progress.Knows(name) end
local function localName(name)
    return ns.Auras.SpellName(ns.Rotation.SpellId(name)) or name
end
Paladin.LocalName = localName

-- First of `names` you have up on `unit` (yours only when mine=true).
-- Returns name | false | nil (unknown).
function Paladin.FirstUp(unit, names, mine, filter)
    local unknown = false
    for _, n in ipairs(names) do
        local has
        if mine then has = ns.Auras.FindMine(unit, localName(n), filter) else has = ns.Auras.Find(unit, localName(n), filter or "HELPFUL") end
        if has then return n, has end
        if has == nil then unknown = true end
    end
    if unknown then return nil end
    return false
end

function Paladin.ActiveAura() return Paladin.FirstUp("player", Paladin.AURAS, true) end
function Paladin.ActiveSeal() return Paladin.FirstUp("player", Paladin.SEALS, true) end

-- Your Might/Wisdom/Kings (or a Greater one) on a unit.
function Paladin.MyBlessingOn(unit)
    local names = {}
    for _, b in ipairs(Paladin.BLESSINGS) do
        table.insert(names, b)
        table.insert(names, Paladin.GREATER[b])
    end
    return Paladin.FirstUp(unit, names, true)
end

-- Your Freedom/Protection on a unit (they replace the normal Blessing).
function Paladin.MyReplacingOn(unit) return Paladin.FirstUp(unit, Paladin.REPLACING, true) end

function Paladin.KnownAuras()
    local out = {}
    for _, a in ipairs(Paladin.AURAS) do if knows(a) then table.insert(out, a) end end
    return out
end

-- Is the player in a PvP situation (battleground, or flagged)?
function Paladin.InPvP()
    if ns.PvP and ns.PvP.InBattleground() then return true end
    if UnitIsPVP then
        local ok, v = pcall(UnitIsPVP, "player")
        if ok and v and not ns.Auras.IsSecret(v) then return true end
    end
    return false
end

-- Which Aura to run. ctx = { spec, inGroup, inPvP, override }; known(name) injectable.
-- Research: Devotion solo, Retribution in groups (and for Protection's AoE pulls),
-- Concentration for Holy in PvP; resistance auras only when the player picks one.
function Paladin.RecommendedAura(ctx, known)
    known = known or knows
    ctx = ctx or {}
    local function first(...)
        for _, n in ipairs({ ... }) do if known(n) then return n end end
    end
    if ctx.override and known(ctx.override) then return ctx.override, "your pick" end
    if ctx.spec == "Holy" and ctx.inPvP then
        local a = first("Concentration Aura", "Devotion Aura")
        return a, a == "Concentration Aura" and "Holy in PvP: casts aren't pushed back as much" or "solo"
    end
    if ctx.spec == "Protection" then
        local a = first("Retribution Aura", "Devotion Aura")
        return a, a == "Retribution Aura" and "Protection: damages everything hitting you on AoE pulls" or "solo"
    end
    if ctx.inGroup then
        local a = first("Retribution Aura", "Devotion Aura")
        return a, a == "Retribution Aura" and "in a group" or "solo"
    end
    return first("Devotion Aura"), "solo"
end

-- Which Seal to keep up. ctx = { spec, weaponSpeed, twoHanded, targetHasCrusader, judgeReady }.
-- Ret: Judge Seal of the Crusader first, then Seal of Command for slow two-handers
-- or Seal of Righteousness for fast weapons / high spell power (Icy Veins).
-- The swing-speed cut-off (3.4 s) is an addon assumption, shown as such.
Paladin.SLOW_WEAPON = 3.4
function Paladin.RecommendedSeal(ctx, known)
    known = known or knows
    ctx = ctx or {}
    if ctx.spec == "Protection" and known("Seal of Fury") then return "Seal of Fury", "tank seal: holy damage, absorb and a taunting Judgement" end
    if ctx.spec == "Holy" then
        if known("Seal of Wisdom") then return "Seal of Wisdom", "Judgement of Wisdom gives your group mana back" end
        if known("Seal of Righteousness") then return "Seal of Righteousness", "until Seal of Wisdom" end
        return nil
    end
    if ctx.targetHasCrusader == false and known("Seal of the Crusader") and ctx.judgeReady ~= false then
        return "Seal of the Crusader", "Judge it first: the Crusader debuff, then switch"
    end
    local slow = (ctx.weaponSpeed or 0) >= Paladin.SLOW_WEAPON
    if known("Seal of Command") and (slow or not known("Seal of Righteousness")) then
        return "Seal of Command", "slow two-hander"
    end
    if known("Seal of Righteousness") then return "Seal of Righteousness", (known("Seal of Command") and "fast weapon or high spell power" or nil) end
    return nil
end

function Paladin.WeaponSpeed()
    if not UnitAttackSpeed then return nil end
    local ok, mh = pcall(UnitAttackSpeed, "player")
    if ok and type(mh) == "number" and not ns.Auras.IsSecret(mh) then return mh end
    return nil
end

-- Target within melee reach? true/false/nil.
function Paladin.InMelee()
    if not UnitExists("target") or not UnitCanAttack("player", "target") then return false end
    if knows("Holy Strike") and C_Spell and C_Spell.IsSpellInRange then
        local ok, r = pcall(C_Spell.IsSpellInRange, ns.Rotation.SpellId("Holy Strike") or "Holy Strike", "target")
        if ok and r ~= nil and not ns.Auras.IsSecret(r) then return r and true or false end
    end
    if CheckInteractDistance then
        local ok, r = pcall(CheckInteractDistance, "target", 3)
        if ok and not ns.Auras.IsSecret(r) then return r and true or false end
    end
    return nil
end

-- Unsealed Wrath echoes (0-3) from your own aura. nil = hidden/unknown.
function Paladin.EchoStacks()
    local data = ns.Auras.Find("player", Paladin.UNSEALED_WRATH, "HELPFUL")
    if data == nil then return nil end
    if data == false then return 0 end
    local c = data.applications or data.charges or data.count
    if c == nil or ns.Auras.IsSecret(c) then return nil end
    return math.max(1, c)
end

function Paladin.HasUnsealedWrath() return knows("Unsealed Wrath") end

-- Forbearance on you: { left = seconds|nil } or false / nil (unknown).
function Paladin.Forbearance()
    local data = ns.Auras.Find("player", localName(Paladin.FORBEARANCE), "HARMFUL")
    if data == nil then return nil end
    if data == false then return false end
    return { left = ns.Auras.TimeLeft(data), data = data }
end

-- Righteous Fury on you: true / false / nil (unknown).
function Paladin.RighteousFury()
    if not knows("Righteous Fury") then return false end
    local has = ns.Auras.PlayerHas(localName("Righteous Fury"))
    if has == nil then return nil end
    return has and true or false
end

-- Everything the bar, Home and reminders want to know, in one table.
function Paladin.State()
    local spec = ns.DB.ActiveSpec()
    local inGroup = IsInGroup and IsInGroup() or false
    local inPvP = Paladin.InPvP()
    local aura = Paladin.ActiveAura()
    local seal = Paladin.ActiveSeal()
    local crusader
    if UnitExists("target") and UnitCanAttack("player", "target") then
        local has = ns.Auras.TargetHasMine(localName("Judgement of the Crusader"))
        if has ~= nil then crusader = has and true or false end
    end
    local recAura, auraWhy = Paladin.RecommendedAura({ spec = spec, inGroup = inGroup, inPvP = inPvP, override = ns.db.char.auraHint.override })
    local recSeal, sealWhy = Paladin.RecommendedSeal({ spec = spec, weaponSpeed = Paladin.WeaponSpeed(), targetHasCrusader = crusader })
    return {
        spec = spec, inGroup = inGroup, inPvP = inPvP,
        aura = aura, recAura = recAura, auraWhy = auraWhy,
        seal = seal, recSeal = recSeal, sealWhy = sealWhy,
        blessing = Paladin.MyBlessingOn("player"),
        rf = Paladin.RighteousFury(),
        inMelee = Paladin.InMelee(),
    }
end
