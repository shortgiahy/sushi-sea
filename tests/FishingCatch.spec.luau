-- Headless tests for FishingCatch (PRD §7.7): input validation, cooldown/throttle gating, and the
-- pure cast->hook->reel fight simulation. Client feel/animation cannot be tested headlessly — see
-- BUILD_LOG.md M3 entry for what remains a Studio/human playtest concern.
local FishingCatch = require("../src/server/ServerStorage/Modules/FishingCatch")

-- Fish motion amplitudes are 0 here so this fixture behaves exactly like the pre-2026-08-06 static
-- band (FISH_CENTER=0.55, CATCH_BOX_WIDTH=0.40 => [0.35, 0.75], the old TENSION_TARGET_MIN/MAX) —
-- every fight-simulation test below was written against that static band and stays meaningful
-- unchanged. Motion itself is covered separately by the fishPositionAt/isInBand tests below.
local FIGHT_CONFIG = {
    HOOK_REACTION_WINDOW_SECONDS = 1.2,
    FIGHT_DURATION_SECONDS = 12.0,
    FISH_CENTER = 0.55,
    CATCH_BOX_WIDTH = 0.40,
    FISH_MOTION_AMPLITUDE_1 = 0,
    FISH_MOTION_FREQUENCY_1 = 0.9,
    FISH_MOTION_AMPLITUDE_2 = 0,
    FISH_MOTION_FREQUENCY_2 = 2.3,
    FISH_MOTION_PHASE_2 = 1.7,
    TENSION_SNAP_THRESHOLD = 0.95,
    PROGRESS_GAIN_PER_SECOND_IN_BAND = 0.20,
    PROGRESS_DECAY_PER_SECOND_OUT_OF_BAND = 0.08,
}

-- isStructurallyValidLocation: type/NaN/infinity checks, garbage rejected.
do
    assert(FishingCatch.isStructurallyValidLocation({ X = 1, Y = 2, Z = 3 }) == true, "plain X/Y/Z table must be valid")
    assert(FishingCatch.isStructurallyValidLocation({ X = 0, Y = 0, Z = 0 }) == true, "origin must be valid")
    assert(FishingCatch.isStructurallyValidLocation("not a location") == false, "a string must be rejected")
    assert(FishingCatch.isStructurallyValidLocation(nil) == false, "nil must be rejected")
    assert(FishingCatch.isStructurallyValidLocation({ X = 1, Y = 2 }) == false, "missing Z must be rejected")
    assert(
        FishingCatch.isStructurallyValidLocation({ X = "1", Y = 2, Z = 3 }) == false,
        "non-number component must be rejected"
    )
    assert(
        FishingCatch.isStructurallyValidLocation({ X = 0 / 0, Y = 0, Z = 0 }) == false,
        "NaN component must be rejected"
    )
    assert(
        FishingCatch.isStructurallyValidLocation({ X = math.huge, Y = 0, Z = 0 }) == false,
        "+inf component must be rejected"
    )
    assert(
        FishingCatch.isStructurallyValidLocation({ X = -math.huge, Y = 0, Z = 0 }) == false,
        "-inf component must be rejected"
    )
    print("FishingCatch.spec: isStructurallyValidLocation rejects garbage OK")
end

-- isLocationWithinRange: distance check used to reject absurd cast targets.
do
    local origin = { X = 0, Y = 0, Z = 0 }
    assert(
        FishingCatch.isLocationWithinRange({ X = 100, Y = 0, Z = 0 }, origin, 120) == true,
        "100 studs must be within a 120 stud range"
    )
    assert(
        FishingCatch.isLocationWithinRange({ X = 200, Y = 0, Z = 0 }, origin, 120) == false,
        "200 studs must exceed a 120 stud range"
    )
    assert(
        FishingCatch.isLocationWithinRange({ X = 120, Y = 0, Z = 0 }, origin, 120) == true,
        "exactly at the max distance must be within range"
    )
    print("FishingCatch.spec: isLocationWithinRange OK")
end

-- isValidTension: only finite numbers in [0, 1] are accepted — a spoofed client value outside
-- that range must be rejected outright, not silently clamped.
do
    assert(FishingCatch.isValidTension(0) == true, "0 must be valid")
    assert(FishingCatch.isValidTension(1) == true, "1 must be valid")
    assert(FishingCatch.isValidTension(0.5) == true, "0.5 must be valid")
    assert(FishingCatch.isValidTension(-0.01) == false, "below 0 must be rejected")
    assert(FishingCatch.isValidTension(1.01) == false, "above 1 must be rejected")
    assert(FishingCatch.isValidTension(999) == false, "a spoofed large value must be rejected")
    assert(FishingCatch.isValidTension(0 / 0) == false, "NaN must be rejected")
    assert(FishingCatch.isValidTension("0.5") == false, "a string must be rejected")
    assert(FishingCatch.isValidTension(nil) == false, "nil must be rejected")
    print("FishingCatch.spec: isValidTension rejects out-of-range/garbage OK")
