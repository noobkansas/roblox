--!nonstrict
--[[
	EggMaster V19
	放置位置：autoexec 或 StarterPlayerScripts

	V19 修复：
	  · 拖拽位置持久化（customPanelX/Y）
	  · 紧急模式按稀有度阈值接入
	  · flashEntries 定期 GC
	  · 增量监听蛋缓存（不再全量扫描）
	  · 篮子查找三重容错
	  · UI 位置切换重置拖拽状态
	  · 悬浮文字开关
	  · 紧急稀有度阈值可调

EggMaster V19 —— 简明说明

━━━━━━━━━━━━━━━━━━━━━━━━━━
【功能】
━━━━━━━━━━━━━━━━━━━━━━━━━━

一、自动偷蛋
  自动检测 RenderedEggs 里所有公共蛋，按价值从高到低偷。
  偷蛋用三路齐发：InputHoldBegin + fireproximityprompt + 模拟 E 键。
  每次偷蛋前先 BasketDrop 放下手上的蛋。

二、双模式
  偷蛋模式：偷到蛋 → 传送回自己篮子 → BasketDrop 放下。
  送蛋模式：偷到蛋 → 传送到目标玩家篮子 → BasketDrop 放下。

三、光柱 + 悬浮文字
  勾选的蛋上方生成光柱，颜色随稀有度（普通/稀有/史诗/传奇/神话/神/超越）。
  稀有及以上还显示悬浮文字：蛋名 + 稀有度 + 估值。
  光柱和文字都穿透渲染，隔墙可见。
  悬浮文字可单独开关。

四、安全区
  家附近半径内的蛋自动跳过。
  形状支持圆形 / 方形，半径手调。

五、树木处理
  隐藏 / 删除 树、灌木、叶子等干扰物。

━━━━━━━━━━━━━━━━━━━━━━━━━━
【特点】
━━━━━━━━━━━━━━━━━━━━━━━━━━

· 假蛋过滤三重保险（角色内排除 / 只在 RenderedEggs / Prompt 必须 Enabled）
· 传送用 Prompt.WorldPosition 精确定位
· 光柱/文字穿透渲染，隔墙可见
· UI 挂在 gethui，游戏清不掉
· 配置持久化到文件，重启不丢
· 拖拽后的面板位置也持久化
· 增量监听蛋缓存，性能更好
· flashEntries 定期 GC，无内存泄漏
· 紧急模式按稀有度阈值触发
· 篮子查找三重容错，兼容游戏更新

━━━━━━━━━━━━━━━━━━━━━━━━━━
【UI】
━━━━━━━━━━━━━━━━━━━━━━━━━━

面板包含 8 个可折叠卡片：

  ▼ 状态              - 光柱/蛋数量、当前状态
  ▼ 模式              - 偷蛋/送蛋切换 + 玩家列表
  ▼ 启动              - 开始/停止自动偷蛋
  ▼ 光柱筛选          - 7种稀有度勾选 + 光柱开关 + 悬浮文字开关
  ▼ 偷蛋筛选          - 7种稀有度勾选
  ▼ 安全区            - 圆形/方形 + 半径
  ▼ 速度 / 紧急模式   - 传送速度 + 紧急模式 + 紧急稀有度阈值
  ▼ 树木处理          - 关/隐藏/删除

顶部按钮：
  ⌗  切换面板位置（居中 / 四角 / 自定义拖拽）
  −  最小化整个面板

拖动标题栏可自由移动，位置自动保存。

━━━━━━━━━━━━━━━━━━━━━━━━━━
【用法】
━━━━━━━━━━━━━━━━━━━━━━━━━━

放置位置（三选一）：
  1. autoexec 目录 → 游戏启动自动执行
  2. StarterPlayerScripts → LocalScript
  3. 执行器手动执行

使用步骤：
  1. 执行脚本
  2. 勾选想偷的稀有度（偷蛋筛选卡片）
  3. 勾选想看光柱的稀有度（光柱筛选卡片）
  4. 点"显示光柱：开"
  5. （可选）点"悬浮文字：开/关"
  6. 选择模式：偷蛋 / 送蛋
     送蛋模式还要在玩家列表里选目标
  7. 点"开始自动偷蛋"

调参建议：
  传送速度        默认 2000，可调到 6000 更快
  紧急模式        开启后 ≥指定稀有度的蛋用 EMERGENCY_SPEED 速度
  紧急稀有度阈值  默认"神"，可调成"传奇"、"超越"等
  安全区半径      默认 150，家附近不想被偷就调大

━━━━━━━━━━━━━━━━━━━━━━━━━━
【日志速查】
━━━━━━━━━━━━━━━━━━━━━━━━━━

启动后 Console 打印：

  [EggMaster V19] 启动...
  [EggMaster] EggPickup: true  BasketDrop: true
  [EggMaster V19] 加载完成

如果 EggPickup 或 BasketDrop 是 false，脚本无法工作。

━━━━━━━━━━━━━━━━━━━━━━━━━━
【V19 相比 V16 的改动】
━━━━━━━━━━━━━━━━━━━━━━━━━━

1. 拖拽面板位置持久化，重启后保持在原位置
2. 紧急模式真正接入，按稀有度阈值切换速度
3. flashEntries 每 10 秒 GC 一次，避免内存泄漏
4. 蛋缓存改为增量监听，性能大幅提升
5. 篮子查找三重容错（属性 / Data.Owner / plot.Name）
6. UI 位置切换重置拖拽状态，避免坐标冲突
7. 新增悬浮文字开关
8. 新增紧急稀有度阈值按钮（7 选 1）
]]

print("[EggMaster V19] 启动...")

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local HttpService          = game:GetService("HttpService")

local localPlayer
for _ = 1, 50 do
	localPlayer = Players.LocalPlayer
	if localPlayer then break end
	task.wait(0.1)
end
if not localPlayer then return end
local playerGui = localPlayer:WaitForChild("PlayerGui", 30)

--=====================================================
-- 配置持久化
--=====================================================
local CONFIG_FILE = "EggMasterConfig.json"
local CONFIG_ATTR = "EggMasterConfig"
local canWriteFile = (typeof(writefile) == "function"
	and typeof(readfile) == "function" and typeof(isfile) == "function")

local function loadConfigTable()
	if canWriteFile then
		local ok, exists = pcall(isfile, CONFIG_FILE)
		if ok and exists then
			local ok2, content = pcall(readfile, CONFIG_FILE)
			if ok2 and content then
				local ok3, data = pcall(function() return HttpService:JSONDecode(content) end)
				if ok3 and type(data) == "table" then return data end
			end
		end
	end
	local attr = localPlayer:GetAttribute(CONFIG_ATTR)
	if typeof(attr) == "string" then
		local ok, data = pcall(function() return HttpService:JSONDecode(attr) end)
		if ok and type(data) == "table" then return data end
	end
	return nil
end

local function saveConfigTable(data)
	local ok, content = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok or not content then return end
	if canWriteFile then pcall(writefile, CONFIG_FILE, content) end
	pcall(function() localPlayer:SetAttribute(CONFIG_ATTR, content) end)
end

--=====================================================
-- 常量
--=====================================================
local PILLAR_NAME = "EggPillar"
local PILLAR_GAP = 5
local KEYWORDS = { "egg", "蛋" }
local FAKE_KEYWORDS = {
	"tracker", "npc", "dummy", "player", "character",
	"fake", "ghost", "visual", "preview", "pillar", "masterpillar",
}

local ARRIVE_DISTANCE = 5
local HOME_TIMEOUT = 8.0
local TREE_KEYWORDS = { "tree", "树", "bush", "leaf", "branch", "log", "trunk" }
local TREE_SKIP = { "terrain" }
local PILLAR_REFRESH_INTERVAL = 0.7
local FLASH_GC_INTERVAL = 10.0

--=====================================================
-- 运行时配置
--=====================================================
local TRANSPORT_SPEED = 2000
local EMERGENCY_SPEED = 10000
local EMERGENCY_ENABLED = false
local emergencyRarityMin = "God"    -- 紧急模式起始稀有度
local showEggLabels = true          -- 悬浮文字开关

local treeMode = "off"
local mode = "steal"
local targetPlayerName = nil
local zoneShape = "circle"
local zoneSize = 150
local panelPos = "center"
local customPanelX = nil
local customPanelY = nil

local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "God", "Beyond" }
local pillarEnabled = {}
local stealEnabled = {}
for _, n in ipairs(RARITY_ORDER) do
	pillarEnabled[n] = true
	stealEnabled[n] = true
