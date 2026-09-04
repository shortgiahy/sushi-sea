-- Headless tests for CustomerFlow (PRD §4 "Customer simulation"): the 6-stage state machine.
-- Pure module, no Roblox globals — runs under Lune exactly like SpoilageCalculator.spec.luau.
local CustomerFlow = require("../src/server/ServerStorage/Modules/CustomerFlow")

local TUNING = {
    ARRIVAL_SECONDS = 2,
    ORDERING_SECONDS = 5,
    FULFILLMENT_TIMEOUT_SECONDS = 60,
    EATING_SECONDS = 15,
    RATING_SECONDS = 3,
}

-- new: a customer always starts in "arrival" at the given timestamp.
do
    local customer = CustomerFlow.new("c1", 1000)
    assert(customer.stage == "arrival", "a new customer must start in the arrival stage")
    assert(customer.stageEnteredAt == 1000, "a new customer's stageEnteredAt must match creation time")
    print("CustomerFlow.spec: new OK")
end

-- arrival -> ordering -> fulfillment: fixed-duration stages advance only once their timer elapses,
-- and emit no event along the way.
do
    local customer = CustomerFlow.new("c1", 0)

    local unchanged, event = CustomerFlow.tick(customer, 1, false, TUNING)
    assert(unchanged.stage == "arrival" and event == nil, "arrival must not advance before ARRIVAL_SECONDS elapses")

    local afterArrival, event2 = CustomerFlow.tick(customer, 2, false, TUNING)
    assert(afterArrival.stage == "ordering" and event2 == nil, "arrival must advance to ordering at ARRIVAL_SECONDS")

    local stillOrdering = CustomerFlow.tick(afterArrival, 6, false, TUNING)
    assert(stillOrdering.stage == "ordering", "ordering must not advance before ORDERING_SECONDS elapses")

    local afterOrdering = CustomerFlow.tick(afterArrival, 7, false, TUNING)
    assert(afterOrdering.stage == "fulfillment", "ordering must advance to fulfillment at ORDERING_SECONDS")
    print("CustomerFlow.spec: arrival -> ordering -> fulfillment timing OK")
end

-- fulfillment: waits indefinitely (within the timeout) for hasPlateReady, emits "served" and
-- advances to eating the instant a plate is ready, regardless of elapsed time.
do
    local customer = { id = "c1", stage = "fulfillment", stageEnteredAt = 0 }

    local waiting, event = CustomerFlow.tick(customer, 10, false, TUNING)
    assert(waiting.stage == "fulfillment" and event == nil, "fulfillment must keep waiting while no plate is ready")

    local served, servedEvent = CustomerFlow.tick(customer, 10, true, TUNING)
    assert(served.stage == "eating", "fulfillment must advance to eating once a plate is ready")
    assert(servedEvent == "served", "fulfillment resolving must emit a 'served' event")
    print("CustomerFlow.spec: fulfillment served OK")
end

-- fulfillment: a customer walks out once FULFILLMENT_TIMEOUT_SECONDS elapses with no plate ready,
-- and the customer's own stage does not change (caller is expected to remove it entirely).
do
    local customer = { id = "c1", stage = "fulfillment", stageEnteredAt = 0 }

    local stillWaiting = CustomerFlow.tick(customer, 59, false, TUNING)
    assert(stillWaiting.stage == "fulfillment", "fulfillment must not time out before FULFILLMENT_TIMEOUT_SECONDS")

    local _, walkoutEvent = CustomerFlow.tick(customer, 60, false, TUNING)
    assert(walkoutEvent == "walked_out", "fulfillment must emit 'walked_out' at the timeout with no plate ready")
    print("CustomerFlow.spec: fulfillment walkout OK")
end

-- eating -> payment -> rating -> left: payment resolves instantly and emits "paid"; rating holds
-- for its own duration then emits "left".
do
    local eating = { id = "c1", stage = "eating", stageEnteredAt = 0 }

    local stillEating = CustomerFlow.tick(eating, 14, false, TUNING)
    assert(stillEating.stage == "eating", "eating must not advance before EATING_SECONDS elapses")

    local atPayment = CustomerFlow.tick(eating, 15, false, TUNING)
    assert(atPayment.stage == "payment", "eating must advance to payment at EATING_SECONDS")

    local atRating, paidEvent = CustomerFlow.tick(atPayment, 15, false, TUNING)
    assert(atRating.stage == "rating", "payment must advance to rating the same tick it resolves")
    assert(paidEvent == "paid", "payment resolving must emit a 'paid' event")

    local stillRating = CustomerFlow.tick(atRating, 17, false, TUNING)
    assert(stillRating.stage == "rating", "rating must not resolve before RATING_SECONDS elapses")

    local _, leftEvent = CustomerFlow.tick(atRating, 18, false, TUNING)
    assert(leftEvent == "left", "rating must emit 'left' once RATING_SECONDS elapses")
    print("CustomerFlow.spec: eating -> payment -> rating -> left OK")
end

print("CustomerFlow.spec: all assertions passed")
