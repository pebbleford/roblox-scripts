-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate() then return end

-- ================================================================
-- Synapse X The Revival - SharkBite 2 Hub
-- Dedicated admin for SharkBite 2
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

-- ===================== COLOR PALETTE (Red/Crimson Theme) =====================
local COLORS = {
	bg = Color3.fromRGB(20, 18, 18),
	bgSecondary = Color3.fromRGB(32, 28, 28),
	tabBg = Color3.fromRGB(50, 42, 42),
	accent = Color3.fromRGB(220, 40, 40),
	accentHover = Color3.fromRGB(240, 70, 70),
	accentDark = Color3.fromRGB(160, 30, 30),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(176, 176, 176),
	textDim = Color3.fromRGB(120, 120, 120),
	border = Color3.fromRGB(60, 45, 45),
	toggleOn = Color3.fromRGB(220, 40, 40),
	toggleOff = Color3.fromRGB(85, 85, 85),
	error = Color3.fromRGB(255, 68, 68),
	success = Color3.fromRGB(68, 255, 68),
	btnExecute = Color3.fromRGB(220, 40, 40),
	btnClear = Color3.fromRGB(60, 60, 60),
}

-- Player ESP colors (green to contrast red shark ESP)
local PLAYER_ESP_COLOR = Color3.fromRGB(0, 200, 0)
local PLAYER_ESP_OUTLINE = Color3.fromRGB(0, 255, 0)

-- ===================== STATE =====================
local autoShootSharkEnabled = false
local autoKillAsSharkEnabled = false
local sharkEspEnabled = false
local playerEspEnabled = false
local boatSpeedEnabled = false
local flyEnabled = false
local noclipEnabled = false
local speedEnabled = false
local infJumpEnabled = false
local godEnabled = false
local flingEnabled = false
local spinEnabled = false
local emoteActive = false

local flySpeed = 80
local speedValue = 100
local boatSpeedValue = 200
local flingPower = 99999
local jumpPowerValue = 50

local autoShootConnection = nil
local autoKillConnection = nil
local sharkEspHighlights = {}
local playerEspHighlights = {}
local playerEspNametags = {}
local espConnections = {}
local boatSpeedConnection = nil
local flyConnection = nil
local bodyGyro = nil
local bodyVelocity = nil
local noclipConnection = nil
local infJumpConnection = nil
local spinConnection = nil
local spinBAV = nil
local savedPhysProps = {}
local flingConnection = nil
local flingConnection2 = nil
local emoteTracks = {}
local emoteConnection = nil
local windowVisible = true
local activeTab = "Main"
local logLines = {}
local MAX_LOG_LINES = 50

local origWalkSpeed = 16
local origJumpPower = 50

-- ESP config
local REFRESH_INTERVAL = 5

-- ===================== MOBILE / RESIZE DETECTION =====================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local ORIG_W = 560
local ORIG_H = 390
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
	local old = game:GetService("CoreGui"):FindFirstChild("SXSharkBite")
	if old then old:Destroy() end
end)
pcall(function()
	local old = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("SXSharkBite")
	if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SXSharkBite"
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

local function getShark()
	-- SharkBite 2 stores sharks in workspace.Sharks
	local sharks = workspace:FindFirstChild("Sharks")
	if not sharks then return nil end
	for _, shark in ipairs(sharks:GetChildren()) do
		if shark:IsA("Model") then
			local body = shark:FindFirstChild("Body") or shark:FindFirstChild("HumanoidRootPart") or shark.PrimaryPart
			if body then return shark, body end
		end
	end
	return nil
end

local function getSharkPart()
	local shark, body = getShark()
	if shark then
		-- Try various known paths for the shark's hittable part
		local part = shark:FindFirstChild("Body")
			or shark:FindFirstChild("Head")
			or shark:FindFirstChild("HumanoidRootPart")
			or shark.PrimaryPart
		if part and part:IsA("BasePart") then return part end
		-- If Body is a model, find a BasePart inside
		if part and part:IsA("Model") then
			return part:FindFirstChildWhichIsA("BasePart")
		end
		-- Fallback: first BasePart in shark
		return shark:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getWeaponTool()
	local character = LocalPlayer.Character
	if not character then return nil end
	-- Check currently equipped tool
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then return child end
	end
	-- Check backpack
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then return child end
		end
	end
	return nil
end

local function equipWeapon()
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if not backpack then return end
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum:EquipTool(tool) end
			return tool
		end
	end
end

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
titleLabel.Text = "SharkBite 2 Hub"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 40, 1, 0)
versionLabel.Position = UDim2.new(0, 160, 0, 0)
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

