-- WeatherRoll: pure zone quantization and randomness rolls for weather/legendary spawning (M13,
-- PRD §7.5)
--
-- Not in PRD §7.1's file list — same "pure logic needs to be headlessly testable" deviation every
-- other pure module in this repo already makes. WeatherService.server.lua and
-- EconomyService.server.lua are the callers. Randomness is injectable (optional `randomFn`, same
-- shape as FishingCatch.rollBiteWaitSeconds) so every roll here is deterministically testable.
local WeatherRoll = {}

export type Vector3Like = { X: number, Y: number, Z: number }

-- Quantizes a cast location into a zone id by flooring X/Z into ZONE_SIZE_STUDS-wide grid cells —
-- see WeatherConfig.lua's header for why a grid stands in for a real named zone/sector today.
function WeatherRoll.zoneFor(location: Vector3Like, zoneSizeStuds: number): string
    local zx = math.floor(location.X / zoneSizeStuds)
    local zz = math.floor(location.Z / zoneSizeStuds)
    return ("%d_%d"):format(zx, zz)
end

function WeatherRoll.randomZone(gridRadius: number, randomFn: ((number, number) -> number)?): string
    local roll = randomFn
        or function(minInt: number, maxInt: number): number
            return math.random(minInt, maxInt)
        end
    local zx = roll(-gridRadius, gridRadius)
    local zz = roll(-gridRadius, gridRadius)
    return ("%d_%d"):format(zx, zz)
end

function WeatherRoll.rollInRange(minValue: number, maxValue: number, randomFn: (() -> number)?): number
    local roll = if randomFn then randomFn() else math.random()
    return minValue + roll * (maxValue - minValue)
end

function WeatherRoll.shouldStartStorm(chancePerTick: number, randomFn: (() -> number)?): boolean
    local roll = if randomFn then randomFn() else math.random()
    return roll < chancePerTick
end

-- `odds` is the caller's already-computed effective odds (0 outside an active storm's zone,
-- BASELINE * IN_ZONE_MULTIPLIER inside it — see EconomyService.server.lua) — this function has no
-- opinion on zone/storm state, it only resolves one roll against a probability.
function WeatherRoll.shouldTriggerLegendary(odds: number, randomFn: (() -> number)?): boolean
    local roll = if randomFn then randomFn() else math.random()
    return roll < odds
end

return WeatherRoll
