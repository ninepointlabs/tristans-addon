-- Tristan's Addon: namespace, client guard, tiny event bus.
local ADDON, ns = ...

ns.ADDON = ADDON
ns.TITLE = "Tristan's Addon"
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"

-- Forever only. WOW_PROJECT_CAMELOT (= 18) is the Forever project id per the
-- wow-ui-source forever branch; refuse to run anywhere else.
ns.FOREVER_PROJECT_ID = WOW_PROJECT_CAMELOT or 18
ns.disabled = (WOW_PROJECT_ID ~= ns.FOREVER_PROJECT_ID)

local listeners = {}
function ns.On(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end

function ns.Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok and ns.Debug then ns.Debug("listener error for " .. event .. ": " .. tostring(err)) end
    end
end

function ns.Print(msg)
    print("|cfff58cbaTristan's Addon|r: " .. tostring(msg))
end

function ns.Debug(msg)
    if ns.db and ns.db.global and ns.db.global.debug then
        print("|cff888888[TA debug]|r " .. tostring(msg))
    end
end
