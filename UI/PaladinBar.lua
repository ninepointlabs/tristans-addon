-- The Paladin bar: one small draggable strip with the Blessing button (secure,
-- casts) and two hint cells, Aura and Seal (not secure, they never cast: Blizzard's
-- own Aura flyout on your action bar stays the way to switch Auras).
--
-- Each button lives in a "cell" (a plain frame under the bar). Cells holding
-- secure buttons can only be shown, hidden or moved out of combat (Blizzard
-- rule), so Layout() does nothing in combat and runs again when combat ends.
--
-- Also home to the shared key helpers: key bindings are override bindings
-- that click a button directly (SetOverrideBindingClick), per character, out
-- of combat, never on Super/Meta (Omarchy's desktop owns Super).
local _, ns = ...
local UI = ns.UI

local Bar = {}
ns.PaladinBar = Bar
Bar.CELL_W, Bar.CELL_H, Bar.HANDLE_H = 68, 76, 8

-- A bar = { holder, cells }. Bar.New makes one; the Paladin bar is the default
-- instance and its functions are exposed on Bar itself (Bar.Cell, Bar.Layout...).
-- The Battle group's PvP bar (UI/PvPBar.lua) is a second instance.
local function NewBar(frameName, dbKey, title, defaultPoint)
    local self = { cells = {} }

    function self.Holder()
        if self.holder then return self.holder end
        -- Non-secure holder so it can be dragged (out of combat) without interfering with clicks.
        local holder = CreateFrame("Frame", frameName, UIParent)
        self.holder = holder
        holder:SetSize(Bar.CELL_W, Bar.CELL_H + Bar.HANDLE_H + 2)
        holder:SetMovable(true)
        holder:SetClampedToScreen(true)
        holder.handle = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        holder.handle:SetHeight(Bar.HANDLE_H)
        holder.handle:SetPoint("TOPLEFT", 8, 0)
        holder.handle:SetPoint("TOPRIGHT", -8, 0)
        UI.Backdrop(holder.handle, { 0.2, 0.2, 0.25, 0.8 }, { 0, 0, 0, 0 })
        holder.handle:EnableMouse(true)
        holder.handle:RegisterForDrag("LeftButton")
        holder.handle:SetScript("OnDragStart", function() if not InCombatLockdown() then holder:StartMoving() end end)
        holder.handle:SetScript("OnDragStop", function()
            holder:StopMovingOrSizing()
            local point, _, rel, x, y = holder:GetPoint()
            ns.db.char[dbKey].point = { point, rel, x, y }
        end)
        holder.handle:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine("Drag to move (out of combat). Settings > " .. title .. ".", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        holder.handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.Place()
        holder:Hide()
        return holder
    end

    function self.Place()
        local holder = self.holder
        if not holder then return end
        holder:ClearAllPoints()
        local p = ns.db.char[dbKey].point
        if p then holder:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else holder:SetPoint(unpack(defaultPoint)) end
    end

    function self.ResetPosition()
        ns.db.char[dbKey].point = nil
        self.Place()
    end

    -- A cell for one button. order: 1 = left.
    function self.Cell(key, order)
        if self.cells[key] then return self.cells[key] end
        local holder = self.Holder()
        local cell = CreateFrame("Frame", nil, holder)
        cell:SetSize(Bar.CELL_W, Bar.CELL_H)
        cell.order, cell.key, cell.want = order, key, false
        cell:Hide()
        self.cells[key] = cell
        return cell
    end

    -- Show the wanted cells left to right; hide the bar when none are wanted.
    function self.Layout()
        local holder = self.holder
        if not holder or InCombatLockdown() then return false end
        local list = {}
        for _, c in pairs(self.cells) do
            if c.want then table.insert(list, c) else c:Hide() end
        end
        table.sort(list, function(a, b) return a.order < b.order end)
        for i, c in ipairs(list) do
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * Bar.CELL_W, -(Bar.HANDLE_H + 2))
            c:Show()
        end
        holder:SetWidth(math.max(1, #list) * Bar.CELL_W)
        holder:SetShown(#list > 0)
        return true
    end

    function self.Shown()
        local out = {}
        for k, c in pairs(self.cells) do if c.want then out[k] = true end end
        return out
    end
    return self
end
Bar.New = NewBar

local main = NewBar("TristansPaladinBar", "paladinBar", "Paladin bar", { "CENTER", UIParent, "CENTER", -160, -190 })
Bar.main = main
Bar.Holder, Bar.Place, Bar.ResetPosition, Bar.Cell, Bar.Layout, Bar.Shown = main.Holder, main.Place, main.ResetPosition, main.Cell, main.Layout, main.Shown

-- Shared button look: 40px icon button with hotkey text and two lines below.
function Bar.Decorate(btn, cell, icon)
    btn:SetSize(40, 40)
    btn:SetPoint("TOP", cell, "TOP", 0, 0)
    UI.Backdrop(btn, { 0, 0, 0, 0.7 }, UI.C.border)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon:SetTexture(icon)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn.hotkey = UI.Text(btn, 10)
    UI.Font(btn.hotkey, 10, "OUTLINE")
    btn.hotkey:SetPoint("TOPRIGHT", -2, -2)
    btn.hotkey:SetJustifyH("RIGHT")
    btn.hotkey:SetWordWrap(false)
    btn.status = UI.Text(cell, 10)
    btn.status:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    btn.status:SetWidth(Bar.CELL_W - 2)
    btn.status:SetJustifyH("CENTER")
    btn.status:SetWordWrap(false)
    btn.stock = UI.Text(cell, 10)
    btn.stock:SetPoint("TOP", btn.status, "BOTTOM", 0, -2)
    btn.stock:SetWidth(Bar.CELL_W - 2)
    btn.stock:SetJustifyH("CENTER")
    btn.stock:SetWordWrap(false)
end

function Bar.SetLook(btn, active)
    if not btn then return end
    btn.icon:SetDesaturated(not active)
    btn.icon:SetAlpha(active and 1 or 0.45)
    btn:SetBackdropBorderColor(unpack(active and UI.Accent() or UI.C.border))
end

-- "/cast <spell>" for a secure button's macrotext. The Priest sister addon found that on
-- Forever a SecureActionButton with type "spell" didn't cast, while the same
-- button running a /cast line did (and still picks your highest rank).
-- This is the button's own attribute, not a player macro and not /click.
function Bar.CastText(spell, unit)
    if unit then return ("/cast [@%s,help,nodead] %s"):format(unit, spell) end
    return "/cast " .. spell
end

-- ---------------------------------------------------------------------------
-- Keys
-- Turn a key press into a binding string like "ALT-CTRL-SHIFT-F" (nil = ignore).
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true }
function Bar.KeyString(key)
    if not key or MODIFIERS[key] then return nil end
    if IsMetaKeyDown and IsMetaKeyDown() then return nil end
    local prefix = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
    return prefix .. key
end

-- Apply one button's key: owner = the button itself, so each button's binding
-- is cleared and set on its own.
function Bar.ApplyKey(btn, clickName, key)
    if not btn or InCombatLockdown() then return end
    ClearOverrideBindings(btn)
    if key then SetOverrideBindingClick(btn, true, key, clickName, "LeftButton") end
    btn.hotkey:SetText(key and ((GetBindingText and GetBindingText(key, true)) or key) or "")
end

local capture
function Bar.CaptureKey(what, onKey)
    if InCombatLockdown() then ns.Print("Can't change key bindings in combat.") return end
    if not capture then
        capture = CreateFrame("Frame", "TristansKeyCapture", UIParent, "BackdropTemplate")
        capture:SetSize(380, 96)
        capture:SetPoint("CENTER", 0, 120)
        capture:SetFrameStrata("FULLSCREEN_DIALOG")
        UI.Backdrop(capture, UI.C.bg, UI.Accent())
        capture.text = UI.Text(capture, 14)
        capture.text:SetPoint("CENTER")
        capture.text:SetWidth(350)
        capture.text:SetJustifyH("CENTER")
        capture:EnableKeyboard(true)
        capture:SetPropagateKeyboardInput(false)
        capture:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then self:Hide() return end
            local k = Bar.KeyString(key)
            if k then
                self:Hide()
                self.onKey(k)
            end
        end)
        capture:SetScript("OnMouseDown", function(self, mouseButton)
            if mouseButton == "Button4" or mouseButton == "Button5" or mouseButton == "MiddleButton" then
                local k = Bar.KeyString(mouseButton == "MiddleButton" and "BUTTON3" or mouseButton:upper())
                self:Hide()
                if k then self.onKey(k) end
            end
        end)
    end
    capture.onKey = onKey
    capture.text:SetText("Press a key for the " .. what .. "\n" .. UI.Hex(UI.C.dim) .. "(Shift/Ctrl/Alt combos work; Super isn't used; Esc cancels)|r")
    capture:Show()
end
