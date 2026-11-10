-- Settings: General · Paladin bar · Tooltips & bags · Reminders · About the data · About.
local _, ns = ...
local UI = ns.UI

UI.SettingsSections = UI.SettingsSections or {}
local S = UI.SettingsSections

local TABS = { "General", "Paladin bar", "Tooltips & bags", "Reminders", "About the data", "About" }
local tab = "General"

S.General = function(L, c)
    local g, ch = ns.db.global, ns.db.char
    L:Label("Specs & dual spec")
    for _, id in ipairs(ns.DB.PROFILE_IDS) do
        local p = ns.DB.Profile(id)
        local items = {}
        for _, spec in ipairs(ns.SPEC_ORDER) do
            table.insert(items, { label = spec, active = p.spec == spec, onClick = function()
                ns.DB.SetSpec(spec, id)
                UI.Refresh()
            end })
        end
        L:Text(("Profile %s · talent spec %s%s"):format(id, id == "A" and "1" or "2", ns.DB.ActiveId() == id and (UI.Hex(UI.C.good) .. "  (active)|r") or ""))
        L:Buttons(items, 110)
    end
    local cb = L:Check("Switch profile automatically with my talent spec", ch.autoSwitch, function(v)
        ch.autoSwitch = v
        if v then ns.DualSpec.Sync() end
        UI.Refresh()
    end, "Swapping talent specs (dual spec, level 40) swaps the addon profile: spec 1 -> A, spec 2 -> B.")
    if not ns.DualSpec.IsAvailable() then
        cb:Disable()
        L:Text(UI.Hex(UI.C.dim) .. "This client doesn't expose the talent-group API.|r", { size = 12, indent = 30 })
    else
        local grp = ns.DualSpec.ActiveGroup()
        L:Text(UI.Hex(UI.C.dim) .. (ns.DualSpec.HasDualSpec() and ("Dual spec learned. Active talent spec: " .. tostring(grp or "?") .. ".")
            or "Dual spec not learned yet (level 40, at your class trainer). The plan: Retribution on A, Holy on B for battlegrounds.") .. "|r", { size = 12, indent = 30 })
    end

    L:Label("Rotation helper & fight summary")
    L:Check("Show the on-screen rotation helper", ch.rotation.enabled, function(v) ch.rotation.enabled = v ns.Fire("HUD_TOGGLE") end)
    L:Check("Only in combat", ch.rotation.showInCombatOnly, function(v) ch.rotation.showInCombatOnly = v ns.Fire("HUD_TOGGLE") end)
    L:Check("Post-fight summary in chat", ch.summary.enabled, function(v) ch.summary.enabled = v end)
    L:Buttons({ { label = "Reset helper position", onClick = function() ch.rotation.point = nil ns.Fire("HUD_RESET") end } })

    L:Label("Learning & window")
    L:Check("Hint the first time I learn a spell", ch.learn.hints, function(v) ch.learn.hints = v end)
    L:Check("Show minimap button", not g.minimap.hide, function(v) g.minimap.hide = not v ns.Fire("MINIMAP_TOGGLE") end)
    L:Check("Debug messages", g.debug, function(v) g.debug = v end)
    L:Text(UI.Hex(UI.C.dim) .. "Slash: /tristan (or /paladin) · /tristan spec holy|prot|ret · /tristan rotation · /tristan battle · /tristan bless key · /tristan pvpbar always|pvp|never|r", { size = 12 })
end

-- Cycle a setting through steps (button label "Keep 20" -> next value).
local function cycle(cfgT, key, steps, after)
    return function()
        local nextV = steps[1]
        for i, v in ipairs(steps) do if v == cfgT[key] then nextV = steps[i + 1] or steps[1] end end
        cfgT[key] = nextV
        if after then after() end
        UI.Refresh()
    end
end

local function keyRow(L, key, what, startCapture, clear)
    L:Row({ title = what .. " key", sub = key and "Pressing it presses the button, even if the key is bound to something else in Blizzard's menu." or "No key set (none by default).",
        right = key and (UI.Hex(UI.C.good) .. key .. "|r") or (UI.Hex(UI.C.dim) .. "none|r") })
    L:Buttons({
        { label = "Set key", onClick = startCapture, tip = "Press any key (Shift/Ctrl/Alt combos work). Esc cancels." },
        { label = "Clear key", onClick = function() clear(nil) UI.Refresh() end },
    })
