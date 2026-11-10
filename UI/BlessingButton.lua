-- "Bless next" button: one press casts your Blessing on the next friendly
-- player who's missing one from you, nearest first. Ported from the sister
-- addons' Fortitude and Arcane Intellect buttons (same rules, same look),
-- with the Paladin twists:
--   * Class-smart (Tim's decision 2026-11-10): Might for Warriors, Rogues and
--     Hunters, Wisdom for casters and healers, Kings for everyone once known if
--     you pick that. Every class can be overridden in Settings > Paladin bar.
--     Your own Blessing follows your spec (Might for Ret/Prot, Wisdom for Holy).
--   * One Blessing from you per target: anyone you've just given Blessing of
--     Freedom or Protection is skipped until it ends (casting Might would replace
--     it), then offered again.
--   * Greater Blessings only when you know them, in a raid, when 3+ of that
--     class need it.
--
-- Blizzard rules this follows:
--   * A secure action button does the cast; every cast needs your click / key
--     press. The addon never casts by itself.
--   * Who the button targets only changes out of combat. In combat it keeps its
--     last target (and says so).
--   * It casts through the button's own "/cast [@unit,help,nodead] <Blessing>"
--     line (type=spell failed on Forever; the Priest addon's v0.1.5 fix). Strangers are
--     reached with /targetexact (Forever silently ignores [@nameplateN]) and your
--     target is restored afterwards.
--   * "Nearest" = you, then group members (nearest first when the client reports
--     distance), your target, then friendly players with a visible nameplate.
local _, ns = ...
local UI = ns.UI

local Int = {}
ns.Blessing = Int

Int.NAME = "TristansBlessingButton"
Int.CLICK = Int.NAME
Int.RECENT_SECONDS = 4 -- skip someone we just blessed until their aura shows up
Int.ICON = "Interface\\Icons\\Spell_Holy_FistOfJustice"
Int.SHORT = { Might = "Blessing of Might", Wisdom = "Blessing of Wisdom", Kings = "Blessing of Kings" }

local btn, cell, current
local recent = {} -- guid -> GetTime() of our last cast on them

local function safe(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

local function knows(name) return ns.Progress.Knows(name) end

-- Which Blessing a class gets: override > Kings-for-all > class default > whatever you know.
-- known(name) injectable for tests.
function Int.ChoiceForClass(class, known, cfg, isSelf, spec)
    known = known or knows
    cfg = cfg or ns.db.char.blessing
    local want
    if cfg.byClass and cfg.byClass[class] then want = cfg.byClass[class]
    elseif cfg.kingsForAll and known(Int.SHORT.Kings) then want = "Kings"
    elseif isSelf then want = (spec == "Holy") and "Wisdom" or "Might"
    else want = ns.Paladin.CLASS_DEFAULT[class] or "Wisdom" end
    local spell = Int.SHORT[want]
    if spell and known(spell) then return spell end
    for _, alt in ipairs({ "Might", "Wisdom", "Kings" }) do
        if known(Int.SHORT[alt]) then return Int.SHORT[alt] end
    end
    return nil
end

local function unitClass(unit)
    local ok, _, class = pcall(UnitClass, unit)
    if ok and class and not ns.Auras.IsSecret(class) then return class end
    return nil
end

function Int.KnowsAny()
    for _, n in ipairs(ns.Paladin.BLESSINGS) do if knows(n) then return true end end
    return false
end

-- Has my Blessing? true/false/nil(unknown). "busy" when my Freedom/Protection is on them.
function Int.HasBuff(unit)
    local mine = ns.Paladin.MyBlessingOn(unit)
    if mine then return true end
    local rep = ns.Paladin.MyReplacingOn(unit)
    if rep then return "busy" end
    if mine == nil or rep == nil then return nil end
    return false
end

function Int.InRange(unit, spell)
    if UnitIsUnit("player", unit) then return true end
    spell = spell or Int.SHORT.Might
    if C_Spell and C_Spell.IsSpellInRange then
        local r = safe(C_Spell.IsSpellInRange, ns.Rotation.SpellId(spell) or spell, unit)
        if r ~= nil and not ns.Auras.IsSecret(r) then return r end
        return safe(C_Spell.IsSpellInRange, spell, unit)
    end
    return nil
end

-- Unit tokens to consider, in "nearest first" order.
function Int.CandidateUnits()
    local list = { { unit = "player", order = 0 } }
    local group = {}
    if IsInRaid() then
        for i = 1, 40 do table.insert(group, "raid" .. i) end
    elseif IsInGroup() then
        for i = 1, 4 do table.insert(group, "party" .. i) end
    end
    for _, u in ipairs(group) do
        if UnitExists(u) then
            local d, checked = nil, false
            if UnitDistanceSquared then d, checked = safe(UnitDistanceSquared, u) end
            local dist = (checked and type(d) == "number" and not ns.Auras.IsSecret(d)) and d or nil
            table.insert(list, { unit = u, order = 1, dist = dist })
        end
    end
    table.insert(list, { unit = "target", order = 2 })
    for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists(u) then table.insert(list, { unit = u, order = 3 }) end
    end
    return list
end

-- Pick the next unit to bless. Returns { unit, name, guid, class, spell, rangeKnown, buffKnown, classNeed } or nil,
-- plus a reason, the eligible count and how many group members need one.
function Int.Pick(now)
    now = now or GetTime()
    local seen, eligible = {}, {}
    local outOfRange, groupNeed, busy = 0, 0, 0
    local classNeed = {}
    for _, c in ipairs(Int.CandidateUnits()) do
        local u = c.unit
        local guid = UnitExists(u) and UnitGUID(u)
        if guid and not ns.Auras.IsSecret(guid) and not seen[guid] then
            seen[guid] = true
            local ok = UnitIsPlayer(u) and UnitCanAssist("player", u) and not UnitIsDeadOrGhost(u)
                and UnitIsConnected(u)
                and not (recent[guid] and now - recent[guid] < Int.RECENT_SECONDS)
            if ok then
                local has = Int.HasBuff(u)
                local class = unitClass(u)
                local isSelf = UnitIsUnit(u, "player")
                local spell = Int.ChoiceForClass(class, nil, nil, isSelf, ns.DB.ActiveSpec())
                local range = spell and Int.InRange(u, spell)
                if has == "busy" then
                    busy = busy + 1
                elseif not spell then
                    -- nothing known to cast
                elseif range == false then
                    if has ~= true then outOfRange = outOfRange + 1 end
                elseif has ~= true then
                    if c.order <= 1 and class then classNeed[class] = (classNeed[class] or 0) + 1 end
                    if c.order <= 1 then groupNeed = groupNeed + 1 end
                    table.insert(eligible, { unit = u, guid = guid, name = UnitName(u), order = c.order, dist = c.dist,
                        buffKnown = has == false, rangeKnown = range == true, class = class, spell = spell })
                end
            end
        end
    end
    table.sort(eligible, function(a, b)
        -- Confirmed missing + confirmed in range first, then group order, then distance.
        local ak = (a.buffKnown and 0 or 1) + (a.rangeKnown and 0 or 2)
        local bk = (b.buffKnown and 0 or 1) + (b.rangeKnown and 0 or 2)
        if ak ~= bk then return ak < bk end
        if a.order ~= b.order then return a.order < b.order end
        if a.dist and b.dist then return a.dist < b.dist end
        return false
    end)
    local reason
    if #eligible == 0 then
        if outOfRange > 0 then reason = outOfRange .. " player(s) need it but are out of range"
        elseif busy > 0 then reason = busy .. " player(s) have your Freedom or Protection; offered again when it ends"
        else reason = "everyone nearby is blessed" end
    end
    if eligible[1] then eligible[1].classNeed = classNeed[eligible[1].class or ""] or 0 end
    return eligible[1], reason, #eligible, groupNeed
end

-- Which spell to cast on the pick: a Greater Blessing only if you know it, you're
-- in a raid and 3+ of that class need it (setting), else the normal one.
function Int.SpellFor(pick, known)
    known = known or knows
    local cfg = ns.db.char.blessing
    if not pick or not pick.spell then return nil end
    local greater = ns.Paladin.GREATER[pick.spell]
    if greater and cfg.greater and IsInRaid() and pick.order <= 1 and (pick.classNeed or 0) >= (cfg.greaterMin or 3) and known(greater) then
        return greater
    end
    return pick.spell
end

local DIRECT = { player = true, target = true, focus = true }
function Int.IsDirectUnit(unit)
    return DIRECT[unit] or unit:match("^party%d+$") ~= nil or unit:match("^raid%d+$") ~= nil
end

function Int.MacroText(unit, name, hadTarget, spell)
    spell = spell or Int.SHORT.Might
    if Int.IsDirectUnit(unit) or not name then
        return ns.PaladinBar.CastText(spell, unit)
    end
    return ("/targetexact %s\n/cast [@target,help,nodead] %s\n%s"):format(name, spell, hadTarget and "/targetlasttarget" or "/cleartarget")
end

-- Full name (with realm for other-realm players) for /targetexact.
local function fullName(unit)
    if GetUnitName then
        local ok, n = pcall(GetUnitName, unit, true)
        if ok and n and not ns.Auras.IsSecret(n) then return n end
    end
    return UnitName(unit)
end

-- Re-aim the secure button (out of combat only).
function Int.Update()
    if not btn then return end
    if InCombatLockdown() then
        btn.status:SetText(current and (UI.Hex(UI.C.dim) .. "in combat: " .. (current.name or "?") .. "|r") or (UI.Hex(UI.C.dim) .. "in combat|r"))
        return
    end
    local pick, reason, count = Int.Pick()
    current = pick
    if pick then
        local spell = Int.SpellFor(pick)
        pick.cast = spell
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", Int.MacroText(pick.unit, fullName(pick.unit), UnitExists("target"), spell))
        btn:SetAttribute("unit", pick.unit)
        btn.status:SetText((UnitIsUnit(pick.unit, "player") and "you" or (pick.name or "?")) .. (count > 1 and (UI.Hex(UI.C.dim) .. " +" .. (count - 1) .. "|r") or ""))
        btn.stock:SetText(UI.Hex(spell:find("^Greater") and UI.C.info or UI.C.dim) .. (spell:gsub("^Greater ", "G. "):gsub("Blessing of ", "")) .. "|r")
        btn.icon:SetTexture(ns.Rotation.Icon(spell))
        ns.PaladinBar.SetLook(btn, true)
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
        btn:SetAttribute("unit", nil)
        btn.status:SetText(UI.Hex(UI.C.dim) .. (reason == "everyone nearby is blessed" and "all blessed" or (reason and reason:find("Freedom") and "wait" or "none in range")) .. "|r")
        btn.stock:SetText("")
        btn.icon:SetTexture(Int.ICON)
        ns.PaladinBar.SetLook(btn, false)
    end
    btn.reason = reason
    btn.count = count
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == btn then btn:GetScript("OnEnter")(btn) end
end

function Int.ShouldShow()
    local cfg = ns.db and ns.db.char.blessing
    return cfg and cfg.enabled and Int.KnowsAny() and true or false
end

function Int.Build()
    if btn then return btn end
    cell = ns.PaladinBar.Cell("blessing", 1)
    btn = CreateFrame("Button", Int.NAME, cell, "SecureActionButtonTemplate, BackdropTemplate")
    ns.PaladinBar.Decorate(btn, cell, Int.ICON)
    -- Mouse and key binding act on release (see SecureActionButton_OnClick).
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bless next: " .. (current and current.cast or "Blessing"), 1, 0.82, 0)
        if current then
            GameTooltip:AddLine("Next: " .. (current.name or "?") .. (current.rangeKnown and "" or " (range unknown)") .. (current.buffKnown and "" or " (buff state unknown)"), 1, 1, 1)
            if (s.count or 0) > 1 then GameTooltip:AddLine((s.count - 1) .. " more after that", 0.7, 0.7, 0.7) end
        else
            GameTooltip:AddLine("Nobody to buff: " .. (s.reason or "?"), 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine("Click or press " .. (Int.Key() or "your key (Settings > Paladin bar)") .. ": one cast per press.", 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine("Nearest = you, your group, your target, then players with friendly nameplates shown (Shift+V). Might for melee, Wisdom for casters (Settings > Paladin bar to change per class).", 0.6, 0.6, 0.6, true)
        if InCombatLockdown() then GameTooltip:AddLine("In combat the target can't change until combat ends.", 1, 0.5, 0.3, true) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- After a press, remember who we just buffed, watch what the game did, move on.
    btn:HookScript("PostClick", function(_, _, down)
        if down then return end -- the action fires on release; ignore the press half
        if current and current.guid then recent[current.guid] = GetTime() end
        Int.Watch(current)
        C_Timer.After(0.3, function() if not InCombatLockdown() then Int.Update() end end)
    end)
    return btn
end

local ticker
function Int.Refresh()
    if InCombatLockdown() then return end -- show/hide of secure frames is blocked in combat
    Int.Build()
    local show = Int.ShouldShow()
    cell.want = show
    ns.PaladinBar.Layout()
    if show and not ticker then
        ticker = C_Timer.NewTicker(0.5, function() pcall(Int.Update) end)
    elseif not show and ticker then
        ticker:Cancel()
        ticker = nil
    end
    if show then Int.Update() end
    Int.ApplyKey()
end

-- Click diagnostics: for ~1.5s after a press, report whether a cast started,
-- failed (red error text) or was blocked by the client.
local watch
function Int.ConditionCheck(unit)
    if not unit or not SecureCmdOptionParse then return "n/a" end
    local ok, action, target = pcall(SecureCmdOptionParse, "[@" .. unit .. ",help,nodead] x")
    if not ok then return "error" end
    if action then return "pass (" .. tostring(target) .. ")" end
    return "FAIL"
end

function Int.Watch(target)
    watch = { name = target and target.name or "?", unit = target and target.unit, spell = target and target.cast or "Blessing" }
    watch.cond = Int.ConditionCheck(watch.unit)
    watch.macro = btn and btn:GetAttribute("macrotext")
    C_Timer.After(1.5, function()
        local w = watch
        watch = nil
        if not w then return end
        if w.sent or w.succeeded then
            if ns.db.global.debug then ns.Print(w.spell .. " on " .. w.name .. (w.succeeded and " succeeded." or " started.")) end
        elseif w.error then
            ns.Print("|cffff5050" .. w.spell .. " on " .. w.name .. " failed:|r " .. w.error)
        elseif w.blocked then
            ns.Print("|cffff5050The game blocked the buff button|r (" .. w.blocked .. "). /tristan bless debug shows details.")
        elseif target then
            ns.Print("|cffff5050Buff button pressed but no cast started|r (target " .. w.name .. ", " .. tostring(w.unit)
                .. ", macro condition " .. tostring(w.cond) .. "). Please share this line and /tristan bless debug.")
        end
    end)
end

local function isOurs(spellID)
    local n = spellID and ns.Auras.SpellName(spellID)
    if not n then return false end
    for _, b in ipairs(ns.Paladin.BLESSINGS) do
        if n == b or n == ns.Paladin.GREATER[b] then return true end
    end
    return false
end
ns.On("WOW_UNIT_SPELLCAST_SENT", function(unit, targetName, _, spellID)
    if unit ~= "player" or not isOurs(spellID) then return end
    if watch then watch.sent = true end
    -- Casts from the action bar don't fire PostClick: skip whoever we just buffed.
    if current and current.guid and (targetName == nil or targetName == current.name or (current.name and tostring(targetName):find("^" .. current.name))) then
        recent[current.guid] = GetTime()
    end
    C_Timer.After(0.3, function() if btn and not InCombatLockdown() then Int.Update() end end)
end)
ns.On("WOW_UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if watch and unit == "player" and isOurs(spellID) then watch.succeeded = true end
end)
ns.On("WOW_UNIT_SPELLCAST_FAILED", function(unit, _, spellID)
    if watch and unit == "player" and isOurs(spellID) and not watch.error then watch.error = "spell failed" end
end)
ns.On("WOW_UI_ERROR_MESSAGE", function(_, message)
    if watch and type(message) == "string" then watch.error = message end
end)
local function blocked(addon, func)
    if watch then watch.blocked = tostring(addon) .. ": " .. tostring(func) end
end
ns.On("WOW_ADDON_ACTION_BLOCKED", blocked)
ns.On("WOW_ADDON_ACTION_FORBIDDEN", blocked)

-- /tristan bless debug
function Int.Debug()
    Int.Build()
    local function a(n) return tostring(btn:GetAttribute(n)) end
    ns.Print("Blessing button debug:")
    print(("  shown=%s combat=%s knowsAny=%s kingsForAll=%s enabled=%s"):format(tostring(cell:IsShown()), tostring(InCombatLockdown()),
        tostring(Int.KnowsAny()), tostring(ns.db.char.blessing.kingsForAll), tostring(ns.db.char.blessing.enabled)))
    print(("  type=%s unit=%s useOnKeyDown=%s"):format(a("type"), a("unit"), a("useOnKeyDown")))
    print("  macrotext=" .. a("macrotext"):gsub("\n", " | "))
    if current then
        print("  macro condition [@" .. current.unit .. ",help,nodead]: " .. Int.ConditionCheck(current.unit))
        print(("  next=%s (%s, %s) spell=%s inRange=%s hasMine=%s"):format(tostring(current.name), current.unit, tostring(current.class),
            tostring(current.cast), tostring(Int.InRange(current.unit, current.spell)), tostring(Int.HasBuff(current.unit))))
    else
        print("  next=none (" .. tostring(btn.reason) .. ")")
    end
    print("  key: " .. tostring(Int.Key()))
end

-- Key binding: override binding that clicks the button, per character, out of
-- combat. None by default; Super/Meta combos are refused.
function Int.Key()
    return ns.db and ns.db.char.blessing.key
end

function Int.ApplyKey()
    if not btn then return end
    ns.PaladinBar.ApplyKey(btn, Int.CLICK, Int.Key())
end

function Int.SetKey(key)
    if InCombatLockdown() then ns.Print("Can't change key bindings in combat.") return end
    Int.Build()
    ns.db.char.blessing.key = key
    Int.ApplyKey()
    ns.Print(key and ("Blessing button bound to " .. key .. ".") or "Blessing button key cleared.")
    ns.Fire("KEY_CHANGED")
end

function Int.StartKeyCapture()
    ns.PaladinBar.CaptureKey("Blessing button", Int.SetKey)
end
