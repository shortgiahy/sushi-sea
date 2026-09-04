-- LegendaryFight: per-phase difficulty scaling for the legendary encounter (M14, PRD §4
-- "Legendary creatures & the encounter system": "the fight is the bite/reel loop, scaled up...
-- not a bespoke combat system — fishing turned up to 11")
--
-- Not in PRD §7.1's file list — same "pure logic needs to be headlessly testable" deviation every
-- other pure module in this repo already makes. Deliberately does NOT reimplement fight
-- simulation — EconomyService.server.lua still drives each phase through the exact same
-- FishingCatch.newFight/applyReelInput/tick functions a normal catch uses, just with a
-- phase-specific FightConfig this module computes. "Fishing level gates outcome" (PRD §4):
-- underleveled players get the full narrowed box, high-level players get most of it back.
local LegendaryFight = {}

export type LegendaryTuning = {
    PHASE_COUNT: number,
    PHASE_WIDTH_MULTIPLIER: number,
    MIN_CATCH_BOX_WIDTH: number,
    LEVEL_RELIEF_PER_LEVEL: number,
    MAX_LEVEL_RELIEF: number,
    MAX_FISHING_LEVEL_FOR_RELIEF: number,
}

-- catchBoxWidth narrows geometrically per phase (phase 1 = full base width, each phase after
-- multiplies by PHASE_WIDTH_MULTIPLIER), then Fishing level widens it back by a capped linear
-- relief — never past the base width, and never below MIN_CATCH_BOX_WIDTH regardless of level.
function LegendaryFight.catchBoxWidthFor(
    phaseIndex: number,
    fishingLevel: number,
    baseCatchBoxWidth: number,
    tuning: LegendaryTuning
): number
    local narrowed = baseCatchBoxWidth * (tuning.PHASE_WIDTH_MULTIPLIER ^ (phaseIndex - 1))

    local level = math.max(fishingLevel, 1)
    local reliefLevels = math.min(level - 1, tuning.MAX_FISHING_LEVEL_FOR_RELIEF - 1)
    local relief = math.min(reliefLevels * tuning.LEVEL_RELIEF_PER_LEVEL, tuning.MAX_LEVEL_RELIEF)

    return math.clamp(narrowed + relief, tuning.MIN_CATCH_BOX_WIDTH, baseCatchBoxWidth)
end

function LegendaryFight.isFinalPhase(phaseIndex: number, tuning: LegendaryTuning): boolean
    return phaseIndex >= tuning.PHASE_COUNT
end

return LegendaryFight
