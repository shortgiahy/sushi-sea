# Sushi Sea — Team Handoff

Read this first, every session. This document is the mission briefing for any orchestrator or agent picking up the project cold. If this file and your instructions conflict, this file wins; if this file and `docs/PRD.md` conflict, the PRD wins.

## What we're building

Roblox hybrid of *Dave the Diver* / *RuneScape* / *Fisch* / restaurant sim. Fish the open seas, process the catch, run a sushi restaurant. The supply chain IS the game — every fish becomes gold only through a served plate.

- **Design source of truth:** `docs/PRD.md` — a mirror. Canonical copy lives in the MIMIR vault at `Projects/Sushi Sea/PRD.md`. Never edit the mirror; run `scripts/sync-prd.sh` (needs the vault cloned beside this repo, or `MIMIR_VAULT` set) after any vault-side PRD change, and `scripts/sync-prd.sh --check` at session start to catch drift
- **Build order:** PRD §6 modules M0–M20, sequential with explicit deps. Live status: `TASKS.md`
- **Owner:** Giahy. He resolves Open Threads, gates `dev`→`main`, publishes to Roblox, and does Blender/Figma work.

## Locked infrastructure decisions (grill-me, 2026-07-05)

| Topic | Decision |
|---|---|
| Repo | This dedicated repo. Vault keeps design docs; code + agents + process live here |
| Sequencing | PRD §6 honored. No economy/mechanics code before its module gate. M0 (cook verb) blocks the vertical slice — Giahy decision only |
| Orchestrator | **Sonnet** starts and resumes every session |
| Workers | 3 dev + 2 review agents on **Sonnet**; downgrade a task to **Haiku** only if single-file, fully specified, mechanically checkable |
| Senior advisor | **Opus** (`senior-advisor` agent), escalation-only — the advisor strategy: plan/unblock with the smart model, build with fast ones |
| Comments | PRD §8 stands: why-comments only. Reasoning lives in commit messages, PR Reasoning sections, `BUILD_LOG.md` |
| Merge gate | Feature branches → PR to `dev`: merge on green CI + `reviewer-code` + `reviewer-reality` approval. `dev` → `main`: **Giahy only**, at module boundaries |
| Tools | Roblox Studio (Rojo-synced) · Blender (manifest + bpy scripts) · GitHub · **Figma** (UI design) |
| Memory | Git docs (this file, TASKS, BUILD_LOG) = build state. mem0 (`user_id: giahy`) = durable decisions/facts. No cross-session agent memory exists — files are the memory |
| mem0 wiring | Declared in `.mcp.json` at the repo root, so every session and subagent gets it. Needs two things in the cloud environment: `MEM0_API_KEY` as an environment variable, and `mcp.mem0.ai` on the network allowlist (**Custom** access — it is not in the Trusted default list, and a `.mcp.json` HTTP server dials out over the session's own network). Missing either and the tools just don't appear. Every agent's protocol block carries the search-first/write-last rule |

## Session protocol

### Start (orchestrator, Sonnet)
1. Read `HANDOFF.md` (this file) → `ROADMAP.md` (current phase/wave) → `TASKS.md` → last ~3 entries of `BUILD_LOG.md`
2. Search mem0 (`search_memories`, `user_id: giahy`) for recent Sushi Sea decisions
3. `git fetch`; check open PRs and `dev` state
4. Dispatch the current wave (see TASKS.md) to worker agents, one branch per task

### Escalation (advisor strategy)
- Worker attempts the task fully first. Blocked = architectural ambiguity, hard-invariant conflict, or 2 failed approaches.
- Worker writes a **blocker report**: what was tried, why it failed, the specific question.
- Orchestrator routes the report to `senior-advisor` (Opus). Advisor returns a decision + direction; the **worker** implements it.
- If the blocker touches a PRD Locked Decision or Open Thread → stop, surface to Giahy. No workarounds.

### End (every session, non-negotiable)
1. Update `TASKS.md` statuses to reality
2. Append a `BUILD_LOG.md` entry (format in that file)
3. Save durable decisions to mem0 (`metadata.type: project`)
4. Commit and push every branch touched. **Unpushed work is destroyed when the container dies.**

## Branch & review flow

```
claude/sushi-<feature>  ──PR──▶  dev  ──PR (Giahy approves)──▶  main
```

- One logical change per commit; descriptive messages (they are the audit trail)
- PR description must include a **Reasoning** section: approach chosen, alternatives rejected, PRD sections relied on
- CI (once M1 lands): selene + stylua --check + headless tests. Green CI is part of Definition of Done
- Definition of Done (PRD §11): wired end-to-end · verified (playtest or headless test) · both reviewers passed · §8-conformant · CI green

## Agent roster (`.claude/agents/`)

| Agent | Model | Role |
|---|---|---|
| `dev-systems` | sonnet | Server services, DataStore, economy plumbing, spoilage, offline bank |
| `dev-gameplay` | sonnet | Fishing feel, cast/hook/reel, cook/serve verbs, client controllers |
| `dev-experience` | sonnet | UX, onboarding, retention, UI, monetization design, design-doc prep |
| `reviewer-code` | sonnet | Every PR: §8 standards, §7 architecture, hard invariants |
| `reviewer-reality` | sonnet | Module-boundary DoD gate; defaults to NEEDS WORK, demands evidence |
| `senior-advisor` | opus | Escalation only. Advises, never implements |

Base personalities from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents), tuned with the Sushi Sea Protocol block.

