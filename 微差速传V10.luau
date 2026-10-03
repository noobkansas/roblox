--!strict
--!native
--[[
====================================================================================
  MicroOffsetSpeed · 微差速传  v10  (33 档至 ×10 · 前馈+有界积分 · 多通道单实例)
====================================================================================
  v10 修复「一直被覆盖 / 拉满→归零→拉满 / 一直熔断」
    根因 1：输出上限(前馈×1.6) 与 熔断线(实测×1.18) 自相矛盾 → 必然极限环
            → 上限压到 前馈×1.20；因为 总速度/目标 < 1.20 < 熔断线1.35
              自身动作数学上不可能触发熔断
    根因 2：地面门控 → 高速时 FloorMaterial 闪成 Air 就停补偿，落地再补
            → 移除地面门控（只补水平、Y 恒 0，本来就不会飞天）
    根因 3：顶墙时误差大 → 积分顶格 → 脱困瞬间爆发 → 再次熔断
            → 斜坡接近 0 时积分主动泄放
    根因 4：两个执行器 gethui 指向不同容器 → 文件夹锁互相看不见
            → 增加 LocalPlayer 属性通道（DataModel 级，跨执行器必然共享）
    根因 5：两个实例都在补偿的窗口期
            → 所有权连续 2 次心跳确认后才允许写入

  功能
    · 33 档倍率 1.05 → 10.00（刻度尺最左 = 关闭）
    · 右下角刻度尺，拖动圆点 / 点击刻度 / 滚轮换档
    · 档位永久保存（存倍率，未来增删档不错位）
    · 完全不修改 Humanoid.WalkSpeed
    · 左下角按钮长按 2s 立刻卸载并严格清理全部连接与 UI

  控制律（前馈 + 有界积分）
    前馈   = WalkSpeed × (倍率 - 1)          ← 解析解，起点就正确
    积分   = ∫(目标 - 实测) / Ti，有界 ±25%   ← 消除被物理吃掉的部分
    输出   = clamp(前馈 + 积分, 0, 前馈×1.20) × 速度斜坡
    方向   = Humanoid.MoveDirection 水平单位向量

  安全模型
    · 输出下限恒为 0；上限 前馈×1.20；单帧位移另有硬上限
    · 总速度 / 目标 < 1.20（数学上界），熔断线 1.35 且需持续 0.4s
    · 速度斜坡：贴墙/被卡(自然速度≈0) 输出自动归零 → 不穿墙
    · 补偿向量 Y 恒为 0 → 不飞天
    · 积分有界 + 卡墙泄放 + 空转泄放
    · 目标速度绝对上限 500 stud/s
====================================================================================
]]

local SCRIPT_ID = "MicroOffsetSpeed"
local VERSION = 10
local SCHEMA_VERSION = 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

--====================================================================================
-- 常量
--====================================================================================

type Tier = {
	factor: number,
	label: string,
}

-- 33 档：低段 0.05 细步进，高段放大跨度
local SPEED_TIERS: { Tier } = table.freeze({
	{ factor = 1.05, label = "×1.05" },
	{ factor = 1.10, label = "×1.10" },
	{ factor = 1.15, label = "×1.15" },
	{ factor = 1.20, label = "×1.20" },
	{ factor = 1.25, label = "×1.25" },
	{ factor = 1.30, label = "×1.30" },
	{ factor = 1.35, label = "×1.35" },
	{ factor = 1.40, label = "×1.40" },
	{ factor = 1.45, label = "×1.45" },
	{ factor = 1.50, label = "×1.50" },
	{ factor = 1.60, label = "×1.60" },
	{ factor = 1.70, label = "×1.70" },
	{ factor = 1.80, label = "×1.80" },
	{ factor = 1.90, label = "×1.90" },
	{ factor = 2.00, label = "×2.00" },
	{ factor = 2.20, label = "×2.20" },
	{ factor = 2.40, label = "×2.40" },
	{ factor = 2.60, label = "×2.60" },
	{ factor = 2.80, label = "×2.80" },
	{ factor = 3.00, label = "×3.00" },
	{ factor = 3.25, label = "×3.25" },
	{ factor = 3.50, label = "×3.50" },
	{ factor = 3.75, label = "×3.75" },
	{ factor = 4.00, label = "×4.00" },
	{ factor = 4.50, label = "×4.50" },
	{ factor = 5.00, label = "×5.00" },
	{ factor = 5.50, label = "×5.50" },
	{ factor = 6.00, label = "×6.00" },
	{ factor = 6.50, label = "×6.50" },
	{ factor = 7.00, label = "×7.00" },
	{ factor = 8.00, label = "×8.00" },
	{ factor = 9.00, label = "×9.00" },
	{ factor = 10.00, label = "×10.0" },
})

local TIER_COUNT = #SPEED_TIERS
local KNOB_SIZE = 24
local PANEL_WIDTH = 320

local LOCK_CONFIG = table.freeze({
	folderName = "_MicroOffsetSpeedLock",
	staleTime = 1.0,          -- 心跳超时视为已死 (秒)
	pulseInterval = 0.15,     -- 仲裁心跳间隔 (秒)
	confirmChecks = 2,        -- 连续确认次数（达到后才允许写入）
	acquireBackoff = 0.08,    -- 启动时等待邻居写入 (秒)
})

local PERSIST = table.freeze({
	fileName = "MicroOffsetSpeed.json",
	debounce = 0.75,
})

local CONFIG = table.freeze({
	playerTimeout = 20,

	-- 网络所有权（best-effort）
	claimOwnership = true,
	ownershipOkInterval = 1.0,
	ownershipFailInterval = 3.0,

	-- 控制律：前馈 + 有界积分
	integralTime = 0.45,           -- 积分时间常数 (秒)
	integralLimit = 0.25,          -- 积分上限 = 前馈 × 该系数
	integralLeak = 0.25,           -- 空转 / 卡墙时积分泄放时间常数 (秒)
	outputCeiling = 1.20,          -- 输出上限 = 前馈 × 该系数
	grantAlpha = 0.55,             -- 输出低通

	-- 测量
	achievedAlpha = 0.30,          -- 实测速度低通
	naturalAlpha = 0.45,           -- 自然速度低通
	naturalClamp = 2.00,           -- 自然速度上限 = WalkSpeed × 该系数
	velocityDropRatio = 0.55,      -- 速度掉到该比例以下才还原（更保守）

	-- 安全斜坡（软门控，防穿墙）
	rampLow = 0.10,
	rampHigh = 0.35,

	-- 平滑
	factorEaseTime = 0.10,
	baseEaseTime = 0.12,

	-- 限幅
	maxStepScale = 3.0,
	maxStepBase = 0.15,
	maxTargetSpeed = 500,

	-- 重生
	spawnGrace = 0.25,

	-- 熔断（只针对真正的外部失控；自身动作上限 1.20 < 1.35）
	fuseBand = 1.35,
	fuseTime = 0.40,
	fuseCooldown = 1.00,
	logFuse = true,

	-- 环境阻力提示
	resistOutputFrac = 0.95,
	resistAchievedFrac = 0.80,
	resistTime = 0.60,

	-- UI
	holdSeconds = 2,
	readoutInterval = 0.08,
	resetConfirmWindow = 3,
})

local THEME = table.freeze({
	background = Color3.fromRGB(18, 18, 22),
	surface = Color3.fromRGB(28, 28, 34),
	stroke = Color3.fromRGB(58, 58, 70),
	text = Color3.fromRGB(236, 236, 246),
	subText = Color3.fromRGB(150, 150, 168),
	accent = Color3.fromRGB(96, 148, 255),
	success = Color3.fromRGB(86, 200, 122),
	danger = Color3.fromRGB(240, 92, 92),
	warn = Color3.fromRGB(240, 180, 80),
	pure = Color3.fromRGB(255, 255, 255),
})

local ZERO = Vector3.zero

--====================================================================================
-- 时间 / 执行器环境 / 通用工具
--====================================================================================

---墙钟秒（跨进程一致，用于跨执行器仲裁）
local function wallNow(): number
	local ok, ms = pcall(function()
		return DateTime.now().UnixTimestampMillis
	end)
	if ok and type(ms) == "number" then
		return ms / 1000
	end
	return os.time()
