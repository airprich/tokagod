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
            if object.Name == "tokagod_FlyVelocity" then
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

local function UpdateFly()
    if not Globals.Active.Fly then return end

    local root = Globals.Active.FlyRootPart
    local humanoid = Globals.Active.FlyHumanoid
    local bodyVelocity = Globals.Active.FlyVelocity
    local camera = Workspace.CurrentCamera
    if not root or not root.Parent or not humanoid or humanoid.Health <= 0
        or not bodyVelocity or not camera then
        StopFly(true)
        return
    end

    local cam = camera.CFrame
    local forward = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
    local right = Vector3.new(cam.RightVector.X, 0, cam.RightVector.Z)
    if forward.Magnitude > 0 then forward = forward.Unit end
    if right.Magnitude > 0 then right = right.Unit end

    local direction = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - right end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.new(0, 1, 0) end

    if direction.Magnitude > 0 then
        direction = direction.Unit
    end

    bodyVelocity.Velocity = direction * (Options.FlySpeed.Value or 20)
end

local function StartFly()
    if not Character or not RootPart or not Humanoid or Humanoid.Health <= 0 then return end
    if Globals.Active.Fly then return end
    if Globals.Active.FlyConnection then
        StopFly(true)
    end

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "tokagod_FlyVelocity"
    bodyVelocity.MaxForce = Vector3.one * RootPart.AssemblyMass * 10000
    bodyVelocity.P = 2500
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = RootPart

    table.insert(Globals.BodyObjects, bodyVelocity)
    Globals.Active.FlyVelocity = bodyVelocity
    Globals.Active.FlyRootPart = RootPart
    Globals.Active.FlyHumanoid = Humanoid
    Globals.Active.Fly = true

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

    if Globals.Active.FlyDiedConnection then
        Globals.Active.FlyDiedConnection:Disconnect()
        Globals.Active.FlyDiedConnection = nil
    end

    if not Globals.Active.Fly and not Globals.Active.FlyConnection and not bodyVelocity then return end
    Globals.Active.Fly = false
    if Globals.Active.FlyConnection then
        Globals.Active.FlyConnection:Disconnect()
        Globals.Active.FlyConnection = nil
    end

    if bodyVelocity then bodyVelocity.Velocity = Vector3.zero end
    RemoveFlyObject(bodyVelocity)
    RestoreFlyCharacter(root, humanoid)
    Globals.Active.FlyVelocity = nil
    Globals.Active.FlyRootPart = nil
    Globals.Active.FlyHumanoid = nil
end

Toggles.FlyToggle:OnChanged(function(Value)
    if Value then StartFly() else StopFly(true) end
end)

-- ============================================
-- ESP SYSTEM (перенесено из Abysall → вкладка Visuals)
-- ============================================

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

Functions.AddESP = function(ESPOptions, RoomBased)
    local Object = ESPOptions.Object
    if not Object or table.find(Globals.ESPBlacklist, Object) then return end
    if RoomBased and Globals.ESPConnections[Object] then return end

    local function AddObject()
        pcall(function()
            ESPLibrary:AddESP(ESPOptions)
        end)
    end

    if RoomBased then
        local CurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
        local ObjectRoom = tonumber(Object:GetAttribute("ParentRoom"))

        if ObjectRoom == CurrentRoom
            or (table.find(Objects.Doors, Object) and ObjectRoom == CurrentRoom + 1) then
            AddObject()
        end

        local RoomConnection = LocalPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(function()
            if ESPLibrary.ColorTable and ESPLibrary.ColorTable[Object] then
                ESPOptions.Color = ESPLibrary.ColorTable[Object]
            end
            local NewCurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
            local ObjRoom = tonumber(Object:GetAttribute("ParentRoom"))
            if ObjRoom == NewCurrentRoom
                or (table.find(Objects.Doors, Object) and ObjRoom == NewCurrentRoom + 1) then
                AddObject()
            else
                pcall(function()
                    ESPLibrary:RemoveESP(Object)
                end)
            end
        end)

        table.insert(Globals.Connections, RoomConnection)
        Globals.ESPConnections[Object] = RoomConnection
        Object.Destroying:Once(function()
            Functions.RemoveESP(Object)
        end)
    else
        AddObject()
    end
