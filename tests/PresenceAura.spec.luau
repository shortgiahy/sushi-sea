-- Headless tests for PresenceAura (PRD §4 "presence aura"): session-decaying quality multiplier.
-- Pure module, no Roblox globals — runs under Lune exactly like TrafficStat.spec.luau.
local PresenceAura = require("../src/server/ServerStorage/Modules/PresenceAura")

local TUNING = {
    BASE_MULTIPLIER = 1.2,
    MIN_MULTIPLIER = 1.0,
    SESSION_DECAY_HALF_LIFE_SECONDS = 20 * 60,
}

-- At session start (0 elapsed), the multiplier is exactly BASE_MULTIPLIER — full strength.
do
    local multiplier = PresenceAura.multiplierFor(0, TUNING)
    assert(math.abs(multiplier - 1.2) < 1e-9, "zero session time must resolve to exactly BASE_MULTIPLIER")
    print("PresenceAura.spec: session start OK")
end

-- At exactly one half-life, the bonus above MIN_MULTIPLIER has halved.
do
    local multiplier = PresenceAura.multiplierFor(TUNING.SESSION_DECAY_HALF_LIFE_SECONDS, TUNING)
    local expected = 1.0 + (1.2 - 1.0) * 0.5
    assert(math.abs(multiplier - expected) < 1e-9, "one half-life must halve the bonus above MIN_MULTIPLIER")
    print("PresenceAura.spec: one half-life OK")
end

-- A very long session decays toward, but never below, MIN_MULTIPLIER.
do
    local multiplier = PresenceAura.multiplierFor(TUNING.SESSION_DECAY_HALF_LIFE_SECONDS * 100, TUNING)
    assert(multiplier >= 1.0, "the multiplier must never drop below MIN_MULTIPLIER")
    assert(multiplier < 1.001, "an extremely long session must decay very close to MIN_MULTIPLIER")
    print("PresenceAura.spec: long session decay floor OK")
end

-- Strictly monotonically decreasing as session time grows — visiting (short sessions) beats
-- parking (long sessions), the entire point of this module.
do
    local early = PresenceAura.multiplierFor(60, TUNING)
    local later = PresenceAura.multiplierFor(3600, TUNING)
    assert(early > later, "a longer session must resolve to a strictly lower multiplier than a shorter one")
    print("PresenceAura.spec: monotonic decay OK")
end

print("PresenceAura.spec: all assertions passed")
