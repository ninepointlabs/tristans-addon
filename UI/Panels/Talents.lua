local _, ns = ...
local UI = ns.UI

-- Selected build per spec (session only).
local selected = {}

local CELL, GAP, TREE_GAP = 36, 7, 26

-- One talent cell: icon, points badge, tooltip with the in-game spell.
local function acquireCell(L)
    return L:Acquire("talentCell", function()
        local f = CreateFrame("Button", nil, L.content, "BackdropTemplate")
        f:SetSize(CELL, CELL)
        UI.Backdrop(f, { 0, 0, 0, 0.6 }, UI.C.border)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("TOPLEFT", 1, -1)
        f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        f.pts = UI.Text(f, 10)
        UI.Font(f.pts, 10, "OUTLINE")
        f.pts:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
        f.pts:SetJustifyH("RIGHT")
        f.pts:SetWordWrap(false)
        f:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            local ok = s.spellId and pcall(GameTooltip.SetSpellByID, GameTooltip, s.spellId)
            if not ok then
                GameTooltip:SetText(s.talent.name, 1, 1, 1)
                GameTooltip:AddLine(s.talent.desc_max, 1, 0.82, 0, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(("This build: %d/%d"):format(s.points, s.talent.max_rank), unpack(s.points > 0 and UI.Accent() or UI.C.dim))
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return f
    end)
end

local function drawTrees(L, build)
    local trees = ns.Data.TalentTrees
    local maxRow = 1
    for _, tree in ipairs(trees) do
        for _, t in ipairs(tree.talents) do maxRow = math.max(maxRow, t.row) end
    end
    local treeW = 4 * CELL + 3 * GAP
    local top = L.y
    for ti, tree in ipairs(trees) do
        local x0 = (ti - 1) * (treeW + TREE_GAP)
        local label = L:Acquire("treeLabel", function() return UI.Text(L.content, 12) end)
        label:SetWidth(treeW)
        label:SetPoint("TOPLEFT", L.content, "TOPLEFT", x0, -top)
        local spent = build.trees[ti].spent
        label:SetText((spent > 0 and UI.Hex(UI.Accent()) or UI.Hex(UI.C.dim)) .. tree.name .. "|r  " .. UI.Hex(UI.C.dim) .. spent .. " pts|r")
        for i, t in ipairs(tree.talents) do
            local p = build.trees[ti].points[i] or 0
            local cell = acquireCell(L)
            cell.talent, cell.points = t, p
            cell.spellId = t.rank_spell_ids[math.max(1, p)]
            cell.icon:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            cell.icon:SetDesaturated(p == 0)
            cell.icon:SetAlpha(p == 0 and 0.35 or 1)
            local full = p > 0 and p == t.max_rank
            cell:SetBackdropBorderColor(unpack(p == 0 and UI.C.border or (full and UI.Accent() or UI.C.good)))
            cell.pts:SetText(p > 0 and ((full and UI.Hex(UI.Accent()) or UI.Hex(UI.C.good)) .. p .. "/" .. t.max_rank .. "|r") or "")
            cell:SetPoint("TOPLEFT", L.content, "TOPLEFT", x0 + (t.col - 1) * (CELL + GAP), -(top + 20 + (t.row - 1) * (CELL + GAP)))
        end
    end
    L.y = top + 20 + maxRow * (CELL + GAP) + 6
end

local function buildList(L, build)
    for ti, tree in ipairs(ns.Data.TalentTrees) do
        local lines = {}
        for i, t in ipairs(tree.talents) do
            local p = build.trees[ti].points[i] or 0
            if p > 0 then
                table.insert(lines, ("%s%s %d/%d|r  %s%s|r"):format(p == t.max_rank and UI.Hex(UI.Accent()) or UI.Hex(UI.C.good),
                    t.name, p, t.max_rank, UI.Hex(UI.C.dim), t.desc_max))
            end
        end
        if #lines > 0 then
            L:Text(tree.name .. " (" .. build.trees[ti].spent .. ")", { size = 13 })
            for _, line in ipairs(lines) do L:Text(line, { size = 11, indent = 10 }) end
        end
    end
end

UI.RegisterPanel({
    key = "talents", label = "Talents",
    render = function(L, c)
        local spec = c.spec
        L:Title("Talents", spec and ("Recommended " .. spec .. " builds, drawn on Forever's trees") or nil)
        if not spec then L:Text("Pick a spec first (spec pill at the top).") return end
        if c.level < 10 then
            L:Row({ chip = { text = "Level 10", kind = "info" }, title = "Talents start at level 10",
                sub = ("You're level %d: no talent points yet. The builds below show where you're heading."):format(c.level) })
        end
        local builds = {}
        for _, b in ipairs(ns.Data.DecodedBuilds or {}) do
            if b.spec == spec then table.insert(builds, b) end
        end
        if #builds == 0 then
            L:Text("No builds in the research for this spec.")
        else
            local cur = selected[spec]
            if not cur then
                for _, b in ipairs(builds) do
                    if not cur and ((c.level < 60 and b.purpose:find("Leveling")) or (c.level >= 60 and b.purpose:find("Raid"))) then cur = b.purpose end
                end
                cur = cur or builds[1].purpose
            end
            local items, build = {}, nil
            for _, b in ipairs(builds) do
                if b.purpose == cur then build = b end
                table.insert(items, { label = b.purpose, active = b.purpose == cur, onClick = function() selected[spec] = b.purpose UI.Refresh() end })
            end
            L:Tabs(items)
            build = build or builds[1]
            if build.valid then
                local spent = {}
                for ti, tree in ipairs(ns.Data.TalentTrees) do table.insert(spent, tree.name .. " " .. build.trees[ti].spent) end
                L:Row({ title = ("%s · %d points (level %d)"):format(table.concat(spent, " / "), build.total, build.level),
                    sub = "Hover a talent for its in-game tooltip.",
                    button = { label = "Copy build link", onClick = function() UI.CopyURL(build.url) end } })
                if build.level > c.level then
                    L:Text(UI.Hex(UI.C.dim) .. ("You have %d talent points at level %d; this build is the level-%d target. Work toward it in the order your guide suggests."):format(math.max(0, c.level - 9), c.level, build.level) .. "|r", { size = 11 })
                end
                L:Space(4)
                drawTrees(L, build)
                L:Label("What this build takes")
                buildList(L, build)
            else
                L:Row({ chip = { text = "Can't draw", kind = "warn" }, title = "This build doesn't fit the current talent tree",
                    sub = build.reason or "?", button = { label = "Copy build link", onClick = function() UI.CopyURL(build.url) end } })
            end
            L:Source(build)
            local meta = ns.Data.TalentTreesMeta
            if meta then
                L:Note(("Talent trees: Icy Veins calculator data for client build %s (checked %s)."):format(tostring(meta.client_build), meta.checked))
                L:Source({ source_url = meta.page_url, checked = meta.checked })
            end
        end
        for _, b in ipairs(ns.Data.Builds.Other or {}) do
            if b.spec == spec or b.spec == "Alt route" then
                L:Row({ icon = "Interface\\Icons\\INV_Misc_Map_01", title = b.spec .. ": " .. b.purpose, sub = b.notes,
                    button = b.talent_calc_url and { label = "Copy link", onClick = function() UI.CopyURL(b.talent_calc_url) end } or nil })
            end
        end
        L:Text(UI.Hex(UI.C.dim) .. "Talents start at level 10. Milestones: " .. ns.Data.Milestones.talent_milestones .. ". Respec at any class trainer in a major city.|r", { size = 12 })

        L:Label("What changed in Forever")
        local tree = ns.Specs[spec].tree
        for _, t in ipairs(ns.Data.TalentChanges) do
            if t.tree == tree or t.tree == "Baseline" then
                L:Row({ title = UI.Hex(t.tree == tree and UI.Accent() or UI.C.dim) .. t.tree .. "|r", sub = t.change })
            end
        end
        for _, t in ipairs(ns.Data.TalentChanges) do
            if t.tree ~= tree and t.tree ~= "Baseline" then L:Note(t.tree .. ": " .. t.change) end
        end
        L:Source(ns.Data.TalentChanges[1])


    end,
})
