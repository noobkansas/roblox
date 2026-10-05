--!nonstrict
-- 肌肉之王自动化 v26
--更新内容：修复了91个bug
--by ThxTure & DeepSeek V4.1 Flash
--本项目 @starter:2026/10/5 10:20 last upd：2026/10/5 0:30
--[[这是一款自动化脚本，主打**宠物养成、战斗杀戮、传送重生、BOSS 攻坚、宠物抽取**全套自动化逻辑，附带丰富可自定义参数、UI 自定义与性能优化能力，功能之间支持交叉启用或互斥避让，业务逻辑清晰。

核心模块

1. 锻炼自动化
支持自动锻炼、快速锻炼；快速锻炼依赖 100 只宠物反复执行，可依据帧率自动适配工具切换，兜底最多同时选用 2 种工具，兼容各类器械。
2. 传送与重生
传送可循环前往肌肉之王点位，支持全图传送点；提供自动重生、换包重生。
3. 杀戮战斗系统
全图自动杀戮，内置力量 / 耐久阈值判断，战力不足时自动停止战斗；支持全体自动击杀，可设置好友白名单；战斗时自动切换训练工具；检测到其他肌肉之王目标可优先击杀，支持自定义触发阈值。
4. 宠物 & 道具自动化
自动抽宠、购买宠物；自动转盘、自动拾取 / 投喂弹药，弹药投喂数量自定义。
5. BOSS 与宝箱
自动挑战 BOSS，可调节 BOSS 悬停高度；自动开启宝箱，宝箱相关数值可配置。
6. UI 与信息面板
UI 尺寸、比例、不透明度均可调节；独立信息小窗，可自定义大小、透明度；实时查看自身与其他玩家信息，数值格式化展示。
7. 视觉隐藏
可隐藏自身 / 他人宠物、器械、原生游戏 UI。
8. 性能优化
深度防卡顿方案：可关闭粒子、阴影、后处理、音效；远处模型渲染剔除，剔除距离可自定义；支持移除纹理。
9. 业务逻辑
内置避让机制；多功能支持交叉运行、互斥锁控制，防止功能冲突，自动化流程稳定可控。]]--

local SCRIPT_ID   = "__MUSCLE_KING_AUTO__"
local VERSION     = 2600
local CONFIG_FILE = "muscle_king_auto_config.json"

do
    local existing = _G[SCRIPT_ID]
    if existing then
        if existing.version and existing.version >= VERSION then return end
        if type(existing.cleanup) == "function" then pcall(existing.cleanup) end
    end
end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")
local SoundService      = game:GetService("SoundService")
local MarketplaceService= game:GetService("MarketplaceService")
local VirtualUser       = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local GetPlayers   = Players.GetPlayers
local RS_HB        = RunService.Heartbeat
local RS_RS        = RunService.RenderStepped
local UIS_IC       = UserInputService.InputChanged
local UIS_IB       = UserInputService.InputBegan
local UIS_IE       = UserInputService.InputEnded
local UIS_GML      = UserInputService.GetMouseLocation
local UIS_Touch    = UserInputService.TouchEnabled
local UIS_Kb       = UserInputService.KeyboardEnabled
local UD2n         = UDim2.new
local UD2o         = UDim2.fromOffset
local UD2s         = UDim2.fromScale
local C3           = Color3.fromRGB
local V2n          = Vector2.new
local V3n          = Vector3.new
local CN           = CFrame.new
local Font         = Enum.Font
local E_StrokeMode = Enum.ApplyStrokeMode.Border
local E_ZIdx       = Enum.ZIndexBehavior.Sibling
local E_AS_Y       = Enum.AutomaticSize.Y
local E_SortL      = Enum.SortOrder.LayoutOrder
local E_ScrollY    = Enum.ScrollingDirection.Y
local E_UI_MB1     = Enum.UserInputType.MouseButton1
local E_UI_Touch   = Enum.UserInputType.Touch
local E_UI_MMove   = Enum.UserInputType.MouseMovement
local E_TxtXL      = Enum.TextXAlignment.Left
local E_TxtXR      = Enum.TextXAlignment.Right
local E_CamCustom  = Enum.CameraType.Custom

local isMobile = UIS_Touch and not UIS_Kb

local Theme = {
    Bg         = C3(15, 17, 23),
    Surface    = C3(24, 27, 36),
    SurfaceAlt = C3(34, 38, 50),
    Border     = C3(52, 58, 74),
    Accent     = C3(102, 145, 255),
    AccentDim  = C3(45, 65, 120),
    Success    = C3(105, 210, 145),
    Warning    = C3(240, 185, 100),
    Danger     = C3(230, 100, 100),
    Text       = C3(238, 242, 250),
    TextDim    = C3(165, 172, 190),
    TextMuted  = C3(110, 120, 140),
}

local DEFAULT = {
    uiWidthPct = 40,
    uiHeightPct = 46,
    mainPos = UD2n(0.5, -260, 0.5, -190),
    infoPos = UD2n(1, -300, 1, -440),
}

local State = {
    destroyed = false, conns = {}, ui = {},

    autoTrain = false, fastTrain = false, fastRate = 20,
    toolDumbbell = false, toolPushups = false,
    toolHandstands = false, toolSitups = false,
    lastToolCheck = 0, toolCooldown = false,
    _missingSince = 0, _lastSuicide = 0, _suicideCount = 0,

    autoTeleport = false, lastTeleportAt = 0, lastCameraFix = 0,
    autoRebirth = false, rebirthRate = 2, lastRebirthAt = 0,

    killEnabled = false, killThreshold = 5,
    killScanAt = 0, killTarget = nil, killLastAttack = 0,
    killSavedState = nil, toolOwnedByKill = false,
    friendWhitelist = false,
    autoKingKill = false, kingKillThreshold = 20,
    kingKillTarget = nil, kingKillLastAttack = 0,
    kingKillActive = false, lastKingCheck = 0,
    dualEnabled = true, dualLastSwitch = 0, dualCurrentMode = "punch",

    adaptiveEnabled = false, adaptiveThreshold = 30,
    adaptiveStep = 100, adaptiveStableCount = 0, lastAdaptiveAt = 0,

    antiLagEnabled = false,
    renderCullEnabled = false, renderCullDist = 500,
    hideOwnPets = false, hideAllPets = false, hideMachines = false,
    textureRemoverEnabled = false,
    hideUIEnabled = false,

    infoWindowEnabled = false, infoLastRefresh = 0,
    formatEnabled = true,

    uiBgOpacity = 1.0,
    uiPageOpacity = 1.0,
    infoBgOpacity = 1.0,
    infoScale = 100,

    autoPetBuy = false, selectedPet = "",
    autoWheel = false,
    autoBoss = false, bossHeight = 70,
    autoPackRebirth = false,
    autoEatEgg = false, giftAmount = 0, selectedEggTarget = "",

    -- Boss / 宝箱
    autoChest = true,
    chestDelay = 5,
    chestHoldTime = 2,
    lastBossAliveAt = 0,
    bossWasAlive = false,
    bossKilledAt = 0,

    petRepBonus = 0, petRepBonusCheckedAt = 0, petRepBonusDetail = {},
    uiWidthPct = DEFAULT.uiWidthPct, uiHeightPct = DEFAULT.uiHeightPct,
    originalGravity = Workspace.Gravity,
    muscleEventRef = nil, rebirthEventRef = nil, lastRebirthScan = 0,

    trainAccum = 0, time = 0,
    fpsWinTime = 0, fpsWinFrames = 0, avgFps = 60,
    lastDegradeAt = 0, degradeLevel = 0,
    lastAFKClick = 0, lastSaveAt = 0, lastSweepAt = 0,
    sessionStartStrength = nil, strengthCheckAt = 0,
    lastStrengthSnapshot = 0, strengthPerSec = 0,
    ping = 0, lastPingCheck = 0,
    friendCount = 0,
}

local FriendWhitelist = { ids = {}, loaded = false, refreshing = false, lastRefresh = 0 }
local function refreshFriendList()
    if FriendWhitelist.refreshing then return end
    FriendWhitelist.refreshing = true
    task.spawn(function()
        local ids = {}
        pcall(function()
            local pages = LocalPlayer:GetFriendsAsync()
            while pages do
                for _, item in ipairs(pages:GetCurrentPage()) do
                    if item.Id then ids[item.Id] = true end
                end
                if pages.IsFinished then break end
                pages:AdvanceToNextPageAsync()
            end
        end)
        pcall(function()
            for _, f in ipairs(LocalPlayer:GetFriendsOnline(200)) do
                if f.VisitorId then ids[f.VisitorId] = true end
            end
        end)
        FriendWhitelist.ids = ids
        FriendWhitelist.loaded = true
        local n = 0
        for _ in pairs(ids) do n = n + 1 end
        State.friendCount = n
        FriendWhitelist.lastRefresh = tick()
        FriendWhitelist.refreshing = false
    end)
end
local function isFriend(plr)
    if not plr or not plr.UserId then return false end
    return FriendWhitelist.ids[plr.UserId] == true
end

local RepCache = { pet = 0, ult = 0, x2 = false, speedMul = 1, lastRefresh = 0, lastPassCheck = 0 }
local X2_REP_PASS_ID = 6998482
local Cache = { char = nil, hum = nil, hrp = nil }
local function refreshCache()
    local c = LocalPlayer.Character
    if c ~= Cache.char then Cache.char = c; Cache.hum = nil; Cache.hrp = nil end
    if c then
        if not Cache.hum or not Cache.hum.Parent then
            Cache.hum = c:FindFirstChildOfClass("Humanoid")
        end
        if not Cache.hrp or not Cache.hrp.Parent then
            Cache.hrp = c:FindFirstChild("HumanoidRootPart")
        end
    end
end

local function track(c) if c then table.insert(State.conns, c) end return c end
local function create(cls, props, parent)
    local i = Instance.new(cls)
    for k, v in pairs(props) do if k ~= "Parent" then i[k] = v end end
    if parent then i.Parent = parent end
    return i
end
local function corner(p, r) return create("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p) end
local function stroke(p, c, t, tr)
    return create("UIStroke", { Color = c or Theme.Border, Thickness = t or 1,
        Transparency = tr or 0, ApplyStrokeMode = E_StrokeMode }, p)
end
local function padding(p, t, b, l, r)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
    }, p)
end
local function listLayout(p, spacing, h)
    return create("UIListLayout", {
        Padding = UDim.new(0, spacing or 6),
        FillDirection = h and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder = E_SortL,
    }, p)
end

local function notify(text, duration)
    duration = duration or 3
    if State.destroyed or not State.ui.screen then return end
    local label = create("TextLabel", {
        AnchorPoint = V2n(0.5, 0), Position = UD2n(0.5, 0, 0.04, 0),
        Size = UD2o(420, 42), BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0, Font = Font.GothamMedium,
        Text = text, TextColor3 = Theme.Text,
        TextSize = 14, TextWrapped = true, ZIndex = 500,
    }, State.ui.screen)
    corner(label, 10); stroke(label, Theme.Accent, 1.5, 0.3)
    task.delay(duration, function() pcall(function() label:Destroy() end) end)
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
    "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }
local function formatNumber(n)
    n = tonumber(n) or 0
    if not State.formatEnabled then return tostring(math.floor(n)) end
    local neg = n < 0
    n = math.abs(n)
    if n < 1000 then return (neg and "-" or "") .. string.format("%.0f", n) end
    local idx = 1
    while n >= 1000 and idx < #SUFFIXES do n = n / 1000; idx = idx + 1 end
    return (neg and "-" or "") .. string.format("%.3f%s", n, SUFFIXES[idx])
end

local function saveConfig()
    if State.destroyed or type(writefile) ~= "function" then return end
    local data = {
        autoTrain = State.autoTrain, fastTrain = State.fastTrain, fastRate = State.fastRate,
        toolDumbbell = State.toolDumbbell, toolPushups = State.toolPushups,
        toolHandstands = State.toolHandstands, toolSitups = State.toolSitups,
        autoRebirth = State.autoRebirth, rebirthRate = State.rebirthRate,
        killThreshold = State.killThreshold, dualEnabled = State.dualEnabled,
        friendWhitelist = State.friendWhitelist,
        autoKingKill = State.autoKingKill, kingKillThreshold = State.kingKillThreshold,
        adaptiveEnabled = State.adaptiveEnabled, adaptiveThreshold = State.adaptiveThreshold,
        antiLagEnabled = State.antiLagEnabled,
        renderCullEnabled = State.renderCullEnabled, renderCullDist = State.renderCullDist,
        hideOwnPets = State.hideOwnPets, hideAllPets = State.hideAllPets, hideMachines = State.hideMachines,
        textureRemoverEnabled = State.textureRemoverEnabled,
        hideUIEnabled = State.hideUIEnabled,
        infoWindowEnabled = State.infoWindowEnabled,
        formatEnabled = State.formatEnabled,
        uiBgOpacity = State.uiBgOpacity, uiPageOpacity = State.uiPageOpacity,
        infoBgOpacity = State.infoBgOpacity, infoScale = State.infoScale,
        autoChest = State.autoChest, chestDelay = State.chestDelay, chestHoldTime = State.chestHoldTime,
        selectedPet = State.selectedPet, bossHeight = State.bossHeight,
        giftAmount = State.giftAmount,
        uiWidthPct = State.uiWidthPct, uiHeightPct = State.uiHeightPct,
    }
    local ok, enc = pcall(HttpService.JSONEncode, HttpService, data)
    if ok and enc then pcall(writefile, CONFIG_FILE, enc) end
end
local function loadConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    local exists = false
    pcall(function() exists = isfile(CONFIG_FILE) end)
    if not exists then return end
    local ok, content = pcall(readfile, CONFIG_FILE)
    if not ok or type(content) ~= "string" then return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok2 or type(data) ~= "table" then return end
    local function b(k, f) if type(data[k]) == "boolean" then return data[k] end return f end
    local function n(k, f, lo, hi)
        local v = tonumber(data[k]) if not v then return f end
        v = math.floor(v)
        if lo then v = math.max(lo, v) end
        if hi then v = math.min(hi, v) end
        return v
    end
    local function fl(k, f, lo, hi)
        local v = tonumber(data[k]) if not v then return f end
        if lo then v = math.max(lo, v) end
        if hi then v = math.min(hi, v) end
        return v
    end
    State.autoTrain = b("autoTrain", State.autoTrain)
    State.fastTrain = b("fastTrain", State.fastTrain)
    State.fastRate = n("fastRate", State.fastRate, 1, 50000)
    State.toolDumbbell = b("toolDumbbell", State.toolDumbbell)
    State.toolPushups = b("toolPushups", State.toolPushups)
    State.toolHandstands = b("toolHandstands", State.toolHandstands)
    State.toolSitups = b("toolSitups", State.toolSitups)
    State.autoRebirth = b("autoRebirth", State.autoRebirth)
    State.rebirthRate = n("rebirthRate", State.rebirthRate, 1, 100)
    State.killThreshold = n("killThreshold", State.killThreshold, 1, 100)
    State.dualEnabled = b("dualEnabled", State.dualEnabled)
    State.friendWhitelist = b("friendWhitelist", State.friendWhitelist)
    State.autoKingKill = b("autoKingKill", State.autoKingKill)
    State.kingKillThreshold = n("kingKillThreshold", State.kingKillThreshold, 1, 1000)
    State.adaptiveEnabled = b("adaptiveEnabled", State.adaptiveEnabled)
    State.adaptiveThreshold = n("adaptiveThreshold", State.adaptiveThreshold, 10, 120)
    State.antiLagEnabled = b("antiLagEnabled", State.antiLagEnabled)
    State.renderCullEnabled = b("renderCullEnabled", State.renderCullEnabled)
    State.renderCullDist = n("renderCullDist", State.renderCullDist, 100, 5000)
    State.hideOwnPets = b("hideOwnPets", State.hideOwnPets)
    State.hideAllPets = b("hideAllPets", State.hideAllPets)
    State.hideMachines = b("hideMachines", State.hideMachines)
    State.textureRemoverEnabled = b("textureRemoverEnabled", State.textureRemoverEnabled)
    State.hideUIEnabled = b("hideUIEnabled", State.hideUIEnabled)
    State.infoWindowEnabled = b("infoWindowEnabled", State.infoWindowEnabled)
    State.formatEnabled = b("formatEnabled", State.formatEnabled)
    State.uiBgOpacity = fl("uiBgOpacity", State.uiBgOpacity, 0.3, 1.0)
    State.uiPageOpacity = fl("uiPageOpacity", State.uiPageOpacity, 0.3, 1.0)
    State.infoBgOpacity = fl("infoBgOpacity", State.infoBgOpacity, 0.3, 1.0)
    State.infoScale = n("infoScale", State.infoScale, 60, 200)
    State.autoChest = b("autoChest", State.autoChest)
    State.chestDelay = n("chestDelay", State.chestDelay, 0, 30)
    State.chestHoldTime = n("chestHoldTime", State.chestHoldTime, 1, 10)
    if type(data.selectedPet) == "string" then State.selectedPet = data.selectedPet end
    State.bossHeight = n("bossHeight", State.bossHeight, 0, 200)
    State.giftAmount = n("giftAmount", State.giftAmount, 0, 9999)
    State.uiWidthPct = n("uiWidthPct", State.uiWidthPct, 30, 90)
    State.uiHeightPct = n("uiHeightPct", State.uiHeightPct, 30, 90)
