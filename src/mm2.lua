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

-- ===================== MAIN WINDOW =====================
local mainWindow = Instance.new("Frame")
mainWindow.Name = "MainWindow"
mainWindow.Size = UDim2.new(0, windowW, 0, windowH)
mainWindow.Position = UDim2.new(0.5, -math.floor(windowW / 2), 0.5, -math.floor(windowH / 2))
mainWindow.BackgroundColor3 = COLORS.bg
mainWindow.BorderSizePixel = 0
mainWindow.Active = true
mainWindow.Parent = screenGui
addCorner(mainWindow, 8)
addStroke(mainWindow, COLORS.border, 2)

-- ===================== RESIZE HANDLE =====================
local MIN_W = isMobile and 300 or 400
local MIN_H = isMobile and 250 or 300
local MAX_W = math.min(math.floor(screenSize.X * 0.95), 900)
local MAX_H = math.min(math.floor(screenSize.Y * 0.85), 700)

local resizeHandle = Instance.new("TextButton")
resizeHandle.Name = "ResizeHandle"
resizeHandle.Size = UDim2.new(0, 20, 0, 20)
resizeHandle.Position = UDim2.new(1, -20, 1, -20)
resizeHandle.BackgroundTransparency = 1
resizeHandle.Text = ""
resizeHandle.ZIndex = 10
resizeHandle.Parent = mainWindow

local _rl1 = Instance.new("Frame")
_rl1.Size = UDim2.new(0, 14, 0, 2)
_rl1.Position = UDim2.new(0, 3, 1, -7)
_rl1.Rotation = -45
_rl1.BackgroundColor3 = COLORS.textDim
_rl1.BorderSizePixel = 0
_rl1.ZIndex = 10
_rl1.Parent = resizeHandle

local _rl2 = Instance.new("Frame")
_rl2.Size = UDim2.new(0, 8, 0, 2)
_rl2.Position = UDim2.new(0, 9, 1, -5)
_rl2.Rotation = -45
_rl2.BackgroundColor3 = COLORS.textDim
_rl2.BorderSizePixel = 0
_rl2.ZIndex = 10
_rl2.Parent = resizeHandle

do
	local resizing = false
	local resizeStart, startSize

	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			resizeStart = input.Position
			startSize = mainWindow.AbsoluteSize
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - resizeStart
			local newW = startSize.X + delta.X
			local newH = startSize.Y + delta.Y
			if newW < MIN_W then newW = MIN_W end
			if newW > MAX_W then newW = MAX_W end
			if newH < MIN_H then newH = MIN_H end
			if newH > MAX_H then newH = MAX_H end
			mainWindow.Size = UDim2.new(0, newW, 0, newH)
		end
	end)
end

-- Shadow effect (outer glow)
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.Position = UDim2.new(0, -15, 0, -15)
shadow.BackgroundTransparency = 1
shadow.ImageTransparency = 0.6
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(24, 24, 276, 276)
shadow.Image = "rbxassetid://6015897843"
shadow.ZIndex = -1
shadow.Parent = mainWindow

-- ===================== TITLE BAR =====================
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = COLORS.bgSecondary
titleBar.BorderSizePixel = 0
titleBar.Parent = mainWindow
addCorner(titleBar, 8)

local titleBarCover = Instance.new("Frame")
titleBarCover.Size = UDim2.new(1, 0, 0, 12)
titleBarCover.Position = UDim2.new(0, 0, 1, -12)
titleBarCover.BackgroundColor3 = COLORS.bgSecondary
titleBarCover.BorderSizePixel = 0
titleBarCover.Parent = titleBar

-- Red accent line under title
local titleAccent = Instance.new("Frame")
titleAccent.Size = UDim2.new(1, 0, 0, 2)
titleAccent.Position = UDim2.new(0, 0, 1, 0)
titleAccent.BackgroundColor3 = COLORS.accent
titleAccent.BorderSizePixel = 0
titleAccent.Parent = titleBar

-- Logo icon (red square with S)
local logoIcon = Instance.new("Frame")
logoIcon.Size = UDim2.new(0, 18, 0, 18)
logoIcon.Position = UDim2.new(0, 10, 0.5, -9)
logoIcon.BackgroundColor3 = COLORS.accent
logoIcon.BorderSizePixel = 0
logoIcon.Parent = titleBar
addCorner(logoIcon, 3)

