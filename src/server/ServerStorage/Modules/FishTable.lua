-- FishTable: authored species -> cut_base[grade] cash lookup (PRD §5/§7.1). Hand-set values,
-- never computed — EconomyService is the only reader, via PlateValueResolver's `cutBase` input.
--
-- M5 scope: covers the five species FishSpecies.lua currently has (that file's header already
-- flags its gray-box roster as deliberately short of PRD §5's ~10-species/30-row target) —
-- growing the roster is a content-authoring pass that arrives with new species, not something to
-- fabricate species for here just to hit a row count. Every value below is a placeholder starting
-- guess (same status as FishingConfig.lua/CookConfig.lua), loosely scaled by catch rarity
-- (FishSpecies.catchWeight — rarer species worth more) and grade (otoro > chutoro > akami, per
-- the M0 cook-verb lock), pending Giahy's M7 numbers session.
local FishTable = {}

export type Grade = "otoro" | "chutoro" | "akami"
export type CutBaseRow = { otoro: number, chutoro: number, akami: number }

FishTable.CUT_BASE = {
    mackerel = { otoro = 18, chutoro = 12, akami = 7 },
    sea_bream = { otoro = 20, chutoro = 13, akami = 8 },
    yellowtail = { otoro = 42, chutoro = 28, akami = 16 },
    tuna = { otoro = 96, chutoro = 64, akami = 36 },
    opah = { otoro = 120, chutoro = 80, akami = 45 },
    -- M14: the legendary tier — a Kraken plate is meant to feel like a windfall, priced well above
    -- anything the ordinary weighted catch table can produce.
    kraken = { otoro = 400, chutoro = 260, akami = 150 },
}

function FishTable.cutBaseFor(speciesId: string, grade: Grade): number?
    local row = FishTable.CUT_BASE[speciesId]
    return row and row[grade]
end

return FishTable
