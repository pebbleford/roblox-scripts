-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("synapsex") then return end

-- ================================================================
-- Pebbleford Hub - Executor + Admin
-- Script executor with Infinite Yield-style admin
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Teams = game:GetService("Teams")
local LocalPlayer = Players.LocalPlayer

local _spawn = (task and task.spawn) or spawn
local _wait = (task and task.wait) or wait
local F = {} -- shared function table (avoids Luau 200 local limit)

-- ===================== THEME SYSTEM =====================
local THEMES = {
	default = {
		name = "Default",
		bg = Color3.fromRGB(20, 20, 20), bgSecondary = Color3.fromRGB(30, 30, 30), tabBg = Color3.fromRGB(45, 45, 45),
		accent = Color3.fromRGB(255, 102, 0), accentHover = Color3.fromRGB(255, 133, 51), accentDark = Color3.fromRGB(180, 72, 0),
		textPrimary = Color3.fromRGB(255, 255, 255), textSecondary = Color3.fromRGB(176, 176, 176), textDim = Color3.fromRGB(120, 120, 120),
		border = Color3.fromRGB(50, 50, 50), toggleOn = Color3.fromRGB(255, 102, 0), toggleOff = Color3.fromRGB(85, 85, 85),
		error = Color3.fromRGB(255, 68, 68), success = Color3.fromRGB(68, 255, 68),
		editor = Color3.fromRGB(15, 15, 15), editorLine = Color3.fromRGB(35, 35, 35),
		btnExecute = Color3.fromRGB(255, 102, 0), btnClear = Color3.fromRGB(60, 60, 60),
	},
	galaxy = {
		name = "Galaxy",
		bg = Color3.fromRGB(10, 5, 25), bgSecondary = Color3.fromRGB(18, 10, 40), tabBg = Color3.fromRGB(30, 15, 60),
		accent = Color3.fromRGB(138, 43, 226), accentHover = Color3.fromRGB(170, 80, 255), accentDark = Color3.fromRGB(90, 20, 160),
		textPrimary = Color3.fromRGB(230, 220, 255), textSecondary = Color3.fromRGB(160, 140, 200), textDim = Color3.fromRGB(100, 80, 140),
		border = Color3.fromRGB(50, 30, 80), toggleOn = Color3.fromRGB(138, 43, 226), toggleOff = Color3.fromRGB(60, 40, 90),
		error = Color3.fromRGB(255, 68, 68), success = Color3.fromRGB(100, 255, 150),
		editor = Color3.fromRGB(8, 4, 18), editorLine = Color3.fromRGB(25, 15, 45),
		btnExecute = Color3.fromRGB(138, 43, 226), btnClear = Color3.fromRGB(40, 25, 65),
	},
	ocean = {
		name = "Ocean",
		bg = Color3.fromRGB(8, 18, 28), bgSecondary = Color3.fromRGB(12, 25, 38), tabBg = Color3.fromRGB(18, 40, 60),
		accent = Color3.fromRGB(0, 170, 255), accentHover = Color3.fromRGB(50, 200, 255), accentDark = Color3.fromRGB(0, 120, 180),
		textPrimary = Color3.fromRGB(220, 240, 255), textSecondary = Color3.fromRGB(140, 180, 210), textDim = Color3.fromRGB(80, 120, 150),
		border = Color3.fromRGB(20, 50, 75), toggleOn = Color3.fromRGB(0, 170, 255), toggleOff = Color3.fromRGB(30, 60, 80),
		error = Color3.fromRGB(255, 90, 90), success = Color3.fromRGB(68, 255, 150),
		editor = Color3.fromRGB(5, 12, 20), editorLine = Color3.fromRGB(15, 30, 45),
		btnExecute = Color3.fromRGB(0, 170, 255), btnClear = Color3.fromRGB(20, 40, 55),
	},
	blood = {
		name = "Blood",
		bg = Color3.fromRGB(15, 5, 5), bgSecondary = Color3.fromRGB(25, 8, 8), tabBg = Color3.fromRGB(50, 15, 15),
		accent = Color3.fromRGB(200, 0, 0), accentHover = Color3.fromRGB(255, 40, 40), accentDark = Color3.fromRGB(140, 0, 0),
		textPrimary = Color3.fromRGB(255, 220, 220), textSecondary = Color3.fromRGB(200, 150, 150), textDim = Color3.fromRGB(140, 100, 100),
		border = Color3.fromRGB(60, 20, 20), toggleOn = Color3.fromRGB(200, 0, 0), toggleOff = Color3.fromRGB(70, 30, 30),
		error = Color3.fromRGB(255, 100, 100), success = Color3.fromRGB(100, 255, 100),
		editor = Color3.fromRGB(10, 3, 3), editorLine = Color3.fromRGB(30, 10, 10),
		btnExecute = Color3.fromRGB(200, 0, 0), btnClear = Color3.fromRGB(50, 20, 20),
	},
	mint = {
		name = "Mint",
		bg = Color3.fromRGB(8, 20, 15), bgSecondary = Color3.fromRGB(12, 30, 22), tabBg = Color3.fromRGB(18, 50, 38),
		accent = Color3.fromRGB(0, 210, 140), accentHover = Color3.fromRGB(40, 240, 170), accentDark = Color3.fromRGB(0, 150, 100),
		textPrimary = Color3.fromRGB(220, 255, 240), textSecondary = Color3.fromRGB(140, 200, 175), textDim = Color3.fromRGB(80, 140, 115),
		border = Color3.fromRGB(20, 60, 45), toggleOn = Color3.fromRGB(0, 210, 140), toggleOff = Color3.fromRGB(30, 65, 50),
		error = Color3.fromRGB(255, 90, 90), success = Color3.fromRGB(68, 255, 130),
		editor = Color3.fromRGB(5, 14, 10), editorLine = Color3.fromRGB(15, 35, 25),
		btnExecute = Color3.fromRGB(0, 210, 140), btnClear = Color3.fromRGB(18, 40, 30),
	},
}

local COLORS = {}
for k, v in pairs(THEMES.default) do COLORS[k] = v end

local currentThemeName = "default"

-- ===================== STATE (grouped to reduce local count) =====================
local combatState = {
	killAuraEnabled = false,
	killAuraConnection = nil,
	antiFlingEnabled = false,
	antiFlingConnection = nil,
	antiFlingLastPos = nil,
	aimbotEnabled = false,
	aimbotConnection = nil,
	aimbotInputBeganConn = nil,
	aimbotInputEndedConn = nil,
	aimbotHolding = false,
	aimbotFOV = 200,
	aimbotSmoothing = 2,
	aimbotWallCheck = true,
	aimbotTeamCheck = true,
	triggerBotEnabled = false,
	triggerBotConnection = nil,
	hitboxEnabled = false,
	hitboxConnection = nil,
	hitboxSize = 10,
	antiVoidEnabled = false,
	antiVoidConnection = nil,
	lastSafePos = nil,
	godEnabled = false,
	godConnection = nil,
}

local espState = {
	espEnabled = false,
	highlights = {},
	nametags = {},
	espConnections = {},
	HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0),
	OUTLINE_COLOR = Color3.fromRGB(255, 255, 255),
	FILL_TRANSPARENCY = 0.5,
	OUTLINE_TRANSPARENCY = 0,
	REFRESH_INTERVAL = 5,
	tracersEnabled = false,
	tracerLines = {},
	tracerConnection = nil,
	nameEspEnabled = false,
	nameEspBillboards = {},
	drawingEspEnabled = false,
	drawingEspConnection = nil,
	drawingEspObjects = {},
	fovCircleEnabled = false,
	fovCircleFrame = nil,
	fovRadius = 200,
	crosshairEnabled = false,
	crosshairLines = {},
}

local flyState = {
	flyEnabled = false,
	flySpeed = 80,
	flyConnection = nil,
	bodyGyro = nil,
	bodyVelocity = nil,
	linearVelocity = nil,
	alignOrientation = nil,
	flyAttachment = nil,
	savedPlatformStand = false,
	vehicleFlyEnabled = false,
	vehicleFlyConnection = nil,
	vehicleFlyBV = nil,
	vehicleFlyBG = nil,
}

local moveState = {
	speedEnabled = false,
	speedValue = 100,
	noclipEnabled = false,
	noclipConnection = nil,
	infJumpEnabled = false,
	infJumpConnection = nil,
	jumpPowerValue = 50,
	gravityValue = 196.2,
	origWalkSpeed = 16,
	origJumpPower = 50,
	origGravity = 196.2,
	carNoclipEnabled = false,
	carNoclipConnection = nil,
	carSpeedEnabled = false,
	carSpeedValue = 200,
	carSpeedConnection = nil,
	carSpeedOrigMaxSpeed = nil,
	carSpeedOrigTorque = nil,
	backseatDriveEnabled = false,
	backseatDriveConnection = nil,
	backseatDriveSpeed = 80,
	backseatDriveTurn = 3,
	clickTpEnabled = false,
	clickTpConnection = nil,
	bunnyHopEnabled = false,
	bunnyHopConnection = nil,
	floatEnabled = false,
	floatConnection = nil,
	platformEnabled = false,
	platformPart = nil,
	platformConnection = nil,
	savedPositions = {},
}

local flingState = {
	flingEnabled = false,
	flingPower = 99999,
	flingPos = nil,
	flingConnection = nil,
	flingBAV = nil,
	walkFlingEnabled = false,
	walkFlingPower = 10000,
	walkFlingConnection = nil,
	walkFlingBAV = nil,
	walkFlingProps = {},
	carFlingEnabled = false,
	carFlingPower = 50000,
	carFlingConnection = nil,
	carFlingBAV = nil,
	carFlingOrigProps = {},
	savedPhysProps = {},
}

local funState = {
	invisibleEnabled = false,
	savedTransparencies = {},
	fakeCharacter = nil,
	invisPosLoop = nil,
	spinEnabled = false,
	spinConnection = nil,
	seizureEnabled = false,
	seizureConnection = nil,
	emoteActive = false,
	emoteTracks = {},
	emoteConnection = nil,
	headlessEnabled = false,
	headlessSaved = {},
	rainbowEnabled = false,
	rainbowConnection = nil,
}

local visualState = {
	fullbrightEnabled = false,
	origAmbient = nil,
	origBrightness = nil,
	origFogEnd = nil,
	origGlobalShadows = nil,
	xrayEnabled = false,
	xrayOrigTransparencies = {},
	fovChangerValue = 70,
	freecamEnabled = false,
	freecamConnection = nil,
	freecamCFrame = nil,
	origCameraSubject = nil,
	origCameraType = nil,
	noFogEnabled = false,
	origFogEndVisual = nil,
	fpsCounterEnabled = false,
	fpsLabel = nil,
	fpsConnection = nil,
}

local serverState = {
	antiAfkEnabled = false,
	antiAfkConnection = nil,
	chatSpyEnabled = false,
	chatSpyConnection = nil,
	joinNotifyEnabled = false,
	joinNotifyAddedConn = nil,
	joinNotifyRemovingConn = nil,
	autoRespawnEnabled = false,
	autoRespawnConnection = nil,
}

local playerState = {
	selectedPlayer = nil,
	spectating = false,
	orbitEnabled = false,
	orbitConnection = nil,
	orbitRadius = 10,
	attachEnabled = false,
	attachConnection = nil,
	followEnabled = false,
	followConnection = nil,
	stareEnabled = false,
	stareConnection = nil,
}

local uiState = {
	windowVisible = true,
	activeTab = "Execute",
	logLines = {},
	MAX_LOG_LINES = 50,
}

-- ===================== MOBILE / RESIZE DETECTION =====================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local ORIG_W = 600
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
	local old = game:GetService("CoreGui"):FindFirstChild("PebblefordHub")
	if old then old:Destroy() end
end)
pcall(function()
	local old = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("PebblefordHub")
	if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PebblefordHub"
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

F.findPlayer = function(name)
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
			return p
		end
	end
	return nil
end

-- ===================== GUI SETUP (WindUI) =====================
-- The hand-built window, tab bar, drag handling and mobile toggle were
-- replaced with WindUI. The builder functions keep their original names and
-- signatures and now produce WindUI elements, so all ~150 feature call sites
-- below are untouched; only these bodies changed.
--
-- screenGui above is kept deliberately: the script editor in the Execute tab
-- is a real multi-line code editor, which WindUI has no equivalent for, so it
-- stays as its own window parented there.
local WindUI
do
	local ok, lib = pcall(function()
		return loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
	end)
	if not ok or not lib then
		warn("[SX] WindUI failed to load: " .. tostring(lib))
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Pebbleford Hub",
				Text = "UI library failed to load. Check your internet/executor.",
				Duration = 8,
			})
		end)
		return
	end
	WindUI = lib
	_G.SX_UI = lib
end

-- These lived in the hand-built GUI that this replaced. Without them the tab
-- loop below indexes a nil global and the script aborts on its first pass.
local tabNames = {"Execute", "Main", "Player", "Combat", "ESP", "Movement", "Visuals", "Fun", "Server", "Settings"}
local tabFrames = {}

local Window = WindUI:CreateWindow({
	Title = "Pebbleford Hub",
	Author = "Universal Hub v3.1",
	Folder = "PebblefordHub",
	Size = UDim2.fromOffset(580, 460),
	HideSearchBar = true,
	OpenButton = {
		Title = "SX",
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
	},
})

-- Execute is not created here: it is a code editor in its own window, opened
-- from a button on the Main tab further down.
for _, name in ipairs(tabNames) do
	if name ~= "Execute" then
		tabFrames[name] = Window:Tab({Title = name})
	end
end

-- Register the hub's own palettes as WindUI themes so its Theme buttons can
-- switch them natively. The old theme code recoloured hand-built frames that
-- no longer exist; WindUI owns the chrome now, so it must do the recolouring.
do
	local function reg(t)
		pcall(function()
			WindUI:AddTheme({
				Name = t.name,
				Accent = t.accent,
				Dialog = t.bgSecondary,
				Outline = t.border,
				Text = t.textPrimary,
				Placeholder = t.textDim,
				Background = t.bg,
				Button = t.accentDark,
				Icon = t.textSecondary,
				Toggle = t.toggleOn,
				Slider = t.accent,
				Checkbox = t.accent,
			})
		end)
	end
	for _, id in ipairs({"default", "galaxy", "ocean", "blood", "mint"}) do
		if THEMES[id] then reg(THEMES[id]) end
	end
end

local function switchTab(tabName)
	uiState.activeTab = tabName
end

-- ===================== SCRIPT EDITOR WINDOW =====================
-- WindUI has no multi-line code editor, so the Execute tab keeps its original
-- hand-built editor and lives in its own draggable window instead of a tab.
-- The executor code further down parents itself to executeFrame unchanged.
local executorWindow = Instance.new("Frame")
executorWindow.Name = "ExecutorWindow"
executorWindow.Size = UDim2.new(0, 560, 0, 400)
executorWindow.Position = UDim2.new(0.5, -280, 0.5, -200)
executorWindow.BackgroundColor3 = COLORS.bg
executorWindow.BorderSizePixel = 0
executorWindow.Visible = false
executorWindow.Active = true
executorWindow.Parent = screenGui
addCorner(executorWindow, 8)
addStroke(executorWindow, COLORS.border, 1)

local execTitleBar = Instance.new("Frame")
execTitleBar.Size = UDim2.new(1, 0, 0, 32)
execTitleBar.BackgroundColor3 = COLORS.bgSecondary
execTitleBar.BorderSizePixel = 0
execTitleBar.Parent = executorWindow
addCorner(execTitleBar, 8)

local execTitle = Instance.new("TextLabel")
execTitle.Size = UDim2.new(1, -40, 1, 0)
execTitle.Position = UDim2.new(0, 12, 0, 0)
execTitle.BackgroundTransparency = 1
execTitle.Text = "Script Executor"
execTitle.TextColor3 = COLORS.textPrimary
execTitle.TextSize = 14
execTitle.Font = Enum.Font.GothamBold
execTitle.TextXAlignment = Enum.TextXAlignment.Left
execTitle.Parent = execTitleBar

local execClose = Instance.new("TextButton")
execClose.Size = UDim2.new(0, 24, 0, 24)
execClose.Position = UDim2.new(1, -30, 0, 4)
execClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
execClose.Text = "X"
execClose.TextColor3 = Color3.fromRGB(255, 255, 255)
execClose.TextSize = 12
execClose.Font = Enum.Font.GothamBold
execClose.BorderSizePixel = 0
execClose.Parent = execTitleBar
addCorner(execClose, 5)
execClose.MouseButton1Click:Connect(function()
	executorWindow.Visible = false
end)

