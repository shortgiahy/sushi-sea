# Sushi Sea — Development Roadmap

Execution plan for the agent team. Expands PRD §6 into phases, waves, assignments, and gates. PRD wins on any conflict. Statuses live in `TASKS.md`, never here.

**How to use:** the orchestrator opens the current phase, dispatches the wave's tasks to the named agents (one branch per task), and does not start a module whose deps aren't `done` per the Definition of Done (PRD §11). Giahy Decision Points (🔶) are hard stops — no agent resolves them.

---

## Phase map

| Phase | Modules | Theme | Exit gate |
|---|---|---|---|
| 0 | M0 | Cook & serve verb design 🔶 | Verbs locked in PRD §4 |
| 1 | M1–M2 | Foundation: toolchain + data | CI green; player data round-trips |
| 2 | M3–M6 | **Vertical slice** (gray-box) | Blind playtester enjoys cast→cook→serve→gold |
| 3 | M7–M9 | Economy & the 24–48h dial 🔶 | Numbers model approved; offline bank correct |
| 4 | M10–M12 | Restaurant autonomy | Restaurant runs itself while player fishes |
| 5 | M13–M18 | Depth: weather, legendaries, aging, art | All retention hooks live; gray-box replaced |
| 6 | M19–M20 | Monetization & launch | Reality-checker sign-off; publish runbook handed to Giahy |

Phases are sequential. Waves *inside* a phase run in parallel where deps allow.

---

## Phase 0 — Verb lock (design only) 🔶

