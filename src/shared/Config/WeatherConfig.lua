-- WeatherConfig: storm rotation, zone grid, and legendary-encounter scaling (M13/M14, PRD §7.5
-- "Weather & legendary system (one system, both purposes)")
--
-- Not in PRD §7.1's exact file list, same "config lives in ReplicatedStorage/Config" shape as
-- every other Config file in this repo.
--
-- M13/M14 scope reasoning (all first-pass placeholders):
-- - ZONE_SIZE_STUDS quantizes a cast location into a zone id purely by grid math (WeatherRoll
--   .zoneFor) — no physical world/terrain exists yet (no `Workspace` mapping in
--   default.project.json), so a zone can't be a real named place today. This is the smallest
--   thing that makes "per-player server-side roll-table modification in-zone" (PRD §7.5) testable
--   now; a real zone/sector system is natural M18-adjacent work once the world exists.
-- - STORM_CATALOG currently has one entry (kraken/ink_storm) — PRD's storm catalog (types →
--   legendaries → durations → zone sizes → broadcast lead time) is Thread #6, unset; this is a
--   first content pass, not the full catalog.
-- - "Weather-triggered, not summonable" (PRD §4) is read literally: a legendary can ONLY roll
--   while a storm is active AND the cast lands in that storm's zone — BASELINE_LEGENDARY_ODDS_PER_CAST
--   only ever applies inside that condition (there is no separate "ambient" legendary chance with
--   no assigned species outside weather); IN_ZONE_LEGENDARY_ODDS_MULTIPLIER is folded into the
--   effective in-zone odds by the caller (EconomyService.server.lua), not a second free-standing
--   knob.
-- - LEGENDARY_PHASE_* scales FishingCatch's existing fight simulation up per phase (PRD §4: "the
--   fight is the bite/reel loop, scaled up... not a bespoke combat system") — each phase narrows
--   the catch box by PHASE_WIDTH_MULTIPLIER, and Fishing level widens it back
--   (LEVEL_RELIEF_PER_LEVEL, capped) per PRD's "Fishing level gates outcome."
local WeatherConfig = {}

WeatherConfig.ZONE_SIZE_STUDS = 200
WeatherConfig.ZONE_GRID_RADIUS = 5

WeatherConfig.STORM_CATALOG = {
    { type = "ink_storm", legendaryType = "kraken", minDurationSeconds = 60, maxDurationSeconds = 120 },
}

WeatherConfig.WEATHER_ROTATION_TICK_SECONDS = 30
WeatherConfig.STORM_START_CHANCE_PER_TICK = 0.3

WeatherConfig.BASELINE_LEGENDARY_ODDS_PER_CAST = 0.001
WeatherConfig.IN_ZONE_LEGENDARY_ODDS_MULTIPLIER = 100

WeatherConfig.LEGENDARY_PHASE_COUNT = 3
WeatherConfig.LEGENDARY_PHASE_WIDTH_MULTIPLIER = 0.75
WeatherConfig.LEGENDARY_MIN_CATCH_BOX_WIDTH = 0.12
WeatherConfig.LEGENDARY_LEVEL_RELIEF_PER_LEVEL = 0.02
WeatherConfig.LEGENDARY_MAX_LEVEL_RELIEF = 0.20
WeatherConfig.LEGENDARY_MAX_FISHING_LEVEL_FOR_RELIEF = 10
WeatherConfig.LEGENDARY_PHASE_DURATION_SECONDS = 15

return WeatherConfig
