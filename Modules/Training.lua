-- Spell ranks by level and the next-trainer reminder.
-- Per-rank training costs are NOT published (research gap); only the
-- ~206-207g total for 1-60 (all classes, Blizzard's launch notes) is shown.
local _, ns = ...

local Training = {}
ns.Training = Training

local function playerFaction()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f
end

-- Is this trainer spell for this character at all? Other-faction spells stay
-- hidden; talent-taught spells only for the spec whose tree has
-- them (or once the talent is known).
function Training.Applies(s, spec, faction)
    faction = faction or playerFaction()
    if s.faction and faction and s.faction ~= faction then return false end
    if s.talent then
        if ns.Progress.KnowsSpell(s.wowhead_base_spell_id) then return true end
        return spec ~= nil and s.talent_tree == spec
    end
    return true
end

-- Spells (with rank numbers) that become trainable exactly at `level`.
function Training.At(level, spec, faction)
    local out = {}
    for _, s in ipairs(ns.Data.Spells) do
        if Training.Applies(s, spec, faction) then
            for rank, lvl in ipairs(s.rank_learn_levels) do
                if lvl == level then
                    table.insert(out, { spell = s, rank = rank, talent = s.talent })
                end
            end
        end
    end
    return out
end

-- Next level > current with something to train (nil at/after the last one).
function Training.NextLevel(level, spec, faction)
    for _, lvl in ipairs(ns.Data.TrainerLevels) do
        if lvl > level and #Training.At(lvl, spec, faction) > 0 then return lvl end
    end
    return nil
end

-- Highest rank available at `level` for one spell record (0 if none yet).
function Training.RankAt(spell, level)
    local r = 0
    for rank, lvl in ipairs(spell.rank_learn_levels) do
        if lvl <= level then r = rank end
    end
    return r
end

function Training.IsKey(spell, spec)
    for _, name in ipairs(ns.Data.KeySpells[spec] or {}) do
        if name == spell.name then return true end
    end
    return false
end

function Training.Names(list)
    local t = {}
    for _, e in ipairs(list) do table.insert(t, e.spell.display .. (#e.spell.rank_learn_levels > 1 and (" r" .. e.rank) or "")) end
    return table.concat(t, ", ")
end

-- Called on PLAYER_LEVEL_UP: chat + toast if the new level has training.
function Training.OnLevelUp(level)
    local spec = ns.DB.ActiveSpec()
    local list = Training.At(level, spec)
    if #list == 0 then
        local nextLvl = Training.NextLevel(level, spec)
        if nextLvl then ns.Print(("Next trainer visit: level %d."):format(nextLvl)) end
        return
    end
    local names = Training.Names(list)
    ns.Print("|cff3fdc5aNew at your trainer:|r " .. names)
    ns.Fire("TOAST", "Visit your Paladin trainer", names)
end
