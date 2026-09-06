# Sushi Sea — Claude Code Context

Roblox game (Luau, mobile-compatible, 18+). Fish → cook → serve → cash. Supply chain is the game.

- **Reference, not required reading:** `PROGRESS.md` (current status / last session / next steps), `ROADMAP.md` (phase & wave plan), `TASKS.md` (live per-module status), `docs/PRD.md` (design source of truth) each answer a different question. Look up the one your task actually needs instead of reading all of them front-to-back every session.
- **Design source of truth:** `docs/PRD.md`. Locked Decisions are settled; Open Threads (§12) are never resolved unilaterally — surface to Giahy.
- **Architecture:** PRD §7 exactly. **Code standards:** PRD §8 exactly (why-comments only; reasoning goes in commits/PRs/PROGRESS.md).
- **`docs/PRD.md` is canonical and lives here.** There is no vault copy and no sync step (separated 2026-07-29). PRD changes are Giahy design sessions, edited directly in this repo on a branch like any other change. Locked sections still need his sign-off — agents propose, Giahy locks.

## Hard invariants — stop and flag

- Client never sees economy components; server resolves plate value (anti-spoof)
- No wholesale market — a served plate is the only cash faucet
- One `ConversionModule`; manual verb and staff AI are just drivers (§7.6)
- Authored bands, clamped multipliers; no total-loss states; no shared legendary state; no crafting; no recurring debt

## Process

- Model: Sonnet by default; Haiku only for single-file mechanical tasks; Opus (`senior-advisor`) for a second opinion on a genuinely hard technical problem — optional, not a required hop.
- Branches: `claude/sushi-<feature>`, PR straight to `main`. Green CI + Giahy's review to merge — no intermediate `dev` branch (never real practice; every module has always merged straight to `main`) and no mandatory reviewer-agent gate. `reviewer-code`/`reviewer-reality` are still useful checks to run, just not a blocking requirement.
- Session start: `PROGRESS.md`'s Status line for where things stand, `git fetch` + check open PRs/`main` state, then pull whatever `TASKS.md`/`ROADMAP.md`/PRD section the task at hand actually needs.
- Blocked or ambiguous (architectural call, invariant conflict, a PRD Locked Decision/Open Thread) → ask Giahy directly. Director decides, executor implements — no intermediate escalation ladder.
- Session end: update `TASKS.md`, replace `PROGRESS.md`'s status/last-session/next sections, push everything. Unpushed work is lost.
- Publishing to Roblox and Blender/Figma work are Giahy actions — hand over runbooks, never assume automation.
- Studio MCP (Giahy's machine only, never cloud), rule revised 2026-09-04: **code vs. building, not "read-only vs. not."** Game logic is always repo-authored and Rojo-synced — never hand-written into the place, since it wouldn't even survive a Play/Stop cycle. World building (terrain, NPCs, props, materials, placement) is normal Studio-native work, and MCP's authoring tools are fair game for it, same as building by hand. `docs/runbooks/roblox-studio-mcp.md`.
- **Studio-first for UI & world-building:** never generate UI layouts or static world content (terrain, environments, prop placement) purely via runtime instantiation scripts. Build and place UI elements and world objects directly in Studio (or a Studio-authored file Rojo can sync) so they can be inspected immediately, without launching a Play/Test session. This is about content, not logic — game logic stays repo-authored/Rojo-synced per the rule above.
