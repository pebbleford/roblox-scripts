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
if not keySystem or not keySystem.validate("99nights") then return end

-- ================================================================
-- 99 Nights in the Forest - Script Hub v1.0
-- Auto Farm | Bring Items | Kill Aura | ESP | Fly | Infinite Saplings
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===================== CLICK SIMULATION =====================
local function mouse1click()
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	task.wait(0.05)
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- ===================== COLOR PALETTE =====================
local COLORS = {
	bg = Color3.fromRGB(15, 18, 15),
	bgSecondary = Color3.fromRGB(22, 28, 22),
	panel = Color3.fromRGB(35, 42, 35),
	accent = Color3.fromRGB(80, 200, 80),
	accentHover = Color3.fromRGB(100, 230, 100),
	textPrimary = Color3.fromRGB(240, 255, 240),
	textSecondary = Color3.fromRGB(150, 180, 150),
	textDim = Color3.fromRGB(100, 130, 100),
	border = Color3.fromRGB(45, 60, 45),
	toggleOn = Color3.fromRGB(80, 200, 80),
	toggleOff = Color3.fromRGB(70, 70, 70),
	error = Color3.fromRGB(255, 80, 80),
	success = Color3.fromRGB(80, 255, 80),
	warning = Color3.fromRGB(255, 200, 60),
}

-- ===================== ITEM CATEGORIES =====================
-- Based on game research: workspace descendants with these names are lootable items/entities
local RESOURCE_ITEMS = {
	"Log", "Coal", "Sapling", "Oil Barrel", "Fuel Canister",
	"Sheet Metal", "Bolt", "Old Car Engine", "Broken Fan",
	"Broken Microwave", "Washing Machine", "Tyre", "Old Radio",
	"Chair Set", "Giant Sack"
}

local FOOD_ITEMS = {
	"Apple", "Berry", "Carrot", "Chilli", "Steak", "Morsel",
	"Meat? Sandwich", "Cake", "Bunny Foot"
}

local WEAPON_ITEMS = {
	"Spear", "Revolver", "Rifle", "Raygun", "Laser Sword",
	"Riot Shield", "Crossbow", "Good Axe"
}

local AMMO_ITEMS = {
	"Revolver Ammo", "Rifle Ammo"
}

local HEALING_ITEMS = {
	"Bandage", "Medkit"
}

local SPECIAL_ITEMS = {
	"Cultist Gem", "Gem of the Forest", "Coin Stack",
	"Laser Fence Blueprint", "UFO Component", "UFO Junk",
	"Seed Box", "Old Flashlight", "Iron Body", "Leather Body",
	"Wolf Pelt", "Alpha Wolf Pelt"
}

local CHEST_ITEMS = {
	"Chest", "Item Chest", "Item Chest2", "Item Chest3",
	"Item Chest4", "Item Chest6", "Alien Chest",
	"Stronghold Diamond Chest"
}

local ENEMY_NAMES = {
	"Deer", "Wolf", "Alpha Wolf", "Bear", "Cultist",
	"Crossbow Cultist", "Alien", "Bunny", "Scorpion",
	"Polar Bear", "Mammoth", "Arctic Fox"
}

local NPC_NAMES = {
	"Lost Child", "Lost Child2", "Lost Child3", "Lost Child4"
}

-- All teleportable items combined
local ALL_ITEMS = {}
for _, list in ipairs({RESOURCE_ITEMS, FOOD_ITEMS, WEAPON_ITEMS, AMMO_ITEMS, HEALING_ITEMS, SPECIAL_ITEMS, CHEST_ITEMS, NPC_NAMES}) do
	for _, name in ipairs(list) do
		table.insert(ALL_ITEMS, name)
	end
end

-- ===================== ARMOR ITEMS =====================
local ARMOR_ITEMS = {
	"Iron Body", "Leather Body", "Wolf Pelt", "Alpha Wolf Pelt",
	"Riot Shield"
}

local FUEL_ITEMS = {
	"Log", "Coal", "Fuel Canister", "Oil Barrel"
}

local FLOWER_ITEMS = {
	"Flower", "Golden Flower"
}

-- ===================== STATE =====================
local autoTreeFarmActive = false
local killAuraActive = false
local autoPickupActive = false
local espActive = false
local entityEspActive = false
local flyActive = false
local noclipActive = false
local infJumpActive = false
local speedBoostActive = false
local autoFuelActive = false
local saplingFarmActive = false
local fullbrightActive = false
local autoPlantActive = false
local autoChestActive = false
local autoCookActive = false
local autoHealActive = false
local autoFeedActive = false
local godModeActive = false
local antiAfkActive = false
local hitboxExpandActive = false
local freezeEntitiesActive = false
local autoSeedBoxActive = false

local flySpeed = 60
local speedValue = 50
local killAuraRange = 15
local killAuraSpeed = 0.15
local hitboxSize = 10
local chopAuraRange = 50
local autoPickupRange = 50
local autoChestRange = 50
local saplingFarmRange = 50
local windowVisible = true
local activeTab = "Farm"

-- Connections
local flyConnection = nil
local flyBV = nil
local flyBG = nil
local noclipConnection = nil
local speedBV = nil
local speedConnection = nil
local godModeConnection = nil
local hitboxConnection = nil
local espHighlights = {}
local entityEspDrawings = {}
local badTrees = {} -- trees that timed out during farming

-- ===================== HELPERS =====================
local function getRoot()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function notify(title, msg)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = msg, Duration = 3})
	end)
end

local function getItemPosition(obj)
	if obj:IsA("Model") then
		local ok, cf = pcall(function() return obj:GetPivot() end)
		if ok and cf then return cf.Position end
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then return part.Position end
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return nil
end

local function getItemCFrame(obj)
	if obj:IsA("Model") then
		local ok, cf = pcall(function() return obj:GetPivot() end)
		if ok and cf then return cf end
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then return part.CFrame end
	elseif obj:IsA("BasePart") then
		return obj.CFrame
	end
	return nil
end

-- Fire all ProximityPrompts on an object (and descendants)
local function fireAllPrompts(obj)
	pcall(function()
		if obj:IsA("ProximityPrompt") then
			local oldHold = obj.HoldDuration
			local oldDist = obj.MaxActivationDistance
			obj.HoldDuration = 0
			obj.MaxActivationDistance = 9999
			pcall(function() if fireproximityprompt then fireproximityprompt(obj) end end)
			pcall(function() obj:InputHoldBegin() task.wait(0.05) obj:InputHoldEnd() end)
			obj.HoldDuration = oldHold
			obj.MaxActivationDistance = oldDist
			return
		end
	end)
	for _, child in ipairs(obj:GetDescendants()) do
		pcall(function()
			if child:IsA("ProximityPrompt") then
				local oldHold = child.HoldDuration
				local oldDist = child.MaxActivationDistance
				child.HoldDuration = 0
				child.MaxActivationDistance = 9999
				pcall(function() if fireproximityprompt then fireproximityprompt(child) end end)
				pcall(function() child:InputHoldBegin() task.wait(0.05) child:InputHoldEnd() end)
				child.HoldDuration = oldHold
				child.MaxActivationDistance = oldDist
			end
		end)
	end
