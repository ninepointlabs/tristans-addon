-- Settings › Reminders: live status + what to remind about.
local _, ns = ...
local UI = ns.UI

UI.SettingsSections = UI.SettingsSections or {}

UI.SettingsSections.Reminders = function(L, c)
    local cfg = ns.db.char.reminders
    L:Columns({ 0.5, 0.5 })
    L:Label("Right now")
    local list = ns.Reminders.Evaluate()
    if #list == 0 then L:Text(UI.Hex(UI.C.dim) .. "Nothing to check yet at your level.|r") end
    for _, r in ipairs(list) do
        local chip = r.ok and { text = "OK", kind = "good" } or { text = r.id == "redemption" and "Open" or "Missing", kind = "warn" }
        L:Row({ chip = chip, title = r.label, sub = r.detail })
    end
    L:Text(UI.Hex(UI.C.dim) .. "Checked out of combat; missing items pop up on screen (also /tristan remind).|r", { size = 12 })
    L:NextColumn()
    L:Label("Remind me about")
    local function check(label, key)
        L:Check(label, cfg[key], function(v) cfg[key] = v ns.Fire("REMINDERS_CHANGED") UI.Refresh() end)
    end
    check("Reminders on", "enabled")
    check("My Blessing on myself", "blessing")
    check("An Aura running", "aura")
    check("A Seal when I'm in melee range", "seal")
    check("Righteous Fury (on when tanking, off otherwise)", "righteousFury")
    check("The Redemption quest at 12", "redemption")
    L:Check("Buff before the gates open (battlegrounds)", ns.db.char.pvp.gatesReminder, function(v) ns.db.char.pvp.gatesReminder = v end,
        "When you enter a battleground: one note listing what's missing.")
    L:Note("Symbol of Kings and other Paladin reagents: no Forever source says they exist, so there's no reagent reminder.")
    L:EndColumns()
end
