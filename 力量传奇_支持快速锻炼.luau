--!nonstrict
-- 肌肉之王自动化 v8
-- 任务链架构 / 杀戮允许锻炼+重生 / 取消穿墙

local SCRIPT_ID   = "__MUSCLE_KING_AUTO__"
local VERSION     = 800
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
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Theme = {
    Background = Color3.fromRGB(20, 22, 28),
    Surface    = Color3.fromRGB(28, 31, 39),
    SurfaceAlt = Color3.fromRGB(36, 40, 50),
    Border     = Color3.fromRGB(50, 56, 70),
    Accent     = Color3.fromRGB(96, 158, 255),
    AccentDim  = Color3.fromRGB(42, 70, 120),
    Text       = Color3.fromRGB(232, 236, 244),
    TextDim    = Color3.fromRGB(148, 156, 172),
    Warning    = Color3.fromRGB(255, 200, 80),
}

-- ============================================================
-- 全局状态
-- ============================================================
local State = {
    destroyed = false, conns = {}, ui = {},

    autoTrain = false, fastTrain = false, fastRate = 20,
    autoTeleport = false, lastTeleportAt = 0,
    autoRebirth = false, rebirthRate = 2, lastRebirthAt = 0,

    toolDumbbell = true, toolPushups = false,
    toolHandstands = false, toolSitups = false,
    lastToolCheck = 0, toolCooldown = false,

    killEnabled = false, killThreshold = 5,
    killScanAt = 0, killTarget = nil, killLastAttack = 0,
    killSavedState = nil,
    toolOwnedByKill = false,

    adaptiveEnabled = false, adaptiveThreshold = 30,
    adaptiveStep = 100, adaptiveStableCount = 0, lastAdaptiveAt = 0,

    originalGravity = Workspace.Gravity,
    muscleEventRef = nil, rebirthEventRef = nil, lastRebirthScan = 0,

    trainAccum = 0, time = 0,
    fpsWinTime = 0, fpsWinFrames = 0, avgFps = 60,
    lastDegradeAt = 0, degradeLevel = 0,

    lastAFKClick = 0, lastSaveAt = 0,
}

-- ============================================================
-- 工具函数
-- ============================================================
local function track(c) if c then table.insert(State.conns, c) end return c end

local function create(cls, props, parent)
    local i = Instance.new(cls)
    for k, v in pairs(props) do if k ~= "Parent" then i[k] = v end end
    if parent then i.Parent = parent end
    return i
end

local function corner(p, r) return create("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p) end
local function stroke(p, c, t)
    return create("UIStroke", {
        Color = c or Theme.Border, Thickness = t or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end

local function notify(text, duration)
    duration = duration or 3
    if State.destroyed or not State.ui.screen then return end
    local label = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.04, 0),
        Size = UDim2.fromOffset(440, 52),
        BackgroundColor3 = Color3.fromRGB(30, 32, 40),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = text, TextColor3 = Theme.Warning,
        TextSize = 15, TextWrapped = true, ZIndex = 100,
    }, State.ui.screen)
    corner(label, 10)
    stroke(label, Theme.Warning, 2)
    task.delay(duration, function() pcall(function() label:Destroy() end) end)
end

-- ============================================================
-- 配置
-- ============================================================
local function saveConfig()
    if State.destroyed or type(writefile) ~= "function" then return end
    local data = {
        autoTrain = State.autoTrain, fastTrain = State.fastTrain, fastRate = State.fastRate,
        autoTeleport = State.autoTeleport, autoRebirth = State.autoRebirth, rebirthRate = State.rebirthRate,
        toolDumbbell = State.toolDumbbell, toolPushups = State.toolPushups,
        toolHandstands = State.toolHandstands, toolSitups = State.toolSitups,
        killThreshold = State.killThreshold,
        adaptiveEnabled = State.adaptiveEnabled, adaptiveThreshold = State.adaptiveThreshold,
    }
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if ok and encoded then pcall(writefile, CONFIG_FILE, encoded) end
end

