-- Headless tests for DryAgingLocker (PRD §4 "Dry aging"): the aging curve and rare mutation roll.
-- Pure module, no Roblox globals — runs under Lune exactly like StaffPerformance.spec.luau.
local DryAgingLocker = require("../src/server/ServerStorage/Modules/DryAgingLocker")

local TUNING = {
    PEAK_MULTIPLIER = 1.5,
    PEAK_SECONDS = 6 * 3600,
    MUTATION_CHANCE = 0.05,
    MIN_MUTATION_BONUS = 1.05,
    MAX_MUTATION_BONUS = 1.5,
}

-- agingMultiplierFor: 1.0 at zero elapsed, climbs to PEAK_MULTIPLIER at PEAK_SECONDS, clamps flat
-- past it — never ruins, never keeps climbing.
do
    local atZero = DryAgingLocker.agingMultiplierFor(0, TUNING)
    assert(atZero == 1.0, "zero elapsed must resolve to exactly 1.0 (no aging bonus yet)")

    local atPeak = DryAgingLocker.agingMultiplierFor(TUNING.PEAK_SECONDS, TUNING)
    assert(math.abs(atPeak - 1.5) < 1e-9, "elapsed at PEAK_SECONDS must resolve to exactly PEAK_MULTIPLIER")

    local pastPeak = DryAgingLocker.agingMultiplierFor(TUNING.PEAK_SECONDS * 10, TUNING)
    assert(math.abs(pastPeak - 1.5) < 1e-9, "elapsed past PEAK_SECONDS must clamp flat, never exceed PEAK_MULTIPLIER")

    local midway = DryAgingLocker.agingMultiplierFor(TUNING.PEAK_SECONDS / 2, TUNING)
    assert(midway > 1.0 and midway < 1.5, "a mid-window elapsed must sit strictly between the two bounds")
    print("DryAgingLocker.spec: agingMultiplierFor OK")
end

-- rollMutationBonus: a "did it happen" roll at/above MUTATION_CHANCE must never mutate.
do
    local bonus = DryAgingLocker.rollMutationBonus(TUNING, function()
        return 0.5 -- >= 0.05, must not mutate
    end)
    assert(bonus == 1.0, "a roll at/above MUTATION_CHANCE must resolve to no mutation (1.0)")
    print("DryAgingLocker.spec: rollMutationBonus no-mutation OK")
end

-- rollMutationBonus: a "did it happen" roll below MUTATION_CHANCE mutates, magnitude drawn from
-- the second roll within [MIN_MUTATION_BONUS, MAX_MUTATION_BONUS].
do
    local calls = 0
    local rolls = { 0.01, 0.5 } -- first roll triggers the mutation, second picks the midpoint magnitude
    local bonus = DryAgingLocker.rollMutationBonus(TUNING, function()
        calls += 1
        return rolls[calls]
    end)
    local expectedMidpoint = TUNING.MIN_MUTATION_BONUS + 0.5 * (TUNING.MAX_MUTATION_BONUS - TUNING.MIN_MUTATION_BONUS)
    assert(
        math.abs(bonus - expectedMidpoint) < 1e-9,
        "a triggered mutation must draw its magnitude from the second roll"
    )
    assert(bonus >= TUNING.MIN_MUTATION_BONUS and bonus <= TUNING.MAX_MUTATION_BONUS, "magnitude must stay in range")
    print("DryAgingLocker.spec: rollMutationBonus mutation-triggered OK")
end

-- resolveDryAgeMutation: combines the aging curve and the mutation roll multiplicatively.
do
    local combined = DryAgingLocker.resolveDryAgeMutation(TUNING.PEAK_SECONDS, TUNING, function()
        return 0.99 -- never mutates
    end)
    assert(math.abs(combined - 1.5) < 1e-9, "at peak aging with no mutation, the result must equal PEAK_MULTIPLIER")
    print("DryAgingLocker.spec: resolveDryAgeMutation OK")
end

print("DryAgingLocker.spec: all assertions passed")