end

local savedConfig = loadConfigTable()
if savedConfig then
	if type(savedConfig.transportSpeed) == "number" and savedConfig.transportSpeed > 5 then
		TRANSPORT_SPEED = savedConfig.transportSpeed
	end
	if type(savedConfig.emergencySpeed) == "number" and savedConfig.emergencySpeed > 10 then
		EMERGENCY_SPEED = savedConfig.emergencySpeed
	end
	if type(savedConfig.emergencyEnabled) == "boolean" then
		EMERGENCY_ENABLED = savedConfig.emergencyEnabled
	end
	if type(savedConfig.emergencyRarityMin) == "string"
		and table.find(RARITY_ORDER, savedConfig.emergencyRarityMin) then
		emergencyRarityMin = savedConfig.emergencyRarityMin
	end
	if type(savedConfig.showEggLabels) == "boolean" then
		showEggLabels = savedConfig.showEggLabels
	end
	if type(savedConfig.pillarEnabled) == "table" then
		for _, n in ipairs(RARITY_ORDER) do
			if type(savedConfig.pillarEnabled[n]) == "boolean" then
				pillarEnabled[n] = savedConfig.pillarEnabled[n]
			end
		end
	end
	if type(savedConfig.stealEnabled) == "table" then
		for _, n in ipairs(RARITY_ORDER) do
			if type(savedConfig.stealEnabled[n]) == "boolean" then
				stealEnabled[n] = savedConfig.stealEnabled[n]
			end
		end
	end
	if type(savedConfig.treeMode) == "string" then treeMode = savedConfig.treeMode end
	if type(savedConfig.mode) == "string" then mode = savedConfig.mode end
	if type(savedConfig.targetPlayerName) == "string" then
		targetPlayerName = savedConfig.targetPlayerName
	end
	if type(savedConfig.zoneShape) == "string" then zoneShape = savedConfig.zoneShape end
	if type(savedConfig.zoneSize) == "number" then zoneSize = savedConfig.zoneSize end
	if type(savedConfig.panelPos) == "string" then panelPos = savedConfig.panelPos end
	if type(savedConfig.customPanelX) == "number" then customPanelX = savedConfig.customPanelX end
	if type(savedConfig.customPanelY) == "number" then customPanelY = savedConfig.customPanelY end
end

local function saveAll()
	saveConfigTable({
		transportSpeed = TRANSPORT_SPEED,
		emergencySpeed = EMERGENCY_SPEED,
		emergencyEnabled = EMERGENCY_ENABLED,
		emergencyRarityMin = emergencyRarityMin,
		showEggLabels = showEggLabels,
		pillarEnabled = pillarEnabled,
		stealEnabled = stealEnabled,
		treeMode = treeMode,
		mode = mode,
		targetPlayerName = targetPlayerName,
		zoneShape = zoneShape,
		zoneSize = zoneSize,
		panelPos = panelPos,
		customPanelX = customPanelX,
		customPanelY = customPanelY,
	})
end

--=====================================================
-- 稀有度
--=====================================================
local RARITIES = {
	Common    = { color = Color3.fromRGB(220,220,220), height =  120, thick = 3, flash = false, cycle = false, speed = 0, label = "普通" },
	Rare      = { color = Color3.fromRGB( 80,180,255), height =  300, thick = 4, flash = false, cycle = false, speed = 0, label = "稀有" },
	Epic      = { color = Color3.fromRGB(180, 80,255), height =  550, thick = 5, flash = false, cycle = false, speed = 0, label = "史诗" },
	Legendary = { color = Color3.fromRGB(255,200, 60), height =  900, thick = 6, flash = true,  cycle = false, speed = 2, label = "传奇" },
	Mythic    = { color = Color3.fromRGB(255, 80,200), height = 1500, thick = 7, flash = true,  cycle = true,  speed = 3, label = "神话" },
	God       = { color = Color3.fromRGB(255, 60, 60),  height = 2300, thick = 8, flash = true,  cycle = true,  speed = 4, label = "神" },
	Beyond    = { color = Color3.fromRGB(  0,255,255), height = 3500, thick = 10, flash = true, cycle = true, speed = 6, label = "超越" },
}

local KNOWN_VALUES = {
	["White Egg"]=1, ["Brown Egg"]=5, ["Cracked Egg"]=30, ["Easter Egg"]=50,
	["Stone Egg"]=100, ["Leaf Egg"]=200, ["Mushroom Egg"]=500, ["Flower Egg"]=750,
	["Slime Egg"]=1e3, ["Ice Egg"]=3e3, ["Glass Egg"]=1e4, ["Golden Egg"]=3e4,
	["Diamond Egg"]=90e3, ["Crystal Egg"]=150e3, ["Skull Egg"]=250e3,
	["Asteroid Egg"]=500e3, ["Dominus Egg"]=700e3, ["Flaming Egg"]=1e6,
	["Sinister Egg"]=3e6, ["Soul Egg"]=7e6, ["Tidal Egg"]=8e6,
	["Aurora Egg"]=300e6, ["Galaxy Egg"]=1.5e9, ["Bloom Egg"]=2e9,
	["Blackhole Egg"]=100e9, ["Solaris Egg"]=300e9, ["Cherub Egg"]=1e12,
	["Volcanic Egg"]=2.5e12,
}

local function classifyValue(v)
	if v >= 1e11 then return "Beyond"
	elseif v >= 1e9 then return "God"
	elseif v >= 1e8 then return "Mythic"
	elseif v >= 1e7 then return "Legendary"
	elseif v >= 5e5 then return "Epic"
	elseif v >= 1e3 then return "Rare"
	else return "Common" end
end

local function lookupKnown(name)
	local v = KNOWN_VALUES[name]
	if v then return v end
	local function norm(s) return (string.lower(s):gsub("%s+", "")) end
	local target = norm(name)
	for k, val in pairs(KNOWN_VALUES) do
		if norm(k) == target then return val end
	end
	return nil
end

local function formatValue(v)
	if v >= 1e12 then return string.format("%.1fT", v / 1e12) end
	if v >= 1e9 then return string.format("%.1fB", v / 1e9) end
	if v >= 1e6 then return string.format("%.1fM", v / 1e6) end
	if v >= 1e3 then return string.format("%.1fK", v / 1e3) end
	return tostring(math.floor(v))
end

local function evalEggValue(model)
	return lookupKnown(model.Name) or 1e12
end

--=====================================================
-- Remote
--=====================================================
local EggPickup, BasketDrop
do
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local gameF = remotes and remotes:FindFirstChild("Game")
	EggPickup = gameF and gameF:FindFirstChild("EggPickup")
	BasketDrop = gameF and gameF:FindFirstChild("BasketDrop")
end
print("[EggMaster] EggPickup:", EggPickup ~= nil, " BasketDrop:", BasketDrop ~= nil)

--=====================================================
-- 工具
--=====================================================
local function nameHas(name, list)
	local lower = string.lower(name)
	for _, kw in ipairs(list) do
		if string.find(lower, string.lower(kw), 1, true) then return true end
	end
	return false
end

local function isLocalCharDescendant(inst)
	local char = localPlayer.Character
	return char and inst:IsDescendantOf(char)
end

local function isRealEgg(inst)
	if not inst:IsA("Model") then return false end
	if inst.Name == PILLAR_NAME then return false end
	if not nameHas(inst.Name, KEYWORDS) then return false end
	if inst:FindFirstChildOfClass("Humanoid") then return false end
	if nameHas(inst.Name, FAKE_KEYWORDS) then return false end
	if isLocalCharDescendant(inst) then return false end

	local renderedRoot = workspace:FindFirstChild("RenderedEggs")
	if not renderedRoot then return false end
	if not inst:IsDescendantOf(renderedRoot) then return false end

	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled and d.MaxActivationDistance > 0 then
			return true
		end
	end
	return false
end

local function findPrompt(model)
	local best
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled then
			if not best or d.MaxActivationDistance > best.MaxActivationDistance then
				best = d
			end
		end
	end
	return best
end

local function findMainPart(model)
	if model.PrimaryPart then return model.PrimaryPart end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function getEggInteractPoint(egg)
	if egg.prompt then
		local ok, wp = pcall(function() return egg.prompt.WorldPosition end)
		if ok and wp then return wp end
	end
	local ok, cf, size = pcall(function()
		local c, s = egg.model:GetBoundingBox()
		return c, s
	end)
	if ok and cf and size then
		return Vector3.new(cf.Position.X, cf.Position.Y - size.Y * 0.5 + 3, cf.Position.Z)
	end
	if egg.pivot then return egg.pivot.Position end
	return nil