end

S["Paladin bar"] = function(L, c)
    local cfg = ns.db.char.blessing
    L:Text("One small bar: the Blessing button (it casts), plus Aura and Seal hints (they only advise; Blizzard's Aura flyout on your action bar stays the way to switch Auras). Drag the strip above them to move the bar.", { size = 13 })
    L:Buttons({ { label = "Reset bar position", onClick = function() ns.PaladinBar.ResetPosition() end } })

    L:Label("Blessing button")
    L:Text("One press blesses the nearest friendly player who's missing a Blessing from you: you first, your group nearest-first, your target, then players with friendly nameplates (Shift+V). One Blessing from you per target: anyone with your Freedom or Protection is skipped until it ends, then offered again.", { size = 12 })
    L:Check("Show the Blessing button", cfg.enabled, function(v)
        if InCombatLockdown() then ns.Print("Out of combat only.") return end
        cfg.enabled = v
        ns.Blessing.Refresh()
    end)
    L:Check("Kings for everyone (once you know Blessing of Kings, level 20)", cfg.kingsForAll, function(v) cfg.kingsForAll = v UI.Refresh() end,
        "Per-class picks below still win.")
    L:Check("Use Greater Blessings in a raid when " .. cfg.greaterMin .. "+ of a class need it", cfg.greater, function(v) cfg.greater = v end,
        "Only if you know the Greater Blessing. Their levels aren't confirmed for Forever.")
    L:Label("By class")
    L:Text(UI.Hex(UI.C.dim) .. "Default: Might for Warriors, Rogues and Hunters; Wisdom for casters, healers and hybrids. Your own Blessing follows your spec (Might for Retribution/Protection, Wisdom for Holy) unless you set Paladin here. Click to cycle.|r", { size = 12 })
    local CHOICES = { nil, "Might", "Wisdom", "Kings" }
    for _, class in ipairs(ns.Paladin.CLASS_ORDER) do
        local cur = cfg.byClass[class]
        local label = cur and cur or ("default (" .. ns.Paladin.CLASS_DEFAULT[class] .. ")")
        L:Row({ title = ns.Paladin.CLASS_LABEL[class], right = cur and (UI.Hex(UI.C.good) .. cur .. "|r") or (UI.Hex(UI.C.dim) .. "default|r"),
            button = { label = label, onClick = function()
                local nextV
                if cur == nil then nextV = "Might" elseif cur == "Might" then nextV = "Wisdom" elseif cur == "Wisdom" then nextV = "Kings" else nextV = nil end
                cfg.byClass[class] = nextV
                if not InCombatLockdown() then ns.Blessing.Update() end
                UI.Refresh()
            end } })
    end
    keyRow(L, cfg.key, "Blessing", ns.Blessing.StartKeyCapture, ns.Blessing.SetKey)
    L:Note("Blessing durations and the Greater Blessing levels (52/54/60 on one secondary site) aren't confirmed for Forever.")

    L:Label("Aura & Seal hints")
    L:Check("Show the Aura hint", ns.db.char.auraHint.enabled, function(v) ns.db.char.auraHint.enabled = v ns.Hints.Refresh() end)
    local known = ns.Paladin.KnownAuras()
    local items = { { label = "Automatic", active = ns.db.char.auraHint.override == nil, onClick = function() ns.db.char.auraHint.override = nil ns.Hints.Refresh() UI.Refresh() end } }
    for _, a in ipairs(known) do
        table.insert(items, { label = (a:gsub(" Aura$", "")), active = ns.db.char.auraHint.override == a, onClick = function() ns.db.char.auraHint.override = a ns.Hints.Refresh() UI.Refresh() end })
    end
    L:Text(UI.Hex(UI.C.dim) .. "Automatic: Devotion solo, Retribution in groups, Concentration for Holy in PvP. Pick one to pin it (e.g. a resistance aura for a fight).|r", { size = 12 })
    L:Buttons(items, 104)
    L:Check("Show the Seal hint", ns.db.char.sealHint.enabled, function(v) ns.db.char.sealHint.enabled = v ns.Hints.Refresh() end)

    L:Space(6)
    L:Text(UI.Hex(UI.C.dim) .. "Pick keys your desktop doesn't use (on Omarchy, Super combos belong to the desktop, so they're never offered). No key is bound by default. What the secure buttons cast and their keys only change out of combat (Blizzard rule).|r", { size = 12 })
    L:Text(UI.Hex(UI.C.dim) .. "The PvP bar (Freedom, Cleanse, Protection, Stun, Repentance) lives under Battle > PvP bar.|r", { size = 12 })
