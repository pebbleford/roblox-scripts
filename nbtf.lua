-- ================================================================
-- Synapse X The Revival - NBTF Hub v3.0
-- Nuclear Blast Testing Facility
-- Silent Aim | Wallbang | ESP | Aimbot | Fly | Teleports
-- Anti-Kick | Anti-Ragdoll | Weapon Selector | Player Actions
-- Stealth mode: cooldowns + delays to avoid detection
-- ================================================================

-- Cleanup old instance
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("SynapseXNBTF")
	if old then old:Destroy() end
end)
pcall(function()
	local old = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if old then
		local oldGui = old:FindFirstChild("SynapseXNBTF")
		if oldGui then oldGui:Destroy() end
	end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local TextChatService = nil
pcall(function() TextChatService = game:GetService("TextChatService") end)

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

-- Find any gun in the player's backpack (respects selectedWeapon if set)
local function findGunInBackpack()
	-- If a specific weapon is selected, try to find it first
	if selectedWeapon then
		for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == selectedWeapon then return tool end
		end
		local char = LocalPlayer.Character
		if char then
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") and tool.Name == selectedWeapon then return tool end
			end
		end
	end
	-- Auto-detect: find any known gun
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

-- ===================== COLOR PALETTE (Synapse X Orange Theme) =====================
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
local antiKickActive = false
local antiRagdollActive = false
local autoRejoinActive = false

local selectedWeapon = nil -- nil = auto-detect

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
local antiRagdollConnection = nil
local killAllDelay = 0.3

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

-- Silent aim connection + cooldown for stealth
local silentAimConnection = nil
local lastSilentAimFire = 0
local silentAimCooldown = 0.4 -- seconds between fires (looks like normal shooting)

local function enableSilentAim()
	silentAimActive = true

	if not WeaponHitRemote then
		notify("Silent Aim", "WeaponHit remote not found! Waiting for game to load...")
		pcall(function()
			WeaponHitRemote = game:GetService("ReplicatedStorage").WeaponsSystem.Network.WeaponHit
		end)
		if not WeaponHitRemote then
			notify("Error", "Could not find WeaponsSystem.Network.WeaponHit")
			return
		end
	end

	-- Stealth silent aim: only fires ONE extra WeaponHit per cooldown period
	-- Looks like a normal shot that just happens to hit the head
	silentAimConnection = RunService.Heartbeat:Connect(function()
		if not silentAimActive then return end
		pcall(function()
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end

			-- Cooldown to avoid spam detection
			local now = tick()
			if now - lastSilentAimFire < silentAimCooldown then return end

			local char = LocalPlayer.Character
			if not char then return end
			-- Only fire if we have a tool equipped (we're actually shooting)
			local equippedGun = char:FindFirstChildOfClass("Tool")
			if not equippedGun then return end

			local target = getClosestPlayerInFOV()
			if not target then target = getClosestPlayer3D() end
			if not target or not target.Parent then return end

			local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
			if not targetPlayer then return end
			if not calculateChance(hitChance) then return end

			fireWeaponHit(targetPlayer, equippedGun)
			lastSilentAimFire = now
		end)
	end)

	notify("Silent Aim", "Active (stealth mode - " .. silentAimCooldown .. "s cooldown)")
end

local function disableSilentAim()
	silentAimActive = false
	if silentAimConnection then silentAimConnection:Disconnect() silentAimConnection = nil end
	notify("Silent Aim", "Disabled")
end

-- ===================== WALLBANG (Stealth - single target through walls) =====================
-- Only fires at ONE closest enemy with cooldown - not all enemies every frame
local wallbangConnection = nil
local lastWallbangFire = 0
local wallbangCooldown = 0.5

local function enableWallbang()
	wallbangActive = true
	wallbangConnection = RunService.Heartbeat:Connect(function()
		if not wallbangActive then return end
		pcall(function()
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end

			local now = tick()
			if now - lastWallbangFire < wallbangCooldown then return end

			local char = LocalPlayer.Character
			if not char then return end
			local equippedGun = char:FindFirstChildOfClass("Tool")
			if not equippedGun then return end

			-- Only target the CLOSEST enemy, not all of them
			local target = getClosestPlayer3D()
			if not target or not target.Parent then return end
			local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
			if not targetPlayer then return end

			fireWeaponHit(targetPlayer, equippedGun)
			lastWallbangFire = now
		end)
	end)
	notify("Wallbang", "Active (stealth - hits closest enemy through walls)")
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

-- ===================== ANTI-KICK =====================
local function startAntiKick()
	-- Disable Idled connections
	pcall(function()
		if getconnections then
			for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
				conn:Disable()
			end
		end
	end)
	-- Hook Kick method via metatable (if executor supports it)
	pcall(function()
		if getrawmetatable and setreadonly and newcclosure then
			local mt = getrawmetatable(game)
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
	-- VirtualUser anti-idle as fallback
	task.spawn(function()
		while antiKickActive do
			pcall(function()
				local VU = game:GetService("VirtualUser")
				VU:CaptureController()
				VU:ClickButton2(Vector2.new())
			end)
			task.wait(60)
		end
	end)
	notify("Anti-Kick", "Kick protection active!")
end

-- ===================== ANTI-RAGDOLL =====================
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
	notify("Anti-Ragdoll", "Ragdoll prevention active!")
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

-- ===================== CHAT MESSAGE SENDER =====================
local function sendChatMessage(msg)
	if not msg or msg == "" then return end
	-- Method 1: TextChatService (modern)
	pcall(function()
		if TextChatService then
			local channel = TextChatService:FindFirstChild("TextChannels")
			if channel then
				local rbxGeneral = channel:FindFirstChild("RBXGeneral")
				if rbxGeneral then
					rbxGeneral:SendAsync(msg)
					return
				end
			end
		end
	end)
	-- Method 2: Legacy SayMessageRequest
	pcall(function()
		game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
			:FindFirstChild("SayMessageRequest"):FireServer(msg, "All")
	end)
end

-- ===================== CUSTOM ANNOUNCEMENT DISPLAY =====================
-- Replica of the NBTF Static Alert System / Rebellion Pirate Transmission
-- The real GUI requires Council Executive/Facility Director or Raid Leader/Warlord/Overseer
-- and is NEVER replicated to non-authorized players, so we build our own

local function showCustomAnnouncement(text, protocol, duration)
	duration = duration or 8
	protocol = protocol or "alert" -- alert, lockdown, core, normal

	-- Remove any existing announcement
	pcall(function()
		local old = game:GetService("CoreGui"):FindFirstChild("SX_Announcement")
		if old then old:Destroy() end
	end)

	local announceGui = Instance.new("ScreenGui")
	announceGui.Name = "SX_Announcement"
	announceGui.ResetOnSpawn = false
	announceGui.DisplayOrder = 999
	pcall(function() announceGui.Parent = game:GetService("CoreGui") end)
	if not announceGui.Parent then announceGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

	-- Get team info for styling
	local teamColor, roleName, teamName = getPlayerTeamInfo(LocalPlayer)
	local isRebel = teamName:lower():find("rebel") or teamName:lower():find("rebellion")

	-- Protocol colors
	local protocolColors = {
		normal = Color3.fromRGB(50, 130, 255),   -- Blue
		alert = Color3.fromRGB(255, 200, 60),     -- Yellow
		lockdown = Color3.fromRGB(255, 50, 50),   -- Red
		core = Color3.fromRGB(30, 30, 30),        -- Black
	}
	local protocolNames = {
		normal = "AREA SCAN PROTOCOL",
		alert = "HOLD AND SECURE PROTOCOL",
		lockdown = "LOCKDOWN PROTOCOL",
		core = "CORE COMPROMISED - EVACUATE",
	}
	local pColor = protocolColors[protocol] or protocolColors.alert

	-- Main container
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.5, 0, 0, 120)
	container.Position = UDim2.new(0.25, 0, 0, -130)
	container.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
	container.BorderSizePixel = 0
	container.Parent = announceGui
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 12)
	cc.Parent = container

	-- Top stripe (blue for facility, red for rebels)
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(1, 0, 0, 28)
	stripe.BackgroundColor3 = isRebel and Color3.fromRGB(180, 30, 30) or Color3.fromRGB(30, 80, 180)
	stripe.BorderSizePixel = 0
	stripe.Parent = container
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 12)
	sc.Parent = stripe
	-- Fix bottom corners of stripe
	local stripeFix = Instance.new("Frame")
	stripeFix.Size = UDim2.new(1, 0, 0, 12)
	stripeFix.Position = UDim2.new(0, 0, 1, -12)
	stripeFix.BackgroundColor3 = stripe.BackgroundColor3
	stripeFix.BorderSizePixel = 0
	stripeFix.Parent = stripe

	-- Stripe text
	local stripeText = Instance.new("TextLabel")
	stripeText.Size = UDim2.new(1, -20, 1, 0)
	stripeText.Position = UDim2.new(0, 10, 0, 0)
	stripeText.BackgroundTransparency = 1
	stripeText.Text = isRebel and "REBELLION PIRATE TRANSMISSION" or "NBTF STATIC ALERT SYSTEM"
	stripeText.TextColor3 = Color3.fromRGB(255, 255, 255)
	stripeText.Font = Enum.Font.GothamBold
	stripeText.TextSize = 13
	stripeText.TextXAlignment = Enum.TextXAlignment.Left
	stripeText.Parent = stripe

	-- Protocol label
	local protoLabel = Instance.new("TextLabel")
	protoLabel.Size = UDim2.new(1, -20, 0, 18)
	protoLabel.Position = UDim2.new(0, 10, 0, 32)
	protoLabel.BackgroundTransparency = 1
	protoLabel.Text = protocolNames[protocol] or "ALERT"
	protoLabel.TextColor3 = pColor
	protoLabel.Font = Enum.Font.GothamBold
	protoLabel.TextSize = 11
	protoLabel.TextXAlignment = Enum.TextXAlignment.Left
	protoLabel.Parent = container

	-- Sender info
	local senderLabel = Instance.new("TextLabel")
	senderLabel.Size = UDim2.new(0.4, -10, 0, 14)
	senderLabel.Position = UDim2.new(0, 10, 0, 52)
	senderLabel.BackgroundTransparency = 1
	senderLabel.Text = LocalPlayer.DisplayName .. (roleName ~= "" and (" - " .. roleName) or "")
	senderLabel.TextColor3 = Color3.fromRGB(160, 170, 190)
	senderLabel.Font = Enum.Font.Gotham
	senderLabel.TextSize = 10
	senderLabel.TextXAlignment = Enum.TextXAlignment.Left
	senderLabel.Parent = container

	-- Message text
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Size = UDim2.new(1, -20, 0, 42)
	msgLabel.Position = UDim2.new(0, 10, 0, 70)
	msgLabel.BackgroundTransparency = 1
	msgLabel.Text = text
	msgLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
	msgLabel.Font = Enum.Font.Gotham
	msgLabel.TextSize = 14
	msgLabel.TextWrapped = true
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.TextYAlignment = Enum.TextYAlignment.Top
	msgLabel.Parent = container

	-- Slide in from top
	container:TweenPosition(UDim2.new(0.25, 0, 0, 15), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.4, true)

	-- Auto dismiss
	task.delay(duration, function()
		pcall(function()
			container:TweenPosition(UDim2.new(0.25, 0, 0, -130), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.4, true)
			task.wait(0.5)
			announceGui:Destroy()
		end)
	end)
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
			if hum then
				camera.CameraSubject = hum
				camera.CameraType = Enum.CameraType.Custom
			end
		end
	end)
	spectateTarget = nil
	spectateActive = false
	notify("Spectate", "Stopped - camera returned to you")
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

