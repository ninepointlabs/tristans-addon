-- Theme + widget kit + a pooled layout (with columns) used by every screen.
--
-- Design rules (v0.2 redesign, Tim approved the mockup 2026-11-09):
--   * one main job per screen: Title, then one Tabs bar, then cards/rows
--   * sources and minor research notes are collected (L:Source / L:Note) and
--     shown behind one "Sources & notes" link per screen, not inline
--   * bigger, higher-contrast text; dim colour only for secondary info
local _, ns = ...

local UI = {}
ns.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8x8"
UI.WHITE = WHITE

UI.C = {
    bg = { 0.051, 0.051, 0.078, 0.98 },
    head = { 0.063, 0.063, 0.094, 1 },
    side = { 0.059, 0.059, 0.090, 1 },
    card = { 0.086, 0.086, 0.122, 1 },
    cardHover = { 0.122, 0.122, 0.169, 1 },
    border = { 0.165, 0.165, 0.220, 1 },
    softBorder = { 0.137, 0.137, 0.184, 1 },
    text = { 0.925, 0.925, 0.953 },
    dim = { 0.640, 0.640, 0.722 },
    label = { 0.608, 0.608, 0.690 },
    good = { 0.431, 0.906, 0.627 },
    goodBg = { 0.071, 0.196, 0.110, 1 },
    bad = { 1.00, 0.40, 0.40 },
    badge = { 0.898, 0.282, 0.302, 1 },
    warn = { 1.00, 0.757, 0.302 },
    warnBg = { 0.227, 0.165, 0.063, 1 },
    info = { 0.620, 0.773, 1.00 },
    infoBg = { 0.114, 0.145, 0.251, 1 },
    neutralBg = { 0.137, 0.137, 0.184, 1 },
    epic = { 0.706, 0.549, 1.00 },
}

UI.FLAG_ICON = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:14:14:0:0|t"
UI.CHECK_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"
UI.CROSS_ICON = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t"
UI.WAIT_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14:14:0:0|t"

function UI.Hex(c)
    return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

function UI.Accent()
    return ns.SpecAccent()
end

function UI.Backdrop(frame, bg, border)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(unpack(bg or UI.C.card))
    frame:SetBackdropBorderColor(unpack(border or UI.C.border))
end

local FONT = "Fonts\\FRIZQT__.TTF"
function UI.Font(fs, size, flags)
    fs:SetFont(FONT, size or 13, flags or "")
    return fs
end

function UI.Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    UI.Font(fs, size or 13)
    fs:SetTextColor(unpack(color or UI.C.text))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

-- Flat button with hover + optional accent.
function UI.Button(parent, label, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 100, height or 28)
    UI.Backdrop(b, { 0.125, 0.125, 0.169, 1 }, { 0.227, 0.227, 0.298, 1 })
    b.label = UI.Text(b, 12)
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetWordWrap(false)
    b.label:SetText(label or "")
    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(UI.C.cardHover))
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self.active and UI.C.cardHover or { 0.125, 0.125, 0.169, 1 }))
        GameTooltip:Hide()
    end)
    if onClick then b:SetScript("OnClick", onClick) end
    function b:SetActive(on)
        self.active = on
        self:SetBackdropColor(unpack(on and UI.C.cardHover or { 0.125, 0.125, 0.169, 1 }))
        self:SetBackdropBorderColor(unpack(on and UI.Accent() or { 0.227, 0.227, 0.298, 1 }))
        self.label:SetTextColor(unpack(on and { 1, 1, 1 } or UI.C.text))
    end
    return b
end

-- Small rounded-looking pill (text with a coloured background).
local CHIP = {
    good = { UI.C.goodBg, UI.C.good }, warn = { UI.C.warnBg, UI.C.warn },
    info = { UI.C.infoBg, UI.C.info }, neutral = { UI.C.neutralBg, UI.C.dim },
    bad = { { 0.24, 0.07, 0.08, 1 }, UI.C.bad },
}
UI.CHIP = CHIP

