-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate("nbtf") then return end

-- ================================================================
-- Pebbleford Hub - NBTF Hub v7.2
-- Nuclear Blast Testing Facility
-- Silent Aim | Wallbang | ESP | Aimbot | Fly | Teleports
-- Anti-Kick | Anti-Ragdoll | Weapon Selector | Player Actions
-- Stealth mode: cooldowns + delays to avoid detection
-- ================================================================

-- Cleanup old instance
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("PebblefordNBTF")
	if old then old:Destroy() end
end)
pcall(function()
	local old = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if old then
		local oldGui = old:FindFirstChild("PebblefordNBTF")
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
-- Roblox replaces workspace.CurrentCamera on respawn, which left this upvalue
-- pointing at a discarded camera: spectate, freecam and aimbot all wrote to
-- an object that was no longer rendering. Reassigning the upvalue fixes every
-- closure that captured it.
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if workspace.CurrentCamera then camera = workspace.CurrentCamera end
end)
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
-- AmmoCapacity and FullMagazineSize are deliberately excluded: inflating them
-- corrupted the ammo readout. The magazine is kept full by writing CurrentAmmo.
local NBTF_MAX_VALUES = {"AmmoReserves", "HitDamage", "MaxDistance"}

local helpers = {}
local actions = {}
local uiBuilder = {}

-- Forward-declare state tables referenced by the helpers below (assigned later)
local aimState
local combatState

-- Find any gun in the player's backpack (respects aimState.selectedWeapon if set)
function helpers.findGunInBackpack()
	-- If a specific weapon is selected, try to find it first
	if aimState.selectedWeapon then
		for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == aimState.selectedWeapon then return tool end
		end
		local char = LocalPlayer.Character
		if char then
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") and tool.Name == aimState.selectedWeapon then return tool end
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
function helpers.equipGun(gun)
	if not gun then return nil end
	local char = LocalPlayer.Character
	if not char then return nil end
	-- Already equipped
	if gun.Parent == char then return gun end
	-- Equip it from backpack
	pcall(function()
		char:FindFirstChildOfClass("Humanoid"):EquipTool(gun)
	end)
	task.wait(0.15)
	return gun
end

-- Sends a hit to the server's WeaponsSystem handler.
--
-- A live dump of this game settled what was wrong. Each shot carries an
-- incrementing id (weapon.nextShotId, observed at 20 on a fired MP5) and the
-- client always raises WeaponFired before WeaponHit. The previous payload
-- hard-coded sid = 2, so every hit referenced a shot the server had never
-- been told about and was discarded. Each burst now takes a real id from the
-- weapon object, announces it via WeaponFired, and only then reports the hit.
--
-- "h" is the Humanoid, not the Head part: the handler calls TakeDamage on it.
local cachedWS = nil
local function getWeaponsSystem()
	if cachedWS then return cachedWS end
	pcall(function()
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("WeaponsSystem")
		local mod = folder and folder:FindFirstChild("WeaponsSystem")
		if mod and mod:IsA("ModuleScript") then cachedWS = require(mod) end
	end)
	return cachedWS
end

local WeaponFiredRemote = nil
pcall(function()
	WeaponFiredRemote = game:GetService("ReplicatedStorage").WeaponsSystem.Network.WeaponFired
end)

-- mode controls how loud this is, because activating the tool is a real
-- trigger pull and snapping the camera is visible to the player:
--   "silent" (default) - remotes only. Never fires the gun or moves the
--                        camera. Used by passive helpers that run while the
--                        player is already shooting.
--   "fire"             - activates the tool but leaves the camera alone.
--   "aim"              - activates and points the camera at the target, so
--                        the game's own raycast resolves onto them.
-- ===================== AIM RAY REDIRECT =====================
-- This is what actually makes shots land on a chosen player, and it is the
-- mechanism every previous attempt was missing. The WeaponsSystem module
-- exposes aimRayCallback, which the kit calls to decide where a shot is
-- pointed. Overriding it redirects the bullet itself, so the game fires
-- normally and its own hit detection reports the target -- no forged payload
-- for the server to reject, and it passes through walls because the ray is
-- simply pointed at them.
--
-- The kit's exact signature is not published, so rather than guess, the
-- original callback is called first and whatever it returns is reshaped. If
-- it hands back a Ray, a Ray with the same origin and length is returned
-- pointing at the target; anything else is passed through untouched.
local aimRedirectTarget = nil
local aimRedirectInstalled = false

local function installAimRedirect()
	if aimRedirectInstalled then return end
	local ws = getWeaponsSystem()
	if type(ws) ~= "table" then return end
	local original = rawget(ws, "aimRayCallback")

	local ok = pcall(function()
		ws.aimRayCallback = function(...)
			local result
			if type(original) == "function" then
				local callOk, res = pcall(original, ...)
				if callOk then result = res end
			end
			if not aimRedirectTarget then return result end

			local char = aimRedirectTarget.Character
			local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
			if not head then return result end

			if typeof(result) == "Ray" then
				local origin = result.Origin
				local length = result.Direction.Magnitude
				if length <= 0 then length = 500 end
				local dir = head.Position - origin
				if dir.Magnitude <= 0 then return result end
				return Ray.new(origin, dir.Unit * length)
			end
			return result
		end
	end)
	aimRedirectInstalled = ok
end

local function fireWeaponHit(targetPlayer, gun, mode)
	mode = mode or "silent"
	if not WeaponHitRemote then
		pcall(function()
			WeaponHitRemote = game:GetService("ReplicatedStorage").WeaponsSystem.Network.WeaponHit
		end)
		if not WeaponHitRemote then return false end
	end

	local char = targetPlayer and targetPlayer.Character
	if not char then return false end
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then return false end

	if not gun then gun = helpers.findGunInBackpack() end
	if not gun then return false end
	helpers.equipGun(gun)

	-- The weapon object owns the shot counter the server expects.
	local weapon = nil
	local ws = getWeaponsSystem()
	if ws and type(ws.getWeaponForInstance) == "function" then
		local ok1, res = pcall(ws.getWeaponForInstance, gun)
		if not ok1 then ok1, res = pcall(ws.getWeaponForInstance, ws, gun) end
		if ok1 then weapon = res end
	end

	local myRoot = helpers.getRoot()
	local origin = (myRoot and myRoot.Position) or head.Position
	local maxDist = 9999
	pcall(function()
		local cfg = gun:FindFirstChild("Configuration")
		local md = cfg and cfg:FindFirstChild("MaxDistance")
		if md and tonumber(md.Value) and md.Value > 0 then maxDist = md.Value end
	end)
	local dist = (head.Position - origin).Magnitude
	if dist >= maxDist then dist = maxDist * 0.05 end

	local function nextShotId()
		-- Keep the weapon's own counter moving so ids stay unique and in step
		-- with what the game itself would send.
		if weapon and type(weapon.nextShotId) == "number" then
			local id = weapon.nextShotId
			weapon.nextShotId = id + 1
			return id
		end
		return math.random(1, 100000)
	end

	-- Fabricated hits are rejected no matter how the payload is shaped, so
	-- rather than forge one, drive the weapon's own firing path: aim at the
	-- target and activate the tool. The kit listens for the Tool's Activated
	-- event (the dump showed an "activated" connection on every weapon), then
	-- raises WeaponFired and WeaponHit itself with ids the server already
	-- trusts. The raw remotes are still sent afterwards as a cheap fallback.
	local function shoot()
		local shotId = nextShotId()
		local dir = head.Position - origin
		dir = dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, -1)

		-- Point at the target so the game's own raycast resolves onto them.
		if mode == "aim" then
			pcall(function()
				if camera then
					camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
				end
			end)
		end

		-- Let the game fire for real.
		local activated = false
		if mode == "aim" or mode == "fire" then
			-- Activate is the trigger going down, and it has to be released.
			-- Without the matching Deactivate an automatic weapon simply holds
			-- the trigger and never stops firing.
			activated = pcall(function() gun:Activate() end)
			pcall(function() gun:Deactivate() end)
		end

		if WeaponFiredRemote then
			pcall(function()
				WeaponFiredRemote:FireServer(gun, {
					origin = origin, dir = dir, id = shotId, t = tick(),
				})
			end)
		end

		local sent = pcall(function()
			WeaponHitRemote:FireServer(gun, {
				["p"] = head.Position,
				["pid"] = shotId,
				["part"] = head,
				["d"] = dist,
				["maxDist"] = maxDist,
				["h"] = humanoid,
				["m"] = Enum.Material.Plastic,
				["sid"] = shotId,
				["t"] = tick(),
				["n"] = (origin - head.Position).Unit,
			})
		end)
		return activated or sent
	end

	-- Aim every shot at this target for the duration of the burst, then clear
	-- it so the player's own aiming is handed straight back.
	installAimRedirect()
	aimRedirectTarget = targetPlayer

	-- HitDamage is only 6-9 on these weapons, so one hit never kills. Respect
	-- ShotCooldown: firing faster than the weapon allows is simply ignored.
	local cooldown = 0.12
	pcall(function()
		local cfg = gun:FindFirstChild("Configuration")
		local sc = cfg and cfg:FindFirstChild("ShotCooldown")
		if sc and tonumber(sc.Value) and sc.Value > 0 then cooldown = sc.Value end
	end)

	-- Passive helpers are called every frame already, so they fire a single
	-- shot per call; only a deliberate kill fires a burst, and that burst is
	-- bounded so it cannot turn into endless fire when a target will not die.
	local shots = (mode == "aim") and 10 or 1
	local ok = false
	for _ = 1, shots do
		if shoot() then ok = true end
		if humanoid.Health <= 0 then break end
		if shots > 1 then task.wait(cooldown) end
	end
	-- Release the trigger and hand aiming back to the player.
	pcall(function() gun:Deactivate() end)
	aimRedirectTarget = nil
	return ok
end

-- Click simulation fallback
function helpers.mouse1click()
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	task.wait(0.05)
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- ===================== COLOR PALETTE (Orange Theme) =====================
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
-- ===================== STATE (grouped to reduce local count) =====================
aimState = {
	silentAimActive = false,
	wallbangActive = false,
	aimbotActive = false,
	targetPart = "Head",
	fovRadius = 150,
	hitChance = 100,
	aimbotSmooth = 0.5,
	selectedWeapon = nil,
	silentAimConnection = nil,
	lastSilentAimFire = 0,
	silentAimCooldown = 0.4,
	wallbangConnection = nil,
	lastWallbangFire = 0,
	wallbangCooldown = 0.5,
	aimbotConnection = nil,
	aimbotAlwaysOn = false,
}

combatState = {
	killAuraActive = false,
	triggerBotActive = false,
	antiAimActive = false,
	autoFireActive = false,
	noRecoilActive = false,
	hitboxExpandActive = false,
	infAmmoActive = false,
	killAuraRange = 40,
	triggerBotDelay = 0.1,
	hitboxSize = 10,
	killAuraConnection = nil,
	triggerBotConnection = nil,
	antiAimConnection = nil,
	autoFireConnection = nil,
	noRecoilConnection = nil,
	hitboxConnection = nil,
	ammoConnection = nil,
	killAllDelay = 0.3,
}

local espState = {
	espActive = false,
	tracersActive = false,
	fovCircleActive = false,
	crosshairActive = false,
	itemEspActive = false,
	fullbrightActive = false,
	noFogActive = false,
	espHighlights = {},
	tracerLines = {},
	fovCircleDrawing = nil,
	crosshairDrawing = nil,
	crosshairLines = {},
	itemEspHighlights = {},
	savedLighting = {},
	xrayActive = false,
	xrayOrig = {},
	chamsActive = false,
	chamsHighlights = {},
	vehicleEspActive = false,
	vehicleEspHighlights = {},
	vehicleEspConnection = nil,
	chamsConnection = nil,
	savedFog = nil,
}

local moveState = {
	flyActive = false,
	noclipActive = false,
	speedBoostActive = false,
	infJumpActive = false,
	godModeActive = false,
	bunnyHopActive = false,
	longJumpActive = false,
	vehicleFlyActive = false,
	carSpeedActive = false,
	gravityActive = false,
	flySpeed = 80,
	vehicleFlySpeed = 250,
	speedValue = 50,
	carSpeedValue = 300,
	gravityValue = 196.2,
	longJumpPower = 150,
	flyConnection = nil,
	flyBV = nil,
	flyBG = nil,
	noclipConnection = nil,
	speedBV = nil,
	speedConnection = nil,
	godModeConnection = nil,
	godHealthConnection = nil,
	godRespawnConnection = nil,
	bunnyHopConnection = nil,
	vehicleFlyConnection = nil,
	vehicleFlyBV = nil,
	vehicleFlyBG = nil,
	carSpeedConnection = nil,
	carSpeedOrigMaxSpeed = nil,
	carSpeedOrigTorque = nil,
	carFlingActive = false,
	carFlingPower = 20000,
	carFlingLoopActive = false,
	carNoclipActive = false,
	noclipAntiSink = true,
	noclipFloor = {},
	carNoclipConnection = nil,
	carNoclipOrig = {},
	backseatDriveActive = false,
	backseatDriveConnection = nil,
	backseatBV = nil,
	backseatBG = nil,
	backseatDriveSpeed = 80,
	backseatDriveTurn = 3,
	walkFlingActive = false,
	walkFlingAutoNoclip = false,
	instantReloadConnection = nil,
}

local playerState = {
	spectateActive = false,
	spectateConnection = nil,
	spectateTarget = nil,
	orbitActive = false,
	orbitRadius = 15,
	orbitSpeed = 2,
	orbitTarget = nil,
	orbitConnection = nil,
	attachActive = false,
	attachTarget = nil,
	attachConnection = nil,
	tpToMouseActive = false,
	tpForwardDist = 50,
	freecamActive = false,
	freecamConnection = nil,
	freecamCF = nil,
	invisibleActive = false,
	bringAllActive = false,
	savedPositions = {},
}

local miscState = {
	antiAfkActive = false,
	antiKickActive = false,
	antiRagdollActive = false,
	autoRejoinActive = false,
	autoRespawnActive = false,
	chatSpyActive = false,
	joinNotifyActive = false,
	antiRagdollConnection = nil,
	chatSpyConnection = nil,
	autoInteractActive = false,
	autoInteractConnection = nil,
	autoInteractRange = 25,
	antiFlingActive = false,
	antiFlingConnection = nil,
	antiVoidActive = false,
	antiVoidConnection = nil,
	antiVoidHeight = -100,
	jumpPowerValue = 50,
	jumpPowerConnection = nil,
	joinNotifyConnections = {},
}

local uiState = {
	windowVisible = true,
	activeTab = "Aim",
}


-- New feature states



-- Connections / refs

-- ===================== HELPERS =====================
function helpers.getRoot()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

function helpers.getHumanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function helpers.notify(title, msg)
	-- Resolved at call time: Rayfield is created much further down the file,
	-- so this cannot capture it when the function is defined.
	if _G.SXNBTF_UI then
		local ok = pcall(function()
			_G.SXNBTF_UI:Notify({Title = title, Content = msg, Duration = 3})
		end)
		if ok then return end
	end
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = msg, Duration = 3})
	end)
end

function helpers.isEnemy(player)
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

function helpers.isAlive(player)
	if not player or not player.Character then return false end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

-- Detect if player is Facility (blue) or Rebel (red)
-- NBTF uses team names like "Facility", "Rebel", "Government", etc.
function helpers.getPlayerTeamInfo(player)
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

function helpers.getTargetPartFromPlayer(player)
	if not player.Character then return nil end
	local part = player.Character:FindFirstChild(aimState.targetPart)
	if not part then
		part = player.Character:FindFirstChild("HumanoidRootPart")
	end
	return part
end

-- ===================== FOV / TARGET SELECTION =====================
function helpers.getClosestPlayerInFOV()
	local closest = nil
	local closestDist = aimState.fovRadius
	local mousePos = UserInputService:GetMouseLocation()

	for _, player in ipairs(Players:GetPlayers()) do
		if helpers.isEnemy(player) and helpers.isAlive(player) then
			local part = helpers.getTargetPartFromPlayer(player)
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

function helpers.getClosestPlayer3D()
	local hrp = helpers.getRoot()
	if not hrp then return nil end
	local closest = nil
	local closestDist = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if helpers.isEnemy(player) and helpers.isAlive(player) then
			local part = helpers.getTargetPartFromPlayer(player)
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

function helpers.calculateChance(percentage)
	return math.random(1, 100) <= percentage
end

function helpers.getDirection(origin, targetPos)
	return (targetPos - origin).Unit * 1000
end

-- ===================== KILL AURA =====================
-- Auto-kills any enemy within range without aiming
local function startKillAura()
	combatState.killAuraConnection = RunService.Heartbeat:Connect(function()
		if not combatState.killAuraActive then return end
		pcall(function()
			local hrp = helpers.getRoot()
			if not hrp then return end
			local gun = helpers.findGunInBackpack()
			if not gun then return end
			helpers.equipGun(gun)

			for _, player in ipairs(Players:GetPlayers()) do
				if helpers.isEnemy(player) and helpers.isAlive(player) then
					local head = player.Character and player.Character:FindFirstChild("Head")
					if head and (head.Position - hrp.Position).Magnitude <= combatState.killAuraRange then
						fireWeaponHit(player, gun, "fire")
					end
				end
			end
		end)
	end)
end

local function stopKillAura()
	if combatState.killAuraConnection then combatState.killAuraConnection:Disconnect() combatState.killAuraConnection = nil end
end

-- ===================== TRIGGER BOT =====================
-- Auto-fires when crosshair is on an enemy
local function startTriggerBot()
	combatState.triggerBotConnection = RunService.Heartbeat:Connect(function()
		if not combatState.triggerBotActive then return end
		pcall(function()
			local mouse = LocalPlayer:GetMouse()
			local target = mouse.Target
			if not target then return end

			-- Check if mouse target belongs to an enemy
			local model = target:FindFirstAncestorOfClass("Model")
			if not model then return end
			local targetPlayer = Players:GetPlayerFromCharacter(model)
			if not targetPlayer or not helpers.isEnemy(targetPlayer) then return end

			local gun = helpers.findGunInBackpack()
			if gun then
				helpers.equipGun(gun)
				fireWeaponHit(targetPlayer, gun, "fire")
			end
		end)
		task.wait(combatState.triggerBotDelay)
	end)
