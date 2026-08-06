-- EconomyService: server-side plate value resolution and catch validation; the client never resolves economy state
--
-- M3 scope note: this file owns the cast->hook->reel loop: validating Player_CastLine /
-- Player_ReelInput, rate-limiting them per player, running the authoritative fight simulation,
-- and resolving *what* got caught (species, quality) — never what it's worth. Full plate-value
-- resolution (species_base × cooking_extraction × freshness_polish × dry_age_mutation) is still
-- M5's job, once FishTable's authored cut_base[species][grade] lookup exists.
--
-- M4 addition: caught fish are now written into PlayerDataService inventory (deferred from M3 —
-- see BUILD_LOG.md M3 entry), and this file also validates the cook verb's Player_CookTrace /
-- Player_CookStroke inputs and drives ConversionModule.cook. Cross-service access to
-- PlayerDataService goes through PlayerDataAccess (see that module's header for why this isn't a
-- `_G` global). No dedicated CookService exists in PRD §7.1's file tree — cook-verb input
-- validation is architecturally the same shape as the fishing input validation already here
-- (authoritative resolution of a player-fired verb RemoteEvent), so it lives alongside it rather
-- than inventing an unlisted service file.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local FishingCatch = require(ServerStorage.Modules.FishingCatch)
local ConversionModule = require(ServerStorage.Modules.ConversionModule)
local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)
local FishingConfig = require(ReplicatedStorage.Config.FishingConfig)
local CookConfig = require(ReplicatedStorage.Config.CookConfig)
local FishSpecies = require(ReplicatedStorage.Modules.FishSpecies)

local RemoteEvents = ReplicatedStorage.Events.RemoteEvents
local castLineRemote: RemoteEvent = RemoteEvents.Player_CastLine
local reelInputRemote: RemoteEvent = RemoteEvents.Player_ReelInput
local biteWindowRemote: RemoteEvent = RemoteEvents.Fishing_BiteWindow
local fightResultRemote: RemoteEvent = RemoteEvents.Fishing_FightResult
local cookTraceRemote: RemoteEvent = RemoteEvents.Player_CookTrace
local cookStrokeRemote: RemoteEvent = RemoteEvents.Player_CookStroke
local portionsResolvedRemote: RemoteEvent = RemoteEvents.Cooking_PortionsResolved

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

-- Cook-verb pending state (M4). Separate table from playerStates/PlayerFishingState — cooking and
-- fishing are independent verbs with independent lifecycles, and conflating their state types
-- would make either one harder to reason about for no benefit.
type PendingCook = {
    fishId: string,
    traceAccuracy: number,
    loinCount: number,
    strokeQuality: { number },
    lastActionAt: number,
}

local playerCookStates: { [number]: PendingCook? } = {}

local function _findInventoryFish(data: any, fishId: string): any
    for _, fish in data.inventory do
        if fish.id == fishId then
            return fish
        end
    end
    return nil
end

local function _getCharacterRoot(player: Player): BasePart?
    local character = player.Character
    return character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