end

local function resolveExecutorEnvironment(): { [string]: any }
	local ok, env = pcall(getfenv, 1)
	if ok and type(env) == "table" then
		local getGenv: any = rawget(env, "getgenv")
		if type(getGenv) ~= "function" then
			getGenv = rawget(_G, "getgenv")
		end
		if type(getGenv) == "function" then
			local ok2, result = pcall(getGenv)
			if ok2 and type(result) == "table" then
				return result
			end
		end
	end
	return _G
end

local EXECUTOR_ENV: { [string]: any } = resolveExecutorEnvironment()

local function resolveExecutorFunction(name: string): any
	local ok, env = pcall(getfenv, 1)
	if ok and type(env) == "table" then
		local fn = rawget(env, name)
		if type(fn) == "function" then
			return fn
		end
	end
	local fn = rawget(EXECUTOR_ENV, name)
	if type(fn) == "function" then
		return fn
	end
	local global = rawget(_G, name)
	if type(global) == "function" then
		return global
	end
	return nil
end

local function waitForLocalPlayer(timeout: number): Player?
	local player = Players.LocalPlayer
	if player ~= nil then
		return player
	end
	local resolved: Player? = nil
	local connection: RBXScriptConnection? = nil
	pcall(function()
		connection = Players:GetPropertyChangedSignal("LocalPlayer"):Connect(function()
			local current = Players.LocalPlayer
			if current ~= nil then
				resolved = current
			end
		end)
	end)
	local deadline = os.clock() + math.max(timeout, 0.1)
	repeat
		local current = Players.LocalPlayer
		if current ~= nil then
			resolved = current
			break
		end
		task.wait(0.05)
	until os.clock() >= deadline
	local pending = connection
	if pending ~= nil then
		local conn = pending :: RBXScriptConnection
		pcall(function()
			conn:Disconnect()
		end)
	end
	return resolved
end

local function createInstance<T>(className: string, properties: { [string]: any }?, children: { Instance }?): T
	local instance = Instance.new(className)
	if properties then
		for key, value in pairs(properties) do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if properties and properties.Parent ~= nil then
		instance.Parent = properties.Parent
	end
	return instance :: any
end

local function resolveOverlayContainer(): Instance?
	local getHui: any = rawget(EXECUTOR_ENV, "gethui")
	if type(getHui) == "function" then
		local ok, result = pcall(getHui)
		if ok and typeof(result) == "Instance" and result ~= game then
			return result
		end
	end
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and typeof(coreGui) == "Instance" then
		local probeOk = pcall(function()
			local probe = Instance.new("Folder")
			probe.Parent = coreGui
			probe:Destroy()
		end)
		if probeOk then
			return coreGui
		end
	end
	return nil
end

local function resolveGuiParent(player: Player?): Instance?
	local overlay = resolveOverlayContainer()
	if overlay ~= nil then
		return overlay
	end
	local target = player or Players.LocalPlayer
	if target == nil then
		return nil
	end
	local ok, found = pcall(function()
		return target:FindFirstChildOfClass("PlayerGui")
	end)
	if ok and typeof(found) == "Instance" then
		return found
	end
	local ok2, waited = pcall(function()
		return target:WaitForChild("PlayerGui", 10)
	end)
	if ok2 and typeof(waited) == "Instance" then
		return waited
	end
	return nil
end

local function showToast(message: string, color: Color3, duration: number, player: Player?): ()
	local guiParent = resolveGuiParent(player)
	if guiParent == nil then
		return
	end
	local gui = createInstance("ScreenGui", {
		Name = "MicroOffsetSpeedToast",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100000,
	})
	createInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(352, 44),
		BackgroundColor3 = THEME.surface,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0, 8) }),
		createInstance("UIStroke", { Color = color, Thickness = 1, Transparency = 0.25 }),
		createInstance("TextLabel", {
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = message,
		}),
	})
	gui.Parent = guiParent
	task.delay(duration, function()
		pcall(function()
			gui:Destroy()
		end)
	end)
end

