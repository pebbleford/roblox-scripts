-- ================================================================
-- NBTF Hub v1.0 - Nuclear Blast Testing Facility
-- Silent Aim | Wallbang | ESP | Aimbot | Fly | Teleports
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ===================== COLOR PALETTE =====================
local COLORS = {
	bg = Color3.fromRGB(12, 12, 18),
	bgSecondary = Color3.fromRGB(18, 18, 28),
	panel = Color3.fromRGB(28, 28, 42),
	accent = Color3.fromRGB(0, 180, 255),
	accentHover = Color3.fromRGB(40, 200, 255),
	textPrimary = Color3.fromRGB(230, 240, 255),
	textSecondary = Color3.fromRGB(140, 150, 180),
	textDim = Color3.fromRGB(90, 100, 130),
	border = Color3.fromRGB(40, 40, 60),
	toggleOn = Color3.fromRGB(0, 180, 255),
	toggleOff = Color3.fromRGB(60, 60, 80),
	error = Color3.fromRGB(255, 60, 60),
	success = Color3.fromRGB(60, 255, 120),
	warning = Color3.fromRGB(255, 200, 60),
	enemyColor = Color3.fromRGB(255, 50, 50),
	teamColor = Color3.fromRGB(50, 255, 50),
}

-- ===================== STATE =====================
local silentAimActive = false
local wallbangActive = false
local aimbotActive = false
local espActive = false
local flyActive = false
local noclipActive = false
local speedBoostActive = false
local infJumpActive = false
local godModeActive = false
local hitboxExpandActive = false
local infAmmoActive = false
local antiAfkActive = false
local fullbrightActive = false

local silentAimMethod = "Raycast" -- Raycast, FindPartOnRay, Mouse.Hit/Target
local targetPart = "Head" -- Head, HumanoidRootPart
local fovRadius = 150
local hitChance = 100
local aimbotSmooth = 0.5
local flySpeed = 80
local speedValue = 50
local hitboxSize = 10
local windowVisible = true
local activeTab = "Aim"

-- Connections / refs
local flyConnection = nil
local flyBV = nil
local flyBG = nil
local noclipConnection = nil
local speedBV = nil
local speedConnection = nil
local godModeConnection = nil
local hitboxConnection = nil
local ammoConnection = nil
local espHighlights = {}
local oldNamecall = nil
local oldIndex = nil

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

local function isEnemy(player)
	if player == LocalPlayer then return false end
	if not player.Character then return false end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	-- Team check: different team = enemy
	if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
		return false
	end
	return true
end

local function isAlive(player)
	if not player or not player.Character then return false end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function getTargetPartFromPlayer(player)
	if not player.Character then return nil end
	local part = player.Character:FindFirstChild(targetPart)
	if not part then
		part = player.Character:FindFirstChild("HumanoidRootPart")
	end
	return part
end

-- ===================== FOV / TARGET SELECTION =====================
local function getClosestPlayerInFOV()
	local closest = nil
	local closestDist = fovRadius
	local mousePos = UserInputService:GetMouseLocation()

	for _, player in ipairs(Players:GetPlayers()) do
		if isEnemy(player) and isAlive(player) then
			local part = getTargetPartFromPlayer(player)
			if part then
				local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
				if onScreen then
					local screenVec = Vector2.new(screenPos.X, screenPos.Y)
					local dist = (screenVec - mousePos).Magnitude
					if dist < closestDist then
						closest = part
						closestDist = dist
					end
				end
			end
		end
	end
	return closest
end

local function getClosestPlayer3D()
	local hrp = getRoot()
	if not hrp then return nil end
	local closest = nil
	local closestDist = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if isEnemy(player) and isAlive(player) then
			local part = getTargetPartFromPlayer(player)
			if part then
				local dist = (part.Position - hrp.Position).Magnitude
				if dist < closestDist then
					closest = part
					closestDist = dist
				end
			end
		end
	end
	return closest
end

local function calculateChance(percentage)
	return math.random(1, 100) <= percentage
