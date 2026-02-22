-- ================================================================
-- Steal a Brainrot - Admin Panel Tool v1.0
-- Standalone admin spammer + defense mechanism
-- Works ONLY in Steal a Brainrot
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
local adminSpamActive = false
local adminDefenseActive = false
local adminSpamSpeed = 1.2
local adminSpamTarget = "random"
local defenseRadius = 40
local savedBasePosition = nil
local windowVisible = true

-- ===================== HELPERS =====================
local function getRoot()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function notify(title, msg)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = msg, Duration = 3})
	end)
end

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SABAdmin"
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
mainFrame.Size = UDim2.new(0, 420, 0, 450)
mainFrame.Position = UDim2.new(0.5, -210, 0.5, -225)
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
titleText.Text = "SAB Admin Tool v1.0"
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

-- ===================== CONTENT SCROLL =====================
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -16, 1, -40)
content.Position = UDim2.new(0, 8, 0, 34)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = COLORS.accent
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = content

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 4)
padding.PaddingRight = UDim.new(0, 4)
padding.PaddingTop = UDim.new(0, 4)
padding.Parent = content

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

-- ===================== CHAT MESSAGE =====================
-- Sends a message through Roblox chat (admin commands go through chat)
-- Tries multiple methods to maximize compatibility across executors

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

	-- Method 3: StarterGui ChatMakeSystemMessage workaround
	-- Some games process chat via the old ChatService
	pcall(function()
		local chatService = game:GetService("Chat")
		if chatService then
			chatService:Chat(LocalPlayer.Character or LocalPlayer, msg)
			sent = true
		end
	end)
end

