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
if not keySystem or not keySystem.validate("prisonlife") then return end

-- ================================================================
-- Pebbleford Hub - Prison Life
-- Dedicated admin for Prison Life
-- v1.0
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

-- ===================== COLOR PALETTE (Red/Crimson Theme) =====================
local COLORS = {
	bg = Color3.fromRGB(20, 12, 12),
	bgSecondary = Color3.fromRGB(35, 18, 18),
	tabBg = Color3.fromRGB(55, 28, 28),
	accent = Color3.fromRGB(220, 50, 50),
	accentHover = Color3.fromRGB(240, 80, 80),
	accentDark = Color3.fromRGB(160, 30, 30),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(176, 176, 176),
	textDim = Color3.fromRGB(120, 120, 120),
	border = Color3.fromRGB(70, 35, 35),
	toggleOn = Color3.fromRGB(220, 50, 50),
	toggleOff = Color3.fromRGB(85, 85, 85),
	error = Color3.fromRGB(255, 68, 68),
	success = Color3.fromRGB(68, 255, 68),
	btnExecute = Color3.fromRGB(220, 50, 50),
	btnClear = Color3.fromRGB(60, 60, 60),
}

-- Team colors for ESP
local TEAM_COLORS = {
	["Bright orange"] = Color3.fromRGB(255, 165, 0),
	["Bright blue"] = Color3.fromRGB(0, 120, 255),
	["Medium stone grey"] = Color3.fromRGB(180, 180, 180),
}

-- ===================== STATE =====================
-- Main
local speedEnabled = false
local speedValue = 50
local flyEnabled = false
local noclipEnabled = false
local infJumpEnabled = false
local godEnabled = false
local invisibleEnabled = false
local antiAfkEnabled = false

-- Combat
local killAuraEnabled = false
local killAuraRadius = 20
local killAuraTeamCheck = true
local aimbotEnabled = false
local aimbotFOV = 200
local aimbotSmoothing = 2
local aimbotHolding = false
local triggerBotEnabled = false
local rapidFireEnabled = false
local noSpreadEnabled = false
local infiniteAmmoEnabled = false
local autoFireGunEnabled = false
local extendedRangeEnabled = false
local multiBulletEnabled = false
local instantReloadEnabled = false

-- ESP
local espEnabled = false
local itemEspEnabled = false
local xrayEnabled = false
local hitboxExpandEnabled = false
local hitboxSize = 10

-- Teleport
local selectedPlayer = nil

-- Fun
local flingEnabled = false
local walkFlingEnabled = false
local seizureEnabled = false
local headlessEnabled = false
local gravityValue = 196

-- Connections
local speedConnection = nil
local flyConnection = nil
local noclipConnection = nil
local infJumpConnection = nil
local godConnection = nil
local antiAfkConnection = nil
local killAuraConnection = nil
local aimbotConnection = nil
local aimbotInputBeganConn = nil
local aimbotInputEndedConn = nil
local triggerBotConnection = nil
local espHighlights = {}
local itemEspHighlights = {}
local xraySaved = {}
local hitboxSaved = {}
local flingConnection = nil
local walkFlingConnection = nil
local seizureConnection = nil
local headlessSaved = {}
local flingPower = 300
local walkFlingPower = 150
local flingEnabledNoclip = false

-- FOV circle
local fovCircle = nil

-- Log
local logEntries = {}
local logFrame = nil

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PebblefordPrisonLife"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

local function getTeamColor(player)
	if player and player.Team then
		return player.Team.TeamColor.Name
	end
	return nil
end

-- ===================== LOG SYSTEM =====================
local function addLog(text, color)
	table.insert(logEntries, {text = text, color = color or COLORS.textSecondary, time = tick()})
	if #logEntries > 100 then table.remove(logEntries, 1) end
	if logFrame then
		pcall(function()
			local logLabel = Instance.new("TextLabel")
			logLabel.Size = UDim2.new(1, 0, 0, 16)
			logLabel.BackgroundTransparency = 1
			logLabel.Text = text
			logLabel.TextColor3 = color or COLORS.textSecondary
			logLabel.Font = Enum.Font.Code
			logLabel.TextSize = 10
			logLabel.TextXAlignment = Enum.TextXAlignment.Left
			logLabel.TextWrapped = true
			logLabel.LayoutOrder = #logEntries
			logLabel.Parent = logFrame
			logFrame.CanvasPosition = Vector2.new(0, logFrame.AbsoluteCanvasSize.Y)
		end)
	end
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

local tabNames = {"Main", "Combat", "ESP", "Teleport", "Fun"}
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
titleLabel.Text = "PRISON LIFE HUB"
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


-- ===================== FEATURE FUNCTIONS =====================

-- Speed
local function startSpeed()
	speedConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.WalkSpeed = speedValue end
		end)
	end)
	addLog("[SPEED] ON (" .. speedValue .. ")", COLORS.success)
end

local function stopSpeed()
	if speedConnection then speedConnection:Disconnect() speedConnection = nil end
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.WalkSpeed = 16 end
		end
	end)
	addLog("[SPEED] OFF", COLORS.error)
end

