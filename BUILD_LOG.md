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

## 2026-07-28 — M0 prep: cook-verb analysis doc (dev-experience)
- Done: `docs/design/m0-cook-verb-brief.md` — scores 5 candidate cook verbs (timing bar, filleting minigame, slicing swipe, hold-button, + added rhythm/combo tap) on mobile feel, skill expression, ~100×/session repetition tolerance, omakase-ceiling extensibility (Thread #6), and implementation cost; recommends timing bar for cook + tap-to-serve for serve, on branch `claude/sushi-m0-verb-brief`
- Decisions: none locked — this is a recommendation only, for Giahy's grill-me session (Thread #1 stays open until he decides); `TASKS.md` M0-prep row moved to `review`
- Blocked/Open: flagged one genuine open question inside the brief itself — PRD §5's plate-value formula has no slot for verb-execution quality (`cooking_extraction` is stat-driven, not verb-driven), so "what does skillful cooking actually reward" needs a beat in the grill-me session, not an invented fifth multiplier
- Next: Giahy grill-me on the cook/serve verbs using this brief; on lock, update PRD §4 + check off Thread #1 + unblock M3/M4