-- Copyable URL popup (addons cannot open a browser).
StaticPopupDialogs["TRISTANS_ADDON_COPY_URL"] = {
    text = "Tristan's Addon: press Ctrl+C to copy this link.",
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 380,
    OnShow = function(self, data)
        local eb = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
        if eb then
            eb:SetText(data or "")
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function UI.CopyURL(url)
    if url and url ~= "" then StaticPopup_Show("TRISTANS_ADDON_COPY_URL", nil, nil, url) end
end

----------------------------------------------------------------------------
-- Layout: pooled flow inside a scroll child, with optional columns.
----------------------------------------------------------------------------
local Layout = {}
Layout.__index = Layout
UI.Layout = Layout

function UI.NewLayout(content, width)
    return setmetatable({ content = content, width = width, fullWidth = width, x = 0, y = 0, pools = {}, used = {}, notes = {} }, Layout)
end

function Layout:Acquire(kind, make)
    self.pools[kind] = self.pools[kind] or {}
    self.used[kind] = (self.used[kind] or 0) + 1
    local obj = self.pools[kind][self.used[kind]]
    if not obj then
        obj = make()
        self.pools[kind][self.used[kind]] = obj
    end
    obj:ClearAllPoints()
    obj:Show()
    return obj
end

function Layout:Reset(width)
    for _, pool in pairs(self.pools) do
        for _, obj in ipairs(pool) do obj:Hide() end
    end
    self.used = {}
    self.y, self.x = 0, 0
    self.notes, self.noteSeen = {}, {}
    if width then self.width, self.fullWidth = width, width end
    self.cols = nil
end

function Layout:Finish()
    self.content:SetHeight(math.max(1, self.y + 16))
    if self.notesBtn then self.notesBtn:SetShown(#self.notes > 0) end
end

function Layout:Space(h)
    self.y = self.y + (h or 8)
end

local GAP = 6

-- Columns: L:Columns({0.6, 0.4}) ... L:NextColumn() ... L:EndColumns()
function Layout:Columns(fractions, gap)
    gap = gap or 16
    local total = self.width - gap * (#fractions - 1)
    self.cols = { startY = self.y, x0 = self.x, width0 = self.width, gap = gap, widths = {}, index = 1, maxY = self.y }
    for i, f in ipairs(fractions) do self.cols.widths[i] = math.floor(total * f) end
    self.width = self.cols.widths[1]
end

function Layout:NextColumn()
    local c = self.cols
    c.maxY = math.max(c.maxY, self.y)
    self.x = self.x + self.width + c.gap
    c.index = c.index + 1
    self.width = c.widths[c.index]
    self.y = c.startY
end

function Layout:EndColumns()
    local c = self.cols
    c.maxY = math.max(c.maxY, self.y)
    self.x, self.width, self.y = c.x0, c.width0, c.maxY
    self.cols = nil
end

-- Plain paragraph. opts: size, color, indent, gap
function Layout:Text(text, opts)
    opts = opts or {}
    local fs = self:Acquire("text", function() return UI.Text(self.content, 13) end)
    UI.Font(fs, opts.size or 13)
    fs:SetTextColor(unpack(opts.color or UI.C.text))
    local indent = opts.indent or 0
    fs:SetWidth(self.width - indent)
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x + indent, -self.y)
    fs:SetText(text or "")
    self.y = self.y + fs:GetStringHeight() + (opts.gap or GAP)
    return fs
end

-- Section label: small uppercase dim text.
function Layout:Label(text, color)
    self:Space(4)
    return self:Text((text or ""):upper(), { size = 11, color = color or UI.C.label, gap = 8 })
end

-- Kept for older panels: a section heading (label style) with optional sub line.
function Layout:Header(text, sub)
    self:Space(6)
    self:Label(text)
    if sub then self:Text(sub, { color = UI.C.dim, size = 12 }) end
end

-- Page title + the "Sources & notes" link (shown by Finish when notes exist).
function Layout:Title(text, sub)
    local fs = self:Text(text, { size = 20, gap = 4 })
    if not self.notesBtn then
        local b = CreateFrame("Button", nil, self.content)
        b:SetSize(140, 18)
        b.text = UI.Text(b, 11, UI.C.dim)
        b.text:SetPoint("RIGHT")
        b.text:SetJustifyH("RIGHT")
        b.text:SetText("|TInterface\\FriendsFrame\\InformationIcon:12:12:0:0|t Sources & notes")
        b:SetScript("OnEnter", function(s) s.text:SetTextColor(1, 1, 1) end)
        b:SetScript("OnLeave", function(s) s.text:SetTextColor(unpack(UI.C.dim)) end)
        b:SetScript("OnClick", function() UI.ShowNotes(self.titleText, self.notes) end)
        self.notesBtn = b
    end
    self.titleText = text
    self.notesBtn:ClearAllPoints()
    self.notesBtn:SetPoint("TOPRIGHT", self.content, "TOPLEFT", self.x + self.width, -2)
    if sub then self:Text(sub, { color = UI.C.dim, size = 13 }) end
    self:Space(4)
    return fs
end

-- Collected (not drawn): research citations and minor notes for this screen.
function Layout:Note(text)
    if text and not self.noteSeen[text] then
        self.noteSeen[text] = true
        table.insert(self.notes, { text = text })
    end
end

function Layout:Source(rec)
    if not rec or not rec.source_url then return end
    local key = rec.source_url
    if self.noteSeen[key] then return end
    self.noteSeen[key] = true
    table.insert(self.notes, { url = rec.source_url, checked = rec.checked })
end

-- Inline warning (only for things the player must know right here).
function Layout:Flag(text)
    return self:Text(UI.Hex(UI.C.warn) .. "!|r  " .. UI.Hex(UI.C.warn) .. text .. "|r", { size = 12 })
end

-- Sub-tab bar. items: { {label, active, onClick, badge} }
function Layout:Tabs(items)
    local x, h = 0, 28
    for _, it in ipairs(items) do
        local b = self:Acquire("tab", function()
            local t = CreateFrame("Button", nil, self.content, "BackdropTemplate")
            UI.Backdrop(t, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
            t.label = UI.Text(t, 12)
            t.label:SetPoint("CENTER")
            t.label:SetWordWrap(false)
            t:SetScript("OnEnter", function(s) if not s.active then s:SetBackdropColor(0.11, 0.11, 0.15, 1) s.label:SetTextColor(1, 1, 1) end end)
            t:SetScript("OnLeave", function(s) if not s.active then s:SetBackdropColor(0, 0, 0, 0) s.label:SetTextColor(unpack(UI.C.dim)) end end)
            return t
        end)
        b.active = it.active
        b.label:SetText(it.label .. (it.badge and it.badge > 0 and ("  " .. UI.Hex(UI.C.bad) .. it.badge .. "|r") or ""))
        local w = b.label:GetStringWidth() + 28
        b:SetSize(w, h)
        b:SetBackdropColor(unpack(it.active and { 0.122, 0.122, 0.169, 1 } or { 0, 0, 0, 0 }))
        b.label:SetTextColor(unpack(it.active and { 1, 1, 1 } or UI.C.dim))
        b:SetScript("OnClick", it.onClick)
        if x + w > self.width then
            x = 0
            self.y = self.y + h + 4
        end
        b:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x + x, -self.y)
        x = x + w + 4
    end
    self.y = self.y + h + 6
    local line = self:Acquire("rule", function()
        local t = self.content:CreateTexture(nil, "ARTWORK")
        t:SetTexture(WHITE)
        return t
    end)
    line:SetColorTexture(unpack(UI.C.softBorder))
    line:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x, -self.y)
    line:SetSize(self.width, 1)
    self.y = self.y + 14
end

-- Row: chip, icon, title, subtitle, right text, optional button.
-- opts: icon, title, sub, right, chip={text,kind}, button={label,onClick}, onClick, onEnter, tint, x, width, y(no advance)
function Layout:Row(opts)
    local row = self:Acquire("row", function()
        local f = CreateFrame("Button", nil, self.content, "BackdropTemplate")
        UI.Backdrop(f, UI.C.card, UI.C.softBorder)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(30, 30)
        f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        f.chip = CreateFrame("Frame", nil, f, "BackdropTemplate")
        UI.Backdrop(f.chip, UI.C.neutralBg, { 0, 0, 0, 0 })
        f.chip:SetHeight(18)
        f.chip.text = UI.Text(f.chip, 11)
        f.chip.text:SetPoint("CENTER")
        f.chip.text:SetWordWrap(false)
        f.title = UI.Text(f, 13)
        f.sub = UI.Text(f, 12, UI.C.dim)
        f.right = UI.Text(f, 12)
        f.right:SetJustifyH("RIGHT")
        f.right:SetWordWrap(false)
        f.btn = UI.Button(f, "", 80, 24)
        f:SetScript("OnEnter", function(s)
            if s.onClick then s:SetBackdropColor(unpack(UI.C.cardHover)) end
            if s.onEnter then s.onEnter(s) end
        end)
        f:SetScript("OnLeave", function(s)
            s:SetBackdropColor(unpack(UI.C.card))
            GameTooltip:Hide()
        end)
        f:SetScript("OnClick", function(s) if s.onClick then s.onClick(s) end end)
        return f
    end)
    local width = opts.width or self.width
    local x = opts.x or self.x
    local y = opts.y or self.y
    row.onClick, row.onEnter = opts.onClick, opts.onEnter
    row:SetBackdropBorderColor(unpack(opts.tint or UI.C.softBorder))
    local left = 12
    if opts.chip then
        local kind = CHIP[opts.chip.kind or "neutral"] or CHIP.neutral
        row.chip:SetBackdropColor(unpack(kind[1]))
        row.chip.text:SetTextColor(unpack(kind[2]))
        row.chip.text:SetText(opts.chip.text)
        row.chip:SetWidth(row.chip.text:GetStringWidth() + 16)
        row.chip:ClearAllPoints()
        row.chip:SetPoint("LEFT", row, "LEFT", left, 0)
        row.chip:Show()
        left = left + row.chip:GetWidth() + 10
    else
        row.chip:Hide()
    end
    if opts.icon then
        row.icon:SetTexture(opts.icon)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", left, -7)
        row.icon:Show()
        left = left + 40
    else
        row.icon:Hide()
    end
    local rightW = 0
    if opts.button then
        row.btn.label:SetText(opts.button.label)
        row.btn:SetWidth(row.btn.label:GetStringWidth() + 24)
        row.btn:SetScript("OnClick", opts.button.onClick)
        row.btn:ClearAllPoints()
        row.btn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.btn:Show()
        rightW = row.btn:GetWidth() + 14
    else
        row.btn:Hide()
    end
    row.right:SetText(opts.right or "")
    row.right:ClearAllPoints()
    row.right:SetPoint("TOPRIGHT", -(10 + rightW), -10)
    if opts.right and opts.right ~= "" then rightW = rightW + math.min(row.right:GetStringWidth() + 14, 220) end
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", left, -9)
    row.title:SetWidth(width - left - 10 - rightW)
    row.title:SetText(opts.title or "")
    row.sub:ClearAllPoints()
    row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
    row.sub:SetWidth(width - left - 10 - rightW)
    row.sub:SetText(opts.sub or "")
    local h = 9 + row.title:GetStringHeight() + (opts.sub and opts.sub ~= "" and (3 + row.sub:GetStringHeight()) or 0) + 9
    h = math.max(h, opts.icon and 44 or 34, opts.button and 38 or 0)
    row:SetSize(width, h)
    row:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
    if not opts.y then self.y = self.y + h + GAP end
    return row, h
end

-- Card: label (accent), big title, body, optional progress bar and button.
-- opts: label, title, body, progress={value,max}, button={label,onClick}, tint, x, y, width, height
function Layout:Card(opts)
    local c = self:Acquire("card", function()
        local f = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
        UI.Backdrop(f, UI.C.card, UI.C.border)
        f.label = UI.Text(f, 11)
        f.title = UI.Text(f, 16)
        f.body = UI.Text(f, 12, UI.C.dim)
        f.bar = CreateFrame("Frame", nil, f, "BackdropTemplate")
        UI.Backdrop(f.bar, UI.C.neutralBg, { 0, 0, 0, 0 })
        f.bar:SetHeight(8)
        f.bar.fill = f.bar:CreateTexture(nil, "ARTWORK")
        f.bar.fill:SetPoint("TOPLEFT")
        f.bar.fill:SetPoint("BOTTOMLEFT")
        f.btn = UI.Button(f, "", 120, 28)
        return f
    end)
    local width = opts.width or self.width
    local inner = width - 32
    local a = UI.Accent()
    c:SetBackdropBorderColor(unpack(opts.tint or UI.C.border))
    c.label:SetTextColor(a[1], a[2], a[3])
    c.label:SetText((opts.label or ""):upper())
    c.label:SetWidth(inner)
    c.label:ClearAllPoints()
    c.label:SetPoint("TOPLEFT", 16, -14)
    c.title:SetText(opts.title or "")
    c.title:SetWidth(inner)
    c.title:ClearAllPoints()
    c.title:SetPoint("TOPLEFT", c.label, "BOTTOMLEFT", 0, -8)
    local h = 14 + c.label:GetStringHeight() + 8 + c.title:GetStringHeight()
    local anchor = c.title
    if opts.progress then
        c.bar:ClearAllPoints()
        c.bar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
        c.bar:SetWidth(inner)
        local pct = math.min(1, math.max(0, (opts.progress.value or 0) / math.max(1, opts.progress.max or 1)))
        c.bar.fill:SetColorTexture(a[1], a[2], a[3], 1)
        c.bar.fill:SetWidth(math.max(1, inner * pct))
        c.bar:Show()
        anchor = c.bar
        h = h + 18
    else
        c.bar:Hide()
    end
    c.body:SetText(opts.body or "")
    c.body:SetWidth(inner)
    c.body:ClearAllPoints()
    c.body:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    if opts.body and opts.body ~= "" then h = h + 8 + c.body:GetStringHeight() end
    if opts.button then
        c.btn.label:SetText(opts.button.label)
        c.btn:SetWidth(inner)
        c.btn:SetScript("OnClick", opts.button.onClick)
        c.btn:ClearAllPoints()
        c.btn:SetPoint("BOTTOMLEFT", 16, 14)
        c.btn:Show()
        h = h + 14 + 28
    else
        c.btn:Hide()
    end
    h = h + 16
    local height = math.max(h, opts.height or 0)
    c:SetSize(width, height)
    c:SetPoint("TOPLEFT", self.content, "TOPLEFT", opts.x or self.x, -(opts.y or self.y))
    if not opts.y then self.y = self.y + height + 12 end
    return c, h
end

-- A row of equal-height cards across the current width.
function Layout:CardRow(list, gap)
    gap = gap or 14
    local n = #list
    if n == 0 then return end
    local w = math.floor((self.width - gap * (n - 1)) / n)
    local maxH = 0
    for i, opts in ipairs(list) do
        opts.x, opts.y, opts.width = self.x + (i - 1) * (w + gap), self.y, w
        local _, h = self:Card(opts)
        maxH = math.max(maxH, h)
    end
    -- second pass: equalise heights (cards were acquired in order)
    local pool = self.pools.card
    for i = 1, n do
        local c = pool[(self.used.card or n) - n + i]
        if c then c:SetHeight(maxH) end
    end
    self.y = self.y + maxH + 14
end

-- Grid of rows (e.g. gear slots), `cols` across.
function Layout:RowGrid(list, cols, gap)
    gap = gap or 8
    local w = math.floor((self.width - gap * (cols - 1)) / cols)
    local i = 0
    while i < #list do
        local maxH = 0
        for c = 1, cols do
            local opts = list[i + c]
            if opts then
                opts.x, opts.y, opts.width = self.x + (c - 1) * (w + gap), self.y, w
                local _, h = self:Row(opts)
                maxH = math.max(maxH, h)
            end
        end
        self.y = self.y + maxH + gap
        i = i + cols
    end
end

-- Progress bar with label.
function Layout:Progress(label, value, max, rightText)
    local bar = self:Acquire("bar", function()
        local f = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
        UI.Backdrop(f, UI.C.card, UI.C.softBorder)
        f:SetHeight(24)
        f.fill = f:CreateTexture(nil, "ARTWORK")
        f.fill:SetTexture(WHITE)
        f.fill:SetPoint("TOPLEFT", 1, -1)
        f.fill:SetPoint("BOTTOMLEFT", 1, 1)
        f.label = UI.Text(f, 12)
        f.label:SetPoint("LEFT", 10, 0)
        f.label:SetWordWrap(false)
        f.right = UI.Text(f, 12)
        f.right:SetPoint("RIGHT", -10, 0)
        f.right:SetJustifyH("RIGHT")
        return f
    end)
    bar:SetWidth(self.width)
    bar:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x, -self.y)
    local pct = (max and max > 0) and math.min(1, math.max(0, value / max)) or 0
    local a = UI.Accent()
    bar.fill:SetColorTexture(a[1], a[2], a[3], 0.45)
    bar.fill:SetWidth(math.max(1, (self.width - 2) * pct))
    bar.label:SetText(label or "")
    bar.right:SetText(rightText or ("%d%%"):format(pct * 100))
    self.y = self.y + 24 + GAP
    return bar