-- Fly
local function startFly()
	local flySpeed = 60
	flyConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not hrp or not humanoid then return end

			local moveDir = humanoid.MoveDirection
			local camCF = Camera.CFrame

			local velocity = Vector3.new(0, 0, 0)
			if moveDir.Magnitude > 0 then
				velocity = velocity + camCF.LookVector * moveDir.Z * flySpeed + camCF.RightVector * moveDir.X * flySpeed
				if velocity.Magnitude < 1 then
					velocity = moveDir * flySpeed
				end
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				velocity = velocity + Vector3.new(0, flySpeed, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				velocity = velocity - Vector3.new(0, flySpeed, 0)
			end

			hrp.Velocity = velocity
		end)
	end)
	addLog("[FLY] ON", COLORS.success)
end

local function stopFly()
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	addLog("[FLY] OFF", COLORS.error)
end

-- Noclip
local function startNoclip()
	noclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
	end)
	addLog("[NOCLIP] ON", COLORS.success)
end

local function stopNoclip()
	if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
	addLog("[NOCLIP] OFF", COLORS.error)
end

-- Infinite Jump
local function startInfJump()
	infJumpConnection = UserInputService.JumpRequest:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end)
	addLog("[INF JUMP] ON", COLORS.success)
end

local function stopInfJump()
	if infJumpConnection then infJumpConnection:Disconnect() infJumpConnection = nil end
	addLog("[INF JUMP] OFF", COLORS.error)
end

-- God Mode (Heartbeat loop)
local function startGod()
	godConnection = RunService.Heartbeat:Connect(function()
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
	if godConnection then godConnection:Disconnect() godConnection = nil end
	addLog("[GOD] OFF", COLORS.error)
end

-- FE Invisible (Seat Trick)
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

		-- Client-side transparency
		if savedChar then
			for _, part in ipairs(savedChar:GetDescendants()) do
				pcall(function()
					if part:IsA("BasePart") then
						part.Transparency = 1
					elseif part:IsA("Decal") or part:IsA("Texture") then
						part.Transparency = 1
					end
				end)
			end
		end
		addLog("[INVISIBLE] ON (FE seat trick - respawn to undo)", COLORS.success)
	end)
end

local function stopInvisible()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.Health = 0 end
		end
	end)
	addLog("[INVISIBLE] OFF (respawning)", COLORS.error)
end

-- Anti-AFK
local function startAntiAfk()
	antiAfkConnection = LocalPlayer.Idled:Connect(function()
		pcall(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end)
	addLog("[ANTI-AFK] ON", COLORS.success)
end

local function stopAntiAfk()
	if antiAfkConnection then antiAfkConnection:Disconnect() antiAfkConnection = nil end
	addLog("[ANTI-AFK] OFF", COLORS.error)
end

-- ===================== PRISON LIFE SPECIFIC FUNCTIONS =====================

-- Switch Team
local function switchTeam(teamColor)
	pcall(function()
		workspace.Remote.TeamEvent:FireServer(teamColor)
		_wait(0.3)
		workspace.Remote.loadchar:InvokeServer(LocalPlayer, teamColor)
	end)
	addLog("[TEAM] Switched to " .. teamColor, COLORS.success)
end

-- Get All Guns
local function getAllGuns()
	pcall(function()
		local count = 0
		for _, v in ipairs(workspace.Prison_ITEMS.giver:GetChildren()) do
			pcall(function()
				if v:FindFirstChild("ITEMPICKUP") then
					workspace.Remote.ItemHandler:InvokeServer(v.ITEMPICKUP)
					count = count + 1
				end
			end)
		end
		addLog("[GUNS] Grabbed " .. count .. " items", COLORS.success)
	end)
end

-- Get Keycard
local function getKeycard()
	pcall(function()
		-- Keycard is in Prison_ITEMS.single, not giver
		local singles = workspace:FindFirstChild("Prison_ITEMS")
		if singles then
			local single = singles:FindFirstChild("single")
			if single then
				for _, v in ipairs(single:GetChildren()) do
					if v.Name:lower():find("key") then
						pcall(function()
							if v:FindFirstChild("ITEMPICKUP") then
								workspace.Remote.ItemHandler:InvokeServer(v.ITEMPICKUP)
								addLog("[KEYCARD] Grabbed keycard!", COLORS.success)
							end
						end)
					end
				end
			end
			-- Also check giver folder as fallback
			local giver = singles:FindFirstChild("giver")
			if giver then
				for _, v in ipairs(giver:GetChildren()) do
					if v.Name:lower():find("key") then
						pcall(function()
							if v:FindFirstChild("ITEMPICKUP") then
								workspace.Remote.ItemHandler:InvokeServer(v.ITEMPICKUP)
								addLog("[KEYCARD] Grabbed keycard!", COLORS.success)
							end
						end)
					end
				end
			end
		end
	end)
end

-- Kill All (melee event)
local function killAll()
	pcall(function()
		local count = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				for i = 1, 20 do
					pcall(function()
						ReplicatedStorage.meleeEvent:FireServer(player)
					end)
				end
				count = count + 1
			end
		end
		addLog("[KILL ALL] Fired on " .. count .. " players", COLORS.success)
	end)
end

-- Kill Aura
local function startKillAura()
	killAuraConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end

			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					if not (killAuraTeamCheck and player.Team == LocalPlayer.Team and LocalPlayer.Team ~= nil) then
						local otherHrp = player.Character:FindFirstChild("HumanoidRootPart")
						if otherHrp then
							local dist = (otherHrp.Position - hrp.Position).Magnitude
							if dist <= killAuraRadius then
								pcall(function()
									ReplicatedStorage.meleeEvent:FireServer(player)
								end)
							end
						end
					end
				end
			end
		end)
	end)
	addLog("[KILL AURA] ON (radius: " .. killAuraRadius .. ")", COLORS.success)
