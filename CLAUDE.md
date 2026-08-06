# Sushi Sea — Claude Code Context

Roblox game (Luau, mobile-compatible, 18+). Fish → cook → serve → gold. Supply chain is the game.

- **Read order, every session:** `HANDOFF.md` → `ROADMAP.md` (current phase) → `TASKS.md` → tail of `BUILD_LOG.md`. Then search mem0 (`user_id: giahy`).
- **Design source of truth:** `docs/PRD.md`. Locked Decisions are settled; Open Threads (§12) are never resolved unilaterally — surface to Giahy.
- **Architecture:** PRD §7 exactly. **Code standards:** PRD §8 exactly (why-comments only; reasoning goes in commits/PRs/BUILD_LOG).
- **`docs/PRD.md` is canonical and lives here.** There is no vault copy and no sync step (separated 2026-07-29). PRD changes are Giahy design sessions, edited directly in this repo on a branch like any other change. Locked sections still need his sign-off — agents propose, Giahy locks.

## Memory (mem0)

- **Wiring (revised 2026-07-28):** mem0 comes from the Claude Code **mem0 plugin** (`/plugin install mem0@mem0-plugins`), installed at the account/environment level — not from a per-repo `.mcp.json` entry (that entry was removed; `.mcp.json` is now empty on purpose, to avoid duplicate tool registrations if both were declared). The plugin must be installed wherever a Sushi Sea session runs, and that environment still needs `MEM0_API_KEY` in the environment and `mcp.mem0.ai` reachable on the network — same backend, same auth, just installed once instead of declared per-repo. If the tools are missing, say so — do not pretend memory happened.
- Tool names are plugin-prefixed (e.g. `mcp__plugin_mem0_mem0__add_memory`) and may show up as **deferred tools** — if a call fails because the schema isn't loaded, run `ToolSearch` with `"select:mcp__plugin_mem0_mem0__<tool_name>"` first.
- **Scope every call explicitly** — `user_id: "giahy"`, `app_id: "sushi-sea"`. Do not rely on the plugin's auto-detected defaults: this account has a global `MEM0_PROJECT_ID=GitHub` environment variable that pins auto-detected `app_id` to `"GitHub"` regardless of which repo a session is rooted in, and the unclaimed-account default `user_id` is `"default"`. Passing both explicitly sidesteps that. Tag `metadata.type`: `project` (decisions with a why), `feedback` (Giahy's corrections), `reference` (pointers to external systems).
- Search at task start, write at task end. Two memory layers, no overlap: **mem0 = durable decisions and their reasoning**, **git docs (`TASKS.md`, `BUILD_LOG.md`) = build state**. Never put status in mem0 or reasoning-only material in TASKS.
- Subagents inherit the parent session's installed plugins — they can and should call mem0 themselves, with the same explicit `user_id`/`app_id`.
- Sanity check anytime: `/mem0:health` (connectivity) and `/mem0:tour` (browse what's stored, filtered to the scope above).

## Hard invariants — stop and flag

- Client never sees economy components; server resolves plate value (anti-spoof)
- No wholesale market — a served plate is the only gold faucet
- One `ConversionModule`; manual verb and staff AI are just drivers (§7.6)
- Authored bands, clamped multipliers; no total-loss states; no shared legendary state; no crafting; no recurring debt

## Process

- Orchestrator: Sonnet. Workers: Sonnet (Haiku only for single-file mechanical tasks). `senior-advisor` (Opus): escalation only — advises, never implements.
- Branches: `claude/sushi-<feature>` off `dev`. PRs target `dev`; merge needs green CI + `reviewer-code` + `reviewer-reality`. `dev`→`main` is Giahy-only.
- Session end: update `TASKS.md`, append `BUILD_LOG.md`, save decisions to mem0, push everything. Unpushed work is lost.
- Publishing to Roblox and Blender/Figma work are Giahy actions — hand over runbooks, never assume automation.
- Studio MCP (Giahy's machine only, never cloud) is read/playtest-only: inspect, playtest, capture console + screenshots. Never author game code or assets through it — repo is source of truth, Rojo syncs one way, Studio-side writes die at the next sync. `docs/runbooks/roblox-studio-mcp.md`.
