-- BoatCookController: manual cook verb on the boat (PRD §7.6 driver)
--
-- M4 gray-box implementation of the M0 lock (docs/design/cook-verb.md): a two-stage verb (trace
-- -> yield, one stroke per loin -> grade) for full-tier species, trace-only for quick-tier. The
-- design doc's real drag-path/angle/speed-consistency capture (§2) needs a camera-locked 3D board
-- and gray-box Part geometry that doesn't exist in this sandbox yet (that's the Studio-side art/
-- interaction pass, M18-adjacent) — this controller instead reuses one timing-precision "stop the
-- marker in the zone" minigame for both stages, feeding the same [0, 1] accuracy inputs
-- ConversionModule.cook's `performance` contract expects on the server. One commit per stage, no
-- retry, matching the design doc's "committed on release" rule.
--
-- Gray-box single-slot simplification: this controller tracks at most one "held" (caught,
-- uncooked) fish at a time, taken directly from Fishing_FightResult, rather than a full inventory
-- browser. A real inventory UI is FreshnessUI's job (PRD §7.1, M6 "slice UI") — every other caught
-- fish still lands safely in PlayerDataService inventory server-side (EconomyService.server.lua),
-- it just isn't reachable from this controller until M6 exists. See BUILD_LOG.md M4 entry.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CookConfig = require(ReplicatedStorage.Config.CookConfig)
local FishSpecies = require(ReplicatedStorage.Modules.FishSpecies)

local BoatCookController = {}

local localPlayer = Players.LocalPlayer

type ControllerPhase = "idle" | "tracing" | "stroking" | "resolving"

type HeldFish = { fishId: string, speciesId: string }

type State = {
    phase: ControllerPhase,
    heldFish: HeldFish?,
    loinIndex: number,
    traceAccuracy: number?,
    markerT: number,
    markerDirection: number,
}

local state: State = {
    phase = "idle",
    heldFish = nil,
    loinIndex = 0,
    traceAccuracy = nil,
    markerT = 0,
    markerDirection = 1,
}

local promptLabel: TextLabel? = nil
local cookButton: TextButton? = nil
local barBack: Frame? = nil
local marker: Frame? = nil
local resultLabel: TextLabel? = nil

local activeMinigamePeriod = CookConfig.FULL_TRACE_PERIOD_SECONDS
local onCommitCallback: ((quality: number) -> ())? = nil

local cookTraceRemote: RemoteEvent
local cookStrokeRemote: RemoteEvent

-- Forward-declared: _onTraceCommitted/_beginStroke/_onStrokeCommitted call each other across the
-- trace -> stroke(s) -> resolve chain, so each needs to exist as an upvalue before the others'
-- bodies (which close over it) are defined.
local _beginTrace
local _beginStroke
local _onTraceCommitted
local _onStrokeCommitted
local _resetToIdle

