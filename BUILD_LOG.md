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

## 2026-07-28 — Roblox Studio MCP wiring (Opus 5 + Giahy)
- Done: `docs/runbooks/roblox-studio-mcp.md` — setup path, tool allow/avoid table, troubleshooting, security note; locked-decisions row in `HANDOFF.md`; standing rule in `CLAUDE.md`; Giahy-queue item in `TASKS.md`; `docs/runbooks/` pointer in `README.md`. Branch `claude/roblox-studio-mcp-setup-wt4for`
- Decisions: use Studio's **built-in** MCP server, not `Roblox/studio-rust-mcp-server` — Roblox moved engineering investment to the built-in one and the standalone repo is now reference-only; the built-in needs no Rust toolchain and no Studio plugin · client scope is `local`, NOT committed to `.mcp.json`: the launch command is an OS-specific absolute path to a Studio-shipped binary, so a committed entry breaks on the other machine and fails in every cloud session (same reasoning that moved mem0 out of `.mcp.json`) · **Studio MCP is an instrument, not an authoring channel** — PRD §10 makes the repo source of truth and Rojo syncs one way, so `multi_edit`/`generate_mesh`/`insert_asset` writes into the place are unversioned, unreviewed, CI-invisible, and destroyed at the next sync; MCP earns its keep on the read side (playtest evidence for `reviewer-reality`, and capturing Studio-only terrain/lighting state into `Studio Setup.md`)
- Blocked/Open: nothing verified against real Studio — the MCP is stdio + a local binary, so it cannot be exercised from a cloud session; the runbook is unconfirmed until Giahy runs it once and reports back · mem0 plugin absent in this environment (tools did not resolve), so these decisions are logged here only and still need writing to mem0 from an environment that has it · the "no AI-generated meshes/materials" line in the tool table is my read of the M18 Blender pipeline, not a Giahy ruling — confirm or overturn
- Next: unchanged — M0 cook-verb grill-me is still the only thing blocking the vertical slice
