local _, ns = ...
local UI = ns.UI

UI.RegisterPanel({
    key = "news", label = "What's new",
    badge = function() return ns.db and ns.Changes.UnreadCount() or 0 end,
    render = function(L, c)
        L:Title("What's new", "Forever, Paladin and PvP changes, newest first")
        L:Buttons({ { label = "Mark all read", onClick = function() ns.Changes.MarkAllRead() end } })
        local gen = ns.Changes.Generated()
        L:Note(gen and ("The companion poller last updated this list " .. gen .. ".")
            or "The companion poller (tools/paladin-changes-poller) hasn't run yet, so this shows changes from the research.")
        L:Note("Addons can't go online: the poller runs on your PC, then /reload shows new items.")
        for _, it in ipairs(ns.Changes.All()) do
            local unread = not ns.Changes.IsRead(it)
            local sub = (it.source or "") .. (it.summary and it.summary ~= "" and (" · " .. it.summary) or "")
            L:Row({ chip = unread and { text = "New", kind = "good" } or nil, title = it.title or "?", sub = sub, right = it.date or "",
                tint = unread and UI.Accent() or nil,
                onEnter = it.url and function(s)
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Click: mark read · Shift-click: copy link", 1, 1, 1)
                    GameTooltip:Show()
                end or nil,
                onClick = function()
                    ns.Changes.MarkRead(it)
                    if IsShiftKeyDown() and it.url then UI.CopyURL(it.url) end
                end })
            if it.url then L:Source({ source_url = it.url }) end
        end
    end,
})
