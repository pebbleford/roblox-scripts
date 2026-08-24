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
if not keySystem or not keySystem.validate("brookhaven") then return end

-- ================================================================
-- Pebbleford Hub - Brookhaven RP Admin Hub
-- Dedicated admin for Brookhaven RP
-- v1.0
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local _spawn = (task and task.spawn) or spawn
local _wait = (task and task.wait) or wait

-- ===================== COLOR PALETTE (Blue Theme) =====================
local COLORS = {
	bg = Color3.fromRGB(20, 20, 25),
	bgSecondary = Color3.fromRGB(30, 30, 38),
	tabBg = Color3.fromRGB(45, 45, 55),
	accent = Color3.fromRGB(0, 150, 255),
	accentHover = Color3.fromRGB(50, 170, 255),
	accentDark = Color3.fromRGB(0, 100, 180),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(176, 176, 176),
	textDim = Color3.fromRGB(120, 120, 120),
	border = Color3.fromRGB(50, 50, 60),
	toggleOn = Color3.fromRGB(0, 150, 255),
	toggleOff = Color3.fromRGB(85, 85, 85),
	error = Color3.fromRGB(255, 68, 68),
	success = Color3.fromRGB(68, 255, 68),
	warning = Color3.fromRGB(255, 200, 0),
	editor = Color3.fromRGB(15, 15, 20),
	btnExecute = Color3.fromRGB(0, 150, 255),
	btnClear = Color3.fromRGB(60, 60, 60),
}

-- ===================== STATE =====================
local espEnabled = false
local flyEnabled = false
local noclipEnabled = false
local flingEnabledNoclip = false
local speedEnabled = false
local infJumpEnabled = false
local godEnabled = false
local invisibleEnabled = false
local spinEnabled = false
local seizureEnabled = false
local flingEnabled = false
local walkFlingEnabled = false
local carNoclipEnabled = false
local rainbowCarEnabled = false
local rainbowHouseEnabled = false
local emoteActive = false
local killAuraEnabled = false

local flySpeed = 80
local speedValue = 100
local flingPower = 99999
local walkFlingPower = 10000
local jumpPowerValue = 50
local gravityValue = 196.2
local origWalkSpeed = 16
local origJumpPower = 50
local origGravity = 196.2

local highlights = {}
local nametags = {}
local nametagConns = {}
local espConnections = {}
local flyConnection = nil
local bodyGyro = nil
local bodyVelocity = nil
local noclipConnection = nil
local infJumpConnection = nil
local killAuraConnection = nil
local spinConnection = nil
local spinBAV = nil
local seizureConnection = nil
local flingConnection = nil
local savedPhysProps = {}
local walkFlingThread = nil
local walkFlingProps = {}
local carNoclipConnection = nil
local rainbowCarConnection = nil
local rainbowHouseConnection = nil
local emoteTracks = {}
local emoteConnection = nil
local selectedPlayer = nil
local windowVisible = true
local activeTab = "Main"
local logLines = {}
local MAX_LOG_LINES = 50

-- ESP config
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local FILL_TRANSPARENCY = 0.5
local OUTLINE_TRANSPARENCY = 0
local REFRESH_INTERVAL = 5

-- Brookhaven teleport locations
local TELEPORT_LOCATIONS = {
	{"School", CFrame.new(-147, 18, -148)},
	{"Hospital", CFrame.new(-78, 18, 93)},
	{"Airport", CFrame.new(453, 18, -256)},
	{"Bank", CFrame.new(-26, 18, -59)},
	{"Police Station", CFrame.new(-40, 18, -15)},
	{"Fire Station", CFrame.new(70, 18, 15)},
	{"Church", CFrame.new(-210, 18, -67)},
	{"Mall", CFrame.new(103, 18, -133)},
	{"Island", CFrame.new(600, 18, 200)},
	{"Agency", CFrame.new(-310, 18, -60)},
	{"Abandoned House", CFrame.new(-360, 18, -140)},
	{"Diner", CFrame.new(35, 18, -95)},
	{"Salon", CFrame.new(60, 18, -60)},
}

-- ===================== MOBILE / RESIZE DETECTION =====================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local ORIG_W = 580
local ORIG_H = 400
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
	local old = game:GetService("CoreGui"):FindFirstChild("SXBrookhaven")
	if old then old:Destroy() end
