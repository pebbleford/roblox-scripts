-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("mm2") then return end

-- ================================================================
-- Pebbleford Hub - MM2 Hub
-- Dedicated admin for Murder Mystery 2
-- v1.1
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local _spawn = (task and task.spawn) or spawn
local _wait = (task and task.wait) or wait

-- ===================== COLOR PALETTE (Crimson/Blood Red Theme) =====================
local COLORS = {
	bg = Color3.fromRGB(20, 12, 12),
	bgSecondary = Color3.fromRGB(35, 18, 18),
	tabBg = Color3.fromRGB(55, 28, 28),
	accent = Color3.fromRGB(220, 30, 30),
	accentHover = Color3.fromRGB(255, 60, 60),
	accentDark = Color3.fromRGB(160, 20, 20),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(176, 176, 176),
	textDim = Color3.fromRGB(120, 120, 120),
	border = Color3.fromRGB(70, 35, 35),
	toggleOn = Color3.fromRGB(220, 30, 30),
	toggleOff = Color3.fromRGB(85, 85, 85),
	error = Color3.fromRGB(255, 68, 68),
	success = Color3.fromRGB(68, 255, 68),
	btnExecute = Color3.fromRGB(220, 30, 30),
	btnClear = Color3.fromRGB(60, 60, 60),
}

-- Role ESP colors
local ROLE_COLORS = {
	Murderer = Color3.fromRGB(255, 0, 0),
	Sheriff = Color3.fromRGB(0, 120, 255),
	Innocent = Color3.fromRGB(0, 220, 0),
	Unknown = Color3.fromRGB(180, 180, 180),
}

-- ===================== STATE (grouped to reduce local count) =====================
local roleState = {
	myRole = "Unknown",
	murdererPlayer = nil,
	sheriffPlayer = nil,
	roleCheckConnection = nil,
	roleCheckEnabled = false,
	lastRoleScan = 0,
}

local combatState = {
	murdererEspEnabled = false,
	murdererAlertEnabled = false,
	autoShootMurdererEnabled = false,
	aimSmoothing = 2,
	alertConnection = nil,
	alertActive = false,
	autoShootConnection = nil,
	murdererEspHighlight = nil,
	murdererEspConnection = nil,
	alertFrame = nil,
}

local espState = {
	espEnabled = false,
	showNamesEnabled = true,
	showDistanceEnabled = true,
	showRoleEnabled = true,
	gunEspEnabled = false,
	coinEspEnabled = false,
	fullbrightEnabled = false,
	playerEspHighlights = {},
	playerEspNametags = {},
	playerEspDistConns = {},
	espConnections = {},
	gunEspHighlights = {},
	coinEspHighlights = {},
	gunEspConnection = nil,
	coinEspConnection = nil,
	REFRESH_INTERVAL = 5,
}

local farmState = {
	autoCoinFarmEnabled = false,
	farmSpeed = 0.5,
	coinFarmThread = nil,
	coinsFarmed = 0,
	antiAfkEnabled = false,
	antiAfkConnection = nil,
}

local moveState = {
	flyEnabled = false,
	speedEnabled = false,
	noclipEnabled = false,
	infJumpEnabled = false,
	godEnabled = false,
	invisibleEnabled = false,
	flySpeed = 80,
	speedValue = 100,
	jumpPowerValue = 50,
	cameraFOV = 70,
	flyConnection = nil,
	bodyGyro = nil,
	bodyVelocity = nil,
	noclipConnection = nil,
	infJumpConnection = nil,
	godConnection = nil,
	bunnyHopEnabled = false,
	bunnyHopConnection = nil,
	gravityValue = 196,
}

local flingState = {
	flingEnabled = false,
	spinEnabled = false,
	seizureEnabled = false,
	flingPower = 99999,
	flingConnection = nil,
	flingConnection2 = nil,
	spinBAV = nil,
	spinConnection = nil,
	seizureConnection = nil,
	savedPhysProps = {},
	emoteActive = false,
	emoteTracks = {},
	emoteConnection = nil,
	walkFlingEnabled = false,
	walkFlingPower = 10000,
	walkFlingProps = {},
	walkFlingConnection = nil,
}

local miscState = {
	autoGrabGunEnabled = false,
	autoGrabConnection = nil,
	killAllEnabled = false,
	killAllConnection = nil,
	xrayEnabled = false,
	xrayOrigTransparencies = {},
	trapdoorEspEnabled = false,
	trapdoorEspHighlights = {},
	bringCoinsEnabled = false,
	bringCoinsConnection = nil,
	autoCollectEnabled = false,
	autoCollectConnection = nil,
	selectedPlayer = nil,
	antiVoidEnabled = false,
	antiVoidConnection = nil,
	lastSafePos = nil,
	headlessEnabled = false,
	headlessSaved = {},
	rainbowEnabled = false,
	rainbowConnection = nil,
	savedTransparencies = {},
}

local uiState = {
	windowVisible = true,
	activeTab = "Main",
	logLines = {},
	MAX_LOG_LINES = 50,
	origWalkSpeed = 16,
	origJumpPower = 50,
	roleLabel = nil,
	coinCountLabel = nil,
	origAmbient = nil,
	origBrightness = nil,
	origFogEnd = nil,
	origGlobalShadows = nil,
}

-- ===================== BUNDLE STATE TABLES (populated by later feature bundles) =====================
local visualEspState = {
	enabled = false,
	-- per-feature enabled flags (Bundle 1 - ESP Suite)
	boxEnabled = false,
	cornerBoxEnabled = false,
	tracersEnabled = false,
	skeletonEnabled = false,
	chamsEnabled = false,
	offscreenArrowsEnabled = false,
	snaplineMurdererEnabled = false,
	-- tunables
	tracerOrigin = "bottom", -- "bottom" | "top" | "mouse"
	tracerThickness = 1,
	-- runtime objects
	driverConnection = nil,
	drawings = {},   -- [player] = { box=Square, corners={Line*8}, tracer=Line, skel={Line*}, arrow=Triangle/Line }
	highlights = {}, -- [player] = Highlight (ChamsESP)
	snaplineDrawing = nil, -- single tracer Line to murderer
}

local coinDomState = {
	enabled = false,
	-- Coin Aura (teleport-to-each-in-radius collector)
	auraEnabled = false,
	auraRadius = 50,
	auraThread = nil,
	auraCollected = 0,
	-- Coin tracers (Drawing lines from screen bottom-center to each coin)
	tracersEnabled = false,
	tracerConnection = nil,
	tracerLines = {}, -- pooled Line drawings, reused frame to frame
	-- Live coin counter
	counterLabel = nil,
	counterThread = nil,
}

local sheriffState = {
	enabled = false,
	-- Sheriff aimbot (client-side camera aim math; generic, no remote)
	aimbotEnabled = false,
	holdToAim = true,        -- only lock while the aim key is held; false = lock while toggle on
	aimKey = "E",            -- hold key for aim lock
	aimKeyDown = false,
	targetHead = true,       -- aim Head (fallback HumanoidRootPart)
	smoothing = 0.2,         -- camera CFrame:Lerp alpha (0..1)
	fov = 120,               -- FOV circle radius in pixels (target gating)
	prediction = 0.1,        -- linear lead factor (Humanoid.MoveDirection * WalkSpeed * this)
	reach = 1,               -- murderer HRP hitbox size multiplier
	aimConnection = nil,
	-- FOV circle (Drawing)
	fovCircleEnabled = false,
	fovCircle = nil,
	fovConnection = nil,
	-- Gun reach / hitbox expander on the murderer
	reachEnabled = false,
	reachConnection = nil,
	savedMurdererPart = nil,
	savedMurdererSize = nil,
	-- RECON-GATED (require MM2's real shoot remote): logic built, fire stubbed
	silentAimEnabled = false,
	silentConnection = nil,
	autoShootEnabled = false,
	autoShootConnection = nil,
	lastFire = 0,
	lastSilentLog = 0,
}

local qolState = {
	enabled = false,
	-- FPS counter / watermark
	watermarkEnabled = true,
	watermarkLabel = nil,
	watermarkConn = nil,
	fps = 60,
	fpsThrottle = 0,
	-- FPS booster / low graphics
	fpsBoostEnabled = false,
	origQualityLevel = nil,
	origGlobalShadows = nil,
	origWaterWaveSize = nil,
	-- Freecam
	freecamEnabled = false,
	freecamConn = nil,
	freecamPos = nil,
	freecamYaw = 0,
	freecamPitch = 0,
	freecamSpeed = 60,
	-- Click TP
	clickTpEnabled = false,
	clickTpConn = nil,
	mouse = nil,
	-- Save / Load position
	savedPos = nil,
	-- Auto-rejoin on death
	autoRejoinEnabled = false,
	autoRejoinConn = nil,
	-- Chat spy / logger
	chatSpyEnabled = false,
	chatSpyConns = {},
	-- Keybinds UI
	capturingBind = nil,
	bindButtons = {},
	bindInfoLabel = nil,
	-- Feature search
	searchQuery = "",
	-- respawn hook (assigned by Bundle 4 do-block)
	onRespawn = nil,
}

local configState = {
	enabled = false,
	values = {},
	registry = {},
}

-- Bundle 5 - EXTRAS grab-bag (ghost/dodge/trap-avoid/hip-height/join-logger/UI keybind)
local extrasState = {
	enabled = false,
	-- Ghost mode (local-visual: noclip + transparency)
	ghostEnabled = false,
	ghostConnection = nil,
	ghostTransparency = 0.6,
	-- Auto-dodge murderer knife (pure movement nudge, no remote)
	dodgeEnabled = false,
	dodgeConnection = nil,
	dodgeDistance = 12,
	dodgeCooldown = 0.35,
	lastDodge = 0,
	dodgeActiveUntil = 0,
	dodgeDir = nil,
	dodgeThrowRadius = 60,
	dodgeThrowSpeed = 45,
	dodgeMeleeRange = 9,
	-- Trap auto-avoid (reuses name-based trap detection from Trapdoor ESP)
	trapAvoidEnabled = false,
	trapAvoidConnection = nil,
	trapAvoidRadius = 10,
	lastTrapNudge = 0,
	-- Hip height (re-applied on respawn; 2 = leave default)
	hipHeightValue = 2,
	-- Player-join logger
	joinLoggerEnabled = false,
	joinLoggerConn = nil,
	-- respawn hook (assigned by the Bundle 5 do-block)
	onRespawn = nil,
}

-- ===================== MOBILE / RESIZE DETECTION =====================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local ORIG_W = 580
local ORIG_H = 420
local windowW = ORIG_W
local windowH = ORIG_H
if isMobile then
	windowW = math.min(math.floor(screenSize.X * 0.92), ORIG_W)
	windowH = math.min(math.floor(screenSize.Y * 0.7), ORIG_H)
	if windowW < 320 then windowW = 320 end
	if windowH < 280 then windowH = 280 end
end

-- ===================== SCREEN GUI =====================
-- Kill old instance if re-executing
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("SXMM2")
	if old then old:Destroy() end
end)
pcall(function()
	local old = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("SXMM2")
	if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SXMM2"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true

pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ===================== UTILITY FUNCTIONS =====================
local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function addStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or COLORS.border
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function addPadding(parent, top, right, bottom, left)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, top or 0)
	p.PaddingRight = UDim.new(0, right or 0)
	p.PaddingBottom = UDim.new(0, bottom or 0)
	p.PaddingLeft = UDim.new(0, left or 0)
	p.Parent = parent
	return p
end

local function findPlayer(name)
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
			return p
		end
	end
	return nil
end

-- ===================== GAME-SPECIFIC HELPERS =====================

local function getPlayerRole(player)
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")

	-- Check character for equipped tools
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") then
				if tool.Name == "Knife" or tool.Name:lower():find("knife") then return "Murderer" end
				if tool.Name == "Gun" or tool.Name == "Revolver" or tool.Name:lower():find("gun") or tool.Name:lower():find("revolver") then return "Sheriff" end
			end
		end
	end

	-- Check backpack for unequipped tools
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				if tool.Name == "Knife" or tool.Name:lower():find("knife") then return "Murderer" end
				if tool.Name == "Gun" or tool.Name == "Revolver" or tool.Name:lower():find("gun") or tool.Name:lower():find("revolver") then return "Sheriff" end
			end
		end
	end

	return "Innocent"
end

local function scanRoles()
	roleState.murdererPlayer = nil
	roleState.sheriffPlayer = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local role = getPlayerRole(player)
		if role == "Murderer" then roleState.murdererPlayer = player end
		if role == "Sheriff" then roleState.sheriffPlayer = player end
		if player == LocalPlayer then roleState.myRole = role end
	end
end

local function findGunDrop()
	-- Search workspace for dropped gun
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name == "Revolver" or obj.Name:lower():find("gun")) then
			return obj
		end
	end
	-- Also check GunDrop folder if it exists
	local gunDrop = workspace:FindFirstChild("GunDrop")
	if gunDrop then
		for _, obj in ipairs(gunDrop:GetChildren()) do
			if obj:IsA("Tool") or obj:IsA("Model") then return obj end
		end
	end
	return nil
end

local function getCoins()
	local coins = {}
	-- Check common coin container names
	for _, name in ipairs({"CoinContainer", "Coins", "CoinFolder"}) do
		local container = workspace:FindFirstChild(name)
		if container then
			for _, coin in ipairs(container:GetDescendants()) do
				if coin:IsA("BasePart") and coin.Transparency < 1 then
					table.insert(coins, coin)
				end
			end
		end
	end
	-- Fallback: search workspace for small parts that look like coins
	if #coins == 0 then
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name:lower():find("coin") and obj.Transparency < 1 then
				table.insert(coins, obj)
			end
		end
	end
	return coins
end

-- ===================== GUI SETUP (WindUI) =====================
-- The hand-built window, tab bar, drag handling and mobile toggle were
-- replaced with WindUI. The builder functions keep their original names and
-- signatures and now produce WindUI elements, so every feature call site is
-- untouched; only these bodies and the window setup changed.
local WindUI
do
	local ok, lib = pcall(function()
		return loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
	end)
	if not ok or not lib then
		warn("[SX] WindUI failed to load: " .. tostring(lib))
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Pebbleford Hub",
				Text = "UI library failed to load. Check your internet/executor.",
				Duration = 8,
			})
		end)
		return
	end
	WindUI = lib
	_G.SX_UI = lib
end

local tabNames = {"Main", "Combat", "ESP", "Farming", "Player", "Fun", "Config"}
local tabFrames = {}

local Window = WindUI:CreateWindow({
	Title = "MM2 Hub",
	Author = "Pebbleford Hub",
	Folder = "PebblefordHub",
	Size = UDim2.fromOffset(560, 440),
	HideSearchBar = false,
	OpenButton = { Title = "Hub", Enabled = true, Draggable = true, OnlyMobile = false },
})

for _, name in ipairs(tabNames) do
	tabFrames[name] = Window:Tab({Title = name})
end

local function switchTab(tabName) uiState = uiState or {}; uiState.activeTab = tabName end

-- ===================== UI COMPONENT BUILDERS (WindUI) =====================
-- order is accepted and ignored; WindUI lays out in creation order.
local function createSectionLabel(parent, text, order)
	if not parent then return end
	return parent:Section({Title = text})
end
local function createInfoLabel(parent, text, order)
	if not parent then return end
	return parent:Paragraph({Title = text})
end
local function createDynamicLabel(parent, text)
	if not parent then return setmetatable({}, {__newindex = function() end}) end
	local para = parent:Paragraph({Title = tostring(text or "")})
	local last = tostring(text or "")
	return setmetatable({}, {
		__newindex = function(_, k, v)
			if k == "Text" then
				local str = tostring(v)
				if str ~= last then last = str; pcall(function() para:SetTitle(str) end) end
			end
		end,
		__index = function() return nil end,
	})
end
local function createToggle(parent, text, order, callback)
	if not parent then return end
	return parent:Toggle({Title = text, Value = false, Callback = function(v)
		if callback then pcall(callback, v) end
	end})
end
local function createActionButton(parent, text, order, callback)
	if not parent then return end
	return parent:Button({Title = text, Callback = function()
		if callback then pcall(callback) end
	end})
end
local createButton = createActionButton
local function createSlider(parent, text, min, max, default, order, callback)
	if not parent then return end
	return parent:Slider({Title = text, Step = 1, Value = {Min = min, Max = max, Default = default},
		Callback = function(v)
			local n = type(v) == "table" and (v.Value or v.Default) or v
			if callback and type(n) == "number" then pcall(callback, n) end
		end})
end
local function createDropdown(parent, text, options, default, callback)
	if not parent then return end
	return parent:Dropdown({Title = text, Values = options, Value = default, Callback = function(c)
		local val = type(c) == "table" and c[1] or c
		if callback and val then pcall(callback, val) end
	end})
end
local function createInput(parent, text, placeholder, callback)
	if not parent then return end
	return parent:Input({Title = text, Placeholder = placeholder or "", Callback = function(v)
		if callback then pcall(callback, v) end
	end})
end
local function createSpacer(parent, order) return nil end

-- ===================== LOG SYSTEM =====================
local logFrame

local function addLog(msg, color)
	print("[SX] " .. tostring(msg))
	table.insert(uiState.logLines, {text = msg, color = color or COLORS.textSecondary})
	if #uiState.logLines > uiState.MAX_LOG_LINES then
		table.remove(uiState.logLines, 1)
	end
	if logFrame then
		for _, child in ipairs(logFrame:GetChildren()) do
			if child:IsA("TextLabel") then child:Destroy() end
		end
		for i, line in ipairs(uiState.logLines) do
			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(1, 0, 0, 14)
			l.BackgroundTransparency = 1
			l.Text = line.text
			l.TextColor3 = line.color
			l.Font = Enum.Font.Code
			l.TextSize = 11
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.TextTruncate = Enum.TextTruncate.AtEnd
			l.LayoutOrder = i
			l.Parent = logFrame
		end
		logFrame.CanvasSize = UDim2.new(0, 0, 0, #uiState.logLines * 16)
		logFrame.CanvasPosition = Vector2.new(0, math.max(0, #uiState.logLines * 16 - logFrame.AbsoluteSize.Y))
	end
end

-- =====================================================================
-- ===================== SHARED CORES (Bundle 0) =======================
-- Self-contained helpers reused by later feature bundles.
-- =====================================================================

-- ---- (a) safeDrawing: Drawing.new wrapper + world-to-screen ----
local function newDrawing(kind, props)
	if not Drawing then return nil end
	local ok, d = pcall(function()
		local obj = Drawing.new(kind)
		for k, v in pairs(props or {}) do
			obj[k] = v
		end
		return obj
	end)
	return ok and d or nil
end

local function worldToScreen(pos)
	local ok, vec, onScreen = pcall(function()
		local v, on = Camera:WorldToViewportPoint(pos)
		return v, on
	end)
	if not ok or not vec then
		return Vector2.new(0, 0), false, 0
	end
	return Vector2.new(vec.X, vec.Y), onScreen, vec.Z
end

-- ---- (b) keybind registry (single global InputBegan handler) ----
local keybinds = {}

local function bindKey(name, keyCodeName, fn)
	keybinds[name] = {key = keyCodeName, fn = fn}
end

local function setKeybind(name, keyCodeName)
	if keybinds[name] then
		keybinds[name].key = keyCodeName
	else
		keybinds[name] = {key = keyCodeName, fn = nil}
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	pcall(function()
		local pressed = input.KeyCode.Name
		for _, bind in pairs(keybinds) do
			if bind.key == pressed and bind.fn then
				bind.fn()
			end
		end
	end)
end)

-- ---- (c) config core: save/load a flat feature->value map ----
local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "MM2Hub_config.json"

function configState.saveConfig()
	-- snapshot every registered feature toggle state into configState.values
	configState.values = configState.values or {}
	if configState.registry then
		for name, entry in pairs(configState.registry) do
			pcall(function()
				if entry and entry.get then
					configState.values[name] = entry.get()
				end
			end)
		end
	end
	local ok = pcall(function()
		if not writefile then error("no writefile") end
		local json = HttpService:JSONEncode(configState.values or {})
		writefile(CONFIG_FILE, json)
	end)
	if ok then
		addLog("[CONFIG] Saved to " .. CONFIG_FILE, COLORS.success)
	else
		addLog("[CONFIG] Snapshot kept in memory (no file IO)", COLORS.error)
	end
end

function configState.loadConfig()
	local ok = pcall(function()
		if not (isfile and readfile) then error("no file IO") end
		if not isfile(CONFIG_FILE) then error("no config file") end
		local json = readfile(CONFIG_FILE)
		local decoded = HttpService:JSONDecode(json)
		if type(decoded) == "table" then
			configState.values = decoded
		end
	end)
	-- apply loaded values through the registered setters (best-effort)
	local applied = 0
	if configState.registry and type(configState.values) == "table" then
		for name, entry in pairs(configState.registry) do
			if configState.values[name] ~= nil and entry and entry.set then
				local oks = pcall(function() entry.set(configState.values[name]) end)
				if oks then applied = applied + 1 end
			end
		end
	end
	if ok then
		addLog("[CONFIG] Loaded from " .. CONFIG_FILE .. " (" .. applied .. " applied)", COLORS.success)
	else
		addLog("[CONFIG] Applied in-memory config (" .. applied .. " applied)", COLORS.error)
	end
end

-- ===================== ROLE DETECTION SYSTEM =====================
local function startRoleCheck()
	roleState.roleCheckEnabled = true
	roleState.roleCheckConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local now = tick()
			if now - roleState.lastRoleScan < 0.5 then return end
			roleState.lastRoleScan = now

			scanRoles()

			-- Update role label dynamically
			if uiState.roleLabel then
				local roleText = "Role: " .. roleState.myRole
				if roleState.murdererPlayer then
					roleText = roleText .. " | Murderer: " .. roleState.murdererPlayer.DisplayName
				end
				if roleState.sheriffPlayer then
					roleText = roleText .. " | Sheriff: " .. roleState.sheriffPlayer.DisplayName
				end
				uiState.roleLabel.Text = roleText
			end
		end)
	end)
	addLog("[ROLE CHECK] ON - Scanning roles every 0.5s", COLORS.success)
end

local function stopRoleCheck()
	roleState.roleCheckEnabled = false
	if roleState.roleCheckConnection then roleState.roleCheckConnection:Disconnect() roleState.roleCheckConnection = nil end
	roleState.myRole = "Unknown"
	roleState.murdererPlayer = nil
	roleState.sheriffPlayer = nil
	addLog("[ROLE CHECK] OFF", COLORS.error)
end

-- ===================== MURDERER ESP =====================
local updateMurdererEsp  -- forward-declared so the standalone driver below can call it

