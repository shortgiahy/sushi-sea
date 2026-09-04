-- CustomerService: customer spawn process and the 6-stage lifecycle state machine, per-restaurant independent stream
--
-- M10 scope: CustomerFlow.lua owns the pure stage-transition logic; this file owns everything it
-- deliberately doesn't know about — the seating gate, popping/resolving a cookedPortions entry
-- when fulfillment can proceed, and crediting cash at payment.
--
-- M12 addition: TrafficStat.lua owns prestige→stars and the traffic multiplier; this file reads
-- `restaurant.prestigePoints` (only ever incremented on "paid," per PRD §4's "never drops") and
-- scales the spawn interval by the resulting multiplier — replacing M10's flat per-seat rate with
-- the real hidden traffic-stat formula (PRD §12 Thread #6). `cosmeticsScore` is passed as 0 (no
-- cosmetics system exists yet); Hospitality level is read from PlayerData but sits at 1 for every
-- player until a leveling system exists (SkillConfig.lua is still an empty stub) — both wired, both
-- inert until their systems land, same status WAGE_RATE carried before M11.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local CustomerFlow = require(ServerStorage.Modules.CustomerFlow)
local PlateValueResolver = require(ServerStorage.Modules.PlateValueResolver)
local FishTable = require(ServerStorage.Modules.FishTable)
local TrafficStat = require(ServerStorage.Modules.TrafficStat)
local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)
local RestaurantConfig = require(ReplicatedStorage.Config.RestaurantConfig)
local CookConfig = require(ReplicatedStorage.Config.CookConfig)
local EconomyConfig = require(ReplicatedStorage.Config.EconomyConfig)

local RemoteEvents = ReplicatedStorage.Events.RemoteEvents
local customerUpdateRemote: RemoteEvent = RemoteEvents.Restaurant_CustomerUpdate
local cashUpdateRemote: RemoteEvent = RemoteEvents.Economy_CashUpdate

local TRAFFIC_TUNING: TrafficStat.TrafficTuning = {
    PRESTIGE_POINTS_PER_STAR = RestaurantConfig.PRESTIGE_POINTS_PER_STAR,
    MAX_STARS = RestaurantConfig.MAX_STARS,
    PRESTIGE_WEIGHT = RestaurantConfig.PRESTIGE_WEIGHT,
    HOSPITALITY_WEIGHT = RestaurantConfig.HOSPITALITY_WEIGHT,
    COSMETICS_WEIGHT = RestaurantConfig.COSMETICS_WEIGHT,
    MAX_HOSPITALITY_LEVEL_FOR_TRAFFIC = RestaurantConfig.MAX_HOSPITALITY_LEVEL_FOR_TRAFFIC,
    MIN_TRAFFIC_MULTIPLIER = RestaurantConfig.MIN_TRAFFIC_MULTIPLIER,
    MAX_TRAFFIC_MULTIPLIER = RestaurantConfig.MAX_TRAFFIC_MULTIPLIER,
}

