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

-- M6 scope reasoning:
-- - RAW_FISH_*_AFTER_SECONDS and COOKED_PORTION_*_AFTER_SECONDS are SpoilageCalculator's
--   two-threshold tuning (PRD §4's "basic freshness tick") — same "starting guess, not locked"
--   status as every other placeholder constant in this file. Cooked-portion thresholds are set
--   relative to FRESHNESS_DECAY_WINDOW_SECONDS (the point freshness_polish already bottoms out at
--   CLAMP_FRESHNESS_MIN) so a portion keeps *some* value for its whole "stale" phase and is only
--   tossed once it would already be resolving at the floor multiplier anyway.
-- - SPOILAGE_TICK_INTERVAL_SECONDS is how often SpoilageService.server.lua sweeps loaded players'
--   inventory/cookedPortions — a period, not a per-frame value, so it lives beside the other
--   service-level timing knob here (MIN_SERVE_ACTION_INTERVAL_SECONDS) rather than in a new file.
EconomyConfig.RAW_FISH_STALE_AFTER_SECONDS = 300
EconomyConfig.RAW_FISH_SPOILED_AFTER_SECONDS = 600
EconomyConfig.COOKED_PORTION_STALE_AFTER_SECONDS = EconomyConfig.FRESHNESS_DECAY_WINDOW_SECONDS
EconomyConfig.COOKED_PORTION_SPOILED_AFTER_SECONDS = EconomyConfig.FRESHNESS_DECAY_WINDOW_SECONDS * 2

EconomyConfig.SPOILAGE_TICK_INTERVAL_SECONDS = 5

return EconomyConfig
