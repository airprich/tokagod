-- tokagod Loader
-- Author: betmon1904p
-- Version: 1.0

local LoadStart = tick()

if shared.tokagod then
    return
end
shared.tokagod = true

local BaseUrl = "https://raw.githubusercontent.com/ТВОЙ_НИК/tokagod/main/"

-- Подгружаем Environment
getgenv().tokagod = {
    Environment = loadstring(game:HttpGet(BaseUrl .. "Components/Environment.luau"))(),
    ESPLibrary = loadstring(game:HttpGet(BaseUrl .. "Components/ESP.luau"))(),
    Notify = loadstring(game:HttpGet(BaseUrl .. "Components/Notify.luau"))(),
    Legit = true
}

local tokagod = getgenv().tokagod

-- Подгружаем Interface (Obsidian)
tokagod.Interface = loadstring(game:HttpGet(BaseUrl .. "Components/Interface.luau"))()

-- Загружаем основную логику
loadstring(game:HttpGet(BaseUrl .. "Games/Doors/Main.luau"))()

tokagod.LoadTime = math.floor((tick() - LoadStart) * 1000) / 1000
