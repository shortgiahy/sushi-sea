-- WorldGenerationService: procedurally builds the island, surrounding ocean, restaurant plots,
-- and a spawn point once, the first time the server starts.
--
-- Not in PRD §7.1's file list — PRD §9 treats terrain as Studio-only, hand-authored content
-- ("Studio-only assets (terrain, lighting, physical placement) that Rojo can't round-trip get
-- documented in a Studio Setup.md runbook"), since Rojo genuinely cannot sync Terrain voxel data
-- from files. This service is a deliberate alternative to that default: a script that calls
-- Terrain's own runtime API (FillCylinder) is just ordinary Luau, so it IS fully versioned and
-- Rojo-syncable even though its *output* (the voxels) isn't — "the repo is the source of truth"
-- holds here the same way it does for every other system, instead of the island's shape living
-- only in a saved .rbxl file nobody can diff or reproduce. Same reasoning that put fishing's
-- bobber Part in FishingController.lua's own Instance.new calls rather than a pre-made model.
--
-- Idempotent: checks `workspace:GetAttribute("WorldGenerated")` before doing anything, so a Giahy
-- hand-edit + Studio save afterward survives the next server start instead of being silently
-- regenerated over. Delete that attribute (or the whole Terrain) to force a regeneration.
--
-- Checked once against real Terrain (2026-09-04, via Studio MCP in its documented read/playtest
-- role — no authoring was done through it, only inspection/screenshots/console). A low, near-level
-- camera angle made the beach/plateau discs read as a tall "wall" in one screenshot; a 90°
-- CFrame.Angles rotation was tried as a fix and made it worse (confirmed a genuinely narrow
-- vertical shaft), which means the original unrotated fills were correct all along and the "wall"
-- was a grazing-angle perspective illusion — a thin, wide disc viewed nearly edge-on from a
-- similar altitude foreshortens into what looks like a tall face. Reverted to unrotated CFrames.
-- Still unverified: the exact island silhouette/proportions from a proper elevated angle, and
-- every size in WorldConfig.lua (still first-pass guesses).
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Config.WorldConfig)

local Terrain = Workspace.Terrain

local function _generateTerrain(): ()
    -- Ocean first, wide enough to cover where the island will sit — the island fills below
    -- overwrite the water/seabed within their own smaller footprints.
    Terrain:FillCylinder(
        CFrame.new(0, WorldConfig.SEA_LEVEL_Y - WorldConfig.OCEAN_DEPTH_STUDS / 2, 0),
        WorldConfig.OCEAN_DEPTH_STUDS,
        WorldConfig.OCEAN_RADIUS_STUDS,
        Enum.Material.Water
    )

    -- Beach ring: a low shelf that just breaks the surface, sloping conceptually toward the water
    -- (a real slope would need noise-based terrain sculpting; a flat shelf is this pass's
    -- deliberate simplification — see WorldConfig.lua's header).
    Terrain:FillCylinder(
        CFrame.new(0, WorldConfig.SEA_LEVEL_Y - 2, 0),
        WorldConfig.BEACH_RING_HEIGHT_STUDS,
        WorldConfig.BEACH_RING_RADIUS_STUDS,
        Enum.Material.Sand
    )

    -- Plateau: the flat inner landmass plots sit on. Top surface = SEA_LEVEL_Y + 2 +
    -- PLATEAU_HEIGHT_STUDS / 2 = SEA_LEVEL_Y + 7 (see _plateauTopY below — kept as one function so
    -- the plot/spawn placement code can't drift out of sync with this fill).
    Terrain:FillCylinder(
        CFrame.new(0, WorldConfig.SEA_LEVEL_Y + 2, 0),
        WorldConfig.PLATEAU_HEIGHT_STUDS,
        WorldConfig.PLATEAU_RADIUS_STUDS,
        Enum.Material.Grass
    )
end

local function _plateauTopY(): number
    return WorldConfig.SEA_LEVEL_Y + 2 + WorldConfig.PLATEAU_HEIGHT_STUDS / 2
end

local function _createPlotLabel(plot: BasePart, plotNumber: number): ()
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlotLabel"
    billboard.Size = UDim2.fromOffset(120, 40)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = plot

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.3
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.Text = ("Plot %d"):format(plotNumber)
    label.Parent = billboard
end

-- Evenly spaced around a ring on the plateau — no per-player assignment yet (PlayerDataSchema has
-- no location field, `restaurant.tier` stays purely abstract); this is only the physical layout
-- to assign onto later.
local function _generatePlots(): ()
    local topY = _plateauTopY()
    local plotsFolder = Instance.new("Folder")
    plotsFolder.Name = "RestaurantPlots"
    plotsFolder.Parent = Workspace

    for i = 1, WorldConfig.PLOT_COUNT do
        local angle = (i - 1) / WorldConfig.PLOT_COUNT * 2 * math.pi
        local x = math.cos(angle) * WorldConfig.PLOT_RING_RADIUS_STUDS
        local z = math.sin(angle) * WorldConfig.PLOT_RING_RADIUS_STUDS

        local plot = Instance.new("Part")
        plot.Name = "Plot_" .. i
        plot.Anchored = true
        plot.Material = Enum.Material.SmoothPlastic
        plot.Color = Color3.fromRGB(180, 160, 130)
        plot.Size = WorldConfig.PLOT_SIZE_STUDS
        plot.Position = Vector3.new(x, topY + WorldConfig.PLOT_SIZE_STUDS.Y / 2, z)
        plot.Parent = plotsFolder

        _createPlotLabel(plot, i)
    end
end

local function _generateSpawn(): ()
    local topY = _plateauTopY()

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "IslandSpawn"
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Material = Enum.Material.SmoothPlastic
    spawn.Color = Color3.fromRGB(140, 180, 140)
    spawn.Size = Vector3.new(12, WorldConfig.SPAWN_HEIGHT_STUDS, 12)
    spawn.Position = Vector3.new(0, topY + WorldConfig.SPAWN_HEIGHT_STUDS / 2, 0)
    spawn.Duration = 0 -- no forced-spawn safe-zone timer, just a normal spawn point
    spawn.Parent = Workspace
end

local function _generateWorld(): ()
    _generateTerrain()
    _generatePlots()
    _generateSpawn()
    Workspace:SetAttribute("WorldGenerated", true)
end

if not Workspace:GetAttribute("WorldGenerated") then
    _generateWorld()
end
