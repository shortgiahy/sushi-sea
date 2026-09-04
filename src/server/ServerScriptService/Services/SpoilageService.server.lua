-- SpoilageService: freshness tick for all inventory; must keep ticking while the owning player is offline
--
-- M6/M8 scope: periodically sweeps every online player's raw inventory and cookedPortions,
-- tossing anything SpoilageCalculator.classify says is spoiled and pushing the survivors'
-- freshness state to that player's FreshnessUI via Spoilage_InventoryUpdate. Freshness itself
-- needs no separate offline-tracking field: it's a pure function of `now - caughtAt`/
-- `now - cookedAt`, so a fish that spoiled while its owner was disconnected is simply gone the
-- first time this sweep reaches them after they reconnect — no catch-up bookkeeping required.
-- M8 scales the tier-0 baseline tuning by the player's own `data.storage.tier` (EconomyConfig
-- .STORAGE_TIERS[tier].spoilageMultiplier) — storage upgrades raise capacity (enforced in
-- EconomyService._writeCaughtFishToInventory) *and* slow spoilage (PRD §4).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SpoilageCalculator = require(ServerStorage.Modules.SpoilageCalculator)
local PlayerDataAccess = require(ServerStorage.Modules.PlayerDataAccess)
local EconomyConfig = require(ReplicatedStorage.Config.EconomyConfig)

local inventoryUpdateRemote: RemoteEvent = ReplicatedStorage.Events.RemoteEvents.Spoilage_InventoryUpdate

local RAW_FISH_BASE_TUNING: SpoilageCalculator.SpoilageTuning = {
    STALE_AFTER_SECONDS = EconomyConfig.RAW_FISH_STALE_AFTER_SECONDS,
    SPOILED_AFTER_SECONDS = EconomyConfig.RAW_FISH_SPOILED_AFTER_SECONDS,
}

local COOKED_PORTION_BASE_TUNING: SpoilageCalculator.SpoilageTuning = {
    STALE_AFTER_SECONDS = EconomyConfig.COOKED_PORTION_STALE_AFTER_SECONDS,
    SPOILED_AFTER_SECONDS = EconomyConfig.COOKED_PORTION_SPOILED_AFTER_SECONDS,
}

local function _tierScaledTuning(
    baseTuning: SpoilageCalculator.SpoilageTuning,
    storageTier: number
): SpoilageCalculator.SpoilageTuning
    local tierData = EconomyConfig.STORAGE_TIERS[storageTier] or EconomyConfig.STORAGE_TIERS[0]
    return {
        STALE_AFTER_SECONDS = baseTuning.STALE_AFTER_SECONDS * tierData.spoilageMultiplier,
        SPOILED_AFTER_SECONDS = baseTuning.SPOILED_AFTER_SECONDS * tierData.spoilageMultiplier,
    }
end

-- Removes spoiled entries in place (backward iteration, same table.remove-while-scanning shape
-- EconomyService.server.lua already uses for inventory/cookedPortions) before anything is
-- snapshotted for the client — a spoiled entry is tossed, never rendered as "spoiled" first.
local function _sweepSpoiled(
    list: { any },
    elapsedKey: string,
    now: number,
    tuning: SpoilageCalculator.SpoilageTuning
): ()
    for i = #list, 1, -1 do
        local elapsed = math.max(now - list[i][elapsedKey], 0)
        local state = SpoilageCalculator.classify(elapsed, tuning)
        if state == "spoiled" then
            table.remove(list, i)
        end
    end
end

local function _snapshotInventory(data: any, now: number): ()
    local rawFishTuning = _tierScaledTuning(RAW_FISH_BASE_TUNING, data.storage.tier)
    local cookedPortionTuning = _tierScaledTuning(COOKED_PORTION_BASE_TUNING, data.storage.tier)

    _sweepSpoiled(data.inventory, "caughtAt", now, rawFishTuning)
    _sweepSpoiled(data.cookedPortions, "cookedAt", now, cookedPortionTuning)

    local inventorySnapshot = {}
    for _, fish in data.inventory do
        local elapsed = math.max(now - fish.caughtAt, 0)
        local state, fraction = SpoilageCalculator.classify(elapsed, rawFishTuning)
        table.insert(inventorySnapshot, {
            id = fish.id,
            species = fish.species,
            freshnessState = state,
            freshnessFraction = fraction,
        })
    end

    local portionsSnapshot = {}
    for _, portion in data.cookedPortions do
        local elapsed = math.max(now - portion.cookedAt, 0)
        local state, fraction = SpoilageCalculator.classify(elapsed, cookedPortionTuning)
        table.insert(portionsSnapshot, {
            id = portion.id,
            species = portion.species,
            grade = portion.grade,
            freshnessState = state,
            freshnessFraction = fraction,
        })
    end

    return inventorySnapshot, portionsSnapshot
end

task.spawn(function()
    while true do
        task.wait(EconomyConfig.SPOILAGE_TICK_INTERVAL_SECONDS)

        local dataService = PlayerDataAccess.getInstance()
        if not dataService then
            continue -- PlayerDataService.server.lua hasn't self-registered yet (startup race) — try next tick
        end

        local now = os.time()
        for _, player in Players:GetPlayers() do
            local data = dataService:get(player.UserId)
            if data then
                local inventorySnapshot, portionsSnapshot = _snapshotInventory(data, now)
                inventoryUpdateRemote:FireClient(player, {
                    inventory = inventorySnapshot,
                    cookedPortions = portionsSnapshot,
                })
            end
        end
    end
end)
