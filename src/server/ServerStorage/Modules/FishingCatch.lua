-- FishingCatch: pure cast/hook/reel validation and fight-resolution logic (PRD §7.7) — no Roblox
-- globals, so it runs headlessly under Lune (tests/FishingCatch.spec.luau). EconomyService.server.lua
-- wires this to real RemoteEvents/Players and supplies FishingConfig/FishSpecies (both live in
-- ReplicatedStorage, unreachable from here without `game`) as plain-value/table arguments instead
-- of this module requiring them directly.
local FishingCatch = {}

export type Vector3Like = { X: number, Y: number, Z: number }

export type FightPhase = "waiting_for_hook" | "fighting" | "ended"

export type FightState = {
    fightId: string,
    phase: FightPhase,
    biteAt: number,
    lastInputAt: number,
    tension: number,
    progress: number,
    inBandSeconds: number,
    totalSeconds: number,
}

export type FightOutcome = "ongoing" | "caught" | "snapped" | "escaped"

export type FightConfig = {
    HOOK_REACTION_WINDOW_SECONDS: number,
    FIGHT_DURATION_SECONDS: number,
    TARGET_CENTER: number,
    TARGET_WIDTH: number,
    TARGET_MOTION_AMPLITUDE_1: number,
    TARGET_MOTION_FREQUENCY_1: number,
    TARGET_MOTION_AMPLITUDE_2: number,
    TARGET_MOTION_FREQUENCY_2: number,
    TARGET_MOTION_PHASE_2: number,
    TENSION_SNAP_THRESHOLD: number,
    PROGRESS_GAIN_PER_SECOND_IN_BAND: number,
    PROGRESS_DECAY_PER_SECOND_OUT_OF_BAND: number,
}

export type SpeciesEntry = { id: string, displayName: string, rarity: string, catchWeight: number }

export type CatchResult = { speciesId: string, quality: string }