end)
pcall(function()
	local old = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("SXBrookhaven")
	if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SXBrookhaven"
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

local tabNames = {"Main", "Teleport", "Player", "Vehicle", "House", "Trolling", "Fun"}
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
titleLabel.Text = "BROOKHAVEN HUB"
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

-- ===================== ESP LOGIC =====================
local function addHighlight(player)
	if player == LocalPlayer then return end
	if highlights[player] then return end
	local character = player.Character
	if not character or not character.Parent then return end
	pcall(function()
		local highlight = Instance.new("Highlight")
		highlight.Name = "ESPHighlight"
		highlight.FillColor = HIGHLIGHT_COLOR
		highlight.OutlineColor = OUTLINE_COLOR
		highlight.FillTransparency = FILL_TRANSPARENCY
		highlight.OutlineTransparency = OUTLINE_TRANSPARENCY
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Adornee = character
		highlight.Parent = character
		highlights[player] = highlight
	end)
end

local function addNametag(player)
	if player == LocalPlayer then return end
	if nametags[player] then return end
	local character = player.Character
	if not character or not character.Parent then return end
	local head = character:FindFirstChild("Head")
	if not head then return end
	pcall(function()
		local bb = Instance.new("BillboardGui")
		bb.Name = "ESPNametag"
		bb.Adornee = head
		bb.Size = UDim2.new(0, 200, 0, 70)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.Parent = character

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 18)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = player.DisplayName
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 14
		nameLabel.Parent = bb

		local healthLabel = Instance.new("TextLabel")
		healthLabel.Size = UDim2.new(1, 0, 0, 14)
		healthLabel.Position = UDim2.new(0, 0, 0, 19)
		healthLabel.BackgroundTransparency = 1
		healthLabel.Text = "? / ?"
		healthLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		healthLabel.TextStrokeTransparency = 0.4
		healthLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		healthLabel.Font = Enum.Font.Gotham
		healthLabel.TextSize = 12
		healthLabel.Parent = bb

		local hpBg = Instance.new("Frame")
		hpBg.Size = UDim2.new(0.7, 0, 0, 6)
		hpBg.Position = UDim2.new(0.15, 0, 0, 36)
		hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		hpBg.BorderSizePixel = 0
		hpBg.Parent = bb
		Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

		local hpFill = Instance.new("Frame")
		hpFill.Size = UDim2.new(1, 0, 1, 0)
		hpFill.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
		hpFill.BorderSizePixel = 0
		hpFill.Parent = hpBg
		Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

		local distLabel = Instance.new("TextLabel")
		distLabel.Size = UDim2.new(1, 0, 0, 14)
		distLabel.Position = UDim2.new(0, 0, 0, 45)
		distLabel.BackgroundTransparency = 1
		distLabel.Text = "[?m]"
		distLabel.TextColor3 = Color3.fromRGB(170, 170, 255)
		distLabel.TextStrokeTransparency = 0.4
		distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		distLabel.Font = Enum.Font.Gotham
		distLabel.TextSize = 12
		distLabel.Parent = bb

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local function updateHealth()
				local hp = humanoid.Health
				local maxHp = humanoid.MaxHealth
				local pct = (maxHp > 0) and (hp / maxHp) or 0
				if pct < 0 then pct = 0 end
				if pct > 1 then pct = 1 end
				hpFill.Size = UDim2.new(pct, 0, 1, 0)
				healthLabel.Text = math.floor(hp) .. " / " .. math.floor(maxHp)
				if pct > 0.5 then
					hpFill.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
				elseif pct > 0.25 then
					hpFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
				else
					hpFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
				end
			end
			updateHealth()
			local conn = humanoid.HealthChanged:Connect(updateHealth)
			nametagConns[player] = nametagConns[player] or {}
			table.insert(nametagConns[player], conn)
		end

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
		nametagConns[player] = nametagConns[player] or {}
		table.insert(nametagConns[player], distConn)
		nametags[player] = bb
	end)
end

local function removeHighlight(player)
	local hl = highlights[player]
	if hl then pcall(function() hl:Destroy() end) end
	highlights[player] = nil
end

local function removeNametag(player)
	local tag = nametags[player]
	if tag then pcall(function() tag:Destroy() end) end
	nametags[player] = nil
	if nametagConns[player] then
		for _, conn in ipairs(nametagConns[player]) do pcall(function() conn:Disconnect() end) end
		nametagConns[player] = nil
	end
end

local function cleanupStale()
	local staleHL, staleNT = {}, {}
	for player, hl in pairs(highlights) do
		local alive = false
		pcall(function() if hl and hl.Adornee and hl.Adornee.Parent then alive = true end end)
		if not alive then table.insert(staleHL, player) end
	end
	for player, tag in pairs(nametags) do
		local alive = false
		pcall(function() if tag and tag.Parent then alive = true end end)
		if not alive then table.insert(staleNT, player) end
	end
	for _, player in ipairs(staleHL) do removeHighlight(player) end
	for _, player in ipairs(staleNT) do removeNametag(player) end
end

local function espScanAll()
	cleanupStale()
	local count, skipped = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			if character and character.Parent then
				if not highlights[player] then addHighlight(player) end
				if not nametags[player] then addNametag(player) end
				count = count + 1
			else
				skipped = skipped + 1
			end
		end
	end
	return count, skipped
end

local function hookPlayer(player)
	if player == LocalPlayer then return end
	local conn = player.CharacterAdded:Connect(function()
		if not espEnabled then return end
		_wait(1)
		if espEnabled then addHighlight(player) addNametag(player) end
	end)
	table.insert(espConnections, conn)
end