local function horizontal(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

local function tierColor(index: number): Color3
	if index <= 0 then
		return THEME.subText
	end
	local lowFactor = SPEED_TIERS[1].factor
	local highFactor = SPEED_TIERS[TIER_COUNT].factor
	local t = math.clamp((SPEED_TIERS[index].factor - lowFactor) / (highFactor - lowFactor), 0, 1)
	if t < 0.5 then
		return THEME.success:Lerp(THEME.warn, t * 2)
	end
	return THEME.warn:Lerp(THEME.danger, (t - 0.5) * 2)
end

local function findTierIndexByFactor(factor: number): number
	if factor <= 1.001 then
		return 0
	end
	local bestIndex = 1
	local bestDelta = math.huge
	for index, tier in ipairs(SPEED_TIERS) do
		local delta = math.abs(tier.factor - factor)
		if delta < bestDelta then
			bestDelta = delta
			bestIndex = index
		end
	end
	return bestIndex
end

--====================================================================================
-- 多通道实例锁
--   通道 A：LocalPlayer 属性（DataModel 级，跨执行器必然共享）
--   通道 B：gethui/CoreGui 里的 Folder 属性
--   在任一「存活」通道上被更高优先级顶替 → 判定失去所有权
--====================================================================================

type LockChannel = {
	Name: string,
	Available: () -> boolean,
	Get: (key: string) -> any,
	Set: (key: string, value: any) -> (),
}

type LockSnapshot = {
	token: string?,
	version: number,
	heartbeat: number,
}

type InstanceLockInstance = {
	_token: string,
	_channels: { LockChannel },
	_announced: boolean,

	Available: (self: InstanceLockInstance) -> boolean,
	Acquire: (self: InstanceLockInstance, version: number) -> boolean,
	Pulse: (self: InstanceLockInstance, version: number) -> (),
	IsOwner: (self: InstanceLockInstance, version: number) -> boolean,
	GetChannelCount: (self: InstanceLockInstance) -> number,
	Release: (self: InstanceLockInstance) -> (),
}

local InstanceLock = {}
InstanceLock.__index = InstanceLock

local function makeToken(): string
	local ok, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	if ok and type(guid) == "string" and #guid >= 8 then
		return guid
	end
	return string.format("%08x-%08x", math.random(0, 2147483647), math.random(0, 2147483647))
end

local function createPlayerChannel(player: Player): LockChannel?
	local prefix = "_MOS_"
	local ok = pcall(function()
		player:SetAttribute(prefix .. "probe", 1)
		player:SetAttribute(prefix .. "probe", nil)
	end)
	if not ok then
		return nil
	end
	return {
		Name = "player",
		Available = function(): boolean
			return true
		end,
		Get = function(key: string): any
			local ok2, value = pcall(function()
				return player:GetAttribute(prefix .. key)
			end)
			if ok2 then
				return value
			end
			return nil
		end,
		Set = function(key: string, value: any): ()
			pcall(function()
				player:SetAttribute(prefix .. key, value)
			end)
		end,
	}
end

local function createFolderChannel(): LockChannel?
	local container = resolveOverlayContainer()
	if container == nil then
		return nil
	end
	local folder: Instance? = nil
	pcall(function()
		local found = container:FindFirstChild(LOCK_CONFIG.folderName)
		if not (found ~= nil and found:IsA("Folder")) then
			local created = Instance.new("Folder")
			created.Name = LOCK_CONFIG.folderName
			created.Parent = container
			found = created
		end
		local target = found :: Folder
		target:SetAttribute("probe", 1)
		target:SetAttribute("probe", nil)
		folder = target
	end)
	if folder == nil then
		return nil
	end
	local holder = folder :: Instance
	return {
		Name = "folder",
		Available = function(): boolean
			return holder.Parent ~= nil
		end,
		Get = function(key: string): any
			local ok2, value = pcall(function()
				return holder:GetAttribute(key)
			end)
			if ok2 then
				return value
			end
			return nil
		end,
		Set = function(key: string, value: any): ()
			pcall(function()
				holder:SetAttribute(key, value)
			end)
		end,
	}
end

function InstanceLock.new(player: Player): InstanceLockInstance
	local channels: { LockChannel } = {}
	local playerChannel = createPlayerChannel(player)
	if playerChannel ~= nil then
		channels[#channels + 1] = playerChannel
	end
	local folderChannel = createFolderChannel()
	if folderChannel ~= nil then
		channels[#channels + 1] = folderChannel
	end
	return (setmetatable({
		_token = makeToken(),
		_channels = channels,
		_announced = false,
	}, InstanceLock) :: any) :: InstanceLockInstance
end

function InstanceLock:Available(): boolean
	for _, channel in ipairs(self._channels) do
		if channel.Available() then
			return true
		end
	end
	return false
end

function InstanceLock:GetChannelCount(): number
	return #self._channels
end

function InstanceLock:Pulse(version: number): ()
	local heartbeat = wallNow()
	for _, channel in ipairs(self._channels) do
		if channel.Available() then
			channel.Set("token", self._token)
			channel.Set("version", version)
			channel.Set("heartbeat", heartbeat)
		end
	end
end

---读取单个通道；返回 nil 表示该通道无有效信息
local function readChannel(channel: LockChannel, selfToken: string): LockSnapshot?
	if not channel.Available() then
		return nil
	end
	local token = channel.Get("token")
	if type(token) ~= "string" or token == "" or token == selfToken then
		return nil
	end
	local version = channel.Get("version")
	local heartbeat = channel.Get("heartbeat")
	return {
		token = token,
		version = (type(version) == "number") and version or 0,
		heartbeat = (type(heartbeat) == "number") and heartbeat or 0,
	}
end

---该快照是否「更高优先级且存活」
local function outranks(snapshot: LockSnapshot, selfVersion: number, selfToken: string): boolean
	if snapshot.token == nil then
		return false
	end
	local alive = (wallNow() - snapshot.heartbeat) < LOCK_CONFIG.staleTime
	if not alive then
		return false
	end
	if snapshot.version > selfVersion then
		return true
	end
	if snapshot.version == selfVersion and snapshot.token > selfToken then
		return true
	end
	return false
end

function InstanceLock:IsOwner(version: number): boolean
	for _, channel in ipairs(self._channels) do
		local snapshot = readChannel(channel, self._token)
		if snapshot ~= nil and outranks(snapshot, version, self._token) then
			return false
		end
	end
	return true
end

---获取所有权：先写入、退避等待、再复核，避免两个实例同时启动时互相看不见
function InstanceLock:Acquire(version: number): boolean
	if not self:Available() then
		return true
	end
	self:Pulse(version)
	local backoff = LOCK_CONFIG.acquireBackoff + math.random() * 0.05
	task.wait(backoff)
	if not self:IsOwner(version) then
		return false
	end
	self:Pulse(version)
	return true
end

function InstanceLock:Release(): ()
	for _, channel in ipairs(self._channels) do
		if channel.Available() then
			local token = channel.Get("token")
			if token == self._token then
				channel.Set("token", "")
				channel.Set("heartbeat", 0)
			end
		end
	end
end

--====================================================================================
-- 配置存档
--====================================================================================

type ConfigData = { [string]: any }

type ConfigStoreInstance = {
	_name: string,
	_available: boolean,
	_data: ConfigData,
	_dirty: boolean,
	_saveScheduled: boolean,
	_destroyed: boolean,
	_lastError: string?,
	_writeFile: any,
	_readFile: any,
	_isFile: any,

	IsAvailable: (self: ConfigStoreInstance) -> boolean,
	IsDirty: (self: ConfigStoreInstance) -> boolean,
	Load: (self: ConfigStoreInstance) -> (),
	Get: (self: ConfigStoreInstance, key: string, default: any) -> any,
	Set: (self: ConfigStoreInstance, key: string, value: any) -> (),
	Save: (self: ConfigStoreInstance) -> boolean,
	ScheduleSave: (self: ConfigStoreInstance) -> (),
	Reset: (self: ConfigStoreInstance) -> (),
	Destroy: (self: ConfigStoreInstance) -> (),
}

local ConfigStore = {}
ConfigStore.__index = ConfigStore

local function createConfigStore(fileName: string): ConfigStoreInstance
	local writeFile = resolveExecutorFunction("writefile")
	local readFile = resolveExecutorFunction("readfile")
	local isFile = resolveExecutorFunction("isfile")
	local available = type(writeFile) == "function" and type(readFile) == "function"
	local self = setmetatable({
		_name = fileName,
		_available = available,
		_data = {},
		_dirty = false,
		_saveScheduled = false,
		_destroyed = false,
		_lastError = nil,
		_writeFile = writeFile,
		_readFile = readFile,
		_isFile = isFile,
	}, ConfigStore)
	return (self :: any) :: ConfigStoreInstance
end

function ConfigStore:IsAvailable(): boolean
	return self._available
end

function ConfigStore:IsDirty(): boolean
	return self._dirty
end

function ConfigStore:Load(): ()
	if not self._available then
		return
	end
	local isFile = self._isFile
	if type(isFile) == "function" then
		local ok, exists = pcall(isFile, self._name)
		if not ok or exists ~= true then
			return
		end
	end
	local ok, content = pcall(self._readFile, self._name)
	if not ok or type(content) ~= "string" or #content < 2 then
		return
	end
	local ok2, decoded = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not ok2 or type(decoded) ~= "table" then
		self._lastError = "存档解析失败，已忽略"
		return
	end
	self._data = decoded
	self._lastError = nil
end

function ConfigStore:Get(key: string, default: any): any
	local value = self._data[key]
	if value == nil then
		return default
	end
	return value
end

function ConfigStore:Set(key: string, value: any): ()
	if self._data[key] == value then
		return
	end
	self._data[key] = value
	self:ScheduleSave()
end

function ConfigStore:Save(): boolean
	if not self._available then
		return false
	end
	local payload: ConfigData = {}
	for key, value in pairs(self._data) do
		payload[key] = value
	end
	payload.schema = SCHEMA_VERSION
	payload.script = SCRIPT_ID
	payload.version = VERSION
	payload.savedAt = os.time()
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not ok or type(encoded) ~= "string" then
		self._lastError = "编码失败"
		return false
	end
	local ok2 = pcall(self._writeFile, self._name, encoded)
	if not ok2 then
		self._lastError = "写入失败"
		return false
	end
	self._dirty = false
	self._lastError = nil
	return true
end

function ConfigStore:ScheduleSave(): ()
	self._dirty = true
	if not self._available or self._saveScheduled then
		return
	end
	self._saveScheduled = true
	task.delay(PERSIST.debounce, function()
		self._saveScheduled = false
		if self._destroyed or not self._dirty then
			return
		end
		self:Save()
	end)
end

function ConfigStore:Reset(): ()
	table.clear(self._data)
	self:ScheduleSave()
end

function ConfigStore:Destroy(): ()
	if self._destroyed then
		return
	end
	if self._available and self._dirty then
		self:Save()
	end
	self._destroyed = true
	table.clear(self._data)
end

--====================================================================================
-- 速度控制器（前馈 + 有界积分）
--====================================================================================

type ControllerStats = {
	baseSpeed: number,
	targetSpeed: number,
	naturalSpeed: number,
	achievedSpeed: number,
	grantedSpeed: number,
	ratio: number,
	factor: number,
	fused: boolean,
	resistive: boolean,
	owned: boolean,
}

type SpeedControllerInstance = {
	_player: Player,
	_character: Model?,
	_rootPart: BasePart?,
	_humanoid: Humanoid?,
	_destroyed: boolean,
	_owned: boolean,
	_tierIndex: number,
	_factor: number,
	_targetFactor: number,
	_smoothedBase: number?,
	_lastHorizontal: Vector3?,
	_lastGrant: Vector3,
	_smoothedAchieved: number,
	_smoothedNatural: number?,
	_integral: number,
	_grantRate: number,
	_fuseTimer: number,
	_fuseCount: number,
	_resistTimer: number,
	_spawnGraceUntil: number,
	_fusedUntil: number,
	_nextOwnershipTry: number,
	_ownershipInterval: number,
	_stats: ControllerStats,
	_connections: { RBXScriptConnection },

	Start: (self: SpeedControllerInstance) -> (),
	Destroy: (self: SpeedControllerInstance) -> (),
	SetOwned: (self: SpeedControllerInstance, value: boolean) -> (),
	IsOwned: (self: SpeedControllerInstance) -> boolean,
	GetFuseCount: (self: SpeedControllerInstance) -> number,
	SetTier: (self: SpeedControllerInstance, tierIndex: number) -> (),
	GetTier: (self: SpeedControllerInstance) -> number,
	GetStats: (self: SpeedControllerInstance) -> ControllerStats,
	BindCharacter: (self: SpeedControllerInstance, character: Model?) -> (),
	ClaimOwnership: (self: SpeedControllerInstance) -> (),
	ResetCache: (self: SpeedControllerInstance) -> (),
	Step: (self: SpeedControllerInstance, deltaTime: number) -> (),
}

local SpeedController = {}
SpeedController.__index = SpeedController

function SpeedController.new(player: Player): SpeedControllerInstance
	local self = setmetatable({
		_player = player,
		_character = nil,
		_rootPart = nil,
		_humanoid = nil,
		_destroyed = false,
		_owned = false,
		_tierIndex = 0,
		_factor = 1,
		_targetFactor = 1,
		_smoothedBase = nil,
		_lastHorizontal = nil,
		_lastGrant = ZERO,
		_smoothedAchieved = 0,
		_smoothedNatural = nil,
		_integral = 0,
		_grantRate = 0,
		_fuseTimer = 0,
		_fuseCount = 0,
		_resistTimer = 0,
		_spawnGraceUntil = 0,
		_fusedUntil = 0,
		_nextOwnershipTry = 0,
		_ownershipInterval = CONFIG.ownershipOkInterval,
		_stats = {
			baseSpeed = 0,
			targetSpeed = 0,
			naturalSpeed = 0,
			achievedSpeed = 0,
			grantedSpeed = 0,
			ratio = 1,
			factor = 1,
			fused = false,
			resistive = false,
			owned = false,
		},
		_connections = {},
	}, SpeedController)
	return (self :: any) :: SpeedControllerInstance
end

function SpeedController:GetStats(): ControllerStats
	return self._stats
end

function SpeedController:GetTier(): number
	return self._tierIndex
end

function SpeedController:IsOwned(): boolean
	return self._owned
end

function SpeedController:GetFuseCount(): number
	return self._fuseCount
end

---所有权确认后才允许写入角色位置（消除双实例同时补偿的窗口）
function SpeedController:SetOwned(value: boolean): ()
	if self._owned == value then
		return
	end
	self._owned = value
	self._stats.owned = value
	if value then
		self:ResetCache()
	end
end

---清空自适应缓存（重生 / 传送 / 取得所有权后调用，不动倍率）
function SpeedController:ResetCache(): ()
	self._lastHorizontal = nil
	self._lastGrant = ZERO
	self._smoothedAchieved = 0
	self._smoothedNatural = nil
	self._integral = 0
	self._grantRate = 0
	self._fuseTimer = 0
	self._resistTimer = 0
end

function SpeedController:SetTier(tierIndex: number): ()
	local clamped = math.clamp(math.floor(tierIndex + 0.5), 0, TIER_COUNT)
	self._tierIndex = clamped
	self._targetFactor = (clamped == 0) and 1 or SPEED_TIERS[clamped].factor
	self._fusedUntil = 0
	self._fuseTimer = 0
	self._integral = 0
end

function SpeedController:BindCharacter(character: Model?): ()
	self._character = character
	self._rootPart = nil
	self._humanoid = nil
	if character == nil then
		self:ResetCache()
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		self._rootPart = rootPart
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self._humanoid = humanoid
	end
	self._spawnGraceUntil = os.clock() + CONFIG.spawnGrace
	self._nextOwnershipTry = 0
	self._ownershipInterval = CONFIG.ownershipOkInterval
	self:ResetCache()
end

function SpeedController:ClaimOwnership(): ()
	if not CONFIG.claimOwnership then
		return
	end
	local rootPart = self._rootPart
	if rootPart == nil or rootPart.Parent == nil then
		return
	end
	local player = self._player
	if player == nil then
		return
	end
	local now = os.clock()
	if now < self._nextOwnershipTry then
		return
	end
	local owner: Player? = nil
	pcall(function()
		owner = rootPart:GetNetworkOwner()
	end)
	if owner == player then
		self._ownershipInterval = CONFIG.ownershipOkInterval
		self._nextOwnershipTry = now + self._ownershipInterval
		return
	end
	local ok = pcall(function()
		rootPart:SetNetworkOwner(player)
	end)
	if not ok then
		pcall(function()
			rootPart:SetNetworkOwnershipAuto()
		end)
		self._ownershipInterval = CONFIG.ownershipFailInterval
	end
	self._nextOwnershipTry = now + self._ownershipInterval
end

function SpeedController:Start(): ()
	if self._destroyed then
		return
	end
	local player = self._player
	if player == nil then
		return
	end
	self:BindCharacter(player.Character)
	self._connections[#self._connections + 1] = player.CharacterAdded:Connect(function(character: Model)
		self:BindCharacter(character)
	end)
	local runServiceAny: any = RunService
	local stepEvent = runServiceAny.PreSimulation or runServiceAny.Stepped
	local connection = stepEvent:Connect(function(deltaTime: number)
		if self._destroyed then
			return
		end
		self:Step(deltaTime)
	end)
	self._connections[#self._connections + 1] = connection
end

function SpeedController:Destroy(): ()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for index = #self._connections, 1, -1 do
		local connection = self._connections[index]
		table.remove(self._connections, index)
		pcall(function()
			connection:Disconnect()
		end)
	end
	self:ResetCache()
end

---核心步进
function SpeedController:Step(deltaTime: number): ()
	local stats = self._stats
	stats.fused = false
	stats.resistive = false
	stats.owned = self._owned

	-- 0) 异常帧（卡顿 / 切后台）丢弃基准
	if deltaTime <= 0 or deltaTime > 0.2 then
		self:ResetCache()
		return
	end

	-- 1) 倍率缓动
	local easeRate = 1 - math.exp(-deltaTime / CONFIG.factorEaseTime)
	local factor = self._factor + (self._targetFactor - self._factor) * easeRate
	if math.abs(factor - self._targetFactor) < 1e-3 then
		factor = self._targetFactor
	end
	self._factor = factor
	stats.factor = factor

	-- 2) 未取得所有权前绝不写入
	if not self._owned then
		self:ResetCache()
		return
	end

	-- 3) 角色引用
	local player = self._player
	if player == nil then
		return
	end
	local character = self._character
	if character == nil or character.Parent == nil then
		local live = player.Character
		if live ~= nil and live ~= character then
			self:BindCharacter(live)
		end
		return
	end
	local rootPart = self._rootPart
	if rootPart == nil or rootPart.Parent == nil then
		self:BindCharacter(character)
		rootPart = self._rootPart
	end
	local humanoid = self._humanoid
	if humanoid == nil or humanoid.Parent == nil then
		humanoid = character:FindFirstChildOfClass("Humanoid")
		self._humanoid = humanoid
	end
	if rootPart == nil or humanoid == nil then
		return
	end

	-- 3.5) 网络所有权（节流，不在每帧做）
	self:ClaimOwnership()

	-- 4) 采样位置
	local position = rootPart.Position
	local currentHorizontal = Vector3.new(position.X, 0, position.Z)
	local previousHorizontal = self._lastHorizontal
	local previousGrant = self._lastGrant
	self._lastHorizontal = currentHorizontal
	self._lastGrant = ZERO

	-- 5) WalkSpeed 平滑
	local rawBase = humanoid.WalkSpeed
	local smoothedBase = self._smoothedBase
	if smoothedBase == nil then
		smoothedBase = rawBase
	else
		local baseEase = 1 - math.exp(-deltaTime / CONFIG.baseEaseTime)
		smoothedBase = smoothedBase + (rawBase - smoothedBase) * baseEase
		if math.abs(smoothedBase - rawBase) < 0.01 then
			smoothedBase = rawBase
		end
	end
	self._smoothedBase = smoothedBase
	local baseSpeed = smoothedBase :: number
	local targetSpeed = math.min(baseSpeed * math.max(factor, 1), CONFIG.maxTargetSpeed)
	stats.baseSpeed = baseSpeed
	stats.targetSpeed = targetSpeed

	if previousHorizontal == nil then
		return
	end
	if factor <= 1.0005 then
		stats.grantedSpeed = 0
		self._grantRate = 0
		self._integral = 0
		return
	end
	if baseSpeed <= 0 or humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand then
		self._grantRate = 0
		return
	end
	if os.clock() < self._spawnGraceUntil then
		return
	end

	-- 6) 意图方向
	local moveDirection = humanoid.MoveDirection
	local desiredPlanar = horizontal(moveDirection)
	if desiredPlanar.Magnitude < 0.05 then
		self._grantRate = 0
		stats.grantedSpeed = 0
		-- 空转：积分缓慢泄放，避免起步窜车
		self._integral = self._integral * math.exp(-deltaTime / CONFIG.integralLeak)
		self._fuseTimer = 0
		self._resistTimer = 0
		return
	end
	local desiredUnit = desiredPlanar.Unit

	-- 7) 测量
	local observedVector = currentHorizontal - previousHorizontal
	local observedSpeed = observedVector.Magnitude / deltaTime
	local naturalVector = observedVector - previousGrant
	local naturalAlong = naturalVector:Dot(desiredUnit) / deltaTime
	local naturalCeiling = baseSpeed * CONFIG.naturalClamp
	local rawNatural = math.clamp(naturalAlong, 0, naturalCeiling)

	local lastNatural = self._smoothedNatural
	if lastNatural == nil then
		self._smoothedNatural = rawNatural
	else
		self._smoothedNatural = lastNatural + (rawNatural - lastNatural) * CONFIG.naturalAlpha
	end
	local naturalSpeed = self._smoothedNatural :: number
	stats.naturalSpeed = naturalSpeed

	local rawAchieved = math.clamp(observedSpeed, 0, baseSpeed * 20)
	self._smoothedAchieved = self._smoothedAchieved + (rawAchieved - self._smoothedAchieved) * CONFIG.achievedAlpha
	local achievedSpeed = self._smoothedAchieved
	stats.achievedSpeed = achievedSpeed
	stats.ratio = (baseSpeed > 0) and (achievedSpeed / baseSpeed) or 1

	-- 8) 熔断：只针对真正的外部失控（自身动作上限 1.20 < 1.35）
	local now = os.clock()
	if now < self._fusedUntil then
		stats.fused = true
		stats.grantedSpeed = 0
		self._grantRate = 0
		self._integral = 0
		return
	end
	if achievedSpeed > targetSpeed * CONFIG.fuseBand then
		self._fuseTimer = self._fuseTimer + deltaTime
	else
		self._fuseTimer = math.max(0, self._fuseTimer - deltaTime * 2)
	end
	if self._fuseTimer >= CONFIG.fuseTime then
		self._fuseTimer = 0
		self._fuseCount = self._fuseCount + 1
		self._fusedUntil = now + CONFIG.fuseCooldown
		if CONFIG.logFuse then
			warn(string.format(
				"[%s] 外部速度失控：实测 %.1f > 目标 %.1f × %.2f 且持续 %.2fs，暂停 %.2fs（第 %d 次）",
				SCRIPT_ID, achievedSpeed, targetSpeed, CONFIG.fuseBand, CONFIG.fuseTime,
				CONFIG.fuseCooldown, self._fuseCount))
		end
		stats.fused = true
		stats.grantedSpeed = 0
		self._grantRate = 0
		self._integral = 0
		return
	end

	-- 9) 速度斜坡（用平滑后的自然速度；贴墙 → 0）
	local ramp = 1
	local rampSpan = baseSpeed * (CONFIG.rampHigh - CONFIG.rampLow)
	if rampSpan > 0.001 then
		ramp = math.clamp((naturalSpeed - baseSpeed * CONFIG.rampLow) / rampSpan, 0, 1)
	end

	-- 10) 控制律：前馈 + 有界积分
	local steadyGrant = baseSpeed * (factor - 1)
	local outputCeiling = steadyGrant * CONFIG.outputCeiling

	local errorSpeed = targetSpeed - achievedSpeed
	self._integral = self._integral + errorSpeed * (deltaTime / CONFIG.integralTime)
	local integralLimit = steadyGrant * CONFIG.integralLimit
	if self._integral > integralLimit then
		self._integral = integralLimit
	elseif self._integral < -integralLimit then
		self._integral = -integralLimit
	end
	-- 卡墙 / 顶墙时主动泄放积分，避免脱困瞬间爆发
	if ramp < 0.5 then
		self._integral = self._integral * math.exp(-deltaTime / CONFIG.integralLeak)
	end

	local output = (steadyGrant + self._integral) * ramp
	if output < 0 then
		output = 0
	elseif output > outputCeiling then
		output = outputCeiling
	end

	-- 11) 环境阻力提示（不削减补偿，仅提示）
	if output >= outputCeiling * CONFIG.resistOutputFrac
		and achievedSpeed < targetSpeed * CONFIG.resistAchievedFrac then
		self._resistTimer = self._resistTimer + deltaTime
	else
		self._resistTimer = math.max(0, self._resistTimer - deltaTime * 2)
	end
	stats.resistive = self._resistTimer > CONFIG.resistTime

	-- 12) 输出低通
	self._grantRate = self._grantRate + (output - self._grantRate) * CONFIG.grantAlpha

	-- 13) 单帧位移上限
	local maxStep = steadyGrant * deltaTime * CONFIG.maxStepScale + CONFIG.maxStepBase
	local grantDistance = math.clamp(self._grantRate * deltaTime, 0, maxStep)
	if grantDistance <= 1e-4 then
		stats.grantedSpeed = 0
		return
	end

	-- 14) 施加：仅水平分量 + 意图方向（世界空间平移，保留朝向）
	local grantVector = desiredUnit * grantDistance
	local velocityBefore = rootPart.AssemblyLinearVelocity
	rootPart.CFrame = rootPart.CFrame + grantVector
	-- 仅在速度被明显抹掉时才还原（保守，避免逐帧写速度造成一顿一顿）
	local velocityAfter = rootPart.AssemblyLinearVelocity
	if velocityAfter.Magnitude < velocityBefore.Magnitude * CONFIG.velocityDropRatio then
		pcall(function()
			rootPart.AssemblyLinearVelocity = velocityBefore
		end)
	end

	self._lastGrant = grantVector
	stats.grantedSpeed = grantDistance / deltaTime
