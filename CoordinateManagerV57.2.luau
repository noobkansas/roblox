--[[ 坐标管理器 v57.2 · 第三人称相机 · 抬升保高 · 中断反馈 · 分游戏存储 · 撤回栈 ]]
local SCRIPT_ID = "CoordinateManager"
local VERSION = 57

local ANTI = rawget(_G, "__CM_ANTI")
local _guiSfx = tostring(math.random(100000, 999999))
local _apiKey = "__CM_" .. tostring(math.random(1000000, 9999999))

pcall(function() print("[" .. SCRIPT_ID .. "] v" .. VERSION) end)

local MAIN_MIN_W, MAIN_MIN_H = 260, 90
local MAIN_MAX_W = 720
local BLK_MIN_W, BLK_MIN_H = 180, 50
local BLK_MAX_W = 600
local SET_MIN_W, SET_MIN_H = 260, 120
local SET_MAX_W = 620
local HDL, HDR_H, TITLE_H = 14, 30, 38
local DBL_MS, RESET_HOLD = 400, 3
local HOLD_REPLACE_MS = 2000
local UNDO_MAX = 100
local SAVE_INTERVAL = 15

local AXES = {"x","y","z"}
local NOCLIP = {{id="off",label="关闭"},{id="basic",label="基础"},{id="all",label="全部"},{id="persistent",label="持续"}}
local PATHS = {{id="direct",label="直线"},{id="lift",label="抬升"},{id="bezier",label="曲线"}}

local BYPASS = {
	{id="off",     label="关闭",   row=1},
	{id="walk",    label="物理",   row=1},
	{id="hybrid",  label="混合",   row=1},
	{id="stealth", label="隐蔽",   row=1},
	{id="jitter",  label="抖动",   row=2},
	{id="pulse",   label="脉冲",   row=2},
	{id="zigzag",  label="之字",   row=2},
	{id="anim",    label="动画",   row=3},
	{id="phys",    label="力推",   row=3},
	{id="ghost",   label="幽灵",   row=3},
	{id="owner",   label="所有权", row=4},
	{id="speed",   label="速度",   row=4},
	{id="jump",    label="跳跃链", row=4},
	{id="align",   label="对齐",   row=5},
	{id="full",    label="全套",   row=5},
	{id="net",     label="网络",   row=5},
}
local BYPASS_DESC = {
	off     = "直接 CFrame，最快",
	walk    = "Humanoid:Move 走路",
	hybrid  = "每帧 CFrame + 速度同步",
	stealth = "混合 + 缓动 + 曲线",
	jitter  = "混合 + 每帧 ±3% 抖动",
	pulse   = "移动/停顿 交替",
	zigzag  = "正弦偏移",
	anim    = "强制 Running + 动画",
	phys    = "BodyVelocity 力推 + 重力补偿",
	ghost   = "力推 + HOOK 全套防护",
	owner   = "抢网络所有权 + 速度欺骗",
	speed   = "按服务端上限插值",
	jump    = "跳跃 + 空中推进",
	align   = "AlignPosition 约束",
	full    = "所有权 + 速度 + HOOK",
	net     = "屏蔽反作弊 Remote",
}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Http = game:GetService("HttpService")
local LP = Players.LocalPlayer

local GAME_ID = 0
do
	local ok, id = pcall(function() return game.GameId end)
	if ok and type(id) == "number" then GAME_ID = id end
end
local GAME_TAG = (GAME_ID > 0) and ("g" .. tostring(GAME_ID)) or "default"
local SAVE_DIR = "CoordinateManager"
local SAVE_FILE = SAVE_DIR .. "/" .. GAME_TAG .. ".json"
local STATE_FILE = SAVE_DIR .. "/ui_state.json"

local gE = (type(getgenv)=="function" and getgenv()) or _G
local pv = gE[SCRIPT_ID]
if type(pv) == "table" and type(pv.version) == "number" and pv.version >= VERSION then
	warn("[" .. SCRIPT_ID .. "] 已在运行 v" .. tostring(pv.version)); return
end
local inherit = nil
if type(pv) == "table" then
	inherit = pv.state
	if type(pv.destroy) == "function" then pcall(pv.destroy) end
end

local _G0 = (type(getgenv)=="function" and getgenv()) or _G
local function _fCS()
	if type(setclipboard)=="function" then return setclipboard end
	if type(toclipboard)=="function" then return toclipboard end
	if type(set_clipboard)=="function" then return set_clipboard end
	if type(writeclipboard)=="function" then return writeclipboard end
	if type(setrbxclipboard)=="function" then return setrbxclipboard end
	local syn = rawget(_G0, "syn")
	if type(syn)=="table" then
		if type(syn.write_clipboard)=="function" then return function(t) return syn.write_clipboard(t) end end
		if type(syn.set_clipboard)=="function" then return function(t) return syn.set_clipboard(t) end end
	end
	if type(_G0)=="table" then
		if type(_G0.setclipboard)=="function" then return _G0.setclipboard end
		if type(_G0.toclipboard)=="function" then return _G0.toclipboard end
		if type(_G0.set_clipboard)=="function" then return _G0.set_clipboard end
		if type(_G0.writeclipboard)=="function" then return _G0.writeclipboard end
	end
end
local function _fCG()
	if type(getclipboard)=="function" then return getclipboard end
	if type(get_clipboard)=="function" then return get_clipboard end
	if type(readclipboard)=="function" then return readclipboard end
	if type(getrbxclipboard)=="function" then return getrbxclipboard end
	local syn = rawget(_G0, "syn")
	if type(syn)=="table" then
		if type(syn.read_clipboard)=="function" then return function() return syn.read_clipboard() end end
		if type(syn.get_clipboard)=="function" then return function() return syn.get_clipboard() end end
	end
	if type(_G0)=="table" then
		if type(_G0.getclipboard)=="function" then return _G0.getclipboard end
		if type(_G0.get_clipboard)=="function" then return _G0.get_clipboard end
		if type(_G0.readclipboard)=="function" then return _G0.readclipboard end
	end
end
local _clipSet, _clipGet = _fCS(), _fCG()
local hasClip = _clipSet ~= nil and _clipGet ~= nil
local hasFile = type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function"

if hasFile then
	pcall(function()
		if type(makefolder) == "function" then pcall(makefolder, SAVE_DIR)
		elseif type(createfolder) == "function" then pcall(createfolder, SAVE_DIR) end
	end)
end

local defMainPos = UDim2.new(0.5, -180, 0, 60)
local defSetPos  = UDim2.new(1, -360, 0, 60)

local St = {
	saved = {}, inputs = {x="",y="",z=""},
	undoStack = {}, redoStack = {},
	nid = 1, mode = "teleport", speed = 60, prec = 10,
	noclip = "persistent", path = "direct", bypass = "off",
	stealthMaxStep = 18, liftHeight = 30, asc = true,
	mainW = 360, mainH = 300, setW = 360, setH = 480,
	blockSizes = {}, hook = false, godmode = false, anticframe = false,
	nograv = false, camStable = true, raycastBlind = false, writeProtect = false,
	maxServerSpeed = 200, sel = {}, multi = false,
	min = false, advOpen = false, _diagShown = false,
}

local UIState = {
	mainPos = defMainPos, setPos = defSetPos,
	mainVisible = true, setVisible = false,
	blockStates = {},
}

local function decode(t)
	local ok, d = pcall(function() return Http:JSONDecode(t) end)
	if ok and type(d) == "table" then return d end
end
local function loadFromFile()
	if not hasFile then return nil end
	local ok, ex = pcall(isfile, SAVE_FILE); if not ok or not ex then return nil end
	local ok2, c = pcall(readfile, SAVE_FILE); if not ok2 or type(c)~="string" or #c<2 then return nil end
	return decode(c)
end
local function saveToFile()
	if not hasFile then return false end
	local cfg = {
		saved=St.saved, mode=St.mode, speed=St.speed, prec=St.prec,
		noclip=St.noclip, path=St.path, bypass=St.bypass, stealthMaxStep=St.stealthMaxStep,
		liftHeight=St.liftHeight,
		nid=St.nid, asc=St.asc, mainW=St.mainW, mainH=St.mainH, setW=St.setW, setH=St.setH,
		blockSizes=St.blockSizes, hook=St.hook, godmode=St.godmode, anticframe=St.anticframe,
		nograv=St.nograv, camStable=St.camStable,
		raycastBlind=St.raycastBlind, writeProtect=St.writeProtect,
		maxServerSpeed=St.maxServerSpeed, gameId=GAME_ID,
	}
	local ok, en = pcall(function() return Http:JSONEncode(cfg) end)
	if not ok or not en then return false end
	return (pcall(writefile, SAVE_FILE, en))
end
local function ud2s(u)
	if typeof(u) == "UDim2" then
		return string.format("%d,%d,%d,%d", u.X.Scale*10000, u.X.Offset, u.Y.Scale*10000, u.Y.Offset)
	end
	return nil
end
local function s2ud(s)
	if type(s) ~= "string" then return nil end
	local a,b,c,d = s:match("^(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)$")
	if not a then return nil end
	return UDim2.new(tonumber(a)/10000, tonumber(b), tonumber(c)/10000, tonumber(d))
end
local function saveUIState()
	if not hasFile then return end
	local t = {
		mainPos = ud2s(UIState.mainPos), setPos = ud2s(UIState.setPos),
		mainVisible = UIState.mainVisible, setVisible = UIState.setVisible,
		blockStates = {},
	}
	for id, b in pairs(UIState.blockStates) do
		t.blockStates[id] = {min = b.min, detach = b.detach, detPos = ud2s(b.detPos)}
	end
	local ok, en = pcall(function() return Http:JSONEncode(t) end)
	if not ok then return end
	pcall(writefile, STATE_FILE, en)
end
local function loadUIState()
	if not hasFile then return end
	local ok, ex = pcall(isfile, STATE_FILE); if not ok or not ex then return end
	local ok2, c = pcall(readfile, STATE_FILE); if not ok2 then return end
	local d = decode(c); if type(d) ~= "table" then return end
	if type(d.mainPos)=="string" then UIState.mainPos = s2ud(d.mainPos) or defMainPos end
	if type(d.setPos)=="string" then UIState.setPos = s2ud(d.setPos) or defSetPos end
	if type(d.mainVisible)=="boolean" then UIState.mainVisible = d.mainVisible end
	if type(d.setVisible)=="boolean" then UIState.setVisible = d.setVisible end
	if type(d.blockStates)=="table" then
		for id, b in pairs(d.blockStates) do
			if type(b) == "table" then
				UIState.blockStates[id] = {
					min = b.min == true, detach = b.detach == true,
					detPos = type(b.detPos)=="string" and s2ud(b.detPos) or nil,
				}
			end
		end
	end
end

local fileData = loadFromFile()
loadUIState()

if type(fileData) == "table" then
	local src = fileData
	St.saved = (type(src.saved)=="table") and src.saved or {}
	St.mode = (type(src.mode)=="string") and src.mode or "teleport"
	St.speed = tonumber(src.speed) or 60
	St.prec = tonumber(src.prec) or 10
	St.noclip = (type(src.noclip)=="string") and src.noclip or "persistent"
	St.path = (type(src.path)=="string") and src.path or "direct"
	St.bypass = (type(src.bypass)=="string") and src.bypass or "off"
	St.stealthMaxStep = tonumber(src.stealthMaxStep) or 18
	St.liftHeight = tonumber(src.liftHeight) or 30
	St.nid = tonumber(src.nid) or 1
	St.asc = src.asc ~= false
	St.mainW = tonumber(src.mainW) or 360
	St.mainH = tonumber(src.mainH) or 300
	St.setW = tonumber(src.setW) or 360
	St.setH = tonumber(src.setH) or 480
	St.blockSizes = (type(src.blockSizes)=="table") and src.blockSizes or {}
	St.hook = src.hook == true
	St.godmode = src.godmode == true
	St.anticframe = src.anticframe == true
	St.nograv = src.nograv == true
	St.camStable = src.camStable ~= false
	St.raycastBlind = src.raycastBlind == true
	St.writeProtect = src.writeProtect == true
	St.maxServerSpeed = tonumber(src.maxServerSpeed) or 200
elseif type(inherit) == "table" then
	for k, v in pairs(inherit) do
		if St[k] == nil then St[k] = v end
	end
	if type(inherit.saved) == "table" then St.saved = inherit.saved end
	if type(inherit.inputs) == "table" then St.inputs = inherit.inputs end
	St.sel = {}; St.multi = false; St.min = false; St.advOpen = false
end

if not St.stealthMaxStep or St.stealthMaxStep < 1 then St.stealthMaxStep = 18 end
if not St.maxServerSpeed or St.maxServerSpeed < 50 then St.maxServerSpeed = 200 end
if not St.liftHeight or St.liftHeight < 1 then St.liftHeight = 30 end

local Th = {
	Bg=Color3.fromRGB(22,22,26), Sur=Color3.fromRGB(33,33,40),
	Sec=Color3.fromRGB(28,28,34), Str=Color3.fromRGB(58,58,70),
	Txt=Color3.fromRGB(236,236,246), Sub=Color3.fromRGB(148,148,165),
	Acc=Color3.fromRGB(88,140,255), AccD=Color3.fromRGB(44,72,130),
	Ok=Color3.fromRGB(86,200,122), Err=Color3.fromRGB(240,92,92),
	Warn=Color3.fromRGB(240,180,80), Hdl=Color3.fromRGB(230,230,240),
}

local TP_BUSY = { untilT = 0, grace = 1.5 }
local function tpBusyMark(sec)
	local t = os.clock() + (sec or TP_BUSY.grace)
	if t > TP_BUSY.untilT then TP_BUSY.untilT = t end
end
local function tpBusyIsBusy()
	return os.clock() < TP_BUSY.untilT
end

local INTERRUPT = { flag = false }

local Conns = {}
local dead = false
local function trk(c) table.insert(Conns, c); return c end
local function mk(cls, props, kids)
	local i = Instance.new(cls); local p
	if props then for k, v in pairs(props) do
		if k == "Parent" then p = v else pcall(function() i[k] = v end) end
	end end
	if kids then for _, c in ipairs(kids) do c.Parent = i end end
	if p then i.Parent = p end
	return i
end

local guiParentCache = nil
local function guiP()
	if guiParentCache and guiParentCache.Parent then return guiParentCache end
	if type(gethui) == "function" then
		local ok, r = pcall(gethui)
		if ok and r and typeof(r)=="Instance" and r ~= game then
			local ok2 = pcall(function() local t = Instance.new("Folder"); t.Parent = r; t:Destroy() end)
			if ok2 then guiParentCache = r; return r end
		end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then
		local ok2 = pcall(function() local t = Instance.new("Folder"); t.Parent = cg; t:Destroy() end)
		if ok2 then guiParentCache = cg; return cg end
	end
	local pg = LP:FindFirstChildOfClass("PlayerGui"); if pg then guiParentCache = pg; return pg end
	guiParentCache = LP:WaitForChild("PlayerGui")
	return guiParentCache
end

local function cl(v, lo, hi) if v<lo then return lo end if v>hi then return hi end return v end
local function clSpd(v) return cl(math.floor((tonumber(v) or 60)+0.5), 1, 20000) end
local function clPrec(v) return cl(math.floor((tonumber(v) or 10)+0.5), 1, 500) end
local function clStep(v) return cl(math.floor((tonumber(v) or 18)+0.5), 1, 5000) end
local function clSrv(v) return cl(math.floor((tonumber(v) or 200)+0.5), 30, 2000) end
local function clLift(v) return cl(math.floor((tonumber(v) or 30)+0.5), 1, 500) end
local function toClip(t) if not _clipSet then return false end return (pcall(_clipSet, t)) end
local function fromClip() if not _clipGet then return nil end local ok, r = pcall(_clipGet); if ok and type(r)=="string" then return r end end

local function evalMathExpr(expr, cur)
	expr = tostring(expr):gsub("%s+", ""); if expr == "" then return nil end
	local pos = 1
	local function peek() return expr:sub(pos, pos) end
	local function nextc() local c = expr:sub(pos, pos); pos = pos + 1; return c end
	local parseAdd
	local function parseNum()
		if expr:sub(pos, pos+2) == "cur" then pos = pos + 3; return cur end
		local s = expr:sub(pos):match("^%d+%.?%d*"); if not s then return nil end
		pos = pos + #s; return tonumber(s)
	end
	local function parseUnary()
		local c = peek()
		if c == "-" then nextc(); local v = parseUnary(); if v then return -v end return nil end
		if c == "+" then nextc(); return parseUnary() end
		if c == "(" then nextc(); local v = parseAdd(); if peek()==")" then nextc() end; return v end
		return parseNum()
	end
	local function parseMul()
		local v = parseUnary(); if not v then return nil end
		while true do
			local c = peek()
			if c == "*" then nextc(); local r = parseUnary(); if not r then return nil end; v = v*r
			elseif c == "/" then nextc(); local r = parseUnary(); if not r or r == 0 then return nil end; v = v/r
			else break end
		end
		return v
	end
	parseAdd = function()
		local v = parseMul(); if not v then return nil end
		while true do
			local c = peek()
			if c == "+" then nextc(); local r = parseMul(); if not r then return nil end; v = v+r
			elseif c == "-" then nextc(); local r = parseMul(); if not r then return nil end; v = v-r
			else break end
		end
		return v
	end
	local v = parseAdd()
	if v == nil or pos <= #expr then return nil end
	return v
end

local OWNER = {enabled=false, conn=nil, lastTry=0, interval=0.35, confirmed=false, lastResult="", notified=false}
function OWNER.claimCharacter()
	local ch = LP.Character; if not ch then return false end
	local hrp = ch:FindFirstChild("HumanoidRootPart"); if not hrp then return false end
	local cur = nil
	pcall(function() cur = hrp:GetNetworkOwner() end)
	if cur == LP then OWNER.confirmed = true; OWNER.lastResult = "already-owner"; return true end
	local ok = pcall(function() hrp:SetNetworkOwner(LP) end)
	if ok then
		pcall(function() cur = hrp:GetNetworkOwner() end)
		if cur == LP or cur == nil then OWNER.confirmed = true; OWNER.lastResult = "success"; return true end
	end
	if not ok then
		pcall(function() hrp:SetNetworkOwnershipAuto() end)
		pcall(function() cur = hrp:GetNetworkOwner() end)
		if cur == LP then OWNER.confirmed = true; OWNER.lastResult = "auto-success"; return true end
	end
	OWNER.lastResult = "locked"
	return false
end
function OWNER.start()
	if OWNER.conn then return end
	OWNER.enabled = true
	OWNER.conn = RS.Heartbeat:Connect(function(dt)
		if dead or not OWNER.enabled then return end
		OWNER.lastTry = OWNER.lastTry + dt
		if OWNER.lastTry >= OWNER.interval then
			OWNER.lastTry = 0; OWNER.claimCharacter()
		end
	end)
end
function OWNER.stop()
	OWNER.enabled = false
	if OWNER.conn then OWNER.conn:Disconnect(); OWNER.conn = nil end
end

local HOOK = {
	installed=false, oldIndex=nil, oldNewIndex=nil, oldNamecall=nil,
	fakeCF=setmetatable({}, {__mode="k"}),
	fakeWS=setmetatable({}, {__mode="k"}),
	fakeVel=setmetatable({}, {__mode="k"}),
	fakeHealth=setmetatable({}, {__mode="k"}),
	blocked=setmetatable({}, {__mode="k"}),
	lastEnsure=0, raycastBlind=false, writeProtect=false, internalCall=false,
	antiKick=true, V3ZERO = Vector3.new(0, 0, 0),
}
function HOOK.supported() return type(hookmetamethod)=="function" and type(typeof)=="function" end
function HOOK.setCF(part, cf)
	if not part or not part.Parent then return end
	local old = HOOK.internalCall; HOOK.internalCall = true
	pcall(function() part.CFrame = cf end); HOOK.internalCall = old
end
function HOOK.setVel(part, v)
	if not part or not part.Parent then return end
	local old = HOOK.internalCall; HOOK.internalCall = true
	pcall(function() part.AssemblyLinearVelocity = v end); HOOK.internalCall = old
end
function HOOK.setAngVel(part, v)
	if not part or not part.Parent then return end
	local old = HOOK.internalCall; HOOK.internalCall = true
	pcall(function() part.AssemblyAngularVelocity = v end); HOOK.internalCall = old
end
function HOOK.setHum(hum, prop, val)
	if not hum or not hum.Parent then return end
	local old = HOOK.internalCall; HOOK.internalCall = true
	pcall(function() hum[prop] = val end); HOOK.internalCall = old
