-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("prisonlife") then return end

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
	["Really red"] = Color3.fromRGB(255, 0, 0),
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

-- ===================== MAIN WINDOW =====================
local windowW = 520
local windowH = 420

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

-- Shadow
local shadow = Instance.new("ImageLabel")
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

local titleAccent = Instance.new("Frame")
titleAccent.Size = UDim2.new(1, 0, 0, 2)
titleAccent.Position = UDim2.new(0, 0, 1, 0)
titleAccent.BackgroundColor3 = COLORS.accent
titleAccent.BorderSizePixel = 0
titleAccent.Parent = titleBar

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
logoText.Text = "P"
logoText.TextColor3 = COLORS.textPrimary
logoText.Font = Enum.Font.GothamBold
logoText.TextSize = 12
logoText.Parent = logoIcon

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -120, 1, 0)
titleLabel.Position = UDim2.new(0, 34, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Prison Life Hub"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 40, 1, 0)
versionLabel.Position = UDim2.new(0, 155, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.0"
versionLabel.TextColor3 = COLORS.accent
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextSize = 10
versionLabel.TextXAlignment = Enum.TextXAlignment.Left
versionLabel.Parent = titleBar

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

closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

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

-- ===================== TAB BAR =====================
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

local tabNames = {"Main", "Combat", "ESP", "Teleport", "Fun"}
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

	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(1, 0, 0, 2)
	indicator.Position = UDim2.new(0, 0, 1, -2)
	indicator.BackgroundColor3 = COLORS.accent
	indicator.BorderSizePixel = 0
	indicator.Visible = (tabName == "Main")
	indicator.Parent = tabBtn

	tabButtons[tabName] = tabBtn

	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = tabName .. "Content"
	contentFrame.Size = UDim2.new(1, -16, 1, -110)
	contentFrame.Position = UDim2.new(0, 8, 0, 68)
	contentFrame.BackgroundTransparency = 1
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 4
	contentFrame.ScrollBarImageColor3 = COLORS.accent
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	contentFrame.Visible = (tabName == "Main")
	contentFrame.Parent = mainWindow

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 4)
	contentLayout.Parent = contentFrame

	addPadding(contentFrame, 4, 4, 4, 4)
	tabFrames[tabName] = contentFrame
end

local activeTab = "Main"
local function setActiveTab(name)
	activeTab = name
	for tabName, frame in pairs(tabFrames) do
		frame.Visible = (tabName == name)
	end
	for tabName, btn in pairs(tabButtons) do
		btn.TextColor3 = (tabName == name) and COLORS.accent or COLORS.textDim
		btn.BackgroundTransparency = (tabName == name) and 0 or 1
		local ind = btn:FindFirstChild("Indicator")
		if ind then ind.Visible = (tabName == name) end
	end
end

for name, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function() setActiveTab(name) end)
end

-- ===================== LOG PANEL =====================
local logContainer = Instance.new("Frame")
logContainer.Size = UDim2.new(1, -16, 0, 36)
logContainer.Position = UDim2.new(0, 8, 1, -40)
logContainer.BackgroundColor3 = COLORS.bgSecondary
logContainer.BorderSizePixel = 0
logContainer.Parent = mainWindow
addCorner(logContainer, 4)

logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -8, 1, -4)
logFrame.Position = UDim2.new(0, 4, 0, 2)
logFrame.BackgroundTransparency = 1
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 2
logFrame.ScrollBarImageColor3 = COLORS.accent
logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.Parent = logContainer

local logLayout = Instance.new("UIListLayout")
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Padding = UDim.new(0, 1)
logLayout.Parent = logFrame

-- ===================== MINIMIZE LOGIC =====================
local windowMinimized = false
minimizeBtn.MouseButton1Click:Connect(function()
	windowMinimized = not windowMinimized
	for _, frame in pairs(tabFrames) do frame.Visible = not windowMinimized and (activeTab == frame.Name:gsub("Content", "")) end
	logContainer.Visible = not windowMinimized
	mainWindow.Size = windowMinimized and UDim2.new(0, windowW, 0, 36) or UDim2.new(0, windowW, 0, windowH)
	minimizeBtn.Text = windowMinimized and "+" or "-"
end)

-- Toggle window with RightControl
local windowVisible = true
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		windowVisible = not windowVisible
		mainWindow.Visible = windowVisible
	end
end)

