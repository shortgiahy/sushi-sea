-- FreshnessUI: inventory freshness timers; mirrors SpoilageService state, never computes freshness locally
--
-- M6 gray-box implementation: a small always-visible panel listing raw inventory fish and cooked
-- portions with their server-pushed freshness state (Spoilage_InventoryUpdate), plus a running
-- gold total (Economy_GoldUpdate). Same one-ScreenGui-per-controller shape BoatCookController
-- already established; positioned top-left so it never overlaps that HUD (top-center). A spoiled
-- entry is never rendered here — SpoilageService.server.lua tosses it before snapshotting, so
-- "spoiled" never appears in an update payload; only "fresh"/"stale" need a color.
--
-- M8 addition: a storage-tier line + upgrade button (Storage_TierUpdate, Player_PurchaseStorageTier)
-- — this panel is already the inventory-side HUD, so the capacity/tier readout belongs here rather
-- than a separate storefront; ShopUI.lua's fuller "Purchasing skill storefront" is a bigger, later
-- system covering rods/boats/equipment, not just this one number.
--
-- M15 addition: a read-only "Aging Locker: n/slots" line (Aging_LockerUpdate) — place/pull/upgrade
-- actions are server-complete (Player_PlaceInAgingLocker/Player_PullFromLocker/
-- Player_PurchaseAgingLockerTier) but have no interactive UI yet; this panel's inventory rows are a
-- flat read-only list with no per-row action slots to attach a "place in locker" button to. Same
-- "mechanic ships, full interaction UI is a later pass" precedent M9's offline bank set.
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
local storageLabel: TextLabel? = nil
local upgradeButton: TextButton? = nil
local agingLockerLabel: TextLabel? = nil
local purchaseStorageTierRemote: RemoteEvent? = nil

local storageTierState = { tier = 0, name = "Boat cooler", capacity = 10, nextTierCost = 500 :: number? }
local lastInventoryCount = 0

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
    root.Size = UDim2.fromOffset(220, 356)
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

    local storage = Instance.new("TextLabel")
    storage.Name = "Storage"
    storage.Position = UDim2.fromOffset(0, 262)
    storage.Size = UDim2.new(1, 0, 0, 18)
    storage.BackgroundTransparency = 1
    storage.TextColor3 = Color3.new(1, 1, 1)
    storage.TextXAlignment = Enum.TextXAlignment.Left
    storage.Font = Enum.Font.SourceSans
    storage.TextSize = 15
    storage.Text = ""
    storage.Parent = root

    local upgrade = Instance.new("TextButton")
    upgrade.Name = "UpgradeStorageButton"
    upgrade.Position = UDim2.fromOffset(0, 284)
    upgrade.Size = UDim2.fromOffset(180, 30)
    upgrade.BackgroundColor3 = Color3.fromRGB(60, 80, 100)
    upgrade.TextColor3 = Color3.new(1, 1, 1)
    upgrade.Font = Enum.Font.SourceSansBold
    upgrade.TextSize = 16
    upgrade.Text = ""
    upgrade.Parent = root

    local aging = Instance.new("TextLabel")
    aging.Name = "AgingLocker"
    aging.Position = UDim2.fromOffset(0, 320)
    aging.Size = UDim2.new(1, 0, 0, 18)
    aging.BackgroundTransparency = 1
    aging.TextColor3 = Color3.fromRGB(200, 170, 230)
    aging.TextXAlignment = Enum.TextXAlignment.Left
    aging.Font = Enum.Font.SourceSans
    aging.TextSize = 15
    aging.Text = ""
    aging.Parent = root

    screenGui.Parent = playerGui

    goldLabel = gold
    inventoryContainer = invContainer
    portionsContainer = portContainer
    storageLabel = storage
    upgradeButton = upgrade
    agingLockerLabel = aging
end

type InventorySnapshotEntry = { id: string, species: string, freshnessState: string, freshnessFraction: number }
type PortionSnapshotEntry = {
    id: string,
    species: string,
    grade: string,
    freshnessState: string,
    freshnessFraction: number,
}

type StorageTierUpdate = { tier: number, name: string, capacity: number, nextTierCost: number? }

-- Mirrors server state only — capacity/count/cost all arrive via remotes, nothing here is computed
-- from local guesses (same "never compute locally" contract as freshness state).
local function _refreshStorageDisplay(): ()
    if storageLabel then
        storageLabel.Text = ("Storage: %s (%d/%d)"):format(
            storageTierState.name,
            lastInventoryCount,
            storageTierState.capacity
        )
    end
    if upgradeButton then
        if storageTierState.nextTierCost then
            upgradeButton.Text = ("Upgrade Storage (%dg)"):format(storageTierState.nextTierCost)
            upgradeButton.Visible = true
        else
            upgradeButton.Visible = false -- already at EconomyConfig.MAX_STORAGE_TIER
        end
    end
end

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

    lastInventoryCount = #payload.inventory
    _refreshStorageDisplay()
end

local function _onGoldUpdate(gold: number): ()
    if goldLabel then
        goldLabel.Text = ("Gold: %d"):format(math.floor(gold))
    end
end

local function _onStorageTierUpdate(payload: StorageTierUpdate): ()
    storageTierState = payload
    _refreshStorageDisplay()
end

type AgingLockerUpdate = { tier: number, slots: number, nextTierCost: number?, locker: { any } }

local function _onAgingLockerUpdate(payload: AgingLockerUpdate): ()
    if not agingLockerLabel then
        return
    end
    if payload.tier <= 0 then
        agingLockerLabel.Text = "Aging Locker: none"
    else
        agingLockerLabel.Text = ("Aging Locker: %d/%d"):format(#payload.locker, payload.slots)
    end
end

local function _onUpgradeButtonPressed(): ()
    if purchaseStorageTierRemote then
        purchaseStorageTierRemote:FireServer()
    end
end

function FreshnessUI.init(): ()
    local remoteEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RemoteEvents")
    local inventoryUpdateRemote = remoteEvents:WaitForChild("Spoilage_InventoryUpdate") :: RemoteEvent
    local goldUpdateRemote = remoteEvents:WaitForChild("Economy_GoldUpdate") :: RemoteEvent
    local storageTierUpdateRemote = remoteEvents:WaitForChild("Storage_TierUpdate") :: RemoteEvent
    local agingLockerUpdateRemote = remoteEvents:WaitForChild("Aging_LockerUpdate") :: RemoteEvent
    purchaseStorageTierRemote = remoteEvents:WaitForChild("Player_PurchaseStorageTier") :: RemoteEvent

    _buildGui()
    _refreshStorageDisplay()

    inventoryUpdateRemote.OnClientEvent:Connect(_onInventoryUpdate)
    goldUpdateRemote.OnClientEvent:Connect(_onGoldUpdate)
    storageTierUpdateRemote.OnClientEvent:Connect(_onStorageTierUpdate)
    agingLockerUpdateRemote.OnClientEvent:Connect(_onAgingLockerUpdate)

    if upgradeButton then
        upgradeButton.Activated:Connect(_onUpgradeButtonPressed)
    end
end

return FreshnessUI