end
function HOOK.install()
	if not HOOK.supported() then return false end
	if HOOK.installed then return true end
	local ok1, oldI = pcall(hookmetamethod, game, "__index", function(self, key)
		if typeof(self) == "Instance" then
			local fws = HOOK.fakeWS[self]
			if fws then
				if key == "WalkSpeed" then return fws end
				if key == "JumpPower" or key == "JumpHeight" then return 50 end
			end
			local fh = HOOK.fakeHealth[self]
			if fh and key == "Health" then return fh end
		end
		return HOOK.oldIndex(self, key)
	end)
	if not ok1 then return false end
	HOOK.oldIndex = oldI
	local ok2, oldN = pcall(hookmetamethod, game, "__newindex", function(self, key, value)
		if HOOK.writeProtect and not HOOK.internalCall and typeof(self) == "Instance" then
			if HOOK.fakeCF[self] and (key == "CFrame" or key == "Position") then return end
			if HOOK.fakeVel[self] and (key == "Velocity" or key == "AssemblyLinearVelocity" or key == "AssemblyAngularVelocity") then return end
			if HOOK.fakeWS[self] and (key == "WalkSpeed" or key == "JumpPower" or key == "JumpHeight") then return end
			if HOOK.fakeHealth[self] and key == "Health" then return end
		end
		return HOOK.oldNewIndex(self, key, value)
	end)
	if ok2 then HOOK.oldNewIndex = oldN end
	local ok3, oldNC = pcall(hookmetamethod, game, "__namecall", function(self, ...)
		if typeof(self) == "Instance" then
			local m = getnamecallmethod()
			if HOOK.antiKick and m == "Kick" then
				if self:IsA("Player") and self == LP then return nil end
			end
			if m == "FireServer" or m == "InvokeServer" then
				if HOOK.blocked[self] then return nil end
			end
			if HOOK.raycastBlind and not HOOK.internalCall then
				if m == "Raycast" or m == "FindPartOnRay" or m == "FindPartOnRayWithIgnoreList" or m == "FindPartOnRayWithWhitelist" then return nil end
				if m == "GetPartBoundsInRadius" or m == "GetPartBoundsInBox" or m == "GetPartsInPart" or m == "GetTouchingParts" then return {} end
			end
		end
		return HOOK.oldNamecall(self, ...)
	end)
	if ok3 then HOOK.oldNamecall = oldNC end
	HOOK.installed = true
	return true
end
function HOOK.uninstall()
	if not HOOK.installed then return end
	pcall(function() if HOOK.oldIndex then hookmetamethod(game, "__index", HOOK.oldIndex) end end)
	pcall(function() if HOOK.oldNewIndex then hookmetamethod(game, "__newindex", HOOK.oldNewIndex) end end)
	pcall(function() if HOOK.oldNamecall then hookmetamethod(game, "__namecall", HOOK.oldNamecall) end end)
	HOOK.installed = false
end
function HOOK.ensure(dt)
	HOOK.lastEnsure = (HOOK.lastEnsure or 0) + (dt or 0)
	if HOOK.lastEnsure < 2 then return end
	HOOK.lastEnsure = 0
	if not HOOK.supported() then return end
	if not HOOK.installed then pcall(HOOK.install) end
end
function HOOK.realCF(part)
	if not part then return nil end
	if not HOOK.installed or not HOOK.oldIndex then return part.CFrame end
	local ok, cf = pcall(HOOK.oldIndex, part, "CFrame")
	if ok and typeof(cf) == "CFrame" then return cf end
	return part.CFrame
end
function HOOK.realPos(part) local cf = HOOK.realCF(part); return cf and cf.Position end
function HOOK.protect(part, hum)
	if not HOOK.installed or not HOOK.oldIndex then return end
	if part then
		local ok, real = pcall(HOOK.oldIndex, part, "CFrame")
		if ok then HOOK.fakeCF[part] = real end
		HOOK.fakeVel[part] = true
	end
	if hum then HOOK.fakeWS[hum] = 16; HOOK.fakeHealth[hum] = hum.MaxHealth or 100 end
end
function HOOK.unprotect(part, hum)
	if part then HOOK.fakeCF[part] = nil; HOOK.fakeVel[part] = nil end
	if hum then HOOK.fakeWS[hum] = nil; HOOK.fakeHealth[hum] = nil end
end
function HOOK.updateFake(part, dt, maxSpeed)
	local f = HOOK.fakeCF[part]; if not f then return end
	local real = HOOK.realCF(part); if not real then return end
	HOOK.fakeCF[part] = real
	local hum = part:FindFirstChildOfClass("Humanoid")
	if hum and HOOK.fakeHealth[hum] then HOOK.fakeHealth[hum] = hum.MaxHealth or 100 end
end
function HOOK.blockRemote(r, s)
	if s == nil then s = true end
	HOOK.blocked[r] = s and true or nil
end
function HOOK.withInternal(fn, ...)
	local old = HOOK.internalCall; HOOK.internalCall = true
	local ok, r = pcall(fn, ...); HOOK.internalCall = old
	if ok then return r end
end

local GRAV = {enabled=false, conn=nil, force=nil}
function GRAV.start()
	if GRAV.conn then return end
	GRAV.enabled = true
	GRAV.conn = RS.Heartbeat:Connect(function()
		if dead then return end
		local ch = LP.Character; if not ch then return end
		local r = ch:FindFirstChild("HumanoidRootPart"); if not r then return end
		local bf = GRAV.force
		if not bf or not bf.Parent or bf.Parent ~= r then
			if bf then pcall(function() bf:Destroy() end) end
			bf = Instance.new("BodyForce")
			bf.Name = "CM_NoGravity"
			bf.Force = Vector3.new(0, r:GetMass() * workspace.Gravity, 0)
			bf.Parent = r
			GRAV.force = bf
		else
			bf.Force = Vector3.new(0, r:GetMass() * workspace.Gravity, 0)
		end
		local hum = ch:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function()
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			end)
		end
	end)
end
function GRAV.stop()
	GRAV.enabled = false
	if GRAV.conn then GRAV.conn:Disconnect(); GRAV.conn = nil end
	if GRAV.force then pcall(function() GRAV.force:Destroy() end); GRAV.force = nil end
	local ch = LP.Character
	if ch then
		local hum = ch:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function()
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			end)
		end
	end
end

do
	local guardState = {char=nil, root=nil, hum=nil, lastRealCF=nil, lastCheck=0, _pendingRollback=nil, _pendingCount=0}
	local function updateGuard()
		local ch = LP.Character
		if ch ~= guardState.char then
			guardState.char = ch
			guardState.root = ch and ch:FindFirstChild("HumanoidRootPart")
			guardState.hum = ch and ch:FindFirstChildOfClass("Humanoid")
			guardState.lastRealCF = nil
			guardState._pendingRollback = nil
			guardState._pendingCount = 0
		end
		if not guardState.root and ch then
			guardState.root = ch:FindFirstChild("HumanoidRootPart")
			guardState.hum = ch and ch:FindFirstChildOfClass("Humanoid")
		end
	end
	trk(RS.Heartbeat:Connect(function(dt)
		if dead then return end
		if St.hook then HOOK.ensure(dt) end
		updateGuard()
		local r, hum = guardState.root, guardState.hum
		if not r or not r.Parent or not hum or not hum.Parent then return end
		if St.godmode and hum.Health <= 0.01 and hum.MaxHealth > 0 then
			pcall(function() hum.Health = hum.MaxHealth end)
		end
		if St.anticframe then
			guardState.lastCheck = guardState.lastCheck + dt
			if guardState.lastCheck >= 0.15 then
				guardState.lastCheck = 0
				local real = HOOK.realCF(r)
				if real then
					local busy = tpBusyIsBusy() or (task_ and task_.cn ~= nil)
					if busy then
						guardState.lastRealCF = real
						guardState._pendingRollback = nil
						guardState._pendingCount = 0
					else
						if guardState.lastRealCF then
							local moved = (real.Position - guardState.lastRealCF.Position).Magnitude
							if moved > 150 then
								if guardState._pendingRollback then
									guardState._pendingCount = guardState._pendingCount + 1
									if guardState._pendingCount >= 2 then
										HOOK.setCF(r, guardState._pendingRollback)
										guardState._pendingRollback = nil
										guardState._pendingCount = 0
									end
								else
									guardState._pendingRollback = guardState.lastRealCF
									guardState._pendingCount = 1
								end
							else
								guardState._pendingRollback = nil
								guardState._pendingCount = 0
								guardState.lastRealCF = real
							end
						else
							guardState.lastRealCF = real
						end
					end
				end
			end
		end
	end))
end

local function parseDir(raw)
	local t = tostring(raw or ""):gsub("%s+", "")
	if t == "" then return nil end
	local m = t:match("^{%^}([%-%+]?[%d%.]+)$")
	if m then local n = tonumber(m); if n then return {dist=n, useCamera=true} end end
	m = t:match("^%^([%-%+]?[%d%.]+)$")
	if m then local n = tonumber(m); if n then return {dist=n, useCamera=false} end end
	return nil
end

local zCounter = 1000
local function nextZ() zCounter = zCounter + 1; return zCounter end
local sg = mk("ScreenGui", {Name="RBX_Gui_".._guiSfx, ResetOnSpawn=false, IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=999999})
sg.Parent = guiP()
local notifGui = mk("ScreenGui", {Name="RBX_Notif_".._guiSfx, ResetOnSpawn=false, IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=1000000})
notifGui.Parent = guiP()
if ANTI and ANTI.mark then ANTI.mark(sg); ANTI.mark(notifGui) end

local notifH = mk("Frame", {Name="NH", AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-20,1,-20), Size=UDim2.fromOffset(300,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, ZIndex=1, Parent=notifGui})
mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8), HorizontalAlignment=Enum.HorizontalAlignment.Right, VerticalAlignment=Enum.VerticalAlignment.Bottom, Parent=notifH})

local mHi = mk("Frame", {Name="MH", BackgroundColor3=Th.Acc, BackgroundTransparency=0.75, BorderSizePixel=0, ZIndex=9000, Visible=false, Parent=sg})
mk("UICorner", {CornerRadius=UDim.new(0,8), Parent=mHi})
mk("UIStroke", {Color=Th.Acc, Thickness=3, Transparency=0.1, Parent=mHi})

local UIX = {_nc = 0, drag = nil}
function UIX.notify(title, message, duration, color)
	if dead then return end
	UIX._nc = UIX._nc + 1
	local n = UIX._nc
	local card = mk("Frame", {Name="C"..n, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundColor3=Th.Sur, BackgroundTransparency=1, BorderSizePixel=0, LayoutOrder=n, ZIndex=2, Parent=notifH})
	local cs = mk("UIStroke", {Color=color or Th.Str, Thickness=1, Transparency=1, Parent=card})
	mk("UICorner", {CornerRadius=UDim.new(0,8), Parent=card})
	mk("UIPadding", {PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,10), PaddingLeft=UDim.new(0,14), PaddingRight=UDim.new(0,14), Parent=card})
	mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,3), Parent=card})
	local tL = mk("TextLabel", {Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=color or Th.Txt, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Text=title, TextTransparency=1, LayoutOrder=1, Parent=card})
	local mL = mk("TextLabel", {Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=12, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Text=message or "", TextTransparency=1, LayoutOrder=2, Parent=card})
	local fi = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Tween:Create(card, fi, {BackgroundTransparency=0}):Play()
	Tween:Create(cs, fi, {Transparency=0}):Play()
	Tween:Create(tL, fi, {TextTransparency=0}):Play()
	Tween:Create(mL, fi, {TextTransparency=0}):Play()
	task.delay(duration or 3, function()
		if dead or not card.Parent then return end
		local fo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween:Create(card, fo, {BackgroundTransparency=1}):Play()
		Tween:Create(cs, fo, {Transparency=1}):Play()
		Tween:Create(tL, fo, {TextTransparency=1}):Play()
		Tween:Create(mL, fo, {TextTransparency=1}):Play()
		task.delay(0.45, function() if not dead and card and card.Parent then card:Destroy() end end)
	end)
end
function UIX.protectGui(obj)
	if not obj then return end
	pcall(function()
		obj.AncestryChanged:Connect(function(_, parent)
			if dead then return end
			if not parent then
				task.defer(function()
					if not dead and obj then pcall(function() obj.Parent = guiP() end) end
				end)
			end
		end)
	end)
end
function UIX.showHiAt(p, s) mHi.Position=UDim2.fromOffset(p.X, p.Y); mHi.Size=UDim2.fromOffset(s.X, s.Y); mHi.Visible=true end
function UIX.hideHi() mHi.Visible = false end
function UIX.startDrag(frame, ip, opts)
	UIX.drag = {frame=frame, startMouse=ip, startPos=frame.Position, opts=opts}
	frame.ZIndex = nextZ()
	if opts and opts.onZ then opts.onZ() end
end
function UIX.stopDrag()
	if not UIX.drag then return end
	local d = UIX.drag; UIX.drag = nil; UIX.hideHi()
	if d.opts and d.opts.onEnd then pcall(d.opts.onEnd) end
end

UIX.protectGui(sg); UIX.protectGui(notifGui)
trk(UIS.InputChanged:Connect(function(input)
	if not UIX.drag or not UIX.drag.frame.Parent then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local d = input.Position - UIX.drag.startMouse
	UIX.drag.frame.Position = UDim2.new(UIX.drag.startPos.X.Scale, UIX.drag.startPos.X.Offset + d.X, UIX.drag.startPos.Y.Scale, UIX.drag.startPos.Y.Offset + d.Y)
	if UIX.drag.opts and UIX.drag.opts.onDrag then pcall(UIX.drag.opts.onDrag) end
end))
trk(UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then UIX.stopDrag() end
end))
trk(UIS.WindowFocusReleased:Connect(function() UIX.stopDrag() end))

local allHidden = false

-- ========== 摄像机模块 v57.2（第三人称跟随 + 自由旋转 + 平方刚度追赶） ==========
local CAM = {
	active = false,
	conn = nil,
	restoreJob = nil,
	savedType = nil,
	savedSubject = nil,
	smoothPos = nil,
	posVel = nil,
	focusOffset = Vector3.new(0, 2, 0),
	distance = 14,
	accumYaw = 0,
	accumPitch = 20,
	yawInputAccum = 0,
	pitchInputAccum = 0,
	fovSaved = nil,
	sens = 0.4,
}

function CAM.restore()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local subj = CAM.savedSubject
	if subj and (typeof(subj) ~= "Instance" or not subj.Parent) then subj = nil end
	if CAM.savedType then pcall(function() cam.CameraType = CAM.savedType end)
	else pcall(function() cam.CameraType = Enum.CameraType.Custom end) end
	if subj then pcall(function() cam.CameraSubject = subj end)
	else
		local ch = LP.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() cam.CameraSubject = hum end) end
	end
	if CAM.fovSaved then pcall(function() cam.FieldOfView = CAM.fovSaved end); CAM.fovSaved = nil end
	CAM.savedType = nil; CAM.savedSubject = nil
	CAM.smoothPos = nil; CAM.posVel = nil
end

function CAM.start()
	local cam = workspace.CurrentCamera
	if not cam or CAM.active then return end
	if CAM.restoreJob then pcall(function() task.cancel(CAM.restoreJob) end); CAM.restoreJob = nil end
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		CAM.savedType = cam.CameraType
		CAM.savedSubject = cam.CameraSubject
		CAM.fovSaved = cam.FieldOfView
	end
	CAM.smoothPos = cam.CFrame.Position
	CAM.posVel = Vector3.new(0, 0, 0)
	local lv = cam.CFrame.LookVector
	CAM.accumYaw = math.deg(math.atan2(-lv.X, -lv.Z))
	CAM.accumPitch = math.deg(math.asin(cl(lv.Y, -1, 1)))
	if CAM.accumPitch > 80 then CAM.accumPitch = 80 end
	if CAM.accumPitch < -80 then CAM.accumPitch = -80 end
	CAM.yawInputAccum = 0
	CAM.pitchInputAccum = 0
	CAM.active = true
	pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)

	local mouseConn = UIS.InputChanged:Connect(function(input)
		if dead or not CAM.active then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			CAM.yawInputAccum = CAM.yawInputAccum + input.Delta.X
			CAM.pitchInputAccum = CAM.pitchInputAccum + input.Delta.Y
		end
	end)
	table.insert(Conns, mouseConn)

	if CAM.conn then return end
	CAM.conn = RS.RenderStepped:Connect(function(dt)
		if dead or not CAM.active then return end
		local c = workspace.CurrentCamera
		if not c then return end
		if c.CameraType ~= Enum.CameraType.Scriptable then
			pcall(function() c.CameraType = Enum.CameraType.Scriptable end)
		end
		local ch = LP.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local charPos = HOOK.realPos(hrp) or hrp.Position

		local dX, dY = 0, 0
		if UIS.GetMouseDelta then
			local ok, d = pcall(function() return UIS:GetMouseDelta() end)
			if ok and d and (d.X ~= 0 or d.Y ~= 0) then
				dX = d.X; dY = d.Y
			end
		end
		if dX == 0 and dY == 0 then
			dX = CAM.yawInputAccum
			dY = CAM.pitchInputAccum
		end
		CAM.yawInputAccum = 0
		CAM.pitchInputAccum = 0

		if dX ~= 0 or dY ~= 0 then
			CAM.accumYaw = CAM.accumYaw - dX * CAM.sens
			CAM.accumPitch = CAM.accumPitch + dY * CAM.sens
			if CAM.accumPitch > 80 then CAM.accumPitch = 80 end
			if CAM.accumPitch < -80 then CAM.accumPitch = -80 end
			while CAM.accumYaw > 180 do CAM.accumYaw = CAM.accumYaw - 360 end
			while CAM.accumYaw < -180 do CAM.accumYaw = CAM.accumYaw + 360 end
		end

		local lookDir = CFrame.fromEulerAnglesYXZ(math.rad(CAM.accumPitch), math.rad(CAM.accumYaw), 0).LookVector
		local focus = charPos + CAM.focusOffset
		local targetPos = focus - lookDir * CAM.distance

		local posDelta = targetPos - CAM.smoothPos
		local posDist = posDelta.Magnitude
		if posDist > 500 then
			CAM.smoothPos = targetPos
			CAM.posVel = Vector3.new(0, 0, 0)
		elseif posDist > 0.005 then
			local stiffness = 80 + posDist * posDist * 0.7
			if stiffness > 14000 then stiffness = 14000 end
			local damping = 2 * math.sqrt(stiffness) * 0.9
			local sdt = math.min(dt, 1/30)
			if sdt < 1/240 then sdt = 1/240 end
			local accel = posDelta * stiffness - CAM.posVel * damping
			CAM.posVel = CAM.posVel + accel * sdt
			local maxSpd = 7000
			if CAM.posVel.Magnitude > maxSpd then CAM.posVel = CAM.posVel.Unit * maxSpd end
			CAM.smoothPos = CAM.smoothPos + CAM.posVel * sdt
		else
			CAM.posVel = CAM.posVel * 0.5
		end

		local finalCF = CFrame.lookAt(CAM.smoothPos, focus)
		pcall(function() c.CFrame = finalCF end)
	end)
end

function CAM.stop()
	if not CAM.active then return end
	CAM.active = false
	if CAM.conn then CAM.conn:Disconnect(); CAM.conn = nil end
	if CAM.restoreJob then pcall(function() task.cancel(CAM.restoreJob) end) end
	CAM.restoreJob = task.delay(0.05, function()
		CAM.restoreJob = nil
		if dead then return end
		CAM.restore()
	end)
end

function CAM.forceRestore()
	if CAM.conn then CAM.conn:Disconnect(); CAM.conn = nil end
	if CAM.restoreJob then pcall(function() task.cancel(CAM.restoreJob) end); CAM.restoreJob = nil end
	CAM.active = false
	CAM.restore()
end

-- 主面板
local main = mk("Frame", {Name="Main", AnchorPoint=Vector2.new(0,0), Position=UIState.mainPos, Size=UDim2.fromOffset(St.mainW, St.mainH), BackgroundColor3=Th.Bg, BorderSizePixel=0, Active=true, ClipsDescendants=true, ZIndex=10, Visible=UIState.mainVisible, Parent=sg})
mk("UICorner", {CornerRadius=UDim.new(0,10), Parent=main})
mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=main})

