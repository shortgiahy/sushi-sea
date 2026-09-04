-- DryAgingLocker: closed-form aging curve + rare mutation roll (PRD §7.1, §4 "Dry aging")
--
-- M15 scope: pure math only — slot management and moving fish between `inventory`/`agingLocker`
-- live in EconomyService.server.lua, same "pure module, Roblox-context glue lives in the calling
-- Service" split every other pure module in this repo already uses. `resolveDryAgeMutation` is
-- called once, at pull time (Player_PullFromLocker) — the result is stamped onto the fish's
-- `dryAgeMutation` field and carried forward through cooking onto the resulting CookedPortion, so
-- PlateValueResolver.resolve's existing optional `dryAgeMutation` input (M5) finally gets a real
-- value for an aged fish.
local DryAgingLocker = {}

export type AgingTuning = {
    PEAK_MULTIPLIER: number,
    PEAK_SECONDS: number,
    MUTATION_CHANCE: number,
    MIN_MUTATION_BONUS: number,
    MAX_MUTATION_BONUS: number,
}

-- Rises linearly from 1.0 at placement to PEAK_MULTIPLIER at PEAK_SECONDS elapsed, then holds flat
-- — "past peak, the fish doesn't ruin" (PRD §4), it just stops climbing.
function DryAgingLocker.agingMultiplierFor(agedSeconds: number, tuning: AgingTuning): number
    local t = math.clamp(agedSeconds / math.max(tuning.PEAK_SECONDS, 1e-6), 0, 1)
    return 1 + (tuning.PEAK_MULTIPLIER - 1) * t
end

-- "Rare" (MUTATION_CHANCE) and "percentage multipliers, never orders of magnitude" (PRD §4) — two
-- independent rolls (whether it happens, then how big) so magnitude isn't biased by the chance
-- roll's own distribution.
function DryAgingLocker.rollMutationBonus(tuning: AgingTuning, randomFn: (() -> number)?): number
    local didMutate = if randomFn then randomFn() else math.random()
    if didMutate >= tuning.MUTATION_CHANCE then
        return 1.0
    end

    local magnitude = if randomFn then randomFn() else math.random()
    return tuning.MIN_MUTATION_BONUS + magnitude * (tuning.MAX_MUTATION_BONUS - tuning.MIN_MUTATION_BONUS)
end

function DryAgingLocker.resolveDryAgeMutation(
    agedSeconds: number,
    tuning: AgingTuning,
    randomFn: (() -> number)?
): number
    return DryAgingLocker.agingMultiplierFor(agedSeconds, tuning) * DryAgingLocker.rollMutationBonus(tuning, randomFn)
end

return DryAgingLocker
