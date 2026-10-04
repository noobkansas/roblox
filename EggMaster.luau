--!strict
--!native
-- =====================================================================
-- EggMaster V54 · 完全重写
-- =====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

if getgenv().EggMasterCleanup then pcall(getgenv().EggMasterCleanup) end

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui") :: PlayerGui

-- =====================================================================
-- ★ 所有状态在最顶部（修 197 报错）
-- =====================================================================
local State = {
    stopAll = false,
    stealRunning = false,
    stealStatus = "就绪",
    feedActive = false,
    feedCancel = false,
    eggBusy = false,
    holding = false,
    gravityForce = nil :: BodyForce?,
    uiOpen = false,
    renderOrder = 0,
}

-- =====================================================================
-- 主题
-- =====================================================================
local Th = {
    Bg=Color3.fromRGB(20,20,23), Sur=Color3.fromRGB(30,30,36),
    Sec=Color3.fromRGB(26,26,31), Card=Color3.fromRGB(36,36,43),
    CardTitle=Color3.fromRGB(46,46,56),
    Str=Color3.fromRGB(70,70,84),
    Txt=Color3.fromRGB(255,255,255),
    Sub=Color3.fromRGB(200,200,210),
    Acc=Color3.fromRGB(88,140,255),
    Ok=Color3.fromRGB(86,200,122),
    Err=Color3.fromRGB(240,92,92),
    Warn=Color3.fromRGB(240,180,80),
    Hdl=Color3.fromRGB(200,200,210),
    Teal=Color3.fromRGB(0,199,190),
    Purple=Color3.fromRGB(140,120,255),
}

local FB = Enum.Font.GothamBold
local FS = Enum.Font.GothamSemibold
local FR = Enum.Font.Gotham

local SZ_TITLE = 18
local SZ_SECTION = 14
local SZ_ITEM = 15
local SZ_TIP = 13

local G = 8
local TITLE_H = 40
local TIPS_H = 40
local SBAR_W = 108

-- 描边规则
local function strokeOf(c: Color3): Color3
    local l = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
    return l > 0.5 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
end

-- =====================================================================
-- 稀有度
-- =====================================================================
type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "God" | "Beyond"

local ORDER: { Rarity } = { "Common","Rare","Epic","Legendary","Mythic","God","Beyond" }
local NUM: { [Rarity]: number } = {
    Common=1, Rare=2, Epic=3, Legendary=4, Mythic=5, God=6, Beyond=7,
}

-- ★ 高度/宽度差距拉大，肉眼可辨
local RAR = {
    Common    = { color=Color3.fromRGB(200,200,200), height=80,  thick=2,   label="普通" },
    Rare      = { color=Color3.fromRGB( 80,180,255), height=140, thick=2.5, label="稀有" },
    Epic      = { color=Color3.fromRGB(180, 80,255), height=200, thick=3,   label="史诗" },
    Legendary = { color=Color3.fromRGB(255,200, 60), height=280, thick=4,   label="传奇" },
    Mythic    = { color=Color3.fromRGB(255, 80,200), height=360, thick=5,   label="神话" },
    God       = { color=Color3.fromRGB(255, 60, 60),  height=440, thick=6,  label="神" },
    Beyond    = { color=Color3.fromRGB(  0,255,255), height=520, thick=8,  label="超越" },
}

local KNOWN = {
    ["White Egg"]=1,["Brown Egg"]=5,["Cracked Egg"]=30,["Easter Egg"]=50,
    ["Stone Egg"]=100,["Leaf Egg"]=200,["Mushroom Egg"]=500,["Flower Egg"]=750,
    ["Slime Egg"]=1e3,["Ice Egg"]=3e3,["Glass Egg"]=1e4,["Golden Egg"]=3e4,
    ["Diamond Egg"]=90e3,["Crystal Egg"]=150e3,["Skull Egg"]=250e3,
    ["Asteroid Egg"]=500e3,["Dominus Egg"]=700e3,["Flaming Egg"]=1e6,
    ["Sinister Egg"]=3e6,["Soul Egg"]=7e6,["Tidal Egg"]=8e6,
    ["Aurora Egg"]=300e6,["Galaxy Egg"]=1.5e9,["Bloom Egg"]=2e9,
    ["Blackhole Egg"]=100e9,["Solaris Egg"]=300e9,["Cherub Egg"]=1e12,
    ["Volcanic Egg"]=2.5e12,
}

local PILLAR_NAME = "EggPillar"
local BILLBOARD_NAME = "EggPillarBB"
local EGG_LIMIT = 10
local PET_LIMIT = LP:GetAttribute("MaxPets") or 9
local ARRIVE_DIST = 5
local HOME_TIMEOUT = 8
local SELL_COORD = Vector3.new(169.39, 40316.16, 935.01)

-- =====================================================================
-- 配置
-- =====================================================================
local CFG_KEY = "EggMasterV54Config"

local DEFAULTS = {
    transportSpeed = 2000,
    emergencySpeed = 10000,
    emergencyEnabled = false,
    emergencyRarityMin = "God" :: Rarity,
    showPillar = false,
    showBillboard = false,
    showRarityValue = true,
    pillarEnabled = {
        Common=true, Rare=true, Epic=true, Legendary=true,
        Mythic=true, God=true, Beyond=true,
    },
    stealEnabled = {
        Common=false, Rare=false, Epic=false, Legendary=false,
        Mythic=false, God=false, Beyond=true,
    },
    treeMode = "off",
    mode = "steal",
    targetPlayerName = nil :: string?,
    zoneSize = 150,
    plantCols = 5, plantRows = 2, plantSpacing = 14,
    plantRarity = {
        Common=false, Rare=false, Epic=false, Legendary=false,
        Mythic=false, God=true, Beyond=true,
    },
    sellBelow = 0,
    autoEggs = false,
    autoPlace = false,
    autoSell = false,
    autoRebirth = false,
    autoLuck = false,
    autoSteal = false,
    autoDismount = true,
    autoPlaceAll = false,
    autoEggsInterval = 5,
    autoPlaceInterval = 5,
    autoPlaceAllInterval = 5,
    autoSellInterval = 10,
    autoLuckInterval = 0.25,
    autoRebirthInterval = 2,
    eggMoveThreshold = 5,
    feedPet = "", feedFood = "Grass", feedCount = "10",
    feedInterval = 0.4,
    rebirthTarget = 0,
    grabHoldBegin = true,
    grabFirePrompt = true,
    grabEKey = true,
    grabHoldExtra = 0.6,
    opacityBg = 1.0,
    opacityPanel = 1.0,
    winW = 620, winH = 520,
}

local Config: any = {}
for k, v in pairs(DEFAULTS) do
    if type(v) == "table" then
        local copy = {}
        for k2, v2 in pairs(v) do copy[k2] = v2 end
        Config[k] = copy
    else
        Config[k] = v
    end
end

local function deepMerge(dst: any, src: any): ()
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            deepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
end

do
    local s = _G[CFG_KEY]
    if type(s) == "table" then deepMerge(Config, s) end
end

local function SaveCfg(): ()
    local s: any = {}
    for k, v in pairs(Config) do
        if type(v) == "table" then
            local copy = {}
            for k2, v2 in pairs(v) do copy[k2] = v2 end
            s[k] = copy
        else
            s[k] = v
        end
    end
    _G[CFG_KEY] = s
end

-- 5 秒自动保存
task.spawn(function()
    while not State.stopAll do
        task.wait(5)
        pcall(SaveCfg)
    end
end)

-- =====================================================================
-- Remote
-- =====================================================================
local R: { [string]: RemoteEvent? } = {}
do
    local f = ReplicatedStorage:FindFirstChild("Remotes")
    local gf = f and f:FindFirstChild("Game")
    if gf then
        for _, n in ipairs({
            "EggPickup","BasketDrop","Autobuy","EggPlaced","Hatch",
            "FeedPet","PickupPet","PlacePet","PetCollect",
            "PetDismount","PetRideMode","Mounting",
            "SellItems","ConfirmRequest","Rebirth","OpenSell",
        }) do R[n] = gf:FindFirstChild(n) :: RemoteEvent? end
    end
end
local UPG: RemoteEvent?
do
    local f = ReplicatedStorage:FindFirstChild("Remotes")
    local gf = f and f:FindFirstChild("Game")
    local plot = gf and gf:FindFirstChild("Plot")
    UPGRADE = plot and plot:FindFirstChild("Upgrades") :: RemoteEvent?
end

-- =====================================================================
-- 工具
-- =====================================================================
local function hasKw(n: string, ks: { string }): boolean
    local l = n:lower()
    for _, k in ipairs(ks) do
        if l:find(k:lower(), 1, true) then return true end
    end
    return false
end

local function classify(v: number): Rarity
    if v >= 1e11 then return "Beyond"
    elseif v >= 1e9 then return "God"
    elseif v >= 1e8 then return "Mythic"
    elseif v >= 1e7 then return "Legendary"
    elseif v >= 5e5 then return "Epic"
    elseif v >= 1e3 then return "Rare"
    else return "Common" end
end

local function lookup(n: string): number?
    local d = KNOWN[n]
    if d then return d end
    local function norm(s: string): string return s:lower():gsub("%s+", "") end
    local t = norm(n)
    for k, v in pairs(KNOWN) do
        if norm(k) == t then return v end
    end
    return nil
end

local function fmtV(v: number): string
    if v >= 1e12 then return string.format("%.1fT", v/1e12) end
    if v >= 1e9 then return string.format("%.1fB", v/1e9) end
    if v >= 1e6 then return string.format("%.1fM", v/1e6) end
    if v >= 1e3 then return string.format("%.1fK", v/1e3) end
    return tostring(math.floor(v))
end

local function parseInc(t: string): number
    if t == "" then return 0 end
    local ns = t:match("(%d+%.?%d*)")
    if not ns then return 0 end
    local b = tonumber(ns) or 0
    local u = t:upper()
    if u:find("QI",1,true) then return b*1e18 end
    if u:find("QA",1,true) then return b*1e15 end
    if u:find("T",1,true) then return b*1e12 end
    if u:find("B",1,true) then return b*1e9 end
    if u:find("M",1,true) then return b*1e6 end
    if u:find("K",1,true) then return b*1e3 end
    return b
end

local function isUUID(s: string): boolean
    if #s < 32 or #s > 40 then return false end
    return s:find("-", 1, true) ~= nil
end

local function cl(v: number, lo: number, hi: number): number
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- =====================================================================
-- 持蛋检测（UI 0.25s）
-- =====================================================================
local function checkHolding(): boolean
    local eb = PG:FindFirstChild("EggBreaking")
    if eb then
        if eb:IsA("ScreenGui") and eb.Enabled then return true end
        if eb:IsA("GuiObject") and eb.Visible then return true end
    end
    local main = PG:FindFirstChild("Main")
    local de = main and main:FindFirstChild("DropEgg")
    if de and de:IsA("GuiObject") and de.Visible then
        local p = de.Parent
        local ok = true
        while p and p ~= game do
            if p:IsA("GuiObject") and not p.Visible then ok = false; break end
            if p:IsA("ScreenGui") and not p.Enabled then ok = false; break end
            p = p.Parent
        end
        if ok then return true end
    end
    return false