local function enableMurdererEsp()
	-- Drive the ESP refresh on its own connection so it works even when Player ESP is off
	if combatState.murdererEspConnection then combatState.murdererEspConnection:Disconnect() combatState.murdererEspConnection = nil end
	combatState.murdererEspConnection = RunService.Heartbeat:Connect(function()
		pcall(updateMurdererEsp)
	end)
	addLog("[MURDERER ESP] ON - Red highlight on murderer", COLORS.success)
end

local function disableMurdererEsp()
	if combatState.murdererEspConnection then combatState.murdererEspConnection:Disconnect() combatState.murdererEspConnection = nil end
	if combatState.murdererEspHighlight then pcall(function() combatState.murdererEspHighlight:Destroy() end) combatState.murdererEspHighlight = nil end
	addLog("[MURDERER ESP] OFF", COLORS.error)
end

function updateMurdererEsp()
	-- Remove stale highlight
	if combatState.murdererEspHighlight then
		local alive = false
		pcall(function() if combatState.murdererEspHighlight and combatState.murdererEspHighlight.Adornee and combatState.murdererEspHighlight.Adornee.Parent then alive = true end end)
		if not alive then
			pcall(function() combatState.murdererEspHighlight:Destroy() end)
			combatState.murdererEspHighlight = nil
		end
	end

	if not combatState.murdererEspEnabled then
		if combatState.murdererEspHighlight then pcall(function() combatState.murdererEspHighlight:Destroy() end) combatState.murdererEspHighlight = nil end
		return
	end

	if roleState.murdererPlayer and roleState.murdererPlayer.Character and roleState.murdererPlayer.Character.Parent then
		if not combatState.murdererEspHighlight or not combatState.murdererEspHighlight.Parent then
			pcall(function()
				combatState.murdererEspHighlight = Instance.new("Highlight")
				combatState.murdererEspHighlight.Name = "MurdererESP"
				combatState.murdererEspHighlight.FillColor = Color3.fromRGB(255, 0, 0)
				combatState.murdererEspHighlight.OutlineColor = Color3.fromRGB(255, 50, 50)
				combatState.murdererEspHighlight.FillTransparency = 0.3
				combatState.murdererEspHighlight.OutlineTransparency = 0
				combatState.murdererEspHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				combatState.murdererEspHighlight.Adornee = roleState.murdererPlayer.Character
				combatState.murdererEspHighlight.Parent = roleState.murdererPlayer.Character
			end)
		end
	else
		if combatState.murdererEspHighlight then pcall(function() combatState.murdererEspHighlight:Destroy() end) combatState.murdererEspHighlight = nil end
	end
end

-- ===================== MURDERER ALERT =====================
local function startMurdererAlert()
	combatState.alertConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not roleState.murdererPlayer then return end
			local myChar = LocalPlayer.Character
			local theirChar = roleState.murdererPlayer.Character
			if not myChar or not theirChar then return end
			local myRoot = myChar:FindFirstChild("HumanoidRootPart")
			local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
			if not myRoot or not theirRoot then return end
			local dist = (myRoot.Position - theirRoot.Position).Magnitude
			if dist < 30 and not combatState.alertActive then
				combatState.alertActive = true
				addLog("[ALERT] MURDERER NEARBY! (" .. math.floor(dist) .. "m)", COLORS.error)
				-- Flash screen border red
				_spawn(function()
					for flashIdx = 1, 3 do
						pcall(function()
							if combatState.alertFrame then combatState.alertFrame:Destroy() combatState.alertFrame = nil end
							combatState.alertFrame = Instance.new("Frame")
							combatState.alertFrame.Name = "AlertFlash"
							combatState.alertFrame.Size = UDim2.new(1, 0, 1, 0)
							combatState.alertFrame.Position = UDim2.new(0, 0, 0, 0)
							combatState.alertFrame.BackgroundTransparency = 1
							combatState.alertFrame.Parent = screenGui
							combatState.alertFrame.ZIndex = 100

							-- Top border
							local topBorder = Instance.new("Frame")
							topBorder.Size = UDim2.new(1, 0, 0, 6)
							topBorder.Position = UDim2.new(0, 0, 0, 0)
							topBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
							topBorder.BackgroundTransparency = 0.2
							topBorder.BorderSizePixel = 0
							topBorder.Parent = combatState.alertFrame

							-- Bottom border
							local bottomBorder = Instance.new("Frame")
							bottomBorder.Size = UDim2.new(1, 0, 0, 6)
							bottomBorder.Position = UDim2.new(0, 0, 1, -6)
							bottomBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
							bottomBorder.BackgroundTransparency = 0.2
							bottomBorder.BorderSizePixel = 0
							bottomBorder.Parent = combatState.alertFrame

							-- Left border
							local leftBorder = Instance.new("Frame")
							leftBorder.Size = UDim2.new(0, 6, 1, 0)
							leftBorder.Position = UDim2.new(0, 0, 0, 0)
							leftBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
							leftBorder.BackgroundTransparency = 0.2
							leftBorder.BorderSizePixel = 0
							leftBorder.Parent = combatState.alertFrame

							-- Right border
							local rightBorder = Instance.new("Frame")
							rightBorder.Size = UDim2.new(0, 6, 1, 0)
							rightBorder.Position = UDim2.new(1, -6, 0, 0)
							rightBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
							rightBorder.BackgroundTransparency = 0.2
							rightBorder.BorderSizePixel = 0
							rightBorder.Parent = combatState.alertFrame
						end)
						_wait(0.2)
						pcall(function()
							if combatState.alertFrame then combatState.alertFrame:Destroy() combatState.alertFrame = nil end
						end)
						_wait(0.1)
					end
					combatState.alertActive = false
				end)
			elseif dist >= 30 then
				combatState.alertActive = false
			end
		end)
	end)
	addLog("[ALERT] ON - Warning when murderer is within 30 studs", COLORS.success)
end

local function stopMurdererAlert()
	if combatState.alertConnection then combatState.alertConnection:Disconnect() combatState.alertConnection = nil end
	if combatState.alertFrame then pcall(function() combatState.alertFrame:Destroy() end) combatState.alertFrame = nil end
	combatState.alertActive = false
	addLog("[ALERT] OFF", COLORS.error)
end

-- ===================== AUTO SHOOT MURDERER (SHERIFF ONLY) =====================
local function startAutoShootMurderer()
	combatState.autoShootConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if roleState.myRole ~= "Sheriff" then return end
			if not roleState.murdererPlayer then return end
			local theirChar = roleState.murdererPlayer.Character
			if not theirChar then return end
			local theirHum = theirChar:FindFirstChildOfClass("Humanoid")
			if theirHum and theirHum.Health <= 0 then return end
			local theirHead = theirChar:FindFirstChild("Head") or theirChar:FindFirstChild("HumanoidRootPart")
			if not theirHead then return end

			local myChar = LocalPlayer.Character
			if not myChar then return end
			local myRoot = myChar:FindFirstChild("HumanoidRootPart")
			if not myRoot then return end

			-- Find equipped gun tool
			local gunTool = nil
			for _, child in ipairs(myChar:GetChildren()) do
				if child:IsA("Tool") and (child.Name == "Gun" or child.Name == "Revolver" or child.Name:lower():find("gun") or child.Name:lower():find("revolver")) then
					gunTool = child
					break
				end
			end
			if not gunTool then return end

			-- Snap camera to look directly at murderer's head
			local cam = workspace.CurrentCamera
			cam.CFrame = CFrame.new(cam.CFrame.Position, theirHead.Position)

			-- Fire the gun via tool activation
			pcall(function() gunTool:Activate() end)
		end)
	end)
	addLog("[AUTO SHOOT] ON - Snapping aim at murderer (Sheriff only)", COLORS.success)
end

local function stopAutoShootMurderer()
	if combatState.autoShootConnection then combatState.autoShootConnection:Disconnect() combatState.autoShootConnection = nil end
	addLog("[AUTO SHOOT] OFF", COLORS.error)
end

-- ===================== TP KILL MURDERER =====================
local function tpKillMurderer()
	pcall(function()
		if roleState.myRole ~= "Sheriff" then
			addLog("[TP KILL] You must be Sheriff!", COLORS.error)
			return
		end
		if not roleState.murdererPlayer then
			addLog("[TP KILL] No murderer detected!", COLORS.error)
			return
		end
		local theirChar = roleState.murdererPlayer.Character
		if not theirChar then
			addLog("[TP KILL] Murderer has no character!", COLORS.error)
			return
		end
		local theirHum = theirChar:FindFirstChildOfClass("Humanoid")
		if theirHum and theirHum.Health <= 0 then
			addLog("[TP KILL] Murderer is already dead!", COLORS.error)
			return
		end
		local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
		local theirHead = theirChar:FindFirstChild("Head") or theirRoot
		if not theirRoot or not theirHead then return end

		local myChar = LocalPlayer.Character
		if not myChar then return end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		if not myRoot then return end

		-- Find gun in backpack or equipped
		local gunTool = nil
		for _, child in ipairs(myChar:GetChildren()) do
			if child:IsA("Tool") and (child.Name == "Gun" or child.Name == "Revolver" or child.Name:lower():find("gun") or child.Name:lower():find("revolver")) then
				gunTool = child
				break
			end
		end
		if not gunTool then
			local backpack = LocalPlayer:FindFirstChild("Backpack")
			if backpack then
				for _, child in ipairs(backpack:GetChildren()) do
					if child:IsA("Tool") and (child.Name == "Gun" or child.Name == "Revolver" or child.Name:lower():find("gun") or child.Name:lower():find("revolver")) then
						gunTool = child
						break
					end
				end
			end
		end
		if not gunTool then
			addLog("[TP KILL] No gun found!", COLORS.error)
			return
		end

		-- Equip gun if in backpack
		if gunTool.Parent ~= myChar then
			local hum = myChar:FindFirstChildOfClass("Humanoid")
			if hum then hum:EquipTool(gunTool) end
			_wait(0.1)
		end

		-- TP behind murderer
		local behindCF = theirRoot.CFrame * CFrame.new(0, 0, 5)
		myRoot.CFrame = behindCF

		-- Snap camera and fire
		_wait(0.05)
		local cam = workspace.CurrentCamera
		cam.CFrame = CFrame.new(cam.CFrame.Position, theirHead.Position)
		_wait(0.05)
		pcall(function() gunTool:Activate() end)
		_wait(0.1)
		pcall(function() gunTool:Activate() end)

		addLog("[TP KILL] Shot at " .. roleState.murdererPlayer.DisplayName, COLORS.success)
	end)
end

-- ===================== GRAB DROPPED GUN =====================
local function grabDroppedGun()
	pcall(function()
		local gun = findGunDrop()
		if not gun then
			addLog("[GUN] No dropped gun found!", COLORS.error)
			return
		end

		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			addLog("[GUN] No character found!", COLORS.error)
			return
		end

		-- Find the gun's position
		local gunPart = nil
		if gun:IsA("BasePart") then
			gunPart = gun
		elseif gun:IsA("Tool") then
			gunPart = gun:FindFirstChild("Handle") or gun:FindFirstChildWhichIsA("BasePart")
		elseif gun:IsA("Model") then
			gunPart = gun.PrimaryPart or gun:FindFirstChildWhichIsA("BasePart")
		end

		if gunPart then
			root.CFrame = gunPart.CFrame + Vector3.new(0, 3, 0)
			addLog("[GUN] Teleported to dropped gun!", COLORS.success)
			-- Try to pick it up by touching it
			_spawn(function()
				_wait(0.2)
				pcall(function()
					if root and root.Parent then
						root.CFrame = gunPart.CFrame
					end
				end)
			end)
		else
			addLog("[GUN] Could not find gun position!", COLORS.error)
		end
	end)
end

-- ===================== AUTO GRAB GUN =====================
local function startAutoGrabGun()
	miscState.autoGrabConnection = workspace.ChildAdded:Connect(function(child)
		if not miscState.autoGrabGunEnabled then return end
		_wait(0.3)
		pcall(function()
			if child:IsA("Tool") and (child.Name == "Gun" or child.Name == "Revolver" or child.Name:lower():find("gun")) then
				addLog("[AUTO GRAB] Gun dropped! Teleporting...", COLORS.accent)
				local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local handle = child:FindFirstChild("Handle") or child:FindFirstChildWhichIsA("BasePart")
					if handle then
						root.CFrame = handle.CFrame + Vector3.new(0, 3, 0)
						_wait(0.2)
						pcall(function()
							if root and root.Parent and handle and handle.Parent then
								root.CFrame = handle.CFrame
							end
						end)
						addLog("[AUTO GRAB] Grabbed the gun!", COLORS.success)
					end
				end
			end
		end)
	end)
	-- Also check GunDrop folder
	local gunDrop = workspace:FindFirstChild("GunDrop")
	if gunDrop then
		local gdConn = gunDrop.ChildAdded:Connect(function(child)
			if not miscState.autoGrabGunEnabled then return end
			_wait(0.3)
			pcall(function()
				local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local gunPart = nil
					if child:IsA("BasePart") then
						gunPart = child
					elseif child:IsA("Tool") then
						gunPart = child:FindFirstChild("Handle") or child:FindFirstChildWhichIsA("BasePart")
					elseif child:IsA("Model") then
						gunPart = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
					end
					if gunPart then
						addLog("[AUTO GRAB] Item in GunDrop! Teleporting...", COLORS.accent)
						root.CFrame = gunPart.CFrame + Vector3.new(0, 3, 0)
						_wait(0.2)
						pcall(function()
							if root and root.Parent and gunPart and gunPart.Parent then
								root.CFrame = gunPart.CFrame
							end
						end)
						addLog("[AUTO GRAB] Grabbed from GunDrop!", COLORS.success)
					end
				end
			end)
		end)
		miscState.autoGrabGunDropConnection = gdConn
	end
	addLog("[AUTO GRAB] ON - Watching for gun drops", COLORS.success)
end

local function stopAutoGrabGun()
	if miscState.autoGrabConnection then miscState.autoGrabConnection:Disconnect() miscState.autoGrabConnection = nil end
	if miscState.autoGrabGunDropConnection then miscState.autoGrabGunDropConnection:Disconnect() miscState.autoGrabGunDropConnection = nil end
	addLog("[AUTO GRAB] OFF", COLORS.error)
end

-- ===================== PLAYER ESP (Role-Based Colors) =====================
local function addPlayerHighlight(player)
	if player == LocalPlayer then return end
	if espState.playerEspHighlights[player] then return end
	local character = player.Character
	if not character or not character.Parent then return end
	pcall(function()
		local role = getPlayerRole(player)
		local espColor = ROLE_COLORS[role] or ROLE_COLORS.Unknown

		local highlight = Instance.new("Highlight")
		highlight.Name = "ESPHighlight"
		highlight.FillColor = espColor
		highlight.OutlineColor = espColor
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Adornee = character
		highlight.Parent = character
		espState.playerEspHighlights[player] = highlight
	end)
end

local function addPlayerNametag(player)
	if player == LocalPlayer then return end
	if espState.playerEspNametags[player] then return end
	local character = player.Character
	if not character or not character.Parent then return end
	local head = character:FindFirstChild("Head")
	if not head then return end
	pcall(function()
		local role = getPlayerRole(player)
		local espColor = ROLE_COLORS[role] or ROLE_COLORS.Unknown

		local bb = Instance.new("BillboardGui")
		bb.Name = "ESPNametag"
		bb.Adornee = head
		bb.Size = UDim2.new(0, 200, 0, 80)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.Parent = character

		local yOffset = 0

		-- Name label
		if espState.showNamesEnabled then
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, 0, 0, 18)
			nameLabel.Position = UDim2.new(0, 0, 0, yOffset)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = player.DisplayName
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLabel.TextStrokeTransparency = 0.3
			nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 14
			nameLabel.Parent = bb
			yOffset = yOffset + 18
		end

		-- Role label
		if espState.showRoleEnabled then
			local roleLabelTag = Instance.new("TextLabel")
			roleLabelTag.Size = UDim2.new(1, 0, 0, 14)
			roleLabelTag.Position = UDim2.new(0, 0, 0, yOffset)
			roleLabelTag.BackgroundTransparency = 1
			roleLabelTag.Text = "[" .. role .. "]"
			roleLabelTag.TextColor3 = espColor
			roleLabelTag.TextStrokeTransparency = 0.3
			roleLabelTag.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			roleLabelTag.Font = Enum.Font.GothamBold
			roleLabelTag.TextSize = 12
			roleLabelTag.Parent = bb
			yOffset = yOffset + 14
		end

		-- Distance label
		if espState.showDistanceEnabled then
			local distLabel = Instance.new("TextLabel")
			distLabel.Name = "DistLabel"
			distLabel.Size = UDim2.new(1, 0, 0, 14)
			distLabel.Position = UDim2.new(0, 0, 0, yOffset)
			distLabel.BackgroundTransparency = 1
			distLabel.Text = "[?m]"
			distLabel.TextColor3 = Color3.fromRGB(170, 170, 255)
			distLabel.TextStrokeTransparency = 0.4
			distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			distLabel.Font = Enum.Font.Gotham
			distLabel.TextSize = 12
			distLabel.Parent = bb

			local distConn = RunService.Heartbeat:Connect(function()
				pcall(function()
					if not bb or not bb.Parent then return end
					local myChar = LocalPlayer.Character
					local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
					local theirRoot = character and character:FindFirstChild("HumanoidRootPart")
					if myRoot and theirRoot then
						distLabel.Text = "[" .. math.floor((myRoot.Position - theirRoot.Position).Magnitude) .. "m]"
					end
				end)
			end)
			espState.playerEspDistConns[player] = distConn
		end

		espState.playerEspNametags[player] = bb
	end)
end

local function removePlayerHighlight(player)
	local hl = espState.playerEspHighlights[player]
	if hl then pcall(function() hl:Destroy() end) end
	espState.playerEspHighlights[player] = nil
end

local function removePlayerNametag(player)
	local tag = espState.playerEspNametags[player]
	if tag then pcall(function() tag:Destroy() end) end
	espState.playerEspNametags[player] = nil
	local dc = espState.playerEspDistConns and espState.playerEspDistConns[player]
	if dc then pcall(function() dc:Disconnect() end) espState.playerEspDistConns[player] = nil end
end

local function cleanupStalePlayerEsp()
	local staleHL, staleNT = {}, {}
	for player, hl in pairs(espState.playerEspHighlights) do
		local alive = false
		pcall(function() if hl and hl.Adornee and hl.Adornee.Parent then alive = true end end)
		if not alive then table.insert(staleHL, player) end
	end
	for player, tag in pairs(espState.playerEspNametags) do
		local alive = false
		pcall(function() if tag and tag.Parent then alive = true end end)
		if not alive then table.insert(staleNT, player) end
	end
	for _, player in ipairs(staleHL) do removePlayerHighlight(player) end
	for _, player in ipairs(staleNT) do removePlayerNametag(player) end
end

local function playerEspScanAll()
	cleanupStalePlayerEsp()
	local count, skipped = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			if character and character.Parent then
				-- Remove and re-add to update role colors
				removePlayerHighlight(player)
				removePlayerNametag(player)
				addPlayerHighlight(player)
				addPlayerNametag(player)
				count = count + 1
			else
				skipped = skipped + 1
			end
		end
	end
	return count, skipped
end

local function hookPlayerForEsp(player)
	if player == LocalPlayer then return end
	local conn = player.CharacterAdded:Connect(function()
		if not espState.espEnabled then return end
		_wait(1)
		if espState.espEnabled then addPlayerHighlight(player) addPlayerNametag(player) end
	end)
	table.insert(espState.espConnections, conn)
end

local function enablePlayerEsp()
	for _, player in ipairs(Players:GetPlayers()) do hookPlayerForEsp(player) end
	local addedConn = Players.PlayerAdded:Connect(function(player)
		if not espState.espEnabled then return end
		hookPlayerForEsp(player)
	end)
	table.insert(espState.espConnections, addedConn)
	local count, skipped = playerEspScanAll()
	addLog("[ESP] ON - " .. count .. " highlighted, " .. skipped .. " pending", COLORS.success)
	if not espState.refreshRunning then
		espState.refreshRunning = true
		_spawn(function()
			while espState.espEnabled do
				_wait(espState.REFRESH_INTERVAL)
				if not espState.espEnabled then break end
				playerEspScanAll()
				-- Also update murderer ESP while we're at it
				updateMurdererEsp()
			end
			espState.refreshRunning = false
		end)
	end
end

local function disablePlayerEsp()
	local allP = {}
	for player in pairs(espState.playerEspHighlights) do table.insert(allP, player) end
	for _, player in ipairs(allP) do removePlayerHighlight(player) end
	local allN = {}
	for player in pairs(espState.playerEspNametags) do table.insert(allN, player) end
	for _, player in ipairs(allN) do removePlayerNametag(player) end
	for _, dc in pairs(espState.playerEspDistConns) do pcall(function() dc:Disconnect() end) end
	espState.playerEspDistConns = {}
	for _, conn in ipairs(espState.espConnections) do pcall(function() conn:Disconnect() end) end
	espState.espConnections = {}
	addLog("[ESP] OFF", COLORS.error)
end

-- ===================== GUN ESP =====================
local function clearGunEsp()
	for _, hl in pairs(espState.gunEspHighlights) do pcall(function() hl:Destroy() end) end
	espState.gunEspHighlights = {}
end

local function refreshGunEsp()
	clearGunEsp()
	if not espState.gunEspEnabled then return end

	pcall(function()
		-- Search workspace for dropped guns
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name == "Revolver" or obj.Name:lower():find("gun")) then
				local hl = Instance.new("Highlight")
				hl.Name = "GunESP"
				hl.FillColor = Color3.fromRGB(255, 215, 0)
				hl.OutlineColor = Color3.fromRGB(255, 255, 0)
				hl.FillTransparency = 0.3
				hl.OutlineTransparency = 0
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Adornee = obj
				hl.Parent = obj
				table.insert(espState.gunEspHighlights, hl)
			end
		end

		-- Check GunDrop folder
		local gunDrop = workspace:FindFirstChild("GunDrop")
		if gunDrop then
			for _, obj in ipairs(gunDrop:GetChildren()) do
				if obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart") then
					local hl = Instance.new("Highlight")
					hl.Name = "GunESP"
					hl.FillColor = Color3.fromRGB(255, 215, 0)
					hl.OutlineColor = Color3.fromRGB(255, 255, 0)
					hl.FillTransparency = 0.3
					hl.OutlineTransparency = 0
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Adornee = obj
					hl.Parent = obj
					table.insert(espState.gunEspHighlights, hl)
				end
			end
		end
	end)
end