end

--====================================================================================
-- UI
--====================================================================================

type MicroSpeedUiInstance = {
	_controller: SpeedControllerInstance,
	_store: ConfigStoreInstance,
	_lock: InstanceLockInstance,
	_screenGui: ScreenGui,
	_sliderArea: Frame,
	_knob: Frame,
	_knobGlow: Frame,
	_fill: Frame,
	_ticks: { [number]: Frame },
	_valueLabel: TextLabel,
	_statusLabel: TextLabel,
	_readoutLabel: TextLabel,
	_detailLabel: TextLabel,
	_meterFill: Frame,
	_saveStatusLabel: TextLabel,
	_instanceStatusLabel: TextLabel,
	_resetButton: TextButton,
	_connections: { RBXScriptConnection },
	_onUnload: () -> (),
	_destroyed: boolean,
	_index: number,
	_dragging: boolean,
	_dragInput: InputObject?,
	_mousePosition: Vector2?,
	_readoutAccumulator: number,
	_meterRatio: number,
	_persistEnabled: boolean,
	_resetArmedUntil: number,
	_saveStatusText: string,

	ApplyIndex: (self: MicroSpeedUiInstance, index: number) -> (),
	UpdateFromAbsoluteX: (self: MicroSpeedUiInstance, absoluteX: number) -> (),
	RefreshSlider: (self: MicroSpeedUiInstance) -> (),
	RefreshLabels: (self: MicroSpeedUiInstance) -> (),
	RefreshReadout: (self: MicroSpeedUiInstance) -> (),
	RefreshMeter: (self: MicroSpeedUiInstance) -> (),
	RefreshStatusLines: (self: MicroSpeedUiInstance) -> (),
	Destroy: (self: MicroSpeedUiInstance) -> (),
}