## Current wave — Wave 1

| Task | Agent | Notes |
|---|---|---|
| M1: Rojo/Rokit/wally/selene/stylua skeleton + CI | `dev-systems` | Layout per PRD §10; empty service files per §7.1 |
| M2: PlayerDataService + versioned schema | `dev-systems` (after M1) or parallel branch | Schema per PRD §7.3; pcall/retry per §8 |
| M0 prep: cook-verb option analysis doc | `dev-experience` | Analysis ONLY — options, tradeoffs, recommendation. Giahy decides in a grill-me session. Blocks M3+ |
| Economy design prep (Open Thread #3 table skeleton) | `dev-experience` | Doc only, no code. Numbers get a dedicated session with Giahy |

## Giahy's one-time setup checklist

- [x] Create the `dev` branch — done 2026-07-28, seeded at the migration commit. `main` stays at the initial commit until Giahy merges at a module boundary
- [ ] Protect `main` on GitHub (Settings → Branches): require PR, no direct pushes
- [ ] Optional: require 2 approvals on PRs into `dev` (agents approve via review; server-side enforcement is belt-and-suspenders)
- [ ] Create a **Sushi Sea** cloud environment at claude.ai/code (cloud icon above the message box → **Add cloud environment**). Environments carry network access, env vars, and a setup script — they do *not* pin repos; a session reaches any repo the connected GitHub account can see
- [ ] In that environment, set **Network access → Custom**, add `mcp.mem0.ai`, and tick *also include the default list* — mem0 is an HTTP MCP server dialing out over the session network, and its host is not on the Trusted allowlist
- [ ] In that environment, add `MEM0_API_KEY=...` under **Environment variables**. There is no secrets store; env vars are readable by anyone using the environment, so scope the key and rotate it if the environment is ever shared
- [ ] Verify: start a session on this repo in that environment and confirm the mem0 tools are present before trusting any agent's "saved to memory"
- [ ] Pull the MIMIR vault into a session alongside this repo whenever the PRD needs syncing — `scripts/sync-prd.sh` expects it as a sibling directory, or `MIMIR_VAULT` pointed at it
- [ ] Figma workspace for UI design (needed by M6/M18, not now)
- [ ] Roblox Creator Hub remains yours — publishing is always a Giahy action
