-- tokagod Main (рефактор: clean architecture + proper cleanup)

local tokagod = getgenv().tokagod
local Globals = {
    Connections = {},
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
local Floor = ReplicatedStorage:WaitForChild("GameData"):WaitForChild("Floor").Value
local LiveModifiers = ReplicatedStorage:FindFirstChild("LiveModifiers")
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemotesFolder")
    or ReplicatedStorage:FindFirstChild("EntityInfo")
    or ReplicatedStorage:FindFirstChild("Bricks")

local Character, Humanoid, RootPart

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
    Title = "????",
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
    Archives  = Window:AddTab("New - Archives", "rbxassetid://104508835882225"),
    Stairwell = Window:AddTab("New - Stairwell", "rbxassetid://80017304328364"),
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
-- SPEED LOGIC
-- ============================================

Functions.IsCrouching = function()
    if not Character then return false end
    if Floor == "Fools" or Floor == "OldHotel" then
        return Character:GetAttribute("Crouching") == true
    end
    local CollisionPart = Character:FindFirstChild("CollisionPart") or Character:FindFirstChild("Collision")
    return CollisionPart and CollisionPart.CollisionGroup == "PlayerCrouching" or false
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

local function UpdateSpeed()
    if Humanoid then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + (Toggles.SpeedBoostToggle.Value and Options.SpeedBoost.Value or 0)
    end
    Functions.FireRemote("Crouch", false, true)
end

Toggles.SpeedBoostToggle:OnChanged(function(Value)
    UpdateSpeed()
    Functions.Notify({
        Title = "Speed Boost",
        Body = Value and "Включено" or "Выключено"
    })
end)

Options.SpeedBoost:OnChanged(function()
    if Toggles.SpeedBoostToggle.Value then
        UpdateSpeed()
    end
end)

Functions.ConnectSignal(RunService.Heartbeat, function()
    if Toggles.SpeedBoostToggle.Value and Humanoid then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + Options.SpeedBoost.Value
    end
end)

-- ============================================
-- FLY
-- ============================================

local function StartFly()
    if not Character or not RootPart or not Humanoid then return end
    if Globals.Active.Fly then return end

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVelocity.P = 1250
    bodyVelocity.Parent = RootPart

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.P = 1250
    bodyGyro.CFrame = RootPart.CFrame
    bodyGyro.Parent = RootPart

    table.insert(Globals.BodyObjects, bodyVelocity)
    table.insert(Globals.BodyObjects, bodyGyro)

    Humanoid.PlatformStand = true
    Globals.Active.Fly = true

    local Camera = Workspace.CurrentCamera
    local conn = Functions.ConnectSignal(RunService.RenderStepped, function()
        if not RootPart or not Humanoid or not Globals.Active.Fly then return end

        local direction = Vector3.zero
        local cam = Camera.CFrame

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.new(0, 1, 0) end

        if direction.Magnitude > 0 then direction = direction.Unit end

        bodyVelocity.Velocity = direction * Options.FlySpeed.Value
        bodyGyro.CFrame = cam
    end)

    Globals.Active.FlyConnection = conn
end

local function StopFly()
    if Globals.Active.FlyConnection then
        Globals.Active.FlyConnection:Disconnect()
        Globals.Active.FlyConnection = nil
    end
    if Humanoid then
        Humanoid.PlatformStand = false
    end
    Globals.Active.Fly = false
end

Toggles.FlyToggle:OnChanged(function(Value)
    if Value then StartFly() else StopFly() end
end)

-- ============================================
-- ESP SYSTEM (перенесено из Abysall → вкладка Visuals)
-- ============================================

local ESP = {
    Added = {},
    LastScan = 0,
    LastPlayerScan = 0,
    ScanInterval = 0.5,
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

local EntityAliases = {
    ["StemsEntity"]="Balls",["NoiseModel"]="Noise",["Creak"]="Creak",
    ["DronesStampede"]="DronesStampede",["TellerRig"]="Teller",
    ["Scribbles"]="Scribbles",["BashMoving"]="Bash",["RushMoving"]="Rush",
    ["AmbushMoving"]="Ambush",["Eyes"]="Eyes",["Lookman"]="Eyes",
    ["BackdoorRush"]="Blitz",["BackdoorLookman"]="Lookman",
    ["Groundskeeper"]="Groundskeeper",["A60"]="A-60",["A120"]="A-120",
    ["GloombatSwarm"]="Gloombat Swarm",["GlitchRush"]="RNIUSHCG==",
    ["GlitchAmbush"]="AR0xMBUSH",["MonumentEntity"]="Monument",
    ["JeffTheKiller"]="Jeff the Killer",["CustomEntity"]="Custom Entity",
    ["FrozenAmbush"]="Frozen Ambush",["SallyMoving"]="Sally",
    ["Snare"]="Snare",["GiggleCeiling"]="Giggle",["GrumbleRig"]="Grumble",
    ["LiveEntityBramble"]="Bramble",["Figure"]="Figure",["FigureRig"]="Figure",
    ["FigureRagdoll"]="Figure",["DoorFake"]="Dupe",["FakeDoor"]="Dupe"
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

-- === Классификатор объекта ===
local function ClassifyObject(Object)
    local Name = Object.Name

    if Name == "Door" and Object:IsA("Model") and Object.Parent and tonumber(Object.Parent.Name) then
        return "Doors", "Door " .. tostring(tonumber(Object.Parent.Name) + 1)
    end

    if ObjectiveLabels[Name] then
        return "Objectives", ObjectiveLabels[Name]
    end

    if HidingSpotLabels[Name] then
        return "HidingSpots", HidingSpotLabels[Name]
    end
    if typeof(Name) == "string" and string.find(string.lower(Name), "hidingspot") then
        return "HidingSpots", "Hiding Spot"
    end

    if ChestLabels[Name] then
        return "Chests", ChestLabels[Name]
    end

    if ItemNames[Name] and Object:FindFirstChild("ModulePrompt") then
        return "Items", ItemNames[Name]
    end
    if Name == "Green_Herb" then
        return "Items", "Green Herb"
    end

    if Name == "GoldPile" and Object:GetAttribute("GoldValue") then
        return "Currency", "Gold Pile [" .. Object:GetAttribute("GoldValue") .. "]"
    end
    if Name == "StardustPickup" then
        return "Currency", "Stardust Pile"
    end

    if Name == "Ladder" then
        return "Ladders", "Ladder"
    end

    if EntityAliases[Name] then
        return "Entities", EntityAliases[Name]
    end

    return nil, nil
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

    for _, Object in ipairs(Workspace:GetDescendants()) do
        local category, label = ClassifyObject(Object)
        if category then
            seen[Object] = true

            local toggleName = ESPToggleMap[category]
            local colorName  = ESPColorMap[category]
            local isOn = Toggles[toggleName] and Toggles[toggleName].Value

            if isOn and not ESP.Added[Object] then
                local ok = pcall(function()
                    ESPLibrary:AddESP({
                        Object = Object,
                        Text = label,
                        Color = Options[colorName].Value,
                    })
                end)
                if ok then
                    ESP.Added[Object] = category
                end
            elseif not isOn and ESP.Added[Object] then
                pcall(function() ESPLibrary:RemoveESP(Object) end)
                ESP.Added[Object] = nil
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
Groupboxes.Visuals_ESP:AddToggle("EntityESPToggle",     { Text = "Entities", Default = false })

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
                part.CanCollide = false
            end
        end

        Functions.FireRemote("Crouch", true, true)

        if Toggles.PositionSpoof.Value and RootPart and Humanoid then
            RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
            Humanoid.HipHeight = 0.05
        end
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
                part.CanCollide = true
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
-- POSITION SPOOF
-- ============================================

local function ApplyPositionSpoof(enable)
    if not RootPart or not Humanoid or Floor == "Fools" or Floor == "OldHotel" then return end

    if enable then
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
        Humanoid.HipHeight = 0.05
    else
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, 2.346, 0)
        Humanoid.HipHeight = 2.396
    end

    Functions.FireRemote("Crouch", enable, true)
end

Toggles.PositionSpoof:OnChanged(function(Value)
    ApplyPositionSpoof(Value)
end)

Functions.ConnectSignal(RunService.RenderStepped, function()
    if Toggles.PositionSpoof.Value and RootPart and Humanoid then
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
        Humanoid.HipHeight = 0.05
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

Toggles.VelocityManipulationToggle:OnChanged(UpdateVelocityManipulation)
if Options.VelocityManipulationMode then
    Options.VelocityManipulationMode:OnChanged(UpdateVelocityManipulation)
end

Functions.ConnectSignal(RunService.RenderStepped, UpdateVelocityManipulation)

-- ============================================
-- CHARACTER HANDLER
-- ============================================

local function OnCharacterAdded(newCharacter)
    Character = newCharacter
    Humanoid = newCharacter:WaitForChild("Humanoid", 10)
    RootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)

    if not Humanoid or not RootPart then return end

    if Toggles.SpeedBoostToggle.Value then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + Options.SpeedBoost.Value
    end

    if Toggles.FlyToggle.Value then
        task.wait(0.5)
        StartFly()
    end

    if Toggles.NoclipToggle.Value then
        StartNoclip()
    end

    Functions.ConnectSignal(Character:GetAttributeChangedSignal("Climbing"), function()
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
        StopFly()
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
    StopFly()
    StopNoclip()
    Functions.DisconnectAll()
    Functions.CleanupBodyObjects()
    pcall(function() Toggles.SpeedBoostToggle:SetValue(false) end)
    pcall(function() Toggles.FlyToggle:SetValue(false) end)
    pcall(function() Toggles.NoclipToggle:SetValue(false) end)

    if Humanoid then
        pcall(function() Humanoid.WalkSpeed = 15 end)
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
