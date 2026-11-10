-- Main window (v0.2 layout): header (spec pill + profile A/B), grouped sidebar
-- with search, scrolling content, first-run spec picker overlay.
local _, ns = ...
local UI = ns.UI

ns.Panels = {}
ns.PanelOrder = {}

-- Panels register themselves: { key, label, render(layout, ctx), badge(), setSub(sub) }
function UI.RegisterPanel(p)
    ns.Panels[p.key] = p
    table.insert(ns.PanelOrder, p.key)
end

-- Sidebar groups (Tim approved the mockup, 2026-11-09).
UI.NAV = {
    { title = nil, keys = { "home" } },
    { title = "Play", keys = { "rotation", "gear" } },
    { title = "Battle", keys = { "battle" } },
    { title = "Progress", keys = { "leveling", "talents" } },
    { title = "Learn", keys = { "learn" } },
    { title = "More", keys = { "news", "settings" } },
}

-- Old tab names (slash commands, links) -> new screen + sub-tab.
UI.ALIASES = {
    overview = { "home" }, training = { "leveling", "Trainer" }, spells = { "leveling", "Trainer" },
    quests = { "leveling", "Class quests" }, mounts = { "leveling", "Riding & gold" }, gold = { "leveling", "Riding & gold" },
    reminders = { "settings", "Reminders" }, options = { "settings" }, config = { "settings" }, trainer = { "leveling", "Trainer" }, riding = { "leveling", "Riding & gold" },
    sources = { "settings", "About the data" }, about = { "settings", "About" }, changes = { "news" },
    mana = { "rotation", "Mana" }, seals = { "rotation", "Seals & auras" }, bless = { "settings", "Paladin bar" }, buff = { "settings", "Paladin bar" },
    pvp = { "battle" }, honor = { "battle", "Honor & Rank" }, battlegrounds = { "battle", "Battlegrounds" }, pvpbar = { "battle", "PvP bar" },
    cooldowns = { "battle", "Cooldowns" }, burst = { "battle", "Burst coach" }, worldpvp = { "battle", "World PvP" },
}

local W, H, SIDE, HEAD = 980, 660, 210, 56
-- Fixed content width: GetWidth() on an anchored frame can be 0 before the first layout pass.
local CONTENT_W = W - SIDE - 2 - 28 - 34 - 6
local frame

local function ctx()
    local level = UnitLevel("player") or 1
    local _, faction = UnitFactionGroup("player")
    return {
        spec = ns.DB.ActiveSpec(),
        profile = ns.DB.Profile(),
        level = level,
        race = ns.Progress.PlayerRace(),
        faction = UnitFactionGroup("player") or faction,
        name = UnitName("player"),
    }
end
UI.Ctx = ctx

local function ApplyHeader()
    if not frame then return end
    local a = UI.Accent()
    local spec = ns.DB.ActiveSpec()
    local s = ns.Specs[spec]
    frame.logo:SetTexture(s and s.icon or ns.NEUTRAL_ICON)
    frame.logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.specPill.dot:SetColorTexture(a[1], a[2], a[3], 1)
    frame.specPill:SetBackdropBorderColor(a[1], a[2], a[3], 1)
    frame.specPill.label:SetText(s and (spec .. " · " .. s.role .. "   " .. UI.Hex(UI.C.dim) .. "change|r") or ("Pick a spec   " .. UI.Hex(UI.C.dim) .. "change|r"))
    frame.specPill:SetWidth(frame.specPill.label:GetStringWidth() + 44)
    for _, id in ipairs(ns.DB.PROFILE_IDS) do
        local b = frame.profileButtons[id]
        local p = ns.DB.Profile(id)
        local active = ns.DB.ActiveId() == id
        b.label:SetText(id .. " · " .. (p.spec or "-"))
        b:SetWidth(b.label:GetStringWidth() + 20)
        b:SetBackdropColor(unpack(active and { 0.165, 0.165, 0.22, 1 } or { 0, 0, 0, 0 }))
        b.label:SetTextColor(unpack(active and { 1, 1, 1 } or UI.C.dim))
        b.tip = ("Profile %s%s. Follows talent spec %s (dual spec); click to switch by hand."):format(id, p.spec and (" (" .. p.spec .. ")") or "", id == "A" and "1" or "2")
    end
    local segW = 8
    for _, id in ipairs(ns.DB.PROFILE_IDS) do segW = segW + frame.profileButtons[id]:GetWidth() + 3 end
    frame.profileSeg:SetWidth(segW)
end