local MicroSpeedUi = {}
MicroSpeedUi.__index = MicroSpeedUi

local function trackConnection(self: MicroSpeedUiInstance, connection: RBXScriptConnection): RBXScriptConnection
	self._connections[#self._connections + 1] = connection
	return connection
end

local function isMajorTick(index: number): boolean
	return (index % 5 == 0) or (index == TIER_COUNT)
end

function MicroSpeedUi.new(
	controller: SpeedControllerInstance,
	onUnload: () -> (),
	store: ConfigStoreInstance,
	lock: InstanceLockInstance,
	initialIndex: number,
	player: Player
): MicroSpeedUiInstance?
	local guiParent = resolveGuiParent(player)
	if guiParent == nil then
		return nil
	end

	local self = (setmetatable({
		_controller = controller,
		_store = store,
		_lock = lock,
		_ticks = {},
		_connections = {},
		_onUnload = onUnload,
		_destroyed = false,
		_index = 0,
		_dragging = false,
		_dragInput = nil,
		_mousePosition = nil,
		_readoutAccumulator = 0,
		_meterRatio = 0,
		_persistEnabled = true,
		_resetArmedUntil = 0,
		_saveStatusText = "",
	}, MicroSpeedUi) :: any) :: MicroSpeedUiInstance

	local gui = createInstance("ScreenGui", {
		Name = "MicroOffsetSpeedGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 99999,
	})
	self._screenGui = gui

	local panel = createInstance("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.background,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Active = true,
		Parent = gui,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0, 12) }),
		createInstance("UIStroke", { Color = THEME.stroke, Thickness = 1, Transparency = 0.15 }),
		createInstance("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		createInstance("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 7),
		}),
	})

	local statusLabel = createInstance("TextLabel", {
		Name = "Status",
		Size = UDim2.new(0.4, 0, 1, 0),
		Position = UDim2.new(0.6, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = THEME.subText,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "已关闭",
	})
	self._statusLabel = statusLabel

	createInstance("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = panel,
	}, {
		createInstance("TextLabel", {
			Name = "Title",
			Size = UDim2.new(0.6, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = THEME.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("微差速传 v%d", VERSION),
		}),
		statusLabel,
	})

	self._valueLabel = createInstance("TextLabel", {
		Name = "Value",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = THEME.subText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "关闭",
		LayoutOrder = 2,
		Parent = panel,
	})

	local sliderArea = createInstance("Frame", {
		Name = "Slider",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Active = true,
		LayoutOrder = 3,
		Parent = panel,
	})
	self._sliderArea = sliderArea

	for index = 0, TIER_COUNT do
		local major = isMajorTick(index)
		local tick = createInstance("Frame", {
			Name = "Tick" .. tostring(index),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, KNOB_SIZE / 2, 0.5, 0),
			Size = UDim2.fromOffset(1, major and 18 or 9),
			BackgroundColor3 = THEME.subText,
			BackgroundTransparency = major and 0.5 or 0.82,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = sliderArea,
		})
		self._ticks[index] = tick
	end

	local rail = createInstance("Frame", {
		Name = "Rail",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB_SIZE / 2, 0.5, 0),
		Size = UDim2.new(1, -KNOB_SIZE, 0, 6),
		BackgroundColor3 = THEME.stroke,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = sliderArea,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})

	self._fill = createInstance("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = THEME.subText,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = rail,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})

	self._knobGlow = createInstance("Frame", {
		Name = "KnobGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, KNOB_SIZE / 2, 0.5, 0),
		Size = UDim2.fromOffset(KNOB_SIZE + 12, KNOB_SIZE + 12),
		BackgroundColor3 = THEME.accent,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = sliderArea,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})

	self._knob = createInstance("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, KNOB_SIZE / 2, 0.5, 0),
		Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE),
		BackgroundColor3 = THEME.subText,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = sliderArea,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		createInstance("UIStroke", { Color = THEME.pure, Thickness = 2, Transparency = 0.35 }),
		createInstance("Frame", {
			Name = "Highlight",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = THEME.pure,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			createInstance("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		}),
	})

	createInstance("Frame", {
		Name = "Range",
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = panel,
	}, {
		createInstance("TextLabel", {
			Size = UDim2.new(0.5, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 9,
			TextColor3 = THEME.subText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "关闭",
		}),
		createInstance("TextLabel", {
			Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 9,
			TextColor3 = THEME.subText,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = SPEED_TIERS[TIER_COUNT].label,
		}),
	})

	local meter = createInstance("Frame", {
		Name = "Meter",
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = THEME.stroke,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		LayoutOrder = 5,
		Parent = panel,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	self._meterFill = createInstance("Frame", {
		Name = "MeterFill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = THEME.accent,
		BorderSizePixel = 0,
		Parent = meter,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})

	self._readoutLabel = createInstance("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = THEME.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "等待角色加载…",
		LayoutOrder = 6,
		Parent = panel,
	})

	self._detailLabel = createInstance("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = THEME.subText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "拖动 / 滚轮 / 点击刻度 · 不修改 WalkSpeed",
		LayoutOrder = 7,
		Parent = panel,
	})

	local footer = createInstance("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		LayoutOrder = 8,
		Parent = panel,
	})
	self._saveStatusLabel = createInstance("TextLabel", {
		Name = "SaveStatus",
		Size = UDim2.new(0.62, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = THEME.subText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "存档：检测中…",
		Parent = footer,
	})
	self._resetButton = createInstance("TextButton", {
		Name = "Reset",
		Size = UDim2.new(0.38, 0, 1, 0),
		Position = UDim2.new(0.62, 0, 0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = THEME.subText,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "重置存档",
		Parent = footer,
	})

	self._instanceStatusLabel = createInstance("TextLabel", {
		Name = "InstanceStatus",
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = THEME.subText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "实例：确认中…",
		LayoutOrder = 9,
		Parent = panel,
	})

	trackConnection(self, self._resetButton.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now > self._resetArmedUntil then
			self._resetArmedUntil = now + CONFIG.resetConfirmWindow
			self._resetButton.Text = "确认重置？"
			self._resetButton.TextColor3 = THEME.warn
			task.delay(CONFIG.resetConfirmWindow, function()
				if self._destroyed or os.clock() < self._resetArmedUntil then
					return
				end
				self._resetButton.Text = "重置存档"
				self._resetButton.TextColor3 = THEME.subText
			end)
			return
		end
		self._resetArmedUntil = 0
		self._resetButton.Text = "重置存档"
		self._resetButton.TextColor3 = THEME.subText
		self._persistEnabled = false
		self:ApplyIndex(0)
		self._persistEnabled = true
		self._store:Reset()
		showToast("微差速传：存档已重置，档位回到「关闭」", THEME.success, 2.5, player)
	end))

	local function beginDrag(input: InputObject): ()
		if self._dragging then
			return
		end
		self._dragging = true
		self._dragInput = input
		self:UpdateFromAbsoluteX(input.Position.X)
	end

	local function endDrag(input: InputObject): ()
		if input == self._dragInput then
			self._dragging = false
			self._dragInput = nil
		end
	end

	local function onBegan(input: InputObject): ()
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end

	trackConnection(self, sliderArea.InputBegan:Connect(onBegan))
	trackConnection(self, self._knob.InputBegan:Connect(onBegan))
	trackConnection(self, sliderArea.InputEnded:Connect(endDrag))
	trackConnection(self, self._knob.InputEnded:Connect(endDrag))

	trackConnection(self, UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self._mousePosition = input.Position
			if self._dragging and self._dragInput ~= nil then
				self:UpdateFromAbsoluteX(input.Position.X)
			end
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			if self._dragging and input == self._dragInput then
				self:UpdateFromAbsoluteX(input.Position.X)
			end
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local mousePosition = self._mousePosition
			if mousePosition == nil then
				return
			end
			local panelPosition = panel.AbsolutePosition
			local panelSize = panel.AbsoluteSize
			local inside = mousePosition.X >= panelPosition.X
				and mousePosition.X <= panelPosition.X + panelSize.X
				and mousePosition.Y >= panelPosition.Y
				and mousePosition.Y <= panelPosition.Y + panelSize.Y
			if not inside then
				return
			end
			local delta = (input.Position.Z > 0) and 1 or -1
			self:ApplyIndex(self._index + delta)
		end
	end))

	trackConnection(self, UserInputService.InputEnded:Connect(endDrag))
	trackConnection(self, sliderArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:RefreshSlider()
	end))

	local unloadButton = createInstance("TextButton", {
		Name = "UnloadButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.fromOffset(184, 40),
		BackgroundColor3 = THEME.surface,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
		Parent = gui,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0, 9) }),
		createInstance("UIStroke", { Color = THEME.danger, Thickness = 1, Transparency = 0.4 }),
	})

	local holdProgress = createInstance("Frame", {
		Name = "Progress",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = THEME.danger,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = unloadButton,
	}, {
		createInstance("UICorner", { CornerRadius = UDim.new(0, 9) }),
	})

	local unloadLabel = createInstance("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = THEME.pure,
		Text = string.format("长按 %.1fs 卸载脚本", CONFIG.holdSeconds),
		ZIndex = 4,
		Parent = unloadButton,
	})

	local activeInput: InputObject? = nil
	local heldSeconds = 0

	local function resetHold(): ()
		activeInput = nil
		heldSeconds = 0
		holdProgress.Size = UDim2.new(0, 0, 1, 0)
		unloadLabel.Text = string.format("长按 %.1fs 卸载脚本", CONFIG.holdSeconds)
		unloadLabel.TextColor3 = THEME.pure
	end

	trackConnection(self, unloadButton.InputBegan:Connect(function(input: InputObject)
		if activeInput ~= nil then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			activeInput = input
			heldSeconds = 0
			holdProgress.Size = UDim2.new(0, 0, 1, 0)
		end
	end))

	trackConnection(self, unloadButton.InputEnded:Connect(function(input: InputObject)
		if input == activeInput then
			resetHold()
		end
	end))

	trackConnection(self, unloadButton.MouseLeave:Connect(resetHold))

	trackConnection(self, UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == activeInput then
			resetHold()
		end
	end))

	trackConnection(self, RunService.Heartbeat:Connect(function(deltaTime: number)
		if self._destroyed then
			return
		end

		if activeInput ~= nil then
			heldSeconds += deltaTime
			local ratio = math.clamp(heldSeconds / CONFIG.holdSeconds, 0, 1)
			holdProgress.Size = UDim2.new(ratio, 0, 1, 0)
			unloadLabel.Text = string.format("卸载中… %.1fs", math.max(CONFIG.holdSeconds - heldSeconds, 0))
			if heldSeconds >= CONFIG.holdSeconds then
				activeInput = nil
				heldSeconds = 0
				unloadLabel.Text = "正在卸载…"
				local callback = self._onUnload
				task.defer(function()
					pcall(callback)
				end)
			end
		end

		self:RefreshMeter()

		self._readoutAccumulator += deltaTime
		if self._readoutAccumulator >= CONFIG.readoutInterval then
			self._readoutAccumulator = 0
			self:RefreshReadout()
		end
	end))

	gui.Parent = guiParent

	self:ApplyIndex(initialIndex)
	task.defer(function()
		self:RefreshSlider()
	end)
	return self
