-- Minimal, strict WoW API mock for headless tests (Lua 5.1).
-- Undefined globals raise an error so typos and unmocked APIs surface here
-- instead of in the client. Optional APIs the addon feature-tests are listed in
-- OPTIONAL and read as nil.
local M = {}

M.texts = {}       -- every SetText call, for assertions
M.events = {}      -- frames registered per event
M.timers = {}
M.state = {
    level = 24, race = "Human", class = "PALADIN", faction = "Alliance", money = 345678, knownNames = {},
    projectId = 18, combat = false, known = {}, auras = {}, targetAuras = {}, target = true,
    mana = 80, targetHp = 60, cooldowns = {}, equipped = {}, itemLines = {}, itemInfo = {},
    questsDone = {}, bags = {}, bagSlots = {},
}

local function newObject(kind)
    local o = { __kind = kind, __shown = true, __scripts = {}, __w = 100, __h = 20 }
    return setmetatable(o, {
        __index = function(t, k)
            if k == "SetText" then
                return function(self, s) self.__text = s table.insert(M.texts, tostring(s or "")) end
            elseif k == "GetText" then
                return function(self) return self.__text end
            elseif k == "SetScript" then
                return function(self, ev, fn) self.__scripts[ev] = fn end
            elseif k == "GetScript" then
                return function(self, ev) return self.__scripts[ev] end
            elseif k == "HookScript" then
                return function(self, ev, fn) self.__scripts[ev] = fn end
            elseif k == "RegisterEvent" or k == "RegisterUnitEvent" then
                return function(self, ev) M.events[ev] = M.events[ev] or {} table.insert(M.events[ev], self) end
            elseif k == "UnregisterEvent" then
                return function() end
            elseif k == "Show" then
                return function(self) self.__shown = true if self.__scripts.OnShow then self.__scripts.OnShow(self) end end
            elseif k == "Hide" then
                return function(self) self.__shown = false end
            elseif k == "SetShown" then
                return function(self, v) if v then self:Show() else self:Hide() end end
            elseif k == "IsShown" or k == "IsVisible" then
                return function(self) return self.__shown end
            elseif k == "SetWidth" then
                return function(self, w) self.__w = w end
            elseif k == "SetHeight" then
                return function(self, h) self.__h = h end
            elseif k == "SetSize" then
                return function(self, w, h) self.__w, self.__h = w, h end
            elseif k == "GetWidth" then
                return function(self) return self.__w end
            elseif k == "GetHeight" then
                return function(self) return self.__h end
            elseif k == "GetStringHeight" then
                return function() return 14 end
            elseif k == "GetStringWidth" then
                return function(self) return #(tostring(self.__text or "")) * 6 end
            elseif k == "GetChecked" then
                return function(self) return self.__checked end
            elseif k == "SetChecked" then
                return function(self, v) self.__checked = v end
            elseif k == "GetFrameLevel" then
                return function() return 1 end
            elseif k == "GetPoint" then
                return function() return "CENTER", nil, "CENTER", 0, 0 end
            elseif k == "GetCenter" then
                return function() return 0, 0 end
            elseif k == "GetEffectiveScale" then
                return function() return 1 end
            elseif k == "SetAttribute" then
                return function(self, name, v) rawset(self, "__attr_" .. name, v == nil and false or v) end
            elseif k == "GetAttribute" then
                return function(self, name) local v = rawget(self, "__attr_" .. name) if v == false then return nil end return v end
            elseif k == "GetItem" then
                return function(self) return "Item", self.__item end
            elseif k:match("^Create") then
                return function() return newObject(k) end
            elseif k:match("^Is") or k:match("^Can") then
                return function() return false end
            else
                return function() return nil end
            end
        end,
    })
end
M.newObject = newObject

function M.Fire(event, ...)
    for _, f in ipairs(M.events[event] or {}) do
        local fn = f.__scripts.OnEvent
        if fn then fn(f, event, ...) end
    end
