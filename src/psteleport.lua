-- ================================================================
-- Pebbleford Hub - Private Server Teleporter
-- Paste a private server share link and teleport into it
-- v1.0
-- ================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- ===================== COLOR PALETTE (Purple Theme) =====================
local COLORS = {
	bg = Color3.fromRGB(18, 16, 24),
	bgSecondary = Color3.fromRGB(30, 26, 40),
	inputBg = Color3.fromRGB(24, 21, 32),
	accent = Color3.fromRGB(150, 90, 240),
	accentHover = Color3.fromRGB(175, 120, 255),
	accentDark = Color3.fromRGB(110, 60, 190),
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(180, 175, 195),
	textDim = Color3.fromRGB(120, 116, 135),
	border = Color3.fromRGB(60, 50, 80),
	error = Color3.fromRGB(255, 80, 80),
	success = Color3.fromRGB(90, 230, 130),
	warn = Color3.fromRGB(255, 200, 90),
}

-- ===================== MOBILE / RESIZE DETECTION =====================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local ORIG_W = 440
local ORIG_H = 300
local windowW = ORIG_W
local windowH = ORIG_H
if isMobile then
	windowW = math.min(math.floor(screenSize.X * 0.92), ORIG_W)
	windowH = math.min(math.floor(screenSize.Y * 0.7), ORIG_H)
	if windowW < 300 then windowW = 300 end
	if windowH < 240 then windowH = 240 end
end

-- ===================== SCREEN GUI =====================
-- Resolve the most reliable GUI container for the current executor.
-- Mobile executors often block CoreGui parenting, so prefer gethui() and
-- fall back through CoreGui to PlayerGui.
local function getGuiParent()
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()

pcall(function()
	local old = guiParent:FindFirstChild("SXPrivateTP")
	if old then old:Destroy() end
end)
pcall(function()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if pg and pg:FindFirstChild("SXPrivateTP") then pg.SXPrivateTP:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SXPrivateTP"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
if typeof(syn) == "table" and syn.protect_gui then pcall(syn.protect_gui, screenGui) end
pcall(function() screenGui.Parent = guiParent end)
if not screenGui.Parent then
	pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
end
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

-- ===================== MAIN WINDOW =====================
local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.new(0, windowW, 0, windowH)
window.Position = UDim2.new(0.5, -windowW / 2, 0.5, -windowH / 2)
window.BackgroundColor3 = COLORS.bg
window.BorderSizePixel = 0
window.Active = true
window.Parent = screenGui
addCorner(window, 10)
addStroke(window, COLORS.border, 1)

-- ===================== TITLE BAR =====================
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = COLORS.bgSecondary
titleBar.BorderSizePixel = 0
titleBar.Parent = window
addCorner(titleBar, 10)

local titleBarFix = Instance.new("Frame")
titleBarFix.Size = UDim2.new(1, 0, 0, 12)
titleBarFix.Position = UDim2.new(0, 0, 1, -12)
titleBarFix.BackgroundColor3 = COLORS.bgSecondary
titleBarFix.BorderSizePixel = 0
titleBarFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -90, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Private Server Teleporter"
titleLabel.TextColor3 = COLORS.textPrimary
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 36, 1, 0)
versionLabel.Position = UDim2.new(1, -78, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.0"
versionLabel.TextColor3 = COLORS.textDim
versionLabel.TextSize = 12
versionLabel.Font = Enum.Font.Gotham
versionLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.textPrimary
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = true
closeBtn.Parent = titleBar
addCorner(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

-- ===================== CONTENT =====================
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, 0, 1, -40)
content.Position = UDim2.new(0, 0, 0, 40)
content.BackgroundTransparency = 1
content.Parent = window
addPadding(content, 14, 14, 14, 14)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 0, 36)
infoLabel.Position = UDim2.new(0, 0, 0, 0)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Paste a private server link below, then press Teleport."
infoLabel.TextColor3 = COLORS.textSecondary
infoLabel.TextSize = 13
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextWrapped = true
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = content

-- Link input box
local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, 0, 0, 78)
inputFrame.Position = UDim2.new(0, 0, 0, 42)
inputFrame.BackgroundColor3 = COLORS.inputBg
inputFrame.BorderSizePixel = 0
inputFrame.Parent = content
addCorner(inputFrame, 8)
addStroke(inputFrame, COLORS.border, 1)
addPadding(inputFrame, 8, 10, 8, 10)