local function loadConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    local exists = false
    pcall(function() exists = isfile(CONFIG_FILE) end)
    if not exists then return end
    local ok, content = pcall(readfile, CONFIG_FILE)
    if not ok or type(content) ~= "string" then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 or type(data) ~= "table" then return end
    local function bool(k, f) if type(data[k]) == "boolean" then return data[k] end return f end
    local function num(k, f, lo, hi)
        local v = tonumber(data[k]) if not v then return f end
        v = math.floor(v)
        if lo then v = math.max(lo, v) end
        if hi then v = math.min(hi, v) end
        return v
    end
    State.autoTrain = bool("autoTrain", State.autoTrain)
    State.fastTrain = bool("fastTrain", State.fastTrain)
    State.fastRate = num("fastRate", State.fastRate, 1, 50000)
    State.autoTeleport = bool("autoTeleport", State.autoTeleport)
    State.autoRebirth = bool("autoRebirth", State.autoRebirth)
    State.rebirthRate = num("rebirthRate", State.rebirthRate, 1, 100)
    State.toolDumbbell = bool("toolDumbbell", State.toolDumbbell)
    State.toolPushups = bool("toolPushups", State.toolPushups)
    State.toolHandstands = bool("toolHandstands", State.toolHandstands)
    State.toolSitups = bool("toolSitups", State.toolSitups)
    State.killThreshold = num("killThreshold", State.killThreshold, 1, 100)
    State.adaptiveEnabled = bool("adaptiveEnabled", State.adaptiveEnabled)
    State.adaptiveThreshold = num("adaptiveThreshold", State.adaptiveThreshold, 10, 120)
end

-- ============================================================
-- 清理
-- ============================================================
local function destroy()
    if State.destroyed then return end
    State.destroyed = true
    pcall(saveConfig)
    for _, c in ipairs(State.conns) do pcall(function() c:Disconnect() end) end
    table.clear(State.conns)
    pcall(function() Workspace.Gravity = State.originalGravity end)
    if State.ui.screen then
        pcall(function() State.ui.screen:Destroy() end)
        State.ui.screen = nil
    end
    if _G[SCRIPT_ID] and _G[SCRIPT_ID].version == VERSION then _G[SCRIPT_ID] = nil end
end

-- ============================================================
-- 反 AFK（点击后立即恢复鼠标）
-- ============================================================
local function performAFKClick()
    if State.destroyed then return end
    local camera = Workspace.CurrentCamera
    local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local tx, ty = vp.X - 8, vp.Y - 8

    local ox, oy, hasOrig = 0, 0, false
    local ok0, mloc = pcall(function() return UserInputService:GetMouseLocation() end)
    if ok0 and mloc then ox, oy = mloc.X, mloc.Y hasOrig = true end

    if type(mousemoveabs) == "function" and type(mouse1click) == "function" then
        local ok = pcall(function()
            mousemoveabs(tx, ty)
            mouse1click()
            if hasOrig then mousemoveabs(ox, oy) end
        end)
        if ok then return end
    end

    local ok2, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
    if ok2 and VIM then
        pcall(function()
            VIM:SendMouseButtonEvent(tx, ty, 0, true, game, 0)
            VIM:SendMouseButtonEvent(tx, ty, 0, false, game, 0)
            if hasOrig then VIM:SendMouseMoveEvent(ox, oy, game) end
        end)
    end
end

-- ============================================================
-- 工具关键字
-- ============================================================
local TOOL_KEYWORDS = {
    dumbbell   = { "barbell", "dumbbell", "weight", "哑铃", "杠铃" },
    pushups    = { "pushup", "push up", "push-up", "俯卧撑" },
    handstands = { "handstand", "hand stand", "hand-stand", "倒立" },
    situps     = { "situp", "sit up", "sit-up", "仰卧起坐" },
    punch      = { "punch", "拳", "fist", "空手", "拳头" },
}

local function matchKeyword(name, list)
    local n = name:lower()
    for _, kw in ipairs(list) do if n:find(kw) then return true end end
    return false
end

local function isToolMatch(tool, list)
    if not tool or not tool:IsA("Tool") then return false end
    return matchKeyword(tool.Name, list)
end

local function isEquipped(list)
    local char = LocalPlayer.Character
    if not char then return false end
    for _, c in ipairs(char:GetChildren()) do
        if isToolMatch(c, list) then return true end
    end
    return false
end

local function hasInBackpack(list)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false end
    for _, c in ipairs(bp:GetChildren()) do
        if isToolMatch(c, list) then return true end
    end
    return false
end

local function tryEquip(list)
    if isEquipped(list) then return true end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false end
    for _, c in ipairs(bp:GetChildren()) do
        if isToolMatch(c, list) then
            local char = LocalPlayer.Character
            local h = char and char:FindFirstChildOfClass("Humanoid")
            if h then
                pcall(function() h:EquipTool(c) end)
                return true
            end
        end
    end
    return false
end

local function toolExists(list) return isEquipped(list) or hasInBackpack(list) end

local function suicide()
    local char = LocalPlayer.Character
    if not char then return end
    local h = char:FindFirstChildOfClass("Humanoid")
    if h and h.Health > 0 then h.Health = 0
    else pcall(function() char:BreakJoints() end) end
end

