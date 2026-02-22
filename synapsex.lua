-- ================================================================
-- Synapse X The Revival - Executor + Admin
-- Script executor with Infinite Yield-style admin
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local _spawn = (task and task.spawn) or spawn
local _wait = (task and task.wait) or wait

-- ===================== COLOR PALETTE =====================
local COLORS = {
	bg = Color3.fromRGB(20, 20, 20),
	bgSecondary = Color3.fromRGB(30, 30, 30),
	tabBg = Color3.fromRGB(45, 45, 45),
	accent = Color3.fromRGB(255, 102, 0),
	accentHover = Color3.fromRGB(255, 133, 51),
	accentDark = Color3.fromRGB(180, 72, 0),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(176, 176, 176),
	textDim = Color3.fromRGB(120, 120, 120),
	border = Color3.fromRGB(50, 50, 50),
	toggleOn = Color3.fromRGB(255, 102, 0),
	toggleOff = Color3.fromRGB(85, 85, 85),
	error = Color3.fromRGB(255, 68, 68),
	success = Color3.fromRGB(68, 255, 68),
	editor = Color3.fromRGB(15, 15, 15),
	editorLine = Color3.fromRGB(35, 35, 35),
	btnExecute = Color3.fromRGB(255, 102, 0),
	btnClear = Color3.fromRGB(60, 60, 60),
}

-- ===================== STATE =====================
local espEnabled = false
local flyEnabled = false
local flingEnabled = false
local walkFlingEnabled = false
local speedEnabled = false
local noclipEnabled = false
local godEnabled = false
local infJumpEnabled = false
local killAuraEnabled = false
local invisibleEnabled = false
local spinEnabled = false
local seizureEnabled = false

local flingPower = 99999
local walkFlingPower = 10000
local flySpeed = 80
local speedValue = 100
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
local touchConnections = {}
local noclipConnection = nil
local infJumpConnection = nil
local killAuraConnection = nil
local spinConnection = nil
local spinBAV = nil
local walkFlingThread = nil
local savedPhysProps = {}
local seizureConnection = nil
local selectedPlayer = nil
local windowVisible = true
local activeTab = "Execute"
local logLines = {}
local MAX_LOG_LINES = 50

-- ESP config
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local FILL_TRANSPARENCY = 0.5
local OUTLINE_TRANSPARENCY = 0
local REFRESH_INTERVAL = 5

-- ===================== SCREEN GUI =====================
-- Kill old instance if re-executing
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("SynapseXRevival")
	if old then old:Destroy() end