end

function M.RunTimers()
    local list = M.timers
    M.timers = {}
    for _, t in ipairs(list) do if not t.cancelled then t.fn() end end
end

local S = M.state
local G = {}

G.WOW_PROJECT_ID = function() return S.projectId end -- resolved below
G.CreateFrame = function(kind, name) local f = newObject(kind) if name then _G[name] = f end return f end
G.UIParent = newObject("UIParent")
G.ChatFontNormal = newObject("Font")
G.Minimap = newObject("Minimap")
G.GameTooltip = newObject("GameTooltip")
G.ItemRefTooltip = newObject("ItemRefTooltip")
G.UISpecialFrames = {}
G.StaticPopupDialogs = {}
G.StaticPopup_Show = function() end
G.SlashCmdList = {}
G.CLOSE = "Close"
G.Mixin = function(o, m) for k, v in pairs(m) do o[k] = v end return o end
G.BackdropTemplateMixin = {}
G.Settings = { RegisterCanvasLayoutCategory = function() return {} end, RegisterAddOnCategory = function() end }
G.SettingsPanel = newObject("SettingsPanel")
G.HideUIPanel = function() end
G.Enum = { TooltipDataType = { Item = 0 } }
G.TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) M.tooltipHook = fn end }
G.C_Timer = {
    After = function(_, fn) table.insert(M.timers, { fn = fn }) end,
    NewTimer = function(_, fn) local t = { fn = fn, Cancel = function(self) self.cancelled = true end } table.insert(M.timers, t) return t end,
    NewTicker = function(_, fn) return { Cancel = function() end } end,
}
G.C_AddOns = { GetAddOnMetadata = function() return "test" end }
G.C_Item = {
    GetItemInfoInstant = function(id)
        local info = S.itemInfo[id] or S.itemInfo[tonumber(tostring(id):match("item:(%d+)") or id)]
        if not info then return nil end
        return id, "Armor", "Cloth", info.equipLoc, 134400, info.classID, info.subclassID
    end,
    GetItemInfo = function(id)
        id = tonumber(tostring(id):match("item:(%d+)")) or id
        local info = S.itemInfo[id]
        if not info then return nil end
        return "Item", "item:" .. id, 2, 20, info.minLevel or 1
    end,
    GetItemIconByID = function() return 134400 end,
    GetItemNameByID = function(id) return "Item " .. id end,
    GetItemCount = function(id) return S.bags[id] or 0 end,
}
G.C_Spell = {
    GetSpellName = function(id) return S.spellNames and S.spellNames[id] or nil end,
    GetSpellTexture = function() return 136207 end,
    GetSpellInfo = function(name) return S.knownNames[name] and { name = name } or nil end,
    GetSpellCooldown = function(name)
        if S.secretMode and S.secretCooldowns then return { startTime = M.SECRET, duration = M.SECRET } end
        local left = S.cooldowns[name] or 0
        return { startTime = (S.time or 1000) - 0, duration = left > 0 and (left + 0) or 0 }
    end,
    IsSpellUsable = function(name) if S.secretMode then return M.SECRET end return S.usable and S.usable[name] or false end,
}
G.C_UnitAuras = {
    GetAuraDataBySpellName = function(unit, name)
        if S.secretMode and unit ~= "player" then return M.SECRET end
        if S.secretMode and S.secretOwnAuras then return M.SECRET end
        local set = unit == "player" and S.auras or (S.units[unit] and S.units[unit].buffs) or S.targetAuras
        local v = set[name]
        if type(v) == "table" then local d = { name = name } for k2, x in pairs(v) do d[k2] = x end return d end
        return v and { name = name } or nil
    end,
}
G.C_QuestLog = { IsQuestFlaggedCompleted = function(id) return S.questsDone[id] == true end }
G.C_TooltipInfo = {
    GetHyperlink = function(link)
        local lines = S.itemLines[link]
        if not lines then return nil end
        local out = {}
        for i, l in ipairs(lines) do out[i] = { leftText = l } end
        return { lines = out }
    end,
}
G.UnitLevel = function(u) if u and u ~= "player" and S.units[u] and S.units[u].level then return S.units[u].level end return S.level end
G.UnitRace = function() return S.race, S.race end
G.UnitClass = function(u) local x = u and u ~= "player" and S.units[u] if x and x.class then return x.class, x.class end return "Paladin", S.class end
G.UnitFactionGroup = function() return S.faction, S.faction end
G.UnitExists = function(u) return u == "player" or (u == "target" and S.target) or (S.units[u] ~= nil) end
G.UnitCanAttack = function() return true end
G.UnitIsDead = function() return false end
G.UnitAffectingCombat = function() return S.combat end
G.UnitPower = function(u) local x = u and u ~= "player" and S.units[u] if x and x.mana then return x.mana end return S.mana end
G.UnitPowerMax = function() return 100 end
G.UnitHealth = function() if S.secretMode then return M.SECRET end return S.targetHp end
G.UnitHealthMax = function() return 100 end
G.InCombatLockdown = function() return S.combat end
G.GetMoney = function() return S.money end
G.GetBuildInfo = function() return "1.60.1", "70862", "Nov 6 2026", 16001 end
G.GetInventoryItemLink = function(_, slot) return S.equipped[slot] end
G.IsPlayerSpell = function(id) return S.known[id] == true end
G.IsSpellKnown = function(id) return S.known[id] == true end
G.GetTime = function() return S.time or 1000 end
G.GetCursorPosition = function() return 0, 0 end
G.IsShiftKeyDown = function() return S.shift or false end
G.IsModifiedClick = function() return false end
G.ChatEdit_InsertLink = function() end
G.hooksecurefunc = function(a, b, c)
    -- hooksecurefunc(table, "method", fn) or hooksecurefunc("global", fn)
    if type(a) == "table" then
        local orig = a[b]
        a[b] = function(...) local r = orig and orig(...) c(...) return r end
    end