local mHdr = mk("Frame", {Name="Hdr", Size=UDim2.new(1,0,0,TITLE_H), BackgroundColor3=Th.Sur, BorderSizePixel=0, Active=true, ZIndex=11, Parent=main})
mk("UICorner", {CornerRadius=UDim.new(0,10), Parent=mHdr})
mk("TextLabel", {Size=UDim2.new(1,-84,1,0), Position=UDim2.fromOffset(14,0), BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=14, TextColor3=Th.Txt, TextXAlignment=Enum.TextXAlignment.Left, Text="坐标管理器 v"..VERSION, ZIndex=12, Parent=mHdr, Active=false})
local mMin = mk("TextButton", {Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-58,0.5,-12), BackgroundColor3=Th.Bg, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=14, TextColor3=Th.Sub, Text="—", ZIndex=12, Parent=mHdr})
mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=mMin})
local mCls = mk("TextButton", {Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-30,0.5,-12), BackgroundColor3=Th.Bg, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Err, Text="X", ZIndex=12, Parent=mHdr})
mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=mCls})

local function inRect(px, py, obj)
	local p, s = obj.AbsolutePosition, obj.AbsoluteSize
	if not p or not s then return false end
	return px >= p.X and px <= p.X+s.X and py >= p.Y and py <= p.Y+s.Y
end

trk(mHdr.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if UIX.drag then return end
	local ix, iy = input.Position.X, input.Position.Y
	if inRect(ix, iy, mMin) or inRect(ix, iy, mCls) then return end
	UIX.startDrag(main, input.Position, {
		onZ=function() mHdr.ZIndex = nextZ() end,
		onEnd=function() UIState.mainPos = main.Position; saveUIState() end,
	})
end))

local cScroll = mk("ScrollingFrame", {Name="Scroll", Size=UDim2.new(1,0,1,-TITLE_H), Position=UDim2.fromOffset(0,TITLE_H), BackgroundTransparency=1, BorderSizePixel=0, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=4, ScrollBarImageColor3=Th.Str, ZIndex=11, Parent=main})
local cInner = mk("Frame", {Name="Inner", Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, ZIndex=11, Parent=cScroll})
mk("UIListLayout", {Name="IL", FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8), Parent=cInner})
mk("UIPadding", {PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,10), PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), Parent=cInner})

local curCard = mk("Frame", {Size=UDim2.new(1,0,0,50), BackgroundColor3=Th.Sur, BorderSizePixel=0, LayoutOrder=0, Parent=cInner})
mk("UICorner", {CornerRadius=UDim.new(0,8), Parent=curCard})
mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=curCard})
mk("TextLabel", {Size=UDim2.new(1,-20,0,14), Position=UDim2.fromOffset(12,6), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=11, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="当前坐标 ("..GAME_TAG..")", Parent=curCard})
local curLbl = mk("TextLabel", {Size=UDim2.new(1,-20,0,22), Position=UDim2.fromOffset(12,22), BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=15, TextColor3=Th.Acc, TextXAlignment=Enum.TextXAlignment.Left, Text="X: --   Y: --   Z: --", Parent=curCard})
local stCard = mk("Frame", {Size=UDim2.new(1,0,0,46), BackgroundColor3=Th.Sec, BorderSizePixel=0, LayoutOrder=900, Parent=cInner})
mk("UICorner", {CornerRadius=UDim.new(0,8), Parent=stCard})
mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=stCard})
local stLbl = mk("TextLabel", {Size=UDim2.new(1,-100,1,0), Position=UDim2.fromOffset(12,0), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Text="", Parent=stCard})
local setBtn = mk("TextButton", {Size=UDim2.fromOffset(80,26), Position=UDim2.new(1,-88,0.5,-13), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Txt, Text="⚙ 设置", Parent=stCard})
mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=setBtn})
mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=setBtn})

local mRH = mk("Frame", {Name="RH", AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-4,1,-4), Size=UDim2.fromOffset(HDL,HDL), BackgroundColor3=Th.Hdl, BackgroundTransparency=0.15, BorderSizePixel=0, Active=true, ZIndex=13, Parent=main})
mk("UICorner", {CornerRadius=UDim.new(0,3), Parent=mRH})

local function refreshMainSize()
	if St.min then return end
	local il = cInner:FindFirstChild("IL"); if not il then return end
	local needH = TITLE_H + il.AbsoluteContentSize.Y + 20
	if needH < MAIN_MIN_H then needH = MAIN_MIN_H end
	if math.abs(needH - St.mainH) > 1 then
		St.mainH = needH
		main.Size = UDim2.fromOffset(St.mainW, St.mainH)
	end
end
do
	local rsz, rs, rsz0 = false, nil, nil
	trk(mRH.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		rsz = true; rs = input.Position; rsz0 = Vector2.new(main.AbsoluteSize.X, main.AbsoluteSize.Y)
	end))
	trk(UIS.InputChanged:Connect(function(input)
		if not rsz then return end
		local d = input.Position - rs
		local il = cInner:FindFirstChild("IL")
		local contentH = il and il.AbsoluteContentSize.Y or cInner.AbsoluteSize.Y
		local dynamicMax = TITLE_H + contentH + 20
		if dynamicMax < MAIN_MIN_H then dynamicMax = MAIN_MIN_H end
		local w = cl(rsz0.X + d.X, MAIN_MIN_W, MAIN_MAX_W)
		local h = cl(rsz0.Y + d.Y, MAIN_MIN_H, dynamicMax)
		main.Size = UDim2.fromOffset(w, h)
		St.mainW = w; St.mainH = h
	end))
	trk(UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			rsz = false; saveToFile()
			UIState.mainPos = main.Position; saveUIState()
		end
	end))
end

local refreshOwnerSize = {}
local function registerOwnerRefresh(c, fn) refreshOwnerSize[c] = fn end
local function unregisterOwnerRefresh(c) refreshOwnerSize[c] = nil end
local function triggerOwnerRefresh(c) local fn = c and refreshOwnerSize[c]; if fn then pcall(fn) end end
registerOwnerRefresh(cInner, refreshMainSize)

local function getMergeZoneBox(panel)
	local pp, ps = panel.AbsolutePosition, panel.AbsoluteSize
	if not pp or not ps then return nil, nil end
	local padX = ps.X * 0.12
	local topY = pp.Y + ps.Y * 0.5
	local w = ps.X + padX * 2
	local h = pp.Y + ps.Y - topY
	return Vector2.new(pp.X - padX, topY), Vector2.new(w, h)
end
local function isHdrInMergeZone(hdrObj, panel)
	if not panel or not panel.Parent then return false end
	local hp, hs = hdrObj.AbsolutePosition, hdrObj.AbsoluteSize
	local pp, ps = panel.AbsolutePosition, panel.AbsoluteSize
	if not hp or not hs or not pp or not ps then return false end
	local padX = ps.X * 0.12
	local zx1, zy1 = pp.X - padX, pp.Y + ps.Y * 0.5
	local zx2, zy2 = pp.X + ps.X + padX, pp.Y + ps.Y
	local hx1, hy1 = hp.X, hp.Y
	local hx2, hy2 = hp.X + hs.X, hp.Y + hs.Y
	return hx1 < zx2 and hx2 > zx1 and hy1 < zy2 and hy2 > zy1
end

local setPanelRef, setBodyInner = nil, nil
local allBlocks, mainBlocks = {}, {}
local orderCounter = 100

local function findOwningPanel(c)
	if not c then return nil end
	if c == cInner then return main end
	if setPanelRef and c == setBodyInner then return setPanelRef end
end
local function applyVisibility()
	main.Visible = not allHidden and UIState.mainVisible
	if setPanelRef then setPanelRef.Visible = not allHidden and UIState.setVisible end
	for _, bl in pairs(allBlocks) do
		if bl.host == "detached" and bl.frame then bl.frame.Visible = not allHidden end
	end
end

local function createBlock(cfg)
	local self = {id=cfg.id, title=cfg.title, host=cfg.host or "main", minimized=false, isMain=(cfg.host=="main"), getMergeParent=cfg.getMergeParent, _lastClick=0, detW=nil, detH=nil, _hasAdjusted=false, _detachConn=nil}
	local savedState = UIState.blockStates[cfg.id]
	if savedState then self.minimized = savedState.min == true end
	orderCounter = orderCounter + 10
	local baseZ = (self.host=="settings") and (200+math.floor(orderCounter/10)) or (30+math.floor(orderCounter/10))
	local frm = mk("Frame", {Name="B"..cfg.id, Size=UDim2.new(1,0,0,HDR_H), BackgroundColor3=Th.Sec, BorderSizePixel=0, LayoutOrder=orderCounter, Active=true, ClipsDescendants=true, ZIndex=baseZ, Parent=cfg.parent})
	mk("UICorner", {CornerRadius=UDim.new(0,8), Parent=frm})
	mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=frm})
	local hdr = mk("Frame", {Name="H", Size=UDim2.new(1,0,0,HDR_H), BackgroundColor3=Th.Sur, BorderSizePixel=0, Active=true, ZIndex=baseZ+1, Parent=frm})
	mk("UICorner", {CornerRadius=UDim.new(0,8), Parent=hdr})
	mk("TextLabel", {Size=UDim2.new(1,-50,1,0), Position=UDim2.fromOffset(12,0), BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Txt, TextXAlignment=Enum.TextXAlignment.Left, Text=cfg.title, ZIndex=baseZ+2, Parent=hdr, Active=false})
	local tgl = mk("TextButton", {Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-32,0.5,-12), BackgroundColor3=Th.Bg, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=14, TextColor3=Th.Sub, Text=self.minimized and "+" or "−", ZIndex=baseZ+2, Parent=hdr})
	mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=tgl})
	local body = mk("Frame", {Name="B", Size=UDim2.new(1,0,0,0), Position=UDim2.fromOffset(0,HDR_H), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, ZIndex=baseZ+1, Parent=frm})
	local bIL = mk("UIListLayout", {Name="IL", FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), Parent=body})
	mk("UIPadding", {PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,8), PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), Parent=body})
	self.frame, self.header, self.body, self.toggle, self.scrollFrame = frm, hdr, body, tgl, nil
	local rh = mk("Frame", {Name="RH", AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-4,1,-4), Size=UDim2.fromOffset(HDL,HDL), BackgroundColor3=Th.Hdl, BackgroundTransparency=0.15, BorderSizePixel=0, Active=true, Visible=false, ZIndex=baseZ+10, Parent=frm})
	mk("UICorner", {CornerRadius=UDim.new(0,3), Parent=rh})
	self.rh = rh
	local function updateHandle() rh.Visible = (self.host == "detached" and not self.minimized) end
	local function refreshHeight()
		if self.host ~= "main" and self.host ~= "settings" then return end
		if self.minimized then frm.Size = UDim2.new(1,0,0,HDR_H)
		else local bh = body.AbsoluteSize.Y; if bh and bh > 0 then frm.Size = UDim2.new(1,0,0,HDR_H+bh) end end
	end
	trk(body:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshHeight))
	function self:applyMinimized()
		self.body.Visible = not self.minimized
		self.toggle.Text = self.minimized and "+" or "−"
		if self.host == "main" or self.host == "settings" then refreshHeight()
		else
			if self.minimized then frm.Size = UDim2.fromOffset(frm.AbsoluteSize.X, HDR_H)
			else
				local h = (self.detH and self.detH > HDR_H) and self.detH or (HDR_H + body.AbsoluteSize.Y + 20)
				frm.Size = UDim2.fromOffset(frm.AbsoluteSize.X, h)
			end
		end
		updateHandle()
	end
	trk(tgl.MouseButton1Click:Connect(function()
		self.minimized = not self.minimized
		self:applyMinimized()
		local bs = UIState.blockStates[self.id] or {}
		bs.min = self.minimized
		UIState.blockStates[self.id] = bs
		saveUIState()
	end))
	if cfg.build then cfg.build(body, self) end
	task.defer(refreshHeight)
	do
		local rsz, rs, rsz0 = false, nil, nil
		trk(rh.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			rsz = true; rs = input.Position; rsz0 = Vector2.new(frm.AbsoluteSize.X, frm.AbsoluteSize.Y)
		end))
		trk(UIS.InputChanged:Connect(function(input)
			if not rsz then return end
			local d = input.Position - rs
			local contentH = bIL.AbsoluteContentSize.Y
			local dynamicMax = HDR_H + contentH + 20
			if dynamicMax < BLK_MIN_H then dynamicMax = BLK_MIN_H end
			local w = cl(rsz0.X + d.X, BLK_MIN_W, BLK_MAX_W)
			local h = cl(rsz0.Y + d.Y, BLK_MIN_H, dynamicMax)
			frm.Size = UDim2.fromOffset(w, h)
			self.detW = w; self.detH = h
		end))
		trk(UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				rsz = false; self._hasAdjusted = true
				St.blockSizes[self.id] = {w=self.detW, h=self.detH}
				saveToFile()
			end
		end))
	end
	function self:detach()
		if self.host == "detached" then return end
		local ap, asz = frm.AbsolutePosition, frm.AbsoluteSize
		local curW = asz.X; if curW < 10 then curW = 300 end
		local contentH = body.AbsoluteSize.Y; if contentH < 10 then contentH = 30 end
		local fW, fH
		if self._hasAdjusted and self.detW and self.detH then fW, fH = self.detW, self.detH
		else fW = curW; fH = HDR_H + contentH + 20; self.detW = fW; self.detH = fH end
		local oldP = frm.Parent
		frm.AutomaticSize = Enum.AutomaticSize.None
		if self.minimized then frm.Size = UDim2.fromOffset(fW, HDR_H) else frm.Size = UDim2.fromOffset(fW, fH) end
		frm.Parent = sg
		frm.Position = UDim2.fromOffset(ap.X, ap.Y)
		local sf = mk("ScrollingFrame", {Name="SF", Size=UDim2.new(1,0,1,-HDR_H), Position=UDim2.fromOffset(0,HDR_H), BackgroundTransparency=1, BorderSizePixel=0, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=4, ScrollBarImageColor3=Th.Str, ZIndex=baseZ+1, Parent=frm})
		body.Parent = sf; body.Position = UDim2.fromOffset(0,0); body.Size = UDim2.new(1,0,0,0)
		self.scrollFrame = sf
		hdr.Position = UDim2.fromOffset(0,0); hdr.Size = UDim2.new(1,0,0,HDR_H)
		if self._detachConn then pcall(function() self._detachConn:Disconnect() end) end
		self._detachConn = body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if self.host ~= "detached" or self.minimized or self._hasAdjusted then return end
			local bh = body.AbsoluteSize.Y
			if bh > 0 then frm.Size = UDim2.fromOffset(frm.AbsoluteSize.X, HDR_H+bh+20) end
		end)
		self.host = "detached"; updateHandle(); applyVisibility()
		task.defer(function() triggerOwnerRefresh(oldP) end)
		local bs = UIState.blockStates[self.id] or {}
		bs.detach = true
		UIState.blockStates[self.id] = bs
		saveUIState()
	end
	function self:attach(container)
		if self.host ~= "detached" then return end
		if self._detachConn then pcall(function() self._detachConn:Disconnect() end); self._detachConn = nil end
		if self.scrollFrame then body.Parent = frm; self.scrollFrame:Destroy(); self.scrollFrame = nil end
		frm.Parent = container; frm.Position = UDim2.fromOffset(0,0)
		frm.AutomaticSize = Enum.AutomaticSize.None
		hdr.Position = UDim2.fromOffset(0,0); hdr.Size = UDim2.new(1,0,0,HDR_H)
		body.Position = UDim2.fromOffset(0,HDR_H); body.Size = UDim2.new(1,0,0,0)
		self.host = (container == setBodyInner) and "settings" or "main"
		updateHandle()
		task.defer(function() updateHandle(); refreshHeight() end)
		self:applyMinimized()
		task.defer(function() triggerOwnerRefresh(container) end)
		local bs = UIState.blockStates[self.id] or {}
		bs.detach = false
		UIState.blockStates[self.id] = bs
		saveUIState()
	end
	trk(hdr.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if UIX.drag then return end
		local ix, iy = input.Position.X, input.Position.Y
		if inRect(ix, iy, tgl) then return end
		local now = tick(); local isDbl = (now - self._lastClick) < (DBL_MS/1000); self._lastClick = now
		local opts = {
			onZ = function() hdr.ZIndex = nextZ(); body.ZIndex = nextZ() end,
			onDrag = function()
				if self.host ~= "detached" then UIX.hideHi(); return end
				local c = self.getMergeParent and self.getMergeParent()
				local panel = findOwningPanel(c)
				if not panel or not panel.Parent then UIX.hideHi(); return end
				if isHdrInMergeZone(hdr, panel) then
					local p, s = getMergeZoneBox(panel)
					if p and s then UIX.showHiAt(p, s) else UIX.hideHi() end
				else UIX.hideHi() end
			end,
			onEnd = function()
				UIX.hideHi()
				if self.host ~= "detached" then
					local bs = UIState.blockStates[self.id] or {}
					bs.detPos = frm.Position
					UIState.blockStates[self.id] = bs
					saveUIState()
					return
				end
				local c = self.getMergeParent and self.getMergeParent()
				local panel = findOwningPanel(c)
				if not panel or not panel.Parent then return end
				if isHdrInMergeZone(hdr, panel) and c then self:attach(c) end
			end,
		}
		if isDbl and self.host ~= "detached" then
			self._lastClick = 0
			self:detach()
			UIX.startDrag(frm, input.Position, opts)
		else
			UIX.startDrag(frm, input.Position, opts)
		end
	end))
	allBlocks[cfg.id] = self
	if self.isMain then mainBlocks[cfg.id] = self end
	if self.minimized and self.host == "main" then
		task.defer(function() pcall(function() self:applyMinimized() end) end)
	end
	return self
end

local UI = {}

createBlock({id="global", title="全局设置", host="main", parent=cInner,
	getMergeParent=function() return cInner end,
	build=function(bd, self)
		local row = mk("Frame", {Size=UDim2.new(1,0,0,26), BackgroundTransparency=1, LayoutOrder=1, Parent=bd})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), VerticalAlignment=Enum.VerticalAlignment.Center, Parent=row})
		mk("TextLabel", {Size=UDim2.new(0,52,1,0), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=12, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="传送模式", LayoutOrder=1, Parent=row})
		local sm = mk("TextButton", {Size=UDim2.new(0.5,-29,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Sub, Text="平滑", LayoutOrder=2, Parent=row})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=sm}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=sm})
		local tp = mk("TextButton", {Size=UDim2.new(0.5,-29,1,0), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Color3.fromRGB(255,255,255), Text="瞬移", LayoutOrder=3, Parent=row})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=tp}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=tp})
		UI.smBtn, UI.tpBtn = sm, tp
		local sr = mk("Frame", {Size=UDim2.new(1,0,0,26), BackgroundTransparency=1, LayoutOrder=2, Parent=bd})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), VerticalAlignment=Enum.VerticalAlignment.Center, Parent=sr})
		mk("TextLabel", {Size=UDim2.new(0,52,1,0), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=12, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="速度", LayoutOrder=1, Parent=sr})
		local sb = mk("TextBox", {Size=UDim2.new(1,-52-6-66,1,0), BackgroundColor3=Th.Bg, BorderSizePixel=0, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Txt, Text=tostring(St.speed), ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Center, LayoutOrder=2, Parent=sr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=sb}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=sb})
		mk("TextLabel", {Size=UDim2.new(0,66,1,0), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=11, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="studs/s", LayoutOrder=3, Parent=sr})
		UI.spdBox = sb
		local gr = mk("Frame", {Size=UDim2.new(1,0,0,26), BackgroundTransparency=1, LayoutOrder=3, Parent=bd})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), VerticalAlignment=Enum.VerticalAlignment.Center, Parent=gr})
		mk("TextLabel", {Size=UDim2.new(0,52,1,0), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=12, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="无重力", LayoutOrder=1, Parent=gr})
		local gOn = mk("TextButton", {Size=UDim2.new(0.5,-29,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Txt, Text="开启", LayoutOrder=2, Parent=gr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=gOn}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=gOn})
		local gOff = mk("TextButton", {Size=UDim2.new(0.5,-29,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Txt, Text="关闭", LayoutOrder=3, Parent=gr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=gOff}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=gOff})
		UI.gOn, UI.gOff = gOn, gOff
	end})

