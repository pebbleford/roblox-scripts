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
if not keySystem or not keySystem.validate("slapbattles") then return end

-- ================================================================
-- Pebbleford Hub - Slap Battles Hub
-- Dedicated hub for Slap Battles
-- v1.5
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local _spawn = (task and task.spawn) or spawn
local _wait = (task and task.wait) or wait

-- ===================== COLOR PALETTE (placeholder; terminal overrides below) =====================
local COLORS = {
	bg = Color3.fromRGB(20, 20, 20), bgSecondary = Color3.fromRGB(30, 30, 30), tabBg = Color3.fromRGB(45, 45, 45),
	accent = Color3.fromRGB(0, 255, 65), accentHover = Color3.fromRGB(93, 255, 143), accentDark = Color3.fromRGB(15, 61, 28),
	textPrimary = Color3.fromRGB(255, 255, 255), textSecondary = Color3.fromRGB(176, 176, 176), textDim = Color3.fromRGB(120, 120, 120),
	border = Color3.fromRGB(50, 50, 50), toggleOn = Color3.fromRGB(0, 255, 65), toggleOff = Color3.fromRGB(85, 85, 85),
	error = Color3.fromRGB(255, 68, 68), success = Color3.fromRGB(68, 255, 68),
}

-- ===================== STATE (bundled to stay under Lua 200 local limit) =====================
local S = {
	-- combat
	reachEnabled = false, autoSlapEnabled = false, slapAuraEnabled = false,
	reachSize = 18, slapAuraRange = 60, autoSlapDelay = 0.1,
	-- movement
	speedEnabled = false, flyEnabled = false, noclipEnabled = false, infJumpEnabled = false,
	antiVoidEnabled = false, antiFlingEnabled = false,
	speedValue = 40, flySpeed = 70, jumpPowerValue = 60,
	-- visuals / misc
	espEnabled = false, fullbrightEnabled = false, antiAfkEnabled = false, autoRespawnEnabled = false,
	selectedPlayer = nil,
}

local C = {
	reachConn = nil, reachOrigSize = nil, reachPart = nil,
	autoSlapThread = nil, slapAuraThread = nil,
	flyConn = nil, flyBV = nil, flyBG = nil, flyUpBtn = nil, flyDownBtn = nil,
	noclipConn = nil, infJumpConn = nil, speedConn = nil,
	antiVoidConn = nil, antiVoidSafe = nil, antiFlingConn = nil,
	espObjects = {}, espConn = nil, espAddedConn = nil,
	antiAfkConn = nil, respawnConn = nil,
	origFog = nil, origAmbient = nil, origBrightness = nil,
}

local logLines = {}
local MAX_LOG_LINES = 50

-- ===================== MOBILE DETECTION =====================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled

-- ===================== SCREEN GUI =====================
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("SXSlapBattles")
	if old then old:Destroy() end
end)
pcall(function()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	local old = pg and pg:FindFirstChild("SXSlapBattles")
	if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SXSlapBattles"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
do
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then screenGui.Parent = hui end
end
if not screenGui.Parent then pcall(function() screenGui.Parent = game:GetService("CoreGui") end) end
if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ===================== UTILITY FUNCTIONS =====================
local function addCorner(parent, radius)
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, radius or 6) c.Parent = parent return c
end

local function getChar() return LocalPlayer.Character end
local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function findPlayer(name)
	if not name or name == "" then return nil end
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and (p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name) then
			return p
		end
	end
	return nil
end

local function isAlive(player)
	local ch = player and player.Character
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0
end

-- ===================== GUI SETUP (Terminal, hand-built) =====================
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

local tabFrames = {}
do
local _uiOrd = 0
local function _nextOrd() _uiOrd = _uiOrd + 1 return _uiOrd end

local tabNames = {"Combat", "Movement", "Places", "Player", "Visuals", "Misc"}
uiState = uiState or {activeTab = tabNames[1]}

local _TUIS = UserInputService
local _mobile = _TUIS.TouchEnabled and not _TUIS.KeyboardEnabled
local _vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
local _W = _mobile and math.floor(math.min(_vp.X * 0.95, 540)) or 540
local _H = _mobile and math.floor(math.min(_vp.Y * 0.82, 620)) or 430

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
titleLabel.Text = "SLAP BATTLES v1.5"
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

local tabButtons = {}
local _tabN = #tabNames
local _perRow = _mobile and 3 or math.min(_tabN, 5)
if _tabN < _perRow then _perRow = _tabN end
local _cellW = math.floor(_W / _perRow)
local _cellH = _mobile and 34 or 28
local _rows = math.ceil(_tabN / _perRow)
local _tabBarH = _rows * _cellH
local _contentTop = 42 + _tabBarH + 2

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, _tabBarH)
tabBar.Position = UDim2.new(0, 0, 0, 42)
tabBar.BackgroundColor3 = COLORS.bgSecondary
tabBar.BorderSizePixel = 0
tabBar.Parent = mainWindow
do local dv = Instance.new("Frame") dv.Size = UDim2.new(1,0,0,1) dv.Position = UDim2.new(0,0,1,-1) dv.BackgroundColor3 = COLORS.border dv.BorderSizePixel = 0 dv.ZIndex = 2 dv.Parent = tabBar end
do local g = Instance.new("UIGridLayout") g.CellSize = UDim2.new(0, _cellW, 0, _cellH) g.CellPadding = UDim2.new(0,0,0,0) g.SortOrder = Enum.SortOrder.LayoutOrder g.FillDirectionMaxCells = _perRow g.Parent = tabBar end

