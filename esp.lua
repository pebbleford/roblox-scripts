-- PlayerHighlightESP + Fly
-- LocalScript - Place inside StarterGui
-- Toggle ESP and Fly with draggable GUI buttons

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ESP Config
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local FILL_TRANSPARENCY = 0.5
local OUTLINE_TRANSPARENCY = 0

-- Fly Config
local FLY_SPEED = 80

-- ESP Refresh Config
local REFRESH_INTERVAL = 5

-- State
local espEnabled = false
local flyEnabled = false
local highlights = {}
local nametags = {}
local espConnections = {}
local refreshThread = nil
local flyConnection = nil
local bodyGyro = nil
local bodyVelocity = nil

-- ===================== GUI =====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPFlyGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 170, 0, 110)
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

-- Title bar (drag handle)
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
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -10, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Tools"
titleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- ESP Button
local espButton = Instance.new("TextButton")
espButton.Name = "ESPButton"
espButton.Size = UDim2.new(1, -20, 0, 30)
espButton.Position = UDim2.new(0, 10, 0, 35)
espButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
espButton.TextColor3 = Color3.fromRGB(255, 80, 80)
espButton.Font = Enum.Font.GothamBold
espButton.TextSize = 15
espButton.Text = "ESP: OFF"
espButton.Parent = panel

local espCorner = Instance.new("UICorner")
espCorner.CornerRadius = UDim.new(0, 6)
espCorner.Parent = espButton

-- Fly Button
local flyButton = Instance.new("TextButton")
flyButton.Name = "FlyButton"
flyButton.Size = UDim2.new(1, -20, 0, 30)
flyButton.Position = UDim2.new(0, 10, 0, 72)
flyButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
flyButton.TextColor3 = Color3.fromRGB(255, 80, 80)
flyButton.Font = Enum.Font.GothamBold
flyButton.TextSize = 15
flyButton.Text = "FLY: OFF"
flyButton.Parent = panel

local flyCorner = Instance.new("UICorner")
flyCorner.CornerRadius = UDim.new(0, 6)
flyCorner.Parent = flyButton

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

-- =============== ESP: Highlight Logic ===============

local function addHighlight(player)
	if player == LocalPlayer then return end
	if highlights[player] then return end

	local character = player.Character
	if not character or not character.Parent then return end
	if not character:FindFirstChild("HumanoidRootPart") then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ESPHighlight"
	highlight.FillColor = HIGHLIGHT_COLOR
	highlight.OutlineColor = OUTLINE_COLOR
	highlight.FillTransparency = FILL_TRANSPARENCY
	highlight.OutlineTransparency = OUTLINE_TRANSPARENCY
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = screenGui

	highlights[player] = highlight
end

local function addNametag(player)
	if player == LocalPlayer then return end
	if nametags[player] then return end

	local character = player.Character
	if not character then return end

	if not character:FindFirstChild("HumanoidRootPart") then return end
	local head = character:FindFirstChild("Head")
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESPNametag"
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 200, 0, 70)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = screenGui

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 18)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.Parent = billboard

	-- Health text
	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "HealthLabel"
	healthLabel.Size = UDim2.new(1, 0, 0, 14)
	healthLabel.Position = UDim2.new(0, 0, 0, 19)
	healthLabel.BackgroundTransparency = 1
	healthLabel.Text = "? / ?"
	healthLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	healthLabel.TextStrokeTransparency = 0.4
	healthLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	healthLabel.Font = Enum.Font.Gotham
	healthLabel.TextSize = 12
	healthLabel.Parent = billboard

	-- Health bar
	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBarBG"
	healthBar.Size = UDim2.new(0.7, 0, 0, 6)
	healthBar.Position = UDim2.new(0.15, 0, 0, 36)
	healthBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = billboard

	local healthBarCorner = Instance.new("UICorner")
	healthBarCorner.CornerRadius = UDim.new(0, 3)
	healthBarCorner.Parent = healthBar

	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBar

	local healthFillCorner = Instance.new("UICorner")
	healthFillCorner.CornerRadius = UDim.new(0, 3)
	healthFillCorner.Parent = healthFill

	-- Distance label
	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "DistLabel"
	distLabel.Size = UDim2.new(1, 0, 0, 14)
	distLabel.Position = UDim2.new(0, 0, 0, 45)
	distLabel.BackgroundTransparency = 1
	distLabel.Text = "[0m]"
	distLabel.TextColor3 = Color3.fromRGB(170, 170, 255)
	distLabel.TextStrokeTransparency = 0.4
	distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	distLabel.Font = Enum.Font.Gotham
	distLabel.TextSize = 12
	distLabel.Parent = billboard

	-- Update health bar + health text
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local function updateHealth()
			local pct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
			healthFill.Size = UDim2.new(pct, 0, 1, 0)
			healthLabel.Text = math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
			if pct > 0.5 then
				healthFill.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
			elseif pct > 0.25 then
				healthFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
			else
				healthFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			end
		end
		updateHealth()
		local conn = humanoid.HealthChanged:Connect(updateHealth)
		table.insert(espConnections, conn)
	end

	-- Update distance every frame
	local distConn = RunService.Heartbeat:Connect(function()
		if not billboard.Parent then return end

		local myChar = LocalPlayer.Character
		local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local theirRoot = character and character:FindFirstChild("HumanoidRootPart")

		if myRoot and theirRoot then
			local dist = math.floor((myRoot.Position - theirRoot.Position).Magnitude)
			distLabel.Text = "[" .. dist .. "m]"
		else
			distLabel.Text = "[?m]"
		end
	end)
	table.insert(espConnections, distConn)

	nametags[player] = billboard
