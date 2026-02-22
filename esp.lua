--[[
    PlayerHighlightESP
    Type: LocalScript
    Place inside: StarterGui

    Highlights every other player with a toggleable GUI button.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Config
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local FILL_TRANSPARENCY = 0.5
local OUTLINE_TRANSPARENCY = 0

-- State
local enabled = false
local highlights = {}
local nametags = {}
local connections = {}

-- ===================== GUI =====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HighlightToggleGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

local toggleFrame = Instance.new("Frame")
toggleFrame.Name = "ToggleFrame"
toggleFrame.Size = UDim2.new(0, 160, 0, 50)
toggleFrame.Position = UDim2.new(0, 15, 0, 15)
toggleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleFrame.BorderSizePixel = 0
toggleFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = toggleFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(80, 80, 80)
frameStroke.Thickness = 2
frameStroke.Parent = toggleFrame

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(1, -16, 1, -12)
toggleButton.Position = UDim2.new(0, 8, 0, 6)
toggleButton.BackgroundTransparency = 1
toggleButton.TextColor3 = Color3.fromRGB(255, 80, 80)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 18
toggleButton.Text = "ESP: OFF"
toggleButton.Parent = toggleFrame

-- =============== Highlight Logic ===============

local function addHighlight(player)
	if player == LocalPlayer then return end
	if highlights[player] then return end

	local character = player.Character
	if not character then return end
	if not character:FindFirstChild("HumanoidRootPart") then
		character:WaitForChild("HumanoidRootPart", 5)
	end
	if not character or not character.Parent then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ESPHighlight"
	highlight.FillColor = HIGHLIGHT_COLOR
	highlight.OutlineColor = OUTLINE_COLOR
	highlight.FillTransparency = FILL_TRANSPARENCY
	highlight.OutlineTransparency = OUTLINE_TRANSPARENCY
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = screenGui -- parent to GUI so it survives character resets

	highlights[player] = highlight
end

local function addNametag(player)
	if player == LocalPlayer then return end
	if nametags[player] then return end

	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESPNametag"
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = screenGui

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextScaled = false
	nameLabel.Parent = billboard

	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBarBG"
	healthBar.Size = UDim2.new(0.6, 0, 0, 6)
	healthBar.Position = UDim2.new(0.2, 0, 0.7, 0)
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

	-- Update health bar
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local function updateHealth()
			local pct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
			healthFill.Size = UDim2.new(pct, 0, 1, 0)
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
		table.insert(connections, conn)
	end

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

local function setupPlayer(player)
	if player == LocalPlayer then return end

	-- Highlight and nametag their current character
	if player.Character then
		addHighlight(player)
		addNametag(player)
	end

	-- Re-apply on every respawn
	local conn = player.CharacterAdded:Connect(function(character)
		-- Remove old instances
		removeHighlight(player)
		removeNametag(player)

		if not enabled then return end

		-- Wait for the character model to fully load
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)

		if enabled and character.Parent then
			addHighlight(player)
			addNametag(player)
		end
	end)

	table.insert(connections, conn)
end

local function enableAll()
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end
end

local function disableAll()
	removeAllHighlights()
	removeAllNametags()
	-- Disconnect respawn listeners
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	connections = {}
end

-- ================== Toggle ==================

local function toggle()
	enabled = not enabled

	if enabled then
		toggleButton.Text = "ESP: ON"
		toggleButton.TextColor3 = Color3.fromRGB(80, 255, 80)
		frameStroke.Color = Color3.fromRGB(0, 200, 80)
		enableAll()
	else
		toggleButton.Text = "ESP: OFF"
		toggleButton.TextColor3 = Color3.fromRGB(255, 80, 80)
		frameStroke.Color = Color3.fromRGB(80, 80, 80)
		disableAll()
	end
end

toggleButton.MouseButton1Click:Connect(toggle)

-- =========== New players / cleanup ===========

Players.PlayerAdded:Connect(function(player)
	if enabled then
		setupPlayer(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	removeHighlight(player)
	removeNametag(player)
end)