local function enableGunEsp()
	refreshGunEsp()
	-- Watch for new gun drops
	espState.gunEspConnection = workspace.ChildAdded:Connect(function(child)
		if not espState.gunEspEnabled then return end
		_wait(0.3)
		pcall(function()
			if child:IsA("Tool") and (child.Name == "Gun" or child.Name == "Revolver" or child.Name:lower():find("gun")) then
				local hl = Instance.new("Highlight")
				hl.Name = "GunESP"
				hl.FillColor = Color3.fromRGB(255, 215, 0)
				hl.OutlineColor = Color3.fromRGB(255, 255, 0)
				hl.FillTransparency = 0.3
				hl.OutlineTransparency = 0
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Adornee = child
				hl.Parent = child
				table.insert(espState.gunEspHighlights, hl)
			end
		end)
	end)
	-- Periodic refresh
	if not espState.gunEspRefreshRunning then
		espState.gunEspRefreshRunning = true
		_spawn(function()
			while espState.gunEspEnabled do
				_wait(3)
				if not espState.gunEspEnabled then break end
				refreshGunEsp()
			end
			espState.gunEspRefreshRunning = false
		end)
	end
	addLog("[GUN ESP] ON - Yellow highlight on dropped guns", COLORS.success)
end

local function disableGunEsp()
	clearGunEsp()
	if espState.gunEspConnection then espState.gunEspConnection:Disconnect() espState.gunEspConnection = nil end
	addLog("[GUN ESP] OFF", COLORS.error)
end

-- ===================== COIN ESP =====================
local function clearCoinEsp()
	for _, hl in pairs(espState.coinEspHighlights) do pcall(function() hl:Destroy() end) end
	espState.coinEspHighlights = {}
end

local function refreshCoinEsp()
	clearCoinEsp()
	if not espState.coinEspEnabled then return end

	pcall(function()
		local coins = getCoins()
		for _, coin in ipairs(coins) do
			local hl = Instance.new("Highlight")
			hl.Name = "CoinESP"
			hl.FillColor = Color3.fromRGB(255, 200, 0)
			hl.OutlineColor = Color3.fromRGB(255, 215, 0)
			hl.FillTransparency = 0.4
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = coin
			hl.Parent = coin
			table.insert(espState.coinEspHighlights, hl)
		end
	end)
end

local function enableCoinEsp()
	refreshCoinEsp()
	-- Periodic refresh
	if not espState.coinEspRefreshRunning then
		espState.coinEspRefreshRunning = true
		_spawn(function()
			while espState.coinEspEnabled do
				_wait(5)
				if not espState.coinEspEnabled then break end
				refreshCoinEsp()
			end
			espState.coinEspRefreshRunning = false
		end)
	end
	addLog("[COIN ESP] ON - Gold highlight on coins", COLORS.success)
end

local function disableCoinEsp()
	clearCoinEsp()
	addLog("[COIN ESP] OFF", COLORS.error)
end

-- ===================== FULLBRIGHT =====================
local function startFullbright()
	uiState.origAmbient = Lighting.Ambient
	uiState.origBrightness = Lighting.Brightness
	uiState.origFogEnd = Lighting.FogEnd
	uiState.origGlobalShadows = Lighting.GlobalShadows
	Lighting.Ambient = Color3.fromRGB(200, 200, 200)
	Lighting.Brightness = 2
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = false
	addLog("[FULLBRIGHT] ON", COLORS.success)
end

local function stopFullbright()
	if uiState.origAmbient then Lighting.Ambient = uiState.origAmbient end
	if uiState.origBrightness then Lighting.Brightness = uiState.origBrightness end
	if uiState.origFogEnd then Lighting.FogEnd = uiState.origFogEnd end
	if uiState.origGlobalShadows ~= nil then Lighting.GlobalShadows = uiState.origGlobalShadows end
	addLog("[FULLBRIGHT] OFF", COLORS.error)
end

-- ===================== AUTO COIN FARM =====================
local function tweenToPosition(root, targetCFrame, speed)
	local dist = (root.Position - targetCFrame.Position).Magnitude
	local tweenTime = dist / speed
	if tweenTime < 0.1 then tweenTime = 0.1 end
	local tween = TweenService:Create(root, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
	tween:Play()
	return tween
end

local function startAutoCoinFarm()
	farmState.coinsFarmed = 0
	farmState.coinFarmThread = _spawn(function()
		while farmState.autoCoinFarmEnabled do
			pcall(function()
				local coins = getCoins()
				if #coins == 0 then
					addLog("[FARM] No coins found, waiting...", COLORS.textSecondary)
					_wait(2)
					return
				end

				-- Sort by distance so we walk to nearest first
				local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if not root then return end
				table.sort(coins, function(a, b)
					return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
				end)

				for _, coin in ipairs(coins) do
					if not farmState.autoCoinFarmEnabled then break end
					pcall(function()
						root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
						if root and coin and coin.Parent and coin.Transparency < 1 then
							local targetCFrame = coin.CFrame + Vector3.new(0, 2, 0)
							local tweenSpeed = math.max(60, 120 / farmState.farmSpeed)
							local tween = tweenToPosition(root, targetCFrame, tweenSpeed)
							-- Wait for tween to finish or coin to disappear
							local start = tick()
							local dist = (root.Position - targetCFrame.Position).Magnitude
							local maxWait = (dist / tweenSpeed) + 1
							while tween.PlaybackState == Enum.PlaybackState.Playing do
								if not farmState.autoCoinFarmEnabled then tween:Cancel() return end
								if not coin or not coin.Parent or coin.Transparency >= 1 then tween:Cancel() break end
								if tick() - start > maxWait then tween:Cancel() break end
								_wait(0.05)
							end
							farmState.coinsFarmed = farmState.coinsFarmed + 1
							if uiState.coinCountLabel then
								uiState.coinCountLabel.Text = "Coins Farmed: " .. farmState.coinsFarmed
							end
						end
					end)
					_wait(0.1)
				end
			end)
			_wait(0.5)
		end
	end)
	addLog("[FARM] ON - Tweening to coins (speed: " .. farmState.farmSpeed .. "s)", COLORS.success)
end

local function stopAutoCoinFarm()
	farmState.autoCoinFarmEnabled = false
	addLog("[FARM] OFF - Farmed " .. farmState.coinsFarmed .. " coins", COLORS.error)
end

-- ===================== COIN DOMINATION (Bundle 2) =====================
-- Coin Aura: every ~0.1s sweep the HumanoidRootPart to each coin inside a
-- radius, briefly touch it to collect, then snap back to the start position.
-- Re-reads LocalPlayer.Character every iteration so it survives respawn on
-- its own (no re-enable needed in the CharacterAdded handler).
function coinDomState.startCoinAura()
	coinDomState.auraCollected = 0
	coinDomState.auraThread = _spawn(function()
		while coinDomState.auraEnabled do
			pcall(function()
				local char = LocalPlayer.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if not root then return end
				local coins = getCoins()
				if #coins == 0 then return end
				local origin = root.CFrame
				local radius = coinDomState.auraRadius
				local touched = 0
				for _, coin in ipairs(coins) do
					if not coinDomState.auraEnabled then break end
					pcall(function()
						char = LocalPlayer.Character
						root = char and char:FindFirstChild("HumanoidRootPart")
						if root and coin and coin.Parent and coin.Transparency < 1 then
							local dist = (coin.Position - origin.Position).Magnitude
							if dist <= radius then
								root.CFrame = coin.CFrame + Vector3.new(0, 2, 0)
								_wait(0.03)
								touched = touched + 1
								coinDomState.auraCollected = coinDomState.auraCollected + 1
							end
						end
					end)
				end
				-- Return to the sweep origin so the aura is non-disruptive
				char = LocalPlayer.Character
				root = char and char:FindFirstChild("HumanoidRootPart")
				if root and touched > 0 then
					root.CFrame = origin
				end
			end)
			_wait(0.1)
		end
	end)
	addLog("[COIN] Aura ON - radius " .. coinDomState.auraRadius, COLORS.success)
end

function coinDomState.stopCoinAura()
	coinDomState.auraEnabled = false
	addLog("[COIN] Aura OFF - collected " .. coinDomState.auraCollected, COLORS.error)
end

-- TP through EVERY coin once to vacuum the whole map, then return to start.
function coinDomState.tpThroughAllCoins()
	_spawn(function()
		pcall(function()
			local char = LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then
				addLog("[COIN] No character for TP sweep", COLORS.error)
				return
			end
			local coins = getCoins()
			if #coins == 0 then
				addLog("[COIN] No coins found to sweep", COLORS.textSecondary)
				return
			end
			local origin = root.CFrame
			local swept = 0
			for _, coin in ipairs(coins) do
				pcall(function()
					char = LocalPlayer.Character
					root = char and char:FindFirstChild("HumanoidRootPart")
					if root and coin and coin.Parent and coin.Transparency < 1 then
						root.CFrame = coin.CFrame + Vector3.new(0, 2, 0)
						swept = swept + 1
						_wait(0.06)
					end
				end)
			end
			char = LocalPlayer.Character
			root = char and char:FindFirstChild("HumanoidRootPart")
			if root then root.CFrame = origin end
			addLog("[COIN] Swept " .. swept .. " coins", COLORS.success)
		end)
	end)
end

-- Coin tracers: pooled Drawing lines from screen bottom-center to each coin.
function coinDomState.clearCoinTracers()
	for _, line in ipairs(coinDomState.tracerLines) do
		pcall(function() line.Visible = false end)
	end
end

function coinDomState.startCoinTracers()
	if not Drawing then
		addLog("[COIN] Tracers need the executor Drawing API (recon required)", COLORS.error)
		coinDomState.tracersEnabled = false
		return
	end
	if coinDomState.tracerConnection then
		pcall(function() coinDomState.tracerConnection:Disconnect() end)
		coinDomState.tracerConnection = nil
	end
	coinDomState.tracerConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not coinDomState.tracersEnabled then return end
			local coins = getCoins()
			local vp = Camera.ViewportSize
			local originX, originY = vp.X / 2, vp.Y
			local used = 0
			for _, coin in ipairs(coins) do
				pcall(function()
					if coin and coin.Parent and coin.Transparency < 1 then
						local s, onScreen, depth = worldToScreen(coin.Position)
						if onScreen and depth > 0 then
							used = used + 1
							local line = coinDomState.tracerLines[used]
							if not line then
								line = newDrawing("Line", {Thickness = 1, Transparency = 1, Color = COLORS.accent})
								coinDomState.tracerLines[used] = line
							end
							if line then
								line.From = Vector2.new(originX, originY)
								line.To = s
								line.Color = COLORS.accent
								line.Visible = true
							end
						end
					end
				end)
			end
			-- Hide any pooled lines left over from a busier frame
			for i = used + 1, #coinDomState.tracerLines do
				pcall(function() coinDomState.tracerLines[i].Visible = false end)
			end
		end)
	end)
	addLog("[COIN] Tracers ON", COLORS.success)
end

function coinDomState.stopCoinTracers()
	coinDomState.tracersEnabled = false
	if coinDomState.tracerConnection then
		pcall(function() coinDomState.tracerConnection:Disconnect() end)
		coinDomState.tracerConnection = nil
	end
	coinDomState.clearCoinTracers()
	addLog("[COIN] Tracers OFF", COLORS.error)
end

-- Live counter of coins remaining on the map.
function coinDomState.startCoinCounter()
	if coinDomState.counterThread then return end
	coinDomState.counterThread = _spawn(function()
		while true do
			pcall(function()
				if coinDomState.counterLabel then
					coinDomState.counterLabel.Text = "Coins Remaining: " .. #getCoins()
				end
			end)
			_wait(0.5)
		end
	end)
end

-- ===================== ANTI-AFK =====================
local function startAntiAfk()
	farmState.antiAfkConnection = _spawn(function()
		while farmState.antiAfkEnabled do
			pcall(function()
				local vu = game:GetService("VirtualUser")
				vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
				_wait(1)
				vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
			end)
			pcall(function()
				local vim = game:GetService("VirtualInputManager")
				vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
				_wait(0.1)
				vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
			end)
			_wait(300)
		end
	end)
	addLog("[ANTI-AFK] ON", COLORS.success)
end

local function stopAntiAfk()
	farmState.antiAfkEnabled = false
	addLog("[ANTI-AFK] OFF", COLORS.error)
end

-- ===================== FLY LOGIC =====================
local function startFly()
	local character = LocalPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	moveState.bodyGyro = Instance.new("BodyGyro")
	moveState.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	moveState.bodyGyro.P = 9e4
	moveState.bodyGyro.Parent = hrp
	moveState.bodyVelocity = Instance.new("BodyVelocity")
	moveState.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	moveState.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	moveState.bodyVelocity.Parent = hrp
	moveState.flyConnection = RunService.Heartbeat:Connect(function()
		if not moveState.flyEnabled or not hrp or not hrp.Parent then return end
		local cam = workspace.CurrentCamera
		local dir = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
		if dir.Magnitude > 0 then dir = dir.Unit end
		moveState.bodyVelocity.Velocity = dir * moveState.flySpeed
		moveState.bodyGyro.CFrame = cam.CFrame
	end)
	addLog("[FLY] ON - Speed: " .. moveState.flySpeed, COLORS.success)
end

local function stopFly()
	if moveState.flyConnection then moveState.flyConnection:Disconnect() moveState.flyConnection = nil end
	if moveState.bodyGyro then pcall(function() moveState.bodyGyro:Destroy() end) moveState.bodyGyro = nil end
	if moveState.bodyVelocity then pcall(function() moveState.bodyVelocity:Destroy() end) moveState.bodyVelocity = nil end
	addLog("[FLY] OFF", COLORS.error)
end

-- ===================== NOCLIP LOGIC =====================
local function startNoclip()
	if moveState.noclipConnection then pcall(function() moveState.noclipConnection:Disconnect() end) moveState.noclipConnection = nil end
	moveState.noclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end)
	end)
	addLog("[NOCLIP] ON", COLORS.success)
end

local function stopNoclip()
	if moveState.noclipConnection then moveState.noclipConnection:Disconnect() moveState.noclipConnection = nil end
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end)
	addLog("[NOCLIP] OFF", COLORS.error)
end

-- ===================== SPEED LOGIC =====================
local function startSpeed()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then uiState.origWalkSpeed = humanoid.WalkSpeed humanoid.WalkSpeed = moveState.speedValue end
		end
	end)
	addLog("[SPEED] ON - WalkSpeed: " .. moveState.speedValue, COLORS.success)
end

local function stopSpeed()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.WalkSpeed = uiState.origWalkSpeed end
		end
	end)
	addLog("[SPEED] OFF", COLORS.error)
end

-- ===================== GOD MODE LOGIC =====================
local function startGod()
	if moveState.godConnection then pcall(function() moveState.godConnection:Disconnect() end) moveState.godConnection = nil end
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.MaxHealth = math.huge humanoid.Health = math.huge end
		end
	end)
	-- Keep health topped up
	moveState.godConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = math.huge
			end
		end)
	end)
	addLog("[GOD] ON", COLORS.success)
end

local function stopGod()
	if moveState.godConnection then moveState.godConnection:Disconnect() moveState.godConnection = nil end
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.MaxHealth = 100 humanoid.Health = 100 end
		end
	end)
	addLog("[GOD] OFF", COLORS.error)
end

-- ===================== INFINITE JUMP LOGIC =====================
local function startInfJump()
	if moveState.infJumpConnection then pcall(function() moveState.infJumpConnection:Disconnect() end) moveState.infJumpConnection = nil end
	moveState.infJumpConnection = UserInputService.JumpRequest:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
			end
		end)
	end)
	addLog("[INF JUMP] ON", COLORS.success)
end

local function stopInfJump()
	if moveState.infJumpConnection then moveState.infJumpConnection:Disconnect() moveState.infJumpConnection = nil end
	addLog("[INF JUMP] OFF", COLORS.error)
end

-- ===================== JUMP POWER HELPER =====================
local function setJumpPower(value)
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.UseJumpPower = true humanoid.JumpPower = value end
		end
	end)
end

-- ===================== INVISIBLE LOGIC (FE Seat Trick) =====================
local function startInvisible()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local savedCF = hrp.CFrame
		local savedChar = character

		local seat = Instance.new("Seat")
		seat.Size = Vector3.new(1, 1, 1)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Anchored = true
		seat.CFrame = savedCF
		seat.Parent = workspace

		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			seat:Sit(hum)
			_wait(0.2)
			LocalPlayer.Character = nil
			_wait(0.1)
			if hum then hum.Sit = false end
			seat:Destroy()
			_wait(0.1)
			LocalPlayer.Character = savedChar
			if hrp and hrp.Parent then hrp.CFrame = savedCF end
		else
			seat:Destroy()
		end

		miscState.savedTransparencies = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				miscState.savedTransparencies[part] = part.Transparency
				part.Transparency = 1
			elseif part:IsA("Decal") or part:IsA("Texture") then
				miscState.savedTransparencies[part] = part.Transparency
				part.Transparency = 1
			end
		end
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				if handle then miscState.savedTransparencies[handle] = handle.Transparency handle.Transparency = 1 end
			end
		end
	end)
	addLog("[INVISIBLE] ON (FE invisible)", COLORS.success)
end

local function stopInvisible()
	pcall(function()
		for part, transparency in pairs(miscState.savedTransparencies) do
			if part and part.Parent then part.Transparency = transparency end
		end
		miscState.savedTransparencies = {}
		local character = LocalPlayer.Character
		if character then
			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = 0
				addLog("[INVISIBLE] OFF (respawning to restore)", COLORS.error)
				return
			end
		end
	end)
	addLog("[INVISIBLE] OFF", COLORS.error)
end

-- ===================== CAMERA FOV =====================
local function setCameraFOV(fov)
	pcall(function()
		workspace.CurrentCamera.FieldOfView = fov
	end)
end

-- ===================== TP BEHIND PLAYER =====================
local function tpBehindPlayer(targetName)
	pcall(function()
		local target = findPlayer(targetName)
		if not target then
			addLog("[TP BEHIND] Player not found: " .. targetName, COLORS.error)
			return
		end
		local myChar = LocalPlayer.Character
		if not myChar then return end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		if not myRoot then return end
		local theirChar = target.Character
		if not theirChar then
			addLog("[TP BEHIND] Target has no character!", COLORS.error)
			return
		end
		local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
		if not theirRoot then return end
		myRoot.CFrame = theirRoot.CFrame * CFrame.new(0, 0, 5)
		addLog("[TP BEHIND] Teleported behind " .. target.DisplayName, COLORS.success)
	end)
end

-- ===================== KILL ALL (MURDERER) =====================
local function startKillAll()
	miscState.killAllConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if roleState.myRole ~= "Murderer" then return end
			local myChar = LocalPlayer.Character
			if not myChar then return end
			local myRoot = myChar:FindFirstChild("HumanoidRootPart")
			if not myRoot then return end

			-- Check if knife is equipped
			local hasKnife = false
			for _, child in ipairs(myChar:GetChildren()) do
				if child:IsA("Tool") and (child.Name == "Knife" or child.Name:lower():find("knife")) then
					hasKnife = true
					break
				end
			end
			if not hasKnife then return end

			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					local theirRoot = player.Character:FindFirstChild("HumanoidRootPart")
					local theirHum = player.Character:FindFirstChildOfClass("Humanoid")
					if theirRoot and theirHum and theirHum.Health > 0 and theirHum:GetState() ~= Enum.HumanoidStateType.Dead then
						myRoot.CFrame = theirRoot.CFrame
						_wait(0.05)
					end
				end
			end
		end)
	end)
	addLog("[KILL ALL] ON - Equip knife! (Murderer only)", COLORS.success)
end

local function stopKillAll()
	if miscState.killAllConnection then miscState.killAllConnection:Disconnect() miscState.killAllConnection = nil end
	addLog("[KILL ALL] OFF", COLORS.error)
end

-- ===================== KILL SPECIFIC PLAYER (MURDERER) =====================
local function killSpecificPlayer(targetName)
	pcall(function()
		if roleState.myRole ~= "Murderer" then
			addLog("[KILL] You must be Murderer!", COLORS.error)
			return
		end
		local target = findPlayer(targetName)
		if not target then
			addLog("[KILL] Player not found: " .. targetName, COLORS.error)
			return
		end
		if target == LocalPlayer then
			addLog("[KILL] Can't target yourself!", COLORS.error)
			return
		end
		local theirChar = target.Character
		if not theirChar then
			addLog("[KILL] Target has no character!", COLORS.error)
			return
		end
		local theirHum = theirChar:FindFirstChildOfClass("Humanoid")
		if theirHum and (theirHum.Health <= 0 or theirHum:GetState() == Enum.HumanoidStateType.Dead) then
			addLog("[KILL] " .. target.DisplayName .. " is already dead!", COLORS.error)
			return
		end
		local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
		if not theirRoot then return end

		local myChar = LocalPlayer.Character
		if not myChar then return end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		if not myRoot then return end

		-- Make sure knife is equipped
		local hasKnife = false
		for _, child in ipairs(myChar:GetChildren()) do
			if child:IsA("Tool") and (child.Name == "Knife" or child.Name:lower():find("knife")) then
				hasKnife = true
				break
			end
		end
		if not hasKnife then
			local backpack = LocalPlayer:FindFirstChild("Backpack")
			if backpack then
				for _, child in ipairs(backpack:GetChildren()) do
					if child:IsA("Tool") and (child.Name == "Knife" or child.Name:lower():find("knife")) then
						local hum = myChar:FindFirstChildOfClass("Humanoid")
						if hum then hum:EquipTool(child) end
						hasKnife = true
						_wait(0.1)
						break
					end
				end
			end
		end
		if not hasKnife then
			addLog("[KILL] No knife found! Equip it first.", COLORS.error)
			return
		end

		-- TP to target repeatedly until they die or we give up
		addLog("[KILL] Targeting " .. target.DisplayName .. "...", COLORS.success)
		for i = 1, 20 do
			theirChar = target.Character
			if not theirChar then break end
			theirHum = theirChar:FindFirstChildOfClass("Humanoid")
			if theirHum and (theirHum.Health <= 0 or theirHum:GetState() == Enum.HumanoidStateType.Dead) then
				addLog("[KILL] " .. target.DisplayName .. " killed!", COLORS.success)
				return
			end
			theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
			if not theirRoot then break end
			myRoot = myChar:FindFirstChild("HumanoidRootPart")
			if not myRoot then break end
			myRoot.CFrame = theirRoot.CFrame
			_wait(0.1)
		end
	end)
end

