-- tokagod ESP Library

local ESPLibrary = {}

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

ESPLibrary.Objects = {}
ESPLibrary.ColorTable = {}

local Settings = {
    Rainbow = false,
    ShowDistance = true,
    FillTransparency = 0.75,
    OutlineTransparency = 0,
    TextTransparency = 0,
    TextOutlineTransparency = 0,
    FadeTime = 0.25,
    RenderLimit = 240,
    TextSize = 20,
    Font = Enum.Font.Highway,
    Tracers = false,
    TracerSize = 0.75,
    TracerOrigin = "Bottom",
    Arrows = false,
    ArrowRadius = 250,
    DistanceSizeRatio = 0.8
}

function ESPLibrary:GenerateRandomString()
    local length = math.random(10, 20)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = ""
    for i = 1, length do
        local pos = math.random(1, #chars)
        result = result .. chars:sub(pos, pos)
    end
    return result
end

function ESPLibrary:AddESP(Options)
    local Object = Options.Object
    if not Object or self.Objects[Object] then return end

    local Text = Options.Text or "Object"
    local Color = Options.Color or Color3.new(1, 1, 1)

    local Highlight = Instance.new("Highlight")
    Highlight.Name = "tokagod_ESP"
    Highlight.FillColor = Color
    Highlight.FillTransparency = Settings.FillTransparency
    Highlight.OutlineColor = Color
    Highlight.OutlineTransparency = Settings.OutlineTransparency
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Parent = Object

    local Billboard = Instance.new("BillboardGui")
    Billboard.Name = "tokagod_Billboard"
    Billboard.Size = UDim2.new(0, 200, 0, 50)
    Billboard.StudsOffset = Vector3.new(0, 3, 0)
    Billboard.AlwaysOnTop = true
    Billboard.Parent = Object

    local Label = Instance.new("TextLabel")
    Label.Name = "Text"
    Label.Size = UDim2.fromScale(1, 1)
    Label.BackgroundTransparency = 1
    Label.Text = Text
    Label.TextColor3 = Color
    Label.TextStrokeTransparency = Settings.TextOutlineTransparency
    Label.TextTransparency = Settings.TextTransparency
    Label.TextSize = Settings.TextSize
    Label.Font = Settings.Font
    Label.Parent = Billboard

    self.Objects[Object] = {
        Highlight = Highlight,
        Billboard = Billboard,
        Label = Label,
        Text = Text,
        Color = Color
    }
    self.ColorTable[Object] = Color
end

function ESPLibrary:RemoveESP(Object)
    local Data = self.Objects[Object]
    if not Data then return end

    if Data.Highlight then Data.Highlight:Destroy() end
    if Data.Billboard then Data.Billboard:Destroy() end

    self.Objects[Object] = nil
    self.ColorTable[Object] = nil
end

function ESPLibrary:UpdateObjectColor(Object, Color)
    local Data = self.Objects[Object]
    if not Data then return end

    Data.Color = Color
    Data.Highlight.FillColor = Color
    Data.Highlight.OutlineColor = Color
    Data.Label.TextColor3 = Color
    self.ColorTable[Object] = Color
end

RunService.RenderStepped:Connect(function()
    for Object, Data in pairs(ESPLibrary.Objects) do
        if not Object or not Object.Parent then
            ESPLibrary:RemoveESP(Object)
            continue
        end

        if Settings.Rainbow then
            local hue = tick() % 1
            local color = Color3.fromHSV(hue, 1, 1)
            Data.Highlight.FillColor = color
            Data.Highlight.OutlineColor = color
            Data.Label.TextColor3 = color
        end

        if Settings.ShowDistance and Data.Label then
            local pos = Object:IsA("Model") and Object:GetPivot().Position or Object.Position
            local dist = (Camera.CFrame.Position - pos).Magnitude
            Data.Label.Text = Data.Text .. " [" .. math.floor(dist) .. "m]"
        end
    end
end)

function ESPLibrary:SetRainbow(v) Settings.Rainbow = v end
function ESPLibrary:SetShowDistance(v) Settings.ShowDistance = v end
function ESPLibrary:SetFillTransparency(v) Settings.FillTransparency = v end
function ESPLibrary:SetOutlineTransparency(v) Settings.OutlineTransparency = v end
function ESPLibrary:SetTextTransparency(v) Settings.TextTransparency = v end
function ESPLibrary:SetTextOutlineTransparency(v) Settings.TextOutlineTransparency = v end
function ESPLibrary:SetFadeTime(v) Settings.FadeTime = v end
function ESPLibrary:SetRenderLimit(v) Settings.RenderLimit = v end
function ESPLibrary:SetTextSize(v) Settings.TextSize = v end
function ESPLibrary:SetFont(v) Settings.Font = v end
function ESPLibrary:SetTracers(v) Settings.Tracers = v end
function ESPLibrary:SetTracerSize(v) Settings.TracerSize = v end
function ESPLibrary:SetTracerOrigin(v) Settings.TracerOrigin = v end
function ESPLibrary:SetArrows(v) Settings.Arrows = v end
function ESPLibrary:SetArrowRadius(v) Settings.ArrowRadius = v end

function ESPLibrary:Unload()
    for Object in pairs(self.Objects) do
        self:RemoveESP(Object)
    end
end

return ESPLibrary
