# Build Log

Append-only. One entry per session, newest last. Format:

```
## YYYY-MM-DD — <session focus>
- Done: <what shipped, with branch/PR>
- Decisions: <anything locked, with why>
- Blocked/Open: <blockers, escalations, questions for Giahy>
- Next: <the single most important next action>
```

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