end

Functions.RemoveESP = function(Object)
    local Connection = Globals.ESPConnections[Object]
    if Connection then
        Connection:Disconnect()
        Globals.ESPConnections[Object] = nil
        local Position = table.find(Globals.Connections, Connection)
        if Position then table.remove(Globals.Connections, Position) end
    end
    pcall(function()
        ESPLibrary:RemoveESP(Object)
    end)
end

Functions.BlacklistESP = function(Object)
    table.insert(Globals.ESPBlacklist, Object)
end

Functions.GetDoorNumber = function(Object)
    local DoorNumber = tonumber(Object.Parent.Name) or tonumber(Object.Parent.Parent.Name)
    if DoorNumber then DoorNumber = DoorNumber + 1 end
    if Floor == "Mines" and DoorNumber then DoorNumber = DoorNumber + 100 end
    if Floor == "Backdoor" and DoorNumber then DoorNumber = DoorNumber - 50 end
    return tostring(DoorNumber)
end

local function EntityIsSelected(Alias)
    local EntityOption = Options.EntityESPOptions
    local Selected = EntityOption and EntityOption.Value
    if not Selected then return false end
    if type(Selected) ~= "table" then return Selected == Alias end
    if Selected[Alias] == true then return true end
    return table.find(Selected, Alias) ~= nil