end
G.C_Container = {
    GetContainerNumSlots = function(bag) return S.bagSlots[bag] and #S.bagSlots[bag] or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local link = S.bagSlots[bag] and S.bagSlots[bag][slot]
        local id = link and tonumber(tostring(link):match("item:(%d+)"))
        return link and { hyperlink = link, stackCount = (S.bagStacks and S.bagStacks[link]) or 1, itemID = id } or nil
    end,
}
G.NUM_BAG_SLOTS = 4
G.NUM_TOTAL_BAG_FRAMES = 0
-- One combined-bags frame with two buttons (bag 0, slots 1-2).
local bagButtons = {}
for i = 1, 2 do
    local b = newObject("ItemButton")
    b.GetBagID = function() return 0 end
    b.GetID = function() return i end
    b.isExtended = false
    bagButtons[i] = b
end
M.bagButtons = bagButtons
G.ContainerFrameMixin = { UpdateItems = function() end }
G.ContainerFrameCombinedBags = newObject("ContainerFrameCombinedBags")
G.ContainerFrameCombinedBags.EnumerateValidItems = function() return ipairs(bagButtons) end
-- Map: a top map with two zones; The Barrens has the Wailing Caverns entrance.
local function vec(x, y) return { GetXY = function() return x, y end } end
M.waypoints = {}
G.C_Map = {
    GetBestMapForUnit = function() return 10 end,
    GetFallbackWorldMapID = function() return 947 end,
    GetMapInfo = function(id)
        local maps = { [947] = { name = "Azeroth", parentMapID = 0 }, [10] = { name = "Northern Barrens", parentMapID = 947 },
            [2200] = { name = "Riverglades", parentMapID = 947 } }
        return maps[id] and { mapID = id, name = maps[id].name, parentMapID = maps[id].parentMapID } or nil
    end,
    GetMapChildrenInfo = function(top)
        return { { mapID = 10, name = "Northern Barrens", mapType = 3 }, { mapID = 2200, name = "Riverglades", mapType = 3 } }
    end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(p) table.insert(M.waypoints, p) end,
}
G.UiMapPoint = { CreateFromCoordinates = function(mapID, x, y) return { mapID = mapID, x = x, y = y } end }
G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) M.superTracked = v end }
G.C_EncounterJournal = {
    GetDungeonEntrancesForMap = function(mapID)
        if mapID == 10 then return { { name = "Wailing Caverns", position = vec(0.389, 0.693) } } end
        return {}
    end,
}
-- Simple unit world (group, nameplates, the sheep): S.units[token] = {guid, name, player, friend, dead, offline, range, buffs={}, dist}
S.units = {}
local function U(u) if u == "player" then return S.units.player or { guid = "P", name = "Tristan", player = true, friend = true, buffs = S.auras, class = "PALADIN" } end return S.units[u] end
G.IsInRaid = function() return false end
G.IsInGroup = function() return S.units.party1 ~= nil end
G.UnitGUID = function(u) if u == "target" and S.targetGUID then return S.targetGUID end return U(u) and U(u).guid end
G.UnitIsPlayer = function(u) return U(u) and U(u).player or false end
G.UnitCanAssist = function(_, u) return U(u) and U(u).friend or false end
G.UnitIsDeadOrGhost = function(u) return U(u) and U(u).dead or false end
G.UnitIsConnected = function(u) return not (U(u) and U(u).offline) end
G.UnitIsUnit = function(a, b) return U(a) and U(b) and U(a).guid == U(b).guid or false end
G.UnitDistanceSquared = function(u) if U(u) and U(u).dist then return U(u).dist, true end return 0, false end
G.C_Spell.IsSpellInRange = function(_, u) local x = U(u) if not x then return nil end return x.range end
M.macros = {}
G.GetMacroIndexByName = function(n) for i, m in ipairs(M.macros) do if m.name == n then return i end end return 0 end
G.CreateMacro = function(name, icon, body) table.insert(M.macros, { name = name, body = body }) return #M.macros end
G.EditMacro = function(i, name, icon, body) M.macros[i].body = body end
G.PickupMacro = function(i) M.pickedMacro = i end
G.GetMacroInfo = function(i) local m = M.macros[i] return m and m.name, 134400, m and m.body end
G.GetCVarBool = function() return false end
M.overrides = {}
M.overrideOwner = {}
G.SetOverrideBindingClick = function(owner, prio, key, name, button) M.overrides[key] = name .. ":" .. button M.overrideOwner[key] = owner end
G.ClearOverrideBindings = function(owner)
    for k, o in pairs(M.overrideOwner) do if o == owner then M.overrides[k] = nil M.overrideOwner[k] = nil end end