end

local function removeNametag(player)
	local tag = nametags[player]
	if tag then
		tag:Destroy()
		nametags[player] = nil
	end
end

local function removeAllNametags()
	for player in pairs(nametags) do
		removeNametag(player)
	end
end

local function removeHighlight(player)
	local hl = highlights[player]
	if hl then
		hl:Destroy()
		highlights[player] = nil
	end
end

local function removeAllHighlights()
	for player in pairs(highlights) do
		removeHighlight(player)
	end
end

local function espScanAll()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			if character and character.Parent and character:FindFirstChild("HumanoidRootPart") then
				if not highlights[player] then
					addHighlight(player)
				end
				if not nametags[player] then
					addNametag(player)
				end
			end
		end
	end
end

local function enableESP()
	espScanAll()

	-- Refresh loop: pick up new players and respawns every N seconds
	refreshThread = task.spawn(function()
		while espEnabled do
			task.wait(REFRESH_INTERVAL)
			if not espEnabled then break end
			espScanAll()
		end
	end)
end

local function disableESP()
	removeAllHighlights()
	removeAllNametags()
	for _, conn in ipairs(espConnections) do
		conn:Disconnect()
	end
	espConnections = {}
	refreshThread = nil
end

-- =============== Fly Logic ===============

local function startFly()
	local character = LocalPlayer.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	-- Prevent falling
	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.P = 9e4
	bodyGyro.Parent = hrp

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.Parent = hrp

	flyConnection = RunService.Heartbeat:Connect(function()
		if not flyEnabled then return end
		if not hrp or not hrp.Parent then return end

		local camera = workspace.CurrentCamera
		local moveDir = Vector3.new(0, 0, 0)

		-- WASD movement relative to camera
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveDir = moveDir + camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveDir = moveDir - camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveDir = moveDir - camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveDir = moveDir + camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			moveDir = moveDir + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			moveDir = moveDir - Vector3.new(0, 1, 0)
		end

		if moveDir.Magnitude > 0 then
			moveDir = moveDir.Unit
		end

		bodyVelocity.Velocity = moveDir * FLY_SPEED
		bodyGyro.CFrame = camera.CFrame
	end)
end

local function stopFly()
	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end
	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
end

-- ================== Toggles ==================

espButton.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	if espEnabled then
		espButton.Text = "ESP: ON"
		espButton.TextColor3 = Color3.fromRGB(80, 255, 80)
		espButton.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
		enableESP()
	else
		espButton.Text = "ESP: OFF"
		espButton.TextColor3 = Color3.fromRGB(255, 80, 80)
		espButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		disableESP()
	end
end)

flyButton.MouseButton1Click:Connect(function()
	flyEnabled = not flyEnabled
	if flyEnabled then
		flyButton.Text = "FLY: ON"
		flyButton.TextColor3 = Color3.fromRGB(80, 255, 80)
		flyButton.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
		startFly()
	else
		flyButton.Text = "FLY: OFF"
		flyButton.TextColor3 = Color3.fromRGB(255, 80, 80)
		flyButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		stopFly()
	end
end)

-- =========== Cleanup when players leave ===========

Players.PlayerRemoving:Connect(function(player)
	removeHighlight(player)
	removeNametag(player)
end)

-- Stop fly if character dies/resets
LocalPlayer.CharacterAdded:Connect(function()
	if flyEnabled then
		stopFly()
		task.wait(0.5)
		local character = LocalPlayer.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			startFly()
		end
	end
end)
