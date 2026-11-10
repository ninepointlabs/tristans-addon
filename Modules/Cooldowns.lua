-- Battle > My cooldowns & Forbearance, and the burst-window coach.
--
-- Only YOUR spells: cooldowns come from C_Spell.GetSpellCooldown for spells you
-- know, Forbearance from your own debuff, and the coach follows your own
-- UNIT_SPELLCAST_SUCCEEDED events. Nothing reads enemy health, casts or
-- cooldowns (Forever hides them from addons, and that would be automation).
-- Cooldown widgets take secret start/duration values directly, so the swirl
-- still works when the numbers themselves are hidden from addon code.
local _, ns = ...

local CD = {}
ns.Cooldowns = CD

-- Spells listed when the research has no pvp.cooldowns rows (names only; every
-- number shown comes from the game or from the research rows).
CD.DEFAULT = { "Hammer of Justice", "Repentance", "Divine Shield", "Divine Protection", "Blessing of Protection",
    "Blessing of Freedom", "Lay on Hands", "Templar's Bulwark", "Holy Shock" }

function CD.Rows()
    local rows = ns.Data.PvP and ns.Data.PvP.cooldowns
    if rows and #rows > 0 then return rows end
    local out = {}
    for _, n in ipairs(CD.DEFAULT) do table.insert(out, { spell = n }) end
    return out
end

-- Known cooldowns: { spell, rec, left (sec|nil hidden), start, duration, readable }.
function CD.List(knows)
    knows = knows or function(n) return ns.Progress.Knows(n) end
    local out = {}
    for _, r in ipairs(CD.Rows()) do
        local name = r.spell
        if name and knows(name) then
            local id = ns.Rotation.SpellId(name) or name
            local start, duration, readable = ns.Auras.CooldownRaw(id)
            table.insert(out, { spell = name, rec = r, left = ns.Auras.CooldownLeft(id), start = start, duration = duration, readable = readable })
        end
    end
    return out
end

-- Forbearance text for the HUD / Battle screen.
function CD.ForbearanceText()
    local f = ns.Paladin.Forbearance()
    if f == nil then return "Forbearance: hidden" end
    if f == false then return nil end
    if f.left then return ("Forbearance: %ds (no Divine Shield, Divine Protection or Blessing of Protection)"):format(math.ceil(f.left)) end
    return "Forbearance is on you"
end

-- ---------------------------------------------------------------------------
-- Burst coach. Steps come from the research (pvp.burst.<spec>); the coach
-- marks a step done when YOU cast it and points at the next one that's known
-- and off cooldown. The window resets after WINDOW seconds without a step.
CD.WINDOW = 12
local coach = { done = {}, last = 0 }

function CD.Steps(spec)
    local b = ns.Data.PvP and ns.Data.PvP.burst
    return (b and spec and b[spec]) or {}
end

function CD.ResetCoach() coach = { done = {}, last = 0 } end

function CD.OnCast(spellID, now)
    now = now or GetTime()
    local name = ns.Auras.SpellName(spellID)
    if not name then return end
    if now - coach.last > CD.WINDOW then coach.done = {} end
    for i, step in ipairs(CD.Steps(ns.DB.ActiveSpec())) do
        if not coach.done[i] and (name == step.spell or name == ns.Paladin.LocalName(step.spell)) then
            coach.done[i] = true
            coach.last = now
            return i
        end
    end
end

-- The coach's view: { steps = { {spell, note, known, done, ready (true/false/nil)} }, next = index|nil, active }
function CD.Coach(spec, state, now)
    now = now or GetTime()
    state = state or {
        known = function(n) return ns.Progress.Knows(n) end,
        cooldown = function(n) return ns.Auras.CooldownLeft(ns.Rotation.SpellId(n) or n) end,
    }
    if now - coach.last > CD.WINDOW then coach.done = {} end
    local out, nextIdx = {}, nil
    for i, step in ipairs(CD.Steps(spec)) do
        local known = state.known(step.spell)
        local left = known and state.cooldown(step.spell) or nil
        local ready
        if not known then ready = false elseif left == nil then ready = nil else ready = left <= 0.1 end
        local e = { spell = step.spell, note = step.note, known = known, done = coach.done[i] == true, ready = ready, left = left }
        table.insert(out, e)
        if not nextIdx and known and not e.done and ready ~= false then nextIdx = i end
    end
    return { steps = out, next = nextIdx, active = next(coach.done) ~= nil }
end
