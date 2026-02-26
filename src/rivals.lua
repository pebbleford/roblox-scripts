-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("rivals") then return end

-- ================================================================
-- Pebbleford Hub - RIVALS Hub
-- Dedicated admin for RIVALS FPS
-- v1.4
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

-- ===================== STATE =====================
-- Combat
local aimbotEnabled = false
local silentAimEnabled = false
local triggerBotEnabled = false
local aimbotKey = Enum.UserInputType.MouseButton2  -- Right click to aim
local aimbotFOV = 200
local aimbotSmoothing = 2
local aimbotAimPart = "Head"  -- "Head", "HumanoidRootPart", "Torso"
local aimbotMaxDist = 300
local aimbotWallCheck = true
local teamCheck = true

-- ESP
local espEnabled = false
local espBoxEnabled = false
local espTracerEnabled = false
local espHealthBar = true
local espNameEnabled = true
local espDistEnabled = true
local fovCircleEnabled = false

-- Gun Mods
local noRecoilEnabled = false
local noSpreadEnabled = false
local rapidFireEnabled = false

-- Player
local flyEnabled = false
local noclipEnabled = false
local speedEnabled = false
local infJumpEnabled = false
local fovChangerEnabled = false
local fullbrightEnabled = false
local hitboxExpandEnabled = false

-- Fun
local flingEnabled = false
local walkFlingEnabled = false
local spinEnabled = false
local seizureEnabled = false
local headlessEnabled = false
local emoteActive = false

-- Combat (new)
local autoFireEnabled = false
local killAuraEnabled = false

-- ESP (new)
local noFogEnabled = false
local chamsEnabled = false

-- Player (new)
local godEnabled = false
local invisibleEnabled = false
local antiAfkEnabled = false
local bunnyHopEnabled = false
local spectating = false
local selectedPlayer = nil

-- Values
local flySpeed = 80
local speedValue = 100
local flingPower = 99999
local walkFlingPower = 10000
local jumpPowerValue = 50
local cameraFOV = 90
local hitboxSize = 10
local killAuraRange = 15
local gravityValue = 196.2

-- Connections
local aimbotConnection = nil
local silentAimHook = nil
local triggerBotConnection = nil
local espObjects = {}  -- stores all ESP drawing objects per player
local espUpdateConnection = nil
local espPlayerAddedConnection = nil
local espCharConnections = {}
local fovCircle = nil
local noRecoilConnection = nil
local noSpreadConnection = nil
local rapidFireConnection = nil
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
local hitboxConnection = nil
local emoteTracks = {}
local emoteConnection = nil
local autoFireConnection = nil
local killAuraConnection = nil
local noFogOrigFogStart = nil
local noFogOrigFogEnd = nil
local chamsObjects = {}
local chamsCharConnections = {}
local chamsPlayerAddedConnection = nil
local godConnection = nil
local savedTransparencies = {}
local antiAfkConnection = nil
local bunnyHopConnection = nil
local walkFlingThread = nil
local walkFlingProps = {}
local walkFlingConnection = nil
local seizureConnection = nil
local headlessSavedParts = {}
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

-- Accent line under title
local titleAccent = Instance.new("Frame")
titleAccent.Size = UDim2.new(1, 0, 0, 2)
titleAccent.Position = UDim2.new(0, 0, 1, 0)
titleAccent.BackgroundColor3 = COLORS.accent
titleAccent.BorderSizePixel = 0
titleAccent.Parent = titleBar

-- Logo icon (purple square with R)
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
logoText.Text = "R"
logoText.TextColor3 = COLORS.textPrimary
logoText.Font = Enum.Font.GothamBold
logoText.TextSize = 12
logoText.Parent = logoIcon

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -120, 1, 0)
titleLabel.Position = UDim2.new(0, 34, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "RIVALS Hub"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 40, 1, 0)
versionLabel.Position = UDim2.new(0, 130, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.4"
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

local tabNames = {"Main", "Combat", "ESP", "GunMods", "Player", "Fun"}
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

	-- Active indicator (bottom accent line)
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
toggleBtn.Text = "RV"
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
	if dist > aimbotMaxDist then return false end

	return true
end

local function isTargetVisible(targetPart)
	if not aimbotWallCheck then return true end
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
	if not teamCheck then return false end
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
	local closestDist = aimbotFOV
	local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local skipTeam = shouldSkipTeammate(player)

			if not skipTeam and isPlayerInMatch(player) then
				local character = player.Character
				local targetPart = character:FindFirstChild(aimbotAimPart) or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
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
		if input.UserInputType == aimbotKey or input.KeyCode == Enum.KeyCode.Q then
			aimbotHolding = true
		end
	end)
	aimbotInputEndedConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == aimbotKey or input.KeyCode == Enum.KeyCode.Q then
			aimbotHolding = false
		end
	end)

	-- Use Heartbeat (fires AFTER camera update) so our CFrame sticks instead of being overwritten
	aimbotConnection = RunService.Heartbeat:Connect(function()
		if not aimbotEnabled or not aimbotHolding then return end
		pcall(function()
			local cam = workspace.CurrentCamera
			local target = getClosestPlayerInFOV()
			if not target then return end

			local targetPos = target.Position
			local camPos = cam.CFrame.Position

			-- mousemoverel (most reliable in FPS games - moves actual mouse)
			local screenPos = cam:WorldToViewportPoint(targetPos)
			local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
			local delta = Vector2.new(screenPos.X - screenCenter.X, screenPos.Y - screenCenter.Y)

			-- Apply smoothing with sensitivity multiplier
			-- Mouse sensitivity in Roblox means 1 pixel of mousemoverel != 1 pixel on screen
			-- Multiply by 1.5 to compensate for typical sensitivity scaling
			local sensitivity = 1.5
			local moveX = (delta.X / aimbotSmoothing) * sensitivity
			local moveY = (delta.Y / aimbotSmoothing) * sensitivity

			-- Minimum movement threshold: prevents aimbot from stalling when close to target
			if math.abs(moveX) < 1 and math.abs(delta.X) > 1 then
				moveX = delta.X > 0 and 1 or -1
			end
			if math.abs(moveY) < 1 and math.abs(delta.Y) > 1 then
				moveY = delta.Y > 0 and 1 or -1
			end

			-- Use mousemoverel if available (works on most executors)
			if mousemoverel then
				mousemoverel(moveX, moveY)
			else
				-- Fallback: direct CFrame set (may be overwritten by game camera)
				local currentCF = cam.CFrame
				local targetCF = CFrame.new(camPos, targetPos)
				cam.CFrame = currentCF:Lerp(targetCF, 1 / aimbotSmoothing)
			end
		end)
	end)
	addLog("[AIMBOT] ON (Hold RMB or Q)", COLORS.success)