end

-- 反复速度
local function collectPetRepTimes()
    local sumPct, timeMul = 0, 1
    local own = Workspace:FindFirstChild(LocalPlayer.Name)
    if not own then return 0, 1 end
    local seen = {}
    for _, pet in ipairs(own:GetChildren()) do
        if pet:IsA("Model") then
            local slot
            local s = pet:FindFirstChild("equippedSlot")
            if s and s:IsA("StringValue") and s.Value ~= "" then slot = s.Value end
            local key = slot or ("obj:" .. tostring(pet))
            if not seen[key] then
                seen[key] = true
                local perks = pet:FindFirstChild("perksFolder")
                if perks then
                    for _, p in ipairs(perks:GetChildren()) do
                        if p:IsA("ValueBase") and p.Name:lower():find("rep") then
                            local v = tonumber(p.Value) or 0
                            if v > 0 then
                                sumPct = sumPct + v
                                local m = 1 - v / 100
                                if m < 0.001 then m = 0.001 end
                                timeMul = timeMul * m
                            end
                        end
                    end
                end
            end
        end
    end
    return sumPct, timeMul
end

local function readUltPct()
    local a = LocalPlayer:GetAttribute("UltimateRepSpeed")
    if type(a) == "number" then return a * 5 end
    local v = LocalPlayer:FindFirstChild("UltimateRepSpeed")
    if v and v:IsA("ValueBase") then return (tonumber(v.Value) or 0) * 5 end
    return 0
end

local function checkX2Pass()
    local now = tick()
    if now - RepCache.lastPassCheck < 60 then return RepCache.x2 end
    RepCache.lastPassCheck = now
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, X2_REP_PASS_ID)
    end)
    RepCache.x2 = (ok and owns) and true or false
    return RepCache.x2
end
local function refreshRepSpeed()
    local petPct, petMul = collectPetRepTimes()
    local ultPct = readUltPct()
    local x2 = checkX2Pass()
    local ultMul = math.max(0.001, 1 - ultPct / 100)
    local passMul = x2 and 0.5 or 1
    RepCache.pet = petPct
    RepCache.ult = ultPct
    RepCache.x2 = x2
    local tt = math.max(0.0001, petMul * ultMul * passMul)
    RepCache.speedMul = 1 / tt
end

-- 性能
local AntiLag = { enabled = false, rescanAt = 0, particles = {}, shadows = {}, sounds = {}, lighting = nil, postEffects = {}, atmospheres = {} }
local POST = { BloomEffect = true, BlurEffect = true, SunRaysEffect = true, ColorCorrectionEffect = true, DepthOfFieldEffect = true }
local function scanAntiLag()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local cls = obj.ClassName
        if cls == "ParticleEmitter" or cls == "Trail" or cls == "Beam" or cls == "Fire" or cls == "Smoke" or cls == "Sparkles" then
            if obj.Enabled then obj.Enabled = false; table.insert(AntiLag.particles, obj) end
        elseif cls == "BasePart" and obj.CastShadow then
            table.insert(AntiLag.shadows, { part = obj, value = true }); obj.CastShadow = false
        end
    end
    for _, obj in ipairs(Lighting:GetChildren()) do
        if POST[obj.ClassName] then
            if obj.Enabled then obj.Enabled = false; table.insert(AntiLag.postEffects, obj) end
        elseif obj.ClassName == "Atmosphere" then
            table.insert(AntiLag.atmospheres, { obj = obj, Density = obj.Density, Haze = obj.Haze, Glare = obj.Glare })
            obj.Density = 0; obj.Haze = 0; obj.Glare = 0
        end
    end
    for _, obj in ipairs(SoundService:GetDescendants()) do
        if obj:IsA("Sound") and obj.Playing and obj.Volume > 0 then
            table.insert(AntiLag.sounds, { sound = obj, volume = obj.Volume }); obj.Volume = 0
        end
    end
end
local function enableAntiLag()
    if AntiLag.enabled then return end
    AntiLag.enabled = true
    AntiLag.lighting = { GlobalShadows = Lighting.GlobalShadows, ShadowSoftness = Lighting.ShadowSoftness }
    pcall(function() Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0 end)
    scanAntiLag(); AntiLag.rescanAt = State.time + 2
end
local function rescanAntiLag()
    if not AntiLag.enabled then return end
    pcall(function() Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0 end)
    scanAntiLag(); AntiLag.rescanAt = State.time + 2
end
local function disableAntiLag()
    AntiLag.enabled = false
    for _, p in ipairs(AntiLag.particles) do pcall(function() p.Enabled = true end) end
    table.clear(AntiLag.particles)
    for _, it in ipairs(AntiLag.shadows) do pcall(function() it.part.CastShadow = it.value end) end
    table.clear(AntiLag.shadows)
    for _, it in ipairs(AntiLag.sounds) do pcall(function() it.sound.Volume = it.volume end) end
    table.clear(AntiLag.sounds)
    for _, fx in ipairs(AntiLag.postEffects) do pcall(function() fx.Enabled = true end) end
    table.clear(AntiLag.postEffects)
    for _, it in ipairs(AntiLag.atmospheres) do
        pcall(function() it.obj.Density = it.Density; it.obj.Haze = it.Haze; it.obj.Glare = it.Glare end)
    end
    table.clear(AntiLag.atmospheres)
    if AntiLag.lighting then
        pcall(function()
            Lighting.GlobalShadows = AntiLag.lighting.GlobalShadows
            Lighting.ShadowSoftness = AntiLag.lighting.ShadowSoftness
        end)
        AntiLag.lighting = nil
    end
end

local RenderCull = { hidden = {}, rescanAt = 0 }
local function cullModel(m)
    local s = {}
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then
            s[p] = { ltm = p.LocalTransparencyModifier, tr = p.Transparency }
            pcall(function() p.LocalTransparencyModifier = 1; p.Transparency = 1 end)
        end
    end
    RenderCull.hidden[m] = s
end
local function uncullModel(m)
    local s = RenderCull.hidden[m]; if not s then return end
    for p, v in pairs(s) do
        if p.Parent then pcall(function() p.LocalTransparencyModifier = v.ltm; p.Transparency = v.tr end) end
    end
    RenderCull.hidden[m] = nil
end
local function scanRenderCull()
    local hrp = Cache.hrp; if not hrp then return end
    local pos = hrp.Position
    local tSq = (State.renderCullDist or 500) ^ 2
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= Cache.char and not Players:GetPlayerFromCharacter(obj) then
            local prim = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if prim then
                local d = prim.Position - pos
                local dsq = d.X*d.X + d.Y*d.Y + d.Z*d.Z
                if dsq > tSq then
                    if not RenderCull.hidden[obj] then cullModel(obj) end
                else
                    if RenderCull.hidden[obj] then uncullModel(obj) end
                end
            end
        end
    end
    for m in pairs(RenderCull.hidden) do if not m.Parent then RenderCull.hidden[m] = nil end end
    RenderCull.rescanAt = State.time + 1
end
local function disableRenderCull()
    for m in pairs(RenderCull.hidden) do uncullModel(m) end
    table.clear(RenderCull.hidden)
end

local PetHider = { own = {}, all = {}, machines = {}, rescanAt = 0 }
local function hidePart(m)
    if not m or not m.Parent then return end
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.LocalTransparencyModifier = 1; p.Transparency = 1 end) end
    end
end
local function showPart(m)
    if not m or not m.Parent then return end
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.LocalTransparencyModifier = 0; p.Transparency = 0 end) end
    end
end
local function scanHidePets()
    if State.hideOwnPets then
        local own = Workspace:FindFirstChild(LocalPlayer.Name)
        if own then
            for _, pet in ipairs(own:GetChildren()) do
                if pet:IsA("Model") or pet:IsA("Folder") then
                    table.insert(PetHider.own, pet); hidePart(pet)
                end
            end
        end
    end
    if State.hideAllPets then
        for _, plr in ipairs(GetPlayers(Players)) do
            if plr ~= LocalPlayer then
                local f = Workspace:FindFirstChild(plr.Name)
                if f then
                    for _, pet in ipairs(f:GetChildren()) do
                        if pet:IsA("Model") or pet:IsA("Folder") then
                            table.insert(PetHider.all, pet); hidePart(pet)
                        end
                    end
                end
            end
        end
    end
    PetHider.rescanAt = State.time + 2
end
local function restoreHiddenPets()
    for _, m in ipairs(PetHider.own) do showPart(m) end
    table.clear(PetHider.own)
    for _, m in ipairs(PetHider.all) do showPart(m) end
    table.clear(PetHider.all)
end
local function scanHideMachines()
    if not State.hideMachines then return end
    local mf = Workspace:FindFirstChild("machinesFolder")
    if mf then
        for _, m in ipairs(mf:GetChildren()) do
            if m:IsA("Model") then table.insert(PetHider.machines, m); hidePart(m) end
        end
    end
    PetHider.rescanAt = State.time + 2
end
local function restoreHiddenMachines()
    for _, m in ipairs(PetHider.machines) do showPart(m) end
    table.clear(PetHider.machines)
end

local TexRem = { enabled = false, rescanAt = 0, saved = {}, seen = {} }
local function scanTextures()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local cls = obj.ClassName
        if cls == "Decal" or cls == "Texture" then
            if not TexRem.seen[obj] and obj.Texture ~= "" then
                TexRem.seen[obj] = true
                table.insert(TexRem.saved, { obj = obj, prop = "Texture", value = obj.Texture })
                obj.Texture = ""
            end
        elseif cls == "MeshPart" or cls == "SpecialMesh" then
            local p = (cls == "MeshPart") and "TextureID" or "TextureId"
            if not TexRem.seen[obj] and obj[p] and obj[p] ~= "" then
                TexRem.seen[obj] = true
                table.insert(TexRem.saved, { obj = obj, prop = p, value = obj[p] })
                obj[p] = ""
            end
        elseif cls == "SurfaceAppearance" then
            if not TexRem.seen[obj] and obj.ColorMap ~= "" then
                TexRem.seen[obj] = true
                table.insert(TexRem.saved, { obj = obj, prop = "ColorMap", value = obj.ColorMap })
                obj.ColorMap = ""
            end
        end
    end
end
local function enableTex()
    if TexRem.enabled then return end
    TexRem.enabled = true; table.clear(TexRem.saved); table.clear(TexRem.seen)
    scanTextures(); TexRem.rescanAt = State.time + 4
end
local function rescanTex()
    if not TexRem.enabled then return end
    scanTextures(); TexRem.rescanAt = State.time + 4
end
local function disableTex()
    TexRem.enabled = false
    for _, it in ipairs(TexRem.saved) do pcall(function() it.obj[it.prop] = it.value end) end
    table.clear(TexRem.saved); table.clear(TexRem.seen)
end

local HiddenUIs = {}
local function hideAllUI()
    table.clear(HiddenUIs)
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui ~= State.ui.screen and gui ~= State.ui.infoGui then
            if gui.Enabled then gui.Enabled = false; table.insert(HiddenUIs, gui) end
        end
    end
end
local function restoreHiddenUI()
    for _, gui in ipairs(HiddenUIs) do pcall(function() gui.Enabled = true end) end
    table.clear(HiddenUIs)
end

local function sweepOverflow()
    for i = #AntiLag.particles, 1, -1 do local p = AntiLag.particles[i]; if not p or not p.Parent then table.remove(AntiLag.particles, i) end end
    for i = #AntiLag.shadows, 1, -1 do local it = AntiLag.shadows[i]; if not it.part or not it.part.Parent then table.remove(AntiLag.shadows, i) end end
    for i = #AntiLag.sounds, 1, -1 do local it = AntiLag.sounds[i]; if not it.sound or not it.sound.Parent then table.remove(AntiLag.sounds, i) end end
    for i = #AntiLag.postEffects, 1, -1 do local fx = AntiLag.postEffects[i]; if not fx or not fx.Parent then table.remove(AntiLag.postEffects, i) end end
    for i = #AntiLag.atmospheres, 1, -1 do local it = AntiLag.atmospheres[i]; if not it.obj or not it.obj.Parent then table.remove(AntiLag.atmospheres, i) end end
    for m in pairs(RenderCull.hidden) do if not m.Parent then RenderCull.hidden[m] = nil end end
    for i = #TexRem.saved, 1, -1 do local it = TexRem.saved[i]; if not it.obj or not it.obj.Parent then table.remove(TexRem.saved, i) end end
    for o in pairs(TexRem.seen) do if not o.Parent then TexRem.seen[o] = nil end end
    for i = #PetHider.own, 1, -1 do if not PetHider.own[i].Parent then table.remove(PetHider.own, i) end end
    for i = #PetHider.all, 1, -1 do if not PetHider.all[i].Parent then table.remove(PetHider.all, i) end end
    for i = #PetHider.machines, 1, -1 do if not PetHider.machines[i].Parent then table.remove(PetHider.machines, i) end end
    for i = #HiddenUIs, 1, -1 do if not HiddenUIs[i].Parent then table.remove(HiddenUIs, i) end end
end

-- 工具
local TOOL_KW = {
    dumbbell   = { "barbell", "dumbbell", "weight", "哑铃", "杠铃" },
    pushups    = { "pushup", "push up", "push-up", "俯卧撑" },
    handstands = { "handstand", "hand stand", "hand-stand", "倒立" },
    situps     = { "situp", "sit up", "sit-up", "仰卧起坐" },
    punch      = { "punch", "拳", "fist", "空手", "拳头" },
}
local function matchKw(n, list)
    n = n:lower()
    for i = 1, #list do if n:find(list[i]) then return true end end
    return false
end
local function isEquipped(list)
    local c = Cache.char; if not c then return false end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and matchKw(t.Name, list) then return true end
    end
    return false
end
local function findTool(list)
    local c = Cache.char
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and matchKw(t.Name, list) then return t end
        end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and matchKw(t.Name, list) then return t end
        end
    end
    return nil
end
local function tryEquip(list)
    if isEquipped(list) then return true end
    local hum = Cache.hum; if not hum then return false end
    local bp = LocalPlayer:FindFirstChild("Backpack"); if not bp then return false end
    for _, c in ipairs(bp:GetChildren()) do
        if c:IsA("Tool") and matchKw(c.Name, list) then
            pcall(function() hum:EquipTool(c) end)
            return true
        end
    end
    return false
end
local function toolExists(list) return isEquipped(list) or findTool(list) ~= nil end
local function suicide()
    local hum = Cache.hum
    if hum and hum.Health > 0 then hum.Health = 0
    elseif Cache.char then pcall(function() Cache.char:BreakJoints() end) end
end

