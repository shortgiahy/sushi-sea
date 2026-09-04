-- RestaurantUI: customer display, prestige bar, Yelp app; read-only view over server-pushed restaurant state
--
-- M10/M11 gray-box implementation: restaurant tier + upgrade button, staff roster + hire buttons
-- (one per rarity), and a live customer stage list — all mirroring server-pushed state
-- (Restaurant_TierUpdate, Restaurant_StaffUpdate, Restaurant_CustomerUpdate), same "never compute
-- locally" contract FreshnessUI already established. Positioned top-right so it never overlaps
-- BoatCookController's HUD (top-center) or FreshnessUI's panel (top-left).
--
-- M12 addition: a star-rating line (TrafficStat.starsFor, server-resolved and pushed alongside the
-- customer snapshot) stands in for the full "Yelp app" — that's a bigger UI surface than this
-- gray-box panel needs yet; the number itself is the part M12's task table actually calls for.
--
-- M16 addition: a read-only trophy count (Restaurant_TrophyUpdate) — mounting itself happens via
-- Player_MountTrophy with no dedicated UI yet, same "mechanic complete, interaction UI later"
-- precedent M15's aging locker set.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RestaurantUI = {}

local localPlayer = Players.LocalPlayer

local RARITY_ORDER = { "common", "rare", "legendary" }

local tierLabel: TextLabel? = nil
local starsLabel: TextLabel? = nil
local upgradeTierButton: TextButton? = nil
local staffLabel: TextLabel? = nil
local hireButtons: { [string]: TextButton } = {}
local customerContainer: Frame? = nil
local trophyLabel: TextLabel? = nil

local purchaseRestaurantTierRemote: RemoteEvent? = nil
local hireStaffRemote: RemoteEvent? = nil

local restaurantTierState = { tier = 0, name = nil :: string?, seats = 0, nextTierCost = 2000 :: number? }
local staffCount = 0
local currentStars = 1
local trophyCount = 0

local function _clearContainer(container: Frame): ()
    for _, child in container:GetChildren() do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end

local function _addRow(container: Frame, layoutOrder: number, text: string): ()
    local row = Instance.new("TextLabel")
    row.Name = "Row"
    row.LayoutOrder = layoutOrder
    row.Size = UDim2.new(1, 0, 0, 18)
    row.BackgroundTransparency = 1
    row.TextColor3 = Color3.new(1, 1, 1)
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.Font = Enum.Font.SourceSans
    row.TextSize = 15
    row.Text = text
    row.Parent = container
end

