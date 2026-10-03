--!nonstrict
--  AimAssist v33  (v32 + 打身体功能，头优先)
local VERSION = 33
local SHARED_KEY = "__AimAssistTool_v1"

local prev = shared[SHARED_KEY]
if prev and prev.version and prev.version >= VERSION then return end
if prev and prev.cleanup then pcall(prev.cleanup) end

local cleanupFns = {}
local function onCleanup(fn) table.insert(cleanupFns, fn) end
local function track(c) onCleanup(function() c:Disconnect() end) end

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local CollectionService   = game:GetService("CollectionService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local config = {
    enabled       = true,
    strength      = 1.00,
    maxAngle      = 360,
    angleStep     = 15,
    predictEnabled = true,
    predictTime   = 0.020,
    predictMax    = 0.050,
    bisectIters   = 3,
    lockTime      = 0.35,
    fireMode      = "tap",
    fireRate      = 0.04,
    targetHoldTime = 0.12,
    autoTrigger   = true,
    wallAim       = false,
    keywordFilter = true,
    teamMode      = "team",
    floorGuardK   = 1.5,
    bodyAim       = true,      -- ★ 新增：头不可见时允许瞄躯干
}

local diag = {
    cachedTotal = 0, filteredTeam = 0, filteredDead = 0,
    filteredAngle = 0, solvedAim = 0, losBlocked = 0,
    rays = 0, maxRays = 0, frameUs = 0,
    fireCount = 0, lastFireTime = 0,
    lastTargetName = "-",
    clamped = 0,
    aimYOffset = 0,
}

local cosLimit = -1
local function refreshCos()
    cosLimit = config.maxAngle >= 360 and -1
        or math.cos(math.rad(config.maxAngle))
end
refreshCos()

-- ============================================================
-- 阵营（同 v32）
-- ============================================================
local function teamKey(v)
    if v == nil then return nil end
    if typeof(v) == "string" then return v end
    return tostring(v)
end

local teamCache = setmetatable({}, { __mode = "k" })
local TEAM_TTL = 0.5

local function shouldSkip(targetModel)
    if config.teamMode == "none" then return false end

    local now = os.clock()
    local entry = teamCache[targetModel]
    if entry and (now - entry.t) < TEAM_TTL then return entry.v end

    local tp = Players:GetPlayerFromCharacter(targetModel)
    local skip = false

    if tp then
        if config.teamMode == "all" then
            skip = true
        else
            if player.Team ~= nil and tp.Team ~= nil then
                if player.Team == tp.Team
                   or player.Team.Name == tp.Team.Name then
                    skip = true
                end
            end
            if not skip then
                local a = teamKey(player:GetAttribute("Team"))
                    or teamKey(player:GetAttribute("Faction"))
                local b = teamKey(tp:GetAttribute("Team"))
                    or teamKey(tp:GetAttribute("Faction"))
                if a ~= nil and b ~= nil and a == b then skip = true end
            end
        end
    else
        if config.teamMode ~= "all" then
            local npcTeam = teamKey(targetModel:GetAttribute("Team"))
                or teamKey(targetModel:GetAttribute("Faction"))
            if npcTeam ~= nil then
                local myTeamName = teamKey(player.Team and player.Team.Name)
                local myAttr = teamKey(player:GetAttribute("Team"))
                    or teamKey(player:GetAttribute("Faction"))
                if npcTeam == myTeamName or npcTeam == myAttr then
                    skip = true
                end
            end
        end
    end

    teamCache[targetModel] = { t = now, v = skip }
    return skip
end

local function clearTeamCache()
    for k in pairs(teamCache) do teamCache[k] = nil end
end

-- ============================================================
-- 目标缓存（新增 torso）
-- ============================================================
local function getTorso(m)
    local t = m:FindFirstChild("UpperTorso")
        or m:FindFirstChild("Torso")
        or m:FindFirstChild("LowerTorso")
        or m:FindFirstChild("HumanoidRootPart")
    if t and t:IsA("BasePart") then return t end
    return nil
