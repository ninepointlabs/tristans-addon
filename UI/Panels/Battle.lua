-- Battle: PvP. One screen in the main window (not a second window), with
-- sub-tabs: Honor & Rank · Battlegrounds · PvP bar · Cooldowns · Burst coach · World PvP.
-- Uses the muted battle-red accent for its labels only.
local _, ns = ...
local UI = ns.UI

local TABS = { "Honor & Rank", "Battlegrounds", "PvP bar", "Cooldowns", "Burst coach", "World PvP" }
local tab = "Honor & Rank"
local S = {}
UI.BattleSections = S

local function red(text) return UI.Hex(ns.BattleAccent) .. text .. "|r" end
local function flag(e)
    if e and e.unconfirmed then return "\n" .. UI.FLAG_ICON .. " " .. UI.Hex(UI.C.warn) .. ((e.flag and e.flag ~= "") and e.flag or "Unconfirmed") .. "|r" end
    return ""
end
local function P() return ns.Data.PvP or {} end

local function probeStatus(L)
    L:Label(red("What this client lets addons read"))
    local probes = ns.PvP.RunProbes()
    for _, name in ipairs(ns.PvP.PROBE_ORDER) do
        local p = probes[name] or { status = "missing" }
        local kind = (p.status == "ok") and "good" or ((p.status == "secret") and "warn" or "neutral")
        L:Row({ chip = { text = p.status, kind = kind }, title = name, sub = p.note })
    end
    L:Text(UI.Hex(UI.C.dim) .. "\"ok\" = readable, \"secret\" = the game hides it from addons, \"missing\" = not in this client. Anything not ok shows as hidden; Character (C) > Player vs. Player always has the real numbers.|r", { size = 11 })
end

S["Honor & Rank"] = function(L, c)
    local rank = ns.PvP.Rank()
    local honor = ns.PvP.Honor()
    local session = ns.PvP.Session()
    L:Columns({ 0.55, 0.45 })
    L:Label(red("You"))
    if rank then
        L:Row({ chip = { text = rank.rank > 0 and ("R" .. rank.rank) or "R0", kind = "info" }, title = rank.rank > 0 and (rank.name or ("Rank " .. rank.rank)) or "No rank yet",
            sub = "Rank Points come from battlegrounds and PvP quests, with a weekly cap. No decay." })
        if rank.progress then L:Progress("Progress to the next rank", math.floor(rank.progress * 100), 100, math.floor(rank.progress * 100) .. "%") end
    else
        L:Row({ chip = { text = "hidden", kind = "neutral" }, title = "Rank and Rank Points",
            sub = "Not readable by addons here. Press C, then the Player vs. Player tab: rank, Rank Points this week and what you can buy." })
    end
    if honor then
        L:Row({ icon = honor.icon, title = "Honor: " .. honor.amount .. (honor.max and honor.max > 0 and (" / " .. honor.max) or ""),
            sub = "Spent on the blue PvP set and rank rewards." })
    else
        L:Row({ chip = { text = "hidden", kind = "neutral" }, title = "Honor", sub = "Not readable here; it's on Character > Player vs. Player and in the currency tab." })
    end
    if session then
        L:Row({ title = ("This session: %s honorable kills%s"):format(tostring(session.hk), session.honor and (", " .. session.honor .. " honor") or ""),
            sub = "From the game's own session counter (no combat log)." })
    end
    local goal = ns.db.char.pvp.rewardGoal
    local nextR = ns.PvP.NextReward(rank and rank.rank or 0)
    L:Label(red("Next rank reward"))
    if nextR then
        L:Row({ chip = { text = "R" .. nextR.rank, kind = "warn" }, title = nextR.reward })
        L:Source(nextR)
    else
        L:Text("Rank 14: you've seen it all.")
    end
    L:Label(red("Gear path for a Paladin"))
    local gp = P().gear_path
    if gp then
        L:Text((gp.text or "") .. (gp.emboldened_seal and ("\n" .. UI.Hex(UI.C.dim) .. gp.emboldened_seal .. "|r") or "") .. flag(gp), { size = 12 })
        L:Source(gp)
    end
    if goal then L:Note("Saving for: " .. goal) end
    L:NextColumn()
    L:Label(red("Rank rewards (Blizzard)"))
    for _, r in ipairs(ns.PvP.Ranks()) do
        local reached = rank and rank.rank >= r.rank
        L:Row({ chip = { text = "R" .. r.rank, kind = reached and "good" or "neutral" }, title = r.reward,
            onClick = function() ns.db.char.pvp.rewardGoal = "R" .. r.rank .. " " .. r.reward UI.Refresh() end })
    end
    if ns.PvP.Ranks()[1] then L:Source(ns.PvP.Ranks()[1]) end
    L:Text(UI.Hex(UI.C.dim) .. "Click a reward to set it as your goal.|r", { size = 11 })
    for _, k in ipairs({ "honor", "rank_points", "seasonal" }) do
        local e = P()[k]
        if e and (e.notes or e.text) then L:Note((e.notes or e.text)) L:Source(e) end
    end
    L:EndColumns()
    probeStatus(L)
