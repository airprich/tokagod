-- tokagod Loader
-- Author: airprich

local LoadStart = tick()

if shared.tokagod then return end
shared.tokagod = true

local BaseUrl = "https://raw.githubusercontent.com/airprich/tokagod/main/"

getgenv().tokagod = {
    Environment = loadstring(game:HttpGet(BaseUrl .. "Components/Environment.luau"))(),
    ESPLibrary  = loadstring(game:HttpGet(BaseUrl .. "Components/ESP.luau"))(),
    Interface   = loadstring(game:HttpGet(BaseUrl .. "Components/Interface.luau"))(),
    Notify      = loadstring(game:HttpGet(BaseUrl .. "Components/Notify.luau"))(),
    Legit = true
}

local tokagod = getgenv().tokagod
tokagod.LoadTime = math.floor((tick() - LoadStart) * 1000) / 1000

loadstring(game:HttpGet(BaseUrl .. "Games/Doors/Main.luau"))()