end

local function stopKillAura()
	if killAuraConnection then killAuraConnection:Disconnect() killAuraConnection = nil end
	addLog("[KILL AURA] OFF", COLORS.error)
end

-- Gun Mods
local function applyGunMods()
	pcall(function()
		local count = 0
		local function modGun(tool)
			pcall(function()
				local module = tool:FindFirstChildWhichIsA("ModuleScript")
				if module then
					local stat = require(module)
					if rapidFireEnabled then
						if stat.FireRate then stat.FireRate = 0.01 end
					end
					if noSpreadEnabled then
						if stat.Spread then stat.Spread = 0 end
					end
					if infiniteAmmoEnabled then
						if stat.MaxAmmo then stat.MaxAmmo = 9999 end
						if stat.StoredAmmo then stat.StoredAmmo = 9999 end
						if stat.CurrentAmmo then stat.CurrentAmmo = 9999 end
						if stat.AmmoPerClip then stat.AmmoPerClip = 9999 end
					end
					if autoFireGunEnabled then
						if stat.AutoFire ~= nil then stat.AutoFire = true end
					end
					if extendedRangeEnabled then
						if stat.Range then stat.Range = 9999 end
					end
					if multiBulletEnabled then
						if stat.Bullets then stat.Bullets = 10 end
					end
					if instantReloadEnabled then
						if stat.ReloadTime then stat.ReloadTime = 0 end
					end
					count = count + 1
				end
			end)
		end

		local character = LocalPlayer.Character
		if character then
			for _, tool in ipairs(character:GetChildren()) do
				if tool:IsA("Tool") then modGun(tool) end
			end
		end
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if backpack then
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then modGun(tool) end
			end
		end
		addLog("[GUN MODS] Applied to " .. count .. " guns", COLORS.success)
	end)
end

local function applyAllGunMods()
	rapidFireEnabled = true
	noSpreadEnabled = true
	infiniteAmmoEnabled = true
	autoFireGunEnabled = true
	extendedRangeEnabled = true
	multiBulletEnabled = true
	instantReloadEnabled = true
	applyGunMods()
	addLog("[GUN MODS] ALL mods enabled and applied!", COLORS.success)
end

-- Aimbot
local function startAimbot()
	-- FOV circle
	if not fovCircle then
		fovCircle = Drawing and Drawing.new("Circle") or nil
	end
	if fovCircle then
		fovCircle.Color = COLORS.accent
		fovCircle.Thickness = 1
		fovCircle.Filled = false
		fovCircle.Transparency = 0.7
		fovCircle.Radius = aimbotFOV
		fovCircle.Visible = true
	end

	aimbotInputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			aimbotHolding = true
		end
	end)

	aimbotInputEndedConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			aimbotHolding = false
		end
	end)

	aimbotConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if fovCircle then
				local mouse = UserInputService:GetMouseLocation()
				fovCircle.Position = mouse
				fovCircle.Radius = aimbotFOV
			end

			if not aimbotHolding then return end

			local closest = nil
			local closestDist = aimbotFOV

			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					if not (killAuraTeamCheck and player.Team == LocalPlayer.Team and LocalPlayer.Team ~= nil) then
						local head = player.Character:FindFirstChild("Head")
						if head then
							local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
							if onScreen then
								local mouse = UserInputService:GetMouseLocation()
								local dist = (Vector2.new(screenPos.X, screenPos.Y) - mouse).Magnitude
								if dist < closestDist then
									closest = head
									closestDist = dist
								end
							end
						end
					end
				end
			end

			if closest then
				local screenPos = Camera:WorldToViewportPoint(closest.Position)
				local mouse = UserInputService:GetMouseLocation()
				local delta = Vector2.new(screenPos.X - mouse.X, screenPos.Y - mouse.Y)

				local sensitivity = 1.5
				local moveX = (delta.X / aimbotSmoothing) * sensitivity
				local moveY = (delta.Y / aimbotSmoothing) * sensitivity

				if math.abs(moveX) < 1 and math.abs(delta.X) > 1 then
					moveX = delta.X > 0 and 1 or -1
				end
				if math.abs(moveY) < 1 and math.abs(delta.Y) > 1 then
					moveY = delta.Y > 0 and 1 or -1
				end

				mousemoverel(moveX, moveY)
			end
		end)
	end)
	addLog("[AIMBOT] ON (RMB to aim)", COLORS.success)
end