end

local function getDirection(origin, targetPos)
	return (targetPos - origin).Unit * 1000
end

-- ===================== SILENT AIM =====================
-- Hooks workspace raycast methods to redirect bullets to target
-- This is the core "teleport bullets" / "shoot through walls" mechanic
-- Requires executor with hookmetamethod support

local function enableSilentAim()
	silentAimActive = true

	-- Check if executor supports hookmetamethod
	if not hookmetamethod then
		notify("Silent Aim", "Your executor doesn't support hookmetamethod - using fallback")
		-- Fallback: use RenderStepped mouse override (less reliable)
		return
	end

	-- Hook __namecall to intercept Raycast / FindPartOnRay calls
	if not oldNamecall then
		oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
			local args = {...}
			local self = args[1]
			local method = getnamecallmethod()

			if silentAimActive and self == workspace and not checkcaller() then
				local target = getClosestPlayerInFOV()
				if target and calculateChance(hitChance) then

					if method == "Raycast" and (silentAimMethod == "Raycast" or wallbangActive) then
						local origin = args[2]
						if typeof(origin) == "Vector3" then
							-- Redirect ray direction to target
							args[3] = getDirection(origin, target.Position)

							-- Wallbang: modify RaycastParams to ignore walls
							if wallbangActive and typeof(args[4]) == "RaycastParams" then
								local params = RaycastParams.new()
								params.FilterType = Enum.RaycastFilterType.Include
								-- Only include target character parts
								if target.Parent then
									params.FilterDescendantsInstances = {target.Parent}
								end
								args[4] = params
							end

							return oldNamecall(unpack(args))
						end

					elseif method == "FindPartOnRayWithIgnoreList" and silentAimMethod == "FindPartOnRay" then
						local ray = args[2]
						if typeof(ray) == "Ray" then
							local origin = ray.Origin
							local direction = getDirection(origin, target.Position)
							args[2] = Ray.new(origin, direction)
							return oldNamecall(unpack(args))
						end

					elseif method == "FindPartOnRayWithWhitelist" and silentAimMethod == "FindPartOnRay" then
						local ray = args[2]
						if typeof(ray) == "Ray" then
							local origin = ray.Origin
							local direction = getDirection(origin, target.Position)
							args[2] = Ray.new(origin, direction)
							return oldNamecall(unpack(args))
						end

					elseif (method == "FindPartOnRay" or method == "findPartOnRay") and silentAimMethod == "FindPartOnRay" then
						local ray = args[2]
						if typeof(ray) == "Ray" then
							local origin = ray.Origin
							local direction = getDirection(origin, target.Position)
							args[2] = Ray.new(origin, direction)
							return oldNamecall(unpack(args))
						end
					end
				end
			end

			return oldNamecall(...)
		end))
	end

	-- Hook __index for Mouse.Hit/Target method
	if not oldIndex then
		oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, index)
			if silentAimActive and self == Mouse and not checkcaller() and silentAimMethod == "Mouse.Hit/Target" then
				local target = getClosestPlayerInFOV()
				if target and calculateChance(hitChance) then
					if index == "Hit" or index == "hit" then
						return target.CFrame
					elseif index == "Target" or index == "target" then
						return target
					end
				end
			end
			return oldIndex(self, index)
		end))
	end

	notify("Silent Aim", "Active - bullets redirect to target!")
end

local function disableSilentAim()
	silentAimActive = false
	notify("Silent Aim", "Disabled")
end

-- ===================== AIMBOT (Camera Lock) =====================
-- Smoothly locks camera to nearest enemy - visual aimbot
local aimbotConnection = nil

local function startAimbot()
	aimbotConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not aimbotActive then return end
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

			local target = getClosestPlayerInFOV()
			if target then
				local targetCF = CFrame.new(camera.CFrame.Position, target.Position)
				camera.CFrame = camera.CFrame:Lerp(targetCF, aimbotSmooth)
			end
		end)
	end)
	notify("Aimbot", "Hold right-click to lock on!")
