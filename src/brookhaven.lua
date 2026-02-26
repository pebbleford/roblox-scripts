-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("brookhaven") then return end

-- ================================================================
-- Synapse X The Revival - Brookhaven RP Admin Hub
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

-- Blue accent line under title
local titleAccent = Instance.new("Frame")
titleAccent.Size = UDim2.new(1, 0, 0, 2)
titleAccent.Position = UDim2.new(0, 0, 1, 0)
titleAccent.BackgroundColor3 = COLORS.accent
titleAccent.BorderSizePixel = 0
titleAccent.Parent = titleBar

-- Logo icon (blue square with B)
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
logoText.Text = "B"
logoText.TextColor3 = COLORS.textPrimary
logoText.Font = Enum.Font.GothamBold
logoText.TextSize = 12
logoText.Parent = logoIcon

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -120, 1, 0)
titleLabel.Position = UDim2.new(0, 34, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Brookhaven RP Hub"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 40, 1, 0)
versionLabel.Position = UDim2.new(0, 180, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.0"
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

local tabNames = {"Main", "Teleport", "Player", "Vehicle", "House", "Trolling", "Fun"}
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

	-- Active indicator (bottom blue line)
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
toggleBtn.Text = "BH"
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
	windowVisible = false
end)

closeBtn.MouseButton1Click:Connect(function()
	mainWindow.Visible = false
	if not isMobile then toggleBtn.Visible = true end
	windowVisible = false
end)

toggleBtn.MouseButton1Click:Connect(function()
	mainWindow.Visible = true
	toggleBtn.Visible = false
	windowVisible = true
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
	activeTab = tabName
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
			table.insert(espConnections, conn)
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
		table.insert(espConnections, distConn)
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
		if not noclipEnabled then noclipEnabled = true startNoclip() end
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
		if not noclipEnabled then noclipEnabled = true startNoclip() end

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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 5
	spacer.Parent = tab

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

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 12
	spacer2.Parent = tab

	createSectionLabel(tab, "Output Log", 13)

	logFrame = Instance.new("ScrollingFrame")
	logFrame.Size = UDim2.new(1, 0, 0, 100)
	logFrame.BackgroundColor3 = COLORS.editor
	logFrame.BorderSizePixel = 0
	logFrame.ScrollBarThickness = 3
	logFrame.ScrollBarImageColor3 = COLORS.accent
	logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	logFrame.LayoutOrder = 14
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
	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = spacerOrder
	spacer.Parent = tab

	createSectionLabel(tab, "Players", spacerOrder + 1)

	-- Player name input + goto button row
	local gotoRow = Instance.new("Frame")
	gotoRow.Size = UDim2.new(1, 0, 0, 30)
	gotoRow.BackgroundTransparency = 1
	gotoRow.LayoutOrder = spacerOrder + 2
	gotoRow.Parent = tab

	local playerInput = Instance.new("TextBox")
	playerInput.Size = UDim2.new(0.65, -4, 1, 0)
	playerInput.BackgroundColor3 = COLORS.tabBg
	playerInput.TextColor3 = COLORS.textPrimary
	playerInput.PlaceholderText = "Player name..."
	playerInput.PlaceholderColor3 = COLORS.textDim
	playerInput.Font = Enum.Font.Gotham
	playerInput.TextSize = 12
	playerInput.ClearTextOnFocus = false
	playerInput.Text = ""
	playerInput.Parent = gotoRow
	addCorner(playerInput, 4)

	local gotoBtn = Instance.new("TextButton")
	gotoBtn.Size = UDim2.new(0.35, -4, 1, 0)
	gotoBtn.Position = UDim2.new(0.65, 4, 0, 0)
	gotoBtn.BackgroundColor3 = COLORS.accent
	gotoBtn.Text = "Goto Player"
	gotoBtn.TextColor3 = COLORS.textPrimary
	gotoBtn.Font = Enum.Font.GothamBold
	gotoBtn.TextSize = 12
	gotoBtn.Parent = gotoRow
	addCorner(gotoBtn, 4)

	gotoBtn.MouseButton1Click:Connect(function()
		local name = playerInput.Text
		if name == "" then addLog("[TP] Enter a player name", COLORS.error) return end
		local target = findPlayer(name)
		if target then
			teleportToPlayer(target)
		else
			addLog("[TP] Player not found: " .. name, COLORS.error)
		end
	end)
	gotoBtn.MouseEnter:Connect(function() gotoBtn.BackgroundColor3 = COLORS.accentHover end)
	gotoBtn.MouseLeave:Connect(function() gotoBtn.BackgroundColor3 = COLORS.accent end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = spacerOrder + 3
	spacer2.Parent = tab

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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 7
	spacer.Parent = tab

	createSectionLabel(tab, "Jumping", 8)

	createToggle(tab, "Infinite Jump", 9, function(on)
		infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)
	createSlider(tab, "Jump Power", 10, 500, jumpPowerValue, 10, function(val)
		jumpPowerValue = val
		setJumpPower(val)
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 11
	spacer2.Parent = tab

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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 3
	spacer.Parent = tab

	createSectionLabel(tab, "Info", 4)
	createInfoLabel(tab, "House features are experimental", 5)
end

-- =====================================================================
-- ======================== BUILD TROLLING TAB ========================
-- =====================================================================
do
	local tab = tabFrames["Trolling"]

	createSectionLabel(tab, "Fling", 1)

	createToggle(tab, "Spin Fling", 2, function(on)
		flingEnabled = on
		if on then
			if walkFlingEnabled then walkFlingEnabled = false stopWalkFling() end
			startFling()
		else stopFling() end
	end)
	createSlider(tab, "Spin Fling Power", 1000, 99999, flingPower, 3, function(val) flingPower = val end)
	createToggle(tab, "Walk Fling", 4, function(on)
		walkFlingEnabled = on
		if on then
			if flingEnabled then flingEnabled = false stopFling() end
			startWalkFling()
		else stopWalkFling() end
	end)
	createSlider(tab, "Walk Fling Power", 1000, 50000, walkFlingPower, 5, function(val) walkFlingPower = val end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 6
	spacer.Parent = tab

	createSectionLabel(tab, "Combat", 7)

	createToggle(tab, "Kill Aura", 8, function(on)
		killAuraEnabled = on
		if on then startKillAura() else stopKillAura() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 9
	spacer2.Parent = tab

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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 7
	spacer.Parent = tab

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
		if loc[1]:lower():find(search) then
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

-- ===================== KEYBOARD SHORTCUT =====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		windowVisible = not windowVisible
		mainWindow.Visible = windowVisible
		toggleBtn.Visible = not windowVisible
	end
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