local function stopAimbot()
	if aimbotConnection then aimbotConnection:Disconnect() aimbotConnection = nil end
	if aimbotInputBeganConn then aimbotInputBeganConn:Disconnect() aimbotInputBeganConn = nil end
	if aimbotInputEndedConn then aimbotInputEndedConn:Disconnect() aimbotInputEndedConn = nil end
	if fovCircle then fovCircle.Visible = false end
	addLog("[AIMBOT] OFF", COLORS.error)
end

-- Triggerbot
local function startTriggerBot()
	triggerBotConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local mouse = LocalPlayer:GetMouse()
			if mouse.Target and mouse.Target.Parent then
				local target = Players:GetPlayerFromCharacter(mouse.Target.Parent)
				if not target then
					target = Players:GetPlayerFromCharacter(mouse.Target.Parent.Parent)
				end
				if target and target ~= LocalPlayer then
					if killAuraTeamCheck and target.Team == LocalPlayer.Team and LocalPlayer.Team ~= nil then
						return
					end
					mouse1click()
				end
			end
		end)
	end)
	addLog("[TRIGGERBOT] ON", COLORS.success)
end

local function stopTriggerBot()
	if triggerBotConnection then triggerBotConnection:Disconnect() triggerBotConnection = nil end
	addLog("[TRIGGERBOT] OFF", COLORS.error)
end

-- Player ESP
local function clearESP()
	for _, h in pairs(espHighlights) do pcall(function() h:Destroy() end) end
	espHighlights = {}
end

local function updateESP()
	clearESP()
	if not espEnabled then return end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			pcall(function()
				local teamColor = getTeamColor(player)
				local highlightColor = TEAM_COLORS[teamColor] or Color3.fromRGB(255, 255, 255)

				local hl = Instance.new("Highlight")
				hl.FillColor = highlightColor
				hl.FillTransparency = 0.5
				hl.OutlineColor = highlightColor
				hl.OutlineTransparency = 0
				hl.Adornee = player.Character
				hl.Parent = player.Character
				table.insert(espHighlights, hl)
			end)
		end
	end
end

local espUpdateThread = nil
local function startESP()
	espUpdateThread = _spawn(function()
		while espEnabled do
			updateESP()
			_wait(3)
		end
	end)
	addLog("[ESP] ON (team colors)", COLORS.success)
end

local function stopESP()
	clearESP()
	addLog("[ESP] OFF", COLORS.error)
end

-- Item ESP
local function clearItemESP()
	for _, h in pairs(itemEspHighlights) do pcall(function() h:Destroy() end) end
	itemEspHighlights = {}
end

local function updateItemESP()
	clearItemESP()
	if not itemEspEnabled then return end
	pcall(function()
		for _, item in ipairs(workspace.Prison_ITEMS.giver:GetChildren()) do
			pcall(function()
				local part = item:FindFirstChildWhichIsA("BasePart") or item:FindFirstChild("ITEMPICKUP")
				if part then
					local hl = Instance.new("Highlight")
					hl.FillColor = Color3.fromRGB(255, 255, 0)
					hl.FillTransparency = 0.5
					hl.OutlineColor = Color3.fromRGB(255, 255, 0)
					hl.OutlineTransparency = 0
					hl.Adornee = item
					hl.Parent = item
					table.insert(itemEspHighlights, hl)
				end
			end)
		end
	end)
end

local function startItemESP()
	_spawn(function()
		while itemEspEnabled do
			updateItemESP()
			_wait(5)
		end
	end)
	addLog("[ITEM ESP] ON", COLORS.success)
end

local function stopItemESP()
	clearItemESP()
	addLog("[ITEM ESP] OFF", COLORS.error)
end

-- X-Ray
local function startXRay()
	pcall(function()
		for _, part in ipairs(workspace:GetDescendants()) do
			pcall(function()
				if part:IsA("BasePart") and not part:IsDescendantOf(LocalPlayer.Character or Instance.new("Folder")) then
					local player = Players:GetPlayerFromCharacter(part.Parent) or Players:GetPlayerFromCharacter(part.Parent and part.Parent.Parent)
					if not player and part.Transparency < 0.5 then
						xraySaved[part] = part.Transparency
						part.Transparency = 0.7
					end
				end
			end)
		end
	end)
	addLog("[X-RAY] ON", COLORS.success)
end

local function stopXRay()
	for part, trans in pairs(xraySaved) do
		pcall(function() part.Transparency = trans end)
	end
	xraySaved = {}
	addLog("[X-RAY] OFF", COLORS.error)
end

-- Hitbox Expander
local function startHitbox()
	pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				pcall(function()
					local hrp = player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						hitboxSaved[hrp] = hrp.Size
						hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
						hrp.Transparency = 0.7
						hrp.CanCollide = false
					end
				end)
			end
		end
	end)
	addLog("[HITBOX] ON (size: " .. hitboxSize .. ")", COLORS.success)
end

local function stopHitbox()
	for hrp, size in pairs(hitboxSaved) do
		pcall(function()
			hrp.Size = size
			hrp.Transparency = 1
		end)
	end
	hitboxSaved = {}
	addLog("[HITBOX] OFF", COLORS.error)
end

