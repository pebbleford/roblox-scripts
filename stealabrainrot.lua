-- ╔═══════════════════════════════════════════════════════════════╗
-- ║        Steal a Brainrot - Script Hub                        ║
-- ║   Instant Steal | Auto Farm | ESP | Speed | Noclip | Fly    ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LocalPlayer = Players.LocalPlayer

-- ===================== COLOR PALETTE =====================
local COLORS = {
	bg = Color3.fromRGB(20, 20, 20),
	bgSecondary = Color3.fromRGB(30, 30, 30),
	panel = Color3.fromRGB(45, 45, 45),
	accent = Color3.fromRGB(255, 102, 0),
	accentHover = Color3.fromRGB(255, 133, 51),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(176, 176, 176),
	textDim = Color3.fromRGB(120, 120, 120),
	border = Color3.fromRGB(50, 50, 50),
	toggleOn = Color3.fromRGB(255, 102, 0),
	toggleOff = Color3.fromRGB(85, 85, 85),
	error = Color3.fromRGB(255, 68, 68),
	success = Color3.fromRGB(68, 255, 68),
}

-- ===================== STATE =====================
local instantStealActive = false
local autoFarmActive = false
local espActive = false
local brainrotEspActive = false
local noclipActive = false
local flyActive = false
local speedBoostActive = false
local autoLockActive = false
local antiHitActive = false

local speedValue = 50
local flySpeed = 60
local savedBasePosition = nil
local noclipConnection = nil
local flyConnection = nil
local speedConnection = nil
local autoFarmConnection = nil
local autoLockConnection = nil
local antiHitConnection = nil
local espHighlights = {}
local brainrotHighlights = {}
local windowVisible = true
local activeTab = "Main"
local logLines = {}
local MAX_LOG_LINES = 30

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealBrainrotHub"
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

local function addLog(msg, color)
	table.insert(logLines, {text = msg, color = color or COLORS.textSecondary})
	if #logLines > MAX_LOG_LINES then table.remove(logLines, 1) end
end

-- ===================== MAIN FRAME =====================
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 380)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -190)
mainFrame.BackgroundColor3 = COLORS.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
addCorner(mainFrame, 8)

-- Border
local borderFrame = Instance.new("UIStroke")
borderFrame.Color = COLORS.border
borderFrame.Thickness = 1
borderFrame.Parent = mainFrame

-- ===================== TITLE BAR =====================
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
addCorner(titleBar, 8)

-- Fix bottom corners of title bar
local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 10)
titleFix.Position = UDim2.new(0, 0, 1, -10)
titleFix.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Steal a Brainrot Hub"
titleText.TextColor3 = COLORS.accent
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 13
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 30, 1, 0)
versionLabel.Position = UDim2.new(1, -75, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.0"
versionLabel.TextColor3 = COLORS.textDim
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextSize = 10
versionLabel.Parent = titleBar

-- Close/minimize buttons
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.error
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = titleBar
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
minimizeBtn.Position = UDim2.new(1, -55, 0, 0)
minimizeBtn.BackgroundTransparency = 1
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = COLORS.textSecondary
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.Parent = titleBar

-- Orange accent line
local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 0, 30)
accentLine.BackgroundColor3 = COLORS.accent
accentLine.BorderSizePixel = 0
accentLine.Parent = mainFrame

-- ===================== TAB BAR =====================
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 30)
tabBar.Position = UDim2.new(0, 0, 0, 32)
tabBar.BackgroundColor3 = COLORS.bgSecondary
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local tabNames = {"Main", "Steal", "Movement", "ESP"}
local tabButtons = {}
local tabFrames = {}

for i, name in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 120, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = name
	btn.TextColor3 = COLORS.textSecondary
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 12
	btn.LayoutOrder = i
	btn.Parent = tabBar
	tabButtons[name] = btn

	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -16, 1, -72)
	content.Position = UDim2.new(0, 8, 0, 64)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = COLORS.accent
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Visible = name == "Main"
	content.Parent = mainFrame
	tabFrames[name] = content

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = content

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 4)
	padding.Parent = content
end

local function setActiveTab(name)
	activeTab = name
	for tabName, frame in pairs(tabFrames) do
		frame.Visible = tabName == name
	end
	for tabName, btn in pairs(tabButtons) do
		btn.TextColor3 = tabName == name and COLORS.accent or COLORS.textSecondary
		btn.Font = tabName == name and Enum.Font.GothamBold or Enum.Font.GothamMedium
	end
end

for name, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function() setActiveTab(name) end)
end

