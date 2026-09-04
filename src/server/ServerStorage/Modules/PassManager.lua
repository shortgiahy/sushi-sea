-- PassManager: GamePass ownership cache and purchase prompt; cosmetics/convenience only, cached once per session (PRD §9, M19)
--
-- M19 scope: a stateful singleton (same "module-cached, not a `_G` global" shape
-- PlayerDataAccess.lua/WeatherAccess.lua already document) rather than a pure module — there is no
-- interesting math here to headlessly test, only a cache wrapper around MarketplaceService. Called
-- from PlayerDataService.server.lua's existing PlayerAdded/PlayerRemoving handlers (same "lives
-- alongside the established per-player join/leave wiring" reasoning every other cross-cutting
-- system in this repo already uses) rather than a new dedicated service file, since PRD §7.1 names
-- only the module, not a service, for this.
local MarketplaceService = game:GetService("MarketplaceService")

local PassManager = {}

local ownershipCache: { [number]: { [number]: boolean } } = {}

function PassManager.playerOwns(userId: number, gamePassId: number): boolean
    local userCache = ownershipCache[userId]
    return userCache ~= nil and userCache[gamePassId] == true
end

-- UserOwnsGamePassAsync throws on an unpublished place or an invalid/placeholder id (gamePassId =
-- 0 today — see MonetizationConfig.lua's header) — same "unpublished place breaks a Marketplace-
-- style API" shape PlayerDataService.server.lua's DataStoreService fallback already documents.
-- Treated as "not owned" rather than erroring, so the rest of the game stays testable locally.
local function _queryOwnership(userId: number, gamePassId: number): boolean
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
    end)
    if not ok then
        warn(
            ("[PassManager] UserOwnsGamePassAsync failed for user %d / passId %d (expected on an unpublished place or placeholder id): %s"):format(
                userId,
                gamePassId,
                tostring(owns)
            )
        )
        return false
    end
    return owns
end

-- Cache ownership once per player per session (PRD: "Cache ownership checks (GamePass) once per
-- player per session"), not re-queried on every check.
function PassManager.refreshForPlayer(userId: number, gamePassIds: { number }): ()
    local userCache = ownershipCache[userId]
    if not userCache then
        userCache = {}
        ownershipCache[userId] = userCache
    end
    for _, gamePassId in gamePassIds do
        userCache[gamePassId] = _queryOwnership(userId, gamePassId)
    end
end

function PassManager.promptPurchase(player: Player, gamePassId: number): ()
    MarketplaceService:PromptGamePassPurchase(player, gamePassId)
end

function PassManager.releasePlayer(userId: number): ()
    ownershipCache[userId] = nil
end

-- Global event, connected once at first require — same shape as the module-level task.spawn loops
-- other services in this repo already run once at load time.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(
    function(player: Player, gamePassId: number, wasPurchased: boolean)
        if not wasPurchased then
            return
        end
        local userCache = ownershipCache[player.UserId]
        if not userCache then
            userCache = {}
            ownershipCache[player.UserId] = userCache
        end
        userCache[gamePassId] = true
    end
)

return PassManager