local tabNames = {"Main", "Shark", "Survivor", "Player", "ESP", "Fun"}
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
toggleBtn.Text = "SB"
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

-- ===================== SHARK INFO =====================
local function showSharkInfo()
	local sharks = workspace:FindFirstChild("Sharks")
	if not sharks then
		addLog("[INFO] No sharks folder found", COLORS.error)
		return
	end
	local count = 0
	for _, shark in ipairs(sharks:GetChildren()) do
		if shark:IsA("Model") then
			count = count + 1
			local hum = shark:FindFirstChildOfClass("Humanoid")
			local hp = hum and (math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)) or "N/A"
			addLog("[SHARK] " .. shark.Name .. " HP: " .. hp, COLORS.accent)
		end
	end
	if count == 0 then
		addLog("[INFO] No sharks alive", COLORS.textSecondary)
	end
end

local function showTeethInfo()
	pcall(function()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			addLog("[INFO] PlayerGui not found", COLORS.error)
			return
		end
		-- Search for teeth counter in various GUI structures
		local found = false
		for _, gui in ipairs(playerGui:GetDescendants()) do
			if gui:IsA("TextLabel") and (gui.Name:lower():find("teeth") or gui.Name:lower():find("tooth") or gui.Name:lower():find("money") or gui.Name:lower():find("currency")) then
				addLog("[TEETH] " .. gui.Name .. ": " .. gui.Text, COLORS.accent)
				found = true
			end
		end
		if not found then
			-- Try leaderstats
			local ls = LocalPlayer:FindFirstChild("leaderstats")
			if ls then
				for _, stat in ipairs(ls:GetChildren()) do
					addLog("[STAT] " .. stat.Name .. ": " .. tostring(stat.Value), COLORS.accent)
					found = true
				end
			end
		end
		if not found then
			addLog("[INFO] Could not find teeth/currency counter", COLORS.textSecondary)
		end
	end)
end

-- ===================== AUTO SHOOT SHARK (SURVIVOR) =====================
local function startAutoShootShark()
	-- Auto-equip weapon first
	equipWeapon()

	autoShootConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local sharkPart = getSharkPart()
			if not sharkPart then return end

			local character = LocalPlayer.Character
			if not character then return end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then return end

			-- Check distance (only shoot if reasonably close)
			local dist = (root.Position - sharkPart.Position).Magnitude
			if dist > 500 then return end

			-- Try to aim camera at shark
			pcall(function()
				workspace.CurrentCamera.CFrame = CFrame.new(root.Position, sharkPart.Position)
			end)

			-- Find and activate equipped tool
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Tool") then
					pcall(function() child:Activate() end)
					break
				end
			end

			-- Also try clicking the shark directly
			for _, desc in ipairs(sharkPart.Parent:GetDescendants()) do
				if desc:IsA("ClickDetector") then
					pcall(function() fireclickdetector(desc) end)
				end
			end
		end)
	end)
	addLog("[AUTO SHOOT] ON - Targeting shark!", COLORS.success)
end

local function stopAutoShootShark()
	if autoShootConnection then autoShootConnection:Disconnect() autoShootConnection = nil end
	addLog("[AUTO SHOOT] OFF", COLORS.error)
end

-- ===================== AUTO KILL AS SHARK =====================
local function startAutoKillAsShark()
	autoKillConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then return end

			-- Find nearest other player
			local nearest, nearDist = nil, math.huge
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					local theirRoot = player.Character:FindFirstChild("HumanoidRootPart")
					if theirRoot then
						local d = (root.Position - theirRoot.Position).Magnitude
						if d < nearDist then
							nearest = theirRoot
							nearDist = d
						end
					end
				end
			end

			if nearest then
				-- Teleport to nearest player rapidly
				root.CFrame = CFrame.new(root.Position, nearest.Position)
				root.AssemblyLinearVelocity = (nearest.Position - root.Position).Unit * 200

				-- If very close, try touch interactions
				if nearDist < 20 then
					pcall(function()
						root.CFrame = nearest.CFrame
					end)
				end
			end
		end)
	end)
	addLog("[AUTO KILL SHARK] ON - Hunting survivors!", COLORS.success)
end

local function stopAutoKillAsShark()
	if autoKillConnection then autoKillConnection:Disconnect() autoKillConnection = nil end
	addLog("[AUTO KILL SHARK] OFF", COLORS.error)