end

local function stopAimbot()
	if aimbotConnection then aimbotConnection:Disconnect() aimbotConnection = nil end
	if aimbotInputBeganConn then aimbotInputBeganConn:Disconnect() aimbotInputBeganConn = nil end
	if aimbotInputEndedConn then aimbotInputEndedConn:Disconnect() aimbotInputEndedConn = nil end
	aimbotHolding = false
	addLog("[AIMBOT] OFF", COLORS.error)
end

-- ===================== SILENT AIM =====================
local function startSilentAim()
	-- Try to hook mouse methods to redirect aim
	pcall(function()
		local mt = getrawmetatable(game)
		if mt and setreadonly then
			local oldNamecall = mt.__namecall
			setreadonly(mt, false)
			mt.__namecall = newcclosure(function(self, ...)
				local method = getnamecallmethod()
				if silentAimEnabled and (method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "Raycast") then
					local target = getClosestPlayerInFOV()
					if target then
						-- Redirect ray toward target
						local args = {...}
						if method == "Raycast" and typeof(args[1]) == "Vector3" then
							local origin = args[1]
							local direction = (target.Position - origin).Unit * 1000
							return oldNamecall(self, origin, direction, select(3, ...))
						end
					end
				end
				return oldNamecall(self, ...)
			end)
			setreadonly(mt, true)
			silentAimHook = true
		end
	end)

	-- Fallback: if no hook available, use camera manipulation (less reliable)
	if not silentAimHook then
		addLog("[SILENT AIM] Fallback mode (no hook support)", COLORS.textSecondary)
	end
	addLog("[SILENT AIM] ON", COLORS.success)
end

local function stopSilentAim()
	silentAimEnabled = false
	-- Note: hooks can't easily be undone, they check silentAimEnabled flag
	addLog("[SILENT AIM] OFF", COLORS.error)
end

-- ===================== TRIGGERBOT =====================
local function startTriggerBot()
	triggerBotConnection = RunService.Heartbeat:Connect(function()
		if not triggerBotEnabled then return end
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
	if triggerBotConnection then triggerBotConnection:Disconnect() triggerBotConnection = nil end
	addLog("[TRIGGERBOT] OFF", COLORS.error)
end

-- ===================== ESP SYSTEM =====================
local function enableESP()
	local function addPlayerESP(player)
		if player == LocalPlayer then return end

		local function updateESP()
			-- Remove old
			if espObjects[player] then
				for _, obj in pairs(espObjects[player]) do
					pcall(function()
						if typeof(obj) == "RBXScriptConnection" then
							obj:Disconnect()
						else
							obj:Destroy()
						end
					end)
				end
			end
			espObjects[player] = {}

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
			table.insert(espObjects[player], hl)

			-- BillboardGui for name + health + distance
			local head = character:FindFirstChild("Head")
			local adornPart = head or root
			local bb = Instance.new("BillboardGui")
			bb.Adornee = adornPart
			bb.Size = UDim2.new(0, 200, 0, 60)
			bb.StudsOffset = Vector3.new(0, 3.5, 0)
			bb.AlwaysOnTop = true
			bb.Parent = adornPart
			table.insert(espObjects[player], bb)

			-- Name label
			if espNameEnabled then
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
			if espHealthBar then
				local healthBg = Instance.new("Frame")
				healthBg.Size = UDim2.new(0.7, 0, 0, 5)
				healthBg.Position = UDim2.new(0.15, 0, 0, 18)
				healthBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				healthBg.BorderSizePixel = 0
				healthBg.Parent = bb
				Instance.new("UICorner", healthBg).CornerRadius = UDim.new(0, 3)
				table.insert(espObjects[player], healthBg)

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
				table.insert(espObjects[player], healthConn)
			end

			-- Distance label
			if espDistEnabled then
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
				table.insert(espObjects[player], distConn)
			end
		end

		updateESP()
		-- Update on character changes
		local conn = player.CharacterAdded:Connect(function()
			_wait(1)
			if espEnabled then updateESP() end
		end)
		table.insert(espCharConnections, conn)
	end

	-- Initial ESP for all players
	for _, player in ipairs(Players:GetPlayers()) do
		addPlayerESP(player)
	end

	-- Watch for new players
	espPlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
		_wait(2)
		if espEnabled then addPlayerESP(player) end
	end)

	addLog("[ESP] ON", COLORS.success)