end

local candidateCache = {}
local cacheDirty = true

local function rebuildCache()
    local list = {}
    local myChar = player.Character
    local function add(m)
        if m == myChar then return end
        local hum = m:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local head = m:FindFirstChild("Head")
        if not head or not head:IsA("BasePart") then return end
        list[#list + 1] = {
            model = m, hum = hum, head = head,
            torso = getTorso(m),
        }
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then add(plr.Character) end
    end
    for _, obj in ipairs(CollectionService:GetTagged("AimTarget")) do
        if obj:IsA("Model") then add(obj) end
    end
    candidateCache = list
    diag.cachedTotal = #list
    cacheDirty = false
end

local function hookPlayer(plr)
    if plr == player then return end
    track(plr.CharacterAdded:Connect(function() cacheDirty = true end))
    track(plr.CharacterRemoving:Connect(function() cacheDirty = true end))
    track(plr:GetPropertyChangedSignal("Team"):Connect(function()
        if plr.Character then teamCache[plr.Character] = nil end
    end))
end
track(Players.PlayerAdded:Connect(function(p) cacheDirty = true; hookPlayer(p) end))
track(Players.PlayerRemoving:Connect(function() cacheDirty = true; clearTeamCache() end))
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
track(CollectionService:GetInstanceAddedSignal("AimTarget"):Connect(function() cacheDirty = true end))
track(CollectionService:GetInstanceRemovedSignal("AimTarget"):Connect(function() cacheDirty = true end))

-- ============================================================
-- 预测（key 用 part，兼容头/躯干）
-- ============================================================
local state = setmetatable({}, { __mode = "k" })
local function predict(part)
    local now = os.clock()
    local pos = part.Position
    local st = state[part]
    if not st then
        state[part] = { pos = pos, vel = Vector3.zero, time = now }
        return pos
    end
    local dt = now - st.time
    if dt > 1e-5 and dt < 0.5 then
        st.vel = st.vel:Lerp((pos - st.pos) / dt, 0.4)
        st.pos = pos
        st.time = now
    end
    if not config.predictEnabled then return pos end
    if st.vel.Magnitude < 3 then return pos end

    local off = st.vel * math.min(config.predictTime, config.predictMax)
    if off.Y < 0 then
        off = Vector3.new(off.X, off.Y * 0.5, off.Z)
    end
    local maxOff = part.Size.Y * 0.4
    if off.Magnitude > maxOff then off = off.Unit * maxOff end
    return pos + off
end

-- ============================================================
-- 射线
-- ============================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local BLOCK = {
    "Leaf", "Leaves", "Grass", "Bush", "Foliage",
    "Particle", "Smoke", "Fog", "Cloud", "Trail",
    "Beam", "Sparkle", "Effect", "FX",
    "Invisible", "Hitbox", "Trigger",
}
local partCache = setmetatable({}, { __mode = "k" })
local function isTransparent(p)
    if not p:IsA("BasePart") or not config.keywordFilter then return false end
    local c = partCache[p]
    if c ~= nil then return c end
    local n = p.Name
    local r = false
    for i = 1, #BLOCK do
        if n:find(BLOCK[i], 1, true) then r = true; break end
    end
    partCache[p] = r
    return r
end

local function ray(o, d)
    diag.rays += 1
    return workspace:Raycast(o, d, rayParams)
end

-- head 传 nil 时：打到目标模型任何部位都算可见（用于瞄身体）
local function visible(eye, pt, model, head, depth)
    if config.wallAim then return true end
    depth = depth or 0
    if depth > 2 then return false end
    local dir = pt - eye
    if dir.Magnitude < 0.01 then return true end
    local hit = ray(eye, dir)
    if not hit then return true end

    if hit.Instance:IsDescendantOf(model) then
        if not head then return true end
        local headBottom = head.Position.Y - head.Size.Y * 0.5
        if hit.Position.Y >= headBottom then
            return true
        end
        return false
    end

    if (hit.Position - pt).Magnitude < 0.3 then return true end
    if isTransparent(hit.Instance) then
        return visible(hit.Position + dir.Unit * 0.15, pt, model, head, depth + 1)
    end
    return false
