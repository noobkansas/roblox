--!nonstrict
-- 肌肉之王自动化 v33
-- 大重构：所有函数挂 State 表避免寄存器溢出 + 全功能
local PLUGIN_ID = "__MK_AUTO_V33__"
local VERSION = 3300
local CONFIG_FILE = "mk_auto_v33.json"

if _G[PLUGIN_ID] then
    if _G[PLUGIN_ID].version and _G[PLUGIN_ID].version >= VERSION then return end
    if type(_G[PLUGIN_ID].cleanup) == "function" then pcall(_G[PLUGIN_ID].cleanup) end
end

-- 服务打包
local SVC = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Workspace = game:GetService("Workspace"),
    Lighting = game:GetService("Lighting"),
    HttpService = game:GetService("HttpService"),
    SoundService = game:GetService("SoundService"),
    MarketplaceService = game:GetService("MarketplaceService"),
    VirtualUser = game:GetService("VirtualUser"),
    VirtualInputManager = game:GetService("VirtualInputManager"),
    TeleportService = game:GetService("TeleportService"),
    Stats = game:GetService("Stats"),
    TweenService = game:GetService("TweenService"),
}
local UIS = SVC.UserInputService
local WS = SVC.Workspace
local RS_ = SVC.ReplicatedStorage
local LP, PG
do
    local t = 0
    while not game:IsLoaded() and t < 60 do t = t + 1; task.wait(0.5) end
    if not SVC.Players.LocalPlayer then SVC.Players.PlayerAdded:Wait() end
    LP = SVC.Players.LocalPlayer
    PG = LP:WaitForChild("PlayerGui", 60)
end

-- 简写
local UD2 = UDim2.new
local UDO = UDim2.fromOffset
local UDS = UDim2.fromScale
local C3 = Color3.fromRGB
local V2 = Vector2.new
local V3 = Vector3.new
local CN = CFrame.new
local ENUM = Enum
local HB = SVC.RunService.Heartbeat
local RS = SVC.RunService.RenderStepped
local UIS_IC = UIS.InputChanged
local UIS_IB = UIS.InputBegan
local UIS_IE = UIS.InputEnded
local GetPlayers = SVC.Players.GetPlayers

-- ============================================================
-- State
-- ============================================================
local S = {
    version = VERSION,
    destroyed = false,
    threads = {},
    conns = {},
    ui = {},
    Info = { rows = {}, frames = {}, viewingPlayer = nil, listOpen = false, minimized = false },
    UIState = { mode = "normal", pillPos = UD2(0.85, 0, 0.9, 0), pillDragArea = nil },
    pingHistory = {},
    activeNotifies = {},
    friendWL = { ids = {}, loaded = false, refreshing = false, lastRefresh = 0, lastAttempt = 0 },
    repCache = { pet = 0, ult = 0, x2 = false, speedMul = 1, lastRefresh = 0, lastPassCheck = 0 },
    cache = { char = nil, hum = nil, hrp = nil },
    antiLag = { enabled = false, rescanAt = 0, particles = {}, shadows = {}, sounds = {}, lighting = nil, postEffects = {}, atmospheres = {} },
    renderCull = { hidden = {}, rescanAt = 0 },
    petHider = { own = {}, all = {}, machines = {}, rescanAt = 0 },
    texRem = { enabled = false, rescanAt = 0, saved = {}, seen = {} },
    hiddenUIs = {},
    taskChain = {},
    -- 反重力
    gravityLock = { active = false, anchor = nil, force = nil, align = nil, alignPos = nil, lastSet = 0 },
    -- 器械
    machineState = { enabled = false, mode = "dumbbell", targetSeat = nil, lastTry = 0, using = false, seatIndex = nil, failCount = 0, triedAt = 0, overchargedPrep = false },
    -- 自动换宠
    petPreset = {
        train = {}, rebirth = {}, kill = {}, boss = {},
        autoSwitch = false, activeType = nil,
    },
    -- 目标重生
    rebirthTarget = 0, rebirthStoppedByTarget = false,
    -- 循环传送点
    teleportLoopEnabled = false, teleportLoopIndex = 1, teleportLoopLastAt = 0,
    -- 脚本暂停
    scriptPaused = false, pausedSnapshot = nil,
    -- 紧急重进
    emergencyRejoin = false,
    -- 器械传送
    machineTeleport = { enabled = false, lastAt = 0 },

    -- 原有状态字段
    autoTrain = false, fastTrain = false, fastRate = 20,
    toolDumbbell = false, toolPushups = false, toolHandstands = false, toolSitups = false,
    lastToolCheck = 0, toolCooldown = false,
    _missingSince = 0, _lastSuicide = 0, _suicideCount = 0,
    autoTeleport = false, lastTeleportAt = 0, lastCameraFix = 0,
    autoRebirth = false, rebirthRate = 2, lastRebirthAt = 0,
    rebirthPausedReasons = {}, rebirthSavedBySystem = false,
    killEnabled = false, killThreshold = 5,
    killGoodOnly = false, killBadOnly = false,
    killScanAt = 0, killTarget = nil, killLastAttack = 0,
    killSavedState = nil, toolOwnedByKill = false,
    friendWhitelist = false,
    autoKingKill = false,
    kingKillTarget = nil, kingKillLastAttack = 0, kingKillActive = false, lastKingCheck = 0,
    dualEnabled = true, dualLastSwitch = 0, dualCurrentMode = "punch",
    adaptiveEnabled = false, adaptiveThreshold = 30,
    adaptiveStep = 100, adaptiveStableCount = 0, lastAdaptiveAt = 0,
    antiLagEnabled = false,
    renderCullEnabled = false, renderCullDist = 500,
    hideOwnPets = false, hideAllPets = false, hideMachines = false,
    textureRemoverEnabled = false, hideUIEnabled = false,
    infoWindowEnabled = false, infoLastRefresh = 0, formatEnabled = true,
    uiBgOpacity = 1.0, uiPageOpacity = 1.0, infoBgOpacity = 1.0, infoScale = 100,
    autoPetBuy = false, selectedPet = "", autoWheel = false,
    autoBoss = false, bossHeight = 70,
    autoPackRebirth = false,
    autoEatEgg = false, giftAmount = 0, selectedEggTarget = "",
    autoChest = true, chestDelay = 5, chestHoldTime = 2,
    lastBossAliveAt = 0, bossWasAlive = false, bossKilledAt = 0,
    bossDeathPos = nil, chestOpenUntil = 0, chestLastPos = nil, chestTaskActive = false,
    autoRejoinEnabled = false, rejoinCondition = "any",
    rejoinEnableMem = true, rejoinEnableFps = true, rejoinEnablePing = true,
    rejoinServerMode = "same", rejoinPrivateServerId = "",
    rejoinMemThreshold = 1800, rejoinFpsThreshold = 5, rejoinPingThreshold = 800,
    rejoinCheckAt = 0, _rejoinTriggered = false,
    savedMainPos = nil, savedInfoPos = nil, savedInfoSize = nil,
    uiWidthPct = 40, uiHeightPct = 46, originalGravity = WS.Gravity,
    muscleEventRef = nil, rebirthEventRef = nil, lastRebirthScan = 0,
    trainAccum = 0, time = 0,
    fpsWinTime = 0, fpsWinFrames = 0, avgFps = 60,
    lastDegradeAt = 0, degradeLevel = 0,
    lastAFKClick = 0, lastSaveAt = 0, lastSweepAt = 0,
    sessionStartStrength = nil, strengthCheckAt = 0,
    lastStrengthSnapshot = 0, strengthPerSec = 0,
    ping = 0, lastPingCheck = 0, friendCount = 0, memMb = 0,
    _lastBossAlive = false,
    startAt = tick(), lastGcAt = 0, lastMemCheckAt = 0,
    memBaseline = 0, memWarnCount = 0, sessionUptime = 0, peakMem = 0,
    _didDeepClean = false,
    portalCache = nil, portalCacheAt = 0,
    bossHoverConn = nil, bossCurrent = "Boss1",
    bossAliveCache = false, bossAliveCacheAt = 0,
    -- 字体调大系数
    fontScale = 1.0,
    -- 服务器 ID（当前私服）
    currentPrivateServerId = "",
    -- 配色（优化后高对比度）
    theme = {
        Bg         = C3(18, 20, 26),
        Bg2        = C3(24, 27, 35),
        Surface    = C3(32, 36, 46),
        SurfaceAlt = C3(42, 47, 60),
        Border     = C3(70, 78, 96),
        Accent     = C3(90, 160, 255),
        Accent2    = C3(60, 120, 220),
        Success    = C3(80, 220, 140),
        Warning    = C3(255, 190, 80),
        Danger     = C3(255, 100, 100),
        Text       = C3(245, 248, 255),
        TextDim    = C3(180, 188, 205),
        TextMuted  = C3(130, 140, 160),
        OnAccent   = C3(255, 255, 255),
    },
}

-- 兼容性字段
S.Info.rows = {}
S.Info.frames = {}

-- 数据表
S.TELEPORTS = {
    { name = "大厅", pos = V3(-0.75, 90.61, 242.78) },
    { name = "小岛", pos = V3(-32.14, 8.51, 1904.41) },
    { name = "冰霜健身房", pos = V3(-2623.41, 6.99, -409.34) },
    { name = "神话健身房", pos = V3(2250.39, 6.99, 1072.77) },
    { name = "永恒健身房", pos = V3(-6758.39, 6.99, -1284.45) },
    { name = "传奇健身房", pos = V3(4603.40, 990.99, -3897.44) },
    { name = "肌肉之王健身房", pos = V3(-8625.40, 16.99, -5730.41) },
    { name = "丛林健身房", pos = V3(-8685.01, 5.99, 2392.06) },
    { name = "工业健身房", pos = V3(-5496.68, 59.04, 4927.74) },
    { name = "超载健身房", pos = V3(-3045.30, 165.41, 4990.69) },
    { name = "无转盘岛", pos = V3(1952.09, 1, 6179.98) },
    { name = "熔岩争斗", pos = V3(4472.53, 118.90, -8848.54) },
    { name = "沙漠争斗", pos = V3(973.62, 15.92, -7277.01) },
    { name = "海滩争斗", pos = V3(-1880.89, 15.87, -6137.75) },
}
S.TOOL_KW = {
    dumbbell   = { "barbell", "dumbbell", "weight", "哑铃", "杠铃" },
    pushups    = { "pushup", "push up", "push-up", "俯卧撑" },
    handstands = { "handstand", "hand stand", "hand-stand", "倒立" },
    situps     = { "situp", "sit up", "sit-up", "仰卧起坐" },
    punch      = { "punch", "拳", "fist", "空手", "拳头" },
}
S.BOSS_NAMES = { "Boss1", "Boss2", "Boss3", "Boss4", "Boss5", "BossRainbow" }
S.CHEST_POS = V3(-12.6, 403, -1246.9)
S.CHEST_RADIUS = 30

-- ============================================================
-- 工具函数（挂 S 表）
-- ============================================================
S.create = function(cls, props, parent)
    local i = Instance.new(cls)
    if props then for k, v in pairs(props) do if k ~= "Parent" then i[k] = v end end end
    if parent then i.Parent = parent end
    return i
end
S.corner = function(p, r) return S.create("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p) end
S.stroke = function(p, c, t, tr)
    return S.create("UIStroke", { Color = c or S.theme.Border, Thickness = t or 1,
        Transparency = tr or 0, ApplyStrokeMode = ENUM.ApplyStrokeMode.Border }, p)
end
S.padding = function(p, t, b, l, r)
    return S.create("UIPadding", {
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0) }, p)
end
S.listLayout = function(p, spacing, h)
    return S.create("UIListLayout", {
        Padding = UDim.new(0, spacing or 6),
        FillDirection = h and ENUM.FillDirection.Horizontal or ENUM.FillDirection.Vertical,
        SortOrder = ENUM.SortOrder.LayoutOrder }, p)
end
S.track = function(c) if c then table.insert(S.conns, c) end return c end

S.notify = function(text, duration)
    duration = duration or 3
    if S.destroyed or not S.ui.screen then return end
    local AN = S.activeNotifies
    for i = #AN, 1, -1 do if not AN[i] or not AN[i].Parent then table.remove(AN, i) end end
    if #AN >= 5 then local o = table.remove(AN, 1); if o then pcall(function() o:Destroy() end) end end
    local label = S.create("TextLabel", {
        AnchorPoint = V2(0.5, 0), Position = UD2(0.5, 0, 0.04, 0),
        Size = UDO(460, 46), BackgroundColor3 = S.theme.Surface,
        BorderSizePixel = 0, Font = ENUM.Font.GothamMedium,
        Text = text, TextColor3 = S.theme.Text,
        TextSize = 16, TextWrapped = true, ZIndex = 500,
    }, S.ui.screen)
    S.corner(label, 10); S.stroke(label, S.theme.Accent, 1.5, 0.3)
    table.insert(AN, label)
    task.delay(duration, function() pcall(function() label:Destroy() end) end)
end

S.serializePos = function(pos)
    if not pos then return nil end
    return { xs = pos.X.Scale, xo = pos.X.Offset, ys = pos.Y.Scale, yo = pos.Y.Offset }
end
S.deserializePos = function(t, fallback)
    if type(t) ~= "table" then return fallback end
    return UD2(t.xs or 0, t.xo or 0, t.ys or 0, t.yo or 0)
end
S.serializeSize = function(sz)
    if not sz then return nil end
    return { xo = sz.X.Offset, yo = sz.Y.Offset, xs = sz.X.Scale, ys = sz.Y.Scale }
end
S.deserializeSize = function(t, fallback)
    if type(t) ~= "table" then return fallback end
    return UD2(t.xs or 0, t.xo or 0, t.ys or 0, t.yo or 0)
end

S.formatNumber = function(n)
    local SUF = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
        "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }
    n = tonumber(n) or 0
    if not S.formatEnabled then return tostring(math.floor(n)) end
    local neg = n < 0; n = math.abs(n)
    if n < 1000 then return (neg and "-" or "") .. string.format("%.0f", n) end
    local idx = 1
    while n >= 1000 and idx < #SUF do n = n / 1000; idx = idx + 1 end
    return (neg and "-" or "") .. string.format("%.3f%s", n, SUF[idx])
end

-- ============================================================
-- 配置保存/读取
-- ============================================================
S.saveConfig = function()
    if S.destroyed or type(writefile) ~= "function" then return end
    pcall(function()
        if S.ui and S.ui.main then
            S.savedMainPos = S.serializePos(S.ui.main.Position)
        end
        local inf = S.Info
        if inf and inf.frames and inf.frames.frame then
            S.savedInfoPos = S.serializePos(inf.frames.frame.Position)
            S.savedInfoSize = S.serializeSize(inf.frames.frame.Size)
        end
        S.UIState.pillPos = S.serializePos(S.UIState.pillPos) or nil
    end)
    local data = {
        autoTrain=S.autoTrain, fastTrain=S.fastTrain, fastRate=S.fastRate,
        toolDumbbell=S.toolDumbbell, toolPushups=S.toolPushups,
        toolHandstands=S.toolHandstands, toolSitups=S.toolSitups,
        adaptiveEnabled=S.adaptiveEnabled, adaptiveThreshold=S.adaptiveThreshold,
        autoRebirth=S.autoRebirth, rebirthRate=S.rebirthRate, rebirthTarget=S.rebirthTarget,
        autoPackRebirth=S.autoPackRebirth,
        autoEatEgg=S.autoEatEgg, giftAmount=S.giftAmount, selectedEggTarget=S.selectedEggTarget,
        autoTeleport=S.autoTeleport, autoChest=S.autoChest, chestDelay=S.chestDelay, chestHoldTime=S.chestHoldTime,
        killEnabled=S.killEnabled, killThreshold=S.killThreshold, dualEnabled=S.dualEnabled,
        killGoodOnly=S.killGoodOnly, killBadOnly=S.killBadOnly, friendWhitelist=S.friendWhitelist,
        autoKingKill=S.autoKingKill,
        antiLagEnabled=S.antiLagEnabled, renderCullEnabled=S.renderCullEnabled, renderCullDist=S.renderCullDist,
        hideOwnPets=S.hideOwnPets, hideAllPets=S.hideAllPets, hideMachines=S.hideMachines,
        textureRemoverEnabled=S.textureRemoverEnabled, hideUIEnabled=S.hideUIEnabled,
        infoWindowEnabled=S.infoWindowEnabled, formatEnabled=S.formatEnabled,
        uiBgOpacity=S.uiBgOpacity, uiPageOpacity=S.uiPageOpacity,
        infoBgOpacity=S.infoBgOpacity, infoScale=S.infoScale,
        uiWidthPct=S.uiWidthPct, uiHeightPct=S.uiHeightPct,
        savedMainPos=S.savedMainPos, savedInfoPos=S.savedInfoPos, savedInfoSize=S.savedInfoSize,
        autoBoss=S.autoBoss, bossHeight=S.bossHeight,
        autoRejoinEnabled=S.autoRejoinEnabled, rejoinCondition=S.rejoinCondition,
        rejoinEnableMem=S.rejoinEnableMem, rejoinEnableFps=S.rejoinEnableFps, rejoinEnablePing=S.rejoinEnablePing,
        rejoinServerMode=S.rejoinServerMode, rejoinPrivateServerId=S.rejoinPrivateServerId,
        rejoinMemThreshold=S.rejoinMemThreshold, rejoinFpsThreshold=S.rejoinFpsThreshold,
        rejoinPingThreshold=S.rejoinPingThreshold,
        machineEnabled = S.machineState.enabled, machineMode = S.machineState.mode,
        teleportLoopEnabled = S.teleportLoopEnabled, teleportLoopIndex = S.teleportLoopIndex,
        emergencyRejoin = S.emergencyRejoin,
        fontScale = S.fontScale,
        UIState_mode = S.UIState.mode, UIState_pillPos = S.UIState.pillPos,
        -- 换宠预设（不能持久化实际宠物引用，只存元数据）
        petPresetAutoSwitch = S.petPreset.autoSwitch,
    }
    local ok, enc = pcall(SVC.HttpService.JSONEncode, SVC.HttpService, data)
    if ok and enc then pcall(writefile, CONFIG_FILE, enc) end
end