createBlock({id="manual", title="手动输入", host="main", parent=cInner,
	getMergeParent=function() return cInner end,
	build=function(bd, self)
		local ir = mk("Frame", {Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, LayoutOrder=1, Parent=bd})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), VerticalAlignment=Enum.VerticalAlignment.Center, Parent=ir})
		local ins = {}
		for i, ax in ipairs(AXES) do
			local up = ax:upper()
			local b = mk("TextBox", {Name=up.."In", Size=UDim2.new(1/3,-4,1,0), BackgroundColor3=Th.Bg, BorderSizePixel=0, Font=Enum.Font.Gotham, TextSize=13, TextColor3=Th.Txt, PlaceholderText=up, PlaceholderColor3=Color3.fromRGB(92,92,108), Text=St.inputs[ax] or "", ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Center, LayoutOrder=i, Parent=ir})
			mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=b}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=b})
			ins[ax] = b
			trk(b:GetPropertyChangedSignal("Text"):Connect(function() St.inputs[ax] = b.Text end))
		end
		UI.ins = ins
		mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="空=当前  ~n=相对  ^n=面朝  {^}n=相机  #表达式", LayoutOrder=2, Parent=bd})
		local br = mk("Frame", {Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, LayoutOrder=3, Parent=bd})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), Parent=br})
		local tp = mk("TextButton", {Size=UDim2.new(0.5,-3,1,0), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Color3.fromRGB(255,255,255), Text="传送", LayoutOrder=1, Parent=br})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=tp})
		local lp = mk("TextButton", {Size=UDim2.new(0.5,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Txt, Text="循环传送", LayoutOrder=2, Parent=br})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=lp}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=lp})
		UI.mTp, UI.mLp = tp, lp
	end})

createBlock({id="list", title="坐标列表", host="main", parent=cInner,
	getMergeParent=function() return cInner end,
	build=function(bd, self)
		local tr = mk("Frame", {Size=UDim2.new(1,0,0,26), BackgroundTransparency=1, LayoutOrder=1, Parent=bd})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), Parent=tr})
		local sv = mk("TextButton", {Size=UDim2.new(1/3,-4,1,0), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=false, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Color3.fromRGB(255,255,255), Text="保存坐标", LayoutOrder=1, Parent=tr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=sv})
		local so = mk("TextButton", {Size=UDim2.new(1/3,-4,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Txt, Text=St.asc and "正序" or "倒序", LayoutOrder=2, Parent=tr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=so}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=so})
		local ad = mk("TextButton", {Size=UDim2.new(1/3,-4,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Txt, Text="高级选择", LayoutOrder=3, Parent=tr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=ad}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=ad})
		UI.svBtn, UI.soBtn, UI.adBtn = sv, so, ad

		local ur = mk("Frame", {Size=UDim2.new(1,0,0,26), BackgroundTransparency=1, LayoutOrder=2, Parent=bd})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), Parent=ur})
		local undo = mk("TextButton", {Size=UDim2.new(0.5,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Txt, Text="↶ 撤回", LayoutOrder=1, Parent=ur})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=undo}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=undo})
		local redo = mk("TextButton", {Size=UDim2.new(0.5,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Txt, Text="↷ 取消撤回", LayoutOrder=2, Parent=ur})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=redo}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=redo})
		UI.undoBtn, UI.redoBtn = undo, redo

		local ap = mk("Frame", {Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundColor3=Th.Bg, BorderSizePixel=0, LayoutOrder=3, Visible=false, Parent=bd})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=ap}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=ap})
		mk("UIPadding", {PaddingTop=UDim.new(0,6), PaddingBottom=UDim.new(0,6), PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6), Parent=ap})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=ap})
		local mb = mk("TextButton", {Size=UDim2.new(1,0,0,24), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Th.Txt, Text="多选模式：关", LayoutOrder=1, Parent=ap})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=mb}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=mb})
		UI.mulBtn, UI.advP = mb, ap
		local ar = mk("Frame", {Size=UDim2.new(1,0,0,24), BackgroundTransparency=1, LayoutOrder=2, Parent=ap})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=ar})
		local sa = mk("TextButton", {Size=UDim2.new(0.5,-2,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text="全选", LayoutOrder=1, Parent=ar})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=sa})
		local iv = mk("TextButton", {Size=UDim2.new(0.5,-2,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text="反选", LayoutOrder=2, Parent=ar})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=iv})
		UI.saBtn, UI.ivBtn = sa, iv

		local ls = mk("ScrollingFrame", {Size=UDim2.new(1,0,0,130), BackgroundColor3=Th.Bg, BorderSizePixel=0, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=4, ScrollBarImageColor3=Th.Str, LayoutOrder=4, Parent=bd})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=ls}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=ls})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=ls})
		mk("UIPadding", {PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,4), PaddingLeft=UDim.new(0,4), PaddingRight=UDim.new(0,4), Parent=ls})
		UI.lScroll = ls

		local lr = mk("Frame", {Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=5, Parent=bd})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=lr})
		local tb = mk("TextButton", {Size=UDim2.new(0.25,-3,1,0), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Color3.fromRGB(255,255,255), Text="传送", LayoutOrder=1, Parent=lr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=tb})
		local lb = mk("TextButton", {Size=UDim2.new(0.25,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text="循环", LayoutOrder=2, Parent=lr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=lb}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=lb})
		local cb = mk("TextButton", {Size=UDim2.new(0.25,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text="复制", LayoutOrder=3, Parent=lr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=cb}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=cb})
		local db = mk("TextButton", {Size=UDim2.new(0.25,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Err, Text="删除", LayoutOrder=4, Parent=lr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=db}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=db})
		UI.lTp, UI.lLp, UI.lCp, UI.lDl = tb, lb, cb, db

		local holdBar = mk("Frame", {Size=UDim2.new(1,0,0,3), Position=UDim2.fromOffset(0,0), BackgroundColor3=Th.Ok, BackgroundTransparency=0.7, BorderSizePixel=0, ZIndex=5, Visible=false, Parent=sv})
		mk("UICorner", {CornerRadius=UDim.new(0,2), Parent=holdBar})
		UI.svHoldBar = holdBar
	end})

print("[" .. SCRIPT_ID .. "] 主面板已创建")

-- 业务逻辑辅助
local statLast = { msg = "", color = nil, t = 0 }
local function setStat(m, c)
	if dead then return end
	local now = os.clock()
	if m == statLast.msg and c == statLast.color and (now - statLast.t) < 0.08 then return end
	statLast.msg = m; statLast.color = c; statLast.t = now
	stLbl.Text = m
	stLbl.TextColor3 = c or Th.Sub
end
local function getPos()
	local ch = LP.Character; if not ch then return nil end
	local r = ch:FindFirstChild("HumanoidRootPart")
	if r then local p = HOOK.realPos(r); if p then return p end; return r.Position end
	local ok, p = pcall(function() return ch:GetPivot().Position end)
	if ok and p then return p end
end
local function rp(part) if not part then return nil end local p = HOOK.realPos(part); return p or part.Position end
local function realCF(part) if not part then return nil end local cf = HOOK.realCF(part); return cf or part.CFrame end
local function parseAx(raw, cur)
	local t = tostring(raw or ""):gsub("^%s+",""):gsub("%s+$","")
	if t == "" then return cur, nil end
	if t:sub(1,1) == "~" then
		local b = t:sub(2); if b == "" then return cur, nil end
		local n = tonumber(b); if not n then return nil, "相对无效" end
		return cur + n, nil
	end
	local n = tonumber(t); if not n then return nil, "数值无效" end
	return n, nil
end
local function getTgt(cur)
	for _, ax in ipairs(AXES) do
		local b = UI.ins[ax]
		if b then
			local d = parseDir(b.Text)
			if d then
				local ch = LP.Character
				local rpp = ch and ch:FindFirstChild("HumanoidRootPart")
				if not rpp then return nil, "角色未加载" end
				local dir
				if d.useCamera then
					local cam = workspace.CurrentCamera; if not cam then return nil, "无相机" end
					dir = cam.CFrame.LookVector
				else
					local rcf = realCF(rpp); local lv = rcf.LookVector
					dir = Vector3.new(lv.X, 0, lv.Z)
					if dir.Magnitude < 0.01 then dir = Vector3.new(0,0,-1) end
					dir = dir.Unit
				end
				local base = rp(rpp) or rpp.Position
				return base + dir * d.dist, nil
			end
		end
	end
	local r = {}
	for _, ax in ipairs(AXES) do
		local v, e = parseAx(UI.ins[ax].Text, cur[ax:upper()])
		if not v then return nil, string.format("%s轴：%s", ax:upper(), e) end
		r[ax] = v
	end
	return Vector3.new(r.x, r.y, r.z), nil
end
local function resolveHash(ax)
	local b = UI.ins[ax]; if not b then return false end
	local t = tostring(b.Text or ""):gsub("%s+", "")
	if t:sub(1,1) ~= "#" then return false end
	local c = getPos(); if not c then return true end
	local v = c[ax:upper()]
	local body = t:sub(2)
	if body == "" then b.Text = string.format("%.2f", v); return true end
	if body:match("^[%+%-%*/]") then body = "cur" .. body end
	local result = evalMathExpr(body, v)
	if result then b.Text = string.format("%.2f", result) else b.Text = string.format("%.2f", v) end
	return true
end

local UNDO = {}
function UNDO.snap()
	local t = {}
	for _, v in ipairs(St.saved) do
		table.insert(t, {id=v.id, x=v.x, y=v.y, z=v.z, note=v.note or ""})
	end
	return t
end
function UNDO.push()
	local snap = UNDO.snap()
	table.insert(St.undoStack, snap)
	if #St.undoStack > UNDO_MAX then table.remove(St.undoStack, 1) end
	St.redoStack = {}
end
function UNDO.apply(snap)
	if type(snap) ~= "table" then return end
	St.saved = {}
	for _, v in ipairs(snap) do
		table.insert(St.saved, {id=v.id, x=v.x, y=v.y, z=v.z, note=v.note or ""})
	end
	St.sel = {}
end
function UNDO.undo()
	if #St.undoStack == 0 then setStat("无可撤回", Th.Warn); return false end
	local cur = UNDO.snap()
	table.insert(St.redoStack, cur)
	if #St.redoStack > UNDO_MAX then table.remove(St.redoStack, 1) end
	local snap = table.remove(St.undoStack)
	UNDO.apply(snap)
	saveToFile()
	return true
end
function UNDO.redo()
	if #St.redoStack == 0 then setStat("无可取消撤回", Th.Warn); return false end
	local cur = UNDO.snap()
	table.insert(St.undoStack, cur)
	if #St.undoStack > UNDO_MAX then table.remove(St.undoStack, 1) end
	local snap = table.remove(St.redoStack)
	UNDO.apply(snap)
	saveToFile()
	return true
end

-- noclip v57.2（持续强制 + 属性变更修复）
local noclipMgr = {conn=nil, recorded={}, propConns={}}
local function recordPart(p, hard)
	if noclipMgr.recorded[p] then
		pcall(function() p.CanCollide = false end)
		if hard then pcall(function() p.CanTouch = false end) end
		return
	end
	local rec = {cc = p.CanCollide, ct = p.CanTouch}
	noclipMgr.recorded[p] = rec
	pcall(function()
		p.CanCollide = false
		if hard then p.CanTouch = false end
	end)
	local conn = p:GetPropertyChangedSignal("CanCollide"):Connect(function()
		if dead then return end
		if St.noclip ~= "off" and p.CanCollide then
			pcall(function() p.CanCollide = false end)
		end
	end)
	noclipMgr.propConns[p] = conn
end
local function noclipApplyToChar(ch)
	if not ch or St.noclip == "off" then return end
	local hard = (St.noclip == "all")
	if St.noclip == "persistent" or St.noclip == "all" then
		for _, p in ipairs(ch:GetDescendants()) do
			if p:IsA("BasePart") then
				recordPart(p, hard)
				if p.CanCollide then pcall(function() p.CanCollide = false end) end
				if hard and p.CanTouch then pcall(function() p.CanTouch = false end) end
			end
		end
	elseif St.noclip == "basic" then
		local r = ch:FindFirstChild("HumanoidRootPart")
		if r then
			recordPart(r, false)
			if r.CanCollide then pcall(function() r.CanCollide = false end) end
		end
	end
end
function noclipMgr.start()
	if noclipMgr.conn then return end
	noclipMgr.conn = RS.Heartbeat:Connect(function()
		if dead then return end
		if St.noclip == "off" then return end
		noclipApplyToChar(LP.Character)
	end)
end
function noclipMgr.stop()
	if noclipMgr.conn then noclipMgr.conn:Disconnect(); noclipMgr.conn = nil end
	for p, conn in pairs(noclipMgr.propConns) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(noclipMgr.propConns)
	for p, d in pairs(noclipMgr.recorded) do
		if p and p.Parent then
			pcall(function() p.CanCollide = d.cc; p.CanTouch = d.ct end)
		end
	end
	table.clear(noclipMgr.recorded)
end
local task_
local uLoop
local function cancelTask()
	if task_ and task_.stop then pcall(task_.stop) end
	task_ = nil
	INTERRUPT.flag = false
	CAM.forceRestore()
	tpBusyMark(1.5)
	if uLoop then uLoop() end
end
local function isLp() return task_ and task_.loop == true end

local function buildState(tgt, loop, src, ch, r, hum, fin, rst)
	local S = {
		tgt=tgt, loop=loop, src=src, ch=ch, r=r, hum=hum, fin=fin, rst=rst,
		startTime=os.clock(), lastDirH=nil, faceBlend=0,
		curvePhase=math.random()*math.pi*2, zigPhase=math.random()*math.pi*2,
		pulseTimer=0, pulseOn=true, jitterSeed=math.random()*1000,
		lagTimer=0, lagFreeze=0,
		origWalkSpeed=hum and hum.WalkSpeed or 16, origJumpPower=hum and hum.JumpPower or 50,
		rayTimer=0, done=false, faceMove=false,
		startPos=rp(r) or r.Position, initialDist=0,
		pathDir=nil, pathPerp=nil, bezierAmp=0,
		_stuckCount=0, _lastCheckTime=0, _lastCheckPos=rp(r) or r.Position,
		_uiTimer=0,
	}
	S.initialDist = (tgt - S.startPos).Magnitude
	if St.path == "bezier" and S.initialDist > 1 then
		local d = tgt - S.startPos
		local dH = Vector3.new(d.X, 0, d.Z)
		if dH.Magnitude > 0.01 then
			S.pathDir = dH.Unit
			S.pathPerp = Vector3.new(-S.pathDir.Z, 0, S.pathDir.X)
			S.bezierAmp = math.min(S.initialDist * 0.2, 25)
		end
	end
	return S
end

local function restoreState(S, r, hum)
	if S.bv then pcall(function() S.bv:Destroy() end); S.bv = nil end
	if S._gravComp then pcall(function() S._gravComp:Destroy() end); S._gravComp = nil end
	if hum then
		pcall(function()
			if S.origWalkSpeed then hum.WalkSpeed = S.origWalkSpeed end
			if S.origJumpPower then hum.JumpPower = S.origJumpPower end
			hum.PlatformStand = false
			hum:Move(HOOK.V3ZERO, false)
		end)
	end
	if r and r.Parent then
		HOOK.setVel(r, HOOK.V3ZERO)
		HOOK.setAngVel(r, HOOK.V3ZERO)
	end
end

local function tickProgress(S, dt, tag)
	S._uiTimer = (S._uiTimer or 0) + dt
	if S._uiTimer < 0.1 then return end
	S._uiTimer = 0
	local r = S.r
	if not r or not r.Parent then return end
	local p = rp(r)
	if not p then return end
	local d = (S.tgt - p).Magnitude
	setStat(string.format("%s 剩余 %.1f → (%.1f, %.1f, %.1f)", tag or "传送中", d, S.tgt.X, S.tgt.Y, S.tgt.Z), Th.Acc)
end

local STEP = {}
local ALIGN = {ap=nil, att=nil, target=nil}
local function cleanAlign()
	if ALIGN.ap then pcall(function() ALIGN.ap:Destroy() end); ALIGN.ap = nil end
	if ALIGN.att then pcall(function() ALIGN.att:Destroy() end); ALIGN.att = nil end
	ALIGN.target = nil
end
STEP.cleanAlign = cleanAlign

local _netInited = false
local function _netInit()
	if _netInited then return end
	_netInited = true
	if not HOOK.supported() then return end
	HOOK.install()
	local patterns = {"anticheat","anti_cheat","ac_","heartbeat","ping","checkposition","positioncheck","velocitycheck","speedcheck","antiteleport","antifly","antinoclip","accheck"}
	task.spawn(function()
		local roots = {game:GetService("ReplicatedStorage"), game:GetService("ReplicatedFirst"), LP:FindFirstChildOfClass("PlayerScripts"), LP:FindFirstChildOfClass("PlayerGui")}
		for _, root in ipairs(roots) do
			if root then
				for _, d in ipairs(root:GetDescendants()) do
					if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
						local lname = d.Name:lower()
						for _, p in ipairs(patterns) do
							if lname:find(p, 1, true) then
								HOOK.blockRemote(d, true)
								if ANTI and ANTI.blockRemote then ANTI.blockRemote(d) end
								break
							end
						end
					end
				end
			end
		end
	end)
end