end

function MicroSpeedUi:UpdateFromAbsoluteX(absoluteX: number): ()
	if self._destroyed then
		return
	end
	local width = self._sliderArea.AbsoluteSize.X
	if width <= 1 then
		return
	end
	local span = math.max(width - KNOB_SIZE, 1)
	local relX = absoluteX - self._sliderArea.AbsolutePosition.X
	local value = math.clamp((relX - KNOB_SIZE / 2) / span, 0, 1)
	self:ApplyIndex(math.floor(value * TIER_COUNT + 0.5))
end

function MicroSpeedUi:ApplyIndex(index: number): ()
	if self._destroyed then
		return
	end
	local clamped = math.clamp(math.floor(index + 0.5), 0, TIER_COUNT)
	self._index = clamped
	self._controller:SetTier(clamped)
	if self._persistEnabled and self._store:IsAvailable() then
		local factor = (clamped == 0) and 1 or SPEED_TIERS[clamped].factor
		self._store:Set("tierFactor", factor)
	end
	self:RefreshSlider()
	self:RefreshLabels()
	self:RefreshReadout()
end

function MicroSpeedUi:RefreshSlider(): ()
	if self._destroyed then
		return
	end
	local width = self._sliderArea.AbsoluteSize.X
	if width <= 1 then
		return
	end
	local span = math.max(width - KNOB_SIZE, 1)
	local value = self._index / TIER_COUNT
	local centerX = KNOB_SIZE / 2 + value * span
	local color = tierColor(self._index)

	self._knob.Position = UDim2.new(0, centerX, 0.5, 0)
	self._knob.BackgroundColor3 = color
	self._knobGlow.Position = UDim2.new(0, centerX, 0.5, 0)
	self._knobGlow.BackgroundColor3 = color
	self._fill.Size = UDim2.new(value, 0, 1, 0)
	self._fill.BackgroundColor3 = color

	for index = 0, TIER_COUNT do
		local tick = self._ticks[index]
		if tick ~= nil then
			local major = isMajorTick(index)
			tick.Position = UDim2.new(0, KNOB_SIZE / 2 + (index / TIER_COUNT) * span, 0.5, 0)
			if index <= self._index and self._index > 0 then
				tick.BackgroundColor3 = color
				tick.BackgroundTransparency = major and 0.2 or 0.5
			else
				tick.BackgroundColor3 = THEME.subText
				tick.BackgroundTransparency = major and 0.5 or 0.82
			end
		end
	end
