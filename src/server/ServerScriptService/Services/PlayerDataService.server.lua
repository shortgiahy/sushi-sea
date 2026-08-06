-- PlayerDataService: DataStore reads/writes and offline bank snapshot/restore (PRD §7.3, §7.4)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerStorage.Modules.PlayerDataService)
local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)

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

Players.PlayerAdded:Connect(function(player: Player)
    service:load(player.UserId, player.Name)
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