end

task.spawn(function()
    while not State.stopAll do
        State.holding = checkHolding()
        task.wait(0.25)
    end
end)

local function isHolding(): boolean return State.holding end

-- =====================================================================
-- 反重力
-- =====================================================================
local function startAntiGrav(): ()
    local c = LP.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end
    if State.gravityForce and State.gravityForce.Parent then return end
    local bf = Instance.new("BodyForce")
    bf.Name = "EggMaster_AntiGrav"
    bf.Force = Vector3.new(0, hrp:GetMass() * workspace.Gravity, 0)
    bf.Parent = hrp
    State.gravityForce = bf
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = true
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)
    end
end

local function stopAntiGrav(): ()
    if State.gravityForce then
        pcall(function() State.gravityForce:Destroy() end)
        State.gravityForce = nil
    end
    local c = LP.Character
    if c then
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            end)
        end
    end
end

task.spawn(function()
    while not State.stopAll do
        task.wait(0.2)
        if State.stealRunning then
            local c = LP.Character
            if c then
                local hrp = c:FindFirstChild("HumanoidRootPart") :: BasePart?
                if hrp then
                    if not State.gravityForce or not State.gravityForce.Parent then
                        local bf = Instance.new("BodyForce")
                        bf.Name = "EggMaster_AntiGrav"
                        bf.Parent = hrp
                        State.gravityForce = bf
                    end
                    (State.gravityForce :: BodyForce).Force =
                        Vector3.new(0, hrp:GetMass() * workspace.Gravity, 0)
                end
            end
        end
    end
end)

-- =====================================================================
-- 篮子查找
-- =====================================================================
local function findPlot(p: Player): Instance?
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local oid = plot:GetAttribute("OwnerUserId")
        if oid ~= nil and tonumber(oid) == p.UserId then return plot end
        local d = plot:FindFirstChild("Data")
        if d then
            local on = d:FindFirstChild("Owner")
            if on then
                local v = (on :: any).Value
                if v == p.Name or tostring(v) == p.Name then return plot end
            end
        end
    end
    return nil
end

local function findBasket(p: Player): BasePart?
    local plot = findPlot(p)
    if not plot then return nil end
    for _, n in ipairs({ "Basket","EggBasket","Float","EggSlot","BasketPoint","EggBag" }) do
        local c = plot:FindFirstChild(n, true)
        if c and c:IsA("BasePart") then return c end
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
    local b = plot:FindFirstChild("Baseplate")
    if b and b:IsA("BasePart") then return b end
    return nil
end

-- =====================================================================
-- 蛋扫描（只扫 RenderedEggs / 无假蛋逻辑）
-- =====================================================================
local eggSet: { [Model]: boolean } = {}

local function isLocal(inst: Instance): boolean
    local c = LP.Character
    return c ~= nil and inst:IsDescendantOf(c)
end

local function getMainPart(m: Model): BasePart?
    if m.PrimaryPart then return m.PrimaryPart end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

local function getPrompt(m: Model): ProximityPrompt?
    local best: ProximityPrompt? = nil
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            if not best then best = d
            elseif d.Enabled and not best.Enabled then best = d
            end
        end
    end
    return best
end

local function isRealEgg(inst: Instance): boolean
    if not inst:IsA("Model") then return false end
    if inst.Name == PILLAR_NAME then return false end
    if inst.Name == BILLBOARD_NAME then return false end
    if not hasKw(inst.Name, { "egg", "蛋" }) then return false end
    if inst:FindFirstChildOfClass("Humanoid") then return false end
    if hasKw(inst.Name, { "tracker","npc","dummy","player","character","fake","ghost","visual","preview","pillar","masterpillar" }) then return false end
    if isLocal(inst) then return false end
    local re = workspace:FindFirstChild("RenderedEggs")
    if not re or not inst:IsDescendantOf(re) then return false end
    return true
end

local function scanEggs(): ()
    local re = workspace:FindFirstChild("RenderedEggs")
    if not re then return end
    for _, d in ipairs(re:GetDescendants()) do
        if d:IsA("Model") and isRealEgg(d) then
            eggSet[d] = true
        end
    end
end

type Entry = {
    model: Model,
    part: BasePart,
    value: number,
    rarity: Rarity,
    prompt: ProximityPrompt?,
}

local function collect(): { Entry }
    local out: { Entry } = table.create(16)
    local rm: { Model } = {}
    for m in pairs(eggSet) do
        if not m.Parent then
            table.insert(rm, m)
        else
            local p = getMainPart(m)
            if p then
                local v = lookup(m.Name) or 1
                table.insert(out, {
                    model = m,
                    part = p,
                    value = v,
                    rarity = classify(v),
                    prompt = getPrompt(m),
                })
            end
        end
    end
    for _, m in ipairs(rm) do eggSet[m] = nil end
    return out
end

task.spawn(function()
    while not State.stopAll do
        task.wait(1)
        pcall(scanEggs)
    end
end)
task.spawn(function()
    while not State.stopAll do
        task.wait(60)
        table.clear(eggSet)
    end
end)

-- =====================================================================
-- ★★★ 光柱系统（Part / Billboard / 数值 —— 三个独立开关）
-- =====================================================================
local modelToPart: { [Model]: BasePart } = {}
local modelToBB: { [Model]: BillboardGui } = {}

local function destroyPillarFor(m: Model): ()
    local p = modelToPart[m]
    if p then p:Destroy(); modelToPart[m] = nil end
    local b = modelToBB[m]
    if b then b:Destroy(); modelToBB[m] = nil end
end

local function clearAllPillars(): ()
    for m in pairs(modelToPart) do destroyPillarFor(m) end
    table.clear(modelToPart)
    table.clear(modelToBB)
    -- 保险：清掉 workspace 里所有残留
    for _, c in ipairs(workspace:GetChildren()) do
        if c.Name == PILLAR_NAME or c.Name == BILLBOARD_NAME then
            c:Destroy()
        end
    end
end

local function makePartFor(e: Entry): BasePart
    local rule = RAR[e.rarity]
    local base = e.part.Position
    local topY = base.Y + rule.height * 0.5

    local p = Instance.new("Part")
    p.Name = PILLAR_NAME
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Locked = true
    p.Massless = true
    p.Material = Enum.Material.Neon
    p.Color = rule.color
    p.Transparency = 0.3
    p.Size = Vector3.new(rule.thick, rule.height, rule.thick)
    p.CFrame = CFrame.new(base.X, topY, base.Z)
    p.Parent = workspace

    -- 透视 Highlight
    local hl = Instance.new("Highlight")
    hl.Name = "EggPillarHl"
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor = rule.color
    hl.FillTransparency = 0.5
    hl.OutlineColor = rule.color
    hl.OutlineTransparency = 0
    hl.Adornee = p
    hl.Parent = p

    return p
end

local function makeBBFor(e: Entry): BillboardGui
    local rule = RAR[e.rarity]
    local base = e.part.Position

    local bb = Instance.new("BillboardGui")
    bb.Name = BILLBOARD_NAME
    bb.Size = UDim2.fromOffset(340, 96)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 100000
    -- 挂到蛋的 MainPart 上方
    bb.Adornee = e.part
    bb.StudsOffsetWorldSpace = Vector3.new(0, rule.height + 20, 0)
    bb.DisplayOrder = 100 + (NUM[e.rarity] or 1) * 10
    bb.Parent = e.part

    local t1 = Instance.new("TextLabel")
    t1.BackgroundTransparency = 1
    t1.Size = UDim2.new(1, 0, 0.5, 0)
    t1.Font = FB
    t1.Text = e.model.Name
    t1.TextColor3 = Color3.new(1, 1, 1)
    t1.TextStrokeColor3 = Color3.new(0, 0, 0)
    t1.TextStrokeTransparency = 0.3
    t1.TextScaled = true
    t1.ZIndex = 1000
    t1.Parent = bb

    -- 只在"显示稀有度数值"开启时创建第二行
    if Config.showRarityValue then
        local t2 = Instance.new("TextLabel")
        t2.BackgroundTransparency = 1
        t2.Position = UDim2.new(0, 0, 0.5, 0)
        t2.Size = UDim2.new(1, 0, 0.5, 0)
        t2.Font = FB
        t2.Text = string.format("%s [%s]", rule.label, fmtV(e.value))
        t2.TextColor3 = rule.color
        t2.TextStrokeColor3 = strokeOf(rule.color)
        t2.TextStrokeTransparency = 0.3
        t2.TextScaled = true
        t2.ZIndex = 1000
        t2.Parent = bb
    end

    return bb
end

local function syncPillars(): ()
    local all = collect()

    -- 先清理掉不再匹配的
    for m in pairs(modelToPart) do
        local alive = false
        for _, e in ipairs(all) do
            if e.model == m then alive = true; break end
        end
        if not alive then destroyPillarFor(m) end
    end
    for m in pairs(modelToBB) do
        if not modelToPart[m] or not Config.showBillboard then
            local b = modelToBB[m]
            if b then b:Destroy() end
            modelToBB[m] = nil
        end
    end

    -- 逐个处理
    for _, e in ipairs(all) do
        local shouldHavePillar = Config.showPillar and Config.pillarEnabled[e.rarity]
        local shouldHaveBB = Config.showBillboard and Config.pillarEnabled[e.rarity]
            and e.rarity ~= "Common"   -- 普通不显示文字

        -- Part
        if shouldHavePillar then
            if not modelToPart[e.model] or not modelToPart[e.model].Parent then
                modelToPart[e.model] = makePartFor(e)
            else
                -- 更新位置和尺寸（蛋被移动时）
                local p = modelToPart[e.model] :: BasePart
                local rule = RAR[e.rarity]
                local base = e.part.Position
                p.Size = Vector3.new(rule.thick, rule.height, rule.thick)
                p.CFrame = CFrame.new(base.X, base.Y + rule.height * 0.5, base.Z)
            end
        else
            local p = modelToPart[e.model]
            if p then p:Destroy(); modelToPart[e.model] = nil end
        end

        -- Billboard
        if shouldHaveBB then
            if not modelToBB[e.model] or not modelToBB[e.model].Parent then
                modelToBB[e.model] = makeBBFor(e)
            end
        else
            local b = modelToBB[e.model]
            if b then b:Destroy(); modelToBB[e.model] = nil end
        end
    end
end

-- 同步循环
task.spawn(function()
    while not State.stopAll do
        task.wait(0.5)
        if Config.showPillar or Config.showBillboard then
            pcall(syncPillars)
        else
            if next(modelToPart) or next(modelToBB) then
                clearAllPillars()
            end
        end
    end
end)

-- =====================================================================
-- 树木
-- =====================================================================
type TEntry = { inst: Instance, prop: string, orig: any }
local treeHidden: { [Instance]: { TEntry } } = {}

local function isTree(inst: Instance): boolean
    if not hasKw(inst.Name, { "tree","树","bush","leaf","branch","log","trunk" }) then return false end
    if hasKw(inst.Name, { "terrain" }) then return false end
    if LP.Character and inst:IsDescendantOf(LP.Character) then return false end
    return true