for i, tabName in ipairs(tabNames) do
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -8, 1, -(_contentTop + 4))
	content.Position = UDim2.new(0, 4, 0, _contentTop)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = _mobile and 5 or 3
	content.ScrollBarImageColor3 = COLORS.accent
	content.CanvasSize = UDim2.new(0,0,0,0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Visible = (i == 1)
	content.Parent = mainWindow
	local lay = Instance.new("UIListLayout") lay.SortOrder = Enum.SortOrder.LayoutOrder lay.Padding = UDim.new(0, _mobile and 6 or 4) lay.Parent = content
	local pd = Instance.new("UIPadding") pd.PaddingLeft = UDim.new(0,4) pd.PaddingRight = UDim.new(0,4) pd.PaddingTop = UDim.new(0,4) pd.Parent = content
	tabFrames[tabName] = content

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, _cellW, 0, _cellH)
	b.BackgroundColor3 = COLORS.accentDark
	b.BackgroundTransparency = (i == 1) and 0 or 1
	b.Text = string.upper(tabName)
	b.TextColor3 = (i == 1) and COLORS.accent or COLORS.textSecondary
	b.Font = Enum.Font.Code
	b.TextSize = _mobile and 11 or 10
	b.AutoButtonColor = false
	b.LayoutOrder = i
	b.ZIndex = 3
	b.Parent = tabBar
	do local sep = Instance.new("Frame") sep.Size = UDim2.new(0,1,1,0) sep.Position = UDim2.new(1,-1,0,0) sep.BackgroundColor3 = COLORS.bg sep.BorderSizePixel = 0 sep.ZIndex = 4 sep.Parent = b end
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
local function createSectionLabel(parent, text)
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

local function createInfoLabel(parent, text)
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
	local l = createInfoLabel(parent, text or "")
	l.TextColor3 = COLORS.textSecondary
	return setmetatable({}, {
		__newindex = function(_, k, v)
			if k == "Text" then pcall(function() l.Text = tostring(v) end)
			elseif k == "TextColor3" then pcall(function() l.TextColor3 = v end) end
		end,
		__index = function() return nil end,
	})
end

local function createToggle(parent, text, callback)
	if not parent then return end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, _mobile and 44 or 36)
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
	lbl.TextSize = _mobile and 15 or 13
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

local function createActionButton(parent, text, callback)
	if not parent then return end
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, _mobile and 40 or 32)
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

local function createSlider(parent, text, min, max, default, callback)
	if not parent then return end
	local c = Instance.new("Frame")
	c.Size = UDim2.new(1, 0, 0, _mobile and 54 or 46)
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
				b.Text = tostring(text) .. ": " .. tostring(opt)
				list.Visible = false
				if callback then pcall(callback, opt) end
			end)
		end
	end
	rebuild(options or {})
	b.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
	function wrap:SetValues(opts) rebuild(opts) end
	return wrap
end

local function createInput(parent, placeholder, callback)
	if not parent then return end
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 32)
	box.BackgroundColor3 = COLORS.tabBg
	box.Text = ""
	box.PlaceholderText = placeholder or ""
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

local function createSpacer(parent)
	if not parent then return end
	local s = Instance.new("Frame")
	s.Size = UDim2.new(1, 0, 0, 4)
	s.BackgroundTransparency = 1
	s.LayoutOrder = _nextOrd()
	s.Parent = parent
end

-- Expose builders to the feature code outside this scope.
UI = {
	section = createSectionLabel, info = createInfoLabel, dyn = createDynamicLabel,
	toggle = createToggle, button = createActionButton, slider = createSlider,
	dropdown = createDropdown, input = createInput, spacer = createSpacer,
}
end -- end terminal adapter scope

local function notify(title, msg)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = msg, Duration = 3})
	end)
	print("[SX SLAP] " .. tostring(title) .. ": " .. tostring(msg))
end

-- ================================================================
-- FEATURES
-- ================================================================
local F = {}

-- ----- SLAP TOOL HELPERS -----
-- The slap glove is a Tool. Reach is the character's right hand/arm hitbox:
-- expanding it is the classic Slap Battles reach method.
local function getReachPart()
	local c = getChar()
	if not c then return nil end
	return c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
end

local function getGlove()
	local c = getChar()
	if c then
		for _, t in ipairs(c:GetChildren()) do
			if t:IsA("Tool") then return t end
		end
	end
	local bp = LocalPlayer:FindFirstChild("Backpack")
	if bp then
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") then return t end
		end
	end
	return nil
end

local function equipGlove()
	local hum = getHum()
	local c = getChar()
	if not hum or not c then return nil end
	-- already equipped?
	for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") then return t end end
	local bp = LocalPlayer:FindFirstChild("Backpack")
	if bp then
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") then pcall(function() hum:EquipTool(t) end) return t end
		end
	end
	return nil
end

-- ----- REACH -----
F.startReach = function()
	C.reachConn = RunService.Heartbeat:Connect(function()
		pcall(function()
			local part = getReachPart()
			if not part then return end
			if C.reachPart ~= part then
				-- new character / part; remember its original size once
				C.reachPart = part
				C.reachOrigSize = part.Size
			end
			local s = S.reachSize
			part.Size = Vector3.new(s, s, s)
			part.Massless = true
			part.CanCollide = false
			part.Transparency = math.max(part.Transparency, 0.6)
		end)
	end)
	notify("Reach", "Extended to " .. S.reachSize .. " studs")