end

local function stopTriggerBot()
	if combatState.triggerBotConnection then combatState.triggerBotConnection:Disconnect() combatState.triggerBotConnection = nil end
end

-- ===================== ANTI-AIM =====================
-- Spins character rapidly to make it harder to hit
local function startAntiAim()
	combatState.antiAimConnection = RunService.Heartbeat:Connect(function()
		if not combatState.antiAimActive then return end
		pcall(function()
			local hrp = helpers.getRoot()
			if hrp then
				hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(30), 0)
			end
		end)
	end)
end

local function stopAntiAim()
	if combatState.antiAimConnection then combatState.antiAimConnection:Disconnect() combatState.antiAimConnection = nil end
end

-- ===================== BUNNY HOP =====================
-- Auto-jumps while moving for speed
local function startBunnyHop()
	moveState.bunnyHopConnection = RunService.Heartbeat:Connect(function()
		if not moveState.bunnyHopActive then return end
		pcall(function()
			local hum = helpers.getHumanoid()
			if hum and hum.MoveDirection.Magnitude > 0 then
				if hum.FloorMaterial ~= Enum.Material.Air then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end)
	end)
end

local function stopBunnyHop()
	if moveState.bunnyHopConnection then moveState.bunnyHopConnection:Disconnect() moveState.bunnyHopConnection = nil end
end

-- ===================== LONG JUMP =====================
function actions.doLongJump()
	pcall(function()
		local hrp = helpers.getRoot()
		local hum = helpers.getHumanoid()
		if not hrp or not hum then return end
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		task.wait(0.1)
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Velocity = hrp.CFrame.LookVector * moveState.longJumpPower + Vector3.new(0, moveState.longJumpPower * 0.3, 0)
		bv.P = 9000
		bv.Parent = hrp
		task.delay(0.3, function() pcall(function() bv:Destroy() end) end)
	end)
end

-- ===================== TP FORWARD =====================
function actions.tpForward()
	pcall(function()
		local hrp = helpers.getRoot()
		local char = LocalPlayer.Character
		if hrp and char then
			char:PivotTo(hrp.CFrame + hrp.CFrame.LookVector * playerState.tpForwardDist)
			helpers.notify("TP", "Teleported " .. playerState.tpForwardDist .. " studs forward")
		end
	end)
end

-- ===================== TP TO MOUSE =====================
function actions.tpToMouse()
	pcall(function()
		local mouse = LocalPlayer:GetMouse()
		local char = LocalPlayer.Character
		if char and mouse.Hit then
			char:PivotTo(mouse.Hit + Vector3.new(0, 3, 0))
		end
	end)
end

-- ===================== SAVE / LOAD POSITION =====================
function actions.savePosition(name)
	local hrp = helpers.getRoot()
	if hrp then
		playerState.savedPositions[name] = hrp.CFrame
		helpers.notify("Saved", "Position '" .. name .. "' saved!")
	end
end

function actions.loadPosition(name)
	local cf = playerState.savedPositions[name]
	if cf then
		local char = LocalPlayer.Character
		if char then
			char:PivotTo(cf)
			helpers.notify("Loaded", "Teleported to '" .. name .. "'")
		end
	else
		helpers.notify("Error", "No saved position '" .. name .. "'")
	end
end

-- ===================== INVISIBLE MODE =====================
local function startInvisible()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 1
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 1
			end
		end
		local face = char:FindFirstChild("Head") and char.Head:FindFirstChildOfClass("Decal")
		if face then face.Transparency = 1 end
		helpers.notify("Invisible", "You are now invisible (client-side)")
	end)
end

local function stopInvisible()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 0
			end
		end
		helpers.notify("Invisible", "Visibility restored")
	end)
end

-- ===================== TRACERS =====================
local function clearTracers()
	for _, line in pairs(espState.tracerLines) do pcall(function() line:Remove() end) end
	espState.tracerLines = {}
end

local function updateTracers()
	clearTracers()
	if not espState.tracersActive then return end
	pcall(function()
		if not Drawing then return end -- Drawing API required
		local hrp = helpers.getRoot()
		for _, player in ipairs(Players:GetPlayers()) do
			if helpers.isEnemy(player) and helpers.isAlive(player) then
				local pHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if pHRP then
					local screenPos, onScreen = camera:WorldToViewportPoint(pHRP.Position)
					if onScreen then
						local line = Drawing.new("Line")
						line.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
						line.To = Vector2.new(screenPos.X, screenPos.Y)
						line.Color = Color3.fromRGB(255, 165, 0)
						line.Thickness = 1.5
						line.Transparency = 1
						line.Visible = true
						table.insert(espState.tracerLines, line)
					end
				end
			end
		end
	end)
end

local function startTracers()
	task.spawn(function()
		while espState.tracersActive do updateTracers() task.wait(0.05) end
		clearTracers()
	end)
end

-- ===================== FOV CIRCLE =====================
local function createFOVCircle()
	pcall(function()
		if not Drawing then return end
		if espState.fovCircleDrawing then espState.fovCircleDrawing:Remove() end
		espState.fovCircleDrawing = Drawing.new("Circle")
		espState.fovCircleDrawing.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
		espState.fovCircleDrawing.Radius = aimState.fovRadius
		espState.fovCircleDrawing.Color = Color3.fromRGB(255, 165, 0)
		espState.fovCircleDrawing.Thickness = 1.5
		espState.fovCircleDrawing.Filled = false
		espState.fovCircleDrawing.Transparency = 0.7
		espState.fovCircleDrawing.Visible = true
	end)
end

local function updateFOVCircle()
	pcall(function()
		if espState.fovCircleDrawing then
			espState.fovCircleDrawing.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
			espState.fovCircleDrawing.Radius = aimState.fovRadius
			espState.fovCircleDrawing.Visible = espState.fovCircleActive
		end
	end)
end

local function removeFOVCircle()
	pcall(function() if espState.fovCircleDrawing then espState.fovCircleDrawing:Remove() espState.fovCircleDrawing = nil end end)
end

-- ===================== CROSSHAIR =====================

local function createCrosshair()
	pcall(function()
		if not Drawing then return end
		for _, l in pairs(espState.crosshairLines) do pcall(function() l:Remove() end) end
		espState.crosshairLines = {}
		local cx = camera.ViewportSize.X / 2
		local cy = camera.ViewportSize.Y / 2
		local gap = 4
		local size = 12
		local color = Color3.fromRGB(0, 255, 0)

		for _, offset in ipairs({
			{Vector2.new(cx - size, cy), Vector2.new(cx - gap, cy)},   -- left
			{Vector2.new(cx + gap, cy), Vector2.new(cx + size, cy)},   -- right
			{Vector2.new(cx, cy - size), Vector2.new(cx, cy - gap)},   -- top
			{Vector2.new(cx, cy + gap), Vector2.new(cx, cy + size)},   -- bottom
		}) do
			local line = Drawing.new("Line")
			line.From = offset[1]
			line.To = offset[2]
			line.Color = color
			line.Thickness = 2
			line.Visible = true
			table.insert(espState.crosshairLines, line)
		end
	end)
end

local function removeCrosshair()
	for _, l in pairs(espState.crosshairLines) do pcall(function() l:Remove() end) end
	espState.crosshairLines = {}
end

-- ===================== ITEM ESP =====================
local function clearItemESP()
	for _, h in pairs(espState.itemEspHighlights) do pcall(function() h:Destroy() end) end
	espState.itemEspHighlights = {}
end

local function updateItemESP()
	clearItemESP()
	if not espState.itemEspActive then return end
	pcall(function()
		-- Search workspace for dropped tools/weapons
		for _, obj in ipairs(workspace:GetChildren()) do
			pcall(function()
				local isTool = obj:IsA("Tool") or (obj:IsA("Model") and obj:FindFirstChildOfClass("Tool"))
				local isWeapon = false
				if not isTool then
					local name = obj.Name:lower()
					isWeapon = name:find("gun") or name:find("weapon") or name:find("rifle") or
						name:find("pistol") or name:find("sword") or name:find("knife") or
						name:find("ammo") or name:find("crate") or name:find("pickup")
				end
				if (isTool or isWeapon) and not Players:GetPlayerFromCharacter(obj) then
					local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
					if part then
						local hl = Instance.new("Highlight")
						hl.Name = "ItemESP"
						hl.FillColor = Color3.fromRGB(0, 255, 128)
						hl.FillTransparency = 0.5
						hl.OutlineColor = Color3.fromRGB(255, 255, 255)
						hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						hl.Parent = obj
						table.insert(espState.itemEspHighlights, hl)

						local bb = Instance.new("BillboardGui")
						bb.Name = "ItemESP_BB"
						bb.AlwaysOnTop = true
						bb.Size = UDim2.new(3, 0, 0.5, 0)
						bb.StudsOffset = Vector3.new(0, 2, 0)
						bb.Adornee = part
						bb.Parent = obj
						table.insert(espState.itemEspHighlights, bb)

						local lbl = Instance.new("TextLabel")
						lbl.Text = obj.Name
						lbl.TextColor3 = Color3.fromRGB(0, 255, 128)
						lbl.TextStrokeTransparency = 0
						lbl.TextSize = 11
						lbl.Font = Enum.Font.GothamBold
						lbl.BackgroundTransparency = 1
						lbl.Size = UDim2.new(1, 0, 1, 0)
						lbl.Parent = bb
					end
				end
			end)
		end
	end)
end

local function startItemESP()
	task.spawn(function()
		while espState.itemEspActive do updateItemESP() task.wait(3) end
		clearItemESP()
	end)
end

-- ===================== CHAT SPY =====================
local function startChatSpy()
	miscState.chatSpyActive = true
	pcall(function()
		local TextChatService = game:GetService("TextChatService")
		if TextChatService then
			miscState.chatSpyConnection = TextChatService.MessageReceived:Connect(function(message)
				if not miscState.chatSpyActive then return end
				pcall(function()
					local sender = message.TextSource
					if sender then
						local player = Players:GetPlayerByUserId(sender.UserId)
						local name = player and player.DisplayName or "Unknown"
						if player ~= LocalPlayer then
							print("[CHAT SPY] " .. name .. ": " .. message.Text)
						end
					end
				end)
			end)
		end
	end)
	helpers.notify("Chat Spy", "Logging all chat to F9")
end

local function stopChatSpy()
	miscState.chatSpyActive = false
	if miscState.chatSpyConnection then pcall(function() miscState.chatSpyConnection:Disconnect() end) miscState.chatSpyConnection = nil end
end

-- ===================== PLAYER JOIN/LEAVE NOTIFICATIONS =====================
local function startJoinNotify()
	miscState.joinNotifyActive = true
	local joinConn = Players.PlayerAdded:Connect(function(player)
		if miscState.joinNotifyActive then
			helpers.notify("Joined", player.DisplayName .. " (@" .. player.Name .. ") joined")
			print("[JOIN] " .. player.DisplayName .. " (@" .. player.Name .. ") joined the server")
		end
	end)
	local leaveConn = Players.PlayerRemoving:Connect(function(player)
		if miscState.joinNotifyActive then
			helpers.notify("Left", player.DisplayName .. " left the server")
			print("[LEAVE] " .. player.DisplayName .. " (@" .. player.Name .. ") left the server")
		end
	end)
	table.insert(miscState.joinNotifyConnections, joinConn)
	table.insert(miscState.joinNotifyConnections, leaveConn)
end

local function stopJoinNotify()
	miscState.joinNotifyActive = false
	for _, conn in ipairs(miscState.joinNotifyConnections) do pcall(function() conn:Disconnect() end) end
	miscState.joinNotifyConnections = {}
end

-- ===================== AUTO RESPAWN =====================
local function setupAutoRespawn()
	LocalPlayer.CharacterAdded:Connect(function(char)
		if not miscState.autoRespawnActive then return end
		char:WaitForChild("Humanoid").Died:Connect(function()
			if miscState.autoRespawnActive then
				task.wait(1)
				pcall(function()
					-- Try to click respawn button
					local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
					if playerGui then
						for _, gui in ipairs(playerGui:GetDescendants()) do
							pcall(function()
								if (gui:IsA("TextButton") or gui:IsA("ImageButton")) then
									local txt = gui.Text and gui.Text:lower() or ""
									if txt:find("respawn") or txt:find("deploy") or txt:find("spawn") then
										if firesignal then pcall(firesignal, gui.MouseButton1Click) end
									end
								end
							end)
						end
					end
					-- Fallback: just load character
					task.wait(2)
					pcall(function() LocalPlayer:LoadCharacter() end)
				end)
			end
		end)
	end)
end

-- ===================== ORBIT PLAYER =====================
local function startOrbit(targetPlayer)
	playerState.orbitTarget = targetPlayer
	playerState.orbitActive = true
	local angle = 0
	playerState.orbitConnection = RunService.Heartbeat:Connect(function()
		if not playerState.orbitActive or not playerState.orbitTarget then return end
		pcall(function()
			local theirHRP = playerState.orbitTarget.Character and playerState.orbitTarget.Character:FindFirstChild("HumanoidRootPart")
			local char = LocalPlayer.Character
			if not theirHRP or not char then return end
			angle = angle + playerState.orbitSpeed * 0.03
			local offset = Vector3.new(math.cos(angle) * playerState.orbitRadius, 0, math.sin(angle) * playerState.orbitRadius)
			char:PivotTo(CFrame.new(theirHRP.Position + offset, theirHRP.Position))
		end)
	end)
end

local function stopOrbit()
	playerState.orbitActive = false
	playerState.orbitTarget = nil
	if playerState.orbitConnection then playerState.orbitConnection:Disconnect() playerState.orbitConnection = nil end
end

-- ===================== ATTACH TO PLAYER =====================
local function startAttach(targetPlayer)
	playerState.attachTarget = targetPlayer
	playerState.attachActive = true
	playerState.attachConnection = RunService.Heartbeat:Connect(function()
		if not playerState.attachActive or not playerState.attachTarget then return end
		pcall(function()
			local theirHRP = playerState.attachTarget.Character and playerState.attachTarget.Character:FindFirstChild("HumanoidRootPart")
			local char = LocalPlayer.Character
			if not theirHRP or not char then return end
			char:PivotTo(theirHRP.CFrame * CFrame.new(0, 0, -5))
		end)
	end)
end

local function stopAttach()
	playerState.attachActive = false
	playerState.attachTarget = nil
	if playerState.attachConnection then playerState.attachConnection:Disconnect() playerState.attachConnection = nil end
end

-- ===================== FREECAM =====================
local function startFreecam()
	playerState.freecamActive = true
	local hrp = helpers.getRoot()
	playerState.freecamCF = hrp and hrp.CFrame or camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable

	playerState.freecamConnection = RunService.RenderStepped:Connect(function()
		if not playerState.freecamActive then return end
		pcall(function()
			local speed = moveState.flySpeed * 0.5
			local moveVec = Vector3.zero
			local camCF = camera.CFrame
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - Vector3.new(0, 1, 0) end
			if moveVec.Magnitude > 0 then
				playerState.freecamCF = CFrame.new(playerState.freecamCF.Position + moveVec.Unit * speed * 0.016) * (camCF - camCF.Position)
			end
			camera.CFrame = playerState.freecamCF
		end)
	end)
end

local function stopFreecam()
	playerState.freecamActive = false
	if playerState.freecamConnection then playerState.freecamConnection:Disconnect() playerState.freecamConnection = nil end
	pcall(function() camera.CameraType = Enum.CameraType.Custom end)
end

-- ===================== NO FOG =====================
local function enableNoFog()
	pcall(function()
		local Lighting = game:GetService("Lighting")
		espState.savedFog = {FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor}
		Lighting.FogEnd = 9999999
		Lighting.FogStart = 9999999
	end)
end

local function disableNoFog()
	pcall(function()
		if espState.savedFog then
			local Lighting = game:GetService("Lighting")
			Lighting.FogEnd = espState.savedFog.FogEnd
			Lighting.FogStart = espState.savedFog.FogStart
			Lighting.FogColor = espState.savedFog.FogColor
		end
	end)
end

-- Holds the redirect on a target while a passive feature is engaged, so the
-- player's own shots are the ones being steered.
local function setAimRedirect(player)
	installAimRedirect()
	aimRedirectTarget = player
end

-- ===================== SILENT AIM =====================
-- Hooks workspace raycast methods to redirect bullets to target
-- This is the core "teleport bullets" / "shoot through walls" mechanic
-- Requires executor with hookmetamethod support

-- Silent aim connection + cooldown for stealth