-- ===================== KILL ALL (Stealth - Delayed WeaponHit) =====================
-- Fires at each enemy with delays to avoid detection
-- Uses only ONE gun, 3 rounds per player, 0.3s between each fire
local killAllRunning = false

local function killAllPlayers()
	if not WeaponHitRemote then
		notify("Error", "WeaponHit remote not found!")
		return
	end
	if killAllRunning then
		notify("Kill All", "Already running! Wait for it to finish.")
		return
	end

	task.spawn(function()
		killAllRunning = true
		local gun = findGunInBackpack()
		if not gun then
			-- Try equipped tool
			local char = LocalPlayer.Character
			if char then
				gun = char:FindFirstChildOfClass("Tool")
			end
		end
		if not gun then
			notify("Error", "No gun found! Equip a weapon first.")
			killAllRunning = false
			return
		end

		local killed = 0
		local targets = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and isAlive(player) then
				table.insert(targets, player)
			end
		end

		notify("Kill All", "Targeting " .. #targets .. " players (stealth mode)...")

		-- 3 rounds per target, configurable delay between each fire
		for round = 1, 3 do
			for _, player in ipairs(targets) do
				if not killAllRunning then break end
				if isAlive(player) then
					pcall(function()
						fireWeaponHit(player, gun)
					end)
					if round == 1 then killed = killed + 1 end
					task.wait(killAllDelay)
				end
			end
			if not killAllRunning then break end
			task.wait(0.5) -- pause between rounds
		end

		killAllRunning = false
		notify("Kill All", "Done! Fired at " .. killed .. " players (3 rounds each)")
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

-- Get position from a found object (small offset so you don't clip into floor)
local function getLocationPosition(obj)
	if obj:IsA("Model") then
		local primary = obj.PrimaryPart
		if primary then return primary.Position + Vector3.new(0, 3, 0) end
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then return part.Position + Vector3.new(0, 3, 0) end
	elseif obj:IsA("BasePart") then
		return obj.Position + Vector3.new(0, 3, 0)
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
screenGui.Name = "SynapseXNBTF"
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
mainFrame.Size = UDim2.new(0, 560, 0, 500)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -250)
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
titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
addCorner(titleBar, 8)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 10)
titleFix.Position = UDim2.new(0, 0, 1, -10)
titleFix.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Synapse X The Revival - NBTF Hub v3.0"
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

local tabNames = {"Aim", "Combat", "Movement", "Visuals", "Teleport", "Players", "Settings"}
local tabButtons = {}
local tabFrames = {}

for i, name in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 80, 1, 0)
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

	createSpacer(tab, o())

	createSectionLabel(tab, "Weapon Selector", o())
	createInfoLabel(tab, "Choose which gun silent aim/wallbang uses (Auto = first found)", o())

	local weaponBtns = {}
	local weaponListFrame = Instance.new("Frame")
	weaponListFrame.Size = UDim2.new(1, 0, 0, 0)
	weaponListFrame.AutomaticSize = Enum.AutomaticSize.Y
	weaponListFrame.BackgroundTransparency = 1
	weaponListFrame.LayoutOrder = o()
	weaponListFrame.Parent = tab

	local weaponListLayout = Instance.new("UIListLayout")
	weaponListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	weaponListLayout.Padding = UDim.new(0, 3)
	weaponListLayout.FillDirection = Enum.FillDirection.Horizontal
	weaponListLayout.Wraps = true
	weaponListLayout.Parent = weaponListFrame

	local function updateWeaponHighlight()
		for name, btn in pairs(weaponBtns) do
			if name == (selectedWeapon or "Auto") then
				btn.BackgroundColor3 = COLORS.accent
				btn.TextColor3 = Color3.fromRGB(10, 10, 10)
			else
				btn.BackgroundColor3 = COLORS.panel
				btn.TextColor3 = COLORS.textSecondary
			end
		end
	end

	local function makeWeaponBtn(name, order)
		local wb = Instance.new("TextButton")
		wb.Size = UDim2.new(0, 85, 0, 24)
		wb.BackgroundColor3 = COLORS.panel
		wb.BorderSizePixel = 0
		wb.Text = name
		wb.TextColor3 = COLORS.textSecondary
		wb.Font = Enum.Font.Gotham
		wb.TextSize = 9
		wb.TextTruncate = Enum.TextTruncate.AtEnd
		wb.LayoutOrder = order
		wb.Parent = weaponListFrame
		addCorner(wb, 4)
		weaponBtns[name] = wb
		wb.MouseButton1Click:Connect(function()
			if name == "Auto" then
				selectedWeapon = nil
			else
				selectedWeapon = name
			end
			updateWeaponHighlight()
			notify("Weapon", name == "Auto" and "Auto-detect mode" or "Using: " .. name)
		end)
	end

	makeWeaponBtn("Auto", 1)
	for i, gunName in ipairs(NBTF_GUNS) do
		makeWeaponBtn(gunName, i + 1)
	end
	updateWeaponHighlight()
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
	createToggle(tab, "Anti-Ragdoll (No Knockdown)", o(), function(on)
		antiRagdollActive = on
		if on then startAntiRagdoll() else stopAntiRagdoll() end
	end)
	createInfoLabel(tab, "Prevents ragdoll/falling states (lighter than God Mode)", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Player Control", o())
	createButton(tab, "Bring All Players to You", o(), bringAllPlayers)
	createButton(tab, "Kill All (WeaponHit Remote)", o(), killAllPlayers)
	createButton(tab, "Freeze All Players", o(), freezeAllPlayers)
	createButton(tab, "Unfreeze All Players", o(), unfreezeAllPlayers)
	createInfoLabel(tab, "Bring/freeze work on all non-team players", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Announcement System", o())
	createInfoLabel(tab, "TP to Broadcast Room + auto-fire the console prompt to open GUI", o())
	createInfoLabel(tab, "Uses noclip to bypass keycard door", o())

	createButton(tab, "TP to Broadcast Room + Open Console", o(), function()
		local char = LocalPlayer.Character
		if not char then return end

		-- Enable noclip temporarily to get through keycard doors
		local tempNoclip = RunService.Stepped:Connect(function()
			pcall(function()
				if not char then return end
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then part.CanCollide = false end
				end
			end)
		end)

		-- Search for broadcast/announcement room
		local searchTerms = {"broadcast", "broadcasting", "announc", "alert room",
			"alert system", "static alert", "control room", "control tablet",
			"facility control", "announcement center", "pirate transmission"}
		local found = nil
		for _, obj in ipairs(workspace:GetDescendants()) do
			if found then break end
			pcall(function()
				local n = obj.Name:lower()
				for _, term in ipairs(searchTerms) do
					if n:find(term, 1, true) then
						if obj:IsA("BasePart") or obj:IsA("Model") then
							found = obj
						end
						return
					end
				end
			end)
		end

		-- Fallback: try SCC area
		if not found then
			found = findLocationByName("SCC") or findLocationByName("Strategic") or findLocationByName("Executive")
		end

		if found then
			local pos = getLocationPosition(found)
			if not pos and found:IsA("BasePart") then pos = found.Position + Vector3.new(0, 3, 0) end
			if pos then
				char:PivotTo(CFrame.new(pos))
				notify("Teleport", "TP to: " .. found.Name .. " - looking for console...")
			end
		else
			notify("Error", "Broadcast Room not found - use Print Workspace Names")
		end

		-- Wait a moment then search for ProximityPrompts and ClickDetectors nearby
		task.wait(0.5)

		-- Fire ALL ProximityPrompts within 50 studs
		local hrp = getRoot()
		local promptsFired = 0
		if hrp then
			for _, obj in ipairs(workspace:GetDescendants()) do
				pcall(function()
					if obj:IsA("ProximityPrompt") then
						local promptPart = obj.Parent
						if promptPart and promptPart:IsA("BasePart") then
							local dist = (promptPart.Position - hrp.Position).Magnitude
							if dist < 50 then
								-- Fire the prompt
								local oldHold = obj.HoldDuration
								local oldDist = obj.MaxActivationDistance
								obj.MaxActivationDistance = 100
								obj.HoldDuration = 0
								-- Try multiple methods to fire
								pcall(function()
									if fireproximityprompt then
										fireproximityprompt(obj)
									end
								end)
								pcall(function()
									obj:InputHoldBegin()
									task.wait(0.1)
									obj:InputHoldEnd()
								end)
								obj.MaxActivationDistance = oldDist
								obj.HoldDuration = oldHold
								promptsFired = promptsFired + 1
								print("[SX NBTF] Fired prompt: " .. obj.Parent.Name .. " (" .. math.floor(dist) .. "m)")
							end
						end
					elseif obj:IsA("ClickDetector") then
						local detPart = obj.Parent
						if detPart and detPart:IsA("BasePart") then
							local dist = (detPart.Position - hrp.Position).Magnitude
							if dist < 50 then
								pcall(function()
									if fireclickdetector then
										fireclickdetector(obj)
									end
								end)
								promptsFired = promptsFired + 1
								print("[SX NBTF] Fired click detector: " .. obj.Parent.Name .. " (" .. math.floor(dist) .. "m)")
							end
						end
					end
				end)
			end
		end

		-- Disable temp noclip after 3 seconds
		task.delay(3, function()
			pcall(function() tempNoclip:Disconnect() end)
		end)

		if promptsFired > 0 then
			notify("Announce", "Fired " .. promptsFired .. " prompts - check your screen!")
		else
			notify("Announce", "No prompts found nearby - try walking up to the console")
		end
	end)

	createButton(tab, "Fire ALL Nearby Prompts (within 30m)", o(), function()
		local hrp = getRoot()
		if not hrp then notify("Error", "No character") return end
		local count = 0
		for _, obj in ipairs(workspace:GetDescendants()) do
			pcall(function()
				if obj:IsA("ProximityPrompt") then
					local promptPart = obj.Parent
					if promptPart and promptPart:IsA("BasePart") then
						local dist = (promptPart.Position - hrp.Position).Magnitude
						if dist < 30 then
							local oldHold = obj.HoldDuration
							local oldDist = obj.MaxActivationDistance
							obj.MaxActivationDistance = 100
							obj.HoldDuration = 0
							pcall(function()
								if fireproximityprompt then fireproximityprompt(obj) end
							end)
							pcall(function()
								obj:InputHoldBegin()
								task.wait(0.1)
								obj:InputHoldEnd()
							end)
							obj.MaxActivationDistance = oldDist
							obj.HoldDuration = oldHold
							count = count + 1
							print("[SX NBTF] Fired: " .. obj.Parent.Name .. " [" .. (obj.ActionText ~= "" and obj.ActionText or obj.ObjectText) .. "]")
						end
					end
				elseif obj:IsA("ClickDetector") then
					local detPart = obj.Parent
					if detPart and detPart:IsA("BasePart") then
						local dist = (detPart.Position - hrp.Position).Magnitude
						if dist < 30 then
							pcall(function()
								if fireclickdetector then fireclickdetector(obj) end
							end)
							count = count + 1
							print("[SX NBTF] Fired click: " .. obj.Parent.Name)
						end
					end
				end
			end)
		end
		notify("Prompts", "Fired " .. count .. " nearby prompts/detectors")
	end)

	createButton(tab, "List ALL Prompts Near You (F9)", o(), function()
		local hrp = getRoot()
		if not hrp then notify("Error", "No character") return end
		print("=== PROMPTS WITHIN 100m ===")
		local count = 0
		for _, obj in ipairs(workspace:GetDescendants()) do
			pcall(function()
				if obj:IsA("ProximityPrompt") then
					local promptPart = obj.Parent
					if promptPart and promptPart:IsA("BasePart") then
						local dist = (promptPart.Position - hrp.Position).Magnitude
						if dist < 100 then
							count = count + 1
							print(math.floor(dist) .. "m | " .. obj.Parent:GetFullName()
								.. " | Action: " .. obj.ActionText
								.. " | Object: " .. obj.ObjectText
								.. " | Enabled: " .. tostring(obj.Enabled)
								.. " | Hold: " .. tostring(obj.HoldDuration) .. "s")
						end
					end
				elseif obj:IsA("ClickDetector") then
					local detPart = obj.Parent
					if detPart and detPart:IsA("BasePart") then
						local dist = (detPart.Position - hrp.Position).Magnitude
						if dist < 100 then
							count = count + 1
							print(math.floor(dist) .. "m | ClickDetector: " .. obj.Parent:GetFullName())
						end
					end
				end
			end)
		end
		print("=== " .. count .. " PROMPTS FOUND ===")
		notify("Debug", count .. " prompts/detectors printed to F9")
	end)

	createSpacer(tab, o())

	-- Keep the custom announcement for fun / local display
	createSectionLabel(tab, "Custom Announcement (Local Only)", o())
	local announcementText = "Alert: All personnel report to SCC immediately"
	local announceTB = Instance.new("TextBox")
	announceTB.Size = UDim2.new(1, 0, 0, 28)
	announceTB.BackgroundColor3 = COLORS.panel
	announceTB.BorderSizePixel = 0
	announceTB.Text = announcementText
	announceTB.PlaceholderText = "Type announcement here..."
	announceTB.TextColor3 = COLORS.textPrimary
	announceTB.PlaceholderColor3 = COLORS.textDim
	announceTB.Font = Enum.Font.Gotham
	announceTB.TextSize = 11
	announceTB.ClearTextOnFocus = false
	announceTB.LayoutOrder = o()
	announceTB.Parent = tab
	addCorner(announceTB, 5)
	local tbPad = Instance.new("UIPadding")
	tbPad.PaddingLeft = UDim.new(0, 8)
	tbPad.PaddingRight = UDim.new(0, 8)
	tbPad.Parent = announceTB
	announceTB:GetPropertyChangedSignal("Text"):Connect(function()
		announcementText = announceTB.Text
	end)

	local selectedProtocol = "alert"
	local protoFrame = Instance.new("Frame")
	protoFrame.Size = UDim2.new(1, 0, 0, 26)
	protoFrame.BackgroundTransparency = 1
	protoFrame.LayoutOrder = o()
	protoFrame.Parent = tab
	local protoLayout = Instance.new("UIListLayout")
	protoLayout.FillDirection = Enum.FillDirection.Horizontal
	protoLayout.Padding = UDim.new(0, 4)
	protoLayout.Parent = protoFrame
	local protoBtns = {}
	local protocols = {
		{id = "normal", label = "Normal", color = Color3.fromRGB(50, 130, 255)},
		{id = "alert", label = "Alert", color = Color3.fromRGB(255, 200, 60)},
		{id = "lockdown", label = "Lockdown", color = Color3.fromRGB(255, 50, 50)},
		{id = "core", label = "Core", color = Color3.fromRGB(80, 80, 80)},
	}
	for i, proto in ipairs(protocols) do
		local pb = Instance.new("TextButton")
		pb.Size = UDim2.new(0, 75, 0, 24)
		pb.BackgroundColor3 = proto.id == selectedProtocol and proto.color or COLORS.panel
		pb.BorderSizePixel = 0
		pb.Text = proto.label
		pb.TextColor3 = COLORS.textPrimary
		pb.Font = Enum.Font.GothamBold
		pb.TextSize = 10
		pb.LayoutOrder = i
		pb.Parent = protoFrame
		addCorner(pb, 4)
		protoBtns[proto.id] = {btn = pb, color = proto.color}
		pb.MouseButton1Click:Connect(function()
			selectedProtocol = proto.id
			for pid, data in pairs(protoBtns) do
				data.btn.BackgroundColor3 = pid == selectedProtocol and data.color or COLORS.panel
			end
		end)
	end
	createButton(tab, "Show Local Announcement", o(), function()
		showCustomAnnouncement(announcementText, selectedProtocol, 8)
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "GUI & Remote Debug", o())

	createButton(tab, "Force Show ALL Hidden GUIs", o(), function()
		local count = 0
		pcall(function()
			for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
				if gui:IsA("ScreenGui") and not gui.Enabled then
					gui.Enabled = true
					count = count + 1
					print("[SX NBTF] Enabled: " .. gui.Name)
				end
			end
		end)
		-- Also unhide all frames inside enabled GUIs
		pcall(function()
			for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
				if gui:IsA("ScreenGui") then
					for _, desc in ipairs(gui:GetDescendants()) do
						if (desc:IsA("Frame") or desc:IsA("TextButton") or desc:IsA("ImageButton")) and not desc.Visible then
							desc.Visible = true
							count = count + 1
						end
					end
				end
			end
		end)
		-- Clone announcement GUIs from ReplicatedStorage/StarterGui
		local cloneContainers = {}
		pcall(function() table.insert(cloneContainers, game:GetService("ReplicatedStorage")) end)
		pcall(function() table.insert(cloneContainers, game:GetService("StarterGui")) end)
		for _, container in ipairs(cloneContainers) do
			pcall(function()
				for _, obj in ipairs(container:GetDescendants()) do
					if obj:IsA("ScreenGui") then
						local n = obj.Name:lower()
						if n:find("announce") or n:find("alert") or n:find("broadcast")
							or n:find("transmission") or n:find("tablet") or n:find("control") then
							local clone = obj:Clone()
							clone.Parent = LocalPlayer.PlayerGui
							clone.Enabled = true
							count = count + 1
							print("[SX NBTF] Cloned: " .. obj:GetFullName())
						end
					end
				end
			end)
		end
		notify("GUIs", "Enabled/unhidden/cloned " .. count .. " elements")
	end)

	createButton(tab, "Dump ALL GUIs to F9", o(), function()
		pcall(function()
			print("=== FULL GUI SCAN ===")
			local containers = {
				{name = "PlayerGui", obj = LocalPlayer.PlayerGui},
			}
			pcall(function() table.insert(containers, {name = "StarterGui", obj = game:GetService("StarterGui")}) end)
			pcall(function() table.insert(containers, {name = "ReplicatedStorage", obj = game:GetService("ReplicatedStorage")}) end)
			pcall(function() table.insert(containers, {name = "ReplicatedFirst", obj = game:GetService("ReplicatedFirst")}) end)
			for _, c in ipairs(containers) do
				print("--- " .. c.name .. " ---")
				for _, gui in ipairs(c.obj:GetDescendants()) do
					if gui:IsA("ScreenGui") or gui:IsA("Frame") or gui:IsA("TextButton") then
						local vis = ""
						if gui:IsA("ScreenGui") then
							vis = gui.Enabled and "ENABLED" or "disabled"
						else
							vis = gui.Visible and "VISIBLE" or "hidden"
						end
						print(vis .. " | " .. gui.ClassName .. ": " .. gui:GetFullName())
					end
				end
			end
			print("=== END SCAN ===")
		end)
		notify("Debug", "Full GUI scan printed to F9 console")
	end)

	createButton(tab, "List All Remotes (F9)", o(), function()
		pcall(function()
			print("=== ALL REMOTES ===")
			local containers = {}
			pcall(function() table.insert(containers, game:GetService("ReplicatedStorage")) end)
			pcall(function() table.insert(containers, workspace) end)
			for _, container in ipairs(containers) do
				for _, obj in ipairs(container:GetDescendants()) do
					if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
						print(obj.ClassName .. ": " .. obj:GetFullName())
					end
				end
			end
			print("=== END ===")
		end)
		notify("Remotes", "Printed to F9 console")
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Rank Change", o())
	createInfoLabel(tab, "Searches for rank/role remotes (may be patched)", o())

	createButton(tab, "Try Change Rank (prints result to F9)", o(), function()
		pcall(function()
			local RS = game:GetService("ReplicatedStorage")
			-- Search for any rank-related remote
			local found = false
			for _, obj in ipairs(RS:GetDescendants()) do
				if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
					local n = obj.Name:lower()
					if n:find("rank") or n:find("role") or n:find("promote") or n:find("setrank") then
						print("[SX NBTF] Found rank remote: " .. obj:GetFullName())
						if obj:IsA("RemoteEvent") then
							obj:FireServer("Ultimate")
							print("[SX NBTF] Fired: " .. obj.Name .. " with 'Ultimate'")
						end
						found = true
					end
				end
			end
			if not found then
				print("[SX NBTF] No rank remotes found - may be patched")
				notify("Rank", "No rank remote found - likely patched")
			else
				notify("Rank", "Fired rank remotes - check if it worked")
			end
		end)
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Chat Commands", o())
	local chatText = ""
	local chatTB = Instance.new("TextBox")
	chatTB.Size = UDim2.new(1, 0, 0, 28)
	chatTB.BackgroundColor3 = COLORS.panel
	chatTB.BorderSizePixel = 0
	chatTB.Text = ""
	chatTB.PlaceholderText = "Type chat message..."
	chatTB.TextColor3 = COLORS.textPrimary
	chatTB.PlaceholderColor3 = COLORS.textDim
	chatTB.Font = Enum.Font.Gotham
	chatTB.TextSize = 11
	chatTB.ClearTextOnFocus = false
	chatTB.LayoutOrder = o()
	chatTB.Parent = tab
	addCorner(chatTB, 5)
	local chatPad = Instance.new("UIPadding")
	chatPad.PaddingLeft = UDim.new(0, 8)
	chatPad.PaddingRight = UDim.new(0, 8)
	chatPad.Parent = chatTB
	chatTB:GetPropertyChangedSignal("Text"):Connect(function()
		chatText = chatTB.Text
	end)

	createButton(tab, "Send Chat Message", o(), function()
		if chatText ~= "" then
			sendChatMessage(chatText)
			notify("Chat", "Sent: " .. chatText)
		end
	end)
	createInfoLabel(tab, "Sends via TextChatService or legacy SayMessageRequest", o())
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

	createSectionLabel(tab, "AFK & Protection", o())
	createToggle(tab, "Anti-AFK (Prevent Idle Kick)", o(), function(on)
		antiAfkActive = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)
	createToggle(tab, "Anti-Kick (Block Server Kicks)", o(), function(on)
		antiKickActive = on
		if on then startAntiKick() end
	end)
	createInfoLabel(tab, "Disables Idled + hooks Kick method (needs executor support)", o())
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
	createButton(tab, "TP: Mod Room / Regular Lounge", o(), function()
		local char = LocalPlayer.Character
		if not char then return end
		local searchTerms = {
			"secret", "mod room", "regular lounge", "lounge", "modroom",
			"secretarea", "secret area", "regularlounge", "hidden",
			"canyon", "mod_room", "moderator"
		}
		local found = nil
		-- Search workspace 3 levels deep
		for _, obj in ipairs(workspace:GetChildren()) do
			local n = obj.Name:lower()
			for _, term in ipairs(searchTerms) do
				if n:find(term, 1, true) then found = obj break end
			end
			if found then break end
			if obj:IsA("Model") or obj:IsA("Folder") then
				pcall(function()
					for _, child in ipairs(obj:GetChildren()) do
						if found then return end
						local cn = child.Name:lower()
						for _, term in ipairs(searchTerms) do
							if cn:find(term, 1, true) then found = child return end
						end
						if (child:IsA("Model") or child:IsA("Folder")) then
							for _, gc in ipairs(child:GetChildren()) do
								if found then return end
								local gn = gc.Name:lower()
								for _, term in ipairs(searchTerms) do
									if gn:find(term, 1, true) then found = gc return end
								end
							end
						end
					end
				end)
			end
			if found then break end
		end
		if found then
			local pos = nil
			if found:IsA("Model") then
				local pp = found.PrimaryPart or found:FindFirstChildWhichIsA("BasePart")
				if pp then pos = pp.Position + Vector3.new(0, 3, 0) end
			elseif found:IsA("BasePart") then
				pos = found.Position + Vector3.new(0, 3, 0)
			end
			if pos then
				char:PivotTo(CFrame.new(pos))
				notify("Teleport", "Found: " .. found.Name)
				return
			end
		end
		-- Fallback: try Maintenance
		local maint = findLocationByName("Maintenance")
		if maint then
			local pos = getLocationPosition(maint)
			if pos then
				char:PivotTo(CFrame.new(pos))
				notify("Teleport", "TP to Maintenance (Mod Room behind it on canyon wall)")
				return
			end
		end
		notify("Error", "Not found - click 'Print Workspace Names' and check F9")
	end)
	createButton(tab, "Print Workspace Names (F9)", o(), function()
		pcall(function()
			print("=== Workspace Top-Level ===")
			for _, obj in ipairs(workspace:GetChildren()) do
				local info = obj.ClassName .. ": " .. obj.Name
				if obj:IsA("BasePart") then
					info = info .. " @ " .. tostring(obj.Position)
				end
				print(info)
				if obj:IsA("Model") or obj:IsA("Folder") then
					for _, child in ipairs(obj:GetChildren()) do
						if child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart") then
							local cinfo = "  " .. child.ClassName .. ": " .. child.Name
							if child:IsA("BasePart") then
								cinfo = cinfo .. " @ " .. tostring(child.Position)
							end
							print(cinfo)
						end
					end
				end
			end
			print("=== End ===")
		end)
		notify("Debug", "Workspace names printed to F9 console")
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
				sBtn.BackgroundColor3 = COLORS.panel
				sBtn.BorderSizePixel = 0
				sBtn.Text = "Spectate: " .. player.DisplayName
				sBtn.TextColor3 = COLORS.accent
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

-- ===================== BUILD PLAYERS TAB =====================
do
	local tab = tabFrames["Players"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Player Actions", o())
	createInfoLabel(tab, "Per-player actions: Kill, Bring, Teleport, Spectate", o())

	local playerActionsFrame = Instance.new("Frame")
	playerActionsFrame.Size = UDim2.new(1, 0, 0, 0)
	playerActionsFrame.AutomaticSize = Enum.AutomaticSize.Y
	playerActionsFrame.BackgroundTransparency = 1
	playerActionsFrame.LayoutOrder = o()
	playerActionsFrame.Parent = tab

	local playerActionsLayout = Instance.new("UIListLayout")
	playerActionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerActionsLayout.Padding = UDim.new(0, 4)
	playerActionsLayout.Parent = playerActionsFrame

	local function refreshPlayerActions()
		for _, child in ipairs(playerActionsFrame:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		local idx = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				idx = idx + 1
				local color, roleName, teamName = getPlayerTeamInfo(player)
				local roleDisplay = ""
				if roleName ~= "" then
					roleDisplay = " [" .. roleName .. "]"
				elseif teamName ~= "" then
					roleDisplay = " [" .. teamName .. "]"
				end

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 32)
				row.BackgroundColor3 = COLORS.panel
				row.BorderSizePixel = 0
				row.LayoutOrder = idx
				row.Parent = playerActionsFrame
				addCorner(row, 5)

				local nameLbl = Instance.new("TextLabel")
				nameLbl.Size = UDim2.new(1, -220, 1, 0)
				nameLbl.Position = UDim2.new(0, 8, 0, 0)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Text = player.DisplayName .. roleDisplay
				nameLbl.TextColor3 = color
				nameLbl.Font = Enum.Font.Gotham
				nameLbl.TextSize = 10
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nameLbl.Parent = row

				-- Action buttons
				local actions = {
					{text = "Kill", offset = 215, fn = function()
						local gun = findGunInBackpack()
						if gun then
							task.spawn(function()
								for i = 1, 3 do
									fireWeaponHit(player, gun)
									task.wait(0.3)
								end
							end)
							notify("Kill", "Fired at " .. player.DisplayName)
						else
							notify("Error", "No gun found!")
						end
					end},
					{text = "Bring", offset = 165, fn = function()
						pcall(function()
							local myHRP = getRoot()
							local theirHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
							if myHRP and theirHRP then
								theirHRP.CFrame = myHRP.CFrame + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
								notify("Bring", "Brought " .. player.DisplayName)
							end
						end)
					end},
					{text = "TP", offset = 120, fn = function()
						teleportToPlayer(player.Name)
					end},
					{text = "Spec", offset = 75, fn = function()
						spectatePlayer(player)
					end},
				}

				for _, action in ipairs(actions) do
					local abtn = Instance.new("TextButton")
					abtn.Size = UDim2.new(0, 40, 0, 22)
					abtn.Position = UDim2.new(1, -action.offset, 0.5, -11)
					abtn.BackgroundColor3 = COLORS.accent
					abtn.BorderSizePixel = 0
					abtn.Text = action.text
					abtn.TextColor3 = Color3.fromRGB(10, 10, 10)
					abtn.Font = Enum.Font.GothamBold
					abtn.TextSize = 9
					abtn.Parent = row
					addCorner(abtn, 4)
					abtn.MouseEnter:Connect(function() abtn.BackgroundColor3 = COLORS.accentHover end)
					abtn.MouseLeave:Connect(function() abtn.BackgroundColor3 = COLORS.accent end)
					abtn.MouseButton1Click:Connect(action.fn)
				end
			end
		end
	end

	createButton(tab, "Refresh Player List", o(), refreshPlayerActions)
	refreshPlayerActions()

	-- Auto-refresh on player join/leave
	Players.PlayerAdded:Connect(function() task.wait(1) refreshPlayerActions() end)
	Players.PlayerRemoving:Connect(function() task.wait(0.5) refreshPlayerActions() end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Target Info", o())
	local targetInfoLabel = Instance.new("TextLabel")
	targetInfoLabel.Size = UDim2.new(1, 0, 0, 24)
	targetInfoLabel.BackgroundColor3 = COLORS.panel
	targetInfoLabel.BorderSizePixel = 0
	targetInfoLabel.Text = "No target - enable Silent Aim or Aimbot"
	targetInfoLabel.TextColor3 = COLORS.textSecondary
	targetInfoLabel.Font = Enum.Font.Gotham
	targetInfoLabel.TextSize = 10
	targetInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
	targetInfoLabel.LayoutOrder = o()
	targetInfoLabel.Parent = tab
	addCorner(targetInfoLabel, 5)
	local tipPad = Instance.new("UIPadding")
	tipPad.PaddingLeft = UDim.new(0, 8)
	tipPad.Parent = targetInfoLabel

	-- Update target info periodically
	task.spawn(function()
		while task.wait(0.5) do
			pcall(function()
				if not silentAimActive and not aimbotActive then
					targetInfoLabel.Text = "No target - enable Silent Aim or Aimbot"
					targetInfoLabel.TextColor3 = COLORS.textSecondary
					return
				end
				local target = getClosestPlayerInFOV()
				if not target then target = getClosestPlayer3D() end
				if target and target.Parent then
					local p = Players:GetPlayerFromCharacter(target.Parent)
					if p then
						local hum = target.Parent:FindFirstChildOfClass("Humanoid")
						local hp = hum and math.floor((hum.Health / hum.MaxHealth) * 100) or 0
						local myRoot = getRoot()
						local dist = myRoot and math.floor((target.Position - myRoot.Position).Magnitude) or 0
						local weapon = target.Parent:FindFirstChildOfClass("Tool")
						local weaponName = weapon and weapon.Name or "None"
						targetInfoLabel.Text = "Target: " .. p.DisplayName .. " | HP: " .. hp .. "% | " .. dist .. "m | Weapon: " .. weaponName
						targetInfoLabel.TextColor3 = COLORS.accent
					end
				else
					targetInfoLabel.Text = "No enemy in range"
					targetInfoLabel.TextColor3 = COLORS.textDim
				end
			end)
		end
	end)

	createSpacer(tab, o())

	createButton(tab, "Stop Spectating", o(), unspectate)
end

-- ===================== BUILD SETTINGS TAB =====================
do
	local tab = tabFrames["Settings"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Keybinds", o())
	createInfoLabel(tab, "Right Shift = Toggle GUI window", o())
	createInfoLabel(tab, "GUI is draggable (drag title bar)", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Stealth Configuration", o())
	createInfoLabel(tab, "Adjust cooldowns to balance stealth vs. effectiveness", o())
	createSlider(tab, "Silent Aim Cooldown (x0.1s)", 1, 20, math.floor(silentAimCooldown * 10), o(), function(val)
		silentAimCooldown = val / 10
	end)
	createSlider(tab, "Wallbang Cooldown (x0.1s)", 1, 20, math.floor(wallbangCooldown * 10), o(), function(val)
		wallbangCooldown = val / 10
	end)
	createSlider(tab, "Kill All Delay (x0.1s)", 1, 10, math.floor(killAllDelay * 10), o(), function(val)
		killAllDelay = val / 10
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Server Info", o())
	local placeLabel = Instance.new("TextLabel")
	placeLabel.Size = UDim2.new(1, 0, 0, 16)
	placeLabel.BackgroundTransparency = 1
	placeLabel.Text = "Place ID: " .. tostring(game.PlaceId)
	placeLabel.TextColor3 = COLORS.textSecondary
	placeLabel.Font = Enum.Font.Gotham
	placeLabel.TextSize = 10
	placeLabel.TextXAlignment = Enum.TextXAlignment.Left
	placeLabel.LayoutOrder = o()
	placeLabel.Parent = tab

	local jobLabel = Instance.new("TextLabel")
	jobLabel.Size = UDim2.new(1, 0, 0, 16)
	jobLabel.BackgroundTransparency = 1
	jobLabel.Text = "Server ID: " .. tostring(game.JobId):sub(1, 20) .. "..."
	jobLabel.TextColor3 = COLORS.textSecondary
	jobLabel.Font = Enum.Font.Gotham
	jobLabel.TextSize = 10
	jobLabel.TextXAlignment = Enum.TextXAlignment.Left
	jobLabel.LayoutOrder = o()
	jobLabel.Parent = tab

	local playerCountLabel = Instance.new("TextLabel")
	playerCountLabel.Size = UDim2.new(1, 0, 0, 16)
	playerCountLabel.BackgroundTransparency = 1
	playerCountLabel.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
	playerCountLabel.TextColor3 = COLORS.textSecondary
	playerCountLabel.Font = Enum.Font.Gotham
	playerCountLabel.TextSize = 10
	playerCountLabel.TextXAlignment = Enum.TextXAlignment.Left
	playerCountLabel.LayoutOrder = o()
	playerCountLabel.Parent = tab

	local localLabel = Instance.new("TextLabel")
	localLabel.Size = UDim2.new(1, 0, 0, 16)
	localLabel.BackgroundTransparency = 1
	localLabel.Text = "You: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")"
	localLabel.TextColor3 = COLORS.textSecondary
	localLabel.Font = Enum.Font.Gotham
	localLabel.TextSize = 10
	localLabel.TextXAlignment = Enum.TextXAlignment.Left
	localLabel.LayoutOrder = o()
	localLabel.Parent = tab

	-- Keep player count updated
	task.spawn(function()
		while task.wait(5) do
			pcall(function()
				playerCountLabel.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
			end)
		end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Server Actions", o())
	createButton(tab, "Rejoin Server", o(), function()
		notify("Rejoin", "Teleporting...")
		pcall(function()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end)
	end)
	createButton(tab, "Server Hop (Random Server)", o(), function()
		notify("Server Hop", "Finding new server...")
		task.spawn(function()
			pcall(function()
				local HttpService = game:GetService("HttpService")
				local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/0?sortOrder=2&excludeFullGames=true&limit=10"
				local data = HttpService:JSONDecode(game:HttpGet(url))
				if data and data.data then
					for _, server in ipairs(data.data) do
						if server.id ~= game.JobId and server.playing < server.maxPlayers then
							TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
							return
						end
					end
				end
				notify("Error", "No available servers found")
			end)
		end)
	end)
	createToggle(tab, "Auto-Rejoin on Kick", o(), function(on)
		autoRejoinActive = on
		if on then
			notify("Auto-Rejoin", "Will rejoin if kicked")
		end
	end)
	createInfoLabel(tab, "Auto-rejoin attempts to reconnect when kicked", o())

	-- Setup auto-rejoin hooks
	pcall(function()
		game:GetService("GuiService").ErrorMessageChanged:Connect(function(msg)
			if autoRejoinActive and msg ~= "" then
				task.wait(3)
				pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
			end
		end)
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "About", o())
	createInfoLabel(tab, "Synapse X The Revival - NBTF Hub v3.0", o())
	createInfoLabel(tab, "Uses WeaponsSystem.Network.WeaponHit for combat", o())
	createInfoLabel(tab, "Stealth mode with configurable cooldowns", o())
end

-- ===================== MINIMIZE / TOGGLE =====================
local contentVisible = true
minimizeBtn.MouseButton1Click:Connect(function()
	contentVisible = not contentVisible
	for _, frame in pairs(tabFrames) do frame.Visible = contentVisible and frame == tabFrames[activeTab] end
	tabBar.Visible = contentVisible
	mainFrame.Size = contentVisible and UDim2.new(0, 560, 0, 500) or UDim2.new(0, 560, 0, 32)
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
	if antiRagdollActive then stopAntiRagdoll() task.wait(0.3) startAntiRagdoll() end
	if infAmmoActive then modGuns() end
	if noRecoilActive then modGuns() end
end)

-- ===================== STARTUP =====================
notify("SX NBTF v3.0", "Loaded! Right Shift to toggle")
print("[SX NBTF v3.0] Synapse X The Revival - NBTF Hub v3.0")
print("[SX NBTF v3.0] Tabs: Aim | Combat | Movement | Visuals | Teleport | Players | Settings")
print("[SX NBTF v3.0] Uses WeaponsSystem.Network.WeaponHit for combat")
print("[SX NBTF v3.0] Stealth mode active - configurable cooldowns in Settings")