-- Spin Fling (Assembly properties)
local function startFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		if not noclipEnabled then noclipEnabled = true flingEnabledNoclip = true startNoclip() end
		_wait(0.1)

		flingConnection = RunService.Heartbeat:Connect(function()
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end
				local rt = char:FindFirstChild("HumanoidRootPart")
				if not rt then return end

				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
						part.CanCollide = false
					end
				end

				rt.AssemblyAngularVelocity = Vector3.new(
					math.random(-1, 1) * flingPower,
					math.random(-1, 1) * flingPower,
					math.random(-1, 1) * flingPower
				)
				rt.AssemblyLinearVelocity = rt.AssemblyLinearVelocity + Vector3.new(
					math.random(-80, 80), 0, math.random(-80, 80)
				)
			end)
		end)
		addLog("[SPIN FLING] ON - Walk into players!", COLORS.success)
	end)
	if not ok then addLog("[SPIN FLING] Error: " .. tostring(err), COLORS.error) end
end

local function stopFling()
	if flingConnection then flingConnection:Disconnect() flingConnection = nil end
	if flingEnabledNoclip then
		flingEnabledNoclip = false
		noclipEnabled = false
		stopNoclip()
	end
	local character = LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
				part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end
		end
	end
	addLog("[SPIN FLING] OFF", COLORS.error)
end

-- Walk Fling (Assembly properties)
local function startWalkFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end

		walkFlingConnection = RunService.Heartbeat:Connect(function()
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end
				local rt = char:FindFirstChild("HumanoidRootPart")
				if not rt then return end
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hum then return end

				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
					end
				end

				local moveDir = hum.MoveDirection
				if moveDir.Magnitude > 0.1 then
					rt.AssemblyLinearVelocity = moveDir.Unit * walkFlingPower
				end
			end)
		end)
		addLog("[WALK FLING] ON - Walk into players!", COLORS.success)
	end)
	if not ok then addLog("[WALK FLING] Error: " .. tostring(err), COLORS.error) end
end

local function stopWalkFling()
	if walkFlingConnection then walkFlingConnection:Disconnect() walkFlingConnection = nil end
	local character = LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
				part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end
		end
	end
	addLog("[WALK FLING] OFF", COLORS.error)
end

-- Seizure
local function startSeizure()
	seizureConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
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

-- Headless
local function startHeadless()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		headlessSaved = {}
		local head = character:FindFirstChild("Head")
		if head then
			for _, child in ipairs(head:GetChildren()) do
				if child:IsA("SpecialMesh") then
					headlessSaved[child] = {Scale = child.Scale}
					child.Scale = Vector3.new(0, 0, 0)
				elseif child:IsA("Decal") then
					headlessSaved[child] = {Transparency = child.Transparency}
					child.Transparency = 1
				end
			end
			headlessSaved[head] = {Transparency = head.Transparency}
			head.Transparency = 1
		end
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				if handle then
					headlessSaved[handle] = {Transparency = handle.Transparency}
					handle.Transparency = 1
				end
			end
		end
		addLog("[HEADLESS] ON", COLORS.success)
	end)
end

local function stopHeadless()
	for obj, props in pairs(headlessSaved) do
		pcall(function()
			for k, v in pairs(props) do
				obj[k] = v
			end
		end)
	end
	headlessSaved = {}
	addLog("[HEADLESS] OFF", COLORS.error)
end

-- Door Remover
local function removeDoors()
	local count = 0
	-- Prison Life stores doors in workspace.Doors
	pcall(function()
		if workspace:FindFirstChild("Doors") then
			local children = workspace.Doors:GetChildren()
			count = count + #children
			workspace.Doors:Destroy()
		end
	end)
	-- Also destroy cell block doors
	pcall(function()
		if workspace:FindFirstChild("Prison_Cellblock") then
			local doors = workspace.Prison_Cellblock:FindFirstChild("doors")
			if doors then
				local children = doors:GetChildren()
				count = count + #children
				doors:Destroy()
			end
		end
	end)
	-- Destroy prison fences
	pcall(function()
		if workspace:FindFirstChild("Prison_Fences") then
			local children = workspace.Prison_Fences:GetChildren()
			count = count + #children
			workspace.Prison_Fences:Destroy()
		end
	end)
	addLog("[DOORS] Removed " .. count .. " door/fence objects", COLORS.success)
end

-- Teleport to location
local function teleportTo(cf)
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.CFrame = cf end
	end)
end

