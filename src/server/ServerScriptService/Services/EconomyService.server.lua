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
--
-- M14 addition: a cast's bite can resolve into a legendary encounter instead of a normal fight —
-- WeatherAccess (read-only, mirrors PlayerDataAccess) tells this file whether the cast's zone is
-- the active storm's zone; WeatherRoll resolves the odds roll; LegendaryFight computes each
-- phase's harder FightConfig. The fight simulation itself is NOT reimplemented — every phase still
-- runs through the exact same FishingCatch.newFight/applyReelInput/tick a normal catch uses (PRD
-- §4: "not a bespoke combat system"), just with a per-phase config instead of the shared FIGHT_CONFIG.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local FishingCatch = require(ServerStorage.Modules.FishingCatch)
local ConversionModule = require(ServerStorage.Modules.ConversionModule)
local PlateValueResolver = require(ServerStorage.Modules.PlateValueResolver)
local FishTable = require(ServerStorage.Modules.FishTable)
local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)
local WeatherAccess = require(ServerStorage.Modules.WeatherAccess)
local WeatherRoll = require(ServerStorage.Modules.WeatherRoll)
local LegendaryFight = require(ServerStorage.Modules.LegendaryFight)
local DryAgingLocker = require(ServerStorage.Modules.DryAgingLocker)
local FishingConfig = require(ReplicatedStorage.Config.FishingConfig)
local CookConfig = require(ReplicatedStorage.Config.CookConfig)
local EconomyConfig = require(ReplicatedStorage.Config.EconomyConfig)
local WeatherConfig = require(ReplicatedStorage.Config.WeatherConfig)
local AgingConfig = require(ReplicatedStorage.Config.AgingConfig)
local FishSpecies = require(ReplicatedStorage.Modules.FishSpecies)

local RemoteEvents = ReplicatedStorage.Events.RemoteEvents
local castLineRemote: RemoteEvent = RemoteEvents.Player_CastLine
local reelInputRemote: RemoteEvent = RemoteEvents.Player_ReelInput
local biteWindowRemote: RemoteEvent = RemoteEvents.Fishing_BiteWindow
local fightResultRemote: RemoteEvent = RemoteEvents.Fishing_FightResult
local legendaryPhaseAdvancedRemote: RemoteEvent = RemoteEvents.Fishing_LegendaryPhaseAdvanced
local cookTraceRemote: RemoteEvent = RemoteEvents.Player_CookTrace
local cookStrokeRemote: RemoteEvent = RemoteEvents.Player_CookStroke
local portionsResolvedRemote: RemoteEvent = RemoteEvents.Cooking_PortionsResolved
local servePlateRemote: RemoteEvent = RemoteEvents.Player_ServePlate
local plateResolvedRemote: RemoteEvent = RemoteEvents.Economy_PlateResolved
local goldUpdateRemote: RemoteEvent = RemoteEvents.Economy_GoldUpdate
local purchaseStorageTierRemote: RemoteEvent = RemoteEvents.Player_PurchaseStorageTier
local storageTierUpdateRemote: RemoteEvent = RemoteEvents.Storage_TierUpdate
local placeInAgingLockerRemote: RemoteEvent = RemoteEvents.Player_PlaceInAgingLocker
local pullFromLockerRemote: RemoteEvent = RemoteEvents.Player_PullFromLocker
local purchaseAgingLockerTierRemote: RemoteEvent = RemoteEvents.Player_PurchaseAgingLockerTier
local agingLockerUpdateRemote: RemoteEvent = RemoteEvents.Aging_LockerUpdate
local mountTrophyRemote: RemoteEvent = RemoteEvents.Player_MountTrophy
local giftFishRemote: RemoteEvent = RemoteEvents.Player_GiftFish
local trophyUpdateRemote: RemoteEvent = RemoteEvents.Restaurant_TrophyUpdate

