# Tasks

Live status of PRD §6 modules. Statuses: `todo` · `in-progress` · `review` · `blocked` · `done` (done = full Definition of Done, PRD §11 — not "file exists"). Update every session.

## Wave 1 (current)

| Task | Agent | Status | Branch/PR |
|---|---|---|---|
| M1 toolchain skeleton + CI | dev-systems | review | `claude/sushi-m1-toolchain` |
| M2 player data backbone | dev-systems | todo (after M1) | — |
| M0 prep: cook-verb analysis doc | dev-experience | todo | — |
| Economy table skeleton (Thread #3 prep, doc only) | dev-experience | todo | — |

## Modules

| # | Module | Deps | Status |
|---|---|---|---|
| M0 ⚡ | Cook & serve verb lock (design) | Giahy grill-me | blocked (Giahy) |
| M1 | Repo + toolchain skeleton | — | review |
| M2 | Player data backbone | M1 | todo |
| M3 ⚡ | Fishing feel slice (gray-box) | M0, M2 | todo |
| M4 ⚡ | Conversion core + cook verb | M0, M3 | todo |
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
| Cloud environment: `MEM0_API_KEY` var + `mcp.mem0.ai` on a Custom network allowlist | agent memory (tools absent without both) |
| Branch protection on `main` | process safety |
| Figma workspace | M6/M18 |
