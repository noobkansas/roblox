--!nonstrict
--[[
	全玩家头顶大天线 V11（回滚天线方案 + UI 抗闪烁）
	放置位置：StarterPlayer > StarterPlayerScripts（LocalScript）
	或执行器直接注入

	V11 关键：
	  · 天线回滚 Anchored = true + 每帧 CFrame（不摆头）
	  · UI 重建加 2 秒冷却，避免疯狂闪烁
	  · 去掉十字线
	  · 外框细淡：Thickness 1, Transparency 0.85
	  · ZIndexBehavior 回 Sibling
可调参数（脚本顶部）：
天线高度 160 POLE_HEIGHT
天线粗细 0.8 POLE_THICK
天线离头距离 2 ANTENNA_BOTTOM_OFFSET
名字字号 18 NAME_TEXT_SIZE
距离字号 14 DIST_TEXT_SIZE
雷达半径 150 RADAR_RADIUS
雷达范围 375 RADAR_MAX_DIST
雷达点大小 7 RADAR_DOT_SIZE
刷新间隔 0.05 REFRESH_RATE
显示自己 false SHOW_FOR_SELF
]]

print("[Antenna V11] 脚本开始加载...")

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- 等待 LocalPlayer 就绪
local localPlayer
for _ = 1, 50 do
	localPlayer = Players.LocalPlayer
	if localPlayer then break end
	task.wait(0.1)
end

if not localPlayer then
	warn("[Antenna] 无法获取 LocalPlayer，脚本退出")
	return
end

-- 等待 PlayerGui
local playerGui = localPlayer:WaitForChild("PlayerGui", 30)
if not playerGui then
	warn("[Antenna] 无法获取 PlayerGui，脚本退出")
	return
end

--=====================================================
-- 配置
--=====================================================
local ANTENNA_NAME  = "RedAntenna"
local REFRESH_RATE  = 0.05

local SHOW_FOR_SELF = false

-- 天线（Anchored + 每帧 CFrame）
local POLE_HEIGHT   = 160
local POLE_THICK    = 0.8
local BALL_SIZE     = 4
local ANTENNA_BOTTOM_OFFSET = 2

local DEFAULT_COLOR = Color3.fromRGB(255, 40, 40)

-- 名字 + 距离
local NAME_TEXT_SIZE  = 18
local DIST_TEXT_SIZE  = 14
local NAME_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local NAME_BOX_SIZE_X = 220
local NAME_BOX_SIZE_Y = 56
local NAME_OFFSET_Y   = 3

-- 雷达
local RADAR_RADIUS   = 150
local RADAR_MAX_DIST = 375
local RADAR_DOT_SIZE = 7
local RADAR_BG_TRANS = 0.92

-- ★ UI 重建冷却
local UI_CHECK_INTERVAL  = 0.5
local UI_REBUILD_COOLDOWN = 2.0

--=====================================================
-- UI 父级
--=====================================================
local function getUIParent()
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui, "gethui" end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then
		local test = Instance.new("Folder")
		local ok2 = pcall(function() test.Parent = cg end)
		if ok2 then
			test:Destroy()
			return cg, "CoreGui"
		end
		test:Destroy()
	end
	return playerGui, "PlayerGui"
end

local uiParent, uiParentName = getUIParent()
print("[Antenna] UI 挂载到：" .. uiParentName)

