-- Safe aura/cooldown/power readers.
-- Forever uses the Midnight-era addon restrictions (research: "secret values
-- apply - verify in client"). Every read is pcall-wrapped and any secret value
-- is treated as "unknown" so the addon degrades to advice instead of erroring.
local _, ns = ...

local Auras = {}
ns.Auras = Auras

local function secret(v)
    return issecretvalue ~= nil and v ~= nil and issecretvalue(v)
end
Auras.IsSecret = secret

function Auras.SpellName(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and n and not secret(n) then return n end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok and n then return n end
    end
    return nil
end

-- Returns aura data table, false (definitely absent), or nil (unknown/blocked).
function Auras.Find(unit, name, filter)
    if not name or not UnitExists(unit) then return false end
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, filter)
        if not ok or secret(data) then return nil end
        return data or false
    end
    if AuraUtil and AuraUtil.FindAuraByName then
        local ok, n = pcall(AuraUtil.FindAuraByName, name, unit, filter)
        if not ok then return nil end
        return n and { name = n } or false
    end
    return nil
end

function Auras.PlayerHas(name)
    return Auras.Find("player", name, "HELPFUL")
end

-- Target debuff cast by the player.
function Auras.TargetHasMine(name)
    return Auras.Find("target", name, "HARMFUL|PLAYER")
end

-- Seconds of cooldown left (0 = ready), or nil if unknown.
function Auras.CooldownLeft(nameOrId)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, nameOrId)
        if not ok or not cd or secret(cd.startTime) or secret(cd.duration) then return nil end
        if (cd.duration or 0) <= 1.5 then return 0 end -- global cooldown counts as ready
        return math.max(0, cd.startTime + cd.duration - GetTime())
    end
    return nil
end

function Auras.PowerPct(unit)
    local ok, cur = pcall(UnitPower, unit or "player", 0)
    local ok2, max = pcall(UnitPowerMax, unit or "player", 0)
    if not ok or not ok2 or secret(cur) or secret(max) or not max or max == 0 then return nil end
    return cur / max * 100
end

function Auras.HealthPct(unit)
    if not UnitExists(unit) then return nil end
    local ok, cur = pcall(UnitHealth, unit)
    local ok2, max = pcall(UnitHealthMax, unit)
    if not ok or not ok2 or secret(cur) or secret(max) or not max or max == 0 then return nil end
    return cur / max * 100
end

-- Does this unit's class use mana? Class, not current power type: a Druid in
-- Bear Form still uses mana. Unknown class -> true (don't skip anyone by mistake).
Auras.NO_MANA = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, DEMONHUNTER = true }
function Auras.UsesMana(unit)
    local ok, _, class = pcall(UnitClass, unit)
    if not ok or not class or secret(class) then return true end
    return not Auras.NO_MANA[class]
end

-- One of *your* auras on a unit (filter adds PLAYER). Same true/false/nil contract.
function Auras.FindMine(unit, name, filter)
    return Auras.Find(unit, name, (filter or "HELPFUL") .. "|PLAYER")
end

-- Seconds left on an aura data table, or nil when unknown/secret/permanent.
function Auras.TimeLeft(data, now)
    if type(data) ~= "table" then return nil end
    local exp = data.expirationTime
    if exp == nil or secret(exp) or exp == 0 then return nil end
    return math.max(0, exp - (now or GetTime()))
end

-- Raw cooldown start/duration for a Cooldown widget. Cooldown frames accept
-- secret values (Blizzard), so these are passed through untouched; the second
-- return says whether addon code may read them.
function Auras.CooldownRaw(nameOrId)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, nameOrId)
        if ok and cd then
            local readable = not secret(cd.startTime) and not secret(cd.duration)
            return cd.startTime, cd.duration, readable
        end
    end
    return nil, nil, false
end

-- Is a spell usable right now (mana, target, Hammer of Wrath's execute window)?
-- true/false/nil(unknown).
function Auras.Usable(nameOrId)
    local fn = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
    if not fn then return nil end
    local ok, usable = pcall(fn, nameOrId)
    if not ok or secret(usable) then return nil end
    return usable and true or false
end
