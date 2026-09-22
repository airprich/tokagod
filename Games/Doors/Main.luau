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
-- ESP SYSTEM (перенесено из Abysall → вкладка Visuals)
-- ============================================

-- Справочники
local EntityIcons = {
    ["RushMoving"]      = "rbxassetid://10716032262",
    ["AmbushMoving"]    = "rbxassetid://10110576663",
    ["A60"]             = "rbxassetid://12571092295",
    ["A120"]            = "rbxassetid://12711591665",
    ["BackdoorRush"]    = "rbxassetid://16602023490",
    ["Eyes"]            = "rbxassetid://10183704772",
    ["Lookman"]         = "rbxassetid://10183704772",
    ["BackdoorLookman"] = "rbxassetid://16764872677",
    ["GloombatSwarm"]   = "rbxassetid://79221203116470",
    ["Halt"]            = "rbxassetid://11331795398",
    ["JeffTheKiller"]   = "rbxassetid://94479432156278",
    ["GlitchRush"]      = "rbxassetid://73859273102919",
    ["GlitchAmbush"]    = "rbxassetid://88369678433359",
    ["SallyMoving"]     = "rbxassetid://10840888070",
    ["MonumentEntity"]  = "rbxassetid://88933556873017",
    ["Groundskeeper"]   = "rbxassetid://114991380115557"
}

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
    ["StemsEntity"]={Alias="Balls"},["NoiseModel"]={Alias="Noise"},["Creak"]={Alias="Creak"},
    ["DronesStampede"]={Alias="DronesStampede"},["TellerRig"]={Alias="Teller"},
    ["Scribbles"]={Alias="Scribbles"},["BashMoving"]={Alias="Bash"},["RushMoving"]={Alias="Rush"},
    ["AmbushMoving"]={Alias="Ambush"},["Eyes"]={Alias="Eyes"},["Lookman"]={Alias="Eyes"},
    ["BackdoorRush"]={Alias="Blitz"},["BackdoorLookman"]={Alias="Lookman"},
    ["Groundskeeper"]={Alias="Groundskeeper"},["A60"]={Alias="A-60"},["A120"]={Alias="A-120"},
    ["GloombatSwarm"]={Alias="Gloombat Swarm"},["GlitchRush"]={Alias="RNIUSHCG=="},
    ["GlitchAmbush"]={Alias="AR0xMBUSH"},["MonumentEntity"]={Alias="Monument"},
    ["JeffTheKiller"]={Alias="Jeff the Killer"},["CustomEntity"]={Alias="Custom Entity"},
    ["FrozenAmbush"]={Alias="Frozen Ambush"},["SallyMoving"]={Alias="Sally"}
}

local HidingSpotLabels = {
    Wardrobe="Closet",["Backdoor_Wardrobe"]="Closet",Toolshed="Closet",
    RetroWardrobe="Closet",["Wardrobe-FOOLS26"]="Closet",Locker_Large="Locker",
    Rooms_Locker="Hiding_Spot",Rooms_Locker_Fridge="Locker",Bed="Bed",
    Double_Bed="Double Bed",CircularVent="Vent",Dumpster="Dumpster"
}
local ChestLabels = {
    Chest_Vine="Vine Chest",Toolshed_Small="Toolshed",
    Locker_Small_Locked="Locked Item Locker",MouseHole="Mouse"
}
local EntityESPLabels = {
    JeffTheKiller="Jeff the Killer",GiggleCeiling="Giggle",Snare="Snare",
    GrumbleRig="Grumble",Drakobloxxer="Drakobloxxer",Hole="Mandrake Hole",
    Groundskeeper="Groundskeeper",LiveEntityBramble="Bramble",
    Figure="Figure",FigureRig="Figure",FigureRagdoll="Figure",
    FakeDoor="Dupe",DoorFake="Dupe"
}
local NodeEntities = {
    Rush=true,Bash=true,Scribbles=true,DronesStampede=true,Ambush=true,Eyes=true,
    Blitz=true,Lookman=true,["A-60"]=true,["A-120"]=true,Sally=true,
    ["Jeff The Killer"]=true,Monument=true,["AR0xMBUSH"]=true,["RNIUSHCG=="]=true
}

