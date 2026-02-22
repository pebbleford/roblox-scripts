-- ================================================================
-- NBTF Hub v1.0 - Nuclear Blast Testing Facility
-- Silent Aim | Wallbang | ESP | Aimbot | Fly | Teleports
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ===================== NBTF WEAPON SYSTEM =====================
-- NBTF uses ReplicatedStorage.WeaponsSystem.Network.WeaponHit:FireServer()
-- This is the ACTUAL remote the game uses for hit registration
local WeaponHitRemote = nil
pcall(function()
	WeaponHitRemote = game:GetService("ReplicatedStorage"):FindFirstChild("WeaponsSystem")
	if WeaponHitRemote then
		WeaponHitRemote = WeaponHitRemote:FindFirstChild("Network")
		if WeaponHitRemote then
			WeaponHitRemote = WeaponHitRemote:FindFirstChild("WeaponHit")
		end
	end
end)

-- All NBTF weapon names
local NBTF_GUNS = {
	"Imaginary Gun", "M4 Carbine", "USP", "Spy USP", "AK74",
	"Colt Python", "USP Silenced", "M24 Sniper", "UMP-9", "MPX",
	"XM1014", "Makarov", "AK47", "Crowbar", "Virus Kit",
	"SniperRifle", "Shotgun"
}

-- NBTF weapon config values
local NBTF_ZERO_VALUES = {"RecoilDecay", "RecoilMax", "RecoilMin", "ShotCooldown", "TotalRecoilMax", "MaxSpread", "MinSpread"}
local NBTF_MAX_VALUES = {"AmmoCapacity", "AmmoReserves", "FullMagazineSize", "HitDamage", "MaxDistance"}

-- Find any gun in the player's backpack
local function findGunInBackpack()
	for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
		if tool:IsA("Tool") then
			for _, gunName in ipairs(NBTF_GUNS) do
				if tool.Name == gunName then
					return tool
				end
			end
		end
	end
	-- Also check equipped tools
	local char = LocalPlayer.Character
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				for _, gunName in ipairs(NBTF_GUNS) do
					if tool.Name == gunName then
						return tool
					end
				end
			end
		end
	end
	return nil
end

-- Fire a weapon hit on a target player using the NBTF WeaponHit remote
local function fireWeaponHit(targetPlayer, gun)
	if not WeaponHitRemote then return false end
	if not targetPlayer or not targetPlayer.Character then return false end
	local head = targetPlayer.Character:FindFirstChild("Head")
	if not head then return false end
	if not gun then gun = findGunInBackpack() end
	if not gun then return false end

	local args = {
		[1] = gun,
		[2] = {
			["p"] = Vector3.new(0, 0, 0),
			["pid"] = 1,
			["part"] = head,
			["d"] = 0,
			["maxDist"] = 0,
			["h"] = head,
			["m"] = Enum.Material.Plastic,
			["sid"] = 2,
			["t"] = 0,
			["n"] = Vector3.new(0, 0, 0)
		}
	}
	pcall(function()
		WeaponHitRemote:FireServer(unpack(args))
	end)
	return true
end

-- Click simulation fallback
local function mouse1click()
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	task.wait(0.05)
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

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
	facilityColor = Color3.fromRGB(50, 130, 255),
	rebelColor = Color3.fromRGB(255, 50, 50),
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
local vehicleFlyActive = false
local spectateActive = false
local noRecoilActive = false
local autoFireActive = false
local gravityActive = false
local bringAllActive = false

local targetPart = "Head" -- Head, HumanoidRootPart
local fovRadius = 150
local hitChance = 100
local aimbotSmooth = 0.5
local flySpeed = 80
local speedValue = 50
local hitboxSize = 10
local gravityValue = 196.2
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
local vehicleFlyConnection = nil
local vehicleFlyBV = nil
local vehicleFlyBG = nil
local noRecoilConnection = nil
local autoFireConnection = nil
local espHighlights = {}
local spectateTarget = nil

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