end

--=====================================================
-- ★ V19：增量监听蛋缓存
--=====================================================
local eggModelCache = {}   -- [Model] = true

local function addEggToCache(inst)
	if eggModelCache[inst] then return end
	if isRealEgg(inst) then
		eggModelCache[inst] = true
	end
end

local function removeEggFromCache(inst)
	eggModelCache[inst] = nil
end

-- 初始化缓存
do
	local root = workspace:FindFirstChild("RenderedEggs")
	if root then
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Model") and isRealEgg(d) then
				eggModelCache[d] = true
			end
		end
		root.DescendantAdded:Connect(function(d)
			if d:IsA("Model") then
				task.defer(function()
					if d.Parent then addEggToCache(d) end
				end)
			end
		end)
		root.DescendantRemoving:Connect(function(d)
			if d:IsA("Model") then
				removeEggFromCache(d)
			end
		end)
	end
end

-- 新加入 RenderedEggs 时（比如整个 RenderedEggs 被替换）
workspace.DescendantAdded:Connect(function(d)
	if d.Name == "RenderedEggs" then
		task.wait(0.1)
		for _, dd in ipairs(d:GetDescendants()) do
			if dd:IsA("Model") and isRealEgg(dd) then
				eggModelCache[dd] = true
			end
		end
		d.DescendantAdded:Connect(function(x)
			if x:IsA("Model") then
				task.defer(function()
					if x.Parent then addEggToCache(x) end
				end)
			end
		end)
		d.DescendantRemoving:Connect(function(x)
			if x:IsA("Model") then removeEggFromCache(x) end
		end)
	end
end)

