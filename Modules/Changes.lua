-- "What's changed": research baseline + items written by the companion poller
-- (tools/paladin-changes-poller -> Data/Changes.lua). Read state is account-wide.
local _, ns = ...

local Changes = {}
ns.Changes = Changes

local function researchItems()
    local out = {}
    for _, c in ipairs(ns.Data.ChangesLog or {}) do
        table.insert(out, {
            id = "research:" .. c.date .. ":" .. c.change:sub(1, 40),
            date = c.date, source = "Research", title = c.change, url = c.source_url,
        })
    end
    return out
end

function Changes.All()
    local items = {}
    local polled = ns.Data.Changes and ns.Data.Changes.items or {}
    for _, it in ipairs(polled) do table.insert(items, it) end
    for _, it in ipairs(researchItems()) do table.insert(items, it) end
    table.sort(items, function(a, b) return (a.date or "") > (b.date or "") end)
    return items
end

function Changes.IsRead(item)
    return ns.db.global.changesRead[item.id] == true
end

function Changes.UnreadCount()
    local n = 0
    for _, it in ipairs(Changes.All()) do
        if not Changes.IsRead(it) then n = n + 1 end
    end
    return n
end

function Changes.MarkRead(item)
    ns.db.global.changesRead[item.id] = true
    ns.Fire("CHANGES_READ")
end

function Changes.MarkAllRead()
    for _, it in ipairs(Changes.All()) do ns.db.global.changesRead[it.id] = true end
    ns.Fire("CHANGES_READ")
end

function Changes.Generated()
    return ns.Data.Changes and ns.Data.Changes.generated
end