end

local function disableESP()
	if espPlayerAddedConnection then espPlayerAddedConnection:Disconnect() espPlayerAddedConnection = nil end
	for _, conn in ipairs(espCharConnections) do
		pcall(function() conn:Disconnect() end)
	end
	espCharConnections = {}
	for player, objects in pairs(espObjects) do
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
	espObjects = {}
	addLog("[ESP] OFF", COLORS.error)
end

-- ===================== FOV CIRCLE =====================
local function createFOVCircle()
	-- Use a Frame with UICorner to simulate circle (works everywhere)
	if fovCircle then pcall(function() fovCircle:Destroy() end) end

	local gui = Instance.new("Frame")
	gui.Name = "FOVCircle"
	gui.Size = UDim2.new(0, aimbotFOV * 2, 0, aimbotFOV * 2)
	gui.Position = UDim2.new(0.5, -aimbotFOV, 0.5, -aimbotFOV)
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

	fovCircle = gui
	addLog("[FOV CIRCLE] ON - Radius: " .. aimbotFOV, COLORS.success)
end

local function destroyFOVCircle()
	if fovCircle then pcall(function() fovCircle:Destroy() end) fovCircle = nil end
	addLog("[FOV CIRCLE] OFF", COLORS.error)
end

local function updateFOVCircleSize()
	if fovCircle then
		fovCircle.Size = UDim2.new(0, aimbotFOV * 2, 0, aimbotFOV * 2)
		fovCircle.Position = UDim2.new(0.5, -aimbotFOV, 0.5, -aimbotFOV)
	end
end

