-- Key System Gate
-- Key gate, resilient to a single host failing. raw.githubusercontent
-- often rate-limits or fails to fetch on executors, which silently
-- returned here and made the whole hub look dead; jsDelivr mirrors the
-- same repo through a CDN and is the fallback.
local SXKeySources = {
	"https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick()),
	"https://cdn.jsdelivr.net/gh/pebbleford/roblox-scripts@main/keysystem.lua",
}
local keySystem
for _, SXKeyURL in ipairs(SXKeySources) do
	local ok, res = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
	if ok and res then keySystem = res break end
end
if not keySystem or not keySystem.validate("rivals") then return end

-- ================================================================
-- Pebbleford Hub - RIVALS Hub
-- Dedicated admin for RIVALS FPS
-- v1.6
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local _spawn = (task and task.spawn) or spawn
local _wait = (task and task.wait) or wait

-- ===================== COLOR PALETTE (Purple/Violet Theme) =====================
local COLORS = {
	bg = Color3.fromRGB(18, 16, 24),
	bgSecondary = Color3.fromRGB(28, 24, 38),
	tabBg = Color3.fromRGB(42, 36, 56),
	accent = Color3.fromRGB(160, 60, 255),
	accentHover = Color3.fromRGB(180, 90, 255),
	accentDark = Color3.fromRGB(110, 40, 180),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(176, 176, 176),
	textDim = Color3.fromRGB(120, 120, 120),
	border = Color3.fromRGB(50, 40, 65),
	toggleOn = Color3.fromRGB(160, 60, 255),
	toggleOff = Color3.fromRGB(85, 85, 85),
	error = Color3.fromRGB(255, 68, 68),
	success = Color3.fromRGB(68, 255, 68),
	btnExecute = Color3.fromRGB(160, 60, 255),
	btnClear = Color3.fromRGB(60, 60, 60),
}

-- ===================== STATE (bundled to stay under Lua 200 local limit) =====================
local S = {
	aimbotEnabled = false, silentAimEnabled = false, triggerBotEnabled = false,
	aimbotKey = Enum.UserInputType.MouseButton2,
	aimbotFOV = 200, aimbotSmoothing = 2, aimbotAimPart = "Head",
	aimbotMaxDist = 300, aimbotWallCheck = true, teamCheck = true,
	espEnabled = false, espBoxEnabled = false, espTracerEnabled = false,
	espHealthBar = true, espNameEnabled = true, espDistEnabled = true, fovCircleEnabled = false,
	noRecoilEnabled = false, noSpreadEnabled = false, rapidFireEnabled = false,
	flyEnabled = false, noclipEnabled = false, speedEnabled = false, infJumpEnabled = false,
	fovChangerEnabled = false, fullbrightEnabled = false, hitboxExpandEnabled = false,
	flingEnabled = false, walkFlingEnabled = false, spinEnabled = false,
	seizureEnabled = false, headlessEnabled = false, emoteActive = false,
	autoFireEnabled = false, killAuraEnabled = false,
	noFogEnabled = false, chamsEnabled = false,
	godEnabled = false, invisibleEnabled = false, antiAfkEnabled = false,
	bunnyHopEnabled = false, spectating = false, selectedPlayer = nil,
	flySpeed = 80, speedValue = 100, flingPower = 99999, walkFlingPower = 10000,
	jumpPowerValue = 50, cameraFOV = 90, hitboxSize = 10, killAuraRange = 15, gravityValue = 196.2,
}

-- Connections & storage (bundled to stay under Lua 200 local limit)
local C = {
	aimbotConnection = nil,
	silentAimHook = nil,
	triggerBotConnection = nil,
	espObjects = {},
	espUpdateConnection = nil,
	espPlayerAddedConnection = nil,
	espCharConnections = {},
	fovCircle = nil,
	noRecoilConnection = nil,
	noSpreadConnection = nil,
	rapidFireConnection = nil,
	flyConnection = nil,
	bodyGyro = nil,
	bodyVelocity = nil,
	noclipConnection = nil,
	infJumpConnection = nil,
	spinConnection = nil,
	spinBAV = nil,
	savedPhysProps = {},
	flingConnection = nil,
	flingConnection2 = nil,
	hitboxConnection = nil,
	emoteTracks = {},
	emoteConnection = nil,
	autoFireConnection = nil,
	killAuraConnection = nil,
	noFogOrigFogStart = nil,
	noFogOrigFogEnd = nil,
	chamsObjects = {},
	chamsCharConnections = {},
	chamsPlayerAddedConnection = nil,
	godConnection = nil,
	savedTransparencies = {},
	antiAfkConnection = nil,
	bunnyHopConnection = nil,
	walkFlingThread = nil,
	walkFlingProps = {},
	walkFlingConnection = nil,
	seizureConnection = nil,
	headlessSavedParts = {},
}
local windowVisible = true
local activeTab = "Main"
local logLines = {}
local MAX_LOG_LINES = 50
local aimbotHolding = false

local origWalkSpeed = 16
local origJumpPower = 50

-- Fullbright saved values
local origAmbient = nil
local origBrightness = nil
local origFogEnd = nil
local origGlobalShadows = nil

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
	local old = game:GetService("CoreGui"):FindFirstChild("SXRivals")
	if old then old:Destroy() end
end)
pcall(function()
	local old = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("SXRivals")
	if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SXRivals"
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

-- ===================== GUI SETUP (Terminal, hand-built) =====================
-- Terminal green-on-black hand-built UI. Feature call sites are untouched: the
-- builder functions keep their signatures and now produce terminal-styled
-- frames instead of Fluent elements. Light (no library), so no menu lag.
do
	local T = {
		bg = Color3.fromRGB(0,0,0), bgSecondary = Color3.fromRGB(5,12,6), tabBg = Color3.fromRGB(5,12,6),
		accent = Color3.fromRGB(0,255,65), accentHover = Color3.fromRGB(93,255,143), accentDark = Color3.fromRGB(15,61,28),
		textPrimary = Color3.fromRGB(191,255,205), textSecondary = Color3.fromRGB(63,191,95), textDim = Color3.fromRGB(31,122,52),
		border = Color3.fromRGB(15,61,28), toggleOn = Color3.fromRGB(20,81,42), toggleOff = Color3.fromRGB(11,42,18),
		error = Color3.fromRGB(255,85,85), success = Color3.fromRGB(0,255,65),
	}
	for k,v in pairs(T) do COLORS[k] = v end
end

local _uiOrd = 0
local function _nextOrd() _uiOrd = _uiOrd + 1 return _uiOrd end

local tabNames = {"Main", "Combat", "ESP", "GunMods", "Player", "Fun"}
local tabFrames = {}
uiState = uiState or {activeTab = tabNames[1]}

local _TUIS = UserInputService
local _mobile = _TUIS.TouchEnabled and not _TUIS.KeyboardEnabled
local _W = _mobile and 440 or 560
local _H = _mobile and 380 or 440

local mainWindow = Instance.new("Frame")
mainWindow.Name = "MainWindow"
mainWindow.Size = UDim2.new(0, _W, 0, _H)
mainWindow.Position = UDim2.new(0.5, -_W/2, 0.5, -_H/2)
mainWindow.BackgroundColor3 = COLORS.bg
mainWindow.BorderSizePixel = 0
mainWindow.Active = true
mainWindow.Parent = screenGui
do local st = Instance.new("UIStroke") st.Color = COLORS.border st.Thickness = 1 st.Parent = mainWindow end

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = COLORS.bgSecondary
titleBar.BorderSizePixel = 0
titleBar.Parent = mainWindow

local titleAccent = Instance.new("Frame")
titleAccent.Size = UDim2.new(1, 0, 0, 2)
titleAccent.Position = UDim2.new(0, 0, 1, 0)
titleAccent.BackgroundColor3 = COLORS.accent
titleAccent.BorderSizePixel = 0
titleAccent.ZIndex = 3
titleAccent.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -160, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "RIVALS HUB"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.Font = Enum.Font.Code
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local keyBadge = Instance.new("TextLabel")
keyBadge.Size = UDim2.new(0, 60, 0, 22)
keyBadge.Position = UDim2.new(1, -132, 0.5, -11)
keyBadge.BackgroundTransparency = 1
keyBadge.Text = "KEY OK"
keyBadge.TextColor3 = COLORS.textDim
keyBadge.Font = Enum.Font.Code
keyBadge.TextSize = 11
keyBadge.Parent = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -64, 0.5, -14)
minimizeBtn.BackgroundColor3 = COLORS.accentDark
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = COLORS.textPrimary
minimizeBtn.Font = Enum.Font.Code
minimizeBtn.TextSize = 16
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0.5, -14)
closeBtn.BackgroundColor3 = COLORS.accent
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(0,0,0)
closeBtn.Font = Enum.Font.Code
closeBtn.TextSize = 13
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar

-- Drag (mouse + touch)
do
	local dragging, ds, sp = false, nil, nil
	titleBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true ds = i.Position sp = mainWindow.Position
		end
	end)
	_TUIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - ds
			mainWindow.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end
	end)
	_TUIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 34)
tabBar.Position = UDim2.new(0, 0, 0, 42)
tabBar.BackgroundColor3 = COLORS.bgSecondary
tabBar.BorderSizePixel = 0
tabBar.Parent = mainWindow
do local dv = Instance.new("Frame") dv.Size = UDim2.new(1,0,0,1) dv.Position = UDim2.new(0,0,1,-1) dv.BackgroundColor3 = COLORS.border dv.BorderSizePixel = 0 dv.ZIndex = 2 dv.Parent = tabBar end