-- Detect if player is Facility (blue) or Rebel (red)
-- NBTF uses team names like "Facility", "Rebel", "Government", etc.
local function getPlayerTeamInfo(player)
	local teamName = ""
	local roleName = ""
	local color = COLORS.rebelColor -- default red

	-- Get team name
	if player.Team then
		teamName = player.Team.Name or ""
	end

	-- Get role from leaderboard stats or character name tags
	pcall(function()
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			for _, stat in ipairs(leaderstats:GetChildren()) do
				local sName = stat.Name:lower()
				if sName == "role" or sName == "rank" or sName == "class" or sName == "job" or sName == "team" then
					roleName = tostring(stat.Value)
					break
				end
			end
		end
	end)

	-- Also check for role in other common value locations
	if roleName == "" then
		pcall(function()
			for _, child in ipairs(player:GetChildren()) do
				if child:IsA("StringValue") or child:IsA("ObjectValue") then
					local cName = child.Name:lower()
					if cName == "role" or cName == "rank" or cName == "class" or cName == "job" then
						roleName = tostring(child.Value)
						break
					end
				end
			end
		end)
	end

	-- Determine color based on team/role name
	-- NBTF teams: Radio_Rebellion = rebel, anything else = facility
	-- Rebel roles: Rebel, Raid Leader, Overseer, Vindicator, Warlord, Insurgent, Bandit, Hostile
	-- Facility roles: Scientist, Rocket Scientist, Intern, Security, Guard, Military, Director, Staff
	local nameLower = (teamName .. " " .. roleName):lower()
	if nameLower:find("rebel") or nameLower:find("rebellion") or nameLower:find("raid leader")
		or nameLower:find("overseer") or nameLower:find("vindicator") or nameLower:find("warlord")
		or nameLower:find("insurgent") or nameLower:find("bandit") or nameLower:find("hostile") then
		color = COLORS.rebelColor
	elseif nameLower:find("facility") or nameLower:find("scientist") or nameLower:find("security")
		or nameLower:find("intern") or nameLower:find("guard") or nameLower:find("military")
		or nameLower:find("director") or nameLower:find("staff") or nameLower:find("government")
		or nameLower:find("intelligence") or nameLower:find("official") or nameLower:find("worker") then
		color = COLORS.facilityColor
	else
		-- Fallback: use team color if available
		if player.Team then
			pcall(function()
				local tc = player.Team.TeamColor
				if tc then color = tc.Color end
			end)
		end
	end

	-- Build display role text
	local displayRole = ""
	if roleName ~= "" then
		displayRole = roleName
	elseif teamName ~= "" then
		displayRole = teamName
	end

	return color, displayRole, teamName
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

-- Silent aim connection
local silentAimConnection = nil

local function enableSilentAim()
	silentAimActive = true

	if not WeaponHitRemote then
		notify("Silent Aim", "WeaponHit remote not found! Waiting for game to load...")
		-- Try to find it again
		pcall(function()
			WeaponHitRemote = game:GetService("ReplicatedStorage").WeaponsSystem.Network.WeaponHit
		end)
		if not WeaponHitRemote then
			notify("Error", "Could not find WeaponsSystem.Network.WeaponHit")
			return
		end
	end

	-- NBTF Silent Aim: When you fire your gun, we also fire a WeaponHit
	-- at the closest enemy's Head using the actual game remote
	-- This runs every frame while you hold left click
	silentAimConnection = RunService.Heartbeat:Connect(function()
		if not silentAimActive then return end
		pcall(function()
			-- Only fire when player is holding left click (shooting)
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end

			local gun = findGunInBackpack()
			if not gun then
				-- Check equipped tool
				local char = LocalPlayer.Character
				if char then
					local tool = char:FindFirstChildOfClass("Tool")
					if tool then gun = tool end
				end
			end
			if not gun then return end

			local target = getClosestPlayerInFOV()
			if not target then target = getClosestPlayer3D() end
			if not target or not target.Parent then return end

			-- Find the player who owns this character
			local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
			if not targetPlayer then return end
			if not calculateChance(hitChance) then return end

			fireWeaponHit(targetPlayer, gun)
		end)
	end)

	notify("Silent Aim", "Active! Bullets auto-hit nearest enemy head")
end

local function disableSilentAim()
	silentAimActive = false
	if silentAimConnection then silentAimConnection:Disconnect() silentAimConnection = nil end
	notify("Silent Aim", "Disabled")
end

-- ===================== WALLBANG (WeaponHit through walls) =====================
-- Since WeaponHit uses d=0 and maxDist=0, it bypasses distance/wall checks
-- Wallbang auto-fires at nearest enemy every 0.3s while holding left click
local wallbangConnection = nil

