--!nonstrict
-- 肌肉之王自动化 v17
-- 修复语法 / 渲染剔除实时生效 / 快速锻炼停止清理 / 定期清理防溢出

local SCRIPT_ID   = "__MUSCLE_KING_AUTO__"
local VERSION     = 1700
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

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local GetPlayers   = Players.GetPlayers
local RS_HB        = RunService.Heartbeat
local UIS_IC       = UserInputService.InputChanged
local UIS_IB       = UserInputService.InputBegan
local UIS_IE       = UserInputService.InputEnded
local UIS_GML      = UserInputService.GetMouseLocation
local UIS_Touch    = UserInputService.TouchEnabled
local UIS_Kb       = UserInputService.KeyboardEnabled
local UD2n         = UDim2.new
local UD2o         = UDim2.fromOffset
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
local E_TxtYT      = Enum.TextYAlignment.Top
local E_CamCustom  = Enum.CameraType.Custom

local isMobile = UIS_Touch and not UIS_Kb

local Theme = {
    Background = C3(20, 22, 28), Surface = C3(28, 31, 39),
    SurfaceAlt = C3(36, 40, 50), Border = C3(50, 56, 70),
    Accent = C3(96, 158, 255), AccentDim = C3(42, 70, 120),
    Text = C3(232, 236, 244), TextDim = C3(148, 156, 172),
    Warning = C3(255, 200, 80), Success = C3(120, 220, 160),
    Danger = C3(235, 90, 90),
}

local DEFAULT = {
    uiHeightRatio = 0.4,
    infoHeightRatio = 0.28,
    mainPos = UD2n(0.5, -175, 0.5, -220),
    infoPos = UD2n(1, -280, 1, -360),
}

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
    infoWindowEnabled = false,
    formatEnabled = true,

    petRepBonus = 0, petRepBonusCheckedAt = 0, petRepBonusDetail = {},

    uiHeightRatio = DEFAULT.uiHeightRatio,
    infoHeightRatio = DEFAULT.infoHeightRatio,

    originalGravity = Workspace.Gravity,
    muscleEventRef = nil, rebirthEventRef = nil, lastRebirthScan = 0,

    trainAccum = 0, time = 0,
    fpsWinTime = 0, fpsWinFrames = 0, avgFps = 60,
    lastDegradeAt = 0, degradeLevel = 0,

    lastAFKClick = 0, lastSaveAt = 0,
    lastSweepAt = 0,
    sessionStartStrength = nil, strengthCheckAt = 0,
    lastStrengthSnapshot = 0, strengthPerSec = 0,
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
        ApplyStrokeMode = E_StrokeMode }, p)
end

local function notify(text, duration)
    duration = duration or 3
    if State.destroyed or not State.ui.screen then return end
    local label = create("TextLabel", {
        AnchorPoint = V2n(0.5, 0), Position = UD2n(0.5, 0, 0.04, 0),
        Size = UD2o(440, 52), BackgroundColor3 = C3(30, 32, 40),
        BorderSizePixel = 0, Font = Font.GothamBold,
        Text = text, TextColor3 = Theme.Warning,
        TextSize = 15, TextWrapped = true, ZIndex = 200,
    }, State.ui.screen)
    corner(label, 10)
    stroke(label, Theme.Warning, 2)
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
        autoTeleport = State.autoTeleport, autoRebirth = State.autoRebirth, rebirthRate = State.rebirthRate,
        toolDumbbell = State.toolDumbbell, toolPushups = State.toolPushups,
        toolHandstands = State.toolHandstands, toolSitups = State.toolSitups,
        killThreshold = State.killThreshold, dualEnabled = State.dualEnabled,
        autoKingKill = State.autoKingKill, kingKillThreshold = State.kingKillThreshold,
        adaptiveEnabled = State.adaptiveEnabled, adaptiveThreshold = State.adaptiveThreshold,
        antiLagEnabled = State.antiLagEnabled,
        renderCullEnabled = State.renderCullEnabled, renderCullDist = State.renderCullDist,
        hideOwnPets = State.hideOwnPets, hideAllPets = State.hideAllPets, hideMachines = State.hideMachines,
        textureRemoverEnabled = State.textureRemoverEnabled,
        hideUIEnabled = State.hideUIEnabled,
        infoWindowEnabled = State.infoWindowEnabled,
        formatEnabled = State.formatEnabled,
        uiHeightRatio = State.uiHeightRatio,
        infoHeightRatio = State.infoHeightRatio,
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
    local function fnum(k, f, lo, hi)
        local v = tonumber(data[k]) if not v then return f end
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
    State.autoKingKill = bool("autoKingKill", State.autoKingKill)
    State.kingKillThreshold = num("kingKillThreshold", State.kingKillThreshold, 1, 1000)
    State.adaptiveEnabled = bool("adaptiveEnabled", State.adaptiveEnabled)
    State.adaptiveThreshold = num("adaptiveThreshold", State.adaptiveThreshold, 10, 120)
    State.antiLagEnabled = bool("antiLagEnabled", State.antiLagEnabled)
    State.renderCullEnabled = bool("renderCullEnabled", State.renderCullEnabled)
    State.renderCullDist = num("renderCullDist", State.renderCullDist, 100, 5000)
    State.hideOwnPets = bool("hideOwnPets", State.hideOwnPets)
    State.hideAllPets = bool("hideAllPets", State.hideAllPets)
    State.hideMachines = bool("hideMachines", State.hideMachines)
    State.textureRemoverEnabled = bool("textureRemoverEnabled", State.textureRemoverEnabled)
    State.hideUIEnabled = bool("hideUIEnabled", State.hideUIEnabled)
    State.infoWindowEnabled = bool("infoWindowEnabled", State.infoWindowEnabled)
    State.formatEnabled = bool("formatEnabled", State.formatEnabled)
    State.uiHeightRatio = fnum("uiHeightRatio", State.uiHeightRatio, 0.2, 0.9)
    State.infoHeightRatio = fnum("infoHeightRatio", State.infoHeightRatio, 0.15, 0.7)
end

-- ============================================================
-- 防卡顿
-- ============================================================
local AntiLag = {
    enabled = false, rescanAt = 0,
    particles = {}, shadows = {}, sounds = {},
    lighting = nil, postEffects = {}, atmospheres = {},
}
local POST_CLASSES = {
    BloomEffect = true, BlurEffect = true, SunRaysEffect = true,
    ColorCorrectionEffect = true, DepthOfFieldEffect = true,
}
local function scanAntiLag()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local cls = obj.ClassName
        if cls == "ParticleEmitter" or cls == "Trail" or cls == "Beam"
        or cls == "Fire" or cls == "Smoke" or cls == "Sparkles" then
            if obj.Enabled then
                obj.Enabled = false
                table.insert(AntiLag.particles, obj)
            end
        elseif cls == "BasePart" and obj.CastShadow then
            table.insert(AntiLag.shadows, { part = obj, value = true })
            obj.CastShadow = false
        end
    end
    for _, obj in ipairs(Lighting:GetChildren()) do
        if POST_CLASSES[obj.ClassName] then
            if obj.Enabled then
                obj.Enabled = false
                table.insert(AntiLag.postEffects, obj)
            end
        elseif obj.ClassName == "Atmosphere" then
            table.insert(AntiLag.atmospheres, {
                obj = obj, Density = obj.Density, Haze = obj.Haze, Glare = obj.Glare,
            })
            obj.Density = 0; obj.Haze = 0; obj.Glare = 0
        end
    end
    for _, obj in ipairs(SoundService:GetDescendants()) do
        if obj:IsA("Sound") and obj.Playing and obj.Volume > 0 then
            table.insert(AntiLag.sounds, { sound = obj, volume = obj.Volume })
            obj.Volume = 0
        end
    end