end

local function stopAimbot()
	if aimbotConnection then aimbotConnection:Disconnect() aimbotConnection = nil end
end

-- ===================== ESP =====================
local function clearESP()
	for _, obj in pairs(espHighlights) do pcall(function() obj:Destroy() end) end
	espHighlights = {}
end

local function updateESP()
	clearESP()
	if not espActive then return end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and isAlive(player) then
			pcall(function()
				local char = player.Character
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum then return end

				local isTeammate = player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team
				local color = isTeammate and COLORS.teamColor or COLORS.enemyColor

				-- Highlight
				if not char:FindFirstChild("NBTF_HL") then
					local hl = Instance.new("Highlight")
					hl.Name = "NBTF_HL"
					hl.Adornee = char
					hl.FillColor = color
					hl.FillTransparency = 0.5
					hl.OutlineColor = color
					hl.OutlineTransparency = 0
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = char
					table.insert(espHighlights, hl)
				end

				-- Name + Health + Distance billboard
				local myRoot = getRoot()
				local dist = myRoot and math.floor((hrp.Position - myRoot.Position).Magnitude) or 0
				local healthPct = math.floor((hum.Health / hum.MaxHealth) * 100)

				if not char:FindFirstChild("NBTF_BB") then
					local bb = Instance.new("BillboardGui")
					bb.Name = "NBTF_BB"
					bb.AlwaysOnTop = true
					bb.Size = UDim2.new(6, 0, 1.2, 0)
					bb.StudsOffset = Vector3.new(0, 3.5, 0)
					bb.Adornee = hrp
					bb.Parent = char
					table.insert(espHighlights, bb)

					local lbl = Instance.new("TextLabel")
					lbl.Text = player.DisplayName .. " [" .. healthPct .. "%] " .. dist .. "m"
					lbl.TextColor3 = color
					lbl.TextStrokeTransparency = 0
					lbl.TextSize = 12
					lbl.Font = Enum.Font.GothamBold
					lbl.BackgroundTransparency = 1
					lbl.Size = UDim2.new(1, 0, 0.5, 0)
					lbl.Parent = bb

					-- Health bar
					local barBg = Instance.new("Frame")
					barBg.Size = UDim2.new(0.6, 0, 0, 4)
					barBg.Position = UDim2.new(0.2, 0, 0.6, 0)
					barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					barBg.BorderSizePixel = 0
					barBg.Parent = bb
					table.insert(espHighlights, barBg)

					local barFill = Instance.new("Frame")
					barFill.Size = UDim2.new(hum.Health / hum.MaxHealth, 0, 1, 0)
					barFill.BackgroundColor3 = hum.Health > hum.MaxHealth * 0.5 and COLORS.success or COLORS.error
					barFill.BorderSizePixel = 0
					barFill.Parent = barBg
					table.insert(espHighlights, barFill)

					-- Weapon label
					local tool = char:FindFirstChildOfClass("Tool")
					if tool then
						local weaponLbl = Instance.new("TextLabel")
						weaponLbl.Text = "[" .. tool.Name .. "]"
						weaponLbl.TextColor3 = COLORS.warning
						weaponLbl.TextStrokeTransparency = 0
						weaponLbl.TextSize = 10
						weaponLbl.Font = Enum.Font.Gotham
						weaponLbl.BackgroundTransparency = 1
						weaponLbl.Size = UDim2.new(1, 0, 0.3, 0)
						weaponLbl.Position = UDim2.new(0, 0, 0.75, 0)
						weaponLbl.Parent = bb
					end
				end
			end)
		end
	end
end

local function startESP()
	task.spawn(function()
		while espActive do updateESP() task.wait(1.5) end
	end)
	notify("ESP", "Player ESP active!")
end

