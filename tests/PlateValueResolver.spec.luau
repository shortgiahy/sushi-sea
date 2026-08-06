-- Headless tests for PlateValueResolver (PRD §5): the served_plate_value formula's four
-- multiplier terms and their clamps. Pure module, no Roblox globals — runs under Lune exactly
-- like ConversionModule.spec.luau.
local PlateValueResolver = require("../src/server/ServerStorage/Modules/PlateValueResolver")

local TUNING = {
    MAX_COOKING_LEVEL_FOR_EXTRACTION = 10,
    CLAMP_FRESHNESS_MIN = 0.5,
    CLAMP_FRESHNESS_MAX = 1.5,
    FRESHNESS_DECAY_WINDOW_SECONDS = 600,
    DRY_AGE_MUTATION_BASELINE = 1.0,
}

-- cooking_extraction: clamps to [0, 1] and scales linearly with level/maxLevel.
do
    local _, lowLevel =
        PlateValueResolver.resolve({ cutBase = 10, cookingLevel = 1, freshnessElapsedSeconds = 0 }, TUNING)
    assert(lowLevel.cookingExtraction == 0.1, "level 1 of 10 must resolve to extraction 0.1")

    local _, maxLevel =
        PlateValueResolver.resolve({ cutBase = 10, cookingLevel = 10, freshnessElapsedSeconds = 0 }, TUNING)
    assert(maxLevel.cookingExtraction == 1.0, "max level must resolve to extraction 1.0")

    local _, aboveCap =
        PlateValueResolver.resolve({ cutBase = 10, cookingLevel = 999, freshnessElapsedSeconds = 0 }, TUNING)
    assert(aboveCap.cookingExtraction == 1.0, "above-cap level must clamp extraction to 1.0, never exceed it")
    print("PlateValueResolver.spec: cooking_extraction OK")
end

-- freshness_polish: max at zero elapsed, min at/after the decay window, linear and monotonic
-- non-increasing in between, clamped flat past the window rather than continuing to fall.
do
    local _, atZero =
        PlateValueResolver.resolve({ cutBase = 10, cookingLevel = 10, freshnessElapsedSeconds = 0 }, TUNING)
    assert(atZero.freshnessPolish == 1.5, "zero elapsed must resolve to CLAMP_FRESHNESS_MAX")

    local _, atWindow =
        PlateValueResolver.resolve({ cutBase = 10, cookingLevel = 10, freshnessElapsedSeconds = 600 }, TUNING)
    assert(atWindow.freshnessPolish == 0.5, "elapsed at the decay window must resolve to CLAMP_FRESHNESS_MIN")

    local _, pastWindow =
        PlateValueResolver.resolve({ cutBase = 10, cookingLevel = 10, freshnessElapsedSeconds = 6000 }, TUNING)
    assert(pastWindow.freshnessPolish == 0.5, "elapsed past the decay window must clamp flat, not go negative")

    local _, mid =
        PlateValueResolver.resolve({ cutBase = 10, cookingLevel = 10, freshnessElapsedSeconds = 300 }, TUNING)
    assert(
        mid.freshnessPolish > 0.5 and mid.freshnessPolish < 1.5,
        "a mid-window elapsed must sit strictly between the clamps"
    )
    print("PlateValueResolver.spec: freshness_polish OK")
end

-- dry_age_mutation: defaults to the tuning baseline when the caller supplies no roll (M5 scope —
-- no aging locker exists yet), and passes an explicit override straight through unclamped by this
-- module (M15's job to clamp its own roll before handing it in).
do
    local _, defaulted =
        PlateValueResolver.resolve({ cutBase = 10, cookingLevel = 10, freshnessElapsedSeconds = 0 }, TUNING)
    assert(defaulted.dryAgeMutation == 1.0, "an omitted dryAgeMutation must default to DRY_AGE_MUTATION_BASELINE")

    local _, overridden = PlateValueResolver.resolve(
        { cutBase = 10, cookingLevel = 10, freshnessElapsedSeconds = 0, dryAgeMutation = 2.0 },
        TUNING
    )
    assert(overridden.dryAgeMutation == 2.0, "an explicit dryAgeMutation must pass through unchanged")
    print("PlateValueResolver.spec: dry_age_mutation OK")
end

-- resolve: the returned plateValue is the product of the four breakdown terms — no term is
-- computed on the client, this is the sole place the multiplication happens (PRD §5 anti-spoof).
do
    local plateValue, breakdown = PlateValueResolver.resolve(
        { cutBase = 40, cookingLevel = 10, freshnessElapsedSeconds = 0, dryAgeMutation = 2.0 },
        TUNING
    )
    local expected = breakdown.cutBase
        * breakdown.cookingExtraction
        * breakdown.freshnessPolish
        * breakdown.dryAgeMutation
    assert(math.abs(plateValue - expected) < 1e-9, "plateValue must equal the product of the four breakdown terms")
    assert(math.abs(plateValue - 120) < 1e-9, "40 * 1.0 * 1.5 * 2.0 must resolve to 120")
    print("PlateValueResolver.spec: resolve multiplies the four terms correctly OK")
end

print("PlateValueResolver.spec: all assertions passed")
