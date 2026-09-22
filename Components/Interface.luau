-- tokagod Interface
-- Obsidian + SaveManager + ThemeManager

local BaseUrl = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"

local Obsidian = loadstring(game:HttpGet(BaseUrl .. "Obsidian.lua"))()
local SaveManager = loadstring(game:HttpGet(BaseUrl .. "Addons/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet(BaseUrl .. "Addons/ThemeManager.lua"))()

return {
    Library = Obsidian,
    SaveManager = SaveManager,
    ThemeManager = ThemeManager
}