end

local function hasTreeAnc(inst: Instance): boolean
    local p = inst.Parent
    while p and p ~= workspace do
        if isTree(p) then return true end
        p = p.Parent
    end
    return false
end

local function hideOne(root: Instance): ()
    if treeHidden[root] then return end
    local es: { TEntry } = {}
    local function h(i: Instance)
        if i:IsA("BasePart") then
            table.insert(es, { inst = i, prop = "Transparency", orig = i.Transparency })
            table.insert(es, { inst = i, prop = "CanCollide", orig = i.CanCollide })
            i.Transparency = 1
            i.CanCollide = false
        end
    end
    h(root)
    for _, d in ipairs(root:GetDescendants()) do h(d) end
    treeHidden[root] = es
end

local function restoreOne(root: Instance): ()
    local es = treeHidden[root]
    if not es then return end
    for _, x in ipairs(es) do
        pcall(function() (x.inst :: any)[x.prop] = x.orig end)
    end
    treeHidden[root] = nil
end

local function applyTree(): ()
    if Config.treeMode == "off" then return end
    for _, d in ipairs(workspace:GetDescendants()) do
        if isTree(d) and not hasTreeAnc(d) then
            if Config.treeMode == "hide" then hideOne(d)
            elseif Config.treeMode == "delete" then
                treeHidden[d] = nil
                d:Destroy()
            end
        end
    end
end

local function restoreTrees(): ()
    local ks: { Instance } = {}
    for k in pairs(treeHidden) do table.insert(ks, k) end
    for _, k in ipairs(ks) do restoreOne(k) end
    table.clear(treeHidden)
end

-- =====================================================================
-- 移动
-- =====================================================================
local moveTarget: Vector3? = nil
local lastSet: Vector3? = nil
local holdPos: Vector3? = nil

local function setMove(p: Vector3?): ()
    moveTarget = p
    lastSet = nil
    if p then holdPos = nil end
end

RunService.Heartbeat:Connect(function(dt: number)
    if State.stopAll then return end
    local c = LP.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    if State.stealRunning then
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") then
                if d.CanCollide then d.CanCollide = false end
                if d.CanTouch then d.CanTouch = false end
            end
        end
    end

    if not moveTarget and holdPos then
        if (holdPos - hrp.Position).Magnitude > 0.3 then
            c:PivotTo(CFrame.new(holdPos))
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        return
    end

    local t = moveTarget
    if not t then lastSet = nil; return end
    local cur = hrp.Position
    if lastSet and (cur - lastSet).Magnitude > 50 then
        c:PivotTo(CFrame.new(lastSet) * (hrp.CFrame - hrp.CFrame.Position))
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return
    end
    local diff = t - cur
    local d = diff.Magnitude
    if d < 0.5 then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        lastSet = cur
        return
    end
    local step = math.min(d, Config.transportSpeed * dt)
    local np = cur + diff.Unit * step
    c:PivotTo(CFrame.new(np) * (hrp.CFrame - hrp.CFrame.Position))
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    lastSet = np
end)

local function applyCharState(fly: boolean): ()
    local c = LP.Character
    if not c then return end
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") then d.CanCollide = not fly end
    end
end

local function travelTo(target: Vector3, timeout: number): string
    local t0 = tick()
    setMove(target)
    while tick() - t0 < timeout and not State.stopAll do
        local c = LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp and (hrp.Position - target).Magnitude < ARRIVE_DIST then
            moveTarget = nil
            return "arrived"
        end
        task.wait(0.03)
    end
    moveTarget = nil
    return "timeout"
end

-- =====================================================================
-- 抓蛋 / 送蛋
-- =====================================================================
local function dropBasket(): ()
    local r = R.BasketDrop
    if r then pcall(function() r:FireServer() end) end
end

local function goHomeOrDeliver(): boolean
    local dest: Vector3? = nil
    if Config.mode == "deliver" and Config.targetPlayerName then
        local t = Players:FindFirstChild(Config.targetPlayerName)
        if t then
            local b = findBasket(t)
            if b then dest = b.Position + Vector3.new(0, 5, 0) end
        end
    end
    if not dest then
        local b = findBasket(LP)
        if b then dest = b.Position + Vector3.new(0, 5, 0) end
    end
    if not dest then dropBasket(); return false end
    State.stealStatus = "前往目的地"
    travelTo(dest, HOME_TIMEOUT)
    task.wait(0.3)
    for _ = 1, 3 do dropBasket(); task.wait(0.4) end
    return true
end

local function tryGrab(e: Entry): boolean
    if not e.prompt or not e.prompt.Parent then
        goHomeOrDeliver()
        return false
    end
    local p = e.prompt

    if Config.grabHoldBegin then
        pcall(function() p:InputHoldBegin() end)
    end
    if Config.grabFirePrompt and typeof(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(p) end)
    end
    if Config.grabEKey then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        end)
    end

    local waitTime = math.max(p.HoldDuration or 0.2, 0.2) + Config.grabHoldExtra
    task.wait(waitTime)

    if Config.grabHoldBegin then
        pcall(function() p:InputHoldEnd() end)
    end
    if Config.grabEKey then
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end
    task.wait(0.2)
    goHomeOrDeliver()
    return true
end

-- =====================================================================
-- 安全区
-- =====================================================================
local homeCenter: Vector3? = nil
local function refreshHome(): ()
    local b = findBasket(LP)
    if b then homeCenter = b.Position end
end
refreshHome()

local function isSafe(p: Vector3): boolean
    if not homeCenter then return false end
    local d = p - homeCenter
    return math.sqrt(d.X * d.X + d.Z * d.Z) <= Config.zoneSize
end

-- =====================================================================
-- 偷蛋主循环
-- =====================================================================
local eggPos: { [Model]: Vector3 } = {}