-- ===================== BRING GUN =====================
local function bringGun()
	pcall(function()
		local gun = findGunDrop()
		if not gun then
			addLog("[BRING GUN] No dropped gun found!", COLORS.error)
			return
		end

		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			addLog("[BRING GUN] No character found!", COLORS.error)
			return
		end

		-- Find the gun's moveable part
		local gunPart = nil
		if gun:IsA("BasePart") then
			gunPart = gun
		elseif gun:IsA("Tool") then
			gunPart = gun:FindFirstChild("Handle") or gun:FindFirstChildWhichIsA("BasePart")
		elseif gun:IsA("Model") then
			gunPart = gun.PrimaryPart or gun:FindFirstChildWhichIsA("BasePart")
		end

		if gunPart then
			gunPart.CFrame = root.CFrame + Vector3.new(0, 2, 0)
			-- If it's a model with SetPrimaryPartCFrame
			if gun:IsA("Model") and gun.PrimaryPart then
				pcall(function() gun:SetPrimaryPartCFrame(root.CFrame + Vector3.new(0, 2, 0)) end)
			end
			addLog("[BRING GUN] Gun brought to you!", COLORS.success)
		else
			addLog("[BRING GUN] Could not find gun part!", COLORS.error)
		end
	end)
end

-- ===================== X-RAY =====================
local function startXRay()
	miscState.xrayOrigTransparencies = {}
	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character or workspace) then
				local isPlayerChar = false
				for _, p in ipairs(Players:GetPlayers()) do
					if p.Character and obj:IsDescendantOf(p.Character) then isPlayerChar = true break end
				end
				if not isPlayerChar and obj.Transparency < 0.7 then
					miscState.xrayOrigTransparencies[obj] = obj.Transparency
					obj.Transparency = 0.7
				end
			end
		end
	end)
	addLog("[X-RAY] ON - See through walls", COLORS.success)
end

local function stopXRay()
	pcall(function()
		for part, transparency in pairs(miscState.xrayOrigTransparencies) do
			if part and part.Parent then part.Transparency = transparency end
		end
		miscState.xrayOrigTransparencies = {}
	end)
	addLog("[X-RAY] OFF", COLORS.error)
end

-- ===================== TRAPDOOR ESP =====================
local function clearTrapdoorEsp()
	for _, hl in pairs(miscState.trapdoorEspHighlights) do pcall(function() hl:Destroy() end) end
	miscState.trapdoorEspHighlights = {}
end

local function startTrapdoorEsp()
	clearTrapdoorEsp()
	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") and (obj.Name == "Trap" or obj.Name == "Trapdoor" or obj.Name == "TrapDoor" or obj.Name:lower():find("trap")) then
				local hl = Instance.new("Highlight")
				hl.Name = "TrapdoorESP"
				hl.FillColor = Color3.fromRGB(255, 100, 0)
				hl.OutlineColor = Color3.fromRGB(255, 150, 50)
				hl.FillTransparency = 0.3
				hl.OutlineTransparency = 0
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Adornee = obj
				hl.Parent = obj
				table.insert(miscState.trapdoorEspHighlights, hl)
			end
		end
	end)
	addLog("[TRAPDOOR ESP] ON - Orange highlight on traps (" .. #miscState.trapdoorEspHighlights .. " found)", COLORS.success)
end

local function stopTrapdoorEsp()
	clearTrapdoorEsp()
	addLog("[TRAPDOOR ESP] OFF", COLORS.error)
end

-- ===================== BRING COINS =====================
local function startBringCoins()
	miscState.bringCoinsConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if not root then return end
			local coins = getCoins()
			for _, coin in ipairs(coins) do
				if coin and coin.Parent and coin.Transparency < 1 then
					coin.CFrame = root.CFrame
					-- Fire touch interest if available
					if firetouchinterest then
						pcall(function()
							firetouchinterest(root, coin, 0)
							_wait()
							firetouchinterest(root, coin, 1)
						end)
					end
				end
			end
		end)
	end)
	addLog("[BRING COINS] ON - Coins teleporting to you", COLORS.success)
end

local function stopBringCoins()
	if miscState.bringCoinsConnection then miscState.bringCoinsConnection:Disconnect() miscState.bringCoinsConnection = nil end
	addLog("[BRING COINS] OFF", COLORS.error)
end

-- ===================== AUTO COLLECT ALL =====================
local function startAutoCollect()
	miscState.autoCollectConnection = _spawn(function()
		while miscState.autoCollectEnabled do
			pcall(function()
				local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if not root then return end
				local coins = getCoins()
				for _, coin in ipairs(coins) do
					if not miscState.autoCollectEnabled then break end
					if coin and coin.Parent and coin.Transparency < 1 then
						if firetouchinterest then
							pcall(function()
								firetouchinterest(root, coin, 0)
								firetouchinterest(root, coin, 1)
							end)
						else
							local savedCF = root.CFrame
							root.CFrame = coin.CFrame
							_wait(0.05)
							root.CFrame = savedCF
						end
					end
				end
			end)
			_wait(0.3)
		end
	end)
	addLog("[AUTO COLLECT] ON - Collecting all coins rapidly", COLORS.success)
end

local function stopAutoCollect()
	miscState.autoCollectEnabled = false
	addLog("[AUTO COLLECT] OFF", COLORS.error)
end

-- ===================== BUNNY HOP =====================
local function startBunnyHop()
	moveState.bunnyHopConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end)
	addLog("[BHOP] ON - Auto-jump while moving forward", COLORS.success)
end

local function stopBunnyHop()
	if moveState.bunnyHopConnection then moveState.bunnyHopConnection:Disconnect() moveState.bunnyHopConnection = nil end
	addLog("[BHOP] OFF", COLORS.error)
end

-- ===================== TELEPORT TO PLAYER =====================
local function tpToPlayer(target)
	pcall(function()
		if not target then
			addLog("[TP] No player selected!", COLORS.error)
			return
		end
		local myChar = LocalPlayer.Character
		if not myChar then return end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		if not myRoot then return end
		local theirChar = target.Character
		if not theirChar then
			addLog("[TP] Target has no character!", COLORS.error)
			return
		end
		local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
		if not theirRoot then return end
		myRoot.CFrame = theirRoot.CFrame + Vector3.new(0, 3, 0)
		addLog("[TP] Teleported to " .. target.DisplayName, COLORS.success)
	end)
end

-- ===================== SPECTATE / UNSPECTATE =====================
local function spectatePlayer(target)
	pcall(function()
		if not target then
			addLog("[SPECTATE] No player selected!", COLORS.error)
			return
		end
		local theirChar = target.Character
		if not theirChar then
			addLog("[SPECTATE] Target has no character!", COLORS.error)
			return
		end
		workspace.CurrentCamera.CameraSubject = theirChar:FindFirstChildOfClass("Humanoid")
		addLog("[SPECTATE] Spectating " .. target.DisplayName, COLORS.success)
	end)
end

local function unspectate()
	pcall(function()
		local myChar = LocalPlayer.Character
		if myChar then
			workspace.CurrentCamera.CameraSubject = myChar:FindFirstChildOfClass("Humanoid")
		end
	end)
	addLog("[SPECTATE] Stopped spectating", COLORS.error)
end

-- ===================== GRAVITY MODIFIER =====================
local function setGravity(value)
	pcall(function()
		workspace.Gravity = value
	end)
	addLog("[GRAVITY] Set to " .. value, COLORS.success)
end

-- ===================== ANTI-VOID =====================
local function startAntiVoid()
	miscState.lastSafePos = nil
	miscState.antiVoidConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hrp.Position.Y > -50 and hum and hum.FloorMaterial ~= Enum.Material.Air then
				miscState.lastSafePos = hrp.CFrame
			elseif hrp.Position.Y <= -50 and miscState.lastSafePos then
				hrp.CFrame = miscState.lastSafePos
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
		end)
	end)
	addLog("[ANTI-VOID] ON - Preventing void deaths", COLORS.success)
end

local function stopAntiVoid()
	if miscState.antiVoidConnection then miscState.antiVoidConnection:Disconnect() miscState.antiVoidConnection = nil end
	miscState.lastSafePos = nil
	addLog("[ANTI-VOID] OFF", COLORS.error)
end

-- ===================== WALK FLING LOGIC (Dinos Anim / Velocity Spike) =====================
local function startWalkFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Enable noclip so we phase through while the spike happens
		if not moveState.noclipEnabled then moveState.noclipEnabled = true startNoclip() end

		-- Velocity spike-and-restore loop (Dinos Anim technique)
		-- Spike velocity for one physics tick, restore next frame
		-- Server sees the spike → physics collision → fling
		-- Anti-cheat sees normal velocity → no kick
		flingState.walkFlingConnection = _spawn(function()
			local movel = 0.1
			while flingState.walkFlingEnabled do
				RunService.Heartbeat:Wait()
				local char = LocalPlayer.Character
				if not char or not char.Parent then _wait(0.1) end
				local rt = char and char:FindFirstChild("HumanoidRootPart")
				if rt and rt.Parent then
					local vel = rt.Velocity

					-- SPIKE: massive velocity burst for one tick
					rt.Velocity = vel * flingState.walkFlingPower + Vector3.new(0, flingState.walkFlingPower, 0)

					RunService.RenderStepped:Wait()
					-- RESTORE: snap back to normal
					char = LocalPlayer.Character
					rt = char and char:FindFirstChild("HumanoidRootPart")
					if rt and rt.Parent then
						rt.Velocity = vel
					end

					RunService.Stepped:Wait()
					-- MICRO-OSCILLATE: tiny bounce to keep physics alive
					char = LocalPlayer.Character
					rt = char and char:FindFirstChild("HumanoidRootPart")
					if rt and rt.Parent then
						rt.Velocity = vel + Vector3.new(0, movel, 0)
						movel = movel * -1
					end
				end
			end
		end)

		addLog("[WALK FLING] ON - Walk into players!", COLORS.success)
	end)
	if not ok then
		addLog("[WALK FLING] Error: " .. tostring(err), COLORS.error)
	end
end

local function stopWalkFling()
	flingState.walkFlingEnabled = false
	-- walkFlingConnection is a spawned thread, it will exit on its own
	flingState.walkFlingConnection = nil
	local character = LocalPlayer.Character
	if character then
		local V3 = Vector3.new(0, 0, 0)
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Velocity = V3
				part.RotVelocity = V3
			end
		end
	end
	flingState.walkFlingProps = {}
	addLog("[WALK FLING] OFF", COLORS.error)
end

-- ===================== HEADLESS =====================
local function startHeadless()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		miscState.headlessSaved = {}

		-- Hide head mesh
		local head = character:FindFirstChild("Head")
		if head then
			for _, child in ipairs(head:GetChildren()) do
				if child:IsA("SpecialMesh") then
					miscState.headlessSaved[child] = {Scale = child.Scale}
					child.Scale = Vector3.new(0, 0, 0)
				elseif child:IsA("Decal") then
					miscState.headlessSaved[child] = {Transparency = child.Transparency}
					child.Transparency = 1
				end
			end
			miscState.headlessSaved[head] = {Transparency = head.Transparency}
			head.Transparency = 1
		end

		-- Hide hat accessories
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				if handle then
					miscState.headlessSaved[handle] = {Transparency = handle.Transparency}
					handle.Transparency = 1
				end
			end
		end
	end)
	addLog("[HEADLESS] ON", COLORS.success)
end

local function stopHeadless()
	pcall(function()
		for obj, props in pairs(miscState.headlessSaved) do
			if obj and obj.Parent then
				for prop, val in pairs(props) do
					pcall(function() obj[prop] = val end)
				end
			end
		end
		miscState.headlessSaved = {}
	end)
	addLog("[HEADLESS] OFF", COLORS.error)
end

-- ===================== RAINBOW CHARACTER =====================
local function startRainbow()
	local hueOffset = 0
	miscState.rainbowConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			hueOffset = hueOffset + 0.005
			if hueOffset > 1 then hueOffset = 0 end
			local color = Color3.fromHSV(hueOffset, 1, 1)
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Color = color
				end
			end
		end)
	end)
	addLog("[RAINBOW] ON - Cycling colors", COLORS.success)
end

local function stopRainbow()
	if miscState.rainbowConnection then miscState.rainbowConnection:Disconnect() miscState.rainbowConnection = nil end
	addLog("[RAINBOW] OFF", COLORS.error)
end

-- ===================== SPIN FLING LOGIC =====================
local function startFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Enable noclip
		if not moveState.noclipEnabled then moveState.noclipEnabled = true startNoclip() end
		_wait(0.1)

		-- Set density to 100 on all parts + massless children
		flingState.savedPhysProps = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				flingState.savedPhysProps[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
				part.CanCollide = false
				part.Massless = true
				part.Velocity = Vector3.new(0, 0, 0)
			end
		end

		-- Try BodyAngularVelocity first (most reliable fling method)
		-- MM2 may remove it - if so, the Heartbeat loop below uses Assembly properties
		pcall(function()
			flingState.spinBAV = Instance.new("BodyAngularVelocity")
			flingState.spinBAV.AngularVelocity = Vector3.new(0, flingState.flingPower, 0)
			flingState.spinBAV.MaxTorque = Vector3.new(0, math.huge, 0)
			flingState.spinBAV.P = math.huge
			flingState.spinBAV.Parent = root
		end)

		-- Heartbeat: re-apply density + pulse spin + fallback Assembly spin
		flingState.flingConnection = RunService.Heartbeat:Connect(function()
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end
				local rt = char:FindFirstChild("HumanoidRootPart")
				if not rt then return end

				-- Re-apply density every frame (server resets this)
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
					end
				end

				-- If BAV was removed by server, use Assembly properties
				if not flingState.spinBAV or not flingState.spinBAV.Parent then
					rt.AssemblyAngularVelocity = Vector3.new(0, 9999, 0)
				end
			end)
		end)

		-- Pulse spin on/off to create impulse spikes
		flingState.flingConnection2 = _spawn(function()
			while flingState.flingEnabled do
				if flingState.spinBAV and flingState.spinBAV.Parent then
					flingState.spinBAV.AngularVelocity = Vector3.new(0, flingState.flingPower, 0)
				end
				_wait(0.2)
				if flingState.spinBAV and flingState.spinBAV.Parent then
					flingState.spinBAV.AngularVelocity = Vector3.new(0, 0, 0)
				end
				_wait(0.1)
			end
		end)

		addLog("[SPIN FLING] ON - Walk into players!", COLORS.success)
	end)
	if not ok then
		addLog("[SPIN FLING] Error: " .. tostring(err), COLORS.error)
	end
end

local function stopFling()
	flingState.flingEnabled = false
	if flingState.flingConnection then flingState.flingConnection:Disconnect() flingState.flingConnection = nil end
	-- flingConnection2 is a spawned thread, exits when flingEnabled = false
	flingState.flingConnection2 = nil

	-- Remove BAV
	if flingState.spinBAV then pcall(function() flingState.spinBAV:Destroy() end) flingState.spinBAV = nil end

	-- Restore physics
	local character = LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				if flingState.savedPhysProps[part] then
					part.CustomPhysicalProperties = flingState.savedPhysProps[part]
				else
					part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
				end
				part.Massless = false
				part.Velocity = Vector3.new(0, 0, 0)
				part.RotVelocity = Vector3.new(0, 0, 0)
				part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end
		end
	end
	flingState.savedPhysProps = {}

	addLog("[SPIN FLING] OFF", COLORS.error)
end

-- ===================== SPIN LOGIC =====================
local function startSpin()
	flingState.spinConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(15), 0) end
		end)
	end)
	addLog("[SPIN] ON", COLORS.success)
end

local function stopSpin()
	if flingState.spinConnection then flingState.spinConnection:Disconnect() flingState.spinConnection = nil end
	addLog("[SPIN] OFF", COLORS.error)
end

-- ===================== SEIZURE LOGIC =====================
local function startSeizure()
	flingState.seizureConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.BrickColor = BrickColor.Random()
				end
			end
		end)
	end)
	addLog("[SEIZURE] ON", COLORS.success)
end

local function stopSeizure()
	if flingState.seizureConnection then flingState.seizureConnection:Disconnect() flingState.seizureConnection = nil end
	addLog("[SEIZURE] OFF", COLORS.error)
end

-- ===================== EMOTE LOGIC =====================
local function stopEmote()
	flingState.emoteActive = false
	if flingState.emoteConnection then flingState.emoteConnection:Disconnect() flingState.emoteConnection = nil end
	for _, track in ipairs(flingState.emoteTracks) do
		pcall(function() track:Stop() end)
	end
	flingState.emoteTracks = {}
end

local function playEmote(animId, speed, duration)
	stopEmote()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(animId)
		local track = hum:LoadAnimation(anim)
		track:Play()
		if speed then track:AdjustSpeed(speed) end
		table.insert(flingState.emoteTracks, track)
		flingState.emoteActive = true
		if duration then
			task.delay(duration, function()
				if flingState.emoteActive then stopEmote() end
			end)
		end
	end)
end

local function playJerkEmote()
	stopEmote()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		flingState.emoteActive = true

		local isR6 = character:FindFirstChild("Torso") ~= nil

		if isR6 then
			-- R6: dual animation loop
			local anim1 = Instance.new("Animation")
			anim1.AnimationId = "rbxassetid://4689362868"
			local anim2 = Instance.new("Animation")
			anim2.AnimationId = "rbxassetid://168086975"
			local track1 = hum:LoadAnimation(anim1)
			local track2 = hum:LoadAnimation(anim2)
			track1:Play()
			track2:Play()
			track1:AdjustSpeed(2)
			track2:AdjustSpeed(2)
			table.insert(flingState.emoteTracks, track1)
			table.insert(flingState.emoteTracks, track2)

			-- Loop by replaying when tracks finish
			flingState.emoteConnection = RunService.Heartbeat:Connect(function()
				if not flingState.emoteActive then return end
				pcall(function()
					if track1.IsPlaying == false then
						track1:Play()
						track1:AdjustSpeed(2)
					end
					if track2.IsPlaying == false then
						track2:Play()
						track2:AdjustSpeed(2)
					end
				end)
			end)
		else
			-- R15 fallback
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://698251653"
			local track = hum:LoadAnimation(anim)
			track:Play()
			track:AdjustSpeed(0.4)
			table.insert(flingState.emoteTracks, track)

			flingState.emoteConnection = RunService.Heartbeat:Connect(function()
				if not flingState.emoteActive then return end
				pcall(function()
					if track.TimePosition > 0.72 then
						track.TimePosition = 0.579
					end
				end)
			end)
		end

		addLog("[EMOTE] Playing...", COLORS.success)
	end)
end

-- ===================== REJOIN / SERVER HOP =====================
local function rejoinServer()
	addLog("[REJOIN] Rejoining...", COLORS.accent)
	pcall(function()
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end)
end

local function serverHop()
	addLog("[SERVER HOP] Finding new server...", COLORS.accent)
	pcall(function()
		local placeId = game.PlaceId
		local servers = game:GetService("HttpService"):JSONDecode(
			game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100")
		)
		if servers and servers.data then
			for _, server in ipairs(servers.data) do
				if server.playing and server.playing < server.maxPlayers and server.id ~= game.JobId then
					TeleportService:TeleportToPlaceInstance(placeId, server.id, LocalPlayer)
					return
				end
			end
		end
		addLog("[SERVER HOP] No available servers found, rejoining...", COLORS.textSecondary)
		TeleportService:Teleport(placeId, LocalPlayer)
	end)
end

-- =====================================================================
-- ======================== BUILD MAIN TAB ============================
-- =====================================================================
do
	local tab = tabFrames["Main"]

	createSectionLabel(tab, "Info", 1)
	createInfoLabel(tab, "MM2 Hub v1.1", 2)
	createInfoLabel(tab, "SX The Revival", 3)


	createSectionLabel(tab, "Quick Actions", 5)

	createActionButton(tab, "Rejoin Server", 6, function()
		rejoinServer()
	end)
	createActionButton(tab, "Server Hop", 7, function()
		serverHop()
	end)


	createSectionLabel(tab, "Role", 9)
	uiState.roleLabel = createInfoLabel(tab, "Role: Unknown", 10)


	createSectionLabel(tab, "Log", 12)

	createInfoLabel(tab, "Output goes to the F9 console.", 99)
end

-- =====================================================================
-- ============ BUNDLE 3: COMBAT / SHERIFF AIM ASSIST =================
-- Client-side aim MATH for the user's own MM2 helper. Aiming / camera /
-- Drawing / part-scaling are all generic and fully implemented here.
-- Silent Aim and Auto-Shoot are RECON-GATED: the target-selection and
-- when-to-fire logic is built, but the actual shot is stubbed because
-- MM2's real shoot remote is NOT confirmed in this code.
-- =====================================================================

local SH = {}
SH.STUB_MSG = "Auto-Shoot / Silent Aim needs the game's real shoot remote (recon required)"

-- Aim part: prefer Head, fall back to HumanoidRootPart
function SH.sheriffGetAimPart(player)
	if not player then return nil end
	local char = player.Character
	if not char then return nil end
	if sheriffState.targetHead then
		local head = char:FindFirstChild("Head")
		if head then return head end
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

-- Linear target prediction: lead the aim point by the target's movement
function SH.sheriffPredictedPos(part, player)
	local pos = part.Position
	pcall(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.MoveDirection.Magnitude > 0 then
			pos = pos + (hum.MoveDirection * hum.WalkSpeed) * sheriffState.prediction
		else
			pos = pos + part.AssemblyLinearVelocity * sheriffState.prediction
		end
	end)
	return pos
end

-- Closest-target selection honoring the FOV circle and role (prefer murderer)
function SH.sheriffSelectTarget()
	local vp = Camera.ViewportSize
	local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)
	local function fovDist(player)
		local part = SH.sheriffGetAimPart(player)
		if not part then return nil, nil end
		local sp, onScreen = worldToScreen(part.Position)
		if not onScreen then return nil, nil end
		local d = (sp - screenCenter).Magnitude
		if d > sheriffState.fov then return nil, nil end
		return d, part
	end
	-- Prefer the confirmed murderer if within the FOV circle
	if roleState.murdererPlayer and roleState.murdererPlayer ~= LocalPlayer then
		local d, part = fovDist(roleState.murdererPlayer)
		if d ~= nil then return roleState.murdererPlayer, part end
	end
	-- Otherwise closest player within the FOV circle (excluding self)
	local best, bestPart, bestDist = nil, nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local d, part = fovDist(player)
			if d ~= nil and d < bestDist then
				best, bestPart, bestDist = player, part, d
			end
		end
	end
	return best, bestPart
end

-- Should the aim lock be applied this frame? (hold key OR toggle-lock)
function SH.sheriffAimActive()
	if not sheriffState.aimbotEnabled then return false end
	if sheriffState.holdToAim then return sheriffState.aimKeyDown end
	return true
end

