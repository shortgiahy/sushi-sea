# M0 Prep — Cook & Serve Verb Brief

**Status: draft for Giahy's grill-me session. Nothing in this document is locked.** This is an options-and-scoring brief prepared per PRD §12 Open Thread #1 and ROADMAP Phase 0. The cook verb (and its lower-stakes sibling, the serve verb) is decided by Giahy in a grill-me session, not by this document. Treat the recommendation below as a proposed starting answer to walk through, not a decision already made.

## Why this exists

Open Thread #1 (PRD §12) is the highest-priority open thread: *"What the player physically does when cooking on the boat is undefined."* It blocks:
- **M3/M4** — `BoatCookController` can't be built without a locked verb (ROADMAP Phase 2, Wave 2B).
- **M17 — Omakase counter** — the player-run counter that lifts the staff menu ceiling is explicitly coupled to this thread (PRD §12 Thread #6: "Omakase counter mechanics... Couples to #1").
- The whole vertical slice (M0→M6) — nothing playable exists until this locks.

Two framing constraints from Locked material that shape every option below:
1. **Retention thesis (PRD §1):** *"Game feel (the rod), not content volume, is the binding constraint on retention"* (council ruling, 2026-06-17). The cook verb is fired roughly as often as the fishing verb across a session — its feel matters on the same order.
2. **Pillar 3 — manual before automatic (PRD §2):** the boat verb is deliberately manual so the player *performs* cooking once before staff automate it (§7.6, `ConversionModule`). The verb needs to feel worth doing by hand, not like a chore blocking the "real" automated version.

**A locked-material note worth flagging for the grill-me session itself:** PRD §5's plate-value formula (`species_base × cooking_extraction × freshness_polish × dry_age_mutation`) is a fixed four-term formula, and `cooking_extraction` is driven by `cookingLevel / MAX_LEVEL` — a **stat**, not verb execution quality. That formula is Locked and out of scope for this brief to relitigate. Practically, this means **verb execution quality (how well the player times/aims/swipes) has no defined payoff hook today** — it isn't one of the four clamped multipliers. The options below are scored on feel/engagement/omakase-fit on the assumption that verb performance pays off through something outside the plate-value formula (throughput/pacing, a non-economy "chef performance" readout, cosmetic feedback, or an omakase-specific mechanic scoped separately at M17) — not through inventing a fifth economy multiplier. **This coupling question (what does skillful cooking actually reward, if not plate value?) is itself worth a beat in the grill-me session** — it isn't resolved here.

---

## Candidate verbs

### 1. Timing bar
A needle sweeps across a bar; tap when it's in a highlighted "sweet zone." The classic cooking-minigame convention (Cooking Mama, Overcooked chopping stations, countless mobile idle/cooking games).

### 2. Filleting / portioning minigame
Player drags a knife along an authored cut-path traced over the fish's silhouette — following a guided line to portion it correctly.

### 3. Slicing swipe
Player performs directional swipe gestures across the fish (Fruit Ninja-style) — direction, speed, and swipe count determine outcome.

### 4. Hold-button
Player holds a button and releases; charge level or release timing near a target determines outcome. Minimal input surface.

### 5. Rhythm / combo tap *(additional candidate)*
A short sequence of on-beat taps (QTE-style combo, no music-sync requirement) — each hit graded for timing accuracy, building a combo streak across the sequence.

---

## Scoring

Qualitative scale: **High / Med / Low**. For every column except *implementation cost*, High is better. For *implementation cost*, Low is better (cheaper).

| Option | Mobile feel | Skill expression | 100×/session tolerance | Omakase-ceiling extensibility | Implementation cost |
|---|---|---|---|---|---|
| **1. Timing bar** | High — single tap, large hit target, thumb-friendly | Med — precision timing reads as skillful without needing fine motor control | High — fast, low physical effort, an instantly legible convention that doesn't wear out | High — chain multiple bars per plate, narrow the window, speed up the sweep for the omakase tier | Low — one UI element, one input, one tolerance variable |
| **2. Filleting minigame** | Low — path-following drag is fiddly on small touchscreens, easy to mis-register | High — richest skill ceiling, most thematically literal ("you are cutting a fish") | Low-Med — precision-drag repeated ~100×/session risks becoming a chore, not a satisfaction loop | High — more complex cut paths, species-specific patterns, multi-cut sequences | High — path-follow detection, per-species authored cut-lines, most tuning-iteration risk (comparable to the M3 feel-tuning burden, but stacked on top of it) |
| **3. Slicing swipe** | Med-High — swipes are mobile-native and satisfying, but directional/velocity detection is fiddlier than a tap | Med — direction/speed/count express skill with juicy feedback | Med — more physically effortful than tapping; repeated swiping across long daily sessions risks thumb fatigue | Med-High — more slices, faster cadence, multi-directional combos | Med — gesture/velocity recognition, less than a full path-follow but more than tap-timing |
| **4. Hold-button** | High — minimal input, most accessible | Low — closest to no skill expression; risks feeling like idle-game filler | High physically (near-zero effort) but Low on engagement — boredom risk undercuts the "manual verb worth doing" premise (Pillar 3) | Low — already near its own ceiling; hard to meaningfully deepen into a "chef performance" | Lowest — trivial to build |
| **5. Rhythm/combo tap** | High — tap-only, thumb-friendly, proven mobile pattern | Med-High — timing accuracy across a sequence plus visible combo streaks | Med-High — quick and low-fatigue, though a strict multi-tap sequence run ~100×/session needs pacing care so it doesn't feel like busywork | High — naturally scales by adding taps/tempo for the omakase counter; combo/streak framing fits a "chef showing off at the counter" fantasy well | Med — needs a sequence generator + combo/streak tracking; more state than a single timing bar, less than gesture-path detection |

---

## Recommendation

**Timing bar**, for the cook verb.

Reasoning:
- It wins or ties on every column except peak skill ceiling (where filleting wins) and omakase extensibility (tied with rhythm/combo tap).
- It's the cheapest of the five to build well, which matters because M4 has to ship this reliably *alongside* the feel-critical fishing loop (M3) — Phase 2's exit gate already carries real tuning risk on the rod (ROADMAP risk register: "Rod never passes the feel gate"). The cook verb shouldn't add a second high-risk feel system to that same phase.
- It tolerates ~100×/session best: fast, thumb-friendly, low physical effort, and — unlike hold-button — still reads as a real action rather than idle filler, which matters given the retention thesis is explicitly about feel, not content volume.
- Omakase-ceiling extensibility is genuinely strong and cheap to realize: chaining multiple sequential bars per plate, narrowing the sweet zone, and speeding the sweep are all parameter changes on the same mechanic — no new input scheme needed when M17 (Omakase counter) arrives. This directly serves the "manual verb the player performs, that later becomes the counter-lifting skill display" arc implied by PRD §4's staff/omakase split.
- Filleting is the most thematically rich but carries real mobile-feel and tuning-cost risk for a verb fired this often; it's a stronger candidate for a *later* visual/art pass (Phase 5, once gray-box is replaced) than for the gray-box vertical slice, if Giahy wants to revisit it once art exists to make dragging a knife along a fish silhouette actually read well.
- Rhythm/combo tap (candidate 5) is the closest runner-up — nearly as cheap, and its "combo streak in front of the counter" framing arguably fits the omakase fantasy even better than a timing bar. It's worth keeping on the table for the grill-me session as the strongest alternative if Giahy wants a bit more built-in skill-ceiling texture than a timing bar offers, at a modest cost increase.

### Matching serve verb proposal

**Tap-to-serve (single-action deliver):** once a plate is cooked, the player carries it (walk animation, no extra input) to the serve point and taps to place it — a single confirm-style tap, no timing window, no failure state. This deliberately matches the lower-stakes framing from ROADMAP Phase 0 ("Same question applies to the boat serving verb (lower stakes, same session)") and PRD Pillar 1 (risk is opt-in, never forced — serving isn't a risk surface, freshness/spoilage already carries that load via `SpoilageService`). It also reuses the same tap-based input vocabulary as the timing-bar cook verb, so the boat loop stays cognitively simple: cast → reel → **tap-time** the cook → **tap** to serve.

---

## Open question to carry into the grill-me session

Beyond picking the verb itself: **what does skillful verb execution actually reward**, given §5's plate-value formula has no slot for it? Candidate answers to walk through with Giahy (not decided here): throughput/pacing (skilled play = more plates served per minute, an indirect economic lever via volume rather than a new multiplier), a non-economy "chef performance" display tied to prestige/Yelp flavor text, or scoping any execution payoff entirely to the M17 omakase counter rather than the base boat verb. This doesn't need to block the verb choice, but the verb choice should be made with an eye toward which of these answers it needs to support later.

---

## Exit condition

Per ROADMAP Phase 0: Giahy locks both verbs via grill-me → PRD §4 updated with the locked verbs → Open Thread #1 (§12) checked off → M3/M4 unblocked.
