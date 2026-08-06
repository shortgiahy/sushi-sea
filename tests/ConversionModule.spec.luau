-- Headless tests for ConversionModule (PRD §7.6, docs/design/cook-verb.md §4.2/§4.3): the yield
-- formula, grade bands, and quick vs full tier portion resolution. Pure module, no Roblox globals
-- — runs under Lune exactly like FishingCatch.spec.luau.
local ConversionModule = require("../src/server/ServerStorage/Modules/ConversionModule")

local TUNING = {
    FLOOR_FRAC_AT_LEVEL_1 = 0.4,
    FLOOR_FRAC_AT_MAX_LEVEL = 0.85,
    MAX_COOKING_LEVEL_FOR_EXTRACTION = 10,
    GRADE_BANDS = {
        { minQuality = 0.75, grade = "otoro" },
        { minQuality = 0.4, grade = "chutoro" },
        { minQuality = 0, grade = "akami" },
    },
}

-- floorFrac: level 1 must land exactly on the authored floor, max level on the authored ceiling,
-- and values must be monotonic non-decreasing in between.
do
    assert(ConversionModule.floorFrac(1, TUNING) == 0.4, "level 1 must resolve to FLOOR_FRAC_AT_LEVEL_1")
    assert(ConversionModule.floorFrac(10, TUNING) == 0.85, "max level must resolve to FLOOR_FRAC_AT_MAX_LEVEL")
    assert(ConversionModule.floorFrac(0, TUNING) == 0.4, "below-level-1 input must clamp to the level-1 floor")
    local mid = ConversionModule.floorFrac(5, TUNING)
    assert(mid > 0.4 and mid < 0.85, "a mid-level floor must sit strictly between the level-1 and max-level floors")
    print("ConversionModule.spec: floorFrac OK")
end

-- resolveYield: never zero even at zero accuracy/level 1, and scales up toward maxYield as
-- traceAccuracy approaches 1 — the "bounded convergence, not compounding" rule from §4.2.
do
    local species = { prepTier = "full", loinCount = 2, maxYield = 4 }
    local botched = ConversionModule.resolveYield(species, 0, 1, TUNING)
    assert(botched >= 1, "a botched trace (accuracy 0) must never yield zero portions")
    local perfect = ConversionModule.resolveYield(species, 1, 1, TUNING)
    assert(perfect == 4, "a perfect trace at level 1 must reach maxYield (floor + (1-floor)*1 == 1.0)")
    assert(perfect >= botched, "higher trace accuracy must never yield fewer portions than lower accuracy")
    print("ConversionModule.spec: resolveYield OK")
end

-- resolveYield: leveling raises the floor (worse-case outcome) but never the ceiling — a perfect
-- trace at any level must still cap at maxYield.
do
    local species = { prepTier = "full", loinCount = 2, maxYield = 10 }
    local lowLevelBotch = ConversionModule.resolveYield(species, 0, 1, TUNING)
    local highLevelBotch = ConversionModule.resolveYield(species, 0, 10, TUNING)
    assert(highLevelBotch > lowLevelBotch, "a higher cooking level must raise the botched-trace floor")
    local highLevelPerfect = ConversionModule.resolveYield(species, 1, 10, TUNING)
    assert(highLevelPerfect == 10, "a perfect trace at max level must still cap at maxYield, never exceed it")
    print("ConversionModule.spec: resolveYield level-raises-floor-not-ceiling OK")
end

-- gradeFor: the band thresholds resolve as documented, and the bottom band (minQuality = 0)
-- guarantees there is no grade below akami and no "no match" case.
do
    assert(ConversionModule.gradeFor(1.0, TUNING) == "otoro", "quality 1.0 must grade as otoro")
    assert(
        ConversionModule.gradeFor(0.75, TUNING) == "otoro",
        "quality exactly at the otoro threshold must grade as otoro"
    )
    assert(ConversionModule.gradeFor(0.74, TUNING) == "chutoro", "just under the otoro threshold must grade as chutoro")
    assert(
        ConversionModule.gradeFor(0.4, TUNING) == "chutoro",
        "quality exactly at the chutoro threshold must grade as chutoro"
    )
    assert(ConversionModule.gradeFor(0.0, TUNING) == "akami", "quality 0 must grade as akami, never below")
    assert(
        ConversionModule.gradeFor(-5, TUNING) == "akami",
        "an out-of-range quality must clamp and still grade as akami, not error"
    )
    print("ConversionModule.spec: gradeFor grade-floor OK")
end

-- cook: quick-tier ignores strokeQuality entirely and floors every portion at akami — no stage
-- two, per cook-verb.md §2.3.
do
    local species = { prepTier = "quick", loinCount = 0, maxYield = 2 }
    local portions = ConversionModule.cook(species, { traceAccuracy = 1.0, strokeQuality = {} }, 1, TUNING)
    assert(#portions == 2, "a perfect quick-tier trace must yield the species' maxYield in portions")
    for _, portion in portions do
        assert(portion.grade == "akami", "every quick-tier portion must be akami — no stage two")
    end
    print("ConversionModule.spec: cook quick-tier OK")
end

-- cook: full-tier distributes yield portions across loins and each portion carries its loin's
-- grade — a fish with a perfect trace and one perfect + one botched loin should show both grades.
do
    local species = { prepTier = "full", loinCount = 2, maxYield = 4 }
    local portions = ConversionModule.cook(species, { traceAccuracy = 1.0, strokeQuality = { 1.0, 0.0 } }, 1, TUNING)
    assert(#portions == 4, "a perfect full-tier trace must yield the species' maxYield in portions")

    local grades: { [string]: number } = {}
    for _, portion in portions do
        grades[portion.grade] = (grades[portion.grade] or 0) + 1
    end
    assert(grades.otoro == 2, "the perfect loin's half of the portions must grade otoro")
    assert(grades.akami == 2, "the botched loin's half of the portions must grade akami")
    print("ConversionModule.spec: cook full-tier grade distribution OK")
end

-- cook: a missing strokeQuality entry for a loin (malformed/short client payload) must not error
-- — it degrades to a botched (akami) stroke for that loin rather than crashing the resolution.
do
    local species = { prepTier = "full", loinCount = 2, maxYield = 2 }
    local portions = ConversionModule.cook(species, { traceAccuracy = 1.0, strokeQuality = { 1.0 } }, 1, TUNING)
    assert(#portions == 2, "yield resolution must not be affected by a short strokeQuality array")
    local grades: { [string]: number } = {}
    for _, portion in portions do
        grades[portion.grade] = (grades[portion.grade] or 0) + 1
    end
    assert(grades.akami == 1, "a missing stroke entry must degrade to akami, not error")
    print("ConversionModule.spec: cook missing strokeQuality entry degrades safely OK")
end

print("ConversionModule.spec: all assertions passed")
