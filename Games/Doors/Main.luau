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

local BASE_WALKSPEED = 16
local originalWalkSpeed = nil

local function ApplySpeedBoost()
    if not Humanoid then return end

    local enabled = Toggles.SpeedBoostToggle.Value
    local boost = Options.SpeedBoost.Value

    if enabled then
        if not originalWalkSpeed then
            originalWalkSpeed = Humanoid.WalkSpeed
        end
        Humanoid.WalkSpeed = originalWalkSpeed + boost
    else
        if originalWalkSpeed then
            Humanoid.WalkSpeed = originalWalkSpeed
            originalWalkSpeed = nil
        end
    end
end

Toggles.SpeedBoostToggle:OnChanged(function(Value)
    ApplySpeedBoost()
    Functions.Notify({
        Title = "Speed Boost",
        Body = Value and "Включено" or "Выключено"
    })
end)

Options.SpeedBoost:OnChanged(function(Value)
    ApplySpeedBoost()
end)

-- ============================================
-- ОБРАБОТКА ПЕРСОНАЖА (CharacterAdded)
-- ============================================

local function OnCharacterAdded(newCharacter)
    Character = newCharacter
    Humanoid = newCharacter:WaitForChild("Humanoid", 10)
    RootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)

    -- Если speed boost был включён — применить заново
    if Toggles.SpeedBoostToggle.Value then
        originalWalkSpeed = Humanoid.WalkSpeed
        ApplySpeedBoost()
    end

    -- Если fly был включён — перезапустить
    if Toggles.FlyToggle.Value then
        StopFly()
        task.wait(0.5)
        StartFly()
    end

    -- Если noclip был включён — перезапустить
    if Toggles.NoclipToggle.Value then
        StopNoclip()
        StartNoclip()
    end
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
    SaveManager:BuildConfigSection(Tabs.General)
    SaveManager:LoadAutoloadConfig()
end

if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:ApplyToTab(Tabs.General)
end

-- ============================================
-- ЗАГРУЗКА
-- ============================================

Functions.Notify({
    Title = "tokagod загружен",
    Body = "Нажми RightShift чтобы открыть меню",
    Time = 5
})