-- Track the hold key state (generic keyboard input, no remote)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	pcall(function()
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == sheriffState.aimKey then
			sheriffState.aimKeyDown = true
		end
	end)
end)
UserInputService.InputEnded:Connect(function(input)
	pcall(function()
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == sheriffState.aimKey then
			sheriffState.aimKeyDown = false
		end
	end)
end)

-- Sheriff aimbot: lerp the camera CFrame toward the (predicted) aim point
function SH.startSheriffAimbot()
	if sheriffState.aimConnection then return end
	sheriffState.aimConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not SH.sheriffAimActive() then return end
			if roleState.myRole ~= "Sheriff" then return end
			local target, part = SH.sheriffSelectTarget()
			if not target or not part then return end
			local aimPos = SH.sheriffPredictedPos(part, target)
			local camPos = Camera.CFrame.Position
			local goalCF = CFrame.lookAt(camPos, aimPos)
			local alpha = math.clamp(sheriffState.smoothing, 0.01, 1)
			Camera.CFrame = Camera.CFrame:Lerp(goalCF, alpha)
		end)
	end)
	addLog("[SHERIFF] Aimbot ON (Sheriff only, hold " .. sheriffState.aimKey .. ")", COLORS.success)
end

function SH.stopSheriffAimbot()
	if sheriffState.aimConnection then
		sheriffState.aimConnection:Disconnect()
		sheriffState.aimConnection = nil
	end
	addLog("[SHERIFF] Aimbot OFF", COLORS.textSecondary)
end

-- FOV circle: screen-centered Drawing circle; targets outside it are ignored
function SH.startSheriffFovCircle()
	if sheriffState.fovCircle or sheriffState.fovConnection then return end
	sheriffState.fovCircle = newDrawing("Circle", {
		Thickness = 1,
		NumSides = 64,
		Radius = sheriffState.fov,
		Filled = false,
		Transparency = 1,
		Color = COLORS.accent,
	})
	if not sheriffState.fovCircle then
		addLog("[SHERIFF] FOV circle needs the executor Drawing API (recon required)", COLORS.error)
		return
	end
	sheriffState.fovConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not sheriffState.fovCircle then return end
			local vp = Camera.ViewportSize
			sheriffState.fovCircle.Radius = sheriffState.fov
			sheriffState.fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
			sheriffState.fovCircle.Visible = true
		end)
	end)
end

function SH.stopSheriffFovCircle()
	if sheriffState.fovConnection then
		sheriffState.fovConnection:Disconnect()
		sheriffState.fovConnection = nil
	end
	if sheriffState.fovCircle then
		pcall(function()
			sheriffState.fovCircle.Visible = false
			sheriffState.fovCircle:Remove()
		end)
		sheriffState.fovCircle = nil
	end
end

-- Gun reach / hitbox expander on the murderer (generic BasePart scaling)
function SH.restoreMurdererHitbox()
	if sheriffState.savedMurdererPart and sheriffState.savedMurdererSize then
		pcall(function() sheriffState.savedMurdererPart.Size = sheriffState.savedMurdererSize end)
	end
	sheriffState.savedMurdererPart = nil
	sheriffState.savedMurdererSize = nil
end

function SH.startSheriffReach()
	if sheriffState.reachConnection then return end
	sheriffState.reachConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local m = roleState.murdererPlayer
			if not m or not m.Character then return end
			local hrp = m.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			-- Re-save originals whenever the target part changes (respawn / new murderer)
			if sheriffState.savedMurdererPart ~= hrp then
				if sheriffState.savedMurdererPart and sheriffState.savedMurdererSize then
					pcall(function() sheriffState.savedMurdererPart.Size = sheriffState.savedMurdererSize end)
				end
				sheriffState.savedMurdererPart = hrp
				sheriffState.savedMurdererSize = hrp.Size
			end
			local desired = sheriffState.savedMurdererSize * sheriffState.reach
			if hrp.Size ~= desired then
				hrp.Size = desired
			end
		end)
	end)
	addLog("[SHERIFF] Gun reach ON (scales murderer hitbox)", COLORS.success)
end

function SH.stopSheriffReach()
	if sheriffState.reachConnection then
		sheriffState.reachConnection:Disconnect()
		sheriffState.reachConnection = nil
	end
	SH.restoreMurdererHitbox()
	addLog("[SHERIFF] Gun reach OFF", COLORS.textSecondary)
end

-- ------- RECON-GATED: shoot logic is built, the fire call is stubbed -------
function SH.sheriffFireStub()
	-- Do NOT fire any guessed remote. MM2's real shoot remote is unconfirmed.
	addLog(SH.STUB_MSG, COLORS.error)
end

-- Auto-Shoot Murderer as Sheriff: decide WHEN to fire, then hit the stub
function SH.startSheriffAutoShoot()
	if sheriffState.autoShootConnection then return end
	sheriffState.autoShootConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not sheriffState.autoShootEnabled then return end
			if roleState.myRole ~= "Sheriff" then return end
			local target, part = SH.sheriffSelectTarget()
			-- Only auto-shoot the confirmed murderer, within the FOV circle, alive
			if not target or not part then return end
			if target ~= roleState.murdererPlayer then return end
			local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health <= 0 then return end
			local now = tick()
			if now - sheriffState.lastFire < 2.5 then return end
			sheriffState.lastFire = now
			SH.sheriffFireStub() -- RECON-GATED: replaces the real gun/shoot remote fire
		end)
	end)
end

function SH.stopSheriffAutoShoot()
	if sheriffState.autoShootConnection then
		sheriffState.autoShootConnection:Disconnect()
		sheriffState.autoShootConnection = nil
	end
end

-- Silent Aim: compute the hidden hit target (no camera move); redirect is stubbed
function SH.startSheriffSilentAim()
	if sheriffState.silentConnection then return end
	sheriffState.silentConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not sheriffState.silentAimEnabled then return end
			if roleState.myRole ~= "Sheriff" then return end
			local target, part = SH.sheriffSelectTarget()
			if not target or not part then return end
			-- The predicted point the shot would be silently redirected to.
			-- Actually redirecting a shot requires hooking/firing MM2's real
			-- shoot remote, which is recon-gated, so we hit the stub instead.
			local _aimPos = SH.sheriffPredictedPos(part, target)
			local now = tick()
			if now - sheriffState.lastSilentLog < 2.5 then return end
			sheriffState.lastSilentLog = now
			SH.sheriffFireStub()
		end)
	end)
end

function SH.stopSheriffSilentAim()
	if sheriffState.silentConnection then
		sheriffState.silentConnection:Disconnect()
		sheriffState.silentConnection = nil
	end
end

-- =====================================================================
-- ======================== BUILD COMBAT TAB ==========================
-- =====================================================================
do
	local tab = tabFrames["Combat"]

	createSectionLabel(tab, "Role Detection", 1)

	createToggle(tab, "Murderer ESP", 2, function(on)
		combatState.murdererEspEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			enableMurdererEsp()
		else
			disableMurdererEsp()
		end
	end)
	createToggle(tab, "Murderer Alert", 3, function(on)
		combatState.murdererAlertEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			startMurdererAlert()
		else
			stopMurdererAlert()
		end
	end)


	createSectionLabel(tab, "Sheriff Tools", 5)

	createToggle(tab, "Auto Shoot Murderer", 6, function(on)
		combatState.autoShootMurdererEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			startAutoShootMurderer()
		else
			stopAutoShootMurderer()
		end
	end)
	createActionButton(tab, "TP Kill Murderer", 7, function()
		if not roleState.roleCheckEnabled then startRoleCheck() end
		tpKillMurderer()
	end)


	createSectionLabel(tab, "Gun", 9)

	createActionButton(tab, "Grab Dropped Gun", 10, function()
		grabDroppedGun()
	end)
	createActionButton(tab, "Bring Gun To You", 11, function()
		bringGun()
	end)
	createToggle(tab, "Auto Grab Gun", 12, function(on)
		miscState.autoGrabGunEnabled = on
		if on then startAutoGrabGun() else stopAutoGrabGun() end
	end)


	createSectionLabel(tab, "Murderer Tools", 14)

	createToggle(tab, "Kill All (Murderer)", 15, function(on)
		miscState.killAllEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			startKillAll()
		else
			stopKillAll()
		end
	end)

	local killInput_text = ""
	createInput(tab, "Player Name (Kill)", "Enter player name to kill...", function(v) killInput_text = v end)

	createActionButton(tab, "Kill Player (Murderer)", 17, function()
		local name = killInput_text
		if name and name ~= "" then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			killSpecificPlayer(name)
		else
			addLog("[KILL] Enter a player name first!", COLORS.error)
		end
	end)


	createSectionLabel(tab, "TP Behind", 19)

	-- TP Behind player name input
	local tpBehindInput_text = ""
	createInput(tab, "Player Name (TP Behind)", "Enter player name...", function(v) tpBehindInput_text = v end)

	createActionButton(tab, "TP Behind Player", 21, function()
		local name = tpBehindInput_text
		if name and name ~= "" then
			tpBehindPlayer(name)
		else
			addLog("[TP BEHIND] Enter a player name first!", COLORS.error)
		end
	end)


	createSectionLabel(tab, "Info", 23)
	createInfoLabel(tab, "Auto Shoot only works as Sheriff", 24)
	createInfoLabel(tab, "Kill All / Kill Player only work as Murderer", 25)
	createInfoLabel(tab, "Bring Gun teleports gun to you", 26)

	-- ---------------- Bundle 3: Aim Assist ----------------

	createSectionLabel(tab, "Aim Assist", 28)

	createToggle(tab, "Sheriff Aimbot", 29, function(on)
		sheriffState.aimbotEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			SH.startSheriffAimbot()
		else
			SH.stopSheriffAimbot()
		end
	end)
	createToggle(tab, "Hold Key To Aim (E)", 30, function(on)
		sheriffState.holdToAim = on
		if on then
			addLog("[SHERIFF] Aim locks only while holding " .. sheriffState.aimKey, COLORS.textSecondary)
		else
			addLog("[SHERIFF] Aim locks continuously while aimbot is ON", COLORS.textSecondary)
		end
	end).setVisualState(true)
	createToggle(tab, "Aim Head (else HRP)", 31, function(on)
		sheriffState.targetHead = on
	end).setVisualState(true)
	createToggle(tab, "FOV Circle", 32, function(on)
		sheriffState.fovCircleEnabled = on
		if on then SH.startSheriffFovCircle() else SH.stopSheriffFovCircle() end
	end)
	createToggle(tab, "Gun Reach (Murderer Hitbox)", 33, function(on)
		sheriffState.reachEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			SH.startSheriffReach()
		else
			SH.stopSheriffReach()
		end
	end)

	createSlider(tab, "Aim Smoothing %", 1, 100, 20, 34, function(v)
		sheriffState.smoothing = v / 100
	end)
	createSlider(tab, "FOV Radius", 20, 500, 120, 35, function(v)
		sheriffState.fov = v
	end)
	createSlider(tab, "Prediction %", 0, 100, 10, 36, function(v)
		sheriffState.prediction = v / 100
	end)
	createSlider(tab, "Gun Reach x", 1, 10, 1, 37, function(v)
		sheriffState.reach = v
	end)


	createSectionLabel(tab, "Recon-Gated (needs game remote)", 39)

	createToggle(tab, "Silent Aim (recon)", 40, function(on)
		sheriffState.silentAimEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			SH.startSheriffSilentAim()
			SH.sheriffFireStub()
		else
			SH.stopSheriffSilentAim()
		end
	end)
	createToggle(tab, "Auto-Shoot Murderer as Sheriff (recon)", 41, function(on)
		sheriffState.autoShootEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			SH.startSheriffAutoShoot()
			SH.sheriffFireStub()
		else
			SH.stopSheriffAutoShoot()
		end
	end)

	createInfoLabel(tab, "Aimbot/FOV/Reach are client-side and active", 42)
	createInfoLabel(tab, "Silent Aim + Auto-Shoot are stubbed (no remote)", 43)
end

-- =====================================================================
-- ======================== BUILD ESP TAB =============================
-- =====================================================================
do
	local tab = tabFrames["ESP"]

	createSectionLabel(tab, "Player ESP", 1)

	createToggle(tab, "ESP", 2, function(on)
		espState.espEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			enablePlayerEsp()
		else
			disablePlayerEsp()
		end
	end)
	createToggle(tab, "Show Names", 3, function(on)
		espState.showNamesEnabled = on
		if espState.espEnabled then
			disablePlayerEsp()
			_wait(0.2)
			enablePlayerEsp()
		end
	end).setVisualState(true)
	createToggle(tab, "Show Distance", 4, function(on)
		espState.showDistanceEnabled = on
		if espState.espEnabled then
			disablePlayerEsp()
			_wait(0.2)
			enablePlayerEsp()
		end
	end).setVisualState(true)
	createToggle(tab, "Show Role", 5, function(on)
		espState.showRoleEnabled = on
		if espState.espEnabled then
			disablePlayerEsp()
			_wait(0.2)
			enablePlayerEsp()
		end
	end).setVisualState(true)


	createSectionLabel(tab, "Item ESP", 7)

	createToggle(tab, "Gun ESP", 8, function(on)
		espState.gunEspEnabled = on
		if on then enableGunEsp() else disableGunEsp() end
	end)
	createToggle(tab, "Coin ESP", 9, function(on)
		espState.coinEspEnabled = on
		if on then enableCoinEsp() else disableCoinEsp() end
	end)
	createToggle(tab, "Trapdoor ESP", 10, function(on)
		miscState.trapdoorEspEnabled = on
		if on then startTrapdoorEsp() else stopTrapdoorEsp() end
	end)


	createSectionLabel(tab, "World", 12)

	createToggle(tab, "Fullbright", 13, function(on)
		espState.fullbrightEnabled = on
		if on then startFullbright() else stopFullbright() end
	end)
	createToggle(tab, "X-Ray", 14, function(on)
		miscState.xrayEnabled = on
		if on then startXRay() else stopXRay() end
	end)


	createSectionLabel(tab, "Info", 16)
	createInfoLabel(tab, "ESP colors: Red=Murderer, Blue=Sheriff, Green=Innocent", 17)
	createInfoLabel(tab, "Gun ESP: Yellow highlight on dropped guns", 18)
	createInfoLabel(tab, "Coin ESP: Gold highlight on collectible coins", 19)
	createInfoLabel(tab, "X-Ray: See through walls (0.7 transparency)", 20)
	createInfoLabel(tab, "Trapdoor ESP: Orange highlight on trap parts", 21)
end