end

function MicroSpeedUi:RefreshLabels(): ()
	if self._destroyed then
		return
	end
	if self._index == 0 then
		self._valueLabel.Text = "关闭"
		self._valueLabel.TextColor3 = THEME.subText
	else
		local factor = SPEED_TIERS[self._index].factor
		local percent = math.floor((factor - 1) * 100 + 0.5)
		self._valueLabel.Text = string.format("×%.2f   +%d%%", factor, percent)
		self._valueLabel.TextColor3 = tierColor(self._index)
	end
end

function MicroSpeedUi:RefreshMeter(): ()
	if self._destroyed then
		return
	end
	local stats = self._controller:GetStats()
	local quota = math.max(stats.targetSpeed - stats.baseSpeed, 0)
	local target = 0
	if quota > 0.001 then
		target = math.clamp(stats.grantedSpeed / quota, 0, 1)
	end
	self._meterRatio += (target - self._meterRatio) * 0.25
	self._meterFill.Size = UDim2.new(self._meterRatio, 0, 1, 0)
	self._meterFill.BackgroundColor3 = (self._index > 0) and tierColor(self._index) or THEME.stroke
end

function MicroSpeedUi:RefreshStatusLines(): ()
	if self._destroyed then
		return
	end
	local store = self._store
	local saveText: string
	local saveColor: Color3
	if not store:IsAvailable() then
		saveText = "存档 ✗ 执行器无文件 API"
		saveColor = THEME.subText
	elseif store:IsDirty() then
		saveText = "存档 … 写入中"
		saveColor = THEME.warn
	else
		saveText = "存档 ✓ 已永久保存"
		saveColor = THEME.success
	end
	if saveText ~= self._saveStatusText then
		self._saveStatusText = saveText
		self._saveStatusLabel.Text = saveText
		self._saveStatusLabel.TextColor3 = saveColor
	end

	local stats = self._controller:GetStats()
	local lockText: string
	local lockColor: Color3
	if not self._lock:Available() then
		lockText = "实例：单环境模式（无仲裁通道）"
		lockColor = THEME.subText
	elseif not stats.owned then
		lockText = "实例：等待独占确认…"
		lockColor = THEME.warn
	elseif stats.resistive then
		lockText = "实例：独占 · 环境阻力（可能服务端拉回）"
		lockColor = THEME.warn
	else
		lockText = string.format("实例：独占 · 通道 %d · 熔断 %d",
			self._lock:GetChannelCount(), self._controller:GetFuseCount())
		lockColor = THEME.success
	end
	self._instanceStatusLabel.Text = lockText
	self._instanceStatusLabel.TextColor3 = lockColor