local LEGENDARY_TUNING: LegendaryFight.LegendaryTuning = {
    PHASE_COUNT = WeatherConfig.LEGENDARY_PHASE_COUNT,
    PHASE_WIDTH_MULTIPLIER = WeatherConfig.LEGENDARY_PHASE_WIDTH_MULTIPLIER,
    MIN_CATCH_BOX_WIDTH = WeatherConfig.LEGENDARY_MIN_CATCH_BOX_WIDTH,
    LEVEL_RELIEF_PER_LEVEL = WeatherConfig.LEGENDARY_LEVEL_RELIEF_PER_LEVEL,
    MAX_LEVEL_RELIEF = WeatherConfig.LEGENDARY_MAX_LEVEL_RELIEF,
    MAX_FISHING_LEVEL_FOR_RELIEF = WeatherConfig.LEGENDARY_MAX_FISHING_LEVEL_FOR_RELIEF,
}

local AGING_TUNING: DryAgingLocker.AgingTuning = {
    PEAK_MULTIPLIER = AgingConfig.PEAK_MULTIPLIER,
    PEAK_SECONDS = AgingConfig.PEAK_SECONDS,
    MUTATION_CHANCE = AgingConfig.MUTATION_CHANCE,
    MIN_MUTATION_BONUS = AgingConfig.MIN_MUTATION_BONUS,
    MAX_MUTATION_BONUS = AgingConfig.MAX_MUTATION_BONUS,
}

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
    -- M14 additions: pendingCastZone is stashed at cast time (WeatherRoll.zoneFor) so the bite
    -- timer, which fires later, can check it against the then-current storm. activeFightConfig is
    -- the FightConfig actually driving `fight` right now — FIGHT_CONFIG for a normal fight, or a
    -- phase-specific override for a legendary one. legendaryPhaseIndex/legendaryType are set only
    -- while a legendary encounter is in progress.
    pendingCastZone: string?,
    activeFightConfig: FishingCatch.FightConfig?,
    legendaryPhaseIndex: number?,
    legendaryType: string?,
}

local playerStates: { [number]: PlayerFishingState } = {}

local function _stateFor(userId: number): PlayerFishingState
    local state = playerStates[userId]
    if not state then
        state = {
            lastCastAt = nil,
            pendingCast = false,
            lastReelInputAt = nil,
            fight = nil,
            pendingCastZone = nil,
            activeFightConfig = nil,
            legendaryPhaseIndex = nil,
            legendaryType = nil,
        }
        playerStates[userId] = state
    end
    return state
end

-- Phase 1 = the base FIGHT_CONFIG's own width/duration; later phases narrow the catch box
-- (LegendaryFight.catchBoxWidthFor) and stretch the duration to WeatherConfig's legendary phase
-- length. table.clone so mutating the copy never touches the shared FIGHT_CONFIG.
local function _legendaryFightConfigFor(phaseIndex: number, fishingLevel: number): FishingCatch.FightConfig
    local config = table.clone(FIGHT_CONFIG)
    config.CATCH_BOX_WIDTH =
        LegendaryFight.catchBoxWidthFor(phaseIndex, fishingLevel, FishingConfig.CATCH_BOX_WIDTH, LEGENDARY_TUNING)
    config.FIGHT_DURATION_SECONDS = WeatherConfig.LEGENDARY_PHASE_DURATION_SECONDS
    return config
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

