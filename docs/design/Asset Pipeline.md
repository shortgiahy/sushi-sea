# Asset Pipeline

PRD §9 ("Blender — specify and script, don't sculpt"): this repo's role is the manifest, the
export contract, and `bpy` tooling — not interactive modeling. Modeling and importing are Giahy
(or a hired artist's) actions. This document is that manifest.

**Timing** (PRD §13, answered 2026-09-04): gray-box through Phase 4, real modeling starts at
Phase 5 (M13–M18). All of Phase 5's mechanics (M13–M17) are code-complete as of this doc; M18 is
this manifest plus the `scripts/blender/` tooling below — no modeling happens in this repo.

## Export contract (PRD §7.9 / §9, locked)

| Rule | Value |
|---|---|
| Format | `.fbx` (animated/rigged), `.obj` (static props) |
| Triangle budget | ≤10,000 tris per `MeshPart` |
| Texture maps | ≤4 per material (albedo, normal, metalness/roughness, emissive) |
| Pivot | At model origin — a fish's pivot is its own center, not world origin, but local origin must sit at a sensible grab point (nose-to-tail midpoint for fish, floor-center for props) |
| Scale | Real-world stud scale: 1 Roblox stud ≈ 0.28m. Author in meters in Blender, the FBX importer's stud conversion handles the rest — do not hand-scale to studs before export |
| Transforms | Applied (Object > Apply > All Transforms) before export — an un-applied rotation/scale imports incorrectly |

## Naming convention

`{Category}_{AssetName}_{Variant?}` — PascalCase, matching this repo's existing Luau `PascalCase`
module-name convention (PRD §8) so an asset name and the code that references it read the same way.

Examples: `Fish_Tuna`, `Fish_Kraken`, `Prop_CookingBoard`, `Prop_Boat_Starter`, `NPC_Customer_Generic`,
`NPC_Staff_Common`, `Equip_StorageLocker_Tier1`.

## Content manifest

Every entry below is a real gray-box gap identified in this codebase — not a speculative wishlist.
Poly budgets are a starting allocation (first-pass, like every other number in this repo), not a
hard design lock; adjust per-asset if a specific model's silhouette needs more/less.

### Fish (`src/shared/Modules/FishSpecies.lua`, `FishTable.lua`)

| Asset | Species id | Poly budget | Notes |
|---|---|---|---|
| `Fish_Mackerel` | `mackerel` | 1,500 | Common, quick-tier — simplest fish in the roster |
| `Fish_SeaBream` | `sea_bream` | 1,500 | Common, quick-tier |
| `Fish_Yellowtail` | `yellowtail` | 3,000 | Uncommon, full-tier — needs visible loin segmentation for the cook verb (see below) |
| `Fish_Tuna` | `tuna` | 4,000 | Rare, full-tier, 4 loins |
| `Fish_Opah` | `opah` | 3,500 | Rare, full-tier, 3 loins |
| `Fish_Kraken` | `kraken` | 10,000 (full budget) | Legendary — the one creature worth spending the whole tris budget on; also needed for M14's multi-phase reel and M16's trophy mount |

**Blocked mechanic these unblock:** the cook verb's real slicing interaction (drag along the cut
seam, angle/straightness/speed-consistency per `docs/design/cook-verb.md` §2) has been gray-boxed
since M4 specifically because no fish/board geometry exists (`BUILD_LOG.md` 2026-08-06). At minimum
`Fish_Tuna` or `Fish_Yellowtail` (a full-tier species with visible loins) plus `Prop_CookingBoard`
need to exist before that mechanic can be built for real — this is the highest-priority pair in
this manifest.

### Props

| Asset | Poly budget | Notes |
|---|---|---|
| `Prop_CookingBoard` | 2,000 | Camera-locked board for the M0-locked cook verb; needs a visible cut-seam guide geometry/UV for the trace stage |
| `Prop_Boat_Starter` | 8,000 | "The dinky sailboat is the first restaurant" (PRD §4) — fish at the stern, cook midship, sell at the bow, whole loop in one camera frame |
| `Prop_FishingRod_Starter` | 800 | First-tier rod; Purchasing's rod category (Thread #6) will want a small tier ladder eventually, this is the one that exists today |

### Restaurant tiers (`RestaurantConfig.RESTAURANT_TIERS`)

| Asset | Tier | Poly budget | Notes |
|---|---|---|---|
| `Room_SmallDiningRoom` | 1 (4 seats) | 6,000 | |
| `Room_FullRestaurant` | 2 (8 seats) | 9,000 | |
| `Room_FlagshipHouse` | 3 (16 seats) | 10,000 | |

### Storage tiers (`EconomyConfig.STORAGE_TIERS`)

| Asset | Tier | Poly budget |
|---|---|---|
| `Equip_BoatCooler` | 0 (starter) | 500 |
| `Equip_Icebox` | 1 | 800 |
| `Equip_ChillerUnit` | 2 | 1,200 |
| `Equip_ColdStorageRoom` | 3 | 2,000 |

### Aging locker (`AgingConfig.LOCKER_TIERS`)

| Asset | Tier | Poly budget |
|---|---|---|
| `Equip_AgingLocker_Tier1` (2 slots) | 1 | 1,000 |
| `Equip_AgingLocker_Tier2` (4 slots) | 2 | 1,500 |
| `Equip_AgingLocker_Tier3` (8 slots) | 3 | 2,000 |

### Characters

| Asset | Poly budget | Notes |
|---|---|---|
| `NPC_Customer_Generic` | 4,000 | `CustomerService` currently has no visual representation at all (state machine only) — this is what an arrived customer would actually be |
| `NPC_Staff_Common` / `NPC_Staff_Rare` / `NPC_Staff_Legendary` | 4,000 each | One silhouette per `RestaurantConfig.STAFF_RARITY` tier, visually communicating rarity without needing a name tag |

### Explicitly out of scope for `bpy`/Blender

- **UI icons and 2D art** — PRD names Figma as the UI design tool, not Blender. Fish/grade/staff
  icons for `FreshnessUI`/`RestaurantUI` are a Figma + Studio `ImageLabel` pipeline, not modeled.
- **Weather VFX** (storm visuals for M13) — particle/lighting effects are typically authored
  directly in Studio (`ParticleEmitter`, `Beam`, lighting), not modeled in Blender.
- **Terrain/world geometry** — no `Workspace` mapping exists in `default.project.json` (everything
  Rojo can't round-trip is Studio-only, PRD §9) — building the harbor/ocean is a Studio terrain
  pass, tracked in a `Studio Setup.md` runbook (does not exist yet — flagged separately, not this
  doc's job).

## `bpy` scripts (`scripts/blender/`)

Run via Blender's built-in Python (`Scripting` tab, or headless: `blender --background --python
script.py -- <args>`). None of these have been run against real Blender — no assets exist yet to
run them against — so treat them as a starting point to smoke-test against the first real model,
not as verified tooling.

- `validate_asset.py` — checks a selected object against the export contract above (triangle
  count, material/texture count, pivot at local origin, all transforms applied) and prints a
  pass/fail report. Run before every export.
- `export_fbx_batch.py` — exports every top-level object in the current `.blend` to its own `.fbx`
  in a target directory, named from the object's own name (so naming-convention compliance in
  Blender's outliner directly becomes the exported filename).
- `procedural_fish_scale.py` — scales a base fish mesh to each species' relative size from a table
  mirroring `FishSpecies.lua`'s roster, so one authored fish model can stand in for multiple
  species' silhouettes during an early art pass, before each gets its own unique model.