local function stat(plr, name)
    if not plr then return 0 end
    local v = plr:FindFirstChild(name)
    if v and v:IsA("ValueBase") then return tonumber(v.Value) or 0 end
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        local s = ls:FindFirstChild(name)
        if s and s:IsA("ValueBase") then return tonumber(s.Value) or 0 end
    end
    return 0
end
local function myStrength() return stat(LocalPlayer, "Strength") end
local function myDurability() return stat(LocalPlayer, "Durability") end

local function getMuscleEvent()
    local c = State.muscleEventRef
    if c and c.Parent == LocalPlayer then return c end
    local ev = LocalPlayer:FindFirstChild("muscleEvent")
    State.muscleEventRef = ev
    return ev
end
local function getRebirthEvent()
    local c = State.rebirthEventRef
    if c and c.Parent then return c end
    if State.time - State.lastRebirthScan < 3 then return nil end
    State.lastRebirthScan = State.time
    local r = ReplicatedStorage:FindFirstChild("rEvents")
    if r then
        local ev = r:FindFirstChild("rebirthRemote")
        if ev and (ev:IsA("RemoteEvent") or ev:IsA("RemoteFunction")) then
            State.rebirthEventRef = ev
            return ev
        end
    end
    return nil
end
local function fireRebirth()
    local ev = getRebirthEvent(); if not ev then return end
    task.spawn(function()
        pcall(function()
            if ev:IsA("RemoteFunction") then ev:InvokeServer("rebirthRequest")
            else ev:FireServer("rebirthRequest") end
        end)
    end)
end

local function getMuscleKing()
    local shared = ReplicatedStorage:FindFirstChild("shared")
    if not shared then return nil end
    local state = shared:FindFirstChild("state")
    if not state then return nil end
    local world = state:FindFirstChild("World")
    if not world then return nil end
    local mk = world:FindFirstChild("muscleKing")
    if not mk then return nil end
    if mk:IsA("ObjectValue") then
        local v = mk.Value
        if v and v:IsA("Player") then return v end
    elseif mk:IsA("StringValue") then
        if mk.Value ~= "" then return Players:FindFirstChild(mk.Value) end
    end
    return nil
end

-- 传送
local PortalCache, PortalCacheAt = nil, 0
local function getPortal()
    if PortalCache and PortalCache.Parent and State.time - PortalCacheAt < 5 then return PortalCache end
    local p = Workspace:FindFirstChild("beachToMuscleKing", true)
    PortalCache = (p and p:IsA("BasePart")) and p or nil
    PortalCacheAt = State.time
    return PortalCache
end
local function teleportMuscleKing(force)
    if force then PortalCache = nil; PortalCacheAt = 0 end
    local hrp = Cache.hrp; if not hrp then return false end
    local portal = getPortal()
    local cf = portal and CN(portal.Position + V3n(0, 3, 0)) or CN(V3n(-8727.1, 406.7, -5796.4))
    return pcall(function()
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity = V3n(0, 0, 0)
        hrp.AssemblyAngularVelocity = V3n(0, 0, 0)
    end)
end

local TELEPORTS = {
    { name = "大厅", pos = V3n(-0.75, 90.61, 242.78) },
    { name = "小岛", pos = V3n(-32.14, 8.51, 1904.41) },
    { name = "冰霜健身房", pos = V3n(-2623.41, 6.99, -409.34) },
    { name = "神话健身房", pos = V3n(2250.39, 6.99, 1072.77) },
    { name = "永恒健身房", pos = V3n(-6758.39, 6.99, -1284.45) },
    { name = "传奇健身房", pos = V3n(4603.40, 990.99, -3897.44) },
    { name = "肌肉之王健身房", pos = V3n(-8625.40, 16.99, -5730.41) },
    { name = "丛林健身房", pos = V3n(-8685.01, 5.99, 2392.06) },
    { name = "工业健身房", pos = V3n(-5496.68, 59.04, 4927.74) },
    { name = "超载健身房", pos = V3n(-3045.30, 165.41, 4990.69) },
    { name = "无转盘岛", pos = V3n(1952.09, 1, 6179.98) },
    { name = "熔岩争斗", pos = V3n(4472.53, 118.90, -8848.54) },
    { name = "沙漠争斗", pos = V3n(973.62, 15.92, -7277.01) },
    { name = "海滩争斗", pos = V3n(-1880.89, 15.87, -6137.75) },
}
local function teleportTo(pos)
    local hrp = Cache.hrp; if not hrp then return false end
    return pcall(function()
        hrp.CFrame = CN(pos)
        hrp.AssemblyLinearVelocity = V3n(0, 0, 0)
        hrp.AssemblyAngularVelocity = V3n(0, 0, 0)
    end)
end

-- 杀戮
local function getCharHRP(plr)
    local c = plr and plr.Character
    if not c then return nil end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return nil end
    return hrp
end
local function applyKillMove(targetHRP)
    local hrp = Cache.hrp; if not hrp then return end
    local delta = targetHRP.Position - hrp.Position
    local dsq = delta.X*delta.X + delta.Y*delta.Y + delta.Z*delta.Z
    if dsq > 9 then
        local dist = math.sqrt(dsq)
        local newPos = targetHRP.Position - delta / dist * 2.5
        local cf = CN(newPos, targetHRP.Position)
        pcall(function()
            hrp.CFrame = cf
            hrp.AssemblyLinearVelocity = V3n(0, 0, 0)
            hrp.AssemblyAngularVelocity = V3n(0, 0, 0)
        end)
    end
end
local function punch()
    local c = Cache.char; if not c then return end
    local tool = c:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

-- ★ v26：判断目标是否安全（对方不能在我打死他前先打死我）
-- 我打死对方所需攻击次数 = theirDur / myStr
-- 对方打死我所需攻击次数 = myDur / theirStr
-- 如果我的攻击次数 >= 对方的攻击次数 → 对方先打死我 → 不安全
local function isTargetSafe(plr, myStr, myDur)
    if myDur <= 0 or myStr <= 0 then return true end
    local theirStr = stat(plr, "Strength")
    local theirDur = stat(plr, "Durability")
    if theirStr <= 0 or theirDur <= 0 then return true end
    local myHits    = theirDur / myStr
    local theirHits = myDur / theirStr
    return myHits < theirHits
end

local function selectKillTarget()
    local s = myStrength()
    local myDur = myDurability()
    local t = State.killThreshold or 5
    for _, plr in ipairs(GetPlayers(Players)) do
        if plr ~= LocalPlayer and not (State.friendWhitelist and isFriend(plr)) then
            local hrp = getCharHRP(plr)
            if hrp then
                local dur = stat(plr, "Durability")
                -- 检查1：我能否打死对方（原逻辑）
                local canKill = (dur == 0) or (s > 0 and s * t >= dur)
                -- 检查2：★ 对方能否先把我打死
                if canKill and isTargetSafe(plr, s, myDur) then
                    return plr
                end
            end
        end
    end
    return nil
end

local function runKillTick()
    if State.time - State.killScanAt >= 0.5 then
        State.killScanAt = State.time
        if State.killTarget and State.friendWhitelist and isFriend(State.killTarget) then
            State.killTarget = nil
        end
        local valid = State.killTarget and getCharHRP(State.killTarget)
        if not valid then
            State.killTarget = selectKillTarget()
        else
            local s = myStrength()
            local myDur = myDurability()
            local dur = stat(State.killTarget, "Durability")
            -- 目标耐久太高 或 对方能反杀 → 换目标
            local failKill = dur > 0 and s > 0 and s * (State.killThreshold or 5) < dur
            local failSafe = not isTargetSafe(State.killTarget, s, myDur)
            if failKill or failSafe then
                State.killTarget = selectKillTarget()
            end
        end
        State.toolOwnedByKill = State.killTarget ~= nil
    end
    local t = State.killTarget; if not t then return end
    local hrp = getCharHRP(t); if not hrp then State.killTarget = nil; return end
    applyKillMove(hrp)
    local dual = State.dualEnabled and (State.autoTrain or State.fastTrain)
    if not dual then
        if State.time - State.killLastAttack >= 0.05 then
            State.killLastAttack = State.time
            if not isEquipped(TOOL_KW.punch) then tryEquip(TOOL_KW.punch) end
            punch()
        end
    end
end

-- ★ v26：肌肉之王 —— 加入反杀判定
local function runKingKillTick()
    if State.time - State.lastKingCheck >= 0.5 then
        State.lastKingCheck = State.time
        local king = getMuscleKing()
        if not king or king == LocalPlayer or (State.friendWhitelist and isFriend(king)) then
            State.kingKillTarget = nil; State.kingKillActive = false; return
        end
        local hrp = getCharHRP(king)
        if not hrp then State.kingKillTarget = nil; State.kingKillActive = false; return end
        local s = myStrength()
        local myDur = myDurability()
        local theirDur = stat(king, "Durability")
        local theirStr = stat(king, "Strength")
        -- 检查1：我能否打死对方（原逻辑）
        if theirDur > 0 and s > 0 and theirDur >= s * (State.kingKillThreshold or 20) then
            State.kingKillTarget = nil; State.kingKillActive = false; return
        end
        -- 检查2：★ 对方能否先把我打死
        if not isTargetSafe(king, s, myDur) then
            State.kingKillTarget = nil; State.kingKillActive = false; return
        end
        State.kingKillTarget = king
    end
    local t = State.kingKillTarget; if not t then State.kingKillActive = false; return end
    if State.friendWhitelist and isFriend(t) then
        State.kingKillTarget = nil; State.kingKillActive = false; return
    end
    local hrp = getCharHRP(t)
    if not hrp then State.kingKillTarget = nil; State.kingKillActive = false; return end
    State.kingKillActive = true
    applyKillMove(hrp)
    if State.time - State.kingKillLastAttack >= 0.05 then
        State.kingKillLastAttack = State.time
        if not isEquipped(TOOL_KW.punch) then tryEquip(TOOL_KW.punch) end
        punch()
    end
end

local function findPreferredTool()
    if State.toolPushups then local t = findTool(TOOL_KW.pushups); if t then return t end end
    if State.toolHandstands then local t = findTool(TOOL_KW.handstands); if t then return t end end
    if State.toolSitups then local t = findTool(TOOL_KW.situps); if t then return t end end
    if State.toolDumbbell then local t = findTool(TOOL_KW.dumbbell); if t then return t end end
    return nil
end
local function updateDualTool()
    if not State.dualEnabled or not State.killEnabled or not State.killTarget then return end
    if not (State.autoTrain or State.fastTrain) then return end
    local hum = Cache.hum; if not hum then return end
    if State.time - State.dualLastSwitch < 0.06 then return end
    State.dualLastSwitch = State.time
    if State.dualCurrentMode == "punch" then
        local t = findPreferredTool()
        if t then
            pcall(function() hum:EquipTool(t) end)
            State.dualCurrentMode = "train"
            task.defer(function() if not State.destroyed then pcall(function() t:Activate() end) end end)
        else State.dualCurrentMode = "punch" end
    else
        local t = findTool(TOOL_KW.punch)
        if t then
            pcall(function() hum:EquipTool(t) end)
            State.dualCurrentMode = "punch"
            task.defer(function() if not State.destroyed then pcall(function() t:Activate() end) end end)
        else State.dualCurrentMode = "train" end
    end
end

-- 宠物商店
local FALLBACK_PETS = {
    "不稳定幻影", "以太仙灵小兔", "伏特爪", "冰波传奇企鹅", "反应堆兽",
    "地狱火", "地狱火龙", "大超新星", "幻影创世龙", "星界电光",
    "暗星猎人", "核心小狗", "橙色刺猬", "橙色飞马", "永恒巨型攻击",
    "永恒打击利维坦", "熵爆炸", "电光", "白色凤凰", "白色飞马",
    "等离子掠夺者", "紫色光环", "紫色新环", "紫色猎鹰", "紫色龙",
    "红色光环", "红色小猫", "红色火龙", "红色释火者", "终极超新星飞马",
    "绿色光环", "绿色蝴蝶", "绿色释火者", "肌肉之王", "肌肉老师",
    "能量闪电", "蓝色光环", "蓝色凤凰", "顶峰霸主", "魔法蝴蝶",
    "黄色光环", "黄色蝴蝶", "黄金维金人", "黑暗德古拉", "黑暗电光",
    "黑暗蝎尾怪传奇", "黑暗闪电", "黑暗风暴", "黑暗魔像",
}
local function getPetShopRemote()
    local r = ReplicatedStorage:FindFirstChild("rEvents")
    return r and r:FindFirstChild("cPetShopRemote")
end
local function getPetShopFolder()
    local s = ReplicatedStorage:FindFirstChild("shared")
    local rt = s and s:FindFirstChild("runtime")
    return rt and rt:FindFirstChild("cPetShopFolder")
end
local function getPetShopList()
    local names = {}
    pcall(function()
        local f = getPetShopFolder()
        if f then for _, item in ipairs(f:GetChildren()) do table.insert(names, item.Name) end end
    end)
    if #names == 0 then names = FALLBACK_PETS end
    table.sort(names)
    return names
end
local function buyPet(name)
    local remote = getPetShopRemote()
    local folder = getPetShopFolder()
    if not (remote and folder) then return false, "未找到宠物商店" end
    if not name or name == "" then return false, "请先选择宠物" end
    local pet = folder:FindFirstChild(name)
    if not pet then return false, "商店里没有: " .. name end
    local ok, err = pcall(function()
        if remote:IsA("RemoteFunction") then remote:InvokeServer(pet)
        else remote:FireServer(pet) end
    end)
    if ok then return true, "已购买: " .. name end
    return false, tostring(err)
end

local function runWheel()
    pcall(function()
        local r = ReplicatedStorage:FindFirstChild("rEvents")
        local remote = r and r:FindFirstChild("openFortuneWheelRemote")
        local s = ReplicatedStorage:FindFirstChild("shared")
        local catalogs = s and s:FindFirstChild("catalogs")
        local wc = catalogs and catalogs:FindFirstChild("fortuneWheelChances")
        local wheel = wc and wc:FindFirstChild("Fortune Wheel")
        if remote and wheel then
            if remote:IsA("RemoteFunction") then remote:InvokeServer("openFortuneWheel", wheel)
            else remote:FireServer("openFortuneWheel", wheel) end
        end
    end)
end

-- Boss + 宝箱
local BOSS_NAMES = { "Boss1", "Boss2", "Boss3", "Boss4", "Boss5" }
local BOSS_IDLE_POS = V3n(1, 44, -1251)
local PUNCH_ANIMS = { left = "rbxassetid://3638729053", right = "rbxassetid://3638767427" }
local bossHoverConn = nil
local bossPunchThread, bossScanThread
local bossCurrent = "Boss1"
local _bossAliveCache, _bossAliveCacheAt = false, 0

local function findBossModel(name)
    local events = Workspace:FindFirstChild("Events")
    local arena = events and events:FindFirstChild("BossArena")
    local holder = arena and arena:FindFirstChild(name or bossCurrent)
    return holder and holder:FindFirstChild("Boss")
end
local function isBossAlive(name)
    local b = findBossModel(name); if not b then return false end
    if b:IsA("Model") then
        local h = b:FindFirstChildOfClass("Humanoid")
        return h ~= nil and h.Health > 0
    end
    return b:IsA("BasePart") and b.Transparency < 1
end
local function isAnyBossAlive()
    if State.time - _bossAliveCacheAt < 0.5 then return _bossAliveCache end
    _bossAliveCacheAt = State.time
    for _, n in ipairs(BOSS_NAMES) do
        if isBossAlive(n) then _bossAliveCache = true; return true end
    end
    _bossAliveCache = false
    return false
end
local function getBossPos()
    local b = findBossModel(); if not b then return nil end
    if b:IsA("Model") then return b:GetPivot().Position end
    return b.Position
end
local function destroyPortals()
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            if obj.Name == "RobloxForwardPortals" then obj:Destroy() end
        end
    end)
