-- Leveling › Riding & gold
local _, ns = ...
local UI = ns.UI

UI.LevelingSections = UI.LevelingSections or {}

UI.LevelingSections["Riding & gold"] = function(L, c)
    local money = GetMoney()
    local gold = math.floor(money / 10000)
    local cards = {}
    for _, g in ipairs(ns.Progress.GoldGoals()) do
        local known = ns.Progress.KnowsSpell(g.spell_id)
        table.insert(cards, {
            label = g.name .. " · level " .. g.level,
            title = known and "Learned" or ("%dg of %dg"):format(math.min(gold, g.gold), g.gold),
            progress = not known and { value = gold, max = g.gold } or nil,
            body = ("%s speed · mount: %s"):format(g.speed or "?", g.mount or "?")
                .. (not known and c.level < g.level and (" · in " .. (g.level - c.level) .. " levels") or ""),
        })
    end
    L:Text(("You have %s."):format(ns.Progress.MoneyText(money)), { size = 14 })
    L:CardRow(cards)
    local notes = ns.Progress.RidingNotes()
    if notes then L:Text(UI.Hex(UI.C.dim) .. notes.notes .. "|r", { size = 12 }) end
    L:Flag("Reports say quests give no gold at level 60 (not officially confirmed). Plan your 1000g before 60.")
    L:Source(ns.Data.Riding[1])

    L:Label("Your riding trainer & first mount")
    local m = ns.Progress.MountForRace(c.race)
    if m then
        local done = m.quest_id and ns.Progress.IsQuestDone(m.quest_id)
        if m.trainer then L:Row({ title = "Trainer: " .. m.trainer, sub = m.location }) end
        if m.vendor then L:Row({ title = "Vendor: " .. m.vendor }) end
        if m.first_mount_quest then
            L:Row({ chip = done and { text = "Done", kind = "good" } or { text = "Level 40", kind = "neutral" },
                title = "First mount quest: " .. m.first_mount_quest, sub = (m.quest_id and ("Quest #" .. m.quest_id .. " · ") or "") .. "your first mount is free" })
        end
        if m.notes and m.race ~= "Any" then L:Text(UI.Hex(UI.C.dim) .. m.notes .. "|r", { size = 12 }) end
        if (m.mount_item_ids and #m.mount_item_ids > 0) or (m.epic_mount_item_ids and #m.epic_mount_item_ids > 0) then L:Label("Mounts sold") end
        for _, id in ipairs(m.mount_item_ids or {}) do L:Item(id, (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("Item " .. id), "Apprentice mount") end
        for _, id in ipairs(m.epic_mount_item_ids or {}) do L:Item(id, (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("Item " .. id), "Epic mount (Journeyman)") end
        L:Source(m)
    else
        L:Row({ chip = { text = "Gap", kind = "warn" }, title = "No " .. (c.race or "?") .. " riding trainer or vendor in the research yet",
            sub = "The addon doesn't guess where it is. Riding costs above apply to every race." })
    end
    for _, x in ipairs(ns.Data.Mounts) do
        if x.race == "Any" then L:Note(x.notes) end
    end
    L:Note("Paladin class mount quests (40 and 60) aren't confirmed for Forever yet; Leveling > Class quests lists them as unconfirmed.")
end
