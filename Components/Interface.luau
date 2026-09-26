-- tokagod Interface
-- Obsidian + SaveManager + ThemeManager

local BaseUrl = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local function FetchScript(path, retries)
    retries = retries or 3
    local lastErr

    for attempt = 1, retries do
        local ok, result = pcall(function()
            return game:HttpGet(BaseUrl .. path, true)
        end)

        if ok and typeof(result) == "string" and #result > 100 then
            return result
        end

        lastErr = ok and ("short/empty response, len=" .. tostring(#(result or ""))) or tostring(result)
        warn("[tokagod.Interface] fetch " .. path .. " attempt " .. attempt .. " failed: " .. lastErr)
        task.wait(0.5)
    end

    error("[tokagod.Interface] failed to fetch " .. path .. " after " .. retries .. " attempts: " .. tostring(lastErr))
end

local function LoadScript(path)
    local source = FetchScript(path)

    if typeof(loadstring) ~= "function" then
        error("[tokagod.Interface] loadstring недоступен. Executor не поддерживает.")
    end

    local fn, err = loadstring(source)
    if not fn then
        error("[tokagod.Interface] syntax error in " .. path .. ": " .. tostring(err))
    end

    local ok, result = pcall(fn)
    if not ok then
        error("[tokagod.Interface] runtime error in " .. path .. ": " .. tostring(result))
    end

    return result
end

local Obsidian     = LoadScript("Library.lua")
local SaveManager  = LoadScript("addons/SaveManager.lua")
local ThemeManager = LoadScript("addons/ThemeManager.lua")

return {
    Library = Obsidian,
    SaveManager = SaveManager,
    ThemeManager = ThemeManager
}
