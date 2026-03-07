-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("industrialist") then return end

-- ================================================================
-- Pebbleford Hub - Industrialist Auto Farm v1.0
-- Auto-place farm layouts | Resource monitor | Auto-sell
-- Auto-wire | Auto-pipe | Remote discovery
-- ================================================================

print("[PB Industrialist v1.0] Loading...")

-- Cleanup old instance
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("PBIndustrialist")
	if old then old:Destroy() end
end)
pcall(function()
	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		local o2 = pg:FindFirstChild("PBIndustrialist")
		if o2 then o2:Destroy() end
	end
end)

-- ===================== SERVICES =====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===================== COLORS =====================
local COLORS = {
	bg = Color3.fromRGB(18, 18, 24),
	bgSecondary = Color3.fromRGB(26, 26, 34),
	tabBg = Color3.fromRGB(38, 38, 50),
	accent = Color3.fromRGB(255, 165, 0),
	accentDark = Color3.fromRGB(200, 120, 0),
	text = Color3.fromRGB(230, 230, 230),
	textDim = Color3.fromRGB(150, 150, 165),
	toggleOn = Color3.fromRGB(255, 165, 0),
	toggleOff = Color3.fromRGB(60, 60, 75),
	border = Color3.fromRGB(55, 55, 70),
	success = Color3.fromRGB(0, 200, 100),
	danger = Color3.fromRGB(220, 50, 50),
}

-- ===================== STATE =====================
local guiOpen = true
local activeTab = "Farms"
local logs = {}
local logMax = 50

-- Remote discovery
local discoveredRemotes = {}
local placeRemote = nil
local pipeRemote = nil
local wireRemote = nil
local sellRemote = nil
local removeRemote = nil

-- Auto-farm state
local autoSellEnabled = false
local autoSellConnection = nil
local currentFarmBuilding = false

-- ===================== REMOTE DISCOVERY =====================
local function scanRemotes(parent, depth)
	depth = depth or 0
	if depth > 4 then return end
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
			local name = child.Name:lower()
			discoveredRemotes[child.Name] = {
				instance = child,
				type = child.ClassName,
				path = child:GetFullName()
			}
			-- Auto-detect key remotes
			if name:find("place") or name:find("build") or name:find("spawn") then
				if not placeRemote then placeRemote = child end
			end
			if name:find("pipe") or name:find("connect") then
				if not pipeRemote then pipeRemote = child end
			end
			if name:find("wire") or name:find("power") or name:find("electric") then
				if not wireRemote then wireRemote = child end
			end
			if name:find("sell") or name:find("depot") or name:find("truck") then
				if not sellRemote then sellRemote = child end
			end
			if name:find("remove") or name:find("destroy") or name:find("demolish") or name:find("delete") then
				if not removeRemote then removeRemote = child end
			end
		end
		if #child:GetChildren() > 0 then
			scanRemotes(child, depth + 1)
		end
	end
end

local function discoverRemotes()
	discoveredRemotes = {}
	placeRemote = nil
	pipeRemote = nil
	wireRemote = nil
	sellRemote = nil
	removeRemote = nil
	scanRemotes(ReplicatedStorage)
	scanRemotes(game:GetService("Players").LocalPlayer.PlayerGui)
	pcall(function() scanRemotes(workspace) end)
	return discoveredRemotes
end

-- ===================== FARM BLUEPRINTS =====================
-- Each blueprint defines machines and their relative positions in a grid
-- Positions are in studs relative to origin (where player stands)