end
G.GetBindingText = function(k) return k end
G.IsAltKeyDown = function() return S.alt or false end
G.IsControlKeyDown = function() return S.ctrl or false end
G.DeleteMacro = function(i) table.remove(M.macros, i) end
G.UnitName = function(u) if u == "player" then return "Tristan" end if u == "target" and S.targetName then return S.targetName end return S.units[u] and S.units[u].name end
G.GetUnitName = function(u, withRealm) local x = S.units[u] if not x then return u == "player" and "Tristan" or nil end return x.realm and (x.name .. "-" .. x.realm) or x.name end
G.IsMetaKeyDown = function() return S.meta or false end
G.GetBindLocation = function() return S.bind end
G.SecureCmdOptionParse = function(s) local unit = s:match("^%[@([%w]+),") return (unit and G.UnitExists(unit)) and "x" or nil, unit end
-- Trading: S.units.NPC is the trade partner; S.tradeSlots[i] = item placed.
M.trades, M.chat = {}, {}
S.tradeSlots = {}
G.CheckInteractDistance = function(u) local x = U(u) if not x then return false end if x.tradeRange == nil then return true end return x.tradeRange end
G.InitiateTrade = function(u) table.insert(M.trades, u) end
G.GetTradePlayerItemInfo = function(i) return S.tradeSlots[i] end
G.ClickTradeButton = function(i) if M.cursor then S.tradeSlots[i] = M.cursor M.cursor = nil end end
G.CursorHasItem = function() return M.cursor ~= nil end
G.ClearCursor = function() M.cursor = nil end
G.C_Container.PickupContainerItem = function(bag, slot) M.cursor = { bag = bag, slot = slot, count = "all" } end
G.C_Container.SplitContainerItem = function(bag, slot, n) M.cursor = { bag = bag, slot = slot, count = n } end
G.C_ChatInfo = { SendChatMessage = function(msg, chatType, _, target) table.insert(M.chat, { msg = msg, chatType = chatType, target = target }) end }
G.C_SpecializationInfo = { GetActiveSpecGroup = function() return S.specGroup or 1 end }
G.GetNumSpecGroups = function() return S.numSpecGroups or 1 end

