# Tasks

Live status of PRD §6 modules. Statuses: `todo` · `in-progress` · `review` · `blocked` · `done` (done = full Definition of Done, PRD §11 — not "file exists"). Update every session.

## Wave 1 (current)

| Task | Agent | Status | Branch/PR |
|---|---|---|---|
| M1 toolchain skeleton + CI | dev-systems | done (merged to `main`) | `claude/sushi-m1-toolchain` |
| M2 player data backbone | dev-systems | done (merged to `main`) | `claude/sushi-m2-playerdata` |
| M0 prep: cook-verb analysis doc | dev-experience | done (merged to `main`) | `claude/sushi-m0-verb-brief` |
| Economy table skeleton (Thread #3 prep, doc only) | dev-experience | done (merged to `main`) | `claude/sushi-econ-skeleton` |

Wave 1 is complete. CI-green-on-Actions was not independently reconfirmed after merge — flagging, not blocking.

## Modules

| # | Module | Deps | Status |
|---|---|---|---|
| M0 ⚡ | Cook & serve verb lock (design) | Giahy grill-me | done — locked 2026-07-29 (Giahy): two-stage cook (trace→yield, stroke→grade), serve = pure delivery. Spec `docs/design/cook-verb.md`; PRD §4/§5/§6/§7.6/§12 updated 2026-07-29 |
| M1 | Repo + toolchain skeleton | — | done |
| M2 | Player data backbone | M1 | done — Studio join/load/save not yet manually verified (headless-only so far) |
| M3 ⚡ | Fishing feel slice (gray-box) | M0, M2 | in-progress — `claude/sushi-m4-cook` (fishing files touched here too, see note). Reel minigame reworked 2026-08-06 (Giahy, two passes same day): real Stardew Valley roles — a fish sprite drifts on its own (`FishingCatch.fishPositionAt`, deterministic sine-sum), the player moves a fixed-width catch box via hold/release (unchanged control scheme) to keep the fish inside it. Also fixed the progress bar, dead since M3 (never wired to a value) — now mirrors the server's gain/decay formula client-side. Studio-unverified since this rework; needs another playtest pass before the feel gate. |
| M4 ⚡ | Conversion core + cook verb | M0, M3 | review — `claude/sushi-m4-cook`. `ConversionModule.cook` (yield + grade per the 2026-07-29 cook-verb lock) implemented and headless-tested; `BoatCookController` drives it gray-box on the boat; caught fish now write into `PlayerDataService` inventory (deferred from M3). `rojo build`/selene/stylua clean. **Studio-verified 2026-08-06 (Giahy): cast→catch→cook interaction works end-to-end.** NOT `done`: mechanics/feel confirmed not right — the real slicing interaction (drag/angle/speed-consistency, cook-verb.md §2) is **blocked on fish/board geometry that doesn't exist yet** (M18 art pass); current gray-box stand-in exercises the real contract but isn't the intended feel. See BUILD_LOG.md 2026-08-06 entries. |
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
| M17 | Presence aura (was: omakase counter) | M11, M0 | todo |
| M18 | Art pipeline | M6 | todo |
| M19 | Monetization | M12 | todo |
| M20 | Polish + launch prep | M16–M19 | todo |

## Giahy queue

| Item | Blocks |
|---|---|
| ~~M0 cook-verb grill-me session~~ — done 2026-07-29 | ~~M3+, the whole vertical slice~~ |
| ~~Apply the M0 PRD edits~~ — done 2026-07-29, directly in `docs/PRD.md` | ~~M4/M5/M17 acceptance criteria~~ |
| Cloud environment: `MEM0_API_KEY` var + `mcp.mem0.ai` on a Custom network allowlist + mem0 plugin installed (`/plugin install mem0@mem0-plugins`) | agent memory (tools absent without all three) |
| Local machine: enable Studio's built-in MCP server + Quick Connect Claude Code (`docs/runbooks/roblox-studio-mcp.md`) | Studio-side verification, playtest evidence for `reviewer-reality` |
| Branch protection on `main` | process safety |
| Figma workspace | M6/M18 |

## M0 lock (2026-07-29, Giahy)

**Cook verb: two stages at a camera-locked board** — a trace along the cut seam sets *yield*, then one decisive stroke per loin sets *grade* (otoro / chutoro / akami). The outputs are orthogonal so each stage teaches one lesson. **Serve verb: pure delivery**, no order matching. Spec: `docs/design/cook-verb.md`. Locked across 18 branches of the design tree in a grill-me session.

Superseded the provisional 2026-07-28 "timing bar + tap-to-serve" adoption — the timing bar was **ruled out** in the grill-me, because a single gesture producing both yield and grade makes failure undiagnosable.

**Deferred, not resolved:** what verb-execution skill should *reward* beyond yield and grade — PRD §5's formula has no slot for it. Revisit only when a specific module needs it.
