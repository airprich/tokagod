-- tokagod Main (структура меню по образцу Abysall)

local tokagod = getgenv().tokagod
local Globals = {}
local Library = tokagod.Interface.Library
local SaveManager = tokagod.Interface.SaveManager
local ThemeManager = tokagod.Interface.ThemeManager
local ESPLibrary = tokagod.ESPLibrary

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Toggles = Library.Toggles
local Options = Library.Options
local Functions = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Floor = ReplicatedStorage:WaitForChild("GameData"):WaitForChild("Floor").Value
local LiveModifiers = ReplicatedStorage:FindFirstChild("LiveModifiers")
local CurrentRooms = workspace:FindFirstChild("CurrentRooms")
local CollisionPart

local RemotesFolder = ReplicatedStorage:FindFirstChild("RemotesFolder")
    or ReplicatedStorage:FindFirstChild("EntityInfo")
    or ReplicatedStorage:FindFirstChild("Bricks")

local Character, Humanoid, RootPart

Functions.Notify = function(Settings)
    tokagod.Notify:Send({
        Title = Settings.Title or "tokagod",
        Body = Settings.Body or "...",
        Time = Settings.Time or 5
    })
end

-- ============================================
-- КЕЙБИНД ДЛЯ ОТКРЫТИЯ МЕНЮ
-- ============================================

-- ОКНО
local Window = Library:CreateWindow({
    Title = "????",
    Footer = "dsc.gg/???",
    NotifySide = "Right",
    ShowCustomCursor = false,
    AutoShow = true,
    Center = true,
    TabPadding = 3,
    MenuFadeTime = 0,
    CornerRadius = 6,
    ToggleKeybind = Enum.KeyCode.RightShift,
})

-- ВКЛАДКИ
local Tabs = {
    General   = Window:AddTab("General", "house"),
    Exploits  = Window:AddTab("Exploits", "shield"),
    Visuals   = Window:AddTab("Visuals", "eye"),
    Floors    = Window:AddTab("Floors", "earth"),
    Archives  = Window:AddTab("New - Archives", "rbxassetid://104508835882225"),
    Stairwell = Window:AddTab("New - Stairwell", "rbxassetid://80017304328364"),
    Settings  = Window:AddTab("Settings", "settings"),
}

-- ГРУПБОКСЫ
local Groupboxes = {}

Groupboxes.General_Character   = Tabs.General:AddLeftGroupbox("Character")
Groupboxes.General_Self        = Tabs.General:AddLeftGroupbox("Self")
Groupboxes.Self_Automation     = Tabs.General:AddRightGroupbox("Automation")
Groupboxes.Self_Misc           = Tabs.General:AddRightGroupbox("Miscellaneous")

Groupboxes.General_Self:AddToggle("DisableAnticheat", {
    Text = "Anticheat Bypass",
    Default = false,
    Tooltip = "Отключает античит при взаимодействии с лестницей. Без него Speed Boost откатывает."
})

-- ============================================
-- CHARACTER / SPEED BOOST
-- ============================================

Groupboxes.General_Character:AddSlider("SpeedBoost", {
    Text = "Speed Boost",
    Min = 0, Max = 100, Default = 0,
    Rounding = 0, Compact = true
})

Groupboxes.General_Character:AddToggle("SpeedBoostToggle", {
    Text = "Enable Speed Boost",
    Default = false,
    Tooltip = "Увеличивает скорость на значение слайдера"
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
    Tooltip = "Телепортирует хитбокс под пол — античит не ловит скорость"
})

Toggles.PositionSpoof:AddKeyPicker("PositionSpoofKeybind", {
    Text = "Position Spoof", Default = "B", Mode = "Toggle", SyncToggleState = true
})

