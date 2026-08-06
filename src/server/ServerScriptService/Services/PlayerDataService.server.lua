-- PlayerDataService: DataStore reads/writes and offline bank snapshot/restore (PRD §7.3, §7.4)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerStorage.Modules.PlayerDataService)
local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)

local dataStore = DataStoreService:GetDataStore("PlayerData_v1")
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