-- 从缓存收集蛋（O(n) 但 n = 当前有效蛋数量）
local function collectEggs()
	local list = {}
	local toRemove = {}
	for model in pairs(eggModelCache) do
		if not model.Parent then
			toRemove[#toRemove + 1] = model
		else
			-- 检查嵌套（避免同一个蛋被重复加入）
			local nested = false
			local p = model.Parent
			while p and p.Name ~= "RenderedEggs" do
				if eggModelCache[p] then
					nested = true
					break
				end
				p = p.Parent
			end
			if not nested then
				local part = findMainPart(model)
				if part then
					local prompt = findPrompt(model)
					if prompt then
						local value = evalEggValue(model)
						list[#list + 1] = {
							model = model,
							pivot = part,
							value = value,
							rarity = classifyValue(value),
							prompt = prompt,
						}
					end
				end
			end
		end
	end
	for _, m in ipairs(toRemove) do
		eggModelCache[m] = nil
	end
	return list
end

--=====================================================
-- 篮子查找（三重容错）
--=====================================================
local function findPlayerPlot(plr)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return nil end
	for _, plot in ipairs(plots:GetChildren()) do
		-- 方式 1：OwnerUserId 属性
		local owner = plot:GetAttribute("OwnerUserId")
		if owner and owner == plr.UserId then return plot end
		-- 方式 2：Data.Owner.Value
		local data = plot:FindFirstChild("Data")
		if data then
			local ownerName = data:FindFirstChild("Owner")
			if ownerName and ownerName.Value == plr.Name then return plot end
		end
		-- 方式 3：plot.Name 含玩家名
		if plot.Name:find(plr.Name, 1, true) then return plot end
	end
	return nil
end

local function findBasketForPlayer(plr)
	local plot = findPlayerPlot(plr)
	if not plot then return nil end
	local candidates = { "Basket", "EggBasket", "Float", "EggSlot", "BasketPoint", "EggBag" }
	for _, name in ipairs(candidates) do
		local b = plot:FindFirstChild(name, true)
		if b and b:IsA("BasePart") then return b end
	end
	local nests = plot:FindFirstChild("Nests", true)
	if nests then
		local n1 = nests:FindFirstChild("1")
		if n1 then
			for _, d in ipairs(n1:GetDescendants()) do
				if d:IsA("BasePart") then return d end
			end
		end
	end
	local base = plot:FindFirstChildOfClass("BasePart")
	if base then return base end
	return nil
end

--=====================================================
-- 安全区
--=====================================================
local homeCenter = nil

local function refreshHomeCenter()
	local b = findBasketForPlayer(localPlayer)
	if b then homeCenter = b.Position end
end
refreshHomeCenter()

local function isInSafeZone(pos)
	if not homeCenter then return false end
	local diff = pos - homeCenter
	if zoneShape == "square" then
		return math.abs(diff.X) <= zoneSize and math.abs(diff.Z) <= zoneSize
	else
		return math.sqrt(diff.X * diff.X + diff.Z * diff.Z) <= zoneSize
	end
end

--=====================================================
-- 光柱
--=====================================================
local pillarModel = Instance.new("Model")
pillarModel.Name = "EggMasterPillars"
pcall(function()
	pillarModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end)
pillarModel.Parent = workspace

local modelToPillar = {}
local pillarActive = false
local flashEntries = {}

local function createPillar(egg)
	if modelToPillar[egg.model] then return end
	if not egg.model.Parent then return end

	local rule = RARITIES[egg.rarity]

	local centerPos
	if egg.prompt then
		local ok, wp = pcall(function() return egg.prompt.WorldPosition end)
		if ok and wp then centerPos = wp end
	end
	if not centerPos then
		local ok, cf = pcall(function()
			local c = egg.model:GetBoundingBox()
			return c
		end)
		if ok and cf then
			centerPos = cf.Position
		else
			centerPos = egg.pivot.Position
		end
	end

	local baseY = centerPos.Y + PILLAR_GAP
	local centerY = baseY + rule.height * 0.5
	local pos = Vector3.new(centerPos.X, centerY, centerPos.Z)

	local pillar = Instance.new("Part")
	pillar.Name = PILLAR_NAME
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanTouch = false
	pillar.CanQuery = false
	pillar.CastShadow = false
	pillar.Locked = true
	pillar.Massless = true
	pillar.Material = Enum.Material.Neon
	pillar.Color = rule.color
	pillar.Transparency = 0.05
	pillar.Size = Vector3.new(rule.thick, rule.height, rule.thick)
	pillar.CFrame = CFrame.new(pos)
	pillar.Parent = pillarModel

	local light = Instance.new("PointLight")
	light.Color = rule.color
	light.Brightness = 4 + math.min(rule.height / 300, 4)
	light.Range = 40 + math.min(rule.height / 20, 40)
	light.Shadows = false
	light.Parent = pillar

	local hl = Instance.new("Highlight")
	hl.Name = "PillarPerspective"
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillColor = rule.color
	hl.FillTransparency = 0.7
	hl.OutlineColor = rule.color
	hl.OutlineTransparency = 0
	hl.Adornee = pillar
	hl.Parent = pillar

	-- ★ V19：悬浮文字开关 + 非普通才显示
	if showEggLabels and egg.rarity ~= "Common" then
		local bb = Instance.new("BillboardGui")
		bb.Name = "PillarLabel"
		bb.Size = UDim2.fromOffset(220, 70)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.MaxDistance = 5000
		bb.Adornee = pillar
		bb.StudsOffsetWorldSpace = Vector3.new(0, rule.height * 0.5 + 8, 0)
		bb.Parent = pillar

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "NameLabel"
		nameLbl.BackgroundTransparency = 1
		nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
		nameLbl.Position = UDim2.new(0, 0, 0, 0)
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.Text = egg.model.Name
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextStrokeTransparency = 0
		nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLbl.TextScaled = true
		nameLbl.Parent = bb

		local valLbl = Instance.new("TextLabel")
		valLbl.Name = "ValueLabel"
		valLbl.BackgroundTransparency = 1
		valLbl.Size = UDim2.new(1, 0, 0.45, 0)
		valLbl.Position = UDim2.new(0, 0, 0.55, 0)
		valLbl.Font = Enum.Font.GothamBold
		valLbl.Text = rule.label .. "  " .. formatValue(egg.value)
		valLbl.TextColor3 = rule.color
		valLbl.TextStrokeTransparency = 0
		valLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		valLbl.TextScaled = true
		valLbl.Parent = bb
	end

	modelToPillar[egg.model] = pillar
	if rule.flash then
		flashEntries[pillar] = { rarity = egg.rarity, phase = math.random() * 10 }
	end
end

local function removePillar(model)
	local p = modelToPillar[model]
	if p then
		flashEntries[p] = nil
		pcall(function() p:Destroy() end)
		modelToPillar[model] = nil
	end
end

local function clearPillars()
	for m in pairs(modelToPillar) do
		removePillar(m)
	end
	table.clear(modelToPillar)
	table.clear(flashEntries)
	if pillarModel then
		for _, v in ipairs(pillarModel:GetChildren()) do
			pcall(function() v:Destroy() end)
		end
	end
end

local function syncPillars()
	for m in pairs(modelToPillar) do
		if not m.Parent or not eggModelCache[m] then
			removePillar(m)
		end
	end
	for _, egg in ipairs(collectEggs()) do
		if pillarEnabled[egg.rarity] then
			createPillar(egg)
		else
			removePillar(egg.model)
		end
	end
end

task.spawn(function()
	while true do
		task.wait(PILLAR_REFRESH_INTERVAL)
		if pillarActive then
			pcall(syncPillars)
		end
	end
end)

-- 闪烁循环
task.spawn(function()
	while true do
		local t = tick()
		for pillar, info in pairs(flashEntries) do
			if not pillar.Parent then
				flashEntries[pillar] = nil
			else
				local rule = RARITIES[info.rarity]
				local pulse = 0.5 + 0.5 * math.sin(t * (4 + rule.speed) + info.phase)
				local c = rule.color
				if rule.cycle then
					local h = (t * 0.1 * (1 + rule.speed / 3) + info.phase * 0.1) % 1
					local _, s, v = Color3.toHSV(rule.color)
					c = Color3.fromHSV(h, math.max(s, 0.7), v)
				else
					c = rule.color:Lerp(Color3.new(1, 1, 1), pulse * 0.5)
				end
				pillar.Color = c
				pillar.Transparency = 0.05 + pulse * 0.25
				local light = pillar:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = c
					light.Brightness = 5 + pulse * 6
				end
				local hl = pillar:FindFirstChild("PillarPerspective")
				if hl then
					hl.FillColor = c
					hl.OutlineColor = c
				end
			end
		end
		task.wait(0.03)
	end
end)

-- ★ V19：定期 GC flashEntries
task.spawn(function()
	while true do
		task.wait(FLASH_GC_INTERVAL)
		local toRemove = {}
		for pillar in pairs(flashEntries) do
			if not pillar or not pillar.Parent then
				toRemove[#toRemove + 1] = pillar
			end
		end
		for _, p in ipairs(toRemove) do
			flashEntries[p] = nil
		end
	end
end)

--=====================================================
-- 树木
--=====================================================
local treeHidden = {}
local TREE_HIDE_RULES = {
	{ Class = "BasePart", Props = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CanClimb = false } },
	{ Class = "ParticleEmitter", Props = { Enabled = false } },
	{ Class = "Light", Props = { Enabled = false } },
}

local function isTreeInstance(inst)
	if not nameHas(inst.Name, TREE_KEYWORDS) then return false end
	if nameHas(inst.Name, TREE_SKIP) then return false end
	if localPlayer.Character and inst:IsDescendantOf(localPlayer.Character) then return false end
	return true
end

local function hasTreeAncestor(inst)
	local p = inst.Parent
	while p and p ~= workspace do
		if isTreeInstance(p) then return true end
		p = p.Parent
	end
	return false
end

local function hideOneTree(root)
	if treeHidden[root] then return end
	local entries = {}
	local function tryHide(inst)
		for _, rule in ipairs(TREE_HIDE_RULES) do
			if inst:IsA(rule.Class) then
				for prop, newVal in pairs(rule.Props) do
					local ok, oldVal = pcall(function() return (inst :: any)[prop] end)
					if ok and oldVal ~= nil and oldVal ~= newVal then
						entries[#entries + 1] = { inst = inst, prop = prop, old = oldVal }
						pcall(function() (inst :: any)[prop] = newVal end)
					end
				end
				break
			end
		end
	end
	tryHide(root)
	for _, d in ipairs(root:GetDescendants()) do
		tryHide(d)
	end
	treeHidden[root] = entries
end

local function restoreOneTree(root)
	local entries = treeHidden[root]
	if not entries then return end
	for _, e in ipairs(entries) do
		pcall(function() (e.inst :: any)[e.prop] = e.old end)
	end
	treeHidden[root] = nil
end

local function applyTreeMode()
	if treeMode == "off" then return end
	for _, d in ipairs(workspace:GetDescendants()) do
		if isTreeInstance(d) and not hasTreeAncestor(d) then
			if treeMode == "hide" then
				hideOneTree(d)
			elseif treeMode == "delete" then
				treeHidden[d] = nil
				pcall(function() d:Destroy() end)
			end
		end
	end
end

local function restoreAllTrees()
	local keys = {}
	for k in pairs(treeHidden) do
		keys[#keys + 1] = k
	end
	for _, k in ipairs(keys) do
		restoreOneTree(k)
	end
	table.clear(treeHidden)
end

--=====================================================
-- 自动农场
--=====================================================
local autoActive = false
local autoStatus = "空闲"

RunService.Stepped:Connect(function()
	if not autoActive then return end
	local char = localPlayer.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.CanCollide then d.CanCollide = false end
			if d.CanTouch then d.CanTouch = false end
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and not hum.PlatformStand then
		hum.PlatformStand = true
	end
end)

local lastSetPos = nil
local moveTarget = nil
local moveSpeed = TRANSPORT_SPEED

local function setMoveTarget(pos, speed)
	moveTarget = pos
	moveSpeed = speed or TRANSPORT_SPEED
	lastSetPos = nil
end

RunService.Heartbeat:Connect(function(dt)
	local char = localPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local target = moveTarget
	if not target then
		lastSetPos = nil
		return
	end

	local cur = hrp.Position

	-- ★ V19：只有真正卡住才回滚
	if lastSetPos then
		local disc = (cur - lastSetPos).Magnitude
		if disc > 50 then
			char:PivotTo(CFrame.new(lastSetPos) * (hrp.CFrame - hrp.CFrame.Position))
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			return
		end
	end

	local diff = target - cur
	local dist = diff.Magnitude

	if dist < 0.5 then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		lastSetPos = cur
		return
	end

	local step = math.min(dist, moveSpeed * dt)
	local newPos = cur + diff.Unit * step
	char:PivotTo(CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position))
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	lastSetPos = newPos
end)

local function applyCharState(fly)
	local char = localPlayer.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = not fly
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		if not fly then
			hum.PlatformStand = false
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		else
			hum.PlatformStand = true
		end
	end
end

local function travelTo(targetPos, speed, timeout)
	local t0 = tick()
	setMoveTarget(targetPos, speed)
	while tick() - t0 < timeout do
		local char = localPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			if (hrp.Position - targetPos).Magnitude < ARRIVE_DISTANCE then
				moveTarget = nil
				return "arrived"
			end
		end
		task.wait(0.03)
	end
	moveTarget = nil
	return "timeout"
end

local function tryGrab(egg)
	if not egg.prompt or not egg.prompt.Parent then return false end
	local prompt = egg.prompt

	pcall(function() prompt:InputHoldBegin() end)
	if typeof(fireproximityprompt) == "function" then
		pcall(function() fireproximityprompt(prompt) end)
	end
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
	end)

	local waitTime = math.max(prompt.HoldDuration, 0.3) + 0.4
	local t0 = tick()
	while tick() - t0 < waitTime do
		if not egg.model.Parent then
			pcall(function() prompt:InputHoldEnd() end)
			pcall(function()
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			end)
			return true
		end
		task.wait(0.05)
	end

	pcall(function() prompt:InputHoldEnd() end)
	pcall(function()
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
	task.wait(0.15)
	return not egg.model.Parent
end

local function dropBasket()
	if BasketDrop then
		pcall(function() BasketDrop:FireServer() end)
	end
end

local function deliverToTarget()
	if not targetPlayerName then return false end
	local target = Players:FindFirstChild(targetPlayerName)
	if not target then return false end
	local basket = findBasketForPlayer(target)
	if not basket then
		autoStatus = "⚠ 找不到 " .. targetPlayerName .. " 的篮子"
		return false
	end
	autoStatus = "送货中 → " .. targetPlayerName
	travelTo(basket.Position + Vector3.new(0, 5, 0), EMERGENCY_SPEED, HOME_TIMEOUT)
	task.wait(0.3)
	dropBasket()
	task.wait(0.5)
	return true
end

local function goHome()
	local basket = findBasketForPlayer(localPlayer)
	if not basket then
		dropBasket()
		return
	end
	autoStatus = "回家中..."
	travelTo(basket.Position + Vector3.new(0, 5, 0), EMERGENCY_SPEED, HOME_TIMEOUT)
	task.wait(0.3)
	dropBasket()
	task.wait(0.5)
end

-- ★ V19：紧急模式接入
local function speedForEgg(egg)
	if EMERGENCY_ENABLED then
		local eggIdx = table.find(RARITY_ORDER, egg.rarity)
		local minIdx = table.find(RARITY_ORDER, emergencyRarityMin)
		if eggIdx and minIdx and eggIdx >= minIdx then
			return EMERGENCY_SPEED
		end
	end
	return TRANSPORT_SPEED
end

local function startAuto()
	if autoActive then return end
	if mode == "deliver" and not targetPlayerName then
		autoStatus = "⚠ 送蛋模式请先选择目标玩家"
		return
	end
	autoActive = true
	applyCharState(true)
	refreshHomeCenter()

	task.spawn(function()
		while autoActive do
			local eggs = collectEggs()
			local filtered = {}
			for _, e in ipairs(eggs) do
				if stealEnabled[e.rarity] then
					filtered[#filtered + 1] = e
				end
			end
			table.sort(filtered, function(a, b) return a.value > b.value end)

			if #filtered == 0 then
				setMoveTarget(nil)
				autoStatus = "无目标，悬浮等待..."
				task.wait(1)
			else
				for i, egg in ipairs(filtered) do
					if not autoActive then break end
					if not egg.model.Parent then
						continue
					end

					if isInSafeZone(egg.pivot.Position) then
						autoStatus = string.format("[%d/%d] %s 在安全区，跳过",
							i, #filtered, egg.model.Name)
						continue
					end

					autoStatus = string.format("[%d/%d] %s (%s)",
						i, #filtered, egg.model.Name, egg.rarity)

					dropBasket()
					task.wait(0.4)

					local point = getEggInteractPoint(egg)
					if point then
						-- ★ V19：按稀有度选择速度
						local spd = speedForEgg(egg)
						travelTo(point, spd, 4)
						task.wait(0.2)

						if tryGrab(egg) then
							autoStatus = string.format("[%d/%d] %s 成功",
								i, #filtered, egg.model.Name)
							if mode == "deliver" then
								deliverToTarget()
							else
								goHome()
							end
						else
							autoStatus = string.format("[%d/%d] %s 失败",
								i, #filtered, egg.model.Name)
						end
					end
					task.wait(0.3)
				end
				task.wait(0.5)
			end
		end
		setMoveTarget(nil)
		applyCharState(false)
		autoStatus = "空闲"
	end)
end

local function stopAuto()
	autoActive = false
end

--=====================================================
-- UI
--=====================================================
local cam = workspace.CurrentCamera
local viewport = cam and cam.ViewportSize or Vector2.new(1920, 1080)
local PANEL_W = 340
local PANEL_H = 520

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggMasterUI_V19"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
do
	local parent
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and h then parent = h end
	end
	if not parent then
		local ok, cg = pcall(function() return game:GetService("CoreGui") end)
		if ok and cg then parent = cg end
	end
	if not parent then parent = playerGui end
	screenGui.Parent = parent
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
panel.Active = true
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local pStroke = Instance.new("UIStroke")
pStroke.Color = Color3.fromRGB(70, 75, 90)
pStroke.Thickness = 1
pStroke.Parent = panel

local function applyPanelPos()
	if panelPos == "custom" and customPanelX and customPanelY then
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = UDim2.fromOffset(customPanelX, customPanelY)
		return
	end
	local preset = {
		center = {0.5, 0.5, 0, 0},
		tl = {0, 0, 12, 12},
		tr = {1, 0, -12, 12},
		bl = {0, 1, 12, -12},
		br = {1, 1, -12, -12},
	}
	local p = preset[panelPos] or preset.center
	panel.AnchorPoint = Vector2.new(p[1], p[2])
	panel.Position = UDim2.new(p[1], p[3], p[2], p[4])
end
applyPanelPos()

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.BackgroundTransparency = 1
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 0)
title.Size = UDim2.new(1, -120, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "EggMaster V19"
title.TextColor3 = Color3.fromRGB(240, 242, 248)
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local posBtn = Instance.new("TextButton")
posBtn.AnchorPoint = Vector2.new(1, 0.5)
posBtn.Position = UDim2.new(1, -44, 0.5, 0)
posBtn.Size = UDim2.fromOffset(28, 26)
posBtn.BackgroundColor3 = Color3.fromRGB(50, 54, 64)
posBtn.BorderSizePixel = 0
posBtn.Font = Enum.Font.GothamBold
posBtn.Text = "⌗"
posBtn.TextColor3 = Color3.fromRGB(200, 210, 220)
posBtn.TextSize = 16
posBtn.Parent = titleBar
Instance.new("UICorner", posBtn).CornerRadius = UDim.new(0, 6)

local minBtn = Instance.new("TextButton")
minBtn.AnchorPoint = Vector2.new(1, 0.5)
minBtn.Position = UDim2.new(1, -10, 0.5, 0)
minBtn.Size = UDim2.fromOffset(28, 26)
minBtn.BackgroundColor3 = Color3.fromRGB(50, 54, 64)
minBtn.BorderSizePixel = 0
minBtn.Font = Enum.Font.GothamBold
minBtn.Text = "−"
minBtn.TextColor3 = Color3.fromRGB(200, 210, 220)
minBtn.TextSize = 18
minBtn.Parent = titleBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- 位置菜单
local posMenu = Instance.new("Frame")
posMenu.Visible = false
posMenu.AnchorPoint = Vector2.new(1, 0)
posMenu.Position = UDim2.new(1, -10, 0, 42)
posMenu.Size = UDim2.fromOffset(140, 172)
posMenu.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
posMenu.BorderSizePixel = 0
posMenu.ZIndex = 10
posMenu.Parent = panel
Instance.new("UICorner", posMenu).CornerRadius = UDim.new(0, 8)
local posMenuPad = Instance.new("UIPadding", posMenu)
posMenuPad.PaddingTop = UDim.new(0, 4)
local posMenuLayout = Instance.new("UIListLayout", posMenu)
posMenuLayout.Padding = UDim.new(0, 3)
posMenuLayout.SortOrder = Enum.SortOrder.LayoutOrder

local posOptions = {
	{ key = "center", label = "居中" },
	{ key = "tl", label = "左上角" },
	{ key = "tr", label = "右上角" },
	{ key = "bl", label = "左下角" },
	{ key = "br", label = "右下角" },
}
local posMenuBtns = {}
for i, opt in ipairs(posOptions) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0, 26)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.Gotham
	btn.Text = opt.label
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextSize = 12
	btn.LayoutOrder = i
	btn.Parent = posMenu
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
	posMenuBtns[opt.key] = btn
	btn.MouseButton1Click:Connect(function()
		panelPos = opt.key
		customPanelX = nil
		customPanelY = nil
		-- ★ V19：重置拖拽状态
		isDragging = false
		applyPanelPos()
		posMenu.Visible = false
		for k, b in pairs(posMenuBtns) do
			b.BackgroundColor3 = (k == panelPos)
				and Color3.fromRGB(70, 130, 200)
				or Color3.fromRGB(40, 44, 54)
		end
		saveAll()
	end)
end
for k, b in pairs(posMenuBtns) do
	b.BackgroundColor3 = (k == panelPos)
		and Color3.fromRGB(70, 130, 200)
		or Color3.fromRGB(40, 44, 54)
end

posBtn.MouseButton1Click:Connect(function()
	posMenu.Visible = not posMenu.Visible
end)

-- 内容
local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.new(0, 0, 0, 40)
content.Size = UDim2.new(1, 0, 1, -46)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = Color3.fromRGB(80, 85, 100)
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = panel

local contentLayout = Instance.new("UIListLayout", content)
contentLayout.Padding = UDim.new(0, 6)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder

local contentPad = Instance.new("UIPadding", content)
contentPad.PaddingLeft = UDim.new(0, 8)
contentPad.PaddingRight = UDim.new(0, 8)
contentPad.PaddingTop = UDim.new(0, 4)
contentPad.PaddingBottom = UDim.new(0, 8)

local orderCounter = 0
local function nextOrder()
	orderCounter += 10
	return orderCounter
end

local function makeCard(titleText)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = nextOrder()
	card.Parent = content
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local cardLayout = Instance.new("UIListLayout", card)
	cardLayout.Padding = UDim.new(0, 6)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local cardPad = Instance.new("UIPadding", card)
	cardPad.PaddingLeft = UDim.new(0, 10)
	cardPad.PaddingRight = UDim.new(0, 10)
	cardPad.PaddingTop = UDim.new(0, 6)
	cardPad.PaddingBottom = UDim.new(0, 8)

	local header = Instance.new("TextButton")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 18)
	header.Font = Enum.Font.GothamBold
	header.Text = "▼ " .. titleText
	header.TextColor3 = Color3.fromRGB(150, 200, 255)
	header.TextSize = 12
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = 0
	header.Parent = card

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 1
	body.Parent = card
	local bodyLayout = Instance.new("UIListLayout", body)
	bodyLayout.Padding = UDim.new(0, 4)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder

	header.MouseButton1Click:Connect(function()
		body.Visible = not body.Visible
		header.Text = (body.Visible and "▼ " or "▶ ") .. titleText
	end)

	return card, body, header
end

local function contrastText(c)
	local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return lum > 0.55 and Color3.fromRGB(20,20,20) or Color3.fromRGB(255,255,255)
end

-- 状态
local statusCard, statusBody = makeCard("状态")
local statsLbl = Instance.new("TextLabel")
statsLbl.BackgroundTransparency = 1
statsLbl.Size = UDim2.new(1, 0, 0, 16)
statsLbl.Font = Enum.Font.Code
statsLbl.Text = "光柱 0 / 蛋 0"
statsLbl.TextColor3 = Color3.fromRGB(130, 190, 255)
statsLbl.TextSize = 11
statsLbl.TextXAlignment = Enum.TextXAlignment.Left
statsLbl.LayoutOrder = 1
statsLbl.Parent = statusBody

local autoStatusLbl = Instance.new("TextLabel")
autoStatusLbl.BackgroundTransparency = 1
autoStatusLbl.Size = UDim2.new(1, 0, 0, 16)
autoStatusLbl.AutomaticSize = Enum.AutomaticSize.Y
autoStatusLbl.Font = Enum.Font.Code
autoStatusLbl.Text = "空闲"
autoStatusLbl.TextColor3 = Color3.fromRGB(160, 220, 200)
autoStatusLbl.TextSize = 11
autoStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
autoStatusLbl.TextYAlignment = Enum.TextYAlignment.Top
autoStatusLbl.TextWrapped = true
autoStatusLbl.LayoutOrder = 2
autoStatusLbl.Parent = statusBody

-- 模式
local modeCard, modeBody = makeCard("模式")

local modeRow = Instance.new("Frame")
modeRow.BackgroundTransparency = 1
modeRow.Size = UDim2.new(1, 0, 0, 28)
modeRow.LayoutOrder = 1
modeRow.Parent = modeBody

local stealModeBtn = Instance.new("TextButton")
stealModeBtn.Size = UDim2.new(0.5, -3, 1, 0)
stealModeBtn.BorderSizePixel = 0
stealModeBtn.Font = Enum.Font.GothamMedium
stealModeBtn.Text = "偷蛋模式"
stealModeBtn.TextSize = 12
stealModeBtn.TextColor3 = Color3.new(1, 1, 1)
stealModeBtn.Parent = modeRow
Instance.new("UICorner", stealModeBtn).CornerRadius = UDim.new(0, 5)

local deliverModeBtn = Instance.new("TextButton")
deliverModeBtn.Position = UDim2.new(0.5, 3, 0, 0)
deliverModeBtn.Size = UDim2.new(0.5, -3, 1, 0)
deliverModeBtn.BorderSizePixel = 0
deliverModeBtn.Font = Enum.Font.GothamMedium
deliverModeBtn.Text = "送蛋模式"
deliverModeBtn.TextSize = 12
deliverModeBtn.TextColor3 = Color3.new(1, 1, 1)
deliverModeBtn.Parent = modeRow
Instance.new("UICorner", deliverModeBtn).CornerRadius = UDim.new(0, 5)

local function updateModeUI()
	if mode == "steal" then
		stealModeBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
		deliverModeBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
	else
		stealModeBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
		deliverModeBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
	end
end

local playerListLbl = Instance.new("TextLabel")
playerListLbl.BackgroundTransparency = 1
playerListLbl.Size = UDim2.new(1, 0, 0, 14)
playerListLbl.Font = Enum.Font.Gotham
playerListLbl.Text = "选择目标玩家："
playerListLbl.TextColor3 = Color3.fromRGB(180, 185, 200)
playerListLbl.TextSize = 11
playerListLbl.TextXAlignment = Enum.TextXAlignment.Left
playerListLbl.LayoutOrder = 2
playerListLbl.Parent = modeBody

local playerListScroll = Instance.new("ScrollingFrame")
playerListScroll.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
playerListScroll.BorderSizePixel = 0
playerListScroll.Size = UDim2.new(1, 0, 0, 100)
playerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
playerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerListScroll.ScrollBarThickness = 3
playerListScroll.LayoutOrder = 3
playerListScroll.Parent = modeBody
Instance.new("UICorner", playerListScroll).CornerRadius = UDim.new(0, 5)
local plsLayout = Instance.new("UIListLayout", playerListScroll)
plsLayout.Padding = UDim.new(0, 3)
local plsPad = Instance.new("UIPadding", playerListScroll)
plsPad.PaddingLeft = UDim.new(0, 4)
plsPad.PaddingRight = UDim.new(0, 4)
plsPad.PaddingTop = UDim.new(0, 4)
plsPad.PaddingBottom = UDim.new(0, 4)

local function rebuildPlayerList()
	for _, c in ipairs(playerListScroll:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	local count = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= localPlayer then
			count += 1
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 24)
			btn.BackgroundColor3 = (targetPlayerName == plr.Name)
				and Color3.fromRGB(200, 130, 40)
				or Color3.fromRGB(40, 44, 54)
			btn.BorderSizePixel = 0
			btn.Font = Enum.Font.Gotham
			btn.Text = plr.Name
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.TextSize = 11
			btn.Parent = playerListScroll
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
			btn.MouseButton1Click:Connect(function()
				targetPlayerName = plr.Name
				rebuildPlayerList()
				saveAll()
			end)
		end
	end
	if count == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 20)
		empty.Font = Enum.Font.Gotham
		empty.Text = "（无其他玩家）"
		empty.TextColor3 = Color3.fromRGB(120, 125, 140)
		empty.TextSize = 11
		empty.Parent = playerListScroll
	end
end
rebuildPlayerList()
Players.PlayerAdded:Connect(function()
	task.wait(0.5)
	rebuildPlayerList()
end)
Players.PlayerRemoving:Connect(function()
	task.wait(0.5)
	rebuildPlayerList()
end)

stealModeBtn.MouseButton1Click:Connect(function()
	mode = "steal"
	updateModeUI()
	saveAll()
end)
deliverModeBtn.MouseButton1Click:Connect(function()
	mode = "deliver"
	updateModeUI()
	saveAll()
end)
updateModeUI()

-- 启动
local startCard, startBody = makeCard("启动")
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, 0, 0, 34)
autoBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
autoBtn.BorderSizePixel = 0
autoBtn.Font = Enum.Font.GothamBold
autoBtn.Text = "开始自动偷蛋"
autoBtn.TextColor3 = Color3.new(1, 1, 1)
autoBtn.TextSize = 13
autoBtn.LayoutOrder = 1
autoBtn.Parent = startBody
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 6)

autoBtn.MouseButton1Click:Connect(function()
	if autoActive then
		stopAuto()
		applyCharState(false)
		autoBtn.Text = "开始自动偷蛋"
		autoBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
	else
		if mode == "deliver" and not targetPlayerName then
			autoStatus = "⚠ 请先在模式卡片选择目标玩家"
			return
		end
		startAuto()
		autoBtn.Text = "停止自动偷蛋"
		autoBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
	end
end)

-- 光柱
local pillarCard, pillarBody = makeCard("光柱筛选")
local pillarToggleBtn = Instance.new("TextButton")
pillarToggleBtn.Size = UDim2.new(1, 0, 0, 28)
pillarToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 150)
pillarToggleBtn.BorderSizePixel = 0
pillarToggleBtn.Font = Enum.Font.GothamMedium
pillarToggleBtn.Text = "显示光柱：关"
pillarToggleBtn.TextColor3 = Color3.new(1, 1, 1)
pillarToggleBtn.TextSize = 12
pillarToggleBtn.LayoutOrder = 1
pillarToggleBtn.Parent = pillarBody
Instance.new("UICorner", pillarToggleBtn).CornerRadius = UDim.new(0, 5)

-- ★ V19：悬浮文字开关
local labelToggleBtn = Instance.new("TextButton")
labelToggleBtn.Size = UDim2.new(1, 0, 0, 26)
labelToggleBtn.BorderSizePixel = 0
labelToggleBtn.Font = Enum.Font.GothamMedium
labelToggleBtn.TextSize = 11
labelToggleBtn.TextColor3 = Color3.new(1, 1, 1)
labelToggleBtn.LayoutOrder = 2
labelToggleBtn.Parent = pillarBody
Instance.new("UICorner", labelToggleBtn).CornerRadius = UDim.new(0, 5)

local function updateLabelToggle()
	if showEggLabels then
		labelToggleBtn.Text = "悬浮文字：开"
		labelToggleBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
	else
		labelToggleBtn.Text = "悬浮文字：关"
		labelToggleBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
	end
end
updateLabelToggle()

labelToggleBtn.MouseButton1Click:Connect(function()
	showEggLabels = not showEggLabels
	updateLabelToggle()
	-- 重建所有光柱以应用开关
	if pillarActive then
		clearPillars()
		syncPillars()
	end
	saveAll()
end)

local pillarHolder = Instance.new("Frame")
pillarHolder.BackgroundTransparency = 1
pillarHolder.Size = UDim2.new(1, 0, 0, 56)
pillarHolder.LayoutOrder = 3
pillarHolder.Parent = pillarBody
local pillarGrid = Instance.new("UIGridLayout", pillarHolder)
pillarGrid.CellSize = UDim2.new(0.25, -3, 0, 24)
pillarGrid.CellPadding = UDim2.new(0, 4, 0, 4)
pillarGrid.SortOrder = Enum.SortOrder.LayoutOrder

for i, r in ipairs(RARITY_ORDER) do
	local btn = Instance.new("TextButton")
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamMedium
	btn.Text = RARITIES[r].label
	btn.TextSize = 11
	btn.Parent = pillarHolder
	btn.LayoutOrder = i
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
	local function update()
		if pillarEnabled[r] then
			btn.BackgroundColor3 = RARITIES[r].color
			btn.TextColor3 = contrastText(RARITIES[r].color)
		else
			btn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
			btn.TextColor3 = Color3.fromRGB(110, 115, 130)
		end
	end
	update()
	btn.MouseButton1Click:Connect(function()
		pillarEnabled[r] = not pillarEnabled[r]
		update()
		if pillarActive then syncPillars() end
		saveAll()
	end)
end

pillarToggleBtn.MouseButton1Click:Connect(function()
	pillarActive = not pillarActive
	if pillarActive then
		pillarToggleBtn.Text = "显示光柱：开"
		pillarToggleBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
		syncPillars()
	else
		pillarToggleBtn.Text = "显示光柱：关"
		pillarToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 150)
		clearPillars()
	end
end)