end
local function startBossHover()
    bossHoverConn = RS_RS:Connect(function()
        if not State.autoBoss then return end
        if not isAnyBossAlive() then return end
        local hrp = Cache.hrp; if not hrp then return end
        local bp = getBossPos(); if not bp then return end
        local hoverPos = bp + V3n(0, State.bossHeight, 0)
        local flat = V3n(bp.X - hoverPos.X, 0, bp.Z - hoverPos.Z)
        if flat.Magnitude < 0.1 then flat = V3n(0, 0, -1) end
        hrp.AssemblyLinearVelocity = V3n(0, 0, 0)
        hrp.AssemblyAngularVelocity = V3n(0, 0, 0)
        hrp.CFrame = CFrame.lookAt(hoverPos, hoverPos + (flat.Unit + V3n(0, -1, 0)).Unit)
    end)
end
local function bossPunchLoop()
    local useLeft, trackL, trackR = true, nil, nil
    local counter = 0
    while State.autoBoss do
        if isAnyBossAlive() and getBossPos() then
            counter = counter + 1
            if counter % 4 == 0 then
                pcall(function()
                    local bp = LocalPlayer:FindFirstChild("Backpack")
                    local pt = bp and bp:FindFirstChild("Punch")
                    local cd = pt and pt:FindFirstChildOfClass("NumberValue")
                    if cd then cd.Value = 0.01 end
                end)
            end
            pcall(function()
                local char = Cache.char
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                local bp = LocalPlayer:FindFirstChild("Backpack")
                local pt = (char and char:FindFirstChild("Punch")) or (bp and bp:FindFirstChild("Punch"))
                if pt and pt.Parent ~= char then hum:EquipTool(pt) end
                local ev = getMuscleEvent()
                if ev then ev:FireServer("punch", useLeft and "leftHand" or "rightHand") end
                local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
                local track = useLeft and trackL or trackR
                if not track then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = useLeft and PUNCH_ANIMS.left or PUNCH_ANIMS.right
                    track = animator:LoadAnimation(anim)
                    if useLeft then trackL = track else trackR = track end
                end
                if track then track:Stop(0); track:Play(0.1) end
                useLeft = not useLeft
            end)
        else
            task.wait(0.5)
        end
        task.wait(0.05)
    end
end
local function bossScanLoop()
    while State.autoBoss do
        task.wait(2)
        if State.autoBoss then
            local found = false
            for _, n in ipairs(BOSS_NAMES) do
                if isBossAlive(n) then
                    found = true
                    if n ~= bossCurrent then bossCurrent = n end
                    break
                end
            end
            if not found and not State.bossWasAlive then
                -- 什么都不做
            end
        end
    end
end

