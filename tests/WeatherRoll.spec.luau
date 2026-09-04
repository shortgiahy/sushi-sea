-- Headless tests for WeatherRoll (PRD §7.5): zone quantization and injectable-randomness rolls.
-- Pure module, no Roblox globals — runs under Lune exactly like FishingCatch.spec.luau (same
-- injectable-randomFn pattern as rollBiteWaitSeconds).
local WeatherRoll = require("../src/server/ServerStorage/Modules/WeatherRoll")

-- zoneFor: quantizes into ZONE_SIZE_STUDS grid cells; same cell for any point within one cell,
-- different cells across a boundary.
do
    local a = WeatherRoll.zoneFor({ X = 50, Y = 0, Z = 50 }, 200)
    local b = WeatherRoll.zoneFor({ X = 150, Y = 0, Z = 150 }, 200)
    assert(a == b, "two points in the same 200-stud cell must resolve to the same zone")

    local c = WeatherRoll.zoneFor({ X = 250, Y = 0, Z = 50 }, 200)
    assert(a ~= c, "points across a cell boundary must resolve to different zones")

    local negative = WeatherRoll.zoneFor({ X = -50, Y = 0, Z = -50 }, 200)
    assert(negative == "-1_-1", "negative coordinates must floor toward negative infinity, not truncate toward zero")
    print("WeatherRoll.spec: zoneFor OK")
end

-- randomZone: with an injected roll always returning the same value, zx and zz both equal it.
do
    local zone = WeatherRoll.randomZone(5, function(_min, _max)
        return 3
    end)
    assert(zone == "3_3", "randomZone must format the injected roll for both axes")
    print("WeatherRoll.spec: randomZone OK")
end

-- rollInRange: linear interpolation between min and max by the injected [0,1] roll.
do
    local atZero = WeatherRoll.rollInRange(60, 120, function()
        return 0
    end)
    assert(atZero == 60, "rollInRange at roll=0 must resolve to minValue")

    local atOne = WeatherRoll.rollInRange(60, 120, function()
        return 1
    end)
    assert(atOne == 120, "rollInRange at roll=1 must resolve to maxValue")

    local atHalf = WeatherRoll.rollInRange(60, 120, function()
        return 0.5
    end)
    assert(atHalf == 90, "rollInRange at roll=0.5 must resolve to the midpoint")
    print("WeatherRoll.spec: rollInRange OK")
end

-- shouldStartStorm / shouldTriggerLegendary: a roll strictly below the odds succeeds, at or above
-- it fails.
do
    local succeeds = WeatherRoll.shouldStartStorm(0.5, function()
        return 0.4
    end)
    assert(succeeds == true, "a roll below the chance must succeed")

    local fails = WeatherRoll.shouldStartStorm(0.5, function()
        return 0.6
    end)
    assert(fails == false, "a roll at/above the chance must fail")

    local zeroOdds = WeatherRoll.shouldTriggerLegendary(0, function()
        return 0
    end)
    assert(zeroOdds == false, "zero odds must never trigger, even at the lowest possible roll")
    print("WeatherRoll.spec: shouldStartStorm / shouldTriggerLegendary OK")
end

print("WeatherRoll.spec: all assertions passed")