end)
pcall(function()
	local old = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("SynapseXRevival")
	if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SynapseXRevival"
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
mainWindow.Size = UDim2.new(0, 600, 0, 420)
mainWindow.Position = UDim2.new(0.5, -300, 0.5, -210)
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

-- Orange accent line under title
local titleAccent = Instance.new("Frame")
titleAccent.Size = UDim2.new(1, 0, 0, 2)
titleAccent.Position = UDim2.new(0, 0, 1, 0)
titleAccent.BackgroundColor3 = COLORS.accent
titleAccent.BorderSizePixel = 0
titleAccent.Parent = titleBar

-- Logo icon (orange square)
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
titleLabel.Text = "Synapse X - The Revival"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 40, 1, 0)
versionLabel.Position = UDim2.new(0, 200, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v2.0"
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

-- ===================== TAB BAR (horizontal, Synapse X style) =====================
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

local tabNames = {"Execute", "Main", "Player", "Server", "ESP", "Movement", "Fun"}
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
	tabBtn.Size = UDim2.new(0, 86, 1, 0)
	tabBtn.BackgroundColor3 = COLORS.bg
	tabBtn.BackgroundTransparency = (tabName == "Execute") and 0 or 1
	tabBtn.Text = tabName
	tabBtn.TextColor3 = (tabName == "Execute") and COLORS.accent or COLORS.textDim
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.TextSize = 11
	tabBtn.LayoutOrder = i
	tabBtn.Parent = tabBar

	-- Active indicator (bottom orange line)
	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(1, 0, 0, 2)
	indicator.Position = UDim2.new(0, 0, 1, -2)
	indicator.BackgroundColor3 = COLORS.accent
	indicator.BorderSizePixel = 0
	indicator.Visible = (tabName == "Execute")
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
toggleBtn.Text = "SX"
toggleBtn.TextColor3 = COLORS.textPrimary
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 15
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
	frame.Visible = (name == "Execute")
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

-- Create Execute tab as a raw frame (not scrolling, needs custom layout)
local executeFrame = Instance.new("Frame")
executeFrame.Name = "ExecuteFrame"
executeFrame.Size = UDim2.new(1, 0, 1, 0)
executeFrame.BackgroundTransparency = 1
executeFrame.BorderSizePixel = 0
executeFrame.Visible = true
executeFrame.Parent = contentArea
tabFrames["Execute"] = executeFrame

-- Create the other tabs as scrolling frames
for _, name in ipairs(tabNames) do
	if name ~= "Execute" then
		createTabFrame(name)
	end
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

-- =====================================================================
-- ======================== EXECUTOR TAB ==============================
-- =====================================================================
do
	local tab = executeFrame

	-- Script editor area (main big text box)
	local editorFrame = Instance.new("Frame")
	editorFrame.Size = UDim2.new(1, -16, 1, -58)
	editorFrame.Position = UDim2.new(0, 8, 0, 8)
	editorFrame.BackgroundColor3 = COLORS.editor
	editorFrame.BorderSizePixel = 0
	editorFrame.ClipsDescendants = true
	editorFrame.Parent = tab
	addCorner(editorFrame, 6)
	addStroke(editorFrame, COLORS.border, 1)

	-- Line number gutter
	local lineGutter = Instance.new("Frame")
	lineGutter.Size = UDim2.new(0, 36, 1, 0)
	lineGutter.BackgroundColor3 = COLORS.editorLine
	lineGutter.BorderSizePixel = 0
	lineGutter.Parent = editorFrame

	local gutterDivider = Instance.new("Frame")
	gutterDivider.Size = UDim2.new(0, 1, 1, 0)
	gutterDivider.Position = UDim2.new(1, 0, 0, 0)
	gutterDivider.BackgroundColor3 = COLORS.border
	gutterDivider.BorderSizePixel = 0
	gutterDivider.Parent = lineGutter

	-- Line numbers label (auto updates)
	local lineNumbers = Instance.new("TextLabel")
	lineNumbers.Size = UDim2.new(1, -4, 1, 0)
	lineNumbers.Position = UDim2.new(0, 2, 0, 0)
	lineNumbers.BackgroundTransparency = 1
	lineNumbers.Text = "1"
	lineNumbers.TextColor3 = COLORS.textDim
	lineNumbers.Font = Enum.Font.Code
	lineNumbers.TextSize = 14
	lineNumbers.TextXAlignment = Enum.TextXAlignment.Right
	lineNumbers.TextYAlignment = Enum.TextYAlignment.Top
	lineNumbers.Parent = lineGutter
	addPadding(lineNumbers, 6, 4, 0, 0)

	-- Script text input
	local scriptInput = Instance.new("TextBox")
	scriptInput.Size = UDim2.new(1, -40, 1, 0)
	scriptInput.Position = UDim2.new(0, 40, 0, 0)
	scriptInput.BackgroundTransparency = 1
	scriptInput.TextColor3 = COLORS.textPrimary
	scriptInput.PlaceholderText = '-- Paste your script here...\n-- Press "Execute" to run\nprint("Hello from Synapse X The Revival!")'
	scriptInput.PlaceholderColor3 = COLORS.textDim
	scriptInput.Font = Enum.Font.Code
	scriptInput.TextSize = 14
	scriptInput.Text = ""
	scriptInput.ClearTextOnFocus = false
	scriptInput.MultiLine = true
	scriptInput.TextXAlignment = Enum.TextXAlignment.Left
	scriptInput.TextYAlignment = Enum.TextYAlignment.Top
	scriptInput.TextWrapped = true
	scriptInput.Parent = editorFrame
	addPadding(scriptInput, 6, 8, 6, 4)

	-- Update line numbers when text changes
	local function updateLineNumbers()
		local text = scriptInput.Text
		local lines = 1
		for _ in text:gmatch("\n") do
			lines = lines + 1
		end
		local nums = {}
		for i = 1, lines do
			table.insert(nums, tostring(i))
		end
		lineNumbers.Text = table.concat(nums, "\n")
	end

	scriptInput:GetPropertyChangedSignal("Text"):Connect(updateLineNumbers)

	-- Bottom button bar
	local btnBar = Instance.new("Frame")
	btnBar.Size = UDim2.new(1, -16, 0, 40)
	btnBar.Position = UDim2.new(0, 8, 1, -46)
	btnBar.BackgroundTransparency = 1
	btnBar.BorderSizePixel = 0
	btnBar.Parent = tab

	local btnBarLayout = Instance.new("UIListLayout")
	btnBarLayout.FillDirection = Enum.FillDirection.Horizontal
	btnBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	btnBarLayout.Padding = UDim.new(0, 8)
	btnBarLayout.Parent = btnBar

	-- Execute button
	local executeBtn = Instance.new("TextButton")
	executeBtn.Size = UDim2.new(0, 120, 0, 36)
	executeBtn.BackgroundColor3 = COLORS.btnExecute
	executeBtn.Text = "Execute"
	executeBtn.TextColor3 = COLORS.textPrimary
	executeBtn.Font = Enum.Font.GothamBold
	executeBtn.TextSize = 14
	executeBtn.LayoutOrder = 1
	executeBtn.Parent = btnBar
	addCorner(executeBtn, 6)

	-- Clear button
	local clearBtn = Instance.new("TextButton")
	clearBtn.Size = UDim2.new(0, 90, 0, 36)
	clearBtn.BackgroundColor3 = COLORS.btnClear
	clearBtn.Text = "Clear"
	clearBtn.TextColor3 = COLORS.textSecondary
	clearBtn.Font = Enum.Font.GothamBold
	clearBtn.TextSize = 13
	clearBtn.LayoutOrder = 2
	clearBtn.Parent = btnBar
	addCorner(clearBtn, 6)

	-- Clipboard paste button
	local pasteBtn = Instance.new("TextButton")
	pasteBtn.Size = UDim2.new(0, 130, 0, 36)
	pasteBtn.BackgroundColor3 = COLORS.btnClear
	pasteBtn.Text = "Paste Clipboard"
	pasteBtn.TextColor3 = COLORS.textSecondary
	pasteBtn.Font = Enum.Font.GothamBold
	pasteBtn.TextSize = 13
	pasteBtn.LayoutOrder = 3
	pasteBtn.Parent = btnBar
	addCorner(pasteBtn, 6)

	-- Script Hub button
	local hubBtn = Instance.new("TextButton")
	hubBtn.Size = UDim2.new(0, 110, 0, 36)
	hubBtn.BackgroundColor3 = COLORS.accentDark
	hubBtn.Text = "Script Hub"
	hubBtn.TextColor3 = COLORS.textPrimary
	hubBtn.Font = Enum.Font.GothamBold
	hubBtn.TextSize = 13
	hubBtn.LayoutOrder = 4
	hubBtn.Parent = btnBar
	addCorner(hubBtn, 6)

	-- Execute logic
	executeBtn.MouseButton1Click:Connect(function()
		local code = scriptInput.Text
		if code == "" then
			addLog("[EXEC] No script to execute", COLORS.error)
			return
		end
		addLog("[EXEC] Executing script...", COLORS.accent)
		local fn, err = loadstring(code)
		if not fn then
			addLog("[EXEC] Compile error: " .. tostring(err), COLORS.error)
			return
		end
		local ok, runtimeErr = pcall(fn)
		if ok then
			addLog("[EXEC] Script executed successfully", COLORS.success)
		else
			addLog("[EXEC] Runtime error: " .. tostring(runtimeErr), COLORS.error)
		end
	end)

	-- Clear logic
	clearBtn.MouseButton1Click:Connect(function()
		scriptInput.Text = ""
		updateLineNumbers()
		addLog("[EXEC] Editor cleared", COLORS.textSecondary)
	end)

	-- Paste clipboard
	pasteBtn.MouseButton1Click:Connect(function()
		pcall(function()
			-- Try different clipboard functions available in exploits
			local clipboard = nil
			if getclipboard then
				clipboard = getclipboard()
			elseif readclipboard then
				clipboard = readclipboard()
			end
			if clipboard and clipboard ~= "" then
				scriptInput.Text = clipboard
				updateLineNumbers()
				addLog("[EXEC] Pasted from clipboard", COLORS.success)
			else
				addLog("[EXEC] Clipboard empty or not supported", COLORS.error)
			end
		end)
	end)

	-- Script Hub (popup with preset scripts)
	local hubOpen = false
	local hubFrame

	hubBtn.MouseButton1Click:Connect(function()
		if hubOpen and hubFrame then
			hubFrame:Destroy()
			hubOpen = false
			return
		end

		hubFrame = Instance.new("Frame")
		hubFrame.Size = UDim2.new(1, -16, 0, 200)
		hubFrame.Position = UDim2.new(0, 8, 1, -250)
		hubFrame.BackgroundColor3 = COLORS.bgSecondary
		hubFrame.BorderSizePixel = 0
		hubFrame.ZIndex = 10
		hubFrame.Parent = tab
		addCorner(hubFrame, 6)
		addStroke(hubFrame, COLORS.accent, 1)
		hubOpen = true

		local hubTitle = Instance.new("TextLabel")
		hubTitle.Size = UDim2.new(1, 0, 0, 28)
		hubTitle.BackgroundColor3 = COLORS.accent
		hubTitle.Text = "  Script Hub"
		hubTitle.TextColor3 = COLORS.textPrimary
		hubTitle.Font = Enum.Font.GothamBold
		hubTitle.TextSize = 12
		hubTitle.TextXAlignment = Enum.TextXAlignment.Left
		hubTitle.ZIndex = 10
		hubTitle.Parent = hubFrame
		addCorner(hubTitle, 6)

		local hubTitleCover = Instance.new("Frame")
		hubTitleCover.Size = UDim2.new(1, 0, 0, 8)
		hubTitleCover.Position = UDim2.new(0, 0, 0, 22)
		hubTitleCover.BackgroundColor3 = COLORS.accent
		hubTitleCover.BorderSizePixel = 0
		hubTitleCover.ZIndex = 10
		hubTitleCover.Parent = hubFrame

		local hubClose = Instance.new("TextButton")
		hubClose.Size = UDim2.new(0, 24, 0, 24)
		hubClose.Position = UDim2.new(1, -26, 0, 2)
		hubClose.BackgroundTransparency = 1
		hubClose.Text = "X"
		hubClose.TextColor3 = COLORS.textPrimary
		hubClose.Font = Enum.Font.GothamBold
		hubClose.TextSize = 12
		hubClose.ZIndex = 11
		hubClose.Parent = hubFrame
		hubClose.MouseButton1Click:Connect(function()
			hubFrame:Destroy()
			hubOpen = false
		end)

		local hubScroll = Instance.new("ScrollingFrame")
		hubScroll.Size = UDim2.new(1, -8, 1, -34)
		hubScroll.Position = UDim2.new(0, 4, 0, 30)
		hubScroll.BackgroundTransparency = 1
		hubScroll.ScrollBarThickness = 3
		hubScroll.ScrollBarImageColor3 = COLORS.accent
		hubScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		hubScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		hubScroll.ZIndex = 10
		hubScroll.Parent = hubFrame

		local hubLayout = Instance.new("UIListLayout")
		hubLayout.Padding = UDim.new(0, 4)
		hubLayout.SortOrder = Enum.SortOrder.LayoutOrder
		hubLayout.Parent = hubScroll

		-- Preset scripts
		local presets = {
			{"Infinite Yield", "loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()"},
			{"Dark Dex Explorer", "loadstring(game:HttpGet('https://raw.githubusercontent.com/infyiff/backup/main/dex.lua'))()"},
			{"Simple Spy", "loadstring(game:HttpGet('https://github.com/infyiff/backup/blob/main/SimpleSpyV3/main.lua?raw=true'))()"},
			{"Print All Players", 'for _,v in pairs(game.Players:GetPlayers()) do print(v.Name) end'},
			{"Print Workspace Children", 'for _,v in pairs(workspace:GetChildren()) do print(v.Name, v.ClassName) end'},
			{"Anti AFK", 'local vu = game:GetService("VirtualUser")\ngame:GetService("Players").LocalPlayer.Idled:Connect(function()\n\tvu:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)\n\twait(1)\n\tvu:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)\nend)'},
			{"Remove All Fog", 'game.Lighting.FogStart = 999999\ngame.Lighting.FogEnd = 9999999'},
			{"Fullbright", 'game.Lighting.Brightness = 2\ngame.Lighting.ClockTime = 14\ngame.Lighting.FogEnd = 100000\ngame.Lighting.GlobalShadows = false\ngame.Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)'},
			{"Spin Fling", "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/spinfling.lua'))()"},
			{"ESP Loader", "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/esp.lua'))()"},
			{"Steal a Brainrot Hub (Only for Steal a Brainrot)", "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/stealabrainrot.lua'))()"},
			{"SAB Admin Tool (Only for Steal a Brainrot)", "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/stealabrainrot-admin.lua'))()"},
			{"99 Nights Hub (Only for 99 Nights in the Forest)", "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/99nights.lua'))()"},
			{"NBTF Hub (Only for Nuclear Blast Testing Facility)", "loadstring(game:HttpGet('https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/nbtf.lua'))()"},
		}

		for i, preset in ipairs(presets) do
			local pBtn = Instance.new("TextButton")
			pBtn.Size = UDim2.new(1, -4, 0, 28)
			pBtn.BackgroundColor3 = COLORS.tabBg
			pBtn.Text = "  " .. preset[1]
			pBtn.TextColor3 = COLORS.accent
			pBtn.Font = Enum.Font.GothamBold
			pBtn.TextSize = 11
			pBtn.TextXAlignment = Enum.TextXAlignment.Left
			pBtn.LayoutOrder = i
			pBtn.ZIndex = 10
			pBtn.Parent = hubScroll
			addCorner(pBtn, 4)

			pBtn.MouseEnter:Connect(function() pBtn.BackgroundColor3 = COLORS.bgSecondary end)
			pBtn.MouseLeave:Connect(function() pBtn.BackgroundColor3 = COLORS.tabBg end)

			pBtn.MouseButton1Click:Connect(function()
				scriptInput.Text = preset[2]
				updateLineNumbers()
				hubFrame:Destroy()
				hubOpen = false
				addLog("[HUB] Loaded: " .. preset[1], COLORS.success)
			end)
		end
	end)

	-- Hover effects
	executeBtn.MouseEnter:Connect(function() executeBtn.BackgroundColor3 = COLORS.accentHover end)
	executeBtn.MouseLeave:Connect(function() executeBtn.BackgroundColor3 = COLORS.btnExecute end)
	clearBtn.MouseEnter:Connect(function() clearBtn.BackgroundColor3 = COLORS.tabBg end)
	clearBtn.MouseLeave:Connect(function() clearBtn.BackgroundColor3 = COLORS.btnClear end)
	pasteBtn.MouseEnter:Connect(function() pasteBtn.BackgroundColor3 = COLORS.tabBg end)
	pasteBtn.MouseLeave:Connect(function() pasteBtn.BackgroundColor3 = COLORS.btnClear end)
	hubBtn.MouseEnter:Connect(function() hubBtn.BackgroundColor3 = COLORS.accent end)
	hubBtn.MouseLeave:Connect(function() hubBtn.BackgroundColor3 = COLORS.accentDark end)
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

-- ===================== SPIN FLING LOGIC (Infinite Yield Style) =====================
-- High density + BodyAngularVelocity + noclip + massless + pulse spin

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

		-- Enable noclip
		if not noclipEnabled then noclipEnabled = true startNoclip() end
		wait(0.1)

		-- BodyAngularVelocity - spin on Y axis
		spinBAV = Instance.new("BodyAngularVelocity")
		spinBAV.AngularVelocity = Vector3.new(0, flingPower, 0)
		spinBAV.MaxTorque = Vector3.new(0, math.huge, 0)
		spinBAV.P = math.huge
		spinBAV.Parent = root

		-- Set all parts massless + zero velocity
		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Massless = true
				part.Velocity = Vector3.new(0, 0, 0)
			end
		end

		-- Pulse spin on/off (0.2s on, 0.1s off) to create repeated impulse spikes
		spawn(function()
			while flingEnabled do
				if spinBAV and spinBAV.Parent then
					spinBAV.AngularVelocity = Vector3.new(0, flingPower, 0)
				end
				wait(0.2)
				if spinBAV and spinBAV.Parent then
					spinBAV.AngularVelocity = Vector3.new(0, 0, 0)
				end
				wait(0.1)
			end
		end)

		addLog("[SPIN FLING] ON - Walk into players!", COLORS.success)
	end)
	if not ok then
		warn("[SPIN FLING ERROR] " .. tostring(err))
		addLog("[SPIN FLING] Error: " .. tostring(err), COLORS.error)
	end