end

F.stopReach = function()
	if C.reachConn then C.reachConn:Disconnect() C.reachConn = nil end
	pcall(function()
		if C.reachPart and C.reachPart.Parent and C.reachOrigSize then
			C.reachPart.Size = C.reachOrigSize
			C.reachPart.Transparency = 0
		end
	end)
	C.reachPart = nil C.reachOrigSize = nil
	notify("Reach", "OFF")
end

-- ----- AUTO SLAP -----
F.startAutoSlap = function()
	C.autoSlapThread = _spawn(function()
		while S.autoSlapEnabled do
			pcall(function()
				local tool = equipGlove()
				if tool then tool:Activate() end
			end)
			_wait(S.autoSlapDelay)
		end
	end)
	notify("Auto Slap", "Spamming slap")
end

F.stopAutoSlap = function()
	S.autoSlapEnabled = false
	notify("Auto Slap", "OFF")
end

-- ----- SLAP AURA (auto-target nearest player, face + slap) -----
F.startSlapAura = function()
	C.slapAuraThread = _spawn(function()
		while S.slapAuraEnabled do
			pcall(function()
				local root = getRoot()
				if root then
					-- find nearest alive player within range
					local best, bestD
					for _, p in ipairs(Players:GetPlayers()) do
						if p ~= LocalPlayer and isAlive(p) then
							local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
							if r then
								local d = (r.Position - root.Position).Magnitude
								if d <= S.slapAuraRange and (not bestD or d < bestD) then best, bestD = r, d end
							end
						end
					end
					if best then
						-- face the target so the slap connects, then activate
						root.CFrame = CFrame.new(root.Position, Vector3.new(best.Position.X, root.Position.Y, best.Position.Z))
						local tool = equipGlove()
						if tool then tool:Activate() end
					end
				end
			end)
			_wait(S.autoSlapDelay)
		end
	end)
	notify("Slap Aura", "Auto-slapping within " .. S.slapAuraRange .. " studs")
end

F.stopSlapAura = function()
	S.slapAuraEnabled = false
	notify("Slap Aura", "OFF")
end

F.slapTarget = function()
	local target = S.selectedPlayer
	if not target or not isAlive(target) then notify("Slap", "Pick a live target first") return end
	local root = getRoot()
	local tr = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not root or not tr then return end
	pcall(function()
		root.CFrame = tr.CFrame * CFrame.new(0, 0, 4)
		local tool = equipGlove()
		if tool then tool:Activate() end
	end)
	notify("Slap", "Slapped " .. target.DisplayName)
end

-- ----- SPEED -----
F.startSpeed = function()
	C.speedConn = RunService.Heartbeat:Connect(function()
		pcall(function()
			local h = getHum()
			if h then h.WalkSpeed = S.speedValue end
		end)
	end)
end
F.stopSpeed = function()
	if C.speedConn then C.speedConn:Disconnect() C.speedConn = nil end
	pcall(function() local h = getHum() if h then h.WalkSpeed = 16 end end)
end

-- ----- FLY (keyboard + mobile, ignores chat typing) -----
F.startFly = function()
	local root = getRoot()
	local hum = getHum()
	if not root then return end
	if hum then hum.PlatformStand = true end
	C.flyBV = Instance.new("BodyVelocity")
	C.flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	C.flyBV.Velocity = Vector3.zero
	C.flyBV.Parent = root
	C.flyBG = Instance.new("BodyGyro")
	C.flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	C.flyBG.P = 9000
	C.flyBG.CFrame = root.CFrame
	C.flyBG.Parent = root

	if isMobile then
		local function mk(txt, yoff)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 60, 0, 60)
			btn.Position = UDim2.new(1, -80, 1, yoff)
			btn.BackgroundColor3 = COLORS.bgSecondary
			btn.BackgroundTransparency = 0.2
			btn.Text = txt
			btn.TextColor3 = COLORS.accent
			btn.Font = Enum.Font.Code
			btn.TextSize = 13
			btn.Parent = screenGui
			addCorner(btn, 8)
			return btn
		end
		C.flyUpBtn = mk("UP", -180)
		C.flyDownBtn = mk("DOWN", -110)
		C.flyUpBtn.MouseButton1Down:Connect(function() S._flyUp = true end)
		C.flyUpBtn.MouseButton1Up:Connect(function() S._flyUp = false end)
		C.flyDownBtn.MouseButton1Down:Connect(function() S._flyDown = true end)
		C.flyDownBtn.MouseButton1Up:Connect(function() S._flyDown = false end)
	end

	C.flyConn = RunService.Heartbeat:Connect(function()
		if not C.flyBV or not C.flyBV.Parent then return end
		local cam = workspace.CurrentCamera
		local dir = Vector3.zero
		local typing = UserInputService:GetFocusedTextBox() ~= nil
		if not typing then
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
		end
		if isMobile then
			local h = getHum()
			local mv = h and h.MoveDirection or Vector3.zero
			if mv.Magnitude > 0.1 then dir = dir + cam.CFrame.LookVector * (-mv.Z) + cam.CFrame.RightVector * mv.X end
			if S._flyUp then dir = dir + Vector3.new(0,1,0) end
			if S._flyDown then dir = dir - Vector3.new(0,1,0) end
		end
		if dir.Magnitude > 0 then dir = dir.Unit end
		C.flyBV.Velocity = dir * S.flySpeed
		C.flyBG.CFrame = cam.CFrame
	end)
