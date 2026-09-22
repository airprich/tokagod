-- tokagod Main (структура меню по образцу Abysall)

local tokagod = getgenv().tokagod
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
    Title = "tokagod",
    Footer = "dsc.gg/tokagod",
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
    Functions.Notify({
        Title = "Speed Boost",
        Body = Value and "Включено" or "Выключено"
    })
end)

Options.SpeedBoost:OnChanged(function(Value)
    if Toggles.SpeedBoostToggle.Value and Humanoid then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + Value
    end
end)

RunService.RenderStepped:Connect(function()
    if Toggles.SpeedBoostToggle.Value and Humanoid then
        Humanoid.WalkSpeed = Functions.GetCurrentSpeed() + Options.SpeedBoost.Value
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
-- ОБРАБОТКА ПЕРСОНАЖА (CharacterAdded)
-- ============================================

local function OnCharacterAdded(newCharacter)
    Character = newCharacter
    Humanoid = newCharacter:WaitForChild("Humanoid", 10)
    RootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
    CollisionPart = newCharacter:FindFirstChild("CollisionPart") or newCharacter:FindFirstChild("Collision")

    -- Speed Boost — просто применяем через RenderStepped loop
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
end

-- Запускаем обработку персонажа
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
-- ЗАГРУЗКА
-- ============================================

Functions.Notify({
    Title = "tokagod загружен",
    Body = "Нажми RightShift чтобы открыть меню",
    Time = 5
})