local logoText = Instance.new("TextLabel")
logoText.Size = UDim2.new(1, 0, 1, 0)
logoText.BackgroundTransparency = 1
logoText.Text = "S"
logoText.TextColor3 = COLORS.textPrimary
logoText.Font = Enum.Font.GothamBold
logoText.TextSize = 12
logoText.Parent = logoIcon

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -120, 1, 0)
titleLabel.Position = UDim2.new(0, 34, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MM2 Hub"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 40, 1, 0)
versionLabel.Position = UDim2.new(0, 110, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.1"
versionLabel.TextColor3 = COLORS.accent
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextSize = 10
versionLabel.TextXAlignment = Enum.TextXAlignment.Left
versionLabel.Parent = titleBar

-- Window buttons
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
minimizeBtn.Position = UDim2.new(1, -58, 0, 4)
minimizeBtn.BackgroundColor3 = COLORS.tabBg
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = COLORS.textSecondary
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.Parent = titleBar
addCorner(minimizeBtn, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -30, 0, 4)
closeBtn.BackgroundColor3 = COLORS.error
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.textPrimary
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 11
closeBtn.Parent = titleBar
addCorner(closeBtn, 4)

-- ===================== DRAG LOGIC =====================
do
	local dragging = false
	local dragStart, startPos

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = mainWindow.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			mainWindow.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- ===================== TAB BAR (horizontal) =====================
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, 0, 0, 30)
tabBar.Position = UDim2.new(0, 0, 0, 36)
tabBar.BackgroundColor3 = COLORS.bgSecondary
tabBar.BorderSizePixel = 0
tabBar.Parent = mainWindow

local tabBarDivider = Instance.new("Frame")
tabBarDivider.Size = UDim2.new(1, 0, 0, 1)
tabBarDivider.Position = UDim2.new(0, 0, 1, -1)
tabBarDivider.BackgroundColor3 = COLORS.border
tabBarDivider.BorderSizePixel = 0
tabBarDivider.Parent = tabBar

local tabNames = {"Main", "Combat", "ESP", "Farming", "Player", "Fun"}
local tabButtons = {}
local tabFrames = {}

local tabBarLayout = Instance.new("UIListLayout")
tabBarLayout.FillDirection = Enum.FillDirection.Horizontal
tabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabBarLayout.Padding = UDim.new(0, 0)
tabBarLayout.Parent = tabBar

for i, tabName in ipairs(tabNames) do
	local tabBtn = Instance.new("TextButton")
	tabBtn.Name = tabName .. "Tab"
	tabBtn.Size = UDim2.new(1 / #tabNames, 0, 1, 0)
	tabBtn.BackgroundColor3 = COLORS.bg
	tabBtn.BackgroundTransparency = (tabName == "Main") and 0 or 1
	tabBtn.Text = tabName
	tabBtn.TextColor3 = (tabName == "Main") and COLORS.accent or COLORS.textDim
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.TextSize = 11
	tabBtn.LayoutOrder = i
	tabBtn.Parent = tabBar

	-- Active indicator (bottom red line)
	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(1, 0, 0, 2)
	indicator.Position = UDim2.new(0, 0, 1, -2)
	indicator.BackgroundColor3 = COLORS.accent
	indicator.BorderSizePixel = 0
	indicator.Visible = (tabName == "Main")
	indicator.Parent = tabBtn

	tabButtons[tabName] = tabBtn
end

-- ===================== CONTENT AREA =====================
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, 0, 1, -66)
contentArea.Position = UDim2.new(0, 0, 0, 66)
contentArea.BackgroundTransparency = 1
contentArea.BorderSizePixel = 0
contentArea.ClipsDescendants = true
contentArea.Parent = mainWindow

-- ===================== TOGGLE BUTTON (show/hide) =====================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleBtn"
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(0, 10, 0.5, -22)
toggleBtn.BackgroundColor3 = COLORS.accent
toggleBtn.Text = "MM"
toggleBtn.TextColor3 = COLORS.textPrimary
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 13
toggleBtn.Visible = false
toggleBtn.Parent = screenGui
addCorner(toggleBtn, 22)
addStroke(toggleBtn, COLORS.accentDark, 2)

if isMobile then
	toggleBtn.Visible = true
	toggleBtn.Size = UDim2.new(0, 50, 0, 50)
	toggleBtn.Position = UDim2.new(1, -60, 0.5, -25)
	toggleBtn.BackgroundTransparency = 0.3
end

-- ===================== BUTTON LOGIC =====================
minimizeBtn.MouseButton1Click:Connect(function()
	mainWindow.Visible = false
	if not isMobile then toggleBtn.Visible = true end
	uiState.windowVisible = false
end)

closeBtn.MouseButton1Click:Connect(function()
	mainWindow.Visible = false
	if not isMobile then toggleBtn.Visible = true end
	uiState.windowVisible = false
end)

toggleBtn.MouseButton1Click:Connect(function()
	mainWindow.Visible = true
	toggleBtn.Visible = false
	uiState.windowVisible = true
end)

-- ===================== TAB CONTENT FRAMES =====================
local function createTabFrame(name)
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name .. "Frame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = COLORS.accent
	frame.Visible = (name == "Main")
	frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Parent = contentArea

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame

	addPadding(frame, 8, 8, 8, 8)

	tabFrames[name] = frame
	return frame
end

for _, name in ipairs(tabNames) do
	createTabFrame(name)
end

-- ===================== TAB SWITCHING =====================
local function switchTab(tabName)
	uiState.activeTab = tabName
	for name, frame in pairs(tabFrames) do
		frame.Visible = (name == tabName)
	end
	for name, btn in pairs(tabButtons) do
		local indicator = btn:FindFirstChild("Indicator")
		if name == tabName then
			btn.BackgroundTransparency = 0
			btn.BackgroundColor3 = COLORS.bg
			btn.TextColor3 = COLORS.accent
			if indicator then indicator.Visible = true end
		else
			btn.BackgroundTransparency = 1
			btn.TextColor3 = COLORS.textDim
			if indicator then indicator.Visible = false end
		end
	end
end

for name, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function()
		switchTab(name)
	end)
