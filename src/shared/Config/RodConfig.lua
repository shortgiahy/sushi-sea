-- RodConfig: purchasable fishing rod catalog (PRD §4 Purchasing category — "rods" are explicitly
-- named alongside boats/equipment/capacity/restaurant tiers as bought-not-crafted durable goods).
--
-- A rod's only effect is `catchBoxWidthBonus`, added to FishingConfig.CATCH_BOX_WIDTH for whoever
-- has it equipped. This reuses the exact mechanism M14's legendary phases already use to
-- parametrize catch-box width per-fight (EconomyService fires the effective width down
-- Fishing_BiteWindow every time) — a rod bonus is just another input to that same per-fight
-- number, not a second shared-width concept the client and server would need to separately agree
-- on. `effectiveCatchBoxWidth` is the one function both sides call so they can never disagree.
local RodConfig = {}

RodConfig.DEFAULT_ROD_ID = "starter_rod"

export type RodEntry = {
    id: string,
    displayName: string,
    cost: number,
    catchBoxWidthBonus: number,
    order: number,
}

-- First-pass numbers, same status as every other tuning table in this repo — retune after
-- Giahy plays with it in Studio. `carbon_rod` is the one rod this session's NPC actually sells;
-- `starter_rod` is free and owned by every player by default (PlayerDataSchema.newDefault()).
RodConfig.RODS = {
    starter_rod = {
        id = "starter_rod",
        displayName = "Starter Rod",
        cost = 0,
        catchBoxWidthBonus = 0,
        order = 1,
    },
    carbon_rod = {
        id = "carbon_rod",
        displayName = "Carbon Fiber Rod",
        cost = 750,
        catchBoxWidthBonus = 0.12,
        order = 2,
    },
} :: { [string]: RodEntry }

-- Lua tables have no guaranteed iteration order; a shop menu needs a stable one (starter first,
-- then purchasable upgrades in ascending price/order).
function RodConfig.orderedRods(): { RodEntry }
    local list = {}
    for _, rod in RodConfig.RODS do
        table.insert(list, rod)
    end
    table.sort(list, function(a: RodEntry, b: RodEntry): boolean
        return a.order < b.order
    end)
    return list
end

-- The one function client and server both call to turn "which rod is equipped" into an actual
-- fight-simulation number — never let each side compute this independently (same anti-drift
-- reasoning FishingCatch.fishPositionAt's header already documents for the client's duplicate).
function RodConfig.effectiveCatchBoxWidth(baseWidth: number, equippedRodId: string?): number
    local rod = RodConfig.RODS[equippedRodId or RodConfig.DEFAULT_ROD_ID] or RodConfig.RODS[RodConfig.DEFAULT_ROD_ID]
    return math.clamp(baseWidth + rod.catchBoxWidthBonus, 0.05, 1)
end

return RodConfig
