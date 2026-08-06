-- PlayerDataAccess: minimal singleton registry exposing the live PlayerDataService instance to
-- other server Scripts.
--
-- Deferred from M3 (BUILD_LOG.md M3 entry): EconomyService.server.lua and Bootstrap.server.lua
-- are separate Scripts that each self-wire independently, and no service-registry/injection
-- pattern existed for one Service to reach another's owned state — inventing that as a side
-- effect of the M3 fishing stub would have been an undocumented architecture decision. M4 needs
-- exactly this access (writing caught fish and cooked portions into inventory), so it decides it
-- once, here.
--
-- Filled by PlayerDataService.server.lua right after it constructs its instance. This is a
-- module-cached singleton (every `require` of this module returns the same table), not a `_G`
-- global — PRD §8's "stop and flag: a cross-script global" targets `_G`/free-variable state; every
-- script in this repo already relies on require-caching for shared modules (FishingConfig,
-- FishSpecies, etc.), and this is the same mechanism applied to a live instance instead of static
-- config.
local PlayerDataService = require(script.Parent.PlayerDataService)

local PlayerDataAccess = {}

local instance: PlayerDataService.PlayerDataServiceInstance? = nil

function PlayerDataAccess.setInstance(newInstance: PlayerDataService.PlayerDataServiceInstance): ()
    instance = newInstance
end

function PlayerDataAccess.getInstance(): PlayerDataService.PlayerDataServiceInstance?
    return instance
end

return PlayerDataAccess
