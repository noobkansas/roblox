--!strict
-- BunnyHop.client.luau  v1.5.0
-- 物理驱动 + 版本校验
-- 起跳瞬间直接把水平速度拉到目标值，第一跳即全速
-- 按 N 切换

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- ==================== 版本校验 ====================
local SCRIPT_VERSION = "1.5.0"
local MIN_PLACE_VERSION = 0
local MIN_SUPPORTED = "1.0.0"

local function versionGte(a: string, b: string): boolean
	local at, bt = {}, {}
	for n in string.gmatch(a, "[^.]+") do table.insert(at, tonumber(n) or 0) end
	for n in string.gmatch(b, "[^.]+") do table.insert(bt, tonumber(n) or 0) end
	for i = 1, math.max(#at, #bt) do
		local av, bv = at[i] or 0, bt[i] or 0
		if av > bv then return true end
		if av < bv then return false end
	end
	return true
end

local function validateVersion(): (boolean, string?)
	if not versionGte(SCRIPT_VERSION, "1.0.0") then
		return false, "脚本版本号格式异常: " .. SCRIPT_VERSION
	end
	if game.PlaceVersion < MIN_PLACE_VERSION then
		return false, string.format("游戏版本过低 (%d < %d)", game.PlaceVersion, MIN_PLACE_VERSION)
	end
	if not versionGte(SCRIPT_VERSION, MIN_SUPPORTED) then
		return false, string.format("脚本版本过低 (%s < %s)", SCRIPT_VERSION, MIN_SUPPORTED)
	end
	return true, nil
end

local versionOk, versionErr = validateVersion()
if not versionOk then warn("[BunnyHop] 版本校验失败: " .. tostring(versionErr)) end

-- ==================== 基础引用 ====================
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

-- ==================== 可调参数 ====================
local JUMP_VELOCITY = 24          -- 跳跃垂直速度
local SPEED_MULTIPLIER = 5      -- 水平速度倍率
local INSTANT_LAUNCH = true       -- ★ 起跳瞬间直接顶满水平速度
local ACCEL_STIFFNESS = 222       -- 地面加速度刚度（加大，地面很快就到目标）
local MAX_FORCE_PER_MASS = 800    -- 单位质量最大力
local AIR_SPEED_KEEP = 1.0        -- ★ 空中完全不衰减
local JUMP_COOLDOWN = 0.05

local bunnyHopEnabled = false
local baseWalkSpeed = 16
local nextJumpTime = 0
local forceConstraint: VectorForce? = nil
local attachment: Attachment? = nil

-- ==================== UI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "BunnyHopGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(400, 52)
label.Position = UDim2.new(0.5, -200, 0, 16)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
label.BackgroundTransparency = 0.35
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.Font = Enum.Font.GothamMedium
label.TextSize = 15
label.TextYAlignment = Enum.TextYAlignment.Center
label.Text = ""
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local function updateLabel()
	if not versionOk then
		label.Text = string.format("兔子跳 v%s\n版本校验失败: %s", SCRIPT_VERSION, tostring(versionErr))
		label.TextColor3 = Color3.fromRGB(255, 120, 120)
		return
	end
	if bunnyHopEnabled then
		label.Text = string.format(
			"兔子跳：开启 (物理驱动, 水平 x%.1f)  v%s",
			SPEED_MULTIPLIER, SCRIPT_VERSION
		)
		label.TextColor3 = Color3.fromRGB(120, 255, 140)
	else
		label.Text = string.format("兔子跳：关闭 (按 N 切换)  v%s", SCRIPT_VERSION)
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

-- ==================== 约束管理 ====================
local function cleanupConstraint()
	if forceConstraint then forceConstraint:Destroy() forceConstraint = nil end
	if attachment then attachment:Destroy() attachment = nil end
end

local function setupConstraint()
	cleanupConstraint()
	if not character or not character.Parent then return end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	attachment = Instance.new("Attachment")
	attachment.Name = "BunnyHopAttach"
	attachment.Parent = hrp

	forceConstraint = Instance.new("VectorForce")
	forceConstraint.Name = "BunnyHopForce"
	forceConstraint.Attachment0 = attachment
	forceConstraint.RelativeTo = Enum.ActuatorRelativeTo.World
	forceConstraint.Force = Vector3.zero
	forceConstraint.Enabled = false
	forceConstraint.Parent = hrp
end

-- ==================== 角色重生 ====================
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid") :: Humanoid
	baseWalkSpeed = humanoid.WalkSpeed
	nextJumpTime = 0
	setupConstraint()
	if bunnyHopEnabled and versionOk then
		humanoid.WalkSpeed = baseWalkSpeed * SPEED_MULTIPLIER
	end
end)

