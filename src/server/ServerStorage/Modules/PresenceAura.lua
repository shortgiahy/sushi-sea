-- PresenceAura: session-decaying quality multiplier for nearby staff (M17, PRD §4: "the player's
-- presence applies a quality (and speed) aura to nearby staff... needs a shape that rewards
-- visiting rather than parking")
--
-- Not in PRD §7.1's file list — same "pure logic needs to be headlessly testable" deviation every
-- other pure module in this repo already makes. StaffService.server.lua is the sole caller; see
-- RestaurantConfig.lua's header for why "presence" is a play-session proxy rather than real
-- proximity (no world/restaurant geometry exists yet to check against).
local PresenceAura = {}

export type PresenceTuning = {
    BASE_MULTIPLIER: number,
    MIN_MULTIPLIER: number,
    SESSION_DECAY_HALF_LIFE_SECONDS: number,
}

-- Exponential decay from BASE_MULTIPLIER (session start) toward MIN_MULTIPLIER (long-parked),
-- halving every SESSION_DECAY_HALF_LIFE_SECONDS — never below MIN_MULTIPLIER, never above BASE.
function PresenceAura.multiplierFor(sessionSeconds: number, tuning: PresenceTuning): number
    local elapsed = math.max(sessionSeconds, 0)
    local decay = 0.5 ^ (elapsed / math.max(tuning.SESSION_DECAY_HALF_LIFE_SECONDS, 1e-6))
    return tuning.MIN_MULTIPLIER + (tuning.BASE_MULTIPLIER - tuning.MIN_MULTIPLIER) * decay
end

return PresenceAura
