-- OfflineBankCalculator: closed-form snapshot-in/snapshot-out math, net of wages and spoilage (PRD §7.4)
--
-- M9 scope (2026-09-04 Giahy numbers session): implements the §7.4 algorithm exactly as
-- specified — closed-form, never replays the restaurant tick-by-tick. `compute` always resolves
-- to 0 while `staffHeadcount` is 0, which is every player today (M11's staff system doesn't exist
-- yet) — nobody is present to run automated service while the player is offline (PRD §4: "NPC
-- staff run the restaurant... while offline"). Raw-fish/cooked-portion spoilage during the offline
-- gap needs no separate handling here: it's already covered for free by SpoilageService's own
-- elapsed-time-based tick the moment the player reconnects (see that file's header). The full
-- formula (throughput cap, wages, the max(0, ...) floor) is implemented and tested now so M11
-- only has to supply real staffHeadcount/throughputPerHourWhenStaffed/wageRatePerHourPerStaff
-- values later, not touch this module.
local OfflineBankCalculator = {}

export type OfflineBankInputs = {
    elapsedSeconds: number,
    staffHeadcount: number,
    throughputPerHourWhenStaffed: number, -- plates/hour ceiling while offline; ignored when staffHeadcount is 0
    avgPlateValueAtLogout: number,
    remainingStockAfterSpoilage: number, -- servable units (cooked portions) surviving the elapsed window
    wageRatePerHourPerStaff: number,
}

-- netBank = max(0, grossIncome - wages) (PRD §7.4, step 6 — never negative). Both grossIncome and
-- wages are 0 whenever nobody is staffed to run the restaurant while the player is away.
function OfflineBankCalculator.compute(inputs: OfflineBankInputs): number
    if inputs.staffHeadcount <= 0 then
        return 0
    end

    local elapsedHours = inputs.elapsedSeconds / 3600
    local platesServed =
        math.min(inputs.throughputPerHourWhenStaffed * elapsedHours, inputs.remainingStockAfterSpoilage)
    local grossIncome = platesServed * inputs.avgPlateValueAtLogout
    local wages = inputs.staffHeadcount * inputs.wageRatePerHourPerStaff * elapsedHours

    return math.max(0, grossIncome - wages)
end

return OfflineBankCalculator
