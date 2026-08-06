-- CookConfig: placeholder tuning knobs for the M4 gray-box cook verb (docs/design/cook-verb.md)
--
-- Mirrors FishingConfig.lua's stance: every number here is a reasoned starting guess, not a
-- locked value, pending Studio-side human iteration. Reasoning:
-- - QUICK/FULL_TRACE_PERIOD_SECONDS and STROKE_PERIOD_SECONDS approximate the design doc's
--   "~2s" (quick) and "~8-12s" (full: one trace + one stroke per loin) targets (§2.3), explicitly
--   called out there as targets, not locked numbers.
-- - FLOOR_FRAC_AT_LEVEL_1/MAX and MAX_COOKING_LEVEL_FOR_EXTRACTION implement the yield formula's
--   floorFrac curve (§4.2): level raises the worst-case floor, never the ceiling
--   (maxYield is authored per-species in FishSpecies.lua and never moves). No XP/leveling system
--   exists yet anywhere in this codebase (SkillConfig.lua is still an empty stub), so
--   cookingLevel always reads PlayerData's default of 1 today — floorFrac therefore always
--   resolves to FLOOR_FRAC_AT_LEVEL_1 in practice until a leveling system lands. That's expected,
--   not a bug: the curve is still correct, just constant until there's a level to vary.
-- - GRADE_BANDS implements §4.3's grade floor rule directly: the lowest band's minQuality = 0,
--   so gradeFor() always resolves to at least "akami" — there is no way to fall through with no
--   match, satisfying "no grade below akami and no inedible result."
-- - MIN_COOK_ACTION_INTERVAL_SECONDS is a coarser debounce than fishing's
--   MIN_REEL_INPUT_INTERVAL_SECONDS because cook inputs are one-shot commits (PRD §8: "Debounce
--   spammable Player_* events"), not a per-frame stream — 0.3s comfortably exceeds any legitimate
--   double-fire from a single button press/key release pair.
-- - PENDING_COOK_TIMEOUT_SECONDS mirrors EconomyService's fight-timeout pattern (FishingCatch):
--   if a client stops sending Player_CookStroke mid-sequence (dropped connection, walked away),
--   the server-side pending-cook state still gets cleaned up instead of leaking forever.
local CookConfig = {}

-- Minigame pacing (client-only feel knobs, but shared so a human tuning session has one file to
-- look at, matching FishingConfig's split rationale)
CookConfig.QUICK_TRACE_PERIOD_SECONDS = 1.0
CookConfig.FULL_TRACE_PERIOD_SECONDS = 1.4
CookConfig.STROKE_PERIOD_SECONDS = 1.2
CookConfig.RESULT_MESSAGE_DISPLAY_SECONDS = 3.0

-- Yield formula (docs/design/cook-verb.md §4.2)
CookConfig.FLOOR_FRAC_AT_LEVEL_1 = 0.4
CookConfig.FLOOR_FRAC_AT_MAX_LEVEL = 0.85
CookConfig.MAX_COOKING_LEVEL_FOR_EXTRACTION = 10

-- Grade bands (docs/design/cook-verb.md §4.3) — checked in order, first match wins. Must stay
-- sorted descending by minQuality with a trailing minQuality = 0 entry.
CookConfig.GRADE_BANDS = {
    { minQuality = 0.75, grade = "otoro" },
    { minQuality = 0.4, grade = "chutoro" },
    { minQuality = 0, grade = "akami" },
}

-- Server-side authority knobs
CookConfig.MIN_COOK_ACTION_INTERVAL_SECONDS = 0.3
CookConfig.PENDING_COOK_TIMEOUT_SECONDS = 30

return CookConfig
