-- Leveling › Trainer
local _, ns = ...
local UI = ns.UI

UI.LevelingSections = UI.LevelingSections or {}

UI.LevelingSections.Trainer = function(L, c)
    local now = ns.Training.At(c.level, c.spec)
    local nextLvl = ns.Training.NextLevel(c.level, c.spec)
    local names = ns.Training.Names
    local cards = {}
    if #now > 0 then table.insert(cards, { label = "Train now (level " .. c.level .. ")", title = #now .. " spell" .. (#now == 1 and "" or "s"), body = names(now) }) end
    if nextLvl then table.insert(cards, { label = "Next visit", title = "Level " .. nextLvl, body = names(ns.Training.At(nextLvl, c.spec)) }) end
    local costs = ns.Data.Milestones.trainer_costs
    local total = costs and costs:match("~?(%d+%s*[-–]%s*%d+g)")
    if total then
        table.insert(cards, { label = "Cost", title = "~" .. total .. " for 1-60", body = "Total for all ranks, same for every class. Per-rank costs aren't published." })
    end
    L:CardRow(cards)
    L:Note(costs)

    L:Label("All spells")
    for _, s in ipairs(ns.Data.Spells) do
      if not (s.faction and c.faction and s.faction ~= c.faction) then
        local rank = ns.Training.RankAt(s, c.level)
        local total = #s.rank_learn_levels
        local nextRank = s.rank_learn_levels[rank + 1]
        local key = c.spec and ns.Training.IsKey(s, c.spec)
        local talentOther = s.talent and not ns.Training.Applies(s, c.spec, c.faction)
        local chip
        if key then chip = { text = "Key for " .. c.spec, kind = "info" } end
        if s.talent then chip = { text = (s.talent_tree or "") .. " talent", kind = "neutral" } end
        local sub = s.levels_unknown and "Learn level not in the research yet (gap)" or ("Ranks at " .. table.concat(s.rank_learn_levels, ", "))
        if s.notes then L:Note(s.display .. ": " .. s.notes) end
        local right = rank > 0 and ("rank %d/%d"):format(rank, total) or (s.rank_learn_levels[1] and ("at level " .. s.rank_learn_levels[1]) or "level not in research")
        if nextRank and rank > 0 then right = right .. UI.Hex(UI.C.dim) .. (" · next at %d|r"):format(nextRank) end
        L:Spell(s.wowhead_base_spell_id, (talentOther and UI.Hex(UI.C.dim) or "") .. s.display .. (talentOther and "|r" or ""), sub, right, nil, chip and { chip = chip } or nil)
      end
    end
    L:Source(ns.Data.Spells[1])
end