end

-- ===================== SHARK ESP =====================
local function enableSharkEsp()
	-- Clear old
	for _, hl in pairs(sharkEspHighlights) do pcall(function() hl:Destroy() end) end
	sharkEspHighlights = {}

	local function addSharkHighlight(shark)
		if sharkEspHighlights[shark] then return end
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(255, 0, 0)
		hl.OutlineColor = Color3.fromRGB(255, 50, 50)
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Adornee = shark
		hl.Parent = shark
		sharkEspHighlights[shark] = hl
	end

	-- Initial scan
	local sharks = workspace:FindFirstChild("Sharks")
	if sharks then
		for _, shark in ipairs(sharks:GetChildren()) do
			if shark:IsA("Model") then addSharkHighlight(shark) end
		end
		-- Watch for new sharks spawning
		local conn = sharks.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				_wait(0.5)
				if sharkEspEnabled then addSharkHighlight(child) end
			end
		end)
		table.insert(espConnections, conn)
	end
	addLog("[SHARK ESP] ON", COLORS.success)
end

local function disableSharkEsp()
	for _, hl in pairs(sharkEspHighlights) do pcall(function() hl:Destroy() end) end
	sharkEspHighlights = {}
	addLog("[SHARK ESP] OFF", COLORS.error)
end

-- ===================== PLAYER ESP =====================
local function addPlayerHighlight(player)
	if player == LocalPlayer then return end
	if playerEspHighlights[player] then return end
	local character = player.Character
	if not character or not character.Parent then return end
	pcall(function()
		local highlight = Instance.new("Highlight")
		highlight.Name = "ESPHighlight"
		highlight.FillColor = PLAYER_ESP_COLOR
		highlight.OutlineColor = PLAYER_ESP_OUTLINE
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Adornee = character
		highlight.Parent = character
		playerEspHighlights[player] = highlight
	end)
end

local function addPlayerNametag(player)
	if player == LocalPlayer then return end
	if playerEspNametags[player] then return end
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
		playerEspNametags[player] = bb
	end)
end

local function removePlayerHighlight(player)
	local hl = playerEspHighlights[player]
	if hl then pcall(function() hl:Destroy() end) end
	playerEspHighlights[player] = nil
end

local function removePlayerNametag(player)
	local tag = playerEspNametags[player]
	if tag then pcall(function() tag:Destroy() end) end
	playerEspNametags[player] = nil
end

local function cleanupStalePlayerEsp()
	local staleHL, staleNT = {}, {}
	for player, hl in pairs(playerEspHighlights) do
		local alive = false
		pcall(function() if hl and hl.Adornee and hl.Adornee.Parent then alive = true end end)
		if not alive then table.insert(staleHL, player) end
	end
	for player, tag in pairs(playerEspNametags) do
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
				if not playerEspHighlights[player] then addPlayerHighlight(player) end
				if not playerEspNametags[player] then addPlayerNametag(player) end
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
		if not playerEspEnabled then return end
		_wait(1)
		if playerEspEnabled then addPlayerHighlight(player) addPlayerNametag(player) end
	end)
	table.insert(espConnections, conn)
end

local function enablePlayerEsp()
	for _, player in ipairs(Players:GetPlayers()) do hookPlayerForEsp(player) end
	local addedConn = Players.PlayerAdded:Connect(function(player)
		if not playerEspEnabled then return end
		hookPlayerForEsp(player)
	end)
	table.insert(espConnections, addedConn)
	local count, skipped = playerEspScanAll()
	addLog("[PLAYER ESP] ON - " .. count .. " highlighted, " .. skipped .. " pending", COLORS.success)
	_spawn(function()
		while playerEspEnabled do
			_wait(REFRESH_INTERVAL)
			if not playerEspEnabled then break end
			playerEspScanAll()
		end
	end)
end

local function disablePlayerEsp()
	local allP = {}
	for player in pairs(playerEspHighlights) do table.insert(allP, player) end
	for _, player in ipairs(allP) do removePlayerHighlight(player) end
	local allN = {}
	for player in pairs(playerEspNametags) do table.insert(allN, player) end
	for _, player in ipairs(allN) do removePlayerNametag(player) end
	for _, conn in ipairs(espConnections) do pcall(function() conn:Disconnect() end) end
	espConnections = {}
	addLog("[PLAYER ESP] OFF", COLORS.error)
end