local executeFrame = Instance.new("Frame")
executeFrame.Name = "ExecuteFrame"
executeFrame.Size = UDim2.new(1, 0, 1, -32)
executeFrame.Position = UDim2.new(0, 0, 0, 32)
executeFrame.BackgroundTransparency = 1
executeFrame.Parent = executorWindow
tabFrames["Execute"] = executeFrame

-- Touch and mouse both, so the window can be moved on a phone.
do
	local dragging, dragStart, startPos = false, nil, nil
	execTitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = executorWindow.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			executorWindow.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- ===================== UI COMPONENT BUILDERS (WindUI) =====================
-- order is accepted and ignored: WindUI lays out in creation order, which is
-- the order these were already declared in.
local function createSectionLabel(parent, text, order)
	if not parent then return end
	return parent:Section({Title = text})
end

local function createInfoLabel(parent, text, order)
	if not parent then return end
	-- Text goes in Title: WindUI treats it as the primary rendered field, and
	-- a paragraph with an empty Title draws as a blank box.
	return parent:Paragraph({Title = text})
end

local function createDynamicLabel(parent, text)
	if not parent then return setmetatable({}, {__newindex = function() end}) end
	local para = parent:Paragraph({Title = tostring(text or "")})
	local last = tostring(text or "")
	return setmetatable({}, {
		__newindex = function(_, key, value)
			if key == "Text" then
				local str = tostring(value)
				if str ~= last then last = str; pcall(function() para:SetTitle(str) end) end
			end
		end,
		__index = function() return nil end,
	})
end

local function createToggle(parent, text, order, callback)
	if not parent then return end
	return parent:Toggle({
		Title = text,
		Value = false,
		Callback = function(value)
			if callback then pcall(callback, value) end
		end,
	})
end

local function createActionButton(parent, text, order, callback)
	if not parent then return end
	return parent:Button({
		Title = text,
		Callback = function()
			if callback then pcall(callback) end
		end,
	})
end

local function createSlider(parent, text, min, max, default, order, callback)
	if not parent then return end
	return parent:Slider({
		Title = text,
		Step = 1,
		Value = {Min = min, Max = max, Default = default},
		Callback = function(value)
			-- WindUI can hand back a table for range sliders; take the number.
			local n = type(value) == "table" and (value.Value or value.Default) or value
			if callback and type(n) == "number" then pcall(callback, n) end
		end,
	})
end

local function createDropdown(parent, text, options, default, callback)
	if not parent then return end
	return parent:Dropdown({
		Title = text,
		Values = options,
		Value = default,
		Callback = function(chosen)
			local value = type(chosen) == "table" and chosen[1] or chosen
			if callback and value then pcall(callback, value) end
		end,
	})
end

local function createInput(parent, text, placeholder, callback)
	if not parent then return end
	return parent:Input({
		Title = text,
		Placeholder = placeholder or "",
		Callback = function(value)
			if callback then pcall(callback, value) end
		end,
	})
end

local function createSpacer(parent, order)
	-- WindUI spaces its own elements.
	return nil
end

-- Opens the script editor. It is a separate window rather than a tab because
-- WindUI has no multi-line code editor element.
if tabFrames["Main"] then
	tabFrames["Main"]:Button({
		Title = "Open Script Executor",
		Desc = "Opens the Lua editor in its own window",
		Callback = function()
			executorWindow.Visible = not executorWindow.Visible
		end,
	})
end

-- ===================== LOG SYSTEM =====================
local logFrame

-- Backing state for the player dropdown that replaced the old button list.
local playerDropdown
local playerLookup = {}

local function addLog(msg, color)
	-- The scrolling log panel went with the hand-built window, so lines go to
	-- the console. They are still kept in uiState for anything that reads them,
	-- and the logFrame branch below stays dormant since it is never assigned.
	print("[SX] " .. tostring(msg))
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
	scriptInput.PlaceholderText = '-- Paste your script here...\n-- Press "Execute" to run\nprint("Hello from Pebbleford Hub!")'
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
		hubFrame.Size = UDim2.new(0, 380, 0, 200)
		hubFrame.Position = UDim2.new(0.5, -190, 0.5, -100)
		hubFrame.BackgroundColor3 = COLORS.bgSecondary
		hubFrame.BorderSizePixel = 0
		hubFrame.ZIndex = 10
		hubFrame.Parent = screenGui
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
F.addHighlight = function(player)
	if player == LocalPlayer then return end
	if espState.highlights[player] then return end
	local character = player.Character
	if not character or not character.Parent then return end
	pcall(function()
		local highlight = Instance.new("Highlight")
		highlight.Name = "ESPHighlight"
		highlight.FillColor = espState.HIGHLIGHT_COLOR
		highlight.OutlineColor = espState.OUTLINE_COLOR
		highlight.FillTransparency = espState.FILL_TRANSPARENCY
		highlight.OutlineTransparency = espState.OUTLINE_TRANSPARENCY
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Adornee = character
		highlight.Parent = character
		espState.highlights[player] = highlight
	end)
end

F.addNametag = function(player)
	if player == LocalPlayer then return end
	if espState.nametags[player] then return end
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
			table.insert(espState.espConnections, conn)
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
		table.insert(espState.espConnections, distConn)
		espState.nametags[player] = bb
	end)
end

F.removeHighlight = function(player)
	local hl = espState.highlights[player]
	if hl then pcall(function() hl:Destroy() end) end
	espState.highlights[player] = nil
end

F.removeNametag = function(player)
	local tag = espState.nametags[player]
	if tag then pcall(function() tag:Destroy() end) end
	espState.nametags[player] = nil
end

F.cleanupStale = function()
	local staleHL, staleNT = {}, {}
	for player, hl in pairs(espState.highlights) do
		local alive = false
		pcall(function() if hl and hl.Adornee and hl.Adornee.Parent then alive = true end end)
		if not alive then table.insert(staleHL, player) end
	end
	for player, tag in pairs(espState.nametags) do
		local alive = false
		pcall(function() if tag and tag.Parent then alive = true end end)
		if not alive then table.insert(staleNT, player) end
	end
	for _, player in ipairs(staleHL) do F.removeHighlight(player) end
	for _, player in ipairs(staleNT) do F.removeNametag(player) end
end

F.espScanAll = function()
	F.cleanupStale()
	local count, skipped = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			if character and character.Parent then
				if not espState.highlights[player] then F.addHighlight(player) end
				if not espState.nametags[player] then F.addNametag(player) end
				count = count + 1
			else
				skipped = skipped + 1
			end
		end
	end
	return count, skipped
end

F.hookPlayer = function(player)
	if player == LocalPlayer then return end
	local conn = player.CharacterAdded:Connect(function()
		if not espState.espEnabled then return end
		_wait(1)
		if espState.espEnabled then F.addHighlight(player) F.addNametag(player) end
	end)
	table.insert(espState.espConnections, conn)
end

F.enableESP = function()
	for _, player in ipairs(Players:GetPlayers()) do F.hookPlayer(player) end
	local addedConn = Players.PlayerAdded:Connect(function(player)
		if not espState.espEnabled then return end
		F.hookPlayer(player)
	end)
	table.insert(espState.espConnections, addedConn)
	local count, skipped = F.espScanAll()
	addLog("[ESP] ON - " .. count .. " highlighted, " .. skipped .. " pending", COLORS.success)
	_spawn(function()
		while espState.espEnabled do
			_wait(espState.REFRESH_INTERVAL)
			if not espState.espEnabled then break end
			F.espScanAll()
		end
	end)
end

F.disableESP = function()
	local allP = {}
	for player in pairs(espState.highlights) do table.insert(allP, player) end
	for _, player in ipairs(allP) do F.removeHighlight(player) end
	local allN = {}
	for player in pairs(espState.nametags) do table.insert(allN, player) end
	for _, player in ipairs(allN) do F.removeNametag(player) end
	for _, conn in ipairs(espState.espConnections) do pcall(function() conn:Disconnect() end) end
	espState.espConnections = {}
	addLog("[ESP] OFF", COLORS.error)
end

-- ===================== DRAWING ESP (INFINITE RANGE) =====================
F.clearDrawingEsp = function()
	for _, objs in pairs(espState.drawingEspObjects) do
		pcall(function() if objs.box then objs.box:Remove() end end)
		pcall(function() if objs.name then objs.name:Remove() end end)
		pcall(function() if objs.dist then objs.dist:Remove() end end)
		pcall(function() if objs.health then objs.health:Remove() end end)
		pcall(function() if objs.healthBg then objs.healthBg:Remove() end end)
	end
	espState.drawingEspObjects = {}
end

F.getDrawingObjects = function(player)
	if espState.drawingEspObjects[player] then
		return espState.drawingEspObjects[player]
	end
	local ok, objs = pcall(function()
		local box = Drawing.new("Quad")
		box.Color = espState.OUTLINE_COLOR
		box.Thickness = 1
		box.Filled = false
		box.Visible = false

		local name = Drawing.new("Text")
		name.Color = Color3.fromRGB(255, 255, 255)
		name.Size = 13
		name.Center = true
		name.Outline = true
		name.OutlineColor = Color3.fromRGB(0, 0, 0)
		name.Visible = false

		local dist = Drawing.new("Text")
		dist.Color = Color3.fromRGB(170, 170, 255)
		dist.Size = 12
		dist.Center = true
		dist.Outline = true
		dist.OutlineColor = Color3.fromRGB(0, 0, 0)
		dist.Visible = false

		local healthBg = Drawing.new("Line")
		healthBg.Color = Color3.fromRGB(40, 40, 40)
		healthBg.Thickness = 3
		healthBg.Visible = false

		local health = Drawing.new("Line")
		health.Color = Color3.fromRGB(80, 255, 80)
		health.Thickness = 2
		health.Visible = false

		return {box = box, name = name, dist = dist, health = health, healthBg = healthBg}
	end)
	if ok and objs then
		espState.drawingEspObjects[player] = objs
		return objs
	end
	return nil
end

F.startDrawingEsp = function()
	if not Drawing then
		addLog("[ESP+] Drawing API not available!", COLORS.error)
		return
	end

	espState.drawingEspConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			local myChar = LocalPlayer.Character
			local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
			local cam = workspace.CurrentCamera

			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					local objs = F.getDrawingObjects(player)
					if objs then

					local character = player.Character
					if not character or not character.Parent then
						if objs.box then objs.box.Visible = false end
						if objs.name then objs.name.Visible = false end
						if objs.dist then objs.dist.Visible = false end
						if objs.health then objs.health.Visible = false end
						if objs.healthBg then objs.healthBg.Visible = false end
					else
						local hrp = character:FindFirstChild("HumanoidRootPart")
						local head = character:FindFirstChild("Head")
						local humanoid = character:FindFirstChildOfClass("Humanoid")
						if not hrp or not head then
							objs.box.Visible = false
							objs.name.Visible = false
							objs.dist.Visible = false
							objs.health.Visible = false
							objs.healthBg.Visible = false
						else
							local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
							if not onScreen then
								objs.box.Visible = false
								objs.name.Visible = false
								objs.dist.Visible = false
								objs.health.Visible = false
								objs.healthBg.Visible = false
							else
								-- Calculate box size based on distance
								local distance = pos.Z
								local scaleFactor = 1 / distance * 1000
								local boxW = 4.5 * scaleFactor
								local boxH = 6 * scaleFactor

								local screenPos = Vector2.new(pos.X, pos.Y)

								-- Box corners
								objs.box.PointA = Vector2.new(screenPos.X - boxW / 2, screenPos.Y - boxH / 2)
								objs.box.PointB = Vector2.new(screenPos.X + boxW / 2, screenPos.Y - boxH / 2)
								objs.box.PointC = Vector2.new(screenPos.X + boxW / 2, screenPos.Y + boxH / 2)
								objs.box.PointD = Vector2.new(screenPos.X - boxW / 2, screenPos.Y + boxH / 2)
								objs.box.Color = espState.OUTLINE_COLOR
								objs.box.Visible = true

								-- Name above box
								objs.name.Text = player.DisplayName
								objs.name.Position = Vector2.new(screenPos.X, screenPos.Y - boxH / 2 - 16)
								objs.name.Visible = true

								-- Distance below box
								local studs = myRoot and math.floor((myRoot.Position - hrp.Position).Magnitude) or 0
								objs.dist.Text = "[" .. studs .. "m]"
								objs.dist.Position = Vector2.new(screenPos.X, screenPos.Y + boxH / 2 + 4)
								objs.dist.Visible = true

								-- Health bar on left side
								if humanoid then
									local hp = humanoid.Health
									local maxHp = humanoid.MaxHealth
									local pct = (maxHp > 0) and (hp / maxHp) or 0
									if pct < 0 then pct = 0 end
									if pct > 1 then pct = 1 end

									local barX = screenPos.X - boxW / 2 - 5
									local barTop = screenPos.Y - boxH / 2
									local barBot = screenPos.Y + boxH / 2
									local barH = barBot - barTop

									objs.healthBg.From = Vector2.new(barX, barTop)
									objs.healthBg.To = Vector2.new(barX, barBot)
									objs.healthBg.Visible = true

									objs.health.From = Vector2.new(barX, barBot - barH * pct)
									objs.health.To = Vector2.new(barX, barBot)
									if pct > 0.5 then
										objs.health.Color = Color3.fromRGB(80, 255, 80)
									elseif pct > 0.25 then
										objs.health.Color = Color3.fromRGB(255, 200, 0)
									else
										objs.health.Color = Color3.fromRGB(255, 50, 50)
									end
									objs.health.Visible = true
								end
							end
						end
					end
					end -- if objs
				end
			end

			-- Hide objects for players who left
			for player, objs in pairs(espState.drawingEspObjects) do
				if not player or not player.Parent then
					pcall(function()
						objs.box.Visible = false
						objs.name.Visible = false
						objs.dist.Visible = false
						objs.health.Visible = false
						objs.healthBg.Visible = false
					end)
				end
			end
		end)
	end)
	addLog("[ESP+] Drawing ESP ON - infinite range!", COLORS.success)
end

F.stopDrawingEsp = function()
	if espState.drawingEspConnection then
		espState.drawingEspConnection:Disconnect()
		espState.drawingEspConnection = nil
	end
	F.clearDrawingEsp()
	addLog("[ESP+] Drawing ESP OFF", COLORS.error)
end