STEP.walk = function(S, dt)
	tpBusyMark(0.5)
	local r, tgt = S.r, S.tgt
	if not r or not r.Parent then return end
	tickProgress(S, dt, "走路")
	local hum = S.hum; if not hum or not hum.Parent then return end
	local pos = rp(r)
	local diff = tgt - pos
	local horizDiff = Vector3.new(diff.X, 0, diff.Z)
	local horizDist = horizDiff.Magnitude
	local vertDist = diff.Y
	if not GRAV.enabled and not S.bv and math.abs(vertDist) > 8 then
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(0, math.huge, 0); bv.P = 2000
		bv.Velocity = Vector3.new(0, math.sign(vertDist) * math.min(math.abs(vertDist)*3, 300), 0)
		bv.Parent = r; S.bv = bv
	end
	if S.bv then
		if math.abs(vertDist) < 5 then S.bv:Destroy(); S.bv = nil
		else S.bv.Velocity = Vector3.new(0, math.sign(vertDist) * math.min(math.abs(vertDist)*3, 300), 0) end
	end
	if S._fastMode and hum.WalkSpeed < 300 then HOOK.setHum(hum, "WalkSpeed", 200) end
	if horizDist > 3 then pcall(function() hum:Move(horizDiff.Unit, false) end) else pcall(function() hum:Move(HOOK.V3ZERO, false) end) end
	S._lastCheckTime = (S._lastCheckTime or 0) + dt
	if S._lastCheckTime >= 0.5 then
		local moved = (pos - (S._lastCheckPos or pos)).Magnitude
		S._lastCheckPos = pos; S._lastCheckTime = 0
		if (horizDist > 5 or math.abs(vertDist) > 5) and moved < 0.3 then
			S._stuckCount = (S._stuckCount or 0) + 1
			if S._stuckCount >= 6 then
				if S.bv then pcall(function() S.bv:Destroy() end); S.bv = nil end
				local cf = realCF(r); local rotPart = cf - cf.Position
				HOOK.setCF(r, CFrame.new(tgt) * rotPart)
				if not S.loop then S.fin(string.format("已到达(回退) X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
				return true
			end
		else S._stuckCount = 0 end
	end
	if horizDist < 3 and math.abs(vertDist) < 5 then
		if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
		return true
	end
	return false
end

local function _stepCFrame(S, dt, mode)
	tpBusyMark(0.6)
	local r, tgt = S.r, S.tgt
	if not r or not r.Parent then return end
	tickProgress(S, dt, mode == "stealth" and "隐蔽" or (mode == "pulse" and "脉冲" or (mode == "jitter" and "抖动" or (mode == "zigzag" and "之字" or "混合"))))
	local ch = S.ch
	local pos = rp(r)
	local actualDist = (tgt - pos).Magnitude
	local curCF = realCF(r)
	local rotPart = curCF - curCF.Position
	if actualDist <= 1 then
		HOOK.setCF(r, CFrame.new(tgt) * rotPart)
		if mode == "stealth" or mode == "jitter" then HOOK.setAngVel(r, HOOK.V3ZERO) end
		if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
		return true
	end
	local currentTgt = tgt
	if S.pathPerp and S.initialDist > 0 then
		local alongDist = (pos - S.startPos):Dot(S.pathDir)
		local progress = cl(alongDist / S.initialDist, 0, 1)
		local bump = math.sin(progress * math.pi)
		currentTgt = tgt + S.pathPerp * bump * S.bezierAmp
	end
	local diff = currentTgt - pos
	local dist = diff.Magnitude
	if dist < 0.001 then
		if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
		return true
	end
	local speedMul = 1
	if mode == "stealth" and not GRAV.enabled then
		local elapsed = os.clock() - S.startTime
		local easeIn = 0.12
		if elapsed < easeIn then speedMul = elapsed / easeIn end
		local easeOutDist = math.max(2, 0.15 * St.speed)
		if actualDist < easeOutDist then speedMul = math.min(speedMul, actualDist / easeOutDist) end
		if speedMul < 0.1 then speedMul = 0.1 end
	end
	local boost = S._fastMode and 3 or 1
	local speed = math.max(1, St.speed) * boost
	local mv = speed * dt * speedMul
	if mode == "stealth" then
		local maxStep = (St.stealthMaxStep or 18) * boost
		if mv > maxStep then mv = maxStep end
		mv = mv * (1 + (math.random()-0.5)*0.06)
		if mv < 0 then mv = 0 end
	elseif mode == "jitter" then
		mv = mv * (1 + (math.random()-0.5)*0.06)
	elseif mode == "pulse" then
		S.pulseTimer = S.pulseTimer + dt
		if S.pulseOn then
			if S.pulseTimer >= 0.45 then S.pulseOn = false; S.pulseTimer = 0 end
		else
			mv = 0
			if S.pulseTimer >= 0.15 then S.pulseOn = true; S.pulseTimer = 0 end
		end
	end
	if mv >= dist then
		HOOK.setCF(r, CFrame.new(currentTgt) * rotPart)
		if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
		return true
	end
	if mv <= 0 then return false end
	local dir = diff.Unit
	local offset = HOOK.V3ZERO
	if mode == "stealth" then
		S.curvePhase = S.curvePhase + dt * 1.2
		local perp = Vector3.new(-diff.Z, 0, diff.X)
		if perp.Magnitude > 0.01 then offset = perp.Unit * math.sin(S.curvePhase) * 0.008 * mv end
	elseif mode == "zigzag" then
		S.zigPhase = S.zigPhase + dt * 4
		local perp = Vector3.new(-diff.Z, 0, diff.X)
		if perp.Magnitude > 0.01 then offset = perp.Unit * math.sin(S.zigPhase) * 0.3 end
	end
	local np = pos + dir * mv + offset
	if (mode == "stealth" or mode == "zigzag") and ch and not GRAV.enabled then
		S.rayTimer = S.rayTimer + dt
		if S.rayTimer >= 0.05 then
			S.rayTimer = 0
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = {ch}
			params.FilterType = Enum.RaycastFilterType.Exclude
			local res = HOOK.withInternal(function()
				return workspace:Raycast(np + Vector3.new(0,8,0), Vector3.new(0,-160,0), params)
			end)
			if res then
				local dY = np.Y - res.Position.Y
				if dY > -5 and dY < 10 then np = Vector3.new(np.X, res.Position.Y + 3, np.Z) end
			end
		end
	end
	local finalCF
	if S.faceMove then
		local dirH = Vector3.new(dir.X, 0, dir.Z)
		if dirH.Magnitude > 0.01 then
			if not S.lastDirH then S.lastDirH = dirH.Unit; S.faceBlend = 0
			else
				S.faceBlend = S.faceBlend + (1 - S.faceBlend) * math.min(dt*8, 1)
				local bl = S.lastDirH:Lerp(dirH.Unit, S.faceBlend)
				if bl.Magnitude > 0.01 then S.lastDirH = bl.Unit else S.lastDirH = dirH.Unit end
			end
			finalCF = CFrame.lookAt(np, np + S.lastDirH)
		else finalCF = CFrame.new(np) * rotPart end
	else finalCF = CFrame.new(np) * rotPart end
	HOOK.setCF(r, finalCF)
	if not S.pathPerp then
		local offsetV = rp(r) - pos
		local toT = tgt - pos
		local distB = toT.Magnitude
		if offsetV.Magnitude > 0.001 and distB > 0.05 then
			if offsetV:Dot(toT.Unit) > distB then
				HOOK.setCF(r, CFrame.new(tgt) * rotPart)
				if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
				return true
			end
		end
	end
	if mode == "stealth" or mode == "jitter" or mode == "zigzag" then
		HOOK.setAngVel(r, HOOK.V3ZERO)
	end
	return false
end

STEP.cframe = _stepCFrame
STEP.hybrid = function(s, dt) return _stepCFrame(s, dt, "hybrid") end
STEP.stealth = function(s, dt) return _stepCFrame(s, dt, "stealth") end
STEP.jitter = function(s, dt) return _stepCFrame(s, dt, "jitter") end
STEP.pulse = function(s, dt) return _stepCFrame(s, dt, "pulse") end
STEP.zigzag = function(s, dt) return _stepCFrame(s, dt, "zigzag") end

STEP.anim = function(S, dt)
	tpBusyMark(0.6)
	local r, tgt = S.r, S.tgt
	if not r or not r.Parent then return end
	tickProgress(S, dt, "动画")
	local hum = S.hum
	if hum and hum.Parent then
		local cur = hum:GetState()
		if cur ~= Enum.HumanoidStateType.Running and cur ~= Enum.HumanoidStateType.Jumping then
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
		end
		local pos = rp(r)
		local dir = tgt - pos
		local dirH = Vector3.new(dir.X, 0, dir.Z)
		if dirH.Magnitude > 0.01 then pcall(function() hum.MoveDirection = dirH.Unit end) end
		if hum.WalkSpeed > 100 or hum.WalkSpeed < 5 then HOOK.setHum(hum, "WalkSpeed", 16) end
	end
	return _stepCFrame(S, dt, "hybrid")
end

STEP.phys = function(S, dt)
	tpBusyMark(0.6)
	local r, tgt = S.r, S.tgt
	if not r or not r.Parent then return end
	tickProgress(S, dt, "力推")
	local pos = rp(r)
	local diff = tgt - pos
	local dist = diff.Magnitude
	if dist <= 0.8 then
		if S.bv then pcall(function() S.bv:Destroy() end); S.bv = nil end
		if S._gravComp then pcall(function() S._gravComp:Destroy() end); S._gravComp = nil end
		if S.hum and S.hum.Parent then pcall(function() S.hum.PlatformStand = false end) end
		local real = realCF(r); local rot = real - real.Position
		HOOK.setCF(r, CFrame.new(tgt) * rot)
		if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
		return true
	end
	if S.hum and S.hum.Parent and not S.hum.PlatformStand then
		pcall(function() S.hum.PlatformStand = true end)
	end
	if not S.bv or not S.bv.Parent then
		local bv = Instance.new("BodyVelocity")
		bv.Name = "CM_Phys"
		bv.MaxForce = Vector3.new(1e7, 1e7, 1e7)
		bv.P = 3000
		bv.Parent = r
		S.bv = bv
		if not S._gravComp then
			local gf = Instance.new("BodyForce")
			gf.Name = "CM_GravComp"
			gf.Force = Vector3.new(0, r:GetMass() * workspace.Gravity, 0)
			gf.Parent = r
			S._gravComp = gf
		end
	end
	if S._gravComp and S._gravComp.Parent then
		S._gravComp.Force = Vector3.new(0, r:GetMass() * workspace.Gravity, 0)
	end
	local boost = S._fastMode and 3 or 1
	local speed = math.max(1, St.speed) * boost
	local dir = diff.Unit
	S.bv.Velocity = dir * speed
	if S.hum and S.hum.Parent then
		local cur = S.hum:GetState()
		if cur ~= Enum.HumanoidStateType.Running then
			pcall(function() S.hum:ChangeState(Enum.HumanoidStateType.Running) end)
		end
		local dirH = Vector3.new(dir.X, 0, dir.Z)
		if dirH.Magnitude > 0.01 then pcall(function() S.hum.MoveDirection = dirH.Unit end) end
		if S.hum.WalkSpeed > 100 or S.hum.WalkSpeed < 5 then HOOK.setHum(S.hum, "WalkSpeed", 16) end
	end
	return false
end

STEP.ghost = function(S, dt)
	if not S._ghostInit then
		S._ghostInit = true
		if HOOK.supported() then
			HOOK.install()
			HOOK.raycastBlind = true
			HOOK.writeProtect = true
			St.raycastBlind = true
			St.writeProtect = true
		end
		if St.noclip == "off" then St.noclip = "persistent" end
	end
	return STEP.phys(S, dt)
end

STEP.net = function(S, dt)
	_netInit()
	return _stepCFrame(S, dt, "hybrid")
end

STEP.lag = function(S, dt)
	tpBusyMark(0.6)
	if S.lagFreeze and S.lagFreeze > 0 then
		S.lagFreeze = S.lagFreeze - dt
		return false
	end
	S.lagTimer = (S.lagTimer or 0) + dt
	if S.lagTimer >= 1.2 then
		S.lagTimer = 0
		S.lagFreeze = 0.03
		return false
	end
	return _stepCFrame(S, dt, "hybrid")
end

STEP.speed = function(S, dt)
	tpBusyMark(0.6)
	local r, tgt = S.r, S.tgt
	if not r or not r.Parent then return end
	tickProgress(S, dt, "速度欺骗")
	local pos = rp(r)
	local diff = tgt - pos
	local dist = diff.Magnitude
	if dist <= 1 then
		local real = realCF(r); local rot = real - real.Position
		HOOK.setCF(r, CFrame.new(tgt) * rot)
		if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
		return true
	end
	local boost = S._fastMode and 3 or 1
	local maxStep = St.maxServerSpeed * dt * boost
	local maxAllow = maxStep * 2.5
	local userStep = math.max(1, St.speed) * dt * boost
	local mv = math.min(userStep, maxAllow, dist)
	if mv <= 0 then return false end
	local dir = diff.Unit
	local np = pos + dir * mv
	local curCF = realCF(r)
	local rotPart = curCF - curCF.Position
	HOOK.setCF(r, CFrame.new(np) * rotPart)
	local realDT = math.max(dt, 1/240)
	local vel = (np - pos) / realDT
	local curVelY = 0
	pcall(function() curVelY = r.AssemblyLinearVelocity.Y end)
	HOOK.setVel(r, Vector3.new(vel.X, curVelY, vel.Z))
	if mv >= dist then
		HOOK.setCF(r, CFrame.new(tgt) * rotPart)
		if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
		return true
	end
	return false
end

STEP.jump = function(S, dt)
	tpBusyMark(0.6)
	local r, tgt = S.r, S.tgt
	if not r or not r.Parent then return end
	tickProgress(S, dt, "跳跃")
	local hum = S.hum
	if not hum or not hum.Parent then return STEP.speed(S, dt) end
	local pos = rp(r)
	local diff = tgt - pos
	local dist = diff.Magnitude
	if dist <= 2 then
		local real = realCF(r); local rot = real - real.Position
		HOOK.setCF(r, CFrame.new(tgt) * rot)
		if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
		return true
	end
	local boost = S._fastMode and 3 or 1
	local isAir = (hum.FloorMaterial == Enum.Material.Air)
	local maxStep
	if isAir then maxStep = St.maxServerSpeed * 2 * dt * boost
	else maxStep = St.maxServerSpeed * 1.5 * dt * boost end
	local mv = math.min(maxStep, dist)
	if mv <= 0 then return false end
	local dir = diff.Unit
	local np = pos + dir * mv
	local curCF = realCF(r)
	local rotPart = curCF - curCF.Position
	HOOK.setCF(r, CFrame.new(np) * rotPart)
	S.jumpTimer = (S.jumpTimer or 0) + dt
	if S.jumpTimer >= 0.5 then
		S.jumpTimer = 0
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			hum.Jump = true
		end)
	end
	return false
end

STEP.align = function(S, dt)
	tpBusyMark(0.6)
	local r, tgt = S.r, S.tgt
	if not r or not r.Parent then cleanAlign(); return end
	tickProgress(S, dt, "对齐")
	local pos = rp(r)
	local dist = (tgt - pos).Magnitude
	if dist <= 0.8 then
		cleanAlign()
		if S.hum and S.hum.Parent then pcall(function() S.hum.PlatformStand = false end) end
		local real = realCF(r); local rot = real - real.Position
		HOOK.setCF(r, CFrame.new(tgt) * rot)
		if not S.loop then S.fin(string.format("已到达 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
		return true
	end
	if S.hum and S.hum.Parent and not S.hum.PlatformStand then
		pcall(function() S.hum.PlatformStand = true end)
	end
	if not ALIGN.ap or not ALIGN.ap.Parent or ALIGN.target ~= tgt then
		cleanAlign()
		local att = Instance.new("Attachment")
		att.Name = "CM_AlignAtt"
		att.Parent = r
		local ap = Instance.new("AlignPosition")
		ap.Name = "CM_AlignPos"
		ap.Attachment0 = att
		ap.Mode = Enum.PositionAlignmentMode.OneAttachment
		ap.Position = tgt
		ap.MaxForce = 1e6
		ap.Responsiveness = 15
		ap.ApplyAtCenterOfMass = true
		ap.Parent = r
		ALIGN.ap = ap
		ALIGN.att = att
		ALIGN.target = tgt
	end
	ALIGN.ap.Position = tgt
	local base = S._fastMode and 60 or 25
	local resp = base + dist * dist * 0.15
	if resp < 20 then resp = 20 end
	if resp > 200 then resp = 200 end
	ALIGN.ap.Responsiveness = resp
	return false
end

STEP.full = function(S, dt)
	if not S._fullInit then
		S._fullInit = true
		if HOOK.supported() then
			HOOK.install()
			HOOK.raycastBlind = true
			St.raycastBlind = true
		end
		OWNER.start()
		if St.noclip == "off" then St.noclip = "persistent" end
	end
	return STEP.speed(S, dt)
end

STEP.instant = function(S, dt)
	tpBusyMark(2.5)
	local r, tgt = S.r, S.tgt
	if not r or not r.Parent then return end
	local real = realCF(r)
	local rotPart = real - real.Position
	HOOK.setCF(r, CFrame.new(tgt) * rotPart)
	if not S.loop then S.fin(string.format("已传送 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z)) end
	return true
end

local function doTp(opts)
	local tgt, loop, src = opts.target, opts.loop == true, opts.source

	-- ★ 中断旧的非循环传送并继续新传送
	if task_ and not task_.loop then
		setStat("切换到新目标…", Th.Warn)
		UIX.notify("坐标管理器", "已中断旧传送，切换到新目标", 2, Th.Warn)
		cancelTask()
	end
	if loop and isLp() then UIX.notify("坐标管理器", "已有循环传送", 3, Th.Warn); return false end
	if not loop and isLp() then UIX.notify("坐标管理器", "循环传送运行中", 3, Th.Warn); return false end
	tpBusyMark(3.0)

	INTERRUPT.flag = false
	local done, cn = false, nil
	local ch = LP.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not r then setStat("角色未加载", Th.Err); return false end
	setStat(string.format("传送启动 → (%.1f, %.1f, %.1f)", tgt.X, tgt.Y, tgt.Z), Th.Acc)
	if St.hook then HOOK.install(); HOOK.protect(r, hum) end
	if St.camStable then CAM.start() end

	local LIFT = { phase = 0, baseTgt = tgt, liftY = 0 }
	if St.path == "lift" and St.bypass ~= "walk" then
		LIFT.phase = 1
		LIFT.liftY = 0
	end

	local fallbackConn = nil
	local S_ref = nil
	local function fin(m, c)
		if done then return end
		if LIFT.phase > 0 and LIFT.phase < 3 then return end
		done = true
		if cn then cn:Disconnect() end
		if fallbackConn then fallbackConn:Disconnect(); fallbackConn = nil end
		if S_ref then restoreState(S_ref, r, hum) end
		cleanAlign()
		if St.camStable then CAM.stop() end
		if St.bypass ~= "full" and St.bypass ~= "owner" then OWNER.stop() end
		if St.hook and r then HOOK.unprotect(r, hum) end
		if task_ and task_.cn == cn then task_ = nil end
		tpBusyMark(2.0)
		if m then
			setStat(m, c or Th.Ok)
			if c == Th.Warn or (m:find("中断") or m:find("⚠")) then
				UIX.notify("坐标管理器", m, 2.5, c or Th.Warn)
			end
		end
		if uLoop then uLoop() end
	end
	local serverAware = (St.bypass == "phys" or St.bypass == "ghost"
		or St.bypass == "owner" or St.bypass == "speed"
		or St.bypass == "jump" or St.bypass == "align"
		or St.bypass == "full" or St.bypass == "walk"
		or St.bypass == "anim" or St.bypass == "net")

	if St.mode == "teleport" and not serverAware and LIFT.phase == 0 then
		local real = realCF(r); local rot = real - real.Position
		HOOK.setCF(r, CFrame.new(tgt) * rot)
		fin(string.format("已传送 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z))
		return true
	end
	if St.bypass == "walk" and hum then HOOK.setHum(hum, "WalkSpeed", math.min(St.speed, 300)) end
	local S = buildState(tgt, loop, src, ch, r, hum, fin, nil)
	S_ref = S
	S._fastMode = (St.mode == "teleport" and serverAware)
	local stepFn
	if St.bypass == "walk" then stepFn = STEP.walk
	elseif St.bypass == "hybrid" then stepFn = STEP.hybrid
	elseif St.bypass == "stealth" then stepFn = STEP.stealth
	elseif St.bypass == "jitter" then stepFn = STEP.jitter
	elseif St.bypass == "pulse" then stepFn = STEP.pulse
	elseif St.bypass == "zigzag" then stepFn = STEP.zigzag
	elseif St.bypass == "anim" then stepFn = STEP.anim
	elseif St.bypass == "phys" then stepFn = STEP.phys
	elseif St.bypass == "ghost" then stepFn = STEP.ghost
	elseif St.bypass == "net" then stepFn = STEP.net
	elseif St.bypass == "lag" then stepFn = STEP.lag
	elseif St.bypass == "owner" then OWNER.start(); stepFn = STEP.speed
	elseif St.bypass == "speed" then stepFn = STEP.speed
	elseif St.bypass == "jump" then stepFn = STEP.jump
	elseif St.bypass == "align" then stepFn = STEP.align
	elseif St.bypass == "full" then stepFn = STEP.full
	else stepFn = STEP.instant end
	local _fbStart = os.clock()
	local _fbLastPos = rp(r) or r.Position
	fallbackConn = RS.Heartbeat:Connect(function()
		if dead or done then return end
		local elapsed = os.clock() - _fbStart
		if elapsed < 3 then return end
		local cur = rp(r) or r.Position
		local moved = (cur - _fbLastPos).Magnitude
		if moved < 2 then
			if S.bv then pcall(function() S.bv:Destroy() end); S.bv = nil end
			if S._gravComp then pcall(function() S._gravComp:Destroy() end); S._gravComp = nil end
			cleanAlign()
			local real = realCF(r); local rot = real - real.Position
			HOOK.setCF(r, CFrame.new(tgt) * rot)
			LIFT.phase = 3
			fin(string.format("⚠ 服务端阻塞，强制传送 X:%.2f Y:%.2f Z:%.2f", tgt.X, tgt.Y, tgt.Z), Th.Warn)
		else
			_fbStart = os.clock()
			_fbLastPos = cur
		end
	end)
	cn = RS.Heartbeat:Connect(function(dt)
		if dead then fin() return end

		if INTERRUPT.flag then
			INTERRUPT.flag = false
			fin("已中断传送", Th.Warn)
			return
		end

		tpBusyMark(0.8)
		if St.hook then HOOK.updateFake(r, dt, 16); if hum and HOOK.fakeWS[hum] then HOOK.fakeWS[hum] = 16 end end
		if St.bypass == "walk" and hum and hum.Parent then
			local tWS = math.min(St.speed, 300)
			if hum.WalkSpeed < tWS then HOOK.setHum(hum, "WalkSpeed", tWS) end
		end

		-- ★ 抬升逻辑 v57.2：保持高度 + 考虑目的地 Y
		if LIFT.phase > 0 then
			local cur = rp(r) or r.Position
			local realTgt = LIFT.baseTgt
			local liftH = tonumber(St.liftHeight) or 30
			if LIFT.phase == 1 then
				if LIFT.liftY == 0 then
					LIFT.liftY = math.max(cur.Y, realTgt.Y) + liftH
				end
				S.tgt = Vector3.new(cur.X, LIFT.liftY, cur.Z)
				if math.abs(cur.Y - LIFT.liftY) < 3 then
					LIFT.phase = 2
					setStat(string.format("抬升完成 → 水平 (%.1f)", LIFT.liftY), Th.Acc)
				end
			elseif LIFT.phase == 2 then
				S.tgt = Vector3.new(realTgt.X, LIFT.liftY, realTgt.Z)
				-- 保持高度：如果下坠超过 2 studs，直接拽回
				if math.abs(cur.Y - LIFT.liftY) > 2 then
					local cf = realCF(r)
					local rot = cf - cf.Position
					HOOK.setCF(r, CFrame.new(Vector3.new(cur.X, LIFT.liftY, cur.Z)) * rot)
					HOOK.setVel(r, HOOK.V3ZERO)
				end
				local dxz = Vector3.new(cur.X - realTgt.X, 0, cur.Z - realTgt.Z).Magnitude
				if dxz < 3 then
					LIFT.phase = 3
					if math.abs(cur.Y - realTgt.Y) > 2 then
						setStat(string.format("水平到位 → 下降 (%.1f → %.1f)", LIFT.liftY, realTgt.Y), Th.Acc)
					else
						setStat("水平到位", Th.Acc)
					end
				end
			elseif LIFT.phase == 3 then
				S.tgt = realTgt
				-- 强制下降（防止 stepFn 水平分量占主导）
				if math.abs(cur.Y - realTgt.Y) > 3 then
					local cf = realCF(r)
					local rot = cf - cf.Position
					local descendSpeed = math.min(St.speed, 80)
					local newY = cur.Y - descendSpeed * dt
					if newY < realTgt.Y then newY = realTgt.Y end
					HOOK.setCF(r, CFrame.new(Vector3.new(cur.X, newY, cur.Z)) * rot)
				end
			end
		end
		local ok, err = pcall(stepFn, S, dt)
		if not ok and not dead then warn("[" .. SCRIPT_ID .. "] step: " .. tostring(err)) end
	end)
	task_ = {cn=cn, loop=loop, source=src, target=tgt, stop=function()
		if cn then cn:Disconnect() end
		if fallbackConn then fallbackConn:Disconnect() end
		if S_ref then restoreState(S_ref, r, hum) end
		cleanAlign()
		if St.camStable then CAM.stop() end
		if St.bypass ~= "full" and St.bypass ~= "owner" then OWNER.stop() end
		if St.hook and r then HOOK.unprotect(r, hum) end
		tpBusyMark(2.0)
	end}
	if loop then setStat(string.format("[%s] 循环中 → X:%.1f Y:%.1f Z:%.1f", src == "list" and "列表" or "手动", tgt.X, tgt.Y, tgt.Z), Th.Acc) end
	if uLoop then uLoop() end
	return true
end

local function interruptTp()
	if task_ and not task_.loop then
		INTERRUPT.flag = true
		return true
	end
	return false
end

trk(LP.CharacterAdded:Connect(function(newChar)
	if task_ then
		local wasLoop = task_.loop
		local tgt, src = task_.target, task_.source
		cancelTask()
		if wasLoop and tgt then
			setStat("角色重生，恢复循环…", Th.Warn)
			task.spawn(function()
				local r = newChar:WaitForChild("HumanoidRootPart", 5)
				if r and not dead then
					task.wait(0.4)
					doTp({target=tgt, loop=true, source=src})
					setStat("已恢复循环", Th.Ok)
				end
			end)
		else setStat("角色重生，已停止", Th.Warn) end
	end
end))

uLoop = function()
	local r = task_ and task_.loop
	local s = r and task_.source or nil
	if UI.mLp then
		if s == "manual" then UI.mLp.Text = "停止循环"; UI.mLp.BackgroundColor3 = Th.Err; UI.mLp.TextColor3 = Color3.fromRGB(255,255,255)
		else UI.mLp.Text = "循环传送"; UI.mLp.BackgroundColor3 = Th.Sur; UI.mLp.TextColor3 = Th.Txt end
	end
	if UI.lLp then
		if s == "list" then UI.lLp.Text = "停止"; UI.lLp.BackgroundColor3 = Th.Err; UI.lLp.TextColor3 = Color3.fromRGB(255,255,255)
		else UI.lLp.Text = "循环"; UI.lLp.BackgroundColor3 = Th.Sur; UI.lLp.TextColor3 = Th.Txt end
	end
end

local function diagnose()
	local ch = LP.Character
	if not ch then UIX.notify("诊断", "角色未加载", 4, Th.Err); return end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	if not hrp then UIX.notify("诊断", "无 HRP", 4, Th.Err); return end
	local before = HOOK.realPos(hrp) or hrp.Position
	local owner = nil
	pcall(function() owner = hrp:GetNetworkOwner() end)
	local ownerStr = (owner == LP) and "客户端" or (owner and owner.Name or "服务端")
	local test = before + Vector3.new(5, 0, 0)
	local real = realCF(hrp)
	local rot = real - real.Position
	tpBusyMark(3.0)
	HOOK.setCF(hrp, CFrame.new(test) * rot)
	task.wait(0.5)
	local after = HOOK.realPos(hrp) or hrp.Position
	local moved = (after - before).Magnitude
	local msg
	if moved > 4 then
		msg = string.format("✅ 客户端权威\n所有权: %s\n可自由传送 (位移 %.2f)", ownerStr, moved)
	elseif moved > 0.5 then
		msg = string.format("⚠️ 部分服务端权威\n所有权: %s\n建议用【速度】模式 (位移 %.2f)", ownerStr, moved)
	else
		msg = string.format("❌ 完全服务端权威\n所有权: %s\n客户端无法传送 (位移 %.2f)", ownerStr, moved)
	end
	UIX.notify("诊断结果", msg, 6, (moved > 4) and Th.Ok or (moved > 0.5) and Th.Warn or Th.Err)
	HOOK.setCF(hrp, CFrame.new(before) * rot)
end

-- 列表渲染（新坐标永远在末尾）
local rows = {}
local function updRows()
	for id, rw in pairs(rows) do
		local sel = St.sel and St.sel[id] == true
		rw.BackgroundColor3 = sel and Th.AccD or Th.Sur
		rw.BackgroundTransparency = sel and 0.05 or 0.5
	end
end
local function clrSel() St.sel = {}; updRows() end
local function getSel()
	local o = {}
	for _, it in ipairs(St.saved) do if St.sel and St.sel[it.id] then table.insert(o, it) end end
	return o
end
local function fstSel()
	for _, it in ipairs(St.saved) do if St.sel and St.sel[it.id] then return it end end
end

local function renderList()
	for _, c in ipairs(UI.lScroll:GetChildren()) do if c:GetAttribute("isRow") then c:Destroy() end end
	rows = {}
	St.sel = St.sel or {}
	-- ★ 按数组顺序渲染（= 添加顺序），新坐标永远在末尾
	local items = {}
	for i, v in ipairs(St.saved) do table.insert(items, v) end
	if not St.asc then
		local rev = {}
		for i = #items, 1, -1 do table.insert(rev, items[i]) end
		items = rev
	end
	for i, it in ipairs(items) do
		local x, y, z = tonumber(it.x) or 0, tonumber(it.y) or 0, tonumber(it.z) or 0
		local id = tonumber(it.id) or i
		local r = mk("Frame", {Name="R"..id, Size=UDim2.new(1,0,0,30), BackgroundColor3=Th.Sur, BackgroundTransparency=0.5, BorderSizePixel=0, LayoutOrder=i, Parent=UI.lScroll})
		r:SetAttribute("isRow", true)
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=r})
		mk("UIStroke", {Color=Th.Str, Thickness=1, Transparency=0.5, Parent=r})
		local cb = mk("TextButton", {Size=UDim2.new(0.55,-4,1,0), Position=UDim2.fromOffset(4,0), BackgroundTransparency=1, AutoButtonColor=false, Font=Enum.Font.Gotham, TextSize=11, TextColor3=Th.Txt, TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, Text=string.format("%d| %.1f, %.1f, %.1f", i, x, y, z), Parent=r})
		mk("UIPadding", {PaddingLeft=UDim.new(0,6), Parent=cb})
		local nb = mk("TextBox", {Size=UDim2.new(0.45,-8,1,-6), Position=UDim2.new(0.55,2,0,3), BackgroundColor3=Th.Bg, BorderSizePixel=0, Font=Enum.Font.Gotham, TextSize=11, TextColor3=Th.Sub, PlaceholderText="备注…", PlaceholderColor3=Color3.fromRGB(80,80,96), Text=it.note or "", ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left, Parent=r})
		mk("UICorner", {CornerRadius=UDim.new(0,4), Parent=nb})
		mk("UIPadding", {PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6), Parent=nb})
		rows[id] = r
		cb.MouseButton1Click:Connect(function()
			if St.multi then
				if St.sel[id] then St.sel[id] = nil else St.sel[id] = true end
			else
				St.sel = {[id]=true}
			end
			updRows()
		end)
		nb:GetPropertyChangedSignal("Text"):Connect(function()
			if it.note ~= nb.Text then it.note = nb.Text end
		end)
	end
	updRows()
end

local function applyMode()
	if St.mode == "smooth" then
		UI.smBtn.BackgroundColor3 = Th.Acc; UI.smBtn.TextColor3 = Color3.fromRGB(255,255,255)
		UI.tpBtn.BackgroundColor3 = Th.Sur; UI.tpBtn.TextColor3 = Th.Sub
	else
		UI.smBtn.BackgroundColor3 = Th.Sur; UI.smBtn.TextColor3 = Th.Sub
		UI.tpBtn.BackgroundColor3 = Th.Acc; UI.tpBtn.TextColor3 = Color3.fromRGB(255,255,255)
	end
end
local function applyGrav()
	if UI.gOn and UI.gOff then
		if St.nograv then
			UI.gOn.BackgroundColor3 = Th.Acc; UI.gOn.TextColor3 = Color3.fromRGB(255,255,255)
			UI.gOff.BackgroundColor3 = Th.Sur; UI.gOff.TextColor3 = Th.Txt
		else
			UI.gOn.BackgroundColor3 = Th.Sur; UI.gOn.TextColor3 = Th.Txt
			UI.gOff.BackgroundColor3 = Th.Acc; UI.gOff.TextColor3 = Color3.fromRGB(255,255,255)
		end
	end
end
local function applyMainMin()
	if St.min then
		main.Size = UDim2.fromOffset(main.AbsoluteSize.X, TITLE_H)
		cScroll.Visible = false; mMin.Text = "+"; mRH.Visible = false
	else
		main.Size = UDim2.fromOffset(St.mainW, St.mainH)
		cScroll.Visible = true; mMin.Text = "—"; mRH.Visible = true
	end
end
trk(mMin.MouseButton1Click:Connect(function() St.min = not St.min; applyMainMin() end))

trk(UI.smBtn.MouseButton1Click:Connect(function() St.mode = "smooth"; applyMode(); setStat("已切换到平滑模式", Th.Ok); saveToFile() end))
trk(UI.tpBtn.MouseButton1Click:Connect(function() St.mode = "teleport"; applyMode(); setStat("已切换到瞬移模式", Th.Ok); saveToFile() end))
trk(UI.spdBox.FocusLost:Connect(function() St.speed = clSpd(UI.spdBox.Text); UI.spdBox.Text = tostring(St.speed); setStat("速度已设为 " .. St.speed .. " studs/s", Th.Ok); saveToFile() end))
trk(UI.gOn.MouseButton1Click:Connect(function() St.nograv = true; GRAV.start(); applyGrav(); saveToFile(); setStat("无重力已开启", Th.Ok); UIX.notify("坐标管理器", "无重力已开启", 2, Th.Ok) end))
trk(UI.gOff.MouseButton1Click:Connect(function() St.nograv = false; GRAV.stop(); applyGrav(); saveToFile(); setStat("无重力已关闭", Th.Sub); UIX.notify("坐标管理器", "无重力已关闭", 2, Th.Sub) end))

trk(UI.mTp.MouseButton1Click:Connect(function()
	if task_ and not task_.loop then
		INTERRUPT.flag = true
		setStat("⚠ 正在中断传送…", Th.Warn)
		UIX.notify("坐标管理器", "正在中断传送…", 1.5, Th.Warn)
		return
	end
	if isLp() then UIX.notify("坐标管理器", "循环传送运行中", 3, Th.Warn); return end
	local c = getPos(); if not c then setStat("无坐标", Th.Err); return end
	local t, e = getTgt(c); if not t then setStat(e, Th.Err); return end
	doTp({target=t, loop=false, source="manual"})
end))
trk(UI.mLp.MouseButton1Click:Connect(function()
	if task_ and task_.loop and task_.source == "manual" then cancelTask(); setStat("已停止", Th.Sub); return end
	if isLp() then UIX.notify("坐标管理器", "已有循环传送", 3, Th.Warn); return end
	local c = getPos(); if not c then setStat("无坐标", Th.Err); return end
	local t, e = getTgt(c); if not t then setStat(e, Th.Err); return end
	doTp({target=t, loop=true, source="manual"})
end))
for _, ax in ipairs(AXES) do
	trk(UI.ins[ax].FocusLost:Connect(function(ep)
		-- ★ 只解析表达式，不再自动触发传送
		resolveHash(ax)
	end))
end

-- 长按保存（带反馈）
do
	local holdStart = nil
	local holdJob = nil
	local holdBar = UI.svHoldBar
	local lastNotifiedStage = 0
	local function clearHold()
		holdStart = nil
		lastNotifiedStage = 0
		if holdJob then pcall(function() task.cancel(holdJob) end); holdJob = nil end
		if holdBar then holdBar.Visible = false; holdBar.Size = UDim2.new(0,0,0,3) end
	end
	local function doSaveReplace()
		local p = getPos(); if not p then setStat("无坐标", Th.Err); return end
		local sel = getSel()
		if #sel > 0 then
			UNDO.push()
			for _, it in ipairs(sel) do
				it.x = p.X; it.y = p.Y; it.z = p.Z
			end
			saveToFile()
			setStat(string.format("已覆盖 %d 个坐标 → (%.1f, %.1f, %.1f)", #sel, p.X, p.Y, p.Z), Th.Ok)
			UIX.notify("坐标管理器", string.format("已覆盖 %d 个坐标", #sel), 2.5, Th.Ok)
		else
			UNDO.push()
			table.insert(St.saved, {id=St.nid, x=p.X, y=p.Y, z=p.Z, note=""})
			St.nid = St.nid + 1
			saveToFile()
			setStat(string.format("已保存新坐标 (%.1f, %.1f, %.1f)", p.X, p.Y, p.Z), Th.Ok)
			UIX.notify("坐标管理器", "已保存新坐标（末尾）", 2, Th.Ok)
		end
		renderList()
	end
	trk(UI.svBtn.MouseButton1Down:Connect(function()
		clearHold()
		holdStart = os.clock()
		lastNotifiedStage = 0
		if holdBar then holdBar.Visible = true; holdBar.Size = UDim2.new(0,0,0,3); holdBar.BackgroundColor3 = Th.Acc end
		local sel = getSel()
		if #sel > 0 then
			UIX.notify("坐标管理器", string.format("松手=保存新坐标\n按住2秒=覆盖选中 %d 个", #sel), 3, Th.Acc)
		else
			UIX.notify("坐标管理器", "松手=保存新坐标\n（先选中条目后按住=覆盖）", 3, Th.Acc)
		end
		holdJob = task.spawn(function()
			while holdStart and not dead do
				local el = os.clock() - holdStart
				local ratio = math.min(el / (HOLD_REPLACE_MS/1000), 1)
				if holdBar then
					holdBar.Size = UDim2.new(ratio, 0, 0, 3)
					holdBar.BackgroundColor3 = (ratio >= 1) and Th.Ok or Th.Acc
				end
				local stage = math.floor(ratio * 4)
				if stage ~= lastNotifiedStage then
					lastNotifiedStage = stage
					if stage == 1 then setStat("长按中… 松手保存", Th.Acc)
					elseif stage == 2 then setStat("继续按住… 覆盖选中", Th.Acc)
					elseif stage == 3 then setStat("即将覆盖…", Th.Warn) end
				end
				if ratio >= 1 then
					clearHold()
					doSaveReplace()
					return
				end
				task.wait(0.03)
			end
		end)
	end))
	trk(UI.svBtn.MouseButton1Up:Connect(function()
		if holdStart then
			local el = os.clock() - holdStart
			clearHold()
			if el < (HOLD_REPLACE_MS/1000) then
				local p = getPos(); if not p then setStat("无坐标", Th.Err); return end
				UNDO.push()
				table.insert(St.saved, {id=St.nid, x=p.X, y=p.Y, z=p.Z, note=""})
				St.nid = St.nid + 1
				saveToFile()
				renderList()
				setStat(string.format("已保存 %.1f, %.1f, %.1f", p.X, p.Y, p.Z), Th.Ok)
				UIX.notify("坐标管理器", "已保存到列表末尾", 2, Th.Ok)
			end
		end
	end))
	trk(UI.svBtn.MouseLeave:Connect(function() clearHold() end))
end

trk(UI.undoBtn.MouseButton1Click:Connect(function()
	if UNDO.undo() then
		renderList()
		setStat(string.format("已撤回（剩余 %d 步）", #St.undoStack), Th.Ok)
	end
end))
trk(UI.redoBtn.MouseButton1Click:Connect(function()
	if UNDO.redo() then
		renderList()
		setStat(string.format("已取消撤回（剩余 %d 步）", #St.redoStack), Th.Ok)
	end
end))

trk(UI.soBtn.MouseButton1Click:Connect(function()
	St.asc = not St.asc
	UI.soBtn.Text = St.asc and "正序" or "倒序"
	renderList()
	setStat(St.asc and "列表：正序（新坐标在末尾）" or "列表：倒序（新坐标在开头）", Th.Sub)
end))
trk(UI.adBtn.MouseButton1Click:Connect(function()
	St.advOpen = not St.advOpen
	UI.advP.Visible = St.advOpen
	setStat(St.advOpen and "高级选择已展开" or "高级选择已收起", Th.Sub)
end))
trk(UI.mulBtn.MouseButton1Click:Connect(function()
	St.multi = not St.multi
	UI.mulBtn.Text = "多选模式：" .. (St.multi and "开" or "关")
	UI.mulBtn.BackgroundColor3 = St.multi and Th.AccD or Th.Sur
	setStat(St.multi and "多选模式已开启" or "多选模式已关闭", Th.Sub)
end))
trk(UI.saBtn.MouseButton1Click:Connect(function()
	for _, it in ipairs(St.saved) do St.sel[it.id] = true end
	updRows()
	setStat(string.format("已全选 %d 条", #St.saved), Th.Ok)
end))
trk(UI.ivBtn.MouseButton1Click:Connect(function()
	for _, it in ipairs(St.saved) do if St.sel[it.id] then St.sel[it.id] = nil else St.sel[it.id] = true end end
	updRows()
	setStat("已反选", Th.Sub)
end))
trk(UI.lTp.MouseButton1Click:Connect(function()
	if St.multi then UIX.notify("坐标管理器", "多选模式无法传送", 3, Th.Warn); return end
	if task_ and not task_.loop then
		INTERRUPT.flag = true
		setStat("⚠ 正在中断传送…", Th.Warn)
		UIX.notify("坐标管理器", "正在中断传送…", 1.5, Th.Warn)
		return
	end
	if isLp() then UIX.notify("坐标管理器", "循环传送运行中", 3, Th.Warn); return end
	local it = fstSel(); if not it then setStat("请先选中", Th.Warn); return end
	doTp({target=Vector3.new(it.x, it.y, it.z), loop=false, source="list"})
end))
trk(UI.lLp.MouseButton1Click:Connect(function()
	if task_ and task_.loop and task_.source == "list" then cancelTask(); setStat("已停止", Th.Sub); return end
	if St.multi then UIX.notify("坐标管理器", "多选模式无法传送", 3, Th.Warn); return end
	if isLp() then UIX.notify("坐标管理器", "已有循环传送", 3, Th.Warn); return end
	local it = fstSel(); if not it then setStat("请先选中", Th.Warn); return end
	doTp({target=Vector3.new(it.x, it.y, it.z), loop=true, source="list"})
end))
trk(UI.lCp.MouseButton1Click:Connect(function()
	local sel = getSel()
	if #sel == 0 then setStat("未选中", Th.Warn); return end
	local ln = {}
	for _, it in ipairs(sel) do
		local n = (type(it.note)=="string" and it.note ~= "" and it.note) or ""
		if n ~= "" then table.insert(ln, string.format("%.2f, %.2f, %.2f  -- %s", it.x, it.y, it.z, n))
		else table.insert(ln, string.format("%.2f, %.2f, %.2f", it.x, it.y, it.z)) end
	end
	if toClip(table.concat(ln, "\n")) then
		setStat(string.format("已复制 %d 条到剪贴板", #sel), Th.Ok)
		UIX.notify("坐标管理器", string.format("已复制 %d 条", #sel), 2.5, Th.Ok)
	else
		setStat("剪贴板不可用", Th.Err)
		UIX.notify("坐标管理器", "剪贴板不可用", 3, Th.Err)
	end
end))
trk(UI.lDl.MouseButton1Click:Connect(function()
	local sel = getSel()
	if #sel == 0 then setStat("未选中", Th.Warn); return end
	UNDO.push()
	local rm = {}
	for _, it in ipairs(sel) do rm[it.id] = true end
	local kept = {}
	for _, it in ipairs(St.saved) do if not rm[it.id] then table.insert(kept, it) end end
	St.saved = kept; clrSel(); renderList(); saveToFile()
	setStat(string.format("已删除 %d 条", #sel), Th.Ok)
end))

-- 设置面板
local sPanel = nil
local sRefs = {}

local function closeSet()
	if sPanel then
		for id, bl in pairs(allBlocks) do
			if bl.host == "settings" and bl.frame.Parent == setBodyInner then
				bl.frame:Destroy(); allBlocks[id] = nil
			end
		end
		if setBodyInner then unregisterOwnerRefresh(setBodyInner) end
		sPanel:Destroy()
		sPanel = nil; setBodyInner = nil; sRefs = {}; setPanelRef = nil
	end
	UIState.setVisible = false
	saveUIState()
end

local function otherSnap()
	return {
		mode=St.mode, speed=St.speed, sortAsc=St.asc, noclipMode=St.noclip,
		pathMode=St.path, precision=St.prec, bypass=St.bypass,
		stealthMaxStep=St.stealthMaxStep, liftHeight=St.liftHeight,
		hook=St.hook, godmode=St.godmode, anticframe=St.anticframe,
		nograv=St.nograv, camStable=St.camStable,
		maxServerSpeed=St.maxServerSpeed,
		raycastBlind=St.raycastBlind, writeProtect=St.writeProtect,
	}
end
local function exportCfg(kind)
	local list = {}
	for _, it in ipairs(St.saved) do
		table.insert(list, {id=it.id, x=it.x, y=it.y, z=it.z, note=it.note or ""})
	end
	local cfg
	if kind == "full" then
		cfg = {type="full", version=VERSION, gameId=GAME_ID, list=list, nextId=St.nid, other=otherSnap()}
	elseif kind == "list" then
		cfg = {type="list", version=VERSION, gameId=GAME_ID, list=list, nextId=St.nid}
	else
		cfg = {type="other", version=VERSION, gameId=GAME_ID, other=otherSnap()}
	end
	local ok, en = pcall(function() return Http:JSONEncode(cfg) end)
	if not ok or not en then
		setStat("导出失败", Th.Err); UIX.notify("坐标管理器", "导出失败", 3, Th.Err); return
	end
	if toClip(en) then
		setStat(string.format("已导出%s", kind == "full" and "全部" or (kind == "list" and "列表" or "其他")), Th.Ok)
		UIX.notify("坐标管理器", "已复制到剪贴板", 2.5, Th.Ok)
	else
		setStat("剪贴板不可用", Th.Err)
		UIX.notify("坐标管理器", "剪贴板不可用", 3, Th.Err)
	end
end

local impUI = {parsed=nil, listMode="add", scopeAll=true, scopeList=true, scopeOther=true}
local function applyImp()
	local p = impUI.parsed
	if not p then return false, "配置无法解析" end
	local pver = tonumber(p.version)
	if pver and pver > VERSION then return false, string.format("配置版本 v%d > 当前 v%d", pver, VERSION) end
	local t = p.type
	if not t then
		if p.list and p.other then t = "full"
		elseif p.list then t = "list"
		elseif p.other then t = "other"
		else return false, "格式无法识别" end
	end
	local dL, dO = false, false
	if t == "full" then dL = impUI.scopeList; dO = impUI.scopeOther
	elseif t == "list" then dL = true
	elseif t == "other" then dO = true end
	if not dL and not dO then return false, "请选择范围" end
	local parts = {}
	if dL and type(p.list) == "table" then
		local im = {}
		for _, r in ipairs(p.list) do
			if type(r) == "table" and tonumber(r.x) and tonumber(r.y) and tonumber(r.z) then
				table.insert(im, {x=tonumber(r.x), y=tonumber(r.y), z=tonumber(r.z), note=type(r.note)=="string" and r.note or ""})
			end
		end
		if #im > 0 then
			UNDO.push()
			if impUI.listMode == "overwrite" then St.saved = {}; St.nid = 1 end
			for _, it in ipairs(im) do
				it.id = St.nid; St.nid = St.nid + 1
				table.insert(St.saved, it)
			end
			clrSel(); renderList()
			table.insert(parts, string.format("列表 %d 条", #im))
		end
	end
	if dO and type(p.other) == "table" then
		local o = p.other
		if o.mode == "smooth" or o.mode == "teleport" then St.mode = o.mode end
		if tonumber(o.speed) then St.speed = clSpd(o.speed); UI.spdBox.Text = tostring(St.speed) end
		if type(o.sortAsc) == "boolean" then St.asc = o.sortAsc; UI.soBtn.Text = St.asc and "正序" or "倒序" end
		if type(o.noclipMode) == "string" then for _, m in ipairs(NOCLIP) do if m.id == o.noclipMode then St.noclip = o.noclipMode end end end
		if type(o.pathMode) == "string" then for _, m in ipairs(PATHS) do if m.id == o.pathMode then St.path = o.pathMode end end end
		if tonumber(o.precision) then St.prec = clPrec(o.precision) end
		if type(o.bypass) == "string" then for _, m in ipairs(BYPASS) do if m.id == o.bypass then St.bypass = o.bypass end end end
		if tonumber(o.stealthMaxStep) then St.stealthMaxStep = clStep(o.stealthMaxStep) end
		if tonumber(o.liftHeight) then St.liftHeight = clLift(o.liftHeight) end
		if type(o.hook) == "boolean" then St.hook = o.hook end
		if type(o.godmode) == "boolean" then St.godmode = o.godmode end
		if type(o.anticframe) == "boolean" then St.anticframe = o.anticframe end
		if type(o.nograv) == "boolean" then St.nograv = o.nograv; if St.nograv then GRAV.start() else GRAV.stop() end end
		if type(o.camStable) == "boolean" then St.camStable = o.camStable end
		if tonumber(o.maxServerSpeed) then St.maxServerSpeed = clSrv(o.maxServerSpeed) end
		if type(o.raycastBlind) == "boolean" then St.raycastBlind = o.raycastBlind end
		if type(o.writeProtect) == "boolean" then St.writeProtect = o.writeProtect end
		applyMode(); applyGrav(); renderList()
		table.insert(parts, "其他配置")
	end
	if #parts == 0 then return false, "无可导入" end
	return true, "导入完成：" .. table.concat(parts, " / ")
end

local function refreshSet()
	local r = sRefs; if not r then return end
	if r.ncB then for id, b in pairs(r.ncB) do
		if id == St.noclip then b.BackgroundColor3 = Th.Acc; b.TextColor3 = Color3.fromRGB(255,255,255)
		else b.BackgroundColor3 = Th.Sur; b.TextColor3 = Th.Txt end
	end end
	if r.pthB then for id, b in pairs(r.pthB) do
		if id == St.path then b.BackgroundColor3 = Th.Acc; b.TextColor3 = Color3.fromRGB(255,255,255)
		else b.BackgroundColor3 = Th.Sur; b.TextColor3 = Th.Txt end
	end end
	if r.bypB then for id, b in pairs(r.bypB) do
		if id == St.bypass then b.BackgroundColor3 = Th.Acc; b.TextColor3 = Color3.fromRGB(255,255,255)
		else b.BackgroundColor3 = Th.Sur; b.TextColor3 = Th.Txt end
	end end
	if r.descLbl then r.descLbl.Text = BYPASS_DESC[St.bypass] or BYPASS_DESC.off end
	if r.precB then r.precB.Text = tostring(St.prec) end
	if r.stepB then r.stepB.Text = tostring(St.stealthMaxStep) end
	if r.srvB then r.srvB.Text = tostring(St.maxServerSpeed) end
	if r.lftB then r.lftB.Text = tostring(St.liftHeight or 30) end
	if r.addB and r.ovrB then
		if impUI.listMode == "add" then
			r.addB.BackgroundColor3 = Th.Acc; r.addB.TextColor3 = Color3.fromRGB(255,255,255)
			r.ovrB.BackgroundColor3 = Th.Sur; r.ovrB.TextColor3 = Th.Txt
		else
			r.addB.BackgroundColor3 = Th.Sur; r.addB.TextColor3 = Th.Txt
			r.ovrB.BackgroundColor3 = Th.Acc; r.ovrB.TextColor3 = Color3.fromRGB(255,255,255)
		end
	end
	if r.allB then r.allB.BackgroundColor3 = impUI.scopeAll and Th.AccD or Th.Sur; r.allB.TextColor3 = impUI.scopeAll and Color3.fromRGB(255,255,255) or Th.Txt end
	if r.lsB then r.lsB.BackgroundColor3 = impUI.scopeList and Th.Acc or Th.Sur; r.lsB.TextColor3 = impUI.scopeList and Color3.fromRGB(255,255,255) or Th.Txt end
	if r.osB then r.osB.BackgroundColor3 = impUI.scopeOther and Th.Acc or Th.Sur; r.osB.TextColor3 = impUI.scopeOther and Color3.fromRGB(255,255,255) or Th.Txt end
	local function paint(onB, offB, on)
		if not onB or not offB then return end
		if on then
			onB.BackgroundColor3 = Th.Acc; onB.TextColor3 = Color3.fromRGB(255,255,255)
			offB.BackgroundColor3 = Th.Sur; offB.TextColor3 = Th.Txt
		else
			onB.BackgroundColor3 = Th.Sur; onB.TextColor3 = Th.Txt
			offB.BackgroundColor3 = Th.Acc; offB.TextColor3 = Color3.fromRGB(255,255,255)
		end
	end
	paint(r.hookOnB, r.hookOffB, St.hook)
	paint(r.gmOnB, r.gmOffB, St.godmode)
	paint(r.acOnB, r.acOffB, St.anticframe)
	paint(r.csOnB, r.csOffB, St.camStable)
	paint(r.rbOnB, r.rbOffB, St.raycastBlind)
	paint(r.wpOnB, r.wpOffB, St.writeProtect)
	paint(r.owOnB, r.owOffB, OWNER.enabled)
end

local function openSet()
	if sPanel then closeSet(); return end
	if not St._diagShown then
		St._diagShown = true
		task.delay(0.5, function()
			task.spawn(function()
				if not dead then diagnose() end
			end)
		end)
	end
	local pw, ph = St.setW, St.setH
	local p = mk("Frame", {Name="SetP", AnchorPoint=Vector2.new(0,0), Position=UIState.setPos, Size=UDim2.fromOffset(pw, ph), BackgroundColor3=Th.Bg, BorderSizePixel=0, Active=true, ClipsDescendants=true, ZIndex=20, Visible=true, Parent=sg})
	sPanel = p; setPanelRef = p
	mk("UICorner", {CornerRadius=UDim.new(0,10), Parent=p}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=p})

	local hdr = mk("Frame", {Name="H", Size=UDim2.new(1,0,0,32), BackgroundColor3=Th.Sur, BorderSizePixel=0, Active=true, ZIndex=21, Parent=p})
	mk("UICorner", {CornerRadius=UDim.new(0,10), Parent=hdr})
	mk("TextLabel", {Size=UDim2.new(1,-84,1,0), Position=UDim2.fromOffset(14,0), BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Txt, TextXAlignment=Enum.TextXAlignment.Left, Text="设置 ("..GAME_TAG..")", ZIndex=22, Parent=hdr, Active=false})
	local minB = mk("TextButton", {Size=UDim2.fromOffset(22,22), Position=UDim2.new(1,-58,0.5,-11), BackgroundColor3=Th.Bg, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=14, TextColor3=Th.Sub, Text="—", ZIndex=22, Parent=hdr})
	mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=minB})
	local clB = mk("TextButton", {Size=UDim2.fromOffset(22,22), Position=UDim2.new(1,-30,0.5,-11), BackgroundColor3=Th.Bg, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Err, Text="X", ZIndex=22, Parent=hdr})
	mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=clB})
	trk(clB.MouseButton1Click:Connect(closeSet))
	trk(hdr.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if UIX.drag then return end
		local ix, iy = input.Position.X, input.Position.Y
		if inRect(ix, iy, minB) or inRect(ix, iy, clB) then return end
		UIX.startDrag(p, input.Position, {
			onZ=function() hdr.ZIndex = nextZ() end,
			onEnd=function() UIState.setPos = p.Position; saveUIState() end,
		})
	end))

	local sRH = mk("Frame", {Name="RH", AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-4,1,-4), Size=UDim2.fromOffset(HDL,HDL), BackgroundColor3=Th.Hdl, BackgroundTransparency=0.15, BorderSizePixel=0, Active=true, ZIndex=nextZ(), Parent=p})
	mk("UICorner", {CornerRadius=UDim.new(0,3), Parent=sRH})

	local body = mk("ScrollingFrame", {Name="Body", Size=UDim2.new(1,0,1,-32), Position=UDim2.fromOffset(0,32), BackgroundTransparency=1, BorderSizePixel=0, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=6, ScrollBarImageColor3=Th.Str, ZIndex=21, Parent=p})
	local bInner = mk("Frame", {Name="BI", Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, ZIndex=21, Parent=body})
	setBodyInner = bInner
	mk("UIListLayout", {Name="IL", FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), Parent=bInner})
	mk("UIPadding", {PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,8), PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), Parent=bInner})

	local function viewportH() local cam = workspace.CurrentCamera; if cam then return cam.ViewportSize.Y end; return 1080 end
	local function refreshSetSize()
		if p.AbsoluteSize.Y <= 40 then return end
		local il = bInner:FindFirstChild("IL"); if not il then return end
		local needH = 32 + il.AbsoluteContentSize.Y + 20
		local maxH = math.floor(viewportH() * 0.85)
		if needH > maxH then needH = maxH end
		if needH < SET_MIN_H then needH = SET_MIN_H end
		if math.abs(needH - St.setH) > 1 then
			St.setH = needH
			p.Size = UDim2.fromOffset(St.setW, St.setH)
		end
	end
	registerOwnerRefresh(bInner, refreshSetSize)

	do
		local rsz, rs, rsz0 = false, nil, nil
		trk(sRH.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			rsz = true; rs = input.Position; rsz0 = Vector2.new(p.AbsoluteSize.X, p.AbsoluteSize.Y)
		end))
		trk(UIS.InputChanged:Connect(function(input)
			if not rsz then return end
			local d = input.Position - rs
			local maxH = math.floor(viewportH() * 0.85)
			local w = cl(rsz0.X + d.X, SET_MIN_W, SET_MAX_W)
			local h = cl(rsz0.Y + d.Y, SET_MIN_H, maxH)
			p.Size = UDim2.fromOffset(w, h)
			St.setW = w; St.setH = h
		end))
		trk(UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				rsz = false
				saveToFile()
				UIState.setPos = p.Position
				saveUIState()
			end
		end))
	end

	trk(minB.MouseButton1Click:Connect(function()
		if p.AbsoluteSize.Y <= 40 then
			p.Size = UDim2.fromOffset(St.setW, St.setH)
			body.Visible = true; minB.Text = "—"; sRH.Visible = true
		else
			p.Size = UDim2.fromOffset(p.AbsoluteSize.X, 32)
			body.Visible = false; minB.Text = "+"; sRH.Visible = false
		end
	end))

	local function setMergeTarget() return bInner end

	createBlock({id="set_diag", title="诊断", host="settings", parent=bInner, getMergeParent=setMergeTarget, build=function(b, self)
		mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="当前游戏 ID："..tostring(GAME_ID).."  存档："..GAME_TAG, LayoutOrder=1, Parent=b})
		mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="检测本游戏是客户端/服务端权威", LayoutOrder=2, Parent=b})
		local btn = mk("TextButton", {Size=UDim2.new(1,0,0,28), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Color3.fromRGB(255,255,255), Text="🔍 开始诊断", LayoutOrder=3, Parent=b})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=btn})
		trk(btn.MouseButton1Click:Connect(function()
			setStat("正在诊断…", Th.Sub)
			UIX.notify("坐标管理器", "诊断中…", 1, Th.Sub)
			task.spawn(diagnose)
		end))
	end})

	createBlock({id="set_noclip", title="穿墙模式", host="settings", parent=bInner, getMergeParent=setMergeTarget, build=function(b, self)
		local r = mk("Frame", {Size=UDim2.new(1,0,0,26), BackgroundTransparency=1, LayoutOrder=1, Parent=b})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=r})
		local bs = {}
		for i, m in ipairs(NOCLIP) do
			local btn = mk("TextButton", {Size=UDim2.new(1/#NOCLIP,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text=m.label, LayoutOrder=i, Parent=r})
			mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=btn}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=btn})
			bs[m.id] = btn
			trk(btn.MouseButton1Click:Connect(function()
				St.noclip = m.id; refreshSet(); saveToFile()
				if St.noclip ~= "off" then
					noclipMgr.start()
					pcall(function() noclipApplyToChar(LP.Character) end)
				end
				setStat("穿墙模式：" .. m.label, Th.Ok)
			end))
		end
		sRefs.ncB = bs
	end})

	createBlock({id="set_path", title="接近方式", host="settings", parent=bInner, getMergeParent=setMergeTarget, build=function(b, self)
		local r = mk("Frame", {Size=UDim2.new(1,0,0,26), BackgroundTransparency=1, LayoutOrder=1, Parent=b})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=r})
		local bs = {}
		for i, m in ipairs(PATHS) do
			local btn = mk("TextButton", {Size=UDim2.new(1/#PATHS,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text=m.label, LayoutOrder=i, Parent=r})
			mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=btn}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=btn})
			bs[m.id] = btn
			trk(btn.MouseButton1Click:Connect(function()
				St.path = m.id; refreshSet(); saveToFile()
				setStat("接近方式：" .. m.label, Th.Ok)
			end))
		end
		sRefs.pthB = bs
	end})

	createBlock({id="set_prec", title="传送参数", host="settings", parent=bInner, getMergeParent=setMergeTarget, build=function(b, self)
		mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="精度：次/studs，1-500", LayoutOrder=1, Parent=b})
		local bx = mk("TextBox", {Size=UDim2.new(1,0,0,26), BackgroundColor3=Th.Sur, BorderSizePixel=0, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Txt, Text=tostring(St.prec), ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Center, LayoutOrder=2, Parent=b})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=bx}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=bx})
		trk(bx.FocusLost:Connect(function() St.prec = clPrec(bx.Text); bx.Text = tostring(St.prec); saveToFile(); setStat("精度已设为 " .. St.prec, Th.Ok) end))
		sRefs.precB = bx
		mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="隐蔽模式单帧最大位移：1-5000", LayoutOrder=3, Parent=b})
		local stx = mk("TextBox", {Size=UDim2.new(1,0,0,26), BackgroundColor3=Th.Sur, BorderSizePixel=0, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Txt, Text=tostring(St.stealthMaxStep), ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Center, LayoutOrder=4, Parent=b})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=stx}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=stx})
		trk(stx.FocusLost:Connect(function() St.stealthMaxStep = clStep(stx.Text); stx.Text = tostring(St.stealthMaxStep); saveToFile(); setStat("隐蔽单帧上限已设为 " .. St.stealthMaxStep, Th.Ok) end))
		sRefs.stepB = stx
		mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="服务端最大速度 (studs/s)：30-2000", LayoutOrder=5, Parent=b})
		local srv = mk("TextBox", {Size=UDim2.new(1,0,0,26), BackgroundColor3=Th.Sur, BorderSizePixel=0, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Txt, Text=tostring(St.maxServerSpeed), ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Center, LayoutOrder=6, Parent=b})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=srv}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=srv})
		trk(srv.FocusLost:Connect(function() St.maxServerSpeed = clSrv(srv.Text); srv.Text = tostring(St.maxServerSpeed); saveToFile(); setStat("服务端上限已设为 " .. St.maxServerSpeed, Th.Ok) end))
		sRefs.srvB = srv
		mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="抬高路径高度 (studs)：1-500", LayoutOrder=7, Parent=b})
		local lft = mk("TextBox", {Size=UDim2.new(1,0,0,26), BackgroundColor3=Th.Sur, BorderSizePixel=0, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Txt, Text=tostring(St.liftHeight or 30), ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Center, LayoutOrder=8, Parent=b})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=lft}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=lft})
		trk(lft.FocusLost:Connect(function() St.liftHeight = clLift(lft.Text); lft.Text = tostring(St.liftHeight); saveToFile(); setStat("抬高高度已设为 " .. St.liftHeight .. " studs", Th.Ok) end))
		sRefs.lftB = lft
	end})

	createBlock({id="set_bypass", title="反检测方案", host="settings", parent=bInner, getMergeParent=setMergeTarget, build=function(b, self)
		mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="整体方案，自动组合多种规避手段", LayoutOrder=1, Parent=b})
		local rowCount = {}
		for _, m in ipairs(BYPASS) do rowCount[m.row] = (rowCount[m.row] or 0) + 1 end
		local maxRow = 0
		for r in pairs(rowCount) do if r > maxRow then maxRow = r end end
		local grid = mk("Frame", {Size=UDim2.new(1,0,0,maxRow*29), BackgroundTransparency=1, LayoutOrder=2, Parent=b})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=grid})
		local rows_ = {}
		for r = 1, maxRow do
			local rowFr = mk("Frame", {Size=UDim2.new(1,0,0,25), BackgroundTransparency=1, LayoutOrder=r, Parent=grid})
			mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=rowFr})
			rows_[r] = {frame=rowFr, cnt=rowCount[r] or 1, idx=0}
		end
		local bs = {}
		for _, m in ipairs(BYPASS) do
			local rd = rows_[m.row]
			rd.idx = rd.idx + 1
			local btn = mk("TextButton", {Size=UDim2.new(1/rd.cnt,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text=m.label, LayoutOrder=rd.idx, Parent=rd.frame})
			mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=btn}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=btn})
			bs[m.id] = btn
			trk(btn.MouseButton1Click:Connect(function()
				St.bypass = m.id
				refreshSet(); saveToFile()
				setStat("反检测：" .. m.label, Th.Ok)
				UIX.notify("坐标管理器", "反检测：" .. m.label, 2, Th.Ok)
			end))
		end
		sRefs.bypB = bs
		local dl = mk("TextLabel", {Size=UDim2.new(1,0,0,24), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Text=BYPASS_DESC[St.bypass] or BYPASS_DESC.off, LayoutOrder=3, Parent=b})
		sRefs.descLbl = dl
	end})

	createBlock({id="set_hook", title="HOOK 防护", host="settings", parent=bInner, getMergeParent=setMergeTarget, build=function(b, self)
		local sup = HOOK.supported()
		mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=sup and Th.Ok or Th.Err, TextXAlignment=Enum.TextXAlignment.Left, Text=sup and "执行器支持 HOOK ✓" or "执行器不支持 HOOK ✗", LayoutOrder=1, Parent=b})

		local function addToggle(text, order, setVal)
			mk("TextLabel", {Size=UDim2.new(1,0,0,12), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text=text, LayoutOrder=order, Parent=b})
			local row = mk("Frame", {Size=UDim2.new(1,0,0,24), BackgroundTransparency=1, LayoutOrder=order+1, Parent=b})
			mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=row})
			local on = mk("TextButton", {Size=UDim2.new(0.5,-2,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text="开启", LayoutOrder=1, Parent=row})
			mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=on})
			local off = mk("TextButton", {Size=UDim2.new(0.5,-2,1,0), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Color3.fromRGB(255,255,255), Text="关闭", LayoutOrder=2, Parent=row})
			mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=off}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=off})
			on.MouseButton1Click:Connect(function() setVal(true); refreshSet(); saveToFile() end)
			off.MouseButton1Click:Connect(function() setVal(false); refreshSet(); saveToFile() end)
			return on, off
		end

		local hOn, hOff = addToggle("属性伪装", 2, function(v)
			if v and not sup then UIX.notify("坐标管理器", "执行器不支持 HOOK", 3, Th.Err); return end
			St.hook = v
			if v then HOOK.install() end
			setStat(v and "属性伪装已开启" or "属性伪装已关闭", v and Th.Ok or Th.Sub)
		end)
		sRefs.hookOnB, sRefs.hookOffB = hOn, hOff

		local gOn, gOff = addToggle("Godmode（血量归零自动恢复）", 4, function(v)
			St.godmode = v
			setStat(v and "Godmode 已开启" or "Godmode 已关闭", v and Th.Ok or Th.Sub)
		end)
		sRefs.gmOnB, sRefs.gmOffB = gOn, gOff

		local aOn, aOff = addToggle("AntiCFrame（阻止服务器强制位移）", 6, function(v)
			St.anticframe = v
			setStat(v and "AntiCFrame 已开启" or "AntiCFrame 已关闭", v and Th.Ok or Th.Sub)
		end)
		sRefs.acOnB, sRefs.acOffB = aOn, aOff

		local cOn, cOff = addToggle("相机固定（传送时相机不动）", 8, function(v)
			St.camStable = v
			setStat(v and "相机固定已开启" or "相机固定已关闭", v and Th.Ok or Th.Sub)
		end)
		sRefs.csOnB, sRefs.csOffB = cOn, cOff

		local rOn, rOff = addToggle("射线屏蔽", 10, function(v)
			if v and not sup then UIX.notify("坐标管理器", "执行器不支持 HOOK", 3, Th.Err); return end
			St.raycastBlind = v
			if v then HOOK.install() end
			HOOK.raycastBlind = v
			setStat(v and "射线屏蔽已开启" or "射线屏蔽已关闭", v and Th.Ok or Th.Sub)
		end)
		sRefs.rbOnB, sRefs.rbOffB = rOn, rOff

		local wOn, wOff = addToggle("写入保护", 12, function(v)
			if v and not sup then UIX.notify("坐标管理器", "执行器不支持 HOOK", 3, Th.Err); return end
			St.writeProtect = v
			if v then HOOK.install() end
			HOOK.writeProtect = v
			setStat(v and "写入保护已开启" or "写入保护已关闭", v and Th.Ok or Th.Sub)
		end)
		sRefs.wpOnB, sRefs.wpOffB = wOn, wOff

		local oOn, oOff = addToggle("网络所有权（每 0.35s 抢一次）", 14, function(v)
			if v then
				OWNER.start()
				setStat("网络所有权争夺中…", Th.Acc)
				task.delay(1, function()
					if OWNER.confirmed then
						setStat("网络所有权已抢到", Th.Ok)
						UIX.notify("坐标管理器", "网络所有权已抢到 ✓", 2, Th.Ok)
					elseif OWNER.lastResult == "auto-success" then
						setStat("网络所有权已切回自动", Th.Ok)
						UIX.notify("坐标管理器", "已切回自动（客户端权威）", 3, Th.Ok)
					else
						setStat("服务端锁定所有权", Th.Warn)
						UIX.notify("坐标管理器", "服务端锁定所有权 ✗\n需用【速度】模式", 4, Th.Warn)
					end
				end)
			else
				OWNER.stop()
				setStat("网络所有权已关闭", Th.Sub)
			end
		end)
		sRefs.owOnB, sRefs.owOffB = oOn, oOff
	end})

	createBlock({id="set_export", title="导出配置", host="settings", parent=bInner, getMergeParent=setMergeTarget, build=function(b, self)
		local r = mk("Frame", {Size=UDim2.new(1,0,0,26), BackgroundTransparency=1, LayoutOrder=1, Parent=b})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=r})
		local function mke(t, k, o)
			local btn = mk("TextButton", {Size=UDim2.new(1/3,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text=t, LayoutOrder=o, Parent=r})
			mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=btn}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=btn})
			trk(btn.MouseButton1Click:Connect(function() exportCfg(k) end))
		end
		mke("全部", "full", 1); mke("列表", "list", 2); mke("其他", "other", 3)
	end})

	createBlock({id="set_import", title="导入配置", host="settings", parent=bInner, getMergeParent=setMergeTarget, build=function(b, self)
		local cs = mk("ScrollingFrame", {Size=UDim2.new(1,0,0,80), BackgroundColor3=Th.Sur, BorderSizePixel=0, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=3, ScrollBarImageColor3=Th.Str, LayoutOrder=1, Parent=b})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=cs}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=cs})
		local cb = mk("TextBox", {Size=UDim2.new(1,-8,0,50), Position=UDim2.fromOffset(4,4), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Font=Enum.Font.Code, TextSize=11, TextColor3=Th.Txt, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, ClearTextOnFocus=false, MultiLine=true, Text="", Parent=cs})
		local dls = mk("TextLabel", {Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=11, TextColor3=Th.Sub, TextXAlignment=Enum.TextXAlignment.Left, Text="", LayoutOrder=2, Parent=b})
		local function val()
			impUI.parsed = decode(cb.Text)
			if not impUI.parsed then dls.Text = "无法解析"; dls.TextColor3 = Th.Err; return false end
			local pv = tonumber(impUI.parsed.version)
			if pv and pv > VERSION then dls.Text = string.format("版本 v%d > 当前 v%d", pv, VERSION); dls.TextColor3 = Th.Err; return false end
			local t = impUI.parsed.type
			if not t then
				if impUI.parsed.list and impUI.parsed.other then t = "full"
				elseif impUI.parsed.list then t = "list"
				elseif impUI.parsed.other then t = "other"
				else dls.Text = "格式无效"; dls.TextColor3 = Th.Err; return false end
			end
			local gid = impUI.parsed.gameId
			local gidHint = (gid and tonumber(gid) and tonumber(gid) ~= GAME_ID) and " (其他游戏)" or ""
			dls.Text = "类型：" .. t .. gidHint
			dls.TextColor3 = Th.Ok
			return true
		end
		trk(cb:GetPropertyChangedSignal("Text"):Connect(function() task.defer(val) end))
		trk(cb.FocusLost:Connect(val))
		local rcb = mk("TextButton", {Size=UDim2.new(1,0,0,22), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text="从剪贴板读取", LayoutOrder=3, Parent=b})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=rcb}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=rcb})
		trk(rcb.MouseButton1Click:Connect(function()
			if not hasClip then dls.Text = "剪贴板 API 不可用"; dls.TextColor3 = Th.Err; setStat("剪贴板 API 不可用", Th.Err); return end
			local t = fromClip()
			if not t then dls.Text = "剪贴板为空"; dls.TextColor3 = Th.Err; setStat("剪贴板为空", Th.Warn); return end
			cb.Text = t; val()
			setStat("已从剪贴板读取", Th.Ok)
		end))
		local lr = mk("Frame", {Size=UDim2.new(1,0,0,22), BackgroundTransparency=1, LayoutOrder=4, Parent=b})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6), Parent=lr})
		local ab = mk("TextButton", {Size=UDim2.new(0.5,-3,1,0), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Color3.fromRGB(255,255,255), Text="新增", LayoutOrder=1, Parent=lr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=ab})
		local ob = mk("TextButton", {Size=UDim2.new(0.5,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text="覆盖", LayoutOrder=2, Parent=lr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=ob}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=ob})
		trk(ab.MouseButton1Click:Connect(function() impUI.listMode = "add"; refreshSet(); setStat("导入模式：新增", Th.Sub) end))
		trk(ob.MouseButton1Click:Connect(function() impUI.listMode = "overwrite"; refreshSet(); setStat("导入模式：覆盖", Th.Sub) end))
		sRefs.addB, sRefs.ovrB = ab, ob
		local sr = mk("Frame", {Size=UDim2.new(1,0,0,22), BackgroundTransparency=1, LayoutOrder=5, Parent=b})
		mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=sr})
		local alb = mk("TextButton", {Size=UDim2.new(1/3,-3,1,0), BackgroundColor3=Th.Sur, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Th.Txt, Text="全部", LayoutOrder=1, Parent=sr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=alb}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=alb})
		local lsb = mk("TextButton", {Size=UDim2.new(1/3,-3,1,0), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Color3.fromRGB(255,255,255), Text="列表", LayoutOrder=2, Parent=sr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=lsb})
		local osb = mk("TextButton", {Size=UDim2.new(1/3,-3,1,0), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=11, TextColor3=Color3.fromRGB(255,255,255), Text="其他", LayoutOrder=3, Parent=sr})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=osb})
		trk(alb.MouseButton1Click:Connect(function() impUI.scopeAll = not impUI.scopeAll; if impUI.scopeAll then impUI.scopeList = true; impUI.scopeOther = true end; refreshSet() end))
		trk(lsb.MouseButton1Click:Connect(function() impUI.scopeList = not impUI.scopeList; impUI.scopeAll = impUI.scopeList and impUI.scopeOther; refreshSet() end))
		trk(osb.MouseButton1Click:Connect(function() impUI.scopeOther = not impUI.scopeOther; impUI.scopeAll = impUI.scopeList and impUI.scopeOther; refreshSet() end))
		sRefs.allB, sRefs.lsB, sRefs.osB = alb, lsb, osb
		local cf = mk("TextButton", {Size=UDim2.new(1,0,0,24), BackgroundColor3=Th.Acc, BorderSizePixel=0, AutoButtonColor=true, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Color3.fromRGB(255,255,255), Text="确认导入", LayoutOrder=6, Parent=b})
		mk("UICorner", {CornerRadius=UDim.new(0,6), Parent=cf})
		trk(cf.MouseButton1Click:Connect(function()
			if not val() then return end
			local ok, msg = applyImp()
			if ok then
				dls.Text = msg; dls.TextColor3 = Th.Ok
				setStat(msg, Th.Ok)
				UIX.notify("坐标管理器", msg, 3, Th.Ok)
				saveToFile()
			else
				dls.Text = msg; dls.TextColor3 = Th.Warn
				setStat(msg, Th.Warn)
			end
		end))
	end})

	refreshSet()
	UIState.setVisible = true
	applyVisibility()
	task.defer(function() refreshSetSize() end)
	trk(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(refreshSetSize) end))
