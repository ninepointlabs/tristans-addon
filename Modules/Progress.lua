-- Class quests, riding/gold goals and milestones.
local _, ns = ...

local Progress = {}
ns.Progress = Progress

Progress.RACE_NAMES = {
    Human = "Human", Dwarf = "Dwarf", Gnome = "Gnome", NightElf = "Night Elf",
    Scourge = "Undead", Undead = "Undead", Troll = "Troll", Orc = "Orc", Tauren = "Tauren",
}

function Progress.PlayerRace()
    local name, english = UnitRace("player")
    return Progress.RACE_NAMES[english] or english or name
end

local function raceMatches(field, race)
    if not field or not race then return false end
    if field == "All" then return true end
    for part in field:gmatch("[^/]+") do
        if part == race then return true end
    end
    return false
end
Progress.RaceMatches = raceMatches

function Progress.IsQuestDone(id)
    if not id then return nil end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
        if ok then return done end
    end
    return nil
end

-- Class quests for a race + faction (nil = show all). Quests without a
-- researched ID are kept and flagged (`missing`), never given an invented ID.
function Progress.ClassQuests(race, faction)
    local out = {}
    for _, q in ipairs(ns.Data.Quests) do
        local ok = (race == nil) or q.races == nil or raceMatches(q.races, race)
        if ok and faction and q.faction and q.faction ~= "Both" and q.faction ~= faction then ok = false end
        if ok then
            if q.quest_id == nil then q.missing = true end
            table.insert(out, q)
        end
    end
    table.sort(out, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    return out
end

-- The next class quest at or above level-ish that isn't completed.
function Progress.NextClassQuest(race, faction, level)
    for _, q in ipairs(Progress.ClassQuests(race, faction)) do
        if q.missing or not Progress.IsQuestDone(q.quest_id) then
            if q.level >= (level or 1) - 10 then return q end
        end
    end
    return nil
end

-- Gold goals. Values come from research riding data (training cost text "100g").
local function goldFromText(text)
    local g = text and tonumber(tostring(text):match("(%d+)g"))
    return g
end

function Progress.GoldGoals()
    local goals = {}
    for _, r in ipairs(ns.Data.Riding) do
        local cost = goldFromText(r.training)
        if cost and r.level then
            table.insert(goals, {
                name = r.skill, level = r.level, gold = cost, speed = r.speed,
                mount = r.mount_cost, spell_id = r.spell_id, source_url = r.source_url, checked = r.checked,
            })
        end
    end
    table.sort(goals, function(a, b) return a.level < b.level end)
    return goals
end

function Progress.RidingNotes()
    for _, r in ipairs(ns.Data.Riding) do
        if r.notes then return r end
    end
end

function Progress.MountForRace(race)
    for _, m in ipairs(ns.Data.Mounts) do
        if m.race == race then return m end
    end
end

function Progress.KnowsSpell(id)
    if not id then return false end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and known then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, id)
        if ok and known then return true end
    end
    return false
end

-- Next unmet gold goal (skipping skills already learned).
function Progress.NextGoldGoal(level)
    for _, g in ipairs(Progress.GoldGoals()) do
        if not Progress.KnowsSpell(g.spell_id) then return g end
    end
end

function Progress.NextMilestone(level)
    for _, m in ipairs(ns.Data.Milestones.items) do
        if m.level > level then return m end
    end
end

-- Spell known by name: research ID first, then the spellbook by name.
function Progress.Knows(name)
    local id = ns.Rotation and ns.Rotation.SpellId(name)
    if id and Progress.KnowsSpell(id) then return true end
    local s = ns.Rotation and ns.Rotation.SpellRecord(name)
    for _, rid in ipairs(s and s.rank_spell_ids or {}) do
        if Progress.KnowsSpell(rid) then return true end
    end
    -- Without any research ID, fall back to a spellbook lookup by name.
    if not id and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and info and not ns.Auras.IsSecret(info) then return true end
    end
    return false
end

function Progress.MoneyText(copper)
    copper = copper or 0
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    return ("%dg %ds"):format(g, s)
end