end

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
    ["StemsEntity"] = { Alias = "Balls", NotifyMessage = { Title = "Balls", Body = "Balls." } },
    ["NoiseModel"] = { Alias = "Noise", NotifyMessage = { Title = "Entity 'Noise' has spawned.", Body = "Dont let it touch you." } },
    ["Creak"] = { Alias = "Creak", NotifyMessage = { Title = "Entity 'Creak' has spawned.", Body = "Dont touch him." } },
    ["DronesStampede"] = { Alias = "DronesStampede", NotifyMessage = { Title = "Entity 'Drones Stampede' has spawned.", Body = "Find a hiding spot." } },
    ["TellerRig"] = { Alias = "Teller", NotifyMessage = { Title = "Entity 'Teller' has spawned.", Body = "Dont worry, hes only annoying." } },
    ["Scribbles"] = { Alias = "Scribbles", NotifyMessage = { Title = "Entity 'Scribbles' has spawned.", Body = "Find a hiding spot." } },
    ["BashMoving"] = { Alias = "Bash", NotifyMessage = { Title = "Entity 'Bash' has spawned.", Body = "Find a hiding spot." } },
    ["RushMoving"] = { Alias = "Rush", NotifyMessage = { Title = "Entity 'Rush' has spawned.", Body = "Find a hiding spot." } },
    ["AmbushMoving"] = { Alias = "Ambush", NotifyMessage = { Title = "Entity 'Ambush' has spawned.", Body = "Find a hiding spot." } },
    ["Eyes"] = { Alias = "Eyes", NotifyMessage = { Title = "Entity 'Eyes' has spawned.", Body = "Avoid looking at it." } },
    ["Lookman"] = { Alias = "Eyes", NotifyMessage = { Title = "Entity 'Eyes' has spawned.", Body = "Avoid looking at it." } },
    ["BackdoorRush"] = { Alias = "Blitz", NotifyMessage = { Title = "Entity 'Blitz' has spawned.", Body = "Find a hiding spot." } },
    ["BackdoorLookman"] = { Alias = "Lookman", NotifyMessage = { Title = "Entity 'Lookman' has spawned.", Body = "Avoid looking at its eyes." } },
    ["Groundskeeper"] = { Alias = "Groundskeeper", NotifyMessage = { Title = "Entity 'Groundskeeper' has spawned.", Body = "Avoid stepping on the grass." } },
    ["A60"] = { Alias = "A-60", NotifyMessage = { Title = "Entity 'A-60' has spawned.", Body = "Find a hiding spot." } },
    ["A120"] = { Alias = "A-120", NotifyMessage = { Title = "Entity 'A-120' has spawned.", Body = "Find a hiding spot." } },
    ["GloombatSwarm"] = { Alias = "Gloombat Swarm", NotifyMessage = { Title = "Entity 'Gloombat Swarm' has spawned.", Body = "Keep all light sources turned off." } },
    ["GlitchRush"] = { Alias = "RNIUSHCG==", NotifyMessage = { Title = "Entity 'RNIUSHCG==' has spawned.", Body = "Find a hiding spot." } },
    ["GlitchAmbush"] = { Alias = "AR0xMBUSH", NotifyMessage = { Title = "Entity 'AR0xMBUSH' has spawned.", Body = "Find a hiding spot." } },
    ["MonumentEntity"] = { Alias = "Monument", NotifyMessage = { Title = "Entity 'Monument' has spawned.", Body = "It can't move while you are looking at it." } },
    ["JeffTheKiller"] = { Alias = "Jeff the Killer", NotifyMessage = { Title = "Entity 'Jeff the Killer' has spawned.", Body = "Avoid touching him." } },
    ["CustomEntity"] = { Alias = "Custom Entity", NotifyMessage = { Title = "Entity 'Custom Entity' has spawned.", Body = "Find a hiding spot." } },
    ["FrozenAmbush"] = { Alias = "Frozen Ambush", NotifyMessage = { Title = "Entity 'Frozen Ambush' has spawned.", Body = "Find a hiding spot." } },
    ["SallyMoving"] = { Alias = "Sally", NotifyMessage = { Title = "Entity 'Sally' has spawned.", Body = "Find her horse and rop it." } },
    ["MandrakeHole"] = { Alias = "Mandrake Hole" },
    ["GloombatEggs"] = { Alias = "Gloombat Eggs" },
    ["GloombatEgg"] = { Alias = "Gloombat Eggs" },
    ["Snare"] = { Alias = "Snare" },
    ["GiggleCeiling"] = { Alias = "Giggle" },
    ["GrumbleRig"] = { Alias = "Grumble" },
    ["LiveEntityBramble"] = { Alias = "Bramble" },
    ["Figure"] = { Alias = "Figure" },
    ["FigureRig"] = { Alias = "Figure" },
    ["FigureRagdoll"] = { Alias = "Figure" },
    ["DoorFake"] = { Alias = "Dupe" },
    ["FakeDoor"] = { Alias = "Dupe" }
}

local EntityIcons = {
    ["RushMoving"] = "rbxassetid://10716032262",
    ["AmbushMoving"] = "rbxassetid://10110576663",
    ["A60"] = "rbxassetid://12571092295",
    ["A120"] = "rbxassetid://12711591665",
    ["BackdoorRush"] = "rbxassetid://16602023490",
    ["Eyes"] = "rbxassetid://10183704772",
    ["Lookman"] = "rbxassetid://10183704772",
    ["BackdoorLookman"] = "rbxassetid://16764872677",
    ["GloombatSwarm"] = "rbxassetid://79221203116470",
    ["Halt"] = "rbxassetid://11331795398",
    ["JeffTheKiller"] = "rbxassetid://94479432156278",
    ["GlitchRush"] = "rbxassetid://73859273102919",
    ["GlitchAmbush"] = "rbxassetid://88369678433359",
    ["SallyMoving"] = "rbxassetid://10840888070",
    ["MonumentEntity"] = "rbxassetid://88933556873017",
    ["Groundskeeper"] = "rbxassetid://114991380115557"
}