end

-- Fire all ClickDetectors on an object
local function fireAllClicks(obj)
	for _, child in ipairs(obj:GetDescendants()) do
		pcall(function()
			if child:IsA("ClickDetector") then
				pcall(function() if fireclickdetector then fireclickdetector(child) end end)
			end
		end)
	end
end

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NightsHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local function addCorner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = inst
	return c
end

-- ===================== MOBILE / RESIZE DETECTION =====================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local ORIG_W = 500
local ORIG_H = 420
local windowW = ORIG_W
local windowH = ORIG_H
if isMobile then
	windowW = math.min(math.floor(screenSize.X * 0.92), ORIG_W)
	windowH = math.min(math.floor(screenSize.Y * 0.7), ORIG_H)
	if windowW < 320 then windowW = 320 end
	if windowH < 280 then windowH = 280 end
end

-- ===================== GUI SETUP (Terminal, hand-built) =====================
-- Terminal green-on-black hand-built UI. Feature call sites are untouched: the
-- builder functions keep their signatures and now produce terminal-styled
-- frames instead of Fluent elements. Light (no library), so no menu lag.
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

local _uiOrd = 0
local function _nextOrd() _uiOrd = _uiOrd + 1 return _uiOrd end

local tabNames = {"Farm", "Combat", "Movement", "Visuals", "Teleport"}
local tabFrames = {}
uiState = uiState or {activeTab = tabNames[1]}

local _TUIS = UserInputService
local _mobile = _TUIS.TouchEnabled and not _TUIS.KeyboardEnabled
local _W = _mobile and 440 or 560
local _H = _mobile and 380 or 440

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
titleLabel.Text = "99 NIGHTS HUB"
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

-- Drag (mouse + touch)
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

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 34)
tabBar.Position = UDim2.new(0, 0, 0, 42)
tabBar.BackgroundColor3 = COLORS.bgSecondary
tabBar.BorderSizePixel = 0
tabBar.Parent = mainWindow
do local dv = Instance.new("Frame") dv.Size = UDim2.new(1,0,0,1) dv.Position = UDim2.new(0,0,1,-1) dv.BackgroundColor3 = COLORS.border dv.BorderSizePixel = 0 dv.ZIndex = 2 dv.Parent = tabBar end

local tabButtons = {}
local _tabN = #tabNames
for i, tabName in ipairs(tabNames) do
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -8, 1, -84)
	content.Position = UDim2.new(0, 4, 0, 80)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = COLORS.accent
	content.CanvasSize = UDim2.new(0,0,0,0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Visible = (i == 1)
	content.Parent = mainWindow
	local lay = Instance.new("UIListLayout") lay.SortOrder = Enum.SortOrder.LayoutOrder lay.Padding = UDim.new(0,4) lay.Parent = content
	local pd = Instance.new("UIPadding") pd.PaddingLeft = UDim.new(0,4) pd.PaddingRight = UDim.new(0,4) pd.PaddingTop = UDim.new(0,4) pd.Parent = content
	tabFrames[tabName] = content

	local b = Instance.new("TextButton")
	b.Position = UDim2.new((i-1)/_tabN, 0, 0, 0)
	b.Size = UDim2.new(1/_tabN, 0, 1, -1)
	b.BackgroundColor3 = COLORS.accentDark
	b.BackgroundTransparency = (i == 1) and 0 or 1
	b.Text = string.upper(tabName)
	b.TextColor3 = (i == 1) and COLORS.accent or COLORS.textSecondary
	b.Font = Enum.Font.Code
	b.TextSize = 10
	b.AutoButtonColor = false
	b.ZIndex = 3
	b.Parent = tabBar
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

-- Minimise / close + mobile reopen button
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
local function createSectionLabel(parent, text, order)
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

local function createInfoLabel(parent, text, order)
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
	local l = createInfoLabel(parent, text or "", 0)
	l.TextColor3 = COLORS.textSecondary
	return setmetatable({}, {
		__newindex = function(_, k, v)
			if k == "Text" then pcall(function() l.Text = tostring(v) end)
			elseif k == "TextColor3" then pcall(function() l.TextColor3 = v end) end
		end,
		__index = function() return nil end,
	})
end

local function createToggle(parent, text, order, callback)
	if not parent then return end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
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
	lbl.TextSize = 13
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

local function createActionButton(parent, text, order, callback)
	if not parent then return end
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 32)
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
local createButton = createActionButton

local function createSlider(parent, text, min, max, default, order, callback)
	if not parent then return end
	local c = Instance.new("Frame")
	c.Size = UDim2.new(1, 0, 0, 46)
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
	local cur = default
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
				cur = opt
				b.Text = tostring(text) .. ": " .. tostring(opt)
				list.Visible = false
				if callback then pcall(callback, opt) end
			end)
		end
	end
	rebuild(options or {})
	b.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
	function wrap:Refresh(opts) rebuild(opts) end
	function wrap:SetValues(opts) rebuild(opts) end
	return wrap
end

local function createInput(parent, text, placeholder, callback)
	if not parent then return end
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 32)
	box.BackgroundColor3 = COLORS.tabBg
	box.Text = ""
	box.PlaceholderText = placeholder or tostring(text)
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

local function createSpacer(parent, order)
	if not parent then return end
	local s = Instance.new("Frame")
	s.Size = UDim2.new(1, 0, 0, 4)
	s.BackgroundTransparency = 1
	s.LayoutOrder = _nextOrd()
	s.Parent = parent
end


-- ===================== CHOP AURA (Voidware-style) =====================
-- Stays in place - rapidly cycles through nearby trees:
-- Save position -> TP to tree -> swing -> TP back -> next tree
-- Also fires ProximityPrompts on trees if they have them

