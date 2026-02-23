-- Key System Gate
local SXKeyURL = "https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/keysystem.lua?v=" .. tostring(tick())
local keyOk, keySystem = pcall(function() return loadstring(game:HttpGet(SXKeyURL))() end)
if not keyOk or not keySystem or not keySystem.validate() then return end

-- ================================================================
-- Synapse X The Revival - Elected Admin Hub v1.3
-- Tool-Based Mining | Admin Commands | Building | Sign Editor
-- Player Control | Teleports | ESP | Anti-Jail | Remote Spy
-- Game uses Red networking (ReliableRedEvent) + ReplicaService
-- ================================================================

print("[SX Elected v1.3] Script loaded - EditSign remote discovery")

-- Cleanup old instance
pcall(function()
	local old = game:GetService("CoreGui"):FindFirstChild("SXElected")
	if old then old:Destroy() end
end)
pcall(function()
	local old = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if old then
		local o2 = old:FindFirstChild("SXElected")
		if o2 then o2:Destroy() end
	end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===================== REMOTES =====================
-- This game uses Red networking library (ReliableRedEvent) for all game actions
-- and ReplicaService for state replication. There are NO individual MineEvent/BuildEvent/EditSignEvent remotes.
local RedEvent = nil -- ReplicatedStorage.ReliableRedEvent (main networking)
local ChatRemote = nil

-- Find the Red networking event
pcall(function()
	RedEvent = ReplicatedStorage:FindFirstChild("ReliableRedEvent")
end)

pcall(function()
	local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
	if chatEvents then ChatRemote = chatEvents:FindFirstChild("SayMessageRequest") end
end)

-- ===================== REMOTE SPY =====================
local remoteSpyActive = false
local remoteSpyHooks = {}

-- Deep print a table recursively for spy output
local function deepPrint(val, indent, visited)
	indent = indent or "  "
	visited = visited or {}

	if type(val) ~= "table" then
		if typeof(val) == "Instance" then
			return val.ClassName .. " '" .. val:GetFullName() .. "'"
		elseif type(val) == "string" then
			return '"' .. val:sub(1, 100) .. '"'
		else
			return tostring(val)
		end
	end

	-- Avoid infinite recursion
	if visited[val] then return "{...circular...}" end
	visited[val] = true

	local parts = {}
	local count = 0
	for k, v in pairs(val) do
		count = count + 1
		if count > 20 then
			table.insert(parts, indent .. "  ... (" .. count .. "+ entries)")
			break
		end
		local keyStr = type(k) == "number" and "[" .. k .. "]" or tostring(k)
		local valStr = deepPrint(v, indent .. "  ", visited)
		table.insert(parts, indent .. "  " .. keyStr .. " = " .. valStr)
	end

	if #parts == 0 then return "{}" end
	return "{\n" .. table.concat(parts, "\n") .. "\n" .. indent .. "}"
end

local function startRemoteSpy()
	remoteSpyActive = true
	print("[SX Elected] === REMOTE SPY STARTED ===")
	print("[SX Elected] Perform actions in-game and watch F9")

	-- Try multiple hooking methods in order of preference
	local hooked = false

	-- Method 1: hookmetamethod (best - catches all outgoing)
	pcall(function()
		if hookmetamethod and getnamecallmethod then
			local oldNamecall
			oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
				local method = getnamecallmethod()
				if remoteSpyActive and (method == "FireServer" or method == "InvokeServer") then
					print("[SPY-OUT] " .. method .. " -> " .. self:GetFullName())
					local args = {...}
					for i, arg in ipairs(args) do
						print("  arg" .. i .. " (" .. typeof(arg) .. "): " .. deepPrint(arg))
					end
				end
				return oldNamecall(self, ...)
			end)
			hooked = true
			print("[SX Elected] Spy: hookmetamethod active (full outgoing spy)")
		end
	end)

	-- Method 2: hookfunction on ReliableRedEvent.FireServer specifically
	if not hooked then
		pcall(function()
			if hookfunction and newcclosure and RedEvent then
				local oldFire = RedEvent.FireServer
				hookfunction(RedEvent.FireServer, newcclosure(function(self, ...)
					if remoteSpyActive then
						print("[SPY-OUT] ReliableRedEvent:FireServer()")
						local args = {...}
						for i, arg in ipairs(args) do
							print("  arg" .. i .. " (" .. typeof(arg) .. "): " .. deepPrint(arg))
						end
					end
					return oldFire(self, ...)
				end))
				hooked = true
				print("[SX Elected] Spy: hookfunction active (RedEvent outgoing spy)")
			end
		end)
	end

	-- Method 3: Listen to incoming events + deep print tables
	if not hooked then
		warn("[SX Elected] No outgoing hook available - incoming spy only")
		print("[SX Elected] TIP: Manually edit a sign and check what incoming data changes")
	end

	-- Always listen to incoming events with deep table printing
	pcall(function()
		if RedEvent then
			local conn = RedEvent.OnClientEvent:Connect(function(...)
				if remoteSpyActive then
					local args = {...}
					print("[SPY-IN] ReliableRedEvent received: " .. #args .. " args")
					for i, arg in ipairs(args) do
						print("  arg" .. i .. " (" .. typeof(arg) .. "): " .. deepPrint(arg))
					end
				end
			end)
			table.insert(remoteSpyHooks, function() conn:Disconnect() end)
		end
	end)

	-- Also spy on all other known remotes
	pcall(function()
		local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if remoteEvents then
			for _, remote in ipairs(remoteEvents:GetChildren()) do
				if remote:IsA("RemoteEvent") then
					local conn = remote.OnClientEvent:Connect(function(...)
						if remoteSpyActive then
							local args = {...}
							print("[SPY-IN] " .. remote.Name .. " received: " .. #args .. " args")
							for i, arg in ipairs(args) do
								print("  arg" .. i .. " (" .. typeof(arg) .. "): " .. deepPrint(arg))
							end
						end
					end)
					table.insert(remoteSpyHooks, function() conn:Disconnect() end)
				end
			end
		end
	end)
end

local function stopRemoteSpy()
	remoteSpyActive = false
	for _, cleanup in ipairs(remoteSpyHooks) do pcall(cleanup) end
	remoteSpyHooks = {}
	print("[SX Elected] === REMOTE SPY STOPPED ===")
end

-- TextChatService for modern chat
local TextChatService = nil
pcall(function() TextChatService = game:GetService("TextChatService") end)

-- ===================== CLICK SIMULATION =====================
local function mouse1click()
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	task.wait(0.05)
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- ===================== COLOR PALETTE (Adminium Purple Theme) =====================
local COLORS = {
	bg = Color3.fromRGB(18, 14, 24),
	bgSecondary = Color3.fromRGB(26, 20, 34),
	panel = Color3.fromRGB(40, 32, 52),
	accent = Color3.fromRGB(160, 80, 255),
	accentHover = Color3.fromRGB(185, 120, 255),
	textPrimary = Color3.fromRGB(245, 240, 255),
	textSecondary = Color3.fromRGB(160, 150, 180),
	textDim = Color3.fromRGB(110, 100, 130),
	border = Color3.fromRGB(55, 42, 70),
	toggleOn = Color3.fromRGB(160, 80, 255),
	toggleOff = Color3.fromRGB(70, 60, 80),
	error = Color3.fromRGB(255, 68, 68),
	success = Color3.fromRGB(68, 255, 68),
	warning = Color3.fromRGB(255, 200, 60),
	admin = Color3.fromRGB(255, 215, 0),
}

-- ===================== STATE =====================
local autoMineActive = false
local autoUpgradeActive = false
local flyActive = false
local noclipActive = false
local speedBoostActive = false
local infJumpActive = false
local godModeActive = false
local espActive = false
local antiJailActive = false
local antiFlingActive = false
local antiAfkActive = false
local fullbrightActive = false
local autoCommandActive = false
local chatSpamActive = false
local signSpamActive = false

local flySpeed = 60
local speedValue = 50
local mineSpeed = 0.1
local windowVisible = true
local activeTab = "Mining"

-- Connections
local flyConnection = nil
local flyBV = nil
local flyBG = nil
local noclipConnection = nil
local speedBV = nil
local speedConnection = nil
local godModeConnection = nil
local antiJailConnection = nil
local antiFlingConnection = nil
local espHighlights = {}

-- Track last jail position to detect jailing
local lastKnownPos = nil

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

local function getItemPosition(obj)
	if obj:IsA("Model") then
		local ok, cf = pcall(function() return obj:GetPivot() end)
		if ok and cf then return cf.Position end
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then return part.Position end
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return nil
end

local function getItemCFrame(obj)
	if obj:IsA("Model") then
		local ok, cf = pcall(function() return obj:GetPivot() end)
		if ok and cf then return cf end
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then return part.CFrame end
	elseif obj:IsA("BasePart") then
		return obj.CFrame
	end
	return nil
end

-- Fire all ProximityPrompts on an object
local function fireAllPrompts(obj)
	local targets = {}
	pcall(function()
		if obj:IsA("ProximityPrompt") then table.insert(targets, obj) end
	end)
	pcall(function()
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("ProximityPrompt") then table.insert(targets, child) end
		end
	end)
	for _, prompt in ipairs(targets) do
		pcall(function()
			local oldHold = prompt.HoldDuration
			local oldDist = prompt.MaxActivationDistance
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 9999
			pcall(function() if fireproximityprompt then fireproximityprompt(prompt) end end)
			pcall(function() prompt:InputHoldBegin() task.wait(0.05) prompt:InputHoldEnd() end)
			prompt.HoldDuration = oldHold
			prompt.MaxActivationDistance = oldDist
		end)
	end
end

-- Send a chat message (used for admin commands)
local function sendChat(text)
	local sent = false
	-- Try modern TextChatService first
	pcall(function()
		if TextChatService then
			local channel = TextChatService:FindFirstChild("TextChannels")
			if channel then
				local rbxGeneral = channel:FindFirstChild("RBXGeneral")
				if rbxGeneral then
					rbxGeneral:SendAsync(text)
					sent = true
				end
			end
		end
	end)
	-- Fallback to legacy chat remote
	if not sent then
		pcall(function()
			if ChatRemote then
				ChatRemote:FireServer(text, "All")
				sent = true
			end
		end)
	end
	if not sent then
		warn("[SX Elected] Could not send chat: no chat system found")
	end
end

-- Send admin command (prepends ; if needed)
local function sendAdminCmd(cmd)
	if cmd:sub(1, 1) ~= ";" then
		cmd = ";" .. cmd
	end
	sendChat(cmd)
end

-- ===================== AUTO MINE =====================
-- Tool-based mining: equips pickaxe, TPs to Adminium, activates tool rapidly
-- The game uses Red networking (ReliableRedEvent) - mining goes through the tool's LocalScript
-- which fires the proper Red event when the tool is activated near Adminium

local function findMiningTool()
	-- Search backpack for any pickaxe/mining tool
	local char = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local searchNames = {"pickaxe", "pick", "mine", "axe", "hammer", "drill", "tool"}

	-- Check equipped tools first
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				for _, keyword in ipairs(searchNames) do
					if n:find(keyword) then return tool end
				end
			end
		end
	end

	-- Check backpack
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				for _, keyword in ipairs(searchNames) do
					if n:find(keyword) then return tool end
				end
			end
		end
	end

	-- If no named mining tool found, return any tool from backpack
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then return tool end
		end
	end
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then return tool end
		end
	end

	return nil
end

local function equipTool(tool)
	if not tool then return end
	local char = LocalPlayer.Character
	local hum = getHumanoid()
	if not char or not hum then return end

	-- If tool is in backpack, equip it
	if tool.Parent == LocalPlayer:FindFirstChild("Backpack") then
		hum:EquipTool(tool)
		task.wait(0.1)
	end
end

local function findAdminium()
	-- Search workspace for Adminium
	local adminium = workspace:FindFirstChild("Adminium")
	if adminium then return adminium end

	-- Deep search
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name:lower():find("adminium") and (obj:IsA("Model") or obj:IsA("BasePart")) then
			return obj
		end
	end
	return nil
end

local function startAutoMine()
	autoMineActive = true

	task.spawn(function()
		local tool = findMiningTool()
		if tool then
			equipTool(tool)
			print("[SX Elected] Mining with tool: " .. tool.Name)
			notify("Auto Mine", "Mining with " .. tool.Name)
		else
			print("[SX Elected] No mining tool found - using click + ProximityPrompt only")
			notify("Auto Mine", "No tool found - using prompts + clicks")
		end

		-- Find Adminium
		local adminium = findAdminium()
		if adminium then
			print("[SX Elected] Found Adminium: " .. adminium:GetFullName())
		else
			print("[SX Elected] Adminium not found in workspace")
		end

		while autoMineActive do
			pcall(function()
				local char = LocalPlayer.Character
				local hrp = getRoot()
				local hum = getHumanoid()
				if not char or not hrp or not hum then return end

				-- Re-find adminium if needed
				if not adminium or not adminium.Parent then
					adminium = findAdminium()
				end

				-- Re-equip tool if it got unequipped
				tool = findMiningTool()
				if tool then equipTool(tool) end

				-- Fire ProximityPrompts on Adminium (works from any distance with fireproximityprompt)
				if adminium then
					fireAllPrompts(adminium)
				end

				-- Activate the tool (triggers the tool's LocalScript mining logic)
				if tool and tool.Parent == char then
					pcall(function() tool:Activate() end)
				end

				-- Also simulate a click
				mouse1click()
			end)
			task.wait(mineSpeed)
		end
	end)
end

local function stopAutoMine()
	autoMineActive = false
	notify("Auto Mine", "Stopped")
end

-- ===================== AUTO UPGRADE =====================
-- Automatically upgrades Adminium level when possible
-- Clicks upgrade buttons in the Adminium GUI

local function startAutoUpgrade()
	autoUpgradeActive = true
	task.spawn(function()
		while autoUpgradeActive do
			pcall(function()
				-- Search player GUI for upgrade buttons
				local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
				if playerGui then
					for _, gui in ipairs(playerGui:GetDescendants()) do
						if gui:IsA("TextButton") then
							local text = gui.Text:lower()
							if text:find("upgrade") or text:find("level up") then
								pcall(function()
									-- Simulate click on upgrade button
									gui.MouseButton1Click:Fire()
								end)
							end
						end
					end
				end
			end)
			task.wait(2)
		end
	end)
	notify("Auto Upgrade", "Upgrading when possible!")
end

local function stopAutoUpgrade()
	autoUpgradeActive = false
end

-- ===================== ADMIN COMMAND HELPERS =====================
-- These fire admin commands via chat. Only work if you ARE the elected admin.

local function adminKill(target) sendAdminCmd(";kill " .. target) end
local function adminFly(target) sendAdminCmd(";fly " .. target) end
local function adminBtools(target) sendAdminCmd(";btools " .. target) end
local function adminSpeed(target, val) sendAdminCmd(";speed " .. target .. " " .. tostring(val or 100)) end
local function adminJumpPower(target, val) sendAdminCmd(";jumppower " .. target .. " " .. tostring(val or 200)) end
local function adminGod(target) sendAdminCmd(";god " .. target) end
local function adminBring(target) sendAdminCmd(";bring " .. target) end
local function adminGoto(target) sendAdminCmd(";goto " .. target) end
local function adminTeleport(p1, p2) sendAdminCmd(";teleport " .. p1 .. " " .. p2) end
local function adminFling(target) sendAdminCmd(";fling " .. target) end
local function adminJail(target) sendAdminCmd(";jail " .. target) end
local function adminKick(target) sendAdminCmd(";kick " .. target) end
local function adminRespawn(target) sendAdminCmd(";respawn " .. target) end
local function adminNoclip(target) sendAdminCmd(";noclip " .. target) end
local function adminGun(target) sendAdminCmd(";gun " .. target) end
local function adminSword(target) sendAdminCmd(";sword " .. target) end
local function adminMissile(target) sendAdminCmd(";missile " .. target) end
local function adminAirstrike(target) sendAdminCmd(";airstrike " .. target) end
local function adminMute(target) sendAdminCmd(";mute " .. target) end
local function adminCar(target) sendAdminCmd(";car " .. target) end
local function adminPlane(target) sendAdminCmd(";plane " .. target) end
local function adminDrone(target) sendAdminCmd(";drone " .. target) end

-- ===================== SIGN EDITOR =====================
-- Signs in Elected use the Red networking library
-- From BlockController: Network.Event("EditSign"):Client():Fire(signBlock, text)
-- No need to click signs or open GUIs - just fire the remote directly

local function findSigns(ownerOnly)
	local signs = {}
	local blocks = workspace:FindFirstChild("Blocks")
	if not blocks then return signs end

	local myId = LocalPlayer.UserId
	for _, block in ipairs(blocks:GetChildren()) do
		pcall(function()
			-- Check if this block has a SignTextBox (that's what makes it a sign)
			local hasST = false
			pcall(function()
				-- Signs have: Part > SignMesh > SurfaceGui > SignTextBox
				-- or: Part > SurfaceGui > SignTextBox
				for _, desc in ipairs(block:GetDescendants()) do
					if desc.Name == "SignTextBox" then
						hasST = true
						return
					end
				end
			end)
			if not hasST then return end

			if ownerOnly then
				local builtBy = nil
				pcall(function() builtBy = block:GetAttribute("BuiltBy") end)
				if builtBy == myId then
					table.insert(signs, block)
				end
			else
				table.insert(signs, block)
			end
		end)
	end
	return signs
end

-- Find the SignTextBox inside a sign block
-- Signs structure: Model > Part > SignMesh > SurfaceGui > SignTextBox
-- or: Model > Part > SurfaceGui > SignTextBox
local function findSignTextBox(sign)
	for _, desc in ipairs(sign:GetDescendants()) do
		if desc.Name == "SignTextBox" and desc:IsA("TextBox") then
			return desc
		end
	end
	return nil
end

-- Find the ClickDetector inside a sign block
local function findSignClickDetector(sign)
	for _, desc in ipairs(sign:GetDescendants()) do
		if desc:IsA("ClickDetector") then
			return desc
		end
	end
	return nil
end

-- Edit a single sign by triggering the game's own code path:
-- 1. Fire ClickDetector (BlockController sets up FocusLost handler on SignTextBox)
-- 2. Set SignTextBox.Text to new text
-- 3. Fire FocusLost signal (BlockController's handler fires EditSign remote for us)
local function editSignText(sign, newText)
	local stb = findSignTextBox(sign)
	if not stb then
		print("[SX Elected] No SignTextBox in: " .. sign:GetFullName())
		return false
	end

	local cd = findSignClickDetector(sign)
	if not cd then
		print("[SX Elected] No ClickDetector in: " .. sign:GetFullName())
		return false
	end

	-- Step 1: Fire ClickDetector to trigger BlockController's click handler
	-- This sets up the FocusLost connection on SignTextBox
	local oldDist = cd.MaxActivationDistance
	cd.MaxActivationDistance = 9999

	pcall(function()
		if fireclickdetector then
			fireclickdetector(cd)
		end
	end)

	cd.MaxActivationDistance = oldDist

	-- Step 2: Wait for BlockController to set up FocusLost handler
	task.wait(0.3)

	-- Step 3: Set the text
	stb.Text = newText

	-- Step 4: Fire FocusLost to trigger BlockController's handler
	-- FocusLost passes (enterPressed: bool) - we pass true
	pcall(function()
		if firesignal then
			firesignal(stb.FocusLost, true)
			print("[SX Elected] firesignal FocusLost for: " .. sign:GetFullName())
		else
			-- Fallback: CaptureFocus then ReleaseFocus
			stb:CaptureFocus()
			task.wait(0.1)
			stb:ReleaseFocus(true)
			print("[SX Elected] ReleaseFocus for: " .. sign:GetFullName())
		end
	end)

	return true
end

-- Decompile the Network/Red modules to find event identifier mapping
local function decompileNetworkModule()
	print("[SX Elected] === DECOMPILE NETWORK MODULE ===")
	local log = {}
	local function L(t) table.insert(log, t) print(t) end

	-- Try to decompile ReplicatedStorage.Shared.Network
	local locations = {
		{ReplicatedStorage, "Shared", "Network"},
		{ReplicatedStorage, "Shared", "Red"},
		{game:GetService("ReplicatedFirst"), "Shared", "Network"},
		{game:GetService("ReplicatedFirst"), "Shared", "Red"},
	}

	for _, path in ipairs(locations) do
		pcall(function()
			local current = path[1]
			for i = 2, #path do
				current = current:FindFirstChild(path[i])
				if not current then return end
			end
			if current and current:IsA("ModuleScript") and decompile then
				L("\n--- " .. current:GetFullName() .. " ---")
				local src = decompile(current)
				if src then
					local lines = 0
					for line in src:gmatch("[^\n]+") do
						lines = lines + 1
						if lines <= 100 then
							L(line)
						end
					end
					if lines > 100 then L("... (" .. lines .. " total lines)") end
				else
					L("  decompile returned nil")
				end
			end
		end)
	end

	-- Also decompile BlockController to see full sign edit code
	pcall(function()
		local bc = game:GetService("ReplicatedFirst"):FindFirstChild("Controllers")
		if bc then bc = bc:FindFirstChild("BlockController") end
		if bc and bc:IsA("ModuleScript") and decompile then
			L("\n--- BlockController (first 150 lines) ---")
			local src = decompile(bc)
			if src then
				local lines = 0
				for line in src:gmatch("[^\n]+") do
					lines = lines + 1
					if lines <= 150 then L(line) end
				end
				if lines > 150 then L("... (" .. lines .. " total lines)") end
			end
		end
	end)

	pcall(function()
		local output = table.concat(log, "\n")
		writefile("SXNetworkDecompile.txt", output)
		L("\nSaved to workspace/SXNetworkDecompile.txt")
		notify("Decompile", "Saved to SXNetworkDecompile.txt")
	end)
end

-- Edit all signs (own or all)
local function editAllSigns(newText, ownerOnly)
	local signs = findSigns(ownerOnly or false)
	if #signs == 0 then
		notify("Signs", "No signs found")
		return
	end

	-- Need to be near signs for ClickDetector to work
	local char = LocalPlayer.Character
	local hrp = getRoot()
	if not char or not hrp then
		notify("Signs", "No character")
		return
	end
	local savedCF = hrp.CFrame

	notify("Signs", "Editing " .. #signs .. " signs...")

	task.spawn(function()
		local count = 0
		for i, sign in ipairs(signs) do
			pcall(function()
				-- TP to sign (need to be within ClickDetector range)
				local cf = getItemCFrame(sign)
				if cf then
					char:PivotTo(CFrame.new(cf.Position + Vector3.new(0, 0, -3), cf.Position))
					task.wait(0.15)
				end

				if editSignText(sign, newText) then
					count = count + 1
				end
			end)
			task.wait(0.5)
		end

		-- TP back
		pcall(function() char:PivotTo(savedCF) end)
		notify("Signs", "Edited " .. count .. "/" .. #signs .. " signs")
	end)
end

-- Edit slogan via Red network event "UpdateSlogan" (separate from sign text)
-- Red library fires via: ReliableRedEvent:FireServer({["UpdateSlogan"] = {slogan, banner}})
local function editSlogan(sloganText, bannerText)
	bannerText = bannerText or ""
	if not RedEvent then
		notify("Slogan", "ReliableRedEvent not found!")
		return
	end
	local fired = false
	pcall(function()
		RedEvent:FireServer({["UpdateSlogan"] = {sloganText, bannerText}})
		fired = true
		print("[SX Elected] UpdateSlogan fired: '" .. sloganText .. "'")
	end)
	if fired then
		pcall(function() LocalPlayer:SetAttribute("Slogan", sloganText) end)
		notify("Slogan", "Updated: " .. sloganText:sub(1, 30))
	else
		notify("Slogan", "Failed to fire UpdateSlogan")
	end
end

-- ===================== SIGN DISCOVERY =====================
-- Comprehensive scan to figure out how sign editing actually works in this game

local function discoverSignMethod()
	local log = {}
	local function L(text)
		table.insert(log, text)
		print(text)
	end
	local function saveLog()
		pcall(function()
			writefile("SXElectedDiscovery.txt", table.concat(log, "\n"))
		end)
	end

	L("=== SIGN DISCOVERY v3 ===")

	-- Helper: scan a container for modules, decompile, find events + sign refs
	local eventNames = {}
	local signRefs = {}
	local scanned = 0

	local function scanContainer(container, label)
		L("\n--- Scanning: " .. label .. " ---")
		local descs = {}
		pcall(function() descs = container:GetDescendants() end)
		local count = 0
		for _, desc in ipairs(descs) do
			pcall(function()
				if desc:IsA("ModuleScript") or desc:IsA("LocalScript") then
					count = count + 1
					scanned = scanned + 1
					if scanned % 10 == 0 then
						L("  [progress: " .. scanned .. " scripts scanned...]")
						saveLog()
					end
					pcall(function()
						if decompile then
							local src = decompile(desc)
							if src then
								-- Find Red event names
								for eventName in src:gmatch('[Ee]vent%(%s*"([^"]+)"%s*%)') do
									if not eventNames[eventName] then
										eventNames[eventName] = desc:GetFullName()
										L("  Event: \"" .. eventName .. "\" in " .. desc.Name)
									end
								end
								-- Find sign-related references
								local low = src:lower()
								if low:find("signtext") or low:find("sign_text") or low:find("editsign") or low:find("edit_sign") or low:find("updatesign") or low:find("update_sign") or low:find("setsign") or low:find("set_sign") or low:find("signbox") then
									L("  ** SIGN REF in: " .. desc:GetFullName())
									table.insert(signRefs, desc:GetFullName())
									for line in src:gmatch("[^\n]+") do
										local ll = line:lower()
										if ll:find("signtext") or ll:find("sign_text") or ll:find("editsign") or ll:find("updatesign") or ll:find("setsign") or ll:find("signbox") then
											L("    >> " .. line:sub(1, 200))
										end
									end
								end
								-- Also look for "Sign" as an event name specifically
								for eventName in src:gmatch('[Ee]vent%(%s*"([^"]+)"%s*%)') do
									local el = eventName:lower()
									if el:find("sign") or el:find("block") or el:find("edit") or el:find("build") or el:find("text") or el:find("place") or el:find("update") then
										L("  ** INTERESTING EVENT: \"" .. eventName .. "\" in " .. desc:GetFullName())
									end
								end
							end
						end
					end)
				end
			end)
		end
		L("  Scanned " .. count .. " scripts in " .. label)
	end

	-- Scan targeted locations (NOT game:GetDescendants which hangs)
	scanContainer(game:GetService("ReplicatedFirst"), "ReplicatedFirst")
	saveLog()

	pcall(function() scanContainer(ReplicatedStorage, "ReplicatedStorage") end)
	saveLog()

	pcall(function() scanContainer(game:GetService("StarterPlayer"), "StarterPlayer") end)
	saveLog()

	pcall(function() scanContainer(game:GetService("StarterGui"), "StarterGui") end)
	saveLog()

	-- Try ServerScriptService (usually blocked but worth trying)
	pcall(function() scanContainer(game:GetService("ServerScriptService"), "ServerScriptService") end)
	saveLog()

	-- Event summary
	L("\n--- ALL EVENT NAMES SUMMARY ---")
	local allNames = {}
	for name, source in pairs(eventNames) do
		table.insert(allNames, name)
	end
	table.sort(allNames)
	for _, name in ipairs(allNames) do
		L("  \"" .. name .. "\" -> " .. eventNames[name])
	end
	L("  Total unique events: " .. #allNames)

	-- Sign refs summary
	L("\n--- SIGN REFERENCES SUMMARY ---")
	if #signRefs == 0 then
		L("  No sign text references found in scanned modules")
	else
		for _, ref in ipairs(signRefs) do
			L("  " .. ref)
		end
	end

	-- Also check: what happens when you click a sign? Check the ClickDetector connections
	L("\n--- SIGN CLICKDETECTOR CONNECTIONS ---")
	pcall(function()
		local blocks = workspace:FindFirstChild("Blocks")
		if blocks then
			local checked = 0
			for _, block in ipairs(blocks:GetChildren()) do
				if checked >= 5 then break end
				pcall(function()
					local cd = block:FindFirstChildWhichIsA("ClickDetector", true)
					if cd then
						checked = checked + 1
						L("  Sign: " .. block.Name .. " | ClickDetector at " .. cd:GetFullName())
						L("    MaxDist: " .. tostring(cd.MaxActivationDistance))
						pcall(function()
							if getconnections then
								local conns = getconnections(cd.MouseClick)
								L("    MouseClick connections: " .. #conns)
								for ci, conn in ipairs(conns) do
									if ci > 3 then break end
									pcall(function()
										L("      [" .. ci .. "] func: " .. tostring(conn.Function))
										if conn.Function and decompile then
											local fsrc = decompile(conn.Function)
											if fsrc then
												L("      -- DECOMPILED CONNECTION --")
												local lines = 0
												for line in fsrc:gmatch("[^\n]+") do
													lines = lines + 1
													if lines <= 30 then
														L("      " .. line)
													end
												end
												if lines > 30 then
													L("      ... (" .. lines .. " total lines)")
												end
											end
										end
									end)
								end
							end
						end)
					end
				end)
			end
		end
	end)

	-- Check what GUI appears when interacting with a sign (BuildFrame?)
	L("\n--- BUILD/SIGN GUI SEARCH ---")
	pcall(function()
		local gui = LocalPlayer:FindFirstChild("PlayerGui")
		if gui then
			for _, desc in ipairs(gui:GetDescendants()) do
				pcall(function()
					local n = desc.Name:lower()
					if n:find("sign") or n:find("build") or n:find("edit") or n:find("lectern") then
						L("  " .. desc.ClassName .. ": " .. desc:GetFullName())
						if desc:IsA("TextBox") or desc:IsA("TextLabel") then
							L("    Text: " .. tostring(desc.Text):sub(1, 100))
						end
						if desc:IsA("GuiObject") then
							L("    Visible: " .. tostring(desc.Visible) .. " | Size: " .. tostring(desc.Size))
						end
					end
				end)
			end
		end
	end)

	L("\n=== END SIGN DISCOVERY v3 ===")
	L("Total scripts scanned: " .. scanned)
	saveLog()
	notify("Discovery", "Done! Saved to SXElectedDiscovery.txt (F9 for details)")
end

-- ===================== BUILDING SYSTEM =====================
-- Building in Elected works through the BuildingTool + Red networking
-- The client-side tool handles placement and sends data via ReliableRedEvent
-- We interact with the building system by:
-- 1. Equipping the building tool
-- 2. Selecting blocks through the tool's UI
-- 3. Activating at positions

local function findBuildingTool()
	local char = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local searchNames = {"build", "place", "hammer", "wrench"}

	-- Check equipped
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				for _, keyword in ipairs(searchNames) do
					if n:find(keyword) then return tool end
				end
			end
		end
	end

	-- Check backpack
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local n = tool.Name:lower()
				for _, keyword in ipairs(searchNames) do
					if n:find(keyword) then return tool end
				end
			end
		end
	end

	return nil
end

local function placeBlockAt(cframe, blockName)
	-- Try to use ReliableRedEvent directly if we can figure out the format
	-- Otherwise, use the building tool
	local tool = findBuildingTool()
	if tool then
		equipTool(tool)
		task.wait(0.1)
		-- The building tool places blocks where you click
		-- We move the character to the position and activate the tool
		local char = LocalPlayer.Character
		if char then
			local savedCF = char:GetPivot()
			char:PivotTo(cframe)
			task.wait(0.05)
			pcall(function() tool:Activate() end)
			mouse1click()
			task.wait(0.05)
			char:PivotTo(savedCF)
		end
	else
		notify("Error", "No building tool found! Equip one first.")
	end
end

-- ===================== CLIENT-SIDE FLING =====================
-- Spins your character at high velocity into a target player to fling them

local function flingPlayer(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then
		notify("Error", targetPlayer and (targetPlayer.DisplayName .. " has no character") or "No target")
		return
	end
	local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not targetHRP then
		notify("Error", "Target has no HumanoidRootPart")
		return
	end

	local myChar = LocalPlayer.Character
	local myHRP = getRoot()
	if not myChar or not myHRP then return end

	local savedCF = myHRP.CFrame
	notify("Fling", "Flinging " .. targetPlayer.DisplayName .. "...")

	task.spawn(function()
		-- TP to target and spin at high velocity
		local av = Instance.new("BodyAngularVelocity")
		av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		av.AngularVelocity = Vector3.new(0, 9999, 0)
		av.P = 1000000
		av.Parent = myHRP

		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.P = 9000
		bv.Parent = myHRP

		-- Ram into them for 1.5 seconds
		local startTime = tick()
		while tick() - startTime < 1.5 do
			pcall(function()
				if not targetHRP or not targetHRP.Parent then return end
				local dir = (targetHRP.Position - myHRP.Position).Unit
				bv.Velocity = dir * 500
				myHRP.CFrame = CFrame.new(targetHRP.Position + dir * -3)
			end)
			task.wait()
		end

		-- Cleanup and return
		pcall(function() av:Destroy() end)
		pcall(function() bv:Destroy() end)

		task.wait(0.2)
		pcall(function()
			local root = getRoot()
			if root then root.CFrame = savedCF end
		end)
		notify("Fling", "Flung " .. targetPlayer.DisplayName .. "!")
	end)
end

-- ===================== ANTI-JAIL =====================
-- Detects when player gets jailed (sudden teleport to jail cell) and teleports back

local function startAntiJail()
	antiJailActive = true
	local hrp = getRoot()
	if hrp then lastKnownPos = hrp.CFrame end

	antiJailConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not antiJailActive then return end
			local root = getRoot()
			if not root then return end

			-- Update position every frame
			-- If we suddenly teleport far (jailed), teleport back
			if lastKnownPos then
				local dist = (root.Position - lastKnownPos.Position).Magnitude
				-- Jail detection: sudden move > 50 studs that we didn't cause
				if dist > 50 and not flyActive then
					-- Check if we're in a small enclosed space (jail cell)
					task.wait(0.2)
					root.CFrame = lastKnownPos
					notify("Anti-Jail", "Broke out of jail!")
				end
			end
			lastKnownPos = root.CFrame
		end)
	end)
	notify("Anti-Jail", "Active - will break out automatically")
end

local function stopAntiJail()
	antiJailActive = false
	if antiJailConnection then antiJailConnection:Disconnect() antiJailConnection = nil end
end

-- ===================== ANTI-FLING =====================
-- Prevents fling by anchoring or clamping velocity

local function startAntiFling()
	antiFlingActive = true
	antiFlingConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not antiFlingActive then return end
			local root = getRoot()
			if not root then return end
			-- Clamp velocity to prevent fling
			if root.AssemblyLinearVelocity.Magnitude > 100 then
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end
		end)
	end)
	notify("Anti-Fling", "Fling protection active!")
end

local function stopAntiFling()
	antiFlingActive = false
	if antiFlingConnection then antiFlingConnection:Disconnect() antiFlingConnection = nil end
end

-- ===================== FLY =====================
local function startFly()
	local hrp = getRoot()
	local hum = getHumanoid()
	if not hrp or not hum then return end

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
			local h = char:FindFirstChild("HumanoidRootPart")
			if h then h.CanCollide = false end
			local t = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
			if t then t.CanCollide = false end
		end)
	end)
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
end

local function stopSpeedBoost()
	if speedConnection then speedConnection:Disconnect() speedConnection = nil end
	if speedBV then pcall(function() speedBV:Destroy() end) speedBV = nil end
end

-- ===================== INFINITE JUMP =====================
local function startInfJump() infJumpActive = true end

UserInputService.JumpRequest:Connect(function()
	if infJumpActive then
		pcall(function()
			local hum = getHumanoid()
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end
end)

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

-- ===================== ESP =====================
local function clearESP()
	for _, h in pairs(espHighlights) do pcall(function() h:Destroy() end) end
	espHighlights = {}
end

local function updateESP()
	clearESP()
	if not espActive then return end

	local hrp = getRoot()

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			pcall(function()
				local pHRP = player.Character:FindFirstChild("HumanoidRootPart")
				local pHum = player.Character:FindFirstChildOfClass("Humanoid")
				if not pHRP or not pHum then return end
				local dist = hrp and math.floor((pHRP.Position - hrp.Position).Magnitude) or 0

				if not player.Character:FindFirstChild("ESP_HL") then
					local hl = Instance.new("Highlight")
					hl.Name = "ESP_HL"
					hl.Adornee = player.Character
					hl.FillColor = Color3.fromRGB(160, 80, 255)
					hl.FillTransparency = 0.5
					hl.OutlineColor = Color3.new(1, 1, 1)
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = player.Character
					table.insert(espHighlights, hl)
				end

				if not player.Character:FindFirstChild("ESP_BB") then
					local bb = Instance.new("BillboardGui")
					bb.Name = "ESP_BB"
					bb.AlwaysOnTop = true
					bb.Size = UDim2.new(4, 0, 0.8, 0)
					bb.StudsOffset = Vector3.new(0, 3.5, 0)
					bb.Adornee = pHRP
					bb.Parent = player.Character
					table.insert(espHighlights, bb)

					local lbl = Instance.new("TextLabel")
					lbl.Text = player.DisplayName .. " [" .. dist .. "m]\nHP: " .. math.floor(pHum.Health) .. "/" .. math.floor(pHum.MaxHealth)
					lbl.TextColor3 = COLORS.textPrimary
					lbl.TextStrokeTransparency = 0
					lbl.TextSize = 12
					lbl.Font = Enum.Font.GothamBold
					lbl.BackgroundTransparency = 1
					lbl.Size = UDim2.new(1, 0, 1, 0)
					lbl.Parent = bb
				end
			end)
		end
	end
end

local function startESP()
	task.spawn(function()
		while espActive do updateESP() task.wait(2) end
	end)
end

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
end

local function disableFullbright()
	local Lighting = game:GetService("Lighting")
	if savedLighting.Brightness then Lighting.Brightness = savedLighting.Brightness end
	if savedLighting.ClockTime then Lighting.ClockTime = savedLighting.ClockTime end
	if savedLighting.FogEnd then Lighting.FogEnd = savedLighting.FogEnd end
	if savedLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = savedLighting.GlobalShadows end
	if savedLighting.OutdoorAmbient then Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient end
end

-- ===================== ANTI-AFK =====================
local function startAntiAfk()
	antiAfkActive = true
	pcall(function()
		if getconnections then
			for _, conn in pairs(getconnections(LocalPlayer.Idled)) do conn:Disable() end
		end
	end)
	task.spawn(function()
		while antiAfkActive do
			pcall(function()
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
				task.wait(0.1)
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
			end)
			task.wait(300)
		end
	end)
	notify("Anti-AFK", "AFK prevention active!")
end

local function stopAntiAfk() antiAfkActive = false end

-- ===================== CHAT SPAM =====================
local spamText = "Elected Admin Hub on top"

local function startChatSpam()
	chatSpamActive = true
	task.spawn(function()
		while chatSpamActive do
			sendChat(spamText)
			task.wait(1.5) -- Chat cooldown
		end
	end)
	notify("Chat Spam", "Spamming chat!")
end

local function stopChatSpam()
	chatSpamActive = false
	notify("Chat Spam", "Stopped")
end

-- ===================== WORD BUILDER =====================
-- Builds text out of blocks in the game world
-- Each letter is a 5x5 pixel grid made of blocks

local LETTER_PIXELS = {
	A = {"01110","10001","11111","10001","10001"},
	B = {"11110","10001","11110","10001","11110"},
	C = {"01111","10000","10000","10000","01111"},
	D = {"11110","10001","10001","10001","11110"},
	E = {"11111","10000","11110","10000","11111"},
	F = {"11111","10000","11110","10000","10000"},
	G = {"01111","10000","10011","10001","01110"},
	H = {"10001","10001","11111","10001","10001"},
	I = {"11111","00100","00100","00100","11111"},
	J = {"00111","00010","00010","10010","01100"},
	K = {"10001","10010","11100","10010","10001"},
	L = {"10000","10000","10000","10000","11111"},
	M = {"10001","11011","10101","10001","10001"},
	N = {"10001","11001","10101","10011","10001"},
	O = {"01110","10001","10001","10001","01110"},
	P = {"11110","10001","11110","10000","10000"},
	Q = {"01110","10001","10101","10010","01101"},
	R = {"11110","10001","11110","10010","10001"},
	S = {"01111","10000","01110","00001","11110"},
	T = {"11111","00100","00100","00100","00100"},
	U = {"10001","10001","10001","10001","01110"},
	V = {"10001","10001","10001","01010","00100"},
	W = {"10001","10001","10101","11011","10001"},
	X = {"10001","01010","00100","01010","10001"},
	Y = {"10001","01010","00100","00100","00100"},
	Z = {"11111","00010","00100","01000","11111"},
	["0"] = {"01110","10011","10101","11001","01110"},
	["1"] = {"00100","01100","00100","00100","01110"},
	["2"] = {"01110","10001","00110","01000","11111"},
	["3"] = {"11110","00001","01110","00001","11110"},
	["4"] = {"10010","10010","11111","00010","00010"},
	["5"] = {"11111","10000","11110","00001","11110"},
	["6"] = {"01110","10000","11110","10001","01110"},
	["7"] = {"11111","00001","00010","00100","01000"},
	["8"] = {"01110","10001","01110","10001","01110"},
	["9"] = {"01110","10001","01111","00001","01110"},
	["!"] = {"00100","00100","00100","00000","00100"},
	["?"] = {"01110","10001","00110","00000","00100"},
	[" "] = {"00000","00000","00000","00000","00000"},
}

local wordBlockSize = 4 -- studs per pixel

local function buildWord(text, blockColor)
	local hrp = getRoot()
	local char = LocalPlayer.Character
	if not hrp or not char then notify("Error", "No character") return end

	-- Find and equip building tool
	local tool = findBuildingTool()
	if not tool then
		notify("Error", "No building tool found! Equip a building tool first.")
		return
	end
	equipTool(tool)

	text = text:upper()
	local startPos = hrp.Position + hrp.CFrame.LookVector * 15 + Vector3.new(0, 10, 0)
	local rightDir = hrp.CFrame.RightVector
	local upDir = Vector3.new(0, 1, 0)
	local savedCF = hrp.CFrame

	local blocksPlaced = 0
	local charOffset = 0

	notify("Building", "Building: " .. text)

	task.spawn(function()
		for ci = 1, #text do
			local ch = text:sub(ci, ci)
			local pixels = LETTER_PIXELS[ch]
			if pixels then
				for row = 1, 5 do
					for col = 1, 5 do
						if pixels[row]:sub(col, col) == "1" then
							local x = (charOffset + col - 1) * wordBlockSize
							local y = (5 - row) * wordBlockSize
							local pos = startPos + rightDir * x + upDir * y
							pcall(function()
								-- TP to position, place block, TP back
								char:PivotTo(CFrame.new(pos))
								task.wait(0.05)
								pcall(function() tool:Activate() end)
								mouse1click()
								task.wait(0.05)
								char:PivotTo(savedCF)
							end)
							blocksPlaced = blocksPlaced + 1
							task.wait(0.1)
						end
					end
				end
				charOffset = charOffset + 6
			else
				charOffset = charOffset + 3
			end
		end
		notify("Built", blocksPlaced .. " blocks placed for: " .. text)
	end)
end

-- ===================== DEMOLISH OWN BLOCKS =====================
local function demolishOwnBlocks()
	local count = 0
	local blocks = workspace:FindFirstChild("Blocks")
	if not blocks then notify("Error", "No blocks folder") return end

	for _, block in ipairs(blocks:GetDescendants()) do
		pcall(function()
			if block:IsA("BasePart") and block:GetAttribute("Builder") == LocalPlayer.Name then
				block:Destroy()
				count = count + 1
			end
		end)
	end
	notify("Demolish", "Removed " .. count .. " of your blocks")
end

-- Count your blocks
local function countOwnBlocks()
	local count = 0
	local blocks = workspace:FindFirstChild("Blocks")
	if blocks then
		for _, block in ipairs(blocks:GetDescendants()) do
			pcall(function()
				if block:IsA("BasePart") and block:GetAttribute("Builder") == LocalPlayer.Name then
					count = count + 1
				end
			end)
		end
	end
	notify("Blocks", "You have " .. count .. " blocks placed")
end

-- ===================== REMOTE SCANNER =====================
-- Scans all remotes for exploiting
local function scanRemotes()
	print("=== ELECTED ADMIN REMOTE SCAN ===")
	local count = 0
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		pcall(function()
			if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
				print("[" .. obj.ClassName .. "] " .. obj:GetFullName())
				count = count + 1
			end
		end)
	end
	print("=== " .. count .. " REMOTES FOUND ===")
	notify("Scan", count .. " remotes printed to F9")
end

-- ===================== GUI SETUP =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SXElected"
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
mainFrame.Size = UDim2.new(0, 560, 0, 460)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -230)
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
titleBar.BackgroundColor3 = Color3.fromRGB(12, 8, 18)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
addCorner(titleBar, 8)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 10)
titleFix.Position = UDim2.new(0, 0, 1, -10)
titleFix.BackgroundColor3 = Color3.fromRGB(12, 8, 18)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "SX Revival - Elected Admin Hub v1.3"
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

local tabNames = {"Mining", "Admin", "Build", "Players", "Movement", "Visuals", "Troll"}
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
	content.Visible = name == "Mining"
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

local function createTextInput(parent, placeholder, order)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 30)
	box.BackgroundColor3 = COLORS.panel
	box.BorderSizePixel = 0
	box.Text = ""
	box.PlaceholderText = placeholder or "Type here..."
	box.PlaceholderColor3 = COLORS.textDim
	box.TextColor3 = COLORS.textPrimary
	box.Font = Enum.Font.Gotham
	box.TextSize = 11
	box.ClearTextOnFocus = false
	box.LayoutOrder = order or 0
	box.Parent = parent
	addCorner(box, 5)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.Parent = box

	return box
end

-- ===================== BUILD MINING TAB =====================
do
	local tab = tabFrames["Mining"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Adminium Mining", o())
	createToggle(tab, "Auto Mine (Tool + Prompts)", o(), function(on)
		if on then startAutoMine() else stopAutoMine() end
	end)
	createSlider(tab, "Mine Speed (x100 ms)", 1, 50, math.floor(mineSpeed * 100), o(), function(val)
		mineSpeed = val / 100
	end)
	createInfoLabel(tab, "Equips pickaxe, fires ProximityPrompts + activates tool", o())
	createInfoLabel(tab, "Works best when near Adminium with a pickaxe equipped", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Upgrades", o())
	createToggle(tab, "Auto Upgrade", o(), function(on)
		if on then startAutoUpgrade() else stopAutoUpgrade() end
	end)
	createInfoLabel(tab, "Automatically clicks upgrade buttons when available", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Quick Actions", o())
	createButton(tab, "TP to Adminium + Mine", o(), function()
		local char = LocalPlayer.Character
		if not char then return end
		local adminium = findAdminium()
		if adminium then
			local cf = getItemCFrame(adminium)
			if cf then
				char:PivotTo(cf + Vector3.new(0, 5, 0))
				notify("Teleport", "TP to Adminium!")
				-- Also equip mining tool
				local tool = findMiningTool()
				if tool then equipTool(tool) end
			end
		else
			notify("Error", "Adminium not found in workspace")
		end
	end)
	createButton(tab, "Burst Mine (100 clicks)", o(), function()
		task.spawn(function()
			local tool = findMiningTool()
			if tool then equipTool(tool) end
			local adminium = findAdminium()
			for i = 1, 100 do
				if adminium and adminium.Parent then
					fireAllPrompts(adminium)
				end
				if tool and tool.Parent == LocalPlayer.Character then
					pcall(function() tool:Activate() end)
				end
				mouse1click()
				task.wait(0.02)
			end
			notify("Mine", "Burst complete! 100 clicks")
		end)
	end)
	createButton(tab, "List All Tools (F9)", o(), function()
		print("=== YOUR TOOLS ===")
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if backpack then
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then
					print("[Backpack] " .. tool.Name .. " (" .. tool.ClassName .. ")")
				end
			end
		end
		local char = LocalPlayer.Character
		if char then
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then
					print("[Equipped] " .. tool.Name .. " (" .. tool.ClassName .. ")")
				end
			end
		end
		notify("Tools", "Tool list printed to F9")
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Debug / Remote Spy", o())
	createButton(tab, "Scan All Remotes (F9)", o(), scanRemotes)
	createToggle(tab, "Remote Spy (Log all remotes to F9)", o(), function(on)
		if on then startRemoteSpy() else stopRemoteSpy() end
	end)
	createInfoLabel(tab, "Spy logs every FireServer/InvokeServer call to F9", o())
	createInfoLabel(tab, "Use spy to find how mining/building/signs actually work", o())
end

-- ===================== BUILD ADMIN TAB =====================
do
	local tab = tabFrames["Admin"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Admin Commands (Requires Admin)", o())
	createInfoLabel(tab, "These send ; commands in chat - only work if YOU are admin", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Self Commands", o())
	createButton(tab, ";btools me (Building Tools)", o(), function() adminBtools("me") end)
	createButton(tab, ";fly me", o(), function() adminFly("me") end)
	createButton(tab, ";god me", o(), function() adminGod("me") end)
	createButton(tab, ";speed me 100", o(), function() adminSpeed("me", 100) end)
	createButton(tab, ";noclip me", o(), function() adminNoclip("me") end)
	createButton(tab, ";gun me", o(), function() adminGun("me") end)
	createButton(tab, ";sword me", o(), function() adminSword("me") end)
	createButton(tab, ";car me", o(), function() adminCar("me") end)
	createButton(tab, ";plane me", o(), function() adminPlane("me") end)
	createButton(tab, ";drone me", o(), function() adminDrone("me") end)

	createSpacer(tab, o())

	createSectionLabel(tab, "All Commands", o())
	createButton(tab, ";kill all", o(), function() adminKill("all") end)
	createButton(tab, ";fling all", o(), function() adminFling("all") end)
	createButton(tab, ";bring all", o(), function() adminBring("all") end)
	createButton(tab, ";jail all", o(), function() adminJail("all") end)
	createButton(tab, ";respawn all", o(), function() adminRespawn("all") end)
	createButton(tab, ";mute all", o(), function() adminMute("all") end)
	createButton(tab, ";missile all", o(), function() adminMissile("all") end)
	createButton(tab, ";airstrike all", o(), function() adminAirstrike("all") end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Environment", o())
	createButton(tab, ";time 14 (Daytime)", o(), function() sendAdminCmd(";time 14") end)
	createButton(tab, ";time 0 (Nighttime)", o(), function() sendAdminCmd(";time 0") end)
	createButton(tab, ";gravity 50 (Low Gravity)", o(), function() sendAdminCmd(";gravity 50") end)
	createButton(tab, ";gravity 196 (Normal)", o(), function() sendAdminCmd(";gravity 196") end)
	createButton(tab, ";nuke", o(), function() sendAdminCmd(";nuke") end)
	createButton(tab, ";rain", o(), function() sendAdminCmd(";rain") end)
	createButton(tab, ";fog 50", o(), function() sendAdminCmd(";fog 50") end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Custom Command", o())
	local cmdInput = createTextInput(tab, "Enter command (e.g. ;kill all)", o())
	createButton(tab, "Send Command", o(), function()
		if cmdInput.Text ~= "" then
			sendAdminCmd(cmdInput.Text)
			notify("Command", "Sent: " .. cmdInput.Text)
		end
	end)
end

-- ===================== BUILD BUILD TAB =====================
do
	local tab = tabFrames["Build"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Sign Text Editor", o())
	local signInput = createTextInput(tab, "Sign text...", o())
	createButton(tab, "Edit My Signs", o(), function()
		if signInput.Text ~= "" then
			editAllSigns(signInput.Text, true)
		else
			notify("Error", "Enter sign text first!")
		end
	end)
	createButton(tab, "Edit All Signs", o(), function()
		if signInput.Text ~= "" then
			editAllSigns(signInput.Text, false)
		else
			notify("Error", "Enter sign text first!")
		end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Campaign Slogan", o())
	local sloganInput = createTextInput(tab, "Slogan text...", o())
	local bannerInput = createTextInput(tab, "Banner text (optional)...", o())
	createButton(tab, "Update Slogan", o(), function()
		if sloganInput.Text ~= "" then
			editSlogan(sloganInput.Text, bannerInput.Text)
		else
			notify("Error", "Enter slogan text first!")
		end
	end)
	createButton(tab, "Decompile Network (F9)", o(), decompileNetworkModule)
	createButton(tab, "Discover Sign Method (F9)", o(), discoverSignMethod)

	createSpacer(tab, o())

	createSectionLabel(tab, "Block Management", o())
	createButton(tab, "Count My Blocks", o(), countOwnBlocks)
	createButton(tab, "Demolish All My Blocks", o(), demolishOwnBlocks)

	createSpacer(tab, o())

	createSectionLabel(tab, "Word Builder", o())
	createInfoLabel(tab, "Builds text out of blocks using building tool (A-Z, 0-9)", o())
	createInfoLabel(tab, "REQUIRES building tool equipped with a block selected!", o())
	local wordInput = createTextInput(tab, "Enter text to build...", o())
	createSlider(tab, "Block Size (studs)", 2, 8, wordBlockSize, o(), function(val)
		wordBlockSize = val
	end)
	createButton(tab, "Build Word", o(), function()
		if wordInput.Text ~= "" then
			buildWord(wordInput.Text)
		else
			notify("Error", "Enter text first!")
		end
	end)
	createInfoLabel(tab, "TPs to each pixel position and clicks - face your build direction", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Building Tools", o())
	createButton(tab, "Find + Equip Building Tool", o(), function()
		local tool = findBuildingTool()
		if tool then
			equipTool(tool)
			notify("Build", "Equipped: " .. tool.Name)
		else
			notify("Error", "No building tool found in backpack")
		end
	end)
	createButton(tab, "List All Workspace Blocks (F9)", o(), function()
		local blocks = workspace:FindFirstChild("Blocks")
		if blocks then
			local count = 0
			local types = {}
			for _, block in ipairs(blocks:GetChildren()) do
				count = count + 1
				local name = block.Name
				types[name] = (types[name] or 0) + 1
			end
			print("=== PLACED BLOCKS (" .. count .. " total) ===")
			for name, c in pairs(types) do
				print("  " .. name .. ": " .. c)
			end
			notify("Blocks", count .. " blocks placed - see F9")
		else
			notify("Error", "No Blocks folder in workspace")
		end
	end)
	createButton(tab, "List Block Templates (F9)", o(), function()
		print("=== BLOCK TEMPLATES ===")
		local blocksFolder = ReplicatedStorage:FindFirstChild("Assets")
		if blocksFolder then
			local bFolder = blocksFolder:FindFirstChild("Blocks")
			if bFolder then
				local count = 0
				for _, block in ipairs(bFolder:GetChildren()) do
					print("[Template] " .. block.Name .. " (" .. block.ClassName .. ")")
					count = count + 1
				end
				print("=== " .. count .. " TEMPLATES ===")
				notify("Blocks", count .. " templates - see F9")
				return
			end
		end
		-- Try direct path
		blocksFolder = ReplicatedStorage:FindFirstChild("Blocks")
		if blocksFolder then
			local count = 0
			for _, block in ipairs(blocksFolder:GetChildren()) do
				print("[Template] " .. block.Name .. " (" .. block.ClassName .. ")")
				count = count + 1
			end
			print("=== " .. count .. " TEMPLATES ===")
			notify("Blocks", count .. " templates - see F9")
		else
			notify("Error", "No block templates found")
		end
	end)
end

-- ===================== BUILD PLAYERS TAB =====================
do
	local tab = tabFrames["Players"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Player Actions", o())
	createInfoLabel(tab, "Per-player actions (admin cmds require admin status)", o())

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

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 32)
				row.BackgroundColor3 = COLORS.panel
				row.BorderSizePixel = 0
				row.LayoutOrder = idx
				row.Parent = playerActionsFrame
				addCorner(row, 5)

				local nameLbl = Instance.new("TextLabel")
				nameLbl.Size = UDim2.new(1, -280, 1, 0)
				nameLbl.Position = UDim2.new(0, 8, 0, 0)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Text = player.DisplayName
				nameLbl.TextColor3 = COLORS.textPrimary
				nameLbl.Font = Enum.Font.Gotham
				nameLbl.TextSize = 10
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nameLbl.Parent = row

				local actions = {
					{text = "Kill", offset = 275, fn = function() adminKill(player.Name) end},
					{text = "Bring", offset = 230, fn = function() adminBring(player.Name) end},
					{text = "TP", offset = 190, fn = function()
						pcall(function()
							local myChar = LocalPlayer.Character
							local theirHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
							if myChar and theirHRP then
								myChar:PivotTo(theirHRP.CFrame + Vector3.new(0, 3, 0))
								notify("TP", "Teleported to " .. player.DisplayName)
							end
						end)
					end},
					{text = "Fling", offset = 148, fn = function() flingPlayer(player) end},
					{text = "Jail", offset = 108, fn = function() adminJail(player.Name) end},
					{text = "Kick", offset = 68, fn = function() adminKick(player.Name) end},
				}

				for _, action in ipairs(actions) do
					local abtn = Instance.new("TextButton")
					abtn.Size = UDim2.new(0, 38, 0, 22)
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

	Players.PlayerAdded:Connect(function() task.wait(1) refreshPlayerActions() end)
	Players.PlayerRemoving:Connect(function() task.wait(0.5) refreshPlayerActions() end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Protection", o())
	createToggle(tab, "Anti-Jail (TP back if jailed)", o(), function(on)
		if on then startAntiJail() else stopAntiJail() end
	end)
	createToggle(tab, "Anti-Fling (Clamp velocity)", o(), function(on)
		if on then startAntiFling() else stopAntiFling() end
	end)
	createInfoLabel(tab, "Anti-jail detects sudden TP and brings you back", o())
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
	createSlider(tab, "Fly Speed", 10, 200, flySpeed, o(), function(val) flySpeed = val end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Speed", o())
	createToggle(tab, "Speed Boost", o(), function(on)
		speedBoostActive = on
		if on then startSpeedBoost() else stopSpeedBoost() end
	end)
	createSlider(tab, "Speed Value", 20, 200, speedValue, o(), function(val) speedValue = val end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Other", o())
	createToggle(tab, "Noclip (Walk Through Walls)", o(), function(on)
		noclipActive = on
		if on then startNoclip() else stopNoclip() end
	end)
	createToggle(tab, "Infinite Jump", o(), function(on)
		infJumpActive = on
	end)
	createToggle(tab, "God Mode (Infinite Health)", o(), function(on)
		godModeActive = on
		if on then startGodMode() else stopGodMode() end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Teleport Locations", o())
	createButton(tab, "TP to Main Island (Spawn)", o(), function()
		local char = LocalPlayer.Character
		if char then char:PivotTo(CFrame.new(0, 30, 0)) notify("TP", "Main Island") end
	end)
	createButton(tab, "TP to Adminium", o(), function()
		local char = LocalPlayer.Character
		if not char then return end
		local adminium = workspace:FindFirstChild("Adminium")
		if adminium then
			local cf = getItemCFrame(adminium)
			if cf then char:PivotTo(cf + Vector3.new(0, 5, 0)) end
		end
		notify("TP", "Adminium")
	end)
	createButton(tab, "TP to Mars", o(), function()
		local char = LocalPlayer.Character
		if char then
			-- Mars is far away, search workspace for it
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj.Name == "Mars" and (obj:IsA("Model") or obj:IsA("BasePart")) then
					local cf = getItemCFrame(obj)
					if cf then char:PivotTo(cf + Vector3.new(0, 10, 0)) break end
				end
			end
			notify("TP", "Mars (if found)")
		end
	end)
	createButton(tab, "TP to Moon", o(), function()
		local char = LocalPlayer.Character
		if char then
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj.Name == "Moon" and (obj:IsA("Model") or obj:IsA("BasePart")) then
					local cf = getItemCFrame(obj)
					if cf then char:PivotTo(cf + Vector3.new(0, 10, 0)) break end
				end
			end
			notify("TP", "Moon (if found)")
		end
	end)
	createButton(tab, "TP to Sky (Y=500)", o(), function()
		local char = LocalPlayer.Character
		local hrp = getRoot()
		if char and hrp then char:PivotTo(CFrame.new(hrp.Position.X, 500, hrp.Position.Z)) end
		notify("TP", "Sky")
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "AFK", o())
	createToggle(tab, "Anti-AFK (Prevent Kick)", o(), function(on)
		antiAfkActive = on
		if on then startAntiAfk() else stopAntiAfk() end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Server", o())
	createButton(tab, "Rejoin Server", o(), function()
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end)
	createButton(tab, "Server Hop", o(), function()
		task.spawn(function()
			pcall(function()
				local servers = game:GetService("HttpService"):JSONDecode(
					game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=25")
				)
				for _, server in ipairs(servers.data) do
					if server.id ~= game.JobId and server.playing < server.maxPlayers then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
						return
					end
				end
				notify("Error", "No available servers found")
			end)
		end)
	end)
	createInfoLabel(tab, "PlaceId: " .. tostring(game.PlaceId), o())
end

-- ===================== BUILD VISUALS TAB =====================
do
	local tab = tabFrames["Visuals"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "ESP", o())
	createToggle(tab, "Player ESP (Highlight + Distance)", o(), function(on)
		espActive = on
		if on then startESP() else clearESP() end
	end)
	createInfoLabel(tab, "Shows all players through walls with distance + HP", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Visual Mods", o())
	createToggle(tab, "Fullbright (Remove Darkness)", o(), function(on)
		fullbrightActive = on
		if on then enableFullbright() else disableFullbright() end
	end)
	createInfoLabel(tab, "Removes fog, shadows, makes everything bright", o())
end

-- ===================== BUILD TROLL TAB =====================
do
	local tab = tabFrames["Troll"]
	local n = 0
	local function o() n = n + 1 return n end

	createSectionLabel(tab, "Chat Spam", o())
	local spamInput = createTextInput(tab, "Spam message...", o())
	createToggle(tab, "Chat Spam", o(), function(on)
		if spamInput.Text ~= "" then spamText = spamInput.Text end
		if on then startChatSpam() else stopChatSpam() end
	end)
	createInfoLabel(tab, "Sends message in chat every 1.5s", o())

	createSpacer(tab, o())

	createSectionLabel(tab, "Sign Spam", o())
	local signSpamInput = createTextInput(tab, "Sign spam text...", o())
	createButton(tab, "Spam My Signs", o(), function()
		if signSpamInput.Text ~= "" then editAllSigns(signSpamInput.Text, true) end
	end)
	createButton(tab, "Spam All Signs", o(), function()
		if signSpamInput.Text ~= "" then editAllSigns(signSpamInput.Text, false) end
	end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Admin Troll (Requires Admin)", o())
	createButton(tab, ";kill all", o(), function() adminKill("all") end)
	createButton(tab, ";fling all", o(), function() adminFling("all") end)
	createButton(tab, ";jail all", o(), function() adminJail("all") end)
	createButton(tab, ";missile all", o(), function() adminMissile("all") end)
	createButton(tab, ";airstrike all", o(), function() adminAirstrike("all") end)
	createButton(tab, ";nuke", o(), function() sendAdminCmd(";nuke") end)
	createButton(tab, ";gravity 10 (Moon gravity)", o(), function() sendAdminCmd(";gravity 10") end)
	createButton(tab, ";speed all 200", o(), function() adminSpeed("all", 200) end)

	createSpacer(tab, o())

	createSectionLabel(tab, "Fake Admin Popup", o())
	createButton(tab, "Show Fake Admin Notification", o(), function()
		-- Create a fake "You are now admin" popup
		local fakeGui = Instance.new("Frame")
		fakeGui.Size = UDim2.new(0, 350, 0, 80)
		fakeGui.Position = UDim2.new(0.5, -175, 0.1, 0)
		fakeGui.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		fakeGui.BorderSizePixel = 0
		fakeGui.Parent = screenGui
		addCorner(fakeGui, 10)

		local stroke = Instance.new("UIStroke")
		stroke.Color = COLORS.admin
		stroke.Thickness = 2
		stroke.Parent = fakeGui

		local fakeLbl = Instance.new("TextLabel")
		fakeLbl.Size = UDim2.new(1, 0, 1, 0)
		fakeLbl.BackgroundTransparency = 1
		fakeLbl.Text = "You have been elected as Administrator!\nYou now have access to admin commands."
		fakeLbl.TextColor3 = COLORS.admin
		fakeLbl.Font = Enum.Font.GothamBold
		fakeLbl.TextSize = 14
		fakeLbl.Parent = fakeGui

		task.delay(5, function() pcall(function() fakeGui:Destroy() end) end)
		notify("Troll", "Fake admin popup shown (local only)")
	end)
end

-- ===================== MINIMIZE / TOGGLE =====================
local contentVisible = true
minimizeBtn.MouseButton1Click:Connect(function()
	contentVisible = not contentVisible
	for _, frame in pairs(tabFrames) do frame.Visible = contentVisible and frame == tabFrames[activeTab] end
	tabBar.Visible = contentVisible
	accentLine.Visible = contentVisible
	mainFrame.Size = contentVisible and UDim2.new(0, 560, 0, 460) or UDim2.new(0, 560, 0, 32)
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
	if antiJailActive then stopAntiJail() task.wait(0.3) startAntiJail() end
	if antiFlingActive then stopAntiFling() task.wait(0.3) startAntiFling() end
end)

-- ===================== STARTUP =====================
notify("SX Elected v1.3", "Loaded! Right Shift to toggle")
print("[SX Elected v1.3] Synapse X The Revival - Elected Admin Hub")
print("[SX Elected v1.3] Tabs: Mining | Admin | Build | Players | Movement | Visuals | Troll")
print("[SX Elected v1.3] Red Event: " .. (RedEvent and RedEvent:GetFullName() or "NOT FOUND"))
print("[SX Elected v1.3] Chat: " .. (ChatRemote and "Legacy Chat" or "TextChatService"))
print("[SX Elected v1.3] Mining: Tool-based (equip pickaxe + ProximityPrompt)")
print("[SX Elected v1.3] Building: Tool-based (equip building tool)")
print("[SX Elected v1.3] Signs: EditSign Red event (direct remote fire)")
print("[SX Elected v1.3] Right Shift to toggle GUI")