-- =====================================================================
-- ==================== BUNDLE 1: ESP SUITE ============================
-- Box / Corner-box / Tracers / Skeleton / Chams / Off-screen arrows /
-- Snapline-to-murderer. All generic Drawing/Highlight overlays driven
-- by ONE RenderStepped loop. Functions are scoped inside this do-block
-- so they do not inflate the top-level local register count.
-- =====================================================================
do
	local tab = tabFrames["ESP"]
	local VE = {}

	-- role -> color (falls back to white for innocent/unknown)
	function VE.vespRoleColor(player)
		local ok, role = pcall(getPlayerRole, player)
		if ok then
			if role == "Murderer" then return ROLE_COLORS.Murderer end
			if role == "Sheriff" then return ROLE_COLORS.Sheriff end
		end
		return COLORS.textPrimary
	end

	-- lazily fetch the per-player drawing container
	function VE.vespGet(player)
		local t = visualEspState.drawings[player]
		if not t then
			t = {}
			visualEspState.drawings[player] = t
		end
		return t
	end

	-- current tracer origin point in screen space
	function VE.vespOrigin(viewport)
		local o = visualEspState.tracerOrigin
		if o == "top" then
			return Vector2.new(viewport.X * 0.5, 0)
		elseif o == "mouse" then
			local ok, m = pcall(function() return UserInputService:GetMouseLocation() end)
			if ok and m then return Vector2.new(m.X, m.Y) end
		end
		return Vector2.new(viewport.X * 0.5, viewport.Y)
	end

	-- skeleton limb connection tables
	local VESP_R6_PAIRS = {
		{"Head", "Torso"},
		{"Torso", "Left Arm"}, {"Torso", "Right Arm"},
		{"Torso", "Left Leg"}, {"Torso", "Right Leg"},
	}
	local VESP_R15_PAIRS = {
		{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
		{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
		{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
		{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
		{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
	}

	function VE.vespRemoveDrawing(d)
		if d then pcall(function() d:Remove() end) end
	end

	-- destroy every overlay object for one player (on leave)
	function VE.vespRemovePlayer(player)
		local t = visualEspState.drawings[player]
		if t then
			VE.vespRemoveDrawing(t.box)
			if t.corners then for _, l in ipairs(t.corners) do VE.vespRemoveDrawing(l) end end
			VE.vespRemoveDrawing(t.tracer)
			if t.skel then for _, l in ipairs(t.skel) do VE.vespRemoveDrawing(l) end end
			VE.vespRemoveDrawing(t.arrow)
			visualEspState.drawings[player] = nil
		end
		local hl = visualEspState.highlights[player]
		if hl then
			pcall(function() hl:Destroy() end)
			visualEspState.highlights[player] = nil
		end
	end

	-- clear one overlay type across all players (called on toggle OFF)
	function VE.vespClearOverlay(kind)
		for _, t in pairs(visualEspState.drawings) do
			if kind == "box" then VE.vespRemoveDrawing(t.box) t.box = nil end
			if kind == "corners" then
				if t.corners then for _, l in ipairs(t.corners) do VE.vespRemoveDrawing(l) end end
				t.corners = nil
			end
			if kind == "tracer" then VE.vespRemoveDrawing(t.tracer) t.tracer = nil end
			if kind == "skeleton" then
				if t.skel then for _, l in ipairs(t.skel) do VE.vespRemoveDrawing(l) end end
				t.skel = nil
			end
			if kind == "arrow" then VE.vespRemoveDrawing(t.arrow) t.arrow = nil end
		end
		if kind == "chams" then
			for _, hl in pairs(visualEspState.highlights) do pcall(function() hl:Destroy() end) end
			visualEspState.highlights = {}
		end
		if kind == "snapline" then
			VE.vespRemoveDrawing(visualEspState.snaplineDrawing)
			visualEspState.snaplineDrawing = nil
		end
	end

	-- build / refresh the 8 corner segments for a box
	function VE.vespDrawCorners(t, x, y, w, h, color, thickness)
		if not Drawing then return end
		if not t.corners then
			t.corners = {}
			for i = 1, 8 do
				t.corners[i] = newDrawing("Line", {Thickness = thickness, Transparency = 1})
			end
		end
		local len = math.min(w, h) * 0.28
		if len < 1 then len = 1 end
		local c = t.corners
		local function seg(idx, fx, fy, tx, ty)
			local l = c[idx]
			if l then
				l.From = Vector2.new(fx, fy)
				l.To = Vector2.new(tx, ty)
				l.Color = color
				l.Thickness = thickness
				l.Visible = true
			end
		end
		local x2, y2 = x + w, y + h
		seg(1, x, y, x + len, y)      seg(2, x, y, x, y + len)        -- top-left
		seg(3, x2, y, x2 - len, y)    seg(4, x2, y, x2, y + len)      -- top-right
		seg(5, x, y2, x + len, y2)    seg(6, x, y2, x, y2 - len)      -- bottom-left
		seg(7, x2, y2, x2 - len, y2)  seg(8, x2, y2, x2, y2 - len)    -- bottom-right
	end

	function VE.vespHideCorners(t)
		if t.corners then for _, l in ipairs(t.corners) do if l then l.Visible = false end end end
	end

	-- off-screen arrow (Triangle, falls back to Line)
	function VE.vespDrawArrow(t, ndir, pos, color, big)
		if not Drawing then return end
		if not t.arrow then
			t.arrow = newDrawing("Triangle", {Thickness = 1, Filled = true, Transparency = 1})
			if not t.arrow then
				t.arrow = newDrawing("Line", {Thickness = 2, Transparency = 1})
			end
		end
		local a = t.arrow
		if not a then return end
		local perp = Vector2.new(-ndir.Y, ndir.X)
		local size = big and 22 or 14
		local tip = pos + ndir * size
		local baseL = pos - ndir * (size * 0.4) + perp * (size * 0.6)
		local baseR = pos - ndir * (size * 0.4) - perp * (size * 0.6)
		local okTri = pcall(function()
			a.PointA = tip
			a.PointB = baseL
			a.PointC = baseR
		end)
		if not okTri then
			pcall(function()
				a.From = pos - ndir * size
				a.To = tip
			end)
		end
		pcall(function()
			a.Color = color
			a.Visible = true
		end)
	end

	-- ONE per-frame driver: redraws enabled overlays, hides the rest
	function VE.vespUpdate()
		pcall(function()
			local viewport = Camera.ViewportSize
			local thickness = visualEspState.tracerThickness or 1
			if thickness < 1 then thickness = 1 end
			local originPt = VE.vespOrigin(viewport)

			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					pcall(function()
						local char = player.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						local t = VE.vespGet(player)
						local color = VE.vespRoleColor(player)

						if not char or not hrp then
							if t.box then t.box.Visible = false end
							VE.vespHideCorners(t)
							if t.tracer then t.tracer.Visible = false end
							if t.skel then for _, l in ipairs(t.skel) do if l then l.Visible = false end end end
							if t.arrow then t.arrow.Visible = false end
							return
						end

						local head = char:FindFirstChild("Head")
						local rootPos = hrp.Position
						local topWorld = head and (head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.4, 0)) or (rootPos + Vector3.new(0, 3, 0))
						local botWorld = rootPos - Vector3.new(0, 3, 0)
						local rootS, _, rootDepth = worldToScreen(rootPos)
						local topS, _, topDepth = worldToScreen(topWorld)
						local botS, _, botDepth = worldToScreen(botWorld)

						local inFront = rootDepth > 0
						local onScreen = inFront and rootS.X >= 0 and rootS.X <= viewport.X and rootS.Y >= 0 and rootS.Y <= viewport.Y

						-- 2D box from projected head-top & feet-bottom
						local bx, by, bw, bh
						if inFront and topDepth > 0 and botDepth > 0 then
							bh = math.abs(botS.Y - topS.Y)
							if bh < 4 then bh = 4 end
							bw = bh * 0.42
							local cx = (topS.X + botS.X) * 0.5
							bx = cx - bw * 0.5
							by = math.min(topS.Y, botS.Y)
						end

						-- BOX
						if visualEspState.boxEnabled and bx then
							if not t.box and Drawing then
								t.box = newDrawing("Square", {Thickness = thickness, Filled = false, Transparency = 1})
							end
							if t.box then
								t.box.Position = Vector2.new(bx, by)
								t.box.Size = Vector2.new(bw, bh)
								t.box.Color = color
								t.box.Thickness = thickness
								t.box.Visible = true
							end
						elseif t.box then
							t.box.Visible = false
						end

						-- CORNER BOX
						if visualEspState.cornerBoxEnabled and bx then
							VE.vespDrawCorners(t, bx, by, bw, bh, color, thickness)
						elseif t.corners then
							VE.vespHideCorners(t)
						end

						-- TRACER
						if visualEspState.tracersEnabled and inFront then
							if not t.tracer and Drawing then
								t.tracer = newDrawing("Line", {Thickness = thickness, Transparency = 1})
							end
							if t.tracer then
								t.tracer.From = originPt
								t.tracer.To = Vector2.new(rootS.X, rootS.Y)
								t.tracer.Color = color
								t.tracer.Thickness = thickness
								t.tracer.Visible = true
							end
						elseif t.tracer then
							t.tracer.Visible = false
						end

						-- SKELETON
						if visualEspState.skeletonEnabled and inFront then
							local hum = char:FindFirstChildOfClass("Humanoid")
							local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15
							local limbPairs = isR15 and VESP_R15_PAIRS or VESP_R6_PAIRS
							if not t.skel and Drawing then
								t.skel = {}
								for i = 1, #VESP_R15_PAIRS do
									t.skel[i] = newDrawing("Line", {Thickness = thickness, Transparency = 1})
								end
							end
							if t.skel then
								for i, pr in ipairs(limbPairs) do
									local pa = char:FindFirstChild(pr[1])
									local pb = char:FindFirstChild(pr[2])
									local l = t.skel[i]
									if l then
										if pa and pb and pa:IsA("BasePart") and pb:IsA("BasePart") then
											local sa, _, da = worldToScreen(pa.Position)
											local sb, _, db = worldToScreen(pb.Position)
											if da > 0 and db > 0 then
												l.From = Vector2.new(sa.X, sa.Y)
												l.To = Vector2.new(sb.X, sb.Y)
												l.Color = color
												l.Thickness = thickness
												l.Visible = true
											else
												l.Visible = false
											end
										else
											l.Visible = false
										end
									end
								end
								for i = #limbPairs + 1, #t.skel do
									if t.skel[i] then t.skel[i].Visible = false end
								end
							end
						elseif t.skel then
							for _, l in ipairs(t.skel) do if l then l.Visible = false end end
						end

						-- CHAMS (Highlight, independent of Drawing API)
						if visualEspState.chamsEnabled then
							local hl = visualEspState.highlights[player]
							local valid = false
							if hl then
								pcall(function() valid = (hl.Parent ~= nil and hl.Adornee == char) end)
							end
							if not valid then
								if hl then pcall(function() hl:Destroy() end) end
								hl = Instance.new("Highlight")
								hl.Name = "ChamsESP"
								hl.FillTransparency = 0.5
								hl.OutlineTransparency = 0
								hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
								hl.Adornee = char
								hl.Parent = char
								visualEspState.highlights[player] = hl
							end
							pcall(function()
								hl.FillColor = color
								hl.OutlineColor = color
							end)
						end

						-- OFF-SCREEN ARROW
						if visualEspState.offscreenArrowsEnabled and not onScreen then
							local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
							local target = Vector2.new(rootS.X, rootS.Y)
							local dir = inFront and (target - center) or (center - target)
							local mag = dir.Magnitude
							local ndir = (mag < 0.001) and Vector2.new(0, -1) or (dir / mag)
							local radius = math.min(viewport.X, viewport.Y) * 0.34
							local pos = center + ndir * radius
							local isMurderer = (roleState.murdererPlayer == player)
							VE.vespDrawArrow(t, ndir, pos, isMurderer and ROLE_COLORS.Murderer or color, isMurderer)
						elseif t.arrow then
							t.arrow.Visible = false
						end
					end)
				end
			end

			-- SNAPLINE to murderer (single line)
			if visualEspState.snaplineMurdererEnabled then
				local mp = roleState.murdererPlayer
				local mchar = mp and mp ~= LocalPlayer and mp.Character
				local mhrp = mchar and mchar:FindFirstChild("HumanoidRootPart")
				local shown = false
				if mhrp then
					local s, _, depth = worldToScreen(mhrp.Position)
					if depth > 0 then
						if not visualEspState.snaplineDrawing and Drawing then
							visualEspState.snaplineDrawing = newDrawing("Line", {Thickness = thickness, Transparency = 1})
						end
						local ln = visualEspState.snaplineDrawing
						if ln then
							ln.From = originPt
							ln.To = Vector2.new(s.X, s.Y)
							ln.Color = ROLE_COLORS.Murderer
							ln.Thickness = thickness
							ln.Visible = true
							shown = true
						end
					end
				end
				if not shown and visualEspState.snaplineDrawing then
					visualEspState.snaplineDrawing.Visible = false
				end
			end
		end)
	end

	function VE.vespAnyEnabled()
		return visualEspState.boxEnabled or visualEspState.cornerBoxEnabled or visualEspState.tracersEnabled
			or visualEspState.skeletonEnabled or visualEspState.chamsEnabled
			or visualEspState.offscreenArrowsEnabled or visualEspState.snaplineMurdererEnabled
	end

	function VE.vespStartDriver()
		if visualEspState.driverConnection then return end
		visualEspState.driverConnection = RunService.RenderStepped:Connect(VE.vespUpdate)
	end

	function VE.vespStopDriver()
		if visualEspState.driverConnection then
			visualEspState.driverConnection:Disconnect()
			visualEspState.driverConnection = nil
		end
	end

	function VE.vespSync()
		if VE.vespAnyEnabled() then VE.vespStartDriver() else VE.vespStopDriver() end
	end

	-- per-player cleanup when a player leaves
	Players.PlayerRemoving:Connect(function(player)
		pcall(function() VE.vespRemovePlayer(player) end)
	end)

	-- ---------------------------- UI ----------------------------

	createSectionLabel(tab, "ESP Suite", 30)

	createToggle(tab, "Box ESP", 31, function(on)
		visualEspState.boxEnabled = on
		if not on then VE.vespClearOverlay("box") end
		VE.vespSync()
		addLog(on and "[BOX ESP] ON" or "[BOX ESP] OFF", on and COLORS.success or COLORS.error)
	end)
	createToggle(tab, "Corner Box", 32, function(on)
		visualEspState.cornerBoxEnabled = on
		if not on then VE.vespClearOverlay("corners") end
		VE.vespSync()
		addLog(on and "[CORNER BOX] ON" or "[CORNER BOX] OFF", on and COLORS.success or COLORS.error)
	end)
	createToggle(tab, "Tracers", 33, function(on)
		visualEspState.tracersEnabled = on
		if not on then VE.vespClearOverlay("tracer") end
		VE.vespSync()
		addLog(on and "[TRACERS] ON" or "[TRACERS] OFF", on and COLORS.success or COLORS.error)
	end)
	createToggle(tab, "Skeleton ESP", 34, function(on)
		visualEspState.skeletonEnabled = on
		if not on then VE.vespClearOverlay("skeleton") end
		VE.vespSync()
		addLog(on and "[SKELETON ESP] ON" or "[SKELETON ESP] OFF", on and COLORS.success or COLORS.error)
	end)
	createToggle(tab, "Chams", 35, function(on)
		visualEspState.chamsEnabled = on
		if not on then VE.vespClearOverlay("chams") end
		VE.vespSync()
		addLog(on and "[CHAMS] ON" or "[CHAMS] OFF", on and COLORS.success or COLORS.error)
	end)
	createToggle(tab, "Off-Screen Arrows", 36, function(on)
		visualEspState.offscreenArrowsEnabled = on
		if not on then VE.vespClearOverlay("arrow") end
		VE.vespSync()
		addLog(on and "[OFFSCREEN ARROWS] ON" or "[OFFSCREEN ARROWS] OFF", on and COLORS.success or COLORS.error)
	end)
	createToggle(tab, "Snapline to Murderer", 37, function(on)
		visualEspState.snaplineMurdererEnabled = on
		if on then
			if not roleState.roleCheckEnabled then startRoleCheck() end
		else
			VE.vespClearOverlay("snapline")
		end
		VE.vespSync()
		addLog(on and "[SNAPLINE] ON" or "[SNAPLINE] OFF", on and COLORS.success or COLORS.error)
	end)

	createSlider(tab, "Tracer Thickness", 1, 6, 1, 38, function(value)
		visualEspState.tracerThickness = value
	end)

	local originBtn
	originBtn = createActionButton(tab, "Tracer Origin: Bottom", 39, function()
		local order = {"bottom", "top", "mouse"}
		local labels = {bottom = "Bottom", top = "Top", mouse = "Mouse"}
		local cur = visualEspState.tracerOrigin
		local idx = 1
		for i, v in ipairs(order) do if v == cur then idx = i end end
		idx = idx % #order + 1
		visualEspState.tracerOrigin = order[idx]
		if originBtn then originBtn.Text = "Tracer Origin: " .. labels[order[idx]] end
		addLog("[TRACER ORIGIN] " .. labels[order[idx]], COLORS.textSecondary)
	end)

	createInfoLabel(tab, "ESP Suite uses the executor Drawing API for lines/boxes.", 40)
	createInfoLabel(tab, "Colors: Red=Murderer, Blue=Sheriff, White=Innocent.", 41)
	createInfoLabel(tab, "Chams uses Highlight (works even without Drawing API).", 42)
end

-- =====================================================================
-- ======================== BUILD FARMING TAB ==========================
-- =====================================================================
do
	local tab = tabFrames["Farming"]

	createSectionLabel(tab, "Coins", 1)

	createToggle(tab, "Auto Coin Farm", 2, function(on)
		farmState.autoCoinFarmEnabled = on
		if on then startAutoCoinFarm() else stopAutoCoinFarm() end
	end)
	createSlider(tab, "Farm Speed (seconds)", 1, 20, math.floor(farmState.farmSpeed * 10), 3, function(val)
		farmState.farmSpeed = val / 10
	end)
	uiState.coinCountLabel = createInfoLabel(tab, "Coins Farmed: 0", 4)
	createToggle(tab, "Bring Coins To You", 5, function(on)
		miscState.bringCoinsEnabled = on
		if on then startBringCoins() else stopBringCoins() end
	end)
	createToggle(tab, "Auto Collect All", 6, function(on)
		miscState.autoCollectEnabled = on
		if on then startAutoCollect() else stopAutoCollect() end
	end)


	createSectionLabel(tab, "XP", 8)

	createToggle(tab, "Anti-AFK", 9, function(on)
		farmState.antiAfkEnabled = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)


	createSectionLabel(tab, "Info", 11)
	createInfoLabel(tab, "Auto Coin Farm teleports to each coin", 12)
	createInfoLabel(tab, "Bring Coins teleports coins to you", 13)
	createInfoLabel(tab, "Auto Collect fires touch events on coins", 14)
	createInfoLabel(tab, "Anti-AFK prevents idle kick", 15)
end

-- =====================================================================
-- ============== BUILD FARMING TAB - COIN DOMINATION (B2) =============
-- =====================================================================
do
	local tab = tabFrames["Farming"]


	createSectionLabel(tab, "Coin Domination", 20)

	createToggle(tab, "Coin Aura", 21, function(on)
		coinDomState.auraEnabled = on
		if on then coinDomState.startCoinAura() else coinDomState.stopCoinAura() end
	end)
	createSlider(tab, "Aura Radius", 10, 300, coinDomState.auraRadius, 22, function(val)
		coinDomState.auraRadius = val
	end)
	createActionButton(tab, "TP Through All Coins", 23, function()
		coinDomState.tpThroughAllCoins()
	end)
	createToggle(tab, "Coin Tracers", 24, function(on)
		coinDomState.tracersEnabled = on
		if on then coinDomState.startCoinTracers() else coinDomState.stopCoinTracers() end
	end)
	coinDomState.counterLabel = createInfoLabel(tab, "Coins Remaining: ...", 25)
	coinDomState.startCoinCounter()

	createInfoLabel(tab, "Aura sweeps to coins in radius then returns", 26)
	createInfoLabel(tab, "TP sweep vacuums every coin on the map once", 27)
end

-- =====================================================================
-- ======================== BUILD PLAYER TAB ==========================
-- =====================================================================
do
	local tab = tabFrames["Player"]

	createSectionLabel(tab, "Movement", 1)

	createToggle(tab, "Fly", 2, function(on)
		moveState.flyEnabled = on
		if on then startFly() else stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 500, moveState.flySpeed, 3, function(val) moveState.flySpeed = val end)
	createToggle(tab, "Speed Boost", 4, function(on)
		moveState.speedEnabled = on
		if on then startSpeed() else stopSpeed() end
	end)
	createSlider(tab, "Walk Speed", 16, 500, moveState.speedValue, 5, function(val)
		moveState.speedValue = val
		if moveState.speedEnabled then
			pcall(function()
				local character = LocalPlayer.Character
				if character then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then humanoid.WalkSpeed = val end
				end
			end)
		end
	end)
	createToggle(tab, "Noclip", 6, function(on)
		moveState.noclipEnabled = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "Infinite Jump", 7, function(on)
		moveState.infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)
	createSlider(tab, "Jump Power", 10, 500, moveState.jumpPowerValue, 8, function(val)
		moveState.jumpPowerValue = val
		setJumpPower(val)
	end)
	createToggle(tab, "Bunny Hop", 9, function(on)
		moveState.bunnyHopEnabled = on
		if on then startBunnyHop() else stopBunnyHop() end
	end)


	createSectionLabel(tab, "Survival", 11)

	createToggle(tab, "God Mode", 12, function(on)
		moveState.godEnabled = on
		if on then startGod() else stopGod() end
	end)
	createToggle(tab, "Invisible", 13, function(on)
		moveState.invisibleEnabled = on
		if on then startInvisible() else stopInvisible() end
	end)
	createToggle(tab, "Anti-Void", 14, function(on)
		miscState.antiVoidEnabled = on
		if on then startAntiVoid() else stopAntiVoid() end
	end)


	createSectionLabel(tab, "Camera", 16)

	createSlider(tab, "Camera FOV", 50, 120, moveState.cameraFOV, 17, function(val)
		moveState.cameraFOV = val
		setCameraFOV(val)
	end)


	createSectionLabel(tab, "World", 19)

	createSlider(tab, "Gravity", 0, 1000, moveState.gravityValue, 20, function(val)
		moveState.gravityValue = val
		setGravity(val)
	end)


	createSectionLabel(tab, "Player Target", 22)
	local selectedPlayerLabel = createDynamicLabel(tab, "Selected: None")

	createActionButton(tab, "Teleport to Player", 24, function()
		if miscState.selectedPlayer then
			tpToPlayer(miscState.selectedPlayer)
		else
			addLog("[TP] No player selected!", COLORS.error)
		end
	end)
	createActionButton(tab, "Spectate Player", 25, function()
		if miscState.selectedPlayer then
			spectatePlayer(miscState.selectedPlayer)
		else
			addLog("[SPECTATE] No player selected!", COLORS.error)
		end
	end)
	createActionButton(tab, "Unspectate", 26, function()
		unspectate()
	end)

	-- Player list frame
	local mm2Players, mm2Dropdown = {}, nil
	local function refreshPlayerList()
		mm2Players = {}
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local label = player.DisplayName .. " (@" .. player.Name .. ")"
				mm2Players[label] = player
				table.insert(names, label)
			end
		end
		if #names == 0 then names = {"(no players)"} end
		if mm2Dropdown then pcall(function() mm2Dropdown:Refresh(names) end) end
	end
	mm2Dropdown = createDropdown(tab, "Select Player", {"(refresh first)"}, "(refresh first)", function(choice)
		local player = mm2Players[choice]
		if not player then return end
		miscState.selectedPlayer = player
		selectedPlayerLabel.Text = "Selected: " .. player.DisplayName
	end)
	createActionButton(tab, "Refresh Player List", 28, refreshPlayerList)
	refreshPlayerList()
	Players.PlayerAdded:Connect(function() _wait(0.5) refreshPlayerList() end)
	Players.PlayerRemoving:Connect(function(player)
		if miscState.selectedPlayer == player then
			miscState.selectedPlayer = nil
			selectedPlayerLabel.Text = "Selected: None"
		end
		refreshPlayerList()
	end)
end

-- =====================================================================
-- ======================== BUILD FUN TAB =============================
-- =====================================================================
do
	local tab = tabFrames["Fun"]

	createSectionLabel(tab, "Fling", 1)

	local walkFlingToggle
	local spinFlingToggle = createToggle(tab, "Spin Fling", 2, function(on)
		if on and flingState.walkFlingEnabled then
			flingState.walkFlingEnabled = false
			stopWalkFling()
			if walkFlingToggle then walkFlingToggle.setVisualState(false) end
		end
		flingState.flingEnabled = on
		if on then startFling() else stopFling() end
	end)
	createSlider(tab, "Fling Power", 1000, 99999, flingState.flingPower, 3, function(val) flingState.flingPower = val end)
	walkFlingToggle = createToggle(tab, "Walk Fling", 4, function(on)
		if on and flingState.flingEnabled then
			flingState.flingEnabled = false
			stopFling()
			spinFlingToggle.setVisualState(false)
		end
		flingState.walkFlingEnabled = on
		if on then startWalkFling() else stopWalkFling() end
	end)
	createSlider(tab, "Walk Fling Power", 1000, 50000, flingState.walkFlingPower, 5, function(val) flingState.walkFlingPower = val end)


	createSectionLabel(tab, "Visual", 7)

	createToggle(tab, "Spin", 8, function(on)
		flingState.spinEnabled = on
		if on then startSpin() else stopSpin() end
	end)
	createToggle(tab, "Seizure", 9, function(on)
		flingState.seizureEnabled = on
		if on then startSeizure() else stopSeizure() end
	end)
	createToggle(tab, "Headless", 10, function(on)
		miscState.headlessEnabled = on
		if on then startHeadless() else stopHeadless() end
	end)
	createToggle(tab, "Rainbow Character", 11, function(on)
		miscState.rainbowEnabled = on
		if on then startRainbow() else stopRainbow() end
	end)


	createSectionLabel(tab, "Emotes", 13)

	createActionButton(tab, "Emote 1", 14, function()
		playJerkEmote()
	end)
	createActionButton(tab, "Dance", 15, function()
		playEmote(507771019, 1, 10)
		addLog("[EMOTE] Dance!", COLORS.success)
	end)
	createActionButton(tab, "Dab", 16, function()
		playEmote(183412246, 1, 3)
		addLog("[EMOTE] Dab!", COLORS.success)
	end)
	createActionButton(tab, "Stop Emote", 17, function()
		stopEmote()
		addLog("[EMOTE] Stopped", COLORS.error)
	end)
end

-- ======================== CONFIG TAB =============================
do
	local tab = tabFrames["Config"]

	createSectionLabel(tab, "Config", 1)
	createActionButton(tab, "Save Config", 2, configState.saveConfig)
	createActionButton(tab, "Load Config", 3, configState.loadConfig)
end

-- =====================================================================
-- ============ BUNDLE 4: QoL + UI OVERHAUL (Config tab) ==============
-- All generic (camera/movement/settings/Drawing/chat-read). No remotes.
-- =====================================================================
(function()
	local configTab = tabFrames["Config"]

	-- ---- config registry helper (toggles register name+get+set) ----
	local function registerConfigToggle(name, getFn, setFn)
		configState.registry = configState.registry or {}
		configState.registry[name] = {get = getFn, set = setFn}
	end

	-- ---- feature search (best-effort hide/show of control rows) ----
	local function labelTextOf(obj)
		if obj:IsA("TextButton") then return obj.Text end
		if obj:IsA("Frame") then
			-- skip panels that host their own scrolling content (log, player list)
			for _, c in ipairs(obj:GetChildren()) do
				if c:IsA("ScrollingFrame") then return nil end
			end
			for _, c in ipairs(obj:GetChildren()) do
				if c:IsA("TextLabel") then return c.Text end
			end
		end
		return nil
	end

	local function filterFeatures(query)
		query = tostring(query or ""):lower()
		qolState.searchQuery = query
		for _, frame in pairs(tabFrames) do
			for _, child in ipairs(frame:GetChildren()) do
				pcall(function()
					if child.Name == "QoLSearchRow" then return end
					if child:IsA("ScrollingFrame") then return end
					if child:IsA("TextButton") or child:IsA("Frame") then
						local txt = labelTextOf(child)
						if txt then
							if query == "" then
								child.Visible = true
							else
								child.Visible = (txt:lower():find(query, 1, true) ~= nil)
							end
						end
					end
				end)
			end
		end
	end

	-- ---- FPS booster / low graphics ----
	local function startFpsBoost()
		pcall(function()
			local s = settings()
			if qolState.origQualityLevel == nil then qolState.origQualityLevel = s.Rendering.QualityLevel end
			s.Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
		pcall(function()
			if qolState.origGlobalShadows == nil then qolState.origGlobalShadows = Lighting.GlobalShadows end
			Lighting.GlobalShadows = false
		end)
		pcall(function()
			if qolState.origWaterWaveSize == nil then qolState.origWaterWaveSize = workspace.Terrain.WaterWaveSize end
			workspace.Terrain.WaterWaveSize = 0
			workspace.Terrain.WaterWaveSpeed = 0
		end)
		pcall(function()
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("BasePart") then
					pcall(function() d.Material = Enum.Material.SmoothPlastic end)
				elseif d:IsA("Decal") or d:IsA("Texture") then
					pcall(function() d.Transparency = 1 end)
				end
			end
		end)
		addLog("[QoL] FPS Booster ON (low graphics)", COLORS.success)
	end
	local function stopFpsBoost()
		pcall(function()
			local s = settings()
			if qolState.origQualityLevel ~= nil then s.Rendering.QualityLevel = qolState.origQualityLevel end
		end)
		pcall(function()
			if qolState.origGlobalShadows ~= nil then Lighting.GlobalShadows = qolState.origGlobalShadows end
		end)
		pcall(function()
			if qolState.origWaterWaveSize ~= nil then workspace.Terrain.WaterWaveSize = qolState.origWaterWaveSize end
		end)
		addLog("[QoL] FPS Booster OFF (materials/decals stay)", COLORS.textSecondary)
	end

	-- ---- Freecam (detach camera, WASD/arrows/space/ctrl to fly) ----
	local function startFreecam()
		pcall(function()
			local cf = Camera.CFrame
			qolState.freecamPos = cf.Position
			local rx, ry = cf:ToEulerAnglesYXZ()
			qolState.freecamPitch = rx
			qolState.freecamYaw = ry
			Camera.CameraType = Enum.CameraType.Scriptable
		end)
		if qolState.freecamConn then qolState.freecamConn:Disconnect() qolState.freecamConn = nil end
		qolState.freecamConn = RunService.RenderStepped:Connect(function(dt)
			pcall(function()
				if not qolState.freecamEnabled then return end
				dt = (dt and dt > 0) and dt or 0.016
				local rotSpeed = 1.8 * dt
				if UserInputService:IsKeyDown(Enum.KeyCode.Left) then qolState.freecamYaw = qolState.freecamYaw + rotSpeed end
				if UserInputService:IsKeyDown(Enum.KeyCode.Right) then qolState.freecamYaw = qolState.freecamYaw - rotSpeed end
				if UserInputService:IsKeyDown(Enum.KeyCode.Up) then qolState.freecamPitch = math.clamp(qolState.freecamPitch + rotSpeed, -1.4, 1.4) end
				if UserInputService:IsKeyDown(Enum.KeyCode.Down) then qolState.freecamPitch = math.clamp(qolState.freecamPitch - rotSpeed, -1.4, 1.4) end
				local baseCF = CFrame.new(qolState.freecamPos) * CFrame.Angles(0, qolState.freecamYaw, 0) * CFrame.Angles(qolState.freecamPitch, 0, 0)
				local moveSpeed = qolState.freecamSpeed * dt
				local dir = Vector3.new(0, 0, 0)
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + baseCF.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - baseCF.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + baseCF.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - baseCF.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
				if dir.Magnitude > 0 then qolState.freecamPos = qolState.freecamPos + dir.Unit * moveSpeed end
				Camera.CFrame = CFrame.new(qolState.freecamPos) * CFrame.Angles(0, qolState.freecamYaw, 0) * CFrame.Angles(qolState.freecamPitch, 0, 0)
			end)
		end)
		addLog("[QoL] Freecam ON (WASD move, arrows look, Space/Ctrl up-down)", COLORS.success)
	end
	local function stopFreecam()
		if qolState.freecamConn then qolState.freecamConn:Disconnect() qolState.freecamConn = nil end
		pcall(function()
			Camera.CameraType = Enum.CameraType.Custom
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then Camera.CameraSubject = hum end
		end)
		addLog("[QoL] Freecam OFF", COLORS.textSecondary)
	end

	-- ---- Click-TP (click a spot to teleport HRP there) ----
	local function startClickTp()
		if qolState.mouse == nil then
			pcall(function() qolState.mouse = LocalPlayer:GetMouse() end)
		end
		if qolState.clickTpConn then return end
		qolState.clickTpConn = UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if not qolState.clickTpEnabled then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				pcall(function()
					local char = LocalPlayer.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					if hrp and qolState.mouse then
						local hit = qolState.mouse.Hit
						if hit then hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0)) end
					end
				end)
			end
		end)
		addLog("[QoL] Click TP ON (click ground to teleport)", COLORS.success)
	end
	local function stopClickTp()
		if qolState.clickTpConn then qolState.clickTpConn:Disconnect() qolState.clickTpConn = nil end
		addLog("[QoL] Click TP OFF", COLORS.textSecondary)
	end

	-- ---- Save / Load position ----
	local function savePosition()
		pcall(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				qolState.savedPos = hrp.CFrame
				addLog("[QoL] Position saved", COLORS.success)
			else
				addLog("[QoL] No character to save", COLORS.error)
			end
		end)
	end
	local function loadPosition()
		pcall(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and qolState.savedPos then
				hrp.CFrame = qolState.savedPos
				addLog("[QoL] Teleported to saved position", COLORS.success)
			else
				addLog("[QoL] No saved position", COLORS.error)
			end
		end)
	end

	-- ---- Auto-rejoin on death ----
	local function startAutoRejoin()
		if qolState.autoRejoinConn then qolState.autoRejoinConn:Disconnect() qolState.autoRejoinConn = nil end
		pcall(function()
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				qolState.autoRejoinConn = hum.Died:Connect(function()
					if qolState.autoRejoinEnabled then
						pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
					end
				end)
			end
		end)
	end
	local function stopAutoRejoin()
		if qolState.autoRejoinConn then qolState.autoRejoinConn:Disconnect() qolState.autoRejoinConn = nil end
	end

	-- ---- Chat spy / logger (legacy Chatted + TextChatService) ----
	local function stopChatSpy()
		for _, c in ipairs(qolState.chatSpyConns) do pcall(function() c:Disconnect() end) end
		qolState.chatSpyConns = {}
	end
	local function startChatSpy()
		stopChatSpy()
		-- legacy per-player Chatted
		pcall(function()
			local function hook(p)
				local ok, conn = pcall(function()
					return p.Chatted:Connect(function(msg)
						if qolState.chatSpyEnabled then
							addLog("[CHAT] " .. p.Name .. ": " .. tostring(msg), COLORS.textSecondary)
						end
					end)
				end)
				if ok and conn then table.insert(qolState.chatSpyConns, conn) end
			end
			for _, p in ipairs(Players:GetPlayers()) do hook(p) end
			table.insert(qolState.chatSpyConns, Players.PlayerAdded:Connect(function(p) hook(p) end))
		end)
		-- modern TextChatService
		pcall(function()
			local TCS = game:GetService("TextChatService")
			if TCS and TCS.MessageReceived then
				local conn = TCS.MessageReceived:Connect(function(message)
					if qolState.chatSpyEnabled then
						local name = "?"
						pcall(function() if message.TextSource then name = message.TextSource.Name end end)
						addLog("[CHAT] " .. name .. ": " .. tostring(message.Text), COLORS.textSecondary)
					end
				end)
				table.insert(qolState.chatSpyConns, conn)
			end
		end)
		addLog("[QoL] Chat Spy ON", COLORS.success)
	end

	-- ---- Keybinds (reuse infra keybind registry) ----
	local KEYBIND_FEATURES = {"Fly", "Noclip", "Speed", "Aimbot", "UIToggle"}

	local function updateBindInfo()
		if not qolState.bindInfoLabel then return end
		local parts = {}
		for _, feat in ipairs(KEYBIND_FEATURES) do
			local k = (keybinds[feat] and keybinds[feat].key) or "-"
			table.insert(parts, feat .. ":" .. k)
		end
		qolState.bindInfoLabel.Text = table.concat(parts, "  ")
	end

	bindKey("Fly", "F", function()
		moveState.flyEnabled = not moveState.flyEnabled
		if moveState.flyEnabled then startFly() else stopFly() end
		addLog("[KEYBIND] Fly " .. (moveState.flyEnabled and "ON" or "OFF"), COLORS.accent)
	end)
	bindKey("Noclip", "N", function()
		moveState.noclipEnabled = not moveState.noclipEnabled
		if moveState.noclipEnabled then startNoclip() else stopNoclip() end
		addLog("[KEYBIND] Noclip " .. (moveState.noclipEnabled and "ON" or "OFF"), COLORS.accent)
	end)
	bindKey("Speed", "G", function()
		moveState.speedEnabled = not moveState.speedEnabled
		if moveState.speedEnabled then startSpeed() else stopSpeed() end
		addLog("[KEYBIND] Speed " .. (moveState.speedEnabled and "ON" or "OFF"), COLORS.accent)
	end)
	bindKey("Aimbot", "H", function()
		sheriffState.aimbotEnabled = not sheriffState.aimbotEnabled
		if sheriffState.aimbotEnabled then SH.startSheriffAimbot() else SH.stopSheriffAimbot() end
		addLog("[KEYBIND] Aimbot " .. (sheriffState.aimbotEnabled and "ON" or "OFF"), COLORS.accent)
	end)
	bindKey("UIToggle", "K", function()
		-- WindUI owns show/hide; the old window vars are gone.
		if _G.SX_UI then pcall(function() _G.SX_UI:ToggleUI() end) end
	end)

	-- capture the next key press when a Bind button is armed
	UserInputService.InputBegan:Connect(function(input, gp)
		if not qolState.capturingBind then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local feat = qolState.capturingBind
		qolState.capturingBind = nil
		local keyName = input.KeyCode.Name
		setKeybind(feat, keyName)
		if qolState.bindButtons[feat] then
			qolState.bindButtons[feat].Text = "Bind: " .. feat .. " [" .. keyName .. "]"
		end
		updateBindInfo()
		addLog("[KEYBIND] " .. feat .. " -> " .. keyName, COLORS.success)
	end)

	-- ================= CONFIG TAB UI =================

	-- Feature search box (top of Config tab)
	local searchRow = Instance.new("Frame")
	searchRow.Name = "QoLSearchRow"
	searchRow.Size = UDim2.new(1, 0, 0, 30)
	searchRow.BackgroundColor3 = COLORS.tabBg
	searchRow.BorderSizePixel = 0
	searchRow.LayoutOrder = 0
	searchRow.Parent = configTab
	addCorner(searchRow, 5)

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -16, 1, 0)
	searchBox.Position = UDim2.new(0, 8, 0, 0)
	searchBox.BackgroundTransparency = 1
	searchBox.Text = ""
	searchBox.PlaceholderText = "Search features across tabs..."
	searchBox.TextColor3 = COLORS.textPrimary
	searchBox.PlaceholderColor3 = COLORS.textDim
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 12
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = searchRow
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		pcall(function() filterFeatures(searchBox.Text) end)
	end)

	createSectionLabel(configTab, "QoL", 10)

	-- FPS Booster
	local fpsBoostToggle
	local function setFpsBoost(v)
		qolState.fpsBoostEnabled = v
		if v then startFpsBoost() else stopFpsBoost() end
		if fpsBoostToggle then pcall(function() fpsBoostToggle.setVisualState(v) end) end
	end
	fpsBoostToggle = createToggle(configTab, "FPS Booster (Low Graphics)", 11, function(on) setFpsBoost(on) end)

	-- Watermark / FPS counter
	local watermarkToggle
	local function setWatermark(v)
		qolState.watermarkEnabled = v
		if qolState.watermarkLabel then qolState.watermarkLabel.Visible = v end
		if watermarkToggle then pcall(function() watermarkToggle.setVisualState(v) end) end
	end
	watermarkToggle = createToggle(configTab, "FPS Counter / Watermark", 12, function(on) setWatermark(on) end)

	-- Freecam
	local freecamToggle
	local function setFreecam(v)
		qolState.freecamEnabled = v
		if v then startFreecam() else stopFreecam() end
		if freecamToggle then pcall(function() freecamToggle.setVisualState(v) end) end
	end
	freecamToggle = createToggle(configTab, "Freecam", 13, function(on) setFreecam(on) end)

	-- Click TP
	local clickTpToggle
	local function setClickTp(v)
		qolState.clickTpEnabled = v
		if v then startClickTp() else stopClickTp() end
		if clickTpToggle then pcall(function() clickTpToggle.setVisualState(v) end) end
	end
	clickTpToggle = createToggle(configTab, "Click TP", 14, function(on) setClickTp(on) end)

	-- Auto-rejoin on death
	local autoRejoinToggle
	local function setAutoRejoin(v)
		qolState.autoRejoinEnabled = v
		if v then startAutoRejoin() else stopAutoRejoin() end
		if autoRejoinToggle then pcall(function() autoRejoinToggle.setVisualState(v) end) end
		addLog("[QoL] Auto-Rejoin " .. (v and "ON" or "OFF"), v and COLORS.success or COLORS.textSecondary)
	end
	autoRejoinToggle = createToggle(configTab, "Auto-Rejoin on Death", 15, function(on) setAutoRejoin(on) end)

	-- Chat spy
	local chatSpyToggle
	local function setChatSpy(v)
		qolState.chatSpyEnabled = v
		if v then startChatSpy() else stopChatSpy() addLog("[QoL] Chat Spy OFF", COLORS.textSecondary) end
		if chatSpyToggle then pcall(function() chatSpyToggle.setVisualState(v) end) end
	end
	chatSpyToggle = createToggle(configTab, "Chat Spy / Logger", 16, function(on) setChatSpy(on) end)

	-- Save / Load position
	createActionButton(configTab, "Save Position", 17, savePosition)
	createActionButton(configTab, "Load Position", 18, loadPosition)

	-- Keybinds section
	createSectionLabel(configTab, "Keybinds", 19)
	local bindOrder = 20
	for _, feat in ipairs(KEYBIND_FEATURES) do
		local defKey = (keybinds[feat] and keybinds[feat].key) or "-"
		local btn = createActionButton(configTab, "Bind: " .. feat .. " [" .. defKey .. "]", bindOrder, function()
			qolState.capturingBind = feat
			if qolState.bindButtons[feat] then
				qolState.bindButtons[feat].Text = "Press any key... (" .. feat .. ")"
			end
			addLog("[KEYBIND] Press a key to bind " .. feat, COLORS.textSecondary)
		end)
		qolState.bindButtons[feat] = btn
		bindOrder = bindOrder + 1
	end
	qolState.bindInfoLabel = createInfoLabel(configTab, "", 26)
	updateBindInfo()

	createInfoLabel(configTab, "Save Config snapshots every registered toggle.", 30)
	createInfoLabel(configTab, "Load Config re-applies them (movement/visual/QoL).", 31)

	-- ================= FPS COUNTER / WATERMARK (own label) =================
	local wm = Instance.new("TextLabel")
	wm.Name = "SXWatermark"
	wm.Size = UDim2.new(0, 280, 0, 22)
	wm.Position = UDim2.new(0.5, -140, 0, 6)
	wm.BackgroundColor3 = COLORS.bg
	wm.BackgroundTransparency = 0.35
	wm.Text = "MM2 Hub | FPS: --"
	wm.TextColor3 = COLORS.accent
	wm.Font = Enum.Font.GothamBold
	wm.TextSize = 12
	wm.Visible = qolState.watermarkEnabled
	wm.Parent = screenGui
	addCorner(wm, 5)
	addStroke(wm, COLORS.accentDark, 1)
	qolState.watermarkLabel = wm
	if watermarkToggle then pcall(function() watermarkToggle.setVisualState(qolState.watermarkEnabled) end) end

	qolState.watermarkConn = RunService.RenderStepped:Connect(function(dt)
		pcall(function()
			if dt and dt > 0 then
				qolState.fps = (qolState.fps or 60) * 0.9 + (1 / dt) * 0.1
			end
			qolState.fpsThrottle = (qolState.fpsThrottle or 0) + (dt or 0)
			if qolState.fpsThrottle >= 0.25 then
				qolState.fpsThrottle = 0
				if qolState.watermarkLabel then
					qolState.watermarkLabel.Visible = qolState.watermarkEnabled
					if qolState.watermarkEnabled then
						local pingTxt = ""
						pcall(function()
							local stats = game:GetService("Stats")
							local ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
							pingTxt = " | Ping: " .. tostring(math.floor(ping)) .. "ms"
						end)
						qolState.watermarkLabel.Text = "MM2 Hub | FPS: " .. tostring(math.floor(qolState.fps + 0.5)) .. pingTxt
					end
				end
			end
		end)
	end)

	-- ================= CONFIG REGISTRY (persist + restore) =================
	-- Simple movement / visual toggles (best-effort start/stop, no visual sync)
	registerConfigToggle("Fly", function() return moveState.flyEnabled end, function(v) moveState.flyEnabled = v if v then startFly() else stopFly() end end)
	registerConfigToggle("Noclip", function() return moveState.noclipEnabled end, function(v) moveState.noclipEnabled = v if v then startNoclip() else stopNoclip() end end)
	registerConfigToggle("Speed", function() return moveState.speedEnabled end, function(v) moveState.speedEnabled = v if v then startSpeed() else stopSpeed() end end)
	registerConfigToggle("InfiniteJump", function() return moveState.infJumpEnabled end, function(v) moveState.infJumpEnabled = v if v then startInfJump() else stopInfJump() end end)
	registerConfigToggle("God", function() return moveState.godEnabled end, function(v) moveState.godEnabled = v if v then startGod() else stopGod() end end)
	registerConfigToggle("Invisible", function() return moveState.invisibleEnabled end, function(v) moveState.invisibleEnabled = v if v then startInvisible() else stopInvisible() end end)
	registerConfigToggle("BunnyHop", function() return moveState.bunnyHopEnabled end, function(v) moveState.bunnyHopEnabled = v if v then startBunnyHop() else stopBunnyHop() end end)
	registerConfigToggle("ESP", function() return espState.espEnabled end, function(v)
		espState.espEnabled = v
		if v then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			enablePlayerEsp()
		else
			disablePlayerEsp()
		end
	end)
	registerConfigToggle("Fullbright", function() return espState.fullbrightEnabled end, function(v) espState.fullbrightEnabled = v if v then startFullbright() else stopFullbright() end end)
	-- QoL toggles (setters sync their toggle visual state)
	registerConfigToggle("FpsBooster", function() return qolState.fpsBoostEnabled end, setFpsBoost)
	registerConfigToggle("Watermark", function() return qolState.watermarkEnabled end, setWatermark)
	registerConfigToggle("Freecam", function() return qolState.freecamEnabled end, setFreecam)
	registerConfigToggle("ClickTP", function() return qolState.clickTpEnabled end, setClickTp)
	registerConfigToggle("AutoRejoin", function() return qolState.autoRejoinEnabled end, setAutoRejoin)
	registerConfigToggle("ChatSpy", function() return qolState.chatSpyEnabled end, setChatSpy)

	-- ================= RESPAWN HOOK (called from CharacterAdded) =================
	qolState.onRespawn = function(char)
		if qolState.autoRejoinEnabled then startAutoRejoin() end
		if qolState.freecamEnabled then
			pcall(function() Camera.CameraType = Enum.CameraType.Scriptable end)
		end
	end
end)()