local Objects = {
    Prompts={},Objectives={},Doors={},HidingSpots={},Entities={},Items={},
    Chests={},Currency={},Ladders={},Obstructions={},EventTriggers={}
}

-- === ESP функции ===
Functions.AddESP = function(ESPOptions, RoomBased)
    local Object = ESPOptions.Object
    if table.find(Globals.ESPBlacklist, Object) then return end

    if RoomBased then
        local CurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
        local ObjectRoom = tonumber(Object:GetAttribute("ParentRoom"))
        if ObjectRoom == CurrentRoom or (table.find(Objects.Doors, Object) and ObjectRoom == CurrentRoom + 1) then
            ESPLibrary:AddESP(ESPOptions)
        end
        local RoomConn = LocalPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(function()
            if ESPLibrary.ColorTable[Object] then
                ESPOptions.Color = ESPLibrary.ColorTable[Object]
            end
            local NewCurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
            local ObjRoom = tonumber(Object:GetAttribute("ParentRoom"))
            if ObjRoom == NewCurrentRoom or (table.find(Objects.Doors, Object) and ObjRoom == NewCurrentRoom + 1) then
                ESPLibrary:AddESP(ESPOptions)
            else
                ESPLibrary:RemoveESP(Object)
            end
        end)
        table.insert(Globals.Connections, RoomConn)
        Globals.ESPConnections[Object] = RoomConn
        Object.Destroying:Once(function()
            RoomConn:Disconnect()
            ESPLibrary:RemoveESP(Object)
            local Pos = table.find(Globals.Connections, RoomConn)
            if Pos then table.remove(Globals.Connections, Pos) end
        end)
    else
        ESPLibrary:AddESP(ESPOptions)
    end
end

Functions.RemoveESP = function(Object)
    local Conn = Globals.ESPConnections[Object]
    if Conn then
        Conn:Disconnect()
        Globals.ESPConnections[Object] = nil
        local Pos = table.find(Globals.Connections, Conn)
        if Pos then table.remove(Globals.Connections, Pos) end
    end
    ESPLibrary:RemoveESP(Object)
end

Functions.BlacklistESP = function(Object)
    table.insert(Globals.ESPBlacklist, Object)
end

Functions.GetDoorNumber = function(Object)
    local DoorNumber = tonumber(Object.Parent.Name) or tonumber(Object.Parent.Parent.Name)
    if DoorNumber then DoorNumber = DoorNumber + 1 end
    if Floor == "Mines" then DoorNumber = DoorNumber + 100 end
    if Floor == "Backdoor" then DoorNumber = DoorNumber - 50 end
    return tostring(DoorNumber)
end

-- === Вкладка Visuals: ESP группы ===
Groupboxes.Visuals_ESP          = Tabs.Visuals:AddLeftGroupbox("ESP")
Groupboxes.Visuals_ESP_Settings = Tabs.Visuals:AddRightGroupbox("ESP Settings")

