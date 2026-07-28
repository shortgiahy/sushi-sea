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

## 2026-07-28 — mem0 plugin migration (Sonnet 5 + Giahy)
- Done: verified mem0 works cross-session (two independent agents, one wrote a marker fact, the other retrieved it cold — confirmed via the Claude Code mem0 plugin, not this repo's `.mcp.json`); migrated mem0 wiring from a per-repo `.mcp.json` HTTP entry to the account/environment-level mem0 plugin (`/plugin install mem0@mem0-plugins`) — `.mcp.json`'s mem0 block removed to avoid duplicate tool registration; updated `CLAUDE.md`, `HANDOFF.md` (locked-decisions table + setup checklist), `TASKS.md`, `README.md`, and all 6 agent protocol blocks to match; branch `claude/sushi-mem0-plugin-migration` off `dev`
- Decisions: keep the existing `user_id: "giahy"` scoping convention, add explicit `app_id: "sushi-sea"` on every call — this machine has a global `MEM0_PROJECT_ID=GitHub` env var that pins mem0's auto-detected project scope to `"GitHub"` regardless of repo, so relying on auto-detection would silently mix Sushi Sea memories with unrelated ones. `MEM0_API_KEY` + `mcp.mem0.ai` network access requirements are unchanged — only *where* the MCP server is declared changed
- Blocked/Open: this was verified locally, not in the actual Sushi Sea cloud environment — that environment still needs the mem0 plugin installed (new checklist item) before an agent session there can be trusted · no `gh` CLI or GitHub token available in this environment, so branch protection on `main` is still unset and must be done via the GitHub UI · this branch has not been pushed or opened as a PR yet — pending Giahy confirmation
- Next: Giahy pushes/reviews this branch, completes the updated cloud-environment checklist in `HANDOFF.md`, sets branch protection, then Wave 1 (M1 toolchain skeleton) can start

