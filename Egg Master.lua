--!nonstrict
--[[
	Egg 全能脚本 V17
	放置位置：StarterPlayer > StarterPlayerScripts（LocalScript）

	V17 关键修复：
	  · 传送目标 = 蛋包围盒底部 + 3（不再用 pivot 位置，因为 pivot 常在蛋顶）
	  · UI 顶部实时显示当前生效的偷蛋筛选列表
	  · 悬浮文字全部 AlwaysOnTop
	  · 标题栏锚点左上，最小化不窜位
	  · 相机穿墙只做 Popper 回滚，不改 CameraType
]]

--=====================================================
-- 服务
--=====================================================
local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local TweenService         = game:GetService("TweenService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local HttpService          = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--=====================================================
-- 配置持久化
--=====================================================
local CONFIG_FILE = "EggMasterConfig.json"
local CONFIG_ATTR = "EggMasterConfig"
local canWriteFile = (typeof(writefile) == "function"
	and typeof(readfile) == "function"
	and typeof(isfile) == "function")

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
	local attr = player:GetAttribute(CONFIG_ATTR)
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
	pcall(function() player:SetAttribute(CONFIG_ATTR, content) end)
end

--=====================================================
-- 静态配置
--=====================================================
local KEYWORDS = { "egg", "蛋" }
local SKIP_ROOTS = { "Plots" }
local PILLAR_NAME = "EggPillar"
local PILLAR_GAP = 5

local TRANSPARENCY_MAX = 0.5
local IGNORE_PART_NAMES = {
	["handle"] = true, ["eggbase"] = true, ["mutationhitbox"] = true,
}
local FAKE_EGG_KEYWORDS = { "tracker", "npc", "dummy", "player", "character", "fake" }

local HOLD_DURATION = 1.0
local OBSERVE_TIME = 0.7
local MAX_ATTEMPTS = 3
local ARRIVE_DISTANCE = 12
local GO_HOME_TIMEOUT = 8.0
local HOME_SAFE_RADIUS = 150

local REMOTE_WAIT = 0.4
local MOVE_MOVED_THRESH = 10
local NO_PROGRESS_TIMEOUT = 2.0
local PROGRESS_THRESHOLD = 5

local TREE_KEYWORDS = { "tree", "树", "bush", "leaf", "branch", "log", "trunk" }
local TREE_SKIP = { "terrain" }

local PILLAR_REFRESH_INTERVAL = 0.7
local PILLAR_MOVE_EPS = 30

local TRANSPORT_SPEED = 2000
local EMERGENCY_SPEED = 10000
local EMERGENCY_THRESH = 1e11
local EMERGENCY_ENABLED = false
local AUTO_ACCEL_THRESH = 1e9

local homeCoords = {}
local treeMode = "off"
local autoRecordCoord = true
local plotCoord = nil

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
	if type(savedConfig.autoAccelEnabled) == "boolean" then
		AUTO_ACCEL_THRESH = savedConfig.autoAccelEnabled and 1e9 or math.huge
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
	if type(savedConfig.homeCoords) == "table" then
		for _, c in ipairs(savedConfig.homeCoords) do
			if type(c) == "table" and type(c.X) == "number" then
				homeCoords[#homeCoords + 1] = {
					pos = Vector3.new(c.X, c.Y, c.Z),
					note = type(c.note) == "string" and c.note or "",
				}
			end
		end
	end
	if #homeCoords == 0 and type(savedConfig.plotCoord) == "table"
		and type(savedConfig.plotCoord.X) == "number" then
		homeCoords[1] = {
			pos = Vector3.new(
				savedConfig.plotCoord.X,
				savedConfig.plotCoord.Y,
				savedConfig.plotCoord.Z),
			note = "默认",
		}
	end
	if type(savedConfig.treeMode) == "string" then treeMode = savedConfig.treeMode end
	if type(savedConfig.autoRecordCoord) == "boolean" then
		autoRecordCoord = savedConfig.autoRecordCoord
	end
end

local function refreshPlotCoord()
	plotCoord = #homeCoords > 0 and homeCoords[1].pos or nil
end
refreshPlotCoord()

local function saveAll()
	local data = {
		transportSpeed = TRANSPORT_SPEED,
		emergencySpeed = EMERGENCY_SPEED,
		emergencyEnabled = EMERGENCY_ENABLED,
		autoAccelEnabled = (AUTO_ACCEL_THRESH < math.huge),
		pillarEnabled = pillarEnabled,
		stealEnabled = stealEnabled,
		treeMode = treeMode,
		autoRecordCoord = autoRecordCoord,
		homeCoords = {},
	}
	for i, c in ipairs(homeCoords) do
		data.homeCoords[i] = { X = c.pos.X, Y = c.pos.Y, Z = c.pos.Z, note = c.note }
	end
	saveConfigTable(data)
end

--=====================================================
-- 稀有度
--=====================================================
local RARITIES = {
	Common = {
		color = Color3.fromRGB(220,220,220),
		height =  150, thick = 4, flash = false, cycle = false, speed = 0,
		label = "普通",
		labelScale = 0.85, displayOrder = 100,
		showLabel = false,
	},
	Rare = {
		color = Color3.fromRGB( 80,180,255),
		height =  300, thick = 5, flash = false, cycle = false, speed = 0,
		label = "稀有",
		labelScale = 1.00, displayOrder = 110,
		showLabel = true,
	},
	Epic = {
		color = Color3.fromRGB(180, 80,255),
		height =  550, thick = 6, flash = false, cycle = false, speed = 0,
		label = "史诗",
		labelScale = 1.15, displayOrder = 120,
		showLabel = true,
	},
	Legendary = {
		color = Color3.fromRGB(255,200, 60),
		height =  900, thick = 7, flash = true, cycle = false, speed = 2,
		label = "传奇",
		labelScale = 1.35, displayOrder = 130,
		showLabel = true,
	},
	Mythic = {
		color = Color3.fromRGB(255, 80,200),
		height = 1500, thick = 8, flash = true, cycle = true,  speed = 3,
		label = "神话",
		labelScale = 1.60, displayOrder = 140,
		showLabel = true,
	},
	God = {
		color = Color3.fromRGB(255, 60, 60),
		height = 2300, thick = 10, flash = true, cycle = true, speed = 4,
		label = "神",
		labelScale = 1.90, displayOrder = 150,
		showLabel = true,
	},
	Beyond = {
		color = Color3.fromRGB(  0,255,255),
		height = 3500, thick = 12, flash = true, cycle = true, speed = 6,
		label = "超越",
		labelScale = 2.30, displayOrder = 160,
		showLabel = true,
	},
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

local KNOWN_VALUES = {
	["White Egg"]     = 1,
	["Brown Egg"]     = 5,
	["Cracked Egg"]   = 30,
	["Easter Egg"]    = 50,
	["Stone Egg"]     = 100,
	["Leaf Egg"]      = 200,
	["Flower Egg"]    = 750,
	["Slime Egg"]     = 1e3,
	["Ice Egg"]       = 3e3,
	["Glass Egg"]     = 1e4,
	["Golden Egg"]    = 3e4,
	["Crystal Egg"]   = 150e3,
	["Skull Egg"]     = 250e3,
	["Dominus Egg"]   = 700e3,
	["Sinister Egg"]  = 800e3,
	["Flaming Egg"]   = 1e6,
	["Soul Egg"]      = 7e6,
	["Tidal Egg"]     = 8e6,
	["Aurora Egg"]    = 300e6,
	["Galaxy Egg"]    = 1.5e9,
	["Blackhole Egg"] = 1.5e9,
	["Bloom Egg"]     = 2e9,
	["Solaris Egg"]   = 300e9,
	["Cherub Egg"]    = 1e12,
}

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

local function parseValue(text)
	text = text:gsub("%s", ""):gsub(",", "")
	local num, suffix = text:match("^([%d%.]+)([KkMmBbTt]?)")
	if not num then return nil end
	local n = tonumber(num)
	if not n then return nil end
	local mult = 1
	local s = string.upper(suffix)
	if s == "K" then mult = 1e3
	elseif s == "M" then mult = 1e6
	elseif s == "B" then mult = 1e9
	elseif s == "T" then mult = 1e12 end
	return n * mult
end

local function formatValue(v)
	if v >= 1e12 then return string.format("%.2fT", v / 1e12) end
	if v >= 1e9  then return string.format("%.2fB", v / 1e9)  end
	if v >= 1e6  then return string.format("%.2fM", v / 1e6)  end
	if v >= 1e3  then return string.format("%.1fK", v / 1e3)  end
	return tostring(math.floor(v))
end

--=====================================================
-- 清理旧物
--=====================================================
for _, gui in ipairs(playerGui:GetChildren()) do
	if gui.Name == "EggMasterUI" then gui:Destroy() end
end

do
	local oldPM = workspace:FindFirstChild("EggMasterPillars")
	if oldPM then pcall(function() oldPM:Destroy() end) end
	for _, v in ipairs(workspace:GetChildren()) do
		if v.Name == PILLAR_NAME and v:IsA("BasePart") then v:Destroy() end
	end
end

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

local function underSkipRoot(inst)
	local p = inst.Parent
	while p and p ~= workspace do
		for _, s in ipairs(SKIP_ROOTS) do
			if p.Name == s then return true end
		end
		p = p.Parent
	end
	return false
end

local function isFakeEgg(model)
	if model:FindFirstChildOfClass("Humanoid") then return true end
	if nameHas(model.Name, FAKE_EGG_KEYWORDS) then return true end
	return false
end

local function isEggModel(inst)
	if not inst:IsA("Model") then return false end
	if inst.Name == PILLAR_NAME then return false end
	if not nameHas(inst.Name, KEYWORDS) then return false end
	if isFakeEgg(inst) then return false end
	return true
end

local function hasEggAncestor(inst)
	local p = inst.Parent
	while p and p ~= workspace do
		if isEggModel(p) then return true end
		p = p.Parent
	end
	return false
end

local function isVisiblePart(p)
	if p.Transparency > TRANSPARENCY_MAX then return false end
	if p.LocalTransparencyModifier > TRANSPARENCY_MAX then return false end
	return true
end

local function pickPivot(model)
	local best, pivot = -1, nil
	local fallback = nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsA("Terrain") then
			if not fallback then fallback = d end
			local n = string.lower(d.Name)
			if not IGNORE_PART_NAMES[n] and isVisiblePart(d) then
				local score = 0
				if d:IsA("MeshPart") then score += 10000 end
				local mag = d.Size.Magnitude
				if mag < 200 then score += mag end
				if score > best then best, pivot = score, d end
			end
		end
	end
	return pivot or fallback
end

local function getEggId(model)
	local a = model:GetAttribute("EggInventoryId")
	if typeof(a) == "string" then return a end
	for _, d in ipairs(model:GetDescendants()) do
		local v = d:GetAttribute("EggInventoryId")
		if typeof(v) == "string" then return v end
	end
	return nil
end

local function readValueText(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local v = parseValue(d.Text)
			if v then return v end
		end
	end
	return nil
end

local function evalEggValue(model)
	local known = lookupKnown(model.Name)
	local text = readValueText(model)
	if known and text then return math.max(known, text) end
	return known or text or 1e12
end

local function collectEggs()
	local list = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if isEggModel(d) and not hasEggAncestor(d) and not underSkipRoot(d) then
			local pivot = pickPivot(d)
			if pivot then
				local value = evalEggValue(d)
				list[#list + 1] = {
					model = d, pivot = pivot,
					value = value,
					rarity = classifyValue(value),
					id = getEggId(d),
				}
			end
		end
	end
	return list
end

--=====================================================
-- ★ V17：蛋的交互点 = 包围盒底部 + 3 studs
--     （pivot 常在蛋顶装饰上，用它传送会飞到光柱高度）
--=====================================================
local function getEggInteractPoint(egg)
	local ok, cf, size = pcall(function()
		local c, s = egg.model:GetBoundingBox()
		return c, s
	end)
	if ok and cf and size then
		local bottomY = cf.Position.Y - size.Y * 0.5
		return Vector3.new(cf.Position.X, bottomY + 3, cf.Position.Z)
	end
	if egg.pivot then
		return egg.pivot.Position
	end
	return nil
end

--=====================================================
-- 光柱
--=====================================================
local pillarModel = Instance.new("Model")
pillarModel.Name = "EggMasterPillars"
pcall(function()
	pillarModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end)
pcall(function() pillarModel.Archivable = false end)
pillarModel.Parent = workspace

local modelToPillar = {}
local pillarMeta    = {}
local flashEntries  = {}
local pillarActive  = false
local ignoredEggs = setmetatable({}, { __mode = "k" })

local function createPillar(egg)
	if modelToPillar[egg.model] then return end
	if ignoredEggs[egg.model] then return end
	if not egg.model.Parent then return end
	if not egg.pivot.Parent then return end

	local rule = RARITIES[egg.rarity]

	local cf, bboxSize
	local ok = pcall(function()
		cf, bboxSize = egg.model:GetBoundingBox()
	end)
	if not ok or not cf or not bboxSize then
		cf = CFrame.new(egg.pivot.Position)
		bboxSize = egg.pivot.Size
	end

	local centerX = cf.Position.X
	local centerZ = cf.Position.Z
	local topY    = cf.Position.Y + bboxSize.Y * 0.5
	local baseY   = topY + PILLAR_GAP
	local centerY = baseY + rule.height * 0.5
	local pos     = Vector3.new(centerX, centerY, centerZ)

	local pillar = Instance.new("Part")
	pillar.Name         = PILLAR_NAME
	pillar.Anchored     = true
	pillar.CanCollide   = false
	pillar.CanTouch     = false
	pillar.CanQuery     = false
	pillar.CastShadow   = false
	pillar.Locked       = true
	pillar.Massless     = true
	pillar.Material     = Enum.Material.Neon
	pillar.Color        = rule.color
	pillar.Transparency = 0.05
	pillar.Size         = Vector3.new(rule.thick, rule.height, rule.thick)
	pillar.CFrame       = CFrame.new(pos)
	pillar.Parent       = pillarModel

	local light = Instance.new("PointLight")
	light.Color      = rule.color
	light.Brightness = 4 + math.min(rule.height / 300, 4)
	light.Range      = 40 + math.min(rule.height / 20, 40)
	light.Shadows    = false
	light.Parent     = pillar

	local hl = Instance.new("Highlight")
	hl.Name                = "PillarPerspective"
	hl.DepthMode           = rule.showLabel
		and Enum.HighlightDepthMode.AlwaysOnTop
		or Enum.HighlightDepthMode.Occluded
	hl.FillColor           = rule.color
	hl.FillTransparency    = 0.7
	hl.OutlineColor        = rule.color
	hl.OutlineTransparency = 0
	hl.Adornee             = pillar
	hl.Parent              = pillar

	if rule.showLabel then
		local bbSizeX = math.floor(220 * rule.labelScale)
		local bbSizeY = math.floor(80  * rule.labelScale)

		local billboard = Instance.new("BillboardGui")
		billboard.Name           = "PillarLabel"
		billboard.Size           = UDim2.fromOffset(bbSizeX, bbSizeY)
		billboard.AlwaysOnTop    = true
		billboard.LightInfluence = 0
		billboard.MaxDistance    = 100000
		billboard.DisplayOrder   = rule.displayOrder
		billboard.Adornee        = pillar
		billboard.StudsOffsetWorldSpace = Vector3.new(0, rule.height * 0.5 + 5, 0)
		billboard.Parent         = pillar

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "NameLabel"
		nameLbl.BackgroundTransparency = 1
		nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.Text = egg.model.Name
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextStrokeTransparency = 0
		nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLbl.TextScaled = true
		nameLbl.Parent = billboard

		local valLbl = Instance.new("TextLabel")
		valLbl.Name = "ValueLabel"
		valLbl.BackgroundTransparency = 1
		valLbl.Position = UDim2.new(0, 0, 0.55, 0)
		valLbl.Size = UDim2.new(1, 0, 0.45, 0)
		valLbl.Font = Enum.Font.GothamBold
		valLbl.Text = formatValue(egg.value)
		valLbl.TextColor3 = rule.color
		valLbl.TextStrokeTransparency = 0
		valLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		valLbl.TextScaled = true
		valLbl.Parent = billboard
	end

	modelToPillar[egg.model] = pillar
	pillarMeta[pillar] = {
		model = egg.model,
		pivot = egg.pivot,
		originPos = egg.pivot.Position,
	}

	if rule.flash then
		flashEntries[pillar] = { rarity = egg.rarity, phase = math.random() * 10 }
	end
end

local function removePillar(model)
	local p = modelToPillar[model]
	if p then
		flashEntries[p] = nil
		pillarMeta[p] = nil
		pcall(function() p:Destroy() end)
		modelToPillar[model] = nil
	end
end

local function clearPillars()
	for m in pairs(modelToPillar) do removePillar(m) end
	table.clear(modelToPillar)
	table.clear(pillarMeta)
	table.clear(flashEntries)
	if pillarModel then
		for _, v in ipairs(pillarModel:GetChildren()) do
			pcall(function() v:Destroy() end)
		end
	end
	for _, v in ipairs(workspace:GetChildren()) do
		if v.Name == PILLAR_NAME and v:IsA("BasePart") then v:Destroy() end
	end
end

local function syncPillars()
	for m in pairs(modelToPillar) do
		if not m.Parent or not isEggModel(m) or underSkipRoot(m) then
			removePillar(m)
		end
	end

	for pillar, meta in pairs(pillarMeta) do
		if not pillar.Parent then
			pillarMeta[pillar] = nil
		else
			local m = meta.model
			local pivot = meta.pivot
			if not m.Parent or not pivot or not pivot.Parent then
				removePillar(m)
			else
				local curPos = pivot.Position
				if (curPos - meta.originPos).Magnitude > PILLAR_MOVE_EPS then
					ignoredEggs[m] = true
					removePillar(m)
				end
			end
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
				local bb = pillar:FindFirstChild("PillarLabel")
				if bb then
					local valLbl = bb:FindFirstChild("ValueLabel")
					if valLbl then valLbl.TextColor3 = c end
				end
			end
		end
		task.wait(0.03)
	end
end)

--=====================================================
-- 树木
--=====================================================
local treeHidden = {}

local TREE_HIDE_RULES = {
	{ Class = "BasePart", Props = {
		Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CanClimb = false,
	} },
	{ Class = "Decal",           Props = { Transparency = 1 } },
	{ Class = "Texture",         Props = { Transparency = 1 } },
	{ Class = "ParticleEmitter", Props = { Enabled = false } },
	{ Class = "Beam",            Props = { Enabled = false } },
	{ Class = "Trail",           Props = { Enabled = false } },
	{ Class = "Light",           Props = { Enabled = false } },
	{ Class = "BillboardGui",    Props = { Enabled = false } },
	{ Class = "SurfaceGui",      Props = { Enabled = false } },
	{ Class = "Sound",           Props = { Playing = false } },
}

local function isTreeInstance(inst)
	if not nameHas(inst.Name, TREE_KEYWORDS) then return false end
	if nameHas(inst.Name, TREE_SKIP) then return false end
	if player.Character and inst:IsDescendantOf(player.Character) then return false end
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

local function collectTreeTargets()
	local list = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if isTreeInstance(d) and not hasTreeAncestor(d) then
			list[#list + 1] = d
		end
	end
	return list
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
	for _, d in ipairs(root:GetDescendants()) do tryHide(d) end
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
	for _, t in ipairs(collectTreeTargets()) do
		if treeMode == "hide" then
			hideOneTree(t)
		elseif treeMode == "delete" then
			treeHidden[t] = nil
			pcall(function() t:Destroy() end)
		end
	end
end

local function restoreAllTrees()
	local keys = {}
	for k in pairs(treeHidden) do keys[#keys + 1] = k end
	for _, k in ipairs(keys) do restoreOneTree(k) end
	table.clear(treeHidden)
end

workspace.DescendantAdded:Connect(function(d)
	if treeMode == "off" then return end
	if isTreeInstance(d) and not hasTreeAncestor(d) then
		task.defer(function()
			if treeMode == "hide" then
				hideOneTree(d)
			elseif treeMode == "delete" then
				pcall(function() d:Destroy() end)
			end
		end)
	end
end)

if treeMode ~= "off" then
	task.defer(function()
		task.wait(1)
		applyTreeMode()
	end)
end

--=====================================================
-- Remote
--=====================================================
local eggPickupRemote = nil
do
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local gameF = remotes and remotes:FindFirstChild("Game")
	local pickup = gameF and gameF:FindFirstChild("EggPickup")
	if pickup and pickup:IsA("RemoteEvent") then
		eggPickupRemote = pickup
	end
end

local remoteCooldown = {}
local REMOTE_COOLDOWN = 0.5

local function firePickupRemote(egg)
	if not egg.id or not eggPickupRemote then return false end
	local now = tick()
	local last = remoteCooldown[egg.id]
	if last and now - last < REMOTE_COOLDOWN then return false end
	remoteCooldown[egg.id] = now
	local ok = pcall(function() eggPickupRemote:FireServer(egg.id) end)
	return ok
end

task.spawn(function()
	while true do
		task.wait(30)
		local now = tick()
		for id, t in pairs(remoteCooldown) do
			if now - t > 60 then remoteCooldown[id] = nil end
		end
	end
end)

--=====================================================
-- 自动农场核心
--=====================================================
local autoActive = false
local autoStatus = "空闲"
local landedAtHome = false

RunService.Stepped:Connect(function(_, _)
	if not autoActive then return end
	if landedAtHome then return end
	local char = player.Character
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

-- 相机穿墙：只做 Popper 突降回滚，不改 CameraType
local camLastOffset = nil
RunService:BindToRenderStep("EggMasterCamNoClip",
	Enum.RenderPriority.Camera.Value + 1,
	function()
		if not autoActive then
			camLastOffset = nil
			return
		end
		local cam = workspace.CurrentCamera
		if not cam then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local offset = cam.CFrame.Position - hrp.Position
		local dist = offset.Magnitude

		if not camLastOffset then
			camLastOffset = offset
			return
		end

		local lastDist = camLastOffset.Magnitude
		if lastDist - dist > 5 then
			local rot = cam.CFrame - cam.CFrame.Position
			cam.CFrame = CFrame.new(hrp.Position + camLastOffset) * rot
		else
			camLastOffset = offset
		end
	end)

local lastSetPos = nil
local moveTarget = nil
local moveSpeed = TRANSPORT_SPEED
local holdPos = nil

local function setMoveTarget(pos, speed)
	if pos then
		moveTarget = pos
		moveSpeed = speed or TRANSPORT_SPEED
	else
		moveTarget = nil
	end
	lastSetPos = nil
end

RunService.Heartbeat:Connect(function(dt)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if autoActive and not landedAtHome then
		if not moveTarget and not holdPos then
			holdPos = hrp.Position
		end
	end

	local target = moveTarget or ((not landedAtHome) and holdPos or nil)
	if not target then
		lastSetPos = nil
		return
	end

	local cur = hrp.Position

	if lastSetPos then
		local discrepancy = (cur - lastSetPos).Magnitude
		if discrepancy > 50 then
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

	local speed = moveTarget and moveSpeed or TRANSPORT_SPEED
	local step = math.min(dist, speed * dt)
	local newPos = cur + diff.Unit * step
	char:PivotTo(CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position))
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	lastSetPos = newPos
end)

local function applyCharState(fly)
	local char = player.Character
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

local function eggStillExists(egg)
	return egg.model.Parent ~= nil and egg.pivot.Parent ~= nil
end

local function travelTo(targetPos, speed, timeout, stillValid)
	local t0 = tick()
	local lastProgressTime = t0
	local lastDist = math.huge

	if autoActive and landedAtHome then
		landedAtHome = false
	end
	if autoActive then
		applyCharState(true)
	end
	holdPos = nil
	setMoveTarget(targetPos, speed)

	local function freezeHold()
		if not autoActive then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		holdPos = hrp and hrp.Position or nil
	end

	while tick() - t0 < timeout do
		if stillValid and not stillValid() then
			setMoveTarget(nil)
			freezeHold()
			return "gone"
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local dist = (hrp.Position - targetPos).Magnitude
			if dist < ARRIVE_DISTANCE then
				setMoveTarget(nil)
				freezeHold()
				return "arrived"
			end

			if dist < lastDist - PROGRESS_THRESHOLD then
				lastDist = dist
				lastProgressTime = tick()
			end

			if tick() - lastProgressTime > NO_PROGRESS_TIMEOUT then
				char:PivotTo(CFrame.new(targetPos) * (hrp.CFrame - hrp.CFrame.Position))
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				lastProgressTime = tick()
				lastDist = math.huge
			end
		end
		task.wait(0.04)
	end
	setMoveTarget(nil)
	freezeHold()
	return "timeout"
end

local function observeEgg(egg, originalPos)
	local t0 = tick()
	while tick() - t0 < OBSERVE_TIME do
		if not eggStillExists(egg) then return "gone" end
		if (egg.pivot.Position - originalPos).Magnitude > MOVE_MOVED_THRESH then
			return "moved"
		end
		task.wait(0.1)
	end
	return "unchanged"
end

-- ★ V17：使用 getEggInteractPoint 定位到蛋底
local function stealEggFully(egg, speed)
	if not eggStillExists(egg) then return "success" end

	if plotCoord and (egg.pivot.Position - plotCoord).Magnitude < HOME_SAFE_RADIUS then
		return "tooCloseToHome"
	end

	firePickupRemote(egg)
	task.wait(REMOTE_WAIT)
	if not eggStillExists(egg) then return "success" end

	local originalPos = egg.pivot.Position

	local function findPrompt()
		if not egg.model.Parent then return nil end
		for _, d in ipairs(egg.model:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled then
				return d
			end
		end
		return nil
	end

	for attempt = 1, MAX_ATTEMPTS do
		if not eggStillExists(egg) then return "success" end
		if attempt > 1 then task.wait(0.1) end

		-- ★ 关键：用包围盒底部定位，不用 pivot
		local targetPos = getEggInteractPoint(egg)
		if not targetPos then return "failed" end

		local travelResult = travelTo(targetPos, speed, 6,
			function() return eggStillExists(egg) end)
		if travelResult == "gone" then return "success" end

		task.wait(0.25)
		if not eggStillExists(egg) then return "success" end

		firePickupRemote(egg)

		local prompt = findPrompt()
		local releaseFn = nil
		local holdDuration = HOLD_DURATION
		if prompt and prompt.Parent then
			local ok, hd = pcall(function() return prompt.HoldDuration end)
			if ok and type(hd) == "number" and hd > 0 then
				holdDuration = math.max(hd, 0.3)
			end
			pcall(function() prompt:InputHoldBegin() end)
			releaseFn = function()
				pcall(function() prompt:InputHoldEnd() end)
			end
		end

		pcall(function()
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
		end)

		local holdEnd = tick() + holdDuration + 0.15
		while tick() < holdEnd do
			if not eggStillExists(egg) then
				if releaseFn then releaseFn() end
				pcall(function()
					VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
				end)
				return "success"
			end
			task.wait(0.05)
		end

		if releaseFn then releaseFn() end
		pcall(function()
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
		end)

		task.wait(0.15)
		if not eggStillExists(egg) then return "success" end

		firePickupRemote(egg)
		task.wait(0.3)
		if not eggStillExists(egg) then return "success" end

		local result = observeEgg(egg, originalPos)
		if result == "gone" then return "success" end
		if result == "moved" then return "moved" end
	end

	return "failed"
end

local function goHomeFully()
	if #homeCoords == 0 then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then holdPos = hrp.Position end
		return false
	end

	for i, coord in ipairs(homeCoords) do
		local targetPos = coord.pos + Vector3.new(0, 4, 0)
		autoStatus = string.format("回家 #%d/%d %s",
			i, #homeCoords,
			coord.note ~= "" and ("(" .. coord.note .. ")") or "")
		local result = travelTo(targetPos, EMERGENCY_SPEED, GO_HOME_TIMEOUT)
		if result == "arrived" then
			holdPos = nil
			landedAtHome = true
			applyCharState(false)
			autoStatus = string.format("已到家 #%d%s",
				i,
				coord.note ~= "" and (" [" .. coord.note .. "]") or "")
			return true
		end
		task.wait(0.15)
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then holdPos = hrp.Position end
	landedAtHome = false
	autoStatus = "⚠ 所有回家坐标均失败，原地悬停"
	return false
end

local function speedForEgg(egg)
	if EMERGENCY_ENABLED and egg.value >= EMERGENCY_THRESH then
		return EMERGENCY_SPEED
	end
	if egg.value >= AUTO_ACCEL_THRESH then
		return math.max(TRANSPORT_SPEED, EMERGENCY_SPEED)
	end
	return TRANSPORT_SPEED
end

-- 计算当前生效的偷蛋稀有度列表（供 UI 显示）
local function getActiveStealList()
	local list = {}
	for _, r in ipairs(RARITY_ORDER) do
		if stealEnabled[r] then
			list[#list + 1] = RARITIES[r].label
		end
	end
	return list
end

local function startAuto()
	if autoActive then return end
	if #homeCoords == 0 then
		autoStatus = "⚠ 请先添加至少一个回家坐标"
		return
	end
	autoActive = true
	applyCharState(true)

	task.spawn(function()
		while autoActive do
			-- ★ V17：严格按 stealEnabled 过滤
			local eggs = collectEggs()
			local filtered = {}
			for _, e in ipairs(eggs) do
				if stealEnabled[e.rarity] == true then
					filtered[#filtered + 1] = e
				end
			end
			table.sort(filtered, function(a, b) return a.value > b.value end)

			if #filtered == 0 then
				if landedAtHome then
					landedAtHome = false
					applyCharState(true)
				end
				setMoveTarget(nil)
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then holdPos = hrp.Position end
				autoStatus = "无目标，悬浮等待中..."
				task.wait(0.8)
			else
				holdPos = nil
				landedAtHome = false
				applyCharState(true)
				for i, egg in ipairs(filtered) do
					if not eggStillExists(egg) then continue end

					local targetSpeed = speedForEgg(egg)
					local isEmergency = targetSpeed == EMERGENCY_SPEED
					autoStatus = string.format(
						"[%d/%d] %s (%s) %.0f%s",
						i, #filtered, egg.model.Name, egg.rarity,
						targetSpeed, isEmergency and " ⚡" or "")

					local result = stealEggFully(egg, targetSpeed)

					if result == "success" then
						autoStatus = string.format("[%d/%d] %s → 成功",
							i, #filtered, egg.model.Name)
						goHomeFully()
					elseif result == "moved" then
						autoStatus = string.format("[%d/%d] %s → 被别人抢先",
							i, #filtered, egg.model.Name)
						goHomeFully()
					elseif result == "tooCloseToHome" then
						autoStatus = string.format("[%d/%d] %s → 家附近，跳过",
							i, #filtered, egg.model.Name)
						task.wait(0.15)
					else
						autoStatus = string.format("[%d/%d] %s → 未拿到，回家重试",
							i, #filtered, egg.model.Name)
						goHomeFully()
					end

					if not autoActive then break end
				end
			end
		end

		setMoveTarget(nil)
		holdPos = nil
		landedAtHome = false
		applyCharState(false)
		autoStatus = "空闲"
	end)
end

local function stopAuto()
	autoActive = false
end

local function cleanupAll()
	pcall(stopAuto)
	pcall(applyCharState, false)
	pcall(clearPillars)
	pcall(restoreAllTrees)
	if pillarModel then
		pcall(function() pillarModel:Destroy() end)
	end
	pcall(function()
		RunService:UnbindFromRenderStep("EggMasterCamNoClip")
	end)
end

pcall(function()
	if script then
		script.Destroying:Connect(cleanupAll)
	end
end)

--=====================================================
-- UI
--=====================================================
local cam0 = workspace.CurrentCamera
local viewport = cam0 and cam0.ViewportSize or Vector2.new(1920, 1080)
local PANEL_W = math.min(400, viewport.X - 40)
local PANEL_H = math.min(660, viewport.Y - 40)

local initX = math.floor((viewport.X - PANEL_W) / 2)
local initY = math.floor((viewport.Y - PANEL_H) / 2)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggMasterUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(initX, initY)
panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local pStroke = Instance.new("UIStroke")
pStroke.Color = Color3.fromRGB(64, 68, 82)
pStroke.Thickness = 1
pStroke.Parent = panel

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.BackgroundTransparency = 1
titleBar.Size = UDim2.new(1, 0, 0, 44)
titleBar.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 16, 0, 0)
title.Size = UDim2.new(1, -110, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "Egg 全能脚本 V17"
title.TextColor3 = Color3.fromRGB(240, 242, 248)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local saveLbl = Instance.new("TextLabel")
saveLbl.BackgroundTransparency = 1
saveLbl.AnchorPoint = Vector2.new(1, 0.5)
saveLbl.Position = UDim2.new(1, -48, 0.5, 0)
saveLbl.Size = UDim2.fromOffset(80, 16)
saveLbl.Font = Enum.Font.Gotham
saveLbl.Text = canWriteFile and "✓ 持久化" or "⚠ 仅本次"
saveLbl.TextColor3 = canWriteFile and Color3.fromRGB(100, 220, 140) or Color3.fromRGB(220, 180, 100)
saveLbl.TextSize = 10
saveLbl.TextXAlignment = Enum.TextXAlignment.Right
saveLbl.Parent = titleBar

local minBtn = Instance.new("TextButton")
minBtn.AnchorPoint = Vector2.new(1, 0.5)
minBtn.Position = UDim2.new(1, -10, 0.5, 0)
minBtn.Size = UDim2.fromOffset(28, 28)
minBtn.BackgroundColor3 = Color3.fromRGB(50, 54, 64)
minBtn.BorderSizePixel = 0
minBtn.Font = Enum.Font.GothamBold
minBtn.Text = "−"
minBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
minBtn.TextSize = 18
minBtn.AutoButtonColor = false
minBtn.Parent = titleBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.new(0, 0, 0, 44)
content.Size = UDim2.new(1, 0, 1, -50)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 5
content.ScrollBarImageColor3 = Color3.fromRGB(80, 85, 100)
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = panel

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local contentPad = Instance.new("UIPadding")
contentPad.PaddingLeft = UDim.new(0, 12)
contentPad.PaddingRight = UDim.new(0, 12)
contentPad.PaddingTop = UDim.new(0, 6)
contentPad.PaddingBottom = UDim.new(0, 10)
contentPad.Parent = content

local order = 0
local function nextOrder() order += 10; return order end

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		panel.Size = UDim2.fromOffset(PANEL_W, 44)
		content.Visible = false
		minBtn.Text = "+"
	else
		panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
		content.Visible = true
		minBtn.Text = "−"
	end
end)

local function makeCard()
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Parent = content
	card.LayoutOrder = nextOrder()
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
	local pad = Instance.new("UIPadding", card)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	local lay = Instance.new("UIListLayout", card)
	lay.Padding = UDim.new(0, 6)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	return card
end

local function makeSectionTitle(parent, text)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 14)
	l.Font = Enum.Font.GothamMedium
	l.Text = text
	l.TextColor3 = Color3.fromRGB(150, 155, 170)
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	l.LayoutOrder = 0
	return l
end

local function contrastText(c)
	local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return lum > 0.55 and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(255, 255, 255)
end

local function makeBtn(parent, text, color, h, orderVal)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, h or 30)
	b.Font = Enum.Font.GothamMedium
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 12
	b.AutoButtonColor = false
	b.Parent = parent
	b.LayoutOrder = orderVal or nextOrder()
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15),
			{ BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.18) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15),
			{ BackgroundColor3 = color }):Play()
	end)
	return b
end

--=====================================================
-- 卡片 1：状态（含筛选显示）
--=====================================================
local statusCard = makeCard()
local statsLbl = Instance.new("TextLabel")
statsLbl.BackgroundTransparency = 1
statsLbl.Size = UDim2.new(1, 0, 0, 16)
statsLbl.Font = Enum.Font.Gotham
statsLbl.Text = "光柱 0 / 蛋 0"
statsLbl.TextColor3 = Color3.fromRGB(130, 190, 255)
statsLbl.TextSize = 11
statsLbl.TextXAlignment = Enum.TextXAlignment.Left
statsLbl.Parent = statusCard
statsLbl.LayoutOrder = 1

-- ★ V17：实时显示偷蛋筛选
local filterLbl = Instance.new("TextLabel")
filterLbl.BackgroundTransparency = 1
filterLbl.Size = UDim2.new(1, 0, 0, 16)
filterLbl.Font = Enum.Font.Code
filterLbl.Text = "偷蛋筛选：(计算中)"
filterLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
filterLbl.TextSize = 11
filterLbl.TextXAlignment = Enum.TextXAlignment.Left
filterLbl.TextWrapped = true
filterLbl.AutomaticSize = Enum.AutomaticSize.Y
filterLbl.Parent = statusCard
filterLbl.LayoutOrder = 2

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
autoStatusLbl.Parent = statusCard
autoStatusLbl.LayoutOrder = 3

--=====================================================
-- 卡片 2：自动拿蛋
--=====================================================
local autoCard = makeCard()
local autoBtn = makeBtn(autoCard, "自动拿蛋：关", Color3.fromRGB(150, 60, 60), 36)

--=====================================================
-- 卡片 3：光柱筛选
--=====================================================
local pillarCard = makeCard()
makeSectionTitle(pillarCard, "光柱筛选（除普通外都显示文字）")

local pillarHolder = Instance.new("Frame")
pillarHolder.BackgroundTransparency = 1
pillarHolder.Size = UDim2.new(1, 0, 0, 56)
pillarHolder.Parent = pillarCard
pillarHolder.LayoutOrder = 1

local pillarGrid = Instance.new("UIGridLayout")
pillarGrid.CellSize = UDim2.new(0.25, -3, 0, 26)
pillarGrid.CellPadding = UDim2.new(0, 4, 0, 4)
pillarGrid.SortOrder = Enum.SortOrder.LayoutOrder
pillarGrid.Parent = pillarHolder

local rarityBtns = {}
local function updateRarityBtn(rarity)
	local btn = rarityBtns[rarity]
	if not btn then return end
	local rule = RARITIES[rarity]
	if pillarEnabled[rarity] then
		btn.BackgroundColor3 = rule.color
		btn.TextColor3 = contrastText(rule.color)
	else
		btn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
		btn.TextColor3 = Color3.fromRGB(110, 115, 130)
	end
end

for i, rarity in ipairs(RARITY_ORDER) do
	local btn = Instance.new("TextButton")
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamMedium
	btn.Text = RARITIES[rarity].label
	btn.TextSize = 11
	btn.AutoButtonColor = false
	btn.Parent = pillarHolder
	btn.LayoutOrder = i
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	rarityBtns[rarity] = btn
	updateRarityBtn(rarity)
	btn.MouseButton1Click:Connect(function()
		pillarEnabled[rarity] = not pillarEnabled[rarity]
		updateRarityBtn(rarity)
		saveAll()
		if pillarActive then syncPillars() end
	end)
end

local pillarBtn = makeBtn(pillarCard, "显示光柱：关", Color3.fromRGB(60, 90, 150), 30)

--=====================================================
-- 卡片 4：偷蛋筛选
--=====================================================
local stealCard = makeCard()
makeSectionTitle(stealCard, "偷蛋筛选（只有点亮的才会被偷）")

local stealHolder = Instance.new("Frame")
stealHolder.BackgroundTransparency = 1
stealHolder.Size = UDim2.new(1, 0, 0, 56)
stealHolder.Parent = stealCard
stealHolder.LayoutOrder = 1

local stealGrid = Instance.new("UIGridLayout")
stealGrid.CellSize = UDim2.new(0.25, -3, 0, 26)
stealGrid.CellPadding = UDim2.new(0, 4, 0, 4)
stealGrid.SortOrder = Enum.SortOrder.LayoutOrder
stealGrid.Parent = stealHolder

local stealBtns = {}
local function updateStealBtn(rarity)
	local btn = stealBtns[rarity]
	if not btn then return end
	local rule = RARITIES[rarity]
	if stealEnabled[rarity] then
		btn.BackgroundColor3 = rule.color
		btn.TextColor3 = contrastText(rule.color)
	else
		btn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
		btn.TextColor3 = Color3.fromRGB(110, 115, 130)
	end
end

-- ★ V17：更新筛选显示
local function refreshFilterLabel()
	local list = getActiveStealList()
	if #list == 0 then
		filterLbl.Text = "偷蛋筛选：(空，不会偷任何蛋)"
		filterLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
	else
		filterLbl.Text = "偷蛋筛选：" .. table.concat(list, "、")
		filterLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
	end
end

for i, rarity in ipairs(RARITY_ORDER) do
	local btn = Instance.new("TextButton")
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamMedium
	btn.Text = RARITIES[rarity].label
	btn.TextSize = 11
	btn.AutoButtonColor = false
	btn.Parent = stealHolder
	btn.LayoutOrder = i
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	stealBtns[rarity] = btn
	updateStealBtn(rarity)
	btn.MouseButton1Click:Connect(function()
		stealEnabled[rarity] = not stealEnabled[rarity]
		updateStealBtn(rarity)
		refreshFilterLabel()
		saveAll()
	end)
end

refreshFilterLabel()

--=====================================================
-- 卡片 5：回家坐标
--=====================================================
local homeCard = makeCard()
makeSectionTitle(homeCard, "回家坐标（多个自动备份）")

local homeTopRow = Instance.new("Frame")
homeTopRow.BackgroundTransparency = 1
homeTopRow.Size = UDim2.new(1, 0, 0, 30)
homeTopRow.Parent = homeCard
homeTopRow.LayoutOrder = 1

local addCoordBtn = Instance.new("TextButton")
addCoordBtn.Size = UDim2.new(0.55, -3, 1, 0)
addCoordBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 90)
addCoordBtn.BorderSizePixel = 0
addCoordBtn.Font = Enum.Font.GothamMedium
addCoordBtn.Text = "＋ 添加当前坐标"
addCoordBtn.TextColor3 = Color3.new(1, 1, 1)
addCoordBtn.TextSize = 12
addCoordBtn.AutoButtonColor = false
addCoordBtn.Parent = homeTopRow
Instance.new("UICorner", addCoordBtn).CornerRadius = UDim.new(0, 6)

local clearCoordsBtn = Instance.new("TextButton")
clearCoordsBtn.Position = UDim2.new(0.55, 3, 0, 0)
clearCoordsBtn.Size = UDim2.new(0.45, -3, 1, 0)
clearCoordsBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
clearCoordsBtn.BorderSizePixel = 0
clearCoordsBtn.Font = Enum.Font.GothamMedium
clearCoordsBtn.Text = "清空全部"
clearCoordsBtn.TextColor3 = Color3.new(1, 1, 1)
clearCoordsBtn.TextSize = 12
clearCoordsBtn.AutoButtonColor = false
clearCoordsBtn.Parent = homeTopRow
Instance.new("UICorner", clearCoordsBtn).CornerRadius = UDim.new(0, 6)

local autoRecordBtn = Instance.new("TextButton")
autoRecordBtn.BackgroundColor3 = autoRecordCoord and Color3.fromRGB(60, 140, 90) or Color3.fromRGB(42, 45, 54)
autoRecordBtn.BorderSizePixel = 0
autoRecordBtn.Size = UDim2.new(1, 0, 0, 26)
autoRecordBtn.Font = Enum.Font.GothamMedium
autoRecordBtn.Text = autoRecordCoord
	and "自动记录：开（落地时自动添加坐标）"
	or  "自动记录：关"
autoRecordBtn.TextColor3 = Color3.new(1, 1, 1)
autoRecordBtn.TextSize = 11
autoRecordBtn.AutoButtonColor = false
autoRecordBtn.Parent = homeCard
autoRecordBtn.LayoutOrder = 2
Instance.new("UICorner", autoRecordBtn).CornerRadius = UDim.new(0, 6)

local coordList = Instance.new("Frame")
coordList.BackgroundTransparency = 1
coordList.Size = UDim2.new(1, 0, 0, 0)
coordList.AutomaticSize = Enum.AutomaticSize.Y
coordList.Parent = homeCard
coordList.LayoutOrder = 3

local coordListLayout = Instance.new("UIListLayout")
coordListLayout.Padding = UDim.new(0, 4)
coordListLayout.SortOrder = Enum.SortOrder.LayoutOrder
coordListLayout.Parent = coordList

local coordRowHeight = 32

local rebuildCoordList
rebuildCoordList = function()
	for _, c in ipairs(coordList:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	if #homeCoords == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 20)
		empty.Font = Enum.Font.Gotham
		empty.Text = "（暂无坐标，点击上方按钮添加）"
		empty.TextColor3 = Color3.fromRGB(120, 125, 140)
		empty.TextSize = 11
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Parent = coordList
		empty.LayoutOrder = 1
		return
	end

	for i, coord in ipairs(homeCoords) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, coordRowHeight)
		row.Parent = coordList
		row.LayoutOrder = i
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local idxLbl = Instance.new("TextLabel")
		idxLbl.BackgroundTransparency = 1
		idxLbl.Position = UDim2.new(0, 6, 0, 0)
		idxLbl.Size = UDim2.fromOffset(24, coordRowHeight)
		idxLbl.Font = Enum.Font.GothamBold
		idxLbl.Text = tostring(i)
		idxLbl.TextColor3 = Color3.fromRGB(150, 190, 255)
		idxLbl.TextSize = 12
		idxLbl.Parent = row

		local coordLbl = Instance.new("TextLabel")
		coordLbl.BackgroundTransparency = 1
		coordLbl.Position = UDim2.new(0, 32, 0, 0)
		coordLbl.Size = UDim2.new(0, 130, 1, 0)
		coordLbl.Font = Enum.Font.Code
		coordLbl.Text = string.format("%.0f,%.0f,%.0f",
			coord.pos.X, coord.pos.Y, coord.pos.Z)
		coordLbl.TextColor3 = Color3.fromRGB(200, 220, 240)
		coordLbl.TextSize = 10
		coordLbl.TextXAlignment = Enum.TextXAlignment.Left
		coordLbl.Parent = row

		local noteBox = Instance.new("TextBox")
		noteBox.Position = UDim2.new(0, 164, 0, 4)
		noteBox.Size = UDim2.new(1, -232, 1, -8)
		noteBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
		noteBox.BorderSizePixel = 0
		noteBox.Font = Enum.Font.Gotham
		noteBox.Text = coord.note
		noteBox.PlaceholderText = "备注..."
		noteBox.TextColor3 = Color3.fromRGB(200, 210, 230)
		noteBox.PlaceholderColor3 = Color3.fromRGB(90, 95, 110)
		noteBox.TextSize = 11
		noteBox.ClearTextOnFocus = false
		noteBox.Parent = row
		Instance.new("UICorner", noteBox).CornerRadius = UDim.new(0, 5)
		noteBox.FocusLost:Connect(function()
			coord.note = noteBox.Text
			saveAll()
		end)

		local delBtn = Instance.new("TextButton")
		delBtn.AnchorPoint = Vector2.new(1, 0.5)
		delBtn.Position = UDim2.new(1, -6, 0.5, 0)
		delBtn.Size = UDim2.fromOffset(56, 22)
		delBtn.BackgroundColor3 = Color3.fromRGB(150, 55, 55)
		delBtn.BorderSizePixel = 0
		delBtn.Font = Enum.Font.GothamMedium
		delBtn.Text = "删除"
		delBtn.TextColor3 = Color3.new(1, 1, 1)
		delBtn.TextSize = 11
		delBtn.AutoButtonColor = false
		delBtn.Parent = row
		Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 5)
		delBtn.MouseButton1Click:Connect(function()
			table.remove(homeCoords, i)
			refreshPlotCoord()
			saveAll()
			rebuildCoordList()
		end)
	end
end

rebuildCoordList()

local function addCurrentCoord()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	homeCoords[#homeCoords + 1] = {
		pos = hrp.Position,
		note = "",
	}
	refreshPlotCoord()
	saveAll()
	rebuildCoordList()
end

addCoordBtn.MouseButton1Click:Connect(addCurrentCoord)

clearCoordsBtn.MouseButton1Click:Connect(function()
	table.clear(homeCoords)
	refreshPlotCoord()
	saveAll()
	rebuildCoordList()
end)

autoRecordBtn.MouseButton1Click:Connect(function()
	autoRecordCoord = not autoRecordCoord
	autoRecordBtn.BackgroundColor3 = autoRecordCoord and Color3.fromRGB(60, 140, 90) or Color3.fromRGB(42, 45, 54)
	autoRecordBtn.Text = autoRecordCoord
		and "自动记录：开（落地时自动添加坐标）"
		or  "自动记录：关"
	saveAll()
end)

local function tryAutoRecord()
	if not autoRecordCoord then return end
	if #homeCoords > 0 then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		homeCoords[1] = { pos = hrp.Position, note = "自动" }
		refreshPlotCoord()
		saveAll()
		rebuildCoordList()
	end
end

local function recordWhenReady(char)
	char = char or player.Character
	if not char then return end
	task.spawn(function()
		local hrp = char:WaitForChild("HumanoidRootPart", 15)
		local hum = char:WaitForChild("Humanoid", 15)
		if not hrp or not hum then return end
		local t0 = tick()
		while hum.FloorMaterial == Enum.Material.Air and tick() - t0 < 15 do
			task.wait(0.2)
		end
		task.wait(0.5)
		tryAutoRecord()
	end)
end

player.CharacterAdded:Connect(recordWhenReady)
task.defer(function() recordWhenReady() end)

--=====================================================
-- 卡片 6：传送速度
--=====================================================
local speedCard = makeCard()
makeSectionTitle(speedCard, "传送速度")

local speedRow = Instance.new("Frame")
speedRow.BackgroundTransparency = 1
speedRow.Size = UDim2.new(1, 0, 0, 30)
speedRow.Parent = speedCard
speedRow.LayoutOrder = 1

local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.fromOffset(100, 30)
speedBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
speedBox.BorderSizePixel = 0
speedBox.Font = Enum.Font.Code
speedBox.Text = tostring(TRANSPORT_SPEED)
speedBox.TextColor3 = Color3.fromRGB(200, 220, 240)
speedBox.TextSize = 13
speedBox.ClearTextOnFocus = false
speedBox.Parent = speedRow
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 6)

local speedLbl = Instance.new("TextLabel")
speedLbl.Position = UDim2.new(0, 108, 0, 0)
speedLbl.Size = UDim2.new(1, -108, 1, 0)
speedLbl.BackgroundTransparency = 1
speedLbl.Font = Enum.Font.Gotham
speedLbl.Text = "studs/s（默认 2000）"
speedLbl.TextColor3 = Color3.fromRGB(150, 160, 180)
speedLbl.TextSize = 11
speedLbl.TextXAlignment = Enum.TextXAlignment.Left
speedLbl.Parent = speedRow

speedBox.FocusLost:Connect(function()
	local n = tonumber(speedBox.Text)
	if n and n > 5 then
		TRANSPORT_SPEED = n
		saveAll()
	end
	speedBox.Text = tostring(TRANSPORT_SPEED)
end)

--=====================================================
-- 卡片 7：紧急模式 + 自动加速
--=====================================================
local emergCard = makeCard()
makeSectionTitle(emergCard, "紧急模式 + 自动加速")

local emergRow = Instance.new("Frame")
emergRow.BackgroundTransparency = 1
emergRow.Size = UDim2.new(1, 0, 0, 30)
emergRow.Parent = emergCard
emergRow.LayoutOrder = 1

local emergBtn = Instance.new("TextButton")
emergBtn.Size = UDim2.new(0.5, -3, 1, 0)
emergBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
emergBtn.BorderSizePixel = 0
emergBtn.Font = Enum.Font.GothamMedium
emergBtn.Text = "紧急模式：关"
emergBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
emergBtn.TextSize = 12
emergBtn.AutoButtonColor = false
emergBtn.Parent = emergRow
Instance.new("UICorner", emergBtn).CornerRadius = UDim.new(0, 6)

local emergSpeedBox = Instance.new("TextBox")
emergSpeedBox.Position = UDim2.new(0.5, 3, 0, 0)
emergSpeedBox.Size = UDim2.new(0.5, -3, 1, 0)
emergSpeedBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
emergSpeedBox.BorderSizePixel = 0
emergSpeedBox.Font = Enum.Font.Code
emergSpeedBox.Text = tostring(EMERGENCY_SPEED)
emergSpeedBox.TextColor3 = Color3.fromRGB(255, 200, 100)
emergSpeedBox.TextSize = 13
emergSpeedBox.ClearTextOnFocus = false
emergSpeedBox.Parent = emergRow
Instance.new("UICorner", emergSpeedBox).CornerRadius = UDim.new(0, 6)

local autoAccelBtn = Instance.new("TextButton")
autoAccelBtn.Size = UDim2.new(1, 0, 0, 26)
autoAccelBtn.BackgroundColor3 = (AUTO_ACCEL_THRESH < math.huge)
	and Color3.fromRGB(200, 130, 40)
	or Color3.fromRGB(42, 45, 54)
autoAccelBtn.BorderSizePixel = 0
autoAccelBtn.Font = Enum.Font.GothamMedium
autoAccelBtn.Text = (AUTO_ACCEL_THRESH < math.huge)
	and "自动加速：开（≥1B 用紧急速度）"
	or "自动加速：关"
autoAccelBtn.TextColor3 = Color3.new(1, 1, 1)
autoAccelBtn.TextSize = 12
autoAccelBtn.AutoButtonColor = false
autoAccelBtn.Parent = emergCard
autoAccelBtn.LayoutOrder = 2
Instance.new("UICorner", autoAccelBtn).CornerRadius = UDim.new(0, 6)

local function refreshEmergUI()
	if EMERGENCY_ENABLED then
		emergBtn.Text = "紧急模式：开"
		emergBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
		emergBtn.TextColor3 = Color3.new(1, 1, 1)
	else
		emergBtn.Text = "紧急模式：关"
		emergBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
		emergBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
	end
end
refreshEmergUI()

emergBtn.MouseButton1Click:Connect(function()
	EMERGENCY_ENABLED = not EMERGENCY_ENABLED
	refreshEmergUI()
	saveAll()
end)

emergSpeedBox.FocusLost:Connect(function()
	local n = tonumber(emergSpeedBox.Text)
	if n and n > 10 then
		EMERGENCY_SPEED = n
		saveAll()
	end
	emergSpeedBox.Text = tostring(EMERGENCY_SPEED)
end)

autoAccelBtn.MouseButton1Click:Connect(function()
	if AUTO_ACCEL_THRESH < math.huge then
		AUTO_ACCEL_THRESH = math.huge
		autoAccelBtn.Text = "自动加速：关"
		autoAccelBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
	else
		AUTO_ACCEL_THRESH = 1e9
		autoAccelBtn.Text = "自动加速：开（≥1B 用紧急速度）"
		autoAccelBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
	end
	saveAll()
end)

--=====================================================
-- 卡片 8：树木处理
--=====================================================
local treeCard = makeCard()
makeSectionTitle(treeCard, "树木处理")

local treeRow = Instance.new("Frame")
treeRow.BackgroundTransparency = 1
treeRow.Size = UDim2.new(1, 0, 0, 30)
treeRow.Parent = treeCard
treeRow.LayoutOrder = 1

local TREE_MODES = {
	{ key = "off",    label = "关",   color = Color3.fromRGB( 80,  80,  90) },
	{ key = "hide",   label = "隐藏", color = Color3.fromRGB( 60, 100, 180) },
	{ key = "delete", label = "删除", color = Color3.fromRGB(180,  50,  50) },
}

local treeBtns = {}
local deleteArmed = false

local function updateTreeBtn()
	for k, b in pairs(treeBtns) do
		local color
		for _, m in ipairs(TREE_MODES) do
			if m.key == k then color = m.color break end
		end
		if treeMode == k then
			b.BackgroundColor3 = color
			b.TextColor3 = Color3.new(1, 1, 1)
		else
			b.BackgroundColor3 = Color3.fromRGB(42, 45, 54)
			b.TextColor3 = Color3.fromRGB(180, 185, 200)
		end
	end
end

for i, m in ipairs(TREE_MODES) do
	local b = Instance.new("TextButton")
	b.Position = UDim2.new((i-1) / 3, (i-1) * 2, 0, 0)
	b.Size = UDim2.new(1/3, -4, 1, 0)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamMedium
	b.Text = m.label
	b.TextSize = 12
	b.AutoButtonColor = false
	b.Parent = treeRow
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	treeBtns[m.key] = b
	b.MouseButton1Click:Connect(function()
		if m.key == "delete" then
			if treeMode == "delete" then return end
			if not deleteArmed then
				deleteArmed = true
				b.Text = "再点确认"
				b.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
				task.delay(2, function()
					if deleteArmed then
						deleteArmed = false
						if treeMode ~= "delete" then
							b.Text = "删除"
							updateTreeBtn()
						end
					end
				end)
				return
			end
			deleteArmed = false
			b.Text = "删除"
			if treeMode == "hide" then restoreAllTrees() end
			treeMode = "delete"
			updateTreeBtn()
			saveAll()
			task.defer(applyTreeMode)
			return
		end
		deleteArmed = false
		if treeMode == "hide" and m.key ~= "hide" then restoreAllTrees() end
		treeMode = m.key
		updateTreeBtn()
		saveAll()
		task.defer(applyTreeMode)
	end)
end
updateTreeBtn()

local restoreTreesBtn = makeBtn(treeCard, "还原所有隐藏的树", Color3.fromRGB(60, 140, 90), 30)
restoreTreesBtn.TextSize = 12
restoreTreesBtn.MouseButton1Click:Connect(function()
	treeMode = "off"
	updateTreeBtn()
	restoreAllTrees()
	saveAll()
end)

--=====================================================
-- 拖动
--=====================================================
do
	local dragging = false
	local dragStart, startPos

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = panel.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
			local cur = Vector2.new(input.Position.X, input.Position.Y)
			local delta = cur - dragStart
			panel.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

--=====================================================
-- 按钮事件
--=====================================================
pillarBtn.MouseButton1Click:Connect(function()
	pillarActive = not pillarActive
	if pillarActive then
		pillarBtn.Text = "显示光柱：开"
		pillarBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
		syncPillars()
	else
		pillarBtn.Text = "显示光柱：关"
		pillarBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 150)
		clearPillars()
	end
end)

autoBtn.MouseButton1Click:Connect(function()
	if autoActive then
		stopAuto()
		applyCharState(false)
		autoBtn.Text = "自动拿蛋：关"
		autoBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
		autoStatus = "停止中（等当前蛋处理完）..."
	else
		if #homeCoords == 0 then
			autoStatus = "⚠ 请先添加至少一个回家坐标"
			return
		end
		startAuto()
		autoBtn.Text = "自动拿蛋：开"
		autoBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
	end
end)

--=====================================================
-- 统计
--=====================================================
task.spawn(function()
	while true do
		local pillars = 0
		for _ in pairs(modelToPillar) do pillars += 1 end
		local eggs = collectEggs()
		statsLbl.Text = ("光柱 %d / 蛋 %d / 坐标 %d"):format(pillars, #eggs, #homeCoords)
		autoStatusLbl.Text = autoStatus
		task.wait(0.5)
	end
end)