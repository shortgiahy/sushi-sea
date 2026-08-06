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
