-- WeatherService: server-authoritative weather events and legendary spawn broadcast (PRD §7.5)
--
-- M13 scope: rotates a single active storm (or none) — picks a catalog entry, a random zone
-- (WeatherRoll.randomZone, grid-quantized per WeatherConfig's header since no real world/zones
-- exist yet), and a random duration, then broadcasts it via Weather_StormBroadcast (PRD §7.2's
-- exact payload shape) and publishes it to WeatherAccess for EconomyService.server.lua to read
-- when resolving a cast's legendary odds (M14).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeatherRoll = require(ServerStorage.Modules.WeatherRoll)
local WeatherAccess = require(ServerStorage.Modules.WeatherAccess)
local WeatherConfig = require(ReplicatedStorage.Config.WeatherConfig)

local stormBroadcastRemote: RemoteEvent = ReplicatedStorage.Events.RemoteEvents.Weather_StormBroadcast

local function _startStorm(now: number): ()
    local catalogEntry = WeatherConfig.STORM_CATALOG[math.random(1, #WeatherConfig.STORM_CATALOG)]
    local zone = WeatherRoll.randomZone(WeatherConfig.ZONE_GRID_RADIUS)
    local duration = WeatherRoll.rollInRange(catalogEntry.minDurationSeconds, catalogEntry.maxDurationSeconds)

    WeatherAccess.setCurrentStorm({
        zone = zone,
        legendaryType = catalogEntry.legendaryType,
        endsAt = now + duration,
    })

    for _, player in Players:GetPlayers() do
        stormBroadcastRemote:FireClient(player, {
            zone = zone,
            duration = duration,
            legendaryType = catalogEntry.legendaryType,
            oddsMultiplier = WeatherConfig.IN_ZONE_LEGENDARY_ODDS_MULTIPLIER,
        })
    end
end

Players.PlayerAdded:Connect(function(player: Player)
    local storm = WeatherAccess.getCurrentStorm()
    if storm then
        stormBroadcastRemote:FireClient(player, {
            zone = storm.zone,
            duration = math.max(storm.endsAt - os.time(), 0),
            legendaryType = storm.legendaryType,
            oddsMultiplier = WeatherConfig.IN_ZONE_LEGENDARY_ODDS_MULTIPLIER,
        })
    end
end)

task.spawn(function()
    while true do
        task.wait(WeatherConfig.WEATHER_ROTATION_TICK_SECONDS)

        local now = os.time()
        local storm = WeatherAccess.getCurrentStorm()
        if storm and now >= storm.endsAt then
            WeatherAccess.setCurrentStorm(nil)
            storm = nil
        end

        if not storm and WeatherRoll.shouldStartStorm(WeatherConfig.STORM_START_CHANCE_PER_TICK) then
            _startStorm(now)
        end
    end
end)