local function startAutoTreeFarm()
	autoTreeFarmActive = true
	task.spawn(function()
		while autoTreeFarmActive do
			pcall(function()
				local char = LocalPlayer.Character
				local hrp = getRoot()
				if not char or not hrp then return end

				local savedCF = hrp.CFrame

				-- Find trees within chop aura range, sorted by distance
				local trees = {}
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj.Name == "Trunk" and obj:IsA("BasePart") and obj.Parent then
						local treeName = obj.Parent.Name
						if treeName == "Small Tree" or treeName == "Big Tree" or treeName == "Tree" then
							if not badTrees[obj:GetFullName()] then
								local dist = (obj.Position - savedCF.Position).Magnitude
								if dist <= chopAuraRange then
									table.insert(trees, {trunk = obj, dist = dist})
								end
							end
						end
					end
				end

				table.sort(trees, function(a, b) return a.dist < b.dist end)

				for _, data in ipairs(trees) do
					if not autoTreeFarmActive then break end
					local trunk = data.trunk
					if trunk and trunk.Parent then

					-- Try firing ProximityPrompts on the tree first (no TP needed)
					fireAllPrompts(trunk.Parent)
					fireAllClicks(trunk.Parent)

					-- Rapid TP-swing-return: briefly go to tree, click, come back
					local swings = 0
					local maxSwings = 15 -- enough for any axe type
					while autoTreeFarmActive and trunk and trunk.Parent and swings < maxSwings do
						-- TP to tree
						char:PivotTo(trunk.CFrame + Vector3.new(0, 3, 0))
						task.wait(0.05)
						mouse1click()
						task.wait(0.05)
						-- TP back to saved position
						char:PivotTo(savedCF)
						swings = swings + 1
						task.wait(0.05)

						-- Check if tree is gone
						if not trunk.Parent or trunk.Parent.Parent == nil then break end
					end

					if swings >= maxSwings and trunk and trunk.Parent then
						badTrees[trunk:GetFullName()] = true
					end
					end
				end
			end)
			task.wait(0.5)
		end
	end)
	notify("Chop Aura", "Chopping trees in " .. chopAuraRange .. " stud radius!")
end

local function stopAutoTreeFarm()
	autoTreeFarmActive = false
	notify("Chop Aura", "Stopped")
end

-- ===================== INFINITE SAPLINGS / AUTO PLANT =====================
-- Plants saplings by finding Sapling items and placing them near your base
-- Technique: move saplings to player position (client-side), then interact
-- Also: continuous sapling finder that grabs all saplings in workspace

local function startSaplingFarm()
	saplingFarmActive = true
	task.spawn(function()
		while saplingFarmActive do
			pcall(function()
				local hrp = getRoot()
				local char = LocalPlayer.Character
				if not hrp or not char then return end

				local savedCF = hrp.CFrame
				local count = 0

				for _, obj in ipairs(workspace:GetDescendants()) do
					if not saplingFarmActive then break end
					if obj.Name == "Sapling" then
						local cf = getItemCFrame(obj)
						if not cf and obj:IsA("BasePart") then cf = obj.CFrame end
						if cf and (cf.Position - savedCF.Position).Magnitude <= saplingFarmRange then
							-- Try fireproximityprompt from distance first
							fireAllPrompts(obj)
							fireAllClicks(obj)
							-- Rapid TP-click-return
							char:PivotTo(cf + Vector3.new(0, 2, 0))
							task.wait(0.05)
							mouse1click()
							task.wait(0.05)
							mouse1click()
							char:PivotTo(savedCF)
							task.wait(0.05)
							count = count + 1
						end
					end
				end

				if count > 0 then
					notify("Saplings", "Collected " .. count .. " sapling(s)")
				end
			end)
			task.wait(2)
		end
	end)
	notify("Sapling Farm", "Auto collecting saplings!")
end

local function stopSaplingFarm()
	saplingFarmActive = false
end

-- ===================== AUTO PLANT SAPLINGS =====================
-- Plants saplings in a circle around your position
-- Simulates placing saplings via click at offset positions

local function plantSaplingsInCircle()
	local hrp = getRoot()
	local char = LocalPlayer.Character
	if not hrp or not char then notify("Error", "No character") return end

	local basePos = hrp.Position
	local radius = 8
	local count = 8

	notify("Planting", "Planting saplings in circle...")

	for i = 1, count do
		if not char or not char.Parent then break end
		local angle = (i / count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local targetPos = basePos + offset

		char:PivotTo(CFrame.new(targetPos + Vector3.new(0, 2, 0)))
		task.wait(0.2)
		mouse1click()
		task.wait(0.3)
		mouse1click()
		task.wait(0.2)
	end

	-- Return to base
	char:PivotTo(CFrame.new(basePos + Vector3.new(0, 2, 0)))
	notify("Planted", "Saplings placed in circle!")
end

-- ===================== BRING ITEMS =====================
-- Moves items to player position (client-side CFrame manipulation)
-- Works by finding items in workspace and setting their CFrame to near the player

local function bringItemsByName(itemNames)
	local hrp = getRoot()
	if not hrp then notify("Error", "No character") return end

	local count = 0
	local targetPos = hrp.Position + Vector3.new(0, 2, 0)

	for _, obj in ipairs(workspace:GetDescendants()) do
		if table.find(itemNames, obj.Name) then
			pcall(function()
				local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
				if obj:IsA("Model") then
					obj:PivotTo(CFrame.new(targetPos + offset))
					count = count + 1
				elseif obj:IsA("BasePart") and not obj.Anchored then
					obj.CFrame = CFrame.new(targetPos + offset)
					count = count + 1
				end
				-- Fire ProximityPrompts to actually collect the item
				fireAllPrompts(obj)
				fireAllClicks(obj)
			end)
			task.wait(0.05) -- small delay to avoid lag
		end
	end

	-- Also click at player position to pick up anything that landed nearby
	if count > 0 then
		task.wait(0.2)
		mouse1click()
	end

	notify("Bring", "Brought " .. count .. " item(s)")
end

-- ===================== AUTO FUEL CAMPFIRE =====================
-- Finds fuel items (logs, coal, fuel canisters, oil barrels) and brings them to campfire
-- Campfire is approximately at origin

local function startAutoFuel()
	autoFuelActive = true
	task.spawn(function()
		while autoFuelActive do
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end

				-- Find fuel items
				local fuelNames = {"Log", "Coal", "Fuel Canister", "Oil Barrel"}
				for _, obj in ipairs(workspace:GetDescendants()) do
					if not autoFuelActive then break end
					if table.find(fuelNames, obj.Name) then
						local cf = getItemCFrame(obj)
						if cf then
							-- Teleport to item
							char:PivotTo(cf + Vector3.new(0, 2, 0))
							task.wait(0.2)
							mouse1click()
							task.wait(0.15)
							-- Teleport to campfire area
							char:PivotTo(CFrame.new(0, 10, 0))
							task.wait(0.3)
							mouse1click()
							task.wait(0.2)
						end
					end
				end
			end)
			task.wait(3)
		end
	end)
	notify("Auto Fuel", "Keeping campfire fed!")
end

local function stopAutoFuel()
	autoFuelActive = false
end

-- ===================== KILL AURA =====================
-- Finds enemies within range, teleports to them, clicks to attack
-- Cycles through nearby enemies continuously

