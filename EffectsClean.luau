-- 一键删除全图特效/粒子/烟雾 (客户端)
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function cleanEffects()
    local count = 0
    -- 遍历所有对象
    for _, obj in ipairs(game:GetDescendants()) do
        -- 检查是否为特效类型
        if obj:IsA("ParticleEmitter") or
           obj:IsA("Smoke") or
           obj:IsA("Fire") or
           obj:IsA("Sparkles") or
           obj:IsA("Trail") or
           obj:IsA("Beam") or
           obj:IsA("Attachment") and obj:FindFirstChildWhichIsA("ParticleEmitter") then
            -- 如果是附件且包含粒子发射器，删除粒子发射器（可选）
            if obj:IsA("Attachment") then
                local pe = obj:FindFirstChildWhichIsA("ParticleEmitter")
                if pe then pe:Destroy(); count = count + 1 end
            else
                obj:Destroy()
                count = count + 1
            end
        end
    end
    return count
end

-- 创建 UI
local gui = Instance.new("ScreenGui")
gui.Name = "EffectCleaner"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 80)
frame.Position = UDim2.new(0.5, -100, 0.5, -40)
frame.BackgroundColor3 = Color3.fromRGB(30,30,40)
frame.Draggable = true
frame.Active = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.BackgroundTransparency = 1
title.Text = "🧹 特效清理"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextSize = 16
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -10, 0, 20)
statusLabel.Position = UDim2.new(0, 5, 0, 32)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "点击下方按钮清理"
statusLabel.TextColor3 = Color3.fromRGB(200,200,200)
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

local cleanBtn = Instance.new("TextButton")
cleanBtn.Size = UDim2.new(0, 120, 0, 30)
cleanBtn.Position = UDim2.new(0.5, -60, 0.5, 20)
cleanBtn.BackgroundColor3 = Color3.fromRGB(60,80,100)
cleanBtn.Text = "删除所有特效"
cleanBtn.TextColor3 = Color3.fromRGB(255,255,255)
cleanBtn.TextSize = 14
cleanBtn.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -30, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.Parent = frame
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

cleanBtn.MouseButton1Click:Connect(function()
    cleanBtn.Text = "清理中..."
    cleanBtn.BackgroundColor3 = Color3.fromRGB(80,60,60)
    statusLabel.Text = "正在清理..."
    task.wait(0.1)  -- 让UI更新
    local count = cleanEffects()
    statusLabel.Text = string.format("已删除 %d 个特效对象", count)
    cleanBtn.Text = "删除所有特效"
    cleanBtn.BackgroundColor3 = Color3.fromRGB(60,80,100)
end)