-- ===================== BUILD MAIN TAB =====================
do
	local tab = tabFrames["Main"]

	createSectionLabel(tab, "Prison Life Actions", 1)
	createActionButton(tab, "Switch to Guard", 2, function() switchTeam("Bright blue") end)
	createActionButton(tab, "Switch to Inmate", 3, function() switchTeam("Bright orange") end)
	createActionButton(tab, "Switch to Criminal", 4, function() switchTeam("Medium stone grey") end)
	createActionButton(tab, "Get All Guns", 5, function() getAllGuns() end)
	createActionButton(tab, "Get Keycard", 6, function() getKeycard() end)
	createActionButton(tab, "Arrest All (as Guard)", 7, function()
		pcall(function()
			local count = 0
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					pcall(function()
						local hrp = player.Character:FindFirstChild("HumanoidRootPart")
						if hrp then
							workspace.Remote.arrest:InvokeServer(hrp)
							count = count + 1
						end
					end)
				end
			end
			addLog("[ARREST] Arrested " .. count .. " players", COLORS.success)
		end)
	end)

	createSectionLabel(tab, "Movement", 10)
	createToggle(tab, "Speed", 11, function(on)
		speedEnabled = on
		if on then startSpeed() else stopSpeed() end
	end)
	createSlider(tab, "Speed Value", 16, 200, speedValue, 12, function(val) speedValue = val end)
	createToggle(tab, "Fly", 13, function(on)
		flyEnabled = on
		if on then startFly() else stopFly() end
	end)
	createToggle(tab, "Noclip", 14, function(on)
		noclipEnabled = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "Infinite Jump", 15, function(on)
		infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)

	createSectionLabel(tab, "Protection", 20)
	createToggle(tab, "God Mode", 21, function(on)
		godEnabled = on
		if on then startGod() else stopGod() end
	end)
	createToggle(tab, "FE Invisible", 22, function(on)
		invisibleEnabled = on
		if on then startInvisible() else stopInvisible() end
	end)
	createInfoLabel(tab, "Invisible uses seat trick - respawn to undo", 23)
	createToggle(tab, "Anti-AFK", 24, function(on)
		antiAfkEnabled = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)
end

-- ===================== BUILD COMBAT TAB =====================
do
	local tab = tabFrames["Combat"]

	createSectionLabel(tab, "Melee Exploits", 1)
	createActionButton(tab, "Kill All (meleeEvent)", 2, function() killAll() end)
	createInfoLabel(tab, "Fires meleeEvent on all players 20x each", 3)

	createToggle(tab, "Kill Aura", 4, function(on)
		killAuraEnabled = on
		if on then startKillAura() else stopKillAura() end
	end)
	createSlider(tab, "Kill Aura Radius", 10, 50, killAuraRadius, 5, function(val) killAuraRadius = val end)
	createToggle(tab, "Team Check", 6, function(on) killAuraTeamCheck = on end, true)

	createSectionLabel(tab, "Gun Mods", 10)
	createInfoLabel(tab, "Equip a gun then toggle mods", 11)
	createToggle(tab, "Rapid Fire", 12, function(on) rapidFireEnabled = on applyGunMods() end)
	createToggle(tab, "No Spread", 13, function(on) noSpreadEnabled = on applyGunMods() end)
	createToggle(tab, "Infinite Ammo", 14, function(on) infiniteAmmoEnabled = on applyGunMods() end)
	createToggle(tab, "Auto Fire", 15, function(on) autoFireGunEnabled = on applyGunMods() end)
	createToggle(tab, "Extended Range", 16, function(on) extendedRangeEnabled = on applyGunMods() end)
	createToggle(tab, "Multi Bullet (10x)", 17, function(on) multiBulletEnabled = on applyGunMods() end)
	createToggle(tab, "Instant Reload", 18, function(on) instantReloadEnabled = on applyGunMods() end)
	createActionButton(tab, "Apply ALL Gun Mods", 19, function() applyAllGunMods() end)

	createSectionLabel(tab, "Aim Assist", 20)
	createToggle(tab, "Aimbot (Hold RMB)", 21, function(on)
		aimbotEnabled = on
		if on then startAimbot() else stopAimbot() end
	end)
	createSlider(tab, "Aimbot FOV", 50, 500, aimbotFOV, 22, function(val) aimbotFOV = val end)
	createSlider(tab, "Aimbot Smoothing", 1, 10, aimbotSmoothing, 23, function(val) aimbotSmoothing = val end)
	createToggle(tab, "Triggerbot", 24, function(on)
		triggerBotEnabled = on
		if on then startTriggerBot() else stopTriggerBot() end
	end)
end

-- ===================== BUILD ESP TAB =====================
do
	local tab = tabFrames["ESP"]

	createSectionLabel(tab, "Player ESP", 1)
	createToggle(tab, "Player ESP (Team Colors)", 2, function(on)
		espEnabled = on
		if on then startESP() else stopESP() end
	end)
	createInfoLabel(tab, "Orange=Inmate, Blue=Guard, Grey=Criminal", 3)

	createSectionLabel(tab, "Item ESP", 5)
	createToggle(tab, "Item ESP", 6, function(on)
		itemEspEnabled = on
		if on then startItemESP() else stopItemESP() end
	end)

	createSectionLabel(tab, "Vision", 10)
	createToggle(tab, "X-Ray (See Through Walls)", 11, function(on)
		xrayEnabled = on
		if on then startXRay() else stopXRay() end
	end)

	createSectionLabel(tab, "Hitbox", 15)
	createToggle(tab, "Hitbox Expander", 16, function(on)
		hitboxExpandEnabled = on
		if on then startHitbox() else stopHitbox() end
	end)
	createSlider(tab, "Hitbox Size", 5, 20, hitboxSize, 17, function(val) hitboxSize = val end)
end