-- ===================== ADMIN COMMANDS =====================
local ADMIN_COMMANDS = {
	"rocket", "ragdoll", "balloon", "inverse",
	"jail", "jumpscare", "tiny", "morph", "control"
}

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
	local targets = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			table.insert(targets, p.Name)
		end
	end
	if #targets == 0 then return nil end
	return targets[math.random(1, #targets)]
end

local function fireAdminCommand(cmd)
	local target = adminSpamTarget == "random" and getRandomTarget() or adminSpamTarget
	if not target then notify("Error", "No players to target") return end
	sendChatMessage(";" .. cmd .. " " .. target)
	notify("Admin", ";" .. cmd .. " " .. target)
end

local function fireAdminOnPlayer(cmd, playerName)
	sendChatMessage(";" .. cmd .. " " .. playerName)
end

-- ===================== ADMIN SPAMMER =====================
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

				local cmd = cmds[math.random(1, #cmds)]
				sendChatMessage(";" .. cmd .. " " .. target)
			end)
			-- Randomized delay to avoid spam detection
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

-- ===================== ADMIN DEFENSE =====================
local defenseCommandOrder = {"balloon", "rocket", "jail", "ragdoll", "inverse", "tiny", "jumpscare", "morph", "control"}
local defenseCooldowns = {}
local DEFENSE_COOLDOWN = 3
local defenseCommandIndex = {}

local function startAdminDefense()
	adminDefenseActive = true
	spawn(function()
		while adminDefenseActive do
			pcall(function()
				local hrp = getRoot()
				if not hrp then return end

				local basePos = savedBasePosition or hrp.Position

				for _, player in ipairs(Players:GetPlayers()) do
					if player ~= LocalPlayer and player.Character then
						local otherHrp = player.Character:FindFirstChild("HumanoidRootPart")
						if otherHrp then
							local dist = (otherHrp.Position - basePos).Magnitude
							if dist <= defenseRadius then
								local now = tick()
								local lastFire = defenseCooldowns[player.Name]
								if not lastFire or (now - lastFire) >= DEFENSE_COOLDOWN then
									local idx = defenseCommandIndex[player.Name] or 1
									local cmd = defenseCommandOrder[idx]

									fireAdminOnPlayer(cmd, player.Name)
									notify("Defense", ";" .. cmd .. " " .. player.DisplayName .. " (near base!)")

									defenseCooldowns[player.Name] = now
									defenseCommandIndex[player.Name] = (idx % #defenseCommandOrder) + 1
								end
							end
						end
					end
				end
			end)
			-- Randomized scan interval
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

-- ===================== BUILD GUI =====================
do
	local tab = content

	-- ===== BASE =====
	createSectionLabel(tab, "Base Position", 1)
	createInfoLabel(tab, "Save your base to enable defense", 2)
	createButton(tab, "Save Base Position", 3, function()
		local hrp = getRoot()
		if hrp then
			savedBasePosition = hrp.Position
			notify("Saved", "Base position saved!")
		end
	end)

	local spacer1 = Instance.new("Frame")
	spacer1.Size = UDim2.new(1, 0, 0, 8)
	spacer1.BackgroundTransparency = 1
	spacer1.LayoutOrder = 4
	spacer1.Parent = tab

	-- ===== TARGET PICKER =====
	createSectionLabel(tab, "Target Player", 5)
	local targetLabel = Instance.new("TextLabel")
	targetLabel.Size = UDim2.new(1, 0, 0, 22)
	targetLabel.BackgroundColor3 = COLORS.panel
	targetLabel.BorderSizePixel = 0
	targetLabel.Text = "  Current Target: Random"
	targetLabel.TextColor3 = COLORS.accent
	targetLabel.Font = Enum.Font.GothamBold
	targetLabel.TextSize = 12
	targetLabel.TextXAlignment = Enum.TextXAlignment.Left
	targetLabel.LayoutOrder = 6
	targetLabel.Parent = tab
	addCorner(targetLabel, 5)

	local playerListFrame = Instance.new("Frame")
	playerListFrame.Size = UDim2.new(1, 0, 0, 120)
	playerListFrame.BackgroundColor3 = COLORS.bgSecondary
	playerListFrame.BorderSizePixel = 0
	playerListFrame.LayoutOrder = 7
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
		for _, child in ipairs(playerScroll:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end

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
	createButton(tab, "Refresh Player List", 8, refreshPlayerList)

	Players.PlayerAdded:Connect(function() wait(1) refreshPlayerList() end)
	Players.PlayerRemoving:Connect(function(player)
		if adminSpamTarget == player.Name then
			adminSpamTarget = "random"
			targetLabel.Text = "  Current Target: Random"
		end
		wait(0.5)
		refreshPlayerList()
	end)

	local spacer2 = Instance.new("Frame")
	spacer2.Size = UDim2.new(1, 0, 0, 8)
	spacer2.BackgroundTransparency = 1
	spacer2.LayoutOrder = 9
	spacer2.Parent = tab

	-- ===== AUTO SPAM =====
	createSectionLabel(tab, "Admin Spammer", 10)
	createInfoLabel(tab, "Requires Admin Panel gamepass (;cmds)", 11)
	createToggle(tab, "Auto Spam Commands", 12, function(on)
		adminSpamActive = on
		if on then startAdminSpam() else stopAdminSpam() end
	end)
	createSlider(tab, "Spam Speed (x10 = seconds)", 3, 30, math.floor(adminSpamSpeed * 10), 13, function(val)
		adminSpamSpeed = val / 10
	end)
	createInfoLabel(tab, "Fires random commands at target with jittered delay", 14)

	local spacer3 = Instance.new("Frame")
	spacer3.Size = UDim2.new(1, 0, 0, 8)
	spacer3.BackgroundTransparency = 1
	spacer3.LayoutOrder = 15
	spacer3.Parent = tab

	-- ===== DEFENSE =====
	createSectionLabel(tab, "Admin Defense (Auto-Guard)", 16)
	createInfoLabel(tab, "Auto fires commands on anyone near your base", 17)
	createInfoLabel(tab, "Order: balloon > rocket > jail > ragdoll > ...", 18)
	createToggle(tab, "Admin Defense", 19, function(on)
		adminDefenseActive = on
		if on then startAdminDefense() else stopAdminDefense() end
	end)
	createSlider(tab, "Defense Radius (studs)", 10, 100, defenseRadius, 20, function(val)
		defenseRadius = val
	end)
	createInfoLabel(tab, "Save base position first!", 21)

	local spacer4 = Instance.new("Frame")
	spacer4.Size = UDim2.new(1, 0, 0, 8)
	spacer4.BackgroundTransparency = 1
	spacer4.LayoutOrder = 22
	spacer4.Parent = tab

	-- ===== QUICK ADMIN =====
	createSectionLabel(tab, "Quick Admin (One-Shot)", 23)
	createButton(tab, ";rocket (Launch Player)", 24, function() fireAdminCommand("rocket") end)
	createButton(tab, ";jail (Trap in Cage)", 25, function() fireAdminCommand("jail") end)
	createButton(tab, ";ragdoll (Knock Down)", 26, function() fireAdminCommand("ragdoll") end)
	createButton(tab, ";jumpscare (Scare Player)", 27, function() fireAdminCommand("jumpscare") end)
	createButton(tab, ";tiny (Shrink Player)", 28, function() fireAdminCommand("tiny") end)
	createButton(tab, ";morph (Transform Player)", 29, function() fireAdminCommand("morph") end)
	createButton(tab, ";balloon (Inflate Head)", 30, function() fireAdminCommand("balloon") end)
	createButton(tab, ";inverse (Reverse Controls)", 31, function() fireAdminCommand("inverse") end)
	createButton(tab, ";control (Possess Player)", 32, function() fireAdminCommand("control") end)
	createInfoLabel(tab, "Fires at selected target above", 33)
end

-- ===================== MINIMIZE / TOGGLE =====================
local contentVisible = true
minimizeBtn.MouseButton1Click:Connect(function()
	contentVisible = not contentVisible
	content.Visible = contentVisible
	mainFrame.Size = contentVisible and UDim2.new(0, 420, 0, 450) or UDim2.new(0, 420, 0, 32)
	minimizeBtn.Text = contentVisible and "-" or "+"
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		windowVisible = not windowVisible
		mainFrame.Visible = windowVisible
	end
end)

-- ===================== STARTUP =====================
notify("SAB Admin v1.0", "Loaded! RightCtrl to toggle")
print("[SAB Admin v1.0] Loaded - Right Ctrl to toggle window")
print("[SAB Admin v1.0] Save base position, pick target, enable spam/defense!")
