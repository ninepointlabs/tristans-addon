-- Gear: best researched item per slot (left) + details of the selected item
-- (right): what it gives you, how to get it, map pins.
local _, ns = ...
local UI = ns.UI

local SLOT_NAMES = {
    INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest",
    INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands",
    INVTYPE_FINGER = "Ring", INVTYPE_TRINKET = "Trinket", INVTYPE_CLOAK = "Back", INVTYPE_WEAPON = "One-hand",
    INVTYPE_WEAPONMAINHAND = "Main hand", INVTYPE_2HWEAPON = "Two-hand", INVTYPE_HOLDABLE = "Off hand",
    INVTYPE_SHIELD = "Shield", INVTYPE_RELIC = "Libram", INVTYPE_WEAPONOFFHAND = "Off hand",
}

local SLOT_GROUPS = {
    { "Head", { INVTYPE_HEAD = true } }, { "Neck", { INVTYPE_NECK = true } },
    { "Shoulder", { INVTYPE_SHOULDER = true } }, { "Back", { INVTYPE_CLOAK = true } },
    { "Chest", { INVTYPE_CHEST = true, INVTYPE_ROBE = true } }, { "Wrist", { INVTYPE_WRIST = true } },
    { "Hands", { INVTYPE_HAND = true } }, { "Waist", { INVTYPE_WAIST = true } },
    { "Legs", { INVTYPE_LEGS = true } }, { "Feet", { INVTYPE_FEET = true } },
    { "Ring", { INVTYPE_FINGER = true } }, { "Trinket", { INVTYPE_TRINKET = true } },
    { "Weapon", { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true } },
    { "Off hand", { INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true } },
    { "Libram", { INVTYPE_RELIC = true } },
}

local TABS = { "For my level", "Best overall", "By bracket", "Consumables", "Weights" }
local tab = "For my level"
local bracketSel
local detailId -- selected item (nil = first in the list)

UI.OpenGearDetail = function(id) detailId = id end
function UI.SetGearView(v)
    tab = (v == "best" and "Best overall") or (v == "bracket" and "By bracket") or "For my level"
end

-- "req. 13" when the item itself requires it; "from level 20" when it comes from the source.
local function levelText(it)
    if (it.itemLevelReq or 0) >= (it.minLevel or 1) and (it.itemLevelReq or 0) > 1 then return "req. " .. it.itemLevelReq end
    return "from level " .. (it.minLevel or 1)
end

local function pick(id)
    return function() detailId = id UI.Refresh() end
end

local function researchLabels(id)
    local out = {}
    for bracket, list in pairs(ns.Data.GearBrackets) do
        for _, g in ipairs(list) do
            if g.item_id == id then table.insert(out, { bracket = bracket, source = g.source, rec = g }) end
        end
    end
    return out
end

local function findDungeon(label)
    if not label then return nil end
    local key = ns.Map.Norm(label)
    key = ns.Map.DUNGEON_ALIASES[key] or key
    for _, d in ipairs(ns.Data.Dungeons) do
        local dn = ns.Map.Norm(d.name)
        if dn == key or dn:find(key, 1, true) or (key:find("scarlet monastery", 1, true) and dn:find("^sm ")) then return d end
    end
    return nil
end