--=====================================================
-- 清理旧残留
--=====================================================
local function cleanOld()
	local count = 0
	local stack = { Workspace }
	while #stack > 0 do
		local node = table.remove(stack)
		for _, child in ipairs(node:GetChildren()) do
			if child.Name == ANTENNA_NAME then
				pcall(function() child:Destroy() end)
				count += 1
			else
				stack[#stack + 1] = child
			end
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local head = char and char:FindFirstChild("Head")
		if head then
			for _, d in ipairs(head:GetChildren()) do
				if d.Name == ANTENNA_NAME or (d.Name == "NameTag" and d:IsA("BillboardGui")) then
					pcall(function() d:Destroy() end)
					count += 1
				end
			end
		end
	end
	print("[Antenna] 清理了 " .. count .. " 个旧残留")
end

cleanOld()

for _, g in ipairs(playerGui:GetChildren()) do
	if g.Name == "PlayerRadarGui" then g:Destroy() end
end
if uiParent ~= playerGui then
	local ok, children = pcall(function() return uiParent:GetChildren() end)
	if ok and children then
		for _, g in ipairs(children) do
			if g.Name == "PlayerRadarGui" then g:Destroy() end
		end
	end
end

--=====================================================
-- 颜色
--=====================================================
local function getColorForPlayer(plr)
	if plr.Team then
		return plr.Team.TeamColor.Color
	end
	return DEFAULT_COLOR
end

--=====================================================
-- 天线（★ V11：Anchored = true + 每帧 CFrame）
--=====================================================
local function createAntenna(head, color)
	local model = Instance.new("Model")
	model.Name = ANTENNA_NAME

	local pole = Instance.new("Part")
	pole.Name         = "Pole"
	pole.Anchored     = true
	pole.CanCollide   = false
	pole.CanTouch     = false
	pole.CanQuery     = false
	pole.CastShadow   = false
	pole.Locked       = true
	pole.Massless     = true
	pole.Material     = Enum.Material.Neon
	pole.Color        = color
	pole.Transparency = 0
	pole.Size         = Vector3.new(POLE_THICK, POLE_HEIGHT, POLE_THICK)
	pole.Parent       = model

	local ball = Instance.new("Part")
	ball.Name         = "Tip"
	ball.Shape        = Enum.PartType.Ball
	ball.Anchored     = true
	ball.CanCollide   = false
	ball.CanTouch     = false
	ball.CanQuery     = false
	ball.CastShadow   = false
	ball.Locked       = true
	ball.Massless     = true
	ball.Material     = Enum.Material.Neon
	ball.Color        = color
	ball.Size         = Vector3.new(BALL_SIZE, BALL_SIZE, BALL_SIZE)
	ball.Parent       = model

	local light = Instance.new("PointLight")
	light.Color      = color
	light.Brightness = 6
	light.Range      = 20
	light.Shadows    = false
	light.Parent     = ball

	local hl = Instance.new("Highlight")
	hl.Name                = "AntennaHighlight"
	hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillColor           = color
	hl.FillTransparency    = 0.35
	hl.OutlineColor        = color
	hl.OutlineTransparency = 0
	hl.Adornee             = model
	hl.Parent              = model

	model.Parent = head
	return model
end

--=====================================================
-- 名字 + 距离
--=====================================================
local function ensureNameTag(head, color, displayName)
	local tag = head:FindFirstChild("NameTag")
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name           = "NameTag"
		tag.Size           = UDim2.fromOffset(NAME_BOX_SIZE_X, NAME_BOX_SIZE_Y)
		tag.AlwaysOnTop    = true
		tag.LightInfluence = 0
		tag.MaxDistance    = 100000
		tag.Adornee        = head
		tag.StudsOffset    = Vector3.new(0, NAME_OFFSET_Y, 0)
		tag.Parent         = head

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name                   = "NameLabel"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size                   = UDim2.new(1, 0, 0.62, 0)
		nameLabel.Position               = UDim2.new(0, 0, 0, 0)
		nameLabel.Font                   = Enum.Font.GothamBold
		nameLabel.Text                   = displayName
		nameLabel.TextSize               = NAME_TEXT_SIZE
		nameLabel.TextColor3             = NAME_TEXT_COLOR
		nameLabel.TextStrokeColor3       = color
		nameLabel.TextStrokeTransparency = 0
		nameLabel.Parent                 = tag

		local distLabel = Instance.new("TextLabel")
		distLabel.Name                   = "DistLabel"
		distLabel.BackgroundTransparency = 1
		distLabel.Size                   = UDim2.new(1, 0, 0.38, 0)
		distLabel.Position               = UDim2.new(0, 0, 0.62, 0)
		distLabel.Font                   = Enum.Font.Gotham
		distLabel.Text                   = "..."
		distLabel.TextSize               = DIST_TEXT_SIZE
		distLabel.TextColor3             = Color3.fromRGB(220, 220, 220)
		distLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
		distLabel.TextStrokeTransparency = 0
		distLabel.Parent                 = tag
	end

	local nameLabel = tag:FindFirstChild("NameLabel")
	if nameLabel then
		if nameLabel.Text ~= displayName then
			nameLabel.Text = displayName
		end
		if nameLabel.TextStrokeColor3 ~= color then
			nameLabel.TextStrokeColor3 = color
		end
	end

	return tag
end

--=====================================================
-- 雷达
--=====================================================
local radarGui, radarFrame, radarDots
local dotPool = {}
local lastRebuildTime = 0

local function buildRadar()
	-- ★ V11：先清掉所有可能存在的同名 GUI
	local function tryClear(parent)
		if not parent then return end
		local ok, children = pcall(function() return parent:GetChildren() end)
		if not ok or not children then return end
		for _, g in ipairs(children) do
			if g.Name == "PlayerRadarGui" then
				pcall(function() g:Destroy() end)
			end
		end
	end
	tryClear(uiParent)
	tryClear(playerGui)

	radarGui = Instance.new("ScreenGui")
	radarGui.Name = "PlayerRadarGui"
	radarGui.ResetOnSpawn = false
	radarGui.IgnoreGuiInset = true
	radarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling   -- ★ 回 Sibling
	local ok = pcall(function() radarGui.Parent = uiParent end)
	if not ok then
		radarGui.Parent = playerGui
	end

	radarFrame = Instance.new("Frame")
	radarFrame.Name = "Radar"
	radarFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	radarFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	radarFrame.Size = UDim2.fromOffset(RADAR_RADIUS * 2, RADAR_RADIUS * 2)
	radarFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	radarFrame.BackgroundTransparency = RADAR_BG_TRANS
	radarFrame.BorderSizePixel = 0
	radarFrame.Parent = radarGui
	Instance.new("UICorner", radarFrame).CornerRadius = UDim.new(1, 0)

	-- ★ V11：外框更细更淡
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(80, 220, 130)
	st.Thickness = 1
	st.Transparency = 0.85
	st.Parent = radarFrame

	-- ★ V11：去掉十字线

	-- 中心点
	local cd = Instance.new("Frame")
	cd.AnchorPoint = Vector2.new(0.5, 0.5)
	cd.Position = UDim2.new(0.5, 0, 0.5, 0)
	cd.Size = UDim2.fromOffset(5, 5)
	cd.BackgroundColor3 = Color3.fromRGB(80, 220, 130)
	cd.BackgroundTransparency = 0.7
	cd.BorderSizePixel = 0
	cd.ZIndex = 5
	cd.Parent = radarFrame
	Instance.new("UICorner", cd).CornerRadius = UDim.new(1, 0)

	radarDots = Instance.new("Frame")
	radarDots.Name = "Dots"
	radarDots.BackgroundTransparency = 1
	radarDots.Size = UDim2.new(1, 0, 1, 0)
	radarDots.ClipsDescendants = false
	radarDots.ZIndex = 3
	radarDots.Parent = radarFrame

	-- ★ V11：只清掉已失效的池引用
	for plr, d in pairs(dotPool) do
		if not d.frame or not d.frame.Parent then
			dotPool[plr] = nil
		end
	end
end

buildRadar()
lastRebuildTime = tick()

-- ★ V11：0.5 秒检测 + 2 秒冷却
task.spawn(function()
	while true do
		task.wait(UI_CHECK_INTERVAL)
		if radarGui and not radarGui.Parent then
			if tick() - lastRebuildTime >= UI_REBUILD_COOLDOWN then
				lastRebuildTime = tick()
				pcall(buildRadar)
			end
		end
	end
end)

--=====================================================
-- 小圆点
--=====================================================
local function getOrCreateDot(plr)
	local d = dotPool[plr]
	if d and d.frame and d.frame.Parent == radarDots then
		return d
	end

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(RADAR_DOT_SIZE, RADAR_DOT_SIZE)
	dot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	dot.BorderSizePixel = 0
	dot.ZIndex = 4
	dot.Parent = radarDots
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1
	stroke.Transparency = 0.2
	stroke.Parent = dot

	local lbl = Instance.new("TextLabel")
	lbl.Name                   = "DistLbl"
	lbl.AnchorPoint            = Vector2.new(0.5, 0)
	lbl.Position               = UDim2.new(0.5, 0, 1, 1)
	lbl.Size                   = UDim2.fromOffset(60, 12)
	lbl.BackgroundTransparency = 1
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextSize               = 10
	lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	lbl.Text                   = ""
	lbl.ZIndex                 = 5
	lbl.Parent                 = dot

	dotPool[plr] = { frame = dot, label = lbl }
	return dotPool[plr]
end

--=====================================================
-- 雷达更新
--=====================================================
local function updateRadar()
	if not radarDots or not radarDots.Parent then return end

	local myChar = localPlayer.Character
	local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myHrp then return end

	local cam = Workspace.CurrentCamera
	if not cam then return end

	local myPos = myHrp.Position

	local look = cam.CFrame.LookVector
	local fx, fz = look.X, look.Z
	local len = math.sqrt(fx * fx + fz * fz)
	if len < 0.001 then
		fx, fz = 0, -1
		len = 1
	end
	fx, fz = fx / len, fz / len
	local rx, rz = -fz, fx

	local scale = RADAR_RADIUS / RADAR_MAX_DIST
	local seen = {}

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= localPlayer then
			local char = plr.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local rel = hrp.Position - myPos
				local fDist = rel.X * fx + rel.Z * fz
				local rDist = rel.X * rx + rel.Z * rz
				local distXZ = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)

				if distXZ <= RADAR_MAX_DIST then
					local px = rDist * scale
					local py = -fDist * scale
					if px * px + py * py <= RADAR_RADIUS * RADAR_RADIUS then
						local d = getOrCreateDot(plr)
						d.frame.Position = UDim2.new(0.5, px, 0.5, py)
						d.frame.Visible = true
						local col = getColorForPlayer(plr)
						if d.frame.BackgroundColor3 ~= col then
							d.frame.BackgroundColor3 = col
						end
						local newText
						if distXZ >= 1000 then
							newText = string.format("%.1fkm", distXZ / 1000)
						else
							newText = string.format("%.0fm", distXZ)
						end
						if d.label.Text ~= newText then
							d.label.Text = newText
						end
						seen[plr] = true
					end
				end
			end
		end
	end

	for plr, d in pairs(dotPool) do
		if not seen[plr] then
			if d.frame and d.frame.Parent then
				if d.frame.Visible then
					d.frame.Visible = false
				end
			else
				dotPool[plr] = nil
			end
		end
	end