Groupboxes.General_Character:AddToggle("VelocityManipulationToggle", {
    Text = "Velocity Manipulation",
    Default = false,
    Tooltip = "Медленно двигает тебя вперёд через физику — обход античита"
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
-- ЛОГИКА SPEED BOOST
-- ============================================

Functions.IsCrouching = function()
    if not Character then return false end
    if Floor == "Fools" or Floor == "OldHotel" then
        return Character:GetAttribute("Crouching") == true
    end
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
        if LiveModifiers and LiveModifiers:FindFirstChild("PlayerCrouchSlow") then
            Speed -= 8
        elseif LiveModifiers and LiveModifiers:FindFirstChild("PlayerSlow") then
            Speed -= 8
        else
            Speed -= 5
        end
    end

    return Speed
end

Toggles.SpeedBoostToggle:OnChanged(function(Value)
    if Humanoid then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + (Value and Options.SpeedBoost.Value or 0)
    end
    -- Сообщаем серверу
    if RemotesFolder and RemotesFolder:FindFirstChild("Crouch") then
        RemotesFolder.Crouch:FireServer(false, true)
    end
    Functions.Notify({
        Title = "Speed Boost",
        Body = Value and "Включено" or "Выключено"
    })
end)

Options.SpeedBoost:OnChanged(function(Value)
    if Toggles.SpeedBoostToggle.Value and Humanoid then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + Value
    end
    -- Сообщаем серверу, что скорость изменилась (обход античита)
    if RemotesFolder and RemotesFolder:FindFirstChild("Crouch") then
        RemotesFolder.Crouch:FireServer(false, true)
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if Toggles.SpeedBoostToggle.Value and Humanoid then
            Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + Options.SpeedBoost.Value
        end
    end
end)

-- ============================================
-- POSITION SPOOF + VELOCITY MANIPULATION
-- ============================================

Globals.ManipulateBody = Instance.new("BodyVelocity")
Globals.ManipulateBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)

Toggles.PositionSpoof:OnChanged(function(Value)
    if Floor == "Fools" or Floor == "OldHotel" then return end
    if not RootPart or not Humanoid then return end
    if Value then
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
        Humanoid.HipHeight = 0.05
        if RemotesFolder and RemotesFolder:FindFirstChild("Crouch") then
            RemotesFolder.Crouch:FireServer(true, true)
        end
    else
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, 2.346, 0)
        Humanoid.HipHeight = 2.396
    end
end)

RunService.RenderStepped:Connect(function()
    -- Position Spoof — постоянное применение
    if Toggles.PositionSpoof.Value and RootPart and Humanoid then
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
        Humanoid.HipHeight = 0.05
        if RemotesFolder and RemotesFolder:FindFirstChild("Crouch") then
            RemotesFolder.Crouch:FireServer(true, true)
        end
    end

    -- Velocity Manipulation
    if Toggles.VelocityManipulationToggle.Value and RootPart then
        if Options.VelocityManipulationMode.Value == "Velocity" then
            Globals.ManipulateBody.Parent = RootPart
            Globals.ManipulateBody.Velocity = RootPart.CFrame.LookVector * 2.25
        else
            Globals.ManipulateBody.Parent = nil
        end
    else
        Globals.ManipulateBody.Parent = nil
    end

    -- Pivot-режим — телепорт вперёд
    if Toggles.VelocityManipulationToggle.Value
        and Options.VelocityManipulationMode.Value == "Pivot"
        and Floor ~= "Fools" and Floor ~= "OldHotel"
        and Character
    then
        Character:PivotTo(Workspace.CurrentCamera:GetPivot() * CFrame.new(0, 0, 2560))
    end
end)

-- ============================================
-- ЛОГИКА FLY
-- ============================================

local flyConnection = nil
local flyBodyVelocity = nil
local flyBodyGyro = nil

function StartFly()
    if not Character or not RootPart or not Humanoid then return end
    if flyConnection then return end

    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyBodyVelocity.P = 1250
    flyBodyVelocity.Parent = RootPart

    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBodyGyro.P = 1250
    flyBodyGyro.CFrame = RootPart.CFrame
    flyBodyGyro.Parent = RootPart

    Humanoid.PlatformStand = true

    local UserInputService = game:GetService("UserInputService")
    local Camera = Workspace.CurrentCamera

    flyConnection = RunService.RenderStepped:Connect(function()
        if not RootPart or not Humanoid then return end

        local cameraCFrame = Camera.CFrame
        local forward = cameraCFrame.LookVector
        local right = cameraCFrame.RightVector
        local direction = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            direction = direction + forward
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            direction = direction - forward
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            direction = direction - right
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            direction = direction + right
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction = direction + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            direction = direction - Vector3.new(0, 1, 0)
        end

        if direction.Magnitude > 0 then
            direction = direction.Unit
        end

        flyBodyVelocity.Velocity = direction * Options.FlySpeed.Value
        flyBodyGyro.CFrame = cameraCFrame
    end)