-- ===================== BOAT SPEED BOOST =====================
local function startBoatSpeed()
	boatSpeedConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or not hum.SeatPart then return end
			local seat = hum.SeatPart
			-- Boost VehicleSeat speed
			if seat:IsA("VehicleSeat") then
				seat.MaxSpeed = boatSpeedValue
				seat.Torque = boatSpeedValue * 2
			else
				-- For regular seats, push the boat forward
				local parent = seat.Parent
				if parent then
					local primary = (parent:IsA("Model") and parent.PrimaryPart) or seat
					local look = primary.CFrame.LookVector
					primary.AssemblyLinearVelocity = primary.AssemblyLinearVelocity + look * 3
				end
			end
		end)
	end)
	addLog("[BOAT SPEED] ON - Speed: " .. boatSpeedValue, COLORS.success)
end

local function stopBoatSpeed()
	if boatSpeedConnection then boatSpeedConnection:Disconnect() boatSpeedConnection = nil end
	addLog("[BOAT SPEED] OFF", COLORS.error)
end

-- ===================== TELEPORT TO SHARK =====================
local function teleportToShark()
	pcall(function()
		local sharkPart = getSharkPart()
		if not sharkPart then
			addLog("[TP] No shark found!", COLORS.error)
			return
		end
		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = sharkPart.CFrame + Vector3.new(0, 10, 0)
			addLog("[TP] Teleported to shark!", COLORS.success)
		end
	end)
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
		savedPhysProps = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				savedPhysProps[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
			end
		end

		-- Enable noclip so we can move freely while spinning
		if not noclipEnabled then noclipEnabled = true startNoclip() end
		_wait(0.1)

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
		flingConnection2 = _spawn(function()
			while flingEnabled do
				if spinBAV and spinBAV.Parent then
					spinBAV.AngularVelocity = Vector3.new(flingPower, flingPower, flingPower)
				end
				_wait(0.15)
				if spinBAV and spinBAV.Parent then
					spinBAV.AngularVelocity = Vector3.new(0, 0, 0)
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

-- =====================================================================
-- ======================== BUILD MAIN TAB ============================
-- =====================================================================
do
	local tab = tabFrames["Main"]

	createSectionLabel(tab, "Info", 1)
	createInfoLabel(tab, "SharkBite 2 Hub v1.0", 2)
	createInfoLabel(tab, "SX The Revival", 3)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

	createSectionLabel(tab, "Quick Info", 5)

	createActionButton(tab, "Show Shark Info", 6, function()
		showSharkInfo()
	end)
	createActionButton(tab, "Show My Teeth", 7, function()
		showTeethInfo()
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 8
	spacer2.Parent = tab

	createSectionLabel(tab, "Log", 9)

	logFrame = Instance.new("ScrollingFrame")
	logFrame.Size = UDim2.new(1, 0, 0, 100)
	logFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 12)
	logFrame.BorderSizePixel = 0
	logFrame.ScrollBarThickness = 3
	logFrame.ScrollBarImageColor3 = COLORS.accent
	logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	logFrame.LayoutOrder = 10
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
-- ======================== BUILD SHARK TAB ===========================
-- =====================================================================
do
	local tab = tabFrames["Shark"]

	createSectionLabel(tab, "Shark Controls", 1)

	createToggle(tab, "Auto Kill (As Shark)", 2, function(on)
		autoKillAsSharkEnabled = on
		if on then startAutoKillAsShark() else stopAutoKillAsShark() end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 3
	spacer.Parent = tab

	createSectionLabel(tab, "Info", 4)
	createInfoLabel(tab, "Enable when you are the shark", 5)
	createInfoLabel(tab, "Auto-rams into nearest survivor", 6)
end

-- =====================================================================
-- ======================== BUILD SURVIVOR TAB ========================
-- =====================================================================
do
	local tab = tabFrames["Survivor"]

	createSectionLabel(tab, "Combat", 1)

	createToggle(tab, "Auto Shoot Shark", 2, function(on)
		autoShootSharkEnabled = on
		if on then startAutoShootShark() else stopAutoShootShark() end
	end)
	createActionButton(tab, "Equip Weapon", 3, function()
		local tool = equipWeapon()
		if tool then
			addLog("[EQUIP] Equipped: " .. tool.Name, COLORS.success)
		else
			addLog("[EQUIP] No weapon found in backpack", COLORS.error)
		end
	end)
	createActionButton(tab, "Teleport to Shark", 4, function()
		teleportToShark()
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 5
	spacer.Parent = tab

	createSectionLabel(tab, "Boat", 6)

	createToggle(tab, "Boat Speed Boost (Sit First)", 7, function(on)
		boatSpeedEnabled = on
		if on then startBoatSpeed() else stopBoatSpeed() end
	end)
	createSlider(tab, "Boat Speed", 50, 500, boatSpeedValue, 8, function(val)
		boatSpeedValue = val
	end)
end

-- =====================================================================
-- ======================== BUILD PLAYER TAB ==========================
-- =====================================================================
do
	local tab = tabFrames["Player"]

	createSectionLabel(tab, "Movement", 1)

	createToggle(tab, "Fly", 2, function(on)
		flyEnabled = on
		if on then startFly() else stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 500, flySpeed, 3, function(val) flySpeed = val end)
	createToggle(tab, "Speed Boost", 4, function(on)
		speedEnabled = on
		if on then startSpeed() else stopSpeed() end
	end)
	createSlider(tab, "Walk Speed", 16, 500, speedValue, 5, function(val)
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
	createToggle(tab, "Noclip", 6, function(on)
		noclipEnabled = on
		if on then startNoclip() else stopNoclip() end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 7
	spacer.Parent = tab

	createSectionLabel(tab, "Character", 8)

	createToggle(tab, "God Mode", 9, function(on)
		godEnabled = on
		if on then startGod() else stopGod() end
	end)
	createToggle(tab, "Infinite Jump", 10, function(on)
		infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)
	createSlider(tab, "Jump Power", 10, 500, jumpPowerValue, 11, function(val)
		jumpPowerValue = val
		setJumpPower(val)
	end)
end

-- =====================================================================
-- ======================== BUILD ESP TAB =============================
-- =====================================================================
do
	local tab = tabFrames["ESP"]

	createSectionLabel(tab, "ESP", 1)

	createToggle(tab, "Shark ESP", 2, function(on)
		sharkEspEnabled = on
		if on then enableSharkEsp() else disableSharkEsp() end
	end)
	createToggle(tab, "Player ESP", 3, function(on)
		playerEspEnabled = on
		if on then enablePlayerEsp() else disablePlayerEsp() end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

	createSectionLabel(tab, "Info", 5)
	createInfoLabel(tab, "Shark ESP: Red highlight on sharks", 6)
	createInfoLabel(tab, "Player ESP: Green highlight + nametags", 7)
	createInfoLabel(tab, "ESP works through walls", 8)
end

-- =====================================================================
-- ======================== BUILD FUN TAB =============================
-- =====================================================================
do
	local tab = tabFrames["Fun"]

	createSectionLabel(tab, "Fling", 1)

	createToggle(tab, "Spin Fling", 2, function(on)
		flingEnabled = on
		if on then startFling() else stopFling() end
	end)
	createSlider(tab, "Fling Power", 1000, 99999, flingPower, 3, function(val) flingPower = val end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

	createSectionLabel(tab, "Visual", 5)

	createToggle(tab, "Spin", 6, function(on)
		spinEnabled = on
		if on then startSpin() else stopSpin() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 7
	spacer2.Parent = tab

	createSectionLabel(tab, "Emotes", 8)

	createActionButton(tab, "Emote 1", 9, function()
		playJerkEmote()
	end)
	createActionButton(tab, "Dance", 10, function()
		playEmote(507771019, 1, 10)
		addLog("[EMOTE] Dance!", COLORS.success)
	end)
	createActionButton(tab, "Dab", 11, function()
		playEmote(183412246, 1, 3)
		addLog("[EMOTE] Dab!", COLORS.success)
	end)
	createActionButton(tab, "Stop Emote", 12, function()
		stopEmote()
		addLog("[EMOTE] Stopped", COLORS.error)
	end)
end

-- =====================================================================
-- ======================== CHAT COMMANDS =============================
-- =====================================================================
local commands = {}

commands["autoshoot"] = function() autoShootSharkEnabled = true startAutoShootShark() end
commands["unautoshoot"] = function() autoShootSharkEnabled = false stopAutoShootShark() end
commands["autokill"] = function() autoKillAsSharkEnabled = true startAutoKillAsShark() end
commands["unautokill"] = function() autoKillAsSharkEnabled = false stopAutoKillAsShark() end
commands["sharkesp"] = function() sharkEspEnabled = true enableSharkEsp() end
commands["unsharkesp"] = function() sharkEspEnabled = false disableSharkEsp() end
commands["esp"] = function() playerEspEnabled = true enablePlayerEsp() end
commands["unesp"] = function() playerEspEnabled = false disablePlayerEsp() end
commands["boatspeed"] = function(args)
	local v = tonumber(args[1])
	if v then boatSpeedValue = v end
	boatSpeedEnabled = true
	startBoatSpeed()
end
commands["unboatspeed"] = function() boatSpeedEnabled = false stopBoatSpeed() end
commands["fly"] = function() flyEnabled = true startFly() end
commands["unfly"] = function() flyEnabled = false stopFly() end
commands["noclip"] = function() noclipEnabled = true startNoclip() end
commands["unnoclip"] = function() noclipEnabled = false stopNoclip() end
commands["speed"] = function(args) local v = tonumber(args[1]) if v then speedValue = v end speedEnabled = true startSpeed() end
commands["unspeed"] = function() speedEnabled = false stopSpeed() end
commands["god"] = function() godEnabled = true startGod() end
commands["ungod"] = function() godEnabled = false stopGod() end
commands["infjump"] = function() infJumpEnabled = true startInfJump() end
commands["uninfjump"] = function() infJumpEnabled = false stopInfJump() end
commands["fling"] = function() flingEnabled = true startFling() end
commands["unfling"] = function() flingEnabled = false stopFling() end
commands["spin"] = function() spinEnabled = true startSpin() end
commands["unspin"] = function() spinEnabled = false stopSpin() end
commands["tpshark"] = function() teleportToShark() end
commands["equip"] = function()
	local tool = equipWeapon()
	if tool then addLog("[EQUIP] Equipped: " .. tool.Name, COLORS.success)
	else addLog("[EQUIP] No weapon found", COLORS.error) end
end
commands["sharkinfo"] = function() showSharkInfo() end
commands["emote1"] = function() playJerkEmote() end
commands["dance"] = function() playEmote(507771019, 1, 10) addLog("[EMOTE] Dance!", COLORS.success) end
commands["dab"] = function() playEmote(183412246, 1, 3) addLog("[EMOTE] Dab!", COLORS.success) end
commands["stopemote"] = function() stopEmote() addLog("[EMOTE] Stopped", COLORS.error) end
commands["cmds"] = function()
	addLog("--- SharkBite 2 Commands ---", COLORS.accent)
	addLog(";autoshoot / ;unautoshoot (auto shoot shark)", COLORS.textSecondary)
	addLog(";autokill / ;unautokill (as shark)", COLORS.textSecondary)
	addLog(";sharkesp / ;unsharkesp", COLORS.textSecondary)
	addLog(";esp / ;unesp (player ESP)", COLORS.textSecondary)
	addLog(";boatspeed [val] / ;unboatspeed", COLORS.textSecondary)
	addLog(";fly / ;unfly    ;noclip / ;unnoclip", COLORS.textSecondary)
	addLog(";speed [val] / ;unspeed", COLORS.textSecondary)
	addLog(";god / ;ungod    ;infjump / ;uninfjump", COLORS.textSecondary)
	addLog(";fling / ;unfling    ;spin / ;unspin", COLORS.textSecondary)
	addLog(";tpshark    ;equip    ;sharkinfo", COLORS.textSecondary)
	addLog(";emote1  ;dance  ;dab  ;stopemote", COLORS.textSecondary)
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
	removePlayerHighlight(player)
	removePlayerNametag(player)
end)

LocalPlayer.CharacterAdded:Connect(function()
	if flyEnabled then
		stopFly() _wait(0.5)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then startFly() end
	end
	if flingEnabled then stopFling() _wait(0.5) startFling() end
	spinBAV = nil
	savedPhysProps = {}
	if speedEnabled then _wait(0.3) startSpeed() end
	if godEnabled then _wait(0.3) startGod() end
	if jumpPowerValue ~= 50 then _wait(0.3) setJumpPower(jumpPowerValue) end
	if autoShootSharkEnabled then
		stopAutoShootShark() _wait(0.5) startAutoShootShark()
	end
	if autoKillAsSharkEnabled then
		stopAutoKillAsShark() _wait(0.5) startAutoKillAsShark()
	end
end)

-- ===================== STARTUP =====================
addLog("SharkBite 2 Hub v1.0", COLORS.accent)
addLog("Type ;cmds for command list", COLORS.textSecondary)
addLog("Use Right Shift to toggle GUI", COLORS.textSecondary)
print("[SharkBite 2 Hub] v1.0 loaded")