end

local function clampAim(p, head)
    local minY = head.Position.Y - head.Size.Y * config.floorGuardK
    if p.Y < minY then
        diag.clamped += 1
        return Vector3.new(p.X, minY, p.Z)
    end
    return p
end

-- refHead == part 时视为瞄头（启用 clamp + 严格可见性）
-- refHead == nil 时视为瞄身体（不 clamp，宽松可见性）
local function solvePoint(part, model, eye, refHead)
    local isHead = (refHead == part)
    local function clampP(p)
        return isHead and clampAim(p, part) or p
    end

    local c = clampP(part.Position)
    if config.wallAim then return c end
    if visible(eye, c, model, refHead) then return c end

    local size = part.Size
    local sx = size.X * 0.5 * 0.9
    local sy = size.Y * 0.5 * 0.9
    local up = Vector3.new(0, 1, 0)
    local camRight = Vector3.new(camera.CFrame.RightVector.X, 0,
        camera.CFrame.RightVector.Z)
    if camRight.Magnitude < 0.01 then camRight = Vector3.new(1, 0, 0) end
    camRight = camRight.Unit

    local best, bestD = nil, math.huge
    local function try(edge)
        edge = clampP(edge)
        if not visible(eye, edge, model, refHead) then return end
        local lo, hi = 0, 1
        for _ = 1, config.bisectIters do
            local mid = (lo + hi) * 0.5
            local p = clampP(c:Lerp(edge, mid))
            if visible(eye, p, model, refHead) then
                hi = mid
            else
                lo = mid
            end
        end
        local p = clampP(c:Lerp(edge, hi))
        local d = (p - c).Magnitude
        if d < bestD then bestD = d; best = p end
    end
    try(c + up * sy)
    try(c - up * sy)
    try(c - camRight * sx)
    try(c + camRight * sx)
    return best
end

-- ============================================================
-- 锁定（新增 lockedPart）
-- ============================================================
local lockedModel = nil
local lockedPart = nil      -- "head" / "body"
local lockedUntil = 0
local lockFail = 0

local function clearLock()
    lockedModel = nil
    lockedPart = nil
    lockFail = 0
end

