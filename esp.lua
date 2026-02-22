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

	-- Highlight their current character
	if player.Character then
		addHighlight(player)
	end

	-- Re-apply on every respawn
	local conn = player.CharacterAdded:Connect(function(character)
		-- Remove old highlight reference
		removeHighlight(player)

		if not enabled then return end

		-- Wait for the character model to fully load
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)

		if enabled and character.Parent then
			addHighlight(player)
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
end)
