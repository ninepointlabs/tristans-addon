-- SavedVariables and the dual-spec-ready profile model.
--
-- TristansAddonDB      (account)        minimap, read "What's changed" ids, global toggles
-- TristansAddonCharDB  (per character)  two spec profiles A/B + active pointer, reminders,
--                                      teaching progress
--
-- Every spec-aware feature asks ns.DB.ActiveSpec(); switching profile (manually
-- now, automatically later via Core/DualSpec.lua) re-fires "SPEC_CHANGED".
local _, ns = ...

local DB = {}
ns.DB = DB

DB.SCHEMA = 1
DB.PROFILE_IDS = { "A", "B" }

local function deepDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            deepDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end
DB.deepDefaults = deepDefaults

function DB.NewProfile()
    return {
        spec = nil,               -- "Holy" | "Protection" | "Retribution"; nil until picked
        levelingWeights = nil,    -- nil = spec default (see Modules/Stats.lua)
        pvpWeights = false,       -- Gear: PvP weight profile (more Stamina) on/off
        weights = {},             -- per-stat overrides of the derived weights
        rotationContext = "solo", -- "solo" | "dungeon" | "raid"
    }
end

DB.accountDefaults = {
    schema = DB.SCHEMA,
    minimap = { angle = 215, hide = false },
    changesRead = {},
    tooltip = { enabled = true, showStats = true },
    bags = { highlight = true, toast = true },
    percentScale = 10, -- points per 1% hit/crit: addon assumption, editable, flagged in-game
    debug = false,
}

DB.charDefaults = {
    schema = DB.SCHEMA,
    active = "A",
    profiles = {},
    autoSwitch = true, -- follow the active talent spec (Core/DualSpec.lua): group 1 = A, group 2 = B
    reminders = {
        enabled = true, blessing = true, aura = true, seal = true, righteousFury = true,
        redemption = true, gates = true,
    },
    rotation = { enabled = true, showInCombatOnly = false, scale = 1, point = nil },
    learn = { hints = true, seenSpells = {}, readLessons = {} },
    summary = { enabled = true },
    -- Blessing button (Paladin bar). byClass: per-class override ("Might"|"Wisdom"|"Kings"|nil = class default).
    blessing = { enabled = true, key = nil, kingsForAll = false, greater = true, greaterMin = 3, byClass = {} },
    auraHint = { enabled = true, override = nil },
    sealHint = { enabled = true },
    paladinBar = { point = nil },
    -- Battle group: PvP bar (secure /cast buttons), cooldown list, world PvP notices.
    pvpBar = { show = "pvp", point = nil, ally = nil, keys = {} }, -- show: "always" | "pvp" | "never"
    pvp = { ruleset = "PvP", rewardGoal = nil, zoneNotice = true, gatesReminder = true, cooldownsOnHud = true },
    window = { tab = "overview" },
    lastLevel = nil,
}

-- Wire up (or create) the saved tables. Pure function of its inputs so tests can
-- drive it without a client.
function DB.Init(account, char)
    account = deepDefaults(account or {}, DB.accountDefaults)
    char = deepDefaults(char or {}, DB.charDefaults)
    for _, id in ipairs(DB.PROFILE_IDS) do
        char.profiles[id] = deepDefaults(char.profiles[id] or {}, DB.NewProfile())
    end
    if not char.profiles[char.active] then char.active = "A" end
    DB.global, DB.char = account, char
    ns.db = { global = account, char = char }
    return account, char
end

function DB.Profile(id)
    return DB.char.profiles[id or DB.char.active]
end

function DB.ActiveId()
    return DB.char.active
end

function DB.ActiveSpec()
    local p = DB.Profile()
    return p and p.spec
end

function DB.HasChosenSpec()
    return DB.ActiveSpec() ~= nil
end

function DB.SetSpec(spec, id)
    assert(ns.Specs[spec], "unknown spec " .. tostring(spec))
    local p = DB.Profile(id)
    local changed = p.spec ~= spec
    p.spec = spec
    if changed and (id == nil or id == DB.char.active) then ns.Fire("SPEC_CHANGED", spec) end
end

function DB.SwitchProfile(id)
    if not DB.char.profiles[id] or DB.char.active == id then return false end
    DB.char.active = id
    ns.Fire("SPEC_CHANGED", DB.ActiveSpec())
    return true
end

function DB.OtherProfileId()
    return DB.char.active == "A" and "B" or "A"
end