-- ===================== UNLIMITED AMMO =====================
-- Finds tool ammo values and keeps them maxed
local function startInfAmmo()
	ammoConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then
					-- Common ammo patterns in Roblox FPS games
					for _, obj in ipairs(tool:GetDescendants()) do
						if obj:IsA("NumberValue") or obj:IsA("IntValue") then
							local name = obj.Name:lower()
							if name == "ammo" or name == "currentammo" or name == "magammo"
								or name == "clip" or name == "clipammo" or name == "bullets"
								or name == "magazine" or name == "mag" or name == "rounds" then
								if obj.Value < 999 then
									obj.Value = 999
								end
							elseif name == "reserveammo" or name == "reserve" or name == "totalammo"
								or name == "storedammo" or name == "spareammmo" or name == "maxammo" then
								if obj.Value < 999 then
									obj.Value = 999
								end
							end
						end
					end
					-- Also check in Backpack copy
					local bpTool = LocalPlayer.Backpack:FindFirstChild(tool.Name)
					if bpTool then
						for _, obj in ipairs(bpTool:GetDescendants()) do
							if (obj:IsA("NumberValue") or obj:IsA("IntValue")) then
								local name = obj.Name:lower()
								if name == "ammo" or name == "currentammo" or name == "magammo"
									or name == "clip" or name == "clipammo" or name == "bullets"
									or name == "magazine" or name == "mag" or name == "rounds"
									or name == "reserveammo" or name == "reserve" or name == "totalammo" then
									if obj.Value < 999 then
										obj.Value = 999
									end
								end
							end
						end
					end
				end
			end
			-- Also set all backpack tool ammo
			for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
				if tool:IsA("Tool") then
					for _, obj in ipairs(tool:GetDescendants()) do
						if (obj:IsA("NumberValue") or obj:IsA("IntValue")) then
							local name = obj.Name:lower()
							if name == "ammo" or name == "currentammo" or name == "magammo"
								or name == "clip" or name == "clipammo" or name == "bullets"
								or name == "magazine" or name == "mag" or name == "rounds"
								or name == "reserveammo" or name == "reserve" or name == "totalammo" then
								if obj.Value < 999 then
									obj.Value = 999
								end
							end
						end
					end
				end
			end
		end)
	end)
	notify("Ammo", "Unlimited ammo active!")
end

local function stopInfAmmo()
	if ammoConnection then ammoConnection:Disconnect() ammoConnection = nil end
end

-- ===================== HITBOX EXPANDER =====================
local function startHitboxExpand()
	hitboxConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and isAlive(player) then
					local hrp = player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
						hrp.Transparency = 0.7
					end
				end
			end
		end)
	end)
	notify("Hitbox", "Enemy hitboxes expanded!")
end

local function stopHitboxExpand()
	if hitboxConnection then hitboxConnection:Disconnect() hitboxConnection = nil end
	pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Size = Vector3.new(2, 2, 1)
					hrp.Transparency = 1
				end
			end
		end
	end)
end

-- ===================== GOD MODE =====================
local function startGodMode()
	godModeConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local hum = getHumanoid()
			if hum then
				hum.Health = hum.MaxHealth
				hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			end
		end)
	end)
	notify("God Mode", "Invincible!")
end

local function stopGodMode()
	if godModeConnection then godModeConnection:Disconnect() godModeConnection = nil end
	pcall(function()
		local hum = getHumanoid()
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		end
	end)
end

-- ===================== FLY =====================
local function startFly()
	local hrp = getRoot()
	if not hrp then return end

	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyBV.Velocity = Vector3.new(0, 0, 0)
	flyBV.P = 9000
	flyBV.Parent = hrp

	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flyBG.P = 9000
	flyBG.CFrame = hrp.CFrame
	flyBG.Parent = hrp

	flyConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not flyBV or not flyBV.Parent then return end
			local moveVec = Vector3.zero
			local camCF = camera.CFrame
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + camCF.UpVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - camCF.UpVector end
			flyBV.Velocity = moveVec.Magnitude > 0 and moveVec.Unit * flySpeed or Vector3.zero
			flyBG.CFrame = camCF
		end)
	end)
	notify("Fly", "Flying! WASD + Space/Shift")