end

--=====================================================
-- 单个玩家天线
--=====================================================
local function updatePlayerAntenna(plr)
	if not SHOW_FOR_SELF and plr == localPlayer then
		local char = plr.Character
		local head = char and char:FindFirstChild("Head")
		if head then
			local a = head:FindFirstChild(ANTENNA_NAME)
			if a then a:Destroy() end
			local t = head:FindFirstChild("NameTag")
			if t then t:Destroy() end
		end
		return
	end

	local char = plr.Character
	if not char then return end

	local head = char:FindFirstChild("Head")
	if not head then return end
	if not head:IsDescendantOf(Workspace) then return end

	local hp = head.Position
	if hp.Magnitude < 0.1 then return end

	local color = getColorForPlayer(plr)
	local displayName = plr.DisplayName ~= "" and plr.DisplayName or plr.Name

	local model = head:FindFirstChild(ANTENNA_NAME)
	if model and (not model:FindFirstChild("Pole") or not model:FindFirstChild("Tip")) then
		model:Destroy()
		model = nil
	end
	if not model then
		model = createAntenna(head, color)
	end

	local pole = model:FindFirstChild("Pole")
	local ball = model:FindFirstChild("Tip")

	-- ★ V11：每帧 CFrame 更新位置
	local headTopY = hp.Y + head.Size.Y * 0.5
	local baseY    = headTopY + ANTENNA_BOTTOM_OFFSET
	local poleCY   = baseY + POLE_HEIGHT * 0.5
	local ballY    = baseY + POLE_HEIGHT

	if pole then
		pole.CFrame = CFrame.new(hp.X, poleCY, hp.Z)
	end
	if ball then
		ball.CFrame = CFrame.new(hp.X, ballY, hp.Z)
	end

	if pole and pole.Color ~= color then pole.Color = color end
	if ball and ball.Color ~= color then
		ball.Color = color
		local light = ball:FindFirstChildOfClass("PointLight")
		if light then light.Color = color end
	end
	local hl = model:FindFirstChild("AntennaHighlight")
	if hl and hl.FillColor ~= color then
		hl.FillColor    = color
		hl.OutlineColor = color
	end

	local tag = ensureNameTag(head, color, displayName)
	local distLabel = tag:FindFirstChild("DistLabel")
	if distLabel then
		local localChar = localPlayer.Character
		local localHrp  = localChar and localChar:FindFirstChild("HumanoidRootPart")
		if localHrp then
			local dist = (localHrp.Position - hp).Magnitude
			local newText
			if dist >= 1000 then
				newText = string.format("%.2fkm", dist / 1000)
			else
				newText = string.format("%.0fm", dist)
			end
			if distLabel.Text ~= newText then
				distLabel.Text = newText
			end
		end
	end