-- ===================== FLY LOGIC =====================
F.startFly = function()
	local character = LocalPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChild("Humanoid")
	if not hrp then return end

	-- Save and set PlatformStand to prevent normal physics
	if hum then
		flyState.savedPlatformStand = hum.PlatformStand
		hum.PlatformStand = true
	end

	-- Try modern LinearVelocity + AlignOrientation first
	local useModern = false
	pcall(function()
		-- Create attachment for constraints
		flyState.flyAttachment = hrp:FindFirstChild("RootAttachment") or Instance.new("Attachment", hrp)

		flyState.linearVelocity = Instance.new("LinearVelocity")
		flyState.linearVelocity.MaxForce = math.huge
		flyState.linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		flyState.linearVelocity.Attachment0 = flyState.flyAttachment
		flyState.linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		flyState.linearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
		flyState.linearVelocity.Parent = hrp

		flyState.alignOrientation = Instance.new("AlignOrientation")
		flyState.alignOrientation.MaxTorque = math.huge
		flyState.alignOrientation.Responsiveness = 200
		flyState.alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		flyState.alignOrientation.Attachment0 = flyState.flyAttachment
		flyState.alignOrientation.CFrame = workspace.CurrentCamera.CFrame
		flyState.alignOrientation.Parent = hrp

		useModern = true
	end)

	-- Fallback to legacy BodyGyro + BodyVelocity
	if not useModern then
		pcall(function()
			flyState.bodyGyro = Instance.new("BodyGyro")
			flyState.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			flyState.bodyGyro.P = 9e4
			flyState.bodyGyro.Parent = hrp
			flyState.bodyVelocity = Instance.new("BodyVelocity")
			flyState.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			flyState.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
			flyState.bodyVelocity.Parent = hrp
		end)
	end

	-- Mobile: create fly up/down buttons
	if isMobile then
		local flyUpBtn = Instance.new("TextButton")
		flyUpBtn.Name = "FlyUp"
		flyUpBtn.Size = UDim2.new(0, 60, 0, 60)
		flyUpBtn.Position = UDim2.new(1, -80, 1, -180)
		flyUpBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		flyUpBtn.BackgroundTransparency = 0.3
		flyUpBtn.Text = "UP"
		flyUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		flyUpBtn.Font = Enum.Font.GothamBold
		flyUpBtn.TextSize = 14
		flyUpBtn.Parent = screenGui
		addCorner(flyUpBtn, 8)
		flyState.flyUpBtn = flyUpBtn

		local flyDownBtn = Instance.new("TextButton")
		flyDownBtn.Name = "FlyDown"
		flyDownBtn.Size = UDim2.new(0, 60, 0, 60)
		flyDownBtn.Position = UDim2.new(1, -80, 1, -110)
		flyDownBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		flyDownBtn.BackgroundTransparency = 0.3
		flyDownBtn.Text = "DOWN"
		flyDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		flyDownBtn.Font = Enum.Font.GothamBold
		flyDownBtn.TextSize = 12
		flyDownBtn.Parent = screenGui
		addCorner(flyDownBtn, 8)
		flyState.flyDownBtn = flyDownBtn

		flyState.flyUpHeld = false
		flyState.flyDownHeld = false
		flyUpBtn.MouseButton1Down:Connect(function() flyState.flyUpHeld = true end)
		flyUpBtn.MouseButton1Up:Connect(function() flyState.flyUpHeld = false end)
		flyDownBtn.MouseButton1Down:Connect(function() flyState.flyDownHeld = true end)
		flyDownBtn.MouseButton1Up:Connect(function() flyState.flyDownHeld = false end)
	end

	flyState.flyConnection = RunService.Heartbeat:Connect(function()
		if not flyState.flyEnabled or not hrp or not hrp.Parent then return end
		local cam = workspace.CurrentCamera
		local dir = Vector3.new(0, 0, 0)

		-- Keyboard input
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

		-- Mobile: read thumbstick for movement + buttons for up/down
		if isMobile then
			local hum = character:FindFirstChildOfClass("Humanoid")
			local moveDir = hum and hum.MoveDirection or Vector3.zero
			if moveDir.Magnitude > 0.1 then
				dir = dir + cam.CFrame.LookVector * moveDir.Z * -1 + cam.CFrame.RightVector * moveDir.X
			end
			if flyState.flyUpHeld then dir = dir + Vector3.new(0, 1, 0) end
			if flyState.flyDownHeld then dir = dir - Vector3.new(0, 1, 0) end
		end

		if dir.Magnitude > 0 then dir = dir.Unit end
		local vel = dir * flyState.flySpeed

		if flyState.linearVelocity then
			flyState.linearVelocity.VectorVelocity = vel
		end
		if flyState.alignOrientation then
			flyState.alignOrientation.CFrame = cam.CFrame
		end
		if flyState.bodyVelocity then
			flyState.bodyVelocity.Velocity = vel
		end
		if flyState.bodyGyro then
			flyState.bodyGyro.CFrame = cam.CFrame
		end
	end)
	addLog("[FLY] ON - Speed: " .. flyState.flySpeed, COLORS.success)
end

F.stopFly = function()
	if flyState.flyConnection then flyState.flyConnection:Disconnect() flyState.flyConnection = nil end
	if flyState.linearVelocity then pcall(function() flyState.linearVelocity:Destroy() end) flyState.linearVelocity = nil end
	if flyState.alignOrientation then pcall(function() flyState.alignOrientation:Destroy() end) flyState.alignOrientation = nil end
	if flyState.bodyGyro then pcall(function() flyState.bodyGyro:Destroy() end) flyState.bodyGyro = nil end
	if flyState.bodyVelocity then pcall(function() flyState.bodyVelocity:Destroy() end) flyState.bodyVelocity = nil end
	flyState.flyAttachment = nil
	-- Remove mobile fly buttons
	if flyState.flyUpBtn then pcall(function() flyState.flyUpBtn:Destroy() end) flyState.flyUpBtn = nil end
	if flyState.flyDownBtn then pcall(function() flyState.flyDownBtn:Destroy() end) flyState.flyDownBtn = nil end
	-- Restore PlatformStand
	local character = LocalPlayer.Character
	if character then
		local hum = character:FindFirstChild("Humanoid")
		if hum then hum.PlatformStand = flyState.savedPlatformStand or false end
	end
	addLog("[FLY] OFF", COLORS.error)
end

-- ===================== ANTI FLING LOGIC =====================
local FLING_VEL_THRESHOLD = 120
local FLING_ANGULAR_THRESHOLD = 50

F.startAntiFling = function()
	if combatState.antiFlingConnection then combatState.antiFlingConnection:Disconnect() combatState.antiFlingConnection = nil end
	combatState.antiFlingLastPos = nil
	combatState.antiFlingConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end

			-- Save safe position periodically
			local vel = hrp.AssemblyLinearVelocity
			local angVel = hrp.AssemblyAngularVelocity
			local speed = vel.Magnitude
			local angSpeed = angVel.Magnitude

			if speed < FLING_VEL_THRESHOLD and angSpeed < FLING_ANGULAR_THRESHOLD then
				combatState.antiFlingLastPos = hrp.CFrame
			end

			-- Detect fling: abnormally high velocity or angular velocity
			if speed > FLING_VEL_THRESHOLD or angSpeed > FLING_ANGULAR_THRESHOLD then
				-- Zero out all velocity
				hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				hrp.Velocity = Vector3.new(0, 0, 0)
				hrp.RotVelocity = Vector3.new(0, 0, 0)

				-- Teleport back to last safe position
				if combatState.antiFlingLastPos then
					hrp.CFrame = combatState.antiFlingLastPos
				end

				-- Remove any BodyMovers someone may have inserted
				for _, obj in ipairs(hrp:GetChildren()) do
					if obj:IsA("BodyAngularVelocity") or obj:IsA("BodyVelocity") or obj:IsA("BodyForce") or obj:IsA("BodyThrust") then
						if obj.Name ~= "FlyGyro" and obj.Name ~= "FlyVelocity" then
							obj:Destroy()
						end
					end
				end
			end
		end)
	end)
	addLog("[ANTI FLING] ON", COLORS.success)
end

F.stopAntiFling = function()
	if combatState.antiFlingConnection then combatState.antiFlingConnection:Disconnect() combatState.antiFlingConnection = nil end
	combatState.antiFlingLastPos = nil
	addLog("[ANTI FLING] OFF", COLORS.error)
end

-- ===================== NOCLIP LOGIC =====================
F.startNoclip = function()
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

F.stopNoclip = function()
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

-- ===================== GET VEHICLE HELPER =====================
F.getVehicle = function()
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
F.startCarNoclip = function()
	moveState.carNoclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local vehicle, vPart = F.getVehicle()
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

F.stopCarNoclip = function()
	if moveState.carNoclipConnection then moveState.carNoclipConnection:Disconnect() moveState.carNoclipConnection = nil end
	pcall(function()
		local vehicle, vPart = F.getVehicle()
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

-- ===================== CAR SPEED BOOST =====================
F.startCarSpeed = function()
	local char = LocalPlayer.Character
	if not char then addLog("[CAR SPEED] No character!", COLORS.error) return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or not hum.SeatPart then
		addLog("[CAR SPEED] Sit in a vehicle first!", COLORS.error)
		return
	end
	local seat = hum.SeatPart

	-- Save originals
	if seat:IsA("VehicleSeat") then
		moveState.carSpeedOrigMaxSpeed = seat.MaxSpeed
		moveState.carSpeedOrigTorque = seat.Torque
		seat.MaxSpeed = moveState.carSpeedValue
		seat.Torque = seat.Torque * (moveState.carSpeedValue / (moveState.carSpeedOrigMaxSpeed > 0 and moveState.carSpeedOrigMaxSpeed or 50))
	end

	-- Heartbeat: keep applying speed + add thrust via AssemblyLinearVelocity for non-VehicleSeat seats
	moveState.carSpeedConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local c = LocalPlayer.Character
			if not c then return end
			local h = c:FindFirstChildOfClass("Humanoid")
			if not h or not h.SeatPart then return end
			local s = h.SeatPart

			if s:IsA("VehicleSeat") then
				-- Keep MaxSpeed updated if slider changes
				s.MaxSpeed = moveState.carSpeedValue
			else
				-- For regular Seats (planes, boats, etc), apply velocity boost
				local vehicle = s.Parent
				if vehicle then
					local primary = (vehicle:IsA("Model") and vehicle.PrimaryPart) or s
					local look = primary.CFrame.LookVector
					local currentSpeed = primary.AssemblyLinearVelocity:Dot(look)
					if currentSpeed < moveState.carSpeedValue then
						primary.AssemblyLinearVelocity = primary.AssemblyLinearVelocity + look * 2
					end
				end
			end
		end)
	end)
	addLog("[CAR SPEED] ON - Speed: " .. moveState.carSpeedValue, COLORS.success)
end

F.stopCarSpeed = function()
	if moveState.carSpeedConnection then moveState.carSpeedConnection:Disconnect() moveState.carSpeedConnection = nil end
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
			if moveState.carSpeedOrigMaxSpeed then hum.SeatPart.MaxSpeed = moveState.carSpeedOrigMaxSpeed end
			if moveState.carSpeedOrigTorque then hum.SeatPart.Torque = moveState.carSpeedOrigTorque end
		end
	end)
	moveState.carSpeedOrigMaxSpeed = nil
	moveState.carSpeedOrigTorque = nil
	addLog("[CAR SPEED] OFF", COLORS.error)
end

-- ===================== BACKSEAT DRIVE LOGIC =====================
-- Direct physics control: apply velocity + angular velocity to vehicle from any seat
F.startBackseatDrive = function()
	local char = LocalPlayer.Character
	if not char then addLog("[BACKSEAT] No character!", COLORS.error) return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or not hum.SeatPart then
		addLog("[BACKSEAT] Sit in a vehicle first!", COLORS.error)
		return
	end

	local mySeat = hum.SeatPart
	-- Walk up to find the vehicle model
	local vehicle = mySeat.Parent
	while vehicle and not vehicle:IsA("Model") do
		vehicle = vehicle.Parent
	end
	if not vehicle or vehicle == workspace then
		addLog("[BACKSEAT] Could not find vehicle model!", COLORS.error)
		return
	end

	-- Find the main part to apply forces to (PrimaryPart or VehicleSeat or our seat)
	local drivePart = vehicle.PrimaryPart
	if not drivePart then
		for _, part in ipairs(vehicle:GetDescendants()) do
			if part:IsA("VehicleSeat") then
				drivePart = part
				break
			end
		end
	end
	if not drivePart then drivePart = mySeat end

	local driveSpeed = moveState.backseatDriveSpeed or 80
	local turnSpeed = moveState.backseatDriveTurn or 3

	moveState.backseatDriveConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local c = LocalPlayer.Character
			if not c then return end
			local h = c:FindFirstChildOfClass("Humanoid")
			if not h or not h.SeatPart then return end
			if not drivePart or not drivePart.Parent then return end

			local throttle = 0
			local steer = 0

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then throttle = throttle + 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then throttle = throttle - 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then steer = steer - 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then steer = steer + 1 end

			-- Apply forward/backward velocity along the vehicle's look direction
			if throttle ~= 0 then
				local lookDir = drivePart.CFrame.LookVector
				local currentVel = drivePart.AssemblyLinearVelocity
				local targetVel = lookDir * throttle * driveSpeed
				-- Keep existing Y velocity (gravity) and blend horizontal
				drivePart.AssemblyLinearVelocity = Vector3.new(targetVel.X, currentVel.Y, targetVel.Z)
			end

			-- Apply steering via angular velocity (Y-axis rotation)
			if steer ~= 0 then
				drivePart.AssemblyAngularVelocity = Vector3.new(0, -steer * turnSpeed, 0)
			else
				-- Dampen angular velocity when not steering
				local av = drivePart.AssemblyAngularVelocity
				drivePart.AssemblyAngularVelocity = Vector3.new(av.X, av.Y * 0.8, av.Z)
			end
		end)
	end)
	addLog("[BACKSEAT] ON - WASD to drive from any seat!", COLORS.success)
end

F.stopBackseatDrive = function()
	if moveState.backseatDriveConnection then
		moveState.backseatDriveConnection:Disconnect()
		moveState.backseatDriveConnection = nil
	end
	addLog("[BACKSEAT] OFF", COLORS.error)
end

-- ===================== SPIN FLING LOGIC =====================
-- Exact Infinite Yield method: density 100 + noclip + BAV + massless + pulse on/off

F.startFling = function()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Step 1: density 100 on all parts
		flingState.savedPhysProps = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				flingState.savedPhysProps[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
			end
		end

		-- Step 2: enable noclip
		if not moveState.noclipEnabled then
			moveState.noclipEnabled = true
			F.startNoclip()
			flingState.flingAutoNoclip = true
		end
		wait(0.1)

		-- Step 3: BodyAngularVelocity Y-axis spin
		local bav = Instance.new("BodyAngularVelocity")
		bav.AngularVelocity = Vector3.new(0, flingState.flingPower, 0)
		bav.MaxTorque = Vector3.new(0, math.huge, 0)
		bav.P = math.huge
		bav.Parent = root
		flingState.flingBAV = bav

		-- Step 4: massless + no collide + zero velocity on all parts
		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Massless = true
				part.Velocity = Vector3.new(0, 0, 0)
			end
		end

		-- Step 5: pulse spin on/off (creates repeated impulse spikes)
		flingState.flingEnabled = true
		spawn(function()
			while flingState.flingEnabled do
				if flingState.flingBAV and flingState.flingBAV.Parent then
					flingState.flingBAV.AngularVelocity = Vector3.new(0, flingState.flingPower, 0)
				end
				wait(0.2)
				if flingState.flingBAV and flingState.flingBAV.Parent then
					flingState.flingBAV.AngularVelocity = Vector3.new(0, 0, 0)
				end
				wait(0.1)
			end
		end)

		addLog("[SPIN FLING] ON - Players near you get flung!", COLORS.success)
	end)
	if not ok then
		addLog("[SPIN FLING] Error: " .. tostring(err), COLORS.error)
	end
end

F.stopFling = function()
	flingState.flingEnabled = false
	if flingState.flingBAV then pcall(function() flingState.flingBAV:Destroy() end) flingState.flingBAV = nil end

	-- Disable auto-noclip if we enabled it
	if flingState.flingAutoNoclip then
		moveState.noclipEnabled = false
		F.stopNoclip()
		flingState.flingAutoNoclip = false
	end

	pcall(function()
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
				end
			end
		end
	end)
	flingState.savedPhysProps = {}
	addLog("[SPIN FLING] OFF", COLORS.error)
end