local EntityESPLabels = {
    JeffTheKiller = "Jeff the Killer", GiggleCeiling = "Giggle",
    Snare = "Snare", GrumbleRig = "Grumble",
    Drakobloxxer = "Drakobloxxer", Hole = "Mandrake Hole", Groundskeeper = "Groundskeeper",
    LiveEntityBramble = "Bramble", Figure = "Figure", FigureRig = "Figure", FigureRagdoll = "Figure",
    FakeDoor = "Dupe", DoorFake = "Dupe"
}

local NodeEntities = {
    Rush=true, Bash=true, Scribbles=true, DronesStampede=true, Ambush=true,
    Eyes=true, Blitz=true, Lookman=true, ["A-60"]=true, ["A-120"]=true,
    Sally=true, ["Jeff The Killer"]=true, Monument=true, ["AR0xMBUSH"]=true, ["RNIUSHCG=="]=true
}

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

local AllowedInstances = {
    Lava=true, GoldPile=true, KeyObtain=true, Drakobloxxer=true, FuseObtain=true,
    MinesGenerator=true, JeffTheKiller=true, Snare=true, FakeDoor=true, DoorFake=true, SideroomSpace=true,
    ChestBox=true, ChestBoxLocked=true, Chest_Vine=true, Locker_Small_Locked=true, Toolbox=true,
    Toolbox_Locked=true, Wardrobe=true, ["Wardrobe-FOOLS26"]=true, Toolshed=true, Toolshed_Small=true,
    Bed=true, MinesAnchor=true, Double_Bed=true, RetroWardrobe=true, Backdoor_Wardrobe=true,
    Rooms_Locker=true, Rooms_Locker_Fridge=true, Locker_Large=true, FigureRig=true, FigureRagdoll=true,
    TimerLever=true, Lever=true, Seek_Arm=true, ChandelierObstruction=true, ScaryWall=true, Ladder=true,
    CircularVent=true, Dumpster=true, SquareGrate=true, TriggerEventCollision=true, GrumbleRig=true,
    GiggleCeiling=true, MinesGateButton=true, ElectricalKeyObtain=true, LibraryHintPaper=true,
    WaterPump=true, CringlePresent=true, Wheel=true, PickupItem=true, LiveHintBook=true,
    LiveBreakerPolePickup=true, LeverForGate=true, GloomPile=true, SeekFloodline=true, Door=true,
    Green_Herb=true, Bridge=true, MouseHole=true, BananaPeel=true, NannerPeel=true, PowerupPad=true,
    IndustrialGate=true, CollisionFloor=true, ElevatorCar=true, Wax_Door=true, ThingToOpen=true,
    MovingDoor=true, StardustPickup=true, Hole=true, Groundskeeper=true, MandrakeLive=true,
    GardenGateButton=true, LotusPetalPickup=true, VineGuillotine=true, LiveEntityBramble=true, ArchivesFihTank=true,
    RiftSpawn=true, ElevatorBreaker=true, RunnerNodes=true, PathLights=true, DuckBoard=true,
    Padlock=true, EyestalkEndCutscene=true, MinecartRig=true, SeekMovingNewClone=true, Cellar=true, ArchivesPackageDeposit=true, SalvageChute=true,
    StairwellFireAlarm=true, ShoppingCart=true
}

local function TrackObject(ObjectList, Object)
    if table.find(ObjectList, Object) then return false end
    table.insert(ObjectList, Object)
    Object.Destroying:Once(function()
        local index = table.find(ObjectList, Object)
        if index then table.remove(ObjectList, index) end
        Functions.RemoveESP(Object)
    end)
    return true
end

