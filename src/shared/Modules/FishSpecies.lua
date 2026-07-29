-- FishSpecies: shared fish data the client needs for UI (species name, rarity tier); no prices here, see FishTable
--
-- Placeholder gray-box catalog for M3 (five species, three rarity tiers) — deliberately NOT the
-- ~10-species authored table PRD §5/M5 calls for. M3 only needs enough identity data to resolve
-- "what got caught"; base_price belongs in FishTable.lua and is explicitly out of scope until
-- M5 wires the economy faucet. catchWeight drives FishingCatch's weighted species roll — it is a
-- catch-probability weight, not a value multiplier, so it stays here rather than in FishTable.
local FishSpecies = {}

export type RarityTier = "common" | "uncommon" | "rare"

export type SpeciesEntry = {
    id: string,
    displayName: string,
    rarity: RarityTier,
    catchWeight: number,
}

FishSpecies.SPECIES = {
    { id = "mackerel", displayName = "Mackerel", rarity = "common", catchWeight = 40 },
    { id = "sea_bream", displayName = "Sea Bream", rarity = "common", catchWeight = 35 },
    { id = "yellowtail", displayName = "Yellowtail", rarity = "uncommon", catchWeight = 15 },
    { id = "tuna", displayName = "Tuna", rarity = "rare", catchWeight = 7 },
    { id = "opah", displayName = "Opah", rarity = "rare", catchWeight = 3 },
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
