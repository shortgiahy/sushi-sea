# M0 — Cook & Serve Verb Lock

Resolution of PRD Open Thread #1. Locked by Giahy in a grill-me session, 2026-07-29.

This document is the **spec**; the PRD is the source of truth. The `docs/PRD.md` mirror is
deliberately untouched — the canonical edits this session requires are listed in
[§9 PRD edits pending](#9-prd-edits-pending-vault-side) and must be applied in the MIMIR vault at
`Projects/Sushi Sea/PRD.md`, then pulled back with `scripts/sync-prd.sh`.

---

## 1. Summary

Cooking is a **two-stage manual verb performed at the boat's midship board**, on a camera-locked
3D cutting board. Stage one is a **trace** along the fish's cut seam and produces **yield**
(portion count). Stage two is a **single decisive stroke per loin** and produces **grade**
(otoro / chutoro / akami). Serving is friction-free delivery with no order matching.

Performance is pure hand skill. Cooking *level* does not touch the difficulty of either stage — it
raises the **worst-case floor** (consistency) and multiplies plate value via the existing
`cooking_extraction` term. **Level buys consistency; hands buy peak.**

---

## 2. The two stages

| Stage | Fiction | Input | Output | Granularity |
|---|---|---|---|---|
| **1. Butchery** (*oroshi*) | Break the fish down off the frame | Drag along the anatomical cut seam | **Yield** — portion count | Per fish |
| **2. Slicing** (*hikizukuri*) | Draw the blade through the loin | One decisive stroke | **Grade** — otoro / chutoro / akami | Per loin |

The two outputs are **orthogonal**. The trace does not influence grade; the stroke does not
influence yield. This is deliberate — two legible lessons rather than correlated noise.

### 2.1 Stage one — the trace

- A cut path is presented along the fish's anatomy. The player drags along it.
- Deviation from the path is meat left on the bone, i.e. lost yield.
- **Accuracy is continuous**, not hit/miss, so yield forms a smooth skill curve.
- **One pass per fish, committed on release. No retry.** A restartable cut is savescummed to
  perfection and makes the skill curve decorative.
- Scales to large-creature butchering (PRD §4) as longer, curvier, multi-segment geometry — the
  same verb, harder path. No new mechanic needed for legendaries.

### 2.2 Stage two — the stroke

- One loin at a time. A single drag; the loin fans into its portions.
- Three read inputs: **angle** (what cut you're making), **straightness** (control),
  **speed consistency** (composure). Sawing back and forth is bad technique in the fiction and
  bad input in the mechanic.
- **One grade per loin**, so a multi-loin fish yields a grade *distribution* with nothing rolled.
- Grade is **pure execution**. Loin anatomy does not cap it; any loin can reach any grade.

### 2.3 Prep tiers

An authored `prepTier` field per species scales ceremony to stakes:

| Tier | Species | Interaction | Time |
|---|---|---|---|
| **Quick** | Small / common | Single short trace; portions come off at base grade. No stage two. | ~2s |
| **Full** | Large / rare / legendary | Full two-stage verb: trace, then a stroke per loin. | ~8–12s |

Times are targets for M4, not locked numbers.

**Known watch item:** quick-tier fish cannot produce premium grades, so early players (catching
mostly commons) see less of the grade system than late players. Verify at the M6 slice gate.

---

## 3. Presentation

- **Camera-locked 3D board**, midship on the boat. Not a 2D UI panel.
- The camera lock makes the world-space raycast against the board plane deterministic — identical
  hand motion produces an identical result on every device and camera angle. This is a
  requirement, not polish: a projection-dependent mapping makes the skill curve a lie.
- **Only the acting player's camera locks.** Other players see the avatar working the board, so the
  shared-world spectacle survives.
- **Gray-box compatible.** A stretched `Part` for the fish and a `Beam`/thin part for the cut path
  satisfy this fully. PRD §6's "do not model fish before the fishing loop feels good" holds; M18
  swaps the blockout for a model and changes nothing else.

### 3.1 Feedback

**Result readout only. No live cue during the stroke.**

- Nothing assists the player mid-cut. The stroke is unassisted and committed, consistent with the
  no-retry rule.
- After each fish: a summary showing **the player's path traced against the ideal**, portions
  produced **against the ceiling that was available** (e.g. "4 of 6"), and the grades that came off.
- The against-the-ceiling comparison is load-bearing. Without a visible ceiling a player cannot
  distinguish a good cut on a small fish from a bad cut on a big one, and the verb reads as random.
- **No anti-spoof concern.** PRD §5's invariant covers *plate value components*. Yield counts and
  grade labels are neither — the client may see them because it cannot change them. The server still
  resolves value alone.

---

## 4. Economy integration

### 4.1 Plate value

`species_base` widens to an authored two-index lookup. **No new multiplier** — the formula's shape
is unchanged, and Pillar 4 ("author the bands, clamp the multipliers") is untouched.

```
served_plate_value = cut_base[species][grade] × cooking_extraction × freshness_polish × dry_age_mutation
```

- `cut_base[species][grade]` — authored in `FishTable`. ~10 species × 3 grades ≈ 30 rows at M5.
- `cooking_extraction` — **unchanged from PRD §5.** `cookingLevel / MAX_LEVEL`, clamp `[0, 1]`.
- `freshness_polish` — **now reads the portion's own clock**, not `caughtAt`. Same linear shape.
- `dry_age_mutation` — unchanged.

### 4.2 Yield

```
yield = round(maxYield[species] × lerp(floorFrac(cookingLevel), 1.0, traceAccuracy))
```

- `maxYield[species]` — authored, **level-independent**. The ceiling never moves.
- `floorFrac` — lerps from ~0.4 at level 1 to ~0.85 at max level.
- Never zero. A botched cut returns a *fraction of species max*, not a flat minimum, so a
  badly-butchered legendary still beats a perfect sardine and the rarity ladder survives.

This is **bounded convergence, not compounding**: levelling raises the bad day toward the good day
and never raises the good day. Cooking level therefore contributes to income twice — once via
`cooking_extraction`, once via consistency — but the second channel is capped by `maxYield`.

### 4.3 Grade floor

A botched stroke floors at **akami** (base grade). There is no grade below akami and no "inedible"
result.

---

## 5. Freshness and the portion clock

**Cutting resets the clock.** A portion does not inherit `caughtAt`; it starts its own timer at
the cut.

```
portion_lifetime = grade_lifetime[grade] × fish_freshness_at_cut
```

- **Per-portion, independent clocks.** Portion *count* does not affect lifetime.
- **Higher grades run out faster.** `grade_lifetime[otoro] < [chutoro] < [akami]`. Anti-hoard
  pressure aimed specifically at premium stock.
- **Scaled by the parent fish's freshness at the moment of the cut.** This closes the laundering
  loophole — without it, a player holds fish until nearly spoiled, then cuts to refresh, and
  spoilage stops leashing anyone who notices.

### 5.1 Expiry — downgrade, not destruction

**Otoro → chutoro → akami → spoiled (tossed).** Only the base grade can be destroyed.

Rationale (this overrode the initially-stated "premium spoils outright"):

- PRD §4 says "spoiled is tossed." Grade-accelerated destruction would place a **total-loss state
  directly on top of the skill reward** — a hard invariant violation (CLAUDE.md; Pillar 1:
  *"forfeits a gain you could have had, never destroys something you own"*).
- §4 already resolved this exact tension for dry-aging: "past peak, the fish doesn't ruin — it sits
  there making no money." One consistent rule for premium decay, not two contradictory ones.
- Under destroy-on-expiry, **deliberately cutting worse is sometimes correct** (stay at akami to
  keep stock stable). Any rule that rewards sandbagging the verb will be found and exploited.
- Anti-hoard intent is fully preserved: bank a vault of otoro, wake up with a vault of akami. The
  loss is real and scales with grade.

**M7 tuning risk:** value now decays on two axes simultaneously — continuously via
`freshness_polish` and stepwise via grade downgrade. `freshness_polish` is clamped `[0.5, 1.5]`, so
it is bounded, but the combined curve needs checking in the numbers session.

---

## 6. Loop shape

- **Cooking is free-choice, any time.** Not interleaved-on-catch, not a gated prep phase. One fish
  or twenty, mid-trip or at the dock.
- Because `freshness_polish` reads the portion clock, and the portion clock starts at the cut,
  **cutting early shortens the sale window**. Timing is therefore a real choice, not a neutral one —
  cut when you intend to serve.
- **Serving is pure delivery.** Walk the plate over and hand it off. No order matching, no grade
  requirements, no plating minigame. §4's "ordering" lifecycle stage becomes meaningful at M10 for
  the restaurant, not on the boat.

---

## 7. Automation and the staff transition

### 7.1 `ConversionModule` interface

PRD §7.6 is honored literally — one canonical module, two drivers, no duplicated logic.

```
ConversionModule.cook(fish, performance) -> portions

performance = {
    traceAccuracy = number,      -- [0, 1]
    strokeQuality = {number},    -- [0, 1] per loin; empty for quick-tier
}
```

- `BoatCookController` fills `performance` from real input.
- `StaffService` synthesizes it.

### 7.2 Staff performance

- **Deterministic, no per-fish roll.** Required, not preferred: PRD §7.4 is emphatic that the
  offline bank is closed-form and must not replay the restaurant tick-by-tick. Deterministic
  accuracy → deterministic yield and grade → the bank stays arithmetic.
- **Capped by staff rarity tier, NOT by "below the player."** A common cook is solid; a rare chef
  matches a good player; a legendary chef beats most players.
- **High floors — staff do not botch.** Their accuracy band is narrow and sits near their tier
  ceiling. Hiring good staff is a reward, never a downgrade in plate quality.
- PRD §4's "each staff member's Cooking skill levels up the longer you keep them" gets its
  mechanism here: their accuracy scalar rises with tenure, so retention is an economic decision.

### 7.3 The late game is management

The player is **never punished for being absent**. A well-staffed kitchen runs at full quality.

- **Manual cooking remains available at all times** (free choice, §6). It stays worthwhile until the
  player's staff outgrow their hands — a crossover that happens organically per-player rather than
  on a scripted rail.
- **The omakase counter is dropped as a separate product.** No premium seating, no customer variant,
  no player-run counter minigame.
- **Player presence boosts staff *quality*** (not only speed), and therefore profit. The boss aura
  becomes a quality multiplier on staff `performance`.

**Accepted consequence:** the two-stage cook verb is **early-to-mid-game content**. That is
defensible — the boat phase is where retention is won, and M0–M6 (the entire near-term build) is
judged on exactly this verb at the M6 slice gate.

**M17 hazard to solve later:** presence-boosts-quality creates an incentive to *idle* in the
restaurant, which competes with fishing — the other half of the game. The aura needs a shape that
rewards **visiting rather than parking** (diminishing over a session, or a per-shift cap).

---

## 8. Carried risks and open items

| Item | Owner | Notes |
|---|---|---|
| `cooking_extraction` needs a floor or a curve | M7 | `cookingLevel / MAX_LEVEL` clamped `[0,1]` makes a level-1 plate worth ~1–5% of `cut_base`. The tutorial boat would earn nothing. Suggest a floor around `[0.3, 1.0]`. It is now the sole *direct* value channel for level, so this is load-bearing. |
| Two-axis value decay | M7 | Continuous `freshness_polish` + stepwise grade downgrade. Check the combined curve. |
| Quick-tier players see less grade variety | M6 slice gate | Early players catch mostly commons, which cannot produce premium grades. |
| Aura-parking incentive | M17 | See §7.3. |
| Knife / board as a Purchasing tier | Thread #6 | Not decided. If equipment widens the trace corridor it becomes a third level-adjacent channel — check against the compounding caution in §5 before adding. |
| Grade has no demand-side | M10 | With pure-delivery serving, grade is a value number with no tactical consequence. If the grade system feels inert at the slice gate, order matching is the lever to reach for. |

## 8.1 Thread #2 (menu variety) — partial relief

Grades triple the effective menu (~10 species × 3 grades) **without adding a single recipe** and
without leaving the nigiri-only constraint. This does not close Thread #2, but it materially
weakens the case for pulling the post-launch attribute-mixing relief valve forward.

---

## 9. PRD edits pending (vault-side)

Apply in the MIMIR vault at `Projects/Sushi Sea/PRD.md`, then run `scripts/sync-prd.sh`.

1. **§4 — Onboarding & the boat→restaurant transition.** Define the cook verb per §2 above.
2. **§4 — Staff.** Add rarity tiers; state that staff quality is tier-capped and may equal or
   exceed the player; staff have high floors and do not botch.
3. **§4 — Customer simulation.** Rewrite *"Staff run the standard menu to a ceiling; the player,
   when present, runs an omakase counter that lifts the ceiling, plus a modest boss-aura speed bonus
   to nearby staff"* → the player's presence applies a **quality** (and speed) aura to staff. No
   separate omakase product.
4. **§4 — The leash: perishability.** Add the portion clock (§5 above) and the
   downgrade-before-spoil rule.
5. **§5 — Economy.** `species_base` → `cut_base[species][grade]`; `freshness_polish` reads the
   portion clock rather than `caughtAt`. Add the yield formula (§4.2 above) as a separate,
   non-value channel.
6. **§6 — Modules.** M4 acceptance gains the two-stage verb and the `performance` interface; M5
   gains the graded `FishTable`; M17 shrinks to the presence aura.
7. **§12 — Open Threads.** Thread #1 → **resolved, 2026-07-29** (this document). Thread #6's
   omakase-counter entry → resolved as the presence aura. Note Thread #2's partial relief.