-- 偷蛋筛选
local stealCard, stealBody = makeCard("偷蛋筛选")
local stealHolder = Instance.new("Frame")
stealHolder.BackgroundTransparency = 1
stealHolder.Size = UDim2.new(1, 0, 0, 56)
stealHolder.LayoutOrder = 1
stealHolder.Parent = stealBody
local stealGrid = Instance.new("UIGridLayout", stealHolder)
stealGrid.CellSize = UDim2.new(0.25, -3, 0, 24)
stealGrid.CellPadding = UDim2.new(0, 4, 0, 4)
stealGrid.SortOrder = Enum.SortOrder.LayoutOrder

for i, r in ipairs(RARITY_ORDER) do
	local btn = Instance.new("TextButton")
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamMedium
	btn.Text = RARITIES[r].label
	btn.TextSize = 11
	btn.Parent = stealHolder
	btn.LayoutOrder = i
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
	local function update()
		if stealEnabled[r] then
			btn.BackgroundColor3 = RARITIES[r].color
			btn.TextColor3 = contrastText(RARITIES[r].color)
		else
			btn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
			btn.TextColor3 = Color3.fromRGB(110, 115, 130)
		end
	end
	update()
	btn.MouseButton1Click:Connect(function()
		stealEnabled[r] = not stealEnabled[r]
		update()
		saveAll()
	end)
