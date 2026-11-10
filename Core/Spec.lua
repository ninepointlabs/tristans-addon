-- Spec definitions: names, roles, palette, icons.
local _, ns = ...

ns.SPEC_ORDER = { "Holy", "Protection", "Retribution" }

-- Palette (brief): holy gold/white, steel blue/silver, crimson/gold. Icons are the
-- standard Paladin spec icons (the same art Blizzard's icon CDN serves).
ns.Specs = {
    Holy = {
        key = "Holy", role = "Healer",
        icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
        accent = { 1.00, 0.851, 0.420 }, accent2 = { 1.00, 0.976, 0.902 },
        tree = "Holy", weights = "Holy",
        blurb = "Holy Light, Flash of Light and Holy Shock with Illumination refunds. The battleground healer: Oath of Light and Light's Vigil on the flag carrier.",
    },
    Protection = {
        key = "Protection", role = "Tank",
        icon = "Interface\\Icons\\Spell_Holy_DevotionAura",
        accent = { 0.553, 0.698, 0.851 }, accent2 = { 0.808, 0.839, 0.871 },
        tree = "Protection", weights = "Protection",
        blurb = "Seal of Fury, Righteous Fury and Consecration. Easy dungeon groups, strong AoE leveling, Templar's Bulwark when it gets scary.",
    },
    Retribution = {
        key = "Retribution", role = "Damage",
        icon = "Interface\\Icons\\Spell_Holy_AuraOfLight",
        accent = { 0.863, 0.243, 0.290 }, accent2 = { 1.00, 0.800, 0.302 },
        tree = "Retribution", weights = "Retribution",
        blurb = "Two-hander, Seals and Judgement, Holy Strike on cooldown. A very efficient leveler and the burst spec for battlegrounds (HoJ, Repentance, Hammer of Wrath).",
    },
}

-- Tim's decision (2026-11-10): level as Retribution; at 40 make dual spec Ret (A) + Holy (B) for battlegrounds.
ns.RECOMMENDED_LEVELING_SPEC = "Retribution"
ns.RECOMMENDED_DUAL_SPEC = { A = "Retribution", B = "Holy" }

-- Neutral palette used before a spec is picked (paladin pink-gold).
ns.NeutralAccent = { 0.961, 0.549, 0.729 }
ns.NEUTRAL_ICON = "Interface\\Icons\\Spell_Holy_SealOfMight"

-- Muted "battle red", used only on the Battle screens.
ns.BattleAccent = { 0.761, 0.275, 0.247 }

function ns.SpecAccent(spec)
    local s = ns.Specs[spec or (ns.DB and ns.DB.char and ns.DB.ActiveSpec())]
    return s and s.accent or ns.NeutralAccent
end

function ns.IsHealer(spec)
    spec = spec or (ns.DB and ns.DB.char and ns.DB.ActiveSpec())
    return spec == "Holy"
end

function ns.IsTank(spec)
    spec = spec or (ns.DB and ns.DB.char and ns.DB.ActiveSpec())
    return spec == "Protection"
end