local tabButtons = {}
local _tabN = #tabNames
for i, tabName in ipairs(tabNames) do
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -8, 1, -84)
	content.Position = UDim2.new(0, 4, 0, 80)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = COLORS.accent
	content.CanvasSize = UDim2.new(0,0,0,0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Visible = (i == 1)
	content.Parent = mainWindow
	local lay = Instance.new("UIListLayout") lay.SortOrder = Enum.SortOrder.LayoutOrder lay.Padding = UDim.new(0,4) lay.Parent = content
	local pd = Instance.new("UIPadding") pd.PaddingLeft = UDim.new(0,4) pd.PaddingRight = UDim.new(0,4) pd.PaddingTop = UDim.new(0,4) pd.Parent = content
	tabFrames[tabName] = content

	local b = Instance.new("TextButton")
	b.Position = UDim2.new((i-1)/_tabN, 0, 0, 0)
	b.Size = UDim2.new(1/_tabN, 0, 1, -1)
	b.BackgroundColor3 = COLORS.accentDark
	b.BackgroundTransparency = (i == 1) and 0 or 1
	b.Text = string.upper(tabName)
	b.TextColor3 = (i == 1) and COLORS.accent or COLORS.textSecondary
	b.Font = Enum.Font.Code
	b.TextSize = 10
	b.AutoButtonColor = false
	b.ZIndex = 3
	b.Parent = tabBar
	tabButtons[tabName] = b
end

local function switchTab(name)
	uiState.activeTab = name
	for n, f in pairs(tabFrames) do f.Visible = (n == name) end
	for n, b in pairs(tabButtons) do
		if n == name then b.BackgroundTransparency = 0 b.TextColor3 = COLORS.accent
		else b.BackgroundTransparency = 1 b.TextColor3 = COLORS.textSecondary end
	end
end
for name, b in pairs(tabButtons) do b.MouseButton1Click:Connect(function() switchTab(name) end) end

-- Minimise / close + mobile reopen button
local reopenBtn = Instance.new("TextButton")
reopenBtn.Size = UDim2.new(0, 46, 0, 46)
reopenBtn.Position = UDim2.new(0, 12, 0.5, -23)
reopenBtn.BackgroundColor3 = COLORS.accent
reopenBtn.Text = "PB"
reopenBtn.TextColor3 = Color3.fromRGB(0,0,0)
reopenBtn.Font = Enum.Font.Code
reopenBtn.TextSize = 14
reopenBtn.BorderSizePixel = 0
reopenBtn.Visible = false
reopenBtn.Parent = screenGui
local function _hide() mainWindow.Visible = false reopenBtn.Visible = true end
minimizeBtn.MouseButton1Click:Connect(_hide)
closeBtn.MouseButton1Click:Connect(_hide)
reopenBtn.MouseButton1Click:Connect(function() mainWindow.Visible = true reopenBtn.Visible = false end)
_TUIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.RightShift then
		mainWindow.Visible = not mainWindow.Visible
		reopenBtn.Visible = not mainWindow.Visible
	end
end)

-- ===================== UI COMPONENT BUILDERS (Terminal) =====================
local function createSectionLabel(parent, text, order)
	if not parent then return end
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 22)
	l.BackgroundTransparency = 1
	l.Text = string.upper(tostring(text))
	l.TextColor3 = COLORS.accentHover
	l.Font = Enum.Font.Code
	l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.LayoutOrder = _nextOrd()
	l.Parent = parent
	return l
end

local function createInfoLabel(parent, text, order)
	if not parent then return end
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 18)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.Text = tostring(text)
	l.TextColor3 = COLORS.textDim
	l.Font = Enum.Font.Code
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.LayoutOrder = _nextOrd()
	l.Parent = parent
	return l
end

local function createDynamicLabel(parent, text)
	if not parent then return setmetatable({}, {__newindex = function() end}) end
	local l = createInfoLabel(parent, text or "", 0)
	l.TextColor3 = COLORS.textSecondary
	return setmetatable({}, {
		__newindex = function(_, k, v)
			if k == "Text" then pcall(function() l.Text = tostring(v) end)
			elseif k == "TextColor3" then pcall(function() l.TextColor3 = v end) end
		end,
		__index = function() return nil end,
	})
end

local function createToggle(parent, text, order, callback)
	if not parent then return end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = COLORS.tabBg
	row.BorderSizePixel = 0
	row.LayoutOrder = _nextOrd()
	row.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = row end
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -66, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = tostring(text)
	lbl.TextColor3 = COLORS.textPrimary
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.new(0, 50, 0, 22)
	pill.Position = UDim2.new(1, -56, 0.5, -11)
	pill.BackgroundColor3 = COLORS.toggleOff
	pill.BorderSizePixel = 0
	pill.Text = "OFF"
	pill.TextColor3 = COLORS.accent
	pill.Font = Enum.Font.Code
	pill.TextSize = 12
	pill.Parent = row
	local isOn = false
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = row
	local function set(on)
		isOn = on
		pill.Text = on and "ON" or "OFF"
		pill.BackgroundColor3 = on and COLORS.toggleOn or COLORS.toggleOff
	end
	btn.MouseButton1Click:Connect(function() set(not isOn) if callback then pcall(callback, isOn) end end)
	return {setVisualState = set, isOn = function() return isOn end}
end

local function createActionButton(parent, text, order, callback)
	if not parent then return end
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 32)
	b.BackgroundColor3 = COLORS.tabBg
	b.Text = string.upper(tostring(text))
	b.TextColor3 = COLORS.accent
	b.Font = Enum.Font.Code
	b.TextSize = 12
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.LayoutOrder = _nextOrd()
	b.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = b end
	b.MouseEnter:Connect(function() b.BackgroundColor3 = COLORS.accentDark end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = COLORS.tabBg end)
	b.MouseButton1Click:Connect(function() if callback then pcall(callback) end end)
	return b
end
local createButton = createActionButton

local function createSlider(parent, text, min, max, default, order, callback)
	if not parent then return end
	local c = Instance.new("Frame")
	c.Size = UDim2.new(1, 0, 0, 46)
	c.BackgroundColor3 = COLORS.tabBg
	c.BorderSizePixel = 0
	c.LayoutOrder = _nextOrd()
	c.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = c end
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -80, 0, 20)
	lbl.Position = UDim2.new(0, 10, 0, 3)
	lbl.BackgroundTransparency = 1
	lbl.Text = tostring(text)
	lbl.TextColor3 = COLORS.textSecondary
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = c
	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(0, 70, 0, 20)
	val.Position = UDim2.new(1, -75, 0, 3)
	val.BackgroundTransparency = 1
	val.Text = tostring(default)
	val.TextColor3 = COLORS.accentHover
	val.Font = Enum.Font.Code
	val.TextSize = 12
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.Parent = c
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, -20, 0, 6)
	bg.Position = UDim2.new(0, 10, 0, 30)
	bg.BackgroundColor3 = COLORS.bgSecondary
	bg.BorderSizePixel = 0
	bg.Parent = c
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
	fill.BackgroundColor3 = COLORS.accent
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local drag = false
	local function upd(x)
		local p = math.clamp((x - bg.AbsolutePosition.X)/bg.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.new(p, 0, 1, 0)
		local v = math.floor(min + p*(max-min))
		val.Text = tostring(v)
		if callback then pcall(callback, v) end
	end
	bg.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true upd(i.Position.X) end end)
	bg.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end end)
	_TUIS.InputChanged:Connect(function(i) if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i.Position.X) end end)
	return c
end

local function createDropdown(parent, text, options, default, callback)
	if not parent then return end
	local wrap = {}
	local cur = default
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 32)
	b.BackgroundColor3 = COLORS.tabBg
	b.Text = tostring(text) .. ": " .. tostring(default)
	b.TextColor3 = COLORS.accent
	b.Font = Enum.Font.Code
	b.TextSize = 12
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.LayoutOrder = _nextOrd()
	b.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = b end
	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundColor3 = COLORS.bgSecondary
	list.BorderSizePixel = 0
	list.Visible = false
	list.LayoutOrder = _nextOrd()
	list.Parent = parent
	local ll = Instance.new("UIListLayout") ll.Parent = list
	local function rebuild(opts)
		for _, ch in ipairs(list:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
		for _, opt in ipairs(opts) do
			local o = Instance.new("TextButton")
			o.Size = UDim2.new(1, 0, 0, 26)
			o.BackgroundColor3 = COLORS.bgSecondary
			o.Text = tostring(opt)
			o.TextColor3 = COLORS.textSecondary
			o.Font = Enum.Font.Code
			o.TextSize = 11
			o.BorderSizePixel = 0
			o.Parent = list
			o.MouseButton1Click:Connect(function()
				cur = opt
				b.Text = tostring(text) .. ": " .. tostring(opt)
				list.Visible = false
				if callback then pcall(callback, opt) end
			end)
		end
	end
	rebuild(options or {})
	b.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
	function wrap:Refresh(opts) rebuild(opts) end
	function wrap:SetValues(opts) rebuild(opts) end
	return wrap
end

local function createInput(parent, text, placeholder, callback)
	if not parent then return end
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 32)
	box.BackgroundColor3 = COLORS.tabBg
	box.Text = ""
	box.PlaceholderText = placeholder or tostring(text)
	box.PlaceholderColor3 = COLORS.textDim
	box.TextColor3 = COLORS.textPrimary
	box.Font = Enum.Font.Code
	box.TextSize = 12
	box.ClearTextOnFocus = false
	box.BorderSizePixel = 0
	box.LayoutOrder = _nextOrd()
	box.Parent = parent
	do local st = Instance.new("UIStroke") st.Color = COLORS.accentDark st.Thickness = 1 st.Parent = box end
	local pd = Instance.new("UIPadding") pd.PaddingLeft = UDim.new(0,8) pd.Parent = box
	box.FocusLost:Connect(function() if callback then pcall(callback, box.Text) end end)
	return box
end

local function createSpacer(parent, order)
	if not parent then return end
	local s = Instance.new("Frame")
	s.Size = UDim2.new(1, 0, 0, 4)
	s.BackgroundTransparency = 1
	s.LayoutOrder = _nextOrd()
	s.Parent = parent
end


-- ===================== LOG SYSTEM =====================
local logFrame

