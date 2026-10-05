--!nonstrict
-- 肌肉之王自动化 v10
-- 设置页 / 信息悬浮窗 / 宠物加成检测 / 触发器保护

local SCRIPT_ID   = "__MUSCLE_KING_AUTO__"
local VERSION     = 1000
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

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local GetPlayers           = Players.GetPlayers
local RS_Heartbeat         = RunService.Heartbeat
local UIS_GetMouseLocation = UserInputService.GetMouseLocation
local LP_FindFirstChild    = LocalPlayer.FindFirstChild
local UDim2_new            = UDim2.new
local UDim2_fromOffset     = UDim2.fromOffset
local UDim2_fromScale      = UDim2.fromScale
local Color3_fromRGB       = Color3.fromRGB
local Vector2_new          = Vector2.new
local Enum_Font            = Enum.Font

local Theme = {
    Background = Color3_fromRGB(20, 22, 28),
    Surface    = Color3_fromRGB(28, 31, 39),
    SurfaceAlt = Color3_fromRGB(36, 40, 50),
    Border     = Color3_fromRGB(50, 56, 70),
    Accent     = Color3_fromRGB(96, 158, 255),
    AccentDim  = Color3_fromRGB(42, 70, 120),
    Text       = Color3_fromRGB(232, 236, 244),
    TextDim    = Color3_fromRGB(148, 156, 172),
    Warning    = Color3_fromRGB(255, 200, 80),
    Success    = Color3_fromRGB(120, 220, 160),
}

-- ============================================================
-- 状态
-- ============================================================
local State = {
    destroyed = false, conns = {}, ui = {},

    autoTrain = false, fastTrain = false, fastRate = 20,
    autoTeleport = false, lastTeleportAt = 0, lastCameraFix = 0,
    autoRebirth = false, rebirthRate = 2, lastRebirthAt = 0,

    toolDumbbell = true, toolPushups = false,
    toolHandstands = false, toolSitups = false,
    lastToolCheck = 0, toolCooldown = false,

    killEnabled = false, killThreshold = 5,
    killScanAt = 0, killTarget = nil, killLastAttack = 0,
    killSavedState = nil, toolOwnedByKill = false,

    dualEnabled = true, dualLastSwitch = 0, dualCurrentMode = "punch",

    adaptiveEnabled = false, adaptiveThreshold = 30,
    adaptiveStep = 100, adaptiveStableCount = 0, lastAdaptiveAt = 0,

    -- 新功能
    antiLagEnabled = false,
    textureRemoverEnabled = false,
    hideUIEnabled = false,
    infoWindowEnabled = false,
    formatEnabled = true,

    -- 宠物加成
    petRepBonus = 0, petRepBonusCheckedAt = 0, petRepWarned = false,

    originalGravity = Workspace.Gravity,
    muscleEventRef = nil, rebirthEventRef = nil, lastRebirthScan = 0,

    trainAccum = 0, time = 0,
    fpsWinTime = 0, fpsWinFrames = 0, avgFps = 60,
    lastDegradeAt = 0, degradeLevel = 0,

    lastAFKClick = 0, lastSaveAt = 0,
}

local Cache = { char = nil, hum = nil, hrp = nil }
local function refreshCache()
    local c = LocalPlayer.Character
    if c ~= Cache.char then
        Cache.char = c; Cache.hum = nil; Cache.hrp = nil
    end
    if c then
        if not Cache.hum or not Cache.hum.Parent then
            Cache.hum = c:FindFirstChildOfClass("Humanoid")
        end
        if not Cache.hrp or not Cache.hrp.Parent then
            Cache.hrp = c:FindFirstChild("HumanoidRootPart")
        end
    end
end

-- ============================================================
-- 通用
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
    return create("UIStroke", { Color = c or Theme.Border, Thickness = t or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

local function notify(text, duration)
    duration = duration or 3
    if State.destroyed or not State.ui.screen then return end
    local label = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2_new(0.5, 0, 0.04, 0),
        Size = UDim2_fromOffset(440, 52),
        BackgroundColor3 = Color3_fromRGB(30, 32, 40),
        BorderSizePixel = 0, Font = Enum_Font.GothamBold,
        Text = text, TextColor3 = Theme.Warning,
        TextSize = 15, TextWrapped = true, ZIndex = 200,
    }, State.ui.screen)
    corner(label, 10)
    stroke(label, Theme.Warning, 2)
    task.delay(duration, function() pcall(function() label:Destroy() end) end)
end