Groupboxes.Visuals_ESP:AddToggle("ObjectiveESPToggle", { Text = "Objectives", Default = false })
Groupboxes.Visuals_ESP:AddToggle("DoorESPToggle",       { Text = "Doors", Default = false })
Groupboxes.Visuals_ESP:AddToggle("HidingSpotESPToggle", { Text = "Hiding Spots", Default = false })
Groupboxes.Visuals_ESP:AddToggle("PlayerESPToggle",     { Text = "Players", Default = false })
Groupboxes.Visuals_ESP:AddToggle("ChestESPToggle",      { Text = "Chests", Default = false })
Groupboxes.Visuals_ESP:AddToggle("ItemESPToggle",       { Text = "Items (Item ESP)", Default = false })
Groupboxes.Visuals_ESP:AddToggle("CurrencyESPToggle",   { Text = "Currency", Default = false })
Groupboxes.Visuals_ESP:AddToggle("LadderESPToggle",     { Text = "Ladders", Default = false })
Groupboxes.Visuals_ESP:AddDivider()
Groupboxes.Visuals_ESP:AddDropdown("EntityESPOptions", {
    Text = "Entity List",
    Values = { "Rush","Bash","Scribbles","Teller","DronesStampede","Creak","Noise","Balls","Ambush","Eyes","Dupe","Figure","Blitz","Lookman","Snare","Giggle","Gloombat Eggs","Grumble","A-60","A-120","Sally","Jeff the Killer","Groundskeeper","Mandrake Hole","Monument","Bramble","AR0xMBUSH","RNIUSHCG==" },
    Multi = true, AllowNull = true
})
Groupboxes.Visuals_ESP:AddToggle("EntityESPToggle", { Text = "Entities", Default = false })

Toggles.ObjectiveESPToggle:AddColorPicker("ObjectiveESPColor", { Text = "Objectives", Default = Color3.fromRGB(0,255,0), Transparency = 0 })
Toggles.DoorESPToggle:AddColorPicker("DoorESPColor",           { Text = "Doors", Default = Color3.fromRGB(0,200,255), Transparency = 0 })
Toggles.HidingSpotESPToggle:AddColorPicker("HidingSpotESPColor",{ Text = "Hiding Spots", Default = Color3.fromRGB(255,170,0), Transparency = 0 })
Toggles.PlayerESPToggle:AddColorPicker("PlayerESPColor",       { Text = "Players", Default = Color3.fromRGB(255,255,255), Transparency = 0 })
Toggles.ChestESPToggle:AddColorPicker("ChestESPColor",         { Text = "Chests", Default = Color3.fromRGB(255,255,0), Transparency = 0 })
Toggles.ItemESPToggle:AddColorPicker("ItemESPColor",           { Text = "Items", Default = Color3.fromRGB(170,0,255), Transparency = 0 })
Toggles.CurrencyESPToggle:AddColorPicker("CurrencyESPColor",   { Text = "Currency", Default = Color3.fromRGB(255,255,0), Transparency = 0 })
Toggles.LadderESPToggle:AddColorPicker("LadderESPColor",       { Text = "Ladders", Default = Color3.fromRGB(255,255,255), Transparency = 0 })
Toggles.EntityESPToggle:AddColorPicker("EntityESPColor",       { Text = "Entities", Default = Color3.fromRGB(255,0,0), Transparency = 0 })

-- === Настройки ESP ===
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

-- === Логика ESP-тогглов ===
Toggles.DoorESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Doors do
        if Value then Functions.AddESP({ Object=Object, Text="Door "..Functions.GetDoorNumber(Object), Color=Options.DoorESPColor.Value }, true)
        else Functions.RemoveESP(Object) end
    end