local function addLog(msg, color)
	print("[SX] " .. tostring(msg))
	table.insert(logLines, {text = msg, color = color or COLORS.textSecondary})
	if #logLines > MAX_LOG_LINES then
		table.remove(logLines, 1)
	end
	if logFrame then
		for _, child in ipairs(logFrame:GetChildren()) do
			if child:IsA("TextLabel") then child:Destroy() end
		end
		for i, line in ipairs(logLines) do
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
		logFrame.CanvasSize = UDim2.new(0, 0, 0, #logLines * 16)
		logFrame.CanvasPosition = Vector2.new(0, math.max(0, #logLines * 16 - logFrame.AbsoluteSize.Y))
	end
end

-- ===================== AIMBOT: GET CLOSEST PLAYER IN FOV =====================
local function isPlayerInMatch(player)
	-- Filter out lobby/spectating players
	local character = player.Character
	if not character then return false end
	if not character.Parent then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	-- Skip players with ForceField (spawn protection / lobby)
	if character:FindFirstChildOfClass("ForceField") then return false end

	-- Skip if character is parented to something other than workspace (lobby area)
	if character.Parent ~= workspace then return false end

	-- Distance check from our character
	local myChar = LocalPlayer.Character
	if not myChar then return false end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	local theirRoot = character:FindFirstChild("HumanoidRootPart")
	if not myRoot or not theirRoot then return false end

	local dist = (myRoot.Position - theirRoot.Position).Magnitude
	if dist > S.aimbotMaxDist then return false end

	return true
end

local function isTargetVisible(targetPart)
	if not S.aimbotWallCheck then return true end
	local cam = workspace.CurrentCamera
	local origin = cam.CFrame.Position
	local direction = (targetPart.Position - origin)

	-- Raycast from camera to target, ignoring our own character
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local myChar = LocalPlayer.Character
	local ignoreList = {}
	if myChar then table.insert(ignoreList, myChar) end
	rayParams.FilterDescendantsInstances = ignoreList

	local result = workspace:Raycast(origin, direction, rayParams)
	if not result then return true end -- nothing hit = clear line of sight

	-- Check if what we hit belongs to the target's character
	local hitPart = result.Instance
	local targetChar = targetPart.Parent
	if hitPart and hitPart:IsDescendantOf(targetChar) then return true end

	return false
end

-- Team mode detection: only filter teammates if there are 2+ teams with players
local function isActualTeamMode()
	local ok, result = pcall(function()
		local teamsWithPlayers = 0
		for _, team in ipairs(Teams:GetTeams()) do
			if #team:GetPlayers() > 0 then
				teamsWithPlayers = teamsWithPlayers + 1
			end
		end
		return teamsWithPlayers >= 2
	end)
	return ok and result
end

local function shouldSkipTeammate(player)
	if not S.teamCheck then return false end
	local myTeam = LocalPlayer.Team
	local theirTeam = player.Team
	if not myTeam or not theirTeam then return false end
	if myTeam == theirTeam then
		return isActualTeamMode()
	end
	return false
end

local function getClosestPlayerInFOV()
	local cam = workspace.CurrentCamera
	local closest = nil
	local closestDist = S.aimbotFOV
	local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local skipTeam = shouldSkipTeammate(player)

			if not skipTeam and isPlayerInMatch(player) then
				local character = player.Character
				local targetPart = character:FindFirstChild(S.aimbotAimPart) or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
				if targetPart then
					local screenPos, onScreen = cam:WorldToViewportPoint(targetPart.Position)
					if onScreen then
						local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
						if screenDist < closestDist then
							-- Wall check — only target visible players
							if isTargetVisible(targetPart) then
								closest = targetPart
								closestDist = screenDist
							end
						end
					end
				end
			end
		end
	end
	return closest
end

-- ===================== AIMBOT =====================
local aimbotInputBeganConn = nil
local aimbotInputEndedConn = nil

local function startAimbot()
	-- Track when aimbot key is held (ignore gpe so it works even when game processes the input)
	aimbotInputBeganConn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == S.aimbotKey or input.KeyCode == Enum.KeyCode.Q then
			aimbotHolding = true
		end
	end)
	aimbotInputEndedConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == S.aimbotKey or input.KeyCode == Enum.KeyCode.Q then
			aimbotHolding = false
		end
	end)

	-- Use RenderStepped:Connect which fires AFTER all BindToRenderStep callbacks.
	-- This ensures our CFrame overwrite runs after RIVALS' camera controller
	-- regardless of what priority the game uses. Works hipfire and scoped.
	C.aimbotConnection = RunService.RenderStepped:Connect(function()
		if not S.aimbotEnabled or not aimbotHolding then return end
		pcall(function()
			local cam = workspace.CurrentCamera
			local target = getClosestPlayerInFOV()
			if not target then return end

			local targetPos = target.Position
			local camPos = cam.CFrame.Position
			local targetCF = CFrame.new(camPos, targetPos)

			-- Smooth aim: lerp from current camera to target look direction
			-- Lower smoothing value = snappier aim
			local alpha = math.clamp(1 / S.aimbotSmoothing, 0.05, 1)
			cam.CFrame = cam.CFrame:Lerp(targetCF, alpha)
		end)
	end)
	addLog("[AIMBOT] ON (Hold RMB or Q)", COLORS.success)
end

local function stopAimbot()
	if C.aimbotConnection then C.aimbotConnection:Disconnect() C.aimbotConnection = nil end
	if aimbotInputBeganConn then aimbotInputBeganConn:Disconnect() aimbotInputBeganConn = nil end
	if aimbotInputEndedConn then aimbotInputEndedConn:Disconnect() aimbotInputEndedConn = nil end
	aimbotHolding = false
	addLog("[AIMBOT] OFF", COLORS.error)
end

-- ===================== SILENT AIM =====================
local function startSilentAim()
	-- Hook workspace:Raycast via hookmetamethod to redirect bullets to target
	-- RIVALS fires raycasts from scripts named "Equipment" and "FighterController"
	-- We intercept those and redirect the ray direction toward the closest enemy
	if not C.silentAimHook and hookmetamethod then
		pcall(function()
			local oldNamecall
			oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
				local method = getnamecallmethod()
				if S.silentAimEnabled and self == workspace and not checkcaller() then
					if method == "Raycast" then
						-- Only redirect RIVALS weapon raycasts, not camera/UI raycasts
						local callingScript = getcallingscript()
						if callingScript and (callingScript.Name == "Equipment" or callingScript.Name == "FighterController" or callingScript.Name == "PlayerDataController" or callingScript.Name == "ControlsController") then
							local target = getClosestPlayerInFOV()
							if target then
								local args = {... }
								local origin = args[1]
								if typeof(origin) == "Vector3" then
									local direction = (target.Position - origin).Unit * 1000
									return oldNamecall(self, origin, direction, select(3, ...))
								end
							end
						end
					end
				end
				return oldNamecall(self, ...)
			end))
			C.silentAimHook = true
		end)
	end

	-- Fallback: try getrawmetatable if hookmetamethod not available
	if not C.silentAimHook then
		pcall(function()
			local mt = getrawmetatable(game)
			if mt and setreadonly then
				local oldNamecall = mt.__namecall
				setreadonly(mt, false)
				mt.__namecall = newcclosure(function(self, ...)
					local method = getnamecallmethod()
					if S.silentAimEnabled and self == workspace and method == "Raycast" then
						local target = getClosestPlayerInFOV()
						if target then
							local args = {... }
							if typeof(args[1]) == "Vector3" then
								local origin = args[1]
								local direction = (target.Position - origin).Unit * 1000
								return oldNamecall(self, origin, direction, select(3, ...))
							end
						end
					end
					return oldNamecall(self, ...)
				end)
				setreadonly(mt, true)
				C.silentAimHook = true
			end
		end)
	end

	if not C.silentAimHook then
		addLog("[SILENT AIM] No hook support on this executor", COLORS.error)
	end
	addLog("[SILENT AIM] ON - bullets redirect to target", COLORS.success)
end

local function stopSilentAim()
	S.silentAimEnabled = false
	-- Hook stays installed but checks the flag, so disabling is instant
	addLog("[SILENT AIM] OFF", COLORS.error)
end

-- ===================== TRIGGERBOT =====================
local function startTriggerBot()
	C.triggerBotConnection = RunService.Heartbeat:Connect(function()
		if not S.triggerBotEnabled then return end
		pcall(function()
			local mouse = LocalPlayer:GetMouse()
			if mouse.Target then
				local targetModel = mouse.Target:FindFirstAncestorOfClass("Model")
				if targetModel then
					local player = Players:GetPlayerFromCharacter(targetModel)
					if player and player ~= LocalPlayer then
						if not shouldSkipTeammate(player) then
							-- Check if alive
							local hum = targetModel:FindFirstChildOfClass("Humanoid")
							if hum and hum.Health > 0 then
								-- Fire mouse click
								pcall(function() mouse1click() end)
							end
						end
					end
				end
			end
		end)
	end)
	addLog("[TRIGGERBOT] ON", COLORS.success)
end

local function stopTriggerBot()
	if C.triggerBotConnection then C.triggerBotConnection:Disconnect() C.triggerBotConnection = nil end
	addLog("[TRIGGERBOT] OFF", COLORS.error)
end

-- ===================== ESP SYSTEM =====================
local function enableESP()
	local function addPlayerESP(player)
		if player == LocalPlayer then return end

		local function updateESP()
			-- Remove old
			if C.espObjects[player] then
				for _, obj in pairs(C.espObjects[player]) do
					pcall(function()
						if typeof(obj) == "RBXScriptConnection" then
							obj:Disconnect()
						else
							obj:Destroy()
						end
					end)
				end
			end
			C.espObjects[player] = {}

			local character = player.Character
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then return end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then return end

			-- Determine color based on team
			local isEnemy = not shouldSkipTeammate(player)
			local espColor = isEnemy and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)

			-- Highlight (chams)
			local hl = Instance.new("Highlight")
			hl.FillColor = espColor
			hl.OutlineColor = espColor
			hl.FillTransparency = 0.7
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = character
			hl.Parent = character
			table.insert(C.espObjects[player], hl)

			-- BillboardGui for name + health + distance
			local head = character:FindFirstChild("Head")
			local adornPart = head or root
			local bb = Instance.new("BillboardGui")
			bb.Adornee = adornPart
			bb.Size = UDim2.new(0, 200, 0, 60)
			bb.StudsOffset = Vector3.new(0, 3.5, 0)
			bb.AlwaysOnTop = true
			bb.Parent = adornPart
			table.insert(C.espObjects[player], bb)

			-- Name label
			if S.espNameEnabled then
				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(1, 0, 0, 16)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = player.DisplayName
				nameLabel.TextColor3 = espColor
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.TextSize = 13
				nameLabel.TextStrokeTransparency = 0.3
				nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
				nameLabel.Parent = bb
			end

			-- Health bar
			if S.espHealthBar then
				local healthBg = Instance.new("Frame")
				healthBg.Size = UDim2.new(0.7, 0, 0, 5)
				healthBg.Position = UDim2.new(0.15, 0, 0, 18)
				healthBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				healthBg.BorderSizePixel = 0
				healthBg.Parent = bb
				Instance.new("UICorner", healthBg).CornerRadius = UDim.new(0, 3)
				table.insert(C.espObjects[player], healthBg)

				local healthFill = Instance.new("Frame")
				local pct = humanoid.Health / humanoid.MaxHealth
				healthFill.Size = UDim2.new(pct, 0, 1, 0)
				local r = math.floor(255 * (1 - pct))
				local g = math.floor(255 * pct)
				healthFill.BackgroundColor3 = Color3.fromRGB(r, g, 0)
				healthFill.BorderSizePixel = 0
				healthFill.Parent = healthBg
				Instance.new("UICorner", healthFill).CornerRadius = UDim.new(0, 3)

				-- Update health bar dynamically
				local healthConn = humanoid.HealthChanged:Connect(function(hp)
					pcall(function()
						local p2 = hp / humanoid.MaxHealth
						if p2 < 0 then p2 = 0 end
						if p2 > 1 then p2 = 1 end
						healthFill.Size = UDim2.new(p2, 0, 1, 0)
						local r2 = math.floor(255 * (1 - p2))
						local g2 = math.floor(255 * p2)
						healthFill.BackgroundColor3 = Color3.fromRGB(r2, g2, 0)
					end)
				end)
				table.insert(C.espObjects[player], healthConn)
			end

			-- Distance label
			if S.espDistEnabled then
				local distLabel = Instance.new("TextLabel")
				distLabel.Size = UDim2.new(1, 0, 0, 14)
				distLabel.Position = UDim2.new(0, 0, 0, 25)
				distLabel.BackgroundTransparency = 1
				distLabel.Text = "0m"
				distLabel.TextColor3 = COLORS.textSecondary
				distLabel.Font = Enum.Font.Gotham
				distLabel.TextSize = 11
				distLabel.TextStrokeTransparency = 0.4
				distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
				distLabel.Parent = bb

				-- Update distance dynamically
				local distConn = RunService.Heartbeat:Connect(function()
					pcall(function()
						if not bb or not bb.Parent then return end
						local myChar = LocalPlayer.Character
						local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
						local theirRoot = character and character:FindFirstChild("HumanoidRootPart")
						if myRoot and theirRoot then
							distLabel.Text = math.floor((myRoot.Position - theirRoot.Position).Magnitude) .. "m"
						end
					end)
				end)
				table.insert(C.espObjects[player], distConn)
			end
		end

		updateESP()
		-- Update on character changes
		local conn = player.CharacterAdded:Connect(function()
			_wait(1)
			if S.espEnabled then updateESP() end
		end)
		table.insert(C.espCharConnections, conn)
	end

	-- Initial ESP for all players
	for _, player in ipairs(Players:GetPlayers()) do
		addPlayerESP(player)
	end

	-- Watch for new players
	C.espPlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
		_wait(2)
		if S.espEnabled then addPlayerESP(player) end
	end)

	addLog("[ESP] ON", COLORS.success)
