local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoRebirthGUI_v3"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 10000
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 200)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local TitleBar = Instance.new("TextButton")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TitleBar.Text = "Auto Rebirth"
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.Font = Enum.Font.GothamBold
TitleBar.TextSize = 14
TitleBar.BorderSizePixel = 0
TitleBar.AutoButtonColor = false
TitleBar.Parent = MainFrame

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 1, 0)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 1, 0)
MinimizeBtn.Position = UDim2.new(1, -60, 0, 0)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
MinimizeBtn.Text = "_"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Parent = TitleBar

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -30)
ContentFrame.Position = UDim2.new(0, 0, 0, 30)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local EventLabel = Instance.new("TextLabel")
EventLabel.Size = UDim2.new(1, -10, 0, 15)
EventLabel.Position = UDim2.new(0, 5, 0, 5)
EventLabel.BackgroundTransparency = 1
EventLabel.Text = "Event Name:"
EventLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
EventLabel.Font = Enum.Font.Gotham
EventLabel.TextSize = 12
EventLabel.TextXAlignment = Enum.TextXAlignment.Left
EventLabel.Parent = ContentFrame

local EventBox = Instance.new("TextBox")
EventBox.Size = UDim2.new(1, -10, 0, 25)
EventBox.Position = UDim2.new(0, 5, 0, 20)
EventBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
EventBox.Text = ""
EventBox.TextColor3 = Color3.fromRGB(255, 255, 255)
EventBox.Font = Enum.Font.Gotham
EventBox.TextSize = 12
EventBox.PlaceholderText = "Enter Event Name"
EventBox.ClearTextOnFocus = false
EventBox.Parent = ContentFrame

local FreqLabel = Instance.new("TextLabel")
FreqLabel.Size = UDim2.new(1, -10, 0, 15)
FreqLabel.Position = UDim2.new(0, 5, 0, 50)
FreqLabel.BackgroundTransparency = 1
FreqLabel.Text = "Frequency (Hz):"
FreqLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
FreqLabel.Font = Enum.Font.Gotham
FreqLabel.TextSize = 12
FreqLabel.TextXAlignment = Enum.TextXAlignment.Left
FreqLabel.Parent = ContentFrame

local FreqBox = Instance.new("TextBox")
FreqBox.Size = UDim2.new(1, -10, 0, 25)
FreqBox.Position = UDim2.new(0, 5, 0, 65)
FreqBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
FreqBox.Text = "2"
FreqBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FreqBox.Font = Enum.Font.Gotham
FreqBox.TextSize = 14
FreqBox.PlaceholderText = "Enter Hz"
FreqBox.ClearTextOnFocus = false
FreqBox.Parent = ContentFrame

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -10, 0, 35)
ToggleBtn.Position = UDim2.new(0, 5, 0, 100)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
ToggleBtn.Text = "START"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 14
ToggleBtn.Parent = ContentFrame

local UICornerBtn = Instance.new("UICorner")
UICornerBtn.CornerRadius = UDim.new(0, 4)
UICornerBtn.Parent = ToggleBtn

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 0, 15)
StatusLabel.Position = UDim2.new(0, 5, 0, 145)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Stopped"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = ContentFrame

local foundName = ""
for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
    if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
        if child.Name:lower():find("rebirth") then
            foundName = child.Name
            break
        end
    end
end
EventBox.Text = foundName

local dragging = false
local dragInput, dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame.Size = UDim2.new(0, 220, 0, 30)
        ContentFrame.Visible = false
        MinimizeBtn.Text = "^"
    else
        MainFrame.Size = UDim2.new(0, 220, 0, 200)
        ContentFrame.Visible = true
        MinimizeBtn.Text = "_"
    end
end)

local running = false

local function fireRebirth()
    local eventName = EventBox.Text
    if eventName == "" then return end
    local targetEvent = ReplicatedStorage:FindFirstChild(eventName, true)
    if not targetEvent then return end
    
    pcall(function()
        for i = 1, 10 do
            task.spawn(function()
                if targetEvent:IsA("RemoteEvent") then
                    targetEvent:FireServer("rebirthRequest")
                elseif targetEvent:IsA("RemoteFunction") then
                    targetEvent:InvokeServer("rebirthRequest")
                end
            end)
        end
    end)
end

local function startLoop()
    if EventBox.Text == "" then
        StatusLabel.Text = "Error: No Event Name"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    running = true
    ToggleBtn.Text = "STOP"
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    StatusLabel.Text = "Status: Running"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    
    task.spawn(function()
        while running do
            local freq = tonumber(FreqBox.Text)
            if not freq or freq <= 0 then freq = 2 end
            local interval = 1 / freq
            fireRebirth()
            task.wait(interval)
        end
    end)
end

local function stopLoop()
    running = false
    ToggleBtn.Text = "START"
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    StatusLabel.Text = "Status: Stopped"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
end

ToggleBtn.MouseButton1Click:Connect(function()
    if running then
        stopLoop()
    else
        startLoop()
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    stopLoop()
    ScreenGui:Destroy()
end)