end
local function enableAntiLag()
    if AntiLag.enabled then return end
    AntiLag.enabled = true
    AntiLag.lighting = {
        GlobalShadows = Lighting.GlobalShadows,
        ShadowSoftness = Lighting.ShadowSoftness,
    }
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
    end)
    scanAntiLag()
    AntiLag.rescanAt = State.time + 2
end
local function rescanAntiLag()
    if not AntiLag.enabled then return end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
    end)
    scanAntiLag()
    AntiLag.rescanAt = State.time + 2
end
local function disableAntiLag()
    AntiLag.enabled = false
    for _, p in ipairs(AntiLag.particles) do pcall(function() p.Enabled = true end) end
    table.clear(AntiLag.particles)
    for _, item in ipairs(AntiLag.shadows) do pcall(function() item.part.CastShadow = item.value end) end
    table.clear(AntiLag.shadows)
    for _, item in ipairs(AntiLag.sounds) do pcall(function() item.sound.Volume = item.volume end) end
    table.clear(AntiLag.sounds)
    for _, fx in ipairs(AntiLag.postEffects) do pcall(function() fx.Enabled = true end) end
    table.clear(AntiLag.postEffects)
    for _, item in ipairs(AntiLag.atmospheres) do
        pcall(function()
            item.obj.Density = item.Density
            item.obj.Haze = item.Haze
            item.obj.Glare = item.Glare
        end)
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

-- ============================================================
-- 渲染剔除（距离改动会立即生效）
-- ============================================================
local RenderCull = { hidden = {}, rescanAt = 0 }
local function cullModel(model)
    local saved = {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            saved[p] = { ltm = p.LocalTransparencyModifier, tr = p.Transparency }
            pcall(function()
                p.LocalTransparencyModifier = 1
                p.Transparency = 1
            end)
        end
    end
    RenderCull.hidden[model] = saved
end
local function uncullModel(model)
    local saved = RenderCull.hidden[model]
    if not saved then return end
    for p, v in pairs(saved) do
        if p.Parent then
            pcall(function()
                p.LocalTransparencyModifier = v.ltm
                p.Transparency = v.tr
            end)
        end
    end
    RenderCull.hidden[model] = nil
end
local function scanRenderCull()
    local hrp = Cache.hrp
    if not hrp then return end
    local pos = hrp.Position
    local threshSq = (State.renderCullDist or 500) ^ 2
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= Cache.char and not Players:GetPlayerFromCharacter(obj) then
            local prim = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if prim then
                local d = prim.Position - pos
                local dsq = d.X*d.X + d.Y*d.Y + d.Z*d.Z
                if dsq > threshSq then
                    if not RenderCull.hidden[obj] then cullModel(obj) end
                else
                    if RenderCull.hidden[obj] then uncullModel(obj) end
                end
            end
        end
    end
    for model in pairs(RenderCull.hidden) do
        if not model.Parent then RenderCull.hidden[model] = nil end
    end
    RenderCull.rescanAt = State.time + 1
end
local function disableRenderCull()
    for model in pairs(RenderCull.hidden) do uncullModel(model) end
    table.clear(RenderCull.hidden)
end
local function forceRescanRenderCull()
    pcall(disableRenderCull)
    RenderCull.rescanAt = 0
end

-- ============================================================
-- 隐藏宠物/器械
-- ============================================================
local PetHider = { own = {}, all = {}, machines = {}, rescanAt = 0 }
local function hideModelParts(model)
    if not model or not model.Parent then return end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.LocalTransparencyModifier = 1
                p.Transparency = 1
            end)
        end
    end
end
local function showModelParts(model)
    if not model or not model.Parent then return end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.LocalTransparencyModifier = 0
                p.Transparency = 0
            end)
        end
    end
end
local function scanHidePets()
    if State.hideOwnPets then
        local own = Workspace:FindFirstChild(LocalPlayer.Name)
        if own then
            for _, pet in ipairs(own:GetChildren()) do
                if pet:IsA("Model") or pet:IsA("Folder") then
                    table.insert(PetHider.own, pet)
                    hideModelParts(pet)
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
                            table.insert(PetHider.all, pet)
                            hideModelParts(pet)
                        end
                    end
                end
            end
        end
    end
    PetHider.rescanAt = State.time + 2
end
local function restoreHiddenPets()
    for _, m in ipairs(PetHider.own) do showModelParts(m) end
    table.clear(PetHider.own)
    for _, m in ipairs(PetHider.all) do showModelParts(m) end
    table.clear(PetHider.all)
end
local function scanHideMachines()
    if not State.hideMachines then return end
    local mf = Workspace:FindFirstChild("machinesFolder")
    if mf then
        for _, m in ipairs(mf:GetChildren()) do
            if m:IsA("Model") then
                table.insert(PetHider.machines, m)
                hideModelParts(m)
            end
        end
    end
    PetHider.rescanAt = State.time + 2
end
local function restoreHiddenMachines()
    for _, m in ipairs(PetHider.machines) do showModelParts(m) end
    table.clear(PetHider.machines)
end

-- ============================================================
-- 纹理移除
-- ============================================================
local TextureRemover = { enabled = false, rescanAt = 0, saved = {}, seen = {} }
local function scanTextures()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local cls = obj.ClassName
        if cls == "Decal" or cls == "Texture" then
            if not TextureRemover.seen[obj] and obj.Texture ~= "" then
                TextureRemover.seen[obj] = true
                table.insert(TextureRemover.saved, { obj = obj, prop = "Texture", value = obj.Texture })
                obj.Texture = ""
            end
        elseif cls == "MeshPart" or cls == "SpecialMesh" then
            local p = (cls == "MeshPart") and "TextureID" or "TextureId"
            if not TextureRemover.seen[obj] and obj[p] and obj[p] ~= "" then
                TextureRemover.seen[obj] = true
                table.insert(TextureRemover.saved, { obj = obj, prop = p, value = obj[p] })
                obj[p] = ""
            end
        elseif cls == "SurfaceAppearance" then
            if not TextureRemover.seen[obj] and obj.ColorMap ~= "" then
                TextureRemover.seen[obj] = true
                table.insert(TextureRemover.saved, { obj = obj, prop = "ColorMap", value = obj.ColorMap })
                obj.ColorMap = ""
            end
        end
    end
end
local function enableTextureRemover()
    if TextureRemover.enabled then return end
    TextureRemover.enabled = true
    table.clear(TextureRemover.saved)
    table.clear(TextureRemover.seen)
    scanTextures()
    TextureRemover.rescanAt = State.time + 4
end
local function rescanTextureRemover()
    if not TextureRemover.enabled then return end
    scanTextures()
    TextureRemover.rescanAt = State.time + 4
end
local function disableTextureRemover()
    TextureRemover.enabled = false
    for _, item in ipairs(TextureRemover.saved) do
        pcall(function() item.obj[item.prop] = item.value end)
    end
    table.clear(TextureRemover.saved)
    table.clear(TextureRemover.seen)
end

local HiddenUIs = {}
local function hideAllUI()
    table.clear(HiddenUIs)
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui ~= State.ui.screen and gui ~= State.ui.infoGui then
            if gui.Enabled then
                gui.Enabled = false
                table.insert(HiddenUIs, gui)
            end
        end
    end
end
local function restoreHiddenUI()
    for _, gui in ipairs(HiddenUIs) do pcall(function() gui.Enabled = true end) end
    table.clear(HiddenUIs)
end