end

local function disableESP()
	if C.espPlayerAddedConnection then C.espPlayerAddedConnection:Disconnect() C.espPlayerAddedConnection = nil end
	for _, conn in ipairs(C.espCharConnections) do
		pcall(function() conn:Disconnect() end)
	end
	C.espCharConnections = {}
	for player, objects in pairs(C.espObjects) do
		for _, obj in pairs(objects) do
			pcall(function()
				if typeof(obj) == "RBXScriptConnection" then
					obj:Disconnect()
				else
					obj:Destroy()
				end
			end)
		end
	end
	C.espObjects = {}
	addLog("[ESP] OFF", COLORS.error)
end

-- ===================== FOV CIRCLE =====================
local function createFOVCircle()
	-- Use a Frame with UICorner to simulate circle (works everywhere)
	if C.fovCircle then pcall(function() C.fovCircle:Destroy() end) end

	local gui = Instance.new("Frame")
	gui.Name = "FOVCircle"
	gui.Size = UDim2.new(0, S.aimbotFOV * 2, 0, S.aimbotFOV * 2)
	gui.Position = UDim2.new(0.5, -S.aimbotFOV, 0.5, -S.aimbotFOV)
	gui.BackgroundTransparency = 0.95
	gui.BackgroundColor3 = COLORS.accent
	gui.BorderSizePixel = 0
	gui.Parent = screenGui

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.accent
	stroke.Thickness = 1
	stroke.Transparency = 0.3
	stroke.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = gui

	C.fovCircle = gui
	addLog("[FOV CIRCLE] ON - Radius: " .. S.aimbotFOV, COLORS.success)
end

local function destroyFOVCircle()
	if C.fovCircle then pcall(function() C.fovCircle:Destroy() end) C.fovCircle = nil end
	addLog("[FOV CIRCLE] OFF", COLORS.error)
end

local function updateFOVCircleSize()
	if C.fovCircle then
		C.fovCircle.Size = UDim2.new(0, S.aimbotFOV * 2, 0, S.aimbotFOV * 2)
		C.fovCircle.Position = UDim2.new(0.5, -S.aimbotFOV, 0.5, -S.aimbotFOV)
	end
end

-- ===================== GUN MODS: NO RECOIL =====================
local function startNoRecoil()
	C.noRecoilConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local tool = character:FindFirstChildOfClass("Tool")
			if not tool then return end
			-- Find any recoil-related values and zero them
			for _, desc in ipairs(tool:GetDescendants()) do
				if desc:IsA("NumberValue") and (desc.Name:lower():find("recoil") or desc.Name:lower():find("kick") or desc.Name:lower():find("spread")) then
					desc.Value = 0
				end
			end
		end)
	end)
	addLog("[NO RECOIL] ON", COLORS.success)
end

local function stopNoRecoil()
	if C.noRecoilConnection then C.noRecoilConnection:Disconnect() C.noRecoilConnection = nil end
	addLog("[NO RECOIL] OFF", COLORS.error)
end

-- ===================== GUN MODS: NO SPREAD =====================
local function startNoSpread()
	C.noSpreadConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local tool = character:FindFirstChildOfClass("Tool")
			if not tool then return end
			for _, desc in ipairs(tool:GetDescendants()) do
				if desc:IsA("NumberValue") and (desc.Name:lower():find("spread") or desc.Name:lower():find("bloom") or desc.Name:lower():find("inaccuracy")) then
					desc.Value = 0
				end
			end
		end)
	end)
	addLog("[NO SPREAD] ON", COLORS.success)
end

local function stopNoSpread()
	if C.noSpreadConnection then C.noSpreadConnection:Disconnect() C.noSpreadConnection = nil end
	addLog("[NO SPREAD] OFF", COLORS.error)
end

-- ===================== GUN MODS: RAPID FIRE =====================
local function startRapidFire()
	C.rapidFireConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local tool = character:FindFirstChildOfClass("Tool")
			if not tool then return end
			for _, desc in ipairs(tool:GetDescendants()) do
				if desc:IsA("NumberValue") and (desc.Name:lower():find("firerate") or desc.Name:lower():find("cooldown") or desc.Name:lower():find("delay") or desc.Name:lower():find("firedelay")) then
					desc.Value = 0.01
				end
			end
		end)
	end)
	addLog("[RAPID FIRE] ON", COLORS.success)
end

local function stopRapidFire()
	if C.rapidFireConnection then C.rapidFireConnection:Disconnect() C.rapidFireConnection = nil end
	addLog("[RAPID FIRE] OFF", COLORS.error)
end

-- ===================== HITBOX EXPANDER =====================
local savedHeadProps = {}
local function startHitboxExpand()
	C.hitboxConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					if not shouldSkipTeammate(player) then
						local head = player.Character:FindFirstChild("Head")
						if head and head:IsA("BasePart") then
							if not savedHeadProps[head] then
								savedHeadProps[head] = {Size = head.Size, Transparency = head.Transparency}
							end
							head.Size = Vector3.new(S.hitboxSize, S.hitboxSize, S.hitboxSize)
							head.Transparency = 0.8
							head.CanCollide = false
						end
					end
				end
			end
		end)
	end)
	addLog("[HITBOX] ON - Size: " .. S.hitboxSize, COLORS.success)
end

local function stopHitboxExpand()
	if C.hitboxConnection then C.hitboxConnection:Disconnect() C.hitboxConnection = nil end
	-- Restore head sizes from captured originals
	pcall(function()
		for head, props in pairs(savedHeadProps) do
			if head and head:IsA("BasePart") then
				head.Size = props.Size
				head.Transparency = props.Transparency
			end
		end
	end)
	savedHeadProps = {}
	addLog("[HITBOX] OFF", COLORS.error)
end

-- ===================== FULLBRIGHT =====================
local function startFullbright()
	origAmbient = Lighting.Ambient
	origBrightness = Lighting.Brightness
	origFogEnd = Lighting.FogEnd
	origGlobalShadows = Lighting.GlobalShadows
	Lighting.Ambient = Color3.fromRGB(200, 200, 200)
	Lighting.Brightness = 2
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = false
	addLog("[FULLBRIGHT] ON", COLORS.success)
end

local function stopFullbright()
	if origAmbient then Lighting.Ambient = origAmbient end
	if origBrightness then Lighting.Brightness = origBrightness end
	if origFogEnd then Lighting.FogEnd = origFogEnd end
	if origGlobalShadows ~= nil then Lighting.GlobalShadows = origGlobalShadows end
	addLog("[FULLBRIGHT] OFF", COLORS.error)
end

-- ===================== FOV CHANGER =====================
local function setGameFOV(fov)
	pcall(function()
		Camera = workspace.CurrentCamera
		Camera.FieldOfView = fov
	end)
end

-- ===================== FLY LOGIC =====================
local function startFly()
	local character = LocalPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	C.bodyGyro = Instance.new("BodyGyro")
	C.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	C.bodyGyro.P = 9e4
	C.bodyGyro.Parent = hrp
	C.bodyVelocity = Instance.new("BodyVelocity")
	C.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	C.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	C.bodyVelocity.Parent = hrp
	C.flyConnection = RunService.Heartbeat:Connect(function()
		if not S.flyEnabled or not hrp or not hrp.Parent then return end
		local cam = workspace.CurrentCamera
		local dir = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
		if dir.Magnitude > 0 then dir = dir.Unit end
		C.bodyVelocity.Velocity = dir * S.flySpeed
		C.bodyGyro.CFrame = cam.CFrame
	end)
	addLog("[FLY] ON - Speed: " .. S.flySpeed, COLORS.success)
end

local function stopFly()
	if C.flyConnection then C.flyConnection:Disconnect() C.flyConnection = nil end
	if C.bodyGyro then pcall(function() C.bodyGyro:Destroy() end) C.bodyGyro = nil end
	if C.bodyVelocity then pcall(function() C.bodyVelocity:Destroy() end) C.bodyVelocity = nil end
	addLog("[FLY] OFF", COLORS.error)
end

-- ===================== NOCLIP LOGIC =====================
local function startNoclip()
	C.noclipConnection = RunService.Stepped:Connect(function()
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
	if C.noclipConnection then C.noclipConnection:Disconnect() C.noclipConnection = nil end
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
			if humanoid then origWalkSpeed = humanoid.WalkSpeed humanoid.WalkSpeed = S.speedValue end
		end
	end)
	addLog("[SPEED] ON - WalkSpeed: " .. S.speedValue, COLORS.success)
end

local function stopSpeed()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.WalkSpeed = origWalkSpeed end
		end
	end)
	addLog("[SPEED] OFF", COLORS.error)
end