end

-- A row of buttons. items: { {label, active, onClick, tip} }
function Layout:Buttons(items, width)
    local x, h = 0, 28
    for _, it in ipairs(items) do
        local b = self:Acquire("btn", function() return UI.Button(self.content, "", 100, 28) end)
        b.label:SetText(it.label)
        local w = width or (b.label:GetStringWidth() + 28)
        b:SetSize(w, h)
        b.tip = it.tip
        b:SetScript("OnClick", it.onClick)
        b:SetActive(it.active)
        if x + w > self.width then
            x = 0
            self.y = self.y + h + GAP
        end
        b:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x + x, -self.y)
        x = x + w + 8
    end
    self.y = self.y + h + GAP + 2
end

-- Checkbox line for settings.
function Layout:Check(label, checked, onToggle, tip)
    local cb = self:Acquire("check", function()
        local c = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
        c:SetSize(24, 24)
        c.text = UI.Text(c, 13)
        c.text:SetPoint("LEFT", c, "RIGHT", 6, 0)
        c.text:SetWordWrap(false)
        c:SetScript("OnEnter", function(s)
            if s.tip then
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(s.tip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return c
    end)
    cb:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x, -self.y)
    cb.text:SetText(label)
    cb:SetChecked(checked and true or false)
    cb.tip = tip
    cb:SetScript("OnClick", function(s) onToggle(s:GetChecked() and true or false) end)
    self.y = self.y + 28
    return cb
end

-- Item row helper (icon from item id, tooltip shows our upgrade tip).
-- extra: optional table merged into the row opts (chip, x/y/width for grids).
function Layout:Item(id, name, sub, right, onClick, extra)
    local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    local opts = {
        icon = icon, title = name, sub = sub, right = right,
        onEnter = function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(id)
            GameTooltip:Show()
        end,
        onClick = function()
            if IsModifiedClick and IsModifiedClick("CHATLINK") then
                local _, link = C_Item.GetItemInfo(id)
                if link then ChatEdit_InsertLink(link) end
            elseif onClick then
                onClick()
            end
        end,
    }
    for k, v in pairs(extra or {}) do opts[k] = v end
    if extra and extra.y then return self:Row(opts) end
    return self:Row(opts)
end

function Layout:Spell(id, title, sub, right, iconOverride, extra)
    local icon = iconOverride
    if not icon and id and C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, id)
        if ok then icon = tex end
    end
    local opts = {
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark", title = title, sub = sub, right = right,
        onEnter = id and function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetSpellByID, GameTooltip, id)
            GameTooltip:Show()
        end or nil,
    }
    for k, v in pairs(extra or {}) do opts[k] = v end
    return self:Row(opts)
