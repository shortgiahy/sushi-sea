-- FishingController: cast/reel input handler; sends intent to the server and renders its validation response
--
-- M3 gray-box scope: Part-based bobber, code-built GUI meter, no art/animation/sound assets.
-- Reasoning for the client/server split lives in FishingConfig.lua and FishingCatch.lua's
-- doc comments; this file is "as much instant local feedback as possible, real authority stays
-- server-side" (PRD §7.7). Feel tuning is Giahy's next step (TASKS.md M3), not settled here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FishingConfig = require(ReplicatedStorage.Config.FishingConfig)

local FishingController = {}

local localPlayer = Players.LocalPlayer

type ControllerPhase = "idle" | "waiting_for_bite" | "hooked" | "fighting"

type ControllerState = {
    phase: ControllerPhase,
    activeFightId: string?,
    tension: number,
    progress: number,
    isHolding: boolean,
    lastSentAt: number,
    biteAt: number?,
}

local state: ControllerState = {
    phase = "idle",
    activeFightId = nil,
    tension = 0,
    progress = 0,
    isHolding = false,
    lastSentAt = 0,
    biteAt = nil,
}

local bobber: BasePart? = nil
local promptLabel: TextLabel? = nil
local catchBox: Frame? = nil
local fishSprite: Frame? = nil
local progressFill: Frame? = nil

local IN_BAND_COLOR = Color3.fromRGB(80, 200, 120)
local OUT_OF_BAND_COLOR = Color3.fromRGB(230, 200, 60)
local SNAP_RISK_COLOR = Color3.fromRGB(220, 70, 70)
local FISH_COLOR = Color3.fromRGB(230, 140, 40)

-- Duplicates FishingCatch.fishPositionAt exactly (server-authoritative version lives there).
-- FishingController can't require it directly — FishingCatch.lua lives in ServerStorage, which
-- doesn't replicate to clients — so this is a small, deliberate duplication rather than inventing
-- a new client/server module-sharing mechanism for one function. If the motion formula changes,
-- update both; there is no anti-spoof concern in them drifting slightly out of sync (worst case is
-- a briefly-misleading render, never an economy/inventory effect — the server's copy is what
-- actually resolves the catch).
local function _fishPositionAt(elapsedSeconds: number): number
    local raw = FishingConfig.FISH_CENTER
        + FishingConfig.FISH_MOTION_AMPLITUDE_1 * math.sin(elapsedSeconds * FishingConfig.FISH_MOTION_FREQUENCY_1)
        + FishingConfig.FISH_MOTION_AMPLITUDE_2
            * math.sin(elapsedSeconds * FishingConfig.FISH_MOTION_FREQUENCY_2 + FishingConfig.FISH_MOTION_PHASE_2)

    local halfWidth = FishingConfig.CATCH_BOX_WIDTH / 2
    return math.clamp(raw, halfWidth, 1 - halfWidth)
end

local function _buildGui(): ()
    local playerGui = localPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FishingHud"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(0.5, 1)
    root.Position = UDim2.new(0.5, 0, 1, -60)
    root.Size = UDim2.fromOffset(260, 90)
    root.BackgroundTransparency = 1
    root.Parent = screenGui

    local prompt = Instance.new("TextLabel")
    prompt.Name = "Prompt"
    prompt.Size = UDim2.new(1, 0, 0, 24)
    prompt.Position = UDim2.new(0, 0, 0, 0)
    prompt.BackgroundTransparency = 1
    prompt.TextColor3 = Color3.new(1, 1, 1)
    prompt.TextStrokeTransparency = 0.5
    prompt.Font = Enum.Font.SourceSansBold
    prompt.TextSize = 20
    prompt.Text = ""
    prompt.Visible = false
    prompt.Parent = root

    local tensionBack = Instance.new("Frame")
    tensionBack.Name = "TensionBar"
    tensionBack.Size = UDim2.new(1, 0, 0, 22)
    tensionBack.Position = UDim2.fromOffset(0, 30)
    tensionBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    tensionBack.BorderSizePixel = 0
    tensionBack.Visible = false
    tensionBack.Parent = root

    -- Catch box: fixed-width, player-moved (2026-08-06, Giahy Studio feedback — real Stardew
    -- Valley fishing: the PLAYER moves this box via hold/release, the FISH drifts on its own, goal
    -- is keep the fish inside the box). Position (its center) tracks state.tension every frame in
    -- _onHeartbeat; Size stays fixed at CATCH_BOX_WIDTH. Initial Position here is just a
    -- placeholder before the first fight ever begins.
    local box = Instance.new("Frame")
    box.Name = "CatchBox"
    box.BackgroundColor3 = OUT_OF_BAND_COLOR
    box.BorderSizePixel = 0
    box.AnchorPoint = Vector2.new(0.5, 0)
    box.Position = UDim2.fromScale(0, 0)
    box.Size = UDim2.fromScale(FishingConfig.CATCH_BOX_WIDTH, 1)
    box.Parent = tensionBack

    -- Fish sprite: a small marker that drifts on its own (_fishPositionAt), rendered above the
    -- catch box so it's always visible against it. Gray-box stand-in for real fish art (M18).
    local fish = Instance.new("Frame")
    fish.Name = "FishSprite"
    fish.BackgroundColor3 = FISH_COLOR
    fish.BorderSizePixel = 0
    fish.AnchorPoint = Vector2.new(0.5, 0)
    fish.Position = UDim2.fromScale(FishingConfig.FISH_CENTER, 0)
    fish.Size = UDim2.fromScale(0.05, 1)
    fish.ZIndex = 3
    fish.Parent = tensionBack

    local progressBack = Instance.new("Frame")
    progressBack.Name = "ProgressBar"
    progressBack.Size = UDim2.new(1, 0, 0, 12)
    progressBack.Position = UDim2.fromOffset(0, 60)
    progressBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    progressBack.BorderSizePixel = 0
    progressBack.Visible = false
    progressBack.Parent = root

    local pFill = Instance.new("Frame")
    pFill.Name = "Fill"
    pFill.BackgroundColor3 = Color3.fromRGB(80, 160, 230)
    pFill.BorderSizePixel = 0
    pFill.Size = UDim2.fromScale(0, 1)
    pFill.Parent = progressBack

    screenGui.Parent = playerGui

    promptLabel = prompt
    catchBox = box
    fishSprite = fish
    progressFill = pFill