Functions.HandleObject = function(Object)
    local Name = Object.Name

    if CurrentRooms then
        for _, Room in CurrentRooms:GetChildren() do
            if Object:IsDescendantOf(Room) then
                Object:SetAttribute("ParentRoom", tonumber(Room.Name))
                break
            end
            task.wait()
        end
    end

    if Name == "Door" and Object:IsA("Model") and Object.Parent and tonumber(Object.Parent.Name) then
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
                Instance.new("Humanoid", HighlightModel).Name = "HighlightHumanoid"
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
                    return
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

        if TrackObject(Objects.Doors, target) and Toggles.DoorESPToggle.Value then
            Functions.AddESP({
                Object = target,
                Text = "Door " .. Functions.GetDoorNumber(Object),
                Color = Options.DoorESPColor.Value,
            }, true)
        end
    elseif Name == "ChestBox" or Name == "ChestBoxLocked" then
        if TrackObject(Objects.Chests, Object) and Toggles.ChestESPToggle.Value then
            local Label = Object:GetAttribute("Locked") and "Locked Chest" or "Chest"
            Functions.AddESP({ Object = Object, Text = Label, Color = Options.ChestESPColor.Value }, true)
        end
    elseif Name == "Toolbox" or Name == "Toolbox_Locked" then
        if TrackObject(Objects.Chests, Object) and Toggles.ChestESPToggle.Value then
            local Label = Object:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox"
            Functions.AddESP({ Object = Object, Text = Label, Color = Options.ChestESPColor.Value }, true)
        end
    elseif Name == "Chest_Vine" or Name == "Toolshed_Small" or Name == "Locker_Small_Locked" or Name == "MouseHole" then
        if TrackObject(Objects.Chests, Object) and Toggles.ChestESPToggle.Value then
            Functions.AddESP({ Object = Object, Text = ChestLabels[Name], Color = Options.ChestESPColor.Value }, true)
        end
    elseif ItemNames[Name] and Object:FindFirstChild("ModulePrompt") then
        if TrackObject(Objects.Items, Object) and Toggles.ItemESPToggle.Value then
            Functions.AddESP({ Object = Object, Text = ItemNames[Name], Color = Options.ItemESPColor.Value }, Object:GetAttribute("ParentRoom") ~= nil)
        end
    elseif Name == "Green_Herb" then
        if TrackObject(Objects.Items, Object) and Toggles.ItemESPToggle.Value then
            Functions.AddESP({ Object = Object, Text = "Green Herb", Color = Options.ItemESPColor.Value }, true)
        end
    elseif Name == "GoldPile" and Object:GetAttribute("GoldValue") then
        if TrackObject(Objects.Currency, Object) and Toggles.CurrencyESPToggle.Value then
            Functions.AddESP({ Object = Object, Text = "Gold Pile [" .. Object:GetAttribute("GoldValue") .. "]", Color = Options.CurrencyESPColor.Value }, true)
        end
    elseif Name == "StardustPickup" then
        if TrackObject(Objects.Currency, Object) and Toggles.CurrencyESPToggle.Value then
            Functions.AddESP({ Object = Object, Text = "Stardust Pile", Color = Options.CurrencyESPColor.Value }, true)
        end
    elseif Name == "Ladder" then
        if TrackObject(Objects.Ladders, Object) and Toggles.LadderESPToggle.Value then
            Functions.AddESP({ Object = Object, Text = "Ladder", Color = Options.LadderESPColor.Value }, true)
        end
    elseif ObjectiveLabels[Name] then
        if TrackObject(Objects.Objectives, Object) and Toggles.ObjectiveESPToggle.Value then
            Functions.AddESP({ Object = Object, Text = ObjectiveLabels[Name], Color = Options.ObjectiveESPColor.Value }, true)
        end
    elseif HidingSpotLabels[Name] or string.find(string.lower(Name), "hidingspot") then
        if TrackObject(Objects.HidingSpots, Object) and Toggles.HidingSpotESPToggle.Value then
            local Label = HidingSpotLabels[Name] or "Hiding Spot"
            Functions.AddESP({ Object = Object, Text = Label, Color = Options.HidingSpotESPColor.Value }, true)
        end
    end
end

Functions.QueueObject = function(Object)
    if not Object or not Object.Parent then return end
    local Name = Object.Name
    local IsHidingSpot = string.find(string.lower(Name), "hidingspot") ~= nil
    local IsAllowed = IsHidingSpot
        or AllowedInstances[Name]
        or Object.ClassName == "ProximityPrompt"
        or Object.Parent == CurrentRooms
        or ItemNames[Name] ~= nil

    if IsAllowed and not table.find(Globals.ObjectQueue, Object) then
        table.insert(Globals.ObjectQueue, Object)
    end
