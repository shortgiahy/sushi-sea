-- Headless tests for StaffPerformance (PRD §4 "Staff"): deterministic performance from rarity +
-- tenure. Pure module, no Roblox globals — runs under Lune exactly like PlateValueResolver.spec.luau.
local StaffPerformance = require("../src/server/ServerStorage/Modules/StaffPerformance")

local COMMON = { basePerformance = 0.55, tenureBonusCap = 0.10 }
local TENURE_SECONDS_FOR_FULL_BONUS = 50 * 3600

-- Zero tenure resolves to exactly basePerformance — a freshly hired staff member has no bonus yet.
do
    local performance = StaffPerformance.resolve(COMMON, 1000, 1000, TENURE_SECONDS_FOR_FULL_BONUS)
    assert(math.abs(performance - 0.55) < 1e-9, "zero tenure must resolve to exactly basePerformance")
    print("StaffPerformance.spec: zero tenure OK")
end

-- Full tenure (at or past the threshold) resolves to basePerformance + tenureBonusCap, clamped
-- flat beyond the threshold rather than continuing to climb.
do
    local atThreshold =
        StaffPerformance.resolve(COMMON, 0, TENURE_SECONDS_FOR_FULL_BONUS, TENURE_SECONDS_FOR_FULL_BONUS)
    assert(math.abs(atThreshold - 0.65) < 1e-9, "tenure at the threshold must resolve to basePerformance + cap")

    local pastThreshold =
        StaffPerformance.resolve(COMMON, 0, TENURE_SECONDS_FOR_FULL_BONUS * 10, TENURE_SECONDS_FOR_FULL_BONUS)
    assert(math.abs(pastThreshold - 0.65) < 1e-9, "tenure past the threshold must clamp flat, never exceed the cap")
    print("StaffPerformance.spec: full tenure clamp OK")
end

-- Mid-tenure sits strictly between the two bounds, monotonically increasing with elapsed time.
do
    local earlier =
        StaffPerformance.resolve(COMMON, 0, TENURE_SECONDS_FOR_FULL_BONUS * 0.25, TENURE_SECONDS_FOR_FULL_BONUS)
    local later =
        StaffPerformance.resolve(COMMON, 0, TENURE_SECONDS_FOR_FULL_BONUS * 0.75, TENURE_SECONDS_FOR_FULL_BONUS)
    assert(earlier > 0.55 and earlier < 0.65, "mid-tenure must sit strictly between the two bounds")
    assert(later > earlier, "performance must strictly increase with tenure between the bounds")
    print("StaffPerformance.spec: mid-tenure monotonic increase OK")
end

-- An unrecognized rarity (nil tuning — a content gap upstream) resolves to 0 rather than erroring.
do
    local performance = StaffPerformance.resolve(nil, 0, 1000, TENURE_SECONDS_FOR_FULL_BONUS)
    assert(performance == 0, "an unrecognized rarity must resolve to 0, not error")
    print("StaffPerformance.spec: unrecognized rarity OK")
end

print("StaffPerformance.spec: all assertions passed")
