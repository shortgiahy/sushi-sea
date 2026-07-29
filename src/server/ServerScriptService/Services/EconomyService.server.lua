-- EconomyService: server-side plate value resolution and catch validation; the client never resolves economy state
--
-- M3 scope note: this is the "server-side validation stub" ROADMAP names for M3, not the plate
-- resolution service PRD §5 describes — that formula (species_base × cooking_extraction ×
-- freshness_polish × dry_age_mutation) is explicitly M5's job, once ConversionModule (M4) exists
-- to feed it. Today this file only owns the cast->hook->reel loop: validating Player_CastLine /
-- Player_ReelInput, rate-limiting them per player, running the authoritative fight simulation,
-- and resolving *what* got caught (species, quality) — never what it's worth.
--
-- Caught fish are intentionally NOT written to PlayerDataService inventory yet. Doing so would
-- require reaching into the PlayerDataService instance that PlayerDataService.server.lua owns
-- privately (Bootstrap.server.lua is still an empty stub — no service registry or injection
-- pattern exists yet for one Service script to reach another's state). Inventing that wiring as
-- a side effect here would be an undocumented cross-cutting architecture decision; it belongs
-- with M4, which needs the same access to feed ConversionModule.cook(fish) anyway. See
-- BUILD_LOG.md M3 entry.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local FishingCatch = require(ServerStorage.Modules.FishingCatch)
local FishingConfig = require(ReplicatedStorage.Config.FishingConfig)
local FishSpecies = require(ReplicatedStorage.Modules.FishSpecies)

local RemoteEvents = ReplicatedStorage.Events.RemoteEvents
local castLineRemote: RemoteEvent = RemoteEvents.Player_CastLine
local reelInputRemote: RemoteEvent = RemoteEvents.Player_ReelInput
local biteWindowRemote: RemoteEvent = RemoteEvents.Fishing_BiteWindow
local fightResultRemote: RemoteEvent = RemoteEvents.Fishing_FightResult

-- Shared-authoritative subset of FishingConfig the fight simulation needs (client-only feel
-- knobs like tension rise/fall rate are deliberately excluded — the server never uses them).
local FIGHT_CONFIG: FishingCatch.FightConfig = {
    HOOK_REACTION_WINDOW_SECONDS = FishingConfig.HOOK_REACTION_WINDOW_SECONDS,
    FIGHT_DURATION_SECONDS = FishingConfig.FIGHT_DURATION_SECONDS,
    TENSION_TARGET_MIN = FishingConfig.TENSION_TARGET_MIN,
    TENSION_TARGET_MAX = FishingConfig.TENSION_TARGET_MAX,
    TENSION_SNAP_THRESHOLD = FishingConfig.TENSION_SNAP_THRESHOLD,
    PROGRESS_GAIN_PER_SECOND_IN_BAND = FishingConfig.PROGRESS_GAIN_PER_SECOND_IN_BAND,
    PROGRESS_DECAY_PER_SECOND_OUT_OF_BAND = FishingConfig.PROGRESS_DECAY_PER_SECOND_OUT_OF_BAND,
}

type PlayerFishingState = {
    lastCastAt: number?,
    pendingCast: boolean,
    lastReelInputAt: number?,
    fight: FishingCatch.FightState?,
}

local playerStates: { [number]: PlayerFishingState } = {}

local function _stateFor(userId: number): PlayerFishingState
    local state = playerStates[userId]
    if not state then
        state = { lastCastAt = nil, pendingCast = false, lastReelInputAt = nil, fight = nil }
        playerStates[userId] = state
    end
    return state
end

local function _getCharacterRoot(player: Player): BasePart?
    local character = player.Character
    return character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

local function _endFight(player: Player, state: PlayerFishingState, outcome: FishingCatch.FightOutcome): ()
    local fight = state.fight
    state.fight = nil
    if not fight then
        return
    end

    if outcome == "caught" then
        local qualityScore = FishingCatch.qualityScoreFor(fight)
        local catch = FishingCatch.rollCatch(FishSpecies.SPECIES, qualityScore)
        if catch then
            fightResultRemote:FireClient(player, fight.fightId, "caught", catch.speciesId, catch.quality)
            return
        end
        -- No species configured to roll against — treat as an escape rather than silently lying
        -- about a catch. Should never happen with FishSpecies.SPECIES populated; guards against
        -- a future edit that empties it without updating this fallback.
        fightResultRemote:FireClient(player, fight.fightId, "escaped", nil, nil)
        return
    end

    fightResultRemote:FireClient(player, fight.fightId, outcome, nil, nil)
end

-- Schedules the fight's own timeout resolution independent of further client input — if the
-- client stops sending Player_ReelInput entirely (dropped connection, exploiter silence), the
-- fight still resolves instead of leaving state.fight dangling forever.
local function _scheduleTimeout(player: Player, state: PlayerFishingState, fightId: string): ()
    local budgetSeconds = FishingConfig.HOOK_REACTION_WINDOW_SECONDS + FishingConfig.FIGHT_DURATION_SECONDS
    task.delay(budgetSeconds + 0.5, function()
        local fight = state.fight
        if not fight or fight.fightId ~= fightId then
            return
        end
        local _, outcome = FishingCatch.tick(fight, os.clock(), FIGHT_CONFIG)
        if outcome ~= "ongoing" then
            _endFight(player, state, outcome)
        end
    end)
end

local function _startBiteTimer(player: Player, state: PlayerFishingState): ()
    local waitSeconds =
        FishingCatch.rollBiteWaitSeconds(FishingConfig.BITE_WAIT_MIN_SECONDS, FishingConfig.BITE_WAIT_MAX_SECONDS)

    task.delay(waitSeconds, function()
        state.pendingCast = false

        if not Players:GetPlayerByUserId(player.UserId) then
            return
        end
        if state.fight ~= nil then
            return -- a stray timer from an already-superseded cast cycle; should not happen, but cheap to guard
        end

        local fightId = HttpService:GenerateGUID(false)
        state.fight = FishingCatch.newFight(os.clock(), fightId)
        biteWindowRemote:FireClient(player, fightId)
        _scheduleTimeout(player, state, fightId)
    end)
end

local function _onCastLine(player: Player, payload: any): ()
    local location = if typeof(payload) == "table" then payload.location else nil
    if not FishingCatch.isStructurallyValidLocation(location) then
        return
    end

    local root = _getCharacterRoot(player)
    if not root then
        return
    end
    if not FishingCatch.isLocationWithinRange(location, root.Position, FishingConfig.MAX_CAST_DISTANCE_STUDS) then
        return
    end

    local state = _stateFor(player.UserId)
    local now = os.clock()
    if state.fight ~= nil then
        return
    end
    if not FishingCatch.canCast(now, state.lastCastAt, state.pendingCast, FishingConfig.CAST_COOLDOWN_SECONDS) then
        return
    end

    state.lastCastAt = now
    state.pendingCast = true
    _startBiteTimer(player, state)
end

local function _onReelInput(player: Player, payload: any): ()
    local tension = if typeof(payload) == "table" then payload.tension else nil
    if not FishingCatch.isValidTension(tension) then
        return
    end

    local state = _stateFor(player.UserId)
    local fight = state.fight
    if not fight then
        return
    end

    local now = os.clock()
    if
        FishingCatch.shouldThrottleReelInput(now, state.lastReelInputAt, FishingConfig.MIN_REEL_INPUT_INTERVAL_SECONDS)
    then
        return
    end
    state.lastReelInputAt = now

    local updatedFight, outcome = FishingCatch.applyReelInput(fight, tension, now, FIGHT_CONFIG)
    state.fight = updatedFight

    if outcome ~= "ongoing" then
        _endFight(player, state, outcome)
    end
end

castLineRemote.OnServerEvent:Connect(_onCastLine)
reelInputRemote.OnServerEvent:Connect(_onReelInput)

Players.PlayerRemoving:Connect(function(player: Player)
    playerStates[player.UserId] = nil
end)
