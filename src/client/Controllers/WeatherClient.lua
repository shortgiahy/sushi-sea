-- WeatherClient: storm alert display and legendary FOMO UI, driven entirely by server broadcasts
--
-- M13 gray-box implementation: a banner that appears on Weather_StormBroadcast naming the zone and
-- legendary type, counting down the storm's remaining duration, then hides itself — "an ink storm
-- is passing through Sector X" (PRD §4). No client-side computation of odds/timing beyond a local
-- countdown display; the server is the sole authority on whether/when a storm is active.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeatherClient = {}

local localPlayer = Players.LocalPlayer

local bannerLabel: TextLabel? = nil
local stormEndsAtClock: number? = nil

local function _buildGui(): ()
    local playerGui = localPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WeatherHud"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true

    local banner = Instance.new("TextLabel")
    banner.Name = "StormBanner"
    banner.AnchorPoint = Vector2.new(0.5, 0)
    banner.Position = UDim2.new(0.5, 0, 0, 8)
    banner.Size = UDim2.fromOffset(420, 26)
    banner.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
    banner.BackgroundTransparency = 0.2
    banner.BorderSizePixel = 0
    banner.TextColor3 = Color3.fromRGB(230, 200, 255)
    banner.Font = Enum.Font.SourceSansBold
    banner.TextSize = 16
    banner.Text = ""
    banner.Visible = false
    banner.Parent = screenGui

    screenGui.Parent = playerGui

    bannerLabel = banner
end

type StormBroadcast = { zone: string, duration: number, legendaryType: string, oddsMultiplier: number }

local function _onStormBroadcast(payload: StormBroadcast): ()
    if not bannerLabel then
        return
    end

    stormEndsAtClock = os.clock() + payload.duration
    bannerLabel.Text = ("A storm is passing through Sector %s — %s odds are way up!"):format(
        payload.zone,
        payload.legendaryType
    )
    bannerLabel.Visible = true
end

local function _onHeartbeat(): ()
    if not bannerLabel or not stormEndsAtClock then
        return
    end
    if os.clock() >= stormEndsAtClock then
        bannerLabel.Visible = false
        stormEndsAtClock = nil
    end
end

function WeatherClient.init(): ()
    local remoteEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RemoteEvents")
    local stormBroadcastRemote = remoteEvents:WaitForChild("Weather_StormBroadcast") :: RemoteEvent

    _buildGui()

    stormBroadcastRemote.OnClientEvent:Connect(_onStormBroadcast)
    game:GetService("RunService").Heartbeat:Connect(_onHeartbeat)
end

return WeatherClient