-- Deferred from M3 (BUILD_LOG.md M3 entry): writes the caught fish into PlayerDataService's
-- inventory via PlayerDataAccess, the cross-service access pattern M4 introduces (see that
-- module's header). Returns the generated fishId, or nil if PlayerData isn't loaded yet (e.g. a
-- race right at join) — the catch still displays client-side in that case, it just can't be
-- cooked, matching this fight-sim's existing best-effort stance on transient player state.
local function _writeCaughtFishToInventory(player: Player, speciesId: string): string?
    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return nil
    end

    local fishId = HttpService:GenerateGUID(false)
    table.insert(data.inventory, { id = fishId, species = speciesId, caughtAt = os.time() })
    return fishId
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
            local fishId = _writeCaughtFishToInventory(player, catch.speciesId)
            fightResultRemote:FireClient(player, fight.fightId, "caught", catch.speciesId, catch.quality, fishId)
            return
        end
        -- No species configured to roll against — treat as an escape rather than silently lying
        -- about a catch. Should never happen with FishSpecies.SPECIES populated; guards against
        -- a future edit that empties it without updating this fallback.
        fightResultRemote:FireClient(player, fight.fightId, "escaped", nil, nil, nil)
        return
    end

    fightResultRemote:FireClient(player, fight.fightId, outcome, nil, nil, nil)
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

-- Resolves a completed cook (all required performance inputs collected) into portions, removes
-- the source fish from inventory, and appends the results to cookedPortions. `fish` must already
-- be a live entry in `data.inventory` — callers look it up fresh right before calling this so a
-- stale/removed fish can't be cooked twice.
local function _resolveCook(player: Player, data: any, fish: any, traceAccuracy: number, strokeQuality: { number }): ()
    local species = FishSpecies.getById(fish.species)
    if not species then
        return
    end

    local cookingLevel = data.skills.cooking.level
    local portions = ConversionModule.cook(
        { prepTier = species.prepTier, loinCount = species.loinCount, maxYield = species.maxYield },
        { traceAccuracy = traceAccuracy, strokeQuality = strokeQuality },
        cookingLevel,
        CookConfig
    )

    for i, entry in data.inventory do
        if entry.id == fish.id then
            table.remove(data.inventory, i)
            break
        end
    end

    local now = os.time()
    for _, portion in portions do
        table.insert(data.cookedPortions, {
            id = HttpService:GenerateGUID(false),
            species = fish.species,
            grade = portion.grade,
            cookedAt = now,
        })
    end

    portionsResolvedRemote:FireClient(player, fish.id, portions)
end

-- Mirrors EconomyService's fishing-fight timeout pattern: if a client stops sending
-- Player_CookStroke mid-sequence (dropped connection, walked away), the pending-cook state still
-- gets cleaned up instead of leaking forever.
local function _scheduleCookTimeout(player: Player, fishId: string): ()
    task.delay(CookConfig.PENDING_COOK_TIMEOUT_SECONDS, function()
        local pending = playerCookStates[player.UserId]
        if pending and pending.fishId == fishId then
            playerCookStates[player.UserId] = nil
        end
    end)
end

local function _onCookTrace(player: Player, payload: any): ()
    local fishId = if typeof(payload) == "table" then payload.fishId else nil
    local traceAccuracy = if typeof(payload) == "table" then payload.traceAccuracy else nil
    -- isValidTension is a generic [0,1]-finite-number check; reused rather than duplicated —
    -- trace accuracy has the identical validity shape as reel tension (FishingCatch.lua).
    if type(fishId) ~= "string" or not FishingCatch.isValidTension(traceAccuracy) then
        return
    end

    local now = os.clock()
    local existingPending = playerCookStates[player.UserId]
    if existingPending and (now - existingPending.lastActionAt) < CookConfig.MIN_COOK_ACTION_INTERVAL_SECONDS then
        return
    end

    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    local fish = _findInventoryFish(data, fishId)
    if not fish then
        return
    end

    local species = FishSpecies.getById(fish.species)
    if not species then
        return
    end

    if species.prepTier == "quick" or species.loinCount <= 0 then
        _resolveCook(player, data, fish, traceAccuracy, {})
        return
    end

    playerCookStates[player.UserId] = {
        fishId = fishId,
        traceAccuracy = traceAccuracy,
        loinCount = species.loinCount,
        strokeQuality = {},
        lastActionAt = now,
    }
    _scheduleCookTimeout(player, fishId)
end

local function _onCookStroke(player: Player, payload: any): ()
    local fishId = if typeof(payload) == "table" then payload.fishId else nil
    local loinIndex = if typeof(payload) == "table" then payload.loinIndex else nil
    local strokeQuality = if typeof(payload) == "table" then payload.strokeQuality else nil

    if type(fishId) ~= "string" or type(loinIndex) ~= "number" or not FishingCatch.isValidTension(strokeQuality) then
        return
    end

    local pending = playerCookStates[player.UserId]
    if not pending or pending.fishId ~= fishId then
        return
    end
    if loinIndex < 1 or loinIndex > pending.loinCount or math.floor(loinIndex) ~= loinIndex then
        return
    end
    if pending.strokeQuality[loinIndex] ~= nil then
        return -- already submitted for this loin — one pass, committed, no retry (cook-verb.md §2.2)
    end

    local now = os.clock()
    if (now - pending.lastActionAt) < CookConfig.MIN_COOK_ACTION_INTERVAL_SECONDS then
        return
    end
    pending.lastActionAt = now
    pending.strokeQuality[loinIndex] = strokeQuality

    local submittedCount = 0
    for i = 1, pending.loinCount do
        if pending.strokeQuality[i] ~= nil then
            submittedCount += 1
        end
    end
    if submittedCount < pending.loinCount then
        return
    end

    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        playerCookStates[player.UserId] = nil
        return
    end

    local fish = _findInventoryFish(data, fishId)
    if not fish then
        playerCookStates[player.UserId] = nil
        return
    end

    playerCookStates[player.UserId] = nil
    _resolveCook(player, data, fish, pending.traceAccuracy, pending.strokeQuality)
end

castLineRemote.OnServerEvent:Connect(_onCastLine)
reelInputRemote.OnServerEvent:Connect(_onReelInput)
cookTraceRemote.OnServerEvent:Connect(_onCookTrace)
cookStrokeRemote.OnServerEvent:Connect(_onCookStroke)

Players.PlayerRemoving:Connect(function(player: Player)
    playerStates[player.UserId] = nil
    playerCookStates[player.UserId] = nil
end)
