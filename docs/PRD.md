# Sushi Sea — PRD

Single source of truth for Sushi Sea. **A Roblox hybrid of *Dave the Diver*, *RuneScape*, *Fisch*, and a restaurant sim.** Fish the open seas, process the catch, run a sushi restaurant. The supply chain *is* the game — there is no wholesale fish market, so every fish must flow through the kitchen to become cash.

**How to read this doc.** Locked material (§1–§5, §7–§11) is settled — do not relitigate unless Giahy explicitly reopens it. Open Threads (§12) are open — never fill one in unilaterally; surface it and run grill-me. Where something is *recommended / first-pass*, treat it as a default to confirm, not gospel.

---

## 1. Vision

- **One-line:** Fish the open seas, process the catch, run a sushi restaurant.
- **Core conceit:** The supply chain *is* the game. No wholesale fish market, ever — every fish must flow through the kitchen to become cash. Both halves (sea, restaurant) stay load-bearing by construction.
- **Core loop:** Cast → hook → reel → cook → serve → cash → reinvest → reach deeper water / better restaurant.
- **Retention thesis:** Game *feel* (the rod), not content volume, is the binding constraint on retention (council ruling, 2026-06-17). Perishability is the dial tuned to the return target.

| Field | Value |
|---|---|
| Platform | Roblox, mobile-compatible, Luau |
| Demographic | 18+ |
| Tone | Upbeat, arcadey, modern (*Dave the Diver*). No dark or gritty. |
| Algorithm target | 24–48h return rate, tuned primarily by fish perishability |
| Monetization | F2P; cosmetics and convenience only. Nobody is taxed for winning. |
| World | One shared, persistent world. Fishing outcomes roll per-player, client-side, server-validated. |

---

## 2. Design Pillars

Five principles that resolve most new questions. If a principle resolves a question, proceed and note the reasoning in the build log. If it doesn't, it's an Open Thread — surface it.

1. **Risk is always available, never forced, always trades for acceleration — and means opportunity cost, not punishment.** Storm zones, the aging locker, the tutorial loan, and legendary hunts all express this. Failure forfeits a *gain you could have had*, never destroys something you own. A botched legendary costs nothing but the moment; an over-aged fish doesn't ruin — it sits there not making money. *You missed out* beats *you lost everything*. Every new risk surface must obey this.
2. **The supply chain is the only path to cash.** No wholesale market, ever. Both halves stay load-bearing by construction.
3. **Perform every system manually once before it can be automated or expanded.** Manual cast before bite depth. Manual cook and serve on the boat before hiring cooks and servers. Manual sale before staff. Manual cook before the presence aura lifts staff output. This is a literal code path (§7.6), not a philosophy.
4. **Author the bands, clamp the multipliers.** Large values are hand-authored lookups. Formula modifiers are clamped. Nothing large emerges from a chain of multiplications.
5. **Experimentation lives in risk management** (the dry-aging cash-out decision), not combinatorics (recipe mixing).

---

## 3. Golden Rules & Hard Constraints

- **Locked Decisions are settled.** Do not relitigate unless Giahy explicitly reopens one.
- **Open Threads (§12) are open.** Never fill one in unilaterally — grill-me, get the answer, *then* build.
- **Authored vs. computed discipline** (pillar 4) and **manual before automatic** (pillar 3) are code-level constraints, not vibes.
- **Stop and surface if a task pushes toward any of these:**
  - **No crafting** — all durable goods (rods, boats, equipment, capacity, restaurant tiers) are *bought* with cash ("Purchasing," not "Crafting"). No assembly, materials, or gathering.
  - **No wholesale market** — fish only becomes cash through a served plate.
  - **No shared legendary encounters** — catches are per-player rolls; encounters are structurally independent. No kill-steal, no tag-team, no contested spawns.
  - **No total-loss states** — aging is a cash-out timer, not a ruin timer.
  - **No recurring debt** — debt exists only as the tutorial loan + early overarching goal.
- **Client never sees economy components** — the server resolves plate value; the client receives the final resolved number only (anti-spoof invariant).

### Overrides from v1 (these contradict any older material)

1. **World is one shared persistent world — NOT solo-instanced.** v1's "solo-instanced with optional co-op invite" is dead. The sea is a single shared world (Fisch-style); the skill-gate is preserved structurally (§4).
2. **Catches are per-player, client-side rolls.** Two players on the same boat cast into the same water; one may reel a salmon while the other hooks a Kraken. No shared catch, no contested encounter, no kill-stealing — *structurally impossible*, not balanced away.
3. **Aging is a cash-out timer, NOT a ruin timer.** No total-loss state. Risk in this game is opportunity cost, not punishment — game-wide stance.
4. **Debt is tutorial-and-early-goal only — NOT a permanent risk pillar.** Scoped to the onboarding loan and the early overarching goal. Never a recurring late-game mechanic.
5. **"Crafting" skill is really "Purchasing."** No crafting exists. All durable goods are bought with cash. No assembly, materials, or gathering.

Clarification (a tightening, not a contradiction): **offline service is freshness-governed, not storage-governed.** Storage upgrades raise capacity *and* slow spoilage; the real cap on an offline coast is how fast stock spoils.

---

## 4. System Decisions (Locked)

### World architecture
- **One shared, persistent world.** All players share the same ocean and harbor town. Other boats visible on the horizon; the world feels populated.
- **Fishing outcomes are independent per-player client-side rolls** — determined by *your* Fishing level, location, and current weather, not a shared spawn.
- **The skill-gate is structural.** Underleveled players roll worse outcomes and lose hard fights; a crowd can't carry them because there is no crowd on *their* fish.
- **The boat shares *access*, never *outcome*.** A low-Sailing friend can ride a high-level player's storm-rated ship into a zone they couldn't reach alone — but brings their own Fishing skill to the catch.
- **Co-op is parallel play, never shared performance.** Friends on one boat fight *two independent* Krakens side by side. No tag-team reeling.
- **Restaurants are public and tourable.** No private instances.
- **Gifting carries the resource-sharing load** — you can gift the rare fish afterward, not the catch in the water.