local function UpdateNav()
    local a = UI.Accent()
    for key, b in pairs(frame.navButtons) do
        local p = ns.Panels[key]
        local selected = frame.current == key
        b.bg:SetColorTexture(1, 1, 1, selected and 0.07 or 0)
        b.bar:SetColorTexture(a[1], a[2], a[3], selected and 1 or 0)
        b.text:SetTextColor(unpack(selected and { 1, 1, 1 } or { 0.84, 0.84, 0.886 }))
        local n = p and p.badge and p.badge() or 0
        if n and n > 0 then
            b.badge.text:SetText(n > 99 and "99+" or tostring(n))
            b.badge:SetWidth(math.max(20, b.badge.text:GetStringWidth() + 12))
            b.badge:Show()
        else
            b.badge:Hide()
        end
    end
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    ApplyHeader()
    UpdateNav()
    local key = frame.current
    local p = ns.Panels[key]
    local view = key and frame.views[key]
    if not view then return end
    view.layout:Reset(CONTENT_W)
    local ok, err = pcall(p.render, view.layout, ctx())
    if not ok then
        view.layout:Text(UI.Hex(UI.C.bad) .. "This panel hit an error: " .. tostring(err) .. "|r")
        ns.Debug(err)
    end
    view.layout:Finish()
    UI.currentNotes = view.layout.notes -- what the "Sources & notes" link shows (tests read it too)
    frame.picker:SetShown(not ns.DB.HasChosenSpec() or frame.forcePicker)
end

function UI.Select(key, sub)
    local alias = UI.ALIASES[key or ""]
    if alias then key, sub = alias[1], sub or alias[2] end
    if not ns.Panels[key] then key = "home" end
    UI.Build()
    if sub and ns.Panels[key].setSub then ns.Panels[key].setSub(sub) end
    if frame.current and frame.views[frame.current] then frame.views[frame.current].content:Hide() end
    frame.current = key
    ns.db.char.window.tab = key
    local view = frame.views[key]
    if not view then
        local content = CreateFrame("Frame", nil, frame.scroll)
        content:SetSize(CONTENT_W + 20, 1)
        view = { content = content, layout = UI.NewLayout(content, CONTENT_W) }
        frame.views[key] = view
    end
    frame.scroll:SetScrollChild(view.content)
    view.content:Show()
    frame.scroll:SetVerticalScroll(0)
    frame.search.results:Hide()
    UI.Refresh()
end

----------------------------------------------------------------------------
-- Search: spells, talents, items, quests, dungeons -> jump to the right screen.
----------------------------------------------------------------------------
local function searchIndex()
    if UI.searchIndex then return UI.searchIndex end
    local idx = {}
    local function add(kind, name, open)
        if name then table.insert(idx, { kind = kind, name = name, lower = name:lower(), open = open }) end
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for _, s in ipairs(ns.Data.Spells) do
        if not (s.faction and faction and s.faction ~= faction) then
            add("Spell", s.display, function() UI.Select("learn", "Spells") end)
        end
    end
    for _, bg in ipairs(ns.PvP.Battlegrounds()) do
        add("PvP", bg.name, function() UI.Select("battle", "Battlegrounds") end)
    end
    for _, tree in ipairs(ns.Data.TalentTrees or {}) do
        for _, t in ipairs(tree.talents) do add("Talent", t.name, function() UI.Select("talents") end) end
    end
    local seen = {}
    local function item(id, name)
        if seen[id] then return end
        seen[id] = true
        add("Item", name, function() UI.OpenGearDetail(id) UI.Select("gear") end)
    end
    for _, list in pairs(ns.Data.GearBrackets) do
        for _, g in ipairs(list) do item(g.item_id, g.name) end
    end
    for _, q in ipairs(ns.Data.Quests) do
        if not (q.faction and faction and q.faction ~= "Both" and q.faction ~= faction) then
            add("Quest", q.name, function() UI.Select("leveling", "Class quests") end)
        end
    end
    for _, d in ipairs(ns.Data.Dungeons) do add("Dungeon", d.name, function() UI.Select("leveling", "Zones & dungeons") end) end
    UI.searchIndex = idx
    return idx
end

