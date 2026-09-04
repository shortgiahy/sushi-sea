-- PlateValueResolver: served_plate_value = cut_base × cooking_extraction × freshness_polish ×
-- dry_age_mutation (PRD §5). EconomyService looks up cutBase from FishTable and cookingLevel/
-- portion age from PlayerData, then calls this; kept pure (no Roblox globals, no `require` of
-- ReplicatedStorage/ServerStorage config) so it's headlessly testable under Lune exactly like
-- FishingCatch.lua and ConversionModule.lua already are — tuning is passed in explicitly instead.
--
-- Not in PRD §7.1's file list, same deviation FishingCatch.lua/PlayerDataAccess.lua already made
-- and documented: PRD §7.1 names EconomyService.server.lua as the owner of "plate value
-- resolution," but the actual arithmetic needs to run outside a live Roblox instance to be
-- testable, so it lives in its own pure module and EconomyService.server.lua is the sole caller.
local PlateValueResolver = {}

export type PlateValueInputs = {
    cutBase: number,
    cookingLevel: number,
    freshnessElapsedSeconds: number,
    dryAgeMutation: number?, -- nil until M15's aging locker exists; resolves to the tuning baseline
}

export type PlateValueTuning = {
    MAX_COOKING_LEVEL_FOR_EXTRACTION: number,
    CLAMP_FRESHNESS_MIN: number,
    CLAMP_FRESHNESS_MAX: number,
    FRESHNESS_DECAY_WINDOW_SECONDS: number,
    DRY_AGE_MUTATION_BASELINE: number,
}

export type PlateValueBreakdown = {
    cutBase: number,
    cookingExtraction: number,
    freshnessPolish: number,
    dryAgeMutation: number,
}

-- cooking_extraction (PRD §5): cookingLevel / MAX_LEVEL, clamped [0, 1] — novice and (a
-- hypothetical) above-cap level both floor/ceiling here rather than producing an out-of-band
-- multiplier.
local function _resolveCookingExtraction(cookingLevel: number, tuning: PlateValueTuning): number
    local maxLevel = math.max(tuning.MAX_COOKING_LEVEL_FOR_EXTRACTION, 1)
    return math.clamp(cookingLevel / maxLevel, 0, 1)
end

-- freshness_polish (PRD §5): linear from the portion's own clock. CLAMP_FRESHNESS_MAX at zero
-- elapsed, decaying to CLAMP_FRESHNESS_MIN by FRESHNESS_DECAY_WINDOW_SECONDS, clamped flat beyond
-- the window — see EconomyConfig.lua's header for why this placeholder curve exists ahead of M6's
-- real SpoilageService tick.
local function _resolveFreshnessPolish(elapsedSeconds: number, tuning: PlateValueTuning): number
    local window = math.max(tuning.FRESHNESS_DECAY_WINDOW_SECONDS, 1e-6)
    local t = math.clamp(elapsedSeconds / window, 0, 1)
    local polish = tuning.CLAMP_FRESHNESS_MAX - t * (tuning.CLAMP_FRESHNESS_MAX - tuning.CLAMP_FRESHNESS_MIN)
    return math.clamp(polish, tuning.CLAMP_FRESHNESS_MIN, tuning.CLAMP_FRESHNESS_MAX)
end

-- The canonical plate-value resolution (PRD §5). Returns the resolved cash value plus a breakdown
-- of the four multiplier terms — safe to send to the client for receipt display (PRD §7.2's
-- Economy_PlateResolved schema) because it's already-resolved output, not a component the client
-- could spoof; the anti-spoof invariant (PRD §5) is about computation authority, not display data.
function PlateValueResolver.resolve(inputs: PlateValueInputs, tuning: PlateValueTuning): (number, PlateValueBreakdown)
    local cookingExtraction = _resolveCookingExtraction(inputs.cookingLevel, tuning)
    local freshnessPolish = _resolveFreshnessPolish(inputs.freshnessElapsedSeconds, tuning)
    local dryAgeMutation = inputs.dryAgeMutation or tuning.DRY_AGE_MUTATION_BASELINE

    local plateValue = inputs.cutBase * cookingExtraction * freshnessPolish * dryAgeMutation

    local breakdown: PlateValueBreakdown = {
        cutBase = inputs.cutBase,
        cookingExtraction = cookingExtraction,
        freshnessPolish = freshnessPolish,
        dryAgeMutation = dryAgeMutation,
    }

    return plateValue, breakdown
end

return PlateValueResolver
