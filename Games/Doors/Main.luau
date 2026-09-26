-- tokagod Main (рефактор: clean architecture + proper cleanup)

local tokagod = getgenv().tokagod
local Globals = {
    Connections = {},
    CharacterConnections = {},
    BodyObjects = {},
    Active = {},
    ESPConnections = {},
    ESPBlacklist = {},
    ObjectQueue = {}
}
local Library = tokagod.Interface.Library
local SaveManager = tokagod.Interface.SaveManager
local ThemeManager = tokagod.Interface.ThemeManager
local ESPLibrary = tokagod.ESPLibrary

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Toggles = Library.Toggles
local Options = Library.Options
local Functions = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentRooms = Workspace:FindFirstChild("CurrentRooms")
local Floor = ReplicatedStorage:WaitForChild("GameData"):WaitForChild("Floor").Value
local LiveModifiers = ReplicatedStorage:FindFirstChild("LiveModifiers")
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemotesFolder")
    or ReplicatedStorage:FindFirstChild("EntityInfo")
    or ReplicatedStorage:FindFirstChild("Bricks")

local Character, Humanoid, RootPart, Collision, CollisionPart

-- ============================================
-- UTILITY
-- ============================================

Functions.Notify = function(Settings)
    tokagod.Notify:Send({
        Title = Settings.Title or "tokagod",
        Body = Settings.Body or "...",
        Time = Settings.Time or 5
    })
end

