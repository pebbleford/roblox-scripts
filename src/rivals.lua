-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate() then return end

-- ================================================================
-- Synapse X The Revival - RIVALS Hub
-- Dedicated admin for RIVALS FPS
-- v1.1
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
local aimbotSmoothing = 5
local aimbotAimPart = "Head"  -- "Head", "HumanoidRootPart", "Torso"
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
local spinEnabled = false
local emoteActive = false

-- Values
local flySpeed = 80
local speedValue = 100
local flingPower = 99999
local jumpPowerValue = 50
local cameraFOV = 90
local hitboxSize = 10

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
mainWindow.Size = UDim2.new(0, 580, 0, 420)
mainWindow.Position = UDim2.new(0.5, -290, 0.5, -210)
mainWindow.BackgroundColor3 = COLORS.bg
mainWindow.BorderSizePixel = 0
mainWindow.Active = true
mainWindow.Parent = screenGui
addCorner(mainWindow, 8)
addStroke(mainWindow, COLORS.border, 2)

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
	tabBtn.Size = UDim2.new(0, 96, 1, 0)
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

-- ===================== BUTTON LOGIC =====================
minimizeBtn.MouseButton1Click:Connect(function()
	mainWindow.Visible = false
	toggleBtn.Visible = true
	windowVisible = false
end)

closeBtn.MouseButton1Click:Connect(function()
	mainWindow.Visible = false
	toggleBtn.Visible = true
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
local function getClosestPlayerInFOV()
	local cam = workspace.CurrentCamera
	local closest = nil
	local closestDist = aimbotFOV
	local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			-- Team check
			local skipTeam = false
			if teamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
				skipTeam = true
			end

			if not skipTeam then
				local character = player.Character
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					local targetPart = character:FindFirstChild(aimbotAimPart) or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
					if targetPart then
						local screenPos, onScreen = cam:WorldToViewportPoint(targetPart.Position)
						if onScreen then
							local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
							if screenDist < closestDist then
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

			-- Method 1: mousemoverel (most reliable in FPS games - moves actual mouse)
			local screenPos = cam:WorldToViewportPoint(targetPos)
			local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
			local delta = Vector2.new(screenPos.X - screenCenter.X, screenPos.Y - screenCenter.Y)

			-- Apply smoothing (lower = snappier)
			local moveX = delta.X / aimbotSmoothing
			local moveY = delta.Y / aimbotSmoothing

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
						-- Team check
						local skipTeam = false
						if teamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
							skipTeam = true
						end
						if not skipTeam then
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
			local isEnemy = true
			if teamCheck and player.Team and LocalPlayer.Team then
				isEnemy = player.Team ~= LocalPlayer.Team
			end
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
					local skipTeam = false
					if teamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
						skipTeam = true
					end
					if not skipTeam then
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
	createInfoLabel(tab, "RIVALS Hub v1.1", 2)
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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 6
	spacer.Parent = tab

	createSectionLabel(tab, "Automation", 7)

	createToggle(tab, "Silent Aim", 8, function(on)
		silentAimEnabled = on
		if on then startSilentAim() else stopSilentAim() end
	end)
	createToggle(tab, "TriggerBot", 9, function(on)
		triggerBotEnabled = on
		if on then startTriggerBot() else stopTriggerBot() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 10
	spacer2.Parent = tab

	createSectionLabel(tab, "Visual", 11)

	createToggle(tab, "FOV Circle", 12, function(on)
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

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 9
	spacer.Parent = tab

	createSectionLabel(tab, "Camera", 10)

	createSlider(tab, "Camera FOV", 50, 120, cameraFOV, 11, function(val)
		cameraFOV = val
		setGameFOV(val)
	end)
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
	addLog(";aimbot / ;unaimbot (hold RMB)", COLORS.textSecondary)
	addLog(";silentaim / ;unsilentaim", COLORS.textSecondary)
	addLog(";triggerbot / ;untriggerbot", COLORS.textSecondary)
	addLog(";esp / ;unesp", COLORS.textSecondary)
	addLog(";norecoil / ;unnorecoil", COLORS.textSecondary)
	addLog(";nospread / ;unnospread", COLORS.textSecondary)
	addLog(";rapidfire / ;unrapidfire", COLORS.textSecondary)
	addLog(";hitbox [size] / ;unhitbox", COLORS.textSecondary)
	addLog(";fullbright / ;unfullbright", COLORS.textSecondary)
	addLog(";fov [value]", COLORS.textSecondary)
	addLog(";fly / ;unfly    ;noclip / ;unnoclip", COLORS.textSecondary)
	addLog(";speed [val] / ;unspeed", COLORS.textSecondary)
	addLog(";infjump / ;uninfjump", COLORS.textSecondary)
	addLog(";fling / ;unfling    ;spin / ;unspin", COLORS.textSecondary)
	addLog(";emote1  ;dance  ;dab  ;stopemote", COLORS.textSecondary)
	addLog(";rejoin  ;serverhop", COLORS.textSecondary)
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
end)

-- ===================== STARTUP =====================
addLog("RIVALS Hub v1.1", COLORS.accent)
addLog("Type ;cmds for command list", COLORS.textSecondary)
addLog("Use Right Shift to toggle GUI", COLORS.textSecondary)
print("[RIVALS Hub] v1.1 loaded")
