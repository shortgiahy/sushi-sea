# Economy Model Skeleton — Faucets vs. Sinks

> **This is a starting structure for the Phase 3 / M7 numbers session, not a locked model.**
> It exists to give the Giahy numbers session (PRD §12 Open Thread #3, resolved jointly with Thread #5 — see ROADMAP.md Phase 3 / M7) a formula-level scaffold to fill in, so that session starts from named variables instead of a blank page. **No numeric value in this document is decided.** Every rate, threshold, and cost is `TBD (Giahy numbers session)`. Where a clamp is already locked elsewhere in the PRD (§5), this doc cites the source instead of repeating the digits, so nothing here can be mistaken for a new decision.
>
> Do not treat any formula shape here as locked either, except where explicitly marked "(locked, PRD §X)" — the rest is a first-pass structure for the numbers session to confirm, adjust, or replace.

## Scope

PRD §12 Thread #3 frames the eventual numbers-session deliverable as a **progression-stage table** (rows: tutorial boat, new restaurant, mid, late, whale; columns: avg plate value, plates/hr, headcount, wages/hr, spoilage/hr, net income/hr, time to next tier). That table can't be filled in without first knowing *what formula produces each column*. This document is that substrate: a **flow-based** faucets-vs-sinks table (one row per gold-moving mechanism named in PRD §5/§7), each with a formula in named variables. The M7 numbers-session table's columns are read off these rows once values are assigned.

Only mechanics the PRD already names are included — nothing here is invented. Source citations are given per row.

## The 5 rows

### 1. Plate Sale Faucet

**Direction:** faucet (the only one — PRD §5: "One faucet: a served dish," enforced server-side in `EconomyService`).

**Source:** PRD §5 (formula + clamp table, Locked), §7.1 (`EconomyService`, `FishTable.lua`), §7.6 (`ConversionModule.cook(fish) -> plate`).

**Formula (locked, PRD §5 — reproduced verbatim for context, not re-decided here):**

```
served_plate_value = species_base × cooking_extraction × freshness_polish × dry_age_mutation
```

| Variable | Definition | Clamp |
|---|---|---|
| `species_base` | `FishTable.lua` authored lookup, per species | none — locked in PRD §5 as the large term |
| `cooking_extraction` | `cookingLevel / MAX_LEVEL` | locked in PRD §5 — see source, not repeated here |
| `freshness_polish` | linear function of `now - caughtAt` | locked in PRD §5 — see source, not repeated here |
| `dry_age_mutation` | rare roll on locker pull (`DryAgingLocker`) | locked in PRD §5 — see source, not repeated here |

**Aggregate faucet rate (new structure — not in §5, TBD):**

```
gross_income_per_hour = plates_served_per_hour × avg(served_plate_value)
```

- `plates_served_per_hour`: bounded by kitchen throughput (PRD §4 "kitchen throughput is the primary bottleneck") — `throughputCap`: `TBD (Giahy numbers session)`
- `avg(served_plate_value)`: depends on the four locked multipliers above plus whatever mix of species/freshness/mutation actually occurs at a given progression stage — this is exactly the "avg plate value" column of the Thread #3 table.

### 2. Staff Wages Sink

**Direction:** sink (mandatory, scales with headcount).

**Source:** PRD §5 sink stack ("Staff wages — mandatory, scales with headcount; low early, a real line item at brick-and-mortar tier"), §4 Staff section ("Wages scale with headcount"), §7.4 offline bank wages term.

**Formula:**

```
wages_per_hour = staffHeadcount × WAGE_RATE
```

(§7.4 shows the same shape scoped to an offline window: `wages = data.restaurant.staffHeadcount × WAGE_RATE × elapsed`.)

| Variable | Definition | Value |
|---|---|---|
| `staffHeadcount` | from `PlayerData.restaurant.staffHeadcount` (§7.3) | computed from hiring, not authored |
| `WAGE_RATE` | gold/hour per staff member | `TBD (Giahy numbers session)` |

**Note:** PRD §5's economy caution and ROADMAP's risk register both flag wages as **a weak dial** relative to spoilage rate and next-tier pricing — do not lean on `WAGE_RATE` to control the throughput cliff; it's here for completeness, not as a primary lever.

### 3. Spoilage-Driven Loss Sink

**Direction:** sink (mandatory, drains inventory upstream of income — PRD §5).

**Source:** PRD §4 "The leash: perishability" and "Temporal model" clarification (offline service is freshness-governed), §5 sink stack ("Spoilage — mandatory, drains inventory upstream of income"), §7.1 `SpoilageService`, §7.3 inventory schema (`caughtAt`), §7.4 offline bank spoilage step, §12 Thread #5 (decay rates unset).

**Formula structure:**

```
freshnessState(item) = f(now - item.caughtAt)   →  {fresh, stale, spoiled}
spoiledCount_per_hour = rate at which inventory entries cross into "spoiled" and are removed pre-sale
value_lost_per_hour ≈ spoiledCount_per_hour × avg(species_base × cooking_extraction)
```

Items on the aging track (`agingLocker`, §7.3) are **not** part of this row — PRD §4 is explicit that aging fish "leave the spoilage track and enter the aging track"; spoilage loss only applies to standard inventory.

| Variable | Definition | Value |
|---|---|---|
| `decayRate` (per species/tier) | freshness-timer slope | `TBD (Giahy numbers session — PRD §12 Thread #5)` |
| `staleThreshold`, `spoiledThreshold` | freshness-timer breakpoints feeding `freshness_polish` (Row 1) and the fresh/stale/spoiled state | `TBD (Giahy numbers session)` |
| storage-tier decay modifier | PRD §4: "storage upgrades raise capacity *and* slow spoilage" | `TBD (Giahy numbers session)` |

**Note:** this is "the leash" — PRD §1 names spoilage as **the dial tuned to hit the 24–48h return target**, jointly resolved with Thread #5 per §12. It is one of the two strong dials named in §5's economy caution (the other is Row 4).

### 4. Storage / Tier Upgrade Cost Sink (Purchasing)

**Direction:** sink (large, lumpy, player-initiated).

**Source:** PRD §5 sink stack ("Purchasing (rods, boats, equipment, storage, restaurant tiers) — large, lumpy, player-initiated"), §4 "Purchasing" skill (purchase-only, no crafting — Design Pillar 2/§3 hard constraint), §7.1 `ShopUI`, §12 Thread #6 ("Purchasing tiers: boats, rods, equipment, storage, restaurant tiers — ladder, costs, unlocks").

**Formula structure:**

```
tierUpgradeCost(category, tierIndex) = authored lookup   -- Design Pillar 4: "author the bands, clamp the multipliers" — a hand-authored table, not a computed formula
time_to_next_tier = tierUpgradeCost / net_income_per_hour
```

`time_to_next_tier` is the direct read for PRD §12 Thread #3's stated output question: *"does net income/hr grow faster than next-tier cost?"*

| Variable | Definition | Value |
|---|---|---|
| `tierUpgradeCost` table | authored per (category, tierIndex); categories named in §5: rods, boats, equipment, storage capacity, restaurant tiers | `TBD (Giahy numbers session)` — authored, not derived |

**Note:** PRD §5's economy caution names **next-tier pricing** as the other strong dial (with spoilage rate) governing the income-vs-sink curve; the throughput cliff should land around week 6 per §12 Thread #3 and ROADMAP's M7 exit criteria.

### 5. Offline Bank (net faucet/sink reconciliation)

**Direction:** hybrid — nets Row 1 (frozen at logout) against Row 2 and Row 3 for the offline window; PRD §4 calls it a "computed bank... net of payroll."

**Source:** PRD §7.4 `OfflineBankCalculator` (exact algorithm already specified structurally), §4 Temporal model.

**Formula (already given in PRD §7.4 — reproduced with named variables, no numbers filled in):**

```
elapsed            = now - offlineSnapshotAt
[spoilage step]     = removes stock that decays past "stale" during `elapsed`   -- uses Row 3's decayRate
platesServed        = min(throughputCap × elapsed, remainingStockAfterSpoilage)
grossIncome         = platesServed × avgPlateValueAtLogout                       -- uses Row 1's formula, frozen at logout state
wages               = staffHeadcount × WAGE_RATE × elapsed                       -- uses Row 2's variables
netBank             = max(0, grossIncome - wages)                                -- never negative, per PRD §7.4
```

| Variable | Definition | Value |
|---|---|---|
| `throughputCap` | plates/hour ceiling while offline, presumably scaling with restaurant tier (§4: "capacity scaling on the storage/restaurant upgrade line") | `TBD (Giahy numbers session)` |
| `WAGE_RATE`, `decayRate`, thresholds | shared with Rows 2 and 3 | `TBD (Giahy numbers session)` |

**Note:** PRD §7.4 is explicit — **closed-form only, do not replay the restaurant tick-by-tick.** This row's job in the numbers session is to confirm the closed-form math balances against Rows 1–3's per-hour rates, not to introduce a new mechanic.

## How this feeds the M7 numbers-session table

PRD §12 Thread #3's actual deliverable is a 5-row **progression-stage** table (tutorial boat / new restaurant / mid / late / whale) with columns `avg plate value, plates/hr, headcount, wages/hr, spoilage/hr, net income/hr, time to next tier`. Once Giahy assigns real numbers to the variables above, those columns fall out directly:

| Thread #3 column | Sourced from |
|---|---|
| avg plate value | Row 1 |
| plates/hr | Row 1 (`throughputCap`, gated by kitchen throughput per §4) |
| headcount | player-progression assumption per stage (not a formula output) |
| wages/hr | Row 2 |
| spoilage/hr | Row 3 |
| net income/hr | Row 1 minus Rows 2 + 3 |
| time to next tier | Row 4 |

Row 5 (offline bank) doesn't map to a Thread #3 column directly — it's the reconciliation check for M9 (`OfflineBankCalculator`), built from the same shared variables.

## Open items carried into M7 (Threads #3 + #5)

Everything below remains `TBD (Giahy numbers session)` — nothing here should be inferred or estimated ahead of that session:

- `WAGE_RATE`
- `decayRate` per species/tier, `staleThreshold`, `spoiledThreshold`, storage-tier decay modifier
- `throughputCap` per restaurant tier (both live and offline)
- `tierUpgradeCost` table across all Purchasing categories (rods, boats, equipment, storage, restaurant tiers)
- headcount and stage assumptions for the tutorial/new/mid/late/whale rows themselves

This document does not attempt to resolve, estimate, or default any of the above. Doing so would be a unilateral resolution of Open Thread #3, which PRD §3/§11 forbid.