-- Authored quality bands (Pillar 4, PRD §2: author the bands, clamp the multipliers) — evaluated
-- against qualityScoreFor()'s [0, 1] in-band-time ratio. This is a catch-quality descriptor for
-- client flavor text only; it is NOT an economy multiplier (freshness_polish etc. are M5's job).
local QUALITY_BANDS = {
    { max = 0.4, quality = "poor" },
    { max = 0.75, quality = "good" },
    { max = math.huge, quality = "excellent" },
}

function FishingCatch.isStructurallyValidLocation(location: any): boolean
    if typeof(location) ~= "table" and typeof(location) ~= "Vector3" then
        return false
    end

    local x, y, z = location.X, location.Y, location.Z
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return false
    end
    if x ~= x or y ~= y or z ~= z then -- NaN != NaN
        return false
    end
    if math.abs(x) == math.huge or math.abs(y) == math.huge or math.abs(z) == math.huge then
        return false
    end

    return true
end

function FishingCatch.isLocationWithinRange(location: Vector3Like, origin: Vector3Like, maxDistance: number): boolean
    local dx, dy, dz = location.X - origin.X, location.Y - origin.Y, location.Z - origin.Z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    return distance <= maxDistance
end

function FishingCatch.isValidTension(tension: any): boolean
    if type(tension) ~= "number" then
        return false
    end
    if tension ~= tension then -- NaN != NaN
        return false
    end
    return tension >= 0 and tension <= 1
end

function FishingCatch.canCast(now: number, lastCastAt: number?, pendingCast: boolean, cooldownSeconds: number): boolean
    if pendingCast then
        return false
    end
    if lastCastAt == nil then
        return true
    end
    return (now - lastCastAt) >= cooldownSeconds
end

function FishingCatch.shouldThrottleReelInput(now: number, lastAcceptedAt: number?, minIntervalSeconds: number): boolean
    if lastAcceptedAt == nil then
        return false
    end
    return (now - lastAcceptedAt) < minIntervalSeconds
end

function FishingCatch.rollBiteWaitSeconds(minSeconds: number, maxSeconds: number, randomFn: (() -> number)?): number
    local roll = if randomFn then randomFn() else math.random()
    return minSeconds + roll * (maxSeconds - minSeconds)
end

function FishingCatch.newFight(now: number, fightId: string): FightState
    return {
        fightId = fightId,
        phase = "waiting_for_hook",
        biteAt = now,
        lastInputAt = now,
        tension = 0,
        progress = 0,
        inBandSeconds = 0,
        totalSeconds = 0,
    }
end

-- Stardew Valley-style moving catch zone (2026-08-06, Giahy Studio feedback — replaces M3's
-- static tension band). A sum of two incommensurate-frequency sine waves is smooth (no jarring
-- jumps mid-fight) but not obviously periodic on a fight's timescale, evoking Stardew's erratic
-- fish drift without needing synchronized randomness: the position is a pure function of elapsed
-- time since the bite, so the server (here) and the client (FishingController.lua, which
-- duplicates this exact formula — see its own comment for why it can't just require this module)
-- independently compute the identical trajectory. Clamped so the zone never drifts off the bar.
function FishingCatch.targetCenterAt(elapsedSeconds: number, config: FightConfig): number
    local raw = config.TARGET_CENTER
        + config.TARGET_MOTION_AMPLITUDE_1 * math.sin(elapsedSeconds * config.TARGET_MOTION_FREQUENCY_1)
        + config.TARGET_MOTION_AMPLITUDE_2
            * math.sin(elapsedSeconds * config.TARGET_MOTION_FREQUENCY_2 + config.TARGET_MOTION_PHASE_2)

    local halfWidth = config.TARGET_WIDTH / 2
    return math.clamp(raw, halfWidth, 1 - halfWidth)
end

function FishingCatch.isInBand(tension: number, center: number, width: number): boolean
    local halfWidth = width / 2
    return tension >= center - halfWidth and tension <= center + halfWidth
end

-- Applies one validated reel-input sample to a fight and returns the (possibly mutated) state
-- plus the resulting outcome. The first call after a bite resolves the hook reaction (did the
-- player respond within HOOK_REACTION_WINDOW_SECONDS?); every call after that advances the
-- tension-band minigame. Mutates `fight` in place and also returns it, matching the DataStoreRetry
-- / PlayerDataSchema style already in this codebase (caller reassigns the returned value).
function FishingCatch.applyReelInput(
    fight: FightState,
    tension: number,
    now: number,
    config: FightConfig
): (FightState, FightOutcome)
    if fight.phase == "ended" then
        return fight, "ongoing"
    end

    if fight.phase == "waiting_for_hook" then
        if (now - fight.biteAt) > config.HOOK_REACTION_WINDOW_SECONDS then
            fight.phase = "ended"
            return fight, "escaped"
        end
        fight.phase = "fighting"
        fight.lastInputAt = now -- do not count anticipation time as in/out-of-band tension time
    end

    local fightBudget = config.HOOK_REACTION_WINDOW_SECONDS + config.FIGHT_DURATION_SECONDS
    if (now - fight.biteAt) > fightBudget then
        fight.phase = "ended"
        return fight, "escaped"
    end

    local dt = math.max(0, now - fight.lastInputAt)
    fight.lastInputAt = now
    fight.tension = tension
    fight.totalSeconds += dt

    if tension >= config.TENSION_SNAP_THRESHOLD then
        fight.phase = "ended"
        return fight, "snapped"
    end

    local targetCenter = FishingCatch.targetCenterAt(now - fight.biteAt, config)
    local inBand = FishingCatch.isInBand(tension, targetCenter, config.TARGET_WIDTH)
    if inBand then
        fight.inBandSeconds += dt
        fight.progress = math.clamp(fight.progress + dt * config.PROGRESS_GAIN_PER_SECOND_IN_BAND, 0, 1)
    else
        fight.progress = math.clamp(fight.progress - dt * config.PROGRESS_DECAY_PER_SECOND_OUT_OF_BAND, 0, 1)
    end

    if fight.progress >= 1 then
        fight.phase = "ended"
        return fight, "caught"
    end

    return fight, "ongoing"
end

-- Timeout-only check with no new input sample — the server calls this on a schedule so a fight
-- still resolves (as "escaped") even if the client stops sending Player_ReelInput entirely.
function FishingCatch.tick(fight: FightState, now: number, config: FightConfig): (FightState, FightOutcome)
    if fight.phase == "ended" then
        return fight, "ongoing"
    end

    if fight.phase == "waiting_for_hook" and (now - fight.biteAt) > config.HOOK_REACTION_WINDOW_SECONDS then
        fight.phase = "ended"
        return fight, "escaped"
    end

    local fightBudget = config.HOOK_REACTION_WINDOW_SECONDS + config.FIGHT_DURATION_SECONDS
    if fight.phase == "fighting" and (now - fight.biteAt) > fightBudget then
        fight.phase = "ended"
        return fight, "escaped"
    end

    return fight, "ongoing"
end

function FishingCatch.qualityScoreFor(fight: FightState): number
    if fight.totalSeconds <= 0 then
        return 0
    end
    return math.clamp(fight.inBandSeconds / fight.totalSeconds, 0, 1)
end

-- Weighted-random species pick + authored quality bucket. Returns only catch identity (species,
-- quality) — never a price or plate value. That resolution is explicitly M5's job (PRD §5): the
-- client must never see economy components, and this module has no notion of gold at all.
function FishingCatch.rollCatch(
    species: { SpeciesEntry },
    qualityScore: number,
    randomFn: (() -> number)?
): CatchResult?
    if #species == 0 then
        return nil
    end

    local totalWeight = 0
    for _, entry in species do
        totalWeight += entry.catchWeight
    end
    if totalWeight <= 0 then
        return nil
    end

    local roll = (if randomFn then randomFn() else math.random()) * totalWeight
    local cumulative = 0
    local chosen = species[#species]
    for _, entry in species do
        cumulative += entry.catchWeight
        if roll <= cumulative then
            chosen = entry
            break
        end
    end

    local quality = "poor"
    for _, band in QUALITY_BANDS do
        if qualityScore <= band.max then
            quality = band.quality
            break
        end
    end

    return { speciesId = chosen.id, quality = quality }
end

return FishingCatch
