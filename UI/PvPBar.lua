-- Battle group: the Paladin PvP bar. Secure action buttons, each running its
-- own /cast macrotext (type=macro; type=spell failed on Forever), built out of
-- combat only. One press = one cast. No /click, no player macros, no
-- Bindings.xml; keys are optional, unbound by default, never Super/Meta.
--
--   Freedom     /cast [@mouseover,help,nodead][@focus,help,nodead][@<ally>,help,nodead][@player] Blessing of Freedom
--   Cleanse     /cast [@mouseover,help,nodead][@focus,help,nodead][@player] Cleanse (Purify until Cleanse)
--   Protection  /cast [@mouseover,help,nodead][@<ally>,help,nodead][@focus,help,nodead] Blessing of Protection
--   Stun        /cast [mod:shift,@focus,harm,nodead] Hammer of Justice; [@target,harm,nodead] Hammer of Justice
--   Repentance  same as Stun, for Repentance (talent)
--
-- <ally> is the party/raid member you picked on Battle > PvP bar, re-resolved
-- to a unit token out of combat. In combat the bar keeps what it had. (No
-- right-click menu on the buttons: a right-click would also cast.)
local _, ns = ...
local UI = ns.UI

local PB = {}
ns.PvPBar = PB

local bar = ns.PaladinBar.New("TristansPvPBar", "pvpBar", "PvP bar", { "CENTER", UIParent, "CENTER", 120, -190 })
PB.bar = bar

PB.BUTTONS = {
    { key = "freedom", order = 1, label = "Freedom", spells = { "Blessing of Freedom" }, kind = "help_ally_self",
      tip = "Blessing of Freedom on your mouseover, focus, picked ally, else you. Roots and slows. It replaces your other Blessing on that target." },
    { key = "cleanse", order = 2, label = "Cleanse", spells = { "Cleanse", "Purify" }, kind = "help_self",
      tip = "Cleanse (or Purify) on your mouseover, focus, else you. Use it on magic crowd control on your flag carrier." },
    { key = "protection", order = 3, label = "Protect", spells = { "Blessing of Protection" }, kind = "help_ally",
      tip = "Blessing of Protection on your mouseover, picked ally, or focus. Not on the tank (they lose threat), and not on yourself if you need to keep attacking. Causes Forbearance." },
    { key = "stun", order = 4, label = "Stun", spells = { "Hammer of Justice" }, kind = "harm",
      tip = "Hammer of Justice on your target; hold Shift for your focus." },
    { key = "repentance", order = 5, label = "Repent", spells = { "Repentance" }, kind = "harm",
      tip = "Repentance on your target; hold Shift for your focus. Your second burst window (or a peel)." },
}

local buttons = {}

-- The spell this button casts at your level (first known), or nil.
function PB.Spell(def, known)
    known = known or function(n) return ns.Progress.Knows(n) end
    for _, s in ipairs(def.spells) do if known(s) then return s end end
    return nil
end

-- Unit token for the picked ally (by name), out of combat.
function PB.AllyUnit()
    local want = ns.db.char.pvpBar.ally
    if not want then return nil end
    local list = {}
    if IsInRaid() then for i = 1, 40 do table.insert(list, "raid" .. i) end
    elseif IsInGroup() then for i = 1, 4 do table.insert(list, "party" .. i) end end
    for _, u in ipairs(list) do
        if UnitExists(u) and UnitName(u) == want then return u end
    end
    return nil
end

-- Pure: the macrotext for a button definition.
function PB.MacroText(def, spell, ally)
    local allyPart = ally and ("[@" .. ally .. ",help,nodead]") or ""
    if def.kind == "help_ally_self" then
        return ("/cast [@mouseover,help,nodead][@focus,help,nodead]%s[@player] %s"):format(allyPart, spell)
    elseif def.kind == "help_self" then
        return ("/cast [@mouseover,help,nodead][@focus,help,nodead][@player] %s"):format(spell)
    elseif def.kind == "help_ally" then
        return ("/cast [@mouseover,help,nodead]%s[@focus,help,nodead] %s"):format(allyPart, spell)
    elseif def.kind == "harm" then
        return ("/cast [mod:shift,@focus,harm,nodead] %s; [@target,harm,nodead] %s"):format(spell, spell)
    end
end

-- Should the bar be up? "always" | "pvp" (battleground or PvP-flagged or a PvP realm) | "never".
function PB.Wanted()
    local mode = ns.db.char.pvpBar.show
    if mode == "never" then return false end
    if mode == "always" then return true end
    if ns.PvP.Ruleset() == "PvP" then return true end
    return ns.Paladin.InPvP()
end