-- =====================================================================
-- ============ BUNDLE 5: EXTRAS GRAB-BAG =============================
-- All generic (movement/noclip/transparency/logging/keybind). No remotes.
-- =====================================================================
do
	local HIP_DEFAULT = 2

	-- ---- Ghost mode: noclip + semi-transparent local character (client-only) ----
	local function startGhost()
		if extrasState.ghostConnection then pcall(function() extrasState.ghostConnection:Disconnect() end) extrasState.ghostConnection = nil end
		extrasState.ghostConnection = RunService.Heartbeat:Connect(function()
			if not extrasState.ghostEnabled then return end
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
						part.LocalTransparencyModifier = extrasState.ghostTransparency
					end
				end
			end)
		end)
		addLog("[GHOST] ON (local-visual: noclip + transparency)", COLORS.success)
	end

	local function stopGhost()
		if extrasState.ghostConnection then pcall(function() extrasState.ghostConnection:Disconnect() end) extrasState.ghostConnection = nil end
		pcall(function()
			local char = LocalPlayer.Character
			if char then
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = 0
						if not moveState.noclipEnabled then part.CanCollide = true end
					end
				end
			end
		end)
		addLog("[GHOST] OFF", COLORS.error)
	end

	-- ---- Auto-dodge murderer knife: sideways HRP velocity nudge (MM2-safe Assembly prop) ----
	local function startDodge()
		if extrasState.dodgeConnection then pcall(function() extrasState.dodgeConnection:Disconnect() end) extrasState.dodgeConnection = nil end
		extrasState.dodgeConnection = RunService.Heartbeat:Connect(function()
			if not extrasState.dodgeEnabled then return end
			pcall(function()
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then return end
				local now = os.clock()
				local myPos = hrp.Position
				-- Sustain an active dodge burst across several frames so the walk
				-- controller can't immediately damp a single-frame velocity set.
				if extrasState.dodgeDir and now < (extrasState.dodgeActiveUntil or 0) then
					hrp.AssemblyLinearVelocity = extrasState.dodgeDir * 55 + Vector3.new(0, 14, 0)
					return
				end
				if now - (extrasState.lastDodge or 0) < extrasState.dodgeCooldown then return end
				local threatDir = nil
				-- (1) Thrown-knife / projectile detection (generic, name-independent):
				-- efficient spatial query for small fast-moving parts heading at us.
				pcall(function()
					local params = OverlapParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { char }
					params.MaxParts = 50
					local nearby = workspace:GetPartBoundsInRadius(myPos, extrasState.dodgeThrowRadius or 60, params)
					local best = 0.55
					for _, part in ipairs(nearby) do
						if part:IsA("BasePart") and not part.Anchored then
							local vel = part.AssemblyLinearVelocity
							if vel.Magnitude >= (extrasState.dodgeThrowSpeed or 45) then
								local sz = part.Size
								if sz.X < 8 and sz.Y < 8 and sz.Z < 8 then
									local toMe = myPos - part.Position
									if toMe.Magnitude > 1 then
										local approach = vel.Unit:Dot(toMe.Unit)
										if approach > best then
											best = approach
											threatDir = vel.Unit
										end
									end
								end
							end
						end
					end
				end)
				-- (2) Melee / rush detection: murderer close AND facing us.
				if not threatDir then
					local murderer = roleState.murdererPlayer
					local mChar = murderer and murderer ~= LocalPlayer and murderer.Character
					local mHrp = mChar and mChar:FindFirstChild("HumanoidRootPart")
					if mHrp then
						local toMe = myPos - mHrp.Position
						local dist = toMe.Magnitude
						if dist <= extrasState.dodgeDistance and dist > 0.1 then
							local facing = mHrp.CFrame.LookVector:Dot(toMe.Unit)
							if dist <= (extrasState.dodgeMeleeRange or 9) or facing > 0.55 then
								threatDir = (-toMe).Unit
							end
						end
					end
				end
				if not threatDir then return end
				-- Dodge PERPENDICULAR to the threat's path (sideways out of the line of fire).
				local side = threatDir:Cross(Vector3.new(0, 1, 0))
				if side.Magnitude < 0.1 then side = hrp.CFrame.RightVector end
				side = side.Unit
				local v = hrp.AssemblyLinearVelocity
				local lateral = v - threatDir * v:Dot(threatDir)
				if lateral:Dot(side) < 0 then side = -side end
				extrasState.dodgeDir = side
				extrasState.dodgeActiveUntil = now + 0.28
				extrasState.lastDodge = now
				hrp.AssemblyLinearVelocity = side * 55 + Vector3.new(0, 14, 0)
				addLog("[DODGE] Evaded incoming threat", COLORS.accent)
			end)
		end)
		addLog("[DODGE] ON - dodges thrown knives + close murderer rushes", COLORS.success)
	end

	local function stopDodge()
		if extrasState.dodgeConnection then pcall(function() extrasState.dodgeConnection:Disconnect() end) extrasState.dodgeConnection = nil end
		addLog("[DODGE] OFF", COLORS.error)
	end

	-- ---- Trap auto-avoid: reuse the name-based trap detection Trapdoor ESP uses ----
	local function getTraps()
		local traps = {}
		pcall(function()
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("BasePart") and (obj.Name == "Trap" or obj.Name == "Trapdoor" or obj.Name == "TrapDoor" or obj.Name:lower():find("trap")) then
					table.insert(traps, obj)
				end
			end
		end)
		return traps
	end

	local trapCache = {}
	local lastTrapScan = 0

	local function startTrapAvoid()
		if extrasState.trapAvoidConnection then pcall(function() extrasState.trapAvoidConnection:Disconnect() end) extrasState.trapAvoidConnection = nil end
		trapCache = getTraps()
		lastTrapScan = os.clock()
		if #trapCache == 0 then
			addLog("[TRAP AVOID] No trap parts found by name yet; will keep scanning (map may need recon)", COLORS.textSecondary)
		end
		extrasState.trapAvoidConnection = RunService.Heartbeat:Connect(function()
			if not extrasState.trapAvoidEnabled then return end
			pcall(function()
				local now = os.clock()
				if now - lastTrapScan > 1 then
					lastTrapScan = now
					trapCache = getTraps()
				end
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then return end
				for _, trap in ipairs(trapCache) do
					if trap and trap.Parent then
						local d = (hrp.Position - trap.Position).Magnitude
						if d <= extrasState.trapAvoidRadius then
							if now - (extrasState.lastTrapNudge or 0) >= 0.5 then
								extrasState.lastTrapNudge = now
								local away = hrp.Position - trap.Position
								local flat = Vector3.new(away.X, 0, away.Z)
								if flat.Magnitude < 0.1 then flat = hrp.CFrame.LookVector end
								hrp.AssemblyLinearVelocity = flat.Unit * 45 + Vector3.new(0, 10, 0)
								addLog("[TRAP AVOID] Nudged away from " .. trap.Name, COLORS.accent)
							end
							break
						end
					end
				end
			end)
		end)
		addLog("[TRAP AVOID] ON - avoid traps within " .. extrasState.trapAvoidRadius .. " studs", COLORS.success)
	end

	local function stopTrapAvoid()
		if extrasState.trapAvoidConnection then pcall(function() extrasState.trapAvoidConnection:Disconnect() end) extrasState.trapAvoidConnection = nil end
		addLog("[TRAP AVOID] OFF", COLORS.error)
	end

	-- ---- Hip height (one-shot property; re-applied via onRespawn) ----
	local function setHipHeight(v)
		pcall(function()
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum.HipHeight = v end
		end)
	end

	-- ---- Player-join logger ----
	local function startJoinLogger()
		if extrasState.joinLoggerConn then pcall(function() extrasState.joinLoggerConn:Disconnect() end) extrasState.joinLoggerConn = nil end
		extrasState.joinLoggerConn = Players.PlayerAdded:Connect(function(plr)
			pcall(function() addLog("[JOIN] " .. plr.Name .. " joined", COLORS.textSecondary) end)
		end)
		addLog("[JOIN LOGGER] ON", COLORS.success)
	end

	local function stopJoinLogger()
		if extrasState.joinLoggerConn then pcall(function() extrasState.joinLoggerConn:Disconnect() end) extrasState.joinLoggerConn = nil end
		addLog("[JOIN LOGGER] OFF", COLORS.error)
	end

	-- ================= PLAYER TAB UI (Extras / Evasion) =================
	local ptab = tabFrames["Player"]
	if ptab then
		createSectionLabel(ptab, "Extras - Evasion", 40)

		createToggle(ptab, "Ghost Mode (local-visual)", 41, function(on)
			extrasState.ghostEnabled = on
			if on then startGhost() else stopGhost() end
		end)
		createSlider(ptab, "Ghost Transparency %", 0, 100, 60, 42, function(val)
			extrasState.ghostTransparency = math.clamp(val / 100, 0, 0.95)
		end)
		createToggle(ptab, "Auto-Dodge Knife", 43, function(on)
			extrasState.dodgeEnabled = on
			if on then
				if not roleState.roleCheckEnabled then startRoleCheck() end
				startDodge()
			else
				stopDodge()
			end
		end)
		createSlider(ptab, "Dodge Trigger Distance", 4, 40, extrasState.dodgeDistance, 44, function(val)
			extrasState.dodgeDistance = val
		end)
		createToggle(ptab, "Trap Auto-Avoid", 45, function(on)
			extrasState.trapAvoidEnabled = on
			if on then startTrapAvoid() else stopTrapAvoid() end
		end)
		createSlider(ptab, "Trap Avoid Radius", 4, 40, extrasState.trapAvoidRadius, 46, function(val)
			extrasState.trapAvoidRadius = val
		end)
		createSlider(ptab, "Hip Height", 0, 15, HIP_DEFAULT, 47, function(val)
			extrasState.hipHeightValue = val
			setHipHeight(val)
		end)
		createInfoLabel(ptab, "Ghost/Dodge/Trap are client-side movement only.", 48)
	end

	-- ================= FUN TAB UI (Utility) =================
	local ftab = tabFrames["Fun"]
	if ftab then
		createSectionLabel(ftab, "Utility - Extras", 60)
		createToggle(ftab, "Player-Join Logger", 61, function(on)
			extrasState.joinLoggerEnabled = on
			if on then startJoinLogger() else stopJoinLogger() end
		end)
	end

	-- ================= UI MINIMIZE KEYBIND (infra keybind registry) =================
	-- Registered via bindKey so it is rebindable. Defaults to RightControl:
	-- RightShift is already handled by a hardcoded toggle elsewhere, so binding a
	-- second RightShift handler here would double-toggle (net no-op / dead key).
	bindKey("UIMinimize", "RightControl", function()
		if _G.SX_UI then pcall(function() _G.SX_UI:ToggleUI() end) end
	end)

	-- ================= RESPAWN HOOK (called from CharacterAdded) =================
	extrasState.onRespawn = function(char)
		-- Ghost/Dodge/Trap-Avoid loops re-read LocalPlayer.Character each frame,
		-- so they survive death on their own. Only Hip Height is a one-shot set.
		if extrasState.hipHeightValue and extrasState.hipHeightValue ~= HIP_DEFAULT then
			pcall(function()
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then hum.HipHeight = extrasState.hipHeightValue end
			end)
		end
	end