-- ============================================================
-- 数值读取
-- ============================================================
local function getMyStrength()
    local v = LocalPlayer:FindFirstChild("Strength")
    if v and v:IsA("ValueBase") then return tonumber(v.Value) or 0 end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local s = ls:FindFirstChild("Strength")
        if s and s:IsA("ValueBase") then return tonumber(s.Value) or 0 end
    end
    return 0
end

local function getPlayerDurability(plr)
    if not plr then return nil end
    local v = plr:FindFirstChild("Durability")
    if v and v:IsA("ValueBase") then return tonumber(v.Value) or 0 end
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        local d = ls:FindFirstChild("Durability")
        if d and d:IsA("ValueBase") then return tonumber(d.Value) or 0 end
    end
    return nil
end

-- ============================================================
-- 事件引用
-- ============================================================
local function getMuscleEvent()
    local cached = State.muscleEventRef
    if cached and cached.Parent then return cached end
    local ev = LocalPlayer:FindFirstChild("muscleEvent")
    State.muscleEventRef = ev
    return ev
end

local function findRebirthEvent()
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    if rEvents then
        local ev = rEvents:FindFirstChild("rebirthRemote")
        if ev and (ev:IsA("RemoteEvent") or ev:IsA("RemoteFunction")) then return ev end
    end
    for _, name in ipairs({ "rebirthRemote", "RebirthRemote", "rebirth", "Rebirth",
        "rebirthEvent", "RebirthEvent", "doRebirth", "requestRebirth" }) do
        local obj = ReplicatedStorage:FindFirstChild(name, true)
        if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then return obj end
    end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if obj.Name:lower():find("rebirth") then return obj end
        end
    end
    return nil
end

local function getRebirthEvent()
    local cached = State.rebirthEventRef
    if cached and cached.Parent then return cached end
    if State.time - State.lastRebirthScan < 3 then return nil end
    State.lastRebirthScan = State.time
    local found = findRebirthEvent()
    State.rebirthEventRef = found
    return found
end

local function getMuscleKingCFrame()
    local part = Workspace:FindFirstChild("beachToMuscleKing", true)
    if part and part:IsA("BasePart") then return part.CFrame end
    return CFrame.new(Vector3.new(-8727.1, 406.7, -5796.4))
end

local function doTeleport()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function() hrp.CFrame = getMuscleKingCFrame() end)
end

local function fireRebirth()
    local ev = getRebirthEvent()
    if not ev then return end
    task.spawn(function()
        pcall(function()
            if ev:IsA("RemoteFunction") then ev:InvokeServer("rebirthRequest")
            elseif ev:IsA("RemoteEvent") then ev:FireServer("rebirthRequest") end
        end)
    end)
end

-- ============================================================
-- 杀戮任务（无穿墙）
-- ============================================================
local function getCharacterHRP(plr)
    local char = plr and plr.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return nil end
    return hrp, h
end

local function selectKillTarget()
    local myStrength = getMyStrength()
    local threshold = State.killThreshold or 5
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local hrp = getCharacterHRP(plr)
            if hrp then
                local dur = getPlayerDurability(plr)
                if dur == nil then return plr end
                if myStrength > 0 and myStrength * threshold >= dur then return plr end
            end
        end
    end
    return nil
end

local function ensurePunchEquipped()
    if isEquipped(TOOL_KEYWORDS.punch) then return true end
    return tryEquip(TOOL_KEYWORDS.punch)
end

local function activatePunch()
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

