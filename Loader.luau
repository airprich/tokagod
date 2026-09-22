-- tokagod Loader (safe debug version)
-- Author: airprich

local LoadStart = tick()

shared.tokagod = nil
getgenv().tokagod = nil

local BaseUrl = "https://raw.githubusercontent.com/airprich/tokagod/main/"
local CacheBust = "?t=" .. tostring(math.floor(tick() * 1000))

local function LoadFile(path)
    local url = BaseUrl .. path .. CacheBust
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        warn("[tokagod] HTTP FAIL: " .. path .. " | " .. tostring(result))
        return nil
    end

    if not result or #result < 50 then
        warn("[tokagod] EMPTY/SHORT: " .. path .. " | len=" .. tostring(#(result or "")))
        return nil
    end

    local fn, err = loadstring(result)
    if not fn then
        warn("[tokagod] SYNTAX ERROR in " .. path .. ": " .. tostring(err))
        return nil
    end

    local runOk, runResult = pcall(fn)
    if not runOk then
        warn("[tokagod] RUNTIME ERROR in " .. path .. ": " .. tostring(runResult))
        return nil
    end

    print("[tokagod] Loaded OK: " .. path)
    return runResult
end

getgenv().tokagod = {
    Environment = LoadFile("Components/Environment.luau"),
    ESPLibrary  = LoadFile("Components/ESP.luau"),
    Interface   = LoadFile("Components/Interface.luau"),
    Notify      = LoadFile("Components/Notify.luau"),
    Legit = true
}

if not getgenv().tokagod.Interface then
    warn("[tokagod] FATAL: Interface.luau НЕ загружен. Дальше не идём.")
    return
end

if not getgenv().tokagod.Environment then
    warn("[tokagod] FATAL: Environment.luau НЕ загружен.")
    return
end

if not getgenv().tokagod.Notify then
    warn("[tokagod] FATAL: Notify.luau НЕ загружен.")
    return
end

local tokagod = getgenv().tokagod
tokagod.LoadTime = math.floor((tick() - LoadStart) * 1000) / 1000

LoadFile("Games/Doors/Main.luau")