**M0 — Cook & serve verb** · blocks everything playable
- Owner: Giahy decision via grill-me. `dev-experience` prepares the brief first.
- Prep task (`claude/sushi-m0-verb-brief`): one doc — the four shelf options (timing bar / filleting minigame / slicing swipe / hold-button) + any new candidates; each scored on: mobile feel, skill expression, 100×/session repetition tolerance, omakase-ceiling extensibility (couples to Thread #6), implementation cost. End with ONE recommendation and the matching serve-verb proposal.
- Exit: Giahy locks both verbs → PRD §4 updated, Thread #1 checked off, M3/M4 unblocked.

## Phase 1 — Foundation

**Wave 1A (parallel):**

| Task | Agent | Branch | Notes |
|---|---|---|---|
| M1 toolchain skeleton | dev-systems | `claude/sushi-m1-toolchain` | Rojo `default.project.json` mapping §7.1 exactly; `rokit.toml` pinning rojo/wally/selene/stylua; empty service/module files with role headers; CI workflow (selene + stylua --check + headless test runner). Exit: `rojo build` produces an openable place; CI green on a trivial test |
| M0 verb brief (above) | dev-experience | `claude/sushi-m0-verb-brief` | Doc only |
| Economy model skeleton (Thread #3 prep) | dev-experience | `claude/sushi-econ-skeleton` | The 5-row faucets−sinks table structure + formulas, values blank for the Phase 3 numbers session. Doc only |

**Wave 1B (after M1):**

| Task | Agent | Branch | Notes |
|---|---|---|---|
| M2 player data backbone | dev-systems | `claude/sushi-m2-playerdata` | `PlayerDataService` with §7.3 schema, `schemaVersion` migration chain, pcall+retry wrapper (§8), logout snapshot fields. Headless tests: serialize/deserialize, migration, retry exhaustion. Exit: join→load→save clean in Studio |

## Phase 2 — Vertical slice ⚡ (gray-box `Part`s only — no art, no Blender)

**Wave 2A:**

| Task | Agent | Branch | Notes |
|---|---|---|---|
| M3 fishing feel slice | dev-gameplay | `claude/sushi-m3-fishing-feel` | `FishingController` cast→hook→reel with placeholder numbers; server-side validation stub in `EconomyService`; tension/timing tuned for *feel*. Expect multiple tuning rounds — feel is the binding retention constraint (council 2026-06-17) |

🔶 **Feel gate:** blind playtester (Giahy or recruit) finds the rod alone satisfying. Iterate M3 until pass. Nothing downstream starts before this.

**Wave 2B (after feel gate):**

| Task | Agent | Branch | Notes |
|---|---|---|---|
| M4 conversion core + cook verb | dev-gameplay | `claude/sushi-m4-cook` | `ConversionModule.cook(fish)→plate` (canonical, §7.6) + `BoatCookController` driving the locked M0 verb |
| M5 serve verb + economy faucet | dev-systems | `claude/sushi-m5-economy` | `EconomyService` plate resolution, all 4 multipliers server-side, clamps at resolution; `FishTable` ~10 authored species; boat serve verb. Headless tests on the formula + clamps |
| M6 spoilage + slice UI | dev-systems (tick) + dev-experience (UI) | `claude/sushi-m6-spoilage`, `claude/sushi-m6-ui` | Basic freshness tick; `FreshnessUI` + gold display |

🔶 **Slice gate:** blind playtester finds the full loop satisfying with gray-box. Reality-checker reviews evidence. This is the go/no-go for the rest of the game.

## Phase 3 — Economy & the 24–48h dial

| Task | Agent | Branch | Notes |
|---|---|---|---|
| M7 economy tuning model 🔶 | dev-experience prepares; **Giahy numbers session** decides | `claude/sushi-m7-economy-model` | Fill the Thread #3 table; single readout: net income/hr vs next-tier cost; throughput cliff ≈ week 6. Threads #3+#5 resolved jointly here |
| M8 spoilage + storage tiers | dev-systems | `claude/sushi-m8-storage` | Real decay rates + storage ladder from M7 numbers; coast lengths per tier match the 24–48h dial |
| M9 offline bank | dev-systems | `claude/sushi-m9-offline` | `OfflineBankCalculator` closed-form (§7.4), net of wages+spoilage, `max(0,…)`. Headless tests: zero-stock, full-spoil, wage-exceeds-gross, long-elapsed |

## Phase 4 — Restaurant autonomy

| Task | Agent | Branch | Notes |
|---|---|---|---|
| M10 customer lifecycle | dev-systems | `claude/sushi-m10-customers` | `CustomerService` 6-stage state machine, per-restaurant independent stream; kitchen throughput = primary bottleneck |
| M11 restaurant tier + staff | dev-systems | `claude/sushi-m11-staff` | Brick-and-mortar unlock; `StaffService` drives the SAME `ConversionModule` (§7.6 — reviewer-code hard-checks no duplication); headcount + wages |
| M12 prestige + traffic 🔶 | dev-experience designs, dev-systems wires | `claude/sushi-m12-prestige` | Yelp prestige (never drops) + hidden traffic formula — Thread #6 items need Giahy sign-off before wiring |

## Phase 5 — Depth & art

| Task | Agent | Branch | Notes |
|---|---|---|---|
| M13 weather system | dev-systems | `claude/sushi-m13-weather` | `WeatherService` events + `Weather_StormBroadcast` + per-player roll-table modification. Storm catalog values 🔶 (Thread #6) |
| M14 legendary encounter 🔶 | dev-gameplay | `claude/sushi-m14-legendary` | Multi-phase reel scaled from M3 numbers (Thread #4 — Giahy locks phase structure first); no buy-in, no loss, per-connection only |
| M15 dry-aging locker | dev-systems | `claude/sushi-m15-aging` | Aging track separate from spoilage; slot management; cash-out timer; clamped mutation roll |
| M16 trophies + gifting | dev-gameplay | `claude/sushi-m16-gifting` | Decay-free mounts; rare-fish gifting; Cooking-gated butchering; no cheap-liquidation path |
| M17 omakase counter | dev-gameplay + dev-experience | `claude/sushi-m17-omakase` | Player counter lifts staff ceiling + boss aura; couples to M0 verb 🔶 |
| M18 art pipeline | dev-experience specs; **Giahy/artist models** | `claude/sushi-m18-art` | `Asset Pipeline.md` manifest + bpy scripts; Blender→FBX→Studio contract (≤10k tris, ≤4 maps, origin pivot, stud scale); replace gray-box. Figma for UI art direction |

## Phase 6 — Launch

| Task | Agent | Branch | Notes |
|---|---|---|---|
| M19 monetization | dev-systems + dev-experience | `claude/sushi-m19-passes` | `PassManager`; cosmetics + convenience ONLY. reviewer-reality checks nothing is pay-to-win |
| M20 polish + launch prep 🔶 | all | `claude/sushi-m20-launch` | Walkout rules, storm catalog, remaining Thread #6 items, full playtest, `Studio Setup.md` runbook, publish handoff to Giahy. Reality-checker final certification |

---

## Giahy Decision Points (🔶) — schedule these; agents stop at each

1. **M0 verbs** (now — blocks Phase 2)
2. **Feel gate** playtest (end of Wave 2A)
3. **Slice gate** playtest (end of Phase 2)
4. **M7 numbers session** (Threads #3+#5, Phase 3)
5. **Prestige/traffic formulas** (Thread #6 subset, Phase 4)
6. **Legendary phase structure** (Thread #4, Phase 5)
7. **Storm catalog + walkout rules + remaining Thread #6** (Phases 5–6)
8. **dev→main merges** at every phase boundary
9. **Publish** (always Giahy)

## Standing rules (every wave)

- One branch per task off `dev`; PR needs green CI + `reviewer-code` + `reviewer-reality`
- Blocked after a full attempt → blocker report → `senior-advisor` (Opus); Locked-Decision conflicts go to Giahy, not the advisor
- Session end: `TASKS.md` + `BUILD_LOG.md` + push — always
- Pure logic (economy, offline bank, spoilage, conversion) ships with headless tests; feel ships with a playtest note

## Risk register

| Risk | Watch | Mitigation |
|---|---|---|
| Rod never passes the feel gate | M3 iteration count climbing | Budget multiple tuning rounds; escalate to senior-advisor for approach change, then Giahy for scope call — do NOT skip the gate |
| Economy compounding outruns sinks | M7 model; net income/hr vs tier cost | Tune spoilage + tier pricing (strong dials); wages are weak |
| Cook verb boring at 100×/session | M0 brief repetition scoring; slice-gate feedback | Verb must be re-lockable without rewriting ConversionModule (driver/logic split makes this cheap) |
| Nigiri-only too shallow for weeks of play (Thread #2) | Slice-gate + Phase 4 playtests | Relief valves post-launch (attribute mixing, farming); pulling either forward is a Giahy scope decision |
| Agent context loss mid-module | Unpushed branches | Push-before-death rule; TASKS.md granular enough to resume a half-done module |
| Studio-only state drifts from repo | Terrain/lighting edits | Everything Rojo can't round-trip goes in `Studio Setup.md` immediately |