local function _buildGui(): ()
    local playerGui = localPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RestaurantHud"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(1, 0)
    root.Position = UDim2.new(1, -16, 0, 16)
    root.Size = UDim2.fromOffset(240, 362)
    root.BackgroundTransparency = 1
    root.Parent = screenGui

    local tier = Instance.new("TextLabel")
    tier.Name = "Tier"
    tier.Size = UDim2.new(1, 0, 0, 18)
    tier.BackgroundTransparency = 1
    tier.TextColor3 = Color3.new(1, 1, 1)
    tier.TextXAlignment = Enum.TextXAlignment.Left
    tier.Font = Enum.Font.SourceSansBold
    tier.TextSize = 15
    tier.Text = ""
    tier.Parent = root

    local stars = Instance.new("TextLabel")
    stars.Name = "Stars"
    stars.Position = UDim2.fromOffset(0, 20)
    stars.Size = UDim2.new(1, 0, 0, 18)
    stars.BackgroundTransparency = 1
    stars.TextColor3 = Color3.fromRGB(240, 210, 100)
    stars.TextXAlignment = Enum.TextXAlignment.Left
    stars.Font = Enum.Font.SourceSans
    stars.TextSize = 15
    stars.Text = ""
    stars.Parent = root

    local upgradeTier = Instance.new("TextButton")
    upgradeTier.Name = "UpgradeTierButton"
    upgradeTier.Position = UDim2.fromOffset(0, 42)
    upgradeTier.Size = UDim2.fromOffset(220, 28)
    upgradeTier.BackgroundColor3 = Color3.fromRGB(80, 60, 100)
    upgradeTier.TextColor3 = Color3.new(1, 1, 1)
    upgradeTier.Font = Enum.Font.SourceSansBold
    upgradeTier.TextSize = 15
    upgradeTier.Text = ""
    upgradeTier.Parent = root

    local staff = Instance.new("TextLabel")
    staff.Name = "Staff"
    staff.Position = UDim2.fromOffset(0, 78)
    staff.Size = UDim2.new(1, 0, 0, 18)
    staff.BackgroundTransparency = 1
    staff.TextColor3 = Color3.new(1, 1, 1)
    staff.TextXAlignment = Enum.TextXAlignment.Left
    staff.Font = Enum.Font.SourceSansBold
    staff.TextSize = 15
    staff.Text = "Staff: 0"
    staff.Parent = root

    local hireButtonsTop = 98
    for i, rarity in RARITY_ORDER do
        local hireButton = Instance.new("TextButton")
        hireButton.Name = "Hire_" .. rarity
        hireButton.Position = UDim2.fromOffset(0, hireButtonsTop + (i - 1) * 30)
        hireButton.Size = UDim2.fromOffset(220, 26)
        hireButton.BackgroundColor3 = Color3.fromRGB(60, 90, 70)
        hireButton.TextColor3 = Color3.new(1, 1, 1)
        hireButton.Font = Enum.Font.SourceSans
        hireButton.TextSize = 14
        hireButton.Text = ""
        hireButton.Parent = root
        hireButton.Activated:Connect(function()
            if hireStaffRemote then
                hireStaffRemote:FireServer({ rarity = rarity })
            end
        end)
        hireButtons[rarity] = hireButton
    end

    local customersHeader = Instance.new("TextLabel")
    customersHeader.Name = "CustomersHeader"
    customersHeader.Position = UDim2.fromOffset(0, hireButtonsTop + #RARITY_ORDER * 30 + 6)
    customersHeader.Size = UDim2.new(1, 0, 0, 16)
    customersHeader.BackgroundTransparency = 1
    customersHeader.TextColor3 = Color3.new(1, 1, 1)
    customersHeader.TextXAlignment = Enum.TextXAlignment.Left
    customersHeader.Font = Enum.Font.SourceSansBold
    customersHeader.TextSize = 14
    customersHeader.Text = "Customers"
    customersHeader.Parent = root

    local customers = Instance.new("Frame")
    customers.Name = "CustomersList"
    customers.Position = UDim2.fromOffset(0, hireButtonsTop + #RARITY_ORDER * 30 + 24)
    customers.Size = UDim2.new(1, 0, 0, 120)
    customers.BackgroundTransparency = 1
    customers.Parent = root

    local customersLayout = Instance.new("UIListLayout")
    customersLayout.SortOrder = Enum.SortOrder.LayoutOrder
    customersLayout.Parent = customers

    local trophy = Instance.new("TextLabel")
    trophy.Name = "Trophies"
    trophy.Position = UDim2.fromOffset(0, hireButtonsTop + #RARITY_ORDER * 30 + 24 + 120 + 4)
    trophy.Size = UDim2.new(1, 0, 0, 18)
    trophy.BackgroundTransparency = 1
    trophy.TextColor3 = Color3.fromRGB(220, 200, 150)
    trophy.TextXAlignment = Enum.TextXAlignment.Left
    trophy.Font = Enum.Font.SourceSans
    trophy.TextSize = 15
    trophy.Text = "Trophies: 0"
    trophy.Parent = root

    screenGui.Parent = playerGui

    tierLabel = tier
    starsLabel = stars
    upgradeTierButton = upgradeTier
    staffLabel = staff
    customerContainer = customers
    trophyLabel = trophy
end

local function _refreshTierDisplay(): ()
    if tierLabel then
        if restaurantTierState.tier <= 0 then
            tierLabel.Text = "Restaurant: none (boat only)"
        else
            tierLabel.Text = ("Restaurant: %s (%d seats)"):format(
                restaurantTierState.name or "?",
                restaurantTierState.seats
            )
        end
    end
    if upgradeTierButton then
        if restaurantTierState.nextTierCost then
            upgradeTierButton.Text = ("Upgrade Restaurant (%dg)"):format(restaurantTierState.nextTierCost)
            upgradeTierButton.Visible = true
        else
            upgradeTierButton.Visible = false
        end
    end
end

local function _refreshStaffDisplay(): ()
    if staffLabel then
        staffLabel.Text = ("Staff: %d"):format(staffCount)
    end
    for rarity, button in hireButtons do
        button.Text = "Hire " .. rarity
    end
end

local function _refreshStarsDisplay(): ()
    if starsLabel then
        starsLabel.Text = ("Yelp: %.1f / 5.0"):format(currentStars)
    end
end

type RestaurantTierUpdate = { tier: number, name: string?, seats: number, nextTierCost: number? }
type StaffRosterEntry = { id: string, rarity: string, hiredAt: number }
type CustomerSnapshotEntry = { id: string, stage: string }
type CustomerUpdate = { customers: { CustomerSnapshotEntry }, prestigePoints: number, stars: number }

local function _onTierUpdate(payload: RestaurantTierUpdate): ()
    restaurantTierState = payload
    _refreshTierDisplay()
end

local function _onStaffUpdate(payload: { roster: { StaffRosterEntry } }): ()
    staffCount = #payload.roster
    _refreshStaffDisplay()
end

local function _onCustomerUpdate(payload: CustomerUpdate): ()
    currentStars = payload.stars
    _refreshStarsDisplay()

    if not customerContainer then
        return
    end
    _clearContainer(customerContainer)
    for i, customer in payload.customers do
        _addRow(customerContainer, i, ("Customer — %s"):format(customer.stage))
    end
end

local function _onTrophyUpdate(payload: { trophies: { any } }): ()
    trophyCount = #payload.trophies
    if trophyLabel then
        trophyLabel.Text = ("Trophies: %d"):format(trophyCount)
    end
end

local function _onUpgradeTierButtonPressed(): ()
    if purchaseRestaurantTierRemote then
        purchaseRestaurantTierRemote:FireServer()
    end
end

function RestaurantUI.init(): ()
    local remoteEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RemoteEvents")
    local tierUpdateRemote = remoteEvents:WaitForChild("Restaurant_TierUpdate") :: RemoteEvent
    local staffUpdateRemote = remoteEvents:WaitForChild("Restaurant_StaffUpdate") :: RemoteEvent
    local customerUpdateRemote = remoteEvents:WaitForChild("Restaurant_CustomerUpdate") :: RemoteEvent
    local trophyUpdateRemote = remoteEvents:WaitForChild("Restaurant_TrophyUpdate") :: RemoteEvent
    purchaseRestaurantTierRemote = remoteEvents:WaitForChild("Player_PurchaseRestaurantTier") :: RemoteEvent
    hireStaffRemote = remoteEvents:WaitForChild("Player_HireStaff") :: RemoteEvent

    _buildGui()
    _refreshTierDisplay()
    _refreshStaffDisplay()
    _refreshStarsDisplay()

    tierUpdateRemote.OnClientEvent:Connect(_onTierUpdate)
    staffUpdateRemote.OnClientEvent:Connect(_onStaffUpdate)
    customerUpdateRemote.OnClientEvent:Connect(_onCustomerUpdate)
    trophyUpdateRemote.OnClientEvent:Connect(_onTrophyUpdate)

    if upgradeTierButton then
        upgradeTierButton.Activated:Connect(_onUpgradeTierButtonPressed)
    end
end

return RestaurantUI