end

-- canCast: cooldown gating and the pending-cast guard (blocks a second cast while the first
-- cast's bite roll is still pending, independent of the cooldown timer).
do
    assert(FishingCatch.canCast(10, nil, false, 1.5) == true, "first-ever cast must be allowed")
    assert(FishingCatch.canCast(10, 9, false, 1.5) == false, "a cast 1s after the last one must be blocked by cooldown")
    assert(FishingCatch.canCast(10, 8, false, 1.5) == true, "a cast 2s after the last one must clear a 1.5s cooldown")
    assert(FishingCatch.canCast(10, 8, true, 1.5) == false, "a pending cast must block a new cast even off cooldown")
    print("FishingCatch.spec: canCast cooldown + pending-cast gating OK")
end

-- shouldThrottleReelInput: server-side spam guard on Player_ReelInput.
do
    assert(FishingCatch.shouldThrottleReelInput(10, nil, 0.08) == false, "the first input must never be throttled")
    assert(
        FishingCatch.shouldThrottleReelInput(10, 9.95, 0.08) == true,
        "an input 0.05s after the last accepted one must be throttled"
    )
    assert(
        FishingCatch.shouldThrottleReelInput(10, 9.9, 0.08) == false,
        "an input 0.1s after the last accepted one must pass"
    )
    print("FishingCatch.spec: shouldThrottleReelInput OK")
end

-- rollBiteWaitSeconds: stays within [min, max] regardless of the random roll.
do
    assert(FishingCatch.rollBiteWaitSeconds(2.0, 6.0, function()
        return 0
    end) == 2.0, "a roll of 0 must produce the minimum wait")
    assert(FishingCatch.rollBiteWaitSeconds(2.0, 6.0, function()
        return 1
    end) == 6.0, "a roll of 1 must produce the maximum wait")
    local mid = FishingCatch.rollBiteWaitSeconds(2.0, 6.0, function()
        return 0.5
    end)
    assert(mid == 4.0, "a roll of 0.5 must produce the midpoint wait, got " .. tostring(mid))
    print("FishingCatch.spec: rollBiteWaitSeconds stays in range OK")
end

-- applyReelInput: missing the hook reaction window loses the fish before any reeling happens.
do
    local fight = FishingCatch.newFight(0, "fight-1")
    local _, outcome = FishingCatch.applyReelInput(fight, 0.5, 1.5, FIGHT_CONFIG)
    assert(outcome == "escaped", "a reel input arriving after the hook window must escape, got " .. outcome)
    print("FishingCatch.spec: applyReelInput hook-window expiry -> escaped OK")
end

-- applyReelInput: sustained in-band tension accumulates progress to a catch.
do
    local fight = FishingCatch.newFight(0, "fight-2")
    local now = 0
    local outcome = "ongoing"
    -- First input lands the hook (dt from the hook-landing call is intentionally 0, see module
    -- comment); subsequent 0.5s steps at mid-band tension (0.5) accumulate progress.
    fight, outcome = FishingCatch.applyReelInput(fight, 0.5, now, FIGHT_CONFIG)
    assert(outcome == "ongoing", "hook-landing input must not resolve the fight by itself")

    local steps = 0
    while outcome == "ongoing" and steps < 200 do
        now += 0.5
        fight, outcome = FishingCatch.applyReelInput(fight, 0.5, now, FIGHT_CONFIG)
        steps += 1
    end

    assert(outcome == "caught", "sustained in-band tension must eventually land the fish, got " .. outcome)
    assert(now <= FIGHT_CONFIG.FIGHT_DURATION_SECONDS, "the catch must land within the fight duration budget")
    print("FishingCatch.spec: applyReelInput sustained in-band tension -> caught OK (" .. steps .. " steps)")
end

-- applyReelInput: tension at/above the snap threshold ends the fight immediately.
do
    local fight = FishingCatch.newFight(0, "fight-3")
    local outcome
    fight, outcome = FishingCatch.applyReelInput(fight, 0.5, 0.1, FIGHT_CONFIG) -- land the hook
    assert(outcome == "ongoing", "sanity: hook must land first")
    fight, outcome = FishingCatch.applyReelInput(fight, 0.99, 0.3, FIGHT_CONFIG)
    assert(outcome == "snapped", "tension above the snap threshold must snap the line, got " .. outcome)
    print("FishingCatch.spec: applyReelInput over-tension -> snapped OK")
end

-- applyReelInput: the total fight-duration budget is enforced even mid-fight.
do
    local fight = FishingCatch.newFight(0, "fight-4")
    local outcome
    fight, outcome = FishingCatch.applyReelInput(fight, 0.5, 0.1, FIGHT_CONFIG) -- land the hook
    assert(outcome == "ongoing", "sanity: hook must land first")
    -- Out-of-band tension the whole time so progress never reaches 1 before the budget expires.
    -- Budget is measured from biteAt, not from the hook-landing time — include the hook window too.
    fight, outcome = FishingCatch.applyReelInput(
        fight,
        0.0,
        0.1 + FIGHT_CONFIG.HOOK_REACTION_WINDOW_SECONDS + FIGHT_CONFIG.FIGHT_DURATION_SECONDS + 1,
        FIGHT_CONFIG
    )
    assert(outcome == "escaped", "exceeding the total fight budget must escape the fish, got " .. outcome)
    print("FishingCatch.spec: applyReelInput fight-duration budget -> escaped OK")
end

-- applyReelInput: out-of-band tension decays progress but does not fail the fight outright
-- (Pillar 1 — opportunity cost, not punishment, even at the single-fight mechanical level).
do
    local fight = FishingCatch.newFight(0, "fight-5")
    local outcome
    fight, outcome = FishingCatch.applyReelInput(fight, 0.5, 0.1, FIGHT_CONFIG) -- land the hook, in-band
    fight, outcome = FishingCatch.applyReelInput(fight, 0.5, 1.1, FIGHT_CONFIG) -- 1s in-band
    assert(fight.progress > 0, "in-band time must have produced positive progress")
    local progressBeforeDrift = fight.progress
    fight, outcome = FishingCatch.applyReelInput(fight, 0.1, 2.1, FIGHT_CONFIG) -- 1s out-of-band (below target)
    assert(outcome == "ongoing", "out-of-band tension alone must not end the fight")
    assert(fight.progress < progressBeforeDrift, "out-of-band time must decay progress")
    assert(fight.progress >= 0, "progress must never go negative")
    print("FishingCatch.spec: applyReelInput out-of-band decay without failure OK")
end

-- fishPositionAt: deterministic Stardew Valley-style fish drift (2026-08-06, corrects the first
-- moving-target pass which had the fish and the player-controlled box backwards). Must start at
-- FISH_CENTER exactly when PHASE_2=0 (both sines are 0 at t=0), stay bounded on the bar always,
-- and actually move over time rather than sitting static.
do
    local motionConfig = {
        FISH_CENTER = 0.5,
        CATCH_BOX_WIDTH = 0.22,
        FISH_MOTION_AMPLITUDE_1 = 0.28,
        FISH_MOTION_FREQUENCY_1 = 0.9,
        FISH_MOTION_AMPLITUDE_2 = 0.14,
        FISH_MOTION_FREQUENCY_2 = 2.3,
        FISH_MOTION_PHASE_2 = 1.7,
    }

    -- Independently re-derive the formula's expected value at t=0 (PHASE_2 is nonzero, so the
    -- second sine term is NOT 0 here — only checking "it equals FISH_CENTER" would be wrong).
    local expectedAtZero = 0.5 + 0.28 * math.sin(0) + 0.14 * math.sin(1.7)
    assert(
        math.abs(FishingCatch.fishPositionAt(0, motionConfig) - expectedAtZero) < 1e-9,
        "fishPositionAt(0, ...) must match the documented formula exactly"
    )

    local zeroPhaseConfig = {
        FISH_CENTER = 0.5,
        CATCH_BOX_WIDTH = 0.22,
        FISH_MOTION_AMPLITUDE_1 = 0.28,
        FISH_MOTION_FREQUENCY_1 = 0.9,
        FISH_MOTION_AMPLITUDE_2 = 0.14,
        FISH_MOTION_FREQUENCY_2 = 2.3,
        FISH_MOTION_PHASE_2 = 0,
    }
    assert(
        FishingCatch.fishPositionAt(0, zeroPhaseConfig) == 0.5,
        "with PHASE_2 = 0, both sine terms are 0 at elapsed=0, so the fish must sit exactly at FISH_CENTER"
    )

    local halfWidth = motionConfig.CATCH_BOX_WIDTH / 2
    local t = 0
    while t <= 20 do
        local position = FishingCatch.fishPositionAt(t, motionConfig)
        assert(
            position >= halfWidth - 1e-9 and position <= 1 - halfWidth + 1e-9,
            "the fish must always stay fully within [0, 1], got position="
                .. tostring(position)
                .. " at t="
                .. tostring(t)
        )
        t += 0.37
    end

    local position1 = FishingCatch.fishPositionAt(1.0, motionConfig)
    local position2 = FishingCatch.fishPositionAt(2.0, motionConfig)
    assert(position1 ~= position2, "the fish must actually move between two different elapsed times, not sit static")
    print("FishingCatch.spec: fishPositionAt bounded + moving OK")