end

-- === Обработчик спавна сущностей (1-в-1 из Abysall) ===
local RusherAliases = {
    Rush=true, Bash=true, Scribbles=true, DronesStampede=true, Ambush=true,
    Eyes=true, Lookman=true, Blitz=true, ["A-60"]=true, ["A-120"]=true,
    ["AR0xMBUSH"]=true, ["RNIUSHCG=="]=true
}

local function HandleEntitySpawn(Entity)
    if not Entity or typeof(Entity) ~= "Instance" then return end

    local Model = Entity
    if Entity:IsA("Humanoid") then Model = Entity.Parent end
    if not Model or not Model:IsA("Model") then return end

    local EntityData = Entities[Model.Name]
    if not EntityData then return end
    if Model:GetAttribute("Abysall_EntityHandled") then return end
    Model:SetAttribute("Abysall_EntityHandled", true)

    while not Model.PrimaryPart do
        for _, Child in Model:GetChildren() do
            if Child:IsA("BasePart") then Model.PrimaryPart = Child end
        end
        if not Model.PrimaryPart then task.wait() end
    end
    task.wait(0.1)

    if not Model.PrimaryPart or LocalPlayer:DistanceFromCharacter(Model.PrimaryPart.Position) >= 10000 then return end

    local Alias = EntityData.Alias
    local RealAlias = Alias

    if Model.Name ~= "GloombatSwarm" then
        if Toggles.EntityESPToggle.Value and EntityIsSelected(RealAlias) then
            if Model.Name == "MonumentEntity" then
                Functions.AddESP({ Object = Model.Top, Text = Alias, Color = Options.EntityESPColor.Value })
            else
                Functions.AddESP({ Object = Model, Text = Alias, Color = Options.EntityESPColor.Value })
            end
        end
        table.insert(Objects.Entities, Model)
    end

    Model.Destroying:Once(function()
        local index = table.find(Objects.Entities, Model)
        if index then
            table.remove(Objects.Entities, index)
        end
        Functions.RemoveESP(Model)
        if Model.Name == "MonumentEntity" and Model:FindFirstChild("Top") then
            Functions.RemoveESP(Model.Top)
        end
        local queueIndex = table.find(Globals.ObjectQueue, Model)
        if queueIndex then table.remove(Globals.ObjectQueue, queueIndex) end
    end)

    if RusherAliases[EntityData.Alias] then
        Instance.new("Humanoid", Model).Name = "HighlightHumanoid"
        local Root = Model.PrimaryPart
        if Root then Root.Transparency = 0.999 Root.Material = Enum.Material.Plastic end
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
    local EntityModel = Descendant:IsA("Humanoid") and Descendant.Parent or Descendant
    if EntityModel and EntityModel:IsA("Model") and Entities[EntityModel.Name] then
        task.defer(function() HandleEntitySpawn(Descendant) end)
    end
end)

local function UpdatePlayerESP()
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            local CharacterModel = Player.Character
            if CharacterModel and Toggles.PlayerESPToggle.Value then
                Functions.AddESP({ Object = CharacterModel, Text = Player.Name, Color = Options.PlayerESPColor.Value })
            elseif CharacterModel then
                Functions.RemoveESP(CharacterModel)
            end
        end
    end
end

local function TrackPlayer(Player)
    if Player == LocalPlayer then return end

    local CharacterConnection = Functions.ConnectSignal(Player.CharacterAdded, function(NewCharacter)
        if Toggles.PlayerESPToggle.Value then
            Functions.AddESP({ Object = NewCharacter, Text = Player.Name, Color = Options.PlayerESPColor.Value })
        end
    end)
    local DeadConnection = Functions.ConnectSignal(Player:GetAttributeChangedSignal("Alive"), function()
        if Player:GetAttribute("Alive") ~= true and Player.Character then
            Functions.RemoveESP(Player.Character)
        end
    end)
    Player.Destroying:Once(function()
        CharacterConnection:Disconnect()
        DeadConnection:Disconnect()
    end)
