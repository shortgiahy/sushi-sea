-- CustomerFlow: pure 6-stage customer lifecycle state machine (PRD §4 "Customer simulation":
-- arrival/seating → ordering → fulfillment → serving/eating → payment → rating)
--
-- Not in PRD §7.1's file list — same "pure logic needs to be headlessly testable under Lune"
-- deviation FishingCatch.lua/PlateValueResolver.lua/SpoilageCalculator.lua already made and
-- documented. CustomerService.server.lua is the sole caller, and owns everything this module
-- doesn't know about: seating gate (a customer is only created once a seat is confirmed free),
-- popping/resolving a cookedPortions entry when fulfillment can proceed, and crediting cash at
-- payment. This module only tracks which stage a customer is in and when to move to the next one.
--
-- "No order matching" (PRD §4/docs/design/cook-verb.md) means ordering has nothing to decide —
-- it's a fixed-duration pacing beat, not a menu choice. Fulfillment is the one event-driven stage:
-- it waits on `hasPlateReady` (kitchen throughput is the primary bottleneck, PRD §4) and times out
-- into a walkout if the kitchen never catches up — PRD's "cash lost to walkouts" is the potential
-- sale that never happened, not a penalty deducted from anything.
local CustomerFlow = {}

export type CustomerStage = "arrival" | "ordering" | "fulfillment" | "eating" | "payment" | "rating"

export type Customer = {
    id: string,
    stage: CustomerStage,
    stageEnteredAt: number,
}

export type CustomerFlowTuning = {
    ARRIVAL_SECONDS: number,
    ORDERING_SECONDS: number,
    FULFILLMENT_TIMEOUT_SECONDS: number,
    EATING_SECONDS: number,
    RATING_SECONDS: number,
}

-- "served" fires the tick fulfillment resolves — caller must pop+resolve a cookedPortions entry
-- in that same tick, before the customer moves on.
-- "paid" fires the tick payment resolves — caller must credit the previously-resolved plate value.
-- "left" fires once rating completes — caller removes the customer normally.
-- "walked_out" fires if fulfillment times out — caller removes the customer, nothing is credited.
export type CustomerFlowEvent = "served" | "paid" | "left" | "walked_out"

function CustomerFlow.new(id: string, now: number): Customer
    return { id = id, stage = "arrival", stageEnteredAt = now }
end

local function _enterStage(customer: Customer, stage: CustomerStage, now: number): Customer
    return { id = customer.id, stage = stage, stageEnteredAt = now }
end

function CustomerFlow.tick(
    customer: Customer,
    now: number,
    hasPlateReady: boolean,
    tuning: CustomerFlowTuning
): (Customer, CustomerFlowEvent?)
    local elapsed = math.max(now - customer.stageEnteredAt, 0)

    if customer.stage == "arrival" then
        if elapsed >= tuning.ARRIVAL_SECONDS then
            return _enterStage(customer, "ordering", now), nil
        end
        return customer, nil
    elseif customer.stage == "ordering" then
        if elapsed >= tuning.ORDERING_SECONDS then
            return _enterStage(customer, "fulfillment", now), nil
        end
        return customer, nil
    elseif customer.stage == "fulfillment" then
        if hasPlateReady then
            return _enterStage(customer, "eating", now), "served"
        end
        if elapsed >= tuning.FULFILLMENT_TIMEOUT_SECONDS then
            return customer, "walked_out"
        end
        return customer, nil
    elseif customer.stage == "eating" then
        if elapsed >= tuning.EATING_SECONDS then
            return _enterStage(customer, "payment", now), nil
        end
        return customer, nil
    elseif customer.stage == "payment" then
        -- Resolves the tick it's entered — payment itself is instant, no minigame or delay.
        return _enterStage(customer, "rating", now), "paid"
    elseif customer.stage == "rating" then
        if elapsed >= tuning.RATING_SECONDS then
            return customer, "left"
        end
        return customer, nil
    end

    return customer, nil
end

return CustomerFlow