local function enableSilentAim()
	aimState.silentAimActive = true

	if not WeaponHitRemote then
		helpers.notify("Silent Aim", "WeaponHit remote not found! Waiting for game to load...")
		pcall(function()
			WeaponHitRemote = game:GetService("ReplicatedStorage").WeaponsSystem.Network.WeaponHit
		end)
		if not WeaponHitRemote then
			helpers.notify("Error", "Could not find WeaponsSystem.Network.WeaponHit")
			return
		end
	end

	-- Stealth silent aim: only fires ONE extra WeaponHit per cooldown period
	-- Looks like a normal shot that just happens to hit the head
	installAimRedirect()
	aimState.silentAimConnection = RunService.Heartbeat:Connect(function()
		if not aimState.silentAimActive then return end
		pcall(function()
			-- Keep the aim ray locked on the nearest enemy the whole time the
			-- feature is on, so the player's own shots are what gets steered.
			local lockTarget = helpers.getClosestPlayerInFOV() or helpers.getClosestPlayer3D()
			if lockTarget then
				local lockPlayer = Players:GetPlayerFromCharacter(lockTarget.Parent)
				if lockPlayer and helpers.isEnemy(lockPlayer) then
					setAimRedirect(lockPlayer)
				end
			end

			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end

			-- Cooldown to avoid spam detection
			local now = tick()
			if now - aimState.lastSilentAimFire < aimState.silentAimCooldown then return end

			local char = LocalPlayer.Character
			if not char then return end
			-- Only fire if we have a tool equipped (we're actually shooting)
			local equippedGun = char:FindFirstChildOfClass("Tool")
			if not equippedGun then return end

			local target = helpers.getClosestPlayerInFOV()
			if not target then target = helpers.getClosestPlayer3D() end
			if not target or not target.Parent then return end

			local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
			if not targetPlayer then return end
			if not helpers.calculateChance(aimState.hitChance) then return end

			fireWeaponHit(targetPlayer, equippedGun, "silent")
			aimState.lastSilentAimFire = now
		end)
	end)

	helpers.notify("Silent Aim", "Active (stealth mode - " .. aimState.silentAimCooldown .. "s cooldown)")
end

local function disableSilentAim()
	aimRedirectTarget = nil
	aimState.silentAimActive = false
	if aimState.silentAimConnection then aimState.silentAimConnection:Disconnect() aimState.silentAimConnection = nil end
	helpers.notify("Silent Aim", "Disabled")
end

-- ===================== WALLBANG (Stealth - single target through walls) =====================
-- Only fires at ONE closest enemy with cooldown - not all enemies every frame

local function enableWallbang()
	aimState.wallbangActive = true
	aimState.wallbangConnection = RunService.Heartbeat:Connect(function()
		if not aimState.wallbangActive then return end
		pcall(function()
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end

			local now = tick()
			if now - aimState.lastWallbangFire < aimState.wallbangCooldown then return end

			local char = LocalPlayer.Character
			if not char then return end
			local equippedGun = char:FindFirstChildOfClass("Tool")
			if not equippedGun then return end

			-- Only target the CLOSEST enemy, not all of them
			local target = helpers.getClosestPlayer3D()
			if not target or not target.Parent then return end
			local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
			if not targetPlayer then return end

			-- Redirect first: the shot the player is already taking is the one
			-- that should land, which is what makes this work through walls.
			setAimRedirect(targetPlayer)
			fireWeaponHit(targetPlayer, equippedGun, "silent")
			aimState.lastWallbangFire = now
		end)
	end)
	helpers.notify("Wallbang", "Active (stealth - hits closest enemy through walls)")
end

local function disableWallbang()
	aimRedirectTarget = nil
	aimState.wallbangActive = false
	if aimState.wallbangConnection then aimState.wallbangConnection:Disconnect() aimState.wallbangConnection = nil end
	helpers.notify("Wallbang", "Disabled")
end

-- ===================== AIMBOT (Camera Lock) =====================
-- Locks camera to nearest enemy when holding right-click OR always-on mode

local function startAimbot()
	aimState.aimbotConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not aimState.aimbotActive then return end
			-- Work in both modes: always-on or hold right-click
			if not aimState.aimbotAlwaysOn and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

			local target = helpers.getClosestPlayerInFOV()
			if not target then
				-- Fallback: try 3D closest if FOV finds nothing
				target = helpers.getClosestPlayer3D()
			end
			if target then
				local camPos = camera.CFrame.Position
				local targetCF = CFrame.new(camPos, target.Position)
				-- Direct snap for low smoothness, lerp for high
				if aimState.aimbotSmooth >= 0.9 then
					camera.CFrame = targetCF
				else
					camera.CFrame = camera.CFrame:Lerp(targetCF, aimState.aimbotSmooth)
				end
			end
		end)
	end)
	helpers.notify("Aimbot", "Active! Right-click to lock on")
end

local function stopAimbot()
	if aimState.aimbotConnection then aimState.aimbotConnection:Disconnect() aimState.aimbotConnection = nil end
end

-- ===================== ESP =====================
local function clearESP()
	for _, obj in pairs(espState.espHighlights) do pcall(function() obj:Destroy() end) end
	espState.espHighlights = {}
end

local function updateESP()
	clearESP()
	if not espState.espActive then return end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and helpers.isAlive(player) then
			pcall(function()
				local char = player.Character
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum then return end

				-- Get team color: Facility = blue, Rebel = red
				local color, roleName, teamName = helpers.getPlayerTeamInfo(player)

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
					table.insert(espState.espHighlights, hl)
				end

				-- Name + Role + Health + Distance billboard
				local myRoot = helpers.getRoot()
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
					table.insert(espState.espHighlights, bb)

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
					table.insert(espState.espHighlights, barBg)

					local barFill = Instance.new("Frame")
					barFill.Size = UDim2.new(hum.Health / hum.MaxHealth, 0, 1, 0)
					barFill.BackgroundColor3 = hum.Health > hum.MaxHealth * 0.5 and COLORS.success or COLORS.error
					barFill.BorderSizePixel = 0
					barFill.Parent = barBg
					table.insert(espState.espHighlights, barFill)

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
		while espState.espActive do updateESP() task.wait(1.5) end
	end)
	helpers.notify("ESP", "Player ESP active!")
end

-- ===================== UNLIMITED AMMO (NBTF-Specific) =====================
-- NBTF weapons store ammo in tool.Configuration (AmmoCapacity, AmmoReserves, etc.)
function actions.modGuns()
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

-- Ammo in this game lives in two loose IntValues parented directly to the
-- Tool -- CurrentAmmo (the magazine) and AmmoReserves -- not in Configuration
-- and not in any Lua weapon table. Confirmed by dumping a live session:
--   XM1014.CurrentAmmo = 5,  AmmoReserves = 999,  Configuration.AmmoCapacity = 5
--   MP5.CurrentAmmo    = 30, AmmoReserves = 999,  Configuration.AmmoCapacity = 30
--
-- CurrentAmmo is topped back up to the weapon's real AmmoCapacity rather than
-- to a huge number: AmmoCapacity is only 5 on the shotgun, and inflating it is
-- what made the HUD read zero while a reload restored the true count.
local function refillToolAmmo(tool)
	if not tool or not tool:IsA("Tool") then return 0 end
	local wrote = 0
	local current = tool:FindFirstChild("CurrentAmmo")
	local reserves = tool:FindFirstChild("AmmoReserves")
	local config = tool:FindFirstChild("Configuration")
	local capacity = config and config:FindFirstChild("AmmoCapacity")

	if current and capacity and current.Value < capacity.Value then
		pcall(function() current.Value = capacity.Value end)
		wrote = wrote + 1
	end
	if reserves and reserves.Value < 999 then
		pcall(function() reserves.Value = 999 end)
		wrote = wrote + 1
	end
	return wrote
end

-- Refilling the magazine mid-reload can leave the kit's reload half finished,
-- so "reloading" never clears and the weapon quietly refuses to fire. That is
-- the intermittent stall: the ammo count is fine, the weapon is just wedged.
-- These flags are cleared on our own weapons every pass so it cannot stick.
--
-- knownWeapons holds every player's weapons, so it MUST be filtered by owner;
-- without that this would be writing into other people's weapon state.
local function unstickMyWeapons()
	local ws = getWeaponsSystem()
	if type(ws) ~= "table" then return end
	local known = rawget(ws, "knownWeapons")
	if type(known) ~= "table" then return end
	for _, weapon in pairs(known) do
		if type(weapon) == "table" and rawget(weapon, "player") == LocalPlayer then
			pcall(function()
				if weapon.reloading then weapon.reloading = false end
				-- A fire time left in the future locks the weapon out entirely.
				if type(weapon.nextFireTime) == "number" and weapon.nextFireTime > tick() then
					weapon.nextFireTime = 0
				end
				if weapon.triggerDisconnected then weapon.triggerDisconnected = false end
				if weapon.burstFiring then weapon.burstFiring = false end
			end)
		end
	end
end

local function refillAllAmmo()
	local wrote = 0
	pcall(function()
		local char = LocalPlayer.Character
		if char then
			for _, tool in ipairs(char:GetChildren()) do wrote = wrote + refillToolAmmo(tool) end
		end
		if LocalPlayer:FindFirstChild("Backpack") then
			for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
				wrote = wrote + refillToolAmmo(tool)
			end
		end
	end)
	return wrote
end

local function startInfAmmo()
	-- Damage and range still come from Configuration, which is read per shot.
	actions.modGuns()
	refillAllAmmo()

	combatState.ammoConnection = RunService.Heartbeat:Connect(function()
		refillAllAmmo()
		unstickMyWeapons()
	end)

	helpers.notify("Ammo", "Unlimited ammo active")
end

local function stopInfAmmo()
	if combatState.ammoConnection then combatState.ammoConnection:Disconnect() combatState.ammoConnection = nil end
end

-- ===================== HITBOX EXPANDER =====================
local function startHitboxExpand()
	combatState.hitboxConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and helpers.isAlive(player) then
					local hrp = player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						hrp.Size = Vector3.new(combatState.hitboxSize, combatState.hitboxSize, combatState.hitboxSize)
						hrp.Transparency = 0.7
					end
				end
			end
		end)
	end)
	helpers.notify("Hitbox", "Enemy hitboxes expanded!")
end

local function stopHitboxExpand()
	if combatState.hitboxConnection then combatState.hitboxConnection:Disconnect() combatState.hitboxConnection = nil end
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
-- Healing only on Heartbeat leaves a whole frame between the hit landing and
-- the heal, which is long enough to die outright from a large hit. HealthChanged
-- fires the moment damage is applied, so the restore happens before the death
-- can process; the Heartbeat loop stays on as a backstop.
--
-- MaxHealth is raised too. Restoring to MaxHealth alone leaves you on whatever
-- the game set as the cap, so a single shot bigger than that cap still kills.
local function applyGodMode(hum)
	if not hum then return end
	pcall(function()
		hum.MaxHealth = math.huge
		hum.Health = math.huge
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end)
end

local function hookGodMode(hum)
	if not hum then return end
	applyGodMode(hum)
	if moveState.godHealthConnection then
		moveState.godHealthConnection:Disconnect()
	end
	moveState.godHealthConnection = hum.HealthChanged:Connect(function()
		if moveState.godModeActive then applyGodMode(hum) end
	end)
end

local function startGodMode()
	hookGodMode(helpers.getHumanoid())

	-- The Humanoid is a new instance after every respawn, so the old hook dies
	-- with the old character and has to be re-established.
	if moveState.godRespawnConnection then
		moveState.godRespawnConnection:Disconnect()
	end
	moveState.godRespawnConnection = LocalPlayer.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if hum and moveState.godModeActive then hookGodMode(hum) end
	end)

	moveState.godModeConnection = RunService.Heartbeat:Connect(function()
		applyGodMode(helpers.getHumanoid())
	end)
	helpers.notify("God Mode", "Invincible!")
end

local function stopGodMode()
	if moveState.godModeConnection then moveState.godModeConnection:Disconnect() moveState.godModeConnection = nil end
	if moveState.godHealthConnection then moveState.godHealthConnection:Disconnect() moveState.godHealthConnection = nil end
	if moveState.godRespawnConnection then moveState.godRespawnConnection:Disconnect() moveState.godRespawnConnection = nil end
	pcall(function()
		local hum = helpers.getHumanoid()
		if hum then
			-- math.huge MaxHealth would otherwise persist after switching off.
			hum.MaxHealth = 100
			hum.Health = 100
			hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		end
	end)
end

-- ===================== FLY =====================
-- ===================== FLY TOUCH PAD (shared) =====================
-- Both fly modes were keyboard-only, so on a phone moveVec stayed zero and
-- nothing moved. Horizontal input differs per mode (Humanoid.MoveDirection
-- when on foot, the VehicleSeat's Throttle/Steer when driving) but neither
-- has a touch equivalent for up/down, so this pad supplies it for both.
-- Ref-counted by tag so turning one mode off does not remove the other's pad.
local flyPadGui = nil
local flyPadUsers = {}
local flyUp, flyDown = false, false

local function destroyFlyPad(tag)
	flyPadUsers[tag] = nil
	if next(flyPadUsers) then return end
	if flyPadGui then pcall(function() flyPadGui:Destroy() end) end
	flyPadGui = nil
	flyUp, flyDown = false, false
end

local function createFlyPad(tag)
	flyPadUsers[tag] = true
	if not UserInputService.TouchEnabled then return end
	if flyPadGui then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "NBTF_FlyPad"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	pcall(function() gui.Parent = game:GetService("CoreGui") end)
	if not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	flyPadGui = gui

	local function makeBtn(label, yOffset, onDown, onUp)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 64, 0, 64)
		b.Position = UDim2.new(1, -80, 1, yOffset)
		b.AnchorPoint = Vector2.new(0, 0)
		b.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		b.BackgroundTransparency = 0.25
		b.Text = label
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextSize = 26
		b.Font = Enum.Font.GothamBold
		b.BorderSizePixel = 0
		b.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 12)
		c.Parent = b
		b.MouseButton1Down:Connect(onDown)
		b.MouseButton1Up:Connect(onUp)
		-- Releasing outside the button must still stop the thrust.
		b.MouseLeave:Connect(onUp)
		return b
	end

	makeBtn("^", -150, function() flyUp = true end, function() flyUp = false end)
	makeBtn("v", -78, function() flyDown = true end, function() flyDown = false end)
end

local function startFly()
	local hrp = helpers.getRoot()
	if not hrp then return end

	moveState.flyBV = Instance.new("BodyVelocity")
	moveState.flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	moveState.flyBV.Velocity = Vector3.new(0, 0, 0)
	moveState.flyBV.P = 9000
	moveState.flyBV.Parent = hrp

	moveState.flyBG = Instance.new("BodyGyro")
	moveState.flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	moveState.flyBG.P = 9000
	moveState.flyBG.CFrame = hrp.CFrame
	moveState.flyBG.Parent = hrp

	moveState.flyConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not moveState.flyBV or not moveState.flyBV.Parent then return end
			local moveVec = Vector3.zero
			local camCF = camera.CFrame
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + camCF.UpVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - camCF.UpVector end

			-- Touch input. On foot the humanoid is not seated, so MoveDirection
			-- tracks the mobile thumbstick; it is already world-space, so it is
			-- flattened against the camera rather than added to a key vector.
			local ch = LocalPlayer.Character
			local hm = ch and ch:FindFirstChildOfClass("Humanoid")
			if hm and hm.MoveDirection.Magnitude > 0 then
				local md = hm.MoveDirection
				moveVec = moveVec + Vector3.new(md.X, 0, md.Z)
			end
			if flyUp then moveVec = moveVec + camCF.UpVector end
			if flyDown then moveVec = moveVec - camCF.UpVector end

			moveState.flyBV.Velocity = moveVec.Magnitude > 0 and moveVec.Unit * moveState.flySpeed or Vector3.zero
			moveState.flyBG.CFrame = camCF
		end)
	end)
	createFlyPad("character")
	if UserInputService.TouchEnabled then
		helpers.notify("Fly", "Flying! Thumbstick + on-screen up/down")
	else
		helpers.notify("Fly", "Flying! WASD + Space/Shift")
	end
end

local function stopFly()
	if moveState.flyConnection then moveState.flyConnection:Disconnect() moveState.flyConnection = nil end
	if moveState.flyBV then pcall(function() moveState.flyBV:Destroy() end) moveState.flyBV = nil end
	if moveState.flyBG then pcall(function() moveState.flyBG:Destroy() end) moveState.flyBG = nil end
	destroyFlyPad("character")
end

-- ===================== NOCLIP =====================
-- Anti-sink, shared by character and vehicle noclip.
--
-- Turning collision off removes the ground as well as the walls, so gravity
-- drags you straight through the map: that is the sinking, not a bug in the
-- collision code. Downward velocity is cancelled and a floor height is kept,
-- so you hold your level while still passing through walls. The floor rises
-- with you, so flying or jumping upward still works; you simply will not
-- drift below where you already are. Switch noclip off to land normally.
local function holdAltitude(part, key)
	if not part or not part.Parent then return end
	local v = part.AssemblyLinearVelocity
	if v.Y < 0 then
		part.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
	end
	local y = part.Position.Y
	local floor = moveState.noclipFloor[key]
	if floor == nil or y > floor then
		moveState.noclipFloor[key] = y
	elseif y < floor - 0.75 then
		-- Slipped through something: lift straight back to the held level.
		part.CFrame = part.CFrame + Vector3.new(0, floor - y, 0)
		part.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
	end
end

local function startNoclip()
	moveState.noclipFloor.character = nil
	moveState.noclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
			if moveState.noclipAntiSink then
				-- Flying already controls height, and walk fling drives Y
				-- itself through its spike and restore cycle, so anti-sink
				-- must stay out of the way of both or they fight.
				if not (moveState.flyActive or moveState.vehicleFlyActive
					or moveState.walkFlingActive) then
					holdAltitude(char:FindFirstChild("HumanoidRootPart"), "character")
				end
			end
		end)
	end)
	helpers.notify("Noclip", "Walk through walls!")
end

local function stopNoclip()
	if moveState.noclipConnection then moveState.noclipConnection:Disconnect() moveState.noclipConnection = nil end
	moveState.noclipFloor.character = nil
end

-- ===================== WALK FLING =====================
-- Ported from the Synapse hub, where it is proven. Unlike the car case this
-- works because your own character is the one thing you both own and can
-- safely spike: the velocity is multiplied for a single frame and restored
-- on the next, so you barely move but anything you touch during the spiked
-- frame is resolved by the server against a body travelling absurdly fast.
-- Only the horizontal components are spiked; touching Y would launch you.
local function startWalkFling()
	local ok, err = pcall(function()
		local character = LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Noclip is required, not optional: without it you bump off a player
		-- instead of overlapping them, and the spike never makes contact. It
		-- was removed earlier because it sank the character through the floor,
		-- but anti-sink now holds altitude, so it is safe to turn back on.
		if not moveState.noclipActive then
			moveState.noclipActive = true
			moveState.noclipAntiSink = true
			startNoclip()
			moveState.walkFlingAutoNoclip = true
		end

		moveState.walkFlingActive = true
		local movel = 0.1

		task.spawn(function()
			while moveState.walkFlingActive do
				local char = LocalPlayer.Character
				local rt = char and char:FindFirstChild("HumanoidRootPart")
				if not (char and char.Parent and rt and rt.Parent) then
					RunService.Heartbeat:Wait()
				else
					local vel = rt.Velocity
					-- Strictly a multiplier of the velocity you already have.
					-- An earlier version added a fixed push along the facing
					-- direction so it would work while standing still; that is
					-- a large absolute velocity applied to your own character,
					-- and it simply launched the player. Multiplying means a
					-- stationary player scales zero and goes nowhere, which is
					-- the point: you have to walk into someone.
					rt.Velocity = Vector3.new(vel.X * 10000, vel.Y, vel.Z * 10000)

					RunService.RenderStepped:Wait()
					if char and char.Parent and rt and rt.Parent then
						rt.Velocity = vel
					end

					RunService.Stepped:Wait()
					-- Tiny Y oscillation keeps ground contact so you keep moving.
					if char and char.Parent and rt and rt.Parent then
						rt.Velocity = vel + Vector3.new(0, movel, 0)
						movel = movel * -1
					end
				end
			end
		end)

		helpers.notify("Walk Fling", "ON - walk into players!")
	end)
	if not ok then helpers.notify("Walk Fling", "Error: " .. tostring(err)) end
