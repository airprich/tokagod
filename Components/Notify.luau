-- tokagod Notify
-- Простые уведомления через StarterGui

local Notify = {}

function Notify:Send(Settings)
    local Title = Settings.Title or "tokagod"
    local Body = Settings.Body or "..."
    local Time = Settings.Time or 5

    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = Title,
            Text = Body,
            Duration = Time
        })
    end)

    print("[" .. Title .. "] " .. Body)
end

return Notify