end

--=====================================================
-- 主循环
--=====================================================
print("[Antenna] 启动主循环")

task.spawn(function()
	while true do
		for _, plr in ipairs(Players:GetPlayers()) do
			local ok, err = pcall(updatePlayerAntenna, plr)
			if not ok then
				warn("[Antenna] " .. tostring(err))
			end
		end

		local ok2, err2 = pcall(updateRadar)
		if not ok2 then
			warn("[Radar] " .. tostring(err2))
		end

		task.wait(REFRESH_RATE)
	end
end)

--=====================================================
-- 事件绑定
--=====================================================
local function attachPlayer(plr)
	plr.CharacterAdded:Connect(function(char)
		char:WaitForChild("Head", 10)
		task.wait(0.1)
		pcall(updatePlayerAntenna, plr)
	end)
	if plr.Character then
		pcall(updatePlayerAntenna, plr)
	end
	plr:GetPropertyChangedSignal("Team"):Connect(function()
		pcall(updatePlayerAntenna, plr)
	end)
	plr:GetPropertyChangedSignal("DisplayName"):Connect(function()
		pcall(updatePlayerAntenna, plr)
	end)
end

for _, plr in ipairs(Players:GetPlayers()) do
	attachPlayer(plr)
end
Players.PlayerAdded:Connect(attachPlayer)

print("[Antenna] 加载完成 — 当前玩家数：" .. #Players:GetPlayers())

--=====================================================
-- 清理
--=====================================================
pcall(function()
	if script then
		script.Destroying:Connect(function()
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				local head = char and char:FindFirstChild("Head")
				if head then
					local a = head:FindFirstChild(ANTENNA_NAME)
					if a then pcall(function() a:Destroy() end) end
					local t = head:FindFirstChild("NameTag")
					if t then pcall(function() t:Destroy() end) end
				end
			end
			if radarGui then pcall(function() radarGui:Destroy() end) end
		end)
	end
end)
