-- Headless tests for TrafficStat (PRD §12 Thread #6): prestige-to-stars and the traffic multiplier.
-- Pure module, no Roblox globals — runs under Lune exactly like StaffPerformance.spec.luau.
local TrafficStat = require("../src/server/ServerStorage/Modules/TrafficStat")

local TUNING = {
    PRESTIGE_POINTS_PER_STAR = 50,
    MAX_STARS = 5,
    PRESTIGE_WEIGHT = 1.0,
    HOSPITALITY_WEIGHT = 0.5,
    COSMETICS_WEIGHT = 0.3,
    MAX_HOSPITALITY_LEVEL_FOR_TRAFFIC = 10,
    MIN_TRAFFIC_MULTIPLIER = 0.5,
    MAX_TRAFFIC_MULTIPLIER = 3.0,
}

-- starsFor: zero prestige is exactly 1 star (the floor), climbs linearly, clamps at MAX_STARS.
do
    local zero = TrafficStat.starsFor(0, TUNING)
    assert(zero == 1, "zero prestige must resolve to exactly 1 star")

    local partial = TrafficStat.starsFor(25, TUNING)
    assert(math.abs(partial - 1.5) < 1e-9, "25 prestige points at 50/star must resolve to 1.5 stars")

    local atMax = TrafficStat.starsFor(200, TUNING)
    assert(atMax == 5, "prestige reaching the top of the scale must resolve to exactly MAX_STARS")

    local pastMax = TrafficStat.starsFor(999999, TUNING)
    assert(pastMax == 5, "prestige past the top of the scale must clamp at MAX_STARS, never exceed it")
    print("TrafficStat.spec: starsFor OK")
end

-- multiplierFor: 1 star + level-1 Hospitality + no cosmetics is exactly the floor multiplier (1.0,
-- since all fractions are 0 and MIN_TRAFFIC_MULTIPLIER is below that).
do
    local baseline = TrafficStat.multiplierFor(1, 1, 0, TUNING)
    assert(math.abs(baseline - 1.0) < 1e-9, "1 star, level-1 Hospitality, 0 cosmetics must resolve to multiplier 1.0")
    print("TrafficStat.spec: multiplierFor baseline OK")
end

-- multiplierFor: max stars + max Hospitality + full cosmetics must sum all three weights, clamped
-- at MAX_TRAFFIC_MULTIPLIER if the sum would exceed it.
do
    local maxed = TrafficStat.multiplierFor(5, 10, 1, TUNING)
    local expected = 1 + TUNING.PRESTIGE_WEIGHT + TUNING.HOSPITALITY_WEIGHT + TUNING.COSMETICS_WEIGHT
    assert(
        math.abs(maxed - math.min(expected, TUNING.MAX_TRAFFIC_MULTIPLIER)) < 1e-9,
        "maxed inputs must sum all three weights (clamped)"
    )
    print("TrafficStat.spec: multiplierFor maxed inputs OK")
end

-- multiplierFor: strictly increases with stars, holding other inputs fixed.
do
    local lowStars = TrafficStat.multiplierFor(1, 1, 0, TUNING)
    local highStars = TrafficStat.multiplierFor(4, 1, 0, TUNING)
    assert(highStars > lowStars, "higher stars must strictly increase the traffic multiplier")
    print("TrafficStat.spec: multiplierFor monotonic in stars OK")
end

print("TrafficStat.spec: all assertions passed")