end

local function stopWalkFling()
	moveState.walkFlingActive = false
	if moveState.walkFlingAutoNoclip then
		moveState.noclipActive = false
		stopNoclip()
		moveState.walkFlingAutoNoclip = false
	end
	helpers.notify("Walk Fling", "OFF")
end

-- ===================== INSTANT RELOAD =====================
-- Zeroes the reload timing the kit reads from each weapon's Configuration.
-- These are read per reload rather than once at init, so unlike the ammo
-- counts this does take effect on already-equipped weapons.
-- A live dump showed these weapons carry no ReloadTime value at all, so the
-- earlier list of reload timings was zeroing fields that do not exist.
-- ShotCooldown is the only timing present, and the reload itself is made
-- instant by refilling CurrentAmmo the moment it drops.
local RELOAD_ZERO_VALUES = {"ShotCooldown"}

local function applyInstantReload()
	local function zeroTool(tool)
		if not tool:IsA("Tool") then return end
		local config = tool:FindFirstChild("Configuration")
		if not config then return end
		for _, val in ipairs(config:GetChildren()) do
			for _, name in ipairs(RELOAD_ZERO_VALUES) do
				if val.Name == name then
					pcall(function() val.Value = 0 end)
				end
			end
		end
	end
	pcall(function()
		for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do zeroTool(tool) end
		local char = LocalPlayer.Character
		if char then
			for _, tool in ipairs(char:GetChildren()) do zeroTool(tool) end
		end
	end)
end

local function startInstantReload()
	applyInstantReload()
	moveState.instantReloadConnection = RunService.Heartbeat:Connect(function()
		applyInstantReload()
		-- Refilling the magazine as it empties is what actually removes the
		-- reload, since there is no reload duration to zero out.
		refillAllAmmo()
	end)
	helpers.notify("Instant Reload", "ON")
end

local function stopInstantReload()
	if moveState.instantReloadConnection then
		moveState.instantReloadConnection:Disconnect()
		moveState.instantReloadConnection = nil
	end
	helpers.notify("Instant Reload", "OFF")
end

-- ===================== SPEED BOOST =====================
local function startSpeedBoost()
	local hrp = helpers.getRoot()
	if not hrp then return end

	moveState.speedBV = Instance.new("BodyVelocity")
	moveState.speedBV.MaxForce = Vector3.new(math.huge, 0, math.huge)
	moveState.speedBV.Velocity = Vector3.new(0, 0, 0)
	moveState.speedBV.P = 9000
	moveState.speedBV.Parent = hrp

	moveState.speedConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local rt = helpers.getRoot()
			local hum = helpers.getHumanoid()
			if not rt or not hum then return end
			if not moveState.speedBV or not moveState.speedBV.Parent then return end
			local moveDir = hum.MoveDirection
			if moveDir.Magnitude > 0 then
				moveState.speedBV.Velocity = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * moveState.speedValue
			else
				moveState.speedBV.Velocity = Vector3.new(0, 0, 0)
			end
		end)
	end)
	helpers.notify("Speed", "Speed boost active!")
end

local function stopSpeedBoost()
	if moveState.speedConnection then moveState.speedConnection:Disconnect() moveState.speedConnection = nil end
	if moveState.speedBV then pcall(function() moveState.speedBV:Destroy() end) moveState.speedBV = nil end
end

-- ===================== INFINITE JUMP =====================
local function startInfJump()
	moveState.infJumpActive = true
end

UserInputService.JumpRequest:Connect(function()
	if moveState.infJumpActive then
		pcall(function()
			local hum = helpers.getHumanoid()
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end
end)

-- ===================== FULLBRIGHT =====================

local function enableFullbright()
	local Lighting = game:GetService("Lighting")
	espState.savedLighting.Brightness = Lighting.Brightness
	espState.savedLighting.ClockTime = Lighting.ClockTime
	espState.savedLighting.FogEnd = Lighting.FogEnd
	espState.savedLighting.GlobalShadows = Lighting.GlobalShadows
	espState.savedLighting.OutdoorAmbient = Lighting.OutdoorAmbient

	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = false
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	helpers.notify("Fullbright", "Full visibility!")
end

local function disableFullbright()
	local Lighting = game:GetService("Lighting")
	if espState.savedLighting.Brightness then Lighting.Brightness = espState.savedLighting.Brightness end
	if espState.savedLighting.ClockTime then Lighting.ClockTime = espState.savedLighting.ClockTime end
	if espState.savedLighting.FogEnd then Lighting.FogEnd = espState.savedLighting.FogEnd end
	if espState.savedLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = espState.savedLighting.GlobalShadows end
	if espState.savedLighting.OutdoorAmbient then Lighting.OutdoorAmbient = espState.savedLighting.OutdoorAmbient end
end

-- ===================== ANTI AFK =====================
local function startAntiAfk()
	miscState.antiAfkActive = true
	pcall(function()
		if getconnections then
			for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
				conn:Disable()
			end
		end
	end)
	task.spawn(function()
		while miscState.antiAfkActive do
			pcall(function()
				local VirtualUser = game:GetService("VirtualUser")
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
			task.wait(300)
		end
	end)
	helpers.notify("Anti-AFK", "AFK prevention active!")
end

local function stopAntiAfk()
	miscState.antiAfkActive = false
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
		while miscState.antiKickActive do
			pcall(function()
				local VU = game:GetService("VirtualUser")
				VU:CaptureController()
				VU:ClickButton2(Vector2.new())
			end)
			task.wait(60)
		end
	end)
	helpers.notify("Anti-Kick", "Kick protection active!")
end

-- ===================== ANTI-RAGDOLL =====================
local function startAntiRagdoll()
	miscState.antiRagdollConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local hum = helpers.getHumanoid()
			if hum then
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			end
		end)
	end)
	helpers.notify("Anti-Ragdoll", "Ragdoll prevention active!")
end

local function stopAntiRagdoll()
	if miscState.antiRagdollConnection then miscState.antiRagdollConnection:Disconnect() miscState.antiRagdollConnection = nil end
	pcall(function()
		local hum = helpers.getHumanoid()
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		end
	end)
end

-- ===================== CHAT MESSAGE SENDER =====================
function helpers.sendChatMessage(msg)
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

function actions.showCustomAnnouncement(text, protocol, duration)
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
	local teamColor, roleName, teamName = helpers.getPlayerTeamInfo(LocalPlayer)
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
function actions.getVehicle()
	local char = LocalPlayer.Character
	if not char then return nil, nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or not hum.SeatPart then return nil, nil end
	local seat = hum.SeatPart

	-- Walk up rather than checking seat.Parent alone. Passenger seats are
	-- often nested (Model > Seats > Seat), so the old single-level check
	-- returned nil for every seat except the driver's, which is why the
	-- vehicle features only worked from the driving seat.
	local vehicle = seat.Parent
	while vehicle and vehicle ~= workspace and not vehicle:IsA("Model") do
		vehicle = vehicle.Parent
	end
	if vehicle and vehicle ~= workspace and vehicle:IsA("Model") then
		-- Prefer the VehicleSeat: it is the body the game itself drives.
		local drivePart = vehicle.PrimaryPart
		if not drivePart then
			for _, part in ipairs(vehicle:GetDescendants()) do
				if part:IsA("VehicleSeat") then drivePart = part break end
			end
		end
		return vehicle, drivePart or seat
	end
	return nil, seat
end

local function startVehicleFly()
	local vehicle, part = actions.getVehicle()
	if not part then
		helpers.notify("Vehicle Fly", "You must be sitting in a vehicle!")
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

	moveState.vehicleFlyBV = Instance.new("BodyVelocity")
	moveState.vehicleFlyBV.Name = "NBTF_VFly_BV"
	moveState.vehicleFlyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	moveState.vehicleFlyBV.Velocity = Vector3.new(0, 0, 0)
	moveState.vehicleFlyBV.P = 9000
	moveState.vehicleFlyBV.Parent = part

	moveState.vehicleFlyBG = Instance.new("BodyGyro")
	moveState.vehicleFlyBG.Name = "NBTF_VFly_BG"
	moveState.vehicleFlyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	moveState.vehicleFlyBG.P = 9000
	moveState.vehicleFlyBG.CFrame = part.CFrame
	moveState.vehicleFlyBG.Parent = part

	moveState.vehicleFlyConnection = RunService.RenderStepped:Connect(function()
		pcall(function()
			if not moveState.vehicleFlyBV or not moveState.vehicleFlyBV.Parent then return end
			local moveVec = Vector3.zero
			local camCF = camera.CFrame
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + camCF.UpVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - camCF.UpVector end

			-- Touch input. A seated humanoid reports no MoveDirection, so the
			-- seat's own Throttle/Steer (driven by Roblox's mobile vehicle
			-- controls) provides horizontal movement, and the pad does up/down.
			local ch = LocalPlayer.Character
			local hm = ch and ch:FindFirstChildOfClass("Humanoid")
			local st = hm and hm.SeatPart
			if st and st:IsA("VehicleSeat") then
				if st.Throttle ~= 0 then moveVec = moveVec + camCF.LookVector * st.Throttle end
				if st.Steer ~= 0 then moveVec = moveVec + camCF.RightVector * st.Steer end
			end
			if flyUp then moveVec = moveVec + camCF.UpVector end
			if flyDown then moveVec = moveVec - camCF.UpVector end

			moveState.vehicleFlyBV.Velocity = moveVec.Magnitude > 0 and moveVec.Unit * moveState.vehicleFlySpeed or Vector3.zero
			moveState.vehicleFlyBG.CFrame = camCF
		end)
	end)

	createFlyPad("vehicle")
	if UserInputService.TouchEnabled then
		helpers.notify("Vehicle Fly", "Flying! Use vehicle controls + on-screen up/down")
	else
		helpers.notify("Vehicle Fly", "Flying with vehicle! WASD + Space/Shift")
	end
end

local function stopVehicleFly()
	if moveState.vehicleFlyConnection then moveState.vehicleFlyConnection:Disconnect() moveState.vehicleFlyConnection = nil end
	if moveState.vehicleFlyBV then pcall(function() moveState.vehicleFlyBV:Destroy() end) moveState.vehicleFlyBV = nil end
	if moveState.vehicleFlyBG then pcall(function() moveState.vehicleFlyBG:Destroy() end) moveState.vehicleFlyBG = nil end
	destroyFlyPad("vehicle")
end

-- ===================== CAR SPEED BOOST =====================
-- Boosts the vehicle you're sitting in. For VehicleSeat we raise MaxSpeed
-- and Torque so the engine itself pushes harder; for plain Seats (planes,
-- boats, custom rigs) we push the primary part forward each frame until it
-- reaches the target speed.
-- ===================== VEHICLE NOCLIP =====================
-- Turns off collision on the vehicle (and the driver, who is welded into the
-- same assembly) so it can be driven through walls.
--
-- Originals are recorded and restored rather than forcing everything back to
-- CanCollide = true on the way out: plenty of vehicle parts are deliberately
-- non-collidable, and blanket-restoring them makes the car solid in places it
-- never was.
local function startCarNoclip()
	moveState.carNoclipOrig = {}
	moveState.carNoclipConnection = RunService.Stepped:Connect(function()
		pcall(function()
			local vehicle = actions.getVehicle()
			if not vehicle then return end
			for _, part in ipairs(vehicle:GetDescendants()) do
				if part:IsA("BasePart") then
					if moveState.carNoclipOrig[part] == nil then
						moveState.carNoclipOrig[part] = part.CanCollide
					end
					part.CanCollide = false
				end
			end
			if moveState.noclipAntiSink and not moveState.vehicleFlyActive then
				local _, drivePart = actions.getVehicle()
				holdAltitude(drivePart, "vehicle")
			end
		end)
	end)
	helpers.notify("Vehicle Noclip", "ON - drive through walls!")
end

local function stopCarNoclip()
	if moveState.carNoclipConnection then
		moveState.carNoclipConnection:Disconnect()
		moveState.carNoclipConnection = nil
	end
	pcall(function()
		for part, was in pairs(moveState.carNoclipOrig) do
			if part and part.Parent then part.CanCollide = was end
		end
	end)
	moveState.carNoclipOrig = {}
	moveState.noclipFloor.vehicle = nil
	helpers.notify("Vehicle Noclip", "OFF")
end

-- ===================== BACKSEAT DRIVE =====================
-- Drives the vehicle from ANY seat, including passenger seats, by pushing the
-- vehicle body directly instead of going through the driver's controls.
--
-- Steering is camera-relative rather than the vehicle's own look direction:
-- a passenger has no steering wheel to turn, and camera-relative movement is
-- also the only scheme that works on touch, where there is no A/D to read.
local bsPadGui, bsFwd, bsBack = nil, false, false

local function destroyBackseatPad()
	if bsPadGui then pcall(function() bsPadGui:Destroy() end) end
	bsPadGui = nil
	bsFwd, bsBack = false, false
end

local function createBackseatPad()
	destroyBackseatPad()
	if not UserInputService.TouchEnabled then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "NBTF_BackseatPad"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	pcall(function() gui.Parent = game:GetService("CoreGui") end)
	if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
	bsPadGui = gui

	local function makeBtn(label, yOffset, onDown, onUp)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 64, 0, 64)
		-- Left side, so it does not sit under the fly pad on the right.
		b.Position = UDim2.new(0, 16, 1, yOffset)
		b.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		b.BackgroundTransparency = 0.25
		b.Text = label
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextSize = 24
		b.Font = Enum.Font.GothamBold
		b.BorderSizePixel = 0
		b.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 12)
		c.Parent = b
		b.MouseButton1Down:Connect(onDown)
		b.MouseButton1Up:Connect(onUp)
		b.MouseLeave:Connect(onUp)
	end

	makeBtn("GO", -150, function() bsFwd = true end, function() bsFwd = false end)
	makeBtn("REV", -78, function() bsBack = true end, function() bsBack = false end)
end

local function startBackseatDrive()
	local _, drivePart = actions.getVehicle()
	if not drivePart then
		helpers.notify("Backseat Drive", "Sit in a vehicle first!")
		return
	end
	createBackseatPad()

	-- Built on BodyVelocity/BodyGyro rather than AssemblyLinearVelocity,
	-- because that is the mechanism Vehicle Fly uses and Vehicle Fly is
	-- confirmed working in this game. Writing assembly velocity directly is a
	-- different path and evidently does not take here.
	--
	-- The important difference from flying: MaxForce leaves Y at zero, so
	-- gravity still acts and the vehicle stays on the ground instead of
	-- floating. The gyro likewise only has torque on Y, so the vehicle turns
	-- to face where you are steering without being held level.
	local bv = Instance.new("BodyVelocity")
	bv.Name = "NBTF_Backseat_BV"
	bv.MaxForce = Vector3.new(math.huge, 0, math.huge)
	bv.Velocity = Vector3.zero
	bv.P = 9000
	bv.Parent = drivePart
	moveState.backseatBV = bv

	local bg = Instance.new("BodyGyro")
	bg.Name = "NBTF_Backseat_BG"
	bg.MaxTorque = Vector3.new(0, math.huge, 0)
	bg.P = 6000
	bg.D = 500
	bg.CFrame = drivePart.CFrame
	bg.Parent = drivePart
	moveState.backseatBG = bg

	moveState.backseatDriveConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not moveState.backseatBV or not moveState.backseatBV.Parent then return end

			local throttle = 0
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then throttle = throttle + 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then throttle = throttle - 1 end
			if bsFwd then throttle = throttle + 1 end
			if bsBack then throttle = throttle - 1 end

			-- Flattened so looking down does not drive into the ground.
			local look = camera.CFrame.LookVector
			local dir = Vector3.new(look.X, 0, look.Z)
			if dir.Magnitude < 0.01 then return end
			dir = dir.Unit

			if throttle ~= 0 then
				moveState.backseatBV.Velocity = dir * throttle * moveState.backseatDriveSpeed
				-- Face the way we are travelling; reversing keeps facing forward.
				moveState.backseatBG.CFrame = CFrame.new(Vector3.zero, dir)
			else
				moveState.backseatBV.Velocity = Vector3.zero
			end
		end)
	end)

	if UserInputService.TouchEnabled then
		helpers.notify("Backseat Drive", "ON - GO/REV buttons, aim with camera")
	else
		helpers.notify("Backseat Drive", "ON - W/S from any seat, aim with camera")
	end
end

local function stopBackseatDrive()
	if moveState.backseatDriveConnection then
		moveState.backseatDriveConnection:Disconnect()
		moveState.backseatDriveConnection = nil
	end
	if moveState.backseatBV then pcall(function() moveState.backseatBV:Destroy() end) moveState.backseatBV = nil end
	if moveState.backseatBG then pcall(function() moveState.backseatBG:Destroy() end) moveState.backseatBG = nil end
	destroyBackseatPad()
	helpers.notify("Backseat Drive", "OFF")
end

