-- WeatherAccess: minimal singleton exposing the live active storm to other server Scripts.
--
-- Same deviation PlayerDataAccess.lua already made and documented (M4): WeatherService.server.lua
-- and EconomyService.server.lua are separate Scripts that each self-wire independently, and
-- EconomyService needs read-only access to WeatherService's owned state (the active storm's
-- zone/legendaryType) to resolve a cast's legendary odds. Module-cached singleton, not a `_G`
-- global — same reasoning PlayerDataAccess's header already gives in full.
local WeatherAccess = {}

export type Storm = { zone: string, legendaryType: string, endsAt: number }

local currentStorm: Storm? = nil

function WeatherAccess.setCurrentStorm(storm: Storm?): ()
    currentStorm = storm
end

function WeatherAccess.getCurrentStorm(): Storm?
    return currentStorm
end

return WeatherAccess