local function _buildGui(): ()
    local playerGui = localPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CookHud"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(0.5, 0)
    root.Position = UDim2.new(0.5, 0, 0, 60)
    root.Size = UDim2.fromOffset(280, 120)
    root.BackgroundTransparency = 1
    root.Parent = screenGui

    local prompt = Instance.new("TextLabel")
    prompt.Name = "Prompt"
    prompt.Size = UDim2.new(1, 0, 0, 24)
    prompt.BackgroundTransparency = 1
    prompt.TextColor3 = Color3.new(1, 1, 1)
    prompt.TextStrokeTransparency = 0.5
    prompt.Font = Enum.Font.SourceSansBold
    prompt.TextSize = 20
    prompt.Text = ""
    prompt.Visible = false
    prompt.Parent = root

    local button = Instance.new("TextButton")
    button.Name = "CookButton"
    button.Size = UDim2.fromOffset(140, 32)
    button.Position = UDim2.fromOffset(0, 28)
    button.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 18
    button.Text = "Cook (E)"
    button.Visible = false
    button.Parent = root

    local back = Instance.new("Frame")
    back.Name = "MarkerBar"
    back.Size = UDim2.new(1, 0, 0, 22)
    back.Position = UDim2.fromOffset(0, 68)
    back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    back.BorderSizePixel = 0
    back.Visible = false
    back.Parent = root

    -- Visual reference only — the whole bar is the input surface. resolveAccuracy scores the
    -- marker's distance from dead-center, not intersection with this strip.
    local centerZone = Instance.new("Frame")
    centerZone.Name = "CenterZone"
    centerZone.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
    centerZone.BorderSizePixel = 0
    centerZone.AnchorPoint = Vector2.new(0.5, 0)
    centerZone.Position = UDim2.fromScale(0.5, 0)
    centerZone.Size = UDim2.fromScale(0.14, 1)
    centerZone.Parent = back

    local markerFrame = Instance.new("Frame")
    markerFrame.Name = "Marker"
    markerFrame.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
    markerFrame.BorderSizePixel = 0
    markerFrame.AnchorPoint = Vector2.new(0.5, 0)
    markerFrame.Position = UDim2.fromScale(0, 0)
    markerFrame.Size = UDim2.fromScale(0.02, 1)
    markerFrame.ZIndex = 2
    markerFrame.Parent = back

    local result = Instance.new("TextLabel")
    result.Name = "Result"
    result.Size = UDim2.new(1, 0, 0, 20)
    result.Position = UDim2.fromOffset(0, 96)
    result.BackgroundTransparency = 1
    result.TextColor3 = Color3.fromRGB(220, 220, 255)
    result.Font = Enum.Font.SourceSans
    result.TextSize = 16
    result.TextWrapped = true
    result.Text = ""
    result.Visible = false
    result.Parent = root

    screenGui.Parent = playerGui

    promptLabel = prompt
    cookButton = button
    barBack = back
    marker = markerFrame
    resultLabel = result
end

local function _setPrompt(text: string): ()
    if promptLabel then
        promptLabel.Text = text
        promptLabel.Visible = text ~= ""
    end
end

local function _setBarVisible(visible: boolean): ()
    if barBack then
        barBack.Visible = visible
    end
end

-- Distance-from-center scoring: 1.0 dead-center, 0.0 at either edge of the bar. The one piece of
-- "skill math" this controller owns; everything downstream (yield/grade) is ConversionModule's,
-- which is what tests/ConversionModule.spec.luau actually covers headlessly.
local function _qualityFromMarkerT(t: number): number
    return 1 - math.clamp(math.abs(t - 0.5) / 0.5, 0, 1)
end

local function _startMarkerMinigame(periodSeconds: number, onCommit: (quality: number) -> ()): ()
    state.markerT = 0
    state.markerDirection = 1
    activeMinigamePeriod = periodSeconds
    onCommitCallback = onCommit
    _setBarVisible(true)
end

local function _commitMinigame(): ()
    if not onCommitCallback then
        return
    end
    local quality = _qualityFromMarkerT(state.markerT)
    local callback = onCommitCallback
    onCommitCallback = nil
    _setBarVisible(false)
    callback(quality)
end

_beginTrace = function(): ()
    local heldFish = state.heldFish
    if not heldFish then
        return
    end

    state.phase = "tracing"
    local species = FishSpecies.getById(heldFish.speciesId)
    local period = if species and species.prepTier == "quick"
        then CookConfig.QUICK_TRACE_PERIOD_SECONDS
        else CookConfig.FULL_TRACE_PERIOD_SECONDS

    if cookButton then
        cookButton.Text = "Commit (E)"
    end
    _setPrompt("Trace the cut — press E to commit")
    _startMarkerMinigame(period, _onTraceCommitted)
end

_onTraceCommitted = function(quality: number): ()
    local heldFish = state.heldFish
    if not heldFish then
        return
    end

    state.traceAccuracy = quality
    cookTraceRemote:FireServer({ fishId = heldFish.fishId, traceAccuracy = quality })

    local species = FishSpecies.getById(heldFish.speciesId)
    if species and species.prepTier == "full" and species.loinCount > 0 then
        state.loinIndex = 1
        _beginStroke()
    else
        state.phase = "resolving"
        _setPrompt("Cooking...")
        if cookButton then
            cookButton.Visible = false
        end
    end
end

_beginStroke = function(): ()
    local heldFish = state.heldFish
    if not heldFish then
        return
    end

    state.phase = "stroking"
    if cookButton then
        cookButton.Text = ("Commit loin %d (E)"):format(state.loinIndex)
    end
    _setPrompt(("Slice loin %d — press E to commit"):format(state.loinIndex))
    _startMarkerMinigame(CookConfig.STROKE_PERIOD_SECONDS, _onStrokeCommitted)