end

S.Battlegrounds = function(L, c)
    local list = ns.PvP.Battlegrounds()
    if #list == 0 then L:Flag("No battleground data in the research.") return end
    local q = P().queue
    if q then L:Text(UI.Hex(UI.C.dim) .. (q.text or "") .. "|r", { size = 12 }) L:Source(q) end
    local spec = c.spec
    for _, bg in ipairs(list) do
        local open = ns.PvP.BGOpen(bg, c.level)
        local chip = open and { text = "Open to you", kind = "good" } or { text = (bg.min_level and ("from " .. bg.min_level) or "?"), kind = "neutral" }
        local sub = {}
        if bg.objective then table.insert(sub, bg.objective) end
        if bg.alliance_queue then table.insert(sub, "Queue: " .. bg.alliance_queue) end
        if bg.portal then table.insert(sub, "Portal: " .. bg.portal) end
        if bg.marks then table.insert(sub, "Marks: " .. bg.marks) end
        if bg.rep_faction then table.insert(sub, "Reputation: " .. bg.rep_faction) end
        if bg.vendor_note then table.insert(sub, bg.vendor_note) end
        local role = bg.roles and spec and bg.roles[spec]
        if role and role ~= "" then table.insert(sub, UI.Hex(UI.Accent()) .. "As " .. spec .. ":|r " .. role) end
        L:Row({ chip = chip, title = bg.name .. (bg.size and ("  " .. UI.Hex(UI.C.dim) .. bg.size .. "|r") or ""),
            right = (bg.min_level or "?") .. "-" .. (bg.max_level or "?"), sub = table.concat(sub, "\n") .. flag(bg),
            tint = open and ns.BattleAccent or nil })
        L:Source(bg)
    end
    local cta = P().call_to_arms
    L:Label(red("Call to Arms"))
    L:Text(((cta and cta.text) or "Holiday weeks give more Honor.") .. " This week's battleground isn't readable by addons: check the in-game calendar.", { size = 12 })
    if cta then L:Source(cta) end
    L:Note("Battlemaster locations: the research has no coordinates or names for them, so there's no map pin (it won't guess). Stormwind Keep is named as a queue spot.")
end