local chestTaskActive = false
local chestTaskAt = 0
local function isChestVisible()
    local chest = Workspace:FindFirstChild("BossChest")
    if not chest then return nil end
    for _, obj in ipairs(chest:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Transparency < 0.95 and obj.CanTouch ~= false then
            return chest, obj
        end
    end
    for _, name in ipairs({"BossChest", "Chest", "RewardChest"}) do
        local c = Workspace:FindFirstChild(name)
        if c then
            for _, obj in ipairs(c:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Transparency < 0.95 then
                    return c, obj
                end
            end
        end
    end
    return nil
end
local function runChestTask()
    if not State.autoChest then return end
    if isAnyBossAlive() then
        State.bossWasAlive = true
        State.bossKilledAt = 0
        return
    end
    if State.bossWasAlive and State.bossKilledAt == 0 then
        State.bossKilledAt = State.time
        State.bossWasAlive = false
    end
    if State.bossKilledAt == 0 or State.time - State.bossKilledAt < State.chestDelay then return end
    local chestModel, chestPart = isChestVisible()
    if not chestModel or not chestPart then return end

    local hrp = Cache.hrp; if not hrp then return end
    local targetCF = CN(chestPart.Position + V3n(0, 4, 0))
    pcall(function()
        hrp.CFrame = targetCF
        hrp.AssemblyLinearVelocity = V3n(0, 0, 0)
        hrp.AssemblyAngularVelocity = V3n(0, 0, 0)
    end)

    if not chestTaskActive then
        chestTaskActive = true
        task.spawn(function()
            local holdTime = State.chestHoldTime or 2
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            end)
            task.wait(holdTime)
            pcall(function()
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end)
            pcall(function()
                for _, obj in ipairs(chestModel:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and obj.Enabled then
                        fireproximityprompt(obj)
                    end
                end
            end)
            chestTaskActive = false
        end)
    end
end

-- 换包重生 / 吃蛋 / 送蛋
local PETS_DATA = {
    ["Omega Overlord"] = { repSpeed = 20 },
    ["Swift Samurai"]  = { repSpeed = 15 },
    ["Powercore Hound"]= { strength = 25, durability = 15 },
    ["Titanium Hydra"] = { rebirth = 2 },
    ["Tribal Overlord"]= { rebirth = 2 },
    ["Inferno Unicorn"]= { strength = 25, durability = 25 },
    ["Common Boss Pet"]= { repSpeed = 5 },
    ["Rare Boss Pet"]  = { repSpeed = 7 },
    ["Epic Boss Pet"]  = { repSpeed = 10 },
    ["Rainbow Boss Pet"]= { repSpeed = 10, strength = 7 },
    ["Legendary Boss Pet"] = { repSpeed = 10, strength = 10 },
    ["Mythic Boss Pet"] = { repSpeed = 10, strength = 20 },
    ["Inferno Drake"]  = { repSpeed = 40 },
}
local MAX_SLOTS = 12
local TARGET_REP = 100
local function unequipAllPets()
    local r = ReplicatedStorage:FindFirstChild("rEvents")
    local ev = r and r:FindFirstChild("equipPetEvent")
    if not ev then return end
    local pf = LocalPlayer:FindFirstChild("petsFolder"); if not pf then return end
    for _, folder in ipairs(pf:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in ipairs(folder:GetChildren()) do
                pcall(function() ev:FireServer("unequipPet", pet) end)
            end
        end
    end
    task.wait(0.1)
end
local function equipOne(pet)
    local r = ReplicatedStorage:FindFirstChild("rEvents")
    local ev = r and r:FindFirstChild("equipPetEvent")
    if ev then pcall(function() ev:FireServer("equipPet", pet) end) end
end
local function getOwnedPets()
    local out = {}
    local pf = LocalPlayer:FindFirstChild("petsFolder"); if not pf then return out end
    for _, folder in ipairs(pf:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in ipairs(folder:GetChildren()) do
                local cfg = PETS_DATA[pet.Name]
                if cfg then
                    table.insert(out, { instance = pet, name = pet.Name,
                        repSpeed = cfg.repSpeed or 0, strength = cfg.strength or 0,
                        durability = cfg.durability or 0, rebirth = cfg.rebirth or 0 })
                end
            end
        end
    end
    return out
end
local function equipFarmingPets()
    unequipAllPets()
    local pets = getOwnedPets()
    table.sort(pets, function(a, b) return a.repSpeed > b.repSpeed end)
    local equipped, count, rep = {}, 0, 0
    for _, p in ipairs(pets) do
        if count >= MAX_SLOTS or rep >= TARGET_REP then break end
        if p.repSpeed > 0 then equipOne(p.instance); equipped[p.instance] = true; count = count + 1; rep = rep + p.repSpeed end
    end
    local rest = {}
    for _, p in ipairs(pets) do if not equipped[p.instance] then table.insert(rest, p) end end
    table.sort(rest, function(a, b) return (a.strength + a.durability) > (b.strength + b.durability) end)
    for _, p in ipairs(rest) do
        if count >= MAX_SLOTS then break end
        if p.strength > 0 or p.durability > 0 then equipOne(p.instance); count = count + 1 end
    end
end
local function equipRebirthPets()
    unequipAllPets()
    local pets = getOwnedPets()
    table.sort(pets, function(a, b) return a.rebirth > b.rebirth end)
    local count = 0
    for _, p in ipairs(pets) do
        if count >= MAX_SLOTS then break end
        if p.rebirth > 0 then equipOne(p.instance); count = count + 1 end
    end
end

-- ★ v26：换包重生不再使用 trainRate，统一用 fastRate
local function performPackRebirth()
    local ev = getMuscleEvent(); if not ev then return end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local strStat = ls and ls:FindFirstChild("Strength")
    local rebStat = ls and ls:FindFirstChild("Rebirths")
    if not (strStat and rebStat) then return end
    local target = 5000 + rebStat.Value * 2550
    while strStat.Value < target and State.autoPackRebirth do
        pcall(function()
            -- 与快速锻炼频率保持一致
            local burst = math.clamp(math.floor(State.fastRate / 10), 5, 50)
            for _ = 1, burst do ev:FireServer("rep") end
        end)
        task.wait(0.01)
    end
    equipRebirthPets()
    task.wait(0.25)
    local before = rebStat.Value
    local tries = 0
    repeat
        fireRebirth()
        task.wait(0.05)
        tries = tries + 1
    until rebStat.Value > before or tries > 20
end
local function packRebirthLoop()
    while State.autoPackRebirth do
        equipFarmingPets()
        performPackRebirth()
        task.wait(0.5)
    end
end

local function findProteinEgg()
    local c = Cache.char
    local bp = LocalPlayer:FindFirstChild("Backpack")
    return (c and c:FindFirstChild("Protein Egg")) or (bp and bp:FindFirstChild("Protein Egg"))
end
local function eatEggLoop()
    local ev = getMuscleEvent()
    while State.autoEatEgg do
        pcall(function()
            local egg = findProteinEgg()
            if egg and ev then
                for _ = 1, 10 do ev:FireServer("proteinEgg", egg) end
            end
        end)
        task.wait(0.5)
    end
end
local function giftEggsTo(target, amount)
    local r = ReplicatedStorage:FindFirstChild("rEvents")
    local giftRemote = r and r:FindFirstChild("giftRemote")
    local folder = LocalPlayer:FindFirstChild("consumablesFolder")
    if not (giftRemote and folder and target) then return 0 end
    local sent = 0
    for _ = 1, amount do
        local egg = folder:FindFirstChild("Protein Egg")
        if not egg then break end
        local ok = pcall(function() giftRemote:InvokeServer("giftRequest", target, egg) end)
        if ok then sent = sent + 1 end
        task.wait(0.1)
    end
    return sent
end

-- 自适应
local function cleanupTrainingState()
    State.trainAccum = 0; State.degradeLevel = 0
    State.fpsWinTime = 0; State.fpsWinFrames = 0
    State.adaptiveStableCount = 0; State.adaptiveStep = 100
end
local function runAdaptive()
    if not State.adaptiveEnabled or not State.fastTrain then return end
    if State.time - State.lastAdaptiveAt < 1 then return end
    State.lastAdaptiveAt = State.time
    local fps = State.avgFps
    local th = State.adaptiveThreshold or 30
    if fps < th then
        local r = fps / th
        local new = math.max(1, math.floor(State.fastRate * (r < 0.4 and 0.4 or r < 0.7 and 0.7 or 0.9)))
        if new ~= State.fastRate then
            State.fastRate = new; State.adaptiveStep = 100; State.adaptiveStableCount = 0
            if State.ui.rateBox then State.ui.rateBox.Text = tostring(new) end
        end
    else
        if fps > th * 1.15 then
            State.adaptiveStableCount = State.adaptiveStableCount + 1
            if State.adaptiveStableCount >= 2 then
                State.fastRate = math.min(50000, State.fastRate + State.adaptiveStep)
                State.adaptiveStep = math.min(2000, State.adaptiveStep * 2)
                State.adaptiveStableCount = 0
                if State.ui.rateBox then State.ui.rateBox.Text = tostring(State.fastRate) end
            end
        else State.adaptiveStableCount = 0 end
    end
end
local function handleDegradation()
    if State.time - State.lastDegradeAt < 3 then return end
    State.lastDegradeAt = State.time
    if State.degradeLevel == 0 then
        State.degradeLevel = 1; State.fastRate = 500
        if State.ui.rateBox then State.ui.rateBox.Text = "500" end
        notify("卡顿已降至 500 次/秒", 3)
    elseif State.degradeLevel == 1 then
        State.degradeLevel = 2; State.fastRate = 100
        if State.ui.rateBox then State.ui.rateBox.Text = "100" end
        notify("仍卡顿，降至 100 次/秒", 3)
    elseif State.degradeLevel == 2 then
        State.degradeLevel = 3; State.fastTrain = false; State.autoTrain = false
        if State.ui.fastToggle then State.ui.fastToggle.set(false) end
        if State.ui.trainToggle then State.ui.trainToggle.set(false) end
        cleanupTrainingState()
        notify("设备太弱，已关闭锻炼", 6)
    end
end

-- 任务链
local TaskPriority = {
    AFK = 200,
    CHEST = 195,
    BOSS = 190,
    KING_KILL = 180,
    KILL = 150,
    DUAL = 140,
    REBIRTH = 120,
    WHEEL = 110,
    TELEPORT = 100,
    CAMERA = 90,
    INFO = 85,
    PETBUY = 82,
    TOOL = 80,
    TRAIN = 60,
    EGG = 58,
    PACKREBIRTH = 56,
    ANTILAG = 40,
    CULL = 35,
    HIDER = 30,
    TEX = 25,
    FRIEND = 22,
    SWEEP = 20,
    SAVE = 10,
}
local TaskChain = {}
local function register(t)
    table.insert(TaskChain, t)
    table.sort(TaskChain, function(a, b) return a.priority > b.priority end)
end

register({ id = "afk", priority = TaskPriority.AFK,
    enabled = function() return true end,
    tick = function()
        if State.time - State.lastAFKClick >= 60 then
            State.lastAFKClick = State.time
            local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or V2n(1920, 1080)
            local x, y = vp.X - 8, vp.Y - 8
            local ox, oy = 0, 0
            local ok, ml = pcall(UIS_GML, UserInputService)
            if ok and ml then ox, oy = ml.X, ml.Y end
            if type(mousemoveabs) == "function" then
                pcall(function() mousemoveabs(x, y); mouse1click(); mousemoveabs(ox, oy) end)
            end
            pcall(function()
                VirtualUser:Button2Down(V2n(0, 0), Workspace.CurrentCamera.CFrame)
                task.wait(0.05)
                VirtualUser:Button2Up(V2n(0, 0), Workspace.CurrentCamera.CFrame)
            end)
        end
    end,
})

register({ id = "chest", priority = TaskPriority.CHEST,
    enabled = function() return State.autoChest end,
    tick = runChestTask,
})

register({ id = "boss", priority = TaskPriority.BOSS,
    enabled = function() return State.autoBoss end,
    onEnable = function()
        if not bossPunchThread or coroutine.status(bossPunchThread) == "dead" then
            destroyPortals(); startBossHover()
            bossPunchThread = task.spawn(bossPunchLoop)
            bossScanThread = task.spawn(bossScanLoop)
        end
    end,
    onDisable = function()
        if bossHoverConn then pcall(function() bossHoverConn:Disconnect() end); bossHoverConn = nil end
        if bossPunchThread then pcall(function() task.cancel(bossPunchThread) end); bossPunchThread = nil end
        if bossScanThread then pcall(function() task.cancel(bossScanThread) end); bossScanThread = nil end
    end,
    tick = function()
        if isAnyBossAlive() and State.killEnabled then
            State.killEnabled = false
            if State.ui.killToggle then State.ui.killToggle.set(false) end
            notify("检测到 Boss，自动杀戮已暂停", 4)
        end
    end,
})
register({ id = "kingKill", priority = TaskPriority.KING_KILL,
    enabled = function()
        return State.autoKingKill and not (State.autoBoss and isAnyBossAlive())
    end,
    onDisable = function() State.kingKillTarget = nil; State.kingKillActive = false end,
    tick = runKingKillTick,
})
register({ id = "kill", priority = TaskPriority.KILL,
    enabled = function()
        return State.killEnabled and not State.kingKillActive
            and not (State.autoBoss and isAnyBossAlive())
    end,
    onEnable = function()
        State.killSavedState = { autoTeleport = State.autoTeleport }
        State.autoTeleport = false
        if State.ui.teleToggle then State.ui.teleToggle.set(false) end
        State.killTarget = nil; State.killScanAt = 0; State.dualCurrentMode = "punch"
    end,
    onDisable = function()
        if State.killSavedState then
            State.autoTeleport = State.killSavedState.autoTeleport
            if State.ui.teleToggle then State.ui.teleToggle.set(State.autoTeleport) end
            State.killSavedState = nil
        end
        State.killTarget = nil; State.toolOwnedByKill = false; State.dualCurrentMode = "punch"
    end,
    tick = runKillTick,
})
register({ id = "dual", priority = TaskPriority.DUAL,
    enabled = function()
        return State.dualEnabled and State.killEnabled and State.killTarget ~= nil
            and (State.autoTrain or State.fastTrain) and not State.kingKillActive
            and not (State.autoBoss and isAnyBossAlive())
    end,
    onDisable = function() State.dualCurrentMode = "punch" end,
    tick = updateDualTool,
})
register({ id = "rebirth", priority = TaskPriority.REBIRTH,
    enabled = function() return State.autoRebirth end,
    tick = function()
        local interval = 1 / math.max(1, State.rebirthRate)
        if State.time - State.lastRebirthAt >= interval then
            State.lastRebirthAt = State.time
            fireRebirth()
        end
    end,
})
register({ id = "wheel", priority = TaskPriority.WHEEL,
    enabled = function() return State.autoWheel end,
    onEnable = function() task.spawn(function() while State.autoWheel do runWheel(); task.wait(1) end end) end,
    tick = function() end,
})
register({ id = "teleport", priority = TaskPriority.TELEPORT,
    enabled = function()
        return State.autoTeleport and not State.killEnabled
            and not State.kingKillActive
            and not (State.autoBoss and isAnyBossAlive())
    end,
    tick = function()
        if State.time - State.lastTeleportAt >= 0.05 then
            State.lastTeleportAt = State.time
            teleportMuscleKing()
        end
    end,
})
register({ id = "camera", priority = TaskPriority.CAMERA,
    enabled = function() return State.killEnabled or State.autoTeleport or State.kingKillActive or State.autoBoss end,
    tick = function()
        if State.time - State.lastCameraFix >= 0.5 then
            State.lastCameraFix = State.time
            local cam = Workspace.CurrentCamera
            local hum = Cache.hum
            if cam and hum and hum.Parent then
                pcall(function()
                    if cam.CameraSubject ~= hum then cam.CameraSubject = hum end
                    if cam.CameraType ~= E_CamCustom then cam.CameraType = E_CamCustom end
                end)
            end
        end
    end,
})
register({ id = "info", priority = TaskPriority.INFO,
    enabled = function() return State.infoWindowEnabled end,
    tick = function()
        if State.time - State.strengthCheckAt >= 1 then
            State.strengthCheckAt = State.time
            local s = myStrength()
            if State.sessionStartStrength == nil then
                State.sessionStartStrength = s; State.lastStrengthSnapshot = s
            else
                local d = s - State.lastStrengthSnapshot
                if d >= 0 then State.strengthPerSec = State.strengthPerSec * 0.7 + d * 0.3 end
                State.lastStrengthSnapshot = s
            end
        end
        if State.time - RepCache.lastRefresh >= 1 then
            RepCache.lastRefresh = State.time; refreshRepSpeed()
        end
        if State.time - State.lastPingCheck >= 1 then
            State.lastPingCheck = State.time
            pcall(function()
                State.ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
        end
        if State.time - State.infoLastRefresh >= 0.2 then
            State.infoLastRefresh = State.time
            refreshInfoWindow()
        end
    end,
})
register({ id = "petbuy", priority = TaskPriority.PETBUY,
    enabled = function() return State.autoPetBuy and State.selectedPet ~= "" end,
    tick = function()
        if State.time - (State._petBuyLast or 0) >= 0.5 then
            State._petBuyLast = State.time
            buyPet(State.selectedPet)
        end
    end,
})
register({ id = "tool", priority = TaskPriority.TOOL,
    enabled = function()
        return (State.autoTrain or State.fastTrain)
            and not State.toolCooldown and not State.toolOwnedByKill and not State.kingKillActive
    end,
    tick = function()
        if State.time - State.lastToolCheck < 0.1 then return end
        State.lastToolCheck = State.time
        local sel = {}
        if State.toolPushups then table.insert(sel, TOOL_KW.pushups) end
        if State.toolHandstands then table.insert(sel, TOOL_KW.handstands) end
        if State.toolSitups then table.insert(sel, TOOL_KW.situps) end
        if State.toolDumbbell then table.insert(sel, TOOL_KW.dumbbell) end
        if #sel == 0 then State._missingSince = 0; return end
        local equipped = false
        for _, kw in ipairs(sel) do if tryEquip(kw) then equipped = true; break end end
        if equipped then State._missingSince = 0; return end
        local anyExist = false
        for _, kw in ipairs(sel) do if toolExists(kw) then anyExist = true; break end end
        if anyExist then State._missingSince = 0; return end
        if State._missingSince == 0 then State._missingSince = State.time end
        if State.time - State._missingSince < 1.0 then return end
        if State.time - State._lastSuicide < 60 then return end
        State._lastSuicide = State.time
        State._suicideCount = (State._suicideCount or 0) + 1
        if State._suicideCount <= 3 then
            State.toolCooldown = true
            notify(string.format("未找到训练工具，第 %d 次重生", State._suicideCount), 4)
            suicide()
            task.delay(15, function() if not State.destroyed then State.toolCooldown = false end end)
        else
            notify("连续找不到工具，已停止自动切换", 6)
        end
    end,
})
register({ id = "train", priority = TaskPriority.TRAIN,
    enabled = function()
        return (State.autoTrain or State.fastTrain) and not State.kingKillActive and not State.autoPackRebirth
    end,
    tick = function(dt)
        local rate = State.fastTrain and State.fastRate or (State.autoTrain and 10 or 0)
        if rate <= 0 then return end
        State.trainAccum = State.trainAccum + rate * dt
        local count = math.floor(State.trainAccum)
        if count <= 0 then return end
        State.trainAccum = State.trainAccum - count
        if count > 3000 then count = 3000 end
        local ev = getMuscleEvent()
        if ev then
            pcall(function()
                for _ = 1, count do ev:FireServer("rep") end
            end)
        end
    end,
})
register({ id = "packrebirth", priority = TaskPriority.PACKREBIRTH,
    enabled = function() return State.autoPackRebirth end,
    onEnable = function() task.spawn(packRebirthLoop) end,
    tick = function() end,
})
-- ★ v26：删除了 fasttrain 任务（原来它和 train 任务重复发包，导致快速锻炼失效）
register({ id = "egg", priority = TaskPriority.EGG,
    enabled = function() return State.autoEatEgg end,
    onEnable = function() task.spawn(eatEggLoop) end,
    tick = function() end,
})
register({ id = "antilag", priority = TaskPriority.ANTILAG,
    enabled = function() return State.antiLagEnabled end,
    onEnable = function() pcall(enableAntiLag) end,
    onDisable = function() pcall(disableAntiLag) end,
    tick = function() if AntiLag.enabled and State.time >= AntiLag.rescanAt then rescanAntiLag() end end,
})
register({ id = "cull", priority = TaskPriority.CULL,
    enabled = function() return State.renderCullEnabled end,
    onEnable = function() RenderCull.rescanAt = 0 end,
    onDisable = function() pcall(disableRenderCull) end,
    tick = function() if State.time >= RenderCull.rescanAt then scanRenderCull() end end,
})
register({ id = "hider", priority = TaskPriority.HIDER,
    enabled = function() return State.hideOwnPets or State.hideAllPets or State.hideMachines end,
    onEnable = function() PetHider.rescanAt = 0 end,
    onDisable = function() pcall(restoreHiddenPets); pcall(restoreHiddenMachines) end,
    tick = function()
        if State.time >= PetHider.rescanAt then
            pcall(restoreHiddenPets); pcall(restoreHiddenMachines)
            scanHidePets(); scanHideMachines()
        end
    end,
})
register({ id = "tex", priority = TaskPriority.TEX,
    enabled = function() return State.textureRemoverEnabled end,
    onEnable = function() pcall(enableTex) end,
    onDisable = function() pcall(disableTex) end,
    tick = function() if TexRem.enabled and State.time >= TexRem.rescanAt then rescanTex() end end,
})
register({ id = "friend", priority = TaskPriority.FRIEND,
    enabled = function() return State.friendWhitelist end,
    onEnable = function() if not FriendWhitelist.loaded then refreshFriendList() end end,
    tick = function()
        if FriendWhitelist.refreshing then return end
        if not FriendWhitelist.loaded then refreshFriendList()
        elseif tick() - FriendWhitelist.lastRefresh >= 300 then refreshFriendList() end
    end,
})
register({ id = "sweep", priority = TaskPriority.SWEEP,
    enabled = function() return true end,
    tick = function()
        if State.time - State.lastSweepAt >= 30 then State.lastSweepAt = State.time; pcall(sweepOverflow) end
    end,
})
register({ id = "save", priority = TaskPriority.SAVE,
    enabled = function() return true end,
    tick = function()
        if State.time - State.lastSaveAt >= 2 then State.lastSaveAt = State.time; task.spawn(saveConfig) end
    end,
})

local function updateGlobal(dt)
    local wantZero = State.killEnabled or State.autoTeleport or State.kingKillActive
    if wantZero then
        if Workspace.Gravity ~= 0 then pcall(function() Workspace.Gravity = 0 end) end
    else
        if Workspace.Gravity ~= State.originalGravity then
            pcall(function() Workspace.Gravity = State.originalGravity end)
        end
    end
    State.fpsWinTime = State.fpsWinTime + dt
    State.fpsWinFrames = State.fpsWinFrames + 1
    if State.fpsWinTime >= 0.5 then
        State.avgFps = State.fpsWinFrames / State.fpsWinTime
        State.fpsWinTime = 0; State.fpsWinFrames = 0
        if State.fastTrain then
            if State.adaptiveEnabled then runAdaptive()
            elseif State.avgFps < 5 then handleDegradation() end
        end
    end
    if State.sessionStartStrength == nil then
        State.sessionStartStrength = myStrength()
        State.lastStrengthSnapshot = State.sessionStartStrength
    end
end

local function onHeartbeat(dt)
    if State.destroyed then return end
    State.time = State.time + dt
    refreshCache()
    updateGlobal(dt)
    for i = 1, #TaskChain do
        local task = TaskChain[i]
        local ok, en = pcall(task.enabled)
        if not ok then en = false end
        if not en then
            if task._wasActive then
                task._wasActive = false
                if task.onDisable then pcall(task.onDisable) end
            end
        else
            if not task._wasActive then
                task._wasActive = true
                if task.onEnable then pcall(task.onEnable) end
            end
            local ok2, err = pcall(task.tick, dt)
            if not ok2 and not task._errWarned then
                task._errWarned = true
                warn("[Task:" .. task.id .. "]", err)
            end
        end
    end
end

local function destroy()
    if State.destroyed then return end
    pcall(saveConfig)
    State.destroyed = true
    for _, c in ipairs(State.conns) do pcall(function() c:Disconnect() end) end
    table.clear(State.conns)
    pcall(function() Workspace.Gravity = State.originalGravity end)
    pcall(disableAntiLag); pcall(disableRenderCull)
    pcall(restoreHiddenPets); pcall(restoreHiddenMachines)
    pcall(disableTex); pcall(restoreHiddenUI)
    if bossHoverConn then pcall(function() bossHoverConn:Disconnect() end) end
    if State.ui.screen then pcall(function() State.ui.screen:Destroy() end); State.ui.screen = nil end
    if State.ui.infoGui then pcall(function() State.ui.infoGui:Destroy() end); State.ui.infoGui = nil end
    if _G[SCRIPT_ID] and _G[SCRIPT_ID].version == VERSION then _G[SCRIPT_ID] = nil end
end

local ResetBtnState = { pressAt = 0, holding = false, lastStep = 0 }
local function doResetAll()
    State.uiWidthPct = DEFAULT.uiWidthPct
    State.uiHeightPct = DEFAULT.uiHeightPct
    if State.ui.main then State.ui.main.Position = DEFAULT.mainPos end
    if Info.frames.frame then
        Info.frames.frame.Position = DEFAULT.infoPos
        Info.minimized = false
        Info.frames.frame.Size = UD2o(300, 460)
        if Info.frames.playerBtn then Info.frames.playerBtn.Visible = true end
        if Info.frames.dataFrame then Info.frames.dataFrame.Visible = true end
    end
    applyUISize()
    pcall(saveConfig)
    notify("已复位", 3)
end
local function buildResetButton()
    local screen = State.ui.screen; if not screen then return end
    local btn = create("TextButton", {
        Name = "ResetBtn", AnchorPoint = V2n(0, 1),
        Position = UD2n(0, 16, 1, -16), Size = UD2o(44, 44),
        BackgroundColor3 = Theme.Surface, BackgroundTransparency = 0.1,
        BorderSizePixel = 0, Text = "复位",
        Font = Font.GothamBold, TextColor3 = Theme.TextDim, TextSize = 12,
        ZIndex = 150,
    }, screen)
    corner(btn, 22); stroke(btn, Theme.Border, 1, 0.4)
    State.ui.resetBtn = btn
    track(btn.InputBegan:Connect(function(input)
        if input.UserInputType ~= E_UI_MB1 and input.UserInputType ~= E_UI_Touch then return end
        ResetBtnState.pressAt = tick(); ResetBtnState.holding = true; ResetBtnState.lastStep = 0
    end))
    track(btn.InputEnded:Connect(function(input)
        if input.UserInputType == E_UI_MB1 or input.UserInputType == E_UI_Touch then
            ResetBtnState.holding = false; ResetBtnState.pressAt = 0
            btn.BackgroundColor3 = Theme.Surface; btn.TextColor3 = Theme.TextDim; btn.Text = "复位"
        end
    end))
end
local function tickResetButton()
    if not ResetBtnState.holding then return end
    local btn = State.ui.resetBtn; if not btn then return end
    local elapsed = tick() - ResetBtnState.pressAt
    local step = math.floor(elapsed)
    if step ~= ResetBtnState.lastStep and step <= 3 then
        ResetBtnState.lastStep = step
        btn.Text = tostring(3 - step) .. "s"
        if step == 1 then btn.BackgroundColor3 = Theme.Warning; btn.TextColor3 = C3(20, 20, 20)
        elseif step == 2 then btn.BackgroundColor3 = C3(240, 130, 60); btn.TextColor3 = C3(20, 20, 20) end
    end
    if elapsed >= 3 then
        ResetBtnState.holding = false; ResetBtnState.pressAt = 0
        btn.BackgroundColor3 = Theme.Success; btn.Text = "OK"; btn.TextColor3 = C3(20, 20, 20)
        doResetAll()
        task.delay(1, function()
            if btn and btn.Parent then
                btn.BackgroundColor3 = Theme.Surface; btn.TextColor3 = Theme.TextDim; btn.Text = "复位"
            end
        end)
    end
end

-- 信息悬浮窗
local Info = { viewingPlayer = nil, listOpen = false, minimized = false, rows = {}, frames = {} }
local function buildInfoWindow()
    local screen = create("ScreenGui", {
        Name = "MuscleKingInfoUI", ResetOnSpawn = false,
        ZIndexBehavior = E_ZIdx, DisplayOrder = 99998,
    }, PlayerGui)
    State.ui.infoGui = screen
    screen.Enabled = false

    local us = create("UIScale", { Scale = 1 }, screen)
    State.ui.infoScale = us

    local frame = create("Frame", {
        Name = "InfoFrame", AnchorPoint = V2n(0, 0),
        Position = DEFAULT.infoPos, Size = UD2o(300, 460),
        BackgroundColor3 = Theme.Bg, BorderSizePixel = 0,
        ClipsDescendants = true, Active = true,
    }, screen)
    Info.frames.frame = frame
    corner(frame, 12); stroke(frame, Theme.Border, 1)

    local tb = create("Frame", {
        Size = UD2n(1, 0, 0, 34), BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0, Active = true,
    }, frame)
    corner(tb, 12)
    create("TextLabel", {
        BackgroundTransparency = 1, Position = UD2o(12, 0),
        Size = UD2n(1, -80, 1, 0),
        Font = Font.GothamBold, Text = "实时信息",
        TextColor3 = Theme.Text, TextSize = 14, TextXAlignment = E_TxtXL,
    }, tb)
    local minBtn = create("TextButton", {
        Size = UD2o(22, 22), Position = UD2n(1, -50, 0, 6),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "-", TextColor3 = Theme.TextDim, TextSize = 14,
    }, tb); corner(minBtn, 6)
    local closeBtn = create("TextButton", {
        Size = UD2o(22, 22), Position = UD2n(1, -26, 0, 6),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "x", TextColor3 = Theme.TextDim, TextSize = 14,
    }, tb); corner(closeBtn, 6)

    local playerBtn = create("TextButton", {
        Position = UD2o(10, 42), Size = UD2n(1, -20, 0, 30),
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        Font = Font.GothamMedium, Text = "查看：自己",
        TextColor3 = Theme.Text, TextSize = 13,
    }, frame)
    corner(playerBtn, 8); stroke(playerBtn, Theme.Border, 1, 0.5)
    Info.frames.playerBtn = playerBtn

    local listFrame = create("ScrollingFrame", {
        Position = UD2o(10, 76), Size = UD2n(1, -20, 0, 150),
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UD2n(0, 0, 0, 0), AutomaticCanvasSize = E_AS_Y,
        ScrollingDirection = E_ScrollY, Visible = false, ZIndex = 5,
    }, frame)
    corner(listFrame, 8); stroke(listFrame, Theme.Border, 1)
    listLayout(listFrame, 2); padding(listFrame, 4, 4, 4, 4)
    Info.frames.listFrame = listFrame

    local dataFrame = create("ScrollingFrame", {
        Position = UD2o(0, 114), Size = UD2n(1, 0, 1, -114),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 5, ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UD2n(0, 0, 0, 0), AutomaticCanvasSize = E_AS_Y,
        ScrollingDirection = E_ScrollY, ClipsDescendants = true,
    }, frame)
    padding(dataFrame, 6, 6, 10, 10)
    listLayout(dataFrame, 4)
    Info.frames.dataFrame = dataFrame

    local resizeHandle = create("TextButton", {
        Size = UD2o(16, 16), Position = UD2n(1, -18, 1, -18),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
        Text = "", ZIndex = 10,
    }, frame)
    corner(resizeHandle, 4)

    local function createRow(label, order)
        local row = create("Frame", {
            Size = UD2n(1, 0, 0, 23), BackgroundTransparency = 1, LayoutOrder = order,
        }, dataFrame)
        create("TextLabel", {
            BackgroundTransparency = 1, Size = UD2n(0.55, 0, 1, 0),
            Font = Font.GothamMedium, Text = label,
            TextColor3 = Theme.TextDim, TextSize = 13, TextXAlignment = E_TxtXL,
        }, row)
        local val = create("TextLabel", {
            BackgroundTransparency = 1, Position = UD2n(0.55, 0, 0, 0),
            Size = UD2n(0.45, 0, 1, 0),
            Font = Font.GothamBold, Text = "-",
            TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = E_TxtXR,
        }, row)
        return val
    end
    Info.rows.strength   = createRow("力量", 1)
    Info.rows.strengthDelta = createRow("力量增量", 2)
    Info.rows.gems       = createRow("宝石", 3)
    Info.rows.durability = createRow("耐力", 4)
    Info.rows.agility    = createRow("敏捷", 5)
    Info.rows.rebirths   = createRow("重生", 6)
    Info.rows.petRep     = createRow("宠物反复%", 7)
    Info.rows.ultRep     = createRow("终极反复%", 8)
    Info.rows.passRep    = createRow("通行证", 9)
    Info.rows.speedMul   = createRow("综合速度", 10)
    Info.rows.perHour    = createRow("每小时预计", 11)
    Info.rows.perDay     = createRow("每天预计", 12)
    Info.rows.perMonth   = createRow("每月预计", 13)
    Info.rows.pingRow    = createRow("网络延迟", 14)
    Info.rows.friendRow  = createRow("好友白名单", 15)

    local dragging, dragStart, startPos = false, nil, nil
    track(tb.InputBegan:Connect(function(input)
        if input.UserInputType ~= E_UI_MB1 and input.UserInputType ~= E_UI_Touch then return end
        local ap = closeBtn.AbsolutePosition; local as = closeBtn.AbsoluteSize
        if input.Position.X >= ap.X and input.Position.X <= ap.X + as.X
        and input.Position.Y >= ap.Y and input.Position.Y <= ap.Y + as.Y then return end
        local mp = minBtn.AbsolutePosition; local ms = minBtn.AbsoluteSize
        if input.Position.X >= mp.X and input.Position.X <= mp.X + ms.X
        and input.Position.Y >= mp.Y and input.Position.Y <= mp.Y + ms.Y then return end
        dragging = true; dragStart = input.Position; startPos = frame.Position
    end))
    track(UIS_IC:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= E_UI_MMove and input.UserInputType ~= E_UI_Touch then return end
        local d = input.Position - dragStart
        frame.Position = UD2n(startPos.X.Scale, startPos.X.Offset + d.X,
                               startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end))
    track(UIS_IE:Connect(function(input)
        if input.UserInputType == E_UI_MB1 or input.UserInputType == E_UI_Touch then dragging = false end
    end))

    local resizing, resizeStart, resizeStartSize = false, nil, nil
    track(resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType ~= E_UI_MB1 and input.UserInputType ~= E_UI_Touch then return end
        resizing = true; resizeStart = input.Position; resizeStartSize = frame.Size
    end))
    track(UIS_IC:Connect(function(input)
        if not resizing then return end
        if input.UserInputType ~= E_UI_MMove and input.UserInputType ~= E_UI_Touch then return end
        local d = input.Position - resizeStart
        local nw = math.max(220, math.min(600, resizeStartSize.X.Offset + d.X))
        local nh = math.max(200, math.min(700, resizeStartSize.Y.Offset + d.Y))
        frame.Size = UD2o(nw, nh)
    end))
    track(UIS_IE:Connect(function(input)
        if input.UserInputType == E_UI_MB1 or input.UserInputType == E_UI_Touch then resizing = false end
    end))

    track(minBtn.MouseButton1Click:Connect(function()
        Info.minimized = not Info.minimized
        if Info.minimized then
            playerBtn.Visible = false; listFrame.Visible = false; dataFrame.Visible = false
            resizeHandle.Visible = false
            frame.Size = UD2o(300, 34); minBtn.Text = "+"
        else
            playerBtn.Visible = true; dataFrame.Visible = true
            resizeHandle.Visible = true
            frame.Size = UD2o(300, 460); minBtn.Text = "-"
        end
    end))
    track(closeBtn.MouseButton1Click:Connect(function()
        State.infoWindowEnabled = false; screen.Enabled = false
        Info.listOpen = false; listFrame.Visible = false
        if State.ui.infoToggle then State.ui.infoToggle.set(false) end
    end))
    track(playerBtn.MouseButton1Click:Connect(function()
        Info.listOpen = not Info.listOpen
        listFrame.Visible = Info.listOpen
        if Info.listOpen then
            for _, c in ipairs(listFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            local ord = 0
            local function addRow(plr)
                ord = ord + 1
                local nm
                if plr == LocalPlayer then nm = plr.Name .. " (自己)"
                else nm = plr.Name end
                if State.friendWhitelist and plr ~= LocalPlayer and isFriend(plr) then nm = nm .. " [友]" end
                local b = create("TextButton", {
                    Size = UD2n(1, 0, 0, 25), BackgroundColor3 = Theme.SurfaceAlt,
                    BorderSizePixel = 0, Font = Font.GothamMedium,
                    Text = nm, TextColor3 = Theme.Text, TextSize = 13, LayoutOrder = ord,
                }, listFrame)
                corner(b, 6)
                track(b.MouseButton1Click:Connect(function()
                    Info.viewingPlayer = plr
                    if plr == LocalPlayer then playerBtn.Text = "查看：自己"
                    else playerBtn.Text = "查看：" .. plr.Name end
                    Info.listOpen = false; listFrame.Visible = false
                end))
            end
            addRow(LocalPlayer)
            for _, plr in ipairs(GetPlayers(Players)) do
                if plr ~= LocalPlayer then addRow(plr) end
            end
        end
    end))
    track(UIS_IB:Connect(function(input)
        if not Info.listOpen then return end
        if input.UserInputType ~= E_UI_MB1 and input.UserInputType ~= E_UI_Touch then return end
        local lp = listFrame.AbsolutePosition; local ls = listFrame.AbsoluteSize
        local pb = playerBtn.AbsolutePosition; local ps = playerBtn.AbsoluteSize
        local ip = input.Position
        local inL = ip.X >= lp.X and ip.X <= lp.X + ls.X and ip.Y >= lp.Y and ip.Y <= lp.Y + ls.Y
        local inB = ip.X >= pb.X and ip.X <= pb.X + ps.X and ip.Y >= pb.Y and ip.Y <= pb.Y + ps.Y
        if not inL and not inB then Info.listOpen = false; listFrame.Visible = false end
    end))
    Info.viewingPlayer = LocalPlayer
end

function refreshInfoWindow()
    if not Info.frames or not Info.frames.frame or not State.ui.infoGui then return end
    if not State.ui.infoGui.Enabled or Info.minimized then return end
    local plr = Info.viewingPlayer
    if not plr or not plr.Parent then
        Info.viewingPlayer = LocalPlayer; plr = LocalPlayer
        if Info.frames.playerBtn then Info.frames.playerBtn.Text = "查看：自己" end
    end
    Info.rows.strength.Text = formatNumber(stat(plr, "Strength"))
    Info.rows.gems.Text = formatNumber(stat(plr, "Gems"))
    Info.rows.durability.Text = formatNumber(stat(plr, "Durability"))
    Info.rows.agility.Text = formatNumber(stat(plr, "Agility"))
    Info.rows.rebirths.Text = formatNumber(stat(plr, "Rebirths"))
    if plr == LocalPlayer then
        if State.sessionStartStrength then
            local d = stat(plr, "Strength") - State.sessionStartStrength
            Info.rows.strengthDelta.Text = (d >= 0 and "+" or "") .. formatNumber(d)
            Info.rows.strengthDelta.TextColor3 = d >= 0 and Theme.Success or Theme.Danger
        end
        Info.rows.petRep.Text = string.format("%d%%", RepCache.pet)
        Info.rows.petRep.TextColor3 = RepCache.pet >= 100 and Theme.Success or Theme.Text
        Info.rows.ultRep.Text = string.format("%d%%", RepCache.ult)
        Info.rows.ultRep.TextColor3 = RepCache.ult > 0 and Theme.Success or Theme.TextDim
        Info.rows.passRep.Text = RepCache.x2 and "x2" or "无"
        Info.rows.passRep.TextColor3 = RepCache.x2 and Theme.Success or Theme.TextDim
        Info.rows.speedMul.Text = string.format("%.2fx", RepCache.speedMul)
        Info.rows.speedMul.TextColor3 = RepCache.speedMul >= 2 and Theme.Success or Theme.Text
        local s = State.strengthPerSec
        Info.rows.perHour.Text = formatNumber(s * 3600)
        Info.rows.perDay.Text = formatNumber(s * 86400)
        Info.rows.perMonth.Text = formatNumber(s * 2592000)
        local p = State.ping
        Info.rows.pingRow.Text = p > 0 and (math.floor(p) .. " ms") or "-"
        if p > 0 then
            Info.rows.pingRow.TextColor3 = p < 80 and Theme.Success or (p < 200 and Theme.Warning or Theme.Danger)
        end
        if State.friendWhitelist then
            if FriendWhitelist.loaded then
                Info.rows.friendRow.Text = string.format("已加载 %d 人", State.friendCount)
                Info.rows.friendRow.TextColor3 = Theme.Success
            else
                Info.rows.friendRow.Text = "加载中"
                Info.rows.friendRow.TextColor3 = Theme.Warning
            end
        else
            Info.rows.friendRow.Text = "关闭"
            Info.rows.friendRow.TextColor3 = Theme.TextDim
        end
    else
        for _, k in ipairs({"strengthDelta","petRep","ultRep","passRep","speedMul","perHour","perDay","perMonth","pingRow","friendRow"}) do
            Info.rows[k].Text = "-"
        end
    end
end

function applyUISize()
    if not State.ui.main then return end
    local cam = Workspace.CurrentCamera; if not cam then return end
    local vp = cam.ViewportSize
    local w = math.max(360, vp.X * State.uiWidthPct / 100)
    local h = math.max(260, vp.Y * State.uiHeightPct / 100)
    State.ui.main.Size = UD2o(w, h)
    if State.ui.contentArea then
        State.ui.contentArea.Size = UD2n(1, 0, 1, -(44 + 36))
    end
    if State.ui.infoScale then
        local s = math.clamp(vp.Y / 900, 0.7, 1.6) * (State.infoScale / 100)
        State.ui.infoScale.Scale = s
    end
end

local function applyUIOpacity()
    if State.ui.main then
        State.ui.main.BackgroundTransparency = 1 - State.uiBgOpacity
    end
    if State.ui.contentArea then
        State.ui.contentArea.BackgroundTransparency = 1 - State.uiPageOpacity
    end
    if Info.frames.frame then
        Info.frames.frame.BackgroundTransparency = 1 - State.infoBgOpacity
    end
end

local function buildUI()
    local screen = create("ScreenGui", {
        Name = "MuscleKingAutoUI", ResetOnSpawn = false,
        ZIndexBehavior = E_ZIdx, DisplayOrder = 99999,
    }, PlayerGui)
    State.ui.screen = screen

    local main = create("Frame", {
        Name = "Main", AnchorPoint = V2n(0, 0),
        Position = DEFAULT.mainPos,
        Size = UD2o(520, 380),
        BackgroundColor3 = Theme.Bg, BorderSizePixel = 0,
        ClipsDescendants = true, Active = true,
    }, screen)
    State.ui.main = main
    corner(main, 12); stroke(main, Theme.Border, 1)

    local titleBar = create("Frame", {
        Name = "TitleBar", Size = UD2n(1, 0, 0, 44),
        Position = UD2o(0, 0), BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0, Active = true,
    }, main)
    corner(titleBar, 12)
    create("Frame", {
        Size = UD2n(1, 0, 0, 12), Position = UD2n(0, 0, 1, -12),
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
    }, titleBar)
    create("TextLabel", {
        BackgroundTransparency = 1, Position = UD2o(16, 0),
        Size = UD2n(1, -110, 1, 0),
        Font = Font.GothamBold, Text = "肌肉之王自动化",
        TextColor3 = Theme.Text, TextSize = 16, TextXAlignment = E_TxtXL,
    }, titleBar)
    create("TextLabel", {
        BackgroundTransparency = 1, Position = UD2n(1, -220, 0, 0),
        Size = UD2n(0, 100, 1, 0),
        Font = Font.GothamMedium, Text = string.format("v%d", math.floor(VERSION/100)),
        TextColor3 = Theme.TextMuted, TextSize = 12, TextXAlignment = E_TxtXR,
    }, titleBar)

    local minBtn = create("TextButton", {
        Size = UD2o(28, 26), Position = UD2n(1, -96, 0, 9),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "-", TextColor3 = Theme.TextDim, TextSize = 17,
    }, titleBar); corner(minBtn, 6)
    local hideBtn = create("TextButton", {
        Size = UD2o(28, 26), Position = UD2n(1, -64, 0, 9),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "_", TextColor3 = Theme.TextDim, TextSize = 15,
    }, titleBar); corner(hideBtn, 6)
    local closeBtn = create("TextButton", {
        Size = UD2o(28, 26), Position = UD2n(1, -32, 0, 9),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "x", TextColor3 = Theme.TextDim, TextSize = 15,
    }, titleBar); corner(closeBtn, 6)

    local tabBar = create("Frame", {
        Name = "TabBar", Size = UD2n(1, 0, 0, 36),
        Position = UD2o(0, 44), BackgroundColor3 = Theme.SurfaceAlt,
        BorderSizePixel = 0,
    }, main)
    create("Frame", {
        Size = UD2n(1, 0, 0, 1), Position = UD2n(0, 0, 1, -1),
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0,
    }, tabBar)

    local contentArea = create("Frame", {
        Name = "ContentArea", Size = UD2n(1, 0, 1, -80),
        Position = UD2o(0, 80), BackgroundTransparency = 1,
    }, main)
    State.ui.contentArea = contentArea

    local TABS = {
        { id = "train", label = "锻炼" },
        { id = "tele",  label = "传送" },
        { id = "reb",   label = "重生" },
        { id = "kill",  label = "杀戮" },
        { id = "pet",   label = "宠物" },
        { id = "boss",  label = "Boss" },
        { id = "set",   label = "设置" },
    }

    local tabButtons = {}
    local tabIndicator = create("Frame", {
        Size = UD2n(1/#TABS, 0, 0, 2),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 3,
        Position = UD2o(0, 34),
    }, tabBar)

    for i, tab in ipairs(TABS) do
        local btn = create("TextButton", {
            Name = "Tab_" .. tab.id,
            Size = UD2n(1/#TABS, 0, 1, 0),
            Position = UD2n((i-1)/#TABS, 0, 0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Font = Font.GothamMedium, Text = tab.label,
            TextColor3 = Theme.TextDim, TextSize = 13, ZIndex = 2,
            AutoButtonColor = false,
        }, tabBar)
        tabButtons[i] = btn
    end

    local function newPage(name)
        local page = create("ScrollingFrame", {
            Name = name, Size = UD2n(1, 0, 1, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 5, ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UD2n(0, 0, 0, 0), AutomaticCanvasSize = E_AS_Y,
            ScrollingDirection = E_ScrollY, Visible = false,
            ClipsDescendants = true,
        }, contentArea)
        padding(page, 12, 12, 12, 12)
        listLayout(page, 6)
        return page
    end

    local function sectionLabel(parent, text)
        return create("TextLabel", {
            Size = UD2n(1, 0, 0, 20), BackgroundTransparency = 1,
            Font = Font.GothamBold, Text = text,
            TextColor3 = Theme.TextMuted, TextSize = 12,
            TextXAlignment = E_TxtXL,
        }, parent)
    end

    local function divider(parent)
        return create("Frame", {
            Size = UD2n(1, 0, 0, 1), BackgroundColor3 = Theme.Border,
            BorderSizePixel = 0,
        }, parent)
    end

    local function addToggle(parent, label, default, onChange, hint)
        local row = create("Frame", {
            Size = UD2n(1, 0, 0, hint and 54 or 42),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 8); stroke(row, Theme.Border, 1, 0.5)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UD2o(12, hint and 7 or 0),
            Size = UD2n(1, -80, 0, hint and 22 or 42),
            Font = Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = E_TxtXL,
        }, row)
        if hint then
            create("TextLabel", {
                BackgroundTransparency = 1, Position = UD2o(12, 28),
                Size = UD2n(1, -80, 0, 20),
                Font = Font.Gotham, Text = hint,
                TextColor3 = Theme.TextDim, TextSize = 11, TextXAlignment = E_TxtXL,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, row)
        end
        local tb = create("Frame", {
            AnchorPoint = V2n(1, 0.5), Position = UD2n(1, -12, 0.5, 0),
            Size = UD2o(42, 22), BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
        }, row)
        corner(tb, 11)
        local knob = create("Frame", {
            AnchorPoint = V2n(0, 0.5), Position = UD2n(0, 3, 0.5, 0),
            Size = UD2o(16, 16), BackgroundColor3 = Theme.TextMuted,
            BorderSizePixel = 0, ZIndex = 2,
        }, tb)
        corner(knob, 8)
        local function render(on)
            if on then
                tb.BackgroundColor3 = Theme.Accent
                knob.Position = UD2n(1, -19, 0.5, 0)
                knob.BackgroundColor3 = C3(255, 255, 255)
            else
                tb.BackgroundColor3 = Theme.SurfaceAlt
                knob.Position = UD2n(0, 3, 0.5, 0)
                knob.BackgroundColor3 = Theme.TextMuted
            end
        end
        render(default)
        local ca = create("TextButton", {
            Size = UD2n(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
        }, row)
        local value = default
        track(ca.MouseButton1Click:Connect(function()
            value = not value
            render(value)
            if onChange then onChange(value) end
        end))
        return { set = function(v) value = v; render(v) end, get = function() return value end }
    end

    local function addInput(parent, label, default, minV, maxV, onChange, hint)
        local row = create("Frame", {
            Size = UD2n(1, 0, 0, hint and 54 or 42),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 8); stroke(row, Theme.Border, 1, 0.5)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UD2o(12, hint and 7 or 0),
            Size = UD2n(1, -120, 0, hint and 22 or 42),
            Font = Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = E_TxtXL,
        }, row)
        if hint then
            create("TextLabel", {
                BackgroundTransparency = 1, Position = UD2o(12, 28),
                Size = UD2n(1, -120, 0, 20),
                Font = Font.Gotham, Text = hint,
                TextColor3 = Theme.TextDim, TextSize = 11, TextXAlignment = E_TxtXL,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, row)
        end
        local box = create("TextBox", {
            AnchorPoint = V2n(1, 0.5), Position = UD2n(1, -12, 0.5, 0),
            Size = UD2o(90, 28), BackgroundColor3 = Theme.Bg,
            BorderSizePixel = 0, Font = Font.GothamMedium,
            Text = tostring(default), TextColor3 = Theme.Text, TextSize = 13,
            PlaceholderText = string.format("%d-%d", minV, maxV),
            PlaceholderColor3 = Theme.TextMuted, ClearTextOnFocus = false,
        }, row)
        corner(box, 6); stroke(box, Theme.Border, 1)
        track(box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if not n then box.Text = tostring(default); return end
            n = math.floor(n); n = math.clamp(n, minV, maxV)
            box.Text = tostring(n)
            if onChange then onChange(n) end
        end))
        return box
    end

    local function addButton(parent, label, onClick, color)
        local btn = create("TextButton", {
            Size = UD2n(1, 0, 0, 36),
            BackgroundColor3 = color or Theme.SurfaceAlt,
            BorderSizePixel = 0, Font = Font.GothamBold,
            Text = label, TextColor3 = Theme.Text, TextSize = 13,
            AutoButtonColor = true,
        }, parent)
        corner(btn, 8); stroke(btn, Theme.Border, 1, 0.5)
        track(btn.MouseButton1Click:Connect(onClick))
        return btn
    end

    local function addSlider(parent, label, minV, maxV, default, onChange)
        local row = create("Frame", {
            Size = UD2n(1, 0, 0, 46),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 8); stroke(row, Theme.Border, 1, 0.5)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UD2o(12, 5),
            Size = UD2n(1, -100, 0, 16),
            Font = Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = E_TxtXL,
        }, row)
        local vl = create("TextLabel", {
            BackgroundTransparency = 1, AnchorPoint = V2n(1, 0),
            Position = UD2n(1, -12, 0, 5),
            Size = UD2o(80, 16),
            Font = Font.GothamBold, Text = tostring(default),
            TextColor3 = Theme.Accent, TextSize = 13, TextXAlignment = E_TxtXR,
        }, row)
        local trackBar = create("Frame", {
            Position = UD2o(12, 28), Size = UD2n(1, -24, 0, 6),
            BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        }, row)
        corner(trackBar, 3)
        local fill = create("Frame", {
            Size = UD2n((default - minV) / math.max(1, maxV - minV), 0, 1, 0),
            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
        }, trackBar)
        corner(fill, 3)
        local sb = create("TextButton", {
            Size = UD2n(1, 0, 1, 18), Position = UD2o(0, -6),
            BackgroundTransparency = 1, Text = "",
        }, trackBar)
        local active = false
        local function upd(mx)
            local ap = trackBar.AbsolutePosition
            local as = trackBar.AbsoluteSize
            local r = math.clamp((mx - ap.X) / math.max(1, as.X), 0, 1)
            local v = math.floor(minV + (maxV - minV) * r + 0.5)
            vl.Text = tostring(v)
            fill.Size = UD2n((v - minV) / math.max(1, maxV - minV), 0, 1, 0)
            if onChange then onChange(v) end
        end
        track(sb.InputBegan:Connect(function(i)
            if i.UserInputType == E_UI_MB1 or i.UserInputType == E_UI_Touch then active = true; upd(i.Position.X) end
        end))
        track(sb.InputEnded:Connect(function(i)
            if i.UserInputType == E_UI_MB1 or i.UserInputType == E_UI_Touch then active = false end
        end))
        track(UIS_IC:Connect(function(i)
            if not active then return end
            if i.UserInputType == E_UI_MMove or i.UserInputType == E_UI_Touch then upd(i.Position.X) end
        end))
        return { set = function(v) vl.Text = tostring(v); fill.Size = UD2n((v - minV) / math.max(1, maxV - minV), 0, 1, 0) end }
    end

    local function addDropdown(parent, label, values, default, onChange)
        local row = create("Frame", {
            Size = UD2n(1, 0, 0, 42),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 8); stroke(row, Theme.Border, 1, 0.5)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UD2o(12, 0),
            Size = UD2n(0.4, 0, 1, 0),
            Font = Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = E_TxtXL,
        }, row)
        local dropBtn = create("TextButton", {
            AnchorPoint = V2n(1, 0.5), Position = UD2n(1, -12, 0.5, 0),
            Size = UD2o(170, 30), BackgroundColor3 = Theme.Bg,
            BorderSizePixel = 0, Font = Font.GothamMedium,
            Text = (default and tostring(default) or "无人") .. "  v",
            TextColor3 = Theme.Text, TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)
        corner(dropBtn, 6); stroke(dropBtn, Theme.Border, 1)

        local modal = create("Frame", {
            Name = "DropModal_" .. tostring(math.random(1, 1e9)),
            Size = UD2o(170, 220),
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0, Visible = false, ZIndex = 300,
        }, State.ui.main)
        corner(modal, 8); stroke(modal, Theme.Accent, 1.5, 0.2)

        local list = create("ScrollingFrame", {
            Size = UD2n(1, 0, 1, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 4,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UD2n(0, 0, 0, 0), AutomaticCanvasSize = E_AS_Y,
            ScrollingDirection = E_ScrollY,
        }, modal)
        padding(list, 4, 4, 4, 4)
        listLayout(list, 2)

        local function draw()
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for i, v in ipairs(values) do
                local opt = create("TextButton", {
                    Size = UD2n(1, 0, 0, 26), BackgroundColor3 = Theme.SurfaceAlt,
                    BorderSizePixel = 0, Font = Font.GothamMedium,
                    Text = tostring(v), TextColor3 = Theme.Text,
                    TextSize = 12, LayoutOrder = i,
                    TextXAlignment = E_TxtXL, TextTruncate = Enum.TextTruncate.AtEnd,
                }, list)
                corner(opt, 5); padding(opt, 0, 0, 8, 8)
                track(opt.MouseButton1Click:Connect(function()
                    dropBtn.Text = tostring(v) .. "  v"
                    modal.Visible = false
                    if onChange then onChange(v) end
                end))
            end
        end
        draw()

        local function positionModal()
            local m = State.ui.main; if not m then return end
            local bp = dropBtn.AbsolutePosition
            local bs = dropBtn.AbsoluteSize
            local mp = m.AbsolutePosition
            local ms = m.AbsoluteSize
            local scale = (State.ui.mainScale and State.ui.mainScale.Scale) or 1
            local mx = (bp.X - mp.X) / scale + (bs.X / scale) - 170
            local my = (bp.Y - mp.Y) / scale + (bs.Y / scale) + 4
            if mx < 4 then mx = 4 end
            if mx + 170 > (ms.X / scale) - 4 then mx = (ms.X / scale) - 174 end
            if my + 220 > (ms.Y / scale) - 4 then my = (bp.Y - mp.Y) / scale - 224 end
            modal.Position = UD2o(mx, my)
        end

        track(dropBtn.MouseButton1Click:Connect(function()
            if modal.Visible then modal.Visible = false; return end
            positionModal(); modal.Visible = true
        end))
        track(UIS_IB:Connect(function(i)
            if not modal.Visible then return end
            if i.UserInputType ~= E_UI_MB1 and i.UserInputType ~= E_UI_Touch then return end
            local ap = modal.AbsolutePosition; local as = modal.AbsoluteSize
            local ip = i.Position
            local inM = ip.X >= ap.X and ip.X <= ap.X + as.X and ip.Y >= ap.Y and ip.Y <= ap.Y + as.Y
            local bp = dropBtn.AbsolutePosition; local bs = dropBtn.AbsoluteSize
            local inB = ip.X >= bp.X and ip.X <= bp.X + bs.X and ip.Y >= bp.Y and ip.Y <= bp.Y + bs.Y
            if not inM and not inB then modal.Visible = false end
        end))

        return {
            refresh = function(newV, clear)
                values = newV
                if clear then
                    dropBtn.Text = "无人  v"
                    if onChange then onChange(nil) end
                end
                draw()
            end,
        }
    end

    local function addActionRow(parent, actions)
        local row = create("Frame", {
            Size = UD2n(1, 0, 0, 36), BackgroundTransparency = 1,
        }, parent)
        listLayout(row, 6, true)
        for _, a in ipairs(actions) do
            local btn = create("TextButton", {
                Size = UD2n(1/#actions, -4, 1, 0),
                BackgroundColor3 = a.color or Theme.SurfaceAlt,
                BorderSizePixel = 0, Font = Font.GothamBold,
                Text = a.label, TextColor3 = Theme.Text, TextSize = 13,
            }, row)
            corner(btn, 8); stroke(btn, Theme.Border, 1, 0.5)
            track(btn.MouseButton1Click:Connect(a.onClick))
        end
        return row
    end

    local pages = {}
    for _, tab in ipairs(TABS) do pages[tab.id] = newPage("Page_" .. tab.id) end

    -- 锻炼
    local pTr = pages.train
    sectionLabel(pTr, "基本锻炼")
    local trainToggle, fastToggle
    trainToggle = addToggle(pTr, "自动锻炼", State.autoTrain, function(v)
        State.autoTrain = v
        if v and State.fastTrain then State.fastTrain = false; fastToggle.set(false) end
        if v then cleanupTrainingState() end
    end, "固定 10 次/秒")
    fastToggle = addToggle(pTr, "快速锻炼", State.fastTrain, function(v)
        State.fastTrain = v
        if v and State.autoTrain then State.autoTrain = false; trainToggle.set(false) end
        if v then cleanupTrainingState(); refreshRepSpeed() else cleanupTrainingState() end
    end, "自定义频率 + 自适应")
    State.ui.rateBox = addInput(pTr, "频率（次/秒）", State.fastRate, 1, 50000, function(n)
        if State.adaptiveEnabled then
            if State.ui.rateBox then State.ui.rateBox.Text = tostring(State.fastRate) end
            return
        end
        State.fastRate = n; State.degradeLevel = 0
    end)
    divider(pTr)
    sectionLabel(pTr, "卡顿自调节")
    addToggle(pTr, "根据帧率自动调节频率", State.adaptiveEnabled, function(v)
        State.adaptiveEnabled = v
        if State.ui.rateBox then
            State.ui.rateBox.TextEditable = not v
            State.ui.rateBox.TextColor3 = v and Theme.TextDim or Theme.Text
        end
        State.adaptiveStep = 100; State.adaptiveStableCount = 0
    end)
    addSlider(pTr, "目标帧率阈值", 10, 120, State.adaptiveThreshold, function(v) State.adaptiveThreshold = v end)
    divider(pTr)
    sectionLabel(pTr, "工具自动切换")
    local tP, tH, tS
    addToggle(pTr, "自动切换哑铃", State.toolDumbbell, function(v) State.toolDumbbell = v end)
    tP = addToggle(pTr, "自动切换俯卧撑", State.toolPushups, function(v)
        State.toolPushups = v
        if v then State.toolHandstands = false; State.toolSitups = false
            if tH then tH.set(false) end; if tS then tS.set(false) end end
    end)
    tH = addToggle(pTr, "自动切换倒立", State.toolHandstands, function(v)
        State.toolHandstands = v
        if v then State.toolPushups = false; State.toolSitups = false
            if tP then tP.set(false) end; if tS then tS.set(false) end end
    end)
    tS = addToggle(pTr, "自动切换仰卧起坐", State.toolSitups, function(v)
        State.toolSitups = v
        if v then State.toolPushups = false; State.toolHandstands = false
            if tP then tP.set(false) end; if tH then tH.set(false) end end
    end)

    -- 传送
    local pTe = pages.tele
    sectionLabel(pTe, "自动传送")
    State.ui.teleToggle = addToggle(pTe, "循环前往肌肉之王", State.autoTeleport, function(v) State.autoTeleport = v end,
        "Boss 存在时自动暂停")
    addButton(pTe, "强制传送肌肉之王", function()
        teleportMuscleKing(true); notify("已传送", 2)
    end)
    divider(pTe)
    sectionLabel(pTe, "地图传送点")
    local grid = create("Frame", {
        Size = UD2n(1, 0, 0, 0), BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, pTe)
    create("UIGridLayout", {
        CellSize = UDim2.new(0.5, -4, 0, 34),
        CellPadding = UDim2.new(0, 8, 0, 6),
        SortOrder = E_SortL,
    }, grid)
    for i, tp in ipairs(TELEPORTS) do
        local btn = create("TextButton", {
            LayoutOrder = i, BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0, Font = Font.GothamMedium,
            Text = tp.name, TextColor3 = Theme.Text,
            TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
        }, grid)
        corner(btn, 6); stroke(btn, Theme.Border, 1, 0.4)
        padding(btn, 0, 0, 8, 8)
        track(btn.MouseButton1Click:Connect(function()
            if teleportTo(tp.pos) then notify("已传送：" .. tp.name, 2)
            else notify("传送失败", 2) end
        end))
    end

    -- 重生
    local pRe = pages.reb
    sectionLabel(pRe, "自动重生")
    addToggle(pRe, "自动重生", State.autoRebirth, function(v) State.autoRebirth = v end)
    addInput(pRe, "频率（次/秒）", State.rebirthRate, 1, 100, function(n) State.rebirthRate = n end)
    divider(pRe)
    sectionLabel(pRe, "换包重生")
    -- ★ v26：删除了「训练速率」滑块，换包重生自动沿用「快速锻炼」的频率
    addToggle(pRe, "换包重生（练速装→重生装）", State.autoPackRebirth, function(v) State.autoPackRebirth = v end,
        "自动换宠并自动重生，使用快速锻炼的频率")

    -- 杀戮
    local pKi = pages.kill
    sectionLabel(pKi, "全图杀戮")
    State.ui.killToggle = addToggle(pKi, "开启全图杀戮", State.killEnabled, function(v) State.killEnabled = v end,
        "Boss 存在时自动暂停")
    addInput(pKi, "力量/耐久 阈值", State.killThreshold, 1, 100, function(n) State.killThreshold = n end,
        "自己力量 × 阈值 ≥ 目标耐久才击杀")
    divider(pKi)
    sectionLabel(pKi, "好友白名单")
    addToggle(pKi, "不打好友（含好友王）", State.friendWhitelist, function(v)
        State.friendWhitelist = v
        if v and not FriendWhitelist.loaded then refreshFriendList() end
    end, "跳过好友，不抢好友的王")
    addButton(pKi, "刷新好友列表", function()
        refreshFriendList(); notify("正在刷新好友列表", 2)
    end)
    divider(pKi)
    sectionLabel(pKi, "双工具 / 肌肉之王竞争")
    addToggle(pKi, "杀戮时切换训练工具", State.dualEnabled, function(v) State.dualEnabled = v end, "边打边练")
    addToggle(pKi, "自动击杀其他肌肉之王", State.autoKingKill, function(v)
        State.autoKingKill = v
        if not v then State.kingKillTarget = nil; State.kingKillActive = false end
    end, "自动跳过能反杀你的目标")
    addInput(pKi, "对方耐久/我力量 上限", State.kingKillThreshold, 1, 1000, function(n) State.kingKillThreshold = n end,
        "超过倍数视为打不过；同时自动跳过能反杀你的目标")

    -- 宠物
    local pPe = pages.pet
    sectionLabel(pPe, "宠物商店")
    local petList = getPetShopList()
    local petDrop = addDropdown(pPe, "选择宠物", petList, State.selectedPet, function(v) State.selectedPet = v or "" end)
    addActionRow(pPe, {
        { label = "刷新", onClick = function()
            local l = getPetShopList(); petDrop.refresh(l, false)
            notify(string.format("已刷新，共 %d 项", #l), 2)
        end },
        { label = "购买一次", color = Theme.AccentDim, onClick = function()
            local _, msg = buyPet(State.selectedPet); notify(msg, 3)
        end },
    })
    addToggle(pPe, "自动购买", State.autoPetBuy, function(v) State.autoPetBuy = v end, "每 0.5 秒购买一次")
    divider(pPe)
    sectionLabel(pPe, "自动轮盘")
    addToggle(pPe, "自动轮盘", State.autoWheel, function(v) State.autoWheel = v end, "每秒抽一次")
    divider(pPe)
    sectionLabel(pPe, "蛋白蛋")
    addToggle(pPe, "自动吃蛋", State.autoEatEgg, function(v) State.autoEatEgg = v end, "每 0.5 秒吃 10 发蛋")
    local names = {}
    for _, p in ipairs(GetPlayers(Players)) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    local eggDrop = addDropdown(pPe, "送蛋目标", names, State.selectedEggTarget, function(v) State.selectedEggTarget = v or "" end)
    addInput(pPe, "送蛋数量（0=全部）", State.giftAmount, 0, 9999, function(n) State.giftAmount = n end)
    addActionRow(pPe, {
        { label = "赠送蛋白蛋", color = Theme.Success, onClick = function()
            local target = Players:FindFirstChild(State.selectedEggTarget)
            if not target then notify("请先选择玩家", 3); return end
            local folder = LocalPlayer:FindFirstChild("consumablesFolder")
            local have = folder and #folder:GetChildren() or 0
            if have == 0 then notify("仓库里没有蛋", 3); return end
            local amt = State.giftAmount > 0 and State.giftAmount or 9999
            task.spawn(function()
                local sent = giftEggsTo(target, amt)
                notify(string.format("已送 %d 个蛋", sent), 3)
            end)
        end },
        { label = "刷新玩家", onClick = function()
            local l = {}
            for _, p in ipairs(GetPlayers(Players)) do
                if p ~= LocalPlayer then table.insert(l, p.Name) end
            end
            eggDrop.refresh(l, false); notify("已刷新玩家列表", 2)
        end },
    })

    -- Boss
    local pBo = pages.boss
    sectionLabel(pBo, "自动打 Boss")
    addToggle(pBo, "自动打 Boss", State.autoBoss, function(v)
        State.autoBoss = v
        if not v and bossHoverConn then
            pcall(function() bossHoverConn:Disconnect() end); bossHoverConn = nil
        end
    end, "只在 Boss 存活时打；Boss 存在会暂停杀戮")
    addSlider(pBo, "悬停高度", 0, 200, State.bossHeight, function(v) State.bossHeight = v end)
    divider(pBo)
    sectionLabel(pBo, "自动宝箱（Boss 死后）")
    addToggle(pBo, "自动开宝箱", State.autoChest, function(v) State.autoChest = v end,
        "Boss 死后自动传送宝箱上方 + 长按 E")
    addSlider(pBo, "宝箱延迟（秒）", 0, 30, State.chestDelay, function(v) State.chestDelay = v end)
    addSlider(pBo, "长按 E 时间（秒）", 1, 10, State.chestHoldTime, function(v) State.chestHoldTime = v end)

    -- 设置
    local pSe = pages.set
    sectionLabel(pSe, "窗口外观")
    addSlider(pSe, "窗口宽度比例(%)", 30, 90, State.uiWidthPct, function(v)
        State.uiWidthPct = v; applyUISize()
    end)
    addSlider(pSe, "窗口高度比例(%)", 30, 90, State.uiHeightPct, function(v)
        State.uiHeightPct = v; applyUISize()
    end)
    addSlider(pSe, "主窗口不透明度(%)", 30, 100, math.floor(State.uiBgOpacity * 100), function(v)
        State.uiBgOpacity = v / 100; applyUIOpacity()
    end)
    addSlider(pSe, "内容页不透明度(%)", 30, 100, math.floor(State.uiPageOpacity * 100), function(v)
        State.uiPageOpacity = v / 100; applyUIOpacity()
    end)
    addActionRow(pSe, {
        { label = "重置窗口位置", onClick = function()
            if State.ui.main then State.ui.main.Position = DEFAULT.mainPos end
            applyUISize(); notify("已重置窗口位置", 2)
        end },
    })
    divider(pSe)
    sectionLabel(pSe, "信息悬浮窗")
    State.ui.infoToggle = addToggle(pSe, "显示实时信息", State.infoWindowEnabled, function(v)
        State.infoWindowEnabled = v
        if State.ui.infoGui then State.ui.infoGui.Enabled = v end
    end)
    addSlider(pSe, "信息窗大小(%)", 60, 200, State.infoScale, function(v)
        State.infoScale = v; applyUISize()
    end)
    addSlider(pSe, "信息窗不透明度(%)", 30, 100, math.floor(State.infoBgOpacity * 100), function(v)
        State.infoBgOpacity = v / 100; applyUIOpacity()
    end)
    addToggle(pSe, "数字格式化显示", State.formatEnabled, function(v) State.formatEnabled = v end)
    divider(pSe)
    sectionLabel(pSe, "性能优化")
    addToggle(pSe, "深度防卡顿", State.antiLagEnabled, function(v) State.antiLagEnabled = v end, "关闭粒子/阴影/后处理/声音")
    addToggle(pSe, "渲染剔除", State.renderCullEnabled, function(v) State.renderCullEnabled = v end, "远处模型透明")
    addSlider(pSe, "剔除距离", 100, 5000, State.renderCullDist, function(v)
        State.renderCullDist = v
        for m in pairs(RenderCull.hidden) do uncullModel(m) end
        table.clear(RenderCull.hidden); RenderCull.rescanAt = 0
    end)
    addToggle(pSe, "移除纹理", State.textureRemoverEnabled, function(v) State.textureRemoverEnabled = v end)
    divider(pSe)
    sectionLabel(pSe, "隐藏")
    addToggle(pSe, "隐藏自己的宠物", State.hideOwnPets, function(v) State.hideOwnPets = v end)
    addToggle(pSe, "隐藏所有宠物", State.hideAllPets, function(v) State.hideAllPets = v end)
    addToggle(pSe, "隐藏器械", State.hideMachines, function(v) State.hideMachines = v end)
    addToggle(pSe, "隐藏其他 UI", State.hideUIEnabled, function(v)
        State.hideUIEnabled = v
        if v then pcall(hideAllUI) else pcall(restoreHiddenUI) end
    end)

    -- Tab 切换
    local function switchTab(id)
        for tid, p in pairs(pages) do p.Visible = (tid == id) end
        for i, tab in ipairs(TABS) do
            local on = (tab.id == id)
            tabButtons[i].TextColor3 = on and C3(255, 255, 255) or Theme.TextDim
            if on then tabIndicator.Position = UD2n((i-1)/#TABS, 0, 0, 34) end
        end
    end
    for i, btn in ipairs(tabButtons) do
        track(btn.MouseButton1Click:Connect(function() switchTab(TABS[i].id) end))
    end
    switchTab("train")

    -- 拖动
    local dragging, dragStart, dragStartPos = false, nil, nil
    local function posIn(btn, pos)
        local ap = btn.AbsolutePosition; local as = btn.AbsoluteSize
        return pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
    end
    track(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= E_UI_MB1 and input.UserInputType ~= E_UI_Touch then return end
        if posIn(minBtn, input.Position) or posIn(hideBtn, input.Position) or posIn(closeBtn, input.Position) then return end
        dragging = true; dragStart = input.Position; dragStartPos = main.Position
    end))
    track(UIS_IC:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= E_UI_MMove and input.UserInputType ~= E_UI_Touch then return end
        local d = input.Position - dragStart
        main.Position = UD2n(dragStartPos.X.Scale, dragStartPos.X.Offset + d.X,
                             dragStartPos.Y.Scale, dragStartPos.Y.Offset + d.Y)
    end))
    track(UIS_IE:Connect(function(input)
        if input.UserInputType == E_UI_MB1 or input.UserInputType == E_UI_Touch then dragging = false end
    end))

    local minimized = false
    track(minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tabBar.Visible = false; contentArea.Visible = false
            main.Size = UD2o(main.Size.X.Offset, 44)
            minBtn.Text = "+"
        else
            tabBar.Visible = true; contentArea.Visible = true
            applyUISize()
            minBtn.Text = "-"
        end
    end))
    track(hideBtn.MouseButton1Click:Connect(function()
        main.Visible = false
        if State.ui.restoreBtn then State.ui.restoreBtn.Visible = true end
    end))
    track(closeBtn.MouseButton1Click:Connect(destroy))

    local restore = create("TextButton", {
        Name = "RestoreBtn", AnchorPoint = V2n(0.5, 0.5),
        Position = UD2s(0.5, 0.5), Size = UD2o(130, 40),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "显示主界面",
        TextColor3 = C3(255, 255, 255), TextSize = 13,
        Visible = false, ZIndex = 999,
    }, screen)
    corner(restore, 10); stroke(restore, Theme.Accent, 1.5, 0.2)
    State.ui.restoreBtn = restore
    track(restore.MouseButton1Click:Connect(function()
        main.Visible = true; restore.Visible = false
    end))

    applyUISize()
    applyUIOpacity()
end

loadConfig()
buildUI()
buildInfoWindow()
buildResetButton()
applyUISize()
applyUIOpacity()

if State.ui.rateBox then
    State.ui.rateBox.TextEditable = not State.adaptiveEnabled
    State.ui.rateBox.TextColor3 = State.adaptiveEnabled and Theme.TextDim or Theme.Text
end
if State.antiLagEnabled then pcall(enableAntiLag) end
if State.textureRemoverEnabled then pcall(enableTex) end
if State.hideUIEnabled then pcall(hideAllUI) end
if State.infoWindowEnabled and State.ui.infoGui then State.ui.infoGui.Enabled = true end
if State.friendWhitelist then task.delay(2, function() refreshFriendList() end) end

local cam = Workspace.CurrentCamera
if cam then
    track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyUISize))
end

track(LocalPlayer.CharacterAdded:Connect(function()
    Cache.char = nil; Cache.hum = nil; Cache.hrp = nil
    State.killTarget = nil; State.kingKillTarget = nil; State.kingKillActive = false
    State.toolCooldown = false; State.toolOwnedByKill = false
    State.dualCurrentMode = "punch"
    State.muscleEventRef = nil; State.rebirthEventRef = nil
    PortalCache = nil; PortalCacheAt = 0
    State._missingSince = 0; State._lastSuicide = 0; State._suicideCount = 0
    State.bossKilledAt = 0; State.bossWasAlive = false
    table.clear(RenderCull.hidden)
    table.clear(PetHider.own); table.clear(PetHider.all); table.clear(PetHider.machines)
end))

track(RS_HB:Connect(onHeartbeat))

_G[SCRIPT_ID] = { version = VERSION, cleanup = destroy }