end

_onStrokeCommitted = function(quality: number): ()
    local heldFish = state.heldFish
    local species = heldFish and FishSpecies.getById(heldFish.speciesId)
    if not heldFish or not species then
        return
    end

    cookStrokeRemote:FireServer({ fishId = heldFish.fishId, loinIndex = state.loinIndex, strokeQuality = quality })

    if state.loinIndex >= species.loinCount then
        state.phase = "resolving"
        _setPrompt("Cooking...")
        if cookButton then
            cookButton.Visible = false
        end
    else
        state.loinIndex += 1
        _beginStroke()
    end
end

_resetToIdle = function(): ()
    state.phase = "idle"
    state.heldFish = nil
    state.loinIndex = 0
    state.traceAccuracy = nil
    onCommitCallback = nil
    _setBarVisible(false)
    _setPrompt("")
    if cookButton then
        cookButton.Visible = false
    end
end

local function _onCookButtonPressed(): ()
    if state.phase == "idle" and state.heldFish then
        _beginTrace()
    elseif state.phase == "tracing" or state.phase == "stroking" then
        _commitMinigame()
    end
end

local function _onFightResultForCook(
    _fightId: string,
    outcome: string,
    speciesId: string?,
    _quality: string?,
    fishId: string?
): ()
    if outcome ~= "caught" or not fishId or not speciesId then
        return
    end
    if state.heldFish ~= nil then
        return -- gray-box single-slot: this catch still lands in server inventory either way
    end

    state.heldFish = { fishId = fishId, speciesId = speciesId }
    _setPrompt("Fish ready to cook — press E")
    if cookButton then
        cookButton.Text = "Cook (E)"
        cookButton.Visible = true
    end
end

local function _onPortionsResolved(fishId: string, portions: { { grade: string } }): ()
    if not state.heldFish or state.heldFish.fishId ~= fishId then
        return
    end

    local counts: { [string]: number } = { otoro = 0, chutoro = 0, akami = 0 }
    for _, portion in portions do
        counts[portion.grade] = (counts[portion.grade] or 0) + 1
    end

    local summary = ("Cooked %d portions — %d otoro, %d chutoro, %d akami"):format(
        #portions,
        counts.otoro,
        counts.chutoro,
        counts.akami
    )

    if resultLabel then
        resultLabel.Text = summary
        resultLabel.Visible = true
        task.delay(CookConfig.RESULT_MESSAGE_DISPLAY_SECONDS, function()
            if resultLabel then
                resultLabel.Visible = false
            end
        end)
    end

    _resetToIdle()
end

local function _onHeartbeat(dt: number): ()
    if state.phase ~= "tracing" and state.phase ~= "stroking" then
        return
    end
    if activeMinigamePeriod <= 0 then
        return
    end

    state.markerT += (state.markerDirection * dt) / (activeMinigamePeriod / 2)
    if state.markerT >= 1 then
        state.markerT = 1
        state.markerDirection = -1
    elseif state.markerT <= 0 then
        state.markerT = 0
        state.markerDirection = 1
    end

    if marker then
        marker.Position = UDim2.fromScale(state.markerT, 0)
    end
end

function BoatCookController.init(): ()
    local remoteEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RemoteEvents")
    cookTraceRemote = remoteEvents:WaitForChild("Player_CookTrace") :: RemoteEvent
    cookStrokeRemote = remoteEvents:WaitForChild("Player_CookStroke") :: RemoteEvent
    local fightResultRemote = remoteEvents:WaitForChild("Fishing_FightResult") :: RemoteEvent
    local portionsResolvedRemote = remoteEvents:WaitForChild("Cooking_PortionsResolved") :: RemoteEvent

    _buildGui()

    fightResultRemote.OnClientEvent:Connect(_onFightResultForCook)
    portionsResolvedRemote.OnClientEvent:Connect(_onPortionsResolved)

    if cookButton then
        cookButton.Activated:Connect(_onCookButtonPressed)
    end

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then
            return
        end
        if input.KeyCode == Enum.KeyCode.E then
            _onCookButtonPressed()
        end
    end)

    RunService.Heartbeat:Connect(_onHeartbeat)
end

return BoatCookController