end

-- 安全区
local zoneCard, zoneBody = makeCard("安全区")

local zoneShapeRow = Instance.new("Frame")
zoneShapeRow.BackgroundTransparency = 1
zoneShapeRow.Size = UDim2.new(1, 0, 0, 26)
zoneShapeRow.LayoutOrder = 1
zoneShapeRow.Parent = zoneBody

local circleBtn = Instance.new("TextButton")
circleBtn.Size = UDim2.new(0.5, -3, 1, 0)
circleBtn.BorderSizePixel = 0
circleBtn.Font = Enum.Font.GothamMedium
circleBtn.Text = "圆形"
circleBtn.TextColor3 = Color3.new(1, 1, 1)
circleBtn.TextSize = 11
circleBtn.Parent = zoneShapeRow
Instance.new("UICorner", circleBtn).CornerRadius = UDim.new(0, 5)

local squareBtn = Instance.new("TextButton")
squareBtn.Position = UDim2.new(0.5, 3, 0, 0)
squareBtn.Size = UDim2.new(0.5, -3, 1, 0)
squareBtn.BorderSizePixel = 0
squareBtn.Font = Enum.Font.GothamMedium
squareBtn.Text = "方形"
squareBtn.TextColor3 = Color3.new(1, 1, 1)
squareBtn.TextSize = 11
squareBtn.Parent = zoneShapeRow
Instance.new("UICorner", squareBtn).CornerRadius = UDim.new(0, 5)