local function enableESP()
	for _, player in ipairs(Players:GetPlayers()) do hookPlayer(player) end
	local addedConn = Players.PlayerAdded:Connect(function(player)
		if not espEnabled then return end
		hookPlayer(player)
	end)
	table.insert(espConnections, addedConn)
	local count, skipped = espScanAll()
	addLog("[ESP] ON - " .. count .. " highlighted, " .. skipped .. " pending", COLORS.success)
	_spawn(function()
		while espEnabled do
			_wait(REFRESH_INTERVAL)
			if not espEnabled then break end
			espScanAll()
		end
	end)
end

local function disableESP()
	local allP = {}
	for player in pairs(highlights) do table.insert(allP, player) end
	for _, player in ipairs(allP) do removeHighlight(player) end
	local allN = {}
	for player in pairs(nametags) do table.insert(allN, player) end
	for _, player in ipairs(allN) do removeNametag(player) end
	for _, conn in ipairs(espConnections) do pcall(function() conn:Disconnect() end) end
	espConnections = {}
	addLog("[ESP] OFF", COLORS.error)
end

-- ===================== FLY LOGIC =====================
local function startFly()
	local character = LocalPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.P = 9e4
	bodyGyro.Parent = hrp
	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.Parent = hrp
	flyConnection = RunService.Heartbeat:Connect(function()
		if not flyEnabled or not hrp or not hrp.Parent then return end
		local cam = workspace.CurrentCamera
		local dir = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
		if dir.Magnitude > 0 then dir = dir.Unit end
		bodyVelocity.Velocity = dir * flySpeed
		bodyGyro.CFrame = cam.CFrame
	end)
	addLog("[FLY] ON - Speed: " .. flySpeed, COLORS.success)
end

local function stopFly()
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	if bodyGyro then pcall(function() bodyGyro:Destroy() end) bodyGyro = nil end
	if bodyVelocity then pcall(function() bodyVelocity:Destroy() end) bodyVelocity = nil end
	addLog("[FLY] OFF", COLORS.error)
end

-- ===================== NOCLIP LOGIC =====================
local function startNoclip()
	noclipConnection = RunService.Stepped:Connect(function()
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
	if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end)
	addLog("[NOCLIP] OFF", COLORS.error)
end

-- ===================== GET VEHICLE HELPER =====================
local function getVehicle()
	local char = LocalPlayer.Character
	if not char then return nil, nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or not hum.SeatPart then return nil, nil end
	local seat = hum.SeatPart
	local vehicle = seat.Parent
	if vehicle and vehicle:IsA("Model") then
		return vehicle, vehicle.PrimaryPart or seat
	end
	return nil, seat
end

-- ===================== CAR NOCLIP LOGIC =====================
local function startCarNoclip()
	carNoclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local vehicle, vPart = getVehicle()
			if not vehicle then return end
			local character = LocalPlayer.Character
			-- Vehicle parts
			for _, part in ipairs(vehicle:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
			-- Character parts
			if character then
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") then part.CanCollide = false end
				end
			end
		end)
	end)
	addLog("[CAR NOCLIP] ON - Drive through walls!", COLORS.success)
end

