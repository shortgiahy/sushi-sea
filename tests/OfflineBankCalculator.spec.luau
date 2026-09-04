-- Headless tests for OfflineBankCalculator (PRD §7.4): the closed-form offline bank formula.
-- Pure module, no Roblox globals — runs under Lune exactly like PlateValueResolver.spec.luau.
local OfflineBankCalculator = require("../src/server/ServerStorage/Modules/OfflineBankCalculator")

local BASE_INPUTS = {
    elapsedSeconds = 3600,
    staffHeadcount = 2,
    throughputPerHourWhenStaffed = 10,
    avgPlateValueAtLogout = 20,
    remainingStockAfterSpoilage = 100,
    wageRatePerHourPerStaff = 5,
}

local function withOverrides(overrides: { [string]: any })
    local merged = table.clone(BASE_INPUTS)
    for key, value in overrides do
        merged[key] = value
    end
    return merged
end

-- staffHeadcount == 0 (every player today — M11's staff system doesn't exist yet): netBank must
-- always resolve to 0, regardless of any other input, since nobody is present to run the
-- restaurant while the player is away.
do
    local netBank = OfflineBankCalculator.compute(withOverrides({ staffHeadcount = 0 }))
    assert(netBank == 0, "zero staffHeadcount must always resolve to a 0 net bank")
    print("OfflineBankCalculator.spec: staffHeadcount == 0 short-circuit OK")
end

-- zero-stock: nothing survived to be served, so grossIncome (and therefore netBank) must be 0.
do
    local netBank = OfflineBankCalculator.compute(withOverrides({ remainingStockAfterSpoilage = 0 }))
    assert(netBank == 0, "zero remaining stock must resolve to a 0 net bank")
    print("OfflineBankCalculator.spec: zero-stock OK")
end

-- full-spoil: same shape as zero-stock — everything decayed before it could be served.
do
    local netBank =
        OfflineBankCalculator.compute(withOverrides({ remainingStockAfterSpoilage = 0, elapsedSeconds = 999999 }))
    assert(netBank == 0, "fully spoiled stock must resolve to a 0 net bank even over a long elapsed window")
    print("OfflineBankCalculator.spec: full-spoil OK")
end

-- wage-exceeds-gross: netBank must clamp at 0, never go negative, per PRD §7.4 step 6.
do
    local netBank = OfflineBankCalculator.compute(withOverrides({
        throughputPerHourWhenStaffed = 1,
        remainingStockAfterSpoilage = 1,
        avgPlateValueAtLogout = 1,
        wageRatePerHourPerStaff = 1000,
    }))
    assert(netBank == 0, "wages exceeding gross income must clamp netBank at 0, never negative")
    print("OfflineBankCalculator.spec: wage-exceeds-gross OK")
end

-- long-elapsed: platesServed must cap at remainingStockAfterSpoilage, not grow unbounded with
-- elapsed time.
do
    local netBank = OfflineBankCalculator.compute(withOverrides({
        elapsedSeconds = 100 * 3600,
        remainingStockAfterSpoilage = 5,
        wageRatePerHourPerStaff = 0,
    }))
    local expected = 5 * BASE_INPUTS.avgPlateValueAtLogout
    assert(
        math.abs(netBank - expected) < 1e-9,
        "a long elapsed window must cap platesServed at remainingStockAfterSpoilage, not throughput * elapsed"
    )
    print("OfflineBankCalculator.spec: long-elapsed throughput cap OK")
end

-- resolve: a normal in-range case nets gross income minus wages exactly.
do
    local netBank = OfflineBankCalculator.compute(BASE_INPUTS)
    -- platesServed = min(10 * 1, 100) = 10; gross = 10 * 20 = 200; wages = 2 * 5 * 1 = 10
    assert(math.abs(netBank - 190) < 1e-9, "a normal case must net gross income minus wages exactly")
    print("OfflineBankCalculator.spec: gross-minus-wages resolution OK")
end

print("OfflineBankCalculator.spec: all assertions passed")