function UI.Search(text)
    text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local out = {}
    if #text < 2 then return out end
    for _, e in ipairs(searchIndex()) do
        local pos = e.lower:find(text, 1, true)
        if pos then table.insert(out, { e = e, score = (pos == 1 and 0 or 1) }) end
    end
    table.sort(out, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        return a.e.name < b.e.name
    end)
    local res = {}
    for i = 1, math.min(8, #out) do res[i] = out[i].e end
    return res
end

local function BuildSearch(parent)
    local box = CreateFrame("EditBox", "TristansAddonSearch", parent, "BackdropTemplate")
    box:SetSize(SIDE - 24, 30)
    box:SetPoint("TOPLEFT", 12, -12)
    UI.Backdrop(box, UI.C.card, UI.C.border)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetTextInsets(10, 8, 0, 0)
    box.hint = UI.Text(box, 12, UI.C.dim)
    box.hint:SetPoint("LEFT", 10, 0)
    box.hint:SetText("Search spells, items, quests...")
    box.results = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box.results:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
    box.results:SetWidth(320)
    box.results:SetFrameStrata("DIALOG")
    UI.Backdrop(box.results, UI.C.bg, UI.C.border)
    box.results:Hide()
    box.rows = {}
    for i = 1, 8 do
        local r = CreateFrame("Button", nil, box.results)
        r:SetSize(312, 26)
        r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 26)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(1, 1, 1, 0)
        r.kind = UI.Text(r, 10, UI.C.dim)
        r.kind:SetPoint("LEFT", 8, 0)
        r.kind:SetWidth(60)
        r.text = UI.Text(r, 13)
        r.text:SetPoint("LEFT", 70, 0)
        r.text:SetWidth(234)
        r.text:SetWordWrap(false)
        r:SetScript("OnEnter", function(s) s.bg:SetColorTexture(1, 1, 1, 0.07) end)
        r:SetScript("OnLeave", function(s) s.bg:SetColorTexture(1, 1, 1, 0) end)
        r:SetScript("OnClick", function(s)
            box:SetText("")
            box:ClearFocus()
            box.results:Hide()
            if s.entry then s.entry.open() end
        end)
        box.rows[i] = r
    end
    function box.Update(self)
        local t = self:GetText() or ""
        self.hint:SetShown(t == "")
        local res = UI.Search(t)
        for i = 1, 8 do
            local r, e = self.rows[i], res[i]
            r.entry = e
            if e then
                r.kind:SetText(e.kind:upper())
                r.text:SetText(e.name)
                r:Show()
            else
                r:Hide()
            end
        end
        if #res == 0 and #t >= 2 then
            local r = self.rows[1]
            r.kind:SetText("")
            r.text:SetText(UI.Hex(UI.C.dim) .. "No matches|r")
            r:Show()
            self.results:SetHeight(34)
        else
            self.results:SetHeight(8 + #res * 26)
        end
        self.results:SetShown(#t >= 2)
    end
    box:SetScript("OnTextChanged", function(self) self:Update() end)
    box:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() self.results:Hide() end)
    box:SetScript("OnEnterPressed", function(self)
        local first = self.rows[1].entry
        self:ClearFocus()
        self.results:Hide()
        if first then self:SetText("") first.open() end
    end)
    return box
end

local function BuildPicker(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetPoint("TOPLEFT", parent.body, "TOPLEFT")
    f:SetPoint("BOTTOMRIGHT", parent.body, "BOTTOMRIGHT")
    f:SetFrameLevel(parent:GetFrameLevel() + 20)
    UI.Backdrop(f, { 0.04, 0.04, 0.06, 0.98 }, { 0, 0, 0, 0 })
    f:EnableMouse(true)
    local title = UI.Text(f, 20)
    title:SetPoint("TOP", 0, -40)
    title:SetJustifyH("CENTER")
    f.title = title
    local sub = UI.Text(f, 13, UI.C.dim)
    sub:SetPoint("TOP", title, "BOTTOM", 0, -8)
    sub:SetWidth(560)
    sub:SetJustifyH("CENTER")
    sub:SetText("Rotation, gear tips, reminders and lessons all follow this choice. Change it any time from the spec pill at the top.")
    f.sub = sub
    f.cards = {}
    local cardW, gap = 200, 18
    local total = cardW * 3 + gap * 2
    for i, key in ipairs(ns.SPEC_ORDER) do
        local s = ns.Specs[key]
        local c = CreateFrame("Button", nil, f, "BackdropTemplate")
        c:SetSize(cardW, 240)
        c:SetPoint("TOPLEFT", f, "TOP", -total / 2 + (i - 1) * (cardW + gap), -120)
        UI.Backdrop(c, UI.C.card, UI.C.border)
        local icon = c:CreateTexture(nil, "ARTWORK")
        icon:SetSize(56, 56)
        icon:SetPoint("TOP", 0, -24)
        icon:SetTexture(s.icon)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local name = UI.Text(c, 18, s.accent)
        name:SetPoint("TOP", icon, "BOTTOM", 0, -14)
        name:SetJustifyH("CENTER")
        name:SetText(key)
        local role = UI.Text(c, 12, UI.C.dim)
        role:SetPoint("TOP", name, "BOTTOM", 0, -4)
        role:SetJustifyH("CENTER")
        role:SetText(s.role)
        c.role = role
        local blurb = UI.Text(c, 12)
        blurb:SetPoint("TOP", role, "BOTTOM", 0, -12)
        blurb:SetWidth(cardW - 28)
        blurb:SetJustifyH("CENTER")
        blurb:SetText(s.blurb)
        c:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(s.accent)) self:SetBackdropColor(unpack(UI.C.cardHover)) end)
        c:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(UI.C.border)) self:SetBackdropColor(unpack(UI.C.card)) end)
        c:SetScript("OnClick", function()
            ns.DB.SetSpec(key)
            parent.forcePicker = false
            UI.Refresh()
        end)
        f.cards[key] = c
    end
    f:SetScript("OnShow", function()
        f.title:SetText(("Pick a spec for profile %s (talent spec %s)"):format(ns.DB.ActiveId(), ns.DB.ActiveId() == "A" and "1" or "2"))
        -- No talents yet (under 10): still pick one so the advice fits; recommend the research's leveling pick.
        local level = UnitLevel("player") or 1
        if level < 10 then
            f.sub:SetText(("You're level %d: talents start at 10, so nothing is locked in yet. Pick the spec you plan to level as; everything follows it and you can change it any time. The plan: level as %s, then at 40 make dual spec Retribution (A) + Holy (B) for battlegrounds."):format(level, ns.RECOMMENDED_LEVELING_SPEC))
        else
            f.sub:SetText("Rotation, gear tips, reminders and lessons all follow this choice. Change it any time from the spec pill at the top. Dual spec at 40: Retribution (A) + Holy (B) for battlegrounds.")
        end
        for key, c in pairs(f.cards) do
            local s = ns.Specs[key]
            c.role:SetText(s.role .. ((key == ns.RECOMMENDED_LEVELING_SPEC) and ("  " .. UI.Hex(UI.C.good) .. "recommended for leveling|r") or ""))
        end
    end)
    f:Hide()
    return f