local function stopCarNoclip()
	if carNoclipConnection then carNoclipConnection:Disconnect() carNoclipConnection = nil end
	pcall(function()
		local vehicle, vPart = getVehicle()
		if vehicle then
			for _, part in ipairs(vehicle:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = true end
			end
		end
		local character = LocalPlayer.Character
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = true end
			end
		end
	end)
	addLog("[CAR NOCLIP] OFF", COLORS.error)
end

-- ===================== SPIN FLING LOGIC =====================
local function startFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Set density to 100 (super heavy = others get launched on contact)
		savedPhysProps = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				savedPhysProps[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
			end
		end

		-- Enable noclip so we can move freely while spinning
		if not noclipEnabled then noclipEnabled = true startNoclip() flingEnabledNoclip = true end
		wait(0.1)

		-- BodyAngularVelocity - spin on ALL axes for chaotic collision
		spinBAV = Instance.new("BodyAngularVelocity")
		spinBAV.AngularVelocity = Vector3.new(flingPower, flingPower, flingPower)
		spinBAV.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		spinBAV.P = math.huge
		spinBAV.Parent = root

		-- Disable collision on character parts
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end

		-- Heartbeat: random velocity perturbation to keep physics active
		flingConnection = RunService.Heartbeat:Connect(function()
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
		spawn(function()
			while flingEnabled do
				if spinBAV and spinBAV.Parent then
					spinBAV.AngularVelocity = Vector3.new(flingPower, flingPower, flingPower)
				end
				wait(0.15)
				if spinBAV and spinBAV.Parent then
					spinBAV.AngularVelocity = Vector3.new(0, 0, 0)
				end
				wait(0.05)
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
	if flingConnection then flingConnection:Disconnect() flingConnection = nil end

	-- Remove BodyAngularVelocity
	if spinBAV then pcall(function() spinBAV:Destroy() end) spinBAV = nil end

	-- Restore physics properties
	local character = LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				if savedPhysProps[part] then
					part.CustomPhysicalProperties = savedPhysProps[part]
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
	savedPhysProps = {}

	if flingEnabledNoclip then noclipEnabled = false stopNoclip() flingEnabledNoclip = false end

	addLog("[SPIN FLING] OFF", COLORS.error)
end

-- ===================== WALK FLING LOGIC =====================
local function startWalkFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Set density to 100
		walkFlingProps = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				walkFlingProps[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
			end
		end

		-- Enable noclip
		if not noclipEnabled then noclipEnabled = true startNoclip() flingEnabledNoclip = true end

		-- Velocity spike loop
		walkFlingThread = spawn(function()
			local frame = 0
			while walkFlingEnabled do
				RunService.Heartbeat:Wait()
				local char = LocalPlayer.Character
				local rt = char and char:FindFirstChild("HumanoidRootPart")
				if char and char.Parent and rt and rt.Parent then
					frame = frame + 1
					if frame % 2 == 1 then
						local vel = rt.Velocity
						rt.AssemblyLinearVelocity = vel * walkFlingPower + Vector3.new(0, walkFlingPower * 0.5, 0)
					else
						rt.AssemblyLinearVelocity = Vector3.new(
							math.random(-10, 10),
							math.random(-5, 5),
							math.random(-10, 10)
						)
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
	-- Restore physics
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					if walkFlingProps[part] then
						part.CustomPhysicalProperties = walkFlingProps[part]
					else
						part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
					end
					part.Velocity = Vector3.new(0, 0, 0)
					part.RotVelocity = Vector3.new(0, 0, 0)
				end
			end
		end
	end)
	walkFlingProps = {}

	if flingEnabledNoclip then noclipEnabled = false stopNoclip() flingEnabledNoclip = false end

	addLog("[WALK FLING] OFF", COLORS.error)
end

-- ===================== SPEED LOGIC =====================
local function startSpeed()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then origWalkSpeed = humanoid.WalkSpeed humanoid.WalkSpeed = speedValue end
		end
	end)
	addLog("[SPEED] ON - WalkSpeed: " .. speedValue, COLORS.success)
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

-- ===================== GOD MODE LOGIC =====================
local function startGod()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.MaxHealth = math.huge humanoid.Health = math.huge end
		end
	end)
	addLog("[GOD] ON", COLORS.success)
end

local function stopGod()
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
	infJumpConnection = UserInputService.JumpRequest:Connect(function()
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
	if infJumpConnection then infJumpConnection:Disconnect() infJumpConnection = nil end
	addLog("[INF JUMP] OFF", COLORS.error)
end

-- ===================== KILL AURA LOGIC =====================
local function startKillAura()
	killAuraConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local myHRP = character:FindFirstChild("HumanoidRootPart")
			if not myHRP then return end
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					local theirChar = player.Character
					if theirChar then
						local theirHRP = theirChar:FindFirstChild("HumanoidRootPart")
						if theirHRP and (myHRP.Position - theirHRP.Position).Magnitude <= 15 then
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
		end)
	end)
	addLog("[KILL AURA] ON - Range: 15 studs", COLORS.success)
end

local function stopKillAura()
	if killAuraConnection then killAuraConnection:Disconnect() killAuraConnection = nil end
	addLog("[KILL AURA] OFF", COLORS.error)
end

-- ===================== INVISIBLE LOGIC =====================
local savedTransparencies = {}

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

		savedTransparencies = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				savedTransparencies[part] = part.Transparency
				part.Transparency = 1
			elseif part:IsA("Decal") or part:IsA("Texture") then
				savedTransparencies[part] = part.Transparency
				part.Transparency = 1
			end
		end
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				if handle then savedTransparencies[handle] = handle.Transparency handle.Transparency = 1 end
			end
		end
	end)
	addLog("[INVISIBLE] ON (FE invisible)", COLORS.success)
end

local function stopInvisible()
	pcall(function()
		for part, transparency in pairs(savedTransparencies) do
			if part and part.Parent then part.Transparency = transparency end
		end
		savedTransparencies = {}
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

-- ===================== SPIN LOGIC =====================
local function startSpin()
	spinConnection = RunService.Heartbeat:Connect(function()
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
	if spinConnection then spinConnection:Disconnect() spinConnection = nil end
	addLog("[SPIN] OFF", COLORS.error)
end

-- ===================== SEIZURE LOGIC =====================
local function startSeizure()
	seizureConnection = RunService.Heartbeat:Connect(function()
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
	if seizureConnection then seizureConnection:Disconnect() seizureConnection = nil end
	addLog("[SEIZURE] OFF", COLORS.error)
end

-- ===================== RAINBOW CAR LOGIC =====================
local function startRainbowCar()
	rainbowCarConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local vehicle, vPart = getVehicle()
			if not vehicle then return end
			local hue = tick() % 5 / 5
			local color = Color3.fromHSV(hue, 1, 1)
			for _, part in ipairs(vehicle:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Color = color
				end
			end
		end)
	end)
	addLog("[RAINBOW CAR] ON", COLORS.success)
end

local function stopRainbowCar()
	if rainbowCarConnection then rainbowCarConnection:Disconnect() rainbowCarConnection = nil end
	addLog("[RAINBOW CAR] OFF", COLORS.error)
end

-- ===================== RAINBOW HOUSE LOGIC =====================
local function startRainbowHouse()
	rainbowHouseConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			-- Find the player's house/plot
			local plots = workspace:FindFirstChild("Plots") or workspace:FindFirstChild("Houses")
			if not plots then return end
			for _, plot in ipairs(plots:GetChildren()) do
				if plot:IsA("Model") and plot.Name:find(LocalPlayer.Name) then
					local hue = tick() % 5 / 5
					local color = Color3.fromHSV(hue, 1, 1)
					for _, part in ipairs(plot:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Color = color
						end
					end
				end
			end
		end)
	end)
	addLog("[RAINBOW HOUSE] ON", COLORS.success)
end

local function stopRainbowHouse()
	if rainbowHouseConnection then rainbowHouseConnection:Disconnect() rainbowHouseConnection = nil end
	addLog("[RAINBOW HOUSE] OFF", COLORS.error)
end

-- ===================== EMOTE LOGIC =====================
local function stopEmote()
	emoteActive = false
	if emoteConnection then emoteConnection:Disconnect() emoteConnection = nil end
	for _, track in ipairs(emoteTracks) do
		pcall(function() track:Stop() end)
	end
	emoteTracks = {}
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
		table.insert(emoteTracks, track)
		emoteActive = true
		if duration then
			task.delay(duration, function()
				if emoteActive then stopEmote() end
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
		emoteActive = true

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
			table.insert(emoteTracks, track1)
			table.insert(emoteTracks, track2)

			-- Loop by replaying when tracks finish
			emoteConnection = RunService.Heartbeat:Connect(function()
				if not emoteActive then return end
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
			table.insert(emoteTracks, track)

			emoteConnection = RunService.Heartbeat:Connect(function()
				if not emoteActive then return end
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

-- ===================== TELEPORT FUNCTIONS =====================
local function teleportTo(cf)
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then root.CFrame = cf end
	end)
end

local function teleportToPlayer(target)
	pcall(function()
		if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if myRoot then
				myRoot.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(3, 0, 0)
				addLog("[TP] Teleported to " .. target.DisplayName, COLORS.success)
			end
		end
	end)
end

-- ===================== CHARACTER SCALE =====================
local function setCharacterScale(scale)
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		-- R15 scaling
		local headScale = hum:FindFirstChild("HeadScale")
		local bodyDepth = hum:FindFirstChild("BodyDepthScale")
		local bodyWidth = hum:FindFirstChild("BodyWidthScale")
		local bodyHeight = hum:FindFirstChild("BodyHeightScale")
		if headScale then headScale.Value = scale end
		if bodyDepth then bodyDepth.Value = scale end
		if bodyWidth then bodyWidth.Value = scale end
		if bodyHeight then bodyHeight.Value = scale end
	end)
end

-- ===================== JUMP POWER / GRAVITY HELPERS =====================
local function setJumpPower(value)
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.UseJumpPower = true humanoid.JumpPower = value end
		end
	end)
end

local function setGravity(value)
	pcall(function() workspace.Gravity = value end)
end

-- =====================================================================
-- ======================== BUILD MAIN TAB ============================
-- =====================================================================
do
	local tab = tabFrames["Main"]

	createSectionLabel(tab, "Info", 1)
	createInfoLabel(tab, "Brookhaven RP Hub v1.0", 2)
	createInfoLabel(tab, "SX The Revival", 3)
	createInfoLabel(tab, "Player: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")", 4)


	createSectionLabel(tab, "Quick Toggles", 6)

	createToggle(tab, "ESP", 7, function(on)
		espEnabled = on
		if on then enableESP() else disableESP() end
	end)
	createToggle(tab, "Fly", 8, function(on)
		flyEnabled = on
		if on then startFly() else stopFly() end
	end)
	createToggle(tab, "Noclip", 9, function(on)
		noclipEnabled = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "God Mode", 10, function(on)
		godEnabled = on
		if on then startGod() else stopGod() end
	end)
	createToggle(tab, "Infinite Jump", 11, function(on)
		infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)


	createSectionLabel(tab, "Output Log", 13)

	createInfoLabel(tab, "Output goes to the F9 console.", 99)
end

-- =====================================================================
-- ======================== BUILD TELEPORT TAB ========================
-- =====================================================================
do
	local tab = tabFrames["Teleport"]

	createSectionLabel(tab, "Map Locations", 1)

	for i, loc in ipairs(TELEPORT_LOCATIONS) do
		createActionButton(tab, loc[1], i + 1, function()
			teleportTo(loc[2])
			addLog("[TP] Teleported to " .. loc[1], COLORS.success)
		end)
	end

	local spacerOrder = #TELEPORT_LOCATIONS + 3

	createSectionLabel(tab, "Players", spacerOrder + 1)

	-- Player name input + goto button row
	-- Input + button pair, replacing the hand-built row.
	local gotoName = ""
	createInput(tab, "Player Name", "Player name...", function(v) gotoName = v end)
	createActionButton(tab, "Goto Player", spacerOrder + 2, function()
		if gotoName == "" then addLog("[TP] Enter a player name", COLORS.error) return end
		local target = findPlayer(gotoName)
		if target then teleportToPlayer(target)
		else addLog("[TP] Player not found: " .. gotoName, COLORS.error) end
	end)


	createActionButton(tab, "Print My Position", spacerOrder + 4, function()
		pcall(function()
			local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local cf = root.CFrame
				local pos = string.format("CFrame.new(%.1f, %.1f, %.1f)", cf.X, cf.Y, cf.Z)
				addLog("[POS] " .. pos, COLORS.accent)
				print("[BROOKHAVEN POS] " .. pos)
			end
		end)
	end)
end

-- =====================================================================
-- ======================== BUILD PLAYER TAB ==========================
-- =====================================================================
do
	local tab = tabFrames["Player"]

	createSectionLabel(tab, "Movement", 1)

	createToggle(tab, "Speed Boost", 2, function(on)
		speedEnabled = on
		if on then startSpeed() else stopSpeed() end
	end)
	createSlider(tab, "Walk Speed", 16, 500, speedValue, 3, function(val)
		speedValue = val
		if speedEnabled then
			pcall(function()
				local character = LocalPlayer.Character
				if character then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then humanoid.WalkSpeed = val end
				end
			end)
		end
	end)
	createToggle(tab, "Fly", 4, function(on)
		flyEnabled = on
		if on then startFly() else stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 500, flySpeed, 5, function(val) flySpeed = val end)
	createToggle(tab, "Noclip", 6, function(on)
		noclipEnabled = on
		if on then startNoclip() else stopNoclip() end
	end)


	createSectionLabel(tab, "Jumping", 8)

	createToggle(tab, "Infinite Jump", 9, function(on)
		infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)
	createSlider(tab, "Jump Power", 10, 500, jumpPowerValue, 10, function(val)
		jumpPowerValue = val
		setJumpPower(val)
	end)


	createSectionLabel(tab, "Character", 12)

	createToggle(tab, "God Mode", 13, function(on)
		godEnabled = on
		if on then startGod() else stopGod() end
	end)
	createToggle(tab, "Invisible", 14, function(on)
		invisibleEnabled = on
		if on then startInvisible() else stopInvisible() end
	end)
	createSlider(tab, "Gravity", 0, 1000, math.floor(gravityValue), 15, function(val)
		gravityValue = val
		setGravity(val)
	end)
end

-- =====================================================================
-- ======================== BUILD VEHICLE TAB =========================
-- =====================================================================
do
	local tab = tabFrames["Vehicle"]

	createSectionLabel(tab, "Vehicle Features", 1)

	createToggle(tab, "Car Noclip", 2, function(on)
		carNoclipEnabled = on
		if on then startCarNoclip() else stopCarNoclip() end
	end)
	createToggle(tab, "Rainbow Car", 3, function(on)
		rainbowCarEnabled = on
		if on then startRainbowCar() else stopRainbowCar() end
	end)


	createSectionLabel(tab, "Info", 5)
	createInfoLabel(tab, "Sit in a vehicle before enabling", 6)
end

-- =====================================================================
-- ======================== BUILD HOUSE TAB ===========================
-- =====================================================================
do
	local tab = tabFrames["House"]

	createSectionLabel(tab, "House Features", 1)

	createToggle(tab, "Rainbow House", 2, function(on)
		rainbowHouseEnabled = on
		if on then startRainbowHouse() else stopRainbowHouse() end
	end)


	createSectionLabel(tab, "Info", 4)
	createInfoLabel(tab, "House features are experimental", 5)
end

-- =====================================================================
-- ======================== BUILD TROLLING TAB ========================
-- =====================================================================
do
	local tab = tabFrames["Trolling"]

	createSectionLabel(tab, "Fling", 1)

	local spinFlingToggle, walkFlingToggle
	spinFlingToggle = createToggle(tab, "Spin Fling", 2, function(on)
		flingEnabled = on
		if on then
			if walkFlingEnabled then walkFlingEnabled = false stopWalkFling() if walkFlingToggle then walkFlingToggle.setVisualState(false) end end
			startFling()
		else stopFling() end
	end)
	createSlider(tab, "Spin Fling Power", 1000, 99999, flingPower, 3, function(val) flingPower = val end)
	walkFlingToggle = createToggle(tab, "Walk Fling", 4, function(on)
		walkFlingEnabled = on
		if on then
			if flingEnabled then flingEnabled = false stopFling() if spinFlingToggle then spinFlingToggle.setVisualState(false) end end
			startWalkFling()
		else stopWalkFling() end
	end)
	createSlider(tab, "Walk Fling Power", 1000, 50000, walkFlingPower, 5, function(val) walkFlingPower = val end)


	createSectionLabel(tab, "Combat", 7)

	createToggle(tab, "Kill Aura", 8, function(on)
		killAuraEnabled = on
		if on then startKillAura() else stopKillAura() end
	end)


	createSectionLabel(tab, "Visual", 10)

	createToggle(tab, "Spin", 11, function(on)
		spinEnabled = on
		if on then startSpin() else stopSpin() end
	end)
	createToggle(tab, "Seizure", 12, function(on)
		seizureEnabled = on
		if on then startSeizure() else stopSeizure() end
	end)
end

-- =====================================================================
-- ======================== BUILD FUN TAB =============================
-- =====================================================================
do
	local tab = tabFrames["Fun"]

	createSectionLabel(tab, "Emotes", 1)

	createActionButton(tab, "Emote 1", 2, function()
		playJerkEmote()
	end)
	createActionButton(tab, "Dance", 3, function()
		playEmote(507771019, 1, 10)
		addLog("[EMOTE] Dance!", COLORS.success)
	end)
	createActionButton(tab, "Dab", 4, function()
		playEmote(183412246, 1, 3)
		addLog("[EMOTE] Dab!", COLORS.success)
	end)
	createActionButton(tab, "Crouch", 5, function()
		playEmote(182724289, 1, nil)
		addLog("[EMOTE] Crouch (;stopemote to stop)", COLORS.success)
	end)
	createActionButton(tab, "Stop Emote", 6, function()
		stopEmote()
		addLog("[EMOTE] Stopped", COLORS.error)
	end)


	createSectionLabel(tab, "Size", 8)

	createActionButton(tab, "Giant (3x)", 9, function()
		setCharacterScale(3)
		addLog("[SIZE] Giant mode!", COLORS.success)
	end)
	createActionButton(tab, "Tiny (0.5x)", 10, function()
		setCharacterScale(0.5)
		addLog("[SIZE] Tiny mode!", COLORS.success)
	end)
	createActionButton(tab, "Normal Size (1x)", 11, function()
		setCharacterScale(1)
		addLog("[SIZE] Normal size restored", COLORS.success)
	end)
end

-- =====================================================================
-- ======================== CHAT COMMANDS =============================
-- =====================================================================
local commands = {}

commands["fly"] = function() flyEnabled = true startFly() end
commands["unfly"] = function() flyEnabled = false stopFly() end
commands["noclip"] = function() noclipEnabled = true startNoclip() end
commands["unnoclip"] = function() noclipEnabled = false stopNoclip() end
commands["speed"] = function(args) local v = tonumber(args[1]) if v then speedValue = v end speedEnabled = true startSpeed() end
commands["unspeed"] = function() speedEnabled = false stopSpeed() end
commands["god"] = function() godEnabled = true startGod() end
commands["ungod"] = function() godEnabled = false stopGod() end
commands["invisible"] = function() invisibleEnabled = true startInvisible() end
commands["visible"] = function() invisibleEnabled = false stopInvisible() end
commands["tp"] = function(args)
	if not args[1] then addLog("[CMD] Usage: ;tp <player>", COLORS.error) return end
	local target = findPlayer(args[1])
	if target then teleportToPlayer(target) else addLog("[CMD] Player not found: " .. args[1], COLORS.error) end
end
commands["fling"] = function() if walkFlingEnabled then walkFlingEnabled = false stopWalkFling() end flingEnabled = true startFling() end
commands["unfling"] = function() flingEnabled = false stopFling() end
commands["walkfling"] = function() if flingEnabled then flingEnabled = false stopFling() end walkFlingEnabled = true startWalkFling() end
commands["unwalkfling"] = function() walkFlingEnabled = false stopWalkFling() end
commands["infjump"] = function() infJumpEnabled = true startInfJump() end
commands["uninfjump"] = function() infJumpEnabled = false stopInfJump() end
commands["killaura"] = function() killAuraEnabled = true startKillAura() end
commands["unkillaura"] = function() killAuraEnabled = false stopKillAura() end
commands["spin"] = function() spinEnabled = true startSpin() end
commands["unspin"] = function() spinEnabled = false stopSpin() end
commands["seizure"] = function() seizureEnabled = true startSeizure() end
commands["unseizure"] = function() seizureEnabled = false stopSeizure() end
commands["emote1"] = function() playJerkEmote() end
commands["dance"] = function() playEmote(507771019, 1, 10) addLog("[EMOTE] Dance!", COLORS.success) end
commands["dab"] = function() playEmote(183412246, 1, 3) addLog("[EMOTE] Dab!", COLORS.success) end
commands["crouch"] = function() playEmote(182724289, 1, nil) addLog("[EMOTE] Crouch", COLORS.success) end
commands["stopemote"] = function() stopEmote() addLog("[EMOTE] Stopped", COLORS.error) end
commands["esp"] = function() espEnabled = true enableESP() end
commands["unesp"] = function() espEnabled = false disableESP() end
commands["carnoclip"] = function() carNoclipEnabled = true startCarNoclip() end
commands["uncarnoclip"] = function() carNoclipEnabled = false stopCarNoclip() end
commands["rainbowcar"] = function() rainbowCarEnabled = true startRainbowCar() end
commands["unrainbowcar"] = function() rainbowCarEnabled = false stopRainbowCar() end
commands["rainbowhouse"] = function() rainbowHouseEnabled = true startRainbowHouse() end
commands["unrainbowhouse"] = function() rainbowHouseEnabled = false stopRainbowHouse() end
commands["pos"] = function()
	pcall(function()
		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local cf = root.CFrame
			local pos = string.format("CFrame.new(%.1f, %.1f, %.1f)", cf.X, cf.Y, cf.Z)
			addLog("[POS] " .. pos, COLORS.accent)
			print("[BROOKHAVEN POS] " .. pos)
		end
	end)
end
commands["goto"] = function(args)
	if not args[1] then addLog("[CMD] Usage: ;goto <location name>", COLORS.error) return end
	local search = table.concat(args, " "):lower()
	for _, loc in ipairs(TELEPORT_LOCATIONS) do
		if loc[1]:lower():find(search, 1, true) then
			teleportTo(loc[2])
			addLog("[TP] Teleported to " .. loc[1], COLORS.success)
			return
		end
	end
	addLog("[CMD] Location not found: " .. search, COLORS.error)
end
commands["giant"] = function() setCharacterScale(3) addLog("[SIZE] Giant!", COLORS.success) end
commands["tiny"] = function() setCharacterScale(0.5) addLog("[SIZE] Tiny!", COLORS.success) end
commands["normal"] = function() setCharacterScale(1) addLog("[SIZE] Normal!", COLORS.success) end
commands["jp"] = function(args)
	local v = tonumber(args[1])
	if v then jumpPowerValue = v setJumpPower(v) addLog("[CMD] Jump Power: " .. v, COLORS.success)
	else addLog("[CMD] Usage: ;jp <value>", COLORS.error) end
end
commands["gravity"] = function(args)
	local v = tonumber(args[1])
	if v then gravityValue = v setGravity(v) addLog("[CMD] Gravity: " .. v, COLORS.success)
	else addLog("[CMD] Usage: ;gravity <value>", COLORS.error) end
end
commands["cmds"] = function()
	addLog("--- Brookhaven RP Commands ---", COLORS.accent)
	addLog(";fly / ;unfly    ;noclip / ;unnoclip", COLORS.textSecondary)
	addLog(";speed [val] / ;unspeed", COLORS.textSecondary)
	addLog(";god / ;ungod    ;invisible / ;visible", COLORS.textSecondary)
	addLog(";tp <player>    ;goto <location>", COLORS.textSecondary)
	addLog(";fling / ;unfling (spin fling)", COLORS.textSecondary)
	addLog(";walkfling / ;unwalkfling", COLORS.textSecondary)
	addLog(";infjump / ;uninfjump", COLORS.textSecondary)
	addLog(";killaura / ;unkillaura", COLORS.textSecondary)
	addLog(";spin / ;unspin    ;seizure / ;unseizure", COLORS.textSecondary)
	addLog(";esp / ;unesp", COLORS.textSecondary)
	addLog(";carnoclip / ;uncarnoclip", COLORS.textSecondary)
	addLog(";rainbowcar / ;unrainbowcar", COLORS.textSecondary)
	addLog(";rainbowhouse / ;unrainbowhouse", COLORS.textSecondary)
	addLog(";emote1  ;dance  ;dab  ;crouch  ;stopemote", COLORS.textSecondary)
	addLog(";giant  ;tiny  ;normal (size)", COLORS.textSecondary)
	addLog(";jp <val>  ;gravity <val>  ;pos", COLORS.textSecondary)
	addLog(";cmds (this list)", COLORS.textSecondary)
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
	removeHighlight(player)
	removeNametag(player)
end)

LocalPlayer.CharacterAdded:Connect(function()
	if flyEnabled then
		stopFly() _wait(0.5)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then startFly() end
	end
	if flingEnabled then stopFling() _wait(0.5) startFling() end
	if walkFlingEnabled then stopWalkFling() _wait(0.5) startWalkFling() end
	spinBAV = nil
	savedPhysProps = {}
	if speedEnabled then _wait(0.3) startSpeed() end
	if godEnabled then _wait(0.3) startGod() end
	if jumpPowerValue ~= 50 then _wait(0.3) setJumpPower(jumpPowerValue) end
end)

-- ===================== STARTUP =====================
addLog("Brookhaven RP Hub v1.0", COLORS.accent)
addLog("Type ;cmds for command list", COLORS.textSecondary)
addLog("Use Right Shift to toggle GUI", COLORS.textSecondary)
print("[Brookhaven RP Hub] v1.0 loaded")