S["PvP bar"] = function(L, c)
    local cfg = ns.db.char.pvpBar
    L:Text("Secure buttons, one press = one cast, set up out of combat. Each runs its own /cast line (mouseover, focus, your picked ally). Freedom and Protection replace your other Blessing on that target; the Blessing button offers it again afterwards.", { size = 12 })
    local modes = { { "pvp", "In PvP" }, { "always", "Always" }, { "never", "Never" } }
    local items = {}
    for _, m in ipairs(modes) do
        table.insert(items, { label = m[2], active = cfg.show == m[1], onClick = function()
            if InCombatLockdown() then ns.Print("Out of combat only.") return end
            cfg.show = m[1]
            ns.PvPBar.Refresh()
            UI.Refresh()
        end })
    end
    L:Text(UI.Hex(UI.C.dim) .. "Show the bar: \"In PvP\" = on a PvP realm, in a battleground, or while flagged.|r", { size = 12 })
    L:Buttons(items, 90)
    L:Buttons({ { label = "Reset bar position", onClick = function() if not InCombatLockdown() then ns.PvPBar.bar.ResetPosition() end end } })
    L:Label(red("Picked ally (Freedom and Protection)"))
    local allies = ns.PvPBar.AllyChoices()
    local items2 = { { label = "None", active = cfg.ally == nil, onClick = function() ns.PvPBar.SetAlly(nil) UI.Refresh() end } }
    for _, a in ipairs(allies) do
        table.insert(items2, { label = a.name or "?", active = cfg.ally == a.name, onClick = function() ns.PvPBar.SetAlly(a.name) UI.Refresh() end })
    end
    L:Buttons(items2, 110)
    if #allies == 0 then L:Text(UI.Hex(UI.C.dim) .. "Join a group to pick an ally (your flag carrier, your healer).|r", { size = 12 }) end
    L:Label(red("Buttons"))
    for _, def in ipairs(ns.PvPBar.BUTTONS) do
        local spell = ns.PvPBar.Spell(def)
        local key = cfg.keys[def.key]
        L:Row({ icon = spell and ns.Rotation.Icon(spell) or nil, title = def.label .. (spell and (": " .. spell) or ""),
            sub = spell and def.tip or (UI.Hex(UI.C.dim) .. "Shows up once you know " .. def.spells[1] .. ".|r"),
            right = key and (UI.Hex(UI.C.good) .. key .. "|r") or (UI.Hex(UI.C.dim) .. "no key|r") })
        if spell then
            L:Buttons({
                { label = "Set key", onClick = function() ns.PvPBar.StartKeyCapture(def.key) end, tip = "Shift/Ctrl/Alt combos work; Super is never used. Esc cancels." },
                { label = "Clear key", onClick = function() ns.PvPBar.SetKey(def.key, nil) UI.Refresh() end },
            }, 100)
        end
    end
    L:Note("Check in game: does Forever honour [@mouseover] in these /cast lines? ([@nameplateN] is silently ignored, so it isn't used.)")
end

S.Cooldowns = function(L, c)
    L:Columns({ 0.55, 0.45 })
    L:Label(red("My cooldowns"))
    local list = ns.Cooldowns.List()
    if #list == 0 then L:Text(UI.Hex(UI.C.dim) .. "Your PvP cooldowns show here once you know them .|r", { size = 12 }) end
    for _, cd in ipairs(list) do
        local right = cd.left == nil and (UI.Hex(UI.C.dim) .. "hidden|r") or (cd.left <= 0.1 and (UI.Hex(UI.C.good) .. "ready|r") or ("%ds"):format(math.ceil(cd.left)))
        local r = cd.rec
        local sub = {}
        if r.cooldown then table.insert(sub, "Cooldown " .. r.cooldown) end
        if r.duration then table.insert(sub, "lasts " .. r.duration) end
        if r.forbearance then table.insert(sub, "causes Forbearance") end
        if r.notes then table.insert(sub, r.notes) end
        L:Spell(ns.Rotation.SpellId(cd.spell), cd.spell, table.concat(sub, " · ") .. flag(r), right, ns.Rotation.Icon(cd.spell))
        if r.source_url then L:Source(r) end
    end
    L:Label(red("Forbearance"))
    local fb = ns.Cooldowns.ForbearanceText()
    L:Row({ icon = "Interface\\Icons\\Spell_Holy_RemoveCurse", title = fb or "Not on you",
        sub = (P().forbearance and P().forbearance.text) or "Divine Shield, Divine Protection, Blessing of Protection and Templar's Bulwark cause Forbearance: you can't use another of them while it lasts." })
    if P().forbearance then L:Source(P().forbearance) end
    L:NextColumn()
    L:Label(red("Built-in alternative"))
    L:Text("Blizzard's Cooldown Manager (/cdm, Options > Gameplay Enhancements, off by default) tracks your cooldowns on screen, and since the Nov 9 hotfix it shows Seals correctly.", { size = 12 })
    L:Check("Show Forbearance and the burst coach's next step on the on-screen helper", ns.db.char.pvp.cooldownsOnHud, function(v) ns.db.char.pvp.cooldownsOnHud = v end)
    L:Label(red("Not possible (and why)"))
    for _, n in ipairs(P().not_in_addon or {}) do
        L:Row({ title = n.feature or "?", sub = n.why })
    end
    L:EndColumns()
end