local FARM_BLUEPRINTS = {
	{
		name = "Coal Starter",
		description = "3 Coal Drills -> Truck Depot. Simple money maker.",
		tier = "Early",
		machines = {
			{name = "Coal Drill", offset = Vector3.new(0, 0, 0)},
			{name = "Coal Drill", offset = Vector3.new(8, 0, 0)},
			{name = "Coal Drill", offset = Vector3.new(16, 0, 0)},
			{name = "Truck Depot", offset = Vector3.new(8, 0, 16)},
			{name = "Coal Generator", offset = Vector3.new(-8, 0, 8)},
		},
		pipes = {
			{from = 1, to = 4},
			{from = 2, to = 4},
			{from = 3, to = 4},
		},
		wires = {
			{from = 5, to = 1},
			{from = 5, to = 2},
			{from = 5, to = 3},
			{from = 5, to = 4},
		},
	},
	{
		name = "Copper Wire Line",
		description = "9 Copper Drills -> 3 Furnaces -> Molder -> 2 Presses -> 2 Rollers -> 4 Depots",
		tier = "Early-Mid",
		machines = {
			-- Row 1: Drills
			{name = "Copper Drill", offset = Vector3.new(0, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(8, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(16, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(24, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(32, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(40, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(48, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(56, 0, 0)},
			{name = "Copper Drill", offset = Vector3.new(64, 0, 0)},
			-- Row 2: Furnaces
			{name = "Electric Furnace", offset = Vector3.new(8, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(32, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(56, 0, 16)},
			-- Row 3: Molder
			{name = "Ingot Molder", offset = Vector3.new(32, 0, 32)},
			-- Row 4: Presses + Rollers
			{name = "Press", offset = Vector3.new(16, 0, 48)},
			{name = "Press", offset = Vector3.new(48, 0, 48)},
			{name = "Roller", offset = Vector3.new(16, 0, 64)},
			{name = "Roller", offset = Vector3.new(48, 0, 64)},
			-- Row 5: Truck Depots
			{name = "Truck Depot", offset = Vector3.new(0, 0, 80)},
			{name = "Truck Depot", offset = Vector3.new(20, 0, 80)},
			{name = "Truck Depot", offset = Vector3.new(40, 0, 80)},
			{name = "Truck Depot", offset = Vector3.new(60, 0, 80)},
			-- Power
			{name = "Coal Generator", offset = Vector3.new(-12, 0, 32)},
			{name = "Coal Generator", offset = Vector3.new(76, 0, 32)},
		},
	},
	{
		name = "Iron Coil Line",
		description = "15 Iron Drills -> 5 Furnaces -> Molder -> 8 Sawmills -> 8 Rollers -> Van Depots",
		tier = "Mid",
		machines = {
			-- Drills row
			{name = "Iron Drill", offset = Vector3.new(0, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(8, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(16, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(24, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(32, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(40, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(48, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(56, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(64, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(72, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(80, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(88, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(96, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(104, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(112, 0, 0)},
			-- Furnaces
			{name = "Electric Furnace", offset = Vector3.new(8, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(32, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(56, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(80, 0, 16)},
			{name = "Electric Furnace", offset = Vector3.new(104, 0, 16)},
			-- Molder
			{name = "Ingot Molder", offset = Vector3.new(56, 0, 32)},
			-- Sawmills
			{name = "Sawmill", offset = Vector3.new(0, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(16, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(32, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(48, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(64, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(80, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(96, 0, 48)},
			{name = "Sawmill", offset = Vector3.new(112, 0, 48)},
			-- Rollers
			{name = "Roller", offset = Vector3.new(0, 0, 64)},
			{name = "Roller", offset = Vector3.new(16, 0, 64)},
			{name = "Roller", offset = Vector3.new(32, 0, 64)},
			{name = "Roller", offset = Vector3.new(48, 0, 64)},
			{name = "Roller", offset = Vector3.new(64, 0, 64)},
			{name = "Roller", offset = Vector3.new(80, 0, 64)},
			{name = "Roller", offset = Vector3.new(96, 0, 64)},
			{name = "Roller", offset = Vector3.new(112, 0, 64)},
			-- Van Depots
			{name = "Van Depot", offset = Vector3.new(20, 0, 80)},
			{name = "Van Depot", offset = Vector3.new(90, 0, 80)},
			-- Power
			{name = "Coal Generator", offset = Vector3.new(-12, 0, 24)},
			{name = "Coal Generator", offset = Vector3.new(-12, 0, 48)},
			{name = "Coal Generator", offset = Vector3.new(124, 0, 24)},
			{name = "Coal Generator", offset = Vector3.new(124, 0, 48)},
		},
	},
	{
		name = "Gearbox Factory",
		description = "Crankshafts + Plastic Casings -> Craft Assemblers. $2,552/unit.",
		tier = "Mid-Late",
		machines = {
			-- Crankshaft line (simplified)
			{name = "Iron Drill", offset = Vector3.new(0, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(8, 0, 0)},
			{name = "Iron Drill", offset = Vector3.new(16, 0, 0)},
			{name = "Electric Furnace", offset = Vector3.new(8, 0, 16)},
			{name = "Ingot Molder", offset = Vector3.new(8, 0, 32)},
			{name = "Press", offset = Vector3.new(8, 0, 48)},
			-- Plastic line
			{name = "Oil Pump", offset = Vector3.new(40, 0, 0)},
			{name = "Oil Pump", offset = Vector3.new(48, 0, 0)},
			{name = "Plastic Molding Machine", offset = Vector3.new(44, 0, 16)},
			-- Assemblers
			{name = "Craft Assembler", offset = Vector3.new(24, 0, 64)},
			{name = "Craft Assembler", offset = Vector3.new(36, 0, 64)},
			-- Sell
			{name = "Truck Depot", offset = Vector3.new(30, 0, 80)},
			-- Power
			{name = "Coal Generator", offset = Vector3.new(-12, 0, 32)},
			{name = "Coal Generator", offset = Vector3.new(60, 0, 32)},
		},
	},
}

-- ===================== LOGGING =====================
local logFrame = nil
local function addLog(msg)
	table.insert(logs, "[" .. os.date("%H:%M:%S") .. "] " .. msg)
	if #logs > logMax then table.remove(logs, 1) end
	if logFrame then
		-- Update log display
		for _, child in ipairs(logFrame:GetChildren()) do
			if child:IsA("TextLabel") then child:Destroy() end
		end
		for i, log in ipairs(logs) do
			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(1, -10, 0, 16)
			l.Position = UDim2.new(0, 5, 0, (i - 1) * 16)
			l.BackgroundTransparency = 1
			l.Text = log
			l.TextColor3 = COLORS.textDim
			l.TextSize = 11
			l.Font = Enum.Font.RobotoMono
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.TextTruncate = Enum.TextTruncate.AtEnd
			l.Parent = logFrame
		end
		logFrame.CanvasSize = UDim2.new(0, 0, 0, #logs * 16)
		logFrame.CanvasPosition = Vector2.new(0, math.max(0, #logs * 16 - logFrame.AbsoluteSize.Y))
	end
	print("[PB Industrialist] " .. msg)
end

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PBIndustrialist"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Try CoreGui first, fall back to PlayerGui
pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 520, 0, 420)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
mainFrame.BackgroundColor3 = COLORS.bg
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COLORS.accent
mainStroke.Thickness = 2
mainStroke.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = COLORS.bgSecondary
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

-- Logo
local logoBox = Instance.new("Frame")
logoBox.Size = UDim2.new(0, 26, 0, 26)
logoBox.Position = UDim2.new(0, 6, 0, 5)
logoBox.BackgroundColor3 = COLORS.accent
logoBox.BorderSizePixel = 0
logoBox.Parent = titleBar

local logoCorner = Instance.new("UICorner")
logoCorner.CornerRadius = UDim.new(0, 5)
logoCorner.Parent = logoBox

local logoText = Instance.new("TextLabel")
logoText.Size = UDim2.new(1, 0, 1, 0)
logoText.BackgroundTransparency = 1
logoText.Text = "P"
logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
logoText.TextSize = 16
logoText.Font = Enum.Font.GothamBold
logoText.Parent = logoBox

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 250, 1, 0)
titleLabel.Position = UDim2.new(0, 38, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Pebbleford Hub - Industrialist"
titleLabel.TextColor3 = COLORS.text
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 50, 1, 0)
versionLabel.Position = UDim2.new(0, 290, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.0"
versionLabel.TextColor3 = COLORS.textDim
versionLabel.TextSize = 12
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextXAlignment = Enum.TextXAlignment.Left
versionLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -36, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.danger
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar

-- Minimize button
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 36, 0, 36)
minBtn.Position = UDim2.new(1, -72, 0, 0)
minBtn.BackgroundTransparency = 1
minBtn.Text = "_"
minBtn.TextColor3 = COLORS.textDim
minBtn.TextSize = 16
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = titleBar

-- Dragging
local dragging = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

-- ===================== TABS =====================
local tabNames = {"Farms", "Auto", "Remotes", "Log"}
local tabButtons = {}
local tabFrames = {}

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 30)
tabBar.Position = UDim2.new(0, 0, 0, 36)
tabBar.BackgroundColor3 = COLORS.bgSecondary
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local tabWidth = 1 / #tabNames
for i, name in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(tabWidth, -2, 1, 0)
	btn.Position = UDim2.new(tabWidth * (i - 1), 1, 0, 0)
	btn.BackgroundColor3 = COLORS.tabBg
	btn.BackgroundTransparency = 0.5
	btn.Text = name
	btn.TextColor3 = COLORS.textDim
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamSemibold
	btn.BorderSizePixel = 0
	btn.Parent = tabBar
	tabButtons[name] = btn

	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.new(1, -10, 1, -76)
	frame.Position = UDim2.new(0, 5, 0, 66)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = COLORS.accent
	frame.Visible = (name == activeTab)
	frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	frame.Parent = mainFrame
	tabFrames[name] = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame

	-- Auto-resize canvas
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)
end

local function switchTab(name)
	activeTab = name
	for tName, btn in pairs(tabButtons) do
		if tName == name then
			btn.BackgroundTransparency = 0
			btn.BackgroundColor3 = COLORS.accent
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundTransparency = 0.5
			btn.BackgroundColor3 = COLORS.tabBg
			btn.TextColor3 = COLORS.textDim
		end
	end
	for tName, frame in pairs(tabFrames) do
		frame.Visible = (tName == name)
	end
end

for name, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function() switchTab(name) end)
end
switchTab("Farms")

-- ===================== HELPER: GUI ELEMENTS =====================
local function createSectionLabel(parent, text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -10, 0, 24)
	lbl.BackgroundTransparency = 1
	lbl.Text = "  " .. text
	lbl.TextColor3 = COLORS.accent
	lbl.TextSize = 14
	lbl.Font = Enum.Font.GothamBold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order or 0
	lbl.Parent = parent
	return lbl
end

local function createActionButton(parent, text, order, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 32)
	btn.BackgroundColor3 = COLORS.tabBg
	btn.Text = "  " .. text
	btn.TextColor3 = COLORS.text
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamSemibold
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.BorderSizePixel = 0
	btn.LayoutOrder = order or 0
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.border
	stroke.Thickness = 1
	stroke.Parent = btn

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = COLORS.accentDark
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = COLORS.tabBg
	end)

	if callback then
		btn.MouseButton1Click:Connect(callback)
	end

	return btn
end

local function createToggle(parent, text, default, order, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -10, 0, 32)
	frame.BackgroundColor3 = COLORS.tabBg
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order or 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.border
	stroke.Thickness = 1
	stroke.Parent = frame

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -60, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.text
	lbl.TextSize = 13
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = frame

	local toggleBg = Instance.new("Frame")
	toggleBg.Size = UDim2.new(0, 40, 0, 20)
	toggleBg.Position = UDim2.new(1, -50, 0.5, -10)
	toggleBg.BackgroundColor3 = default and COLORS.toggleOn or COLORS.toggleOff
	toggleBg.BorderSizePixel = 0
	toggleBg.Parent = frame

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 10)
	toggleCorner.Parent = toggleBg

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = toggleBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0, 8)
	knobCorner.Parent = knob

	local enabled = default

	local clickBtn = Instance.new("TextButton")
	clickBtn.Size = UDim2.new(1, 0, 1, 0)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.Parent = frame

	clickBtn.MouseButton1Click:Connect(function()
		enabled = not enabled
		toggleBg.BackgroundColor3 = enabled and COLORS.toggleOn or COLORS.toggleOff
		knob.Position = enabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		if callback then callback(enabled) end
	end)

	return frame, function() return enabled end
end

local function createInfoLabel(parent, text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -10, 0, 20)
	lbl.BackgroundTransparency = 1
	lbl.Text = "  " .. text
	lbl.TextColor3 = COLORS.textDim
	lbl.TextSize = 12
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextWrapped = true
	lbl.LayoutOrder = order or 0
	lbl.Parent = parent
	return lbl
end

-- ===================== PLACEMENT ENGINE =====================
-- Attempts to place a machine at a world position using discovered remotes
-- Falls back to tool simulation if no remote found

local function getPlayerPosition()
	local char = LocalPlayer.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then return root.Position end
	end
	return Vector3.new(0, 0, 0)
end

local function findMachineInShop(machineName)
	-- Search through the game's shop/building system for matching machine
	local results = {}
	-- Check common locations for machine data
	local searchPaths = {
		ReplicatedStorage:FindFirstChild("Buildings"),
		ReplicatedStorage:FindFirstChild("Machines"),
		ReplicatedStorage:FindFirstChild("Items"),
		ReplicatedStorage:FindFirstChild("Shop"),
		ReplicatedStorage:FindFirstChild("Assets"),
		ReplicatedStorage:FindFirstChild("Models"),
		ReplicatedStorage:FindFirstChild("Shared"),
	}
	for _, folder in ipairs(searchPaths) do
		if folder then
			for _, item in ipairs(folder:GetDescendants()) do
				if item.Name:lower():find(machineName:lower():gsub(" ", "")) or
				   item.Name:lower():find(machineName:lower()) then
					table.insert(results, item)
				end
			end
		end
	end
	return results
end

local function tryPlaceMachine(machineName, worldPosition)
	addLog("Placing: " .. machineName .. " at " .. tostring(worldPosition))

	-- Strategy 1: Fire discovered place remote
	if placeRemote then
		local ok, err = pcall(function()
			if placeRemote:IsA("RemoteEvent") then
				-- Try common argument patterns
				placeRemote:FireServer(machineName, worldPosition)
				task.wait(0.1)
				placeRemote:FireServer(machineName, CFrame.new(worldPosition))
				task.wait(0.1)
				-- Try with table args
				placeRemote:FireServer({
					Name = machineName,
					Position = worldPosition,
					CFrame = CFrame.new(worldPosition),
				})
			elseif placeRemote:IsA("RemoteFunction") then
				placeRemote:InvokeServer(machineName, worldPosition)
			end
		end)
		if ok then
			addLog("  -> Fired place remote for " .. machineName)
			return true
		else
			addLog("  -> Remote error: " .. tostring(err))
		end
	end

	-- Strategy 2: Find the hammer tool and simulate placement
	local char = LocalPlayer.Character
	if char then
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		local tool = nil
		-- Look for hammer/building tool
		if backpack then
			for _, t in ipairs(backpack:GetChildren()) do
				if t:IsA("Tool") and (t.Name:lower():find("hammer") or t.Name:lower():find("build") or t.Name:lower():find("place")) then
					tool = t
					break
				end
			end
		end
		if not tool and char then
			for _, t in ipairs(char:GetChildren()) do
				if t:IsA("Tool") and (t.Name:lower():find("hammer") or t.Name:lower():find("build") or t.Name:lower():find("place")) then
					tool = t
					break
				end
			end
		end

		if tool then
			-- Equip the tool
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid and tool.Parent == backpack then
				humanoid:EquipTool(tool)
				task.wait(0.3)
			end
			addLog("  -> Found build tool: " .. tool.Name)
		end
	end

	-- Strategy 3: Try all remotes with place-like patterns
	for remoteName, data in pairs(discoveredRemotes) do
		local rName = remoteName:lower()
		if rName:find("place") or rName:find("build") or rName:find("create") or rName:find("spawn") then
			pcall(function()
				if data.instance:IsA("RemoteEvent") then
					data.instance:FireServer(machineName, worldPosition)
					data.instance:FireServer(machineName, CFrame.new(worldPosition))
				end
			end)
			addLog("  -> Tried remote: " .. remoteName)
			task.wait(0.1)
		end
	end

	return false
end

local function tryConnectPipe(fromPos, toPos)
	if pipeRemote then
		pcall(function()
			if pipeRemote:IsA("RemoteEvent") then
				pipeRemote:FireServer(fromPos, toPos)
			end
		end)
		addLog("Piped: " .. tostring(fromPos) .. " -> " .. tostring(toPos))
	end
end

local function tryConnectWire(fromPos, toPos)
	if wireRemote then
		pcall(function()
			if wireRemote:IsA("RemoteEvent") then
				wireRemote:FireServer(fromPos, toPos)
			end
		end)
		addLog("Wired: " .. tostring(fromPos) .. " -> " .. tostring(toPos))
	end
end

-- ===================== BUILD FARM =====================
local function buildFarm(blueprint)
	if currentFarmBuilding then
		addLog("Already building a farm! Wait for it to finish.")
		return
	end
	currentFarmBuilding = true
	addLog("=== Building: " .. blueprint.name .. " ===")

	local origin = getPlayerPosition()
	-- Snap to grid (8 stud grid typical for Industrialist)
	origin = Vector3.new(
		math.floor(origin.X / 8) * 8,
		origin.Y,
		math.floor(origin.Z / 8) * 8
	)

	addLog("Origin: " .. tostring(origin))

	-- Place all machines
	local placedPositions = {}
	for i, machine in ipairs(blueprint.machines) do
		local worldPos = origin + machine.offset
		placedPositions[i] = worldPos
		tryPlaceMachine(machine.name, worldPos)
		task.wait(0.5) -- Delay between placements to avoid rate limiting
	end

	-- Connect pipes
	if blueprint.pipes then
		task.wait(1)
		addLog("Connecting pipes...")
		for _, pipe in ipairs(blueprint.pipes) do
			tryConnectPipe(placedPositions[pipe.from], placedPositions[pipe.to])
			task.wait(0.3)
		end
	end

	-- Connect wires
	if blueprint.wires then
		task.wait(1)
		addLog("Connecting wires...")
		for _, wire in ipairs(blueprint.wires) do
			tryConnectWire(placedPositions[wire.from], placedPositions[wire.to])
			task.wait(0.3)
		end
	end

	addLog("=== " .. blueprint.name .. " build complete! ===")
	currentFarmBuilding = false
end

-- ===================== AUTO SELL =====================
local function startAutoSell()
	if autoSellConnection then return end
	addLog("Auto-sell started")

	autoSellConnection = RunService.Heartbeat:Connect(function()
		if not autoSellEnabled then return end
		-- Find all truck/van depots in workspace and fire their sell action
		if sellRemote then
			pcall(function()
				sellRemote:FireServer()
			end)
		end
	end)
end

local function stopAutoSell()
	if autoSellConnection then
		autoSellConnection:Disconnect()
		autoSellConnection = nil
	end
	addLog("Auto-sell stopped")
end

-- ===================== POPULATE TABS =====================

-- === FARMS TAB ===
local farmsTab = tabFrames["Farms"]

createSectionLabel(farmsTab, "Farm Blueprints", 0)
createInfoLabel(farmsTab, "Stand where you want the farm origin, then click Build.", 1)
createInfoLabel(farmsTab, "Remotes auto-discovered. Check Remotes tab for status.", 2)

for i, bp in ipairs(FARM_BLUEPRINTS) do
	local order = i * 10 + 10

	-- Farm card frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -10, 0, 90)
	card.BackgroundColor3 = COLORS.bgSecondary
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = farmsTab

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 6)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = COLORS.border
	cardStroke.Thickness = 1
	cardStroke.Parent = card

	-- Tier badge
	local tierBadge = Instance.new("TextLabel")
	tierBadge.Size = UDim2.new(0, 70, 0, 18)
	tierBadge.Position = UDim2.new(0, 8, 0, 6)
	tierBadge.BackgroundColor3 = COLORS.accent
	tierBadge.Text = bp.tier
	tierBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	tierBadge.TextSize = 10
	tierBadge.Font = Enum.Font.GothamBold
	tierBadge.Parent = card

	local tierCorner = Instance.new("UICorner")
	tierCorner.CornerRadius = UDim.new(0, 4)
	tierCorner.Parent = tierBadge

	-- Farm name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -100, 0, 22)
	nameLabel.Position = UDim2.new(0, 84, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = bp.name
	nameLabel.TextColor3 = COLORS.text
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -16, 0, 28)
	descLabel.Position = UDim2.new(0, 8, 0, 28)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = bp.description
	descLabel.TextColor3 = COLORS.textDim
	descLabel.TextSize = 11
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = card

	-- Machine count
	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(0, 100, 0, 16)
	countLabel.Position = UDim2.new(0, 8, 1, -22)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = #bp.machines .. " machines"
	countLabel.TextColor3 = COLORS.textDim
	countLabel.TextSize = 10
	countLabel.Font = Enum.Font.Gotham
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.Parent = card

	-- Build button
	local buildBtn = Instance.new("TextButton")
	buildBtn.Size = UDim2.new(0, 80, 0, 26)
	buildBtn.Position = UDim2.new(1, -90, 1, -32)
	buildBtn.BackgroundColor3 = COLORS.accent
	buildBtn.Text = "BUILD"
	buildBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buildBtn.TextSize = 12
	buildBtn.Font = Enum.Font.GothamBold
	buildBtn.BorderSizePixel = 0
	buildBtn.Parent = card

	local buildCorner = Instance.new("UICorner")
	buildCorner.CornerRadius = UDim.new(0, 4)
	buildCorner.Parent = buildBtn

	buildBtn.MouseButton1Click:Connect(function()
		buildBtn.Text = "BUILDING..."
		buildBtn.BackgroundColor3 = COLORS.textDim
		task.spawn(function()
			buildFarm(bp)
			buildBtn.Text = "BUILD"
			buildBtn.BackgroundColor3 = COLORS.accent
		end)
	end)
end

-- Custom farm section
createSectionLabel(farmsTab, "Custom Placement", 200)

local customNameBox = Instance.new("TextBox")
customNameBox.Size = UDim2.new(1, -10, 0, 30)
customNameBox.BackgroundColor3 = COLORS.tabBg
customNameBox.Text = ""
customNameBox.PlaceholderText = "Machine name (e.g. Coal Drill)"
customNameBox.TextColor3 = COLORS.text
customNameBox.PlaceholderColor3 = COLORS.textDim
customNameBox.TextSize = 13
customNameBox.Font = Enum.Font.Gotham
customNameBox.BorderSizePixel = 0
customNameBox.ClearTextOnFocus = false
customNameBox.LayoutOrder = 201
customNameBox.Parent = farmsTab

local customCorner = Instance.new("UICorner")
customCorner.CornerRadius = UDim.new(0, 6)
customCorner.Parent = customNameBox

createActionButton(farmsTab, "Place Single Machine at Position", 202, function()
	local name = customNameBox.Text
	if name == "" then
		addLog("Enter a machine name first!")
		return
	end
	local pos = getPlayerPosition()
	tryPlaceMachine(name, pos)
end)

local customCountBox = Instance.new("TextBox")
customCountBox.Size = UDim2.new(1, -10, 0, 30)
customCountBox.BackgroundColor3 = COLORS.tabBg
customCountBox.Text = ""
customCountBox.PlaceholderText = "Row count (e.g. 5)"
customCountBox.TextColor3 = COLORS.text
customCountBox.PlaceholderColor3 = COLORS.textDim
customCountBox.TextSize = 13
customCountBox.Font = Enum.Font.Gotham
customCountBox.BorderSizePixel = 0
customCountBox.ClearTextOnFocus = false
customCountBox.LayoutOrder = 203
customCountBox.Parent = farmsTab

local customCountCorner = Instance.new("UICorner")
customCountCorner.CornerRadius = UDim.new(0, 6)
customCountCorner.Parent = customCountBox

createActionButton(farmsTab, "Place Row of Machines (8 stud spacing)", 204, function()
	local name = customNameBox.Text
	local count = tonumber(customCountBox.Text) or 3
	if name == "" then
		addLog("Enter a machine name first!")
		return
	end
	if count > 50 then count = 50 end
	local origin = getPlayerPosition()
	task.spawn(function()
		currentFarmBuilding = true
		for i = 0, count - 1 do
			tryPlaceMachine(name, origin + Vector3.new(i * 8, 0, 0))
			task.wait(0.5)
		end
		addLog("Placed row of " .. count .. " " .. name)
		currentFarmBuilding = false
	end)
end)

local customSpacingBox = Instance.new("TextBox")
customSpacingBox.Size = UDim2.new(1, -10, 0, 30)
customSpacingBox.BackgroundColor3 = COLORS.tabBg
customSpacingBox.Text = ""
customSpacingBox.PlaceholderText = "Grid size (e.g. 3x3)"
customSpacingBox.TextColor3 = COLORS.text
customSpacingBox.PlaceholderColor3 = COLORS.textDim
customSpacingBox.TextSize = 13
customSpacingBox.Font = Enum.Font.Gotham
customSpacingBox.BorderSizePixel = 0
customSpacingBox.ClearTextOnFocus = false
customSpacingBox.LayoutOrder = 205
customSpacingBox.Parent = farmsTab

local customSpacingCorner = Instance.new("UICorner")
customSpacingCorner.CornerRadius = UDim.new(0, 6)
customSpacingCorner.Parent = customSpacingBox

createActionButton(farmsTab, "Place Grid of Machines (8 stud spacing)", 206, function()
	local name = customNameBox.Text
	local gridText = customSpacingBox.Text
	if name == "" then
		addLog("Enter a machine name first!")
		return
	end
	local cols, rows = 3, 3
	if gridText:find("x") then
		local c, r = gridText:match("(%d+)x(%d+)")
		cols = tonumber(c) or 3
		rows = tonumber(r) or 3
	end
	if cols > 10 then cols = 10 end
	if rows > 10 then rows = 10 end

	local origin = getPlayerPosition()
	task.spawn(function()
		currentFarmBuilding = true
		for row = 0, rows - 1 do
			for col = 0, cols - 1 do
				tryPlaceMachine(name, origin + Vector3.new(col * 8, 0, row * 8))
				task.wait(0.5)
			end
		end
		addLog("Placed " .. cols .. "x" .. rows .. " grid of " .. name)
		currentFarmBuilding = false
	end)
end)

-- === AUTO TAB ===
local autoTab = tabFrames["Auto"]

createSectionLabel(autoTab, "Automation", 0)

createToggle(autoTab, "Auto Sell (fire sell remotes)", false, 1, function(on)
	autoSellEnabled = on
	if on then startAutoSell() else stopAutoSell() end
end)

createSectionLabel(autoTab, "Resource Monitor", 10)

local monitorLabel = createInfoLabel(autoTab, "Scanning workspace for resources...", 11)

createActionButton(autoTab, "Scan Resources in Workspace", 12, function()
	addLog("Scanning workspace for resource nodes...")
	local counts = {}
	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") then
				local name = obj.Name:lower()
				for _, res in ipairs({"coal", "iron", "copper", "gold", "oil", "lithium", "tungsten", "uranium"}) do
					if name:find(res) then
						counts[res] = (counts[res] or 0) + 1
					end
				end
			end
		end
	end)
	local parts = {}
	for res, count in pairs(counts) do
		table.insert(parts, res .. ": " .. count)
	end
	local result = #parts > 0 and table.concat(parts, ", ") or "No resource nodes found"
	monitorLabel.Text = "  " .. result
	addLog("Resources: " .. result)
end)

createSectionLabel(autoTab, "Player Machines", 20)

createActionButton(autoTab, "List My Placed Machines", 21, function()
	addLog("Scanning for your machines...")
	local myMachines = {}
	pcall(function()
		-- Look for machines owned by the player in workspace
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") then
				-- Check common ownership patterns
				local owner = obj:FindFirstChild("Owner") or obj:FindFirstChild("PlayerName") or obj:GetAttribute("Owner")
				if owner then
					local ownerName = ""
					if typeof(owner) == "Instance" and owner:IsA("StringValue") then
						ownerName = owner.Value
					elseif type(owner) == "string" then
						ownerName = owner
					end
					if ownerName == LocalPlayer.Name or ownerName == tostring(LocalPlayer.UserId) then
						myMachines[obj.Name] = (myMachines[obj.Name] or 0) + 1
					end
				end
			end
		end
	end)
	if next(myMachines) then
		for name, count in pairs(myMachines) do
			addLog("  " .. name .. " x" .. count)
		end
	else
		addLog("  No owned machines found (may use different ownership system)")
	end
end)

createSectionLabel(autoTab, "Teleport", 30)

createActionButton(autoTab, "TP to Nearest Truck Depot", 31, function()
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local nearest = nil
	local nearestDist = math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and (obj.Name:lower():find("truck") or obj.Name:lower():find("depot")) then
			local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if primary then
				local dist = (primary.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearest = primary
					nearestDist = dist
				end
			end
		end
	end

	if nearest then
		root.CFrame = nearest.CFrame + Vector3.new(0, 5, 0)
		addLog("Teleported to depot (" .. math.floor(nearestDist) .. " studs)")
	else
		addLog("No truck depot found in workspace")
	end
end)

createActionButton(autoTab, "TP to Nearest Drill", 32, function()
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local nearest = nil
	local nearestDist = math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name:lower():find("drill") then
			local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if primary then
				local dist = (primary.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearest = primary
					nearestDist = dist
				end
			end
		end
	end

	if nearest then
		root.CFrame = nearest.CFrame + Vector3.new(0, 5, 0)
		addLog("Teleported to drill (" .. math.floor(nearestDist) .. " studs)")
	else
		addLog("No drill found in workspace")
	end
end)

-- === REMOTES TAB ===
local remotesTab = tabFrames["Remotes"]

createSectionLabel(remotesTab, "Remote Discovery", 0)
createInfoLabel(remotesTab, "Scans the game for remote events/functions used by the building system.", 1)

local remoteStatusLabel = createInfoLabel(remotesTab, "Not scanned yet. Click Scan below.", 2)

local remoteListFrame = Instance.new("Frame")
remoteListFrame.Size = UDim2.new(1, -10, 0, 0)
remoteListFrame.BackgroundTransparency = 1
remoteListFrame.LayoutOrder = 100
remoteListFrame.Parent = remotesTab

local remoteListLayout = Instance.new("UIListLayout")
remoteListLayout.SortOrder = Enum.SortOrder.LayoutOrder
remoteListLayout.Padding = UDim.new(0, 2)
remoteListLayout.Parent = remoteListFrame

remoteListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	remoteListFrame.Size = UDim2.new(1, -10, 0, remoteListLayout.AbsoluteContentSize.Y)
end)

local function refreshRemoteList()
	for _, child in ipairs(remoteListFrame:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then child:Destroy() end
	end

	local order = 0
	for name, data in pairs(discoveredRemotes) do
		order = order + 1
		local entry = Instance.new("TextButton")
		entry.Size = UDim2.new(1, 0, 0, 22)
		entry.BackgroundColor3 = COLORS.tabBg
		entry.BackgroundTransparency = 0.5
		entry.BorderSizePixel = 0
		entry.LayoutOrder = order
		entry.Parent = remoteListFrame

		local isKey = (data.instance == placeRemote) or (data.instance == pipeRemote) or
		              (data.instance == wireRemote) or (data.instance == sellRemote)
		local prefix = isKey and "[KEY] " or ""
		local typeStr = data.instance:IsA("RemoteEvent") and "RE" or "RF"

		entry.Text = "  " .. prefix .. typeStr .. " | " .. name
		entry.TextColor3 = isKey and COLORS.accent or COLORS.textDim
		entry.TextSize = 11
		entry.Font = Enum.Font.RobotoMono
		entry.TextXAlignment = Enum.TextXAlignment.Left
		entry.TextTruncate = Enum.TextTruncate.AtEnd

		entry.MouseButton1Click:Connect(function()
			addLog("Remote: " .. data.path .. " (" .. data.type .. ")")
		end)
	end

	local count = 0
	for _ in pairs(discoveredRemotes) do count = count + 1 end

	local keyStatus = {}
	if placeRemote then table.insert(keyStatus, "Place: " .. placeRemote.Name) end
	if pipeRemote then table.insert(keyStatus, "Pipe: " .. pipeRemote.Name) end
	if wireRemote then table.insert(keyStatus, "Wire: " .. wireRemote.Name) end
	if sellRemote then table.insert(keyStatus, "Sell: " .. sellRemote.Name) end

	local statusText = count .. " remotes found."
	if #keyStatus > 0 then
		statusText = statusText .. " Key: " .. table.concat(keyStatus, ", ")
	else
		statusText = statusText .. " No key remotes auto-detected."
	end
	remoteStatusLabel.Text = "  " .. statusText
	addLog(statusText)
end

createActionButton(remotesTab, "Scan Remotes", 3, function()
	addLog("Scanning for remotes...")
	discoverRemotes()
	refreshRemoteList()
end)

createActionButton(remotesTab, "Force Set Place Remote (click next remote you fire)", 4, function()
	addLog("Listening for next remote fire... Use the hammer tool to place something.")
	-- Hook remotes to detect which one fires
	local hookConns = {}
	for name, data in pairs(discoveredRemotes) do
		if data.instance:IsA("RemoteEvent") then
			local conn
			conn = data.instance.OnClientEvent:Connect(function(...)
				placeRemote = data.instance
				addLog("Place remote set to: " .. data.instance:GetFullName())
				refreshRemoteList()
				for _, c in ipairs(hookConns) do c:Disconnect() end
			end)
			table.insert(hookConns, conn)
		end
	end
	-- Auto-cleanup after 15 seconds
	task.delay(15, function()
		for _, c in ipairs(hookConns) do c:Disconnect() end
	end)
end)

createSectionLabel(remotesTab, "Manual Remote Override", 50)
createInfoLabel(remotesTab, "If auto-detect fails, type the exact remote path:", 51)

local remoteOverrideBox = Instance.new("TextBox")
remoteOverrideBox.Size = UDim2.new(1, -10, 0, 30)
remoteOverrideBox.BackgroundColor3 = COLORS.tabBg
remoteOverrideBox.Text = ""
remoteOverrideBox.PlaceholderText = "e.g. ReplicatedStorage.Events.PlaceBuilding"
remoteOverrideBox.TextColor3 = COLORS.text
remoteOverrideBox.PlaceholderColor3 = COLORS.textDim
remoteOverrideBox.TextSize = 12
remoteOverrideBox.Font = Enum.Font.RobotoMono
remoteOverrideBox.BorderSizePixel = 0
remoteOverrideBox.ClearTextOnFocus = false
remoteOverrideBox.LayoutOrder = 52
remoteOverrideBox.Parent = remotesTab

local overrideCorner = Instance.new("UICorner")
overrideCorner.CornerRadius = UDim.new(0, 6)
overrideCorner.Parent = remoteOverrideBox

createActionButton(remotesTab, "Set as Place Remote", 53, function()
	local path = remoteOverrideBox.Text
	if path == "" then
		addLog("Enter a remote path first!")
		return
	end
	-- Parse path like "ReplicatedStorage.Events.PlaceBuilding"
	local parts = {}
	for part in path:gmatch("[^%.]+") do
		table.insert(parts, part)
	end
	local obj = game
	for _, part in ipairs(parts) do
		obj = obj:FindFirstChild(part)
		if not obj then
			addLog("Could not find: " .. path .. " (failed at '" .. part .. "')")
			return
		end
	end
	if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
		placeRemote = obj
		addLog("Place remote manually set to: " .. obj:GetFullName())
		refreshRemoteList()
	else
		addLog("Found object but it's a " .. obj.ClassName .. ", not a Remote")
	end
end)

-- === LOG TAB ===
logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -10, 1, -76)
logFrame.Position = UDim2.new(0, 5, 0, 66)
logFrame.BackgroundColor3 = COLORS.bgSecondary
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 4
logFrame.ScrollBarImageColor3 = COLORS.accent
logFrame.Visible = false
logFrame.Parent = mainFrame

-- Replace the auto-generated log tab frame
tabFrames["Log"]:Destroy()
tabFrames["Log"] = logFrame

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 6)
logCorner.Parent = logFrame

-- ===================== TOGGLE BUTTON =====================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 40, 0, 40)
toggleBtn.Position = UDim2.new(0, 10, 0.5, -20)
toggleBtn.BackgroundColor3 = COLORS.accent
toggleBtn.Text = "PB"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 12
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.BorderSizePixel = 0
toggleBtn.Visible = false
toggleBtn.ZIndex = 10
toggleBtn.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleBtn

-- ===================== CLOSE / MINIMIZE =====================
closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	toggleBtn.Visible = true
	guiOpen = false
end)

minBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	toggleBtn.Visible = true
	guiOpen = false
end)

toggleBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = true
	toggleBtn.Visible = false
	guiOpen = true
end)

-- Toggle with Insert key
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Insert then
		guiOpen = not guiOpen
		mainFrame.Visible = guiOpen
		toggleBtn.Visible = not guiOpen
	end
end)

-- ===================== STARTUP =====================
addLog("Pebbleford Hub - Industrialist v1.0 loaded")
addLog("Discovering remotes...")
discoverRemotes()
refreshRemoteList()
addLog("Ready! Select a farm blueprint or use custom placement.")
addLog("Press Insert to toggle GUI.")
