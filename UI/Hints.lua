-- Aura and Seal hint cells on the Paladin bar. Plain frames, not secure: they
-- never cast. Blizzard's Aura flyout on your action bar stays the way to switch
-- Auras (the dev notes added it for Paladins); these only say which one fits.
--   Aura: the recommended Aura's icon; dimmed with a check when it's running,
--         glowing when you have none or a different one.
--   Seal: the Seal to use; glows when you're in melee range with no Seal. With
--         Unsealed Wrath talented it shows your echo stacks (0-3) from your own
--         aura and "swap" at 3 (advice only). Hidden values read "hidden".
local _, ns = ...
local UI = ns.UI

local Hints = {}
ns.Hints = Hints

local cells = {}

local function build(key, order, title)
    if cells[key] then return cells[key] end
    local cell = ns.PaladinBar.Cell(key, order)
    local b = CreateFrame("Frame", nil, cell, "BackdropTemplate")
    ns.PaladinBar.Decorate(b, cell, ns.NEUTRAL_ICON)
    b:EnableMouse(true)
    b.title = title
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.title, 1, 0.82, 0)
        for _, l in ipairs(s.lines or {}) do GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
        GameTooltip:AddLine("A hint, not a button: cast it from your action bar" .. (key == "aura" and " (Aura flyout)." or "."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cell.b = b
    cells[key] = cell
    return cell
end

-- Pure view model for the aura cell (tests call it).
function Hints.AuraView(st)
    if not st.recAura then return nil end
    local v = { icon = ns.Rotation.Icon(st.recAura), lines = {} }
    if st.aura == nil then
        v.status, v.active = UI.Hex(UI.C.dim) .. "hidden|r", false
    elseif st.aura == st.recAura then
        v.status, v.active, v.ok = UI.Hex(UI.C.good) .. "on|r", false, true
    elseif st.aura == false then
        v.status, v.active = UI.Hex(UI.C.warn) .. "no aura|r", true
    else
        v.status, v.active = UI.Hex(UI.C.warn) .. "switch?|r", true
    end
    v.sub = (st.recAura:gsub(" Aura$", ""))
    table.insert(v.lines, "Suggested: " .. st.recAura .. (st.auraWhy and (" (" .. st.auraWhy .. ")") or ""))
    table.insert(v.lines, "Running: " .. (st.aura == nil and "can't tell right now" or (st.aura or "none")))
    table.insert(v.lines, "Devotion solo, Retribution in groups, Concentration for Holy in PvP; resistance auras when a fight calls for them (pick one in Settings > Paladin bar).")
    return v
end

function Hints.SealView(st, echo, hasUW)
    if not st.recSeal then return nil end
    local v = { icon = ns.Rotation.Icon(st.recSeal), lines = {} }
    local short = st.recSeal:gsub("^Seal of the ", ""):gsub("^Seal of ", "")
    if st.seal == nil then
        v.status, v.active = UI.Hex(UI.C.dim) .. "hidden|r", false
    elseif st.seal then
        v.status, v.ok = UI.Hex(UI.C.good) .. (st.seal:gsub("^Seal of the ", ""):gsub("^Seal of ", "")) .. "|r", true
        v.active = false
    else
        v.status = UI.Hex(st.inMelee and UI.C.warn or UI.C.dim) .. "no seal|r"
        v.active = st.inMelee == true
    end
    v.sub = short
    if hasUW then
        if echo == nil then v.sub = "echo hidden"
        else
            v.sub = "echo " .. echo .. "/3"
            if echo >= 3 then v.sub = UI.Hex(UI.C.good) .. "swap Seal|r" v.active = true end
        end
        table.insert(v.lines, "Unsealed Wrath: your swings store an echo of your Seal (up to 3). Hitting with a different Seal spends them, one proc chance each. At 3, swap Seals.")
    end
    table.insert(v.lines, "Suggested: " .. st.recSeal .. (st.sealWhy and (" (" .. st.sealWhy .. ")") or ""))
    if st.spec == "Retribution" then
        table.insert(v.lines, ("Seal of Command for slow two-handers, Seal of Righteousness for fast weapons or lots of spell power. The %.1f s swing cut-off is an addon assumption."):format(ns.Paladin.SLOW_WEAPON))
    end
    table.insert(v.lines, "Judgement doesn't use up your Seal in Forever. Don't refresh it early.")
    return v
end

local function apply(cell, v)
    local b = cell.b
    if not v then return false end
    b.icon:SetTexture(v.icon)
    b.status:SetText(v.status or "")
    b.stock:SetText(UI.Hex(UI.C.dim) .. (v.sub or "") .. "|r")
    b.lines = v.lines
    b.icon:SetDesaturated(v.ok == true)
    b.icon:SetAlpha(v.ok and 0.6 or 1)
    b:SetBackdropBorderColor(unpack(v.active and UI.C.warn or (v.ok and UI.C.border or UI.Accent())))
    return true
end

function Hints.Update()
    if not ns.db then return end
    local st = ns.Paladin.State()
    local aura = build("aura", 2, "Aura")
    local seal = build("seal", 3, "Seal")
    local av = ns.db.char.auraHint.enabled and Hints.AuraView(st) or nil
    local sv = ns.db.char.sealHint.enabled and Hints.SealView(st, ns.Paladin.EchoStacks(), ns.Paladin.HasUnsealedWrath()) or nil
    apply(aura, av)
    apply(seal, sv)
    return av, sv
end

local ticker
-- Which cells exist (out of combat only: the bar holds a secure button).
function Hints.Refresh()
    if InCombatLockdown() then return end
    local aura = build("aura", 2, "Aura")
    local seal = build("seal", 3, "Seal")
    local st = ns.Paladin.State()
    aura.want = ns.db.char.auraHint.enabled and st.recAura ~= nil
    seal.want = ns.db.char.sealHint.enabled and st.recSeal ~= nil
    ns.PaladinBar.Layout()
    if (aura.want or seal.want) and not ticker then
        ticker = C_Timer.NewTicker(0.5, function() pcall(Hints.Update) end)
    end
    pcall(Hints.Update)
end
