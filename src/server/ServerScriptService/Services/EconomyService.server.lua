-- EconomyService: server-side plate value resolution and catch validation; the client never resolves economy state
--
-- M3 scope note: this file owns the cast->hook->reel loop: validating Player_CastLine /
-- Player_ReelInput, rate-limiting them per player, running the authoritative fight simulation,
-- and resolving *what* got caught (species, quality) — never what it's worth. Full plate-value
-- resolution (cut_base[species][grade] × cooking_extraction × freshness_polish × dry_age_mutation)
-- is M5's job, below, once served via the boat serve verb.
--
-- M4 addition: caught fish are now written into PlayerDataService inventory (deferred from M3 —
-- see BUILD_LOG.md M3 entry), and this file also validates the cook verb's Player_CookTrace /
-- Player_CookStroke inputs and drives ConversionModule.cook. Cross-service access to
-- PlayerDataService goes through PlayerDataAccess (see that module's header for why this isn't a
-- `_G` global). No dedicated CookService exists in PRD §7.1's file tree — cook-verb input
-- validation is architecturally the same shape as the fishing input validation already here
-- (authoritative resolution of a player-fired verb RemoteEvent), so it lives alongside it rather
-- than inventing an unlisted service file.
--
-- M5 addition: this file also validates the boat serve verb's Player_ServePlate and resolves
-- served_plate_value via PlateValueResolver.lua (PRD §5's one faucet) — same "lives alongside the
-- existing verb-input validation rather than a new service file" reasoning as M4's cook verb.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local FishingCatch = require(ServerStorage.Modules.FishingCatch)
local ConversionModule = require(ServerStorage.Modules.ConversionModule)
local PlateValueResolver = require(ServerStorage.Modules.PlateValueResolver)
local FishTable = require(ServerStorage.Modules.FishTable)
local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)
local FishingConfig = require(ReplicatedStorage.Config.FishingConfig)
local CookConfig = require(ReplicatedStorage.Config.CookConfig)
local EconomyConfig = require(ReplicatedStorage.Config.EconomyConfig)
local FishSpecies = require(ReplicatedStorage.Modules.FishSpecies)

local RemoteEvents = ReplicatedStorage.Events.RemoteEvents
local castLineRemote: RemoteEvent = RemoteEvents.Player_CastLine
local reelInputRemote: RemoteEvent = RemoteEvents.Player_ReelInput
local biteWindowRemote: RemoteEvent = RemoteEvents.Fishing_BiteWindow
local fightResultRemote: RemoteEvent = RemoteEvents.Fishing_FightResult
local cookTraceRemote: RemoteEvent = RemoteEvents.Player_CookTrace
local cookStrokeRemote: RemoteEvent = RemoteEvents.Player_CookStroke
local portionsResolvedRemote: RemoteEvent = RemoteEvents.Cooking_PortionsResolved
local servePlateRemote: RemoteEvent = RemoteEvents.Player_ServePlate
local plateResolvedRemote: RemoteEvent = RemoteEvents.Economy_PlateResolved

-- PRD §5's cooking_extraction reuses CookConfig's existing "cooking level ceiling" constant
-- (see EconomyConfig.lua's header for why this isn't duplicated there) rather than defining a
-- second, potentially divergent one for the same concept.
local PLATE_VALUE_TUNING: PlateValueResolver.PlateValueTuning = {
    MAX_COOKING_LEVEL_FOR_EXTRACTION = CookConfig.MAX_COOKING_LEVEL_FOR_EXTRACTION,
    CLAMP_FRESHNESS_MIN = EconomyConfig.CLAMP_FRESHNESS_MIN,
    CLAMP_FRESHNESS_MAX = EconomyConfig.CLAMP_FRESHNESS_MAX,
    FRESHNESS_DECAY_WINDOW_SECONDS = EconomyConfig.FRESHNESS_DECAY_WINDOW_SECONDS,
    DRY_AGE_MUTATION_BASELINE = EconomyConfig.DRY_AGE_MUTATION_BASELINE,
}