end
F.stopFly = function()
	if C.flyConn then C.flyConn:Disconnect() C.flyConn = nil end
	if C.flyBV then pcall(function() C.flyBV:Destroy() end) C.flyBV = nil end
	if C.flyBG then pcall(function() C.flyBG:Destroy() end) C.flyBG = nil end
	if C.flyUpBtn then pcall(function() C.flyUpBtn:Destroy() end) C.flyUpBtn = nil end
	if C.flyDownBtn then pcall(function() C.flyDownBtn:Destroy() end) C.flyDownBtn = nil end
	pcall(function()
		local hum = getHum()
		local root = getRoot()
		if hum then hum.PlatformStand = false end
		if root then root.AssemblyLinearVelocity = Vector3.zero end
	end)
end

-- ----- NOCLIP -----
F.startNoclip = function()
	C.noclipConn = RunService.Stepped:Connect(function()
		pcall(function()
			local c = getChar()
			if c then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
				end
			end
		end)
	end)
end
F.stopNoclip = function()
	if C.noclipConn then C.noclipConn:Disconnect() C.noclipConn = nil end
end

-- ----- INFINITE JUMP -----
F.startInfJump = function()
	C.infJumpConn = UserInputService.JumpRequest:Connect(function()
		pcall(function()
			local h = getHum()
			if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end)
end
F.stopInfJump = function()
	if C.infJumpConn then C.infJumpConn:Disconnect() C.infJumpConn = nil end
end

-- ----- ANTI-VOID (catches you when you fall off the arena) -----
F.startAntiVoid = function()
	C.antiVoidConn = RunService.Heartbeat:Connect(function()
		pcall(function()
			local h = getHum()
			local root = getRoot()
			if not h or not root then return end
			-- remember last safe spot while standing on something
			if h.FloorMaterial ~= Enum.Material.Air then
				C.antiVoidSafe = root.Position
			elseif root.Position.Y < -20 or (C.antiVoidSafe and root.Position.Y < C.antiVoidSafe.Y - 80) then
				if C.antiVoidSafe then
					root.CFrame = CFrame.new(C.antiVoidSafe + Vector3.new(0, 4, 0))
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end)
	end)
	notify("Anti-Void", "Will catch you when slapped off")
end
F.stopAntiVoid = function()
	if C.antiVoidConn then C.antiVoidConn:Disconnect() C.antiVoidConn = nil end
end

-- ----- ANTI-FLING (clamp the big velocity a slap imparts) -----
F.startAntiFling = function()
	C.antiFlingConn = RunService.Heartbeat:Connect(function()
		pcall(function()
			local root = getRoot()
			if not root then return end
			local v = root.AssemblyLinearVelocity
			local horiz = Vector3.new(v.X, 0, v.Z)
			if horiz.Magnitude > 150 then
				root.AssemblyLinearVelocity = Vector3.new(horiz.Unit.X * 50, math.max(v.Y, -50), horiz.Unit.Z * 50)
			end
			local av = root.AssemblyAngularVelocity
			if av.Magnitude > 30 then root.AssemblyAngularVelocity = Vector3.zero end
		end)
	end)
	notify("Anti-Fling", "Clamping slap knockback")
end
F.stopAntiFling = function()
	if C.antiFlingConn then C.antiFlingConn:Disconnect() C.antiFlingConn = nil end
end

-- ----- ESP -----
local function makeEsp(player)
	if C.espObjects[player] then return end
	local hl = Instance.new("Highlight")
	hl.FillColor = COLORS.accent
	hl.OutlineColor = Color3.fromRGB(255,255,255)
	hl.FillTransparency = 0.6
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = screenGui
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 120, 0, 18)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = screenGui
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.new(1,0,1,0)
	txt.BackgroundTransparency = 1
	txt.TextColor3 = COLORS.accent
	txt.Font = Enum.Font.Code
	txt.TextSize = 12
	txt.TextStrokeTransparency = 0.4
	txt.Parent = bb
	C.espObjects[player] = {hl = hl, bb = bb, txt = txt}
end

local function clearEsp()
	for _, o in pairs(C.espObjects) do
		pcall(function() o.hl:Destroy() end)
		pcall(function() o.bb:Destroy() end)
	end
	C.espObjects = {}
end

F.startEsp = function()
	for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then makeEsp(p) end end
	C.espAddedConn = Players.PlayerAdded:Connect(function(p) makeEsp(p) end)
	C.espConn = RunService.Heartbeat:Connect(function()
		local root = getRoot()
		for player, o in pairs(C.espObjects) do
			pcall(function()
				local ch = player.Character
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				local head = ch and ch:FindFirstChild("Head")
				if ch and hrp and isAlive(player) then
					o.hl.Adornee = ch
					o.bb.Adornee = head or hrp
					local d = root and math.floor((hrp.Position - root.Position).Magnitude) or 0
					o.txt.Text = player.DisplayName .. " [" .. d .. "]"
					o.hl.Enabled = true o.bb.Enabled = true
				else
					o.hl.Enabled = false o.bb.Enabled = false
				end
			end)
		end
	end)
	notify("ESP", "Players highlighted")