end

function MicroSpeedUi:RefreshReadout(): ()
	if self._destroyed then
		return
	end
	local stats = self._controller:GetStats()
	local tierIndex = self._controller:GetTier()

	if tierIndex == 0 then
		self._statusLabel.Text = "已关闭"
		self._statusLabel.TextColor3 = THEME.subText
	elseif not stats.owned then
		self._statusLabel.Text = "等待独占…"
		self._statusLabel.TextColor3 = THEME.warn
	elseif stats.fused then
		self._statusLabel.Text = "熔断中…"
		self._statusLabel.TextColor3 = THEME.warn
	elseif stats.resistive then
		self._statusLabel.Text = "受阻…"
		self._statusLabel.TextColor3 = THEME.warn
	else
		self._statusLabel.Text = "运行中"
		self._statusLabel.TextColor3 = THEME.success
	end

	self:RefreshStatusLines()

	if stats.baseSpeed <= 0 then
		self._readoutLabel.Text = "等待角色加载…"
		self._detailLabel.Text = "拖动 / 滚轮 / 点击刻度 · 不修改 WalkSpeed"
		return
	end

	self._readoutLabel.Text = string.format("基础 %.1f  →  目标 %.1f stud/s", stats.baseSpeed, stats.targetSpeed)
	self._detailLabel.Text = string.format("实时 ×%.2f · 实测 %.1f · 补偿 %.1f",
		stats.ratio, stats.achievedSpeed, stats.grantedSpeed)
end

function MicroSpeedUi:Destroy(): ()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._dragging = false
	self._dragInput = nil
	for index = #self._connections, 1, -1 do
		local connection = self._connections[index]
		table.remove(self._connections, index)
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self._ticks)
	if self._screenGui then
		pcall(function()
			self._screenGui:Destroy()
		end)
	end
end

--====================================================================================
-- 残留 UI 清扫
--====================================================================================

local function sweepStaleOverlays(): ()
	local container = resolveOverlayContainer()
	if container == nil then
		return
	end
	local names = { "MicroOffsetSpeedGui", "MicroOffsetSpeedToast" }
	pcall(function()
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("ScreenGui") then
				for _, name in ipairs(names) do
					if child.Name == name then
						child:Destroy()
						break
					end
				end
			end
		end
	end)
end

--====================================================================================
-- 启动 / 仲裁 / 卸载
--====================================================================================

local function bootstrap(): ()
	local player = waitForLocalPlayer(CONFIG.playerTimeout)
	if player == nil then
		warn(string.format("[%s] 无法获取 LocalPlayer（等待 %.0fs 超时），本次不运行", SCRIPT_ID, CONFIG.playerTimeout))
		return
	end

	local shouldRun = true
	local rejectReason = ""

	-- A. 同环境检测（getgenv）
	local existing = EXECUTOR_ENV[SCRIPT_ID]
	if type(existing) == "table" then
		local existingVersion = existing.version
		if type(existingVersion) == "number" then
			if existingVersion >= VERSION then
				shouldRun = false
				rejectReason = string.format("同环境已存在 v%d", existingVersion)
			else
				print(string.format("[%s] 发现同环境旧版 v%d，先让其自毁并落盘", SCRIPT_ID, existingVersion))
				if type(existing.destroy) == "function" then
					local ok, err = pcall(existing.destroy)
					if not ok then
						warn(string.format("[%s] 旧版自毁失败：%s", SCRIPT_ID, tostring(err)))
					end
				end
			end
		else
			EXECUTOR_ENV[SCRIPT_ID] = nil
		end
	end

	-- B. 跨环境多通道仲裁
	local lock = InstanceLock.new(player)
	if shouldRun then
		if not lock:Acquire(VERSION) then
			shouldRun = false
			rejectReason = "已存在同版本或更高版本实例"
		end
	end

	if not shouldRun then
		warn(string.format("[%s] 本次不运行：%s（>= 本版 v%d）", SCRIPT_ID, rejectReason, VERSION))
		showToast(string.format("微差速传：%s，本次不运行", rejectReason), THEME.warn, 3.5, player)
		return
	end

	-- C. 清扫残留 UI（此刻已确认自己是唯一持有者）
	sweepStaleOverlays()

	-- D. 读取存档（优先按倍率，兼容旧版索引）
	local store = createConfigStore(PERSIST.fileName)
	store:Load()
	local initialIndex = 0
	local savedFactor = store:Get("tierFactor", nil)
	if type(savedFactor) == "number" then
		initialIndex = findTierIndexByFactor(savedFactor)
	else
		local savedIndex = store:Get("tierIndex", nil)
		if type(savedIndex) == "number" then
			initialIndex = math.clamp(math.floor(savedIndex + 0.5), 0, TIER_COUNT)
		end
	end

	-- E. 控制器
	local controller = SpeedController.new(player)
	controller:Start()

	local destroyed = false
	local ui: MicroSpeedUiInstance? = nil
	local api: any = nil
	local extraConnections: { RBXScriptConnection } = {}

	local function disconnectExtras(): ()
		for index = #extraConnections, 1, -1 do
			local connection = extraConnections[index]
			table.remove(extraConnections, index)
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	local function destroy(): ()
		if destroyed then
			return
		end
		destroyed = true
		pcall(function()
			controller:Destroy()
		end)
		disconnectExtras()
		local instanceUi = ui
		if instanceUi ~= nil then
			local targetUi = instanceUi :: MicroSpeedUiInstance
			pcall(function()
				targetUi:Destroy()
			end)
		end
		pcall(function()
			store:Destroy()
		end)
		pcall(function()
			lock:Release()
		end)
		if EXECUTOR_ENV[SCRIPT_ID] == api then
			EXECUTOR_ENV[SCRIPT_ID] = nil
		end
		print(string.format("[%s] v%d 已卸载并清理完毕", SCRIPT_ID, VERSION))
	end

	-- F. UI
	ui = MicroSpeedUi.new(controller, destroy, store, lock, initialIndex, player)

	-- G. 仲裁心跳（所有权确认后才允许写入；被顶替则自毁）
	if lock:Available() then
		local ownerAccum = 0
		local ownedChecks = 0
		local arbiter = RunService.Heartbeat:Connect(function(deltaTime: number)
			if destroyed then
				return
			end
			ownerAccum += deltaTime
			if ownerAccum < LOCK_CONFIG.pulseInterval then
				return
			end
			ownerAccum = 0
			if lock:IsOwner(VERSION) then
				ownedChecks += 1
				if ownedChecks >= LOCK_CONFIG.confirmChecks and not controller:IsOwned() then
					controller:SetOwned(true)
				end
				lock:Pulse(VERSION)
			else
				ownedChecks = 0
				if controller:IsOwned() then
					controller:SetOwned(false)
				end
				warn(string.format("[%s] 检测到更高优先级实例，本实例自动退出以消除冲突", SCRIPT_ID))
				task.defer(destroy)
			end
		end)
		extraConnections[#extraConnections + 1] = arbiter
	else
		-- 无仲裁通道：单环境模式，直接放行
		controller:SetOwned(true)
	end

	api = {
		version = VERSION,
		destroy = destroy,
		controller = controller,
		ui = ui,
		store = store,
		lock = lock,
	}
	EXECUTOR_ENV[SCRIPT_ID] = api

	print(string.format("[%s] v%d 已加载 · 档位 %d(%s) · 仲裁通道 %d · 已启用所有权门控",
		SCRIPT_ID, VERSION, initialIndex,
		initialIndex == 0 and "关闭" or SPEED_TIERS[initialIndex].label,
		lock:GetChannelCount()))
end

local ok, err = pcall(bootstrap)
if not ok then
	warn(string.format("[%s] 启动失败：%s", SCRIPT_ID, tostring(err)))
end
