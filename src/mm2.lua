-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate() then return end

-- ================================================================
-- Synapse X The Revival - MM2 Hub
-- Dedicated admin for Murder Mystery 2
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

-- ===================== STATE =====================
-- Role Detection
local myRole = "Unknown"
local murdererPlayer = nil
local sheriffPlayer = nil
local roleCheckConnection = nil
local roleCheckEnabled = false
local lastRoleScan = 0

-- Combat
local murdererEspEnabled = false
local murdererAlertEnabled = false
local autoShootMurdererEnabled = false
local aimSmoothing = 2
local alertConnection = nil
local alertActive = false
local autoShootConnection = nil

-- ESP
local espEnabled = false
local showNamesEnabled = true
local showDistanceEnabled = true
local showRoleEnabled = true
local gunEspEnabled = false
local coinEspEnabled = false
local fullbrightEnabled = false
local playerEspHighlights = {}
local playerEspNametags = {}
local espConnections = {}
local gunEspHighlights = {}
local coinEspHighlights = {}
local gunEspConnection = nil
local coinEspConnection = nil
local REFRESH_INTERVAL = 5

-- Farming
local autoCoinFarmEnabled = false
local farmSpeed = 0.5
local coinFarmThread = nil
local coinsFarmed = 0
local antiAfkEnabled = false
local antiAfkConnection = nil

-- Player
local flyEnabled = false
local speedEnabled = false
local noclipEnabled = false
local infJumpEnabled = false
local godEnabled = false
local invisibleEnabled = false
local flySpeed = 80
local speedValue = 100
local jumpPowerValue = 50
local cameraFOV = 70
local flyConnection = nil
local bodyGyro = nil
local bodyVelocity = nil
local noclipConnection = nil
local infJumpConnection = nil
local godConnection = nil

-- Fun
local flingEnabled = false
local spinEnabled = false
local seizureEnabled = false
local flingPower = 99999
local flingConnection = nil
local flingConnection2 = nil
local spinBAV = nil
local spinConnection = nil
local seizureConnection = nil
local savedPhysProps = {}
local emoteActive = false
local emoteTracks = {}
local emoteConnection = nil

-- Auto Grab Gun
local autoGrabGunEnabled = false
local autoGrabConnection = nil

-- Fullbright saved values
local origAmbient = nil
local origBrightness = nil
local origFogEnd = nil
local origGlobalShadows = nil

-- Invisible saved values
local savedTransparencies = {}

-- Murderer ESP highlights
local murdererEspHighlight = nil

-- Alert visual frame
local alertFrame = nil

-- GUI State
local windowVisible = true
local activeTab = "Main"
local logLines = {}
local MAX_LOG_LINES = 50

local origWalkSpeed = 16
local origJumpPower = 50

-- Dynamic labels
local roleLabel = nil
local coinCountLabel = nil

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
	murdererPlayer = nil
	sheriffPlayer = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local role = getPlayerRole(player)
		if role == "Murderer" then murdererPlayer = player end
		if role == "Sheriff" then sheriffPlayer = player end
		if player == LocalPlayer then myRole = role end
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
	tabBtn.Size = UDim2.new(0, 96, 1, 0)
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

-- ===================== ROLE DETECTION SYSTEM =====================
local function startRoleCheck()
	roleCheckEnabled = true
	roleCheckConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local now = tick()
			if now - lastRoleScan < 0.5 then return end
			lastRoleScan = now

			scanRoles()

			-- Update role label dynamically
			if roleLabel then
				local roleText = "Role: " .. myRole
				if murdererPlayer then
					roleText = roleText .. " | Murderer: " .. murdererPlayer.DisplayName
				end
				if sheriffPlayer then
					roleText = roleText .. " | Sheriff: " .. sheriffPlayer.DisplayName
				end
				roleLabel.Text = roleText
			end
		end)
	end)
	addLog("[ROLE CHECK] ON - Scanning roles every 0.5s", COLORS.success)
end