end
trk(setBtn.MouseButton1Click:Connect(function()
	openSet()
	setStat(sPanel and "设置面板已打开" or "设置面板已关闭", Th.Sub)
end))

-- 复位
local rGui = mk("ScreenGui", {Name="RBX_Ctrl_".._guiSfx, ResetOnSpawn=false, IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=999998})
rGui.Parent = guiP()
if ANTI and ANTI.mark then ANTI.mark(rGui) end
UIX.protectGui(rGui)
local rBtn = mk("TextButton", {Name="Reset", AnchorPoint=Vector2.new(0,1), Position=UDim2.new(0,16,1,-16), Size=UDim2.fromOffset(96,40), BackgroundColor3=Th.Sur, BackgroundTransparency=0.1, BorderSizePixel=0, AutoButtonColor=false, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=Th.Txt, Text="复位 (长按3秒)", Parent=rGui})
mk("UICorner", {CornerRadius=UDim.new(0,8), Parent=rBtn}); mk("UIStroke", {Color=Th.Str, Thickness=1, Parent=rBtn})
local rPg = mk("Frame", {Size=UDim2.new(0,0,1,0), BackgroundColor3=Th.Err, BackgroundTransparency=0.55, BorderSizePixel=0, ZIndex=0, Parent=rBtn})
mk("UICorner", {CornerRadius=UDim.new(0,8), Parent=rPg})
local rHold, rT = false, 0
trk(rBtn.MouseButton1Down:Connect(function() rHold = true; rT = 0; rPg.Size = UDim2.new(0,0,1,0) end))
local function clRh() rHold = false; rT = 0; rPg.Size = UDim2.new(0,0,1,0) end
trk(rBtn.MouseButton1Up:Connect(clRh))
trk(rBtn.MouseLeave:Connect(clRh))

