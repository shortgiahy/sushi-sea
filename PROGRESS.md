# Progress

Living doc: current status, what changed last session, what's next. Each section is *replaced* at session end, not appended — this file stays short by design. Superseded `HANDOFF.md` + `BUILD_LOG.md` on 2026-09-06; full prior session history is still in git (`git log -- HANDOFF.md BUILD_LOG.md`).

## Status

M1–M5 merged to `main`. M6–M19 are all coded on `claude/sushi-m6-spoilage` (one "attempt to one-shot the game" push) — every module's `review`, none `done`: code-complete and headless-tested, but nothing past M5 has been Studio-verified yet. Currently mid-build on the rod-seller NPC + shop feature (schema v7) on top of that branch — see `TASKS.md`'s "Current" section for the exact in-progress/remaining steps.

## Last session (2026-09-06)

- Removed mem0 (memory-layer plugin, network allowlist, per-agent protocol bullets) — dropped in favor of concise in-repo files and normal session context. mem0-side account cleanup (stray `MEM0_CROSSCHECK_MARKER` memory, unclaiming the account) is not repo work — still on Giahy.
- Merged `HANDOFF.md` + `BUILD_LOG.md` into this file; folded the non-redundant session-protocol/escalation rules into `CLAUDE.md`.
- Replaced `CLAUDE.md`'s mandatory sequential doc-read with a reference model — look up what the task needs instead of reading every doc every session.
- Added a `CLAUDE.md` rule: UI and world-building content must be placed directly in Studio, not runtime-instantiated. Note: existing GUI code (`FreshnessUI.lua`, `RestaurantUI.lua`, `ShopUI.lua`, `FishingController._buildGui`) predates this rule and wasn't rewritten — it governs new work going forward, including the not-yet-built rod-shop GUI.
- Deleted `.claude/worktrees/agent-a003ce461b2fbca27/`, a stale committed duplicate of an old repo snapshot carrying dead mem0 wiring.

## Next / blockers

- Decide whether the in-flight rod-shop-NPC GUI (`TASKS.md` step 4, not yet built) should be redesigned Studio-first before that task resumes, given the new UI rule.
- Everything in the pre-existing Giahy queue (`TASKS.md`) still stands: full Studio playtest pass (M3–M19 never run in Studio), branch protection on `main`, Figma workspace, numbers-session follow-ups (WAGE_RATE, throughput cap, purchasing costs), interactive UI still missing (aging locker, trophy mount/gift, GamePass purchase prompt), M18 real modeling.