end
F.stopEsp = function()
	if C.espConn then C.espConn:Disconnect() C.espConn = nil end
	if C.espAddedConn then C.espAddedConn:Disconnect() C.espAddedConn = nil end
	clearEsp()
	notify("ESP", "OFF")
end

-- ----- FULLBRIGHT -----
F.startFullbright = function()
	C.origFog = Lighting.FogEnd
	C.origAmbient = Lighting.Ambient
	C.origBrightness = Lighting.Brightness
	Lighting.Ambient = Color3.fromRGB(180,180,180)
	Lighting.Brightness = 2
	Lighting.FogEnd = 1e9
	Lighting.GlobalShadows = false
end
F.stopFullbright = function()
	pcall(function()
		if C.origAmbient then Lighting.Ambient = C.origAmbient end
		if C.origBrightness then Lighting.Brightness = C.origBrightness end
		if C.origFog then Lighting.FogEnd = C.origFog end
		Lighting.GlobalShadows = true
	end)
end

-- ----- ANTI-AFK -----
F.startAntiAfk = function()
	C.antiAfkConn = LocalPlayer.Idled:Connect(function()
		pcall(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end)
	notify("Anti-AFK", "Won't be kicked for idling")
end
F.stopAntiAfk = function()
	if C.antiAfkConn then C.antiAfkConn:Disconnect() C.antiAfkConn = nil end
end

-- ----- TELEPORT / SPECTATE -----
F.tpToTarget = function()
	local t = S.selectedPlayer
	local root = getRoot()
	local tr = t and t.Character and t.Character:FindFirstChild("HumanoidRootPart")
	if root and tr then root.CFrame = tr.CFrame * CFrame.new(0,0,4) notify("TP", "To " .. t.DisplayName)
	else notify("TP", "No valid target") end
end

F.spectate = function()
	local t = S.selectedPlayer
	if t and t.Character and t.Character:FindFirstChild("Humanoid") then
		Camera.CameraSubject = t.Character.Humanoid
		notify("Spectate", t.DisplayName)
	else notify("Spectate", "No valid target") end
end
F.unspectate = function()
	local h = getHum()
	if h then Camera.CameraSubject = h end
	notify("Spectate", "OFF")
end

F.resetChar = function()
	local h = getHum()
	if h then h.Health = 0 notify("Reset", "Respawning") end
end

-- ----- PLACE TELEPORTER -----
-- Slap Battles' areas are locations in the same server (arena, Brazil,
-- Backrooms, the void/secret spots, glove-unlock pads, etc). We find them by
-- scanning the workspace for named Models/Parts and all SpawnLocations, then
-- teleport by CFrame. Works regardless of map version since it searches names.
local PLACE_NAMES = {
	"Brazil", "Backrooms", "Lobby", "Arena", "Void", "Island", "Shop",
	"Statue", "Recall", "Secret", "Minigame", "Space", "Moon", "Hell",
	"Heaven", "Office", "Pot", "Cannon", "Portal", "Teleport", "Pad",
	"Area", "Stage", "Ring", "Badge", "Obby", "Tower", "Cave", "Beach",
	"Desert", "Snow", "Sky", "Gym", "Boss", "Diddy", "Gojo", "Error",
	"Platform", "Bridge", "House", "Room", "Zone", "Spawn", "Map",
}

local function placePos(obj)
	if obj:IsA("Model") then
		local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
		if pp then return pp.Position + Vector3.new(0, 4, 0) end
	elseif obj:IsA("BasePart") then
		return obj.Position + Vector3.new(0, 4, 0)
	end
	return nil
end

F.scanPlaces = function()
	local found, seen = {}, {}
	local function add(obj, label)
		if seen[obj] then return end
		local pos = placePos(obj)
		if pos then seen[obj] = true table.insert(found, {name = label or obj.Name, pos = pos}) end
	end
	local function matches(name)
		local nl = name:lower()
		for _, kw in ipairs(PLACE_NAMES) do if nl:find(kw:lower(), 1, true) then return true end end
		return false
	end
	-- Named Models/Parts, top 2 levels (fast, avoids a full-tree walk).
	for _, obj in ipairs(workspace:GetChildren()) do
		if matches(obj.Name) then add(obj) end
		if obj:IsA("Model") or obj:IsA("Folder") then
			pcall(function()
				for _, ch in ipairs(obj:GetChildren()) do
					if matches(ch.Name) then add(ch, ch.Name) end
				end
			end)
		end
	end
	-- Every SpawnLocation is a reachable spot too.
	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("SpawnLocation") and not seen[obj] then
				seen[obj] = true
				table.insert(found, {name = "Spawn: " .. obj.Name, pos = obj.Position + Vector3.new(0, 4, 0)})
			end
		end
	end)
	table.sort(found, function(a, b) return a.name < b.name end)
	return found
end

F.tpToPos = function(pos)
	local root = getRoot()
	if root and pos then
		root.CFrame = CFrame.new(pos)
		root.AssemblyLinearVelocity = Vector3.zero
		return true
	end
	return false
end

-- ----- GLOVE PORTALS -----
-- Brazil and the other glove areas are not separate places - they are in-game
-- portals you normally have to touch. We find them STRICTLY (strong portal
-- names only, plus children of any Portals/Teleporters folder) so the list
-- stays short, and ACTIVATE fires the portal so the game teleports you.
local PORTAL_NAMES = { "portal", "brazil", "teleport", "warp", "dimension", "realm" }
local PORTAL_CONTAINERS = { "portal", "teleport", "warp" }