-- ===================== CAR FLING LOGIC =====================
-- Heavy vehicle + BodyAngularVelocity spin = drive into players to fling them
F.startCarFling = function()
	local ok, err = pcall(function()
		local vehicle, vPart = F.getVehicle()
		if not vPart then
			addLog("[CAR FLING] Sit in a vehicle first!", COLORS.error)
			return
		end

		-- Make vehicle + character super dense
		flingState.carFlingOrigProps = {}
		for _, part in ipairs(vehicle:GetDescendants()) do
			if part:IsA("BasePart") then
				flingState.carFlingOrigProps[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
			end
		end
		local character = LocalPlayer.Character
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					flingState.carFlingOrigProps[part] = part.CustomPhysicalProperties
					part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
				end
			end
		end

		-- BodyAngularVelocity on vehicle seat part
		local bav = Instance.new("BodyAngularVelocity")
		bav.AngularVelocity = Vector3.new(0, flingState.carFlingPower, 0)
		bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bav.P = math.huge
		bav.Parent = vPart
		flingState.carFlingBAV = bav

		-- Heartbeat: update BAV power + re-parent if removed
		flingState.carFlingConnection = RunService.Heartbeat:Connect(function()
			pcall(function()
				if flingState.carFlingBAV then
					flingState.carFlingBAV.AngularVelocity = Vector3.new(0, flingState.carFlingPower, 0)
				end
				local v, vp = F.getVehicle()
				if vp and flingState.carFlingBAV and not flingState.carFlingBAV.Parent then
					flingState.carFlingBAV.Parent = vp
				end
			end)
		end)

		addLog("[CAR FLING] ON - Drive into players!", COLORS.success)
	end)
	if not ok then
		addLog("[CAR FLING] Error: " .. tostring(err), COLORS.error)
	end
end

F.stopCarFling = function()
	if flingState.carFlingConnection then
		flingState.carFlingConnection:Disconnect()
		flingState.carFlingConnection = nil
	end
	if flingState.carFlingBAV then pcall(function() flingState.carFlingBAV:Destroy() end) flingState.carFlingBAV = nil end

	-- Restore physics properties
	pcall(function()
		for part, props in pairs(flingState.carFlingOrigProps) do
			if part and part.Parent then
				if props then
					part.CustomPhysicalProperties = props
				else
					part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
				end
				part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end
		end
	end)
	flingState.carFlingOrigProps = {}

	addLog("[CAR FLING] OFF", COLORS.error)
end

-- ===================== WALK FLING LOGIC =====================
-- Exact Infinite Yield method: noclip + velocity spike each frame
-- No spin, just massive velocity spikes that get restored next frame

F.startWalkFling = function()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Enable noclip
		if not moveState.noclipEnabled then
			moveState.noclipEnabled = true
			F.startNoclip()
			flingState.walkFlingAutoNoclip = true
		end

		flingState.walkFlingEnabled = true
		local movel = 0.1

		-- Velocity spike loop (runs across Heartbeat/RenderStepped/Stepped)
		spawn(function()
			while flingState.walkFlingEnabled do
				local char = LocalPlayer.Character
				local rt = char and char:FindFirstChild("HumanoidRootPart")
				if not (char and char.Parent and rt and rt.Parent) then
					RunService.Heartbeat:Wait()
				else
					-- Save current velocity, spike horizontal only (no Y = no flying up)
					local vel = rt.Velocity
					local spiked = Vector3.new(vel.X * 10000, vel.Y, vel.Z * 10000)
					rt.Velocity = spiked

					RunService.RenderStepped:Wait()
					-- Restore original velocity
					if char and char.Parent and rt and rt.Parent then
						rt.Velocity = vel
					end

					RunService.Stepped:Wait()
					-- Tiny Y oscillation to maintain ground contact
					if char and char.Parent and rt and rt.Parent then
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

F.stopWalkFling = function()
	flingState.walkFlingEnabled = false

	-- Disable auto-noclip if we enabled it
	if flingState.walkFlingAutoNoclip then
		moveState.noclipEnabled = false
		F.stopNoclip()
		flingState.walkFlingAutoNoclip = false
	end

	addLog("[WALK FLING] OFF", COLORS.error)
end

-- ===================== SPEED LOGIC =====================
F.startSpeed = function()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then moveState.origWalkSpeed = humanoid.WalkSpeed humanoid.WalkSpeed = moveState.speedValue end
		end
	end)
	addLog("[SPEED] ON - WalkSpeed: " .. moveState.speedValue, COLORS.success)
end

F.stopSpeed = function()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.WalkSpeed = moveState.origWalkSpeed end
		end
	end)
	addLog("[SPEED] OFF", COLORS.error)
end

-- ===================== GOD MODE LOGIC =====================
F.startGod = function()
	combatState.godConnection = RunService.Heartbeat:Connect(function()
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

F.stopGod = function()
	if combatState.godConnection then combatState.godConnection:Disconnect() combatState.godConnection = nil end
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
F.startInfJump = function()
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

F.stopInfJump = function()
	if moveState.infJumpConnection then moveState.infJumpConnection:Disconnect() moveState.infJumpConnection = nil end
	addLog("[INF JUMP] OFF", COLORS.error)
end

-- ===================== KILL AURA LOGIC =====================
F.startKillAura = function()
	combatState.killAuraConnection = RunService.Heartbeat:Connect(function()
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

F.stopKillAura = function()
	if combatState.killAuraConnection then combatState.killAuraConnection:Disconnect() combatState.killAuraConnection = nil end
	addLog("[KILL AURA] OFF", COLORS.error)
end

-- ===================== INVISIBLE LOGIC =====================
funState.savedTransparencies = {}
funState.fakeCharacter = nil
funState.invisPosLoop = nil

F.startInvisible = function()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		local savedCF = hrp.CFrame

		-- FE Invisible: character swap method
		-- Create fake character model hidden under the map
		local fakeChar = Instance.new("Model")
		fakeChar.Name = LocalPlayer.Name

		local fakeHRP = Instance.new("Part")
		fakeHRP.Name = "HumanoidRootPart"
		fakeHRP.Size = Vector3.new(2, 2, 1)
		fakeHRP.Transparency = 1
		fakeHRP.CanCollide = false
		fakeHRP.Anchored = true
		fakeHRP.CFrame = CFrame.new(0, -3000, 0)
		fakeHRP.Parent = fakeChar

		local fakeHum = Instance.new("Humanoid")
		fakeHum.Parent = fakeChar
		fakeChar.Parent = workspace

		-- Step 1: Nil character to break server replication
		LocalPlayer.Character = nil
		_wait(0.1)

		-- Step 2: Assign fake character - server latches onto the fake
		LocalPlayer.Character = fakeChar
		_wait(0.5)

		-- Step 3: Swap back to real character
		-- Server still tracks the fake, our real movements aren't replicated
		LocalPlayer.Character = character
		_wait(0.1)

		-- Restore position
		if hrp and hrp.Parent then hrp.CFrame = savedCF end

		-- Keep fake alive (don't destroy it or server reconnects to real char)
		funState.fakeCharacter = fakeChar

		-- Keep real character anchored at position to prevent server drift
		-- Use a loop to re-apply CFrame if server tries to correct
		if funState.invisPosLoop then funState.invisPosLoop:Disconnect() end
		funState.invisPosLoop = RunService.Heartbeat:Connect(function()
			pcall(function()
				if funState.fakeCharacter and funState.fakeCharacter.Parent then
					-- Keep fake HRP under map
					local fHRP = funState.fakeCharacter:FindFirstChild("HumanoidRootPart")
					if fHRP then fHRP.CFrame = CFrame.new(0, -3000, 0) end
				end
			end)
		end)

		-- Apply client-side transparency so we can't see ourselves
		funState.savedTransparencies = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				funState.savedTransparencies[part] = part.Transparency
				part.Transparency = 1
			elseif part:IsA("Decal") or part:IsA("Texture") then
				funState.savedTransparencies[part] = part.Transparency
				part.Transparency = 1
			end
		end
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				if handle then funState.savedTransparencies[handle] = handle.Transparency handle.Transparency = 1 end
			end
		end
	end)
	addLog("[INVISIBLE] ON (FE invisible)", COLORS.success)
end

F.stopInvisible = function()
	pcall(function()
		-- Stop position loop
		if funState.invisPosLoop then funState.invisPosLoop:Disconnect() funState.invisPosLoop = nil end

		-- Restore client transparency
		for part, transparency in pairs(funState.savedTransparencies) do
			if part and part.Parent then part.Transparency = transparency end
		end
		funState.savedTransparencies = {}

		-- Destroy fake character so server reconnects to real char
		if funState.fakeCharacter and funState.fakeCharacter.Parent then
			funState.fakeCharacter:Destroy()
		end
		funState.fakeCharacter = nil

		-- Respawn to fully restore server replication
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
F.startSpin = function()
	funState.spinConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local character = LocalPlayer.Character
			if not character then return end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(15), 0) end
		end)
	end)
	addLog("[SPIN] ON", COLORS.success)
end

F.stopSpin = function()
	if funState.spinConnection then funState.spinConnection:Disconnect() funState.spinConnection = nil end
	addLog("[SPIN] OFF", COLORS.error)
end

-- ===================== SEIZURE LOGIC =====================
F.startSeizure = function()
	funState.seizureConnection = RunService.Heartbeat:Connect(function()
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

F.stopSeizure = function()
	if funState.seizureConnection then funState.seizureConnection:Disconnect() funState.seizureConnection = nil end
	addLog("[SEIZURE] OFF", COLORS.error)
end

-- ===================== EMOTE LOGIC =====================
F.stopEmote = function()
	funState.emoteActive = false
	if funState.emoteConnection then funState.emoteConnection:Disconnect() funState.emoteConnection = nil end
	for _, track in ipairs(funState.emoteTracks) do
		pcall(function() track:Stop() end)
	end
	funState.emoteTracks = {}
end

F.playEmote = function(animId, speed, duration)
	F.stopEmote()
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
		table.insert(funState.emoteTracks, track)
		funState.emoteActive = true
		if duration then
			task.delay(duration, function()
				if funState.emoteActive then F.stopEmote() end
			end)
		end
	end)
end

F.playJerkEmote = function()
	F.stopEmote()
	pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		funState.emoteActive = true

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
			table.insert(funState.emoteTracks, track1)
			table.insert(funState.emoteTracks, track2)

			-- Loop by replaying when tracks finish
			funState.emoteConnection = RunService.Heartbeat:Connect(function()
				if not funState.emoteActive then return end
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
			-- R15 fallback: Bug Net swing looped at suggestive time range
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://698251653"
			local track = hum:LoadAnimation(anim)
			track:Play()
			track:AdjustSpeed(0.4)
			table.insert(funState.emoteTracks, track)

			funState.emoteConnection = RunService.Heartbeat:Connect(function()
				if not funState.emoteActive then return end
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

-- ===================== VEHICLE FLY =====================
F.startVehicleFly = function()
	local vehicle, part = F.getVehicle()
	if not part then
		addLog("[VFLY] Sit in a vehicle first!", COLORS.error)
		return
	end

	pcall(function()
		for _, obj in ipairs(part.Parent:GetDescendants()) do
			if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") or obj:IsA("BodyPosition") then
				if obj.Name ~= "SX_VFly_BV" and obj.Name ~= "SX_VFly_BG" then
					obj:Destroy()
				end
			end
		end
		for _, obj in ipairs(part.Parent:GetDescendants()) do
			if obj:IsA("BasePart") then obj.Anchored = false end
		end
	end)

	flyState.vehicleFlyBV = Instance.new("BodyVelocity")
	flyState.vehicleFlyBV.Name = "SX_VFly_BV"
	flyState.vehicleFlyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyState.vehicleFlyBV.Velocity = Vector3.new(0, 0, 0)
	flyState.vehicleFlyBV.P = 9000
	flyState.vehicleFlyBV.Parent = part

	flyState.vehicleFlyBG = Instance.new("BodyGyro")
	flyState.vehicleFlyBG.Name = "SX_VFly_BG"
	flyState.vehicleFlyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flyState.vehicleFlyBG.P = 9000
	flyState.vehicleFlyBG.CFrame = part.CFrame
	flyState.vehicleFlyBG.Parent = part

	flyState.vehicleFlyConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not flyState.vehicleFlyBV or not flyState.vehicleFlyBV.Parent then return end
			local cam = workspace.CurrentCamera
			local moveVec = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + cam.CFrame.UpVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - cam.CFrame.UpVector end
			flyState.vehicleFlyBV.Velocity = moveVec.Magnitude > 0 and moveVec.Unit * flyState.flySpeed or Vector3.zero
			flyState.vehicleFlyBG.CFrame = cam.CFrame
		end)
	end)
	addLog("[VFLY] Vehicle fly ON", COLORS.success)
end

F.stopVehicleFly = function()
	if flyState.vehicleFlyConnection then flyState.vehicleFlyConnection:Disconnect() flyState.vehicleFlyConnection = nil end
	if flyState.vehicleFlyBV then pcall(function() flyState.vehicleFlyBV:Destroy() end) flyState.vehicleFlyBV = nil end
	if flyState.vehicleFlyBG then pcall(function() flyState.vehicleFlyBG:Destroy() end) flyState.vehicleFlyBG = nil end
	addLog("[VFLY] Vehicle fly OFF", COLORS.error)
end

-- ===================== TELEPORT / SPECTATE =====================
F.teleportToPlayer = function(targetPlayer)
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

playerState.spectating = false

F.spectatePlayer = function(targetPlayer)
	pcall(function()
		if targetPlayer and targetPlayer.Character then
			local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				workspace.CurrentCamera.CameraSubject = humanoid
				playerState.spectating = true
				addLog("[SPECTATE] Watching " .. targetPlayer.DisplayName, COLORS.success)
			end
		end
	end)
end

F.unspectate = function()
	pcall(function()
		local myChar = LocalPlayer.Character
		if myChar then
			local humanoid = myChar:FindFirstChildOfClass("Humanoid")
			if humanoid then workspace.CurrentCamera.CameraSubject = humanoid end
		end
		playerState.spectating = false
		addLog("[SPECTATE] Stopped", COLORS.error)
	end)
end

F.setJumpPower = function(value)
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.UseJumpPower = true humanoid.JumpPower = value end
		end
	end)
end

F.setGravity = function(value)
	pcall(function() workspace.Gravity = value end)
end

-- ===================== SERVER FUNCTIONS =====================
F.rejoinServer = function()
	pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
	addLog("[SERVER] Rejoining...", COLORS.accent)
end

F.respawnCharacter = function()
	-- Kills the character so the server respawns it. Works wherever
	-- CharacterAutoLoads is left on, which is the default. Breaking the root's
	-- joints is more reliable than Health=0 alone against god-mode style loops
	-- that pin health, so both are done.
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = 0 end
		local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		if root then root:BreakJoints() end
	end)
	addLog("[RESPAWN] Respawning character...", COLORS.accent)
end

F.serverHop = function()
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

-- Functions defined below use F table (declared at top of file)

-- ===================== BUILD MAIN TAB =====================
do
	local tab = tabFrames["Main"]

	createSectionLabel(tab, "Welcome", 1)
	createInfoLabel(tab, "Pebbleford Hub v3.1", 2)
	createInfoLabel(tab, "Player: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")", 3)


	createSectionLabel(tab, "Quick Toggles", 5)

	createToggle(tab, "ESP", 6, function(on)
		espState.espEnabled = on
		if on then F.enableESP() else F.disableESP() end
	end)
	createToggle(tab, "Fly", 7, function(on)
		flyState.flyEnabled = on
		if on then F.startFly() else F.stopFly() end
	end)
	createToggle(tab, "Noclip", 8, function(on)
		moveState.noclipEnabled = on
		if on then F.startNoclip() else F.stopNoclip() end
	end)
	createToggle(tab, "God Mode", 9, function(on)
		combatState.godEnabled = on
		if on then F.startGod() else F.stopGod() end
	end)
	createToggle(tab, "Infinite Jump", 10, function(on)
		moveState.infJumpEnabled = on
		if on then F.startInfJump() else F.stopInfJump() end
	end)


	createSectionLabel(tab, "Output Log", 12)

	createInfoLabel(tab, "Output goes to notifications and the F9 console.", 13)
end

-- ===================== BUILD PLAYER TAB =====================
local playerListFrame
local playerButtons = {}
local selectedPlayerLabel

