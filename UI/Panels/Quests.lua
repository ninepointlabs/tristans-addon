-- Leveling › Class quests
local _, ns = ...
local UI = ns.UI

UI.LevelingSections = UI.LevelingSections or {}
local showAll = false

UI.LevelingSections["Class quests"] = function(L, c)
    L:Buttons({
        { label = "Mine (" .. (c.race or "?") .. ", " .. (c.faction or "?") .. ")", active = not showAll, onClick = function() showAll = false UI.Refresh() end },
        { label = "All races & factions", active = showAll, onClick = function() showAll = true UI.Refresh() end },
    })
    L:Text(UI.Hex(UI.C.dim) .. "Paladin class quests: Redemption at 12 (do it before you join groups), Verigan's Fist at 20 and the Cloak of the Divine Storm at 22. The other faction's quests stay hidden.|r", { size = 12 })
    local race = not showAll and c.race or nil
    local faction = not showAll and c.faction or nil
    local list = ns.Progress.ClassQuests(race, faction)
    if #list == 0 then L:Text("No class quests in the research for you yet.") end
    for _, q in ipairs(list) do
        local done = ns.Progress.IsQuestDone(q.quest_id)
        local chip
        if done then chip = { text = "Done", kind = "good" }
        elseif q.missing and c.level >= (q.level or 0) then chip = { text = "Ready · ID unknown", kind = "warn" }
        elseif q.missing then chip = { text = "Level " .. (q.level or "?") .. " · ID unknown", kind = "neutral" }
        elseif c.level >= (q.level or 0) then chip = { text = "Ready", kind = "info" }
        else chip = { text = "Level " .. (q.level or "?"), kind = "neutral" } end
        local sub = {}
        if showAll then table.insert(sub, (q.races or "All") .. (q.faction and q.faction ~= "Both" and (" · " .. q.faction) or "")) end
        if q.start_npc then table.insert(sub, "From " .. q.start_npc) end
        if q.zone then table.insert(sub, q.zone) end
        if q.reward_spell then table.insert(sub, "Teaches " .. q.reward_spell) end
        if q.reward then table.insert(sub, "Reward: " .. q.reward) end
        if q.unconfirmed then table.insert(sub, UI.FLAG_ICON .. " " .. UI.Hex(UI.C.warn) .. (q.flag or "unconfirmed") .. "|r") end
        if q.notes then table.insert(sub, q.notes) end
        if q.missing then L:Note(q.name .. ": quest ID not captured in the research, so completion can't be checked.") end
        L:Row({
            chip = chip, title = q.name, sub = table.concat(sub, " · "),
            right = "level " .. (q.level or "?") .. (q.quest_id and (" · #" .. q.quest_id) or ""),
            onEnter = q.reward_item_id and function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(q.reward_item_id)
                GameTooltip:Show()
            end or nil,
        })
        L:Source(q)
    end
    local t = ns.Data.ClassTrainers
    if t and t.trainers then
        L:Label("Paladin trainers")
        L:Text(table.concat(t.trainers, " · "), { size = 12 })
        L:Source(t)
    end
end