end

-- isInBand: inclusive-range check, symmetric regardless of which argument is "the fish" and which
-- is "the player's box center" — the same check applyReelInput now runs every tick against a
-- fresh fishPositionAt() result and the player's current tension.
do
    assert(FishingCatch.isInBand(0.5, 0.5, 0.2) == true, "fish exactly at the box center must be in band")
    assert(FishingCatch.isInBand(0.6, 0.5, 0.2) == true, "fish at the edge of the box must be in band (inclusive)")
    assert(FishingCatch.isInBand(0.61, 0.5, 0.2) == false, "fish just outside the box must not be in band")
    print("FishingCatch.spec: isInBand OK")
end

-- tick: resolves a fight that never receives further input (client went silent).
do
    local waitingFight = FishingCatch.newFight(0, "fight-6")
    local _, outcome = FishingCatch.tick(waitingFight, 5, FIGHT_CONFIG)
    assert(outcome == "escaped", "a fight with no hook input past the hook window must escape on tick, got " .. outcome)

    local stillWaiting = FishingCatch.newFight(0, "fight-7")
    local _, ongoingOutcome = FishingCatch.tick(stillWaiting, 0.5, FIGHT_CONFIG)
    assert(ongoingOutcome == "ongoing", "a fight still inside the hook window must remain ongoing on tick")

    local endedFight = FishingCatch.newFight(0, "fight-8")
    endedFight.phase = "ended"
    local _, noopOutcome = FishingCatch.tick(endedFight, 100, FIGHT_CONFIG)
    assert(noopOutcome == "ongoing", "ticking an already-ended fight must be a no-op, not re-fire an outcome")
    print("FishingCatch.spec: tick timeout resolution OK")