local function enableWallbang()
	wallbangActive = true
	wallbangConnection = RunService.Heartbeat:Connect(function()
		if not wallbangActive then return end
		pcall(function()
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end

			local gun = findGunInBackpack()
			if not gun then
				local char = LocalPlayer.Character
				if char then
					local tool = char:FindFirstChildOfClass("Tool")
					if tool then gun = tool end
				end
			end
			if not gun then return end

			-- Fire at ALL visible enemies through walls
			for _, player in ipairs(Players:GetPlayers()) do
				if isEnemy(player) and isAlive(player) then
					fireWeaponHit(player, gun)
				end
			end
		end)
	end)
	notify("Wallbang", "Active! Hold LMB to hit all enemies through walls")
end

local function disableWallbang()
	wallbangActive = false
	if wallbangConnection then wallbangConnection:Disconnect() wallbangConnection = nil end
	notify("Wallbang", "Disabled")
end

-- ===================== AIMBOT (Camera Lock) =====================
-- Locks camera to nearest enemy when holding right-click OR always-on mode
local aimbotConnection = nil
local aimbotAlwaysOn = false

local function startAimbot()
	aimbotConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not aimbotActive then return end
			-- Work in both modes: always-on or hold right-click
			if not aimbotAlwaysOn and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

			local target = getClosestPlayerInFOV()
			if not target then
				-- Fallback: try 3D closest if FOV finds nothing
				target = getClosestPlayer3D()
			end
			if target then
				local camPos = camera.CFrame.Position
				local targetCF = CFrame.new(camPos, target.Position)
				-- Direct snap for low smoothness, lerp for high
				if aimbotSmooth >= 0.9 then
					camera.CFrame = targetCF
				else
					camera.CFrame = camera.CFrame:Lerp(targetCF, aimbotSmooth)
				end
			end
		end)
	end)
	notify("Aimbot", "Active! Right-click to lock on")
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

				-- Get team color: Facility = blue, Rebel = red
				local color, roleName, teamName = getPlayerTeamInfo(player)

				-- Highlight with team color
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

				-- Name + Role + Health + Distance billboard
				local myRoot = getRoot()
				local dist = myRoot and math.floor((hrp.Position - myRoot.Position).Magnitude) or 0
				local healthPct = math.floor((hum.Health / hum.MaxHealth) * 100)

				if not char:FindFirstChild("NBTF_BB") then
					local bb = Instance.new("BillboardGui")
					bb.Name = "NBTF_BB"
					bb.AlwaysOnTop = true
					bb.Size = UDim2.new(8, 0, 1.6, 0)
					bb.StudsOffset = Vector3.new(0, 3.5, 0)
					bb.Adornee = hrp
					bb.Parent = char
					table.insert(espHighlights, bb)

					-- Name line
					local lbl = Instance.new("TextLabel")
					lbl.Text = player.DisplayName .. " [" .. healthPct .. "%] " .. dist .. "m"
					lbl.TextColor3 = color
					lbl.TextStrokeTransparency = 0
					lbl.TextSize = 12
					lbl.Font = Enum.Font.GothamBold
					lbl.BackgroundTransparency = 1
					lbl.Size = UDim2.new(1, 0, 0.3, 0)
					lbl.Parent = bb

					-- Role / Team line
					local roleText = ""
					if roleName ~= "" then
						roleText = roleName
					elseif teamName ~= "" then
						roleText = teamName
					end
					if roleText ~= "" then
						local roleLbl = Instance.new("TextLabel")
						roleLbl.Text = "[" .. roleText .. "]"
						roleLbl.TextColor3 = color
						roleLbl.TextStrokeTransparency = 0
						roleLbl.TextSize = 10
						roleLbl.Font = Enum.Font.GothamBold
						roleLbl.BackgroundTransparency = 1
						roleLbl.Size = UDim2.new(1, 0, 0.2, 0)
						roleLbl.Position = UDim2.new(0, 0, 0.3, 0)
						roleLbl.Parent = bb
					end

					-- Health bar
					local barBg = Instance.new("Frame")
					barBg.Size = UDim2.new(0.6, 0, 0, 4)
					barBg.Position = UDim2.new(0.2, 0, 0.55, 0)
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
						weaponLbl.Size = UDim2.new(1, 0, 0.2, 0)
						weaponLbl.Position = UDim2.new(0, 0, 0.65, 0)
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