-- Shared-authoritative subset of FishingConfig the fight simulation needs (client-only feel
-- knobs like tension rise/fall rate are deliberately excluded — the server never uses them).
local FIGHT_CONFIG: FishingCatch.FightConfig = {
    HOOK_REACTION_WINDOW_SECONDS = FishingConfig.HOOK_REACTION_WINDOW_SECONDS,
    FIGHT_DURATION_SECONDS = FishingConfig.FIGHT_DURATION_SECONDS,
    FISH_CENTER = FishingConfig.FISH_CENTER,
    CATCH_BOX_WIDTH = FishingConfig.CATCH_BOX_WIDTH,
    FISH_MOTION_AMPLITUDE_1 = FishingConfig.FISH_MOTION_AMPLITUDE_1,
    FISH_MOTION_FREQUENCY_1 = FishingConfig.FISH_MOTION_FREQUENCY_1,
    FISH_MOTION_AMPLITUDE_2 = FishingConfig.FISH_MOTION_AMPLITUDE_2,
    FISH_MOTION_FREQUENCY_2 = FishingConfig.FISH_MOTION_FREQUENCY_2,
    FISH_MOTION_PHASE_2 = FishingConfig.FISH_MOTION_PHASE_2,
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

-- Serve-verb debounce (M5). Separate table for the same reason playerCookStates is separate from
-- playerStates: serving is its own verb lifecycle, not a variant of fishing or cooking state.
local playerLastServeAt: { [number]: number } = {}

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
            warn(("[EconomyService][debug] %s: bite timer fired but player is gone"):format(player.Name))
            return
        end
        if state.fight ~= nil then
            warn(
                ("[EconomyService][debug] %s: bite timer fired but a fight already exists (stray timer)"):format(
                    player.Name
                )
            )
            return -- a stray timer from an already-superseded cast cycle; should not happen, but cheap to guard
        end

        local fightId = HttpService:GenerateGUID(false)
        state.fight = FishingCatch.newFight(os.clock(), fightId)
        warn(
            ("[EconomyService][debug] %s: bite timer fired after %.1fs, firing Fishing_BiteWindow"):format(
                player.Name,
                waitSeconds
            )
        )
        biteWindowRemote:FireClient(player, fightId)
        _scheduleTimeout(player, state, fightId)
    end)
end

-- TEMPORARY (2026-08-06): this loop has never been playtested in real Studio (BUILD_LOG.md M3
-- entry) and every rejection below is otherwise silent by design (anti-spoof: no oracle for a
-- spoofed client). Giahy hit "stuck on waiting for a bite" with no way to tell why. These warns
-- are diagnostic scaffolding for that session, not a permanent behavior change — remove once the
-- cast->bite path is confirmed working end-to-end in Studio.
local function _onCastLine(player: Player, payload: any): ()
    local location = if typeof(payload) == "table" then payload.location else nil
    if not FishingCatch.isStructurallyValidLocation(location) then
        warn(("[EconomyService][debug] %s: cast rejected — structurally invalid location"):format(player.Name))
        return
    end

    local root = _getCharacterRoot(player)
    if not root then
        warn(
            ("[EconomyService][debug] %s: cast rejected — no HumanoidRootPart (character not spawned/loaded yet)"):format(
                player.Name
            )
        )
        return
    end
    if not FishingCatch.isLocationWithinRange(location, root.Position, FishingConfig.MAX_CAST_DISTANCE_STUDS) then
        local dx, dy, dz = location.X - root.Position.X, location.Y - root.Position.Y, location.Z - root.Position.Z
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        warn(
            ("[EconomyService][debug] %s: cast rejected — target %.1f studs from character, max is %d (root=%s, target=%s)"):format(
                player.Name,
                distance,
                FishingConfig.MAX_CAST_DISTANCE_STUDS,
                tostring(root.Position),
                tostring(location)
            )
        )
        return
    end

    local state = _stateFor(player.UserId)
    local now = os.clock()
    if state.fight ~= nil then
        warn(("[EconomyService][debug] %s: cast rejected — already mid-fight"):format(player.Name))
        return
    end
    if not FishingCatch.canCast(now, state.lastCastAt, state.pendingCast, FishingConfig.CAST_COOLDOWN_SECONDS) then
        warn(
            ("[EconomyService][debug] %s: cast rejected — cooldown/pending-cast guard (pendingCast=%s)"):format(
                player.Name,
                tostring(state.pendingCast)
            )
        )
        return
    end

    state.lastCastAt = now
    state.pendingCast = true
    warn(("[EconomyService][debug] %s: cast ACCEPTED, waiting on bite timer"):format(player.Name))
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

    -- Each cooked portion needs its server-assigned id sent back to the client (not just its
    -- grade) so BoatCookController can later name a specific portion in Player_ServePlate — the
    -- serve verb resolves one cookedPortions entry at a time, the same shape as _onCookStroke
    -- addressing one loin at a time.
    local now = os.time()
    local resolvedPortions: { { id: string, grade: string } } = {}
    for _, portion in portions do
        local cookedPortion = {
            id = HttpService:GenerateGUID(false),
            species = fish.species,
            grade = portion.grade,
            cookedAt = now,
        }
        table.insert(data.cookedPortions, cookedPortion)
        table.insert(resolvedPortions, { id = cookedPortion.id, grade = cookedPortion.grade })
    end

    portionsResolvedRemote:FireClient(player, fish.id, resolvedPortions)
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