local function startSteal(): ()
    if State.stealRunning then return end
    if Config.mode == "deliver" and not Config.targetPlayerName then
        State.stealStatus = "请先选目标玩家"
        return
    end
    State.stealRunning = true
    applyCharState(true)
    startAntiGrav()
    refreshHome()

    task.spawn(function()
        while State.stealRunning and not State.stopAll do
            if isHolding() then
                State.stealStatus = "手上有蛋，先送"
                goHomeOrDeliver()
                task.wait(0.3)
                continue
            end

            local all = collect()
            local filt: { Entry } = {}
            for _, e in ipairs(all) do
                if Config.stealEnabled[e.rarity] then table.insert(filt, e) end
            end
            table.sort(filt, function(a, b) return a.value > b.value end)

            if #filt == 0 then
                local c = LP.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
                if hrp and not holdPos then holdPos = hrp.Position end
                moveTarget = nil
                State.stealStatus = "无符合稀有度的蛋"
                task.wait(1)
                continue
            end

            for i, e in ipairs(filt) do
                if not State.stealRunning or State.stopAll then break end
                if isHolding() then break end

                local skip = false
                if not e.model.Parent then skip = true end
                if not skip and eggPos[e.model] then
                    local moved = (e.part.Position - (eggPos[e.model] :: Vector3)).Magnitude
                    if moved > Config.eggMoveThreshold then
                        State.stealStatus = string.format("[%d/%d] %s 已被抢", i, #filt, e.model.Name)
                        eggPos[e.model] = nil
                        skip = true
                    end
                end
                if not skip and isSafe(e.part.Position) then
                    State.stealStatus = string.format("[%d/%d] %s 安全区", i, #filt, e.model.Name)
                    skip = true
                end
                if skip then task.wait(0.2); continue end

                eggPos[e.model] = e.part.Position
                State.stealStatus = string.format("[%d/%d] %s (%s)", i, #filt, e.model.Name, e.rarity)
                dropBasket()
                task.wait(0.3)

                local point = e.part.Position
                if e.prompt then
                    local ok, wp = pcall(function() return e.prompt.WorldPosition end)
                    if ok and wp then point = wp end
                end
                travelTo(point, 4)
                task.wait(0.2)
                tryGrab(e)
                eggPos[e.model] = nil
                task.wait(0.2)
            end
            task.wait(0.3)
        end
        setMove(nil)
        holdPos = nil
        applyCharState(false)
        stopAntiGrav()
        State.stealStatus = "空闲"
    end)
end

local function stopSteal(): () State.stealRunning = false end

-- =====================================================================
-- 放蛋 / 开蛋 / 放最佳
-- =====================================================================
local function myPlot(): Instance? return findPlot(LP) end

local function countPlaced(): number
    local p = myPlot()
    local e = p and p:FindFirstChild("Eggs")
    return e and #e:GetChildren() or 0
end

local function getSlots(): { Vector3 }
    local p = myPlot()
    if not p then return {} end
    local b = p:FindFirstChild("Baseplate")
    if not b or not b:IsA("BasePart") then return {} end
    local c = b.Position
    local topY = c.Y + b.Size.Y / 2 + 0.5
    local cols, rows, sp = Config.plantCols, Config.plantRows, Config.plantSpacing
    local hw = (cols - 1) * sp / 2
    local hh = (rows - 1) * sp / 2
    local s: { Vector3 } = table.create(cols * rows)
    for r = 0, rows - 1 do
        for cc = 0, cols - 1 do
            table.insert(s, Vector3.new(c.X - hw + cc * sp, topY, c.Z - hh + r * sp))
        end
    end
    return s
end

local function openEggs(): number
    if State.eggBusy then return 0 end
    State.eggBusy = true
    local n = 0
    local p = myPlot()
    local e = p and p:FindFirstChild("Eggs")
    if e then
        for _, egg in ipairs(e:GetChildren()) do
            local k = egg:GetAttribute("EggKey")
            local comp = egg:GetAttribute("EggBuildComplete")
            if k and comp and R.Hatch then
                pcall(function() (R.Hatch :: RemoteEvent):FireServer({ EggKey = k }) end)
                n = n + 1
                task.wait(0.3)
            end
        end
    end
    State.eggBusy = false
    return n
end

local function placeAll(): (number, string)
    if State.eggBusy then return 0, "忙" end
    State.eggBusy = true
    local exist = countPlaced()
    if exist >= EGG_LIMIT then State.eggBusy = false; return 0, "已满" end
    local slots = getSlots()
    if #slots == 0 then State.eggBusy = false; return 0, "无蛋位" end
    local bp = LP:FindFirstChild("Backpack")
    if not bp then State.eggBusy = false; return 0, "无背包" end
    local cands: { { tool: Tool, rarity: Rarity } } = {}
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then
            local v = lookup(t.Name) or 1
            local r = classify(v)
            if Config.plantRarity[r] then table.insert(cands, { tool = t, rarity = r }) end
        end
    end
    if #cands == 0 then State.eggBusy = false; return 0, "无符合蛋" end
    table.sort(cands, function(a, b) return NUM[a.rarity] > NUM[b.rarity] end)
    local c = LP.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if not hum then State.eggBusy = false; return 0, "无角色" end
    local placed, fail = 0, 0
    local maxN = math.min(#slots, #cands, EGG_LIMIT - exist)
    for i = 1, maxN do
        local cd = cands[i]
        local slot = slots[i]
        if not cd.tool.Parent then
            fail = fail + 1
        else
            pcall(function() hum:EquipTool(cd.tool) end)
            task.wait(0.2)
            if not c:FindFirstChildOfClass("Tool") then
                fail = fail + 1
            else
                travelTo(Vector3.new(slot.X, slot.Y + 3, slot.Z), 5)
                task.wait(0.4)
                local before = countPlaced()
                local ok = false
                if R.EggPlaced then
                    for _ = 1, 3 do
                        pcall(function() (R.EggPlaced :: RemoteEvent):FireServer({ PlantPosition = slot }) end)
                        task.wait(0.6)
                        if countPlaced() > before or not c:FindFirstChildOfClass("Tool") then
                            ok = true
                            break
                        end
                    end
                end
                if ok then placed = placed + 1 else fail = fail + 1 end
            end
        end
        task.wait(0.2)
    end
    State.eggBusy = false
    return placed, string.format("已放%d 失败%d", placed, fail)
end

local function goHome(): ()
    local b = findBasket(LP)
    if b then travelTo(b.Position + Vector3.new(0, 8, 0), 6) end
end

local function placeBest(): (boolean, string)
    goHome(); task.wait(0.5)
    if Config.autoDismount then
        local main = PG:FindFirstChild("Main")
        local ah = main and main:FindFirstChild("ActionsHolder")
        local btn = ah and ah:FindFirstChild("Dismount")
        if btn and btn:IsA("GuiButton") and btn.Visible and typeof(firesignal) == "function" then
            pcall(firesignal, btn.MouseButton1Click)
        end
        task.wait(0.5)
    end
    local main = PG:FindFirstChild("Main")
    local pt = main and main:FindFirstChild("PetsTracker")
    if not pt then return false, "PetsTracker 不存在" end
    if not pt:GetAttribute("Open") then
        local tg = pt:FindFirstChild("Toggle")
        if tg and tg:IsA("GuiButton") and typeof(firesignal) == "function" then
            pcall(firesignal, tg.MouseButton1Click)
        end
        task.wait(0.6)
    end
    local pb = pt:FindFirstChild("PlaceBest")
    if not pb or not pb:IsA("GuiButton") then return false, "找不到 PlaceBest" end
    if typeof(firesignal) == "function" then
        pcall(firesignal, pb.MouseButton1Click)
        pcall(firesignal, pb.Activated)
    end
    pcall(function() pb:Activate() end)
    task.wait(1.5)
    return true, "已触发"
end

-- =====================================================================
-- 卖宠
-- =====================================================================
local function sellPets(threshold: number): (number, string)
    travelTo(SELL_COORD, 8); task.wait(0.8)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    local main = PG:FindFirstChild("Main")
    local sf: ScrollingFrame? = nil
    local t0 = tick()
    local loaded = false
    while tick() - t0 < 5 do
        local s = main and main:FindFirstChild("Sell")
        sf = s and s:FindFirstChild("ScrollingFrame") :: ScrollingFrame?
        if sf then
            for _, e in ipairs(sf:GetChildren()) do
                if isUUID(e.Name) then loaded = true; break end
            end
        end
        if loaded then break end
        task.wait(0.15)
    end
    if not loaded or not sf then return 0, "面板未加载" end
    task.wait(0.4)
    local items: { { key: string, frame: GuiObject, val: number } } = {}
    for _, entry in ipairs(sf:GetChildren()) do
        if isUUID(entry.Name) then
            for _, lb in ipairs(entry:GetDescendants()) do
                if lb:IsA("TextLabel") then
                    local ln = lb.Name:lower()
                    if ln:find("income", 1, true) or ln:find("rate", 1, true) then
                        table.insert(items, { key = entry.Name, frame = entry, val = parseInc(lb.Text) })
                        break
                    end
                end
            end
        end
    end
    if #items == 0 then return 0, "无条目" end
    table.sort(items, function(a, b) return a.val > b.val end)
    local protect: { [string]: boolean } = {}
    for i = 1, math.min(PET_LIMIT, #items) do protect[items[i].key] = true end
    local toSell: { string } = {}
    for _, it in ipairs(items) do
        if not protect[it.key] and it.val < threshold then
            local btn = it.frame:FindFirstChildOfClass("ImageButton") or it.frame:FindFirstChildOfClass("TextButton")
            if btn and typeof(firesignal) == "function" then pcall(firesignal, btn.MouseButton1Click) end
            task.wait(0.12)
            table.insert(toSell, it.key)
        end
    end
    if #toSell == 0 then return 0, "无可卖" end
    if R.SellItems then
        pcall(function() (R.SellItems :: RemoteEvent):FireServer({ Pets = toSell, Eggs = {} }) end)
    end
    task.wait(1.2)
    local conf = main and main:FindFirstChild("Confirmation")
    if conf then
        local cb = conf:FindFirstChild("Confirm")
        if cb and cb:IsA("GuiButton") and typeof(firesignal) == "function" then
            pcall(firesignal, cb.MouseButton1Click)
        end
        task.wait(0.8)
    end
    if R.ConfirmRequest then
        for _ = 1, 3 do
            local uuid = HttpService:GenerateGUID(false)
            if conf then
                local q = conf:FindFirstChild("Question")
                if q and q:IsA("TextLabel") then
                    local f = q.Text:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)")
                    if f then uuid = f end
                end
            end
            pcall(function() (R.ConfirmRequest :: RemoteEvent):FireServer(uuid, true, "Yes") end)
            task.wait(1.0)
            if not conf or not conf.Parent or not conf.Visible then break end
        end
    end
    return #toSell, "已卖"
end

-- =====================================================================
-- 喂食
-- =====================================================================
local function findFood(n: string): Tool?
    local c = LP.Character
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(n:lower(), 1, true) then return t end
        end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(n:lower(), 1, true) then return t end
        end
    end
    return nil
end

local function equipFood(n: string): boolean
    local c = LP.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    local cur = c:FindFirstChildOfClass("Tool")
    if cur and cur.Name:lower():find(n:lower(), 1, true) then return true end
    local f = findFood(n)
    if not f then return false end
    pcall(function() h:EquipTool(f) end)
    task.wait(0.15)
    local hand = c:FindFirstChildOfClass("Tool")
    return hand ~= nil and hand.Name:lower():find(n:lower(), 1, true) ~= nil
end

local function countFood(n: string): number
    local k = 0
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(n:lower(), 1, true) then k = k + 1 end
        end
    end
    local c = LP.Character
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(n:lower(), 1, true) then k = k + 1 end
        end
    end
    return k
end

local function feed(petKey: string, foodName: string, count: number): (number, string)
    if not R.FeedPet then return -1, "无 FeedPet" end
    if State.feedActive then return -1, "正在喂食" end
    State.feedActive = true
    State.feedCancel = false
    goHome(); task.wait(0.5)
    if not equipFood(foodName) then
        State.feedActive = false
        return -2, "背包无 " .. foodName
    end
    local ok, fail = 0, 0
    for _ = 1, count do
        if State.feedCancel then
            State.feedActive = false
            State.feedCancel = false
            return ok, string.format("用户停止（已喂%d）", ok)
        end
        local c = LP.Character
        local hand = c and c:FindFirstChildOfClass("Tool")
        if not hand or not hand.Name:lower():find(foodName:lower(), 1, true) then
            if not equipFood(foodName) then
                State.feedActive = false
                return ok, string.format("食物耗尽（已喂%d）", ok)
            end
        end
        local before = countFood(foodName)
        if before <= 0 then
            State.feedActive = false
            return ok, string.format("食物耗尽（已喂%d）", ok)
        end
        pcall(function() (R.FeedPet :: RemoteEvent):FireServer(petKey, foodName) end)
        task.wait(Config.feedInterval)
        local after = countFood(foodName)
        if after < before then ok = ok + 1 else fail = fail + 1 end
    end
    State.feedActive = false
    return ok, string.format("成功%d 失败%d", ok, fail)
end

local function stopFeed(): () State.feedCancel = true end

-- =====================================================================
-- 商店
-- =====================================================================
local function buy(cat: string, item: string, st: boolean): ()
    if R.Autobuy then pcall(function() (R.Autobuy :: RemoteEvent):FireServer(cat, item, st) end) end
end

local function rebirth(): ()
    if R.Rebirth then pcall(function() (R.Rebirth :: RemoteEvent):FireServer() end) end
end

local function luck(n: number): ()
    local u = UPGRADE
    if not u then return end
    for _ = 1, n do
        pcall(function() u:FireServer("Max") end)
        task.wait(Config.autoLuckInterval)
    end
end

-- =====================================================================
-- 后台自动任务
-- =====================================================================
task.spawn(function()
    while not State.stopAll do
        task.wait(Config.autoPlaceInterval)
        if Config.autoPlace then pcall(placeBest) end
    end
end)
task.spawn(function()
    while not State.stopAll do
        task.wait(Config.autoSellInterval)
        if Config.autoSell then pcall(function() sellPets(Config.sellBelow) end) end
    end
end)
task.spawn(function()
    while not State.stopAll do
        task.wait(Config.autoLuckInterval)
        if Config.autoLuck and UPGRADE then
            pcall(function() UPGRADE:FireServer("Max") end)
        end
    end
end)
task.spawn(function()
    while not State.stopAll do
        task.wait(Config.autoEggsInterval)
        if Config.autoEggs then pcall(openEggs) end
    end
end)
task.spawn(function()
    while not State.stopAll do
        task.wait(Config.autoPlaceAllInterval)
        if Config.autoPlaceAll then pcall(placeAll) end
    end
end)
task.spawn(function()
    while not State.stopAll do
        task.wait(Config.autoRebirthInterval)
        if Config.autoRebirth then
            local sd = LP:FindFirstChild("SavedData")
            local rb = sd and sd:FindFirstChild("Rebirths")
            local n = rb and (rb :: any).Value or 0
            if Config.rebirthTarget > 0 and n >= Config.rebirthTarget then
                Config.autoRebirth = false
            else
                rebirth()
            end
        end
    end
end)

-- =====================================================================
-- UI
-- =====================================================================
local Conns: { RBXScriptConnection } = {}
local dead = false

local function trk(c: RBXScriptConnection): RBXScriptConnection
    table.insert(Conns, c)
    return c
end

local function mk(cls: string, props: { [string]: any }?, kids: { Instance }?): Instance
    local inst = Instance.new(cls)
    local parent: Instance? = nil
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then parent = v
            else pcall(function() (inst :: any)[k] = v end) end
        end
    end
    if kids then for _, c in ipairs(kids) do c.Parent = inst end end
    if parent then inst.Parent = parent end
    return inst
end

local function styledText(props: { [string]: any }): TextLabel
    local c = props.TextColor3 :: Color3? or Th.Txt
    props.TextColor3 = c
    props.TextStrokeColor3 = strokeOf(c)
    props.TextStrokeTransparency = 0.5
    return mk("TextLabel", props) :: TextLabel
end

local gpc: Instance? = nil
local function guiP(): Instance
    if gpc and gpc.Parent then return gpc :: Instance end
    if typeof(gethui) == "function" then
        local ok, r = pcall(gethui)
        if ok and r and typeof(r) == "Instance" then
            local ok2 = pcall(function()
                local t = Instance.new("Folder"); t.Parent = r; t:Destroy()
            end)
            if ok2 then gpc = r; return r end
        end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        local ok2 = pcall(function()
            local t = Instance.new("Folder"); t.Parent = cg; t:Destroy()
        end)
        if ok2 then gpc = cg; return cg end
    end
    gpc = PG
    return PG
end

local OpRegs: { { f: GuiObject, kind: string } } = {}
local function regOp(f: GuiObject, kind: string): ()
    table.insert(OpRegs, { f = f, kind = kind })
end
local function applyOp(): ()
    for _, r in ipairs(OpRegs) do
        if r.f.Parent then
            local a = (r.kind == "bg") and Config.opacityBg or Config.opacityPanel
            r.f.BackgroundTransparency = 1 - a
        end
    end
end

-- 通知
local notifGui = mk("ScreenGui", {
    Name = "EggMasterNotif", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999999,
})
notifGui.Parent = guiP()

local notifHolder = mk("Frame", {
    Name = "NH", AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -20, 1, -20),
    Size = UDim2.fromOffset(300, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, Parent = notifGui,
})
mk("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, G),
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    Parent = notifHolder,
})

local nc = 0
local function Notify(title: string, msg: string?, dur: number?, color: Color3?): ()
    if dead then return end
    nc = nc + 1
    local n = nc
    local card = mk("Frame", {
        Name = "C" .. n, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Th.Sur, BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = n, Parent = notifHolder,
    })
    local st = mk("UIStroke", { Color = color or Th.Str, Thickness = 1, Transparency = 1, Parent = card })
    mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = card,
    })
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3), Parent = card,
    })
    local tL = styledText({
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Font = FB, TextSize = 15,
        TextColor3 = color or Th.Txt, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Text = title, TextTransparency = 1,
        LayoutOrder = 1, Parent = card,
    })
    local mL = styledText({
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Font = FR, TextSize = 14,
        TextColor3 = Th.Sub, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Text = msg or "", TextTransparency = 1,
        LayoutOrder = 2, Parent = card,
    })
    local fi = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(card, fi, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(st, fi, { Transparency = 0 }):Play()
    TweenService:Create(tL, fi, { TextTransparency = 0 }):Play()
    TweenService:Create(mL, fi, { TextTransparency = 0 }):Play()
    task.delay(dur or 3, function()
        if dead or not card.Parent then return end
        local fo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(card, fo, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(st, fo, { Transparency = 1 }):Play()
        TweenService:Create(tL, fo, { TextTransparency = 1 }):Play()
        TweenService:Create(mL, fo, { TextTransparency = 1 }):Play()
        task.delay(0.45, function()
            if not dead and card.Parent then card:Destroy() end
        end)
    end)
end

-- 主面板
local SG = mk("ScreenGui", {
    Name = "EggMasterV54", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
})
SG.Parent = guiP()

local Main = mk("Frame", {
    Name = "Main",
    Position = UDim2.new(0.5, -Config.winW / 2, 0.5, -Config.winH / 2),
    Size = UDim2.fromOffset(Config.winW, Config.winH),
    BackgroundColor3 = Th.Bg, BorderSizePixel = 0,
    Active = true, ClipsDescendants = true, Parent = SG,
})
mk("UICorner", { CornerRadius = UDim.new(0, 10), Parent = Main })
mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = Main })
regOp(Main, "bg")