end

local function stopFly()
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	if flyBV then pcall(function() flyBV:Destroy() end) flyBV = nil end
	if flyBG then pcall(function() flyBG:Destroy() end) flyBG = nil end
end

-- ===================== NOCLIP =====================
local function startNoclip()
	noclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
	end)
	notify("Noclip", "Walk through walls!")
end

local function stopNoclip()
	if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
end

-- ===================== SPEED BOOST =====================
local function startSpeedBoost()
	local hrp = getRoot()
	if not hrp then return end

	speedBV = Instance.new("BodyVelocity")
	speedBV.MaxForce = Vector3.new(math.huge, 0, math.huge)
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
				speedBV.Velocity = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * speedValue
			else
				speedBV.Velocity = Vector3.new(0, 0, 0)
			end
		end)
	end)
	notify("Speed", "Speed boost active!")
end

local function stopSpeedBoost()
	if speedConnection then speedConnection:Disconnect() speedConnection = nil end
	if speedBV then pcall(function() speedBV:Destroy() end) speedBV = nil end
end

-- ===================== INFINITE JUMP =====================
local function startInfJump()
	infJumpActive = true
end

UserInputService.JumpRequest:Connect(function()
	if infJumpActive then
		pcall(function()
			local hum = getHumanoid()
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end
end)

-- ===================== FULLBRIGHT =====================
local savedLighting = {}

local function enableFullbright()
	local Lighting = game:GetService("Lighting")
	savedLighting.Brightness = Lighting.Brightness
	savedLighting.ClockTime = Lighting.ClockTime
	savedLighting.FogEnd = Lighting.FogEnd
	savedLighting.GlobalShadows = Lighting.GlobalShadows
	savedLighting.OutdoorAmbient = Lighting.OutdoorAmbient

	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = false
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	notify("Fullbright", "Full visibility!")
end

local function disableFullbright()
	local Lighting = game:GetService("Lighting")
	if savedLighting.Brightness then Lighting.Brightness = savedLighting.Brightness end
	if savedLighting.ClockTime then Lighting.ClockTime = savedLighting.ClockTime end
	if savedLighting.FogEnd then Lighting.FogEnd = savedLighting.FogEnd end
	if savedLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = savedLighting.GlobalShadows end
	if savedLighting.OutdoorAmbient then Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient end
end

-- ===================== ANTI AFK =====================
local function startAntiAfk()
	antiAfkActive = true
	pcall(function()
		if getconnections then
			for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
				conn:Disable()
			end
		end
	end)
	task.spawn(function()
		while antiAfkActive do
			pcall(function()
				local VirtualUser = game:GetService("VirtualUser")
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
			task.wait(300)
		end
	end)
	notify("Anti-AFK", "AFK prevention active!")
end

local function stopAntiAfk()
	antiAfkActive = false
end

-- ===================== TELEPORT TO PLAYER =====================
local function teleportToPlayer(playerName)
	local target = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(playerName:lower()) or p.DisplayName:lower():find(playerName:lower()) then
			target = p
			break
		end
	end
	if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
		local char = LocalPlayer.Character
		if char then
			char:PivotTo(target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0))
			notify("Teleport", "Teleported to " .. target.DisplayName)
		end
	else
		notify("Error", "Player not found or dead")
	end
end

-- ===================== NBTF LOCATION TELEPORTS =====================
-- Key locations in Nuclear Blast Testing Facility
local NBTF_LOCATIONS = {
	-- These are approximate positions - actual positions depend on map version
	{name = "Spawn / Lobby", pos = Vector3.new(0, 10, 0)},
	{name = "Main Control Room", pos = Vector3.new(100, 15, 0)},
	{name = "Reactor Core", pos = Vector3.new(-50, -20, 50)},
	{name = "Weapons Research Center", pos = Vector3.new(150, 10, -80)},
	{name = "Military Barracks", pos = Vector3.new(-120, 10, -100)},
	{name = "Strategic Command (SCC)", pos = Vector3.new(200, 20, 50)},
	{name = "Exterior Checkpoint", pos = Vector3.new(-200, 10, 0)},
	{name = "Ammo Station 1", pos = Vector3.new(80, 10, -30)},
	{name = "Ammo Station 2", pos = Vector3.new(-80, 10, 60)},
}

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NBTFHub"
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
mainFrame.Size = UDim2.new(0, 520, 0, 440)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -220)
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
titleBar.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
addCorner(titleBar, 8)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 10)
titleFix.Position = UDim2.new(0, 0, 1, -10)
titleFix.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "NBTF Hub v1.0 - Nuclear Blast Testing Facility"
titleText.TextColor3 = COLORS.accent
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 12
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
tabBar.Size = UDim2.new(1, 0, 0, 28)
tabBar.Position = UDim2.new(0, 0, 0, 32)
tabBar.BackgroundColor3 = COLORS.bgSecondary
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local tabNames = {"Aim", "Combat", "Movement", "Visuals", "Teleport"}
local tabButtons = {}
local tabFrames = {}