local function stopRoleCheck()
	roleCheckEnabled = false
	if roleCheckConnection then roleCheckConnection:Disconnect() roleCheckConnection = nil end
	myRole = "Unknown"
	murdererPlayer = nil
	sheriffPlayer = nil
	addLog("[ROLE CHECK] OFF", COLORS.error)
end

-- ===================== MURDERER ESP =====================
local function enableMurdererEsp()
	-- Runs via the role check system; we just mark it enabled and handle in ESP refresh
	addLog("[MURDERER ESP] ON - Red highlight on murderer", COLORS.success)
end

local function disableMurdererEsp()
	if murdererEspHighlight then pcall(function() murdererEspHighlight:Destroy() end) murdererEspHighlight = nil end
	addLog("[MURDERER ESP] OFF", COLORS.error)
end

local function updateMurdererEsp()
	-- Remove stale highlight
	if murdererEspHighlight then
		local alive = false
		pcall(function() if murdererEspHighlight and murdererEspHighlight.Adornee and murdererEspHighlight.Adornee.Parent then alive = true end end)
		if not alive then
			pcall(function() murdererEspHighlight:Destroy() end)
			murdererEspHighlight = nil
		end
	end

	if not murdererEspEnabled then
		if murdererEspHighlight then pcall(function() murdererEspHighlight:Destroy() end) murdererEspHighlight = nil end
		return
	end

	if murdererPlayer and murdererPlayer.Character and murdererPlayer.Character.Parent then
		if not murdererEspHighlight or not murdererEspHighlight.Parent then
			pcall(function()
				murdererEspHighlight = Instance.new("Highlight")
				murdererEspHighlight.Name = "MurdererESP"
				murdererEspHighlight.FillColor = Color3.fromRGB(255, 0, 0)
				murdererEspHighlight.OutlineColor = Color3.fromRGB(255, 50, 50)
				murdererEspHighlight.FillTransparency = 0.3
				murdererEspHighlight.OutlineTransparency = 0
				murdererEspHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				murdererEspHighlight.Adornee = murdererPlayer.Character
				murdererEspHighlight.Parent = murdererPlayer.Character
			end)
		end
	else
		if murdererEspHighlight then pcall(function() murdererEspHighlight:Destroy() end) murdererEspHighlight = nil end
	end
end

-- ===================== MURDERER ALERT =====================
local function startMurdererAlert()
	alertConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not murdererPlayer then return end
			local myChar = LocalPlayer.Character
			local theirChar = murdererPlayer.Character
			if not myChar or not theirChar then return end
			local myRoot = myChar:FindFirstChild("HumanoidRootPart")
			local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
			if not myRoot or not theirRoot then return end
			local dist = (myRoot.Position - theirRoot.Position).Magnitude
			if dist < 30 and not alertActive then
				alertActive = true
				addLog("[ALERT] MURDERER NEARBY! (" .. math.floor(dist) .. "m)", COLORS.error)
				-- Flash screen border red
				_spawn(function()
					for flashIdx = 1, 3 do
						pcall(function()
							if alertFrame then alertFrame:Destroy() alertFrame = nil end
							alertFrame = Instance.new("Frame")
							alertFrame.Name = "AlertFlash"
							alertFrame.Size = UDim2.new(1, 0, 1, 0)
							alertFrame.Position = UDim2.new(0, 0, 0, 0)
							alertFrame.BackgroundTransparency = 1
							alertFrame.Parent = screenGui
							alertFrame.ZIndex = 100

							-- Top border
							local topBorder = Instance.new("Frame")
							topBorder.Size = UDim2.new(1, 0, 0, 6)
							topBorder.Position = UDim2.new(0, 0, 0, 0)
							topBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
							topBorder.BackgroundTransparency = 0.2
							topBorder.BorderSizePixel = 0
							topBorder.Parent = alertFrame

							-- Bottom border
							local bottomBorder = Instance.new("Frame")
							bottomBorder.Size = UDim2.new(1, 0, 0, 6)
							bottomBorder.Position = UDim2.new(0, 0, 1, -6)
							bottomBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
							bottomBorder.BackgroundTransparency = 0.2
							bottomBorder.BorderSizePixel = 0
							bottomBorder.Parent = alertFrame

							-- Left border
							local leftBorder = Instance.new("Frame")
							leftBorder.Size = UDim2.new(0, 6, 1, 0)
							leftBorder.Position = UDim2.new(0, 0, 0, 0)
							leftBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
							leftBorder.BackgroundTransparency = 0.2
							leftBorder.BorderSizePixel = 0
							leftBorder.Parent = alertFrame

							-- Right border
							local rightBorder = Instance.new("Frame")
							rightBorder.Size = UDim2.new(0, 6, 1, 0)
							rightBorder.Position = UDim2.new(1, -6, 0, 0)
							rightBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
							rightBorder.BackgroundTransparency = 0.2
							rightBorder.BorderSizePixel = 0
							rightBorder.Parent = alertFrame
						end)
						_wait(0.2)
						pcall(function()
							if alertFrame then alertFrame:Destroy() alertFrame = nil end
						end)
						_wait(0.1)
					end
					alertActive = false
				end)
			elseif dist >= 30 then
				alertActive = false
			end
		end)
	end)
	addLog("[ALERT] ON - Warning when murderer is within 30 studs", COLORS.success)
