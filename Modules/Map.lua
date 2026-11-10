-- Map helpers: find zones and dungeon entrances from the client's own map data
-- and drop a user waypoint (map pin + supertracked arrow).
--
-- Forever's world map uses Blizzard's standard DungeonEntranceDataProvider and
-- user waypoints (wow-ui-source@forever, Blizzard_WorldMap.lua), so these APIs
-- exist: C_Map.GetMapChildrenInfo / GetMapInfo, C_EncounterJournal.
-- GetDungeonEntrancesForMap, C_Map.SetUserWaypoint, C_SuperTrack.
-- Coordinates come from the client (entrances) or the Icy Veins DB (quest givers).
local _, ns = ...

local Map = {}
ns.Map = Map

local function norm(s)
    s = (s or ""):lower():gsub("^the ", ""):gsub("[^%w ]", ""):gsub("%s+", " ")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
Map.Norm = norm

-- Research gear "source" labels -> dungeon names used in game / research.
Map.DUNGEON_ALIASES = {
    bfd = "blackfathom deeps", deadmines = "deadmines", stockade = "stockade",
    ["sm graveyard"] = "scarlet monastery", ["sm library"] = "scarlet monastery",
    ["sm armory"] = "scarlet monastery", ["sm cathedral"] = "scarlet monastery",
    ["excavation site"] = "excavation site",
}

local zones -- normalized name -> mapID
local function topMap()
    local id = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    id = id or (C_Map.GetFallbackWorldMapID and C_Map.GetFallbackWorldMapID())
    local guard = 0
    while id and guard < 10 do
        local info = C_Map.GetMapInfo(id)
        if not info or not info.parentMapID or info.parentMapID == 0 then break end
        id = info.parentMapID
        guard = guard + 1
    end
    return id
end

function Map.Zones()
    if zones then return zones end
    zones = {}
    local top = topMap()
    if not top then return zones end
    local ok, children = pcall(C_Map.GetMapChildrenInfo, top, nil, true)
    for _, m in ipairs(ok and children or {}) do
        -- 3 = Zone, 2 = Continent, 4 = Dungeon map, 5 = Micro; keep zones/continents
        if m.mapType == 3 or m.mapType == 2 then
            local key = norm(m.name)
            if not zones[key] then zones[key] = m.mapID end
        end
    end
    return zones
end

function Map.FindZone(name)
    if not name then return nil end
    return Map.Zones()[norm(name)]
end

local entranceCache = {}
-- Find a dungeon entrance by (research) dungeon name. Returns {mapID, x, y, name} (x/y 0-1).
function Map.FindDungeonEntrance(name)
    local key = norm(name)
    key = Map.DUNGEON_ALIASES[key] or key
    if entranceCache[key] ~= nil then return entranceCache[key] or nil end
    local found = false
    if C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap then
        for _, mapID in pairs(Map.Zones()) do
            local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
            for _, e in ipairs(ok and list or {}) do
                local en = norm(e.name)
                if en == key or en:find(key, 1, true) or key:find(en, 1, true) then
                    local x, y = e.position:GetXY()
                    found = { mapID = mapID, x = x, y = y, name = e.name }
                    break
                end
            end
            if found then break end
        end
    end
    entranceCache[key] = found
    return found or nil
end

function Map.MapName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or "?"
end

-- Place a waypoint (x/y in 0-1) and turn on the guide arrow.
function Map.SetWaypoint(mapID, x, y, label)
    if not (mapID and x and y and C_Map.SetUserWaypoint and UiMapPoint) then
        ns.Print("Can't set a map pin here (map API unavailable).")
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
        ns.Print("This map doesn't allow pins: " .. Map.MapName(mapID) .. ".")
        return false
    end
    local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if not ok then
        ns.Print("Couldn't set the map pin.")
        return false
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
    ns.Print(("Map pin set: %s (%s %.1f, %.1f). Follow the arrow or open your map (M)."):format(label or "?", Map.MapName(mapID), x * 100, y * 100))
    return true
end

function Map.Open(mapID)
    if OpenWorldMap then pcall(OpenWorldMap, mapID) end
end