-- Boat serve verb (M5, PRD §4/§5): pure delivery — resolves one cookedPortions entry into gold
-- via PlateValueResolver and removes it from inventory. No order matching, no plating minigame;
-- the "verb" is the button press itself (docs/design/cook-verb.md's serve-verb scope).
local function _onServePlate(player: Player, payload: any): ()
    local portionId = if typeof(payload) == "table" then payload.portionId else nil
    if type(portionId) ~= "string" then
        return
    end

    local now = os.clock()
    local lastServeAt = playerLastServeAt[player.UserId]
    if lastServeAt and (now - lastServeAt) < EconomyConfig.MIN_SERVE_ACTION_INTERVAL_SECONDS then
        return
    end

    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    local portionIndex, portion = nil, nil
    for i, entry in data.cookedPortions do
        if entry.id == portionId then
            portionIndex, portion = i, entry
            break
        end
    end
    if not portion then
        return -- already served, or never existed — expected-failure path (PRD §8), not an error
    end

    local cutBase = FishTable.cutBaseFor(portion.species, portion.grade)
    if not cutBase then
        -- Refuse rather than resolve an undefined price as 0/nil — a missing FishTable row is a
        -- content gap (see FishTable.lua's header), not a state a served plate should silently
        -- pass through.
        warn(
            ("[EconomyService] no FishTable.cutBase for %s/%s — refusing to resolve the plate"):format(
                portion.species,
                portion.grade
            )
        )
        return
    end

    playerLastServeAt[player.UserId] = now

    local freshnessElapsedSeconds = math.max(os.time() - portion.cookedAt, 0)
    local plateValue, breakdown = PlateValueResolver.resolve({
        cutBase = cutBase,
        cookingLevel = data.skills.cooking.level,
        freshnessElapsedSeconds = freshnessElapsedSeconds,
    }, PLATE_VALUE_TUNING)

    table.remove(data.cookedPortions, portionIndex)
    data.economy.gold += plateValue

    plateResolvedRemote:FireClient(player, plateValue, breakdown)
end

castLineRemote.OnServerEvent:Connect(_onCastLine)
reelInputRemote.OnServerEvent:Connect(_onReelInput)
cookTraceRemote.OnServerEvent:Connect(_onCookTrace)
cookStrokeRemote.OnServerEvent:Connect(_onCookStroke)
servePlateRemote.OnServerEvent:Connect(_onServePlate)

Players.PlayerRemoving:Connect(function(player: Player)
    playerStates[player.UserId] = nil
    playerCookStates[player.UserId] = nil
    playerLastServeAt[player.UserId] = nil
end)
