-- Post-fight summary: what you cast and mana tips.
-- Uses UNIT_SPELLCAST_SUCCEEDED for the player only (no combat log). If the
-- client hides spell ids as secret values in combat, those casts are counted as
-- "hidden" and the summary says so instead of guessing.
local _, ns = ...

local Summary = {}
ns.Summary = Summary

local fight

function Summary.Start(now, manaPct)
    fight = { start = now, manaStart = manaPct, casts = {}, order = {}, hidden = 0 }
end

function Summary.OnCast(spellID, name)
    if not fight then return end
    if spellID == nil or ns.Auras.IsSecret(spellID) then
        fight.hidden = fight.hidden + 1
        return
    end
    name = name or ns.Auras.SpellName(spellID) or tostring(spellID)
    if not fight.casts[name] then
        fight.casts[name] = 0
        table.insert(fight.order, name)
    end
    fight.casts[name] = fight.casts[name] + 1
end

-- Rule-based tips. Each tip references a mechanic in content/learn.json.
-- knows(name) is injectable for tests.
function Summary.Tips(f, spec, context, knows)
    knows = knows or function(name) return ns.Progress.Knows(name) end
    local tips = {}
    local dur = f.duration or 0
    local used = f.manaStart and f.manaEnd and (f.manaStart - f.manaEnd) or nil
    local c = f.casts
    local function n(name) return c[name] or 0 end
    if spec == "Retribution" and dur >= 12 then
        if n("Judgement") == 0 and knows("Judgement") then
            table.insert(tips, "No Judgement this fight. In Forever, Judgement doesn't use up your Seal: use it on cooldown.")
        end
        if n("Holy Strike") == 0 and knows("Holy Strike") then
            table.insert(tips, "No Holy Strike. It's instant Holy damage on a short cooldown: press it every time it's ready.")
        end
    end
    if spec == "Protection" and dur >= 10 and n("Consecration") == 0 and knows("Consecration") and context ~= "solo" then
        table.insert(tips, "No Consecration. On 4 or fewer targets it's your best threat on a pack, when your mana allows.")
    end
    local sealCasts = 0
    for name, count in pairs(c) do if name:find("^Seal of ") then sealCasts = sealCasts + count end end
    if dur > 0 and dur < 30 and sealCasts >= 3 then
        table.insert(tips, "Seal cast " .. sealCasts .. " times in a short fight. Don't refresh your Seal early; it lasts.")
    end
    if f.manaEnd and f.manaEnd < 20 then
        if spec == "Holy" then
            table.insert(tips, "Mana ended under 20%. Flash of Light is cheaper than Holy Light; let Illumination crits refund mana and stop casting for 5 seconds when you can.")
        elseif knows("Seal of Wisdom") then
            table.insert(tips, "Mana ended under 20%. Judge Seal of Wisdom for mana back, and skip Consecration on single enemies.")
        else
            table.insert(tips, "Mana ended under 20%. Skip Consecration on single enemies and let the five-second rule work between pulls.")
        end
    elseif spec == "Retribution" and f.manaEnd and f.manaEnd > 70 and context == "solo" and knows("Holy Light") then
        table.insert(tips, "Lots of mana left: heal yourself up with Holy Light between pulls instead of eating.")
    end
    if used and used > 0 and dur > 0 and #tips == 0 then
        table.insert(tips, ("Mana used: %.0f%% over %ds. Nice and tidy."):format(used, dur))
    end
    if f.hidden > 0 then
        table.insert(tips, ("%d cast(s) were hidden by the client's addon restrictions and aren't counted."):format(f.hidden))
    end
    return tips
end

function Summary.Finish(now, manaPct)
    if not fight then return nil end
    local f = fight
    fight = nil
    f.duration = math.floor((now - f.start) + 0.5)
    f.manaEnd = manaPct
    local total = 0
    for _, v in pairs(f.casts) do total = total + v end
    if f.duration < 4 or (total == 0 and f.hidden == 0) then return nil end
    local spec = ns.DB.ActiveSpec()
    f.tips = Summary.Tips(f, spec, ns.DB.Profile().rotationContext, nil)
    Summary.last = f
    return f
end

function Summary.Text(f)
    local parts = {}
    table.sort(f.order, function(a, b) return f.casts[a] > f.casts[b] end)
    for _, name in ipairs(f.order) do table.insert(parts, name .. " x" .. f.casts[name]) end
    return table.concat(parts, ", ")
end