local function startKillAura()
	killAuraActive = true
	task.spawn(function()
		while killAuraActive do
			pcall(function()
				local hrp = getRoot()
				local char = LocalPlayer.Character
				if not hrp or not char then return end

				for _, obj in ipairs(workspace:GetDescendants()) do
					if not killAuraActive then break end
					if table.find(ENEMY_NAMES, obj.Name) and obj:IsA("Model") then
						local enemyHRP = obj:FindFirstChild("HumanoidRootPart")
						local enemyHum = obj:FindFirstChildOfClass("Humanoid")
						if enemyHRP and enemyHum and enemyHum.Health > 0 then
							local dist = (enemyHRP.Position - hrp.Position).Magnitude
							if dist <= killAuraRange then
								-- Face and attack enemy
								char:PivotTo(CFrame.new(hrp.Position, enemyHRP.Position))
								mouse1click()
								task.wait(killAuraSpeed)
							end
						end
					end
				end
			end)
			task.wait(0.1)
		end
	end)
	notify("Kill Aura", "Auto attacking nearby enemies!")
end

local function stopKillAura()
	killAuraActive = false
	notify("Kill Aura", "Stopped")
end

-- ===================== AUTO PICKUP =====================
-- Clicks on nearby items to pick them up

local function startAutoPickup()
	autoPickupActive = true
	task.spawn(function()
		while autoPickupActive do
			pcall(function()
				local hrp = getRoot()
				local char = LocalPlayer.Character
				if not hrp or not char then return end

				local savedCF = hrp.CFrame

				for _, obj in ipairs(workspace:GetDescendants()) do
					if not autoPickupActive then break end
					if table.find(ALL_ITEMS, obj.Name) then
						local pos = getItemPosition(obj)
						if pos and (pos - savedCF.Position).Magnitude <= autoPickupRange then
							-- Try firing prompts from distance (no TP needed)
							fireAllPrompts(obj)
							fireAllClicks(obj)
							-- Fallback: rapid TP-click-return
							char:PivotTo(CFrame.new(pos + Vector3.new(0, 2, 0)))
							task.wait(0.05)
							mouse1click()
							char:PivotTo(savedCF)
							task.wait(0.05)
						end
					end
				end
			end)
			task.wait(1)
		end
	end)
	notify("Auto Pickup", "Collecting items in " .. autoPickupRange .. " stud radius!")
end

local function stopAutoPickup()
	autoPickupActive = false
end

-- ===================== FLY =====================
-- BodyVelocity + BodyGyro (camera-relative WASD flight)

local function startFly()
	local hrp = getRoot()
	local hum = getHumanoid()
	if not hrp or not hum then return end

	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyBV.Velocity = Vector3.new(0, 0, 0)
	flyBV.P = 9000
	flyBV.Parent = hrp

	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flyBG.P = 9000
	flyBG.CFrame = hrp.CFrame
	flyBG.Parent = hrp

	flyConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not flyBV or not flyBV.Parent then return end
			local moveVec = Vector3.zero
			local camCF = camera.CFrame
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + camCF.UpVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - camCF.UpVector end
			flyBV.Velocity = moveVec.Magnitude > 0 and moveVec.Unit * flySpeed or Vector3.zero
			flyBG.CFrame = camCF
		end)
	end)
end

local function stopFly()
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	if flyBV then pcall(function() flyBV:Destroy() end) flyBV = nil end
	if flyBG then pcall(function() flyBG:Destroy() end) flyBG = nil end
end

-- ===================== NOCLIP =====================
local function startNoclip()
	noclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
	end)
end

local function stopNoclip()
	if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
end

-- ===================== SPEED BOOST =====================
local function startSpeedBoost()
	local hrp = getRoot()
	if not hrp then return end

	speedBV = Instance.new("BodyVelocity")
	speedBV.MaxForce = Vector3.new(math.huge, 0, math.huge)
	speedBV.Velocity = Vector3.new(0, 0, 0)
	speedBV.P = 9000
	speedBV.Parent = hrp

	speedConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local rt = getRoot()
			local hum = getHumanoid()
			if not rt or not hum then return end
			if not speedBV or not speedBV.Parent then return end
			local moveDir = hum.MoveDirection
			if moveDir.Magnitude > 0 then
				speedBV.Velocity = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * speedValue
			else
				speedBV.Velocity = Vector3.new(0, 0, 0)
			end
		end)
	end)
end

local function stopSpeedBoost()
	if speedConnection then speedConnection:Disconnect() speedConnection = nil end
	if speedBV then pcall(function() speedBV:Destroy() end) speedBV = nil end
end

-- ===================== INFINITE JUMP =====================
local function startInfJump()
	infJumpActive = true
end

UserInputService.JumpRequest:Connect(function()
	if infJumpActive then
		pcall(function()
			local hum = getHumanoid()
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end
end)

-- ===================== ESP =====================
local function clearESP()
	for _, h in pairs(espHighlights) do pcall(function() h:Destroy() end) end
	espHighlights = {}
end

local function updateESP()
	clearESP()
	if not espActive then return end

	local hrp = getRoot()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if table.find(ALL_ITEMS, obj.Name) then
			pcall(function()
				local pos = getItemPosition(obj)
				if not pos then return end
				local dist = hrp and math.floor((pos - hrp.Position).Magnitude) or 0

				local adornee = obj:IsA("Model") and obj or obj
				if not obj:FindFirstChild("ESP_HL") then
					local hl = Instance.new("Highlight")
					hl.Name = "ESP_HL"
					hl.Adornee = adornee
					hl.FillColor = Color3.fromRGB(255, 165, 0)
					hl.FillTransparency = 0.4
					hl.OutlineColor = COLORS.accent
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = obj
					table.insert(espHighlights, hl)
				end

				local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
				if part and not obj:FindFirstChild("ESP_BB") then
					local bb = Instance.new("BillboardGui")
					bb.Name = "ESP_BB"
					bb.AlwaysOnTop = true
					bb.Size = UDim2.new(4, 0, 0.6, 0)
					bb.StudsOffset = Vector3.new(0, 3, 0)
					bb.Adornee = part
					bb.Parent = obj
					table.insert(espHighlights, bb)

					local lbl = Instance.new("TextLabel")
					lbl.Text = obj.Name .. " [" .. dist .. "m]"
					lbl.TextColor3 = COLORS.textPrimary
					lbl.TextStrokeTransparency = 0
					lbl.TextSize = 11
					lbl.Font = Enum.Font.GothamBold
					lbl.BackgroundTransparency = 1
					lbl.Size = UDim2.new(1, 0, 1, 0)
					lbl.Parent = bb
				end
			end)
		end
	end
end

local function startESP()
	task.spawn(function()
		while espActive do updateESP() task.wait(3) end
	end)
end

-- Entity ESP (enemies/NPCs)
local function clearEntityESP()
	for _, h in pairs(entityEspDrawings) do pcall(function() h:Destroy() end) end
	entityEspDrawings = {}
end

local function updateEntityESP()
	clearEntityESP()
	if not entityEspActive then return end

	local hrp = getRoot()
	local allEntities = {}
	for _, name in ipairs(ENEMY_NAMES) do table.insert(allEntities, name) end
	for _, name in ipairs(NPC_NAMES) do table.insert(allEntities, name) end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if table.find(allEntities, obj.Name) and obj:IsA("Model") then
			pcall(function()
				local entityHRP = obj:FindFirstChild("HumanoidRootPart")
				if not entityHRP then return end
				local dist = hrp and math.floor((entityHRP.Position - hrp.Position).Magnitude) or 0

				local isEnemy = table.find(ENEMY_NAMES, obj.Name)
				local color = isEnemy and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 150, 255)

				if not obj:FindFirstChild("ENT_HL") then
					local hl = Instance.new("Highlight")
					hl.Name = "ENT_HL"
					hl.Adornee = obj
					hl.FillColor = color
					hl.FillTransparency = 0.3
					hl.OutlineColor = Color3.new(1, 1, 1)
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = obj
					table.insert(entityEspDrawings, hl)
				end

				if not obj:FindFirstChild("ENT_BB") then
					local bb = Instance.new("BillboardGui")
					bb.Name = "ENT_BB"
					bb.AlwaysOnTop = true
					bb.Size = UDim2.new(4, 0, 0.6, 0)
					bb.StudsOffset = Vector3.new(0, 4, 0)
					bb.Adornee = entityHRP
					bb.Parent = obj
					table.insert(entityEspDrawings, bb)

					local lbl = Instance.new("TextLabel")
					lbl.Text = obj.Name .. " [" .. dist .. "m]"
					lbl.TextColor3 = color
					lbl.TextStrokeTransparency = 0
					lbl.TextSize = 12
					lbl.Font = Enum.Font.GothamBold
					lbl.BackgroundTransparency = 1
					lbl.Size = UDim2.new(1, 0, 1, 0)
					lbl.Parent = bb
				end
			end)
		end
	end