local linkBox = Instance.new("TextBox")
linkBox.Name = "LinkBox"
linkBox.Size = UDim2.new(1, 0, 1, 0)
linkBox.BackgroundTransparency = 1
linkBox.Text = ""
linkBox.PlaceholderText = "https://www.roblox.com/games/... ?privateServerLinkCode=..."
linkBox.PlaceholderColor3 = COLORS.textDim
linkBox.TextColor3 = COLORS.textPrimary
linkBox.TextSize = 13
linkBox.Font = Enum.Font.Gotham
linkBox.ClearTextOnFocus = false
linkBox.MultiLine = true
linkBox.TextWrapped = true
linkBox.TextXAlignment = Enum.TextXAlignment.Left
linkBox.TextYAlignment = Enum.TextYAlignment.Top
linkBox.Parent = inputFrame

-- Teleport button
local tpBtn = Instance.new("TextButton")
tpBtn.Name = "Teleport"
tpBtn.Size = UDim2.new(1, 0, 0, 42)
tpBtn.Position = UDim2.new(0, 0, 0, 132)
tpBtn.BackgroundColor3 = COLORS.accent
tpBtn.Text = "Teleport"
tpBtn.TextColor3 = COLORS.textPrimary
tpBtn.TextSize = 16
tpBtn.Font = Enum.Font.GothamBold
tpBtn.BorderSizePixel = 0
tpBtn.AutoButtonColor = false
tpBtn.Parent = content
addCorner(tpBtn, 8)
tpBtn.MouseEnter:Connect(function() tpBtn.BackgroundColor3 = COLORS.accentHover end)
tpBtn.MouseLeave:Connect(function() tpBtn.BackgroundColor3 = COLORS.accent end)

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 40)
statusLabel.Position = UDim2.new(0, 0, 0, 184)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = COLORS.textSecondary
statusLabel.TextSize = 13
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = content

local function setStatus(msg, color)
	statusLabel.Text = msg
	statusLabel.TextColor3 = color or COLORS.textSecondary
end

-- ===================== LINK PARSING =====================
-- Extracts the place id and the private server link/access code from a
-- pasted Roblox share link. Supports the standard share URL format
-- (".../games/<placeId>/...?privateServerLinkCode=<code>") as well as
-- the older launch URL and a bare code being pasted on its own.
local function parseLink(raw)
	local link = tostring(raw):gsub("%s+", "")
	if link == "" then return nil, nil end

	local placeId = link:match("/games/(%d+)")
		or link:match("[?&]placeId=(%d+)")
		or link:match("[?&]PlaceId=(%d+)")

	local code = link:match("privateServerLinkCode=([%w%-_]+)")
		or link:match("[?&]accessCode=([%w%-_]+)")
		or link:match("[?&]linkCode=([%w%-_]+)")
		or link:match("[?&]code=([%w%-_]+)")

	-- If no URL pattern matched and the whole input looks like a bare code,
	-- treat it as the link code and use the current place.
	if not code and not placeId and link:match("^[%w%-_]+$") then
		code = link
	end

	return placeId and tonumber(placeId) or nil, code
end

local teleporting = false
local function doTeleport()
	if teleporting then return end

	local placeId, code = parseLink(linkBox.Text)
	if not code then
		setStatus("Couldn't find a private server code in that link. Make sure you copied the full share link.", COLORS.error)
		return
	end
	-- A private server link usually contains its own place id. Fall back to
	-- the current game's place if the link omitted it (e.g. a bare code).
	if not placeId then
		placeId = game.PlaceId
	end

	teleporting = true
	tpBtn.Text = "Teleporting..."
	tpBtn.BackgroundColor3 = COLORS.accentDark
	setStatus(("Teleporting to place %d..."):format(placeId), COLORS.warn)

	local ok, err = pcall(function()
		TeleportService:TeleportToPrivateServer(placeId, code, { LocalPlayer })
	end)

	if not ok then
		teleporting = false
		tpBtn.Text = "Teleport"
		tpBtn.BackgroundColor3 = COLORS.accent
		setStatus("Teleport failed: " .. tostring(err), COLORS.error)
	else
		setStatus("Teleport requested. If nothing happens, the link may be expired or for a different game.", COLORS.success)
	end
end

tpBtn.MouseButton1Click:Connect(doTeleport)
linkBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then doTeleport() end
end)

-- Surface teleport errors raised asynchronously by the engine.
TeleportService.TeleportInitFailed:Connect(function(player, result, msg)
	if player == LocalPlayer then
		teleporting = false
		tpBtn.Text = "Teleport"
		tpBtn.BackgroundColor3 = COLORS.accent
		setStatus("Teleport failed: " .. tostring(msg), COLORS.error)
	end
end)

-- ===================== DRAGGING =====================
local dragging = false
local dragStart, startPos
titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = window.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		window.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

setStatus("Ready.", COLORS.textDim)
