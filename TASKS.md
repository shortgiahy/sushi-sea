# Tasks

Live status of PRD §6 modules. Statuses: `todo` · `in-progress` · `review` · `blocked` · `done` (done = full Definition of Done, PRD §11 — not "file exists"). Update every session.

## Wave 1 (current)

| Task | Agent | Status | Branch/PR |
|---|---|---|---|
| M1 toolchain skeleton + CI | dev-systems | review | `claude/sushi-m1-toolchain` |
| M2 player data backbone | dev-systems | todo (after M1) | — |
| M0 prep: cook-verb analysis doc | dev-experience | review | `claude/sushi-m0-verb-brief` |
| Economy table skeleton (Thread #3 prep, doc only) | dev-experience | todo | — |

## Modules

| # | Module | Deps | Status |
|---|---|---|---|
| M0 ⚡ | Cook & serve verb lock (design) | Giahy grill-me | done — locked 2026-07-28 (Giahy): timing bar (cook) + tap-to-serve (serve), see below; PRD §4 vault sync pending |
| M1 | Repo + toolchain skeleton | — | todo |
| M2 | Player data backbone | M1 | todo |
| M3 ⚡ | Fishing feel slice (gray-box) | M0, M2 | review — `claude/sushi-m3-fishing-feel` (dev-gameplay). Cast→hook→reel implemented, headless-testable logic passes, `rojo build`/selene/stylua clean. NOT `done`: the feel gate (PRD §11 DoD, ROADMAP Phase 2) requires a blind/Giahy playtest, which this sandbox cannot run. Human tuning iteration in Studio is the explicit next step — see BUILD_LOG.md 2026-07-28 entry for the reasoning behind every placeholder number. |
| M4 ⚡ | Conversion core + cook verb | M0, M3 | review — `claude/sushi-m4-cook`. `ConversionModule.cook` (yield + grade per the 2026-07-29 cook-verb lock) implemented and headless-tested; `BoatCookController` drives it gray-box on the boat; caught fish now write into `PlayerDataService` inventory (deferred from M3); `rojo build`/selene/stylua clean. NOT `done`: needs a Studio playtest (feel + the "held fish" single-slot simplification) before the M5 serve verb builds on top. See BUILD_LOG.md 2026-08-06 entry. |
| M5 ⚡ | Serve verb + economy faucet | M4 | todo |
| M6 ⚡ | Basic spoilage + slice UI | M5 | todo |
| M7 | Economy tuning model (numbers, with Giahy) | M6 | todo |
| M8 | Spoilage + storage tiers | M7 | todo |
| M9 | Offline bank | M8 | todo |
| M10 | Customer lifecycle | M6 | todo |
| M11 | Restaurant tier + staff | M10, M4 | todo |
| M12 | Prestige + traffic | M11 | todo |
| M13 | Weather system | M2 | todo |
| M14 | Legendary encounter | M3, M13 | todo |
| M15 | Dry-aging locker | M8 | todo |
| M16 | Trophy mounts + gifting | M14 | todo |
| M17 | Omakase counter | M11, M0 | todo |
| M18 | Art pipeline | M6 | todo |
| M19 | Monetization | M12 | todo |
| M20 | Polish + launch prep | M16–M19 | todo |

## Giahy queue

| Item | Blocks |
|---|---|
| M0 cook-verb grill-me session | M3+, the whole vertical slice |
| Cloud environment: `MEM0_API_KEY` var + `mcp.mem0.ai` on a Custom network allowlist + mem0 plugin installed (`/plugin install mem0@mem0-plugins`) | agent memory (tools absent without all three) |
| Local machine: enable Studio's built-in MCP server + Quick Connect Claude Code (`docs/runbooks/roblox-studio-mcp.md`) | Studio-side verification, playtest evidence for `reviewer-reality` |
| Branch protection on `main` | process safety |
| Figma workspace | M6/M18 |

## M0 lock (2026-07-28, Giahy)

**Cook verb: timing bar. Serve verb: tap-to-serve.** Adopted from the `dev-experience` recommendation in `docs/design/m0-cook-verb-brief.md` (branch `claude/sushi-m0-verb-brief`) without a full grill-me session — Giahy's ruling: the verb's specific mechanics are decoupled from the rest of the game by design (PRD §7.6: `ConversionModule.cook(fish) → plate` is the one canonical conversion function; the boat verb and, later, staff AI are just swappable drivers around it), so the choice doesn't warrant blocking other work. M3/M4 are unblocked. Open question from the brief (what verb-execution skill should reward, since PRD §5's plate-value formula has no slot for it) is deferred, not resolved — revisit if/when it actually matters for a specific module, not before.

**Not yet done:** PRD §4 itself is unchanged — this lock lives in this file and mem0 until someone updates the vault-side PRD and runs `scripts/sync-prd.sh`.
