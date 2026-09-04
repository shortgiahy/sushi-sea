-- Headless tests for SpoilageCalculator (PRD §4 "the leash: perishability"): the basic
-- fresh/stale/spoiled threshold classification and its display-only freshnessFraction. Pure
-- module, no Roblox globals — runs under Lune exactly like PlateValueResolver.spec.luau.
local SpoilageCalculator = require("../src/server/ServerStorage/Modules/SpoilageCalculator")

local TUNING = {
    STALE_AFTER_SECONDS = 300,
    SPOILED_AFTER_SECONDS = 600,
}

-- classify: fresh below the stale threshold, stale between the two thresholds, spoiled at/after
-- the spoiled threshold.
do
    local stateAtZero, fractionAtZero = SpoilageCalculator.classify(0, TUNING)
    assert(stateAtZero == "fresh", "zero elapsed must be fresh")
    assert(fractionAtZero == 1.0, "zero elapsed must resolve to freshnessFraction 1.0")

    local stateJustBeforeStale = SpoilageCalculator.classify(299, TUNING)
    assert(stateJustBeforeStale == "fresh", "just before the stale threshold must still be fresh")

    local stateAtStale = SpoilageCalculator.classify(300, TUNING)
    assert(stateAtStale == "stale", "at the stale threshold must be stale")

    local stateJustBeforeSpoiled = SpoilageCalculator.classify(599, TUNING)
    assert(stateJustBeforeSpoiled == "stale", "just before the spoiled threshold must still be stale, not spoiled")

    local stateAtSpoiled, fractionAtSpoiled = SpoilageCalculator.classify(600, TUNING)
    assert(stateAtSpoiled == "spoiled", "at the spoiled threshold must be spoiled")
    assert(fractionAtSpoiled == 0.0, "at the spoiled threshold freshnessFraction must be 0.0")

    local stateWellPastSpoiled, fractionWellPastSpoiled = SpoilageCalculator.classify(6000, TUNING)
    assert(stateWellPastSpoiled == "spoiled", "well past the spoiled threshold must still be spoiled")
    assert(fractionWellPastSpoiled == 0.0, "freshnessFraction must clamp at 0.0, never negative")

    print("SpoilageCalculator.spec: classify state transitions OK")
end

-- freshnessFraction is linear and monotonic non-increasing between zero elapsed and the spoiled
-- threshold.
do
    local _, midFraction = SpoilageCalculator.classify(300, TUNING)
    assert(
        midFraction > 0 and midFraction < 1,
        "a mid-window elapsed must sit strictly between the freshnessFraction bounds"
    )

    local _, earlierFraction = SpoilageCalculator.classify(100, TUNING)
    local _, laterFraction = SpoilageCalculator.classify(400, TUNING)
    assert(earlierFraction > laterFraction, "freshnessFraction must strictly decrease as elapsed time grows")

    print("SpoilageCalculator.spec: freshnessFraction OK")
end

print("SpoilageCalculator.spec: all assertions passed")