end

-- ===================== UI COMPONENT BUILDERS =====================
local function createSectionLabel(parent, text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.accent
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order or 0
	lbl.Parent = parent
	return lbl
end

local function createToggle(parent, text, order, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundColor3 = COLORS.tabBg
	row.BorderSizePixel = 0
	row.LayoutOrder = order or 0
	row.Parent = parent
	addCorner(row, 5)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -60, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.textPrimary
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local toggleFrame = Instance.new("Frame")
	toggleFrame.Size = UDim2.new(0, 40, 0, 20)
	toggleFrame.Position = UDim2.new(1, -50, 0.5, -10)
	toggleFrame.BackgroundColor3 = COLORS.toggleOff
	toggleFrame.BorderSizePixel = 0
	toggleFrame.Parent = row
	addCorner(toggleFrame, 10)

	local toggleCircle = Instance.new("Frame")
	toggleCircle.Size = UDim2.new(0, 16, 0, 16)
	toggleCircle.Position = UDim2.new(0, 2, 0.5, -8)
	toggleCircle.BackgroundColor3 = COLORS.textPrimary
	toggleCircle.BorderSizePixel = 0
	toggleCircle.Parent = toggleFrame
	addCorner(toggleCircle, 8)

	local isOn = false
	local toggleButton = Instance.new("TextButton")
	toggleButton.Size = UDim2.new(1, 0, 1, 0)
	toggleButton.BackgroundTransparency = 1
	toggleButton.Text = ""
	toggleButton.Parent = row

	local function setVisualState(on)
		isOn = on
		toggleFrame.BackgroundColor3 = on and COLORS.toggleOn or COLORS.toggleOff
		toggleCircle.Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
	end

	toggleButton.MouseButton1Click:Connect(function()
		isOn = not isOn
		setVisualState(isOn)
		if callback then callback(isOn) end
	end)

	return {row = row, setVisualState = setVisualState, isOn = function() return isOn end}
end

local function createSlider(parent, text, min, max, default, order, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 48)
	container.BackgroundColor3 = COLORS.tabBg
	container.BorderSizePixel = 0
	container.LayoutOrder = order or 0
	container.Parent = parent
	addCorner(container, 5)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -80, 0, 20)
	lbl.Position = UDim2.new(0, 10, 0, 2)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.textPrimary
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = container

	local valueLbl = Instance.new("TextLabel")
	valueLbl.Size = UDim2.new(0, 70, 0, 20)
	valueLbl.Position = UDim2.new(1, -75, 0, 2)
	valueLbl.BackgroundTransparency = 1
	valueLbl.Text = tostring(default)
	valueLbl.TextColor3 = COLORS.accent
	valueLbl.Font = Enum.Font.GothamBold
	valueLbl.TextSize = 12
	valueLbl.TextXAlignment = Enum.TextXAlignment.Right
	valueLbl.Parent = container

	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -20, 0, 8)
	sliderBg.Position = UDim2.new(0, 10, 0, 28)
	sliderBg.BackgroundColor3 = COLORS.bgSecondary
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = container
	addCorner(sliderBg, 4)

	local sliderFill = Instance.new("Frame")
	local initPct = (default - min) / (max - min)
	sliderFill.Size = UDim2.new(initPct, 0, 1, 0)
	sliderFill.BackgroundColor3 = COLORS.accent
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderBg
	addCorner(sliderFill, 4)

	local currentValue = default
	local draggingSlider = false

	local function updateSlider(inputX)
		local absPos = sliderBg.AbsolutePosition.X
		local absSize = sliderBg.AbsoluteSize.X
		local pct = (inputX - absPos) / absSize
		if pct < 0 then pct = 0 end
		if pct > 1 then pct = 1 end
		sliderFill.Size = UDim2.new(pct, 0, 1, 0)
		currentValue = math.floor(min + pct * (max - min))
		valueLbl.Text = tostring(currentValue)
		if callback then callback(currentValue) end
	end

	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			updateSlider(input.Position.X)
		end
	end)
	sliderBg.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateSlider(input.Position.X)
		end
	end)

	return {container = container, getValue = function() return currentValue end}
