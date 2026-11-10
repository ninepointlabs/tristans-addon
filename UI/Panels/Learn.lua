local _, ns = ...
local UI = ns.UI

local section = "lessons"
local SECTIONS = {
    { "lessons", "Lessons" }, { "spells", "Spells" }, { "talents", "Talents" }, { "mechanics", "How the class works" },
    { "roles", "In a group" }, { "pvp", "PvP basics" }, { "leveling", "Leveling" }, { "mistakes", "Common mistakes" },
}

local function flagText(e)
    if e and e.unconfirmed then
        return "\n" .. UI.FLAG_ICON .. " " .. UI.Hex(UI.C.warn) .. ((e.flag and e.flag ~= "") and e.flag or "Unconfirmed") .. "|r"
    end
    return ""
end

local function sources(L, e)
    for _, s in ipairs(e and e.sources or {}) do L:Source({ source_url = s }) end
end

local function article(L, e)
    L:Text((e.title and (UI.Hex(UI.Accent()) .. e.title .. "|r\n") or "") .. (e.body or "") .. flagText(e))
    sources(L, e)
    L:Space(4)
end

local render = {}

function render.lessons(L, c, content)
    local unlocked, upcoming = ns.Learn.Lessons(c.level, c.spec)
    local read = ns.db.char.learn.readLessons
    L:Buttons({ { label = "Mark all read", onClick = function()
        for _, l in ipairs(unlocked) do read[l.id] = true end
        UI.Refresh()
    end } }, 120)
    L:Label("Unlocked (" .. #unlocked .. ")")
    for _, l in ipairs(unlocked) do
        local new = not read[l.id]
        local row = L:Row({ icon = "Interface\\Icons\\INV_Misc_Book_07", title = (new and (UI.Hex(UI.C.good) .. "NEW|r  ") or "") .. l.title,
            sub = (l.body or "") .. flagText(l), right = "lvl " .. l.level .. (l.spec ~= "any" and (" · " .. l.spec) or ""),
            onClick = function() read[l.id] = true UI.Refresh() end })
        row.tint = nil
    end
    if #upcoming > 0 then
        L:Label("Coming up")
        for _, l in ipairs(upcoming) do
            L:Row({ icon = "Interface\\Icons\\INV_Misc_Lock_01", title = UI.Hex(UI.C.dim) .. l.title .. "|r", right = "unlocks at " .. l.level })
        end
    end
end

function render.spells(L, c, content)
    L:Text(UI.Hex(UI.C.dim) .. "Every Paladin spell: what it does, when to use it, which rank, and how your spec uses it. Hover for the in-game tooltip.|r", { size = 11 })
    local list = {}
    for _, s in ipairs(ns.Data.Spells) do
        if not (s.faction and c.faction and s.faction ~= c.faction) then
            table.insert(list, { name = s.name, display = s.display, id = s.wowhead_base_spell_id, spell = s })
        end
    end
    for _, it in ipairs(list) do
        local e = content.spells and (content.spells[it.name] or content.spells[it.display])
        local rank = it.spell and ns.Training.RankAt(it.spell, c.level) or nil
        local right = rank > 0 and ("rank %d/%d"):format(rank, #it.spell.rank_learn_levels) or (it.spell.rank_learn_levels[1] and ("at level " .. it.spell.rank_learn_levels[1]) or "level not in research")
        if it.spell.talent then right = it.spell.talent_tree and (it.spell.talent_tree .. " talent") or "talent" end
        local sub = ""
        if e then
            sub = (e.what or "")
            if e.when and e.when ~= "" then sub = sub .. "\n|cffd0d0d0When:|r " .. e.when end
            if e.rank_tip and e.rank_tip ~= "" then sub = sub .. "\n|cffd0d0d0Rank:|r " .. e.rank_tip end
            local ps = e.per_spec and c.spec and e.per_spec[c.spec]
            if ps and ps ~= "" then sub = sub .. "\n" .. UI.Hex(UI.Accent()) .. (c.spec or "") .. ":|r " .. ps end
            sub = sub .. flagText(e)
        else
            sub = UI.FLAG_ICON .. " No teaching text yet."
        end
        if it.spell and it.spell.notes then sub = sub .. "\n|cff9a9a9aResearch: " .. it.spell.notes .. "|r" end
        local key = c.spec and it.spell and ns.Training.IsKey(it.spell, c.spec)
        L:Spell(it.id, (key and (UI.Hex(UI.Accent()) .. "Key|r ") or "") .. it.display, sub, right)
    end
end

function render.talents(L, c, content)
    local tree = c.spec and ns.Specs[c.spec].tree
    local entries = {}
    for name, e in pairs(content.talents or {}) do table.insert(entries, { name = name, e = e }) end
    table.sort(entries, function(a, b)
        local at, bt = a.e.tree == tree and 0 or 1, b.e.tree == tree and 0 or 1
        if at ~= bt then return at < bt end
        if a.e.tree ~= b.e.tree then return (a.e.tree or "") < (b.e.tree or "") end
        return a.name < b.name
    end)
    L:Text(UI.Hex(UI.C.dim) .. "Talents in your spec's tree first. Milestones: " .. (ns.Data.Milestones.talent_milestones or "") .. "|r", { size = 11 })
    local lastTree
    for _, it in ipairs(entries) do
        if it.e.tree ~= lastTree then
            L:Label((it.e.tree or "Other") .. " tree")
            lastTree = it.e.tree
        end
        local id = ns.Rotation.SpellId(it.name)
        L:Spell(id, it.name, (it.e.what or "") .. ((it.e.why and it.e.why ~= "") and ("\n|cffd0d0d0Why:|r " .. it.e.why) or "") .. flagText(it.e))
    end
end

local function articles(key)
    return function(L, c, content)
        for _, e in ipairs(content[key] or {}) do
            if ns.Learn.SpecOk(e.spec, c.spec) then article(L, e) end
        end
    end
end
render.mechanics = articles("mechanics")
render.roles = articles("roles")
render.mistakes = articles("mistakes")

-- PvP basics: the lessons on the "pvp" track (Honor and Rank, world PvP on a PvP
-- realm, battleground objectives, Forbearance, no interrupt or slow), in level order.
function render.pvp(L, c, content)
    L:Text(UI.Hex(UI.C.dim) .. "The PvP lesson track. Locked ones open as you level; the Battle screen has the live tools.|r", { size = 11 })
    local read = ns.db.char.learn.readLessons
    local list = {}
    for _, l in ipairs(content.lessons or {}) do
        if l.track == "pvp" and ns.Learn.SpecOk(l.spec, c.spec) then table.insert(list, l) end
    end
    table.sort(list, function(a, b) return a.level < b.level end)
    for _, l in ipairs(list) do
        if l.level <= c.level then
            local new = not read[l.id]
            L:Row({ icon = "Interface\\Icons\\INV_BannerPVP_01", title = (new and (UI.Hex(UI.C.good) .. "NEW|r  ") or "") .. l.title,
                sub = (l.body or "") .. flagText(l), right = "lvl " .. l.level, onClick = function() read[l.id] = true UI.Refresh() end })
            sources(L, l)
        else
            L:Row({ icon = "Interface\\Icons\\INV_Misc_Lock_01", title = UI.Hex(UI.C.dim) .. l.title .. "|r", right = "unlocks at " .. l.level })
        end
    end
    if #list == 0 then L:Text("No PvP lessons in the content yet.") end
    L:Buttons({ { label = "Open Battle", onClick = function() UI.Select("battle") end } })
end

function render.leveling(L, c, content)
    for _, spec in ipairs(ns.SPEC_ORDER) do
        local list = content.leveling and content.leveling[spec]
        if list and (spec == c.spec or not c.spec) then
            L:Label("Leveling as " .. spec)
            for _, e in ipairs(list) do article(L, e) end
        end
    end
    L:Label("Other specs")
    for _, spec in ipairs(ns.SPEC_ORDER) do
        if spec ~= c.spec and content.leveling and content.leveling[spec] then
            L:Text(UI.Hex(UI.C.dim) .. spec .. ": " .. #content.leveling[spec] .. " tips (switch spec to read them in full).|r", { size = 11 })
        end
    end
    L:Text("Class quests are under Leveling > Class quests.", { color = UI.C.dim, size = 11 })
end

UI.RegisterPanel({
    key = "learn", label = "Learn the Paladin",
    setSub = function(sub)
        for _, s in ipairs(SECTIONS) do if s[2] == sub or s[1] == (sub or ""):lower() then section = s[1] end end
    end,
    badge = function()
        if not ns.DB.HasChosenSpec() then return 0 end
        return ns.Learn.UnreadLessonCount(UnitLevel("player"), ns.DB.ActiveSpec())
    end,
    render = function(L, c)
        L:Title("Learn the Paladin", "Everything about the class, unlocked as you level")
        local content = ns.Learn.Content()
        if not content then
            L:Flag("Teaching content missing: run tools/build_data.py with content/learn.json present.")
            return
        end
        local items = {}
        for _, s in ipairs(SECTIONS) do
            table.insert(items, { label = s[2], active = section == s[1], onClick = function() section = s[1] UI.Refresh() end })
        end
        L:Tabs(items)
        L:Note("Teaching content checked " .. (content.checked or "?") .. ". Entries marked with ! are facts the research couldn't confirm.")
        render[section](L, c, content)
    end,
})
