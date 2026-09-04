# Tasks

Live status of PRD §6 modules. Statuses: `todo` · `in-progress` · `review` · `blocked` · `done` (done = full Definition of Done, PRD §11 — not "file exists"). Update every session.

## Wave 1 — CLOSED

| Task | Agent | Status | Branch/PR |
|---|---|---|---|
| M1 toolchain skeleton + CI | dev-systems | done (merged to `main`) | `claude/sushi-m1-toolchain` |
| M2 player data backbone | dev-systems | done (merged to `main`) | `claude/sushi-m2-playerdata` |
| M0 prep: cook-verb analysis doc | dev-experience | done (merged to `main`) | `claude/sushi-m0-verb-brief` |
| Economy table skeleton (Thread #3 prep, doc only) | dev-experience | done (merged to `main`) | `claude/sushi-econ-skeleton` |

## Current (2026-09-04)

M3, M4, and M5 branches merged to `main` (PRs #12/#13/#14) — TASKS.md hadn't been updated since; reconciled at session start. M6, M7 (partial), M8, and M9 all landed this session on `claude/sushi-m6-spoilage`, proceeding without M5's Studio playtest pass per Giahy's call — that verification, plus M3/M6/M8's own, is still outstanding, tracked in the Giahy queue below rather than blocking further backend work.

## Modules

| # | Module | Deps | Status |
|---|---|---|---|
| M0 ⚡ | Cook & serve verb lock (design) | Giahy grill-me | done — locked 2026-07-29 (Giahy): two-stage cook (trace→yield, stroke→grade), serve = pure delivery. Spec `docs/design/cook-verb.md`; PRD §4/§5/§6/§7.6/§12 updated 2026-07-29 |
| M1 | Repo + toolchain skeleton | — | done |
| M2 | Player data backbone | M1 | done — Studio join/load/save not yet manually verified (headless-only so far) |
| M3 ⚡ | Fishing feel slice (gray-box) | M0, M2 | done (merged to `main`, PR #13) — real Stardew Valley roles: a fish sprite drifts on its own (`FishingCatch.fishPositionAt`, deterministic sine-sum), the player moves a fixed-width catch box via hold/release to keep the fish inside it; progress bar wired to the server's gain/decay formula. **Studio-unverified since the 2026-08-06 rework** — no playtest pass has confirmed the corrected roles feel right; feel gate still open. |
| M4 ⚡ | Conversion core + cook verb | M0, M3 | done (merged to `main`, PR #13). `ConversionModule.cook` (yield + grade per the 2026-07-29 cook-verb lock) implemented and headless-tested; `BoatCookController` drives it gray-box on the boat; caught fish write into `PlayerDataService` inventory. `rojo build`/selene/stylua clean. **Studio-verified 2026-08-06 (Giahy): cast→catch→cook interaction works end-to-end.** Known gap: the real slicing interaction (drag/angle/speed-consistency, cook-verb.md §2) is **blocked on fish/board geometry that doesn't exist yet** (M18 art pass); current gray-box stand-in exercises the real contract but isn't the intended feel. See BUILD_LOG.md 2026-08-06 entries. |
| M5 ⚡ | Serve verb + economy faucet | M4 | done (merged to `main`, PR #14). `PlateValueResolver.lua` implements the full formula (`cut_base × cooking_extraction × freshness_polish × dry_age_mutation`, headless-tested); `FishTable.lua` authors graded `cut_base[species][grade]` for the 5 existing gray-box species (not yet PRD's ~10-species target — flagged as a follow-up content pass). Boat serve verb wired into `BoatCookController.lua`; gold awarded server-side in `EconomyService.server.lua`. `rojo build`/selene/stylua clean, all headless tests green. **Studio-unverified** — no playtest pass yet on the serve button, gold award, or the freshness-decay curve's feel. |
| M6 ⚡ | Basic spoilage + slice UI | M5 | review — `claude/sushi-m6-spoilage`. New pure `SpoilageCalculator.lua` (fresh/stale/spoiled classification, headless-tested) drives `SpoilageService.server.lua`'s periodic sweep (every `EconomyConfig.SPOILAGE_TICK_INTERVAL_SECONDS`) over raw `inventory` and `cookedPortions`; spoiled entries are removed (tossed) before the survivor snapshot is pushed to the client via the new `Spoilage_InventoryUpdate` remote. `FreshnessUI.lua` renders that snapshot plus a running gold total (new `Economy_GoldUpdate` remote, fired on join and after each serve) — client never computes freshness locally, matching the file's original header contract. `rojo build`/selene/stylua clean, all headless tests green. NOT `done`: Studio-unverified; the full otoro→chutoro→akami grade-downgrade chain (PRD §4) is explicitly deferred to M8's real decay model, not built here. Superseded by M8's real numbers below, same branch. |
| M7 | Economy tuning model (numbers, with Giahy) | M6 | partially done — 2026-09-04 quick-pass numbers session (this session, jointly with Thread #5): storage-tier ladder + tier-0 decay thresholds decided (`docs/design/economy-model-skeleton.md` Rows 3-4, PRD §12). `WAGE_RATE`, offline `throughputCap`, and the remaining Purchasing-category costs (rods/boats/equipment/restaurant tiers) stay open — inert until M11 gives real staffing, not blocking M8/M9. Full Thread #3 progression-stage validation table deferred as a follow-up. |
| M8 ⚡ | Spoilage + storage tiers | M7 | review — `claude/sushi-m6-spoilage` (same branch as M6). Real tier-0 decay thresholds replace M6's placeholders (45min/90min raw fish, 20min/40min cooked portions); `PlayerDataSchema` gained `storage.tier` (schema v2→v3 migration, headless-tested) indexing a new 4-tier `EconomyConfig.STORAGE_TIERS` ladder (capacity 10→80, spoilage slowdown 1×→8×, cost 0→15,000g). `SpoilageService` scales tuning per player's tier; `EconomyService._writeCaughtFishToInventory` enforces the capacity cap; a new `Player_PurchaseStorageTier`/`Storage_TierUpdate` remote pair (handled in `EconomyService`, pushed on join from `PlayerDataService`) lets a player buy the next tier, deducting gold. `FreshnessUI` gained a storage readout + upgrade button. `rojo build`/selene/stylua clean, all headless tests green. NOT `done`: Studio-unverified; `tierUpgradeCost` values are first-pass, pending a real playtest read on plates/hour. |
| M9 ⚡ | Offline bank | M8 | review — `claude/sushi-m6-spoilage` (same branch). New pure `OfflineBankCalculator.compute` implements PRD §7.4's closed-form formula exactly (throughput cap, gross income, wages, `max(0, ...)` floor), headless-tested (zero-stock, full-spoil, wage-exceeds-gross, long-elapsed, plus a staffHeadcount-== 0 case). Wired into `PlayerDataService.server.lua`'s `PlayerAdded` handler, crediting gold once per join and re-stamping `offlineSnapshotAt`. NOT `done`: `compute` always nets 0 today since `staffHeadcount` is always 0 (M11 doesn't exist yet) — correct for the current game state, but the formula's real behavior is untested against an actual staffed restaurant until M11 lands. Studio-unverified. |
| M10 ⚡ | Customer lifecycle | M6 | review — `claude/sushi-m6-spoilage` (same branch). New pure `CustomerFlow.lua` (6-stage state machine: arrival→ordering→fulfillment→eating→payment→rating, headless-tested) drives `CustomerService.server.lua`'s tick: spawns customers when seats are free (placeholder rate, not the real M12 traffic formula), pops+resolves a `cookedPortions` entry at fulfillment (same `PlateValueResolver` path as the boat serve verb — one shared kitchen output), credits gold at payment, pushes `Restaurant_CustomerUpdate` for `RestaurantUI`. Rating is a stub — no `prestigePoints` writes (M12's job, Thread #6 unset). NOT `done`: Studio-unverified; spawn/stage-timing constants are first-pass placeholders. |
| M11 ⚡ | Restaurant tier + staff | M10, M4 | review — `claude/sushi-m6-spoilage` (same branch). New `RestaurantConfig.lua` (3-tier ladder 4/8/16 seats, 2,000/10,000/50,000g; 3 staff rarities with hire cost/base performance/tenure bonus; flat `WAGE_RATE_PER_HOUR_PER_STAFF`) — all first-pass numbers from this session's proposal. `PlayerDataSchema` gained `restaurant.staff` roster (schema v4, replacing the old bare `staffHeadcount` int — headless-tested). New pure `StaffPerformance.lua` (deterministic rarity+tenure → performance, headless-tested) feeds the SAME `ConversionModule.cook` the player's manual verb calls (§7.6). `StaffService.server.lua` handles restaurant-tier purchase, staff hiring, and a tick that deducts live wages and auto-cooks one fish per staff member per tick. `RestaurantUI.lua` filled in (tier/upgrade, staff roster/hire buttons, customer list). `rojo build`/selene/stylua clean, all headless tests green. NOT `done`: Studio-unverified; `OfflineBankCalculator`'s wage/throughput inputs are still inert (0) even with real staff now, since those specific numbers remain open (tracked in the Giahy queue). |
| M12 ⚡ | Prestige + traffic | M11 | review — `claude/sushi-m6-spoilage` (same branch). New pure `TrafficStat.lua` (`starsFor`/`multiplierFor`, headless-tested) resolves Yelp stars from `restaurant.prestigePoints` (only ever incremented on a served customer's payment — never drops, PRD §4) and a traffic multiplier from stars+Hospitality+cosmetics (`RestaurantConfig` weights, this session's proposal). `CustomerService` now scales its spawn interval by that multiplier instead of M10's flat placeholder, and pushes `{prestigePoints, stars}` alongside the customer snapshot. `RestaurantUI` shows a "Yelp: x.x / 5.0" line. `rojo build`/selene/stylua clean, all headless tests green. NOT `done`: Studio-unverified; cosmetics contribution is wired but always 0 (no cosmetics system exists), Hospitality contribution is wired but inert (no leveling system exists) — both same "inert until that system lands" status as other cross-module hooks in this repo. |
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
| ~~Cloud environment: `MEM0_API_KEY` var + `mcp.mem0.ai` on a Custom network allowlist + mem0 plugin installed~~ — confirmed working 2026-08-06, mem0 search/write both returned real results this session | ~~agent memory~~ |
| Local machine: enable Studio's built-in MCP server + Quick Connect Claude Code (`docs/runbooks/roblox-studio-mcp.md`) | Studio-side verification, playtest evidence for `reviewer-reality` |
| Studio pass: M3's corrected fishing roles, M5's serve verb/gold/freshness-decay feel, M6-M9's spoilage tick + storage tiers + FreshnessUI panel | Feel gate (M3), slice gate (Phase 2 exit) |
| Numbers session follow-up: `WAGE_RATE`, offline `throughputCap`, remaining Purchasing costs (rods/boats/equipment/restaurant tiers), full Thread #3 progression-stage validation table | M11 real offline-bank behavior; final economy-curve confidence |
| Branch protection on `main` | process safety |
| Figma workspace | M6/M18 |

## M0 lock (2026-07-29, Giahy)

**Cook verb: two stages at a camera-locked board** — a trace along the cut seam sets *yield*, then one decisive stroke per loin sets *grade* (otoro / chutoro / akami). The outputs are orthogonal so each stage teaches one lesson. **Serve verb: pure delivery**, no order matching. Spec: `docs/design/cook-verb.md`. Locked across 18 branches of the design tree in a grill-me session.

Superseded the provisional 2026-07-28 "timing bar + tap-to-serve" adoption — the timing bar was **ruled out** in the grill-me, because a single gesture producing both yield and grade makes failure undiagnosable.

**Deferred, not resolved:** what verb-execution skill should *reward* beyond yield and grade — PRD §5's formula has no slot for it. Revisit only when a specific module needs it.
