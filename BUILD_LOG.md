# Build Log

Append-only. One entry per session, newest last. Format:

```
## YYYY-MM-DD — <session focus>
- Done: <what shipped, with branch/PR>
- Decisions: <anything locked, with why>
- Blocked/Open: <blockers, escalations, questions for Giahy>
- Next: <the single most important next action>
```

## 2026-06-16 — Project scaffolding
- Done: full design infrastructure, since consolidated into `docs/PRD.md`
- Decisions: none locked
- Blocked/Open: cook verb undefined
- Next: grill-me on the cook verb

## 2026-06-17 — Viability council + execution resequence
- Done: no code — council ruled Sushi Sea viable
- Decisions: **game feel (not code velocity) is the binding constraint on retention** — the ruling that put the M3 feel gate ahead of all backend/economy work, and it still governs sequencing
- Blocked/Open: cook verb (Open Thread #1); new feel-tuning gate — rod must pass a blind-playtester test before backend/economy work
- Next: grill-me on cook verb → lock → fishing-only slice (cast-hook-reel) → feel-tuning phase

## 2026-07-05 — Infrastructure bootstrap (Fable 5 + Giahy)
- Done: repo created; HANDOFF.md, CLAUDE.md, TASKS.md, agent roster (6 agents, agency-agents base + Sushi Sea Protocol); PRD copied to docs/; `dev` branch created
- Decisions: dedicated repo (PRD §13 Q1 = B) · PRD §6 sequencing honored · Sonnet orchestrator/workers, Haiku for mechanical tasks, Opus advisor escalation-only · comments stay PRD §8 (reasoning in PRs/commits) · merge gate: auto to dev on CI+2 reviews, Giahy gates main · Figma is the UI tool
- Blocked/Open: M0 cook verb (Giahy grill-me, blocks vertical slice) · branch protection = Giahy manual step · mem0 MCP not connected in bootstrap session — decisions logged here instead
- Next: Wave 1 — M1 toolchain skeleton (`dev-systems`)

## 2026-07-28 — Vault→repo migration (Opus 5 + Giahy)
- Done: staged scaffold moved out of the MIMIR vault into this repo (`HANDOFF`, `CLAUDE`, `ROADMAP`, `TASKS`, `BUILD_LOG`, `README`, 6 agents, `docs/PRD.md`); `.mcp.json` declaring mem0; mem0 protocol bullet added to all 6 agents; `scripts/sync-prd.sh` + `.gitignore`; vault `repo-staging/` deleted
- Decisions: `docs/PRD.md` is a one-way mirror of the vault PRD, enforced by a sync script rather than by discipline — the staged copy had already drifted (it still claimed the repo-layout question was open after §10/§13 Q1 were resolved on 2026-07-05) · mem0 declared at repo root so subagents inherit it, not per-agent
- Blocked/Open: `MEM0_API_KEY` unset in the migration environment, so mem0 tools were unavailable and no memories were written — Giahy must set it as an environment secret · `dev` branch does not exist yet
- Next: Giahy setup checklist (dev branch, MEM0_API_KEY, branch protection), then M0 cook-verb grill-me — still the only thing blocking the vertical slice

## 2026-07-28 — Economy model skeleton (Thread #3 prep, dev-experience)
- Done: `docs/design/economy-model-skeleton.md` (branch `claude/sushi-econ-skeleton`) — 5-row faucets-vs-sinks table (plate sale faucet, staff wages sink, spoilage-driven loss sink, storage/tier upgrade cost sink, offline bank), each row with a formula in named variables and clamps marked `TBD (Giahy numbers session)` or cited as already-locked in PRD §5. TASKS.md row flipped to `review`.
- Decisions: chose a **flow-based** row structure (one row per gold-moving mechanism named in PRD §5/§7) rather than PRD §12 Thread #3's literal **progression-stage** row structure (tutorial/new/mid/late/whale) — the flow rows are the formula substrate the stage table's columns get read off once Giahy assigns numbers; added a mapping section showing which flow row feeds which Thread #3 column so the two structures reconcile explicitly · for the plate-sale-faucet row, cited PRD §5's already-locked clamps by reference instead of repeating the digits, so nothing in this doc could be mistaken for a new numeric decision · excluded "ingredients per plate" and "cosmetics/expansion" (also named in §5's sink stack) from the 5 rows to match the task's named example set and keep the table at 5 rows as specified
- Blocked/Open: none — PRD §5/§7/§12 gave enough grounding to structure all 5 rows without inventing mechanics. mem0 search surfaced an "Agent Mode / unclaimed account" notice unrelated to this task — flagging for Giahy to run `mem0 init --email <email>` at his convenience, not a blocker for this doc
- Next: Giahy numbers session (M7, Phase 3) fills in the `TBD` variables using this skeleton plus the PRD §12 Thread #3 progression-stage table

## 2026-07-29 — Repo/vault separation + M0 PRD application (Opus 5 + Giahy)
- Done: `docs/PRD.md` is now canonical in this repo — `scripts/sync-prd.sh` deleted, mirror language stripped from CLAUDE/HANDOFF/README/TASKS, all 6 agent protocol blocks, and the cook-verb spec header. MIMIR vault's `Projects/Sushi Sea/` deleted; its two pre-repo build-log entries (2026-06-16 scaffolding, 2026-06-17 council) carried into this file so the design history is complete here. Applied the M0 PRD edits enumerated in `docs/design/cook-verb.md` §9 — PRD §4 (cook verb, portion clock, downgrade-not-destroy, staff tiers, presence aura), §5 (`cut_base[species][grade]`, yield formula), §6 (M4/M5/M17 acceptance), §7.6 (`performance` interface), §12 (Thread #1 resolved, #6 omakase resolved, #2 partial relief), Pillar 3 wording
- Decisions: repo owns design outright — the mirror drifted twice in three weeks and left the M0 lock stranded outside the PRD for a full session, so the sync step was the defect, not the discipline around it · `TASKS.md` M0 section rewritten: it still advertised the provisional 2026-07-28 "timing bar" as the lock, which the 2026-07-29 grill-me explicitly **ruled out** — an agent reading TASKS alone would have built the wrong verb
- Blocked/Open: `claude/sushi-docs-sync` is superseded by this change (its Wave 1 status reconciliation is included here, its vault-sync queue row is obsolete) — close it rather than merging · cloud-environment mem0 verification still unconfirmed · branch protection on `main` still open
- Next: M3 fishing feel (`claude/sushi-m3-fishing-feel`, in progress) → feel gate

## 2026-08-06 — M4 Studio playtest fixes + M3 moving catch zone (Sonnet)
- Context: continuation of the M4 reimplementation session. First real Studio playtest surfaced two bugs (`DataStoreService:GetDataStore` throwing outright on an unpublished place, and a stale `rojo serve` process not picking up new RemoteEvents) — both fixed, see prior commits same day. Once playtestable, Giahy's feedback was specific: fishing's catch zone should move (Stardew Valley-style) instead of sitting static, and cooking's gray-box minigame reads as "a Dead by Daylight skill check," not a slicing motion.
- Done (branch `claude/sushi-m4-cook`): Reworked M3's reel minigame — `FishingCatch.targetCenterAt(elapsedSeconds, config)` computes a moving catch-zone center as a deterministic sum of two incommensurate-frequency sine waves (no RNG sync needed between client/server: both derive it from elapsed-time-since-bite alone), clamped to stay on the bar. `FishingCatch.isInBand` replaces the old static `TENSION_TARGET_MIN/MAX` check. `FishingConfig.lua` gained `TARGET_CENTER`/`TARGET_WIDTH`/`TARGET_MOTION_*` (width kept equal to the old band's span — motion is the new difficulty axis, not also narrowing the target). `FishingController.lua` renders the same moving zone client-side via a duplicated copy of the formula (can't require `FishingCatch.lua` — it's ServerStorage-only) and now tracks `state.biteAt` to compute elapsed time locally. `tests/FishingCatch.spec.luau` gained dedicated `targetCenterAt`/`isInBand` coverage; the existing fight-simulation tests were kept meaningful unchanged by giving their `FIGHT_CONFIG` fixture zero motion amplitude (mathematically identical to the old static band). Also ran `stylua` (not just `--check`) over this file and `EconomyService.server.lua` for the first time — surfaced pre-existing formatting debt from M3 that `stylua --check src` never caught because `tests/` wasn't in that path; both are now genuinely clean.
- Decisions (with why):
  - **Deterministic sine-sum motion, not true randomness.** The moving target must render identically enough on client and server that "does the visual line up with what got validated" holds — synchronizing an RNG seed between them is real complexity for no benefit when a pure function of elapsed time gives the same guarantee for free, and evokes Stardew's semi-erratic drift well enough for a gray-box pass.
  - **Target zone WIDTH unchanged (0.40), only added motion.** Nerfing width and adding motion in the same pass would confound whatever Giahy's next playtest reads as "too hard" — motion alone is the one new variable this session introduces.
  - **Cooking's slicing mechanic (drag/angle/speed-consistency per docs/design/cook-verb.md §2) is explicitly NOT touched this session.** Giahy's own read: it can't be built or meaningfully tested without actual fish/cutting-board geometry to slice along, which doesn't exist (gray-box only; that's M18's art pass). The current "stop the marker" stand-in stays as-is — it exercises the real `ConversionModule.cook`/RemoteEvent contract end-to-end, which is what M4's exit criterion needs; the mechanic *feel* is now a documented, explicitly deferred gap rather than something to fake with more skill-check dressing.
- Blocked/Open: the real cook-verb slicing interaction is blocked on M18 art assets (or at minimum placeholder fish/board geometry) — flagging as a concrete dependency for whoever scopes M18, not something to route around with more gray-box cleverness. Fishing's new motion constants are unvalidated placeholders same as every other M3 number — another Studio pass needed.
- Next: Giahy Studio pass on the moving catch zone (feel of `TARGET_WIDTH`/motion amplitudes/frequencies). If that lands, M3's feel gate and M4's Studio-verified status both stand; cooking's real mechanic waits on assets.
