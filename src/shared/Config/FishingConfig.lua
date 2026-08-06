-- FishingConfig: placeholder tuning knobs for the M3 gray-box cast->hook->reel loop (PRD §7.7)
--
-- None of these numbers are validated against real play yet — this sandbox has no blind
-- playtester (PRD §1 retention thesis; ROADMAP risk register: "Rod never passes the feel gate").
-- Every constant below is a reasoned starting guess, not a locked value. Human iteration in
-- Studio is the explicit next step (see TASKS.md M3 row) — expect all of these to move.
--
-- Reasoning behind the starting bands:
-- - Cast/bite pacing (CAST_COOLDOWN, BITE_WAIT_*) keeps the "waiting" beat short. This loop
--   repeats on the order of 100x/session (same repetition-tolerance framing the M0 cook-verb
--   brief used), so idle waiting shouldn't dominate.
-- - HOOK_REACTION_WINDOW is short enough to demand attention (the "hook" is a reaction-time
--   beat, the moment PRD §1 names as the retention-critical one) but wide enough to clear
--   normal human reaction time plus a little network latency.
-- - The catch zone MOVES (TARGET_CENTER drifts via TARGET_MOTION_*, 2026-08-06: Giahy's Studio
--   feedback was explicit that a static band reads wrong — it should feel like Stardew Valley's
--   fishing minigame, where the fish drifts and the player chases it, not a fixed zone the player
--   parks in). TARGET_WIDTH (0.40) keeps the *zone's own size* as wide/forgiving as the old static
--   band was — motion is the new difficulty axis, not also narrowing the target — because this is
--   still a mobile-compatible game (PRD platform table). See FishingCatch.lua's targetCenterAt for
--   why the motion is a deterministic sum of two sine waves rather than true randomness.
-- - PROGRESS_GAIN/DECAY rates are set so a fight is winnable with ~5 cumulative seconds of
--   in-band tension inside a 12s budget — enough headroom for the oscillation a first-time
--   player produces while learning the band.
-- - Out-of-band tension *decays* progress, it does not zero it out or fail the fight outright:
--   small mistakes cost progress, not the whole catch, matching Pillar 1 (PRD §2) — opportunity
--   cost, not punishment — even at the mechanical level of a single fight.
-- - This is a stub-scope simplification worth flagging explicitly: every cast in this slice
--   eventually gets a bite (no miss chance). A spawn/miss-chance system is a natural future
--   dial but isn't part of the three core verbs this module scopes (cast/hook/reel) — adding it
--   now would blur into M13/M14's weather-driven spawn-table territory.
--
-- Split: TENSION_RISE/FALL_RATE and the display/animation timings are client-only feel knobs
-- (the server never needs to know how the client derived a tension value, only the value
-- itself). Everything else here is shared-authoritative — client and server must agree on it
-- for the fight simulation to feel consistent. Both live in one file anyway so a human tuning
-- "the fishing feel" has one place to look.
local FishingConfig = {}

-- Cast
FishingConfig.CAST_COOLDOWN_SECONDS = 1.5
FishingConfig.MAX_CAST_DISTANCE_STUDS = 120
FishingConfig.CAST_FLIGHT_SECONDS = 0.45

-- Bite (anticipation window before the hook beat)
FishingConfig.BITE_WAIT_MIN_SECONDS = 2.0
FishingConfig.BITE_WAIT_MAX_SECONDS = 6.0

-- Hook (reaction beat once a bite starts)
FishingConfig.HOOK_REACTION_WINDOW_SECONDS = 1.2

-- Reel (tension minigame)
FishingConfig.FIGHT_DURATION_SECONDS = 12.0
FishingConfig.TARGET_CENTER = 0.55
FishingConfig.TARGET_WIDTH = 0.40
-- Motion: raw = TARGET_CENTER + AMPLITUDE_1*sin(t*FREQUENCY_1) + AMPLITUDE_2*sin(t*FREQUENCY_2 + PHASE_2),
-- clamped to keep the zone fully on the bar. Amplitudes sum to 0.42, giving the center room to
-- swing well off its resting point without pinning against the clamp on every cycle. Frequencies
-- 0.9 and 2.3 rad/s are deliberately non-multiples of each other so the combined motion doesn't
-- read as a single obvious period — placeholder like everything else here, tune by feel.
FishingConfig.TARGET_MOTION_AMPLITUDE_1 = 0.28
FishingConfig.TARGET_MOTION_FREQUENCY_1 = 0.9
FishingConfig.TARGET_MOTION_AMPLITUDE_2 = 0.14
FishingConfig.TARGET_MOTION_FREQUENCY_2 = 2.3
FishingConfig.TARGET_MOTION_PHASE_2 = 1.7
FishingConfig.TENSION_SNAP_THRESHOLD = 0.95
FishingConfig.PROGRESS_GAIN_PER_SECOND_IN_BAND = 0.20
FishingConfig.PROGRESS_DECAY_PER_SECOND_OUT_OF_BAND = 0.08
FishingConfig.MIN_REEL_INPUT_INTERVAL_SECONDS = 0.08

-- Client-only feel knobs (not sent to / validated by the server)
FishingConfig.TENSION_RISE_RATE_PER_SECOND = 1.4
FishingConfig.TENSION_FALL_RATE_PER_SECOND = 1.0
FishingConfig.RESULT_MESSAGE_DISPLAY_SECONDS = 2.5

return FishingConfig
