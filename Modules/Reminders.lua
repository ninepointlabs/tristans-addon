-- Out-of-combat reminders: your Blessing, your Aura, a Seal when you're in
-- melee range, Righteous Fury (on for Protection, off otherwise), and the
-- Redemption class quest at 12. Reagents (Symbol of Kings etc.) are only
-- reminded if the research confirms they exist in Forever (it doesn't yet).
local _, ns = ...

local Reminders = {}
ns.Reminders = Reminders

local function itemCount(id)
    if C_Item and C_Item.GetItemCount then
        local ok, n = pcall(C_Item.GetItemCount, id)
        if ok then return n or 0 end
    end
    return 0
end
Reminders.ItemCount = itemCount

local function knowsAny(names)
    for _, n in ipairs(names) do
        if ns.Progress.Knows(n) then return n end
    end
    return nil
end

-- The Redemption class quest (The Tome of Divinity) for this character, if open.
function Reminders.RedemptionQuest(level, race, faction)
    if (level or 0) < 12 or ns.Progress.Knows("Redemption") then return nil end
    for _, q in ipairs(ns.Progress.ClassQuests(race, faction)) do
        if (q.reward_spell == "Redemption" or (q.name or ""):find("Tome of Divinity", 1, true)) and not ns.Progress.IsQuestDone(q.quest_id) then
            return q
        end
    end
    return nil
end

-- Returns { {id, label, ok, detail, icon} ... } for the active spec.
function Reminders.Evaluate()
    local cfg = ns.db.char.reminders
    local P = ns.Paladin
    local st = P.State()
    local out = {}
    local function add(id, enabled, applies, label, ok, detail, icon)
        if enabled and applies then
            table.insert(out, { id = id, label = label, ok = ok, detail = detail, icon = icon })
        end
    end

    local blessing = knowsAny(P.BLESSINGS)
    add("blessing", cfg.blessing, blessing ~= nil, "Blessing on yourself", st.blessing ~= false,
        st.blessing == nil and "can't read auras right now" or "Press the Blessing button: it does you first, then your group nearest-first.",
        ns.Rotation.Icon(blessing or "Blessing of Might"))

    add("aura", cfg.aura, st.recAura ~= nil, "Aura", st.aura ~= false,
        st.aura == nil and "can't read auras right now" or ("Use " .. tostring(st.recAura) .. (st.auraWhy and (" (" .. st.auraWhy .. ")") or "") .. ". Pick it from the Aura flyout on your action bar."),
        ns.Rotation.Icon(st.recAura or "Devotion Aura"))

    -- Seal: only nag while you're actually in melee range of an enemy.
    add("seal", cfg.seal, st.recSeal ~= nil and st.inMelee == true, "Seal", st.seal ~= false,
        "In melee range with no Seal: cast " .. tostring(st.recSeal) .. ". Don't refresh it early.",
        ns.Rotation.Icon(st.recSeal or "Seal of Righteousness"))

    if ns.Progress.Knows("Righteous Fury") then
        local tank = st.spec == "Protection"
        local rf = st.rf
        if tank then
            add("righteousFury", cfg.righteousFury, true, "Righteous Fury", rf ~= false,
                "Tanking: keep Righteous Fury on for threat.", ns.Rotation.Icon("Righteous Fury"))
        else
            add("righteousFury", cfg.righteousFury, true, "Righteous Fury is on", rf ~= true,
                "You're not tanking: Righteous Fury makes you pull threat off the tank. Right-click it off.", ns.Rotation.Icon("Righteous Fury"))
        end
    end

    local level = UnitLevel("player") or 1
    local q = Reminders.RedemptionQuest(level, ns.Progress.PlayerRace(), UnitFactionGroup("player"))
    add("redemption", cfg.redemption, q ~= nil, "Redemption quest", false,
        q and (q.name .. ": it teaches Redemption. Do it before you join groups.") or "",
        "Interface\\Icons\\Spell_Holy_Resurrection")
    return out
end

-- Consumables recommended for the player's bracket.
function Reminders.Consumables(level)
    local out = {}
    for _, c in ipairs(ns.Data.Consumables or {}) do
        if c.type == "consumable" then
            local lvl = tonumber((c.bracket or ""):match("(%d+)"))
            table.insert(out, { item = c, count = c.item_id and itemCount(c.item_id) or 0, current = lvl and level >= lvl - 8 and level <= lvl + 9 })
        end
    end
    return out
end

function Reminders.Missing()
    if not ns.db.char.reminders.enabled or InCombatLockdown() then return {} end
    local miss = {}
    for _, r in ipairs(Reminders.Evaluate()) do
        if not r.ok then table.insert(miss, r) end
    end
    return miss
end