-- ===================== HELPER FUNCTIONS =====================
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

	return {row = row, setVisualState = setVisualState}
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
		workspace.Remote.loadchar:InvokeServer()
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
		for _, v in ipairs(workspace.Prison_ITEMS.giver:GetChildren()) do
			if v.Name:lower():find("keycard") or v.Name:lower():find("key") then
				pcall(function()
					if v:FindFirstChild("ITEMPICKUP") then
						workspace.Remote.ItemHandler:InvokeServer(v.ITEMPICKUP)
						addLog("[KEYCARD] Grabbed keycard!", COLORS.success)
					end
				end)
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
					if rapidFireEnabled and stat.FireRate then stat.FireRate = 0.01 end
					if noSpreadEnabled and stat.Spread then stat.Spread = 0 end
					if infiniteAmmoEnabled then
						if stat.MaxAmmo then stat.MaxAmmo = 9999 end
						if stat.StoredAmmo then stat.StoredAmmo = 9999 end
					end
					if autoFireGunEnabled and stat.AutoFire ~= nil then stat.AutoFire = true end
					if extendedRangeEnabled and stat.Range then stat.Range = 9999 end
					if multiBulletEnabled and stat.Bullets then stat.Bullets = 10 end
					if instantReloadEnabled and stat.ReloadTime then stat.ReloadTime = 0 end
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

		if not noclipEnabled then noclipEnabled = true startNoclip() end
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
	pcall(function()
		local count = 0
		for _, obj in ipairs(workspace:GetDescendants()) do
			pcall(function()
				if obj.Name:lower():find("door") and (obj:IsA("BasePart") or obj:IsA("Model")) then
					obj:Destroy()
					count = count + 1
				end
			end)
		end
		addLog("[DOORS] Removed " .. count .. " door objects", COLORS.success)
	end)
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
	createActionButton(tab, "Get All Guns", 4, function() getAllGuns() end)
	createActionButton(tab, "Get Keycard", 5, function() getKeycard() end)

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
	createToggle(tab, "Team Check", 6, function(on) killAuraTeamCheck = on end)

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
	createInfoLabel(tab, "Orange=Inmate, Blue=Guard, Red=Criminal", 3)

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
		teleportTo(CFrame.new(283, 70, 2213))
		addLog("[TP] Criminal Base", COLORS.success)
	end)
	createActionButton(tab, "Yard", 3, function()
		teleportTo(CFrame.new(918, 98, 2355))
		addLog("[TP] Yard", COLORS.success)
	end)
	createActionButton(tab, "Cafeteria", 4, function()
		teleportTo(CFrame.new(917, 98, 2437))
		addLog("[TP] Cafeteria", COLORS.success)
	end)
	createActionButton(tab, "Guard Armory", 5, function()
		teleportTo(CFrame.new(918, 98, 2285))
		addLog("[TP] Guard Armory", COLORS.success)
	end)
	createActionButton(tab, "Parking Lot", 6, function()
		teleportTo(CFrame.new(835, 98, 2285))
		addLog("[TP] Parking Lot", COLORS.success)
	end)
	createActionButton(tab, "Cells", 7, function()
		teleportTo(CFrame.new(918, 98, 2315))
		addLog("[TP] Cells", COLORS.success)
	end)
	createActionButton(tab, "Gas Station", 8, function()
		teleportTo(CFrame.new(178, 73, 2452))
		addLog("[TP] Gas Station", COLORS.success)
	end)

	createSectionLabel(tab, "Player Teleport", 20)
	createInfoLabel(tab, "Click a player to select, then Teleport/Spectate", 21)

	local playerListFrame = Instance.new("Frame")
	playerListFrame.Size = UDim2.new(1, 0, 0, 150)
	playerListFrame.BackgroundColor3 = COLORS.bgSecondary
	playerListFrame.BorderSizePixel = 0
	playerListFrame.LayoutOrder = 22
	playerListFrame.Parent = tab
	addCorner(playerListFrame, 5)

	local playerScroll = Instance.new("ScrollingFrame")
	playerScroll.Size = UDim2.new(1, -4, 1, -4)
	playerScroll.Position = UDim2.new(0, 2, 0, 2)
	playerScroll.BackgroundTransparency = 1
	playerScroll.BorderSizePixel = 0
	playerScroll.ScrollBarThickness = 3
	playerScroll.ScrollBarImageColor3 = COLORS.accent
	playerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	playerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	playerScroll.Parent = playerListFrame

	local playerListLayout = Instance.new("UIListLayout")
	playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerListLayout.Padding = UDim.new(0, 2)
	playerListLayout.Parent = playerScroll

	local selectedLabel = Instance.new("TextLabel")
	selectedLabel.Size = UDim2.new(1, 0, 0, 20)
	selectedLabel.BackgroundTransparency = 1
	selectedLabel.Text = "Selected: None"
	selectedLabel.TextColor3 = COLORS.accent
	selectedLabel.Font = Enum.Font.GothamBold
	selectedLabel.TextSize = 11
	selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectedLabel.LayoutOrder = 23
	selectedLabel.Parent = tab

	local function refreshPlayerList()
		for _, child in ipairs(playerScroll:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for i, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local isSelected = selectedPlayer and selectedPlayer == player
				local pBtn = Instance.new("TextButton")
				pBtn.Size = UDim2.new(1, -4, 0, 24)
				pBtn.BackgroundColor3 = isSelected and COLORS.accent or COLORS.tabBg
				pBtn.BorderSizePixel = 0
				pBtn.Text = "  " .. player.DisplayName .. " (@" .. player.Name .. ")"
				pBtn.TextColor3 = COLORS.textPrimary
				pBtn.Font = isSelected and Enum.Font.GothamBold or Enum.Font.Gotham
				pBtn.TextSize = 11
				pBtn.TextXAlignment = Enum.TextXAlignment.Left
				pBtn.LayoutOrder = i
				pBtn.Parent = playerScroll
				addCorner(pBtn, 4)
				pBtn.MouseButton1Click:Connect(function()
					selectedPlayer = player
					selectedLabel.Text = "Selected: " .. player.DisplayName
					refreshPlayerList()
				end)
			end
		end
	end

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
	elseif cmd == "!help" then
		addLog("=== Prison Life Hub v1.0 Commands ===", COLORS.accent)
		addLog("!speed [val] | !fly | !noclip | !god | !killaura", COLORS.textSecondary)
		addLog("!killall | !esp | !aimbot | !xray | !guard | !inmate", COLORS.textSecondary)
		addLog("!guns | !keycard | !invisible | !antiafk", COLORS.textSecondary)
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
