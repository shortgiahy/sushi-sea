-- MonetizationConfig: the GamePass catalog (M19, PRD: "F2P; cosmetics and convenience only.
-- Nobody is taxed for winning.")
--
-- M19 scope: this is deliberately a ONE-entry catalog, not a fleshed-out storefront. What to
-- actually sell and at what price is a product/business decision — the same category of call this
-- repo has repeatedly routed to Giahy rather than inventing solo (PRD §12's numbers-session
-- threads, the M7/M10/M11/M12/M13/M15 tuning proposals). `RESEARCHER_HAT` exists only to prove the
-- PassManager wiring end-to-end with something that's safely non-pay-to-win by construction — a
-- purely cosmetic accessory has no mechanical effect to balance, so it can't violate "nobody is
-- taxed for winning" no matter how it's priced. `gamePassId = 0` is a placeholder: GamePasses only
-- get real ids once created in the Creator Dashboard, which requires a published place —
-- publishing is always a Giahy action (PRD, HANDOFF.md).
local MonetizationConfig = {}

export type PassCategory = "cosmetic" | "convenience"

export type PassEntry = {
    gamePassId: number,
    category: PassCategory,
    displayName: string,
}

local GAME_PASSES: { [string]: PassEntry } = {
    RESEARCHER_HAT = {
        gamePassId = 0, -- placeholder — Giahy fills in the real id after creating it post-publish
        category = "cosmetic",
        displayName = "Researcher's Hat",
    },
}
MonetizationConfig.GAME_PASSES = GAME_PASSES

return MonetizationConfig