### Temporal model
Player freely toggles between sea and restaurant. NPC staff run the restaurant live and while offline. Offline service is throttled and capped; the cap is governed by **freshness/spoilage**, with capacity scaling on the storage/restaurant upgrade line (early game stalls in a few hours; late game can coast 12h+). Offline earnings are a **computed bank** collected on return, **net of payroll**.

### The leash: perishability
Raw fish decays on a freshness timer. Forces restocking, blocks hoard-and-coast, acts as a cash sink, and is **the dial tuned to hit the 24–48h return target**. Fresh serves at full value; stale is penalized; spoiled is tossed. Spoilage runs while offline.

**The portion clock.** Cutting resets the clock — a portion does not inherit its fish's `caughtAt`, it starts its own timer at the cut. `portion_lifetime = grade_lifetime[grade] × fish_freshness_at_cut`. Clocks are per-portion and independent; portion *count* does not affect lifetime. Higher grades run out faster (`otoro < chutoro < akami`), aiming anti-hoard pressure at premium stock. Scaling by the parent fish's freshness *at the moment of the cut* is what closes the laundering loophole — without it a player holds fish to near-spoiled, cuts to refresh, and spoilage stops leashing anyone who notices.

**Expiry downgrades, it does not destroy.** Otoro → chutoro → akami → spoiled (tossed). **Only the base grade can be destroyed.** Grade-accelerated destruction would put a total-loss state directly on top of the skill reward, violating Pillar 1, and would make *deliberately cutting worse* correct play — any rule that rewards sandbagging the verb will be found. Anti-hoard intent survives intact: bank a vault of otoro, wake to a vault of akami. The loss is real and scales with grade.

### Scoreboard and social
- **Restaurant prestige** (public Yelp app) and the **collection dex** are the public flex.
- **Skills** live on a private LinkedIn-style resume app, later doubling as the **staff-hiring screen**.

### Skills (5 at launch)

| Skill                             | Role                                                                                                                                           |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Sailing**                       | Zone access, travel speed, storm tolerance                                                                                                     |
| **Fishing**                       | Bite/reel, catch quality, risk payoff in dangerous water. **Gates outcome, not location.** Drives the legendary fight                          |
| **Cooking**                       | Absorbs filleting, portioning, yield, large-creature butchering, dish assembly. Sets the **extraction rate** and **dry-aging extraction rate** |
| **Hospitality**                   | Staff speed, customer patience, per-table profit **as margin** (never makes a table free to serve). Feeds the hidden traffic stat              |
| **Purchasing** *(was "Crafting")* | Rods, boats, restaurant equipment, capacity. Purchase-only                                                                                     |

*Farming ships post-launch* (rice, seaweed, wasabi, garnishes; premium home-grown stock with random value-multiplier mutations).

### Access model
Fishing level gates *outcome*, not *location*. Anyone can sail into a storm; underleveled it wrecks you, high-level it pays. Ship upgrades are a parallel capability line (cargo, speed, storm survival, area access), bought via Purchasing.

### Customer simulation
- **Independent stream per restaurant** (no finite shared pool). Volume driven by the hidden traffic stat.
- **Six-stage lifecycle:** arrival/seating → ordering → fulfillment → serving/eating → payment → rating.
- **Difficulty distribution:** kitchen throughput is the primary bottleneck (skill expression); stock is secondary (supply-chain pressure); seating is a buy-past soft cap.
- **Staff run the standard menu; the player's presence applies a quality (and speed) aura to nearby staff.** There is no separate omakase product — no premium seating, no customer variant, no player-run counter minigame. The aura multiplies staff `performance`, so presence raises plate quality and therefore profit.
- **Aura hazard to solve at M17:** presence-boosts-quality creates an incentive to *idle* in the restaurant, competing with fishing — the other half of the game. The aura needs a shape that rewards **visiting rather than parking** (diminishing over a session, or a per-shift cap).

### Rating
Single prestige number that accumulates toward 5 stars, **never drops**, public. A recoverable popularity layer is shelved as a known expansion. In-the-moment stakes lean on cash lost to walkouts.