local function build(def)
    if buttons[def.key] then return buttons[def.key] end
    local cell = bar.Cell(def.key, def.order)
    local b = CreateFrame("Button", "TristansPvP_" .. def.key, cell, "SecureActionButtonTemplate, BackdropTemplate")
    ns.PaladinBar.Decorate(b, cell, "Interface\\Icons\\INV_Misc_QuestionMark")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("useOnKeyDown", false)
    b.def = def
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.spell or def.label, 1, 0.82, 0)
        GameTooltip:AddLine(def.tip, 0.85, 0.85, 0.85, true)
        if def.kind == "help_ally" or def.kind == "help_ally_self" then
            GameTooltip:AddLine("Picked ally: " .. (ns.db.char.pvpBar.ally or "none") .. ". Pick one in Battle > PvP bar.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine("One press = one cast. Key: " .. (ns.db.char.pvpBar.keys[def.key] or "none (Battle > PvP bar)"), 0.6, 0.6, 0.6, true)
        if InCombatLockdown() then GameTooltip:AddLine("In combat the bar can't change until combat ends.", 1, 0.5, 0.3, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[def.key] = b
    return b
end

-- Re-aim every button (out of combat only).
function PB.Update()
    if InCombatLockdown() then return end
    local ally = PB.AllyUnit()
    for _, def in ipairs(PB.BUTTONS) do
        local b = build(def)
        local spell = PB.Spell(def)
        b.spell = spell
        if spell then
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", PB.MacroText(def, spell, ally))
            b.icon:SetTexture(ns.Rotation.Icon(spell))
            b.status:SetText(def.label)
            local left = ns.Auras.CooldownLeft(ns.Rotation.SpellId(spell) or spell)
            b.stock:SetText(left == nil and (UI.Hex(UI.C.dim) .. "hidden|r") or (left > 0.1 and (UI.Hex(UI.C.warn) .. math.ceil(left) .. "s|r") or (UI.Hex(UI.C.good) .. "ready|r")))
        else
            b:SetAttribute("type", nil)
            b:SetAttribute("macrotext", nil)
        end
        b.cell = b.cell or b:GetParent()
    end
end

function PB.Refresh()
    if InCombatLockdown() then return end
    PB.Update()
    local show = PB.Wanted()
    for _, def in ipairs(PB.BUTTONS) do
        local cell = bar.Cell(def.key, def.order)
        cell.want = show and PB.Spell(def) ~= nil
    end
    bar.Layout()
    PB.ApplyKeys()
end

function PB.Shown() return bar.Shown() end
function PB.Button(key) return buttons[key] end

-- Ally picker: a small menu of your group (name + class), out of combat.
local menu
function PB.AllyChoices()
    local out = {}
    local list = {}
    if IsInRaid() then for i = 1, 40 do table.insert(list, "raid" .. i) end
    elseif IsInGroup() then for i = 1, 4 do table.insert(list, "party" .. i) end end
    for _, u in ipairs(list) do
        if UnitExists(u) and not UnitIsUnit(u, "player") then table.insert(out, { unit = u, name = UnitName(u) }) end
    end
    return out
end

function PB.SetAlly(name)
    if InCombatLockdown() then ns.Print("Out of combat only.") return end
    ns.db.char.pvpBar.ally = name
    PB.Update()
    ns.Print(name and ("PvP bar ally: " .. name .. ".") or "PvP bar ally cleared.")
end

function PB.ShowAllyMenu(anchor)
    if InCombatLockdown() then return end
    if not menu then
        menu = CreateFrame("Frame", "TristansAllyMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("DIALOG")
        UI.Backdrop(menu, UI.C.bg, UI.C.border)
        menu.rows = {}
    end
    local choices = PB.AllyChoices()
    table.insert(choices, { name = nil, label = "Clear" })
    for i, ch in ipairs(choices) do
        local r = menu.rows[i] or UI.Button(menu, "", 160, 22)
        menu.rows[i] = r
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 24)
        r.label:SetText(ch.label or ch.name)
        r:SetScript("OnClick", function() PB.SetAlly(ch.name) menu:Hide() end)
        r:Show()
    end
    for i = #choices + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(172, 12 + #choices * 24)
    menu:ClearAllPoints()
    menu:SetPoint("BOTTOM", anchor or UIParent, "TOP", 0, 6)
    menu:Show()
end

-- Keys: one override binding per button, out of combat; none by default.
function PB.ApplyKeys()
    if InCombatLockdown() then return end
    for _, def in ipairs(PB.BUTTONS) do
        local b = buttons[def.key]
        if b then ns.PaladinBar.ApplyKey(b, b:GetName() or ("TristansPvP_" .. def.key), ns.db.char.pvpBar.keys[def.key]) end
    end
end

function PB.SetKey(key, value)
    if InCombatLockdown() then ns.Print("Can't change key bindings in combat.") return end
    ns.db.char.pvpBar.keys[key] = value
    PB.Refresh()
    ns.Print(value and ("PvP bar " .. key .. " bound to " .. value .. ".") or ("PvP bar " .. key .. " key cleared."))
    ns.Fire("KEY_CHANGED")
end

function PB.StartKeyCapture(key)
    ns.PaladinBar.CaptureKey("PvP bar: " .. key, function(v) PB.SetKey(key, v) end)
end