end

local function startEntityESP()
	task.spawn(function()
		while entityEspActive do updateEntityESP() task.wait(2) end
	end)
end

-- ===================== FULLBRIGHT + ANTI FOG =====================
local savedLighting = {}

local function enableFullbright()
	local Lighting = game:GetService("Lighting")
	savedLighting.Brightness = Lighting.Brightness
	savedLighting.ClockTime = Lighting.ClockTime
	savedLighting.FogEnd = Lighting.FogEnd
	savedLighting.GlobalShadows = Lighting.GlobalShadows
	savedLighting.OutdoorAmbient = Lighting.OutdoorAmbient

	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = false
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end

local function disableFullbright()
	local Lighting = game:GetService("Lighting")
	if savedLighting.Brightness then Lighting.Brightness = savedLighting.Brightness end
	if savedLighting.ClockTime then Lighting.ClockTime = savedLighting.ClockTime end
	if savedLighting.FogEnd then Lighting.FogEnd = savedLighting.FogEnd end
	if savedLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = savedLighting.GlobalShadows end
	if savedLighting.OutdoorAmbient then Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient end
end

-- ===================== AUTO CHEST =====================
-- Finds chest models in workspace, teleports to them, clicks to open
-- Then collects dropped items nearby

local function startAutoChest()
	autoChestActive = true
	task.spawn(function()
		while autoChestActive do
			pcall(function()
				local char = LocalPlayer.Character
				local hrp = getRoot()
				if not char or not hrp then return end

				local savedCF = hrp.CFrame

				for _, obj in ipairs(workspace:GetDescendants()) do
					if not autoChestActive then break end
					if table.find(CHEST_ITEMS, obj.Name) then
						local cf = getItemCFrame(obj)
						if cf and (cf.Position - savedCF.Position).Magnitude <= autoChestRange then
							-- Fire prompts from distance first
							fireAllPrompts(obj)
							fireAllClicks(obj)
							-- Rapid TP-click-return
							char:PivotTo(cf + Vector3.new(0, 3, 0))
							task.wait(0.1)
							mouse1click()
							task.wait(0.1)
							mouse1click()
							task.wait(0.1)
							-- Collect any dropped loot nearby before returning
							for _, loot in ipairs(workspace:GetDescendants()) do
								local pos = getItemPosition(loot)
								if pos and table.find(ALL_ITEMS, loot.Name) then
									if (pos - cf.Position).Magnitude <= 15 then
										fireAllPrompts(loot)
										char:PivotTo(CFrame.new(pos + Vector3.new(0, 2, 0)))
										task.wait(0.05)
										mouse1click()
									end
								end
							end
							-- Return to saved position
							char:PivotTo(savedCF)
							task.wait(0.1)
						end
					end
				end
			end)
			task.wait(2)
		end
	end)
	notify("Auto Chest", "Looting chests in " .. autoChestRange .. " stud radius!")
end

local function stopAutoChest()
	autoChestActive = false
end

-- ===================== AUTO COOK =====================
-- Finds food items nearby and teleports to crockpot/campfire to cook
local function startAutoCook()
	autoCookActive = true
	task.spawn(function()
		while autoCookActive do
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end

				-- Look for raw food items
				local rawFoods = {"Morsel", "Meat? Sandwich", "Bunny Foot"}
				for _, obj in ipairs(workspace:GetDescendants()) do
					if not autoCookActive then break end
					if table.find(rawFoods, obj.Name) then
						local cf = getItemCFrame(obj)
						if cf then
							-- Pick up food
							char:PivotTo(cf + Vector3.new(0, 2, 0))
							task.wait(0.2)
							mouse1click()
							task.wait(0.2)
							-- Go to campfire to cook
							char:PivotTo(CFrame.new(0, 10, 0))
							task.wait(0.3)
							mouse1click()
							task.wait(0.3)
						end
					end
				end
			end)
			task.wait(4)
		end
	end)
	notify("Auto Cook", "Cooking food automatically!")
end

local function stopAutoCook()
	autoCookActive = false
end

-- ===================== AUTO HEAL =====================
-- Finds healing items and uses them when health is low
local function startAutoHeal()
	autoHealActive = true
	task.spawn(function()
		while autoHealActive do
			pcall(function()
				local hum = getHumanoid()
				local char = LocalPlayer.Character
				if not hum or not char then return end

				if hum.Health < hum.MaxHealth * 0.7 then
					-- Find healing items
					for _, obj in ipairs(workspace:GetDescendants()) do
						if not autoHealActive then break end
						if table.find(HEALING_ITEMS, obj.Name) then
							local cf = getItemCFrame(obj)
							if cf then
								char:PivotTo(cf + Vector3.new(0, 2, 0))
								task.wait(0.2)
								mouse1click()
								task.wait(0.3)
								break -- only use one at a time
							end
						end
					end
				end
			end)
			task.wait(2)
		end
	end)
	notify("Auto Heal", "Auto healing when low!")
end

local function stopAutoHeal()
	autoHealActive = false
end