-- ===================== GUN MODS: NO RECOIL =====================
local function startNoRecoil()
	noRecoilConnection = RunService.RenderStepped:Connect(function()
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
	if noRecoilConnection then noRecoilConnection:Disconnect() noRecoilConnection = nil end
	addLog("[NO RECOIL] OFF", COLORS.error)
end

-- ===================== GUN MODS: NO SPREAD =====================
local function startNoSpread()
	noSpreadConnection = RunService.RenderStepped:Connect(function()
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
	if noSpreadConnection then noSpreadConnection:Disconnect() noSpreadConnection = nil end
	addLog("[NO SPREAD] OFF", COLORS.error)
end

-- ===================== GUN MODS: RAPID FIRE =====================
local function startRapidFire()
	rapidFireConnection = RunService.Heartbeat:Connect(function()
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
	if rapidFireConnection then rapidFireConnection:Disconnect() rapidFireConnection = nil end
	addLog("[RAPID FIRE] OFF", COLORS.error)
end

-- ===================== HITBOX EXPANDER =====================
local function startHitboxExpand()
	hitboxConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					if not shouldSkipTeammate(player) then
						local head = player.Character:FindFirstChild("Head")
						if head and head:IsA("BasePart") then
							head.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
							head.Transparency = 0.8
							head.CanCollide = false
						end
					end
				end
			end
		end)
	end)
	addLog("[HITBOX] ON - Size: " .. hitboxSize, COLORS.success)
end

local function stopHitboxExpand()
	if hitboxConnection then hitboxConnection:Disconnect() hitboxConnection = nil end
	-- Restore head sizes
	pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local head = player.Character:FindFirstChild("Head")
				if head and head:IsA("BasePart") then
					head.Size = Vector3.new(1, 1, 1)
					head.Transparency = 0
				end
			end
		end
	end)
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
			_spawn(function()
				_wait(duration)
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

-- ===================== KILL AURA =====================
local function startKillAura()
	killAuraConnection = RunService.Heartbeat:Connect(function()
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
							if theirHRP and (myHRP.Position - theirHRP.Position).Magnitude <= killAuraRange then
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
	addLog("[KILL AURA] ON - Range: " .. killAuraRange, COLORS.success)
end

local function stopKillAura()
	if killAuraConnection then killAuraConnection:Disconnect() killAuraConnection = nil end
	addLog("[KILL AURA] OFF", COLORS.error)
end

-- ===================== AUTO FIRE =====================
local function startAutoFire()
	autoFireConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not autoFireEnabled then return end
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
	if autoFireConnection then autoFireConnection:Disconnect() autoFireConnection = nil end
	addLog("[AUTO FIRE] OFF", COLORS.error)
end

-- ===================== NO FOG =====================
local function startNoFog()
	noFogOrigFogStart = Lighting.FogStart
	noFogOrigFogEnd = Lighting.FogEnd
	Lighting.FogStart = 999999
	Lighting.FogEnd = 9999999
	addLog("[NO FOG] ON", COLORS.success)
end

local function stopNoFog()
	if noFogOrigFogStart then Lighting.FogStart = noFogOrigFogStart end
	if noFogOrigFogEnd then Lighting.FogEnd = noFogOrigFogEnd end
	addLog("[NO FOG] OFF", COLORS.error)
end

-- ===================== CHAMS =====================
local function enableChams()
	local function addPlayerChams(player)
		if player == LocalPlayer then return end
		local function updateChams()
			if chamsObjects[player] then
				for _, obj in pairs(chamsObjects[player]) do
					pcall(function()
						if typeof(obj) == "RBXScriptConnection" then obj:Disconnect()
						else obj:Destroy() end
					end)
				end
			end
			chamsObjects[player] = {}
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
			table.insert(chamsObjects[player], hl)
		end
		updateChams()
		local conn = player.CharacterAdded:Connect(function()
			_wait(1)
			if chamsEnabled then updateChams() end
		end)
		table.insert(chamsCharConnections, conn)
	end

	for _, player in ipairs(Players:GetPlayers()) do addPlayerChams(player) end
	chamsPlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
		_wait(2)
		if chamsEnabled then addPlayerChams(player) end
	end)
	addLog("[CHAMS] ON", COLORS.success)
end

local function disableChams()
	if chamsPlayerAddedConnection then chamsPlayerAddedConnection:Disconnect() chamsPlayerAddedConnection = nil end
	for _, conn in ipairs(chamsCharConnections) do pcall(function() conn:Disconnect() end) end
	chamsCharConnections = {}
	for player, objects in pairs(chamsObjects) do
		for _, obj in pairs(objects) do
			pcall(function()
				if typeof(obj) == "RBXScriptConnection" then obj:Disconnect()
				else obj:Destroy() end
			end)
		end
	end
	chamsObjects = {}
	addLog("[CHAMS] OFF", COLORS.error)
end

-- ===================== GOD MODE =====================
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

-- ===================== ANTI-AFK =====================
local function startAntiAfk()
	pcall(function()
		local VirtualUser = game:GetService("VirtualUser")
		antiAfkConnection = LocalPlayer.Idled:Connect(function()
			VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
			_wait(1)
			VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		end)
	end)
	addLog("[ANTI-AFK] ON", COLORS.success)
end

local function stopAntiAfk()
	if antiAfkConnection then antiAfkConnection:Disconnect() antiAfkConnection = nil end
	addLog("[ANTI-AFK] OFF", COLORS.error)
end

-- ===================== BUNNY HOP =====================
local function startBunnyHop()
	bunnyHopConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not bunnyHopEnabled then return end
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
	if bunnyHopConnection then bunnyHopConnection:Disconnect() bunnyHopConnection = nil end
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
				spectating = true
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
		spectating = false
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
		walkFlingProps = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				walkFlingProps[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
			end
		end

		-- Heartbeat: velocity spikes using AssemblyLinearVelocity
		walkFlingConnection = RunService.Heartbeat:Connect(function()
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end
				local rt = char:FindFirstChild("HumanoidRootPart")
				if not rt then return end
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hum then return end
				local moveDir = hum.MoveDirection
				if moveDir.Magnitude > 0.1 then
					rt.AssemblyLinearVelocity = moveDir.Unit * walkFlingPower + Vector3.new(0, 0, 0)
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
	if walkFlingConnection then walkFlingConnection:Disconnect() walkFlingConnection = nil end
	local character = LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				if walkFlingProps[part] then
					part.CustomPhysicalProperties = walkFlingProps[part]
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
	walkFlingProps = {}
	addLog("[WALK FLING] OFF", COLORS.error)
end

-- ===================== SEIZURE =====================
local function startSeizure()
	seizureConnection = RunService.Heartbeat:Connect(function()
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
	if seizureConnection then seizureConnection:Disconnect() seizureConnection = nil end
	addLog("[SEIZURE] OFF", COLORS.error)
end

-- ===================== HEADLESS =====================
local function startHeadless()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local head = character:FindFirstChild("Head")
		if not head then return end
		headlessSavedParts = {}
		headlessSavedParts.headTransparency = head.Transparency
		head.Transparency = 1
		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("Decal") then
				headlessSavedParts[child] = child.Transparency
				child.Transparency = 1
			elseif child:IsA("SpecialMesh") then
				headlessSavedParts[child] = child.Scale
				child.Scale = Vector3.new(0, 0, 0)
			end
		end
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				if handle then
					local att = handle:FindFirstChildOfClass("Attachment")
					if att and (att.Name == "HatAttachment" or att.Name == "HairAttachment" or att.Name == "FaceFrontAttachment" or att.Name == "FaceCenterAttachment") then
						headlessSavedParts[handle] = handle.Transparency
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
		if head and headlessSavedParts.headTransparency then
			head.Transparency = headlessSavedParts.headTransparency
		end
		for obj, val in pairs(headlessSavedParts) do
			if obj ~= "headTransparency" and typeof(obj) ~= "string" and obj and obj.Parent then
				if typeof(val) == "Vector3" then
					obj.Scale = val
				elseif typeof(val) == "number" then
					obj.Transparency = val
				end
			end
		end
		headlessSavedParts = {}
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
	createInfoLabel(tab, "RIVALS Hub v1.4", 2)
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

	createSectionLabel(tab, "Log", 9)

	logFrame = Instance.new("ScrollingFrame")
	logFrame.Size = UDim2.new(1, 0, 0, 100)
	logFrame.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
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
-- ======================== BUILD COMBAT TAB ==========================
-- =====================================================================
do
	local tab = tabFrames["Combat"]

	createSectionLabel(tab, "Aimbot", 1)

	createToggle(tab, "Aimbot (Hold RMB)", 2, function(on)
		aimbotEnabled = on
		if on then startAimbot() else stopAimbot() end
	end)
	createSlider(tab, "Aimbot FOV", 50, 500, aimbotFOV, 3, function(val)
		aimbotFOV = val
		updateFOVCircleSize()
	end)
	createSlider(tab, "Smoothing", 1, 20, aimbotSmoothing, 4, function(val)
		aimbotSmoothing = val
	end)
	createToggle(tab, "Team Check", 5, function(on)
		teamCheck = on
		if on then
			addLog("[TEAM CHECK] ON - Won't target teammates", COLORS.success)
		else
			addLog("[TEAM CHECK] OFF - Targeting everyone", COLORS.error)
		end
	end).setVisualState(true) -- Default on
	createSlider(tab, "Max Distance", 50, 1000, aimbotMaxDist, 6, function(val)
		aimbotMaxDist = val
	end)
	createToggle(tab, "Wall Check", 7, function(on)
		aimbotWallCheck = on
		if on then
			addLog("[WALL CHECK] ON - Only visible targets", COLORS.success)
		else
			addLog("[WALL CHECK] OFF - Aim through walls", COLORS.error)
		end
	end).setVisualState(true) -- Default on

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 8
	spacer.Parent = tab

	createSectionLabel(tab, "Automation", 9)

	createToggle(tab, "Silent Aim", 10, function(on)
		silentAimEnabled = on
		if on then startSilentAim() else stopSilentAim() end
	end)
	createToggle(tab, "TriggerBot", 11, function(on)
		triggerBotEnabled = on
		if on then startTriggerBot() else stopTriggerBot() end
	end)
	createToggle(tab, "Auto Fire", 12, function(on)
		autoFireEnabled = on
		if on then startAutoFire() else stopAutoFire() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 13
	spacer2.Parent = tab

	createSectionLabel(tab, "Aim Part", 14)

	local aimPartLabel = createInfoLabel(tab, "Current: " .. aimbotAimPart, 15)

	createActionButton(tab, "Aim: Head", 16, function()
		aimbotAimPart = "Head"
		aimPartLabel.Text = "Current: Head"
		addLog("[AIM PART] Head", COLORS.success)
	end)
	createActionButton(tab, "Aim: Torso", 17, function()
		aimbotAimPart = "HumanoidRootPart"
		aimPartLabel.Text = "Current: HumanoidRootPart"
		addLog("[AIM PART] Torso", COLORS.success)
	end)
	createActionButton(tab, "Aim: Random", 18, function()
		aimbotAimPart = (math.random(1, 2) == 1) and "Head" or "HumanoidRootPart"
		aimPartLabel.Text = "Current: " .. aimbotAimPart
		addLog("[AIM PART] Random -> " .. aimbotAimPart, COLORS.success)
	end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 19
	spacer3.Parent = tab

	createSectionLabel(tab, "Kill Zone", 20)

	createToggle(tab, "Kill Aura", 21, function(on)
		killAuraEnabled = on
		if on then startKillAura() else stopKillAura() end
	end)
	createSlider(tab, "Kill Aura Range", 5, 30, killAuraRange, 22, function(val) killAuraRange = val end)

	local spacer4 = Instance.new("Frame")
	spacer4.Size = UDim2.new(1, 0, 0, 4)
	spacer4.BackgroundTransparency = 1
	spacer4.LayoutOrder = 23
	spacer4.Parent = tab

	createSectionLabel(tab, "Visual", 24)

	createToggle(tab, "FOV Circle", 25, function(on)
		fovCircleEnabled = on
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
		espEnabled = on
		if on then enableESP() else disableESP() end
	end)
	createToggle(tab, "Show Names", 3, function(on)
		espNameEnabled = on
		if espEnabled then
			disableESP()
			enableESP()
		end
	end).setVisualState(true) -- Default on
	createToggle(tab, "Show Health Bars", 4, function(on)
		espHealthBar = on
		if espEnabled then
			disableESP()
			enableESP()
		end
	end).setVisualState(true) -- Default on
	createToggle(tab, "Show Distance", 5, function(on)
		espDistEnabled = on
		if espEnabled then
			disableESP()
			enableESP()
		end
	end).setVisualState(true) -- Default on

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 6
	spacer.Parent = tab

	createSectionLabel(tab, "World", 7)

	createToggle(tab, "Fullbright", 8, function(on)
		fullbrightEnabled = on
		if on then startFullbright() else stopFullbright() end
	end)
	createToggle(tab, "No Fog", 9, function(on)
		noFogEnabled = on
		if on then startNoFog() else stopNoFog() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 10
	spacer2.Parent = tab

	createSectionLabel(tab, "Chams", 11)

	createToggle(tab, "Chams (Through Walls)", 12, function(on)
		chamsEnabled = on
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
		noRecoilEnabled = on
		if on then startNoRecoil() else stopNoRecoil() end
	end)
	createToggle(tab, "No Spread", 3, function(on)
		noSpreadEnabled = on
		if on then startNoSpread() else stopNoSpread() end
	end)
	createToggle(tab, "Rapid Fire", 4, function(on)
		rapidFireEnabled = on
		if on then startRapidFire() else stopRapidFire() end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 5
	spacer.Parent = tab

	createSectionLabel(tab, "Hitbox", 6)

	createToggle(tab, "Hitbox Expander", 7, function(on)
		hitboxExpandEnabled = on
		if on then startHitboxExpand() else stopHitboxExpand() end
	end)
	createSlider(tab, "Hitbox Size", 2, 30, hitboxSize, 8, function(val)
		hitboxSize = val
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
	createToggle(tab, "Infinite Jump", 7, function(on)
		infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)
	createSlider(tab, "Jump Power", 10, 500, jumpPowerValue, 8, function(val)
		jumpPowerValue = val
		setJumpPower(val)
	end)
	createToggle(tab, "Bunny Hop", 9, function(on)
		bunnyHopEnabled = on
		if on then startBunnyHop() else stopBunnyHop() end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 10
	spacer.Parent = tab

	createSectionLabel(tab, "Survival", 11)

	createToggle(tab, "God Mode", 12, function(on)
		godEnabled = on
		if on then startGod() else stopGod() end
	end)
	createToggle(tab, "Invisible", 13, function(on)
		invisibleEnabled = on
		if on then startInvisible() else stopInvisible() end
	end)
	createToggle(tab, "Anti-AFK", 14, function(on)
		antiAfkEnabled = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 15
	spacer2.Parent = tab

	createSectionLabel(tab, "Physics", 16)

	createSlider(tab, "Gravity", 0, 1000, 196, 17, function(val)
		gravityValue = val
		setGravity(val)
	end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 18
	spacer3.Parent = tab

	createSectionLabel(tab, "Camera", 19)

	createSlider(tab, "Camera FOV", 50, 120, cameraFOV, 20, function(val)
		cameraFOV = val
		setGameFOV(val)
	end)

	local spacer4 = Instance.new("Frame")
	spacer4.Size = UDim2.new(1, 0, 0, 4)
	spacer4.BackgroundTransparency = 1
	spacer4.LayoutOrder = 21
	spacer4.Parent = tab

	createSectionLabel(tab, "Player Target", 22)

	local selectedPlayerLabel = createInfoLabel(tab, "Selected: None", 23)

	createActionButton(tab, "Teleport to Player", 24, function()
		if selectedPlayer then teleportToPlayer(selectedPlayer)
		else addLog("[TP] No player selected!", COLORS.error) end
	end)
	createActionButton(tab, "Spectate Player", 25, function()
		if selectedPlayer then spectatePlayer(selectedPlayer)
		else addLog("[SPECTATE] No player selected!", COLORS.error) end
	end)
	createActionButton(tab, "Unspectate", 26, function()
		unspectate()
	end)

	local spacer5 = Instance.new("Frame")
	spacer5.Size = UDim2.new(1, 0, 0, 4)
	spacer5.BackgroundTransparency = 1
	spacer5.LayoutOrder = 27
	spacer5.Parent = tab

	createSectionLabel(tab, "Player List", 28)

	-- Player list container
	local playerListFrame = Instance.new("Frame")
	playerListFrame.Size = UDim2.new(1, 0, 0, 0)
	playerListFrame.BackgroundTransparency = 1
	playerListFrame.AutomaticSize = Enum.AutomaticSize.Y
	playerListFrame.LayoutOrder = 29
	playerListFrame.Parent = tab

	local playerListLayout = Instance.new("UIListLayout")
	playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerListLayout.Padding = UDim.new(0, 3)
	playerListLayout.Parent = playerListFrame

	local function refreshPlayerList()
		for _, child in ipairs(playerListFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		local order = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				order = order + 1
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, 26)
				btn.BackgroundColor3 = COLORS.tabBg
				btn.Text = player.DisplayName .. " (@" .. player.Name .. ")"
				btn.TextColor3 = COLORS.textPrimary
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 11
				btn.TextTruncate = Enum.TextTruncate.AtEnd
				btn.LayoutOrder = order
				btn.Parent = playerListFrame
				addCorner(btn, 4)
				btn.MouseEnter:Connect(function() btn.BackgroundColor3 = COLORS.bgSecondary end)
				btn.MouseLeave:Connect(function()
					btn.BackgroundColor3 = (selectedPlayer == player) and COLORS.accentDark or COLORS.tabBg
				end)
				btn.MouseButton1Click:Connect(function()
					selectedPlayer = player
					selectedPlayerLabel.Text = "Selected: " .. player.DisplayName
					addLog("[SELECT] " .. player.DisplayName, COLORS.accent)
					-- Update button colors
					for _, c in ipairs(playerListFrame:GetChildren()) do
						if c:IsA("TextButton") then c.BackgroundColor3 = COLORS.tabBg end
					end
					btn.BackgroundColor3 = COLORS.accentDark
				end)
			end
		end
	end

	refreshPlayerList()
	Players.PlayerAdded:Connect(function() _wait(1) refreshPlayerList() end)
	Players.PlayerRemoving:Connect(function(player)
		if selectedPlayer == player then
			selectedPlayer = nil
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
		if on and walkFlingEnabled then
			walkFlingEnabled = false
			stopWalkFling()
		end
		flingEnabled = on
		if on then startFling() else stopFling() end
	end)
	createSlider(tab, "Fling Power", 1000, 99999, flingPower, 3, function(val) flingPower = val end)
	local walkFlingToggle = createToggle(tab, "Walk Fling", 4, function(on)
		if on and flingEnabled then
			flingEnabled = false
			stopFling()
		end
		walkFlingEnabled = on
		if on then startWalkFling() else stopWalkFling() end
	end)
	createSlider(tab, "Walk Fling Power", 1000, 50000, walkFlingPower, 5, function(val) walkFlingPower = val end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 6
	spacer.Parent = tab

	createSectionLabel(tab, "Visual", 7)

	createToggle(tab, "Spin", 8, function(on)
		spinEnabled = on
		if on then startSpin() else stopSpin() end
	end)
	createToggle(tab, "Seizure", 9, function(on)
		seizureEnabled = on
		if on then startSeizure() else stopSeizure() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 10
	spacer2.Parent = tab

	createSectionLabel(tab, "Character", 11)

	createActionButton(tab, "Headless", 12, function()
		if headlessEnabled then
			headlessEnabled = false
			stopHeadless()
		else
			headlessEnabled = true
			startHeadless()
		end
	end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 13
	spacer3.Parent = tab

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
commands["aimbot"] = function() aimbotEnabled = true startAimbot() end
commands["unaimbot"] = function() aimbotEnabled = false stopAimbot() end
commands["silentaim"] = function() silentAimEnabled = true startSilentAim() end
commands["unsilentaim"] = function() silentAimEnabled = false stopSilentAim() end
commands["triggerbot"] = function() triggerBotEnabled = true startTriggerBot() end
commands["untriggerbot"] = function() triggerBotEnabled = false stopTriggerBot() end

-- ESP
commands["esp"] = function() espEnabled = true enableESP() end
commands["unesp"] = function() espEnabled = false disableESP() end

-- Gun Mods
commands["norecoil"] = function() noRecoilEnabled = true startNoRecoil() end
commands["unnorecoil"] = function() noRecoilEnabled = false stopNoRecoil() end
commands["nospread"] = function() noSpreadEnabled = true startNoSpread() end
commands["unnospread"] = function() noSpreadEnabled = false stopNoSpread() end
commands["rapidfire"] = function() rapidFireEnabled = true startRapidFire() end
commands["unrapidfire"] = function() rapidFireEnabled = false stopRapidFire() end

-- Hitbox
commands["hitbox"] = function(args)
	local v = tonumber(args[1])
	if v then hitboxSize = v end
	hitboxExpandEnabled = true
	startHitboxExpand()
end
commands["unhitbox"] = function() hitboxExpandEnabled = false stopHitboxExpand() end

-- World
commands["fullbright"] = function() fullbrightEnabled = true startFullbright() end
commands["unfullbright"] = function() fullbrightEnabled = false stopFullbright() end

-- FOV
commands["fov"] = function(args)
	local v = tonumber(args[1])
	if v then
		cameraFOV = v
		setGameFOV(v)
		addLog("[FOV] Set to " .. v, COLORS.success)
	else
		addLog("[FOV] Usage: ;fov [50-120]", COLORS.error)
	end
end

-- Movement
commands["fly"] = function() flyEnabled = true startFly() end
commands["unfly"] = function() flyEnabled = false stopFly() end
commands["noclip"] = function() noclipEnabled = true startNoclip() end
commands["unnoclip"] = function() noclipEnabled = false stopNoclip() end
commands["speed"] = function(args)
	local v = tonumber(args[1])
	if v then speedValue = v end
	speedEnabled = true
	startSpeed()
end
commands["unspeed"] = function() speedEnabled = false stopSpeed() end
commands["infjump"] = function() infJumpEnabled = true startInfJump() end
commands["uninfjump"] = function() infJumpEnabled = false stopInfJump() end

-- Fun
commands["fling"] = function() flingEnabled = true startFling() end
commands["unfling"] = function() flingEnabled = false stopFling() end
commands["spin"] = function() spinEnabled = true startSpin() end
commands["unspin"] = function() spinEnabled = false stopSpin() end

-- Combat (new)
commands["autofire"] = function() autoFireEnabled = true startAutoFire() end
commands["unautofire"] = function() autoFireEnabled = false stopAutoFire() end
commands["killaura"] = function() killAuraEnabled = true startKillAura() end
commands["unkillaura"] = function() killAuraEnabled = false stopKillAura() end
commands["aimpart"] = function(args)
	local part = args[1] and args[1]:lower()
	if part == "head" then aimbotAimPart = "Head"
	elseif part == "torso" or part == "body" then aimbotAimPart = "HumanoidRootPart"
	elseif part == "random" then aimbotAimPart = (math.random(1, 2) == 1) and "Head" or "HumanoidRootPart"
	else addLog("[CMD] Usage: ;aimpart head/torso/random", COLORS.error) return end
	addLog("[AIM PART] Set to " .. aimbotAimPart, COLORS.success)
end

-- ESP (new)
commands["nofog"] = function() noFogEnabled = true startNoFog() end
commands["unnofog"] = function() noFogEnabled = false stopNoFog() end
commands["chams"] = function() chamsEnabled = true enableChams() end
commands["unchams"] = function() chamsEnabled = false disableChams() end

-- Player (new)
commands["god"] = function() godEnabled = true startGod() end
commands["ungod"] = function() godEnabled = false stopGod() end
commands["invisible"] = function() invisibleEnabled = true startInvisible() end
commands["uninvisible"] = function() invisibleEnabled = false stopInvisible() end
commands["antiafk"] = function() antiAfkEnabled = true startAntiAfk() end
commands["unantiafk"] = function() antiAfkEnabled = false stopAntiAfk() end
commands["bhop"] = function() bunnyHopEnabled = true startBunnyHop() end
commands["unbhop"] = function() bunnyHopEnabled = false stopBunnyHop() end
commands["gravity"] = function(args)
	local v = tonumber(args[1])
	if v then gravityValue = v setGravity(v) addLog("[GRAVITY] Set to " .. v, COLORS.success)
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
	if flingEnabled then flingEnabled = false stopFling() end
	walkFlingEnabled = true startWalkFling()
end
commands["unwalkfling"] = function() walkFlingEnabled = false stopWalkFling() end
commands["seizure"] = function() seizureEnabled = true startSeizure() end
commands["unseizure"] = function() seizureEnabled = false stopSeizure() end
commands["headless"] = function() headlessEnabled = true startHeadless() end
commands["unheadless"] = function() headlessEnabled = false stopHeadless() end

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
	-- Clean up ESP for leaving players
	if espObjects[player] then
		for _, obj in pairs(espObjects[player]) do
			pcall(function()
				if typeof(obj) == "RBXScriptConnection" then
					obj:Disconnect()
				else
					obj:Destroy()
				end
			end)
		end
		espObjects[player] = nil
	end
	-- Clean up Chams for leaving players
	if chamsObjects[player] then
		for _, obj in pairs(chamsObjects[player]) do
			pcall(function()
				if typeof(obj) == "RBXScriptConnection" then obj:Disconnect()
				else obj:Destroy() end
			end)
		end
		chamsObjects[player] = nil
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	_wait(0.5)

	-- Re-enable fly
	if flyEnabled then
		stopFly()
		_wait(0.3)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			startFly()
		end
	end

	-- Re-enable fling
	if flingEnabled then
		stopFling()
		_wait(0.3)
		startFling()
	end
	spinBAV = nil
	savedPhysProps = {}

	-- Re-enable speed
	if speedEnabled then
		_wait(0.3)
		startSpeed()
	end

	-- Re-enable noclip
	if noclipEnabled then
		_wait(0.1)
		startNoclip()
	end

	-- Re-enable infinite jump
	if infJumpEnabled then
		_wait(0.1)
		stopInfJump()
		startInfJump()
	end

	-- Re-apply jump power
	if jumpPowerValue ~= 50 then
		_wait(0.3)
		setJumpPower(jumpPowerValue)
	end

	-- Re-enable aimbot
	if aimbotEnabled then
		stopAimbot()
		_wait(0.2)
		startAimbot()
	end

	-- Re-enable ESP
	if espEnabled then
		disableESP()
		_wait(0.5)
		enableESP()
	end

	-- Re-enable gun mods
	if noRecoilEnabled then
		stopNoRecoil()
		_wait(0.1)
		startNoRecoil()
	end
	if noSpreadEnabled then
		stopNoSpread()
		_wait(0.1)
		startNoSpread()
	end
	if rapidFireEnabled then
		stopRapidFire()
		_wait(0.1)
		startRapidFire()
	end

	-- Re-enable hitbox expander
	if hitboxExpandEnabled then
		stopHitboxExpand()
		_wait(0.2)
		startHitboxExpand()
	end

	-- Re-apply camera FOV
	if cameraFOV ~= 90 then
		_wait(0.3)
		setGameFOV(cameraFOV)
	end

	-- Re-enable fullbright
	if fullbrightEnabled then
		_wait(0.2)
		startFullbright()
	end

	-- Re-enable no fog
	if noFogEnabled then
		_wait(0.1)
		startNoFog()
	end

	-- Re-enable god mode
	if godEnabled then
		if godConnection then godConnection:Disconnect() godConnection = nil end
		_wait(0.1)
		startGod()
	end

	-- Re-enable invisible
	if invisibleEnabled then
		savedTransparencies = {}
		_wait(0.3)
		startInvisible()
	end

	-- Re-enable bunny hop
	if bunnyHopEnabled then
		if bunnyHopConnection then bunnyHopConnection:Disconnect() bunnyHopConnection = nil end
		_wait(0.1)
		startBunnyHop()
	end

	-- Re-enable walk fling
	if walkFlingEnabled then
		stopWalkFling()
		_wait(0.5)
		startWalkFling()
	end

	-- Re-enable kill aura
	if killAuraEnabled then
		if killAuraConnection then killAuraConnection:Disconnect() killAuraConnection = nil end
		_wait(0.1)
		startKillAura()
	end

	-- Re-enable auto fire
	if autoFireEnabled then
		if autoFireConnection then autoFireConnection:Disconnect() autoFireConnection = nil end
		_wait(0.1)
		startAutoFire()
	end

	-- Re-enable chams
	if chamsEnabled then
		disableChams()
		_wait(0.5)
		enableChams()
	end

	-- Re-enable headless
	if headlessEnabled then
		headlessSavedParts = {}
		_wait(0.3)
		startHeadless()
	end

	-- Re-apply gravity
	if gravityValue ~= 196.2 then
		_wait(0.1)
		setGravity(gravityValue)
	end

	-- Re-enable seizure
	if seizureEnabled then
		if seizureConnection then seizureConnection:Disconnect() seizureConnection = nil end
		_wait(0.1)
		startSeizure()
	end

	-- Unspectate on death
	if spectating then
		unspectate()
	end
end)

-- ===================== STARTUP =====================
addLog("RIVALS Hub v1.4", COLORS.accent)
addLog("Type ;cmds for command list", COLORS.textSecondary)
addLog("Use Right Shift to toggle GUI", COLORS.textSecondary)
print("[RIVALS Hub] v1.4 loaded")