do
	local tab = tabFrames["Player"]

	createSectionLabel(tab, "Selected Player", 1)

	selectedPlayerLabel = createDynamicLabel(tab, "None selected")

	createSectionLabel(tab, "Actions", 3)

	createActionButton(tab, "Teleport to Player", 4, function()
		if playerState.selectedPlayer then F.teleportToPlayer(playerState.selectedPlayer)
		else addLog("[TP] No player selected", COLORS.error) end
	end)
	createActionButton(tab, "Spectate Player", 5, function()
		if playerState.selectedPlayer then F.spectatePlayer(playerState.selectedPlayer)
		else addLog("[SPECTATE] No player selected", COLORS.error) end
	end)
	createActionButton(tab, "Unspectate", 6, function() F.unspectate() end)
	createActionButton(tab, "Fling Player", 7, function()
		if not playerState.selectedPlayer or not playerState.selectedPlayer.Character then
			addLog("[FLING] No player selected", COLORS.error)
			return
		end
		local targetHRP = playerState.selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not targetHRP then
			addLog("[FLING] Target has no HumanoidRootPart", COLORS.error)
			return
		end
		local myChar = LocalPlayer.Character
		local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if not myHRP then return end

		addLog("[FLING] Flinging " .. playerState.selectedPlayer.DisplayName .. "...", COLORS.textSecondary)

		task.spawn(function()
			local savedCF = myHRP.CFrame

			-- Make character super heavy so contact launches the target
			local savedProps = {}
			for _, part in ipairs(myChar:GetDescendants()) do
				if part:IsA("BasePart") then
					savedProps[part] = part.CustomPhysicalProperties
					part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
				end
			end

			-- Spin at high angular velocity
			local spinBAVLocal = Instance.new("BodyAngularVelocity")
			spinBAVLocal.AngularVelocity = Vector3.new(0, flingState.flingPower, 0)
			spinBAVLocal.MaxTorque = Vector3.new(0, math.huge, 0)
			spinBAVLocal.P = math.huge
			spinBAVLocal.Parent = myHRP

			-- Ram into target for 2 seconds
			local startTime = tick()
			while tick() - startTime < 2 do
				pcall(function()
					if not targetHRP or not targetHRP.Parent then return end
					myHRP.CFrame = CFrame.new(targetHRP.Position)
				end)
				task.wait()
			end

			-- Cleanup
			pcall(function() spinBAVLocal:Destroy() end)
			for part, props in pairs(savedProps) do
				pcall(function()
					if props then part.CustomPhysicalProperties = props
					else part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5) end
				end)
			end

			task.wait(0.2)
			pcall(function() myHRP.CFrame = savedCF end)
			addLog("[FLING] Flung " .. playerState.selectedPlayer.DisplayName .. "!", COLORS.success)
		end)
	end)

	createToggle(tab, "Kill Aura", 8, function(on)
		combatState.killAuraEnabled = on
		if on then F.startKillAura() else F.stopKillAura() end
	end)


	
	createSpacer(tab, 20)
	createSectionLabel(tab, "Player Loops", 21)
	createToggle(tab, "Orbit", 22, function(on)
		playerState.orbitEnabled = on
		if on then F.startOrbit() else F.stopOrbit() end
	end)
	createSlider(tab, "Orbit Radius", 5, 50, playerState.orbitRadius, 23, function(val) playerState.orbitRadius = val end)
	createToggle(tab, "Attach", 24, function(on)
		playerState.attachEnabled = on
		if on then F.startAttach() else F.stopAttach() end
	end)
	createToggle(tab, "Follow", 25, function(on)
		playerState.followEnabled = on
		if on then F.startFollow() else F.stopFollow() end
	end)
	createToggle(tab, "Stare", 26, function(on)
		playerState.stareEnabled = on
		if on then F.startStare() else F.stopStare() end
	end)
	createActionButton(tab, "TP Behind", 27, function() F.tpBehindPlayer() end)
	createActionButton(tab, "Player Info", 28, function() F.showPlayerInfo() end)

	createSectionLabel(tab, "Player List", 10)

	playerDropdown = createDropdown(tab, "Select Player", {"(refresh first)"}, "(refresh first)", function(choice)
		local player = playerLookup[choice]
		if not player then return end
		playerState.selectedPlayer = player
		selectedPlayerLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
	end)
	createActionButton(tab, "Refresh Player List", 12, function() F.refreshPlayerList() end)
end

F.refreshPlayerList = function()
	playerLookup = {}
	local names = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local label = player.DisplayName .. " (@" .. player.Name .. ")"
			playerLookup[label] = player
			table.insert(names, label)
		end
	end
	if #names == 0 then names = {"(no players)"} end
	if playerDropdown then pcall(function() playerDropdown:Refresh(names) end) end
end
Players.PlayerAdded:Connect(function() _wait(0.5) F.refreshPlayerList() end)
Players.PlayerRemoving:Connect(function(player)
	if playerState.selectedPlayer == player then
		playerState.selectedPlayer = nil
		selectedPlayerLabel.Text = "None selected"
	end
	_wait(0.1) F.refreshPlayerList()
end)
F.refreshPlayerList()

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


	createSectionLabel(tab, "Actions", 6)
	createActionButton(tab, "Respawn Character", 6, function() F.respawnCharacter() end)
	createActionButton(tab, "Rejoin Server", 7, function() F.rejoinServer() end)
	createActionButton(tab, "Server Hop", 8, function() F.serverHop() end)

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
		espState.espEnabled = on
		if on then F.enableESP() else F.disableESP() end
	end)
	createToggle(tab, "Infinite Range ESP (Drawing)", 3, function(on)
		espState.drawingEspEnabled = on
		if on then F.startDrawingEsp() else F.stopDrawingEsp() end
	end)
	createInfoLabel(tab, "Drawing ESP has no distance limit - shows boxes + names + HP", 4)


	createSectionLabel(tab, "Fill Color", 4)

	local fillColors = {
		{Color3.fromRGB(255, 0, 0), "Red"},
		{Color3.fromRGB(0, 255, 0), "Green"},
		{Color3.fromRGB(0, 100, 255), "Blue"},
		{Color3.fromRGB(255, 102, 0), "Orange"},
	}
	do
		local byName, names = {}, {}
		for _, preset in ipairs(fillColors) do
			byName[preset[2]] = preset[1]
			table.insert(names, preset[2])
		end
		createDropdown(tab, "ESP Fill Color", names, names[1], function(choice)
			local col = byName[choice]
			if not col then return end
			espState.HIGHLIGHT_COLOR = col
			for _, hl in pairs(espState.highlights) do pcall(function() hl.FillColor = col end) end
			addLog("[ESP] Fill: " .. choice, COLORS.accent)
		end)
	end

	createSectionLabel(tab, "Outline Color", 6)

	local outlineColors = {
		{Color3.fromRGB(255, 255, 255), "White"},
		{Color3.fromRGB(255, 0, 0), "Red"},
		{Color3.fromRGB(255, 102, 0), "Orange"},
		{Color3.fromRGB(0, 255, 255), "Cyan"},
	}
	do
		local byName, names = {}, {}
		for _, preset in ipairs(outlineColors) do
			byName[preset[2]] = preset[1]
			table.insert(names, preset[2])
		end
		createDropdown(tab, "ESP Outline Color", names, names[1], function(choice)
			local col = byName[choice]
			if not col then return end
			espState.OUTLINE_COLOR = col
			for _, hl in pairs(espState.highlights) do pcall(function() hl.OutlineColor = col end) end
			addLog("[ESP] Outline: " .. choice, COLORS.accent)
		end)
	end

	createSectionLabel(tab, "Refresh", 9)
	createSlider(tab, "Interval (seconds)", 1, 30, espState.REFRESH_INTERVAL, 10, function(val)
		espState.REFRESH_INTERVAL = val
	end)

	createSpacer(tab, 30)
	createSectionLabel(tab, "Overlays", 31)
	createToggle(tab, "Tracers", 32, function(on)
		espState.tracersEnabled = on
		if on then F.startTracers() else F.stopTracers() end
	end)
	createToggle(tab, "FOV Circle", 33, function(on)
		espState.fovCircleEnabled = on
		if on then F.startFOVCircle() else F.stopFOVCircle() end
	end)
	createSlider(tab, "FOV Radius", 50, 500, espState.fovRadius, 34, function(val) espState.fovRadius = val if espState.fovCircleFrame then espState.fovCircleFrame.Radius = val end end)
	createToggle(tab, "Crosshair", 35, function(on)
		espState.crosshairEnabled = on
		if on then F.startCrosshair() else F.stopCrosshair() end
	end)
end

