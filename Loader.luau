-- SimpleUI.luau
-- Базовое графическое меню для Roblox
-- Размер: 500x500, вкладки, drag, keybind

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Colors = {
    Background = Color3.fromRGB(20, 20, 25),
    Accent = Color3.fromRGB(100, 100, 255),
    Section = Color3.fromRGB(30, 30, 38),
    Border = Color3.fromRGB(50, 50, 60),
    Off = Color3.fromRGB(60, 60, 70),
    Text = Color3.fromRGB(240, 240, 240),
    Muted = Color3.fromRGB(155, 155, 170),
}

local function create(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    instance.Parent = parent
    return instance
end

local function round(instance, radius)
    create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, instance)
end

local function outline(instance)
    create("UIStroke", {
        Color = Colors.Border,
        Thickness = 1,
    }, instance)
end

local function tween(instance, properties)
    TweenService:Create(
        instance,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        properties
    ):Play()
end

local function label(parent, text, size, position, textSize, bold)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Position = position,
        Size = size,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        Text = text,
        TextColor3 = Colors.Text,
        TextSize = textSize or 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end

local UI = {}

function UI:CreateWindow(options)
    options = options or {}

    -- Создаём ScreenGui
    local screen = create("ScreenGui", {
        Name = "SimpleUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, LocalPlayer:WaitForChild("PlayerGui"))

    -- Holder — контейнер который двигается (drag)
    local holder = create("Frame", {
        Name = "WindowHolder",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(500, 500),
    }, screen)

    -- Масштаб для мобилки
    local scale = create("UIScale", { Scale = 1 }, holder)

    -- Окно 500x500
    local window = create("Frame", {
        Name = "Window",
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        Size = options.Size or UDim2.fromOffset(500, 500),
    }, holder)
    round(window)
    outline(window)

    -- Заголовок
    local header = create("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 42),
    }, window)

    label(header, options.Title or "tokagod", UDim2.new(1, -100, 1, 0),
        UDim2.fromOffset(14, 0), 15, true)

    -- Кнопка свернуть
    local minimizeButton = create("TextButton", {
        BackgroundColor3 = Colors.Section,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Position = UDim2.new(1, -70, 0, 8),
        Size = UDim2.fromOffset(26, 26),
        Text = "—",
        TextColor3 = Colors.Text,
        TextSize = 15,
    }, header)
    round(minimizeButton, 6)

    -- Кнопка закрыть
    local closeButton = create("TextButton", {
        BackgroundColor3 = Colors.Section,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Position = UDim2.new(1, -36, 0, 8),
        Size = UDim2.fromOffset(26, 26),
        Text = "X",
        TextColor3 = Colors.Text,
        TextSize = 12,
    }, header)
    round(closeButton, 6)

    -- Тело окна
    local body = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 48),
        Size = UDim2.new(1, -20, 1, -58),
    }, window)

    -- Список вкладок слева
    local tabList = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 120, 1, 0),
    }, body)

    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabList)

    -- Контент справа
    local contentHost = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(132, 0),
        Size = UDim2.new(1, -132, 1, 0),
    }, body)

    local result = {
        Toggles = {},
        Options = {},
        KeyPickers = {},
        Keybind = options.Keybind or Enum.KeyCode.RightShift,
    }

    local tabObjects = {}
    local selectedTab

    local function updateScale()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        scale.Scale = math.min(1, (viewport.X - 20) / 520, (viewport.Y - 20) / 520)
    end

    local function clampHolder()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local halfWidth = holder.AbsoluteSize.X / 2
        local halfHeight = holder.AbsoluteSize.Y / 2
        local x = math.clamp(holder.Position.X.Offset, halfWidth, viewport.X - halfWidth)
        local y = math.clamp(holder.Position.Y.Offset, halfHeight, viewport.Y - halfHeight)
        holder.Position = UDim2.fromOffset(x, y)
    end

    local function selectTab(tab)
        selectedTab = tab
        for _, item in pairs(tabObjects) do
            local active = item == tab
            tween(item.Button, {
                BackgroundColor3 = active and Colors.Accent or Colors.Section,
            })
            item.Page.Visible = active
        end
    end

    function result:AddTab(name)
        if tabObjects[name] then
            return tabObjects[name]
        end

        local button = create("TextButton", {
            BackgroundColor3 = Colors.Section,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            Size = UDim2.new(1, 0, 0, 36),
            Text = "  " .. name,
            TextColor3 = Colors.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, tabList)
        round(button, 6)

        create("UIPadding", { PaddingLeft = UDim.new(0, 10) }, button)

        local page = create("ScrollingFrame", {
            Active = true,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            ScrollBarThickness = 3,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
        }, contentHost)

        create("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, page)

        create("UIPadding", {
            PaddingBottom = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 4),
        }, page)

        local tab = {
            Name = name,
            Button = button,
            Page = page,
        }

        tabObjects[name] = tab

        button.Activated:Connect(function()
            selectTab(tab)
        end)

        function tab:AddSection(sectionName)
            local sectionFrame = create("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Colors.Section,
                BorderSizePixel = 0,
                Size = UDim2.new(1, -4, 0, 0),
            }, page)
            round(sectionFrame, 6)
            outline(sectionFrame)

            label(sectionFrame, sectionName, UDim2.new(1, -20, 0, 30),
                UDim2.fromOffset(10, 0), 12, true)

            local rows = create("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 30),
                Size = UDim2.new(1, -16, 0, 0),
            }, sectionFrame)

            local rowsLayout = create("UIListLayout", {
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, rows)

            rowsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                rows.Size = UDim2.new(1, -16, 0, rowsLayout.AbsoluteContentSize.Y)
                sectionFrame.Size = UDim2.new(1, -4, 0, 38 + rowsLayout.AbsoluteContentSize.Y)
            end)

            local section = {}

            local function makeRow(height)
                local row = create("Frame", {
                    BackgroundColor3 = Colors.Background,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, height or 38),
                    ZIndex = 2,
                }, rows)
                round(row, 5)
                return row
            end

            local function makeValueObject(id, default, callback, update)
                local object = { Value = default }

                function object:SetValue(value)
                    self.Value = value
                    if update then update(value) end
                    if callback then callback(value) end
                end

                return object
            end

            function section:AddToggle(id, controlOptions)
                controlOptions = controlOptions or {}
                local row = makeRow(38)
                label(row, controlOptions.Text or id, UDim2.new(1, -60, 1, 0),
                    UDim2.fromOffset(10, 0), 12)

                local indicator = create("TextButton", {
                    BackgroundColor3 = Colors.Off,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -42, 0.5, -9),
                    Size = UDim2.fromOffset(32, 18),
                    Text = "",
                    ZIndex = 3,
                }, row)
                round(indicator, 9)

                local dot = create("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundColor3 = Colors.Text,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 2, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14),
                    ZIndex = 4,
                }, indicator)
                round(dot, 7)

                local object
                object = makeValueObject(id, controlOptions.Default == true,
                    controlOptions.Callback, function(value)
                        tween(indicator, {
                            BackgroundColor3 = value and Colors.Accent or Colors.Off,
                        })
                        tween(dot, {
                            Position = value and UDim2.new(1, -16, 0.5, 0)
                                or UDim2.new(0, 2, 0.5, 0),
                        })
                    end)

                indicator.Activated:Connect(function()
                    object:SetValue(not object.Value)
                end)

                indicator.BackgroundColor3 = object.Value and Colors.Accent or Colors.Off
                dot.Position = object.Value and UDim2.new(1, -16, 0.5, 0)
                    or UDim2.new(0, 2, 0.5, 0)

                result.Toggles[id] = object
                return object
            end

            function section:AddSlider(id, controlOptions)
                controlOptions = controlOptions or {}
                local minimum = controlOptions.Min or 0
                local maximum = controlOptions.Max or 100
                local row = makeRow(52)
                label(row, controlOptions.Text or id, UDim2.new(1, -70, 0, 24),
                    UDim2.fromOffset(10, 2), 12)
                local valueLabel = label(row, "", UDim2.fromOffset(55, 24),
                    UDim2.new(1, -64, 0, 2), 11)
                valueLabel.TextXAlignment = Enum.TextXAlignment.Right

                local track = create("Frame", {
                    BackgroundColor3 = Colors.Off,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 10, 1, -14),
                    Size = UDim2.new(1, -20, 0, 4),
                }, row)
                round(track, 3)

                local fill = create("Frame", {
                    BackgroundColor3 = Colors.Accent,
                    BorderSizePixel = 0,
                    Size = UDim2.new(),
                }, track)
                round(fill, 3)

                local knob = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Colors.Text,
                    BorderSizePixel = 0,
                    Position = UDim2.new(),
                    Size = UDim2.fromOffset(12, 12),
                }, track)
                round(knob, 6)

                local function setDisplay(value)
                    value = math.clamp(value, minimum, maximum)
                    valueLabel.Text = tostring(math.floor(value * 100 + 0.5) / 100)
                    local alpha = maximum == minimum and 0
                        or (value - minimum) / (maximum - minimum)
                    fill.Size = UDim2.new(alpha, 0, 1, 0)
                    knob.Position = UDim2.new(alpha, 0, 0.5, 0)
                end

                local object = makeValueObject(id,
                    math.clamp(controlOptions.Default or minimum, minimum, maximum),
                    controlOptions.Callback, setDisplay)
                setDisplay(object.Value)

                local dragging = false

                local function setFromInput(input)
                    local alpha = math.clamp(
                        (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X,
                        0, 1
                    )
                    object:SetValue(minimum + (maximum - minimum) * alpha)
                end

                track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        setFromInput(input)
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch) then
                        setFromInput(input)
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)

                result.Options[id] = object
                return object
            end

            function section:AddButton(id, controlOptions)
                controlOptions = controlOptions or {}
                local button = create("TextButton", {
                    BackgroundColor3 = Colors.Background,
                    BorderSizePixel = 0,
                    Font = Enum.Font.Gotham,
                    Size = UDim2.new(1, 0, 0, 38),
                    Text = controlOptions.Text or id,
                    TextColor3 = Colors.Text,
                    TextSize = 12,
                }, rows)
                round(button, 5)

                button.Activated:Connect(function()
                    if controlOptions.Callback then
                        controlOptions.Callback(true)
                    end
                end)

                return button
            end

            return section
        end

        if not selectedTab then
            selectTab(tab)
        end

        return tab
    end

    function result:Toggle()
        screen.Enabled = not screen.Enabled
    end

    function result:SetKeybind(key)
        self.Keybind = key
    end

    closeButton.Activated:Connect(function()
        screen.Enabled = false
    end)

    minimizeButton.Activated:Connect(function()
        if body.Visible then
            body.Visible = false
            window.Size = UDim2.new(window.Size.X.Scale, window.Size.X.Offset, 0, 42)
        else
            window.Size = UDim2.fromOffset(500, 500)
            body.Visible = true
        end
    end)

    -- Drag окна
    local dragging = false
    local dragInput
    local dragStart
    local holderStart

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            holderStart = holder.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input == dragInput
            or input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            holder.Position = UDim2.fromOffset(
                holderStart.X.Offset + delta.X,
                holderStart.Y.Offset + delta.Y
            )
            clampHolder()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Keybind для показа/скрытия
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode == result.Keybind then
            result:Toggle()
        end
    end)

    -- Адаптив
    local camera = workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            updateScale()
            clampHolder()
        end)
    end

    updateScale()

    -- Автоматически создаём 4 вкладки
    for _, name in ipairs({ "General", "Visuals", "Exploits", "Settings" }) do
        result:AddTab(name)
    end

    return result
end

return UI