-- Forward-declared: _endFight (M14's phase-advance branch) and _scheduleTimeout call each other —
-- same mutual-recursion shape BoatCookController.lua's trace/stroke chain already documents.
local _scheduleTimeout: (player: Player, state: PlayerFishingState, fightId: string, fightDurationSeconds: number) -> ()

-- Deferred from M3 (BUILD_LOG.md M3 entry): writes the caught fish into PlayerDataService's
-- inventory via PlayerDataAccess, the cross-service access pattern M4 introduces (see that
-- module's header). Returns the generated fishId, or nil if PlayerData isn't loaded yet (e.g. a
-- race right at join) or the player's storage is already at capacity (M8, PRD §4's "forces
-- restocking" leash extends to a hard cap, not just a timer) — the catch still displays
-- client-side in either case, it just can't be cooked, matching this fight-sim's existing
-- best-effort stance on transient/edge-case player state.
local function _writeCaughtFishToInventory(player: Player, speciesId: string): string?
    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return nil
    end

    local tierData = EconomyConfig.STORAGE_TIERS[data.storage.tier] or EconomyConfig.STORAGE_TIERS[0]
    if #data.inventory >= tierData.capacity then
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

    -- M14: a legendary encounter in progress. Succeeding a non-final phase advances instead of
    -- ending; anything else (a final-phase catch, or a failure at any phase) terminates the whole
    -- encounter here — no partial credit for a partly-fought legendary (PRD §4: "no buy-in, no
    -- loss penalty. Losing costs nothing but the moment").
    if state.legendaryPhaseIndex then
        if outcome == "caught" and not LegendaryFight.isFinalPhase(state.legendaryPhaseIndex, LEGENDARY_TUNING) then
            local nextPhase = state.legendaryPhaseIndex + 1
            local dataService = PlayerDataAccess.getInstance()
            local data = dataService and dataService:get(player.UserId)
            local fishingLevel = if data then data.skills.fishing.level else 1
            local nextConfig = _legendaryFightConfigFor(nextPhase, fishingLevel)

            state.legendaryPhaseIndex = nextPhase
            state.activeFightConfig = nextConfig
            state.fight = FishingCatch.newFight(os.clock(), fight.fightId)

            legendaryPhaseAdvancedRemote:FireClient(
                player,
                fight.fightId,
                nextPhase,
                nextConfig.CATCH_BOX_WIDTH,
                nextConfig.FIGHT_DURATION_SECONDS
            )
            _scheduleTimeout(player, state, fight.fightId, nextConfig.FIGHT_DURATION_SECONDS)
            return
        end

        local legendaryType = state.legendaryType
        state.legendaryPhaseIndex = nil
        state.legendaryType = nil
        state.activeFightConfig = nil

        if outcome == "caught" then
            local fishId = legendaryType and _writeCaughtFishToInventory(player, legendaryType)
            fightResultRemote:FireClient(player, fight.fightId, "caught", legendaryType, "legendary", fishId)
        else
            fightResultRemote:FireClient(player, fight.fightId, outcome, nil, nil, nil)
        end
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
-- fight still resolves instead of leaving state.fight dangling forever. `fightDurationSeconds` is
-- the currently-active phase's duration (M14: legendary phases run longer than a normal fight),
-- not always FishingConfig.FIGHT_DURATION_SECONDS.
_scheduleTimeout = function(
    player: Player,
    state: PlayerFishingState,
    fightId: string,
    fightDurationSeconds: number
): ()
    local budgetSeconds = FishingConfig.HOOK_REACTION_WINDOW_SECONDS + fightDurationSeconds
    task.delay(budgetSeconds + 0.5, function()
        local fight = state.fight
        if not fight or fight.fightId ~= fightId then
            return
        end
        local _, outcome = FishingCatch.tick(fight, os.clock(), state.activeFightConfig or FIGHT_CONFIG)
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

        -- M14: weather-triggered legendary roll. "Weather-triggered, not summonable" (PRD §4) is
        -- read literally — this can only succeed while a storm is active AND the cast landed in
        -- that storm's zone; there is no separate ambient/baseline chance outside that condition.
        local storm = WeatherAccess.getCurrentStorm()
        local inActiveZone = storm ~= nil and state.pendingCastZone ~= nil and state.pendingCastZone == storm.zone
        local legendaryOdds = if inActiveZone
            then WeatherConfig.BASELINE_LEGENDARY_ODDS_PER_CAST * WeatherConfig.IN_ZONE_LEGENDARY_ODDS_MULTIPLIER
            else 0
        local isLegendary = inActiveZone and WeatherRoll.shouldTriggerLegendary(legendaryOdds)

        local fightConfig = FIGHT_CONFIG
        if isLegendary then
            local dataService = PlayerDataAccess.getInstance()
            local data = dataService and dataService:get(player.UserId)
            local fishingLevel = if data then data.skills.fishing.level else 1
            fightConfig = _legendaryFightConfigFor(1, fishingLevel)
            state.legendaryPhaseIndex = 1
            state.legendaryType = (storm :: WeatherAccess.Storm).legendaryType
        else
            state.legendaryPhaseIndex = nil
            state.legendaryType = nil
        end
        state.activeFightConfig = fightConfig

        local fightId = HttpService:GenerateGUID(false)
        state.fight = FishingCatch.newFight(os.clock(), fightId)
        warn(
            ("[EconomyService][debug] %s: bite timer fired after %.1fs, firing Fishing_BiteWindow%s"):format(
                player.Name,
                waitSeconds,
                if isLegendary then " (LEGENDARY)" else ""
            )
        )
        biteWindowRemote:FireClient(
            player,
            fightId,
            fightConfig.CATCH_BOX_WIDTH,
            fightConfig.FIGHT_DURATION_SECONDS,
            isLegendary
        )
        _scheduleTimeout(player, state, fightId, fightConfig.FIGHT_DURATION_SECONDS)
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
    state.pendingCastZone = WeatherRoll.zoneFor(location, WeatherConfig.ZONE_SIZE_STUDS)
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

    local updatedFight, outcome =
        FishingCatch.applyReelInput(fight, tension, now, state.activeFightConfig or FIGHT_CONFIG)
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
    -- M15: `fish.dryAgeMutation` is only set when this fish was just pulled from the aging locker
    -- (see _onPullFromLocker) — carried forward onto every resulting portion so
    -- PlateValueResolver.resolve sees it at serve time. nil for an ordinarily-caught fish, same as
    -- before this addition.
    local now = os.time()
    local resolvedPortions: { { id: string, grade: string } } = {}
    for _, portion in portions do
        local cookedPortion = {
            id = HttpService:GenerateGUID(false),
            species = fish.species,
            grade = portion.grade,
            cookedAt = now,
            dryAgeMutation = fish.dryAgeMutation,
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
    if
        species.rarity == "legendary"
        and data.skills.cooking.level < CookConfig.MIN_COOKING_LEVEL_FOR_LEGENDARY_BUTCHER
    then
        return -- not Cooking-gated open yet (M16, PRD §4) — mount it instead, or wait to level up
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
        dryAgeMutation = portion.dryAgeMutation,
    }, PLATE_VALUE_TUNING)

    table.remove(data.cookedPortions, portionIndex)
    data.economy.gold += plateValue

    plateResolvedRemote:FireClient(player, plateValue, breakdown)
    goldUpdateRemote:FireClient(player, data.economy.gold)
end

-- Storage tier purchase (M8, PRD §12 Thread #5 partial resolution). No dedicated PurchasingService
-- exists in PRD §7.1's file tree — same "lives alongside the existing verb-input validation
-- rather than inventing an unlisted service file" reasoning M4/M5's headers already documented for
-- their own Player_* handlers. One tier per press, no batching, matching every other verb here.
local function _onPurchaseStorageTier(player: Player): ()
    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    local nextTier = data.storage.tier + 1
    local tierData = EconomyConfig.STORAGE_TIERS[nextTier]
    if not tierData then
        return -- already at EconomyConfig.MAX_STORAGE_TIER — expected-failure path, not an error
    end
    if data.economy.gold < tierData.upgradeCost then
        return -- can't afford it — expected-failure path (PRD §8), not an error
    end

    data.economy.gold -= tierData.upgradeCost
    data.storage.tier = nextTier

    goldUpdateRemote:FireClient(player, data.economy.gold)
    local afterNextTierData = EconomyConfig.STORAGE_TIERS[nextTier + 1]
    storageTierUpdateRemote:FireClient(player, {
        tier = data.storage.tier,
        name = tierData.name,
        capacity = tierData.capacity,
        nextTierCost = if afterNextTierData then afterNextTierData.upgradeCost else nil,
    })
end

local function _pushAgingLockerUpdate(player: Player, data: any): ()
    local tierData = AgingConfig.LOCKER_TIERS[data.agingLockerEquipment.tier]
    local nextTierData = AgingConfig.LOCKER_TIERS[data.agingLockerEquipment.tier + 1]
    local locker = {}
    for _, fish in data.agingLocker do
        table.insert(locker, { slot = fish.slot, species = fish.species, placedAt = fish.placedAt })
    end
    agingLockerUpdateRemote:FireClient(player, {
        tier = data.agingLockerEquipment.tier,
        slots = if tierData then tierData.slots else 0,
        nextTierCost = if nextTierData then nextTierData.upgradeCost else nil,
        locker = locker,
    })
end

-- Aging locker equipment purchase (M15). Same "lives alongside the existing verb-input validation
-- rather than inventing an unlisted service file" reasoning as the storage tier purchase above —
-- yet another distinct Purchasing category, so it sits next to that one.
local function _onPurchaseAgingLockerTier(player: Player): ()
    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    local nextTier = data.agingLockerEquipment.tier + 1
    local tierData = AgingConfig.LOCKER_TIERS[nextTier]
    if not tierData then
        return -- already at AgingConfig.MAX_LOCKER_TIER — expected-failure path, not an error
    end
    if data.economy.gold < tierData.upgradeCost then
        return
    end

    data.economy.gold -= tierData.upgradeCost
    data.agingLockerEquipment.tier = nextTier

    goldUpdateRemote:FireClient(player, data.economy.gold)
    _pushAgingLockerUpdate(player, data)
end

-- Place a raw fish on the aging track (M15, PRD §4: "leaves the spoilage track and enters the
-- aging track"). Slot numbers are the lowest unused integer in [1, tierData.slots] — reused once
-- freed, not a monotonically increasing counter, so a full-then-partially-emptied locker doesn't
-- run out of representable slot numbers.
local function _onPlaceInAgingLocker(player: Player, payload: any): ()
    local fishId = if typeof(payload) == "table" then payload.fishId else nil
    if type(fishId) ~= "string" then
        return
    end

    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    local tierData = AgingConfig.LOCKER_TIERS[data.agingLockerEquipment.tier]
    if not tierData or #data.agingLocker >= tierData.slots then
        return -- no locker owned yet, or it's full — expected-failure path, not an error
    end

    local fishIndex, fish = nil, nil
    for i, entry in data.inventory do
        if entry.id == fishId then
            fishIndex, fish = i, entry
            break
        end
    end
    if not fish then
        return
    end

    local usedSlots = {}
    for _, entry in data.agingLocker do
        usedSlots[entry.slot] = true
    end
    local slot = 1
    while usedSlots[slot] do
        slot += 1
    end

    table.remove(data.inventory, fishIndex)
    table.insert(data.agingLocker, { slot = slot, species = fish.species, placedAt = os.time() })

    _pushAgingLockerUpdate(player, data)
end

-- Pull a fish back off the aging track (M15, PRD §7.2 `Player_PullFromLocker — {slot}`): resolves
-- the aging multiplier + rare mutation roll once, here, and stamps it onto the fish as it re-enters
-- raw inventory — re-entering the spoilage track with a fresh `caughtAt`, since it left that track
-- entirely while aging (PRD §4) rather than having spoiled invisibly the whole time.
local function _onPullFromLocker(player: Player, payload: any): ()
    local slot = if typeof(payload) == "table" then payload.slot else nil
    if type(slot) ~= "number" then
        return
    end

    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    local lockerIndex, agingFish = nil, nil
    for i, entry in data.agingLocker do
        if entry.slot == slot then
            lockerIndex, agingFish = i, entry
            break
        end
    end
    if not agingFish then
        return -- empty slot, or never existed — expected-failure path, not an error
    end

    local agedSeconds = math.max(os.time() - agingFish.placedAt, 0)
    local dryAgeMutation = DryAgingLocker.resolveDryAgeMutation(agedSeconds, AGING_TUNING)

    table.remove(data.agingLocker, lockerIndex)
    table.insert(data.inventory, {
        id = HttpService:GenerateGUID(false),
        species = agingFish.species,
        caughtAt = os.time(),
        dryAgeMutation = dryAgeMutation,
    })

    _pushAgingLockerUpdate(player, data)
end

-- Trophy mount (M16, PRD §4: "pure public flex, decay-free, and goal-markers for catches you
-- can't yet butcher"). Restricted to legendary rarity — the design explicitly frames mounts as the
-- alternative to butchering a legendary you're not Cooking-level-gated to process yet, not a
-- general-purpose display case for any catch.
local function _onMountTrophy(player: Player, payload: any): ()
    local fishId = if typeof(payload) == "table" then payload.fishId else nil
    if type(fishId) ~= "string" then
        return
    end

    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    local fishIndex, fish = nil, nil
    for i, entry in data.inventory do
        if entry.id == fishId then
            fishIndex, fish = i, entry
            break
        end
    end
    if not fish then
        return
    end

    local species = FishSpecies.getById(fish.species)
    if not species or species.rarity ~= "legendary" then
        return -- trophies are for legendaries only (PRD §4) — expected-failure path, not an error
    end

    table.remove(data.inventory, fishIndex)
    table.insert(data.restaurant.trophies, { species = fish.species, mountedAt = os.time() })

    trophyUpdateRemote:FireClient(player, { trophies = data.restaurant.trophies })
end

-- Rare-fish gifting (M16, PRD §4: "friend-boost and virality engine"). Restricted to rare+
-- rarity, matching "Rare-fish gifting is in" verbatim. Transfers the raw fish only — the recipient
-- still has to cook (Cooking-gated for a legendary, same as anyone) and serve it themselves, so
-- there is no cheap liquidation path (PRD §4): a gift can't skip the skill-gated value-extraction
-- chain any more than a self-caught fish can.
local function _onGiftFish(player: Player, payload: any): ()
    local fishId = if typeof(payload) == "table" then payload.fishId else nil
    local targetUserId = if typeof(payload) == "table" then payload.targetUserId else nil
    if type(fishId) ~= "string" or type(targetUserId) ~= "number" then
        return
    end

    local dataService = PlayerDataAccess.getInstance()
    local senderData = dataService and dataService:get(player.UserId)
    if not senderData then
        return
    end

    local fishIndex, fish = nil, nil
    for i, entry in senderData.inventory do
        if entry.id == fishId then
            fishIndex, fish = i, entry
            break
        end
    end
    if not fish then
        return
    end

    local species = FishSpecies.getById(fish.species)
    if not species or (species.rarity ~= "rare" and species.rarity ~= "legendary") then
        return -- only rare+ fish are giftable — expected-failure path, not an error
    end

    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    local targetData = targetPlayer and dataService:get(targetUserId)
    if not targetData then
        return -- target isn't online / isn't loaded — expected-failure path, not an error
    end

    local targetTierData = EconomyConfig.STORAGE_TIERS[targetData.storage.tier] or EconomyConfig.STORAGE_TIERS[0]
    if #targetData.inventory >= targetTierData.capacity then
        return -- recipient's storage is full
    end

    table.remove(senderData.inventory, fishIndex)
    table.insert(targetData.inventory, {
        id = HttpService:GenerateGUID(false),
        species = fish.species,
        caughtAt = os.time(),
        dryAgeMutation = fish.dryAgeMutation,
    })
end

castLineRemote.OnServerEvent:Connect(_onCastLine)
reelInputRemote.OnServerEvent:Connect(_onReelInput)
cookTraceRemote.OnServerEvent:Connect(_onCookTrace)
cookStrokeRemote.OnServerEvent:Connect(_onCookStroke)
purchaseStorageTierRemote.OnServerEvent:Connect(_onPurchaseStorageTier)
purchaseAgingLockerTierRemote.OnServerEvent:Connect(_onPurchaseAgingLockerTier)
placeInAgingLockerRemote.OnServerEvent:Connect(_onPlaceInAgingLocker)
pullFromLockerRemote.OnServerEvent:Connect(_onPullFromLocker)
mountTrophyRemote.OnServerEvent:Connect(_onMountTrophy)
giftFishRemote.OnServerEvent:Connect(_onGiftFish)
servePlateRemote.OnServerEvent:Connect(_onServePlate)

Players.PlayerRemoving:Connect(function(player: Player)
    playerStates[player.UserId] = nil
    playerCookStates[player.UserId] = nil
    playerLastServeAt[player.UserId] = nil
end)