-- ===================== INFINITE JUMP LOGIC =====================
local function startInfJump()
	C.infJumpConnection = UserInputService.JumpRequest:Connect(function()
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
	if C.infJumpConnection then C.infJumpConnection:Disconnect() C.infJumpConnection = nil end
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

-- ===================== SPIN FLING LOGIC =====================
local function startFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Set density to 100 (super heavy = others get launched on contact)
		C.savedPhysProps = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				C.savedPhysProps[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
			end
		end

		-- Enable noclip so we can move freely while spinning
		if not S.noclipEnabled then S.noclipEnabled = true startNoclip() end
		_wait(0.1)

		-- BodyAngularVelocity - spin on ALL axes for chaotic collision
		C.spinBAV = Instance.new("BodyAngularVelocity")
		C.spinBAV.AngularVelocity = Vector3.new(S.flingPower, S.flingPower, S.flingPower)
		C.spinBAV.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		C.spinBAV.P = math.huge
		C.spinBAV.Parent = root

		-- Disable collision on character parts
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end

		-- Heartbeat: random velocity perturbation to keep physics active
		C.flingConnection = RunService.Heartbeat:Connect(function()
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end
				local rt = char:FindFirstChild("HumanoidRootPart")
				if not rt then return end
				rt.Velocity = rt.Velocity + Vector3.new(
					math.random(-50, 50),
					0,
					math.random(-50, 50)
				)
			end)
		end)

		-- Pulse spin on/off for repeated impulse spikes
		C.flingConnection2 = _spawn(function()
			while S.flingEnabled do
				if C.spinBAV and C.spinBAV.Parent then
					C.spinBAV.AngularVelocity = Vector3.new(S.flingPower, S.flingPower, S.flingPower)
				end
				_wait(0.15)
				if C.spinBAV and C.spinBAV.Parent then
					C.spinBAV.AngularVelocity = Vector3.new(0, 0, 0)
				end
				_wait(0.05)
			end
		end)

		addLog("[SPIN FLING] ON - Walk into players!", COLORS.success)
	end)
	if not ok then
		addLog("[SPIN FLING] Error: " .. tostring(err), COLORS.error)
	end
end

local function stopFling()
	-- Disconnect heartbeat
	if C.flingConnection then C.flingConnection:Disconnect() C.flingConnection = nil end

	-- Remove BodyAngularVelocity
	if C.spinBAV then pcall(function() C.spinBAV:Destroy() end) C.spinBAV = nil end

	-- Restore physics properties
	local character = LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				if C.savedPhysProps[part] then
					part.CustomPhysicalProperties = C.savedPhysProps[part]
				else
					part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
				end
			end
		end
		-- Break velocity
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Velocity = Vector3.new(0, 0, 0)
				part.RotVelocity = Vector3.new(0, 0, 0)
			end
		end
	end
	C.savedPhysProps = {}

	addLog("[SPIN FLING] OFF", COLORS.error)
end

-- ===================== SPIN LOGIC =====================
local function startSpin()
	C.spinConnection = RunService.Heartbeat:Connect(function()
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
	if C.spinConnection then C.spinConnection:Disconnect() C.spinConnection = nil end
	addLog("[SPIN] OFF", COLORS.error)
end

-- ===================== EMOTE LOGIC =====================
local function stopEmote()
	S.emoteActive = false
	if C.emoteConnection then C.emoteConnection:Disconnect() C.emoteConnection = nil end
	for _, track in ipairs(C.emoteTracks) do
		pcall(function() track:Stop() end)
	end
	C.emoteTracks = {}
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
		table.insert(C.emoteTracks, track)
		S.emoteActive = true
		if duration then
			_spawn(function()
				_wait(duration)
				if S.emoteActive then stopEmote() end
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
		S.emoteActive = true

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
			table.insert(C.emoteTracks, track1)
			table.insert(C.emoteTracks, track2)

			-- Loop by replaying when tracks finish
			C.emoteConnection = RunService.Heartbeat:Connect(function()
				if not S.emoteActive then return end
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
			table.insert(C.emoteTracks, track)

			C.emoteConnection = RunService.Heartbeat:Connect(function()
				if not S.emoteActive then return end
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

-- ===================== KILL AURA =====================
local function startKillAura()
	C.killAuraConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local myHRP = character:FindFirstChild("HumanoidRootPart")
			if not myHRP then return end
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					if not shouldSkipTeammate(player) then
						local theirChar = player.Character
						if theirChar then
							local theirHRP = theirChar:FindFirstChild("HumanoidRootPart")
							if theirHRP and (myHRP.Position - theirHRP.Position).Magnitude <= S.killAuraRange then
								local direction = (theirHRP.Position - myHRP.Position)
								direction = direction.Magnitude > 0.1 and direction.Unit or Vector3.new(0, 1, 0)
								for _, part in ipairs(theirChar:GetDescendants()) do
									if part:IsA("BasePart") and not part.Anchored then
										part.Velocity = direction * 200 + Vector3.new(0, 100, 0)
									end
								end
							end
						end
					end
				end
			end
		end)
	end)
	addLog("[KILL AURA] ON - Range: " .. S.killAuraRange, COLORS.success)
end

local function stopKillAura()
	if C.killAuraConnection then C.killAuraConnection:Disconnect() C.killAuraConnection = nil end
	addLog("[KILL AURA] OFF", COLORS.error)
end

-- ===================== AUTO FIRE =====================
local function startAutoFire()
	C.autoFireConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not S.autoFireEnabled then return end
			local character = LocalPlayer.Character
			if not character then return end
			local tool = character:FindFirstChildOfClass("Tool")
			if not tool then return end
			pcall(function() mouse1click() end)
		end)
	end)
	addLog("[AUTO FIRE] ON - Equip weapon!", COLORS.success)
end

local function stopAutoFire()
	if C.autoFireConnection then C.autoFireConnection:Disconnect() C.autoFireConnection = nil end
	addLog("[AUTO FIRE] OFF", COLORS.error)
end

-- ===================== NO FOG =====================
local function startNoFog()
	C.noFogOrigFogStart = Lighting.FogStart
	C.noFogOrigFogEnd = Lighting.FogEnd
	Lighting.FogStart = 999999
	Lighting.FogEnd = 9999999
	addLog("[NO FOG] ON", COLORS.success)
end

local function stopNoFog()
	if C.noFogOrigFogStart then Lighting.FogStart = C.noFogOrigFogStart end
	if C.noFogOrigFogEnd then Lighting.FogEnd = C.noFogOrigFogEnd end
	addLog("[NO FOG] OFF", COLORS.error)
end

-- ===================== CHAMS =====================
local function enableChams()
	local function addPlayerChams(player)
		if player == LocalPlayer then return end
		local function updateChams()
			if C.chamsObjects[player] then
				for _, obj in pairs(C.chamsObjects[player]) do
					pcall(function()
						if typeof(obj) == "RBXScriptConnection" then obj:Disconnect()
						else obj:Destroy() end
					end)
				end
			end
			C.chamsObjects[player] = {}
			local character = player.Character
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then return end

			local isEnemy = not shouldSkipTeammate(player)
			local fillColor = isEnemy and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
			local outlineColor = isEnemy and Color3.fromRGB(255, 200, 200) or Color3.fromRGB(200, 255, 200)

			local hl = Instance.new("Highlight")
			hl.Name = "SXChams"
			hl.FillColor = fillColor
			hl.OutlineColor = outlineColor
			hl.FillTransparency = 0.3
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = character
			hl.Parent = character
			table.insert(C.chamsObjects[player], hl)
		end
		updateChams()
		local conn = player.CharacterAdded:Connect(function()
			_wait(1)
			if S.chamsEnabled then updateChams() end
		end)
		table.insert(C.chamsCharConnections, conn)
	end

	for _, player in ipairs(Players:GetPlayers()) do addPlayerChams(player) end
	C.chamsPlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
		_wait(2)
		if S.chamsEnabled then addPlayerChams(player) end
	end)
	addLog("[CHAMS] ON", COLORS.success)
end

local function disableChams()
	if C.chamsPlayerAddedConnection then C.chamsPlayerAddedConnection:Disconnect() C.chamsPlayerAddedConnection = nil end
	for _, conn in ipairs(C.chamsCharConnections) do pcall(function() conn:Disconnect() end) end
	C.chamsCharConnections = {}
	for player, objects in pairs(C.chamsObjects) do
		for _, obj in pairs(objects) do
			pcall(function()
				if typeof(obj) == "RBXScriptConnection" then obj:Disconnect()
				else obj:Destroy() end
			end)
		end
	end
	C.chamsObjects = {}
	addLog("[CHAMS] OFF", COLORS.error)
end

-- ===================== GOD MODE =====================
local function startGod()
	C.godConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.MaxHealth = math.huge
				humanoid.Health = math.huge
			end
		end)
	end)
	addLog("[GOD] ON (client-side)", COLORS.success)
end

local function stopGod()
	if C.godConnection then C.godConnection:Disconnect() C.godConnection = nil end
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.MaxHealth = 100 humanoid.Health = 100 end
		end
	end)
	addLog("[GOD] OFF", COLORS.error)
end

-- ===================== INVISIBLE =====================
local function startInvisible()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local savedCF = hrp.CFrame
		local savedChar = character

		-- FE Invisible: seat trick to disconnect character from player
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

		-- Client-side transparency so we can't see ourselves
		C.savedTransparencies = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				C.savedTransparencies[part] = part.Transparency
				part.Transparency = 1
			elseif part:IsA("Decal") or part:IsA("Texture") then
				C.savedTransparencies[part] = part.Transparency
				part.Transparency = 1
			end
		end
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				if handle then C.savedTransparencies[handle] = handle.Transparency handle.Transparency = 1 end
			end
		end
	end)
	addLog("[INVISIBLE] ON (FE invisible)", COLORS.success)
end

local function stopInvisible()
	pcall(function()
		for part, transparency in pairs(C.savedTransparencies) do
			if part and part.Parent then part.Transparency = transparency end
		end
		C.savedTransparencies = {}
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

-- ===================== ANTI-AFK =====================
local function startAntiAfk()
	pcall(function()
		local VirtualUser = game:GetService("VirtualUser")
		C.antiAfkConnection = LocalPlayer.Idled:Connect(function()
			VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
			_wait(1)
			VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		end)
	end)
	addLog("[ANTI-AFK] ON", COLORS.success)
end

local function stopAntiAfk()
	if C.antiAfkConnection then C.antiAfkConnection:Disconnect() C.antiAfkConnection = nil end
	addLog("[ANTI-AFK] OFF", COLORS.error)
end

-- ===================== BUNNY HOP =====================
local function startBunnyHop()
	C.bunnyHopConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not S.bunnyHopEnabled then return end
			local character = LocalPlayer.Character
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				local state = humanoid:GetState()
				if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end)
	end)
	addLog("[BHOP] ON - Hold W to auto-jump", COLORS.success)
end

local function stopBunnyHop()
	if C.bunnyHopConnection then C.bunnyHopConnection:Disconnect() C.bunnyHopConnection = nil end
	addLog("[BHOP] OFF", COLORS.error)
end

-- ===================== GRAVITY =====================
local function setGravity(value)
	pcall(function() workspace.Gravity = value end)
end