local TBar = mk("Frame", {
    Name = "TBar", Size = UDim2.new(1, 0, 0, TITLE_H),
    BackgroundColor3 = Th.Sur, BorderSizePixel = 0, Active = true, Parent = Main,
})
mk("UICorner", { CornerRadius = UDim.new(0, 10), Parent = TBar })
styledText({
    Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(G * 2, 0),
    BackgroundTransparency = 1, Font = FB, TextSize = SZ_TITLE,
    TextColor3 = Th.Txt, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "EggMaster V54", Parent = TBar,
})

local MinBtn = mk("TextButton", {
    Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -60, 0.5, -13),
    BackgroundColor3 = Th.Bg, BorderSizePixel = 0, AutoButtonColor = true,
    Font = FB, TextSize = 16, TextColor3 = Th.Sub, Text = "—", Parent = TBar,
})
mk("UICorner", { CornerRadius = UDim.new(0, 6), Parent = MinBtn })
mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = MinBtn })

local CloseBtn = mk("TextButton", {
    Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -32, 0.5, -13),
    BackgroundColor3 = Th.Bg, BorderSizePixel = 0, AutoButtonColor = true,
    Font = FB, TextSize = 15, TextColor3 = Th.Err, Text = "X", Parent = TBar,
})
mk("UICorner", { CornerRadius = UDim.new(0, 6), Parent = CloseBtn })
mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = CloseBtn })

local function bodyH(): number return Config.winH - TITLE_H - TIPS_H end

local Sidebar = mk("Frame", {
    Position = UDim2.fromOffset(G, TITLE_H),
    Size = UDim2.fromOffset(SBAR_W, bodyH()),
    BackgroundColor3 = Th.Sec, BorderSizePixel = 0, Active = true, Parent = Main,
})
mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Sidebar })
mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = Sidebar })
regOp(Sidebar, "panel")
mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Sidebar })
mk("UIPadding", {
    PaddingTop = UDim.new(0, G), PaddingLeft = UDim.new(0, G),
    PaddingRight = UDim.new(0, G), PaddingBottom = UDim.new(0, G), Parent = Sidebar,
})

local Content = mk("Frame", {
    Position = UDim2.fromOffset(G + SBAR_W + G, TITLE_H),
    Size = UDim2.new(1, -(G + SBAR_W + G * 2), 0, bodyH()),
    BackgroundTransparency = 1, Active = true, Parent = Main,
})

local TipsBar = mk("Frame", {
    Position = UDim2.new(0, 0, 1, -TIPS_H),
    Size = UDim2.new(1, 0, 0, TIPS_H),
    BackgroundColor3 = Th.Sec, BorderSizePixel = 0, Active = true, Parent = Main,
})
mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = TipsBar })
mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = TipsBar })
regOp(TipsBar, "panel")
local TipsLbl = styledText({
    Size = UDim2.new(1, -G * 2, 1, 0), Position = UDim2.fromOffset(G, 0),
    BackgroundTransparency = 1, Font = FR, TextSize = SZ_TIP,
    TextColor3 = Th.Txt, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "就绪", Parent = TipsBar,
})

local RH = mk("Frame", {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4),
    Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Th.Hdl,
    BackgroundTransparency = 0.15, BorderSizePixel = 0, Active = true, Parent = Main,
})
mk("UICorner", { CornerRadius = UDim.new(0, 3), Parent = RH })

local Pages: { [string]: ScrollingFrame } = {}
local TabRecs: { [string]: { btn: TextButton, ind: Frame } } = {}

local switchTab: (name: string) -> () = nil :: any
local ClosePopup: () -> () = nil :: any

local function doSwitch(name: string): ()
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, r in pairs(TabRecs) do
        local sel = (n == name)
        r.btn.BackgroundTransparency = sel and 0 or 1
        r.btn.BackgroundColor3 = sel and Th.Acc or Th.Sur
        r.btn.TextColor3 = sel and Color3.new(1, 1, 1) or Th.Sub
        r.ind.Visible = sel
    end
    if ClosePopup then ClosePopup() end
end
switchTab = doSwitch

local function makeTab(name: string, label: string, order: number): ScrollingFrame
    local page = mk("ScrollingFrame", {
        Name = name .. "Page", BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 4, ScrollBarImageColor3 = Th.Str,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingEnabled = true, Active = true, Visible = false, Parent = Content,
    })
    mk("UIListLayout", { Padding = UDim.new(0, G), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
    mk("UIPadding", { PaddingRight = UDim.new(0, G), PaddingBottom = UDim.new(0, G), Parent = page })
    Pages[name] = page

    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Th.Sur, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Font = FS, TextSize = 15, TextColor3 = Th.Sub,
        Text = label, TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = order, Parent = Sidebar,
    })
    mk("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
    local ind = mk("Frame", {
        BackgroundColor3 = Th.Acc, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.new(0, 3, 0.5, 0), Visible = false, Parent = btn,
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ind })
    TabRecs[name] = { btn = btn, ind = ind }
    trk(btn.MouseButton1Click:Connect(function() switchTab(name) end))
    return page
end

-- =====================================================================
-- 组件
-- =====================================================================
local function SectionTitle(parent: Instance, text: string): ()
    styledText({
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
        Font = FS, TextSize = SZ_SECTION, TextColor3 = Th.Txt,
        TextXAlignment = Enum.TextXAlignment.Left, Text = text, Parent = parent,
    })
end

local function Card(parent: Instance, order: number, title: string?): (Frame, UIListLayout)
    local wrap = mk("Frame", {
        Name = "CardWrap", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order, Parent = parent,
    })
    mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wrap })
    if title then
        local th = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Th.CardTitle,
            BorderSizePixel = 0, LayoutOrder = 0, Active = true, Parent = wrap,
        })
        mk("UICorner", { CornerRadius = UDim.new(0, 6), Parent = th })
        mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = th })
        styledText({
            Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(12, 0),
            BackgroundTransparency = 1, Font = FS, TextSize = SZ_SECTION,
            TextColor3 = Th.Txt, TextXAlignment = Enum.TextXAlignment.Left,
            Text = title, Parent = th,
        })
    end
    local c = mk("Frame", {
        Name = "Card", BackgroundColor3 = Th.Card, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1, Active = true, Parent = wrap,
    })
    mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = c })
    mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = c })
    regOp(c, "panel")
    local lay = mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
    mk("UIPadding", {
        PaddingTop = UDim.new(0, G), PaddingBottom = UDim.new(0, G),
        PaddingLeft = UDim.new(0, G + 2), PaddingRight = UDim.new(0, G + 2), Parent = c,
    })
    return c, lay
end

local function Tip(parent: Instance, text: string, order: number): ()
    styledText({
        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
        Font = FR, TextSize = SZ_TIP, TextColor3 = Th.Sub,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        Text = text, LayoutOrder = order, Parent = parent,
    })
end

-- ★ 按钮：暗底 + 灰描边 + 彩色文字
local function Button(parent: Instance, text: string, color: Color3, order: number, cb: () -> ()): TextButton
    local b = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Th.Sur, BorderSizePixel = 0, AutoButtonColor = true,
        Font = FS, TextSize = SZ_ITEM, TextColor3 = color,
        TextStrokeColor3 = strokeOf(color), TextStrokeTransparency = 0.6,
        Text = text, LayoutOrder = order, Parent = parent,
    })
    mk("UICorner", { CornerRadius = UDim.new(0, 6), Parent = b })
    mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = b })
    trk(b.MouseButton1Click:Connect(function() task.spawn(cb) end))
    return b
end