local function updateZoneUI()
	if zoneShape == "circle" then
		circleBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
		squareBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
	else
		circleBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
		squareBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
	end
end
updateZoneUI()

circleBtn.MouseButton1Click:Connect(function()
	zoneShape = "circle"
	updateZoneUI()
	saveAll()
end)
squareBtn.MouseButton1Click:Connect(function()
	zoneShape = "square"
	updateZoneUI()
	saveAll()
end)

local zoneSizeRow = Instance.new("Frame")
zoneSizeRow.BackgroundTransparency = 1
zoneSizeRow.Size = UDim2.new(1, 0, 0, 26)
zoneSizeRow.LayoutOrder = 2
zoneSizeRow.Parent = zoneBody

local zoneSizeLbl = Instance.new("TextLabel")
zoneSizeLbl.BackgroundTransparency = 1
zoneSizeLbl.Size = UDim2.new(0.5, 0, 1, 0)
zoneSizeLbl.Font = Enum.Font.Gotham
zoneSizeLbl.Text = "半径："
zoneSizeLbl.TextColor3 = Color3.fromRGB(180, 185, 200)
zoneSizeLbl.TextSize = 11
zoneSizeLbl.TextXAlignment = Enum.TextXAlignment.Left
zoneSizeLbl.Parent = zoneSizeRow

local zoneSizeBox = Instance.new("TextBox")
zoneSizeBox.Position = UDim2.new(0.5, 0, 0, 0)
zoneSizeBox.Size = UDim2.new(0.5, 0, 1, 0)
zoneSizeBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
zoneSizeBox.BorderSizePixel = 0
zoneSizeBox.Font = Enum.Font.Code
zoneSizeBox.Text = tostring(zoneSize)
zoneSizeBox.TextColor3 = Color3.fromRGB(200, 220, 240)
zoneSizeBox.TextSize = 12
zoneSizeBox.ClearTextOnFocus = false
zoneSizeBox.Parent = zoneSizeRow
Instance.new("UICorner", zoneSizeBox).CornerRadius = UDim.new(0, 5)
zoneSizeBox.FocusLost:Connect(function()
	local n = tonumber(zoneSizeBox.Text)
	if n and n > 0 then
		zoneSize = n
		saveAll()
	end
	zoneSizeBox.Text = tostring(zoneSize)
end)

-- 速度 + 紧急模式
local speedCard, speedBody = makeCard("速度 / 紧急模式")

local speedRow = Instance.new("Frame")
speedRow.BackgroundTransparency = 1
speedRow.Size = UDim2.new(1, 0, 0, 26)
speedRow.LayoutOrder = 1
speedRow.Parent = speedBody

local speedLbl = Instance.new("TextLabel")
speedLbl.BackgroundTransparency = 1
speedLbl.Size = UDim2.new(0.5, 0, 1, 0)
speedLbl.Font = Enum.Font.Gotham
speedLbl.Text = "传送速度："
speedLbl.TextColor3 = Color3.fromRGB(180, 185, 200)
speedLbl.TextSize = 11
speedLbl.TextXAlignment = Enum.TextXAlignment.Left
speedLbl.Parent = speedRow

