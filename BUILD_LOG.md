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

## 2026-07-28 — M0 verb lock (Giahy, via Sonnet 5 orchestrator)
- Done: M0 locked without a full grill-me session — Giahy: "the mechanics of it shouldn't affect the rest of the game," ruling the verb choice non-blocking given PRD §7.6's driver/logic split (`ConversionModule` stays canonical regardless of which verb drives it). Adopted the `dev-experience` brief's recommendation: cook verb = timing bar, serve verb = tap-to-serve. `TASKS.md` M0 row set to `done`; M3/M4 unblocked
- Decisions: this is a real Giahy decision made directly in conversation, not an agent inference — recording precisely to avoid any ambiguity about provenance
- Blocked/Open: `docs/PRD.md` §4 still needs the matching edit at the MIMIR vault source (this repo's copy is a one-way mirror, not editable here) — Thread #1 (§12) stays open at the PRD level until that sync happens, even though the practical blocker is cleared and M3+ can proceed. The verb-execution-reward open question from the brief (§5's plate-value formula has no slot for it) is deferred, not resolved
- Next: dispatch M2 (player data backbone, Wave 1B) — the next concretely unblocked module