-- Same tuning-table construction EconomyService.server.lua already builds for the boat serve
-- verb — small enough duplication that a shared module would be a premature abstraction over
-- five field lookups (see that file's own PLATE_VALUE_TUNING for the identical shape).
local PLATE_VALUE_TUNING: PlateValueResolver.PlateValueTuning = {
    MAX_COOKING_LEVEL_FOR_EXTRACTION = CookConfig.MAX_COOKING_LEVEL_FOR_EXTRACTION,
    CLAMP_FRESHNESS_MIN = EconomyConfig.CLAMP_FRESHNESS_MIN,
    CLAMP_FRESHNESS_MAX = EconomyConfig.CLAMP_FRESHNESS_MAX,
    FRESHNESS_DECAY_WINDOW_SECONDS = EconomyConfig.FRESHNESS_DECAY_WINDOW_SECONDS,
    DRY_AGE_MUTATION_BASELINE = EconomyConfig.DRY_AGE_MUTATION_BASELINE,
}

local CUSTOMER_FLOW_TUNING: CustomerFlow.CustomerFlowTuning = {
    ARRIVAL_SECONDS = RestaurantConfig.CUSTOMER_ARRIVAL_SECONDS,
    ORDERING_SECONDS = RestaurantConfig.CUSTOMER_ORDERING_SECONDS,
    FULFILLMENT_TIMEOUT_SECONDS = RestaurantConfig.CUSTOMER_FULFILLMENT_TIMEOUT_SECONDS,
    EATING_SECONDS = RestaurantConfig.CUSTOMER_EATING_SECONDS,
    RATING_SECONDS = RestaurantConfig.CUSTOMER_RATING_SECONDS,
}

local activeCustomers: { [number]: { CustomerFlow.Customer } } = {}
local lastSpawnAt: { [number]: number } = {}
local pendingPlateValue: { [string]: number } = {}

-- Pops the oldest cookedPortions entry and resolves its value the same way the boat serve verb
-- does (EconomyService._onServePlate) — one shared kitchen output feeding both a manual boat serve
-- and an automatic restaurant serve, not two parallel stock pools.
local function _resolveNextPlate(data: any): number
    local portion = table.remove(data.cookedPortions, 1)
    if not portion then
        return 0
    end

    local cutBase = FishTable.cutBaseFor(portion.species, portion.grade)
    if not cutBase then
        warn(
            ("[CustomerService] no FishTable.cutBase for %s/%s — resolving this plate at 0"):format(
                portion.species,
                portion.grade
            )
        )
        return 0
    end

    local freshnessElapsedSeconds = math.max(os.time() - portion.cookedAt, 0)
    local plateValue = PlateValueResolver.resolve({
        cutBase = cutBase,
        cookingLevel = data.skills.cooking.level,
        freshnessElapsedSeconds = freshnessElapsedSeconds,
        dryAgeMutation = portion.dryAgeMutation,
    }, PLATE_VALUE_TUNING)

    return plateValue
end

local function _tickPlayer(player: Player, data: any, now: number): ()
    local tierData = RestaurantConfig.RESTAURANT_TIERS[data.restaurant.tier]
    if not tierData then
        return -- tier 0 (boat only) — no restaurant, no customers
    end

    local stars = TrafficStat.starsFor(data.restaurant.prestigePoints, TRAFFIC_TUNING)
    local trafficMultiplier = TrafficStat.multiplierFor(stars, data.skills.hospitality.level, 0, TRAFFIC_TUNING)

    local customers = activeCustomers[player.UserId] or {}

    if #customers < tierData.seats then
        local spawnInterval = (RestaurantConfig.CUSTOMER_SPAWN_INTERVAL_SECONDS_PER_SEAT / tierData.seats)
            / trafficMultiplier
        local lastSpawn = lastSpawnAt[player.UserId] or 0
        if now - lastSpawn >= spawnInterval then
            table.insert(customers, CustomerFlow.new(HttpService:GenerateGUID(false), now))
            lastSpawnAt[player.UserId] = now
        end
    end

    local survivors: { CustomerFlow.Customer } = {}
    for _, customer in customers do
        local hasPlateReady = #data.cookedPortions > 0
        local updated, event = CustomerFlow.tick(customer, now, hasPlateReady, CUSTOMER_FLOW_TUNING)

        if event == "served" then
            pendingPlateValue[updated.id] = _resolveNextPlate(data)
        elseif event == "paid" then
            local value = pendingPlateValue[updated.id] or 0
            pendingPlateValue[updated.id] = nil
            data.economy.cash += value
            data.restaurant.prestigePoints += RestaurantConfig.PRESTIGE_POINTS_PER_SERVED_CUSTOMER
            cashUpdateRemote:FireClient(player, data.economy.cash)
        end

        if event == "walked_out" then
            pendingPlateValue[updated.id] = nil
        else
            table.insert(survivors, updated)
        end
    end

    activeCustomers[player.UserId] = survivors

    local snapshot = {}
    for _, customer in survivors do
        table.insert(snapshot, { id = customer.id, stage = customer.stage })
    end
    customerUpdateRemote:FireClient(player, {
        customers = snapshot,
        prestigePoints = data.restaurant.prestigePoints,
        stars = TrafficStat.starsFor(data.restaurant.prestigePoints, TRAFFIC_TUNING),
    })
end

task.spawn(function()
    while true do
        task.wait(RestaurantConfig.RESTAURANT_TICK_INTERVAL_SECONDS)

        local dataService = PlayerDataAccess.getInstance()
        if not dataService then
            continue -- PlayerDataService.server.lua hasn't self-registered yet (startup race) — try next tick
        end

        local now = os.time()
        for _, player in Players:GetPlayers() do
            local data = dataService:get(player.UserId)
            if data then
                _tickPlayer(player, data, now)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player: Player)
    for _, customer in activeCustomers[player.UserId] or {} do
        pendingPlateValue[customer.id] = nil
    end
    activeCustomers[player.UserId] = nil
    lastSpawnAt[player.UserId] = nil
end)