S.loadConfig = function()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    local exists = false
    pcall(function() exists = isfile(CONFIG_FILE) end)
    if not exists then return end
    local ok, content = pcall(readfile, CONFIG_FILE)
    if not ok or type(content) ~= "string" then return end
    local ok2, data = pcall(SVC.HttpService.JSONDecode, SVC.HttpService, content)
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
    local function s_(k, f) if type(data[k]) == "string" then return data[k] end return f end
    S.autoTrain=b("autoTrain",S.autoTrain); S.fastTrain=b("fastTrain",S.fastTrain)
    S.fastRate=n("fastRate",S.fastRate,1,50000)
    S.toolDumbbell=b("toolDumbbell",S.toolDumbbell); S.toolPushups=b("toolPushups",S.toolPushups)
    S.toolHandstands=b("toolHandstands",S.toolHandstands); S.toolSitups=b("toolSitups",S.toolSitups)
    S.adaptiveEnabled=b("adaptiveEnabled",S.adaptiveEnabled)
    S.adaptiveThreshold=n("adaptiveThreshold",S.adaptiveThreshold,10,120)
    S.autoRebirth=b("autoRebirth",S.autoRebirth); S.rebirthRate=n("rebirthRate",S.rebirthRate,1,100)
    S.rebirthTarget=n("rebirthTarget",S.rebirthTarget,0,100000)
    S.autoPackRebirth=b("autoPackRebirth",S.autoPackRebirth)
    S.autoEatEgg=b("autoEatEgg",S.autoEatEgg); S.giftAmount=n("giftAmount",S.giftAmount,0,9999)
    S.selectedEggTarget=s_("selectedEggTarget",S.selectedEggTarget)
    S.autoTeleport=b("autoTeleport",S.autoTeleport)
    S.autoChest=b("autoChest",S.autoChest); S.chestDelay=n("chestDelay",S.chestDelay,0,30)
    S.chestHoldTime=n("chestHoldTime",S.chestHoldTime,1,10)
    S.killEnabled=b("killEnabled",S.killEnabled); S.killThreshold=n("killThreshold",S.killThreshold,1,100)
    S.dualEnabled=b("dualEnabled",S.dualEnabled)
    S.killGoodOnly=b("killGoodOnly",S.killGoodOnly); S.killBadOnly=b("killBadOnly",S.killBadOnly)
    S.friendWhitelist=b("friendWhitelist",S.friendWhitelist)
    S.autoKingKill=b("autoKingKill",S.autoKingKill)
    S.antiLagEnabled=b("antiLagEnabled",S.antiLagEnabled)
    S.renderCullEnabled=b("renderCullEnabled",S.renderCullEnabled)
    S.renderCullDist=n("renderCullDist",S.renderCullDist,100,5000)
    S.hideOwnPets=b("hideOwnPets",S.hideOwnPets); S.hideAllPets=b("hideAllPets",S.hideAllPets)
    S.hideMachines=b("hideMachines",S.hideMachines)
    S.textureRemoverEnabled=b("textureRemoverEnabled",S.textureRemoverEnabled)
    S.hideUIEnabled=b("hideUIEnabled",S.hideUIEnabled)
    S.infoWindowEnabled=b("infoWindowEnabled",S.infoWindowEnabled)
    S.formatEnabled=b("formatEnabled",S.formatEnabled)
    S.uiBgOpacity=fl("uiBgOpacity",S.uiBgOpacity,0.3,1.0)
    S.uiPageOpacity=fl("uiPageOpacity",S.uiPageOpacity,0.3,1.0)
    S.infoBgOpacity=fl("infoBgOpacity",S.infoBgOpacity,0.3,1.0)
    S.infoScale=n("infoScale",S.infoScale,60,200)
    S.uiWidthPct=n("uiWidthPct",S.uiWidthPct,30,90); S.uiHeightPct=n("uiHeightPct",S.uiHeightPct,30,90)
    if type(data.savedMainPos) == "table" then S.savedMainPos = data.savedMainPos end
    if type(data.savedInfoPos) == "table" then S.savedInfoPos = data.savedInfoPos end
    if type(data.savedInfoSize) == "table" then S.savedInfoSize = data.savedInfoSize end
    S.autoBoss=b("autoBoss",S.autoBoss); S.bossHeight=n("bossHeight",S.bossHeight,0,200)
    S.autoRejoinEnabled=b("autoRejoinEnabled",S.autoRejoinEnabled)
    S.rejoinCondition=s_("rejoinCondition",S.rejoinCondition)
    S.rejoinEnableMem=b("rejoinEnableMem",S.rejoinEnableMem)
    S.rejoinEnableFps=b("rejoinEnableFps",S.rejoinEnableFps)
    S.rejoinEnablePing=b("rejoinEnablePing",S.rejoinEnablePing)
    S.rejoinServerMode=s_("rejoinServerMode",S.rejoinServerMode)
    S.rejoinPrivateServerId=s_("rejoinPrivateServerId",S.rejoinPrivateServerId)
    S.rejoinMemThreshold=n("rejoinMemThreshold",S.rejoinMemThreshold,500,100000)
    S.rejoinFpsThreshold=n("rejoinFpsThreshold",S.rejoinFpsThreshold,1,60)
    S.rejoinPingThreshold=n("rejoinPingThreshold",S.rejoinPingThreshold,100,5000)
    S.machineState.enabled=b("machineEnabled",S.machineState.enabled)
    S.machineState.mode=s_("machineMode",S.machineState.mode)
    S.teleportLoopEnabled=b("teleportLoopEnabled",S.teleportLoopEnabled)
    S.teleportLoopIndex=n("teleportLoopIndex",S.teleportLoopIndex,1,#S.TELEPORTS)
    S.emergencyRejoin=b("emergencyRejoin",S.emergencyRejoin)
    S.fontScale=fl("fontScale",S.fontScale,0.8,1.6)
    S.UIState.mode=s_("UIState_mode",S.UIState.mode)
    if type(data.UIState_pillPos) == "table" then S.UIState.pillPos = S.deserializePos(data.UIState_pillPos, S.UIState.pillPos) end
    S.petPreset.autoSwitch=b("petPresetAutoSwitch",S.petPreset.autoSwitch)
    -- 自动重生开启后就持久化保留
end

-- ============================================================
-- 反重力锁（多管齐下）
-- ============================================================
S.setupGravityLock = function()
    local char = S.cache.char
    local hrp = S.cache.hrp
    if not char or not hrp then return end
    -- 清理旧
    if S.gravityLock.force then pcall(function() S.gravityLock.force:Destroy() end) end
    if S.gravityLock.align then pcall(function() S.gravityLock.align:Destroy() end) end
    if S.gravityLock.alignPos then pcall(function() S.gravityLock.alignPos:Destroy() end) end
    -- 方式1：BodyForce（抵消重力）
    local bf = Instance.new("BodyForce")
    bf.Name = "_MK_AntiGrav"
    bf.Force = V3(0, hrp.AssemblyMass * WS.Gravity, 0)
    bf.Parent = hrp
    -- 方式2：AlignOrientation（稳定朝向）
    local ao = Instance.new("AlignOrientation")
    ao.Name = "_MK_AlignOr"
    ao.Mode = ENUM.OrientationAlignmentMode.OneAttachment
    ao.RigidityEnabled = true
    local at1 = Instance.new("Attachment", hrp)
    at1.Name = "_MK_AlignAt1"
    ao.Attachment0 = at1
    ao.Parent = hrp
    -- 方式3：AlignPosition（锁定位置）
    local ap = Instance.new("AlignPosition")
    ap.Name = "_MK_AlignPos"
    ap.Mode = ENUM.PositionAlignmentMode.OneAttachment
    ap.RigidityEnabled = true
    ap.MaxForce = 1e9
    ap.Responsiveness = 200
    local at2 = Instance.new("Attachment", hrp)
    at2.Name = "_MK_AlignAt2"
    ap.Attachment0 = at2
    ap.Position = hrp.Position
    ap.Parent = hrp
    S.gravityLock.force = bf
    S.gravityLock.align = ao
    S.gravityLock.alignPos = ap
    S.gravityLock.anchor = at2
    S.gravityLock.active = true
    S.gravityLock.lastSet = tick()
end

S.updateGravityLock = function(pos)
    if not S.gravityLock.active then return end
    local hrp = S.cache.hrp; if not hrp then return end
    -- 每帧更新 BodyForce（质量可能变化）
    pcall(function()
        if S.gravityLock.force then
            S.gravityLock.force.Force = V3(0, hrp.AssemblyMass * math.max(WS.Gravity, 196.2), 0)
        end
        if S.gravityLock.alignPos and pos then
            S.gravityLock.alignPos.Position = pos
        end
        hrp.AssemblyLinearVelocity = V3(0, 0, 0)
        hrp.AssemblyAngularVelocity = V3(0, 0, 0)
    end)
end

S.releaseGravityLock = function()
    if S.gravityLock.force then pcall(function() S.gravityLock.force:Destroy() end) end
    if S.gravityLock.align then pcall(function() S.gravityLock.align:Destroy() end) end
    if S.gravityLock.alignPos then pcall(function() S.gravityLock.alignPos:Destroy() end) end
    S.gravityLock.force = nil; S.gravityLock.align = nil
    S.gravityLock.alignPos = nil; S.gravityLock.anchor = nil
    S.gravityLock.active = false
end

-- ============================================================
-- 紧急重进（检测弹窗）
-- ============================================================
S.emergencyRejoinCheck = function()
    if not S.emergencyRejoin or S._rejoinTriggered then return end
    local pg = PG
    -- 检测常见"退出/断开"弹窗关键词
    local keywords = {
        "Disconnected", "Connection lost", "You have been kicked",
        "Error", "Failed", "Reconnect", "失去连接", "错误", "断开",
        "网络错误", "服务器关闭", "尝试重新连接",
    }
    local found = nil
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local txt = d.Text or ""
                    for _, kw in ipairs(keywords) do
                        if txt:find(kw, 1, true) then
                            found = txt
                            break
                        end
                    end
                    if found then break end
                end
            end
            if found then break end
        end
    end
    if found then
        S.notify("【紧急重进】检测到弹窗：" .. found:sub(1, 40), 3)
        S._rejoinTriggered = false
        S.rejoinGame("紧急：" .. found:sub(1, 30))
    end
end

-- ============================================================
-- 传送 & 器械
-- ============================================================
S.teleportTo = function(pos)
    local hrp = S.cache.hrp; if not hrp then return false end
    return pcall(function()
        hrp.CFrame = CN(pos)
        hrp.AssemblyLinearVelocity = V3(0, 0, 0)
        hrp.AssemblyAngularVelocity = V3(0, 0, 0)
    end)
end

S.fireOverchargedTravel = function()
    local ev = RS_:FindFirstChild("rEvents")
    ev = ev and ev:FindFirstChild("areaTravelRemote")
    if not ev then return false end
    local circle = WS:FindFirstChild("areaCircles")
    circle = circle and circle:FindFirstChild("overchargedGymCircle")
    if not circle then return false end
    pcall(function() ev:InvokeServer("travelToArea", circle) end)
    return true
end

S.getMachineSeats = function()
    local folder = WS:FindFirstChild("machinesFolder")
    if not folder then return {} end
    local seats = {}
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") then
            local seat = m:FindFirstChild("interactSeat", true)
            if seat and seat:IsA("BasePart") then
                table.insert(seats, { model = m, seat = seat, name = m.Name })
            end
        end
    end
    return seats
end

S.teleportToMachine = function()
    if not S.machineState.enabled then return end
    local now = tick()
    if now - S.machineState.lastTry < 0.5 then return end
    S.machineState.lastTry = now
    local seats = S.getMachineSeats()
    if #seats == 0 then return end
    -- 如果已有目标且仍然可用，保持
    if S.machineState.targetSeat then
        local ok = false
        for _, s in ipairs(seats) do
            if s.seat == S.machineState.targetSeat then ok = true; break end
        end
        if not ok then S.machineState.targetSeat = nil end
    end
    if not S.machineState.targetSeat then
        -- 随机选一个不在使用中的
        local avail = {}
        for _, s in ipairs(seats) do
            local occ = s.seat:GetAttribute("Occupant") or s.seat.Occupant
            if not occ then table.insert(avail, s) end
        end
        if #avail == 0 then avail = seats end
        S.machineState.targetSeat = avail[math.random(1, #avail)].seat
    end
    local seat = S.machineState.targetSeat
    if not seat or not seat.Parent then S.machineState.targetSeat = nil; return end
    -- 先传送到座位位置
    local hrp = S.cache.hrp; if not hrp then return end
    pcall(function()
        hrp.CFrame = CN(seat.Position + V3(0, 3, 0))
        hrp.AssemblyLinearVelocity = V3(0, 0, 0)
        hrp.AssemblyAngularVelocity = V3(0, 0, 0)
    end)
    -- 触发 useMachine
    local ev = RS_:FindFirstChild("rEvents")
    ev = ev and ev:FindFirstChild("machineInteractRemote")
    if ev then
        local ok = pcall(function() ev:InvokeServer("useMachine", seat) end)
        if ok then S.machineState.using = true; S.machineState.failCount = 0
        else S.machineState.failCount = S.machineState.failCount + 1 end
    end
end

S.tryCancelMachine = function()
    -- 取消使用器械 = 跳跃
    pcall(function()
        SVC.VirtualInputManager:SendKeyEvent(true, ENUM.KeyCode.Space, false, game)
        task.wait(0.05)
        SVC.VirtualInputManager:SendKeyEvent(false, ENUM.KeyCode.Space, false, game)
    end)
end

-- ============================================================
-- 战斗判定（优化）
-- ============================================================
S.isTargetSafe = function(plr)
    local myStr = S.stat(LP, "Strength")
    local myDur = S.stat(LP, "Durability")
    local myHealth = 0
    pcall(function() myHealth = S.cache.hum and S.cache.hum.MaxHealth or 0 end)
    local theirStr = S.stat(plr, "Strength")
    local theirDur = S.stat(plr, "Durability")
    -- 我的总EHP = 耐力 + 血量
    local myEHP = myDur + myHealth
    local theirEHP = theirDur
    -- 我的DPS = 力量
    local myDPS = myStr
    local theirDPS = theirStr
    -- 特殊情况：如果我的力量是0，绝对不打
    if myDPS <= 0 then return false end
    -- 特殊情况：如果对方力量是0且耐力也0，不打
    if theirEHP <= 0 and theirDPS <= 0 then return false end
    -- 我打死对方需要的时间（点击次数）
    local myHits = theirEHP / math.max(myDPS, 1)
    -- 对方打死我需要的时间
    local theirHits = myEHP / math.max(theirDPS, 1)
    -- 我要能在对方打死我之前打死他（留20%余量）
    return myHits < theirHits * 0.8
end

-- ============================================================
-- 宝箱（限定坐标范围）
-- ============================================================
S.findNearbyChest = function()
    local best, bestDist = nil, math.huge
    local HRP = S.cache.hrp; if not HRP then return nil end
    -- 搜索 Workspace 顶层 + Events/BossArena
    local roots = { WS, WS:FindFirstChild("Events"), WS:FindFirstChild("BossArena") }
    for _, root in ipairs(roots) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name:find("Chest") or (obj.Parent and obj.Parent.Name:find("Chest"))) then
                    local d = (obj.Position - S.CHEST_POS).Magnitude
                    if d <= S.CHEST_RADIUS and obj.Transparency < 0.95 and obj.CanCollide then
                        local dist = (obj.Position - HRP.Position).Magnitude
                        if dist < bestDist then best, bestDist = obj, dist end
                    end
                end
            end
        end
    end
    return best
end

-- ============================================================
-- 换宠系统
-- ============================================================
S.getEquippedPetNames = function()
    local out = {}
    local own = WS:FindFirstChild(LP.Name)
    if not own then return out end
    for _, c in ipairs(own:GetChildren()) do
        if c:IsA("Model") then
            local slot = c:FindFirstChild("equippedSlot")
            if slot and slot:IsA("StringValue") and slot.Value ~= "" then
                table.insert(out, { name = c.Name, slot = slot.Value, model = c })
            end
        end
    end
    return out
end

S.getOwnedPetInstancesByName = function(name)
    local pf = LP:FindFirstChild("petsFolder")
    if not pf then return {} end
    local out = {}
    for _, folder in ipairs(pf:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in ipairs(folder:GetChildren()) do
                if pet.Name == name then table.insert(out, pet) end
            end
        end
    end
    return out
end

S.unequipAllPets = function()
    local r = RS_:FindFirstChild("rEvents")
    local ev = r and r:FindFirstChild("equipPetEvent")
    if not ev then return end
    local pf = LP:FindFirstChild("petsFolder")
    if not pf then return end
    for _, folder in ipairs(pf:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in ipairs(folder:GetChildren()) do
                pcall(function() ev:FireServer("unequipPet", pet) end)
            end
        end
    end
end

S.applyPetPreset = function(presetType)
    if not S.petPreset.autoSwitch then return end
    local preset = S.petPreset[presetType]
    if not preset or #preset == 0 then return end
    if S.petPreset.activeType == presetType then return end
    S.petPreset.activeType = presetType
    S.unequipAllPets()
    task.wait(0.05)
    local r = RS_:FindFirstChild("rEvents")
    local ev = r and r:FindFirstChild("equipPetEvent")
    if not ev then return end
    for _, entry in ipairs(preset) do
        local instances = S.getOwnedPetInstancesByName(entry.name)
        for i = 1, math.min(entry.count or 1, #instances) do
            pcall(function() ev:FireServer("equipPet", instances[i]) end)
        end
    end
end

-- ============================================================
-- 常用工具
-- ============================================================
S.stat = function(plr, name)
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
S.myStrength = function() return S.stat(LP, "Strength") end
S.myDurability = function() return S.stat(LP, "Durability") end

S.refreshCache = function()
    local c = LP.Character
    local C = S.cache
    if c ~= C.char then
        C.char = c; C.hum = nil; C.hrp = nil
        S.releaseGravityLock()
    end
    if c then
        if not C.hum or not C.hum.Parent then C.hum = c:FindFirstChildOfClass("Humanoid") end
        if not C.hrp or not C.hrp.Parent then C.hrp = c:FindFirstChild("HumanoidRootPart") end
    end
end

S.getMuscleEvent = function()
    local c = S.muscleEventRef
    if c and c.Parent == LP then return c end
    local ev = LP:FindFirstChild("muscleEvent")
    S.muscleEventRef = ev
    return ev
end

S.getRebirthEvent = function()
    local c = S.rebirthEventRef
    if c and c.Parent then return c end
    if tick() - S.lastRebirthScan < 3 then return nil end
    S.lastRebirthScan = tick()
    local r = RS_:FindFirstChild("rEvents")
    if r then
        local ev = r:FindFirstChild("rebirthRemote")
        if ev and (ev:IsA("RemoteEvent") or ev:IsA("RemoteFunction")) then
            S.rebirthEventRef = ev; return ev
        end
    end
    return nil
end

S.fireRebirth = function()
    -- 检查目标
    if S.rebirthTarget > 0 then
        local cur = S.stat(LP, "Rebirths")
        if cur >= S.rebirthTarget then
            if S.autoRebirth then
                S.autoRebirth = false
                S.rebirthStoppedByTarget = true
                S.notify("已达到目标重生 " .. S.rebirthTarget .. "，自动重生已关闭", 6)
                if S.ui.rebirthToggle then S.ui.rebirthToggle.set(false) end
            end
            return
        end
    end
    local ev = S.getRebirthEvent(); if not ev then return end
    task.spawn(function()
        pcall(function()
            if ev:IsA("RemoteFunction") then ev:InvokeServer("rebirthRequest")
            else ev:FireServer("rebirthRequest") end
        end)
    end)
end

-- ============================================================
-- 工具切换
-- ============================================================
S.matchKw = function(n, list)
    n = n:lower()
    for i = 1, #list do if n:find(list[i]) then return true end end
    return false
end
S.isEquipped = function(list)
    local c = S.cache.char; if not c then return false end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and S.matchKw(t.Name, list) then return true end
    end
    return false
end
S.findTool = function(list)
    local c = S.cache.char
    if c then for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and S.matchKw(t.Name, list) then return t end end end
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and S.matchKw(t.Name, list) then return t end end end
    return nil
end
S.tryEquip = function(list)
    if S.isEquipped(list) then return true end
    local hum = S.cache.hum; if not hum then return false end
    local bp = LP:FindFirstChild("Backpack"); if not bp then return false end
    for _, c in ipairs(bp:GetChildren()) do
        if c:IsA("Tool") and S.matchKw(c.Name, list) then
            pcall(function() hum:EquipTool(c) end)
            return true
        end
    end
    return false
end
S.toolExists = function(list) return S.isEquipped(list) or S.findTool(list) ~= nil end
S.suicide = function()
    local hum = S.cache.hum
    if hum and hum.Health > 0 then hum.Health = 0
    elseif S.cache.char then pcall(function() S.cache.char:BreakJoints() end) end
end

-- ============================================================
-- 线程管理
-- ============================================================
S.spawnThread = function(key, fn)
    if S.threads[key] then pcall(function() task.cancel(S.threads[key]) end) end
    S.threads[key] = task.spawn(fn)
    return S.threads[key]
end
S.cancelThread = function(key)
    if S.threads[key] then pcall(function() task.cancel(S.threads[key]) end); S.threads[key] = nil end
end
S.cancelAllThreads = function() for k in pairs(S.threads) do S.cancelThread(k) end end

-- ============================================================
-- 暂停/恢复脚本
-- ============================================================
S.pauseScript = function()
    if S.scriptPaused then return end
    S.scriptPaused = true
    S.pausedSnapshot = {
        autoTrain = S.autoTrain, fastTrain = S.fastTrain,
        autoTeleport = S.autoTeleport, autoRebirth = S.autoRebirth,
        killEnabled = S.killEnabled, autoKingKill = S.autoKingKill,
        autoBoss = S.autoBoss, autoChest = S.autoChest,
        autoPackRebirth = S.autoPackRebirth, autoEatEgg = S.autoEatEgg,
        autoPetBuy = S.autoPetBuy, autoWheel = S.autoWheel,
        machineEnabled = S.machineState.enabled,
        teleportLoopEnabled = S.teleportLoopEnabled,
    }
    S.autoTrain = false; S.fastTrain = false
    S.autoTeleport = false; S.autoRebirth = false
    S.killEnabled = false; S.autoKingKill = false
    S.autoBoss = false; S.autoChest = false
    S.autoPackRebirth = false; S.autoEatEgg = false
    S.autoPetBuy = false; S.autoWheel = false
    S.machineState.enabled = false
    S.teleportLoopEnabled = false
    S.releaseGravityLock()
    S.notify("脚本已暂停", 3)
end

S.resumeScript = function()
    if not S.scriptPaused then return end
    local snap = S.pausedSnapshot
    if snap then
        S.autoTrain = snap.autoTrain; S.fastTrain = snap.fastTrain
        S.autoTeleport = snap.autoTeleport; S.autoRebirth = snap.autoRebirth
        S.killEnabled = snap.killEnabled; S.autoKingKill = snap.autoKingKill
        S.autoBoss = snap.autoBoss; S.autoChest = snap.autoChest
        S.autoPackRebirth = snap.autoPackRebirth; S.autoEatEgg = snap.autoEatEgg
        S.autoPetBuy = snap.autoPetBuy; S.autoWheel = snap.autoWheel
        S.machineState.enabled = snap.machineEnabled
        S.teleportLoopEnabled = snap.teleportLoopEnabled
    end
    S.scriptPaused = false
    S.pausedSnapshot = nil
    S.notify("脚本已恢复", 3)
end

-- ============================================================
-- 服务器信息
-- ============================================================
S.getPrivateServerId = function()
    -- 尝试从 game.JobId / PrivateServerId 读取
    local ok, id = pcall(function() return game.PrivateServerId end)
    if ok and type(id) == "string" and id ~= "" then return id end
    return game.JobId or ""
end

-- ============================================================
-- 重进
-- ============================================================
S.getMemoryMb = function()
    local ok, v = pcall(function() return SVC.Stats:GetTotalMemoryUsageMb() end)
    if ok and type(v) == "number" then return math.floor(v) end
    return 0
end
S.readRawPing = function()
    local ok, v = pcall(function() return LP:GetNetworkPing() end)
    if ok and type(v) == "number" and v > 0 then return v * 1000 end
    local ok2, v2 = pcall(function() return SVC.Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok2 and type(v2) == "number" and v2 > 0 then return v2 end
    return 0
end
S.updatePingSmooth = function()
    local raw = S.readRawPing()
    if raw <= 0 then return S.ping end
    table.insert(S.pingHistory, raw)
    if #S.pingHistory > 5 then table.remove(S.pingHistory, 1) end
    local sum, n = 0, #S.pingHistory
    for i = 1, n do sum = sum + S.pingHistory[i] end
    if n == 0 then return S.ping end
    return math.floor(sum / n)
end

S.getHttpFn = function()
    if syn and syn.request then return syn.request end
    if http and http.request then return http.request end
    if request then return request end
    if http_request then return http_request end
    if fluxus and fluxus.request then return fluxus.request end
    return nil
end
S.fetchServers = function(sortOrder)
    local httpFn = S.getHttpFn()
    if not httpFn then return nil, "no http" end
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100", game.PlaceId, sortOrder)
    local ok, resp = pcall(httpFn, { Url = url, Method = "GET" })
    if not ok or not resp then return nil, "req fail" end
    local body = resp.Body or resp.body
    if not body then return nil, "no body" end
    local ok2, data = pcall(SVC.HttpService.JSONDecode, SVC.HttpService, body)
    if not ok2 or type(data) ~= "table" or not data.data then return nil, "parse fail" end
    local result = {}
    for _, srv in ipairs(data.data) do
        if srv.id and srv.id ~= game.JobId then
            local playing = tonumber(srv.playing) or 0
            local maxP = tonumber(srv.maxPlayers) or 0
            if playing < maxP then table.insert(result, { id = srv.id, playing = playing, maxPlayers = maxP }) end
        end
    end
    return result
end
S.parsePrivateServerCode = function(input)
    if not input or input == "" then return nil end
    local code = input:match("privateServerLinkCode=([%w%-_]+)")
    if code then return code end
    if input:match("^[%w%-_]+$") then return input end
    return nil
end

S.rejoinGame = function(reason)
    if S._rejoinTriggered then return end
    S._rejoinTriggered = true
    S.notify("【自动重进】" .. (reason or "") .. " 即将重进，请确保执行器已开启自动执行", 6)
    task.wait(2)
    local mode = S.rejoinServerMode or "same"
    local ok = false
    if mode == "private" then
        local code = S.parsePrivateServerCode(S.rejoinPrivateServerId)
        if code then
            ok = pcall(function() SVC.TeleportService:TeleportToPrivateServer(game.PlaceId, code, {LP}) end)
        end
        if not ok then
            pcall(function() SVC.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
        end
    elseif mode == "crowded" then
        local servers = S.fetchServers("Desc")
        if servers and #servers > 0 then
            ok = pcall(function() SVC.TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].id, LP) end)
        end
        if not ok then pcall(function() SVC.TeleportService:Teleport(game.PlaceId, LP) end) end
    elseif mode == "sparse" then
        local servers = S.fetchServers("Asc")
        if servers and #servers > 0 then
            ok = pcall(function() SVC.TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].id, LP) end)
        end
        if not ok then pcall(function() SVC.TeleportService:Teleport(game.PlaceId, LP) end) end
    else
        pcall(function() SVC.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
    end
    task.wait(3)
    pcall(function() LP:Kick("AutoRejoin") end)
end

S.checkRejoin = function()
    if not S.autoRejoinEnabled or S._rejoinTriggered then return end
    if tick() - S.rejoinCheckAt < 3 then return end
    S.rejoinCheckAt = tick()
    S.memMb = S.getMemoryMb()
    local enabledCount, triggeredCount = 0, 0
    local triggers = {}
    if S.rejoinEnableFps then
        enabledCount = enabledCount + 1
        if S.avgFps > 0 and S.avgFps < S.rejoinFpsThreshold then
            triggeredCount = triggeredCount + 1
            table.insert(triggers, string.format("帧率%.0f<%d", S.avgFps, S.rejoinFpsThreshold))
        end
    end
    if S.rejoinEnablePing then
        enabledCount = enabledCount + 1
        if S.ping > 0 and S.ping > S.rejoinPingThreshold then
            triggeredCount = triggeredCount + 1
            table.insert(triggers, string.format("延迟%d>%d", S.ping, S.rejoinPingThreshold))
        end
    end
    if S.rejoinEnableMem then
        enabledCount = enabledCount + 1
        if S.memMb > 0 and S.memMb > S.rejoinMemThreshold then
            triggeredCount = triggeredCount + 1
            table.insert(triggers, string.format("内存%d>%d", S.memMb, S.rejoinMemThreshold))
        end
    end
    if enabledCount == 0 then return end
    local should = (S.rejoinCondition == "all") and (triggeredCount == enabledCount) or (triggeredCount > 0)
    if should then S.rejoinGame(table.concat(triggers, ",")) end
end

-- ============================================================
-- 后台工具
-- ============================================================
S.runPeriodicGc = function()
    if tick() - S.lastGcAt < 60 then return end
    S.lastGcAt = tick()
    pcall(function() collectgarbage("collect") end)
end
S.runMemoryWatchdog = function()
    if tick() - S.lastMemCheckAt < 30 then return end
    S.lastMemCheckAt = tick()
    local mem = S.getMemoryMb()
    if mem <= 0 then return end
    S.memMb = mem
    if mem > S.peakMem then S.peakMem = mem end
    if S.memBaseline == 0 then S.memBaseline = mem end
    if mem - S.memBaseline > 400 then
        S.memWarnCount = S.memWarnCount + 1
        pcall(function() collectgarbage("collect") end)
        pcall(S.sweepOverflow)
    end
end
S.longRunProtection = function()
    local uptime = tick() - S.startAt
    S.sessionUptime = uptime
    if uptime > 5 * 3600 and not S._didDeepClean then
        S._didDeepClean = true
        pcall(S.sweepOverflow)
        pcall(function() collectgarbage("collect") end)
        S.startAt = tick()
    end
end

S.sweepOverflow = function()
    local AL, RC, TR, PH, HU = S.antiLag, S.renderCull, S.texRem, S.petHider, S.hiddenUIs
    for i = #AL.particles, 1, -1 do local p = AL.particles[i]; if not p or not p.Parent then table.remove(AL.particles, i) end end
    for i = #AL.shadows, 1, -1 do local it = AL.shadows[i]; if not it.part or not it.part.Parent then table.remove(AL.shadows, i) end end
    for i = #AL.sounds, 1, -1 do local it = AL.sounds[i]; if not it.sound or not it.sound.Parent then table.remove(AL.sounds, i) end end
    for i = #AL.postEffects, 1, -1 do local fx = AL.postEffects[i]; if not fx or not fx.Parent then table.remove(AL.postEffects, i) end end
    for i = #AL.atmospheres, 1, -1 do local it = AL.atmospheres[i]; if not it.obj or not it.obj.Parent then table.remove(AL.atmospheres, i) end end
    for m in pairs(RC.hidden) do if not m.Parent then RC.hidden[m] = nil end end
    for i = #TR.saved, 1, -1 do local it = TR.saved[i]; if not it.obj or not it.obj.Parent then table.remove(TR.saved, i) end end
    for o in pairs(TR.seen) do if not o.Parent then TR.seen[o] = nil end end
    for i = #PH.own, 1, -1 do if not PH.own[i].Parent then table.remove(PH.own, i) end end
    for i = #PH.all, 1, -1 do if not PH.all[i].Parent then table.remove(PH.all, i) end end
    for i = #PH.machines, 1, -1 do if not PH.machines[i].Parent then table.remove(PH.machines, i) end end
    for i = #HU, 1, -1 do if not HU[i].Parent then table.remove(HU, i) end end
    for i = #S.activeNotifies, 1, -1 do
        if not S.activeNotifies[i] or not S.activeNotifies[i].Parent then table.remove(S.activeNotifies, i) end
    end
    while #S.pingHistory > 10 do table.remove(S.pingHistory, 1) end
end

-- 性能
S.scanAntiLag = function()
    local AL = S.antiLag
    for _, obj in ipairs(WS:GetDescendants()) do
        local cls = obj.ClassName
        if cls == "ParticleEmitter" or cls == "Trail" or cls == "Beam" or cls == "Fire" or cls == "Smoke" or cls == "Sparkles" then
            if obj.Enabled then obj.Enabled = false; table.insert(AL.particles, obj) end
        elseif cls == "BasePart" and obj.CastShadow then
            table.insert(AL.shadows, { part = obj, value = true }); obj.CastShadow = false
        end
    end
    local POST = { BloomEffect=1, BlurEffect=1, SunRaysEffect=1, ColorCorrectionEffect=1, DepthOfFieldEffect=1 }
    for _, obj in ipairs(SVC.Lighting:GetChildren()) do
        if POST[obj.ClassName] then
            if obj.Enabled then obj.Enabled = false; table.insert(AL.postEffects, obj) end
        elseif obj.ClassName == "Atmosphere" then
            table.insert(AL.atmospheres, { obj = obj, Density = obj.Density, Haze = obj.Haze, Glare = obj.Glare })
            obj.Density = 0; obj.Haze = 0; obj.Glare = 0
        end
    end
    for _, obj in ipairs(SVC.SoundService:GetDescendants()) do
        if obj:IsA("Sound") and obj.Playing and obj.Volume > 0 then
            table.insert(AL.sounds, { sound = obj, volume = obj.Volume }); obj.Volume = 0
        end
    end
end
S.enableAntiLag = function()
    if S.antiLag.enabled then return end
    S.antiLag.enabled = true
    S.antiLag.lighting = { GlobalShadows = SVC.Lighting.GlobalShadows, ShadowSoftness = SVC.Lighting.ShadowSoftness }
    pcall(function() SVC.Lighting.GlobalShadows = false; SVC.Lighting.ShadowSoftness = 0 end)
    S.scanAntiLag(); S.antiLag.rescanAt = tick() + 4
end
S.rescanAntiLag = function()
    if not S.antiLag.enabled then return end
    pcall(function() SVC.Lighting.GlobalShadows = false; SVC.Lighting.ShadowSoftness = 0 end)
    S.scanAntiLag(); S.antiLag.rescanAt = tick() + 4
end
S.disableAntiLag = function()
    local AL = S.antiLag
    AL.enabled = false
    for _, p in ipairs(AL.particles) do pcall(function() p.Enabled = true end) end
    table.clear(AL.particles)
    for _, it in ipairs(AL.shadows) do pcall(function() it.part.CastShadow = it.value end) end
    table.clear(AL.shadows)
    for _, it in ipairs(AL.sounds) do pcall(function() it.sound.Volume = it.volume end) end
    table.clear(AL.sounds)
    for _, fx in ipairs(AL.postEffects) do pcall(function() fx.Enabled = true end) end
    table.clear(AL.postEffects)
    for _, it in ipairs(AL.atmospheres) do
        pcall(function() it.obj.Density = it.Density; it.obj.Haze = it.Haze; it.obj.Glare = it.Glare end)
    end
    table.clear(AL.atmospheres)
    if AL.lighting then
        pcall(function()
            SVC.Lighting.GlobalShadows = AL.lighting.GlobalShadows
            SVC.Lighting.ShadowSoftness = AL.lighting.ShadowSoftness
        end)
        AL.lighting = nil
    end
end

-- ============================================================
-- 任务链
-- ============================================================
S.registerTask = function(t)
    t._failCount = 0; t._disabledUntil = 0
    table.insert(S.taskChain, t)
    table.sort(S.taskChain, function(a, b) return a.priority > b.priority end)
end

-- 任务：AFK
S.registerTask({ id = "afk", priority = 200,
    enabled = function() return true end,
    tick = function()
        if tick() - S.lastAFKClick >= 60 then
            S.lastAFKClick = tick()
            local cam = WS.CurrentCamera
            local vp = cam and cam.ViewportSize or V2(1920, 1080)
            pcall(function()
                SVC.VirtualUser:Button2Down(V2(0, 0), cam.CFrame)
                task.wait(0.05)
                SVC.VirtualUser:Button2Up(V2(0, 0), cam.CFrame)
            end)
        end
    end,
})

-- 任务：宝箱
S.registerTask({ id = "chest", priority = 195,
    enabled = function() return S.autoChest and not S.scriptPaused end,
    tick = function()
        if S.isAnyBossAlive() then
            S.bossWasAlive = true; S.bossKilledAt = 0; S.chestTaskActive = false
            return
        end
        if S.bossWasAlive and S.bossKilledAt == 0 then
            S.bossKilledAt = tick()
            S.bossWasAlive = false
            local hrp = S.cache.hrp
            if hrp then S.bossDeathPos = hrp.Position end
        end
        if S.bossKilledAt == 0 then return end
        local sinceDeath = tick() - S.bossKilledAt
        -- 等待期锁位
        if sinceDeath < S.chestDelay then
            local hrp = S.cache.hrp
            if hrp then
                pcall(function()
                    hrp.AssemblyLinearVelocity = V3(0, 0, 0)
                    hrp.AssemblyAngularVelocity = V3(0, 0, 0)
                end)
                S.updateGravityLock(S.bossDeathPos or hrp.Position)
            end
            return
        end
        local chest = S.findNearbyChest()
        if not chest then
            if sinceDeath > 30 then
                S.bossKilledAt = 0
                S.releaseGravityLock()
            end
            return
        end
        local hrp = S.cache.hrp; if not hrp then return end
        local targetPos = chest.Position + V3(0, 4, 0)
        pcall(function()
            hrp.CFrame = CN(targetPos)
            hrp.AssemblyLinearVelocity = V3(0, 0, 0)
            hrp.AssemblyAngularVelocity = V3(0, 0, 0)
        end)
        S.updateGravityLock(targetPos)
        if not S.chestTaskActive then
            S.chestTaskActive = true
            task.spawn(function()
                for _ = 1, 5 do
                    pcall(function()
                        SVC.VirtualInputManager:SendKeyEvent(true, ENUM.KeyCode.E, false, game)
                        task.wait(0.05)
                        SVC.VirtualInputManager:SendKeyEvent(false, ENUM.KeyCode.E, false, game)
                    end)
                    task.wait(0.1)
                end
                local holdTime = S.chestHoldTime or 2
                pcall(function()
                    SVC.VirtualInputManager:SendKeyEvent(true, ENUM.KeyCode.E, false, game)
                end)
                task.wait(holdTime)
                pcall(function()
                    SVC.VirtualInputManager:SendKeyEvent(false, ENUM.KeyCode.E, false, game)
                end)
                pcall(function()
                    for _, obj in ipairs(chest:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Enabled then
                            fireproximityprompt(obj)
                        end
                    end
                end)
                task.wait(5)
                S.chestTaskActive = false
            end)
        end
    end,
})

-- 任务：Boss
S.registerTask({ id = "boss", priority = 190,
    enabled = function() return S.autoBoss and not S.scriptPaused end,
    onEnable = function()
        if not S.threads.bossPunch then
            S.spawnThread("bossPunch", S.bossPunchLoop)
            S.spawnThread("bossScan", S.bossScanLoop)
            S.startBossHover()
        end
    end,
    onDisable = function()
        if S.bossHoverConn then pcall(function() S.bossHoverConn:Disconnect() end); S.bossHoverConn = nil end
        S.cancelThread("bossPunch")
        S.cancelThread("bossScan")
    end,
    tick = function()
        if S.isAnyBossAlive() and S.killEnabled then
            S.killEnabled = false
            if S.ui.killToggle then S.ui.killToggle.set(false) end
            S.notify("检测到 Boss，自动杀戮已暂停", 4)
        end
        local bossAlive = S.isAnyBossAlive()
        if bossAlive ~= S._lastBossAlive then
            S._lastBossAlive = bossAlive
            S.setRebirthPause("boss", bossAlive)
            if bossAlive then S.applyPetPreset("boss")
            else S.applyPetPreset("train") end
        end
    end,
})

-- 任务：King Kill
S.registerTask({ id = "kingKill", priority = 180,
    enabled = function() return S.autoKingKill and not S.scriptPaused and not (S.autoBoss and S.isAnyBossAlive()) end,
    onDisable = function() S.kingKillTarget = nil; S.kingKillActive = false end,
    tick = function() S.runKingKillTick() end,
})

-- 任务：全图杀戮
S.registerTask({ id = "kill", priority = 150,
    enabled = function()
        return S.killEnabled and not S.scriptPaused and not S.kingKillActive
            and not (S.autoBoss and S.isAnyBossAlive())
    end,
    onEnable = function()
        S.killSavedState = { autoTeleport = S.autoTeleport }
        S.autoTeleport = false
        if S.ui.teleToggle then S.ui.teleToggle.set(false) end
        S.killTarget = nil; S.killScanAt = 0; S.dualCurrentMode = "punch"
        S.setRebirthPause("kill", true)
        S.applyPetPreset("kill")
    end,
    onDisable = function()
        if S.killSavedState then
            S.autoTeleport = S.killSavedState.autoTeleport
            if S.ui.teleToggle then S.ui.teleToggle.set(S.autoTeleport) end
            S.killSavedState = nil
        end
        S.killTarget = nil; S.toolOwnedByKill = false; S.dualCurrentMode = "punch"
        S.setRebirthPause("kill", false)
        S.applyPetPreset("train")
    end,
    tick = function() S.runKillTick() end,
})

-- 任务：双工具
S.registerTask({ id = "dual", priority = 140,
    enabled = function()
        return S.dualEnabled and S.killEnabled and S.killTarget ~= nil
            and (S.autoTrain or S.fastTrain) and not S.kingKillActive
            and not (S.autoBoss and S.isAnyBossAlive())
    end,
    onDisable = function() S.dualCurrentMode = "punch" end,
    tick = function() S.updateDualTool() end,
})

-- 任务：重生
S.registerTask({ id = "rebirth", priority = 120,
    enabled = function() return S.autoRebirth and not S.scriptPaused end,
    tick = function()
        if S.rebirthTarget > 0 and S.stat(LP, "Rebirths") >= S.rebirthTarget then
            if S.autoRebirth then
                S.autoRebirth = false
                S.rebirthStoppedByTarget = true
                S.notify("已达目标重生 " .. S.rebirthTarget .. "，自动重生已关闭", 6)
                if S.ui.rebirthToggle then S.ui.rebirthToggle.set(false) end
            end
            return
        end
        local interval = 1 / math.max(1, S.rebirthRate)
        if tick() - S.lastRebirthAt >= interval then
            S.lastRebirthAt = tick()
            S.fireRebirth()
        end
    end,
})

-- 任务：轮盘
S.registerTask({ id = "wheel", priority = 110,
    enabled = function() return S.autoWheel and not S.scriptPaused end,
    onEnable = function()
        S.spawnThread("wheel", function()
            while S.autoWheel and not S.destroyed do
                pcall(function()
                    local r = RS_:FindFirstChild("rEvents")
                    local remote = r and r:FindFirstChild("openFortuneWheelRemote")
                    local s = RS_:FindFirstChild("shared")
                    local cat = s and s:FindFirstChild("catalogs")
                    local wc = cat and cat:FindFirstChild("fortuneWheelChances")
                    local wheel = wc and wc:FindFirstChild("Fortune Wheel")
                    if remote and wheel then
                        if remote:IsA("RemoteFunction") then remote:InvokeServer("openFortuneWheel", wheel)
                        else remote:FireServer("openFortuneWheel", wheel) end
                    end
                end)
                task.wait(1)
            end
        end)
    end,
    onDisable = function() S.cancelThread("wheel") end,
    tick = function() end,
})

-- 任务：传送肌肉之王
S.registerTask({ id = "teleport", priority = 100,
    enabled = function()
        return S.autoTeleport and not S.scriptPaused and not S.killEnabled
            and not S.kingKillActive and not (S.autoBoss and S.isAnyBossAlive())
    end,
    tick = function()
        if tick() - S.lastTeleportAt >= 0.05 then
            S.lastTeleportAt = tick()
            local hrp = S.cache.hrp
            if hrp then
                local portal = WS:FindFirstChild("beachToMuscleKing", true)
                local cf = portal and CN(portal.Position + V3(0, 3, 0)) or CN(V3(-8727.1, 406.7, -5796.4))
                pcall(function()
                    hrp.CFrame = cf
                    hrp.AssemblyLinearVelocity = V3(0, 0, 0)
                    hrp.AssemblyAngularVelocity = V3(0, 0, 0)
                end)
                S.updateGravityLock(cf.Position)
            end
        end
    end,
})

-- 任务：循环传送
S.registerTask({ id = "teleportLoop", priority = 95,
    enabled = function()
        return S.teleportLoopEnabled and not S.scriptPaused and not S.autoTeleport
            and not S.killEnabled and not S.kingKillActive
            and not (S.autoBoss and S.isAnyBossAlive())
    end,
    tick = function()
        if tick() - S.teleportLoopLastAt >= 1 then
            S.teleportLoopLastAt = tick()
            local tp = S.TELEPORTS[S.teleportLoopIndex]
            if tp then
                S.teleportTo(tp.pos)
                S.updateGravityLock(tp.pos)
                S.teleportLoopIndex = S.teleportLoopIndex + 1
                if S.teleportLoopIndex > #S.TELEPORTS then S.teleportLoopIndex = 1 end
            end
        end
    end,
})

-- 任务：相机
S.registerTask({ id = "camera", priority = 90,
    enabled = function()
        return S.killEnabled or S.autoTeleport or S.kingKillActive or S.autoBoss or S.teleportLoopEnabled
            or S.autoTrain or S.fastTrain or S.machineState.enabled
    end,
    tick = function()
        if tick() - S.lastCameraFix >= 0.5 then
            S.lastCameraFix = tick()
            local cam = WS.CurrentCamera
            local hum = S.cache.hum
            if cam and hum and hum.Parent then
                pcall(function()
                    if cam.CameraSubject ~= hum then cam.CameraSubject = hum end
                    if cam.CameraType ~= ENUM.CameraType.Custom then cam.CameraType = ENUM.CameraType.Custom end
                end)
            end
        end
    end,
})

-- 任务：信息
S.registerTask({ id = "info", priority = 85,
    enabled = function() return S.infoWindowEnabled end,
    tick = function()
        if tick() - S.strengthCheckAt >= 1 then
            S.strengthCheckAt = tick()
            local s = S.myStrength()
            if S.sessionStartStrength == nil then
                S.sessionStartStrength = s; S.lastStrengthSnapshot = s
            else
                local d = s - S.lastStrengthSnapshot
                if d >= 0 then S.strengthPerSec = S.strengthPerSec * 0.7 + d * 0.3 end
                S.lastStrengthSnapshot = s
            end
        end
        if tick() - S.repCache.lastRefresh >= 1 then
            S.repCache.lastRefresh = tick(); S.refreshRepSpeed()
        end
        if tick() - S.lastPingCheck >= 1 then
            S.lastPingCheck = tick()
            S.ping = S.updatePingSmooth()
        end
        if tick() - S.infoLastRefresh >= 0.2 then
            S.infoLastRefresh = tick()
            S.refreshInfoWindow()
        end
    end,
})

-- 任务：买宠物
S.registerTask({ id = "petbuy", priority = 82,
    enabled = function() return S.autoPetBuy and not S.scriptPaused and S.selectedPet ~= "" end,
    tick = function()
        if tick() - (S._petBuyLast or 0) >= 0.5 then
            S._petBuyLast = tick()
            S.buyPet(S.selectedPet)
        end
    end,
})

-- 任务：器械传送
S.registerTask({ id = "machineTeleport", priority = 81,
    enabled = function() return S.machineTeleport.enabled and not S.scriptPaused end,
    tick = function()
        if tick() - S.machineTeleport.lastAt < 2 then return end
        S.machineTeleport.lastAt = tick()
        -- 前往超载健身房之前必须先触发 areaTravelRemote
        local overchargedPos = V3(-3045.30, 165.41, 4990.69)
        local hrp = S.cache.hrp
        if hrp and (hrp.Position - overchargedPos).Magnitude < 100 then
            S.fireOverchargedTravel()
        end
    end,
})

-- 任务：器械
S.registerTask({ id = "machine", priority = 80,
    enabled = function()
        return S.machineState.enabled and not S.scriptPaused
            and not S.killEnabled and not S.kingKillActive
            and not (S.autoBoss and S.isAnyBossAlive())
    end,
    tick = function()
        -- 尝试传送到器械并触发使用
        S.teleportToMachine()
        -- 如果超过 3 秒还没使用成功，切换哑铃锻炼
        if S.machineState.using then
            if tick() - S.machineState.triedAt > 5 then
                S.machineState.using = false
                S.machineState.triedAt = tick()
                S.tryCancelMachine()
            end
        end
    end,
})

-- 任务：工具切换
S.registerTask({ id = "tool", priority = 79,
    enabled = function()
        return (S.autoTrain or S.fastTrain)
            and not S.toolCooldown and not S.toolOwnedByKill and not S.kingKillActive and not S.scriptPaused
            and S.machineState.mode ~= "machine"  -- 器械模式不切工具
    end,
    tick = function()
        local interval = 0.1
        if S.autoBoss and S.isAnyBossAlive() then interval = 0.4 end
        if tick() - S.lastToolCheck < interval then return end
        S.lastToolCheck = tick()
        local sel = {}
        if S.toolPushups then table.insert(sel, S.TOOL_KW.pushups) end
        if S.toolHandstands then table.insert(sel, S.TOOL_KW.handstands) end
        if S.toolSitups then table.insert(sel, S.TOOL_KW.situps) end
        if S.toolDumbbell then table.insert(sel, S.TOOL_KW.dumbbell) end
        if #sel == 0 then S._missingSince = 0; return end
        local equipped = false
        for _, kw in ipairs(sel) do if S.tryEquip(kw) then equipped = true; break end end
        if equipped then S._missingSince = 0; return end
        local anyExist = false
        for _, kw in ipairs(sel) do if S.toolExists(kw) then anyExist = true; break end end
        if anyExist then S._missingSince = 0; return end
        if S._missingSince == 0 then S._missingSince = tick() end
        if tick() - S._missingSince < 1.0 then return end
        if tick() - S._lastSuicide < 60 then return end
        S._lastSuicide = tick()
        S._suicideCount = (S._suicideCount or 0) + 1
        if S._suicideCount <= 3 then
            S.toolCooldown = true
            S.notify(string.format("未找到训练工具，第 %d 次重生", S._suicideCount), 4)
            S.suicide()
            task.delay(15, function() if not S.destroyed then S.toolCooldown = false end end)
        else
            S.notify("连续找不到工具，已停止自动切换", 6)
        end
    end,
})

-- 任务：锻炼
S.registerTask({ id = "train", priority = 60,
    enabled = function()
        return (S.autoTrain or S.fastTrain) and not S.kingKillActive
            and not S.autoPackRebirth and not S.scriptPaused
    end,
    tick = function(dt)
        local rate = S.fastTrain and S.fastRate or (S.autoTrain and 10 or 0)
        if rate <= 0 then return end
        S.trainAccum = S.trainAccum + rate * dt
        local count = math.floor(S.trainAccum)
        if count <= 0 then return end
        S.trainAccum = S.trainAccum - count
        if count > 3000 then count = 3000 end
        local ev = S.getMuscleEvent()
        if ev then
            pcall(function()
                for _ = 1, count do ev:FireServer("rep") end
            end)
        end
    end,
})

-- 任务：换包重生
S.registerTask({ id = "packrebirth", priority = 56,
    enabled = function() return S.autoPackRebirth and not S.scriptPaused end,
    onEnable = function() S.spawnThread("packRebirth", S.packRebirthLoop) end,
    onDisable = function() S.cancelThread("packRebirth") end,
    tick = function() end,
})

-- 任务：吃蛋
S.registerTask({ id = "egg", priority = 58,
    enabled = function() return S.autoEatEgg and not S.scriptPaused end,
    onEnable = function() S.spawnThread("egg", S.eatEggLoop) end,
    onDisable = function() S.cancelThread("egg") end,
    tick = function() end,
})

-- 任务：重进
S.registerTask({ id = "rejoin", priority = 50,
    enabled = function() return S.autoRejoinEnabled end,
    tick = function() S.checkRejoin() end,
})

-- 任务：紧急重进
S.registerTask({ id = "emergency", priority = 49,
    enabled = function() return S.emergencyRejoin end,
    tick = function() S.emergencyRejoinCheck() end,
})

-- 任务：AntiLag
S.registerTask({ id = "antilag", priority = 40,
    enabled = function() return S.antiLagEnabled end,
    onEnable = function() pcall(S.enableAntiLag) end,
    onDisable = function() pcall(S.disableAntiLag) end,
    tick = function() if S.antiLag.enabled and tick() >= S.antiLag.rescanAt then S.rescanAntiLag() end end,
})

-- 任务：隐藏宠物
S.registerTask({ id = "hider", priority = 30,
    enabled = function() return S.hideOwnPets or S.hideAllPets or S.hideMachines end,
    onEnable = function() S.petHider.rescanAt = 0 end,
    onDisable = function() pcall(S.restoreHiddenPets); pcall(S.restoreHiddenMachines) end,
    tick = function()
        if tick() >= S.petHider.rescanAt then
            pcall(S.restoreHiddenPets); pcall(S.restoreHiddenMachines)
            S.scanHidePets(); S.scanHideMachines()
        end
    end,
})

-- 任务：纹理
S.registerTask({ id = "tex", priority = 25,
    enabled = function() return S.textureRemoverEnabled end,
    onEnable = function() pcall(S.enableTex) end,
    onDisable = function() pcall(S.disableTex) end,
    tick = function() if S.texRem.enabled and tick() >= S.texRem.rescanAt then S.rescanTex() end end,
})

-- 任务：好友
S.registerTask({ id = "friend", priority = 22,
    enabled = function() return S.friendWhitelist end,
    onEnable = function() if not S.friendWL.loaded then S.refreshFriendList() end end,
    tick = function()
        if S.friendWL.refreshing then return end
        if not S.friendWL.loaded then S.refreshFriendList()
        elseif tick() - S.friendWL.lastRefresh >= 300 then S.refreshFriendList() end
    end,
})

-- 任务：清理
S.registerTask({ id = "sweep", priority = 20,
    enabled = function() return true end,
    tick = function()
        if tick() - S.lastSweepAt >= 15 then S.lastSweepAt = tick(); pcall(S.sweepOverflow) end
    end,
})

-- 任务：保存
S.registerTask({ id = "save", priority = 10,
    enabled = function() return true end,
    tick = function()
        if tick() - S.lastSaveAt >= 2 then S.lastSaveAt = tick(); task.spawn(S.saveConfig) end
        pcall(S.runPeriodicGc)
        pcall(S.runMemoryWatchdog)
        pcall(S.longRunProtection)
    end,
})

-- ============================================================
-- 逻辑实现
-- ============================================================
S.getPlayerAlignment = function(plr)
    if not plr then return nil end
    local attrs = {"Alignment", "Karma", "Faction", "Side", "Team"}
    for _, a in ipairs(attrs) do
        local v = plr:GetAttribute(a)
        if type(v) == "string" then
            local k = v:lower()
            if k:find("good") or k:find("hero") or k:find("正义") or k:find("好人") then return "good" end
            if k:find("bad") or k:find("villain") or k:find("evil") or k:find("邪恶") or k:find("坏人") then return "bad" end
        elseif type(v) == "number" then
            if v > 0 then return "good" elseif v < 0 then return "bad" end
        end
    end
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        for _, n in ipairs({"Karma", "Alignment", "Good", "Bad"}) do
            local v = ls:FindFirstChild(n)
            if v and v:IsA("ValueBase") then
                if type(v.Value) == "number" then
                    if v.Value > 0 then return "good" elseif v.Value < 0 then return "bad" end
                end
            end
        end
    end
    return nil
end

S.passAlignmentFilter = function(plr)
    local onlyGood = S.killGoodOnly
    local onlyBad = S.killBadOnly
    if onlyGood == onlyBad then return true end
    local align = S.getPlayerAlignment(plr)
    if not align then return true end
    if onlyGood then return align == "good" end
    if onlyBad then return align == "bad" end
    return true
end

S.getCharHRP = function(plr)
    local c = plr and plr.Character
    if not c then return nil end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return nil end
    return hrp
end

S.applyKillMove = function(targetHRP)
    local hrp = S.cache.hrp; if not hrp then return end
    local delta = targetHRP.Position - hrp.Position
    local dsq = delta.X*delta.X + delta.Y*delta.Y + delta.Z*delta.Z
    if dsq > 9 then
        local dist = math.sqrt(dsq)
        local newPos = targetHRP.Position - delta / dist * 2.5
        local cf = CN(newPos, targetHRP.Position)
        pcall(function()
            hrp.CFrame = cf
            hrp.AssemblyLinearVelocity = V3(0, 0, 0)
            hrp.AssemblyAngularVelocity = V3(0, 0, 0)
        end)
    end
end

S.punch = function()
    local c = S.cache.char; if not c then return end
    local tool = c:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

S.refreshFriendList = function()
    local FW = S.friendWL
    if FW.refreshing then return end
    if tick() - FW.lastAttempt < 60 then return end
    FW.lastAttempt = tick(); FW.refreshing = true
    S.spawnThread("friendRefresh", function()
        local ids = {}
        pcall(function()
            local pages = LP:GetFriendsAsync()
            while pages do
                for _, item in ipairs(pages:GetCurrentPage()) do
                    if item.Id then ids[item.Id] = true end
                end
                if pages.IsFinished then break end
                pcall(function() pages:AdvanceToNextPageAsync() end)
            end
        end)
        pcall(function()
            for _, f in ipairs(LP:GetFriendsOnline(200)) do
                if f.VisitorId then ids[f.VisitorId] = true end
            end
        end)
        FW.ids = ids; FW.loaded = true
        local n = 0
        for _ in pairs(ids) do n = n + 1 end
        S.friendCount = n
        FW.lastRefresh = tick(); FW.refreshing = false
    end)
end

S.isFriend = function(plr)
    if not plr or not plr.UserId then return false end
    return S.friendWL.ids[plr.UserId] == true
end

S.refreshRepSpeed = function()
    local RC = S.repCache
    local sumPct, timeMul = 0, 1
    local own = WS:FindFirstChild(LP.Name)
    if own then
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
    end
    local ultPct = 0
    local a = LP:GetAttribute("UltimateRepSpeed")
    if type(a) == "number" then ultPct = a * 5 end
    local ultMul = math.max(0.001, 1 - ultPct / 100)
    RC.pet = sumPct; RC.ult = ultPct
    local tt = math.max(0.0001, timeMul * ultMul)
    RC.speedMul = 1 / tt
end

-- Boss
S.findBossModel = function(name)
    local events = WS:FindFirstChild("Events")
    local arena = events and events:FindFirstChild("BossArena")
    local holder = arena and arena:FindFirstChild(name or S.bossCurrent)
    return holder and holder:FindFirstChild("Boss")
end
S.isBossAlive = function(name)
    local b = S.findBossModel(name); if not b then return false end
    if b:IsA("Model") then
        local h = b:FindFirstChildOfClass("Humanoid")
        return h ~= nil and h.Health > 0
    end
    return b:IsA("BasePart") and b.Transparency < 1
end
S.isAnyBossAlive = function()
    if tick() - S.bossAliveCacheAt < 0.5 then return S.bossAliveCache end
    S.bossAliveCacheAt = tick()
    for _, n in ipairs(S.BOSS_NAMES) do
        if S.isBossAlive(n) then S.bossAliveCache = true; return true end
    end
    S.bossAliveCache = false
    return false
end
S.getBossPos = function()
    local b = S.findBossModel(); if not b then return nil end
    if b:IsA("Model") then return b:GetPivot().Position end
    return b.Position
end

S.startBossHover = function()
    if S.bossHoverConn then pcall(function() S.bossHoverConn:Disconnect() end) end
    S.bossHoverConn = RS:Connect(function()
        if not S.autoBoss then return end
        if S.isAnyBossAlive() then
            local hrp = S.cache.hrp; if not hrp then return end
            local bp = S.getBossPos(); if not bp then return end
            local hoverPos = bp + V3(0, S.bossHeight, 0)
            local flat = V3(bp.X - hoverPos.X, 0, bp.Z - hoverPos.Z)
            if flat.Magnitude < 0.1 then flat = V3(0, 0, -1) end
            hrp.CFrame = CFrame.lookAt(hoverPos, hoverPos + (flat.Unit + V3(0, -1, 0)).Unit)
            S.updateGravityLock(hoverPos)
        elseif S.bossKilledAt > 0 and (tick() - S.bossKilledAt) < 30 then
            local hrp = S.cache.hrp; if not hrp then return end
            S.updateGravityLock(S.bossDeathPos or hrp.Position)
        end
    end)
end

S.bossPunchLoop = function()
    local useLeft, trackL, trackR = true, nil, nil
    local counter = 0
    while S.autoBoss and not S.destroyed do
        if S.isAnyBossAlive() and S.getBossPos() then
            counter = counter + 1
            if counter % 4 == 0 then
                pcall(function()
                    local bp = LP:FindFirstChild("Backpack")
                    local pt = bp and bp:FindFirstChild("Punch")
                    local cd = pt and pt:FindFirstChildOfClass("NumberValue")
                    if cd then cd.Value = 0.01 end
                end)
            end
            pcall(function()
                local char = S.cache.char
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                local bp = LP:FindFirstChild("Backpack")
                local pt = (char and char:FindFirstChild("Punch")) or (bp and bp:FindFirstChild("Punch"))
                if pt and pt.Parent ~= char then hum:EquipTool(pt) end
                local ev = S.getMuscleEvent()
                if ev then ev:FireServer("punch", useLeft and "leftHand" or "rightHand") end
                local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
                local track = useLeft and trackL or trackR
                if not track then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = useLeft and "rbxassetid://3638729053" or "rbxassetid://3638767427"
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

S.bossScanLoop = function()
    while S.autoBoss and not S.destroyed do
        task.wait(2)
        if S.autoBoss and not S.destroyed then
            for _, n in ipairs(S.BOSS_NAMES) do
                if S.isBossAlive(n) then
                    if n ~= S.bossCurrent then S.bossCurrent = n end
                    break
                end
            end
        end
    end
end

-- 杀戮逻辑
S.selectKillTarget = function()
    for _, plr in ipairs(GetPlayers(SVC.Players)) do
        if plr ~= LP and not (S.friendWhitelist and S.isFriend(plr)) then
            local hrp = S.getCharHRP(plr)
            if hrp and S.passAlignmentFilter(plr) then
                if S.isTargetSafe(plr) then return plr end
            end
        end
    end
    return nil
end

S.runKillTick = function()
    if tick() - S.killScanAt >= 0.5 then
        S.killScanAt = tick()
        if S.killTarget and S.friendWhitelist and S.isFriend(S.killTarget) then S.killTarget = nil end
        if S.killTarget and not S.passAlignmentFilter(S.killTarget) then S.killTarget = nil end
        local valid = S.killTarget and S.getCharHRP(S.killTarget)
        if not valid then
            S.killTarget = S.selectKillTarget()
        else
            if not S.isTargetSafe(S.killTarget) then S.killTarget = S.selectKillTarget() end
        end
        S.toolOwnedByKill = S.killTarget ~= nil
    end
    local t = S.killTarget; if not t then return end
    local hrp = S.getCharHRP(t); if not hrp then S.killTarget = nil; return end
    S.applyKillMove(hrp)
    local dual = S.dualEnabled and (S.autoTrain or S.fastTrain)
    if not dual then
        if tick() - S.killLastAttack >= 0.05 then
            S.killLastAttack = tick()
            if not S.isEquipped(S.TOOL_KW.punch) then S.tryEquip(S.TOOL_KW.punch) end
            S.punch()
        end
    end
end

S.runKingKillTick = function()
    if tick() - S.lastKingCheck >= 0.5 then
        S.lastKingCheck = tick()
        local shared = RS_:FindFirstChild("shared")
        local state = shared and shared:FindFirstChild("state")
        local world = state and state:FindFirstChild("World")
        local mk = world and world:FindFirstChild("muscleKing")
        local king = nil
        if mk then
            if mk:IsA("ObjectValue") then king = mk.Value
            elseif mk:IsA("StringValue") and mk.Value ~= "" then king = SVC.Players:FindFirstChild(mk.Value) end
        end
        if not king or king == LP or (S.friendWhitelist and S.isFriend(king)) then
            S.kingKillTarget = nil; S.kingKillActive = false; return
        end
        local hrp = S.getCharHRP(king)
        if not hrp then S.kingKillTarget = nil; S.kingKillActive = false; return end
        if not S.isTargetSafe(king) then
            S.kingKillTarget = nil; S.kingKillActive = false; return
        end
        S.kingKillTarget = king
    end
    local t = S.kingKillTarget; if not t then S.kingKillActive = false; return end
    if S.friendWhitelist and S.isFriend(t) then
        S.kingKillTarget = nil; S.kingKillActive = false; return
    end
    local hrp = S.getCharHRP(t)
    if not hrp then S.kingKillTarget = nil; S.kingKillActive = false; return end
    S.kingKillActive = true
    S.applyKillMove(hrp)
    if tick() - S.kingKillLastAttack >= 0.05 then
        S.kingKillLastAttack = tick()
        if not S.isEquipped(S.TOOL_KW.punch) then S.tryEquip(S.TOOL_KW.punch) end
        S.punch()
    end
end

S.findPreferredTool = function()
    local TK = S.TOOL_KW
    if S.toolPushups then local t = S.findTool(TK.pushups); if t then return t end end
    if S.toolHandstands then local t = S.findTool(TK.handstands); if t then return t end end
    if S.toolSitups then local t = S.findTool(TK.situps); if t then return t end end
    if S.toolDumbbell then local t = S.findTool(TK.dumbbell); if t then return t end end
    return nil
end
S.updateDualTool = function()
    if not S.dualEnabled or not S.killEnabled or not S.killTarget then return end
    if not (S.autoTrain or S.fastTrain) then return end
    local hum = S.cache.hum; if not hum then return end
    local switchInterval = 0.06
    if S.autoBoss and S.isAnyBossAlive() then switchInterval = 0.4 end
    if tick() - S.dualLastSwitch < switchInterval then return end
    S.dualLastSwitch = tick()
    if S.dualCurrentMode == "punch" then
        local t = S.findPreferredTool()
        if t then
            pcall(function() hum:EquipTool(t) end)
            S.dualCurrentMode = "train"
            task.defer(function() if not S.destroyed then pcall(function() t:Activate() end) end end)
        else S.dualCurrentMode = "punch" end
    else
        local t = S.findTool(S.TOOL_KW.punch)
        if t then
            pcall(function() hum:EquipTool(t) end)
            S.dualCurrentMode = "punch"
            task.defer(function() if not S.destroyed then pcall(function() t:Activate() end) end end)
        else S.dualCurrentMode = "train" end
    end
end

-- 换包重生
S.PETS_DATA = {
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
S.getOwnedPets = function()
    local out = {}
    local pf = LP:FindFirstChild("petsFolder"); if not pf then return out end
    for _, folder in ipairs(pf:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in ipairs(folder:GetChildren()) do
                local cfg = S.PETS_DATA[pet.Name]
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
S.equipOnePet = function(pet)
    local r = RS_:FindFirstChild("rEvents")
    local ev = r and r:FindFirstChild("equipPetEvent")
    if ev then pcall(function() ev:FireServer("equipPet", pet) end) end
end
S.equipFarmingPets = function()
    S.unequipAllPets()
    local pets = S.getOwnedPets()
    table.sort(pets, function(a, b) return a.repSpeed > b.repSpeed end)
    local equipped, count, rep = {}, 0, 0
    for _, p in ipairs(pets) do
        if count >= 12 or rep >= 100 then break end
        if p.repSpeed > 0 then S.equipOnePet(p.instance); equipped[p.instance] = true; count = count + 1; rep = rep + p.repSpeed end
    end
    local rest = {}
    for _, p in ipairs(pets) do if not equipped[p.instance] then table.insert(rest, p) end end
    table.sort(rest, function(a, b) return (a.strength + a.durability) > (b.strength + b.durability) end)
    for _, p in ipairs(rest) do
        if count >= 12 then break end
        if p.strength > 0 or p.durability > 0 then S.equipOnePet(p.instance); count = count + 1 end
    end
end
S.equipRebirthPets = function()
    S.unequipAllPets()
    local pets = S.getOwnedPets()
    table.sort(pets, function(a, b) return a.rebirth > b.rebirth end)
    local count = 0
    for _, p in ipairs(pets) do
        if count >= 12 then break end
        if p.rebirth > 0 then S.equipOnePet(p.instance); count = count + 1 end
    end
end

S.performPackRebirth = function()
    local ev = S.getMuscleEvent(); if not ev then return end
    local ls = LP:FindFirstChild("leaderstats")
    local strStat = ls and ls:FindFirstChild("Strength")
    local rebStat = ls and ls:FindFirstChild("Rebirths")
    if not (strStat and rebStat) then return end
    local target = 5000 + rebStat.Value * 2550
    while strStat.Value < target and S.autoPackRebirth and not S.destroyed do
        pcall(function()
            local burst = math.clamp(math.floor(S.fastRate / 10), 5, 50)
            for _ = 1, burst do ev:FireServer("rep") end
        end)
        task.wait(0.01)
    end
    S.equipRebirthPets()
    task.wait(0.25)
    local before = rebStat.Value
    local tries = 0
    repeat
        S.fireRebirth()
        task.wait(0.05)
        tries = tries + 1
    until rebStat.Value > before or tries > 20
end
S.packRebirthLoop = function()
    while S.autoPackRebirth and not S.destroyed do
        S.equipFarmingPets()
        S.performPackRebirth()
        task.wait(0.5)
    end
end

-- 吃蛋
S.findProteinEgg = function()
    local c = S.cache.char
    local bp = LP:FindFirstChild("Backpack")
    return (c and c:FindFirstChild("Protein Egg")) or (bp and bp:FindFirstChild("Protein Egg"))
end
S.eatEggLoop = function()
    local ev = S.getMuscleEvent()
    while S.autoEatEgg and not S.destroyed do
        pcall(function()
            local egg = S.findProteinEgg()
            if egg and ev then
                for _ = 1, 10 do ev:FireServer("proteinEgg", egg) end
            end
        end)
        task.wait(0.5)
    end
end

-- 买宠物
S.getPetShopFolder = function()
    local s = RS_:FindFirstChild("shared")
    local rt = s and s:FindFirstChild("runtime")
    return rt and rt:FindFirstChild("cPetShopFolder")
end
S.getPetShopRemote = function()
    local r = RS_:FindFirstChild("rEvents")
    return r and r:FindFirstChild("cPetShopRemote")
end
S.getPetShopList = function()
    local names = {}
    pcall(function()
        local f = S.getPetShopFolder()
        if f then for _, item in ipairs(f:GetChildren()) do table.insert(names, item.Name) end end
    end)
    table.sort(names)
    return names
end
S.buyPet = function(name)
    local remote = S.getPetShopRemote()
    local folder = S.getPetShopFolder()
    if not (remote and folder) then return false end
    if not name or name == "" then return false end
    local pet = folder:FindFirstChild(name)
    if not pet then return false end
    pcall(function()
        if remote:IsA("RemoteFunction") then remote:InvokeServer(pet)
        else remote:FireServer(pet) end
    end)
    return true
end

-- 隐藏宠物
S.hidePart = function(m)
    if not m or not m.Parent then return end
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.LocalTransparencyModifier = 1; p.Transparency = 1 end) end
    end
end
S.showPart = function(m)
    if not m or not m.Parent then return end
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.LocalTransparencyModifier = 0; p.Transparency = 0 end) end
    end
end
S.scanHidePets = function()
    local PH = S.petHider
    if S.hideOwnPets then
        local own = WS:FindFirstChild(LP.Name)
        if own then for _, pet in ipairs(own:GetChildren()) do
            if pet:IsA("Model") or pet:IsA("Folder") then table.insert(PH.own, pet); S.hidePart(pet) end
        end end
    end
    if S.hideAllPets then
        for _, plr in ipairs(GetPlayers(SVC.Players)) do
            if plr ~= LP then
                local f = WS:FindFirstChild(plr.Name)
                if f then for _, pet in ipairs(f:GetChildren()) do
                    if pet:IsA("Model") or pet:IsA("Folder") then table.insert(PH.all, pet); S.hidePart(pet) end
                end end
            end
        end
    end
    PH.rescanAt = tick() + 2
end
S.restoreHiddenPets = function()
    local PH = S.petHider
    for _, m in ipairs(PH.own) do S.showPart(m) end
    table.clear(PH.own)
    for _, m in ipairs(PH.all) do S.showPart(m) end
    table.clear(PH.all)
end
S.scanHideMachines = function()
    if not S.hideMachines then return end
    local PH = S.petHider
    local mf = WS:FindFirstChild("machinesFolder")
    if mf then for _, m in ipairs(mf:GetChildren()) do
        if m:IsA("Model") then table.insert(PH.machines, m); S.hidePart(m) end
    end end
    PH.rescanAt = tick() + 2
end
S.restoreHiddenMachines = function()
    for _, m in ipairs(S.petHider.machines) do S.showPart(m) end
    table.clear(S.petHider.machines)
end

-- 纹理移除
S.scanTextures = function()
    local TR = S.texRem
    for _, obj in ipairs(WS:GetDescendants()) do
        local cls = obj.ClassName
        if cls == "Decal" or cls == "Texture" then
            if not TR.seen[obj] and obj.Texture ~= "" then
                TR.seen[obj] = true
                table.insert(TR.saved, { obj = obj, prop = "Texture", value = obj.Texture })
                obj.Texture = ""
            end
        elseif cls == "MeshPart" or cls == "SpecialMesh" then
            local p = (cls == "MeshPart") and "TextureID" or "TextureId"
            if not TR.seen[obj] and obj[p] and obj[p] ~= "" then
                TR.seen[obj] = true
                table.insert(TR.saved, { obj = obj, prop = p, value = obj[p] })
                obj[p] = ""
            end
        end
    end
end
S.enableTex = function()
    if S.texRem.enabled then return end
    S.texRem.enabled = true; table.clear(S.texRem.saved); table.clear(S.texRem.seen)
    S.scanTextures(); S.texRem.rescanAt = tick() + 4
end
S.rescanTex = function()
    if not S.texRem.enabled then return end
    S.scanTextures(); S.texRem.rescanAt = tick() + 4
end
S.disableTex = function()
    S.texRem.enabled = false
    for _, it in ipairs(S.texRem.saved) do pcall(function() it.obj[it.prop] = it.value end) end
    table.clear(S.texRem.saved); table.clear(S.texRem.seen)
end

-- ============================================================
-- 主心跳
-- ============================================================
S.setRebirthPause = function(reason, on)
    local reasons = S.rebirthPausedReasons
    if on then
        if reasons[reason] then return end
        reasons[reason] = true
        if not S.rebirthSavedBySystem and S.autoRebirth then
            S.rebirthSavedBySystem = true
            S.autoRebirth = false
            if S.ui.rebirthToggle then S.ui.rebirthToggle.set(false) end
        end
    else
        if not reasons[reason] then return end
        reasons[reason] = nil
        if not next(reasons) and S.rebirthSavedBySystem then
            S.rebirthSavedBySystem = false
            S.autoRebirth = true
            if S.ui.rebirthToggle then S.ui.rebirthToggle.set(true) end
        end
    end
end

S.updateGlobal = function(dt)
    local wantZero = S.killEnabled or S.autoTeleport or S.kingKillActive
        or S.teleportLoopEnabled or S.machineState.enabled
        or (S.autoBoss and S.autoChest and S.bossKilledAt > 0 and (tick() - S.bossKilledAt) < 30)
        or (S.autoTrain or S.fastTrain)
    if wantZero then
        if WS.Gravity ~= 0 then pcall(function() WS.Gravity = 0 end) end
    else
        if WS.Gravity ~= S.originalGravity then
            pcall(function() WS.Gravity = S.originalGravity end)
        end
    end
    S.fpsWinTime = S.fpsWinTime + dt
    S.fpsWinFrames = S.fpsWinFrames + 1
    if S.fpsWinTime >= 0.5 then
        S.avgFps = S.fpsWinFrames / S.fpsWinTime
        S.fpsWinTime = 0; S.fpsWinFrames = 0
    end
    if S.sessionStartStrength == nil then
        S.sessionStartStrength = S.myStrength()
        S.lastStrengthSnapshot = S.sessionStartStrength
    end
end

S.onHeartbeat = function(dt)
    if S.destroyed then return end
    S.time = tick()
    S.refreshCache()
    S.updateGlobal(dt)
    -- 反重力自动重设（若掉了）
    if S.gravityLock.active then
        local hrp = S.cache.hrp
        if hrp then
            S.updateGravityLock(S.gravityLock.alignPos and S.gravityLock.alignPos.Position or hrp.Position)
        end
    end
    -- 任务
    local now = tick()
    local TC = S.taskChain
    for i = 1, #TC do
        local task_ = TC[i]
        if task_._disabledUntil > 0 and now < task_._disabledUntil then
            -- skip
        else
            if task_._disabledUntil > 0 and now >= task_._disabledUntil then
                task_._disabledUntil = 0; task_._failCount = 0
                S.notify(string.format("任务 %s 已恢复", task_.id), 3)
            end
            local ok, en = pcall(task_.enabled)
            if not ok then en = false end
            if not en then
                if task_._wasActive then
                    task_._wasActive = false
                    if task_.onDisable then pcall(task_.onDisable) end
                end
            else
                if not task_._wasActive then
                    task_._wasActive = true
                    if task_.onEnable then pcall(task_.onEnable) end
                end
                local ok2, err = pcall(task_.tick, dt)
                if not ok2 then
                    task_._failCount = (task_._failCount or 0) + 1
                    warn(string.format("[%s] 第%d次失败: %s", task_.id, task_._failCount, tostring(err)))
                    if task_._failCount >= 10 then
                        task_._disabledUntil = tick() + 30
                        task_._failCount = 0
                        if task_._wasActive and task_.onDisable then
                            pcall(task_.onDisable); task_._wasActive = false
                        end
                    end
                else
                    if task_._failCount and task_._failCount > 0 then task_._failCount = 0 end
                end
            end
        end
    end
end

-- ============================================================
-- UI 构建（放在最后）
-- ============================================================
S.buildUI = function()
    local TH = S.theme
    local screen = S.create("ScreenGui", {
        Name = "MK_AUTO_UI", ResetOnSpawn = false,
        ZIndexBehavior = ENUM.ZIndexBehavior.Sibling, DisplayOrder = 99999,
    }, PG)
    S.ui.screen = screen

    local main = S.create("Frame", {
        Name = "Main", AnchorPoint = V2(0, 0),
        Position = S.deserializePos(S.savedMainPos, UD2(0.5, -260, 0.5, -190)),
        Size = UDO(560, 420),
        BackgroundColor3 = TH.Bg, BorderSizePixel = 0,
        ClipsDescendants = true, Active = true,
    }, screen)
    S.ui.main = main
    S.corner(main, 12); S.stroke(main, TH.Border, 1)

    local titleBar = S.create("Frame", {
        Name = "TitleBar", Size = UD2(1, 0, 0, 48),
        Position = UDO(0, 0), BackgroundColor3 = TH.Surface,
        BorderSizePixel = 0, Active = true,
    }, main)
    S.corner(titleBar, 12)
    S.create("TextLabel", {
        BackgroundTransparency = 1, Position = UDO(18, 0),
        Size = UD2(1, -160, 1, 0),
        Font = ENUM.Font.GothamBold, Text = "肌肉之王自动化  v33",
        TextColor3 = TH.Text, TextSize = 18, TextXAlignment = ENUM.TextXAlignment.Left,
    }, titleBar)

    local minBtn = S.create("TextButton", {
        Size = UDO(32, 28), Position = UD2(1, -110, 0, 10),
        BackgroundColor3 = TH.SurfaceAlt, BorderSizePixel = 0,
        Font = ENUM.Font.GothamBold, Text = "—", TextColor3 = TH.Text, TextSize = 16,
    }, titleBar); S.corner(minBtn, 6)
    local pillBtn = S.create("TextButton", {
        Size = UDO(32, 28), Position = UD2(1, -74, 0, 10),
        BackgroundColor3 = TH.SurfaceAlt, BorderSizePixel = 0,
        Font = ENUM.Font.GothamBold, Text = "◯", TextColor3 = TH.Text, TextSize = 16,
    }, titleBar); S.corner(pillBtn, 6)
    local closeBtn = S.create("TextButton", {
        Size = UDO(32, 28), Position = UD2(1, -38, 0, 10),
        BackgroundColor3 = TH.Danger, BorderSizePixel = 0,
        Font = ENUM.Font.GothamBold, Text = "✕", TextColor3 = TH.OnAccent, TextSize = 16,
    }, titleBar); S.corner(closeBtn, 6)

    local tabBar = S.create("Frame", {
        Name = "TabBar", Size = UD2(1, 0, 0, 40),
        Position = UDO(0, 48), BackgroundColor3 = TH.SurfaceAlt, BorderSizePixel = 0,
    }, main)
    S.create("Frame", {
        Size = UD2(1, 0, 0, 1), Position = UD2(0, 0, 1, -1),
        BackgroundColor3 = TH.Border, BorderSizePixel = 0,
    }, tabBar)

    local contentArea = S.create("Frame", {
        Name = "Content", Size = UD2(1, 0, 1, -88),
        Position = UDO(0, 88), BackgroundTransparency = 1,
    }, main)
    S.ui.contentArea = contentArea

    local TABS = {
        { id = "train", label = "锻炼" }, { id = "tele",  label = "传送" },
        { id = "reb",   label = "重生" }, { id = "kill",  label = "杀戮" },
        { id = "pet",   label = "宠物" }, { id = "boss",  label = "Boss" },
        { id = "set",   label = "设置" },
    }
    local tabButtons = {}
    for i, tab in ipairs(TABS) do
        local btn = S.create("TextButton", {
            Name = "Tab_" .. tab.id, Size = UD2(1/#TABS, 0, 1, 0),
            Position = UD2((i-1)/#TABS, 0, 0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Font = ENUM.Font.GothamBold, Text = tab.label,
            TextColor3 = TH.TextDim, TextSize = 16,
            AutoButtonColor = false,
        }, tabBar)
        tabButtons[i] = btn
    end

    local function newPage(name)
        local page = S.create("ScrollingFrame", {
            Name = name, Size = UD2(1, 0, 1, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 6, ScrollBarImageColor3 = TH.Accent,
            CanvasSize = UD2(0, 0, 0, 0), AutomaticCanvasSize = ENUM.AutomaticSize.Y,
            ScrollingDirection = ENUM.ScrollingDirection.Y, Visible = false,
            ClipsDescendants = true,
        }, contentArea)
        S.padding(page, 14, 14, 14, 14)
        S.listLayout(page, 8)
        return page
    end
    local function sectionLabel(parent, text)
        return S.create("TextLabel", {
            Size = UD2(1, 0, 0, 24), BackgroundTransparency = 1,
            Font = ENUM.Font.GothamBold, Text = text,
            TextColor3 = TH.TextMuted, TextSize = 14, TextXAlignment = ENUM.TextXAlignment.Left,
        }, parent)
    end
    local function divider(parent)
        return S.create("Frame", {
            Size = UD2(1, 0, 0, 1), BackgroundColor3 = TH.Border, BorderSizePixel = 0,
        }, parent)
    end
    local function addToggle(parent, label, default, onChange, hint)
        local row = S.create("Frame", {
            Size = UD2(1, 0, 0, hint and 62 or 48),
            BackgroundColor3 = TH.Surface, BorderSizePixel = 0,
        }, parent)
        S.corner(row, 8); S.stroke(row, TH.Border, 1, 0.5)
        S.create("TextLabel", {
            BackgroundTransparency = 1, Position = UDO(14, hint and 8 or 0),
            Size = UD2(1, -90, 0, hint and 26 or 48),
            Font = ENUM.Font.GothamBold, Text = label,
            TextColor3 = TH.Text, TextSize = 16, TextXAlignment = ENUM.TextXAlignment.Left,
        }, row)
        if hint then
            S.create("TextLabel", {
                BackgroundTransparency = 1, Position = UDO(14, 32),
                Size = UD2(1, -90, 0, 22),
                Font = ENUM.Font.Gotham, Text = hint,
                TextColor3 = TH.TextDim, TextSize = 12,
                TextXAlignment = ENUM.TextXAlignment.Left, TextTruncate = ENUM.TextTruncate.AtEnd,
            }, row)
        end
        local tb = S.create("Frame", {
            AnchorPoint = V2(1, 0.5), Position = UD2(1, -14, 0.5, 0),
            Size = UDO(48, 26), BackgroundColor3 = TH.SurfaceAlt, BorderSizePixel = 0,
        }, row)
        S.corner(tb, 13)
        local knob = S.create("Frame", {
            AnchorPoint = V2(0, 0.5), Position = UD2(0, 3, 0.5, 0),
            Size = UDO(20, 20), BackgroundColor3 = TH.TextMuted, BorderSizePixel = 0, ZIndex = 2,
        }, tb)
        S.corner(knob, 10)
        local function render(on)
            if on then
                tb.BackgroundColor3 = TH.Accent
                knob.Position = UD2(1, -23, 0.5, 0)
                knob.BackgroundColor3 = TH.OnAccent
            else
                tb.BackgroundColor3 = TH.SurfaceAlt
                knob.Position = UD2(0, 3, 0.5, 0)
                knob.BackgroundColor3 = TH.TextMuted
            end
        end
        render(default)
        local ca = S.create("TextButton", { Size = UD2(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, row)
        local value = default
        S.track(ca.MouseButton1Click:Connect(function()
            value = not value; render(value)
            if onChange then onChange(value) end
        end))
        return { set = function(v) value = v; render(v) end, get = function() return value end }
    end
    local function addInput(parent, label, default, minV, maxV, onChange, hint)
        local row = S.create("Frame", {
            Size = UD2(1, 0, 0, hint and 62 or 48),
            BackgroundColor3 = TH.Surface, BorderSizePixel = 0,
        }, parent)
        S.corner(row, 8); S.stroke(row, TH.Border, 1, 0.5)
        S.create("TextLabel", {
            BackgroundTransparency = 1, Position = UDO(14, hint and 8 or 0),
            Size = UD2(1, -130, 0, hint and 26 or 48),
            Font = ENUM.Font.GothamBold, Text = label,
            TextColor3 = TH.Text, TextSize = 16, TextXAlignment = ENUM.TextXAlignment.Left,
        }, row)
        if hint then
            S.create("TextLabel", {
                BackgroundTransparency = 1, Position = UDO(14, 32),
                Size = UD2(1, -130, 0, 22),
                Font = ENUM.Font.Gotham, Text = hint,
                TextColor3 = TH.TextDim, TextSize = 12,
                TextXAlignment = ENUM.TextXAlignment.Left, TextTruncate = ENUM.TextTruncate.AtEnd,
            }, row)
        end
        local box = S.create("TextBox", {
            AnchorPoint = V2(1, 0.5), Position = UD2(1, -14, 0.5, 0),
            Size = UDO(100, 32), BackgroundColor3 = TH.Bg2, BorderSizePixel = 0,
            Font = ENUM.Font.GothamBold, Text = tostring(default),
            TextColor3 = TH.Text, TextSize = 16,
            PlaceholderText = string.format("%d-%d", minV, maxV),
            PlaceholderColor3 = TH.TextMuted, ClearTextOnFocus = false,
        }, row)
        S.corner(box, 6); S.stroke(box, TH.Border, 1)
        S.track(box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if not n then box.Text = tostring(default); return end
            n = math.floor(n); n = math.clamp(n, minV, maxV)
            box.Text = tostring(n)
            if onChange then onChange(n) end
        end))
        return box
    end
    local function addTextInput(parent, label, default, onChange, hint)
        local row = S.create("Frame", {
            Size = UD2(1, 0, 0, hint and 62 or 48),
            BackgroundColor3 = TH.Surface, BorderSizePixel = 0,
        }, parent)
        S.corner(row, 8); S.stroke(row, TH.Border, 1, 0.5)
        S.create("TextLabel", {
            BackgroundTransparency = 1, Position = UDO(14, hint and 8 or 0),
            Size = UD2(1, -130, 0, hint and 26 or 48),
            Font = ENUM.Font.GothamBold, Text = label,
            TextColor3 = TH.Text, TextSize = 16, TextXAlignment = ENUM.TextXAlignment.Left,
        }, row)
        if hint then
            S.create("TextLabel", {
                BackgroundTransparency = 1, Position = UDO(14, 32),
                Size = UD2(1, -130, 0, 22),
                Font = ENUM.Font.Gotham, Text = hint,
                TextColor3 = TH.TextDim, TextSize = 12,
                TextXAlignment = ENUM.TextXAlignment.Left, TextTruncate = ENUM.TextTruncate.AtEnd,
            }, row)
        end
        local box = S.create("TextBox", {
            AnchorPoint = V2(1, 0.5), Position = UD2(1, -14, 0.5, 0),
            Size = UDO(180, 32), BackgroundColor3 = TH.Bg2, BorderSizePixel = 0,
            Font = ENUM.Font.GothamMedium, Text = tostring(default or ""),
            TextColor3 = TH.Text, TextSize = 13,
            PlaceholderText = "链接或 code", PlaceholderColor3 = TH.TextMuted,
            ClearTextOnFocus = false, TextTruncate = ENUM.TextTruncate.AtEnd,
        }, row)
        S.corner(box, 6); S.stroke(box, TH.Border, 1)
        S.track(box.FocusLost:Connect(function() if onChange then onChange(box.Text) end end))
        return box
    end
    local function addButton(parent, label, onClick, color)
        local btn = S.create("TextButton", {
            Size = UD2(1, 0, 0, 42),
            BackgroundColor3 = color or TH.SurfaceAlt, BorderSizePixel = 0,
            Font = ENUM.Font.GothamBold, Text = label,
            TextColor3 = TH.Text, TextSize = 16, AutoButtonColor = true,
        }, parent)
        S.corner(btn, 8); S.stroke(btn, TH.Border, 1, 0.5)
        S.track(btn.MouseButton1Click:Connect(onClick))
        return btn
    end
    local function addSlider(parent, label, minV, maxV, default, onChange)
        local row = S.create("Frame", {
            Size = UD2(1, 0, 0, 54),
            BackgroundColor3 = TH.Surface, BorderSizePixel = 0,
        }, parent)
        S.corner(row, 8); S.stroke(row, TH.Border, 1, 0.5)
        S.create("TextLabel", {
            BackgroundTransparency = 1, Position = UDO(14, 6),
            Size = UD2(1, -110, 0, 20),
            Font = ENUM.Font.GothamBold, Text = label,
            TextColor3 = TH.Text, TextSize = 15, TextXAlignment = ENUM.TextXAlignment.Left,
        }, row)
        local vl = S.create("TextLabel", {
            BackgroundTransparency = 1, AnchorPoint = V2(1, 0),
            Position = UD2(1, -14, 0, 6),
            Size = UDO(90, 20), Font = ENUM.Font.GothamBold,
            Text = tostring(default), TextColor3 = TH.Accent, TextSize = 15,
            TextXAlignment = ENUM.TextXAlignment.Right,
        }, row)
        local trackBar = S.create("Frame", {
            Position = UDO(14, 32), Size = UD2(1, -28, 0, 8),
            BackgroundColor3 = TH.SurfaceAlt, BorderSizePixel = 0,
        }, row)
        S.corner(trackBar, 4)
        local fill = S.create("Frame", {
            Size = UD2((default - minV) / math.max(1, maxV - minV), 0, 1, 0),
            BackgroundColor3 = TH.Accent, BorderSizePixel = 0,
        }, trackBar)
        S.corner(fill, 4)
        local sb = S.create("TextButton", {
            Size = UD2(1, 0, 1, 22), Position = UDO(0, -7),
            BackgroundTransparency = 1, Text = "",
        }, trackBar)
        local active = false
        local function upd(mx)
            local ap = trackBar.AbsolutePosition
            local as = trackBar.AbsoluteSize
            local r = math.clamp((mx - ap.X) / math.max(1, as.X), 0, 1)
            local v = math.floor(minV + (maxV - minV) * r + 0.5)
            vl.Text = tostring(v)
            fill.Size = UD2((v - minV) / math.max(1, maxV - minV), 0, 1, 0)
            if onChange then onChange(v) end
        end
        S.track(sb.InputBegan:Connect(function(i)
            if i.UserInputType == ENUM.UserInputType.MouseButton1 or i.UserInputType == ENUM.UserInputType.Touch then
                active = true; upd(i.Position.X)
            end
        end))
        S.track(sb.InputEnded:Connect(function(i)
            if i.UserInputType == ENUM.UserInputType.MouseButton1 or i.UserInputType == ENUM.UserInputType.Touch then
                active = false
            end
        end))
        S.track(UIS_IC:Connect(function(i)
            if not active then return end
            if i.UserInputType == ENUM.UserInputType.MouseMovement or i.UserInputType == ENUM.UserInputType.Touch then
                upd(i.Position.X)
            end
        end))
        return { set = function(v) vl.Text = tostring(v); fill.Size = UD2((v - minV) / math.max(1, maxV - minV), 0, 1, 0) end }
    end
    local function addDropdown(parent, label, values, default, onChange)
        local row = S.create("Frame", {
            Size = UD2(1, 0, 0, 48),
            BackgroundColor3 = TH.Surface, BorderSizePixel = 0,
        }, parent)
        S.corner(row, 8); S.stroke(row, TH.Border, 1, 0.5)
        S.create("TextLabel", {
            BackgroundTransparency = 1, Position = UDO(14, 0),
            Size = UD2(0.4, 0, 1, 0),
            Font = ENUM.Font.GothamBold, Text = label,
            TextColor3 = TH.Text, TextSize = 16, TextXAlignment = ENUM.TextXAlignment.Left,
        }, row)
        local dropBtn = S.create("TextButton", {
            AnchorPoint = V2(1, 0.5), Position = UD2(1, -14, 0.5, 0),
            Size = UDO(200, 34), BackgroundColor3 = TH.Bg2, BorderSizePixel = 0,
            Font = ENUM.Font.GothamBold, Text = (default and tostring(default) or "—") .. " ▾",
            TextColor3 = TH.Text, TextSize = 14, TextTruncate = ENUM.TextTruncate.AtEnd,
        }, row)
        S.corner(dropBtn, 6); S.stroke(dropBtn, TH.Border, 1)
        local modal = S.create("Frame", {
            Size = UDO(200, 260), BackgroundColor3 = TH.Surface,
            BorderSizePixel = 0, Visible = false, ZIndex = 300,
        }, main)
        S.corner(modal, 8); S.stroke(modal, TH.Accent, 1.5, 0.2)
        local list = S.create("ScrollingFrame", {
            Size = UD2(1, 0, 1, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 5,
            ScrollBarImageColor3 = TH.Accent,
            CanvasSize = UD2(0, 0, 0, 0), AutomaticCanvasSize = ENUM.AutomaticSize.Y,
            ScrollingDirection = ENUM.ScrollingDirection.Y,
        }, modal)
        S.padding(list, 5, 5, 5, 5); S.listLayout(list, 3)
        local function draw()
            for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            for i, v in ipairs(values) do
                local opt = S.create("TextButton", {
                    Size = UD2(1, 0, 0, 30),
                    BackgroundColor3 = TH.SurfaceAlt, BorderSizePixel = 0,
                    Font = ENUM.Font.GothamMedium, Text = tostring(v),
                    TextColor3 = TH.Text, TextSize = 14, LayoutOrder = i,
                    TextXAlignment = ENUM.TextXAlignment.Left,
                    TextTruncate = ENUM.TextTruncate.AtEnd,
                }, list)
                S.corner(opt, 5); S.padding(opt, 0, 0, 10, 10)
                S.track(opt.MouseButton1Click:Connect(function()
                    dropBtn.Text = tostring(v) .. " ▾"
                    modal.Visible = false
                    if onChange then onChange(v) end
                end))
            end
        end
        draw()
        S.track(dropBtn.MouseButton1Click:Connect(function()
            if modal.Visible then modal.Visible = false; return end
            local bp = dropBtn.AbsolutePosition
            local bs = dropBtn.AbsoluteSize
            local mp = main.AbsolutePosition
            modal.Position = UDO((bp.X - mp.X) + bs.X - 200, (bp.Y - mp.Y) + bs.Y + 6)
            modal.Visible = true
        end))
        S.track(UIS_IB:Connect(function(i)
            if not modal.Visible then return end
            if i.UserInputType ~= ENUM.UserInputType.MouseButton1 and i.UserInputType ~= ENUM.UserInputType.Touch then return end
            local ap = modal.AbsolutePosition; local as = modal.AbsoluteSize
            local ip = i.Position
            local inM = ip.X >= ap.X and ip.X <= ap.X + as.X and ip.Y >= ap.Y and ip.Y <= ap.Y + as.Y
            local bp = dropBtn.AbsolutePosition; local bs = dropBtn.AbsoluteSize
            local inB = ip.X >= bp.X and ip.X <= bp.X + bs.X and ip.Y >= bp.Y and ip.Y <= bp.Y + bs.Y
            if not inM and not inB then modal.Visible = false end
        end))
        return { refresh = function(nv) values = nv; draw() end }
    end
    local function addActionRow(parent, actions)
        local row = S.create("Frame", { Size = UD2(1, 0, 0, 42), BackgroundTransparency = 1 }, parent)
        S.listLayout(row, 8, true)
        for _, a in ipairs(actions) do
            local btn = S.create("TextButton", {
                Size = UD2(1/#actions, -5, 1, 0),
                BackgroundColor3 = a.color or TH.SurfaceAlt, BorderSizePixel = 0,
                Font = ENUM.Font.GothamBold, Text = a.label,
                TextColor3 = TH.Text, TextSize = 15,
            }, row)
            S.corner(btn, 8); S.stroke(btn, TH.Border, 1, 0.5)
            S.track(btn.MouseButton1Click:Connect(a.onClick))
        end
        return row
    end

    local pages = {}
    for _, tab in ipairs(TABS) do pages[tab.id] = newPage("Page_" .. tab.id) end

    -- ============ 锻炼 ============
    do
        local p = pages.train
        sectionLabel(p, "基本锻炼")
        local trainToggle, fastToggle
        trainToggle = addToggle(p, "自动锻炼", S.autoTrain, function(v)
            S.autoTrain = v
            if v and S.fastTrain then S.fastTrain = false; fastToggle.set(false) end
        end, "固定 10 次/秒")
        fastToggle = addToggle(p, "快速锻炼", S.fastTrain, function(v)
            S.fastTrain = v
            if v and S.autoTrain then S.autoTrain = false; trainToggle.set(false) end
        end, "自定义频率（最低 10/s）")
        S.ui.rateBox = addInput(p, "频率（次/秒）", S.fastRate, 1, 50000, function(n)
            S.fastRate = n; S.degradeLevel = 0
        end)
        divider(p)
        sectionLabel(p, "卡顿自调节")
        addToggle(p, "根据帧率自动调节频率", S.adaptiveEnabled, function(v)
            S.adaptiveEnabled = v
        end, "自动调节，永不关闭")
        addSlider(p, "目标帧率阈值", 10, 120, S.adaptiveThreshold, function(v) S.adaptiveThreshold = v end)
        divider(p)
        sectionLabel(p, "工具自动切换")
        local tP, tH, tS
        addToggle(p, "自动切换哑铃", S.toolDumbbell, function(v) S.toolDumbbell = v end)
        tP = addToggle(p, "自动切换俯卧撑", S.toolPushups, function(v)
            S.toolPushups = v
            if v then S.toolHandstands = false; S.toolSitups = false
                if tH then tH.set(false) end; if tS then tS.set(false) end end
        end)
        tH = addToggle(p, "自动切换倒立", S.toolHandstands, function(v)
            S.toolHandstands = v
            if v then S.toolPushups = false; S.toolSitups = false
                if tP then tP.set(false) end; if tS then tS.set(false) end end
        end)
        tS = addToggle(p, "自动切换仰卧起坐", S.toolSitups, function(v)
            S.toolSitups = v
            if v then S.toolPushups = false; S.toolHandstands = false
                if tP then tP.set(false) end; if tH then tH.set(false) end end
        end)
        divider(p)
        sectionLabel(p, "★ 器械模式")
        addDropdown(p, "器械模式", { "哑铃", "三种锻炼", "任意器械" },
            S.machineState.mode == "dumbbell" and "哑铃"
                or S.machineState.mode == "train3" and "三种锻炼"
                or "任意器械",
            function(v)
                if v == "哑铃" then S.machineState.mode = "dumbbell"
                elseif v == "三种锻炼" then S.machineState.mode = "train3"
                else S.machineState.mode = "machine" end
            end)
        addToggle(p, "启用器械传送", S.machineTeleport.enabled, function(v) S.machineTeleport.enabled = v end,
            "传送并触发 useMachine")
        addToggle(p, "自动使用器械（保持开启）", S.machineState.enabled, function(v)
            S.machineState.enabled = v
        end, "器械失败则切哑铃，同时继续锻炼")
    end

    -- ============ 传送 ============
    do
        local p = pages.tele
        sectionLabel(p, "自动传送")
        S.ui.teleToggle = addToggle(p, "循环前往肌肉之王", S.autoTeleport, function(v) S.autoTeleport = v end,
            "Boss 存在时自动暂停")
        addButton(p, "强制传送肌肉之王", function()
            local hrp = S.cache.hrp; if not hrp then return end
            local portal = WS:FindFirstChild("beachToMuscleKing", true)
            local cf = portal and CN(portal.Position + V3(0, 3, 0)) or CN(V3(-8727.1, 406.7, -5796.4))
            hrp.CFrame = cf
            S.notify("已传送", 2)
        end)
        divider(p)
        sectionLabel(p, "循环传送点（互斥循环）")
        addToggle(p, "启用循环传送", S.teleportLoopEnabled, function(v) S.teleportLoopEnabled = v end,
            "按顺序依次传送，每个1秒")
        local tpNames = {}
        for _, t in ipairs(S.TELEPORTS) do table.insert(tpNames, t.name) end
        addDropdown(p, "起始点", tpNames, S.TELEPORTS[S.teleportLoopIndex] and S.TELEPORTS[S.teleportLoopIndex].name or tpNames[1],
            function(v)
                for i, t in ipairs(S.TELEPORTS) do
                    if t.name == v then S.teleportLoopIndex = i; break end
                end
            end)
        divider(p)
        sectionLabel(p, "地图传送点")
        local grid = S.create("Frame", {
            Size = UD2(1, 0, 0, 0), BackgroundTransparency = 1,
            AutomaticSize = ENUM.AutomaticSize.Y,
        }, p)
        S.create("UIGridLayout", {
            CellSize = UD2(0.5, -5, 0, 38),
            CellPadding = UD2(0, 10, 0, 8),
            SortOrder = ENUM.SortOrder.LayoutOrder,
        }, grid)
        for i, tp in ipairs(S.TELEPORTS) do
            local btn = S.create("TextButton", {
                LayoutOrder = i, BackgroundColor3 = TH.SurfaceAlt, BorderSizePixel = 0,
                Font = ENUM.Font.GothamBold, Text = tp.name,
                TextColor3 = TH.Text, TextSize = 15, TextTruncate = ENUM.TextTruncate.AtEnd,
            }, grid)
            S.corner(btn, 6); S.stroke(btn, TH.Border, 1, 0.4)
            S.padding(btn, 0, 0, 10, 10)
            S.track(btn.MouseButton1Click:Connect(function()
                S.teleportTo(tp.pos); S.notify("已传送：" .. tp.name, 2)
            end))
        end
    end

    -- ============ 重生 ============
    do
        local p = pages.reb
        sectionLabel(p, "自动重生")
        S.ui.rebirthToggle = addToggle(p, "自动重生", S.autoRebirth, function(v)
            S.autoRebirth = v
            S.rebirthSavedBySystem = false
        end, "Boss/杀戮时会自动暂停，结束后恢复")
        addInput(p, "频率（次/秒）", S.rebirthRate, 1, 100, function(n) S.rebirthRate = n end)
        addInput(p, "★ 目标重生数（0=无限）", S.rebirthTarget, 0, 1000000, function(n)
            S.rebirthTarget = n
        end, "达到后自动关闭自动重生")
        divider(p)
        sectionLabel(p, "换包重生")
        addToggle(p, "换包重生", S.autoPackRebirth, function(v) S.autoPackRebirth = v end,
            "自动换宠并自动重生")
    end

    -- ============ 杀戮 ============
    do
        local p = pages.kill
        sectionLabel(p, "全图杀戮")
        S.ui.killToggle = addToggle(p, "开启全图杀戮", S.killEnabled, function(v) S.killEnabled = v end,
            "Boss 存在时自动暂停；开启时会暂停自动重生")
        divider(p)
        sectionLabel(p, "善恶过滤")
        addToggle(p, "只杀好人", S.killGoodOnly, function(v) S.killGoodOnly = v end)
        addToggle(p, "只杀坏人", S.killBadOnly, function(v) S.killBadOnly = v end)
        divider(p)
        sectionLabel(p, "好友白名单")
        addToggle(p, "不打好友", S.friendWhitelist, function(v)
            S.friendWhitelist = v
            if v and not S.friendWL.loaded then S.refreshFriendList() end
        end)
        addButton(p, "刷新好友列表", function() S.refreshFriendList() end)
        divider(p)
        sectionLabel(p, "双工具 / 肌肉之王竞争")
        addToggle(p, "杀戮时切换训练工具", S.dualEnabled, function(v) S.dualEnabled = v end)
        addToggle(p, "自动击杀其他肌肉之王", S.autoKingKill, function(v)
            S.autoKingKill = v
            if not v then S.kingKillTarget = nil; S.kingKillActive = false end
        end, "只看打不打得过，自动检测敌方力量/耐力")
    end

    -- ============ 宠物 ============
    do
        local p = pages.pet
        sectionLabel(p, "宠物商店")
        local list = S.getPetShopList()
        local dd = addDropdown(p, "选择宠物", list, S.selectedPet, function(v) S.selectedPet = v end)
        addActionRow(p, {
            { label = "刷新", onClick = function() dd.refresh(S.getPetShopList()) end },
            { label = "购买", color = TH.Accent2, onClick = function() S.buyPet(S.selectedPet) end },
        })
        addToggle(p, "自动购买", S.autoPetBuy, function(v) S.autoPetBuy = v end, "重启后不恢复")
        divider(p)
        sectionLabel(p, "自动轮盘（不持久化）")
        addToggle(p, "自动轮盘", S.autoWheel, function(v) S.autoWheel = v end)
        divider(p)
        sectionLabel(p, "自动吃蛋")
        addToggle(p, "自动吃蛋", S.autoEatEgg, function(v) S.autoEatEgg = v end)
        divider(p)
        sectionLabel(p, "★ 自动换宠（4 预设）")
        addToggle(p, "启用自动换宠", S.petPreset.autoSwitch, function(v) S.petPreset.autoSwitch = v end,
            "执行不同任务时切换宠物")
        addActionRow(p, {
            { label = "保存当前→锻炼", onClick = function()
                local names = {}
                for _, p_ in ipairs(S.getEquippedPetNames()) do
                    local found = false
                    for _, e in ipairs(names) do
                        if e.name == p_.name then e.count = e.count + 1; found = true; break end
                    end
                    if not found then table.insert(names, { name = p_.name, count = 1 }) end
                end
                S.petPreset.train = names
                S.notify("已保存锻炼宠物配置（" .. #names .. " 种）", 4)
            end },
            { label = "保存→重生", onClick = function()
                local names = {}
                for _, p_ in ipairs(S.getEquippedPetNames()) do
                    local found = false
                    for _, e in ipairs(names) do
                        if e.name == p_.name then e.count = e.count + 1; found = true; break end
                    end
                    if not found then table.insert(names, { name = p_.name, count = 1 }) end
                end
                S.petPreset.rebirth = names
                S.notify("已保存重生宠物配置", 4)
            end },
        })
        addActionRow(p, {
            { label = "保存→杀戮", onClick = function()
                local names = {}
                for _, p_ in ipairs(S.getEquippedPetNames()) do
                    local found = false
                    for _, e in ipairs(names) do
                        if e.name == p_.name then e.count = e.count + 1; found = true; break end
                    end
                    if not found then table.insert(names, { name = p_.name, count = 1 }) end
                end
                S.petPreset.kill = names
                S.notify("已保存杀戮宠物配置", 4)
            end },
            { label = "保存→Boss", onClick = function()
                local names = {}
                for _, p_ in ipairs(S.getEquippedPetNames()) do
                    local found = false
                    for _, e in ipairs(names) do
                        if e.name == p_.name then e.count = e.count + 1; found = true; break end
                    end
                    if not found then table.insert(names, { name = p_.name, count = 1 }) end
                end
                S.petPreset.boss = names
                S.notify("已保存 Boss 宠物配置", 4)
            end },
        })
        addButton(p, "立即应用锻炼配置", function() S.petPreset.activeType = nil; S.applyPetPreset("train") end)
    end

    -- ============ Boss ============
    do
        local p = pages.boss
        sectionLabel(p, "自动打 Boss")
        addToggle(p, "自动打 Boss", S.autoBoss, function(v)
            S.autoBoss = v
            if not v and S.bossHoverConn then
                pcall(function() S.bossHoverConn:Disconnect() end); S.bossHoverConn = nil
            end
            if not v then
                S._lastBossAlive = false
                S.setRebirthPause("boss", false)
            end
        end, "Boss 存活时打；暂停杀戮和重生；工具切换 0.4 秒")
        addSlider(p, "悬停高度", 0, 200, S.bossHeight, function(v) S.bossHeight = v end)
        divider(p)
        sectionLabel(p, "自动开宝箱（Boss 死后）")
        addToggle(p, "自动开宝箱", S.autoChest, function(v) S.autoChest = v end,
            "限定坐标±30，Boss 死后自动开")
        addSlider(p, "宝箱延迟（秒）", 0, 30, S.chestDelay, function(v) S.chestDelay = v end)
        addSlider(p, "长按 E 时间（秒）", 1, 10, S.chestHoldTime, function(v) S.chestHoldTime = v end)
    end

    -- ============ 设置 ============
    do
        local p = pages.set
        sectionLabel(p, "★ 全局控制")
        addToggle(p, "暂停脚本所有功能", S.scriptPaused, function(v)
            if v then S.pauseScript() else S.resumeScript() end
        end, "暂停后保留当前状态，关闭时恢复")
        divider(p)
        sectionLabel(p, "窗口外观")
        addSlider(p, "字体大小(%)", 80, 160, math.floor(S.fontScale * 100), function(v)
            S.fontScale = v / 100
        end)
        addSlider(p, "窗口宽度比例(%)", 30, 90, S.uiWidthPct, function(v) S.uiWidthPct = v; S.applyUISize() end)
        addSlider(p, "窗口高度比例(%)", 30, 90, S.uiHeightPct, function(v) S.uiHeightPct = v; S.applyUISize() end)
        addSlider(p, "主窗口不透明度(%)", 30, 100, math.floor(S.uiBgOpacity * 100), function(v)
            S.uiBgOpacity = v / 100; S.applyUIOpacity()
        end)
        addSlider(p, "内容页不透明度(%)", 30, 100, math.floor(S.uiPageOpacity * 100), function(v)
            S.uiPageOpacity = v / 100; S.applyUIOpacity()
        end)
        addActionRow(p, {
            { label = "重置窗口位置", onClick = function()
                if S.ui.main then S.ui.main.Position = UD2(0.5, -260, 0.5, -190) end
                S.savedMainPos = nil
                S.applyUISize(); S.notify("已重置", 2)
            end },
        })
        divider(p)
        sectionLabel(p, "信息悬浮窗")
        S.ui.infoToggle = addToggle(p, "显示实时信息", S.infoWindowEnabled, function(v)
            S.infoWindowEnabled = v
            if S.ui.infoGui then S.ui.infoGui.Enabled = v end
        end)
        addSlider(p, "信息窗大小(%)", 60, 200, S.infoScale, function(v) S.infoScale = v; S.applyUISize() end)
        addSlider(p, "信息窗不透明度(%)", 30, 100, math.floor(S.infoBgOpacity * 100), function(v)
            S.infoBgOpacity = v / 100; S.applyUIOpacity()
        end)
        addToggle(p, "数字格式化显示", S.formatEnabled, function(v) S.formatEnabled = v end)
        divider(p)
        sectionLabel(p, "★ 自动重进")
        addToggle(p, "启用自动重进", S.autoRejoinEnabled, function(v)
            S.autoRejoinEnabled = v; S._rejoinTriggered = false
        end)
        addToggle(p, "★ 紧急重进（弹窗检测）", S.emergencyRejoin, function(v) S.emergencyRejoin = v end,
            "检测到退游弹窗立即重进")
        addDropdown(p, "触发条件", {"任意一个满足", "全部满足"},
            S.rejoinCondition == "all" and "全部满足" or "任意一个满足",
            function(v) S.rejoinCondition = (v == "全部满足") and "all" or "any" end)
        addToggle(p, "内存触发器", S.rejoinEnableMem, function(v) S.rejoinEnableMem = v end)
        addInput(p, "内存阈值（MB）", S.rejoinMemThreshold, 500, 100000, function(n) S.rejoinMemThreshold = n end)
        addToggle(p, "帧率触发器", S.rejoinEnableFps, function(v) S.rejoinEnableFps = v end)
        addInput(p, "帧率下限（FPS）", S.rejoinFpsThreshold, 1, 60, function(n) S.rejoinFpsThreshold = n end)
        addToggle(p, "延迟触发器", S.rejoinEnablePing, function(v) S.rejoinEnablePing = v end)
        addInput(p, "延迟上限（ms）", S.rejoinPingThreshold, 100, 5000, function(n) S.rejoinPingThreshold = n end)
        local serverModeMap = { ["回原服务器"]="same", ["人多的服务器"]="crowded", ["私服"]="private", ["人少的服务器"]="sparse" }
        local serverModeRev = { same="回原服务器", crowded="人多的服务器", private="私服", sparse="人少的服务器" }
        addDropdown(p, "重进目标", {"回原服务器", "人多的服务器", "私服", "人少的服务器"},
            serverModeRev[S.rejoinServerMode] or "回原服务器",
            function(v) S.rejoinServerMode = serverModeMap[v] or "same" end)
        S.ui.privateServerBox = addTextInput(p, "私服链接/code", S.rejoinPrivateServerId, function(s)
            S.rejoinPrivateServerId = s
        end, "仅私服模式使用")
        addActionRow(p, {
            { label = "复制当前私服 ID", color = TH.Accent2, onClick = function()
                local id = S.getPrivateServerId()
                S.currentPrivateServerId = id
                if setclipboard then pcall(setclipboard, id) end
                S.notify("已复制：" .. id:sub(1, 30), 4)
                if S.ui.privateServerBox then S.ui.privateServerBox.Text = id end
                S.rejoinPrivateServerId = id
            end },
            { label = "手动重进", color = TH.Warning, onClick = function()
                S._rejoinTriggered = false
                S.rejoinGame("手动")
            end },
        })
        divider(p)
        sectionLabel(p, "性能优化")
        addToggle(p, "深度防卡顿", S.antiLagEnabled, function(v) S.antiLagEnabled = v end)
        addToggle(p, "渲染剔除", S.renderCullEnabled, function(v) S.renderCullEnabled = v end)
        addSlider(p, "剔除距离", 100, 5000, S.renderCullDist, function(v) S.renderCullDist = v end)
        addToggle(p, "移除纹理", S.textureRemoverEnabled, function(v) S.textureRemoverEnabled = v end)
        divider(p)
        sectionLabel(p, "隐藏")
        addToggle(p, "隐藏自己的宠物", S.hideOwnPets, function(v) S.hideOwnPets = v end)
        addToggle(p, "隐藏所有宠物", S.hideAllPets, function(v) S.hideAllPets = v end)
        addToggle(p, "隐藏器械", S.hideMachines, function(v) S.hideMachines = v end)
        addToggle(p, "隐藏其他 UI", S.hideUIEnabled, function(v)
            S.hideUIEnabled = v
            if v then S.hideAllOtherUI() else S.restoreHiddenUI() end
        end)
    end

    local function switchTab(id)
        for tid, p_ in pairs(pages) do p_.Visible = (tid == id) end
        for i, tab in ipairs(TABS) do
            local on = (tab.id == id)
            tabButtons[i].TextColor3 = on and TH.Accent or TH.TextDim
        end
    end
    for i, btn in ipairs(tabButtons) do
        S.track(btn.MouseButton1Click:Connect(function() switchTab(TABS[i].id) end))
    end
    switchTab("train")

    -- 拖动
    local dragging, dragStart, dragStartPos = false, nil, nil
    local function posIn(btn, pos)
        local ap = btn.AbsolutePosition; local as = btn.AbsoluteSize
        return pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
    end
    S.track(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= ENUM.UserInputType.MouseButton1 and input.UserInputType ~= ENUM.UserInputType.Touch then return end
        if posIn(minBtn, input.Position) or posIn(pillBtn, input.Position) or posIn(closeBtn, input.Position) then return end
        dragging = true; dragStart = input.Position; dragStartPos = main.Position
    end))
    S.track(UIS_IC:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= ENUM.UserInputType.MouseMovement and input.UserInputType ~= ENUM.UserInputType.Touch then return end
        local d = input.Position - dragStart
        main.Position = UD2(dragStartPos.X.Scale, dragStartPos.X.Offset + d.X,
                            dragStartPos.Y.Scale, dragStartPos.Y.Offset + d.Y)
    end))
    S.track(UIS_IE:Connect(function(input)
        if input.UserInputType == ENUM.UserInputType.MouseButton1 or input.UserInputType == ENUM.UserInputType.Touch then
            if dragging then S.savedMainPos = S.serializePos(main.Position); dragging = false end
        end
    end))

    -- 最小化
    local minimized = false
    S.track(minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tabBar.Visible = false; contentArea.Visible = false
            main.Size = UDO(main.Size.X.Offset, 48)
            minBtn.Text = "+"
        else
            tabBar.Visible = true; contentArea.Visible = true
            S.applyUISize()
            minBtn.Text = "—"
        end
    end))

    -- ============ 药丸模式 ============
    local pillFrame = S.create("Frame", {
        Name = "Pill", AnchorPoint = V2(0, 0),
        Position = UD2(0.82, 0, 0.88, 0),
        Size = UDO(180, 44), BackgroundColor3 = TH.Surface,
        BorderSizePixel = 0, Visible = false, ZIndex = 1000,
    }, screen)
    S.corner(pillFrame, 22); S.stroke(pillFrame, TH.Accent, 1.5, 0.2)

    local pillDragArea = S.create("Frame", {
        Name = "DragArea", Size = UDO(50, 44),
        BackgroundColor3 = TH.SurfaceAlt, BorderSizePixel = 0,
    }, pillFrame)
    S.corner(pillDragArea, 22)
    S.create("TextLabel", {
        BackgroundTransparency = 1, Size = UD2(1, 0, 1, 0),
        Font = ENUM.Font.GothamBold, Text = "≡", TextColor3 = TH.Text,
        TextSize = 22,
    }, pillDragArea)

    local pillLabel = S.create("TextButton", {
        Size = UD2(1, -50, 1, 0), Position = UDO(50, 0),
        BackgroundTransparency = 1, Text = "肌肉之王 v33",
        Font = ENUM.Font.GothamBold, TextColor3 = TH.Text, TextSize = 15,
        TextXAlignment = ENUM.TextXAlignment.Center,
    }, pillFrame)
    S.track(pillLabel.MouseButton1Click:Connect(function()
        pillFrame.Visible = false
        main.Visible = true
    end))
    S.track(pillBtn.MouseButton1Click:Connect(function()
        main.Visible = false
        pillFrame.Visible = true
    end))

    -- 药丸拖动
    local pillDrag = false; local pillDS, pillDSP
    S.track(pillDragArea.InputBegan:Connect(function(input)
        if input.UserInputType ~= ENUM.UserInputType.MouseButton1 and input.UserInputType ~= ENUM.UserInputType.Touch then return end
        pillDrag = true; pillDS = input.Position; pillDSP = pillFrame.Position
    end))
    S.track(UIS_IC:Connect(function(input)
        if not pillDrag then return end
        if input.UserInputType ~= ENUM.UserInputType.MouseMovement and input.UserInputType ~= ENUM.UserInputType.Touch then return end
        local d = input.Position - pillDS
        pillFrame.Position = UD2(pillDSP.X.Scale, pillDSP.X.Offset + d.X, pillDSP.Y.Scale, pillDSP.Y.Offset + d.Y)
    end))
    S.track(UIS_IE:Connect(function(input)
        if input.UserInputType == ENUM.UserInputType.MouseButton1 or input.UserInputType == ENUM.UserInputType.Touch then
            if pillDrag then S.UIState.pillPos = pillFrame.Position; pillDrag = false end
        end
    end))

    S.track(closeBtn.MouseButton1Click:Connect(function() S.destroy() end))
end

-- 保存/加载辅助 UI 相关函数
S.hideAllOtherUI = function()
    local HU = S.hiddenUIs
    table.clear(HU)
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui ~= S.ui.screen and gui ~= S.ui.infoGui then
            if gui.Enabled then gui.Enabled = false; table.insert(HU, gui) end
        end
    end
end
S.restoreHiddenUI = function()
    for _, gui in ipairs(S.hiddenUIs) do pcall(function() gui.Enabled = true end) end
    table.clear(S.hiddenUIs)
end

S.applyUISize = function()
    if not S.ui.main then return end
    local cam = WS.CurrentCamera; if not cam then return end
    local vp = cam.ViewportSize
    local w = math.max(400, vp.X * S.uiWidthPct / 100)
    local h = math.max(300, vp.Y * S.uiHeightPct / 100)
    S.ui.main.Size = UDO(w, h)
    if S.ui.contentArea then
        S.ui.contentArea.Size = UD2(1, 0, 1, -(48 + 40))
    end
    if S.ui.infoScale then
        local s = math.clamp(vp.Y / 900, 0.7, 1.6) * (S.infoScale / 100)
        S.ui.infoScale.Scale = s
    end
end
S.applyUIOpacity = function()
    if S.ui.main then S.ui.main.BackgroundTransparency = 1 - S.uiBgOpacity end
    if S.ui.contentArea then S.ui.contentArea.BackgroundTransparency = 1 - S.uiPageOpacity end
    if S.Info.frames.frame then S.Info.frames.frame.BackgroundTransparency = 1 - S.infoBgOpacity end
end

-- 信息窗口
S.buildInfoWindow = function()
    local TH = S.theme
    local Info = S.Info
    local screen = S.create("ScreenGui", {
        Name = "MK_AUTO_INFO", ResetOnSpawn = false,
        ZIndexBehavior = ENUM.ZIndexBehavior.Sibling, DisplayOrder = 99998,
    }, PG)
    S.ui.infoGui = screen
    screen.Enabled = false
    S.ui.infoScale = S.create("UIScale", { Scale = 1 }, screen)
    local frame = S.create("Frame", {
        Name = "InfoFrame", AnchorPoint = V2(0, 0),
        Position = S.deserializePos(S.savedInfoPos, UD2(1, -320, 1, -460)),
        Size = S.deserializeSize(S.savedInfoSize, UDO(320, 480)),
        BackgroundColor3 = TH.Bg, BorderSizePixel = 0,
        ClipsDescendants = true, Active = true,
    }, screen)
    Info.frames.frame = frame
    S.corner(frame, 12); S.stroke(frame, TH.Border, 1)
    local tb = S.create("Frame", {
        Size = UD2(1, 0, 0, 40), BackgroundColor3 = TH.Surface, BorderSizePixel = 0, Active = true,
    }, frame)
    S.corner(tb, 12)
    S.create("TextLabel", {
        BackgroundTransparency = 1, Position = UDO(14, 0),
        Size = UD2(1, -90, 1, 0),
        Font = ENUM.Font.GothamBold, Text = "实时信息",
        TextColor3 = TH.Text, TextSize = 16, TextXAlignment = ENUM.TextXAlignment.Left,
    }, tb)
    local minBtn = S.create("TextButton", {
        Size = UDO(26, 26), Position = UD2(1, -58, 0, 7),
        BackgroundColor3 = TH.SurfaceAlt, BorderSizePixel = 0,
        Font = ENUM.Font.GothamBold, Text = "—", TextColor3 = TH.Text, TextSize = 14,
    }, tb); S.corner(minBtn, 6)
    local closeBtn = S.create("TextButton", {
        Size = UDO(26, 26), Position = UD2(1, -30, 0, 7),
        BackgroundColor3 = TH.Danger, BorderSizePixel = 0,
        Font = ENUM.Font.GothamBold, Text = "✕", TextColor3 = TH.OnAccent, TextSize = 14,
    }, tb); S.corner(closeBtn, 6)
    -- 服务器信息
    S.create("TextLabel", {
        BackgroundTransparency = 1, Position = UDO(12, 42),
        Size = UD2(1, -24, 0, 18),
        Font = ENUM.Font.Gotham, Text = "服务器：" .. S.getPrivateServerId():sub(1, 24),
        TextColor3 = TH.TextDim, TextSize = 11,
        TextXAlignment = ENUM.TextXAlignment.Left,
    }, frame)
    S.create("TextLabel", {
        BackgroundTransparency = 1, Position = UDO(12, 60),
        Size = UD2(1, -24, 0, 18),
        Font = ENUM.Font.Gotham, Text = "游戏 ID：" .. tostring(game.PlaceId),
        TextColor3 = TH.TextDim, TextSize = 11,
        TextXAlignment = ENUM.TextXAlignment.Left,
    }, frame)
    local playerBtn = S.create("TextButton", {
        Position = UDO(10, 82), Size = UD2(1, -20, 0, 32),
        BackgroundColor3 = TH.Surface, BorderSizePixel = 0,
        Font = ENUM.Font.GothamBold, Text = "查看：自己",
        TextColor3 = TH.Text, TextSize = 14,
    }, frame)
    S.corner(playerBtn, 8); S.stroke(playerBtn, TH.Border, 1, 0.5)
    Info.frames.playerBtn = playerBtn
    local dataFrame = S.create("ScrollingFrame", {
        Position = UDO(0, 124), Size = UD2(1, 0, 1, -124),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 5, ScrollBarImageColor3 = TH.Accent,
        CanvasSize = UD2(0, 0, 0, 0), AutomaticCanvasSize = ENUM.AutomaticSize.Y,
        ScrollingDirection = ENUM.ScrollingDirection.Y, ClipsDescendants = true,
    }, frame)
    S.padding(dataFrame, 8, 8, 12, 12); S.listLayout(dataFrame, 6)
    Info.frames.dataFrame = dataFrame

    local function mkRow(label, order)
        local row = S.create("Frame", {
            Size = UD2(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order,
        }, dataFrame)
        S.create("TextLabel", {
            BackgroundTransparency = 1, Size = UD2(0.55, 0, 1, 0),
            Font = ENUM.Font.GothamBold, Text = label,
            TextColor3 = TH.TextDim, TextSize = 14, TextXAlignment = ENUM.TextXAlignment.Left,
        }, row)
        local val = S.create("TextLabel", {
            BackgroundTransparency = 1, Position = UD2(0.55, 0, 0, 0),
            Size = UD2(0.45, 0, 1, 0),
            Font = ENUM.Font.GothamBold, Text = "-",
            TextColor3 = TH.Text, TextSize = 14, TextXAlignment = ENUM.TextXAlignment.Right,
        }, row)
        return val
    end
    Info.rows.strength = mkRow("力量", 1)
    Info.rows.strengthDelta = mkRow("力量增量", 2)
    Info.rows.gems = mkRow("宝石", 3)
    Info.rows.durability = mkRow("耐力", 4)
    Info.rows.rebirths = mkRow("重生", 5)
    Info.rows.petRep = mkRow("宠物反复%", 6)
    Info.rows.ultRep = mkRow("终极反复%", 7)
    Info.rows.passRep = mkRow("通行证", 8)
    Info.rows.speedMul = mkRow("综合速度", 9)
    Info.rows.perHour = mkRow("每小时预计", 10)
    Info.rows.pingRow = mkRow("网络延迟", 11)
    Info.rows.memRow = mkRow("内存占用", 12)
    Info.rows.uptimeRow = mkRow("运行时长", 13)

    -- 拖动
    local dragging, dragStart, startPos = false, nil, nil
    S.track(tb.InputBegan:Connect(function(input)
        if input.UserInputType ~= ENUM.UserInputType.MouseButton1 and input.UserInputType ~= ENUM.UserInputType.Touch then return end
        local ap = closeBtn.AbsolutePosition; local as = closeBtn.AbsoluteSize
        if input.Position.X >= ap.X and input.Position.X <= ap.X + as.X
        and input.Position.Y >= ap.Y and input.Position.Y <= ap.Y + as.Y then return end
        local mp = minBtn.AbsolutePosition; local ms = minBtn.AbsoluteSize
        if input.Position.X >= mp.X and input.Position.X <= mp.X + ms.X
        and input.Position.Y >= mp.Y and input.Position.Y <= mp.Y + ms.Y then return end
        dragging = true; dragStart = input.Position; startPos = frame.Position
    end))
    S.track(UIS_IC:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= ENUM.UserInputType.MouseMovement and input.UserInputType ~= ENUM.UserInputType.Touch then return end
        local d = input.Position - dragStart
        frame.Position = UD2(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end))
    S.track(UIS_IE:Connect(function(input)
        if input.UserInputType == ENUM.UserInputType.MouseButton1 or input.UserInputType == ENUM.UserInputType.Touch then
            if dragging then S.savedInfoPos = S.serializePos(frame.Position); dragging = false end
        end
    end))
    S.track(minBtn.MouseButton1Click:Connect(function()
        Info.minimized = not Info.minimized
        if Info.minimized then
            playerBtn.Visible = false; dataFrame.Visible = false
            frame.Size = UDO(frame.Size.X.Offset, 40); minBtn.Text = "+"
        else
            playerBtn.Visible = true; dataFrame.Visible = true
            frame.Size = S.deserializeSize(S.savedInfoSize, UDO(320, 480)); minBtn.Text = "—"
        end
    end))
    S.track(closeBtn.MouseButton1Click:Connect(function()
        S.infoWindowEnabled = false; screen.Enabled = false
        if S.ui.infoToggle then S.ui.infoToggle.set(false) end
    end))
    S.track(playerBtn.MouseButton1Click:Connect(function()
        Info.viewingPlayer = LP
        playerBtn.Text = "查看：自己"
    end))
    Info.viewingPlayer = LP
end

S.refreshInfoWindow = function()
    local Info = S.Info
    if not Info.frames.frame or not S.ui.infoGui then return end
    if not S.ui.infoGui.Enabled or Info.minimized then return end
    local plr = Info.viewingPlayer
    if not plr or not plr.Parent then Info.viewingPlayer = LP; plr = LP end
    local isSelf = (plr == LP)
    local function setRow(row, label, value, color)
        if not row then return end
        if value == nil then row.Text = "-"; row.TextColor3 = S.theme.TextMuted
        else row.Text = tostring(value); row.TextColor3 = color or S.theme.Text end
    end
    Info.rows.strength.Text = S.formatNumber(S.stat(plr, "Strength"))
    Info.rows.gems.Text = S.formatNumber(S.stat(plr, "Gems"))
    Info.rows.durability.Text = S.formatNumber(S.stat(plr, "Durability"))
    Info.rows.rebirths.Text = S.formatNumber(S.stat(plr, "Rebirths"))
    -- 其他人隐藏 self-only 项
    if isSelf then
        if S.sessionStartStrength then
            local d = S.stat(plr, "Strength") - S.sessionStartStrength
            Info.rows.strengthDelta.Text = (d >= 0 and "+" or "") .. S.formatNumber(d)
            Info.rows.strengthDelta.TextColor3 = d >= 0 and S.theme.Success or S.theme.Danger
        end
        local RC = S.repCache
        Info.rows.petRep.Text = string.format("%d%%", RC.pet)
        Info.rows.ultRep.Text = string.format("%d%%", RC.ult)
        Info.rows.passRep.Text = RC.x2 and "x2" or "无"
        Info.rows.speedMul.Text = string.format("%.2fx", RC.speedMul)
        local s = S.strengthPerSec
        Info.rows.perHour.Text = S.formatNumber(s * 3600)
        local p = S.ping
        Info.rows.pingRow.Text = p > 0 and (math.floor(p) .. " ms") or "-"
        if p > 0 then
            Info.rows.pingRow.TextColor3 = p < 80 and S.theme.Success or (p < 200 and S.theme.Warning or S.theme.Danger)
        end
        Info.rows.memRow.Text = string.format("%d MB", S.memMb or 0)
        local up = math.floor(S.sessionUptime or 0)
        local uh = math.floor(up / 3600); local um = math.floor((up % 3600) / 60)
        Info.rows.uptimeRow.Text = string.format("%dh %dm", uh, um)
    else
        for _, k in ipairs({"strengthDelta","petRep","ultRep","passRep","speedMul","perHour","pingRow","memRow","uptimeRow"}) do
            Info.rows[k].Text = "-"
        end
    end
end

-- ============================================================
-- 销毁
-- ============================================================
S.destroy = function()
    if S.destroyed then return end
    pcall(S.saveConfig)
    S.destroyed = true
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    table.clear(S.conns)
    S.cancelAllThreads()
    pcall(S.releaseGravityLock)
    pcall(function() WS.Gravity = S.originalGravity end)
    pcall(S.disableAntiLag); pcall(S.disableRenderCull)
    pcall(S.restoreHiddenPets); pcall(S.restoreHiddenMachines)
    pcall(S.disableTex); pcall(S.restoreHiddenUI)
    if S.bossHoverConn then pcall(function() S.bossHoverConn:Disconnect() end) end
    if S.ui.screen then pcall(function() S.ui.screen:Destroy() end); S.ui.screen = nil end
    if S.ui.infoGui then pcall(function() S.ui.infoGui:Destroy() end); S.ui.infoGui = nil end
    pcall(function() collectgarbage("collect") end)
    if _G[PLUGIN_ID] and _G[PLUGIN_ID].version == VERSION then _G[PLUGIN_ID] = nil end
end

-- ============================================================
-- 启动
-- ============================================================
S.loadConfig()
S.buildUI()
S.buildInfoWindow()
S.applyUISize()
S.applyUIOpacity()

-- 自动初始化
if S.antiLagEnabled then pcall(S.enableAntiLag) end
if S.textureRemoverEnabled then pcall(S.enableTex) end
if S.hideUIEnabled then pcall(S.hideAllOtherUI) end
if S.infoWindowEnabled and S.ui.infoGui then S.ui.infoGui.Enabled = true end
if S.friendWhitelist then task.delay(2, function() S.refreshFriendList() end) end

local cam = WS.CurrentCamera
if cam then S.track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(S.applyUISize)) end

S.track(LP.CharacterAdded:Connect(function()
    S.cache.char = nil; S.cache.hum = nil; S.cache.hrp = nil
    S.killTarget = nil; S.kingKillTarget = nil; S.kingKillActive = false
    S.toolCooldown = false; S.toolOwnedByKill = false
    S.dualCurrentMode = "punch"
    S.muscleEventRef = nil; S.rebirthEventRef = nil
    S.portalCache = nil; S.portalCacheAt = 0
    S._missingSince = 0; S._lastSuicide = 0; S._suicideCount = 0
    S.bossKilledAt = 0; S.bossWasAlive = false; S.chestTaskActive = false
    S.bossDeathPos = nil
    S.petPreset.activeType = nil
    table.clear(S.renderCull.hidden)
    table.clear(S.petHider.own); table.clear(S.petHider.all); table.clear(S.petHider.machines)
    task.wait(1)
    pcall(S.setupGravityLock)
    if S.hideUIEnabled then pcall(S.hideAllOtherUI) end
end))

-- 当前角色立即设置反重力锁（如果开着自动锻炼/传送等）
task.spawn(function()
    task.wait(1)
    pcall(S.setupGravityLock)
end)

S.track(HB:Connect(S.onHeartbeat))

_G[PLUGIN_ID] = { version = VERSION, cleanup = S.destroy }
S.notify("肌肉之王自动化 v33 已加载", 4)