-- ===================== UNLIMITED AMMO (NBTF-Specific) =====================
-- NBTF weapons store ammo in tool.Configuration (AmmoCapacity, AmmoReserves, etc.)
local function modGuns()
	pcall(function()
		for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local config = tool:FindFirstChild("Configuration")
				if config then
					for _, val in ipairs(config:GetChildren()) do
						-- Max out ammo, damage, range
						for _, maxName in ipairs(NBTF_MAX_VALUES) do
							if val.Name == maxName then
								val.Value = 9999999
							end
						end
						-- Zero out recoil, spread, cooldown
						for _, zeroName in ipairs(NBTF_ZERO_VALUES) do
							if val.Name == zeroName then
								val.Value = 0
							end
						end
					end
				end
			end
		end
		-- Also mod equipped tool
		local char = LocalPlayer.Character
		if char then
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then
					local config = tool:FindFirstChild("Configuration")
					if config then
						for _, val in ipairs(config:GetChildren()) do
							for _, maxName in ipairs(NBTF_MAX_VALUES) do
								if val.Name == maxName then val.Value = 9999999 end
							end
							for _, zeroName in ipairs(NBTF_ZERO_VALUES) do
								if val.Name == zeroName then val.Value = 0 end
							end
						end
					end
				end
			end
		end
	end)
end

local function startInfAmmo()
	-- Mod guns once immediately
	modGuns()
	-- Keep modding on heartbeat (in case guns reset)
	ammoConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then
					local config = tool:FindFirstChild("Configuration")
					if config then
						for _, val in ipairs(config:GetChildren()) do
							for _, maxName in ipairs(NBTF_MAX_VALUES) do
								if val.Name == maxName and val.Value < 9999 then val.Value = 9999999 end
							end
						end
					end
				end
			end
		end)
	end)
	notify("Ammo", "Unlimited ammo + max damage active!")
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

-- ===================== VEHICLE / CAR FLY =====================
-- Finds VehicleSeat you're sitting in, applies BodyVelocity + BodyGyro to the vehicle
-- Works with any vehicle in any game
local function getVehicle()
	local char = LocalPlayer.Character
	if not char then return nil, nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or not hum.SeatPart then return nil, nil end
	local seat = hum.SeatPart
	-- Find the vehicle model (parent of seat, or parent of parent)
	local vehicle = seat.Parent
	if vehicle and vehicle:IsA("Model") then
		local primaryPart = vehicle.PrimaryPart or seat
		return vehicle, primaryPart
	end
	return nil, seat
end

local function startVehicleFly()
	local vehicle, part = getVehicle()
	if not part then
		notify("Vehicle Fly", "You must be sitting in a vehicle!")
		return
	end

	-- Remove existing constraints on vehicle
	pcall(function()
		for _, obj in ipairs(part.Parent:GetDescendants()) do
			if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") or obj:IsA("BodyPosition") then
				if obj.Name ~= "NBTF_VFly_BV" and obj.Name ~= "NBTF_VFly_BG" then
					obj:Destroy()
				end
			end
		end
	end)

	-- Unanchor all parts
	pcall(function()
		for _, obj in ipairs(part.Parent:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = false
			end
		end
	end)

	vehicleFlyBV = Instance.new("BodyVelocity")
	vehicleFlyBV.Name = "NBTF_VFly_BV"
	vehicleFlyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	vehicleFlyBV.Velocity = Vector3.new(0, 0, 0)
	vehicleFlyBV.P = 9000
	vehicleFlyBV.Parent = part

	vehicleFlyBG = Instance.new("BodyGyro")
	vehicleFlyBG.Name = "NBTF_VFly_BG"
	vehicleFlyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	vehicleFlyBG.P = 9000
	vehicleFlyBG.CFrame = part.CFrame
	vehicleFlyBG.Parent = part

	vehicleFlyConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not vehicleFlyBV or not vehicleFlyBV.Parent then return end
			local moveVec = Vector3.zero
			local camCF = camera.CFrame
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + camCF.UpVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - camCF.UpVector end
			vehicleFlyBV.Velocity = moveVec.Magnitude > 0 and moveVec.Unit * flySpeed or Vector3.zero
			vehicleFlyBG.CFrame = camCF
		end)
	end)

	notify("Vehicle Fly", "Flying with vehicle! WASD + Space/Shift")