-- ===================== TELEPORT TO PLAYER =====================
local function teleportToPlayer(targetPlayer)
	pcall(function()
		local myChar = LocalPlayer.Character
		local theirChar = targetPlayer.Character
		if myChar and theirChar then
			local myHRP = myChar:FindFirstChild("HumanoidRootPart")
			local theirHRP = theirChar:FindFirstChild("HumanoidRootPart")
			if myHRP and theirHRP then
				myHRP.CFrame = theirHRP.CFrame * CFrame.new(0, 0, -5)
				addLog("[TP] Teleported to " .. targetPlayer.DisplayName, COLORS.success)
			end
		end
	end)
end

-- ===================== SPECTATE =====================
local function spectatePlayer(targetPlayer)
	pcall(function()
		if targetPlayer and targetPlayer.Character then
			local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				workspace.CurrentCamera.CameraSubject = humanoid
				S.spectating = true
				addLog("[SPECTATE] Watching " .. targetPlayer.DisplayName, COLORS.success)
			end
		end
	end)
end

local function unspectate()
	pcall(function()
		local myChar = LocalPlayer.Character
		if myChar then
			local humanoid = myChar:FindFirstChildOfClass("Humanoid")
			if humanoid then workspace.CurrentCamera.CameraSubject = humanoid end
		end
		S.spectating = false
		addLog("[SPECTATE] Stopped", COLORS.error)
	end)
end

-- ===================== WALK FLING =====================
local function startWalkFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Set density to 100
		C.walkFlingProps = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				C.walkFlingProps[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
			end
		end

		-- Heartbeat: velocity spikes using AssemblyLinearVelocity
		C.walkFlingConnection = RunService.Heartbeat:Connect(function()
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end
				local rt = char:FindFirstChild("HumanoidRootPart")
				if not rt then return end
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hum then return end
				local moveDir = hum.MoveDirection
				if moveDir.Magnitude > 0.1 then
					rt.AssemblyLinearVelocity = moveDir.Unit * S.walkFlingPower + Vector3.new(0, 0, 0)
				end
			end)
		end)

		addLog("[WALK FLING] ON - Walk into players!", COLORS.success)
	end)
	if not ok then
		addLog("[WALK FLING] Error: " .. tostring(err), COLORS.error)
	end
end

local function stopWalkFling()
	if C.walkFlingConnection then C.walkFlingConnection:Disconnect() C.walkFlingConnection = nil end
	local character = LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				if C.walkFlingProps[part] then
					part.CustomPhysicalProperties = C.walkFlingProps[part]
				else
					part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
				end
			end
		end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Velocity = Vector3.new(0, 0, 0)
			end
		end
	end
	C.walkFlingProps = {}
	addLog("[WALK FLING] OFF", COLORS.error)
end

-- ===================== SEIZURE =====================
local function startSeizure()
	C.seizureConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = hrp.CFrame * CFrame.Angles(
					math.rad(math.random(-30, 30)),
					math.rad(math.random(-30, 30)),
					math.rad(math.random(-30, 30))
				)
			end
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
	if C.seizureConnection then C.seizureConnection:Disconnect() C.seizureConnection = nil end
	addLog("[SEIZURE] OFF", COLORS.error)
end

-- ===================== HEADLESS =====================
local function startHeadless()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local head = character:FindFirstChild("Head")
		if not head then return end
		C.headlessSavedParts = {}
		C.headlessSavedParts.headTransparency = head.Transparency
		head.Transparency = 1
		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("Decal") then
				C.headlessSavedParts[child] = child.Transparency
				child.Transparency = 1
			elseif child:IsA("SpecialMesh") then
				C.headlessSavedParts[child] = child.Scale
				child.Scale = Vector3.new(0, 0, 0)
			end
		end
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				if handle then
					local att = handle:FindFirstChildOfClass("Attachment")
					if att and (att.Name == "HatAttachment" or att.Name == "HairAttachment" or att.Name == "FaceFrontAttachment" or att.Name == "FaceCenterAttachment") then
						C.headlessSavedParts[handle] = handle.Transparency
						handle.Transparency = 1
					end
				end
			end
		end
	end)
	addLog("[HEADLESS] ON", COLORS.success)
end

local function stopHeadless()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local head = character:FindFirstChild("Head")
		if head and C.headlessSavedParts.headTransparency then
			head.Transparency = C.headlessSavedParts.headTransparency
		end
		for obj, val in pairs(C.headlessSavedParts) do
			if obj ~= "headTransparency" and typeof(obj) ~= "string" and obj and obj.Parent then
				if typeof(val) == "Vector3" then
					obj.Scale = val
				elseif typeof(val) == "number" then
					obj.Transparency = val
				end
			end
		end
		C.headlessSavedParts = {}
	end)
	addLog("[HEADLESS] OFF", COLORS.error)
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
	createInfoLabel(tab, "RIVALS Hub v1.6", 2)
	createInfoLabel(tab, "SX The Revival", 3)


	createSectionLabel(tab, "Quick Actions", 5)

	createActionButton(tab, "Rejoin Server", 6, function()
		rejoinServer()
	end)
	createActionButton(tab, "Server Hop", 7, function()
		serverHop()
	end)


	createSectionLabel(tab, "Log", 9)

	createInfoLabel(tab, "Output goes to the F9 console.", 99)
end

-- =====================================================================
-- ======================== BUILD COMBAT TAB ==========================
-- =====================================================================
do
	local tab = tabFrames["Combat"]

	createSectionLabel(tab, "Aimbot", 1)

	createToggle(tab, "Aimbot (Hold RMB)", 2, function(on)
		S.aimbotEnabled = on
		if on then startAimbot() else stopAimbot() end
	end)
	createSlider(tab, "Aimbot FOV", 50, 500, S.aimbotFOV, 3, function(val)
		S.aimbotFOV = val
		updateFOVCircleSize()
	end)
	createSlider(tab, "Smoothing", 1, 20, S.aimbotSmoothing, 4, function(val)
		S.aimbotSmoothing = val
	end)
	createToggle(tab, "Team Check", 5, function(on)
		S.teamCheck = on
		if on then
			addLog("[TEAM CHECK] ON - Won't target teammates", COLORS.success)
		else
			addLog("[TEAM CHECK] OFF - Targeting everyone", COLORS.error)
		end
	end).setVisualState(true) -- Default on
	createSlider(tab, "Max Distance", 50, 1000, S.aimbotMaxDist, 6, function(val)
		S.aimbotMaxDist = val
	end)
	createToggle(tab, "Wall Check", 7, function(on)
		S.aimbotWallCheck = on
		if on then
			addLog("[WALL CHECK] ON - Only visible targets", COLORS.success)
		else
			addLog("[WALL CHECK] OFF - Aim through walls", COLORS.error)
		end
	end).setVisualState(true) -- Default on


	createSectionLabel(tab, "Automation", 9)

	createToggle(tab, "Silent Aim", 10, function(on)
		S.silentAimEnabled = on
		if on then startSilentAim() else stopSilentAim() end
	end)
	createToggle(tab, "TriggerBot", 11, function(on)
		S.triggerBotEnabled = on
		if on then startTriggerBot() else stopTriggerBot() end
	end)
	createToggle(tab, "Auto Fire", 12, function(on)
		S.autoFireEnabled = on
		if on then startAutoFire() else stopAutoFire() end
	end)


	createSectionLabel(tab, "Aim Part", 14)

	local aimPartLabel = createInfoLabel(tab, "Current: " .. S.aimbotAimPart, 15)

	createActionButton(tab, "Aim: Head", 16, function()
		S.aimbotAimPart = "Head"
		aimPartLabel.Text = "Current: Head"
		addLog("[AIM PART] Head", COLORS.success)
	end)
	createActionButton(tab, "Aim: Torso", 17, function()
		S.aimbotAimPart = "HumanoidRootPart"
		aimPartLabel.Text = "Current: HumanoidRootPart"
		addLog("[AIM PART] Torso", COLORS.success)
	end)
	createActionButton(tab, "Aim: Random", 18, function()
		S.aimbotAimPart = (math.random(1, 2) == 1) and "Head" or "HumanoidRootPart"
		aimPartLabel.Text = "Current: " .. S.aimbotAimPart
		addLog("[AIM PART] Random -> " .. S.aimbotAimPart, COLORS.success)
	end)


	createSectionLabel(tab, "Kill Zone", 20)

	createToggle(tab, "Kill Aura", 21, function(on)
		S.killAuraEnabled = on
		if on then startKillAura() else stopKillAura() end
	end)
	createSlider(tab, "Kill Aura Range", 5, 30, S.killAuraRange, 22, function(val) S.killAuraRange = val end)


	createSectionLabel(tab, "Visual", 24)

	createToggle(tab, "FOV Circle", 25, function(on)
		S.fovCircleEnabled = on
		if on then createFOVCircle() else destroyFOVCircle() end
	end)
end

-- =====================================================================
-- ======================== BUILD ESP TAB =============================
-- =====================================================================
do
	local tab = tabFrames["ESP"]

	createSectionLabel(tab, "Player ESP", 1)

	createToggle(tab, "ESP", 2, function(on)
		S.espEnabled = on
		if on then enableESP() else disableESP() end
	end)
	createToggle(tab, "Show Names", 3, function(on)
		S.espNameEnabled = on
		if S.espEnabled then
			disableESP()
			enableESP()
		end
	end).setVisualState(true) -- Default on
	createToggle(tab, "Show Health Bars", 4, function(on)
		S.espHealthBar = on
		if S.espEnabled then
			disableESP()
			enableESP()
		end
	end).setVisualState(true) -- Default on
	createToggle(tab, "Show Distance", 5, function(on)
		S.espDistEnabled = on
		if S.espEnabled then
			disableESP()
			enableESP()
		end
	end).setVisualState(true) -- Default on


	createSectionLabel(tab, "World", 7)

	createToggle(tab, "Fullbright", 8, function(on)
		S.fullbrightEnabled = on
		if on then startFullbright() else stopFullbright() end
	end)
	createToggle(tab, "No Fog", 9, function(on)
		S.noFogEnabled = on
		if on then startNoFog() else stopNoFog() end
	end)


	createSectionLabel(tab, "Chams", 11)

	createToggle(tab, "Chams (Through Walls)", 12, function(on)
		S.chamsEnabled = on
		if on then enableChams() else disableChams() end
	end)
end

-- =====================================================================
-- ======================== BUILD GUNMODS TAB =========================
-- =====================================================================
do
	local tab = tabFrames["GunMods"]

	createSectionLabel(tab, "Weapon Mods", 1)

	createToggle(tab, "No Recoil", 2, function(on)
		S.noRecoilEnabled = on
		if on then startNoRecoil() else stopNoRecoil() end
	end)
	createToggle(tab, "No Spread", 3, function(on)
		S.noSpreadEnabled = on
		if on then startNoSpread() else stopNoSpread() end
	end)
	createToggle(tab, "Rapid Fire", 4, function(on)
		S.rapidFireEnabled = on
		if on then startRapidFire() else stopRapidFire() end
	end)


	createSectionLabel(tab, "Hitbox", 6)

	createToggle(tab, "Hitbox Expander", 7, function(on)
		S.hitboxExpandEnabled = on
		if on then startHitboxExpand() else stopHitboxExpand() end
	end)
	createSlider(tab, "Hitbox Size", 2, 30, S.hitboxSize, 8, function(val)
		S.hitboxSize = val
	end)