end

function Layout:Link(title, url, sub)
    return self:Row({
        title = title, sub = sub or url,
        button = { label = "Copy link", onClick = function() UI.CopyURL(url) end },
    })
end

----------------------------------------------------------------------------
-- "Sources & notes" popup (one per window).
----------------------------------------------------------------------------
local notesFrame
function UI.ShowNotes(title, notes)
    if not notesFrame then
        local f = CreateFrame("Frame", "TristansAddonNotes", UIParent, "BackdropTemplate")
        f:SetSize(560, 420)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        UI.Backdrop(f, UI.C.bg, UI.C.border)
        f.title = UI.Text(f, 16)
        f.title:SetPoint("TOPLEFT", 18, -16)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT", 18, -46)
        f.scroll:SetPoint("BOTTOMRIGHT", -32, 16)
        f.content = CreateFrame("Frame", nil, f.scroll)
        f.content:SetSize(500, 1)
        f.scroll:SetScrollChild(f.content)
        f.layout = UI.NewLayout(f.content, 500)
        table.insert(UISpecialFrames, "TristansAddonNotes")
        notesFrame = f
    end
    local f = notesFrame
    f.title:SetText((title or "") .. ": sources & notes")
    local L = f.layout
    L:Reset(500)
    local hadNote = false
    for _, n in ipairs(notes or {}) do
        if n.text then
            hadNote = true
            L:Text(UI.Hex(UI.C.warn) .. "!|r  " .. n.text, { size = 12 })
        end
    end
    if hadNote then L:Space(8) end
    for _, n in ipairs(notes or {}) do
        if n.url then
            local host = n.url:match("^https?://([^/]+)") or n.url
            L:Row({ title = host, sub = n.url .. (n.checked and ("\nchecked " .. n.checked) or ""),
                button = { label = "Copy", onClick = function() UI.CopyURL(n.url) end } })
        end
    end
    L:Finish()
    f:Show()
end