end

local function stopVehicleFly()
	if vehicleFlyConnection then vehicleFlyConnection:Disconnect() vehicleFlyConnection = nil end
	if vehicleFlyBV then pcall(function() vehicleFlyBV:Destroy() end) vehicleFlyBV = nil end
	if vehicleFlyBG then pcall(function() vehicleFlyBG:Destroy() end) vehicleFlyBG = nil end
end

-- ===================== SPECTATE PLAYER =====================
local function spectatePlayer(player)
	if player and player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
			spectateTarget = player
			spectateActive = true
			notify("Spectate", "Watching " .. player.DisplayName)
		end
	end
end

local function unspectate()
	pcall(function()
		local char = LocalPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then camera.CameraSubject = hum end
		end
	end)
	spectateTarget = nil
	spectateActive = false
	notify("Spectate", "Stopped")
end

-- ===================== NO RECOIL (NBTF-Specific) =====================
-- Sets RecoilDecay/RecoilMax/RecoilMin/MaxSpread/MinSpread to 0 in weapon Configuration
local function startNoRecoil()
	-- Apply to all guns immediately
	modGuns()
	-- Keep applying on heartbeat
	noRecoilConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then
					local config = tool:FindFirstChild("Configuration")
					if config then
						for _, val in ipairs(config:GetChildren()) do
							for _, zeroName in ipairs(NBTF_ZERO_VALUES) do
								if val.Name == zeroName and val.Value ~= 0 then val.Value = 0 end
							end
						end
					end
				end
			end
		end)
	end)
	notify("No Recoil", "Zero recoil + zero spread!")
end

local function stopNoRecoil()
	if noRecoilConnection then noRecoilConnection:Disconnect() noRecoilConnection = nil end
end

-- ===================== AUTO FIRE =====================
-- Automatically fires equipped gun by simulating mouse1 clicks
local function startAutoFire()
	autoFireConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			local tool = char:FindFirstChildOfClass("Tool")
			if tool and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				-- Activate the tool's fire
				tool:Activate()
			end
		end)
	end)
	notify("Auto Fire", "Hold left click for rapid fire!")
end

local function stopAutoFire()
	if autoFireConnection then autoFireConnection:Disconnect() autoFireConnection = nil end
end

-- ===================== GRAVITY =====================
local function setGravity(val)
	workspace.Gravity = val
end

-- ===================== BRING ALL PLAYERS =====================
-- Teleports all enemy players to your position
local function bringAllPlayers()
	local hrp = getRoot()
	if not hrp then notify("Error", "No character") return end
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and isAlive(player) then
			pcall(function()
				local theirHRP = player.Character:FindFirstChild("HumanoidRootPart")
				if theirHRP then
					theirHRP.CFrame = hrp.CFrame + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
					count = count + 1
				end
			end)
		end
	end
	notify("Bring All", "Brought " .. count .. " players!")
end

-- ===================== KILL ALL (NBTF WeaponHit Remote) =====================
-- Fires WeaponHit remote at every enemy player's Head - no teleporting needed
-- This is how the actual NBTF kill-all scripts work
local function killAllPlayers()
	if not WeaponHitRemote then
		notify("Error", "WeaponHit remote not found!")
		return
	end

	task.spawn(function()
		local gun = findGunInBackpack()
		if not gun then
			notify("Error", "No gun in backpack! Equip a weapon first.")
			return
		end

		local killed = 0
		-- Fire 10 rounds at each enemy (same as the proven NBTF kill script)
		for count = 1, 10 do
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and isAlive(player) then
					pcall(function()
						-- Try every gun in backpack
						for _, bpTool in ipairs(LocalPlayer.Backpack:GetChildren()) do
							if bpTool:IsA("Tool") then
								local isGun = false
								for _, gn in ipairs(NBTF_GUNS) do
									if bpTool.Name == gn then isGun = true break end
								end
								if isGun then
									fireWeaponHit(player, bpTool)
								end
							end
						end
						if count == 1 then killed = killed + 1 end
					end)
				end
			end
		end
		notify("Kill All", "Fired at " .. killed .. " players!")
	end)
end