end

-- =====================================================================
-- ======================== BUILD PLAYER TAB ==========================
-- =====================================================================
do
	local tab = tabFrames["Player"]

	createSectionLabel(tab, "Movement", 1)

	createToggle(tab, "Fly", 2, function(on)
		S.flyEnabled = on
		if on then startFly() else stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 500, S.flySpeed, 3, function(val) S.flySpeed = val end)
	createToggle(tab, "Speed Boost", 4, function(on)
		S.speedEnabled = on
		if on then startSpeed() else stopSpeed() end
	end)
	createSlider(tab, "Walk Speed", 16, 500, S.speedValue, 5, function(val)
		S.speedValue = val
		if S.speedEnabled then
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
		S.noclipEnabled = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "Infinite Jump", 7, function(on)
		S.infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)
	createSlider(tab, "Jump Power", 10, 500, S.jumpPowerValue, 8, function(val)
		S.jumpPowerValue = val
		setJumpPower(val)
	end)
	createToggle(tab, "Bunny Hop", 9, function(on)
		S.bunnyHopEnabled = on
		if on then startBunnyHop() else stopBunnyHop() end
	end)


	createSectionLabel(tab, "Survival", 11)

	createToggle(tab, "God Mode", 12, function(on)
		S.godEnabled = on
		if on then startGod() else stopGod() end
	end)
	createToggle(tab, "Invisible", 13, function(on)
		S.invisibleEnabled = on
		if on then startInvisible() else stopInvisible() end
	end)
	createToggle(tab, "Anti-AFK", 14, function(on)
		S.antiAfkEnabled = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)


	createSectionLabel(tab, "Physics", 16)

	createSlider(tab, "Gravity", 0, 1000, 196, 17, function(val)
		S.gravityValue = val
		setGravity(val)
	end)


	createSectionLabel(tab, "Camera", 19)

	createSlider(tab, "Camera FOV", 50, 120, S.cameraFOV, 20, function(val)
		S.cameraFOV = val
		setGameFOV(val)
	end)


	createSectionLabel(tab, "Player Target", 22)

	local selectedPlayerLabel = createDynamicLabel(tab, "Selected: None")

	createActionButton(tab, "Teleport to Player", 24, function()
		if S.selectedPlayer then teleportToPlayer(S.selectedPlayer)
		else addLog("[TP] No player selected!", COLORS.error) end
	end)
	createActionButton(tab, "Spectate Player", 25, function()
		if S.selectedPlayer then spectatePlayer(S.selectedPlayer)
		else addLog("[SPECTATE] No player selected!", COLORS.error) end
	end)
	createActionButton(tab, "Unspectate", 26, function()
		unspectate()
	end)


	createSectionLabel(tab, "Player List", 28)

	-- Was a button per player; a dropdown rebuilt on join/leave, which does
	-- not overflow a full server.
	local rivalsPlayers, rivalsDropdown = {}, nil
	local function refreshPlayerList()
		rivalsPlayers = {}
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local label = player.DisplayName .. " (@" .. player.Name .. ")"
				rivalsPlayers[label] = player
				table.insert(names, label)
			end
		end
		if #names == 0 then names = {"(no players)"} end
		if rivalsDropdown then pcall(function() rivalsDropdown:SetValues(names) end) end
	end
	rivalsDropdown = createDropdown(tab, "Select Player", {"(refresh first)"}, "(refresh first)", function(choice)
		local player = rivalsPlayers[choice]
		if not player then return end
		S.selectedPlayer = player
		selectedPlayerLabel.Text = "Selected: " .. player.DisplayName
		addLog("[SELECT] " .. player.DisplayName, COLORS.accent)
	end)
	createActionButton(tab, "Refresh Player List", 30, refreshPlayerList)
	refreshPlayerList()
	Players.PlayerAdded:Connect(function() _wait(1) refreshPlayerList() end)
	Players.PlayerRemoving:Connect(function(player)
		if S.selectedPlayer == player then
			S.selectedPlayer = nil
			selectedPlayerLabel.Text = "Selected: None"
		end
		_wait(0.5)
		refreshPlayerList()
	end)
end

-- =====================================================================
-- ======================== BUILD FUN TAB =============================
-- =====================================================================
do
	local tab = tabFrames["Fun"]

	createSectionLabel(tab, "Fling", 1)

	local spinFlingToggle, walkFlingToggle
	spinFlingToggle = createToggle(tab, "Spin Fling", 2, function(on)
		if on and S.walkFlingEnabled then
			S.walkFlingEnabled = false
			stopWalkFling()
			if walkFlingToggle then walkFlingToggle.setVisualState(false) end
		end
		S.flingEnabled = on
		if on then startFling() else stopFling() end
	end)
	createSlider(tab, "Fling Power", 1000, 99999, S.flingPower, 3, function(val) S.flingPower = val end)
	walkFlingToggle = createToggle(tab, "Walk Fling", 4, function(on)
		if on and S.flingEnabled then
			S.flingEnabled = false
			stopFling()
			if spinFlingToggle then spinFlingToggle.setVisualState(false) end
		end
		S.walkFlingEnabled = on
		if on then startWalkFling() else stopWalkFling() end
	end)
	createSlider(tab, "Walk Fling Power", 1000, 50000, S.walkFlingPower, 5, function(val) S.walkFlingPower = val end)


	createSectionLabel(tab, "Visual", 7)

	createToggle(tab, "Spin", 8, function(on)
		S.spinEnabled = on
		if on then startSpin() else stopSpin() end
	end)
	createToggle(tab, "Seizure", 9, function(on)
		S.seizureEnabled = on
		if on then startSeizure() else stopSeizure() end
	end)


	createSectionLabel(tab, "Character", 11)

	createActionButton(tab, "Headless", 12, function()
		if S.headlessEnabled then
			S.headlessEnabled = false
			stopHeadless()
		else
			S.headlessEnabled = true
			startHeadless()
		end
	end)


	createSectionLabel(tab, "Emotes", 14)

	createActionButton(tab, "Emote 1", 15, function()
		playJerkEmote()
	end)
	createActionButton(tab, "Dance", 16, function()
		playEmote(507771019, 1, 10)
		addLog("[EMOTE] Dance!", COLORS.success)
	end)
	createActionButton(tab, "Dab", 17, function()
		playEmote(183412246, 1, 3)
		addLog("[EMOTE] Dab!", COLORS.success)
	end)
	createActionButton(tab, "Stop Emote", 18, function()
		stopEmote()
		addLog("[EMOTE] Stopped", COLORS.error)
	end)
end

-- =====================================================================
-- ======================== CHAT COMMANDS =============================
-- =====================================================================
local commands = {}

-- Combat
commands["aimbot"] = function() S.aimbotEnabled = true startAimbot() end
commands["unaimbot"] = function() S.aimbotEnabled = false stopAimbot() end
commands["silentaim"] = function() S.silentAimEnabled = true startSilentAim() end
commands["unsilentaim"] = function() S.silentAimEnabled = false stopSilentAim() end
commands["triggerbot"] = function() S.triggerBotEnabled = true startTriggerBot() end
commands["untriggerbot"] = function() S.triggerBotEnabled = false stopTriggerBot() end

-- ESP
commands["esp"] = function() S.espEnabled = true enableESP() end
commands["unesp"] = function() S.espEnabled = false disableESP() end

-- Gun Mods
commands["norecoil"] = function() S.noRecoilEnabled = true startNoRecoil() end
commands["unnorecoil"] = function() S.noRecoilEnabled = false stopNoRecoil() end
commands["nospread"] = function() S.noSpreadEnabled = true startNoSpread() end
commands["unnospread"] = function() S.noSpreadEnabled = false stopNoSpread() end
commands["rapidfire"] = function() S.rapidFireEnabled = true startRapidFire() end
commands["unrapidfire"] = function() S.rapidFireEnabled = false stopRapidFire() end

-- Hitbox
commands["hitbox"] = function(args)
	local v = tonumber(args[1])
	if v then S.hitboxSize = v end
	S.hitboxExpandEnabled = true
	startHitboxExpand()
end
commands["unhitbox"] = function() S.hitboxExpandEnabled = false stopHitboxExpand() end

-- World
commands["fullbright"] = function() S.fullbrightEnabled = true startFullbright() end
commands["unfullbright"] = function() S.fullbrightEnabled = false stopFullbright() end

-- FOV
commands["fov"] = function(args)
	local v = tonumber(args[1])
	if v then
		S.cameraFOV = v
		setGameFOV(v)
		addLog("[FOV] Set to " .. v, COLORS.success)
	else
		addLog("[FOV] Usage: ;fov [50-120]", COLORS.error)
	end
end

-- Movement
commands["fly"] = function() S.flyEnabled = true startFly() end
commands["unfly"] = function() S.flyEnabled = false stopFly() end
commands["noclip"] = function() S.noclipEnabled = true startNoclip() end
commands["unnoclip"] = function() S.noclipEnabled = false stopNoclip() end
commands["speed"] = function(args)
	local v = tonumber(args[1])
	if v then S.speedValue = v end
	S.speedEnabled = true
	startSpeed()
end
commands["unspeed"] = function() S.speedEnabled = false stopSpeed() end
commands["infjump"] = function() S.infJumpEnabled = true startInfJump() end
commands["uninfjump"] = function() S.infJumpEnabled = false stopInfJump() end

-- Fun
commands["fling"] = function() S.flingEnabled = true startFling() end
commands["unfling"] = function() S.flingEnabled = false stopFling() end
commands["spin"] = function() S.spinEnabled = true startSpin() end
commands["unspin"] = function() S.spinEnabled = false stopSpin() end

-- Combat (new)
commands["autofire"] = function() S.autoFireEnabled = true startAutoFire() end
commands["unautofire"] = function() S.autoFireEnabled = false stopAutoFire() end
commands["killaura"] = function() S.killAuraEnabled = true startKillAura() end
commands["unkillaura"] = function() S.killAuraEnabled = false stopKillAura() end
commands["aimpart"] = function(args)
	local part = args[1] and args[1]:lower()
	if part == "head" then S.aimbotAimPart = "Head"
	elseif part == "torso" or part == "body" then S.aimbotAimPart = "HumanoidRootPart"
	elseif part == "random" then S.aimbotAimPart = (math.random(1, 2) == 1) and "Head" or "HumanoidRootPart"
	else addLog("[CMD] Usage: ;aimpart head/torso/random", COLORS.error) return end
	addLog("[AIM PART] Set to " .. S.aimbotAimPart, COLORS.success)