local function findTarget()
    diag.rays = 0
    if not camera then camera = workspace.CurrentCamera end
    if not camera then return nil, nil, nil end
    if cacheDirty then rebuildCache() end

    local eye = camera.CFrame.Position
    local dir = camera.CFrame.LookVector
    local char = player.Character
    local now = os.clock()

    diag.filteredTeam, diag.filteredDead, diag.filteredAngle = 0, 0, 0
    diag.solvedAim, diag.losBlocked = 0, 0
    diag.clamped = 0

    if char then
        rayParams.FilterDescendantsInstances = { camera, char }
    else
        rayParams.FilterDescendantsInstances = { camera }
    end

    -- 锁定优先
    if lockedModel and lockedPart and now < lockedUntil then
        local hum = lockedModel:FindFirstChildOfClass("Humanoid")
        local part
        if lockedPart == "head" then
            part = lockedModel:FindFirstChild("Head")
        else
            part = getTorso(lockedModel)
        end
        if hum and hum.Health > 0 and part and part:IsA("BasePart") then
            local to = part.Position - eye
            local d = to.Magnitude
            if d > 0.01 then
                local dot = dir:Dot(to / d)
                if dot >= cosLimit then
                    local refHead = (lockedPart == "head") and part or nil
                    local p = solvePoint(part, lockedModel, eye, refHead)
                    if p then
                        lockFail = 0
                        lockedUntil = now + config.lockTime
                        diag.solvedAim = 1
                        diag.lastTargetName = lockedModel.Name
                        diag.aimYOffset = p.Y - part.Position.Y
                        return p, lockedModel, lockedPart
                    end
                end
            end
        end
        lockFail += 1
        if lockFail >= 2 then clearLock() end
    end

    -- 公共过滤：不通过则返回 nil
    local function basicFilter(e)
        if not e.model.Parent then return false end
        if e.hum.Health <= 0 then diag.filteredDead += 1; return false end
        local hstate = e.hum:GetState()
        if hstate == Enum.HumanoidStateType.Dead
            or hstate == Enum.HumanoidStateType.Physics then
            diag.filteredDead += 1
            return false
        end
        if shouldSkip(e.model) then diag.filteredTeam += 1; return false end
        return true
    end

    local bestE, bestP, bestPart, bestDot = nil, nil, nil, cosLimit

    -- ── 第一遍：扫头 ───────────────────────────────
    for _, e in ipairs(candidateCache) do
        if not basicFilter(e) then continue end

        local to = e.head.Position - eye
        local d = to.Magnitude
        if d < 0.01 then continue end
        local dot = dir:Dot(to / d)
        if dot < cosLimit then diag.filteredAngle += 1; continue end

        if not visible(eye, e.head.Position, e.model, e.head) then
            diag.losBlocked += 1
            continue
        end

        if dot > bestDot then
            bestDot = dot
            bestE = e
            bestP = clampAim(e.head.Position, e.head)
            bestPart = "head"
        end
    end

    -- ── 第二遍：头都看不到时扫躯干 ─────────────────
    if not bestE and config.bodyAim then
        bestDot = cosLimit
        for _, e in ipairs(candidateCache) do
            if not basicFilter(e) then continue end
            if not e.torso then continue end

            local to = e.torso.Position - eye
            local d = to.Magnitude
            if d < 0.01 then continue end
            local dot = dir:Dot(to / d)
            if dot < cosLimit then continue end

            -- 瞄身体：打到模型任何部位都算可见（head 传 nil）
            if not visible(eye, e.torso.Position, e.model, nil) then
                continue
            end

            if dot > bestDot then
                bestDot = dot
                bestE = e
                bestP = e.torso.Position
                bestPart = "body"
            end
        end
    end

    if not bestE then
        clearLock()
        return nil, nil, nil
    end

    diag.solvedAim = 1
    lockedModel = bestE.model
    lockedPart = bestPart
    lockedUntil = now + config.lockTime
    lockFail = 0
    diag.lastTargetName = bestE.model.Name
    diag.aimYOffset = bestP.Y - bestE.head.Position.Y
    return bestP, bestE.model, bestPart
end

-- ============================================================
-- HUD
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "AimAssistMain"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
onCleanup(function() gui:Destroy() end)

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 400, 0, 110)
label.Position = UDim2.new(0, 10, 0, 10)
label.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
label.BackgroundTransparency = 0.35
label.BorderSizePixel = 0
label.TextColor3 = Color3.fromRGB(200, 200, 210)
label.Font = Enum.Font.Code
label.TextSize = 13
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Parent = gui
Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

local sGui = Instance.new("ScreenGui")
sGui.Name = "AimAssistStatus"
sGui.ResetOnSpawn = false
sGui.Parent = player:WaitForChild("PlayerGui")
onCleanup(function() sGui:Destroy() end)

local sFrame = Instance.new("Frame")
sFrame.Size = UDim2.new(0, 420, 0, 132)
sFrame.Position = UDim2.new(1, -16, 1, -16)
sFrame.AnchorPoint = Vector2.new(1, 1)
sFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
sFrame.BackgroundTransparency = 0.2
sFrame.BorderSizePixel = 0
sFrame.Parent = sGui
Instance.new("UICorner", sFrame).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 60, 80)
stroke.Thickness = 1
stroke.Transparency = 0.3
stroke.Parent = sFrame

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.Parent = sFrame

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 8, 0, 8)
dot.Position = UDim2.new(0, 0, 0, 5)
dot.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
dot.BorderSizePixel = 0
dot.Parent = sFrame
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local sLabel = Instance.new("TextLabel")
sLabel.Size = UDim2.new(1, -14, 1, 0)
sLabel.Position = UDim2.new(0, 14, 0, 0)
sLabel.BackgroundTransparency = 1
sLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
sLabel.Font = Enum.Font.Code
sLabel.TextSize = 12
sLabel.TextXAlignment = Enum.TextXAlignment.Left
sLabel.TextYAlignment = Enum.TextYAlignment.Top
sLabel.RichText = true
sLabel.Parent = sFrame

