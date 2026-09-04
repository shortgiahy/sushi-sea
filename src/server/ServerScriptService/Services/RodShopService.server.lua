-- RodShopService: fishing-rod purchase (rod-seller NPC, 2026-09-04, PRD §4 Purchasing category)
--
-- The NPC itself (model, ProximityPrompt, camera-cutscene anchor) is Studio-built content, not
-- code — this file only ever handles the purchase intent the client's RodShopController fires
-- once the player presses "Buy" in the shop menu; it has no idea a 3D menu or camera cutscene
-- exists on the other end, same "server never renders anything" split every other Player_* handler
-- in this repo already keeps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)
local RodConfig = require(ReplicatedStorage.Config.RodConfig)

local RemoteEvents = ReplicatedStorage.Events.RemoteEvents
local purchaseRodRemote: RemoteEvent = RemoteEvents.Player_PurchaseRod
local cashUpdateRemote: RemoteEvent = RemoteEvents.Economy_CashUpdate
local rodUpdateRemote: RemoteEvent = RemoteEvents.Equipment_RodUpdate

-- The freshly-loaded-on-join push lives in PlayerDataService.server.lua alongside every other
-- system's initial-state push (cash/storage/restaurant/staff/aging locker) — that file's own
-- PlayerAdded handler runs *after* `service:load()` resolves, so it's the one safe place to read
-- data on join. A second PlayerAdded connection here would race it: multiple scripts' PlayerAdded
-- handlers have no guaranteed relative ordering, so this file could read before data exists.
local function _pushRodUpdate(player: Player, data: any): ()
    rodUpdateRemote:FireClient(player, {
        ownedRodIds = data.equipment.ownedRodIds,
        equippedRodId = data.equipment.equippedRodId,
    })
end

local function _onPurchaseRod(player: Player, payload: any): ()
    local rodId = if typeof(payload) == "table" then payload.rodId else nil
    if type(rodId) ~= "string" then
        return
    end

    local rod = RodConfig.RODS[rodId]
    if not rod then
        return -- unrecognized rod id — expected-failure path, not an error
    end

    local dataService = PlayerDataAccess.getInstance()
    local data = dataService and dataService:get(player.UserId)
    if not data then
        return
    end

    if data.equipment.ownedRodIds[rodId] then
        -- Already owned — just (re)equip it rather than refusing outright, since "buy" and "equip"
        -- are the same button in the shop menu (only one purchasable rod exists right now).
        data.equipment.equippedRodId = rodId
        _pushRodUpdate(player, data)
        return
    end

    if data.economy.cash < rod.cost then
        return -- can't afford it — expected-failure path (PRD §8), not an error
    end

    data.economy.cash -= rod.cost
    data.equipment.ownedRodIds[rodId] = true
    data.equipment.equippedRodId = rodId

    cashUpdateRemote:FireClient(player, data.economy.cash)
    _pushRodUpdate(player, data)
end

purchaseRodRemote.OnServerEvent:Connect(_onPurchaseRod)
