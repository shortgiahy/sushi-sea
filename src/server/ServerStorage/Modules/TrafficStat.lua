-- TrafficStat: Yelp prestige → star rating, and the hidden traffic-stat multiplier (M12, PRD §12
-- Thread #6: "Yelp prestige formula" + "hidden traffic stat formula")
--
-- Not in PRD §7.1's file list — same "pure logic needs to be headlessly testable" deviation every
-- other pure module in this repo already makes. CustomerService.server.lua is the sole caller: it
-- reads `starsFor` to display the Yelp rating and to feed `multiplierFor`, which scales the
-- customer spawn interval (PRD §4: volume "driven by the hidden traffic stat").
local TrafficStat = {}

export type TrafficTuning = {
    PRESTIGE_POINTS_PER_STAR: number,
    MAX_STARS: number,
    PRESTIGE_WEIGHT: number,
    HOSPITALITY_WEIGHT: number,
    COSMETICS_WEIGHT: number,
    MAX_HOSPITALITY_LEVEL_FOR_TRAFFIC: number,
    MIN_TRAFFIC_MULTIPLIER: number,
    MAX_TRAFFIC_MULTIPLIER: number,
}

-- Prestige never drops (PRD §4 Rating) — this function only ever reads an already-only-increasing
-- value, it doesn't enforce the invariant itself; CustomerService never subtracts from
-- `restaurant.prestigePoints`. Stars are a continuous float (real Yelp-style ratings show
-- fractions), starting at 1 and climbing linearly, clamped at MAX_STARS.
function TrafficStat.starsFor(prestigePoints: number, tuning: TrafficTuning): number
    local stars = 1 + (prestigePoints / math.max(tuning.PRESTIGE_POINTS_PER_STAR, 1e-6))
    return math.clamp(stars, 1, tuning.MAX_STARS)
end

-- multiplier = 1 + weighted normalized inputs, clamped to [MIN, MAX]. `cosmeticsScore` is a [0,1]
-- input the caller supplies — always 0 today since no cosmetics system exists yet, same "wired but
-- inert until that system lands" status WAGE_RATE carried before M11.
function TrafficStat.multiplierFor(
    stars: number,
    hospitalityLevel: number,
    cosmeticsScore: number,
    tuning: TrafficTuning
): number
    local starFraction = math.clamp((stars - 1) / math.max(tuning.MAX_STARS - 1, 1e-6), 0, 1)
    local hospitalityFraction =
        math.clamp((hospitalityLevel - 1) / math.max(tuning.MAX_HOSPITALITY_LEVEL_FOR_TRAFFIC - 1, 1e-6), 0, 1)
    local cosmeticsFraction = math.clamp(cosmeticsScore, 0, 1)

    local multiplier = 1
        + tuning.PRESTIGE_WEIGHT * starFraction
        + tuning.HOSPITALITY_WEIGHT * hospitalityFraction
        + tuning.COSMETICS_WEIGHT * cosmeticsFraction

    return math.clamp(multiplier, tuning.MIN_TRAFFIC_MULTIPLIER, tuning.MAX_TRAFFIC_MULTIPLIER)
end

return TrafficStat
