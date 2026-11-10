-- "Learn the Paladin": lesson unlocks and first-time spell hints.
-- All text lives in content/learn.json -> Data/Learn.lua (generated).
local _, ns = ...

local Learn = {}
ns.Learn = Learn

function Learn.Content()
    return ns.Data.Learn
end

local function specOk(entrySpec, spec)
    return entrySpec == nil or entrySpec == "any" or entrySpec == spec
end
Learn.SpecOk = specOk

-- Lessons for a spec split into unlocked / upcoming by level.
function Learn.Lessons(level, spec)
    local c = Learn.Content()
    local unlocked, upcoming = {}, {}
    for _, l in ipairs(c and c.lessons or {}) do
        if specOk(l.spec, spec) then
            table.insert(l.level <= level and unlocked or upcoming, l)
        end
    end
    table.sort(unlocked, function(a, b) return a.level > b.level end)
    table.sort(upcoming, function(a, b) return a.level < b.level end)
    return unlocked, upcoming
end

function Learn.NewLessonsAt(level, spec)
    local out = {}
    local c = Learn.Content()
    for _, l in ipairs(c and c.lessons or {}) do
        if l.level == level and specOk(l.spec, spec) then table.insert(out, l) end
    end
    return out
end

function Learn.UnreadLessonCount(level, spec)
    local unlocked = Learn.Lessons(level, spec)
    local n = 0
    for _, l in ipairs(unlocked) do
        if not ns.db.char.learn.readLessons[l.id] then n = n + 1 end
    end
    return n
end

-- Spell -> id for hint detection (spells_by_level + racials).
local function hintIds()
    local out = {}
    local c = Learn.Content()
    for name, hint in pairs(c and c.first_learn_hints or {}) do
        local id = ns.Rotation.SpellId(name)
        if id then out[name] = { id = id, hint = hint } end
    end
    return out
end

-- On login with an empty seen-list, record what's already known silently.
function Learn.ScanSpells(silent)
    local learn = ns.db.char.learn
    local fresh = next(learn.seenSpells) == nil
    for name, e in pairs(hintIds()) do
        if not learn.seenSpells[name] and ns.Progress.KnowsSpell(e.id) then
            learn.seenSpells[name] = true
            if not silent and not fresh and learn.hints then
                ns.Print("|cff3fdc5aNew spell: " .. name .. "|r - " .. e.hint)
                ns.Fire("TOAST", "New spell: " .. name, e.hint, ns.Rotation.Icon(name))
            end
        end
    end
end

-- Find the teaching entry for a spell or talent name.
function Learn.Entry(name)
    local c = Learn.Content()
    if not c then return nil end
    return (c.spells and c.spells[name]) or (c.talents and c.talents[name])
end