-- ============================================================
-- 定期清理溢出（不干扰正在运行的功能）
-- ============================================================
local function sweepOverflow()
    -- AntiLag.particles
    for i = #AntiLag.particles, 1, -1 do
        local p = AntiLag.particles[i]
        if not p or not p.Parent then table.remove(AntiLag.particles, i) end
    end
    -- AntiLag.shadows
    for i = #AntiLag.shadows, 1, -1 do
        local it = AntiLag.shadows[i]
        if not it.part or not it.part.Parent then table.remove(AntiLag.shadows, i) end
    end
    -- AntiLag.sounds
    for i = #AntiLag.sounds, 1, -1 do
        local it = AntiLag.sounds[i]
        if not it.sound or not it.sound.Parent then table.remove(AntiLag.sounds, i) end
    end
    -- AntiLag.postEffects
    for i = #AntiLag.postEffects, 1, -1 do
        local fx = AntiLag.postEffects[i]
        if not fx or not fx.Parent then table.remove(AntiLag.postEffects, i) end
    end
    -- AntiLag.atmospheres
    for i = #AntiLag.atmospheres, 1, -1 do
        local it = AntiLag.atmospheres[i]
        if not it.obj or not it.obj.Parent then table.remove(AntiLag.atmospheres, i) end
    end
    -- RenderCull.hidden
    for model in pairs(RenderCull.hidden) do
        if not model.Parent then RenderCull.hidden[model] = nil end
    end
    -- TextureRemover.saved
    for i = #TextureRemover.saved, 1, -1 do
        local it = TextureRemover.saved[i]
        if not it.obj or not it.obj.Parent then table.remove(TextureRemover.saved, i) end
    end
    -- TextureRemover.seen
    for obj in pairs(TextureRemover.seen) do
        if not obj.Parent then TextureRemover.seen[obj] = nil end
    end
    -- PetHider
    for i = #PetHider.own, 1, -1 do
        if not PetHider.own[i].Parent then table.remove(PetHider.own, i) end
    end
    for i = #PetHider.all, 1, -1 do
        if not PetHider.all[i].Parent then table.remove(PetHider.all, i) end
    end
    for i = #PetHider.machines, 1, -1 do
        if not PetHider.machines[i].Parent then table.remove(PetHider.machines, i) end
    end
    -- HiddenUIs
    for i = #HiddenUIs, 1, -1 do
        if not HiddenUIs[i].Parent then table.remove(HiddenUIs, i) end
    end
end

-- ============================================================
-- 训练停止时的清理
-- ============================================================
local function cleanupTrainingState()
    State.trainAccum = 0
    State.degradeLevel = 0
    State.fpsWinTime = 0
    State.fpsWinFrames = 0
    State.adaptiveStableCount = 0
    State.adaptiveStep = 100
end

local function destroy()
    if State.destroyed then return end
    pcall(saveConfig)
    State.destroyed = true
    for _, c in ipairs(State.conns) do pcall(function() c:Disconnect() end) end
    table.clear(State.conns)
    pcall(function() Workspace.Gravity = State.originalGravity end)
    pcall(disableAntiLag)
    pcall(disableRenderCull)
    pcall(restoreHiddenPets)
    pcall(restoreHiddenMachines)
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
    local vp = cam and cam.ViewportSize or V2n(1920, 1080)
    local tx, ty = vp.X - 8, vp.Y - 8
    local ox, oy, hasOrig = 0, 0, false
    local ok0, mloc = pcall(UIS_GML, UserInputService)
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

local function fixCamera()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local hum = Cache.hum
    if hum and hum.Parent then
        pcall(function()
            if cam.CameraSubject ~= hum then cam.CameraSubject = hum end
            if cam.CameraType ~= E_CamCustom then cam.CameraType = E_CamCustom end
        end)
    end
end

-- ============================================================
-- 工具
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
local function isEquipped(list)
    local char = Cache.char
    if not char then return false end
    for _, c in ipairs(char:GetChildren()) do
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
    local bp = LocalPlayer:FindFirstChild("Backpack")
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
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false end
    for _, c in ipairs(bp:GetChildren()) do
        if c:IsA("Tool") and matchKeyword(c.Name, list) then
            pcall(function() hum:EquipTool(c) end)
            return true
        end
    end
    return false
end
local function toolExists(list) return isEquipped(list) or (LocalPlayer:FindFirstChild("Backpack") and findAnyTool(list) ~= nil) end
local function suicide()
    local hum = Cache.hum
    if hum and hum.Health > 0 then hum.Health = 0
    elseif Cache.char then pcall(function() Cache.char:BreakJoints() end) end
end

-- ============================================================
-- 数值
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

-- ============================================================
-- 宠物反复速度
-- ============================================================
local REP_KEYWORDS = { "rep", "反复", "反击", "reptime", "repspeed", "reptimeboost" }
local function isRepKeyword(name)
    local n = name:lower()
    for i = 1, #REP_KEYWORDS do
        if n:find(REP_KEYWORDS[i]) then return true end
    end
    return false
end
local function readRepBonusFromPerks(perks)
    if not perks then return 0 end
    local total = 0
    for _, p in ipairs(perks:GetChildren()) do
        if p:IsA("ValueBase") and isRepKeyword(p.Name) then
            total = total + (tonumber(p.Value) or 0)
        end
    end
    return total
end
local function getEquippedPetRepSpeedBonus()
    local total = 0
    local detail = {}
    local ownFolder = Workspace:FindFirstChild(LocalPlayer.Name)
    if ownFolder then
        local seenSlots = {}
        for _, pet in ipairs(ownFolder:GetChildren()) do
            local slot = pet:GetAttribute("equippedSlot")
            local key
            if slot and slot ~= "" then key = "slot:" .. slot
            else key = "obj:" .. tostring(pet) end
            if not seenSlots[key] then
                seenSlots[key] = true
                local perks = pet:FindFirstChild("perksFolder")
                local v = readRepBonusFromPerks(perks)
                if v > 0 then
                    total = total + v
                    table.insert(detail, (slot or pet.Name) .. "=" .. tostring(v))
                end
            end
        end
        if total > 0 then return total, detail end
    end
    local equipped = LocalPlayer:FindFirstChild("equippedPets")
    if not equipped then return 0, {} end
    local shared = ReplicatedStorage:FindFirstChild("shared")
    local runtime = shared and shared:FindFirstChild("runtime")
    local previews = runtime and runtime:FindFirstChild("petPreviews")
    if not previews then return 0, {} end
    local seen = {}
    for _, slot in ipairs(equipped:GetChildren()) do
        local petName = slot.Value
        if type(petName) == "string" and petName ~= "" then
            local petModel = previews:FindFirstChild(petName)
            if petModel and not seen[petModel] then
                seen[petModel] = true
                local perks = petModel:FindFirstChild("perksFolder")
                local v = readRepBonusFromPerks(perks)
                if v > 0 then
                    total = total + v
                    table.insert(detail, petName .. "=" .. tostring(v))
                end
            end
        end
    end
    return total, detail
end
local function refreshPetBonus()
    local total, detail = getEquippedPetRepSpeedBonus()
    State.petRepBonus = total
    State.petRepBonusDetail = detail
end

-- ============================================================
-- 事件
-- ============================================================
local function getMuscleEvent()
    local cached = State.muscleEventRef
    if cached and cached.Parent == LocalPlayer then return cached end
    local ev = LocalPlayer:FindFirstChild("muscleEvent")
    State.muscleEventRef = ev
    return ev
end
local function getRebirthEvent()
    local cached = State.rebirthEventRef
    if cached and cached.Parent then return cached end
    if State.time - State.lastRebirthScan < 3 then return nil end
    State.lastRebirthScan = State.time
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    if rEvents then
        local ev = rEvents:FindFirstChild("rebirthRemote")
        if ev and (ev:IsA("RemoteEvent") or ev:IsA("RemoteFunction")) then
            State.rebirthEventRef = ev
            return ev
        end
    end
    return nil
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
-- 肌肉之王检测
-- ============================================================
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

-- ============================================================
-- 传送
-- ============================================================
local PortalCache, PortalCacheAt = nil, 0
local function findPortalNow()
    local p = Workspace:FindFirstChild("beachToMuscleKing", true)
    if p and p:IsA("BasePart") then return p end
    return nil
