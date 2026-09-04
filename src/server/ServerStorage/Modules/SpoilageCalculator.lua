-- SpoilageCalculator: pure freshness classification for raw inventory fish and cooked portions
-- (PRD §4 "the leash: perishability"). Not in PRD §7.1's file list — same deviation
-- FishingCatch.lua/PlateValueResolver.lua already made and documented: the classification needs
-- to be headlessly testable under Lune, so it lives in its own pure module and
-- SpoilageService.server.lua is the sole caller.
--
-- M6 scope: the "basic" tick per the module table (PRD §6) — a two-threshold classification
-- (fresh -> stale -> spoiled) with a linearly-interpolated freshnessFraction for UI display. Real
-- decay rates, storage-tier slowdown, and the full otoro/chutoro/akami grade-downgrade chain (PRD
-- §4's "Expiry downgrades, it does not destroy") are M8 scope, explicitly deferred — this module
-- only decides when something is tossed, not how a portion's grade steps down first.
local SpoilageCalculator = {}

export type SpoilageState = "fresh" | "stale" | "spoiled"

export type SpoilageTuning = {
    STALE_AFTER_SECONDS: number,
    SPOILED_AFTER_SECONDS: number,
}

-- freshnessFraction: 1.0 at zero elapsed, 0.0 at/after SPOILED_AFTER_SECONDS, linear between —
-- display-only (FreshnessUI mirrors this, never recomputes it), not an economy value.
function SpoilageCalculator.classify(elapsedSeconds: number, tuning: SpoilageTuning): (SpoilageState, number)
    local spoiledAfter = math.max(tuning.SPOILED_AFTER_SECONDS, 1e-6)
    local fraction = math.clamp(1 - (elapsedSeconds / spoiledAfter), 0, 1)

    local state: SpoilageState
    if elapsedSeconds >= tuning.SPOILED_AFTER_SECONDS then
        state = "spoiled"
    elseif elapsedSeconds >= tuning.STALE_AFTER_SECONDS then
        state = "stale"
    else
        state = "fresh"
    end

    return state, fraction
end

return SpoilageCalculator