### Onboarding & the boat → restaurant transition
- **The dinky sailboat is the first restaurant:** fish at the stern, cook midship, sell at the bow — the whole loop in one camera frame.
- **On the boat, cooking and serving are MANUAL player verbs.** Locked 2026-07-29 (Open Thread #1; full spec in `docs/design/cook-verb.md`):
  - **Cooking is a two-stage verb at a camera-locked 3D cutting board, midship.** Stage one, *butchery*: drag along the fish's anatomical cut seam. Deviation is meat left on the bone, so accuracy is continuous and produces **yield** (portion count). One pass per fish, committed on release, **no retry** — a restartable cut is savescummed to perfection and makes the skill curve decorative. Stage two, *slicing*: one decisive stroke per loin, reading angle, straightness, and speed consistency, producing **grade** (otoro / chutoro / akami). One grade per loin, so a multi-loin fish yields a grade *distribution* with nothing rolled.
  - **The two outputs are orthogonal** — the trace does not influence grade, the stroke does not influence yield. Two legible lessons rather than correlated noise.
  - **Performance is pure hand skill.** Cooking *level* does not touch the difficulty of either stage; it raises the worst-case floor and multiplies plate value via `cooking_extraction`. **Level buys consistency; hands buy peak.**
  - **Authored `prepTier` per species** scales ceremony to stakes: *quick* (small/common) is a single short trace at base grade with no stage two, ~2s; *full* (large/rare/legendary) is the complete two-stage verb, ~8–12s. Times are M4 targets, not locked numbers. Large-creature butchering is the same verb with longer, curvier, multi-segment geometry — no new mechanic for legendaries.
  - **Result readout only, no live cue during the stroke.** After each fish: the player's path against the ideal, portions produced against the ceiling that was available ("4 of 6"), and the grades that came off. The against-the-ceiling comparison is load-bearing — without a visible ceiling a player cannot tell a good cut on a small fish from a bad cut on a big one, and the verb reads as random. Yield counts and grade labels are not plate-value components, so the client may see them; the server still resolves value alone.
  - **Serving is pure delivery.** Walk the plate over and hand it off. No order matching, no grade requirements, no plating minigame.
  - **Cooking is free-choice, any time** — not interleaved-on-catch, not a gated prep phase. Because `freshness_polish` reads the portion clock, cutting early shortens the sale window, so timing is a real choice: cut when you intend to serve.
  - **Watch item:** quick-tier fish cannot produce premium grades, so early players see less of the grade system than late players. Verify at the M6 slice gate.
- **Brick-and-mortar is the earned upgrade** and the moment staff and autonomy unlock — hire cooks and servers (headcount) who perform cooking and serving automatically.
- **Tutorial:** scripted tutorial wraps the boat loop; rails come off after the loop closes once.
- **Starter loan** clears in a session or two — a narrative on-ramp, not a late-game pillar.

### Staff
An **upgrade line — headcount, nothing more complex.** Browse NPC applicants on the resume/LinkedIn app and recruit. **Each staff member's Hospitality/Cooking skill levels up the longer you keep them** — their accuracy scalar rises with tenure, so retention is an economic decision. Wages scale with headcount.

- **Applicants carry rarity tiers.** Staff cooking quality is **capped by tier, not by the player** — a common cook is solid, a rare chef matches a good player, a legendary chef beats most players. Hiring well is a reward, never a downgrade in plate quality.
- **High floors — staff do not botch.** Their accuracy band is narrow and sits near their tier ceiling.
- **Deterministic, no per-fish roll.** Required, not preferred: §7.4's offline bank is closed-form and must not replay the restaurant tick-by-tick. Deterministic accuracy → deterministic yield and grade → the bank stays arithmetic.
- **The player is never punished for being absent.** A well-staffed kitchen runs at full quality. Manual cooking stays available at all times and stays worthwhile until the player's staff outgrow their hands — a crossover that happens organically per-player rather than on a scripted rail.

### Marketing
Not a player action. A **hidden traffic stat** computed from **Yelp prestige + cosmetics + Hospitality**. Do not build a marketing minigame.

### Dry aging — the experimentation engine
Opt-in, equipment-gated, limited capacity. A fish placed in an aging locker **leaves the spoilage track and enters the aging track.** It is a **cash-out timer, not a ruin timer**: past peak, the fish doesn't ruin — it sits there making no money while occupying a scarce slot. *Pull it now and bank it, or tie up the slot hoping it climbs.* Pure opportunity cost. A full random mutation rolls on aging with **percentage multipliers** (never orders of magnitude); mutations must stay rare. The aging decision is a second return hook alongside restock and drives the 24–48h target directly.

### Legendary creatures & the encounter system
- **The fight is the bite/reel loop, scaled up.** Multi-phase, harder, longer, the creature actively fighting back (tension spikes, "dive" phases, stamina on both sides). Not a bespoke combat system — "fishing turned up to 11."
- **Fishing level gates outcome.** Underleveled = windows too tight, line snaps, fish lost. High-level = same fight is landable and pays enormously.
- **No buy-in, no loss penalty.** Losing costs nothing but the moment.
- **Weather is the spawn table.** Legendaries are weather-triggered, not summonable. The weather app **broadcasts the event to everyone** ("an ink storm is passing through Sector X"), raising every player's independent odds of that storm's legendary in the affected zone.
- **Baseline odds are near-zero-but-nonzero** outside the right weather.
- **The storm is a shared spectacle with private encounters.** Many boats converge; each angler fights their own independent struggle.
- **Trophy mounts** are a pure public flex, decay-free, and goal-markers for catches you can't yet butcher. Legendary butchering is Cooking-gated.
- **Tuning note:** storm window must be long enough that *alert → sail to sector → fight* is achievable. Hook rarity and storm duration are paired dials.

### Gifting
Rare-fish gifting is in — friend-boost and virality engine. Gifted legendaries can be mounted or eventually butchered (Cooking-gated) but **not cheaply liquidated** — no whale-to-alt cash pipe.

### Debt
Exists **only** as the tutorial loan and the early overarching goal.

### Parked reconciliations (honor when building)
1. Hospitality per-table profit improves margin, never removes variable cost — a table is never free to serve.
2. Gifted/unprocessable legendaries route to trophy mount or wait for the Cooking level — never to cheap liquidation.

### Post-launch slots (decided, deferred)
Farming skill · popularity layer (recoverable traffic under the prestige rating) · scored-attribute open mixing (only if nigiri needs more depth) · hybrid customer model (guaranteed base + shared hub-traffic skim for top restaurants) · co-op shared-performance raids (only if per-player-roll architecture is reopened).

---

## 5. Economy

**One faucet: a served dish.** Enforced at `EconomyService`, server-side only.

```
served_plate_value = cut_base[species][grade] × cooking_extraction × freshness_polish × dry_age_mutation
```

| Term | Source | Clamp |
|------|--------|-------|
| `cut_base[species][grade]` | `FishTable.lua` authored two-index lookup — species × grade (otoro / chutoro / akami). ~10 species × 3 grades ≈ 30 rows at M5 | none — it IS the large term |
| `cooking_extraction` | `cookingLevel / MAX_LEVEL` — novice + legendary = mediocre plate | `[0, 1]` |
| `freshness_polish` | linear from the **portion's own clock** (starts at the cut, not `caughtAt`) | `[0.5, 1.5]` |
| `dry_age_mutation` | rare roll on locker pull | `[1.0, ~2.5]` — never orders of magnitude |

The base term widened from `species_base` to a two-index lookup when the cook verb locked (2026-07-29). **No new multiplier** — the formula's shape is unchanged and Pillar 4 is untouched.

**All four multipliers apply server-side only.** The client receives the final resolved value for display, never the components. This is the anti-spoof invariant — do not break it for convenience.

**Yield is a separate, non-value channel.** How many portions a fish produces does not enter `served_plate_value`; it multiplies how many plates exist to sell.

```
yield = round(maxYield[species] × lerp(floorFrac(cookingLevel), 1.0, traceAccuracy))
```

- `maxYield[species]` — authored, **level-independent**. The ceiling never moves.
- `floorFrac` — lerps from ~0.4 at level 1 to ~0.85 at max level.
- **Never zero.** A botched cut returns a fraction of species max, not a flat minimum, so a badly-butchered legendary still beats a perfect sardine and the rarity ladder survives. A botched *stroke* floors at akami; there is no grade below it and no "inedible" result.

This is **bounded convergence, not compounding** — levelling raises the bad day toward the good day and never raises the good day. Cooking level therefore reaches income twice, via `cooking_extraction` and via consistency, but the second channel is capped by `maxYield`.

**Sink stack:**
- **Ingredients per plate** — mandatory, scales with volume
- **Staff wages** — mandatory, scales with headcount; low early, a real line item at brick-and-mortar tier
- **Spoilage** — mandatory, drains inventory upstream of income
- **Purchasing** (rods, boats, equipment, storage, restaurant tiers) — large, lumpy, player-initiated
- **Cosmetics and expansion** — aspirational, uncapped, optional

> **Economy caution:** income has a *compounding* term (plates/hr × rising skill) while mandatory sinks are *flat or lumpy*. The two dials governing the curve are **spoilage rate** (the leash) and **next-tier pricing** (the surplus soak). Wages are a weak dial. Watch for the throughput cliff.

---

## 6. Modules — atomic, sequential

Each module is one independently buildable + verifiable unit. Build in order; do not start a module until its deps are ✅. `⚡` = blocks the vertical slice. Live status stays in `Build Log.md`.

**Prereqs before M1:** §13 answers — repo layout (A `game/` subfolder vs B dedicated repo), art timing, publish handoff.

| # | Module | Deps | Exit / acceptance |
|---|---|---|---|
| M0 ⚡ | **Cook & serve verb lock** *(design)* | — | Open Thread #1 resolved via grill-me; boat cook + serve verbs locked; §4/§12 updated. Nothing playable before this. |
| M1 | **Repo + toolchain skeleton** | §13 Q1 | Rojo project, Rokit-pinned selene/stylua/wally, CI, empty service files per §7.1. `rojo build` opens in Studio; CI green. |
| M2 | **Player data backbone** | M1 | `PlayerDataService` w/ versioned schema (§7.3), pcall/retry, migration chain. Player joins → data loads/saves without error. |
| M3 ⚡ | **Fishing feel slice** *(gray-box)* | M0, M2 | `FishingController` cast→hook→reel + server-side catch validation. **Feel gate:** blind playtester finds the rod alone satisfying. Placeholder numbers. |
| M4 ⚡ | **Conversion core + cook verb** | M0, M3 | `ConversionModule.cook(fish, performance)→portions` (canonical, §7.6) with the `performance` interface in place; `BoatCookController` drives both stages — camera-locked board, trace→yield, stroke→grade, `prepTier` honored, result readout against the ceiling. Manual cook works on the boat. |
| M5 ⚡ | **Serve verb + economy faucet** | M4 | Boat serve verb (pure delivery, no order matching); `EconomyService` plate resolution wired to a **graded** `FishTable` — `cut_base[species][grade]`, ~10 species × 3 grades; all 4 multipliers server-side. |
| M6 ⚡ | **Basic spoilage + slice UI** | M5 | `SpoilageService` basic freshness tick; `FreshnessUI` + cash UI. **Slice gate:** blind playtester finds cast→cook→serve→cash satisfying with gray-box. |
| M7 | **Economy tuning model** *(numbers)* | M6 | Open Threads #3+#5 jointly. 5-row faucets−sinks table; net income/hr grows slower than next-tier cost; throughput cliff ≈ week 6. |
| M8 | **Spoilage + storage tiers** | M7 | Real decay rates; storage tier ladder (capacity + spoilage slowdown). Coast lengths per tier match the 24–48h dial. |
| M9 | **Offline bank** | M8 | `OfflineBankCalculator` snapshot-in/out (§7.4), net of wages + spoilage, `max(0, …)`. Closed-form payout correct on return. |
| M10 | **Customer lifecycle** | M6 | `CustomerService` 6-stage state machine, per-restaurant independent stream driven by traffic stat. |
| M11 | **Restaurant tier + staff** | M10, M4 | Restaurant tier unlock; `StaffService` NPC cook/serve driving the *same* `ConversionModule`; headcount + wages. Restaurant runs standard menu autonomously while player fishes. |
| M12 | **Prestige + traffic** | M11 | Yelp prestige (never drops), hidden traffic stat formula (Open Thread #6), `RestaurantUI`. |
| M13 | **Weather system** | M2 | `WeatherService` events, `Weather_StormBroadcast`, per-player server-side roll-table modification in-zone. |
| M14 | **Legendary encounter** | M3, M13 | Multi-phase reel scaling (Open Thread #4 — needs M3 base numbers); Fishing-gated outcome; no buy-in/loss penalty; per-connection only. |
| M15 | **Dry-aging locker** | M8 | `DryAgingLocker` aging track (separate from spoilage), slot management, cash-out timer, rare mutation roll. Real pull-or-wait decision. |
| M16 | **Trophy mounts + gifting** | M14 | Decay-free mounts; rare-fish gifting; Cooking-gated legendary butchering; no cheap liquidation path. |
| M17 | **Presence aura** | M11, M0 | Player presence applies a quality (and speed) multiplier to nearby staff `performance`. Shaped to reward visiting rather than parking — diminishing over a session or a per-shift cap. *(Scope reduced 2026-07-29: the omakase counter is dropped as a separate product.)* |
| M18 | **Art pipeline** | M6 | `Asset Pipeline.md` manifest + `bpy` scripts; Blender→FBX→Studio contract (≤10k tris, ≤4 maps, origin pivot, stud scale). Gray-box replaced. |
| M19 | **Monetization** | M12 | `PassManager` (GamePass cache + prompt); cosmetics + convenience only. No pay-to-win. |
| M20 | **Polish + launch prep** | M16, M17, M18, M19 | Walkout rules, storm catalog, remaining #6 undefineds, full playtest, `Studio Setup.md` runbook, publish handoff. Reality-check sign-off. |

**Phase mapping** (original roadmap → modules): Phase 0 = M0 · Phase 1 = M1–M2 · Phase 2 = M3–M6 (vertical slice; feel gate on M3) · Phase 3 = M7–M9 · Phase 4 = M10–M12 · Phase 5 = M13–M18 · Phase 6 = M19–M20.

**Sequencing notes**
- M0 → M6 form the vertical slice; the feel gate (M3) precedes economy/backend by council ruling (2026-06-17). The rod must pass a blind-playtester test before economy/backend work.
- M7–M9 share the 24–48h dial (economy ↔ spoilage ↔ offline) — resolve in dedicated numbers sessions with Giahy, not on the fly.
- **Gray-box first.** The vertical slice uses Roblox `Part` blockouts only. Do not model fish before the fishing loop feels good (M18/Phase 5).
- Each phase exit gate passes a `testing-reality-checker` review ("is this actually done?") before advancing.

---

## 7. Architecture — build to this exactly; deviations need Giahy's approval

### 7.1 Roblox service ownership

```
ServerScriptService/
  Services/
    WeatherService.server.lua       -- weather events, legendary spawn tables, broadcast
    PlayerDataService.server.lua    -- DataStore reads/writes, offline bank snapshot/restore
    EconomyService.server.lua       -- plate value resolution, server-side catch validation
    StaffService.server.lua         -- NPC cook/serve AI at brick-and-mortar tier
    CustomerService.server.lua      -- customer spawn process, 6-stage lifecycle state machine
    SpoilageService.server.lua      -- freshness tick for all inventory; runs while offline too
  Init.server.lua                   -- wires all services, no logic here

ServerStorage/
  Modules/
    FishTable.lua                   -- AUTHORED lookup: {species -> base_price}. No computed values.
    ConversionModule.lua            -- cook(fish, performance) -> portions; the ONE conversion implementation
    OfflineBankCalculator.lua       -- snapshot-in / snapshot-out math, net of wages and spoilage
    DryAgingLocker.lua              -- aging track: separate from spoilage, slot management
    PassManager.lua                 -- GamePass ownership cache + purchase prompt

ReplicatedStorage/
  Config/
    EconomyConfig.lua               -- clamped multiplier constants (CLAMP_FRESHNESS, etc.)
    SkillConfig.lua                 -- XP curves, level caps per skill
  Modules/
    FishSpecies.lua                 -- shared fish data client needs for UI (species name, rarity tier)
  Events/
    RemoteEvents/
    RemoteFunctions/

StarterPlayerScripts/
  Controllers/
    FishingController.lua           -- cast/reel input handler; sends to server, receives validation
    BoatCookController.lua          -- manual cook/serve on the boat (TBD — Open Thread #1)
    WeatherClient.lua               -- storm alert display, legendary FOMO UI
  UI/
    RestaurantUI.lua                -- customer display, prestige bar, Yelp app
    FreshnessUI.lua                 -- inventory freshness timers
    ShopUI.lua                      -- Purchasing skill storefront

StarterGui/                         -- UI containers only; logic lives in StarterPlayerScripts
```

### 7.2 RemoteEvent naming

**Server → Client:** `{System}_{Event}`
- `Weather_StormBroadcast` — `{zone, duration, legendaryType, oddsMultiplier}`
- `Economy_PlateResolved` — `{plateValue, breakdown}`
- `Spoilage_InventoryUpdate` — `{inventory}` (freshness state sync)

**Client → Server:** `Player_{Action}`
- `Player_CastLine` — `{location}`
- `Player_ReelInput` — `{tension}` (per-frame during a fight)
- `Player_ServePlate` — `{fishId}` (boat manual serve — TBD)
- `Player_PullFromLocker` — `{slot}` (cash out dry-aging fish)

**Rule:** no client RemoteFunction returns an economy-affecting value. Economy resolves server-side only.

### 7.3 PlayerData schema (DataStore key `PlayerData_v1`)

```lua
{
  skills = {
    fishing     = { level = 1, xp = 0 },
    cooking     = { level = 1, xp = 0 },
    sailing     = { level = 1, xp = 0 },
    hospitality = { level = 1, xp = 0 },
    purchasing  = { level = 1, xp = 0 },
  },
  inventory = {
    -- array of fish in the spoilage track
    { id = "uuid", species = "salmon", caughtAt = 1718000000 },
  },
  agingLocker = {
    -- fish on the aging track (NOT the spoilage track); slot count gated by equipment tier
    { slot = 1, species = "tuna", placedAt = 1718000000 },
  },
  restaurant = {
    tier           = 0,   -- 0 = boat only, 1+ = brick-and-mortar tiers
    staffHeadcount = 0,
    prestigePoints = 0,
    trophies       = {},  -- { species, mountedAt } — legendary mounts
  },
  economy = {
    cash                = 0,
    offlineSnapshotAt   = 0,    -- os.time() at last logout
    offlineStockCount   = 0,    -- fish in inventory at snapshot
    tutorialLoanOwed    = 500,  -- zeroed after repayment; never reused
  },
  meta = {
    schemaVersion = 1,          -- increment on breaking changes; migrate, never overwrite
    firstJoinAt   = 0,
    lastJoinAt    = 0,
  }
}
```

**Migration rule:** if `schemaVersion` doesn't match current, run the migration chain before handing data to any system. Never silently overwrite.

### 7.4 Offline bank (`OfflineBankCalculator`)

On logout: save `offlineSnapshotAt = os.time()` and `offlineStockCount = #inventory`. On next login, `compute(data)`:
1. `elapsed = os.time() - data.economy.offlineSnapshotAt`
2. Compute spoilage: fish that would have decayed past "stale" in `elapsed` are marked lost
3. `platesServed = min(throughputCap × elapsed, remainingStockAfterSpoilage)`
4. `grossIncome = platesServed × avgPlateValueAtLogout`
5. `wages = data.restaurant.staffHeadcount × WAGE_RATE × elapsed`
6. `netBank = max(0, grossIncome - wages)` — never negative
7. Add `netBank` to cash; clear snapshot fields

**Do not replay the restaurant tick-by-tick.** Closed-form only.

### 7.5 Weather & legendary system (one system, both purposes)

1. `WeatherService` selects a weather event: `{zone, type, duration, legendaryType}`
2. Broadcasts `Weather_StormBroadcast` to all clients (FOMO hook)
3. Modifies each player's server-side roll table for `Player_CastLine` in the zone
4. On a legendary hook: multi-phase reel on that player's connection only
5. Other players unaffected — rolls stay independent. **No shared legendary state.**

### 7.6 Manual-then-automate code path

```
[ConversionModule] cook(fish, performance) -> portions
        ↑                                        ↑
 player input                               staff AI
 (BoatCookController)                    (StaffService)

performance = {
    traceAccuracy = number,      -- [0, 1]
    strokeQuality = {number},    -- [0, 1] per loin; empty for quick-tier
}
```

`ConversionModule` in `ServerStorage/Modules/` is the canonical implementation. The boat verb and restaurant staff both call it. **Build the conversion once; swap the driver. Do not duplicate the logic.**

The `performance` table is the seam that makes the swap literal: `BoatCookController` fills it from real input, `StaffService` synthesizes it from the staff member's rarity tier and tenure. Neither driver contains conversion logic, and the cook verb can be re-locked later without touching `ConversionModule`.

### 7.7 Catch resolution
Client-authoritative-feeling but server-validated: per-player rolls must feel instant; validate server-side to prevent spoofed legendary hooks. Weather state is server-authoritative and broadcast. The skill-gate needs no networking logic — no kill-steal/tag/loot-priority systems.

---

## 8. Luau coding standards — all code obeys this

### Naming

| Thing | Convention | Example |
|-------|-----------|---------|
| ModuleScript return table | PascalCase | `FishTable`, `EconomyService` |
| Local variables | camelCase | `catchResult`, `plateValue` |
| Constants | SCREAMING_SNAKE | `MAX_AGING_SLOTS`, `CLAMP_FRESHNESS_MAX` |
| RemoteEvents | `{System}_{Event}` / `Player_{Action}` | `Weather_StormBroadcast`, `Player_CastLine` |
| DataStore keys | `{Name}_v{version}` | `PlayerData_v1` |
| Private module functions | `_camelCase` | `_resolveExtraction` |
| Types (Luau) | PascalCase | `type FishEntry = {...}` |

### Module structure
Every ModuleScript returns a single table. No globals. No shared state in free variables (use `module._state` if needed, documented). Layout: constants → types → `_private` helpers → public API. Use `--!strict` where possible.

```lua
-- ServerStorage/Modules/ExampleModule.lua
local ExampleModule = {}

local SOME_CONSTANT = 42

type Config = { value: number, label: string }

local function _helperFn(x: number): number
    return x * 2
end

function ExampleModule.doThing(config: Config): string
    return config.label .. ": " .. _helperFn(config.value)
end

return ExampleModule
```

### Types
All public functions have typed parameters and return types. Private helpers too unless trivially obvious.

### Error handling
All DataStore calls wrapped in pcall — no exceptions — with the retry pattern (max 3 attempts, exponential backoff):

```lua
local function retryAsync(fn, ...)
    local attempts = 0
    local success, result
    repeat
        attempts += 1
        success, result = pcall(fn, ...)
        if not success then task.wait(2 ^ (attempts - 1)) end
    until success or attempts >= 3
    return success, result
end
```

Do not use `error()` for expected failure paths (player not found, fish spoiled) — return `nil, "reason_string"`. Reserve `error()` for truly unexpected states.

### Economy safety
Never trust client-sent economy values; the server recomputes everything. Clamps are enforced at formula resolution, not display:

```lua
local freshnessPolish = math.clamp(computedFreshness, EconomyConfig.CLAMP_FRESHNESS_MIN, EconomyConfig.CLAMP_FRESHNESS_MAX)
```

### DataStore rules
Schema version field in every store; migrate on mismatch, never silently overwrite. Cache ownership checks (GamePass) once per player per session. `SetAsync` for saves; `UpdateAsync` only for atomic read-modify-write.

### RemoteEvent rules
Server always validates client → server; ignore any client value affecting economy/inventory without recomputation. Server → client fires minimal payloads. Debounce spammable `Player_*` events server-side; reject calls under `MIN_ACTION_INTERVAL`.

### Comments & headers
Default to no comments; write one only when the *why* is non-obvious (e.g. `-- Aging fish are NOT on the spoilage track — SpoilageService must skip locker entries`). Every script gets a one-line role header (`-- WeatherService: server-authoritative weather events and legendary spawn broadcast`) — no author, no date.

### Stop and flag if an implementation requires
A cross-script global · client-authoritative economy math · shared legendary state · a DataStore write without the retry wrapper · a multiplier chain that can exit its authored clamp range.

---

## 9. Toolchain

### Roblox Studio — file-first, synced in
- **The repo is the source of truth; Studio is a view.** Author all game code as `.luau` files mirroring §7.1.
- **[Rojo](https://rojo.space)** syncs the repo into Studio via `default.project.json` mapping `src/` onto the Roblox services exactly as §7.1 specifies.
- **[Rokit](https://github.com/rojo-rbx/rokit)** with pinned `rokit.toml` for `rojo`, `wally`, `selene` (lint), `stylua` (format) — reproducible in ephemeral containers. **Wally** for packages; prefer zero dependencies until one is justified.
- **Testing:** unit tests against pure modules (economy resolution, offline bank, spoilage) run headless in CI. Studio playtests are for feel and integration only.
- **Publishing is a Giahy action** (his Roblox account / Creator Hub). Hand him the `rojo build` command and publish steps; never assume automated publishing.
- **Studio-only assets** (terrain, lighting, physical placement) that Rojo can't round-trip get documented in a `Studio Setup.md` runbook.

### GitHub
Git workflow (branches, merge approval, retries, MCP tools) is governed by the root `CLAUDE.md`. Game-specific additions: fresh `claude/sushi-<feature>` branch per feature; one logical change per commit; CI (GitHub Actions) runs `selene` + `stylua --check` + headless tests on every push — green CI is part of Definition of Done.

### Blender — specify and script, don't sculpt
- No Blender connector exists; the role is **asset manifest + `bpy` scripts**, not interactive modeling. Produce `Asset Pipeline.md`: every model, poly budget, pivot/origin convention, stud scale, texture/material spec, naming. Plus `bpy` scripts where useful (procedural fish scaling, LOD decimation, batch FBX/OBJ export).
- **Export contract:** Blender → `.fbx` (`.obj` for static props) → Studio 3D importer. Roblox-legal: ≤10k tris per `MeshPart`, ≤4 texture maps, pivot at model origin, real-world stud scale.
- **Modeling and importing are Giahy actions** (or an artist's) — hand over manifest, scripts, per-asset acceptance criteria.
- **Gray-box first.** The vertical slice uses Roblox `Part` blockouts only. Do not model fish before the fishing loop feels good (Phase 5 / M18).

---

## 10. Repository layout

**Decided (grill-me 2026-07-05): (B) dedicated repo — `shortgiahy/sushi-sea`.** Extended 2026-07-29: the repo owns **everything**, design included. This document is canonical here; the MIMIR vault holds no Sushi Sea material. The earlier split — vault-canonical PRD, repo mirror, `sync-prd.sh` — is retired: it drifted twice in three weeks and left the M0 lock stranded outside the PRD for a session. Layout:

```
sushi-sea/
  default.project.json          # Rojo: maps src/ onto Roblox services per §7.1
  rokit.toml                    # pinned rojo, wally, selene, stylua
  wally.toml                    # deps (empty to start)
  selene.toml  stylua.toml      # lint + format config
  src/
    server/                     # → ServerScriptService / ServerStorage
    shared/                     # → ReplicatedStorage
    client/                     # → StarterPlayerScripts
    gui/                        # → StarterGui
  tests/                        # headless unit tests (economy, offline bank, spoilage)
  .github/workflows/ci.yml      # selene + stylua --check + tests
  docs/PRD.md                   # this document — canonical
  docs/design/                  # locked-decision specs (cook verb, economy skeleton)
  docs/runbooks/                # Giahy-action runbooks (Studio MCP, publish)
  HANDOFF.md TASKS.md BUILD_LOG.md ROADMAP.md
  .claude/agents/               # the six-agent team
```

---

## 11. Definition of Done, workflow, agents

A system is ✅ only when **all** hold: wired end-to-end (actually called by the running game, not just authored) · manually verified in a Studio playtest (or headless test for pure logic) · passes the code-reviewer agent · obeys §8 · CI green. At each module/phase exit gate, run **testing-reality-checker** with "is this actually done?" — it defaults to "needs work" and demands evidence; that is intentional.

**Design session:** grill-me — one question at a time, walk the dependency tree, attach a recommended answer before Giahy decides. On lock: update §4 → check off in §12 → flip Build Log rows.
**Implementation session:** read §7 + §8 → pick the right agent → write code → code-reviewer → commit. Log every session in `Build Log.md` (format there) and push before the container dies.

Team model (grill-me 2026-07-05; agents live in the game repo's `.claude/agents/`, tuned from agency-agents):

| Agent | Model | Role |
|------|-------|------|
| `dev-systems` | Sonnet | Server services, DataStore, economy plumbing |
| `dev-gameplay` | Sonnet | Fishing feel, cook/serve verbs, client controllers |
| `dev-experience` | Sonnet | UX, retention, UI, monetization, design prep |
| `reviewer-code` | Sonnet | Every PR — §8 + §7 + invariants |
| `reviewer-reality` | Sonnet | Module-boundary DoD gate |
| `senior-advisor` | Opus | Escalation only (advisor strategy) — advises, never implements |

- Orchestrator sessions run Sonnet; Haiku only for single-file mechanical tasks
- Merge gate: feature branch → PR to `dev` (green CI + both reviewers) → Giahy gates `dev`→`main` at module boundaries
- Reasoning lives in commits / PR Reasoning sections / repo `BUILD_LOG.md` — §8 comment rules unchanged
- UI design tool: Figma (4th app alongside Studio, Blender, GitHub)

---

## 12. Open Threads — resolution order; do not invent resolutions

### ~~#1 The cook verb~~ — RESOLVED 2026-07-29
Two-stage verb (trace→yield, stroke→grade) at a camera-locked board; serving is pure delivery. Locked by Giahy; specified in §4 (Onboarding) and §5, full spec in `docs/design/cook-verb.md`. **Still open inside it:** what verb-execution skill should *reward* beyond yield and grade — §5's plate-value formula has no slot for it. Deferred deliberately; revisit only when a specific module needs it.

### #2 Menu variety / nigiri depth
Single-fish nigiri is the only dish; attribute-mixing cut; dry-aging opt-in and slot-limited. **Is species-as-variety enough to hold an 18+ audience over weeks?** Relief valves on the shelf: scored-attribute mixing (post-launch), farming line (post-launch). Pulling either forward is a real scope decision — interrogate before committing to nigiri-only at launch.

**Partially relieved by the #1 resolution (2026-07-29):** grades (otoro / chutoro / akami) add a per-portion quality axis on top of species, so a single species now spans three price points and the player's hands decide which. This is real depth that did not exist when the thread opened. It is *not* a full answer — grade is execution variance, not menu variety — but it lowers the pressure to pull a relief valve forward. Re-judge at the M6 slice gate.

### #3 First-pass economy model
Build the 5-row faucets-minus-sinks table — rows: tutorial boat, new restaurant, mid, late, whale; columns: avg plate value, plates/hr, headcount, wages/hr, spoilage/hr, net income/hr, time to next tier. **Single output to read:** does net income/hr grow faster than next-tier cost? **Dial to find:** where the throughput cliff lands (healthy ≈ week 6). Tune with spoilage rate + next-tier pricing; wages are weak. Run as a dedicated numbers session.

**Partially resolved 2026-09-04 (quick-pass numbers session, jointly with #5):** the storage-capacity `tierUpgradeCost` ladder is set (`docs/design/economy-model-skeleton.md` Row 4). The full progression-stage validation table (does net income/hr beat next-tier cost, where the throughput cliff lands) is still open — deferred to a follow-up session once M8 has a Studio pass and real plates/hour data exists.

### #4 Legendary fight phase structure
Locked as "scaled-up multi-phase reel," unspecified: phase count, per-level-band window sizes, stamina curves, dive-phase mechanics. Needs base reel numbers first (#1 → Phase 2 / M3).

### #5 Spoilage ↔ offline-coast values
Stance resolved (freshness-governed; storage raises capacity and slows spoilage). Unset: actual decay rates, storage tier ladder, coast lengths per tier. **Same dial as the 24–48h target — tune jointly with #3.**

**Partially resolved 2026-09-04:** raw-fish/cooked-portion decay thresholds (tier-0 baseline: 45min/90min raw, 20min/40min cooked) and a 4-tier storage ladder (capacity 10→80, spoilage slowdown 1×→8×) are set — tier 3 lands raw-fish spoilage at 12h, the top of this thread's "late game 12h+" target. `docs/design/economy-model-skeleton.md` Rows 3-4 have the full table. Per-species decay-rate variance is still unset (M6/M8 use one flat threshold per tier).

### #6 Smaller undefineds (close before launch)
- **Purchasing tiers:** boats, rods, equipment, storage, restaurant tiers — ladder, costs, unlocks
- **Yelp prestige formula:** how shifts accumulate toward 5 stars; what counts as a "bad shift"
- **Hidden traffic stat formula:** exact weighting of Yelp + cosmetics + Hospitality into spawn volume
- ~~**Omakase counter mechanics**~~ — resolved 2026-07-29 with #1: dropped as a separate product; replaced by the presence aura (quality + speed multiplier on staff `performance`). Still unset: the aura's **magnitude** and its anti-parking shape (session decay or per-shift cap) — M17
- **Walkout rules:** wait time, cash lost, tie-in to the (shelved) popularity layer's eventual hook
- **Storm catalog:** weather types → legendaries, durations, zone sizes, broadcast lead time

---

## 13. Questions for Giahy (answer before Phase 1 / M1)

1. ~~**Repo layout (§10)**~~ — answered 2026-07-05: (B) dedicated repo `shortgiahy/sushi-sea`.
2. **Cook verb (#1):** ready to run grill-me on it, or seed a direction first?
3. ~~**Art timing:**~~ answered 2026-09-04: gray-box through Phase 4 (M10-M12), Blender/artist modeling starts at Phase 5 (M13-M18) as originally planned — no early artist track.
4. **Publishing:** confirm Giahy handles the Creator Hub publish step and receives a buildable project + runbook.

---

## 14. First move

1. Get Giahy's answers to §13.
2. **Open on M0:** grill-me on the cook verb. Do not scaffold code until it's locked and the repo layout is picked.
3. Log the session in `Build Log.md` and push before the container dies.
