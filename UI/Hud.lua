-- On-screen rotation helper + toasts. Advice only: icons and text, no casting.
local _, ns = ...
local UI = ns.UI

local Hud = {}
ns.Hud = Hud

local hud, ticker

local function iconButton(parent, size)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(size, size)
    UI.Backdrop(f, { 0, 0, 0, 0.6 }, UI.C.border)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.cd = UI.Text(f, size > 30 and 14 or 10, nil)
    f.cd:SetPoint("CENTER")
    f.cd:SetJustifyH("CENTER")
    UI.Font(f.cd, size > 30 and 14 or 10, "OUTLINE")
    return f
end

local function build()
    if hud then return hud end
    hud = CreateFrame("Frame", "TristansAddonHud", UIParent, "BackdropTemplate")
    hud:SetSize(236, 112)
    hud:SetFrameStrata("MEDIUM")
    UI.Backdrop(hud, { 0.05, 0.05, 0.07, 0.82 }, UI.C.border)
    hud:SetMovable(true)
    hud:EnableMouse(true)
    hud:RegisterForDrag("LeftButton")
    hud:SetClampedToScreen(true)
    hud:SetScript("OnDragStart", hud.StartMoving)
    hud:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        ns.db.char.rotation.point = { point, rel, x, y }
    end)
    hud.title = UI.Text(hud, 10, UI.C.dim)
    hud.title:SetPoint("TOPLEFT", 8, -6)
    hud.title:SetWordWrap(false)
    hud.main = iconButton(hud, 44)
    hud.main:SetPoint("TOPLEFT", 8, -20)
    hud.q1 = iconButton(hud, 26)
    hud.q1:SetPoint("BOTTOMLEFT", hud.main, "BOTTOMRIGHT", 6, 0)
    hud.q2 = iconButton(hud, 26)
    hud.q2:SetPoint("LEFT", hud.q1, "RIGHT", 4, 0)
    hud.name = UI.Text(hud, 13)
    hud.name:SetPoint("TOPLEFT", hud.main, "TOPRIGHT", 8, -1)
    hud.name:SetWidth(170)
    hud.name:SetWordWrap(false)
    hud.list = UI.Text(hud, 11)
    hud.list:SetPoint("TOPLEFT", 8, -20)
    hud.list:SetWidth(220)
    hud.cds = {}
    for i = 1, 6 do
        local b = iconButton(hud, 22)
        b:SetPoint("BOTTOMLEFT", 8 + (i - 1) * 26, 6)
        hud.cds[i] = b
    end
    hud.pvp = UI.Text(hud, 11)
    hud.pvp:SetPoint("BOTTOMLEFT", 8, 32)
    hud.pvp:SetWidth(220)
    hud.pvp:SetWordWrap(false)
    hud.note = UI.Text(hud, 10, UI.C.warn)
    hud.note:SetPoint("BOTTOMRIGHT", -8, 8)
    hud.note:SetJustifyH("RIGHT")
    hud.note:SetWordWrap(false)
    hud.note:SetWidth(70)
    Hud.Place()
    hud:Hide()
    return hud
end

function Hud.Place()
    if not hud then return end
    hud:ClearAllPoints()
    local p = ns.db.char.rotation.point
    if p then hud:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else hud:SetPoint("CENTER", UIParent, "CENTER", 0, -190) end
end

local function cdText(left)
    if not left or left <= 0 then return "" end
    if left >= 60 then return ("%dm"):format(math.ceil(left / 60)) end
    return ("%d"):format(math.ceil(left))
end

