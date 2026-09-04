-- StaffPerformance: deterministic staff cooking performance from rarity + tenure (M11, PRD §4
-- "Staff": "Deterministic, no per-fish roll... deterministic accuracy → deterministic yield and
-- grade → the bank stays arithmetic.")
--
-- Not in PRD §7.1's file list — same "pure logic needs to be headlessly testable" deviation every
-- other pure module in this repo already makes. StaffService.server.lua is the sole caller; the
-- returned scalar feeds ConversionModule.cook's `performance` contract (§7.6) as both
-- traceAccuracy and a per-loin strokeQuality array (StaffService's job to expand, since only it
-- knows the species' loinCount).
local StaffPerformance = {}

export type StaffRarityTuning = {
    basePerformance: number,
    tenureBonusCap: number,
}

-- Linear ramp from `basePerformance` at hire time to `basePerformance + tenureBonusCap` at
-- `tenureSecondsForFullBonus` elapsed, clamped flat beyond that — same shape as
-- PlateValueResolver's freshness_polish curve, applied to skill instead of decay. An unrecognized
-- rarity resolves to 0 rather than erroring — a content gap (an unlisted rarity ever reaching this
-- function is a bug upstream), matching FishTable.cutBaseFor's "refuse rather than guess" stance.
function StaffPerformance.resolve(
    rarityTuning: StaffRarityTuning?,
    hiredAt: number,
    now: number,
    tenureSecondsForFullBonus: number
): number
    if not rarityTuning then
        return 0
    end

    local tenureElapsed = math.max(now - hiredAt, 0)
    local tenureFraction = math.clamp(tenureElapsed / math.max(tenureSecondsForFullBonus, 1e-6), 0, 1)

    return rarityTuning.basePerformance + tenureFraction * rarityTuning.tenureBonusCap
end

return StaffPerformance
