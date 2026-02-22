-- PlayerHighlightESP.lua
-- LocalScript: Place in StarterPlayerScripts or StarterGui

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Config
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0)    -- Fill color
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)   -- Outline color
local FILL_TRANSPARENCY = 0.5
local OUTLINE_TRANSPARENCY = 0

-- State
local enabled = false
local highlights = {} -- [Player] = Highlight instance

-- ========== GUI ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HighlightToggleGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 140, 0, 40)
toggleButton.Position = UDim2.new(0, 10, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 16
toggleButton.Text = "ESP: OFF"
toggleButton.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = toggleButton

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 80, 80)
stroke.Thickness = 1
stroke.Parent = toggleButton

-- ========== Highlight Logic ==========

local function addHighlight(player)
	if player == LocalPlayer then return end
	if highlights[player] then return end

	local character = player.Character
	if not character then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ESPHighlight"
	highlight.FillColor = HIGHLIGHT_COLOR
	highlight.OutlineColor = OUTLINE_COLOR
	highlight.FillTransparency = FILL_TRANSPARENCY
	highlight.OutlineTransparency = OUTLINE_TRANSPARENCY
	highlight.Adornee = character
	highlight.Parent = character

	highlights[player] = highlight
end

local function removeHighlight(player)
	local highlight = highlights[player]
	if highlight then
		highlight:Destroy()
		highlights[player] = nil
	end
end

local function enableAll()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			addHighlight(player)

			-- Re-apply on respawn
			player.CharacterAdded:Connect(function()
				if enabled then
					task.wait(0.5) -- wait for character to load
					addHighlight(player)
				end
			end)
		end
	end
end

local function disableAll()
	for player, _ in pairs(highlights) do
		removeHighlight(player)
	end
end

-- ========== Toggle ==========

local function toggle()
	enabled = not enabled

	if enabled then
		toggleButton.Text = "ESP: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(0, 140, 60)
		stroke.Color = Color3.fromRGB(0, 200, 80)
		enableAll()
	else
		toggleButton.Text = "ESP: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		stroke.Color = Color3.fromRGB(80, 80, 80)
		disableAll()
	end
end

toggleButton.MouseButton1Click:Connect(toggle)

-- ========== Handle new players joining ==========

Players.PlayerAdded:Connect(function(player)
	if not enabled then return end

	player.CharacterAdded:Connect(function()
		if enabled then
			task.wait(0.5)
			addHighlight(player)
		end
	end)

	if player.Character then
		addHighlight(player)
	end
end)

-- ========== Cleanup when players leave ==========

Players.PlayerRemoving:Connect(function(player)
	removeHighlight(player)
end)
