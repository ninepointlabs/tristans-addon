-- Minimap button (no LibDBIcon dependency) + Blizzard Settings entry.
local _, ns = ...
local UI = ns.UI

local btn

local function position()
    local angle = math.rad(ns.db.global.minimap.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 10
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function UI.MinimapButton()
    if btn then
        btn:SetShown(not ns.db.global.minimap.hide)
        return btn
    end
    btn = CreateFrame("Button", "TristansAddonMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(54, 54)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(18, 18)
    btn.icon:SetPoint("TOPLEFT", 7, -6)
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.badge = btn:CreateTexture(nil, "OVERLAY", nil, 2)
    btn.badge:SetSize(10, 10)
    btn.badge:SetPoint("TOPRIGHT", -2, -2)
    btn.badge:SetColorTexture(0.9, 0.2, 0.2, 1)
    btn:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then UI.Open("options") else UI.Toggle() end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.db.global.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            position()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.TITLE)
        GameTooltip:AddLine((ns.DB.ActiveSpec() or "No spec") .. " · profile " .. ns.DB.ActiveId(), 1, 1, 1)
        local n = ns.Changes.UnreadCount()
        if n > 0 then GameTooltip:AddLine(n .. " unread change(s)", 1, 0.4, 0.4) end
        GameTooltip:AddLine("Left-click: open · Right-click: options · Drag: move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    position()
    UI.UpdateMinimap()
    btn:SetShown(not ns.db.global.minimap.hide)
    return btn
end

function UI.UpdateMinimap()
    if not btn then return end
    local s = ns.Specs[ns.DB.ActiveSpec()]
    btn.icon:SetTexture(s and s.icon or ns.NEUTRAL_ICON)
    btn.badge:SetShown(ns.Changes.UnreadCount() > 0)
end

-- Addon compartment (TOC: AddonCompartmentFunc).
function TristansAddon_OnCompartmentClick()
    if ns.disabled then return end
    UI.Toggle()
end

-- Blizzard Settings: a small page that opens the main window's Options tab.
function UI.RegisterSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    local title = UI.Text(panel, 20, { 1, 0.82, 0.3 })
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ns.TITLE)
    local text = UI.Text(panel, 12)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetWidth(560)
    text:SetText("The do-everything Paladin companion for WoW Forever, with a Battle (PvP) section. All options live in the main window. Type /tristan or /paladin.")
    local b = UI.Button(panel, "Open Tristan's Addon", 180, 26, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        UI.Open("options")
    end)
    b:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, ns.TITLE)
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        UI.settingsCategory = category
    end
end