end

local function _setPrompt(text: string): ()
    if not promptLabel then
        return
    end
    promptLabel.Text = text
    promptLabel.Visible = text ~= ""
end

local function _setMetersVisible(visible: boolean): ()
    local tensionBar = catchBox and (catchBox.Parent :: Frame?)
    local progressBar = progressFill and (progressFill.Parent :: Frame?)
    if tensionBar then
        tensionBar.Visible = visible
    end
    if progressBar then
        progressBar.Visible = visible
    end
    if not visible and progressFill then
        progressFill.Size = UDim2.fromScale(0, 1)
    end
end

local function _getOrCreateBobber(): BasePart
    if bobber and bobber.Parent then
        return bobber
    end
    local part = Instance.new("Part")
    part.Name = "FishingBobber"
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(0.6, 0.6, 0.6)
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(255, 60, 60)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.Parent = Workspace
    bobber = part
    return part
end

local function _destroyBobber(): ()
    if bobber then
        bobber:Destroy()
        bobber = nil
    end
end

-- Raycasts from the camera through the given screen position (mouse and touch both surface a
-- Vector3 Position on the InputObject, Z unused) to find a cast target. Falls back to a fixed
-- point along the camera's look vector when nothing is hit — this repo has no water geometry
-- authored yet (Studio-side terrain is out of scope here, PRD §9), and the loop must still be
-- testable in an empty gray-box place.
local function _resolveCastTarget(screenPosition: Vector3): Vector3?
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end

    local unitRay = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local character = localPlayer.Character
    if character then
        params.FilterDescendantsInstances = { character }
    end

    local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * FishingConfig.MAX_CAST_DISTANCE_STUDS, params)
    if result then
        return result.Position
    end

    return unitRay.Origin + unitRay.Direction * (FishingConfig.MAX_CAST_DISTANCE_STUDS * 0.5)
end

local function _beginCast(screenPosition: Vector3, castLineRemote: RemoteEvent): ()
    if state.phase ~= "idle" then
        return
    end

    local target = _resolveCastTarget(screenPosition)
    if not target then
        return
    end

    state.phase = "waiting_for_bite"
    _setPrompt("Waiting for a bite...")

    local bobberPart = _getOrCreateBobber()
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    bobberPart.Position = if root then (root :: BasePart).Position else target
    bobberPart.Color = Color3.fromRGB(255, 60, 60)

    local tween = TweenService:Create(
        bobberPart,
        TweenInfo.new(FishingConfig.CAST_FLIGHT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = target }
    )
    tween:Play()

    castLineRemote:FireServer({ location = target })
end

local function _onBiteWindow(fightId: string): ()
    if state.phase ~= "waiting_for_bite" then
        return
    end

    state.phase = "hooked"
    state.activeFightId = fightId
    state.tension = 0
    state.progress = 0
    state.biteAt = os.clock()
    _setPrompt("Reel now!")
    _setMetersVisible(true)

    local bobberPart = _getOrCreateBobber()
    local flash = TweenService:Create(
        bobberPart,
        TweenInfo.new(0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 3, true),
        { Size = Vector3.new(1.0, 1.0, 1.0) }
    )
    flash:Play()
end

local function _resetToIdle(): ()
    state.phase = "idle"
    state.activeFightId = nil
    state.tension = 0
    state.progress = 0
    state.isHolding = false
    state.biteAt = nil
    _setMetersVisible(false)
    _destroyBobber()
