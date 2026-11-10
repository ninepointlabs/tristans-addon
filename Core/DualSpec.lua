-- Dual spec: talent group 1 <-> profile A, group 2 <-> profile B.
--
-- Forever has Dual Specialization at level 40 (foreverguide.net; Blizzard deep dives;
-- confirmed in game on the Priest sister addon by Tim 2026-11-09). The API below is what Blizzard's own
-- Forever talent frame uses (Gethe/wow-ui-source@forever, build 1.60.1.70862:
-- Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua):
--   C_SpecializationInfo.GetActiveSpecGroup() -> 1|2
--   GetNumSpecGroups()                         -> 1 before dual spec is learned, 2 after
--   event ACTIVE_TALENT_GROUP_CHANGED(curr, prev)
--
-- With "Auto-switch profile" on (default), swapping talent specs swaps the
-- addon's active profile. Each profile keeps its own spec pick, so pick
-- e.g. Retribution for A and Holy for B once and it follows from then on.
local _, ns = ...

local DualSpec = {}
ns.DualSpec = DualSpec

DualSpec.GROUP_TO_PROFILE = { [1] = "A", [2] = "B" }

local function activeGroup()
    if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
        local ok, g = pcall(C_SpecializationInfo.GetActiveSpecGroup)
        if ok and type(g) == "number" and not ns.Auras.IsSecret(g) then return g end
    end
    return nil
end
DualSpec.ActiveGroup = activeGroup

-- API present in this client?
function DualSpec.IsAvailable()
    return C_SpecializationInfo ~= nil and C_SpecializationInfo.GetActiveSpecGroup ~= nil
end

-- Has this character learned dual spec (two talent groups)?
function DualSpec.HasDualSpec()
    if not GetNumSpecGroups then return false end
    local ok, n = pcall(GetNumSpecGroups)
    return ok and type(n) == "number" and n > 1
end

-- Single entry point for talent-group changes.
function DualSpec.OnTalentGroupChanged(groupIndex)
    if not ns.DB.char.autoSwitch then return false end
    local id = DualSpec.GROUP_TO_PROFILE[groupIndex]
    if not id then return false end
    return ns.DB.SwitchProfile(id)
end

-- Match the active profile to the active talent group (login / toggle on).
function DualSpec.Sync()
    local g = activeGroup()
    if g then return DualSpec.OnTalentGroupChanged(g) end
    return false
end

function DualSpec.Register(frame)
    if not DualSpec.IsAvailable() then return end
    pcall(frame.RegisterEvent, frame, "ACTIVE_TALENT_GROUP_CHANGED")
    ns.On("WOW_ACTIVE_TALENT_GROUP_CHANGED", function(curr)
        local g = (type(curr) == "number" and not ns.Auras.IsSecret(curr)) and curr or activeGroup()
        if g and DualSpec.OnTalentGroupChanged(g) then
            local spec = ns.DB.ActiveSpec()
            ns.Print(("Talent spec %d active: switched to profile %s (%s)."):format(g, ns.DB.ActiveId(), spec or "no spec picked yet"))
            if not spec then ns.UI.ShowPicker() end
        end
    end)
    DualSpec.Sync()
end