-- The level an item is realistically available at. Many quest rewards and
-- crafted items carry no level requirement ("req. 0" in Tim's screenshot), so
-- also use the source: the quest's minimum level, the dungeon's level range,
-- or the research gear list's bracket (a "level 30" list item: from level 20).
local function sourceLevel(id, minLevel)
    local lvl = minLevel or 1
    local src = ns.Data.ItemSources[id]
    for _, q in ipairs(src and src.quests or {}) do
        local qd = ns.Data.QuestSources[q.quest_id]
        if qd and qd.min_level then lvl = math.max(lvl, qd.min_level) end
    end
    local labels = researchLabels(id)
    local dungeon = labels[1] and findDungeon(labels[1].source)
    if dungeon and src and src.drops then
        lvl = math.max(lvl, tonumber(dungeon.levels:match("^(%d+)")) or 1)
    end
    if lvl <= 1 then
        for _, l in ipairs(labels) do
            local b = tonumber((l.bracket or ""):match("(%d+)"))
            if b then lvl = math.max(lvl, b - 10) end
        end
    end
    return lvl
end
UI.GearSourceLevel = sourceLevel

-- Compare chip for an item vs. what's equipped.
local function compareChip(id, c, atLevel)
    local _, link = C_Item.GetItemInfo(id)
    if not link then return { text = "...", kind = "neutral" } end
    local res = ns.Stats.Compare(link, c.spec, c.level, c.profile, ns.db.global.percentScale)
    if not res or res.pending then return { text = "...", kind = "neutral" } end
    if res.unusable then return { text = "Not for paladins", kind = "neutral" } end
    if res.isEquipped then return { text = "Equipped", kind = "neutral" } end
    if res.against and res.against.empty then return { text = "Upgrade", kind = "good" } end
    if not res.delta then return nil end
    local need = math.max(res.minLevel or 1, atLevel or 1)
    if need > c.level and res.delta > 0.05 then return { text = "At " .. need, kind = "warn" } end
    if res.delta > 0.05 then return { text = (res.pct and res.pct < 300) and ("+%.0f%%"):format(res.pct) or "Upgrade", kind = "good" } end
    if res.delta < -0.05 then return { text = (res.pct and res.pct > -300) and ("%.0f%%"):format(res.pct) or "Worse", kind = "bad" } end
    return { text = "Same", kind = "neutral" }
end

-- Items the research marks as one faction's only (e.g. Staff of Orgrimmar from
-- Ragefire Chasm) aren't offered to the other faction.
local function otherFaction(rec)
    local f = rec and rec.faction
    if not f or f == "Both" then return false end
    local mine = UnitFactionGroup("player")
    return mine ~= nil and f ~= mine
end
ns.GearOtherFaction = otherFaction

-- Every researched item (gear lists), deduped.
local function candidates()
    local seen, out = {}, {}
    local function add(id, name, source, bracket)
        if not id then return end
        if seen[id] then
            if bracket and not seen[id].bracket then seen[id].bracket = bracket end
            return
        end
        seen[id] = { id = id, name = name, source = source, bracket = bracket }
        table.insert(out, seen[id])
    end
    local spec = ns.DB.ActiveSpec()
    for bracket, list in pairs(ns.Data.GearBrackets) do
        for _, g in ipairs(list) do
            if (not g.spec or not spec or g.spec == spec) and not otherFaction(g) then add(g.item_id, g.name, g.source, bracket) end
        end
    end
    return out
end

-- Slot, required level and spec score; false if the client hasn't cached it yet.
local function evaluate(it, c)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(it.id)
    it.equipLoc = equipLoc
    local _, link, _, _, minLevel = C_Item.GetItemInfo(it.id)
    if not link then
        if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, it.id) end
        return false
    end
    it.link = link
    it.itemLevelReq = minLevel or 0
    it.minLevel = sourceLevel(it.id, minLevel)
    local res = ns.Stats.Compare(link, c.spec, c.level, c.profile, ns.db.global.percentScale)
    if not res or res.pending then return false end
    it.res = res
    it.score = res.score or 0
    return true
end

-- Per slot: items sorted best first (filtered by level for "mine").
local function slotLists(c, mine)
    local ready, pending, soon = {}, 0, {}
    for _, it in ipairs(candidates()) do
        if evaluate(it, c) then
            if not it.res.unusable then table.insert(ready, it) end
        else
            pending = pending + 1
        end
    end
    local slots = {}
    for _, group in ipairs(SLOT_GROUPS) do
        local list = {}
        for _, it in ipairs(ready) do
            if group[2][it.equipLoc] then
                if not mine or it.minLevel <= c.level then
                    table.insert(list, it)
                elseif it.minLevel <= c.level + 5 then
                    table.insert(soon, it)
                end
            end
        end
        table.sort(list, function(a, b) return a.score > b.score end)
        if #list > 0 then table.insert(slots, { name = group[1], items = list }) end
    end
    table.sort(soon, function(a, b) return a.minLevel < b.minLevel end)
    return slots, pending, soon
end