-- ============================================================
-- 数字格式化
-- ============================================================
local SUFFIXES = {
    "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
    "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}
local function formatNumber(n)
    n = tonumber(n) or 0
    if not State.formatEnabled then
        return tostring(math.floor(n))
    end
    local neg = n < 0
    n = math.abs(n)
    if n < 1000 then
        return (neg and "-" or "") .. string.format("%.0f", n)
    end
    local idx = 1
    while n >= 1000 and idx < #SUFFIXES do
        n = n / 1000
        idx = idx + 1
    end
    return (neg and "-" or "") .. string.format("%.3f%s", n, SUFFIXES[idx])
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
        killThreshold = State.killThreshold, dualEnabled = State.dualEnabled,
        adaptiveEnabled = State.adaptiveEnabled, adaptiveThreshold = State.adaptiveThreshold,
        antiLagEnabled = State.antiLagEnabled,
        textureRemoverEnabled = State.textureRemoverEnabled,
        hideUIEnabled = State.hideUIEnabled,
        infoWindowEnabled = State.infoWindowEnabled,
        formatEnabled = State.formatEnabled,
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
    State.dualEnabled = bool("dualEnabled", State.dualEnabled)
    State.adaptiveEnabled = bool("adaptiveEnabled", State.adaptiveEnabled)
    State.adaptiveThreshold = num("adaptiveThreshold", State.adaptiveThreshold, 10, 120)
    State.antiLagEnabled = bool("antiLagEnabled", State.antiLagEnabled)
    State.textureRemoverEnabled = bool("textureRemoverEnabled", State.textureRemoverEnabled)
    State.hideUIEnabled = bool("hideUIEnabled", State.hideUIEnabled)
    State.infoWindowEnabled = bool("infoWindowEnabled", State.infoWindowEnabled)
    State.formatEnabled = bool("formatEnabled", State.formatEnabled)
end

-- ============================================================
-- 清理
-- ============================================================
local AntiLag = { particles = {}, shadows = {}, originalLighting = nil, enabled = false, rescanAt = 0 }
local TextureRemover = { saved = {}, enabled = false, rescanAt = 0 }
local HiddenUIs = {}

local function disableAntiLag()
    if not AntiLag.enabled then return end
    AntiLag.enabled = false
    for _, p in ipairs(AntiLag.particles) do pcall(function() p.Enabled = true end) end
    table.clear(AntiLag.particles)
    for _, item in ipairs(AntiLag.shadows) do
        pcall(function() item.part.CastShadow = item.value end)
    end
    table.clear(AntiLag.shadows)
    if AntiLag.originalLighting then
        for k, v in pairs(AntiLag.originalLighting) do
            pcall(function() Lighting[k] = v end)
        end
        AntiLag.originalLighting = nil
    end
end

local function disableTextureRemover()
    if not TextureRemover.enabled then return end
    TextureRemover.enabled = false
    for _, item in ipairs(TextureRemover.saved) do
        pcall(function() item.obj[item.prop] = item.value end)
    end
    table.clear(TextureRemover.saved)
end

local function restoreHiddenUI()
    for _, gui in ipairs(HiddenUIs) do
        pcall(function() gui.Enabled = true end)
    end
    table.clear(HiddenUIs)
end

local function destroy()
    if State.destroyed then return end
    State.destroyed = true
    pcall(saveConfig)
    for _, c in ipairs(State.conns) do pcall(function() c:Disconnect() end) end
    table.clear(State.conns)
    pcall(function() Workspace.Gravity = State.originalGravity end)
    pcall(disableAntiLag)
    pcall(disableTextureRemover)
    pcall(restoreHiddenUI)
    if State.ui.screen then pcall(function() State.ui.screen:Destroy() end) State.ui.screen = nil end
    if State.ui.infoGui then pcall(function() State.ui.infoGui:Destroy() end) State.ui.infoGui = nil end
    if _G[SCRIPT_ID] and _G[SCRIPT_ID].version == VERSION then _G[SCRIPT_ID] = nil end
end

-- ============================================================
-- 反 AFK
-- ============================================================
local function performAFKClick()
    if State.destroyed then return end
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2_new(1920, 1080)
    local tx, ty = vp.X - 8, vp.Y - 8
    local ox, oy, hasOrig = 0, 0, false
    local ok0, mloc = pcall(UIS_GetMouseLocation, UserInputService)
    if ok0 and mloc then ox, oy = mloc.X, mloc.Y hasOrig = true end
    if type(mousemoveabs) == "function" and type(mouse1click) == "function" then
        local ok = pcall(function()
            mousemoveabs(tx, ty); mouse1click()
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
-- 摄像机矫正
-- ============================================================
local function fixCamera()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local hum = Cache.hum
    if hum and hum.Parent then
        pcall(function()
            if cam.CameraSubject ~= hum then cam.CameraSubject = hum end
            if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
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
    for i = 1, #list do if n:find(list[i]) then return true end end
    return false
end

local function isToolMatch(tool, list)
    if not tool or not tool:IsA("Tool") then return false end
    return matchKeyword(tool.Name, list)
end

local function isEquipped(list)
    local char = Cache.char
    if not char then return false end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") and matchKeyword(c.Name, list) then return true end
    end
    return false
end

local function hasInBackpack(list)
    local bp = LP_FindFirstChild(LocalPlayer, "Backpack")
    if not bp then return false end
    for _, c in ipairs(bp:GetChildren()) do
        if c:IsA("Tool") and matchKeyword(c.Name, list) then return true end
    end
    return false
end

local function findAnyTool(list)
    local char = Cache.char
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") and matchKeyword(c.Name, list) then return c end
        end
    end
    local bp = LP_FindFirstChild(LocalPlayer, "Backpack")
    if bp then
        for _, c in ipairs(bp:GetChildren()) do
            if c:IsA("Tool") and matchKeyword(c.Name, list) then return c end
        end
    end
    return nil
end

local function tryEquip(list)
    if isEquipped(list) then return true end
    local hum = Cache.hum
    if not hum then return false end
    local bp = LP_FindFirstChild(LocalPlayer, "Backpack")
    if not bp then return false end
    for _, c in ipairs(bp:GetChildren()) do
        if c:IsA("Tool") and matchKeyword(c.Name, list) then
            pcall(function() hum:EquipTool(c) end)
            return true
        end
    end
    return false
end

local function toolExists(list) return isEquipped(list) or hasInBackpack(list) end

local function suicide()
    local hum = Cache.hum
    if hum and hum.Health > 0 then hum.Health = 0
    elseif Cache.char then pcall(function() Cache.char:BreakJoints() end) end
end

-- ============================================================
-- 数值读取
-- ============================================================
local function getStatValue(plr, name)
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

local function getMyStrength() return getStatValue(LocalPlayer, "Strength") end
local function getPlayerDurability(plr) return getStatValue(plr, "Durability") end

-- 判断是否在机器上（用于避免触发器异常）
local function isOnMachine()
    local m = LP_FindFirstChild(LocalPlayer, "machineInUse")
    if m and m:IsA("ValueBase") then
        local v = m.Value
        if v ~= nil and v ~= "" then return true end
    end
    local t = LP_FindFirstChild(LocalPlayer, "treadmillInUse")
    if t and t:IsA("ValueBase") then
        local v = t.Value
        if v ~= nil and v ~= "" then return true end
    end
    return false
end

-- ============================================================
-- 宠物加成检测
-- ============================================================
local function getEquippedPetRepSpeedBonus()
    local total = 0

    -- 优先从 Workspace.<玩家名>.<Pet>.perksFolder 读
    local folder = Workspace:FindFirstChild(LocalPlayer.Name)
    if folder then
        for _, pet in ipairs(folder:GetChildren()) do
            local perks = pet:FindFirstChild("perksFolder")
            if perks then
                local b = perks:FindFirstChild("repTimeBoostPercent")
                if b and b:IsA("ValueBase") then
                    total = total + (tonumber(b.Value) or 0)
                end
            end
        end
    end

    if total > 0 then return total end

    -- 回退：从 equippedPets + petPreviews
    local equipped = LP_FindFirstChild(LocalPlayer, "equippedPets")
    if not equipped then return 0 end
    local previews = ReplicatedStorage:FindFirstChild("shared")
    if previews then previews = previews:FindFirstChild("runtime") end
    if previews then previews = previews:FindFirstChild("petPreviews") end
    if not previews then return 0 end

    for _, slot in ipairs(equipped:GetChildren()) do
        local name = slot.Value
        if type(name) == "string" and name ~= "" then
            local pet = previews:FindFirstChild(name)
            if pet then
                local perks = pet:FindFirstChild("perksFolder")
                if perks then
                    local b = perks:FindFirstChild("repTimeBoostPercent")
                    if b and b:IsA("ValueBase") then
                        total = total + (tonumber(b.Value) or 0)
                    end
                end
            end
        end
    end
    return total
end

local function refreshPetBonus()
    State.petRepBonus = getEquippedPetRepSpeedBonus()
end

-- ============================================================
-- 事件引用
-- ============================================================
local function getMuscleEvent()
    local cached = State.muscleEventRef
    if cached and cached.Parent then return cached end
    local ev = LP_FindFirstChild(LocalPlayer, "muscleEvent")
    State.muscleEventRef = ev
    return ev
end

local function findRebirthEvent()
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    if rEvents then
        local ev = rEvents:FindFirstChild("rebirthRemote")
        if ev and (ev:IsA("RemoteEvent") or ev:IsA("RemoteFunction")) then return ev end
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

local MUSCLE_KING_CF
local function getMuscleKingCFrame()
    if MUSCLE_KING_CF then return MUSCLE_KING_CF end
    local part = Workspace:FindFirstChild("beachToMuscleKing", true)
    if part and part:IsA("BasePart") then
        MUSCLE_KING_CF = part.CFrame
        return MUSCLE_KING_CF
    end
    return CFrame.new(Vector3.new(-8727.1, 406.7, -5796.4))
end

local function doTeleport()
    local hrp = Cache.hrp
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
-- 防卡顿 / 移除纹理 / 隐藏UI
-- ============================================================
local function enableAntiLag()
    if AntiLag.enabled then return end
    AntiLag.enabled = true
    table.clear(AntiLag.particles)
    table.clear(AntiLag.shadows)
    AntiLag.originalLighting = {
        GlobalShadows = Lighting.GlobalShadows,
        ShadowSoftness = Lighting.ShadowSoftness,
        Brightness = Lighting.Brightness,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
    }
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
        if Lighting.FogEnd > 500 then Lighting.FogEnd = 500 end
        if Lighting.FogStart > 200 then Lighting.FogStart = 200 end
    end)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
        or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            if obj.Enabled then
                obj.Enabled = false
                table.insert(AntiLag.particles, obj)
            end
        elseif obj:IsA("BasePart") then
            if obj.CastShadow then
                table.insert(AntiLag.shadows, { part = obj, value = true })
                obj.CastShadow = false
            end
        end
    end
    AntiLag.rescanAt = State.time + 3
end

local function rescanAntiLag()
    if not AntiLag.enabled then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
        or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            if obj.Enabled then
                obj.Enabled = false
                table.insert(AntiLag.particles, obj)
            end
        elseif obj:IsA("BasePart") and obj.CastShadow then
            table.insert(AntiLag.shadows, { part = obj, value = true })
            obj.CastShadow = false
        end
    end
    AntiLag.rescanAt = State.time + 3
end

local function enableTextureRemover()
    if TextureRemover.enabled then return end
    TextureRemover.enabled = true
    table.clear(TextureRemover.saved)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            if obj.Texture ~= "" then
                table.insert(TextureRemover.saved, { obj = obj, prop = "Texture", value = obj.Texture })
                obj.Texture = ""
            end
        end
    end
    TextureRemover.rescanAt = State.time + 5
end

local function rescanTextureRemover()
    if not TextureRemover.enabled then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            if obj.Texture ~= "" then
                table.insert(TextureRemover.saved, { obj = obj, prop = "Texture", value = obj.Texture })
                obj.Texture = ""
            end
        end
    end
    TextureRemover.rescanAt = State.time + 5
end

local function hideAllUI()
    local pg = PlayerGui
    table.clear(HiddenUIs)
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui ~= State.ui.screen and gui ~= State.ui.infoGui then
            if gui.Enabled then
                gui.Enabled = false
                table.insert(HiddenUIs, gui)
            end
        end
    end
end

-- ============================================================
-- 双工具切换
-- ============================================================
local function findPreferredTrainTool()
    if State.toolPushups then
        local t = findAnyTool(TOOL_KEYWORDS.pushups); if t then return t end
    end
    if State.toolHandstands then
        local t = findAnyTool(TOOL_KEYWORDS.handstands); if t then return t end
    end
    if State.toolSitups then
        local t = findAnyTool(TOOL_KEYWORDS.situps); if t then return t end
    end
    if State.toolDumbbell then
        local t = findAnyTool(TOOL_KEYWORDS.dumbbell); if t then return t end
    end
    return nil
end

local function updateDualTool()
    if not State.dualEnabled then return end
    if not State.killEnabled or not State.killTarget then return end
    if not (State.autoTrain or State.fastTrain) then return end
    local hum = Cache.hum
    if not hum then return end
    if State.time - State.dualLastSwitch < 0.06 then return end
    State.dualLastSwitch = State.time

    if State.dualCurrentMode == "punch" then
        local t = findPreferredTrainTool()
        if t then
            pcall(function() hum:EquipTool(t) end)
            State.dualCurrentMode = "train"
            task.defer(function()
                if not State.destroyed then pcall(function() t:Activate() end) end
            end)
        else
            State.dualCurrentMode = "punch"
        end
    else
        local t = findAnyTool(TOOL_KEYWORDS.punch)
        if t then
            pcall(function() hum:EquipTool(t) end)
            State.dualCurrentMode = "punch"
            task.defer(function()
                if not State.destroyed then pcall(function() t:Activate() end) end
            end)
        else
            State.dualCurrentMode = "train"
        end
    end
end

-- ============================================================
-- 杀戮
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
    local list = GetPlayers(Players)
    for i = 1, #list do
        local plr = list[i]
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

local function applyKillMovement(targetHRP)
    local hrp = Cache.hrp
    if not hrp then return end
    local delta = targetHRP.Position - hrp.Position
    local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
    if distSq > 9 then
        local dist = math.sqrt(distSq)
        local newPos = targetHRP.Position - delta / dist * 2.5
        local newCF = CFrame.new(newPos, targetHRP.Position)
        pcall(function()
            hrp.CFrame = newCF
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function activatePunch()
    local char = Cache.char
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

local function runKillTick(dt)
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
    if not target then State.toolOwnedByKill = false return end
    local targetHRP = getCharacterHRP(target)
    if not targetHRP then
        State.killTarget = nil
        State.toolOwnedByKill = false
        return
    end

    applyKillMovement(targetHRP)

    local dual = State.dualEnabled and (State.autoTrain or State.fastTrain)
    if not dual then
        if State.time - State.killLastAttack >= 0.05 then
            State.killLastAttack = State.time
            if not isEquipped(TOOL_KEYWORDS.punch) then
                tryEquip(TOOL_KEYWORDS.punch)
            end
            activatePunch()
        end
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
        State.degradeLevel = 1; State.fastRate = 500; applyRateToUI(500)
        notify("检测到严重卡顿，已降至 500 次/秒", 3)
    elseif State.degradeLevel == 1 then
        State.degradeLevel = 2; State.fastRate = 100; applyRateToUI(100)
        notify("仍然卡顿，已降至 100 次/秒", 3)
    elseif State.degradeLevel == 2 then
        State.degradeLevel = 3; State.fastTrain = false; State.autoTrain = false
        if State.ui.fastToggle then State.ui.fastToggle.set(false) end
        if State.ui.trainToggle then State.ui.trainToggle.set(false) end
        notify("孩子，你的设备这么差就别玩游戏了", 6)
    end
end

-- ============================================================
-- 信息悬浮窗
-- ============================================================
local InfoWindow = {
    viewingPlayer = nil,
    listOpen = false,
    lastRefresh = 0,
    predictor = { lastStrength = 0, lastAt = 0, ratePerSec = 0 },
}

local function updatePredictor()
    local s = getMyStrength()
    local p = InfoWindow.predictor
    if p.lastAt == 0 then
        p.lastStrength = s; p.lastAt = State.time; return
    end
    local dt = State.time - p.lastAt
    if dt >= 10 then
        local gain = s - p.lastStrength
        if gain > 0 then p.ratePerSec = gain / dt end
        p.lastStrength = s
        p.lastAt = State.time
    end
end

local InfoUI = { rows = {} }

local function createInfoRow(parent, label, order)
    local row = create("Frame", {
        Size = UDim2_new(1, -12, 0, 26),
        BackgroundTransparency = 1,
        LayoutOrder = order,
    }, parent)
    local lbl = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2_new(0.5, 0, 1, 0),
        Font = Enum_Font.GothamMedium,
        Text = label,
        TextColor3 = Theme.TextDim,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local val = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2_new(0.5, 0, 0, 0),
        Size = UDim2_new(0.5, 0, 1, 0),
        Font = Enum_Font.GothamBold,
        Text = "-",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    return val
end

local function buildInfoWindow()
    local screen = create("ScreenGui", {
        Name = "MuscleKingInfoUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 99998,
    }, PlayerGui)
    State.ui.infoGui = screen
    screen.Enabled = false

    local frame = create("Frame", {
        Name = "InfoFrame",
        AnchorPoint = Vector2_new(1, 1),
        Position = UDim2_new(1, -20, 1, -20),
        Size = UDim2_fromOffset(260, 320),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
    }, screen)
    InfoUI.frame = frame
    corner(frame, 12)
    stroke(frame, Theme.Border, 1)

    local titleBar = create("Frame", {
        Size = UDim2_new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Active = true,
    }, frame)
    corner(titleBar, 12)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2_fromOffset(12, 0),
        Size = UDim2_new(1, -90, 1, 0),
        Font = Enum_Font.GothamBold,
        Text = "实时信息",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, titleBar)

    local closeBtn = create("TextButton", {
        Size = UDim2_fromOffset(24, 24),
        Position = UDim2_new(1, -28, 0, 4),
        BackgroundColor3 = Theme.SurfaceAlt,
        BorderSizePixel = 0,
        Font = Enum_Font.GothamBold,
        Text = "×",
        TextColor3 = Theme.TextDim,
        TextSize = 16,
    }, titleBar)
    corner(closeBtn, 6)

    -- 玩家选择按钮
    local playerBtn = create("TextButton", {
        Position = UDim2_fromOffset(10, 40),
        Size = UDim2_new(1, -20, 0, 30),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Font = Enum_Font.GothamMedium,
        Text = "查看：自己 ▼",
        TextColor3 = Theme.Text,
        TextSize = 13,
    }, frame)
    corner(playerBtn, 8)
    stroke(playerBtn, Theme.Border, 1)
    InfoUI.playerBtn = playerBtn

    -- 玩家列表（下拉）
    local listFrame = create("ScrollingFrame", {
        Position = UDim2_fromOffset(10, 72),
        Size = UDim2_new(1, -20, 0, 150),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2_new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 5,
    }, frame)
    corner(listFrame, 8)
    stroke(listFrame, Theme.Border, 1)
    create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
    }, listFrame)
    InfoUI.listFrame = listFrame

    -- 数据区
    local dataFrame = create("Frame", {
        Position = UDim2_fromOffset(0, 108),
        Size = UDim2_new(1, 0, 1, -108),
        BackgroundTransparency = 1,
    }, frame)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0),
    }, dataFrame)
    create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, dataFrame)

    InfoUI.rows.strength = createInfoRow(dataFrame, "力量", 1)
    InfoUI.rows.gems     = createInfoRow(dataFrame, "宝石", 2)
    InfoUI.rows.durability = createInfoRow(dataFrame, "耐力", 3)
    InfoUI.rows.agility  = createInfoRow(dataFrame, "敏捷", 4)
    InfoUI.rows.rebirths = createInfoRow(dataFrame, "重生", 5)
    InfoUI.rows.perHour  = createInfoRow(dataFrame, "每小时预计", 6)
    InfoUI.rows.perDay   = createInfoRow(dataFrame, "每天预计", 7)

    -- 拖动
    local dragging, dragStart, startPos = false, nil, nil
    track(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local ap = closeBtn.AbsolutePosition
        local as = closeBtn.AbsoluteSize
        if input.Position.X >= ap.X and input.Position.X <= ap.X + as.X
        and input.Position.Y >= ap.Y and input.Position.Y <= ap.Y + as.Y then return end
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - dragStart
        frame.Position = UDim2_new(startPos.X.Scale, startPos.X.Offset + d.X,
                                   startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    -- 关闭按钮：隐藏窗口而不是销毁（因为设置页开关控制）
    track(closeBtn.MouseButton1Click:Connect(function()
        State.infoWindowEnabled = false
        screen.Enabled = false
        InfoWindow.listOpen = false
        listFrame.Visible = false
        if State.ui.infoToggle then State.ui.infoToggle.set(false) end
    end))

    -- 玩家列表按钮
    track(playerBtn.MouseButton1Click:Connect(function()
        InfoWindow.listOpen = not InfoWindow.listOpen
        listFrame.Visible = InfoWindow.listOpen
        if InfoWindow.listOpen then
            -- 填充列表
            for _, c in ipairs(listFrame:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            local function addRow(plr, order)
                local name = plr == LocalPlayer and (plr.Name .. " (自己)") or plr.Name
                local btn = create("TextButton", {
                    Size = UDim2_new(1, 0, 0, 24),
                    BackgroundColor3 = Theme.SurfaceAlt,
                    BorderSizePixel = 0,
                    Font = Enum_Font.GothamMedium,
                    Text = name,
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    LayoutOrder = order,
                }, listFrame)
                corner(btn, 6)
                track(btn.MouseButton1Click:Connect(function()
                    InfoWindow.viewingPlayer = plr
                    playerBtn.Text = "查看：" .. (plr == LocalPlayer and "自己" or plr.Name) .. " ▼"
                    InfoWindow.listOpen = false
                    listFrame.Visible = false
                end))
            end
            addRow(LocalPlayer, 1)
            local others = GetPlayers(Players)
            local ord = 2
            for _, plr in ipairs(others) do
                if plr ~= LocalPlayer then addRow(plr, ord) ord = ord + 1 end
            end
        end
    end))

    -- 列表失焦自动关闭
    track(UserInputService.InputBegan:Connect(function(input)
        if not InfoWindow.listOpen then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local lp = listFrame.AbsolutePosition
        local ls = listFrame.AbsoluteSize
        local pb = playerBtn.AbsolutePosition
        local ps = playerBtn.AbsoluteSize
        local ip = input.Position
        local inList = ip.X >= lp.X and ip.X <= lp.X + ls.X and ip.Y >= lp.Y and ip.Y <= lp.Y + ls.Y
        local inBtn = ip.X >= pb.X and ip.X <= pb.X + ps.X and ip.Y >= pb.Y and ip.Y <= pb.Y + ps.Y
        if not inList and not inBtn then
            InfoWindow.listOpen = false
            listFrame.Visible = false
        end
    end))

    InfoWindow.viewingPlayer = LocalPlayer
end

local function refreshInfoWindow()
    if not InfoWindow.frame or not State.ui.infoGui then return end
    if not State.ui.infoGui.Enabled then return end

    local plr = InfoWindow.viewingPlayer or LocalPlayer
    if not plr or not plr.Parent then
        InfoWindow.viewingPlayer = LocalPlayer
        plr = LocalPlayer
        InfoUI.playerBtn.Text = "查看：自己 ▼"
    end

    local strength = getStatValue(plr, "Strength")
    local gems = getStatValue(plr, "Gems")
    local dur = getStatValue(plr, "Durability")
    local agi = getStatValue(plr, "Agility")
    local reb = getStatValue(plr, "Rebirths")

    InfoUI.rows.strength.Text = formatNumber(strength)
    InfoUI.rows.gems.Text = formatNumber(gems)
    InfoUI.rows.durability.Text = formatNumber(dur)
    InfoUI.rows.agility.Text = formatNumber(agi)
    InfoUI.rows.rebirths.Text = formatNumber(reb)

    if plr == LocalPlayer then
        local p = InfoWindow.predictor
        InfoUI.rows.perHour.Text = formatNumber(p.ratePerSec * 3600)
        InfoUI.rows.perDay.Text = formatNumber(p.ratePerSec * 86400)
    else
        InfoUI.rows.perHour.Text = "-"
        InfoUI.rows.perDay.Text = "-"
    end
end

-- ============================================================
-- 任务链
-- ============================================================
local TaskPriority = {
    AFK = 200, KILL = 150, DUAL = 140, REBIRTH = 120,
    TELEPORT = 100, CAMERA = 90, INFO = 85, TOOL = 80, TRAIN = 60, SAVE = 10,
}

local TaskChain = {}
local function registerTask(task)
    table.insert(TaskChain, task)
    table.sort(TaskChain, function(a, b) return a.priority > b.priority end)
end

-- AFK
registerTask({
    id = "afk", priority = TaskPriority.AFK,
    enabled = function() return true end,
    tick = function()
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
        State.dualCurrentMode = "punch"
        notify("已进入全图杀戮模式（自动传送已暂停）", 3)
    end,
    onDisable = function()
        if State.killSavedState then
            State.autoTeleport = State.killSavedState.autoTeleport
            if State.ui.teleToggle then State.ui.teleToggle.set(State.autoTeleport) end
            State.killSavedState = nil
        end
        State.killTarget = nil
        State.toolOwnedByKill = false
        State.dualCurrentMode = "punch"
        notify("已退出杀戮模式（自动传送已恢复）", 3)
    end,
    tick = runKillTick,
})

-- 双工具
registerTask({
    id = "dual", priority = TaskPriority.DUAL,
    enabled = function()
        return State.dualEnabled and State.killEnabled
            and State.killTarget ~= nil
            and (State.autoTrain or State.fastTrain)
    end,
    onDisable = function() State.dualCurrentMode = "punch" end,
    tick = function() updateDualTool() end,
})

-- 重生
registerTask({
    id = "rebirth", priority = TaskPriority.REBIRTH,
    enabled = function() return State.autoRebirth end,
    tick = function()
        local interval = 1 / math.max(1, State.rebirthRate)
        if State.time - State.lastRebirthAt >= interval then
            State.lastRebirthAt = State.time
            fireRebirth()
        end
    end,
})

-- 传送
registerTask({
    id = "teleport", priority = TaskPriority.TELEPORT,
    enabled = function() return State.autoTeleport and not State.killEnabled end,
    tick = function()
        if State.time - State.lastTeleportAt >= 0.05 then
            State.lastTeleportAt = State.time
            doTeleport()
        end
    end,
})

-- 摄像机矫正
registerTask({
    id = "camera", priority = TaskPriority.CAMERA,
    enabled = function() return State.killEnabled or State.autoTeleport end,
    tick = function()
        if State.time - State.lastCameraFix >= 0.5 then
            State.lastCameraFix = State.time
            fixCamera()
        end
    end,
})

-- 信息窗口刷新
registerTask({
    id = "info", priority = TaskPriority.INFO,
    enabled = function() return State.infoWindowEnabled end,
    tick = function()
        updatePredictor()
        if State.time - InfoWindow.lastRefresh >= 0.5 then
            InfoWindow.lastRefresh = State.time
            refreshInfoWindow()
        end
    end,
})

-- 工具切换
registerTask({
    id = "tool", priority = TaskPriority.TOOL,
    enabled = function()
        local isTraining = State.autoTrain or State.fastTrain
        return isTraining and not State.toolCooldown and not State.toolOwnedByKill
    end,
    tick = function()
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

-- 锻炼
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

            -- 触发器保护：不在机器上时不发送，避免异常触发
            if not isOnMachine() then
                return
            end

            local ev = getMuscleEvent()
            if ev then
                for _ = 1, count do
                    pcall(function() ev:FireServer("rep") end)
                end
            end
        end
    end,
})

-- 保存
registerTask({
    id = "save", priority = TaskPriority.SAVE,
    enabled = function() return true end,
    tick = function()
        if State.time - State.lastSaveAt >= 2 then
            State.lastSaveAt = State.time
            task.spawn(saveConfig)
        end
    end,
})

-- ============================================================
-- 全局状态
-- ============================================================
local function updateGlobalState(dt)
    if State.killEnabled or State.autoTeleport then
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
        State.fpsWinTime = 0
        State.fpsWinFrames = 0
        if State.fastTrain then
            if State.adaptiveEnabled then runAdaptive()
            elseif State.avgFps < 5 then handleDegradation() end
        end
    end

    -- 定期重扫防卡顿 / 纹理
    if AntiLag.enabled and State.time >= AntiLag.rescanAt then rescanAntiLag() end
    if TextureRemover.enabled and State.time >= TextureRemover.rescanAt then rescanTextureRemover() end

    -- 宠物加成检测
    if State.time - State.petRepBonusCheckedAt >= 5 then
        State.petRepBonusCheckedAt = State.time
        refreshPetBonus()
    end
end

-- ============================================================
-- 主循环
-- ============================================================
local function onHeartbeat(dt)
    if State.destroyed then return end
    State.time = State.time + dt
    refreshCache()
    updateGlobalState(dt)

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

track(LocalPlayer.CharacterAdded:Connect(function()
    Cache.char = nil; Cache.hum = nil; Cache.hrp = nil
    State.killTarget = nil
    State.toolCooldown = false
    State.toolOwnedByKill = false
    State.dualCurrentMode = "punch"
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
        Name = "Main", AnchorPoint = Vector2_new(0, 0),
        Position = UDim2_new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
        Size = UDim2_fromOffset(WIN_W, WIN_H),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0, ClipsDescendants = true, Active = true,
    }, screen)
    State.ui.main = main
    corner(main, 14)
    stroke(main, Theme.Border, 1)

    local titleBar = create("Frame", {
        Name = "TitleBar", Size = UDim2_new(1, 0, 0, TITLE_H),
        Position = UDim2_fromOffset(0, 0),
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, Active = true,
    }, main)
    corner(titleBar, 14)

    create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2_fromOffset(14, 0),
        Size = UDim2_new(1, -110, 1, 0),
        Font = Enum_Font.GothamBold, Text = "肌肉之王自动化",
        TextColor3 = Theme.Text, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, titleBar)

    local minBtn = create("TextButton", {
        Name = "Minimize", Size = UDim2_fromOffset(28, 26),
        Position = UDim2_new(1, -68, 0, 7),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Enum_Font.GothamBold, Text = "—",
        TextColor3 = Theme.TextDim, TextSize = 16, AutoButtonColor = true,
    }, titleBar)
    corner(minBtn, 8)

    local closeBtn = create("TextButton", {
        Name = "Close", Size = UDim2_fromOffset(28, 26),
        Position = UDim2_new(1, -36, 0, 7),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Enum_Font.GothamBold, Text = "×",
        TextColor3 = Theme.TextDim, TextSize = 18, AutoButtonColor = true,
    }, titleBar)
    corner(closeBtn, 8)

    local tabBar = create("Frame", {
        Name = "TabBar", Position = UDim2_fromOffset(0, TITLE_H),
        Size = UDim2_new(1, 0, 0, TAB_H), BackgroundTransparency = 1,
    }, main)

    local TAB_W = 1/5
    local function makeTab(id, text, order)
        local btn = create("TextButton", {
            Name = "Tab_" .. id,
            Size = UDim2_new(TAB_W, -5, 1, -10),
            Position = UDim2_new((order - 1) * TAB_W, 2, 0, 5),
            BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
            Font = Enum_Font.GothamMedium, Text = text,
            TextColor3 = Theme.TextDim, TextSize = 11, AutoButtonColor = true,
        }, tabBar)
        corner(btn, 8)
        return btn
    end

    local tabTrain = makeTab("train", "锻炼", 1)
    local tabTele  = makeTab("tele",  "传送", 2)
    local tabReb   = makeTab("reb",   "重生", 3)
    local tabKill  = makeTab("kill",  "杀戮", 4)
    local tabSet   = makeTab("set",   "设置", 5)

    local content = create("Frame", {
        Name = "Content", Position = UDim2_fromOffset(0, TITLE_H + TAB_H),
        Size = UDim2_new(1, 0, 1, -(TITLE_H + TAB_H)),
        BackgroundTransparency = 1,
    }, main)

    local function newPage(name)
        local page = create("ScrollingFrame", {
            Name = name, Size = UDim2_new(1, 0, 1, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2_new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false, ClipsDescendants = true,
        }, content)
        create("UIPadding", {
            PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        }, page)
        create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
        return page
    end

    local function addDivider(parent, text)
        return create("TextLabel", {
            Size = UDim2_new(1, -6, 0, 22), BackgroundTransparency = 1,
            Font = Enum_Font.GothamBold, Text = text,
            TextColor3 = Theme.TextDim, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, parent)
    end

    local function addRowToggle(parent, label, default, onChange)
        local row = create("Frame", {
            Size = UDim2_new(1, -6, 0, 42),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 10); stroke(row, Theme.Border, 1)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2_fromOffset(12, 0),
            Size = UDim2_new(1, -76, 1, 0),
            Font = Enum_Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local tb = create("Frame", {
            AnchorPoint = Vector2_new(1, 0.5),
            Position = UDim2_new(1, -12, 0.5, 0),
            Size = UDim2_fromOffset(42, 22),
            BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        }, row)
        corner(tb, 11)
        local knob = create("Frame", {
            AnchorPoint = Vector2_new(0, 0.5),
            Position = UDim2_new(0, 3, 0.5, 0),
            Size = UDim2_fromOffset(16, 16),
            BackgroundColor3 = Theme.TextDim, BorderSizePixel = 0, ZIndex = 2,
        }, tb)
        corner(knob, 8)
        local function render(on)
            if on then
                tb.BackgroundColor3 = Theme.Accent
                knob.Position = UDim2_new(1, -19, 0.5, 0)
                knob.BackgroundColor3 = Color3_fromRGB(255, 255, 255)
            else
                tb.BackgroundColor3 = Theme.SurfaceAlt
                knob.Position = UDim2_new(0, 3, 0.5, 0)
                knob.BackgroundColor3 = Theme.TextDim
            end
        end
        render(default)
        local ca = create("TextButton", {
            Size = UDim2_new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
        }, row)
        local value = default
        track(ca.MouseButton1Click:Connect(function()
            value = not value
            render(value)
            if onChange then onChange(value) end
        end))
        return { set = function(v) value = v render(v) end, get = function() return value end }
    end

    local function addInput(parent, label, default, minVal, maxVal, onChange)
        local row = create("Frame", {
            Size = UDim2_new(1, -6, 0, 42),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 10); stroke(row, Theme.Border, 1)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2_fromOffset(12, 0),
            Size = UDim2_new(1, -132, 1, 0),
            Font = Enum_Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local box = create("TextBox", {
            AnchorPoint = Vector2_new(1, 0.5),
            Position = UDim2_new(1, -12, 0.5, 0),
            Size = UDim2_fromOffset(105, 28),
            BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
            Font = Enum_Font.GothamMedium, Text = tostring(default),
            TextColor3 = Theme.Text, TextSize = 13,
            PlaceholderText = string.format("%d-%d", minVal, maxVal),
            ClearTextOnFocus = false,
        }, row)
        corner(box, 8); stroke(box, Theme.Border, 1)
        track(box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if not n then box.Text = tostring(default) return end
            n = math.floor(n); n = math.clamp(n, minVal, maxVal)
            box.Text = tostring(n)
            if onChange then onChange(n) end
        end))
        return box
    end

    local function addActionButton(parent, label, onClick)
        local btn = create("TextButton", {
            Size = UDim2_new(1, -6, 0, 38),
            BackgroundColor3 = Theme.AccentDim, BorderSizePixel = 0,
            Font = Enum_Font.GothamBold, Text = label,
            TextColor3 = Theme.Text, TextSize = 14, AutoButtonColor = true,
        }, parent)
        corner(btn, 10); stroke(btn, Theme.Accent, 1)
        track(btn.MouseButton1Click:Connect(onClick))
        return btn
    end

    local function addHint(parent, text)
        create("TextLabel", {
            Size = UDim2_new(1, -6, 0, 32), BackgroundTransparency = 1,
            Font = Enum_Font.Gotham, Text = text,
            TextColor3 = Theme.TextDim, TextSize = 11,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, parent)
    end

    -- ===== 锻炼 =====
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
        if v then
            -- 检查宠物 Rep 加成
            refreshPetBonus()
            if State.petRepBonus < 100 then
                notify(string.format("反复速度不足（当前 %d%%），功能可能无效", State.petRepBonus), 5)
            end
        end
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

    -- ===== 传送 =====
    local telePage = newPage("TelePage")
    State.ui.teleToggle = addRowToggle(telePage, "自动前往肌肉之王", State.autoTeleport, function(v)
        State.autoTeleport = v
    end)
    addActionButton(telePage, "单次传送", function() doTeleport() end)
    addHint(telePage, "每 0.05 秒循环传送，重力强制为 0，每 0.5 秒自动矫正摄像机。杀戮开启时会暂时接管。")

    -- ===== 重生 =====
    local rebPage = newPage("RebPage")
    addRowToggle(rebPage, "自动重生", State.autoRebirth, function(v) State.autoRebirth = v end)
    addInput(rebPage, "频率（次/秒）", State.rebirthRate, 1, 100, function(n) State.rebirthRate = n end)
    addHint(rebPage, "使用 rEvents.rebirthRemote（RemoteFunction）+ 'rebirthRequest'。可与杀戮同时运行。")

    -- ===== 杀戮 =====
    local killPage = newPage("KillPage")
    addRowToggle(killPage, "全图杀戮", State.killEnabled, function(v) State.killEnabled = v end)
    addInput(killPage, "力量/耐久 阈值", State.killThreshold, 1, 100, function(n) State.killThreshold = n end)
    addDivider(killPage, "── 双工具 ──")
    addRowToggle(killPage, "杀戮+锻炼 双工具切换", State.dualEnabled, function(v) State.dualEnabled = v end)
    addHint(killPage, "杀戮期间会暂停自动传送，退出后自动恢复。")

    -- ===== 设置 =====
    local setPage = newPage("SetPage")

    addDivider(setPage, "── 性能 ──")
    addRowToggle(setPage, "防卡顿（移除粒子/阴影）", State.antiLagEnabled, function(v)
        State.antiLagEnabled = v
        if v then pcall(enableAntiLag) else pcall(disableAntiLag) end
    end)
    addRowToggle(setPage, "移除纹理", State.textureRemoverEnabled, function(v)
        State.textureRemoverEnabled = v
        if v then pcall(enableTextureRemover) else pcall(disableTextureRemover) end
    end)
    addRowToggle(setPage, "隐藏 UI 界面", State.hideUIEnabled, function(v)
        State.hideUIEnabled = v
        if v then pcall(hideAllUI) else pcall(restoreHiddenUI) end
    end)

    addDivider(setPage, "── 显示 ──")
    State.ui.infoToggle = addRowToggle(setPage, "信息小悬浮窗", State.infoWindowEnabled, function(v)
        State.infoWindowEnabled = v
        if State.ui.infoGui then State.ui.infoGui.Enabled = v end
    end)
    addRowToggle(setPage, "数字格式化显示", State.formatEnabled, function(v)
        State.formatEnabled = v
    end)

    addHint(setPage, "信息悬浮窗可自由拖动，右上角 × 关闭。悬浮窗内的玩家列表点击其他玩家可查看其信息。")

    local function switchTab(id)
        trainPage.Visible = (id == "train")
        telePage.Visible = (id == "tele")
        rebPage.Visible = (id == "reb")
        killPage.Visible = (id == "kill")
        setPage.Visible = (id == "set")
        local function tint(btn, on)
            btn.BackgroundColor3 = on and Theme.Accent or Theme.SurfaceAlt
            btn.TextColor3 = on and Color3_fromRGB(255, 255, 255) or Theme.TextDim
        end
        tint(tabTrain, id == "train")
        tint(tabTele, id == "tele")
        tint(tabReb, id == "reb")
        tint(tabKill, id == "kill")
        tint(tabSet, id == "set")
    end

    track(tabTrain.MouseButton1Click:Connect(function() switchTab("train") end))
    track(tabTele.MouseButton1Click:Connect(function() switchTab("tele") end))
    track(tabReb.MouseButton1Click:Connect(function() switchTab("reb") end))
    track(tabKill.MouseButton1Click:Connect(function() switchTab("kill") end))
    track(tabSet.MouseButton1Click:Connect(function() switchTab("set") end))
    switchTab("train")

    -- 拖动
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
        dragging = true; dragStart = input.Position; dragStartPos = main.Position
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - dragStart
        main.Position = UDim2_new(dragStartPos.X.Scale, dragStartPos.X.Offset + d.X,
                                  dragStartPos.Y.Scale, dragStartPos.Y.Offset + d.Y)
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))

    local minimized = false
    track(minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tabBar.Visible = false; content.Visible = false
            main.Size = UDim2_fromOffset(WIN_W, TITLE_H)
            minBtn.Text = "+"
        else
            tabBar.Visible = true; content.Visible = true
            main.Size = UDim2_fromOffset(WIN_W, WIN_H)
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
buildInfoWindow()

-- 应用已加载的配置到 UI 与副作用
if State.ui.rateBox then
    State.ui.rateBox.TextEditable = not State.adaptiveEnabled
    State.ui.rateBox.TextColor3 = State.adaptiveEnabled and Theme.TextDim or Theme.Text
end
if State.antiLagEnabled then pcall(enableAntiLag) end
if State.textureRemoverEnabled then pcall(enableTextureRemover) end
if State.hideUIEnabled then pcall(hideAllUI) end
if State.infoWindowEnabled and State.ui.infoGui then State.ui.infoGui.Enabled = true end

track(RS_Heartbeat:Connect(onHeartbeat))

_G[SCRIPT_ID] = { version = VERSION, cleanup = destroy }
