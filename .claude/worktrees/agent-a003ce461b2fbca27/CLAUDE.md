# Sushi Sea — Claude Code Context

Roblox game (Luau, mobile-compatible, 18+). Fish → cook → serve → gold. Supply chain is the game.

- **Read order, every session:** `HANDOFF.md` → `ROADMAP.md` (current phase) → `TASKS.md` → tail of `BUILD_LOG.md`. Then search mem0 (`user_id: giahy`).
- **Design source of truth:** `docs/PRD.md`. Locked Decisions are settled; Open Threads (§12) are never resolved unilaterally — surface to Giahy.
- **Architecture:** PRD §7 exactly. **Code standards:** PRD §8 exactly (why-comments only; reasoning goes in commits/PRs/BUILD_LOG).
- **`docs/PRD.md` is a mirror, never edit it here.** Canonical copy is the MIMIR vault at `Projects/Sushi Sea/PRD.md`. PRD changes are Giahy design sessions in the vault; pull them in with `scripts/sync-prd.sh` (`--check` to detect drift).

## Memory (mem0)

- mem0 MCP is declared in `.mcp.json`; it needs `MEM0_API_KEY` in the environment. If the tools are missing, say so — do not pretend memory happened.
- Scope every call to `user_id: "giahy"`. Tag `metadata.type`: `project` (decisions with a why), `feedback` (Giahy's corrections), `reference` (pointers to external systems).
- Search at task start, write at task end. Two memory layers, no overlap: **mem0 = durable decisions and their reasoning**, **git docs (`TASKS.md`, `BUILD_LOG.md`) = build state**. Never put status in mem0 or reasoning-only material in TASKS.
- Subagents inherit this repo's MCP config — they can and should call mem0 themselves.

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