local function portalNameHit(name)
	local nl = name:lower()
	for _, kw in ipairs(PORTAL_NAMES) do if nl:find(kw, 1, true) then return kw end end
	return nil
end

local function partPos(obj)
	if obj:IsA("BasePart") then return obj.Position end
	if obj:IsA("Model") then local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart") if p then return p.Position end end
	return nil
end

F.scanPortals = function()
	local found, seen = {}, {}
	local function add(obj, label)
		if seen[obj] or not (obj:IsA("BasePart") or obj:IsA("Model")) then return end
		local pos = partPos(obj)
		if not pos then return end
		seen[obj] = true
		table.insert(found, {name = label, part = (obj:IsA("BasePart") and obj or nil), pos = pos})
	end
	local scanned = 0
	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			scanned = scanned + 1
			if scanned > 60000 then break end
			-- 1) strong portal-named parts/models
			local hit = portalNameHit(obj.Name)
			if hit then add(obj, "[" .. hit .. "] " .. obj.Name) end
			-- 2) children of a Portals/Teleporters folder/model
			if obj:IsA("Folder") or obj:IsA("Model") then
				local cl = obj.Name:lower()
				local isContainer = false
				for _, kw in ipairs(PORTAL_CONTAINERS) do if cl:find(kw, 1, true) then isContainer = true break end end
				if isContainer then
					pcall(function()
						for _, ch in ipairs(obj:GetChildren()) do add(ch, obj.Name .. "/" .. ch.Name) end
					end)
				end
			end
		end
	end)
	table.sort(found, function(a, b) return a.name < b.name end)
	return found, scanned
end

-- Focused dump: prints likely teleporters (named parts, portal folders) and
-- portal/teleport-named Remotes to F9, with full paths, so the exact objects
-- can be identified and wired to named buttons.
F.dumpPortals = function()
	print("========== SLAP BATTLES PORTAL DUMP ==========")
	local KW = { "portal", "brazil", "teleport", "warp", "dimension", "realm",
		"limbo", "repress", "memor", "reverse", "recall", "secret", "gate", "obtain" }
	local function anyKw(name)
		local nl = name:lower()
		for _, k in ipairs(KW) do if nl:find(k, 1, true) then return true end end
		return false
	end
	local n = 0
	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Folder")) and anyKw(obj.Name) then
				n = n + 1
				print(obj.ClassName .. " | " .. obj:GetFullName())
			end
		end
	end)
	print("---------- remotes ----------")
	pcall(function()
		for _, svc in ipairs({ game:GetService("ReplicatedStorage"), workspace }) do
			for _, obj in ipairs(svc:GetDescendants()) do
				if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and anyKw(obj.Name) then
					print(obj.ClassName .. " | " .. obj:GetFullName())
				end
			end
		end
	end)
	print("========== END DUMP (" .. n .. " named objects) ==========")
	notify("Portal Dump", "Printed to F9 - paste it to pin exact portals")
end

-- Activate a portal entry: walk you onto it, fire its touch interest, and fire
-- its ProximityPrompt - whichever the game actually uses then triggers.
F.activatePortal = function(entry)
	if not entry then return false end
	local root = getRoot()
	local ok = false
	-- 1) teleport onto it so a natural Touched fires
	if root and entry.pos then
		pcall(function() root.CFrame = CFrame.new(entry.pos + Vector3.new(0, 3, 0)) root.AssemblyLinearVelocity = Vector3.zero end)
		ok = true
	end
	-- 2) simulate the touch directly (works even without standing exactly right)
	if root and entry.part and firetouchinterest then
		pcall(function()
			firetouchinterest(root, entry.part, 0)
			task.wait(0.05)
			firetouchinterest(root, entry.part, 1)
		end)
		ok = true
	end
	-- 3) fire the ProximityPrompt if there is one
	if entry.prompt and fireproximityprompt then
		pcall(function() fireproximityprompt(entry.prompt) end)
		ok = true
	end
	return ok
end

-- ----- EXACT KNOWN PORTALS (from the in-game dump) -----
-- Each destination fires its real teleport remote and/or touches its real
-- portal part. Resolved by path so a missing one just no-ops.
local KNOWN_PORTALS = {
	{ label = "Brazil",            remote = "ReplicatedStorage.BrazilHit", part = "Workspace.Lobby.brazil.portal" },
	{ label = "Normal Arena",      remote = "ReplicatedStorage.Remotes.NormalArenaTeleport" },
	{ label = "Ultra Instinct",    remote = "ReplicatedStorage.UltraInstinctTeleport" },
	{ label = "Flash",             remote = "ReplicatedStorage.FlashTeleport" },
	{ label = "Elude",             remote = "ReplicatedStorage.TeleportElude" },
	{ label = "Friday 13th",       remote = "ReplicatedStorage.TeleportFriday13th" },
	{ label = "Slenderman",        remote = "ReplicatedStorage.Remotes.SlendermanObtainmentTeleport" },
	{ label = "Shopkeeper",        remote = "ReplicatedStorage.Remotes.ShopkeeperObtainmentTeleport" },
	{ label = "Warp (Lobby)",      remote = "ReplicatedStorage.WarpHit", part = "Workspace.Lobby.Warp" },
	{ label = "Bounty Hunter Room", part = "Workspace.BountyHunterRoom.BountyHunterBooth._bountyRoomWarpPart" },
	{ label = "Egg Teleport",      part = "Workspace.BountyHunterRoom.EggTeleport" },
	{ label = "Pocket Dimension",  part = "Workspace.PocketDimension.PocketDimensionArea" },
	{ label = "Limited Portal",    part = "Workspace.Limited_Portal.Teleport" },
	{ label = "Conker",            part = "Workspace.ConkerTeleport" },
	{ label = "Repressed Memories", part = "Workspace.RepressedMemories.Portal" },
	{ label = "Find The Gloves",   part = "Workspace.FindTheGlovesTeleport" },
	{ label = "Well",              part = "Workspace.WellModel.Portal" },
	{ label = "Cannon Island",     part = "Workspace.Arena.CannonIsland.Cannon Island [OLD].Model.Towers.TeleportSFHitbox" },
}

