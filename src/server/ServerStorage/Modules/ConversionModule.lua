-- ConversionModule: cook(fish, performance) -> portions, the ONE conversion implementation; boat verb and staff AI both call this,
-- never duplicate it (PRD §7.6)
--
-- M4 scope: yield + grade resolution per the locked cook verb (docs/design/cook-verb.md §4.2,
-- §4.3) — the two-stage manual verb (butchery trace -> yield, slicing stroke -> grade per loin).
-- Plate *value* in cash is explicitly out of scope here (PRD §6 names that M5, once FishTable's
-- cut_base[species][grade] lookup exists); this module only produces portions (a yield count with
-- a grade label each), never a price.
--
-- Pure, no Roblox globals — species/performance/tuning are all passed in explicitly rather than
-- required from ReplicatedStorage/ServerStorage, the same dependency-injection call FishingCatch.lua
-- already made and documented (its "no Roblox globals" section): ReplicatedStorage-hosted config
-- is unreachable under the headless Lune test runner (tests/ConversionModule.spec.luau), and DI is
-- simpler here than a runtime-detection branch.
local ConversionModule = {}

export type PrepTier = "quick" | "full"
export type Grade = "otoro" | "chutoro" | "akami"

export type SpeciesCookData = {
    prepTier: PrepTier,
    loinCount: number,
    maxYield: number,
}

export type CookPerformance = {
    traceAccuracy: number, -- [0, 1]
    strokeQuality: { number }, -- one entry per loin, [0, 1]; ignored for quick-tier
}

export type Portion = { grade: Grade }

export type GradeBand = { minQuality: number, grade: Grade }

export type CookTuning = {
    FLOOR_FRAC_AT_LEVEL_1: number,
    FLOOR_FRAC_AT_MAX_LEVEL: number,
    MAX_COOKING_LEVEL_FOR_EXTRACTION: number,
    GRADE_BANDS: { GradeBand },
}

local BASE_GRADE: Grade = "akami"

local function _clamp01(value: number): number
    if type(value) ~= "number" or value ~= value then -- NaN ~= NaN
        return 0
    end
    return math.clamp(value, 0, 1)
end

-- floorFrac (docs/design/cook-verb.md §4.2): level raises the worst-case floor and never the
-- ceiling. floorFrac(1) = FLOOR_FRAC_AT_LEVEL_1, floorFrac(MAX) = FLOOR_FRAC_AT_MAX_LEVEL, linear
-- between. Cooking level always clamps to >= 1 — a corrupt/missing save should degrade to the
-- worst legitimate floor, not extrapolate below it.
function ConversionModule.floorFrac(cookingLevel: number, tuning: CookTuning): number
    local maxLevel = math.max(tuning.MAX_COOKING_LEVEL_FOR_EXTRACTION, 1)
    local level = math.max(cookingLevel, 1)
    local t = _clamp01((level - 1) / math.max(maxLevel - 1, 1))
    return tuning.FLOOR_FRAC_AT_LEVEL_1 + (tuning.FLOOR_FRAC_AT_MAX_LEVEL - tuning.FLOOR_FRAC_AT_LEVEL_1) * t
end

-- Yield (docs/design/cook-verb.md §4.2): bounded convergence, not compounding — traceAccuracy
-- lerps between the level's floor and the species' authored ceiling, and the ceiling never moves.
-- Never zero, per the design doc: a botched cut returns a fraction of species max, not nothing.
function ConversionModule.resolveYield(
    species: SpeciesCookData,
    traceAccuracy: number,
    cookingLevel: number,
    tuning: CookTuning
): number
    local accuracy = _clamp01(traceAccuracy)
    local floor = _clamp01(ConversionModule.floorFrac(cookingLevel, tuning))
    local fraction = floor + (1 - floor) * accuracy
    local yieldCount = math.round(species.maxYield * fraction)
    return math.max(1, yieldCount)
end

-- Grade (docs/design/cook-verb.md §4.3): GRADE_BANDS must end in a minQuality = 0 band, so this
-- always resolves to at least "akami" — there is no grade below akami and no "inedible" result.
function ConversionModule.gradeFor(strokeQuality: number, tuning: CookTuning): Grade
    local quality = _clamp01(strokeQuality)
    for _, band in tuning.GRADE_BANDS do
        if quality >= band.minQuality then
            return band.grade
        end
    end
    return BASE_GRADE
end

-- Spreads yieldCount portions evenly across loinGrades (one grade per loin, per §2's "grade is
-- per loin" split from yield being per-fish). Quick-tier (no loins) floors every portion at
-- BASE_GRADE, matching §2.3's "portions come off at base grade. No stage two."
local function _distributePortions(yieldCount: number, loinGrades: { Grade }): { Portion }
    local portions: { Portion } = {}
    local loinCount = #loinGrades

    if loinCount == 0 then
        for _ = 1, yieldCount do
            table.insert(portions, { grade = BASE_GRADE })
        end
        return portions
    end

    for i = 0, yieldCount - 1 do
        local loinIndex = math.floor(i * loinCount / yieldCount) + 1
        table.insert(portions, { grade = loinGrades[loinIndex] })
    end
    return portions
end

-- The canonical conversion (PRD §7.6). `species` is the caller's authoritative lookup of the fish
-- being cooked (EconomyService resolves this from FishSpecies by the fish's *server-known*
-- species, never trusting a client-sent species string — see EconomyService.server.lua).
function ConversionModule.cook(
    species: SpeciesCookData,
    performance: CookPerformance,
    cookingLevel: number,
    tuning: CookTuning
): { Portion }
    local yieldCount = ConversionModule.resolveYield(species, performance.traceAccuracy, cookingLevel, tuning)

    if species.prepTier == "quick" or species.loinCount <= 0 then
        return _distributePortions(yieldCount, {})
    end

    local loinGrades: { Grade } = {}
    for i = 1, species.loinCount do
        local quality = performance.strokeQuality[i]
        table.insert(loinGrades, ConversionModule.gradeFor(if type(quality) == "number" then quality else 0, tuning))
    end

    return _distributePortions(yieldCount, loinGrades)
end

return ConversionModule