end

local function stopFling()
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
				part.Massless = false
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

-- ===================== WALK FLING LOGIC (Dinos Anim Style) =====================
-- Velocity spike each physics frame - walk normally while flinging

local function startWalkFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Enable noclip
		if not noclipEnabled then noclipEnabled = true startNoclip() end

		-- Velocity spike loop
		walkFlingThread = spawn(function()
			local movel = 0.1
			while walkFlingEnabled do
				RunService.Heartbeat:Wait()
				local char = LocalPlayer.Character
				local rt = char and char:FindFirstChild("HumanoidRootPart")
				if char and char.Parent and rt and rt.Parent then
					-- Save current velocity
					local vel = rt.Velocity

					-- SPIKE: multiply velocity massively + huge upward burst
					rt.Velocity = vel * walkFlingPower + Vector3.new(0, walkFlingPower, 0)

					RunService.RenderStepped:Wait()
					-- RESTORE: set velocity back to normal
					char = LocalPlayer.Character
					rt = char and char:FindFirstChild("HumanoidRootPart")
					if char and char.Parent and rt and rt.Parent then
						rt.Velocity = vel
					end

					RunService.Stepped:Wait()
					-- MICRO-OSCILLATE: tiny bounce to keep physics alive
					char = LocalPlayer.Character
					rt = char and char:FindFirstChild("HumanoidRootPart")
					if char and char.Parent and rt and rt.Parent then
						rt.Velocity = vel + Vector3.new(0, movel, 0)
						movel = movel * -1
					end
				end
			end
		end)

		addLog("[WALK FLING] ON - Dinos Anim style!", COLORS.success)
	end)
	if not ok then
		warn("[WALK FLING ERROR] " .. tostring(err))
		addLog("[WALK FLING] Error: " .. tostring(err), COLORS.error)
	end