S["Burst coach"] = function(L, c)
    if not c.spec then L:Text("Pick a spec first.") return end
    local view = ns.Cooldowns.Coach(c.spec)
    local b = P().burst
    L:Text(UI.Hex(UI.C.dim) .. "Advice only. The coach follows your own casts and cooldowns and lights the next step. It never reads enemy health or cooldowns, and it never presses anything.|r", { size = 12 })
    if #view.steps == 0 then
        L:Flag("No burst sequence for " .. c.spec .. " in the research" .. (c.spec == "Protection" and " (no Protection PvP source yet)." or "."))
        return
    end
    for i, st in ipairs(view.steps) do
        local chip
        if not st.known then chip = { text = "Not known yet", kind = "neutral" }
        elseif st.done then chip = { text = "Done", kind = "good" }
        elseif view.next == i then chip = { text = "Next", kind = "warn" }
        elseif st.ready == nil then chip = { text = "hidden", kind = "neutral" }
        elseif st.ready == false then chip = { text = st.left and (math.ceil(st.left) .. "s") or "cooling", kind = "neutral" } end
        L:Spell(ns.Rotation.SpellId(st.spell), i .. ". " .. st.spell, st.note, nil, ns.Rotation.Icon(st.spell), chip and { chip = chip } or nil)
    end
    if b then
        if b.unconfirmed then L:Note("Burst sequence: " .. (b.flag or "from secondary PvP sites, unconfirmed")) end
        L:Source(b)
    end
    if c.spec == "Retribution" and ns.Paladin.HasUnsealedWrath() then
        L:Text(UI.Hex(UI.Accent()) .. "Unsealed Wrath:|r build echoes with Seal of Command, then swap Seals right before the stun so the echoes proc into the window.", { size = 12 })
    end
    L:Buttons({ { label = "Reset the sequence", onClick = function() ns.Cooldowns.ResetCoach() UI.Refresh() end } })
end

S["World PvP"] = function(L, c)
    local z = ns.PvP.Zone()
    local rs = ns.PvP.Ruleset()
    L:Columns({ 0.5, 0.5 })
    L:Label(red("Where you are"))
    if z then
        L:Row({ chip = { text = z.kind, kind = ns.PvP.ZONE_KIND[z.kind] or "neutral" }, title = z.text,
            sub = (z.flagged == nil and "Flag state hidden." or (z.flagged and "You're flagged for PvP." or "You're not flagged.")) .. (z.ffa and " Free-for-all." or "") })
    else
        L:Row({ chip = { text = "hidden", kind = "neutral" }, title = "Zone PvP status isn't readable here", sub = "Your target frame and the minimap zone text still show it." })
    end
    local tip = ns.PvP.DangerTip()
    if tip then L:Row({ chip = { text = "Ready", kind = "good" }, title = tip }) end
    L:Label(red("Your realm"))
    local items = {}
    for _, r in ipairs({ "PvP", "Normal" }) do
        table.insert(items, { label = r, active = rs == r, onClick = function() ns.db.char.pvp.ruleset = r if not InCombatLockdown() then ns.PvPBar.Refresh() end UI.Refresh() end })
    end
    L:Buttons(items, 90)
    L:Text(UI.Hex(UI.C.dim) .. "Tristan's realm is a PvP ruleset (Tim, 2026-11-10). The game doesn't tell addons the ruleset, so it's a setting. On Normal, the warnings stay quiet unless you flag yourself.|r", { size = 12 })
    L:Check("Warn me when I enter a contested or enemy zone", ns.db.char.pvp.zoneNotice, function(v) ns.db.char.pvp.zoneNotice = v end)
    L:NextColumn()
    L:Label(red("Leveling on a PvP realm"))
    for _, t in ipairs(P().world_pvp_tips or {}) do
        L:Row({ title = t.title or "", sub = (t.body or "") .. flag(t) })
        L:Source(t)
    end
    if not (P().world_pvp_tips and P().world_pvp_tips[1]) then L:Text("No world PvP tips in the research yet.") end
    L:EndColumns()
end

UI.RegisterPanel({
    key = "battle", label = "PvP",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("Battle", "PvP for a Paladin: Honor & Rank, battlegrounds, your PvP bar and cooldowns")
        local items = {}
        for _, t in ipairs(TABS) do
            table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end })
        end
        L:Tabs(items)
        local fn = S[tab] or S["Honor & Rank"]
        fn(L, c)
        local s = P().summary
        if s then L:Source(s) end
    end,
})
