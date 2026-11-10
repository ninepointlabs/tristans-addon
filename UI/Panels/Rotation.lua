local _, ns = ...
local UI = ns.UI

local WHEN_TEXT = {
    always = "", buff_missing = "if the buff is missing", debuff_missing = "if your debuff is missing on the target",
    ready = "when off cooldown", out_of_combat = "out of combat", in_combat = "in combat",
    manual = "when the situation calls for it", seal_missing = "if you have no Seal",
    usable = "when it lights up (e.g. target under 20%)", target_undead_or_demon = "on Undead and Demons",
    in_melee = "in melee range",
}
local function whenText(w)
    if not w then return "" end
    if WHEN_TEXT[w] then return WHEN_TEXT[w] end
    local k, v = w:match("^([%w_]+):(.+)$")
    if k == "mana_above" then return "while mana is above " .. v .. "%" end
    if k == "mana_below" then return "when mana is below " .. v .. "%" end
    if k == "target_hp_below" then return "when the target is below " .. v .. "% health" end
    if k == "proc" then return "when " .. v .. " procs" end
    if k == "target_debuff_missing" then return "if " .. v .. " isn't on the target" end
    if k == "stacks_below" or k == "stacks_at_least" then
        local aura, n = v:match("^(.-):(%d+)$")
        if aura then return (k == "stacks_below" and "until %s has %s stacks" or "at %s %s+ stacks"):format(aura, n) end
    end
    return w
end
ns.Rotation.WhenText = whenText

local view -- nil = the profile's context; "seals" | "mana"

local function renderSeals(L, c)
    local st = ns.Paladin.State()
    L:Columns({ 0.5, 0.5 })
    L:Label("Right now")
    local function stateText(v)
        if v == nil then return UI.Hex(UI.C.dim) .. "hidden|r" end
        return v and (UI.Hex(UI.C.good) .. v .. "|r") or (UI.Hex(UI.C.warn) .. "none|r")
    end
    L:Row({ icon = ns.Rotation.Icon(st.recAura or "Devotion Aura"), title = "Aura: " .. stateText(st.aura),
        sub = st.recAura and ("Suggested: " .. st.recAura .. (st.auraWhy and (" (" .. st.auraWhy .. ")") or "")) or "You don't know an Aura yet." })
    L:Row({ icon = ns.Rotation.Icon(st.recSeal or "Seal of Righteousness"), title = "Seal: " .. stateText(st.seal),
        sub = st.recSeal and ("Suggested: " .. st.recSeal .. (st.sealWhy and (" (" .. st.sealWhy .. ")") or "")) or "Pick a spec to get a Seal suggestion." })
    L:Row({ icon = ns.Rotation.Icon("Blessing of Might"), title = "Your Blessing on you: " .. stateText(st.blessing),
        sub = "The Blessing button on the Paladin bar handles you and your group." })
    if ns.Paladin.HasUnsealedWrath() then
        local echo = ns.Paladin.EchoStacks()
        L:Row({ chip = { text = echo == nil and "hidden" or (echo .. "/3"), kind = (echo or 0) >= 3 and "good" or "neutral" }, title = "Unsealed Wrath echoes",
            sub = (echo or 0) >= 3 and "Three stored: swap to your other Seal now." or "Swings store an echo of your Seal (up to 3). Swap Seals at 3; each echo gets a proc chance." })
        L:Note("Unsealed Wrath: the echo is read from your own aura by its talent name; if Forever names the buff differently the helper shows 'hidden' (check in game).")
    end
    L:Check("Show the Aura hint on the Paladin bar", ns.db.char.auraHint.enabled, function(v) ns.db.char.auraHint.enabled = v ns.Hints.Refresh() UI.Refresh() end)
    L:Check("Show the Seal hint on the Paladin bar", ns.db.char.sealHint.enabled, function(v) ns.db.char.sealHint.enabled = v ns.Hints.Refresh() UI.Refresh() end)
    L:NextColumn()
    local content = ns.Learn.Content()
    L:Label("How Seals, Judgement and Auras work in Forever")
    local any = false
    for _, e in ipairs(content and content.mechanics or {}) do
        if e.topic == "seals" then
            any = true
            local flag = e.unconfirmed and ("\n" .. UI.FLAG_ICON .. " " .. UI.Hex(UI.C.warn) .. ((e.flag and e.flag ~= "") and e.flag or "Unconfirmed") .. "|r") or ""
            L:Text((e.title and (UI.Hex(UI.Accent()) .. e.title .. "|r\n") or "") .. (e.body or "") .. flag, { size = 12 })
            for _, src in ipairs(e.sources or {}) do L:Source({ source_url = src }) end
        end
    end
    local seals = ns.Data.Rotations and ns.Data.Rotations.seals
    if seals then
        L:Text(seals, { size = 12 })
        L:Source(ns.Data.Rotations)
    end
    if not any and not seals then L:Text("Judgement no longer uses up your Seal in Forever; keep one Seal up and Judge on cooldown.", { size = 12 }) end
    L:EndColumns()
end