end

local function stopMurdererAlert()
	if alertConnection then alertConnection:Disconnect() alertConnection = nil end
	if alertFrame then pcall(function() alertFrame:Destroy() end) alertFrame = nil end
	alertActive = false
	addLog("[ALERT] OFF", COLORS.error)
end

-- ===================== AUTO SHOOT MURDERER (SHERIFF ONLY) =====================
local function startAutoShootMurderer()
	autoShootConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			-- Only works when local player is sheriff
			if myRole ~= "Sheriff" then return end
			if not murdererPlayer then return end
			local theirChar = murdererPlayer.Character
			if not theirChar then return end
			local theirHead = theirChar:FindFirstChild("Head") or theirChar:FindFirstChild("HumanoidRootPart")
			if not theirHead then return end

			local myChar = LocalPlayer.Character
			if not myChar then return end
			local myRoot = myChar:FindFirstChild("HumanoidRootPart")
			if not myRoot then return end

			-- Check if we have the gun equipped
			local hasGun = false
			for _, child in ipairs(myChar:GetChildren()) do
				if child:IsA("Tool") and (child.Name == "Gun" or child.Name == "Revolver" or child.Name:lower():find("gun") or child.Name:lower():find("revolver")) then
					hasGun = true
					break
				end
			end
			if not hasGun then return end

			-- Check distance
			local dist = (myRoot.Position - theirHead.Position).Magnitude
			if dist > 300 then return end

			-- Aim at murderer using mousemoverel
			local cam = workspace.CurrentCamera
			local screenPos, onScreen = cam:WorldToViewportPoint(theirHead.Position)
			if not onScreen then return end

			local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
			local delta = Vector2.new(screenPos.X - screenCenter.X, screenPos.Y - screenCenter.Y)

			local sensitivity = 1.5
			local moveX = (delta.X / aimSmoothing) * sensitivity
			local moveY = (delta.Y / aimSmoothing) * sensitivity

			-- Minimum movement threshold
			if math.abs(moveX) < 1 and math.abs(delta.X) > 1 then
				moveX = delta.X > 0 and 1 or -1
			end
			if math.abs(moveY) < 1 and math.abs(delta.Y) > 1 then
				moveY = delta.Y > 0 and 1 or -1
			end

			-- Use mousemoverel if available
			if mousemoverel then
				mousemoverel(moveX, moveY)
			else
				-- Fallback: direct CFrame set
				local currentCF = cam.CFrame
				local targetCF = CFrame.new(cam.CFrame.Position, theirHead.Position)
				cam.CFrame = currentCF:Lerp(targetCF, 1 / aimSmoothing)
			end

			-- Auto fire when close to crosshair
			if math.abs(delta.X) < 15 and math.abs(delta.Y) < 15 then
				pcall(function()
					if mouse1click then
						mouse1click()
					end
					-- Also try tool activation
					for _, child in ipairs(myChar:GetChildren()) do
						if child:IsA("Tool") then
							pcall(function() child:Activate() end)
							break
						end
					end
				end)
			end
		end)
	end)
	addLog("[AUTO SHOOT] ON - Auto-targeting murderer (Sheriff only)", COLORS.success)
