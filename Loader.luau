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

Functions.Notify = function(Settings)
    tokagod.Notify:Send({
        Title = Settings.Title or "tokagod",
        Body = Settings.Body or "...",
        Time = Settings.Time or 5
    })
end

-- ============================================
-- КЕЙБИНД ДЛЯ ОТКРЫТИЯ МЕНЮ (RightShift)
-- ============================================

Library.ToggleKeybind = Enum.KeyCode.RightShift

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
Groupboxes.Debug               = Tabs.General:AddRightGroupbox("Debug")

Groupboxes.Exploits_Bypass     = Tabs.Exploits:AddLeftGroupbox("Bypass / Solve")
Groupboxes.Exploits_Audio      = Tabs.Exploits:AddLeftGroupbox("Audio")
Groupboxes.Exploits_BypassRight= Tabs.Exploits:AddRightGroupbox("Bypass")
Groupboxes.Exploits_Remove     = Tabs.Exploits:AddRightGroupbox("Remove")

Groupboxes.Visuals_LeftTab     = Tabs.Visuals:AddLeftTabbox("Camera / Effects")
Groupboxes.Visuals_Camera      = Groupboxes.Visuals_LeftTab:AddTab("Camera")
Groupboxes.Visuals_Effects     = Groupboxes.Visuals_LeftTab:AddTab("Effects")

Groupboxes.Visuals_RightTab    = Tabs.Visuals:AddRightTabbox("Entities / Settings")
Groupboxes.Visuals_Entities    = Groupboxes.Visuals_RightTab:AddTab("Entities")
Groupboxes.Visuals_EntitySettings = Groupboxes.Visuals_RightTab:AddTab("Settings")

Groupboxes.Visuals_ESP         = Tabs.Visuals:AddRightTabbox("ESP/Settings")
Groupboxes.Visuals_ESP_Toggles = Groupboxes.Visuals_ESP:AddTab("ESP")
Groupboxes.Visuals_ESP_Settings= Groupboxes.Visuals_ESP:AddTab("Settings")

Groupboxes.Floors_Automation   = Tabs.Floors:AddRightGroupbox("Automation")
Groupboxes.Floors_Completion   = Tabs.Floors:AddRightGroupbox("Completion")
Groupboxes.Floors_Visuals      = Tabs.Floors:AddLeftGroupbox("Visuals")
Groupboxes.Floors_Bypass       = Tabs.Floors:AddLeftGroupbox("Bypass")
Groupboxes.Floors_Farming      = Tabs.Floors:AddLeftGroupbox("Farming")

Groupboxes.Archives_Misc       = Tabs.Archives:AddRightGroupbox("Exploits / Anti")
Groupboxes.Archives_Bypasses   = Tabs.Archives:AddLeftGroupbox("Bypasses")
Groupboxes.Archives_Experimental = Tabs.Archives:AddLeftGroupbox("Experimental")

Groupboxes.Stairwell_Misc      = Tabs.Stairwell:AddLeftGroupbox("Exploits / Anti")
Groupboxes.Stairwell_Experimental = Tabs.Stairwell:AddLeftGroupbox("Experimental")

-- ПРИМЕРНЫЕ ЭЛЕМЕНТЫ (потом удалишь)
Groupboxes.General_Character:AddSlider("SpeedBoostSlider", {
    Text = "Speed Boost", Min = 0, Max = 100, Default = 0, Rounding = 0, Compact = true
})

Groupboxes.General_Character:AddToggle("SpeedBoostToggle", {
    Text = "Enable Speed Boost", Default = false,
    Tooltip = "Increases your walkspeed."
})

Groupboxes.General_Character:AddToggle("FlyToggle", {
    Text = "Fly", Default = false,
    Tooltip = "Allows you to fly."
})

Toggles.FlyToggle:AddKeyPicker("FlyKeybind", {
    Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true
})

Groupboxes.General_Character:AddSlider("FlySpeed", {
    Text = "Fly Speed", Min = 0, Max = 115, Default = 20, Rounding = 0, Compact = true
})

Groupboxes.General_Character:AddDivider()

Groupboxes.General_Character:AddToggle("NoclipToggle", {
    Text = "Noclip", Default = false,
    Tooltip = "Walk through walls."
})

Toggles.NoclipToggle:AddKeyPicker("NoclipKeybind", {
    Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true
})

-- SaveManager / ThemeManager
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

Functions.Notify({
    Title = "tokagod загружен",
    Body = "Нажми RightShift чтобы открыть меню",
    Time = 5
})
