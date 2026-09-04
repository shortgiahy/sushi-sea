-- PlayerDataService: DataStore reads/writes and offline bank snapshot/restore (PRD §7.3, §7.4)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerStorage.Modules.PlayerDataService)
local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)
local OfflineBankCalculator = require(ServerStorage.Modules.OfflineBankCalculator)
local EconomyConfig = require(ReplicatedStorage.Config.EconomyConfig)
local RestaurantConfig = require(ReplicatedStorage.Config.RestaurantConfig)
local AgingConfig = require(ReplicatedStorage.Config.AgingConfig)

-- M6 addition: FreshnessUI's gold display needs an initial value on join, not just the delta
-- EconomyService.server.lua already pushes after each serve — this is the one place a freshly
-- loaded player's starting gold is known.
local goldUpdateRemote: RemoteEvent = ReplicatedStorage.Events.RemoteEvents.Economy_GoldUpdate

-- M8 addition: same reasoning as goldUpdateRemote — a freshly loaded player's storage tier/
-- capacity is only known here, right after load.
local storageTierUpdateRemote: RemoteEvent = ReplicatedStorage.Events.RemoteEvents.Storage_TierUpdate

-- M11 addition: same reasoning — a freshly loaded player's restaurant tier and staff roster are
-- only known here, right after load.
local restaurantTierUpdateRemote: RemoteEvent = ReplicatedStorage.Events.RemoteEvents.Restaurant_TierUpdate
local staffUpdateRemote: RemoteEvent = ReplicatedStorage.Events.RemoteEvents.Restaurant_StaffUpdate

-- M15 addition: same reasoning — a freshly loaded player's aging locker tier/contents are only
-- known here, right after load.
local agingLockerUpdateRemote: RemoteEvent = ReplicatedStorage.Events.RemoteEvents.Aging_LockerUpdate

-- M16 addition: same reasoning — a freshly loaded player's mounted trophies are only known here,
-- right after load.
local trophyUpdateRemote: RemoteEvent = ReplicatedStorage.Events.RemoteEvents.Restaurant_TrophyUpdate

-- DataStoreService:GetDataStore throws outright — not just a failed Get/SetAsync — on an
-- unpublished place with Studio API access off, which is the normal state while iterating on this
-- repo locally (no published Roblox experience exists yet). Falling back to an in-memory mock
-- keeps every other system (fishing, cooking, ...) testable in a local Studio session; a published
-- place with API access on never hits this branch, so production behavior is unchanged. No data
-- persists across Studio runs in the fallback case — that's expected, not a bug, for local testing.
local function _newMockDataStore(): PlayerDataService.DataStoreLike
    local store: { [string]: any } = {}
    return {
        GetAsync = function(_self, key: string): any
            return store[key]
        end,
        SetAsync = function(_self, key: string, value: any): ()
            store[key] = value
        end,
    }
end

local ok, dataStoreOrError = pcall(function()
    return DataStoreService:GetDataStore("PlayerData_v1")
end)

local dataStore: PlayerDataService.DataStoreLike
if ok then
    dataStore = dataStoreOrError :: PlayerDataService.DataStoreLike
else
    warn(
        "[PlayerDataService] DataStoreService unavailable (unpublished place / Studio API access off) — "
            .. "using an in-memory mock for this session, no data will persist: "
            .. tostring(dataStoreOrError)
    )
    dataStore = _newMockDataStore()
end

local service = PlayerDataService.new(dataStore)
PlayerDataAccess.setInstance(service)

-- M9 addition, M11 update: PRD §7.4's closed-form offline bank, run once right after load. Only
-- fires when a prior save actually stamped a snapshot (offlineSnapshotAt > 0) — a brand-new player
-- has nothing to reconcile. staffHeadcount now reads `#data.restaurant.staff` (M11's real roster),
-- but throughput/plate-value/wage stay inert placeholders — those numbers still don't exist
-- (docs/design/economy-model-skeleton.md), so a staffed player nets 0 here same as an unstaffed
-- one until a later numbers session fills them in.
local function _creditOfflineBank(data: any): ()
    if data.economy.offlineSnapshotAt <= 0 then
        return
    end

    local elapsedSeconds = math.max(os.time() - data.economy.offlineSnapshotAt, 0)
    local netBank = OfflineBankCalculator.compute({
        elapsedSeconds = elapsedSeconds,
        staffHeadcount = #data.restaurant.staff,
        throughputPerHourWhenStaffed = 0,
        avgPlateValueAtLogout = 0,
        remainingStockAfterSpoilage = 0,
        wageRatePerHourPerStaff = 0,
    })

    data.economy.gold += netBank
    data.economy.offlineSnapshotAt = os.time() -- PRD §7.4 step 7: clear the snapshot after crediting
end

Players.PlayerAdded:Connect(function(player: Player)
    local data = service:load(player.UserId, player.Name)
    _creditOfflineBank(data)
    goldUpdateRemote:FireClient(player, data.economy.gold)

    local tierData = EconomyConfig.STORAGE_TIERS[data.storage.tier] or EconomyConfig.STORAGE_TIERS[0]
    local nextTierData = EconomyConfig.STORAGE_TIERS[data.storage.tier + 1]
    storageTierUpdateRemote:FireClient(player, {
        tier = data.storage.tier,
        name = tierData.name,
        capacity = tierData.capacity,
        nextTierCost = if nextTierData then nextTierData.upgradeCost else nil,
    })

    local restaurantTierData = RestaurantConfig.RESTAURANT_TIERS[data.restaurant.tier]
    local nextRestaurantTierData = RestaurantConfig.RESTAURANT_TIERS[data.restaurant.tier + 1]
    restaurantTierUpdateRemote:FireClient(player, {
        tier = data.restaurant.tier,
        name = if restaurantTierData then restaurantTierData.name else nil,
        seats = if restaurantTierData then restaurantTierData.seats else 0,
        nextTierCost = if nextRestaurantTierData then nextRestaurantTierData.upgradeCost else nil,
    })

    local roster = {}
    for _, staff in data.restaurant.staff do
        table.insert(roster, { id = staff.id, rarity = staff.rarity, hiredAt = staff.hiredAt })
    end
    staffUpdateRemote:FireClient(player, { roster = roster })

    local agingTierData = AgingConfig.LOCKER_TIERS[data.agingLockerEquipment.tier]
    local nextAgingTierData = AgingConfig.LOCKER_TIERS[data.agingLockerEquipment.tier + 1]
    local locker = {}
    for _, fish in data.agingLocker do
        table.insert(locker, { slot = fish.slot, species = fish.species, placedAt = fish.placedAt })
    end
    agingLockerUpdateRemote:FireClient(player, {
        tier = data.agingLockerEquipment.tier,
        slots = if agingTierData then agingTierData.slots else 0,
        nextTierCost = if nextAgingTierData then nextAgingTierData.upgradeCost else nil,
        locker = locker,
    })

    trophyUpdateRemote:FireClient(player, { trophies = data.restaurant.trophies })
end)

Players.PlayerRemoving:Connect(function(player: Player)
    service:save(player.UserId, player.Name)
    service:release(player.UserId)
end)

-- PlayerRemoving alone misses server shutdown — BindToClose is the only hook that fires then.
game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        service:save(player.UserId, player.Name)
    end
end)
