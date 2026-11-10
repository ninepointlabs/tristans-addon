-- Home: "Do next" cards, "Needs attention", rotation at a glance, latest news.
local _, ns = ...
local UI = ns.UI

local function trainerCard(c)
    local now = ns.Training.At(c.level, c.spec)
    local nextLvl = ns.Training.NextLevel(c.level, c.spec)
    local names = ns.Training.Names
    if #now > 0 then
        return { label = "Trainer", title = #now .. (#now == 1 and " spell" or " spells") .. " to train now", body = names(now),
            button = { label = "See trainer list", onClick = function() UI.Select("leveling", "Trainer") end } }
    elseif nextLvl then
        return { label = "Trainer", title = "Next visit at level " .. nextLvl, body = names(ns.Training.At(nextLvl, c.spec)),
            button = { label = "See trainer list", onClick = function() UI.Select("leveling", "Trainer") end } }
    end
    return { label = "Trainer", title = "All spells trained", body = "Nothing left to learn from the trainer.",
        button = { label = "Spell list", onClick = function() UI.Select("leveling", "Trainer") end } }
end

local function ridingCard(c)
    local goal = ns.Progress.NextGoldGoal(c.level)
    if not goal then
        return { label = "Riding", title = "All riding learned", body = "Nothing left to save for.",
            button = { label = "Riding & gold", onClick = function() UI.Select("leveling", "Riding & gold") end } }
    end
    local gold = math.floor(GetMoney() / 10000)
    return { label = "Riding at level " .. goal.level, title = ("%dg of %dg saved"):format(math.min(gold, goal.gold), goal.gold),
        progress = { value = gold, max = goal.gold },
        body = goal.name .. (c.level < goal.level and (" · in " .. (goal.level - c.level) .. " levels") or ""),
        button = { label = "Riding & gold", onClick = function() UI.Select("leveling", "Riding & gold") end } }
end

local function questCard(c)
    local q = ns.Progress.NextClassQuest(c.race, c.faction, c.level)
    if not q then
        return { label = "Class quests", title = "All done", body = "No open Paladin class quests for you right now.",
            button = { label = "Class quests", onClick = function() UI.Select("leveling", "Class quests") end } }
    end
    local body = "Level " .. q.level .. (q.reward_spell and (" · teaches " .. q.reward_spell) or "") .. (q.reward and (" · " .. q.reward) or "")
    if q.zone then body = body .. " · " .. q.zone end
    if q.missing then body = body .. " · quest ID not in the research yet" end
    return { label = "Class quest", title = q.name, body = body,
        button = { label = "Show quest", onClick = function() UI.Select("leveling", "Class quests") end } }
end

-- PvP card: Honor and rank progress, or where to look when the API won't say.
local function pvpCard(c)
    local rank = ns.PvP.Rank()
    local honor = ns.PvP.Honor()
    local open = function() UI.Select("battle", "Honor & Rank") end
    if not rank and not honor then
        return { label = "Honor & Rank", title = "Open Character > PvP",
            body = "This client doesn't hand rank or Honor to addons (yet): press C, then the Player vs. Player tab.",
            button = { label = "Battle", onClick = open } }
    end
    local nextR = ns.PvP.NextReward(rank and rank.rank or 0)
    local title = rank and (rank.rank > 0 and ("Rank " .. rank.rank .. (rank.name and (" · " .. rank.name) or "")) or "No rank yet") or "Rank hidden"
    local card = { label = "Honor & Rank", title = title,
        body = (honor and ("Honor: " .. honor.amount .. " · ") or "") .. (nextR and ("next: R" .. nextR.rank .. " " .. nextR.reward) or ""),
        button = { label = "Battle", onClick = open } }
    if rank and rank.progress then card.progress = { value = math.floor(rank.progress * 100), max = 100 } end
    return card
end