for i, name in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 104, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = name
	btn.TextColor3 = COLORS.textSecondary
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 11
	btn.LayoutOrder = i
	btn.Parent = tabBar
	tabButtons[name] = btn

	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -16, 1, -70)
	content.Position = UDim2.new(0, 8, 0, 62)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = COLORS.accent
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Visible = name == "Aim"
	content.Parent = mainFrame
	tabFrames[name] = content

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = content

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = content
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
	lbl.Size = UDim2.new(1, 0, 0, 16)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.textSecondary
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 10
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order or 0
	lbl.Parent = parent
end

local function createToggle(parent, text, order, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
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
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local toggleFrame = Instance.new("Frame")
	toggleFrame.Size = UDim2.new(0, 36, 0, 18)
	toggleFrame.Position = UDim2.new(1, -46, 0.5, -9)
	toggleFrame.BackgroundColor3 = COLORS.toggleOff
	toggleFrame.BorderSizePixel = 0
	toggleFrame.Parent = row
	addCorner(toggleFrame, 9)

	local circle = Instance.new("Frame")
	circle.Size = UDim2.new(0, 14, 0, 14)
	circle.Position = UDim2.new(0, 2, 0.5, -7)
	circle.BackgroundColor3 = COLORS.textPrimary
	circle.BorderSizePixel = 0
	circle.Parent = toggleFrame
	addCorner(circle, 7)

	local isOn = false
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = row

	btn.MouseButton1Click:Connect(function()
		isOn = not isOn
		toggleFrame.BackgroundColor3 = isOn and COLORS.toggleOn or COLORS.toggleOff
		circle.Position = isOn and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
		if callback then callback(isOn) end
	end)
end

local function createButton(parent, text, order, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 30)
	btn.BackgroundColor3 = COLORS.accent
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(10, 10, 10)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
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
	container.Size = UDim2.new(1, 0, 0, 38)
	container.BackgroundColor3 = COLORS.panel
	container.BorderSizePixel = 0
	container.LayoutOrder = order or 0
	container.Parent = parent
	addCorner(container, 5)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.5, -10, 0, 16)
	lbl.Position = UDim2.new(0, 10, 0, 2)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.textPrimary
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 10
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = container

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0.5, -10, 0, 16)
	valLabel.Position = UDim2.new(0.5, 0, 0, 2)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(default)
	valLabel.TextColor3 = COLORS.accent
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 10
	valLabel.TextXAlignment = Enum.TextXAlignment.Right
	valLabel.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -20, 0, 5)
	track.Position = UDim2.new(0, 10, 0, 26)
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
	sliderBtn.Size = UDim2.new(1, 0, 0, 18)
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

local function createSpacer(parent, order)
	local s = Instance.new("Frame")
	s.Size = UDim2.new(1, 0, 0, 6)
	s.BackgroundTransparency = 1
	s.LayoutOrder = order or 0
	s.Parent = parent
