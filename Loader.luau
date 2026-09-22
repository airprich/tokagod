-- tokagod Loader
-- Author: airprich

local LoadStart = tick()

-- СБРОС флага чтобы можно было перезапускать без рестарта Roblox
shared.tokagod = nil
getgenv().tokagod = nil

local BaseUrl = "https://raw.githubusercontent.com/airprich/tokagod/main/"
local CacheBust = "?t=" .. tostring(math.floor(tick() * 1000))

local function LoadFile(path)
    return loadstring(game:HttpGet(BaseUrl .. path .. CacheBust))()
end

getgenv().tokagod = {
    Environment = LoadFile("Components/Environment.luau"),
    ESPLibrary  = LoadFile("Components/ESP.luau"),
    Interface   = LoadFile("Components/Interface.luau"),
    Notify      = LoadFile("Components/Notify.luau"),
    Legit = true
}

local tokagod = getgenv().tokagod
tokagod.LoadTime = math.floor((tick() - LoadStart) * 1000) / 1000

LoadFile("Games/Doors/Main.luau")