end

-- ESP (new)
commands["nofog"] = function() S.noFogEnabled = true startNoFog() end
commands["unnofog"] = function() S.noFogEnabled = false stopNoFog() end
commands["chams"] = function() S.chamsEnabled = true enableChams() end
commands["unchams"] = function() S.chamsEnabled = false disableChams() end

-- Player (new)
commands["god"] = function() S.godEnabled = true startGod() end
commands["ungod"] = function() S.godEnabled = false stopGod() end
commands["invisible"] = function() S.invisibleEnabled = true startInvisible() end
commands["uninvisible"] = function() S.invisibleEnabled = false stopInvisible() end
commands["antiafk"] = function() S.antiAfkEnabled = true startAntiAfk() end
commands["unantiafk"] = function() S.antiAfkEnabled = false stopAntiAfk() end
commands["bhop"] = function() S.bunnyHopEnabled = true startBunnyHop() end
commands["unbhop"] = function() S.bunnyHopEnabled = false stopBunnyHop() end
commands["gravity"] = function(args)
	local v = tonumber(args[1])
	if v then S.gravityValue = v setGravity(v) addLog("[GRAVITY] Set to " .. v, COLORS.success)
	else addLog("[CMD] Usage: ;gravity [value]", COLORS.error) end
end
commands["tp"] = function(args)
	if not args[1] then addLog("[CMD] Usage: ;tp <player>", COLORS.error) return end
	local target = findPlayer(args[1])
	if target then teleportToPlayer(target) else addLog("[CMD] Player not found: " .. args[1], COLORS.error) end
end
commands["spectate"] = function(args)
	if not args[1] then addLog("[CMD] Usage: ;spectate <player>", COLORS.error) return end
	local target = findPlayer(args[1])
	if target then spectatePlayer(target) else addLog("[CMD] Player not found: " .. args[1], COLORS.error) end
end
commands["unspectate"] = function() unspectate() end

-- Fun (new)
commands["walkfling"] = function()
	if S.flingEnabled then S.flingEnabled = false stopFling() end
	S.walkFlingEnabled = true startWalkFling()
end
commands["unwalkfling"] = function() S.walkFlingEnabled = false stopWalkFling() end
commands["seizure"] = function() S.seizureEnabled = true startSeizure() end
commands["unseizure"] = function() S.seizureEnabled = false stopSeizure() end
commands["headless"] = function() S.headlessEnabled = true startHeadless() end
commands["unheadless"] = function() S.headlessEnabled = false stopHeadless() end

-- Emotes
commands["emote1"] = function() playJerkEmote() end
commands["dance"] = function() playEmote(507771019, 1, 10) addLog("[EMOTE] Dance!", COLORS.success) end
commands["dab"] = function() playEmote(183412246, 1, 3) addLog("[EMOTE] Dab!", COLORS.success) end
commands["stopemote"] = function() stopEmote() addLog("[EMOTE] Stopped", COLORS.error) end

-- Utility
commands["rejoin"] = function() rejoinServer() end
commands["serverhop"] = function() serverHop() end

-- Help
commands["cmds"] = function()
	addLog("--- RIVALS Hub Commands ---", COLORS.accent)
	addLog("-- Combat --", COLORS.accent)
	addLog(";aimbot / ;unaimbot    ;aimpart head/torso/random", COLORS.textSecondary)
	addLog(";silentaim / ;unsilentaim    ;triggerbot / ;untriggerbot", COLORS.textSecondary)
	addLog(";autofire / ;unautofire    ;killaura / ;unkillaura", COLORS.textSecondary)
	addLog("-- ESP --", COLORS.accent)
	addLog(";esp / ;unesp    ;chams / ;unchams", COLORS.textSecondary)
	addLog(";fullbright / ;unfullbright    ;nofog / ;unnofog", COLORS.textSecondary)
	addLog("-- Gun Mods --", COLORS.accent)
	addLog(";norecoil    ;nospread    ;rapidfire", COLORS.textSecondary)
	addLog(";hitbox [size] / ;unhitbox", COLORS.textSecondary)
	addLog("-- Player --", COLORS.accent)
	addLog(";fly / ;unfly    ;noclip / ;unnoclip    ;bhop / ;unbhop", COLORS.textSecondary)
	addLog(";speed [val] / ;unspeed    ;infjump / ;uninfjump", COLORS.textSecondary)
	addLog(";god / ;ungod    ;invisible / ;uninvisible", COLORS.textSecondary)
	addLog(";antiafk / ;unantiafk    ;gravity [val]    ;fov [val]", COLORS.textSecondary)
	addLog(";tp <player>    ;spectate <player> / ;unspectate", COLORS.textSecondary)
	addLog("-- Fun --", COLORS.accent)
	addLog(";fling / ;unfling    ;walkfling / ;unwalkfling", COLORS.textSecondary)
	addLog(";spin / ;unspin    ;seizure / ;unseizure", COLORS.textSecondary)
	addLog(";headless / ;unheadless", COLORS.textSecondary)
	addLog(";emote1  ;dance  ;dab  ;stopemote", COLORS.textSecondary)
	addLog("-- Utility --", COLORS.accent)
	addLog(";rejoin  ;serverhop  ;cmds", COLORS.textSecondary)
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
-- LocalPlayer.Chatted does not fire under the new TextChatService, now the
-- default, so also hook SendingMessage or commands silently do nothing there.
pcall(function()
	local TCS = game:GetService("TextChatService")
	if TCS and TCS.SendingMessage then
		TCS.SendingMessage:Connect(function(message)
			local msg = message and message.Text
			if type(msg) == "string" and msg:sub(1, 1) == ";" then
				processCommand(msg)
			end
		end)
	end
end)

-- ===================== KEYBOARD SHORTCUT =====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
end)

-- ===================== RESPAWN HOOKS =====================
Players.PlayerRemoving:Connect(function(player)
	-- Clean up ESP for leaving players
	if C.espObjects[player] then
		for _, obj in pairs(C.espObjects[player]) do
			pcall(function()
				if typeof(obj) == "RBXScriptConnection" then
					obj:Disconnect()
				else
					obj:Destroy()
				end
			end)
		end
		C.espObjects[player] = nil
	end
	-- Clean up Chams for leaving players
	if C.chamsObjects[player] then
		for _, obj in pairs(C.chamsObjects[player]) do
			pcall(function()
				if typeof(obj) == "RBXScriptConnection" then obj:Disconnect()
				else obj:Destroy() end
			end)
		end
		C.chamsObjects[player] = nil
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	_wait(0.5)

	-- Re-enable fly
	if S.flyEnabled then
		stopFly()
		_wait(0.3)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			startFly()
		end
	end

	-- Re-enable fling
	if S.flingEnabled then
		stopFling()
		_wait(0.3)
		startFling()
	end
	C.spinBAV = nil
	C.savedPhysProps = {}

	-- Re-enable speed
	if S.speedEnabled then
		_wait(0.3)
		startSpeed()
	end

	-- Re-enable noclip
	if S.noclipEnabled then
		_wait(0.1)
		startNoclip()
	end

	-- Re-enable infinite jump
	if S.infJumpEnabled then
		_wait(0.1)
		stopInfJump()
		startInfJump()
	end

	-- Re-apply jump power
	if S.jumpPowerValue ~= 50 then
		_wait(0.3)
		setJumpPower(S.jumpPowerValue)
	end

	-- Re-enable aimbot
	if S.aimbotEnabled then
		stopAimbot()
		_wait(0.2)
		startAimbot()
	end

	-- Re-enable ESP
	if S.espEnabled then
		disableESP()
		_wait(0.5)
		enableESP()
	end

	-- Re-enable gun mods
	if S.noRecoilEnabled then
		stopNoRecoil()
		_wait(0.1)
		startNoRecoil()
	end
	if S.noSpreadEnabled then
		stopNoSpread()
		_wait(0.1)
		startNoSpread()
	end
	if S.rapidFireEnabled then
		stopRapidFire()
		_wait(0.1)
		startRapidFire()
	end

	-- Re-enable hitbox expander
	if S.hitboxExpandEnabled then
		stopHitboxExpand()
		_wait(0.2)
		startHitboxExpand()
	end

	-- Re-apply camera FOV
	if S.cameraFOV ~= 90 then
		_wait(0.3)
		setGameFOV(S.cameraFOV)
	end

	-- Re-enable fullbright
	if S.fullbrightEnabled then
		_wait(0.2)
		startFullbright()
	end

	-- Re-enable no fog
	if S.noFogEnabled then
		_wait(0.1)
		startNoFog()
	end

	-- Re-enable god mode
	if S.godEnabled then
		if C.godConnection then C.godConnection:Disconnect() C.godConnection = nil end
		_wait(0.1)
		startGod()
	end

	-- Re-enable invisible
	if S.invisibleEnabled then
		C.savedTransparencies = {}
		_wait(0.3)
		startInvisible()
	end

	-- Re-enable bunny hop
	if S.bunnyHopEnabled then
		if C.bunnyHopConnection then C.bunnyHopConnection:Disconnect() C.bunnyHopConnection = nil end
		_wait(0.1)
		startBunnyHop()
	end

	-- Re-enable walk fling
	if S.walkFlingEnabled then
		stopWalkFling()
		_wait(0.5)
		startWalkFling()
	end

	-- Re-enable kill aura
	if S.killAuraEnabled then
		if C.killAuraConnection then C.killAuraConnection:Disconnect() C.killAuraConnection = nil end
		_wait(0.1)
		startKillAura()
	end

	-- Re-enable auto fire
	if S.autoFireEnabled then
		if C.autoFireConnection then C.autoFireConnection:Disconnect() C.autoFireConnection = nil end
		_wait(0.1)
		startAutoFire()
	end

	-- Re-enable chams
	if S.chamsEnabled then
		disableChams()
		_wait(0.5)
		enableChams()
	end

	-- Re-enable headless
	if S.headlessEnabled then
		C.headlessSavedParts = {}
		_wait(0.3)
		startHeadless()
	end

	-- Re-apply gravity
	if S.gravityValue ~= 196.2 then
		_wait(0.1)
		setGravity(S.gravityValue)
	end

	-- Re-enable seizure
	if S.seizureEnabled then
		if C.seizureConnection then C.seizureConnection:Disconnect() C.seizureConnection = nil end
		_wait(0.1)
		startSeizure()
	end

	-- Unspectate on death
	if S.spectating then
		unspectate()
	end
end)

-- ===================== STARTUP =====================
addLog("RIVALS Hub v1.6", COLORS.accent)
addLog("Type ;cmds for command list", COLORS.textSecondary)
addLog("Use Right Shift to toggle GUI", COLORS.textSecondary)
print("[RIVALS Hub] v1.6 loaded")