end

S["Tooltips & bags"] = function(L, c)
    local g = ns.db.global
    L:Check("Upgrade tips on item tooltips", g.tooltip.enabled, function(v) g.tooltip.enabled = v end)
    L:Check("Show what improves (stat changes) in tooltips", g.tooltip.showStats, function(v) g.tooltip.showStats = v end)
    L:Check("Highlight upgrades in my bags", g.bags.highlight, function(v) g.bags.highlight = v ns.Bags.RefreshAll() end,
        "Glow + arrow on bag items that beat what you're wearing for your active spec and that you can equip now.")
    L:Check("Tell me when an upgrade lands in my bags", g.bags.toast, function(v) g.bags.toast = v end)
    L:Space(6)
    L:Row({ title = "Hit/crit value", sub = "How many points of spell power/healing 1% hit or crit is worth. An addon assumption, not from the research.",
        button = { label = g.percentScale .. " per 1%", onClick = function()
            local steps = { 5, 8, 10, 12, 14, 20 }
            local nextV = steps[1]
            for i, v in ipairs(steps) do if v == g.percentScale then nextV = steps[i + 1] or steps[1] end end
            g.percentScale = nextV
            ns.Stats.ClearCache()
            UI.Refresh()
        end } })
end

S.About = function(L, c)
    local version = tostring(ns.VERSION)
    if not version:match("^v") then version = "v" .. version end
    L:Row({ icon = ns.NEUTRAL_ICON, title = ns.TITLE .. " " .. version,
        sub = "The do-everything Paladin companion for World of Warcraft: Forever, with a Battle section for PvP." })
    L:Label("Named for")
    L:Row({ icon = "Interface\\Icons\\Spell_Holy_SealOfMight", title = "Tristan Ludlowe",
        sub = "Human Paladin of the Alliance, on a PvP realm. This addon was built for him and tested on him." })
    L:Text(UI.Hex(UI.C.dim) .. "If a Human Paladin blesses you in Elwynn and then gets ganked in Redridge, say hello.|r", { size = 12 })
    L:Label("Links")
    L:Link("Website", "https://tristans-addon.myazerothlife.com")
    L:Link("Source and issues", "https://github.com/ninepointlabs/tristans-addon")
    L:Label("Sister addons")
    L:Link("Andric's Addon (Priest)", "https://andricsaddon.myazerothlife.com")
    L:Link("Parzelle's Addon (Mage)", "https://parzelles-addon.myazerothlife.com")
    L:Link("My Azeroth Life", "https://myazerothlife.com")
    L:Label("Credits")
    L:Row({ title = "Made by Nine Point Labs", sub = "Free and open source, MIT licence." })
    L:Row({ title = "Information from Blizzard, Icy Veins and Wowhead", sub = "Credited per fact: see About the data, or the Sources & notes link on each screen. PvP fan sites are marked unconfirmed." })
    L:Text(UI.Hex(UI.C.dim) .. "Tristan's Addon is an unofficial fan project, not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft and Warcraft are trademarks of Blizzard Entertainment, Inc.|r", { size = 11 })
end

UI.RegisterPanel({
    key = "settings", label = "Settings",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("Settings")
        local items = {}
        for _, t in ipairs(TABS) do
            table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end })
        end
        L:Tabs(items)
        local fn = S[tab] or S.General
        fn(L, c)
    end,
})