-- ===================== FREEZE ALL PLAYERS =====================
local function freezeAllPlayers()
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and isAlive(player) then
			pcall(function()
				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Anchored = true
					count = count + 1
				end
			end)
		end
	end
	notify("Freeze", "Froze " .. count .. " players!")
end

local function unfreezeAllPlayers()
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			pcall(function()
				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Anchored = false
					count = count + 1
				end
			end)
		end
	end
	notify("Unfreeze", "Unfroze " .. count .. " players!")
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
-- Dynamically finds locations by searching workspace for named parts/models
-- This works regardless of map version because it searches by name

-- Keywords to search for in workspace descendants
-- All known NBTF locations from the wiki
local NBTF_SEARCH_NAMES = {
	-- Exterior
	"RebelBase", "Rebel Base", "Rebel",
	"LogisticsCheckpoint", "Logistics",
	"RebelGas", "Gas",
	"HiddenCave", "Cave",
	-- Interior
	"ExteriorCheckpoint", "Exterior Checkpoint",
	"InteriorCheckpoint", "Interior Checkpoint", "Internal",
	"LookoutBridge", "Lookout",
	"Hospital",
	"SCC", "StrategicCommand", "Strategic Command",
	"SCCRooftop",
	"ExecutiveOffices", "Executive",
	"MasterTeleporter", "Teleporter",
	"SecretArea", "ModRoom", "Mod Room", "Regular Lounge",
	"MaintenanceOffices", "Maintenance",
	"DataCenter", "Datacenter",
	"AppliedSciences", "Sciences",
	"ReceivingDepartment", "Receiving",
	"WeaponsResearch", "Weapons Research",
	"TestingField", "Testing",
	"PowerStation", "Power",
	"EGC", "EnergyGeneration", "Energy",
	"EGCLower",
	"CoreControl", "Core",
	"EGCRooftop",
	"MilitaryBarracks", "Barracks",
	-- Other
	"Garage", "Vehicle",
	"Helipad", "Helicopter",
	"Terminal", "Silo", "Armory",
}

-- Find a part/model in workspace by name - only checks direct children and 2 levels deep
local function findLocationByName(searchName)
	local best = nil
	local searchLower = searchName:lower()

	-- Only search top-level children and their immediate children (2 levels max)
	for _, obj in ipairs(workspace:GetChildren()) do
		local nameLower = obj.Name:lower()
		if nameLower:find(searchLower, 1, true) then
			if obj:IsA("SpawnLocation") then return obj end
			if obj:IsA("BasePart") or obj:IsA("Model") then
				best = best or obj
			end
		end
		-- Check one level deeper
		if obj:IsA("Model") or obj:IsA("Folder") then
			pcall(function()
				for _, child in ipairs(obj:GetChildren()) do
					local cName = child.Name:lower()
					if cName:find(searchLower, 1, true) then
						if child:IsA("SpawnLocation") then best = best or child return end
						if child:IsA("BasePart") or child:IsA("Model") then
							best = best or child
						end
					end
				end
			end)
		end
		if best then break end
	end
	return best
end

-- Get position from a found object
local function getLocationPosition(obj)
	if obj:IsA("Model") then
		local primary = obj.PrimaryPart
		if primary then return primary.Position + Vector3.new(0, 5, 0) end
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then return part.Position + Vector3.new(0, 5, 0) end
	elseif obj:IsA("BasePart") then
		return obj.Position + Vector3.new(0, 5, 0)
	end
	return nil
end

-- Scan workspace and build a list of all found teleportable locations
-- Only checks top-level + 1 level deep to avoid timeout
local function scanLocations()
	local found = {}
	local seen = {} -- avoid duplicates

	for _, searchName in ipairs(NBTF_SEARCH_NAMES) do
		local obj = findLocationByName(searchName)
		if obj and not seen[obj] then
			seen[obj] = true
			local pos = getLocationPosition(obj)
			if pos then
				table.insert(found, {name = obj.Name, pos = pos, obj = obj})
			end
		end
	end

	-- Also add SpawnLocations from top-level children only
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("SpawnLocation") and not seen[obj] then
			seen[obj] = true
			table.insert(found, {name = "Spawn: " .. obj.Name, pos = obj.Position + Vector3.new(0, 5, 0), obj = obj})
		end
	end

	-- Sort alphabetically
	table.sort(found, function(a, b) return a.name < b.name end)
	return found