end

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
Toggles.DoorESPToggle:OnChanged(function(Value)
    for _, Object in ipairs(Objects.Doors) do
        if Value then
            Functions.AddESP({
                Object = Object,
                Text = "Door " .. Functions.GetDoorNumber(Object),
                Color = Options.DoorESPColor.Value,
            }, true)
        else
            Functions.RemoveESP(Object)
        end
    end
end)

Toggles.ChestESPToggle:OnChanged(function(Value)
    for _, Object in ipairs(Objects.Chests) do
        if Value then
            local Label
            if Object.Name == "ChestBox" or Object.Name == "ChestBoxLocked" then
                Label = Object:GetAttribute("Locked") and "Locked Chest" or "Chest"
            elseif Object.Name == "Toolbox" or Object.Name == "Toolbox_Locked" then
                Label = Object:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox"
            else
                Label = ChestLabels[Object.Name]
            end
            if Label then
                Functions.AddESP({ Object = Object, Text = Label, Color = Options.ChestESPColor.Value }, true)
            end
        else
            Functions.RemoveESP(Object)
        end
    end
end)

Toggles.ItemESPToggle:OnChanged(function(Value)
    for _, Object in ipairs(Objects.Items) do
        if Value then
            local Label = Object.Name == "Green_Herb" and "Green Herb" or ItemNames[Object.Name]
            if Label then Functions.AddESP({ Object = Object, Text = Label, Color = Options.ItemESPColor.Value }, true) end
        else
            Functions.RemoveESP(Object)
        end
    end
end)

Toggles.CurrencyESPToggle:OnChanged(function(Value)
    for _, Object in ipairs(Objects.Currency) do
        if Value then
            local Label = Object.Name == "GoldPile"
                and ("Gold Pile [" .. Object:GetAttribute("GoldValue") .. "]")
                or "Stardust Pile"
            Functions.AddESP({ Object = Object, Text = Label, Color = Options.CurrencyESPColor.Value }, true)
        else
            Functions.RemoveESP(Object)
        end
    end
end)

Toggles.LadderESPToggle:OnChanged(function(Value)
    for _, Object in ipairs(Objects.Ladders) do
        if Value then
            Functions.AddESP({ Object = Object, Text = "Ladder", Color = Options.LadderESPColor.Value }, true)
        else
            Functions.RemoveESP(Object)
        end
    end
end)

Toggles.ObjectiveESPToggle:OnChanged(function(Value)
    for _, Object in ipairs(Objects.Objectives) do
        if Value then
            local Label = ObjectiveLabels[Object.Name]
            if Label then Functions.AddESP({ Object = Object, Text = Label, Color = Options.ObjectiveESPColor.Value }, true) end
        else
            Functions.RemoveESP(Object)
        end
    end
end)

Toggles.HidingSpotESPToggle:OnChanged(function(Value)
    for _, Object in ipairs(Objects.HidingSpots) do
        if Value then
            local Label = HidingSpotLabels[Object.Name] or "Hiding Spot"
            Functions.AddESP({ Object = Object, Text = Label, Color = Options.HidingSpotESPColor.Value }, true)
        else
            Functions.RemoveESP(Object)
        end
    end
end)

local function UpdateEntitySelection()
    for _, Object in ipairs(Objects.Entities) do
        local Label = EntityESPLabels[Object.Name] or (Entities[Object.Name] and Entities[Object.Name].Alias)
        local ESPObject = Object.Name == "MonumentEntity" and Object:FindFirstChild("Top") or Object
        if Toggles.EntityESPToggle.Value and Label and EntityIsSelected(Label) then
            Functions.AddESP({ Object = ESPObject, Text = Label, Color = Options.EntityESPColor.Value }, NodeEntities[Label] ~= true)
        else
            Functions.RemoveESP(ESPObject)
        end
    end