local function Toggle(parent: Instance, text: string, value: boolean, order: number, cb: (boolean) -> ()): ()
    local row = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, LayoutOrder = order, Parent = parent,
    })
    styledText({
        Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1,
        Font = FS, TextSize = SZ_ITEM, TextColor3 = Th.Txt,
        TextXAlignment = Enum.TextXAlignment.Left, Text = text, Parent = row,
    })
    local pill = mk("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(48, 26),
        BackgroundColor3 = value and Th.Ok or Th.Str,
        BorderSizePixel = 0, Parent = row,
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
    mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = pill })
    local knob = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = value and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = pill,
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
    local s = value
    trk(row.MouseButton1Click:Connect(function()
        s = not s
        pill.BackgroundColor3 = s and Th.Ok or Th.Str
        knob.Position = s and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 14, 0.5, 0)
        cb(s)
    end))
end

local function Input(parent: Instance, text: string, value: string, order: number, cb: (string) -> ()): ()
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
        LayoutOrder = order, Parent = parent,
    })
    styledText({
        Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1,
        Font = FS, TextSize = SZ_ITEM, TextColor3 = Th.Txt,
        TextXAlignment = Enum.TextXAlignment.Left, Text = text, Parent = row,
    })
    local box = mk("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0.45, 0, 1, 0),
        BackgroundColor3 = Th.Bg, BorderSizePixel = 0,
        Font = FR, TextSize = 15, TextColor3 = Th.Txt,
        Text = value, ClearTextOnFocus = false, Parent = row,
    })
    mk("UICorner", { CornerRadius = UDim.new(0, 6), Parent = box })
    mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = box })
    trk(box.FocusLost:Connect(function() cb(box.Text) end))
end

local function Slider(parent: Instance, text: string, value: number, minV: number, maxV: number, order: number, cb: (number) -> ()): ()
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1,
        LayoutOrder = order, Parent = parent,
    })
    styledText({
        Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1, Font = FS, TextSize = SZ_ITEM,
        TextColor3 = Th.Txt, TextXAlignment = Enum.TextXAlignment.Left,
        Text = text, Parent = row,
    })
    local vLbl = styledText({
        Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1, Font = FR, TextSize = 14,
        TextColor3 = Th.Sub, TextXAlignment = Enum.TextXAlignment.Right,
        Text = string.format("%.2f", value), Parent = row,
    })
    local track = mk("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -4),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Th.Bg, BorderSizePixel = 0, Active = true, Parent = row,
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = track })
    local function toF(v: number): number return cl((v - minV) / (maxV - minV), 0, 1) end
    local function fromF(f: number): number return minV + f * (maxV - minV) end
    local fill = mk("Frame", {
        Size = UDim2.new(toF(value), 0, 1, 0),
        BackgroundColor3 = Th.Acc, BorderSizePixel = 0, Parent = track,
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
    local handle = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(toF(value), 0, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track,
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = handle })
    mk("UIStroke", { Color = Th.Acc, Thickness = 2, Parent = handle })
    local drag = false
    local function updateAt(mx: number): ()
        local ap = track.AbsolutePosition
        local as = track.AbsoluteSize
        local f = cl((mx - ap.X) / as.X, 0, 1)
        local v = fromF(f)
        fill.Size = UDim2.new(f, 0, 1, 0)
        handle.Position = UDim2.new(f, 0, 0.5, 0)
        vLbl.Text = string.format("%.2f", v)
        cb(v)
    end
    trk(track.InputBegan:Connect(function(i: InputObject)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            updateAt(i.Position.X)
        end
    end))
    trk(UserInputService.InputChanged:Connect(function(i: InputObject)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch then
            updateAt(i.Position.X)
        end
    end))
    trk(UserInputService.InputEnded:Connect(function(i: InputObject)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end))
end

local function RarityToggle(parent: Instance, r: Rarity, value: boolean, order: number, cb: (boolean) -> ()): ()
    local rule = RAR[r]
    local row = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        LayoutOrder = order, Parent = parent,
    })
    local lbl = styledText({
        Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1,
        Font = FS, TextSize = SZ_ITEM, TextColor3 = rule.color,
        TextXAlignment = Enum.TextXAlignment.Left, Text = rule.label, Parent = row,
    })
    local pill = mk("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(48, 26),
        BackgroundColor3 = value and rule.color or Th.Str,
        BorderSizePixel = 0, Parent = row,
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
    mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = pill })
    local knob = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = value and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = pill,
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
    local s = value
    local function render()
        pill.BackgroundColor3 = s and rule.color or Th.Str
        knob.Position = s and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 14, 0.5, 0)
        lbl.TextTransparency = s and 0 or 0.35
    end
    render()
    trk(row.MouseButton1Click:Connect(function()
        s = not s
        render()
        cb(s)
    end))
end

-- 下拉框
local openPopup: Frame? = nil
local openDisplay: TextButton? = nil

ClosePopup = function(): ()
    if openPopup then
        openPopup.Visible = false
        openPopup = nil
        openDisplay = nil
    end
end

local function Dropdown(parent: Instance, text: string, values: { string }, value: string, order: number, cb: (string) -> ()): { refresh: ({ string }) -> () }
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
        LayoutOrder = order, Parent = parent,
    })
    styledText({
        Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1,
        Font = FS, TextSize = SZ_ITEM, TextColor3 = Th.Txt,
        TextXAlignment = Enum.TextXAlignment.Left, Text = text, Parent = row,
    })
    local disp = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0.45, 0, 1, 0),
        BackgroundColor3 = Th.Bg, BorderSizePixel = 0,
        Font = FR, TextSize = 14, TextColor3 = Th.Txt,
        TextStrokeColor3 = strokeOf(Th.Txt), TextStrokeTransparency = 0.5,
        Text = value, TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = true, Parent = row,
    })
    mk("UICorner", { CornerRadius = UDim.new(0, 6), Parent = disp })
    mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = disp })

    local popup = mk("Frame", {
        BackgroundColor3 = Th.Card, BorderSizePixel = 0,
        Size = UDim2.fromOffset(180, 120), Visible = false,
        ZIndex = 1000, Active = true, Parent = Main,
    })
    mk("UICorner", { CornerRadius = UDim.new(0, 6), Parent = popup })
    mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = popup })

    local list = mk("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 4, ScrollBarImageColor3 = Th.Str,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingEnabled = true, Active = true, ZIndex = 1000, Parent = popup,
    })
    mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = list,
    })

    local curVal = value
    local curVals = values

    local function rebuild(): ()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, v in ipairs(curVals) do
            local opt = mk("TextButton", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = (v == curVal) and Th.Acc or Th.Card,
                BorderSizePixel = 0, Font = FR, TextSize = 14,
                TextColor3 = Th.Txt,
                TextStrokeColor3 = strokeOf(Th.Txt), TextStrokeTransparency = 0.5,
                Text = v, TextTruncate = Enum.TextTruncate.AtEnd,
                AutoButtonColor = true, LayoutOrder = i,
                ZIndex = 1000, Parent = list,
            })
            mk("UICorner", { CornerRadius = UDim.new(0, 4), Parent = opt })
            mk("UIStroke", { Color = Th.Str, Thickness = 1, Parent = opt })
            trk(opt.MouseButton1Click:Connect(function()
                curVal = v
                disp.Text = v
                ClosePopup()
                cb(v)
            end))
        end
    end

    trk(disp.MouseButton1Click:Connect(function()
        if openPopup == popup then ClosePopup(); return end
        ClosePopup()
        rebuild()
        local ap = disp.AbsolutePosition
        local as = disp.AbsoluteSize
        local mp = Main.AbsolutePosition
        local mainH = Main.AbsoluteSize.Y
        local itemCount = #curVals
        local desiredH = math.min(itemCount * 30 + 8, 200)
        local nx = ap.X - mp.X
        local ny = ap.Y - mp.Y + as.Y + 4
        if ny + desiredH > mainH then
            ny = ap.Y - mp.Y - desiredH - 4
        end
        popup.Position = UDim2.fromOffset(nx, ny)
        popup.Size = UDim2.fromOffset(math.max(as.X, 180), desiredH)
        popup.Visible = true
        openPopup = popup
        openDisplay = disp
    end))

    return {
        refresh = function(vs: { string })
            if #vs == #curVals then
                local same = true
                for i = 1, #vs do
                    if vs[i] ~= curVals[i] then same = false; break end
                end
                if same then return end
            end
            curVals = vs
            local found = false
            for _, v in ipairs(curVals) do
                if v == curVal then found = true; break end
            end
            if not found then
                curVal = curVals[1] or "(未选)"
                disp.Text = curVal
                cb(curVal)
            end
            if popup.Visible then rebuild() end
        end,
    }
end

-- 每帧跟随下拉
trk(RunService.RenderStepped:Connect(function()
    if not openPopup or not openDisplay then return end
    if not openDisplay.Parent then ClosePopup(); return end
    if not openDisplay:IsDescendantOf(Main) then ClosePopup(); return end
    local ap = openDisplay.AbsolutePosition
    local as = openDisplay.AbsoluteSize
    local mp = Main.AbsolutePosition
    local nx = ap.X - mp.X
    local ny = ap.Y - mp.Y + as.Y + 4
    local mainH = Main.AbsoluteSize.Y
    local dh = openPopup.AbsoluteSize.Y
    if ny + dh > mainH then
        local upY = ap.Y - mp.Y - dh - 4
        if upY > 0 then ny = upY end
    end
    openPopup.Position = UDim2.fromOffset(nx, ny)
end))

-- 点击任意位置关闭下拉（不检查 processed）
trk(UserInputService.InputBegan:Connect(function(input: InputObject)
    if not openPopup then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local m = UserInputService:GetMouseLocation()
    local function inRect(g: GuiObject): boolean
        local p = g.AbsolutePosition
        local s = g.AbsoluteSize
        return m.X >= p.X and m.X <= p.X + s.X
            and m.Y >= p.Y and m.Y <= p.Y + s.Y
    end
    if openDisplay and inRect(openDisplay) then return end
    if inRect(openPopup) then return end
    ClosePopup()
end))

-- =====================================================================
-- 页面
-- =====================================================================

-- 主页
local mainPage = makeTab("main", "主页", 1)
do
    local order = 0
    order += 1
    SectionTitle(mainPage, "自动任务")
    order += 1
    local c = Card(mainPage, order, "核心开关")
    Toggle(c, "自动偷蛋", Config.autoSteal, 1, function(v: boolean)
        Config.autoSteal = v
        if v then startSteal() else stopSteal() end
    end)
    Toggle(c, "送蛋模式", Config.mode == "deliver", 2, function(v: boolean)
        Config.mode = v and "deliver" or "steal"
    end)
    Toggle(c, "自动开蛋", Config.autoEggs, 3, function(v: boolean)
        Config.autoEggs = v
    end)

    order += 1
    local c2 = Card(mainPage, order, "送蛋目标玩家")
    local pdd: { refresh: ({ string }) -> () }
    pdd = Dropdown(c2, "目标", { "(未选)" }, "(未选)", 1, function(v: string)
        local un = v:match("@([%w_]+)")
        if un then
            Config.targetPlayerName = un
            Config.mode = "deliver"
        else
            Config.targetPlayerName = nil
        end
    end)
    Tip(c2, "选目标后自动切送蛋模式", 2)

    local function refreshPlayers(): ()
        local names: { string } = { "(未选)" }
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                table.insert(names, string.format("%s (@%s)", p.DisplayName, p.Name))
            end
        end
        pdd.refresh(names)
    end
    trk(Players.PlayerAdded:Connect(function() task.wait(0.2); refreshPlayers() end))
    trk(Players.PlayerRemoving:Connect(function() task.wait(0.2); refreshPlayers() end))
    task.spawn(function()
        while not State.stopAll do
            task.wait(0.5)
            pcall(refreshPlayers)
        end
    end)

    order += 1
    SectionTitle(mainPage, "偷蛋稀有度")
    order += 1
    local c3 = Card(mainPage, order, "筛选")
    for i, r in ipairs(ORDER) do
        RarityToggle(c3, r, Config.stealEnabled[r], i, function(v: boolean)
            Config.stealEnabled[r] = v
        end)
    end

    order += 1
    SectionTitle(mainPage, "被抢判定")
    order += 1
    local c4 = Card(mainPage, order, "阈值")
    Input(c4, "移动阈值 (studs)", tostring(Config.eggMoveThreshold), 1, function(s: string)
        local n = tonumber(s)
        if n and n >= 1 and n <= 50 then Config.eggMoveThreshold = n end
    end)