local function resolvePath(path)
	local segs = string.split(path, ".")
	local cur
	if segs[1] == "Workspace" then cur = workspace
	elseif segs[1] == "ReplicatedStorage" then cur = ReplicatedStorage
	else return nil end
	for i = 2, #segs do
		if not cur then return nil end
		cur = cur:FindFirstChild(segs[i])
	end
	return cur
end

F.goToPortal = function(entry)
	local did, tried = false, false
	-- Fire the real teleport remote
	if entry.remote then
		local r = resolvePath(entry.remote)
		if r then
			tried = true
			pcall(function()
				if r:IsA("RemoteEvent") then r:FireServer()
				elseif r:IsA("RemoteFunction") then r:InvokeServer() end
			end)
			did = true
		end
	end
	-- Touch the real portal part. We DON'T teleport you onto it anymore -
	-- firetouchinterest fires the part's Touched from where you stand, so a real
	-- pad still triggers, and a decorative wall just does nothing instead of
	-- stranding you to fall to your death.
	if entry.part then
		local obj = resolvePath(entry.part)
		if obj then
			tried = true
			local bp = obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))) or nil
			local root = getRoot()
			if bp and root and firetouchinterest then
				pcall(function() firetouchinterest(root, bp, 0) task.wait(0.06) firetouchinterest(root, bp, 1) end)
				did = true
			elseif bp and root then
				-- no firetouchinterest on this executor: last resort, move onto it
				pcall(function() root.CFrame = CFrame.new(bp.Position + Vector3.new(0, 3, 0)) root.AssemblyLinearVelocity = Vector3.zero end)
				did = true
			end
		end
	end
	if not tried then notify("Portal", entry.label .. ": not found in this server") end
	return did
end

-- ================================================================
-- RESPAWN HOOK: re-apply active features after death
-- ================================================================
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1.2)
	pcall(function()
		if S.speedEnabled then F.startSpeed() end
		if S.flyEnabled then F.startFly() end
		if S.noclipEnabled then F.startNoclip() end
		if S.reachEnabled then F.startReach() end
		if S.antiVoidEnabled then C.antiVoidSafe = nil F.startAntiVoid() end
		if S.antiFlingEnabled then F.startAntiFling() end
		if S.autoRespawnEnabled then end
	end)
end)

-- ================================================================
-- BUILD TABS
-- ================================================================

-- ===== COMBAT =====
do
	local tab = tabFrames["Combat"]
	UI.section(tab, "Slap Reach")
	UI.toggle(tab, "Reach Extender", function(on)
		S.reachEnabled = on
		if on then F.startReach() else F.stopReach() end
	end)
	UI.slider(tab, "Reach Size (studs)", 5, 60, S.reachSize, function(v) S.reachSize = v end)
	UI.info(tab, "Grows your slap hand so you hit from far away.")

	UI.spacer(tab)
	UI.section(tab, "Auto Slap")
	UI.toggle(tab, "Auto Slap (spam)", function(on)
		S.autoSlapEnabled = on
		if on then F.startAutoSlap() else F.stopAutoSlap() end
	end)
	UI.toggle(tab, "Slap Aura (auto-target)", function(on)
		S.slapAuraEnabled = on
		if on then F.startSlapAura() else F.stopSlapAura() end
	end)
	UI.slider(tab, "Aura Range (studs)", 10, 150, S.slapAuraRange, function(v) S.slapAuraRange = v end)
	UI.slider(tab, "Slap Delay (x100 ms)", 1, 20, math.floor(S.autoSlapDelay*100), function(v) S.autoSlapDelay = v/100 end)
	UI.info(tab, "Aura faces the nearest player and slaps. Pair with Reach for farms.")

	UI.spacer(tab)
	UI.section(tab, "Target")
	UI.button(tab, "Slap Selected Target", function() F.slapTarget() end)
	UI.info(tab, "Pick a target on the Player tab first.")
end

-- ===== MOVEMENT =====
do
	local tab = tabFrames["Movement"]
	UI.section(tab, "Movement")
	UI.toggle(tab, "Speed", function(on) S.speedEnabled = on if on then F.startSpeed() else F.stopSpeed() end end)
	UI.slider(tab, "Walk Speed", 16, 200, S.speedValue, function(v) S.speedValue = v end)
	UI.toggle(tab, "Fly (WASD / mobile)", function(on) S.flyEnabled = on if on then F.startFly() else F.stopFly() end end)
	UI.slider(tab, "Fly Speed", 20, 250, S.flySpeed, function(v) S.flySpeed = v end)
	UI.toggle(tab, "Noclip", function(on) S.noclipEnabled = on if on then F.startNoclip() else F.stopNoclip() end end)
	UI.toggle(tab, "Infinite Jump", function(on) S.infJumpEnabled = on if on then F.startInfJump() else F.stopInfJump() end end)

	UI.spacer(tab)
	UI.section(tab, "Survival")
	UI.toggle(tab, "Anti-Void (catch falls)", function(on) S.antiVoidEnabled = on if on then C.antiVoidSafe = nil F.startAntiVoid() else F.stopAntiVoid() end end)
	UI.toggle(tab, "Anti-Fling (block knockback)", function(on) S.antiFlingEnabled = on if on then F.startAntiFling() else F.stopAntiFling() end end)
	UI.info(tab, "Anti-Void TPs you back when slapped off. Anti-Fling clamps the launch.")
