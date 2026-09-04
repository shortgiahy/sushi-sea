-- EconomyConfig: clamped multiplier constants for served_plate_value (PRD §5) — server resolves
-- against these, never the client (PRD §8's "Economy safety" example names CLAMP_FRESHNESS_MIN/MAX
-- directly; kept here verbatim).
--
-- M5 scope reasoning:
-- - CLAMP_FRESHNESS_MIN/MAX and FRESHNESS_DECAY_WINDOW_SECONDS are a placeholder linear-decay
--   curve (full CLAMP_FRESHNESS_MAX "polish" at zero elapsed since the portion's own cut/cook
--   clock, decaying to CLAMP_FRESHNESS_MIN by the window and clamped flat beyond it) standing in
--   for SpoilageService's real freshness tick, which doesn't exist until M6. Same "starting guess,
--   not locked" status as FishingConfig.lua/CookConfig.lua.
-- - DRY_AGE_MUTATION_BASELINE is the "no mutation" value (1.0, PRD §5's own floor for that term).
--   Every M5 plate resolves with this baseline — the aging locker that produces a real rolled
--   mutation doesn't exist until M15 (DryAgingLocker.lua); PlateValueResolver.lua already accepts
--   an override input so M15 only has to supply a number, not change this module or the formula.
-- - MIN_SERVE_ACTION_INTERVAL_SECONDS mirrors CookConfig's MIN_COOK_ACTION_INTERVAL_SECONDS
--   debounce rationale (PRD §8: "Debounce spammable Player_* events") — Player_ServePlate is a
--   one-shot commit per portion, same shape as the cook verb's trace/stroke commits.
-- - cooking_extraction's MAX_COOKING_LEVEL is intentionally NOT duplicated here — EconomyService
--   reuses CookConfig.MAX_COOKING_LEVEL_FOR_EXTRACTION (the same "cooking level ceiling" concept
--   the yield formula's floorFrac already uses) rather than defining a second, potentially
--   divergent constant for the same thing.
local EconomyConfig = {}

EconomyConfig.CLAMP_FRESHNESS_MIN = 0.5
EconomyConfig.CLAMP_FRESHNESS_MAX = 1.5
EconomyConfig.FRESHNESS_DECAY_WINDOW_SECONDS = 600

EconomyConfig.DRY_AGE_MUTATION_BASELINE = 1.0

EconomyConfig.MIN_SERVE_ACTION_INTERVAL_SECONDS = 0.3

-- M7/M8 scope reasoning (2026-09-04 Giahy numbers session, PRD §12 Threads #3+#5 partial
-- resolution — see docs/design/economy-model-skeleton.md Rows 3-4):
-- - RAW_FISH_*_AFTER_SECONDS / COOKED_PORTION_*_AFTER_SECONDS are the tier-0 (starter boat)
--   baseline for SpoilageCalculator's two-threshold tuning — first-pass real numbers, no longer
--   arbitrary M6 placeholders, but still explicitly first-pass pending playtest feedback (same
--   "confirm/adjust after real play" status every other tuning file in this repo carries). Cooked
--   portions decay faster than raw fish at every tier: they're already-extracted value (more
--   urgent to sell), while raw fish is the hoardable resource whose spoiled-after time is the
--   actual "coast length" PRD §4 targets (a few hours early, 12h+ late).
-- - STORAGE_TIERS is the Purchasing storage-capacity ladder (PlayerDataSchema.Storage.tier
--   indexes this table): each tier both raises `capacity` (max raw `inventory` entries,
--   enforced in EconomyService._writeCaughtFishToInventory) and multiplies the tier-0 baseline
--   above via `spoilageMultiplier` — exactly PRD §4's "storage upgrades raise capacity *and* slow
--   spoilage." Tier 3's 8x multiplier lands raw-fish spoilage at 12h, the top of the §4 target
--   range. `upgradeCost` is a first-pass authored guess (Design Pillar 4: authored bands, not a
--   formula) — the Thread #3 progression-stage validation table (does net income/hr beat
--   next-tier cost) is deferred as a follow-up once M8 gets a Studio pass, not required to build
--   the ladder itself.
-- - WAGE_RATE and offline-bank throughputCap remain undecided on purpose: both only matter once
--   M11 gives a player actual staffHeadcount > 0 (nobody runs the restaurant while the player is
--   away at tier 0) — OfflineBankCalculator.compute short-circuits to a 0 net bank whenever
--   staffHeadcount is 0, so these stay inert until M11 needs real values.
-- - SPOILAGE_TICK_INTERVAL_SECONDS is how often SpoilageService.server.lua sweeps loaded players'
--   inventory/cookedPortions — a period, not a per-frame value, so it lives beside the other
--   service-level timing knob here (MIN_SERVE_ACTION_INTERVAL_SECONDS) rather than in a new file.
EconomyConfig.RAW_FISH_STALE_AFTER_SECONDS = 45 * 60
EconomyConfig.RAW_FISH_SPOILED_AFTER_SECONDS = 90 * 60
EconomyConfig.COOKED_PORTION_STALE_AFTER_SECONDS = 20 * 60
EconomyConfig.COOKED_PORTION_SPOILED_AFTER_SECONDS = 40 * 60

EconomyConfig.SPOILAGE_TICK_INTERVAL_SECONDS = 5

EconomyConfig.STORAGE_TIERS = {
    [0] = { name = "Boat cooler", capacity = 10, spoilageMultiplier = 1, upgradeCost = 0 },
    [1] = { name = "Icebox", capacity = 20, spoilageMultiplier = 2, upgradeCost = 500 },
    [2] = { name = "Chiller unit", capacity = 40, spoilageMultiplier = 4, upgradeCost = 3000 },
    [3] = { name = "Cold storage room", capacity = 80, spoilageMultiplier = 8, upgradeCost = 15000 },
}
EconomyConfig.MAX_STORAGE_TIER = 3

return EconomyConfig