local function renderMana(L, c)
    local content = ns.Learn.Content()
    L:Text(UI.Hex(UI.C.dim) .. "How to stay out of the drink-after-every-pull loop. Facts from the research; anything unconfirmed is marked.|r", { size = 12 })
    local any = false
    for _, e in ipairs(content and content.mechanics or {}) do
        if e.topic == "mana" then
            any = true
            local flag = e.unconfirmed and ("\n" .. UI.FLAG_ICON .. " " .. UI.Hex(UI.C.warn) .. ((e.flag and e.flag ~= "") and e.flag or "Unconfirmed") .. "|r") or ""
            L:Row({ title = e.title or "", sub = (e.body or "") .. flag })
            for _, src in ipairs(e.sources or {}) do L:Source({ source_url = src }) end
        end
    end
    local mana = ns.Data.Rotations and ns.Data.Rotations.mana
    if mana then
        L:Label("Regen")
        L:Text(mana, { size = 12 })
        L:Source(ns.Data.Rotations)
    end
    if not any and not mana then L:Text("No mana content in the research yet.") end
end

UI.RegisterPanel({
    key = "rotation", label = "Rotation",
    setSub = function(sub)
        local key = sub and sub:lower()
        if key == "seals & auras" or key == "seals" then view = "seals"
        elseif key == "mana" then view = "mana"
        elseif key and ns.Rotation.CONTEXT_LABELS[key] then ns.DB.Profile().rotationContext = key view = nil end
    end,
    render = function(L, c)
        L:Title("Rotation", c.spec and (c.spec .. " · only spells you can use at level " .. c.level) or nil)
        if not c.spec then L:Text("Pick a spec first (spec pill at the top).") return end
        local p = c.profile
        local current = p.rotationContext or "solo"
        local tabs = {}
        for _, key in ipairs(ns.Rotation.CONTEXTS) do
            table.insert(tabs, { label = ns.Rotation.CONTEXT_LABELS[key], active = view == nil and key == current, onClick = function()
                p.rotationContext = key
                view = nil
                ns.Fire("ROTATION_CONTEXT", key)
                UI.Refresh()
            end })
        end
        table.insert(tabs, { label = "Seals & auras", active = view == "seals", onClick = function() view = "seals" UI.Refresh() end })
        table.insert(tabs, { label = "Mana", active = view == "mana", onClick = function() view = "mana" UI.Refresh() end })
        L:Tabs(tabs)
        if view == "seals" then renderSeals(L, c) return end
        if view == "mana" then renderMana(L, c) return end

        local ctxData = ns.Rotation.Context(c.spec, current)
        if not ctxData then
            L:Flag("No rotation content for this spec and situation yet.")
            return
        end
        if ctxData.unconfirmed then L:Note(c.spec .. " " .. current .. ": " .. ((ctxData.flag ~= "" and ctxData.flag) or "unconfirmed")) end
        for _, s in ipairs(ctxData.sources or {}) do L:Source({ source_url = s }) end

        L:Columns({ 0.6, 0.4 })
        L:Text(UI.Hex(UI.C.dim) .. "Top of the list wins. The on-screen helper lights up the next one. Advice only: you press the buttons.|r", { size = 12 })
        local n, hidden = 0, 0
        for _, step in ipairs(ctxData.priority or {}) do
            local avail = ns.Rotation.Availability(step.spell, c.level, c.race, c.faction)
            if avail then
                n = n + 1
                local sub = whenText(step.when)
                if step.note and step.note ~= "" then sub = (sub ~= "" and (sub .. " - ") or "") .. step.note end
                local chip
                if avail == "trainable" then chip = { text = "Train it", kind = "warn" } end
                L:Spell(ns.Rotation.SpellId(step.spell), ("%d. %s"):format(n, (step.spell:gsub(" %(talent%)", ""))), sub, nil,
                    ns.Rotation.Icon(step.spell), chip and { chip = chip } or nil)
            else
                hidden = hidden + 1
            end
        end
        if n == 0 then L:Text(UI.Hex(UI.C.dim) .. "Nothing in this list is available at your level yet.|r") end
        if hidden > 0 then
            L:Text(UI.Hex(UI.C.dim) .. hidden .. " more step" .. (hidden == 1 and "" or "s") .. " unlock with levels or talents; they'll appear here when you can use them.|r", { size = 12 })
        end

        L:NextColumn()
        local hud = ns.db.char.rotation
        L:Row({ title = "On-screen helper", sub = hud.showInCombatOnly and "Shows in combat only" or "Next-spell icon near your character",
            button = { label = hud.enabled and "On" or "Off", onClick = function()
                hud.enabled = not hud.enabled
                ns.Fire("HUD_TOGGLE")
                UI.Refresh()
            end } })
        if ctxData.summary then
            L:Label("The plan")
            L:Text(ctxData.summary, { size = 12 })
        end
        if ctxData.tips and #ctxData.tips > 0 then
            L:Label("Tips")
            for _, t in ipairs(ctxData.tips) do L:Text("- " .. t, { size = 12 }) end
        end
        L:Label("Last fight")
        local last = ns.Summary.last
        if last then
            L:Text(("%ds · mana %s -> %s"):format(last.duration, last.manaStart and ("%.0f%%"):format(last.manaStart) or "?", last.manaEnd and ("%.0f%%"):format(last.manaEnd) or "?"), { size = 12 })
            L:Text(UI.Hex(UI.C.dim) .. ns.Summary.Text(last) .. "|r", { size = 12 })
            for _, t in ipairs(last.tips or {}) do L:Text("- " .. t, { size = 12 }) end
        else
            L:Text(UI.Hex(UI.C.dim) .. "After each fight: casts used, mana spent and a tip.|r", { size = 12 })
        end
        L:Buttons({ { label = "Mana tips", onClick = function() view = "mana" UI.Refresh() end },
            { label = "Seals & auras", onClick = function() view = "seals" UI.Refresh() end } })
        L:EndColumns()
    end,
})
