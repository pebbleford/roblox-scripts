-- PlayerHighlightESP + Fly + Fling
-- Draggable GUI with toggles and fling power slider

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local _spawn = (task and task.spawn) or spawn
local _wait = (task and task.wait) or wait

-- Config
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local FILL_TRANSPARENCY = 0.5
local OUTLINE_TRANSPARENCY = 0
local FLY_SPEED = 80
local REFRESH_INTERVAL = 5

-- State
local espEnabled = false
local flyEnabled = false
local flingEnabled = false
local speedEnabled = false
local flingPower = 500
local origWalkSpeed = 16
local highlights = {}
local nametags = {}
local espConnections = {}
local flyConnection = nil
local flingConnection = nil
local bodyGyro = nil
local bodyVelocity = nil

-- ===================== GUI =====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPFlyGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true

pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 170, 0, 250)
panel.Position = UDim2.new(0, 15, 0, 15)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(60, 60, 60)
panelStroke.Thickness = 2
panelStroke.Parent = panel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -10, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Tools"
titleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local function makeButton(name, text, yPos)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, -20, 0, 28)
	btn.Position = UDim2.new(0, 10, 0, yPos)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	btn.TextColor3 = Color3.fromRGB(255, 80, 80)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = text
	btn.Parent = panel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn
	return btn
end

local espButton = makeButton("ESP", "ESP: OFF", 35)
local flyButton = makeButton("FLY", "FLY: OFF", 70)
local flingButton = makeButton("FLING", "FLING: OFF", 105)
local speedButton = makeButton("SPEED", "SPEED: OFF", 140)

-- Fling power label
local powerLabel = Instance.new("TextLabel")
powerLabel.Size = UDim2.new(1, -20, 0, 16)
powerLabel.Position = UDim2.new(0, 10, 0, 173)
powerLabel.BackgroundTransparency = 1
powerLabel.Text = "Power: 500"
powerLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
powerLabel.Font = Enum.Font.Gotham
powerLabel.TextSize = 12
powerLabel.Parent = panel

-- Fling power slider
local sliderBg = Instance.new("Frame")
sliderBg.Name = "SliderBG"
sliderBg.Size = UDim2.new(1, -20, 0, 10)
sliderBg.Position = UDim2.new(0, 10, 0, 192)
sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
sliderBg.BorderSizePixel = 0
sliderBg.Parent = panel

local sliderBgCorner = Instance.new("UICorner")
sliderBgCorner.CornerRadius = UDim.new(0, 5)
sliderBgCorner.Parent = sliderBg

local sliderFill = Instance.new("Frame")
sliderFill.Name = "Fill"
sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(255, 100, 50)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg

local sliderFillCorner = Instance.new("UICorner")
sliderFillCorner.CornerRadius = UDim.new(0, 5)
sliderFillCorner.Parent = sliderFill

-- Min/Max labels
local minLabel = Instance.new("TextLabel")
minLabel.Size = UDim2.new(0.5, 0, 0, 14)
minLabel.Position = UDim2.new(0, 10, 0, 205)
minLabel.BackgroundTransparency = 1
minLabel.Text = "100"
minLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
minLabel.Font = Enum.Font.Gotham
minLabel.TextSize = 10
minLabel.TextXAlignment = Enum.TextXAlignment.Left
minLabel.Parent = panel

local maxLabel = Instance.new("TextLabel")
maxLabel.Size = UDim2.new(0.5, -10, 0, 14)
maxLabel.Position = UDim2.new(0.5, 0, 0, 205)
maxLabel.BackgroundTransparency = 1
maxLabel.Text = "1000"
maxLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
maxLabel.Font = Enum.Font.Gotham
maxLabel.TextSize = 10
maxLabel.TextXAlignment = Enum.TextXAlignment.Right
maxLabel.Parent = panel

-- Power input box
local powerBox = Instance.new("TextBox")
powerBox.Size = UDim2.new(1, -20, 0, 22)
powerBox.Position = UDim2.new(0, 10, 0, 221)
powerBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
powerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
powerBox.PlaceholderText = "Type power (100-9999)"
powerBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
powerBox.Font = Enum.Font.Gotham
powerBox.TextSize = 11
powerBox.Text = ""
powerBox.ClearTextOnFocus = true
powerBox.Parent = panel

