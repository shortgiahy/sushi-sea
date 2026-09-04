-- RestaurantConfig: brick-and-mortar tier ladder, staff hiring, and customer-flow pacing (M10/M11)
--
-- Not in PRD §7.1's exact file list, same "config lives in ReplicatedStorage/Config" shape as
-- EconomyConfig.lua and CookConfig.lua — kept separate from EconomyConfig because these constants
-- are about the restaurant/staff/customer system, not the served_plate_value formula.
--
-- M10/M11 scope reasoning (all first-pass placeholders, "starting guess, not locked" like every
-- other tuning file in this repo):
-- - RESTAURANT_TIERS is the brick-and-mortar upgrade line (PRD §5's "restaurant tiers" Purchasing
--   category, distinct from EconomyConfig.STORAGE_TIERS' storage-capacity category). `seats`
--   caps concurrent customers; PRD §4 calls seating "a buy-past soft cap," not the primary
--   bottleneck (kitchen throughput is).
-- - STAFF_RARITY caps quality by tier, not by player skill (PRD §4 "Staff": "a common cook is
--   solid, a rare chef matches a good player, a legendary chef beats most players"). Each
--   rarity's `basePerformance` feeds directly into ConversionModule.cook's `performance` contract
--   (§7.6) as both traceAccuracy and strokeQuality — deterministic, no per-fish roll, per §4's
--   "high floors — staff do not botch."
-- - TENURE_SECONDS_FOR_FULL_BONUS models "the longer you keep them, the better they get" (§4) as
--   a linear ramp from 0 to each rarity's tenureBonusCap over ~50 hours of real-world tenure
--   (kept hired, not played) — reusing elapsed-time-since-a-timestamp exactly like every other
--   freshness/spoilage clock in this repo, rather than inventing a second time-tracking mechanism.
-- - WAGE_RATE_PER_HOUR_PER_STAFF stays flat across rarities (PRD §5: "wages scale with headcount,"
--   not with rarity) and deliberately weak (PRD's economy caution: wages are a weak dial next to
--   spoilage rate and next-tier pricing).
-- - Customer flow constants are placeholder pacing; CUSTOMER_SPAWN_INTERVAL_SECONDS_PER_SEAT is
--   the base interval TrafficStat.lua's multiplier scales (M12) — higher traffic shortens it.
--
-- M12 scope reasoning (PRD §12 Thread #6, "Yelp prestige formula" + "hidden traffic stat
-- formula" — both explicitly unset, first-pass numbers here same as everything else):
-- - PRESTIGE_POINTS_PER_SERVED_CUSTOMER only ever adds (PRD §4 Rating: prestige "never drops") —
--   a walkout contributes nothing, it never subtracts. PRESTIGE_POINTS_PER_STAR sets how many
--   served customers it takes to climb one star, linearly, clamped at MAX_STARS.
-- - Traffic weights PRESTIGE_WEIGHT/HOSPITALITY_WEIGHT/COSMETICS_WEIGHT reflect PRD §4's stated
--   inputs ("Yelp prestige + cosmetics + Hospitality"); prestige weighted heaviest (reputation
--   drives walk-in traffic more than in-restaurant service skill). COSMETICS_WEIGHT is wired but
--   always multiplied by 0 today — no cosmetics system exists yet, same "inert until that system
--   lands" status WAGE_RATE carried before M11. MAX_HOSPITALITY_LEVEL_FOR_TRAFFIC normalizes
--   Hospitality's level the same way CookConfig.MAX_COOKING_LEVEL_FOR_EXTRACTION normalizes
--   Cooking — also inert today since no XP/leveling system exists yet (SkillConfig.lua is still
--   an empty stub), so Hospitality sits at level 1 for every player.
local RestaurantConfig = {}

RestaurantConfig.RESTAURANT_TIERS = {
    [1] = { name = "Small dining room", seats = 4, upgradeCost = 2000 },
    [2] = { name = "Full restaurant", seats = 8, upgradeCost = 10000 },
    [3] = { name = "Flagship house", seats = 16, upgradeCost = 50000 },
}
RestaurantConfig.MAX_RESTAURANT_TIER = 3

RestaurantConfig.STAFF_RARITY = {
    common = { hireCost = 300, basePerformance = 0.55, tenureBonusCap = 0.10 },
    rare = { hireCost = 1500, basePerformance = 0.75, tenureBonusCap = 0.10 },
    legendary = { hireCost = 8000, basePerformance = 0.92, tenureBonusCap = 0.05 },
}
RestaurantConfig.TENURE_SECONDS_FOR_FULL_BONUS = 50 * 3600

RestaurantConfig.WAGE_RATE_PER_HOUR_PER_STAFF = 10

RestaurantConfig.CUSTOMER_ARRIVAL_SECONDS = 2
RestaurantConfig.CUSTOMER_ORDERING_SECONDS = 5
RestaurantConfig.CUSTOMER_FULFILLMENT_TIMEOUT_SECONDS = 60
RestaurantConfig.CUSTOMER_EATING_SECONDS = 15
RestaurantConfig.CUSTOMER_RATING_SECONDS = 3
RestaurantConfig.CUSTOMER_SPAWN_INTERVAL_SECONDS_PER_SEAT = 30

RestaurantConfig.RESTAURANT_TICK_INTERVAL_SECONDS = 5

RestaurantConfig.PRESTIGE_POINTS_PER_SERVED_CUSTOMER = 1
RestaurantConfig.PRESTIGE_POINTS_PER_STAR = 50
RestaurantConfig.MAX_STARS = 5

RestaurantConfig.PRESTIGE_WEIGHT = 1.0
RestaurantConfig.HOSPITALITY_WEIGHT = 0.5
RestaurantConfig.COSMETICS_WEIGHT = 0.3
RestaurantConfig.MAX_HOSPITALITY_LEVEL_FOR_TRAFFIC = 10
RestaurantConfig.MIN_TRAFFIC_MULTIPLIER = 0.5
RestaurantConfig.MAX_TRAFFIC_MULTIPLIER = 3.0

return RestaurantConfig