-- ===================== BUILD MOVEMENT TAB =====================
do
	local tab = tabFrames["Movement"]

	createSectionLabel(tab, "Flight", 1)
	createToggle(tab, "Fly", 2, function(on)
		flyState.flyEnabled = on
		if on then F.startFly() else F.stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 500, flyState.flySpeed, 3, function(val) flyState.flySpeed = val end)
	createToggle(tab, "Vehicle Fly (Sit First)", 4, function(on)
		flyState.vehicleFlyEnabled = on
		if on then F.startVehicleFly() else F.stopVehicleFly() end
	end)
	createToggle(tab, "Car Speed Boost (Sit First)", 5, function(on)
		moveState.carSpeedEnabled = on
		if on then F.startCarSpeed() else F.stopCarSpeed() end
	end)
	createSlider(tab, "Car Speed", 50, 1000, moveState.carSpeedValue, 6, function(val)
		moveState.carSpeedValue = val
	end)


	createSectionLabel(tab, "Movement", 8)
	createToggle(tab, "Speed Boost", 9, function(on)
		moveState.speedEnabled = on
		if on then F.startSpeed() else F.stopSpeed() end
	end)
	createSlider(tab, "Walk Speed", 16, 500, moveState.speedValue, 10, function(val)
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
	createToggle(tab, "Noclip", 11, function(on)
		moveState.noclipEnabled = on
		if on then F.startNoclip() else F.stopNoclip() end
	end)
	createToggle(tab, "Anti Fling", 12, function(on)
		combatState.antiFlingEnabled = on
		if on then F.startAntiFling() else F.stopAntiFling() end
	end)
	createToggle(tab, "Car Noclip (Sit First)", 13, function(on)
		moveState.carNoclipEnabled = on
		if on then F.startCarNoclip() else F.stopCarNoclip() end
	end)
	createToggle(tab, "Backseat Drive (Sit First)", 14, function(on)
		moveState.backseatDriveEnabled = on
		if on then F.startBackseatDrive() else F.stopBackseatDrive() end
	end)
	createSlider(tab, "Backseat Speed", 20, 300, moveState.backseatDriveSpeed, 15, function(val) moveState.backseatDriveSpeed = val end)


	createSectionLabel(tab, "Jumping", 17)
	createToggle(tab, "Infinite Jump", 17, function(on)
		moveState.infJumpEnabled = on
		if on then F.startInfJump() else F.stopInfJump() end
	end)
	createSlider(tab, "Jump Power", 10, 500, moveState.jumpPowerValue, 18, function(val) moveState.jumpPowerValue = val F.setJumpPower(val) end)


	createSectionLabel(tab, "World", 20)
	createSlider(tab, "Gravity", 0, 1000, math.floor(moveState.gravityValue), 21, function(val) moveState.gravityValue = val F.setGravity(val) end)

	createSpacer(tab, 22)
	createSectionLabel(tab, "Teleportation", 23)
	createToggle(tab, "Click TP (Ctrl+Click)", 24, function(on)
		moveState.clickTpEnabled = on
		if on then F.startClickTp() else F.stopClickTp() end
	end)
	createToggle(tab, "Bunny Hop (Hold W)", 25, function(on)
		moveState.bunnyHopEnabled = on
		if on then F.startBunnyHop() else F.stopBunnyHop() end
	end)
	createToggle(tab, "Float", 26, function(on)
		moveState.floatEnabled = on
		if on then F.startFloat() else F.stopFloat() end
	end)
	createToggle(tab, "Platform", 27, function(on)
		moveState.platformEnabled = on
		if on then F.startPlatform() else F.stopPlatform() end
	end)
	createActionButton(tab, "Long Jump", 28, function() F.doLongJump() end)
	createActionButton(tab, "TP Behind Selected", 29, function() F.tpBehindPlayer() end)
end

-- ===================== BUILD FUN TAB =====================
do
	local tab = tabFrames["Fun"]

	createSectionLabel(tab, "Fling", 1)
	createToggle(tab, "Spin Fling (IY Style)", 2, function(on)
		flingState.flingEnabled = on
		if on then
			if flingState.walkFlingEnabled then flingState.walkFlingEnabled = false F.stopWalkFling() end
			F.startFling()
		else F.stopFling() end
	end)
	createSlider(tab, "Spin Fling Power", 1000, 99999, flingState.flingPower, 3, function(val) flingState.flingPower = val end)
	createToggle(tab, "Walk Fling (Dinos Anim)", 4, function(on)
		flingState.walkFlingEnabled = on
		if on then
			if flingState.flingEnabled then flingState.flingEnabled = false F.stopFling() end
			F.startWalkFling()
		else F.stopWalkFling() end
	end)
	createSlider(tab, "Walk Fling Power", 1000, 50000, flingState.walkFlingPower, 5, function(val) flingState.walkFlingPower = val end)
	createToggle(tab, "Car Fling (Sit First)", 6, function(on)
		flingState.carFlingEnabled = on
		if on then
			if flingState.flingEnabled then flingState.flingEnabled = false F.stopFling() end
			if flingState.walkFlingEnabled then flingState.walkFlingEnabled = false F.stopWalkFling() end
			F.startCarFling()
		else F.stopCarFling() end
	end)
	createSlider(tab, "Car Fling Power", 1000, 99999, flingState.carFlingPower, 7, function(val) flingState.carFlingPower = val end)


	createSectionLabel(tab, "Visual Effects", 9)
	createToggle(tab, "Invisible", 10, function(on)
		funState.invisibleEnabled = on
		if on then F.startInvisible() else F.stopInvisible() end
	end)
	createToggle(tab, "Spin", 11, function(on)
		funState.spinEnabled = on
		if on then F.startSpin() else F.stopSpin() end
	end)
	createToggle(tab, "Seizure", 12, function(on)
		funState.seizureEnabled = on
		if on then F.startSeizure() else F.stopSeizure() end
	end)


	createSectionLabel(tab, "Emotes", 14)
	createActionButton(tab, "Emote 1", 15, function()
		F.playJerkEmote()
	end)
	createActionButton(tab, "Dance", 16, function()
		F.playEmote(507771019, 1, 10)
		addLog("[EMOTE] Dance!", COLORS.success)
	end)
	createActionButton(tab, "Dab", 17, function()
		F.playEmote(183412246, 1, 3)
		addLog("[EMOTE] Dab!", COLORS.success)
	end)
	createActionButton(tab, "Crouch", 18, function()
		F.playEmote(182724289, 1, nil)
		addLog("[EMOTE] Crouch (;stopemote to stop)", COLORS.success)
	end)
	createActionButton(tab, "Stop Emote", 19, function()
		F.stopEmote()
		addLog("[EMOTE] Stopped", COLORS.error)
	end)

	createActionButton(tab, "T-Pose", 30, function() F.playEmote(5104377791) end)
	createActionButton(tab, "Zombie Walk", 31, function() F.playEmote(616163682) end)
	createActionButton(tab, "Wave", 32, function() F.playEmote(507770239) end)
	createActionButton(tab, "Point", 33, function() F.playEmote(507770453) end)
	createActionButton(tab, "Laugh", 34, function() F.playEmote(507770818) end)

	createSpacer(tab, 35)
	createSectionLabel(tab, "Character Mods", 36)
	createToggle(tab, "Headless", 37, function(on)
		funState.headlessEnabled = on
		if on then F.startHeadless() else F.stopHeadless() end
	end)
	createToggle(tab, "Rainbow", 38, function(on)
		funState.rainbowEnabled = on
		if on then F.startRainbow() else F.stopRainbow() end
	end)
	createActionButton(tab, "Tiny Character", 39, function() F.tinyCharacter() end)
	createActionButton(tab, "Giant Character", 40, function() F.giantCharacter() end)
	createActionButton(tab, "Neon Body", 41, function() F.neonBody() end)
	createActionButton(tab, "Glass Body", 42, function() F.glassBody() end)
	createActionButton(tab, "Clone Illusion", 43, function() F.cloneIllusion() end)
	createActionButton(tab, "Sit in Air", 44, function() F.sitInAir() end)
end


-- ===================== BUILD COMBAT TAB =====================
do
	local tab = tabFrames["Combat"]

	createSectionLabel(tab, "Aimbot", 1)
	createToggle(tab, "Aimbot (Hold RMB/Q)", 2, function(on)
		combatState.aimbotEnabled = on
		if on then F.startAimbot() else F.stopAimbot() end
	end)
	createSlider(tab, "Aim Smoothing", 1, 10, combatState.aimbotSmoothing, 3, function(val) combatState.aimbotSmoothing = val end)
	createSlider(tab, "Aim FOV", 50, 500, combatState.aimbotFOV, 4, function(val) combatState.aimbotFOV = val end)
	createToggle(tab, "Wall Check", 5, function(on)
		combatState.aimbotWallCheck = on
		if on then addLog("[AIMBOT] Wall check ON", COLORS.success)
		else addLog("[AIMBOT] Wall check OFF - aim through walls", COLORS.error) end
	end)
	createToggle(tab, "Team Check", 6, function(on)
		combatState.aimbotTeamCheck = on
		if on then addLog("[AIMBOT] Team check ON", COLORS.success)
		else addLog("[AIMBOT] Team check OFF - target all", COLORS.error) end
	end)
	createToggle(tab, "Triggerbot", 7, function(on)
		combatState.triggerBotEnabled = on
		if on then F.startTriggerBot() else F.stopTriggerBot() end
	end)

	createSpacer(tab, 8)
	createSectionLabel(tab, "Hitbox", 9)
	createToggle(tab, "Hitbox Expander", 10, function(on)
		combatState.hitboxEnabled = on
		if on then F.startHitboxExpand() else F.stopHitboxExpand() end
	end)
	createSlider(tab, "Hitbox Size", 1, 30, combatState.hitboxSize, 11, function(val) combatState.hitboxSize = val end)

	createSpacer(tab, 12)
	createSectionLabel(tab, "Defense", 13)
	createToggle(tab, "Kill Aura", 14, function(on)
		combatState.killAuraEnabled = on
		if on then F.startKillAura() else F.stopKillAura() end
	end)
	createToggle(tab, "Anti Fling", 15, function(on)
		combatState.antiFlingEnabled = on
		if on then F.startAntiFling() else F.stopAntiFling() end
	end)
	createToggle(tab, "Anti-Void", 16, function(on)
		combatState.antiVoidEnabled = on
		if on then F.startAntiVoid() else F.stopAntiVoid() end
	end)
end


-- ===================== BUILD VISUALS TAB =====================
do
	local tab = tabFrames["Visuals"]

	createSectionLabel(tab, "Lighting", 1)
	createToggle(tab, "Fullbright", 2, function(on)
		visualState.fullbrightEnabled = on
		if on then F.startFullbright() else F.stopFullbright() end
	end)
	createToggle(tab, "No Fog", 3, function(on)
		visualState.noFogEnabled = on
		if on then F.startNoFog() else F.stopNoFog() end
	end)
	createSlider(tab, "Time of Day", 0, 24, 14, 4, function(val) pcall(function() Lighting.ClockTime = val end) end)
	createSlider(tab, "Brightness", 0, 5, 1, 5, function(val) pcall(function() Lighting.Brightness = val end) end)

	createSpacer(tab, 6)
	createSectionLabel(tab, "World", 7)
	createToggle(tab, "X-Ray", 8, function(on)
		visualState.xrayEnabled = on
		if on then F.startXray() else F.stopXray() end
	end)

	createSpacer(tab, 9)
	createSectionLabel(tab, "Camera", 10)
	createSlider(tab, "FOV", 30, 120, 70, 11, function(val) pcall(function() workspace.CurrentCamera.FieldOfView = val end) end)
	createToggle(tab, "Freecam (WASD)", 12, function(on)
		visualState.freecamEnabled = on
		if on then F.startFreecam() else F.stopFreecam() end
	end)

	createSpacer(tab, 13)
	createSectionLabel(tab, "HUD", 14)
	createToggle(tab, "FPS Counter", 15, function(on)
		visualState.fpsCounterEnabled = on
		if on then F.startFpsCounter() else F.stopFpsCounter() end
	end)
end


-- ===================== BUILD SETTINGS TAB =====================
do
	local tab = tabFrames["Settings"]

	createSectionLabel(tab, "Keybinds", 1)
	createInfoLabel(tab, "Right Shift = Toggle Window", 2)
	createInfoLabel(tab, "; prefix for chat commands", 3)
	createInfoLabel(tab, "Ctrl+Click = ClickTP (when on)", 4)
	createInfoLabel(tab, "Hold RMB/Q = Aimbot (when on)", 5)

	createSpacer(tab, 6)
	createSectionLabel(tab, "Theme", 7)
	local themeNames = {}
	for _, id in ipairs({"default", "galaxy", "ocean", "blood", "mint"}) do
		if THEMES[id] then table.insert(themeNames, THEMES[id].name) end
	end
	createDropdown(tab, "Theme", themeNames, THEMES.default.name, function(choice)
		-- WindUI applies the registered theme by name across its whole UI.
		pcall(function() WindUI:SetTheme(choice) end)
		addLog("[THEME] " .. choice .. " applied!", COLORS.accent)
	end)

	createSpacer(tab, themeOrder)
	themeOrder = themeOrder + 1
	createSectionLabel(tab, "Danger Zone", themeOrder)
	themeOrder = themeOrder + 1
	createActionButton(tab, "Panic Key (Destroy All)", themeOrder, function()
		pcall(function() screenGui:Destroy() end)
	end)
	themeOrder = themeOrder + 1
	createActionButton(tab, "Unload Script", themeOrder, function()
		F.unloadScript()
	end)

	themeOrder = themeOrder + 1
	createSpacer(tab, themeOrder)
	themeOrder = themeOrder + 1
	createSectionLabel(tab, "About", themeOrder)
	themeOrder = themeOrder + 1
	createInfoLabel(tab, "Pebbleford Hub v3.1", themeOrder)
	themeOrder = themeOrder + 1
	createInfoLabel(tab, "50+ features | 10 tabs", themeOrder)
	themeOrder = themeOrder + 1
	createInfoLabel(tab, "github.com/pebbleford/roblox-scripts", themeOrder)
end

-- ===================== COMMAND BAR (hidden inline at bottom of Main tab) =====================
-- Commands can be run from the executor tab by typing them as scripts
-- but we also support ; prefix commands via a chat hook

local commands = {}
commands["esp"] = function() espState.espEnabled = true F.enableESP() end
commands["unesp"] = function() espState.espEnabled = false F.disableESP() end
commands["esp+"] = function() espState.drawingEspEnabled = true F.startDrawingEsp() end
commands["unesp+"] = function() espState.drawingEspEnabled = false F.stopDrawingEsp() end
commands["fly"] = function() flyState.flyEnabled = true F.startFly() end
commands["unfly"] = function() flyState.flyEnabled = false F.stopFly() end
commands["vfly"] = function() flyState.vehicleFlyEnabled = true F.startVehicleFly() end
commands["unvfly"] = function() flyState.vehicleFlyEnabled = false F.stopVehicleFly() end
commands["speed"] = function(args) local v = tonumber(args[1]) if v then moveState.speedValue = v end moveState.speedEnabled = true F.startSpeed() end
commands["unspeed"] = function() moveState.speedEnabled = false F.stopSpeed() end
commands["noclip"] = function() moveState.noclipEnabled = true F.startNoclip() end
commands["unnoclip"] = function() moveState.noclipEnabled = false F.stopNoclip() end
commands["antifling"] = function() combatState.antiFlingEnabled = true F.startAntiFling() end
commands["unantifling"] = function() combatState.antiFlingEnabled = false F.stopAntiFling() end
commands["god"] = function() combatState.godEnabled = true F.startGod() end
commands["ungod"] = function() combatState.godEnabled = false F.stopGod() end
commands["tp"] = function(args)
	if not args[1] then addLog("[CMD] Usage: ;tp <player>", COLORS.error) return end
	local target = F.findPlayer(args[1])
	if target then F.teleportToPlayer(target) else addLog("[CMD] Player not found: " .. args[1], COLORS.error) end
end
commands["invisible"] = function() funState.invisibleEnabled = true F.startInvisible() end
commands["visible"] = function() funState.invisibleEnabled = false F.stopInvisible() end
commands["jp"] = function(args)
	local v = tonumber(args[1])
	if v then moveState.jumpPowerValue = v F.setJumpPower(v) addLog("[CMD] Jump Power: " .. v, COLORS.success)
	else addLog("[CMD] Usage: ;jp <value>", COLORS.error) end
end
commands["gravity"] = function(args)
	local v = tonumber(args[1])
	if v then moveState.gravityValue = v F.setGravity(v) addLog("[CMD] Gravity: " .. v, COLORS.success)
	else addLog("[CMD] Usage: ;gravity <value>", COLORS.error) end
end
commands["fling"] = function() if flingState.walkFlingEnabled then flingState.walkFlingEnabled = false F.stopWalkFling() end flingState.flingEnabled = true F.startFling() end
commands["unfling"] = function() flingState.flingEnabled = false F.stopFling() end
commands["walkfling"] = function() if flingState.flingEnabled then flingState.flingEnabled = false F.stopFling() end flingState.walkFlingEnabled = true F.startWalkFling() end
commands["unwalkfling"] = function() flingState.walkFlingEnabled = false F.stopWalkFling() end
commands["carfling"] = function() if flingState.flingEnabled then flingState.flingEnabled = false F.stopFling() end if flingState.walkFlingEnabled then flingState.walkFlingEnabled = false F.stopWalkFling() end flingState.carFlingEnabled = true F.startCarFling() end
commands["uncarfling"] = function() flingState.carFlingEnabled = false F.stopCarFling() end
commands["carnoclip"] = function() moveState.carNoclipEnabled = true F.startCarNoclip() end
commands["uncarnoclip"] = function() moveState.carNoclipEnabled = false F.stopCarNoclip() end
commands["backseat"] = function() moveState.backseatDriveEnabled = true F.startBackseatDrive() end
commands["unbackseat"] = function() moveState.backseatDriveEnabled = false F.stopBackseatDrive() end
commands["carspeed"] = function(args) local v = tonumber(args[1]) if v then moveState.carSpeedValue = v end moveState.carSpeedEnabled = true F.startCarSpeed() end
commands["uncarspeed"] = function() moveState.carSpeedEnabled = false F.stopCarSpeed() end
commands["infjump"] = function() moveState.infJumpEnabled = true F.startInfJump() end
commands["uninfjump"] = function() moveState.infJumpEnabled = false F.stopInfJump() end
commands["killaura"] = function() combatState.killAuraEnabled = true F.startKillAura() end
commands["unkillaura"] = function() combatState.killAuraEnabled = false F.stopKillAura() end
commands["rejoin"] = function() F.rejoinServer() end
commands["serverhop"] = function() F.serverHop() end
commands["spectate"] = function(args)
	if not args[1] then addLog("[CMD] Usage: ;spectate <player>", COLORS.error) return end
	local target = F.findPlayer(args[1])
	if target then F.spectatePlayer(target) else addLog("[CMD] Player not found: " .. args[1], COLORS.error) end
end
commands["unspectate"] = function() F.unspectate() end
commands["spin"] = function() funState.spinEnabled = true F.startSpin() end
commands["unspin"] = function() funState.spinEnabled = false F.stopSpin() end
commands["seizure"] = function() funState.seizureEnabled = true F.startSeizure() end
commands["unseizure"] = function() funState.seizureEnabled = false F.stopSeizure() end
commands["emote1"] = function() F.playJerkEmote() end
commands["dance"] = function() F.playEmote(507771019, 1, 10) addLog("[EMOTE] Dance!", COLORS.success) end
commands["dab"] = function() F.playEmote(183412246, 1, 3) addLog("[EMOTE] Dab!", COLORS.success) end
commands["crouch"] = function() F.playEmote(182724289, 1, nil) addLog("[EMOTE] Crouch", COLORS.success) end
commands["stopemote"] = function() F.stopEmote() addLog("[EMOTE] Stopped", COLORS.error) end

commands["aimbot"] = function() combatState.aimbotEnabled = true F.startAimbot() end
commands["unaimbot"] = function() combatState.aimbotEnabled = false F.stopAimbot() end
commands["triggerbot"] = function() combatState.triggerBotEnabled = true F.startTriggerBot() end
commands["untriggerbot"] = function() combatState.triggerBotEnabled = false F.stopTriggerBot() end
commands["hitbox"] = function(args) local v = tonumber(args[1]) if v then combatState.hitboxSize = v end combatState.hitboxEnabled = true F.startHitboxExpand() end
commands["unhitbox"] = function() combatState.hitboxEnabled = false F.stopHitboxExpand() end
commands["antivoid"] = function() combatState.antiVoidEnabled = true F.startAntiVoid() end
commands["unantivoid"] = function() combatState.antiVoidEnabled = false F.stopAntiVoid() end
commands["tracers"] = function() espState.tracersEnabled = true F.startTracers() end
commands["untracers"] = function() espState.tracersEnabled = false F.stopTracers() end
commands["crosshair"] = function() espState.crosshairEnabled = true F.startCrosshair() end
commands["uncrosshair"] = function() espState.crosshairEnabled = false F.stopCrosshair() end
commands["clicktp"] = function() moveState.clickTpEnabled = true F.startClickTp() end
commands["unclicktp"] = function() moveState.clickTpEnabled = false F.stopClickTp() end
commands["bhop"] = function() moveState.bunnyHopEnabled = true F.startBunnyHop() end
commands["unbhop"] = function() moveState.bunnyHopEnabled = false F.stopBunnyHop() end
commands["float"] = function() moveState.floatEnabled = true F.startFloat() end
commands["unfloat"] = function() moveState.floatEnabled = false F.stopFloat() end
commands["platform"] = function() moveState.platformEnabled = true F.startPlatform() end
commands["unplatform"] = function() moveState.platformEnabled = false F.stopPlatform() end
commands["longjump"] = function() F.doLongJump() end
commands["tpbehind"] = function() F.tpBehindPlayer() end
commands["savepos"] = function(args) if not args[1] then return end moveState.savedPositions[args[1]] = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame addLog("[WAYPOINT] Saved: " .. args[1], COLORS.success) end
commands["loadpos"] = function(args) if not args[1] or not moveState.savedPositions[args[1]] then addLog("[WAYPOINT] Not found", COLORS.error) return end local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") if hrp then hrp.CFrame = moveState.savedPositions[args[1]] addLog("[WAYPOINT] Loaded: " .. args[1], COLORS.success) end end
commands["listpos"] = function() addLog("--- Waypoints ---", COLORS.accent) for name in pairs(moveState.savedPositions) do addLog("  " .. name, COLORS.textSecondary) end end
commands["fullbright"] = function() visualState.fullbrightEnabled = true F.startFullbright() end
commands["unfullbright"] = function() visualState.fullbrightEnabled = false F.stopFullbright() end
commands["xray"] = function() visualState.xrayEnabled = true F.startXray() end
commands["unxray"] = function() visualState.xrayEnabled = false F.stopXray() end
commands["fov"] = function(args) local v = tonumber(args[1]) if v then pcall(function() workspace.CurrentCamera.FieldOfView = v end) addLog("[FOV] Set to " .. v, COLORS.success) end end
commands["freecam"] = function() visualState.freecamEnabled = true F.startFreecam() end
commands["unfreecam"] = function() visualState.freecamEnabled = false F.stopFreecam() end
commands["time"] = function(args) local v = tonumber(args[1]) if v then pcall(function() Lighting.ClockTime = v end) addLog("[TIME] Set to " .. v, COLORS.success) end end
commands["nofog"] = function() visualState.noFogEnabled = true F.startNoFog() end
commands["unnofog"] = function() visualState.noFogEnabled = false F.stopNoFog() end
commands["fps"] = function() visualState.fpsCounterEnabled = true F.startFpsCounter() end
commands["unfps"] = function() visualState.fpsCounterEnabled = false F.stopFpsCounter() end
commands["headless"] = function() funState.headlessEnabled = true F.startHeadless() end
commands["unheadless"] = function() funState.headlessEnabled = false F.stopHeadless() end
commands["rainbow"] = function() funState.rainbowEnabled = true F.startRainbow() end
commands["unrainbow"] = function() funState.rainbowEnabled = false F.stopRainbow() end
commands["tiny"] = function() F.tinyCharacter() end
commands["giant"] = function() F.giantCharacter() end
commands["neon"] = function() F.neonBody() end
commands["glass"] = function() F.glassBody() end
commands["clone"] = function() F.cloneIllusion() end
commands["sitair"] = function() F.sitInAir() end
commands["tpose"] = function() F.playEmote(5104377791) end
commands["zombie"] = function() F.playEmote(616163682) end
commands["wave"] = function() F.playEmote(507770239) end
commands["point"] = function() F.playEmote(507770453) end
commands["laugh"] = function() F.playEmote(507770818) end
commands["antiafk"] = function() serverState.antiAfkEnabled = true F.startAntiAfk() end
commands["unantiafk"] = function() serverState.antiAfkEnabled = false F.stopAntiAfk() end
commands["chatspy"] = function() serverState.chatSpyEnabled = true F.startChatSpy() end
commands["unchatspy"] = function() serverState.chatSpyEnabled = false F.stopChatSpy() end
commands["joinnotify"] = function() serverState.joinNotifyEnabled = true F.startJoinNotify() end
commands["unjoinnotify"] = function() serverState.joinNotifyEnabled = false F.stopJoinNotify() end
commands["respawn"] = function() F.respawnCharacter() end
commands["autorespawn"] = function() serverState.autoRespawnEnabled = true F.startAutoRespawn() end
commands["unautorespawn"] = function() serverState.autoRespawnEnabled = false F.stopAutoRespawn() end
commands["orbit"] = function() playerState.orbitEnabled = true F.startOrbit() end
commands["unorbit"] = function() playerState.orbitEnabled = false F.stopOrbit() end
commands["attach"] = function() playerState.attachEnabled = true F.startAttach() end
commands["unattach"] = function() playerState.attachEnabled = false F.stopAttach() end
commands["follow"] = function() playerState.followEnabled = true F.startFollow() end
commands["unfollow"] = function() playerState.followEnabled = false F.stopFollow() end
commands["stare"] = function() playerState.stareEnabled = true F.startStare() end
commands["unstare"] = function() playerState.stareEnabled = false F.stopStare() end
commands["playerinfo"] = function() F.showPlayerInfo() end
commands["panic"] = function() pcall(function() screenGui:Destroy() end) end
commands["unload"] = function() F.unloadScript() end

commands["cmds"] = function()
	addLog("--- v3.1 Commands (90+) ---", COLORS.accent)
	addLog("== Combat ==", COLORS.textSecondary)
	addLog(";aimbot ;triggerbot ;hitbox [sz] ;antifling ;antivoid", COLORS.textSecondary)
	addLog(";killaura / un- versions to disable", COLORS.textSecondary)
	addLog("== ESP ==", COLORS.textSecondary)
	addLog(";esp ;tracers ;crosshair", COLORS.textSecondary)
	addLog("== Movement ==", COLORS.textSecondary)
	addLog(";fly ;speed [v] ;noclip ;god ;infjump ;bhop", COLORS.textSecondary)
	addLog(";clicktp ;float ;platform ;longjump ;tpbehind", COLORS.textSecondary)
	addLog(";savepos <n> ;loadpos <n> ;listpos", COLORS.textSecondary)
	addLog("== Visuals ==", COLORS.textSecondary)
	addLog(";fullbright ;xray ;fov [v] ;freecam ;nofog", COLORS.textSecondary)
	addLog(";time [0-24] ;fps", COLORS.textSecondary)
	addLog("== Fun ==", COLORS.textSecondary)
	addLog(";fling ;walkfling ;carfling ;invisible ;spin ;seizure", COLORS.textSecondary)
	addLog(";headless ;rainbow ;tiny ;giant ;neon ;glass ;clone", COLORS.textSecondary)
	addLog(";tpose ;zombie ;wave ;point ;laugh ;sitair", COLORS.textSecondary)
	addLog("== Player ==", COLORS.textSecondary)
	addLog(";tp <p> ;spectate <p> ;orbit ;attach ;follow ;stare", COLORS.textSecondary)
	addLog(";playerinfo", COLORS.textSecondary)
	addLog("== Server ==", COLORS.textSecondary)
	addLog(";rejoin ;serverhop ;antiafk ;chatspy ;joinnotify", COLORS.textSecondary)
	addLog(";respawn ;autorespawn ;panic ;unload ;cmds", COLORS.textSecondary)
	addLog("Prefix un- to disable any toggle (e.g. ;unfly)", COLORS.textSecondary)
end

F.processCommand = function(input)
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
			F.processCommand(msg)
		end
	end)