----------------------------------------------------------------------------
-- Detail panel
----------------------------------------------------------------------------
local function renderDetail(L, c, id, others)
    local name, link, _, _, minLevel = C_Item.GetItemInfo(id)
    local labels = researchLabels(id)
    name = name or (labels[1] and labels[1].rec.name) or ("Item " .. id)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(id)
    L:Item(id, name, (SLOT_NAMES[equipLoc] or "") .. (minLevel and (" · requires level " .. minLevel) or ""), nil, nil,
        { chip = compareChip(id, c) })

    if link then
        local lines = ns.Tooltip.LinesFor(link, c.spec, c.profile, c.level, ns.db.global.percentScale)
        for i = 2, #lines - 1 do L:Text(lines[i], { size = 12 }) end -- skip header + footnote
    else
        L:Text(UI.Hex(UI.C.dim) .. "Loading item data...|r", { size = 12 })
    end

    L:Label("How to get it")
    local src = ns.Data.ItemSources[id]
    local any = false
    local researchLabel = labels[1] and labels[1].source

    for _, d in ipairs(src and src.drops or {}) do
        any = true
        local dungeon = findDungeon(researchLabel)
        local where = dungeon and (" in " .. dungeon.name) or ""
        L:Text("Drops from " .. d.npc .. where, { size = 14 })
        L:Text(UI.Hex(UI.C.dim) .. (d.chance and (d.chance .. " drop chance") or "drop chance unknown")
            .. (dungeon and (" · dungeon levels " .. dungeon.levels .. (dungeon.new_in_forever and " · new in Forever" or "")) or "") .. "|r", { size = 12 })
        if dungeon then
            if c.level < (tonumber(dungeon.levels:match("^(%d+)")) or 0) then
                L:Text(UI.Hex(UI.C.warn) .. "You're below this dungeon's level range.|r", { size = 12 })
            end
            local e = ns.Map.FindDungeonEntrance(dungeon.name)
            if e then
                L:Text(UI.Hex(UI.C.dim) .. ("Entrance: %s (%s %.1f, %.1f)"):format(e.name, ns.Map.MapName(e.mapID), e.x * 100, e.y * 100) .. "|r", { size = 12 })
                L:Buttons({
                    { label = "Mark entrance on map", onClick = function() ns.Map.SetWaypoint(e.mapID, e.x, e.y, e.name .. " entrance") end },
                    { label = "Open map", onClick = function() ns.Map.Open(e.mapID) end },
                })
            else
                L:Note(dungeon.name .. ": the game's map data didn't return an entrance, so it can't be pinned.")
            end
        end
    end

    local playerFaction = c.faction
    for _, q in ipairs(src and src.quests or {}) do
        any = true
        local qd = ns.Data.QuestSources[q.quest_id] or {}
        local done = ns.Progress.IsQuestDone(q.quest_id)
        L:Text((done and (UI.CHECK_ICON .. " ") or "") .. "Quest reward: " .. q.name .. (q.choice and " (choose it)" or ""), { size = 14 })
        local parts = {}
        if qd.level then table.insert(parts, "level " .. qd.level) end
        if qd.min_level then table.insert(parts, "from level " .. qd.min_level) end
        local factionOnly = qd.faction and qd.faction ~= "Both" and qd.faction
        if factionOnly then table.insert(parts, factionOnly .. " only") end
        table.insert(parts, "quest #" .. q.quest_id)
        L:Text(UI.Hex(UI.C.dim) .. table.concat(parts, " · ") .. "|r", { size = 12 })
        if qd.start_npc then L:Text("Starts with " .. qd.start_npc .. (qd.zone and (" in " .. qd.zone) or ""), { size = 12 }) end
        if done then L:Text(UI.Hex(UI.C.good) .. "You've already completed this quest.|r", { size = 12 }) end
        if factionOnly and playerFaction and factionOnly ~= playerFaction then L:Text(UI.Hex(UI.C.bad) .. "Not available to " .. playerFaction .. ".|r", { size = 12 }) end
        local pins, seenLabel = {}, {}
        for _, pin in ipairs(qd.pins or {}) do
            if not seenLabel[pin.label] then
                seenLabel[pin.label] = true
                table.insert(pins, pin)
            end
        end
        table.sort(pins, function(a, b)
            local as, bs = a.label:find("^Start") and 0 or 1, b.label:find("^Start") and 0 or 1
            return as < bs
        end)
        local btns = {}
        for _, pin in ipairs(pins) do
            local zone = pin.zone or qd.zone
            local mapID = ns.Map.FindZone(zone)
            L:Text(UI.Hex(UI.C.dim) .. ("%s: %s %.1f, %.1f"):format(pin.label, zone or "?", pin.x, pin.y) .. "|r", { size = 12 })
            if mapID and #btns < 2 then
                local who = pin.label:gsub("^[^:]*:%s*", "")
                table.insert(btns, { label = (pin.label:find("^Start") and "Mark quest giver" or ("Mark " .. who)), onClick = function()
                    ns.Map.SetWaypoint(mapID, pin.x / 100, pin.y / 100, pin.label)
                end })
            elseif not mapID then
                L:Note("Couldn't match zone '" .. tostring(zone) .. "' to a game map, so it can't be pinned.")
            end
        end
        if #btns > 0 then L:Buttons(btns) end
        if not qd.pins and qd.zone then L:Note(q.name .. ": no coordinates published yet.") end
        if qd.source_url then L:Source(qd) end
    end
    local rq = researchLabel and tonumber(researchLabel:match("Quest (%d+)"))
    if rq and src and src.quests then
        local match = false
        for _, q in ipairs(src.quests) do if q.quest_id == rq then match = true end end
        if not match then L:Note(("The gear guide lists quest %d; the Icy Veins DB lists the quest(s) above. Same chain, different step?"):format(rq)) end
    end

    if src and src.crafted then
        any = true
        local cr = src.crafted
        local reagents = {}
        for _, r in ipairs(cr.reagents or {}) do table.insert(reagents, r.count .. " " .. r.name) end
        L:Text("Crafted with " .. cr.profession .. (cr.skill and (" (skill " .. cr.skill .. ")") or ""), { size = 14 })
        L:Text(UI.Hex(UI.C.dim) .. (#reagents > 0 and table.concat(reagents, ", ") or "Reagents not listed") .. "|r", { size = 12 })
        L:Text(UI.Hex(UI.C.dim) .. "Make it yourself or ask a " .. cr.profession:lower() .. " crafter.|r", { size = 12 })
    end
    for _, v in ipairs(src and src.sold_by or {}) do
        any = true
        L:Text("Sold by " .. v.npc, { size = 14 })
    end
    if not any then
        L:Text("Gear guide says: " .. (researchLabel or "?"), { size = 13 })
        local dungeon = findDungeon(researchLabel)
        local e = dungeon and ns.Map.FindDungeonEntrance(dungeon.name)
        if e then L:Buttons({ { label = "Mark " .. dungeon.name .. " entrance", onClick = function() ns.Map.SetWaypoint(e.mapID, e.x, e.y, e.name .. " entrance") end } }) end
        L:Note(name .. ": the Icy Veins item database (early access) doesn't list a source yet.")
    end
    if src then L:Source(src) end
    if labels[1] then L:Source(labels[1].rec) end

    if others and #others > 0 then
        L:Label("Other options for this slot")
        for i, it in ipairs(others) do
            if i > 3 then break end
            L:Item(it.id, it.name, (it.source or "") .. " · " .. levelText(it), nil, pick(it.id), { chip = compareChip(it.id, c, it.minLevel) })
        end
    end
end

----------------------------------------------------------------------------
-- Tab renderers
----------------------------------------------------------------------------
local function renderSlotsTab(L, c, mine)
    local slots, pending, soon = slotLists(c, mine)
    -- Selected item: an explicit choice (even if it's not in this list, e.g. opened
    -- from search), else the first upgrade, else the first item.
    local selected, selectedSlot
    if detailId then
        selected = detailId
        for _, s in ipairs(slots) do
            for _, it in ipairs(s.items) do
                if it.id == detailId then selectedSlot = s end
            end
        end
    else
        for _, s in ipairs(slots) do
            local chip = compareChip(s.items[1].id, c, s.items[1].minLevel)
            if chip and chip.kind == "good" then selected, selectedSlot = s.items[1].id, s break end
        end
        if not selected and slots[1] then selected, selectedSlot = slots[1].items[1].id, slots[1] end
    end

    L:Columns({ 0.52, 0.48 })
    L:Text(UI.Hex(UI.C.dim) .. (mine and ("Best item per slot you can wear at level " .. c.level .. ".")
        or "Best researched item per slot, any level.") .. " Click one for details.|r", { size = 12 })
    if pending > 0 then L:Text(UI.Hex(UI.C.dim) .. pending .. " item(s) still loading...|r", { size = 12 }) end
    for _, s in ipairs(slots) do
        local it = s.items[1]
        local sub = (it.source or "") .. " · " .. levelText(it) .. (#s.items > 1 and (" · " .. (#s.items - 1) .. " more") or "")
        L:Item(it.id, s.name .. ": " .. it.name, sub, nil, pick(it.id), { chip = compareChip(it.id, c, it.minLevel),
            tint = it.id == selected and UI.Accent() or nil })
    end
    if #slots == 0 and pending == 0 then L:Text("No researched gear fits this view yet.") end
    if mine and #soon > 0 then
        L:Label("Coming up (next 5 levels)")
        for _, it in ipairs(soon) do
            L:Item(it.id, it.name, (it.source or "") .. " · " .. levelText(it), nil, pick(it.id), { chip = compareChip(it.id, c, it.minLevel),
                tint = it.id == selected and UI.Accent() or nil })
        end
    end
    L:NextColumn()
    if selected then
        local others = {}
        for _, it in ipairs(selectedSlot and selectedSlot.items or {}) do
            if it.id ~= selected then table.insert(others, it) end
        end
        renderDetail(L, c, selected, others)
    end
    L:EndColumns()
    L:Note("Gear lists come from the research (Icy Veins Paladin leveling and Retribution gear pages). Brackets without a published list show as 'not published yet'; raid BiS waits for raids (Dec 9).")
end

local function renderBracketTab(L, c)
    local order = ns.Data.GearBracketOrder
    bracketSel = bracketSel or (c.level >= 25 and "level 30" or "level 20")
    local items = {}
    for _, b in ipairs(order) do
        table.insert(items, { label = (b:gsub("^level ", "Level ")), active = bracketSel == b, onClick = function() bracketSel = b UI.Refresh() end })
    end
    L:Buttons(items)
    local list = ns.Data.GearBrackets[bracketSel]
    if bracketSel == "raid BiS" then
        local bis = ns.Data.BiS
        L:Flag(bis.status)
        L:Text("Raids open " .. (ns.Data.Raids[1] and ns.Data.Raids[1].opens or "?") .. ". Raid rule: item stats are hidden until first looted.")
        L:Label("Tier 1 set bonuses (datamined placeholder)")
        L:Note(bis.flag)
        for role, bonuses in pairs(bis.tier1_datamined_placeholder or {}) do
            local lines = {}
            for pieces = 2, 8 do
                local b = bonuses[tostring(pieces)] or bonuses[pieces]
                if b then table.insert(lines, ("(%d) %s"):format(pieces, b)) end
            end
            L:Row({ title = (tostring(role):gsub("^%l", string.upper)) .. " set", sub = table.concat(lines, "\n") })
        end
        L:Source(bis)
        return
    elseif not list then
        L:Row({ chip = { text = "Not published yet", kind = "warn" }, title = "No Paladin gear guide for this bracket yet",
            sub = "It fills in automatically when the research gains it." })
        return
    end
    local bySource, sourcesOrder = {}, {}
    for _, g in ipairs(list) do
      if (not g.spec or not c.spec or g.spec == c.spec) and not otherFaction(g) then
        local src = g.source or "?"
        if not bySource[src] then bySource[src] = {} table.insert(sourcesOrder, src) end
        table.insert(bySource[src], g)
      end
    end
    for _, src in ipairs(sourcesOrder) do
        L:Label(src)
        for _, g in ipairs(bySource[src]) do
            local _, _, _, equipLoc = C_Item.GetItemInfoInstant(g.item_id)
            L:Item(g.item_id, g.name, SLOT_NAMES[equipLoc] or "", nil, function() detailId = g.item_id tab = "Best overall" UI.Refresh() end,
                { chip = compareChip(g.item_id, c) })
        end
    end
    L:Source(list[1])
    if ns.Data.OtherWeapons.note and ns.Data.OtherWeapons.note ~= "" then L:Note(ns.Data.OtherWeapons.note) end
end

local function renderConsumablesTab(L, c)
    L:Label("For your level")
    for _, e in ipairs(ns.Reminders.Consumables(c.level)) do
        L:Item(e.item.item_id, e.item.name, e.item.bracket, e.count .. " in bags", nil,
            { chip = e.current and { text = "Your level", kind = "good" } or nil })
    end
    L:Label("Enchants")
    for _, e in ipairs(ns.Data.Consumables) do
        if e.type == "enchant" then L:Spell(e.spell_id, (e.slot or "") .. ": " .. e.name) end
    end
    L:Label("Camp items")
    for _, e in ipairs(ns.Data.Consumables) do
        if e.type == "camp" then
            L:Item(e.item_id, e.name, ((e.profession and e.profession ~= "") and e.profession or "Any profession") .. ((e.notes and e.notes ~= "") and (" · " .. e.notes) or ""))
        elseif e.type == "note" then
            L:Note(e.name .. ": " .. (e.notes or ""))
        end
    end
end

local function renderWeightsTab(L, c)
    local setName = ns.Stats.WeightSetName(c.spec, c.level, c.profile)
    local prio = ns.Data.StatPriority[setName]
    L:Text("Gear tips use " .. UI.Hex(UI.Accent()) .. setName .. "|r weights" .. (c.spec and (" for " .. c.spec) or "") .. ".", { size = 14 })
    if prio then
        L:Label("Stat priority")
        L:Text(prio.text)
        local weights = ns.Stats.Weights(setName, ns.db.global.percentScale, c.profile.weights, c.profile.pvpWeights)
        L:Label("Weight per point")
        for _, k in ipairs(prio.keys) do
            L:Row({ title = ns.Stats.LABELS[k], right = ("%.2f"):format(weights[k]) })
        end
        if c.profile.pvpWeights and not (function() for _, k in ipairs(prio.keys) do if k == "STA" then return true end end return false end)() then
            L:Row({ title = ns.Stats.LABELS.STA .. " (PvP)", right = ("%.2f"):format(weights.STA) })
        end
        L:Source(prio)
        L:Note("Weights come from the priority ORDER (rank-based), not simulations. Hit/crit % use an assumed " .. ns.db.global.percentScale .. " points per 1% (Settings).")
    end
    L:Space(6)
    L:Check("PvP weights: Stamina first", c.profile.pvpWeights, function(v)
        c.profile.pvpWeights = v
        ns.Stats.ClearCache()
        ns.Bags.Reset()
        UI.Refresh()
    end, "For battlegrounds and world PvP: Stamina moves to the top of your spec's priority (an addon choice). PvP armor comes from Honor: Battle > Honor & Rank.")
    local lev = ns.Data.StatPriority.Leveling
    if c.spec and lev then
        local useLeveling = c.profile.levelingWeights or false
        L:Space(6)
        L:Check("Use leveling weights below 60", useLeveling, function(v)
            c.profile.levelingWeights = v
            ns.Stats.ClearCache()
            UI.Refresh()
        end, "Leveling priority: " .. lev.text)
    end
end

UI.RegisterPanel({
    key = "gear", label = "Gear",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("Gear", c.spec and ("Scored for " .. c.spec .. " · click an item for where and how to get it") or "Pick a spec for spec-specific scores")
        local items = {}
        for _, t in ipairs(TABS) do
            table.insert(items, { label = t, active = tab == t, onClick = function() tab = t detailId = nil UI.Refresh() end })
        end
        L:Tabs(items)
        if tab == "For my level" then renderSlotsTab(L, c, true)
        elseif tab == "Best overall" then renderSlotsTab(L, c, false)
        elseif tab == "By bracket" then renderBracketTab(L, c)
        elseif tab == "Consumables" then renderConsumablesTab(L, c)
        else renderWeightsTab(L, c) end
    end,
})