end

local function _onFightResult(fightId: string, outcome: string, species: string?, quality: string?): ()
    if fightId ~= state.activeFightId then
        return
    end

    if outcome == "caught" then
        _setPrompt(("Caught a %s (%s)!"):format(tostring(species), tostring(quality)))
    elseif outcome == "snapped" then
        _setPrompt("The line snapped!")
    else
        _setPrompt("It got away...")
    end

    _resetToIdle()

    local resultMessage = promptLabel
    task.delay(FishingConfig.RESULT_MESSAGE_DISPLAY_SECONDS, function()
        if resultMessage and state.phase == "idle" then
            _setPrompt("")
        end
    end)
end

local function _onHeartbeat(dt: number, reelInputRemote: RemoteEvent): ()
    if state.phase == "hooked" then
        state.phase = "fighting"
    end
    if state.phase ~= "fighting" then
        return
    end

    -- Player-controlled catch box: hold moves it right, release drifts it left. Unchanged from
    -- before — only its *rendering* changes (a moving fixed-width box instead of a growing fill).
    if state.isHolding then
        state.tension = math.clamp(state.tension + FishingConfig.TENSION_RISE_RATE_PER_SECOND * dt, 0, 1)
    else
        state.tension = math.clamp(state.tension - FishingConfig.TENSION_FALL_RATE_PER_SECOND * dt, 0, 1)
    end

    local now = os.clock()
    local fishPosition = _fishPositionAt(if state.biteAt then now - state.biteAt else 0)
    local halfWidth = FishingConfig.CATCH_BOX_WIDTH / 2
    local inBand = fishPosition >= state.tension - halfWidth and fishPosition <= state.tension + halfWidth

    if fishSprite then
        fishSprite.Position = UDim2.fromScale(fishPosition, 0)
    end

    -- Instant local render — the whole point of PRD §7.7's "feels instant": this does not wait
    -- for a server round trip. The server independently computes the authoritative outcome from
    -- the same tension stream (and its own copy of the fish's motion) and has the final say via
    -- Fishing_FightResult.
    if catchBox then
        catchBox.Position = UDim2.fromScale(state.tension, 0)
        if state.tension >= FishingConfig.TENSION_SNAP_THRESHOLD then
            catchBox.BackgroundColor3 = SNAP_RISK_COLOR
        elseif inBand then
            catchBox.BackgroundColor3 = IN_BAND_COLOR
        else
            catchBox.BackgroundColor3 = OUT_OF_BAND_COLOR
        end
    end

    -- Local progress render, mirroring FishingCatch.applyReelInput's gain/decay exactly (same
    -- constants, same shape) so the bar tracks what the server is about to confirm. This bar
    -- existed since M3 but was never actually wired to a value — Giahy caught it in the
    -- 2026-08-06 Studio playtest ("there's a second bar... it doesn't work").
    if inBand then
        state.progress = math.clamp(state.progress + dt * FishingConfig.PROGRESS_GAIN_PER_SECOND_IN_BAND, 0, 1)
    else
        state.progress = math.clamp(state.progress - dt * FishingConfig.PROGRESS_DECAY_PER_SECOND_OUT_OF_BAND, 0, 1)
    end
    if progressFill then
        progressFill.Size = UDim2.fromScale(state.progress, 1)
    end

    if now - state.lastSentAt >= FishingConfig.MIN_REEL_INPUT_INTERVAL_SECONDS then
        state.lastSentAt = now
        reelInputRemote:FireServer({ tension = state.tension })
    end
end

local function _isPrimaryActionInput(input: InputObject): boolean
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
        or input.KeyCode == Enum.KeyCode.Space
end

function FishingController.init(): ()
    local remoteEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RemoteEvents")
    local castLineRemote = remoteEvents:WaitForChild("Player_CastLine") :: RemoteEvent
    local reelInputRemote = remoteEvents:WaitForChild("Player_ReelInput") :: RemoteEvent
    local biteWindowRemote = remoteEvents:WaitForChild("Fishing_BiteWindow") :: RemoteEvent
    local fightResultRemote = remoteEvents:WaitForChild("Fishing_FightResult") :: RemoteEvent

    _buildGui()

    biteWindowRemote.OnClientEvent:Connect(_onBiteWindow)
    fightResultRemote.OnClientEvent:Connect(_onFightResult)

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then
            return
        end
        if not _isPrimaryActionInput(input) then
            return
        end

        if state.phase == "idle" then
            _beginCast(input.Position, castLineRemote)
        elseif state.phase == "hooked" or state.phase == "fighting" then
            state.isHolding = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
        if _isPrimaryActionInput(input) then
            state.isHolding = false
        end
    end)

    RunService.Heartbeat:Connect(function(dt: number)
        _onHeartbeat(dt, reelInputRemote)
    end)
end

return FishingController