end

-- qualityScoreFor: ratio of in-band time to total reeled time, clamped to [0, 1].
do
    local zeroTime = { totalSeconds = 0, inBandSeconds = 0 }
    assert(FishingCatch.qualityScoreFor(zeroTime) == 0, "zero total time must score 0, not divide by zero")

    local halfInBand = { totalSeconds = 10, inBandSeconds = 5 }
    assert(FishingCatch.qualityScoreFor(halfInBand) == 0.5, "half in-band time must score 0.5")

    local fullyInBand = { totalSeconds = 10, inBandSeconds = 10 }
    assert(FishingCatch.qualityScoreFor(fullyInBand) == 1, "fully in-band time must score 1")
    print("FishingCatch.spec: qualityScoreFor OK")
end

-- rollCatch: weighted species selection at roll boundaries + authored quality bands, plus the
-- degenerate empty/zero-weight cases.
do
    local species = {
        { id = "common_fish", displayName = "Common Fish", rarity = "common", catchWeight = 90 },
        { id = "rare_fish", displayName = "Rare Fish", rarity = "rare", catchWeight = 10 },
    }

    local low = FishingCatch.rollCatch(species, 0.5, function()
        return 0
    end)
    assert(low ~= nil and low.speciesId == "common_fish", "the lowest roll must land on the first cumulative band")

    local high = FishingCatch.rollCatch(species, 0.5, function()
        return 1
    end)
    assert(high ~= nil and high.speciesId == "rare_fish", "the highest roll must land on the last cumulative band")

    assert(FishingCatch.rollCatch(species, 0.4, function()
        return 0
    end).quality == "poor", "qualityScore == 0.4 must be poor (band boundary is inclusive)")
    assert(FishingCatch.rollCatch(species, 0.41, function()
        return 0
    end).quality == "good", "qualityScore just above 0.4 must be good")
    assert(FishingCatch.rollCatch(species, 0.75, function()
        return 0
    end).quality == "good", "qualityScore == 0.75 must be good (band boundary is inclusive)")
    assert(FishingCatch.rollCatch(species, 0.76, function()
        return 0
    end).quality == "excellent", "qualityScore just above 0.75 must be excellent")
    assert(FishingCatch.rollCatch(species, 1, function()
        return 0
    end).quality == "excellent", "qualityScore == 1 must be excellent")

    assert(FishingCatch.rollCatch({}, 0.5) == nil, "an empty species table must return nil, not error")
    local zeroWeightSpecies = { { id = "x", displayName = "X", rarity = "common", catchWeight = 0 } }
    assert(FishingCatch.rollCatch(zeroWeightSpecies, 0.5) == nil, "all-zero catch weights must return nil, not error")
    print("FishingCatch.spec: rollCatch weighted selection + quality bands OK")
end

print("FishingCatch.spec: all assertions passed")
