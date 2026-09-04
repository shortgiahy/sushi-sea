-- Headless tests for LegendaryFight (PRD §4 "Legendary creatures"): per-phase catch-box narrowing
-- and Fishing-level relief. Pure module, no Roblox globals — runs under Lune exactly like
-- StaffPerformance.spec.luau.
local LegendaryFight = require("../src/server/ServerStorage/Modules/LegendaryFight")

local TUNING = {
    PHASE_COUNT = 3,
    PHASE_WIDTH_MULTIPLIER = 0.75,
    MIN_CATCH_BOX_WIDTH = 0.12,
    LEVEL_RELIEF_PER_LEVEL = 0.02,
    MAX_LEVEL_RELIEF = 0.20,
    MAX_FISHING_LEVEL_FOR_RELIEF = 10,
}

local BASE_WIDTH = 0.40

-- catchBoxWidthFor: phase 1 at level 1 (no relief) resolves to exactly the base width.
do
    local width = LegendaryFight.catchBoxWidthFor(1, 1, BASE_WIDTH, TUNING)
    assert(math.abs(width - BASE_WIDTH) < 1e-9, "phase 1 at level 1 must resolve to exactly the base width")
    print("LegendaryFight.spec: phase 1 baseline OK")
end

-- catchBoxWidthFor: each subsequent phase narrows geometrically at level 1 (no relief).
do
    local phase2 = LegendaryFight.catchBoxWidthFor(2, 1, BASE_WIDTH, TUNING)
    local phase3 = LegendaryFight.catchBoxWidthFor(3, 1, BASE_WIDTH, TUNING)
    assert(math.abs(phase2 - BASE_WIDTH * 0.75) < 1e-9, "phase 2 must narrow by exactly PHASE_WIDTH_MULTIPLIER")
    assert(math.abs(phase3 - BASE_WIDTH * 0.75 * 0.75) < 1e-9, "phase 3 must narrow geometrically over two phases")
    assert(phase3 < phase2 and phase2 < BASE_WIDTH, "each phase must be strictly narrower than the last")
    print("LegendaryFight.spec: geometric narrowing OK")
end

-- catchBoxWidthFor: level relief widens the box back, capped, and never past the base width.
do
    local lowLevel = LegendaryFight.catchBoxWidthFor(3, 1, BASE_WIDTH, TUNING)
    local highLevel = LegendaryFight.catchBoxWidthFor(3, 10, BASE_WIDTH, TUNING)
    assert(highLevel > lowLevel, "a higher Fishing level must widen the catch box relative to level 1")
    assert(highLevel <= BASE_WIDTH, "relief must never widen the box past the base width")

    local aboveCapLevel = LegendaryFight.catchBoxWidthFor(3, 999, BASE_WIDTH, TUNING)
    assert(
        math.abs(aboveCapLevel - highLevel) < 1e-9,
        "level above MAX_FISHING_LEVEL_FOR_RELIEF must clamp at the same relief as the cap level"
    )
    print("LegendaryFight.spec: level relief OK")
end

-- catchBoxWidthFor: never narrows below MIN_CATCH_BOX_WIDTH even at a late phase and low level.
do
    local width = LegendaryFight.catchBoxWidthFor(3, 1, 0.15, TUNING)
    assert(width >= TUNING.MIN_CATCH_BOX_WIDTH, "catch box width must never clamp below MIN_CATCH_BOX_WIDTH")
    print("LegendaryFight.spec: minimum width floor OK")
end

-- isFinalPhase: true only at/past PHASE_COUNT.
do
    assert(LegendaryFight.isFinalPhase(1, TUNING) == false, "phase 1 of 3 must not be final")
    assert(LegendaryFight.isFinalPhase(2, TUNING) == false, "phase 2 of 3 must not be final")
    assert(LegendaryFight.isFinalPhase(3, TUNING) == true, "phase 3 of 3 must be final")
    print("LegendaryFight.spec: isFinalPhase OK")
end

print("LegendaryFight.spec: all assertions passed")