-- ===================== UI BUILDERS =====================
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
	row.BackgroundColor3 = COLORS.panel
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

	local circle = Instance.new("Frame")
	circle.Size = UDim2.new(0, 16, 0, 16)
	circle.Position = UDim2.new(0, 2, 0.5, -8)
	circle.BackgroundColor3 = COLORS.textPrimary
	circle.BorderSizePixel = 0
	circle.Parent = toggleFrame
	addCorner(circle, 8)

	local isOn = false
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = row

	local function setVisual(on)
		isOn = on
		toggleFrame.BackgroundColor3 = on and COLORS.toggleOn or COLORS.toggleOff
		circle.Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
	end

	btn.MouseButton1Click:Connect(function()
		isOn = not isOn
		setVisual(isOn)
		if callback then callback(isOn) end
	end)

	return {row = row, setVisualState = setVisual}
end

local function createButton(parent, text, order, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = COLORS.accent
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = COLORS.textPrimary
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.LayoutOrder = order or 0
	btn.Parent = parent
	addCorner(btn, 5)

	btn.MouseEnter:Connect(function() btn.BackgroundColor3 = COLORS.accentHover end)
	btn.MouseLeave:Connect(function() btn.BackgroundColor3 = COLORS.accent end)
	btn.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)
	return btn
end

local function createSlider(parent, text, min, max, default, order, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 40)
	container.BackgroundColor3 = COLORS.panel
	container.BorderSizePixel = 0
	container.LayoutOrder = order or 0
	container.Parent = parent
	addCorner(container, 5)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.5, -10, 0, 18)
	lbl.Position = UDim2.new(0, 10, 0, 2)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.textPrimary
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = container

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0.5, -10, 0, 18)
	valLabel.Position = UDim2.new(0.5, 0, 0, 2)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(default)
	valLabel.TextColor3 = COLORS.accent
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 11
	valLabel.TextXAlignment = Enum.TextXAlignment.Right
	valLabel.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -20, 0, 6)
	track.Position = UDim2.new(0, 10, 0, 28)
	track.BackgroundColor3 = COLORS.border
	track.BorderSizePixel = 0
	track.Parent = container
	addCorner(track, 3)

	local fill = Instance.new("Frame")
	local pct = (default - min) / (max - min)
	fill.Size = UDim2.new(pct, 0, 1, 0)
	fill.BackgroundColor3 = COLORS.accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	addCorner(fill, 3)

	local sliderBtn = Instance.new("TextButton")
	sliderBtn.Size = UDim2.new(1, 0, 0, 20)
	sliderBtn.Position = UDim2.new(0, 0, 0, 20)
	sliderBtn.BackgroundTransparency = 1
	sliderBtn.Text = ""
	sliderBtn.Parent = container

	local dragging = false
	sliderBtn.MouseButton1Down:Connect(function() dragging = true end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local rel = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			rel = math.clamp(rel, 0, 1)
			fill.Size = UDim2.new(rel, 0, 1, 0)
			local val = math.floor(min + (max - min) * rel)
			valLabel.Text = tostring(val)
			if callback then callback(val) end
		end
	end)
end

local function createInfoLabel(parent, text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 18)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.textSecondary
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order or 0
	lbl.Parent = parent
end

-- ===================== HELPER FUNCTIONS =====================
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
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = msg,
			Duration = 3
		})
	end)
end

local function fireProximityPrompt(prompt)
	local holdDuration = prompt.HoldDuration
	prompt.HoldDuration = 0
	prompt:InputHoldBegin()
	prompt:InputHoldEnd()
	prompt.HoldDuration = holdDuration
end

-- Find all brainrots in workspace (they have ProximityPrompts)
local function findBrainrots()
	local brainrots = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			local parent = obj.Parent
			if parent and parent:IsA("BasePart") or parent:IsA("Model") then
				-- Check if it's likely a brainrot (not a shop/button)
				local root = parent
				if parent:IsA("Model") then
					root = parent:FindFirstChild("HumanoidRootPart") or parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
				end
				if root then
					table.insert(brainrots, {prompt = obj, part = root, name = parent.Name})
				end
			end
		end
	end
	return brainrots
end

-- Find brainrots NOT in our base
local function findStealableBrainrots()
	local brainrots = findBrainrots()
	local myBase = nil
	local hrp = getRoot()
	if not hrp then return {} end

	-- Filter: skip brainrots too close to us (our own base)
	local stealable = {}
	for _, b in ipairs(brainrots) do
		-- Only include brainrots that are in other players' bases
		if b.part and (b.part.Position - hrp.Position).Magnitude > 30 then
			table.insert(stealable, b)
		end
	end
	return stealable
end