end

function StopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
    if Humanoid then
        Humanoid.PlatformStand = false
    end
end

Toggles.FlyToggle:OnChanged(function(Value)
    if Value then
        StartFly()
    else
        StopFly()
    end
end)

-- ============================================
-- ЛОГИКА NOCLIP
-- ============================================

local noclipConnection = nil

function StartNoclip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if not Character then return end
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

function StopNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end

Toggles.NoclipToggle:OnChanged(function(Value)
    if Value then
        StartNoclip()
    else
        StopNoclip()
    end
end)

-- ============================================
-- ANTICHEAT BYPASS
-- ============================================

Globals.AnticheatDisabled = false

Toggles.DisableAnticheat:OnChanged(function(Value)
    if Globals.AnticheatDisabled == true and not Value then
        if RemotesFolder and RemotesFolder:FindFirstChild("ClimbLadder") then
            RemotesFolder.ClimbLadder:FireServer()
        end
        Globals.AnticheatDisabled = false
    end
end)

-- ============================================
-- ОБРАБОТКА ПЕРСОНАЖА (CharacterAdded)
-- ============================================

local function OnCharacterAdded(newCharacter)
    Character = newCharacter
    Humanoid = newCharacter:WaitForChild("Humanoid", 10)
    RootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
    CollisionPart = newCharacter:FindFirstChild("CollisionPart") or newCharacter:FindFirstChild("Collision")

    -- Speed Boost — применяем сразу
    if Toggles.SpeedBoostToggle.Value and Humanoid then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + Options.SpeedBoost.Value
    end

    -- Fly — перезапуск
    if Toggles.FlyToggle.Value then
        task.wait(0.5)
        StartFly()
    end

    -- Noclip — перезапуск
    if Toggles.NoclipToggle.Value then
        StartNoclip()
    end

    -- Античит-байпас через лестницу (ВНУТРИ OnCharacterAdded)
    Character:GetAttributeChangedSignal("Climbing"):Connect(function()
        if Character
            and Character:GetAttribute("Climbing") == true
            and Toggles.DisableAnticheat
            and Toggles.DisableAnticheat.Value
            and not Globals.AnticheatDisabled
        then
            task.wait(0.25)
            Character:SetAttribute("Climbing", false)
            Functions.Notify({ Title = "Античит отключён", Body = "Теперь Speed Boost работает" })
            Globals.AnticheatDisabled = true
        end
    end)
end

if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

-- ============================================
-- SaveManager / ThemeManager
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
-- UNLOAD (кнопка выгрузки скрипта)
-- ============================================

local Settings_Misc = Tabs.Settings:AddLeftGroupbox("Misc")

Settings_Misc:AddButton({
    Text = "Unload Script",
    Tooltip = "Полностью выгружает tokagod и очищает все соединения",
    DoubleClick = true,
    Risky = true,
    Func = function()
        if Library and Library.Unload then
            Library:Unload()
        end
        if shared then
            shared.tokagod = nil
        end
        if getgenv then
            getgenv().tokagod = nil
        end
        print("[tokagod] Выгружен")
    end
})

Library:OnUnload(function()
    if Toggles.SpeedBoostToggle then
        pcall(function() Toggles.SpeedBoostToggle:SetValue(false) end)
    end
    if Toggles.FlyToggle then
        pcall(function() Toggles.FlyToggle:SetValue(false) end)
    end
    if Toggles.NoclipToggle then
        pcall(function() Toggles.NoclipToggle:SetValue(false) end)
    end
    if StopFly then pcall(StopFly) end
    if StopNoclip then pcall(StopNoclip) end

    -- Восстанавливаем скорость
    if Humanoid then
        pcall(function() Humanoid.WalkSpeed = 15 end)
    end
    if Humanoid then
        pcall(function() Humanoid.PlatformStand = false end)
    end

    print("[tokagod] Функции выключены")
end)

-- ============================================
-- ЗАГРУЗКА
-- ============================================

Functions.Notify({
    Title = "tokagod загружен",
    Body = "Нажми RightShift чтобы открыть меню",
    Time = 5
})