end

local function createActionButton(parent, text, order, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 30)
	btn.BackgroundColor3 = COLORS.tabBg
	btn.Text = text
	btn.TextColor3 = COLORS.accent
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.LayoutOrder = order or 0
	btn.Parent = parent
	addCorner(btn, 5)

	btn.MouseEnter:Connect(function() btn.BackgroundColor3 = COLORS.bgSecondary end)
	btn.MouseLeave:Connect(function() btn.BackgroundColor3 = COLORS.tabBg end)
	btn.MouseButton1Click:Connect(function() if callback then callback() end end)
	return btn
end

local function createInfoLabel(parent, text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.textSecondary
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order or 0
	lbl.Parent = parent
	return lbl
end

-- ===================== LOG SYSTEM =====================
local logFrame

local function addLog(msg, color)
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
local function enableMurdererEsp()
	-- Runs via the role check system; we just mark it enabled and handle in ESP refresh
	addLog("[MURDERER ESP] ON - Red highlight on murderer", COLORS.success)
end

local function disableMurdererEsp()
	if combatState.murdererEspHighlight then pcall(function() combatState.murdererEspHighlight:Destroy() end) combatState.murdererEspHighlight = nil end
	addLog("[MURDERER ESP] OFF", COLORS.error)
end

local function updateMurdererEsp()
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
		table.insert(espState.espConnections, gdConn)
	end
	addLog("[AUTO GRAB] ON - Watching for gun drops", COLORS.success)
end

local function stopAutoGrabGun()
	if miscState.autoGrabConnection then miscState.autoGrabConnection:Disconnect() miscState.autoGrabConnection = nil end
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
			table.insert(espState.espConnections, distConn)
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
	_spawn(function()
		while espState.espEnabled do
			_wait(espState.REFRESH_INTERVAL)
			if not espState.espEnabled then break end
			playerEspScanAll()
			-- Also update murderer ESP while we're at it
			updateMurdererEsp()
		end
	end)
end

local function disablePlayerEsp()
	local allP = {}
	for player in pairs(espState.playerEspHighlights) do table.insert(allP, player) end
	for _, player in ipairs(allP) do removePlayerHighlight(player) end
	local allN = {}
	for player in pairs(espState.playerEspNametags) do table.insert(allN, player) end
	for _, player in ipairs(allN) do removePlayerNametag(player) end
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
	_spawn(function()
		while espState.gunEspEnabled do
			_wait(3)
			if not espState.gunEspEnabled then break end
			refreshGunEsp()
		end
	end)
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
	_spawn(function()
		while espState.coinEspEnabled do
			_wait(5)
			if not espState.coinEspEnabled then break end
			refreshCoinEsp()
		end
	end)
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
			if hrp.Position.Y > -50 then
				miscState.lastSafePos = hrp.CFrame
			elseif miscState.lastSafePos then
				hrp.CFrame = miscState.lastSafePos
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
					rt.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)

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
			flingState.spinBAV.AngularVelocity = Vector3.new(0, 99999, 0)
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
					flingState.spinBAV.AngularVelocity = Vector3.new(0, 99999, 0)
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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

	createSectionLabel(tab, "Quick Actions", 5)

	createActionButton(tab, "Rejoin Server", 6, function()
		rejoinServer()
	end)
	createActionButton(tab, "Server Hop", 7, function()
		serverHop()
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 8
	spacer2.Parent = tab

	createSectionLabel(tab, "Role", 9)
	uiState.roleLabel = createInfoLabel(tab, "Role: Unknown", 10)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 11
	spacer3.Parent = tab

	createSectionLabel(tab, "Log", 12)

	logFrame = Instance.new("ScrollingFrame")
	logFrame.Size = UDim2.new(1, 0, 0, 100)
	logFrame.BackgroundColor3 = Color3.fromRGB(15, 8, 8)
	logFrame.BorderSizePixel = 0
	logFrame.ScrollBarThickness = 3
	logFrame.ScrollBarImageColor3 = COLORS.accent
	logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	logFrame.LayoutOrder = 13
	logFrame.Parent = tab
	addCorner(logFrame, 5)
	addStroke(logFrame, COLORS.border, 1)
	addPadding(logFrame, 4, 6, 4, 6)

	local logLayout = Instance.new("UIListLayout")
	logLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logLayout.Padding = UDim.new(0, 2)
	logLayout.Parent = logFrame
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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

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

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 8
	spacer2.Parent = tab

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

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 13
	spacer3.Parent = tab

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

	local killInput = Instance.new("TextBox")
	killInput.Size = UDim2.new(1, 0, 0, 30)
	killInput.BackgroundColor3 = COLORS.tabBg
	killInput.Text = ""
	killInput.PlaceholderText = "Enter player name to kill..."
	killInput.TextColor3 = COLORS.textPrimary
	killInput.PlaceholderColor3 = COLORS.textDim
	killInput.Font = Enum.Font.Gotham
	killInput.TextSize = 12
	killInput.LayoutOrder = 16
	killInput.ClearTextOnFocus = false
	killInput.Parent = tab
	addCorner(killInput, 5)

	createActionButton(tab, "Kill Player (Murderer)", 17, function()
		local name = killInput.Text
		if name and name ~= "" then
			if not roleState.roleCheckEnabled then startRoleCheck() end
			killSpecificPlayer(name)
		else
			addLog("[KILL] Enter a player name first!", COLORS.error)
		end
	end)

	local spacer4 = Instance.new("Frame")
	spacer4.Size = UDim2.new(1, 0, 0, 4)
	spacer4.BackgroundTransparency = 1
	spacer4.LayoutOrder = 18
	spacer4.Parent = tab

	createSectionLabel(tab, "TP Behind", 19)

	-- TP Behind player name input
	local tpBehindInput = Instance.new("TextBox")
	tpBehindInput.Size = UDim2.new(1, 0, 0, 30)
	tpBehindInput.BackgroundColor3 = COLORS.tabBg
	tpBehindInput.Text = ""
	tpBehindInput.PlaceholderText = "Enter player name..."
	tpBehindInput.TextColor3 = COLORS.textPrimary
	tpBehindInput.PlaceholderColor3 = COLORS.textDim
	tpBehindInput.Font = Enum.Font.Gotham
	tpBehindInput.TextSize = 12
	tpBehindInput.LayoutOrder = 20
	tpBehindInput.ClearTextOnFocus = false
	tpBehindInput.Parent = tab
	addCorner(tpBehindInput, 5)

	createActionButton(tab, "TP Behind Player", 21, function()
		local name = tpBehindInput.Text
		if name and name ~= "" then
			tpBehindPlayer(name)
		else
			addLog("[TP BEHIND] Enter a player name first!", COLORS.error)
		end
	end)

	local spacer5 = Instance.new("Frame")
	spacer5.Size = UDim2.new(1, 0, 0, 4)
	spacer5.BackgroundTransparency = 1
	spacer5.LayoutOrder = 22
	spacer5.Parent = tab

	createSectionLabel(tab, "Info", 23)
	createInfoLabel(tab, "Auto Shoot only works as Sheriff", 24)
	createInfoLabel(tab, "Kill All / Kill Player only work as Murderer", 25)
	createInfoLabel(tab, "Bring Gun teleports gun to you", 26)
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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 6
	spacer.Parent = tab

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

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 11
	spacer2.Parent = tab

	createSectionLabel(tab, "World", 12)

	createToggle(tab, "Fullbright", 13, function(on)
		espState.fullbrightEnabled = on
		if on then startFullbright() else stopFullbright() end
	end)
	createToggle(tab, "X-Ray", 14, function(on)
		miscState.xrayEnabled = on
		if on then startXRay() else stopXRay() end
	end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 15
	spacer3.Parent = tab

	createSectionLabel(tab, "Info", 16)
	createInfoLabel(tab, "ESP colors: Red=Murderer, Blue=Sheriff, Green=Innocent", 17)
	createInfoLabel(tab, "Gun ESP: Yellow highlight on dropped guns", 18)
	createInfoLabel(tab, "Coin ESP: Gold highlight on collectible coins", 19)
	createInfoLabel(tab, "X-Ray: See through walls (0.7 transparency)", 20)
	createInfoLabel(tab, "Trapdoor ESP: Orange highlight on trap parts", 21)
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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 7
	spacer.Parent = tab

	createSectionLabel(tab, "XP", 8)

	createToggle(tab, "Anti-AFK", 9, function(on)
		farmState.antiAfkEnabled = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 10
	spacer2.Parent = tab

	createSectionLabel(tab, "Info", 11)
	createInfoLabel(tab, "Auto Coin Farm teleports to each coin", 12)
	createInfoLabel(tab, "Bring Coins teleports coins to you", 13)
	createInfoLabel(tab, "Auto Collect fires touch events on coins", 14)
	createInfoLabel(tab, "Anti-AFK prevents idle kick", 15)
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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 10
	spacer.Parent = tab

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

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 15
	spacer2.Parent = tab

	createSectionLabel(tab, "Camera", 16)

	createSlider(tab, "Camera FOV", 50, 120, moveState.cameraFOV, 17, function(val)
		moveState.cameraFOV = val
		setCameraFOV(val)
	end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 18
	spacer3.Parent = tab

	createSectionLabel(tab, "World", 19)

	createSlider(tab, "Gravity", 0, 1000, moveState.gravityValue, 20, function(val)
		moveState.gravityValue = val
		setGravity(val)
	end)

	local spacer4 = Instance.new("Frame")
	spacer4.Size = UDim2.new(1, 0, 0, 4)
	spacer4.BackgroundTransparency = 1
	spacer4.LayoutOrder = 21
	spacer4.Parent = tab

	createSectionLabel(tab, "Player Target", 22)
	local selectedPlayerLabel = createInfoLabel(tab, "Selected: None", 23)

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
	local playerListFrame = Instance.new("Frame")
	playerListFrame.Size = UDim2.new(1, 0, 0, 150)
	playerListFrame.BackgroundColor3 = COLORS.bgSecondary
	playerListFrame.BorderSizePixel = 0
	playerListFrame.LayoutOrder = 27
	playerListFrame.Parent = tab
	addCorner(playerListFrame, 5)
	addStroke(playerListFrame, COLORS.border, 1)

	local playerListScroll = Instance.new("ScrollingFrame")
	playerListScroll.Size = UDim2.new(1, -8, 1, -8)
	playerListScroll.Position = UDim2.new(0, 4, 0, 4)
	playerListScroll.BackgroundTransparency = 1
	playerListScroll.BorderSizePixel = 0
	playerListScroll.ScrollBarThickness = 3
	playerListScroll.ScrollBarImageColor3 = COLORS.accent
	playerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	playerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	playerListScroll.Parent = playerListFrame

	local playerListLayout = Instance.new("UIListLayout")
	playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerListLayout.Padding = UDim.new(0, 3)
	playerListLayout.Parent = playerListScroll

	local function refreshPlayerList()
		for _, child in ipairs(playerListScroll:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		local order = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				order = order + 1
				local pBtn = Instance.new("TextButton")
				pBtn.Size = UDim2.new(1, 0, 0, 24)
				pBtn.BackgroundColor3 = COLORS.tabBg
				pBtn.Text = player.DisplayName .. " (@" .. player.Name .. ")"
				pBtn.TextColor3 = COLORS.textPrimary
				pBtn.Font = Enum.Font.Gotham
				pBtn.TextSize = 11
				pBtn.TextXAlignment = Enum.TextXAlignment.Left
				pBtn.LayoutOrder = order
				pBtn.Parent = playerListScroll
				addCorner(pBtn, 4)

				local padBtn = Instance.new("UIPadding")
				padBtn.PaddingLeft = UDim.new(0, 6)
				padBtn.Parent = pBtn

				pBtn.MouseButton1Click:Connect(function()
					miscState.selectedPlayer = player
					selectedPlayerLabel.Text = "Selected: " .. player.DisplayName
					addLog("[TARGET] Selected: " .. player.DisplayName, COLORS.accent)
					-- Highlight selected button
					for _, child in ipairs(playerListScroll:GetChildren()) do
						if child:IsA("TextButton") then
							child.BackgroundColor3 = COLORS.tabBg
						end
					end
					pBtn.BackgroundColor3 = COLORS.accent
				end)
			end
		end
	end

	refreshPlayerList()
	createActionButton(tab, "Refresh Player List", 28, function()
		refreshPlayerList()
		addLog("[PLAYERS] List refreshed", COLORS.accent)
	end)

	-- Auto-refresh when players join/leave
	Players.PlayerAdded:Connect(function() _wait(0.5) refreshPlayerList() end)
	Players.PlayerRemoving:Connect(function(player)
		if miscState.selectedPlayer == player then
			miscState.selectedPlayer = nil
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

	local spinFlingToggle = createToggle(tab, "Spin Fling", 2, function(on)
		if on and flingState.walkFlingEnabled then
			flingState.walkFlingEnabled = false
			stopWalkFling()
		end
		flingState.flingEnabled = on
		if on then startFling() else stopFling() end
	end)
	createSlider(tab, "Fling Power", 1000, 99999, flingState.flingPower, 3, function(val) flingState.flingPower = val end)
	local walkFlingToggle = createToggle(tab, "Walk Fling", 4, function(on)
		if on and flingState.flingEnabled then
			flingState.flingEnabled = false
			stopFling()
			spinFlingToggle.setVisualState(false)
		end
		flingState.walkFlingEnabled = on
		if on then startWalkFling() else stopWalkFling() end
	end)
	createSlider(tab, "Walk Fling Power", 1000, 50000, flingState.walkFlingPower, 5, function(val) flingState.walkFlingPower = val end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 6
	spacer.Parent = tab

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

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 12
	spacer2.Parent = tab

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
commands["kill"] = function(args) if args and args ~= "" then if not roleState.roleCheckEnabled then startRoleCheck() end killSpecificPlayer(args) else addLog("[KILL] Usage: ;kill <player>", COLORS.error) end end

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
	if input.KeyCode == Enum.KeyCode.RightShift then
		uiState.windowVisible = not uiState.windowVisible
		mainWindow.Visible = uiState.windowVisible
		toggleBtn.Visible = not uiState.windowVisible
	end
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

	-- Re-enable auto coin farm
	if farmState.autoCoinFarmEnabled then
		_wait(0.5)
		startAutoCoinFarm()
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

	-- Re-enable auto collect
	if miscState.autoCollectEnabled then
		_wait(0.3)
		startAutoCollect()
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
end)

-- ===================== STARTUP =====================
-- Start role check automatically so role label updates
startRoleCheck()

addLog("MM2 Hub v1.1", COLORS.accent)
addLog("Type ;cmds for command list", COLORS.textSecondary)
addLog("Use Right Shift to toggle GUI", COLORS.textSecondary)
addLog("Role detection active - scanning every 0.5s", COLORS.textSecondary)
print("[MM2 Hub] v1.1 loaded")