local function doReset()
	cancelTask(); closeSet(); noclipMgr.stop(); cleanAlign(); OWNER.stop()
	for _, bl in pairs(allBlocks) do
		if bl.host == "detached" then
			local tgt = bl.getMergeParent and bl.getMergeParent() or cInner
			bl:attach(tgt)
		end
	end
	allHidden = false
	St.min = false; St.advOpen = false; St.sel = {}; St.multi = false
	St.mainW = 360; St.mainH = 300; St.setW = 360; St.setH = 480
	UIState.mainPos = defMainPos
	UIState.setPos = defSetPos
	UIState.mainVisible = true
	UIState.setVisible = false
	UIState.blockStates = {}
	main.Position = defMainPos
	main.Size = UDim2.fromOffset(St.mainW, St.mainH)
	for _, bl in pairs(mainBlocks) do
		bl.minimized = false
		bl:applyMinimized()
	end
	applyMainMin()
	UI.advP.Visible = false
	UI.mulBtn.Text = "多选模式：关"; UI.mulBtn.BackgroundColor3 = Th.Sur
	updRows(); saveToFile(); saveUIState(); applyVisibility()
	task.defer(function() triggerOwnerRefresh(cInner) end)
	setStat("已复位", Th.Ok)
	UIX.notify("坐标管理器", "已复位", 2.5, Th.Ok)