end)

-- ===================== KEYBOARD SHORTCUT =====================
-- WindUI provides its own show/hide control and open button, so the old
-- RightShift handler that drove the hand-built window is gone.


-- ===================== AIMBOT LOGIC =====================
F.isTargetVisible = function(targetPart)
	if not combatState.aimbotWallCheck then return true end
	local cam = workspace.CurrentCamera
	local origin = cam.CFrame.Position
	local direction = (targetPart.Position - origin)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local myChar = LocalPlayer.Character
	local ignoreList = {}
	if myChar then table.insert(ignoreList, myChar) end
	rayParams.FilterDescendantsInstances = ignoreList
	local result = workspace:Raycast(origin, direction, rayParams)
	if not result then return true end
	local hitPart = result.Instance
	local targetChar = targetPart.Parent
	if hitPart and hitPart:IsDescendantOf(targetChar) then return true end
	return false
end

F.isActualTeamMode = function()
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

F.shouldSkipTeammate = function(player)
	if not combatState.aimbotTeamCheck then return false end
	local myTeam = LocalPlayer.Team
	local theirTeam = player.Team
	if not myTeam or not theirTeam then return false end
	if myTeam == theirTeam then
		return F.isActualTeamMode()
	end
	return false
end

F.getClosestPlayerInFOV = function()
	local cam = workspace.CurrentCamera
	local closest, closestDist = nil, combatState.aimbotFOV
	local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and not F.shouldSkipTeammate(player) then
			local char = player.Character
			local head = char:FindFirstChild("Head")
			if head then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
					if onScreen then
						local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
						if dist < closestDist and F.isTargetVisible(head) then
							closest = head
							closestDist = dist
						end
					end
				end
			end
		end
	end
	return closest
end

F.startAimbot = function()
	combatState.aimbotInputBeganConn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Q then
			combatState.aimbotHolding = true
		end
	end)
	combatState.aimbotInputEndedConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Q then
			combatState.aimbotHolding = false
		end
	end)
	combatState.aimbotConnection = RunService.Heartbeat:Connect(function()
		if not combatState.aimbotEnabled or not combatState.aimbotHolding then return end
		pcall(function()
			local cam = workspace.CurrentCamera
			local target = F.getClosestPlayerInFOV()
			if not target then return end
			local camPos = cam.CFrame.Position
			local targetCF = CFrame.new(camPos, target.Position)
			if combatState.aimbotSmoothing <= 1 then
				cam.CFrame = targetCF
			else
				cam.CFrame = cam.CFrame:Lerp(targetCF, 1 / combatState.aimbotSmoothing)
			end
		end)
	end)
	addLog("[AIMBOT] ON (Hold RMB or Q)", COLORS.success)
end

F.stopAimbot = function()
	if combatState.aimbotConnection then combatState.aimbotConnection:Disconnect() combatState.aimbotConnection = nil end
	if combatState.aimbotInputBeganConn then combatState.aimbotInputBeganConn:Disconnect() combatState.aimbotInputBeganConn = nil end
	if combatState.aimbotInputEndedConn then combatState.aimbotInputEndedConn:Disconnect() combatState.aimbotInputEndedConn = nil end
	combatState.aimbotHolding = false
	addLog("[AIMBOT] OFF", COLORS.error)
end

-- ===================== TRIGGERBOT LOGIC =====================
F.startTriggerBot = function()
	combatState.triggerBotConnection = RunService.Heartbeat:Connect(function()
		if not combatState.triggerBotEnabled then return end
		pcall(function()
			local mouse = LocalPlayer:GetMouse()
			if mouse.Target then
				local targetModel = mouse.Target:FindFirstAncestorOfClass("Model")
				if targetModel then
					local player = Players:GetPlayerFromCharacter(targetModel)
					if player and player ~= LocalPlayer then
						local hum = targetModel:FindFirstChildOfClass("Humanoid")
						if hum and hum.Health > 0 then
							pcall(function() mouse1click() end)
						end
					end
				end
			end
		end)
	end)
	addLog("[TRIGGERBOT] ON", COLORS.success)
end

F.stopTriggerBot = function()
	if combatState.triggerBotConnection then combatState.triggerBotConnection:Disconnect() combatState.triggerBotConnection = nil end
	addLog("[TRIGGERBOT] OFF", COLORS.error)
end

-- ===================== HITBOX EXPANDER LOGIC =====================
F.startHitboxExpand = function()
	combatState.hitboxLastTick = 0
	combatState.hitboxConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - combatState.hitboxLastTick < 2 then return end
		combatState.hitboxLastTick = now
		pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					local head = player.Character:FindFirstChild("Head")
					if head and head:IsA("BasePart") then
						head.Size = Vector3.new(combatState.hitboxSize, combatState.hitboxSize, combatState.hitboxSize)
						head.Transparency = 0.8
						head.CanCollide = false
					end
				end
			end
		end)
	end)
	addLog("[HITBOX] ON - Size: " .. combatState.hitboxSize, COLORS.success)
end

F.stopHitboxExpand = function()
	if combatState.hitboxConnection then combatState.hitboxConnection:Disconnect() combatState.hitboxConnection = nil end
	pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local head = player.Character:FindFirstChild("Head")
				if head and head:IsA("BasePart") then head.Size = Vector3.new(1, 1, 1) head.Transparency = 0 end
			end
		end
	end)
	addLog("[HITBOX] OFF", COLORS.error)
end

-- ===================== ANTI-VOID LOGIC =====================
F.startAntiVoid = function()
	combatState.lastSafePos = nil
	combatState.antiVoidConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			if hrp.Position.Y > -100 then
				combatState.lastSafePos = hrp.CFrame
			elseif combatState.lastSafePos then
				hrp.CFrame = combatState.lastSafePos
			end
		end)
	end)
	addLog("[ANTI-VOID] ON", COLORS.success)
end

F.stopAntiVoid = function()
	if combatState.antiVoidConnection then combatState.antiVoidConnection:Disconnect() combatState.antiVoidConnection = nil end
	combatState.lastSafePos = nil
	addLog("[ANTI-VOID] OFF", COLORS.error)
end

-- ===================== TRACERS LOGIC =====================
local hasDrawing = pcall(function() return Drawing and Drawing.new end)

F.startTracers = function()
	espState.tracerConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local cam = workspace.CurrentCamera
			local viewportSize = cam.ViewportSize
			local bottomCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y)
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					local hrp = player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
						if onScreen and hasDrawing then
							local line = espState.tracerLines[player]
							if not line then
								line = Drawing.new("Line")
								line.Color = Color3.fromRGB(255, 255, 255)
								line.Thickness = 1
								espState.tracerLines[player] = line
							end
							line.From = bottomCenter
							line.To = Vector2.new(screenPos.X, screenPos.Y)
							line.Visible = true
						elseif espState.tracerLines[player] then
							espState.tracerLines[player].Visible = false
						end
					end
				end
			end
			-- Clean up disconnected players
			for player, line in pairs(espState.tracerLines) do
				if not player.Parent then line:Remove() espState.tracerLines[player] = nil end
			end
		end)
	end)
	addLog("[TRACERS] ON", COLORS.success)
end

F.stopTracers = function()
	if espState.tracerConnection then espState.tracerConnection:Disconnect() espState.tracerConnection = nil end
	for _, line in pairs(espState.tracerLines) do pcall(function() line:Remove() end) end
	espState.tracerLines = {}
	addLog("[TRACERS] OFF", COLORS.error)
end

-- ===================== FOV CIRCLE LOGIC =====================
F.startFOVCircle = function()
	if not hasDrawing then addLog("[FOV] Drawing API not available", COLORS.error) return end
	espState.fovCircleFrame = Drawing.new("Circle")
	espState.fovCircleFrame.Color = COLORS.accent
	espState.fovCircleFrame.Thickness = 1
	espState.fovCircleFrame.NumSides = 64
	espState.fovCircleFrame.Radius = espState.fovRadius
	espState.fovCircleFrame.Filled = false
	espState.fovCircleFrame.Visible = true
	espState.fovCircleFrame.Position = Vector2.new(workspace.CurrentCamera.ViewportSize.X/2, workspace.CurrentCamera.ViewportSize.Y/2)
	addLog("[FOV CIRCLE] ON - Radius: " .. espState.fovRadius, COLORS.success)
end

F.stopFOVCircle = function()
	if espState.fovCircleFrame then pcall(function() espState.fovCircleFrame:Remove() end) espState.fovCircleFrame = nil end
	addLog("[FOV CIRCLE] OFF", COLORS.error)
end

-- ===================== CROSSHAIR LOGIC =====================
F.startCrosshair = function()
	if not hasDrawing then addLog("[CROSSHAIR] Drawing API not available", COLORS.error) return end
	local cam = workspace.CurrentCamera
	local cx, cy = cam.ViewportSize.X/2, cam.ViewportSize.Y/2
	local gap, size = 4, 12
	local specs = {
		{Vector2.new(cx - gap - size, cy), Vector2.new(cx - gap, cy)},
		{Vector2.new(cx + gap, cy), Vector2.new(cx + gap + size, cy)},
		{Vector2.new(cx, cy - gap - size), Vector2.new(cx, cy - gap)},
		{Vector2.new(cx, cy + gap), Vector2.new(cx, cy + gap + size)},
	}
	for _, s in ipairs(specs) do
		local l = Drawing.new("Line")
		l.From = s[1]
		l.To = s[2]
		l.Color = Color3.fromRGB(0, 255, 0)
		l.Thickness = 2
		l.Visible = true
		table.insert(espState.crosshairLines, l)
	end
	addLog("[CROSSHAIR] ON", COLORS.success)
end

F.stopCrosshair = function()
	for _, l in ipairs(espState.crosshairLines) do pcall(function() l:Remove() end) end
	espState.crosshairLines = {}
	addLog("[CROSSHAIR] OFF", COLORS.error)
end

-- ===================== CLICK TP LOGIC =====================
F.startClickTp = function()
	moveState.clickTpConnection = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				pcall(function()
					local mouse = LocalPlayer:GetMouse()
					local char = LocalPlayer.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					if hrp and mouse.Hit then
						hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
						addLog("[CLICKTP] Teleported", COLORS.success)
					end
				end)
			end
		end
	end)
	addLog("[CLICK TP] ON (Ctrl+Click)", COLORS.success)
end

F.stopClickTp = function()
	if moveState.clickTpConnection then moveState.clickTpConnection:Disconnect() moveState.clickTpConnection = nil end
	addLog("[CLICK TP] OFF", COLORS.error)
end

-- ===================== BUNNY HOP LOGIC =====================
F.startBunnyHop = function()
	moveState.bunnyHopConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				local state = hum:GetState()
				if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end)
	end)
	addLog("[BHOP] ON - Hold W to auto-jump", COLORS.success)
end

F.stopBunnyHop = function()
	if moveState.bunnyHopConnection then moveState.bunnyHopConnection:Disconnect() moveState.bunnyHopConnection = nil end
	addLog("[BHOP] OFF", COLORS.error)
end

-- ===================== FLOAT LOGIC =====================
F.startFloat = function()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then addLog("[FLOAT] No character", COLORS.error) return end
	local floatY = hrp.Position.Y
	moveState.floatConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local c = LocalPlayer.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if r then
				r.Velocity = Vector3.new(r.Velocity.X, 0, r.Velocity.Z)
				r.CFrame = CFrame.new(r.Position.X, floatY, r.Position.Z) * (r.CFrame - r.CFrame.Position)
			end
		end)
	end)
	addLog("[FLOAT] ON at Y=" .. math.floor(floatY), COLORS.success)
end

F.stopFloat = function()
	if moveState.floatConnection then moveState.floatConnection:Disconnect() moveState.floatConnection = nil end
	addLog("[FLOAT] OFF", COLORS.error)
end

-- ===================== PLATFORM LOGIC =====================
F.startPlatform = function()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local platY = hrp.Position.Y - 3
	local plat = Instance.new("Part")
	plat.Size = Vector3.new(10, 1, 10)
	plat.Anchored = true
	plat.Transparency = 0.5
	plat.BrickColor = BrickColor.new("Medium stone grey")
	plat.Material = Enum.Material.SmoothPlastic
	plat.CanCollide = true
	plat.CFrame = CFrame.new(hrp.Position.X, platY, hrp.Position.Z)
	plat.Parent = workspace
	moveState.platformPart = plat
	moveState.platformConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local c = LocalPlayer.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if r and plat and plat.Parent then
				plat.CFrame = CFrame.new(r.Position.X, platY, r.Position.Z)
			end
		end)
	end)
	addLog("[PLATFORM] ON (fixed height)", COLORS.success)
end

F.stopPlatform = function()
	if moveState.platformConnection then moveState.platformConnection:Disconnect() moveState.platformConnection = nil end
	if moveState.platformPart then pcall(function() moveState.platformPart:Destroy() end) moveState.platformPart = nil end
	addLog("[PLATFORM] OFF", COLORS.error)
end

-- ===================== LONG JUMP (action) =====================
F.doLongJump = function()
	pcall(function()
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Velocity = hrp.CFrame.LookVector * 120 + Vector3.new(0, 60, 0)
			addLog("[LONG JUMP] Launched!", COLORS.success)
		end
	end)
end

-- ===================== TP BEHIND (action) =====================
F.tpBehindPlayer = function()
	pcall(function()
		local target = playerState.selectedPlayer
		if not target or not target.Character then addLog("[TP BEHIND] No player selected", COLORS.error) return end
		local theirHRP = target.Character:FindFirstChild("HumanoidRootPart")
		local myChar = LocalPlayer.Character
		local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if myHRP and theirHRP then
			myHRP.CFrame = theirHRP.CFrame * CFrame.new(0, 0, 5)
			addLog("[TP BEHIND] Teleported behind " .. target.Name, COLORS.success)
		end
	end)
end

