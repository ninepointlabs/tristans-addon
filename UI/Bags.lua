-- Bag upgrade highlight + "you just got an upgrade" toast.
--
-- Hooks the same Blizzard bag refresh points Pawn uses on Forever
-- (ContainerFrameMixin.UpdateItems / ContainerFrameCombinedBags / ContainerFrameN,
-- or ContainerFrame_Update on older bag code). We draw our own overlay instead of
-- Blizzard's shared button.UpgradeIcon so we never fight Pawn over it.
local _, ns = ...
local UI = ns.UI

local Bags = {}
ns.Bags = Bags

local NUM_BAGS = NUM_BAG_SLOTS or 4
local hooked = false

-- Upgrade check for a bag item link (active profile's spec). Pure-ish for tests.
function Bags.Check(link)
    if not link then return nil end
    local level = UnitLevel("player")
    local res = ns.Stats.Compare(link, ns.DB.ActiveSpec(), level, ns.DB.Profile(), ns.db.global.percentScale)
    if ns.Stats.IsUpgrade(res, level) then return res end
    return nil
end

local function overlay(button)
    local existing = rawget(button, "TristansUpgrade")
    if existing then return existing end
    local o = CreateFrame("Frame", nil, button)
    o:SetAllPoints()
    o:SetFrameLevel(button:GetFrameLevel() + 5)
    o.glow = o:CreateTexture(nil, "OVERLAY")
    o.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    o.glow:SetBlendMode("ADD")
    o.glow:SetPoint("CENTER")
    o.glow:SetSize(button:GetWidth() * 1.9, button:GetHeight() * 1.9)
    o.arrow = o:CreateTexture(nil, "OVERLAY", nil, 2)
    o.arrow:SetSize(14, 14)
    o.arrow:SetPoint("TOPRIGHT", 2, 2)
    o.arrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Yellow")
    o.arrow:SetRotation(math.pi) -- point up
    o:Hide()
    button.TristansUpgrade = o
    return o
end

local function bagSlot(button)
    local bag = button.GetBagID and button:GetBagID() or (button:GetParent() and button:GetParent():GetID())
    return bag, button:GetID()
end

function Bags.UpdateButton(button)
    if not button or rawget(button, "isExtended") then return end
    local enabled = ns.db and ns.db.global.bags.highlight and ns.DB.ActiveSpec()
    local link
    if enabled then
        local bag, slot = bagSlot(button)
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        link = ok and info and info.hyperlink
    end
    local res = enabled and Bags.Check(link)
    if res then
        local o = overlay(button)
        local a = UI.Accent()
        o.glow:SetVertexColor(0.25, 1, 0.35, 0.9)
        o.arrow:SetVertexColor(a[1], a[2], a[3])
        o:Show()
    elseif rawget(button, "TristansUpgrade") then
        rawget(button, "TristansUpgrade"):Hide()
    end
end

local function updateFrame(frame)
    if not frame then return end
    if frame.EnumerateValidItems then
        for _, button in frame:EnumerateValidItems() do pcall(Bags.UpdateButton, button) end
    elseif frame.GetName and frame:GetName() and frame.size then
        for i = 1, frame.size do pcall(Bags.UpdateButton, _G[frame:GetName() .. "Item" .. i]) end
    end
end

function Bags.RefreshAll()
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then updateFrame(ContainerFrameCombinedBags) end
    for i = 1, (NUM_TOTAL_BAG_FRAMES or NUM_CONTAINER_FRAMES or 13) do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then updateFrame(f) end
    end
end

function Bags.Install()
    if hooked then return end
    hooked = true
    if ContainerFrameMixin then
        hooksecurefunc(ContainerFrameMixin, "UpdateItems", updateFrame)
        if ContainerFrameCombinedBags then hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", updateFrame) end
        for i = 1, (NUM_TOTAL_BAG_FRAMES or NUM_CONTAINER_FRAMES or 13) do
            local f = _G["ContainerFrame" .. i]
            if f and f.UpdateItems then hooksecurefunc(f, "UpdateItems", updateFrame) end
        end
    elseif ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", updateFrame)
    end
end

-- Upgrades currently in the bags (no side effects; used by Home).
function Bags.Upgrades()
    if not ns.db or not ns.DB.ActiveSpec() then return {} end
    local found = {}
    for bag = 0, NUM_BAGS do
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (ok and n or 0) do
            local okInfo, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
            local link = okInfo and info and info.hyperlink
            local res = link and Bags.Check(link)
            if res then table.insert(found, { link = link, res = res }) end
        end
    end
    return found
end

-- Scan bags for upgrades; toast once per item link.
local announced = {}
function Bags.Scan(silent)
    if not ns.db or not ns.DB.ActiveSpec() then return {} end
    local found = {}
    for _, u in ipairs(Bags.Upgrades()) do
        local link, res = u.link, u.res
        do
            if res then
                table.insert(found, { link = link, res = res })
                if not announced[link] then
                    announced[link] = true
                    if not silent and ns.db.global.bags.toast then
                        local gain = res.against.empty and "empty slot" or (res.pct and ("%+.0f%%"):format(res.pct) or "better")
                        ns.Print("|cff3fdc5aUpgrade in your bags:|r " .. link .. " (" .. gain .. " for " .. ns.DB.ActiveSpec() .. "). Equip it!")
                        local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(link) or nil
                        ns.Fire("TOAST", "Upgrade in your bags (" .. gain .. ")", (link:match("%[(.-)%]") or "Item") .. " - equip it!", icon)
                    end
                end
            end
        end
    end
    return found
end

-- New spec / new gear changes what counts as an upgrade: allow re-announcing.
function Bags.Reset()
    announced = {}
end
