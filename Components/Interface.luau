-- tokagod Interface
-- Obsidian + SaveManager + ThemeManager

local BaseUrl = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

-- Главная библиотека
local Obsidian = loadstring(game:HttpGet(BaseUrl .. "Library.lua"))()

-- SaveManager
local SaveManager = loadstring(game:HttpGet(BaseUrl .. "addons/SaveManager.lua"))()

-- ThemeManager
local ThemeManager = loadstring(game:HttpGet(BaseUrl .. "addons/ThemeManager.lua"))()

return {
    Library = Obsidian,
    SaveManager = SaveManager,
    ThemeManager = ThemeManager
}
