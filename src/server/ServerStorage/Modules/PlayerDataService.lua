-- PlayerDataService: load/save orchestration over a DataStore-like object (PRD §7.3, §7.4). DataStore-agnostic
-- by construction so it can be unit-tested with a mock store; Services/PlayerDataService.server.lua binds a
-- real DataStoreService instance and wires Players/BindToClose.
local PlayerDataSchema = require(script.Parent.PlayerDataSchema)
local DataStoreRetry = require(script.Parent.DataStoreRetry)

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

export type DataStoreLike = {
    GetAsync: (self: DataStoreLike, key: string) -> any,
    SetAsync: (self: DataStoreLike, key: string, value: any) -> (),
}

export type PlayerDataServiceInstance = typeof(setmetatable(
    {} :: {
        _dataStore: DataStoreLike,
        _loaded: { [number]: PlayerDataSchema.PlayerData },
    },
    PlayerDataService
))

local function _keyFor(userId: number): string
    return "Player_" .. tostring(userId)
end

function PlayerDataService.new(dataStore: DataStoreLike): PlayerDataServiceInstance
    local self = setmetatable({
        _dataStore = dataStore,
        _loaded = {},
    }, PlayerDataService)
    return self
end

function PlayerDataService.load(
    self: PlayerDataServiceInstance,
    userId: number,
    playerLabel: string?
): PlayerDataSchema.PlayerData
    local key = _keyFor(userId)
    local success, result = DataStoreRetry.retryAsync(function()
        return self._dataStore:GetAsync(key)
    end)

    local data: PlayerDataSchema.PlayerData
    if success then
        data = PlayerDataSchema.migrate(result)
    else
        warn(
            "[PlayerDataService] load failed for "
                .. tostring(playerLabel or userId)
                .. " after "
                .. tostring(DataStoreRetry.MAX_ATTEMPTS)
                .. " attempts: "
                .. tostring(result)
        )
        data = PlayerDataSchema.newDefault()
    end

    local now = os.time()
    if data.meta.firstJoinAt == 0 then
        data.meta.firstJoinAt = now
    end
    data.meta.lastJoinAt = now

    self._loaded[userId] = data
    return data
end

-- Stamps the offline-bank snapshot fields (PRD §7.4) before every save, not just on logout — a
-- mid-session save (e.g. a periodic autosave added later) must leave a snapshot as fresh as the
-- last known-good write, never a stale one from an earlier save.
function PlayerDataService.save(self: PlayerDataServiceInstance, userId: number, playerLabel: string?): boolean
    local data = self._loaded[userId]
    if not data then
        return false
    end

    data.economy.offlineSnapshotAt = os.time()
    data.economy.offlineStockCount = #data.inventory

    local key = _keyFor(userId)
    local success, err = DataStoreRetry.retryAsync(function()
        self._dataStore:SetAsync(key, data)
    end)

    if not success then
        warn(
            "[PlayerDataService] save failed for "
                .. tostring(playerLabel or userId)
                .. " after "
                .. tostring(DataStoreRetry.MAX_ATTEMPTS)
                .. " attempts: "
                .. tostring(err)
        )
    end

    return success
end

function PlayerDataService.get(self: PlayerDataServiceInstance, userId: number): PlayerDataSchema.PlayerData?
    return self._loaded[userId]
end

function PlayerDataService.release(self: PlayerDataServiceInstance, userId: number): ()
    self._loaded[userId] = nil
end

return PlayerDataService