end
local function getPortal()
    if PortalCache and PortalCache.Parent and State.time - PortalCacheAt < 5 then
        return PortalCache
    end
    PortalCache = findPortalNow()
    PortalCacheAt = State.time
    return PortalCache
end
local function getTargetCF()
    local portal = getPortal()
    if portal then return CN(portal.Position + V3n(0, 3, 0)) end
    return CN(V3n(-8727.1, 406.7, -5796.4))
end
local function doTeleport(force)
    if force then PortalCache = nil; PortalCacheAt = 0 end
    local hrp = Cache.hrp
    if not hrp then return false end
    local cf = getTargetCF()
    if not cf then return false end
    return pcall(function()
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity = V3n(0, 0, 0)
        hrp.AssemblyAngularVelocity = V3n(0, 0, 0)
    end)
end

-- ============================================================
-- 杀戮工具函数
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
local function applyKillMovement(targetHRP)
    local hrp = Cache.hrp
    if not hrp then return end
    local delta = targetHRP.Position - hrp.Position
    local distSq = delta.X*delta.X + delta.Y*delta.Y + delta.Z*delta.Z
    if distSq > 9 then
        local dist = math.sqrt(distSq)
        local newPos = targetHRP.Position - delta / dist * 2.5
        local newCF = CN(newPos, targetHRP.Position)
        pcall(function()
            hrp.CFrame = newCF
            hrp.AssemblyLinearVelocity = V3n(0, 0, 0)
            hrp.AssemblyAngularVelocity = V3n(0, 0, 0)
        end)
    end
end
local function activatePunch()
    local char = Cache.char
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

-- ============================================================
-- 全图杀戮
-- ============================================================
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
-- 肌肉之王竞争
-- ============================================================
local function runKingKillTick(dt)
    if State.time - State.lastKingCheck >= 0.5 then
        State.lastKingCheck = State.time
        local king = getMuscleKing()
        if not king or king == LocalPlayer then
            State.kingKillTarget = nil
            State.kingKillActive = false
            return
        end
        local hrp = getCharacterHRP(king)
        if not hrp then
            State.kingKillTarget = nil
            State.kingKillActive = false
            return
        end
        local myStrength = getMyStrength()
        local targetDur = getPlayerDurability(king)
        local threshold = State.kingKillThreshold or 20
        if targetDur and myStrength > 0 and targetDur >= myStrength * threshold then
            State.kingKillTarget = nil
            State.kingKillActive = false
            return
        end
        State.kingKillTarget = king
    end
    local target = State.kingKillTarget
    if not target then
        State.kingKillActive = false
        return
    end
    local targetHRP = getCharacterHRP(target)
    if not targetHRP then
        State.kingKillTarget = nil
        State.kingKillActive = false
        return
    end
    State.kingKillActive = true
    applyKillMovement(targetHRP)
    if State.time - State.kingKillLastAttack >= 0.05 then
        State.kingKillLastAttack = State.time
        if not isEquipped(TOOL_KEYWORDS.punch) then
            tryEquip(TOOL_KEYWORDS.punch)
        end
        activatePunch()
    end
end

-- ============================================================
-- 双工具
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
-- 自适应
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
                State.fastRate = math.min(50000, State.fastRate + State.adaptiveStep)
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
        cleanupTrainingState()
        notify("孩子，你的设备这么差就别玩游戏了", 6)
    end
end

-- ============================================================
-- UI 缩放
-- ============================================================
local function updateUIScale()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if State.ui.mainScale then
        local scale = (vp.Y * (State.uiHeightRatio or 0.4)) / 440
        scale = math.clamp(scale, 0.5, 3)
        if isMobile then scale = scale * 1.15 end
        State.ui.mainScale.Scale = scale
    end
    if State.ui.infoScale then
        local scale = (vp.Y * (State.infoHeightRatio or 0.28)) / 340
        scale = math.clamp(scale, 0.5, 3)
        if isMobile then scale = scale * 1.15 end
        State.ui.infoScale.Scale = scale
    end
end