end

-- 光柱
local pillarPage = makeTab("pillar", "光柱", 2)
do
    local order = 0
    order += 1
    SectionTitle(pillarPage, "光柱显示（三个独立开关）")
    order += 1
    local c = Card(pillarPage, order, "独立开关")
    Toggle(c, "显示光柱（透视）", Config.showPillar, 1, function(v: boolean)
        Config.showPillar = v
        if v then
            syncPillars()
        else
            -- 只清 Part，不动 Billboard
            for m in pairs(modelToPart) do
                local p = modelToPart[m]
                if p then p:Destroy() end
                modelToPart[m] = nil
            end
        end
    end)
    Toggle(c, "显示悬浮文字", Config.showBillboard, 2, function(v: boolean)
        Config.showBillboard = v
        if v then
            syncPillars()
        else
            for m in pairs(modelToBB) do
                local b = modelToBB[m]
                if b then b:Destroy() end
                modelToBB[m] = nil
            end
        end
    end)
    Toggle(c, "显示稀有度数值", Config.showRarityValue, 3, function(v: boolean)
        Config.showRarityValue = v
        -- 重建所有 billboard（重新生成时 n2 才会出现或消失）
        for m in pairs(modelToBB) do
            local b = modelToBB[m]
            if b then b:Destroy() end
            modelToBB[m] = nil
        end
        if Config.showBillboard then syncPillars() end
    end)
    Tip(c, "光柱 = 透视柱体，文字 = 悬浮标签，数值 = 稀有度数字", 4)

    order += 1
    SectionTitle(pillarPage, "光柱稀有度")
    order += 1
    local c2 = Card(pillarPage, order, "筛选")
    for i, r in ipairs(ORDER) do
        RarityToggle(c2, r, Config.pillarEnabled[r], i, function(v: boolean)
            Config.pillarEnabled[r] = v
            -- 逐个清理
            for m in pairs(modelToPart) do
                local p = modelToPart[m]
                if p then p:Destroy() end
                modelToPart[m] = nil
            end
            for m in pairs(modelToBB) do
                local b = modelToBB[m]
                if b then b:Destroy() end
                modelToBB[m] = nil
            end
            if Config.showPillar or Config.showBillboard then
                syncPillars()
            end
        end)
    end
end

-- 树木
local treePage = makeTab("tree", "树木", 3)
do
    local order = 0
    order += 1
    SectionTitle(treePage, "树木处理")
    order += 1
    local c = Card(treePage, order, "操作")
    Button(c, "关闭", Th.Sub, 1, function()
        if Config.treeMode == "hide" then restoreTrees() end
        Config.treeMode = "off"
    end)
    Button(c, "隐藏", Th.Acc, 2, function()
        Config.treeMode = "hide"
        task.defer(applyTree)
    end)
    local armed = false
    Button(c, "删除（二次确认）", Th.Err, 3, function()
        if not armed then
            armed = true
            Notify("树木", "再点一次确认删除", 2, Th.Warn)
            task.delay(3, function() armed = false end)
            return
        end
        armed = false
        if Config.treeMode == "hide" then restoreTrees() end
        Config.treeMode = "delete"
        task.defer(applyTree)
    end)
    Button(c, "还原", Th.Ok, 4, function()
        Config.treeMode = "off"
        restoreTrees()
    end)
end

-- 蛋
local eggPage = makeTab("egg", "蛋", 4)
do
    local order = 0
    order += 1
    SectionTitle(eggPage, "放蛋品质")
    order += 1
    local c = Card(eggPage, order, "筛选")
    for i, r in ipairs(ORDER) do
        RarityToggle(c, r, Config.plantRarity[r], i, function(v: boolean)
            Config.plantRarity[r] = v
        end)
    end

    order += 1
    SectionTitle(eggPage, "放蛋网格")
    order += 1
    local c2 = Card(eggPage, order, "参数")
    Input(c2, "列数", tostring(Config.plantCols), 1, function(s: string)
        local n = tonumber(s)
        if n and n >= 1 and n <= 10 then Config.plantCols = n end
    end)
    Input(c2, "行数", tostring(Config.plantRows), 2, function(s: string)
        local n = tonumber(s)
        if n and n >= 1 and n <= 10 then Config.plantRows = n end
    end)
    Input(c2, "间距", tostring(Config.plantSpacing), 3, function(s: string)
        local n = tonumber(s)
        if n and n >= 5 and n <= 30 then Config.plantSpacing = n end
    end)

    order += 1
    SectionTitle(eggPage, "操作")
    order += 1
    local c3 = Card(eggPage, order, "执行")
    Toggle(c3, "自动放蛋", Config.autoPlaceAll, 1, function(v: boolean) Config.autoPlaceAll = v end)
    Input(c3, "自动放蛋间隔", tostring(Config.autoPlaceAllInterval), 2, function(s: string)
        local n = tonumber(s)
        if n and n >= 1 then Config.autoPlaceAllInterval = n end
    end)
    Button(c3, "🥚 立即放蛋", Th.Acc, 3, function()
        local n, msg = placeAll()
        Notify("放蛋", msg .. " (" .. n .. ")", 4, Th.Ok)
    end)
    Button(c3, "🥚 一键开家蛋", Th.Teal, 4, function()
        local n = openEggs()
        Notify("开蛋", "开了 " .. n .. " 个", 3, Th.Ok)
    end)
    Input(c3, "自动开蛋间隔", tostring(Config.autoEggsInterval), 5, function(s: string)
        local n = tonumber(s)
        if n and n >= 1 then Config.autoEggsInterval = n end
    end)
end

-- 拿蛋
local grabPage = makeTab("grab", "拿蛋", 5)
do
    local order = 0
    order += 1
    SectionTitle(grabPage, "拿蛋方式")
    order += 1
    local c = Card(grabPage, order, "三路齐发")
    Toggle(c, "InputHoldBegin", Config.grabHoldBegin, 1, function(v: boolean) Config.grabHoldBegin = v end)
    Toggle(c, "fireproximityprompt", Config.grabFirePrompt, 2, function(v: boolean) Config.grabFirePrompt = v end)
    Toggle(c, "E 键模拟", Config.grabEKey, 3, function(v: boolean) Config.grabEKey = v end)
    Tip(c, "三种方式同时触发，独立开关", 4)

    order += 1
    SectionTitle(grabPage, "进度条等待")
    order += 1
    local c2 = Card(grabPage, order, "额外等待")
    Input(c2, "额外等待（秒）", string.format("%.1f", Config.grabHoldExtra), 1, function(s: string)
        local n = tonumber(s)
        if n and n >= 0.3 and n <= 3 then Config.grabHoldExtra = n end
    end)
    Tip(c2, "HoldDuration 之外额外等，默认 0.6s", 2)
end

-- 宠物
local petPage = makeTab("pet", "宠物", 6)
do
    local order = 0
    order += 1
    SectionTitle(petPage, "放最佳")
    order += 1
    local c = Card(petPage, order, "自动放最佳")
    Toggle(c, "自动放最佳", Config.autoPlace, 1, function(v: boolean) Config.autoPlace = v end)
    Input(c, "间隔（秒）", tostring(Config.autoPlaceInterval), 2, function(s: string)
        local n = tonumber(s)
        if n and n >= 1 then Config.autoPlaceInterval = n end
    end)
    Button(c, "🏆 立即放最佳", Th.Acc, 3, function()
        local ok, msg = placeBest()
        Notify("放最佳", tostring(msg), 3, ok and Th.Ok or Th.Err)
    end)

    order += 1
    SectionTitle(petPage, "卖宠")
    order += 1
    local c2 = Card(petPage, order, "自动卖宠")
    Toggle(c2, "自动卖宠", Config.autoSell, 1, function(v: boolean) Config.autoSell = v end)
    Input(c2, "间隔（秒）", tostring(Config.autoSellInterval), 2, function(s: string)
        local n = tonumber(s)
        if n and n >= 1 then Config.autoSellInterval = n end
    end)
    Input(c2, "收益阈值", tostring(Config.sellBelow), 3, function(s: string)
        Config.sellBelow = tonumber(s) or 0
    end)
    Button(c2, "💸 立即卖宠", Th.Ok, 4, function()
        local n, msg = sellPets(Config.sellBelow)
        Notify("卖宠", msg .. " (" .. n .. ")", 3, Th.Ok)
    end)

    order += 1
    SectionTitle(petPage, "喂食")
    order += 1
    local c3 = Card(petPage, order, "自动喂食")
    local feedMap: { [string]: string } = {}
    local fdd: { refresh: ({ string }) -> () }
    fdd = Dropdown(c3, "目标宠物", { "(暂无)" }, "(未选)", 1, function(v: string) Config.feedPet = v end)

    local function refreshFeed(): ()
        table.clear(feedMap)
        local names: { string } = {}
        local plot = myPlot()
        local pets = plot and plot:FindFirstChild("Pets")
        if pets then
            for _, pet in ipairs(pets:GetChildren()) do
                local nm = pet:GetAttribute("PetName") or pet.Name
                local key = pet:GetAttribute("PetKey")
                local age = pet:GetAttribute("Age") or 0
                local d = string.format("%s Lv.%d", nm, age)
                table.insert(names, d)
                if type(key) == "string" then feedMap[d] = key end
            end
        end
        if #names == 0 then names = { "(暂无)" } end
        fdd.refresh(names)
    end

    Button(c3, "🔄 刷新宠物列表", Th.Sub, 2, refreshFeed)
    task.spawn(function()
        while not State.stopAll do
            task.wait(2)
            pcall(refreshFeed)
        end
    end)

    Dropdown(c3, "食物",
        { "Grass", "Bone", "Meat", "Magic Apple", "Dragonfruit" },
        Config.feedFood, 3, function(v: string) Config.feedFood = v end)
    Input(c3, "次数", Config.feedCount, 4, function(s: string) Config.feedCount = s end)
    Input(c3, "每次间隔（秒）", string.format("%.1f", Config.feedInterval), 5, function(s: string)
        local n = tonumber(s)
        if n and n >= 0.1 and n <= 5 then Config.feedInterval = n end
    end)
    Button(c3, "🍖 执行喂食", Th.Warn, 6, function()
        local key = feedMap[Config.feedPet]
        if not key then Notify("喂食", "请先选宠物", 3, Th.Warn); return end
        local cnt = tonumber(Config.feedCount) or 10
        local n, msg = feed(key, Config.feedFood, cnt)
        Notify("喂食", msg .. " (" .. n .. ")", 3, Th.Ok)
    end)
    Button(c3, "⏸️ 暂停喂食", Th.Err, 7, stopFeed)