local speedBox = Instance.new("TextBox")
speedBox.Position = UDim2.new(0.5, 0, 0, 0)
speedBox.Size = UDim2.new(0.5, 0, 1, 0)
speedBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
speedBox.BorderSizePixel = 0
speedBox.Font = Enum.Font.Code
speedBox.Text = tostring(TRANSPORT_SPEED)
speedBox.TextColor3 = Color3.fromRGB(200, 220, 240)
speedBox.TextSize = 12
speedBox.ClearTextOnFocus = false
speedBox.Parent = speedRow
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 5)
speedBox.FocusLost:Connect(function()
	local n = tonumber(speedBox.Text)
	if n and n > 5 then
		TRANSPORT_SPEED = n
		saveAll()
	end
	speedBox.Text = tostring(TRANSPORT_SPEED)
end)

local emergRow = Instance.new("Frame")
emergRow.BackgroundTransparency = 1
emergRow.Size = UDim2.new(1, 0, 0, 26)
emergRow.LayoutOrder = 2
emergRow.Parent = speedBody

local emergBtn = Instance.new("TextButton")
emergBtn.Size = UDim2.new(0.5, -3, 1, 0)
emergBtn.BorderSizePixel = 0
emergBtn.Font = Enum.Font.GothamMedium
emergBtn.TextColor3 = Color3.new(1, 1, 1)
emergBtn.TextSize = 11
emergBtn.Parent = emergRow
Instance.new("UICorner", emergBtn).CornerRadius = UDim.new(0, 5)

local emergBox = Instance.new("TextBox")
emergBox.Position = UDim2.new(0.5, 3, 0, 0)
emergBox.Size = UDim2.new(0.5, -3, 1, 0)
emergBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
emergBox.BorderSizePixel = 0
emergBox.Font = Enum.Font.Code
emergBox.Text = tostring(EMERGENCY_SPEED)
emergBox.TextColor3 = Color3.fromRGB(255, 200, 100)
emergBox.TextSize = 12
emergBox.ClearTextOnFocus = false
emergBox.Parent = emergRow
Instance.new("UICorner", emergBox).CornerRadius = UDim.new(0, 5)
emergBox.FocusLost:Connect(function()
	local n = tonumber(emergBox.Text)
	if n and n > 10 then
		EMERGENCY_SPEED = n
		saveAll()
	end
	emergBox.Text = tostring(EMERGENCY_SPEED)
end)

local function updateEmergUI()
	if EMERGENCY_ENABLED then
		emergBtn.Text = "紧急：开"
		emergBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
	else
		emergBtn.Text = "紧急：关"
		emergBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
	end
end
updateEmergUI()
emergBtn.MouseButton1Click:Connect(function()
	EMERGENCY_ENABLED = not EMERGENCY_ENABLED
	updateEmergUI()
	saveAll()
end)

-- ★ V19：紧急稀有度阈值
local emergThreshLbl = Instance.new("TextLabel")
emergThreshLbl.BackgroundTransparency = 1
emergThreshLbl.Size = UDim2.new(1, 0, 0, 14)
emergThreshLbl.Font = Enum.Font.Gotham
emergThreshLbl.Text = "紧急速度起始稀有度："
emergThreshLbl.TextColor3 = Color3.fromRGB(180, 185, 200)
emergThreshLbl.TextSize = 11
emergThreshLbl.TextXAlignment = Enum.TextXAlignment.Left
emergThreshLbl.LayoutOrder = 3
emergThreshLbl.Parent = speedBody

local emergThreshHolder = Instance.new("Frame")
emergThreshHolder.BackgroundTransparency = 1
emergThreshHolder.Size = UDim2.new(1, 0, 0, 56)
emergThreshHolder.LayoutOrder = 4
emergThreshHolder.Parent = speedBody
local emergThreshGrid = Instance.new("UIGridLayout", emergThreshHolder)
emergThreshGrid.CellSize = UDim2.new(0.25, -3, 0, 24)
emergThreshGrid.CellPadding = UDim2.new(0, 4, 0, 4)
emergThreshGrid.SortOrder = Enum.SortOrder.LayoutOrder

local emergThreshBtns = {}
for i, r in ipairs(RARITY_ORDER) do
	local btn = Instance.new("TextButton")
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamMedium
	btn.Text = RARITIES[r].label
	btn.TextSize = 11
	btn.Parent = emergThreshHolder
	btn.LayoutOrder = i
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
	emergThreshBtns[r] = btn
	local function update()
		if emergencyRarityMin == r then
			btn.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
			btn.TextColor3 = Color3.fromRGB(180, 185, 200)
		end
	end
	update()
	btn.MouseButton1Click:Connect(function()
		emergencyRarityMin = r
		for k, b in pairs(emergThreshBtns) do
			if k == r then
				b.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
				b.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				b.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
				b.TextColor3 = Color3.fromRGB(180, 185, 200)
			end
		end
		saveAll()
	end)
end

-- 树木
local treeCard, treeBody = makeCard("树木处理")

local treeRow = Instance.new("Frame")
treeRow.BackgroundTransparency = 1
treeRow.Size = UDim2.new(1, 0, 0, 26)
treeRow.LayoutOrder = 1
treeRow.Parent = treeBody

local TREE_MODES = {
	{ key = "off", label = "关", color = Color3.fromRGB(80, 80, 90) },
	{ key = "hide", label = "隐藏", color = Color3.fromRGB(60, 100, 180) },
	{ key = "delete", label = "删除", color = Color3.fromRGB(180, 50, 50) },
}
local treeBtns = {}
local deleteArmed = false
local function updateTreeBtn()
	for k, b in pairs(treeBtns) do
		local color = Color3.fromRGB(42, 45, 54)
		if treeMode == k then
			for _, m in ipairs(TREE_MODES) do
				if m.key == k then
					color = m.color
					break
				end
			end
		end
		b.BackgroundColor3 = color
		b.TextColor3 = (treeMode == k) and Color3.new(1,1,1) or Color3.fromRGB(180,185,200)
	end
end
for i, m in ipairs(TREE_MODES) do
	local b = Instance.new("TextButton")
	b.Position = UDim2.new((i-1)/3, (i-1)*2, 0, 0)
	b.Size = UDim2.new(1/3, -3, 1, 0)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamMedium
	b.Text = m.label
	b.TextSize = 11
	b.Parent = treeRow
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
	treeBtns[m.key] = b
	b.MouseButton1Click:Connect(function()
		if m.key == "delete" and not deleteArmed then
			deleteArmed = true
			b.Text = "确认？"
			b.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
			task.delay(2, function()
				if deleteArmed then
					deleteArmed = false
					b.Text = "删除"
					updateTreeBtn()
				end
			end)
			return
		end
		deleteArmed = false
		if treeMode == "hide" then
			restoreAllTrees()
		end
		treeMode = m.key
		b.Text = m.label
		updateTreeBtn()
		task.defer(applyTreeMode)
		saveAll()
	end)
end
updateTreeBtn()

--=====================================================
-- 拖动 + 持久化
--=====================================================
isDragging = false
do
	local dragStart, startPos
	local function begin(input)
		isDragging = true
		dragStart = Vector2.new(input.Position.X, input.Position.Y)
		startPos = panel.Position
	end
	local function update(input)
		if not isDragging then return end
		local cur = Vector2.new(input.Position.X, input.Position.Y)
		local delta = cur - dragStart
		panel.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
	local function finish()
		if not isDragging then return end
		isDragging = false
		-- ★ V19：保存拖拽后的绝对位置
		local absPos = panel.AbsolutePosition
		customPanelX = math.floor(absPos.X)
		customPanelY = math.floor(absPos.Y)
		panelPos = "custom"
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = UDim2.fromOffset(customPanelX, customPanelY)
		saveAll()
	end
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			begin(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
			update(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			finish()
		end
	end)
end

-- 最小化
local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	content.Visible = not minimized
	panel.Size = UDim2.fromOffset(PANEL_W, minimized and 40 or PANEL_H)
	minBtn.Text = minimized and "+" or "−"
end)

--=====================================================
-- 统计循环
--=====================================================
task.spawn(function()
	while true do
		local pillars = 0
		for _ in pairs(modelToPillar) do
			pillars += 1
		end
		local eggs = collectEggs()
		statsLbl.Text = ("光柱 %d / 蛋 %d"):format(pillars, #eggs)
		autoStatusLbl.Text = autoStatus
		task.wait(0.5)
	end
end)

print("[EggMaster V19] 加载完成")