end
trk(RS.Heartbeat:Connect(function(dt)
	if not rHold then return end
	rT = rT + dt
	local ratio = math.min(rT / RESET_HOLD, 1)
	rPg.Size = UDim2.new(ratio, 0, 1, 0)
	if ratio < 1 then rBtn.Text = string.format("复位 %.1fs", RESET_HOLD - rT)
	else rBtn.Text = "复位 (长按3秒)" end
	if rT >= RESET_HOLD then clRh(); doReset() end
end))
trk(UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if rHold then clRh(); rBtn.Text = "复位 (长按3秒)" end
	end
end))
trk(UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightAlt then
		allHidden = not allHidden
		applyVisibility()
		UIX.notify("坐标管理器", allHidden and "已隐藏所有面板 (RightAlt 恢复)" or "已显示所有面板", 2, allHidden and Th.Warn or Th.Ok)
	end
end))

local Api
local function destroy()
	if dead then return end
	dead = true
	pcall(saveUIState)
	pcall(saveToFile)
	cancelTask(); closeSet(); GRAV.stop(); HOOK.uninstall(); noclipMgr.stop(); cleanAlign(); OWNER.stop()
	if CAM.conn then pcall(function() CAM.conn:Disconnect() end); CAM.conn = nil end
	if CAM.restoreJob then pcall(function() task.cancel(CAM.restoreJob) end); CAM.restoreJob = nil end
	CAM.active = false
	for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
	table.clear(Conns)
	if sg then pcall(function() sg:Destroy() end) end
	if notifGui then pcall(function() notifGui:Destroy() end) end
	if rGui then pcall(function() rGui:Destroy() end) end
	if gE[SCRIPT_ID] == Api then gE[SCRIPT_ID] = nil end
	if gE[_apiKey] == Api then rawset(gE, _apiKey, nil) end
end
trk(mCls.MouseButton1Click:Connect(destroy))

local okInit, errInit = pcall(function()
	applyMode(); applyMainMin(); applyGrav()
	UI.mulBtn.Text = "多选模式：" .. (St.multi and "开" or "关")
	UI.mulBtn.BackgroundColor3 = St.multi and Th.AccD or Th.Sur
	renderList(); uLoop()
	if St.hook and HOOK.supported() then
		HOOK.install()
		HOOK.raycastBlind = St.raycastBlind
		HOOK.writeProtect = St.writeProtect
	end
	if St.nograv then GRAV.start() end
	if St.noclip ~= "off" then
		noclipMgr.start()
		pcall(function() noclipApplyToChar(LP.Character) end)
	end
end)
if not okInit then warn("[" .. SCRIPT_ID .. "] 启动出错: " .. tostring(errInit)) end

Api = {version=VERSION, state=St, destroy=destroy, gui=sg, hook=HOOK, gravity=GRAV, noclip=noclipMgr, owner=OWNER, camera=CAM, diagnose=diagnose, busy=TP_BUSY, gameId=GAME_ID, interrupt=interruptTp}
rawset(gE, _apiKey, Api)
rawset(gE, SCRIPT_ID, Api)
pcall(function() print("[" .. SCRIPT_ID .. "] Api 已注册 (GameId="..tostring(GAME_ID)..")") end)

task.defer(function() task.defer(function() pcall(refreshMainSize) end) end)

task.defer(function()
	pcall(function()
		main.Position = UIState.mainPos
		main.Visible = UIState.mainVisible
		for id, bl in pairs(allBlocks) do
			local bs = UIState.blockStates[id]
			if bs and bs.min and bl.host == "main" then
				pcall(function() bl:applyMinimized() end)
			end
		end
	end)
end)

local saveTimer = 0
trk(RS.Heartbeat:Connect(function(dt)
	if dead then return end
	saveTimer = saveTimer + dt
	if saveTimer >= SAVE_INTERVAL then saveTimer = 0; saveToFile() end
	local p = getPos()
	if p then
		curLbl.Text = string.format("X: %.2f   Y: %.2f   Z: %.2f", p.X, p.Y, p.Z)
	else
		curLbl.Text = "X: --   Y: --   Z: --"
	end
end))

UIX.notify("坐标管理器", string.format("v%d 已加载 · GameId=%s", VERSION, tostring(GAME_ID)), 3.5, Th.Ok)
if St.hook and HOOK.supported() then
	task.delay(1, function() UIX.notify("坐标管理器", "HOOK 属性伪装已启用", 3, Th.Ok) end)
end
if not hasFile then
	task.delay(3.6, function() UIX.notify("坐标管理器", "文件存档 API 不可用", 3, Th.Warn) end)
end
if not hasClip then
	task.delay(6.8, function() UIX.notify("坐标管理器", "剪贴板 API 未检测到", 4, Th.Warn) end)
end
setStat("就绪 · "..GAME_TAG, Th.Sub)