end

-- 商店
local shopPage = makeTab("shop", "商店", 7)
do
    local order = 0
    order += 1
    SectionTitle(shopPage, "自动购买-食物")
    order += 1
    local c = Card(shopPage, order, "食物")
    for i, item in ipairs({ "Grass", "Bone", "Magic Apple", "Dragonfruit" }) do
        Toggle(c, item, false, i, function(v: boolean) buy("Food", item, v) end)
    end
    order += 1
    SectionTitle(shopPage, "自动购买-装备")
    order += 1
    local c2 = Card(shopPage, order, "装备")
    for i, item in ipairs({
        "Advanced Radar", "Jewel Radar", "Royal Radar", "Magic Radar",
        "Angelic Radar", "Eternal Radar", "NameTag",
    }) do
        Toggle(c2, item, false, i, function(v: boolean) buy("Gears", item, v) end)
    end
    order += 1
    SectionTitle(shopPage, "重生 / 幸运")
    order += 1
    local c3 = Card(shopPage, order, "重生")
    Toggle(c3, "自动重生", Config.autoRebirth, 1, function(v: boolean) Config.autoRebirth = v end)
    Input(c3, "重生检查间隔", tostring(Config.autoRebirthInterval), 2, function(s: string)
        local n = tonumber(s)
        if n and n >= 1 then Config.autoRebirthInterval = n end
    end)
    Input(c3, "目标次数 (0=无限)", tostring(Config.rebirthTarget), 3, function(s: string)
        Config.rebirthTarget = tonumber(s) or 0
    end)
    Button(c3, "立即重生", Th.Purple, 4, rebirth)
    Toggle(c3, "自动拉满幸运", Config.autoLuck, 5, function(v: boolean) Config.autoLuck = v end)
    Input(c3, "幸运间隔（秒）", string.format("%.2f", Config.autoLuckInterval), 6, function(s: string)
        local n = tonumber(s)
        if n and n >= 0.1 and n <= 5 then Config.autoLuckInterval = n end
    end)
    Button(c3, "拉满 1 次", Th.Purple, 7, function() luck(1) end)
    Button(c3, "拉满 10 次", Th.Purple, 8, function() luck(10) end)
    Button(c3, "拉满 50 次", Th.Purple, 9, function() luck(50) end)
end

-- 信息
local infoPage = makeTab("info", "信息", 8)
do
    local order = 0
    order += 1
    SectionTitle(infoPage, "状态")
    order += 1
    local c, _ = Card(infoPage, order, "实时状态")
    local infoLbl = styledText({
        Size = UDim2.new(1, 0, 0, 180), BackgroundTransparency = 1,
        Font = FR, TextSize = 13, TextColor3 = Th.Txt,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, Text = "加载中...", LayoutOrder = 1, Parent = c,
    })
    task.spawn(function()
        while not State.stopAll do
            task.wait(1)
            pcall(function()
                local eggs = collect()
                local nP = 0
                for _ in pairs(modelToPart) do nP = nP + 1 end
                local nB = 0
                for _ in pairs(modelToBB) do nB = nB + 1 end
                local home = findBasket(LP)
                infoLbl.Text = string.format(
                    "持蛋: %s\n"
                    .. "公共蛋: %d\n"
                    .. "光柱 Part: %d | Billboard: %d\n"
                    .. "模式: %s | 目标: %s\n"
                    .. "状态: %s\n"
                    .. "家位置: %s",
                    State.holding and "是" or "否",
                    #eggs,
                    nP, nB,
                    Config.mode, Config.targetPlayerName or "(未选)",
                    State.stealStatus,
                    home and string.format("(%.0f, %.0f)", home.Position.X, home.Position.Z) or "?"
                )
            end)
        end
    end)
end

-- 设置
local setPage = makeTab("settings", "设置", 9)
do
    local order = 0
    order += 1
    SectionTitle(setPage, "速度")
    order += 1
    local c = Card(setPage, order, "传送速度")
    Input(c, "传送速度", tostring(Config.transportSpeed), 1, function(s: string)
        local n = tonumber(s)
        if n and n > 5 then Config.transportSpeed = n end
    end)
    Input(c, "紧急速度", tostring(Config.emergencySpeed), 2, function(s: string)
        local n = tonumber(s)
        if n and n > 10 then Config.emergencySpeed = n end
    end)
    Toggle(c, "紧急模式", Config.emergencyEnabled, 3, function(v: boolean) Config.emergencyEnabled = v end)
    Dropdown(c, "紧急起始稀有度", ORDER, Config.emergencyRarityMin, 4, function(v: string)
        Config.emergencyRarityMin = v :: Rarity
    end)

    order += 1
    SectionTitle(setPage, "安全区")
    order += 1
    local c2 = Card(setPage, order, "半径")
    Input(c2, "半径", tostring(Config.zoneSize), 1, function(s: string)
        local n = tonumber(s)
        if n and n >= 5 then Config.zoneSize = n end
    end)
    Toggle(c2, "放最佳前自动下骑", Config.autoDismount, 2, function(v: boolean) Config.autoDismount = v end)

    order += 1
    SectionTitle(setPage, "UI 不透明度")
    order += 1
    local c3 = Card(setPage, order, "滑块")
    Slider(c3, "背景透明度", Config.opacityBg, 0.3, 1.0, 1, function(v: number)
        Config.opacityBg = v
        applyOp()
    end)
    Slider(c3, "面板透明度", Config.opacityPanel, 0.3, 1.0, 2, function(v: number)
        Config.opacityPanel = v
        applyOp()
    end)

    order += 1
    SectionTitle(setPage, "配置")
    order += 1
    local c4 = Card(setPage, order, "保存")
    Button(c4, "💾 保存配置", Th.Ok, 1, function()
        SaveCfg()
        Notify("配置", "已保存", 2, Th.Ok)
    end)
    Tip(c4, "配置每 5 秒自动保存", 2)
end

switchTab("main")

-- =====================================================================
-- 拖动 / 缩放 / 最小化 / 快捷键
-- =====================================================================
do
    local dragging = false
    local dS: Vector2? = nil
    local sP: UDim2? = nil
    trk(TBar.InputBegan:Connect(function(i: InputObject)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dS = Vector2.new(i.Position.X, i.Position.Y)
            sP = Main.Position
        end
    end))
    trk(UserInputService.InputChanged:Connect(function(i: InputObject)
        if not dragging or not dS or not sP then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local cur = Vector2.new(i.Position.X, i.Position.Y)
        local d = cur - dS
        Main.Position = UDim2.new(
            sP.X.Scale, sP.X.Offset + d.X,
            sP.Y.Scale, sP.Y.Offset + d.Y
        )
    end))
    trk(UserInputService.InputEnded:Connect(function(i: InputObject)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

do
    local resizing = false
    local rS: Vector2? = nil
    local rZ: Vector2? = nil
    trk(RH.InputBegan:Connect(function(i: InputObject)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            rS = Vector2.new(i.Position.X, i.Position.Y)
            rZ = Vector2.new(Main.AbsoluteSize.X, Main.AbsoluteSize.Y)
        end
    end))
    trk(UserInputService.InputChanged:Connect(function(i: InputObject)
        if not resizing or not rS or not rZ then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local cur = Vector2.new(i.Position.X, i.Position.Y)
        local dx = cur.X - rS.X
        local dy = cur.Y - rS.Y
        local w = cl(rZ.X + dx, 500, 980)
        local h = cl(rZ.Y + dy, 420, 800)
        Main.Size = UDim2.fromOffset(w, h)
        local bh = h - TITLE_H - TIPS_H
        Sidebar.Size = UDim2.fromOffset(SBAR_W, bh)
        Content.Size = UDim2.new(1, -(G + SBAR_W + G * 2), 0, bh)
        TipsBar.Position = UDim2.new(0, 0, 1, -TIPS_H)
        Config.winW = w
        Config.winH = h
    end))
    trk(UserInputService.InputEnded:Connect(function(i: InputObject)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            resizing = false
            SaveCfg()
        end
    end))
end

local min = false
trk(MinBtn.MouseButton1Click:Connect(function()
    min = not min
    Sidebar.Visible = not min
    Content.Visible = not min
    TipsBar.Visible = not min
    RH.Visible = not min
    if min then ClosePopup() end
    Main.Size = UDim2.fromOffset(Main.AbsoluteSize.X, min and TITLE_H or Config.winH)
    MinBtn.Text = min and "+" or "—"
end))

trk(CloseBtn.MouseButton1Click:Connect(function()
    if getgenv().EggMasterCleanup then getgenv().EggMasterCleanup() end
end))

local hidden = false
trk(UserInputService.InputBegan:Connect(function(i: InputObject, gp: boolean)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightAlt then
        hidden = not hidden
        Main.Visible = not hidden
        if hidden then ClosePopup() end
        Notify("EggMaster",
            hidden and "已隐藏 (右Alt 恢复)" or "已显示",
            2, hidden and Th.Warn or Th.Ok)
    end
end))

-- Tips
task.spawn(function()
    while not State.stopAll do
        task.wait(0.5)
        pcall(function()
            local eggs = collect()
            local nP = 0
            for _ in pairs(modelToPart) do nP = nP + 1 end
            local nB = 0
            for _ in pairs(modelToBB) do nB = nB + 1 end
            TipsLbl.Text = string.format(
                "%s | 持蛋:%s | 蛋:%d 柱:%d 文字:%d",
                State.stealStatus,
                State.holding and "是" or "否",
                #eggs, nP, nB
            )
        end)
    end
end)

-- =====================================================================
-- 清理
-- =====================================================================
local function Cleanup(): ()
    if dead then return end
    dead = true
    State.stopAll = true
    State.stealRunning = false
    pcall(stopAntiGrav)
    pcall(clearAllPillars)
    pcall(restoreTrees)
    local c = LP.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
    pcall(SaveCfg)
    for _, conn in ipairs(Conns) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Conns)
    pcall(function() SG:Destroy() end)
    pcall(function() notifGui:Destroy() end)
    if getgenv().EggMasterCleanup == Cleanup then
        getgenv().EggMasterCleanup = nil
    end
    print("[EggMaster V54] 已清理")
end

getgenv().EggMasterCleanup = Cleanup
pcall(function()
    if script then script.Destroying:Connect(Cleanup) end
end)

applyOp()
if Config.autoSteal then task.defer(startSteal) end
Notify("EggMaster", "V54 已启动", 3, Th.Ok)
print("[EggMaster V54] 加载完成")