local powerBoxCorner = Instance.new("UICorner")
powerBoxCorner.CornerRadius = UDim.new(0, 5)
powerBoxCorner.Parent = powerBox

-- Slider logic
do
	local draggingSlider = false

	local function updateSlider(inputX)
		local absPos = sliderBg.AbsolutePosition.X
		local absSize = sliderBg.AbsoluteSize.X
		local pct = (inputX - absPos) / absSize
		if pct < 0 then pct = 0 end
		if pct > 1 then pct = 1 end
		sliderFill.Size = UDim2.new(pct, 0, 1, 0)
		flingPower = math.floor(100 + pct * 900)
		powerLabel.Text = "Power: " .. flingPower
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
end

-- Power text input
powerBox.FocusLost:Connect(function()
	local num = tonumber(powerBox.Text)
	if num then
		if num < 100 then num = 100 end
		if num > 9999 then num = 9999 end
		flingPower = math.floor(num)
		powerLabel.Text = "Power: " .. flingPower
		local pct = (flingPower - 100) / 900
		if pct > 1 then pct = 1 end
		sliderFill.Size = UDim2.new(pct, 0, 1, 0)
	end
	powerBox.Text = ""
end)

-- =============== Draggable Panel ===============

do
	local dragging = false
	local dragStart, startPos

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = panel.Position
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
			panel.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- =============== ESP Logic ===============

local function addHighlight(player)
	if player == LocalPlayer then return end
	if highlights[player] then return end

	local character = player.Character
	if not character or not character.Parent then return end

	local ok2, err2 = pcall(function()
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
	if not ok2 then
		warn("[ESP] Highlight error " .. player.Name .. ": " .. tostring(err2))
	end
end

local function addNametag(player)
	if player == LocalPlayer then return end
	if nametags[player] then return end

	local character = player.Character
	if not character or not character.Parent then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	local ok2, err2 = pcall(function()
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
	if not ok2 then
		warn("[ESP] Nametag error " .. player.Name .. ": " .. tostring(err2))
	end
end

local function removeHighlight(player)
	local hl = highlights[player]
	if hl then
		pcall(function() hl:Destroy() end)
	end
	highlights[player] = nil
end

local function removeNametag(player)
	local tag = nametags[player]
	if tag then
		pcall(function() tag:Destroy() end)
	end
	nametags[player] = nil
end

local function cleanupStale()
	-- Collect stale keys first, THEN remove (safe iteration)
	local staleHL = {}
	local staleNT = {}
	for player, hl in pairs(highlights) do
		local alive = false
		pcall(function()
			if hl and hl.Adornee and hl.Adornee.Parent then
				alive = true
			end
		end)
		if not alive then
			table.insert(staleHL, player)
		end
	end
	for player, tag in pairs(nametags) do
		local alive = false
		pcall(function()
			if tag and tag.Parent then
				alive = true
			end
		end)
		if not alive then
			table.insert(staleNT, player)
		end
	end
	for _, player in ipairs(staleHL) do
		removeHighlight(player)
	end
	for _, player in ipairs(staleNT) do
		removeNametag(player)
	end
end

local function espScanAll()
	cleanupStale()
	local count = 0
	local skipped = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			if character and character.Parent then
				if not highlights[player] then
					addHighlight(player)
				end
				if not nametags[player] then
					addNametag(player)
				end
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
		if espEnabled then
			addHighlight(player)
			addNametag(player)
		end
	end)
	table.insert(espConnections, conn)
end

local function enableESP()
	-- Hook CharacterAdded for ALL players so streaming/respawns get caught instantly
	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end

	-- Also hook future players
	local addedConn = Players.PlayerAdded:Connect(function(player)
		if not espEnabled then return end
		hookPlayer(player)
	end)
	table.insert(espConnections, addedConn)

	-- Initial scan
	local count, skipped = espScanAll()
	print("[ESP] ON - " .. count .. " highlighted, " .. skipped .. " no character yet")

	-- Refresh loop as backup
	_spawn(function()
		while espEnabled do
			_wait(REFRESH_INTERVAL)
			if not espEnabled then break end
			local c, s = espScanAll()
			print("[ESP] Refreshed - " .. c .. " highlighted, " .. s .. " skipped")
		end
	end)
end

local function disableESP()
	-- Collect all players first then remove
	local allPlayers = {}
	for player in pairs(highlights) do
		table.insert(allPlayers, player)
	end
	for _, player in ipairs(allPlayers) do
		removeHighlight(player)
	end

	local allNT = {}
	for player in pairs(nametags) do
		table.insert(allNT, player)
	end
	for _, player in ipairs(allNT) do
		removeNametag(player)
	end

	for _, conn in ipairs(espConnections) do
		pcall(function() conn:Disconnect() end)
	end
	espConnections = {}
	print("[ESP] OFF")
end

-- =============== Fly Logic ===============

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
		bodyVelocity.Velocity = dir * FLY_SPEED
		bodyGyro.CFrame = cam.CFrame
	end)