end

function UI.Build()
    if frame then return frame end
    frame = CreateFrame("Frame", "TristansAddonFrame", UIParent, "BackdropTemplate")
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    UI.Backdrop(frame, UI.C.bg, UI.C.border)
    table.insert(UISpecialFrames, "TristansAddonFrame")
    frame.views, frame.navButtons = {}, {}

    -- Header
    local head = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(HEAD)
    UI.Backdrop(head, UI.C.head, { 0, 0, 0, 0 })
    local rule = head:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    rule:SetHeight(1)
    rule:SetColorTexture(unpack(UI.C.softBorder))
    frame.logo = head:CreateTexture(nil, "ARTWORK")
    frame.logo:SetSize(24, 24)
    frame.logo:SetPoint("LEFT", 18, 0)
    local title = UI.Text(head, 16)
    title:SetPoint("LEFT", frame.logo, "RIGHT", 12, 0)
    title:SetText(ns.TITLE)
    local tag = UI.Text(head, 11, UI.C.dim)
    tag:SetPoint("LEFT", title, "RIGHT", 10, -1)
    tag:SetText("WoW Forever · " .. (tostring(ns.VERSION):match("^v") and ns.VERSION or ("v" .. ns.VERSION)))

    local close = CreateFrame("Button", nil, head, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -8, 0)

    local seg = CreateFrame("Frame", nil, head, "BackdropTemplate")
    seg:SetSize(180, 32)
    UI.Backdrop(seg, { 0.094, 0.094, 0.133, 1 }, UI.C.border)
    frame.profileButtons = {}
    local prev
    for _, id in ipairs(ns.DB.PROFILE_IDS) do
        local b = CreateFrame("Button", nil, seg, "BackdropTemplate")
        b:SetSize(84, 24)
        UI.Backdrop(b, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
        b.label = UI.Text(b, 12)
        b.label:SetPoint("CENTER")
        b.label:SetWordWrap(false)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 3, 0) else b:SetPoint("LEFT", seg, "LEFT", 4, 0) end
        b:SetScript("OnClick", function() ns.DB.SwitchProfile(id) UI.Refresh() end)
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:SetText(s.tip or "", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.profileButtons[id] = b
        prev = b
    end
    seg:SetPoint("RIGHT", close, "LEFT", -8, 0)
    frame.profileSeg = seg

    local pill = CreateFrame("Button", nil, head, "BackdropTemplate")
    pill:SetSize(180, 32)
    UI.Backdrop(pill, { 0.125, 0.125, 0.169, 1 }, UI.C.border)
    pill.dot = pill:CreateTexture(nil, "ARTWORK")
    pill.dot:SetSize(10, 10)
    pill.dot:SetPoint("LEFT", 12, 0)
    pill.label = UI.Text(pill, 13)
    pill.label:SetPoint("LEFT", pill.dot, "RIGHT", 8, 0)
    pill.label:SetWordWrap(false)
    pill:SetPoint("RIGHT", seg, "LEFT", -10, 0)
    pill:SetScript("OnClick", function() frame.forcePicker = true UI.Refresh() end)
    pill:SetScript("OnEnter", function(s) s:SetBackdropColor(unpack(UI.C.cardHover)) end)
    pill:SetScript("OnLeave", function(s) s:SetBackdropColor(0.125, 0.125, 0.169, 1) end)
    frame.specPill = pill

    -- Sidebar
    local side = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    side:SetPoint("TOPLEFT", 1, -(HEAD + 1))
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDE)
    UI.Backdrop(side, UI.C.side, { 0, 0, 0, 0 })
    local sideRule = side:CreateTexture(nil, "ARTWORK")
    sideRule:SetPoint("TOPRIGHT")
    sideRule:SetPoint("BOTTOMRIGHT")
    sideRule:SetWidth(1)
    sideRule:SetColorTexture(unpack(UI.C.softBorder))
    frame.side = side
    frame.search = BuildSearch(side)

    local y = -54
    for _, group in ipairs(UI.NAV) do
        y = y - 6
        if group.title then
            local lbl = UI.Text(side, 11, UI.C.label)
            lbl:SetPoint("TOPLEFT", 24, y)
            lbl:SetText(group.title:upper())
            y = y - 20
        end
        for _, key in ipairs(group.keys) do
            local p = ns.Panels[key]
            if p then
                local t = CreateFrame("Button", nil, side)
                t:SetSize(SIDE - 24, 34)
                t:SetPoint("TOPLEFT", 12, y)
                t.bg = t:CreateTexture(nil, "BACKGROUND")
                t.bg:SetAllPoints()
                t.bar = t:CreateTexture(nil, "ARTWORK")
                t.bar:SetPoint("TOPLEFT")
                t.bar:SetPoint("BOTTOMLEFT")
                t.bar:SetWidth(3)
                t.text = UI.Text(t, 14)
                t.text:SetPoint("LEFT", 14, 0)
                t.text:SetWordWrap(false)
                t.text:SetText(p.label)
                t.badge = CreateFrame("Frame", nil, t, "BackdropTemplate")
                t.badge:SetSize(22, 18)
                t.badge:SetPoint("RIGHT", -8, 0)
                UI.Backdrop(t.badge, UI.C.badge, { 0, 0, 0, 0 })
                t.badge.text = UI.Text(t.badge, 11)
                t.badge.text:SetPoint("CENTER")
                t.badge.text:SetJustifyH("CENTER")
                t.badge:Hide()
                t:SetScript("OnEnter", function(s) if frame.current ~= key then s.bg:SetColorTexture(1, 1, 1, 0.04) end end)
                t:SetScript("OnLeave", function(s) if frame.current ~= key then s.bg:SetColorTexture(1, 1, 1, 0) end end)
                t:SetScript("OnClick", function() UI.Select(key) end)
                frame.navButtons[key] = t
                y = y - 36
            end
        end
    end
    local foot = UI.Text(side, 10, UI.C.dim)
    foot:SetPoint("BOTTOMLEFT", 24, 14)
    foot:SetText("Data checked " .. ((ns.Data.Meta and ns.Data.Meta.checked) or "?"))

    -- Body / scroll
    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
    frame.body:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.scroll = CreateFrame("ScrollFrame", nil, frame.body, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 28, -22)
    frame.scroll:SetPoint("BOTTOMRIGHT", -34, 14)

    frame.picker = BuildPicker(frame)
    frame:SetScript("OnShow", function() UI.Refresh() end)
    frame:Hide()

    ns.On("SPEC_CHANGED", function() UI.Refresh() end)
    ns.On("CHANGES_READ", function() UI.Refresh() end)
    return frame
end

function UI.Toggle(key)
    UI.Build()
    if frame:IsShown() and (not key or key == frame.current) then
        frame:Hide()
        return
    end
    frame:Show()
    UI.Select(key or frame.current or ns.db.char.window.tab or "home")
end

function UI.Open(key, sub)
    UI.Build()
    frame:Show()
    UI.Select(key or frame.current or ns.db.char.window.tab or "home", sub)
end

function UI.ShowPicker()
    UI.Open("home")
    frame.forcePicker = true
    UI.Refresh()
end