Functions.ConnectSignal = function(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(Globals.Connections, conn)
    return conn
end

Functions.DisconnectAll = function()
    for _, conn in ipairs(Globals.Connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    Globals.Connections = {}
end

Functions.CleanupBodyObjects = function()
    for _, obj in ipairs(Globals.BodyObjects) do
        if obj and obj.Parent then
            obj:Destroy()
        end
    end
    Globals.BodyObjects = {}
end

Functions.ConnectCharacterSignal = function(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(Globals.CharacterConnections, conn)
    return conn
end

Functions.DisconnectCharacterConnections = function()
    for _, conn in ipairs(Globals.CharacterConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    Globals.CharacterConnections = {}
end

Functions.FireRemote = function(remoteName, ...)
    if RemotesFolder and RemotesFolder:FindFirstChild(remoteName) then
        local args = {...}
        pcall(function()
            RemotesFolder[remoteName]:FireServer(table.unpack(args))
        end)
    end
end

-- ============================================
-- WINDOW & TABS
-- ============================================

local Window = Library:CreateWindow({
    Title = "?",
    Footer = "dsc.gg/?????",
    NotifySide = "Right",
    ShowCustomCursor = false,
    AutoShow = true,
    Center = true,
    TabPadding = 3,
    MenuFadeTime = 0,
    CornerRadius = 6,
    ToggleKeybind = Enum.KeyCode.RightShift,
})

local Tabs = {
    General   = Window:AddTab("General", "house"),
    Exploits  = Window:AddTab("Exploits", "shield"),
    Visuals   = Window:AddTab("Visuals", "eye"),
    Floors    = Window:AddTab("Floors", "earth"),
    Archives  = Window:AddTab("Archives", "rbxassetid://104508835882225"),
    Stairwell = Window:AddTab("Stairwell", "rbxassetid://80017304328364"),
    Settings  = Window:AddTab("Settings", "settings"),
}

local Groupboxes = {}

Groupboxes.General_Character   = Tabs.General:AddLeftGroupbox("Character")
Groupboxes.General_Self        = Tabs.General:AddLeftGroupbox("Self")
Groupboxes.Self_Automation     = Tabs.General:AddRightGroupbox("Automation")
Groupboxes.Self_Misc           = Tabs.General:AddRightGroupbox("Miscellaneous")

-- ============================================
-- TOGGLES & OPTIONS
-- ============================================

Groupboxes.General_Self:AddToggle("DisableAnticheat", {
    Text = "Anticheat Bypass",
    Default = false,
    Tooltip = "Обход античита при взаимодействии с лестницей"
})

Groupboxes.General_Character:AddSlider("SpeedBoost", {
    Text = "Speed Boost",
    Min = 0, Max = 100, Default = 0,
    Rounding = 0, Compact = true
})

Groupboxes.General_Character:AddToggle("SpeedBoostToggle", {
    Text = "Enable Speed Boost",
    Default = false,
    Tooltip = "Увеличивает скорость"
})

Groupboxes.General_Character:AddToggle("FlyToggle", {
    Text = "Fly",
    Default = false,
    Tooltip = "Полёт"
})
Toggles.FlyToggle:AddKeyPicker("FlyKeybind", {
    Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true
})

Groupboxes.General_Character:AddSlider("FlySpeed", {
    Text = "Fly Speed",
    Min = 0, Max = 115, Default = 20,
    Rounding = 0, Compact = true
})

Groupboxes.General_Character:AddSlider("FlyAcceleration", {
    Text = "Fly Acceleration",
    Min = 5, Max = 150, Default = 45,
    Rounding = 0, Compact = true
})

Groupboxes.General_Character:AddSlider("FlyDeceleration", {
    Text = "Fly Deceleration",
    Min = 5, Max = 150, Default = 35,
    Rounding = 0, Compact = true
})

Groupboxes.General_Character:AddSlider("FlyShiftMultiplier", {
    Text = "Fly Shift Multiplier",
    Min = 1, Max = 4, Default = 2,
    Rounding = 1, Compact = true
})

Groupboxes.General_Character:AddSlider("FlyVerticalSpeed", {
    Text = "Fly Vertical Speed",
    Min = 1, Max = 80, Default = 20,
    Rounding = 0, Compact = true
})

Groupboxes.General_Character:AddSlider("FlySmoothness", {
    Text = "Fly Turn Smoothness",
    Min = 1, Max = 20, Default = 8,
    Rounding = 1, Compact = true
})

Groupboxes.General_Character:AddDivider()

Groupboxes.General_Character:AddToggle("NoclipToggle", {
    Text = "Noclip",
    Default = false,
    Tooltip = "Проходить сквозь стены"
})
Toggles.NoclipToggle:AddKeyPicker("NoclipKeybind", {
    Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true
})

Groupboxes.General_Character:AddDivider()

Groupboxes.General_Character:AddToggle("PositionSpoof", {
    Text = "Position Spoof",
    Default = false,
    Tooltip = "Телепортирует хитбокс под пол"
})
Toggles.PositionSpoof:AddKeyPicker("PositionSpoofKeybind", {
    Text = "Position Spoof", Default = "B", Mode = "Toggle", SyncToggleState = true
})

Groupboxes.General_Character:AddToggle("VelocityManipulationToggle", {
    Text = "Velocity Manipulation",
    Default = false,
    Tooltip = "Обход античита через физику"
})
Toggles.VelocityManipulationToggle:AddKeyPicker("VelocityManipulationKeybind", {
    Text = "Velocity Manipulation", Default = "V", Mode = "Toggle", SyncToggleState = true
})

Groupboxes.General_Character:AddDropdown("VelocityManipulationMode", {
    Text = "Manipulation Method",
    Values = { "Velocity", "Pivot" },
    Default = 1,
})

-- ============================================
-- SPEED LOGIC + POSITION SPOOF + ANTICHEAT BYPASS
-- Технология Abysall, улучшенная версия
-- ============================================

Functions.IsCrouching = function()
    if not Character then return false end
    if Floor == "Fools" or Floor == "OldHotel" then
        return Character:GetAttribute("Crouching") == true
    end
    local CP = Character:FindFirstChild("CollisionPart") or Character:FindFirstChild("Collision")
    return CP and CP.CollisionGroup == "PlayerCrouching" or false
end

Functions.GetInjuriesSpeed = function()
    if not Humanoid then return 0 end
    return 0.075 * (Humanoid.MaxHealth - Humanoid.Health)
end

Functions.GetCurrentSpeed = function()
    local Speed = 15
    if not Character or not Humanoid then return Speed end

    Speed += Character:GetAttribute("SpeedBoost") or 0
    Speed += Character:GetAttribute("SpeedBoostBehind") or 0
    Speed += Character:GetAttribute("SpeedBoostExtra") or 0
    Speed += (Floor == "Party" and 10 or 0)

    if LiveModifiers then
        Speed += (LiveModifiers:FindFirstChild("PlayerFast") and 3 or 0)
        Speed += (LiveModifiers:FindFirstChild("PlayerFaster") and 6 or 0)
        Speed += (LiveModifiers:FindFirstChild("PlayerFastest") and 20 or 0)
        Speed -= (LiveModifiers:FindFirstChild("PlayerSlow") and 3 or 0)
        Speed -= (LiveModifiers:FindFirstChild("PlayerSlowHealth") and Functions.GetInjuriesSpeed() or 0)
    end

    if Functions.IsCrouching() then
        Speed -= (LiveModifiers and LiveModifiers:FindFirstChild("PlayerCrouchSlow") and 8 or 5)
    end

    return Speed
end

-- === Movement State ===
local MovementState = {
    SpoofState = {
        Applied = false,
        LastCrouchFire = 0,
    },
    CrouchDelay = 0.1,
    LastSpeedUpdate = 0,
    LastSpeedState = "",
}

Functions.GetSpeedStateKey = function()
    local key = Floor or ""

    if Character then
        key = key
            .. ":" .. tostring(Character:GetAttribute("SpeedBoost") or 0)
            .. ":" .. tostring(Character:GetAttribute("SpeedBoostBehind") or 0)
            .. ":" .. tostring(Character:GetAttribute("SpeedBoostExtra") or 0)
            .. ":" .. tostring(Character:GetAttribute("Crouching") or false)
    end

    if LiveModifiers then
        local modifiers = {}
        for _, mod in ipairs(LiveModifiers:GetChildren()) do
            if mod:IsA("BoolValue") then
                table.insert(modifiers, mod.Name .. ":" .. tostring(mod.Value))
            end
        end
        table.sort(modifiers)
        key = key .. ":" .. table.concat(modifiers, ",")
    end

    return key
end

local function ApplyPositionSpoof(Enabled)
    if not RootPart or not Humanoid then return end
    local spoofPart = CollisionPart or Collision or RootPart

    if Floor == "Fools" or Floor == "OldHotel" then
        if Enabled and not MovementState.SpoofState.Applied then
            if spoofPart and spoofPart:IsA("BasePart") then
                spoofPart.CFrame = spoofPart.CFrame * CFrame.new(0, -2.346, 0)
            else
                RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
            end
            Humanoid.HipHeight = 0.05
            MovementState.SpoofState.Applied = true
        elseif not Enabled and MovementState.SpoofState.Applied then
            if spoofPart and spoofPart:IsA("BasePart") then
                spoofPart.CFrame = spoofPart.CFrame * CFrame.new(0, 2.346, 0)
            else
                RootPart.CFrame = RootPart.CFrame * CFrame.new(0, 2.346, 0)
            end
            Humanoid.HipHeight = 2.396
            MovementState.SpoofState.Applied = false
        end
        return
    end

    if Enabled and not MovementState.SpoofState.Applied then
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
        Humanoid.HipHeight = 0.05
        MovementState.SpoofState.Applied = true
    elseif not Enabled and MovementState.SpoofState.Applied then
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, 2.346, 0)
        Humanoid.HipHeight = 2.396
        MovementState.SpoofState.Applied = false
    end
end

local function UpdateSpeedBoost()
    if not Humanoid then return end

    local baseSpeed = Functions.GetCurrentSpeed()
    local boost = Options.SpeedBoost.Value or 0

    if Toggles.SpeedBoostToggle.Value then
        Humanoid.WalkSpeed = baseSpeed + boost
    end
end

-- === Hook на Crouch FireServer (главный обход) ===
if tokagod.Environment
   and tokagod.Environment.hookmetamethod
   and tokagod.Environment.newcclosure
   and tokagod.Environment.getnamecallmethod
then
    local OldNamecall
    OldNamecall = tokagod.Environment.hookmetamethod(
        game, "__namecall",
        tokagod.Environment.newcclosure(function(Self, ...)
            local Args = { ... }
            local Method = tokagod.Environment.getnamecallmethod()

            if Self.Name == "Crouch" and Method == "FireServer" then
                if Toggles.PositionSpoof.Value then
                    Args[1] = true
                end
                Args[2] = true
            end

            return OldNamecall(Self, table.unpack(Args))
        end)
    )
end

-- === Main Loop: Speed + Spoof ===
Functions.ConnectSignal(RunService.RenderStepped, function()
    if not Character or not Humanoid or not RootPart then return end

    local speedState = Functions.GetSpeedStateKey()
    if tick() - MovementState.LastSpeedUpdate >= 0.1 or speedState ~= MovementState.LastSpeedState then
        UpdateSpeedBoost()
        MovementState.LastSpeedUpdate = tick()
        MovementState.LastSpeedState = speedState
    end

    if Toggles.PositionSpoof.Value and tick() - MovementState.SpoofState.LastCrouchFire > MovementState.CrouchDelay then
        if RemotesFolder and RemotesFolder:FindFirstChild("Crouch") then
            pcall(function()
                RemotesFolder.Crouch:FireServer(true, true)
            end)
        end
        MovementState.SpoofState.LastCrouchFire = tick()
    end
end)

-- === SpeedBoost toggle ===
Toggles.SpeedBoostToggle:OnChanged(function(Value)
    UpdateSpeedBoost()
    Functions.Notify({
        Title = "Speed Boost",
        Body = Value and "Enabled" or "Disabled"
    })
end)

Options.SpeedBoost:OnChanged(UpdateSpeedBoost)

Toggles.PositionSpoof:OnChanged(function(Value)
    ApplyPositionSpoof(Value)
end)

-- ============================================
-- FLY
-- ============================================

local StopFly

local function MoveTowardsVector(current, target, maxDelta)
    local difference = target - current
    local distance = difference.Magnitude
    if distance <= maxDelta or distance == 0 then
        return target
    end
    return current + difference / distance * maxDelta
end

local function RemoveFlyObject(object)
    if not object then return end
    for index = #Globals.BodyObjects, 1, -1 do
        if Globals.BodyObjects[index] == object then
            table.remove(Globals.BodyObjects, index)
        end
    end
    if object.Parent then
        object:Destroy()
    end
end

local function RestoreFlyCharacter(root, humanoid)
    if root and root.Parent then
        for _, object in ipairs(root:GetChildren()) do
            if object.Name == "tokagod_FlyVelocity" or object.Name == "tokagod_FlyGyro" then
                object:Destroy()
            end
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    if humanoid and humanoid.Parent then
        humanoid.PlatformStand = false
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.PlatformStanding then
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
        end
    end
end

local function FinishFlyLanding()
    local root = Globals.Active.FlyRootPart
    local humanoid = Globals.Active.FlyHumanoid
    local bodyVelocity = Globals.Active.FlyVelocity

    if Globals.Active.FlyConnection then
        Globals.Active.FlyConnection:Disconnect()
        Globals.Active.FlyConnection = nil
    end

    RemoveFlyObject(bodyVelocity)
    RemoveFlyObject(Globals.Active.FlyGyro)
    RestoreFlyCharacter(root, humanoid)
    Globals.Active.FlyVelocity = nil
    Globals.Active.FlyGyro = nil
    Globals.Active.FlyRootPart = nil
    Globals.Active.FlyHumanoid = nil
    Globals.Active.FlyCurrentVelocity = nil
    Globals.Active.FlyRaycastParams = nil
    Globals.Active.FlyLanding = false
end

local function UpdateFly(deltaTime)
    if not Globals.Active.Fly then return end
    local dt = math.min(deltaTime, 0.1)

    local root = Globals.Active.FlyRootPart
    local humanoid = Globals.Active.FlyHumanoid
    local bodyVelocity = Globals.Active.FlyVelocity
    local bodyGyro = Globals.Active.FlyGyro
    local camera = Workspace.CurrentCamera
    if not root or not root.Parent or not humanoid or humanoid.Health <= 0
        or not bodyVelocity or not bodyGyro or not camera then
        StopFly(true)
        return
    end

    local cameraFrame = camera.CFrame
    local forward = Vector3.new(cameraFrame.LookVector.X, 0, cameraFrame.LookVector.Z)
    local right = Vector3.new(cameraFrame.RightVector.X, 0, cameraFrame.RightVector.Z)
    if forward.Magnitude > 0 then forward = forward.Unit end
    if right.Magnitude > 0 then right = right.Unit end

    local horizontalInput = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then horizontalInput += forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then horizontalInput -= forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then horizontalInput += right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then horizontalInput -= right end
    if horizontalInput.Magnitude > 1 then horizontalInput = horizontalInput.Unit end

    local multiplier = 1
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
        multiplier *= Options.FlyShiftMultiplier.Value or 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
        multiplier *= 0.5
    end

    local flySpeed = Options.FlySpeed.Value * multiplier
    local verticalInput = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then verticalInput += 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then verticalInput -= 1 end

    local targetVelocity = Vector3.new(
        horizontalInput.X * flySpeed,
        verticalInput * (Options.FlyVerticalSpeed.Value or 20) * multiplier,
        horizontalInput.Z * flySpeed
    )

    local hasInput = horizontalInput.Magnitude > 0 or verticalInput ~= 0
    local acceleration = hasInput and Options.FlyAcceleration.Value or Options.FlyDeceleration.Value
    local currentVelocity = Globals.Active.FlyCurrentVelocity or root.AssemblyLinearVelocity
    currentVelocity = MoveTowardsVector(currentVelocity, targetVelocity, acceleration * dt)

    local travel = currentVelocity * dt
    if travel.Magnitude > 0.01 then
        local rayParams = Globals.Active.FlyRaycastParams
        local hit = Workspace:Raycast(root.Position, travel.Unit * (travel.Magnitude + 2), rayParams)
        if hit then
            local intoWall = currentVelocity:Dot(hit.Normal)
            if intoWall < 0 then
                currentVelocity -= hit.Normal * intoWall
            end
        end
    end

    Globals.Active.FlyCurrentVelocity = currentVelocity
    bodyVelocity.Velocity = currentVelocity

    local facing = Vector3.new(cameraFrame.LookVector.X, 0, cameraFrame.LookVector.Z)
    if facing.Magnitude > 0.001 then
        local targetRotation = CFrame.lookAt(root.Position, root.Position + facing.Unit)
        local turnAlpha = 1 - math.exp(-(Options.FlySmoothness.Value or 8) * dt)
        bodyGyro.CFrame = bodyGyro.CFrame:Lerp(targetRotation, turnAlpha)
    end
end

local function StartFly()
    if Globals.Active.FlyLanding then
        StopFly(true)
    end
    if not Character or not RootPart or not Humanoid or Humanoid.Health <= 0 then return end
    if Globals.Active.Fly then return end
    if Globals.Active.FlyConnection then
        StopFly(true)
    end

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "tokagod_FlyVelocity"
    bodyVelocity.MaxForce = Vector3.one * RootPart.AssemblyMass * 10000
    bodyVelocity.P = 2500
    bodyVelocity.Velocity = RootPart.AssemblyLinearVelocity
    bodyVelocity.Parent = RootPart

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "tokagod_FlyGyro"
    bodyGyro.MaxTorque = Vector3.one * RootPart.AssemblyMass * 10000
    bodyGyro.P = 2500
    bodyGyro.D = 500
    bodyGyro.CFrame = RootPart.CFrame
    bodyGyro.Parent = RootPart

    table.insert(Globals.BodyObjects, bodyVelocity)
    table.insert(Globals.BodyObjects, bodyGyro)
    Globals.Active.FlyVelocity = bodyVelocity
    Globals.Active.FlyGyro = bodyGyro
    Globals.Active.FlyRootPart = RootPart
    Globals.Active.FlyHumanoid = Humanoid
    Globals.Active.FlyCurrentVelocity = RootPart.AssemblyLinearVelocity
    Globals.Active.FlyRaycastParams = RaycastParams.new()
    Globals.Active.FlyRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    Globals.Active.FlyRaycastParams.FilterDescendantsInstances = { Character }
    Globals.Active.Fly = true
    Globals.Active.FlyLanding = false

    Humanoid.PlatformStand = true
    Globals.Active.FlyConnection = Functions.ConnectSignal(RunService.RenderStepped, UpdateFly)
    Globals.Active.FlyDiedConnection = Functions.ConnectCharacterSignal(Humanoid.Died, function()
        StopFly(true)
        pcall(function() Toggles.FlyToggle:SetValue(false) end)
    end)
end

StopFly = function(immediate)
    local root = Globals.Active.FlyRootPart
    local humanoid = Globals.Active.FlyHumanoid
    local bodyVelocity = Globals.Active.FlyVelocity
    local bodyGyro = Globals.Active.FlyGyro

    if Globals.Active.FlyDiedConnection then
        Globals.Active.FlyDiedConnection:Disconnect()
        Globals.Active.FlyDiedConnection = nil
    end

    if not Globals.Active.Fly and not Globals.Active.FlyConnection then return end
    Globals.Active.Fly = false
    if Globals.Active.FlyConnection then
        Globals.Active.FlyConnection:Disconnect()
        Globals.Active.FlyConnection = nil
    end

    RemoveFlyObject(bodyGyro)
    Globals.Active.FlyGyro = nil

    if not immediate and root and root.Parent and humanoid and humanoid.Health > 0 and bodyVelocity then
        Globals.Active.FlyLanding = true
        Globals.Active.FlyCurrentVelocity = root.AssemblyLinearVelocity
        bodyVelocity.Velocity = Globals.Active.FlyCurrentVelocity
        humanoid.PlatformStand = true

        Globals.Active.FlyConnection = Functions.ConnectSignal(RunService.Heartbeat, function(deltaTime)
            if not root.Parent or humanoid.Health <= 0 then
                FinishFlyLanding()
                return
            end

            Globals.Active.FlyCurrentVelocity = MoveTowardsVector(
                Globals.Active.FlyCurrentVelocity,
                Vector3.new(0, -3, 0),
                Options.FlyDeceleration.Value * deltaTime
            )
            bodyVelocity.Velocity = Globals.Active.FlyCurrentVelocity

            local groundDistance = root.Size.Y * 0.5 + 2.5
            local ground = Workspace:Raycast(
                root.Position,
                Vector3.new(0, -groundDistance, 0),
                Globals.Active.FlyRaycastParams
            )
            if ground then
                FinishFlyLanding()
            end
        end)
        return
    end

    if bodyVelocity then bodyVelocity.Velocity = Vector3.zero end
    RemoveFlyObject(bodyVelocity)
    RestoreFlyCharacter(root, humanoid)
    Globals.Active.FlyVelocity = nil
    Globals.Active.FlyRootPart = nil
    Globals.Active.FlyHumanoid = nil
    Globals.Active.FlyCurrentVelocity = nil
    Globals.Active.FlyRaycastParams = nil
    Globals.Active.FlyLanding = false
end

Toggles.FlyToggle:OnChanged(function(Value)
    if Value then StartFly() else StopFly(true) end
end)

-- ============================================
-- ESP SYSTEM (перенесено из Abysall → вкладка Visuals)
-- ============================================

local ESP = {
    Added = {},
    Queue = {},
    LastScan = 0,
    LastPlayerScan = 0,
    ScanInterval = 0.5,
}

local function EnqueueESPObject(Object)
    if not Object then return end
    ESP.Queue[Object] = true
end

local function IsEntitySelected(alias)
    local EntityOptions = Options.EntityESPOptions
    if not EntityOptions or not EntityOptions.Value then
        return true
    end

    local selected = EntityOptions.Value
    if type(selected) == "string" then
        return selected == alias
    end

    if type(selected) == "table" then
        if selected[alias] == true then
            return true
        end
        for _, value in ipairs(selected) do
            if value == alias then
                return true
            end
        end
    end

    return false
end

local function AddESPForObject(Object, Text, Color)
    if not Object then return nil end
    local ok = pcall(function()
        ESPLibrary:AddESP({
            Object = Object,
            Text = Text,
            Color = Color,
        })
    end)
    if ok then return Object end

    if Object:IsA("Model") then
        local primaryPart = Object.PrimaryPart or Object:FindFirstChildWhichIsA("BasePart", true)
        if primaryPart then
            local fallbackOk = pcall(function()
                ESPLibrary:AddESP({
                    Object = primaryPart,
                    Text = Text,
                    Color = Color,
                })
            end)
            if fallbackOk then return primaryPart end
        end
    end

    return nil
end

local function GetEntityESPTarget(Model)
    if Model.Name == "MonumentEntity" then
        local top = Model:FindFirstChild("Top")
        if top and top:IsA("BasePart") then
            return top
        elseif top and top:IsA("Model") then
            return top.PrimaryPart or top:FindFirstChildWhichIsA("BasePart", true)
        end
    end

    return Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart", true)
end

local Objects = {
    Entities = {},
    Doors = {},
    Items = {},
    Chests = {},
    Currency = {},
    Ladders = {},
    Objectives = {},
    HidingSpots = {},
}

-- === Справочники ===
local ItemNames = {
    ["DinkyLamp"]="Lamp",["BottleCrate"]="18+ Bottles",["GweenSodaPack"]="Gween Soda Pack",
    ["BrokenMonitor"]="Broken Monitor",["JerryCan"]="Jerry Can",["SallyToyObtain"]="Sally Toy",
    ["Leftovers"]="Lunch Box",["HoneyPot"]="Honey Pot",["FihFlakes"]="Fih Food",
    ["SecretCD"]="CD Disc",["Pizza"]="Pizza",["PaperPlanePickup"]="Paper Plane",
    ["Lighter"]="Lighter",["Flashlight"]="Flashlight",["Lockpick"]="Lockpicks",
    ["Vitamins"]="Vitamins",["Bandage"]="Bandage",["StarVial"]="Starlight Vial",
    ["StarBottle"]="Starlight Bottle",["StarJug"]="Starlight Barrel",["Shakelight"]="Gummy Flashlight",
    ["Straplight"]="Straplight",["Bulklight"]="Spotlight",["Battery"]="Battery",
    ["Candle"]="Candle",["Crucifix"]="Crucifix",["CrucifixWall"]="Crucifix",
    ["Glowsticks"]="Glowstick",["SkeletonKey"]="Skeleton Key",["Candy"]="Candy",
    ["ShieldMini"]="Mini Shield Potion",["ShieldBig"]="Big Shield Potion",["BandagePack"]="Bandage Pack",
    ["BatteryPack"]="Battery Pack",["RiftCandle"]="Moonlight Candle",["LaserPointer"]="Laser Pointer",
    ["HolyGrenade"]="Holy Hand Grenade",["Shears"]="Shears",["Smoothie"]="Smoothie",
    ["Cheese"]="Cheese",["Bread"]="Bread",["AlarmClock"]="Alarm Clock",
    ["RiftSmoothie"]="Moonlight Smoothie",["GweenSoda"]="Gween Soda",["GlitchCube"]="Glitch Fragment",
    ["Scanner"]="Tablet",["Bomb"]="Bomb",["Knockbomb"]="Knockbomb",
    ["Nanner"]="Nanner",["BigBomb"]="Big Bomb",["SnakeBox"]="Hiding Box",
    ["GoldGun"]="Golden Gun",["StopSign"]="Stop Sign",["TipJar"]="Tip Jar",
    ["Lantern"]="Lantern",["IronKey"]="Iron Key",["LotusPetal"]="Lotus Petal",
    ["Compass"]="Compass",["LotusPetalPickup"]="Lotus Petal",["LanternLitItem"]="Lantern",
    ["KeyIron"]="Iron Key",["IronKeyForCrypt"]="Iron Key",["LotusHolder"]="Lotus Petal",
    ["Multitool"]="Multitool",["RiftJar"]="Rift Jar",["AloeVera"]="Aloe Vera",
    ["Donut"]="Donut",["Lotus"]="Lotus",["BoxingGloves"]="Boxing Gloves"
}

local Entities = {
    ["StemsEntity"]={Alias="Balls"},
    ["NoiseModel"]={Alias="Noise"},
    ["Creak"]={Alias="Creak"},
    ["DronesStampede"]={Alias="DronesStampede"},
    ["TellerRig"]={Alias="Teller"},
    ["Scribbles"]={Alias="Scribbles"},
    ["BashMoving"]={Alias="Bash"},
    ["RushMoving"]={Alias="Rush"},
    ["AmbushMoving"]={Alias="Ambush"},
    ["Eyes"]={Alias="Eyes"},
    ["Lookman"]={Alias="Eyes"},
    ["BackdoorRush"]={Alias="Blitz"},
    ["BackdoorLookman"]={Alias="Lookman"},
    ["Groundskeeper"]={Alias="Groundskeeper"},
    ["A60"]={Alias="A-60"},
    ["A120"]={Alias="A-120"},
    ["GloombatSwarm"]={Alias="Gloombat Swarm"},
    ["GlitchRush"]={Alias="RNIUSHCG=="},
    ["GlitchAmbush"]={Alias="AR0xMBUSH"},
    ["MandrakeHole"]={Alias="Mandrake Hole"},
    ["GloombatEggs"]={Alias="Gloombat Eggs"},
    ["GloombatEgg"]={Alias="Gloombat Eggs"},
    ["MonumentEntity"]={Alias="Monument"},
    ["JeffTheKiller"]={Alias="Jeff the Killer"},
    ["CustomEntity"]={Alias="Custom Entity"},
    ["FrozenAmbush"]={Alias="Frozen Ambush"},
    ["SallyMoving"]={Alias="Sally"},
    ["Snare"]={Alias="Snare"},
    ["GiggleCeiling"]={Alias="Giggle"},
    ["GrumbleRig"]={Alias="Grumble"},
    ["LiveEntityBramble"]={Alias="Bramble"},
    ["Figure"]={Alias="Figure"},
    ["FigureRig"]={Alias="Figure"},
    ["FigureRagdoll"]={Alias="Figure"},
    ["DoorFake"]={Alias="Dupe"},
    ["FakeDoor"]={Alias="Dupe"}
}

local function RefreshEntityESP()
    for Object, category in pairs(ESP.Added) do
        if category == "Entities" then
            pcall(function()
                ESPLibrary:RemoveESP(Object)
            end)
            ESP.Added[Object] = nil
        end
    end

    if not Toggles.EntityESPToggle or not Toggles.EntityESPToggle.Value then return end

    for _, Model in ipairs(Objects.Entities) do
        local entityData = Entities[Model.Name]
        if Model.Parent and entityData and IsEntitySelected(entityData.Alias) then
            EnqueueESPObject(Model)
        end
    end
end

local HidingSpotLabels = {
    Wardrobe="Closet",["Backdoor_Wardrobe"]="Closet",Toolshed="Closet",
    RetroWardrobe="Closet",["Wardrobe-FOOLS26"]="Closet",Locker_Large="Locker",
    Rooms_Locker="Hiding_Spot",Rooms_Locker_Fridge="Locker",Bed="Bed",
    Double_Bed="Double Bed",CircularVent="Vent",Dumpster="Dumpster"
}

local ChestLabels = {
    ChestBox="Chest", ChestBoxLocked="Locked Chest",
    Toolbox="Toolbox", Toolbox_Locked="Locked Toolbox",
    Chest_Vine="Vine Chest", Toolshed_Small="Toolshed",
    Locker_Small_Locked="Locked Item Locker", MouseHole="Mouse"
}

local ObjectiveLabels = {
    KeyObtain="Door Key", ElectricalKeyObtain="Electrical Key",
    MinesGenerator="Generator", FuseObtain="Generator Fuse",
    LiveHintBook="Hint Book", LiveBreakerPolePickup="Fuse Breaker",
    LibraryHintPaper="Hint Paper", PickupItem="Hint Paper",
    CringlePresent="Present", LeverForGate="Gate Lever",
    MinesGateButton="Gate Button", GardenGateButton="Gate Button",
    Cellar="Cellar", ArchivesFihTank="Fih Tank",
    ArchivesPackageDeposit="Package Deposit", SalvageChute="Package Deposit",
    ShoppingCart="Shopping Cart", MinesAnchor="Anchor",
    WaterPump="Water Pump", TimerLever="Time Lever",
    VineGuillotine="Vine Lever"
}

-- === Классификатор объекта ===
local function ClassifyObject(Object)
    local Name = Object.Name

    -- Door — берём структуру из Abysall (HighlightModel + weld к Door.Door)
    if Name == "Door" and Object:IsA("Model") and Object.Parent and tonumber(Object.Parent.Name) then
        -- Логика из Abysall 1-в-1
        local DoorParts = {}
        for _, Child in Object:GetChildren() do
            if Child.Name == "Door" and Child:IsA("BasePart") then
                table.insert(DoorParts, Child)
            end
        end

        local target
        if #DoorParts == 2 then
            -- Создаём HighlightModel (как в Abysall)
            local HighlightModel = Object:FindFirstChild("HighlightModel")
            if not HighlightModel then
                HighlightModel = Instance.new("Model", Object)
                HighlightModel.Name = "HighlightModel"
                local hum = Instance.new("Humanoid", HighlightModel)
                hum.Name = "HighlightHumanoid"
                HighlightModel:SetAttribute("ParentRoom", tonumber(Object.Parent.Name))

                for _, DoorPart in DoorParts do
                    local HP = Instance.new("Part", HighlightModel)
                    HP.Transparency = 0.999
                    HP.Size = DoorPart.Size
                    HP.CanCollide = false
                    HP.CFrame = DoorPart.CFrame
                    HP.Name = "HighlightPart"
                    HP.Material = Enum.Material.Plastic
                    HP:SetAttribute("ParentRoom", tonumber(Object.Parent.Name))
                    local W = Instance.new("WeldConstraint", HP)
                    W.Part0 = HP W.Part1 = DoorPart W.Enabled = true
                end
            end
            target = HighlightModel
        else
            -- Одна створка — создаём HighlightPart (как в Abysall)
            local HP = Object:FindFirstChild("HighlightPart")
            if not HP then
                local Root = Object:WaitForChild("Door", 9)
                if not Root or not Root:IsA("BasePart") then
                    return nil, nil, nil
                end
                HP = Instance.new("Part", Object)
                HP.Transparency = 0.999
                HP.Size = Root.Size
                HP.CanCollide = false
                HP.CFrame = Root.CFrame
                HP.Name = "HighlightPart"
                HP.Material = Enum.Material.Plastic
                HP:SetAttribute("ParentRoom", tonumber(Object.Parent.Name))
                local W = Instance.new("WeldConstraint", HP)
                W.Part0 = HP W.Part1 = Root W.Enabled = true
                Instance.new("Humanoid", Object).Name = "HighlightHumanoid"
            end
            target = HP
        end

        return "Doors", "Door " .. tostring(tonumber(Object.Parent.Name) + 1), target
    end

    if ObjectiveLabels[Name] then
        return "Objectives", ObjectiveLabels[Name], Object
    end

    if HidingSpotLabels[Name] then
        return "HidingSpots", HidingSpotLabels[Name], Object
    end
    if typeof(Name) == "string" and string.find(string.lower(Name), "hidingspot") then
        return "HidingSpots", "Hiding Spot", Object
    end

    if ChestLabels[Name] then
        return "Chests", ChestLabels[Name], Object
    end

    if ItemNames[Name] and Object:FindFirstChild("ModulePrompt") then
        return "Items", ItemNames[Name], Object
    end
    if Name == "Green_Herb" then
        return "Items", "Green Herb", Object
    end

    if Name == "GoldPile" and Object:GetAttribute("GoldValue") then
        return "Currency", "Gold Pile [" .. Object:GetAttribute("GoldValue") .. "]", Object
    end
    if Name == "StardustPickup" then
        return "Currency", "Stardust Pile", Object
    end

    if Name == "Ladder" then
        return "Ladders", "Ladder", Object
    end

    if Entities[Name] then
        return "Entities", Entities[Name].Alias, GetEntityESPTarget(Object)
    end

    return nil, nil, nil
end

local ESPToggleMap = {
    Doors       = "DoorESPToggle",
    HidingSpots = "HidingSpotESPToggle",
    Chests      = "ChestESPToggle",
    Items       = "ItemESPToggle",
    Currency    = "CurrencyESPToggle",
    Ladders     = "LadderESPToggle",
    Objectives  = "ObjectiveESPToggle",
    Entities    = "EntityESPToggle",
}

local ESPColorMap = {
    Doors       = "DoorESPColor",
    HidingSpots = "HidingSpotESPColor",
    Chests      = "ChestESPColor",
    Items       = "ItemESPColor",
    Currency    = "CurrencyESPColor",
    Ladders     = "LadderESPColor",
    Objectives  = "ObjectiveESPColor",
    Entities    = "EntityESPColor",
}

-- === Основной цикл сканирования ===
local function ScanAndUpdate()
    local seen = {}

    for Object in pairs(ESP.Added) do
        seen[Object] = true
    end

    for Object in pairs(ESP.Queue) do
        ESP.Queue[Object] = nil

        local category, label, target = ClassifyObject(Object)
        if category and target then
            seen[target] = true

            local toggleName = ESPToggleMap[category]
            local colorName  = ESPColorMap[category]
            local isOn = Toggles[toggleName] and Toggles[toggleName].Value

            if isOn and category == "Entities" then
                if not IsEntitySelected(label) then
                    isOn = false
                end
            end
            if isOn and not ESP.Added[target] then
                local ok = pcall(function()
                    ESPLibrary:AddESP({
                        Object = target,
                        Text = label,
                        Color = Options[colorName].Value,
                    })
                end)
                if ok then
                    ESP.Added[target] = category
                end
            elseif not isOn and ESP.Added[target] then
                pcall(function() ESPLibrary:RemoveESP(target) end)
                ESP.Added[target] = nil
            end
        end
    end

    for Object in pairs(ESP.Added) do
        if not seen[Object] or not Object.Parent then
            pcall(function() ESPLibrary:RemoveESP(Object) end)
            ESP.Added[Object] = nil
        end
    end
end

Functions.ConnectSignal(RunService.Heartbeat, function()
    if tick() - ESP.LastScan < ESP.ScanInterval then return end
    ESP.LastScan = tick()
    ScanAndUpdate()
end)

-- === Обработчик спавна сущностей (1-в-1 из Abysall) ===
local RusherAliases = {
    Rush=true, Bash=true, Scribbles=true, DronesStampede=true, Ambush=true,
    Eyes=true, Lookman=true, Blitz=true, ["A-60"]=true, ["A-120"]=true,
    ["AR0xMBUSH"]=true, ["RNIUSHCG=="]=true, ["Custom Entity"]=true
}

local function HandleEntitySpawn(Entity)
    if not Entity or typeof(Entity) ~= "Instance" then return end

    local Model = Entity
    if Entity:IsA("Humanoid") then
        Model = Entity.Parent
    end
    while Model and (not Model:IsA("Model") or not Entities[Model.Name]) do
        Model = Model.Parent
    end
    if not Model then return end

    local EntityData = Entities[Model.Name]
    if not EntityData then return end
    if Model:GetAttribute("tokagod_EntityHandled") then return end
    Model:SetAttribute("tokagod_EntityHandled", true)
    print("Entity spawn:", Model.Name)

    local start = tick()
    while not Model.PrimaryPart do
        for _, Child in Model:GetDescendants() do
            if Child:IsA("BasePart") then Model.PrimaryPart = Child end
        end
        if tick() - start > 5 then break end
        if not Model.PrimaryPart then task.wait(0.05) end
    end
    task.wait(0.1)

    if not Model.PrimaryPart then
        Model:SetAttribute("tokagod_EntityHandled", nil)
        warn("Entity has no BasePart:", Model.Name)
        return
    end
    if LocalPlayer:DistanceFromCharacter(Model.PrimaryPart.Position) >= 10000 then return end

    local Alias = EntityData.Alias
    local RealAlias = Alias

    -- Уведомление (только если включён NotifyEntities — но у нас его нет, пропускаем)

    table.insert(Objects.Entities, Model)
    Model.Destroying:Once(function()
        local index = table.find(Objects.Entities, Model)
        if index then
            table.remove(Objects.Entities, index)
        end

        local target = GetEntityESPTarget(Model)
        if target and ESP.Added[target] == "Entities" then
            pcall(function()
                ESPLibrary:RemoveESP(target)
            end)
            ESP.Added[target] = nil
        end
        ESP.Queue[Model] = nil
    end)

    if Toggles.EntityESPToggle.Value and IsEntitySelected(RealAlias) then
        EnqueueESPObject(Model)
    end

    if RusherAliases[EntityData.Alias] then
        if not Model:FindFirstChild("HighlightHumanoid") then
            Instance.new("Humanoid", Model).Name = "HighlightHumanoid"
        end
        local Root = Model.PrimaryPart
        if Root then
            Root.Transparency = 0.999
            Root.Material = Enum.Material.Plastic
        end
    end

    if Model.Name == "Lookman" then
        CurrentRooms.ChildAdded:Wait()
        task.wait(10)
        Model:Destroy()
    end
end

Functions.ConnectSignal(Workspace.ChildAdded, function(Child)
    HandleEntitySpawn(Child)
end)

Functions.ConnectSignal(Workspace.DescendantAdded, function(Descendant)
    EnqueueESPObject(Descendant)
    task.defer(function()
        HandleEntitySpawn(Descendant)
    end)
end)

-- === Player ESP (отдельно) ===
local function UpdatePlayerESP()
    for _, Player in Players:GetPlayers() do
        if Player ~= LocalPlayer and Player.Character then
            local HRP = Player.Character:FindFirstChild("HumanoidRootPart")
            if HRP then
                local isOn = Toggles.PlayerESPToggle.Value
                local isAdded = ESP.Added[HRP]
                if isOn and not isAdded then
                    local ok = pcall(function()
                        ESPLibrary:AddESP({
                            Object = HRP,
                            Text = Player.Name,
                            Color = Options.PlayerESPColor.Value,
                        })
                    end)
                    if ok then ESP.Added[HRP] = "Players" end
                elseif not isOn and isAdded then
                    pcall(function() ESPLibrary:RemoveESP(HRP) end)
                    ESP.Added[HRP] = nil
                end
            end
        end
    end
end

Functions.ConnectSignal(RunService.Heartbeat, function()
    if tick() - ESP.LastPlayerScan < 0.5 then return end
    ESP.LastPlayerScan = tick()
    UpdatePlayerESP()
end)

-- ============================================
-- ESP UI (внутри Visuals)
-- ============================================

Groupboxes.Visuals_ESP          = Tabs.Visuals:AddLeftGroupbox("ESP")
Groupboxes.Visuals_ESP_Settings = Tabs.Visuals:AddRightGroupbox("ESP Settings")

Groupboxes.Visuals_ESP:AddToggle("ObjectiveESPToggle", { Text = "Objectives", Default = false })
Groupboxes.Visuals_ESP:AddToggle("DoorESPToggle",       { Text = "Doors", Default = false })
Groupboxes.Visuals_ESP:AddToggle("HidingSpotESPToggle", { Text = "Hiding Spots", Default = false })
Groupboxes.Visuals_ESP:AddToggle("PlayerESPToggle",     { Text = "Players", Default = false })
Groupboxes.Visuals_ESP:AddToggle("ChestESPToggle",      { Text = "Chests", Default = false })
Groupboxes.Visuals_ESP:AddToggle("ItemESPToggle",       { Text = "Items", Default = false })
Groupboxes.Visuals_ESP:AddToggle("CurrencyESPToggle",   { Text = "Currency", Default = false })
Groupboxes.Visuals_ESP:AddToggle("LadderESPToggle",     { Text = "Ladders", Default = false })
Groupboxes.Visuals_ESP:AddDivider()
Groupboxes.Visuals_ESP:AddDropdown("EntityESPOptions", {
    Text = "Entities List",
    Values = {
        "Rush","Bash","Scribbles","Teller","DronesStampede","Creak","Noise","Balls",
        "Ambush","Eyes","Dupe","Figure","Blitz","Lookman","Snare","Giggle",
        "Gloombat Eggs","Grumble","A-60","A-120","Sally","Jeff the Killer",
        "Groundskeeper","Mandrake Hole","Monument","Bramble","AR0xMBUSH","RNIUSHCG=="
    },
    Default = { "Rush", "Ambush", "Blitz", "A-60", "A-120", "AR0xMBUSH", "RNIUSHCG==" },
    Multi = true,
    AllowNull = true,
})
Groupboxes.Visuals_ESP:AddToggle("EntityESPToggle",     { Text = "Entities", Default = false })
Toggles.EntityESPToggle:OnChanged(RefreshEntityESP)
Options.EntityESPOptions:OnChanged(RefreshEntityESP)

Toggles.ObjectiveESPToggle:AddColorPicker("ObjectiveESPColor", { Text = "Objectives", Default = Color3.fromRGB(0,255,0), Transparency = 0 })
Toggles.DoorESPToggle:AddColorPicker("DoorESPColor",           { Text = "Doors", Default = Color3.fromRGB(0,200,255), Transparency = 0 })
Toggles.HidingSpotESPToggle:AddColorPicker("HidingSpotESPColor",{ Text = "Hiding Spots", Default = Color3.fromRGB(255,170,0), Transparency = 0 })
Toggles.PlayerESPToggle:AddColorPicker("PlayerESPColor",       { Text = "Players", Default = Color3.fromRGB(255,255,255), Transparency = 0 })
Toggles.ChestESPToggle:AddColorPicker("ChestESPColor",         { Text = "Chests", Default = Color3.fromRGB(255,255,0), Transparency = 0 })
Toggles.ItemESPToggle:AddColorPicker("ItemESPColor",           { Text = "Items", Default = Color3.fromRGB(170,0,255), Transparency = 0 })
Toggles.CurrencyESPToggle:AddColorPicker("CurrencyESPColor",   { Text = "Currency", Default = Color3.fromRGB(255,255,0), Transparency = 0 })
Toggles.LadderESPToggle:AddColorPicker("LadderESPColor",       { Text = "Ladders", Default = Color3.fromRGB(255,255,255), Transparency = 0 })
Toggles.EntityESPToggle:AddColorPicker("EntityESPColor",       { Text = "Entities", Default = Color3.fromRGB(255,0,0), Transparency = 0 })

Groupboxes.Visuals_ESP_Settings:AddToggle("ESPRainbow",      { Text = "Rainbow Effect", Default = false })
Groupboxes.Visuals_ESP_Settings:AddToggle("ESPShowDistance", { Text = "Show Distance", Default = true })
Groupboxes.Visuals_ESP_Settings:AddDivider()
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPFillTransparency",        { Text = "Fill Transparency", Min = 0, Max = 1, Default = 0.75, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPOutlineTransparency",     { Text = "Outline Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTextTransparency",        { Text = "Text Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTextOutlineTransparency", { Text = "Text Outline Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPFadeTime",                { Text = "Fade Time", Min = 0, Max = 1, Default = 0.25, Rounding = 2, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPRenderLimit",             { Text = "Render Limit", Min = 30, Max = 240, Default = 240, Rounding = 0, Compact = true })
Groupboxes.Visuals_ESP_Settings:AddSlider("ESPTextSize",                { Text = "Text Size", Min = 12, Max = 24, Default = 20, Rounding = 0, Compact = true })

-- === Применение настроек ===
ESPLibrary:SetRainbow(false)
ESPLibrary:SetShowDistance(true)
ESPLibrary:SetFillTransparency(0.75)
ESPLibrary:SetOutlineTransparency(0)
ESPLibrary:SetTextTransparency(0)
ESPLibrary:SetTextOutlineTransparency(0)
ESPLibrary:SetRenderLimit(240)
ESPLibrary:SetFadeTime(0.25)
ESPLibrary:SetTextSize(20)

Toggles.ESPRainbow:OnChanged(function(V) ESPLibrary:SetRainbow(V) end)
Toggles.ESPShowDistance:OnChanged(function(V) ESPLibrary:SetShowDistance(V) end)
Options.ESPFillTransparency:OnChanged(function(V) ESPLibrary:SetFillTransparency(V) end)
Options.ESPOutlineTransparency:OnChanged(function(V) ESPLibrary:SetOutlineTransparency(V) end)
Options.ESPTextTransparency:OnChanged(function(V) ESPLibrary:SetTextTransparency(V) end)
Options.ESPTextOutlineTransparency:OnChanged(function(V) ESPLibrary:SetTextOutlineTransparency(V) end)
Options.ESPFadeTime:OnChanged(function(V) ESPLibrary:SetFadeTime(V) end)
Options.ESPRenderLimit:OnChanged(function(V) ESPLibrary:SetRenderLimit(V) end)
Options.ESPTextSize:OnChanged(function(V) ESPLibrary:SetTextSize(V) end)

-- === Изменение цвета → обновление уже подсвеченных ===
for category, colorName in pairs(ESPColorMap) do
    if Options[colorName] then
        Options[colorName]:OnChanged(function(newColor)
            for Object, cat in pairs(ESP.Added) do
                if cat == category then
                    pcall(function() ESPLibrary:UpdateObjectColor(Object, newColor) end)
                end
            end
        end)
    end
end

-- === Очистка при Unload ===
Library:OnUnload(function()
    for Object in pairs(ESP.Added) do
        pcall(function() ESPLibrary:RemoveESP(Object) end)
    end
    ESP.Added = {}
end)

-- ============================================
-- NOCLIP
-- ============================================

local function StartNoclip()
    if Globals.Active.Noclip then return end

    Globals.Active.Noclip = true
    Globals.Active.NoclipConnection = Functions.ConnectSignal(RunService.Stepped, function()
        if not Character or not Globals.Active.Noclip then return end

        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if part:GetAttribute("tokagod_OriginalCanCollide") == nil then
                    part:SetAttribute("tokagod_OriginalCanCollide", part.CanCollide)
                end
                part.CanCollide = false
            end
        end

        Functions.FireRemote("Crouch", true, true)

    end)
end

local function StopNoclip()
    if Globals.Active.NoclipConnection then
        Globals.Active.NoclipConnection:Disconnect()
        Globals.Active.NoclipConnection = nil
    end

    if Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                local originalCanCollide = part:GetAttribute("tokagod_OriginalCanCollide")
                if originalCanCollide ~= nil then
                    part.CanCollide = originalCanCollide
                    part:SetAttribute("tokagod_OriginalCanCollide", nil)
                else
                    part.CanCollide = true
                end
            end
        end
    end

    Globals.Active.Noclip = false
end

Toggles.NoclipToggle:OnChanged(function(Value)
    if Value then
        StartNoclip()
        Functions.Notify({ Title = "Noclip", Body = "Включено" })
    else
        StopNoclip()
        Functions.Notify({ Title = "Noclip", Body = "Выключено" })
    end
end)

-- ============================================
-- VELOCITY MANIPULATION
-- ============================================

local manipulateBody = nil

local function UpdateVelocityManipulation()
    if not Toggles.VelocityManipulationToggle.Value or not RootPart then
        if manipulateBody and manipulateBody.Parent then
            manipulateBody.Parent = nil
        end
        return
    end

    if not manipulateBody then
        manipulateBody = Instance.new("BodyVelocity")
        manipulateBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        table.insert(Globals.BodyObjects, manipulateBody)
    end

    -- Безопасное получение режима
    local mode = "Velocity"
    if Options.VelocityManipulationMode and Options.VelocityManipulationMode.Value then
        mode = Options.VelocityManipulationMode.Value
    end

    if mode == "Velocity" then
        manipulateBody.Parent = RootPart
        manipulateBody.Velocity = RootPart.CFrame.LookVector * 2.25
    else
        manipulateBody.Parent = nil
        if Character and Floor ~= "Fools" and Floor ~= "OldHotel" then
            Character:PivotTo(Workspace.CurrentCamera:GetPivot() * CFrame.new(0, 0, 2560))
        end
    end
end

Functions.ConnectSignal(RunService.RenderStepped, function()
    if not Toggles.VelocityManipulationToggle.Value then return end
    UpdateVelocityManipulation()
end)

Toggles.VelocityManipulationToggle:OnChanged(UpdateVelocityManipulation)
if Options.VelocityManipulationMode then
    Options.VelocityManipulationMode:OnChanged(UpdateVelocityManipulation)
end

-- ============================================
-- CHARACTER HANDLER
-- ============================================

local function OnCharacterAdded(newCharacter)
    if Globals.Active.Fly or Globals.Active.FlyConnection then
        StopFly(true)
    end
    Functions.DisconnectCharacterConnections()

    Character = newCharacter
    Humanoid = newCharacter:WaitForChild("Humanoid", 10)
    RootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
    Collision = newCharacter:FindFirstChild("Collision")
    CollisionPart = newCharacter:FindFirstChild("CollisionPart")

    if not Humanoid or not RootPart then return end

    if Toggles.FlyToggle.Value then
        task.wait(0.5)
        StartFly()
    end

    if Toggles.NoclipToggle.Value then
        StartNoclip()
    end

    Functions.ConnectCharacterSignal(Character:GetAttributeChangedSignal("Climbing"), function()
        if Character
            and Character:GetAttribute("Climbing") == true
            and Toggles.DisableAnticheat.Value
        then
            task.wait(0.25)
            Character:SetAttribute("Climbing", false)
            Functions.Notify({ Title = "Anticheat", Body = "Bypassed" })
        end
    end)
end

if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end
Functions.ConnectSignal(LocalPlayer.CharacterAdded, OnCharacterAdded)

-- ============================================
-- SAVE / THEME
-- ============================================

if SaveManager then
    SaveManager:SetLibrary(Library)
    SaveManager:SetFolder("tokagod/Doors")
    SaveManager:BuildConfigSection(Tabs.Settings)
    SaveManager:LoadAutoloadConfig()
end

if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:ApplyToTab(Tabs.Settings)
end

-- ============================================
-- UNLOAD
-- ============================================

local Settings_Misc = Tabs.Settings:AddLeftGroupbox("Misc")

Settings_Misc:AddButton({
    Text = "Unload Script",
    Tooltip = "Полностью выгружает скрипт",
    DoubleClick = true,
    Risky = true,
    Func = function()
        StopFly(true)
        StopNoclip()
        Functions.DisconnectAll()
        Functions.CleanupBodyObjects()

        if Library and Library.Unload then
            Library:Unload()
        end

        if shared then shared.tokagod = nil end
        if getgenv then getgenv().tokagod = nil end

        print("[tokagod] Unloaded")
    end
})

Library:OnUnload(function()
    StopFly(true)
    StopNoclip()
    Functions.DisconnectAll()
    Functions.CleanupBodyObjects()
    pcall(function() Toggles.SpeedBoostToggle:SetValue(false) end)
    pcall(function() Toggles.FlyToggle:SetValue(false) end)
    pcall(function() Toggles.NoclipToggle:SetValue(false) end)

    if Humanoid then
        pcall(function() Humanoid.WalkSpeed = 15 end)
        pcall(function() Humanoid.HipHeight = 2.367 end)
        pcall(function() Humanoid.PlatformStand = false end)
    end

    print("[tokagod] Cleaned up")
end)

-- ============================================
-- BOOT
-- ============================================

Functions.Notify({
    Title = "tokagod loaded",
    Body = "Press RightShift to open menu",
    Time = 5
})
