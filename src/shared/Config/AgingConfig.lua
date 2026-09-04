-- AgingConfig: dry-aging locker tiers and mutation tuning (M15, PRD §4 "Dry aging — the
-- experimentation engine")
--
-- Not in PRD §7.1's exact file list, same "config lives in ReplicatedStorage/Config" shape as
-- every other Config file in this repo.
--
-- M15 scope reasoning (all first-pass placeholders):
-- - LOCKER_TIERS is yet another distinct Purchasing category (PRD §5's sink stack already treats
--   "storage capacity" and "restaurant tiers" as separate lines; this is a third), gating both
--   whether the locker exists at all (tier 0 = none) and how many slots it has.
-- - PEAK_MULTIPLIER/PEAK_SECONDS model "it is a cash-out timer, not a ruin timer: past peak, the
--   fish doesn't ruin — it sits there making no money" (PRD §4) as a curve that rises to a peak
--   and then holds flat forever, never declining — the "no money" is opportunity cost on the slot,
--   not the fish losing value.
-- - MUTATION_CHANCE/MIN_MUTATION_BONUS/MAX_MUTATION_BONUS implement "a full random mutation rolls
--   on aging with percentage multipliers (never orders of magnitude); mutations must stay rare"
--   verbatim — low chance, and the bonus range is a fraction, not a multiple.
local AgingConfig = {}

AgingConfig.LOCKER_TIERS = {
    [1] = { slots = 2, upgradeCost = 1500 },
    [2] = { slots = 4, upgradeCost = 6000 },
    [3] = { slots = 8, upgradeCost = 25000 },
}
AgingConfig.MAX_LOCKER_TIER = 3

AgingConfig.PEAK_MULTIPLIER = 1.5
AgingConfig.PEAK_SECONDS = 6 * 3600

AgingConfig.MUTATION_CHANCE = 0.05
AgingConfig.MIN_MUTATION_BONUS = 1.05
AgingConfig.MAX_MUTATION_BONUS = 1.5

return AgingConfig