UI.RegisterPanel({
    key = "home", label = "Home",
    render = function(L, c)
        L:Title(("Welcome back, %s"):format(c.name or "Paladin"),
            ("Level %d %s %s Paladin · profile %s"):format(c.level, c.race or "", c.spec or "", ns.DB.ActiveId()))
        if not c.spec and c.level < 10 then
            L:Row({ chip = { text = "Spec", kind = "info" }, title = "No talents yet (they start at level 10)",
                sub = "Pick the spec you plan to level as; the plan is " .. ns.RECOMMENDED_LEVELING_SPEC .. ", then Retribution + Holy dual spec at 40.",
                button = { label = "Pick a spec", onClick = function() UI.ShowPicker() end } })
        end
        if c.level >= 40 and not ns.DualSpec.HasDualSpec() then
            L:Row({ chip = { text = "40", kind = "info" }, title = "Dual spec is available at your trainer",
                sub = "Retribution (A) for questing and burst, Holy (B) for battleground healing. Each profile keeps its own spec." })
        end
        local meta = ns.Data.Meta
        local build = select(1, GetBuildInfo())
        local fullBuild = build and (build .. "." .. (select(2, GetBuildInfo()) or "")) or "?"
        if meta and meta.latest_build_seen and not meta.latest_build_seen:find(fullBuild, 1, true) then
            L:Note(("Client build %s differs from the research snapshot (%s); data may be stale until the next recheck."):format(fullBuild, meta.latest_build_seen:match("^(%S+)") or "?"))
        end

        L:Label("Do next")
        L:CardRow({ trainerCard(c), ridingCard(c), questCard(c) })
        L:CardRow({ pvpCard(c), (function()
            local z = ns.PvP.Zone()
            local cta = ns.Data.PvP and ns.Data.PvP.call_to_arms
            if z and (z.kind == "contested" or z.kind == "hostile") then
                return { label = "World PvP", title = (z.kind == "hostile") and "Enemy territory" or "Contested zone", body = z.text,
                    button = { label = "World PvP", onClick = function() UI.Select("battle", "World PvP") end } }
            end
            return { label = "Call to Arms", title = "This week's battleground", body = (cta and cta.text) and ("Not readable by addons; check the in-game calendar. " .. cta.text) or "Not readable by addons; check the in-game calendar.",
                button = { label = "Battlegrounds", onClick = function() UI.Select("battle", "Battlegrounds") end } }
        end)() })

        L:Columns({ 0.5, 0.5 })
        L:Label("Needs attention")
        local any = false
        for _, r in ipairs(ns.Reminders.Missing()) do
            any = true
            local chip = (r.id == "redemption") and { text = "Quest", kind = "info" } or { text = r.id == "righteousFury" and "Threat" or "Buff", kind = "warn" }
            local title = r.label .. ((r.id == "redemption" or (r.id == "righteousFury" and c.spec ~= "Protection")) and "" or " is missing")
            local btn = (r.id == "redemption") and { label = "Quest", onClick = function() UI.Select("leveling", "Class quests") end } or nil
            L:Row({ chip = chip, title = title, sub = r.detail, button = btn })
        end
        local ups = ns.Bags.Upgrades()
        if #ups > 0 then
            any = true
            local name = ups[1].link:match("%[(.-)%]") or "Item"
            L:Row({ chip = { text = "Upgrade", kind = "good" }, title = name .. (#ups > 1 and (" +" .. (#ups - 1) .. " more") or "") .. " in your bags",
                sub = "Highlighted in your bags", button = { label = "Gear", onClick = function() UI.Select("gear") end } })
        end
        local unread = ns.Changes.UnreadCount()
        if unread > 0 then
            any = true
            L:Row({ chip = { text = "News", kind = "info" }, title = unread .. " unread change" .. (unread == 1 and "" or "s"),
                button = { label = "Read", onClick = function() UI.Select("news") end } })
        end
        local lessons = c.spec and ns.Learn.UnreadLessonCount(c.level, c.spec) or 0
        if lessons > 0 then
            any = true
            L:Row({ chip = { text = "Learn", kind = "info" }, title = lessons .. " new lesson" .. (lessons == 1 and "" or "s"),
                button = { label = "Open", onClick = function() UI.Select("learn") end } })
        end
        if not any then L:Row({ chip = { text = "All good", kind = "good" }, title = "Nothing needs your attention" }) end

        L:NextColumn()
        local context = c.profile and c.profile.rotationContext or "solo"
        L:Label("Your rotation · " .. (ns.Rotation.CONTEXT_LABELS[context] or context):lower())
        local ctxData = c.spec and ns.Rotation.Context(c.spec, context)
        if ctxData then
            local shown = 0
            for _, step in ipairs(ctxData.priority or {}) do
                if shown >= 5 then break end
                local avail = ns.Rotation.Availability(step.spell, c.level, c.race, c.faction)
                if avail and step.when ~= "buff_missing" then
                    shown = shown + 1
                    L:Spell(ns.Rotation.SpellId(step.spell), shown .. ". " .. step.spell:gsub(" %(talent%)", ""),
                        ns.Rotation.WhenText(step.when), avail == "trainable" and (UI.Hex(UI.C.warn) .. "train it|r") or nil, ns.Rotation.Icon(step.spell))
                end
            end
            L:Buttons({ { label = "Open Rotation", onClick = function() UI.Select("rotation") end } })
        else
            L:Text(UI.Hex(UI.C.dim) .. "Pick a spec to see your rotation.|r")
        end
        L:EndColumns()

        L:Label("Latest changes")
        local items = ns.Changes.All()
        for i = 1, math.min(3, #items) do
            local it = items[i]
            L:Row({ chip = not ns.Changes.IsRead(it) and { text = "New", kind = "good" } or nil, title = it.title, right = it.date,
                onClick = function() UI.Select("news") end })
        end
        L:Source(meta)
    end,
})
