-- Leveling: Path · Zones & dungeons · Trainer · Class quests · Riding & gold.
-- Trainer / Class quests / Riding & gold live in their own files as sections.
local _, ns = ...
local UI = ns.UI

UI.LevelingSections = UI.LevelingSections or {}
local S = UI.LevelingSections

local TABS = { "Path", "Zones & dungeons", "Trainer", "Class quests", "Riding & gold" }
local tab = "Path"

local function bracketRange(levels)
    local lo, hi = levels:match("(%d+)%-(%d+)")
    return tonumber(lo), tonumber(hi)
end

-- Upcoming steps: trainer visits + milestones + riding, merged by level.
local function pathSteps(c)
    local steps, seen = {}, {}
    local function add(level, text, kind)
        local key = level .. text
        if seen[key] then return end
        seen[key] = true
        table.insert(steps, { level = level, text = text, kind = kind })
    end
    local lvl, visits = c.level, 0
    while visits < 2 do
        local nextLvl = ns.Training.NextLevel(lvl, c.spec)
        if not nextLvl then break end
        add(nextLvl, "Trainer: " .. ns.Training.Names(ns.Training.At(nextLvl, c.spec)), "trainer")
        lvl, visits = nextLvl, visits + 1
    end
    for _, m in ipairs(ns.Data.Milestones.items) do
        if m.level > c.level then add(m.level, m.what, "milestone") end
    end
    table.sort(steps, function(a, b) return a.level < b.level end)
    local out = {}
    for i = 1, math.min(6, #steps) do out[i] = steps[i] end
    return out
end

function S.Path(L, c)
    L:Columns({ 0.55, 0.45 })
    L:Label("Your path")
    local now = ns.Training.At(c.level, c.spec)
    L:Row({ chip = { text = tostring(c.level), kind = "good" }, title = "You are here" .. (#now > 0 and (" · " .. #now .. " spell" .. (#now == 1 and "" or "s") .. " to train") or ""),
        tint = UI.Accent(), button = #now > 0 and { label = "Trainer", onClick = function() tab = "Trainer" UI.Refresh() end } or nil })
    for _, s in ipairs(pathSteps(c)) do
        L:Row({ chip = { text = tostring(s.level), kind = "neutral" }, title = s.text })
    end
    L:Source(ns.Data.Milestones)
    L:NextColumn()
    local horde = c.faction == "Horde"
    local zoneCard
    for _, z in ipairs(ns.Data.Zones) do
        local lo, hi = bracketRange(z.levels)
        if lo and c.level >= lo and c.level <= hi then zoneCard = z end
    end
    if c.level < 6 and c.race == "Human" then
        L:Card({ label = "Where to quest (1-5)", title = "Northshire Abbey",
            body = "Human start, then Elwynn Forest; Westfall or Loch Modan next (Icy Veins' leveling brackets).",
            button = { label = "Zones & dungeons", onClick = function() tab = "Zones & dungeons" UI.Refresh() end } })
    elseif zoneCard then
        L:Card({ label = "Where to quest (" .. zoneCard.levels .. ")", title = horde and zoneCard.horde or zoneCard.alliance,
            body = "Dungeons: " .. zoneCard.dungeons,
            button = { label = "Zones & dungeons", onClick = function() tab = "Zones & dungeons" UI.Refresh() end } })
    else
        L:Card({ label = "Where to quest", title = "Not in the research yet",
            body = "Zone guides for levels 30-60 aren't published yet. Questie or the dungeon list can help.",
            button = { label = "Dungeons near your level", onClick = function() tab = "Zones & dungeons" UI.Refresh() end } })
    end
    local content = ns.Learn.Content()
    local tips = content and content.leveling and c.spec and content.leveling[c.spec]
    if tips and tips[1] then
        L:Card({ label = "Leveling as " .. c.spec, title = tips[1].title, body = tips[1].body,
            button = { label = "More leveling tips", onClick = function() UI.Select("learn", "Leveling") end } })
    end
    L:EndColumns()
end

S["Zones & dungeons"] = function(L, c)
    local horde = c.faction == "Horde"
    L:Label((c.faction or "?") .. " zones by level")
    if (ns.PvP.Ruleset() or "PvP") ~= "Normal" then
        L:Note("PvP realm: contested zones flag you for world PvP. The Battle > World PvP tab has the survival tips.")
    end
    for _, z in ipairs(ns.Data.Zones) do
        local lo, hi = bracketRange(z.levels)
        local here = lo and c.level >= lo and c.level <= hi
        L:Row({ chip = { text = z.levels, kind = here and "good" or "neutral" }, title = horde and z.horde or z.alliance,
            sub = "Dungeons: " .. z.dungeons, tint = here and UI.Accent() or nil })
    end
    L:Source(ns.Data.Zones[1])
    L:Note("Zones for levels 30-60 aren't in the research yet (Wowhead zone pages were blocked).")
    L:Label("Dungeons near your level")
    local any = false
    for _, d in ipairs(ns.Data.Dungeons) do
        local lo, hi = bracketRange(d.levels)
        if lo and c.level >= lo - 3 and c.level <= hi then
            any = true
            L:Row({ chip = d.new_in_forever and { text = "New in Forever", kind = "info" } or nil, title = d.name, right = "levels " .. d.levels })
        end
    end
    if not any then L:Text(UI.Hex(UI.C.dim) .. "None in range right now.|r") end
    L:Note("Dungeon enemy XP was raised 50% on Nov 8.")
    L:Label("New zones in Forever")
    for _, z in ipairs(ns.Data.NewZones) do
        L:Row({ title = z.zone .. (z.subzone and (": " .. z.subzone) or ""), right = z.levels and ("levels " .. z.levels) or nil, sub = (z.notes and z.notes ~= "") and z.notes or nil })
    end
    L:Label("Professions")
    local pr = ns.Data.Professions
    L:Row({ title = "While leveling: " .. tostring(pr.leveling or "?"), sub = "For raiding: " .. tostring(pr.raiding or "?") .. " · Alternatives: " .. table.concat(pr.alternatives or {}, ", ") })
    if pr.pvp_note then L:Row({ title = "For PvP", sub = pr.pvp_note }) end
    L:Source(pr)
end

UI.RegisterPanel({
    key = "leveling", label = "Leveling",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("Leveling", ("Level %d %s"):format(c.level, c.spec and (c.spec .. " Paladin") or "Paladin"))
        local items = {}
        for _, t in ipairs(TABS) do
            table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end })
        end
        L:Tabs(items)
        local fn = S[tab] or S.Path
        fn(L, c)
    end,
})