end

local function stopFly()
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
	if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
end

-- =============== Fling Logic ===============
-- Walk-around fling: move freely with WASD, anything you touch gets launched
-- Works like Infinite Yield / Dinos Anim fling

local savedPhysics = {}

local function startFling()
	local character = LocalPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Save original physics and make character massless
	-- Massless = collisions push OTHERS, not you
	pcall(function()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				savedPhysics[part] = part.CustomPhysicalProperties
				part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 100, 100)
			end
		end
	end)

	-- Just spin via RotVelocity every frame, NO BodyPosition/BodyMovers
	-- This lets the Humanoid still control walking normally
	flingConnection = RunService.Heartbeat:Connect(function()
		if not flingEnabled then return end
		pcall(function()
			local myChar = LocalPlayer.Character
			if not myChar then return end
			local myHRP = myChar:FindFirstChild("HumanoidRootPart")
			if not myHRP then return end
			-- Spin rapidly - when you walk into things they get flung
			myHRP.RotVelocity = Vector3.new(flingPower, flingPower, flingPower)
		end)
	end)
	print("[FLING] ON - Power: " .. flingPower .. " (walk into things to fling them)")
end

local function stopFling()
	if flingConnection then flingConnection:Disconnect() flingConnection = nil end
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			-- Restore original physics
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					if savedPhysics[part] then
						part.CustomPhysicalProperties = savedPhysics[part]
					else
						part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
					end
				end
			end
			savedPhysics = {}
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.RotVelocity = Vector3.new(0, 0, 0)
				hrp.Velocity = Vector3.new(0, 0, 0)
			end
		end
	end)
	print("[FLING] OFF")
end

-- =============== Speed Logic ===============

local function startSpeed()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				origWalkSpeed = humanoid.WalkSpeed
				humanoid.WalkSpeed = 100
			end
		end
	end)
	print("[SPEED] ON - WalkSpeed: 100")
end

local function stopSpeed()
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = origWalkSpeed
			end
		end
	end)
	print("[SPEED] OFF")
end

-- ================== Button Toggles ==================

local function setBtn(btn, on, text)
	btn.Text = text
	btn.TextColor3 = on and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
	btn.BackgroundColor3 = on and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(45, 45, 45)
end

espButton.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	setBtn(espButton, espEnabled, espEnabled and "ESP: ON" or "ESP: OFF")
	if espEnabled then enableESP() else disableESP() end
end)

flyButton.MouseButton1Click:Connect(function()
	flyEnabled = not flyEnabled
	setBtn(flyButton, flyEnabled, flyEnabled and "FLY: ON" or "FLY: OFF")
	if flyEnabled then startFly() else stopFly() end
end)

flingButton.MouseButton1Click:Connect(function()
	flingEnabled = not flingEnabled
	setBtn(flingButton, flingEnabled, flingEnabled and "FLING: ON" or "FLING: OFF")
	if flingEnabled then startFling() else stopFling() end
end)

speedButton.MouseButton1Click:Connect(function()
	speedEnabled = not speedEnabled
	setBtn(speedButton, speedEnabled, speedEnabled and "SPEED: ON" or "SPEED: OFF")
	if speedEnabled then startSpeed() else stopSpeed() end
end)

-- =========== Cleanup / Respawn ===========

Players.PlayerRemoving:Connect(function(player)
	removeHighlight(player)
	removeNametag(player)
end)

LocalPlayer.CharacterAdded:Connect(function()
	if flyEnabled then
		stopFly()
		_wait(0.5)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			startFly()
		end
	end
	if flingEnabled then
		stopFling()
		_wait(0.5)
		startFling()
	end
	if speedEnabled then
		_wait(0.3)
		startSpeed()
	end
end)

print("[ESP] Script loaded")