-- ===================== AUTO FEED =====================
-- Finds food and eats it when hunger is getting low
local function startAutoFeed()
	autoFeedActive = true
	task.spawn(function()
		while autoFeedActive do
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end

				-- Find food items and pick them up
				for _, obj in ipairs(workspace:GetDescendants()) do
					if not autoFeedActive then break end
					if table.find(FOOD_ITEMS, obj.Name) then
						local cf = getItemCFrame(obj)
						if cf then
							char:PivotTo(cf + Vector3.new(0, 2, 0))
							task.wait(0.2)
							mouse1click()
							task.wait(0.3)
							mouse1click()
							task.wait(0.2)
							break
						end
					end
				end
			end)
			task.wait(5)
		end
	end)
	notify("Auto Feed", "Auto eating food!")
end

local function stopAutoFeed()
	autoFeedActive = false
end

-- ===================== GOD MODE =====================
-- Constantly resets health to max, prevents ragdoll/falling states
local function startGodMode()
	godModeConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local hum = getHumanoid()
			if hum then
				hum.Health = hum.MaxHealth
				hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			end
		end)
	end)
	notify("God Mode", "Invincible!")
end

local function stopGodMode()
	if godModeConnection then godModeConnection:Disconnect() godModeConnection = nil end
	pcall(function()
		local hum = getHumanoid()
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		end
	end)
end

-- ===================== HITBOX EXPANDER =====================
-- Makes enemy HumanoidRootParts larger so they are easier to hit
local function startHitboxExpand()
	hitboxExpandActive = true
	hitboxConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			for _, obj in ipairs(workspace:GetDescendants()) do
				if table.find(ENEMY_NAMES, obj.Name) and obj:IsA("Model") then
					local hrp = obj:FindFirstChild("HumanoidRootPart")
					if hrp then
						hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
						hrp.Transparency = 0.8
					end
				end
			end
		end)
	end)
	notify("Hitbox", "Hitboxes expanded!")
end

local function stopHitboxExpand()
	hitboxExpandActive = false
	if hitboxConnection then hitboxConnection:Disconnect() hitboxConnection = nil end
	-- Reset hitboxes
	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if table.find(ENEMY_NAMES, obj.Name) and obj:IsA("Model") then
				local hrp = obj:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Size = Vector3.new(2, 2, 1)
					hrp.Transparency = 1
				end
			end
		end
	end)
end

-- ===================== FREEZE ENTITIES =====================
-- Anchors all enemy HumanoidRootParts so they can't move
local function freezeAllEntities()
	local count = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if table.find(ENEMY_NAMES, obj.Name) and obj:IsA("Model") then
			pcall(function()
				local hrp = obj:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Anchored = true
					count = count + 1
				end
			end)
		end
	end
	notify("Freeze", "Froze " .. count .. " entities!")
end

local function unfreezeAllEntities()
	local count = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if table.find(ENEMY_NAMES, obj.Name) and obj:IsA("Model") then
			pcall(function()
				local hrp = obj:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Anchored = false
					count = count + 1
				end
			end)
		end
	end
	notify("Unfreeze", "Unfroze " .. count .. " entities!")
end

-- ===================== ANTI AFK =====================
local function startAntiAfk()
	antiAfkActive = true
	pcall(function()
		for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
			conn:Disable()
		end
	end)
	-- Backup: virtual input every 5 min
	task.spawn(function()
		while antiAfkActive do
			pcall(function()
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
				task.wait(0.1)
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
			end)
			task.wait(300)
		end
	end)
	notify("Anti-AFK", "AFK prevention active!")
end

local function stopAntiAfk()
	antiAfkActive = false
end

-- ===================== AUTO OPEN SEED BOXES =====================
-- Finds Seed Box items, teleports to them, clicks to open
local function startAutoSeedBox()
	autoSeedBoxActive = true
	task.spawn(function()
		while autoSeedBoxActive do
			pcall(function()
				local char = LocalPlayer.Character
				if not char then return end

				for _, obj in ipairs(workspace:GetDescendants()) do
					if not autoSeedBoxActive then break end
					if obj.Name == "Seed Box" then
						local cf = getItemCFrame(obj)
						if cf then
							char:PivotTo(cf + Vector3.new(0, 2, 0))
							task.wait(0.2)
							mouse1click()
							task.wait(0.3)
							mouse1click()
							task.wait(0.2)
						end
					end
				end
			end)
			task.wait(3)
		end
	end)
	notify("Seed Boxes", "Auto opening seed boxes!")
end

local function stopAutoSeedBox()
	autoSeedBoxActive = false
end

-- ===================== PLANT SAPLINGS AROUND CAMPFIRE =====================
-- Plants saplings in a ring around the campfire (origin point)
local function plantSaplingsAroundCampfire()
	local char = LocalPlayer.Character
	if not char then notify("Error", "No character") return end

	local campfirePos = Vector3.new(0, 5, 0)
	local radius = 12
	local count = 12

	notify("Planting", "Planting saplings around campfire...")

	for i = 1, count do
		if not char or not char.Parent then break end
		local angle = (i / count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local targetPos = campfirePos + offset

		char:PivotTo(CFrame.new(targetPos + Vector3.new(0, 2, 0)))
		task.wait(0.25)
		mouse1click()
		task.wait(0.3)
		mouse1click()
		task.wait(0.2)
	end

	-- Return to campfire
	char:PivotTo(CFrame.new(campfirePos + Vector3.new(0, 5, 0)))
	notify("Planted", "Saplings planted around campfire!")
end

-- ===================== BUILD LOG WALLS IN CIRCLE =====================
-- Places log walls in a defensive ring around position
local function buildLogWallsInCircle()
	local char = LocalPlayer.Character
	local hrp = getRoot()
	if not char or not hrp then notify("Error", "No character") return end

	local basePos = hrp.Position
	local radius = 15
	local count = 10

	notify("Building", "Placing log walls in circle...")

	for i = 1, count do
		if not char or not char.Parent then break end
		local angle = (i / count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local targetPos = basePos + offset

		char:PivotTo(CFrame.new(targetPos + Vector3.new(0, 2, 0)))
		task.wait(0.3)
		mouse1click()
		task.wait(0.3)
	end

	char:PivotTo(CFrame.new(basePos + Vector3.new(0, 2, 0)))
	notify("Built", "Log walls placed!")
end

-- ===================== CLEANUP LOGS =====================
-- Removes all log models from workspace by moving them far away
local function cleanupLogs()
	local count = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "Log" then
			pcall(function()
				if obj:IsA("Model") then
					obj:PivotTo(CFrame.new(0, -500, 0))
					count = count + 1
				elseif obj:IsA("BasePart") and not obj.Anchored then
					obj.CFrame = CFrame.new(0, -500, 0)
					count = count + 1
				end
			end)
		end
	end
	notify("Cleanup", "Moved " .. count .. " logs out of the way!")
end

-- ===================== REVEAL MAP =====================
-- Reveals map by teleporting to distant positions briefly then returning
local function revealMap()
	local char = LocalPlayer.Character
	local hrp = getRoot()
	if not char or not hrp then notify("Error", "No character") return end

	local startPos = hrp.CFrame
	notify("Map", "Revealing map...")

	-- Visit corners of the map to reveal fog of war
	local mapPositions = {
		Vector3.new(500, 50, 500),
		Vector3.new(-500, 50, 500),
		Vector3.new(500, 50, -500),
		Vector3.new(-500, 50, -500),
		Vector3.new(0, 50, 0),
		Vector3.new(250, 50, 0),
		Vector3.new(-250, 50, 0),
		Vector3.new(0, 50, 250),
		Vector3.new(0, 50, -250),
	}

	for _, pos in ipairs(mapPositions) do
		if not char or not char.Parent then break end
		char:PivotTo(CFrame.new(pos))
		task.wait(0.5)
	end

	-- Return to start
	char:PivotTo(startPos)
	notify("Map", "Map revealed!")
end

-- ===================== AUTO COLLECT FLOWERS + GOLD =====================
local function collectFlowersAndGold()
	local char = LocalPlayer.Character
	local hrp = getRoot()
	if not char or not hrp then return end
	local count = 0

	for _, obj in ipairs(workspace:GetDescendants()) do
		local name = obj.Name
		if name == "Flower" or name == "Golden Flower" or name == "Coin Stack" or name == "Gold Stack" then
			local cf = getItemCFrame(obj)
			if cf then
				char:PivotTo(cf + Vector3.new(0, 2, 0))
				task.wait(0.15)
				mouse1click()
				task.wait(0.1)
				count = count + 1
			end
		end
	end

	notify("Collect", "Picked up " .. count .. " flowers/gold!")
end

-- ===================== TELEPORT ALL TREES/CHESTS/ENTITIES =====================
-- Moves all trees/chests/entities to your position
local function teleportAllTrees()
	local hrp = getRoot()
	if not hrp then return end
	local count = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if (obj.Name == "Small Tree" or obj.Name == "Big Tree" or obj.Name == "Tree") and obj:IsA("Model") then
			pcall(function()
				obj:PivotTo(CFrame.new(hrp.Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))))
				count = count + 1
			end)
		end
	end
	notify("Trees", "Brought " .. count .. " trees to you!")