local function startCarSpeed()
	local char = LocalPlayer.Character
	if not char then helpers.notify("Car Speed", "No character!") return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or not hum.SeatPart then
		helpers.notify("Car Speed", "Sit in a vehicle first!")
		return
	end
	local seat = hum.SeatPart

	if seat:IsA("VehicleSeat") then
		moveState.carSpeedOrigMaxSpeed = seat.MaxSpeed
		moveState.carSpeedOrigTorque = seat.Torque
		local baseMax = (moveState.carSpeedOrigMaxSpeed and moveState.carSpeedOrigMaxSpeed > 0) and moveState.carSpeedOrigMaxSpeed or 50
		seat.MaxSpeed = moveState.carSpeedValue
		seat.Torque = seat.Torque * (moveState.carSpeedValue / baseMax)
	end

	moveState.carSpeedConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local c = LocalPlayer.Character
			if not c then return end
			local h = c:FindFirstChildOfClass("Humanoid")
			if not h or not h.SeatPart then return end
			local s = h.SeatPart
			local vehicle = s.Parent
			local primary = (vehicle and vehicle:IsA("Model") and vehicle.PrimaryPart) or s

			-- Setting MaxSpeed is not enough on its own: property writes from
			-- the client don't replicate in FilteringEnabled games, so the
			-- server keeps driving the car at its own speed. Kept because it
			-- does help in games where the client owns the seat.
			if s:IsA("VehicleSeat") then
				s.MaxSpeed = moveState.carSpeedValue
			end

			-- Real acceleration. The client holds network ownership of the
			-- vehicle it is sitting in, so writing the assembly velocity does
			-- replicate. Throttle picks the direction so the car only speeds
			-- up while you are actually driving it.
			local throttle = s:IsA("VehicleSeat") and s.Throttle or 0
			local dir
			if throttle ~= 0 then
				dir = primary.CFrame.LookVector * throttle
			elseif not s:IsA("VehicleSeat") then
				dir = primary.CFrame.LookVector
			end

			if dir and dir.Magnitude > 0 then
				dir = dir.Unit
				local vel = primary.AssemblyLinearVelocity
				if vel:Dot(dir) < moveState.carSpeedValue then
					-- Preserve vertical velocity so gravity and jumps still work.
					local boosted = dir * moveState.carSpeedValue
					primary.AssemblyLinearVelocity = Vector3.new(boosted.X, vel.Y, boosted.Z)
				end
			end
		end)
	end)
	helpers.notify("Car Speed", "ON - target " .. moveState.carSpeedValue)
end

local function stopCarSpeed()
	if moveState.carSpeedConnection then moveState.carSpeedConnection:Disconnect() moveState.carSpeedConnection = nil end
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
			if moveState.carSpeedOrigMaxSpeed then hum.SeatPart.MaxSpeed = moveState.carSpeedOrigMaxSpeed end
			if moveState.carSpeedOrigTorque then hum.SeatPart.Torque = moveState.carSpeedOrigTorque end
		end
	end)
	moveState.carSpeedOrigMaxSpeed = nil
	moveState.carSpeedOrigTorque = nil
	helpers.notify("Car Speed", "OFF")
end

-- ===================== CAR FLING =====================
-- Velocity-spike fling applied to the vehicle, using the same spike-and-
-- restore cycle as Walk Fling.
--
-- This works here for a reason specific to NBTF: players do not collide with
-- each other, which is why walk fling can never launch anyone in this game,
-- but they DO collide with vehicles. The car is therefore the only body that
-- can actually strike a player, which makes it the right tool rather than the
-- awkward one.
--
-- The spike is a multiplier of the velocity the vehicle already has, and it is
-- restored on the very next frame. The car nets almost no movement, so the
-- driver is not thrown, but the collision the server resolves during the
-- spiked frame is against a body travelling absurdly fast. Y is left alone
-- throughout; touching it is what fired the car and driver skyward before.
local function startCarFling()
	local ok, err = pcall(function()
		local _, vPart = actions.getVehicle()
		if not vPart then
			helpers.notify("Car Fling", "Sit in a vehicle first!")
			return
		end

		moveState.carFlingLoopActive = true
		local movel = 0.1

		task.spawn(function()
			while moveState.carFlingLoopActive do
				local _, part = actions.getVehicle()
				if not part or not part.Parent then
					RunService.Heartbeat:Wait()
				else
					local vel = part.Velocity
					-- Multiplier, not a fixed push: parked means zero times the
					-- multiplier, so nothing happens and the driver stays put.
					-- You have to actually drive into someone.
					part.Velocity = Vector3.new(vel.X * 10000, vel.Y, vel.Z * 10000)

					RunService.RenderStepped:Wait()
					if part and part.Parent then
						part.Velocity = vel
					end

					RunService.Stepped:Wait()
					if part and part.Parent then
						part.Velocity = vel + Vector3.new(0, movel, 0)
						movel = movel * -1
					end
				end
			end
		end)

		helpers.notify("Car Fling", "ON - drive into people!")
	end)
	if not ok then helpers.notify("Car Fling", "Error: " .. tostring(err)) end
end

local function stopCarFling()
	moveState.carFlingLoopActive = false
	-- Clear any spike left behind if the loop stopped between spiking and
	-- restoring, or the vehicle coasts away at ten thousand times its speed.
	pcall(function()
		local _, part = actions.getVehicle()
		if part and part.Parent then
			local v = part.Velocity
			part.Velocity = Vector3.new(0, v.Y, 0)
		end
	end)
	helpers.notify("Car Fling", "OFF")
end

-- ===================== SPECTATE PLAYER =====================
function actions.spectatePlayer(player)
	if not player then return end
	playerState.spectateTarget = player
	playerState.spectateActive = true

	if playerState.spectateConnection then
		playerState.spectateConnection:Disconnect()
		playerState.spectateConnection = nil
	end

	-- Re-applied every frame: setting CameraSubject once is undone whenever
	-- either character respawns, and the target's Humanoid is a new instance
	-- after their death, so it has to be looked up again rather than cached.
	playerState.spectateConnection = RunService.RenderStepped:Connect(function()
		if not playerState.spectateActive then return end
		pcall(function()
			local target = playerState.spectateTarget
			if not target or not target.Parent then return end
			local char = target.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			if camera.CameraSubject ~= hum then
				camera.CameraSubject = hum
			end
			if camera.CameraType ~= Enum.CameraType.Custom then
				camera.CameraType = Enum.CameraType.Custom
			end
		end)
	end)

	helpers.notify("Spectate", "Watching " .. player.DisplayName)
end

function actions.unspectate()
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
	if playerState.spectateConnection then
		playerState.spectateConnection:Disconnect()
		playerState.spectateConnection = nil
	end
	playerState.spectateTarget = nil
	playerState.spectateActive = false
	helpers.notify("Spectate", "Stopped - camera returned to you")
end

-- ===================== NO RECOIL (NBTF-Specific) =====================
-- Sets RecoilDecay/RecoilMax/RecoilMin/MaxSpread/MinSpread to 0 in weapon Configuration
local function startNoRecoil()
	-- Apply to all guns immediately
	actions.modGuns()
	-- Keep applying on heartbeat
	combatState.noRecoilConnection = RunService.Heartbeat:Connect(function()
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
	helpers.notify("No Recoil", "Zero recoil + zero spread!")
end

local function stopNoRecoil()
	if combatState.noRecoilConnection then combatState.noRecoilConnection:Disconnect() combatState.noRecoilConnection = nil end
end

-- ===================== AUTO FIRE =====================
-- Automatically fires equipped gun by simulating mouse1 clicks
local function startAutoFire()
	combatState.autoFireConnection = RunService.Heartbeat:Connect(function()
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
	helpers.notify("Auto Fire", "Hold left click for rapid fire!")
end

local function stopAutoFire()
	if combatState.autoFireConnection then combatState.autoFireConnection:Disconnect() combatState.autoFireConnection = nil end
end

-- ===================== GRAVITY =====================
function actions.setGravity(val)
	workspace.Gravity = val
end

-- ===================== BRING ALL PLAYERS =====================
-- Teleports all enemy players to your position
function actions.bringPlayer(player)
	local hrp = helpers.getRoot()
	if not hrp then helpers.notify("Error", "No character") return end
	if not helpers.isAlive(player) then
		helpers.notify("Error", player.DisplayName .. " is dead or not in game")
		return
	end
	pcall(function()
		local theirHRP = player.Character:FindFirstChild("HumanoidRootPart")
		if theirHRP then
			theirHRP.CFrame = hrp.CFrame + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
			helpers.notify("Bring", "Brought " .. player.DisplayName)
		end
	end)
end

function actions.bringAllPlayers()
	local hrp = helpers.getRoot()
	if not hrp then helpers.notify("Error", "No character") return end
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and helpers.isAlive(player) then
			pcall(function()
				local theirHRP = player.Character:FindFirstChild("HumanoidRootPart")
				if theirHRP then
					theirHRP.CFrame = hrp.CFrame + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
					count = count + 1
				end
			end)
		end
	end
	helpers.notify("Bring All", "Brought " .. count .. " players!")
end

-- ===================== KILL ALL (Stealth - Delayed WeaponHit) =====================
-- Fires at each enemy with delays to avoid detection
-- Uses only ONE gun, 3 rounds per player, 0.3s between each fire
local killAllRunning = false

function actions.killAllPlayers()
	if not WeaponHitRemote then
		helpers.notify("Error", "WeaponHit remote not found!")
		return
	end
	if killAllRunning then
		helpers.notify("Kill All", "Already running! Wait for it to finish.")
		return
	end

	task.spawn(function()
		killAllRunning = true
		local gun = helpers.findGunInBackpack()
		if not gun then
			-- Try equipped tool
			local char = LocalPlayer.Character
			if char then
				gun = char:FindFirstChildOfClass("Tool")
			end
		end
		if not gun then
			helpers.notify("Error", "No gun found! Equip a weapon first.")
			killAllRunning = false
			return
		end

		local killed = 0
		local targets = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and helpers.isAlive(player) then
				table.insert(targets, player)
			end
		end

		helpers.notify("Kill All", "Targeting " .. #targets .. " players (stealth mode)...")

		-- 3 rounds per target, configurable delay between each fire
		for round = 1, 3 do
			for _, player in ipairs(targets) do
				if not killAllRunning then break end
				if helpers.isAlive(player) then
					pcall(function()
						fireWeaponHit(player, gun, "aim")
					end)
					if round == 1 then killed = killed + 1 end
					task.wait(combatState.killAllDelay)
				end
			end
			if not killAllRunning then break end
			task.wait(0.5) -- pause between rounds
		end

		killAllRunning = false
		helpers.notify("Kill All", "Done! Fired at " .. killed .. " players (3 rounds each)")
	end)
end

-- ===================== FREEZE ALL PLAYERS =====================
function actions.freezeAllPlayers()
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and helpers.isAlive(player) then
			pcall(function()
				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Anchored = true
					count = count + 1
				end
			end)
		end
	end
	helpers.notify("Freeze", "Froze " .. count .. " players!")
end

function actions.unfreezeAllPlayers()
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
	helpers.notify("Unfreeze", "Unfroze " .. count .. " players!")
end

-- ===================== TELEPORT TO PLAYER =====================
function actions.teleportToPlayer(playerName)
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
			helpers.notify("Teleport", "Teleported to " .. target.DisplayName)
		end
	else
		helpers.notify("Error", "Player not found or dead")
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
function actions.findLocationByName(searchName)
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
function actions.getLocationPosition(obj)
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
function actions.scanLocations()
	local found = {}
	local seen = {} -- avoid duplicates

	for _, searchName in ipairs(NBTF_SEARCH_NAMES) do
		local obj = actions.findLocationByName(searchName)
		if obj and not seen[obj] then
			seen[obj] = true
			local pos = actions.getLocationPosition(obj)
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

-- ===================== GUI SETUP (WindUI) =====================
-- The hand-built interface was replaced with a library. Every feature call
-- site is untouched: uiBuilder keeps the same signatures and builds WindUI
-- elements instead, and tabFrames holds WindUI tab objects. That kept a
-- fifty-control port to one adapter rather than fifty rewrites.
local Fluent
do
	local ok, lib = pcall(function()
		return loadstring(game:HttpGet(
			"https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
	end)
	if not ok or not lib then
		warn("[SX NBTF] Fluent failed to load: " .. tostring(lib))
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Pebbleford NBTF",
				Text = "UI library failed to load. Check your internet/executor.",
				Duration = 8,
			})
		end)
		return
	end
	Fluent = lib
	_G.SXNBTF_UI = lib
end

local Window = Fluent:CreateWindow({
	Title = "Pebbleford Hub - NBTF",
	SubTitle = "NBTF Hub v7.2",
	TabWidth = 150,
	Size = UDim2.fromOffset(580, 460),
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.RightShift,
})

-- Declared here because the old declaration lived in the hand-built GUI that
-- this replaced; without it the assignment below indexes a nil global.
local tabFrames = {}

-- Same tab names as before, so every build block below still finds its tab.
for _, name in ipairs({"Aim", "Combat", "Movement", "Visuals", "Teleport", "Players", "Misc", "Settings"}) do
	tabFrames[name] = Window:AddTab({Title = name})
end

-- ===================== UI BUILDERS (WindUI adapters) =====================
-- The order argument is accepted and ignored: WindUI lays elements out in
-- creation order, which is the order these were already being declared in.
function uiBuilder.addCorner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = inst
	return c
end

function uiBuilder.setActiveTab(name)
	uiState.activeTab = name
end

function uiBuilder.createSectionLabel(parent, text, order)
	if not parent then return end
	return parent:AddParagraph({Title = text, Content = ""})
end

function uiBuilder.createInfoLabel(parent, text, order)
	if not parent then return end
	return parent:AddParagraph({Title = "", Content = text})
end

-- Returns a proxy, not a WindUI object. The feature code updates these labels
-- by assigning .Text from timer loops, so __newindex forwards that to SetDesc
-- and quietly absorbs the cosmetic properties the library manages itself.
function uiBuilder.createDynamicLabel(parent, text)
	if not parent then return setmetatable({}, {__newindex = function() end}) end
	local para = parent:AddParagraph({Title = "", Content = tostring(text or "")})
	local lastText = tostring(text or "")
	return setmetatable({}, {
		__newindex = function(_, key, value)
			if key == "Text" then
				local str = tostring(value)
				if str ~= lastText then
					lastText = str
					pcall(function() para:SetDesc(str) end)
				end
			end
		end,
		__index = function() return nil end,
	})
end

local _nbtfFlag = 0
local function nbtfFlag() _nbtfFlag = _nbtfFlag + 1 return "nbtf_" .. _nbtfFlag end

function uiBuilder.createToggle(parent, text, order, callback)
	if not parent then return end
	return parent:AddToggle(nbtfFlag(), {
		Title = text, Default = false,
		Callback = function(value) if callback then pcall(callback, value) end end,
	})
end

function uiBuilder.createButton(parent, text, order, callback)
	if not parent then return end
	return parent:AddButton({
		Title = text,
		Callback = function() if callback then pcall(callback) end end,
	})
end

function uiBuilder.createSlider(parent, text, min, max, default, order, callback)
	if not parent then return end
	return parent:AddSlider(nbtfFlag(), {
		Title = text, Min = min, Max = max, Default = default, Rounding = 0,
		Callback = function(value)
			local n = type(value) == "table" and (value.Value or value.Default) or value
			if callback and type(n) == "number" then pcall(callback, n) end
		end,
	})
end

function uiBuilder.createDropdown(parent, text, options, default, callback)
	if not parent then return end
	return parent:AddDropdown(nbtfFlag(), {
		Title = text, Values = options, Multi = false, Default = default,
		Callback = function(chosen)
			local value = type(chosen) == "table" and chosen[1] or chosen
			if callback and value then pcall(callback, value) end
		end,
	})
end

function uiBuilder.createInput(parent, text, placeholder, callback)
	if not parent then return end
	return parent:AddInput(nbtfFlag(), {
		Title = text, Default = "", Placeholder = placeholder or "",
		Numeric = false, Finished = false,
		Callback = function(value) if callback then pcall(callback, value) end end,
	})
end

function uiBuilder.createSpacer(parent, order)
	-- WindUI spaces its own elements; nothing to add.
	return nil
end

-- ===================== X-RAY =====================
-- Makes the map itself see-through. Only large, anchored parts are touched:
-- transparency is applied to the world, and players, vehicles and loose items
-- are deliberately skipped so they stay solid-looking and easy to pick out.
local function startXray()
	espState.xrayOrig = {}
	pcall(function()
		for _, part in ipairs(workspace:GetDescendants()) do
			if part:IsA("BasePart") and part.Anchored and part.Transparency < 1 then
				local model = part:FindFirstAncestorOfClass("Model")
				local isPlayer = model and Players:GetPlayerFromCharacter(model)
				if not isPlayer and part.Size.Magnitude > 6 then
					espState.xrayOrig[part] = part.Transparency
					part.Transparency = 0.72
				end
			end
		end
	end)
	helpers.notify("X-Ray", "Walls are see-through")
end

local function stopXray()
	pcall(function()
		for part, orig in pairs(espState.xrayOrig) do
			if part and part.Parent then part.Transparency = orig end
		end
	end)
	espState.xrayOrig = {}
	helpers.notify("X-Ray", "OFF")
end

-- ===================== CHAMS =====================
-- Highlight with DepthMode set to AlwaysOnTop, so enemies stay visible through
-- geometry. Kept separate from Player ESP: that draws names and distance,
-- this fills the body so a target is readable at a glance in a firefight.
local function updateChams()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and helpers.isAlive(player) then
			local char = player.Character
			if char and not espState.chamsHighlights[player] then
				local hl = Instance.new("Highlight")
				hl.Name = "NBTF_Chams"
				hl.FillTransparency = 0.4
				hl.OutlineTransparency = 0
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.FillColor = helpers.isEnemy(player) and Color3.fromRGB(255, 60, 60)
					or Color3.fromRGB(60, 160, 255)
				hl.OutlineColor = Color3.fromRGB(255, 255, 255)
				hl.Adornee = char
				hl.Parent = char
				espState.chamsHighlights[player] = hl
			end
		elseif espState.chamsHighlights[player] then
			pcall(function() espState.chamsHighlights[player]:Destroy() end)
			espState.chamsHighlights[player] = nil
		end
	end
end

local function startChams()
	espState.chamsConnection = RunService.Heartbeat:Connect(function()
		if not espState.chamsActive then return end
		pcall(updateChams)
	end)
	helpers.notify("Chams", "Players visible through walls")
end

local function stopChams()
	if espState.chamsConnection then espState.chamsConnection:Disconnect() espState.chamsConnection = nil end
	for _, hl in pairs(espState.chamsHighlights) do
		pcall(function() hl:Destroy() end)
	end
	espState.chamsHighlights = {}
	helpers.notify("Chams", "OFF")
end

-- ===================== VEHICLE ESP =====================
-- Vehicles are the one thing that can actually strike a player in this game,
-- so knowing where they are matters more here than in most hubs.
local function startVehicleEsp()
	espState.vehicleEspConnection = RunService.Heartbeat:Connect(function()
		if not espState.vehicleEspActive then return end
		pcall(function()
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("VehicleSeat") then
					local model = obj:FindFirstAncestorOfClass("Model")
					if model and not espState.vehicleEspHighlights[model] then
						local hl = Instance.new("Highlight")
						hl.Name = "NBTF_VehicleESP"
						hl.FillTransparency = 0.75
						hl.FillColor = Color3.fromRGB(255, 200, 60)
						hl.OutlineColor = Color3.fromRGB(255, 230, 120)
						hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						hl.Adornee = model
						hl.Parent = model
						espState.vehicleEspHighlights[model] = hl
					end
				end
			end
			-- Drop highlights whose vehicle has since been removed.
			for model, hl in pairs(espState.vehicleEspHighlights) do
				if not model or not model.Parent then
					pcall(function() hl:Destroy() end)
					espState.vehicleEspHighlights[model] = nil
				end
			end
		end)
	end)
	helpers.notify("Vehicle ESP", "Vehicles highlighted")
end

local function stopVehicleEsp()
	if espState.vehicleEspConnection then espState.vehicleEspConnection:Disconnect() espState.vehicleEspConnection = nil end
	for _, hl in pairs(espState.vehicleEspHighlights) do
		pcall(function() hl:Destroy() end)
	end
	espState.vehicleEspHighlights = {}
	helpers.notify("Vehicle ESP", "OFF")
end

-- ===================== AUTO INTERACT =====================
-- Continuously fires nearby ProximityPrompts. The hub already had a one-shot
-- button for this; as a toggle it opens doors and picks things up as you move
-- rather than needing a press each time.
local function startAutoInteract()
	miscState.autoInteractConnection = RunService.Heartbeat:Connect(function()
		if not miscState.autoInteractActive then return end
		pcall(function()
			local hrp = helpers.getRoot()
			if not hrp then return end
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("ProximityPrompt") and obj.Enabled then
					local part = obj.Parent
					if part and part:IsA("BasePart")
						and (part.Position - hrp.Position).Magnitude <= miscState.autoInteractRange then
						-- Zeroed so prompts fire instantly instead of needing a hold.
						obj.HoldDuration = 0
						obj.MaxActivationDistance = math.max(obj.MaxActivationDistance, miscState.autoInteractRange)
						-- Not every executor exposes this, so it is checked
						-- rather than assumed; without it the toggle would
						-- error every frame instead of simply doing nothing.
						if type(fireproximityprompt) == "function" then
							fireproximityprompt(obj)
						end
					end
				end
			end
		end)
	end)
	helpers.notify("Auto Interact", "Firing nearby prompts")
end

local function stopAutoInteract()
	if miscState.autoInteractConnection then miscState.autoInteractConnection:Disconnect() miscState.autoInteractConnection = nil end
	helpers.notify("Auto Interact", "OFF")
end

-- ===================== ANTI-FLING =====================
-- Clamps absurd velocity on your own character. Being launched across the map
-- is someone else's fling landing on you; capping the spike leaves normal
-- movement untouched because walking and jumping never come near the limit.
local function startAntiFling()
	miscState.antiFlingConnection = RunService.Heartbeat:Connect(function()
		if not miscState.antiFlingActive then return end
		pcall(function()
			local hrp = helpers.getRoot()
			if not hrp then return end
			local v = hrp.AssemblyLinearVelocity
			if v.Magnitude > 350 then
				hrp.AssemblyLinearVelocity = v.Unit * 60
			end
			local av = hrp.AssemblyAngularVelocity
			if av.Magnitude > 40 then
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end)
	end)
	helpers.notify("Anti-Fling", "Velocity spikes clamped")
end

local function stopAntiFling()
	if miscState.antiFlingConnection then miscState.antiFlingConnection:Disconnect() miscState.antiFlingConnection = nil end
	helpers.notify("Anti-Fling", "OFF")
end

-- ===================== ANTI-VOID =====================
-- Records the last safe position and restores it if you drop below the map.
local function startAntiVoid()
	local lastSafe = nil
	miscState.antiVoidConnection = RunService.Heartbeat:Connect(function()
		if not miscState.antiVoidActive then return end
		pcall(function()
			local hrp = helpers.getRoot()
			if not hrp then return end
			if hrp.Position.Y < miscState.antiVoidHeight then
				if lastSafe then
					hrp.CFrame = lastSafe
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			elseif hrp.Position.Y > miscState.antiVoidHeight + 20 then
				-- Only remember spots well clear of the void, or the saved
				-- position ends up being mid-fall and puts you straight back.
				lastSafe = hrp.CFrame
			end
		end)
	end)
	helpers.notify("Anti-Void", "You will be pulled back from falls")
end

local function stopAntiVoid()
	if miscState.antiVoidConnection then miscState.antiVoidConnection:Disconnect() miscState.antiVoidConnection = nil end
	helpers.notify("Anti-Void", "OFF")
end

-- ===================== JUMP POWER =====================
-- Reapplied on a loop because the game resets humanoid properties on respawn
-- and after some state changes.
local function startJumpPower()
	miscState.jumpPowerConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			local hum = helpers.getHumanoid()
			if not hum then return end
			hum.UseJumpPower = true
			hum.JumpPower = miscState.jumpPowerValue
		end)
	end)