-- ===================== BUILD TELEPORT TAB =====================
do
	local tab = tabFrames["Teleport"]

	createSectionLabel(tab, "Location Teleports", 1)
	createActionButton(tab, "Criminal Base", 2, function()
		teleportTo(CFrame.new(-943.704, 91.632, 2056.925))
		addLog("[TP] Criminal Base", COLORS.success)
	end)
	createActionButton(tab, "Yard", 3, function()
		teleportTo(CFrame.new(779.092, 96.001, 2451.114))
		addLog("[TP] Yard", COLORS.success)
	end)
	createActionButton(tab, "Cafeteria", 4, function()
		teleportTo(CFrame.new(930, 97.54, 2291))
		addLog("[TP] Cafeteria", COLORS.success)
	end)
	createActionButton(tab, "Guard Armory", 5, function()
		teleportTo(CFrame.new(821.793, 98.200, 2280.899))
		addLog("[TP] Guard Armory", COLORS.success)
	end)
	createActionButton(tab, "Cells", 6, function()
		teleportTo(CFrame.new(918, 97.73, 2447))
		addLog("[TP] Cells", COLORS.success)
	end)
	createActionButton(tab, "Outside Prison", 7, function()
		teleportTo(CFrame.new(288.452, 69.999, 2206.731))
		addLog("[TP] Outside Prison", COLORS.success)
	end)
	createActionButton(tab, "Sewer Entrance", 8, function()
		teleportTo(CFrame.new(917.174, 76.406, 2426.199))
		addLog("[TP] Sewer Entrance", COLORS.success)
	end)
	createActionButton(tab, "Secret Room", 9, function()
		teleportTo(CFrame.new(697, 97.492, 2364))
		addLog("[TP] Secret Room", COLORS.success)
	end)

	createSectionLabel(tab, "Player Teleport", 20)
	createInfoLabel(tab, "Click a player to select, then Teleport/Spectate", 21)

	local plPlayers, plDropdown = {}, nil
	local function refreshPlayerList()
		plPlayers = {}
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local label = player.DisplayName .. " (@" .. player.Name .. ")"
				plPlayers[label] = player
				table.insert(names, label)
			end
		end
		if #names == 0 then names = {"(no players)"} end
		if plDropdown then pcall(function() plDropdown:SetValues(names) end) end
	end
	plDropdown = createDropdown(tab, "Select Player", {"(refresh first)"}, "(refresh first)", function(choice)
		local player = plPlayers[choice]
		if not player then return end
		selectedPlayer = player
		selectedLabel.Text = "Selected: " .. player.DisplayName
	end)
	refreshPlayerList()
	Players.PlayerAdded:Connect(function() _wait(1) refreshPlayerList() end)
	Players.PlayerRemoving:Connect(function(player)
		if selectedPlayer == player then
			selectedPlayer = nil
			selectedLabel.Text = "Selected: None"
		end
		_wait(0.5)
		refreshPlayerList()
	end)

	createActionButton(tab, "Teleport to Player", 24, function()
		if selectedPlayer and selectedPlayer.Character then
			local hrp = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				teleportTo(hrp.CFrame + Vector3.new(0, 3, 0))
				addLog("[TP] Teleported to " .. selectedPlayer.DisplayName, COLORS.success)
			end
		else
			addLog("[TP] No player selected", COLORS.error)
		end
	end)

	createActionButton(tab, "Spectate Player", 25, function()
		if selectedPlayer and selectedPlayer.Character then
			local hum = selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				Camera.CameraSubject = hum
				addLog("[SPECTATE] Watching " .. selectedPlayer.DisplayName, COLORS.success)
			end
		else
			addLog("[SPECTATE] No player selected", COLORS.error)
		end
	end)

	createActionButton(tab, "Unspectate", 26, function()
		pcall(function()
			local character = LocalPlayer.Character
			if character then
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then Camera.CameraSubject = hum end
			end
		end)
		addLog("[SPECTATE] Stopped", COLORS.success)
	end)

	createActionButton(tab, "Refresh Player List", 27, function() refreshPlayerList() end)
end

-- ===================== BUILD FUN TAB =====================
do
	local tab = tabFrames["Fun"]

	createSectionLabel(tab, "Fling", 1)
	createToggle(tab, "Spin Fling", 2, function(on)
		flingEnabled = on
		if on then startFling() else stopFling() end
	end)
	createToggle(tab, "Walk Fling", 3, function(on)
		walkFlingEnabled = on
		if on then startWalkFling() else stopWalkFling() end
	end)

	createSectionLabel(tab, "Cosmetic", 5)
	createToggle(tab, "Seizure", 6, function(on)
		seizureEnabled = on
		if on then startSeizure() else stopSeizure() end
	end)
	createToggle(tab, "Headless", 7, function(on)
		headlessEnabled = on
		if on then startHeadless() else stopHeadless() end
	end)

	createSectionLabel(tab, "World", 10)
	createActionButton(tab, "Remove All Doors", 11, function() removeDoors() end)
	createSlider(tab, "Gravity", 0, 400, gravityValue, 12, function(val)
		gravityValue = val
		workspace.Gravity = val
	end)
end