-- ============================================================
-- 信息悬浮窗
-- ============================================================
local Info = {
    viewingPlayer = nil, listOpen = false, lastRefresh = 0,
    minimized = false, rows = {}, frames = {},
}
local function buildInfoWindow()
    local screen = create("ScreenGui", {
        Name = "MuscleKingInfoUI", ResetOnSpawn = false,
        ZIndexBehavior = E_ZIdx, DisplayOrder = 99998,
    }, PlayerGui)
    State.ui.infoGui = screen
    screen.Enabled = false

    local uiScale = create("UIScale", { Scale = 1 }, screen)
    State.ui.infoScale = uiScale

    local frame = create("Frame", {
        Name = "InfoFrame", AnchorPoint = V2n(0, 0),
        Position = DEFAULT.infoPos, Size = UD2o(260, 340),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0, ClipsDescendants = true, Active = true,
    }, screen)
    Info.frames.frame = frame
    corner(frame, 12)
    stroke(frame, Theme.Border, 1)

    local titleBar = create("Frame", {
        Size = UD2n(1, 0, 0, 32), BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0, Active = true,
    }, frame)
    corner(titleBar, 12)
    create("TextLabel", {
        BackgroundTransparency = 1, Position = UD2o(12, 0),
        Size = UD2n(1, -90, 1, 0),
        Font = Font.GothamBold, Text = "实时信息",
        TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = E_TxtXL,
    }, titleBar)

    local minBtn = create("TextButton", {
        Size = UD2o(24, 24), Position = UD2n(1, -54, 0, 4),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "—",
        TextColor3 = Theme.TextDim, TextSize = 14,
    }, titleBar)
    corner(minBtn, 6)
    local closeBtn = create("TextButton", {
        Size = UD2o(24, 24), Position = UD2n(1, -28, 0, 4),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "×",
        TextColor3 = Theme.TextDim, TextSize = 16,
    }, titleBar)
    corner(closeBtn, 6)

    local playerBtn = create("TextButton", {
        Position = UD2o(10, 40), Size = UD2n(1, -20, 0, 30),
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        Font = Font.GothamMedium, Text = "查看：自己 ▼",
        TextColor3 = Theme.Text, TextSize = 13,
    }, frame)
    corner(playerBtn, 8)
    stroke(playerBtn, Theme.Border, 1)
    Info.frames.playerBtn = playerBtn

    local listFrame = create("ScrollingFrame", {
        Position = UD2o(10, 72), Size = UD2n(1, -20, 0, 150),
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UD2n(0, 0, 0, 0), AutomaticCanvasSize = E_AS_Y,
        ScrollingDirection = E_ScrollY, Visible = false, ZIndex = 5,
    }, frame)
    corner(listFrame, 8)
    stroke(listFrame, Theme.Border, 1)
    create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = E_SortL }, listFrame)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
    }, listFrame)
    Info.frames.listFrame = listFrame

    local dataFrame = create("Frame", {
        Position = UD2o(0, 108), Size = UD2n(1, 0, 1, -108),
        BackgroundTransparency = 1,
    }, frame)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    }, dataFrame)
    create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = E_SortL }, dataFrame)
    Info.frames.dataFrame = dataFrame

    local function createRow(label, order)
        local row = create("Frame", {
            Size = UD2n(1, 0, 0, 22), BackgroundTransparency = 1,
            LayoutOrder = order,
        }, dataFrame)
        create("TextLabel", {
            BackgroundTransparency = 1, Size = UD2n(0.5, 0, 1, 0),
            Font = Font.GothamMedium, Text = label,
            TextColor3 = Theme.TextDim, TextSize = 12, TextXAlignment = E_TxtXL,
        }, row)
        local val = create("TextLabel", {
            BackgroundTransparency = 1, Position = UD2n(0.5, 0, 0, 0),
            Size = UD2n(0.5, 0, 1, 0),
            Font = Font.GothamBold, Text = "-",
            TextColor3 = Theme.Text, TextSize = 12, TextXAlignment = E_TxtXR,
        }, row)
        return val
    end
    Info.rows.strength   = createRow("力量", 1)
    Info.rows.strengthDelta = createRow("力量增量", 2)
    Info.rows.gems       = createRow("宝石", 3)
    Info.rows.durability = createRow("耐力", 4)
    Info.rows.agility    = createRow("敏捷", 5)
    Info.rows.rebirths   = createRow("重生", 6)
    Info.rows.repSpeed   = createRow("反复速度", 7)
    Info.rows.perHour    = createRow("每小时预计", 8)
    Info.rows.perDay     = createRow("每天预计", 9)

    local dragging, dragStart, startPos = false, nil, nil
    track(titleBar.InputBegan:Connect(function(input)
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
        if input.UserInputType == E_UI_MB1 or input.UserInputType == E_UI_Touch then
            dragging = false
        end
    end))

    track(minBtn.MouseButton1Click:Connect(function()
        Info.minimized = not Info.minimized
        if Info.minimized then
            playerBtn.Visible = false
            listFrame.Visible = false
            dataFrame.Visible = false
            frame.Size = UD2o(260, 32)
            minBtn.Text = "+"
        else
            playerBtn.Visible = true
            dataFrame.Visible = true
            frame.Size = UD2o(260, 340)
            minBtn.Text = "—"
        end
    end))

    track(closeBtn.MouseButton1Click:Connect(function()
        State.infoWindowEnabled = false
        screen.Enabled = false
        Info.listOpen = false
        listFrame.Visible = false
        if State.ui.infoToggle then State.ui.infoToggle.set(false) end
    end))

    track(playerBtn.MouseButton1Click:Connect(function()
        Info.listOpen = not Info.listOpen
        listFrame.Visible = Info.listOpen
        if Info.listOpen then
            for _, c in ipairs(listFrame:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            local ord = 0
            local function addRow(plr)
                ord = ord + 1
                local nm = plr == LocalPlayer and (plr.Name .. " (自己)") or plr.Name
                local btn = create("TextButton", {
                    Size = UD2n(1, 0, 0, 24),
                    BackgroundColor3 = Theme.SurfaceAlt,
                    BorderSizePixel = 0, Font = Font.GothamMedium,
                    Text = nm, TextColor3 = Theme.Text,
                    TextSize = 12, LayoutOrder = ord,
                }, listFrame)
                corner(btn, 6)
                track(btn.MouseButton1Click:Connect(function()
                    Info.viewingPlayer = plr
                    playerBtn.Text = "查看：" .. (plr == LocalPlayer and "自己" or plr.Name) .. " ▼"
                    Info.listOpen = false
                    listFrame.Visible = false
                    Info.lastRefresh = 0
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
        local inList = ip.X >= lp.X and ip.X <= lp.X + ls.X and ip.Y >= lp.Y and ip.Y <= lp.Y + ls.Y
        local inBtn = ip.X >= pb.X and ip.X <= pb.X + ps.X and ip.Y >= pb.Y and ip.Y <= pb.Y + ps.Y
        if not inList and not inBtn then
            Info.listOpen = false
            listFrame.Visible = false
        end
    end))

    Info.viewingPlayer = LocalPlayer
end

local function refreshInfoWindow()
    if not Info.frames.frame or not State.ui.infoGui then return end
    if not State.ui.infoGui.Enabled then return end
    if Info.minimized then return end
    local plr = Info.viewingPlayer
    if not plr or not plr.Parent then
        Info.viewingPlayer = LocalPlayer
        plr = LocalPlayer
        if Info.frames.playerBtn then Info.frames.playerBtn.Text = "查看：自己 ▼" end
    end
    local strength   = getStatValue(plr, "Strength")
    local gems       = getStatValue(plr, "Gems")
    local durability = getStatValue(plr, "Durability")
    local agility    = getStatValue(plr, "Agility")
    local rebirths   = getStatValue(plr, "Rebirths")
    Info.rows.strength.Text   = formatNumber(strength)
    Info.rows.gems.Text       = formatNumber(gems)
    Info.rows.durability.Text = formatNumber(durability)
    Info.rows.agility.Text    = formatNumber(agility)
    Info.rows.rebirths.Text   = formatNumber(rebirths)
    if plr == LocalPlayer then
        if State.sessionStartStrength then
            local delta = strength - State.sessionStartStrength
            local sign = delta >= 0 and "+" or ""
            Info.rows.strengthDelta.Text = sign .. formatNumber(delta)
            Info.rows.strengthDelta.TextColor3 = delta >= 0 and Theme.Success or Theme.Danger
        end
        Info.rows.repSpeed.Text   = State.petRepBonus .. "%"
        Info.rows.repSpeed.TextColor3 = State.petRepBonus < 100 and Theme.Warning or Theme.Success
        Info.rows.perHour.Text = formatNumber(State.strengthPerSec * 3600)
        Info.rows.perDay.Text  = formatNumber(State.strengthPerSec * 86400)
    else
        Info.rows.strengthDelta.Text = "-"
        Info.rows.repSpeed.Text = "-"
        Info.rows.perHour.Text = "-"
        Info.rows.perDay.Text = "-"
    end
end

-- ============================================================
-- 复位按钮
-- ============================================================
local ResetBtnState = { pressAt = 0, holding = false, lastStep = 0 }
local function doResetAll()
    State.uiHeightRatio = DEFAULT.uiHeightRatio
    State.infoHeightRatio = DEFAULT.infoHeightRatio
    if State.ui.main then State.ui.main.Position = DEFAULT.mainPos end
    if Info.frames.frame then
        Info.frames.frame.Position = DEFAULT.infoPos
        Info.minimized = false
        Info.frames.frame.Size = UD2o(260, 340)
        if Info.frames.playerBtn then Info.frames.playerBtn.Visible = true end
        if Info.frames.dataFrame then Info.frames.dataFrame.Visible = true end
    end
    updateUIScale()
    pcall(saveConfig)
    notify("已复位所有位置和大小", 3)
end
local function buildResetButton()
    local screen = State.ui.screen
    if not screen then return end
    local btn = create("TextButton", {
        Name = "ResetBtn", AnchorPoint = V2n(0, 1),
        Position = UD2n(0, 20, 1, -20), Size = UD2o(56, 56),
        BackgroundColor3 = Theme.Surface, BackgroundTransparency = 0.25,
        BorderSizePixel = 0, Text = "复位",
        Font = Font.GothamBold, TextColor3 = Theme.TextDim, TextSize = 12,
        ZIndex = 150,
    }, screen)
    corner(btn, 28)
    stroke(btn, Theme.Border, 1)
    State.ui.resetBtn = btn
    track(btn.InputBegan:Connect(function(input)
        if input.UserInputType ~= E_UI_MB1 and input.UserInputType ~= E_UI_Touch then return end
        ResetBtnState.pressAt = tick()
        ResetBtnState.holding = true
        ResetBtnState.lastStep = 0
    end))
    track(btn.InputEnded:Connect(function(input)
        if input.UserInputType == E_UI_MB1 or input.UserInputType == E_UI_Touch then
            ResetBtnState.holding = false
            ResetBtnState.pressAt = 0
            btn.BackgroundColor3 = Theme.Surface
            btn.TextColor3 = Theme.TextDim
            btn.Text = "复位"
        end
    end))
end
local function tickResetButton()
    if not ResetBtnState.holding then return end
    local btn = State.ui.resetBtn
    if not btn then return end
    local elapsed = tick() - ResetBtnState.pressAt
    local step = math.floor(elapsed)
    if step ~= ResetBtnState.lastStep and step <= 3 then
        ResetBtnState.lastStep = step
        btn.Text = tostring(3 - step) .. "s"
        if step == 1 then
            btn.BackgroundColor3 = Theme.Warning
            btn.TextColor3 = C3(20, 20, 20)
        elseif step == 2 then
            btn.BackgroundColor3 = C3(255, 150, 60)
            btn.TextColor3 = C3(20, 20, 20)
        end
    end
    if elapsed >= 3 then
        ResetBtnState.holding = false
        ResetBtnState.pressAt = 0
        btn.BackgroundColor3 = Theme.Success
        btn.Text = "✓"
        btn.TextColor3 = C3(20, 20, 20)
        doResetAll()
        task.delay(1, function()
            if btn and btn.Parent then
                btn.BackgroundColor3 = Theme.Surface
                btn.TextColor3 = Theme.TextDim
                btn.Text = "复位"
            end
        end)
    end
end

-- ============================================================
-- 任务链
-- ============================================================
local TaskPriority = {
    AFK = 200, KING_KILL = 160, KILL = 150, DUAL = 140, REBIRTH = 120,
    TELEPORT = 100, CAMERA = 90, INFO = 85, TOOL = 80, TRAIN = 60,
    RESET = 55, ANTILAG = 40, CULL = 35, HIDER = 30, TEX = 25,
    SWEEP = 20, SAVE = 10,
}

local TaskChain = {}
local function registerTask(task)
    table.insert(TaskChain, task)
    table.sort(TaskChain, function(a, b) return a.priority > b.priority end)
end

registerTask({ id = "afk", priority = TaskPriority.AFK,
    enabled = function() return true end,
    tick = function()
        if State.time - State.lastAFKClick >= 60 then
            State.lastAFKClick = State.time
            performAFKClick()
        end
    end,
})

registerTask({ id = "kingKill", priority = TaskPriority.KING_KILL,
    enabled = function() return State.autoKingKill end,
    onDisable = function()
        State.kingKillTarget = nil
        State.kingKillActive = false
    end,
    tick = runKingKillTick,
})

registerTask({ id = "kill", priority = TaskPriority.KILL,
    enabled = function() return State.killEnabled and not State.kingKillActive end,
    onEnable = function()
        State.killSavedState = { autoTeleport = State.autoTeleport }
        State.autoTeleport = false
        if State.ui.teleToggle then State.ui.teleToggle.set(false) end
        State.killTarget = nil
        State.killScanAt = 0
        State.dualCurrentMode = "punch"
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
        State.dualCurrentMode = "punch"
    end,
    tick = runKillTick,
})

registerTask({ id = "dual", priority = TaskPriority.DUAL,
    enabled = function()
        return State.dualEnabled and State.killEnabled
            and State.killTarget ~= nil and (State.autoTrain or State.fastTrain)
            and not State.kingKillActive
    end,
    onDisable = function() State.dualCurrentMode = "punch" end,
    tick = function() updateDualTool() end,
})

registerTask({ id = "rebirth", priority = TaskPriority.REBIRTH,
    enabled = function() return State.autoRebirth end,
    tick = function()
        local interval = 1 / math.max(1, State.rebirthRate)
        if State.time - State.lastRebirthAt >= interval then
            State.lastRebirthAt = State.time
            fireRebirth()
        end
    end,
})

registerTask({ id = "teleport", priority = TaskPriority.TELEPORT,
    enabled = function()
        return State.autoTeleport and not State.killEnabled and not State.kingKillActive
    end,
    tick = function()
        if State.time - State.lastTeleportAt >= 0.05 then
            State.lastTeleportAt = State.time
            doTeleport()
        end
    end,
})

registerTask({ id = "camera", priority = TaskPriority.CAMERA,
    enabled = function() return State.killEnabled or State.autoTeleport or State.kingKillActive end,
    tick = function()
        if State.time - State.lastCameraFix >= 0.5 then
            State.lastCameraFix = State.time
            fixCamera()
        end
    end,
})

registerTask({ id = "info", priority = TaskPriority.INFO,
    enabled = function() return State.infoWindowEnabled end,
    tick = function()
        if State.time - State.strengthCheckAt >= 1 then
            State.strengthCheckAt = State.time
            local s = getMyStrength()
            if State.sessionStartStrength == nil then
                State.sessionStartStrength = s
                State.lastStrengthSnapshot = s
            else
                local d = s - State.lastStrengthSnapshot
                if d >= 0 then
                    State.strengthPerSec = State.strengthPerSec * 0.7 + d * 0.3
                end
                State.lastStrengthSnapshot = s
            end
        end
        if State.time - Info.lastRefresh >= 0.5 then
            Info.lastRefresh = State.time
            refreshInfoWindow()
        end
    end,
})

registerTask({ id = "tool", priority = TaskPriority.TOOL,
    enabled = function()
        local isTraining = State.autoTrain or State.fastTrain
        return isTraining and not State.toolCooldown and not State.toolOwnedByKill
            and not State.kingKillActive
    end,
    tick = function()
        if State.time - State.lastToolCheck < 0.1 then return end
        State.lastToolCheck = State.time
        local selected = {}
        if State.toolPushups then table.insert(selected, TOOL_KEYWORDS.pushups) end
        if State.toolHandstands then table.insert(selected, TOOL_KEYWORDS.handstands) end
        if State.toolSitups then table.insert(selected, TOOL_KEYWORDS.situps) end
        local ok1 = false
        for _, kw in ipairs(selected) do
            if tryEquip(kw) then ok1 = true break end
        end
        local ok2 = false
        if not ok1 and State.toolDumbbell then
            ok2 = tryEquip(TOOL_KEYWORDS.dumbbell)
        end
        if not ok1 and not ok2 then
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

registerTask({ id = "train", priority = TaskPriority.TRAIN,
    enabled = function()
        return (State.autoTrain or State.fastTrain) and not State.kingKillActive
    end,
    tick = function(dt)
        local rate = 0
        if State.fastTrain then rate = State.fastRate
        elseif State.autoTrain then rate = 10 end
        if rate <= 0 then return end
        State.trainAccum = State.trainAccum + rate * dt
        local count = math.floor(State.trainAccum)
        if count > 0 then
            State.trainAccum = State.trainAccum - count
            if count > 3000 then count = 3000 end
            local ev = getMuscleEvent()
            if ev then
                pcall(function()
                    for _ = 1, count do
                        ev:FireServer("rep")
                    end
                end)
            end
        end
    end,
})

registerTask({ id = "reset", priority = TaskPriority.RESET,
    enabled = function() return ResetBtnState.holding end,
    tick = function() tickResetButton() end,
})

registerTask({ id = "antilag", priority = TaskPriority.ANTILAG,
    enabled = function() return State.antiLagEnabled end,
    onEnable = function() pcall(enableAntiLag) end,
    onDisable = function() pcall(disableAntiLag) end,
    tick = function()
        if AntiLag.enabled and State.time >= AntiLag.rescanAt then rescanAntiLag() end
    end,
})

registerTask({ id = "cull", priority = TaskPriority.CULL,
    enabled = function() return State.renderCullEnabled end,
    onEnable = function() RenderCull.rescanAt = 0 end,
    onDisable = function() pcall(disableRenderCull) end,
    tick = function()
        if State.time >= RenderCull.rescanAt then scanRenderCull() end
    end,
})

registerTask({ id = "hider", priority = TaskPriority.HIDER,
    enabled = function()
        return State.hideOwnPets or State.hideAllPets or State.hideMachines
    end,
    onEnable = function() PetHider.rescanAt = 0 end,
    onDisable = function()
        pcall(restoreHiddenPets)
        pcall(restoreHiddenMachines)
    end,
    tick = function()
        if State.time >= PetHider.rescanAt then
            pcall(restoreHiddenPets)
            pcall(restoreHiddenMachines)
            scanHidePets()
            scanHideMachines()
        end
    end,
})

registerTask({ id = "tex", priority = TaskPriority.TEX,
    enabled = function() return State.textureRemoverEnabled end,
    onEnable = function() pcall(enableTextureRemover) end,
    onDisable = function() pcall(disableTextureRemover) end,
    tick = function()
        if TextureRemover.enabled and State.time >= TextureRemover.rescanAt then
            rescanTextureRemover()
        end
    end,
})

registerTask({ id = "sweep", priority = TaskPriority.SWEEP,
    enabled = function() return true end,
    tick = function()
        if State.time - State.lastSweepAt >= 30 then
            State.lastSweepAt = State.time
            pcall(sweepOverflow)
        end
    end,
})

registerTask({ id = "save", priority = TaskPriority.SAVE,
    enabled = function() return true end,
    tick = function()
        if State.time - State.lastSaveAt >= 2 then
            State.lastSaveAt = State.time
            task.spawn(saveConfig)
        end
    end,
})

-- ============================================================
-- 全局更新
-- ============================================================
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
        State.fpsWinTime = 0
        State.fpsWinFrames = 0
        if State.fastTrain then
            if State.adaptiveEnabled then runAdaptive()
            elseif State.avgFps < 5 then handleDegradation() end
        end
    end
    if State.time - State.petRepBonusCheckedAt >= 5 then
        State.petRepBonusCheckedAt = State.time
        refreshPetBonus()
    end
    if State.sessionStartStrength == nil then
        State.sessionStartStrength = getMyStrength()
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

track(LocalPlayer.CharacterAdded:Connect(function()
    Cache.char = nil; Cache.hum = nil; Cache.hrp = nil
    State.killTarget = nil
    State.kingKillTarget = nil
    State.kingKillActive = false
    State.toolCooldown = false
    State.toolOwnedByKill = false
    State.dualCurrentMode = "punch"
    State.muscleEventRef = nil
    State.rebirthEventRef = nil
    PortalCache = nil
    PortalCacheAt = 0
    table.clear(RenderCull.hidden)
    table.clear(PetHider.own)
    table.clear(PetHider.all)
    table.clear(PetHider.machines)
end))

-- ============================================================
-- 主 UI
-- ============================================================
local function buildUI()
    local screen = create("ScreenGui", {
        Name = "MuscleKingAutoUI", ResetOnSpawn = false,
        ZIndexBehavior = E_ZIdx, DisplayOrder = 99999,
    }, PlayerGui)
    State.ui.screen = screen

    local uiScale = create("UIScale", { Scale = 1 }, screen)
    State.ui.mainScale = uiScale

    local WIN_W, WIN_H = 350, 440
    local TITLE_H, TAB_H = 40, 40

    local main = create("Frame", {
        Name = "Main", AnchorPoint = V2n(0, 0),
        Position = DEFAULT.mainPos, Size = UD2o(WIN_W, WIN_H),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0, ClipsDescendants = true, Active = true,
    }, screen)
    State.ui.main = main
    corner(main, 14)
    stroke(main, Theme.Border, 1)

    local titleBar = create("Frame", {
        Name = "TitleBar", Size = UD2n(1, 0, 0, TITLE_H),
        Position = UD2o(0, 0), BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0, Active = true,
    }, main)
    corner(titleBar, 14)
    create("TextLabel", {
        BackgroundTransparency = 1, Position = UD2o(14, 0),
        Size = UD2n(1, -110, 1, 0),
        Font = Font.GothamBold, Text = "肌肉之王自动化",
        TextColor3 = Theme.Text, TextSize = 15, TextXAlignment = E_TxtXL,
    }, titleBar)

    local minBtn = create("TextButton", {
        Name = "Minimize", Size = UD2o(28, 26),
        Position = UD2n(1, -68, 0, 7),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "—",
        TextColor3 = Theme.TextDim, TextSize = 16,
    }, titleBar)
    corner(minBtn, 8)
    local closeBtn = create("TextButton", {
        Name = "Close", Size = UD2o(28, 26),
        Position = UD2n(1, -36, 0, 7),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
        Font = Font.GothamBold, Text = "×",
        TextColor3 = Theme.TextDim, TextSize = 18,
    }, titleBar)
    corner(closeBtn, 8)

    local tabBar = create("Frame", {
        Name = "TabBar", Position = UD2o(0, TITLE_H),
        Size = UD2n(1, 0, 0, TAB_H), BackgroundTransparency = 1,
    }, main)

    local TAB_W = 1/5
    local function makeTab(id, text, order)
        local btn = create("TextButton", {
            Name = "Tab_" .. id,
            Size = UD2n(TAB_W, -5, 1, -10),
            Position = UD2n((order - 1) * TAB_W, 2, 0, 5),
            BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
            Font = Font.GothamMedium, Text = text,
            TextColor3 = Theme.TextDim, TextSize = 11,
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
        Name = "Content", Position = UD2o(0, TITLE_H + TAB_H),
        Size = UD2n(1, 0, 1, -(TITLE_H + TAB_H)),
        BackgroundTransparency = 1,
    }, main)

    local function newPage(name)
        local page = create("ScrollingFrame", {
            Name = name, Size = UD2n(1, 0, 1, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UD2n(0, 0, 0, 0), AutomaticCanvasSize = E_AS_Y,
            ScrollingDirection = E_ScrollY, Visible = false, ClipsDescendants = true,
        }, content)
        create("UIPadding", {
            PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        }, page)
        create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = E_SortL }, page)
        return page
    end

    local function addDivider(parent, text)
        return create("TextLabel", {
            Size = UD2n(1, -6, 0, 22), BackgroundTransparency = 1,
            Font = Font.GothamBold, Text = text,
            TextColor3 = Theme.TextDim, TextSize = 11, TextXAlignment = E_TxtXL,
        }, parent)
    end

    local function addRowToggle(parent, label, default, onChange)
        local row = create("Frame", {
            Size = UD2n(1, -6, 0, 42),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 10); stroke(row, Theme.Border, 1)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UD2o(12, 0),
            Size = UD2n(1, -76, 1, 0),
            Font = Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = E_TxtXL,
        }, row)
        local tb = create("Frame", {
            AnchorPoint = V2n(1, 0.5), Position = UD2n(1, -12, 0.5, 0),
            Size = UD2o(42, 22), BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0,
        }, row)
        corner(tb, 11)
        local knob = create("Frame", {
            AnchorPoint = V2n(0, 0.5), Position = UD2n(0, 3, 0.5, 0),
            Size = UD2o(16, 16), BackgroundColor3 = Theme.TextDim,
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
                knob.BackgroundColor3 = Theme.TextDim
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
        return { set = function(v) value = v render(v) end, get = function() return value end }
    end

    local function addInput(parent, label, default, minVal, maxVal, onChange)
        local row = create("Frame", {
            Size = UD2n(1, -6, 0, 42),
            BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        }, parent)
        corner(row, 10); stroke(row, Theme.Border, 1)
        create("TextLabel", {
            BackgroundTransparency = 1, Position = UD2o(12, 0),
            Size = UD2n(1, -132, 1, 0),
            Font = Font.GothamMedium, Text = label,
            TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = E_TxtXL,
        }, row)
        local box = create("TextBox", {
            AnchorPoint = V2n(1, 0.5), Position = UD2n(1, -12, 0.5, 0),
            Size = UD2o(105, 28), BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0, Font = Font.GothamMedium,
            Text = tostring(default), TextColor3 = Theme.Text, TextSize = 13,
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
            Size = UD2n(1, -6, 0, 38),
            BackgroundColor3 = Theme.AccentDim, BorderSizePixel = 0,
            Font = Font.GothamBold, Text = label,
            TextColor3 = Theme.Text, TextSize = 14,
        }, parent)
        corner(btn, 10); stroke(btn, Theme.Accent, 1)
        track(btn.MouseButton1Click:Connect(onClick))
        return btn
    end

    local function addHint(parent, text)
        create("TextLabel", {
            Size = UD2n(1, -6, 0, 32), BackgroundTransparency = 1,
            Font = Font.Gotham, Text = text,
            TextColor3 = Theme.TextDim, TextSize = 11,
            TextWrapped = true, TextXAlignment = E_TxtXL, TextYAlignment = E_TxtYT,
        }, parent)
    end

    -- 锻炼
    local trainPage = newPage("TrainPage")
    local trainToggle, fastToggle
    trainToggle = addRowToggle(trainPage, "自动锻炼（固定 10 次/秒）", State.autoTrain, function(v)
        State.autoTrain = v
        if v and State.fastTrain then State.fastTrain = false fastToggle.set(false) end
        if v then cleanupTrainingState() end
    end)
    fastToggle = addRowToggle(trainPage, "快速锻炼（自定义频率）", State.fastTrain, function(v)
        State.fastTrain = v
        if v and State.autoTrain then
            State.autoTrain = false trainToggle.set(false)
        end
        if v then
            cleanupTrainingState()
            refreshPetBonus()
            if State.petRepBonus < 100 then
                notify(string.format("反复速度不足（当前 %d%%），功能可能无效", State.petRepBonus), 5)
            end
        else
            -- ★ 关闭时清理
            cleanupTrainingState()
            pcall(sweepOverflow)
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

    -- 传送
    local telePage = newPage("TelePage")
    State.ui.teleToggle = addRowToggle(telePage, "自动前往肌肉之王", State.autoTeleport, function(v)
        State.autoTeleport = v
    end)
    addActionButton(telePage, "强制单次传送", function()
        doTeleport(true)
    end)
    addHint(telePage, "使用传送门坐标。强制单次传送会刷新缓存。")

    -- 重生
    local rebPage = newPage("RebPage")
    addRowToggle(rebPage, "自动重生", State.autoRebirth, function(v) State.autoRebirth = v end)
    addInput(rebPage, "频率（次/秒）", State.rebirthRate, 1, 100, function(n) State.rebirthRate = n end)

    -- 杀戮
    local killPage = newPage("KillPage")
    addRowToggle(killPage, "全图杀戮", State.killEnabled, function(v) State.killEnabled = v end)
    addInput(killPage, "力量/耐久 阈值", State.killThreshold, 1, 100, function(n) State.killThreshold = n end)
    addDivider(killPage, "── 双工具 ──")
    addRowToggle(killPage, "杀戮+锻炼 双工具切换", State.dualEnabled, function(v) State.dualEnabled = v end)
    addDivider(killPage, "── 肌肉之王竞争 ──")
    addRowToggle(killPage, "自动击杀其他肌肉之王", State.autoKingKill, function(v)
        State.autoKingKill = v
        if not v then
            State.kingKillTarget = nil
            State.kingKillActive = false
        end
    end)
    addInput(killPage, "对方耐久 / 我力量 上限", State.kingKillThreshold, 1, 1000, function(n)
        State.kingKillThreshold = n
    end)
    addHint(killPage, "别人是肌肉之王时，会尝试击杀他。如果对方耐久 ≥ 我力量 × 上限，跳过等待。")

    -- 设置
    local setPage = newPage("SetPage")
    addDivider(setPage, "── 性能 ──")
    addRowToggle(setPage, "深度防卡顿", State.antiLagEnabled, function(v)
        State.antiLagEnabled = v
    end)
    addRowToggle(setPage, "渲染剔除（远处不显示）", State.renderCullEnabled, function(v)
        State.renderCullEnabled = v
    end)
    addInput(setPage, "剔除距离（studs）", State.renderCullDist, 100, 5000, function(n)
        State.renderCullDist = n
        -- ★ 距离改变立即生效
        pcall(forceRescanRenderCull)
    end)
    addRowToggle(setPage, "深度移除纹理", State.textureRemoverEnabled, function(v)
        State.textureRemoverEnabled = v
    end)

    addDivider(setPage, "── 隐藏 ──")
    addRowToggle(setPage, "隐藏自己的宠物", State.hideOwnPets, function(v) State.hideOwnPets = v end)
    addRowToggle(setPage, "隐藏所有玩家宠物", State.hideAllPets, function(v) State.hideAllPets = v end)
    addRowToggle(setPage, "隐藏器械", State.hideMachines, function(v) State.hideMachines = v end)
    addRowToggle(setPage, "隐藏其他 UI", State.hideUIEnabled, function(v)
        State.hideUIEnabled = v
        if v then pcall(hideAllUI) else pcall(restoreHiddenUI) end
    end)

    addDivider(setPage, "── 显示 ──")
    State.ui.infoToggle = addRowToggle(setPage, "信息小悬浮窗", State.infoWindowEnabled, function(v)
        State.infoWindowEnabled = v
        if State.ui.infoGui then State.ui.infoGui.Enabled = v end
    end)
    addRowToggle(setPage, "数字格式化显示", State.formatEnabled, function(v) State.formatEnabled = v end)

    addDivider(setPage, "── UI 大小 ──")
    addInput(setPage, "主窗口高度比例(%)", math.floor(State.uiHeightRatio * 100), 20, 90, function(n)
        State.uiHeightRatio = n / 100
        updateUIScale()
    end)
    addInput(setPage, "信息窗高度比例(%)", math.floor(State.infoHeightRatio * 100), 15, 70, function(n)
        State.infoHeightRatio = n / 100
        updateUIScale()
    end)
    addHint(setPage, "长按屏幕左下角复位按钮 3 秒可重置所有位置和大小。")

    local function switchTab(id)
        trainPage.Visible = (id == "train")
        telePage.Visible = (id == "tele")
        rebPage.Visible = (id == "reb")
        killPage.Visible = (id == "kill")
        setPage.Visible = (id == "set")
        local function tint(btn, on)
            btn.BackgroundColor3 = on and Theme.Accent or Theme.SurfaceAlt
            btn.TextColor3 = on and C3(255, 255, 255) or Theme.TextDim
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

    local dragging, dragStart, dragStartPos = false, nil, nil
    local function posIn(btn, pos)
        local ap = btn.AbsolutePosition; local as = btn.AbsoluteSize
        return pos.X >= ap.X and pos.X <= ap.X + as.X
           and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
    end
    track(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= E_UI_MB1 and input.UserInputType ~= E_UI_Touch then return end
        if posIn(minBtn, input.Position) or posIn(closeBtn, input.Position) then return end
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
        if input.UserInputType == E_UI_MB1 or input.UserInputType == E_UI_Touch then
            dragging = false
        end
    end))

    local minimized = false
    track(minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tabBar.Visible = false; content.Visible = false
            main.Size = UD2o(WIN_W, TITLE_H)
            minBtn.Text = "+"
        else
            tabBar.Visible = true; content.Visible = true
            main.Size = UD2o(WIN_W, WIN_H)
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
buildResetButton()
updateUIScale()

if State.ui.rateBox then
    State.ui.rateBox.TextEditable = not State.adaptiveEnabled
    State.ui.rateBox.TextColor3 = State.adaptiveEnabled and Theme.TextDim or Theme.Text
end
if State.antiLagEnabled then pcall(enableAntiLag) end
if State.textureRemoverEnabled then pcall(enableTextureRemover) end
if State.hideUIEnabled then pcall(hideAllUI) end
if State.infoWindowEnabled and State.ui.infoGui then State.ui.infoGui.Enabled = true end

local cam = Workspace.CurrentCamera
if cam then
    track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateUIScale))
end

track(RS_HB:Connect(onHeartbeat))

_G[SCRIPT_ID] = { version = VERSION, cleanup = destroy }