local function firePress()
    pcall(function() mouse1press() end)
    pcall(function() VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,1) end)
end
local function fireRelease()
    pcall(function() mouse1release() end)
    pcall(function() VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,1) end)
end

local lastSeen = 0
local lastTap = 0
local firing = false
local hudT = 0

RunService:BindToRenderStep(
    "AimAssistStep",
    Enum.RenderPriority.Camera.Value + 1,
    function()
        if not camera then camera = workspace.CurrentCamera end
        if not camera then return end

        local t0 = os.clock()
        local target, model, aimPart = findTarget()

        -- 预测：按锁定部位预测
        if target and model and config.predictEnabled and aimPart then
            local part
            if aimPart == "head" then
                part = model:FindFirstChild("Head")
            else
                part = getTorso(model)
            end
            if part then
                local pp = predict(part)
                target = target + (pp - part.Position)
                if aimPart == "head" then
                    target = clampAim(target, part)
                end
            end
        end

        if config.enabled and target then
            local want = CFrame.lookAt(camera.CFrame.Position, target, Vector3.new(0, 1, 0))
            if config.strength >= 1 then
                camera.CFrame = want
            else
                camera.CFrame = camera.CFrame:Lerp(want, config.strength)
            end
        end

        local now = os.clock()
        local hasTarget = config.enabled and target ~= nil
        if hasTarget then lastSeen = now end

        local teamOK = true
        if hasTarget and model then teamOK = not shouldSkip(model) end

        -- 开火前 LOS：按部位选对应的可见性检查
        local losOK = true
        if hasTarget and not config.wallAim and model and aimPart then
            if aimPart == "head" then
                local head = model:FindFirstChild("Head")
                losOK = visible(camera.CFrame.Position, target, model, head)
            else
                losOK = visible(camera.CFrame.Position, target, model, nil)
            end
        end

        local shouldFire = config.autoTrigger and config.enabled and hasTarget
            and teamOK and losOK
            and (now - lastSeen <= config.targetHoldTime + 0.001)

        local st
        if not config.enabled then st = "关闭"
        elseif not config.autoTrigger then st = "扳机关"
        elseif not hasTarget then st = "搜索"
        elseif not teamOK then st = "队友"
        elseif not losOK then st = "遮挡"
        elseif now - lastTap < config.fireRate then st = "冷却"
        else st = "开火" end

        if config.fireMode == "tap" then
            if shouldFire then
                if now - lastTap >= config.fireRate then
                    lastTap = now
                    if firing then fireRelease() end
                    task.defer(firePress)
                    firing = true
                    diag.fireCount += 1
                    diag.lastFireTime = now
                end
            else
                if firing then fireRelease(); firing = false end
            end
        else
            if shouldFire and not firing then
                firing = true
                firePress()
                diag.fireCount += 1
                diag.lastFireTime = now
            elseif not shouldFire and firing then
                firing = false
                fireRelease()
            end
        end

        diag.frameUs = (os.clock() - t0) * 1e6
        if diag.rays > diag.maxRays then diag.maxRays = diag.rays end

        hudT += 1 / 60
        if hudT < 0.05 then return end
        hudT = 0

        local teamName = config.teamMode == "all" and "只打NPC"
            or config.teamMode == "none" and "无过滤"
            or "同队不打"

        label.Text = string.format(
            "AimAssist v%d\n"
            .. "瞄准[%s]  扳机[%s]  角度 %s\n"
            .. "队伍[%s]  穿墙[%s]  树叶[%s]  打身[%s]\n"
            .. "E瞄准 T扳机 O队伍 G穿墙 N树叶 B打身\n"
            .. "-/+角度  M模式",
            VERSION,
            config.enabled and "开" or "关",
            config.autoTrigger and "开" or "关",
            config.maxAngle >= 360 and "全向" or (tostring(config.maxAngle) .. "°"),
            teamName,
            config.wallAim and "★开" or "关",
            config.keywordFilter and "开" or "关",
            config.bodyAim and "开" or "关"
        )

        local sc
        if st == "开火" then sc = Color3.fromRGB(0, 255, 100)
        elseif st == "冷却" then sc = Color3.fromRGB(255, 200, 0)
        elseif st == "队友" then sc = Color3.fromRGB(80, 160, 255)
        elseif st == "遮挡" then sc = Color3.fromRGB(255, 100, 100)
        elseif st == "搜索" then sc = Color3.fromRGB(120, 180, 255)
        elseif st == "扳机关" then sc = Color3.fromRGB(255, 140, 0)
        else sc = Color3.fromRGB(255, 80, 80) end
        dot.BackgroundColor3 = sc

        local lockStr = lockedModel and lockedModel.Name or "-"
        local partStr = lockedPart == "body" and "体"
            or lockedPart == "head" and "头" or ""

        sLabel.Text = string.format(
            '<font color="rgb(%d,%d,%d)">%s</font>  %s\n'
            .. '缓存 %d  队 %d  死 %d  角 %d  挡 %d\n'
            .. '射线 %d 峰 %d  %.2fms  clamp %d  Y偏 %.2f\n'
            .. '锁 %s %s  开火 %d',
            math.floor(sc.R * 255), math.floor(sc.G * 255), math.floor(sc.B * 255),
            st, diag.lastTargetName,
            diag.cachedTotal, diag.filteredTeam, diag.filteredDead,
            diag.filteredAngle, diag.losBlocked,
            diag.rays, diag.maxRays, diag.frameUs / 1000,
            diag.clamped, diag.aimYOffset,
            lockStr, partStr, diag.fireCount
        )
    end
)