-- Secret values (Forever's addon restrictions): an opaque sentinel that
-- issecretvalue() recognises once a test installs it.
M.SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
function M.InstallSecrets() rawset(_G, "issecretvalue", function(v) return v == M.SECRET end) end
function M.RemoveSecrets() rawset(_G, "issecretvalue", nil) S.secretMode = false end

-- PvP / zone / combat-target APIs.
G.UnitAttackSpeed = function() return S.weaponSpeed or 3.6, nil end
G.UnitCreatureType = function() if S.secretMode then return M.SECRET end return S.creatureType end
G.IsInInstance = function() if S.instanceType then return true, S.instanceType end return false, "none" end
G.UnitIsPVP = function() return S.flagged or false end
G.GetZonePVPInfo = function() return S.zonePvP, S.zoneFFA, nil end
G.UnitPVPRank = function() if S.secretMode then return M.SECRET end return S.pvpRankId or 0 end
G.GetPVPRankInfo = function(id) if not id or id < 5 then return nil, 0 end return "Rank " .. (id - 4), id - 4 end
G.GetPVPSessionStats = function() return S.sessionHK or 0, S.sessionHonor or 0 end
G.C_CurrencyInfo = {
    GetCurrencyListSize = function() return S.currencies and #S.currencies or 0 end,
    GetCurrencyListInfo = function(i) return S.currencies and S.currencies[i] end,
}
G.IsUsableSpell = function() return false end

local OPTIONAL = {
    issecretvalue = true, WOW_PROJECT_CAMELOT = true, AuraUtil = true, GetSpellInfo = true, strtrim = true,
    TristansAddonDB = true, TristansAddonCharDB = true, TristansAddonFrame = true, TristansAddonHud = true,
    TristansAddonMinimapButton = true, SLASH_TRISTANSADDON1 = true, SLASH_TRISTANSADDON2 = true,
    TristansAddon_OnCompartmentClick = true, OpenWorldMap = true, GetPVPRankProgress = true, GetPVPLifetimeStats = true,
}

function M.Install()
    for k, v in pairs(G) do rawset(_G, k, v) end
    rawset(_G, "WOW_PROJECT_ID", S.projectId)
    setmetatable(_G, {
        __index = function(_, k)
            if OPTIONAL[k] then return nil end
            error("undefined global: " .. tostring(k), 2)
        end,
    })
end

-- Load every file listed in the TOC with (addonName, ns) varargs.
function M.LoadAddon(tocPath, root)
    local ns = {}
    for line in io.lines(tocPath) do
        if not line:match("^##") and line:match("%S") then
            local path = root .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")
            local chunk = assert(loadfile(path))
            chunk("TristansAddon", ns)
        end
    end
    return ns
end

return M