-- ===================== INSTANT STEAL =====================
local function doInstantSteal()
	local ok, err = pcall(function()
		local hrp = getRoot()
		if not hrp then
			notify("Error", "No character found")
			return
		end

		if not savedBasePosition then
			savedBasePosition = hrp.Position
			notify("Base Saved", "Current position saved as base")
		end

		local originalPos = hrp.CFrame

		-- Find nearest stealable brainrot
		local brainrots = findStealableBrainrots()
		if #brainrots == 0 then
			notify("No Brainrots", "No stealable brainrots found nearby")
			return
		end

		-- Sort by distance
		table.sort(brainrots, function(a, b)
			return (a.part.Position - hrp.Position).Magnitude < (b.part.Position - hrp.Position).Magnitude
		end)

		local target = brainrots[1]
		notify("Stealing", "Going for: " .. target.name)

		-- Enable noclip temporarily
		local tempNoclip = RunService.Stepped:Connect(function()
			pcall(function()
				local char = LocalPlayer.Character
				if char then
					for _, part in ipairs(char:GetDescendants()) do
						if part:IsA("BasePart") then part.CanCollide = false end
					end
				end
			end)
		end)

		-- Teleport to brainrot
		hrp.CFrame = target.part.CFrame * CFrame.new(0, 0, -3)
		wait(0.3)

		-- Fire the proximity prompt instantly
		fireProximityPrompt(target.prompt)
		wait(0.2)

		-- Teleport back to base
		hrp.CFrame = CFrame.new(savedBasePosition)
		wait(0.1)

		-- Disable temp noclip
		tempNoclip:Disconnect()

		notify("Stolen!", "Grabbed " .. target.name)
		addLog("[STEAL] Grabbed: " .. target.name, COLORS.success)
	end)
	if not ok then
		warn("[STEAL ERROR] " .. tostring(err))
		notify("Error", tostring(err))
	end
end

-- ===================== AUTO FARM =====================
local function startAutoFarm()
	autoFarmActive = true
	spawn(function()
		while autoFarmActive do
			pcall(function()
				doInstantSteal()
			end)
			wait(3)
		end
	end)
	addLog("[AUTO FARM] ON", COLORS.success)
end

local function stopAutoFarm()
	autoFarmActive = false
	addLog("[AUTO FARM] OFF", COLORS.error)
end

-- ===================== NOCLIP =====================
local function startNoclip()
	noclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end)
	end)
	addLog("[NOCLIP] ON", COLORS.success)
end

local function stopNoclip()
	if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
	addLog("[NOCLIP] OFF", COLORS.error)
end

-- ===================== FLY =====================
local function startFly()
	local hrp = getRoot()
	local hum = getHumanoid()
	if not hrp or not hum then return end

	hum:ChangeState(Enum.HumanoidStateType.Freefall)

	flyConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local cam = workspace.CurrentCamera
			local look = cam.CFrame.LookVector
			local moveDir = hum.MoveDirection

			local velocity = Vector3.new(0, 0, 0)
			if moveDir.Magnitude > 0 then
				velocity = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * flySpeed
			end

			-- Up/down with jump/crouch
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				velocity = velocity + Vector3.new(0, flySpeed, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				velocity = velocity + Vector3.new(0, -flySpeed, 0)
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

-- ===================== SPEED BOOST =====================
local function startSpeedBoost()
	local hum = getHumanoid()
	if hum then hum.WalkSpeed = speedValue end
	speedConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local h = getHumanoid()
			if h then h.WalkSpeed = speedValue end
		end)
	end)
	addLog("[SPEED] ON - " .. speedValue, COLORS.success)
end

local function stopSpeedBoost()
	if speedConnection then speedConnection:Disconnect() speedConnection = nil end
	pcall(function()
		local h = getHumanoid()
		if h then h.WalkSpeed = 16 end
	end)
	addLog("[SPEED] OFF", COLORS.error)
end

-- ===================== ESP =====================
local function clearESP()
	for _, h in pairs(espHighlights) do pcall(function() h:Destroy() end) end
	espHighlights = {}
end