-- ===================== FULLBRIGHT LOGIC =====================
F.startFullbright = function()
	visualState.origAmbient = Lighting.Ambient
	visualState.origBrightness = Lighting.Brightness
	visualState.origFogEnd = Lighting.FogEnd
	visualState.origGlobalShadows = Lighting.GlobalShadows
	Lighting.Ambient = Color3.fromRGB(200, 200, 200)
	Lighting.Brightness = 2
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = false
	addLog("[FULLBRIGHT] ON", COLORS.success)
end

F.stopFullbright = function()
	if visualState.origAmbient then Lighting.Ambient = visualState.origAmbient end
	if visualState.origBrightness then Lighting.Brightness = visualState.origBrightness end
	if visualState.origFogEnd then Lighting.FogEnd = visualState.origFogEnd end
	if visualState.origGlobalShadows ~= nil then Lighting.GlobalShadows = visualState.origGlobalShadows end
	addLog("[FULLBRIGHT] OFF", COLORS.error)
end

-- ===================== X-RAY LOGIC =====================
F.startXray = function()
	visualState.xrayOrigTransparencies = {}
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and not part:IsDescendantOf(LocalPlayer.Character or Instance.new("Folder")) then
			if part.Transparency < 0.5 then
				visualState.xrayOrigTransparencies[part] = part.Transparency
				part.Transparency = 0.7
			end
		end
	end
	addLog("[X-RAY] ON", COLORS.success)
end

F.stopXray = function()
	for part, trans in pairs(visualState.xrayOrigTransparencies) do
		if part and part.Parent then part.Transparency = trans end
	end
	visualState.xrayOrigTransparencies = {}
	addLog("[X-RAY] OFF", COLORS.error)
end

-- ===================== FREECAM LOGIC =====================
F.startFreecam = function()
	local cam = workspace.CurrentCamera
	visualState.origCameraSubject = cam.CameraSubject
	visualState.origCameraType = cam.CameraType
	visualState.freecamCFrame = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	-- Freeze character so WASD only moves camera
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		visualState.freecamWasAnchored = hrp.Anchored
		hrp.Anchored = true
	end
	-- Init yaw/pitch from current camera orientation (YXZ order)
	local rx, ry, _ = cam.CFrame:ToEulerAnglesYXZ()
	visualState.freecamYaw = ry
	visualState.freecamPitch = rx
	visualState.freecamMouseConn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Delta
			visualState.freecamYaw = visualState.freecamYaw - delta.X * 0.004
			visualState.freecamPitch = math.clamp(visualState.freecamPitch - delta.Y * 0.004, -math.rad(89), math.rad(89))
		end
	end)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	visualState.freecamConnection = RunService.RenderStepped:Connect(function(dt)
		pcall(function()
			local speed = 50 * dt
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then speed = speed * 3 end
			-- Yaw around world Y first, then pitch around local X (standard FPS camera)
			local rot = CFrame.Angles(0, visualState.freecamYaw, 0) * CFrame.Angles(visualState.freecamPitch, 0, 0)
			local move = Vector3.new(0, 0, 0)
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + rot.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - rot.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - rot.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + rot.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.E) then move = move - Vector3.new(0, 1, 0) end
			if move.Magnitude > 0 then move = move.Unit * speed end
			visualState.freecamCFrame = CFrame.new(visualState.freecamCFrame.Position + move) * rot
			workspace.CurrentCamera.CFrame = visualState.freecamCFrame
		end)
	end)
	addLog("[FREECAM] ON (WASD/Space/E + Shift=fast)", COLORS.success)
end

F.stopFreecam = function()
	if visualState.freecamConnection then visualState.freecamConnection:Disconnect() visualState.freecamConnection = nil end
	if visualState.freecamMouseConn then visualState.freecamMouseConn:Disconnect() visualState.freecamMouseConn = nil end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	-- Unfreeze character
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Anchored = visualState.freecamWasAnchored or false end
	local cam = workspace.CurrentCamera
	if visualState.origCameraSubject then cam.CameraSubject = visualState.origCameraSubject end
	if visualState.origCameraType then cam.CameraType = visualState.origCameraType end
	addLog("[FREECAM] OFF", COLORS.error)
end

-- ===================== NO FOG LOGIC =====================
F.startNoFog = function()
	visualState.origFogEndVisual = Lighting.FogEnd
	Lighting.FogEnd = 1e10
	addLog("[NO FOG] ON", COLORS.success)
end

F.stopNoFog = function()
	if visualState.origFogEndVisual then Lighting.FogEnd = visualState.origFogEndVisual end
	addLog("[NO FOG] OFF", COLORS.error)
end

-- ===================== FPS COUNTER LOGIC =====================
F.startFpsCounter = function()
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 80, 0, 22)
	label.Position = UDim2.new(1, -90, 0, 5)
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.BackgroundTransparency = 0.5
	label.TextColor3 = Color3.fromRGB(0, 255, 0)
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.Text = "FPS: --"
	label.Parent = screenGui
	visualState.fpsLabel = label
	local lastTick = tick()
	local frames = 0
	visualState.fpsConnection = RunService.RenderStepped:Connect(function()
		frames = frames + 1
		local now = tick()
		if now - lastTick >= 1 then
			if label and label.Parent then label.Text = "FPS: " .. frames end
			frames = 0
			lastTick = now
		end
	end)
	addLog("[FPS COUNTER] ON", COLORS.success)
end

F.stopFpsCounter = function()
	if visualState.fpsConnection then visualState.fpsConnection:Disconnect() visualState.fpsConnection = nil end
	if visualState.fpsLabel then pcall(function() visualState.fpsLabel:Destroy() end) visualState.fpsLabel = nil end
	addLog("[FPS COUNTER] OFF", COLORS.error)
end

-- ===================== HEADLESS LOGIC =====================
F.startHeadless = function()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		local head = char:FindFirstChild("Head")
		if head then
			funState.headlessSaved[head] = head.Transparency
			head.Transparency = 1
			for _, d in ipairs(head:GetDescendants()) do
				if d:IsA("Decal") then funState.headlessSaved[d] = d.Transparency d.Transparency = 1 end
			end
		end
	end)
	addLog("[HEADLESS] ON", COLORS.success)
end

F.stopHeadless = function()
	for inst, trans in pairs(funState.headlessSaved) do
		if inst and inst.Parent then inst.Transparency = trans end
	end
	funState.headlessSaved = {}
	addLog("[HEADLESS] OFF", COLORS.error)
end

-- ===================== RAINBOW LOGIC =====================
F.startRainbow = function()
	funState.rainbowConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			local col = Color3.fromHSV((tick() % 5) / 5, 1, 1)
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Color = col
				end
			end
		end)
	end)
	addLog("[RAINBOW] ON", COLORS.success)
end

F.stopRainbow = function()
	if funState.rainbowConnection then funState.rainbowConnection:Disconnect() funState.rainbowConnection = nil end
	addLog("[RAINBOW] OFF", COLORS.error)
end

-- ===================== CHARACTER MODS (actions) =====================
F.tinyCharacter = function()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			for _, v in ipairs(hum:GetChildren()) do
				if v:IsA("NumberValue") and v.Name:find("Scale") then v.Value = 0.5 end
			end
		end
	end)
	addLog("[TINY] Character scaled to 0.5x", COLORS.success)
end

F.giantCharacter = function()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			for _, v in ipairs(hum:GetChildren()) do
				if v:IsA("NumberValue") and v.Name:find("Scale") then v.Value = 3 end
			end
		end
	end)
	addLog("[GIANT] Character scaled to 3x", COLORS.success)
end

F.neonBody = function()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then p.Material = Enum.Material.Neon end
		end
	end)
	addLog("[NEON] Body material set to Neon", COLORS.success)
end

F.glassBody = function()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then p.Material = Enum.Material.Glass end
		end
	end)
	addLog("[GLASS] Body material set to Glass", COLORS.success)
end

F.cloneIllusion = function()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		char.Archivable = true
		local clone = char:Clone()
		clone.Name = "CloneIllusion"
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
		end
		local hum = clone:FindFirstChildOfClass("Humanoid")
		if hum then hum.PlatformStand = true end
		clone.Parent = workspace
		addLog("[CLONE] Clone created at your position", COLORS.success)
	end)
end

F.sitInAir = function()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.Sit = true end
	end)
	addLog("[SIT] Sitting in air", COLORS.success)
end

-- ===================== ORBIT LOGIC =====================
F.startOrbit = function()
	playerState.orbitConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local target = playerState.selectedPlayer
			if not target or not target.Character then return end
			local theirHRP = target.Character:FindFirstChild("HumanoidRootPart")
			local myChar = LocalPlayer.Character
			local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
			if myHRP and theirHRP then
				local r = playerState.orbitRadius
				local t = tick() * 2
				myHRP.CFrame = CFrame.new(
					theirHRP.Position + Vector3.new(math.cos(t) * r, 0, math.sin(t) * r),
					theirHRP.Position
				)
			end
		end)
	end)
	addLog("[ORBIT] ON", COLORS.success)
end

F.stopOrbit = function()
	if playerState.orbitConnection then playerState.orbitConnection:Disconnect() playerState.orbitConnection = nil end
	addLog("[ORBIT] OFF", COLORS.error)
end

-- ===================== ATTACH LOGIC =====================
F.startAttach = function()
	playerState.attachConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local target = playerState.selectedPlayer
			if not target or not target.Character then return end
			local theirHRP = target.Character:FindFirstChild("HumanoidRootPart")
			local myChar = LocalPlayer.Character
			local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
			if myHRP and theirHRP then myHRP.CFrame = theirHRP.CFrame end
		end)
	end)
	addLog("[ATTACH] ON", COLORS.success)
end

F.stopAttach = function()
	if playerState.attachConnection then playerState.attachConnection:Disconnect() playerState.attachConnection = nil end
	addLog("[ATTACH] OFF", COLORS.error)
end

-- ===================== FOLLOW LOGIC =====================
F.startFollow = function()
	playerState.followConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local target = playerState.selectedPlayer
			if not target or not target.Character then return end
			local theirHRP = target.Character:FindFirstChild("HumanoidRootPart")
			local myChar = LocalPlayer.Character
			local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
			if hum and theirHRP then hum:MoveTo(theirHRP.Position) end
		end)
	end)
	addLog("[FOLLOW] ON", COLORS.success)
end

F.stopFollow = function()
	if playerState.followConnection then playerState.followConnection:Disconnect() playerState.followConnection = nil end
	addLog("[FOLLOW] OFF", COLORS.error)
end

-- ===================== STARE LOGIC =====================
F.startStare = function()
	playerState.stareConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local target = playerState.selectedPlayer
			if not target or not target.Character then return end
			local theirHRP = target.Character:FindFirstChild("HumanoidRootPart")
			local myChar = LocalPlayer.Character
			local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
			if myHRP and theirHRP then
				myHRP.CFrame = CFrame.new(myHRP.Position, theirHRP.Position)
			end
		end)
	end)
	addLog("[STARE] ON", COLORS.success)
end

F.stopStare = function()
	if playerState.stareConnection then playerState.stareConnection:Disconnect() playerState.stareConnection = nil end
	addLog("[STARE] OFF", COLORS.error)
end

-- ===================== ANTI-AFK LOGIC =====================
F.startAntiAfk = function()
	local VirtualUser = game:GetService("VirtualUser")
	serverState.antiAfkConnection = LocalPlayer.Idled:Connect(function()
		pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)
	end)
	addLog("[ANTI-AFK] ON", COLORS.success)
end

F.stopAntiAfk = function()
	if serverState.antiAfkConnection then serverState.antiAfkConnection:Disconnect() serverState.antiAfkConnection = nil end
	addLog("[ANTI-AFK] OFF", COLORS.error)
end

-- ===================== CHAT SPY LOGIC =====================
F.startChatSpy = function()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			player.Chatted:Connect(function(msg) addLog("[SPY] " .. player.Name .. ": " .. msg, COLORS.textSecondary) end)
		end
	end
	serverState.chatSpyConnection = Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(msg) addLog("[SPY] " .. player.Name .. ": " .. msg, COLORS.textSecondary) end)
	end)
	addLog("[CHAT SPY] ON", COLORS.success)
end

F.stopChatSpy = function()
	if serverState.chatSpyConnection then serverState.chatSpyConnection:Disconnect() serverState.chatSpyConnection = nil end
	addLog("[CHAT SPY] OFF", COLORS.error)
end

-- ===================== JOIN NOTIFY LOGIC =====================
F.startJoinNotify = function()
	serverState.joinNotifyAddedConn = Players.PlayerAdded:Connect(function(player)
		addLog("[JOIN] " .. player.Name .. " joined", Color3.fromRGB(100, 255, 100))
	end)
	serverState.joinNotifyRemovingConn = Players.PlayerRemoving:Connect(function(player)
		addLog("[LEAVE] " .. player.Name .. " left", Color3.fromRGB(255, 100, 100))
	end)
	addLog("[JOIN NOTIFY] ON", COLORS.success)
end

F.stopJoinNotify = function()
	if serverState.joinNotifyAddedConn then serverState.joinNotifyAddedConn:Disconnect() serverState.joinNotifyAddedConn = nil end
	if serverState.joinNotifyRemovingConn then serverState.joinNotifyRemovingConn:Disconnect() serverState.joinNotifyRemovingConn = nil end
	addLog("[JOIN NOTIFY] OFF", COLORS.error)
end

-- ===================== AUTO RESPAWN LOGIC =====================
F.startAutoRespawn = function()
	serverState.autoRespawnConnection = LocalPlayer.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.Died:Connect(function()
				_wait(1)
				pcall(function() LocalPlayer:LoadCharacter() end)
			end)
		end
	end)
	addLog("[AUTO RESPAWN] ON", COLORS.success)
end

F.stopAutoRespawn = function()
	if serverState.autoRespawnConnection then serverState.autoRespawnConnection:Disconnect() serverState.autoRespawnConnection = nil end
	addLog("[AUTO RESPAWN] OFF", COLORS.error)
end

-- ===================== PLAYER INFO (action) =====================
F.showPlayerInfo = function()
	pcall(function()
		local target = playerState.selectedPlayer
		if not target then addLog("[INFO] No player selected", COLORS.error) return end
		addLog("--- Player Info ---", COLORS.accent)
		addLog("Name: " .. target.Name, COLORS.textSecondary)
		addLog("Display: " .. target.DisplayName, COLORS.textSecondary)
		addLog("ID: " .. target.UserId, COLORS.textSecondary)
		addLog("Age: " .. target.AccountAge .. " days", COLORS.textSecondary)
	end)
end

-- ===================== UNLOAD SCRIPT =====================
F.unloadScript = function()
	pcall(function()
		-- Disconnect all state connections
		for _, tbl in ipairs({combatState, espState, flyState, moveState, flingState, funState, visualState, serverState, playerState}) do
			for k, v in pairs(tbl) do
				if typeof(v) == "RBXScriptConnection" then pcall(function() v:Disconnect() end) tbl[k] = nil end
			end
		end
		-- Destroy GUI
		if screenGui then screenGui:Destroy() end
	end)
end


-- ===================== RESPAWN HOOKS =====================
Players.PlayerRemoving:Connect(function(player)
	F.removeHighlight(player)
	F.removeNametag(player)
end)

LocalPlayer.CharacterAdded:Connect(function()
	if flyState.flyEnabled then
		F.stopFly() _wait(0.5)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then F.startFly() end
	end
	if flingState.flingEnabled then F.stopFling() _wait(0.5) F.startFling() end
	if flingState.walkFlingEnabled then F.stopWalkFling() _wait(0.5) F.startWalkFling() end
	flingState.savedPhysProps = {}
	if moveState.speedEnabled then _wait(0.3) F.startSpeed() end
	if combatState.antiFlingEnabled then _wait(0.3) F.startAntiFling() end
	if combatState.godEnabled then
		if combatState.godConnection then combatState.godConnection:Disconnect() combatState.godConnection = nil end
		_wait(0.3) F.startGod()
	end
	if moveState.jumpPowerValue ~= 50 then _wait(0.3) F.setJumpPower(moveState.jumpPowerValue) end
end)

-- ===================== STARTUP =====================
addLog("Pebbleford Hub v3.1", COLORS.accent)
addLog("50+ features loaded across 10 tabs", COLORS.success)
addLog("Type ;cmds in chat for commands", COLORS.textSecondary)
addLog("Press Right Shift to toggle window", COLORS.textSecondary)
print("[Pebbleford Hub] v3.1 loaded")
