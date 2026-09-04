-- StaffService: NPC cook/serve AI at brick-and-mortar tier; drives the same ConversionModule as the player (PRD §7.6)
--
-- M11 scope: restaurant-tier purchase, staff hiring, and the auto-cook/wage tick. `ConversionModule
-- .cook` is the SAME function BoatCookController's manual verb calls (§7.6 — "build the conversion
-- once, swap the driver"); this file only synthesizes a `performance` table from a staff member's
-- rarity/tenure (StaffPerformance.lua) instead of reading real trace/stroke input. Restaurant-tier
-- purchase lives here rather than EconomyService.server.lua because it's this service's own
-- unlock gate (staff can't be hired below tier 1) — same "lives alongside the thing it drives"
-- reasoning EconomyService's own Player_* handlers already documented for M4/M5.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local ConversionModule = require(ServerStorage.Modules.ConversionModule)
local StaffPerformance = require(ServerStorage.Modules.StaffPerformance)
local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)
local FishSpecies = require(ReplicatedStorage.Modules.FishSpecies)
local RestaurantConfig = require(ReplicatedStorage.Config.RestaurantConfig)
local CookConfig = require(ReplicatedStorage.Config.CookConfig)

local RemoteEvents = ReplicatedStorage.Events.RemoteEvents
local purchaseRestaurantTierRemote: RemoteEvent = RemoteEvents.Player_PurchaseRestaurantTier
local restaurantTierUpdateRemote: RemoteEvent = RemoteEvents.Restaurant_TierUpdate
local hireStaffRemote: RemoteEvent = RemoteEvents.Player_HireStaff
local staffUpdateRemote: RemoteEvent = RemoteEvents.Restaurant_StaffUpdate
local goldUpdateRemote: RemoteEvent = RemoteEvents.Economy_GoldUpdate

local function _pushRestaurantTierUpdate(player: Player, data: any): ()
    local tierData = RestaurantConfig.RESTAURANT_TIERS[data.restaurant.tier]
    local nextTierData = RestaurantConfig.RESTAURANT_TIERS[data.restaurant.tier + 1]
    restaurantTierUpdateRemote:FireClient(player, {
        tier = data.restaurant.tier,
        name = if tierData then tierData.name else nil,
        seats = if tierData then tierData.seats else 0,
        nextTierCost = if nextTierData then nextTierData.upgradeCost else nil,
    })
end

local function _pushStaffUpdate(player: Player, data: any): ()
    local roster = {}
    for _, staff in data.restaurant.staff do
        table.insert(roster, { id = staff.id, rarity = staff.rarity, hiredAt = staff.hiredAt })
    end
    staffUpdateRemote:FireClient(player, { roster = roster })
end

local function _onPurchaseRestaurantTier(player: Player): ()
    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    local nextTier = data.restaurant.tier + 1
    local tierData = RestaurantConfig.RESTAURANT_TIERS[nextTier]
    if not tierData then
        return -- already at RestaurantConfig.MAX_RESTAURANT_TIER — expected-failure path, not an error
    end
    if data.economy.gold < tierData.upgradeCost then
        return -- can't afford it — expected-failure path (PRD §8), not an error
    end

    data.economy.gold -= tierData.upgradeCost
    data.restaurant.tier = nextTier

    goldUpdateRemote:FireClient(player, data.economy.gold)
    _pushRestaurantTierUpdate(player, data)
end

local function _onHireStaff(player: Player, payload: any): ()
    local rarity = if typeof(payload) == "table" then payload.rarity else nil
    if type(rarity) ~= "string" then
        return
    end

    local rarityTuning = RestaurantConfig.STAFF_RARITY[rarity]
    if not rarityTuning then
        return -- unrecognized rarity — expected-failure path, not an error
    end

    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    if data.restaurant.tier <= 0 then
        return -- no restaurant to staff yet — must buy at least tier 1 first
    end
    if data.economy.gold < rarityTuning.hireCost then
        return
    end

    data.economy.gold -= rarityTuning.hireCost
    table.insert(data.restaurant.staff, { id = HttpService:GenerateGUID(false), rarity = rarity, hiredAt = os.time() })

    goldUpdateRemote:FireClient(player, data.economy.gold)
    _pushStaffUpdate(player, data)
end

-- Auto-cook one fish per staff member per tick (kitchen throughput scales with headcount, PRD
-- §4's "kitchen throughput is the primary bottleneck"), oldest inventory first, stopping early
-- once raw stock runs out regardless of remaining staff. Deterministic performance per §4 ("no
-- per-fish roll") — same ConversionModule.cook call BoatCookController's manual verb makes,
-- just with a synthesized performance table instead of real trace/stroke input.
local function _autoCook(data: any, staffMember: any, now: number): ()
    local fish = table.remove(data.inventory, 1)
    if not fish then
        return
    end

    local species = FishSpecies.getById(fish.species)
    if not species then
        table.insert(data.inventory, 1, fish) -- content gap (unknown species) — put it back, don't destroy it
        return
    end

    local rarityTuning = RestaurantConfig.STAFF_RARITY[staffMember.rarity]
    local performanceScore =
        StaffPerformance.resolve(rarityTuning, staffMember.hiredAt, now, RestaurantConfig.TENURE_SECONDS_FOR_FULL_BONUS)

    local strokeQuality = {}
    for _ = 1, species.loinCount do
        table.insert(strokeQuality, performanceScore)
    end

    local portions = ConversionModule.cook(
        { prepTier = species.prepTier, loinCount = species.loinCount, maxYield = species.maxYield },
        { traceAccuracy = performanceScore, strokeQuality = strokeQuality },
        data.skills.cooking.level,
        CookConfig
    )

    for _, portion in portions do
        table.insert(data.cookedPortions, {
            id = HttpService:GenerateGUID(false),
            species = fish.species,
            grade = portion.grade,
            cookedAt = now,
        })
    end
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
            local staffCount = data and #data.restaurant.staff or 0
            if data and staffCount > 0 then
                -- Wages (PRD §5: "mandatory, scales with headcount"; §5's economy caution: a weak
                -- dial) — deducted continuously while online; the offline case is
                -- OfflineBankCalculator's separate closed-form (M9).
                local wageCost = staffCount
                    * RestaurantConfig.WAGE_RATE_PER_HOUR_PER_STAFF
                    * (RestaurantConfig.RESTAURANT_TICK_INTERVAL_SECONDS / 3600)
                data.economy.gold = math.max(0, data.economy.gold - wageCost)
                goldUpdateRemote:FireClient(player, data.economy.gold)

                for _, staffMember in data.restaurant.staff do
                    if #data.inventory <= 0 then
                        break
                    end
                    _autoCook(data, staffMember, now)
                end
            end
        end
    end
end)

purchaseRestaurantTierRemote.OnServerEvent:Connect(_onPurchaseRestaurantTier)
hireStaffRemote.OnServerEvent:Connect(_onHireStaff)
