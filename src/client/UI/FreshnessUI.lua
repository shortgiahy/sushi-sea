-- FreshnessUI: inventory freshness timers; mirrors SpoilageService state, never computes freshness locally
--
-- M6 gray-box implementation: a small always-visible panel listing raw inventory fish and cooked
-- portions with their server-pushed freshness state (Spoilage_InventoryUpdate), plus a running
-- gold total (Economy_GoldUpdate). Same one-ScreenGui-per-controller shape BoatCookController
-- already established; positioned top-left so it never overlaps that HUD (top-center). A spoiled
-- entry is never rendered here — SpoilageService.server.lua tosses it before snapshotting, so
-- "spoiled" never appears in an update payload; only "fresh"/"stale" need a color.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FreshnessUI = {}

local localPlayer = Players.LocalPlayer

local STATE_COLOR: { [string]: Color3 } = {
    fresh = Color3.fromRGB(90, 170, 90),
    stale = Color3.fromRGB(190, 160, 60),
}

local goldLabel: TextLabel? = nil
local inventoryContainer: Frame? = nil
local portionsContainer: Frame? = nil

local function _clearContainer(container: Frame): ()
    for _, child in container:GetChildren() do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end

local function _addRow(container: Frame, layoutOrder: number, text: string, color: Color3): ()
    local row = Instance.new("TextLabel")
    row.Name = "Row"
    row.LayoutOrder = layoutOrder
    row.Size = UDim2.new(1, 0, 0, 18)
    row.BackgroundTransparency = 1
    row.TextColor3 = color
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.Font = Enum.Font.SourceSans
    row.TextSize = 15
    row.Text = text
    row.Parent = container
end

local function _buildGui(): ()
    local playerGui = localPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FreshnessHud"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.Position = UDim2.fromOffset(16, 16)
    root.Size = UDim2.fromOffset(220, 260)
    root.BackgroundTransparency = 1
    root.Parent = screenGui

    local gold = Instance.new("TextLabel")
    gold.Name = "Gold"
    gold.Size = UDim2.new(1, 0, 0, 22)
    gold.BackgroundTransparency = 1
    gold.TextColor3 = Color3.fromRGB(240, 210, 100)
    gold.TextXAlignment = Enum.TextXAlignment.Left
    gold.Font = Enum.Font.SourceSansBold
    gold.TextSize = 18
    gold.Text = "Gold: 0"
    gold.Parent = root

    local invHeader = Instance.new("TextLabel")
    invHeader.Name = "InventoryHeader"
    invHeader.Position = UDim2.fromOffset(0, 26)
    invHeader.Size = UDim2.new(1, 0, 0, 16)
    invHeader.BackgroundTransparency = 1
    invHeader.TextColor3 = Color3.new(1, 1, 1)
    invHeader.TextXAlignment = Enum.TextXAlignment.Left
    invHeader.Font = Enum.Font.SourceSansBold
    invHeader.TextSize = 14
    invHeader.Text = "Catch"
    invHeader.Parent = root

    local invContainer = Instance.new("Frame")
    invContainer.Name = "InventoryList"
    invContainer.Position = UDim2.fromOffset(0, 44)
    invContainer.Size = UDim2.new(1, 0, 0, 100)
    invContainer.BackgroundTransparency = 1
    invContainer.Parent = root

    local invLayout = Instance.new("UIListLayout")
    invLayout.SortOrder = Enum.SortOrder.LayoutOrder
    invLayout.Parent = invContainer

    local portHeader = Instance.new("TextLabel")
    portHeader.Name = "PortionsHeader"
    portHeader.Position = UDim2.fromOffset(0, 150)
    portHeader.Size = UDim2.new(1, 0, 0, 16)
    portHeader.BackgroundTransparency = 1
    portHeader.TextColor3 = Color3.new(1, 1, 1)
    portHeader.TextXAlignment = Enum.TextXAlignment.Left
    portHeader.Font = Enum.Font.SourceSansBold
    portHeader.TextSize = 14
    portHeader.Text = "Cooked"
    portHeader.Parent = root

    local portContainer = Instance.new("Frame")
    portContainer.Name = "PortionsList"
    portContainer.Position = UDim2.fromOffset(0, 168)
    portContainer.Size = UDim2.new(1, 0, 0, 90)
    portContainer.BackgroundTransparency = 1
    portContainer.Parent = root

    local portLayout = Instance.new("UIListLayout")
    portLayout.SortOrder = Enum.SortOrder.LayoutOrder
    portLayout.Parent = portContainer

    screenGui.Parent = playerGui

    goldLabel = gold
    inventoryContainer = invContainer
    portionsContainer = portContainer
end

type InventorySnapshotEntry = { id: string, species: string, freshnessState: string, freshnessFraction: number }
type PortionSnapshotEntry = {
    id: string,
    species: string,
    grade: string,
    freshnessState: string,
    freshnessFraction: number,
}

local function _onInventoryUpdate(
    payload: { inventory: { InventorySnapshotEntry }, cookedPortions: { PortionSnapshotEntry } }
): ()
    if not inventoryContainer or not portionsContainer then
        return
    end

    _clearContainer(inventoryContainer)
    for i, fish in payload.inventory do
        local color = STATE_COLOR[fish.freshnessState] or Color3.new(1, 1, 1)
        _addRow(inventoryContainer, i, ("%s — %s"):format(fish.species, fish.freshnessState), color)
    end

    _clearContainer(portionsContainer)
    for i, portion in payload.cookedPortions do
        local color = STATE_COLOR[portion.freshnessState] or Color3.new(1, 1, 1)
        _addRow(
            portionsContainer,
            i,
            ("%s %s — %s"):format(portion.species, portion.grade, portion.freshnessState),
            color
        )
    end
end

local function _onGoldUpdate(gold: number): ()
    if goldLabel then
        goldLabel.Text = ("Gold: %d"):format(math.floor(gold))
    end
end

function FreshnessUI.init(): ()
    local remoteEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RemoteEvents")
    local inventoryUpdateRemote = remoteEvents:WaitForChild("Spoilage_InventoryUpdate") :: RemoteEvent
    local goldUpdateRemote = remoteEvents:WaitForChild("Economy_GoldUpdate") :: RemoteEvent

    _buildGui()

    inventoryUpdateRemote.OnClientEvent:Connect(_onInventoryUpdate)
    goldUpdateRemote.OnClientEvent:Connect(_onGoldUpdate)
end

return FreshnessUI
