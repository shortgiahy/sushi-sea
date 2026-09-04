-- FishSpecies: shared fish data the client needs for UI (species name, rarity tier); no prices here, see FishTable
--
-- Placeholder gray-box catalog for M3 (five species, three rarity tiers) — deliberately NOT the
-- ~10-species authored table PRD §5/M5 calls for. M3 only needs enough identity data to resolve
-- "what got caught"; base_price belongs in FishTable.lua and is explicitly out of scope until
-- M5 wires the economy faucet. catchWeight drives FishingCatch's weighted species roll — it is a
-- catch-probability weight, not a value multiplier, so it stays here rather than in FishTable.
--
-- M4 addition: prepTier/loinCount/maxYield, per the locked cook verb (docs/design/cook-verb.md
-- §2.3/§4.2). This is identity/shape data the client needs to drive BoatCookController's UI
-- (how many stroke stages to show, how long the trace runs) — the same reasoning that already
-- puts catchWeight here rather than in FishTable. Placeholder gray-box numbers: common species
-- are "quick" tier (no stage two, per the design doc), uncommon/rare are "full" tier with a
-- loinCount roughly scaled to real tuna/opah primal-cut anatomy. Not yet validated against play.
local FishSpecies = {}

export type RarityTier = "common" | "uncommon" | "rare" | "legendary"
export type PrepTier = "quick" | "full"

export type SpeciesEntry = {
    id: string,
    displayName: string,
    rarity: RarityTier,
    catchWeight: number,
    prepTier: PrepTier,
    loinCount: number, -- 0 for quick tier; stage-two stroke count for full tier
    maxYield: number, -- level-independent portion ceiling (docs/design/cook-verb.md §4.2)
}

FishSpecies.SPECIES = {
    {
        id = "mackerel",
        displayName = "Mackerel",
        rarity = "common",
        catchWeight = 40,
        prepTier = "quick",
        loinCount = 0,
        maxYield = 2,
    },
    {
        id = "sea_bream",
        displayName = "Sea Bream",
        rarity = "common",
        catchWeight = 35,
        prepTier = "quick",
        loinCount = 0,
        maxYield = 2,
    },
    {
        id = "yellowtail",
        displayName = "Yellowtail",
        rarity = "uncommon",
        catchWeight = 15,
        prepTier = "full",
        loinCount = 2,
        maxYield = 4,
    },
    {
        id = "tuna",
        displayName = "Tuna",
        rarity = "rare",
        catchWeight = 7,
        prepTier = "full",
        loinCount = 4,
        maxYield = 8,
    },
    {
        id = "opah",
        displayName = "Opah",
        rarity = "rare",
        catchWeight = 3,
        prepTier = "full",
        loinCount = 3,
        maxYield = 6,
    },
    -- M14 addition: the first legendary (PRD §4 "Legendary creatures"). catchWeight = 0 is
    -- deliberate — FishingCatch.rollCatch's weighted table must never roll this normally; it's
    -- only reachable through EconomyService's separate weather-triggered legendary path
    -- (WeatherRoll.shouldTriggerLegendary), never as a random outcome of an ordinary cast.
    {
        id = "kraken",
        displayName = "Kraken",
        rarity = "legendary",
        catchWeight = 0,
        prepTier = "full",
        loinCount = 6,
        maxYield = 12,
    },
}

function FishSpecies.getById(id: string): SpeciesEntry?
    for _, entry in FishSpecies.SPECIES do
        if entry.id == id then
            return entry
        end
    end
    return nil
end

return FishSpecies