local function updatePlayerESP()
	clearESP()
	if not espActive then return end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			pcall(function()
				local highlight = Instance.new("Highlight")
				highlight.Name = "PlayerESP"
				highlight.Adornee = player.Character
				highlight.FillColor = Color3.fromRGB(255, 0, 0)
				highlight.FillTransparency = 0.5
				highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
				highlight.OutlineTransparency = 0
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = player.Character
				table.insert(espHighlights, highlight)

				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local bb = Instance.new("BillboardGui")
					bb.Name = "ESP_Name"
					bb.AlwaysOnTop = true
					bb.Size = UDim2.new(4, 0, 1, 0)
					bb.StudsOffset = Vector3.new(0, 3, 0)
					bb.Adornee = hrp
					bb.Parent = hrp
					table.insert(espHighlights, bb)

					local nameLabel = Instance.new("TextLabel")
					nameLabel.Text = player.DisplayName .. " [" .. math.floor((hrp.Position - (getRoot() and getRoot().Position or hrp.Position)).Magnitude) .. "m]"
					nameLabel.TextColor3 = Color3.new(1, 1, 1)
					nameLabel.TextStrokeTransparency = 0
					nameLabel.TextSize = 14
					nameLabel.Font = Enum.Font.GothamBold
					nameLabel.BackgroundTransparency = 1
					nameLabel.Size = UDim2.new(1, 0, 1, 0)
					nameLabel.Parent = bb
				end
			end)
		end
	end
end

local function startESP()
	updatePlayerESP()
	spawn(function()
		while espActive do
			updatePlayerESP()
			wait(2)
		end
	end)
	addLog("[ESP] ON", COLORS.success)
end

local function stopESP()
	clearESP()
	addLog("[ESP] OFF", COLORS.error)
end

-- ===================== BRAINROT ESP =====================
local function clearBrainrotESP()
	for _, h in pairs(brainrotHighlights) do pcall(function() h:Destroy() end) end
	brainrotHighlights = {}
end

local function updateBrainrotESP()
	clearBrainrotESP()
	if not brainrotEspActive then return end

	local brainrots = findBrainrots()
	for _, b in ipairs(brainrots) do
		pcall(function()
			local parent = b.part.Parent
			if parent and parent:IsA("Model") then
				local highlight = Instance.new("Highlight")
				highlight.Name = "BrainrotESP"
				highlight.Adornee = parent
				highlight.FillColor = Color3.fromRGB(255, 165, 0)
				highlight.FillTransparency = 0.3
				highlight.OutlineColor = COLORS.accent
				highlight.OutlineTransparency = 0
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = parent
				table.insert(brainrotHighlights, highlight)

				local bb = Instance.new("BillboardGui")
				bb.Name = "BrainrotESP_Name"
				bb.AlwaysOnTop = true
				bb.Size = UDim2.new(4, 0, 0.6, 0)
				bb.StudsOffset = Vector3.new(0, 3, 0)
				bb.Adornee = b.part
				bb.Parent = b.part
				table.insert(brainrotHighlights, bb)

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Text = b.name
				nameLabel.TextColor3 = COLORS.accent
				nameLabel.TextStrokeTransparency = 0
				nameLabel.TextSize = 12
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.BackgroundTransparency = 1
				nameLabel.Size = UDim2.new(1, 0, 1, 0)
				nameLabel.Parent = bb
			end
		end)
	end
end

local function startBrainrotESP()
	updateBrainrotESP()
	spawn(function()
		while brainrotEspActive do
			updateBrainrotESP()
			wait(3)
		end
	end)
	addLog("[BRAINROT ESP] ON", COLORS.success)
end

local function stopBrainrotESP()
	clearBrainrotESP()
	addLog("[BRAINROT ESP] OFF", COLORS.error)
end

-- ===================== AUTO LOCK BASE =====================
local function startAutoLock()
	autoLockConnection = spawn(function()
		while autoLockActive do
			pcall(function()
				-- Find lock prompts near our base
				local hrp = getRoot()
				if not hrp then return end
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("ProximityPrompt") and obj.ActionText and obj.ActionText:lower():find("lock") then
						local promptPart = obj.Parent
						if promptPart and promptPart:IsA("BasePart") then
							if (promptPart.Position - hrp.Position).Magnitude < 50 then
								fireProximityPrompt(obj)
							end
						end
					end
				end
			end)
			wait(5)
		end
	end)
	addLog("[AUTO LOCK] ON", COLORS.success)
end

local function stopAutoLock()
	autoLockActive = false
	addLog("[AUTO LOCK] OFF", COLORS.error)
end

-- ===================== ANTI HIT =====================
local function startAntiHit()
	antiHitConnection = RunService.Stepped:Connect(function()
		pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					for _, part in ipairs(player.Character:GetDescendants()) do
						if part:IsA("BasePart") then
							part.CanCollide = false
						end
					end
				end
			end
		end)
	end)
	addLog("[ANTI HIT] ON", COLORS.success)
end

local function stopAntiHit()
	if antiHitConnection then antiHitConnection:Disconnect() antiHitConnection = nil end
	addLog("[ANTI HIT] OFF", COLORS.error)
