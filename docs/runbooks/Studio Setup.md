# Studio Setup

PRD §9: "Studio-only assets (terrain, lighting, physical placement) that Rojo can't round-trip get
documented in a `Studio Setup.md` runbook." This is that runbook — it didn't exist before
2026-09-04; the island is the first thing that needed it.

## The island, ocean, and restaurant plots

**These are not Rojo-synced files.** Rojo cannot sync `Terrain` voxel data at all, and the plot
Parts/SpawnLocation are created by a script at runtime, not read from a mapped file — so none of
this geometry exists anywhere in `default.project.json`'s tree. What *is* versioned is the
generator: `src/server/ServerScriptService/Services/WorldGenerationService.server.lua` (+
`src/shared/Config/WorldConfig.lua` for the tunable sizes). The island's actual shape is
reproducible from that code, not stored anywhere else — the intent is that nothing about the world
lives only in a `.rbxl` file nobody can diff.

**How it runs:** the service checks `workspace:GetAttribute("WorldGenerated")` the moment the
server starts. If unset, it fills the ocean/beach/plateau Terrain cylinders, creates
`Workspace.RestaurantPlots` (one `Part` per plot, numbered `Plot_1`..`Plot_N`, each with a floating
label), creates `Workspace.IslandSpawn` (a `SpawnLocation`), then sets the attribute so it never
regenerates over itself again. Delete the attribute (or delete `Terrain`/`RestaurantPlots`/
`IslandSpawn` outright) to force a fresh regeneration.

**⚠️ Unverified nuance — check this before relying on the above:** it's not confirmed whether
Studio's Play/Run mode operates on the real `Workspace`/`Terrain` or a throwaway copy that gets
discarded when you stop. If terrain generated during Play **does not persist** after stopping,
the practical workflow is different: run `WorldGenerationService`'s generation logic once from the
**command bar in Edit mode** (not by pressing Play), then save the place — that bakes the terrain
into the actual saved file permanently, the same as if it had been hand-sculpted. If it **does**
persist through a Play/Stop cycle, the script running automatically on every server start is
sufficient and no manual step is needed. Confirm which is true the first time this runs and update
this note.

**Tuning:** every size in `WorldConfig.lua` (ocean/island radii, plot count and spacing, plot
size) is a first-pass placeholder, same status as every numeric guess elsewhere in this repo —
retune after actually looking at it in Studio.

**Known gap:** no plot is assigned to any player yet. `PlayerDataSchema` has no location field and
`restaurant.tier` stays purely abstract (a number, not a place) — `Workspace.RestaurantPlots` is
only the physical layout to assign onto later, not a working claim/ownership system.

## Everything else Rojo can't round-trip

Nothing else yet. As more Studio-only state accumulates (custom lighting, a real boat model once
M18 art lands, additional terrain features), document it here rather than letting it live only in
the saved place file.