end)
Options.DoorESPColor:OnChanged(function(Value)
    for _, Object in Objects.Doors do ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.HidingSpotESPToggle:OnChanged(function(Value)
    for _, Object in Objects.HidingSpots do
        local Label = HidingSpotLabels[Object.Name]
        if Value and Label then Functions.AddESP({ Object=Object, Text=Label, Color=Options.HidingSpotESPColor.Value }, true)
        elseif not Value then Functions.RemoveESP(Object) end
    end
end)
Options.HidingSpotESPColor:OnChanged(function(Value)
    for _, Object in Objects.HidingSpots do ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.PlayerESPToggle:OnChanged(function(Value)
    task.wait()
    for _, Player in Players:GetPlayers() do
        if Player.Character and Player ~= LocalPlayer then
            if Value and Player:GetAttribute("Alive") == true then
                Functions.AddESP({ Object=Player.Character, Text=Player.Name, Color=Options.PlayerESPColor.Value })
            else
                Functions.RemoveESP(Player.Character)
            end
        end
    end
end)
Options.PlayerESPColor:OnChanged(function(Value)
    for _, Player in Players:GetPlayers() do
        if Player.Character and Player ~= LocalPlayer then
            ESPLibrary:UpdateObjectColor(Player.Character, Value)
        end
    end
end)

Toggles.ChestESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Chests do
        if Value then
            local Label
            if Object.Name == "ChestBox" or Object.Name == "ChestBoxLocked" then
                Label = Object:GetAttribute("Locked") and "Locked Chest" or "Chest"
            elseif Object.Name == "Toolbox" or Object.Name == "Toolbox_Locked" then
                Label = Object:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox"
            elseif ChestLabels[Object.Name] then
                Label = ChestLabels[Object.Name]
            end
            if Label then Functions.AddESP({ Object=Object, Text=Label, Color=Options.ChestESPColor.Value }, true) end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.ChestESPColor:OnChanged(function(Value)
    for _, Object in Objects.Chests do ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.ItemESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Items do
        if Value then
            local Label = ItemNames[Object.Name] or (Object.Name == "Green_Herb" and "Green Herb")
            if Label then
                Functions.AddESP({ Object=Object, Text=Label, Color=Options.ItemESPColor.Value }, Object:GetAttribute("ParentRoom") ~= nil)
            end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.ItemESPColor:OnChanged(function(Value)
    for _, Object in Objects.Items do ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.CurrencyESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Currency do
        if Value then
            local Label
            if Object.Name == "GoldPile" and Object:GetAttribute("GoldValue") then
                Label = "Gold Pile ["..Object:GetAttribute("GoldValue").."]"
            elseif Object.Name == "StardustPickup" then
                Label = "Stardust Pile"
            end
            if Label then Functions.AddESP({ Object=Object, Text=Label, Color=Options.CurrencyESPColor.Value }, true) end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.CurrencyESPColor:OnChanged(function(Value)
    for _, Object in Objects.Currency do ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.LadderESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Ladders do
        if Value then Functions.AddESP({ Object=Object, Text="Ladder", Color=Options.LadderESPColor.Value }, true)
        else Functions.RemoveESP(Object) end
    end
end)
Options.LadderESPColor:OnChanged(function(Value)
    for _, Object in Objects.Ladders do ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.ObjectiveESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Objectives do
        if Value then
            local Label = ({
                KeyObtain="Door Key", ElectricalKeyObtain="Electrical Key",
                MinesGenerator="Generator", FuseObtain="Generator Fuse",
                LiveHintBook="Hint Book", LiveBreakerPolePickup="Fuse Breaker",
                LibraryHintPaper="Hint Paper", PickupItem="Hint Paper",
                CringlePresent="Present", LeverForGate="Gate Lever",
                MinesGateButton="Gate Button", GardenGateButton="Gate Button",
                Cellar="Cellar", ArchivesFihTank="Fih Tank",
                ArchivesPackageDeposit="Package Deposit", SalvageChute="Package Deposit",
                ShoppingCart="Shopping Cart"
            })[Object.Name]
            if Object.Name == "TimerLever" then
                Label = "Time Lever [+"..Object:GetAttribute("AddTime").."s]"
            end
            if Label then
                Functions.AddESP({ Object=Object, Text=Label, Color=Options.ObjectiveESPColor.Value }, true)
            end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.ObjectiveESPColor:OnChanged(function(Value)
    for _, Object in Objects.Objectives do ESPLibrary:UpdateObjectColor(Object, Value) end
end)

Toggles.EntityESPToggle:OnChanged(function(Value)
    for _, Object in Objects.Entities do
        if Value then
            local Label = EntityESPLabels[Object.Name]
            if not Label and Entities[Object.Name] then Label = Entities[Object.Name].Alias end
            if Label and Options.EntityESPOptions.Value[Label] then
                Functions.AddESP({ Object=Object, Text=Label, Color=Options.EntityESPColor.Value }, NodeEntities[Label] ~= true)
            else
                Functions.RemoveESP(Object)
            end
        else
            Functions.RemoveESP(Object)
        end
    end
end)

Options.EntityESPOptions:OnChanged(function()
    for _, Object in Objects.Entities do
        if Toggles.EntityESPToggle.Value then
            local Label = EntityESPLabels[Object.Name]
            if not Label and Entities[Object.Name] then Label = Entities[Object.Name].Alias end
            if Label and Options.EntityESPOptions.Value[Label] then
                Functions.AddESP({ Object=Object, Text=Label, Color=Options.EntityESPColor.Value }, NodeEntities[Label] ~= true)
            else
                Functions.RemoveESP(Object)
            end
        else
            Functions.RemoveESP(Object)
        end
    end
end)
Options.EntityESPColor:OnChanged(function(Value)
    for _, Object in Objects.Entities do ESPLibrary:UpdateObjectColor(Object, Value) end
end)

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

-- === Обработчик объектов для ESP (перенесено) ===
local AllowedInstances = {
    Lava=true, GoldPile=true, KeyObtain=true, FuseObtain=true,
    MinesGenerator=true, JeffTheKiller=true, Snare=true, FakeDoor=true, DoorFake=true,
    ChestBox=true, ChestBoxLocked=true, Chest_Vine=true, Locker_Small_Locked=true, Toolbox=true,
    Toolbox_Locked=true, Wardrobe=true, ["Wardrobe-FOOLS26"]=true, Toolshed=true, Toolshed_Small=true,
    Bed=true, MinesAnchor=true, Double_Bed=true, RetroWardrobe=true, Backdoor_Wardrobe=true,
    Rooms_Locker=true, Rooms_Locker_Fridge=true, Locker_Large=true, FigureRig=true, FigureRagdoll=true,
    TimerLever=true, Lever=true, ScaryWall=true, Ladder=true,
    CircularVent=true, Dumpster=true, SquareGrate=true, GrumbleRig=true,
    GiggleCeiling=true, MinesGateButton=true, ElectricalKeyObtain=true, LibraryHintPaper=true,
    WaterPump=true, CringlePresent=true, Wheel=true, PickupItem=true, LiveHintBook=true,
    LiveBreakerPolePickup=true, LeverForGate=true, GloomPile=true, Door=true,
    Green_Herb=true, MouseHole=true, StardustPickup=true, Hole=true, Groundskeeper=true,
    MandrakeLive=true, GardenGateButton=true, LotusPetalPickup=true, VineGuillotine=true,
    LiveEntityBramble=true, ArchivesFihTank=true, Cellar=true, ArchivesPackageDeposit=true,
    SalvageChute=true, ShoppingCart=true, BananaPeel=true
}

local function HandleESPObject(Object)
    local Name = Object.Name

    if Name == "KeyObtain" or Name == "ElectricalKeyObtain" or Name == "LiveHintBook"
       or Name == "LiveBreakerPolePickup" or Name == "LibraryHintPaper" or Name == "PickupItem"
       or Name == "CringlePresent" or Name == "LeverForGate" or Name == "Cellar"
       or Name == "ArchivesFihTank" or Name == "ArchivesPackageDeposit"
       or Name == "SalvageChute" or Name == "ShoppingCart" then
        if Toggles.ObjectiveESPToggle.Value then
            local Label = ItemNames[Name] or Name
            local ObjectiveLabels = {
                KeyObtain="Door Key",ElectricalKeyObtain="Electrical Key",
                LiveHintBook="Hint Book",LiveBreakerPolePickup="Fuse Breaker",
                LibraryHintPaper="Hint Paper",PickupItem="Hint Paper",
                CringlePresent="Present",LeverForGate="Gate Lever",
                Cellar="Cellar",ArchivesFihTank="Fih Tank",
                ArchivesPackageDeposit="Package Deposit",SalvageChute="Package Deposit",
                ShoppingCart="Shopping Cart"
            }
            Label = ObjectiveLabels[Name] or Label
            Functions.AddESP({ Object=Object, Text=Label, Color=Options.ObjectiveESPColor.Value }, true)
        end
        table.insert(Objects.Objectives, Object)

    elseif Name == "MinesAnchor" then
        if Toggles.ObjectiveESPToggle.Value then
            Functions.AddESP({ Object=Object, Text="Anchor ["..Object:WaitForChild("Sign").TextLabel.Text.."]", Color=Options.ObjectiveESPColor.Value }, true)
        end
        table.insert(Objects.Objectives, Object)

    elseif Name == "WaterPump" then
        if Toggles.ObjectiveESPToggle.Value and Object:FindFirstChild("Wheel") then
            Functions.AddESP({ Object=Object.Wheel, Text="Water Pump", Color=Options.ObjectiveESPColor.Value }, true)
        end
        table.insert(Objects.Objectives, Object)

    elseif Name == "MinesGenerator" then
        if Toggles.ObjectiveESPToggle.Value then
            Functions.AddESP({ Object=Object, Text="Generator", Color=Options.ObjectiveESPColor.Value }, true)
        end
        table.insert(Objects.Objectives, Object)

    elseif Name == "FuseObtain" then
        if Toggles.ObjectiveESPToggle.Value then
            Functions.AddESP({ Object=Object, Text="Generator Fuse", Color=Options.ObjectiveESPColor.Value }, true)
        end
        table.insert(Objects.Objectives, Object)

    elseif Name == "MinesGateButton" or Name == "GardenGateButton" then
        if Toggles.ObjectiveESPToggle.Value then
            Functions.AddESP({ Object=Object, Text="Gate Button", Color=Options.ObjectiveESPColor.Value }, true)
        end
        table.insert(Objects.Objectives, Object)

    elseif Name == "VineGuillotine" then
        if Toggles.ObjectiveESPToggle.Value and Object:FindFirstChild("Lever") then
            Functions.AddESP({ Object=Object.Lever, Text="Vine Lever", Color=Options.ObjectiveESPColor.Value }, true)
        end
        table.insert(Objects.Objectives, Object)

    elseif Name == "Ladder" then
        if Toggles.LadderESPToggle.Value then
            Functions.AddESP({ Object=Object, Text="Ladder", Color=Options.LadderESPColor.Value }, true)
        end
        table.insert(Objects.Ladders, Object)

    elseif Name == "Door" and Object.Parent and tonumber(Object.Parent.Name) then
        local HP
        if Object:FindFirstChild("Door") then
            local Root = Object.Door
            HP = Instance.new("Part")
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
            HP.Parent = Object
            table.insert(Objects.Doors, HP)
            if Toggles.DoorESPToggle.Value then
                Functions.AddESP({ Object=HP, Text="Door "..Functions.GetDoorNumber(Object), Color=Options.DoorESPColor.Value }, true)
            end
        end

    elseif HidingSpotLabels[Name] or (typeof(Name) == "string" and string.find(string.lower(Name), "hidingspot")) then
        local Label = HidingSpotLabels[Name] or "Hiding Spot"
        if Toggles.HidingSpotESPToggle.Value then
            Functions.AddESP({ Object=Object, Text=Label, Color=Options.HidingSpotESPColor.Value }, true)
        end
        table.insert(Objects.HidingSpots, Object)

    elseif Name == "ChestBox" or Name == "ChestBoxLocked" or Name == "Toolbox"
        or Name == "Toolbox_Locked" or Name == "Chest_Vine" or Name == "Toolshed_Small"
        or Name == "Locker_Small_Locked" or Name == "MouseHole" then
        if Toggles.ChestESPToggle.Value then
            local Label
            if Name == "ChestBox" or Name == "ChestBoxLocked" then
                Label = Object:GetAttribute("Locked") and "Locked Chest" or "Chest"
            elseif Name == "Toolbox" or Name == "Toolbox_Locked" then
                Label = Object:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox"
            else
                Label = ChestLabels[Name]
            end
            if Label then
                Functions.AddESP({ Object=Object, Text=Label, Color=Options.ChestESPColor.Value }, true)
            end
        end
        table.insert(Objects.Chests, Object)

    elseif ItemNames[Name] and Object:FindFirstChild("ModulePrompt") then
        if Toggles.ItemESPToggle.Value then
            Functions.AddESP({ Object=Object, Text=ItemNames[Name], Color=Options.ItemESPColor.Value }, Object:GetAttribute("ParentRoom") ~= nil)
        end
        table.insert(Objects.Items, Object)

    elseif Name == "Green_Herb" then
        if Toggles.ItemESPToggle.Value then
            Functions.AddESP({ Object=Object, Text="Green Herb", Color=Options.ItemESPColor.Value }, true)
        end
        table.insert(Objects.Items, Object)

    elseif Name == "GoldPile" and Object:GetAttribute("GoldValue") then
        if Toggles.CurrencyESPToggle.Value then
            Functions.AddESP({ Object=Object, Text="Gold Pile ["..Object:GetAttribute("GoldValue").."]", Color=Options.CurrencyESPColor.Value }, true)
        end
        table.insert(Objects.Currency, Object)

    elseif Name == "StardustPickup" then
        if Toggles.CurrencyESPToggle.Value then
            Functions.AddESP({ Object=Object, Text="Stardust Pile", Color=Options.CurrencyESPColor.Value }, true)
        end
        table.insert(Objects.Currency, Object)

    elseif Entities[Name] then
        if Toggles.EntityESPToggle.Value then
            local Label = EntityESPLabels[Name]
            if not Label and Entities[Name] then Label = Entities[Name].Alias end
            if Label and Options.EntityESPOptions.Value[Label] then
                Functions.AddESP({ Object=Object, Text=Label, Color=Options.EntityESPColor.Value }, NodeEntities[Label] ~= true)
            end
        end
        table.insert(Objects.Entities, Object)

    elseif Name == "Snare" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Snare"] then
            Functions.AddESP({ Object=Object, Text="Snare", Color=Options.EntityESPColor.Value }, true)
        end
        table.insert(Objects.Entities, Object)

    elseif Name == "GiggleCeiling" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Giggle"] then
            Functions.AddESP({ Object=Object, Text="Giggle", Color=Options.EntityESPColor.Value }, true)
        end
        table.insert(Objects.Entities, Object)

    elseif Name == "GrumbleRig" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Grumble"] then
            Functions.AddESP({ Object=Object, Text="Grumble", Color=Options.EntityESPColor.Value }, true)
        end
        table.insert(Objects.Entities, Object)

    elseif Name == "LiveEntityBramble" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Bramble"] then
            Functions.AddESP({ Object=Object, Text="Bramble", Color=Options.EntityESPColor.Value }, true)
        end
        table.insert(Objects.Entities, Object)

    elseif Name == "Groundskeeper" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Groundskeeper"] then
            Functions.AddESP({ Object=Object, Text="Groundskeeper", Color=Options.EntityESPColor.Value }, true)
        end
        table.insert(Objects.Entities, Object)

    elseif Name == "Figure" or Name == "FigureRig" or Name == "FigureRagdoll" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Figure"] then
            Functions.AddESP({ Object=Object, Text="Figure", Color=Options.EntityESPColor.Value }, true)
        end
        table.insert(Objects.Entities, Object)

    elseif Name == "DoorFake" or Name == "FakeDoor" then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Dupe"] then
            Functions.AddESP({ Object=Object, Text="Dupe", Color=Options.EntityESPColor.Value }, true)
        end
        table.insert(Objects.Entities, Object)

    elseif Name == "MandrakeLive" and Object:FindFirstChild("Hole") then
        if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value["Mandrake Hole"] then
            Functions.AddESP({ Object=Object.Hole, Text="Mandrake Hole", Color=Options.EntityESPColor.Value }, true)
        end
        table.insert(Objects.Entities, Object.Hole)
    end
end

-- === Очередь объектов ===
local function QueueObject(Object)
    if Object.ClassName == "ProximityPrompt" then return end
    if Object:IsA("Model") and (AllowedInstances[Object.Name] or Entities[Object.Name]) then
        table.insert(Globals.ObjectQueue, Object)
    elseif Object:IsA("BasePart") and AllowedInstances[Object.Name] then
        table.insert(Globals.ObjectQueue, Object)
    end
end

Functions.ConnectSignal(RunService.RenderStepped, function()
    local Object = table.remove(Globals.ObjectQueue, 1)
    if Object then
        pcall(HandleESPObject, Object)
    end
end)

for _, Object in Workspace:GetDescendants() do
    task.spawn(function() QueueObject(Object) end)
end

Functions.ConnectSignal(Workspace.DescendantAdded, function(Object)
    QueueObject(Object)
end)

-- === Обработчик сущностей ===
local function HandleEntitySpawn(Entity)
    if not Entity or typeof(Entity) ~= "Instance" then return end
    local Model = Entity
    if Entity:IsA("Humanoid") then Model = Entity.Parent end
    if not Model or not Model:IsA("Model") then return end

    local EntityData = Entities[Model.Name]
    if not EntityData then return end
    if Model:GetAttribute("tokagod_Handled") then return end
    Model:SetAttribute("tokagod_Handled", true)

    while not Model.PrimaryPart do
        for _, Child in Model:GetChildren() do
            if Child:IsA("BasePart") then Model.PrimaryPart = Child end
        end
        if not Model.PrimaryPart then task.wait() end
    end
    task.wait(0.1)
    if not Model.PrimaryPart then return end

    local Alias = EntityData.Alias
    if Toggles.EntityESPToggle.Value and Options.EntityESPOptions.Value[Alias] then
        Functions.AddESP({ Object=Model, Text=Alias, Color=Options.EntityESPColor.Value }, NodeEntities[Alias] ~= true)
    end
    table.insert(Objects.Entities, Model)
end

Functions.ConnectSignal(Workspace.ChildAdded, function(Child)
    if Child:IsA("Model") and Entities[Child.Name] then
        task.defer(HandleEntitySpawn, Child)
    end
end)
Functions.ConnectSignal(Workspace.DescendantAdded, function(Desc)
    local Model = Desc:IsA("Humanoid") and Desc.Parent or Desc
    if Model and Model:IsA("Model") and Entities[Model.Name] then
        task.defer(HandleEntitySpawn, Desc)
    end
end)

-- === Player ESP ===
local function OnPlayerAdded(Player)
    if Player == LocalPlayer then return end
    if Player.Character and Toggles.PlayerESPToggle.Value then
        Functions.AddESP({ Object=Player.Character, Text=Player.Name, Color=Options.PlayerESPColor.Value })
    end
    Functions.ConnectSignal(Player.CharacterAdded, function(NewChar)
        if Toggles.PlayerESPToggle.Value then
            Functions.AddESP({ Object=NewChar, Text=Player.Name, Color=Options.PlayerESPColor.Value })
        end
    end)
    Functions.ConnectSignal(Player:GetAttributeChangedSignal("Alive"), function()
        if Player:GetAttribute("Alive") ~= true and Player.Character then
            Functions.RemoveESP(Player.Character)
        end
    end)
end

for _, Player in Players:GetPlayers() do OnPlayerAdded(Player) end
Functions.ConnectSignal(Players.PlayerAdded, OnPlayerAdded)

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

    for Object, Conn in pairs(Globals.ESPConnections) do
        pcall(function() Conn:Disconnect() end)
        pcall(function() ESPLibrary:RemoveESP(Object) end)
    end
    Globals.ESPConnections = {}
    Globals.ESPBlacklist = {}
    Globals.ObjectQueue = {}

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