end

local function stopAutoShootMurderer()
	if autoShootConnection then autoShootConnection:Disconnect() autoShootConnection = nil end
	addLog("[AUTO SHOOT] OFF", COLORS.error)
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
	autoGrabConnection = workspace.ChildAdded:Connect(function(child)
		if not autoGrabGunEnabled then return end
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
			if not autoGrabGunEnabled then return end
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
		table.insert(espConnections, gdConn)
	end
	addLog("[AUTO GRAB] ON - Watching for gun drops", COLORS.success)
end

local function stopAutoGrabGun()
	if autoGrabConnection then autoGrabConnection:Disconnect() autoGrabConnection = nil end
	addLog("[AUTO GRAB] OFF", COLORS.error)
end

-- ===================== PLAYER ESP (Role-Based Colors) =====================
local function addPlayerHighlight(player)
	if player == LocalPlayer then return end
	if playerEspHighlights[player] then return end
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
		if showNamesEnabled then
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
		if showRoleEnabled then
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
		if showDistanceEnabled then
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
			table.insert(espConnections, distConn)
		end

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
		if not espEnabled then return end
		_wait(1)
		if espEnabled then addPlayerHighlight(player) addPlayerNametag(player) end
	end)
	table.insert(espConnections, conn)
end

local function enablePlayerEsp()
	for _, player in ipairs(Players:GetPlayers()) do hookPlayerForEsp(player) end
	local addedConn = Players.PlayerAdded:Connect(function(player)
		if not espEnabled then return end
		hookPlayerForEsp(player)
	end)
	table.insert(espConnections, addedConn)
	local count, skipped = playerEspScanAll()
	addLog("[ESP] ON - " .. count .. " highlighted, " .. skipped .. " pending", COLORS.success)
	_spawn(function()
		while espEnabled do
			_wait(REFRESH_INTERVAL)
			if not espEnabled then break end
			playerEspScanAll()
			-- Also update murderer ESP while we're at it
			updateMurdererEsp()
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
	addLog("[ESP] OFF", COLORS.error)
end

-- ===================== GUN ESP =====================
local function clearGunEsp()
	for _, hl in pairs(gunEspHighlights) do pcall(function() hl:Destroy() end) end
	gunEspHighlights = {}
end

local function refreshGunEsp()
	clearGunEsp()
	if not gunEspEnabled then return end

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
				table.insert(gunEspHighlights, hl)
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
					table.insert(gunEspHighlights, hl)
				end
			end
		end
	end)
end

local function enableGunEsp()
	refreshGunEsp()
	-- Watch for new gun drops
	gunEspConnection = workspace.ChildAdded:Connect(function(child)
		if not gunEspEnabled then return end
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
				table.insert(gunEspHighlights, hl)
			end
		end)
	end)
	-- Periodic refresh
	_spawn(function()
		while gunEspEnabled do
			_wait(3)
			if not gunEspEnabled then break end
			refreshGunEsp()
		end
	end)
	addLog("[GUN ESP] ON - Yellow highlight on dropped guns", COLORS.success)
end

local function disableGunEsp()
	clearGunEsp()
	if gunEspConnection then gunEspConnection:Disconnect() gunEspConnection = nil end
	addLog("[GUN ESP] OFF", COLORS.error)
end

-- ===================== COIN ESP =====================
local function clearCoinEsp()
	for _, hl in pairs(coinEspHighlights) do pcall(function() hl:Destroy() end) end
	coinEspHighlights = {}
end