end

-- ===================== BUILD AIM TAB =====================
do
	local tab = tabFrames["Aim"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Silent Aim (Teleport Bullets)", o())
	createToggle(tab, "Silent Aim", o(), function(on)
		silentAimActive = on
		if on then enableSilentAim() else disableSilentAim() end
	end)
	createInfoLabel(tab, "Redirects your bullets to nearest enemy in FOV", o())
	createInfoLabel(tab, "Requires executor with hookmetamethod (Synapse/Fluxus/etc)", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Wallbang (Shoot Through Walls)", o())
	createToggle(tab, "Wallbang", o(), function(on)
		wallbangActive = on
		if on then notify("Wallbang", "Bullets ignore walls!") else notify("Wallbang", "Disabled") end
	end)
	createInfoLabel(tab, "Modifies raycast to ignore wall collisions", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Settings", o())
	createSlider(tab, "FOV Radius", 50, 360, fovRadius, o(), function(val)
		fovRadius = val
	end)
	createSlider(tab, "Hit Chance %", 10, 100, hitChance, o(), function(val)
		hitChance = val
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Visual Aimbot", o())
	createToggle(tab, "Aimbot (Right-Click Lock)", o(), function(on)
		aimbotActive = on
		if on then startAimbot() else stopAimbot() end
	end)
	createSlider(tab, "Aim Smoothness", 10, 100, math.floor(aimbotSmooth * 100), o(), function(val)
		aimbotSmooth = val / 100
	end)
	createInfoLabel(tab, "Hold right-click to lock camera onto nearest enemy", o())
end

-- ===================== BUILD COMBAT TAB =====================
do
	local tab = tabFrames["Combat"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Ammo", o())
	createToggle(tab, "Unlimited Ammo", o(), function(on)
		infAmmoActive = on
		if on then startInfAmmo() else stopInfAmmo() end
	end)
	createInfoLabel(tab, "Keeps all weapon ammo values at 999", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Hitbox", o())
	createToggle(tab, "Hitbox Expander", o(), function(on)
		hitboxExpandActive = on
		if on then startHitboxExpand() else stopHitboxExpand() end
	end)
	createSlider(tab, "Hitbox Size", 5, 30, hitboxSize, o(), function(val)
		hitboxSize = val
	end)
	createInfoLabel(tab, "Makes enemy HumanoidRootParts larger = easier hits", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Protection", o())
	createToggle(tab, "God Mode (Infinite Health)", o(), function(on)
		godModeActive = on
		if on then startGodMode() else stopGodMode() end
	end)
	createInfoLabel(tab, "Heals to max every frame, prevents death states", o())
end

-- ===================== BUILD MOVEMENT TAB =====================
do
	local tab = tabFrames["Movement"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Flight", o())
	createToggle(tab, "Fly (WASD + Space/Shift)", o(), function(on)
		flyActive = on
		if on then startFly() else stopFly() end
	end)
	createSlider(tab, "Fly Speed", 10, 300, flySpeed, o(), function(val) flySpeed = val end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Speed", o())
	createToggle(tab, "Speed Boost", o(), function(on)
		speedBoostActive = on
		if on then startSpeedBoost() else stopSpeedBoost() end
	end)
	createSlider(tab, "Speed Value", 20, 300, speedValue, o(), function(val) speedValue = val end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Other", o())
	createToggle(tab, "Noclip (Walk Through Walls)", o(), function(on)
		noclipActive = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "Infinite Jump", o(), function(on)
		infJumpActive = on
		if on then notify("Inf Jump", "Active!") end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "AFK", o())
	createToggle(tab, "Anti-AFK (Prevent Kick)", o(), function(on)
		antiAfkActive = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)
end

-- ===================== BUILD VISUALS TAB =====================
do
	local tab = tabFrames["Visuals"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "ESP", o())
	createToggle(tab, "Player ESP (Names/Health/Distance)", o(), function(on)
		espActive = on
		if on then startESP() else clearESP() end
	end)
	createInfoLabel(tab, "Red = enemy, Green = teammate. Shows weapon held.", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Lighting", o())
	createToggle(tab, "Fullbright (Remove Darkness)", o(), function(on)
		fullbrightActive = on
		if on then enableFullbright() else disableFullbright() end
	end)
	createInfoLabel(tab, "Max brightness, no fog, no shadows", o())
end

-- ===================== BUILD TELEPORT TAB =====================
do
	local tab = tabFrames["Teleport"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Facility Locations", o())
	createInfoLabel(tab, "Teleport to key areas in the facility", o())

	for _, loc in ipairs(NBTF_LOCATIONS) do
		createButton(tab, "TP: " .. loc.name, o(), function()
			local char = LocalPlayer.Character
			if char then
				char:PivotTo(CFrame.new(loc.pos))
				notify("Teleport", loc.name)
			end
		end)
	end

	createSpacer(tab, o())

	createSectionLabel(tab, "Player Teleport", o())
	createInfoLabel(tab, "Click a player name to teleport to them", o())

	-- Dynamic player list buttons
	local playerListFrame = Instance.new("Frame")
	playerListFrame.Size = UDim2.new(1, 0, 0, 0)
	playerListFrame.AutomaticSize = Enum.AutomaticSize.Y
	playerListFrame.BackgroundTransparency = 1
	playerListFrame.LayoutOrder = o()
	playerListFrame.Parent = tab

	local playerListLayout = Instance.new("UIListLayout")
	playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerListLayout.Padding = UDim.new(0, 3)
	playerListLayout.Parent = playerListFrame

	local function refreshPlayerList()
		for _, child in ipairs(playerListFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for i, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local isTeammate = player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team
				local pBtn = Instance.new("TextButton")
				pBtn.Size = UDim2.new(1, 0, 0, 26)
				pBtn.BackgroundColor3 = COLORS.panel
				pBtn.BorderSizePixel = 0
				pBtn.Text = player.DisplayName .. " (@" .. player.Name .. ")"
				pBtn.TextColor3 = isTeammate and COLORS.teamColor or COLORS.enemyColor
				pBtn.Font = Enum.Font.Gotham
				pBtn.TextSize = 11
				pBtn.LayoutOrder = i
				pBtn.Parent = playerListFrame
				addCorner(pBtn, 4)
				pBtn.MouseButton1Click:Connect(function()
					teleportToPlayer(player.Name)
				end)
			end
		end
	end

	createButton(tab, "Refresh Player List", o(), refreshPlayerList)
	refreshPlayerList()
end

-- ===================== MINIMIZE / TOGGLE =====================
local contentVisible = true
minimizeBtn.MouseButton1Click:Connect(function()
	contentVisible = not contentVisible
	for _, frame in pairs(tabFrames) do frame.Visible = contentVisible and frame == tabFrames[activeTab] end
	tabBar.Visible = contentVisible
	mainFrame.Size = contentVisible and UDim2.new(0, 520, 0, 440) or UDim2.new(0, 520, 0, 32)
	minimizeBtn.Text = contentVisible and "-" or "+"
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		windowVisible = not windowVisible
		mainFrame.Visible = windowVisible
	end
end)

-- ===================== RESPAWN HANDLER =====================
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	if flyActive then stopFly() task.wait(0.3) startFly() end
	if speedBoostActive then stopSpeedBoost() task.wait(0.3) startSpeedBoost() end
	if noclipActive then stopNoclip() task.wait(0.3) startNoclip() end
	if godModeActive then stopGodMode() task.wait(0.3) startGodMode() end
end)

-- ===================== STARTUP =====================
notify("NBTF Hub v1.0", "Loaded! Right Shift to toggle")
print("[NBTF Hub v1.0] Loaded - Right Shift to toggle")
print("[NBTF Hub v1.0] Tabs: Aim | Combat | Movement | Visuals | Teleport")
print("[NBTF Hub v1.0] Silent Aim requires hookmetamethod support")