end

Toggles.EntityESPToggle:OnChanged(UpdateEntitySelection)
Options.EntityESPOptions:OnChanged(UpdateEntitySelection)
Toggles.PlayerESPToggle:OnChanged(UpdatePlayerESP)
Options.DoorESPColor:OnChanged(function(Value)
    for _, Object in ipairs(Objects.Doors) do
        pcall(function()
            ESPLibrary:UpdateObjectColor(Object, Value)
        end)
    end
end)

for _, Player in ipairs(Players:GetPlayers()) do
    TrackPlayer(Player)
end
Functions.ConnectSignal(Players.PlayerAdded, function(Player)
    TrackPlayer(Player)
    if Player.Character and Toggles.PlayerESPToggle.Value then
        Functions.AddESP({ Object = Player.Character, Text = Player.Name, Color = Options.PlayerESPColor.Value })
    end
end)
UpdatePlayerESP()

local function CleanObjectList(ObjectList)
    for index = #ObjectList, 1, -1 do
        local Object = ObjectList[index]
        if not Object or not Object.Parent then
            if Object then Functions.RemoveESP(Object) end
            table.remove(ObjectList, index)
        end
    end
end

Functions.ConnectSignal(RunService.Heartbeat, function()
    CleanObjectList(Objects.Entities)
    CleanObjectList(Objects.Doors)
    CleanObjectList(Objects.Items)
    CleanObjectList(Objects.Chests)
    CleanObjectList(Objects.Currency)
    CleanObjectList(Objects.Ladders)
    CleanObjectList(Objects.Objectives)
    CleanObjectList(Objects.HidingSpots)
end)

Globals.Active.InstanceHandler = Functions.ConnectSignal(Workspace.DescendantAdded, Functions.QueueObject)
Globals.Active.QueueConnection = Functions.ConnectSignal(RunService.RenderStepped, function()
    local Object = table.remove(Globals.ObjectQueue, 1)
    if Object then Functions.HandleObject(Object) end
end)

for _, Object in Workspace:GetDescendants() do
    task.spawn(function()
        Functions.QueueObject(Object)
    end)
end

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

local function UpdateESPColor(ObjectList, Color)
    for _, Object in ipairs(ObjectList) do
        pcall(function()
            ESPLibrary:UpdateObjectColor(Object, Color)
        end)
    end
end

Options.DoorESPColor:OnChanged(function(Value) UpdateESPColor(Objects.Doors, Value) end)
Options.ChestESPColor:OnChanged(function(Value) UpdateESPColor(Objects.Chests, Value) end)
Options.ItemESPColor:OnChanged(function(Value) UpdateESPColor(Objects.Items, Value) end)
Options.CurrencyESPColor:OnChanged(function(Value) UpdateESPColor(Objects.Currency, Value) end)
Options.LadderESPColor:OnChanged(function(Value) UpdateESPColor(Objects.Ladders, Value) end)
Options.ObjectiveESPColor:OnChanged(function(Value) UpdateESPColor(Objects.Objectives, Value) end)
Options.HidingSpotESPColor:OnChanged(function(Value) UpdateESPColor(Objects.HidingSpots, Value) end)
Options.EntityESPColor:OnChanged(function(Value)
    for _, Object in ipairs(Objects.Entities) do
        local ESPObject = Object.Name == "MonumentEntity" and Object:FindFirstChild("Top") or Object
        pcall(function() ESPLibrary:UpdateObjectColor(ESPObject, Value) end)
    end
end)

-- === Очистка при Unload ===
Library:OnUnload(function()
    for _, ObjectList in ipairs({
        Objects.Entities, Objects.Doors, Objects.Items, Objects.Chests,
        Objects.Currency, Objects.Ladders, Objects.Objectives, Objects.HidingSpots,
    }) do
        for _, Object in ipairs(ObjectList) do
            Functions.RemoveESP(Object)
        end
    end
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