end

-- =====================================================================
-- ======================== CHAT COMMANDS =============================
-- =====================================================================
local commands = {}

-- Combat
commands["murderesp"] = function() combatState.murdererEspEnabled = true if not roleState.roleCheckEnabled then startRoleCheck() end enableMurdererEsp() end
commands["unmurderesp"] = function() combatState.murdererEspEnabled = false disableMurdererEsp() end
commands["alert"] = function() combatState.murdererAlertEnabled = true if not roleState.roleCheckEnabled then startRoleCheck() end startMurdererAlert() end
commands["unalert"] = function() combatState.murdererAlertEnabled = false stopMurdererAlert() end
commands["autoshoot"] = function() combatState.autoShootMurdererEnabled = true if not roleState.roleCheckEnabled then startRoleCheck() end startAutoShootMurderer() end
commands["tpkill"] = function() if not roleState.roleCheckEnabled then startRoleCheck() end tpKillMurderer() end
commands["unautoshoot"] = function() combatState.autoShootMurdererEnabled = false stopAutoShootMurderer() end
commands["grabgun"] = function() grabDroppedGun() end
commands["bringgun"] = function() bringGun() end
commands["autograb"] = function() miscState.autoGrabGunEnabled = true startAutoGrabGun() end
commands["unautograb"] = function() miscState.autoGrabGunEnabled = false stopAutoGrabGun() end
commands["tpbehind"] = function(args)
	local name = args[1]
	if name then tpBehindPlayer(name) else addLog("[TP BEHIND] Usage: ;tpbehind <player>", COLORS.error) end
end
commands["killall"] = function() miscState.killAllEnabled = true if not roleState.roleCheckEnabled then startRoleCheck() end startKillAll() end
commands["unkillall"] = function() miscState.killAllEnabled = false stopKillAll() end
commands["kill"] = function(args)
	local name = args[1]
	if name then if not roleState.roleCheckEnabled then startRoleCheck() end killSpecificPlayer(name) else addLog("[KILL] Usage: ;kill <player>", COLORS.error) end
end

-- ESP
commands["esp"] = function() espState.espEnabled = true if not roleState.roleCheckEnabled then startRoleCheck() end enablePlayerEsp() end
commands["unesp"] = function() espState.espEnabled = false disablePlayerEsp() end
commands["gunesp"] = function() espState.gunEspEnabled = true enableGunEsp() end
commands["ungunesp"] = function() espState.gunEspEnabled = false disableGunEsp() end
commands["coinesp"] = function() espState.coinEspEnabled = true enableCoinEsp() end
commands["uncoinesp"] = function() espState.coinEspEnabled = false disableCoinEsp() end
commands["fullbright"] = function() espState.fullbrightEnabled = true startFullbright() end
commands["unfullbright"] = function() espState.fullbrightEnabled = false stopFullbright() end
commands["xray"] = function() miscState.xrayEnabled = true startXRay() end
commands["unxray"] = function() miscState.xrayEnabled = false stopXRay() end
commands["trapdooresp"] = function() miscState.trapdoorEspEnabled = true startTrapdoorEsp() end
commands["untrapdooresp"] = function() miscState.trapdoorEspEnabled = false stopTrapdoorEsp() end

-- Farming
commands["coinfarm"] = function() farmState.autoCoinFarmEnabled = true startAutoCoinFarm() end
commands["uncoinfarm"] = function() farmState.autoCoinFarmEnabled = false stopAutoCoinFarm() end
commands["antiafk"] = function() farmState.antiAfkEnabled = true startAntiAfk() end
commands["unantiafk"] = function() farmState.antiAfkEnabled = false stopAntiAfk() end
commands["bringcoins"] = function() miscState.bringCoinsEnabled = true startBringCoins() end
commands["unbringcoins"] = function() miscState.bringCoinsEnabled = false stopBringCoins() end
commands["autocollect"] = function() miscState.autoCollectEnabled = true startAutoCollect() end
commands["unautocollect"] = function() miscState.autoCollectEnabled = false stopAutoCollect() end

-- Player
commands["fly"] = function() moveState.flyEnabled = true startFly() end
commands["unfly"] = function() moveState.flyEnabled = false stopFly() end
commands["noclip"] = function() moveState.noclipEnabled = true startNoclip() end
commands["unnoclip"] = function() moveState.noclipEnabled = false stopNoclip() end
commands["speed"] = function(args)
	local v = tonumber(args[1])
	if v then moveState.speedValue = v end
	moveState.speedEnabled = true
	startSpeed()
end
commands["unspeed"] = function() moveState.speedEnabled = false stopSpeed() end
commands["infjump"] = function() moveState.infJumpEnabled = true startInfJump() end
commands["uninfjump"] = function() moveState.infJumpEnabled = false stopInfJump() end
commands["god"] = function() moveState.godEnabled = true startGod() end
commands["ungod"] = function() moveState.godEnabled = false stopGod() end
commands["invisible"] = function() moveState.invisibleEnabled = true startInvisible() end
commands["uninvisible"] = function() moveState.invisibleEnabled = false stopInvisible() end
commands["fov"] = function(args)
	local v = tonumber(args[1])
	if v then
		moveState.cameraFOV = v
		setCameraFOV(v)
		addLog("[FOV] Set to " .. v, COLORS.success)
	else
		addLog("[FOV] Usage: ;fov [50-120]", COLORS.error)
	end
end
commands["bhop"] = function() moveState.bunnyHopEnabled = true startBunnyHop() end
commands["unbhop"] = function() moveState.bunnyHopEnabled = false stopBunnyHop() end
commands["tp"] = function(args)
	local name = args[1]
	if name then
		local target = findPlayer(name)
		if target then tpToPlayer(target) else addLog("[TP] Player not found: " .. name, COLORS.error) end
	else
		addLog("[TP] Usage: ;tp <player>", COLORS.error)
	end
end
commands["spectate"] = function(args)
	local name = args[1]
	if name then
		local target = findPlayer(name)
		if target then spectatePlayer(target) else addLog("[SPECTATE] Player not found: " .. name, COLORS.error) end
	else
		addLog("[SPECTATE] Usage: ;spectate <player>", COLORS.error)
	end
end
commands["unspectate"] = function() unspectate() end
commands["gravity"] = function(args)
	local v = tonumber(args[1])
	if v then
		moveState.gravityValue = v
		setGravity(v)
	else
		addLog("[GRAVITY] Usage: ;gravity <0-1000>", COLORS.error)
	end
end
commands["antivoid"] = function() miscState.antiVoidEnabled = true startAntiVoid() end
commands["unantivoid"] = function() miscState.antiVoidEnabled = false stopAntiVoid() end

-- Fun
commands["fling"] = function() flingState.flingEnabled = true startFling() end
commands["unfling"] = function() flingState.flingEnabled = false stopFling() end
commands["walkfling"] = function() flingState.walkFlingEnabled = true startWalkFling() end
commands["unwalkfling"] = function() flingState.walkFlingEnabled = false stopWalkFling() end
commands["spin"] = function() flingState.spinEnabled = true startSpin() end
commands["unspin"] = function() flingState.spinEnabled = false stopSpin() end
commands["seizure"] = function() flingState.seizureEnabled = true startSeizure() end
commands["unseizure"] = function() flingState.seizureEnabled = false stopSeizure() end
commands["headless"] = function() miscState.headlessEnabled = true startHeadless() end
commands["unheadless"] = function() miscState.headlessEnabled = false stopHeadless() end
commands["rainbow"] = function() miscState.rainbowEnabled = true startRainbow() end
commands["unrainbow"] = function() miscState.rainbowEnabled = false stopRainbow() end
commands["emote1"] = function() playJerkEmote() end
commands["dance"] = function() playEmote(507771019, 1, 10) addLog("[EMOTE] Dance!", COLORS.success) end
commands["dab"] = function() playEmote(183412246, 1, 3) addLog("[EMOTE] Dab!", COLORS.success) end
commands["stopemote"] = function() stopEmote() addLog("[EMOTE] Stopped", COLORS.error) end

-- Utility
commands["rejoin"] = function() rejoinServer() end
commands["serverhop"] = function() serverHop() end

-- Help
commands["cmds"] = function()
	addLog("--- MM2 Hub v1.1 Commands ---", COLORS.accent)
	addLog("-- Combat --", COLORS.accent)
	addLog(";murderesp / ;unmurderesp", COLORS.textSecondary)
	addLog(";alert / ;unalert (murderer proximity)", COLORS.textSecondary)
	addLog(";autoshoot / ;unautoshoot (sheriff only)", COLORS.textSecondary)
	addLog(";grabgun    ;bringgun    ;autograb / ;unautograb", COLORS.textSecondary)
	addLog(";tpbehind <player>", COLORS.textSecondary)
	addLog(";killall / ;unkillall (murderer only)", COLORS.textSecondary)
	addLog("-- ESP --", COLORS.accent)
	addLog(";esp / ;unesp (role-colored ESP)", COLORS.textSecondary)
	addLog(";gunesp / ;ungunesp    ;coinesp / ;uncoinesp", COLORS.textSecondary)
	addLog(";fullbright / ;unfullbright", COLORS.textSecondary)
	addLog(";xray / ;unxray    ;trapdooresp / ;untrapdooresp", COLORS.textSecondary)
	addLog("-- Farming --", COLORS.accent)
	addLog(";coinfarm / ;uncoinfarm    ;antiafk / ;unantiafk", COLORS.textSecondary)
	addLog(";bringcoins / ;unbringcoins    ;autocollect / ;unautocollect", COLORS.textSecondary)
	addLog("-- Player --", COLORS.accent)
	addLog(";fly / ;unfly    ;noclip / ;unnoclip", COLORS.textSecondary)
	addLog(";speed [val] / ;unspeed    ;infjump / ;uninfjump", COLORS.textSecondary)
	addLog(";god / ;ungod    ;invisible / ;uninvisible", COLORS.textSecondary)
	addLog(";fov [val]    ;bhop / ;unbhop", COLORS.textSecondary)
	addLog(";tp <player>    ;spectate <player>    ;unspectate", COLORS.textSecondary)
	addLog(";gravity <val>    ;antivoid / ;unantivoid", COLORS.textSecondary)
	addLog("-- Fun --", COLORS.accent)
	addLog(";fling / ;unfling    ;walkfling / ;unwalkfling", COLORS.textSecondary)
	addLog(";spin / ;unspin    ;seizure / ;unseizure", COLORS.textSecondary)
	addLog(";headless / ;unheadless    ;rainbow / ;unrainbow", COLORS.textSecondary)
	addLog(";emote1  ;dance  ;dab  ;stopemote", COLORS.textSecondary)
	addLog("-- Utility --", COLORS.accent)
	addLog(";rejoin    ;serverhop    ;cmds", COLORS.textSecondary)
end

local function processCommand(input)
	if input:sub(1, 1) == ";" then input = input:sub(2) end
	local parts = {}
	for word in input:gmatch("%S+") do table.insert(parts, word) end
	if #parts == 0 then return end
	local cmd = parts[1]:lower()
	local args = {}
	for i = 2, #parts do table.insert(args, parts[i]) end
	if commands[cmd] then commands[cmd](args)
	else addLog("[CMD] Unknown: " .. cmd .. " (;cmds for help)", COLORS.error) end
end

-- Chat hook: messages starting with ; are treated as commands
pcall(function()
	LocalPlayer.Chatted:Connect(function(msg)
		if msg:sub(1, 1) == ";" then
			processCommand(msg)
		end
	end)
end)

-- ===================== KEYBOARD SHORTCUT =====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
end)

-- ===================== RESPAWN HOOKS =====================
Players.PlayerRemoving:Connect(function(player)
	removePlayerHighlight(player)
	removePlayerNametag(player)
end)

LocalPlayer.CharacterAdded:Connect(function(char)
	-- Wait for character to be fully loaded
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hrp or not hum then return end
	_wait(0.3)

	-- Re-enable fly
	if moveState.flyEnabled then
		stopFly()
		_wait(0.3)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			startFly()
		end
	end

	-- Re-enable fling
	if flingState.flingEnabled then
		stopFling()
		_wait(0.3)
		flingState.flingEnabled = true
		startFling()
	end
	flingState.spinBAV = nil
	flingState.savedPhysProps = {}

	-- Re-enable speed
	if moveState.speedEnabled then
		_wait(0.3)
		startSpeed()
	end

	-- Re-enable noclip
	if moveState.noclipEnabled then
		_wait(0.2)
		startNoclip()
	end

	-- Re-enable infinite jump
	if moveState.infJumpEnabled then
		_wait(0.2)
		startInfJump()
	end

	-- Re-enable jump power
	if moveState.jumpPowerValue ~= 50 then
		_wait(0.3)
		setJumpPower(moveState.jumpPowerValue)
	end

	-- Re-enable god mode
	if moveState.godEnabled then
		_wait(0.3)
		startGod()
	end

	-- Re-enable invisible
	if moveState.invisibleEnabled then
		_wait(0.3)
		startInvisible()
	end

	-- Re-enable fullbright
	if espState.fullbrightEnabled then
		_wait(0.2)
		startFullbright()
	end

	-- Re-enable camera FOV
	if moveState.cameraFOV ~= 70 then
		_wait(0.3)
		setCameraFOV(moveState.cameraFOV)
	end

	-- Re-enable role check
	if roleState.roleCheckEnabled then
		stopRoleCheck()
		_wait(0.3)
		startRoleCheck()
	end

	-- Re-enable murderer alert
	if combatState.murdererAlertEnabled then
		stopMurdererAlert()
		_wait(0.3)
		startMurdererAlert()
	end

	-- Re-enable auto shoot
	if combatState.autoShootMurdererEnabled then
		stopAutoShootMurderer()
		_wait(0.3)
		startAutoShootMurderer()
	end

	-- Re-enable auto grab gun
	if miscState.autoGrabGunEnabled then
		stopAutoGrabGun()
		_wait(0.3)
		startAutoGrabGun()
	end

	-- Re-enable ESP
	if espState.espEnabled then
		disablePlayerEsp()
		_wait(0.5)
		enablePlayerEsp()
	end

	-- Re-enable gun ESP
	if espState.gunEspEnabled then
		disableGunEsp()
		_wait(0.3)
		enableGunEsp()
	end

	-- Re-enable coin ESP
	if espState.coinEspEnabled then
		disableCoinEsp()
		_wait(0.3)
		enableCoinEsp()
	end

	-- Re-enable murderer ESP
	if combatState.murdererEspEnabled then
		_wait(0.3)
		updateMurdererEsp()
	end

	-- Re-enable kill all
	if miscState.killAllEnabled then
		stopKillAll()
		_wait(0.3)
		startKillAll()
	end

	-- Re-enable bunny hop
	if moveState.bunnyHopEnabled then
		stopBunnyHop()
		_wait(0.2)
		startBunnyHop()
	end

	-- Re-enable anti-void
	if miscState.antiVoidEnabled then
		stopAntiVoid()
		_wait(0.2)
		startAntiVoid()
	end

	-- Re-enable walk fling
	if flingState.walkFlingEnabled then
		stopWalkFling()
		_wait(0.3)
		flingState.walkFlingEnabled = true
		startWalkFling()
	end

	-- Re-enable headless
	if miscState.headlessEnabled then
		_wait(0.5)
		startHeadless()
	end

	-- Re-enable rainbow
	if miscState.rainbowEnabled then
		stopRainbow()
		_wait(0.2)
		startRainbow()
	end

	-- Re-enable bring coins
	if miscState.bringCoinsEnabled then
		stopBringCoins()
		_wait(0.3)
		startBringCoins()
	end

	-- Re-enable trapdoor ESP
	if miscState.trapdoorEspEnabled then
		_wait(0.3)
		startTrapdoorEsp()
	end

	-- Re-enable gravity
	if moveState.gravityValue ~= 196 then
		_wait(0.2)
		setGravity(moveState.gravityValue)
	end

	-- Bundle 4 (QoL) respawn hook: re-hook auto-rejoin / re-assert freecam
	if qolState.onRespawn then
		pcall(function() qolState.onRespawn(char) end)
	end

	-- Bundle 5 (Extras) respawn hook: re-apply hip height (loops self-survive)
	if extrasState.onRespawn then
		_wait(0.3)
		pcall(function() extrasState.onRespawn(char) end)
	end
end)

-- ===================== STARTUP =====================
-- Start role check automatically so role label updates
startRoleCheck()

addLog("MM2 Hub v1.1", COLORS.accent)
addLog("Type ;cmds for command list", COLORS.textSecondary)
addLog("Use Right Shift to toggle GUI", COLORS.textSecondary)
addLog("Role detection active - scanning every 0.5s", COLORS.textSecondary)
print("[MM2 Hub] v1.1 loaded")