end

-- ===== PLACES =====
do
	local tab = tabFrames["Places"]
	UI.section(tab, "Glove Portals (one-click)")
	UI.info(tab, "Fires each area's real teleport (remote + portal touch). Some need the right glove equipped first.")
	for _, entry in ipairs(KNOWN_PORTALS) do
		UI.button(tab, "Go To " .. entry.label, function()
			if F.goToPortal(entry) then notify("Portal", "-> " .. entry.label) end
		end)
	end

	UI.spacer(tab)
	UI.section(tab, "Generic Scan (fallback)")
	UI.info(tab, "Finds other reachable areas by name if a new one appears.")
	local places = {}
	local chosen = nil
	local dd
	local function labels()
		local n = {}
		for _, pl in ipairs(places) do table.insert(n, pl.name) end
		if #n == 0 then n = {"(scan first)"} end
		return n
	end
	UI.button(tab, "SCAN PLACES", function()
		places = F.scanPlaces()
		chosen = nil
		if dd then dd:SetValues(labels()) end
		notify("Places", #places .. " found")
	end)
	dd = UI.dropdown(tab, "Place", labels(), "Pick", function(choice)
		for _, pl in ipairs(places) do if pl.name == choice then chosen = pl break end end
	end)
	UI.button(tab, "TELEPORT TO PLACE", function()
		if not chosen then notify("Places", "Scan and pick a place first") return end
		if F.tpToPos(chosen.pos) then notify("Places", "Teleported to " .. chosen.name)
		else notify("Places", "Teleport failed") end
	end)
	UI.button(tab, "DUMP PORTALS (F9)", function() F.dumpPortals() end)
end

-- ===== PLAYER =====
do
	local tab = tabFrames["Player"]
	UI.section(tab, "Target Player")
	local players = {}
	local function names()
		players = {}
		local n = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then players[p.DisplayName] = p table.insert(n, p.DisplayName) end
		end
		if #n == 0 then n = {"(no players)"} end
		return n
	end
	local dd
	dd = UI.dropdown(tab, "Target", names(), "Pick", function(choice) S.selectedPlayer = players[choice] end)
	UI.button(tab, "Refresh Players", function() if dd then dd:SetValues(names()) end end)
	Players.PlayerAdded:Connect(function() task.wait(1) if dd then dd:SetValues(names()) end end)
	Players.PlayerRemoving:Connect(function() task.wait(0.5) if dd then dd:SetValues(names()) end end)

	UI.spacer(tab)
	UI.section(tab, "Actions")
	UI.button(tab, "Teleport To Target", function() F.tpToTarget() end)
	UI.button(tab, "Slap Target", function() F.slapTarget() end)
	UI.button(tab, "Spectate Target", function() F.spectate() end)
	UI.button(tab, "Unspectate", function() F.unspectate() end)
	UI.button(tab, "Reset / Respawn", function() F.resetChar() end)
end

-- ===== VISUALS =====
do
	local tab = tabFrames["Visuals"]
	UI.section(tab, "ESP")
	UI.toggle(tab, "Player ESP (name + dist)", function(on) S.espEnabled = on if on then F.startEsp() else F.stopEsp() end end)
	UI.info(tab, "Highlights and labels every player through walls.")

	UI.spacer(tab)
	UI.section(tab, "Lighting")
	UI.toggle(tab, "Fullbright", function(on) S.fullbrightEnabled = on if on then F.startFullbright() else F.stopFullbright() end end)
end

-- ===== MISC =====
do
	local tab = tabFrames["Misc"]
	UI.section(tab, "Utility")
	UI.toggle(tab, "Anti-AFK", function(on) S.antiAfkEnabled = on if on then F.startAntiAfk() else F.stopAntiAfk() end end)

	UI.spacer(tab)
	UI.section(tab, "Server")
	UI.button(tab, "Rejoin Server", function()
		pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
	end)
	UI.button(tab, "Server Hop", function()
		pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
	end)

	UI.spacer(tab)
	UI.section(tab, "Info")
	local plLabel = UI.dyn(tab, "Players: " .. #Players:GetPlayers())
	task.spawn(function()
		while task.wait(3) do pcall(function() plLabel.Text = "Players: " .. #Players:GetPlayers() end) end
	end)
	UI.info(tab, "Right Shift toggles the menu. v1.5")
end

notify("Slap Battles v1.5", "Loaded! Right Shift to toggle")
print("[SX SLAP v1.5] Pebbleford Hub - Slap Battles Hub")
print("[SX SLAP v1.5] Tabs: Combat | Movement | Places | Player | Visuals | Misc")
print("[SX SLAP v1.5] Reach + Auto Slap + Slap Aura + Place TP + Anti-Void")
