-- WorldConfig: island/ocean terrain dimensions and restaurant-plot layout (first world geometry
-- this repo has ever generated — see WorldGenerationService.server.lua's header for why this is
-- script-generated rather than Studio-hand-authored)
--
-- Scope reasoning (first-pass placeholders, "starting guess, not locked" like every other tuning
-- file in this repo):
-- - Sizes are chosen so the island's usable plateau sits comfortably inside
--   FishingConfig.MAX_CAST_DISTANCE_STUDS (120 studs) of its shoreline — a player standing at a
--   plot can walk to the coast and still cast without a long trek — while the ocean extends far
--   enough past that to read as "surrounded by ocean," not a pond.
-- - PLOT_COUNT/PLOT_RING_RADIUS_STUDS are a first physical pass at PRD's "harbor town" — nothing
--   in the data model assigns a specific plot to a specific player yet (`restaurant.tier` is still
--   purely abstract, PlayerDataSchema has no location field); that assignment is deliberately not
--   built here, only the physical plots to assign onto later.
local WorldConfig = {}

WorldConfig.SEA_LEVEL_Y = 0

WorldConfig.OCEAN_RADIUS_STUDS = 800
WorldConfig.OCEAN_DEPTH_STUDS = 60

-- Two concentric terraced rings, not a smooth slope — a deliberate simplification voxel Terrain
-- fills can do reliably without noise-based smoothing, not a bug. The inner ring's flat top is
-- the plateau plots sit on.
WorldConfig.BEACH_RING_RADIUS_STUDS = 180
WorldConfig.BEACH_RING_HEIGHT_STUDS = 6 -- centered 2 studs below sea level, so it just breaks the surface
WorldConfig.PLATEAU_RADIUS_STUDS = 130
WorldConfig.PLATEAU_HEIGHT_STUDS = 10 -- centered 2 studs above sea level -> top surface at sea level + 7

WorldConfig.PLOT_COUNT = 6
WorldConfig.PLOT_RING_RADIUS_STUDS = 90
WorldConfig.PLOT_SIZE_STUDS = Vector3.new(40, 1, 40)

WorldConfig.SPAWN_HEIGHT_STUDS = 1

return WorldConfig