-- ===================== CHAT COMMANDS =====================
local function onChatted(msg)
	msg = msg:lower()
	local args = msg:split(" ")
	local cmd = args[1]

	if cmd == "!speed" then
		local val = tonumber(args[2])
		if val then speedValue = val end
		speedEnabled = not speedEnabled
		if speedEnabled then startSpeed() else stopSpeed() end
	elseif cmd == "!fly" then
		flyEnabled = not flyEnabled
		if flyEnabled then startFly() else stopFly() end
	elseif cmd == "!noclip" then
		noclipEnabled = not noclipEnabled
		if noclipEnabled then startNoclip() else stopNoclip() end
	elseif cmd == "!god" then
		godEnabled = not godEnabled
		if godEnabled then startGod() else stopGod() end
	elseif cmd == "!killaura" then
		killAuraEnabled = not killAuraEnabled
		if killAuraEnabled then startKillAura() else stopKillAura() end
	elseif cmd == "!killall" then
		killAll()
	elseif cmd == "!esp" then
		espEnabled = not espEnabled
		if espEnabled then startESP() else stopESP() end
	elseif cmd == "!aimbot" then
		aimbotEnabled = not aimbotEnabled
		if aimbotEnabled then startAimbot() else stopAimbot() end
	elseif cmd == "!xray" then
		xrayEnabled = not xrayEnabled
		if xrayEnabled then startXRay() else stopXRay() end
	elseif cmd == "!guard" then
		switchTeam("Bright blue")
	elseif cmd == "!inmate" then
		switchTeam("Bright orange")
	elseif cmd == "!criminal" then
		switchTeam("Medium stone grey")
	elseif cmd == "!arrest" then
		pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					pcall(function()
						local hrp = player.Character:FindFirstChild("HumanoidRootPart")
						if hrp then workspace.Remote.arrest:InvokeServer(hrp) end
					end)
				end
			end
			addLog("[ARREST] Arrested all", COLORS.success)
		end)
	elseif cmd == "!guns" then
		getAllGuns()
	elseif cmd == "!keycard" then
		getKeycard()
	elseif cmd == "!invisible" then
		startInvisible()
	elseif cmd == "!antiafk" then
		antiAfkEnabled = not antiAfkEnabled
		if antiAfkEnabled then startAntiAfk() else stopAntiAfk() end
	elseif cmd == "!fling" then
		flingEnabled = not flingEnabled
		if flingEnabled then startFling() else stopFling() end
	elseif cmd == "!walkfling" then
		walkFlingEnabled = not walkFlingEnabled
		if walkFlingEnabled then startWalkFling() else stopWalkFling() end
	elseif cmd == "!gravity" then
		local val = tonumber(args[2])
		if val then workspace.Gravity = val addLog("[GRAVITY] Set to " .. val, COLORS.success) end
	elseif cmd == "!tp" then
		local targetName = args[2]
		if targetName then
			local target = findPlayer(targetName)
			if target and target.Character then
				local hrp = target.Character:FindFirstChild("HumanoidRootPart")
				if hrp then teleportTo(hrp.CFrame + Vector3.new(0, 3, 0)) addLog("[TP] " .. target.DisplayName, COLORS.success) end
			else
				addLog("[TP] Player not found", COLORS.error)
			end
		end
	elseif cmd == "!doors" then
		removeDoors()
	elseif cmd == "!help" then
		addLog("=== Prison Life Hub v1.0 Commands ===", COLORS.accent)
		addLog("!speed [val] | !fly | !noclip | !god | !killaura", COLORS.textSecondary)
		addLog("!killall | !esp | !aimbot | !xray", COLORS.textSecondary)
		addLog("!guard | !inmate | !criminal | !arrest", COLORS.textSecondary)
		addLog("!guns | !keycard | !invisible | !antiafk | !doors", COLORS.textSecondary)
		addLog("!fling | !walkfling | !gravity [val] | !tp [player]", COLORS.textSecondary)
	end
end

LocalPlayer.Chatted:Connect(onChatted)

-- ===================== RESPAWN HOOKS =====================
LocalPlayer.CharacterAdded:Connect(function(character)
	_wait(1)

	if speedEnabled then
		if speedConnection then speedConnection:Disconnect() speedConnection = nil end
		startSpeed()
	end
	if flyEnabled then
		if flyConnection then flyConnection:Disconnect() flyConnection = nil end
		startFly()
	end
	if noclipEnabled then
		if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
		startNoclip()
	end
	if infJumpEnabled then
		if infJumpConnection then infJumpConnection:Disconnect() infJumpConnection = nil end
		startInfJump()
	end
	if godEnabled then
		if godConnection then godConnection:Disconnect() godConnection = nil end
		startGod()
	end
	if killAuraEnabled then
		if killAuraConnection then killAuraConnection:Disconnect() killAuraConnection = nil end
		startKillAura()
	end
	if espEnabled then updateESP() end
	if seizureEnabled then
		if seizureConnection then seizureConnection:Disconnect() seizureConnection = nil end
		startSeizure()
	end
end)

-- ===================== STARTUP =====================
addLog("[PRISON LIFE HUB] v1.0 Loaded!", COLORS.accent)
addLog("[INFO] RightCtrl to toggle window", COLORS.textSecondary)
addLog("[INFO] Type !help in chat for commands", COLORS.textSecondary)
addLog("[INFO] Prison Life remotes: meleeEvent, TeamEvent, ItemHandler", COLORS.textDim)
print("[Prison Life Hub v1.0] Loaded - Right Ctrl to toggle")