end

local function stopWalkFling()
	-- Break velocity
	pcall(function()
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
	end)

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
	addLog("[INVISIBLE] ON", COLORS.success)
end

local function stopInvisible()
	pcall(function()
		for part, transparency in pairs(savedTransparencies) do
			if part and part.Parent then part.Transparency = transparency end
		end
		savedTransparencies = {}
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

-- ===================== TELEPORT / SPECTATE =====================
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

local spectating = false

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

-- ===================== SERVER FUNCTIONS =====================
local function rejoinServer()
	pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
	addLog("[SERVER] Rejoining...", COLORS.accent)
end

local function serverHop()
	pcall(function()
		local servers = HttpService:JSONDecode(
			game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
		)
		if servers and servers.data then
			for _, server in ipairs(servers.data) do
				if server.id ~= game.JobId and server.playing < server.maxPlayers then
					TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
					addLog("[SERVER] Hopping...", COLORS.accent)
					return
				end
			end
		end
		addLog("[SERVER] No available servers found", COLORS.error)
	end)
end

-- ===================== BUILD MAIN TAB =====================
do
	local tab = tabFrames["Main"]

	createSectionLabel(tab, "Welcome", 1)
	createInfoLabel(tab, "Synapse X - The Revival v2.0", 2)
	createInfoLabel(tab, "Player: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")", 3)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

	createSectionLabel(tab, "Quick Toggles", 5)

	createToggle(tab, "ESP", 6, function(on)
		espEnabled = on
		if on then enableESP() else disableESP() end
	end)
	createToggle(tab, "Fly", 7, function(on)
		flyEnabled = on
		if on then startFly() else stopFly() end
	end)
	createToggle(tab, "Noclip", 8, function(on)
		noclipEnabled = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "God Mode", 9, function(on)
		godEnabled = on
		if on then startGod() else stopGod() end
	end)
	createToggle(tab, "Infinite Jump", 10, function(on)
		infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 11
	spacer2.Parent = tab

	createSectionLabel(tab, "Output Log", 12)

	logFrame = Instance.new("ScrollingFrame")
	logFrame.Size = UDim2.new(1, 0, 0, 100)
	logFrame.BackgroundColor3 = COLORS.editor
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

-- ===================== BUILD PLAYER TAB =====================
local playerListFrame
local playerButtons = {}
local selectedPlayerLabel

do
	local tab = tabFrames["Player"]

	createSectionLabel(tab, "Selected Player", 1)

	selectedPlayerLabel = Instance.new("TextLabel")
	selectedPlayerLabel.Size = UDim2.new(1, 0, 0, 22)
	selectedPlayerLabel.BackgroundColor3 = COLORS.tabBg
	selectedPlayerLabel.Text = "  None selected"
	selectedPlayerLabel.TextColor3 = COLORS.textSecondary
	selectedPlayerLabel.Font = Enum.Font.Gotham
	selectedPlayerLabel.TextSize = 12
	selectedPlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectedPlayerLabel.LayoutOrder = 2
	selectedPlayerLabel.Parent = tab
	addCorner(selectedPlayerLabel, 5)

	createSectionLabel(tab, "Actions", 3)

	createActionButton(tab, "Teleport to Player", 4, function()
		if selectedPlayer then teleportToPlayer(selectedPlayer)
		else addLog("[TP] No player selected", COLORS.error) end
	end)
	createActionButton(tab, "Spectate Player", 5, function()
		if selectedPlayer then spectatePlayer(selectedPlayer)
		else addLog("[SPECTATE] No player selected", COLORS.error) end
	end)
	createActionButton(tab, "Unspectate", 6, function() unspectate() end)
	createActionButton(tab, "Fling Player", 7, function()
		if selectedPlayer and selectedPlayer.Character then
			pcall(function()
				for _, part in ipairs(selectedPlayer.Character:GetDescendants()) do
					if part:IsA("BasePart") and not part.Anchored then
						part.Velocity = Vector3.new((math.random()-0.5)*flingPower, flingPower*0.5, (math.random()-0.5)*flingPower)
					end
				end
				addLog("[FLING] Flung " .. selectedPlayer.DisplayName, COLORS.success)
			end)
		else addLog("[FLING] No player selected", COLORS.error) end
	end)

	createToggle(tab, "Kill Aura", 8, function(on)
		killAuraEnabled = on
		if on then startKillAura() else stopKillAura() end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 9
	spacer.Parent = tab

	createSectionLabel(tab, "Player List", 10)

	playerListFrame = Instance.new("Frame")
	playerListFrame.Size = UDim2.new(1, 0, 0, 0)
	playerListFrame.BackgroundTransparency = 1
	playerListFrame.AutomaticSize = Enum.AutomaticSize.Y
	playerListFrame.LayoutOrder = 11
	playerListFrame.Parent = tab

	local playerListLayout = Instance.new("UIListLayout")
	playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerListLayout.Padding = UDim.new(0, 3)
	playerListLayout.Parent = playerListFrame
end

local function refreshPlayerList()
	for _, btn in pairs(playerButtons) do pcall(function() btn:Destroy() end) end
	playerButtons = {}
	local order = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			order = order + 1
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 26)
			btn.BackgroundColor3 = (selectedPlayer == player) and COLORS.accent or COLORS.tabBg
			btn.Text = "  " .. player.DisplayName .. " (@" .. player.Name .. ")"
			btn.TextColor3 = (selectedPlayer == player) and COLORS.textPrimary or COLORS.textSecondary
			btn.Font = Enum.Font.Gotham
			btn.TextSize = 11
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.LayoutOrder = order
			btn.Parent = playerListFrame
			addCorner(btn, 4)
			btn.MouseButton1Click:Connect(function()
				selectedPlayer = player
				selectedPlayerLabel.Text = "  " .. player.DisplayName .. " (@" .. player.Name .. ")"
				selectedPlayerLabel.TextColor3 = COLORS.accent
				refreshPlayerList()
			end)
			playerButtons[player] = btn
		end
	end
end

Players.PlayerAdded:Connect(function() _wait(0.5) refreshPlayerList() end)
Players.PlayerRemoving:Connect(function(player)
	if selectedPlayer == player then
		selectedPlayer = nil
		selectedPlayerLabel.Text = "  None selected"
		selectedPlayerLabel.TextColor3 = COLORS.textSecondary
	end
	_wait(0.1) refreshPlayerList()
end)
refreshPlayerList()

-- ===================== BUILD SERVER TAB =====================
do
	local tab = tabFrames["Server"]

	createSectionLabel(tab, "Server Info", 1)
	createInfoLabel(tab, "Place ID: " .. tostring(game.PlaceId), 2)
	createInfoLabel(tab, "Server ID: " .. tostring(game.JobId):sub(1, 24) .. "...", 3)

	local playerCountLabel = createInfoLabel(tab, "Players: " .. #Players:GetPlayers(), 4)
	_spawn(function()
		while true do
			playerCountLabel.Text = "Players: " .. #Players:GetPlayers()
			_wait(5)
		end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 5
	spacer.Parent = tab

	createSectionLabel(tab, "Actions", 6)
	createActionButton(tab, "Rejoin Server", 7, function() rejoinServer() end)
	createActionButton(tab, "Server Hop", 8, function() serverHop() end)

	createActionButton(tab, "Copy Server ID", 9, function()
		pcall(function()
			if setclipboard then setclipboard(game.JobId) addLog("[SERVER] Server ID copied", COLORS.success)
			elseif toclipboard then toclipboard(game.JobId) addLog("[SERVER] Server ID copied", COLORS.success)
			else addLog("[SERVER] Clipboard not supported", COLORS.error) end
		end)
	end)
	createActionButton(tab, "Copy Place ID", 10, function()
		pcall(function()
			if setclipboard then setclipboard(tostring(game.PlaceId)) addLog("[SERVER] Place ID copied", COLORS.success)
			elseif toclipboard then toclipboard(tostring(game.PlaceId)) addLog("[SERVER] Place ID copied", COLORS.success)
			else addLog("[SERVER] Clipboard not supported", COLORS.error) end
		end)
	end)
end

-- ===================== BUILD ESP TAB =====================
do
	local tab = tabFrames["ESP"]

	createSectionLabel(tab, "ESP Settings", 1)
	createToggle(tab, "ESP Enabled", 2, function(on)
		espEnabled = on
		if on then enableESP() else disableESP() end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 3
	spacer.Parent = tab

	createSectionLabel(tab, "Fill Color", 4)

	local fillColors = {
		{Color3.fromRGB(255, 0, 0), "Red"},
		{Color3.fromRGB(0, 255, 0), "Green"},
		{Color3.fromRGB(0, 100, 255), "Blue"},
		{Color3.fromRGB(255, 102, 0), "Orange"},
	}
	local fillRow = Instance.new("Frame")
	fillRow.Size = UDim2.new(1, 0, 0, 26)
	fillRow.BackgroundTransparency = 1
	fillRow.LayoutOrder = 5
	fillRow.Parent = tab
	for i, preset in ipairs(fillColors) do
		local colorBtn = Instance.new("TextButton")
		colorBtn.Size = UDim2.new(0.25, -4, 1, 0)
		colorBtn.Position = UDim2.new((i-1)*0.25, 2, 0, 0)
		colorBtn.BackgroundColor3 = preset[1]
		colorBtn.Text = preset[2]
		colorBtn.TextColor3 = COLORS.textPrimary
		colorBtn.Font = Enum.Font.GothamBold
		colorBtn.TextSize = 10
		colorBtn.Parent = fillRow
		addCorner(colorBtn, 4)
		colorBtn.MouseButton1Click:Connect(function()
			HIGHLIGHT_COLOR = preset[1]
			for _, hl in pairs(highlights) do pcall(function() hl.FillColor = preset[1] end) end
			addLog("[ESP] Fill: " .. preset[2], COLORS.accent)
		end)
	end

	createSectionLabel(tab, "Outline Color", 6)

	local outlineColors = {
		{Color3.fromRGB(255, 255, 255), "White"},
		{Color3.fromRGB(255, 0, 0), "Red"},
		{Color3.fromRGB(255, 102, 0), "Orange"},
		{Color3.fromRGB(0, 255, 255), "Cyan"},
	}
	local outRow = Instance.new("Frame")
	outRow.Size = UDim2.new(1, 0, 0, 26)
	outRow.BackgroundTransparency = 1
	outRow.LayoutOrder = 7
	outRow.Parent = tab
	for i, preset in ipairs(outlineColors) do
		local colorBtn = Instance.new("TextButton")
		colorBtn.Size = UDim2.new(0.25, -4, 1, 0)
		colorBtn.Position = UDim2.new((i-1)*0.25, 2, 0, 0)
		colorBtn.BackgroundColor3 = preset[1]
		colorBtn.Text = preset[2]
		colorBtn.TextColor3 = (preset[2] == "White") and COLORS.bg or COLORS.textPrimary
		colorBtn.Font = Enum.Font.GothamBold
		colorBtn.TextSize = 10
		colorBtn.Parent = outRow
		addCorner(colorBtn, 4)
		colorBtn.MouseButton1Click:Connect(function()
			OUTLINE_COLOR = preset[1]
			for _, hl in pairs(highlights) do pcall(function() hl.OutlineColor = preset[1] end) end
			addLog("[ESP] Outline: " .. preset[2], COLORS.accent)
		end)
	end

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 8
	spacer2.Parent = tab

	createSectionLabel(tab, "Refresh", 9)
	createSlider(tab, "Interval (seconds)", 1, 30, REFRESH_INTERVAL, 10, function(val)
		REFRESH_INTERVAL = val
	end)
end

-- ===================== BUILD MOVEMENT TAB =====================
do
	local tab = tabFrames["Movement"]

	createSectionLabel(tab, "Flight", 1)
	createToggle(tab, "Fly", 2, function(on)
		flyEnabled = on
		if on then startFly() else stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 500, flySpeed, 3, function(val) flySpeed = val end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

	createSectionLabel(tab, "Movement", 5)
	createToggle(tab, "Speed Boost", 6, function(on)
		speedEnabled = on
		if on then startSpeed() else stopSpeed() end
	end)
	createSlider(tab, "Walk Speed", 16, 500, speedValue, 7, function(val)
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
	createToggle(tab, "Noclip", 8, function(on)
		noclipEnabled = on
		if on then startNoclip() else stopNoclip() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 9
	spacer2.Parent = tab

	createSectionLabel(tab, "Jumping", 10)
	createToggle(tab, "Infinite Jump", 11, function(on)
		infJumpEnabled = on
		if on then startInfJump() else stopInfJump() end
	end)
	createSlider(tab, "Jump Power", 10, 500, jumpPowerValue, 12, function(val) jumpPowerValue = val setJumpPower(val) end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 13
	spacer3.Parent = tab

	createSectionLabel(tab, "World", 14)
	createSlider(tab, "Gravity", 0, 1000, math.floor(gravityValue), 15, function(val) gravityValue = val setGravity(val) end)
end

-- ===================== BUILD FUN TAB =====================
do
	local tab = tabFrames["Fun"]

	createSectionLabel(tab, "Fling", 1)
	createToggle(tab, "Spin Fling (IY Style)", 2, function(on)
		flingEnabled = on
		if on then
			if walkFlingEnabled then walkFlingEnabled = false stopWalkFling() end
			startFling()
		else stopFling() end
	end)
	createSlider(tab, "Spin Fling Power", 1000, 99999, flingPower, 3, function(val) flingPower = val end)
	createToggle(tab, "Walk Fling (Dinos Anim)", 4, function(on)
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

	createSectionLabel(tab, "Visual Effects", 7)
	createToggle(tab, "Invisible", 8, function(on)
		invisibleEnabled = on
		if on then startInvisible() else stopInvisible() end
	end)
	createToggle(tab, "Spin", 9, function(on)
		spinEnabled = on
		if on then startSpin() else stopSpin() end
	end)
	createToggle(tab, "Seizure", 10, function(on)
		seizureEnabled = on
		if on then startSeizure() else stopSeizure() end
	end)
end

-- ===================== COMMAND BAR (hidden inline at bottom of Main tab) =====================
-- Commands can be run from the executor tab by typing them as scripts
-- but we also support ; prefix commands via a chat hook

local commands = {}
commands["esp"] = function() espEnabled = true enableESP() end
commands["unesp"] = function() espEnabled = false disableESP() end
commands["fly"] = function() flyEnabled = true startFly() end
commands["unfly"] = function() flyEnabled = false stopFly() end
commands["speed"] = function(args) local v = tonumber(args[1]) if v then speedValue = v end speedEnabled = true startSpeed() end
commands["unspeed"] = function() speedEnabled = false stopSpeed() end
commands["noclip"] = function() noclipEnabled = true startNoclip() end
commands["unnoclip"] = function() noclipEnabled = false stopNoclip() end
commands["god"] = function() godEnabled = true startGod() end
commands["ungod"] = function() godEnabled = false stopGod() end
commands["tp"] = function(args)
	if not args[1] then addLog("[CMD] Usage: ;tp <player>", COLORS.error) return end
	local target = findPlayer(args[1])
	if target then teleportToPlayer(target) else addLog("[CMD] Player not found: " .. args[1], COLORS.error) end
end
commands["invisible"] = function() invisibleEnabled = true startInvisible() end
commands["visible"] = function() invisibleEnabled = false stopInvisible() end
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
commands["fling"] = function() if walkFlingEnabled then walkFlingEnabled = false stopWalkFling() end flingEnabled = true startFling() end
commands["unfling"] = function() flingEnabled = false stopFling() end
commands["walkfling"] = function() if flingEnabled then flingEnabled = false stopFling() end walkFlingEnabled = true startWalkFling() end
commands["unwalkfling"] = function() walkFlingEnabled = false stopWalkFling() end
commands["infjump"] = function() infJumpEnabled = true startInfJump() end
commands["uninfjump"] = function() infJumpEnabled = false stopInfJump() end
commands["killaura"] = function() killAuraEnabled = true startKillAura() end
commands["unkillaura"] = function() killAuraEnabled = false stopKillAura() end
commands["rejoin"] = function() rejoinServer() end
commands["serverhop"] = function() serverHop() end
commands["spectate"] = function(args)
	if not args[1] then addLog("[CMD] Usage: ;spectate <player>", COLORS.error) return end
	local target = findPlayer(args[1])
	if target then spectatePlayer(target) else addLog("[CMD] Player not found: " .. args[1], COLORS.error) end
end
commands["unspectate"] = function() unspectate() end
commands["spin"] = function() spinEnabled = true startSpin() end
commands["unspin"] = function() spinEnabled = false stopSpin() end
commands["seizure"] = function() seizureEnabled = true startSeizure() end
commands["unseizure"] = function() seizureEnabled = false stopSeizure() end
commands["cmds"] = function()
	addLog("--- Commands ---", COLORS.accent)
	addLog(";esp / ;unesp    ;fly / ;unfly", COLORS.textSecondary)
	addLog(";speed [val] / ;unspeed", COLORS.textSecondary)
	addLog(";noclip / ;unnoclip    ;god / ;ungod", COLORS.textSecondary)
	addLog(";tp <player>    ;invisible / ;visible", COLORS.textSecondary)
	addLog(";jp <val>    ;gravity <val>", COLORS.textSecondary)
	addLog(";fling / ;unfling (spin fling)", COLORS.textSecondary)
	addLog(";walkfling / ;unwalkfling (dinos anim)", COLORS.textSecondary)
	addLog(";infjump / ;uninfjump", COLORS.textSecondary)
	addLog(";killaura / ;unkillaura", COLORS.textSecondary)
	addLog(";spectate <player> / ;unspectate", COLORS.textSecondary)
	addLog(";spin / ;unspin    ;seizure / ;unseizure", COLORS.textSecondary)
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
addLog("Synapse X - The Revival v2.0", COLORS.accent)
addLog("Executor + Admin loaded", COLORS.success)
addLog("Type ;cmds in chat for commands", COLORS.textSecondary)
addLog("Press Right Shift to toggle window", COLORS.textSecondary)
print("[Synapse X] The Revival v2.0 loaded")
