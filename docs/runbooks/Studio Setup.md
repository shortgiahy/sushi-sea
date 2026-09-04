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

**✅ Confirmed 2026-09-04 (via Studio MCP, read/playtest use only — see below):** Play-mode changes
do **not** persist. Pressing Play generated `Terrain`/`RestaurantPlots`/`IslandSpawn` correctly;
stopping Play reverted `Workspace` back to the untouched pre-Play state (confirmed by inspecting
Edit-mode `Workspace` immediately after stopping — the generated instances were gone, back to just
the stock `Baseplate`/default `SpawnLocation`). This is a Studio-only testing artifact, not
something a real published server does — each live server instance runs the script once at start
and keeps its own generated world for the life of that server, which is the actual intended
behavior and needs no extra step. It only matters for **Giahy's own Edit-mode work**: if you want
the island visibly present while editing (to place other things relative to it, take marketing
screenshots, etc.), Play/Stop won't leave it there. Run the generation once from the **command bar
in Edit mode** instead, then save the place — that bakes it into the actual `.rbxl` permanently.

**Also confirmed 2026-09-04:** the underlying `Terrain:FillCylinder` geometry is correct as
written (unrotated `CFrame.new(x, y, z)`, no `CFrame.Angles` rotation needed) — a round grass
plateau surrounded by a sand beach ring surrounded by ocean, roughly matching the intended shape,
verified via screenshots from a proper elevated angle. A low, near-level camera angle in an
earlier check made the beach/plateau discs look like a tall wall — that was a grazing-angle
perspective illusion (a thin, wide disc viewed nearly edge-on from a similar altitude
foreshortens dramatically), not a real shape bug; a `CFrame.Angles(90°, 0, 0)` rotation was tried
as a fix based on that misread and made it measurably worse (a genuinely narrow vertical shaft),
which is itself confirmation the original was right. `Plot_1`'s actual in-game position
(`90, 7.5, 0`) matches its intended math exactly. Distant water rendering in a terraced/stepped
pattern is Roblox's normal terrain LOD (level-of-detail) system simplifying far voxels for
performance, not a bug.

**How this was checked:** via the Roblox Studio MCP connection, strictly in its documented
read/playtest role (`get_studio_state`, `search_game_tree`, `inspect_instance`,
`start_stop_play`, `screen_capture`, `get_console_output`) — no code or assets were authored
through it. The one fix this produced (reverting an unnecessary rotation) was made by editing the
repo source and letting the already-running `rojo serve` sync it into Studio, same as every other
change this project makes.

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
