-- tokagod Interface
-- Obsidian + SaveManager + ThemeManager

local BaseUrl = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

-- Главная библиотека
local Obsidian = loadstring(game:HttpGet(BaseUrl .. "Library.lua"))()

-- SaveManager (в папке addons)
local SaveManager = loadstring(game:HttpGet(BaseUrl .. "addons/SaveManager.lua"))()

-- ThemeManager (в папке addons)
local ThemeManager = loadstring(game:HttpGet(BaseUrl .. "addons/ThemeManager.lua"))()

return {
    Library = Obsidian,
    SaveManager = SaveManager,
    ThemeManager = ThemeManager
}
