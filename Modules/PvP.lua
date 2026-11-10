-- Battle group data layer: Honor & Rank reads, battleground state, zone PvP
-- status. No combat log (Forever gives addons none) and no chat sending.
--
-- Forever's PvP Lua API isn't documented anywhere the research could find, so
-- every read is feature-detected and recorded in Probe(): "ok", "missing" (the
-- function doesn't exist), "secret" (exists, returns secret values) or "error".
-- The Battle screen shows that table so Tim can check it in game, and any
-- value that isn't "ok" is shown as "hidden" with a pointer to Character >
-- Player vs. Player. Nothing is guessed.
local _, ns = ...

local PvP = {}
ns.PvP = PvP

local function secret(v) return ns.Auras.IsSecret(v) end

-- name -> { status, note }
PvP.probes = {}
local function probe(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then
        PvP.probes[name] = { status = "missing" }
        return nil
    end
    local res = { pcall(fn, ...) }
    if not res[1] then
        PvP.probes[name] = { status = "error", note = tostring(res[2]) }
        return nil
    end
    for i = 2, #res do
        if secret(res[i]) then
            PvP.probes[name] = { status = "secret" }
            return nil
        end
    end
    PvP.probes[name] = { status = "ok" }
    return select(2, unpack(res))
end
PvP.Probe = probe

-- Classic-era rank API (UnitPVPRank/GetPVPRankInfo). Rank 0 = no rank.
-- Returns { rank = 0..14, name = "Private" | nil, progress = 0..1 | nil } or nil (unreadable).
function PvP.Rank()
    local rankId = probe("UnitPVPRank", "player")
    if rankId == nil then return nil end
    local name, number = probe("GetPVPRankInfo", rankId)
    local rank = (type(number) == "number" and number) or 0
    if rank < 0 then rank = 0 end
    local progress = probe("GetPVPRankProgress")
    if type(progress) ~= "number" then progress = nil end
    return { rank = rank, name = name, progress = progress }
end

-- Honor currency: found by name in the currency list (no currency ID is in the
-- research, so none is hard-coded). Returns { amount, max?, weeklyMax?, icon } or nil.
function PvP.Honor()
    local C = C_CurrencyInfo
    if not (C and C.GetCurrencyListSize and C.GetCurrencyListInfo) then
        PvP.probes["C_CurrencyInfo (list)"] = { status = "missing" }
        return nil
    end
    local okN, n = pcall(C.GetCurrencyListSize)
    if not okN or type(n) ~= "number" or secret(n) then
        PvP.probes["C_CurrencyInfo (list)"] = { status = okN and "secret" or "error" }
        return nil
    end
    for i = 1, n do
        local ok, info = pcall(C.GetCurrencyListInfo, i)
        if ok and type(info) == "table" and not secret(info.name) and info.name == "Honor" and not info.isHeader then
            PvP.probes["C_CurrencyInfo (list)"] = { status = secret(info.quantity) and "secret" or "ok" }
            if secret(info.quantity) then return nil end
            return { amount = info.quantity, max = info.maxQuantity, icon = info.iconFileID }
        end
    end
    PvP.probes["C_CurrencyInfo (list)"] = { status = "ok", note = "no currency named Honor in the list yet" }
    return nil
end

-- Honorable kills / honor this session (Classic API, no combat log needed).
function PvP.Session()
    local hk, honor = probe("GetPVPSessionStats")
    if hk == nil then return nil end
    return { hk = hk, honor = honor }
end

function PvP.Lifetime()
    local hk = probe("GetPVPLifetimeStats")
    if hk == nil then return nil end
    return { hk = hk }
end

-- Next rank reward from the research table (Blizzard's PvP post).
function PvP.Ranks()
    local p = ns.Data.PvP
    return p and p.ranks or {}
end

function PvP.NextReward(rank)
    for _, r in ipairs(PvP.Ranks()) do
        if r.rank > (rank or 0) then return r end
    end
end

-- ---------------------------------------------------------------------------
-- Battlegrounds
function PvP.Battlegrounds()
    local p = ns.Data.PvP
    return p and p.battlegrounds or {}
end

-- Is this battleground open to you at your level? (min/max from the research)
function PvP.BGOpen(bg, level)
    if not bg.min_level then return nil end
    return level >= bg.min_level and level <= (bg.max_level or 60)
end

function PvP.InBattleground()
    if not IsInInstance then return false end
    local ok, inInstance, kind = pcall(IsInInstance)
    if not ok or secret(kind) then return false end
    return inInstance and kind == "pvp" or false
end

-- ---------------------------------------------------------------------------
-- Zone status: sanctuary / friendly / contested / hostile / combat.
PvP.ZONE_TEXT = {
    sanctuary = "Sanctuary: no PvP here.",
    friendly = "Friendly territory: you're only flagged if you attack or turn PvP on.",
    contested = "Contested zone: on a PvP realm you're flagged here. Expect the other faction.",
    hostile = "Enemy territory: you're flagged and their guards attack you.",
    combat = "Combat zone: PvP everywhere.",
    arena = "Arena: free-for-all.",
    none = "No PvP status reported for this zone.",
}
PvP.ZONE_KIND = { sanctuary = "good", friendly = "good", contested = "warn", hostile = "bad", combat = "bad", arena = "bad", none = "neutral" }

-- Returns { kind = "contested"|..., text, ffa, flagged } or nil (unreadable).
function PvP.Zone()
    local pvpType, isFFA = probe("GetZonePVPInfo")
    if pvpType == nil and PvP.probes.GetZonePVPInfo.status ~= "ok" then return nil end
    local kind = pvpType or "none"
    local flagged
    if UnitIsPVP then
        local ok, v = pcall(UnitIsPVP, "player")
        if ok and not secret(v) then flagged = v and true or false end
    end
    return { kind = kind, text = PvP.ZONE_TEXT[kind] or kind, ffa = isFFA, flagged = flagged }
end

-- Tristan is on a PvP-ruleset realm (Tim, 2026-11-10). No ruleset API is in the
-- research, so this is a setting with that default; Normal realms still work.
function PvP.Ruleset()
    return (ns.db and ns.db.char.pvp.ruleset) or "PvP"
end

-- Entering a contested/hostile zone: one notice per zone change.
local lastZoneKind
function PvP.OnZoneChanged()
    if not ns.db.char.pvp.zoneNotice then return end
    local z = PvP.Zone()
    if not z then return end
    if z.kind ~= lastZoneKind and (z.kind == "contested" or z.kind == "hostile") and PvP.Ruleset() ~= "Normal" then
        local tip = ns.PvP.DangerTip()
        ns.Fire("TOAST", (z.kind == "hostile" and "Enemy territory" or "Contested zone"), z.text .. (tip and ("\n" .. tip) or ""), "Interface\\Icons\\INV_BannerPVP_01")
    end
    lastZoneKind = z.kind
end

-- A short "danger" tip from your own cooldowns: what's ready if you get jumped.
function PvP.DangerTip()
    local ready = {}
    for _, n in ipairs({ "Divine Shield", "Divine Protection", "Blessing of Freedom", "Lay on Hands" }) do
        if ns.Progress.Knows(n) then
            local left = ns.Auras.CooldownLeft(ns.Rotation.SpellId(n) or n)
            if left == 0 then table.insert(ready, n) end
        end
    end
    if #ready == 0 then return nil end
    return "Ready if you get jumped: " .. table.concat(ready, ", ") .. "."
end

-- "Buff before the gates open": entering a battleground with something missing.
function PvP.OnEnterWorld()
    if not PvP.InBattleground() or not ns.db.char.pvp.gatesReminder then return end
    C_Timer.After(3, function()
        if InCombatLockdown() then return end
        local miss = ns.Reminders.Missing()
        local names = {}
        for _, r in ipairs(miss) do table.insert(names, r.label) end
        if #names > 0 then
            ns.Fire("TOAST", "Buff before the gates open", "Missing: " .. table.concat(names, ", ") .. ". The Blessing button does your group nearest-first.", "Interface\\Icons\\Spell_Holy_FistOfJustice")
        end
    end)
end

-- Which probes the Battle screen lists (in this order).
PvP.PROBE_ORDER = { "UnitPVPRank", "GetPVPRankInfo", "GetPVPRankProgress", "C_CurrencyInfo (list)", "GetPVPSessionStats",
    "GetPVPLifetimeStats", "GetZonePVPInfo" }

function PvP.RunProbes()
    PvP.Rank()
    PvP.Honor()
    PvP.Session()
    PvP.Lifetime()
    PvP.Zone()
    return PvP.probes
end