function Hud.Update()
    if not hud or not hud:IsShown() then return end
    local spec = ns.DB.ActiveSpec()
    local context = ns.DB.Profile().rotationContext or "solo"
    local suggestions, blocked, ctx = ns.Rotation.Suggest(spec, context, nil, 3)
    hud.title:SetText(UI.Hex(UI.Accent()) .. spec .. "|r · " .. ns.Rotation.CONTEXT_LABELS[context])
    hud:SetBackdropBorderColor(unpack(UI.Accent()))
    local healing = ctx and ctx.kind == "healing"
    hud.main:SetShown(not healing)
    hud.q1:SetShown(not healing)
    hud.q2:SetShown(not healing)
    hud.name:SetShown(not healing)
    hud.list:SetShown(healing)
    if healing then
        local lines = {}
        for i, step in ipairs(ctx.priority or {}) do
            if i > 4 then break end
            if ns.Rotation.Known(step.spell) then
                local left = step.when == "ready" and ns.Rotation.LiveState.cooldown(step.spell) or nil
                local status = left and left > 0.1 and (UI.Hex(UI.C.dim) .. " (" .. cdText(left) .. ")|r") or ""
                table.insert(lines, ("%d. %s%s"):format(#lines + 1, step.spell, status))
            end
        end
        hud.list:SetText(table.concat(lines, "\n"))
    else
        local function set(btn, step)
            if step then
                btn.tex:SetTexture(ns.Rotation.Icon(step.spell))
                btn:SetAlpha(1)
            else
                btn.tex:SetTexture(nil)
                btn:SetAlpha(0.3)
            end
        end
        set(hud.main, suggestions[1])
        set(hud.q1, suggestions[2])
        set(hud.q2, suggestions[3])
        local s = suggestions[1]
        if s then
            hud.name:SetText(s.spell .. "\n" .. UI.Hex(UI.C.dim) .. (ns.Rotation.WhenText(s.when) or "") .. "|r")
        else
            hud.name:SetText(UI.Hex(UI.C.dim) .. (UnitExists("target") and "Nothing to suggest" or "No target") .. "|r")
        end
    end
    -- Cooldown row.
    local cds = ns.Rotation.Cooldowns(ctx)
    local shown = 0
    for _, name in ipairs(cds) do
        if shown >= #hud.cds then break end
        if ns.Rotation.Known(name) then
            shown = shown + 1
            local b = hud.cds[shown]
            b.tex:SetTexture(ns.Rotation.Icon(name))
            local left = ns.Rotation.LiveState.cooldown(name)
            b.cd:SetText(left == nil and "?" or cdText(left))
            b.tex:SetDesaturated(left ~= nil and left > 0.1)
            b:Show()
        end
    end
    for i = shown + 1, #hud.cds do hud.cds[i]:Hide() end
    hud.note:SetText(blocked and "some info hidden" or "")
    hud.pvp:SetText(Hud.PvPLine() or "")
end

-- PvP line: Forbearance time left and the burst coach's next step (in PvP only).
function Hud.PvPLine()
    if not ns.db.char.pvp.cooldownsOnHud then return nil end
    local parts = {}
    local fb = ns.Paladin.Forbearance()
    if fb and fb.left then table.insert(parts, UI.Hex(UI.C.warn) .. ("Forbearance %ds"):format(math.ceil(fb.left)) .. "|r") end
    if ns.Paladin.InPvP() then
        local coach = ns.Cooldowns.Coach(ns.DB.ActiveSpec())
        local st = coach.next and coach.steps[coach.next]
        if st then table.insert(parts, UI.Hex(ns.BattleAccent) .. "Burst:|r " .. st.spell) end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "  ")
end

function Hud.Refresh()
    build()
    local cfg = ns.db.char.rotation
    local spec = ns.DB.ActiveSpec()
    local show = cfg.enabled and spec ~= nil and (not cfg.showInCombatOnly or UnitAffectingCombat("player"))
    hud:SetShown(show)
    if show and not ticker then
        ticker = C_Timer.NewTicker(0.25, function() pcall(Hud.Update) end)
    elseif not show and ticker then
        ticker:Cancel()
        ticker = nil
    end
    if show then pcall(Hud.Update) end
end

----------------------------------------------------------------------------
-- Toasts
----------------------------------------------------------------------------
local toast, toastTimer
function Hud.Toast(title, text, icon)
    if not toast then
        toast = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        toast:SetSize(340, 64)
        toast:SetPoint("TOP", UIParent, "TOP", 0, -140)
        toast:SetFrameStrata("DIALOG")
        UI.Backdrop(toast, { 0.05, 0.05, 0.07, 0.95 }, UI.C.border)
        toast.icon = toast:CreateTexture(nil, "ARTWORK")
        toast.icon:SetSize(40, 40)
        toast.icon:SetPoint("LEFT", 12, 0)
        toast.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        toast.title = UI.Text(toast, 13)
        toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, 0)
        toast.title:SetWidth(270)
        toast.title:SetWordWrap(false)
        toast.text = UI.Text(toast, 11, UI.C.dim)
        toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -3)
        toast.text:SetWidth(270)
        toast:EnableMouse(true)
        toast:SetScript("OnMouseUp", function() toast:Hide() end)
    end
    toast.icon:SetTexture(icon or ns.NEUTRAL_ICON)
    toast.title:SetText(UI.Hex(UI.Accent()) .. (title or "") .. "|r")
    toast.text:SetText(text or "")
    toast:SetHeight(math.max(64, 22 + toast.title:GetStringHeight() + toast.text:GetStringHeight()))
    toast:SetBackdropBorderColor(unpack(UI.Accent()))
    toast:Show()
    if toastTimer then toastTimer:Cancel() end
    toastTimer = C_Timer.NewTimer(8, function() toast:Hide() end)
end
