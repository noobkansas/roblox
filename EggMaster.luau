--!nonstrict
-- =====================================================================
-- EggMaster V37 — 基于 V19.1 核心逻辑
-- 修复: 手上有蛋检测(角色Model) / 回家(篮子) / 稀有度表
-- =====================================================================
print("[EggMaster V37] 启动...")

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local HttpService          = game:GetService("HttpService")

if getgenv().EggMasterCleanup then pcall(getgenv().EggMasterCleanup) end

local localPlayer
for _ = 1, 50 do localPlayer = Players.LocalPlayer; if localPlayer then break end task.wait(0.1) end
if not localPlayer then return end
local playerGui = localPlayer:WaitForChild("PlayerGui", 30)

local WindUI
do
    local ok, err = pcall(function()
        WindUI = loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
    if not ok or not WindUI then warn("[EggMaster] WindUI 加载失败: "..tostring(err)); return end
    print("[EggMaster] WindUI 已加载")
end

--=====================================================
-- 配置
--=====================================================
local CONFIG_FILE = "EggMasterV37.json"
local canWriteFile = (typeof(writefile)=="function" and typeof(readfile)=="function" and typeof(isfile)=="function")

local cfg = {
    transportSpeed = 2000,
    emergencySpeed = 10000,
    emergencyEnabled = false,
    emergencyRarityMin = "God",
    showEggLabels = true,
    pillarEnabled = { Common=false, Rare=false, Epic=false, Legendary=false, Mythic=false, God=false, Beyond=true },
    stealEnabled = { Common=false, Rare=false, Epic=false, Legendary=false, Mythic=false, God=false, Beyond=true },
    treeMode = "off",
    mode = "steal",
    targetPlayerName = nil,
    zoneShape = "circle",
    zoneSize = 150,
    safeRadius = 150,
    plantCols = 5, plantRows = 2, plantSpacing = 14,
    plantRarity = { Common=false, Rare=false, Epic=false, Legendary=false, Mythic=false, God=true, Beyond=true },
    sellBelow = 0,
    autoEggs = false,
    feedPet = "", feedFood = "Grass", feedCount = "10",
}

if canWriteFile and pcall(isfile, CONFIG_FILE) then
    local ok, c = pcall(readfile, CONFIG_FILE)
    if ok and c and c ~= "" then
        local ok2, d = pcall(HttpService.JSONDecode, HttpService, c)
        if ok2 and type(d) == "table" then
            for k, v in pairs(d) do cfg[k] = v end
            print("[EggMaster] 配置已加载")
        end
    end
end

local function saveCfg()
    if not canWriteFile then return end
    local ok, c = pcall(HttpService.JSONEncode, HttpService, cfg)
    if ok then pcall(writefile, CONFIG_FILE, c) end
end
task.spawn(function() while true do task.wait(3); saveCfg() end end)

--=====================================================
-- 常量
--=====================================================
local PILLAR_NAME = "EggPillar"
local PILLAR_GAP = 5
local EGG_LIMIT = 10
local PET_LIMIT = localPlayer:GetAttribute("MaxPets") or 9
local ARRIVE_DISTANCE = 5
local HOME_TIMEOUT = 8.0

local RARITY_ORDER = { "Common","Rare","Epic","Legendary","Mythic","God","Beyond" }
local RARITIES = {
    Common    = { color=Color3.fromRGB(220,220,220), height=120,  thick=3,  flash=false, cycle=false, speed=0, label="普通" },
    Rare      = { color=Color3.fromRGB( 80,180,255), height=300,  thick=4,  flash=false, cycle=false, speed=0, label="稀有" },
    Epic      = { color=Color3.fromRGB(180, 80,255), height=550,  thick=5,  flash=false, cycle=false, speed=0, label="史诗" },
    Legendary = { color=Color3.fromRGB(255,200, 60), height=900,  thick=6,  flash=true,  cycle=false, speed=2, label="传奇" },
    Mythic    = { color=Color3.fromRGB(255, 80,200), height=1500, thick=7,  flash=true,  cycle=true,  speed=3, label="神话" },
    God       = { color=Color3.fromRGB(255, 60, 60),  height=2300, thick=8,  flash=true,  cycle=true,  speed=4, label="神" },
    Beyond    = { color=Color3.fromRGB(  0,255,255), height=3500, thick=10, flash=true,  cycle=true,  speed=6, label="超越" },
}

-- ★ V19.1 的稀有度表（用户验证过是对的）
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
    -- 精确匹配
    local v = KNOWN_VALUES[name]
    if v then return v end
    -- 规范化匹配
    local function norm(s) return (string.lower(s):gsub("%s+", "")) end
    local target = norm(name)
    for k, val in pairs(KNOWN_VALUES) do
        if norm(k) == target then return val end
    end
    -- 不匹配则返回 nil，让调用方处理（默认最保守：Unknown → Common）
    return nil
end

local function formatValue(v)
    if v >= 1e12 then return string.format("%.1fT", v/1e12) end
    if v >= 1e9 then return string.format("%.1fB", v/1e9) end
    if v >= 1e6 then return string.format("%.1fM", v/1e6) end
    if v >= 1e3 then return string.format("%.1fK", v/1e3) end
    return tostring(math.floor(v))
end

local function evalEggValue(model)
    local known = lookupKnown(model.Name)
    if known then return known end
    -- 未知蛋默认 1（Common），不要瞎猜 1e12 导致误判成高品级
    return 1
end

--=====================================================
-- Remote
--=====================================================
local R = {}
do
    local g = ReplicatedStorage:FindFirstChild("Remotes")
    g = g and g:FindFirstChild("Game")
    if g then
        for _, n in ipairs({
            "EggPickup","BasketDrop","Autobuy","EggPlaced","Hatch",
            "FeedPet","PickupPet","PlacePet","PetCollect",
            "PetDismount","PetRideMode","Mounting",
            "SellItems","ConfirmRequest","Rebirth","OpenSell",
        }) do R[n] = g:FindFirstChild(n) end
    end
end
local UpgradesRemote
do
    local g = ReplicatedStorage:FindFirstChild("Remotes")
    g = g and g:FindFirstChild("Game")
    local p = g and g:FindFirstChild("Plot")
    UpgradesRemote = p and p:FindFirstChild("Upgrades")
end

--=====================================================
-- 工具
--=====================================================
local KEYWORDS = { "egg", "蛋" }
local FAKE_KEYWORDS = { "tracker","npc","dummy","player","character","fake","ghost","visual","preview","pillar","masterpillar" }

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
    local root = workspace:FindFirstChild("RenderedEggs")
    if not root then return false end
    if not inst:IsDescendantOf(root) then return false end
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
            if not best or d.MaxActivationDistance > best.MaxActivationDistance then best = d end
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
        return Vector3.new(cf.Position.X, cf.Position.Y - size.Y*0.5 + 3, cf.Position.Z)
    end
    if egg.pivot then return egg.pivot.Position end
    return nil
end

--=====================================================
-- ★ 蛋缓存
--=====================================================
local eggModelCache = {}

local function addEgg(inst)
    if eggModelCache[inst] then return end
    if isRealEgg(inst) then eggModelCache[inst] = true end
end

do
    local root = workspace:FindFirstChild("RenderedEggs")
    if root then
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("Model") and isRealEgg(d) then eggModelCache[d] = true end
        end
        root.DescendantAdded:Connect(function(d)
            if d:IsA("Model") then task.defer(function()
                if d.Parent then addEgg(d) end
            end) end
        end)
        root.DescendantRemoving:Connect(function(d)
            if d:IsA("Model") then eggModelCache[d] = nil end
        end)
    end
end

local function collectEggs()
    local list = {}
    local toRemove = {}
    for model in pairs(eggModelCache) do
        if not model.Parent then
            toRemove[#toRemove+1] = model
        else
            local nested = false
            local p = model.Parent
            while p and p.Name ~= "RenderedEggs" do
                if eggModelCache[p] then nested = true; break end
                p = p.Parent
            end
            if not nested then
                local part = findMainPart(model)
                if part then
                    local prompt = findPrompt(model)
                    if prompt then
                        local value = evalEggValue(model)
                        list[#list+1] = {
                            model = model, pivot = part, value = value,
                            rarity = classifyValue(value), prompt = prompt,
                        }
                    end
                end
            end
        end
    end
    for _, m in ipairs(toRemove) do eggModelCache[m] = nil end
    return list
end

--=====================================================
-- ★ 篮子查找（V19.1 逻辑）
--=====================================================
local function findPlayerPlot(plr)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:GetAttribute("OwnerUserId")
        if owner and owner == plr.UserId then return plot end
        local data = plot:FindFirstChild("Data")
        if data then
            local ownerName = data:FindFirstChild("Owner")
            if ownerName and ownerName.Value == plr.Name then return plot end
        end
        if plot.Name:find(plr.Name, 1, true) then return plot end
    end
    return nil
end

local function findBasketForPlayer(plr)
    local plot = findPlayerPlot(plr)
    if not plot then return nil end
    local candidates = { "Basket","EggBasket","Float","EggSlot","BasketPoint","EggBag" }
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
    local base = plot:FindFirstChild("Baseplate")
    if base then return base end
    return nil
end

--=====================================================
-- ★★★ 手上有蛋检测（角色 Model！）
--=====================================================
local function isHoldingEgg()
    local char = localPlayer.Character
    if not char then return false end
    -- 1. 角色下的蛋 Model
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Model") and nameHas(d.Name, KEYWORDS) then
            if not nameHas(d.Name, FAKE_KEYWORDS) then
                return true
            end
        end
    end
    -- 2. 角色手上的 Tool（有些情况）
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and nameHas(tool.Name, KEYWORDS) then return true end
    -- 3. 背包里的蛋 Model（公共蛋有时暂存此处）
    local bp = localPlayer:FindFirstChild("Backpack")
    if bp then
        for _, d in ipairs(bp:GetChildren()) do
            if d:IsA("Model") and nameHas(d.Name, KEYWORDS) then
                if not nameHas(d.Name, FAKE_KEYWORDS) then return true end
            end
        end
    end
    return false
end

--=====================================================
-- 光柱
--=====================================================
local pillarModel = Instance.new("Model")
pillarModel.Name = "EggMasterPillars"
pcall(function() pillarModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
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
        centerPos = (ok and cf) and cf.Position or egg.pivot.Position
    end

    local baseY = centerPos.Y + PILLAR_GAP
    local centerY = baseY + rule.height * 0.5
    local pos = Vector3.new(centerPos.X, centerY, centerPos.Z)

    local pillar = Instance.new("Part")
    pillar.Name = PILLAR_NAME
    pillar.Anchored = true; pillar.CanCollide = false
    pillar.CanTouch = false; pillar.CanQuery = false; pillar.CastShadow = false
    pillar.Locked = true; pillar.Massless = true
    pillar.Material = Enum.Material.Neon
    pillar.Color = rule.color; pillar.Transparency = 0.05
    pillar.Size = Vector3.new(rule.thick, rule.height, rule.thick)
    pillar.CFrame = CFrame.new(pos)
    pillar.Parent = pillarModel

    local light = Instance.new("PointLight")
    light.Color = rule.color
    light.Brightness = 4 + math.min(rule.height/300, 4)
    light.Range = 40 + math.min(rule.height/20, 40)
    light.Shadows = false
    light.Parent = pillar

    local hl = Instance.new("Highlight")
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor = rule.color; hl.FillTransparency = 0.7
    hl.OutlineColor = rule.color; hl.OutlineTransparency = 0
    hl.Adornee = pillar; hl.Parent = pillar

    -- ★ 悬浮文字挂在蛋本体上（不是光柱）
    if cfg.showEggLabels and egg.rarity ~= "Common" then
        local handle = egg.model:FindFirstChild("Handle")
            or egg.model:FindFirstChild("EggBase")
            or egg.model.PrimaryPart
            or findMainPart(egg.model)
        if handle then
            local bb = Instance.new("BillboardGui")
            bb.Name = "EggLabel"
            bb.Size = UDim2.fromOffset(300, 90)
            bb.AlwaysOnTop = true
            bb.LightInfluence = 0
            bb.MaxDistance = 5000
            bb.Adornee = handle
            bb.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
            bb.Parent = handle

            local n1 = Instance.new("TextLabel")
            n1.BackgroundTransparency = 1
            n1.Size = UDim2.new(1, 0, 0.55, 0)
            n1.Font = Enum.Font.GothamBold
            n1.Text = egg.model.Name
            n1.TextColor3 = Color3.new(1,1,1)
            n1.TextStrokeTransparency = 0
            n1.TextStrokeColor3 = Color3.new(0,0,0)
            n1.TextScaled = true
            n1.Parent = bb

            local n2 = Instance.new("TextLabel")
            n2.BackgroundTransparency = 1
            n2.Position = UDim2.new(0, 0, 0.55, 0)
            n2.Size = UDim2.new(1, 0, 0.45, 0)
            n2.Font = Enum.Font.GothamBold
            n2.Text = string.format("%s [%s]", rule.label, formatValue(egg.value))
            n2.TextColor3 = rule.color
            n2.TextStrokeTransparency = 0
            n2.TextStrokeColor3 = Color3.new(0,0,0)
            n2.TextScaled = true
            n2.Parent = bb
        end
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
    for m in pairs(modelToPillar) do removePillar(m) end
    table.clear(modelToPillar); table.clear(flashEntries)
    if pillarModel then
        for _, v in ipairs(pillarModel:GetChildren()) do pcall(function() v:Destroy() end) end
    end
end

local function syncPillars()
    for m in pairs(modelToPillar) do
        if not m.Parent or not eggModelCache[m] then removePillar(m) end
    end
    for _, egg in ipairs(collectEggs()) do
        if cfg.pillarEnabled[egg.rarity] then
            if not modelToPillar[egg.model] then createPillar(egg) end
        else
            removePillar(egg.model)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.7)
        if pillarActive then pcall(syncPillars) end
    end
end)

task.spawn(function()
    while true do
        local t = tick()
        for pillar, info in pairs(flashEntries) do
            if not pillar.Parent then flashEntries[pillar] = nil
            else
                local rule = RARITIES[info.rarity]
                local pulse = 0.5 + 0.5 * math.sin(t * (4 + rule.speed) + info.phase)
                local c = rule.color
                if rule.cycle then
                    local h = (t * 0.1 * (1 + rule.speed/3) + info.phase * 0.1) % 1
                    local _, s, v = Color3.toHSV(rule.color)
                    c = Color3.fromHSV(h, math.max(s, 0.7), v)
                else
                    c = rule.color:Lerp(Color3.new(1,1,1), pulse * 0.5)
                end
                pillar.Color = c
                pillar.Transparency = 0.05 + pulse * 0.15
                local light = pillar:FindFirstChildOfClass("PointLight")
                if light then light.Color = c; light.Brightness = 5 + pulse * 6 end
            end
        end
        task.wait(0.03)
    end
end)

--=====================================================
-- 树木
--=====================================================
local treeHidden = {}
local TREE_KEYWORDS = { "tree", "树", "bush", "leaf", "branch", "log", "trunk" }
local TREE_SKIP = { "terrain" }

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
    local function h(inst)
        if inst:IsA("BasePart") then
            entries[#entries+1] = { inst=inst, p="Transparency", o=inst.Transparency }
            entries[#entries+1] = { inst=inst, p="CanCollide", o=inst.CanCollide }
            pcall(function() inst.Transparency = 1; inst.CanCollide = false end)
        end
    end
    h(root)
    for _, d in ipairs(root:GetDescendants()) do h(d) end
    treeHidden[root] = entries
end

local function restoreOneTree(root)
    local entries = treeHidden[root]
    if not entries then return end
    for _, e in ipairs(entries) do pcall(function() (e.inst :: any)[e.p] = e.o end) end
    treeHidden[root] = nil
end

local function applyTreeMode()
    if cfg.treeMode == "off" then return end
    for _, d in ipairs(workspace:GetDescendants()) do
        if isTreeInstance(d) and not hasTreeAncestor(d) then
            if cfg.treeMode == "hide" then hideOneTree(d)
            elseif cfg.treeMode == "delete" then
                treeHidden[d] = nil
                pcall(function() d:Destroy() end)
            end
        end
    end
end

local function restoreAllTrees()
    local keys = {}
    for k in pairs(treeHidden) do keys[#keys+1] = k end
    for _, k in ipairs(keys) do restoreOneTree(k) end
    table.clear(treeHidden)
end

--=====================================================
-- ★★★ 偷蛋核心（V19.1 逻辑）
--=====================================================
local stealState = { running = false, status = "空闲" }
local feeding = { active = false, cancel = false }
local eggBusy = false
local autoPlace, autoSell, autoRebirth, autoLuck = false, false, false, false

local lastSetPos, moveTarget = nil, nil

local function setMoveTarget(pos, speed)
    moveTarget = pos
    lastSetPos = nil
end

RunService.Heartbeat:Connect(function(dt)
    local char = localPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- 穿墙
    if stealState.running then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                if d.CanCollide then d.CanCollide = false end
                if d.CanTouch then d.CanTouch = false end
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and not hum.PlatformStand then hum.PlatformStand = true end
    end

    local target = moveTarget
    if not target then lastSetPos = nil; return end

    local cur = hrp.Position
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

    local spd = (stealState.running and cfg.transportSpeed) or cfg.transportSpeed
    local step = math.min(dist, spd * dt)
    local np = cur + diff.Unit * step
    char:PivotTo(CFrame.new(np) * (hrp.CFrame - hrp.CFrame.Position))
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    lastSetPos = np
end)

local function applyCharState(fly)
    local char = localPlayer.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then d.CanCollide = not fly end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if not fly then
            hum.PlatformStand = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
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
        if hrp and (hrp.Position - targetPos).Magnitude < ARRIVE_DISTANCE then
            moveTarget = nil
            return "arrived"
        end
        task.wait(0.03)
    end
    moveTarget = nil
    return "timeout"
end

-- 三路齐发抓蛋
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

    -- 阻塞等待：蛋消失 或 手上有蛋 或 超时
    local waitTime = math.max(prompt.HoldDuration or 0.3, 0.3) + 1.5
    local t0 = tick()
    local grabbed = false
    while tick() - t0 < waitTime do
        if not egg.model.Parent then grabbed = true; break end
        if isHoldingEgg() then grabbed = true; break end
        task.wait(0.05)
    end

    pcall(function() prompt:InputHoldEnd() end)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    task.wait(0.15)
    return grabbed or isHoldingEgg()
end

local function dropBasket()
    if R.BasketDrop then pcall(function() R.BasketDrop:FireServer() end) end
end

-- ★ 回家：把蛋放回自己篮子
local function goHome()
    local basket = findBasketForPlayer(localPlayer)
    if not basket then
        stealState.status = "找不到篮子，直接 BasketDrop"
        dropBasket(); task.wait(0.5)
        return false
    end
    stealState.status = "回家中..."
    travelTo(basket.Position + Vector3.new(0, 5, 0), cfg.emergencySpeed, HOME_TIMEOUT)
    task.wait(0.3)
    -- 反复尝试到手上没蛋（最多 5 秒）
    local t0 = tick()
    while tick() - t0 < 5 do
        if not isHoldingEgg() then return true end
        dropBasket()
        task.wait(0.5)
    end
    return not isHoldingEgg()
end

-- ★ 送蛋：把蛋放到目标玩家篮子
local function deliverToTarget()
    if not cfg.targetPlayerName then return false end
    local target = Players:FindFirstChild(cfg.targetPlayerName)
    if not target then
        stealState.status = "目标玩家已离开"
        return false
    end
    local basket = findBasketForPlayer(target)
    if not basket then
        stealState.status = "找不到目标篮子"
        return false
    end
    stealState.status = "送货中 → " .. cfg.targetPlayerName
    travelTo(basket.Position + Vector3.new(0, 5, 0), cfg.emergencySpeed, HOME_TIMEOUT)
    task.wait(0.3)
    local t0 = tick()
    while tick() - t0 < 5 do
        if not isHoldingEgg() then return true end
        dropBasket()
        task.wait(0.5)
    end
    return not isHoldingEgg()
end

-- ★ 处理手上的蛋（回家/送目标）
local function clearHandEgg()
    if not isHoldingEgg() then return true end
    if cfg.mode == "deliver" and cfg.targetPlayerName then
        return deliverToTarget()
    else
        return goHome()
    end
end

-- 安全区
local homeCenter = nil
local function refreshHomeCenter()
    local b = findBasketForPlayer(localPlayer)
    if b then homeCenter = b.Position end
end
refreshHomeCenter()

local function isInSafeZone(pos)
    if not homeCenter then return false end
    local diff = pos - homeCenter
    if cfg.zoneShape == "square" then
        return math.abs(diff.X) <= cfg.zoneSize and math.abs(diff.Z) <= cfg.zoneSize
    else
        return math.sqrt(diff.X*diff.X + diff.Z*diff.Z) <= cfg.zoneSize
    end
end

local function speedForEgg(egg)
    if cfg.emergencyEnabled then
        local i = table.find(RARITY_ORDER, egg.rarity)
        local m = table.find(RARITY_ORDER, cfg.emergencyRarityMin)
        if i and m and i >= m then return cfg.emergencySpeed end
    end
    return cfg.transportSpeed
end

-- ★ 主循环（每轮开始/每次偷前都检查手上有蛋）
local function startSteal()
    if stealState.running then return end
    if cfg.mode == "deliver" and not cfg.targetPlayerName then
        stealState.status = "⚠ 请先选目标玩家"
        return
    end
    stealState.running = true
    applyCharState(true)
    refreshHomeCenter()

    task.spawn(function()
        while stealState.running do
            -- ★ 每轮开始：手上有蛋必须先处理
            if isHoldingEgg() then
                stealState.status = "手上有蛋，优先处理"
                local ok = clearHandEgg()
                task.wait(0.3)
                if not ok then task.wait(1) end
            else
                local eggs = collectEggs()
                local filtered = {}
                for _, e in ipairs(eggs) do
                    if cfg.stealEnabled[e.rarity] then filtered[#filtered+1] = e end
                end
                table.sort(filtered, function(a, b) return a.value > b.value end)

                if #filtered == 0 then
                    setMoveTarget(nil)
                    stealState.status = "无目标，悬浮等待..."
                    task.wait(1)
                else
                    for i, egg in ipairs(filtered) do
                        if not stealState.running then break end
                        if not egg.model.Parent then
                            -- 该蛋已消失，继续下一个
                        else
                            -- ★ 每次偷前再检查手上有蛋
                            if isHoldingEgg() then
                                stealState.status = "手上有蛋，先处理"
                                local ok = clearHandEgg()
                                task.wait(0.3)
                                if not ok then break end
                            end

                            if isInSafeZone(egg.pivot.Position) then
                                stealState.status = string.format("[%d/%d] %s 在安全区跳过",
                                    i, #filtered, egg.model.Name)
                            else
                                stealState.status = string.format("[%d/%d] %s (%s)",
                                    i, #filtered, egg.model.Name, egg.rarity)

                                dropBasket()
                                task.wait(0.4)

                                local point = getEggInteractPoint(egg)
                                if point then
                                    local spd = speedForEgg(egg)
                                    travelTo(point, spd, 4)
                                    task.wait(0.2)

                                    if tryGrab(egg) then
                                        stealState.status = string.format("[%d/%d] %s 成功，处理中",
                                            i, #filtered, egg.model.Name)
                                        -- ★★★ 抓到后立即处理
                                        local ok = clearHandEgg()
                                        if not ok then
                                            stealState.status = "处理失败，下一轮重试"
                                        end
                                    else
                                        stealState.status = string.format("[%d/%d] %s 失败",
                                            i, #filtered, egg.model.Name)
                                    end
                                end
                            end
                        end
                        task.wait(0.3)
                    end
                    task.wait(0.5)
                end
            end
        end
        setMoveTarget(nil)
        applyCharState(false)
        stealState.status = "空闲"
    end)
end

local function stopSteal() stealState.running = false end

--=====================================================
-- 放蛋 / 开蛋
--=====================================================
local function getMyPlot()
    return findPlayerPlot(localPlayer)
end

local function countPlacedEggs()
    local plot = getMyPlot()
    local eggs = plot and plot:FindFirstChild("Eggs")
    return eggs and #eggs:GetChildren() or 0
end

local function getMySlots()
    local plot = getMyPlot()
    if not plot then return {} end
    local base = plot:FindFirstChild("Baseplate")
    if not base or not base:IsA("BasePart") then return {} end
    local center = base.Position
    local topY = center.Y + base.Size.Y/2 + 0.5
    local cols = math.max(1, cfg.plantCols or 5)
    local rows = math.max(1, cfg.plantRows or 2)
    local spacing = cfg.plantSpacing or 14
    local halfW = (cols-1) * spacing/2
    local halfH = (rows-1) * spacing/2
    local slots = {}
    for r = 0, rows-1 do
        for c = 0, cols-1 do
            local dx = -halfW + c * spacing
            local dz = -halfH + r * spacing
            slots[#slots+1] = Vector3.new(center.X+dx, topY, center.Z+dz)
        end
    end
    return slots
end

local function openEggs()
    if eggBusy then return 0 end
    eggBusy = true
    local n = 0
    local plot = getMyPlot()
    local eggs = plot and plot:FindFirstChild("Eggs")
    if eggs then
        for _, e in ipairs(eggs:GetChildren()) do
            local k = e:GetAttribute("EggKey")
            local complete = e:GetAttribute("EggBuildComplete")
            if k and complete and R.Hatch then
                pcall(function() R.Hatch:FireServer({ EggKey = k }) end)
                n = n + 1
                task.wait(0.3)
            end
        end
    end
    eggBusy = false
    return n
end

local function placeAllEggs()
    if eggBusy then return 0, "忙" end
    eggBusy = true
    local existing = countPlacedEggs()
    if existing >= EGG_LIMIT then eggBusy = false; return 0, "已满" end

    local slots = getMySlots()
    if #slots == 0 then eggBusy = false; return 0, "无蛋位" end

    local bp = localPlayer:FindFirstChild("Backpack")
    if not bp then eggBusy = false; return 0, "无背包" end
    local eggsToPlace = {}
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then
            local v = lookupKnown(t.Name) or 1
            local rar = classifyValue(v)
            if cfg.plantRarity[rar] then
                eggsToPlace[#eggsToPlace+1] = { tool=t, rarity=rar }
            end
        end
    end
    if #eggsToPlace == 0 then eggBusy = false; return 0, "无符合蛋" end

    local RARITY_NUM = { Common=1,Rare=2,Epic=3,Legendary=4,Mythic=5,God=6,Beyond=7 }
    table.sort(eggsToPlace, function(a, b)
        return (RARITY_NUM[a.rarity] or 0) > (RARITY_NUM[b.rarity] or 0)
    end)

    local char = localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then eggBusy = false; return 0, "无角色" end

    local placed, failed = 0, 0
    local maxCan = math.min(#slots, #eggsToPlace, EGG_LIMIT - existing)

    for i = 1, maxCan do
        local entry = eggsToPlace[i]
        local egg = entry.tool
        local slot = slots[i]

        -- 检查槽位占用
        local busy = false
        local plot = getMyPlot()
        local eg = plot and plot:FindFirstChild("Eggs")
        if eg then
            for _, e in ipairs(eg:GetChildren()) do
                local eb = e:FindFirstChild("EggBase")
                local p = eb and eb.Position or e:GetPivot().Position
                local dx = slot.X - p.X
                local dz = slot.Z - p.Z
                if math.sqrt(dx*dx + dz*dz) < 6 then busy = true; break end
            end
        end

        if busy then
            -- skip
        elseif not egg.Parent then
            failed = failed + 1
        else
            pcall(function() hum:EquipTool(egg) end)
            task.wait(0.2)
            local hand = char:FindFirstChildOfClass("Tool")
            if not hand then
                failed = failed + 1
            else
                travelTo(Vector3.new(slot.X, slot.Y+3, slot.Z), cfg.transportSpeed, 5)
                task.wait(0.4)
                local before = countPlacedEggs()
                local ok = false
                if R.EggPlaced then
                    for _ = 1, 3 do
                        pcall(function() R.EggPlaced:FireServer({ PlantPosition = slot }) end)
                        task.wait(0.6)
                        if countPlacedEggs() > before or not char:FindFirstChildOfClass("Tool") then
                            ok = true; break
                        end
                    end
                end
                if ok then placed = placed + 1 else failed = failed + 1 end
            end
        end
        task.wait(0.2)
    end
    eggBusy = false
    return placed, string.format("已放%d 失败%d", placed, failed)
end

--=====================================================
-- 卖宠 / 喂食 / 商店
--=====================================================
local SELL_COORD = Vector3.new(169.39, 40316.16, 935.01)
local function parseIncome(text)
    if type(text) ~= "string" or text == "" then return 0 end
    local numStr = text:match("(%d+%.?%d*)")
    if not numStr then return 0 end
    local n = tonumber(numStr) or 0
    local u = text:upper()
    if u:find("QI",1,true) then return n*1e18 end
    if u:find("QA",1,true) then return n*1e15 end
    if u:find("T",1,true) then return n*1e12 end
    if u:find("B",1,true) then return n*1e9 end
    if u:find("M",1,true) then return n*1e6 end
    if u:find("K",1,true) then return n*1e3 end
    return n
end

local function looksLikeUUID(s)
    if type(s) ~= "string" then return false end
    if #s < 32 or #s > 40 then return false end
    return s:find("-",1,true) ~= nil
end

local function getMain() return playerGui:FindFirstChild("Main") end

local function sellPets(threshold)
    threshold = tonumber(threshold) or 0
    -- 传送到卖点
    travelTo(SELL_COORD, cfg.transportSpeed, 8)
    task.wait(0.8)
    -- 按 E
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    -- 等 Sell 面板加载
    local main = getMain()
    local sell = main and main:FindFirstChild("Sell")
    local sf
    local t0 = tick()
    local loaded = false
    while tick() - t0 < 5 do
        sell = main and main:FindFirstChild("Sell")
        sf = sell and sell:FindFirstChild("ScrollingFrame")
        if sf then
            for _, e in ipairs(sf:GetChildren()) do
                if looksLikeUUID(e.Name) then loaded = true; break end
            end
        end
        if loaded then break end
        task.wait(0.15)
    end
    if not loaded then return 0, "面板未加载" end
    task.wait(0.4)

    local items = {}
    for _, entry in ipairs(sf:GetChildren()) do
        if looksLikeUUID(entry.Name) then
            for _, sub in ipairs(entry:GetDescendants()) do
                if sub:IsA("TextLabel") then
                    local ln = sub.Name:lower()
                    if ln:find("income",1,true) or ln:find("rate",1,true) then
                        items[#items+1] = { key=entry.Name, frame=entry, val=parseIncome(sub.Text) }
                        break
                    end
                end
            end
        end
    end
    if #items == 0 then return 0, "无条目" end
    table.sort(items, function(a,b) return a.val > b.val end)
    local protect = {}
    for i = 1, math.min(PET_LIMIT, #items) do protect[items[i].key] = true end

    local sellList = {}
    for _, item in ipairs(items) do
        if not protect[item.key] and item.val < threshold then
            local btn = item.frame:FindFirstChildOfClass("ImageButton") or item.frame:FindFirstChildOfClass("TextButton")
            if btn then
                if typeof(firesignal) == "function" then pcall(firesignal, btn.MouseButton1Click) end
                pcall(function() btn:Activate() end)
            end
            task.wait(0.12)
            sellList[#sellList+1] = item.key
        end
    end
    if #sellList == 0 then return 0, "无可卖" end

    if R.SellItems then pcall(function() R.SellItems:FireServer({ Pets = sellList, Eggs = {} }) end) end
    task.wait(1.2)
    local conf = main and main:FindFirstChild("Confirmation")
    if conf then
        local cb = conf:FindFirstChild("Confirm")
        if cb and cb:IsA("ImageButton") then
            if typeof(firesignal) == "function" then pcall(firesignal, cb.MouseButton1Click) end
            pcall(function() cb:Activate() end)
            task.wait(0.8)
        end
    end
    if R.ConfirmRequest then
        for _ = 1, 3 do
            local uuid = HttpService:GenerateGUID(false)
            if conf then
                local q = conf:FindFirstChild("Question")
                if q then
                    local found = q.Text:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)")
                    if found then uuid = found end
                end
            end
            pcall(function() R.ConfirmRequest:FireServer(uuid, true, "Yes") end)
            task.wait(1.0)
            if not conf or not conf.Parent or conf.Visible == false then break end
        end
    end
    return #sellList, "已卖"
end

--=====================================================
-- 自动任务循环
--=====================================================
task.spawn(function()
    while true do task.wait(5)
        if autoPlace then pcall(placeAllEggs) end
    end
end)
task.spawn(function()
    while true do task.wait(10)
        if autoSell then pcall(function() sellPets(cfg.sellBelow) end) end
    end
end)
task.spawn(function()
    while true do task.wait(0.25)
        if autoLuck and UpgradesRemote then pcall(function() UpgradesRemote:FireServer("Max") end) end
    end
end)
task.spawn(function()
    while true do task.wait(5)
        if cfg.autoEggs then pcall(openEggs) end
    end
end)

--=====================================================
-- UI
--=====================================================
local Window
do
    local ok, err = pcall(function()
        Window = WindUI:CreateWindow({
            Title = "EggMaster V37",
            Author = "V19.1 核心",
            Folder = "EggMasterV37",
            Icon = "solar:star-bold-duotone",
            Size = UDim2.fromOffset(720, 405),
            MinSize = Vector2.new(560, 350),
            MaxSize = Vector2.new(850, 560),
            Transparent = true,
            Theme = "Dark",
            SideBarWidth = 180,
            OpenButton = {
                Title = "EggMaster",
                CornerRadius = UDim.new(1, 0),
                StrokeThickness = 2,
                Enabled = true,
                Draggable = true,
            },
        })
    end)
    if not ok or not Window then warn("[EggMaster] 窗口失败: "..tostring(err)); return end
    print("[EggMaster] 窗口已创建")
end

-- 信息
local statusPara, rankPara
do
    pcall(function()
        local infoTab = Window:Tab({ Title = "信息", Icon = "solar:chart-bold-duotone" })
        statusPara = infoTab:Paragraph({ Title = "状态", Desc = "加载中..." })
        rankPara = infoTab:Paragraph({ Title = "手上有蛋", Desc = "..." })
    end)
end

local function refreshInfo()
    if not statusPara or not rankPara then return end
    pcall(function()
        refreshHomeCenter()
        local holding = isHoldingEgg()
        local char = localPlayer.Character
        local heldDetail = "(空)"
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("Model") and nameHas(d.Name, KEYWORDS) and not nameHas(d.Name, FAKE_KEYWORDS) then
                    heldDetail = d.Name .. " [" .. d.ClassName .. "]"
                    break
                end
            end
            if heldDetail == "(空)" then
                local t = char:FindFirstChildOfClass("Tool")
                if t and nameHas(t.Name, KEYWORDS) then heldDetail = t.Name .. " [Tool]" end
            end
        end

        statusPara:SetDesc(string.format(
            "手上有蛋：%s ｜ 持有：%s\n"
            .. "家坐标：%s ｜ 模式：%s\n"
            .. "状态：%s",
            tostring(holding), heldDetail,
            homeCenter and string.format("(%.0f, %.0f)", homeCenter.X, homeCenter.Z) or "?",
            cfg.mode == "deliver" and ("送蛋→"..tostring(cfg.targetPlayerName)) or "偷蛋",
            stealState.status))

        local eggs = collectEggs()
        local lines = { string.format("公共蛋共 %d 个：", #eggs) }
        table.sort(eggs, function(a,b) return a.value > b.value end)
        for i = 1, math.min(10, #eggs) do
            local e = eggs[i]
            lines[#lines+1] = string.format("%d. %s (%s) [%s]",
                i, e.model.Name, e.rarity, formatValue(e.value))
        end
        rankPara:SetDesc(table.concat(lines, "\n"))
    end)
end

task.spawn(function() task.wait(2); refreshInfo(); while true do task.wait(2); refreshInfo() end end)

-- 关于
do pcall(function()
    local aboutTab = Window:Tab({ Title = "关于", Icon = "solar:info-circle-bold-duotone" })
    aboutTab:Paragraph({ Title = "EggMaster V37", Desc = "基于 V19.1 · 手上有蛋(角色Model) · 篮子回家" })
end) end

-- 偷蛋 Tab
do pcall(function()
    local stealTab = Window:Tab({ Title = "偷蛋", Icon = "solar:target-bold-duotone" })
    stealTab:Toggle({
        Title = "自动偷蛋",
        Default = cfg.autoSteal == true,
        Callback = function(v)
            cfg.autoSteal = v
            if v then startSteal() else stopSteal() end
        end,
    })
    local sStatus = stealTab:Paragraph({ Title = "状态", Desc = "空闲" })
    task.spawn(function()
        while true do task.wait(0.5); pcall(function() sStatus:SetDesc(stealState.status) end) end
    end)

    stealTab:Section({ Title = "模式" })
    stealTab:Dropdown({
        Title = "模式",
        Values = { "偷蛋模式", "送蛋模式" },
        Value = cfg.mode == "deliver" and "送蛋模式" or "偷蛋模式",
        Callback = function(v)
            cfg.mode = (v == "送蛋模式") and "deliver" or "steal"
        end,
    })

    local deliverTargetDropdown
    local function refreshPlayerList()
        local names = { "(未选)" }
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= localPlayer then
                names[#names+1] = string.format("%s (@%s) [%d]",
                    plr.DisplayName or plr.Name, plr.Name, plr.UserId)
            end
        end
        if deliverTargetDropdown and deliverTargetDropdown.Refresh then
            pcall(function() deliverTargetDropdown:Refresh(names) end)
        end
        return names
    end
    deliverTargetDropdown = stealTab:Dropdown({
        Title = "送蛋目标",
        Values = refreshPlayerList(),
        Value = cfg.targetPlayerName and ("(@"..cfg.targetPlayerName..")") or "(未选)",
        Callback = function(v)
            local un = v:match("@([%w_]+)")
            if un then cfg.targetPlayerName = un end
        end,
    })
    stealTab:Button({ Title = "🔄 刷新玩家", Callback = refreshPlayerList })
    task.spawn(function() while true do task.wait(5); pcall(refreshPlayerList) end end)

    stealTab:Section({ Title = "稀有度筛选" })
    for _, r in ipairs(RARITY_ORDER) do
        stealTab:Toggle({
            Title = RARITIES[r].label,
            Default = cfg.stealEnabled[r] or false,
            Callback = function(v) cfg.stealEnabled[r] = v end,
        })
    end
end) end

-- 光柱 Tab
do pcall(function()
    local pillarTab = Window:Tab({ Title = "光柱", Icon = "solar:flashlight-bold-duotone" })
    pillarTab:Toggle({
        Title = "显示光柱",
        Default = pillarActive,
        Callback = function(v)
            pillarActive = v
            if v then syncPillars() else clearPillars() end
        end,
    })
    pillarTab:Toggle({
        Title = "显示悬浮文字",
        Default = cfg.showEggLabels,
        Callback = function(v)
            cfg.showEggLabels = v
            clearPillars()
            if pillarActive then syncPillars() end
        end,
    })
    pillarTab:Section({ Title = "稀有度筛选" })
    for _, r in ipairs(RARITY_ORDER) do
        pillarTab:Toggle({
            Title = RARITIES[r].label,
            Default = cfg.pillarEnabled[r] or false,
            Callback = function(v)
                cfg.pillarEnabled[r] = v
                clearPillars()
                if pillarActive then syncPillars() end
            end,
        })
    end

    pillarTab:Section({ Title = "树木" })
    local delArmed = false
    pillarTab:Button({ Title = "关", Callback = function()
        if cfg.treeMode == "hide" then restoreAllTrees() end
        cfg.treeMode = "off"
    end })
    pillarTab:Button({ Title = "隐藏", Callback = function()
        cfg.treeMode = "hide"; task.defer(applyTreeMode)
    end })
    pillarTab:Button({ Title = "删除（二次确认）", Callback = function()
        if not delArmed then
            delArmed = true
            WindUI:Notify({ Title = "再点一次", Duration = 2 })
            task.delay(3, function() delArmed = false end)
            return
        end
        delArmed = false
        if cfg.treeMode == "hide" then restoreAllTrees() end
        cfg.treeMode = "delete"; task.defer(applyTreeMode)
    end })
    pillarTab:Button({ Title = "还原", Callback = function()
        cfg.treeMode = "off"; restoreAllTrees()
    end })
end) end

-- 蛋 Tab
do pcall(function()
    local eggTab = Window:Tab({ Title = "蛋", Icon = "solar:egg-bold-duotone" })
    eggTab:Toggle({ Title = "自动开蛋", Default = cfg.autoEggs,
        Callback = function(v) cfg.autoEggs = v end })
    eggTab:Button({
        Title = "一键开家蛋",
        Callback = function()
            task.spawn(function()
                local n = openEggs()
                WindUI:Notify({ Title = "开了 "..n.." 个", Duration = 3 })
            end)
        end,
    })
    eggTab:Section({ Title = "放蛋品质" })
    for _, r in ipairs(RARITY_ORDER) do
        eggTab:Toggle({
            Title = RARITIES[r].label,
            Default = cfg.plantRarity[r] or false,
            Callback = function(v) cfg.plantRarity[r] = v end,
        })
    end
    eggTab:Section({ Title = "网格参数" })
    eggTab:Input({ Title = "列数", Value = tostring(cfg.plantCols),
        Callback = function(v) local n=tonumber(v); if n and n>=1 and n<=10 then cfg.plantCols=n end end })
    eggTab:Input({ Title = "行数", Value = tostring(cfg.plantRows),
        Callback = function(v) local n=tonumber(v); if n and n>=1 and n<=10 then cfg.plantRows=n end end })
    eggTab:Input({ Title = "间距", Value = tostring(cfg.plantSpacing),
        Callback = function(v) local n=tonumber(v); if n and n>=5 and n<=30 then cfg.plantSpacing=n end end })
    eggTab:Button({
        Title = "一键放蛋",
        Callback = function()
            task.spawn(function()
                local n, msg = placeAllEggs()
                WindUI:Notify({ Title = "放蛋 ("..n..")", Content = msg, Duration = 4 })
            end)
        end,
    })
end) end

-- 宠物 Tab
do pcall(function()
    local petTab = Window:Tab({ Title = "宠物", Icon = "solar:cat-bold-duotone" })
    petTab:Toggle({
        Title = "自动卖宠",
        Default = cfg.autoSell == true,
        Callback = function(v) autoSell = v; cfg.autoSell = v end,
    })
    petTab:Input({ Title = "收益阈值", Value = tostring(cfg.sellBelow),
        Callback = function(v) cfg.sellBelow = tonumber(v) or 0 end })
    petTab:Button({
        Title = "立即卖宠",
        Callback = function()
            task.spawn(function()
                local n, msg = sellPets(cfg.sellBelow)
                WindUI:Notify({ Title = "卖宠", Content = msg.."("..n..")", Duration = 3 })
            end)
        end,
    })
end) end

-- 商店 Tab
do pcall(function()
    local shopTab = Window:Tab({ Title = "商店", Icon = "solar:cart-bold-duotone" })
    shopTab:Toggle({ Title = "自动拉满幸运", Default = cfg.autoLuck == true,
        Callback = function(v) autoLuck = v; cfg.autoLuck = v end })
end) end

-- 设置 Tab
do pcall(function()
    local setTab = Window:Tab({ Title = "设置", Icon = "solar:settings-bold-duotone" })
    setTab:Input({ Title = "传送速度", Value = tostring(cfg.transportSpeed),
        Callback = function(v) local n=tonumber(v); if n and n>5 then cfg.transportSpeed=n end end })
    setTab:Input({ Title = "紧急速度", Value = tostring(cfg.emergencySpeed),
        Callback = function(v) local n=tonumber(v); if n and n>10 then cfg.emergencySpeed=n end end })
    setTab:Toggle({ Title = "紧急模式", Default = cfg.emergencyEnabled,
        Callback = function(v) cfg.emergencyEnabled = v end })
    setTab:Dropdown({ Title = "紧急起始稀有度",
        Values = RARITY_ORDER, Value = cfg.emergencyRarityMin,
        Callback = function(v) cfg.emergencyRarityMin = v end })
    setTab:Input({ Title = "安全区半径", Value = tostring(cfg.zoneSize),
        Callback = function(v) local n=tonumber(v); if n and n>=5 then cfg.zoneSize=n end end })
    setTab:Button({ Title = "保存配置", Callback = saveCfg })
end) end

-- 快捷键
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightAlt then
        pcall(function() Window:Open() end)
        pcall(function() Window:Show() end)
    end
end)

if Window.OnClose then pcall(function() Window:OnClose(function() saveCfg() end) end) end

--=====================================================
-- 清理
--=====================================================
local function cleanup()
    stealState.running = false
    eggBusy = false
    feeding.cancel = true
    pcall(clearPillars)
    if pillarModel then pcall(function() pillarModel:Destroy() end) end
    pcall(restoreAllTrees)
    local c = localPlayer.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
    saveCfg()
    print("[EggMaster V37] 已清理")
end

getgenv().EggMasterCleanup = cleanup
pcall(function() if script then script.Destroying:Connect(cleanup) end end)

if cfg.autoSteal then task.defer(startSteal) end

WindUI:Notify({ Title = "EggMaster V37 已启动", Content = "V19.1 核心逻辑", Duration = 5 })
print("[EggMaster V37] 加载完成")