end

-- ===================== BUILD MAIN TAB =====================
do
	local tab = tabFrames["Main"]
	createSectionLabel(tab, "Info", 1)
	createInfoLabel(tab, "Player: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")", 2)
	createInfoLabel(tab, "Game: Steal a Brainrot", 3)
	createInfoLabel(tab, "Right Shift to toggle window", 4)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 5
	spacer.Parent = tab

	createSectionLabel(tab, "Quick Actions", 6)
	createButton(tab, "Save Base Position", 7, function()
		local hrp = getRoot()
		if hrp then
			savedBasePosition = hrp.Position
			notify("Saved", "Base position saved!")
			addLog("[BASE] Position saved", COLORS.success)
		end
	end)
	createButton(tab, "Teleport to Base", 8, function()
		if savedBasePosition then
			local hrp = getRoot()
			if hrp then hrp.CFrame = CFrame.new(savedBasePosition) end
		else
			notify("Error", "Save base position first!")
		end
	end)
end

-- ===================== BUILD STEAL TAB =====================
do
	local tab = tabFrames["Steal"]
	createSectionLabel(tab, "Stealing", 1)
	createButton(tab, "Instant Steal (Nearest)", 2, doInstantSteal)
	createToggle(tab, "Auto Farm (Loop Steal)", 3, function(on)
		autoFarmActive = on
		if on then startAutoFarm() else stopAutoFarm() end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

	createSectionLabel(tab, "Defense", 5)
	createToggle(tab, "Auto Lock Base", 6, function(on)
		autoLockActive = on
		if on then startAutoLock() else stopAutoLock() end
	end)
	createToggle(tab, "Anti Hit (No Player Collision)", 7, function(on)
		antiHitActive = on
		if on then startAntiHit() else stopAntiHit() end
	end)
end

-- ===================== BUILD MOVEMENT TAB =====================
do
	local tab = tabFrames["Movement"]
	createSectionLabel(tab, "Movement", 1)
	createToggle(tab, "Noclip", 2, function(on)
		noclipActive = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "Fly (Space=Up, Shift=Down)", 3, function(on)
		flyActive = on
		if on then startFly() else stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 200, flySpeed, 4, function(val) flySpeed = val end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 5
	spacer.Parent = tab

	createSectionLabel(tab, "Speed", 6)
	createToggle(tab, "Speed Boost", 7, function(on)
		speedBoostActive = on
		if on then startSpeedBoost() else stopSpeedBoost() end
	end)
	createSlider(tab, "Walk Speed", 16, 350, speedValue, 8, function(val) speedValue = val end)
end

-- ===================== BUILD ESP TAB =====================
do
	local tab = tabFrames["ESP"]
	createSectionLabel(tab, "Player ESP", 1)
	createToggle(tab, "Player ESP (Highlights + Names)", 2, function(on)
		espActive = on
		if on then startESP() else stopESP() end
	end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 3
	spacer.Parent = tab

	createSectionLabel(tab, "Brainrot ESP", 4)
	createToggle(tab, "Brainrot ESP (See All Brainrots)", 5, function(on)
		brainrotEspActive = on
		if on then startBrainrotESP() else stopBrainrotESP() end
	end)
end

-- ===================== MINIMIZE / TOGGLE =====================
local contentVisible = true
minimizeBtn.MouseButton1Click:Connect(function()
	contentVisible = not contentVisible
	for _, frame in pairs(tabFrames) do
		frame.Visible = contentVisible and frame == tabFrames[activeTab]
	end
	tabBar.Visible = contentVisible
	mainFrame.Size = contentVisible and UDim2.new(0, 480, 0, 380) or UDim2.new(0, 480, 0, 32)
	minimizeBtn.Text = contentVisible and "-" or "+"
end)

-- Right Shift to toggle visibility
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		windowVisible = not windowVisible
		mainFrame.Visible = windowVisible
	end
end)

-- Cleanup on respawn
LocalPlayer.CharacterAdded:Connect(function()
	if noclipActive then stopNoclip() wait(0.5) startNoclip() end
	if flyActive then stopFly() wait(0.5) startFly() end
	if speedBoostActive then wait(0.3) startSpeedBoost() end
end)

-- ===================== STARTUP =====================
notify("Steal a Brainrot Hub", "Loaded! Right Shift to toggle")
addLog("Steal a Brainrot Hub v1.0 loaded", COLORS.accent)
addLog("Save your base position first!", COLORS.textSecondary)
print("[Steal a Brainrot Hub] Loaded v1.0")
print("[Steal a Brainrot Hub] Right Shift to toggle window")