end

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
titleText.Text = "NBTF Hub v2.0 - Nuclear Blast Testing Facility"
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
	createInfoLabel(tab, "Fires WeaponHit remote at nearest enemy when you shoot", o())
	createInfoLabel(tab, "Uses actual NBTF WeaponsSystem - no hookmetamethod needed!", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Wallbang (Shoot Through Walls)", o())
	createToggle(tab, "Wallbang", o(), function(on)
		if on then enableWallbang() else disableWallbang() end
	end)
	createInfoLabel(tab, "Fires WeaponHit with d=0/maxDist=0 - hits through any wall", o())

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
	createToggle(tab, "Aimbot Always-On (No Right-Click)", o(), function(on)
		aimbotAlwaysOn = on
		if on then notify("Aimbot", "Always-on mode!") end
	end)
	createSlider(tab, "Aim Smoothness", 10, 100, math.floor(aimbotSmooth * 100), o(), function(val)
		aimbotSmooth = val / 100
	end)
	createInfoLabel(tab, "Locks camera on nearest enemy. Always-on = no click needed.", o())
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
	createInfoLabel(tab, "Maxes AmmoCapacity/Reserves/Damage in weapon Configuration", o())
	createButton(tab, "Mod All Guns (Ammo + Damage + No Recoil)", o(), function()
		modGuns()
		notify("Mod Guns", "All guns modded! Max ammo, damage, zero recoil/spread")
	end)

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

	createSpacer(tab, o())

	createSectionLabel(tab, "Weapon Mods", o())
	createToggle(tab, "No Recoil", o(), function(on)
		noRecoilActive = on
		if on then startNoRecoil() else stopNoRecoil() end
	end)
	createToggle(tab, "Auto Fire (Hold LMB = Rapid)", o(), function(on)
		autoFireActive = on
		if on then startAutoFire() else stopAutoFire() end
	end)
	createInfoLabel(tab, "No recoil zeros gun config values. Auto fire spams tool:Activate()", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Protection", o())
	createToggle(tab, "God Mode (Infinite Health)", o(), function(on)
		godModeActive = on
		if on then startGodMode() else stopGodMode() end
	end)
	createInfoLabel(tab, "Heals to max every frame, prevents death states", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Player Control", o())
	createButton(tab, "Bring All Players to You", o(), bringAllPlayers)
	createButton(tab, "Kill All (WeaponHit Remote)", o(), killAllPlayers)
	createButton(tab, "Freeze All Players", o(), freezeAllPlayers)
	createButton(tab, "Unfreeze All Players", o(), unfreezeAllPlayers)
	createInfoLabel(tab, "Bring/freeze work on all non-team players", o())
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

	createSectionLabel(tab, "Vehicle Fly", o())
	createToggle(tab, "Vehicle Fly (Sit in Vehicle First)", o(), function(on)
		vehicleFlyActive = on
		if on then startVehicleFly() else stopVehicleFly() end
	end)
	createInfoLabel(tab, "Sit in any vehicle/car, then toggle to fly it", o())

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

	createSectionLabel(tab, "World", o())
	createSlider(tab, "Gravity", 0, 500, math.floor(gravityValue), o(), function(val)
		gravityValue = val
		setGravity(val)
	end)
	createInfoLabel(tab, "Default: 196. Lower = moon gravity. 0 = float.", o())

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
	createInfoLabel(tab, "Blue = Facility, Red = Rebel. Shows role + weapon.", o())

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

	createSectionLabel(tab, "Secret / Special Locations", o())
	createButton(tab, "TP: Secret Mod Room (Canyon Wall)", o(), function()
		-- Known NBTF invis/mod room coordinates
		local char = LocalPlayer.Character
		if char then
			char:PivotTo(CFrame.new(Vector3.new(-25.95, 84, 3537.55)))
			notify("Teleport", "Teleported to Secret Mod Room area!")
		end
	end)
	createInfoLabel(tab, "Behind Maintenance Offices on the Canyon Wall", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Facility Locations (Auto-Scanned)", o())
	createInfoLabel(tab, "Scans workspace for named areas - click Scan to find them", o())

	-- Location list container
	local locListFrame = Instance.new("Frame")
	locListFrame.Size = UDim2.new(1, 0, 0, 0)
	locListFrame.AutomaticSize = Enum.AutomaticSize.Y
	locListFrame.BackgroundTransparency = 1
	locListFrame.LayoutOrder = o()
	locListFrame.Parent = tab

	local locListLayout = Instance.new("UIListLayout")
	locListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	locListLayout.Padding = UDim.new(0, 3)
	locListLayout.Parent = locListFrame

	local function refreshLocations()
		for _, child in ipairs(locListFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		local locations = scanLocations()
		if #locations == 0 then
			notify("Scan", "No named locations found in workspace")
			return
		end
		for i, loc in ipairs(locations) do
			local locBtn = Instance.new("TextButton")
			locBtn.Size = UDim2.new(1, 0, 0, 26)
			locBtn.BackgroundColor3 = COLORS.panel
			locBtn.BorderSizePixel = 0
			locBtn.Text = "TP: " .. loc.name .. " (" .. math.floor(loc.pos.X) .. ", " .. math.floor(loc.pos.Y) .. ", " .. math.floor(loc.pos.Z) .. ")"
			locBtn.TextColor3 = COLORS.accent
			locBtn.Font = Enum.Font.Gotham
			locBtn.TextSize = 10
			locBtn.LayoutOrder = i
			locBtn.Parent = locListFrame
			addCorner(locBtn, 4)
			locBtn.MouseButton1Click:Connect(function()
				local char = LocalPlayer.Character
				if char then
					char:PivotTo(CFrame.new(loc.pos))
					notify("Teleport", loc.name)
				end
			end)
		end
		notify("Scan", "Found " .. #locations .. " locations!")
	end

	createButton(tab, "Scan Facility Locations", o(), refreshLocations)

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
				local color, roleName, teamName = getPlayerTeamInfo(player)
				local roleDisplay = ""
				if roleName ~= "" then
					roleDisplay = " [" .. roleName .. "]"
				elseif teamName ~= "" then
					roleDisplay = " [" .. teamName .. "]"
				end
				local pBtn = Instance.new("TextButton")
				pBtn.Size = UDim2.new(1, 0, 0, 26)
				pBtn.BackgroundColor3 = COLORS.panel
				pBtn.BorderSizePixel = 0
				pBtn.Text = player.DisplayName .. " (@" .. player.Name .. ")" .. roleDisplay
				pBtn.TextColor3 = color
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

	createSpacer(tab, o())

	createSectionLabel(tab, "Spectate", o())
	createInfoLabel(tab, "Click a player above to TP, or use buttons below to spectate", o())

	-- Spectate player list
	local specListFrame = Instance.new("Frame")
	specListFrame.Size = UDim2.new(1, 0, 0, 0)
	specListFrame.AutomaticSize = Enum.AutomaticSize.Y
	specListFrame.BackgroundTransparency = 1
	specListFrame.LayoutOrder = o()
	specListFrame.Parent = tab

	local specListLayout = Instance.new("UIListLayout")
	specListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	specListLayout.Padding = UDim.new(0, 3)
	specListLayout.Parent = specListFrame

	local function refreshSpecList()
		for _, child in ipairs(specListFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for i, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local sBtn = Instance.new("TextButton")
				sBtn.Size = UDim2.new(1, 0, 0, 24)
				sBtn.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
				sBtn.BorderSizePixel = 0
				sBtn.Text = "Spectate: " .. player.DisplayName
				sBtn.TextColor3 = Color3.fromRGB(180, 130, 255)
				sBtn.Font = Enum.Font.Gotham
				sBtn.TextSize = 10
				sBtn.LayoutOrder = i
				sBtn.Parent = specListFrame
				addCorner(sBtn, 4)
				sBtn.MouseButton1Click:Connect(function()
					spectatePlayer(player)
				end)
			end
		end
	end

	createButton(tab, "Stop Spectating", o(), unspectate)
	createButton(tab, "Refresh Spectate List", o(), refreshSpecList)
	refreshSpecList()
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
notify("NBTF Hub v2.0", "Loaded! Right Shift to toggle")
print("[NBTF Hub v2.0] Loaded - Right Shift to toggle")
print("[NBTF Hub v2.0] Tabs: Aim | Combat | Movement | Visuals | Teleport")
print("[NBTF Hub v2.0] Uses WeaponsSystem.Network.WeaponHit for kill/aim")