end

local function teleportAllChests()
	local hrp = getRoot()
	if not hrp then return end
	local count = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if table.find(CHEST_ITEMS, obj.Name) then
			pcall(function()
				if obj:IsA("Model") then
					obj:PivotTo(CFrame.new(hrp.Position + Vector3.new(math.random(-5, 5), 2, math.random(-5, 5))))
					count = count + 1
				elseif obj:IsA("BasePart") then
					obj.CFrame = CFrame.new(hrp.Position + Vector3.new(math.random(-5, 5), 2, math.random(-5, 5)))
					count = count + 1
				end
			end)
		end
	end
	notify("Chests", "Brought " .. count .. " chests to you!")
end

-- ===================== BUILD FARM TAB =====================
do
	local tab = tabFrames["Farm"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Chop Aura", o())
	createToggle(tab, "Chop Aura (Auto Chop Trees)", o(), function(on)
		if on then startAutoTreeFarm() else stopAutoTreeFarm() end
	end)
	createSlider(tab, "Chop Aura Range (studs)", 10, 100, chopAuraRange, o(), function(val)
		chopAuraRange = val
	end)
	createInfoLabel(tab, "Chops trees in radius - you stay in place (Voidware style)", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Saplings", o())
	createToggle(tab, "Auto Collect Saplings", o(), function(on)
		saplingFarmActive = on
		if on then startSaplingFarm() else stopSaplingFarm() end
	end)
	createSlider(tab, "Sapling Collect Range (studs)", 10, 100, saplingFarmRange, o(), function(val)
		saplingFarmRange = val
	end)
	createButton(tab, "Plant Saplings in Circle (Around You)", o(), plantSaplingsInCircle)
	createButton(tab, "Plant Saplings Around Campfire", o(), plantSaplingsAroundCampfire)
	createToggle(tab, "Auto Open Seed Boxes", o(), function(on)
		autoSeedBoxActive = on
		if on then startAutoSeedBox() else stopAutoSeedBox() end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Chests", o())
	createToggle(tab, "Auto Chest (Open + Loot)", o(), function(on)
		autoChestActive = on
		if on then startAutoChest() else stopAutoChest() end
	end)
	createSlider(tab, "Auto Chest Range (studs)", 10, 100, autoChestRange, o(), function(val)
		autoChestRange = val
	end)
	createInfoLabel(tab, "Opens chests in range, fires prompts + collects loot", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Campfire & Survival", o())
	createToggle(tab, "Auto Fuel Campfire", o(), function(on)
		autoFuelActive = on
		if on then startAutoFuel() else stopAutoFuel() end
	end)
	createToggle(tab, "Auto Cook (Raw Food)", o(), function(on)
		autoCookActive = on
		if on then startAutoCook() else stopAutoCook() end
	end)
	createToggle(tab, "Auto Feed (Eat Food)", o(), function(on)
		autoFeedActive = on
		if on then startAutoFeed() else stopAutoFeed() end
	end)
	createToggle(tab, "Auto Heal (Use Bandage/Medkit)", o(), function(on)
		autoHealActive = on
		if on then startAutoHeal() else stopAutoHeal() end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Auto Pickup", o())
	createToggle(tab, "Auto Pickup Nearby Items", o(), function(on)
		autoPickupActive = on
		if on then startAutoPickup() else stopAutoPickup() end
	end)
	createSlider(tab, "Auto Pickup Range (studs)", 10, 100, autoPickupRange, o(), function(val)
		autoPickupRange = val
	end)
	createButton(tab, "Collect Flowers & Gold", o(), collectFlowersAndGold)

	createSpacer(tab, o())

	createSectionLabel(tab, "Bring Items to You", o())
	createButton(tab, "Bring Resources (Logs/Coal/Scrap)", o(), function()
		bringItemsByName(RESOURCE_ITEMS)
	end)
	createButton(tab, "Bring Food", o(), function()
		bringItemsByName(FOOD_ITEMS)
	end)
	createButton(tab, "Bring Weapons + Ammo", o(), function()
		local combined = {}
		for _, v in ipairs(WEAPON_ITEMS) do table.insert(combined, v) end
		for _, v in ipairs(AMMO_ITEMS) do table.insert(combined, v) end
		bringItemsByName(combined)
	end)
	createButton(tab, "Bring Healing", o(), function()
		bringItemsByName(HEALING_ITEMS)
	end)
	createButton(tab, "Bring Armor", o(), function()
		bringItemsByName(ARMOR_ITEMS)
	end)
	createButton(tab, "Bring Fuel", o(), function()
		bringItemsByName(FUEL_ITEMS)
	end)
	createButton(tab, "Bring ALL Items", o(), function()
		bringItemsByName(ALL_ITEMS)
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "World", o())
	createButton(tab, "Teleport All Trees to You", o(), teleportAllTrees)
	createButton(tab, "Teleport All Chests to You", o(), teleportAllChests)
	createButton(tab, "Build Log Walls in Circle", o(), buildLogWallsInCircle)
	createButton(tab, "Cleanup Logs (Move Away)", o(), cleanupLogs)
	createButton(tab, "Reveal Map", o(), revealMap)
end

-- ===================== BUILD COMBAT TAB =====================
do
	local tab = tabFrames["Combat"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Kill Aura", o())
	createToggle(tab, "Kill Aura (Auto Attack Enemies)", o(), function(on)
		killAuraActive = on
		if on then startKillAura() else stopKillAura() end
	end)
	createSlider(tab, "Kill Range (studs)", 5, 50, killAuraRange, o(), function(val)
		killAuraRange = val
	end)
	createSlider(tab, "Attack Speed (x100 ms)", 5, 50, math.floor(killAuraSpeed * 100), o(), function(val)
		killAuraSpeed = val / 100
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Protection", o())
	createToggle(tab, "God Mode (Infinite Health)", o(), function(on)
		godModeActive = on
		if on then startGodMode() else stopGodMode() end
	end)
	createInfoLabel(tab, "Constantly heals to max, prevents death", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Hitbox", o())
	createToggle(tab, "Hitbox Expander", o(), function(on)
		hitboxExpandActive = on
		if on then startHitboxExpand() else stopHitboxExpand() end
	end)
	createSlider(tab, "Hitbox Size", 5, 30, hitboxSize, o(), function(val)
		hitboxSize = val
	end)
	createInfoLabel(tab, "Makes enemy hitboxes larger for easier hits", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Entity Control", o())
	createButton(tab, "Freeze All Entities", o(), freezeAllEntities)
	createButton(tab, "Unfreeze All Entities", o(), unfreezeAllEntities)
	createInfoLabel(tab, "Anchors/unanchors all enemy HumanoidRootParts", o())
end

-- ===================== BUILD MOVEMENT TAB =====================
do
	local tab = tabFrames["Movement"]
	createSectionLabel(tab, "Flight", 1)
	createToggle(tab, "Fly (WASD + Space/Shift)", 2, function(on)
		flyActive = on
		if on then startFly() else stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 200, flySpeed, 3, function(val) flySpeed = val end)
	createInfoLabel(tab, "Camera-relative flight with BodyVelocity", 4)

	createSpacer(tab, 5)

	createSectionLabel(tab, "Speed", 6)
	createToggle(tab, "Speed Boost", 7, function(on)
		speedBoostActive = on
		if on then startSpeedBoost() else stopSpeedBoost() end
	end)
	createSlider(tab, "Speed Value", 20, 200, speedValue, 8, function(val) speedValue = val end)

	createSpacer(tab, 9)

	createSectionLabel(tab, "Other", 10)
	createToggle(tab, "Noclip (Walk Through Walls)", 11, function(on)
		noclipActive = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "Infinite Jump", 12, function(on)
		infJumpActive = on
	end)

	createSpacer(tab, 13)

	createSectionLabel(tab, "AFK", 14)
	createToggle(tab, "Anti-AFK (Prevent Kick)", 15, function(on)
		antiAfkActive = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)
	createInfoLabel(tab, "Disables idle kick + sends periodic input", 16)
end

-- ===================== BUILD VISUALS TAB =====================
do
	local tab = tabFrames["Visuals"]
	createSectionLabel(tab, "ESP", 1)
	createToggle(tab, "Item ESP (Resources/Chests/Loot)", 2, function(on)
		espActive = on
		if on then startESP() else clearESP() end
	end)
	createToggle(tab, "Entity ESP (Enemies/NPCs)", 3, function(on)
		entityEspActive = on
		if on then startEntityESP() else clearEntityESP() end
	end)

	createSpacer(tab, 4)

	createSectionLabel(tab, "Visual Mods", 5)
	createToggle(tab, "Fullbright (Remove Darkness)", 6, function(on)
		fullbrightActive = on
		if on then enableFullbright() else disableFullbright() end
	end)
	createInfoLabel(tab, "Removes fog, shadows, makes everything bright", 7)
end

-- ===================== BUILD TELEPORT TAB =====================
do
	local tab = tabFrames["Teleport"]
	createSectionLabel(tab, "Quick Teleports", 1)
	createButton(tab, "TP to Campfire", 2, function()
		local char = LocalPlayer.Character
		if char then char:PivotTo(CFrame.new(0, 10, 0)) end
	end)
	createButton(tab, "TP to Grinder", 3, function()
		local char = LocalPlayer.Character
		if char then char:PivotTo(CFrame.new(16.1, 4, -4.6)) end
	end)

	createSpacer(tab, 4)

	createSectionLabel(tab, "Teleport to Item", 5)
	createInfoLabel(tab, "Finds closest instance and teleports you there", 6)

	-- Create teleport buttons for key items
	local tpItems = {
		"Lost Child", "Lost Child2", "Lost Child3", "Lost Child4",
		"Chest", "Item Chest", "Stronghold Diamond Chest", "Alien Chest",
		"Sapling", "Seed Box", "Log", "Coal",
		"Good Axe", "Raygun", "Laser Sword", "Rifle", "Revolver",
		"Cultist Gem", "Gem of the Forest",
		"Wolf", "Bear", "Alpha Wolf", "Alien", "Deer",
	}

	for i, itemName in ipairs(tpItems) do
		createButton(tab, "TP to " .. itemName, 6 + i, function()
			local hrp = getRoot()
			local char = LocalPlayer.Character
			if not hrp or not char then notify("Error", "No character") return end

			local closest, shortest = nil, math.huge
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj.Name == itemName then
					local pos = getItemPosition(obj)
					if pos then
						local dist = (pos - hrp.Position).Magnitude
						if dist < shortest then
							closest = obj
							shortest = dist
						end
					end
				end
			end

			if closest then
				local cf = getItemCFrame(closest)
				if cf then
					char:PivotTo(cf + Vector3.new(0, 5, 0))
					notify("Teleported", itemName .. " (" .. math.floor(shortest) .. "m)")
				end
			else
				notify("Not Found", itemName .. " not in workspace")
			end
		end)
	end
end

-- ===================== MINIMIZE / TOGGLE =====================

-- Mobile toggle button removed: WindUI provides its own open button.
-- ===================== RESPAWN HANDLER =====================
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	if flyActive then stopFly() task.wait(0.3) startFly() end
	if speedBoostActive then stopSpeedBoost() task.wait(0.3) startSpeedBoost() end
	if noclipActive then stopNoclip() task.wait(0.3) startNoclip() end
end)

-- ===================== STARTUP =====================
notify("99 Nights Hub v1.0", "Loaded! Right Shift to toggle")
print("[99 Nights Hub v1.0] Loaded - Right Shift to toggle")
print("[99 Nights Hub v1.0] Tabs: Farm | Combat | Movement | Visuals | Teleport")
