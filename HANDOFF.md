# Sushi Sea — Team Handoff

Read this first, every session. This document is the mission briefing for any orchestrator or agent picking up the project cold. If this file and your instructions conflict, this file wins; if this file and `docs/PRD.md` conflict, the PRD wins.

## What we're building

Roblox hybrid of *Dave the Diver* / *RuneScape* / *Fisch* / restaurant sim. Fish the open seas, process the catch, run a sushi restaurant. The supply chain IS the game — every fish becomes gold only through a served plate.

- **Design source of truth:** `docs/PRD.md` — canonical, and it lives here. No vault copy, no sync step, no drift to check (separated 2026-07-29). Edit it on a branch like anything else; Locked sections (§1–§5, §7–§11) still need Giahy's sign-off, and Open Threads (§12) are never resolved unilaterally
- **Build order:** PRD §6 modules M0–M20, sequential with explicit deps. Live status: `TASKS.md`
- **Owner:** Giahy. He resolves Open Threads, gates `dev`→`main`, publishes to Roblox, and does Blender/Figma work.

## Locked infrastructure decisions (grill-me, 2026-07-05)

| Topic | Decision |
|---|---|
| Repo | This dedicated repo owns everything — design, code, agents, process. The MIMIR vault holds no Sushi Sea material (separated 2026-07-29; it previously kept the canonical PRD and the repo mirrored it) |
| Sequencing | PRD §6 honored. No economy/mechanics code before its module gate. M0 (cook verb) blocks the vertical slice — Giahy decision only |
| Orchestrator | **Sonnet** starts and resumes every session |
| Workers | 3 dev + 2 review agents on **Sonnet**; downgrade a task to **Haiku** only if single-file, fully specified, mechanically checkable |
| Senior advisor | **Opus** (`senior-advisor` agent), escalation-only — the advisor strategy: plan/unblock with the smart model, build with fast ones |
| Comments | PRD §8 stands: why-comments only. Reasoning lives in commit messages, PR Reasoning sections, `BUILD_LOG.md` |
| Merge gate | Feature branches → PR to `dev`: merge on green CI + `reviewer-code` + `reviewer-reality` approval. `dev` → `main`: **Giahy only**, at module boundaries |
| Tools | Roblox Studio (Rojo-synced, + built-in MCP server on Giahy's machine) · Blender (manifest + bpy scripts) · GitHub · **Figma** (UI design) |
| Memory | Git docs (this file, TASKS, BUILD_LOG) = build state. mem0 (`user_id: giahy`, `app_id: sushi-sea`) = durable decisions/facts. No cross-session agent memory beyond mem0 exists — files are the memory otherwise |
| mem0 wiring (**revised 2026-07-28**, was: declared in `.mcp.json`) | The Claude Code **mem0 plugin** (`/plugin install mem0@mem0-plugins`) must be installed in every environment that runs a Sushi Sea session — this is now an account/environment-level install, not a per-repo `.mcp.json` entry (that entry was removed to avoid duplicate tool registrations). The environment still needs, exactly as before: `MEM0_API_KEY` as an environment variable, and `mcp.mem0.ai` on the network allowlist (**Custom** access — it is not in the Trusted default list). Missing either and the tools just don't appear. New requirement vs. the old wiring: always pass `user_id`/`app_id` explicitly — this account has a global `MEM0_PROJECT_ID=GitHub` var that would otherwise pin auto-detected `app_id` to `"GitHub"` in any repo. Every agent's protocol block carries the search-first/write-last rule and the explicit scoping |
| Roblox Studio MCP (**added 2026-07-28**) | Use Studio's **built-in** MCP server (Assistant → ⋯ → Manage MCP Servers), not the legacy `Roblox/studio-rust-mcp-server` standalone. stdio transport + a local Studio binary, so it runs **only on Giahy's machine — never in a cloud session**. Client scope is `local`, never committed to `.mcp.json` (OS- and machine-specific path). Standing rule: it is a **read/playtest instrument, not an authoring channel** — PRD §10 keeps the repo as source of truth and Rojo syncs one way, so anything MCP writes into the place is unversioned and dies at the next sync. Setup + tool allow/avoid table: `docs/runbooks/roblox-studio-mcp.md` |

## Session protocol

### Start (orchestrator, Sonnet)
1. Read `HANDOFF.md` (this file) → `ROADMAP.md` (current phase/wave) → `TASKS.md` → last ~3 entries of `BUILD_LOG.md`
2. Search mem0 (`search_memories`, `user_id: giahy`, `app_id: sushi-sea`) for recent Sushi Sea decisions
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
- [ ] Configure the **Default** cloud environment at claude.ai/code (cloud icon above the message box → hover Default → settings gear). One environment, not a Sushi-Sea-specific one: a second environment is one more thing to remember to select, and forgetting fails silently. Environments carry network access, env vars, and a setup script — they do *not* pin repos; a session reaches any repo the connected GitHub account can see
  - **Network access → Custom**, add `mcp.mem0.ai`, tick *also include the default list*. Verified 2026-07-28: under Trusted that host fails the CONNECT tunnel with a proxy 403 while `api.github.com` and `registry.npmjs.org` return 200 — mem0 is an HTTP MCP server dialing out over the session network
  - **Environment variables** → `MEM0_API_KEY=...`. No secrets store exists; env vars are readable by anyone using the environment, so keep the key scoped
  - Install the mem0 plugin: `/plugin marketplace add mem0ai/mem0` then `/plugin install mem0@mem0-plugins` (**new step, 2026-07-28** — mem0 is no longer wired via `sushi-sea/.mcp.json`, that entry was removed; it's now an account/environment-level plugin install, same as the vault would use)
  - All three are required. Missing any one leaves the mem0 tools absent with no error pointing at the cause
- [ ] Verify in a **new** session — running sessions copy env vars once at startup and never re-read them. Confirm the mem0 tools are present (`/mem0:health`) before trusting any agent's "saved to memory". Note: cross-session write/read was confirmed working locally on 2026-07-28 via the plugin — this checkbox is specifically about confirming it *in the actual cloud environment*, which is untested
- [ ] Figma workspace for UI design (needed by M6/M18, not now)
- [ ] Roblox Creator Hub remains yours — publishing is always a Giahy action