setupConstraint()

-- ==================== 按键切换 ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.N then return end
	if not versionOk then
		warn("[BunnyHop] 版本校验未通过，无法启用")
		return
	end

	bunnyHopEnabled = not bunnyHopEnabled

	if humanoid then
		if bunnyHopEnabled then
			baseWalkSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = baseWalkSpeed * SPEED_MULTIPLIER
		else
			humanoid.WalkSpeed = baseWalkSpeed
			if forceConstraint then forceConstraint.Enabled = false end
		end
	end

	updateLabel()
	print(string.format("[BunnyHop v%s] %s", SCRIPT_VERSION, bunnyHopEnabled and "开启" or "关闭"))
end)

-- ==================== 物理驱动核心 ====================
RunService.PreSimulation:Connect(function()
	if not versionOk then return end

	if not forceConstraint or not forceConstraint.Parent then
		setupConstraint()
		if not forceConstraint then return end
	end

	if not bunnyHopEnabled then
		forceConstraint.Enabled = false
		return
	end
	if not humanoid or humanoid.Health <= 0 then return end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local moveDir = humanoid.MoveDirection

	-- 不移动：撤掉推力
	if moveDir.Magnitude < 0.1 then
		forceConstraint.Enabled = false
		return
	end

	local v = hrp.AssemblyLinearVelocity
	local horiz = Vector3.new(v.X, 0, v.Z)
	local targetSpeed = baseWalkSpeed * SPEED_MULTIPLIER
	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air

	if onGround then
		-- === 地面：比例力加速，速度到目标就停 ===
		local speedError = targetSpeed - horiz.Magnitude
		if speedError > 0.5 then
			local mass = hrp.AssemblyMass
			local mag = math.min(speedError * mass * ACCEL_STIFFNESS, mass * MAX_FORCE_PER_MASS)
			forceConstraint.Force = moveDir.Unit * mag
			forceConstraint.Enabled = true
		else
			forceConstraint.Enabled = false
		end

		-- 落地起跳
		local now = os.clock()
		if now >= nextJumpTime and v.Y <= 0.5 then
			nextJumpTime = now + JUMP_COOLDOWN

			local launchHoriz = horiz
			-- ★ 关键：起跳瞬间直接把水平速度顶到目标值
			if INSTANT_LAUNCH and horiz.Magnitude < targetSpeed then
				launchHoriz = moveDir.Unit * targetSpeed
			end
			hrp.AssemblyLinearVelocity = Vector3.new(launchHoriz.X, JUMP_VELOCITY, launchHoriz.Z)
		end
	else
		-- === 空中：直接维持水平速度 ===
		forceConstraint.Enabled = false

		local newHoriz = horiz
		-- 空中继续按移动方向补到目标速度（即使起跳时没顶满，空中也会继续加速）
		if horiz.Magnitude < targetSpeed then
			newHoriz = moveDir.Unit * targetSpeed
		end
		-- AIR_SPEED_KEEP = 1 时完全保持，不做衰减
		if AIR_SPEED_KEEP < 1 then
			newHoriz = newHoriz * AIR_SPEED_KEEP
		end

		hrp.AssemblyLinearVelocity = Vector3.new(newHoriz.X, v.Y, newHoriz.Z)
	end
end)

updateLabel()