track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.E then
        config.enabled = not config.enabled
        if not config.enabled and firing then firing = false; fireRelease() end
    elseif k == Enum.KeyCode.T then
        config.autoTrigger = not config.autoTrigger
        if not config.autoTrigger and firing then firing = false; fireRelease() end
    elseif k == Enum.KeyCode.O then
        local order = { "team", "all", "none" }
        local idx = 1
        for i, v in ipairs(order) do
            if v == config.teamMode then idx = i; break end
        end
        config.teamMode = order[(idx % #order) + 1]
        clearTeamCache()
        clearLock()
    elseif k == Enum.KeyCode.G then
        config.wallAim = not config.wallAim
        clearLock()
    elseif k == Enum.KeyCode.N then
        config.keywordFilter = not config.keywordFilter
        partCache = setmetatable({}, { __mode = "k" })
    elseif k == Enum.KeyCode.B then
        config.bodyAim = not config.bodyAim
        clearLock()
    elseif k == Enum.KeyCode.Minus or k == Enum.KeyCode.KeypadMinus then
        config.maxAngle = math.max(15, config.maxAngle - config.angleStep)
        refreshCos()
    elseif k == Enum.KeyCode.Equals or k == Enum.KeyCode.KeypadPlus then
        config.maxAngle = math.min(360, config.maxAngle + config.angleStep)
        refreshCos()
    elseif k == Enum.KeyCode.M then
        config.fireMode = (config.fireMode == "tap") and "hold" or "tap"
        if firing then firing = false; fireRelease() end
    end
end))

onCleanup(function()
    if firing then firing = false; pcall(fireRelease) end
end)

shared[SHARED_KEY] = {
    version = VERSION,
    cleanup = function()
        for i = #cleanupFns, 1, -1 do pcall(cleanupFns[i]) end
        if shared[SHARED_KEY] and shared[SHARED_KEY].version == VERSION then
            shared[SHARED_KEY] = nil
        end
    end,
}