local function refreshCoinEsp()
	clearCoinEsp()
	if not coinEspEnabled then return end

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
			table.insert(coinEspHighlights, hl)
		end
	end)
end

local function enableCoinEsp()
	refreshCoinEsp()
	-- Periodic refresh
	_spawn(function()
		while coinEspEnabled do
			_wait(5)
			if not coinEspEnabled then break end
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

-- ===================== AUTO COIN FARM =====================
local function startAutoCoinFarm()
	coinsFarmed = 0
	coinFarmThread = _spawn(function()
		while autoCoinFarmEnabled do
			pcall(function()
				local coins = getCoins()
				if #coins == 0 then
					addLog("[FARM] No coins found, waiting...", COLORS.textSecondary)
					_wait(2)
					return
				end

				for _, coin in ipairs(coins) do
					if not autoCoinFarmEnabled then break end
					pcall(function()
						local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
						if root and coin and coin.Parent and coin.Transparency < 1 then
							root.CFrame = coin.CFrame + Vector3.new(0, 2, 0)
							coinsFarmed = coinsFarmed + 1
							if coinCountLabel then
								coinCountLabel.Text = "Coins Farmed: " .. coinsFarmed
							end
						end
					end)
					_wait(farmSpeed)
				end
			end)
			_wait(1)
		end
	end)
	addLog("[FARM] ON - Teleporting to coins (speed: " .. farmSpeed .. "s)", COLORS.success)
end

local function stopAutoCoinFarm()
	autoCoinFarmEnabled = false
	addLog("[FARM] OFF - Farmed " .. coinsFarmed .. " coins", COLORS.error)
end

-- ===================== ANTI-AFK =====================
local function startAntiAfk()
	antiAfkConnection = _spawn(function()
		while antiAfkEnabled do
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
	antiAfkEnabled = false
	addLog("[ANTI-AFK] OFF", COLORS.error)
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
	-- Keep health topped up
	godConnection = RunService.Heartbeat:Connect(function()
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

-- ===================== INVISIBLE LOGIC =====================
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

-- ===================== CAMERA FOV =====================
local function setCameraFOV(fov)
	pcall(function()
		workspace.CurrentCamera.FieldOfView = fov
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
	createInfoLabel(tab, "MM2 Hub v1.0", 2)
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
	roleLabel = createInfoLabel(tab, "Role: Unknown", 10)

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
		murdererEspEnabled = on
		if on then
			if not roleCheckEnabled then startRoleCheck() end
			enableMurdererEsp()
		else
			disableMurdererEsp()
		end
	end)
	createToggle(tab, "Murderer Alert", 3, function(on)
		murdererAlertEnabled = on
		if on then
			if not roleCheckEnabled then startRoleCheck() end
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
		autoShootMurdererEnabled = on
		if on then
			if not roleCheckEnabled then startRoleCheck() end
			startAutoShootMurderer()
		else
			stopAutoShootMurderer()
		end
	end)
	createSlider(tab, "Aim Smoothing", 1, 10, aimSmoothing, 7, function(val)
		aimSmoothing = val
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
	createToggle(tab, "Auto Grab Gun", 11, function(on)
		autoGrabGunEnabled = on
		if on then startAutoGrabGun() else stopAutoGrabGun() end
	end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 12
	spacer3.Parent = tab

	createSectionLabel(tab, "Info", 13)
	createInfoLabel(tab, "Auto Shoot only works as Sheriff", 14)
	createInfoLabel(tab, "Equip gun first for Auto Shoot", 15)
end

-- =====================================================================
-- ======================== BUILD ESP TAB =============================
-- =====================================================================
do
	local tab = tabFrames["ESP"]

	createSectionLabel(tab, "Player ESP", 1)

	createToggle(tab, "ESP", 2, function(on)
		espEnabled = on
		if on then
			if not roleCheckEnabled then startRoleCheck() end
			enablePlayerEsp()
		else
			disablePlayerEsp()
		end
	end)
	createToggle(tab, "Show Names", 3, function(on)
		showNamesEnabled = on
		if espEnabled then
			disablePlayerEsp()
			_wait(0.2)
			enablePlayerEsp()
		end
	end).setVisualState(true)
	createToggle(tab, "Show Distance", 4, function(on)
		showDistanceEnabled = on
		if espEnabled then
			disablePlayerEsp()
			_wait(0.2)
			enablePlayerEsp()
		end
	end).setVisualState(true)
	createToggle(tab, "Show Role", 5, function(on)
		showRoleEnabled = on
		if espEnabled then
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
		gunEspEnabled = on
		if on then enableGunEsp() else disableGunEsp() end
	end)
	createToggle(tab, "Coin ESP", 9, function(on)
		coinEspEnabled = on
		if on then enableCoinEsp() else disableCoinEsp() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 10
	spacer2.Parent = tab

	createSectionLabel(tab, "World", 11)

	createToggle(tab, "Fullbright", 12, function(on)
		fullbrightEnabled = on
		if on then startFullbright() else stopFullbright() end
	end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 4)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 13
	spacer3.Parent = tab

	createSectionLabel(tab, "Info", 14)
	createInfoLabel(tab, "ESP colors: Red=Murderer, Blue=Sheriff, Green=Innocent", 15)
	createInfoLabel(tab, "Gun ESP: Yellow highlight on dropped guns", 16)
	createInfoLabel(tab, "Coin ESP: Gold highlight on collectible coins", 17)
end

-- =====================================================================
-- ======================== BUILD FARMING TAB ==========================
-- =====================================================================
do
	local tab = tabFrames["Farming"]

	createSectionLabel(tab, "Coins", 1)

	createToggle(tab, "Auto Coin Farm", 2, function(on)
		autoCoinFarmEnabled = on
		if on then startAutoCoinFarm() else stopAutoCoinFarm() end
	end)
	createSlider(tab, "Farm Speed (seconds)", 1, 20, math.floor(farmSpeed * 10), 3, function(val)
		farmSpeed = val / 10
	end)
	coinCountLabel = createInfoLabel(tab, "Coins Farmed: 0", 4)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 4)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 5
	spacer.Parent = tab

	createSectionLabel(tab, "XP", 6)

	createToggle(tab, "Anti-AFK", 7, function(on)
		antiAfkEnabled = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 8
	spacer2.Parent = tab

	createSectionLabel(tab, "Info", 9)
	createInfoLabel(tab, "Auto Coin Farm teleports to each coin", 10)
	createInfoLabel(tab, "Anti-AFK prevents idle kick", 11)
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

	createSectionLabel(tab, "Survival", 10)

	createToggle(tab, "God Mode", 11, function(on)
		godEnabled = on
		if on then startGod() else stopGod() end
	end)
	createToggle(tab, "Invisible", 12, function(on)
		invisibleEnabled = on
		if on then startInvisible() else stopInvisible() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 13
	spacer2.Parent = tab

	createSectionLabel(tab, "Camera", 14)

	createSlider(tab, "Camera FOV", 50, 120, cameraFOV, 15, function(val)
		cameraFOV = val
		setCameraFOV(val)
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
	createToggle(tab, "Seizure", 7, function(on)
		seizureEnabled = on
		if on then startSeizure() else stopSeizure() end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 4)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 8
	spacer2.Parent = tab

	createSectionLabel(tab, "Emotes", 9)

	createActionButton(tab, "Emote 1", 10, function()
		playJerkEmote()
	end)
	createActionButton(tab, "Dance", 11, function()
		playEmote(507771019, 1, 10)
		addLog("[EMOTE] Dance!", COLORS.success)
	end)
	createActionButton(tab, "Dab", 12, function()
		playEmote(183412246, 1, 3)
		addLog("[EMOTE] Dab!", COLORS.success)
	end)
	createActionButton(tab, "Stop Emote", 13, function()
		stopEmote()
		addLog("[EMOTE] Stopped", COLORS.error)
	end)
end

-- =====================================================================
-- ======================== CHAT COMMANDS =============================
-- =====================================================================
local commands = {}

-- Combat
commands["murderesp"] = function() murdererEspEnabled = true if not roleCheckEnabled then startRoleCheck() end enableMurdererEsp() end
commands["unmurderesp"] = function() murdererEspEnabled = false disableMurdererEsp() end
commands["alert"] = function() murdererAlertEnabled = true if not roleCheckEnabled then startRoleCheck() end startMurdererAlert() end
commands["unalert"] = function() murdererAlertEnabled = false stopMurdererAlert() end
commands["autoshoot"] = function() autoShootMurdererEnabled = true if not roleCheckEnabled then startRoleCheck() end startAutoShootMurderer() end
commands["unautoshoot"] = function() autoShootMurdererEnabled = false stopAutoShootMurderer() end
commands["grabgun"] = function() grabDroppedGun() end
commands["autograb"] = function() autoGrabGunEnabled = true startAutoGrabGun() end
commands["unautograb"] = function() autoGrabGunEnabled = false stopAutoGrabGun() end

-- ESP
commands["esp"] = function() espEnabled = true if not roleCheckEnabled then startRoleCheck() end enablePlayerEsp() end
commands["unesp"] = function() espEnabled = false disablePlayerEsp() end
commands["gunesp"] = function() gunEspEnabled = true enableGunEsp() end
commands["ungunesp"] = function() gunEspEnabled = false disableGunEsp() end
commands["coinesp"] = function() coinEspEnabled = true enableCoinEsp() end
commands["uncoinesp"] = function() coinEspEnabled = false disableCoinEsp() end
commands["fullbright"] = function() fullbrightEnabled = true startFullbright() end
commands["unfullbright"] = function() fullbrightEnabled = false stopFullbright() end

-- Farming
commands["coinfarm"] = function() autoCoinFarmEnabled = true startAutoCoinFarm() end
commands["uncoinfarm"] = function() autoCoinFarmEnabled = false stopAutoCoinFarm() end
commands["antiafk"] = function() antiAfkEnabled = true startAntiAfk() end
commands["unantiafk"] = function() antiAfkEnabled = false stopAntiAfk() end

-- Player
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
commands["god"] = function() godEnabled = true startGod() end
commands["ungod"] = function() godEnabled = false stopGod() end
commands["invisible"] = function() invisibleEnabled = true startInvisible() end
commands["uninvisible"] = function() invisibleEnabled = false stopInvisible() end
commands["fov"] = function(args)
	local v = tonumber(args[1])
	if v then
		cameraFOV = v
		setCameraFOV(v)
		addLog("[FOV] Set to " .. v, COLORS.success)
	else
		addLog("[FOV] Usage: ;fov [50-120]", COLORS.error)
	end
end

-- Fun
commands["fling"] = function() flingEnabled = true startFling() end
commands["unfling"] = function() flingEnabled = false stopFling() end
commands["spin"] = function() spinEnabled = true startSpin() end
commands["unspin"] = function() spinEnabled = false stopSpin() end
commands["seizure"] = function() seizureEnabled = true startSeizure() end
commands["unseizure"] = function() seizureEnabled = false stopSeizure() end
commands["emote1"] = function() playJerkEmote() end
commands["dance"] = function() playEmote(507771019, 1, 10) addLog("[EMOTE] Dance!", COLORS.success) end
commands["dab"] = function() playEmote(183412246, 1, 3) addLog("[EMOTE] Dab!", COLORS.success) end
commands["stopemote"] = function() stopEmote() addLog("[EMOTE] Stopped", COLORS.error) end

-- Utility
commands["rejoin"] = function() rejoinServer() end
commands["serverhop"] = function() serverHop() end

-- Help
commands["cmds"] = function()
	addLog("--- MM2 Hub Commands ---", COLORS.accent)
	addLog("-- Combat --", COLORS.accent)
	addLog(";murderesp / ;unmurderesp", COLORS.textSecondary)
	addLog(";alert / ;unalert (murderer proximity)", COLORS.textSecondary)
	addLog(";autoshoot / ;unautoshoot (sheriff only)", COLORS.textSecondary)
	addLog(";grabgun    ;autograb / ;unautograb", COLORS.textSecondary)
	addLog("-- ESP --", COLORS.accent)
	addLog(";esp / ;unesp (role-colored ESP)", COLORS.textSecondary)
	addLog(";gunesp / ;ungunesp    ;coinesp / ;uncoinesp", COLORS.textSecondary)
	addLog(";fullbright / ;unfullbright", COLORS.textSecondary)
	addLog("-- Farming --", COLORS.accent)
	addLog(";coinfarm / ;uncoinfarm    ;antiafk / ;unantiafk", COLORS.textSecondary)
	addLog("-- Player --", COLORS.accent)
	addLog(";fly / ;unfly    ;noclip / ;unnoclip", COLORS.textSecondary)
	addLog(";speed [val] / ;unspeed    ;infjump / ;uninfjump", COLORS.textSecondary)
	addLog(";god / ;ungod    ;invisible / ;uninvisible", COLORS.textSecondary)
	addLog(";fov [val]", COLORS.textSecondary)
	addLog("-- Fun --", COLORS.accent)
	addLog(";fling / ;unfling    ;spin / ;unspin", COLORS.textSecondary)
	addLog(";seizure / ;unseizure", COLORS.textSecondary)
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
		_wait(0.2)
		startNoclip()
	end

	-- Re-enable infinite jump
	if infJumpEnabled then
		_wait(0.2)
		startInfJump()
	end

	-- Re-enable jump power
	if jumpPowerValue ~= 50 then
		_wait(0.3)
		setJumpPower(jumpPowerValue)
	end

	-- Re-enable god mode
	if godEnabled then
		_wait(0.3)
		startGod()
	end

	-- Re-enable invisible
	if invisibleEnabled then
		_wait(0.3)
		startInvisible()
	end

	-- Re-enable fullbright
	if fullbrightEnabled then
		_wait(0.2)
		startFullbright()
	end

	-- Re-enable camera FOV
	if cameraFOV ~= 70 then
		_wait(0.3)
		setCameraFOV(cameraFOV)
	end

	-- Re-enable role check
	if roleCheckEnabled then
		stopRoleCheck()
		_wait(0.3)
		startRoleCheck()
	end

	-- Re-enable murderer alert
	if murdererAlertEnabled then
		stopMurdererAlert()
		_wait(0.3)
		startMurdererAlert()
	end

	-- Re-enable auto shoot
	if autoShootMurdererEnabled then
		stopAutoShootMurderer()
		_wait(0.3)
		startAutoShootMurderer()
	end

	-- Re-enable auto grab gun
	if autoGrabGunEnabled then
		stopAutoGrabGun()
		_wait(0.3)
		startAutoGrabGun()
	end

	-- Re-enable ESP
	if espEnabled then
		disablePlayerEsp()
		_wait(0.5)
		enablePlayerEsp()
	end

	-- Re-enable gun ESP
	if gunEspEnabled then
		disableGunEsp()
		_wait(0.3)
		enableGunEsp()
	end

	-- Re-enable coin ESP
	if coinEspEnabled then
		disableCoinEsp()
		_wait(0.3)
		enableCoinEsp()
	end

	-- Re-enable murderer ESP
	if murdererEspEnabled then
		_wait(0.3)
		updateMurdererEsp()
	end

	-- Re-enable auto coin farm
	if autoCoinFarmEnabled then
		_wait(0.5)
		startAutoCoinFarm()
	end
end)

-- ===================== STARTUP =====================
-- Start role check automatically so role label updates
startRoleCheck()

addLog("MM2 Hub v1.0", COLORS.accent)
addLog("Type ;cmds for command list", COLORS.textSecondary)
addLog("Use Right Shift to toggle GUI", COLORS.textSecondary)
addLog("Role detection active - scanning every 0.5s", COLORS.textSecondary)
print("[MM2 Hub] v1.0 loaded")