end

local function stopJumpPower()
	if miscState.jumpPowerConnection then miscState.jumpPowerConnection:Disconnect() miscState.jumpPowerConnection = nil end
	pcall(function()
		local hum = helpers.getHumanoid()
		if hum then hum.JumpPower = 50 end
	end)
end

-- ===================== BUILD AIM TAB =====================
do
	local tab = tabFrames["Aim"]
	local n = 0
	local function o() n = n + 1 return n end

	uiBuilder.createSectionLabel(tab, "Silent Aim (Teleport Bullets)", o())
	uiBuilder.createToggle(tab, "Silent Aim", o(), function(on)
		aimState.silentAimActive = on
		if on then enableSilentAim() else disableSilentAim() end
	end)
	uiBuilder.createInfoLabel(tab, "Fires WeaponHit remote at nearest enemy when you shoot", o())
	uiBuilder.createInfoLabel(tab, "Uses actual NBTF WeaponsSystem - no hookmetamethod needed!", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Wallbang (Shoot Through Walls)", o())
	uiBuilder.createToggle(tab, "Wallbang", o(), function(on)
		if on then enableWallbang() else disableWallbang() end
	end)
	uiBuilder.createInfoLabel(tab, "Fires WeaponHit with d=0/maxDist=0 - hits through any wall", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Settings", o())
	uiBuilder.createSlider(tab, "FOV Radius", 50, 360, aimState.fovRadius, o(), function(val)
		aimState.fovRadius = val
	end)
	uiBuilder.createSlider(tab, "Hit Chance %", 10, 100, aimState.hitChance, o(), function(val)
		aimState.hitChance = val
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Visual Aimbot", o())
	uiBuilder.createToggle(tab, "Aimbot (Right-Click Lock)", o(), function(on)
		aimState.aimbotActive = on
		if on then startAimbot() else stopAimbot() end
	end)
	uiBuilder.createToggle(tab, "Aimbot Always-On (No Right-Click)", o(), function(on)
		aimState.aimbotAlwaysOn = on
		if on then helpers.notify("Aimbot", "Always-on mode!") end
	end)
	uiBuilder.createSlider(tab, "Aim Smoothness", 10, 100, math.floor(aimState.aimbotSmooth * 100), o(), function(val)
		aimState.aimbotSmooth = val / 100
	end)
	uiBuilder.createInfoLabel(tab, "Locks camera on nearest enemy. Always-on = no click needed.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Weapon Selector", o())
	uiBuilder.createInfoLabel(tab, "Choose which gun silent aim/wallbang uses (Auto = first found)", o())

	-- Was a wrapped grid of highlight buttons; a dropdown carries the same
	-- eighteen options without consuming most of the tab.
	local weaponOptions = {"Auto"}
	for _, gunName in ipairs(NBTF_GUNS) do
		table.insert(weaponOptions, gunName)
	end
	uiBuilder.createDropdown(tab, "Selected Weapon", weaponOptions, "Auto", function(choice)
		aimState.selectedWeapon = (choice ~= "Auto") and choice or nil
		helpers.notify("Weapon", choice == "Auto" and "Auto-detect mode" or "Using: " .. choice)
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Kill Aura", o())
	uiBuilder.createToggle(tab, "Kill Aura (Auto-Kill Nearby Enemies)", o(), function(on)
		combatState.killAuraActive = on
		if on then startKillAura() else stopKillAura() end
	end)
	uiBuilder.createSlider(tab, "Kill Aura Range (studs)", 10, 100, combatState.killAuraRange, o(), function(val) combatState.killAuraRange = val end)
	uiBuilder.createInfoLabel(tab, "Auto-fires WeaponHit at ALL enemies within range", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Trigger Bot", o())
	uiBuilder.createToggle(tab, "Trigger Bot (Auto-Fire on Crosshair)", o(), function(on)
		combatState.triggerBotActive = on
		if on then startTriggerBot() else stopTriggerBot() end
	end)
	uiBuilder.createSlider(tab, "Trigger Delay (x100 ms)", 1, 50, math.floor(combatState.triggerBotDelay * 100), o(), function(val)
		combatState.triggerBotDelay = val / 100
	end)
	uiBuilder.createInfoLabel(tab, "Fires when your crosshair is on an enemy player", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Target Part", o())
	uiBuilder.createButton(tab, "Target: Head (Current: " .. aimState.targetPart .. ")", o(), function()
		aimState.targetPart = "Head"
		helpers.notify("Target", "Targeting Head")
	end)
	uiBuilder.createButton(tab, "Target: Torso (HumanoidRootPart)", o(), function()
		aimState.targetPart = "HumanoidRootPart"
		helpers.notify("Target", "Targeting Torso")
	end)
	uiBuilder.createInfoLabel(tab, "Head = more damage, Torso = easier to hit", o())
end

-- ===================== BUILD COMBAT TAB =====================
do
	local tab = tabFrames["Combat"]
	local n = 0
	local function o() n = n + 1 return n end

	uiBuilder.createSectionLabel(tab, "Ammo", o())
	uiBuilder.createToggle(tab, "Unlimited Ammo", o(), function(on)
		combatState.infAmmoActive = on
		if on then startInfAmmo() else stopInfAmmo() end
	end)
	uiBuilder.createInfoLabel(tab, "Refills the live weapon each frame + maxes damage/range", o())
	uiBuilder.createToggle(tab, "Instant Reload", o(), function(on)
		if on then startInstantReload() else stopInstantReload() end
	end)
	uiBuilder.createButton(tab, "Mod All Guns (Ammo + Damage + No Recoil)", o(), function()
		actions.modGuns()
		helpers.notify("Mod Guns", "All guns modded! Max ammo, damage, zero recoil/spread")
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Hitbox", o())
	uiBuilder.createToggle(tab, "Hitbox Expander", o(), function(on)
		combatState.hitboxExpandActive = on
		if on then startHitboxExpand() else stopHitboxExpand() end
	end)
	uiBuilder.createSlider(tab, "Hitbox Size", 5, 30, combatState.hitboxSize, o(), function(val)
		combatState.hitboxSize = val
	end)
	uiBuilder.createInfoLabel(tab, "Makes enemy HumanoidRootParts larger = easier hits", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Weapon Mods", o())
	uiBuilder.createToggle(tab, "No Recoil", o(), function(on)
		combatState.noRecoilActive = on
		if on then startNoRecoil() else stopNoRecoil() end
	end)
	uiBuilder.createToggle(tab, "Auto Fire (Hold LMB = Rapid)", o(), function(on)
		combatState.autoFireActive = on
		if on then startAutoFire() else stopAutoFire() end
	end)
	uiBuilder.createInfoLabel(tab, "No recoil zeros gun config values. Auto fire spams tool:Activate()", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Protection", o())
	uiBuilder.createToggle(tab, "God Mode (Infinite Health)", o(), function(on)
		moveState.godModeActive = on
		if on then startGodMode() else stopGodMode() end
	end)
	uiBuilder.createInfoLabel(tab, "Heals to max every frame, prevents death states", o())
	uiBuilder.createToggle(tab, "Anti-Ragdoll (No Knockdown)", o(), function(on)
		miscState.antiRagdollActive = on
		if on then startAntiRagdoll() else stopAntiRagdoll() end
	end)
	uiBuilder.createInfoLabel(tab, "Prevents ragdoll/falling states (lighter than God Mode)", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Player Control", o())
	uiBuilder.createButton(tab, "Bring All Players to You", o(), actions.bringAllPlayers)
	uiBuilder.createButton(tab, "Kill All (WeaponHit Remote)", o(), actions.killAllPlayers)
	uiBuilder.createButton(tab, "Freeze All Players", o(), actions.freezeAllPlayers)
	uiBuilder.createButton(tab, "Unfreeze All Players", o(), actions.unfreezeAllPlayers)
	uiBuilder.createInfoLabel(tab, "Bring/freeze work on all non-team players", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Announcement System", o())
	uiBuilder.createInfoLabel(tab, "TP to Broadcast Room + auto-fire the console prompt to open GUI", o())
	uiBuilder.createInfoLabel(tab, "Uses noclip to bypass keycard door", o())

	-- Helper: fire a single ProximityPrompt
	local function firePrompt(obj)
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
	end

	-- Helper: collect prompts/detectors near a position from a pre-fetched list
	local function getNearbyPrompts(descendants, pos, radius)
		local prompts, detectors = {}, {}
		for _, obj in ipairs(descendants) do
			pcall(function()
				if obj:IsA("ProximityPrompt") then
					local p = obj.Parent
					if p and p:IsA("BasePart") and (p.Position - pos).Magnitude < radius then
						table.insert(prompts, obj)
					end
				elseif obj:IsA("ClickDetector") then
					local p = obj.Parent
					if p and p:IsA("BasePart") and (p.Position - pos).Magnitude < radius then
						table.insert(detectors, obj)
					end
				end
			end)
		end
		return prompts, detectors
	end

	uiBuilder.createButton(tab, "TP to Broadcast Room + Open Console", o(), function()
		local char = LocalPlayer.Character
		if not char then return end
		local hrp = helpers.getRoot()
		if not hrp then return end

		-- Lightweight noclip - only root parts, not every descendant
		local tempNoclip = RunService.Stepped:Connect(function()
			pcall(function()
				local c = LocalPlayer.Character
				if not c then return end
				local h = c:FindFirstChild("HumanoidRootPart")
				if h then h.CanCollide = false end
				local t = c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
				if t then t.CanCollide = false end
			end)
		end)

		-- Single GetDescendants call - cache and reuse
		local allDesc = workspace:GetDescendants()

		-- Search for broadcast/announcement room
		local searchTerms = {"broadcast", "broadcasting", "announc", "alert room",
			"alert system", "static alert", "control tablet",
			"announcement center", "pirate transmission"}
		local found = nil
		for _, obj in ipairs(allDesc) do
			if found then break end
			pcall(function()
				if obj:IsA("BasePart") or obj:IsA("Model") then
					local n = obj.Name:lower()
					for _, term in ipairs(searchTerms) do
						if n:find(term, 1, true) then
							found = obj
							return
						end
					end
				end
			end)
		end

		if not found then
			found = actions.findLocationByName("SCC") or actions.findLocationByName("Strategic") or actions.findLocationByName("Executive")
		end

		if found then
			local pos = actions.getLocationPosition(found)
			if not pos and found:IsA("BasePart") then pos = found.Position + Vector3.new(0, 3, 0) end
			if pos then
				char:PivotTo(CFrame.new(pos))
				helpers.notify("Teleport", "TP to: " .. found.Name)
			end
		else
			helpers.notify("Error", "Broadcast Room not found")
		end

		-- Wait then fire nearby prompts (reuse cached descendants)
		task.wait(0.5)
		hrp = helpers.getRoot()
		if hrp then
			local prompts, detectors = getNearbyPrompts(allDesc, hrp.Position, 50)
			for _, p in ipairs(prompts) do
				firePrompt(p)
				print("[SX NBTF] Fired prompt: " .. p.Parent.Name)
			end
			for _, d in ipairs(detectors) do
				pcall(function() if fireclickdetector then fireclickdetector(d) end end)
				print("[SX NBTF] Fired click: " .. d.Parent.Name)
			end
			local total = #prompts + #detectors
			if total > 0 then
				helpers.notify("Announce", "Fired " .. total .. " prompts - check your screen!")
			else
				helpers.notify("Announce", "No prompts nearby - walk up to the console")
			end
		end

		-- Disable noclip after 3 seconds
		task.delay(3, function() pcall(function() tempNoclip:Disconnect() end) end)
	end)

	uiBuilder.createButton(tab, "Fire ALL Nearby Prompts (within 30m)", o(), function()
		local hrp = helpers.getRoot()
		if not hrp then helpers.notify("Error", "No character") return end
		local prompts, detectors = getNearbyPrompts(workspace:GetDescendants(), hrp.Position, 30)
		for _, p in ipairs(prompts) do
			firePrompt(p)
			print("[SX NBTF] Fired: " .. p.Parent.Name .. " [" .. (p.ActionText ~= "" and p.ActionText or p.ObjectText) .. "]")
		end
		for _, d in ipairs(detectors) do
			pcall(function() if fireclickdetector then fireclickdetector(d) end end)
			print("[SX NBTF] Fired click: " .. d.Parent.Name)
		end
		helpers.notify("Prompts", "Fired " .. (#prompts + #detectors) .. " nearby prompts/detectors")
	end)

	uiBuilder.createButton(tab, "List ALL Prompts Near You (F9)", o(), function()
		local hrp = helpers.getRoot()
		if not hrp then helpers.notify("Error", "No character") return end
		print("=== PROMPTS WITHIN 100m ===")
		local prompts, detectors = getNearbyPrompts(workspace:GetDescendants(), hrp.Position, 100)
		for _, obj in ipairs(prompts) do
			pcall(function()
				local dist = (obj.Parent.Position - hrp.Position).Magnitude
				print(math.floor(dist) .. "m | " .. obj.Parent:GetFullName()
					.. " | Action: " .. obj.ActionText
					.. " | Object: " .. obj.ObjectText
					.. " | Enabled: " .. tostring(obj.Enabled)
					.. " | Hold: " .. tostring(obj.HoldDuration) .. "s")
			end)
		end
		for _, obj in ipairs(detectors) do
			pcall(function()
				local dist = (obj.Parent.Position - hrp.Position).Magnitude
				print(math.floor(dist) .. "m | ClickDetector: " .. obj.Parent:GetFullName())
			end)
		end
		print("=== " .. (#prompts + #detectors) .. " PROMPTS FOUND ===")
		helpers.notify("Debug", (#prompts + #detectors) .. " prompts/detectors printed to F9")
	end)

	uiBuilder.createSpacer(tab, o())

	-- Keep the custom announcement for fun / local display
	uiBuilder.createSectionLabel(tab, "Custom Announcement (Local Only)", o())
	local announcementText = "Alert: All personnel report to SCC immediately"
	uiBuilder.createInput(tab, "Announcement Text", "Type announcement here...", function(value)
		announcementText = value
	end)

	local selectedProtocol = "alert"
	uiBuilder.createDropdown(tab, "Announcement Protocol",
		{"Normal", "Alert", "Lockdown", "Core"}, "Alert", function(choice)
			selectedProtocol = string.lower(choice)
		end)
	uiBuilder.createButton(tab, "Show Local Announcement", o(), function()
		actions.showCustomAnnouncement(announcementText, selectedProtocol, 8)
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "GUI & Remote Debug", o())

	uiBuilder.createButton(tab, "Force Show ALL Hidden GUIs", o(), function()
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
		helpers.notify("GUIs", "Enabled/unhidden/cloned " .. count .. " elements")
	end)

	uiBuilder.createButton(tab, "Dump ALL GUIs to F9", o(), function()
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
		helpers.notify("Debug", "Full GUI scan printed to F9 console")
	end)

	uiBuilder.createButton(tab, "List All Remotes (F9)", o(), function()
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
		helpers.notify("Remotes", "Printed to F9 console")
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Rank Change", o())
	uiBuilder.createInfoLabel(tab, "Searches for rank/role remotes (may be patched)", o())

	uiBuilder.createButton(tab, "Try Change Rank (prints result to F9)", o(), function()
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
				helpers.notify("Rank", "No rank remote found - likely patched")
			else
				helpers.notify("Rank", "Fired rank remotes - check if it worked")
			end
		end)
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Chat Commands", o())
	local chatText = ""
	uiBuilder.createInput(tab, "Chat Message", "Type chat message...", function(value)
		chatText = value
	end)

	uiBuilder.createButton(tab, "Send Chat Message", o(), function()
		if chatText ~= "" then
			helpers.sendChatMessage(chatText)
			helpers.notify("Chat", "Sent: " .. chatText)
		end
	end)
	uiBuilder.createInfoLabel(tab, "Sends via TextChatService or legacy SayMessageRequest", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Anti-Aim", o())
	uiBuilder.createToggle(tab, "Anti-Aim (Spin to Dodge)", o(), function(on)
		combatState.antiAimActive = on
		if on then startAntiAim() else stopAntiAim() end
	end)
	uiBuilder.createInfoLabel(tab, "Rapidly spins your character to make you harder to hit", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Quick Actions", o())
	uiBuilder.createButton(tab, "Auto-Equip Best Gun", o(), function()
		local gun = helpers.findGunInBackpack()
		if gun then
			helpers.equipGun(gun)
			helpers.notify("Equip", "Equipped: " .. gun.Name)
		else
			helpers.notify("Error", "No gun found in backpack!")
		end
	end)
	uiBuilder.createButton(tab, "Drop All Weapons", o(), function()
		pcall(function()
			local hum = helpers.getHumanoid()
			if hum then hum:UnequipTools() end
		end)
		helpers.notify("Weapons", "All weapons unequipped")
	end)
end

-- ===================== BUILD MOVEMENT TAB =====================
do
	local tab = tabFrames["Movement"]
	local n = 0
	local function o() n = n + 1 return n end

	uiBuilder.createSectionLabel(tab, "Flight", o())
	uiBuilder.createToggle(tab, "Fly (WASD + Space/Shift)", o(), function(on)
		moveState.flyActive = on
		if on then startFly() else stopFly() end
	end)
	uiBuilder.createSlider(tab, "Fly Speed", 10, 300, moveState.flySpeed, o(), function(val) moveState.flySpeed = val end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Vehicle Fly", o())
	uiBuilder.createToggle(tab, "Vehicle Fly (Sit in Vehicle First)", o(), function(on)
		moveState.vehicleFlyActive = on
		if on then startVehicleFly() else stopVehicleFly() end
	end)
	uiBuilder.createSlider(tab, "Vehicle Fly Speed", 20, 800, moveState.vehicleFlySpeed, o(), function(val) moveState.vehicleFlySpeed = val end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Vehicle Noclip", o())
	uiBuilder.createToggle(tab, "Vehicle Noclip", o(), function(on)
		moveState.carNoclipActive = on
		if on then startCarNoclip() else stopCarNoclip() end
	end)
	uiBuilder.createInfoLabel(tab, "Drive through walls. Altitude is held so it will not sink.", o())
	uiBuilder.createToggle(tab, "Noclip Anti-Sink", o(), function(on)
		moveState.noclipAntiSink = on
		moveState.noclipFloor = {}
	end)
	uiBuilder.createInfoLabel(tab, "Holds your height while noclipping. Turn off to descend.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Backseat Drive", o())
	uiBuilder.createToggle(tab, "Backseat Drive (Any Seat)", o(), function(on)
		moveState.backseatDriveActive = on
		if on then startBackseatDrive() else stopBackseatDrive() end
	end)
	uiBuilder.createSlider(tab, "Backseat Drive Speed", 20, 400, moveState.backseatDriveSpeed, o(), function(val) moveState.backseatDriveSpeed = val end)
	uiBuilder.createInfoLabel(tab, "Drive from a passenger seat. Steers with the camera.", o())
	uiBuilder.createInfoLabel(tab, "Fly the vehicle from any seat, including passenger seats", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Car Speed Boost", o())
	uiBuilder.createToggle(tab, "Car Speed Boost (Sit First)", o(), function(on)
		moveState.carSpeedActive = on
		if on then startCarSpeed() else stopCarSpeed() end
	end)
	uiBuilder.createSlider(tab, "Car Speed Value", 50, 1000, moveState.carSpeedValue, o(), function(val) moveState.carSpeedValue = val end)
	uiBuilder.createInfoLabel(tab, "Raises the vehicle's MaxSpeed + Torque for real acceleration", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Car Fling", o())
	uiBuilder.createToggle(tab, "Car Fling (Sit First)", o(), function(on)
		moveState.carFlingActive = on
		if on then startCarFling() else stopCarFling() end
	end)
	uiBuilder.createSlider(tab, "Car Fling Power", 1000, 100000, moveState.carFlingPower, o(), function(val) moveState.carFlingPower = val end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Walk Fling", o())
	uiBuilder.createToggle(tab, "Walk Fling", o(), function(on)
		moveState.walkFlingActive = on
		if on then startWalkFling() else stopWalkFling() end
	end)
	uiBuilder.createInfoLabel(tab, "NBTF has no player-to-player collision, so this cannot fling here. Use Car Fling.", o())
	uiBuilder.createInfoLabel(tab, "Drive into people to launch them. Must be moving.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Speed", o())
	uiBuilder.createToggle(tab, "Speed Boost", o(), function(on)
		moveState.speedBoostActive = on
		if on then startSpeedBoost() else stopSpeedBoost() end
	end)
	uiBuilder.createSlider(tab, "Speed Value", 20, 300, moveState.speedValue, o(), function(val) moveState.speedValue = val end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Other", o())
	uiBuilder.createToggle(tab, "Noclip (Walk Through Walls)", o(), function(on)
		moveState.noclipActive = on
		if on then startNoclip() else stopNoclip() end
	end)
	uiBuilder.createToggle(tab, "Infinite Jump", o(), function(on)
		moveState.infJumpActive = on
		if on then helpers.notify("Inf Jump", "Active!") end
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "World", o())
	uiBuilder.createSlider(tab, "Gravity", 0, 500, math.floor(moveState.gravityValue), o(), function(val)
		moveState.gravityValue = val
		actions.setGravity(val)
	end)
	uiBuilder.createInfoLabel(tab, "Default: 196. Lower = moon gravity. 0 = float.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "AFK & Protection", o())
	uiBuilder.createToggle(tab, "Anti-AFK (Prevent Idle Kick)", o(), function(on)
		miscState.antiAfkActive = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)
	uiBuilder.createToggle(tab, "Anti-Kick (Block Server Kicks)", o(), function(on)
		miscState.antiKickActive = on
		if on then startAntiKick() end
	end)
	uiBuilder.createInfoLabel(tab, "Disables Idled + hooks Kick method (needs executor support)", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Advanced Movement", o())
	uiBuilder.createToggle(tab, "Bunny Hop (Auto-Jump While Moving)", o(), function(on)
		moveState.bunnyHopActive = on
		if on then startBunnyHop() else stopBunnyHop() end
	end)
	uiBuilder.createButton(tab, "Long Jump (Launch Forward)", o(), function() actions.doLongJump() end)
	uiBuilder.createSlider(tab, "Long Jump Power", 50, 400, moveState.longJumpPower, o(), function(val) moveState.longJumpPower = val end)
	uiBuilder.createSlider(tab, "Jump Power", 50, 400, miscState.jumpPowerValue, o(), function(val)
		miscState.jumpPowerValue = val
		if val > 50 then startJumpPower() else stopJumpPower() end
	end)
	uiBuilder.createInfoLabel(tab, "Raise above 50 to jump higher. Reapplied after respawn.", o())
	uiBuilder.createInfoLabel(tab, "Bunny hop auto-jumps for max speed. Long jump launches you forward.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Teleport Tools", o())
	uiBuilder.createButton(tab, "TP Forward", o(), function() actions.tpForward() end)
	uiBuilder.createSlider(tab, "TP Distance (studs)", 10, 200, playerState.tpForwardDist, o(), function(val) playerState.tpForwardDist = val end)
	uiBuilder.createButton(tab, "TP to Mouse Click Position", o(), function() actions.tpToMouse() end)
	uiBuilder.createInfoLabel(tab, "TP Forward moves in facing direction. Mouse TP goes to cursor.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Camera", o())
	uiBuilder.createToggle(tab, "Freecam (Detach Camera)", o(), function(on)
		playerState.freecamActive = on
		if on then startFreecam() else stopFreecam() end
	end)
	uiBuilder.createInfoLabel(tab, "WASD + Space/Shift to move camera freely. Character stays still.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Saved Positions", o())
	uiBuilder.createButton(tab, "Save Current Position (Slot 1)", o(), function() actions.savePosition("slot1") end)
	uiBuilder.createButton(tab, "Save Current Position (Slot 2)", o(), function() actions.savePosition("slot2") end)
	uiBuilder.createButton(tab, "Save Current Position (Slot 3)", o(), function() actions.savePosition("slot3") end)
	uiBuilder.createButton(tab, "Load Position (Slot 1)", o(), function() actions.loadPosition("slot1") end)
	uiBuilder.createButton(tab, "Load Position (Slot 2)", o(), function() actions.loadPosition("slot2") end)
	uiBuilder.createButton(tab, "Load Position (Slot 3)", o(), function() actions.loadPosition("slot3") end)
	uiBuilder.createInfoLabel(tab, "Save your position and teleport back anytime", o())
end

-- ===================== BUILD VISUALS TAB =====================
do
	local tab = tabFrames["Visuals"]
	local n = 0
	local function o() n = n + 1 return n end

	uiBuilder.createSectionLabel(tab, "ESP", o())
	uiBuilder.createToggle(tab, "Player ESP (Names/Health/Distance)", o(), function(on)
		espState.espActive = on
		if on then startESP() else clearESP() end
	end)
	uiBuilder.createInfoLabel(tab, "Blue = Facility, Red = Rebel. Shows role + weapon.", o())
	uiBuilder.createToggle(tab, "Chams (See Players Through Walls)", o(), function(on)
		espState.chamsActive = on
		if on then startChams() else stopChams() end
	end)
	uiBuilder.createToggle(tab, "Vehicle ESP", o(), function(on)
		espState.vehicleEspActive = on
		if on then startVehicleEsp() else stopVehicleEsp() end
	end)
	uiBuilder.createToggle(tab, "X-Ray (See Through Walls)", o(), function(on)
		espState.xrayActive = on
		if on then startXray() else stopXray() end
	end)
	uiBuilder.createInfoLabel(tab, "X-Ray fades large map parts. Re-toggle after moving areas.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Camera", o())
	uiBuilder.createSlider(tab, "Field of View", 40, 120, 70, o(), function(val)
		pcall(function() camera.FieldOfView = val end)
	end)
	uiBuilder.createSlider(tab, "Max Zoom Distance", 10, 800, 128, o(), function(val)
		pcall(function() LocalPlayer.CameraMaxZoomDistance = val end)
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Lighting", o())
	uiBuilder.createToggle(tab, "Fullbright (Remove Darkness)", o(), function(on)
		espState.fullbrightActive = on
		if on then enableFullbright() else disableFullbright() end
	end)
	uiBuilder.createInfoLabel(tab, "Max brightness, no fog, no shadows", o())
	uiBuilder.createToggle(tab, "No Fog (Remove Fog Only)", o(), function(on)
		espState.noFogActive = on
		if on then enableNoFog() else disableNoFog() end
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Overlays (Requires Drawing API)", o())
	uiBuilder.createToggle(tab, "Tracers (Lines to Enemies)", o(), function(on)
		espState.tracersActive = on
		if on then startTracers() end
	end)
	uiBuilder.createToggle(tab, "FOV Circle (Show Aim FOV)", o(), function(on)
		espState.fovCircleActive = on
		if on then
			createFOVCircle()
			task.spawn(function()
				while espState.fovCircleActive do updateFOVCircle() task.wait(0.03) end
				removeFOVCircle()
			end)
		else
			removeFOVCircle()
		end
	end)
	uiBuilder.createToggle(tab, "Crosshair Overlay", o(), function(on)
		espState.crosshairActive = on
		if on then createCrosshair() else removeCrosshair() end
	end)
	uiBuilder.createInfoLabel(tab, "Tracers/FOV/Crosshair need Drawing API (most executors)", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Item ESP", o())
	uiBuilder.createToggle(tab, "Item / Weapon ESP (Ground Items)", o(), function(on)
		espState.itemEspActive = on
		if on then startItemESP() else clearItemESP() end
	end)
	uiBuilder.createInfoLabel(tab, "Highlights dropped weapons/tools/crates on the ground", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Character", o())
	uiBuilder.createToggle(tab, "Invisible (Client-Side)", o(), function(on)
		playerState.invisibleActive = on
		if on then startInvisible() else stopInvisible() end
	end)
	uiBuilder.createInfoLabel(tab, "Makes your character invisible locally (others still see you)", o())
end

-- ===================== BUILD TELEPORT TAB =====================
do
	local tab = tabFrames["Teleport"]
	local n = 0
	local function o() n = n + 1 return n end

	uiBuilder.createSectionLabel(tab, "Secret / Special Locations", o())
	uiBuilder.createButton(tab, "TP: Mod Room / Regular Lounge", o(), function()
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
				helpers.notify("Teleport", "Found: " .. found.Name)
				return
			end
		end
		-- Fallback: try Maintenance
		local maint = actions.findLocationByName("Maintenance")
		if maint then
			local pos = actions.getLocationPosition(maint)
			if pos then
				char:PivotTo(CFrame.new(pos))
				helpers.notify("Teleport", "TP to Maintenance (Mod Room behind it on canyon wall)")
				return
			end
		end
		helpers.notify("Error", "Not found - click 'Print Workspace Names' and check F9")
	end)
	uiBuilder.createButton(tab, "Print Workspace Names (F9)", o(), function()
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
		helpers.notify("Debug", "Workspace names printed to F9 console")
	end)
	uiBuilder.createInfoLabel(tab, "Behind Maintenance Offices on the Canyon Wall", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Facility Locations (Auto-Scanned)", o())
	uiBuilder.createInfoLabel(tab, "Scans workspace for named areas - click Scan to find them", o())

	-- Location list container
	-- Was a button per location; a dropdown holds an unbounded scan result
	-- without pushing the rest of the tab off-screen.
	local locationsByName = {}
	local locationDropdown
	local function refreshLocations()
		local locations = actions.scanLocations()
		locationsByName = {}
		local names = {}
		for _, loc in ipairs(locations) do
			locationsByName[loc.name] = loc.pos
			table.insert(names, loc.name)
		end
		if #names == 0 then
			helpers.notify("Scan", "No named locations found in workspace")
			return
		end
		if locationDropdown then
			pcall(function() locationDropdown:SetValues(names) end)
		end
		helpers.notify("Scan", "Found " .. #names .. " locations!")
	end

	locationDropdown = uiBuilder.createDropdown(tab, "Facility Location", {"(scan first)"}, "(scan first)", function(choice)
		local pos = locationsByName[choice]
		if not pos then return end
		local char = LocalPlayer.Character
		if char then
			char:PivotTo(CFrame.new(pos))
			helpers.notify("Teleport", choice)
		end
	end)

	uiBuilder.createButton(tab, "Scan Facility Locations", o(), refreshLocations)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Player Teleport", o())
	uiBuilder.createInfoLabel(tab, "Click a player name to teleport to them", o())

	-- Dynamic player list buttons
	-- A dropdown rebuilt on refresh, rather than one button per player: the
	-- old list grew without bound in a full server.
	local tpTargets, tpDropdown = {}, nil
	local function refreshPlayerList()
		tpTargets = {}
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local _, roleName, teamName = helpers.getPlayerTeamInfo(player)
				local suffix = roleName ~= "" and (" [" .. roleName .. "]")
					or (teamName ~= "" and (" [" .. teamName .. "]") or "")
				local label = player.DisplayName .. suffix
				tpTargets[label] = player.Name
				table.insert(names, label)
			end
		end
		if #names == 0 then names = {"(no players)"} end
		if tpDropdown then pcall(function() tpDropdown:SetValues(names) end) end
	end

	tpDropdown = uiBuilder.createDropdown(tab, "Teleport Target", {"(refresh first)"}, "(refresh first)", function(choice)
		local name = tpTargets[choice]
		if name then actions.teleportToPlayer(name) end
	end)
	uiBuilder.createButton(tab, "Refresh Player List", o(), refreshPlayerList)
	refreshPlayerList()

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Spectate", o())
	uiBuilder.createInfoLabel(tab, "Click a player above to TP, or use buttons below to spectate", o())

	-- Spectate player list
	local specTargets, specDropdown = {}, nil
	local function refreshSpecList()
		specTargets = {}
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				specTargets[player.DisplayName] = player
				table.insert(names, player.DisplayName)
			end
		end
		if #names == 0 then names = {"(no players)"} end
		if specDropdown then pcall(function() specDropdown:SetValues(names) end) end
	end

	specDropdown = uiBuilder.createDropdown(tab, "Spectate Target", {"(refresh first)"}, "(refresh first)", function(choice)
		local player = specTargets[choice]
		if player then actions.spectatePlayer(player) end
	end)
	uiBuilder.createButton(tab, "Stop Spectating", o(), actions.unspectate)
	uiBuilder.createButton(tab, "Refresh Spectate List", o(), refreshSpecList)
	refreshSpecList()
end

-- ===================== BUILD PLAYERS TAB =====================
do
	local tab = tabFrames["Players"]
	local n = 0
	local function o() n = n + 1 return n end

	uiBuilder.createSectionLabel(tab, "Player Actions", o())
	uiBuilder.createInfoLabel(tab, "Per-player actions: Kill, Bring, Teleport, Spectate", o())

	-- Was a row per player, each with four inline buttons at fixed pixel
	-- offsets, which does not survive a variable-width window. One dropdown
	-- selects the target and the buttons act on that selection.
	local actionTargets, selectedTarget, actionDropdown = {}, nil, nil
	local function refreshPlayerActions()
		actionTargets = {}
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local _, roleName, teamName = helpers.getPlayerTeamInfo(player)
				local suffix = roleName ~= "" and (" [" .. roleName .. "]")
					or (teamName ~= "" and (" [" .. teamName .. "]") or "")
				local label = player.DisplayName .. suffix
				actionTargets[label] = player
				table.insert(names, label)
			end
		end
		if #names == 0 then names = {"(no players)"} end
		if actionDropdown then pcall(function() actionDropdown:SetValues(names) end) end
	end

	actionDropdown = uiBuilder.createDropdown(tab, "Target Player", {"(refresh first)"}, "(refresh first)", function(choice)
		selectedTarget = actionTargets[choice]
	end)

	local function withTarget(fn)
		return function()
			if not selectedTarget or not selectedTarget.Parent then
				helpers.notify("Error", "Pick a target from the dropdown first")
				return
			end
			fn(selectedTarget)
		end
	end

	uiBuilder.createButton(tab, "Kill Target", o(), withTarget(function(player)
		local gun = helpers.findGunInBackpack()
		if not gun then
			helpers.notify("Error", "No gun found! Equip a weapon first.")
			return
		end
		if not helpers.isAlive(player) then
			helpers.notify("Error", player.DisplayName .. " is dead or not in game")
			return
		end
		helpers.equipGun(gun)
		task.spawn(function()
			for _ = 1, 3 do
				fireWeaponHit(player, gun, "aim")
				task.wait(combatState.killAllDelay)
			end
			helpers.notify("Kill", "Fired at " .. player.DisplayName)
		end)
	end))

	uiBuilder.createButton(tab, "Bring Target", o(), withTarget(function(player)
		actions.bringPlayer(player)
	end))

	uiBuilder.createButton(tab, "Teleport To Target", o(), withTarget(function(player)
		actions.teleportToPlayer(player.Name)
	end))

	uiBuilder.createButton(tab, "Spectate Target", o(), withTarget(function(player)
		actions.spectatePlayer(player)
	end))

	uiBuilder.createButton(tab, "Refresh Player List", o(), refreshPlayerActions)
	refreshPlayerActions()

	-- Auto-refresh on player join/leave
	Players.PlayerAdded:Connect(function() task.wait(1) refreshPlayerActions() end)
	Players.PlayerRemoving:Connect(function() task.wait(0.5) refreshPlayerActions() end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Target Info", o())
	local targetInfoLabel = uiBuilder.createDynamicLabel(tab, "No target - enable Silent Aim or Aimbot")

	-- Update target info periodically
	task.spawn(function()
		while task.wait(1) do
			pcall(function()
				if not aimState.silentAimActive and not aimState.aimbotActive then
					targetInfoLabel.Text = "No target - enable Silent Aim or Aimbot"
					targetInfoLabel.TextColor3 = COLORS.textSecondary
					return
				end
				local target = helpers.getClosestPlayerInFOV()
				if not target then target = helpers.getClosestPlayer3D() end
				if target and target.Parent then
					local p = Players:GetPlayerFromCharacter(target.Parent)
					if p then
						local hum = target.Parent:FindFirstChildOfClass("Humanoid")
						local hp = hum and math.floor((hum.Health / hum.MaxHealth) * 100) or 0
						local myRoot = helpers.getRoot()
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

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createButton(tab, "Stop Spectating", o(), actions.unspectate)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Orbit / Follow", o())

	-- Orbit player list
	local orbitTargets, orbitDropdown = {}, nil
	local function refreshOrbitList()
		orbitTargets = {}
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				orbitTargets[player.DisplayName] = player
				table.insert(names, player.DisplayName)
			end
		end
		if #names == 0 then names = {"(no players)"} end
		if orbitDropdown then pcall(function() orbitDropdown:SetValues(names) end) end
	end

	local orbitSelected = nil
	orbitDropdown = uiBuilder.createDropdown(tab, "Orbit / Follow Target", {"(refresh first)"}, "(refresh first)", function(choice)
		orbitSelected = orbitTargets[choice]
	end)
	uiBuilder.createButton(tab, "Orbit Selected", o(), function()
		if orbitSelected then startOrbit(orbitSelected) else helpers.notify("Error", "Pick a target first") end
	end)
	uiBuilder.createButton(tab, "Follow Selected", o(), function()
		if orbitSelected then startAttach(orbitSelected) else helpers.notify("Error", "Pick a target first") end
	end)
	uiBuilder.createButton(tab, "Refresh Orbit/Follow List", o(), refreshOrbitList)
	uiBuilder.createButton(tab, "Stop Orbit / Follow", o(), function()
		stopOrbit()
		stopAttach()
		helpers.notify("Stopped", "No longer orbiting or following")
	end)
	uiBuilder.createSlider(tab, "Orbit Radius (studs)", 5, 50, playerState.orbitRadius, o(), function(val) playerState.orbitRadius = val end)
	uiBuilder.createSlider(tab, "Orbit Speed", 1, 10, playerState.orbitSpeed, o(), function(val) playerState.orbitSpeed = val end)
	uiBuilder.createInfoLabel(tab, "Orbit circles around them. Follow stays behind them.", o())

	refreshOrbitList()
end

-- ===================== BUILD MISC TAB =====================
do
	local tab = tabFrames["Misc"]
	local n = 0
	local function o() n = n + 1 return n end

	uiBuilder.createSectionLabel(tab, "Utility", o())
	uiBuilder.createToggle(tab, "Auto Interact (Doors / Pickups)", o(), function(on)
		miscState.autoInteractActive = on
		if on then startAutoInteract() else stopAutoInteract() end
	end)
	uiBuilder.createSlider(tab, "Auto Interact Range", 5, 80, miscState.autoInteractRange, o(), function(val)
		miscState.autoInteractRange = val
	end)
	uiBuilder.createInfoLabel(tab, "Fires nearby prompts continuously as you move.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Protection", o())
	uiBuilder.createToggle(tab, "Anti-Fling (Clamp Velocity Spikes)", o(), function(on)
		miscState.antiFlingActive = on
		if on then startAntiFling() else stopAntiFling() end
	end)
	uiBuilder.createToggle(tab, "Anti-Void (Return From Falls)", o(), function(on)
		miscState.antiVoidActive = on
		if on then startAntiVoid() else stopAntiVoid() end
	end)
	uiBuilder.createInfoLabel(tab, "Anti-Fling blocks others flinging you. Anti-Void restores your last safe spot.", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Chat Spy", o())
	uiBuilder.createToggle(tab, "Chat Spy (Log All Chat to F9)", o(), function(on)
		miscState.chatSpyActive = on
		if on then startChatSpy() else stopChatSpy() end
	end)
	uiBuilder.createInfoLabel(tab, "Logs all chat messages to F9 console", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Join / Leave Notifications", o())
	uiBuilder.createToggle(tab, "Player Join/Leave Alerts", o(), function(on)
		miscState.joinNotifyActive = on
		if on then startJoinNotify() else stopJoinNotify() end
	end)
	uiBuilder.createInfoLabel(tab, "Notification + F9 log when players join/leave", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Auto Respawn", o())
	uiBuilder.createToggle(tab, "Auto Respawn on Death", o(), function(on)
		miscState.autoRespawnActive = on
		if on then
			helpers.notify("Auto Respawn", "Will auto-respawn when you die")
		end
	end)
	uiBuilder.createInfoLabel(tab, "Clicks respawn button or loads character on death", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Player Count", o())
	local playerCountLabel = uiBuilder.createDynamicLabel(tab, "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers)

	task.spawn(function()
		while task.wait(5) do
			pcall(function()
				playerCountLabel.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
			end)
		end
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "FPS Display", o())
	local fpsLabel = uiBuilder.createDynamicLabel(tab, "FPS: --")

	task.spawn(function()
		while task.wait(1) do
			pcall(function()
				local fps = math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1/240))
				fpsLabel.Text = "FPS: " .. fps
				if fps >= 50 then
					fpsLabel.TextColor3 = COLORS.success
				elseif fps >= 30 then
					fpsLabel.TextColor3 = COLORS.warning
				else
					fpsLabel.TextColor3 = COLORS.error
				end
			end)
		end
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Workspace Scanner", o())
	uiBuilder.createButton(tab, "Print All Teams (F9)", o(), function()
		print("=== TEAMS ===")
		pcall(function()
			for _, team in ipairs(game:GetService("Teams"):GetTeams()) do
				local count = #team:GetPlayers()
				print("  [" .. team.Name .. "] Color: " .. tostring(team.TeamColor) .. " | " .. count .. " players")
			end
		end)
		helpers.notify("Teams", "Printed to F9")
	end)
	uiBuilder.createButton(tab, "Print All Sounds (F9)", o(), function()
		print("=== SOUNDS IN WORKSPACE ===")
		local count = 0
		pcall(function()
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("Sound") then
					count = count + 1
					print("  [Sound] " .. obj:GetFullName() .. " ID=" .. tostring(obj.SoundId) .. " Playing=" .. tostring(obj.Playing))
				end
			end
		end)
		print("=== " .. count .. " SOUNDS ===")
		helpers.notify("Sounds", count .. " sounds found - F9")
	end)
	uiBuilder.createButton(tab, "Print Leaderstats (F9)", o(), function()
		print("=== YOUR LEADERSTATS ===")
		pcall(function()
			local ls = LocalPlayer:FindFirstChild("leaderstats")
			if ls then
				for _, stat in ipairs(ls:GetChildren()) do
					print("  " .. stat.Name .. " = " .. tostring(stat.Value) .. " (" .. stat.ClassName .. ")")
				end
			else
				print("  No leaderstats found")
			end
		end)
		helpers.notify("Stats", "Printed to F9")
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Fun", o())
	uiBuilder.createButton(tab, "Seizure Mode (Flash Colors)", o(), function()
		task.spawn(function()
			local Lighting = game:GetService("Lighting")
			for i = 1, 30 do
				Lighting.Ambient = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
				Lighting.OutdoorAmbient = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
				task.wait(0.1)
			end
			Lighting.Ambient = Color3.fromRGB(0, 0, 0)
			Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
		end)
	end)
	uiBuilder.createButton(tab, "Tiny Character", o(), function()
		pcall(function()
			local char = LocalPlayer.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.HeadScale.Value = 0.5
					hum.BodyDepthScale.Value = 0.5
					hum.BodyWidthScale.Value = 0.5
					hum.BodyHeightScale.Value = 0.5
					helpers.notify("Fun", "Tiny mode!")
				end
			end
		end)
	end)
	uiBuilder.createButton(tab, "Giant Character", o(), function()
		pcall(function()
			local char = LocalPlayer.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.HeadScale.Value = 3
					hum.BodyDepthScale.Value = 3
					hum.BodyWidthScale.Value = 3
					hum.BodyHeightScale.Value = 3
					helpers.notify("Fun", "Giant mode!")
				end
			end
		end)
	end)
	uiBuilder.createButton(tab, "Normal Size", o(), function()
		pcall(function()
			local char = LocalPlayer.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.HeadScale.Value = 1
					hum.BodyDepthScale.Value = 1
					hum.BodyWidthScale.Value = 1
					hum.BodyHeightScale.Value = 1
					helpers.notify("Fun", "Normal size restored")
				end
			end
		end)
	end)
	uiBuilder.createButton(tab, "Dance (Emote)", o(), function()
		pcall(function()
			local hum = helpers.getHumanoid()
			if hum then
				local anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://507771019"
				local track = hum:LoadAnimation(anim)
				track:Play()
				task.delay(5, function() track:Stop() end)
			end
		end)
	end)
end

-- ===================== BUILD SETTINGS TAB =====================
do
	local tab = tabFrames["Settings"]
	local n = 0
	local function o() n = n + 1 return n end

	uiBuilder.createSectionLabel(tab, "Keybinds", o())
	uiBuilder.createInfoLabel(tab, "Right Shift = Toggle GUI window", o())
	uiBuilder.createInfoLabel(tab, "GUI is draggable (drag title bar)", o())

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Stealth Configuration", o())
	uiBuilder.createInfoLabel(tab, "Adjust cooldowns to balance stealth vs. effectiveness", o())
	uiBuilder.createSlider(tab, "Silent Aim Cooldown (x0.1s)", 1, 20, math.floor(aimState.silentAimCooldown * 10), o(), function(val)
		aimState.silentAimCooldown = val / 10
	end)
	uiBuilder.createSlider(tab, "Wallbang Cooldown (x0.1s)", 1, 20, math.floor(aimState.wallbangCooldown * 10), o(), function(val)
		aimState.wallbangCooldown = val / 10
	end)
	uiBuilder.createSlider(tab, "Kill All Delay (x0.1s)", 1, 10, math.floor(combatState.killAllDelay * 10), o(), function(val)
		combatState.killAllDelay = val / 10
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Server Info", o())
	local placeLabel = uiBuilder.createDynamicLabel(tab, "Place ID: " .. tostring(game.PlaceId))

	local jobLabel = uiBuilder.createDynamicLabel(tab, "Server ID: " .. tostring(game.JobId):sub(1, 20) .. "...")

	local playerCountLabel = uiBuilder.createDynamicLabel(tab, "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers)

	local localLabel = uiBuilder.createDynamicLabel(tab, "You: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")")

	-- Keep player count updated
	task.spawn(function()
		while task.wait(5) do
			pcall(function()
				playerCountLabel.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
			end)
		end
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "Server Actions", o())
	uiBuilder.createButton(tab, "Rejoin Server", o(), function()
		helpers.notify("Rejoin", "Teleporting...")
		pcall(function()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end)
	end)
	uiBuilder.createButton(tab, "Server Hop (Random Server)", o(), function()
		helpers.notify("Server Hop", "Finding new server...")
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
				helpers.notify("Error", "No available servers found")
			end)
		end)
	end)
	uiBuilder.createToggle(tab, "Auto-Rejoin on Kick", o(), function(on)
		miscState.autoRejoinActive = on
		if on then
			helpers.notify("Auto-Rejoin", "Will rejoin if kicked")
		end
	end)
	uiBuilder.createInfoLabel(tab, "Auto-rejoin attempts to reconnect when kicked", o())

	-- Setup auto-rejoin hooks
	pcall(function()
		game:GetService("GuiService").ErrorMessageChanged:Connect(function(msg)
			if miscState.autoRejoinActive and msg ~= "" then
				task.wait(3)
				pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
			end
		end)
	end)

	uiBuilder.createSpacer(tab, o())

	uiBuilder.createSectionLabel(tab, "About", o())
	uiBuilder.createInfoLabel(tab, "Pebbleford Hub - NBTF Hub v7.2", o())
	uiBuilder.createInfoLabel(tab, "Uses WeaponsSystem.Network.WeaponHit for combat", o())
	uiBuilder.createInfoLabel(tab, "Stealth mode with configurable cooldowns", o())
end

-- ===================== WINDOW VISIBILITY =====================
-- Rayfield owns the window chrome now: it draws its own minimise and close
-- controls, and its own mobile show button, so the hand-rolled toggle button,
-- drag handling and RightShift hook are gone. The keybind is declared as
-- ToggleUIKeybind on the window above.

-- ===================== RESPAWN HANDLER =====================
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	if moveState.flyActive then stopFly() task.wait(0.3) startFly() end
	if moveState.speedBoostActive then stopSpeedBoost() task.wait(0.3) startSpeedBoost() end
	if moveState.noclipActive then stopNoclip() task.wait(0.3) startNoclip() end
	if moveState.godModeActive then stopGodMode() task.wait(0.3) startGodMode() end
	if miscState.antiRagdollActive then stopAntiRagdoll() task.wait(0.3) startAntiRagdoll() end
	if combatState.infAmmoActive then actions.modGuns() end
	if combatState.noRecoilActive then actions.modGuns() end
	if moveState.bunnyHopActive then stopBunnyHop() task.wait(0.1) startBunnyHop() end
	if combatState.antiAimActive then stopAntiAim() task.wait(0.1) startAntiAim() end
	if playerState.invisibleActive then task.wait(0.5) startInvisible() end
end)

-- Setup auto respawn listener
setupAutoRespawn()

-- ===================== STARTUP =====================
helpers.notify("Pebbleford NBTF", "Loaded - Right Shift toggles the menu")
print("[SX NBTF v7.2] Pebbleford Hub - NBTF Hub v7.2")
print("[SX NBTF v7.2] Tabs: Aim | Combat | Movement | Visuals | Teleport | Players | Misc | Settings")
print("[SX NBTF v7.2] Uses WeaponsSystem.Network.WeaponHit for combat")
print("[SX NBTF v7.2] New: Kill Aura, Trigger Bot, Freecam, Tracers, FOV Circle, Chat Spy, Orbit + more")