-- 位置吸附：保持 2.5 格距离，不穿墙，保持 CanCollide
local function applyKillMovement(targetHRP)
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local delta = targetHRP.Position - myHRP.Position
    local dist = delta.Magnitude
    if dist > 3 then
        local newPos = targetHRP.Position - delta.Unit * 2.5
        local newCF = CFrame.new(newPos, targetHRP.Position)
        pcall(function()
            myHRP.CFrame = newCF
            myHRP.AssemblyLinearVelocity = Vector3.zero
            myHRP.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function runKillTick(dt)
    -- 每 0.5 秒重新扫描
    if State.time - State.killScanAt >= 0.5 then
        State.killScanAt = State.time
        local cur = State.killTarget
        local valid = cur and getCharacterHRP(cur)
        if not valid then
            State.killTarget = selectKillTarget()
        else
            local myStrength = getMyStrength()
            local dur = getPlayerDurability(cur)
            if dur and myStrength > 0 and myStrength * (State.killThreshold or 5) < dur then
                State.killTarget = selectKillTarget()
            end
        end
        State.toolOwnedByKill = State.killTarget ~= nil
    end

    local target = State.killTarget
    if not target then
        State.toolOwnedByKill = false
        return
    end

    local targetHRP = getCharacterHRP(target)
    if not targetHRP then
        State.killTarget = nil
        State.toolOwnedByKill = false
        return
    end

    applyKillMovement(targetHRP)

    if State.time - State.killLastAttack >= 0.05 then
        State.killLastAttack = State.time
        ensurePunchEquipped()
        activatePunch()
    end
end

-- ============================================================
-- 梯度自适应
-- ============================================================
local function applyRateToUI(rate)
    if State.ui.rateBox then State.ui.rateBox.Text = tostring(rate) end
end

local function runAdaptive()
    if not State.adaptiveEnabled or not State.fastTrain then return end
    if State.time - State.lastAdaptiveAt < 1 then return end
    State.lastAdaptiveAt = State.time

    local fps = State.avgFps
    local threshold = State.adaptiveThreshold or 30

    if fps < threshold then
        local ratio = fps / threshold
        local newRate
        if ratio < 0.4 then newRate = math.max(1, math.floor(State.fastRate * 0.4))
        elseif ratio < 0.7 then newRate = math.max(1, math.floor(State.fastRate * 0.7))
        else newRate = math.max(1, math.floor(State.fastRate * 0.9)) end
        if newRate ~= State.fastRate then
            State.fastRate = newRate
            State.adaptiveStep = 100
            State.adaptiveStableCount = 0
            applyRateToUI(newRate)
        end
    else
        if fps > threshold * 1.15 then
            State.adaptiveStableCount = State.adaptiveStableCount + 1
            if State.adaptiveStableCount >= 2 then
                local step = State.adaptiveStep
                State.fastRate = math.min(50000, State.fastRate + step)
                State.adaptiveStep = math.min(2000, State.adaptiveStep * 2)
                State.adaptiveStableCount = 0
                applyRateToUI(State.fastRate)
            end
        else
            State.adaptiveStableCount = 0
        end
    end
end

local function handleDegradation()
    if State.time - State.lastDegradeAt < 3 then return end
    State.lastDegradeAt = State.time
    if State.degradeLevel == 0 then
        State.degradeLevel = 1
        State.fastRate = 500
        applyRateToUI(500)
        notify("检测到严重卡顿，已降至 500 次/秒", 3)
    elseif State.degradeLevel == 1 then
        State.degradeLevel = 2
        State.fastRate = 100
        applyRateToUI(100)
        notify("仍然卡顿，已降至 100 次/秒", 3)
    elseif State.degradeLevel == 2 then
        State.degradeLevel = 3
        State.fastTrain = false
        State.autoTrain = false
        if State.ui.fastToggle then State.ui.fastToggle.set(false) end
        if State.ui.trainToggle then State.ui.trainToggle.set(false) end
        notify("孩子，你的设备这么差就别玩游戏了", 6)
    end
end

-- ============================================================
-- 任务链架构
-- ============================================================
-- 优先级：数值越大越先执行
local TaskPriority = {
    AFK      = 200,
    KILL     = 150,
    REBIRTH  = 120,
    TELEPORT = 100,
    TOOL     = 80,
    TRAIN    = 60,
    SAVE     = 10,
}

local TaskChain = {}

local function registerTask(task)
    table.insert(TaskChain, task)
    table.sort(TaskChain, function(a, b) return a.priority > b.priority end)
end

local function runTaskChain(dt)
    for _, task in ipairs(TaskChain) do
        if task.enabled and not task.enabled() then
            -- 任务未启用，如果之前有状态需要重置，调用 onDisable
            if task._wasActive and task.onDisable then
                pcall(task.onDisable)
            end
            task._wasActive = false
        else
            if not task._wasActive and task.onEnable then
                pcall(task.onEnable)
            end
            task._wasActive = true
            if task.tick then
                local ok, err = pcall(task.tick, dt)
                if not ok then warn("[TaskChain:" .. task.id .. "]", err) end
            end
        end
    end
end

-- ============================================================
-- 任务定义
-- ============================================================

-- 反 AFK
registerTask({
    id = "afk", priority = TaskPriority.AFK,
    enabled = function() return true end,
    tick = function(dt)
        if State.time - State.lastAFKClick >= 60 then
            State.lastAFKClick = State.time
            performAFKClick()
        end
    end,
})

-- 杀戮
registerTask({
    id = "kill", priority = TaskPriority.KILL,
    enabled = function() return State.killEnabled end,
    onEnable = function()
        State.killSavedState = { autoTeleport = State.autoTeleport }
        State.autoTeleport = false
        if State.ui.teleToggle then State.ui.teleToggle.set(false) end
        State.killTarget = nil
        State.killScanAt = 0
        notify("已进入全图杀戮模式", 3)
    end,
    onDisable = function()
        if State.killSavedState then
            State.autoTeleport = State.killSavedState.autoTeleport
            if State.ui.teleToggle then State.ui.teleToggle.set(State.autoTeleport) end
            State.killSavedState = nil
        end
        State.killTarget = nil
        State.toolOwnedByKill = false
        notify("已退出杀戮模式", 3)
    end,
    tick = function(dt)
        runKillTick(dt)
    end,
})

-- 重生
registerTask({
    id = "rebirth", priority = TaskPriority.REBIRTH,
    enabled = function() return State.autoRebirth end,
    tick = function(dt)
        local interval = 1 / math.max(1, State.rebirthRate)
        if State.time - State.lastRebirthAt >= interval then
            State.lastRebirthAt = State.time
            fireRebirth()
        end
    end,
})

-- 自动传送（杀戮开启时被禁用）
registerTask({
    id = "teleport", priority = TaskPriority.TELEPORT,
    enabled = function() return State.autoTeleport and not State.killEnabled end,
    tick = function(dt)
        if State.time - State.lastTeleportAt >= 0.05 then
            State.lastTeleportAt = State.time
            doTeleport()
        end
    end,
})

-- 工具切换（杀戮持有目标时让位给拳击）
registerTask({
    id = "tool", priority = TaskPriority.TOOL,
    enabled = function()
        local isTraining = State.autoTrain or State.fastTrain
        return isTraining and not State.toolCooldown and not State.toolOwnedByKill
    end,
    tick = function(dt)
        if State.time - State.lastToolCheck < 0.1 then return end
        State.lastToolCheck = State.time

        local selected = {}
        if State.toolPushups then table.insert(selected, TOOL_KEYWORDS.pushups) end
        if State.toolHandstands then table.insert(selected, TOOL_KEYWORDS.handstands) end
        if State.toolSitups then table.insert(selected, TOOL_KEYWORDS.situps) end

        local equippedSpecial = false
        for _, kw in ipairs(selected) do
            if tryEquip(kw) then equippedSpecial = true break end
        end
        local equippedDumbbell = false
        if not equippedSpecial and State.toolDumbbell then
            equippedDumbbell = tryEquip(TOOL_KEYWORDS.dumbbell)
        end
        if not equippedSpecial and not equippedDumbbell then
            local anyExists = false
            for _, kw in ipairs(selected) do
                if toolExists(kw) then anyExists = true break end
            end
            if not anyExists and State.toolDumbbell and toolExists(TOOL_KEYWORDS.dumbbell) then
                anyExists = true
            end
            if not anyExists then
                local hasAny = State.toolDumbbell or #selected > 0
                if hasAny then
                    State.toolCooldown = true
                    suicide()
                    task.delay(15, function()
                        if not State.destroyed then State.toolCooldown = false end
                    end)
                end
            end
        end
    end,
})

-- 锻炼（杀戮期间仍然允许，但工具切换让位给拳击）
registerTask({
    id = "train", priority = TaskPriority.TRAIN,
    enabled = function() return State.autoTrain or State.fastTrain end,
    tick = function(dt)
        local rate = 0
        if State.fastTrain then rate = State.fastRate
        elseif State.autoTrain then rate = 10 end
        if rate <= 0 then return end

        State.trainAccum = State.trainAccum + rate * dt
        local count = math.floor(State.trainAccum)
        if count > 0 then
            State.trainAccum = State.trainAccum - count
            if count > 2000 then count = 2000 end
            local ev = getMuscleEvent()
            if ev then
                pcall(function()
                    for _ = 1, count do ev:FireServer("rep") end
                end)
            end
        end
    end,
})

-- 配置保存
registerTask({
    id = "save", priority = TaskPriority.SAVE,
    enabled = function() return true end,
    tick = function(dt)
        if State.time - State.lastSaveAt >= 2 then
            State.lastSaveAt = State.time
            task.spawn(saveConfig)
        end
    end,
})

-- ============================================================
-- 全局状态更新（重力、帧率）
-- ============================================================
local function updateGlobalState(dt)
    -- 重力：杀戮或自动传送任一开启 → 0
    local wantsGravityZero = State.killEnabled or State.autoTeleport
    if wantsGravityZero then
        if Workspace.Gravity ~= 0 then pcall(function() Workspace.Gravity = 0 end) end
    else
        if Workspace.Gravity ~= State.originalGravity then
            pcall(function() Workspace.Gravity = State.originalGravity end)
        end
    end

    -- 帧率窗口
    State.fpsWinTime = State.fpsWinTime + dt
    State.fpsWinFrames = State.fpsWinFrames + 1
    if State.fpsWinTime >= 0.5 then
        State.avgFps = State.fpsWinFrames / State.fpsWinTime
        State.fpsWinTime = 0
        State.fpsWinFrames = 0
        if State.fastTrain then
            if State.adaptiveEnabled then runAdaptive()
            elseif State.avgFps < 5 then handleDegradation() end
        end
    end
end

-- ============================================================
-- 主循环
-- ============================================================
local function onHeartbeat(dt)
    if State.destroyed then return end
    State.time = State.time + dt
    updateGlobalState(dt)
    runTaskChain(dt)
end

-- ============================================================
-- 角色重生监听（重置杀戮目标与工具冷却）
-- ============================================================
track(LocalPlayer.CharacterAdded:Connect(function()
    State.killTarget = nil
    State.toolCooldown = false
    State.toolOwnedByKill = false
end))

-- ============================================================
-- UI
-- ============================================================
local function buildUI()
    local screen = create("ScreenGui", {
        Name = "MuscleKingAutoUI", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 99999,
    }, PlayerGui)
    State.ui.screen = screen

    local WIN_W, WIN_H = 350, 440
    local TITLE_H, TAB_H = 40, 40

    local main = create("Frame", {
        Name = "Main", AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
        Size = UDim2.fromOffset(WIN_W, WIN_H),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0, ClipsDescendants = true, Active = true,
    }, screen)
    State.ui.main = main
    corner(main, 14)
    stroke(main, Theme.Border, 1)

    local titleBar = create("Frame", {
        Name = "TitleBar", Size = UDim2.new(1, 0, 0, TITLE_H),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, Active = true,
    }, main)
    corner(titleBar, 14)

    create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Font = Enum.Font.GothamBold, Text = "肌肉之王自动化",
        TextColor3 = Theme.Text, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, titleBar)

    local minBtn = create("TextButton", {
        Name = "Minimize", Size = UDim2.fromOffset(28, 26),
        Position = UDim2.new(1, -68, 0, 7),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, Text = "—",
        TextColor3 = Theme.TextDim, TextSize = 16, AutoButtonColor = true,
    }, titleBar)
    corner(minBtn, 8)

    local closeBtn = create("TextButton", {
        Name = "Close", Size = UDim2.fromOffset(28, 26),
        Position = UDim2.new(1, -36, 0, 7),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, Text = "×",
        TextColor3 = Theme.TextDim, TextSize = 18, AutoButtonColor = true,
    }, titleBar)
    corner(closeBtn, 8)

    local tabBar = create("Frame", {
        Name = "TabBar", Position = UDim2.fromOffset(0, TITLE_H),
        Size = UDim2.new(1, 0, 0, TAB_H), BackgroundTransparency = 1,
    }, main)

    local TAB_W = 1/4
    local function makeTab(id, text, order)
        local btn = create("TextButton", {
            Name = "Tab_" .. id,
            Size = UDim2.new(TAB_W, -6, 1, -10),
            Position = UDim2.new((order - 1) * TAB_W, 3, 0, 5),
            BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium, Text = text,
            TextColor3 = Theme.TextDim, TextSize = 12, AutoButtonColor = true,
        }, tabBar)
        corner(btn, 8)
        return btn
    end

    local tabTrain = makeTab("train", "锻炼", 1)
    local tabTele  = makeTab("tele",  "传送", 2)
    local tabReb   = makeTab("reb",   "重生", 3)
    local tabKill  = makeTab("kill",  "杀戮", 4)

    local content = create("Frame", {
        Name = "Content", Position = UDim2.fromOffset(0, TITLE_H + TAB_H),
        Size = UDim2.new(1, 0, 1, -(TITLE_H + TAB_H)),
        BackgroundTransparency = 1,
    }, main)

    local function newPage(name)
        local page = create("ScrollingFrame", {
            Name = name, Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false, ClipsDescendants = true,
        }, content)
        create("UIPadding", {
            PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        }, page)
        create("UIListLayout", {
            Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        }, page)
        return page
    end

    local function addDivider(parent, text)
        return create("TextLabel", {
            Size = UDim2.new(1, -6, 0, 22), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, Text = text,
            TextColor3 = Theme.TextDim, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, parent)
    end

    local function addRowToggle(parent, label, default, onChange)
        local row = create("Frame", {
            Size = UDim2.new(1, -6, 0, 42),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 10)
        stroke(row, Theme.Border, 1)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -76, 1, 0),
            Font = Enum.Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local tb = create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(42, 22),
            BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        }, row)
        corner(tb, 11)
        local knob = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 3, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = Theme.TextDim, BorderSizePixel = 0, ZIndex = 2,
        }, tb)
        corner(knob, 8)
        local function render(on)
            if on then
                tb.BackgroundColor3 = Theme.Accent
                knob.Position = UDim2.new(1, -19, 0.5, 0)
                knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            else
                tb.BackgroundColor3 = Theme.SurfaceAlt
                knob.Position = UDim2.new(0, 3, 0.5, 0)
                knob.BackgroundColor3 = Theme.TextDim
            end
        end
        render(default)
        local ca = create("TextButton", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
        }, row)
        local value = default
        track(ca.MouseButton1Click:Connect(function()
            value = not value
            render(value)
            if onChange then onChange(value) end
        end))
        return { set = function(v) value = v render(v) end,
                 get = function() return value end }
    end

    local function addInput(parent, label, default, minVal, maxVal, onChange)
        local row = create("Frame", {
            Size = UDim2.new(1, -6, 0, 42),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 10)
        stroke(row, Theme.Border, 1)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -132, 1, 0),
            Font = Enum.Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local box = create("TextBox", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(105, 28),
            BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium, Text = tostring(default),
            TextColor3 = Theme.Text, TextSize = 13,
            PlaceholderText = string.format("%d-%d", minVal, maxVal),
            ClearTextOnFocus = false,
        }, row)
        corner(box, 8)
        stroke(box, Theme.Border, 1)
        track(box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if not n then box.Text = tostring(default) return end
            n = math.floor(n)
            n = math.clamp(n, minVal, maxVal)
            box.Text = tostring(n)
            if onChange then onChange(n) end
        end))
        return box
    end

    local function addActionButton(parent, label, onClick)
        local btn = create("TextButton", {
            Size = UDim2.new(1, -6, 0, 38),
            BackgroundColor3 = Theme.AccentDim, BorderSizePixel = 0,
            Font = Enum.Font.GothamBold, Text = label,
            TextColor3 = Theme.Text, TextSize = 14, AutoButtonColor = true,
        }, parent)
        corner(btn, 10)
        stroke(btn, Theme.Accent, 1)
        track(btn.MouseButton1Click:Connect(onClick))
        return btn
    end

    local function addHint(parent, text)
        create("TextLabel", {
            Size = UDim2.new(1, -6, 0, 32), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, Text = text,
            TextColor3 = Theme.TextDim, TextSize = 11,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, parent)
    end

    -- 锻炼页
    local trainPage = newPage("TrainPage")
    local trainToggle, fastToggle
    trainToggle = addRowToggle(trainPage, "自动锻炼（固定 10 次/秒）", State.autoTrain, function(v)
        State.autoTrain = v
        if v and State.fastTrain then State.fastTrain = false fastToggle.set(false) end
    end)
    fastToggle = addRowToggle(trainPage, "快速锻炼（自定义频率）", State.fastTrain, function(v)
        State.fastTrain = v
        State.degradeLevel = 0
        if v and State.autoTrain then State.autoTrain = false trainToggle.set(false) end
    end)
    State.ui.rateBox = addInput(trainPage, "频率（次/秒）", State.fastRate, 1, 50000, function(n)
        if State.adaptiveEnabled then
            if State.ui.rateBox then State.ui.rateBox.Text = tostring(State.fastRate) end
            return
        end
        State.fastRate = n
        State.degradeLevel = 0
    end)
    addDivider(trainPage, "── 防卡顿 ──")
    addRowToggle(trainPage, "快速锻炼卡顿自调节", State.adaptiveEnabled, function(v)
        State.adaptiveEnabled = v
        if State.ui.rateBox then
            State.ui.rateBox.TextEditable = not v
            State.ui.rateBox.TextColor3 = v and Theme.TextDim or Theme.Text
        end
        State.adaptiveStep = 100
        State.adaptiveStableCount = 0
    end)
    addInput(trainPage, "目标帧率阈值", State.adaptiveThreshold, 10, 120, function(n)
        State.adaptiveThreshold = n
    end)
    addHint(trainPage, "开启后频率每秒自动向目标帧率调节（梯度步进 100 → 200 → 400...）。")
    addDivider(trainPage, "── 工具自动切换 ──")
    local toolPushToggle, toolHandToggle, toolSitToggle
    addRowToggle(trainPage, "自动切换哑铃（兜底）", State.toolDumbbell, function(v) State.toolDumbbell = v end)
    toolPushToggle = addRowToggle(trainPage, "自动切换俯卧撑", State.toolPushups, function(v)
        State.toolPushups = v
        if v then
            State.toolHandstands = false State.toolSitups = false
            if toolHandToggle then toolHandToggle.set(false) end
            if toolSitToggle then toolSitToggle.set(false) end
        end
    end)
    toolHandToggle = addRowToggle(trainPage, "自动切换倒立", State.toolHandstands, function(v)
        State.toolHandstands = v
        if v then
            State.toolPushups = false State.toolSitups = false
            if toolPushToggle then toolPushToggle.set(false) end
            if toolSitToggle then toolSitToggle.set(false) end
        end
    end)
    toolSitToggle = addRowToggle(trainPage, "自动切换仰卧起坐", State.toolSitups, function(v)
        State.toolSitups = v
        if v then
            State.toolPushups = false State.toolHandstands = false
            if toolPushToggle then toolPushToggle.set(false) end
            if toolHandToggle then toolHandToggle.set(false) end
        end
    end)
    addHint(trainPage, "杀戮锁定目标时工具切换会自动让位给拳击。")

    -- 传送页
    local telePage = newPage("TelePage")
    State.ui.teleToggle = addRowToggle(telePage, "自动前往肌肉之王", State.autoTeleport, function(v)
        State.autoTeleport = v
    end)
    addActionButton(telePage, "单次传送", function() doTeleport() end)
    addHint(telePage, "开启后每 0.05 秒循环传送，重力强制为 0。杀戮开启时会暂时被接管。")

    -- 重生页
    local rebPage = newPage("RebPage")
    addRowToggle(rebPage, "自动重生", State.autoRebirth, function(v) State.autoRebirth = v end)
    addInput(rebPage, "频率（次/秒）", State.rebirthRate, 1, 100, function(n) State.rebirthRate = n end)
    addHint(rebPage, "使用 rEvents.rebirthRemote（RemoteFunction）+ 'rebirthRequest'。可与杀戮同时运行。")

    -- 杀戮页
    local killPage = newPage("KillPage")
    addRowToggle(killPage, "全图杀戮", State.killEnabled, function(v) State.killEnabled = v end)
    addInput(killPage, "力量/耐久 阈值", State.killThreshold, 1, 100, function(n) State.killThreshold = n end)
    addHint(killPage, "自动切拳击，靠近目标 2.5 格内攻击。杀戮期间锻炼、重生仍可运行。")

    local function switchTab(id)
        trainPage.Visible = (id == "train")
        telePage.Visible = (id == "tele")
        rebPage.Visible = (id == "reb")
        killPage.Visible = (id == "kill")
        local function tint(btn, on)
            btn.BackgroundColor3 = on and Theme.Accent or Theme.SurfaceAlt
            btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.TextDim
        end
        tint(tabTrain, id == "train")
        tint(tabTele, id == "tele")
        tint(tabReb, id == "reb")
        tint(tabKill, id == "kill")
    end

    track(tabTrain.MouseButton1Click:Connect(function() switchTab("train") end))
    track(tabTele.MouseButton1Click:Connect(function() switchTab("tele") end))
    track(tabReb.MouseButton1Click:Connect(function() switchTab("reb") end))
    track(tabKill.MouseButton1Click:Connect(function() switchTab("kill") end))
    switchTab("train")

    local dragging, dragStart, dragStartPos = false, nil, nil
    local function posIn(btn, pos)
        local ap = btn.AbsolutePosition
        local as = btn.AbsoluteSize
        return pos.X >= ap.X and pos.X <= ap.X + as.X
           and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
    end

    track(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if posIn(minBtn, input.Position) or posIn(closeBtn, input.Position) then return end
        dragging = true
        dragStart = input.Position
        dragStartPos = main.Position
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - dragStart
        main.Position = UDim2.new(
            dragStartPos.X.Scale, dragStartPos.X.Offset + d.X,
            dragStartPos.Y.Scale, dragStartPos.Y.Offset + d.Y
        )
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    local minimized = false
    track(minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tabBar.Visible = false
            content.Visible = false
            main.Size = UDim2.fromOffset(WIN_W, TITLE_H)
            minBtn.Text = "+"
        else
            tabBar.Visible = true
            content.Visible = true
            main.Size = UDim2.fromOffset(WIN_W, WIN_H)
            minBtn.Text = "—"
        end
    end))

    track(closeBtn.MouseButton1Click:Connect(destroy))

    State.ui.trainToggle = trainToggle
    State.ui.fastToggle = fastToggle
end

-- ============================================================
-- 启动
-- ============================================================
loadConfig()
buildUI()
if State.ui.rateBox then
    State.ui.rateBox.TextEditable = not State.adaptiveEnabled
    State.ui.rateBox.TextColor3 = State.adaptiveEnabled and Theme.TextDim or Theme.Text
end
track(RunService.Heartbeat:Connect(onHeartbeat))

_G[SCRIPT_ID] = { version = VERSION, cleanup = destroy }
